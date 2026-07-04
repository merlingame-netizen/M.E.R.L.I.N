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
var effect_type: String = ""   # "" | HEAL | PURGE | DRAW — effet actif joué (Rare+, user 2026-06-07)
var effect_value: int = 0      # intensité (PV soignés / Corruption purgée / cartes piochées)
# v11 (pivot ACTION+TRAIT, spec panel 2026-07-04) — famille canonique FIXE d'une ACTION (verbe).
# "" pour les traits et cartes legacy. La famille de synergie de l'action ne change JAMAIS,
# même quand des tags sont greffés (W3).
var family: String = ""
# v11-W3 (spec §E) — GREFFES posées sur une ACTION (cap 3). Dicts {id, name, evocation,
# kind: "tag"|"die"|"charge", tag, effect_type, effect_value, charges, corr_cost, pilier}.
# Champ ADDITIF (défaut []) : les saves W2 chargent sans bump de SAVE_VERSION.
# GUARDRAIL CRITICAL : le prix d'une greffe est ONE-SHOT à la pose (corr_cost, payé par
# merlin_run.apply_graft) ou PAR CHARGE — jamais récurrent (corruption de l'action reste 0).
var grafts: Array = []
var _archetype_cache: String = ""  # v10.5 : archétype dérivé memoïsé (to_dict appelé ~1Hz × deck)


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
			"Regarder vraiment — et laisser ce qui se cache remonter à la surface."),
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
static func starter_traits() -> Array:
	return [
		make("regard_percant", "Le Regard Perçant", ["Vigilance", "Sens"],
			"Tes yeux fendent l'ombre ; rien ne reste caché à qui sait vraiment voir."),
		make("ecoute_silence", "L'Écoute du Silence", ["Vigilance"],
			"Entre deux souffles du vent, la forêt confie ce qu'elle tait aux autres."),
		make("memoire_lieux", "La Mémoire des Lieux", ["Mémoire", "Savoir"],
			"Les pierres se souviennent. Pose la main, et leur passé remonte en toi."),
		make("main_de_fer", "La Main de Fer", ["Force", "Endurance"],
			"Quand la douceur échoue, reste la poigne qui ne tremble pas."),
		make("pas_leger", "Le Pas Léger", ["Agilité", "Finesse"],
			"Tu glisses où d'autres trébuchent ; le danger ne saisit que le vide."),
		make("souffle_tenace", "Le Souffle Tenace", ["Endurance"],
			"Le corps plie sans rompre ; tu tiens quand tout voudrait te briser."),
		make("langue_de_miel", "La Langue de Miel", ["Ruse", "Empathie"],
			"Tes mots coulent doux ; même les cœurs fermés s'entrouvrent."),
		make("mot_ruse", "Le Mot Rusé", ["Ruse", "Verbe"],
			"Une vérité de travers, un silence bien placé — et la porte cède."),
		make("presence_calme", "La Présence Calme", ["Autorité", "Empathie"],
			"Ta seule présence apaise ; la tempête baisse d'un ton."),
		make("pressentiment", "Le Pressentiment", ["Vision", "Instinct"],
			"Quelque chose te souffle avant que tu saches — écoute ce frisson."),
		make("voix_foret", "La Voix de la Forêt", ["Vision", "Nature"],
			"Tu parles la langue des sèves et des racines ; Brocéliande répond."),
		make("appel_ombre", "L'Appel de l'Ombre", ["Mystère", "Nature"],
			"Tu appelles ce qui dort sous les racines. Il vient — mais il prélève son dû.", 1),
		make("main_sure", "La Main Sûre", ["Finesse"],
			"Le geste juste, ni trop tôt ni trop fort — la précision est une patience."),
		make("verbe_haut", "Le Verbe Haut", ["Autorité", "Verbe"],
			"Ta voix porte sans crier ; on se tait pour l'entendre, pas parce qu'elle l'exige."),
		make("coeur_franc", "Le Cœur Franc", ["Franchise", "Empathie"],
			"Tu dis vrai même quand ça coûte — et c'est pour cela qu'on te croit."),
		make("geste_ancien", "Le Geste Ancien", ["Rituel", "Mémoire"],
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


## Pool enrichi — cartes Rare/Épique/Mythique gagnées par DRAFT aux beats clés (user 2026-06-07).
## tags ORDONNÉS pour que tags[0] donne l'archétype voulu (archetype() = famille de tags[0] ;
## corruption>0 force Corrompu). Effets actifs (HEAL/PURGE/DRAW) sur Rare+. Barème : merlin-game-designer.
static func enriched_pool() -> Array:
	return [
		# — Rares (6) —
		make("oeil_du_druide", "L'Œil du Druide", ["Savoir", "Vigilance"],
			"Tu lis les traces que d'autres effacent ; le mensonge devient transparent sous ton regard.", 0, "Rare", "DRAW", 1),
		make("voix_autorite", "La Voix d'Autorité", ["Autorité", "Verbe"],
			"Un seul mot, dit au bon moment — et la salle cède sans qu'on sache pourquoi.", 0, "Rare"),
		make("pas_de_loup", "Le Pas de Loup", ["Agilité", "Instinct"],
			"Tu disparais avant que l'ombre sache qu'elle t'a vu.", 0, "Rare"),
		make("bras_de_fer", "Le Bras de Fer", ["Force", "Endurance"],
			"Tu encaisses, tu tiens, tu retournes la pression — le premier qui cède n'est pas toi.", 0, "Rare", "HEAL", 1),
		make("lecture_augure", "La Lecture des Augures", ["Vision", "Mystère"],
			"Les signes étaient là depuis le matin ; tu es le seul à les avoir lus.", 0, "Rare"),
		make("serment_tenu", "Le Serment Tenu", ["Sacrifice", "Franchise"],
			"Tu as promis. Tu paies le prix. Et c'est précisément ce qui te donne du poids.", 0, "Rare", "HEAL", 1),
		# — Épiques (5) —
		make("transe_druidique", "La Transe Druidique", ["Vision", "Rituel"],
			"La frontière entre toi et la forêt s'efface. Tu vois ce que Brocéliande te cache depuis longtemps.", 0, "Épique", "DRAW", 1),
		make("colere_juste", "La Colère Juste", ["Force", "Autorité"],
			"Elle ne crie pas, elle tonne — et personne ne cherche à la faire taire.", 0, "Épique"),
		make("empathie_profonde", "L'Empathie Profonde", ["Empathie", "Mémoire"],
			"Tu portes la douleur de l'autre un instant — assez pour lui dire exactement ce qu'il fallait.", 0, "Épique", "HEAL", 2),
		make("marche_equilibre", "La Marche d'Équilibre", ["Équilibre", "Endurance"],
			"Tu ne cherches pas la victoire — tu cherches la durée. Et tu dures.", 0, "Épique", "PURGE", 2),
		make("appel_profond", "L'Appel Profond", ["Nature", "Sacrifice"],
			"Tu demandes à la terre plus qu'elle ne donne d'ordinaire. Elle répond — et tu sais ce que ça coûte.", 1, "Épique", "HEAL", 2),
		# — Mythiques (3) —
		make("verbe_primordial", "Le Verbe Primordial", ["Verbe", "Rituel"],
			"Ce mot existait avant les hommes. Tu n'en connais qu'un. Il suffit.", 0, "Mythique", "PURGE", 2),
		make("memoire_ancienne", "La Mémoire Ancienne", ["Mémoire", "Vision"],
			"Tu touches une strate du temps que nul n'a visitée depuis des siècles. Ce que tu rapportes change tout.", 0, "Mythique", "DRAW", 2),
		make("dissolution_consentie", "La Dissolution Consentie", ["Dissolution", "Sacrifice"],
			"Tu effaces une part de toi pour qu'une autre passe. Ce n'est pas de la faiblesse — c'est du calcul froid.", 2, "Mythique", "HEAL", 3),
	]


## === v11-W3 (spec §E + mapping_actions) — BANQUES DE GREFFES ===
## Conversion de pilier_bank() + enriched_pool() : noms + évocations CONSERVÉS (zéro perte de lore).
## pilier "" = draft générique (mix +tag / +bande de dé / charges) ; sinon banque SIGNÉE du PNJ :
##   choeur    = charges HEAL/PURGE gratuites + tag Mémoire (L'Eau Claire), corr 0
##   etre      = +tag Mystère/Vision/Sacrifice contre +1 Corruption ONE-SHOT (affichée au modal)
##   compagnon = tentation DRAW/HEAL contre +1 Corruption one-shot
##   chevalier = +bande de dé ou +tag Force/Autorité/Endurance, corr 0
##   enfant    = piège 100 % NARRATIF, corr 0 (charges ×1 médiocres honnêtes, jouet = dé de bois)
## GUARDRAIL CRITICAL : corr_cost ≤ 1, payé UNE fois à la pose — aucun coût récurrent, sans exception.
static func graft_banks(pilier: String = "") -> Array:
	match pilier:
		"":
			return [
				_graft_die("g_oeil_du_druide", "L'Œil du Druide",
					"Tu lis les traces que d'autres effacent ; le mensonge devient transparent sous ton regard."),
				_graft_charge("g_bras_de_fer", "Le Bras de Fer",
					"Tu encaisses, tu tiens, tu retournes la pression — le premier qui cède n'est pas toi.",
					"HEAL", 1, 2, 0),
				_graft_tag("g_serment_tenu", "Le Serment Tenu",
					"Tu as promis. Tu paies le prix. Et c'est précisément ce qui te donne du poids.",
					"Franchise", 0),
				_graft_die("g_voix_autorite", "La Voix d'Autorité",
					"Un seul mot, dit au bon moment — et la salle cède sans qu'on sache pourquoi."),
				_graft_tag("g_marche_equilibre", "La Marche d'Équilibre",
					"Tu ne cherches pas la victoire — tu cherches la durée. Et tu dures.",
					"Équilibre", 0),
				_graft_die("g_transe_druidique", "La Transe Druidique",
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
					"Il te tend la main par-dessus le gouffre ; sa poigne est chaude, ferme, sincère — et quelque chose en lui s'éteint un peu chaque fois qu'il t'aide.",
					"HEAL", 1, 2, 1, "compagnon"),
			]
		"chevalier":
			return [
				_graft_tag("g_lame_ternie", "La Lame Ternie",
					"Son épée n'a plus l'éclat des serments, mais elle tranche encore ; il te la confie sans un regard pour ce qu'elle a coûté.",
					"Endurance", 0, "chevalier"),
				_graft_die("g_charge_du_dechu", "La Charge du Déchu",
					"Il fond sur l'obstacle comme aux jours de gloire ; ce qui le poussait jadis vers l'honneur le pousse aujourd'hui tout court.",
					"chevalier"),
				_graft_tag("g_serment_de_cendre", "Le Serment de Cendre",
					"Tu jures sur ce qu'il te reste d'honneur ; le serment tient, mais il te brûle les lèvres à chaque fois qu'il sort.",
					"Autorité", 0, "chevalier"),
			]
		"enfant":
			return [
				_graft_die("g_jouet_offert", "Le Jouet Offert",
					"« Tiens, c'est pour toi », dit l'Enfant, et le petit objet de bois ne fait rien d'autre que tenir au creux de ta main.",
					"enfant"),
				_graft_charge("g_secret_chuchote", "Le Secret Chuchoté",
					"« Garde-le pour toi », souffle l'enfant en riant ; mais son rire sonne faux, et le secret pèse déjà trop lourd dans ta poitrine.",
					"DRAW", 1, 1, 0, "enfant"),
				_graft_charge("g_main_chaude", "La Petite Main Chaude",
					"Sa menotte se glisse dans la tienne, confiante ; le geste te réchauffe le cœur — mais tu sens, sans savoir pourquoi, qu'il ne faudrait pas la lâcher.",
					"HEAL", 1, 1, 0, "enfant"),
			]
	return []


static func _graft_tag(p_id: String, p_name: String, p_evo: String, p_tag: String, p_corr: int, p_pilier: String = "") -> Dictionary:
	return {"id": p_id, "name": p_name, "evocation": p_evo, "kind": "tag", "tag": p_tag,
		"effect_type": "", "effect_value": 0, "charges": 0, "corr_cost": p_corr, "pilier": p_pilier}


static func _graft_die(p_id: String, p_name: String, p_evo: String, p_pilier: String = "") -> Dictionary:
	return {"id": p_id, "name": p_name, "evocation": p_evo, "kind": "die", "tag": "",
		"effect_type": "", "effect_value": 0, "charges": 0, "corr_cost": 0, "pilier": p_pilier}


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
					"Il te tend la main par-dessus le gouffre ; sa poigne est chaude, ferme, sincère — et quelque chose en lui s'éteint un peu chaque fois qu'il t'aide.", 1, "Épique", "HEAL", 2),
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
					"Sa menotte se glisse dans la tienne, confiante ; le geste te réchauffe le cœur — mais tu sens, sans savoir pourquoi, qu'il ne faudrait pas la lâcher.", 0, "Rare", "HEAL", 1),
			]
	return []
