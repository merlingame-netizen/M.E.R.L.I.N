class_name MerlinCard
extends RefCounted
## Carte MERLIN (bible R3/R33/R51/R102). Une carte = nom + évocation + tags + coût Corruption + rareté.
## Rôle flexible : toute carte peut être principale OU modificateur (R3).

var id: String = ""
var card_name: String = ""
var evocation: String = ""
var tags: Array = []          # Array[String] (concepts, R81)
var corruption: int = 0       # coût Corruption payé en jouant (0-3, R64)
var rarity: String = "Commune"  # Commune / Rare / Épique / Mythique (R52)
var _archetype_cache: String = ""  # v10.5 : archétype dérivé memoïsé (to_dict appelé ~1Hz × deck)


static func make(p_id: String, p_name: String, p_tags: Array, p_evocation: String, p_corruption: int = 0, p_rarity: String = "Commune") -> MerlinCard:
	var c: MerlinCard = MerlinCard.new()
	c.id = p_id
	c.card_name = p_name
	c.tags = p_tags.duplicate()
	c.evocation = p_evocation
	c.corruption = p_corruption
	c.rarity = p_rarity
	return c


# v10.5 (user 2026-06-06) — archétype d'EFFET dérivé du tag primaire (visuel d'abord : reflète
# « ce que fait la carte » sans toucher le moteur de résolution tag-coverage). Offensif / Défensif /
# Social / Mystique / Corrompu. Une carte à coût Corruption > 0 ou tag corrompu → Corrompu.
func archetype() -> String:
	if _archetype_cache != "":
		return _archetype_cache
	_archetype_cache = _compute_archetype()
	return _archetype_cache


func _compute_archetype() -> String:
	for t in tags:
		if MerlinTags.is_corrupted_tag(str(t)):
			return "Corrompu"
	if corruption > 0:
		return "Corrompu"
	var fam: String = MerlinTags.family_of(str(tags[0])) if tags.size() > 0 else ""
	match fam:
		"Corps": return "Offensif"
		"Parole": return "Social"
		"Monde": return "Défensif"
		"Perception", "Intuition": return "Mystique"
		_: return "Mystique"


func to_dict() -> Dictionary:
	return {
		"id": id, "name": card_name, "evocation": evocation,
		"tags": tags.duplicate(), "corruption": corruption, "rarity": rarity,
		"archetype": archetype(),
	}


static func from_dict(d: Dictionary) -> MerlinCard:
	return make(
		str(d.get("id", "")), str(d.get("name", "")),
		d.get("tags", []), str(d.get("evocation", "")),
		int(d.get("corruption", 0)), str(d.get("rarity", "Commune")))


## Deck de départ canon — 12 cartes (R33 tags + R102 évocations). Communes, voyageur généraliste.
static func starter_deck() -> Array:
	return [
		make("regard_percant", "Le Regard Perçant", ["Sens"],
			"Tes yeux fendent l'ombre ; rien ne reste caché à qui sait vraiment voir."),
		make("ecoute_silence", "L'Écoute du Silence", ["Sens", "Savoir"],
			"Entre deux souffles du vent, la forêt confie ce qu'elle tait aux autres."),
		make("memoire_lieux", "La Mémoire des Lieux", ["Mémoire", "Savoir"],
			"Les pierres se souviennent. Pose la main, et leur passé remonte en toi."),
		make("main_de_fer", "La Main de Fer", ["Force"],
			"Quand la douceur échoue, reste la poigne qui ne tremble pas."),
		make("pas_leger", "Le Pas Léger", ["Agilité"],
			"Tu glisses où d'autres trébuchent ; le danger ne saisit que le vide."),
		make("souffle_tenace", "Le Souffle Tenace", ["Endurance", "Force"],
			"Le corps plie sans rompre ; tu tiens quand tout voudrait te briser."),
		make("langue_de_miel", "La Langue de Miel", ["Empathie", "Verbe"],
			"Tes mots coulent doux ; même les cœurs fermés s'entrouvrent."),
		make("mot_ruse", "Le Mot Rusé", ["Ruse"],
			"Une vérité de travers, un silence bien placé — et la porte cède."),
		make("presence_calme", "La Présence Calme", ["Empathie"],
			"Ta seule présence apaise ; la tempête baisse d'un ton."),
		make("pressentiment", "Le Pressentiment", ["Instinct"],
			"Quelque chose te souffle avant que tu saches — écoute ce frisson."),
		make("voix_foret", "La Voix de la Forêt", ["Nature", "Instinct"],
			"Tu parles la langue des sèves et des racines ; Brocéliande répond."),
		make("appel_ombre", "L'Appel de l'Ombre", ["Instinct", "Nature"],
			"Tu appelles ce qui dort sous les racines. Il vient — mais il prélève son dû.", 1),
	]
