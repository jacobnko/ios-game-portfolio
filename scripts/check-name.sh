#!/usr/bin/env bash
# Checks whether a candidate game name already exists on the App Store.
# Usage: ./scripts/check-name.sh "Pipely" [country]
set -euo pipefail

NAME="${1:?usage: check-name.sh \"Game Name\" [country]}"
COUNTRY="${2:-us}"

echo "=== App Store search: \"$NAME\" ($COUNTRY) ==="
curl -sG "https://itunes.apple.com/search" \
  --data-urlencode "term=$NAME" \
  --data-urlencode "country=$COUNTRY" \
  --data-urlencode "entity=software" \
  --data-urlencode "limit=15" \
| python3 -c '
import json, sys
d = json.load(sys.stdin)
results = d.get("results", [])
if not results:
    print("no results — name space looks open")
    sys.exit(0)
target = sys.argv[1].strip().lower()
for r in results:
    name = r.get("trackName", "")
    exact = "  <== EXACT MATCH" if name.strip().lower() == target else ""
    print(f'"'"'{name[:52]:<52} | {r.get("sellerName","")[:26]:<26} | {r.get("primaryGenreName","")}{exact}'"'"')
' "$NAME"
