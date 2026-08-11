"""MERLIN Studio — read-only probes (stdlib only, never raise).

Everything the VM-local dashboard *shows*. Each probe degrades to a partial dict with an
"error"/"available" flag instead of throwing, so one broken piece never blanks the page.

Grounded on the real Oracle ARM A1 layout (cloud-init): godot at /usr/local/bin/godot,
Ollama on $OLLAMA_URL, repo cloned in ~/workspace/M.E.R.L.I.N, docker stack "merlin-*".
"""
from __future__ import annotations

import json
import os
import socket
import subprocess
import time
import urllib.request
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]          # repo root
STATUS_DIR = ROOT / "tools" / "autodev" / "status"
CANON = ROOT / "data" / "ai" / "lore_canon.json"
CORPUS = ROOT / "data" / "ai" / "training" / "auto_corpus.jsonl"
LOOPS = STATUS_DIR / "cockpit_loops.json"
OLLAMA_URL = os.environ.get("OLLAMA_URL", "http://127.0.0.1:11434").rstrip("/")
TTS_URL = os.environ.get("TTS_URL", "http://127.0.0.1:8772").rstrip("/")
ASR_URL = os.environ.get("ASR_URL", "http://127.0.0.1:8770").rstrip("/")
GODOT = os.environ.get("GODOT_BIN", "godot")

# Ports worth probing on the VM (name shown next to each in the Hôte pane).
PORTS = [
    (11434, "ollama"), (3000, "open-webui"), (8443, "code-server"),
    (8081, "filebrowser"), (5432, "postgres"), (8770, "asr"),
    (8772, "tts"), (8790, "studio"), (5900, "vnc-game"),
]

_cache: dict = {}


def _sh(argv, timeout=8) -> tuple[str, int]:
    """Run a command, return (output, rc). Never raises."""
    try:
        p = subprocess.run(argv, cwd=str(ROOT), capture_output=True, text=True, timeout=timeout)
        return ((p.stdout or "") + (p.stderr or "")).strip(), p.returncode
    except Exception as e:
        return f"{type(e).__name__}: {e}", 127


def _read_json(path: Path, default):
    try:
        return json.loads(Path(path).read_text(encoding="utf-8"))
    except Exception:
        return default


def _http_json(url: str, timeout=4):
    try:
        with urllib.request.urlopen(url, timeout=timeout) as r:
            return json.loads(r.read().decode("utf-8", "replace"))
    except Exception:
        return None


def _now() -> str:
    return time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime())


# ── Godot / jeu ──────────────────────────────────────────────────────────────
def scenes() -> list[str]:
    """The scenes that ACTUALLY exist (CLAUDE.md's list is stale — verified)."""
    try:
        return sorted(p.name for p in (ROOT / "scenes").glob("*.tscn"))
    except Exception:
        return []


def godot_info() -> dict:
    """Godot binary + project facts. Cached (version never changes at runtime)."""
    if "godot" in _cache:
        info = dict(_cache["godot"])
    else:
        out, rc = _sh([GODOT, "--headless", "--version"], timeout=20)
        version = out.splitlines()[-1].strip() if rc == 0 and out else ""
        info = {"binary": GODOT, "version": version, "available": rc == 0}
        _cache["godot"] = dict(info)
    # project.godot facts (cheap, re-read so edits show up)
    proj = {"name": "", "main_scene": "", "features": ""}
    try:
        txt = (ROOT / "project.godot").read_text(encoding="utf-8", errors="replace")
        for line in txt.splitlines():
            s = line.strip()
            if s.startswith("config/name="):
                proj["name"] = s.split("=", 1)[1].strip().strip('"')
            elif s.startswith("run/main_scene="):
                proj["main_scene"] = s.split("=", 1)[1].strip().strip('"')
            elif s.startswith("config/features="):
                proj["features"] = s.split("=", 1)[1].strip()
    except Exception:
        pass
    info["project"] = proj
    # version mismatch warning (project features may target a newer Godot than the binary)
    warn = ""
    if info.get("version") and proj.get("features"):
        bin_mm = ".".join(info["version"].split(".")[:2])          # e.g. "4.4"
        import re as _re
        targets = _re.findall(r"\d+\.\d+", proj["features"])       # e.g. ["4.5"]
        if bin_mm and targets and bin_mm not in targets:
            warn = f"projet cible Godot {targets[0]} — binaire {bin_mm}"
    info["warning"] = warn
    info["headless_only"] = not bool(os.environ.get("DISPLAY"))
    info["xvfb"] = _sh(["which", "xvfb-run"], timeout=4)[1] == 0
    info["scenes"] = scenes()
    info["export_presets"] = (ROOT / "export_presets.cfg").exists()
    return info


def last_runs() -> dict:
    """Latest smoke/test outcomes per scene, written by the action layer."""
    return _read_json(STATUS_DIR / "studio_runs.json", {})


AGENTS_DIR = ROOT / "infra" / "oracle" / "agents"


def agents() -> dict:
    """Agents planifiés sur la VM + leur dernier passage. Never raises."""
    manifest = _read_json(AGENTS_DIR / "agents.json", {})
    defs = manifest.get("agents", []) if isinstance(manifest, dict) else []
    state_dir = Path.home() / ".cache" / "merlin-agents"
    out = []
    for a in defs:
        st = _read_json(state_dir / f"{a.get('id')}.json", {})
        out.append({
            "id": a.get("id"), "label": a.get("label", a.get("id")),
            "desc": a.get("desc", ""), "schedule": a.get("schedule", ""),
            "enabled": bool(a.get("enabled")),
            "last_run": st.get("last_run", ""), "ok": st.get("ok"),
            "rc": st.get("rc"), "duration_s": st.get("duration_s"),
            "summary": st.get("summary", ""),
        })
    installed = False
    try:
        cron = _sh(["crontab", "-l"], timeout=5)[0]
        installed = "merlin-agents" in cron
    except Exception:
        pass
    health = []
    try:
        hist = (state_dir / "health-history.jsonl").read_text(encoding="utf-8").splitlines()
        health = [json.loads(x) for x in hist[-24:] if x.strip()]
    except Exception:
        pass
    ci = []
    try:
        lines = (state_dir / "ci" / "history.jsonl").read_text(encoding="utf-8").splitlines()
        ci = [json.loads(x) for x in lines[-8:] if x.strip()]
    except Exception:
        pass
    report = ""
    try:
        report = (state_dir / "daily-report.md").read_text(encoding="utf-8")[:8000]
    except Exception:
        pass
    missions = 0
    try:
        missions = len(list((Path.home() / ".cache" / "merlin-missions" / "queue").glob("*")))
    except Exception:
        pass
    return {"available": AGENTS_DIR.exists(), "installed": installed,
            "agents": out, "health": health, "ci": ci, "report": report,
            "missions_queued": missions,
            "smoke": _read_json(state_dir / "smoke-scenes.json", {})}


def game() -> dict:
    """État du jeu natif (VNC), via game-stack.sh status — source de vérité
    unique pour les deux modes (container podman / native sysroot). Never raises."""
    info = {"available": False, "image_built": False, "container": "absent",
            "vnc_open": False, "mode": "none"}
    gs = ROOT / "infra" / "oracle" / "game" / "game-stack.sh"
    if not gs.exists():
        info["reason"] = "game-stack.sh absent du repo"
        return info
    out, rc = _sh(["bash", str(gs), "status"], timeout=12)
    if rc != 0:
        info["reason"] = ("pile non provisionnée — lancer "
                          "infra/oracle/game/provision-game-user.sh")
        return info
    try:
        st = json.loads(out.splitlines()[-1])
    except Exception:
        info["reason"] = "status illisible: " + out[:120]
        return info
    info["available"] = True
    info["mode"] = st.get("mode", "?")
    info["container"] = st.get("container", "?")
    info["vnc_open"] = bool(st.get("vnc_open"))
    # Transparence : QUEL PROJET est joué. Le jeu vit dans son propre dossier,
    # séparé de l'outillage (sa branche ne contient pas infra/oracle/game).
    info["game_dir"] = st.get("game_dir", "")
    info["repo_branch"] = st.get("game_branch", "?")
    info["repo_commit"] = st.get("game_commit", "?")
    info["imported"] = bool(st.get("imported"))
    # Outillage (ce dépôt) — utile pour diagnostiquer, jamais confondu avec le jeu.
    info["tools_branch"] = _sh(["git", "rev-parse", "--abbrev-ref", "HEAD"], timeout=5)[0]
    gi = godot_info()
    info["godot_version"] = gi.get("version", "")
    info["version_warning"] = ""
    if info["mode"] == "container":
        info["image_built"] = _sh(["podman", "image", "exists",
                                   "localhost/merlin-game"], timeout=6)[1] == 0
        if not info["image_built"]:
            info["reason"] = ("image non buildée — lancer "
                              "infra/oracle/game/provision-game-user.sh")
    else:
        info["image_built"] = True   # mode native : le sysroot est le gate d'entrée
    return info


# ── Contenu (canon / corpus / loops) ─────────────────────────────────────────
def canon() -> dict:
    c = _read_json(CANON, None)
    if not isinstance(c, dict):
        return {"available": False}
    return {
        "available": True,
        "version": c.get("version", ""),
        "generated": c.get("generated", ""),
        "counts": {k: len(c.get(k, [])) for k in
                   ("factions", "npcs", "biomes", "rune_circuits", "endings", "events", "themes")},
        "divergences": len(c.get("divergences", [])),
        "gaps": len(c.get("gaps", [])),
        "divergence_list": [d.get("topic", "?") for d in c.get("divergences", [])][:12],
        "gap_list": [g if isinstance(g, str) else str(g)[:90] for g in c.get("gaps", [])][:12],
    }


def corpus() -> dict:
    if not CORPUS.exists():
        return {"available": False, "lines": 0}
    lines, backends, last_ids = 0, {}, []
    try:
        with CORPUS.open(encoding="utf-8") as f:
            for ln in f:
                ln = ln.strip()
                if not ln:
                    continue
                lines += 1
                try:
                    o = json.loads(ln)
                    b = o.get("backend", "?")
                    backends[b] = backends.get(b, 0) + 1
                    cid = (o.get("card") or {}).get("card_id")
                    if cid:
                        last_ids.append(cid)
                except Exception:
                    pass
    except Exception:
        pass
    st = CORPUS.stat()
    return {"available": True, "lines": lines, "bytes": st.st_size,
            "mtime": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime(st.st_mtime)),
            "backends": backends, "last_ids": last_ids[-3:],
            # MOS target from the bible (soft-min 8 / target 20-25 / soft-max 40)
            "mos": {"cards": lines, "target": 25, "soft_min": 8, "soft_max": 40}}


def loops() -> dict:
    return _read_json(LOOPS, {})


# ── LLM (Ollama) + voix ──────────────────────────────────────────────────────
def ollama() -> dict:
    ver = _http_json(f"{OLLAMA_URL}/api/version")
    if ver is None:
        return {"available": False, "url": OLLAMA_URL}
    tags = _http_json(f"{OLLAMA_URL}/api/tags") or {}
    ps = _http_json(f"{OLLAMA_URL}/api/ps") or {}
    models = [{"name": m.get("name"), "gb": round((m.get("size") or 0) / 1e9, 2),
               "param": ((m.get("details") or {}).get("parameter_size") or ""),
               "quant": ((m.get("details") or {}).get("quantization_level") or "")}
              for m in (tags.get("models") or [])]
    loaded = [{"name": m.get("name"), "vram_gb": round((m.get("size_vram") or 0) / 1e9, 2)}
              for m in (ps.get("models") or [])]
    biggest = max([m["gb"] for m in models], default=0.0)
    mem = host_mem()
    return {"available": True, "url": OLLAMA_URL, "version": ver.get("version", ""),
            "models": models, "loaded": loaded, "biggest_gb": biggest,
            "fits": (mem.get("available_gb", 0) >= biggest) if biggest else True}


def voice() -> dict:
    return {"tts": _http_json(f"{TTS_URL}/health") or {"ok": False, "url": TTS_URL},
            "asr": _http_json(f"{ASR_URL}/health") or {"ok": False, "url": ASR_URL}}


# ── Repo ─────────────────────────────────────────────────────────────────────
def repo() -> dict:
    branch, _ = _sh(["git", "rev-parse", "--abbrev-ref", "HEAD"])
    porcelain, _ = _sh(["git", "status", "--porcelain"])
    dirty = [l for l in porcelain.splitlines() if l.strip()]
    ahead_behind, rc = _sh(["git", "rev-list", "--left-right", "--count", "@{u}...HEAD"])
    behind = ahead = 0
    if rc == 0 and ahead_behind:
        parts = ahead_behind.split()
        if len(parts) == 2:
            behind, ahead = int(parts[0]), int(parts[1])
    log, _ = _sh(["git", "log", "-12", "--pretty=%h\x1f%s\x1f%cr\x1f%an"])
    commits = []
    for line in log.splitlines():
        p = line.split("\x1f")
        if len(p) == 4:
            commits.append({"hash": p[0], "subject": p[1], "when": p[2], "author": p[3]})
    stat, _ = _sh(["git", "diff", "--stat"])
    return {"branch": branch, "ahead": ahead, "behind": behind,
            "dirty_count": len(dirty), "dirty": dirty[:20],
            "commits": commits, "diffstat": stat.splitlines()[-1] if stat else ""}


# ── Hôte ─────────────────────────────────────────────────────────────────────
def host_mem() -> dict:
    info = {}
    try:
        for line in Path("/proc/meminfo").read_text().splitlines():
            k, _, v = line.partition(":")
            info[k.strip()] = int(v.split()[0])  # kB
    except Exception:
        return {}
    g = lambda k: round(info.get(k, 0) / 1048576, 2)  # kB -> GB
    return {"total_gb": g("MemTotal"), "available_gb": g("MemAvailable"),
            "swap_free_gb": g("SwapFree"),
            "used_pct": round(100 * (1 - (info.get("MemAvailable", 0) / max(info.get("MemTotal", 1), 1))))}


def _port_open(port: int) -> bool:
    try:
        with socket.create_connection(("127.0.0.1", port), timeout=0.25):
            return True
    except Exception:
        return False


def host() -> dict:
    load = ""
    try:
        load = Path("/proc/loadavg").read_text().split()[0:3]
        load = " ".join(load)
    except Exception:
        pass
    df, _ = _sh(["df", "-h", str(ROOT)], timeout=5)
    disk = df.splitlines()[-1].split() if len(df.splitlines()) > 1 else []
    up, _ = _sh(["uptime", "-p"], timeout=5)
    arch, _ = _sh(["uname", "-m"], timeout=5)
    nproc, _ = _sh(["nproc"], timeout=5)
    # one systemctl call for all units
    units = ["ollama", "docker", "merlin-stack", "merlin-runner", "merlin-studio"]
    st, _ = _sh(["systemctl", "is-active"] + units, timeout=6)
    states = [s.strip() for s in st.splitlines()]
    # Outside systemd (container/dev box) systemctl prints a sentence, not a state.
    ok = {"active", "inactive", "failed", "activating", "deactivating", "unknown"}
    services = {u: (states[i] if i < len(states) and states[i] in ok else "n/a")
                for i, u in enumerate(units)}
    dk, dkrc = _sh(["docker", "ps", "--filter", "name=merlin-", "--format", "{{.Names}}\t{{.Status}}"], timeout=6)
    containers = ([{"name": l.split("\t")[0], "status": l.split("\t")[-1]}
                   for l in dk.splitlines() if "\t" in l] if dkrc == 0 else None)
    with ThreadPoolExecutor(max_workers=8) as ex:
        opened = list(ex.map(lambda p: _port_open(p[0]), PORTS))
    ports = [{"port": p, "name": n, "open": o} for (p, n), o in zip(PORTS, opened)]
    prov = {"provision_done": Path("/opt/merlin/PROVISION_DONE").exists(),
            "models_done": ""}
    try:
        prov["models_done"] = Path("/opt/merlin/MODELS_DONE").read_text(encoding="utf-8").strip()[:120]
    except Exception:
        pass
    return {"arch": arch, "cpus": nproc, "load": load, "uptime": up,
            "mem": host_mem(), "services": services, "containers": containers,
            "ports": ports, "provision": prov,
            "disk": ({"size": disk[1], "used": disk[2], "avail": disk[3], "pct": disk[4]}
                     if len(disk) >= 5 else {}),
            "checked_at": _now()}


def overview() -> dict:
    """Cheap summary for the header line."""
    m = host_mem()
    o = ollama()
    return {"cpus": _sh(["nproc"], timeout=4)[0], "mem": m,
            "ollama": o.get("available", False), "models": len(o.get("models", [])),
            "branch": _sh(["git", "rev-parse", "--abbrev-ref", "HEAD"], timeout=5)[0],
            "checked_at": _now()}
