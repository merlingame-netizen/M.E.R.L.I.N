class_name MerlinGrammar
extends RefCounted
## v10.17 (track LLM, inspiré NobodyWho) — chargement + validation CENTRALISÉS des grammaires GBNF.
## Comble le gap NobodyWho « chargement GBNF ad-hoc ». Classe statique pure (zéro autoload, zéro
## état de node) — même discipline que MerlinProse / MerlinJson / MerlinPromptBuilder.
##
## ⚠ ENFORCEMENT DÉSACTIVÉ PAR DÉFAUT (USE_GBNF = false). Raison : merlin_scenario L10-11 +
## merlin_json L3-4 documentent que le GBNF est CASSÉ sur ce build gemma4 (un set_grammar peut
## bloquer le natif ~90s, faisant exploser la deadline 8s de la sélection). La robustesse vient
## donc du parse+repair+validate+retry (MerlinJson + MerlinStructured), JAMAIS de la grammaire.
## Rôle de ce helper tant que USE_GBNF = false : valider l'existence/forme des .gbnf au boot
## (observabilité) et servir d'ON-RAMP — basculer USE_GBNF à true (1 const) réactive l'enforcement
## APRÈS un soak dédié prouvant que set_grammar ne bloque pas. Catalogue = grammaires CANON v2.0
## UNIQUEMENT (jamais les .gbnf legacy factions/OGHAM/ANAM, périmés hors canon).

const DIR: String = "res://data/ai/"
const USE_GBNF: bool = false  # OFF (sûreté R109) — voir merlin_scenario.gd L10-11
const CATALOG: Dictionary = {"selection": "selection.gbnf"}

static var _cache: Dictionary = {}
static var _loaded: bool = false


## Charge+valide toutes les grammaires du catalogue (idempotent). Ne lève JAMAIS : un fichier
## absent/vide est signalé (push_warning + rapport), jamais une erreur fatale. Retourne un rapport
## {ok, missing, invalid, enforcement} loggé au boot par MerlinNative.
static func preload_all() -> Dictionary:
	var ok: int = 0
	var missing: PackedStringArray = []
	var invalid: PackedStringArray = []
	for name in CATALOG:
		var fname: String = str(CATALOG[name])
		var src: String = _read_file(DIR + fname)
		if src.strip_edges().is_empty():
			missing.append(fname)
			push_warning("MerlinGrammar: grammaire absente/vide '%s'" % fname)
		elif not validate_source(src):
			invalid.append(fname)
			push_warning("MerlinGrammar: grammaire sans règle 'root' '%s'" % fname)
		else:
			_cache[name] = src
			ok += 1
	_loaded = true
	return {"ok": ok, "missing": missing, "invalid": invalid, "enforcement": USE_GBNF}


## Source GBNF par nom logique. Enforcement OFF → toujours "" (le parse+retry fait tout le travail).
## ON → cache-hit ou "" (cache-miss = pas d'enforcement, dégradation gracieuse).
static func get_grammar(name: String) -> String:
	if not USE_GBNF:
		return ""
	if not _loaded:
		preload_all()
	return str(_cache.get(name, ""))


## Vrai si l'enforcement est actif ET la grammaire est au catalogue (gate côté MerlinStructured).
static func has(name: String) -> bool:
	return USE_GBNF and CATALOG.has(name)


## Validation minimale : non-vide ET contient au moins une ligne débutant par 'root' (règle d'entrée).
static func validate_source(src: String) -> bool:
	if src.strip_edges().is_empty():
		return false
	for line in src.split("\n"):
		if line.strip_edges().begins_with("root"):
			return true
	return false


static func _read_file(path: String) -> String:
	if not FileAccess.file_exists(path):
		return ""
	var f: FileAccess = FileAccess.open(path, FileAccess.READ)
	if f == null:
		return ""
	var s: String = f.get_as_text()
	f.close()
	return s
