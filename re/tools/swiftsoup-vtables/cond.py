import sys, re, subprocess
SP = "/private/tmp/claude-501/-Users-<user>--claude-spares-spare-OyfGU2/ade7e8e9-c95a-4cba-bd4f-b4f6c03f3ea7/scratchpad/"
D = SP + "a1a/"
DEM = "/Applications/Xcode.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/bin/swift-demangle"
vt = {}
for l in open(D + "vtables.tsv"):
    c, o, n = l.rstrip("\n").split("\t")
    vt.setdefault(c, {})[int(o, 16)] = n
def vname(off):
    parts = []
    for c, tag in (("Element", "E"), ("Elements", "Es"), ("Document", "D")):
        n = vt.get(c, {}).get(off)
        if n and "deletedMethod" not in n and "OBJC" not in n and "metaclass" not in n and "nominal type" not in n:
            if c == "Document" and vt["Element"].get(off) == n: continue
            n = re.sub(r"SwiftSoup\.|Swift\.", "", n)
            n = re.sub(r" throws", "", n)
            parts.append(f"{tag}:{n[:60]}")
    return " | ".join(parts) or f"vt+{off:#x}"
lo, hi = int(sys.argv[1], 16), int(sys.argv[2], 16)
lines = []
with open(SP + "disasm.txt", encoding="latin1") as f:
    for l in f:
        if not l.startswith("0000000100"): continue
        a = int(l[:16], 16)
        if a < lo: continue
        if a >= hi: break
        lines.append(l.rstrip("\n"))
# demangle symbols in bl lines
syms = set()
for l in lines:
    m = re.search(r"(?:symbol stub for: |\bbl\s+)(_\$s\S+|\$s\S+)", l)
    if m: syms.add(m.group(1))
syms = sorted(syms)
dm = dict(zip(syms, subprocess.run([DEM, "--simplified"], input="\n".join(s.lstrip("_") for s in syms), capture_output=True, text=True).stdout.splitlines()))
regs = {}
last_ldr = {}
def small(lo_, hi_):
    n = (hi_ >> 56) & 0xf
    if (hi_ >> 60) not in (0xe, 0xa): return None
    raw = lo_.to_bytes(8, "little") + (hi_ & 0x00ffffffffffffff).to_bytes(7, "little")
    try: return raw[:n].decode("utf8")
    except Exception: return None
for l in lines:
    p = l.split("\t")
    addr, op = p[0][-8:], p[1]
    args = p[2] if len(p) > 2 else ""
    m = re.match(r"(x\d+|w\d+), #(-?0x[0-9a-f]+|-?\d+)(?:, lsl #(\d+))?$", args)
    if op in ("mov", "movz") and m:
        r = "x" + m.group(1)[1:]; v = int(m.group(2), 0) & 0xffffffffffffffff
        regs[r] = v
    elif op == "movk" and m:
        r = "x" + m.group(1)[1:]; sh = int(m.group(3) or 0); v = int(m.group(2), 0)
        regs[r] = (regs.get(r, 0) & ~(0xffff << sh)) | (v << sh)
    mm = re.match(r"(x\d+), \[(x\d+), #(0x[0-9a-f]+)\]$", args)
    if op == "ldr" and mm:
        last_ldr[mm.group(1)] = int(mm.group(3), 16)
    out = None
    if op == "blr":
        r = args.strip()
        off = last_ldr.get(r)
        s = small(regs.get("x0", 0), regs.get("x1", 0))
        out = f"CALL {vname(off) if off is not None else r}" + (f'  ("{s}")' if s is not None else "")
    elif op == "bl":
        m2 = re.search(r"(_\$s\S+|\$s\S+)", l)
        name = dm.get(m2.group(1), m2.group(1)) if m2 else args
        if re.search(r"swift_(retain|release|bridgeObject|errorRelease|endAccess|beginAccess)|objc_re|swift_isUniquely", l): continue
        s = small(regs.get("x0", 0), regs.get("x1", 0))
        out = f"BL {name[:200]}" + (f'  (x0x1="{s}")' if s is not None else "")
    elif "literal pool for:" in l:
        out = "LIT " + l.split("literal pool for:")[1].strip()
    elif op in ("b", "cbz", "cbnz", "tbz", "tbnz") or op.startswith("b."):
        out = f"{op} {args}"
    elif op == "ret":
        out = "RET"
    elif op == "brk":
        out = "BRK"
    if out: print(addr, out)
