# test_reputation_system.gd
# GUT Unit Tests for MerlinReputationSystem
# Covers: apply_delta, get_available_endings, get_unlocked_content,
#         get_dominant_faction, describe_factions, validation helpers

extends GutTest


# ═══════════════════════════════════════════════════════════════════════════════
# HELPERS
# ═══════════════════════════════════════════════════════════════════════════════

func _make_factions(druides: float, anciens: float, korrigans: float, niamh: float, ankou: float) -> Dictionary:
	return {
		"druides": druides,
		"anciens": anciens,
		"korrigans": korrigans,
		"niamh": niamh,
		"ankou": ankou,
	}


# ═══════════════════════════════════════════════════════════════════════════════
# apply_delta
# ═══════════════════════════════════════════════════════════════════════════════

func test_apply_delta_basic():
	var factions: Dictionary = _make_factions(30.0, 0.0, 0.0, 0.0, 0.0)
	var result: Dictionary = MerlinReputationSystem.apply_delta(factions, "druides", 20.0)
	assert_eq(result["druides"], 50.0, "Druides devrait etre 50 apres +20")
	# Original non muté
	assert_eq(factions["druides"], 30.0, "L'original ne doit pas etre mute")


func test_apply_delta_clamped_max():
	var factions: Dictionary = _make_factions(90.0, 0.0, 0.0, 0.0, 0.0)
	var result: Dictionary = MerlinReputationSystem.apply_delta(factions, "druides", 20.0)
	assert_eq(result["druides"], 100.0, "Clamp max a 100")


func test_apply_delta_clamped_min():
	var factions: Dictionary = _make_factions(5.0, 0.0, 0.0, 0.0, 0.0)
	var result: Dictionary = MerlinReputationSystem.apply_delta(factions, "druides", -20.0)
	assert_eq(result["druides"], 0.0, "Clamp min a 0")


func test_apply_delta_invalid_faction():
	var factions: Dictionary = _make_factions(50.0, 0.0, 0.0, 0.0, 0.0)
	var result: Dictionary = MerlinReputationSystem.apply_delta(factions, "humains", 10.0)
	# Faction inconnue : dict retourné identique, pas d'entrée ajoutée
	assert_false(result.has("humains"), "Faction inconnue ne doit pas etre ajoutee")
	assert_eq(result["druides"], 50.0, "Autres factions inchangees")


func test_apply_delta_negative():
	var factions: Dictionary = _make_factions(60.0, 0.0, 0.0, 0.0, 0.0)
	var result: Dictionary = MerlinReputationSystem.apply_delta(factions, "druides", -15.0)
	assert_eq(result["druides"], 45.0, "Delta negatif applique correctement")


# ═══════════════════════════════════════════════════════════════════════════════
# get_available_endings
# ═══════════════════════════════════════════════════════════════════════════════

func test_no_endings_below_threshold():
	var factions: Dictionary = _make_factions(79.9, 79.9, 79.9, 79.9, 79.9)
	var endings: Array[String] = MerlinReputationSystem.get_available_endings(factions)
	assert_eq(endings.size(), 0, "Aucune fin sous 80")


func test_single_ending_at_threshold():
	var factions: Dictionary = _make_factions(80.0, 0.0, 0.0, 0.0, 0.0)
	var endings: Array[String] = MerlinReputationSystem.get_available_endings(factions)
	assert_eq(endings.size(), 1, "Une fin disponible a 80")
	assert_true(endings.has("druides"), "Druides debloques")


func test_multiple_endings_available():
	# Design Q2 2026-03-11 : plusieurs fins valides sans hierarchie
	var factions: Dictionary = _make_factions(85.0, 90.0, 0.0, 80.0, 0.0)
	var endings: Array[String] = MerlinReputationSystem.get_available_endings(factions)
	assert_eq(endings.size(), 3, "Trois fins disponibles simultanement")
	assert_true(endings.has("druides"), "Druides debloques")
	assert_true(endings.has("anciens"), "Anciens debloques")
	assert_true(endings.has("niamh"), "Niamh debloquee")


func test_all_endings_at_100():
	var factions: Dictionary = _make_factions(100.0, 100.0, 100.0, 100.0, 100.0)
	var endings: Array[String] = MerlinReputationSystem.get_available_endings(factions)
	assert_eq(endings.size(), 5, "Toutes les fins disponibles a 100")


# ═══════════════════════════════════════════════════════════════════════════════
# get_unlocked_content
# ═══════════════════════════════════════════════════════════════════════════════

func test_no_content_below_threshold():
	var factions: Dictionary = _make_factions(49.9, 0.0, 0.0, 0.0, 0.0)
	var content: Array[String] = MerlinReputationSystem.get_unlocked_content(factions)
	assert_eq(content.size(), 0, "Aucun contenu sous 50")


func test_content_at_threshold():
	var factions: Dictionary = _make_factions(50.0, 0.0, 0.0, 0.0, 0.0)
	var content: Array[String] = MerlinReputationSystem.get_unlocked_content(factions)
	assert_eq(content.size(), 1, "Contenu debloque a 50")
	assert_true(content.has("druides"), "Druides debloque")


func test_ending_also_unlocks_content():
	# Faction a 80 doit apparaitre dans get_unlocked_content aussi (80 >= 50)
	var factions: Dictionary = _make_factions(0.0, 80.0, 0.0, 0.0, 0.0)
	var content: Array[String] = MerlinReputationSystem.get_unlocked_content(factions)
	assert_true(content.has("anciens"), "Anciens a 80 debloques dans le contenu aussi")


# ═══════════════════════════════════════════════════════════════════════════════
# get_dominant_faction
# ═══════════════════════════════════════════════════════════════════════════════

func test_dominant_faction_single():
	var factions: Dictionary = _make_factions(0.0, 0.0, 75.0, 0.0, 0.0)
	var dominant: String = MerlinReputationSystem.get_dominant_faction(factions)
	assert_eq(dominant, "korrigans", "Korrigans dominant")


func test_dominant_faction_all_zero():
	var factions: Dictionary = _make_factions(0.0, 0.0, 0.0, 0.0, 0.0)
	var dominant: String = MerlinReputationSystem.get_dominant_faction(factions)
	assert_eq(dominant, "", "Aucun dominant si toutes a 0")


func test_dominant_faction_uses_max():
	var factions: Dictionary = _make_factions(60.0, 70.0, 65.0, 55.0, 45.0)
	var dominant: String = MerlinReputationSystem.get_dominant_faction(factions)
	assert_eq(dominant, "anciens", "Anciens dominant a 70")


# ═══════════════════════════════════════════════════════════════════════════════
# describe_factions
# ═══════════════════════════════════════════════════════════════════════════════

func test_describe_factions_format():
	var factions: Dictionary = _make_factions(45.0, 12.0, 78.0, 5.0, 30.0)
	var desc: String = MerlinReputationSystem.describe_factions(factions)
	assert_true(desc.contains("Druides:45"), "Contient Druides:45")
	assert_true(desc.contains("Anciens:12"), "Contient Anciens:12")
	assert_true(desc.contains("Korrigans:78"), "Contient Korrigans:78")
	assert_true(desc.contains("Niamh:5"), "Contient Niamh:5")
	assert_true(desc.contains("Ankou:30"), "Contient Ankou:30")


func test_describe_factions_all_zero():
	var factions: Dictionary = _make_factions(0.0, 0.0, 0.0, 0.0, 0.0)
	var desc: String = MerlinReputationSystem.describe_factions(factions)
	assert_true(desc.length() > 0, "Description non vide meme a 0")
	assert_true(desc.contains("Druides:0"), "Contient Druides:0")


# ═══════════════════════════════════════════════════════════════════════════════
# build_default_factions
# ═══════════════════════════════════════════════════════════════════════════════

func test_build_default_factions():
	var factions: Dictionary = MerlinReputationSystem.build_default_factions()
	assert_eq(factions.size(), 5, "5 factions par defaut")
	for faction in MerlinReputationSystem.FACTIONS:
		assert_true(factions.has(faction), "Faction presente: " + faction)
		assert_eq(factions[faction], 0.0, "Valeur initiale 0.0 pour " + faction)


# ═══════════════════════════════════════════════════════════════════════════════
# is_valid_faction
# ═══════════════════════════════════════════════════════════════════════════════

func test_valid_factions():
	for faction in MerlinReputationSystem.FACTIONS:
		assert_true(MerlinReputationSystem.is_valid_faction(faction), faction + " devrait etre valide")


func test_invalid_faction():
	assert_false(MerlinReputationSystem.is_valid_faction("humains"), "humains n'est pas dans les 5 factions")
	assert_false(MerlinReputationSystem.is_valid_faction(""), "chaine vide invalide")


# ═══════════════════════════════════════════════════════════════════════════════
# get_tier_label
# ═══════════════════════════════════════════════════════════════════════════════

func test_tier_label_venere():
	assert_eq(MerlinReputationSystem.get_tier_label(80.0), "Venere", "80 = Venere")
	assert_eq(MerlinReputationSystem.get_tier_label(100.0), "Venere", "100 = Venere")


func test_tier_label_honore():
	assert_eq(MerlinReputationSystem.get_tier_label(60.0), "Honore", "60 = Honore")
	assert_eq(MerlinReputationSystem.get_tier_label(79.9), "Honore", "79.9 = Honore")


func test_tier_label_sympathisant():
	assert_eq(MerlinReputationSystem.get_tier_label(40.0), "Sympathisant", "40 = Sympathisant")


func test_tier_label_neutre():
	assert_eq(MerlinReputationSystem.get_tier_label(20.0), "Neutre", "20 = Neutre")


func test_tier_label_hostile():
	assert_eq(MerlinReputationSystem.get_tier_label(0.0), "Hostile", "0 = Hostile")
	assert_eq(MerlinReputationSystem.get_tier_label(19.9), "Hostile", "19.9 = Hostile")
