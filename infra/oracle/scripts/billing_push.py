#!/usr/bin/env python3
"""Pousse un instantané de facturation vers la VM (repli sans droit IAM).

À lancer depuis un poste qui possède ~/.oci/config (le PC de Maxime, ou
l'environnement de l'agent) — la VM, elle, ne reçoit qu'un fichier JSON de
quelques lignes, jamais une clé.

    python3 infra/oracle/scripts/billing_push.py            # relève + pousse
    python3 infra/oracle/scripts/billing_push.py --dry-run  # relève seulement

Dès que le droit `read usage-report` est accordé au dynamic group de la VM,
ce script devient inutile : la sonde interroge Oracle directement (source=live).
"""
from __future__ import annotations

import argparse
import base64
import datetime as dt
import json
import subprocess
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent


def collect() -> dict:
    import oci

    cfg = oci.config.from_file()
    client = oci.usage_api.UsageapiClient(cfg)
    now = dt.datetime.now(dt.timezone.utc)
    start = now.replace(day=1, hour=0, minute=0, second=0, microsecond=0)
    end = (start + dt.timedelta(days=32)).replace(day=1)
    resp = client.request_summarized_usages(
        oci.usage_api.models.RequestSummarizedUsagesDetails(
            tenant_id=cfg["tenancy"], time_usage_started=start, time_usage_ended=end,
            granularity="MONTHLY", query_type="COST", group_by=["service"]))
    services, total, currency = [], 0.0, "EUR"
    for it in resp.data.items:
        amount = float(it.computed_amount or 0.0)
        total += amount
        currency = it.currency or currency
        if amount:
            services.append({"name": it.service or "?", "amount": round(amount, 4)})
    services.sort(key=lambda s: -s["amount"])
    return {"t": now.strftime("%Y-%m-%dT%H:%M:%SZ"), "source": "snapshot",
            "month": start.strftime("%Y-%m"), "total": round(total, 4),
            "currency": currency, "services": services, "error": None}


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--dry-run", action="store_true")
    args = ap.parse_args()

    data = collect()
    print(f"{data['total']} {data['currency']} ce mois ({data['month']})")
    if args.dry_run:
        return 0

    blob = base64.b64encode(json.dumps(data, ensure_ascii=False).encode()).decode()
    cmd = (f"mkdir -p ~/.cache/merlin-agents && echo '{blob}' | base64 -d "
           f"> ~/.cache/merlin-agents/billing-snapshot.json && "
           f"bash ~/workspace/M.E.R.L.I.N/infra/oracle/agents/agent-run.sh billing 2>&1 | tail -1")
    res = subprocess.run([sys.executable, str(HERE / "agent_takeover.py"), "--cmd", cmd,
                          "--timeout", "180"], capture_output=True, text=True)
    print(res.stdout.strip().splitlines()[-1] if res.stdout.strip() else res.stderr[-300:])
    return res.returncode


if __name__ == "__main__":
    sys.exit(main())
