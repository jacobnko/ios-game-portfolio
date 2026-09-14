#!/usr/bin/env bash
# Verifies CoreKit on both the host (fast unit tests) and iOS (platform code paths).
#
# The host run cannot compile anything behind `#if canImport(UIKit)`, so an iOS
# build is required before claiming a change works. Run this before every commit.
set -euo pipefail

PKG="$(cd "$(dirname "$0")/../Packages/CoreKit" && pwd)"
DD="${TMPDIR:-/tmp}/corekit-dd"

echo "=== 1/2  swift test (host) ==="
swift test --package-path "$PKG" 2>&1 | tail -3

echo
echo "=== 2/2  xcodebuild (generic/platform=iOS) ==="
xcodebuild -scheme CoreKit-Package \
           -destination 'generic/platform=iOS' \
           -derivedDataPath "$DD" \
           -quiet build 2>&1 \
  | grep -E "error:|warning:|BUILD" || true

echo
echo "done."
