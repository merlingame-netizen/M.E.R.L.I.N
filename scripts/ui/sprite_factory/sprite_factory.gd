class_name SpriteFactory
extends RefCounted
## Procedural 32x32 pixel art sprite generator.
## API: generate(tag, biome, seed) → ImageTexture (cached).
## Dispatches to SpriteTemplates by tag category lookup.

const SPRITE_SIZE := 32
const UPSCALE_FACTOR := 4  ## 32 → 128px displayed


# ═══════════════════════════════════════════════════════════════════════════════
# TAG → CATEGORY MAPPING
# ═══════════════════════════════════════════════════════════════════════════════
## Each tag maps to a category and generator function name.
## Format: tag → { "category": str, "generator": str, "is_character": bool }

static var TAG_REGISTRY := {
	# Trees / Plants (category 1)
	"chene": {"gen": "tree"}, "sapin": {"gen": "tree"}, "saule": {"gen": "tree"},
	"arbre": {"gen": "tree"}, "arbres": {"gen": "tree"}, "bois": {"gen": "tree"},
	"foret": {"gen": "tree"}, "fougere": {"gen": "bush"}, "bruyere": {"gen": "bush"},
	"gui": {"gen": "bush"}, "mousse": {"gen": "bush"}, "champignon": {"gen": "mushroom"},
	"nature": {"gen": "tree"}, "vegetal": {"gen": "bush"},

	# Stones / Minerals (category 2)
	"menhir": {"gen": "standing_stone"}, "pierre": {"gen": "standing_stone"},
	"pierres": {"gen": "standing_stone"}, "dolmen": {"gen": "dolmen"},
	"cairn": {"gen": "cairn"}, "roche": {"gen": "standing_stone"},
	"cristal": {"gen": "standing_stone"}, "galet": {"gen": "cairn"},
	"cercle": {"gen": "cairn"}, "sacre": {"gen": "standing_stone"},

	# Weapons / Combat (category 3)
	"epee": {"gen": "sword"}, "lame": {"gen": "sword"},
	"hache": {"gen": "axe"}, "lance": {"gen": "sword"},
	"arc": {"gen": "axe"}, "bouclier": {"gen": "shield"},
	"combat": {"gen": "sword"}, "danger": {"gen": "axe"},
	"arme": {"gen": "sword"},

	# Fire / Light (category 4)
	"feu": {"gen": "fire"}, "torche": {"gen": "fire"},
	"lanterne": {"gen": "lantern"}, "bougie": {"gen": "lantern"},
	"brasier": {"gen": "fire"}, "lumiere": {"gen": "lantern"},

	# Water (category 5)
	"eau": {"gen": "water"}, "source": {"gen": "water"},
	"mare": {"gen": "water"}, "lac": {"gen": "water"},
	"cascade": {"gen": "water"}, "puits": {"gen": "well"},

	# Magic / Arcane (category 6)
	"potion": {"gen": "potion"}, "grimoire": {"gen": "grimoire"},
	"rune": {"gen": "standing_stone"}, "amulette": {"gen": "crown"},
	"magie": {"gen": "potion"}, "sort": {"gen": "potion"},
	"ogham": {"gen": "standing_stone"}, "enchantement": {"gen": "grimoire"},

	# Buildings (category 7)
	"hutte": {"gen": "hut"}, "maison": {"gen": "hut"},
	"pont": {"gen": "dolmen"}, "autel": {"gen": "altar"},
	"tour": {"gen": "standing_stone"}, "village": {"gen": "hut"},

	# Sacred / Ritual (category 8)
	"rituel": {"gen": "altar"}, "calice": {"gen": "potion"},
	"couronne": {"gen": "crown"}, "torc": {"gen": "crown"},
	"nemeton": {"gen": "tree"},

	# Characters — Humanoids (category 9)
	"druide": {"gen": "druid", "is_char": true},
	"merlin": {"gen": "druid", "is_char": true},
	"guerrier": {"gen": "warrior", "is_char": true},
	"chevalier": {"gen": "warrior", "is_char": true},
	"garde": {"gen": "warrior", "is_char": true},
	"villageois": {"gen": "villager", "is_char": true},
	"paysan": {"gen": "villager", "is_char": true},
	"forgeron": {"gen": "villager", "is_char": true},
	"noble": {"gen": "noble", "is_char": true},
	"roi": {"gen": "noble", "is_char": true},
	"reine": {"gen": "noble", "is_char": true},
	"seigneur": {"gen": "noble", "is_char": true},
	"rencontre": {"gen": "villager", "is_char": true},
	"barde": {"gen": "druid", "is_char": true},

	# Characters — Beasts (category 10)
	"loup": {"gen": "wolf", "is_char": true},
	"predateur": {"gen": "wolf", "is_char": true},
	"sanglier": {"gen": "wolf", "is_char": true},
	"cerf": {"gen": "deer", "is_char": true},
	"biche": {"gen": "deer", "is_char": true},
	"cheval": {"gen": "deer", "is_char": true},
	"corbeau": {"gen": "bird", "is_char": true},
	"aigle": {"gen": "bird", "is_char": true},
	"hibou": {"gen": "bird", "is_char": true},
	"faucon": {"gen": "bird", "is_char": true},
	"chouette": {"gen": "bird", "is_char": true},

	# Characters — Fae / Mythical (category 11)
	"korrigan": {"gen": "korrigan", "is_char": true},
	"lutin": {"gen": "korrigan", "is_char": true},
	"fee": {"gen": "fae", "is_char": true},
	"esprit": {"gen": "spirit", "is_char": true},
	"spectre": {"gen": "spirit", "is_char": true},
	"fantome": {"gen": "spirit", "is_char": true},
	"ame": {"gen": "spirit", "is_char": true},
	"revenant": {"gen": "undead", "is_char": true},
	"squelette": {"gen": "undead", "is_char": true},
	"mort_vivant": {"gen": "undead", "is_char": true},
	"creature": {"gen": "fae", "is_char": true},
	"feux_follets": {"gen": "fae", "is_char": true},

	# Extra objects (category 13)
	"torche_objet": {"gen": "torch"}, "flambeau": {"gen": "torch"},
	"fontaine": {"gen": "well"},
	"barque": {"gen": "boat"}, "bateau": {"gen": "boat"},
	"tente": {"gen": "tent"}, "camp": {"gen": "tent"},
	"harpe": {"gen": "harp"}, "lyre": {"gen": "harp"},
	"musique": {"gen": "harp"}, "chant": {"gen": "harp"},
	"crane": {"gen": "skull"}, "ossements": {"gen": "skull"},
	"mort": {"gen": "skull"}, "relique": {"gen": "skull"},

	# Atmosphere / Abstract
	"brume": {"gen": "spirit"}, "mystere": {"gen": "spirit"},
	"nuit": {"gen": "lantern"}, "nocturne": {"gen": "lantern"},
	"pluie": {"gen": "water"}, "orage": {"gen": "fire"},
	"neige": {"gen": "generic"}, "vent": {"gen": "generic"},

	# Misc
	"sentier": {"gen": "bush"}, "chemin": {"gen": "bush"},
	"repos": {"gen": "tent"}, "monde": {"gen": "tree"},
	"presage": {"gen": "standing_stone"}, "danse": {"gen": "fae"},
	"malice": {"gen": "korrigan"},
}


# ═══════════════════════════════════════════════════════════════════════════════
# GENERATOR DISPATCH
# ═══════════════════════════════════════════════════════════════════════════════

static var _GENERATORS := {
	# Category 1: Trees / Plants
	"tree": SpriteTemplates.gen_tree,
	"bush": SpriteTemplates.gen_bush,
	"mushroom": SpriteTemplates.gen_mushroom,
	# Category 2: Stones / Minerals
	"standing_stone": SpriteTemplates.gen_standing_stone,
	"dolmen": SpriteTemplates.gen_dolmen,
	"cairn": SpriteTemplates.gen_cairn,
	# Category 3: Weapons / Combat
	"sword": SpriteTemplates.gen_sword,
	"axe": SpriteTemplates.gen_axe,
	"shield": SpriteTemplates.gen_shield,
	# Category 4: Fire / Light
	"fire": SpriteTemplates.gen_fire,
	"lantern": SpriteTemplates.gen_lantern,
	"torch": SpriteTemplates.gen_torch,
	# Category 5: Water
	"water": SpriteTemplates.gen_water,
	"well": SpriteTemplates.gen_well,
	# Category 6: Magic / Arcane
	"potion": SpriteTemplates.gen_potion,
	"grimoire": SpriteTemplates.gen_grimoire,
	# Category 7: Buildings
	"hut": SpriteTemplates.gen_hut,
	# Category 8: Sacred / Ritual
	"altar": SpriteTemplates.gen_altar,
	"crown": SpriteTemplates.gen_crown,
	# Category 9: Humanoid Characters
	"druid": SpriteTemplates.gen_druid,
	"warrior": SpriteTemplates.gen_warrior,
	"villager": SpriteTemplates.gen_villager,
	"noble": SpriteTemplates.gen_noble,
	# Category 10: Beasts
	"wolf": SpriteTemplates.gen_wolf,
	"deer": SpriteTemplates.gen_deer,
	"bird": SpriteTemplates.gen_bird,
	# Category 11: Fae / Mythical
	"korrigan": SpriteTemplates.gen_korrigan,
	"spirit": SpriteTemplates.gen_spirit,
	"fae": SpriteTemplates.gen_fae,
	# Category 12: Undead
	"undead": SpriteTemplates.gen_undead,
	# Category 13: Extra Objects
	"boat": SpriteTemplates.gen_boat,
	"tent": SpriteTemplates.gen_tent,
	"harp": SpriteTemplates.gen_harp,
	"skull": SpriteTemplates.gen_skull,
	# Fallback
	"generic": SpriteTemplates.gen_generic,
}


# ═══════════════════════════════════════════════════════════════════════════════
# CACHE
# ═══════════════════════════════════════════════════════════════════════════════

static var _texture_cache := {}
static var _cache_max := 256


# ═══════════════════════════════════════════════════════════════════════════════
# PUBLIC API
# ═══════════════════════════════════════════════════════════════════════════════

static func generate(tag: String, biome: String, seed_val: int = 0,
		season: String = "automne", weather: String = "clair") -> ImageTexture:
	## Generate or retrieve cached 32x32 sprite for given tag + biome + seed.
	## Returns upscaled ImageTexture (128x128) ready for display.
	var cache_key: String = "%s:%s:%d:%s:%s" % [tag, biome, seed_val, season, weather]
	if _texture_cache.has(cache_key):
		return _texture_cache[cache_key]

	# Evict oldest if cache full
	if _texture_cache.size() >= _cache_max:
		var first_key: String = str(_texture_cache.keys()[0])
		_texture_cache.erase(first_key)

	# Generate
	var palette: Array[Color] = SpritePalette.get_palette(biome, season, weather)
	var rng := RandomNumberGenerator.new()
	rng.seed = _compute_seed(tag, biome, seed_val)

	var gen_name: String = _get_generator_name(tag)
	var gen_func: Callable = _GENERATORS.get(gen_name, SpriteTemplates.gen_generic)
	var img: Image = gen_func.call(palette, rng, seed_val)

	# Upscale with nearest-neighbor for pixel art look
	img.resize(SPRITE_SIZE * UPSCALE_FACTOR, SPRITE_SIZE * UPSCALE_FACTOR,
		Image.INTERPOLATE_NEAREST)

	var tex := ImageTexture.create_from_image(img)
	_texture_cache[cache_key] = tex
	return tex


static func generate_raw(tag: String, biome: String, seed_val: int = 0,
		season: String = "automne", weather: String = "clair") -> Image:
	## Generate 32x32 Image (not upscaled, not cached). For thumbnails/previews.
	var palette: Array[Color] = SpritePalette.get_palette(biome, season, weather)
	var rng := RandomNumberGenerator.new()
	rng.seed = _compute_seed(tag, biome, seed_val)
	var gen_name: String = _get_generator_name(tag)
	var gen_func: Callable = _GENERATORS.get(gen_name, SpriteTemplates.gen_generic)
	return gen_func.call(palette, rng, seed_val)


static func has_tag(tag: String) -> bool:
	## Check if a tag is registered in the factory.
	return TAG_REGISTRY.has(tag)


static func is_character_tag(tag: String) -> bool:
	## Check if a tag represents a character (vs object/environment).
	var entry: Dictionary = TAG_REGISTRY.get(tag, {})
	return entry.get("is_char", false)


static func get_best_subject_tag(tags: Array, biome: String) -> String:
	## From a list of visual_tags, pick the most important one for subject layer.
	## Priority: character tags first, then registered tags, then first tag.
	var best_char: String = ""
	var best_obj: String = ""
	for tag in tags:
		var stag: String = str(tag)
		if not TAG_REGISTRY.has(stag):
			continue
		if is_character_tag(stag) and best_char.is_empty():
			best_char = stag
		elif best_obj.is_empty():
			best_obj = stag
	# Character tags take priority only if context suggests it
	if not best_char.is_empty():
		return best_char
	if not best_obj.is_empty():
		return best_obj
	# Fallback: first tag or biome default
	if not tags.is_empty():
		return str(tags[0])
	var defaults: Dictionary = {
		"foret_broceliande": "chene", "marais_korrigans": "mare",
		"landes_bruyere": "bruyere", "cotes_sauvages": "roche",
		"villages_celtes": "hutte", "cercles_pierres": "menhir",
		"collines_dolmens": "dolmen", "iles_mystiques": "roche",
	}
	return defaults.get(biome, "chene")


static func clear_cache() -> void:
	## Clear all cached textures.
	_texture_cache.clear()


# ═══════════════════════════════════════════════════════════════════════════════
# INTERNALS
# ═══════════════════════════════════════════════════════════════════════════════

static func _get_generator_name(tag: String) -> String:
	var entry: Dictionary = TAG_REGISTRY.get(tag, {})
	return str(entry.get("gen", "generic"))


static func _compute_seed(tag: String, biome: String, variant: int) -> int:
	## Deterministic seed from tag + biome + variant.
	var h: int = tag.hash() ^ biome.hash() ^ (variant * 2654435761)
	return h & 0x7FFFFFFF
