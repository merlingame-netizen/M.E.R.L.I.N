"""Generation + envoi de l'alerte email quotidienne (Gmail SMTP).

Deux responsabilites separees pour la testabilite :
  - build_email(snapshot, history) -> (subject, html_body)   [pur, sans reseau]
  - send_via_smtp(...)              -> envoi SMTP (Gmail + App Password)
"""

from __future__ import annotations

import smtplib
from email.message import EmailMessage
from html import escape


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


def _price_stats(quotes: list[dict]) -> dict | None:
    """min / median / max + nb d'offres dans une fourchette de 50 du minimum."""
    prices = sorted(q["price"] for q in quotes if q.get("price"))
    if not prices:
        return None
    n = len(prices)
    mid = n // 2
    median = prices[mid] if n % 2 else (prices[mid - 1] + prices[mid]) / 2
    pmin = prices[0]
    return {
        "n": n,
        "min": pmin,
        "median": median,
        "max": prices[-1],
        "near_best": sum(1 for p in prices if p <= pmin + 50),
    }


def build_html(snapshot: dict, history: list[dict], top_n: int = 0) -> str:
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
        '<div style="background:#0b3d2e;color:#fff;border-radius:10px;padding:18px 20px;margin-bottom:14px;">'
        f'<div style="font-size:34px;font-weight:bold;line-height:1;">{best["price"]:.0f} {cur}</div>'
        f'<div style="font-size:15px;margin-top:6px;">{escape(best["origin"])} → {escape(best["destination"])}'
        f' &nbsp;·&nbsp; {escape(best["depart"])} → {escape(best["return_date"])}</div>'
        f'<div style="font-size:13px;margin-top:6px;opacity:.9;">'
        f'Escales A/R : {_fmt_stops(best["stops_out"])}/{_fmt_stops(best["stops_in"])}'
        f' &nbsp;·&nbsp; {escape(_fmt_carriers(best["carriers"]))}</div>'
        f'<div style="font-size:13px;margin-top:8px;">{trend_html}</div>'
        "</div>"
    )

    quotes = snapshot.get("quotes", [])

    # Bandeau statistiques
    stats = _price_stats(quotes)
    if stats:
        def _chip(label: str, value: str) -> str:
            return (
                '<td style="text-align:center;padding:8px 6px;background:#f4f8f6;'
                'border:1px solid #e0e0e0;border-radius:8px;">'
                f'<div style="font-size:18px;font-weight:bold;color:#0b3d2e;">{value}</div>'
                f'<div style="font-size:11px;color:#666;">{label}</div></td>'
            )
        parts.append(
            f'<table style="{css_table}border-spacing:6px;border-collapse:separate;margin-bottom:6px;"><tr>'
            + _chip("offres trouvées", str(stats["n"]))
            + _chip("le moins cher", f'{stats["min"]:.0f} {cur}')
            + _chip("prix médian", f'{stats["median"]:.0f} {cur}')
            + _chip("le plus cher", f'{stats["max"]:.0f} {cur}')
            + _chip(f'à moins de {stats["min"]+50:.0f} {cur}', str(stats["near_best"]))
            + "</tr></table>"
        )

    # Classement competitif de TOUTES les offres (top_n <= 0 = tout)
    shown = quotes if top_n <= 0 else quotes[:top_n]
    n_more = max(0, len(quotes) - len(shown))
    pmin = quotes[0]["price"] if quotes else 0.0
    medals = {1: "🥇", 2: "🥈", 3: "🥉"}
    if top_n <= 0 or n_more == 0:
        heading = f"Classement de toutes les offres ({len(quotes)})"
    else:
        heading = f"Top {len(shown)} des {len(quotes)} offres"
    parts.append(f'<h3 style="color:#0b3d2e;margin:14px 0 8px;">{heading}</h3>')
    parts.append(f'<table style="{css_table}"><tr>'
                 f'<th style="{th}">#</th><th style="{th}">Prix</th><th style="{th}">Δ vs meilleur</th>'
                 f'<th style="{th}">Origine</th><th style="{th}">Aller</th><th style="{th}">Retour</th>'
                 f'<th style="{th}">Esc. A/R</th><th style="{th}">Compagnies</th></tr>')
    for i, q in enumerate(shown, 1):
        gap = q["price"] - pmin
        if gap <= 0:
            gap_html = '<span style="color:#1a7f37;font-weight:bold;">meilleur</span>'
        else:
            pct = (gap / pmin * 100) if pmin else 0
            gap_html = f'<span style="color:#666;">+{gap:.0f} {cur} ({pct:.0f}%)</span>'
        rank = f'{medals.get(i, "")} {i}'.strip()
        row_bg = "background:#eef6f1;" if i <= 3 else ("background:#f7faf8;" if i % 2 == 0 else "")
        parts.append(
            f'<tr style="{row_bg}"><td style="{td}white-space:nowrap;">{rank}</td>'
            f'<td style="{td}"><b>{q["price"]:.0f} {q["currency"]}</b></td>'
            f'<td style="{td}">{gap_html}</td>'
            f'<td style="{td}">{escape(q["origin"])}</td>'
            f'<td style="{td}">{escape(q["depart"])}</td>'
            f'<td style="{td}">{escape(q["return_date"])}</td>'
            f'<td style="{td}">{_fmt_stops(q["stops_out"])}/{_fmt_stops(q["stops_in"])}</td>'
            f'<td style="{td}">{escape(_fmt_carriers(q["carriers"]))}</td></tr>'
        )
    parts.append("</table>")
    if n_more:
        parts.append(
            f'<p style="font-size:12px;color:#666;margin:6px 0 0;">'
            f'+ {n_more} autre(s) combo(s) au-delà de {shown[-1]["price"]:.0f} {cur} '
            f'(jusqu’à {quotes[-1]["price"]:.0f} {cur}).</p>'
        )

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


def build_email(snapshot: dict, history: list[dict], top_n: int = 0) -> tuple[str, str]:
    """Retourne (subject, html_body). top_n<=0 => classe TOUTES les offres."""
    return build_subject(snapshot, history), build_html(snapshot, history, top_n=top_n)


def build_mime(mail_from: str, recipients: list[str], subject: str, html: str) -> EmailMessage:
    """Construit le message multipart (texte + HTML) pour un envoi SMTP."""
    msg = EmailMessage()
    msg["From"] = mail_from
    msg["To"] = ", ".join(recipients)
    msg["Subject"] = subject
    msg.set_content(
        "Cette alerte est en HTML. Si vous voyez ce texte, votre client mail "
        "n'affiche pas le HTML — le meilleur prix figure dans l'objet du message."
    )
    msg.add_alternative(html, subtype="html")
    return msg


def send_via_smtp(
    host: str,
    port: int,
    username: str,
    password: str,
    mail_from: str,
    recipients: list[str],
    subject: str,
    html: str,
    timeout: int = 30,
) -> dict:
    """Envoie via SMTP (Gmail : smtp.gmail.com:465 + App Password). Leve EmailError si KO."""
    if not username or not password:
        raise EmailError("Identifiants SMTP manquants (MAIL_USERNAME / MAIL_PASSWORD).")
    if not recipients:
        raise EmailError("Aucun destinataire (MAIL_TO vide).")
    msg = build_mime(mail_from or username, recipients, subject, html)
    try:
        if int(port) == 465:
            with smtplib.SMTP_SSL(host, int(port), timeout=timeout) as srv:
                srv.login(username, password)
                srv.send_message(msg)
        else:
            with smtplib.SMTP(host, int(port), timeout=timeout) as srv:
                srv.starttls()
                srv.login(username, password)
                srv.send_message(msg)
    except (smtplib.SMTPException, OSError) as exc:
        raise EmailError(f"Envoi SMTP echoue ({host}:{port}): {exc}") from exc
    return {"recipients": recipients, "transport": "smtp"}
