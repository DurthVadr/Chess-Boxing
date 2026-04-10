# dialogue_manager.gd
# Autoload CanvasLayer — registered in project.godot as:
#   DialogueManager="*res://scenes/dialogue/dialogue_manager.gd"
#
# Renders at layer 90 (below CRT overlay at 100).
#
# Usage:
#   DialogueManager.start_dialogue(lines)   # lines: Array[Dictionary]
#     Each entry: { "text": String, "speaker": String }
#   DialogueManager.set_portraits(map)
#   DialogueManager.force_close()
extends CanvasLayer

# ---------------------------------------------------------------------------
# Signals
# ---------------------------------------------------------------------------

signal dialogue_finished

# ---------------------------------------------------------------------------
# Tuning
# ---------------------------------------------------------------------------

## Seconds per character — lower = faster.
@export var text_speed: float = 0.020

## Pause after sentence-ending punctuation (. ! ?)
const PAUSE_SENTENCE := 0.28
## Pause after clause punctuation (, ; :)
const PAUSE_CLAUSE   := 0.11

const BOX_HEIGHT     := 170.0
const PORTRAIT_WIDTH := 130.0

# Speaker → left-border accent color (shown on the nameplate strip)
const SPEAKER_COLORS := {
	"rookie": Color(0.898, 0.753, 0.298),   # gold
	"mentor": Color(0.431, 0.682, 0.898),   # blue
	"magnus": Color(0.863, 0.431, 0.431),   # red
	"dev":    Color(0.553, 0.898, 0.431),   # green
	"system": Color(0.700, 0.700, 0.700),   # grey
}

# ---------------------------------------------------------------------------
# Portrait paths
# ---------------------------------------------------------------------------

var portrait_paths: Dictionary = {
	"rookie": "res://assets/sprites/fighters/rookie_neutral.png",
	"mentor": "res://assets/sprites/fighters/mentor_neutral.png",
	"magnus": "res://assets/sprites/opponents/magnus_neutral.png",
	"dev":    "res://assets/sprites/npc/dev_happy.png",
	"system": "res://assets/sprites/ui/system_icon.png",
}
var _texture_cache: Dictionary = {}

# ---------------------------------------------------------------------------
# Runtime nodes
# ---------------------------------------------------------------------------

var _box: PanelContainer
var _portrait_panel: Panel
var _portrait_rect: TextureRect
var _portrait_fade: ColorRect      # dark vignette at portrait bottom
var _nameplate: PanelContainer
var _name_accent: ColorRect        # colored left border on nameplate
var _name_label: Label
var _dialogue_text: RichTextLabel
var _prompt_label: Label

# ---------------------------------------------------------------------------
# Internal state
# ---------------------------------------------------------------------------

var _lines: Array[Dictionary] = []
var _current_index: int       = 0
var _is_typing: bool          = false
var _type_gen: int            = 0   # incremented to cancel in-flight coroutine
var _prompt_tween: Tween
var _current_speaker: String  = ""

# ---------------------------------------------------------------------------
# Lifecycle
# ---------------------------------------------------------------------------

func _ready() -> void:
	layer = 90
	_build_ui()
	_box.hide()
	set_process_unhandled_input(true)

# ---------------------------------------------------------------------------
# UI construction
# ---------------------------------------------------------------------------

func _build_ui() -> void:
	# ── Outer box ────────────────────────────────────────────────────────────
	_box = PanelContainer.new()
	_box.name = "DialogueBox"
	_box.anchor_left   = 0.0
	_box.anchor_top    = 1.0
	_box.anchor_right  = 1.0
	_box.anchor_bottom = 1.0
	_box.offset_left   = 0.0
	_box.offset_top    = -BOX_HEIGHT
	_box.offset_right  = 0.0
	_box.offset_bottom = 0.0

	var box_style := StyleBoxFlat.new()
	box_style.bg_color              = Color(0.04, 0.025, 0.07, 0.97)
	box_style.border_color          = Color(0.898, 0.753, 0.298, 0.7)
	box_style.set_border_width_all(0)
	box_style.border_width_top      = 2
	box_style.set_corner_radius_all(0)
	box_style.content_margin_left   = 0.0
	box_style.content_margin_right  = 0.0
	box_style.content_margin_top    = 0.0
	box_style.content_margin_bottom = 0.0
	_box.add_theme_stylebox_override("panel", box_style)
	add_child(_box)

	# ── Horizontal split: [portrait | right content] ─────────────────────────
	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 0)
	_box.add_child(hbox)

	# ── Portrait panel ────────────────────────────────────────────────────────
	_portrait_panel = Panel.new()
	_portrait_panel.custom_minimum_size = Vector2(PORTRAIT_WIDTH, 0)
	_portrait_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_portrait_panel.clip_contents       = true

	var port_style := StyleBoxFlat.new()
	port_style.bg_color = Color(0.03, 0.02, 0.06)
	port_style.set_border_width_all(0)
	port_style.border_width_right = 2
	port_style.border_color       = Color(0.898, 0.753, 0.298, 0.4)
	port_style.set_corner_radius_all(0)
	_portrait_panel.add_theme_stylebox_override("panel", port_style)
	hbox.add_child(_portrait_panel)

	# Portrait image — STRETCH_KEEP_ASPECT_COVERED fills the panel and crops
	# from the bottom, keeping the face visible as a natural close-up.
	_portrait_rect = TextureRect.new()
	_portrait_rect.stretch_mode         = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_portrait_rect.expand_mode          = TextureRect.EXPAND_IGNORE_SIZE
	_portrait_rect.anchor_left          = 0.0
	_portrait_rect.anchor_top           = 0.0
	_portrait_rect.anchor_right         = 1.0
	_portrait_rect.anchor_bottom        = 1.0
	_portrait_rect.offset_left          = 0.0
	_portrait_rect.offset_top           = 0.0
	_portrait_rect.offset_right         = 0.0
	_portrait_rect.offset_bottom        = 0.0
	_portrait_rect.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_portrait_rect.size_flags_vertical   = Control.SIZE_EXPAND_FILL
	_portrait_panel.add_child(_portrait_rect)

	# Bottom-gradient vignette so the portrait blends into the dark box
	_portrait_fade = ColorRect.new()
	_portrait_fade.anchor_left   = 0.0
	_portrait_fade.anchor_top    = 0.6   # cover the bottom 40 %
	_portrait_fade.anchor_right  = 1.0
	_portrait_fade.anchor_bottom = 1.0
	_portrait_fade.offset_left   = 0.0
	_portrait_fade.offset_top    = 0.0
	_portrait_fade.offset_right  = 0.0
	_portrait_fade.offset_bottom = 0.0
	_portrait_fade.color         = Color(0.03, 0.02, 0.06, 0.6)
	_portrait_fade.mouse_filter  = Control.MOUSE_FILTER_IGNORE
	_portrait_panel.add_child(_portrait_fade)

	# ── Right content column ──────────────────────────────────────────────────
	var right_col := VBoxContainer.new()
	right_col.add_theme_constant_override("separation", 0)
	right_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right_col.size_flags_vertical   = Control.SIZE_EXPAND_FILL
	hbox.add_child(right_col)

	# ── Nameplate (speaker label row) ─────────────────────────────────────────
	_nameplate = PanelContainer.new()
	_nameplate.custom_minimum_size = Vector2(0, 30)

	var nameplate_style := StyleBoxFlat.new()
	nameplate_style.bg_color = Color(0.07, 0.04, 0.12, 1.0)
	nameplate_style.set_border_width_all(0)
	nameplate_style.border_width_bottom = 1
	nameplate_style.border_color        = Color(0.898, 0.753, 0.298, 0.25)
	nameplate_style.set_corner_radius_all(0)
	nameplate_style.content_margin_left   = 0.0
	nameplate_style.content_margin_right  = 0.0
	nameplate_style.content_margin_top    = 0.0
	nameplate_style.content_margin_bottom = 0.0
	_nameplate.add_theme_stylebox_override("panel", nameplate_style)
	right_col.add_child(_nameplate)

	# Nameplate inner HBox: [colored accent bar | name label]
	var nameplate_hbox := HBoxContainer.new()
	nameplate_hbox.add_theme_constant_override("separation", 0)
	_nameplate.add_child(nameplate_hbox)

	_name_accent = ColorRect.new()
	_name_accent.custom_minimum_size = Vector2(4, 0)
	_name_accent.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_name_accent.color               = Color(0.898, 0.753, 0.298)
	nameplate_hbox.add_child(_name_accent)

	_name_label = Label.new()
	_name_label.name = "NameLabel"
	_name_label.add_theme_font_size_override("font_size", 12)
	_name_label.add_theme_color_override("font_color", Color(0.898, 0.753, 0.298))
	_name_label.vertical_alignment  = VERTICAL_ALIGNMENT_CENTER
	var name_margin := MarginContainer.new()
	name_margin.add_theme_constant_override("margin_left",   10)
	name_margin.add_theme_constant_override("margin_right",  10)
	name_margin.add_theme_constant_override("margin_top",     0)
	name_margin.add_theme_constant_override("margin_bottom",  0)
	name_margin.size_flags_vertical = Control.SIZE_EXPAND_FILL
	name_margin.add_child(_name_label)
	nameplate_hbox.add_child(name_margin)

	# ── Text + prompt inside a margin ─────────────────────────────────────────
	var text_margin := MarginContainer.new()
	text_margin.add_theme_constant_override("margin_left",   18)
	text_margin.add_theme_constant_override("margin_right",  18)
	text_margin.add_theme_constant_override("margin_top",    10)
	text_margin.add_theme_constant_override("margin_bottom",  8)
	text_margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text_margin.size_flags_vertical   = Control.SIZE_EXPAND_FILL
	right_col.add_child(text_margin)

	var text_vbox := VBoxContainer.new()
	text_vbox.add_theme_constant_override("separation", 4)
	text_margin.add_child(text_vbox)

	_dialogue_text = RichTextLabel.new()
	_dialogue_text.name             = "DialogueText"
	_dialogue_text.bbcode_enabled   = true
	_dialogue_text.scroll_active    = false
	_dialogue_text.autowrap_mode    = TextServer.AUTOWRAP_WORD_SMART
	_dialogue_text.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_dialogue_text.add_theme_font_size_override("normal_font_size", 17)
	_dialogue_text.add_theme_color_override("default_color", Color(0.93, 0.91, 0.87))
	text_vbox.add_child(_dialogue_text)

	_prompt_label = Label.new()
	_prompt_label.name                 = "PromptLabel"
	_prompt_label.text                 = "▼"
	_prompt_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_prompt_label.add_theme_font_size_override("font_size", 13)
	_prompt_label.add_theme_color_override("font_color", Color(0.898, 0.753, 0.298, 0.9))
	_prompt_label.modulate.a = 0.0
	text_vbox.add_child(_prompt_label)

# ---------------------------------------------------------------------------
# Public API
# ---------------------------------------------------------------------------

func set_portraits(map: Dictionary) -> void:
	portrait_paths.merge(map, true)

func start_dialogue(lines: Array[Dictionary]) -> void:
	if lines.is_empty():
		push_warning("DialogueManager.start_dialogue(): empty lines array.")
		return
	_lines         = lines
	_current_index = 0
	_box.show()
	AudioManager.play_dialogue_open()
	_type_current_line()

func force_close() -> void:
	_type_gen += 1
	if _prompt_tween and _prompt_tween.is_valid():
		_prompt_tween.kill()
	_is_typing = false
	_lines.clear()
	_box.hide()

# ---------------------------------------------------------------------------
# Input
# ---------------------------------------------------------------------------

func _unhandled_input(event: InputEvent) -> void:
	if not _box.visible:
		return
	if not event.is_action_pressed("ui_accept"):
		return
	get_viewport().set_input_as_handled()
	if _is_typing:
		_finish_typing()
	else:
		_advance()

# ---------------------------------------------------------------------------
# Typewriter engine
# ---------------------------------------------------------------------------

func _type_current_line() -> void:
	var entry: Dictionary = _lines[_current_index]
	var line: String      = entry.get("text",    "")
	var speaker: String   = entry.get("speaker", "")

	_set_portrait(speaker)
	_set_nameplate(speaker)

	_dialogue_text.text               = line
	_dialogue_text.visible_characters = 0
	_is_typing = true

	if _prompt_tween and _prompt_tween.is_valid():
		_prompt_tween.kill()
	_prompt_label.modulate.a = 0.0

	_type_gen += 1
	_run_typewriter(line, _type_gen)

## Character-by-character typewriter. Pauses at punctuation, plays tick per char.
func _run_typewriter(line: String, gen: int) -> void:
	var total := _dialogue_text.get_total_character_count()
	for i in total:
		if _type_gen != gen:
			return
		_dialogue_text.visible_characters = i + 1

		var ch := line[i] if i < line.length() else ""

		# Tick sound only on visible non-punctuation characters
		if ch.strip_edges() != "" and ch not in [".", ",", "!", "?", ";", ":"]:
			AudioManager.play_dialogue_tick()

		var delay: float
		if ch in [".", "!", "?"]:
			delay = PAUSE_SENTENCE
		elif ch in [",", ";", ":"]:
			delay = PAUSE_CLAUSE
		else:
			delay = text_speed

		await get_tree().create_timer(delay).timeout

	if _type_gen == gen:
		_on_tween_finished()

func _set_portrait(speaker: String) -> void:
	var has_portrait: bool = (not speaker.is_empty()) and portrait_paths.has(speaker)

	if not has_portrait:
		_portrait_panel.visible                 = false
		_portrait_panel.custom_minimum_size.x   = 0.0
		return

	_portrait_panel.visible                 = true
	_portrait_panel.custom_minimum_size.x   = PORTRAIT_WIDTH

	# Fade out → swap → fade in for a clean speaker transition
	if speaker != _current_speaker:
		var fade := create_tween()
		fade.tween_property(_portrait_rect, "modulate:a", 0.0, 0.08)
		fade.tween_callback(func() -> void:
			_load_portrait_texture(portrait_paths[speaker])
			var fade_in := create_tween()
			fade_in.tween_property(_portrait_rect, "modulate:a", 1.0, 0.12)
		)
	else:
		_load_portrait_texture(portrait_paths[speaker])

	_current_speaker = speaker

func _load_portrait_texture(path: String) -> void:
	if _texture_cache.has(path):
		_portrait_rect.texture = _texture_cache[path]
		return
	var tex := load(path) as Texture2D
	if tex == null:
		push_warning("DialogueManager: portrait not found at '%s'" % path)
		_portrait_panel.visible = false
		_portrait_panel.custom_minimum_size.x = 0.0
		return
	_texture_cache[path] = tex
	_portrait_rect.texture = tex

func _set_nameplate(speaker: String) -> void:
	if speaker.is_empty():
		_nameplate.visible = false
		return

	_nameplate.visible = true

	# Display name — derive from portrait_paths keys to keep it DRY
	var display_names := {
		"rookie": "THE ROOKIE",
		"mentor": "MENTOR",
		"magnus": "MAGNUS",
		"dev":    "THE DEVS",
		"system": "SYSTEM",
	}
	_name_label.text = display_names.get(speaker, speaker.to_upper())

	# Accent bar color per speaker
	var accent: Color = SPEAKER_COLORS.get(speaker, Color(0.898, 0.753, 0.298))
	_name_accent.color = accent
	_name_label.add_theme_color_override("font_color", accent)

func _on_tween_finished() -> void:
	_is_typing = false
	_prompt_label.modulate.a = 1.0
	_prompt_tween = create_tween().set_loops()
	_prompt_tween.tween_property(_prompt_label, "modulate:a", 0.15, 0.6)
	_prompt_tween.tween_property(_prompt_label, "modulate:a", 1.0,  0.4)

func _finish_typing() -> void:
	_type_gen += 1  # cancel running coroutine
	_dialogue_text.visible_characters = _dialogue_text.get_total_character_count()
	_is_typing = false
	_prompt_label.modulate.a = 1.0
	AudioManager.play_dialogue_advance()

func _advance() -> void:
	if _prompt_tween and _prompt_tween.is_valid():
		_prompt_tween.kill()
	AudioManager.play_dialogue_advance()
	_current_index += 1
	if _current_index < _lines.size():
		_type_current_line()
	else:
		_close()

func _close() -> void:
	_box.hide()
	_lines.clear()
	_current_index = 0
	_current_speaker = ""
	dialogue_finished.emit()
