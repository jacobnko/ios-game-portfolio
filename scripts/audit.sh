#!/usr/bin/env bash
# Runs every mechanical check from the phase audit playbook (docs/AUDIT.md).
#
# Slower than verify.sh and meant for the end of a phase, not for every commit.
# Everything here is automatable; the reading pass in docs/AUDIT.md §4 is not.
set -uo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PKG="$ROOT/Packages/CoreKit"
FAILURES=0

section() { echo; echo "═══ $1"; }
fail()    { echo "  ✗ $1"; FAILURES=$((FAILURES + 1)); }
pass()    { echo "  ✓ $1"; }

# Files that can only execute on a device. Excluded from the coverage floor
# because no host test can reach them — they are covered by docs/DEVICE-TEST.md.
DEVICE_ONLY='HapticEngine|PitchedTonePlayer|JuiceAudioSession|VictorySequence|NotificationScheduler|StoreKitClient|CoreKitAdsGoogle|CoreKitFirebase|CoreKitUI/Screens'
# 80 rather than 90: a file may legitimately hold one or two calls that cannot run
# off a device (UIApplication.open, for example). Anything below this is a real gap,
# and the uncovered function names are printed so the number is actionable.
COVERAGE_FLOOR=80

section "1/6  Build, tests, product checks"
"$ROOT/scripts/verify.sh" 2>&1 | grep -E "Test run|BUILD|MISSING|ok " | sed 's/^/  /'
"$ROOT/scripts/verify.sh" 2>&1 | grep -q "BUILD FAILED" && fail "a build failed" || pass "builds and tests"

section "2/6  Warnings treated as errors"
if swift build --package-path "$PKG" -Xswiftc -warnings-as-errors 2>&1 | grep -q "error:"; then
    fail "warnings present"
else
    pass "no warnings"
fi

section "3/6  Static analyser"
if ( cd "$PKG" && xcodebuild analyze -scheme CoreKit-Package -destination 'generic/platform=iOS' \
        -derivedDataPath "${TMPDIR:-/tmp}/ck-analyze" 2>&1 | grep -q "ANALYZE SUCCEEDED" ); then
    pass "analyze succeeded"
else
    fail "analyze failed"
fi

section "4/6  Coverage floor (${COVERAGE_FLOOR}% on host-testable code)"
swift test --package-path "$PKG" --enable-code-coverage >/dev/null 2>&1
PROF=$(find "$PKG/.build" -name "*.profdata" | head -1)
BIN=$(find "$PKG/.build" -name "CoreKitPackageTests.xctest" | head -1)/Contents/MacOS/CoreKitPackageTests
if [ -n "$PROF" ] && [ -f "$BIN" ]; then
    LOW=$(xcrun llvm-cov report "$BIN" -instr-profile "$PROF" -ignore-filename-regex="Tests|\.build" 2>/dev/null \
      | sed 's|.*Sources/||' | awk -v floor="$COVERAGE_FLOOR" -v skip="$DEVICE_ONLY" '
        NF > 5 && $1 !~ /^(Filename|-|TOTAL)/ {
            pct = $4; sub(/%/, "", pct)
            if ($1 ~ skip) next
            if (pct + 0 < floor) printf "%s %s\n", $1, pct
        }')
    if [ -n "$LOW" ]; then
        echo "$LOW" | while read -r file pct; do
            echo "  ✗ $file — ${pct}%, never executed:"
            xcrun llvm-cov report "$BIN" -instr-profile "$PROF" -show-functions \
                "$PKG/Sources/$file" 2>/dev/null \
              | awk '$2 == 0 { print "      " $1 }' | head -6
        done
        fail "files below the coverage floor"
    else
        pass "host-testable code at or above ${COVERAGE_FLOOR}%"
    fi
else
    fail "could not read coverage data"
fi

section "5/6  Test suite audit"
python3 - "$PKG" <<'PY'
import pathlib, re, sys
root = pathlib.Path(sys.argv[1]) / "Tests"
issues, total = [], 0
for path in sorted(root.rglob("*.swift")):
    for part in re.split(r'\n(?=@Test)', path.read_text()):
        if not part.lstrip().startswith("@Test"): continue
        m = re.search(r'func (\w+)', part)
        if not m: continue
        total += 1
        expects = re.findall(r'#expect\(([^\n]*)', part)
        if not expects and "Issue.record" not in part:
            issues.append((path.name, m.group(1), "no assertion")); continue
        for e in expects:
            e = e.strip().rstrip(')')
            mm = re.match(r'^(.*?)\s*==\s*(.*)$', e)
            if mm and mm.group(1).strip() and mm.group(1).strip() == mm.group(2).strip():
                issues.append((path.name, m.group(1), f"tautology: {e[:40]}"))
            if e in ("true", "false"):
                issues.append((path.name, m.group(1), f"constant: {e}"))
print(f"  {total} test functions inspected")
for f, n, why in issues:
    print(f"  ✗ {f} :: {n} — {why}")
sys.exit(1 if issues else 0)
PY
if [ $? -eq 0 ]; then pass "no weak assertions"; else fail "weak tests found"; fi

section "6/6  Hazard patterns"
HAZARDS=$(grep -rnE 'try!|fatalError|as!|UIScreen\.main|DispatchQueue|assumeIsolated|removeAllPendingNotificationRequests' \
    --include="*.swift" "$ROOT/Packages"/*/Sources/ 2>/dev/null | grep -v '^\s*//' | grep -vE '^\S+:\s*[0-9]+:\s*//')
if [ -n "$HAZARDS" ]; then
    echo "$HAZARDS" | sed 's/^/  ✗ /' | cut -c1-140
    fail "hazard patterns present"
else
    pass "none"
fi

echo
if [ "$FAILURES" -eq 0 ]; then
    echo "═══ mechanical checks passed. Now do the reading pass — docs/AUDIT.md §4."
else
    echo "═══ $FAILURES check(s) failed."
fi
exit "$FAILURES"
