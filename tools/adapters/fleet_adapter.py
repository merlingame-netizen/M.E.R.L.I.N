"""Fleet adapter — health-check a multi-cloud free fleet and serve a local dashboard.

Reads infra/fleet/fleet.yaml, probes each target (SSH for VMs, HTTP for serverless),
and returns a normalized JSON status. `serve` launches a local web dashboard.

Actions:
  status              health-check every target -> JSON (+ writes status/fleet.json)
  list                list inventory targets
  check  --target N   health-check a single target
  serve  [--port P]   run the local admin dashboard (default http://127.0.0.1:8765)
"""
from __future__ import annotations

import json
import os
import socket
import subprocess
import time
import urllib.request
from datetime import datetime, timezone
from pathlib import Path
from typing import Any

import yaml

from adapters.base_adapter import BaseAdapter

REPO_ROOT = Path(__file__).resolve().parents[2]
FLEET_YAML = REPO_ROOT / "infra" / "fleet" / "fleet.yaml"
FLEET_LOCAL = REPO_ROOT / "infra" / "fleet" / "fleet.local.yaml"
STATUS_JSON = REPO_ROOT / "infra" / "fleet" / "status" / "fleet.json"

# Remote one-liner: "usedMB/totalMB ncpu load disk%"
SSH_PROBE = (
    "awk '/MemTotal/{t=$2}/MemAvailable/{a=$2}"
    "END{printf \"%d/%d \",(t-a)/1024,t/1024}' /proc/meminfo; "
    "printf \"%s \" \"$(nproc)\"; cut -d' ' -f1 /proc/loadavg | tr -d '\\n'; "
    "printf \" \"; df -P / | awk 'NR==2{print $5}'"
)


class FleetAdapter(BaseAdapter):
    def __init__(self) -> None:
        super().__init__("fleet")

    def list_actions(self) -> dict[str, str]:
        return {
            "status": "Health-check every target and write status/fleet.json",
            "list": "List inventory targets from fleet.yaml",
            "check": "Health-check a single target (--target NAME)",
            "serve": "Run the local admin dashboard (--port 8765)",
        }

    def health_probe(self) -> tuple[str, dict]:
        return "list", {}

    # ── inventory ────────────────────────────────────────────────────────────
    def _load(self) -> dict:
        if not FLEET_YAML.exists():
            raise FileNotFoundError(f"inventory not found: {FLEET_YAML}")
        inv = yaml.safe_load(FLEET_YAML.read_text()) or {}
        # Merge optional local-only overrides (e.g. VM IPs kept out of a public repo).
        if FLEET_LOCAL.exists():
            local = yaml.safe_load(FLEET_LOCAL.read_text()) or {}
            by_name = {t.get("name"): t for t in inv.get("targets", [])}
            for ovr in local.get("targets", []):
                tgt = by_name.get(ovr.get("name"))
                if tgt:
                    tgt.update({k: v for k, v in ovr.items() if k != "name"})
        return inv

    def run(self, action: str, **kwargs: Any) -> dict:
        if action == "list":
            inv = self._load()
            return self.ok({"targets": inv.get("targets", []), "path": str(FLEET_YAML)})
        if action == "status":
            return self.ok(self._status_all())
        if action == "check":
            name = kwargs.get("target")
            if not name:
                return self.error("check requires --target NAME")
            inv = self._load()
            tgt = next((t for t in inv.get("targets", []) if t.get("name") == name), None)
            if not tgt:
                return self.error(f"unknown target '{name}'")
            return self.ok(self._probe(tgt, inv.get("defaults", {})))
        if action == "serve":
            return self._serve(int(kwargs.get("port", 8765)))
        raise NotImplementedError(action)

    # ── probing ──────────────────────────────────────────────────────────────
    def _status_all(self) -> dict:
        inv = self._load()
        defaults = inv.get("defaults", {})
        results = [self._probe(t, defaults) for t in inv.get("targets", [])]
        payload = {
            "checked_at": datetime.now(timezone.utc).isoformat(timespec="seconds"),
            "up": sum(1 for r in results if r["state"] == "up"),
            "total": len(results),
            "targets": results,
        }
        STATUS_JSON.parent.mkdir(parents=True, exist_ok=True)
        STATUS_JSON.write_text(json.dumps(payload, indent=2))
        return payload

    def _probe(self, tgt: dict, defaults: dict) -> dict:
        name = tgt.get("name", "?")
        provider = tgt.get("provider", "?")
        role = tgt.get("role", "")
        ttype = tgt.get("type", "ssh")
        timeout = int(tgt.get("timeout", defaults.get("timeout", 6)))
        base = {
            "name": name, "provider": provider, "role": role, "type": ttype,
            "state": "pending", "detail": "", "latency_ms": None,
            "cpu": None, "mem": None, "disk": None,
        }
        try:
            if ttype == "http":
                url = tgt.get("url", "").strip()
                if not url:
                    base["detail"] = "no url (not deployed yet)"
                    return base
                self._probe_http(url, timeout, base)
            else:  # ssh
                host = tgt.get("host", "").strip()
                if not host:
                    base["detail"] = "no host (not deployed yet)"
                    return base
                user = tgt.get("ssh_user") or defaults.get("ssh_user", "ubuntu")
                key = os.path.expanduser(tgt.get("ssh_key") or defaults.get("ssh_key", ""))
                self._probe_ssh(host, user, key, timeout, base)
        except Exception as exc:  # noqa: BLE001
            base["state"] = "down"
            base["detail"] = str(exc)
        return base

    def _probe_http(self, url: str, timeout: int, base: dict) -> None:
        t0 = time.monotonic()
        req = urllib.request.Request(url, method="GET", headers={"User-Agent": "merlin-fleet"})
        try:
            with urllib.request.urlopen(req, timeout=timeout) as resp:
                base["latency_ms"] = int((time.monotonic() - t0) * 1000)
                base["state"] = "up" if resp.status < 500 else "down"
                base["detail"] = f"HTTP {resp.status}"
        except urllib.error.HTTPError as e:
            base["latency_ms"] = int((time.monotonic() - t0) * 1000)
            base["state"] = "up" if e.code < 500 else "down"  # 401/404 still = reachable
            base["detail"] = f"HTTP {e.code}"

    def _probe_ssh(self, host: str, user: str, key: str, timeout: int, base: dict) -> None:
        ssh = self.resolve_cmd("ssh")
        cmd = [ssh, "-o", "BatchMode=yes", "-o", "StrictHostKeyChecking=accept-new",
               "-o", f"ConnectTimeout={timeout}"]
        if key and Path(key).exists():
            cmd += ["-i", key]
        cmd += [f"{user}@{host}", SSH_PROBE]
        t0 = time.monotonic()
        proc = subprocess.run(cmd, capture_output=True, text=True, timeout=timeout + 8)
        base["latency_ms"] = int((time.monotonic() - t0) * 1000)
        if proc.returncode != 0:
            base["state"] = "down"
            base["detail"] = (proc.stderr or "ssh failed").strip().splitlines()[-1][:120]
            return
        parts = proc.stdout.strip().split()
        # "usedMB/totalMB ncpu load disk%"
        if len(parts) >= 4:
            base["mem"] = parts[0]
            base["cpu"] = f"{parts[2]} load / {parts[1]} cpu"
            base["disk"] = parts[3]
        base["state"] = "up"
        base["detail"] = "ssh ok"

    # ── dashboard ──────────────────────────────────────────────────────────────
    def _serve(self, port: int) -> dict:
        import sys
        sys.path.insert(0, str(REPO_ROOT / "tools"))
        try:
            from fleet_dashboard.app import run_dashboard
        except Exception as exc:  # noqa: BLE001
            return self.error(f"dashboard import failed (need flask): {exc}")
        self.log(f"Dashboard on http://127.0.0.1:{port}  (Ctrl-C to stop)")
        run_dashboard(self, port)  # blocking
        return self.ok({"served": True})
