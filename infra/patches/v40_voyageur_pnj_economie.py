#!/usr/bin/env python3
"""Patch v40 — écriture au Voyageur, colporteur narré, économie visible."""
import pathlib
import sys


def exact(texte, vieux, neuf, nom):
    n = texte.count(vieux)
    if n != 1:
        sys.exit("ECHEC %s : motif trouve %d fois (attendu 1) : %r" % (nom, n, vieux[:80]))
    return texte.replace(vieux, neuf)


# ── merlin_game.gd ──
p = pathlib.Path("scripts/game/merlin_game.gd")
t = p.read_text(encoding="utf-8")

# G2 — la variable du dernier butin
t = exact(t,
    "var _merchant_items: Dictionary = {}\n",
    "var _merchant_items: Dictionary = {}\n"
    "var _gain_gwenneg_recent: int = 0  # v40 — dernier butin, affiché « (+X) » à côté de la bourse\n",
    "G2-var")

# G1 — le butin s'annonce
t = exact(t,
    "\trun.add_gwenneg(run.gwenneg_gain_for_degree(deg) + run.roll_loot(deg))\n",
    "\t# v40 — le butin s'ANNONCE : le gain du beat s'affiche à côté de la bourse (+X),\n"
    "\t# remplacé au butin suivant — l'économie se voit, elle ne se devine plus.\n"
    "\tvar _gain_g: int = run.gwenneg_gain_for_degree(deg) + run.roll_loot(deg)\n"
    "\trun.add_gwenneg(_gain_g)\n"
    "\t_gain_gwenneg_recent = _gain_g\n",
    "G1-butin")

# G3 — la bourse se voit, même vide, et porte le dernier gain
t = exact(t,
    "\tif _bourse_box != null:\n"
    "\t\t_bourse_box.visible = g > 0\n"
    "\tif _bourse_lbl != null:\n"
    "\t\t_bourse_lbl.text = str(g)\n",
    "\tif _bourse_box != null:\n"
    "\t\t# v40 — la bourse se VOIT, même vide (Maxime : « il me manque le compteur de monnaie »).\n"
    "\t\t_bourse_box.visible = true\n"
    "\tif _bourse_lbl != null:\n"
    '\t\t_bourse_lbl.text = (str(g) + " (+%d)" % _gain_gwenneg_recent) if _gain_gwenneg_recent > 0 else str(g)\n',
    "G3-hud")

# G4 — le colporteur arrive dans le récit avant son étal
t = exact(t,
    "\tif cards.is_empty():\n"
    "\t\treturn  # rien a offrir, pas de vitrine vide\n"
    "\t_merchant_active = true\n",
    "\tif cards.is_empty():\n"
    "\t\treturn  # rien a offrir, pas de vitrine vide\n"
    "\t# v40 — LE COLPORTEUR EXISTE DANS LE RÉCIT (bible : des PNJ, pas des écrans) : une\n"
    "\t# arrivée narrée, du banc — instantanée —, écrite à la suite du fil (pattern R128).\n"
    "\tvar _arrivees: Array = [\n"
    '\t\t"Un grelot tinte entre les troncs. Le colporteur pousse sa carriole bâchée jusqu\'à vous, rabat la toile et sourit : « Regarde avant de marcher, Voyageur. Tout se paie en gwenneg. »",\n'
    '\t\t"Une silhouette voûtée attend au bord du sentier, assise sur une malle cerclée de fer. Le colporteur relève son capuchon et tapote le couvercle : « J\'ai ce qu\'il te faut, si ta bourse sait parler. »",\n'
    '\t\t"Des sabots frappent la terre derrière vous. Le colporteur mène une mule chargée de sacoches, s\'arrête, et déroule son tapis sans un mot de trop : « Choisis vite. La brume n\'attend personne. »",\n'
    "\t]\n"
    '\tvar _arr: String = str(_arrivees[absi(hash(str(run.get("gwenneg")) + ":" + str(run.beat_index))) % _arrivees.size()])\n'
    "\tif _situation_text != null:\n"
    "\t\tvar _sc0: int = _situation_text.get_total_character_count()\n"
    '\t\t_typewriter(_situation_text.text.replace("[/center]", "\\n\\n%s[/center]" % _arr), true, _situation_text, _sc0)\n'
    "\t_merchant_active = true\n",
    "G4-colporteur")

p.write_text(t, encoding="utf-8")
print("OK merlin_game.gd")

# ── merlin_scenario.gd ──
p = pathlib.Path("scripts/llm/merlin_scenario.gd")
t = p.read_text(encoding="utf-8")

# S1 — la variable de garde
t = exact(t,
    'var _reso_retry_sig: String = ""  # v35.5 — signature déjà re-essayée après une gen VIDE (1 seul re-essai)\n',
    'var _reso_retry_sig: String = ""  # v35.5 — signature déjà re-essayée après une gen VIDE (1 seul re-essai)\n'
    'var _reso_revous_sig: String = ""  # v40 — signature déjà re-essayée (première phrase sans « Vous »)\n',
    "S1-var")

# S2 — la garde « Vous »
t = exact(t,
    '\tif prose.length() >= 10:\n'
    '\t\t_reso_cache[sig] = prose\n'
    '\t\t_reso_state = "ready"\n',
    '\tif prose.length() >= 10:\n'
    "\t\t# v40 — LA PREMIÈRE PHRASE APPARTIENT AU VOYAGEUR : si elle ne commence pas par\n"
    "\t\t# « Vous » (dérive ~1 beat/partie : scène recopiée ou PNJ en tête), UN re-essai —\n"
    "\t\t# même contrat que le moteur muet (v35.5), jamais deux pour la même combinaison.\n"
    '\t\tvar _t0: String = prose.strip_edges().trim_prefix("[i]").strip_edges()\n'
    '\t\t_t0 = _t0.trim_prefix("*").strip_edges()\n'
    '\t\tif not _t0.begins_with("Vous") and _reso_revous_sig != sig and mn.is_ready():\n'
    '\t\t\t_reso_revous_sig = sig\n'
    '\t\t\t_reso_state = "idle"\n'
    '\t\t\tprint("[MerlinScenario] issue — re-essai (première phrase sans « Vous ») pour %s" % sig)\n'
    '\t\t\tprefetch_resolution(situation, played_cards, res)\n'
    '\t\t\treturn\n'
    '\t\t_reso_cache[sig] = prose\n'
    '\t\t_reso_state = "ready"\n',
    "S2-garde-vous")

p.write_text(t, encoding="utf-8")
print("OK merlin_scenario.gd")

# ── merlin_prompt_builder.gd — sujets abstraits bannis ──
p = pathlib.Path("scripts/llm/merlin_prompt_builder.gd")
t = p.read_text(encoding="utf-8")
t = exact(t,
    "Phrases LIEES et CONCRETES, sujets concrets (jamais 'le vide'/'le nom').",
    "Phrases LIEES et CONCRETES. SUJETS INTERDITS : une abstraction ne fait JAMAIS l'action — 'la sensation', 'une forme', 'la presence', 'le silence', 'l'air', 'la brume' ne sont jamais sujets d'un verbe d'action ; chaque phrase a pour sujet le Voyageur, un personnage, une creature ou un objet NOMME (jamais 'le vide'/'le nom').",
    "B1-sujets")
p.write_text(t, encoding="utf-8")
print("OK merlin_prompt_builder.gd")

# ── tools/probe_partie_journal.gd — gwenneg par beat ──
p = pathlib.Path("tools/probe_partie_journal.gd")
t = p.read_text(encoding="utf-8")
t = exact(t,
    '\td["corruption_apres"] = int(run.corruption)\n',
    '\td["corruption_apres"] = int(run.corruption)\n'
    '\td["gwenneg_apres"] = int(run.get("gwenneg"))  # v40 — la bourse par beat (chroniques)\n',
    "P1-gwenneg")
p.write_text(t, encoding="utf-8")
print("OK probe_partie_journal.gd")
print("v40 applique")
"""marqueur: v40"""
