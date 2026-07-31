"""Coeur du traceur : balaye les combos, trouve le meilleur, journalise l'historique.

Sorties (dans tools/flight_tracker/data/) :
    price_history.jsonl   1 ligne JSON par run (snapshot complet compresse)
    latest_report.md      rapport lisible : meilleur combo + top 10 + tendance
    best_combo.json        dernier meilleur combo (machine-readable)
"""

from __future__ import annotations

import json
import time
from datetime import date, datetime, timezone
from pathlib import Path

from .amadeus_client import AmadeusClient, AmadeusError, MockClient, Quote
from .config import SearchConfig

DATA_DIR = Path(__file__).resolve().parent / "data"
HISTORY_FILE = DATA_DIR / "price_history.jsonl"
REPORT_FILE = DATA_DIR / "latest_report.md"
BEST_FILE = DATA_DIR / "best_combo.json"


def run_scan(
    cfg: SearchConfig,
    client,
    sleep_between: float = 0.25,
    verbose: bool = True,
) -> dict:
    """Interroge chaque itineraire, retourne le snapshot complet."""
    quotes: list[Quote] = []
    itineraries = cfg.itineraries()
    total = len(itineraries)
    errors: list[str] = []

    for idx, (origin, dep, ret) in enumerate(itineraries, 1):
        try:
            q = client.search_round_trip(
                origin=origin,
                destination=cfg.destination,
                depart=dep,
                return_date=ret,
                adults=cfg.adults,
                currency=cfg.currency,
                non_stop=cfg.non_stop,
                max_offers=cfg.max_offers,
            )
            if q is not None:
                quotes.append(q)
                if verbose:
                    print(f"[{idx}/{total}] {origin} {dep} -> {ret}  {q.price:.0f} {q.currency}")
            elif verbose:
                print(f"[{idx}/{total}] {origin} {dep} -> {ret}  (aucune offre)")
        except AmadeusError as exc:
            errors.append(f"{origin} {dep}->{ret}: {exc}")
            if verbose:
                print(f"[{idx}/{total}] {origin} {dep} -> {ret}  ERREUR: {exc}")
        if sleep_between:
            time.sleep(sleep_between)

    quotes.sort(key=lambda q: q.price)
    snapshot = {
        "ts": datetime.now(timezone.utc).isoformat(timespec="seconds"),
        "search": cfg.summary(),
        "config": {
            "origins": cfg.origins,
            "destination": cfg.destination,
            "depart_start": cfg.depart_start.isoformat(),
            "depart_end": cfg.depart_end.isoformat(),
            "trip_days": cfg.trip_days,
            "return_flex": cfg.return_flex,
            "currency": cfg.currency,
            "adults": cfg.adults,
            "non_stop": cfg.non_stop,
        },
        "n_itineraries": total,
        "n_quotes": len(quotes),
        "errors": errors,
        "best": quotes[0].as_dict() if quotes else None,
        "quotes": [q.as_dict() for q in quotes],
    }
    return snapshot


def append_history(snapshot: dict) -> None:
    DATA_DIR.mkdir(parents=True, exist_ok=True)
    # On ne garde que le best + un resume par origine dans l'historique pour limiter la taille.
    compact = {
        "ts": snapshot["ts"],
        "best": snapshot["best"],
        "best_by_origin": _best_by_origin(snapshot["quotes"]),
        "n_quotes": snapshot["n_quotes"],
        "errors": len(snapshot["errors"]),
    }
    with HISTORY_FILE.open("a", encoding="utf-8") as fh:
        fh.write(json.dumps(compact, ensure_ascii=False) + "\n")


def _fmt_stops(n) -> str:
    """-1 (inconnu, vue combinee Google) -> '?', sinon le nombre."""
    return "?" if n is None or n < 0 else str(n)


def _fmt_carriers(carriers: list[str]) -> str:
    return ", ".join(carriers) if carriers else "n/a"


def _best_by_origin(quotes: list[dict]) -> dict:
    out: dict[str, dict] = {}
    for q in quotes:
        o = q["origin"]
        if o not in out or q["price"] < out[o]["price"]:
            out[o] = {"price": q["price"], "depart": q["depart"], "return_date": q["return_date"]}
    return out


def _load_history() -> list[dict]:
    if not HISTORY_FILE.exists():
        return []
    rows: list[dict] = []
    for line in HISTORY_FILE.read_text(encoding="utf-8").splitlines():
        line = line.strip()
        if line:
            try:
                rows.append(json.loads(line))
            except json.JSONDecodeError:
                continue
    return rows


def write_report(snapshot: dict) -> None:
    DATA_DIR.mkdir(parents=True, exist_ok=True)
    history = _load_history()
    best = snapshot["best"]
    lines: list[str] = []
    lines.append("# Traceur prix vols -> La Reunion (RUN)")
    lines.append("")
    lines.append(f"_Derniere mise a jour : **{snapshot['ts']}**_")
    lines.append("")
    lines.append(f"**Recherche :** {snapshot['search']}")
    lines.append("")
    lines.append(f"- Itineraires interroges : {snapshot['n_itineraries']}")
    lines.append(f"- Offres trouvees : {snapshot['n_quotes']}")
    if snapshot["errors"]:
        lines.append(f"- Erreurs : {len(snapshot['errors'])}")
    lines.append("")

    if not best:
        lines.append("> Aucune offre trouvee sur cette fenetre. "
                     "Source keyless : Google a pu throttler l'IP (CI) ; "
                     "relance plus tard ou reduis la fenetre (FT_DEPART_STEP).")
        REPORT_FILE.write_text("\n".join(lines) + "\n", encoding="utf-8")
        return

    cur = best["currency"]
    lines.append("## Meilleur combo")
    lines.append("")
    lines.append(f"### {best['price']:.0f} {cur} — {best['origin']} -> {best['destination']}")
    lines.append("")
    lines.append(f"- **Aller :** {best['depart']}  ({_fmt_stops(best['stops_out'])} escale(s))")
    lines.append(f"- **Retour :** {best['return_date']}  ({_fmt_stops(best['stops_in'])} escale(s))")
    lines.append(f"- **Compagnies :** {_fmt_carriers(best['carriers'])}")
    lines.append("")

    # Top 10
    top = snapshot["quotes"][:10]
    lines.append("## Top 10 des combos les moins chers")
    lines.append("")
    lines.append("| # | Prix | Origine | Aller | Retour | Escales A/R | Compagnies |")
    lines.append("|---|------|---------|-------|--------|-------------|------------|")
    for i, q in enumerate(top, 1):
        lines.append(
            f"| {i} | {q['price']:.0f} {q['currency']} | {q['origin']} | {q['depart']} | "
            f"{q['return_date']} | {_fmt_stops(q['stops_out'])}/{_fmt_stops(q['stops_in'])} | "
            f"{_fmt_carriers(q['carriers'])} |"
        )
    lines.append("")

    # Meilleur prix par origine
    bbo = _best_by_origin(snapshot["quotes"])
    lines.append("## Meilleur prix par aeroport de depart")
    lines.append("")
    lines.append("| Origine | Prix | Aller | Retour |")
    lines.append("|---------|------|-------|--------|")
    for origin, info in sorted(bbo.items(), key=lambda kv: kv[1]["price"]):
        lines.append(f"| {origin} | {info['price']:.0f} {cur} | {info['depart']} | {info['return_date']} |")
    lines.append("")

    # Tendance historique
    if len(history) > 1:
        lines.append("## Tendance du meilleur prix")
        lines.append("")
        lines.append("| Date du releve | Meilleur prix | Origine | Aller |")
        lines.append("|----------------|---------------|---------|-------|")
        for row in history[-14:]:
            b = row.get("best")
            if b:
                lines.append(
                    f"| {row['ts'][:16].replace('T', ' ')} | {b['price']:.0f} {b['currency']} "
                    f"| {b['origin']} | {b['depart']} |"
                )
        lines.append("")
        prev = next((r["best"] for r in reversed(history[:-1]) if r.get("best")), None)
        if prev:
            delta = best["price"] - prev["price"]
            arrow = "▼ baisse" if delta < 0 else ("▲ hausse" if delta > 0 else "= stable")
            lines.append(f"**Variation depuis le dernier releve : {delta:+.0f} {cur} ({arrow})**")
            lines.append("")

    lines.append("---")
    lines.append("_Genere par tools/flight_tracker — prix indicatifs (source keyless Google Flights), a confirmer sur le site de la compagnie._")
    REPORT_FILE.write_text("\n".join(lines) + "\n", encoding="utf-8")
    BEST_FILE.write_text(json.dumps(best, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")


def send_daily_email(snapshot: dict) -> bool:
    """Envoie l'alerte quotidienne via Gmail SMTP. Best-effort : log + False si KO.

    Variables d'environnement :
        MAIL_USERNAME    adresse Gmail (login SMTP)
        MAIL_PASSWORD    App Password Gmail (16 car., espaces ignores)
        SMTP_HOST        defaut smtp.gmail.com
        SMTP_PORT        defaut 465 (SSL) ; 587 = STARTTLS
        MAIL_FROM        expediteur (defaut: MAIL_USERNAME)
        MAIL_TO          destinataires ',' (defaut: les 2 adresses cibles)
        FT_EMAIL_TOP     nb de lignes du classement (0 = toutes les offres, defaut 0)
    """
    import os

    from .emailer import EmailError, build_email, send_via_smtp

    recipients = [
        a.strip()
        for a in os.environ.get(
            "MAIL_TO", "maxime.babonneau@orange.com,eliserobert05@gmail.com"
        ).split(",")
        if a.strip()
    ]
    smtp_user = os.environ.get("MAIL_USERNAME", "").strip()
    smtp_pass = os.environ.get("MAIL_PASSWORD", "").replace(" ", "").strip()
    if not (smtp_user and smtp_pass):
        print("[flight_tracker] MAIL_USERNAME/MAIL_PASSWORD absents -> email non envoye.")
        return False

    history = _load_history()  # inclut le run courant (append_history deja appele)
    try:
        top_n = max(0, int(os.environ.get("FT_EMAIL_TOP", "0")))  # 0 = toutes les offres
    except ValueError:
        top_n = 0
    subject, html = build_email(snapshot, history, top_n=top_n)

    host = os.environ.get("SMTP_HOST", "smtp.gmail.com").strip()
    port = int(os.environ.get("SMTP_PORT", "465") or "465")
    mail_from = os.environ.get("MAIL_FROM", smtp_user).strip() or smtp_user
    try:
        send_via_smtp(host, port, smtp_user, smtp_pass, mail_from, recipients, subject, html)
    except EmailError as exc:
        print(f"[flight_tracker] Envoi email ECHOUE: {exc}")
        return False
    print(f"[flight_tracker] Email (SMTP {host}) envoye a {', '.join(recipients)}.")
    return True


def make_client(use_mock: bool):
    """Selectionne la source de prix.

    Priorite :
      1. --mock                       -> MockClient (prix simules)
      2. FT_PROVIDER=google|amadeus|mock (forcage explicite)
      3. Auto : cles Amadeus presentes -> Amadeus (API contractuelle, fiable)
                sinon                  -> Google Flights keyless (defaut, zero config)
    """
    import os

    if use_mock:
        return MockClient()

    provider = (os.environ.get("FT_PROVIDER", "") or "").strip().lower()
    has_keys = bool(os.environ.get("AMADEUS_CLIENT_ID") and os.environ.get("AMADEUS_CLIENT_SECRET"))

    if provider == "mock":
        return MockClient()
    if provider == "amadeus":
        return AmadeusClient()
    if provider == "google":
        from .google_flights_client import GoogleFlightsClient
        return GoogleFlightsClient()

    # Auto.
    if has_keys:
        print("[flight_tracker] Cles Amadeus detectees -> source Amadeus.")
        return AmadeusClient()
    print("[flight_tracker] Aucune cle -> source keyless Google Flights (fast-flights).")
    from .google_flights_client import GoogleFlightsClient
    return GoogleFlightsClient()
