#!/usr/bin/env python3
"""Summarize what a SwiftUI view does, from all its decompiled procedures.

usage: view_facts.py <TypeName> [decompiled_dir]
Prints: procedures, string literals (incl. decoded small strings), localization keys,
SF Symbol-like names, app types referenced, SwiftUI modifiers/containers used,
app service calls. Read the listed procedures with digest.py for details.
"""
import collections
import os
import re
import sys

sys.path.insert(0, os.path.dirname(__file__))
from digest import small  # noqa: E402

name = sys.argv[1]
ddir = sys.argv[2] if len(sys.argv) > 2 else os.path.join(os.path.dirname(__file__), "..", "decompiled")
index = [l.rstrip("\n").split("\t") for l in open(os.path.join(ddir, "INDEX.tsv"))]
own = re.compile(r"(^|[ (])" + re.escape(name) + r"(\.|\b(?!\w))")
procs = [(a, int(sz), n) for a, sz, n in index if own.search(n) and not re.search(r"metadata|witness|outlined|destroy", n)]

text = []
for a, _, _ in procs:
    for f in os.listdir(ddir):
        if f.startswith(a + "_"):
            text.append(open(os.path.join(ddir, f), errors="replace").read())
            break
blob = "\n".join(text)

lits = collections.Counter(re.findall(r'"((?:[^"\\]|\\.){2,200})"(?! - 0x)', blob))
lits.update(re.findall(r'"((?:[^"\\]|\\.){2,200})" - 0x20', blob))
for h in re.findall(r"0x[0-9a-f]{5,16}\b", blob):
    s = small(int(h, 16))
    if s and len(s) >= 3:
        lits[s + "  (small)"] += 1
apptypes = collections.Counter(t for t in re.findall(r"HDrezka\.([A-Z][A-Za-z]+)", blob) if t != name)
mods = collections.Counter(m for m in re.findall(r"SwiftUI\.(?:View\.)?([a-z][A-Za-z]+)(?:<|\()", blob))
containers = collections.Counter(re.findall(r"SwiftUI\.(VStack|HStack|ZStack|LazyVGrid|LazyHGrid|LazyVStack|LazyHStack|ScrollView|List|Form|Section|NavigationView|NavigationStack|NavigationLink|TabView|Button|Menu|Picker|Toggle|TextField|SecureField|Image|Text|Label|Link|ShareLink|ProgressView|GeometryReader|ForEach|Spacer|Divider|AsyncImage|Color|LinearGradient|RoundedRectangle|Circle|Capsule)\b", blob))
calls = collections.Counter(re.findall(r"HDrezka\.([A-Z][A-Za-z]+\.[a-z][A-Za-z]*)\(", blob))
libs = collections.Counter(re.findall(r"\b(NukeUI\.[A-Za-z.]+|Nuke\.[A-Za-z.]+|AlertKit\.[A-Za-z.]+|Flow\.[A-Za-z]+|YouTubePlayerKit\.[A-Za-z.]+|Alamofire\.[A-Za-z]+\.[a-z][A-Za-z]*)", blob))

print(f"== {name}: {len(procs)} procedures, {sum(s for _, s, _ in procs)} bytes")
for a, sz, n in sorted(procs, key=lambda x: -x[1])[:40]:
    print(f"  {a} {sz:8d} {n}")
print("== string literals")
for s, c in sorted(lits.items()):
    print(f"  {s}" + (f"  x{c}" if c > 1 else ""))
print("== app types referenced:", ", ".join(f"{t}({c})" for t, c in apptypes.most_common()))
print("== app calls:", ", ".join(f"{t}({c})" for t, c in calls.most_common()))
print("== SwiftUI views:", ", ".join(f"{t}({c})" for t, c in containers.most_common()))
print("== SwiftUI modifiers:", ", ".join(f"{t}({c})" for t, c in mods.most_common(60)))
print("== libraries:", ", ".join(f"{t}({c})" for t, c in libs.most_common(30)))
