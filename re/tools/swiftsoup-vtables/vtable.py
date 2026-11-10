import re, subprocess, sys
SP = "/private/tmp/claude-501/-Users-<user>--claude-spares-spare-OyfGU2/ade7e8e9-c95a-4cba-bd4f-b4f6c03f3ea7/scratchpad/"
DEM = "/Applications/Xcode.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/bin/swift-demangle"
fix = {}
for line in open(SP + "fixups.txt"):
    p = line.split()
    if len(p) >= 5 and p[2].startswith("0x"):
        fix[int(p[2], 16)] = (p[3], p[4] if len(p) > 4 else "", " ".join(p[4:]))
syms = {}
cn = {}
for line in open(SP + "nm.txt"):
    p = line.rstrip("\n").split(" ", 2)
    if len(p) < 3 or not p[0]: continue
    a = int(p[0], 16)
    syms.setdefault(a, p[2])
    m = re.match(r"_\$s9SwiftSoup(\d+)(\w+?)CN$", p[2])
    if m: cn[m.group(2)[:int(m.group(1))]] = a
cls = sys.argv[1:]
out = []
for c in cls:
    base = cn[c]
    for off in range(0x50, 0x800, 8):
        f = fix.get(base + off)
        if not f: continue
        kind, tgt, rest = f
        if kind == "rebase":
            t = int(tgt, 16); name = syms.get(t, "?")
        else:
            name = rest
        out.append((c, off, name))
names = [n for _, _, n in out]
dm = subprocess.run([DEM, "--compact"], input="\n".join(n.lstrip("_") if n.startswith("_$") else n for n in names), capture_output=True, text=True).stdout.splitlines()
for (c, off, n), d in zip(out, dm):
    print(f"{c}\t{off:#x}\t{d}")
