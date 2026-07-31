"""Client minimal pour l'API Amadeus Self-Service (Flight Offers Search).

Auth : OAuth2 client_credentials.
Endpoint : GET /v2/shopping/flight-offers (aller-retour).

Variables d'environnement requises :
    AMADEUS_CLIENT_ID
    AMADEUS_CLIENT_SECRET
    AMADEUS_ENV       "test" (defaut) ou "production"

NB : l'environnement "test" renvoie des donnees catalogue limitees/synthetiques.
Pour de vrais prix La Reunion, promouvoir l'app en "production" sur le portail
Amadeus (gratuit, meme quota) puis AMADEUS_ENV=production. Voir README.
"""

from __future__ import annotations

import json
import os
import time
import urllib.error
import urllib.parse
import urllib.request
from dataclasses import dataclass
from datetime import date, datetime, timedelta

_BASES = {
    "test": "https://test.api.amadeus.com",
    "production": "https://api.amadeus.com",
}


class AmadeusError(RuntimeError):
    pass


@dataclass
class Quote:
    """Meilleure offre trouvee pour un itineraire (origine, depart, retour)."""

    origin: str
    destination: str
    depart: str          # ISO date
    return_date: str     # ISO date
    price: float
    currency: str
    carriers: list[str]
    stops_out: int
    stops_in: int
    deep_link: str = ""

    def as_dict(self) -> dict:
        return {
            "origin": self.origin,
            "destination": self.destination,
            "depart": self.depart,
            "return_date": self.return_date,
            "price": self.price,
            "currency": self.currency,
            "carriers": self.carriers,
            "stops_out": self.stops_out,
            "stops_in": self.stops_in,
            "deep_link": self.deep_link,
        }


class AmadeusClient:
    def __init__(
        self,
        client_id: str | None = None,
        client_secret: str | None = None,
        env: str | None = None,
        timeout: int = 20,
    ) -> None:
        self.client_id = client_id or os.environ.get("AMADEUS_CLIENT_ID", "")
        self.client_secret = client_secret or os.environ.get("AMADEUS_CLIENT_SECRET", "")
        self.env = (env or os.environ.get("AMADEUS_ENV", "test")).strip().lower()
        if self.env not in _BASES:
            self.env = "test"
        self.base = _BASES[self.env]
        self.timeout = timeout
        self._token: str = ""
        self._token_exp: float = 0.0
        if not self.client_id or not self.client_secret:
            raise AmadeusError(
                "AMADEUS_CLIENT_ID / AMADEUS_CLIENT_SECRET manquants. "
                "Cree une cle gratuite sur https://developers.amadeus.com et exporte-les."
            )

    # -- auth -------------------------------------------------------------
    def _ensure_token(self) -> None:
        if self._token and time.time() < self._token_exp - 30:
            return
        data = urllib.parse.urlencode(
            {
                "grant_type": "client_credentials",
                "client_id": self.client_id,
                "client_secret": self.client_secret,
            }
        ).encode()
        req = urllib.request.Request(
            f"{self.base}/v1/security/oauth2/token",
            data=data,
            headers={"Content-Type": "application/x-www-form-urlencoded"},
            method="POST",
        )
        try:
            with urllib.request.urlopen(req, timeout=self.timeout) as resp:
                payload = json.loads(resp.read().decode())
        except urllib.error.HTTPError as exc:
            raise AmadeusError(f"Auth Amadeus echouee ({exc.code}): {exc.read().decode()[:200]}") from exc
        except urllib.error.URLError as exc:
            raise AmadeusError(f"Reseau indisponible pour l'auth Amadeus: {exc}") from exc
        self._token = payload["access_token"]
        self._token_exp = time.time() + float(payload.get("expires_in", 1799))

    # -- search -----------------------------------------------------------
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
        """Retourne la moins chere des offres aller-retour, ou None si aucune."""
        self._ensure_token()
        params = {
            "originLocationCode": origin,
            "destinationLocationCode": destination,
            "departureDate": depart.isoformat(),
            "returnDate": return_date.isoformat(),
            "adults": str(adults),
            "currencyCode": currency,
            "max": str(max_offers),
            "nonStop": "true" if non_stop else "false",
        }
        url = f"{self.base}/v2/shopping/flight-offers?" + urllib.parse.urlencode(params)

        backoff = 2.0
        last_err: Exception | None = None
        for attempt in range(retries):
            req = urllib.request.Request(
                url, headers={"Authorization": f"Bearer {self._token}"}, method="GET"
            )
            try:
                with urllib.request.urlopen(req, timeout=self.timeout) as resp:
                    payload = json.loads(resp.read().decode())
                return self._cheapest(payload, origin, destination, depart, return_date, currency)
            except urllib.error.HTTPError as exc:
                body = exc.read().decode()[:300]
                if exc.code == 429:  # rate limited -> backoff
                    last_err = AmadeusError(f"429 rate-limited: {body}")
                    time.sleep(backoff)
                    backoff *= 2
                    continue
                if exc.code == 401:  # token expire -> refresh une fois
                    self._token = ""
                    self._ensure_token()
                    last_err = AmadeusError(f"401: {body}")
                    continue
                if exc.code == 400:  # pas de route / params -> pas de quote
                    return None
                last_err = AmadeusError(f"HTTP {exc.code}: {body}")
                time.sleep(backoff)
                backoff *= 2
            except urllib.error.URLError as exc:
                last_err = AmadeusError(f"Reseau: {exc}")
                time.sleep(backoff)
                backoff *= 2
        if last_err:
            raise last_err
        return None

    @staticmethod
    def _cheapest(
        payload: dict, origin: str, destination: str, depart: date, return_date: date, currency: str
    ) -> Quote | None:
        offers = payload.get("data") or []
        if not offers:
            return None
        best = min(offers, key=lambda o: float(o["price"]["grandTotal"]))
        itineraries = best.get("itineraries", [])
        stops_out = max(0, len(itineraries[0]["segments"]) - 1) if itineraries else 0
        stops_in = max(0, len(itineraries[1]["segments"]) - 1) if len(itineraries) > 1 else 0
        carriers = sorted(
            {seg["carrierCode"] for it in itineraries for seg in it.get("segments", [])}
        )
        return Quote(
            origin=origin,
            destination=destination,
            depart=depart.isoformat(),
            return_date=return_date.isoformat(),
            price=round(float(best["price"]["grandTotal"]), 2),
            currency=best["price"].get("currency", currency),
            carriers=carriers,
            stops_out=stops_out,
            stops_in=stops_in,
        )


class MockClient:
    """Source de prix simulee (deterministe) pour tester le pipeline sans cle.

    Active via --mock ou si aucune cle Amadeus n'est presente et
    FLIGHT_TRACKER_ALLOW_MOCK=1.
    """

    _BASE_PRICE = {"MRS": 980.0, "CDG": 890.0, "ORY": 910.0}

    def search_round_trip(
        self, origin, destination, depart: date, return_date: date,
        adults=1, currency="EUR", non_stop=False, max_offers=5, retries=3,
    ) -> Quote | None:
        import math

        base = self._BASE_PRICE.get(origin, 950.0)
        # Pic de prix autour de Noel/Nouvel An, creux mi-janvier.
        doy = depart.timetuple().tm_yday if depart.month == 1 else depart.day
        holiday_bump = 260.0 * math.exp(-((depart.day - 22) ** 2) / 50.0) if depart.month == 12 else 0.0
        jan_relief = -120.0 * min(depart.day / 15.0, 1.0) if depart.month == 1 else 0.0
        # Petite oscillation deterministe pour simuler la variation jour le jour.
        wiggle = 40.0 * math.sin(depart.toordinal() * 1.3)
        price = round(base + holiday_bump + jan_relief + wiggle, 2)
        carriers = {"MRS": ["AF", "UU"], "CDG": ["AF"], "ORY": ["UU", "SS"]}.get(origin, ["AF"])
        return Quote(
            origin=origin,
            destination=destination,
            depart=depart.isoformat(),
            return_date=return_date.isoformat(),
            price=price,
            currency=currency,
            carriers=carriers,
            stops_out=0 if origin != "MRS" else 1,
            stops_in=0 if origin != "MRS" else 1,
        )
