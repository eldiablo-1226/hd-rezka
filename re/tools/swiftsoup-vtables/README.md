# SwiftSoup vtable map

`vtables.tsv` maps class-method vtable offsets of SwiftSoup `Element`, `Elements` and `Document` (as embedded in
the binary, SwiftSoup 2.6.x) to method names. Use it to label pseudocode calls like `(*(*r20 + 0x370))(…)`.

`vtable.py` rebuilds the map; `cond.py <lo> <hi>` prints an annotated disassembly range. Both read `nm.txt`,
`fixups.txt` and `disasm.txt` from the path in their `SP` variable; recreate those with `../regen-inputs.sh <dir>`
and point `SP` there.
