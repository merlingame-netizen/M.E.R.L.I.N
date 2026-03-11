"""Power BI adapter — REST API (MSAL device flow) + pbi-tools offline actions."""

from __future__ import annotations

import json
import subprocess
import time
from pathlib import Path
from typing import Any

from tools.adapters.base_adapter import BaseAdapter

# ── Constants ────────────────────────────────────────────────────────────────

_CLIENT_ID = "ea0616ba-638b-4df5-95b9-636659ae5121"
_SCOPE = ["https://analysis.windows.net/powerbi/api/.default"]
_BASE_URL = "https://api.powerbi.com/v1.0/myorg"
_TOKEN_CACHE_PATH = Path.home() / ".claude" / "workspace" / "powerbi_token.json"
_PBI_TOOLS_EXE = Path.home() / ".claude" / "workspace" / "pbi-tools" / "pbi-tools.exe"

_PBI_TOOLS_MISSING_MSG = (
    "pbi-tools not found. Download from https://pbi.tools/ and place at "
    "~/.claude/workspace/pbi-tools/pbi-tools.exe"
)

# ── Adapter ──────────────────────────────────────────────────────────────────


class PowerBIAdapter(BaseAdapter):
    """
    Adapter for Microsoft Power BI.

    REST actions use MSAL device-code flow for authentication.
    Offline actions delegate to pbi-tools.exe.
    """

    def __init__(self) -> None:
        super().__init__("powerbi")

    # ── Public interface ─────────────────────────────────────────────────────

    def list_actions(self) -> dict[str, str]:
        return {
            # REST — workspace/dataset/report management
            "workspaces": "List all Power BI workspaces (groups)",
            "list-workspaces": "Alias for workspaces",
            "list-reports": "List reports (kwarg: workspace=<id> optional)",
            "list-datasets": "List datasets (kwarg: workspace=<id> optional)",
            "refresh": "Trigger dataset refresh and poll until done (kwarg: dataset=<id>)",
            "refresh-status": "Return last 3 refresh entries for a dataset (kwarg: dataset=<id>)",
            "query": "Execute a DAX query (kwargs: dataset=<id>, dax=<query string>)",
            "export": "Export a report (kwargs: report=<id>, format=PDF|XLSX|PNG)",
            # Offline — pbi-tools
            "open": "Show .pbix metadata via pbi-tools info (kwarg: pbix=<path>)",
            "info": "Alias for open",
            "extract": "Extract .pbix to folder (kwargs: pbix=<path>, out=<path optional>)",
        }

    def run(self, action: str, **kwargs: Any) -> dict:
        # Offline actions — no auth needed
        if action in ("open", "info"):
            return self._pbi_info(kwargs)
        if action == "extract":
            return self._pbi_extract(kwargs)

        # REST actions — require a valid token
        token_result = self._get_token()
        if token_result.get("status") == "error":
            return token_result
        token: str = token_result["data"]["access_token"]

        dispatch = {
            "workspaces": self._workspaces,
            "list-workspaces": self._workspaces,
            "list-reports": self._list_reports,
            "list-datasets": self._list_datasets,
            "refresh": self._refresh,
            "refresh-status": self._refresh_status,
            "query": self._query,
            "export": self._export,
        }
        handler = dispatch.get(action)
        if handler is None:
            raise NotImplementedError  # propagated to execute() → error envelope

        return handler(token, kwargs)

    # ── Auth ─────────────────────────────────────────────────────────────────

    def _get_token(self) -> dict:
        """Return cached token or launch MSAL device-code flow."""
        try:
            import msal  # noqa: PLC0415
        except ImportError:
            return self.error("msal is not installed. Run: pip install msal requests")

        # Try cache first
        cached = self._load_token_cache()
        if cached:
            self.log("Using cached Power BI token.")
            return self.ok(cached)

        # Device-code flow
        self.log("Starting MSAL device-code flow…")
        app = msal.PublicClientApplication(
            client_id=_CLIENT_ID,
            authority="https://login.microsoftonline.com/common",
        )

        flow = app.initiate_device_flow(scopes=_SCOPE)
        if "user_code" not in flow:
            return self.error(f"Device flow initiation failed: {flow.get('error_description', flow)}")

        # Surface the user instruction
        self.log(flow["message"])
        print(flow["message"])  # visible in terminal even without log capture

        result = app.acquire_token_by_device_flow(flow)
        if "access_token" not in result:
            return self.error(
                f"Authentication failed: {result.get('error_description', result.get('error', 'unknown'))}"
            )

        self._save_token_cache(result)
        self.log("Token acquired and cached.")
        return self.ok(result)

    def _load_token_cache(self) -> dict | None:
        """Return cached token dict if it exists and is not expired, else None."""
        if not _TOKEN_CACHE_PATH.exists():
            return None
        try:
            raw = json.loads(_TOKEN_CACHE_PATH.read_text(encoding="utf-8"))
        except (json.JSONDecodeError, OSError):
            return None

        expires_at = raw.get("expires_at", 0)
        # Reject if within 60 s of expiry
        if time.time() >= expires_at - 60:
            self.log("Cached token is expired or about to expire.")
            return None

        return raw

    def _save_token_cache(self, result: dict) -> None:
        """Persist token with an absolute expiry timestamp."""
        expires_in = int(result.get("expires_in", 3600))
        payload = {
            "access_token": result["access_token"],
            "expires_at": time.time() + expires_in,
            "expires_in": expires_in,
            "token_type": result.get("token_type", "Bearer"),
        }
        _TOKEN_CACHE_PATH.parent.mkdir(parents=True, exist_ok=True)
        _TOKEN_CACHE_PATH.write_text(
            json.dumps(payload, indent=2), encoding="utf-8"
        )
        try:
            import os, stat
            os.chmod(_TOKEN_CACHE_PATH, stat.S_IRUSR | stat.S_IWUSR)  # 0o600 — owner only
        except Exception:
            pass  # chmod unsupported on some Windows configs — non-fatal

    # ── REST helpers ─────────────────────────────────────────────────────────

    def _api_get(self, token: str, path: str) -> dict:
        """GET request against the Power BI REST API."""
        try:
            import requests  # noqa: PLC0415
        except ImportError:
            return self.error("requests is not installed. Run: pip install msal requests")

        url = f"{_BASE_URL}{path}"
        self.log(f"GET {url}")
        resp = requests.get(
            url,
            headers={"Authorization": f"Bearer {token}"},
            timeout=30,
        )
        if not resp.ok:
            return self.error(f"HTTP {resp.status_code}: {resp.text[:200]}")
        return self.ok(resp.json())

    def _api_post(self, token: str, path: str, body: dict | None = None) -> dict:
        """POST request against the Power BI REST API."""
        try:
            import requests  # noqa: PLC0415
        except ImportError:
            return self.error("requests is not installed. Run: pip install msal requests")

        url = f"{_BASE_URL}{path}"
        self.log(f"POST {url}")
        resp = requests.post(
            url,
            headers={
                "Authorization": f"Bearer {token}",
                "Content-Type": "application/json",
            },
            json=body or {},
            timeout=30,
        )
        if not resp.ok:
            return self.error(f"HTTP {resp.status_code}: {resp.text[:200]}")
        # 202 Accepted returns no body
        if resp.status_code == 202 or not resp.content:
            return self.ok({"status_code": resp.status_code, "headers": dict(resp.headers)})
        return self.ok(resp.json())

    # ── REST actions ─────────────────────────────────────────────────────────

    def _workspaces(self, token: str, _kwargs: dict) -> dict:
        result = self._api_get(token, "/groups")
        if result["status"] == "error":
            return result
        workspaces = result["data"].get("value", [])
        return self.ok({"workspaces": workspaces, "count": len(workspaces)})

    def _list_reports(self, token: str, kwargs: dict) -> dict:
        workspace = kwargs.get("workspace")
        path = f"/groups/{workspace}/reports" if workspace else "/reports"
        result = self._api_get(token, path)
        if result["status"] == "error":
            return result
        reports = result["data"].get("value", [])
        return self.ok({"reports": reports, "count": len(reports)})

    def _list_datasets(self, token: str, kwargs: dict) -> dict:
        workspace = kwargs.get("workspace")
        path = f"/groups/{workspace}/datasets" if workspace else "/datasets"
        result = self._api_get(token, path)
        if result["status"] == "error":
            return result
        datasets = result["data"].get("value", [])
        return self.ok({"datasets": datasets, "count": len(datasets)})

    def _refresh(self, token: str, kwargs: dict) -> dict:
        dataset = kwargs.get("dataset")
        if not dataset:
            return self.error("Missing required argument: dataset")

        # Trigger the refresh
        trigger = self._api_post(token, f"/datasets/{dataset}/refreshes")
        if trigger["status"] == "error":
            return trigger

        self.log("Refresh triggered. Polling every 5 s (max 60 s)…")
        deadline = time.monotonic() + 60
        while time.monotonic() < deadline:
            time.sleep(5)
            status_result = self._api_get(token, f"/datasets/{dataset}/refreshes")
            if status_result["status"] == "error":
                return status_result
            entries = status_result["data"].get("value", [])
            if entries:
                latest = entries[0]
                state = latest.get("status", "Unknown")
                self.log(f"Refresh state: {state}")
                if state in ("Completed", "Failed", "Disabled"):
                    return self.ok({"refresh": latest, "polled": True})

        return self.ok({"message": "Refresh still in progress after 60 s. Use refresh-status to check.", "polled": False})

    def _refresh_status(self, token: str, kwargs: dict) -> dict:
        dataset = kwargs.get("dataset")
        if not dataset:
            return self.error("Missing required argument: dataset")
        result = self._api_get(token, f"/datasets/{dataset}/refreshes")
        if result["status"] == "error":
            return result
        entries = result["data"].get("value", [])
        return self.ok({"refreshes": entries[:3], "count": min(len(entries), 3)})

    def _query(self, token: str, kwargs: dict) -> dict:
        dataset = kwargs.get("dataset")
        dax = kwargs.get("dax")
        if not dataset:
            return self.error("Missing required argument: dataset")
        if not dax:
            return self.error("Missing required argument: dax")

        body = {
            "queries": [{"query": dax}],
            "serializerSettings": {"includeNulls": True},
        }
        result = self._api_post(token, f"/datasets/{dataset}/executeQueries", body)
        if result["status"] == "error":
            return result
        return self.ok(result["data"])

    def _export(self, token: str, kwargs: dict) -> dict:
        report = kwargs.get("report")
        fmt = kwargs.get("format", "PDF").upper()
        if not report:
            return self.error("Missing required argument: report")
        if fmt not in ("PDF", "XLSX", "PNG"):
            return self.error("format must be one of: PDF, XLSX, PNG")

        # Initiate export
        body = {"format": fmt}
        trigger = self._api_post(token, f"/reports/{report}/ExportTo", body)
        if trigger["status"] == "error":
            return trigger

        data = trigger["data"]
        export_id = data.get("id")
        if not export_id:
            location = data.get("headers", {}).get("Location", "")
            parts = [p for p in location.split("/") if p]
            export_id = parts[-1] if parts else None
        if not export_id:
            return self.error("Could not determine export job ID from response.")

        self.log(f"Export job started: {export_id}. Polling…")
        deadline = time.monotonic() + 120
        while time.monotonic() < deadline:
            time.sleep(5)
            poll = self._api_get(token, f"/reports/{report}/exports/{export_id}")
            if poll["status"] == "error":
                return poll
            state = poll["data"].get("status", "Unknown")
            self.log(f"Export state: {state}")
            if state == "Succeeded":
                download_url = f"{_BASE_URL}/reports/{report}/exports/{export_id}/file"
                return self.ok({
                    "export_id": export_id,
                    "status": "Succeeded",
                    "format": fmt,
                    "download_url": download_url,
                })
            if state in ("Failed", "Cancelled"):
                return self.error(f"Export ended with state: {state}")

        return self.error("Export timed out after 120 s.")

    # ── pbi-tools offline actions ─────────────────────────────────────────────

    def _require_pbi_tools(self) -> str | None:
        """Return exe path string if found, else None (caller should call self.error)."""
        return str(_PBI_TOOLS_EXE) if _PBI_TOOLS_EXE.exists() else None

    def _pbi_info(self, kwargs: dict) -> dict:
        exe = self._require_pbi_tools()
        if not exe:
            return self.error(_PBI_TOOLS_MISSING_MSG)
        pbix = kwargs.get("pbix")
        if not pbix:
            return self.error("Missing required argument: pbix")

        self.log(f"Running: pbi-tools info {pbix}")
        completed = subprocess.run(
            [exe, "info", str(pbix)],
            capture_output=True,
            text=True,
            timeout=60,
        )
        if completed.returncode != 0:
            return self.error(
                f"pbi-tools failed (exit {completed.returncode}): {completed.stderr[:200]}"
            )
        return self.ok({"stdout": completed.stdout, "stderr": completed.stderr})

    def _pbi_extract(self, kwargs: dict) -> dict:
        exe = self._require_pbi_tools()
        if not exe:
            return self.error(_PBI_TOOLS_MISSING_MSG)
        pbix = kwargs.get("pbix")
        if not pbix:
            return self.error("Missing required argument: pbix")

        pbix_path = Path(pbix)
        out = kwargs.get("out") or str(pbix_path.with_name(pbix_path.stem + "_extracted"))

        self.log(f"Running: pbi-tools extract {pbix} -outPath {out}")
        completed = subprocess.run(
            [exe, "extract", str(pbix_path), "-outPath", str(out)],
            capture_output=True,
            text=True,
            timeout=120,
        )
        if completed.returncode != 0:
            return self.error(
                f"pbi-tools extract failed (exit {completed.returncode}): {completed.stderr[:200]}"
            )
        return self.ok({"out_path": out, "stdout": completed.stdout, "stderr": completed.stderr})
