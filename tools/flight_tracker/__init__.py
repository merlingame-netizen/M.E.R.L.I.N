"""Traceur de prix de billets d'avion Marseille/Paris -> La Reunion.

Usage CLI :
    python -m tools.flight_tracker            # scan + rapport + historique
    python -m tools.flight_tracker --mock     # sans cle API (prix simules)
    python -m tools.flight_tracker --dry-run  # affiche les itineraires sans appeler l'API
"""

from .config import SearchConfig
from .amadeus_client import AmadeusClient, MockClient, Quote
from .tracker import run_scan, write_report, append_history, make_client

__all__ = [
    "SearchConfig",
    "AmadeusClient",
    "MockClient",
    "Quote",
    "run_scan",
    "write_report",
    "append_history",
    "make_client",
]
