#!/usr/bin/env python3
"""Patch v35 — l'enchaînement d'abord : lookahead porté par le beat, pont d'action,
cœurs 3+1. Décisions Maxime 2026-08-20 matin. Échec fort si ancre non unique."""
import pathlib
import sys


def exact(texte: str, vieux: str, neuf: str, nom: str) -> str:
    n = texte.count(vieux)
    if n != 1:
        sys.exit("ECHEC %s : motif trouve %d fois (attendu 1) : %r" % (nom, n, vieux[:80]))
    return texte.replace(vieux, neuf)


# ============ merlin_scenario.gd ============
p = pathlib.Path("scripts/llm/merlin_scenario.gd")
t = p.read_text(encoding="utf-8")

# A1 — la scène écrite vit DANS le beat (fix racine du lookahead jamais servi)
t = exact(t,
    '\t_scene_cache[qn] = {"texte": texte, "tags": tags}\n'
    '\tprint("[MerlinScenario] lookahead — scène %d prête (%d car.)" % [qn, texte.length()])\n',
    '\t_scene_cache[qn] = {"texte": texte, "tags": tags}\n'
    '\t# v35 — LA SCÈNE VIT DANS LE BEAT : le cache latéral par qn ne coïncidait JAMAIS avec la\n'
    '\t# clé relue par build_situation (0 lookahead servie en 4 parties — le bug racine de\n'
    '\t# « pourquoi une hutte ensuite ? »). Le beat est une RÉFÉRENCE du scénario de la run :\n'
    '\t# ce qu\'on y écrit, la présentation le retrouve — sans aucune clé à accorder.\n'
    '\tbeat["scene_lookahead"] = texte\n'
    '\tbeat["scene_lookahead_tags"] = (tags as Array).duplicate() if tags is Array else []\n'
    '\tprint("[MerlinScenario] lookahead — scène %d prête (%d car.)" % [qn, texte.length()])\n',
    "A1-beat-borne")

# A2 — garde anti-doublon : le beat déjà servi par une scène écrite
t = exact(t,
    "\tif _scene_cache.has(qn) or _scene_jit_qn == qn:\n"
    "\t\treturn\n",
    '\tif str(beat.get("scene_lookahead", "")) != "" or _scene_cache.has(qn) or _scene_jit_qn == qn:\n'
    "\t\treturn\n",
    "A2-garde")

# A3 — build_situation lit la scène dans le beat AVANT le cache et l'arc
t = exact(t,
    '\tvar qn_beat: int = int(beat.get("qn", beat.get("n", 1)))\n'
    "\tif _scene_cache.has(qn_beat):\n"
    "\t\tvar entree: Dictionary = _scene_cache[qn_beat]\n"
    '\t\tnarration = str(entree.get("texte", ""))\n'
    '\t\trequired = (entree.get("tags", []) as Array).duplicate()\n'
    '\t\tprovenance = "lookahead"\n',
    '\t# v35 — la scène lookahead se lit DANS le beat (fix racine : les clés de cache ne\n'
    '\t# coïncidaient jamais). Le cache par qn reste en second regard (harnais hors-jeu).\n'
    '\tvar qn_beat: int = int(beat.get("qn", beat.get("n", 1)))\n'
    '\tif str(beat.get("scene_lookahead", "")) != "":\n'
    '\t\tnarration = str(beat.get("scene_lookahead", ""))\n'
    '\t\trequired = (beat.get("scene_lookahead_tags", []) as Array).duplicate()\n'
    '\t\tprovenance = "lookahead"\n'
    "\telif _scene_cache.has(qn_beat):\n"
    "\t\tvar entree: Dictionary = _scene_cache[qn_beat]\n"
    '\t\tnarration = str(entree.get("texte", ""))\n'
    '\t\trequired = (entree.get("tags", []) as Array).duplicate()\n'
    '\t\tprovenance = "lookahead"\n',
    "A3-lecture")

# A4 — l'arc REPATIENTE quand une scène lookahead attend d'écrire (inversion de file)
t = exact(t,
    "\t\t\tvar mn_a: Node = _mn()\n"
    "\t\t\tif mn_a == null or not mn_a.is_ready() \\\n"
    '\t\t\t\t\tor (mn_a.est_occupe("conteur") if mn_a.has_method("est_occupe") else mn_a.is_busy()):\n'
    "\t\t\t\tawait get_tree().create_timer(1.0).timeout\n"
    "\t\t\t\tcontinue  # voie conteur occupée : on repatiente, ce n'est PAS un échec\n",
    "\t\t\tvar mn_a: Node = _mn()\n"
    "\t\t\t# v35 — une scène lookahead qui attend d'écrire passe DEVANT l'arc (inversion de\n"
    "\t\t\t# file, jamais d'annulation — leçon v31.1) : l'arc cède son tour, pas sa tranche.\n"
    "\t\t\tif _scene_jit_qn != -1 \\\n"
    "\t\t\t\t\tor mn_a == null or not mn_a.is_ready() \\\n"
    '\t\t\t\t\tor (mn_a.est_occupe("conteur") if mn_a.has_method("est_occupe") else mn_a.is_busy()):\n'
    "\t\t\t\tawait get_tree().create_timer(1.0).timeout\n"
    "\t\t\t\tcontinue  # scène lookahead en attente ou voie occupée : on repatiente\n",
    "A4-file")

# B1 — le pont dit l'ACTION, jamais le degré
t = exact(t,
    "\t# N3-V1 (2026-07-06) : PONT VISIBLE. Le LLM perd la course >95% du temps, donc on RESTAURE un pont\n"
    "\t# procédural (retiré en R140 car alors générique) mais désormais ANCRÉ (degré, biome, momentum). Posé\n"
    "\t# ici : build_situation le prépose à la narration du beat n>1 (fallback presque toujours affiché).\n"
    '\t_run_thread["bridge"] = _compose_bridge(degree, _run_biome())\n',
    "\t# v35 — LE PONT DIT L'ACTION, jamais le degré (Maxime 2026-08-20 : « ne pas faire écho au\n"
    "\t# degré de réussite mais une suite logique à l'action »). Geste réel + locomotion neutre.\n"
    '\t_run_thread["bridge"] = _compose_pont_action(action, _run_biome())\n',
    "B1-note")

# B2 — le banc de locomotions neutres + le compositeur du pont d'action
t = exact(t,
    "# N3-V1 : TON du pont selon le momentum (bornes MerlinRun : sombre <= -2, élan >= +2, neutre entre).\n",
    "# v35 — locomotions de biome NEUTRES (aucun écho du degré) pour le pont d'action.\n"
    "const LOCOMOTION_BY_BIOME: Dictionary = {\n"
    '\t"foret": [\n'
    '\t\t"vous reprenez entre les troncs,",\n'
    '\t\t"vous vous enfoncez plus avant sous le couvert,",\n'
    '\t\t"vous suivez le sentier qui se poursuit sous les branches,",\n'
    "\t],\n"
    '\t"falaises": [\n'
    '\t\t"vous longez la corniche,",\n'
    '\t\t"vous reprenez le fil du bord,",\n'
    '\t\t"vous gagnez la roche suivante,",\n'
    "\t],\n"
    "}\n"
    "\n"
    "\n"
    "# v35 — le pont reconstruit sur l'ACTION réelle : « Vous avez trouvé les mots ; vous reprenez\n"
    "# entre les troncs, ». Le degré n'y apparaît jamais. Gist vide (1er beat) → ancien banc.\n"
    "func _compose_pont_action(action: String, biome: String) -> String:\n"
    '\tif action.strip_edges() == "":\n'
    '\t\treturn _compose_bridge("reussite", biome)\n'
    "\tvar affichage: Dictionary = {\n"
    '\t\t"avez trouve les mots": "avez trouvé les mots",\n'
    '\t\t"avez tenu bon sans ceder": "avez tenu bon sans céder",\n'
    '\t\t"avez appele l\'ombre": "avez appelé l\'ombre",\n'
    "\t}\n"
    "\tvar act_aff: String = str(affichage.get(action, action))\n"
    '\tvar pool: Array = LOCOMOTION_BY_BIOME.get(biome, LOCOMOTION_BY_BIOME["foret"])\n'
    "\tvar loco: String = str(pool[_rng.randi_range(0, pool.size() - 1)])\n"
    '\treturn "Vous %s ; %s" % [act_aff, loco]\n'
    "\n"
    "\n"
    "# N3-V1 : TON du pont selon le momentum (bornes MerlinRun : sombre <= -2, élan >= +2, neutre entre).\n",
    "B2-compositeur")

# B3 — aucun pont devant une scène lookahead (elle enchaîne d'elle-même)
t = exact(t,
    "\t\telse:\n"
    '\t\t\tvar bridge: String = str(_run_thread.get("bridge", "")).strip_edges()\n'
    '\t\t\tif bridge != "":\n',
    '\t\telif provenance != "lookahead":\n'
    "\t\t\t# v35 — une scène lookahead ENCHAÎNE d'elle-même (écrite en connaissant l'issue) :\n"
    "\t\t\t# aucun pont ne s'y prépose (la suite logique, pas l'écho — Maxime 2026-08-20).\n"
    '\t\t\tvar bridge: String = str(_run_thread.get("bridge", "")).strip_edges()\n'
    '\t\t\tif bridge != "":\n',
    "B3-silence")

p.write_text(t, encoding="utf-8")
print("OK merlin_scenario.gd")

# ============ merlin_native.gd — cœurs 3+1 ============
p = pathlib.Path("scripts/llm/merlin_native.gd")
t = p.read_text(encoding="utf-8")

t = exact(t,
    "const FILS_PARTAGE: int = 2\n",
    "const FILS_PARTAGE: int = 2  # (v33 — conservé pour référence des mesures)\n"
    "# v35 — asymétrie du duo : le Vif écrit ce que le joueur ATTEND (issues), 3 fils ; le\n"
    "# Conteur (scènes/arc, personne n'attend devant) continue sur 1. Bande passante mesurée\n"
    "# v33 : 3 fils ~ 90 % du débit solo — l'issue attendue passe de 40-80 s à ~25-35 s.\n"
    "const FILS_VIF_DUO: int = 3\n"
    "const FILS_CONTEUR_DUO: int = 1\n",
    "C1-constantes")

t = exact(t,
    "\t\tif deux:\n"
    "\t\t\tm.set_thread_count(FILS_PARTAGE, _fils_plein())\n"
    "\t\telse:\n",
    "\t\tif deux:\n"
    '\t\t\tm.set_thread_count(FILS_VIF_DUO if c == "vif" else FILS_CONTEUR_DUO, _fils_plein())\n'
    "\t\telse:\n",
    "C2-partage")

p.write_text(t, encoding="utf-8")
print("OK merlin_native.gd")
print("v35 applique")
