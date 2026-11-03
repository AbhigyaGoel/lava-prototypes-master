#!/usr/bin/env bash
# Runs the demo flow end to end against a running server in mock mode.
# Usage: scripts/demo-check.sh [base url]   (default http://localhost:3000)
set -euo pipefail
B=${1:-http://localhost:3000}
p() { curl -s -X POST -H content-type:application/json "$B$1" -d "$2"; }
field() { python3 -c "import sys,json;print(json.load(sys.stdin)['$1'])"; }
pan_from() { curl -s "$1" | python3 -c 'import sys,re;h=sys.stdin.read();m=re.search(r"class=\"pan\">([\d ]{19})<",h);print(m.group(1).replace(" ","") if m else "")'; }
# Build JSON with printf: a literal {"a":..,"b":..} inside "$(...)" can be brace-expanded by bash into several requests.
buy() { p /api/dev/simulate "$(printf '{"pan":"%s","amount":"%s","merchant":"%s"}' "$1" "$2" "$3")"; }
check() { [ $# -eq 3 ] || { echo "FAIL  $1: check got $# args (quoting bug)"; FAILED=1; return; }; if echo "$2" | grep -q "$3"; then echo "PASS  $1"; else echo "FAIL  $1: $2"; FAILED=1; fi; }
FAILED=0

check "connect bank" "$(p /api/plaid/exchange '{}')" '"availableCents":124000'

R=$(p /api/cards '{"amount":"700","purpose":"GBM food","recipientName":"Jordan Lee","recipientContact":"jordan@usc.edu","expiryDays":7}')
check "make \$700 card" "$R" '"link"'
LINK=$(echo "$R" | field link); CARD=$(echo "$R" | field cardId)
PAN=$(pan_from "$LINK")
check "officer page shows card" "$(curl -s "$LINK")" "NSBE at USC sent you a card"

check "T4 \$612.40 approved" "$(buy "$PAN" 612.40 "Raising Cane's")" '"decision":"APPROVED"'
check "T5 second use declined" "$(buy "$PAN" 5 "Raising Cane's")" 'already used or closed'
check "link closed after use" "$(curl -s "$LINK")" "This card has closed"
check "T2 \$1,000 blocked (\$627.60 free)" "$(p /api/cards '{"amount":"1000","purpose":"Hotel","recipientName":"Aisha Khan","recipientContact":"aisha@usc.edu"}')" 'Up to \$627.60'

R2=$(p /api/cards '{"amount":"500","purpose":"Tabling supplies","recipientName":"Aisha Khan","recipientContact":"aisha@usc.edu"}')
L2=$(echo "$R2" | field link); C2=$(echo "$R2" | field cardId); PAN2=$(pan_from "$L2")
p /api/dev/balance '{"amount":"300"}' >/dev/null
check "T7 balance dropped -> declined" "$(buy "$PAN2" 400 "Amazon")" 'Club balance too low'
p /api/dev/balance '{"amount":"2000"}' >/dev/null
check "T6 \$501 on \$500 card declined" "$(buy "$PAN2" 501 "Amazon")" 'Over the card limit'
check "cancel card" "$(p /api/cards/$C2/cancel '{}')" '"cancelled":true'
check "T12 cancelled card declined" "$(buy "$PAN2" 10 "Amazon")" 'already used or closed'
check "T12 cancelled link closed" "$(curl -s "$L2")" "This card has closed"
check "unsigned ASA rejected" "$(curl -s -o /dev/null -w '%{http_code}' -X POST $B/api/lithic/asa -d '{"token":"x"}')" '401'

check "purchases feed lists declines" "$(curl -s "$B/purchases?status=declined")" 'Over the \$500 card limit'
check "CSV export" "$(curl -s "$B/api/purchases/export?days=all")" "Raising Cane's"

for u in /home /setup /cards /cards/new /cards/$CARD /cards/$C2 /purchases /settings; do
  code=$(curl -s -o /dev/null -w "%{http_code}" "$B$u")
  [[ "$code" == 200 ]] && echo "PASS  page $u ($code)" || { echo "FAIL  page $u ($code)"; FAILED=1; }
done
check "app opens on Home (seeded club + bank)" "$(curl -s -o /dev/null -w '%{redirect_url}' $B/)" '/home'
for u in /checkout /c/not-a-real-link; do
  code=$(curl -s -o /dev/null -w "%{http_code}" "$B$u")
  [[ "$code" == 200 ]] && echo "PASS  page $u ($code)" || { echo "FAIL  page $u ($code)"; FAILED=1; }
done
exit $FAILED
