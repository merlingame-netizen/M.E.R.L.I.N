"""Configuration du traceur de prix vols Marseille/Paris -> La Reunion.

Toute la fenetre de recherche est definie ici. Les valeurs peuvent etre
surchargees par variables d'environnement (utile pour la GitHub Action) :

    FT_ORIGINS         "MRS,CDG,ORY"
    FT_DESTINATION     "RUN"
    FT_DEPART_START    "2026-12-20"
    FT_DEPART_END      "2027-01-15"
    FT_TRIP_DAYS       "21"
    FT_RETURN_FLEX     "0"          (jours +/- autour de TRIP_DAYS)
    FT_DEPART_STEP     "1"          (pas en jours dans la fenetre de depart)
    FT_CURRENCY        "EUR"
    FT_ADULTS          "1"
    FT_NON_STOP        "false"
    FT_MAX_OFFERS      "5"          (offres recuperees par requete, on garde la moins chere)
"""

from __future__ import annotations

import os
from dataclasses import dataclass, field
from datetime import date, timedelta


def _env(name: str, default: str) -> str:
    val = os.environ.get(name)
    return val if val not in (None, "") else default


def _env_int(name: str, default: int) -> int:
    try:
        return int(_env(name, str(default)))
    except ValueError:
        return default


def _env_bool(name: str, default: bool) -> bool:
    return _env(name, "true" if default else "false").strip().lower() in ("1", "true", "yes", "on")


@dataclass
class SearchConfig:
    """Parametres de la recherche de combos aller-retour."""

    origins: list[str] = field(
        default_factory=lambda: [o.strip().upper() for o in _env("FT_ORIGINS", "MRS,CDG,ORY").split(",") if o.strip()]
    )
    destination: str = field(default_factory=lambda: _env("FT_DESTINATION", "RUN").upper())
    depart_start: date = field(default_factory=lambda: date.fromisoformat(_env("FT_DEPART_START", "2026-12-20")))
    depart_end: date = field(default_factory=lambda: date.fromisoformat(_env("FT_DEPART_END", "2027-01-15")))
    trip_days: int = field(default_factory=lambda: _env_int("FT_TRIP_DAYS", 21))
    return_flex: int = field(default_factory=lambda: _env_int("FT_RETURN_FLEX", 0))
    depart_step: int = field(default_factory=lambda: max(1, _env_int("FT_DEPART_STEP", 1)))
    currency: str = field(default_factory=lambda: _env("FT_CURRENCY", "EUR").upper())
    adults: int = field(default_factory=lambda: _env_int("FT_ADULTS", 1))
    non_stop: bool = field(default_factory=lambda: _env_bool("FT_NON_STOP", False))
    max_offers: int = field(default_factory=lambda: _env_int("FT_MAX_OFFERS", 5))

    def departure_dates(self) -> list[date]:
        """Toutes les dates de depart de la fenetre, selon le pas."""
        out: list[date] = []
        d = self.depart_start
        while d <= self.depart_end:
            out.append(d)
            d += timedelta(days=self.depart_step)
        return out

    def return_offsets(self) -> list[int]:
        """Durees de sejour a tester (en jours), centrees sur trip_days."""
        flex = max(0, self.return_flex)
        return list(range(self.trip_days - flex, self.trip_days + flex + 1))

    def itineraries(self) -> list[tuple[str, date, date]]:
        """Toutes les combinaisons (origine, date_depart, date_retour) a interroger."""
        combos: list[tuple[str, date, date]] = []
        for origin in self.origins:
            for dep in self.departure_dates():
                for offset in self.return_offsets():
                    combos.append((origin, dep, dep + timedelta(days=offset)))
        return combos

    def summary(self) -> str:
        return (
            f"{'/'.join(self.origins)} -> {self.destination} | "
            f"depart {self.depart_start.isoformat()}..{self.depart_end.isoformat()} | "
            f"sejour {self.trip_days}j (flex +/-{self.return_flex}) | "
            f"{self.adults} adulte(s) | {self.currency}"
        )
