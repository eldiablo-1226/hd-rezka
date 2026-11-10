#!/bin/sh
# Regenerate HDrezka.xcodeproj after adding/removing source files (serialized with a lock).
cd "$(dirname "$0")" || exit 1
until mkdir /tmp/hdrezka-xcodegen.lock 2>/dev/null; do sleep 1; done
trap 'rmdir /tmp/hdrezka-xcodegen.lock' EXIT
xcodegen generate --quiet
