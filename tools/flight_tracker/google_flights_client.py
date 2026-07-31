"""Client keyless : prix reels via Google Flights (lib `fast-flights`, scraping).

AUCUNE cle / AUCUN compte requis. C'est l'option par defaut du traceur.

`fast-flights` encode la requete dans l'URL Google Flights (protobuf b64) puis
parse le HTML retourne. On en extrait, par itineraire (origine, depart, retour),
l'offre aller-retour la moins chere.

Limites assumees (scraping, pas une API contractuelle) :
  - Devise pilotee par Google (on force `curr=EUR` / `hl=en`).
  - Dans la vue aller-retour combinee, Google n'expose pas toujours le detail
    compagnies / escales -> ces champs sont best-effort (carriers=[], stops=-1).
  - Google peut throttler une IP qui enchaine trop de requetes (ex: CI). On
    retente quelques fois puis on renvoie None pour cet itineraire (le run
    continue, le rapport reste honnete).

Variables d'environnement :
    FT_FETCH_MODE   "common" (defaut, requete directe) | "fallback" | "local"
    FT_CURRENCY     devise demandee a Google (defaut EUR, voir config)
"""

from __future__ import annotations

import os
import re
import time
from datetime import date

from .amadeus_client import AmadeusError, Quote

_PRICE_RE = re.compile(r"\d[\d.,  ]*\d|\d")


def _parse_price(raw: str) -> float | None:
    """'€1293' / '$1,491' / '1 234 €' / 'Price unavailable' -> 1293.0 / 1491.0 / 1234.0 / None."""
    if not raw:
        return None
    m = _PRICE_RE.search(raw)
    if not m:
        return None
    # Retire separateurs de milliers (virgule, point, espace, nbsp) ;
    # aucune offre Google (hl=en) n'a de centimes ici.
    digits = re.sub(r"[^\d]", "", m.group(0))
    try:
        val = float(digits)
    except ValueError:
        return None
    return val if val > 0 else None


def _parse_stops(raw) -> int:
    """fast-flights renvoie un int (0=Nonstop) ou la chaine 'Unknown'."""
    if isinstance(raw, int):
        return raw
    if isinstance(raw, str):
        if raw.strip().lower().startswith("nonstop"):
            return 0
        m = re.search(r"\d+", raw)
        if m:
            return int(m.group(0))
    return -1  # inconnu (vue combinee Google)


def _parse_carriers(name: str) -> list[str]:
    if not name:
        return []
    parts = [p.strip() for p in re.split(r"[,/]", name) if p.strip()]
    # Dedup en preservant l'ordre.
    seen: dict[str, None] = {}
    for p in parts:
        seen.setdefault(p, None)
    return list(seen.keys())


class GoogleFlightsClient:
    """Source de prix keyless basee sur Google Flights (via `fast-flights`)."""

    def __init__(self, fetch_mode: str | None = None) -> None:
        try:
            from fast_flights import FlightData, Passengers, TFSData  # noqa: F401
            from fast_flights.core import get_flights_from_filter  # noqa: F401
        except ImportError as exc:  # pragma: no cover - depend de l'install
            raise AmadeusError(
                "Le module 'fast-flights' est requis pour la source keyless. "
                "Installe-le : pip install fast-flights"
            ) from exc
        self._FlightData = FlightData
        self._Passengers = Passengers
        self._TFSData = TFSData
        self._get = get_flights_from_filter
        mode = (fetch_mode or os.environ.get("FT_FETCH_MODE", "common")).strip().lower()
        if mode not in ("common", "fallback", "force-fallback", "local"):
            mode = "common"
        self.fetch_mode = mode

    def search_round_trip(
        self,
        origin: str,
        destination: str,
        depart: date,
        return_date: date,
        adults: int = 1,
        currency: str = "EUR",
        non_stop: bool = False,
        max_offers: int = 5,
        retries: int = 3,
    ) -> Quote | None:
        flight_data = [
            self._FlightData(date=depart.isoformat(), from_airport=origin, to_airport=destination),
            self._FlightData(date=return_date.isoformat(), from_airport=destination, to_airport=origin),
        ]
        filt = self._TFSData.from_interface(
            flight_data=flight_data,
            trip="round-trip",
            seat="economy",
            passengers=self._Passengers(adults=adults),
            max_stops=0 if non_stop else None,
        )

        backoff = 2.0
        last_err: Exception | None = None
        for attempt in range(max(1, retries)):
            try:
                result = self._get(filt, currency=currency, mode=self.fetch_mode)
            except Exception as exc:  # noqa: BLE001 - scraping: erreurs variees (HTTP, parse, reseau)
                last_err = exc
                time.sleep(backoff)
                backoff *= 2
                continue
            return self._cheapest(result, origin, destination, depart, return_date, currency)

        # Toutes les tentatives ont echoue : on ne tue pas le run, on signale.
        raise AmadeusError(f"Google Flights indisponible apres {retries} tentatives: {last_err}")

    @staticmethod
    def _cheapest(result, origin, destination, depart: date, return_date: date, currency: str) -> Quote | None:
        flights = getattr(result, "flights", None) or []
        best_price: float | None = None
        best_flight = None
        for fl in flights:
            p = _parse_price(getattr(fl, "price", ""))
            if p is None:
                continue
            if best_price is None or p < best_price:
                best_price = p
                best_flight = fl
        if best_flight is None or best_price is None:
            return None

        stops = _parse_stops(getattr(best_flight, "stops", -1))
        carriers = _parse_carriers(getattr(best_flight, "name", "") or "")
        return Quote(
            origin=origin,
            destination=destination,
            depart=depart.isoformat(),
            return_date=return_date.isoformat(),
            price=round(best_price, 2),
            currency=currency,
            carriers=carriers,
            stops_out=stops,
            stops_in=stops,  # vue combinee : Google ne separe pas A/R en escales
        )
