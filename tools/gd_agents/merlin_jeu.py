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

# Le CALQUE, et rien d'autre. Son identité et son ton ne sont plus écrits ici :
# ils viennent du jeu (voix_du_jeu()). Ce qui reste est un réglage fin, posé
# APRÈS la voix canonique, qui ne peut donc jamais la contredire — il est vide
# par défaut, parce que le jeu se suffit à lui-même.
DEFAUT = {
    "nom": "Merlin",
    "regles": [],
    "exemples": [],
    "modele": "",            # vide = le modèle par défaut du routeur
}


JEU = Path.home() / "workspace" / "merlin-game"
BUILDER = JEU / "scripts" / "llm" / "merlin_prompt_builder.gd"
NATIF = JEU / "scripts" / "llm" / "merlin_native.gd"


def _const_gd(fichier: Path, nom: str) -> str:
    """Lit une constante GDScript. Le jeu EST la source : rien n'est recopié ici,
    donc rien ne peut diverger quand le jeu change."""
    try:
        texte = fichier.read_text(encoding="utf-8", errors="replace")
    except Exception:
        return ""
    m = re.search(rf'^const\s+{nom}\s*:\s*\w+\s*=\s*(.+?)$', texte, re.M)
    if not m:
        return ""
    val = m.group(1).strip()
    if val.startswith('"') and val.endswith('"'):
        return val[1:-1]
    return val.split("#")[0].strip()


def voix_du_jeu() -> str:
    """La voix CANONIQUE : celle que le jeu donne à Merlin, mot pour mot.

    C'est ce qui rend le personnage identique des deux côtés. La voix écrite à la
    main qui vivait ici disait « grave et chaleureux » quand le jeu dit « taquin,
    plus JEUNE que sage, jamais solennel » — presque l'inverse."""
    return _const_gd(BUILDER, "MERLIN_VOICE_PREFIX")


def reglages_du_jeu() -> dict:
    """L'échantillonnage du jeu (merlin_native.gd), lu et non recopié.

    Le régime « créatif » est celui de TOUTES ses prises de parole narratives —
    c'est donc celui d'une conversation."""
    def _f(nom: str, defaut: float) -> float:
        try:
            return float(_const_gd(NATIF, nom))
        except Exception:
            return defaut
    def _i(nom: str, defaut: int) -> int:
        try:
            return int(float(_const_gd(NATIF, nom)))
        except Exception:
            return defaut
    return {"temp": _f("TEMP_CREATIVE", 0.85), "top_p": _f("TOP_P", 0.9),
            "top_k": _i("TOP_K", 40), "repeat_penalty": _f("REPEAT_PENALTY", 1.1),
            "ctx": _i("N_CTX", 2048),
            "predict": _i("MAX_TOK_PROSE", 220) if _const_gd(BUILDER, "MAX_TOK_PROSE") else 220,
            "lu": bool(voix_du_jeu())}


# Le gabarit de chat du jeu (merlin_native.gd:build_prompt). Ollama applique le
# gabarit du modèle au champ `prompt` : pour ne pas le doubler, on l'envoie en
# `raw` avec CETTE chaîne — l'entrée devient identique token pour token.
#
# `<bos>` est AJOUTÉ ici : le jeu ne l'écrit pas parce que llama.cpp le pose
# lui-même à la tokenisation (add_special), tandis qu'Ollama en mode `raw` ne
# pose plus rien. Sans lui, gemma4 rend une suite de chiffres — mesuré :
# « n0101010101010000000000000000067594032… ».
def gabarit(system_text: str, user_text: str) -> str:
    return ("<bos><start_of_turn>user\n%s\n\n%s<end_of_turn>\n<start_of_turn>model\n"
            % (system_text, user_text))


# Marqueurs que gemma4 émet parfois EN TEXTE : le jeu tronque au premier d'entre
# eux (merlin_native.gd:STOP_MARKERS), le portail ne le faisait pas.
STOP_MARKERS = ("<start_of_turn", "</start_of_turn", "<end_of_turn", "</end_of_turn",
                "<turn|", "<|turn", "<|im_", "<eos", "<bos", "<pad", "<unk", "<0x")


def nettoyer(t: str) -> str:
    coupe = -1
    for m in STOP_MARKERS:
        i = t.find(m)
        if i != -1 and (coupe == -1 or i < coupe):
            coupe = i
    if coupe != -1:
        t = t[:coupe]
    for tok in ("<start_of_turn>", "<end_of_turn>", "<bos>", "<eos>", "<pad>", "<unk>"):
        t = t.replace(tok, "")
    return t.strip()


def charger() -> dict:
    try:
        d = json.loads(VOIX.read_text(encoding="utf-8"))
        v = {**DEFAUT, **d} if isinstance(d, dict) else dict(DEFAUT)
    except Exception:
        v = dict(DEFAUT)
    # La voix canonique, lue dans le jeu à CHAQUE appel : elle suit le jeu sans
    # que personne ait à recopier quoi que ce soit.
    v["canon"] = voix_du_jeu()
    return v


def enregistrer(d: dict) -> dict:
    """N'écrit que les champs connus : le portail ne peut pas injecter n'importe
    quoi dans le prompt du personnage."""
    base = charger()
    # `identite` et `ton` ne sont plus réglables : ils appartiennent au jeu. Le
    # portail ne peut qu'AJOUTER (règles, exemples), jamais contredire.
    for k in ("nom", "modele"):
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
    """La voix, mise en prompt : le CANON du jeu d'abord, le calque ensuite.

    L'ordre n'est pas cosmétique. Le prefixe du jeu est ce que Merlin EST ; ce
    que Maxime ajoute depuis le portail est un réglage, et un réglage se lit
    après ce qu'il règle. Les exemples scrapés du code ont disparu : le modèle
    les RECOPIAIT au lieu de s'en inspirer — mesuré, il a resservi mot pour mot
    la réplique de test `MERLIN_VOICE_TEST`."""
    v = v or charger()
    canon = v.get("canon") or voix_du_jeu()
    if not canon:
        # Ne jamais servir une voix d'imitation en silence : si le jeu est
        # introuvable, ça se dit, et ça se voit dans le panneau.
        return ("[voix du jeu introuvable — dépôt du jeu absent de cette machine]\n"
                "Réponds en restant Merlin, l'enchanteur de Brocéliande.")
    bouts = [canon, ""]
    if v.get("regles"):
        bouts.append("RÉGLAGE DU STUDIO (s'ajoute à ce qui précède, ne le contredit pas) :")
        bouts += [f"- {r}" for r in v["regles"]]
        bouts.append("")
    if v.get("exemples"):
        bouts.append("AINSI RÉPONDS-TU :")
        for e in v["exemples"]:
            bouts.append(f"— {e.get('joueur','')}")
            bouts.append(f"— {e.get('merlin','')}")
        bouts.append("")
    return "\n".join(bouts).strip()


def apercu() -> dict:
    """Ce que le portail affiche : la voix du JEU en lecture, le calque en édition,
    et les réglages effectivement appliqués — pour qu'on voie ce qu'on règle."""
    v = charger()
    r = reglages_du_jeu()
    return {"voix": v, "prompt": prompt(v),
            "taille_prompt": len(prompt(v)) // 4,
            "canon": v.get("canon", ""),
            "canon_lu": bool(v.get("canon")),
            "reglages": r,
            "source": str(BUILDER),
            "fichier": str(VOIX)}


if __name__ == "__main__":
    if "--prompt" in sys.argv:
        print(prompt())
    else:
        a = apercu()
        print(f"Voix de Merlin — {a['taille_prompt']} tokens environ\n")
        print(a["prompt"])
