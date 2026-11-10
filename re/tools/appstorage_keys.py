#!/usr/bin/env python3
"""Recover @AppStorage keys/defaults from `otool -tV` arm64 disassembly.

Tracks constant register values (mov/movk/adrp/add/sub/orr) in the instructions
preceding each call to a SwiftUI.AppStorage.init stub and prints the decoded
Swift string arguments. Also reports the enclosing function symbol.

usage: appstorage_keys.py <disasm.txt> <macho>
"""
import re
import struct
import sys

dis_path, macho = sys.argv[1], sys.argv[2]
data = open(macho, "rb").read()
segs = []
ncmds = struct.unpack_from("<I", data, 16)[0]
off = 32
for _ in range(ncmds):
    cmd, cs = struct.unpack_from("<II", data, off)
    if cmd == 0x19:
        vm, vs, fo, fs = struct.unpack_from("<QQQQ", data, off + 24)
        segs.append((vm, fs, fo))
    off += cs


def cstr(addr):
    for vm, fs, fo in segs:
        if vm <= addr < vm + fs:
            p = fo + addr - vm
            return data[p:data.index(b"\0", p)].decode("utf-8", "replace")
    return None


def u64(addr):
    for vm, fs, fo in segs:
        if vm <= addr < vm + fs:
            return struct.unpack_from("<Q", data, fo + addr - vm)[0]
    return None


def imm(s):
    v = int(s.replace("#", ""), 0)
    return v & 0xFFFFFFFFFFFFFFFF


def swift_str(lo, hi):
    """Decode a Swift String from its two raw words."""
    if lo is None or hi is None:
        return None
    top = hi >> 56
    if top & 0xF0 in (0xE0, 0xA0):  # small string
        n = top & 0x0F
        raw = lo.to_bytes(8, "little") + (hi & 0x00FFFFFFFFFFFFFF).to_bytes(7, "little")
        return raw[:n].decode("utf-8", "replace")
    if lo >> 60 in (0xD, 0x1, 0x0) and hi & 0x8000000000000000:  # large immortal literal
        return cstr((hi & 0x7FFFFFFFFFFFFFFF) + 0x20)
    return None


INS = re.compile(r"^([0-9a-f]{16})\t(\w+)\t(.*)$")
INIT = re.compile(r"symbol stub for: _\$s7SwiftUI10AppStorageV12wrappedValue_5storeACy(\w+?)G")
regs, func = {}, "?"
for line in open(dis_path):
    line = line.rstrip("\n")
    if line.endswith(":") and not line.startswith("0"):
        func, regs = line[:-1], {}
        continue
    m = INS.match(line)
    if not m:
        continue
    op, args = m.group(2), m.group(3)
    a = [x.strip() for x in args.split(";")[0].split(",")]
    r = a[0] if a else ""
    r64 = "x" + r[1:] if r[:1] in "xw" and r[1:].isdigit() else None
    try:
        if op in ("mov", "movz") and len(a) == 2 and a[1].startswith("#"):
            regs[r64] = imm(a[1]) & (0xFFFFFFFF if r.startswith("w") else 0xFFFFFFFFFFFFFFFF)
        elif op == "mov" and len(a) == 2 and a[1][:1] in "xw" and a[1][1:].isdigit():
            regs[r64] = regs.get("x" + a[1][1:])
        elif op == "movk" and isinstance(regs.get(r64), int):
            sh = int(a[2].split("#")[1], 0) if len(a) > 2 else 0
            v = imm(a[1])
            regs[r64] = (regs[r64] & ~(0xFFFF << sh)) | (v << sh)
        elif op == "adrp":
            regs[r64] = int(args.split(";")[1].strip(), 16)
        elif op == "add" and len(a) == 3 and a[2].startswith("#") and a[1][:1] == "x" and isinstance(regs.get("x" + a[1][1:]), int):
            regs[r64] = regs["x" + a[1][1:]] + imm(a[2])
        elif op == "sub" and len(a) == 3 and a[2].startswith("#") and isinstance(regs.get("x" + a[1][1:]), int):
            regs[r64] = (regs["x" + a[1][1:]] - imm(a[2])) & 0xFFFFFFFFFFFFFFFF
        elif op == "orr" and len(a) == 3 and a[2].startswith("#") and isinstance(regs.get("x" + a[1][1:]), int):
            regs[r64] = regs["x" + a[1][1:]] | imm(a[2])
        elif op == "ldp" and "[" in args:
            base = re.search(r"\[(x\d+)(?:, #(-?0x[0-9a-f]+|\d+))?\]", args)
            if base and isinstance(regs.get(base.group(1)), int):
                addr = regs[base.group(1)] + (int(base.group(2), 0) if base.group(2) else 0)
                d1, d2 = a[0], a[1]
                regs["x" + d1[1:]] = ("global", addr)
                regs["x" + d2[1:]] = ("global", addr + 8)
            else:
                regs.pop("x" + a[0][1:], None)
                regs.pop("x" + a[1][1:], None)
        elif op == "bl":
            mm = INIT.search(args)
            if mm:
                kind = {"SS": "String", "Sb": "Bool"}.get(mm.group(1), "RawRepresentable")
                def g(n):
                    v = regs.get(n)
                    return v if isinstance(v, int) else None
                if kind == "String":
                    dv = regs.get("x0")
                    default = (f"<global {dv[1]:#x}>" if isinstance(dv, tuple) else repr(swift_str(g("x0"), g("x1"))))
                    key = swift_str(g("x2"), g("x3"))
                elif kind == "Bool":
                    default = {0: "false", 1: "true"}.get(g("x0"), "?")
                    key = swift_str(g("x1"), g("x2"))
                else:
                    default = "<raw enum via x0>"
                    key = swift_str(g("x1"), g("x2"))
                print(f"{m.group(1)}\t{kind}\tkey={key!r}\tdefault={default}\tin {func}")
            regs = {k: v for k, v in regs.items() if k not in {f"x{i}" for i in range(19)}}
        elif r64 and op not in ("str", "stp", "stur", "cmp", "cbz", "cbnz", "tbz", "tbnz", "b", "ret", "br", "blr"):
            regs.pop(r64, None)
    except (ValueError, IndexError):
        regs.pop(r64, None)
