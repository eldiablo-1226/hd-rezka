#!/usr/bin/env python3
"""Condense Hopper pseudocode of Swift functions into a readable digest.

- decodes Swift small-string immediates (e.g. 0x2f2f3a7370747468 -> "https://")
- drops ARC/stack noise and plain register shuffles
- collapses repeated lines

usage: digest.py <file.c> [...]   (prints to stdout)
"""
import re
import sys

NOISE = re.compile(
    r"swift_(retain|release|bridgeObject|unknownObject|beginAccess|endAccess|task_dealloc|allocObject|initStackObject"
    r"|deallocObject|setDeallocating|isUniquelyReferenced|arrayDestroy|willThrow|errorRetain|errorRelease)"
    r"|objc_(retain|release|autorelease|msgSend\$retain)|outlined (destroy|copy|init|retain|release)"
    r"|___chkstk|___swift_destroy_boxed|___swift_allocate_boxed|___swift_instantiateConcreteType"
    r"|value witness|\[r\d+ release\]|\[r\d+ retain\]|_swift_stdlib_|swift_getObjectType"
    r"|lazy protocol witness table accessor|type metadata accessor|___stack_chk"
)
SHUFFLE = re.compile(r"^\s*(r\d+|var_\w+|decomp_var_\w+|q\d+|d\d+|s\d+|saved_fp|\*\(.*\)|r\d+\[0x[0-9a-f]+\])\s*=\s*"
                     r"(r\d+|var_\w+|decomp_var_\w+|q\d+|d\d+|s\d+|r31|r29|r30|0x0|&var_\w+|r\d+ \+ 0x[0-9a-f]+"
                     r"|r\d+\[0x[0-9a-f]+\]|r31 [-+] 0x[0-9a-f]+|r29 \| 0x[0-9a-f]+|\*r\d+)\s*;\s*$")
HEX = re.compile(r"0x[0-9a-f]{5,16}\b")


def small(v):
    b = v.to_bytes(8, "little")
    top = b[7]
    if top >> 4 in (0xE, 0xA) and v >> 56 != 0:  # second word of a small string
        n = top & 0x0F
        b = b[: max(0, min(7, n - 8))] if n > 8 else b[:0]
        if not b:
            return None
    else:
        b = b.rstrip(b"\0")
    if len(b) < 2:
        return None
    try:
        s = b.decode("utf-8")
    except UnicodeDecodeError:
        return None
    if all(c.isprintable() for c in s) and sum(c.isalnum() or c in " ./:-_?=&%#[]{}()<>,;'@!*+" for c in s) >= len(s) * 0.8:
        return s
    return None


def annotate(line):
    def rep(m):
        s = small(int(m.group(0), 16))
        return f'{m.group(0)}/*"{s}"*/' if s else m.group(0)
    return HEX.sub(rep, line)


def main():
  for path in sys.argv[1:]:
      lines = open(path, encoding="utf-8", errors="replace").read().split("\n")
      print(f"===== {lines[0][3:]}")
      prev = None
      for ln in lines[2:]:
          if not ln.strip() or NOISE.search(ln) or SHUFFLE.match(ln):
              continue
          ln = annotate(ln.rstrip())
          key = ln.strip()
          if key == prev:
              continue
          prev = key
          print(ln)


if __name__ == "__main__":
    main()
