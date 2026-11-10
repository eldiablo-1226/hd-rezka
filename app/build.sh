#!/bin/sh
# usage: ./build.sh <agent-tag> [test]
# Builds (or tests) into $BUILD_ROOT/dd-<tag> (default BUILD_ROOT: the repo's .build), log in $BUILD_ROOT/<tag>.log.
# Works from a private copy of app/ too: set BUILD_ROOT=/Users/<user>/Documents/Git/hd-rezka/.build there.
cd "$(dirname "$0")" || exit 1
BUILD_ROOT=${BUILD_ROOT:-$(cd .. && pwd)/.build}
TAG=${1:?tag}; ACTION=${2:-build}
[ -d "$BUILD_ROOT/dd-$TAG" ] || [ ! -d "$BUILD_ROOT/dd-main" ] || cp -R "$BUILD_ROOT/dd-main" "$BUILD_ROOT/dd-$TAG"
if [ "$ACTION" = test ]; then
  DEST="platform=iOS Simulator,id=${SIM_ID:?set SIM_ID to your assigned simulator UDID}"
  set -- test -only-testing:"HDrezkaTests${ONLY:+/$ONLY}"
else
  DEST='generic/platform=iOS Simulator'; set -- build
fi
xcodebuild -project HDrezka.xcodeproj -scheme HDrezka -destination "$DEST" \
  -derivedDataPath "$BUILD_ROOT/dd-$TAG" -clonedSourcePackagesDirPath "$BUILD_ROOT/spm" \
  -disableAutomaticPackageResolution -parallel-testing-enabled NO CODE_SIGNING_ALLOWED=NO "$@" > "$BUILD_ROOT/$TAG.log" 2>&1
rc=$?
grep -E 'error:|Test Case .*(passed|failed)|Executed [0-9]+ test|\*\* (BUILD|TEST) (SUCCEEDED|FAILED)' "$BUILD_ROOT/$TAG.log" | grep -v '^ ' | sort -u | tail -60
exit $rc
