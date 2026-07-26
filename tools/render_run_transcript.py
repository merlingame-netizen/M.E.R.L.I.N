#!/usr/bin/env python3
"""Rend lisible le transcript d'un run joué dans le moteur.

Consomme le JSON produit par l'instrumentation de `board_narration.gd`
(`MERLIN_TRANSCRIPT=<chemin>`), qui enregistre carte par carte tout ce que le
joueur a sous les yeux et tout ce que le moteur résout derrière.

Le document produit sépare strictement deux plans :

  À L'ÉCRAN   — ce que le joueur lit réellement : HUD, texte de carte, libellés
                des trois options. Rien d'autre ne lui est montré.
  EN COULISSES— ce que le moteur applique sans le dire : effets attachés à
                l'option, réputations de faction, tags, dés du destin,
                modificateur de marchand.

Cette séparation est le cœur de la revue de game design : un joueur ne peut
arbitrer que sur ce qu'il voit.

Usage :
  python tools/render_run_transcript.py --input run_transcript.json \
      --out docs/30_jdr/RUN_TRANSCRIPT.md
"""

from __future__ import annotations

import argparse
import json
from pathlib import Path

ACT_LABEL = {
    "standard": "Standard",
    "shop": "Marchand",
    "event": "Événement",
    "boss": "Climax",
}

FACTIONS = ["druides", "anciens", "korrigans", "niamh", "ankou"]


def effects_fr(effects: list) -> str:
    if not effects:
        return "aucun effet"
    parts = []
    for e in effects:
        t = e.get("type", "?")
        amt = e.get("amount")
        if t == "ADD_REPUTATION":
            parts.append(f"réputation {e.get('faction', '?')} {amt:+d}")
        elif t == "HEAL_LIFE":
            parts.append(f"vie +{amt}")
        elif t == "DAMAGE_LIFE":
            parts.append(f"vie −{amt}")
        elif t == "ADD_ANAM":
            parts.append(f"Anam {amt:+d}")
        elif t == "ADD_ESSENCE":
            parts.append(f"essence {amt:+d}")
        elif t in ("ADD_TAG", "REMOVE_TAG"):
            parts.append(f"{'ajoute' if t == 'ADD_TAG' else 'retire'} le marqueur « {e.get('tag', '?')} »")
        elif t in ("CREATE_PROMISE", "PROMISE"):
            parts.append(f"promesse « {e.get('promise_id', e.get('description', '?'))} »")
        else:
            parts.append(f"{t} {amt if amt is not None else ''}".strip())
    return " · ".join(parts)


def diff_factions(before: dict, after: dict) -> str:
    deltas = []
    for f in FACTIONS:
        b, a = int(before.get(f, 0)), int(after.get(f, 0))
        if a != b:
            deltas.append(f"{f} {a - b:+d} (→ {a})")
    return " · ".join(deltas) if deltas else "aucun changement"


def render(data: dict) -> str:
    entries = data.get("entrees", [])
    seq = data.get("sequence_actes", [])
    L: list = []

    L.append("# Run joué dans le moteur — transcript intégral")
    L.append("")
    L.append("> Produit par l'instrumentation de `scripts/board_narration/board_narration.gd` "
             "(`MERLIN_TRANSCRIPT=<chemin>`) pendant un run réel en autoplay "
             "(`MERLIN_AUTOPLAY=1`), puis rendu par `tools/render_run_transcript.py`. "
             "Aucun élément n'est reconstitué à la main.")
    L.append("")
    L.append(f"**Biome** : {data.get('biome', '?')} · "
             f"**Séquence d'actes** : {' → '.join(ACT_LABEL.get(a, a) for a in seq)} · "
             f"**Issue** : {data.get('issue', '?')} · "
             f"**Cartes jouées** : {data.get('cartes_jouees', 0)} · "
             f"**Anam gagné** : {data.get('anam_gagne', 0)}")
    L.append("")
    L.append("Chaque carte est présentée en deux plans : **à l'écran** (ce que le joueur "
             "lit) et **en coulisses** (ce que le moteur applique sans le dire).")
    L.append("")

    start = next((e for e in entries if e.get("evenement") == "debut_run"), None)
    if start:
        h = start.get("hud", {})
        L.append("## Départ")
        L.append("")
        L.append(f"- Vie **{h.get('vie', '?')}/100** · Anam affiché **{h.get('anam_affiche', 0)}**")
        sc = h.get("scenario_actif", "")
        L.append(f"- Scénario sélectionné dans le catalogue : "
                 f"**{sc if sc else 'aucun'}**")
        L.append(f"- Réputations de départ (jamais affichées) : "
                 f"{h.get('factions_backend', {})}")
        L.append("")

    cards = [e for e in entries if e.get("evenement") == "carte_affichee"]
    resols = {e.get("acte_index"): e for e in entries if e.get("evenement") == "resolution"}

    for c in cards:
        idx = c.get("acte_index")
        h = c.get("hud", {})
        demande, servi = c.get("acte_type_demande", "?"), c.get("acte_type_servi", "?")
        titre = ACT_LABEL.get(demande, demande)
        L.append(f"## Carte {idx} — acte « {titre} »")
        L.append("")
        L.append("### À l'écran")
        L.append("")
        L.append(f"| HUD | valeur |")
        L.append(f"|---|---|")
        L.append(f"| Compteur | {h.get('compteur_cartes', '?')} |")
        L.append(f"| Vie | {h.get('vie', '?')}/100 |")
        L.append(f"| Anam | {h.get('anam_affiche', 0)} |")
        L.append("")
        L.append("Texte de la carte :")
        L.append("")
        txt = (c.get("texte") or "").strip()
        for line in txt.split("\n"):
            L.append(f"> {line}" if line.strip() else ">")
        L.append("")
        dial = (c.get("dialogue_merlin") or "").strip()
        if dial:
            L.append(f"Merlin : *« {dial} »*")
            L.append("")
        L.append("Les trois options, telles qu'elles s'affichent :")
        L.append("")
        for i, o in enumerate(c.get("options_visibles", [])):
            L.append(f"{i + 1}. **{o.get('label', '')}**")
        L.append("")

        L.append("### En coulisses")
        L.append("")
        if demande != servi:
            L.append(f"- ⚠ L'acte demandé était « {demande} » mais la carte servie est de type "
                     f"« {servi} » — le pool ne contient aucune carte pour cet acte.")
        L.append(f"- Carte tirée : `{c.get('carte_id', '?')}`")
        L.append("- Effets attachés à chaque option, **invisibles pour le joueur** :")
        for i, o in enumerate(c.get("options_visibles", [])):
            L.append(f"  {i + 1}. {effects_fr(o.get('effets_caches', []))}")
        r = resols.get(idx)
        if r:
            ha, hd = r.get("hud_apres_choix", {}), r.get("hud_apres_des_du_destin", {})
            L.append(f"- Choix retenu par l'autoplay : option {int(r.get('option_choisie', -1)) + 1} "
                     f"— « {r.get('label_choisi', '')} »")
            L.append(f"- Vie après résolution : {ha.get('vie', '?')}/100 "
                     f"(avant : {h.get('vie', '?')})")
            L.append(f"- Réputations après le choix : "
                     f"{diff_factions(h.get('factions_backend', {}), ha.get('factions_backend', {}))}")
            L.append(f"- Dé du destin (lancé après chaque carte hors climax) : "
                     f"{diff_factions(ha.get('factions_backend', {}), hd.get('factions_backend', {}))}")
            mod = r.get("modificateur_marchand_actif", "")
            if mod:
                L.append(f"- Modificateur de marchand actif : `{mod}`")
            tags = hd.get("tags_actifs", [])
            if tags:
                L.append(f"- Marqueurs actifs : {tags}")
        L.append("")

    end = next((e for e in entries if e.get("evenement") == "fin_run"), None)
    if end:
        h = end.get("hud", {})
        L.append("## Fin de run")
        L.append("")
        L.append(f"- Issue : **{end.get('issue', '?')}**")
        L.append(f"- Vie finale : **{h.get('vie', '?')}/100**")
        L.append(f"- Anam gagné sur ce run : **{end.get('anam_gagne', 0)}**")
        L.append(f"- Réputations finales (jamais montrées au joueur) : "
                 f"{h.get('factions_backend', {})}")
        L.append("")

    L.append("## Ce que le joueur ne voit jamais")
    L.append("")
    L.append("Relevé directement sur le HUD instrumenté : seuls **trois** éléments sont "
             "affichés — le compteur de cartes, la vie et l'Anam. Ne sont montrés à "
             "aucun moment :")
    L.append("")
    L.append("- les réputations des cinq factions (`_refresh_hud` : « aucun affichage HUD »), "
             "alors que presque chaque option en modifie une ;")
    L.append("- les effets attachés aux options, y compris les dégâts et les soins ;")
    L.append("- le dé du destin, qui modifie une faction au hasard après chaque carte ;")
    L.append("- le scénario sélectionné dans le catalogue, ses ancres et ses drapeaux ;")
    L.append("- les marqueurs, promesses et modificateurs de marchand actifs.")
    L.append("")
    return "\n".join(L)


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--input", required=True)
    ap.add_argument("--out", default=None)
    args = ap.parse_args()

    data = json.load(open(args.input, encoding="utf-8"))
    md = render(data)
    if args.out:
        Path(args.out).write_text(md, encoding="utf-8")
        print(f"Transcript rendu : {args.out}")
    else:
        print(md)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
