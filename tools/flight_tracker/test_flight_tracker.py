"""Tests unitaires du traceur (sans reseau). Lancer : python tools/flight_tracker/test_flight_tracker.py"""

from __future__ import annotations

import os
import sys
from datetime import date

# Permet l'import du package depuis la racine du repo.
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))))

from tools.flight_tracker.amadeus_client import MockClient, Quote
from tools.flight_tracker.config import SearchConfig
from tools.flight_tracker.google_flights_client import (
    GoogleFlightsClient,
    _parse_carriers,
    _parse_price,
    _parse_stops,
)
from tools.flight_tracker.tracker import _best_by_origin, _fmt_stops, make_client, run_scan


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


def test_parse_price_variants():
    assert _parse_price("€1293") == 1293.0
    assert _parse_price("$1,491") == 1491.0
    assert _parse_price("1 234 €") == 1234.0
    assert _parse_price("Price unavailable") is None
    assert _parse_price("") is None
    assert _parse_price("0") is None


def test_parse_stops_variants():
    assert _parse_stops(0) == 0
    assert _parse_stops(2) == 2
    assert _parse_stops("Nonstop") == 0
    assert _parse_stops("1 stop") == 1
    assert _parse_stops("Unknown") == -1
    assert _parse_stops("") == -1


def test_parse_carriers_dedup():
    assert _parse_carriers("Air France, KLM") == ["Air France", "KLM"]
    assert _parse_carriers("Air France/Air France") == ["Air France"]
    assert _parse_carriers("") == []


def test_fmt_stops_unknown():
    assert _fmt_stops(-1) == "?"
    assert _fmt_stops(0) == "0"
    assert _fmt_stops(2) == "2"


def test_cheapest_picks_min_price():
    class _F:
        def __init__(self, price, stops="Unknown", name=""):
            self.price, self.stops, self.name = price, stops, name

    class _R:
        flights = [_F("€1500"), _F("€1290", "1 stop", "Air France"), _F("Price unavailable")]

    q = GoogleFlightsClient._cheapest(_R(), "MRS", "RUN", date(2026, 12, 20), date(2027, 1, 10), "EUR")
    assert q is not None
    assert q.price == 1290.0
    assert q.stops_out == 1
    assert q.carriers == ["Air France"]


def test_provider_selection_mock(monkeyenv=None):
    os.environ["FT_PROVIDER"] = "mock"
    try:
        assert isinstance(make_client(use_mock=False), MockClient)
    finally:
        os.environ.pop("FT_PROVIDER", None)


def test_provider_auto_keyless_without_keys():
    # Sans cle ni provider force -> Google Flights keyless.
    for k in ("FT_PROVIDER", "AMADEUS_CLIENT_ID", "AMADEUS_CLIENT_SECRET"):
        os.environ.pop(k, None)
    client = make_client(use_mock=False)
    assert isinstance(client, GoogleFlightsClient)


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
