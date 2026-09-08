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
GODOT = os.environ.get("GODOT_BIN", "godot")

# Ports worth probing on the VM (name shown next to each in the Hôte pane).
PORTS = [(8790, "studio"), (5900, "vnc-game")]

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


def _is_running(agent_id: str) -> bool:
    """Un agent tourne-t-il MAINTENANT ? agent-run.sh tient un flock par id :
    si on ne peut pas le prendre, c'est qu'il travaille."""
    lock = Path.home() / ".cache" / "merlin-agents" / f"{agent_id}.lock"
    if not lock.exists():
        return False
    try:
        import fcntl
        with lock.open("r") as f:
            try:
                fcntl.flock(f.fileno(), fcntl.LOCK_EX | fcntl.LOCK_NB)
                fcntl.flock(f.fileno(), fcntl.LOCK_UN)
                return False          # libre → l'agent ne tourne pas
            except OSError:
                return True           # pris → il travaille
    except Exception:
        return False


def _course(agent_id: str) -> dict:
    """Où en est l'agent PENDANT qu'il travaille : étape, libellé, temps écoulé.

    `state/<id>.json` n'est écrit qu'à la FIN d'un passage — pendant l'exécution il porte
    encore le passage PRÉCÉDENT, ce qui rendait tout agent en cours illisible. C'est
    `state/<id>.run.json`, posé par agent-run.sh et enrichi par la fonction `etape`, qui
    décrit la course en cours ; son absence signifie qu'aucune course n'est en cours.

    `silence_s` est EXPOSÉ SANS ÊTRE INTERPRÉTÉ : un long silence peut être un agent planté
    comme un appel bloquant parfaitement légitime (la mesure du moteur dure 12 minutes sans
    rien pouvoir annoncer). Trancher ici fabriquerait de fausses alertes ; c'est le rôle de
    l'agent de contrôle, qui connaît la durée habituelle de chacun.
    """
    d = _read_json(Path.home() / ".cache" / "merlin-agents" / "state" / f"{agent_id}.run.json", None)
    if not isinstance(d, dict) or not d:
        return {}
    maintenant = int(time.time())
    return {
        "etape": int(d.get("etape", 0)),
        "etapes_total": int(d.get("etapes_total", 0)),
        "libelle": str(d.get("libelle", "")),
        "depuis_s": max(0, maintenant - int(d.get("debut", maintenant))),
        "silence_s": max(0, maintenant - int(d.get("maj", maintenant))),
    }


def _next_run(schedule: str, now: float | None = None) -> str:
    """Prochain passage, en français. Balaie les minutes à venir (cron simple :
    minute + heure, les autres champs valant *)."""
    sched = (schedule or "").strip()
    if not sched or sched.startswith(("webhook", "à la")):
        return "sur demande"
    parts = sched.split()
    if len(parts) < 2:
        return sched

    def _match(field: str, value: int) -> bool:
        for tok in field.split(","):
            if tok == "*":
                return True
            if tok.startswith("*/"):
                try:
                    if value % int(tok[2:]) == 0:
                        return True
                except ValueError:
                    pass
            elif "-" in tok:
                try:
                    lo, hi = (int(x) for x in tok.split("-", 1))
                    if lo <= value <= hi:
                        return True
                except ValueError:
                    pass
            elif tok.isdigit() and int(tok) == value:
                return True
        return False

    base = time.localtime(now or time.time())
    start = time.mktime(base) // 60 * 60 + 60      # minute suivante
    for step in range(0, 60 * 24 * 7):             # jusqu'à 7 jours
        t = time.localtime(start + step * 60)
        if _match(parts[0], t.tm_min) and _match(parts[1], t.tm_hour):
            mins = step
            if mins < 1:
                return "dans moins d'une minute"
            if mins < 60:
                return f"dans {mins} min"
            if mins < 60 * 24:
                h, m = divmod(mins, 60)
                return f"dans {h} h" + (f" {m}" if m else "")
            return f"dans {mins // (60 * 24)} j"
    return sched


def agents() -> dict:
    """Agents planifiés sur la VM + leur dernier passage. Never raises."""
    # État RÉEL = manifeste + réglages faits depuis le portail (hors dépôt).
    try:
        import sys as _s
        _s.path.insert(0, str(AGENTS_DIR))
        from overrides import agents as _ag
        defs = _ag()
    except Exception:
        manifest = _read_json(AGENTS_DIR / "agents.json", {})
        defs = manifest.get("agents", []) if isinstance(manifest, dict) else []
    state_dir = Path.home() / ".cache" / "merlin-agents"
    out = []
    for a in defs:
        # état dans state/<id>.json ; repli sur l'ancien emplacement (racine)
        st = _read_json(state_dir / "state" / f"{a.get('id')}.json", None) \
            or _read_json(state_dir / f"{a.get('id')}.json", {})
        aid = a.get("id")
        last = st.get("last_run", "")
        ago = None
        if last:
            try:
                ago = max(0, int((time.time()
                                  - time.mktime(time.strptime(last[:19], "%Y-%m-%dT%H:%M:%S"))
                                  - time.timezone) // 60))
            except Exception:
                ago = None
        out.append({
            "id": aid, "label": a.get("label", aid),
            "desc": a.get("desc", ""), "schedule": a.get("schedule", ""),
            "enabled": bool(a.get("enabled")),
            "last_run": last, "ago_min": ago, "ok": st.get("ok"),
            # rc=75 : l'agent a renoncé en le disant (occupé, mémoire, harnais). Ni vert ni rouge.
            "reporte": bool(st.get("reporte")) or st.get("rc") == 75,
            "rc": st.get("rc"), "duration_s": st.get("duration_s"),
            "summary": st.get("summary", ""),
            # Vue « en direct » : qui travaille maintenant, où il en est, qui passe ensuite.
            "running": _is_running(aid),
            "course": _course(aid),
            "next_run": _next_run(a.get("schedule", "")) if a.get("enabled") else "en pause",
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
    return {"available": AGENTS_DIR.exists(), "installed": installed,
            "agents": out, "health": health,
            "billing": _read_json(state_dir / "billing-data.json", {})}


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
    units = ["merlin-studio"]
    st, _ = _sh(["systemctl", "is-active"] + units, timeout=6)
    states = [s.strip() for s in st.splitlines()]
    # Outside systemd (container/dev box) systemctl prints a sentence, not a state.
    ok = {"active", "inactive", "failed", "activating", "deactivating", "unknown"}
    services = {u: (states[i] if i < len(states) and states[i] in ok else "n/a")
                for i, u in enumerate(units)}
    containers = None
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
    return {"cpus": _sh(["nproc"], timeout=4)[0], "mem": m,
            "branch": _sh(["git", "rev-parse", "--abbrev-ref", "HEAD"], timeout=5)[0],
            "checked_at": _now()}
