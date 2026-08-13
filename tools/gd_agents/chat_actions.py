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
VERBS = ("agent.toggle", "agent.cadence", "agent.run", "mission.queue",
         "memory.grave", "agent.create", "task.plan")


def _cron_ok(schedule: str | None) -> bool:
    """Le `schedule` est-il une vraie cadence cron à 5 champs ?

    Les agents « à la demande » / « webhook/push » n'en ont pas : les planifier
    fait rejeter la crontab ENTIÈRE par `crontab -`."""
    f = str(schedule or "").split()
    return len(f) == 5 and all(re.fullmatch(r"[\d*/,\-]+", x) for x in f)


def _agents() -> list[dict]:
    try:
        return json.loads(AGENTS_JSON.read_text(encoding="utf-8")).get("agents", [])
    except Exception:
        return []


def agent_ids() -> dict:
    """id → label français, pour informer le LLM et valider les cibles."""
    return {a["id"]: a.get("label", a["id"]) for a in _agents()}


def studio_state() -> str:
    """L'ÉTAT RÉEL du studio, en clair — sans ça le modèle répond dans le vague.

    Mesuré : sans ces données, il improvise des listes d'agents inexactes et
    tourne autour du pot. Avec, il cite les vraies cadences et les vrais noms."""
    lines = []
    state = Path.home() / ".cache" / "merlin-agents" / "state"
    human = {"*/2 * * * *": "toutes les 2 min", "*/5 * * * *": "toutes les 5 min",
             "*/10 * * * *": "toutes les 10 min", "*/15 * * * *": "tous les quarts d'heure",
             "*/30 * * * *": "toutes les 30 min", "17 * * * *": "chaque heure",
             "10 0-6 * * *": "chaque heure la nuit", "0 3 * * *": "à 3 h",
             "20 2 * * *": "à 2 h 20", "0 7 * * *": "à 7 h", "40 6 * * *": "à 6 h 40",
             "50 7,19 * * *": "2 fois par jour", "20 1,9,15,21 * * *": "4 fois par jour"}
    lines.append("LES AGENTS DU STUDIO (id — rôle — cadence — état) :")
    for a in _agents():
        aid = a["id"]
        cad = human.get(a.get("schedule", ""), a.get("schedule", "?"))
        etat = "actif" if a.get("enabled") else "en pause"
        last = ""
        try:
            st = json.loads((state / f"{aid}.json").read_text(encoding="utf-8"))
            if st.get("summary"):
                last = f" · dernier passage : {st['summary'][:70]}"
        except Exception:
            pass
        lines.append(f"  {aid} — {a.get('label', aid)} — {cad} — {etat}{last}")
    try:
        import memory
        lines.append(f"\nMÉMOIRE DU PROJET ({memory.count()} souvenirs) :\n{memory.digest(500)}")
    except Exception:
        pass
    try:
        import proposals as P
        c = P.listing()["counts"]
        lines.append(f"\nDÉCISIONS : {c.get('pending', 0)} en attente, "
                     f"{c.get('accepted', 0)} acceptées, {c.get('rejected', 0)} rejetées.")
    except Exception:
        pass
    return "\n".join(lines)


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
        "mission.queue (cible -, valeur = la tâche pour le codeur), memory.grave "
        "(cible -, valeur = la règle), task.plan (cible -, valeur = une tâche à "
        "prévoir), agent.create (cible -, valeur = ce que le nouvel agent devrait "
        "faire).\n"
        f"Identifiants d'agents valides : {ids}.")


def _aid(verb: str, target: str, value: str) -> str:
    return hashlib.sha1(f"{verb}|{target}|{value}".encode()).hexdigest()[:10]


def parse(reply: str) -> tuple[str, list[dict]]:
    """Extrait les lignes ACTION du texte. Rend (texte nettoyé, actions valides)."""
    ids = agent_ids()
    actions, keep, rejets = [], [], []
    for line in reply.splitlines():
        m = re.match(r"\s*ACTION:\s*(.+)", line)
        if not m:
            keep.append(line)
            continue
        parts = [p.strip() for p in m.group(1).split("|")]
        if len(parts) < 3:
            rejets.append(("?", "moins de trois champs"))
            continue
        verb, target, value = parts[0], parts[1], parts[2]
        label = parts[3] if len(parts) > 3 else verb
        if verb not in VERBS:
            rejets.append((verb, "verbe inconnu"))
            continue
        # Validation stricte selon le verbe.
        if verb in ("agent.toggle", "agent.cadence", "agent.run"):
            if target not in ids:
                rejets.append((verb, f"agent inconnu : {target}"))
                continue
            if verb == "agent.toggle" and value not in ("on", "off"):
                rejets.append((verb, f"« {value} » n'est pas on/off"))
                continue
            if verb == "agent.cadence" and value not in CADENCES:
                rejets.append((verb, f"« {value} » n'est pas une cadence connue"))
                continue
        elif verb in ("mission.queue", "task.plan"):
            # Le DERNIER champ est le libellé du bouton. Le coller dans la
            # valeur écrivait « Ne jamais dépasser 25 cartes | Grave cette règle »
            # dans la mission et dans la mémoire — Maxime relira ça dans six mois.
            # On ne joint que ce qui est ENTRE la valeur et le libellé, pour
            # continuer de tolérer une barre verticale dans un texte libre.
            value = " | ".join(parts[2:-1]) if len(parts) > 3 else value
            if not (10 <= len(value) <= 2000):
                rejets.append((verb, f"longueur {len(value)} hors 10-2000"))
                continue
            label = parts[-1] if len(parts) > 3 else (
                ("Prévoir : " if verb == "task.plan" else "Confier au codeur : ") + value[:38])
        elif verb == "memory.grave":
            value = " | ".join(parts[2:-1]) if len(parts) > 3 else value
            # 200 et non 300 : `memory.add` tronque le titre à 200 caractères,
            # donc au-delà la fin de la règle se perdait en silence.
            if not (5 <= len(value) <= 200):
                rejets.append((verb, f"longueur {len(value)} hors 5-200"))
                continue
            label = parts[-1] if len(parts) > 3 else "Graver : " + value[:40]
        elif verb == "agent.create":
            value = " | ".join(parts[2:-1]) if len(parts) > 3 else value
            if not (10 <= len(value) <= 500):
                rejets.append((verb, f"longueur {len(value)} hors 10-500"))
                continue
            label = parts[-1] if len(parts) > 3 else "Créer un agent : " + value[:36]
        actions.append({"id": _aid(verb, target, value), "verb": verb,
                        "target": target, "value": value, "label": label[:90],
                        "done": False})
    texte = "\n".join(keep).strip()
    # Une ligne ACTION rejetée emportait son texte avec elle : le modèle mettait
    # tout dans la ligne, la ligne était écartée, et Maxime recevait une BULLE
    # VIDE après plusieurs minutes d'attente — sans texte, sans bouton, sans
    # explication. C'est le mode d'échec le plus fréquent d'un petit modèle
    # (confondre une cadence avec un état, nommer un agent en français).
    if rejets and not texte and not actions:
        detail = " · ".join(f"{v} : {pourquoi}" for v, pourquoi in rejets[:2])
        texte = ("J'avais quelque chose à te proposer mais je l'ai mal formulé "
                 f"({detail}). Redemande-moi, je reformulerai.")
    return texte, actions


def _texte_mission(resume: str, demande: str) -> str:
    """Le texte que lira le codeur : les MOTS DE MAXIME d'abord.

    Mesuré sur un cas réel : Maxime écrit « la deuxième apparition de MERLIN une
    fois le biome sélectionné est inutile, on doit voir lentement la scène se
    construire… », le modèle résume en « Refactorisation séquence apparition
    biome/HUD » — il a interverti MERLIN et le biome, et jeté « lentement »,
    « plus animée », « plus d'éléments graphiques » et l'ordre d'apparition du
    HUD. Un codeur qui reçoit ce résumé ne peut PAS faire le travail demandé.
    La demande d'origine est donc la source, le résumé n'est qu'un titre."""
    resume = str(resume or "").strip()
    demande = str(demande or "").strip()
    if not demande:
        return resume
    return (f"DEMANDE DE MAXIME, MOT POUR MOT :\n« {demande[:1500]} »\n\n"
            f"Lecture qu'en a faite l'assistant (indicative, elle peut se tromper) :\n"
            f"{resume[:400]}\n\n"
            + _pistes(demande + " " + resume)
            + "En cas de désaccord entre les deux, la demande de Maxime fait foi.")


def _pistes(texte: str) -> str:
    """Les écrans et fichiers RÉELS que cette demande semble viser.

    C'est l'orchestration qui manquait : une mission qui dit « refactoriser la
    séquence d'apparition » sans nommer un fichier n'est exécutable par
    personne. On croise les mots de Maxime avec la carte du jeu (parcours.py) et
    on livre les pistes — en les annonçant comme des pistes, jamais comme des
    certitudes : c'est le codeur qui tranche."""
    try:
        import parcours
        vus, pistes = set(), []
        for mot in re.findall(r"[A-Za-zÀ-ÿ]{4,}", texte):
            for p in parcours.chercher(mot):
                if p.split(" ")[0] not in vus:
                    vus.add(p.split(" ")[0])
                    pistes.append(p)
        if not pistes:
            return ""
        return ("PISTES (croisement avec la carte du jeu — à vérifier, pas à croire) :\n"
                + "\n".join(f"- {p}" for p in pistes[:4]) + "\n\n")
    except Exception:
        return ""


def execute(action: dict, demande: str = "") -> dict:
    """Exécute une action DÉJÀ validée (relue depuis le message stocké)."""
    verb, target, value = action["verb"], action.get("target", ""), action.get("value", "")
    try:
        # « En parler » se joue entièrement dans le navigateur : elle amorce la
        # saisie de Maxime. Si elle arrive tout de même ici (plan groupé, vieux
        # message), elle ne doit rien casser ni prétendre avoir agi.
        if verb == "chat.parler":
            return {"ok": True, "effect": "à toi d'écrire — la saisie est amorcée"}
        if verb == "memory.grave":
            memory.add("règle", value, "décidé depuis Parler", source="chat/maxime")
            return {"ok": True, "effect": f"gravé : « {value[:60]} »"}
        if verb == "mission.queue":
            MISSIONS.mkdir(parents=True, exist_ok=True)
            name = time.strftime("%Y%m%d-%H%M%S") + "-chat.md"
            (MISSIONS / name).write_text(_texte_mission(value, demande), encoding="utf-8")
            return {"ok": True, "effect": f"mission {name} en file (codeur au prochain tour)"}
        if verb == "task.plan":
            # Une tâche prévue devient une carte Décider (pas d'exécution directe).
            sys.path.insert(0, str(HERE))
            import proposals as P
            P.write(P.make("chat", "design", "Tâche prévue : " + value[:60],
                           # Le claim porte les MOTS DE MAXIME, pas le résumé du
                           # modèle : c'est ce qu'on relira dans six mois.
                           (f"Demande de Maxime : « {demande[:300]} »" if demande
                            else "Tâche notée depuis Parler, à planifier."),
                           {"summary": _texte_mission(value, demande),
                            "target": "à planifier"},
                           _texte_mission(value, demande), confidence=0.6,
                           impact={"axis": "dev", "expected": value[:50], "risk": "low"}))
            return {"ok": True, "effect": "tâche ajoutée à Décider"}
        if verb == "agent.create":
            # Créer un agent = du code : ça remonte en proposition, jamais direct.
            sys.path.insert(0, str(HERE))
            import proposals as P
            P.write(P.make("chat", "infra", "Nouvel agent : " + value[:55],
                           "Création d'un agent demandée depuis Parler.",
                           {"summary": f"Créer un agent de game design qui : {value}",
                            "target": "tools/gd_agents/"},
                           f"Créer un nouvel agent de game design qui {value}. "
                           f"Suivre le patron des agents existants (analyseur + contrat "
                           f"dans agents.json + wrapper). Il PROPOSE, n'écrit jamais dans le jeu.",
                           confidence=0.55,
                           impact={"axis": "plateforme", "expected": value[:50], "risk": "med"}))
            return {"ok": True, "effect": "création d'agent proposée dans Décider"}
        if verb == "agent.run":
            subprocess.Popen(["bash", str(AGENT_RUN), target],
                             stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
            return {"ok": True, "effect": f"« {agent_ids().get(target, target)} » lancé"}
        if verb in ("agent.toggle", "agent.cadence"):
            return _patch_agent(verb, target, value)
    except Exception as exc:
        return {"error": f"{type(exc).__name__}: {exc}"[:150]}
    return {"error": "verbe inconnu"}


def execute_plan(actions: list[dict], demande: str = "") -> list[dict]:
    """Exécute un PLAN entier (le « Tout lancer » de l'orchestrateur).

    Chaque action garde son propre résultat : un échec n'arrête pas les autres,
    et le fil affiche ce qui a marché et ce qui a bloqué."""
    out = []
    for a in actions:
        if a.get("done"):
            out.append({"id": a["id"], "ok": True, "effect": "déjà fait"})
            continue
        # « En parler » ne s'exécute pas : elle amorce la saisie de Maxime dans
        # le navigateur. L'inclure dans un plan la consommait et écrivait un ✓
        # mensonger dans le fil — le bouton devenait inutilisable sans que rien
        # n'ait eu lieu.
        if a.get("verb") == "chat.parler":
            out.append({"id": a["id"], "ok": True, "ignore": True,
                        "label": a.get("label", ""),
                        "effect": "laissée de côté — c'est à toi d'écrire"})
            continue
        res = execute(a, demande)
        res["id"] = a["id"]
        res["label"] = a.get("label", "")
        out.append(res)
    return out


def _patch_agent(verb: str, target: str, value: str) -> dict:
    """Pose un réglage HORS du dépôt — écrire dans agents.json versionné
    bloquerait tous les déploiements (git pull refusé sur modification locale)."""
    sys.path.insert(0, str(AGENTS_JSON.parent))
    import overrides as OV
    hit = next((a for a in OV.agents() if a["id"] == target), None)
    if not hit:
        return {"error": "agent introuvable"}
    if verb == "agent.toggle":
        on = (value == "on")
        # Certains agents n'ont PAS de cadence cron (« à la demande »,
        # « webhook/push »). Les activer écrivait cette chaîne telle quelle dans la
        # crontab, que `crontab -` rejette EN BLOC : les 15 agents planifiés
        # disparaissaient d'un coup, et le portail répondait « activé ».
        if on and not _cron_ok(hit.get("schedule")):
            return {"error": f"« {hit.get('label', target)} » n'a pas de cadence "
                             f"({hit.get('schedule') or 'aucune'}) — choisis d'abord "
                             f"une fréquence, sinon la planification serait refusée."}
        OV.set_override(target, enabled=on)
        eff = "activé" if on else "désactivé"
    else:  # agent.cadence
        cron, human = CADENCES[value]
        OV.set_override(target, schedule=cron, enabled=True)
        eff = f"réglé sur « {human} »"
    # La crontab reflète le nouvel état — et un refus doit remonter à Maxime.
    p = subprocess.run(["bash", str(INSTALL)], capture_output=True, text=True, timeout=60)
    if p.returncode != 0:
        OV.set_override(target, **({"enabled": not on} if verb == "agent.toggle"
                                   else {"schedule": hit.get("schedule")}))
        return {"error": "planification refusée, réglage annulé : "
                         + (p.stderr or p.stdout or "").strip()[:160]}
    # Trace en mémoire : un réglage d'agent est une décision.
    memory.add("décision", f"Agent « {hit.get('label', target)} » {eff}",
               "réglé depuis Parler", source="chat/maxime")
    return {"ok": True, "effect": f"« {hit.get('label', target)} » {eff}"}


if __name__ == "__main__":
    txt, acts = parse("Je te propose de ralentir l'atelier.\n"
                      "ACTION: agent.cadence | corpus-night | nuit | Ralentir l'atelier (1×/nuit)")
    print("texte:", txt); print("actions:", json.dumps(acts, ensure_ascii=False))
