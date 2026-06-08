"""Generation + envoi de l'alerte email quotidienne (via API Resend).

Deux responsabilites separees pour la testabilite :
  - build_email(snapshot, history) -> (subject, html_body)   [pur, sans reseau]
  - send_via_resend(...)            -> POST https://api.resend.com/emails

Resend : 1 cle API (RESEND_API_KEY). Sans domaine verifie, l'expediteur
`onboarding@resend.dev` ne peut ecrire qu'a l'adresse du titulaire du compte ;
pour des destinataires externes, verifier un domaine et fixer MAIL_FROM.
"""

from __future__ import annotations

import json
import urllib.error
import urllib.request
from html import escape

RESEND_ENDPOINT = "https://api.resend.com/emails"


class EmailError(RuntimeError):
    pass


def _fmt_stops(n) -> str:
    return "?" if n is None or n < 0 else str(n)


def _fmt_carriers(carriers) -> str:
    return ", ".join(carriers) if carriers else "n/a"


def _trend_delta(best: dict | None, history: list[dict]) -> float | None:
    """Variation du meilleur prix vs le releve precedent (history hors run courant)."""
    if not best:
        return None
    prev = next((r["best"] for r in reversed(history[:-1]) if r.get("best")), None) if history else None
    if not prev:
        return None
    return round(best["price"] - prev["price"], 2)


def build_subject(snapshot: dict, history: list[dict]) -> str:
    best = snapshot.get("best")
    dest = snapshot.get("config", {}).get("destination", "RUN")
    day = snapshot.get("ts", "")[:10]
    if not best:
        return f"✈️ Vols -> {dest} : aucune offre ce jour ({day})"
    delta = _trend_delta(best, history)
    cur = best["currency"]
    base = f"✈️ {dest} {best['price']:.0f}{cur} · {best['origin']} {best['depart']}→{best['return_date']}"
    if delta is not None and delta < 0:
        base = f"🔻 -{abs(delta):.0f}{cur} · " + base
    elif delta is not None and delta > 0:
        base = f"🔺 +{delta:.0f}{cur} · " + base
    return f"{base} — {day}"


def _best_by_origin(quotes: list[dict]) -> dict:
    out: dict[str, dict] = {}
    for q in quotes:
        o = q["origin"]
        if o not in out or q["price"] < out[o]["price"]:
            out[o] = {"price": q["price"], "depart": q["depart"], "return_date": q["return_date"]}
    return out


def build_html(snapshot: dict, history: list[dict]) -> str:
    best = snapshot.get("best")
    cfg = snapshot.get("config", {})
    dest = cfg.get("destination", "RUN")
    day = snapshot.get("ts", "")[:16].replace("T", " ")
    search = escape(snapshot.get("search", ""))

    css_table = (
        "border-collapse:collapse;width:100%;font-size:13px;"
        "font-family:Arial,Helvetica,sans-serif;"
    )
    th = "background:#0b3d2e;color:#fff;text-align:left;padding:6px 8px;"
    td = "border-bottom:1px solid #e0e0e0;padding:6px 8px;"

    parts: list[str] = []
    parts.append(
        '<div style="font-family:Arial,Helvetica,sans-serif;max-width:680px;margin:auto;'
        'color:#1a1a1a;">'
    )
    parts.append(
        f'<h2 style="color:#0b3d2e;margin:0 0 4px;">✈️ Suivi prix vols → La Réunion ({escape(dest)})</h2>'
    )
    parts.append(f'<p style="color:#666;margin:0 0 16px;font-size:13px;">Relevé du {escape(day)} · {search}</p>')

    if not best:
        parts.append(
            '<p style="background:#fff3cd;border:1px solid #ffe69c;padding:12px;border-radius:6px;">'
            "Aucune offre trouvée sur cette fenêtre aujourd'hui (source keyless : Google a pu "
            "limiter les requêtes). Le suivi reprend demain.</p>"
        )
        parts.append("</div>")
        return "".join(parts)

    cur = best["currency"]
    delta = _trend_delta(best, history)
    if delta is None:
        trend_html = '<span style="color:#888;">(1er relevé)</span>'
    elif delta < 0:
        trend_html = f'<span style="color:#1a7f37;font-weight:bold;">▼ {delta:.0f} {cur} vs hier</span>'
    elif delta > 0:
        trend_html = f'<span style="color:#c0392b;font-weight:bold;">▲ +{delta:.0f} {cur} vs hier</span>'
    else:
        trend_html = '<span style="color:#888;">= stable vs hier</span>'

    # Carte "meilleur combo"
    parts.append(
        '<div style="background:#0b3d2e;color:#fff;border-radius:10px;padding:18px 20px;margin-bottom:18px;">'
        f'<div style="font-size:34px;font-weight:bold;line-height:1;">{best["price"]:.0f} {cur}</div>'
        f'<div style="font-size:15px;margin-top:6px;">{escape(best["origin"])} → {escape(best["destination"])}'
        f' &nbsp;·&nbsp; {escape(best["depart"])} → {escape(best["return_date"])}</div>'
        f'<div style="font-size:13px;margin-top:6px;opacity:.9;">'
        f'Escales A/R : {_fmt_stops(best["stops_out"])}/{_fmt_stops(best["stops_in"])}'
        f' &nbsp;·&nbsp; {escape(_fmt_carriers(best["carriers"]))}</div>'
        f'<div style="font-size:13px;margin-top:8px;">{trend_html}</div>'
        "</div>"
    )

    # Top 10
    quotes = snapshot.get("quotes", [])
    parts.append('<h3 style="color:#0b3d2e;margin:18px 0 8px;">Top 10 des combos les moins chers</h3>')
    parts.append(f'<table style="{css_table}"><tr>'
                 f'<th style="{th}">#</th><th style="{th}">Prix</th><th style="{th}">Origine</th>'
                 f'<th style="{th}">Aller</th><th style="{th}">Retour</th>'
                 f'<th style="{th}">Esc. A/R</th><th style="{th}">Compagnies</th></tr>')
    for i, q in enumerate(quotes[:10], 1):
        row_bg = "background:#f4f8f6;" if i % 2 == 0 else ""
        parts.append(
            f'<tr style="{row_bg}"><td style="{td}">{i}</td>'
            f'<td style="{td}"><b>{q["price"]:.0f} {q["currency"]}</b></td>'
            f'<td style="{td}">{escape(q["origin"])}</td>'
            f'<td style="{td}">{escape(q["depart"])}</td>'
            f'<td style="{td}">{escape(q["return_date"])}</td>'
            f'<td style="{td}">{_fmt_stops(q["stops_out"])}/{_fmt_stops(q["stops_in"])}</td>'
            f'<td style="{td}">{escape(_fmt_carriers(q["carriers"]))}</td></tr>'
        )
    parts.append("</table>")

    # Meilleur par origine
    bbo = _best_by_origin(quotes)
    parts.append('<h3 style="color:#0b3d2e;margin:18px 0 8px;">Meilleur prix par aéroport</h3>')
    parts.append(f'<table style="{css_table}"><tr>'
                 f'<th style="{th}">Origine</th><th style="{th}">Prix</th>'
                 f'<th style="{th}">Aller</th><th style="{th}">Retour</th></tr>')
    for origin, info in sorted(bbo.items(), key=lambda kv: kv[1]["price"]):
        parts.append(
            f'<tr><td style="{td}">{escape(origin)}</td>'
            f'<td style="{td}"><b>{info["price"]:.0f} {cur}</b></td>'
            f'<td style="{td}">{escape(info["depart"])}</td>'
            f'<td style="{td}">{escape(info["return_date"])}</td></tr>'
        )
    parts.append("</table>")

    # Tendance
    rows = [r for r in history if r.get("best")][-14:]
    if len(rows) > 1:
        parts.append('<h3 style="color:#0b3d2e;margin:18px 0 8px;">Tendance du meilleur prix</h3>')
        parts.append(f'<table style="{css_table}"><tr>'
                     f'<th style="{th}">Relevé</th><th style="{th}">Meilleur prix</th>'
                     f'<th style="{th}">Origine</th><th style="{th}">Aller</th></tr>')
        for r in rows:
            b = r["best"]
            parts.append(
                f'<tr><td style="{td}">{escape(r["ts"][:16].replace("T", " "))}</td>'
                f'<td style="{td}">{b["price"]:.0f} {b["currency"]}</td>'
                f'<td style="{td}">{escape(b["origin"])}</td>'
                f'<td style="{td}">{escape(b["depart"])}</td></tr>'
            )
        parts.append("</table>")

    parts.append(
        '<p style="color:#888;font-size:12px;margin-top:22px;border-top:1px solid #e0e0e0;padding-top:10px;">'
        "Prix indicatifs (source keyless Google Flights) — confirmez toujours sur le site de la "
        "compagnie avant de réserver. Alerte générée automatiquement par tools/flight_tracker.</p>"
    )
    parts.append("</div>")
    return "".join(parts)


def build_email(snapshot: dict, history: list[dict]) -> tuple[str, str]:
    """Retourne (subject, html_body)."""
    return build_subject(snapshot, history), build_html(snapshot, history)


def send_via_resend(
    api_key: str,
    mail_from: str,
    recipients: list[str],
    subject: str,
    html: str,
    timeout: int = 20,
) -> dict:
    """Envoie l'email via l'API Resend. Leve EmailError en cas d'echec."""
    if not api_key:
        raise EmailError("RESEND_API_KEY manquant.")
    if not recipients:
        raise EmailError("Aucun destinataire (MAIL_TO vide).")
    payload = json.dumps(
        {"from": mail_from, "to": recipients, "subject": subject, "html": html}
    ).encode()
    req = urllib.request.Request(
        RESEND_ENDPOINT,
        data=payload,
        headers={
            "Authorization": f"Bearer {api_key}",
            "Content-Type": "application/json",
        },
        method="POST",
    )
    try:
        with urllib.request.urlopen(req, timeout=timeout) as resp:
            return json.loads(resp.read().decode() or "{}")
    except urllib.error.HTTPError as exc:
        raise EmailError(f"Resend {exc.code}: {exc.read().decode()[:300]}") from exc
    except urllib.error.URLError as exc:
        raise EmailError(f"Reseau indisponible pour Resend: {exc}") from exc
