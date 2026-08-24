#!/usr/bin/env python3
"""Patch v43 — le carnet du Voyageur + le re-essai qui garde sa première version.

Le Voyageur SE SOUVIENT — mais uniquement de ce qui est écrit au carnet (bible §6 R166).
Carnet vide = première venue, aucun passé. Le carnet est court (3 entrées max) : la
leçon v42.1 (contexte 2048) interdit d'alourdir les prompts sans compter."""
import pathlib
import sys


def exact(texte, vieux, neuf, nom):
    n = texte.count(vieux)
    if n != 1:
        sys.exit("ECHEC %s : motif trouve %d fois (attendu 1) : %r" % (nom, n, vieux[:90]))
    return texte.replace(vieux, neuf)


# ═══ 1. La CHRONIQUE garde le carnet ═══
p = pathlib.Path("scripts/game/merlin_chronicle.gd")
t = p.read_text(encoding="utf-8")

t = exact(t,
    '\t"tuto_proposed": false, "tuto_done": false, "tuto_rearmed": false,\n}\n',
    '\t"tuto_proposed": false, "tuto_done": false, "tuto_rearmed": false,\n'
    '\t# v43 — LE CARNET : les trois dernières traversées, en JSON. C\'est la SEULE\n'
    '\t# source d\'un passé pour le récit (bible §6 R166 : « échos des anciens runs »).\n'
    '\t"carnet": "",\n}\n',
    "K1-defaults")

t = exact(t,
    'static func record_end(end_type: String, scenario_title: String, integrite: int, corruption: int, faction: String = "", pilier: String = "", voie: String = "") -> void:\n',
    'static func record_end(end_type: String, scenario_title: String, integrite: int, corruption: int, faction: String = "", pilier: String = "", voie: String = "", entree: Dictionary = {}) -> void:\n',
    "K2-signature")

t = exact(t,
    '\tcfg.set_value(SECTION, "last_run_iso", Time.get_datetime_string_from_system())\n'
    '\tcfg.save(PREFS_PATH)\n',
    '\tcfg.set_value(SECTION, "last_run_iso", Time.get_datetime_string_from_system())\n'
    '\t# v43 — LE CARNET : cette traversée rejoint les deux précédentes. Trois suffisent :\n'
    '\t# le récit doit pouvoir s\'y référer, pas réciter une biographie.\n'
    '\tif not entree.is_empty():\n'
    '\t\tvar pages: Array = carnet_lire()\n'
    '\t\tpages.push_front(entree)\n'
    '\t\twhile pages.size() > 3:\n'
    '\t\t\tpages.pop_back()\n'
    '\t\tcfg.set_value(SECTION, "carnet", JSON.stringify(pages))\n'
    '\tcfg.save(PREFS_PATH)\n',
    "K3-ecriture")

t = exact(t,
    '# Horodate la VISITE courante',
    '# v43 — Le carnet, relu par le récit. Jamais d\'exception : un carnet illisible\n'
    '# vaut un carnet vide, et un carnet vide veut dire « première venue ».\n'
    'static func carnet_lire() -> Array:\n'
    '\tvar cfg: ConfigFile = ConfigFile.new()\n'
    '\tcfg.load(PREFS_PATH)\n'
    '\tvar brut: String = str(cfg.get_value(SECTION, "carnet", ""))\n'
    '\tif brut.strip_edges() == "":\n'
    '\t\treturn []\n'
    '\tvar v: Variant = JSON.parse_string(brut)\n'
    '\treturn (v as Array) if v is Array else []\n'
    '\n'
    '\n'
    '# Horodate la VISITE courante',
    "K4-lecture")

p.write_text(t, encoding="utf-8")
print("OK merlin_chronicle.gd")

# ═══ 2. Le JEU écrit la page à la fin de la partie ═══
p = pathlib.Path("scripts/game/merlin_game.gd")
t = p.read_text(encoding="utf-8")

t = exact(t,
    '\tMerlinChronicle.record_end(_end_type, title, int(run.get("integrite")), int(run.get("corruption")), faction, pilier, voie_nom)\n',
    '\t# v43 — LA PAGE DU CARNET : ce que le Voyageur a VRAIMENT vécu ici. C\'est la seule\n'
    '\t# matière dont le récit disposera pour évoquer un passé — court, factuel, vérifiable.\n'
    '\tvar page: Dictionary = {\n'
    '\t\t"t": title, "f": _end_type,\n'
    '\t\t"i": int(run.get("integrite")), "c": int(run.get("corruption")),\n'
    '\t\t"p": (run.get("pnj_rencontres") as Array).slice(0, 3) if run.get("pnj_rencontres") is Array else [],\n'
    '\t\t"a": (run.get("faits_marquants") as Array).slice(0, 3) if run.get("faits_marquants") is Array else [],\n'
    '\t}\n'
    '\tMerlinChronicle.record_end(_end_type, title, int(run.get("integrite")), int(run.get("corruption")), faction, pilier, voie_nom, page)\n',
    "G1-page")

p.write_text(t, encoding="utf-8")
print("OK merlin_game.gd")

# ═══ 3. Les PROMPTS lisent le carnet ═══
p = pathlib.Path("scripts/llm/merlin_prompt_builder.gd")
t = p.read_text(encoding="utf-8")

t = exact(t,
    'static func scene_jit(',
    '# v43 — LE CARNET, DIT AU MODELE. Le Voyageur SE SOUVIENT (décision Maxime), mais\n'
    '# uniquement de ces pages : elles sont écrites par le code à la fin de chaque partie,\n'
    '# jamais par le modèle. Carnet vide = première venue, et l\'interdiction reprend.\n'
    'static func bloc_carnet() -> String:\n'
    '\tvar pages: Array = MerlinChronicle.carnet_lire()\n'
    '\tif pages.is_empty():\n'
    '\t\treturn REGLE_PASSE\n'
    '\tvar fins: Dictionary = {"accomplissement": "menee au bout", "mort": "finie dans la mort", "corrompu": "finie dans la corruption"}\n'
    '\tvar lignes: PackedStringArray = []\n'
    '\tfor e in pages:\n'
    '\t\tif not (e is Dictionary):\n'
    '\t\t\tcontinue\n'
    '\t\tvar d: Dictionary = e\n'
    '\t\tvar bout: String = "- « %s », %s (integrite %d, corruption %d)" % [\n'
    '\t\t\tstr(d.get("t", "une quete")), str(fins.get(str(d.get("f", "")), "laissee en chemin")),\n'
    '\t\t\tint(d.get("i", 0)), int(d.get("c", 0))]\n'
    '\t\tvar pnj: Array = (d.get("p", []) as Array) if d.get("p") is Array else []\n'
    '\t\tif not pnj.is_empty():\n'
    '\t\t\tbout += " ; croises : " + ", ".join(PackedStringArray(pnj))\n'
    '\t\tvar faits: Array = (d.get("a", []) as Array) if d.get("a") is Array else []\n'
    '\t\tif not faits.is_empty():\n'
    '\t\t\tbout += " ; " + ", ".join(PackedStringArray(faits))\n'
    '\t\tlignes.append(bout)\n'
    '\tif lignes.is_empty():\n'
    '\t\treturn REGLE_PASSE\n'
    '\treturn "\\nCE QUE LE VOYAGEUR A DEJA VECU ICI (seule source autorisee d\'un passe ; TOUT autre souvenir, dette, faute ou serment est INTERDIT, et personne ne le reconnait au-dela de ces lignes) :\\n" + "\\n".join(lignes)\n'
    '\n'
    '\n'
    '# La même vérité, en une ligne : l\'issue vit dans 2048 tokens (leçon v42.1).\n'
    'static func _regle_passe_issue() -> String:\n'
    '\tvar pages: Array = MerlinChronicle.carnet_lire()\n'
    '\tif pages.is_empty():\n'
    '\t\treturn REGLE_PASSE_BREVE\n'
    '\tvar d: Dictionary = (pages[0] as Dictionary) if pages[0] is Dictionary else {}\n'
    '\treturn "\\nLe Voyageur a deja traverse ces bois une fois (« %s »). RIEN d\'autre de son passe n\'existe : aucun autre souvenir, aucune dette, aucun serment." % str(d.get("t", "une quete"))\n'
    '\n'
    '\n'
    'static func scene_jit(',
    "P1-carnet")

t = exact(t,
    '\treturn ex + REGLE_PASSE_BREVE + "\\nREGLES : Raconte l\'issue a la 2e PERSONNE',
    '\treturn ex + _regle_passe_issue() + "\\nREGLES : Raconte l\'issue a la 2e PERSONNE',
    "P2-issue")

t = exact(t,
    '\tvar usr: String = bloc + LORE_CANON + REGLE_PASSE + "\\nUne quete ne REPARE JAMAIS',
    '\tvar usr: String = bloc + LORE_CANON + bloc_carnet() + "\\nUne quete ne REPARE JAMAIS',
    "P3-selection")

t = exact(t,
    '\tvar usr: String = LORE_CANON + REGLE_PASSE + "\\nQuete proposee au Voyageur',
    '\tvar usr: String = LORE_CANON + bloc_carnet() + "\\nQuete proposee au Voyageur',
    "P4-intro")

p.write_text(t, encoding="utf-8")
print("OK merlin_prompt_builder.gd")

# ═══ 4. Le RE-ESSAI ne jette plus sa première version ═══
p = pathlib.Path("scripts/llm/merlin_scenario.gd")
t = p.read_text(encoding="utf-8")

t = exact(t,
    'var _reso_revous_sig: String = ""  # v40 — signature déjà re-essayée (première phrase sans « Vous »)\n',
    'var _reso_revous_sig: String = ""  # v40 — signature déjà re-essayée (première phrase sans « Vous »)\n'
    'var _reso_reserve: Dictionary = {}  # v43 — prose valide mise de côté avant un re-essai\n',
    "S1-reserve")

t = exact(t,
    '\t\tif not _t0.begins_with("Vous") and _reso_revous_sig != sig and mn.is_ready():\n'
    '\t\t\t_reso_revous_sig = sig\n',
    '\t\tif not _t0.begins_with("Vous") and _reso_revous_sig != sig and mn.is_ready():\n'
    '\t\t\t_reso_revous_sig = sig\n'
    '\t\t\t# v43 — ON NE JETTE JAMAIS UN TEXTE VALIDE : celui-ci n\'est qu\'imparfait. Il\n'
    '\t\t\t# part en réserve et ressortira si la seconde écriture échoue (p59 : un raté\n'
    '\t\t\t# est devenu un banc uniquement parce que la première version avait disparu).\n'
    '\t\t\t_reso_reserve[sig] = prose\n',
    "S2-mise-en-reserve")

t = exact(t,
    '\telse:\n'
    '\t\t_reso_state = "idle"  # échec moteur → take_resolution génèrera (ou retombera sur fallback)\n'
    '\t\tprint("[MerlinScenario] issue — génération VIDE pour %s" % sig)\n',
    '\telif _reso_reserve.has(sig):\n'
    '\t\t# v43 — la seconde écriture n\'a rien donné : la réserve vaut mille fois le banc.\n'
    '\t\t_reso_cache[sig] = _reso_reserve[sig]\n'
    '\t\t_reso_state = "ready"\n'
    '\t\tprint("[MerlinScenario] issue — re-essai vide : la réserve est servie pour %s" % sig)\n'
    '\telse:\n'
    '\t\t_reso_state = "idle"  # échec moteur → take_resolution génèrera (ou retombera sur fallback)\n'
    '\t\tprint("[MerlinScenario] issue — génération VIDE pour %s" % sig)\n',
    "S3-reserve-servie")

p.write_text(t, encoding="utf-8")
print("OK merlin_scenario.gd")
print("v43 applique")
"""marqueur: v43"""
