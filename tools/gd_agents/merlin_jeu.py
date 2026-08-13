#!/usr/bin/env python3
"""Le MERLIN du JEU — le personnage, pas l'assistant du studio.

Deux MERLIN cohabitent et on les confondait :

  · celui du STUDIO — il connaît les agents, les cadences, la mémoire du
    projet. C'est un outil de pilotage. Il répond déjà dans Parler.
  · celui du JEU — c'est le personnage que le joueur rencontre. Il parle à la
    première personne, il ne sait rien des agents, il ne connaît que le monde
    du jeu. C'est LUI qu'on veut pouvoir entendre, éprouver, et corriger.

Ce module tient sa VOIX dans un fichier hors dépôt
(~/merlin-memory/voix_merlin.json), lisible et modifiable depuis le portail. Le
réglage de la voix, c'est du « fine-tune » au sens utile du terme : on n'a pas
besoin de réentraîner un modèle pour changer la façon dont un personnage parle,
on a besoin d'écrire ce qu'il est. Le vrai fine-tune (LoRA) viendra quand le
corpus le justifiera ; d'ici là, ces quelques lignes font 90 % du travail pour
0 € et 0 minute de calcul.

Stdlib seule. Ne lève jamais.
"""
from __future__ import annotations

import json
import re
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))

VOIX = Path.home() / "merlin-memory" / "voix_merlin.json"

# Le point de départ. Il tient en peu de lignes exprès : une voix qu'on ne peut
# pas relire d'un coup d'œil est une voix qu'on ne corrigera jamais.
DEFAUT = {
    "nom": "Merlin",
    "identite": (
        "Tu es Merlin, l'enchanteur de Brocéliande. Tu t'adresses au voyageur "
        "qui vient de te trouver. Tu as vu passer des siècles et tu n'en fais "
        "pas étalage."),
    "ton": (
        "Grave et chaleureux. Des phrases courtes. Jamais de familiarité, "
        "jamais de solennité creuse. Tu tutoies."),
    "regles": [
        "Tu ne mentionnes JAMAIS que tu es une intelligence artificielle, "
        "ni le studio, ni les agents, ni le développement du jeu.",
        "Tu parles à la première personne, au présent.",
        "Trois phrases au maximum, sauf si on te demande un récit.",
        "Tu ne poses jamais plus d'une question à la fois.",
        "Si tu ignores quelque chose du monde, tu le dis simplement.",
    ],
    "exemples": [
        {"joueur": "Qui es-tu ?",
         "merlin": "On m'a donné bien des noms. Garde celui de Merlin, il "
                   "suffira. Et toi, qu'est-ce qui t'amène si loin des routes ?"},
        {"joueur": "J'ai peur.",
         "merlin": "C'est bon signe. La forêt ne pardonne pas à ceux qui "
                   "n'ont peur de rien. Reste près de moi."},
    ],
    "modele": "",            # vide = le modèle par défaut du routeur
}


JEU = Path.home() / "workspace" / "merlin-game"

# Les répliques du jeu se reconnaissent à leur longueur et à leur ponctuation :
# une vraie phrase française, pas un identifiant ni un nom de nœud.
_REPLIQUE = re.compile(r'"([A-ZÀ-Ý][^"\\]{28,180}[.!?…»])"')
_TECHNIQUE = re.compile(r"(res://|user://|\.gd|\.tscn|\.png|http|%s|\{|_[a-z])")


def repliques_du_jeu(limite: int = 6) -> list[str]:
    """Ce que Merlin dit VRAIMENT dans le jeu, lu dans le code du jeu.

    C'est ce qui fait de lui une copie conforme et non une imitation : sa voix
    dans Parler est calquée sur ses répliques réelles, et elle suit le jeu quand
    le jeu change. On lit les fichiers où il parle (menu, chronique, boot), on
    garde les phrases françaises et on écarte tout ce qui sent le code."""
    src = JEU / "scripts" / "game"
    if not src.exists():
        return []
    vues, out = set(), []
    for nom in ("merlin_menu_voice.gd", "merlin_chronicle.gd", "merlin_boot.gd",
                "merlin_menu.gd", "merlin_game.gd", "merlin_end.gd"):
        f = src / nom
        try:
            texte = f.read_text(encoding="utf-8", errors="replace")
        except Exception:
            continue
        for m in _REPLIQUE.finditer(texte):
            phrase = m.group(1).strip()
            if _TECHNIQUE.search(phrase) or phrase.lower() in vues:
                continue
            vues.add(phrase.lower())
            out.append(phrase)
            if len(out) >= limite:
                return out
    return out


def charger() -> dict:
    try:
        d = json.loads(VOIX.read_text(encoding="utf-8"))
        v = {**DEFAUT, **d} if isinstance(d, dict) else dict(DEFAUT)
    except Exception:
        v = dict(DEFAUT)
    # La copie conforme : ses vraies répliques passent AVANT mes exemples
    # inventés. Si le jeu change ses dialogues, sa voix ici suit toute seule.
    v["repliques_du_jeu"] = repliques_du_jeu()
    return v


def enregistrer(d: dict) -> dict:
    """N'écrit que les champs connus : le portail ne peut pas injecter n'importe
    quoi dans le prompt du personnage."""
    base = charger()
    for k in ("nom", "identite", "ton", "modele"):
        if k in d and isinstance(d[k], str):
            base[k] = d[k][:1200]
    if isinstance(d.get("regles"), list):
        base["regles"] = [str(x)[:200] for x in d["regles"][:10]]
    if isinstance(d.get("exemples"), list):
        base["exemples"] = [
            {"joueur": str(e.get("joueur", ""))[:200],
             "merlin": str(e.get("merlin", ""))[:400]}
            for e in d["exemples"][:6] if isinstance(e, dict)]
    try:
        VOIX.parent.mkdir(parents=True, exist_ok=True)
        VOIX.write_text(json.dumps(base, ensure_ascii=False, indent=1), encoding="utf-8")
    except Exception:
        pass
    return base


def prompt(v: dict | None = None) -> str:
    """La voix, mise en prompt. Les exemples pèsent plus que les consignes :
    un e4b imite bien mieux qu'il n'obéit."""
    v = v or charger()
    bouts = [v["identite"], "", f"TON : {v['ton']}", ""]
    if v.get("regles"):
        bouts.append("RÈGLES :")
        bouts += [f"- {r}" for r in v["regles"]]
        bouts.append("")
    # Ses VRAIES répliques d'abord — c'est ce qui fait la copie conforme. Un
    # petit modèle imite bien mieux qu'il n'obéit : deux phrases authentiques
    # pèsent plus lourd que dix consignes de style.
    if v.get("repliques_du_jeu"):
        bouts.append("VOICI CE QUE TU DIS DANS LE JEU — c'est TA voix, garde-la :")
        bouts += [f"« {r} »" for r in v["repliques_du_jeu"][:5]]
        bouts.append("")
    if v.get("exemples"):
        bouts.append("AINSI RÉPONDS-TU :")
        for e in v["exemples"]:
            bouts.append(f"— {e.get('joueur','')}")
            bouts.append(f"— {e.get('merlin','')}")
        bouts.append("")
    bouts.append("Réponds maintenant, en restant Merlin.")
    return "\n".join(bouts)


def apercu() -> dict:
    """Ce que le portail affiche pour régler la voix."""
    v = charger()
    return {"voix": v, "prompt": prompt(v),
            "taille_prompt": len(prompt(v)) // 4,
            "fichier": str(VOIX)}


if __name__ == "__main__":
    if "--prompt" in sys.argv:
        print(prompt())
    else:
        a = apercu()
        print(f"Voix de Merlin — {a['taille_prompt']} tokens environ\n")
        print(a["prompt"])
