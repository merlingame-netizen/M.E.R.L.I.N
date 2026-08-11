#!/usr/bin/env python3
"""Actions du chat de contrôle — la télécommande du studio, en langage naturel.

Le conseiller peut PROPOSER des actions concrètes en fin de réponse (une par
ligne, format `ACTION: verbe | cible | valeur | libellé`). Elles sont validées
contre une LISTE BLANCHE stricte, attachées au message, et rendues sous forme
de boutons dans Parler. Un tap de Maxime les exécute — rien ne part sans lui,
exactement comme AskUserQuestion, mais piloté par la conversation.

Sécurité : le front n'envoie qu'un identifiant d'action ; le backend relit
l'action depuis le message stocké et la re-valide. Impossible d'en forger une.
"""
from __future__ import annotations

import hashlib
import json
import re
import subprocess
import sys
import time
from pathlib import Path

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
import memory  # noqa: E402

AGENTS_JSON = HERE.parents[1] / "infra" / "oracle" / "agents" / "agents.json"
INSTALL = HERE.parents[1] / "infra" / "oracle" / "agents" / "install-agents.sh"
AGENT_RUN = HERE.parents[1] / "infra" / "oracle" / "agents" / "agent-run.sh"
MISSIONS = Path.home() / ".cache" / "merlin-missions" / "queue"

# Cadences proposables (jamais de cron brut tapé par le LLM — que des presets sûrs).
CADENCES = {
    "horaire": ("10 * * * *", "une fois par heure"),
    "nuit":    ("20 2 * * *", "une fois par nuit"),
    "actif":   ("*/30 * * * *", "toutes les 30 min"),
    "matin":   ("40 6 * * *", "chaque matin"),
}
VERBS = ("agent.toggle", "agent.cadence", "agent.run", "mission.queue", "memory.grave")


def _agents() -> list[dict]:
    try:
        return json.loads(AGENTS_JSON.read_text(encoding="utf-8")).get("agents", [])
    except Exception:
        return []


def agent_ids() -> dict:
    """id → label français, pour informer le LLM et valider les cibles."""
    return {a["id"]: a.get("label", a["id"]) for a in _agents()}


def catalogue_for_prompt() -> str:
    """Ce que le LLM a le droit de proposer — court et en français simple.

    Un e4b se bloque (réponse vide) sur un long catalogue plein de symboles :
    on reste bref, une seule ligne d'exemple, les ids listés à part."""
    ids = ", ".join(agent_ids())
    return (
        "Si Maxime veut régler un agent, confier une tâche au codeur ou noter une "
        "décision, ajoute à la fin de ta réponse une ligne commençant par ACTION: "
        "puis quatre champs séparés par des barres verticales. Exemple :\n"
        "ACTION: agent.cadence | playtest-bot | nuit | Playtest une fois par nuit\n"
        "Actions possibles : agent.toggle (valeur on ou off), agent.cadence "
        "(valeur horaire, nuit, actif ou matin), agent.run (valeur -), "
        "mission.queue (cible -, valeur = la tâche), memory.grave (cible -, "
        "valeur = la règle).\n"
        f"Identifiants d'agents valides : {ids}.")


def _aid(verb: str, target: str, value: str) -> str:
    return hashlib.sha1(f"{verb}|{target}|{value}".encode()).hexdigest()[:10]


def parse(reply: str) -> tuple[str, list[dict]]:
    """Extrait les lignes ACTION du texte. Rend (texte nettoyé, actions valides)."""
    ids = agent_ids()
    actions, keep = [], []
    for line in reply.splitlines():
        m = re.match(r"\s*ACTION:\s*(.+)", line)
        if not m:
            keep.append(line)
            continue
        parts = [p.strip() for p in m.group(1).split("|")]
        if len(parts) < 3:
            continue
        verb, target, value = parts[0], parts[1], parts[2]
        label = parts[3] if len(parts) > 3 else verb
        if verb not in VERBS:
            continue
        # Validation stricte selon le verbe.
        if verb in ("agent.toggle", "agent.cadence", "agent.run"):
            if target not in ids:
                continue
            if verb == "agent.toggle" and value not in ("on", "off"):
                continue
            if verb == "agent.cadence" and value not in CADENCES:
                continue
        elif verb == "mission.queue":
            value = " | ".join(parts[2:]) if len(parts) > 3 else value
            if not (10 <= len(value) <= 2000):
                continue
            label = label if len(parts) > 4 else "Confier au codeur : " + value[:40]
        elif verb == "memory.grave":
            value = " | ".join(parts[2:]) if len(parts) > 3 else value
            if not (5 <= len(value) <= 300):
                continue
            label = label if len(parts) > 4 else "Graver : " + value[:40]
        actions.append({"id": _aid(verb, target, value), "verb": verb,
                        "target": target, "value": value, "label": label[:90],
                        "done": False})
    return "\n".join(keep).strip(), actions


def execute(action: dict) -> dict:
    """Exécute une action DÉJÀ validée (relue depuis le message stocké)."""
    verb, target, value = action["verb"], action.get("target", ""), action.get("value", "")
    try:
        if verb == "memory.grave":
            memory.add("règle", value, "décidé depuis Parler", source="chat/maxime")
            return {"ok": True, "effect": f"gravé : « {value[:60]} »"}
        if verb == "mission.queue":
            MISSIONS.mkdir(parents=True, exist_ok=True)
            name = time.strftime("%Y%m%d-%H%M%S") + "-chat.md"
            (MISSIONS / name).write_text(value, encoding="utf-8")
            return {"ok": True, "effect": f"mission {name} en file (codeur au prochain tour)"}
        if verb == "agent.run":
            subprocess.Popen(["bash", str(AGENT_RUN), target],
                             stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
            return {"ok": True, "effect": f"« {agent_ids().get(target, target)} » lancé"}
        if verb in ("agent.toggle", "agent.cadence"):
            return _patch_agent(verb, target, value)
    except Exception as exc:
        return {"error": f"{type(exc).__name__}: {exc}"[:150]}
    return {"error": "verbe inconnu"}


def _patch_agent(verb: str, target: str, value: str) -> dict:
    data = json.loads(AGENTS_JSON.read_text(encoding="utf-8"))
    hit = None
    for a in data.get("agents", []):
        if a["id"] == target:
            hit = a
            break
    if not hit:
        return {"error": "agent introuvable"}
    if verb == "agent.toggle":
        hit["enabled"] = (value == "on")
        eff = "activé" if hit["enabled"] else "désactivé"
    else:  # agent.cadence
        cron, human = CADENCES[value]
        hit["schedule"] = cron
        hit["enabled"] = True
        eff = f"réglé sur « {human} »"
    AGENTS_JSON.write_text(json.dumps(data, ensure_ascii=False, indent=2) + "\n",
                           encoding="utf-8")
    # La crontab reflète le nouvel état.
    subprocess.run(["bash", str(INSTALL)], capture_output=True, timeout=60)
    # Trace en mémoire : un réglage d'agent est une décision.
    memory.add("décision", f"Agent « {hit.get('label', target)} » {eff}",
               "réglé depuis Parler", source="chat/maxime")
    return {"ok": True, "effect": f"« {hit.get('label', target)} » {eff}"}


if __name__ == "__main__":
    txt, acts = parse("Je te propose de ralentir l'atelier.\n"
                      "ACTION: agent.cadence | corpus-night | nuit | Ralentir l'atelier (1×/nuit)")
    print("texte:", txt); print("actions:", json.dumps(acts, ensure_ascii=False))
