#!/usr/bin/env bash
# Run ON the GCP VM. Fetches the full Firebase Realtime Database and converts it
# to a SQLite file (full DB, incl. the big `states` table).
#
# Two auth modes (no private key needs to touch the VM in token mode):
#   bash vm_migrate.sh --token "<bearer-token>"        # short-lived read token (recommended)
#   bash vm_migrate.sh <path-to-firebase-sa.json>      # service-account key on the VM
#
# Usage via the repo (one-liner):
#   curl -fsSL <raw-url> | bash -s -- --token "<bearer-token>"
set -euo pipefail

OUT="$HOME/atelier-idrac.db"
DBURL="https://idrac-ai-academy-default-rtdb.europe-west1.firebasedatabase.app"
BRANCH="claude/oracle-free-tier-access-IN1Wm"
RAW="https://raw.githubusercontent.com/merlingame-netizen/M.E.R.L.I.N/$BRANCH/infra/fleet/migrations/rtdb_to_sqlite.py"

MODE="" ; ARG=""
if [ "${1:-}" = "--token" ]; then MODE="token"; ARG="${2:?token required}"
elif [ -n "${1:-}" ]; then MODE="sa"; ARG="$1"
else echo "usage: vm_migrate.sh --token <tok> | <sa.json>"; exit 1; fi

echo "==> deps"
sudo apt-get update -y >/dev/null && sudo apt-get install -y python3-venv curl >/dev/null
# extra 4 GB swap for the conversion on a 1 GB box (idempotent)
if [ ! -f /swapfile2 ]; then
  sudo fallocate -l 4G /swapfile2 && sudo chmod 600 /swapfile2 && sudo mkswap /swapfile2 && sudo swapon /swapfile2 || true
fi
python3 -m venv "$HOME/.idracvenv"
"$HOME/.idracvenv/bin/pip" install -q --upgrade pip requests

echo "==> fetch converter"
curl -fsSL "$RAW" -o /tmp/rtdb_to_sqlite.py

echo "==> fetch the Realtime Database"
if [ "$MODE" = "token" ]; then
  curl -fsSL "$DBURL/.json" -H "Authorization: Bearer $ARG" -o /tmp/idrac.json
else
  "$HOME/.idracvenv/bin/pip" install -q google-auth
  "$HOME/.idracvenv/bin/python" - "$ARG" "$DBURL" <<'PY'
import sys, requests
import google.auth.transport.requests as gt
from google.oauth2 import service_account
sa, base = sys.argv[1], sys.argv[2]
c = service_account.Credentials.from_service_account_file(sa, scopes=[
    "https://www.googleapis.com/auth/firebase.database",
    "https://www.googleapis.com/auth/userinfo.email"])
c.refresh(gt.Request())
r = requests.get(base + "/.json", headers={"Authorization": "Bearer " + c.token}, stream=True, timeout=900)
r.raise_for_status()
open("/tmp/idrac.json", "wb").write(r.content)
PY
fi
echo "   downloaded $(du -h /tmp/idrac.json | cut -f1)"

echo "==> convert to SQLite"
"$HOME/.idracvenv/bin/python" /tmp/rtdb_to_sqlite.py /tmp/idrac.json --db "$OUT" --sql /tmp/idrac.sql
rm -f /tmp/idrac.json
echo "==> done"; ls -lh "$OUT"
echo "Try:  sqlite3 $OUT 'SELECT _key,name,xp FROM students ORDER BY xp DESC LIMIT 5;'"
echo "      sqlite3 $OUT 'SELECT _key, length(campaignData) FROM states;'"
