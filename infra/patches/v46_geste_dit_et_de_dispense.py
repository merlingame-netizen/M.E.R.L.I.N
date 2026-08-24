#!/usr/bin/env python3
"""Patch v46 — le geste se DIT, et le de se dispense.

Maxime, 2026-08-24 : « OBSERVER + Le Pressentiment » rendu par « en poussant vos mains
sur leur pierre de basalte » — le modele inventait le geste. v45 lui a donne une regle ;
v46 lui RETIRE la charge : le geste est compose par le CODE (verbe + maniere du trait),
ecrit a la machine entre la fusion et le de. Le modele n'ecrit plus que la SUITE.

Et « des fois juste une difficulte qui demande un niveau de competence dans la competence
action ou en fonction de la rarete de la carte » : la maitrise du verbe et la rarete du
trait achetent de la marge sur le jet MINIMAL — le de se dispense, un sceau s'appose.

Sequence visee (rythme nerveux) : fusion ~1,3 s -> phrase du geste ~2,0 s -> de/sceau ->
issue (qui se termine deja par une phrase de suite, v45). Les ~2 s de la phrase sont
autant de temps gagne pour l'ecriture de l'issue : l'animation PAIE le LLM.
"""
import pathlib
import sys


def exact(texte, vieux, neuf, nom):
    n = texte.count(vieux)
    if n != 1:
        sys.exit("ECHEC %s : motif trouve %d fois (attendu 1) : %r" % (nom, n, vieux[:90]))
    return texte.replace(vieux, neuf)


# ══════════════════════════════════════════════════════════════════════════════════════
# 1) merlin_resolution.gd — la marge sure (maitrise + rarete), la mise, la phrase du geste
# ══════════════════════════════════════════════════════════════════════════════════════
p = pathlib.Path("scripts/game/merlin_resolution.gd")
t = p.read_text(encoding="utf-8")

# ── R1 : les constantes de la marge sure ──────────────────────────────────────────────
t = exact(t,
    "const DIE_FALLBACK: int = 7   # R158 : moyenne de 2d6 (call-sites tools sans de)\n",
    "const DIE_FALLBACK: int = 7   # R158 : moyenne de 2d6 (call-sites tools sans de)\n"
    "\n"
    "# === v46 (Maxime 2026-08-24) — LE DE SE DISPENSE : maitrise du verbe + rarete du trait ===\n"
    "# « des fois juste une difficulte qui demande un niveau de competence dans la competence action\n"
    "# ou en fonction de la rarete de la carte ». Un maitre ne se fait pas defaire par un mauvais de\n"
    "# sur un geste de routine, et une carte rare porte son propre poids : les deux achetent de la\n"
    "# MARGE sur le jet MINIMAL (2), JAMAIS sur le total d'un vrai jet. A talent 0 + trait Commune,\n"
    "# MARGE_SURE = 0 -> le comportement v34 est STRICTEMENT inchange (zero regression mesuree).\n"
    "# L'eclatante reste reservee aux VRAIS jets : dispenser le de ne peut JAMAIS produire un eclat.\n"
    "const SEUIL_MAITRISE: int = 2   # talent (skill_mod) a partir duquel le verbe est maitrise\n"
    "const MARGE_MAITRISE: int = 2   # ... vaut 2 points de de en moins a craindre\n"
    "const MARGE_RARETE: Dictionary = {\"Commune\": 0, \"Rare\": 1, \"\u00c9pique\": 2, \"Mythique\": 3}\n",
    "R1-constantes")

# ── R2 : le geste sur intègre la marge ────────────────────────────────────────────────
t = exact(t,
    "\tvar geste_sur: bool = (2 + mods) >= dc\n"
    "\tvar face: int = die if die >= 2 and die <= 12 else DIE_FALLBACK\n"
    "\tvar total: int = (2 + mods) if geste_sur else (face + mods)\n",
    "\t# v46 : maitrise + rarete s'ajoutent au jet MINIMAL pour decider s'il faut encore jeter.\n"
    "\t# JAMAIS au Climax : le pic de la quete se joue au de, sinon l'eclatante devient\n"
    "\t# inatteignable la ou elle compte le plus (l'eclat n'existe que par le risque, v34).\n"
    "\tvar m_sure: int = 0 if beat_type == \"Climax\" else marge_sure(played_cards, skill_mod)\n"
    "\tvar geste_sur: bool = (2 + mods + m_sure) >= dc\n"
    "\tvar face: int = die if die >= 2 and die <= 12 else DIE_FALLBACK\n"
    "\tvar total: int = (2 + mods + m_sure) if geste_sur else (face + mods)\n",
    "R2-geste-sur")

# ── R3 : la mise + la phrase du geste dans le retour (lues par MerlinFx et le journal) ─
t = exact(t,
    "\t\t\"geste_sur\": geste_sur,\n",
    "\t\t\"geste_sur\": geste_sur,\n"
    "\t\t\"marge_sure\": m_sure,\n"
    "\t\t\"mise\": _mise(geste_sur, m_sure, dc, mods, skill_mod),\n"
    "\t\t\"phrase_geste\": phrase_du_geste(played_cards),\n",
    "R3-retour")

# ── R4 : les helpers, en queue de fichier ─────────────────────────────────────────────
t = exact(t,
    "# Nom canonique d'une carte-like (duck-type). \"\" si inconnu.\n"
    "static func _card_name(c: Variant) -> String:\n",
    "# v46 — MARGE SURE : ce que la maitrise du verbe et la rarete du trait retirent au risque du de.\n"
    "# Talent 0 + trait Commune -> 0 (identique a v34). Statique et pur -> preview = resolution (R120).\n"
    "static func marge_sure(played_cards: Array, skill_mod: int) -> int:\n"
    "\tvar marge: int = MARGE_MAITRISE if skill_mod >= SEUIL_MAITRISE else 0\n"
    "\tvar rare: int = 0\n"
    "\tfor i in range(1, played_cards.size()):\n"
    "\t\trare = maxi(rare, int(MARGE_RARETE.get(_card_rarity(played_cards[i]), 0)))\n"
    "\treturn marge + rare\n"
    "\n"
    "\n"
    "# Rarete d'une carte-like (duck-type), \"Commune\" si inconnue.\n"
    "static func _card_rarity(c: Variant) -> String:\n"
    "\tif c is Object and \"rarity\" in c:\n"
    "\t\treturn str(c.rarity)\n"
    "\tif c is Dictionary and c.has(\"rarity\"):\n"
    "\t\treturn str(c[\"rarity\"])\n"
    "\treturn \"Commune\"\n"
    "\n"
    "\n"
    "# v46 — LA MISE, annoncee AVANT le de (Hands of Fate 2 montre la cible, il ne la cache pas).\n"
    "# Dit l'ENJEU, jamais l'issue : un geste sans jet peut encore etre sabote par un tag antagoniste.\n"
    "static func _mise(geste_sur: bool, m_sure: int, dc: int, mods: int, skill_mod: int) -> String:\n"
    "\tif not geste_sur:\n"
    "\t\tvar s: String = (\"+%d\" % mods) if mods >= 0 else str(mods)\n"
    "\t\treturn \"Difficult\u00e9 %d \u00b7 vos atouts %s\" % [dc, s]\n"
    "\tif m_sure > 0 and skill_mod >= SEUIL_MAITRISE:\n"
    "\t\treturn \"Sans jet \u00b7 ma\u00eetrise du geste\"\n"
    "\tif m_sure > 0:\n"
    "\t\treturn \"Sans jet \u00b7 la carte porte le geste\"\n"
    "\treturn \"Sans jet \u00b7 le geste est acquis\"\n"
    "\n"
    "\n"
    "# === v46 — LA PHRASE DU GESTE, composee par le CODE (jamais par le modele) ===\n"
    "# Le modele avait ecrit « en poussant vos mains sur leur pierre de basalte » sur un OBSERVER +\n"
    "# Pressentiment. Le geste n'est pas une affaire de style : c'est le VERBE joue et la MANIERE du\n"
    "# trait. Le code le DIT, en clair, avant le de — le modele n'ecrit plus que la SUITE. Deterministe\n"
    "# (memes cartes -> meme phrase), zero generation, zero attente : c'est du temps DONNE au LLM.\n"
    "const GESTE_SOCLE: Dictionary = {\n"
    "\t\"OBSERVER\": \"Vous arr\u00eatez votre regard sur ce qui vous fait face\",\n"
    "\t\"AGIR\": \"Vous avancez la main et vous faites le geste\",\n"
    "\t\"COMBATTRE\": \"Vous plantez vos appuis et vous frappez\",\n"
    "\t\"R\u00c9V\u00c9LER\": \"Vous laissez remonter ce que le lieu retient\",\n"
    "\t\"PARLER\": \"Vous parlez, la voix pos\u00e9e\",\n"
    "}\n"
    "\n"
    "# La MANIERE : un tag canon (MerlinTags.to_canon, minuscule sans accent) -> une suite de phrase.\n"
    "# Les 25 concepts-coeur des 6 familles sont couverts : aucun trait ne tombe a vide.\n"
    "const GESTE_MANIERE: Dictionary = {\n"
    "\t\"sens\": \"et rien ne vous \u00e9chappe\",\n"
    "\t\"savoir\": \"avec ce que vous savez d\u00e9j\u00e0 de ces choses\",\n"
    "\t\"memoire\": \"en recoupant ce que vous avez d\u00e9j\u00e0 vu\",\n"
    "\t\"vigilance\": \"sans baisser la garde\",\n"
    "\t\"force\": \"et rien ne vous fera reculer\",\n"
    "\t\"agilite\": \"vite, avant qu'on ne vous arr\u00eate\",\n"
    "\t\"endurance\": \"et vous tiendrez aussi longtemps qu'il faudra\",\n"
    "\t\"finesse\": \"sans rien brusquer\",\n"
    "\t\"empathie\": \"en cherchant d'abord ce que l'autre craint\",\n"
    "\t\"verbe\": \"et vous trouvez les mots qu'il faut\",\n"
    "\t\"ruse\": \"sans montrer ce que vous cherchez vraiment\",\n"
    "\t\"autorite\": \"et personne ici ne vous contredira\",\n"
    "\t\"franchise\": \"sans rien arranger\",\n"
    "\t\"instinct\": \"et vous suivez ce que vous pressentez\",\n"
    "\t\"nature\": \"comme la for\u00eat vous l'a appris\",\n"
    "\t\"vision\": \"et l'image vient avant les mots\",\n"
    "\t\"rituel\": \"et le rite ancien vous guide\",\n"
    "\t\"sacrifice\": \"en acceptant d'y laisser quelque chose\",\n"
    "\t\"equilibre\": \"sans rien rompre\",\n"
    "\t\"mystere\": \"sans chercher \u00e0 tout comprendre\",\n"
    "\t\"vide\": \"et quelque chose manque, en vous\",\n"
    "\t\"glitch\": \"et le geste accroche, une fraction de seconde\",\n"
    "\t\"dissolution\": \"pendant que quelque chose se d\u00e9fait en vous\",\n"
    "\t\"murmure\": \"et une autre voix souffle en m\u00eame temps\",\n"
    "\t\"emprise\": \"et quelque chose d'autre d\u00e9cide avec vous\",\n"
    "}\n"
    "\n"
    "\n"
    "# played_cards[0] = l'ACTION (verbe), le reste = le/les TRAIT(s). \"\" si le call-site n'a pas\n"
    "# d'action reconnue en [0] (harnais legacy) : MerlinFx saute alors la phrase, rythme inchange.\n"
    "static func phrase_du_geste(played_cards: Array) -> String:\n"
    "\tif played_cards.is_empty():\n"
    "\t\treturn \"\"\n"
    "\tvar socle: String = str(GESTE_SOCLE.get(_card_name(played_cards[0]), \"\"))\n"
    "\tif socle == \"\":\n"
    "\t\treturn \"\"\n"
    "\t# La maniere vient du tag du TRAIT que l'action ne porte PAS deja : c'est lui qui ajoute.\n"
    "\tvar deja: Array = []\n"
    "\tfor t0 in _card_tags(played_cards[0]):\n"
    "\t\tdeja.append(MerlinTags.to_canon(str(t0)))\n"
    "\tvar fam: String = _card_family(played_cards[0])\n"
    "\t# 1) le tag du trait qui NOURRIT le verbe (meme famille, non deja porte) : c'est la synergie.\n"
    "\tvar maniere: String = _maniere(played_cards, deja, fam)\n"
    "\tif maniere == \"\":\n"
    "\t\tmaniere = _maniere(played_cards, deja, \"\")   # 2) a defaut, tout tag qui AJOUTE\n"
    "\tif maniere == \"\":\n"
    "\t\tmaniere = _maniere(played_cards, [], \"\")     # 3) repli : meme un tag double donne une maniere\n"
    "\tif maniere == \"\":\n"
    "\t\treturn socle + \".\"\n"
    "\treturn \"%s, %s.\" % [socle, maniere]\n"
    "\n"
    "\n"
    "# `famille` non vide = on n'accepte QUE le tag de cette famille (celui qui nourrit le verbe).\n"
    "static func _maniere(played_cards: Array, exclus: Array, famille: String) -> String:\n"
    "\tfor i in range(1, played_cards.size()):\n"
    "\t\tfor tg in _card_tags(played_cards[i]):\n"
    "\t\t\tvar c: String = MerlinTags.to_canon(str(tg))\n"
    "\t\t\tif not GESTE_MANIERE.has(c) or exclus.has(c):\n"
    "\t\t\t\tcontinue\n"
    "\t\t\tif famille != \"\" and MerlinTags.family_of(c) != famille:\n"
    "\t\t\t\tcontinue\n"
    "\t\t\treturn str(GESTE_MANIERE[c])\n"
    "\treturn \"\"\n"
    "\n"
    "\n"
    "# Nom canonique d'une carte-like (duck-type). \"\" si inconnu.\n"
    "static func _card_name(c: Variant) -> String:\n",
    "R4-helpers")

p.write_text(t, encoding="utf-8")

# ══════════════════════════════════════════════════════════════════════════════════════
# 2) merlin_fx.gd — la phrase s'ecrit a la machine entre la fusion et le de
# ══════════════════════════════════════════════════════════════════════════════════════
p = pathlib.Path("scripts/game/merlin_fx.gd")
t = p.read_text(encoding="utf-8")

# ── F1 : les durees du nouveau temps ──────────────────────────────────────────────────
t = exact(t,
    "const FUSION_SPARK_COUNT: int = 32\n",
    "const FUSION_SPARK_COUNT: int = 32\n"
    "\n"
    "# v46 (Maxime 2026-08-24) — LE TEMPS DU GESTE, entre la fusion et le de. Le joueur LIT ce qu'il\n"
    "# vient de faire (phrase composee par MerlinResolution.phrase_du_geste) avant que le sort ne\n"
    "# tranche : plus aucune coupure entre la pose des cartes et l'issue. Et ces ~2 s sont DONNEES a\n"
    "# l'ecriture de l'issue, qui court deja en fond — l'animation paie le LLM au lieu de l'attendre.\n"
    "const GESTE_ECRITURE: float = 1.60   # frappe machine de la phrase\n"
    "const GESTE_TENUE: float = 0.35      # temps de lecture apres le dernier caractere\n",
    "F1-durees")

# ── F2 : le temps du geste, juste avant la decrue + le de ─────────────────────────────
t = exact(t,
    "\tvar decrue: float = FUSION_DECRUE * m\n",
    "\t# v46 — LE GESTE SE DIT : une phrase composee par le code s'ecrit a la machine, la mise\n"
    "\t# (difficulte, ou « sans jet ») s'allume dessous, PUIS le de part. Rien a ecrire (res legacy,\n"
    "\t# debug F12) -> retour immediat, rythme d'avant strictement conserve.\n"
    "\tawait _ecrire_le_geste(str(_res.get(\"phrase_geste\", \"\")), str(_res.get(\"mise\", \"\")),\n"
    "\t\tglow_col, screen_size)\n"
    "\tif not is_inside_tree():\n"
    "\t\treturn\n"
    "\n"
    "\tvar decrue: float = FUSION_DECRUE * m\n",
    "F2-temps-du-geste")

# ── F3 : le helper d'ecriture ─────────────────────────────────────────────────────────
t = exact(t,
    "# Pr\u00e9dicat inject\u00e9 \u00ab la prose est pr\u00eate \u00bb \u2014 Callable invalide = pr\u00eat (pas de sustain), comme\n",
    "# v46 \u2014 ecrit la phrase du geste a la machine, allume la mise, puis rend la main au de. La phrase\n"
    "# RESTE a l'ecran pendant le de et le sustain : c'est elle qui tient la continuite entre le geste\n"
    "# et l'issue (elle meurt avec le layer). Vide -> retour immediat, zero frame perdue.\n"
    "func _ecrire_le_geste(phrase: String, mise: String, col: Color, screen_size: Vector2) -> void:\n"
    "\tif phrase.strip_edges().is_empty():\n"
    "\t\treturn\n"
    "\tvar m: float = MerlinVisual.motion()\n"
    "\tvar lbl: Label = Label.new()\n"
    "\tlbl.text = phrase\n"
    "\tlbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART\n"
    "\tlbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER\n"
    "\tlbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER\n"
    "\tlbl.mouse_filter = Control.MOUSE_FILTER_IGNORE\n"
    "\tlbl.add_theme_color_override(\"font_color\", MerlinVisual.CREAM)\n"
    "\tlbl.add_theme_font_size_override(\"font_size\", 30)\n"
    "\tlbl.size = Vector2(screen_size.x * 0.72, 104.0)\n"
    "\tlbl.position = Vector2(screen_size.x * 0.14, screen_size.y * 0.42)\n"
    "\tlbl.visible_ratio = 0.0\n"
    "\tadd_child(lbl)\n"
    "\tvar pill: Label = null\n"
    "\tif not mise.strip_edges().is_empty():\n"
    "\t\tpill = Label.new()\n"
    "\t\tpill.text = mise\n"
    "\t\tpill.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER\n"
    "\t\tpill.mouse_filter = Control.MOUSE_FILTER_IGNORE\n"
    "\t\tpill.add_theme_color_override(\"font_color\", col)\n"
    "\t\tpill.add_theme_font_size_override(\"font_size\", 20)\n"
    "\t\tpill.size = Vector2(screen_size.x, 28.0)\n"
    "\t\tpill.position = Vector2(0.0, screen_size.y * 0.42 + 104.0)\n"
    "\t\tpill.modulate.a = 0.0\n"
    "\t\tadd_child(pill)\n"
    "\tif MerlinVisual.reduced_motion:\n"
    "\t\tlbl.visible_ratio = 1.0\n"
    "\t\tif pill != null:\n"
    "\t\t\tpill.modulate.a = 0.90\n"
    "\t\tawait get_tree().create_timer(GESTE_TENUE * 2.0).timeout\n"
    "\t\treturn\n"
    "\tMerlinAudio.play_sfx(\"quill_tick\", 0.70)\n"
    "\tvar frappe: float = GESTE_ECRITURE * m\n"
    "\tvar tw: Tween = create_tween()\n"
    "\ttw.tween_property(lbl, \"visible_ratio\", 1.0, frappe).set_trans(Tween.TRANS_LINEAR)\n"
    "\tif pill != null:\n"
    "\t\ttw.parallel().tween_property(pill, \"modulate:a\", 0.90, frappe * 0.40).set_delay(frappe * 0.60)\n"
    "\t# Meme garde que p3_glow/p4_fade (N4-BUG) : awaiter un tween DEJA fini ne rend jamais la main.\n"
    "\tif tw.is_running():\n"
    "\t\tawait tw.finished\n"
    "\tif not is_inside_tree():\n"
    "\t\treturn\n"
    "\tawait get_tree().create_timer(GESTE_TENUE * m).timeout\n"
    "\n"
    "\n"
    "# Pr\u00e9dicat inject\u00e9 \u00ab la prose est pr\u00eate \u00bb \u2014 Callable invalide = pr\u00eat (pas de sustain), comme\n",
    "F3-helper")

p.write_text(t, encoding="utf-8")

# ══════════════════════════════════════════════════════════════════════════════════════
# 3) probe_partie_journal.gd — la chronique doit MONTRER la phrase et la mise
# ══════════════════════════════════════════════════════════════════════════════════════
p = pathlib.Path("tools/probe_partie_journal.gd")
t = p.read_text(encoding="utf-8")
t = exact(t,
    "\t\td[\"geste_sur\"] = bool(pres.get(\"geste_sur\", false))\n",
    "\t\td[\"geste_sur\"] = bool(pres.get(\"geste_sur\", false))\n"
    "\t\t# v46 : la phrase du geste (composee par le code) et la mise annoncee avant le de.\n"
    "\t\td[\"phrase_geste\"] = str(pres.get(\"phrase_geste\", \"\"))\n"
    "\t\td[\"mise\"] = str(pres.get(\"mise\", \"\"))\n"
    "\t\td[\"marge_sure\"] = int(pres.get(\"marge_sure\", 0))\n",
    "J1-journal")
p.write_text(t, encoding="utf-8")

# ══════════════════════════════════════════════════════════════════════════════════════
# 4) merlin_game.gd — la ligne mecanique ne peut plus annoncer un de qui n'a pas roule
# ══════════════════════════════════════════════════════════════════════════════════════
p = pathlib.Path("scripts/game/merlin_game.gd")
t = p.read_text(encoding="utf-8")
t = exact(t,
    "\tvar line: String = \"%s (%s) \u00b7 2d6 %d %s = %s\" % [clause, reg, face, mods_str, deg_lbl]\n",
    "\t# v46 : un GESTE SUR n'a JAMAIS jete de de — annoncer \u00ab 2d6 7 \u00bb (la face de repli) etait un\n"
    "\t# mensonge a l'ecran, latent depuis v34 et rendu frequent par la dispense maitrise/rarete.\n"
    "\t# On dit alors la MISE (\u00ab Sans jet \u00b7 maitrise du geste \u00bb), la meme qu'a l'animation.\n"
    "\tvar line: String = \"\"\n"
    "\tif bool(res.get(\"geste_sur\", false)):\n"
    "\t\tline = \"%s (%s) \u00b7 %s = %s\" % [clause, reg, str(res.get(\"mise\", \"Sans jet\")), deg_lbl]\n"
    "\telse:\n"
    "\t\tline = \"%s (%s) \u00b7 2d6 %d %s = %s\" % [clause, reg, face, mods_str, deg_lbl]\n",
    "G1-ligne-meca")
p.write_text(t, encoding="utf-8")

print("v46 applique : geste dit par le code, de dispense par maitrise+rarete, journal enrichi.")
