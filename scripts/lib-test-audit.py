import pathlib, re, sys
root = pathlib.Path(sys.argv[1]) / "Tests"
issues, total = [], 0
for path in sorted(root.rglob("*.swift")):
    for part in re.split(r'\n(?=@Test)', path.read_text()):
        if not part.lstrip().startswith("@Test"):
            continue
        m = re.search(r'func (\w+)', part)
        if not m:
            continue
        total += 1
        expects = re.findall(r'#expect\(([^\n]*)', part)
        if not expects and "Issue.record" not in part:
            issues.append((path.name, m.group(1), "no assertion"))
            continue
        for e in expects:
            e = e.strip().rstrip(')')
            mm = re.match(r'^(.*?)\s*==\s*(.*)$', e)
            if mm and mm.group(1).strip() and mm.group(1).strip() == mm.group(2).strip():
                issues.append((path.name, m.group(1), f"tautology: {e[:40]}"))
for f, n, why in issues:
    print(f"    x {f} :: {n} - {why}")
sys.exit(1 if issues else 0)
