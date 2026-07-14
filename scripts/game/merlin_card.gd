class_name MerlinCard
extends RefCounted
## Carte MERLIN (bible R3/R33/R51/R102). Une carte = nom + évocation + tags + coût Corruption + rareté.
## Rôle flexible : toute carte peut être principale OU modificateur (R3).

# N4-RUNES (fix flake bugres) : référence par PRELOAD et non par nom de classe globale. La course
# du résolveur GDScript sur les arêtes de dépendance par class_name (MerlinGlyph.xxx) produisait un
# Parse Error intermittent (~1 boot/24) -> merlin_run KO -> zéro tuile d'action -> softlock beat 1.
# Le preload rend l'ordre de chargement DÉTERMINISTE.
const _Glyph: GDScript = preload("res://scripts/game/merlin_glyph.gd")

var id: String = ""
var card_name: String = ""
var evocation: String = ""
var tags: Array = []          # Array[String] (concepts, R81)
var corruption: int = 0       # coût Corruption payé en jouant (0-3, R64)
var rarity: String = "Commune"  # Commune / Rare / Épique / Mythique (R52)
var effect_type: String = ""   # "" | HEAL | PURGE | DRAW — effet actif joué (Rare+, user 2026-06-07)
var effect_value: int = 0      # intensité (PV soignés / Corruption purgée / cartes piochées)
# v11 (pivot ACTION+TRAIT, spec panel 2026-07-04) — famille canonique FIXE d'une ACTION (verbe).
# "" pour les traits et cartes legacy. La famille de synergie de l'action ne change JAMAIS,
# même quand des tags sont greffés (W3).
var family: String = ""
# v11-W3 (spec §E) — GREFFES posées sur une ACTION (cap 3). Dicts {id, name, evocation,
# kind: "tag"|"roll"|"charge", tag, effect_type, effect_value, charges, corr_cost, amount, pilier}.
# v2-W3 (2026-07-05) — kind "die" (bande de dé) MIGRÉ en "roll" (+N au jet d20 via graft_bonus, W1).
# Les vieilles greffes "die" (saves v11 posées avant le pivot) sont TOLÉRÉES au load : merlin_run.
# graft_roll_bonus les compte comme roll (proxy amount ROLL_BONUS_DEFAULT) — jamais de crash.
# Champ ADDITIF (défaut []) : les saves W2 chargent sans bump de SAVE_VERSION.
# GUARDRAIL CRITICAL : le prix d'une greffe est ONE-SHOT à la pose (corr_cost, payé par
# merlin_run.apply_graft) ou PAR CHARGE — jamais récurrent (corruption de l'action reste 0).
var grafts: Array = []
# N4-RUNES (2026-07-11) : identité de RUNE d'un TRAIT (UI uniquement, mécanique tags INTACTE).
#   display_name = nom français compréhensible affiché en HAUT de carte (Acuité, Vigueur, Adresse...)
#   rune_name    = nom de rune celtique INVENTÉ affiché sous le glyphe (sonorité bretonne/galloise)
#   rune_pattern = index de motif ogham procédural (MerlinGlyph.draw_rune_on, 0-49)
# Champs ADDITIFS : défauts dérivés via _apply_rune_identity() (table RUNES par id, préfixes
# secours_/corrompu_ inclus), donc les saves legacy chargent sans bump de SAVE_VERSION. card_name
# RESTE le nom canon interne (ids, prompts LLM, cartes_notables, clés de verbe) : seul l'AFFICHAGE
# passe aux runes (spec N4, user 2026-07-11 : le jargon quitte l'écran, la preview R120 porte l'affinité).
var display_name: String = ""
var rune_name: String = ""
var rune_pattern: int = -1
var _archetype_cache: String = ""  # v10.5 : archétype dérivé memoïsé (to_dict appelé ~1Hz × deck)


# N4-RUNES : table canon id -> [nom français, rune celte inventée, motif ogham 0-49].
# Motif UNIQUE par carte (50 combinaisons procédurales : série x nombre de traits x marque-point).
# Les clés "secours" / "corrompu" couvrent les cartes DYNAMIQUES (ids suffixés _N à la création).
# RÈGLE (revue design N4, finding bloquant 1) : un display_name ne DOIT JAMAIS être identique à
# l'une des 25 valeurs canon de MerlinTags.FAMILIES (le mot-tag exact ne revient pas à l'écran).
# Les recouvrements avec la table SYNONYMS (interne, jamais affichée) restent acceptés.
const RUNES: Dictionary = {
	# Traits de départ (16)
	"regard_percant": ["Acuité", "Sulwen", 0],
	"ecoute_silence": ["Écoute", "Klewen", 1],
	"memoire_lieux": ["Souvenance", "Kovren", 2],
	"main_de_fer": ["Poigne", "Dornek", 3],
	"pas_leger": ["Légèreté", "Skanvel", 4],
	"souffle_tenace": ["Ténacité", "Padwen", 5],
	"langue_de_miel": ["Charme", "Melgan", 6],
	"mot_ruse": ["Malice", "Kelvor", 7],
	"presence_calme": ["Calme", "Sioulan", 8],
	"pressentiment": ["Flair", "Awenel", 9],
	"voix_foret": ["Voix", "Gwezhen", 10],
	"appel_ombre": ["Ombre", "Duvael", 11],
	"main_sure": ["Adresse", "Kervoal", 12],
	"verbe_haut": ["Prestance", "Uhelvan", 13],
	"coeur_franc": ["Droiture", "Gwiren", 14],
	"geste_ancien": ["Coutume", "Henwaz", 15],
	# Pool enrichi (14)
	"oeil_du_druide": ["Clairvoyance", "Drewyn", 16],
	"voix_autorite": ["Éloquence", "Taelgur", 17],
	"pas_de_loup": ["Discrétion", "Bleizan", 18],
	"bras_de_fer": ["Vigueur", "Braën", 19],
	"lecture_augure": ["Présage", "Argoel", 20],
	"serment_tenu": ["Serment", "Ledoun", 21],
	"transe_druidique": ["Transe", "Hunvael", 22],
	"colere_juste": ["Colère", "Fulvan", 23],
	"empathie_profonde": ["Compassion", "Kalonad", 24],
	"marche_equilibre": ["Constance", "Kemwez", 25],
	"appel_profond": ["Appel", "Donvor", 26],
	"verbe_primordial": ["Incantation", "Gerwan", 27],
	"memoire_ancienne": ["Souvenir", "Envorec", 28],
	"dissolution_consentie": ["Effacement", "Teuzwen", 29],
	# Banques d'offrande des piliers (15)
	"choeur_baume_vert": ["Baume", "Luzawen", 30],
	"choeur_eau_claire": ["Source", "Dourwen", 31],
	"choeur_main_qui_releve": ["Réconfort", "Skoazen", 32],
	"etre_pacte_de_lisiere": ["Pacte", "Gwelvor", 33],
	"etre_offrande_sang": ["Offrande", "Gwadec", 34],
	"etre_faveur_indicible": ["Faveur", "Kuzhwen", 35],
	"compagnon_promesse_ancienne": ["Promesse", "Gedwen", 36],
	"compagnon_main_tendue": ["Entraide", "Dornwel", 37],
	"compagnon_retour_promis": ["Retour", "Distrew", 38],
	"chevalier_lame_ternie": ["Lame", "Klevdur", 39],
	"chevalier_charge_du_dechu": ["Charge", "Ruthrec", 40],
	"chevalier_serment_de_cendre": ["Cendre", "Ludwen", 41],
	"enfant_jouet_offert": ["Jouet", "Koarig", 42],
	"enfant_secret_chuchote": ["Secret", "Kuzhig", 43],
	"enfant_main_chaude": ["Tendresse", "Tomwen", 44],
	# Cartes dynamiques (préfixes d'id). Toutes les corrompues injectées partagent le MÊME gabarit
	# mécanique (mêmes tags/coût), donc la MÊME identité de rune : visuel identique = carte identique.
	"secours": ["Souffle", "Anadlen", 45],
	"corrompu": ["Chuchotis", "Morgrez", 46],
}


# N4-RUNES : complète les champs de rune MANQUANTS depuis la table canon (id exact, sinon préfixe
# dynamique). No-op pour les actions et les ids inconnus (cartes de présentation de greffe/talent :
# display_label() retombe sur card_name, glyph_pattern() dérive du tag primaire).
func _apply_rune_identity() -> void:
	if display_name != "" and rune_name != "" and rune_pattern >= 0:
		return
	var key: String = id
	if key.begins_with("secours_"):
		key = "secours"
	elif key.begins_with("corrompu_"):
		key = "corrompu"
	if not RUNES.has(key):
		return
	var e: Array = RUNES[key]
	if display_name == "":
		display_name = str(e[0])
	if rune_name == "":
		rune_name = str(e[1])
	if rune_pattern < 0:
		rune_pattern = int(e[2])


# N4-RUNES : nom affiché en HAUT de carte (UI). Le canon card_name reste le repli (greffes/talent).
func display_label() -> String:
	return display_name if display_name != "" else card_name


# N4-RUNES : nom de rune celtique affiché SOUS le glyphe ("" = pas de ligne, cartes de présentation).
func rune_label() -> String:
	return rune_name


# N4-RUNES : motif ogham à dessiner. Motif propre de la carte, sinon rune du CONCEPT (tag primaire,
# cartes de présentation de greffe/talent, plage 50-74), sinon rune GÉNÉRIQUE 47 (greffes
# roll/charge sans tag). Revue de code N4 (MEDIUM-2) : jamais le motif d'une carte canon en repli.
func glyph_pattern() -> int:
	if rune_pattern >= 0:
		return rune_pattern
	if tags.size() > 0:
		return _Glyph.pattern_for_tag(str(tags[0]))
	return _Glyph.PATTERN_GENERIC


# v11 — une carte est une ACTION (tuile permanente) si elle porte une famille canonique.
func is_action() -> bool:
	return family != ""


# v11 — un TRAIT est corrompu s'il porte un tag Corrompu OU un coût récurrent (spec §C/§D).
func is_corrupted_trait() -> bool:
	if corruption > 0:
		return true
	for t in tags:
		if MerlinTags.is_corrupted_tag(str(t)):
			return true
	return false


static func make(p_id: String, p_name: String, p_tags: Array, p_evocation: String, p_corruption: int = 0, p_rarity: String = "Commune", p_effect_type: String = "", p_effect_value: int = 0) -> MerlinCard:
	var c: MerlinCard = MerlinCard.new()
	c.id = p_id
	c.card_name = p_name
	c.tags = p_tags.duplicate()
	c.evocation = p_evocation
	c.corruption = p_corruption
	c.rarity = p_rarity
	c.effect_type = p_effect_type
	c.effect_value = p_effect_value
	c._apply_rune_identity()  # N4-RUNES : identité dérivée de la table canon (no-op si id inconnu)
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
		"effect_type": effect_type, "effect_value": effect_value,
		"family": family,  # v11 : "" pour les traits — champ additif
		"grafts": grafts.duplicate(true),  # v11-W3 : additif (défaut [] — saves W2 compatibles)
		# N4-RUNES : champs additifs (les saves legacy sans ces clés re-dérivent au load)
		"display_name": display_name, "rune_name": rune_name, "rune_pattern": rune_pattern,
		"archetype": archetype(),
	}


static func from_dict(d: Dictionary) -> MerlinCard:
	var c: MerlinCard = make(
		str(d.get("id", "")), str(d.get("name", "")),
		d.get("tags", []), str(d.get("evocation", "")),
		int(d.get("corruption", 0)), str(d.get("rarity", "Commune")),
		str(d.get("effect_type", "")), int(d.get("effect_value", 0)))
	c.family = str(d.get("family", ""))
	var gv: Variant = d.get("grafts", [])
	c.grafts = (gv as Array).duplicate(true) if gv is Array else []
	# N4-RUNES : champs additifs. Absents (save legacy) = valeurs déjà dérivées par make() ;
	# présents = les valeurs persistées priment, puis _apply_rune_identity comble les trous.
	c.display_name = str(d.get("display_name", c.display_name))
	c.rune_name = str(d.get("rune_name", c.rune_name))
	c.rune_pattern = int(d.get("rune_pattern", c.rune_pattern))
	c._apply_rune_identity()
	c.refresh_from_grafts()  # v11-W3 : dérivation UNIQUE tags/rarity au load (no-op pour les traits)
	return c


## v11-W3 (spec §E) — DÉRIVATION UNIQUE depuis les greffes, à la pose ET au load :
##   tags   = 2 tags de BASE + tags greffés (kind "tag", dédupliqués) ;
##   rarity = ["Commune","Rare","Épique","Mythique"][min(nb greffes, 3)] — la qualité de dé
##            EST le nombre de greffes (langage R133 : liseré de tuile = qualité).
## No-op pour les traits (pas de famille canonique). Ne touche JAMAIS `corruption` (guardrail :
## zéro coût récurrent sur les greffes).
func refresh_from_grafts() -> void:
	if not is_action():
		return
	var base: Array = tags.slice(0, 2)
	var out: Array = base.duplicate()
	for g in grafts:
		if g is Dictionary and str((g as Dictionary).get("kind", "")) == "tag":
			var t: String = str((g as Dictionary).get("tag", ""))
			if t != "" and not out.has(t):
				out.append(t)
	tags = out
	var ladder: Array = ["Commune", "Rare", "Épique", "Mythique"]
	rarity = str(ladder[mini(grafts.size(), 3)])
	_archetype_cache = ""  # les tags ont pu changer → archétype re-dérivé à la demande


## === v11 (spec panel W2) — Les 4 ACTIONS fixes évolutives (tuiles permanentes) ===
## Action-as-card : MerlinCard avec `family` canonique FIXE, 2 tags de base EXACTEMENT (jamais la
## famille entière — arbitrage lentilles 2+4 : couverture pleine ~67 %, partiel ~31 %). rarity =
## qualité de dé dérivée du nb de greffes (W2 transitoire : "Commune" = bande 33 %, greffes en W3).
static func make_actions() -> Array:
	return [
		_action("action_percevoir", "PERCEVOIR", "Perception", ["Sens", "Savoir"],
			"Regarder vraiment, et laisser ce qui se cache remonter à la surface."),
		_action("action_agir", "AGIR", "Corps", ["Force", "Agilité"],
			"Le corps tranche là où l'esprit hésite ; un geste, et le monde change."),
		_action("action_parler", "PARLER", "Parole", ["Empathie", "Verbe"],
			"Les mots ouvrent ce que la force brise ; parler, c'est déjà agir sur les cœurs."),
		_action("action_ressentir", "RESSENTIR", "Intuition", ["Instinct", "Nature"],
			"Fermer les yeux et écouter ce que Brocéliande murmure sous la peau du monde."),
	]


static func _action(p_id: String, p_name: String, p_family: String, p_tags: Array, p_evocation: String) -> MerlinCard:
	var c: MerlinCard = make(p_id, p_name, p_tags, p_evocation, 0, "Commune")
	c.family = p_family
	return c


## === v11 (spec panel W2) — Deck de TRAITS de départ : 16 (main 4, cycle vrai) ===
## 12 noms canon CONSERVÉS (évocations R102 recyclées — lore 100 % préservé) + 4 nouveaux.
## Structure lentille 4 : les 8 tags gap ×2 slots + ≥1 slot secondaire par tag de base (synergie
## et couverture cross-action). RÈGLE DURE : tout trait porte ≥1 tag NON-dupliqué par une action.
## L'Appel de l'Ombre garde son corr 1 canon (retagué [Mystère, Nature] — Mystère ×1 dans le pool).
##
## v1.0-V4a LEVIER 7a (chantier couverture) — RETAGS mesurés au soak, comptages ×1 préservés
## (Franchise/Mystère/Rituel restent les seuls ×1, tous les autres tags gap restent ×2) :
##   geste_ancien   [Rituel, Mémoire] → [Rituel, Savoir]     : paire double-gap MORTE éliminée
##       (Rituel ×1, émission bornée 1 beat/quête — la moitié Mémoire ne payait jamais double) ;
##       base pertinente Savoir (« un geste plus vieux que toi » = savoir ancien).
##   ecoute_silence [Vigilance]       → [Vigilance, Mémoire] : slot vide rempli — reprend le
##       Mémoire orphelin de geste_ancien (×2 préservé) ; paire double-gap VIVE assumée (2 tags
##       requérables ×2 = 2 chances de couvrir un requis gap, contrairement à la paire morte).
##   souffle_tenace [Endurance]       → [Endurance, Force]   : slot vide → base (tagging canon v10).
##   main_sure      [Finesse]         → [Finesse, Agilité]   : slot vide → base (adresse = Corps).
static func starter_traits() -> Array:
	return [
		make("regard_percant", "Le Regard Perçant", ["Vigilance", "Sens"],
			"Tes yeux fendent l'ombre ; rien ne reste caché à qui sait vraiment voir."),
		make("ecoute_silence", "L'Écoute du Silence", ["Vigilance", "Mémoire"],
			"Entre deux souffles du vent, la forêt confie ce qu'elle tait aux autres."),
		make("memoire_lieux", "La Mémoire des Lieux", ["Mémoire", "Savoir"],
			"Les pierres se souviennent. Pose la main, et leur passé remonte en toi."),
		make("main_de_fer", "La Main de Fer", ["Force", "Endurance"],
			"Quand la douceur échoue, reste la poigne qui ne tremble pas."),
		make("pas_leger", "Le Pas Léger", ["Agilité", "Finesse"],
			"Tu glisses où d'autres trébuchent ; le danger ne saisit que le vide."),
		make("souffle_tenace", "Le Souffle Tenace", ["Endurance", "Force"],
			"Le corps plie sans rompre ; tu tiens quand tout voudrait te briser."),
		make("langue_de_miel", "La Langue de Miel", ["Ruse", "Empathie"],
			"Tes mots coulent doux ; même les cœurs fermés s'entrouvrent."),
		make("mot_ruse", "Le Mot Rusé", ["Ruse", "Verbe"],
			"Une vérité de travers, un silence bien placé, et la porte cède."),
		make("presence_calme", "La Présence Calme", ["Autorité", "Empathie"],
			"Ta seule présence apaise ; la tempête baisse d'un ton."),
		make("pressentiment", "Le Pressentiment", ["Vision", "Instinct"],
			"Quelque chose te souffle avant que tu saches : écoute ce frisson."),
		make("voix_foret", "La Voix de la Forêt", ["Vision", "Nature"],
			"Tu parles la langue des sèves et des racines ; Brocéliande répond."),
		make("appel_ombre", "L'Appel de l'Ombre", ["Mystère", "Nature"],
			"Tu appelles ce qui dort sous les racines. Il vient, mais il prélève son dû.", 1),
		make("main_sure", "La Main Sûre", ["Finesse", "Agilité"],
			"Le geste juste, ni trop tôt ni trop fort : la précision est une patience."),
		make("verbe_haut", "Le Verbe Haut", ["Autorité", "Verbe"],
			"Ta voix porte sans crier ; on se tait pour l'entendre, pas parce qu'elle l'exige."),
		make("coeur_franc", "Le Cœur Franc", ["Franchise", "Empathie"],
			"Tu dis vrai même quand ça coûte, et c'est pour cela qu'on te croit."),
		make("geste_ancien", "Le Geste Ancien", ["Rituel", "Savoir"],
			"Tes mains refont un geste plus vieux que toi ; quelque chose, quelque part, le reconnaît."),
	]


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
			"Une vérité de travers, un silence bien placé, et la porte cède."),
		make("presence_calme", "La Présence Calme", ["Empathie"],
			"Ta seule présence apaise ; la tempête baisse d'un ton."),
		make("pressentiment", "Le Pressentiment", ["Instinct"],
			"Quelque chose te souffle avant que tu saches : écoute ce frisson."),
		make("voix_foret", "La Voix de la Forêt", ["Nature", "Instinct"],
			"Tu parles la langue des sèves et des racines ; Brocéliande répond."),
		make("appel_ombre", "L'Appel de l'Ombre", ["Instinct", "Nature"],
			"Tu appelles ce qui dort sous les racines. Il vient, mais il prélève son dû.", 1),
	]


## Pool enrichi — cartes Rare/Épique/Mythique gagnées par DRAFT aux beats clés (user 2026-06-07).
## tags ORDONNÉS pour que tags[0] donne l'archétype voulu (archetype() = famille de tags[0] ;
## corruption>0 force Corrompu). Effets actifs (HEAL/PURGE/DRAW) sur Rare+. Barème : merlin-game-designer.
static func enriched_pool() -> Array:
	return [
		# — Rares (6) —
		make("oeil_du_druide", "L'Œil du Druide", ["Savoir", "Vigilance"],
			"Tu lis les traces que d'autres effacent ; le mensonge devient transparent sous ton regard.", 0, "Rare", "DRAW", 1),
		make("voix_autorite", "La Voix d'Autorité", ["Autorité", "Verbe"],
			"Un seul mot, dit au bon moment, et la salle cède sans qu'on sache pourquoi.", 0, "Rare"),
		make("pas_de_loup", "Le Pas de Loup", ["Agilité", "Instinct"],
			"Tu disparais avant que l'ombre sache qu'elle t'a vu.", 0, "Rare"),
		make("bras_de_fer", "Le Bras de Fer", ["Force", "Endurance"],
			"Tu encaisses, tu tiens, tu retournes la pression : le premier qui cède n'est pas toi.", 0, "Rare", "HEAL", 1),
		make("lecture_augure", "La Lecture des Augures", ["Vision", "Mystère"],
			"Les signes étaient là depuis le matin ; tu es le seul à les avoir lus.", 0, "Rare"),
		make("serment_tenu", "Le Serment Tenu", ["Sacrifice", "Franchise"],
			"Tu as promis. Tu paies le prix. Et c'est précisément ce qui te donne du poids.", 0, "Rare", "HEAL", 1),
		# — Épiques (5) —
		make("transe_druidique", "La Transe Druidique", ["Vision", "Rituel"],
			"La frontière entre toi et la forêt s'efface. Tu vois ce que Brocéliande te cache depuis longtemps.", 0, "Épique", "DRAW", 1),
		make("colere_juste", "La Colère Juste", ["Force", "Autorité"],
			"Elle ne crie pas, elle tonne, et personne ne cherche à la faire taire.", 0, "Épique"),
		make("empathie_profonde", "L'Empathie Profonde", ["Empathie", "Mémoire"],
			"Tu portes la douleur de l'autre un instant, assez pour lui dire exactement ce qu'il fallait.", 0, "Épique", "HEAL", 2),
		make("marche_equilibre", "La Marche d'Équilibre", ["Équilibre", "Endurance"],
			"Tu ne cherches pas la victoire : tu cherches la durée. Et tu dures.", 0, "Épique", "PURGE", 2),
		make("appel_profond", "L'Appel Profond", ["Nature", "Sacrifice"],
			"Tu demandes à la terre plus qu'elle ne donne d'ordinaire. Elle répond, et tu sais ce que ça coûte.", 1, "Épique", "HEAL", 2),
		# — Mythiques (3) —
		make("verbe_primordial", "Le Verbe Primordial", ["Verbe", "Rituel"],
			"Ce mot existait avant les hommes. Tu n'en connais qu'un. Il suffit.", 0, "Mythique", "PURGE", 2),
		make("memoire_ancienne", "La Mémoire Ancienne", ["Mémoire", "Vision"],
			"Tu touches une strate du temps que nul n'a visitée depuis des siècles. Ce que tu rapportes change tout.", 0, "Mythique", "DRAW", 2),
		make("dissolution_consentie", "La Dissolution Consentie", ["Dissolution", "Sacrifice"],
			"Tu effaces une part de toi pour qu'une autre passe. Ce n'est pas de la faiblesse : c'est du calcul froid.", 2, "Mythique", "HEAL", 3),
	]


## === v11-W3 (spec §E + mapping_actions) — BANQUES DE GREFFES ===
## Conversion de pilier_bank() + enriched_pool() : noms + évocations CONSERVÉS (zéro perte de lore).
## pilier "" = draft générique (mix +tag / +N au jet / charges) ; sinon banque SIGNÉE du PNJ :
##   choeur    = charges HEAL/PURGE gratuites + tag Mémoire (L'Eau Claire), corr 0
##   etre      = +tag Mystère/Vision/Sacrifice contre +1 Corruption ONE-SHOT (affichée au modal)
##   compagnon = tentation DRAW/HEAL contre +1 Corruption one-shot
##   chevalier = +N au jet ou +tag Force/Autorité/Endurance, corr 0
##   enfant    = piège 100 % NARRATIF, corr 0 (charges ×1 médiocres honnêtes, jouet = talisman muet)
## GUARDRAIL CRITICAL : corr_cost ≤ 1, payé UNE fois à la pose — aucun coût récurrent, sans exception.
## v2-W3 — les greffes « roll » ajoutent ROLL_BONUS_DEFAULT au jet d20 (graft_bonus, moteur W1).
static func graft_banks(pilier: String = "") -> Array:
	match pilier:
		"":
			return [
				_graft_roll("g_oeil_du_druide", "L'Œil du Druide",
					"Tu lis les traces que d'autres effacent ; le mensonge devient transparent sous ton regard."),
				_graft_charge("g_bras_de_fer", "Le Bras de Fer",
					"Tu encaisses, tu tiens, tu retournes la pression : le premier qui cède n'est pas toi.",
					"HEAL", 1, 2, 0),
				_graft_tag("g_serment_tenu", "Le Serment Tenu",
					"Tu as promis. Tu paies le prix. Et c'est précisément ce qui te donne du poids.",
					"Franchise", 0),
				_graft_roll("g_voix_autorite", "La Voix d'Autorité",
					"Un seul mot, dit au bon moment, et la salle cède sans qu'on sache pourquoi."),
				_graft_tag("g_marche_equilibre", "La Marche d'Équilibre",
					"Tu ne cherches pas la victoire : tu cherches la durée. Et tu dures.",
					"Équilibre", 0),
				_graft_roll("g_transe_druidique", "La Transe Druidique",
					"La frontière entre toi et la forêt s'efface. Tu vois ce que Brocéliande te cache depuis longtemps."),
			]
		"choeur":
			return [
				_graft_tag("g_eau_claire", "L'Eau Claire",
					"Bois à la source que seuls les Druides connaissent ; elle lave plus que la gorge, elle lave la mémoire de la peur.",
					"Mémoire", 0, "choeur"),
				_graft_charge("g_baume_du_choeur", "Le Baume du Chœur",
					"La druidesse presse une feuille contre ta plaie sans un mot ; la sève sait le chemin que le sang oublie.",
					"PURGE", 1, 2, 0, "choeur"),
				_graft_charge("g_main_qui_releve", "La Main qui Relève",
					"Une paume calleuse se pose sur ton épaule ; tu n'es pas seul, et cette certitude vaut plus que dix remèdes.",
					"HEAL", 1, 2, 0, "choeur"),
			]
		"etre":
			return [
				_graft_tag("g_pacte_de_lisiere", "Le Pacte de Lisière",
					"L'Être te montre une vérité qu'aucun œil ne devrait voir ; tu la prends, et quelque chose en toi se ternit pour l'avoir vue.",
					"Vision", 1, "etre"),
				_graft_tag("g_offrande_sang", "L'Offrande de Sang",
					"Tu ouvres la paume au-dessus de la coupe ; ce que tu y verses revient décuplé, mais ce n'est plus tout à fait du sang qui coule.",
					"Sacrifice", 1, "etre"),
				_graft_tag("g_faveur_indicible", "La Faveur Indicible",
					"Elle murmure un mot que ta bouche refuse de retenir ; la porte s'ouvre, et tu sens qu'une part de toi est restée de l'autre côté.",
					"Mystère", 1, "etre"),
			]
		"compagnon":
			return [
				_graft_charge("g_promesse_ancienne", "La Promesse Ancienne",
					"Sa voix a le grain d'un ami que tu croyais perdu ; elle te promet de rester, et tu voudrais tant la croire.",
					"HEAL", 2, 2, 1, "compagnon"),
				_graft_charge("g_retour_promis", "Le Retour Promis",
					"« Reviens vers moi », souffle-t-il, et chaque mot tisse un chemin si doux que tu oublies de regarder où il mène.",
					"DRAW", 1, 2, 1, "compagnon"),
				_graft_charge("g_main_tendue", "La Main Tendue",
					"Il te tend la main par-dessus le gouffre ; sa poigne est chaude, ferme, sincère, et quelque chose en lui s'éteint un peu chaque fois qu'il t'aide.",
					"HEAL", 1, 2, 1, "compagnon"),
			]
		"chevalier":
			return [
				_graft_tag("g_lame_ternie", "La Lame Ternie",
					"Son épée n'a plus l'éclat des serments, mais elle tranche encore ; il te la confie sans un regard pour ce qu'elle a coûté.",
					"Endurance", 0, "chevalier"),
				_graft_roll("g_charge_du_dechu", "La Charge du Déchu",
					"Il fond sur l'obstacle comme aux jours de gloire ; ce qui le poussait jadis vers l'honneur le pousse aujourd'hui tout court.",
					"chevalier"),
				_graft_tag("g_serment_de_cendre", "Le Serment de Cendre",
					"Tu jures sur ce qu'il te reste d'honneur ; le serment tient, mais il te brûle les lèvres à chaque fois qu'il sort.",
					"Autorité", 0, "chevalier"),
			]
		"enfant":
			return [
				_graft_roll("g_jouet_offert", "Le Jouet Offert",
					"« Tiens, c'est pour toi », dit l'Enfant, et le petit objet de bois ne fait rien d'autre que tenir au creux de ta main.",
					"enfant"),
				_graft_charge("g_secret_chuchote", "Le Secret Chuchoté",
					"« Garde-le pour toi », souffle l'enfant en riant ; mais son rire sonne faux, et le secret pèse déjà trop lourd dans ta poitrine.",
					"DRAW", 1, 1, 0, "enfant"),
				_graft_charge("g_main_chaude", "La Petite Main Chaude",
					"Sa menotte se glisse dans la tienne, confiante ; le geste te réchauffe le cœur, mais tu sens, sans savoir pourquoi, qu'il ne faudrait pas la lâcher.",
					"HEAL", 1, 1, 0, "enfant"),
			]
	return []


# Vague A (A3, 2026-07-12) — BANQUE GÉNÉRIQUE ENRICHIE, réservée au JEU (merlin_run.varied_drafts).
# La banque canonique graft_banks("") (6 entrées, 3 « roll » au libellé identique) ne porte que 3
# libellés d'effet distincts (+jet / +tag / soin) : dès le 2e draft d'une run, les cartes se répètent.
# On AJOUTE deux charges à libellé DISTINCT (PURGE « Dissipe l'Emprise », DRAW « Rappelle une rune »)
# pour porter la diversité à 5 libellés — de quoi tenir toute une run avec l'anti-répétition
# (merlin_run.offered_graft_ids). Le SOAK conserve la banque canonique graft_banks("") → bandes de
# degrés ISO : ces deux charges sont douces (valeur 1, coût 0) et neutres sur le degré (survie/main,
# pas le d20). corr_cost 0 (guardrail CRITICAL ≤ 1). ids uniques (jamais confondus avec les banques signées).
static func graft_bank_generic_varied() -> Array:
	var bank: Array = graft_banks("").duplicate()
	bank.append(_graft_charge("g_source_claire", "La Source Claire",
		"Une eau sans nom sourd de la mousse ; gorgée après gorgée, elle emporte ce que l'Emprise avait déposé en toi.",
		"PURGE", 1, 2, 0))
	bank.append(_graft_charge("g_fil_de_laine", "Le Fil de Laine",
		"Un brin rouge noué à ta ceinture par une main que tu n'as pas vue ; tant qu'il tient, la forêt te rend une rune de plus.",
		"DRAW", 1, 2, 0))
	return bank


static func _graft_tag(p_id: String, p_name: String, p_evo: String, p_tag: String, p_corr: int, p_pilier: String = "") -> Dictionary:
	return {"id": p_id, "name": p_name, "evocation": p_evo, "kind": "tag", "tag": p_tag,
		"effect_type": "", "effect_value": 0, "charges": 0, "corr_cost": p_corr, "pilier": p_pilier}


# v2-W3 (2026-07-05) — bonus AU JET d20 par défaut d'une greffe « roll » (+N au total de resolve via
# graft_bonus, moteur W1). Levier de balance §K (mesuré soak 300, méthode V4a) : à +2, talent+greffes
# stackés poussaient l'éclatante à 14,5-15,3 % (plafond 15 % effleuré/franchi selon la seed) →
# L1 : ROLL_BONUS_DEFAULT 2→1 recentre l'éclatante à ~11 % (marge saine dans 8-15 %), les 3 autres
# bandes restant IN. Baisser encore n'a pas de sens (+0 = greffe morte) ; monter re-déborderait.
const ROLL_BONUS_DEFAULT: int = 1


# v2-W3 — greffe « roll » : +amount au jet d20 (graft_bonus, moteur W1). Remplace l'ex-greffe « die »
# (bande de dé, INERTE depuis W1 : le d6 à bandes n'existe plus). Le champ `amount` alimente
# merlin_run.graft_roll_bonus, sommé dans resolve() aux DEUX call-sites (preview + résolution, R120).
static func _graft_roll(p_id: String, p_name: String, p_evo: String, p_pilier: String = "") -> Dictionary:
	return {"id": p_id, "name": p_name, "evocation": p_evo, "kind": "roll", "tag": "",
		"effect_type": "", "effect_value": 0, "charges": 0, "corr_cost": 0,
		"amount": ROLL_BONUS_DEFAULT, "pilier": p_pilier}


static func _graft_charge(p_id: String, p_name: String, p_evo: String, p_eff: String, p_val: int, p_charges: int, p_corr: int, p_pilier: String = "") -> Dictionary:
	return {"id": p_id, "name": p_name, "evocation": p_evo, "kind": "charge", "tag": "",
		"effect_type": p_eff, "effect_value": p_val, "charges": p_charges, "corr_cost": p_corr, "pilier": p_pilier}


## Wave D (Wave D, co-design user 2026-06-30 + panel équilibrage adversarial) — BANQUES D'OFFRANDE PAR PILIER.
## Au beat « Rencontre », le PNJ pilier de la run offre 1 carte SIGNÉE par sa nature (modal de draft réutilisé).
## 5 signatures DISTINCTES, toutes à coût VISIBLE (pilier ÉVIDENT : zéro stat cachée — le « piège »/« tentation »
## est NARRATIF). Invariant équilibrage : corruption ≤ 1 (coût RÉCURRENT payé à chaque résolution, pas one-shot —
## merlin_resolution.gd:51/95). Sélection (filtre owned + RNG) côté merlin_run.pilier_offering().
##   choeur   = SOIN/PURGE GRATUIT (corruption 0 — seul levier anti-économie-corrompue via eau_claire)
##   etre     = PACTE (corruption 1, effets forts, archétype Corrompu)
##   compagnon= TENTATION (mix corr 0/1, valeur séduisante mais « Passer » reste un choix)
##   chevalier= LAME (effect_type "" pur, tags[0]=Force → Offensif, corruption 0)
##   enfant   = PIÈGE (1 médiocre honnête Commune + 1 corrompu visible + 1 « vrai » cadeau ambigu)
static func pilier_bank(pilier: String) -> Array:
	match pilier:
		"choeur":
			return [
				make("choeur_baume_vert", "Le Baume Vert", ["Nature", "Empathie"],
					"La druidesse presse une feuille contre ta plaie sans un mot ; la sève sait le chemin que le sang oublie.", 0, "Rare", "HEAL", 1),
				make("choeur_eau_claire", "L'Eau Claire", ["Savoir", "Rituel"],
					"Bois à la source que seuls les Druides connaissent ; elle lave plus que la gorge, elle lave la mémoire de la peur.", 0, "Rare", "PURGE", 1),
				make("choeur_main_qui_releve", "La Main qui Relève", ["Empathie", "Savoir"],
					"Une paume calleuse se pose sur ton épaule ; tu n'es pas seul, et cette certitude vaut plus que dix remèdes.", 0, "Épique", "HEAL", 2),
			]
		"etre":
			return [
				make("etre_pacte_de_lisiere", "Le Pacte de Lisière", ["Vision", "Mystère"],
					"L'Être te montre une vérité qu'aucun œil ne devrait voir ; tu la prends, et quelque chose en toi se ternit pour l'avoir vue.", 1, "Épique", "DRAW", 2),
				make("etre_offrande_sang", "L'Offrande de Sang", ["Sacrifice", "Rituel"],
					"Tu ouvres la paume au-dessus de la coupe ; ce que tu y verses revient décuplé, mais ce n'est plus tout à fait du sang qui coule.", 1, "Mythique", "HEAL", 3),
				make("etre_faveur_indicible", "La Faveur Indicible", ["Mystère", "Verbe"],
					"Elle murmure un mot que ta bouche refuse de retenir ; la porte s'ouvre, et tu sens qu'une part de toi est restée de l'autre côté.", 1, "Rare", "PURGE", 1),
			]
		"compagnon":
			return [
				make("compagnon_promesse_ancienne", "La Promesse Ancienne", ["Empathie", "Mémoire"],
					"Sa voix a le grain d'un ami que tu croyais perdu ; elle te promet de rester, et tu voudrais tant la croire.", 0, "Épique", "HEAL", 2),
				make("compagnon_main_tendue", "La Main Tendue", ["Empathie", "Sacrifice"],
					"Il te tend la main par-dessus le gouffre ; sa poigne est chaude, ferme, sincère, et quelque chose en lui s'éteint un peu chaque fois qu'il t'aide.", 1, "Épique", "HEAL", 2),
				make("compagnon_retour_promis", "Le Retour Promis", ["Ruse", "Verbe"],
					"« Reviens vers moi », souffle-t-il, et chaque mot tisse un chemin si doux que tu oublies de regarder où il mène.", 1, "Rare", "DRAW", 1),
			]
		"chevalier":
			return [
				make("chevalier_lame_ternie", "La Lame Ternie", ["Force", "Sacrifice"],
					"Son épée n'a plus l'éclat des serments, mais elle tranche encore ; il te la confie sans un regard pour ce qu'elle a coûté.", 0, "Rare"),
				make("chevalier_charge_du_dechu", "La Charge du Déchu", ["Force", "Autorité"],
					"Il fond sur l'obstacle comme aux jours de gloire ; ce qui le poussait jadis vers l'honneur le pousse aujourd'hui tout court.", 0, "Épique"),
				make("chevalier_serment_de_cendre", "Le Serment de Cendre", ["Force", "Sacrifice", "Autorité"],
					"Tu jures sur ce qu'il te reste d'honneur ; le serment tient, mais il te brûle les lèvres à chaque fois qu'il sort.", 0, "Mythique"),
			]
		"enfant":
			return [
				make("enfant_jouet_offert", "Le Jouet Offert", ["Instinct"],
					"« Tiens, c'est pour toi », dit l'Enfant, et le petit objet de bois ne fait rien d'autre que tenir au creux de ta main.", 0, "Commune"),
				make("enfant_secret_chuchote", "Le Secret Chuchoté", ["Murmure", "Mystère"],
					"« Garde-le pour toi », souffle l'enfant en riant ; mais son rire sonne faux, et le secret pèse déjà trop lourd dans ta poitrine.", 1, "Rare", "DRAW", 1),
				make("enfant_main_chaude", "La Petite Main Chaude", ["Empathie", "Instinct"],
					"Sa menotte se glisse dans la tienne, confiante ; le geste te réchauffe le cœur, mais tu sens, sans savoir pourquoi, qu'il ne faudrait pas la lâcher.", 0, "Rare", "HEAL", 1),
			]
	return []
