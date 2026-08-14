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
            "rc": st.get("rc"), "duration_s": st.get("duration_s"),
            "summary": st.get("summary", ""),
            # Vue « en direct » : qui travaille maintenant, qui passe ensuite.
            "running": _is_running(aid),
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
    # Deux files, deux sens. « En file » = le codeur va l'appliquer. « À la
    # main » = personne ne le fera à ta place. Les confondre annonçait 30
    # missions en cours là où rien ne bougeait depuis trois jours.
    def _compte(nom: str) -> int:
        try:
            return len(list((Path.home() / ".cache" / "merlin-missions" / nom).glob("*")))
        except Exception:
            return 0
    missions = _compte("queue")
    return {"available": AGENTS_DIR.exists(), "installed": installed,
            "agents": out, "health": health, "ci": ci, "report": report,
            "missions_queued": missions, "notes_a_la_main": _compte("a_la_main"),
            "billing": _read_json(state_dir / "billing-data.json", {}),
            "smoke": _read_json(state_dir / "smoke-scenes.json", {})}


def chapitres(limite: int = 20) -> dict:
    """Les chapitres GRAVÉS du journal — le récit qui survit aux purges.

    `journal()` (ci-dessous) reste la vue « live » des dernières 48 h ; ici on
    lit le registre append-only de `tools/gd_agents/journal.py`, qui garde tout
    et porte la causalité (« ce commit vient de ta décision de mardi »).
    Never raises."""
    try:
        import sys as _s
        _s.path.insert(0, str(ROOT / "tools" / "gd_agents"))
        import journal as J
        chaps = J.chapitres(limite)
        # Le tri, la déduplication et le libellé à jour sont dans `journal.py` —
        # une seule règle pour la page ET pour le chapitre écrit la nuit.
        return {"chapitres": chaps, "fils_ouverts": J.fils_visibles(limite=6),
                "total": len(chaps)}
    except Exception as exc:
        return {"chapitres": [], "fils_ouverts": [], "total": 0,
                "error": str(exc)[:150]}


def journal(hours: int = 48, limit: int = 40) -> list[dict]:
    """Le journal de développement : QUE s'est-il passé, en français, avec preuves.

    Aucune instrumentation nouvelle : on agrège ce que la plateforme trace déjà
    (commits du jeu, verdicts CI avec captures, propositions et leurs décisions,
    sessions de playtest, production de corpus). Chaque événement :
    {t, kind, title, detail, shot} — shot est une URL du portail. Never raises."""
    state = Path.home() / ".cache" / "merlin-agents"
    now = time.time()
    floor = now - hours * 3600
    ev: list[dict] = []

    def _ts(s: str) -> float:
        # Ces horodatages sont écrits en UTC (suffixe Z) ; `mktime` les lisait
        # comme du local, ce qui décalait tous les « il y a N h » d'un fuseau.
        try:
            t = time.strptime(str(s)[:19], "%Y-%m-%dT%H:%M:%S")
        except Exception:
            return 0.0
        import calendar
        return calendar.timegm(t) if str(s).rstrip().endswith("Z") else time.mktime(t)

    # Qui parle dans le journal : des noms français, jamais des identifiants.
    WHO = {"gd-content-gap": "l'écrivain de cartes", "gd-balance": "l'équilibreur",
           "coder-local": "le codeur", "playtest-bot": "le robot testeur",
           "billing": "le comptable", "corpus-night": "l'atelier d'écriture",
           "ci": "le vérificateur"}

    def _fr_subject(s: str) -> str:
        """Décape le jargon des messages de commit (feat(x): … → la phrase)."""
        import re as _re
        s = _re.sub(r"^\w+(\([\w./-]+\))?\s*:\s*", "", s.strip())
        return (s[:1].upper() + s[1:])[:130] if s else ""

    # Commits réels sur la branche du jeu — le développement vécu.
    game = Path.home() / "workspace" / "merlin-game"
    if (game / ".git").exists():
        out, rc = _sh(["git", "-C", str(game), "log", f"--since={hours} hours ago",
                       "--format=%ct|%h|%s", "--all"], timeout=10)
        if rc == 0:
            for line in out.splitlines()[:15]:
                try:
                    ts, sha, subj = line.split("|", 2)
                    ev.append({"t": float(ts), "kind": "commit",
                               "title": "Le jeu a été mis à jour",
                               "detail": _fr_subject(subj), "shot": ""})
                except ValueError:
                    continue

    # Verdicts CI — avec la capture du jeu rendu.
    try:
        for line in (state / "ci" / "history.jsonl").read_text(encoding="utf-8").splitlines():
            c = json.loads(line)
            t = _ts(c.get("t", ""))
            if t < floor:
                continue
            ok = c.get("scenes_failing") == 0 and c.get("boot_ok")
            ev.append({"t": t, "kind": "ci",
                       "title": "Le jeu a été testé : tout fonctionne ✓" if ok
                       else "Le test du jeu a échoué ✗",
                       "detail": _fr_subject(c.get("subject", "") or "")
                       + (f" — Diagnostic : {c.get('diag', '')[:110]}" if c.get("diag") else ""),
                       "shot": f"/api/ci/shot/{c['sha']}" if c.get("shot") else ""})
    except Exception:
        pass

    # Propositions : naissances et décisions (y compris auto-intégrations).
    #
    # « Tu as rejeté une proposition », vingt-cinq fois d'affilée : aucune de ces
    # lignes ne venait de Maxime. C'était le ménage automatique de la veille, et
    # le libellé était déduit du NOM DU DOSSIER — un fichier dans `rejected/`
    # produisait mécaniquement « Tu as ». On lit maintenant qui a décidé, et les
    # gestes automatiques d'un même jour tiennent en UNE ligne.
    base = Path.home() / ".cache" / "merlin-proposals"
    autos: dict[tuple, dict] = {}
    # `accepted/` et `rejected/` ne sont jamais purgés : sans borne, le mur
    # repousse tout seul dès que la chaîne tourne quelques nuits. On lit les plus
    # récents par date de fichier, la fenêtre de 48 h fait le reste.
    for sub, label in (("inbox", "💡 Une décision t'attend"),
                       ("accepted", "Tu as accepté une proposition"),
                       ("rejected", "Tu as écarté une proposition")):
        try:
            fichiers = sorted((base / sub).glob("*.json"),
                              key=lambda x: -x.stat().st_mtime)[:80]
            for f in fichiers:
                p = json.loads(f.read_text(encoding="utf-8"))
                t = _ts(p.get("decided_at") or p.get("created", ""))
                if t < floor:
                    continue
                who = WHO.get(str(p.get("agent", "")), p.get("agent", "un agent"))
                raison = str(p.get("decision_reason", ""))
                # Un geste AUTOMATIQUE se reconnaît à sa source ou à sa raison ;
                # `auto` était déjà calculé ici, et n'était utilisé que pour les
                # acceptations — les rejets automatiques passaient pour les tiens.
                auto = (str(p.get("source", "")) == "menage"
                        or raison.lstrip().startswith("auto")
                        or "automatiquement" in raison)
                if auto and sub != "inbox":
                    cle = (sub, time.strftime("%Y-%m-%d", time.localtime(t)))
                    g = autos.setdefault(cle, {"t": t, "n": 0, "motif": raison[:110]})
                    g["n"] += 1
                    g["t"] = max(g["t"], t)   # la ligne porte le DERNIER geste
                    continue
                # Le SUJET dans le titre, l'auteur dans le détail. Seize lignes
                # « Tu as accepté une proposition » sont illisibles : le libellé
                # ne disait pas de QUOI il s'agissait, et la seule information
                # utile était reléguée en seconde ligne.
                sujet = str(p.get("title", "")).strip()
                ev.append({"t": t, "kind": "proposal", "auto": False,
                           "title": f"{label.split(' une ')[0]} : {sujet[:90]}"
                                    if sujet else label,
                           "detail": f"proposé par {who}"
                                     + (f" · {raison}" if raison else ""),
                           "shot": ""})
        except Exception:
            continue
    for (sub, _jour), g in autos.items():
        quoi = ("intégrée sans toi" if sub == "accepted" else "écartée sans toi")
        ev.append({
            "t": g["t"], "kind": "auto", "auto": True,
            "title": (f"{g['n']} proposition {quoi}" if g["n"] == 1
                      else f"{g['n']} propositions {quoi.replace('ée', 'ées')}"),
            "detail": g["motif"] or "geste automatique de la chaîne, pas une décision",
            "shot": ""})

    # Sessions de playtest — le bot a joué ; on joint la dernière capture.
    try:
        shots = sorted((state / "playtest").glob("*.png"))
        sessions: dict[str, list[Path]] = {}
        for s in shots:
            sessions.setdefault(s.name.rsplit("-", 1)[0], []).append(s)
        for tag, files in sessions.items():
            t = files[-1].stat().st_mtime
            if t < floor:
                continue
            ev.append({"t": t, "kind": "playtest",
                       "title": "Le robot testeur a joué au jeu",
                       "detail": f"{len(files)} écrans parcourus, clics et touches "
                                 f"comme un vrai joueur — voici son dernier écran :",
                       "shot": f"/api/playtest/shot/{files[-1].name}"})
    except Exception:
        pass

    # Usine à corpus — dernier passage + cumul.
    loops = _read_json(ROOT / "tools" / "autodev" / "status" / "cockpit_loops.json", {})
    g = loops.get("gen", {})
    t = _ts(g.get("last", ""))
    if t >= floor and g.get("accepted") is not None:
        rej = g.get("rejected", 0)
        ev.append({"t": t, "kind": "corpus",
                   "title": f"L'atelier d'écriture a produit {g.get('accepted', 0)} "
                            f"nouvelle(s) carte(s) de jeu",
                   "detail": (f"{rej} refusée(s) par le contrôle qualité · " if rej else "")
                             + f"le recueil compte {g.get('corpus_total', '?')} cartes"
                             + (f" · passage sauté : {g['skipped']}" if g.get("skipped") else ""),
                   "shot": ""})

    ev.sort(key=lambda e: -e["t"])
    # Le nettoyage du jargon existe depuis le registre et n'a jamais été appliqué
    # ici : c'est de là que venaient les « (JSON illisible) » et les « rc=0 »
    # bruts à l'écran. On réutilise la MÊME table, on n'en écrit pas une seconde.
    try:
        import sys as _s
        _s.path.insert(0, str(ROOT / "tools" / "gd_agents"))
        from journal import _francais as _fr
    except Exception:
        def _fr(x):
            return x
    for e in ev:
        e["ago_min"] = max(0, int((now - e["t"]) // 60))
        e["title"] = _fr(e.get("title", ""))
        e["detail"] = _fr(e.get("detail", ""))
    return ev[:limit]


# ── « Ce matin » : les 4 lignes à lire avant tout le reste ───────────────────

def _proposals_mod():
    import sys as _s
    _s.path.insert(0, str(ROOT / "tools" / "gd_agents"))
    import proposals as P
    return P


def briefing() -> dict:
    """Ce qu'il faut savoir en 5 secondes, en français, sans jargon.

    Rien de nouveau n'est instrumenté : on agrège ce que la plateforme trace
    déjà (états d'agents, propositions et leur parcours, corpus, jeu). Chaque
    ligne répond à UNE question : qu'a-t-on fait cette nuit, qu'attend-on de
    moi, qu'est-ce qui coince, où en est le jeu. Never raises."""
    now = time.time()
    out = {"nuit": [], "attente": [], "bloque": [], "jeu": []}

    # 1. Cette nuit — ce que la chaîne a réellement produit.
    try:
        P = _proposals_mod()
        recent, merges = [], 0
        for p in P.ACCEPTED.glob("*.json"):
            if p.stat().st_mtime < now - 24 * 3600:
                continue
            d = _read_json(p, {})
            if d.get("kind") == "merge":
                merges += 1
            elif d.get("step") in ("poussée", "fusionnée"):
                recent.append(d)
        if recent:
            out["nuit"].append(f"{len(recent)} correction(s) appliquée(s) et vérifiée(s) "
                               f"sur la branche de nuit")
        if merges:
            out["nuit"].append(f"{merges} intégration(s) dans le jeu")
    except Exception:
        pass
    try:
        # L'atelier d'écriture résume son passage en JSON brut. Le recopier tel
        # quel affichait « {"loop": "gen", "accepted": … } » en plein milieu du
        # briefing : exactement le jargon que cet écran est censé remplacer.
        g = _read_json(Path.home() / ".cache" / "merlin-agents" / "state" / "corpus-night.json", {})
        brut = str(g.get("summary") or "")
        if brut.lstrip().startswith("{"):
            try:
                o = json.loads(brut)
                acc, rej = o.get("accepted"), o.get("rejected")
                if acc is not None:
                    phrase = f"{acc} carte(s) écrite(s)" + (f", {rej} refusée(s)" if rej else "")
                elif o.get("skipped"):
                    phrase = f"passage sauté ({o['skipped']})"
                else:
                    phrase = ""
            except Exception:
                phrase = ""
        else:
            phrase = brut[:90]
        if phrase:
            out["nuit"].append(f"atelier d'écriture : {phrase}")
    except Exception:
        pass
    if not out["nuit"]:
        out["nuit"].append("rien de neuf — la chaîne n'a rien eu à appliquer")

    # 2. En attente de toi — les décisions, séparées par nature.
    try:
        P = _proposals_mod()
        pend = [d for d in (_read_json(p, {}) for p in P.INBOX.glob("*.json")) if d]
        fusions = sum(1 for d in pend if d.get("kind") == "merge")
        auto = sum(1 for d in pend if P.applicable(d))
        if fusions:
            out["attente"].append(f"{fusions} intégration(s) à valider — 1 tap et c'est dans le jeu")
        if auto - fusions > 0:
            out["attente"].append(f"{auto - fusions} correction(s) prête(s) à être appliquée(s)")
        reste = len(pend) - auto
        if reste > 0:
            out["attente"].append(f"{reste} idée(s) qui demandent ton arbitrage")
        if not pend:
            out["attente"].append("rien à décider — les agents n'ont rien trouvé de neuf")
        # Les notes à faire à la main sont une attente RÉELLE mais d'une autre
        # nature : aucun agent ne les fera à ta place. Elles vivaient dans la
        # file du codeur, qui les écartait en silence à chaque passage.
        notes = len(list(P.A_LA_MAIN.glob("*"))) if P.A_LA_MAIN.exists() else 0
        if notes:
            out["attente"].append(
                f"{notes} note(s) qui demandent ta main — aucun agent ne sait les faire")
    except Exception:
        pass

    # 3. Bloqué — et POURQUOI, en clair. C'est la ligne qui manquait le plus.
    try:
        for a in agents().get("agents", []):
            if not a.get("enabled"):
                continue
            why = str(a.get("summary") or "")
            if a.get("ok") is False:
                out["bloque"].append(f"{a['label']} : {why[:110] or 'échec sans message'}")
            elif any(k in why for k in ("suspendu", "rien d'applicable", "indisponible",
                                        "absent", "sauté", "vide")):
                out["bloque"].append(f"{a['label']} : {why[:110]}")
    except Exception:
        pass
    out["bloque"] = out["bloque"][:4]
    if not out["bloque"]:
        out["bloque"].append("rien de bloqué")

    # 4. Le jeu — les chiffres qui bougent.
    try:
        c = corpus()
        out["jeu"].append(f"{c.get('lines', 0)} cartes au recueil")
    except Exception:
        pass
    try:
        sm = _read_json(Path.home() / ".cache" / "merlin-agents" / "smoke-scenes.json", {})
        if sm:
            ko = sm.get("failed") or sm.get("ko") or 0
            out["jeu"].append("toutes les scènes démarrent" if not ko
                              else f"{ko} scène(s) en erreur au démarrage")
    except Exception:
        pass
    try:
        g = Path.home() / "workspace" / "merlin-game"
        if (g / ".git").exists():
            # `%cr` rend « 12 days ago » : git parle la langue du système, et la
            # VM est en anglais. On prend l'horodatage brut et on l'écrit nous-mêmes.
            o, rc = _sh(["git", "-C", str(g), "log", "-1", "--format=%ct|%s"], timeout=8)
            if rc == 0 and "|" in o:
                brut, sujet = o.split("|", 1)
                out["jeu"].append(f"dernier changement {_il_y_a(brut)} : {sujet.strip()[:60]}")
    except Exception:
        pass
    return out


def _il_y_a(ts) -> str:
    """« il y a 3 jours » — jamais « 3 days ago »."""
    try:
        d = max(0, int(time.time() - float(ts)))
    except Exception:
        return "récemment"
    if d < 3600:
        return f"il y a {max(1, d // 60)} min"
    if d < 86400:
        return f"il y a {d // 3600} h"
    if d < 2592000:
        n = d // 86400
        return f"il y a {n} jour" + ("s" if n > 1 else "")
    n = d // 2592000
    return f"il y a {n} mois"


PROGRESS = Path.home() / "merlin-memory" / "progress.jsonl"


def progress(days: int = 30) -> list[dict]:
    """Relevé quotidien d'avancement — écrit par le rapport du matin, lu ici.

    Hors dépôt (`~/merlin-memory/`, jamais purgé par le garde-disque) et
    append-only : la courbe ne peut pas être réécrite. Never raises."""
    out = []
    try:
        for line in PROGRESS.read_text(encoding="utf-8").splitlines()[-days:]:
            if line.strip():
                out.append(json.loads(line))
    except Exception:
        pass
    return out


def agent_log(agent_id: str, lines: int = 120) -> dict:
    """La sortie complète d'un agent — la seule façon de comprendre un échec
    sans se connecter en SSH. `agent-run.sh` écrit déjà ce fichier ; il n'était
    simplement exposé nulle part."""
    import re as _re
    if not _re.fullmatch(r"[a-z0-9][a-z0-9_-]{0,40}", str(agent_id)):
        return {"error": "identifiant invalide"}
    path = Path.home() / ".cache" / "merlin-agents" / "logs" / f"{agent_id}.log"
    if not path.exists():
        return {"id": agent_id, "text": "", "missing": True,
                "note": "aucun journal — cet agent n'a jamais tourné sur cette machine"}
    try:
        txt = path.read_text(encoding="utf-8", errors="replace").splitlines()
        return {"id": agent_id, "text": "\n".join(txt[-lines:]),
                "lines": len(txt),
                "mtime": time.strftime("%Y-%m-%dT%H:%M:%SZ",
                                       time.gmtime(path.stat().st_mtime))}
    except Exception as exc:
        return {"id": agent_id, "error": str(exc)[:150]}


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
