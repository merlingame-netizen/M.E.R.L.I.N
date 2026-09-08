"""MERLIN Studio — action layer: allow-listed jobs, launched detached, tracked.

Same mechanism as the GCP cockpit (Popen /bin/sh -c, start_new_session, log + .rc file,
JSON registry) but the allow-list targets the REAL Linux/ARM commands on the Oracle VM:

  * Godot is shelled DIRECTLY (never tools/cli.py godot — godot_adapter.py:19 hardcodes
    PROJECT_ROOT = C:\\Users\\PGNK2128\\Godot-MCP, which is Windows-only and would break).
  * Ollama goes through its HTTP API / the ollama CLI ($OLLAMA_URL honoured) — never
    ollama_adapter.py, whose BASE_URL is hardcoded to localhost with no env override.
  * Content validation runs tools/lora/scenario_validator.py directly (control_loops.py
    'validate' shells the Windows-broken cli.py path).

Concurrency: jobs are grouped; only one job per group runs at a time (a second Godot run
on the same box would thrash CPU/RAM), enforced at launch time.
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

from . import probes

ROOT = probes.ROOT
STATUS = ROOT / "tools" / "autodev" / "status"
LOGDIR = STATUS / "studio_logs"
REGISTRY = STATUS / "studio_jobs.json"
RUNS = STATUS / "studio_runs.json"
PY = sys.executable or "python3"
GODOT = probes.GODOT

# group -> max concurrent (1 = serialized)
# Une conversation N'EST PAS un job d'analyse. Les mettre dans le même groupe
# `llm` faisait répondre « groupe 'llm' déjà occupé » dès qu'un agent tournait —
# c'est-à-dire précisément quand Maxime voulait savoir ce qui se passait. Le chat
# a donc son propre groupe : le modèle étant résident (voir a_brasero.sh), un
# second appel ne recharge rien, il partage juste le CPU quelques secondes.
GROUPS = {"game": 1, "agents": 2, "misc": 2}

# Résolutions autorisées pour le jeu natif (jamais interpolé librement).
GAME_RES = ("1280x720", "960x540", "1920x1080")


def _now() -> str:
    return time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime())


def _s(v) -> str:
    return str(v if v is not None else "")


def _scene_arg(name: str) -> str:
    """Only ever allow a real scene file name (no path traversal)."""
    name = os.path.basename(_s(name))
    return name if name in probes.scenes() else ""


# ── allow-list ───────────────────────────────────────────────────────────────
def build(kind: str, p: dict) -> tuple[list[str] | None, str, str]:
    """Return (argv, group, label). argv=None => unknown/refused kind."""
    p = p or {}
    # -- Godot (shelled directly; headless on the VM) --
    if kind == "game-start":
        res = _s(p.get("res", "1280x720"))
        if res not in GAME_RES:
            res = "1280x720"
        return (["bash", "infra/oracle/game/game-stack.sh", "start", "--res", res],
                "game", f"Jeu natif : démarrer ({res})")
    if kind == "game-stop":
        return (["bash", "infra/oracle/game/game-stack.sh", "stop"],
                "game", "Jeu natif : arrêter")
    if kind == "game-sync":
        # Sync GitHub -> VM + réimport des assets si HEAD a changé (long à froid).
        return (["bash", "infra/oracle/game/game-sync.sh"],
                "game", "Jeu natif : sync + import")
    if kind == "game-restart":
        res = _s(p.get("res", "1280x720"))
        if res not in GAME_RES:
            res = "1280x720"
        return (["bash", "infra/oracle/game/game-stack.sh", "restart", "--res", res],
                "game", f"Jeu natif : redémarrer ({res})")

    # -- Agents de la VM (allow-list stricte : ids du manifeste uniquement) --
    if kind == "agent-run":
        aid = _s(p.get("id", "")).strip()
        valid = {a.get("id") for a in probes.agents().get("agents", [])}
        if aid not in valid:
            return (None, "agents", f"agent inconnu: {aid or '(vide)'}")
        return (["bash", "infra/oracle/agents/agent-run.sh", aid],
                "agents", f"Agent : {aid}")
    if kind == "agents-install":
        return (["bash", "infra/oracle/agents/install-agents.sh"],
                "agents", "Agents : (ré)installer la planification")

    # -- Repo (lecture/avance rapide seulement — jamais commit/push/reset) --
    return None, "", "misc"

def catalog() -> dict:
    """What the UI offers, with availability so impossible buttons render disabled."""
    g = probes.godot_info()
    sc = probes.scenes()
    gm = probes.game()
    return {"launchers": [
        {"kind": "game-start", "label": "Jeu natif : démarrer (VNC)", "group": "game",
         "available": gm.get("available", False) and gm.get("image_built", False),
         "reason": gm.get("reason", ""),
         "params": [{"name": "res", "options": list(GAME_RES)}]},
        {"kind": "game-stop", "label": "Jeu natif : arrêter", "group": "game",
         "available": gm.get("available", False), "params": []},
        {"kind": "game-sync", "label": "Jeu natif : sync + import assets", "group": "game",
         "available": gm.get("available", False), "params": []},
        {"kind": "game-restart", "label": "Jeu natif : redémarrer", "group": "game",
         "available": gm.get("available", False) and gm.get("image_built", False),
         "reason": gm.get("reason", ""),
         "params": [{"name": "res", "options": list(GAME_RES)}]},
    ]}


# ── registry ─────────────────────────────────────────────────────────────────
def _load() -> list:
    return probes._read_json(REGISTRY, [])


def _save(recs: list) -> None:
    try:
        REGISTRY.parent.mkdir(parents=True, exist_ok=True)
        tmp = REGISTRY.with_suffix(".tmp")
        tmp.write_text(json.dumps(recs[-200:], indent=2, ensure_ascii=False), encoding="utf-8")
        tmp.replace(REGISTRY)
    except Exception:
        pass


def _alive(pid: int) -> bool:
    try:
        os.kill(pid, 0)
        return True
    except Exception:
        return False


def _refresh(rec: dict) -> dict:
    if rec.get("status") != "running":
        return rec
    rc = LOGDIR / f"{rec['id']}.rc"
    if rc.exists():
        try:
            code = int(rc.read_text().strip() or "1")
        except Exception:
            code = 1
        rec["status"] = "done" if code == 0 else "failed"
        rec["exit_code"] = code
        rec["ended_at"] = _now()
        _record_run(rec)
    elif rec.get("pid") and not _alive(rec["pid"]):
        rec["status"] = "ended"
    return rec


def _record_run(rec: dict) -> None:
    """Keep the latest outcome per scene/kind so the Run pane shows state at a glance."""
    try:
        runs = probes._read_json(RUNS, {})
        key = rec["kind"]
        if rec["kind"] == "godot-smoke":
            key = "smoke:" + _s((rec.get("params") or {}).get("scene"))
        log = ""
        lp = LOGDIR / f"{rec['id']}.log"
        if lp.exists():
            log = lp.read_text(encoding="utf-8", errors="replace")
        runs[key] = {"id": rec["id"], "status": rec["status"], "exit_code": rec.get("exit_code"),
                     "at": rec.get("ended_at", _now()),
                     "script_errors": log.count("SCRIPT ERROR"),
                     "tail": log[-400:]}
        RUNS.write_text(json.dumps(runs, indent=2, ensure_ascii=False), encoding="utf-8")
    except Exception:
        pass


def _running_in_group(group: str, recs: list) -> int:
    return sum(1 for r in recs if r.get("group") == group and r.get("status") == "running")


def launch(kind: str, params: dict | None = None) -> dict:
    params = params or {}
    argv, group, label = build(kind, params)
    if argv is None:
        return {"error": f"refusé: {label}"}
    recs = [_refresh(r) for r in _load()]
    if _running_in_group(group, recs) >= GROUPS.get(group, 1):
        _save(recs)
        return {"error": f"groupe '{group}' déjà occupé — attends la fin du job en cours"}

    jid = uuid.uuid4().hex[:8]
    LOGDIR.mkdir(parents=True, exist_ok=True)
    log, rc = LOGDIR / f"{jid}.log", LOGDIR / f"{jid}.rc"
    cmd = " ".join(shlex.quote(a) for a in argv)
    wrapped = (f"cd {shlex.quote(str(ROOT))}; {cmd} >{shlex.quote(str(log))} 2>&1; "
               f"echo $? >{shlex.quote(str(rc))}")
    try:
        proc = subprocess.Popen(["/bin/sh", "-c", wrapped], start_new_session=True)
    except Exception as e:
        return {"error": f"spawn: {e}"}
    rec = {"id": jid, "kind": kind, "label": label, "group": group, "params": params,
           "cmd": cmd, "pid": proc.pid, "log": str(log.relative_to(ROOT)),
           "started_at": _now(), "status": "running"}
    recs.append(rec)
    _save(recs)
    return rec


def jobs(limit: int = 40) -> dict:
    recs = _load()
    before = json.dumps([r.get("status") for r in recs])
    recs = [_refresh(r) for r in recs]
    if json.dumps([r.get("status") for r in recs]) != before:
        _save(recs)
    out = list(reversed(recs[-limit:]))
    for r in out[:10]:
        lp = ROOT / r.get("log", "")
        if r.get("log") and lp.exists():
            try:
                r["log_tail"] = lp.read_text(encoding="utf-8", errors="replace")[-800:]
            except Exception:
                pass
    running = {g: _running_in_group(g, recs) for g in GROUPS}
    return {"jobs": out, "count": len(recs), "running": running, "groups": GROUPS}


def job_log(jid: str) -> str:
    lp = LOGDIR / f"{os.path.basename(jid)}.log"
    try:
        return lp.read_text(encoding="utf-8", errors="replace")
    except Exception:
        return ""


def stop(jid: str) -> dict:
    recs = _load()
    for r in recs:
        if r["id"] == jid and r.get("pid") and _alive(r["pid"]):
            try:
                os.killpg(os.getpgid(r["pid"]), signal.SIGTERM)
                r["status"] = "stopped"
                r["ended_at"] = _now()
                _save(recs)
                return {"ok": True, "id": jid}
            except Exception as e:
                return {"error": str(e)}
    return {"error": "introuvable ou déjà terminé"}
