#!/usr/bin/env python3
"""Split a REA batch_decompile JSON result into one file per procedure.

usage: split_decompile.py <batch.json> <out_dir>
Appends "<address>\t<bytes>\t<demangled name>" lines to <out_dir>/INDEX.tsv.
"""
import json
import os
import re
import subprocess
import sys

DEMANGLE = "/Applications/Xcode.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/bin/swift-demangle"

src, out = sys.argv[1], sys.argv[2]
os.makedirs(out, exist_ok=True)
items = json.load(open(src))["normalized_result"]["items"]
names = [(it.get("procedure") or {}).get("name") or it["address"] for it in items]
dm = subprocess.run([DEMANGLE, "--simplified"], input="\n".join(n.lstrip("_") for n in names),
                    capture_output=True, text=True).stdout.split("\n")
with open(os.path.join(out, "INDEX.tsv"), "a") as index:
    for it, name in zip(items, dm):
        code = it.get("pseudocode") or ""
        safe = re.sub(r"[^A-Za-z0-9_.()-]+", "_", name)[:120]
        path = os.path.join(out, f"{it['address']}_{safe}.c")
        with open(path, "w") as f:
            f.write(f"// {it['address']}  {name}\n// status: {it.get('status')}\n{code}\n")
        index.write(f"{it['address']}\t{len(code)}\t{name}\n")
print(len(items), "procedures written")
