#!/usr/bin/env python3
"""Propositions des agents de game design — schéma `merlin.proposal/1`.

DOCTRINE : les agents locaux PROPOSENT, ils n'écrivent jamais dans le jeu.
Accepter une proposition écrit son `mission_text` dans la file du codeur
(~/.cache/merlin-missions/queue), que infra/oracle/agents/a_coder.sh consomme
déjà sur la branche auto/coder. Lancer le codeur reste un second geste explicite.

Stockage hors dépôt, comme les missions :
    ~/.cache/merlin-proposals/{inbox,accepted,rejected}/<id>.json

`rejected/` est conservé AVEC sa raison : inbox triée = jeu de préférences
humaines, exploitable plus tard pour un entraînement par préférences.

Module partagé entre le runner (écriture) et le portail (lecture/décision).
Stdlib uniquement, ne lève jamais côté lecture.
"""
from __future__ import annotations

import json
import re
import time
import uuid
from pathlib import Path

BASE = Path.home() / ".cache" / "merlin-proposals"
INBOX, ACCEPTED, REJECTED = BASE / "inbox", BASE / "accepted", BASE / "rejected"
MISSIONS = Path.home() / ".cache" / "merlin-missions" / "queue"
# Jeu d'entraînement du modèle — PAS du contenu de jeu : les scénarios
# sont générés 100 % en direct par le LLM (décision Maxime, 2026-08-12).
CURATED = "data/ai/training/curated_corpus.jsonl"

SCHEMA = "merlin.proposal/1"
KINDS = ("balance", "content", "design", "ux", "bug", "infra", "merge")
ID_RE = re.compile(r"^[0-9a-z][0-9a-z-]{7,63}$")
MAX_INBOX = 200
REQUIRED = ("schema", "id", "created", "agent", "kind", "title",
            "claim", "change", "confidence", "mission_text", "status")


def _now() -> str:
    return time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime())


def new_id(agent: str) -> str:
    slug = re.sub(r"[^a-z0-9]+", "-", agent.lower()).strip("-")[:20] or "agent"
    return f"{time.strftime('%Y%m%d-%H%M', time.gmtime())}-{slug}-{uuid.uuid4().hex[:6]}"


def make(agent: str, kind: str, title: str, claim: str, change: dict,
         mission_text: str, *, evidence=None, impact=None, confidence=0.5,
         model="none", tier=None, cost=None, validation=None, payload=None) -> dict:
    """Construit une proposition conforme. `change` et `mission_text` sont le cœur."""
    if kind not in KINDS:
        raise ValueError(f"kind inconnu: {kind}")
    return {
        "schema": SCHEMA, "id": new_id(agent), "created": _now(),
        "agent": agent, "model": model, "tier": tier, "kind": kind,
        "title": str(title)[:160], "claim": str(claim)[:400],
        "evidence": evidence or [], "change": change,
        "impact": impact or {}, "confidence": round(float(confidence), 2),
        "cost": cost or {}, "validation": validation or {}, "payload": payload,
        "mission_text": str(mission_text), "status": "pending", "decided_at": None,
    }


def validate(prop: dict) -> list[str]:
    """Rend la liste des manquements (vide = conforme)."""
    errs = [f"champ manquant: {k}" for k in REQUIRED if k not in prop]
    if prop.get("schema") != SCHEMA:
        errs.append(f"schema attendu {SCHEMA}")
    if prop.get("kind") not in KINDS:
        errs.append(f"kind invalide: {prop.get('kind')}")
    if not ID_RE.match(str(prop.get("id", ""))):
        errs.append("id invalide")
    if not isinstance(prop.get("change"), dict) or not prop["change"].get("summary"):
        errs.append("change.summary requis")
    if not str(prop.get("mission_text", "")).strip():
        errs.append("mission_text vide")
    return errs


def write(prop: dict) -> Path:
    """Écrit dans inbox/. Purge FIFO au-delà de MAX_INBOX (le disque est compté)."""
    errs = validate(prop)
    if errs:
        raise ValueError("proposition non conforme: " + "; ".join(errs))
    INBOX.mkdir(parents=True, exist_ok=True)
    path = INBOX / f"{prop['id']}.json"
    path.write_text(json.dumps(prop, ensure_ascii=False, indent=1), encoding="utf-8")
    olds = sorted(INBOX.glob("*.json"), key=lambda p: p.stat().st_mtime)
    for p in olds[:-MAX_INBOX]:
        p.unlink(missing_ok=True)
    return path


def _read(path: Path) -> dict | None:
    try:
        return json.loads(path.read_text(encoding="utf-8"))
    except Exception:
        return None


def _rank(p: dict) -> float:
    """Tri d'affichage : confiance pondérée par le risque (le risqué remonte)."""
    risk = {"low": 0.8, "med": 1.0, "high": 1.3}.get(
        str((p.get("impact") or {}).get("risk", "med")).lower(), 1.0)
    return float(p.get("confidence", 0)) * risk


def listing(limit: int = 40) -> dict:
    """Lecture pour le portail — ne lève jamais."""
    pend = []
    try:
        pend = [d for d in (_read(p) for p in INBOX.glob("*.json")) if d]
    except Exception:
        pass
    pend.sort(key=_rank, reverse=True)
    counts = {}
    for name, d in (("pending", INBOX), ("accepted", ACCEPTED), ("rejected", REJECTED)):
        try:
            counts[name] = len(list(d.glob("*.json")))
        except Exception:
            counts[name] = 0
    # Décisions récentes AVEC leur parcours : sans ça, accepter une proposition
    # la faisait disparaître de l'écran et Maxime n'apprenait jamais ce qu'elle
    # était devenue. Neuf missions ont ainsi attendu sans que rien ne le dise.
    suivi = []
    try:
        recents = sorted(ACCEPTED.glob("*.json"), key=lambda p: p.stat().st_mtime,
                         reverse=True)[:12]
        for p in recents:
            d = _read(p) or {}
            suivi.append({"id": d.get("id"), "title": d.get("title"),
                          "kind": d.get("kind"), "agent": d.get("agent"),
                          "step": d.get("step", "acceptée"),
                          "trail": d.get("trail", []),
                          "decided_at": d.get("decided_at", "")})
    except Exception:
        pass
    return {"pending": pend[:limit], "counts": counts, "suivi": suivi}


def _find(pid: str) -> Path | None:
    """La proposition, où qu'elle en soit de son parcours."""
    name = f"{Path(str(pid)).name}.json"
    for d in (ACCEPTED, INBOX, REJECTED):
        if (d / name).exists():
            return d / name
    return None


def add_step(pid: str, step: str, detail: str = "") -> bool:
    """Grave une étape horodatée sur le parcours d'une proposition.

    Le codeur local CONNAISSAIT déjà chacun de ces états (« patché », « smoke
    rouge », « poussé », « écarté : cible hors périmètre ») — il ne les écrivait
    nulle part. Résultat : neuf décisions de Maxime ont disparu sans laisser de
    trace. Ici, chaque acteur dépose son étape, et le portail affiche le fil.
    Ne lève jamais : une trace manquante ne doit pas casser un patch."""
    if not ID_RE.match(str(pid)):
        return False
    try:
        path = _find(pid)
        if not path:
            return False
        prop = _read(path)
        if not prop:
            return False
        trail = prop.setdefault("trail", [])
        trail.append({"t": _now(), "step": str(step)[:40], "detail": str(detail)[:300]})
        prop["trail"] = trail[-20:]
        prop["step"] = str(step)[:40]          # l'étape courante, pour l'affichage
        path.write_text(json.dumps(prop, ensure_ascii=False, indent=1), encoding="utf-8")
        return True
    except Exception:
        return False


def applicable(prop: dict) -> bool:
    """La proposition porte-t-elle un patch que le codeur sait appliquer ?

    C'est la distinction qui manquait : sans elle, `decide` répondait « mission
    en file » pour TOUT, y compris pour des propositions que le codeur rejette
    définitivement. Maxime lisait « ça va être fait » là où rien n'arriverait."""
    ch = prop.get("change") or {}
    return bool(ch.get("before") and ch.get("after") and ch.get("target"))


def decide(pid: str, decision: str, reason: str = "", repo_root: Path | None = None) -> dict:
    """Accepte ou rejette. Accepter met en file ; ne lance JAMAIS le codeur."""
    if not ID_RE.match(str(pid)):
        return {"error": "id invalide"}
    if decision not in ("accept", "reject"):
        return {"error": "decision doit être accept ou reject"}
    src = INBOX / f"{Path(str(pid)).name}.json"
    if not src.exists():
        return {"error": "proposition introuvable"}
    prop = _read(src)
    if not prop:
        return {"error": "proposition illisible"}

    prop["status"] = "accepted" if decision == "accept" else "rejected"
    prop["decided_at"] = _now()
    if reason:
        prop["decision_reason"] = str(reason)[:400]

    out = {"ok": True, "id": prop["id"], "status": prop["status"], "effect": "aucun"}
    if decision == "accept":
        if prop["kind"] == "merge" and str(prop.get("mission_text", "")).startswith("MERGE:"):
            # LE tap qui fait bouger la branche du jeu : fusion de auto/nightly.
            import subprocess
            _, branch, ref = prop["mission_text"].split(":", 2)
            game = Path.home() / "workspace" / "merlin-game"
            try:
                for args in (["fetch", "origin", branch, ref],
                             ["checkout", ref], ["merge", "--no-ff", "-m",
                              f"merge(auto): intégration {branch} — {prop['id']}",
                              f"origin/{branch}"],
                             ["push", "origin", ref]):
                    p = subprocess.run(["git", "-C", str(game), *args],
                                       capture_output=True, text=True, timeout=180)
                    if p.returncode != 0:
                        raise RuntimeError(f"git {args[0]}: {(p.stdout + p.stderr)[-140:]}")
                out["effect"] = f"{branch} fusionnée dans {ref} et poussée — la CI re-testera"
                # Clôture du parcours de chaque proposition intégrée.
                for pid in (prop.get("integrates") or []):
                    add_step(pid, "fusionnée", f"entrée dans {ref} via {prop['id']}")
            except Exception as exc:
                subprocess.run(["git", "-C", str(game), "merge", "--abort"],
                               capture_output=True, timeout=60)
                subprocess.run(["git", "-C", str(game), "checkout", ref],
                               capture_output=True, timeout=60)
                prop["status"] = "pending"          # le merge a échoué : on rend la carte
                (INBOX / src.name).write_text(json.dumps(prop, ensure_ascii=False, indent=1),
                                              encoding="utf-8")
                return {"error": f"merge impossible : {exc}"[:200]}
        elif prop["kind"] == "content" and prop.get("payload") is not None:
            root = repo_root or Path(__file__).resolve().parents[2]
            target = root / CURATED
            target.parent.mkdir(parents=True, exist_ok=True)
            with target.open("a", encoding="utf-8") as f:
                f.write(json.dumps({"card": prop["payload"], "source": prop["id"],
                                    "ts": _now()}, ensure_ascii=False) + "\n")
            out["effect"] = f"carte ajoutée à {CURATED}"
        else:
            MISSIONS.mkdir(parents=True, exist_ok=True)
            name = f"{prop['id']}.md"
            (MISSIONS / name).write_text(prop["mission_text"], encoding="utf-8")
            # Dire la vérité sur ce qui va se passer. « En file » laissait croire
            # à une application imminente ; sans before/after, le codeur écarte
            # la mission à chaque passage, pour toujours.
            if applicable(prop):
                out["effect"] = ("correction en file — le codeur l'appliquera à son "
                                 "prochain passage, puis te proposera l'intégration")
                out["auto"] = True
            else:
                out["effect"] = ("noté, sans application automatique : cette idée demande "
                                 "une décision d'architecture, pas un remplacement de ligne")
                out["auto"] = False

    # Mémoire absolue : toute décision se grave, avec sa raison. Jamais d'effacement.
    try:
        import memory
        # Le seul appelant automatique préfixe sa raison par « auto : ». Chercher
        # « auto » n'importe où marchait tant que les raisons venaient de la
        # machine ; maintenant que Maxime écrit les siennes, « je le fais en
        # automatique » lui volerait sa signature dans la mémoire.
        auto = str(prop.get("decision_reason", "")).lstrip().startswith("auto ")
        memory.add(
            "contenu" if (decision == "accept" and prop["kind"] == "content") else
            "intégration" if (decision == "accept" and prop["kind"] == "merge") else
            "décision" if decision == "accept" else "rejet",
            prop["title"],
            (prop.get("decision_reason", "") or prop.get("claim", ""))[:300],
            source=("auto" if auto else "maxime") + f"/{prop.get('agent', '?')}",
            refs=[prop["id"]])
    except Exception:
        pass

    # Première étape du parcours visible par Maxime (suite écrite par le codeur).
    prop["step"] = "acceptée" if decision == "accept" else "écartée"
    prop.setdefault("trail", []).append(
        {"t": prop["decided_at"], "step": prop["step"],
         "detail": out.get("effect", "") if decision == "accept"
                   else (prop.get("decision_reason", "") or "sans suite")})

    dest = (ACCEPTED if decision == "accept" else REJECTED)
    dest.mkdir(parents=True, exist_ok=True)
    (dest / src.name).write_text(json.dumps(prop, ensure_ascii=False, indent=1),
                                 encoding="utf-8")
    src.unlink(missing_ok=True)
    return out


if __name__ == "__main__":       # démo/selftest : écrit une proposition factice
    import sys
    if "--selftest" in sys.argv:
        p = make("selftest", "design", "Proposition de test",
                 "Vérifie que la chaîne écriture → listing → décision fonctionne.",
                 {"summary": "Aucun changement réel.", "target": "—"},
                 "Ne rien faire : ceci est un test.", confidence=0.1)
        write(p)
        print(f"écrite: {p['id']} · inbox={listing()['counts']['pending']}")
        print("décision:", decide(p["id"], "reject", "selftest"))
        sys.exit(0)
    print(json.dumps(listing(), ensure_ascii=False, indent=1)[:2000])
