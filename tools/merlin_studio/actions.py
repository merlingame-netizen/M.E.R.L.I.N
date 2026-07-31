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
GROUPS = {"godot": 1, "content": 1, "llm": 1, "git": 1, "daemon": 4, "misc": 2}


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
    if kind == "godot-boot":
        return ([GODOT, "--headless", "--path", ".", "--quit-after", "3"], "godot", "Boot check")
    if kind == "godot-test":
        return ([GODOT, "--headless", "--path", ".", "--quit-after", "60",
                 "--script", "res://tests/headless_runner.gd"], "godot", "Suite de tests")
    if kind == "godot-parse":
        # full import/parse pass (cold: several minutes)
        return ([GODOT, "--headless", "--path", ".", "--import"], "godot", "Import/parse projet")
    if kind == "godot-smoke":
        scene = _scene_arg(p.get("scene"))
        if not scene:
            return (None, "godot", "scène inconnue")
        dur = str(max(3, min(int(p.get("duration", 8) or 8), 60)))
        return ([GODOT, "--headless", "--path", ".", f"scenes/{scene}",
                 "--quit-after", dur], "godot", f"Smoke {scene}")
    if kind == "godot-smoke-all":
        dur = str(max(3, min(int(p.get("duration", 6) or 6), 30)))
        inner = " ; ".join(
            f'echo "=== {s} ===" ; {shlex.quote(GODOT)} --headless --path . scenes/{s} --quit-after {dur} 2>&1 | tail -25'
            for s in probes.scenes())
        return (["/bin/sh", "-c", inner], "godot", "Smoke toutes scènes")
    if kind == "godot-export":
        if not (ROOT / "export_presets.cfg").exists():
            return (None, "godot", "export_presets.cfg absent")
        preset = _s(p.get("preset", "web"))
        out = "build/web/index.html" if preset == "web" else f"build/{preset}/merlin"
        return ([GODOT, "--headless", "--path", ".", "--export-release", preset, out],
                "godot", f"Export {preset}")

    # -- Contenu --
    if kind == "content-gen":
        n = str(max(1, min(int(p.get("count", 12) or 12), 200)))
        backend = _s(p.get("backend", "template"))
        backend = backend if backend in ("template", "ollama", "workers-ai") else "template"
        return ([PY, "tools/cockpit/control_loops.py", "gen", "--count", n,
                 "--backend", backend], "content", f"Génération {n} ({backend})")
    if kind == "content-validate":
        target = _s(p.get("file", ""))
        if target:
            tp = (ROOT / target).resolve()
            if not (str(tp).startswith(str((ROOT / "data" / "ai").resolve())) and tp.exists()):
                return (None, "content", "fichier hors data/ai ou introuvable")
            return ([PY, "tools/lora/scenario_validator.py", str(tp)], "content", f"Validation {target}")
        return ([PY, "tools/lora/scenario_validator.py", "--selftest"], "content", "Validator selftest")
    if kind == "content-eval":
        n = str(max(1, min(int(p.get("count", 20) or 20), 100)))
        backend = _s(p.get("backend", "template"))
        argv = [PY, "tools/lora/eval_models.py", "--backend", backend, "--count", n]
        if p.get("models"):
            argv += ["--models", _s(p["models"])]
        return (argv, "content", f"Éval modèles ({backend})")

    # -- LLM local --
    if kind == "ollama-pull":
        model = _s(p.get("model", "")).strip()
        if not model or any(c in model for c in " ;|&$`"):
            return (None, "llm", "nom de modèle invalide")
        return (["ollama", "pull", model], "llm", f"Pull {model}")
    if kind == "ollama-generate":
        model = _s(p.get("model", "gemma3:4b")).strip()
        prompt = _s(p.get("prompt", "Décris Brocéliande en une phrase."))
        if any(c in model for c in " ;|&$`"):
            return (None, "llm", "nom de modèle invalide")
        payload = json.dumps({"model": model, "prompt": prompt, "stream": False})
        return ([PY, "-c",
                 "import json,os,sys,urllib.request;"
                 "u=os.environ.get('OLLAMA_URL','http://127.0.0.1:11434').rstrip('/')+'/api/generate';"
                 f"d={payload!r}.encode();"
                 "r=urllib.request.urlopen(urllib.request.Request(u,data=d,"
                 "headers={'content-type':'application/json'}),timeout=600);"
                 "print(json.loads(r.read()).get('response',''))"],
                "llm", f"Génération {model}")

    # -- Voix (daemons) --
    if kind == "tts-start":
        return ([PY, "tools/tts/tts_server.py", "--port", "8772"], "daemon", "Service TTS")
    if kind == "asr-start":
        return ([PY, "tools/asr/asr_server.py", "--port", "8770"], "daemon", "Service ASR")

    # -- Repo (lecture/avance rapide seulement — jamais commit/push/reset) --
    if kind == "git-fetch":
        return (["git", "fetch", "--all", "--prune"], "git", "Git fetch")
    if kind == "git-pull":
        return (["git", "pull", "--ff-only"], "git", "Git pull (ff-only)")
    return (None, "misc", "type inconnu")


def catalog() -> dict:
    """What the UI offers, with availability so impossible buttons render disabled."""
    g = probes.godot_info()
    sc = probes.scenes()
    return {"launchers": [
        {"kind": "godot-boot", "label": "Boot check (rapide)", "group": "godot",
         "available": g.get("available", False), "params": []},
        {"kind": "godot-test", "label": "Suite de tests headless", "group": "godot",
         "available": g.get("available", False), "params": []},
        {"kind": "godot-smoke", "label": "Smoke une scène", "group": "godot",
         "available": g.get("available", False) and bool(sc),
         "params": [{"name": "scene", "options": sc}, {"name": "duration", "default": 8}]},
        {"kind": "godot-smoke-all", "label": "Smoke TOUTES les scènes", "group": "godot",
         "available": g.get("available", False) and bool(sc),
         "params": [{"name": "duration", "default": 6}]},
        {"kind": "godot-parse", "label": "Import/parse projet (long)", "group": "godot",
         "available": g.get("available", False), "params": []},
        {"kind": "godot-export", "label": "Export", "group": "godot",
         "available": (ROOT / "export_presets.cfg").exists(),
         "reason": "" if (ROOT / "export_presets.cfg").exists() else "export_presets.cfg absent",
         "params": [{"name": "preset", "default": "web"}]},
        {"kind": "content-gen", "label": "Générer des cartes", "group": "content", "available": True,
         "params": [{"name": "count", "default": 12},
                    {"name": "backend", "options": ["template", "ollama", "workers-ai"]}]},
        {"kind": "content-validate", "label": "Valider (selftest ou fichier)", "group": "content",
         "available": True, "params": [{"name": "file", "default": ""}]},
        {"kind": "content-eval", "label": "Éval modèles", "group": "content", "available": True,
         "params": [{"name": "backend", "options": ["template", "ollama"]},
                    {"name": "count", "default": 20}, {"name": "models", "default": ""}]},
        {"kind": "ollama-pull", "label": "Ollama : pull modèle", "group": "llm", "available": True,
         "params": [{"name": "model", "default": "gemma3:4b"}]},
        {"kind": "ollama-generate", "label": "Ollama : générer", "group": "llm", "available": True,
         "params": [{"name": "model", "default": "gemma3:4b"}, {"name": "prompt", "default": ""}]},
        {"kind": "tts-start", "label": "Démarrer le service voix (TTS)", "group": "daemon",
         "available": True, "params": []},
        {"kind": "asr-start", "label": "Démarrer le service ASR", "group": "daemon",
         "available": True, "params": []},
        {"kind": "git-fetch", "label": "Git fetch", "group": "git", "available": True, "params": []},
        {"kind": "git-pull", "label": "Git pull (ff-only)", "group": "git", "available": True, "params": []},
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
