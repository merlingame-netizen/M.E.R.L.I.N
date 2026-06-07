## ═══════════════════════════════════════════════════════════════════════════════
## ParchmentScroll — Animated parchment that unrolls + typewriter-reveals an intro.
## ═══════════════════════════════════════════════════════════════════════════════
##
## v7.7.23 (2026-05-17) — Used by ScenarioLoading to display the lore-aware
## intro (LLM #2 output) after the player picks a scenario title.
##
## User locked decision : « Parchemin qui se déroule » — animated scroll
##   1. Unroll : scale.y 0→1 over 1.2s TRANS_QUART EASE_OUT + alpha 0→1
##   2. Typewriter : RichTextLabel.visible_characters 0→len char-by-char @ 60ms/char
##   3. Hold : 3.0s after typewriter completes
##   4. Roll-out : scale.y 1→0 over 0.8s + alpha 1→0
##   5. Emit `closed` signal + queue_free()
##
## Style : cream parchment (#eaddad), dark wood border (#4d3218), sepia ink
## (#6a4a2a) — matches the existing parchment precedent in board_narration.gd.
## Sharp edges with a slight 4px corner_radius exception (parchment is a
## physical artifact, not a UI panel — radius=0 would look tile-like).
##
## API :
##   var p := preload("res://scripts/ui/parchment_scroll.gd").new()
##   parent.add_child(p)
##   p.display("Tu es un jeune druide...")  # 6-8 sentences
##   await p.closed                          # waits for full cycle
## ═══════════════════════════════════════════════════════════════════════════════

extends PanelContainer

signal closed

# Animation timing constants (overridable per call if needed).
const UNROLL_DURATION: float = 1.2
const TYPEWRITER_CHARS_PER_SECOND: float = 16.6   # ≈ 60ms/char
const HOLD_DURATION: float = 3.0
const ROLLOUT_DURATION: float = 0.8

# Parchment visual identity (matches board_narration parchment precedent).
const PARCHMENT_BG: Color    = Color("#eaddad")
const PARCHMENT_BORDER: Color = Color("#4d3218")
const SEPIA_INK: Color       = Color("#6a4a2a")
const INK_OUTLINE: Color     = Color(0.0, 0.0, 0.0, 0.85)

var _label: RichTextLabel = null
var _stylebox: StyleBoxFlat = null
var _intro_text: String = ""
var _is_closing: bool = false

# 2026-06-06 — Merlin reads the intro aloud (VoxCPM TTS) as the typewriter runs.
# Caller can disable voicing or pick a cloned voice via display(...) args.
var _voice_enabled: bool = true
var _voice_name: String = ""


func _ready() -> void:
	# Charter-compliant geometry : sharp edges with a slight 4px radius
	# (parchment is a physical artifact, not a UI panel).
	custom_minimum_size = Vector2(680, 400)
	mouse_filter = Control.MOUSE_FILTER_STOP
	# Pivot at center so scale.y animation unrolls FROM CENTER (looks like the
	# scroll opens from a horizontal seam, top and bottom edges spreading apart).
	pivot_offset = Vector2(custom_minimum_size.x * 0.5, custom_minimum_size.y * 0.5)
	# Initial state : rolled up (height 0) + invisible.
	scale = Vector2(1.0, 0.0)
	modulate.a = 0.0

	# Parchment stylebox.
	_stylebox = StyleBoxFlat.new()
	_stylebox.bg_color = PARCHMENT_BG
	_stylebox.border_color = PARCHMENT_BORDER
	_stylebox.set_border_width_all(3)
	_stylebox.set_corner_radius_all(4)
	_stylebox.set_content_margin_all(28)
	_stylebox.shadow_size = 8
	_stylebox.shadow_color = Color(0.0, 0.0, 0.0, 0.4)
	_stylebox.shadow_offset = Vector2(2, 4)
	add_theme_stylebox_override("panel", _stylebox)

	# RichTextLabel for typewriter effect via visible_characters.
	_label = RichTextLabel.new()
	_label.name = "IntroText"
	_label.fit_content = true
	_label.scroll_active = false
	_label.bbcode_enabled = false
	_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_label.add_theme_font_size_override("normal_font_size", 18)
	_label.add_theme_color_override("default_color", SEPIA_INK)
	_label.add_theme_color_override("font_outline_color", INK_OUTLINE)
	_label.add_theme_constant_override("outline_size", 2)
	# Initial : empty + visible_characters=0 so typewriter can reveal char-by-char.
	_label.text = ""
	_label.visible_characters = 0
	add_child(_label)


## Display the intro and run the full unroll → typewriter → hold → close cycle.
## Returns immediately ; caller can `await parchment.closed` to wait for completion.
## `voice` : speak the text via MerlinTTS (default true). `voice_name` : reference
## voice to clone (e.g. "merlin"); empty uses the server default.
func display(intro_text: String, voice: bool = true, voice_name: String = "") -> void:
	_intro_text = intro_text.strip_edges()
	_voice_enabled = voice
	_voice_name = voice_name
	if _label == null:
		# _ready hasn't run yet (instantiated but not added to tree). Defer.
		call_deferred("_display_internal")
		return
	_display_internal()


func _display_internal() -> void:
	if _label == null:
		return
	_label.text = _intro_text
	_label.visible_characters = 0   # hide everything until typewriter starts
	# Phase 1 : unroll (scale.y 0→1 + alpha 0→1 in parallel).
	var unroll_tween: Tween = create_tween().bind_node(self).set_parallel(true)
	unroll_tween.tween_property(self, "scale", Vector2.ONE, UNROLL_DURATION).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
	unroll_tween.tween_property(self, "modulate:a", 1.0, UNROLL_DURATION * 0.7).set_trans(Tween.TRANS_SINE)
	await unroll_tween.finished
	# Phase 2 : typewriter (visible_characters 0 → text length).
	# 2026-06-06 — Merlin speaks the intro now so the voice runs alongside the
	# typewriter reveal. Guarded + no-op if the MerlinTTS autoload / server is
	# absent, so the parchment never blocks on TTS.
	if _voice_enabled and not _intro_text.is_empty():
		var tts := get_node_or_null("/root/MerlinTTS")
		if tts != null and tts.has_method("speak"):
			tts.call("speak", _intro_text, _voice_name)
	var char_count: int = _intro_text.length()
	if char_count > 0:
		var typewriter_duration: float = float(char_count) / TYPEWRITER_CHARS_PER_SECOND
		var tw_tween: Tween = create_tween().bind_node(_label)
		tw_tween.tween_property(_label, "visible_characters", char_count, typewriter_duration)
		await tw_tween.finished
	# Phase 3 : hold for read-time.
	await get_tree().create_timer(HOLD_DURATION).timeout
	# Phase 4 : roll out (scale.y 1→0 + alpha 1→0).
	_is_closing = true
	var rollout_tween: Tween = create_tween().bind_node(self).set_parallel(true)
	rollout_tween.tween_property(self, "scale", Vector2(1.0, 0.0), ROLLOUT_DURATION).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_IN)
	rollout_tween.tween_property(self, "modulate:a", 0.0, ROLLOUT_DURATION * 0.9).set_trans(Tween.TRANS_SINE)
	await rollout_tween.finished
	closed.emit()
	queue_free()


## Public : force-close immediately (e.g. back button pressed during parchment).
## Skips remaining animation phases and emits `closed`.
func close_now() -> void:
	if _is_closing:
		return
	_is_closing = true
	closed.emit()
	queue_free()
