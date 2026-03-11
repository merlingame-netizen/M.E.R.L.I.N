class_name ReputationHud
extends Control

# Affiche les niveaux de réputation des 5 factions
# Design temporaire (labels texte) — le design final sera co-designé

var _faction_labels: Dictionary = {}

func _ready() -> void:
	_build_ui()
	# Connexion au store si disponible
	var store = get_node_or_null("/root/MerlinStore")
	if store and store.has_signal("reputation_changed"):
		store.reputation_changed.connect(_on_reputation_changed)

func _build_ui() -> void:
	var vbox: VBoxContainer = VBoxContainer.new()
	add_child(vbox)
	for faction: String in ["druides", "anciens", "korrigans", "niamh", "ankou"]:
		var label: Label = Label.new()
		label.name = "Label_" + faction
		label.text = faction.capitalize() + ": 0"
		vbox.add_child(label)
		_faction_labels[faction] = label

func _on_reputation_changed(faction: String, value: float, _delta: float) -> void:
	if _faction_labels.has(faction):
		var label: Label = _faction_labels[faction]
		label.text = faction.capitalize() + ": " + str(int(value))

func update_all(factions: Dictionary) -> void:
	for faction: String in factions:
		if _faction_labels.has(faction):
			var label: Label = _faction_labels[faction]
			label.text = faction.capitalize() + ": " + str(int(factions[faction]))
