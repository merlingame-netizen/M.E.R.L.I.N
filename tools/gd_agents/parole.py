#!/usr/bin/env python3
"""Les agents viennent te parler — sans dépenser un seul token.

Le pari central : un agent n'a PAS besoin du modèle pour t'interpeller. Il
produit déjà du français, tous les jours, et personne ne le lit : son `summary`
d'exécution, le `claim` de sa proposition, le `diag` du vérificateur, le motif
exact du validateur. Ouvrir un fil, c'est prendre ce texte et le poser dans
Parler avec deux boutons.

Ce qui coûte cher, ce n'est pas le token — c'est TON attention. D'où :

  · des déclencheurs 100 % déterministes et rares (pas d'heuristique floue) ;
  · un quota DUR de 2 fils par jour, les plus lourds d'abord ;
  · une règle anti-lassitude : un personnage dont les deux derniers fils sont
    restés non lus quatre jours perd la parole jusqu'à ce que tu lui écrives.

Au-delà du quota, l'agent retombe sur la carte Décider, comme aujourd'hui.

    python3 tools/gd_agents/parole.py            # balaie et ouvre ce qui le mérite
    python3 tools/gd_agents/parole.py --sec      # ce qu'il ferait, sans rien écrire

Stdlib seule. Ne lève jamais.
"""
from __future__ import annotations

import json
import subprocess
import sys
import time
from pathlib import Path

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
import boite         # noqa: E402
import chat_actions  # noqa: E402  (générateur d'identifiants d'action)
import memory        # noqa: E402
import proposals as PROP  # noqa: E402

CACHE = Path.home() / ".cache" / "merlin-agents"
NOTIFY = HERE.parents[1] / "infra" / "oracle" / "agents" / "notify.sh"
REGISTRE = memory.BASE / "parole.json"

QUOTA_JOUR = 2
SILENCE_JOURS = 4          # non-lu depuis N jours → l'agent se tait
MAX_FILS_MUETS = 2


def _now() -> str:
    return time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime())


def _jour() -> str:
    return time.strftime("%Y-%m-%d", time.localtime())


def _registre() -> dict:
    try:
        return json.loads(REGISTRE.read_text(encoding="utf-8"))
    except Exception:
        return {"jour": _jour(), "ouverts": [], "par_agent": {}}


def _sauver(r: dict) -> None:
    try:
        REGISTRE.parent.mkdir(parents=True, exist_ok=True)
        REGISTRE.write_text(json.dumps(r, ensure_ascii=False, indent=1), encoding="utf-8")
    except Exception:
        pass


def _lire_json(p: Path, defaut):
    try:
        return json.loads(p.read_text(encoding="utf-8"))
    except Exception:
        return defaut


def _lire_jsonl(p: Path, n: int = 200) -> list[dict]:
    out = []
    try:
        for x in p.read_text(encoding="utf-8").splitlines()[-n:]:
            if x.strip():
                try:
                    out.append(json.loads(x))
                except Exception:
                    pass
    except Exception:
        pass
    return out


def _ts(s) -> float:
    try:
        return time.mktime(time.strptime(str(s)[:19], "%Y-%m-%dT%H:%M:%S"))
    except Exception:
        return 0.0


# ── les déclencheurs, tous déterministes ─────────────────────────────────────

def _ci_deux_fois() -> list[dict]:
    """La MÊME scène en échec sur deux verdicts d'affilée. Une fois est un
    accident, deux fois est un sujet."""
    hist = _lire_jsonl(CACHE / "ci" / "history.jsonl", 10)
    if len(hist) < 2:
        return []
    a, b = hist[-1], hist[-2]
    if not (a.get("scenes_failing") and b.get("scenes_failing")):
        return []
    import re
    def scenes(sha):
        try:
            t = (CACHE / "ci" / f"{str(sha)[:8]}-errors.log").read_text(
                encoding="utf-8", errors="replace")
        except Exception:
            return set()
        return set(re.findall(r"===\s*([\w/.-]+\.tscn)\s*===", t))
    communes = scenes(a.get("sha")) & scenes(b.get("sha"))
    if not communes:
        return []
    nom = sorted(communes)[0]
    return [{"poids": 5, "qui": "ci-commit", "cle": f"scene-{nom.split('/')[-1][:-5].lower()}",
             "sujet": f"{nom} casse deux fois de suite",
             "texte": (f"{nom} refuse de démarrer sur les deux derniers commits.\n\n"
                       f"Mon diagnostic : {str(a.get('diag', '')).strip() or '(aucun)'}\n\n"
                       "Ce n'est plus un accident. Veux-tu que j'ouvre une mission "
                       "pour la réparer, ou préfères-tu la regarder toi-même ?"),
             "actions": [
                 {"verbe": "mission.queue", "cible": "",
                  "valeur": f"Réparer {nom} : elle échoue sur deux commits consécutifs. "
                            f"Diagnostic : {str(a.get('diag',''))[:200]}",
                  "libelle": "Mets une mission en file"},
                 {"verbe": "chat.parler", "cible": "",
                  "valeur": f"À propos de {nom} : ",
                  "libelle": "En parler"}]}]


def _playtest_anomalie() -> list[dict]:
    """Le robot testeur a vu le jeu se figer. Il fabrique déjà la carte ; il lui
    manquait la parole."""
    out = []
    for p in sorted(PROP.INBOX.glob("*.json")) if PROP.INBOX.exists() else []:
        d = _lire_json(p, {})
        if d.get("kind") != "bug" or d.get("agent") != "playtest-bot":
            continue
        if _ts(d.get("created")) < time.time() - 30 * 3600:
            continue
        out.append({"poids": 5, "qui": "playtest-bot",
                    "cle": "playtest-" + str(d.get("id", ""))[-6:],
                    "sujet": d.get("title", "Anomalie pendant le playtest"),
                    "texte": (f"J'ai joué et je me suis arrêté net.\n\n"
                              f"{d.get('claim', '')}\n\n"
                              "Je t'ai laissé la carte dans Décider avec mes captures. "
                              "Tu veux que je rejoue la même séquence pour vérifier que "
                              "ce n'est pas un hasard ?"),
                    "actions": [
                        {"verbe": "agent.run", "cible": "playtest-bot", "valeur": "",
                         "libelle": "Rejoue une session"},
                        {"verbe": "mission.queue", "cible": "",
                         "valeur": f"Anomalie de jeu : {d.get('title','')[:120]}",
                         "libelle": "Mets une mission en file"}]})
    return out[:1]


def _patch_annule() -> list[dict]:
    """Le codeur a appliqué un patch, le smoke est passé au rouge, il a tout
    annulé. C'est le moment le plus romanesque de la chaîne — et il était muet."""
    out = []
    if not PROP.ACCEPTED.exists():
        return out
    for p in PROP.ACCEPTED.glob("*.json"):
        d = _lire_json(p, {})
        for e in (d.get("trail") or []):
            if e.get("step") != "smoke rouge":
                continue
            if _ts(e.get("t")) < time.time() - 30 * 3600:
                continue
            out.append({"poids": 5, "qui": "coder-local",
                        "cle": "annule-" + str(d.get("id", ""))[-6:],
                        "sujet": f"J'ai annulé mon patch : {d.get('title','')[:60]}",
                        "texte": (f"J'ai appliqué la correction que tu avais acceptée "
                                  f"({d.get('title','')}), puis le test a viré au rouge : "
                                  f"{e.get('detail','')}\n\n"
                                  "J'ai tout remis en place — le jeu est intact. Mais la "
                                  "correction reste à faire. On la reprend autrement ?"),
                        "actions": [
                            {"verbe": "mission.queue", "cible": "",
                             "valeur": f"Reprendre autrement : {d.get('title','')[:120]}",
                             "libelle": "Remets-la en file, autrement"},
                            {"verbe": "chat.parler", "cible": "",
                             "valeur": f"Patch refusé par le smoke : {d.get('title','')[:100]}",
                             "libelle": "En parler"}]})
    return out[:1]


def _decision_bloquee() -> list[dict]:
    """Une décision poussée sur la branche de nuit depuis plus de 24 h : elle
    attend un tap de fusion que personne ne voit."""
    if not PROP.ACCEPTED.exists():
        return []
    vieilles = []
    for p in PROP.ACCEPTED.glob("*.json"):
        d = _lire_json(p, {})
        if d.get("step") != "poussée":
            continue
        t = max((_ts(e.get("t")) for e in (d.get("trail") or [])), default=0)
        if t and t < time.time() - 24 * 3600:
            vieilles.append(d)
    if not vieilles:
        return []
    return [{"poids": 4, "qui": "coder-local", "cle": "attente-fusion",
             "sujet": f"{len(vieilles)} correction(s) attendent d'entrer dans le jeu",
             "texte": ("J'ai appliqué et vérifié ces corrections il y a plus d'un jour, "
                       "elles dorment sur la branche de nuit :\n"
                       + "\n".join("· " + str(v.get("title", ""))[:70] for v in vieilles[:4])
                       + "\n\nIl te suffit d'accepter la carte « Intégrer » dans Décider."),
             "actions": []}]


def _idee_sans_patch() -> list[dict]:
    """Un analyseur a trouvé quelque chose qu'il ne sait PAS corriger tout seul.
    C'est exactement ce qui tombe aujourd'hui dans une carte muette."""
    if not PROP.INBOX.exists():
        return []
    for p in sorted(PROP.INBOX.glob("*.json"), key=lambda x: -x.stat().st_mtime):
        d = _lire_json(p, {})
        if d.get("kind") not in ("balance", "design") or PROP.applicable(d):
            continue
        if _ts(d.get("created")) < time.time() - 30 * 3600:
            continue
        claim = str(d.get("claim", "")).strip()
        if not claim:
            continue
        # Une PANNE D'OUTILLAGE n'est pas une question de design. Sans ce filtre,
        # l'agent venait dire « la rédaction automatique a échoué : JSON
        # illisible… qu'est-ce que tu en penses ? » — il demandait son avis à
        # Maxime sur son propre bug. Ces cas restent des cartes dans Décider.
        if any(x in claim.lower() for x in (
                "llm indisponible", "json illisible", "rédaction automatique a échoué",
                "validateur indisponible", "modèle local", "analyse seule")):
            continue
        return [{"poids": 4, "qui": d.get("agent", "gd-balance"),
                 "cle": "idee-" + str(d.get("id", ""))[-6:],
                 "sujet": d.get("title", "Une question de design"),
                 "texte": (f"{d.get('claim','')}\n\n"
                           "Je ne sais pas corriger ça tout seul : il n'y a pas une ligne "
                           "précise à remplacer, c'est un choix de design. "
                           "Qu'est-ce que tu en penses ?"),
                 # On ne grave PAS une question : une question n'est pas une
                 # décision. On l'approfondit d'abord — la mémoire reste à un
                 # tap, dans l'en-tête du fil, quand la réponse est mûre.
                 "actions": [
                     {"verbe": "chat.parler", "cible": "",
                      "valeur": f"À propos de « {str(d.get('title',''))[:80]} » : ",
                      "libelle": "En parler"}]}]
    return []


DECLENCHEURS = (_ci_deux_fois, _playtest_anomalie, _patch_annule,
                _decision_bloquee, _idee_sans_patch)


# ── l'ouverture d'un fil ─────────────────────────────────────────────────────

def _muet(qui: str, reg: dict) -> bool:
    """Anti-lassitude : deux fils de suite non lus depuis 4 jours → silence."""
    h = (reg.get("par_agent") or {}).get(qui) or {}
    if h.get("muets", 0) < MAX_FILS_MUETS:
        return False
    dernier = _ts(h.get("dernier", ""))
    return bool(dernier and dernier > time.time() - SILENCE_JOURS * 86400)


def ouvrir(sig: dict, sec: bool = False) -> str:
    conv = f"mot-{time.strftime('%Y%m%d')}-{boite.slug(sig['cle'])}"[:40]
    if sec:
        return f"[à sec] {conv} · {sig['qui']} · {sig['sujet'][:60]}"
    # L'identifiant DOIT être celui qu'attend le portail : `/api/chat/action`
    # valide `[0-9a-f]{10}`. Fabriquer « mot-20260812-idee-5fe360-0 » faisait
    # rejeter le tap avec « requête invalide » AVANT toute exécution — le bouton
    # ne pouvait pas marcher. On réutilise le générateur officiel.
    actions = []
    for a in (sig.get("actions") or []):
        verbe, cible, valeur = a["verbe"], a.get("cible", ""), a.get("valeur", "")
        actions.append({"id": chat_actions._aid(verbe, cible, valeur),
                        "verb": verbe, "target": cible,
                        "value": valeur, "label": a["libelle"]})
    memory.chat_append(conv, "assistant", sig["qui"], sig["texte"], actions=actions or None)
    boite.declarer(conv, sig["qui"], sig["sujet"])
    try:
        subprocess.run(["bash", str(NOTIFY), "default", sig["qui"],
                        sig["sujet"][:120], "?tab=talk"],
                       capture_output=True, timeout=20)
    except Exception:
        pass
    return conv


def run(sec: bool = False) -> str:
    reg = _registre()
    if reg.get("jour") != _jour():
        reg = {"jour": _jour(), "ouverts": [], "par_agent": reg.get("par_agent", {})}

    # Comptabiliser les fils restés non lus AVANT de décider qui a droit à la parole.
    etat = boite.etat(limite=30)
    for f in etat.get("fils", []):
        qui = f.get("qui", "")
        h = reg.setdefault("par_agent", {}).setdefault(qui, {"muets": 0, "dernier": ""})
        if f.get("non_lu") and _ts(f.get("t")) < time.time() - SILENCE_JOURS * 86400:
            h["muets"] = min(h.get("muets", 0) + 1, MAX_FILS_MUETS)
        elif not f.get("non_lu"):
            h["muets"] = 0                  # tu l'as lu : il retrouve la parole

    signaux = []
    for d in DECLENCHEURS:
        try:
            signaux += d() or []
        except Exception:
            continue
    deja = set(reg.get("ouverts") or [])
    signaux = [s for s in signaux
               if s["cle"] not in deja and not _muet(s["qui"], reg)]
    signaux.sort(key=lambda s: -s["poids"])

    reste = QUOTA_JOUR - len(deja)
    if reste <= 0:
        return f"quota du jour atteint ({QUOTA_JOUR}) — {len(signaux)} signal(aux) reporté(s)"
    if not signaux:
        return "rien à dire aujourd'hui"

    faits = []
    for s in signaux[:reste]:
        faits.append(ouvrir(s, sec))
        if not sec:
            reg.setdefault("ouverts", []).append(s["cle"])
            reg.setdefault("par_agent", {}).setdefault(
                s["qui"], {"muets": 0, "dernier": ""})["dernier"] = _now()
    if not sec:
        _sauver(reg)
    return (f"{len(faits)} fil(s) ouvert(s) : " + " · ".join(faits)
            + (f" · {len(signaux) - len(faits)} reporté(s)" if len(signaux) > len(faits) else ""))


if __name__ == "__main__":
    try:
        print(run(sec="--sec" in sys.argv))
    except Exception as exc:
        print(f"échec de la parole : {type(exc).__name__}: {exc}"[:180])
        sys.exit(1)
