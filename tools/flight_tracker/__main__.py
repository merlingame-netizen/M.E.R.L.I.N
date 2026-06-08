"""Point d'entree CLI du traceur de prix vols La Reunion."""

from __future__ import annotations

import argparse
import sys

from .config import SearchConfig
from .tracker import append_history, make_client, run_scan, send_daily_email, write_report


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(
        prog="python -m tools.flight_tracker",
        description="Traceur de prix de billets Marseille/Paris -> La Reunion (RUN).",
    )
    parser.add_argument("--mock", action="store_true", help="Prix simules, sans cle Amadeus.")
    parser.add_argument("--dry-run", action="store_true", help="Liste les itineraires sans appeler l'API.")
    parser.add_argument("--quiet", action="store_true", help="Moins de logs.")
    parser.add_argument("--sleep", type=float, default=0.25, help="Pause (s) entre requetes (defaut 0.25).")
    parser.add_argument("--no-history", action="store_true", help="Ne pas ecrire dans price_history.jsonl.")
    parser.add_argument("--email", action="store_true", help="Envoyer l'alerte quotidienne (Gmail SMTP).")
    args = parser.parse_args(argv)

    cfg = SearchConfig()
    print(f"[flight_tracker] {cfg.summary()}")
    itineraries = cfg.itineraries()
    print(f"[flight_tracker] {len(itineraries)} itineraires a interroger.")

    if args.dry_run:
        for origin, dep, ret in itineraries:
            print(f"  {origin} {dep} -> {ret}")
        return 0

    try:
        client = make_client(use_mock=args.mock)
    except Exception as exc:  # noqa: BLE001
        print(f"[flight_tracker] ERREUR init client: {exc}", file=sys.stderr)
        return 2

    snapshot = run_scan(cfg, client, sleep_between=args.sleep, verbose=not args.quiet)

    if not args.no_history:
        append_history(snapshot)
    write_report(snapshot)

    if args.email:
        send_daily_email(snapshot)

    best = snapshot["best"]
    if best:
        print(
            f"\n[flight_tracker] MEILLEUR COMBO : {best['price']:.0f} {best['currency']} "
            f"| {best['origin']} -> {best['destination']} | "
            f"aller {best['depart']} / retour {best['return_date']}"
        )
        return 0
    print("\n[flight_tracker] Aucune offre trouvee (voir data/latest_report.md).", file=sys.stderr)
    return 1


if __name__ == "__main__":
    raise SystemExit(main())
