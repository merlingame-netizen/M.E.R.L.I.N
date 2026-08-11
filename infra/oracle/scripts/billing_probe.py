#!/usr/bin/env python3
"""Sonde de facturation Oracle — tourne SUR LA VM, sans clé privée.

Deux sources, dans cet ordre :
  1. INSTANCE PRINCIPAL (live) — la VM s'authentifie par son identité de machine.
     Nécessite, une seule fois dans le tenancy :
       Allow dynamic-group merlin-run-command to read usage-report in tenancy
     Aucun secret n'est déposé sur la VM : c'est l'intérêt de cette voie.
  2. SNAPSHOT POUSSÉ (repli) — un instantané déposé par billing_push.py depuis
     un poste qui a la clé API. Affiché avec son âge, jamais présenté comme live.

Écrit ~/.cache/merlin-agents/billing.json. Ne lève jamais : un échec devient un
champ `error` — la facturation ne doit pas casser le portail.
"""
from __future__ import annotations

import datetime as dt
import json
import sys
from pathlib import Path

OUT = Path.home() / ".cache" / "merlin-agents" / "billing.json"
SNAP = Path.home() / ".cache" / "merlin-agents" / "billing-snapshot.json"


def _month_bounds(now: dt.datetime) -> tuple[dt.datetime, dt.datetime]:
    start = now.replace(day=1, hour=0, minute=0, second=0, microsecond=0)
    end = (start + dt.timedelta(days=32)).replace(day=1)
    return start, end


def fetch_live() -> dict:
    """Usage API via instance principal. Lève si le droit n'est pas accordé."""
    import oci

    signer = oci.auth.signers.InstancePrincipalsSecurityTokenSigner()
    client = oci.usage_api.UsageapiClient(config={}, signer=signer)
    now = dt.datetime.now(dt.timezone.utc)
    start, end = _month_bounds(now)
    resp = client.request_summarized_usages(
        oci.usage_api.models.RequestSummarizedUsagesDetails(
            tenant_id=signer.tenancy_id,
            time_usage_started=start,
            time_usage_ended=end,
            granularity="MONTHLY",
            query_type="COST",
            group_by=["service"],
        )
    )
    services, total, currency = [], 0.0, "EUR"
    for it in resp.data.items:
        amount = float(it.computed_amount or 0.0)
        total += amount
        currency = it.currency or currency
        if amount:
            services.append({"name": it.service or "?", "amount": round(amount, 4)})
    services.sort(key=lambda s: -s["amount"])
    return {
        "t": now.strftime("%Y-%m-%dT%H:%M:%SZ"),
        "source": "live",
        "month": start.strftime("%Y-%m"),
        "total": round(total, 4),
        "currency": currency,
        "services": services,
        "error": None,
    }


def main() -> int:
    OUT.parent.mkdir(parents=True, exist_ok=True)
    try:
        data = fetch_live()
    except Exception as exc:                      # droit absent, SDK absent, réseau…
        reason = f"{type(exc).__name__}: {exc}"[:200]
        if SNAP.exists():                          # repli : instantané poussé
            try:
                data = json.loads(SNAP.read_text(encoding="utf-8"))
                data["source"] = "snapshot"
                data["error"] = None
                data["live_error"] = reason
            except Exception as exc2:
                data = {"total": None, "error": f"snapshot illisible: {exc2}"[:200],
                        "source": "none"}
        else:
            data = {"total": None, "currency": "EUR", "services": [],
                    "source": "none", "error": reason,
                    "t": dt.datetime.now(dt.timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")}
    OUT.write_text(json.dumps(data, ensure_ascii=False, indent=1), encoding="utf-8")
    total = data.get("total")
    if total is None:
        print(f"facturation indisponible ({data.get('error', '?')})")
        return 1
    print(f"{total} {data.get('currency', '')} ce mois "
          f"(source={data.get('source')}, {len(data.get('services') or [])} service(s) facturé(s))")
    return 0


if __name__ == "__main__":
    sys.exit(main())
