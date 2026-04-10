# cutscene.gd
# Reusable narrative cutscene scene.
#
# GameManager sets two fields before calling change_phase(CUTSCENE):
#   pending_cutscene     : String       — key into data/story.json
#   post_cutscene_phase  : GamePhase    — where to go after
#
# SPACE / ENTER advances line-by-line (handled by DialogueManager autoload).
# ESC skips the entire cutscene immediately.
extends Control

# ---------------------------------------------------------------------------
# Story data
# ---------------------------------------------------------------------------

const STORY_PATH := "res://data/story.json"

# ---------------------------------------------------------------------------
# Runtime nodes (built in code)
# ---------------------------------------------------------------------------

var _bg: ColorRect
var _accent_bar: ColorRect     # 4 px gold stripe at the very top
var _title_label: Label
var _location_label: Label
var _skip_hint: Label

# ---------------------------------------------------------------------------
# State guard — prevents _finish_cutscene running twice (ESC vs. natural end)
# ---------------------------------------------------------------------------
var _is_finishing: bool = false

# ---------------------------------------------------------------------------
# Lifecycle
# ---------------------------------------------------------------------------

func _ready() -> void:
	_build_ui()
	_load_and_start()
	set_process_unhandled_input(true)

	# Fade the background in (dialogue box is on a separate CanvasLayer and
	# is unaffected by this node's modulate).
	modulate.a = 0.0
	var tw := create_tween()
	tw.tween_property(self, "modulate:a", 1.0, 0.5).set_trans(Tween.TRANS_QUAD)

func _unhandled_input(event: InputEvent) -> void:
	if _is_finishing:
		return
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_finish_cutscene()

# ---------------------------------------------------------------------------
# UI construction — use explicit anchor/offset, never set_anchors_preset for
# anything that needs a non-zero height before the node is in the tree.
# ---------------------------------------------------------------------------

func _build_ui() -> void:
	# Full-screen background color
	_bg = ColorRect.new()
	_bg.anchor_left   = 0.0
	_bg.anchor_top    = 0.0
	_bg.anchor_right  = 1.0
	_bg.anchor_bottom = 1.0
	_bg.offset_left   = 0.0
	_bg.offset_top    = 0.0
	_bg.offset_right  = 0.0
	_bg.offset_bottom = 0.0
	_bg.color = Color(0.04, 0.02, 0.07)   # overwritten per-stage
	_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_bg)

	# 4 px accent stripe at the top
	_accent_bar = ColorRect.new()
	_accent_bar.anchor_left   = 0.0
	_accent_bar.anchor_top    = 0.0
	_accent_bar.anchor_right  = 1.0
	_accent_bar.anchor_bottom = 0.0
	_accent_bar.offset_left   = 0.0
	_accent_bar.offset_top    = 0.0
	_accent_bar.offset_right  = 0.0
	_accent_bar.offset_bottom = 4.0   # 4 px tall
	_accent_bar.color = Color(0.898, 0.753, 0.298)   # gold — overwritten per-stage
	_accent_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_accent_bar)

	# Stage title  (e.g. "THE CALL")
	_title_label = Label.new()
	_title_label.anchor_left  = 0.0
	_title_label.anchor_top   = 0.0
	_title_label.anchor_right = 1.0
	_title_label.offset_left  = 44.0
	_title_label.offset_top   = 18.0
	_title_label.offset_right = 0.0
	_title_label.add_theme_font_size_override("font_size", 11)
	_title_label.add_theme_color_override("font_color", Color(0.898, 0.753, 0.298, 0.9))
	_title_label.uppercase = true
	add_child(_title_label)

	# Location subtitle
	_location_label = Label.new()
	_location_label.anchor_left  = 0.0
	_location_label.anchor_top   = 0.0
	_location_label.anchor_right = 1.0
	_location_label.offset_left  = 44.0
	_location_label.offset_top   = 36.0
	_location_label.offset_right = 0.0
	_location_label.add_theme_font_size_override("font_size", 10)
	_location_label.add_theme_color_override("font_color", Color(0.45, 0.42, 0.35, 0.8))
	add_child(_location_label)

	# ESC skip hint in the bottom-right corner, just above the dialogue box
	_skip_hint = Label.new()
	_skip_hint.anchor_left   = 1.0
	_skip_hint.anchor_top    = 1.0
	_skip_hint.anchor_right  = 1.0
	_skip_hint.anchor_bottom = 1.0
	_skip_hint.offset_left   = -220.0
	_skip_hint.offset_top    = -180.0   # above the 160 px dialogue box
	_skip_hint.offset_right  = -20.0
	_skip_hint.offset_bottom = -165.0
	_skip_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_skip_hint.text = "ESC  —  Skip"
	_skip_hint.add_theme_font_size_override("font_size", 11)
	_skip_hint.add_theme_color_override("font_color", Color(0.35, 0.32, 0.28))
	add_child(_skip_hint)

# ---------------------------------------------------------------------------
# Data loading & dialogue kick-off
# ---------------------------------------------------------------------------

func _load_and_start() -> void:
	var stage_key: String = GameManager.pending_cutscene
	if stage_key.is_empty():
		push_warning("Cutscene: no pending_cutscene set on GameManager — finishing immediately.")
		_finish_cutscene()
		return

	var file := FileAccess.open(STORY_PATH, FileAccess.READ)
	if file == null:
		push_error("Cutscene: cannot open %s" % STORY_PATH)
		_finish_cutscene()
		return

	var json := JSON.new()
	if json.parse(file.get_as_text()) != OK:
		push_error("Cutscene: failed to parse story.json")
		file.close()
		_finish_cutscene()
		return
	file.close()

	var story: Dictionary = json.data
	if not story.has(stage_key):
		push_error("Cutscene: key '%s' not found in story.json" % stage_key)
		_finish_cutscene()
		return

	var stage: Dictionary = story[stage_key]

	# Apply colours
	if stage.has("bg_color"):
		_bg.color = Color(stage["bg_color"])
	if stage.has("accent_color"):
		_accent_bar.color = Color(stage["accent_color"])

	_title_label.text    = stage.get("title",    "").to_upper()
	_location_label.text = stage.get("location", "")

	var raw: Array = stage.get("lines", [])
	if raw.is_empty():
		push_warning("Cutscene: no lines for stage '%s'" % stage_key)
		_finish_cutscene()
		return

	# Build typed Array[Dictionary] for DialogueManager
	var lines: Array[Dictionary] = []
	for entry in raw:
		if entry is Dictionary:
			lines.append(entry)
		else:
			# Fallback: plain string with no speaker
			lines.append({"text": str(entry), "speaker": ""})

	# Pass portrait paths from the top-level "portraits" block if present
	if story.has("portraits") and story["portraits"] is Dictionary:
		DialogueManager.set_portraits(story["portraits"])

	DialogueManager.dialogue_finished.connect(_on_dialogue_finished, CONNECT_ONE_SHOT)
	DialogueManager.start_dialogue(lines)

# ---------------------------------------------------------------------------
# Completion
# ---------------------------------------------------------------------------

func _on_dialogue_finished() -> void:
	_finish_cutscene()

func _finish_cutscene() -> void:
	if _is_finishing:
		return
	_is_finishing = true

	# Disconnect the signal in case we're on the ESC/error path
	if DialogueManager.dialogue_finished.is_connected(_on_dialogue_finished):
		DialogueManager.dialogue_finished.disconnect(_on_dialogue_finished)

	# Force-close the dialogue box so it doesn't bleed into the next scene
	DialogueManager.force_close()

	# Record this cutscene as seen BEFORE calling change_phase so that
	# _get_cutscene_for_transition won't re-trigger the same cutscene.
	var next_phase: int = GameManager.post_cutscene_phase
	GameManager.mark_cutscene_seen(GameManager.pending_cutscene)

	# Fade out then transition
	var tw := create_tween()
	tw.tween_property(self, "modulate:a", 0.0, 0.35).set_trans(Tween.TRANS_QUAD)
	tw.tween_callback(func() -> void:
		GameManager.change_phase(next_phase)
	)


func debug_skip() -> void:
	_finish_cutscene()
