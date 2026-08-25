#!/usr/bin/env python3
"""Patch v47 — le fantome de tuile : les deux ensembles fusionnent enfin.

Maxime (2026-08-24) : « une animation de fusion avancee tres dynamique [...] qui fusionne les
deux ensembles ». Or une seule carte volait : le TRAIT etait aspire au centre, l'ACTION restait
une tuile permanente qui pulse sur place (v11-W2, regle conservee). v47 fait voler une COPIE :
un node NEUF (doctrine ghost v10.13.1, jamais un reparent), detachee de la tuile, qui converge
avec le trait, fusionne et eclate avec lui. La tuile reelle ne bouge pas d'un pixel.

La sonde du geste gagne un 4e controle : le fantome doit apparaitre dans le layer (node
« FantomeTuile ») et porter le VERBE joue. Et la validation (parse check + sonde) vit
desormais dans le patcheur lui-meme : la session de pilotage a perdu son shell, la VM est
muette — plus personne d'autre ne pouvait executer Godot avant livraison."""
import pathlib
import sys


def exact(texte, vieux, neuf, nom):
    n = texte.count(vieux)
    if n != 1:
        sys.exit("ECHEC %s : motif trouve %d fois (attendu 1) : %r" % (nom, n, vieux[:90]))
    return texte.replace(vieux, neuf)


# ═══ 1) merlin_fx.gd — le fantome se detache de la tuile et vole avec le trait ═══
p = pathlib.Path("scripts/game/merlin_fx.gd")
t = p.read_text(encoding="utf-8")

# F1 — le membre : la tuile d'origine, fournie par l'appelant.
t = exact(t,
    "var _verdict_cb: Callable = Callable()  # N4-P1 (chantier 2b) : stinger de degré, joué PAR le dé au halo\n",
    "var _verdict_cb: Callable = Callable()  # N4-P1 (chantier 2b) : stinger de degré, joué PAR le dé au halo\n"
    "# v47 (Maxime 2026-08-24) — la TUILE D'ACTION d'origine. Elle ne vole JAMAIS (v11-W2 : tuile\n"
    "# permanente, elle pulse sur place) : si elle est fournie, une COPIE — un node NEUF, doctrine\n"
    "# ghost v10.13.1, jamais un reparent — se detache d'elle et converge avec le trait.\n"
    "var _tuile_origine: Control = null\n",
    "F1-membre")

# F2 — la signature de play() : la tuile en dernier, optionnelle (debug F12 et sonde passent sans).
t = exact(t,
    "static func play(host: Control, res: Dictionary, played: Array, card_views: Array, ready: Callable,\n"
    "\t\tverdict: Callable = Callable()) -> MerlinFx:\n"
    "\tvar fx: MerlinFx = MerlinFx.new()\n"
    "\tfx._res = res\n"
    "\tfx._played = played\n"
    "\tfx._card_views = card_views\n"
    "\tfx._ready_pred = ready\n"
    "\tfx._verdict_cb = verdict\n",
    "static func play(host: Control, res: Dictionary, played: Array, card_views: Array, ready: Callable,\n"
    "\t\tverdict: Callable = Callable(), tuile: Control = null) -> MerlinFx:\n"
    "\tvar fx: MerlinFx = MerlinFx.new()\n"
    "\tfx._res = res\n"
    "\tfx._played = played\n"
    "\tfx._card_views = card_views\n"
    "\tfx._ready_pred = ready\n"
    "\tfx._verdict_cb = verdict\n"
    "\tfx._tuile_origine = tuile\n",
    "F2-signature")

# F3 — la naissance du fantome, juste apres le reparentage des vues, avant la Phase 1.
# Insere en TETE du rang : l'ACTION d'abord, le TRAIT ensuite — l'ordre du combo. Les phases 1
# (convergence) et 2 (explosion) iterent card_views : le fantome vole et eclate avec le reste,
# sans une ligne de plus.
t = exact(t,
    "\t\tcv.position = orig\n"
    "\t\tcv.z_index = 100 + i\n"
    "\t\tcv.mouse_filter = Control.MOUSE_FILTER_IGNORE\n"
    "\n"
    "\t# === Phase 1 — Rassemblement ===",
    "\t\tcv.position = orig\n"
    "\t\tcv.z_index = 100 + i\n"
    "\t\tcv.mouse_filter = Control.MOUSE_FILTER_IGNORE\n"
    "\n"
    "\t# v47 — LE FANTOME DE TUILE : « une animation qui fusionne les deux ensembles » (Maxime).\n"
    "\t# La tuile d'action reste a sa place et pulse (v11-W2) ; sa COPIE — un node neuf, jamais\n"
    "\t# un reparent (doctrine ghost v10.13.1) — se detache et converge avec le trait.\n"
    "\tif _tuile_origine != null and is_instance_valid(_tuile_origine) and _tuile_origine.is_inside_tree():\n"
    "\t\tvar fantome: Panel = Panel.new()\n"
    "\t\tfantome.name = \"FantomeTuile\"\n"
    "\t\tfantome.mouse_filter = Control.MOUSE_FILTER_IGNORE\n"
    "\t\tfantome.size = _tuile_origine.size\n"
    "\t\tfantome.pivot_offset = _tuile_origine.size / 2.0\n"
    "\t\tfantome.z_index = 99\n"
    "\t\tvar sb_f: StyleBoxFlat = StyleBoxFlat.new()\n"
    "\t\tsb_f.bg_color = MerlinVisual.CREAM\n"
    "\t\tsb_f.set_corner_radius_all(8)\n"
    "\t\tsb_f.set_border_width_all(3)\n"
    "\t\tsb_f.border_color = MerlinVisual.GOLD\n"
    "\t\tfantome.add_theme_stylebox_override(\"panel\", sb_f)\n"
    "\t\tvar verbe_lbl: Label = Label.new()\n"
    "\t\tverbe_lbl.text = str(_res.get(\"meca_verb\", \"\"))\n"
    "\t\tverbe_lbl.set_anchors_preset(Control.PRESET_FULL_RECT)\n"
    "\t\tverbe_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER\n"
    "\t\tverbe_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER\n"
    "\t\tverbe_lbl.add_theme_color_override(\"font_color\", MerlinVisual.INK)\n"
    "\t\tverbe_lbl.add_theme_font_size_override(\"font_size\", 30)\n"
    "\t\tverbe_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE\n"
    "\t\tfantome.add_child(verbe_lbl)\n"
    "\t\tadd_child(fantome)\n"
    "\t\tfantome.position = _tuile_origine.global_position\n"
    "\t\t# En TETE du rang : l'ACTION d'abord, le TRAIT ensuite — l'ordre du combo.\n"
    "\t\tcard_views.insert(0, fantome)\n"
    "\n"
    "\t# === Phase 1 — Rassemblement ===",
    "F3-fantome")

p.write_text(t, encoding="utf-8")

# ═══ 2) merlin_game.gd — le call-site passe la tuile (callables hisses en variables) ═══
p = pathlib.Path("scripts/game/merlin_game.gd")
t = p.read_text(encoding="utf-8")

t = exact(t,
    "\tvar fx: MerlinFx = MerlinFx.play(self, res, played_cards, vues_du_combo, func() -> bool:\n"
    "\t\treturn not wait_worth or sc.is_resolution_ready(played_cards, res) \\\n"
    "\t\t\tor not sc.is_resolution_incoming(played_cards, res),\n"
    "\t\tfunc() -> void:\n"
    "\t\t\tif is_instance_valid(self):  # review P1 HIGH-1 : le dé (hébergé hors layer) peut survivre à la scène\n"
    "\t\t\t\t_play_seal_audio(deg))\n",
    "\t# v47 : les deux callables sont hisses en variables — une lambda multiligne suivie d'un\n"
    "\t# autre argument est un terrain de parse fragile, et la TUILE passe desormais derriere\n"
    "\t# elles : sa copie-fantome vole dans la fusion, la tuile reelle continue de pulser sur place.\n"
    "\tvar fx_pret: Callable = func() -> bool:\n"
    "\t\treturn not wait_worth or sc.is_resolution_ready(played_cards, res) \\\n"
    "\t\t\tor not sc.is_resolution_incoming(played_cards, res)\n"
    "\tvar fx_verdict: Callable = func() -> void:\n"
    "\t\tif is_instance_valid(self):  # review P1 HIGH-1 : le dé (hébergé hors layer) peut survivre à la scène\n"
    "\t\t\t_play_seal_audio(deg)\n"
    "\tvar fx: MerlinFx = MerlinFx.play(self, res, played_cards, vues_du_combo, fx_pret, fx_verdict, tile)\n",
    "G1-call-site")

p.write_text(t, encoding="utf-8")

# ═══ 3) probe_fx_geste.gd — le 4e controle : le fantome apparait et porte le verbe ═══
p = pathlib.Path("tools/probe_fx_geste.gd")
t = p.read_text(encoding="utf-8")

t = exact(t,
    "var _reduit_ratio_min: float = 2.0\n",
    "var _reduit_ratio_min: float = 2.0\n"
    "var _fantome_texte: String = \"\"\n",
    "P1-membre")

t = exact(t,
    "\tawait _verifier_mouvement_reduit(par_verbe, par_id)\n"
    "\n"
    "\tif _fautes.is_empty():\n",
    "\tawait _verifier_mouvement_reduit(par_verbe, par_id)\n"
    "\tawait _verifier_fantome(par_verbe, par_id)\n"
    "\n"
    "\tif _fautes.is_empty():\n",
    "P2-appel")

t = exact(t,
    "# Suit le Label de la phrase pendant toute la vie du layer",
    "# v47 — LE FANTOME DE TUILE : quand la tuile d'action est passee a play(), une copie doit\n"
    "# apparaitre dans le layer (node « FantomeTuile ») et porter le VERBE joue. Un faux Control\n"
    "# tient lieu de tuile : la sonde n'a pas de HUD.\n"
    "func _verifier_fantome(par_verbe: Dictionary, par_id: Dictionary) -> void:\n"
    "\tprint(\"--- fantome de tuile ---\")\n"
    "\tvar faux: Control = Control.new()\n"
    "\tfaux.size = Vector2(260.0, 116.0)\n"
    "\tfaux.position = Vector2(40.0, 500.0)\n"
    "\tadd_child(faux)\n"
    "\tvar combo: Array = [par_verbe[\"OBSERVER\"], par_id[\"regard_percant\"]]\n"
    "\tvar res: Dictionary = MerlinResolution.resolve([\"Sens\"], combo, [], 8, [], 2, 0, 0, \"Exploration\", 0)\n"
    "\tres[\"meca_verb\"] = \"OBSERVER\"\n"
    "\t_fantome_texte = \"\"\n"
    "\tvar toujours_pret: Callable = func() -> bool: return true\n"
    "\tvar fx: MerlinFx = MerlinFx.play(self, res, combo, [], toujours_pret, Callable(), faux)\n"
    "\t_suivre_fantome(fx)\n"
    "\tawait fx.run()\n"
    "\tfaux.queue_free()\n"
    "\tif _fantome_texte == \"\":\n"
    "\t\t_fautes.append(\"fantome : jamais apparu dans le layer\")\n"
    "\telif _fantome_texte != \"OBSERVER\":\n"
    "\t\t_fautes.append(\"fantome : porte « %s » au lieu du verbe joue\" % _fantome_texte)\n"
    "\telse:\n"
    "\t\tprint(\"  fantome vu, verbe « %s » — OK\" % _fantome_texte)\n"
    "\n"
    "\n"
    "# Les compteurs sont des MEMBRES (jamais des locales fermees dans une lambda — capture par\n"
    "# valeur). Suit le node du fantome tant que le layer vit.\n"
    "func _suivre_fantome(fx: MerlinFx) -> void:\n"
    "\twhile is_instance_valid(fx) and fx.is_inside_tree():\n"
    "\t\tvar f: Node = fx.get_node_or_null(\"FantomeTuile\")\n"
    "\t\tif f != null:\n"
    "\t\t\tfor c in f.get_children():\n"
    "\t\t\t\tif c is Label:\n"
    "\t\t\t\t\t_fantome_texte = (c as Label).text\n"
    "\t\tawait get_tree().process_frame\n"
    "\n"
    "\n"
    "# Suit le Label de la phrase pendant toute la vie du layer",
    "P3-fonctions")

p.write_text(t, encoding="utf-8")

print("v47 applique : fantome de tuile (fx + call-site) + 4e controle dans la sonde.")
