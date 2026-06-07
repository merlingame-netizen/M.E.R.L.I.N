"""Tests unitaires du traceur (sans reseau). Lancer : python tools/flight_tracker/test_flight_tracker.py"""

from __future__ import annotations

import os
import sys
from datetime import date

# Permet l'import du package depuis la racine du repo.
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))))

from tools.flight_tracker.amadeus_client import MockClient, Quote
from tools.flight_tracker.config import SearchConfig
from tools.flight_tracker.tracker import _best_by_origin, run_scan


def test_default_window():
    cfg = SearchConfig()
    assert cfg.origins == ["MRS", "CDG", "ORY"]
    assert cfg.destination == "RUN"
    assert cfg.depart_start == date(2026, 12, 20)
    assert cfg.depart_end == date(2027, 1, 15)
    assert cfg.trip_days == 21
    # 27 jours de depart inclus.
    assert len(cfg.departure_dates()) == 27


def test_return_is_depart_plus_21():
    cfg = SearchConfig()
    origin, dep, ret = cfg.itineraries()[0]
    assert (ret - dep).days == 21


def test_itinerary_count():
    cfg = SearchConfig()
    # 3 origines * 27 dates * 1 offset (flex 0).
    assert len(cfg.itineraries()) == 81


def test_return_flex_offsets():
    cfg = SearchConfig(return_flex=2)
    assert cfg.return_offsets() == [19, 20, 21, 22, 23]


def test_mock_scan_finds_best():
    cfg = SearchConfig()
    snap = run_scan(cfg, MockClient(), sleep_between=0, verbose=False)
    assert snap["n_quotes"] == 81
    assert snap["best"] is not None
    # Le meilleur prix est bien le minimum de toutes les quotes.
    prices = [q["price"] for q in snap["quotes"]]
    assert snap["best"]["price"] == min(prices)
    # La liste est triee croissante.
    assert prices == sorted(prices)


def test_best_by_origin():
    quotes = [
        Quote("CDG", "RUN", "2026-12-20", "2027-01-10", 900, "EUR", ["AF"], 0, 0).as_dict(),
        Quote("CDG", "RUN", "2026-12-21", "2027-01-11", 850, "EUR", ["AF"], 0, 0).as_dict(),
        Quote("MRS", "RUN", "2026-12-20", "2027-01-10", 990, "EUR", ["UU"], 1, 1).as_dict(),
    ]
    bbo = _best_by_origin(quotes)
    assert bbo["CDG"]["price"] == 850
    assert bbo["MRS"]["price"] == 990


def _run_all():
    tests = [v for k, v in sorted(globals().items()) if k.startswith("test_") and callable(v)]
    failed = 0
    for t in tests:
        try:
            t()
            print(f"PASS {t.__name__}")
        except AssertionError as exc:
            failed += 1
            print(f"FAIL {t.__name__}: {exc}")
        except Exception as exc:  # noqa: BLE001
            failed += 1
            print(f"ERROR {t.__name__}: {exc}")
    print(f"\n{len(tests) - failed}/{len(tests)} tests OK")
    return 1 if failed else 0


if __name__ == "__main__":
    raise SystemExit(_run_all())
