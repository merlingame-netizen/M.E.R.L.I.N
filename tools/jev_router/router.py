"""Routeur de taches : decide la lane (small/medium/high/escalate) et le modele par outil.

Ordre : checks deterministes (0 token) -> decideur System One -> garde-fous
codes en dur (seuils, retries, escalades). Le decideur juge, ce code tranche.

Decideur : Qwen local (Ollama) par defaut. Jev (API TypeSafe) seulement si le dossier du
projet est dans decider_policy.remote_allowed_paths ET que TYPESAFE_API_KEY est presente ET
que la demande n'est pas classee "security" par la regex. Echec de l'API -> repli sur Qwen.
Chaque decision est journalisee dans ~/.jev_router/decisions.jsonl.
"""

from __future__ import annotations

import json
import os
import re
import time
from pathlib import Path, PurePath
from typing import Callable

from systemone import Backend, DecisionError, OllamaBackend, decide
from typesafe_backend import API_KEY_ENV, TypeSafeClient

HERE = Path(__file__).resolve().parent
CONFIG_PATH = Path(os.environ.get("JEV_ROUTER_CONFIG", HERE / "lanes.json"))
STATE_DIR = Path(os.environ.get("JEV_ROUTER_HOME", Path.home() / ".jev_router"))
LANES = ["small", "medium", "high", "escalate"]

_RISK_PATTERNS = {
    "security": re.compile(
        r"\b(auth\w*|password|mot de passe|secret|token|credential|api[ _-]?key|cl[eé] api|"
        r"permission|chiffr\w*|crypt\w*|injection|xss|csrf|oauth|jwt|ssh)\b",
        re.IGNORECASE,
    ),
    "data_loss": re.compile(
        r"(rm -rf|drop (table|database)|truncate|reset --hard|push --force|force[- ]push|"
        r"\bdelete\b|\bsupprim\w*|\bmigration\b|\bpurge\b|\bwipe\b|\bformat\w* (le )?disque)",
        re.IGNORECASE,
    ),
}

COMPLEXITY_QUESTION = {
    "id": "complexity",
    "type": "choice",
    "text": "Quel niveau de raisonnement cette demande de developpement logiciel exige-t-elle ?",
    "options": [
        {"value": "small", "description": "question simple ou commande a donner, renommage, faute de frappe, petite correction localisee (1 fichier, <30 lignes)"},
        {"value": "medium", "description": "feature ou bugfix sur 1-3 fichiers, logique claire, tests simples"},
        {"value": "high", "description": "multi-fichiers, logique subtile, debug non evident, refactor, perf"},
        {"value": "escalate", "description": "architecture multi-systeme, decision irreversible, conception de zero"},
    ],
}

RISK_QUESTION = {
    "id": "risk_flag",
    "type": "choice",
    "text": "La demande touche-t-elle un code sensible ?",
    "options": [
        {"value": "none", "description": "cas normal : feature, bugfix, refactor, perf, question — meme si du code est modifie"},
        {"value": "security", "description": "la demande porte explicitement sur authentification, secrets, permissions, crypto ou entrees non fiables"},
        {"value": "data_loss", "description": "la demande consiste explicitement a supprimer, migrer ou ecraser des donnees ou l'historique git"},
    ],
}


def load_config(path: Path = CONFIG_PATH) -> dict:
    return json.loads(Path(path).read_text(encoding="utf-8"))


def make_backend(cfg: dict) -> Backend:
    d = cfg["decider"]
    return OllamaBackend(d["ollama_url"], d["model"], d.get("vote_samples", 5), d.get("timeout_s", 20))


def remote_allowed(cfg: dict, cwd: str | None, risk: str) -> tuple[bool, str]:
    """Jev autorise pour ce projet ? Projet inconnu ou hors liste blanche -> non."""
    policy = cfg.get("decider_policy") or {}
    allowed = {a.casefold() for a in policy.get("remote_allowed_paths", [])}
    if not allowed or not cwd:
        return False, "projet inconnu -> decideur local"
    if not {part.casefold() for part in PurePath(cwd).parts} & allowed:
        return False, "projet hors liste blanche -> decideur local"
    if risk in policy.get("remote_blocked_risks", ["security"]):
        return False, f"risque {risk} -> jamais envoye a l'API"
    if not os.environ.get(API_KEY_ENV):
        return False, f"{API_KEY_ENV} absente -> decideur local"
    return True, "projet en liste blanche -> Jev"


def _deciders(cfg: dict, cwd: str | None, risk: str,
              reasons: list[str]) -> list[Callable[[dict], dict]]:
    """Chaine de decideurs a essayer dans l'ordre (le dernier est toujours Qwen local)."""
    local = make_backend(cfg)
    chain: list[Callable[[dict], dict]] = []
    ok, why = remote_allowed(cfg, cwd, risk)
    if ok:
        chain.append(TypeSafeClient.from_policy(cfg["decider_policy"]).decide)
    elif cwd:
        reasons.append(why)
    chain.append(lambda req: decide(req, local))
    return chain


def _run_chain(request: dict, chain: list[Callable[[dict], dict]], reasons: list[str]) -> dict:
    for i, decider in enumerate(chain):
        try:
            return decider(request)
        except DecisionError as exc:
            if i == len(chain) - 1:
                raise
            reasons.append(f"Jev indisponible ({exc}) -> repli Qwen")
    raise DecisionError("aucun decideur configure")


def deterministic_risk(prompt: str) -> str:
    for flag, pattern in _RISK_PATTERNS.items():
        if pattern.search(prompt):
            return flag
    return "none"


def _bump(lane: str, steps: int = 1) -> str:
    return LANES[min(LANES.index(lane) + steps, len(LANES) - 1)]


def _heuristic_lane(prompt: str) -> str:
    n = len(prompt)
    return "small" if n < 300 else "medium" if n < 2000 else "high"


# ── Budget (retries / escalades par tache) ─────────────────────────────────


def _state_path() -> Path:
    return STATE_DIR / "state.json"


def _load_state() -> dict:
    try:
        return json.loads(_state_path().read_text(encoding="utf-8"))
    except (OSError, ValueError):
        return {}


def _save_state(state: dict) -> None:
    STATE_DIR.mkdir(parents=True, exist_ok=True)
    _state_path().write_text(json.dumps(state, indent=1), encoding="utf-8")


def _log(entry: dict) -> None:
    try:
        STATE_DIR.mkdir(parents=True, exist_ok=True)
        with (STATE_DIR / "decisions.jsonl").open("a", encoding="utf-8") as fh:
            fh.write(json.dumps(entry, ensure_ascii=False) + "\n")
    except OSError:
        pass


def record_failure(task_id: str, cfg: dict | None = None) -> dict:
    """Signale un cycle echoue (tests rouges...). Monte de lane apres max_retries."""
    cfg = cfg or load_config()
    gates = cfg["gates"]
    state = _load_state()
    task = state.get(task_id)
    if task is None:
        return {"task_id": task_id, "error": "tache inconnue : appeler route() d'abord"}
    task["retries"] += 1
    action = "retry"
    if task["retries"] >= gates["max_retries_per_lane"]:
        nxt = _bump(task["lane"])
        if nxt == "escalate" and task["escalations"] >= gates["max_escalations_per_task"]:
            action = "stop"  # kill switch : budget d'escalade epuise
        elif nxt == task["lane"]:
            action = "stop"
        else:
            if nxt == "escalate":
                task["escalations"] += 1
            task["lane"], task["retries"], action = nxt, 0, "escalate"
    state[task_id] = task
    _save_state(state)
    result = {"task_id": task_id, "action": action, **task, "models": cfg["lanes"][task["lane"]]}
    _log({"ts": time.time(), "event": "failure", **result})
    return result


# ── Routage ────────────────────────────────────────────────────────────────


def route(prompt: str, task_id: str | None = None, cfg: dict | None = None,
          backend: Backend | None = None, cwd: str | None = None) -> dict:
    cfg = cfg or load_config()
    gates = cfg["gates"]
    reasons: list[str] = []
    risk = deterministic_risk(prompt)
    if risk != "none":
        reasons.append(f"regex:{risk}")

    confidence: float | None = None
    calibrated = False
    request = {"context": prompt, "questions": [COMPLEXITY_QUESTION, RISK_QUESTION]}
    try:
        if backend is not None:
            result = decide(request, backend)
        else:
            result = _run_chain(request, _deciders(cfg, cwd, risk, reasons), reasons)
        by_id = {a["id"]: a for a in result["answers"]}
        lane = by_id["complexity"]["value"]
        confidence = by_id["complexity"]["confidence"]
        calibrated = by_id["complexity"]["calibrated"]
        if risk == "none" and by_id["risk_flag"]["value"] != "none" \
                and by_id["risk_flag"]["confidence"] >= gates["escalate_below"]:
            risk = by_id["risk_flag"]["value"]
            reasons.append(f"decider:{risk}")
        source = result["model"]
        if confidence < gates["escalate_below"]:
            lane = _bump(lane)
            reasons.append(f"confiance {confidence:.2f} < {gates['escalate_below']} -> +1 lane")
    except DecisionError as exc:
        lane, source = _heuristic_lane(prompt), "heuristic"
        reasons.append(f"decideur indisponible : {exc}")

    if risk != "none" and LANES.index(lane) < LANES.index("high"):
        lane = "high"
        reasons.append("code sensible -> lane high minimum")

    out = {
        "lane": lane,
        "models": cfg["lanes"][lane],
        "confidence": confidence,
        "calibrated": calibrated,
        "risk_flag": risk,
        "source": source,
        "reasons": reasons,
    }
    if task_id:
        state = _load_state()
        state[task_id] = {"lane": lane, "retries": 0, "escalations": int(lane == "escalate")}
        _save_state(state)
        out["task_id"] = task_id
    _log({"ts": time.time(), "event": "route", "prompt_chars": len(prompt), **out})
    return out


def stats() -> dict:
    """Resume du journal : repartition des lanes, escalades, fallbacks."""
    counts: dict[str, int] = {}
    failures = fallbacks = remote = total = 0
    path = STATE_DIR / "decisions.jsonl"
    if path.exists():
        for line in path.read_text(encoding="utf-8").splitlines():
            try:
                e = json.loads(line)
            except ValueError:
                continue
            if e.get("event") == "route":
                total += 1
                counts[e["lane"]] = counts.get(e["lane"], 0) + 1
                fallbacks += e.get("source") == "heuristic"
                remote += str(e.get("source", "")).startswith("typesafe:")
            elif e.get("event") == "failure":
                failures += 1
    return {"routes": total, "lanes": counts, "failures": failures, "heuristic_fallbacks": fallbacks,
            "typesafe_routes": remote}


def describe(result: dict) -> str:
    """Resume une ligne, injecte dans le contexte des assistants."""
    conf = "n/a" if result["confidence"] is None else f"{result['confidence']:.2f}"
    m = result["models"]
    return (f"[JEV-ROUTER] lane={result['lane']} confiance={conf} risque={result['risk_flag']} "
            f"| Claude Code: sous-agent model={m.get('claude_code')} | Copilot: {m.get('copilot')} "
            f"| ChatGPT: {m.get('chatgpt')}"
            + (f" | local: {m['ollama']}" if m.get("ollama") else ""))
