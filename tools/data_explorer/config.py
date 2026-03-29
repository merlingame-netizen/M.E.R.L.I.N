"""Configuration constants for Data Explorer."""

from __future__ import annotations

import os
from pathlib import Path

# --- Server ---
HOST = "127.0.0.1"
PORT = int(os.environ.get("DATA_EXPLORER_PORT", "8050"))

# --- EDH / Hive ---
EDH_DSN = os.environ.get("EDH_DSN", "EDH_BCV_ODBC")
EDH_SCHEMA = os.environ.get("EDH_SCHEMA", "prod_app_bcv_vm_v")
EDH_TIMEOUT = 120  # seconds

# --- BigQuery ---
BQ_PROJECT = os.environ.get("BQ_PROJECT", "ofr-ppx-propme-1-prd")
BQ_DATASET = os.environ.get("BQ_DATASET", "usr_pgnk2128")
BQ_TIMEOUT = 300  # seconds

# --- Hive bridge (Node.js hive-driver) ---
HIVE_BRIDGE_PATH = Path(__file__).parent / "services" / "hive_bridge.js"
HIVE_BRIDGE_CWD = Path(os.environ.get(
    "DBEAVER_MCP_DIR",
    os.path.expanduser("~/AppData/Roaming/npm/node_modules/dbeaver-mcp-server"),
))
HIVE_BRIDGE_TIMEOUT = 360  # seconds (6 min max for heavy queries)

# --- Safety ---
MAX_ROWS = 50_000  # Hard cap on query results
DEFAULT_LIMIT_EDH = 10_000  # Auto-appended if no LIMIT on EDH

# --- Persistence ---
DATA_DIR = Path.home() / ".data_explorer"
SAVED_QUERIES_FILE = DATA_DIR / "saved_queries.json"
CREDENTIALS_FILE = DATA_DIR / "credentials.enc"
HISTORY_FILE = DATA_DIR / "query_history.json"
MAX_HISTORY = 50
