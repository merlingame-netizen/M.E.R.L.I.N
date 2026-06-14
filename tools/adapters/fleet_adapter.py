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
JOBS_YAML = REPO_ROOT / "infra" / "fleet" / "jobs.yaml"
JOBS_LOG = REPO_ROOT / "infra" / "fleet" / "status" / "jobs.json"
QUOTA_JSON = REPO_ROOT / "infra" / "fleet" / "status" / "quota.json"

# Per-capability node preference (efficient dispatch onto free nodes).
PREFERENCE = {
    "llm": ["oracle-a1", "gcp-micro"],
    "heavy": ["oracle-a1", "gcp-micro"],
    "api": ["cf-worker", "gcp-micro", "oracle-a1"],
    "data-sqlite": ["cf-worker", "gcp-micro", "oracle-a1"],
    "edge": ["cf-worker"],
    "data": ["gcp-micro", "cf-worker", "oracle-a1"],
    "cron": ["gcp-micro", "oracle-a1"],
    "service": ["gcp-micro", "oracle-a1"],
    "container": ["gcp-micro", "oracle-a1"],
}
SAFETY = 0.95  # never use more than 95% of a free quota

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
            "jobs": "List defined jobs (infra/fleet/jobs.yaml)",
            "quota": "Show free-tier quota usage/headroom per node",
            "plan": "Dry-run: which node would run a job (--job NAME)",
            "run": "Dispatch + execute a job on the best free node (--job NAME)",
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
        if action == "jobs":
            return self.ok({"jobs": self._load_jobs(), "path": str(JOBS_YAML)})
        if action == "quota":
            return self.ok(self._quota())
        if action == "plan":
            job = self._find_job(kwargs.get("job"))
            if isinstance(job, dict) and job.get("_error"):
                return self.error(job["_error"])
            return self.ok(self._route(job))
        if action == "run":
            return self._run_job(kwargs.get("job"))
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

    # ── jobs / quota / dispatch ────────────────────────────────────────────────
    def _load_jobs(self) -> list[dict]:
        if not JOBS_YAML.exists():
            return []
        return (yaml.safe_load(JOBS_YAML.read_text()) or {}).get("jobs", [])

    def _find_job(self, name: str | None):
        if not name:
            return {"_error": "requires --job NAME"}
        job = next((j for j in self._load_jobs() if j.get("name") == name), None)
        return job or {"_error": f"unknown job '{name}'"}

    def _usage(self) -> dict:
        if QUOTA_JSON.exists():
            return json.loads(QUOTA_JSON.read_text()).get("nodes", {})
        return {}

    def _quota(self, inv: dict | None = None) -> dict:
        inv = inv or self._load()
        usage = self._usage()
        nodes = {}
        for t in inv.get("targets", []):
            q = t.get("quota") or {}
            u = usage.get(t["name"], {})
            node: dict = {"limits": q, "usage": u}
            if q.get("ram_mb"):
                node["ram_pct"] = round(100 * u.get("reserved_ram_mb", 0) / q["ram_mb"])
            if q.get("requests_day"):
                node["req_pct"] = round(100 * u.get("requests_today", 0) / q["requests_day"])
            nodes[t["name"]] = node
        return {"nodes": nodes}

    def _guard(self, node: dict, job: dict, u: dict) -> tuple[bool, str]:
        q = node.get("quota") or {}
        cost = job.get("cost") or {}
        # RAM fit (strict — never exceed the node's free RAM)
        if q.get("ram_mb"):
            free = q["ram_mb"] - int(u.get("reserved_ram_mb", 0))
            need = int(cost.get("ram_mb", 128))
            if need > free:
                return False, f"RAM {need}MB > free {free}MB"
        # Daily requests cap (e.g. Cloudflare)
        if q.get("requests_day"):
            used = int(u.get("requests_today", 0))
            if used + int(cost.get("requests", 1)) > q["requests_day"] * SAFETY:
                return False, f"near requests/day cap ({used}/{q['requests_day']})"
        return True, "ok"

    def _route(self, job: dict, inv: dict | None = None) -> dict:
        inv = inv or self._load()
        targets = {t["name"]: t for t in inv.get("targets", [])}
        needs = list(job.get("needs", []))
        usage = self._usage()
        # build candidate order from per-need preference, then any capable node
        order: list[str] = []
        for need in needs:
            for n in PREFERENCE.get(need, []):
                if n not in order:
                    order.append(n)
        for name, t in targets.items():
            if set(needs).issubset(set(t.get("capabilities", []))) and name not in order:
                order.append(name)
        decisions, chosen = [], None
        for name in order:
            t = targets.get(name)
            if not t:
                continue
            if needs and not set(needs).issubset(set(t.get("capabilities", []))):
                decisions.append({"node": name, "ok": False, "reason": "missing capability"})
                continue
            if not (t.get("host") or t.get("url")):
                decisions.append({"node": name, "ok": False, "reason": "not deployed"})
                continue
            ok, reason = self._guard(t, job, usage.get(name, {}))
            decisions.append({"node": name, "ok": ok, "reason": reason})
            if ok and chosen is None:
                chosen = name
        return {"job": job.get("name"), "needs": needs, "chosen": chosen, "candidates": decisions}

    def _reserve(self, node: str, job: dict, sign: int) -> None:
        data = {"nodes": self._usage()}
        u = data["nodes"].setdefault(node, {})
        cost = job.get("cost") or {}
        u["reserved_ram_mb"] = max(0, int(u.get("reserved_ram_mb", 0)) + sign * int(cost.get("ram_mb", 128)))
        if sign > 0:
            u["requests_today"] = int(u.get("requests_today", 0)) + int(cost.get("requests", 1))
        QUOTA_JSON.parent.mkdir(parents=True, exist_ok=True)
        QUOTA_JSON.write_text(json.dumps(data, indent=2))

    def _log_run(self, rec: dict) -> None:
        log = []
        if JOBS_LOG.exists():
            log = json.loads(JOBS_LOG.read_text()).get("runs", [])
        log.insert(0, rec)
        JOBS_LOG.parent.mkdir(parents=True, exist_ok=True)
        JOBS_LOG.write_text(json.dumps({"runs": log[:100]}, indent=2))

    def _run_job(self, name: str | None) -> dict:
        job = self._find_job(name)
        if isinstance(job, dict) and job.get("_error"):
            return self.error(job["_error"])
        inv = self._load()
        route = self._route(job, inv)
        chosen = route["chosen"]
        if not chosen:
            return self.error("no eligible free node (capability/quota guard)", route)
        node = {t["name"]: t for t in inv["targets"]}[chosen]
        self._reserve(chosen, job, +1)
        rec = {"job": job["name"], "node": chosen,
               "started": datetime.now(timezone.utc).isoformat(timespec="seconds")}
        try:
            if node.get("provider") == "cloudflare" or node.get("type") == "http":
                out = self._exec_http_job(node, job)
            else:
                out = self._exec_ssh_job(node, inv.get("defaults", {}), job)
        finally:
            self._reserve(chosen, job, -1)
        rec.update(out)
        self._log_run(rec)
        return self.ok(rec) if out.get("ok") else self.error(out.get("detail", "job failed"), rec)

    def _exec_ssh_job(self, node: dict, defaults: dict, job: dict) -> dict:
        cmd_str = job.get("cmd")
        if not cmd_str:
            return {"ok": False, "detail": "job has no cmd"}
        host = (node.get("host") or "").strip()
        user = node.get("ssh_user") or defaults.get("ssh_user", "ubuntu")
        key = os.path.expanduser(node.get("ssh_key") or defaults.get("ssh_key", ""))
        ssh = self.resolve_cmd("ssh")
        cmd = [ssh, "-o", "BatchMode=yes", "-o", "StrictHostKeyChecking=accept-new",
               "-o", "ConnectTimeout=8"]
        if key and Path(key).exists():
            cmd += ["-i", key]
        cmd += [f"{user}@{host}", cmd_str]
        try:
            p = subprocess.run(cmd, capture_output=True, text=True, timeout=int(job.get("timeout", 300)))
            ok = p.returncode == 0
            return {"ok": ok, "detail": (p.stdout or p.stderr).strip()[-300:]}
        except Exception as exc:  # noqa: BLE001
            return {"ok": False, "detail": f"ssh exec failed: {exc}"}

    def _exec_http_job(self, node: dict, job: dict) -> dict:
        http = job.get("http")
        if http:
            try:
                req = urllib.request.Request(
                    http["url"], method=http.get("method", "GET"),
                    data=json.dumps(http["body"]).encode() if http.get("body") else None,
                    headers={"content-type": "application/json", "User-Agent": "merlin-fleet"})
                with urllib.request.urlopen(req, timeout=30) as r:
                    return {"ok": r.status < 400, "detail": f"HTTP {r.status}"}
            except Exception as exc:  # noqa: BLE001
                return {"ok": False, "detail": f"http job failed: {exc}"}
        # else: a local command (e.g. wrangler) for this serverless node
        cmd_str = job.get("cmd")
        if not cmd_str:
            return {"ok": False, "detail": "cloudflare job needs 'http' or 'cmd'"}
        try:
            p = subprocess.run(cmd_str, shell=True, capture_output=True, text=True,
                               timeout=int(job.get("timeout", 300)))
            return {"ok": p.returncode == 0, "detail": (p.stdout or p.stderr).strip()[-300:]}
        except Exception as exc:  # noqa: BLE001
            return {"ok": False, "detail": f"exec failed: {exc}"}

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
