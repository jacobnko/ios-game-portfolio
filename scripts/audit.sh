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
# Same idea, one level down: every game's own full-screen gameplay views
# (GeometryReader + Canvas + gesture wiring) live under Sources/*UI/Views/ by
# convention — see docs/architecture/new-game-setup.md. The logic behind them
# (layout math, path/style builders) stays outside that folder and stays held
# to the floor; only the SwiftUI assembly itself is exempt.
GAME_DEVICE_ONLY='UI/Views/'
# 80 rather than 90: a file may legitimately hold one or two calls that cannot run
# off a device (UIApplication.open, for example). Anything below this is a real gap,
# and the uncovered function names are printed so the number is actionable.
COVERAGE_FLOOR=80

section "1/7  Build, tests, product checks"
"$ROOT/scripts/verify.sh" 2>&1 | grep -E "Test run|BUILD|MISSING|ok " | sed 's/^/  /'
"$ROOT/scripts/verify.sh" 2>&1 | grep -q "BUILD FAILED" && fail "a build failed" || pass "builds and tests"

section "2/7  Warnings treated as errors"
if swift build --package-path "$PKG" -Xswiftc -warnings-as-errors 2>&1 | grep -q "error:"; then
    fail "warnings present"
else
    pass "no warnings"
fi

section "3/7  Static analyser"
if ( cd "$PKG" && xcodebuild analyze -scheme CoreKit-Package -destination 'generic/platform=iOS' \
        -derivedDataPath "${TMPDIR:-/tmp}/ck-analyze" 2>&1 | grep -q "ANALYZE SUCCEEDED" ); then
    pass "analyze succeeded"
else
    fail "analyze failed"
fi

section "4/7  Coverage floor (${COVERAGE_FLOOR}% on host-testable code)"
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

section "5/7  Test suite audit"
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

section "6/7  Hazard patterns"
HAZARD_ROOTS=("$ROOT/Packages"/*/Sources/)
for gameSources in "$ROOT/Apps"/*/Sources/; do
    [ -d "$gameSources" ] && HAZARD_ROOTS+=("$gameSources")
done
HAZARDS=$(grep -rnE 'try!|fatalError|as!|UIScreen\.main|DispatchQueue|assumeIsolated|removeAllPendingNotificationRequests' \
    --include="*.swift" "${HAZARD_ROOTS[@]}" 2>/dev/null | grep -v '^\s*//' | grep -vE '^\S+:\s*[0-9]+:\s*//')
if [ -n "$HAZARDS" ]; then
    echo "$HAZARDS" | sed 's/^/  ✗ /' | cut -c1-140
    fail "hazard patterns present"
else
    pass "none"
fi

section "7/7  Game packages"
# Games live in their own repositories (docs/architecture/repo-strategy.md), but
# their logic is where the puzzle rules live — it gets the same treatment as
# CoreKit rather than being audited by eye.
GAME_COUNT=0
for manifest in "$ROOT/Apps"/*/Package.swift; do
    [ -f "$manifest" ] || continue
    GAME_DIR="$(dirname "$manifest")"
    GAME_NAME="$(basename "$GAME_DIR")"
    GAME_COUNT=$((GAME_COUNT + 1))

    GAME_TESTS=$(swift test --package-path "$GAME_DIR" --enable-code-coverage 2>&1)
    if echo "$GAME_TESTS" | grep -q "Test run with .* passed"; then
        pass "$GAME_NAME — $(echo "$GAME_TESTS" | grep -o 'Test run with [0-9]* tests' | tail -1)"
    else
        fail "$GAME_NAME tests failed"
        echo "$GAME_TESTS" | grep -E "error:|recorded an issue" | head -5 | sed 's/^/      /'
        continue
    fi

    GAME_PROF=$(find "$GAME_DIR/.build" -name "*.profdata" 2>/dev/null | head -1)
    GAME_XCTEST=$(find "$GAME_DIR/.build" -name "*PackageTests.xctest" 2>/dev/null | head -1)
    if [ -n "$GAME_PROF" ] && [ -n "$GAME_XCTEST" ]; then
        GAME_BIN="$GAME_XCTEST/Contents/MacOS/$(basename "$GAME_XCTEST" .xctest)"
        # The trailing source path restricts the report to this game's own files.
        # Without it a game that depends on CoreKit reports CoreKit's sources too,
        # which read as 0% here because they are covered by CoreKit's tests in
        # section 4, not by the game's.
        GAME_LOW=$(xcrun llvm-cov report "$GAME_BIN" -instr-profile "$GAME_PROF" \
                     -ignore-filename-regex="Tests|\.build" "$GAME_DIR/Sources" 2>/dev/null \
          | sed 's|.*Sources/||' | awk -v floor="$COVERAGE_FLOOR" -v skip="$GAME_DEVICE_ONLY" '
            NF > 5 && $1 !~ /^(Filename|-|TOTAL)/ {
                pct = $4; sub(/%/, "", pct)
                if ($1 ~ skip) next
                if (pct + 0 < floor) printf "%s %s\n", $1, pct
            }')
        if [ -n "$GAME_LOW" ]; then
            echo "$GAME_LOW" | sed 's/^/    x /'
            fail "$GAME_NAME below the coverage floor"
        else
            echo "    ok  coverage at or above ${COVERAGE_FLOOR}%"
        fi
    fi

    if python3 "$ROOT/scripts/lib-test-audit.py" "$GAME_DIR"; then
        echo "    ok  no weak assertions"
    else
        fail "$GAME_NAME has weak tests"
    fi
done
if [ "$GAME_COUNT" -eq 0 ]; then echo "  (none yet)"; fi

echo
if [ "$FAILURES" -eq 0 ]; then
    echo "═══ mechanical checks passed. Now do the reading pass — docs/AUDIT.md §4."
else
    echo "═══ $FAILURES check(s) failed."
fi
exit "$FAILURES"
