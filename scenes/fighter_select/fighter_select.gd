extends Control

## Fighter Select — Carousel with centered focus card + right detail panel.
## Left/Right (or A/D) cycles cards. Focused card tweens to center of carousel area.

signal fighter_focused(fighter: Dictionary)

@onready var fighter_row: HBoxContainer = %FighterRow
@onready var confirm_btn: Button = %ConfirmBtn
@onready var elo_label: Label = %EloLabel
@onready var showcase_portrait: TextureRect = %ShowcasePortrait
@onready var showcase_name: Label = %ShowcaseName
@onready var showcase_elo: Label = %ShowcaseElo
@onready var showcase_stats: Label = %ShowcaseStats
@onready var showcase_passive: Label = %ShowcasePassive
@onready var blur_overlay: ColorRect = %BlurOverlay

var selected_fighter: Dictionary = {}
var _cards: Array[PanelContainer] = []
var _fighters: Array[Dictionary] = []
var _focused_index := 0
var _is_animating := false
var _carousel_area: Control

const FOCUS_SCALE := Vector2(1.15, 1.15)
const UNFOCUS_SCALE := Vector2(0.85, 0.85)
const FOCUS_ALPHA := 1.0
const UNFOCUS_ALPHA := 0.45
const CARD_W := 160.0
const CARD_H := 220.0
const CARD_GAP := 20.0

const CARD_COLORS := {
	"rookie":      Color(0.25, 0.45, 0.30),
	"grandmaster": Color(0.25, 0.32, 0.52),
	"brawler":     Color(0.52, 0.25, 0.22),
	"hustler":     Color(0.48, 0.38, 0.20),
	"prodigy":     Color(0.40, 0.25, 0.50),
}

func _ready() -> void:
	confirm_btn.pressed.connect(_on_confirm)
	confirm_btn.disabled = true
	elo_label.text = "Your ELO: %d" % SaveManager.player_elo
	fighter_focused.connect(_update_detail_panel)
	_carousel_area = fighter_row.get_parent()
	_setup_blur_overlay()
	_build_fighter_cards()
	call_deferred("_focus_initial_card")
	Juice.fade_in(self, 0.3)

func _unhandled_input(event: InputEvent) -> void:
	if _is_animating:
		return
	if event.is_action_pressed("ui_left"):
		_move_focus(-1)
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("ui_right"):
		_move_focus(1)
		get_viewport().set_input_as_handled()
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_A:
			_move_focus(-1)
			get_viewport().set_input_as_handled()
		elif event.keycode == KEY_D:
			_move_focus(1)
			get_viewport().set_input_as_handled()

func _setup_blur_overlay() -> void:
	var mat := ShaderMaterial.new()
	var shader := Shader.new()
	shader.code = """
shader_type canvas_item;
uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_linear_mipmap;
uniform float lod: hint_range(0.0, 5.0) = 2.0;
void fragment() {
	COLOR = textureLod(screen_texture, SCREEN_UV, lod);
}
"""
	mat.shader = shader
	blur_overlay.material = mat

# --- Card building (compact: portrait + name only) ---

func _build_fighter_cards() -> void:
	for child in fighter_row.get_children():
		child.queue_free()
	_cards.clear()
	_fighters.clear()

	for fighter in GameManager.all_fighters:
		var card := _make_fighter_card(fighter)
		fighter_row.add_child(card)
		_cards.append(card)
		_fighters.append(fighter)

func _make_fighter_card(fighter: Dictionary) -> PanelContainer:
	var fighter_id: String = fighter.get("id", "")
	var required_elo := SaveManager.get_fighter_required_elo(fighter_id)
	var unlocked := SaveManager.is_fighter_elo_unlocked(fighter_id)
	if unlocked and not SaveManager.is_fighter_unlocked(fighter_id):
		SaveManager.unlock_fighter(fighter_id)

	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(CARD_W, CARD_H)
	card.pivot_offset = Vector2(CARD_W, CARD_H) * 0.5

	var bg := StyleBoxFlat.new()
	bg.corner_radius_top_left = 10
	bg.corner_radius_top_right = 10
	bg.corner_radius_bottom_left = 10
	bg.corner_radius_bottom_right = 10
	bg.border_width_left = 2
	bg.border_width_right = 2
	bg.border_width_top = 2
	bg.border_width_bottom = 2
	bg.bg_color = CARD_COLORS.get(fighter_id, Color(0.24, 0.24, 0.24)) if unlocked else Color(0.20, 0.20, 0.20)
	bg.border_color = Color(0.88, 0.78, 0.34, 0.2)
	card.add_theme_stylebox_override("panel", bg)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 4)
	card.add_child(vbox)

	# Small portrait
	var portrait := TextureRect.new()
	portrait.custom_minimum_size = Vector2(0, 160)
	portrait.size_flags_horizontal = SIZE_EXPAND_FILL
	portrait.size_flags_vertical = SIZE_EXPAND_FILL
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	if unlocked:
		var sprite_base: String = fighter.get("sprite_base", "")
		if sprite_base != "":
			var tex_path := "res://assets/sprites/fighters/%s_neutral.png" % sprite_base
			if ResourceLoader.exists(tex_path):
				portrait.texture = load(tex_path)
	else:
		portrait.modulate = Color(0.35, 0.35, 0.35, 1.0)
	vbox.add_child(portrait)

	# Name only
	var name_label := Label.new()
	name_label.text = fighter.get("name", "??") if unlocked else "??"
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.add_theme_font_size_override("font_size", 16)
	name_label.add_theme_color_override("font_color", Color(0.95, 0.92, 0.82, 1))
	vbox.add_child(name_label)

	# Clickable overlay
	var btn := Button.new()
	btn.flat = true
	btn.anchors_preset = PRESET_FULL_RECT
	btn.mouse_default_cursor_shape = CURSOR_POINTING_HAND
	btn.pressed.connect(_on_card_pressed.bind(fighter))
	card.add_child(btn)

	# Lock overlay
	if not unlocked:
		var lock_label := Label.new()
		lock_label.text = "??"
		lock_label.add_theme_font_size_override("font_size", 48)
		lock_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lock_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		lock_label.anchors_preset = PRESET_FULL_RECT
		lock_label.add_theme_color_override("font_color", Color(0.62, 0.60, 0.55, 0.85))
		card.add_child(lock_label)

	return card

# --- Focus / centering ---

func _focus_initial_card() -> void:
	if _cards.is_empty():
		return
	_focused_index = 0
	_layout_row()
	_center_on_index(_focused_index, false)
	_apply_focus_visuals(-1, _focused_index, false)
	fighter_focused.emit(_fighters[_focused_index])

func _move_focus(dir: int) -> void:
	if _cards.is_empty():
		return
	var old := _focused_index
	_focused_index = clampi(_focused_index + dir, 0, _cards.size() - 1)
	if old == _focused_index:
		return
	_center_on_index(_focused_index, true)
	_apply_focus_visuals(old, _focused_index, true)
	fighter_focused.emit(_fighters[_focused_index])

func _on_card_pressed(fighter: Dictionary) -> void:
	var idx := _fighters.find(fighter)
	if idx < 0:
		return
	var old := _focused_index
	_focused_index = idx
	_center_on_index(_focused_index, true)
	_apply_focus_visuals(old, _focused_index, true)
	fighter_focused.emit(fighter)

func _layout_row() -> void:
	# Manually position cards so we can freely tween the row's x offset.
	var x := 0.0
	for card in _cards:
		card.position.x = x
		card.position.y = 0.0
		x += CARD_W + CARD_GAP
	fighter_row.custom_minimum_size.x = x - CARD_GAP if _cards.size() > 0 else 0.0
	fighter_row.size.x = fighter_row.custom_minimum_size.x

func _center_on_index(index: int, animate: bool) -> void:
	# Slide fighter_row so that _cards[index] sits at the horizontal center of _carousel_area.
	var area_w := _carousel_area.size.x
	var card_center_local := _cards[index].position.x + CARD_W * 0.5
	var target_x := area_w * 0.5 - card_center_local

	if not animate:
		fighter_row.position.x = target_x
		return

	_is_animating = true
	var tw := create_tween()
	tw.tween_property(fighter_row, "position:x", target_x, 0.25) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.finished.connect(func() -> void: _is_animating = false)

func _apply_focus_visuals(prev_idx: int, next_idx: int, animate: bool) -> void:
	for i in _cards.size():
		var card := _cards[i]
		var focus := i == next_idx
		var target_scale := FOCUS_SCALE if focus else UNFOCUS_SCALE
		var target_alpha := FOCUS_ALPHA if focus else UNFOCUS_ALPHA
		# Highlight border on focused card
		var bg: StyleBoxFlat = card.get_theme_stylebox("panel")
		if bg:
			bg.border_color = Color(0.9, 0.78, 0.35, 0.9) if focus else Color(0.88, 0.78, 0.34, 0.2)
		if animate:
			var tw := create_tween()
			tw.set_parallel(true)
			tw.tween_property(card, "scale", target_scale, 0.2) \
				.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
			tw.tween_property(card, "modulate:a", target_alpha, 0.2) \
				.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		else:
			card.scale = target_scale
			card.modulate.a = target_alpha

# --- Detail panel (right side) ---

func _update_detail_panel(fighter: Dictionary) -> void:
	selected_fighter = fighter
	var fighter_id: String = fighter.get("id", "")
	var unlocked := SaveManager.is_fighter_elo_unlocked(fighter_id)
	var required_elo := SaveManager.get_fighter_required_elo(fighter_id)

	if unlocked:
		var pattern_text := _pattern_text(fighter.get("attack_pattern", []))
		var dmg_pct := int(round(float(fighter.get("damage_mod", 1.0)) * 100.0))
		var regen := int(fighter.get("regen_per_turn", 0))
		var solve_bonus := int(fighter.get("solve_bonus_damage", 0))
		var puzzle_bonus := float(fighter.get("puzzle_time_bonus", 0.0))
		var puzzle_penalty := float(fighter.get("puzzle_error_penalty", 2.0))

		showcase_name.text = fighter.get("name", "???")
		showcase_elo.text = "ELO Requirement: %d" % required_elo
		showcase_stats.text = "HP: %d  |  DMG: %d%%  |  Regen: +%d  |  Solve: +%d" % [
			fighter.get("hp", 0), dmg_pct, regen, solve_bonus
		]
		showcase_passive.text = "%s\nPattern: %s\nPuzzle: +%.1fs  |  Error: %.1fs" % [
			fighter.get("passive_description", "No passive"), pattern_text,
			puzzle_bonus, puzzle_penalty
		]
		var sprite_base: String = fighter.get("sprite_base", "")
		if sprite_base != "":
			var tex_path := "res://assets/sprites/fighters/%s_neutral.png" % sprite_base
			if ResourceLoader.exists(tex_path):
				showcase_portrait.texture = load(tex_path)
			else:
				showcase_portrait.texture = null
		else:
			showcase_portrait.texture = null
	else:
		showcase_name.text = "??"
		showcase_elo.text = "Requires ELO %d  |  Your ELO: %d" % [required_elo, SaveManager.player_elo]
		showcase_stats.text = "HP: ??  |  DMG: ??"
		showcase_passive.text = "Locked. Reach required ELO in tournaments."
		showcase_portrait.texture = null

	confirm_btn.disabled = not unlocked

func _pattern_text(pattern: Array) -> String:
	if pattern.is_empty():
		return "JAB"
	var parts: Array[String] = []
	for token in pattern:
		var t := str(token).to_upper()
		parts.append(t)
	return "-".join(parts)

func _on_confirm() -> void:
	if selected_fighter.is_empty():
		return
	var fighter_id: String = selected_fighter.get("id", "")
	if not SaveManager.is_fighter_elo_unlocked(fighter_id):
		return
	AudioManager.play_confirm()
	GameManager.start_new_run(selected_fighter)
