#!/usr/bin/env python3
"""La boîte aux lettres — qui t'a écrit, et qui attend ta réponse.

Le problème réel : un seul agent sur vingt-trois pouvait ouvrir une conversation
(le conseil du matin), rien ne signalait qu'elle existait, il fallait quatre
gestes pour la trouver, et quand Maxime répondait c'était MERLIN qui répondait —
parce que le destinataire était choisi par un menu du front, pas par le fil.

Ce module tient un index à côté des conversations : qui parle, sur quoi, qui
attend qui, et jusqu'où Maxime a lu.

    ~/merlin-memory/boite.json      {conv: {qui, sujet, ouvert, dernier, ...}}

ATTENTION au format : c'est un `.json`, PAS un `.jsonl` dans `chats/`.
`memory.chat_list()` balaie `chats/*.jsonl` — y déposer l'index le ferait
apparaître comme une conversation fantôme dans Parler.

Stdlib seule, ne lève jamais.
"""
from __future__ import annotations

import json
import re
import sys
import time
from pathlib import Path

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
import memory  # noqa: E402

INDEX = memory.BASE / "boite.json"
# Les identifiants de fil doivent rester compatibles avec la route du portail
# (`/api/chat/<conv>` valide `[0-9a-z-]{3,40}`) : ni underscore, ni majuscule.
CONV_RE = re.compile(r"^[0-9a-z][0-9a-z-]{2,39}$")


def _now() -> str:
    return time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime())


def _lire() -> dict:
    try:
        d = json.loads(INDEX.read_text(encoding="utf-8"))
        return d if isinstance(d, dict) else {}
    except Exception:
        return {}


def _ecrire(d: dict) -> None:
    try:
        INDEX.parent.mkdir(parents=True, exist_ok=True)
        INDEX.write_text(json.dumps(d, ensure_ascii=False, indent=1), encoding="utf-8")
    except Exception:
        pass


def slug(texte: str) -> str:
    """Un identifiant de fil valide, quoi qu'on lui donne."""
    s = re.sub(r"[^a-z0-9]+", "-", str(texte).lower()).strip("-")[:24]
    return s or "fil"


def declarer(conv: str, qui: str, sujet: str, attend_reponse: bool = True) -> bool:
    """Inscrit (ou met à jour) un fil dans la boîte."""
    if not CONV_RE.match(str(conv)):
        return False
    d = _lire()
    e = d.get(conv) or {"ouvert": _now(), "lu_jusqu_a": ""}
    e.update({"qui": str(qui)[:40], "sujet": str(sujet)[:120],
              "dernier": _now(), "attend_reponse": bool(attend_reponse)})
    d[conv] = e
    _ecrire(d)
    return True


def marquer_lu(conv: str) -> bool:
    d = _lire()
    if conv not in d:
        return False
    d[conv]["lu_jusqu_a"] = _now()
    d[conv]["attend_reponse"] = False
    _ecrire(d)
    return True


def destinataire(conv: str) -> str:
    """À QUI Maxime répond quand il écrit dans ce fil.

    C'est la correction du travers principal : le front imposait un destinataire
    choisi dans un menu, donc répondre au conseiller du matin s'adressait en
    réalité à MERLIN, et le conseiller ne voyait jamais la réponse."""
    return str((_lire().get(conv) or {}).get("qui", "")) or ""


def etat(limite: int = 20) -> dict:
    """Ce que le portail affiche : les fils, les non-lus, le plus urgent.

    Un fil est NON LU si son dernier message vient d'un agent et qu'il est
    postérieur au dernier passage de Maxime. On croise l'index avec les
    conversations réelles : l'index seul mentirait si un fichier disparaissait."""
    index = _lire()
    fils, non_lus = [], 0
    for c in memory.chat_list(limit=limite):
        cid = c.get("conv") or ""
        e = index.get(cid, {})
        neuf = bool(c.get("role") and c["role"] != "user"
                    and str(c.get("t", "")) > str(e.get("lu_jusqu_a", "")))
        if neuf:
            non_lus += 1
        fils.append({
            "conv": cid,
            "qui": e.get("qui") or c.get("who") or "merlin",
            "sujet": e.get("sujet") or (c.get("last") or "")[:80],
            "dernier": c.get("last", ""), "t": c.get("t", ""),
            "non_lu": neuf, "attend_toi": neuf,
            # Un fil dont le dernier mot est de Maxime attend l'AGENT : c'est ce
            # que la relance surveille (le message perdu quand le LLM était pris).
            "attend_agent": c.get("role") == "user",
            "mtime": c.get("mtime", 0),
        })
    fils.sort(key=lambda f: (not f["non_lu"], -f["mtime"]))
    return {"non_lus": non_lus, "fils": fils[:limite],
            "premier_non_lu": next((f["conv"] for f in fils if f["non_lu"]), "")}


def non_lus() -> int:
    return etat().get("non_lus", 0)


def en_attente_d_agent(age_min: int = 3) -> list[str]:
    """Fils où Maxime a parlé le dernier depuis plus de `age_min` minutes.

    C'est exactement le cas « le groupe LLM était occupé » : le portail a écrit
    le message de Maxime, l'agent n'a jamais été lancé, et personne ne le sait."""
    seuil = time.time() - age_min * 60
    return [f["conv"] for f in etat().get("fils", [])
            if f["attend_agent"] and f.get("mtime", 0) < seuil]


if __name__ == "__main__":
    if "--etat" in sys.argv:
        print(json.dumps(etat(), ensure_ascii=False, indent=1))
    else:
        e = etat()
        print(f"{e['non_lus']} non lu(s) sur {len(e['fils'])} fil(s)")
        for f in e["fils"][:6]:
            marque = "●" if f["non_lu"] else "·"
            print(f"  {marque} {f['conv']:28} {f['qui']:18} {f['dernier'][:50]}")
        att = en_attente_d_agent()
        if att:
            print("en attente d'un agent :", ", ".join(att))
