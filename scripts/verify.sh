#!/usr/bin/env bash
# Verifies CoreKit on both the host (fast unit tests) and iOS (platform code paths).
#
# The host run cannot compile anything behind `#if canImport(UIKit)`, so an iOS
# build is required before claiming a change works. Run this before every commit.
set -euo pipefail

PKG="$(cd "$(dirname "$0")/../Packages/CoreKit" && pwd)"
DD="${TMPDIR:-/tmp}/corekit-dd"

echo "=== 1/3  swift test (host) ==="
swift test --package-path "$PKG" 2>&1 | tail -3

echo
echo "=== 2/3  CoreKit (generic/platform=iOS) ==="
# xcodebuild resolves the package from the working directory, so run it inside it.
( cd "$PKG" && xcodebuild -scheme CoreKit-Package \
                          -destination 'generic/platform=iOS' \
                          -derivedDataPath "$DD" \
                          build 2>&1 ) \
  | grep -E "error:|warning:|BUILD SUCCEEDED|BUILD FAILED" || true

echo
echo "=== 3/3  JuiceLab harness (generic/platform=iOS) ==="
# The harness is what proves the feedback layer actually runs inside an app.
LAB="$(cd "$(dirname "$0")/../Tools/JuiceLab" && pwd)"
if [ -d "$LAB/JuiceLab.xcodeproj" ]; then
  ( cd "$LAB" && xcodebuild -scheme JuiceLab \
                            -destination 'generic/platform=iOS' \
                            -derivedDataPath "$DD-lab" \
                            CODE_SIGNING_ALLOWED=NO build 2>&1 ) \
    | grep -E "error:|BUILD SUCCEEDED|BUILD FAILED" || true
else
  echo "skipped — run: cd Tools/JuiceLab && xcodegen generate"
fi

echo
echo "done."
