#!/usr/bin/env python3
"""Patch v31.1 — priorité du fil (issue > lookahead > arc) + amorçage Vif sous le voile.

Appliqué par le workflow patch-v31-1 sur un checkout de feat/practices-docs.
Chaque remplacement doit matcher EXACTEMENT UNE fois — sinon échec fort, rien n'est écrit.
Diagnostic source : validation 6 beats du 2026-08-19 — beats 1-2 seuls au secours
(amorçage du Vif jamais placé avant la première pose) et 0 lookahead servie (l'arc
occupait le moteur en continu, le prefetch cédait en silence).
"""
import pathlib
import sys

OLD_NATIVE_1 = "func is_busy() -> bool:\n\treturn _busy\n\n\nfunc _process"
NEW_NATIVE_1 = (
    "func is_busy() -> bool:\n\treturn _busy\n\n\n"
    "## L'étiquette de la génération EN COURS (\"\" si le moteur est libre). Le lookahead s'en sert\n"
    "## pour ne préempter QUE l'arc — jamais une issue, jamais l'intro (priorité du fil, v31.1).\n"
    "func label_en_cours() -> String:\n\treturn _current_label if _busy else \"\"\n\n\nfunc _process"
)

OLD_SC_AMORCE = (
    "func _amorcer_vif(mn: Node) -> void:\n"
    "\tvar dl: int = Time.get_ticks_msec() + 120000\n"
    "\twhile mn.is_busy() and Time.get_ticks_msec() < dl:\n"
    "\t\tawait get_tree().create_timer(0.5).timeout\n"
    "\tif mn.est_vif_pret():\n"
    "\t\tawait mn.amorcer_prefixe(MerlinPromptBuilder.SYSTEM_PREFIX, \"vif\",\n"
    "\t\t\t\tMerlinPromptBuilder.tete_issue(RICHESSE_ISSUE))"
)
NEW_SC_AMORCE = (
    "# IDEMPOTENT (v31.1) : l'ouverture appelle aussi cet amorçage sous le voile — deux chemins,\n"
    "# une seule lecture de la tête.\n"
    "var _vif_amorce_fait: bool = false\n\n\n"
    "func _amorcer_vif(mn: Node) -> void:\n"
    "\tif _vif_amorce_fait:\n\t\treturn\n"
    "\tvar dl: int = Time.get_ticks_msec() + 120000\n"
    "\twhile mn.is_busy() and Time.get_ticks_msec() < dl:\n"
    "\t\tawait get_tree().create_timer(0.5).timeout\n"
    "\tif _vif_amorce_fait:\n"
    "\t\treturn  # amorcé par l'autre chemin pendant notre attente\n"
    "\tif mn.est_vif_pret() and not mn.is_busy():\n"
    "\t\tawait mn.amorcer_prefixe(MerlinPromptBuilder.SYSTEM_PREFIX, \"vif\",\n"
    "\t\t\t\tMerlinPromptBuilder.tete_issue(RICHESSE_ISSUE))\n"
    "\t\t_vif_amorce_fait = true"
)

OLD_SC_OUVERTURE = (
    "func prepare_arc_ouverture(scenario: Dictionary) -> void:\n"
    "\tawait _prepare_arc(scenario, 1)\n"
)
NEW_SC_OUVERTURE = (
    "func prepare_arc_ouverture(scenario: Dictionary) -> void:\n"
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

OLD_SC_PREFETCH = (
    "\tvar mn: Node = _mn()\n"
    "\tif mn == null or not mn.is_ready() or mn.is_busy():\n"
    "\t\treturn  # le moteur travaille (issue en vol ?) : cette scène viendra de l'arc, tant pis\n"
    "\t_scene_jit_qn = qn"
)
NEW_SC_PREFETCH = (
    "\tvar mn: Node = _mn()\n"
    "\tif mn == null or not mn.is_ready():\n"
    "\t\treturn\n"
    "\t_scene_jit_qn = qn\n"
    "\t# PRIORITÉ DU FIL (validation 6 beats du 2026-08-19 : 0 lookahead servie — l'arc écrivait\n"
    "\t# ses tranches en continu et le `return` silencieux d'ici cédait à chaque fois). La règle\n"
    "\t# décidée : issue > lookahead > arc. Une issue en vol se RESPECTE (on attend qu'elle rende\n"
    "\t# la place) ; une tranche d'arc se PRÉEMPTE — pour l'arc, une collision n'est pas un échec,\n"
    "\t# son budget d'horloge la fera revenir quand le moteur sera libre.\n"
    "\tif mn.is_busy():\n"
    "\t\tvar lab: String = str(mn.label_en_cours()) if mn.has_method(\"label_en_cours\") else \"\"\n"
    "\t\tif lab.begins_with(\"arc\"):\n"
    "\t\t\t_arc_cede_au_fil = true\n"
    "\t\t\tmn.cancel()\n"
    "\t\tvar dl_moteur: int = Time.get_ticks_msec() + 30000\n"
    "\t\twhile mn.is_busy() and Time.get_ticks_msec() < dl_moteur:\n"
    "\t\t\tawait get_tree().create_timer(0.5).timeout\n"
    "\t\tif mn.is_busy():\n"
    "\t\t\t_scene_jit_qn = -1\n"
    "\t\t\treturn  # la place n'a pas été rendue à temps : l'arc couvrira ce beat"
)

OLD_SC_DECL = (
    "# que la suite est demandée — deux chantiers concurrents écriraient les mêmes scènes deux fois.\n"
    "var _arc_chantier: bool = false\n"
)
NEW_SC_DECL = (
    "# que la suite est demandée — deux chantiers concurrents écriraient les mêmes scènes deux fois.\n"
    "var _arc_chantier: bool = false\n\n"
    "# La tranche d'arc en vol vient d'être cédée au lookahead (préemption v31.1) : son retour vide\n"
    "# est une collision assumée, PAS un échec du modèle — le compteur d'échecs réels n'y touche pas.\n"
    "var _arc_cede_au_fil: bool = false\n"
)

OLD_SC_BOUCLE = (
    "\t\t\tmorceau = await narrate_arc_tranche(scenario, tags_tranche, types_tranche,\n"
    "\t\t\t\t\tdebut, total, precedent)\n"
    "\t\t\tif morceau.is_empty():\n"
    "\t\t\t\techecs_reels += 1\n"
    "\t\t\t\tprint(\"[MerlinScenario] arc tranche %d-%d : échec réel %d/%d\"\n"
    "\t\t\t\t\t\t% [debut + 1, fin, echecs_reels, ARC_ECHECS_REELS_MAX])"
)
NEW_SC_BOUCLE = (
    "\t\t\tmorceau = await narrate_arc_tranche(scenario, tags_tranche, types_tranche,\n"
    "\t\t\t\t\tdebut, total, precedent)\n"
    "\t\t\tif morceau.is_empty() and _arc_cede_au_fil:\n"
    "\t\t\t\t_arc_cede_au_fil = false\n"
    "\t\t\t\tprint(\"[MerlinScenario] arc tranche %d-%d : cédée au lookahead (collision, pas un échec)\"\n"
    "\t\t\t\t\t\t% [debut + 1, fin])\n"
    "\t\t\telif morceau.is_empty():\n"
    "\t\t\t\techecs_reels += 1\n"
    "\t\t\t\tprint(\"[MerlinScenario] arc tranche %d-%d : échec réel %d/%d\"\n"
    "\t\t\t\t\t\t% [debut + 1, fin, echecs_reels, ARC_ECHECS_REELS_MAX])"
)

REMPLACEMENTS = [
    ("scripts/llm/merlin_native.gd", [(OLD_NATIVE_1, NEW_NATIVE_1)]),
    ("scripts/llm/merlin_scenario.gd", [
        (OLD_SC_AMORCE, NEW_SC_AMORCE),
        (OLD_SC_OUVERTURE, NEW_SC_OUVERTURE),
        (OLD_SC_PREFETCH, NEW_SC_PREFETCH),
        (OLD_SC_DECL, NEW_SC_DECL),
        (OLD_SC_BOUCLE, NEW_SC_BOUCLE),
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
