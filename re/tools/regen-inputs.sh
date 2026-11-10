#!/bin/sh
# Recreate the large derived inputs used by the tools (not versioned): nm.txt, fixups.txt, disasm.txt.
# usage: re/tools/regen-inputs.sh <out_dir>   (needs ipa-extracted/ next to re/)
set -e
OUT=${1:?out_dir}; ROOT=$(cd "$(dirname "$0")/../.." && pwd)
BIN="$ROOT/ipa-extracted/Payload/HDRezka.app/HDrezka"
mkdir -p "$OUT"
nm "$BIN" > "$OUT/nm.txt"
dyld_info -fixups "$BIN" > "$OUT/fixups.txt"
otool -tV "$BIN" > "$OUT/disasm.txt"
echo "inputs written to $OUT"
