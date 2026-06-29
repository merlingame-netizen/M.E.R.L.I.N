class_name MerlinMenuVoice
extends Node
## Ordonnanceur de la VOIX du menu (user 2026-06-29) : pré-génère des pensées de Merlin (100% LLM)
## dans une file, en CÉDANT la priorité à la pré-génération des scénarios (single-flight via
## MerlinNative.is_busy()). AUCUNE réplique écrite à la main : tout vient de Gemma — on met juste la
## sortie en cache pour masquer la latence (Gemma est lent sur CPU). Possédé par merlin_menu.

const QUEUE_CAP: int = 3
const MAX_LEN: int = 110            # garde-fou longueur d'une pensée
const START_DELAY_S: float = 1.5   # laisse la pré-gen des scénarios réserver le moteur d'abord
const PUMP_PERIOD_S: float = 1.5    # cadence de tentative de remplissage
# Rotation des modes idle (la salutation passe en premier, hors rotation).
const MODES: Array = ["journee", "encourage", "souvenir", "blague", "journee", "souvenir"]

var _voice: String = ""
var _ctx: Dictionary = {}
var _queue: Array[String] = []
var _depart: String = ""             # réplique « le Voyageur s'élance » consommée par la transition de lancement
var _hover_cache: Dictionary = {}   # bouton (String) → réplique prête
var _hover_pending: Dictionary = {} # bouton → true (génération en cours)
var _mode_idx: int = 0
var _greeted: bool = false
var _running: bool = false
var _pumping: bool = false
var _pump_acc: float = 0.0


func setup(voice: String, ctx: Dictionary) -> void:
	_voice = voice
	_ctx = ctx


func _ready() -> void:
	_pump_acc = -START_DELAY_S  # délai initial : priorité aux scénarios
	set_process(true)


func start() -> void:
	_running = true


func stop() -> void:
	_running = false
	set_process(false)


func has_ready() -> bool:
	return _queue.size() > 0


func take_thought() -> String:
	return _queue.pop_front() if not _queue.is_empty() else ""


# Réplique de DÉPART (lancement Nouvelle/Continuer) : consommée par la transition. "" si pas encore prête
# (la transition retombe alors sur une réplique procédurale courte). Re-générée au pump suivant.
func take_depart() -> String:
	var d: String = _depart
	_depart = ""
	return d


# Réplique de survol : instantanée si en cache (consommée), sinon "" (une fraîche sera re-générée).
func hover_line(bouton: String) -> String:
	if _hover_cache.has(bouton):
		var l: String = str(_hover_cache[bouton])
		_hover_cache.erase(bouton)
		return l
	return ""


func _process(delta: float) -> void:
	if not _running:
		return
	_pump_acc += delta
	if _pump_acc >= PUMP_PERIOD_S:
		_pump_acc = 0.0
		_pump()


# Tente UN remplissage si le moteur est libre. Async mais non-bloquant (le moteur pompe chaque frame).
func _pump() -> void:
	if _pumping or not MerlinVoicePrefs.is_enabled():
		return  # voix coupée dans Options → file vide → aucune bulle
	var mn: Node = get_node_or_null("/root/MerlinNative")
	if mn == null or not mn.is_ready() or mn.is_busy():
		return  # scénarios prioritaires / modèle pas prêt → on retentera
	_pumping = true
	await _pump_body()
	if is_instance_valid(self):
		_pumping = false


func _pump_body() -> void:
	# 1) Salutation d'abord (une seule fois). « premiere » au tout premier lancement (chronique vierge),
	# sinon « salut ». _greeted ne passe à true qu'en cas de SUCCÈS (sinon on RETENTE : moteur occupé).
	if not _greeted:
		var first: bool = int(_ctx.get("runs_played", 0)) == 0 and str(_ctx.get("last_seen_iso", "")) == ""
		var hello: String = await _generate("premiere" if first else "salut", {})
		if hello != "" and _running:
			_greeted = true
			_queue.append(hello)
		return
	# 2) Réplique de DÉPART (lancement) — en garder UNE prête pour la transition Nouvelle/Continuer.
	if _depart == "":
		var dep: String = await _generate("depart", {})
		if dep != "" and _running:
			_depart = dep
		return
	# 3) File de pensées idle.
	if _queue.size() < QUEUE_CAP:
		var mode: String = str(MODES[_mode_idx % MODES.size()])
		_mode_idx += 1
		var line: String = await _generate(mode, {})
		if line != "" and _running:
			_queue.append(line)
		return
	# 4) Sinon, alimente le cache de survol (1 bouton manquant à la fois).
	for b in _ctx.get("hover_buttons", []):
		var bs: String = str(b)
		if not _hover_cache.has(bs) and not bool(_hover_pending.get(bs, false)):
			_hover_pending[bs] = true
			var hl: String = await _generate("survol", {"bouton": bs})
			if is_instance_valid(self):
				_hover_pending[bs] = false
				if hl != "" and _running:
					_hover_cache[bs] = hl
			return


func _generate(mode: String, extra: Dictionary) -> String:
	var mn: Node = get_node_or_null("/root/MerlinNative")
	if mn == null or not mn.is_ready() or mn.is_busy():
		return ""
	var ctx: Dictionary = _ctx.duplicate()
	for k in extra.keys():
		ctx[k] = extra[k]
	var p: Dictionary = MerlinPromptBuilder.menu_thought(_voice, mode, ctx)
	var res: Dictionary = await mn.generate(str(p["system"]), str(p["user"]), p["opts"])
	if not is_instance_valid(self) or not _running:
		return ""  # menu quitté pendant la génération → on jette le résultat
	if not (res is Dictionary) or res.has("error"):
		return ""
	return _tidy(str(res.get("text", "")))


# Garde UNE phrase courte, propre, bornée (la prod reste 100% LLM ; on ne fait que recouper).
func _tidy(s: String) -> String:
	var t: String = MerlinProse.clean_prose(s.strip_edges())
	t = MerlinProse.first_sentence(t).strip_edges()
	if t.length() > MAX_LEN:
		t = t.substr(0, MAX_LEN).strip_edges()
		var sp: int = t.rfind(" ")
		if sp >= 40:
			t = t.substr(0, sp)
		t += "…"
	return t
