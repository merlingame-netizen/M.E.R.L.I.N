#!/usr/bin/env python3
"""Patch v33 « Les Deux Mains » — deux voies parallèles (conteur/vif) + issue streamée.

- merlin_native.gd : tout l'état de génération devient PAR VOIE ; les deux moteurs
  écrivent EN MÊME TEMPS (2+2 cœurs à chaud) ; cancel/quit par voie ; signal
  generation_chunk_voie(cerveau, cumul).
- merlin_scenario.gd : chaque consommateur ne draine que SA voie (issues=vif,
  scènes/arc=conteur).
- merlin_game.gd : au resolve, l'issue se STREAME sous les yeux — le banc en dur
  ne sert plus que si le moteur est MORT.

Deux outils : remplacement EXACT (petits blocs) et remplacement de SPAN entre deux
ancres uniques (gros blocs). Échec fort si une ancre n'est pas trouvée exactement
une fois — rien n'est écrit dans ce cas.
"""
import pathlib
import sys


def exact(texte: str, vieux: str, neuf: str, nom: str) -> str:
    n = texte.count(vieux)
    if n != 1:
        sys.exit("ECHEC %s : motif trouvé %d fois (attendu 1) : %r" % (nom, n, vieux[:80]))
    return texte.replace(vieux, neuf)


def span(texte: str, debut: str, fin: str, neuf: str, nom: str) -> str:
    if texte.count(debut) != 1 or texte.count(fin) != 1:
        sys.exit("ECHEC %s : ancres non uniques (%d/%d)" % (nom, texte.count(debut), texte.count(fin)))
    a = texte.index(debut)
    b = texte.index(fin) + len(fin)
    if a >= b:
        sys.exit("ECHEC %s : ancres inversées" % nom)
    return texte[:a] + neuf + texte[b:]


# ──────────── merlin_native.gd ────────────
p = pathlib.Path("scripts/llm/merlin_native.gd")
t = p.read_text(encoding="utf-8")

# N1 — déclarations d'état → par voie
t = exact(t,
    "var _busy: bool = false\n"
    "var _t_start_ms: int = 0\n"
    "var _last_metrics: Dictionary = {}\n"
    "var _pending_prompt: String = \"\"\n"
    "var _pending_result: Dictionary = {}  # résultat de la génération courante (lu par l'auto-polling)\n"
    "var _result_ready: bool = false\n"
    "var _gen_id: int = 0  # nonce : invalide les callbacks tardifs (après timeout) → anti-corruption\n",
    "# v33 « Les Deux Mains » — TOUT l'état de génération vit PAR VOIE (une par cerveau) : les\n"
    "# deux moteurs sont des instances séparées avec leurs propres fils d'inférence, et les deux\n"
    "# voies écrivent EN MÊME TEMPS (2+2 cœurs via set_thread_count à chaud — _partager_les_coeurs).\n"
    "# id = nonce anti-callback-tardif ; plein = régime demandé (restauré quand la voie redevient seule).\n"
    "const FILS_PARTAGE: int = 2\n"
    "var _voies: Dictionary = {\n"
    "\t\"conteur\": {\"busy\": false, \"label\": \"\", \"t0\": 0, \"prompt\": \"\", \"ready\": false,\n"
    "\t\t\"result\": {}, \"id\": 0, \"plein\": false, \"metrics\": {}},\n"
    "\t\"vif\": {\"busy\": false, \"label\": \"\", \"t0\": 0, \"prompt\": \"\", \"ready\": false,\n"
    "\t\t\"result\": {}, \"id\": 0, \"plein\": false, \"metrics\": {}},\n"
    "}\n"
    "var _last_metrics: Dictionary = {}\n",
    "N1")

# N2 — _gen_moteur/_gen_cerveau disparaissent ; signal de flux par voie + accès moteur
t = exact(t,
    "# Moteur et cerveau de la génération EN COURS (routage par opts.cerveau).\n"
    "var _gen_moteur: Variant = null\n"
    "var _gen_cerveau: String = \"conteur\"\n"
    "signal vif_ready()\n",
    "signal vif_ready()\n"
    "# v33 — flux par voie : (cerveau, texte cumulé). L'ancien generation_chunk reste émis (compat).\n"
    "signal generation_chunk_voie(cerveau: String, texte_cumule: String)\n"
    "\n"
    "\n"
    "func _moteur_de(cerveau: String) -> Variant:\n"
    "\treturn _llm_vif if cerveau == \"vif\" else _llm\n",
    "N2")

# N3 — _peut_dormir
t = exact(t,
    "\treturn not _busy and _load_thread == null and _vif_thread == null\n",
    "\treturn not is_busy() and _load_thread == null and _vif_thread == null\n",
    "N3")

# N4 — mort de moteur : le cerveau devient un paramètre
t = exact(t,
    "func _noter_si_moteur_mort(err: String) -> void:\n",
    "func _noter_si_moteur_mort(err: String, cerveau: String = \"conteur\") -> void:\n",
    "N4a")
t = exact(t,
    "\tif _gen_cerveau == \"vif\":\n",
    "\tif cerveau == \"vif\":\n",
    "N4b")

# N5 — is_busy / label_en_cours → par voie + est_occupe + partage des cœurs
t = exact(t,
    "func is_busy() -> bool:\n"
    "\treturn _busy\n"
    "\n"
    "\n"
    "## L'étiquette de la génération EN COURS (\"\" si le moteur est libre). Le lookahead s'en sert\n"
    "## pour ne préempter QUE l'arc — jamais une issue, jamais l'intro (priorité du fil, v31.1).\n"
    "func label_en_cours() -> String:\n"
    "\treturn _current_label if _busy else \"\"\n",
    "func is_busy() -> bool:\n"
    "\treturn bool(_voies[\"conteur\"][\"busy\"]) or bool(_voies[\"vif\"][\"busy\"])\n"
    "\n"
    "\n"
    "## v33 — occupation d'UNE voie : le prefetch d'issue ne regarde que le Vif, le lookahead\n"
    "## et l'arc ne regardent que le Conteur. is_busy() (OU des deux) reste pour les harnais.\n"
    "func est_occupe(cerveau: String) -> bool:\n"
    "\treturn bool((_voies.get(cerveau, {}) as Dictionary).get(\"busy\", false))\n"
    "\n"
    "\n"
    "## L'étiquette d'une génération en cours (\"\" si tout est libre) — compat observabilité.\n"
    "func label_en_cours() -> String:\n"
    "\tfor c in [\"vif\", \"conteur\"]:\n"
    "\t\tif _voies[c][\"busy\"]:\n"
    "\t\t\treturn str(_voies[c][\"label\"])\n"
    "\treturn \"\"\n"
    "\n"
    "\n"
    "# v33 — 2+2 : les DEUX voies actives → chacune la moitié des cœurs (batch plein pour\n"
    "# l'évaluation du prompt) ; une voie seule → son régime demandé. Appliqué À CHAUD\n"
    "# (llama_set_n_threads), à chaque départ ET à chaque fin de génération.\n"
    "func _partager_les_coeurs() -> void:\n"
    "\tvar deux: bool = _voies[\"conteur\"][\"busy\"] and _voies[\"vif\"][\"busy\"]\n"
    "\tfor c in [\"conteur\", \"vif\"]:\n"
    "\t\tvar m: Variant = _moteur_de(c)\n"
    "\t\tif m == null or not _voies[c][\"busy\"] or not m.has_method(\"set_thread_count\"):\n"
    "\t\t\tcontinue\n"
    "\t\tif deux:\n"
    "\t\t\tm.set_thread_count(FILS_PARTAGE, _fils_plein())\n"
    "\t\telse:\n"
    "\t\t\tm.set_thread_count(_fils_plein() if _voies[c][\"plein\"] else _fils_menage(), _fils_plein())\n",
    "N5")

# N6 — pompe de _process : les deux voies
t = exact(t,
    "\tif _llm != null and _busy:\n"
    "\t\t_llm.poll_result()\n",
    "\tif _llm != null and _voies[\"conteur\"][\"busy\"]:\n"
    "\t\t_llm.poll_result()\n"
    "\tif _llm_vif != null and _voies[\"vif\"][\"busy\"]:\n"
    "\t\t_llm_vif.poll_result()\n",
    "N6")

# N7 — garde d'amorçage : la voie visée seulement
t = exact(t,
    "\tif not is_ready() or _busy or (system_text == \"\" and user_text == \"\"):\n",
    "\tvar voie_amorce: String = \"vif\" if (cerveau == \"vif\" and est_vif_pret()) else \"conteur\"\n"
    "\tif not is_ready() or est_occupe(voie_amorce) or (system_text == \"\" and user_text == \"\"):\n",
    "N7")

# N8 — generate_raw : le cœur par voie (span entre deux ancres uniques)
t = span(t,
    "\tif _busy:\n\t\treturn {\"error\": \"generation deja en cours\"}\n",
    "\treturn _pending_result\n",
    "\t# v33 — la voie se résout AVANT tout : deux générations peuvent vivre ensemble, une par\n"
    "\t# cerveau. Une voie occupée refuse — l'appelant draine SA voie, jamais celle de l'autre.\n"
    "\tvar cerveau: String = str(opts.get(\"cerveau\", \"conteur\"))\n"
    "\tif not (cerveau == \"vif\" and est_vif_pret()):\n"
    "\t\tcerveau = \"conteur\"\n"
    "\tvar v: Dictionary = _voies[cerveau]\n"
    "\tif v[\"busy\"]:\n"
    "\t\treturn {\"error\": \"generation deja en cours\"}\n"
    "\t# REPRISE APRÈS MORT DU MOTEUR (2026-08-16) — ne concerne que le Conteur : la mort du Vif\n"
    "\t# est un simple repli mono-cerveau (_noter_si_moteur_mort), jamais une reprise de 6 Go.\n"
    "\tif cerveau == \"conteur\" and _reprise_necessaire():\n"
    "\t\tif _reprises >= REPRISES_MAX:\n"
    "\t\t\treturn {\"error\": \"moteur mort — reprise déjà tentée, relancer le jeu\"}\n"
    "\t\t_reprises += 1\n"
    "\t\tpush_warning(\"[MerlinNative] moteur mort après une génération coincée — reprise %d/%d\"\n"
    "\t\t\t\t% [_reprises, REPRISES_MAX])\n"
    "\t\tif not _monter_moteur():\n"
    "\t\t\treturn {\"error\": \"moteur mort — reprise impossible\"}\n"
    "\t\tvar dl: int = Time.get_ticks_msec() + 60000\n"
    "\t\twhile not _model_ready and Time.get_ticks_msec() < dl:\n"
    "\t\t\tawait get_tree().process_frame\n"
    "\t\tif not _model_ready:\n"
    "\t\t\treturn {\"error\": \"moteur mort — rechargement trop long\"}\n"
    "\t\t_moteur_mort = false\n"
    "\t\t_boot_error = \"\"\n"
    "\tvar creative: bool = opts.get(\"creative\", true)\n"
    "\tvar max_tokens: int = opts.get(\"max_tokens\", 250)\n"
    "\tvar grammar: String = opts.get(\"grammar\", \"\")\n"
    "\tvar grammar_root: String = opts.get(\"grammar_root\", \"root\")\n"
    "\tvar plein_regime: bool = opts.get(\"plein_regime\", false)\n"
    "\tvar moteur: Variant = _moteur_de(cerveau)\n"
    "\t_apply_regime(moteur, creative, max_tokens, plein_regime)\n"
    "\tv[\"plein\"] = plein_regime\n"
    "\tif grammar.is_empty():\n"
    "\t\tmoteur.clear_grammar()\n"
    "\telse:\n"
    "\t\tmoteur.set_grammar(grammar, grammar_root)\n"
    "\t# Arrêt doux : opt-in par tâche (fin_phrase). Jamais pour du JSON.\n"
    "\tif moteur.has_method(\"set_soft_stop\"):\n"
    "\t\tmoteur.set_soft_stop(bool(opts.get(\"fin_phrase\", false)))\n"
    "\tv[\"busy\"] = true\n"
    "\tv[\"label\"] = str(opts.get(\"label\", \"génération\"))\n"
    "\tv[\"t0\"] = Time.get_ticks_msec()\n"
    "\t_partager_les_coeurs()\n"
    "\tset_process(true)\n"
    "\t# Démarre en DIFFÉRÉ (le await generation_finished doit être enregistré avant émission).\n"
    "\tv[\"prompt\"] = full_prompt\n"
    "\tv[\"ready\"] = false\n"
    "\tv[\"result\"] = {}\n"
    "\tv[\"id\"] = int(v[\"id\"]) + 1\n"
    "\tvar my_id: int = int(v[\"id\"])\n"
    "\tcall_deferred(\"_start_generation\", cerveau, my_id)\n"
    "\t# Auto-polling par VOIE : chaque generate_raw pompe SA voie à chaque frame — deux appels\n"
    "\t# concurrents cohabitent, chacun draine son moteur et émet son flux.\n"
    "\tvar t0: int = Time.get_ticks_msec()\n"
    "\tvar cumul: String = \"\"\n"
    "\twhile true:\n"
    "\t\tif moteur != null:\n"
    "\t\t\t# AU FIL DE L'EAU : le tampon du moteur est vidé chaque image. Pas de flux pour un\n"
    "\t\t\t# AMORÇAGE (1 token, aussitôt jeté) — il polluait la mesure du premier texte.\n"
    "\t\t\tif max_tokens > 1 and moteur.has_method(\"poll_stream\"):\n"
    "\t\t\t\tvar morceau: String = str(moteur.poll_stream())\n"
    "\t\t\t\tif morceau != \"\":\n"
    "\t\t\t\t\tcumul += morceau\n"
    "\t\t\t\t\temit_signal(\"generation_chunk\", cumul)\n"
    "\t\t\t\t\temit_signal(\"generation_chunk_voie\", cerveau, cumul)\n"
    "\t\t\tmoteur.poll_result()\n"
    "\t\tif v[\"ready\"]:\n"
    "\t\t\tbreak\n"
    "\t\tif Time.get_ticks_msec() - t0 > GEN_TIMEOUT_MS:\n"
    "\t\t\tv[\"id\"] = int(v[\"id\"]) + 1\n"
    "\t\t\tif moteur != null:\n"
    "\t\t\t\tmoteur.cancel_generation()\n"
    "\t\t\tv[\"busy\"] = false\n"
    "\t\t\t_partager_les_coeurs()\n"
    "\t\t\tif _peut_dormir():\n"
    "\t\t\t\tset_process(false)\n"
    "\t\t\tpush_warning(\"[MerlinNative] timeout génération (%d ms) [%s] — annulée\" % [GEN_TIMEOUT_MS, cerveau])\n"
    "\t\t\treturn {\"error\": \"timeout\"}\n"
    "\t\tawait get_tree().process_frame\n"
    "\treturn v[\"result\"]\n",
    "N8")

# N9 — _start_generation + _on_result par voie (span)
t = span(t,
    "func _start_generation(gen_id: int) -> void:\n",
    "\temit_signal(\"generation_finished\", result)\n",
    "func _start_generation(cerveau: String, gen_id: int) -> void:\n"
    "\tvar v: Dictionary = _voies[cerveau]\n"
    "\tif gen_id != int(v[\"id\"]):\n"
    "\t\treturn  # génération invalidée (timeout) avant l'exécution différée\n"
    "\tvar moteur: Variant = _moteur_de(cerveau)\n"
    "\tif moteur == null:\n"
    "\t\t_on_result({\"error\": \"moteur indisponible\"}, cerveau, gen_id)\n"
    "\t\treturn\n"
    "\tmoteur.generate_async(str(v[\"prompt\"]), Callable(self, \"_on_result\").bind(cerveau, gen_id))\n"
    "\n"
    "\n"
    "func _on_result(result: Dictionary, cerveau: String = \"conteur\", gen_id: int = 0) -> void:\n"
    "\tvar v: Dictionary = _voies[cerveau]\n"
    "\tif gen_id != int(v[\"id\"]):\n"
    "\t\treturn  # callback périmé (annulé/remplacé) → ignore\n"
    "\tif v[\"ready\"]:\n"
    "\t\treturn  # double-poll → résultat déjà consommé\n"
    "\tvar elapsed_ms: int = Time.get_ticks_msec() - int(v[\"t0\"])\n"
    "\tv[\"busy\"] = false\n"
    "\t_partager_les_coeurs()\n"
    "\tif _peut_dormir():\n"
    "\t\tset_process(false)\n"
    "\tif result.has(\"error\"):\n"
    "\t\t_noter_si_moteur_mort(str(result[\"error\"]), cerveau)\n"
    "\tvar txt: String = _sanitize(str(result.get(\"text\", \"\")))\n"
    "\tif result.has(\"text\"):\n"
    "\t\tresult[\"text\"] = txt\n"
    "\t# COMPTEURS RÉELS (llama_perf_context) quand fournis, sinon approximation ~4 car./token.\n"
    "\tvar p_eval_ms: float = float(result.get(\"prompt_eval_ms\", 0.0))\n"
    "\tvar eval_ms: float = float(result.get(\"eval_ms\", 0.0))\n"
    "\tvar n_prompt: int = int(result.get(\"prompt_tokens\", 0))\n"
    "\tvar n_ecrits: int = int(result.get(\"eval_tokens\", 0))\n"
    "\tvar reels: bool = n_ecrits > 0 or n_prompt > 0\n"
    "\tvar approx_tokens: int = n_ecrits if reels else int(txt.length() / 4.0)\n"
    "\tvar tok_per_s: float = 0.0\n"
    "\tif reels and eval_ms > 0.0:\n"
    "\t\ttok_per_s = float(n_ecrits) * 1000.0 / eval_ms\n"
    "\telif elapsed_ms > 0:\n"
    "\t\ttok_per_s = float(approx_tokens) * 1000.0 / float(elapsed_ms)\n"
    "\tvar met: Dictionary = {\n"
    "\t\t\"cerveau\": cerveau,\n"
    "\t\t\"total_ms\": elapsed_ms,\n"
    "\t\t\"approx_tokens\": approx_tokens,\n"
    "\t\t\"tok_per_s\": tok_per_s,\n"
    "\t\t\"chars\": txt.length(),\n"
    "\t\t\"ok\": not result.has(\"error\"),\n"
    "\t\t\"compteurs_reels\": reels,\n"
    "\t\t\"prompt_ms\": p_eval_ms, \"prompt_tokens\": n_prompt,\n"
    "\t\t\"ecriture_ms\": eval_ms, \"tokens_ecrits\": n_ecrits,\n"
    "\t}\n"
    "\tv[\"metrics\"] = met\n"
    "\t_last_metrics = met\n"
    "\tif reels:\n"
    "\t\tvar vp: float = (float(n_prompt) * 1000.0 / p_eval_ms) if p_eval_ms > 0.0 else 0.0\n"
    "\t\tprint(\"[MerlinNative] %s [%s] : prompt %d tok en %.1f s (%.1f tok/s) · ecriture %d tok en %.1f s (%.1f tok/s) · total %.1f s\"\n"
    "\t\t\t\t% [str(v[\"label\"]), cerveau, n_prompt, p_eval_ms / 1000.0, vp,\n"
    "\t\t\t\t\tn_ecrits, eval_ms / 1000.0, tok_per_s, elapsed_ms / 1000.0])\n"
    "\t_activity_log.append({\n"
    "\t\t\"label\": str(v[\"label\"]), \"ms\": elapsed_ms, \"chars\": txt.length(),\n"
    "\t\t\"ok\": not result.has(\"error\"), \"t\": Time.get_ticks_msec(),\n"
    "\t})\n"
    "\twhile _activity_log.size() > ACTIVITY_LOG_MAX:\n"
    "\t\t_activity_log.pop_front()\n"
    "\tv[\"result\"] = result\n"
    "\tv[\"ready\"] = true\n"
    "\temit_signal(\"generation_finished\", result)\n",
    "N9")

# N10 — observabilité debug
t = exact(t,
    "func get_current_label() -> String:\n"
    "\treturn _current_label\n",
    "func get_current_label() -> String:\n"
    "\treturn label_en_cours()\n",
    "N10a")
t = exact(t,
    "func get_elapsed_ms() -> int:\n"
    "\treturn (Time.get_ticks_msec() - _t_start_ms) if _busy else 0\n",
    "func get_elapsed_ms() -> int:\n"
    "\tvar t_actif: int = 0\n"
    "\tfor c in [\"conteur\", \"vif\"]:\n"
    "\t\tif _voies[c][\"busy\"]:\n"
    "\t\t\tt_actif = maxi(t_actif, Time.get_ticks_msec() - int(_voies[c][\"t0\"]))\n"
    "\treturn t_actif\n",
    "N10b")

# N11 — cancel par voie
t = exact(t,
    "func cancel() -> void:\n"
    "\tif _gen_moteur != null and _busy:\n"
    "\t\t_gen_moteur.cancel_generation()\n",
    "func cancel(cerveau: String = \"\") -> void:\n"
    "\tfor c in ([\"conteur\", \"vif\"] if cerveau == \"\" else [cerveau]):\n"
    "\t\tif not _voies.has(c):\n"
    "\t\t\tcontinue\n"
    "\t\tvar m: Variant = _moteur_de(c)\n"
    "\t\tif m != null and _voies[c][\"busy\"]:\n"
    "\t\t\tm.cancel_generation()\n",
    "N11")

# N12 — EXIT_TREE
t = exact(t,
    "\t\tif _llm != null and _busy:\n"
    "\t\t\tif _gen_moteur != null: _gen_moteur.cancel_generation()\n",
    "\t\tcancel()\n",
    "N12")

# N13 — drain du quit
t = exact(t,
    "\tif _llm != null and _busy:\n"
    "\t\tif _gen_moteur != null: _gen_moteur.cancel_generation()\n"
    "\t\tvar dl: int = Time.get_ticks_msec() + 2000\n"
    "\t\twhile _busy and Time.get_ticks_msec() < dl:\n"
    "\t\t\tif _gen_moteur != null: _gen_moteur.poll_result()  # le callback de fin (→ _busy=false) se déclenche au poll\n"
    "\t\t\tawait get_tree().process_frame\n",
    "\tif is_busy():\n"
    "\t\tcancel()\n"
    "\t\tvar dl: int = Time.get_ticks_msec() + 2000\n"
    "\t\twhile is_busy() and Time.get_ticks_msec() < dl:\n"
    "\t\t\tfor c in [\"conteur\", \"vif\"]:\n"
    "\t\t\t\tvar m: Variant = _moteur_de(c)\n"
    "\t\t\t\tif m != null and _voies[c][\"busy\"]:\n"
    "\t\t\t\t\tm.poll_result()  # le callback de fin (→ busy=false) se déclenche au poll\n"
    "\t\t\tawait get_tree().process_frame\n",
    "N13")

p.write_text(t, encoding="utf-8")
print("OK merlin_native.gd")

# ──────────── merlin_scenario.gd ────────────
p = pathlib.Path("scripts/llm/merlin_scenario.gd")
t = p.read_text(encoding="utf-8")

# S1 — le prefetch d'issue ne draine que SA voie (vif)
t = exact(t,
    "\tif mn.is_busy():\n"
    "\t\tmn.cancel()\n"
    "\t\tvar free_dl: int = Time.get_ticks_msec() + 4000\n"
    "\t\twhile mn.is_busy() and Time.get_ticks_msec() < free_dl:\n"
    "\t\t\tawait get_tree().process_frame\n"
    "\t\tif epoch != _reso_epoch:\n"
    "\t\t\treturn  # combo/beat changé pendant le drain — un prefetch plus récent a pris la main\n"
    "\t\tif mn.is_busy():\n"
    "\t\t\t_reso_state = \"idle\"\n"
    "\t\t\treturn  # libération trop lente — le sustain servira le fallback si rien n'arrive\n",
    "\t# v33 — on ne draine que SA voie (vif) : le Conteur continue d'écrire scènes et arc\n"
    "\t# pendant que l'issue se prépare. Compat mono-voie si le natif n'a pas est_occupe.\n"
    "\tvar vif_pris: bool = mn.est_occupe(\"vif\") if mn.has_method(\"est_occupe\") else mn.is_busy()\n"
    "\tif vif_pris:\n"
    "\t\tif mn.has_method(\"est_occupe\"):\n"
    "\t\t\tmn.cancel(\"vif\")\n"
    "\t\telse:\n"
    "\t\t\tmn.cancel()\n"
    "\t\tvar free_dl: int = Time.get_ticks_msec() + 4000\n"
    "\t\twhile (mn.est_occupe(\"vif\") if mn.has_method(\"est_occupe\") else mn.is_busy()) and Time.get_ticks_msec() < free_dl:\n"
    "\t\t\tawait get_tree().process_frame\n"
    "\t\tif epoch != _reso_epoch:\n"
    "\t\t\treturn  # combo/beat changé pendant le drain — un prefetch plus récent a pris la main\n"
    "\t\tif (mn.est_occupe(\"vif\") if mn.has_method(\"est_occupe\") else mn.is_busy()):\n"
    "\t\t\t_reso_state = \"idle\"\n"
    "\t\t\treturn  # libération trop lente — le stream au resolve prendra le relais\n",
    "S1")

# S2 — le lookahead n'attend que la voie conteur (texte v31.2 exact)
t = exact(t,
    "\tif mn.is_busy():\n"
    "\t\t# v31.2 — PLUS D'ANNULATION : la préemption produisait une tempête (six tranches\n"
    "\t\t# cédées, zéro scène livrée, chaque annulation repayant l'éval de l'arc). On attend,\n"
    "\t\t# borné ; si l'arc garde la place, il servira — sa continuité de cache vaut plus\n"
    "\t\t# que notre priorité.\n"
    "\t\tvar dl_moteur: int = Time.get_ticks_msec() + 30000\n"
    "\t\twhile mn.is_busy() and Time.get_ticks_msec() < dl_moteur:\n"
    "\t\t\tawait get_tree().create_timer(0.5).timeout\n"
    "\t\tif mn.is_busy():\n"
    "\t\t\t_scene_jit_qn = -1\n"
    "\t\t\treturn  # la place n'a pas été rendue à temps : l'arc couvrira ce beat\n",
    "\t# v33 — la voie CONTEUR seulement : le Vif peut streamer une issue en même temps,\n"
    "\t# elle ne nous concerne pas. Attente bornée, jamais d'annulation (v31.2).\n"
    "\tvar conteur_pris: bool = mn.est_occupe(\"conteur\") if mn.has_method(\"est_occupe\") else mn.is_busy()\n"
    "\tif conteur_pris:\n"
    "\t\tvar dl_moteur: int = Time.get_ticks_msec() + 30000\n"
    "\t\twhile (mn.est_occupe(\"conteur\") if mn.has_method(\"est_occupe\") else mn.is_busy()) and Time.get_ticks_msec() < dl_moteur:\n"
    "\t\t\tawait get_tree().create_timer(0.5).timeout\n"
    "\t\tif (mn.est_occupe(\"conteur\") if mn.has_method(\"est_occupe\") else mn.is_busy()):\n"
    "\t\t\t_scene_jit_qn = -1\n"
    "\t\t\treturn  # la place n'a pas été rendue à temps : l'arc couvrira ce beat\n",
    "S2")

# S3 — invalidate_resolution : n'annule que la voie du Vif
t = exact(t,
    "\tif _reso_state == \"running\":\n"
    "\t\tvar mn: Node = _mn()\n"
    "\t\tif mn != null and mn.is_busy():\n"
    "\t\t\tmn.cancel()\n",
    "\tif _reso_state == \"running\":\n"
    "\t\tvar mn: Node = _mn()\n"
    "\t\tif mn != null and mn.is_busy():\n"
    "\t\t\t# v33 — seule la voie du Vif porte les issues : on n'annule qu'elle.\n"
    "\t\t\tif mn.has_method(\"est_occupe\"):\n"
    "\t\t\t\tmn.cancel(\"vif\")\n"
    "\t\t\telse:\n"
    "\t\t\t\tmn.cancel()\n",
    "S3")

# S4 — l'arc ne repatiente que sur SA voie (conteur)
t = exact(t,
    "\t\t\tvar mn_a: Node = _mn()\n"
    "\t\t\tif mn_a == null or not mn_a.is_ready() or mn_a.is_busy():\n"
    "\t\t\t\tawait get_tree().create_timer(1.0).timeout\n"
    "\t\t\t\tcontinue  # toujours occupé : on repatiente, ce n'est PAS un échec\n",
    "\t\t\tvar mn_a: Node = _mn()\n"
    "\t\t\tif mn_a == null or not mn_a.is_ready() \\\n"
    "\t\t\t\t\tor (mn_a.est_occupe(\"conteur\") if mn_a.has_method(\"est_occupe\") else mn_a.is_busy()):\n"
    "\t\t\t\tawait get_tree().create_timer(1.0).timeout\n"
    "\t\t\t\tcontinue  # voie conteur occupée : on repatiente, ce n'est PAS un échec\n",
    "S4")

p.write_text(t, encoding="utf-8")
print("OK merlin_scenario.gd")

# ──────────── merlin_game.gd ────────────
p = pathlib.Path("scripts/game/merlin_game.gd")
t = p.read_text(encoding="utf-8")

# G1 — au resolve : le stream AVANT tout filet ; le banc ne sert que moteur mort
t = exact(t,
    "\tvar prose: String = str(sc.take_resolution(situ, played_cards, res))\n"
    "\tif prose.length() < 10:\n"
    "\t\t# N2a — secours COMPOSÉ : reflète la combinaison (registre des cartes) + le biome + le degré.\n"
    "\t\tprose = sc.fallback_resolution(str(res.get(\"degree\", \"reussite\")), str(situ.get(\"type\", \"\")),\n"
    "\t\t\tplayed_cards, str(run.get(\"biome\")))\n",
    "\tvar prose: String = str(sc.take_resolution(situ, played_cards, res))\n"
    "\tif prose.length() < 10:\n"
    "\t\t# v33 « Les Deux Mains » — le banc ne sert plus JAMAIS sur un délai : l'issue s'ÉCRIT\n"
    "\t\t# SOUS LES YEUX (le Vif streame plus vite qu'une lecture humaine). Le filet en dur ne\n"
    "\t\t# reste que pour un moteur MORT — et il est marqué (secours_consomme + bandeau).\n"
    "\t\tprose = await _stream_resolution(sc, situ, played_cards, res)\n"
    "\tif prose.length() < 10:\n"
    "\t\t# N2a — secours COMPOSÉ (filet ULTIME : moteur mort/erreur uniquement).\n"
    "\t\tprose = sc.fallback_resolution(str(res.get(\"degree\", \"reussite\")), str(situ.get(\"type\", \"\")),\n"
    "\t\t\tplayed_cards, str(run.get(\"biome\")))\n",
    "G1")

# G2 — la fonction de stream, insérée devant _show_resolution
t = exact(t,
    "func _show_resolution(res: Dictionary, narration: String, animate: bool = true) -> void:\n",
    "# v33 — L'ISSUE STREAMÉE : la prose du Vif se révèle au fil de l'écriture, dans le MÊME fil\n"
    "# de prose que la situation (la cadence du modèle EST la machine à écrire). Retourne la\n"
    "# prose finale, \"\" si le moteur meurt — l'appelant sert alors le filet, marqué.\n"
    "func _stream_resolution(sc: Node, situ: Dictionary, played_cards: Array, res: Dictionary) -> String:\n"
    "\tvar mn: Node = get_node_or_null(\"/root/MerlinNative\")\n"
    "\tif mn == null or not mn.has_signal(\"generation_chunk_voie\"):\n"
    "\t\treturn \"\"\n"
    "\tif not sc.is_resolution_incoming(played_cards, res):\n"
    "\t\tsc.prefetch_resolution(situ, played_cards, res)\n"
    "\tif _scene_art != null:\n"
    "\t\t_scene_art.set_thinking(true)\n"
    "\tvar texte_avant: String = _situation_text.text\n"
    "\tvar base: String = texte_avant\n"
    "\tif base.ends_with(\"[/center]\"):\n"
    "\t\tbase = base.substr(0, base.length() - 9)\n"
    "\tvar sur_flux: Callable = func(cerveau: String, cumul: String) -> void:\n"
    "\t\tif cerveau != \"vif\" or not is_instance_valid(self) or _situation_text == null:\n"
    "\t\t\treturn\n"
    "\t\tvar brut: String = MerlinProse.clean_prose(cumul.strip_edges())\n"
    "\t\tif brut.length() < 4:\n"
    "\t\t\treturn\n"
    "\t\t_situation_text.text = base + \"\\n\\n\" + MerlinProse.ensure_italic_action(brut) + \"[/center]\"\n"
    "\tmn.connect(\"generation_chunk_voie\", sur_flux)\n"
    "\tvar dl: int = Time.get_ticks_msec() + 180000\n"
    "\tvar finale: String = \"\"\n"
    "\twhile Time.get_ticks_msec() < dl:\n"
    "\t\tif sc.is_resolution_ready(played_cards, res):\n"
    "\t\t\tfinale = str(sc.take_resolution(situ, played_cards, res))\n"
    "\t\t\tbreak\n"
    "\t\tif not sc.is_resolution_incoming(played_cards, res):\n"
    "\t\t\tbreak  # la génération est morte (erreur moteur) et rien en cache → filet ultime\n"
    "\t\tawait get_tree().process_frame\n"
    "\tmn.disconnect(\"generation_chunk_voie\", sur_flux)\n"
    "\tif _scene_art != null and is_instance_valid(_scene_art):\n"
    "\t\t_scene_art.set_thinking(false)\n"
    "\t# L'encart revient à son état d'avant le flux : _show_resolution recompose le fil complet.\n"
    "\tif _situation_text != null:\n"
    "\t\t_situation_text.text = texte_avant\n"
    "\treturn finale\n"
    "\n"
    "\n"
    "func _show_resolution(res: Dictionary, narration: String, animate: bool = true) -> void:\n",
    "G2")

p.write_text(t, encoding="utf-8")
print("OK merlin_game.gd")
print("v33 « Les Deux Mains » appliqué")
