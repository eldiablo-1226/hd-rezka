#!/usr/bin/env python3
"""Dump Swift reflection metadata (types, fields, conformances) from a thin arm64 Mach-O.

usage: swiftmeta.py <macho> <dyld_info -fixups output> <module-filter|-> > out.txt
"""
import re
import struct
import subprocess
import sys

DEMANGLE = "/Applications/Xcode.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/bin/swift-demangle"

path, fixups_path, module_filter = sys.argv[1], sys.argv[2], sys.argv[3]
data = open(path, "rb").read()

magic, _, _, _, ncmds, _, _, _ = struct.unpack_from("<IiiIIIII", data, 0)
assert magic == 0xFEEDFACF, "expected thin 64-bit Mach-O"
segments, sections = [], {}
off = 32
for _ in range(ncmds):
    cmd, cmdsize = struct.unpack_from("<II", data, off)
    if cmd == 0x19:  # LC_SEGMENT_64
        vmaddr, vmsize, fileoff, filesize, _, _, nsects, _ = struct.unpack_from("<QQQQiiII", data, off + 24)
        segments.append((vmaddr, filesize, fileoff))
        so = off + 72
        for _ in range(nsects):
            sect = data[so:so + 16].rstrip(b"\0").decode()
            seg = data[so + 16:so + 32].rstrip(b"\0").decode()
            addr, size, offset = struct.unpack_from("<QQI", data, so + 32)
            sections[(seg, sect)] = (addr, size)
            so += 80
    off += cmdsize


def fo(addr):
    for vm, fsz, foff in segments:
        if vm <= addr < vm + fsz:
            return foff + addr - vm
    raise ValueError(hex(addr))


def i32(a):
    return struct.unpack_from("<i", data, fo(a))[0]


def u32(a):
    return struct.unpack_from("<I", data, fo(a))[0]


def u16(a):
    return struct.unpack_from("<H", data, fo(a))[0]


def rel(a):
    v = i32(a)
    return a + v if v else 0


def cstr(a):
    p = fo(a)
    return data[p:data.index(b"\0", p)].decode("utf-8", "replace")


fix = {}
for line in open(fixups_path):
    parts = line.split()
    if len(parts) >= 5 and parts[2].startswith("0x") and parts[3] in ("rebase", "bind"):
        fix[int(parts[2], 16)] = (parts[3], parts[4])


def slot(a):
    """Resolve a pointer slot: ('addr', int) or ('sym', str)."""
    kind, tgt = fix.get(a, (None, None))
    if kind == "rebase":
        return ("addr", int(tgt, 16))
    if kind == "bind":
        return ("sym", tgt.split("/", 1)[-1])
    return ("addr", struct.unpack_from("<Q", data, fo(a))[0])


def rel_indirectable(a):
    v = i32(a)
    if v == 0:
        return None
    if v & 1:
        return slot(a + (v & ~1))
    return ("addr", a + v)


KIND_CHAR = {16: "C", 17: "V", 18: "O", 3: "P"}
_mcache = {}


def demangle_many(names):
    if not names:
        return []
    out = subprocess.run([DEMANGLE, "--simplified"], input="\n".join(names), capture_output=True, text=True).stdout
    return out.split("\n")[: len(names)]


def ctx_mangling(addr):
    """Standard mangling fragment for a context descriptor (no $s prefix)."""
    if addr in _mcache:
        return _mcache[addr]
    flags = u32(addr)
    kind = flags & 0x1F
    par = rel_indirectable(addr + 4)
    pm = ""
    if par:
        pm = ctx_mangling(par[1]) if par[0] == "addr" else sym_mangling(par[1])
    if kind == 0:
        name = cstr(rel(addr + 8))
        m = "s" if name == "Swift" else ("So" if name == "__C" else f"{len(name.encode())}{name}")
    elif kind == 1:  # extension: use extended type
        mn = rel(addr + 8)
        m = read_mangled(mn) if mn else pm
    elif kind == 2:  # anonymous (private) context: transparent
        m = pm
    elif kind in KIND_CHAR:
        name = cstr(rel(addr + 8))
        m = f"{pm}{len(name.encode())}{name}{KIND_CHAR[kind]}"
    else:
        m = pm
    _mcache[addr] = m
    return m


def sym_mangling(sym):
    s = sym.lstrip("_")
    if s.startswith("$s"):
        s = s[2:]
    if s.endswith("Mn"):
        return s[:-2]
    if s.endswith("Mp"):
        return s[:-2] + "P"
    return f"<{sym}>"


def read_mangled(a):
    out = []
    p = a
    while True:
        b = data[fo(p)]
        if b == 0:
            break
        if 0x01 <= b <= 0x17:
            ref = p + 1
            v = i32(ref)
            if b == 0x01:
                out.append(ctx_mangling(ref + v))
            elif b == 0x02:
                k, t = slot(ref + v)
                out.append(ctx_mangling(t) if k == "addr" else sym_mangling(t))
            else:
                out.append(f"<ref{b:#x}>")
            p += 5
            continue
        if 0x18 <= b <= 0x1F:
            out.append("<absref>")
            p += 9
            continue
        out.append(chr(b))
        p += 1
    return "".join(out)


def ctx_name(addr):
    flags = u32(addr)
    kind = flags & 0x1F
    par = rel_indirectable(addr + 4)
    pn = ""
    if par and par[0] == "addr":
        pn = ctx_name(par[1])
    elif par:
        pn = par[1]
    if kind == 0:
        return cstr(rel(addr + 8))
    if kind == 1:
        mn = rel(addr + 8)
        return f"ext:{read_mangled(mn)}" if mn else pn
    if kind == 2:
        return pn + ".(private)"
    return f"{pn}.{cstr(rel(addr + 8))}"


# --- types ---
taddr, tsize = sections[("__TEXT", "__swift5_types")]
types = []
for i in range(0, tsize, 4):
    a = taddr + i
    v = i32(a)
    if v & 3:
        k, t = slot(a + (v & ~3))
        if k != "addr":
            continue
        d = t
    else:
        d = a + v
    types.append(d)

# --- conformances ---
conf = {}
paddr, psize = sections[("__TEXT", "__swift5_proto")]
proto_syms = []
for i in range(0, psize, 4):
    a = paddr + i
    cd = a + i32(a)
    pr = rel_indirectable(cd)
    flags = u32(cd + 12)
    tk = (flags >> 3) & 7
    tv = i32(cd + 4)
    if tk == 0:
        td = cd + 4 + tv
    elif tk == 1:
        k, t = slot(cd + 4 + tv)
        if k != "addr":
            continue
        td = t
    else:
        continue
    if pr is None:
        continue
    if pr[0] == "addr":
        pname = ctx_name(pr[1])
    else:
        proto_syms.append(pr[1])
        pname = ("SYM", pr[1])
    conf.setdefault(td, []).append(pname)

sym_dm = dict(zip(proto_syms, demangle_many([s.lstrip("_") for s in proto_syms])))
for td, lst in conf.items():
    conf[td] = [sym_dm.get(p[1], p[1]).replace("protocol descriptor for ", "") if isinstance(p, tuple) else p for p in lst]

KINDS = {16: "class", 17: "struct", 18: "enum"}
records = []
pending = []
for d in types:
    flags = u32(d)
    kind = flags & 0x1F
    if kind not in KINDS:
        continue
    name = ctx_name(d)
    if module_filter != "-" and not name.startswith(module_filter + "."):
        continue
    generic = bool(flags & 0x80)
    sup = None
    if kind == 16:
        sp = rel(d + 20)
        if sp:
            sup = read_mangled(sp)
            pending.append("$s" + sup + "D")
    fields = []
    fdp = rel(d + 16)
    if fdp:
        n = u32(fdp + 12)
        rs = u16(fdp + 10)
        for j in range(n):
            r = fdp + 16 + j * rs
            ff = u32(r)
            tn = rel(r + 4)
            fnm = cstr(rel(r + 8)) if i32(r + 8) else "?"
            tm = read_mangled(tn) if tn else ""
            if tm:
                pending.append("$s" + tm + "D")
            fields.append((ff, fnm, tm))
    records.append((kind, name, generic, sup, fields, conf.get(d, [])))

dm = dict(zip(pending, demangle_many(pending)))


def T(m):
    if not m:
        return ""
    s = dm.get("$s" + m + "D", m)
    return m if s == "$s" + m + "D" else s


for kind, name, generic, sup, fields, protos in sorted(records, key=lambda r: r[1]):
    head = f"{KINDS[kind]} {name}{'<generic>' if generic else ''}"
    if sup:
        head += f" : {T(sup)}"
    if protos:
        head += ("," if sup else " :") + " " + ", ".join(sorted(set(protos)))
    print(head + " {")
    for ff, fnm, tm in fields:
        if kind == 18:
            print(f"    case {fnm}{'(' + T(tm) + ')' if tm else ''}{' [indirect]' if ff & 1 else ''}")
        else:
            print(f"    {'var' if ff & 2 else 'let'} {fnm}: {T(tm)}")
    print("}")
