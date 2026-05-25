class_name MerlinTags
extends RefCounted
## Taxonomie des tags (bible R81) + matching souple (R61/R78).
## Cœur curé ~25 concepts en 6 familles. Le matching normalise (minuscule + sans accents)
## et applique une table de synonymes vers le concept-cœur le plus proche.
## 100% logique pure — aucune dépendance LLM, testable.

# Familles (R78/R81) — valeurs affichées (accentuées). Famille primaire = couleur de pastille (R70).
const FAMILIES: Dictionary = {
	"Perception": ["Sens", "Savoir", "Mémoire", "Vigilance"],
	"Corps": ["Force", "Agilité", "Endurance", "Finesse"],
	"Parole": ["Empathie", "Verbe", "Ruse", "Autorité", "Franchise"],
	"Intuition": ["Instinct", "Nature", "Vision"],
	"Monde": ["Rituel", "Sacrifice", "Équilibre", "Mystère"],
	"Corrompu": ["Vide", "Glitch", "Dissolution", "Murmure", "Emprise"],
}

# Couleur de pastille par famille (R70).
const FAMILY_COLORS: Dictionary = {
	"Perception": "C9A24B",
	"Corps": "A8703E",
	"Parole": "B5C04F",
	"Intuition": "4F6B3E",
	"Monde": "7FA6C9",
	"Corrompu": "7B4FA3",
}

# Synonymes courants → concept-cœur (clés normalisées, sans accents). Matching souple R61.
const SYNONYMS: Dictionary = {
	"malin": "ruse", "ruse": "ruse", "astuce": "ruse", "fourberie": "ruse",
	"observer": "sens", "regard": "sens", "vue": "sens", "perception": "sens", "odorat": "sens",
	"ecoute": "sens", "ouie": "sens",
	"connaissance": "savoir", "science": "savoir", "sagesse": "savoir",
	"souvenir": "memoire", "passe": "memoire",
	"attention": "vigilance", "prudence": "vigilance", "guet": "vigilance",
	"puissance": "force", "vigueur": "force", "brutalite": "force",
	"rapide": "agilite", "vitesse": "agilite", "esquive": "agilite", "souplesse": "agilite",
	"resistance": "endurance", "tenacite": "endurance", "fatigue": "endurance",
	"precision": "finesse", "delicatesse": "finesse", "adresse": "finesse",
	"compassion": "empathie", "coeur": "empathie", "douceur": "empathie",
	"parole": "verbe", "mot": "verbe", "discours": "verbe", "eloquence": "verbe",
	"commandement": "autorite", "ordre": "autorite", "prestance": "autorite",
	"honnetete": "franchise", "verite": "franchise", "sincerite": "franchise",
	"intuition": "instinct", "pressentiment": "instinct", "flair": "instinct",
	"foret": "nature", "vivant": "nature", "seve": "nature", "betes": "nature",
	"reve": "vision", "presage": "vision", "augure": "vision",
	"rite": "rituel", "ceremonie": "rituel", "incantation": "rituel",
	"don": "sacrifice", "offrande": "sacrifice", "renoncement": "sacrifice",
	"harmonie": "equilibre", "paix": "equilibre", "balance": "equilibre",
	"enigme": "mystere", "secret": "mystere", "inconnu": "mystere",
	"neant": "vide", "absence": "vide",
	"faille": "glitch", "erreur": "glitch", "bug": "glitch",
	"pourriture": "dissolution", "decomposition": "dissolution",
	"chuchotement": "murmure", "voix": "murmure",
	"controle": "emprise", "possession": "emprise",
}

const CORRUPTED_FAMILY: String = "Corrompu"


static func normalize(s: String) -> String:
	var t: String = s.strip_edges().to_lower()
	var out: String = ""
	for i in t.length():
		out += _strip_accent(t[i])
	return out


static func _strip_accent(c: String) -> String:
	match c:
		"é", "è", "ê", "ë": return "e"
		"à", "â", "ä": return "a"
		"î", "ï": return "i"
		"ô", "ö": return "o"
		"û", "ü", "ù": return "u"
		"ç": return "c"
		_: return c


## Ramène un tag libre au concept-cœur le plus proche (normalisé). Sinon retourne le tag normalisé.
static func to_canon(tag: String) -> String:
	var n: String = normalize(tag)
	if SYNONYMS.has(n):
		return SYNONYMS[n]
	for fam in FAMILIES:
		for core_tag in FAMILIES[fam]:
			if normalize(core_tag) == n:
				return n
	return n


## Famille d'un tag (pour la couleur). "" si inconnue.
static func family_of(tag: String) -> String:
	var n: String = to_canon(tag)
	for fam in FAMILIES:
		for core_tag in FAMILIES[fam]:
			if normalize(core_tag) == n:
				return fam
	return ""


static func color_of(tag: String) -> String:
	var fam: String = family_of(tag)
	if fam != "" and FAMILY_COLORS.has(fam):
		return FAMILY_COLORS[fam]
	return "9C8C6A"


static func is_corrupted_tag(tag: String) -> bool:
	return family_of(tag) == CORRUPTED_FAMILY


## Couverture des tags requis par les tags joués (sets normalisés/canon).
## Retourne {covered: Array, missing: Array, extra: Array} (en canon).
static func coverage(required: Array, played: Array) -> Dictionary:
	var req_canon: Array = []
	for r in required:
		var c: String = to_canon(str(r))
		if not req_canon.has(c):
			req_canon.append(c)
	var play_canon: Array = []
	for p in played:
		var c2: String = to_canon(str(p))
		if not play_canon.has(c2):
			play_canon.append(c2)
	var covered: Array = []
	var missing: Array = []
	for rc in req_canon:
		if play_canon.has(rc):
			covered.append(rc)
		else:
			missing.append(rc)
	var extra: Array = []
	for pc in play_canon:
		if not req_canon.has(pc):
			extra.append(pc)
	return {"covered": covered, "missing": missing, "extra": extra}
