## ═══════════════════════════════════════════════════════════════════════════════
## Tests unitaires — BrainSwarmConfig (methodes statiques + integrite de PROFILES)
## ═══════════════════════════════════════════════════════════════════════════════
## Couverture :
##   detect_profile()      — seuils RAM/threads, repli sur LEGER
##   profile_from_name()   — libelles du menu options -> identifiants
##   get_profile()         — identifiants valides, repli sur identifiant inconnu
##   get_prefetch_depth()  — valeurs par palier, repli
##   get_profile_name()    — chaine non vide, repli
##   is_time_sharing()     — modes resident / parallel
##   get_model_for_role()  — role exact, repli sur le premier cerveau
##   get_brain_config()    — role exact, role absent -> {}
##   get_required_models() — deduplication des tags
##   get_peak_ram_mb()     — valeurs par palier, repli
##   PROFILES              — cles obligatoires, tableaux de cerveaux valides
##
## La regle du joueur (« au-dessus de 32 Go le plus gros modele, en dessous le
## moyen, machine limitee le plus petit ») est verifiee explicitement par
## test_detect_profile_regle_du_joueur_*.
##
## Pattern : extends RefCounted, pas de class_name, test_xxx() -> bool
## ═══════════════════════════════════════════════════════════════════════════════

extends RefCounted


# ─── Alias ─────────────────────────────────────────────────────────────────────

const LEGER: int = BrainSwarmConfig.Profile.LEGER
const MOYEN: int = BrainSwarmConfig.Profile.MOYEN
const ELEVE: int = BrainSwarmConfig.Profile.ELEVE
const MOBILE_LOW: int = BrainSwarmConfig.Profile.MOBILE_LOW
const MOBILE_MID: int = BrainSwarmConfig.Profile.MOBILE_MID
const MOBILE_HIGH: int = BrainSwarmConfig.Profile.MOBILE_HIGH

const DESKTOP: Array[int] = [LEGER, MOYEN, ELEVE]
const TOUS: Array[int] = [LEGER, MOYEN, ELEVE, MOBILE_LOW, MOBILE_MID, MOBILE_HIGH]


# ═══════════════════════════════════════════════════════════════════════════════
# detect_profile() — la regle du joueur, seuils RAM + threads
# ═══════════════════════════════════════════════════════════════════════════════

func test_detect_profile_regle_du_joueur_32go_donne_eleve() -> bool:
	# « si RAM au dessus de 32Go alors le plus haut »
	var result: int = BrainSwarmConfig.detect_profile(32768, 6)
	if result != ELEVE:
		push_error("detect_profile 32 Go: attendu ELEVE (%d), obtenu %d" % [ELEVE, result])
		return false
	return true


func test_detect_profile_regle_du_joueur_16go_donne_moyen() -> bool:
	# « si en dessous alors moyen »
	var result: int = BrainSwarmConfig.detect_profile(16384, 6)
	if result != MOYEN:
		push_error("detect_profile 16 Go: attendu MOYEN (%d), obtenu %d" % [MOYEN, result])
		return false
	return true


func test_detect_profile_regle_du_joueur_8go_donne_leger() -> bool:
	# « si machine limitee alors plus petit modele »
	var result: int = BrainSwarmConfig.detect_profile(8192, 4)
	if result != LEGER:
		push_error("detect_profile 8 Go: attendu LEGER (%d), obtenu %d" % [LEGER, result])
		return false
	return true


func test_detect_profile_juste_sous_32go_reste_moyen() -> bool:
	# 31 Go : le seuil ELEVE (32000) n'est pas atteint.
	var result: int = BrainSwarmConfig.detect_profile(31000, 16)
	if result != MOYEN:
		push_error("detect_profile 31 Go: attendu MOYEN (%d), obtenu %d" % [MOYEN, result])
		return false
	return true


func test_detect_profile_juste_sous_16go_reste_leger() -> bool:
	var result: int = BrainSwarmConfig.detect_profile(15000, 8)
	if result != LEGER:
		push_error("detect_profile 15 Go: attendu LEGER (%d), obtenu %d" % [LEGER, result])
		return false
	return true


func test_detect_profile_ram_insuffisante_replie_sur_leger() -> bool:
	var result: int = BrainSwarmConfig.detect_profile(2000, 2)
	if result != LEGER:
		push_error("detect_profile 2 Go: attendu LEGER (%d), obtenu %d" % [LEGER, result])
		return false
	return true


func test_detect_profile_ressources_nulles_replie_sur_leger() -> bool:
	var result: int = BrainSwarmConfig.detect_profile(0, 0)
	if result != LEGER:
		push_error("detect_profile 0/0: attendu LEGER (%d), obtenu %d" % [LEGER, result])
		return false
	return true


func test_detect_profile_threads_insuffisants_degradent_le_palier() -> bool:
	# 32 Go mais un seul coeur : ELEVE demande 4 threads, MOYEN aussi,
	# LEGER en demande 2 — aucun ne passe, donc repli sur LEGER.
	var result: int = BrainSwarmConfig.detect_profile(32768, 1)
	if result != LEGER:
		push_error("detect_profile 1 thread: attendu LEGER (%d), obtenu %d" % [LEGER, result])
		return false
	return true


func test_detect_profile_i5_8500_32go_donne_eleve() -> bool:
	# Machine de reference du projet : 6 coeurs, 32 Go, sans GPU.
	# ELEVE ne doit PAS exiger 8 threads, sinon la regle « 32 Go = plus haut »
	# serait contredite par le nombre de coeurs.
	var result: int = BrainSwarmConfig.detect_profile(32768, 6)
	if result != ELEVE:
		push_error("detect_profile i5-8500/32 Go: attendu ELEVE (%d), obtenu %d" % [ELEVE, result])
		return false
	return true


# ═══════════════════════════════════════════════════════════════════════════════
# profile_from_name() — libelles du menu options
# ═══════════════════════════════════════════════════════════════════════════════

func test_profile_from_name_reconnait_les_trois_paliers() -> bool:
	var attendu: Dictionary = {"leger": LEGER, "moyen": MOYEN, "eleve": ELEVE}
	for nom in attendu.keys():
		var result: int = BrainSwarmConfig.profile_from_name(str(nom))
		if result != int(attendu[nom]):
			push_error("profile_from_name('%s'): attendu %d, obtenu %d" % [str(nom), int(attendu[nom]), result])
			return false
	return true


func test_profile_from_name_accepte_les_accents_et_la_casse() -> bool:
	if BrainSwarmConfig.profile_from_name("Élevé") != ELEVE:
		push_error("profile_from_name('Élevé'): les accents doivent etre acceptes")
		return false
	if BrainSwarmConfig.profile_from_name("  LÉGER  ") != LEGER:
		push_error("profile_from_name('  LÉGER  '): casse et espaces doivent etre tolerés")
		return false
	return true


func test_profile_from_name_inconnu_retourne_moins_un() -> bool:
	for nom in ["", "auto", "automatique", "quad", "n'importe quoi"]:
		if BrainSwarmConfig.profile_from_name(str(nom)) != -1:
			push_error("profile_from_name('%s'): devrait retourner -1 (detection auto)" % str(nom))
			return false
	return true


# ═══════════════════════════════════════════════════════════════════════════════
# get_profile() — identifiants valides et repli
# ═══════════════════════════════════════════════════════════════════════════════

func test_get_profile_returns_dict_for_every_valid_id() -> bool:
	for pid in TOUS:
		var profile: Dictionary = BrainSwarmConfig.get_profile(pid)
		if profile.is_empty():
			push_error("get_profile: le palier %d renvoie un dictionnaire vide" % pid)
			return false
	return true


func test_get_profile_invalid_id_returns_leger_fallback() -> bool:
	var profile: Dictionary = BrainSwarmConfig.get_profile(9999)
	var leger: Dictionary = BrainSwarmConfig.get_profile(LEGER)
	if str(profile.get("name", "")) != str(leger.get("name", "_")):
		push_error("get_profile identifiant inconnu: repli attendu sur LEGER, obtenu '%s'" % str(profile.get("name", "")))
		return false
	return true


func test_get_profile_has_required_keys() -> bool:
	var required: Array[String] = ["name", "mode", "brains", "total_ram_mb", "min_threads", "min_ram_mb", "prefetch_depth"]
	for pid in TOUS:
		var profile: Dictionary = BrainSwarmConfig.get_profile(pid)
		for key in required:
			if not profile.has(key):
				push_error("get_profile cles: le palier %d n'a pas '%s'" % [pid, key])
				return false
	return true


# ═══════════════════════════════════════════════════════════════════════════════
# get_prefetch_depth()
# ═══════════════════════════════════════════════════════════════════════════════

func test_get_prefetch_depth_leger_is_zero() -> bool:
	var depth: int = BrainSwarmConfig.get_prefetch_depth(LEGER)
	if depth != 0:
		push_error("get_prefetch_depth LEGER: attendu 0, obtenu %d" % depth)
		return false
	return true


func test_get_prefetch_depth_croit_avec_le_palier() -> bool:
	var prev: int = -1
	for pid in DESKTOP:
		var depth: int = BrainSwarmConfig.get_prefetch_depth(pid)
		if depth < prev:
			push_error("get_prefetch_depth: palier %d a %d < precedent %d" % [pid, depth, prev])
			return false
		prev = depth
	return true


func test_get_prefetch_depth_invalid_id_returns_zero() -> bool:
	var depth: int = BrainSwarmConfig.get_prefetch_depth(9999)
	if depth != 0:
		push_error("get_prefetch_depth identifiant inconnu: attendu 0, obtenu %d" % depth)
		return false
	return true


# ═══════════════════════════════════════════════════════════════════════════════
# get_profile_name()
# ═══════════════════════════════════════════════════════════════════════════════

func test_get_profile_name_returns_non_empty_string_for_all() -> bool:
	for pid in TOUS:
		var nom: String = BrainSwarmConfig.get_profile_name(pid)
		if nom.is_empty():
			push_error("get_profile_name: le palier %d renvoie un nom vide" % pid)
			return false
	return true


func test_get_profile_name_porte_le_libelle_du_palier() -> bool:
	var attendu: Dictionary = {LEGER: "leger", MOYEN: "moyen", ELEVE: "eleve"}
	for pid in attendu.keys():
		var nom: String = BrainSwarmConfig.get_profile_name(int(pid))
		if not nom.to_lower().contains(str(attendu[pid])):
			push_error("get_profile_name %d: le nom devrait contenir '%s', obtenu '%s'" % [int(pid), str(attendu[pid]), nom])
			return false
	return true


func test_get_profile_name_invalid_falls_back_to_leger_name() -> bool:
	if BrainSwarmConfig.get_profile_name(9999) != BrainSwarmConfig.get_profile_name(LEGER):
		push_error("get_profile_name identifiant inconnu: repli attendu sur le nom de LEGER")
		return false
	return true


# ═══════════════════════════════════════════════════════════════════════════════
# is_time_sharing()
# ═══════════════════════════════════════════════════════════════════════════════

func test_is_time_sharing_false_pour_les_paliers_a_un_modele() -> bool:
	# LEGER et MOYEN n'ont qu'un modele resident : rien a echanger.
	for pid in [LEGER, MOYEN]:
		if BrainSwarmConfig.is_time_sharing(pid):
			push_error("is_time_sharing: le palier %d ne devrait pas etre en time-sharing" % pid)
			return false
	return true


func test_is_time_sharing_false_pour_eleve_qui_est_parallele() -> bool:
	# ELEVE charge les deux modeles en meme temps (22,1 Go sur 32) : pas
	# d'echange, generation parallele.
	if BrainSwarmConfig.is_time_sharing(ELEVE):
		push_error("is_time_sharing ELEVE: attendu false (mode parallel)")
		return false
	return true


# ═══════════════════════════════════════════════════════════════════════════════
# get_model_for_role()
# ═══════════════════════════════════════════════════════════════════════════════

func test_get_model_for_role_narrator_in_eleve_is_26b() -> bool:
	var tag: String = BrainSwarmConfig.get_model_for_role(ELEVE, "narrator")
	if tag != BrainSwarmConfig.MODEL_GEMMA4_26B:
		push_error("get_model_for_role ELEVE narrator: attendu '%s', obtenu '%s'" % [BrainSwarmConfig.MODEL_GEMMA4_26B, tag])
		return false
	return true


func test_get_model_for_role_gamemaster_in_eleve_is_e4b() -> bool:
	# Le game master ne produit que du JSON : l'E4B suffit, et payer deux fois
	# le gros modele doublerait l'empreinte sans ameliorer la prose.
	var tag: String = BrainSwarmConfig.get_model_for_role(ELEVE, "gamemaster")
	if tag != BrainSwarmConfig.MODEL_GEMMA4_E4B:
		push_error("get_model_for_role ELEVE gamemaster: attendu '%s', obtenu '%s'" % [BrainSwarmConfig.MODEL_GEMMA4_E4B, tag])
		return false
	return true


func test_get_model_for_role_narrator_in_moyen_is_12b() -> bool:
	var tag: String = BrainSwarmConfig.get_model_for_role(MOYEN, "narrator")
	if tag != BrainSwarmConfig.MODEL_GEMMA4_12B:
		push_error("get_model_for_role MOYEN narrator: attendu '%s', obtenu '%s'" % [BrainSwarmConfig.MODEL_GEMMA4_12B, tag])
		return false
	return true


func test_get_model_for_role_narrator_in_leger_is_e4b() -> bool:
	var tag: String = BrainSwarmConfig.get_model_for_role(LEGER, "narrator")
	if tag != BrainSwarmConfig.MODEL_GEMMA4_E4B:
		push_error("get_model_for_role LEGER narrator: attendu '%s', obtenu '%s'" % [BrainSwarmConfig.MODEL_GEMMA4_E4B, tag])
		return false
	return true


func test_get_model_for_role_missing_role_falls_back_to_first_brain() -> bool:
	# LEGER n'a qu'un cerveau (narrator) ; demander "gamemaster" doit rendre
	# le modele du premier cerveau, pas une chaine vide.
	var tag: String = BrainSwarmConfig.get_model_for_role(LEGER, "gamemaster")
	if tag != BrainSwarmConfig.MODEL_GEMMA4_E4B:
		push_error("get_model_for_role LEGER role absent: attendu '%s', obtenu '%s'" % [BrainSwarmConfig.MODEL_GEMMA4_E4B, tag])
		return false
	return true


func test_tous_les_tags_desktop_sont_de_la_famille_gemma4() -> bool:
	# Garde-fou : un tag d'une autre famille reintroduirait le probleme de
	# gabarit de chat que la bascule vers /api/chat vient de supprimer.
	for pid in DESKTOP:
		for tag in BrainSwarmConfig.get_required_models(pid):
			if not str(tag).begins_with("gemma4:"):
				push_error("palier %d: tag '%s' hors famille Gemma 4" % [pid, str(tag)])
				return false
	return true


# ═══════════════════════════════════════════════════════════════════════════════
# get_brain_config()
# ═══════════════════════════════════════════════════════════════════════════════

func test_get_brain_config_narrator_in_eleve() -> bool:
	var cfg: Dictionary = BrainSwarmConfig.get_brain_config(ELEVE, "narrator")
	if cfg.is_empty():
		push_error("get_brain_config ELEVE narrator: ne devrait pas etre vide")
		return false
	if str(cfg.get("role", "")) != "narrator":
		push_error("get_brain_config ELEVE narrator: role incorrect '%s'" % str(cfg.get("role", "")))
		return false
	if int(cfg.get("n_ctx", 0)) != 8192:
		push_error("get_brain_config ELEVE narrator: n_ctx attendu 8192, obtenu %d" % int(cfg.get("n_ctx", 0)))
		return false
	return true


func test_get_brain_config_missing_role_returns_empty_dict() -> bool:
	var cfg: Dictionary = BrainSwarmConfig.get_brain_config(LEGER, "judge")
	if not cfg.is_empty():
		push_error("get_brain_config LEGER judge: devrait renvoyer {}, obtenu %s" % str(cfg))
		return false
	return true


func test_get_brain_config_all_brains_have_required_keys() -> bool:
	var required: Array[String] = ["role", "model_key", "ollama_tag", "n_ctx", "ram_mb", "thinking"]
	for pid in DESKTOP:
		var profile: Dictionary = BrainSwarmConfig.get_profile(pid)
		for brain in profile.get("brains", []):
			for key in required:
				if not brain.has(key):
					push_error("cles de cerveau: palier %d, cerveau '%s', cle '%s' manquante" % [pid, str(brain.get("role", "?")), key])
					return false
	return true


func test_chaque_model_key_existe_dans_ram_by_model() -> bool:
	# Un model_key absent de RAM_BY_MODEL rendrait l'empreinte memoire
	# incalculable — donc le garde-fou « ce modele tient-il ? » inoperant.
	for pid in TOUS:
		var profile: Dictionary = BrainSwarmConfig.get_profile(pid)
		for brain in profile.get("brains", []):
			var key: String = str(brain.get("model_key", ""))
			if not BrainSwarmConfig.RAM_BY_MODEL.has(key):
				push_error("RAM_BY_MODEL: cle '%s' absente (palier %d)" % [key, pid])
				return false
	return true


# ═══════════════════════════════════════════════════════════════════════════════
# get_required_models()
# ═══════════════════════════════════════════════════════════════════════════════

func test_get_required_models_leger_returns_one_model() -> bool:
	var models: Array = BrainSwarmConfig.get_required_models(LEGER)
	if models.size() != 1:
		push_error("get_required_models LEGER: attendu 1 modele, obtenu %d" % models.size())
		return false
	if str(models[0]) != BrainSwarmConfig.MODEL_GEMMA4_E4B:
		push_error("get_required_models LEGER: attendu '%s', obtenu '%s'" % [BrainSwarmConfig.MODEL_GEMMA4_E4B, str(models[0])])
		return false
	return true


func test_get_required_models_eleve_returns_two_models() -> bool:
	var models: Array = BrainSwarmConfig.get_required_models(ELEVE)
	if models.size() != 2:
		push_error("get_required_models ELEVE: attendu 2 modeles, obtenu %d" % models.size())
		return false
	if str(models[0]) != BrainSwarmConfig.MODEL_GEMMA4_26B:
		push_error("get_required_models ELEVE: premier modele attendu 26B, obtenu '%s'" % str(models[0]))
		return false
	if str(models[1]) != BrainSwarmConfig.MODEL_GEMMA4_E4B:
		push_error("get_required_models ELEVE: second modele attendu E4B, obtenu '%s'" % str(models[1]))
		return false
	return true


func test_get_required_models_no_empty_strings() -> bool:
	for pid in DESKTOP:
		for m in BrainSwarmConfig.get_required_models(pid):
			if str(m).is_empty():
				push_error("get_required_models: le palier %d contient un tag vide" % pid)
				return false
	return true


# ═══════════════════════════════════════════════════════════════════════════════
# get_peak_ram_mb()
# ═══════════════════════════════════════════════════════════════════════════════

func test_get_peak_ram_mb_leger_is_6100() -> bool:
	var ram: int = BrainSwarmConfig.get_peak_ram_mb(LEGER)
	if ram != 6100:
		push_error("get_peak_ram_mb LEGER: attendu 6100, obtenu %d" % ram)
		return false
	return true


func test_get_peak_ram_mb_eleve_somme_les_deux_modeles() -> bool:
	# ELEVE est en mode parallel : les deux modeles resident en meme temps,
	# 16000 + 6100. Declarer seulement le plus gros masquerait 6 Go.
	var ram: int = BrainSwarmConfig.get_peak_ram_mb(ELEVE)
	if ram != 22100:
		push_error("get_peak_ram_mb ELEVE: attendu 22100 (16000 + 6100), obtenu %d" % ram)
		return false
	return true


func test_get_peak_ram_mb_invalid_id_returns_leger_fallback() -> bool:
	var ram: int = BrainSwarmConfig.get_peak_ram_mb(9999)
	if ram != BrainSwarmConfig.get_peak_ram_mb(LEGER):
		push_error("get_peak_ram_mb identifiant inconnu: repli attendu sur LEGER, obtenu %d" % ram)
		return false
	return true


func test_le_pic_ram_tient_dans_le_seuil_du_palier() -> bool:
	# Un palier qui exige moins de RAM que son propre modele ne demande est un
	# piege : la detection le choisirait sur une machine ou il ne tient pas.
	for pid in DESKTOP:
		var profile: Dictionary = BrainSwarmConfig.get_profile(pid)
		var pic: int = int(profile.get("total_ram_mb", 0))
		var seuil: int = int(profile.get("min_ram_mb", 0))
		if pic > seuil:
			push_error("palier %d: pic RAM %d MB > seuil d'activation %d MB" % [pid, pic, seuil])
			return false
	return true


# ═══════════════════════════════════════════════════════════════════════════════
# Integrite de PROFILES
# ═══════════════════════════════════════════════════════════════════════════════

func test_profiles_min_ram_increases_with_tier() -> bool:
	# Bureau et mobile sont testes separement : ils visent des classes de
	# materiel differentes et leurs seuils se chevauchent.
	var prev: int = -1
	for pid in DESKTOP:
		var min_ram: int = int(BrainSwarmConfig.get_profile(pid).get("min_ram_mb", 0))
		if min_ram < prev:
			push_error("PROFILES bureau: palier %d min_ram %d < precedent %d" % [pid, min_ram, prev])
			return false
		prev = min_ram
	prev = -1
	for pid in [MOBILE_LOW, MOBILE_MID, MOBILE_HIGH]:
		var min_ram: int = int(BrainSwarmConfig.get_profile(pid).get("min_ram_mb", 0))
		if min_ram < prev:
			push_error("PROFILES mobile: palier %d min_ram %d < precedent %d" % [pid, min_ram, prev])
			return false
		prev = min_ram
	return true


func test_profiles_seuils_correspondent_a_la_demande() -> bool:
	# Les trois seuils sont la traduction litterale de la demande du joueur.
	var attendu: Dictionary = {LEGER: 8000, MOYEN: 16000, ELEVE: 32000}
	for pid in attendu.keys():
		var min_ram: int = int(BrainSwarmConfig.get_profile(int(pid)).get("min_ram_mb", 0))
		if min_ram != int(attendu[pid]):
			push_error("seuil du palier %d: attendu %d MB, obtenu %d MB" % [int(pid), int(attendu[pid]), min_ram])
			return false
	return true


func test_profiles_brain_count_matches_tier_expectations() -> bool:
	var attendu: Dictionary = {LEGER: 1, MOYEN: 1, ELEVE: 2}
	for pid in attendu.keys():
		var brains: Array = BrainSwarmConfig.get_profile(int(pid)).get("brains", [])
		if brains.size() != int(attendu[pid]):
			push_error("nombre de cerveaux: palier %d attendu %d, obtenu %d" % [int(pid), int(attendu[pid]), brains.size()])
			return false
	return true


func test_model_constants_are_non_empty_strings() -> bool:
	var tags: Array[String] = [
		BrainSwarmConfig.MODEL_GEMMA4_26B,
		BrainSwarmConfig.MODEL_GEMMA4_12B,
		BrainSwarmConfig.MODEL_GEMMA4_E4B,
		BrainSwarmConfig.MODEL_GEMMA4_E2B,
		BrainSwarmConfig.MODEL_GEMMA4_31B,
	]
	for tag in tags:
		if tag.is_empty():
			push_error("constante MODEL_: chaine vide")
			return false
	return true


func test_le_31b_dense_n_est_choisi_par_aucun_palier() -> bool:
	# Il tombe sous 1 token/seconde sans GPU (bible §9.9 : aucune attente
	# visible). Il reste selectionnable a la main, jamais automatiquement.
	for pid in DESKTOP:
		for tag in BrainSwarmConfig.get_required_models(pid):
			if str(tag) == BrainSwarmConfig.MODEL_GEMMA4_31B:
				push_error("palier %d: le 31B dense ne doit jamais etre choisi automatiquement" % pid)
				return false
	return true


func test_ram_by_model_keys_are_non_empty() -> bool:
	var ram_map: Dictionary = BrainSwarmConfig.RAM_BY_MODEL
	if ram_map.is_empty():
		push_error("RAM_BY_MODEL: ne devrait pas etre vide")
		return false
	for key in ram_map.keys():
		if int(ram_map[key]) <= 0:
			push_error("RAM_BY_MODEL['%s']: doit etre > 0, obtenu %d" % [str(key), int(ram_map[key])])
			return false
	return true


# ═══════════════════════════════════════════════════════════════════════════════
# RUNNER
# ═══════════════════════════════════════════════════════════════════════════════

func run_all() -> Dictionary:
	var tests: Array[String] = [
		# detect_profile (9)
		"test_detect_profile_regle_du_joueur_32go_donne_eleve",
		"test_detect_profile_regle_du_joueur_16go_donne_moyen",
		"test_detect_profile_regle_du_joueur_8go_donne_leger",
		"test_detect_profile_juste_sous_32go_reste_moyen",
		"test_detect_profile_juste_sous_16go_reste_leger",
		"test_detect_profile_ram_insuffisante_replie_sur_leger",
		"test_detect_profile_ressources_nulles_replie_sur_leger",
		"test_detect_profile_threads_insuffisants_degradent_le_palier",
		"test_detect_profile_i5_8500_32go_donne_eleve",
		# profile_from_name (3)
		"test_profile_from_name_reconnait_les_trois_paliers",
		"test_profile_from_name_accepte_les_accents_et_la_casse",
		"test_profile_from_name_inconnu_retourne_moins_un",
		# get_profile (3)
		"test_get_profile_returns_dict_for_every_valid_id",
		"test_get_profile_invalid_id_returns_leger_fallback",
		"test_get_profile_has_required_keys",
		# get_prefetch_depth (3)
		"test_get_prefetch_depth_leger_is_zero",
		"test_get_prefetch_depth_croit_avec_le_palier",
		"test_get_prefetch_depth_invalid_id_returns_zero",
		# get_profile_name (3)
		"test_get_profile_name_returns_non_empty_string_for_all",
		"test_get_profile_name_porte_le_libelle_du_palier",
		"test_get_profile_name_invalid_falls_back_to_leger_name",
		# is_time_sharing (2)
		"test_is_time_sharing_false_pour_les_paliers_a_un_modele",
		"test_is_time_sharing_false_pour_eleve_qui_est_parallele",
		# get_model_for_role (6)
		"test_get_model_for_role_narrator_in_eleve_is_26b",
		"test_get_model_for_role_gamemaster_in_eleve_is_e4b",
		"test_get_model_for_role_narrator_in_moyen_is_12b",
		"test_get_model_for_role_narrator_in_leger_is_e4b",
		"test_get_model_for_role_missing_role_falls_back_to_first_brain",
		"test_tous_les_tags_desktop_sont_de_la_famille_gemma4",
		# get_brain_config (4)
		"test_get_brain_config_narrator_in_eleve",
		"test_get_brain_config_missing_role_returns_empty_dict",
		"test_get_brain_config_all_brains_have_required_keys",
		"test_chaque_model_key_existe_dans_ram_by_model",
		# get_required_models (3)
		"test_get_required_models_leger_returns_one_model",
		"test_get_required_models_eleve_returns_two_models",
		"test_get_required_models_no_empty_strings",
		# get_peak_ram_mb (4)
		"test_get_peak_ram_mb_leger_is_6100",
		"test_get_peak_ram_mb_eleve_somme_les_deux_modeles",
		"test_get_peak_ram_mb_invalid_id_returns_leger_fallback",
		"test_le_pic_ram_tient_dans_le_seuil_du_palier",
		# integrite de PROFILES (6)
		"test_profiles_min_ram_increases_with_tier",
		"test_profiles_seuils_correspondent_a_la_demande",
		"test_profiles_brain_count_matches_tier_expectations",
		"test_model_constants_are_non_empty_strings",
		"test_le_31b_dense_n_est_choisi_par_aucun_palier",
		"test_ram_by_model_keys_are_non_empty",
	]

	var passed: int = 0
	var failed: int = 0
	var failures: Array[String] = []
	for test_name in tests:
		if call(test_name):
			passed += 1
		else:
			failed += 1
			failures.append(test_name)
	var total: int = passed + failed
	print("[BrainSwarmConfigUnit] %d/%d passed (%d failed)" % [passed, total, failed])
	for f in failures:
		print("  FAIL: %s" % f)
	return {"passed": passed, "failed": failed, "total": total, "failures": failures}
