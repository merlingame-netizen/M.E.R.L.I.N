"""Cockpit control core — MERLIN dev visibility + dev/model launchers.

Dependency-light (stdlib only) so it runs anywhere the cockpit runs (incl. the 1 GB VM).
Two responsibilities:
  1. dev_status()  — aggregate "what's happening in MERLIN dev" from the autodev status
     files + git, for the cockpit's Dev pane.
  2. launch()/launches() — start a dev/model job (Kaggle, Colab, local model, fleet job,
     generation/validation loop) as a DETACHED process, tracked in a registry, so the
     cockpit can fire-and-monitor. Every launch kind maps to an existing portable entry
     point via an allow-list (no arbitrary shell); args are shlex-quoted.

Launch records + logs live under tools/autodev/status/ (cockpit_launches.json, cockpit_logs/).
"""
from __future__ import annotations

import json
import os
import shlex
import signal
import subprocess
import sys
import time
import uuid
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]            # repo root
STATUS = ROOT / "tools" / "autodev" / "status"
LOGDIR = STATUS / "cockpit_logs"
REGISTRY = STATUS / "cockpit_launches.json"
PY = sys.executable or "python3"


# ── helpers ──────────────────────────────────────────────────────────────────
def _read_json(path: Path, default):
    try:
        return json.loads(path.read_text(encoding="utf-8"))
    except Exception:
        return default


def _tail_jsonl(path: Path, n: int):
    try:
        lines = path.read_text(encoding="utf-8").splitlines()
    except Exception:
        return []
    out = []
    for ln in lines[-n:]:
        ln = ln.strip()
        if ln:
            try:
                out.append(json.loads(ln))
            except Exception:
                out.append({"raw": ln[:200]})
    return out


def _git(*args):
    try:
        return subprocess.run(["git", "-C", str(ROOT), *args], capture_output=True,
                              text=True, timeout=8).stdout.strip()
    except Exception:
        return ""


# ── 1. dev status ────────────────────────────────────────────────────────────
def dev_status() -> dict:
    """Snapshot of MERLIN dev state for the cockpit Dev pane."""
    session = _read_json(STATUS / "session.json", {})
    health = _read_json(STATUS / "health_report.json", {})
    msgs = _read_json(STATUS / "agent_messages.json", {})
    queue = _read_json(STATUS / "feature_queue.json", {})
    lora = _read_json(STATUS / "llm-lora.json", {})

    msg_list = msgs.get("messages", []) if isinstance(msgs, dict) else []
    by_type: dict[str, int] = {}
    for m in msg_list:
        by_type[m.get("type", "?")] = by_type.get(m.get("type", "?"), 0) + 1

    q_items = queue.get("features", queue.get("items", queue)) if isinstance(queue, dict) else queue
    q_count = len(q_items) if isinstance(q_items, list) else (
        len(q_items) if isinstance(q_items, dict) else 0)

    commits = []
    raw = _git("log", "-8", "--pretty=%h\x1f%s\x1f%cr\x1f%an")
    for line in raw.splitlines():
        p = line.split("\x1f")
        if len(p) == 4:
            commits.append({"hash": p[0], "subject": p[1], "when": p[2], "author": p[3]})

    return {
        "branch": _git("rev-parse", "--abbrev-ref", "HEAD"),
        "session": {
            "state": session.get("state"),
            "objective": session.get("objective"),
            "cycle": session.get("cycle"),
            "updated_at": session.get("updated_at"),
            "workers": session.get("workers"),
            "checkpoint": session.get("checkpoint"),
        },
        "health": health,
        "lora": lora,
        "agent_messages": {"total": len(msg_list), "by_type": by_type,
                           "recent": msg_list[-6:]},
        "queue_count": q_count,
        "events": _tail_jsonl(STATUS / "events.jsonl", 12),
        "commits": commits,
        "checked_at": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()),
    }


# ── 2. launchers (allow-list) ────────────────────────────────────────────────
def _s(v) -> str:
    return str(v if v is not None else "")


def build_argv(kind: str, params: dict) -> list[str] | None:
    """Map a launch kind + params to a concrete argv (allow-list). None if unknown."""
    p = params or {}
    if kind == "noop":  # connectivity / "launcher works" test
        return [PY, "-c", "import time;print('cockpit-launch-ok');time.sleep(1)"]
    if kind == "kaggle-train":
        brain = _s(p.get("brain", "narrator"))
        action = _s(p.get("action", "submit"))  # setup|submit|status|download
        argv = [PY, "tools/lora/remote_kaggle_train.py", action,
                "--workspace", str(ROOT), "--brain", brain]
        if p.get("username"):
            argv += ["--username", _s(p["username"])]
        if p.get("slug"):
            argv += ["--slug", _s(p["slug"])]
        if action == "download" and p.get("output"):
            argv += ["--output", _s(p["output"])]
        return argv
    if kind == "gen-cycle":
        return [PY, "tools/cockpit/control_loops.py", "gen",
                "--count", _s(p.get("count", 12)), "--backend", _s(p.get("backend", "ollama"))]
    if kind == "validate-cycle":
        return [PY, "tools/cockpit/control_loops.py", "validate"]
    if kind == "train-cadence":
        return [PY, "tools/cockpit/control_loops.py", "train", "--brain", _s(p.get("brain", "narrator"))]
    if kind == "fleet-job":
        return [PY, "tools/cli.py", "fleet", "run", "--job", _s(p.get("job", "ping-self"))]
    if kind == "ollama-gen":
        return [PY, "tools/cli.py", "ollama", "generate",
                "--model", _s(p.get("model", "merlin-narrator")), "--prompt", _s(p.get("prompt", "Bonjour"))]
    return None


# Colab is not a subprocess: it's a notebook the user opens; we record intent + a queue
# entry a Colab notebook can poll (data/ai/colab_queue.json).
COLAB_NOTEBOOKS = {
    "narrator": "tools/lora/train_colab.ipynb",
    "distill": "tools/lora/distill_merlin_colab.ipynb",
}


def launch_colab(params: dict) -> dict:
    nb = COLAB_NOTEBOOKS.get(_s(params.get("notebook", "narrator")), COLAB_NOTEBOOKS["narrator"])
    repo = _git("config", "--get", "remote.origin.url") or "merlingame-netizen/M.E.R.L.I.N"
    branch = _git("rev-parse", "--abbrev-ref", "HEAD") or "master"
    # github.dev / colab open link
    link = f"https://colab.research.google.com/github/merlingame-netizen/M.E.R.L.I.N/blob/{branch}/{nb}"
    queue_path = ROOT / "data" / "ai" / "colab_queue.json"
    queue = _read_json(queue_path, {"queue": []})
    entry = {"id": uuid.uuid4().hex[:8], "notebook": nb, "params": params,
             "requested_at": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()), "status": "queued"}
    queue.setdefault("queue", []).append(entry)
    try:
        queue_path.parent.mkdir(parents=True, exist_ok=True)
        queue_path.write_text(json.dumps(queue, indent=2), encoding="utf-8")
    except Exception:
        pass
    return {"kind": "colab", "open_url": link, "notebook": nb, "queued": entry["id"]}


# ── launch + registry ────────────────────────────────────────────────────────
def _load_registry() -> list:
    return _read_json(REGISTRY, [])


def _save_registry(recs: list) -> None:
    try:
        REGISTRY.parent.mkdir(parents=True, exist_ok=True)
        tmp = REGISTRY.with_suffix(".tmp")
        tmp.write_text(json.dumps(recs[-200:], indent=2), encoding="utf-8")
        tmp.replace(REGISTRY)
    except Exception:
        pass


def _alive(pid: int) -> bool:
    try:
        os.kill(pid, 0)
        return True
    except Exception:
        return False


def launch(kind: str, params: dict | None = None) -> dict:
    """Start a launch kind as a detached process (or Colab intent). Returns a record."""
    params = params or {}
    if kind == "colab":
        rec = {"id": uuid.uuid4().hex[:8], "kind": "colab", **launch_colab(params),
               "started_at": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()), "status": "manual"}
        recs = _load_registry()
        recs.append(rec)
        _save_registry(recs)
        return rec

    argv = build_argv(kind, params)
    if argv is None:
        return {"error": f"unknown launch kind '{kind}'"}

    jid = uuid.uuid4().hex[:8]
    LOGDIR.mkdir(parents=True, exist_ok=True)
    log = LOGDIR / f"{jid}.log"
    rc = LOGDIR / f"{jid}.rc"
    cmd_str = " ".join(shlex.quote(a) for a in argv)
    wrapped = f"cd {shlex.quote(str(ROOT))}; {cmd_str} >{shlex.quote(str(log))} 2>&1; echo $? >{shlex.quote(str(rc))}"
    try:
        proc = subprocess.Popen(["/bin/sh", "-c", wrapped], start_new_session=True)
        pid = proc.pid
    except Exception as e:
        return {"error": f"spawn failed: {e}"}

    rec = {"id": jid, "kind": kind, "params": params, "cmd": cmd_str, "pid": pid,
           "log": str(log.relative_to(ROOT)), "started_at": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()),
           "status": "running"}
    recs = _load_registry()
    recs.append(rec)
    _save_registry(recs)
    return rec


def _refresh(rec: dict) -> dict:
    if rec.get("status") not in ("running",):
        return rec
    jid = rec["id"]
    rc = LOGDIR / f"{jid}.rc"
    if rc.exists():
        try:
            code = int(rc.read_text().strip() or "1")
        except Exception:
            code = 1
        rec["status"] = "done" if code == 0 else "failed"
        rec["exit_code"] = code
    elif rec.get("pid") and not _alive(rec["pid"]):
        rec["status"] = "ended"  # process gone, no rc captured
    return rec


def launches(limit: int = 30) -> dict:
    recs = _load_registry()
    changed = False
    for r in recs:
        before = r.get("status")
        _refresh(r)
        changed = changed or (r.get("status") != before)
    if changed:
        _save_registry(recs)
    # attach a short log tail to the most recent few
    out = list(reversed(recs[-limit:]))
    for r in out[:8]:
        lp = ROOT / r.get("log", "")
        if r.get("log") and lp.exists():
            try:
                r["log_tail"] = lp.read_text(encoding="utf-8")[-600:]
            except Exception:
                pass
    return {"launches": out, "count": len(recs)}


def stop(jid: str) -> dict:
    recs = _load_registry()
    for r in recs:
        if r["id"] == jid and r.get("pid") and _alive(r["pid"]):
            try:
                os.killpg(os.getpgid(r["pid"]), signal.SIGTERM)
                r["status"] = "stopped"
                _save_registry(recs)
                return {"ok": True, "id": jid}
            except Exception as e:
                return {"error": str(e)}
    return {"error": "not found or not running"}


def launchers_catalog() -> dict:
    """Describe available launchers for the UI (kind, label, params)."""
    return {"launchers": [
        {"kind": "kaggle-train", "label": "Entraînement Kaggle (GPU gratuit)",
         "params": [{"name": "brain", "options": ["narrator", "gamemaster", "worker"]},
                    {"name": "action", "options": ["submit", "status", "download", "setup"]},
                    {"name": "username"}, {"name": "slug"}]},
        {"kind": "colab", "label": "Entraînement Colab (notebook)",
         "params": [{"name": "notebook", "options": ["narrator", "distill"]}]},
        {"kind": "gen-cycle", "label": "Cycle génération (cartes/lore → validator)",
         "params": [{"name": "count", "default": 12}, {"name": "backend", "options": ["ollama", "workers-ai"]}]},
        {"kind": "validate-cycle", "label": "Cycle validation (parse + télémétrie)", "params": []},
        {"kind": "train-cadence", "label": "Cadence retrain (si corpus prêt)",
         "params": [{"name": "brain", "options": ["narrator", "gamemaster", "worker"]}]},
        {"kind": "fleet-job", "label": "Job fleet (nœud gratuit)",
         "params": [{"name": "job", "default": "ping-self"}]},
        {"kind": "ollama-gen", "label": "Génération modèle local (Ollama)",
         "params": [{"name": "model", "default": "merlin-narrator"}, {"name": "prompt"}]},
        {"kind": "noop", "label": "Test (vérifie que le lanceur marche)", "params": []},
    ]}


if __name__ == "__main__":  # tiny CLI for testing
    import argparse
    ap = argparse.ArgumentParser()
    ap.add_argument("cmd", choices=["dev", "launch", "launches", "catalog", "stop"])
    ap.add_argument("--kind", default="noop")
    ap.add_argument("--id", default="")
    ap.add_argument("--params", default="{}")
    a = ap.parse_args()
    if a.cmd == "dev":
        print(json.dumps(dev_status(), indent=2, ensure_ascii=False))
    elif a.cmd == "launch":
        print(json.dumps(launch(a.kind, json.loads(a.params)), indent=2, ensure_ascii=False))
    elif a.cmd == "launches":
        print(json.dumps(launches(), indent=2, ensure_ascii=False))
    elif a.cmd == "catalog":
        print(json.dumps(launchers_catalog(), indent=2, ensure_ascii=False))
    elif a.cmd == "stop":
        print(json.dumps(stop(a.id), indent=2, ensure_ascii=False))
