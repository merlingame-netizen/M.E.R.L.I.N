#!/usr/bin/env python3
"""Patch v31.2 — la tête d'issue en DERNIER dans le cache du Vif, et fin de la
tempête d'annulations du lookahead.

Mesuré sur la partie 10 beats du 2026-08-19 (log godot) :
- amorçage vif OK (1055 tok, 16,7 s) puis intro SUR LE VIF → tête évincée :
  1re issue 1450 tok réévalués / 104 s (secours), 2e issue 414 tok / 28 s (servie).
- préemption v31.1 : six « cédée au lookahead », zéro scène livrée, chaque
  annulation repayant l'éval complète de l'arc.
Chaque remplacement doit matcher EXACTEMENT UNE fois — sinon échec fort.
"""
import pathlib
import sys

OLD_OUVERTURE = (
    "\tawait _prepare_arc(scenario, 1)\n"
    "\t# LA TÊTE D'ISSUE DU VIF, amorcée SOUS LE VOILE (validation 6 beats du 2026-08-19 : seuls\n"
    "\t# les beats 1 et 2 sont partis au secours — l'amorçage « quand le moteur sera libre »\n"
    "\t# ne trouvait jamais de place avant la première pose. Ici la place est à nous, et ces\n"
    "\t# ~30 s derrière le voile achètent des premières issues écrites par le modèle).\n"
    "\tawait _laisser_le_moteur_finir()\n"
    "\tvar mn_o: Node = _mn()\n"
    "\tif mn_o != null and mn_o.has_method(\"est_vif_pret\") and mn_o.est_vif_pret():\n"
    "\t\tawait _amorcer_vif(mn_o)\n"
)
NEW_OUVERTURE = "\tawait _prepare_arc(scenario, 1)\n"

OLD_LEGENDE = (
    "\telse:\n"
    "\t\tpush_warning(\"[MerlinScenario] intro — légende NON écrite : le pop-up servira le cadrage en dur\")"
)
NEW_LEGENDE = (
    "\telse:\n"
    "\t\tpush_warning(\"[MerlinScenario] intro — légende NON écrite : le pop-up servira le cadrage en dur\")\n"
    "\t# LA TÊTE D'ISSUE EN DERNIER (v31.2) : l'intro tourne sur le Vif et ÉVINCE la tête de son\n"
    "\t# cache — mesuré : première issue à 1450 tok réévalués (104 s, secours) quand la deuxième,\n"
    "\t# tête recachée, tombe à 414 tok (28 s, servie). On amène donc la tête APRÈS l'intro ;\n"
    "\t# cache intact, le préfixe se réutilise et cet appel ne coûte presque rien.\n"
    "\tawait _laisser_le_moteur_finir()\n"
    "\tvar mn_v: Node = _mn()\n"
    "\tif mn_v != null and mn_v.has_method(\"est_vif_pret\") and mn_v.est_vif_pret() and not mn_v.is_busy():\n"
    "\t\tawait mn_v.amorcer_prefixe(MerlinPromptBuilder.SYSTEM_PREFIX, \"vif\",\n"
    "\t\t\t\tMerlinPromptBuilder.tete_issue(RICHESSE_ISSUE))\n"
    "\t\t_vif_amorce_fait = true"
)

OLD_CANCEL = (
    "\t\tvar lab: String = str(mn.label_en_cours()) if mn.has_method(\"label_en_cours\") else \"\"\n"
    "\t\tif lab.begins_with(\"arc\"):\n"
    "\t\t\t_arc_cede_au_fil = true\n"
    "\t\t\tmn.cancel()\n"
)
NEW_CANCEL = (
    "\t\t# v31.2 — PLUS D'ANNULATION : la préemption produisait une tempête (six tranches\n"
    "\t\t# cédées, zéro scène livrée, chaque annulation repayant l'éval de l'arc). On attend,\n"
    "\t\t# borné ; si l'arc garde la place, il servira — sa continuité de cache vaut plus\n"
    "\t\t# que notre priorité.\n"
)

REMPLACEMENTS = [
    ("scripts/llm/merlin_scenario.gd", [
        (OLD_OUVERTURE, NEW_OUVERTURE),
        (OLD_LEGENDE, NEW_LEGENDE),
        (OLD_CANCEL, NEW_CANCEL),
    ]),
]


def main() -> None:
    for chemin, paires in REMPLACEMENTS:
        p = pathlib.Path(chemin)
        texte = p.read_text(encoding="utf-8")
        for vieux, neuf in paires:
            n = texte.count(vieux)
            if n != 1:
                sys.exit("ECHEC %s : motif trouvé %d fois (attendu 1) : %r" % (chemin, n, vieux[:90]))
            texte = texte.replace(vieux, neuf)
        p.write_text(texte, encoding="utf-8")
        print("OK %s : %d remplacement(s)" % (chemin, len(paires)))


if __name__ == "__main__":
    main()
