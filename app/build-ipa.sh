#!/bin/sh
# usage: ./build-ipa.sh
# Unsigned Release IPA in $BUILD_ROOT/ipa/HDrezka.ipa (default BUILD_ROOT: the repo's .build), log in $BUILD_ROOT/ipa.log.
# AltStore, SideStore, Sideloadly or TrollStore sign it on install. CI runs this too (.github/workflows/release-ipa.yml).
cd "$(dirname "$0")" || exit 1
BUILD_ROOT=${BUILD_ROOT:-$(cd .. && pwd)/.build}
OUT=$BUILD_ROOT/ipa
./regen.sh || exit 1
rm -rf "$OUT" && mkdir -p "$OUT/Payload" || exit 1
xcodebuild archive -project HDrezka.xcodeproj -scheme HDrezka -configuration Release -destination 'generic/platform=iOS' \
  -archivePath "$OUT/HDrezka.xcarchive" -derivedDataPath "$BUILD_ROOT/dd-ipa" -clonedSourcePackagesDirPath "$BUILD_ROOT/spm" \
  -disableAutomaticPackageResolution CODE_SIGNING_ALLOWED=NO > "$BUILD_ROOT/ipa.log" 2>&1 || {
  grep -E 'error:' "$BUILD_ROOT/ipa.log" | sort -u | tail -40; tail -3 "$BUILD_ROOT/ipa.log"; exit 1
}
cp -R "$OUT/HDrezka.xcarchive/Products/Applications/HDrezka.app" "$OUT/Payload/" || exit 1
(cd "$OUT" && zip -qry HDrezka.ipa Payload) || exit 1
echo "$OUT/HDrezka.ipa"
