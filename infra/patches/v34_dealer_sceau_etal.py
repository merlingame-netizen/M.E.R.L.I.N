#!/usr/bin/env python3
"""Patch v34 — le ton du dealer, le sceau du geste sûr, l'étal du colporteur, l'équilibre.

Décisions Maxime 2026-08-19 soir : issues 3-5 phrases directes (HoF2) · auto-réussite
sans dé + sceau quand la réussite est acquise · marchand ~40 %/quête · pactes cap +3
avec compteur par quête. Plus : timings par beat dans le journal de sonde.
Échec fort si une ancre n'est pas trouvée exactement une fois — rien n'est écrit.
"""
import pathlib
import sys


def exact(texte: str, vieux: str, neuf: str, nom: str) -> str:
    n = texte.count(vieux)
    if n != 1:
        sys.exit("ECHEC %s : motif trouve %d fois (attendu 1) : %r" % (nom, n, vieux[:80]))
    return texte.replace(vieux, neuf)


# ============ A. merlin_prompt_builder.gd — le ton du dealer ============
p = pathlib.Path("scripts/llm/merlin_prompt_builder.gd")
t = p.read_text(encoding="utf-8")

t = exact(t,
    '\tvar cible_phrases: String = "3 a 4 phrases (5 a 6 si le moment est un Climax ou une reussite eclatante)"\n'
    '\tif richesse == 1:\n'
    '\t\tcible_phrases = "5 a 7 phrases (7 a 8 si le moment est un Climax ou une reussite eclatante)"\n'
    '\telif richesse >= 2:\n',
    '\t# v34 (Maxime : « trop long, trop de figures imagées — style Hand of Fate 2 ») : paliers\n'
    '\t# resserrés — 0 = sec (2-4), 1 = intermédiaire (3-5, DÉFAUT), 2 = riche (inchangé).\n'
    '\tvar cible_phrases: String = "2 a 4 phrases (4 a 5 si le moment est un Climax ou une reussite eclatante)"\n'
    '\tif richesse == 1:\n'
    '\t\tcible_phrases = "3 a 5 phrases (5 a 6 si le moment est un Climax ou une reussite eclatante)"\n'
    '\telif richesse >= 2:\n',
    "A1-cibles")

t = exact(t,
    "Phrases LIEES et CONCRETES, sujets concrets (jamais 'le vide'/'le nom').",
    "TON DIRECT de conteur de jeu de cartes : phrases COURTES et DECLARATIVES, chaque phrase enonce un FAIT (quelqu'un agit, le monde repond). UNE image concrete AU PLUS par issue ; INTERDIT les metaphores filees, le lyrisme et les comparaisons ('comme si', 'tel un', 'pareil a') — sauf UNE, breve, si le moment est un Climax. Phrases LIEES et CONCRETES, sujets concrets (jamais 'le vide'/'le nom').",
    "A2-ton")

t = exact(t,
    "\tvar tok_budget: int = 260 if long_form else 150\n"
    "\tif richesse == 1:\n"
    "\t\ttok_budget = 340 if long_form else 240\n"
    "\telif richesse >= 2:\n",
    "\tvar tok_budget: int = 200 if long_form else 130\n"
    "\tif richesse == 1:\n"
    "\t\ttok_budget = 280 if long_form else 200\n"
    "\telif richesse >= 2:\n",
    "A3-budgets")

t = exact(t,
    "La scene = 3 a 5 phrases CONCRETES (qui, quoi, ou) avec",
    "La scene = 3 a 5 phrases COURTES et CONCRETES (qui, quoi, ou ; une image au plus, pas de lyrisme ni de comparaisons) avec",
    "A4-scene")

t = exact(t,
    "Chaque etape = 3 a 4 phrases CONCRETES (qui, quoi, ou) avec",
    "Chaque etape = 3 a 4 phrases COURTES et CONCRETES (qui, quoi, ou ; une image au plus, pas de lyrisme ni de comparaisons) avec",
    "A5-arc")

t = exact(t,
    "Images celtiques concretes, SANS remplissage",
    "Phrases courtes et directes, images celtiques concretes (une au plus), SANS remplissage ni lyrisme",
    "A6-ouverture")

p.write_text(t, encoding="utf-8")
print("OK merlin_prompt_builder.gd")

# ============ B. merlin_scenario.gd — richesse 1 par défaut ============
p = pathlib.Path("scripts/llm/merlin_scenario.gd")
t = p.read_text(encoding="utf-8")
t = exact(t,
    "const RICHESSE_ISSUE: int = 2",
    "const RICHESSE_ISSUE: int = 1  # v34 : intermédiaire 3-5 phrases directes (Maxime — style HoF2)",
    "B1-richesse")
p.write_text(t, encoding="utf-8")
print("OK merlin_scenario.gd")

# ============ C. merlin_resolution.gd — le geste sûr ============
p = pathlib.Path("scripts/game/merlin_resolution.gd")
t = p.read_text(encoding="utf-8")

t = exact(t,
    "\tvar face: int = die if die >= 2 and die <= 12 else DIE_FALLBACK\n"
    "\tvar synergy_bonus: int = SYN if synergy > 0 else (-SYN if synergy < 0 else 0)\n"
    "\tvar total: int = face + skill_mod + graft_bonus + COVER_PER_TAG * covered_n + synergy_bonus\n"
    "\tvar dc: int = int(DC_BY_DIFF.get(clampi(diff, 1, 3), DC_BY_DIFF[2])) + dc_bonus\n"
    "\tvar margin: int = total - dc\n"
    "\n"
    "\tvar degree: String = _degree_from_margin(margin, face)\n",
    "\tvar synergy_bonus: int = SYN if synergy > 0 else (-SYN if synergy < 0 else 0)\n"
    "\tvar mods: int = skill_mod + graft_bonus + COVER_PER_TAG * covered_n + synergy_bonus\n"
    "\tvar dc: int = int(DC_BY_DIFF.get(clampi(diff, 1, 3), DC_BY_DIFF[2])) + dc_bonus\n"
    "\t# v34 — GESTE SÛR (Maxime 2026-08-19) : si la réussite est acquise MÊME au jet minimal (2),\n"
    "\t# aucun dé — un sceau s'appose (merlin_fx). L'éclatante reste réservée aux VRAIS jets : le\n"
    "\t# risque est le seul chemin vers l'éclat. Déterministe (mêmes entrées → même verdict) →\n"
    "\t# R120 (preview = résolution) tient sans partager d'état. Le sabotage s'applique APRÈS,\n"
    "\t# comme pour un jet : même un geste sûr se laisse polluer par un tag antagoniste.\n"
    "\tvar geste_sur: bool = (2 + mods) >= dc\n"
    "\tvar face: int = die if die >= 2 and die <= 12 else DIE_FALLBACK\n"
    "\tvar total: int = (2 + mods) if geste_sur else (face + mods)\n"
    "\tvar margin: int = total - dc\n"
    "\n"
    "\tvar degree: String = REUSSITE if geste_sur else _degree_from_margin(margin, face)\n",
    "C1-geste-sur")

t = exact(t,
    '\t\t"die": die,\n',
    '\t\t"die": 0 if geste_sur else die,\n'
    '\t\t"geste_sur": geste_sur,\n',
    "C2-retour")

p.write_text(t, encoding="utf-8")
print("OK merlin_resolution.gd")

# ============ D. merlin_fx.gd — le sceau remplace le dé quand le geste est sûr ============
p = pathlib.Path("scripts/game/merlin_fx.gd")
t = p.read_text(encoding="utf-8")

t = exact(t,
    '\tif int(_res.get("die", 0)) >= 1:\n'
    "\t\t# N4-P1 (chantiers 2b/2c/7) : séquence pose → pause 0,35 s → verdict VIT dans MerlinDice.\n",
    '\tif bool(_res.get("geste_sur", false)):\n'
    "\t\t# v34 — GESTE SÛR : pas de dé, un SCEAU runique s'appose (même dramaturgie pose →\n"
    "\t\t# pause → verdict, stinger via le même callback). Doré si le geste tient, sombre si\n"
    "\t\t# un tag antagoniste l'a saboté — le sceau dit le verdict FINAL, jamais un mensonge.\n"
    "\t\tvar sceau_host: Control = self\n"
    "\t\tvar par_s: Node = get_parent()\n"
    "\t\tif par_s is Control and is_instance_valid(par_s):\n"
    "\t\t\tsceau_host = par_s\n"
    '\t\tvar sceau: MerlinDice = MerlinDice.sceau(sceau_host, bool(_res.get("success", false)), _verdict_cb)\n'
    "\t\tawait sceau.done\n"
    "\t\tif not is_inside_tree():\n"
    "\t\t\treturn\n"
    '\telif int(_res.get("die", 0)) >= 1:\n'
    "\t\t# N4-P1 (chantiers 2b/2c/7) : séquence pose → pause 0,35 s → verdict VIT dans MerlinDice.\n",
    "D1-fx-sceau")

p.write_text(t, encoding="utf-8")
print("OK merlin_fx.gd")

# ============ E. merlin_dice.gd — le sceau + pips gravés ============
p = pathlib.Path("scripts/game/merlin_dice.gd")
t = p.read_text(encoding="utf-8")

t = exact(t,
    'var _static_mode: bool = false   # mode INDICE (pres du bouton Resoudre) : face « ? », aucun roll\n',
    'var _static_mode: bool = false   # mode INDICE (pres du bouton Resoudre) : face « ? », aucun roll\n'
    'var _sceau_mode: bool = false    # v34 : SCEAU du geste sûr (aucun dé, anneau runique qui s\'appose)\n'
    'var _sceau_t: float = 0.0        # 0-1 : déploiement de l\'anneau du sceau\n',
    "E1-vars")

t = exact(t,
    "# Mode INDICE statique (feedforward « ce choix jettera un de ») : petite face « ? » au lisere de rarete.\n",
    "# v34 — LE SCEAU DU GESTE SÛR : quand la réussite est acquise sans jet (resolve.geste_sur),\n"
    "# aucun dé — un anneau runique s'appose (pose → micro-pause → verdict via le même callback\n"
    "# que le jet). Doré si le geste tient (`tenu`), sombre si le sabotage l'a dégradé : le sceau\n"
    "# dit le verdict FINAL. Même cycle de vie que roll() : `await sceau.done`, fondu auto.\n"
    "static func sceau(parent: Control, tenu: bool, on_verdict: Callable = Callable()) -> MerlinDice:\n"
    "\tvar d: MerlinDice = MerlinDice.new()\n"
    "\td._sceau_mode = true\n"
    "\td._success = tenu\n"
    "\td._on_verdict = on_verdict\n"
    "\td.custom_minimum_size = Vector2(SIZE_PX, SIZE_PX)\n"
    "\td.size = Vector2(SIZE_PX, SIZE_PX)\n"
    "\td.mouse_filter = Control.MOUSE_FILTER_IGNORE\n"
    "\td.z_index = 30\n"
    "\tparent.add_child(d)\n"
    "\tvar vp: Vector2 = parent.get_viewport_rect().size\n"
    "\td.position = Vector2(vp.x * 0.5 - SIZE_PX * 0.5, vp.y * 0.19 - SIZE_PX * 0.5)\n"
    "\td.pivot_offset = Vector2(SIZE_PX, SIZE_PX) * 0.5\n"
    "\td._run_sceau()\n"
    "\treturn d\n"
    "\n"
    "\n"
    "func _run_sceau() -> void:\n"
    "\tvar m: float = MerlinVisual.motion()\n"
    '\tMerlinAudio.play_sfx("card_pick", 0.9)\n'
    "\t_settled = true\n"
    "\tmodulate.a = 0.0\n"
    "\tscale = Vector2(1.55, 1.55)\n"
    "\tvar ain: Tween = create_tween().set_parallel(true)\n"
    '\tain.tween_property(self, "modulate:a", 1.0, 0.22 * m)\n'
    '\tain.tween_property(self, "scale", Vector2.ONE, 0.30 * m).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)\n'
    "\tvar grow: Tween = create_tween()\n"
    "\tgrow.tween_method(func(v: float) -> void:\n"
    "\t\t_sceau_t = v\n"
    "\t\tqueue_redraw(), 0.0, 1.0, 0.35 * m)\n"
    "\tif grow.is_running():\n"
    "\t\tawait grow.finished\n"
    "\tawait get_tree().create_timer(PAUSE_READ_S * m).timeout\n"
    "\tif not is_inside_tree():\n"
    "\t\tdone.emit()  # jamais de softlock amont (même garde que le jet, R148)\n"
    "\t\treturn\n"
    "\tif _on_verdict.is_valid():\n"
    "\t\t_on_verdict.call()\n"
    "\tvar halo_tw: Tween = create_tween()\n"
    "\thalo_tw.tween_method(_set_halo, 0.0, 1.0, 0.18 * m)\n"
    "\thalo_tw.tween_method(_set_halo, 1.0, 0.75, 0.30 * m)\n"
    "\tawait get_tree().create_timer(0.15 * m).timeout\n"
    "\tdone.emit()\n"
    "\tif halo_tw.is_running():\n"
    "\t\tawait halo_tw.finished\n"
    "\tif is_inside_tree():\n"
    "\t\tawait get_tree().create_timer(0.5 * m).timeout\n"
    "\t_fade_out()\n"
    "\n"
    "\n"
    "# Mode INDICE statique (feedforward « ce choix jettera un de ») : petite face « ? » au lisere de rarete.\n",
    "E2-sceau")

t = exact(t,
    "\t# Mode INDICE : petite pastille « ? » au lisere de rarete (langage R133, inchange).\n",
    "\t# v34 — SCEAU du geste sûr : anneau runique qui se déploie, huit crans gravés, halo au verdict.\n"
    "\tif _sceau_mode:\n"
    "\t\tvar rs: float = s.x * 0.42\n"
    "\t\tvar scol: Color = MerlinVisual.GOLD if _success else Color(0.40, 0.29, 0.22)\n"
    "\t\tif _halo > 0.0:\n"
    "\t\t\tdraw_circle(half, rs * (1.35 + 0.25 * _halo), Color(scol.r, scol.g, scol.b, 0.16 * _halo))\n"
    "\t\t\tdraw_circle(half, rs * (1.08 + 0.16 * _halo), Color(scol.r, scol.g, scol.b, 0.26 * _halo))\n"
    "\t\tif _sceau_t > 0.02:\n"
    "\t\t\tdraw_arc(half, rs * _sceau_t, 0.0, TAU, 48, scol, 3.0, true)\n"
    "\t\t\tdraw_arc(half, rs * 0.78 * _sceau_t, 0.0, TAU, 40, Color(scol.r, scol.g, scol.b, 0.7), 1.5, true)\n"
    "\t\t\tfor i in range(8):\n"
    "\t\t\t\tvar a: float = TAU * float(i) / 8.0 - TAU * 0.25\n"
    "\t\t\t\tvar p1: Vector2 = half + Vector2(cos(a), sin(a)) * rs * 0.78 * _sceau_t\n"
    "\t\t\t\tvar p2: Vector2 = half + Vector2(cos(a), sin(a)) * rs * _sceau_t\n"
    "\t\t\t\tdraw_line(p1, p2, scol, 2.0, true)\n"
    "\t\tif _sceau_t > 0.85:\n"
    "\t\t\tdraw_circle(half, rs * 0.15, Color(scol.r, scol.g, scol.b, 0.9))\n"
    "\t\treturn\n"
    "\n"
    "\t# Mode INDICE : petite pastille « ? » au lisere de rarete (langage R133, inchange).\n",
    "E3-draw-sceau")

t = exact(t,
    "\tfor p in _pips(face):\n"
    "\t\tdraw_circle(center + Vector2(p.x * off, p.y * off), pr, ink)\n",
    "\tfor p in _pips(face):\n"
    "\t\tvar pc: Vector2 = center + Vector2(p.x * off, p.y * off)\n"
    "\t\tdraw_circle(pc, pr, ink)\n"
    "\t\t# v34 — pip GRAVÉ : fin anneau autour du point, façon os travaillé.\n"
    "\t\tdraw_arc(pc, pr * 1.55, 0.0, TAU, 12, Color(ink.r, ink.g, ink.b, 0.30), 1.0, true)\n"
    "\t# v34 — nervure intérieure discrète (gravure sobre, charte procédurale).\n"
    "\tdraw_arc(center, DIE_HALF * 0.86, 0.0, TAU, 24, Color(bc.r, bc.g, bc.b, 0.22), 1.0, true)\n",
    "E4-pips")

p.write_text(t, encoding="utf-8")
print("OK merlin_dice.gd")

# ============ F. merlin_run.gd — pactes cap +3 par quête ============
p = pathlib.Path("scripts/game/merlin_run.gd")
t = p.read_text(encoding="utf-8")

t = exact(t,
    "var conversions_this_run: int = 0\n",
    "var conversions_this_run: int = 0\n"
    "# v34 (Maxime : 3 runs sur 4 mouraient par l'escalade +1→+6) : le PRIX du pacte suit un compteur\n"
    "# PAR QUÊTE et plafonne à +3 — la corruption redevient une pente, plus un mur. Additif (R108).\n"
    "var conversions_this_quest: int = 0\n",
    "F1-var")

t = exact(t,
    "func next_convert_cost() -> int:\n"
    "\treturn conversions_this_run + 1\n",
    "func next_convert_cost() -> int:\n"
    "\t# v34 : min(compteur de la QUÊTE + 1, 3) — décision Maxime 2026-08-19 (cap +3, reset/quête).\n"
    "\treturn mini(conversions_this_quest + 1, 3)\n",
    "F2-cout")

t = exact(t,
    "\tconversions_this_run += 1\n",
    "\tconversions_this_run += 1\n"
    "\tconversions_this_quest += 1\n",
    "F3-increment")

t = exact(t,
    "\tcoup_de_pouce_exercised = 0\n",
    "\tcoup_de_pouce_exercised = 0\n"
    "\tconversions_this_quest = 0\n"
    "\tmarchand_vu_quete = -1\n",
    "F4-newrun")

t = exact(t,
    "\t\tinfo_achetee_this_quest = false\n"
    "\t\tcoup_de_pouce_used_this_quest = false\n",
    "\t\tinfo_achetee_this_quest = false\n"
    "\t\tcoup_de_pouce_used_this_quest = false\n"
    "\t\tconversions_this_quest = 0  # v34 : le prix des pactes repart à +1 à chaque quête\n",
    "F5-resetquete")

t = exact(t,
    "var merchant_seen_this_run: bool = false\n",
    "var merchant_seen_this_run: bool = false\n"
    "# v34 : index de la dernière quête où l'étal tiré (~40 %) s'est montré — évite qu'il se répète\n"
    "# à chaque Rencontre de la même quête. Additif (R108, défaut sûr au load).\n"
    "var marchand_vu_quete: int = -1\n",
    "F6-marchand-var")

p.write_text(t, encoding="utf-8")
print("OK merlin_run.gd")

# ============ G. merlin_game.gd — l'étal tiré ~40 %/quête ============
p = pathlib.Path("scripts/game/merlin_game.gd")
t = p.read_text(encoding="utf-8")

t = exact(t,
    '\tvar force_merchant: bool = rencontre_beat and run.rencontre_count_this_run >= 2 and not run.merchant_seen_this_run\n',
    "\t# v34 (décision Maxime : étal aléatoire ~40 %/quête) — tirage DÉTERMINISTE par (titre du\n"
    "\t# scénario, index de quête) : stable au resume, aucun état supplémentaire à persister. Quand\n"
    "\t# le tirage sort, l'étal prend la priorité sur l'offrande à la PREMIÈRE Rencontre de la\n"
    "\t# quête (marchand_vu_quete empêche la répétition). La garantie historique (2e Rencontre du\n"
    "\t# run si jamais vu) reste en filet.\n"
    '\tvar q_marchand: int = int(run.current_beat().get("quest", 0))\n'
    '\tvar titre_m: String = str((run.scenario as Dictionary).get("title", (run.scenario as Dictionary).get("titre", "")))\n'
    '\tvar etal_tire: bool = (absi(hash("etal:%s:%d" % [titre_m, q_marchand])) % 100) < 40\n'
    "\tvar force_merchant: bool = rencontre_beat and ((run.rencontre_count_this_run >= 2 and not run.merchant_seen_this_run) \\\n"
    "\t\t\tor (etal_tire and run.marchand_vu_quete != q_marchand))\n",
    "G1-tirage")

t = exact(t,
    "\tif rencontre_beat and not rencontre_slot_used and not run.ended:\n"
    "\t\t_scene_epoch += 1\n"
    "\t\tawait _present_merchant_stall()\n",
    "\tif rencontre_beat and not rencontre_slot_used and not run.ended:\n"
    "\t\t_scene_epoch += 1\n"
    "\t\trun.marchand_vu_quete = q_marchand  # v34 : un seul étal par quête tirée\n"
    "\t\tawait _present_merchant_stall()\n",
    "G2-marque")

p.write_text(t, encoding="utf-8")
print("OK merlin_game.gd")

# ============ H. probe_partie_journal.gd — timings + étal ============
p = pathlib.Path("tools/probe_partie_journal.gd")
t = p.read_text(encoding="utf-8")

t = exact(t,
    '\t\t"beats": [], "cliches": [], "incidents": [], "ok": false,\n',
    '\t\t"beats": [], "cliches": [], "incidents": [], "etals": [], "ok": false,\n',
    "H1-journal")

t = exact(t,
    '\t\t"index": idx + 1,\n',
    '\t\t"index": idx + 1,\n'
    '\t\t"t_pres_ms": Time.get_ticks_msec(),\n',
    "H2-tpres")

t = exact(t,
    '\td["degre"] = str(run.last_degree)\n',
    '\td["degre"] = str(run.last_degree)\n'
    '\t# v34 — le TEMPS de chaque beat (frise de la chronique) + les compteurs de la génération\n'
    '\t# d\'issue (cerveau, durées) et le verdict mécanique (geste sûr, total/DC).\n'
    '\td["t_res_ms"] = Time.get_ticks_msec()\n'
    '\td["duree_beat_s"] = float(int(d["t_res_ms"]) - int(d.get("t_pres_ms", d["t_res_ms"]))) / 1000.0\n'
    '\tvar mn_m: Node = root.get_node_or_null("/root/MerlinNative")\n'
    '\tif mn_m != null and mn_m.has_method("last_metrics"):\n'
    '\t\td["gen"] = (mn_m.last_metrics() as Dictionary).duplicate()\n'
    '\tvar g_res: Node = current_scene\n'
    '\tif g_res != null and ("_pending_res" in g_res) and g_res._pending_res is Dictionary:\n'
    '\t\tvar pres: Dictionary = g_res._pending_res\n'
    '\t\td["geste_sur"] = bool(pres.get("geste_sur", false))\n'
    '\t\td["total"] = int(pres.get("total", 0))\n'
    '\t\td["dc"] = int(pres.get("dc", 0))\n',
    "H3-tres")

t = exact(t,
    "\t\tif game._draft_active:\n"
    "\t\t\tawait create_timer(0.4).timeout\n",
    "\t\tif game._merchant_active:\n"
    "\t\t\t# v34 — l'étal du colporteur : politique d'achat du harnais + journal (offres, bourse).\n"
    "\t\t\tawait create_timer(0.4).timeout\n"
    "\t\t\tif is_instance_valid(game) and game._merchant_active:\n"
    "\t\t\t\tawait _visiter_etal(game, run)\n"
    "\t\t\tawait process_frame\n"
    "\t\t\tcontinue\n"
    "\t\tif game._draft_active:\n"
    "\t\t\tawait create_timer(0.4).timeout\n",
    "H4-boucle")

t = exact(t,
    "func _noter_geste(game: Node) -> void:\n",
    "# v34 — POLITIQUE D'ÉTAL du harnais : soigner si l'intégrité fatigue (≤6), purger si la\n"
    "# corruption monte (≥10), sinon repartir — et tout consigner (offres, bourse, achats).\n"
    "func _visiter_etal(game: Node, run: Node) -> void:\n"
    "\tvar avant: int = int(run.gwenneg)\n"
    "\tvar offres: Array = []\n"
    "\tfor k in game._merchant_items:\n"
    "\t\tvar it: Dictionary = game._merchant_items[k]\n"
    '\t\toffres.append("%s:%d" % [str(it.get("kind", "?")), int(it.get("price", 0))])\n'
    "\tvar achats: Array = []\n"
    "\tfor _essai in range(3):\n"
    '\t\tvar voulu: String = ""\n'
    "\t\tif int(run.integrite) <= 6 and game._merchant_items.has(\"shop_heal\"):\n"
    '\t\t\tvoulu = "shop_heal"\n'
    "\t\telif int(run.corruption) >= 10 and game._merchant_items.has(\"shop_purge\"):\n"
    '\t\t\tvoulu = "shop_purge"\n'
    '\t\tif voulu == "":\n'
    "\t\t\tbreak\n"
    "\t\tvar prix: int = int((game._merchant_items[voulu] as Dictionary).get(\"price\", 0))\n"
    "\t\tif int(run.gwenneg) < prix:\n"
    "\t\t\tbreak\n"
    "\t\tvar cv: Node = _trouver_carte_id(game._hand_box, voulu)\n"
    "\t\tif cv == null:\n"
    "\t\t\tbreak\n"
    "\t\tgame._on_draft_card(cv.card)\n"
    '\t\tachats.append("%s (%d gw)" % [voulu, prix])\n'
    "\t\tawait create_timer(0.3).timeout\n"
    "\t\tif not is_instance_valid(game) or not game._merchant_active:\n"
    "\t\t\tbreak\n"
    "\tif is_instance_valid(game) and game._merchant_active:\n"
    "\t\tgame._on_draft_skip()\n"
    '\t(_journal["etals"] as Array).append({"apres_beat": (_journal["beats"] as Array).size(),\n'
    '\t\t"gwenneg_avant": avant, "gwenneg_apres": int(run.gwenneg),\n'
    '\t\t"offres": offres, "achats": achats})\n'
    "\t_sauver()\n"
    '\t_incident("étal du colporteur : %d offre(s), achats %s, bourse %d→%d"\n'
    "\t\t\t% [offres.size(), str(achats), avant, int(run.gwenneg)])\n"
    "\n"
    "\n"
    "# v34 — retrouve la VUE de carte dont l'id est exactement `id_voulu` (étal : shop_heal...).\n"
    "func _trouver_carte_id(box: Node, id_voulu: String) -> Node:\n"
    "\tif box == null:\n"
    "\t\treturn null\n"
    "\tfor c in box.get_children():\n"
    '\t\tif not ("card" in c) or c.card == null:\n'
    "\t\t\tcontinue\n"
    '\t\tvar cid: String = ""\n'
    '\t\tif c.card is Object and ("id" in c.card):\n'
    "\t\t\tcid = str(c.card.id)\n"
    "\t\telif c.card is Dictionary:\n"
    '\t\t\tcid = str((c.card as Dictionary).get("id", ""))\n'
    "\t\tif cid == id_voulu:\n"
    "\t\t\treturn c\n"
    "\treturn null\n"
    "\n"
    "\n"
    "func _noter_geste(game: Node) -> void:\n",
    "H5-etal")

p.write_text(t, encoding="utf-8")
print("OK probe_partie_journal.gd")
print("v34 « ton du dealer + sceau + étal + équilibre » appliqué")
