#!/usr/bin/env bash
# Run ON the GCP VM. Fetches the full Firebase Realtime Database with a service
# account and converts it to a SQLite file (full DB, incl. the big `states` table).
#
# Usage (on the VM):
#   curl -fsSL <raw-url-of-this-file> | bash -s ~/idrac-sa.json
# or:
#   bash vm_migrate.sh <path-to-firebase-sa.json> [out.db] [db-url]
set -euo pipefail

SA="${1:?usage: vm_migrate.sh <firebase-sa.json> [out.db] [db-url]}"
OUT="${2:-$HOME/atelier-idrac.db}"
DBURL="${3:-https://idrac-ai-academy-default-rtdb.europe-west1.firebasedatabase.app}"
BRANCH="claude/oracle-free-tier-access-IN1Wm"
RAW="https://raw.githubusercontent.com/merlingame-netizen/M.E.R.L.I.N/$BRANCH/infra/fleet/migrations/rtdb_to_sqlite.py"

echo "==> deps"
sudo apt-get update -y >/dev/null && sudo apt-get install -y python3-venv curl >/dev/null
python3 -m venv "$HOME/.idracvenv"
"$HOME/.idracvenv/bin/pip" install -q --upgrade pip google-auth requests

echo "==> fetch converter"
curl -fsSL "$RAW" -o /tmp/rtdb_to_sqlite.py

echo "==> fetch the Realtime Database (this can take a minute for a large DB)"
"$HOME/.idracvenv/bin/python" - "$SA" "$DBURL" <<'PY'
import sys, requests
import google.auth.transport.requests as gt
from google.oauth2 import service_account
sa, base = sys.argv[1], sys.argv[2]
scopes = ["https://www.googleapis.com/auth/firebase.database",
          "https://www.googleapis.com/auth/userinfo.email"]
c = service_account.Credentials.from_service_account_file(sa, scopes=scopes)
c.refresh(gt.Request())
r = requests.get(base + "/.json", headers={"Authorization": "Bearer " + c.token},
                 stream=True, timeout=900)
r.raise_for_status()
with open("/tmp/idrac.json", "wb") as f:
    for chunk in r.iter_content(1 << 16):
        f.write(chunk)
import os
print("  downloaded %.1f MB" % (os.path.getsize("/tmp/idrac.json") / 1048576))
PY

echo "==> convert to SQLite"
"$HOME/.idracvenv/bin/python" /tmp/rtdb_to_sqlite.py /tmp/idrac.json --db "$OUT" --sql /tmp/idrac.sql
rm -f /tmp/idrac.json   # don't leave the raw dump lying around
echo "==> done"
ls -lh "$OUT"
echo "Query it with:  sqlite3 $OUT 'SELECT _key,name,xp FROM students ORDER BY xp DESC LIMIT 5;'"
