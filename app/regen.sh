#!/bin/sh
# Regenerate HDrezka.xcodeproj after adding/removing source files (serialized with a lock).
cd "$(dirname "$0")" || exit 1
until mkdir /tmp/hdrezka-xcodegen.lock 2>/dev/null; do sleep 1; done
trap 'rmdir /tmp/hdrezka-xcodegen.lock' EXIT
xcodegen generate --quiet || exit 1
# Package.resolved is the tracked lockfile. Builds never resolve packages themselves, so every build, CI's included,
# gets these versions. After changing a package in project.yml, resolve once in Xcode and copy the new file back here.
mkdir -p HDrezka.xcodeproj/project.xcworkspace/xcshareddata/swiftpm
cp Package.resolved HDrezka.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/
