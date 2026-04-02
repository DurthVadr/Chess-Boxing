class_name ReelUI
extends Control

## Action selection UI — player picks one action per reel (3 total).
## Each reel's available symbols come from GameManager.reel_symbols.
## Emits `reels_stopped(results)` when all 3 actions are chosen.

signal reels_stopped(results: Array)  # Array of 3 BoxingAction.ActionType

const SLOT_WIDTH := 130
const SLOT_SPACING := 12
const BG_COLOR := Color(0.08, 0.06, 0.12)
const FRAME_COLOR := Color(0.35, 0.30, 0.50)
const FRAME_LOCKED := Color(0.92, 0.80, 0.28)
const LOCKED_BG := Color(0.14, 0.11, 0.20)
const GOLD := Color(0.92, 0.80, 0.28)

var _reels: Array = []                # 3 symbol arrays from GameManager
var _selections: Array = [-1, -1, -1] # Selected ActionType per reel (-1 = none)
var _current_reel: int = 0            # Which reel the player is picking for
var _slot_columns: Array = []         # 3 VBoxContainers holding buttons
var _slot_panels: Array = []          # 3 PanelContainers (the frames)
var _prompt_label: Label
var _triple_label: Label
var _confirm_btn: Button

func _ready() -> void:
	_reels = GameManager.reel_symbols.duplicate(true)
	_build_ui()

func _build_ui() -> void:
	var root := VBoxContainer.new()
	root.alignment = BoxContainer.ALIGNMENT_CENTER
	root.add_theme_constant_override("separation", 8)
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(root)

	# Prompt
	_prompt_label = Label.new()
	_prompt_label.text = "SELECT ACTION 1"
	_prompt_label.add_theme_font_size_override("font_size", 18)
	_prompt_label.add_theme_color_override("font_color", GOLD)
	_prompt_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(_prompt_label)

	# 3-column reel row
	var reel_row := HBoxContainer.new()
	reel_row.alignment = BoxContainer.ALIGNMENT_CENTER
	reel_row.add_theme_constant_override("separation", SLOT_SPACING)
	root.add_child(reel_row)

	for i in 3:
		var col := VBoxContainer.new()
		col.alignment = BoxContainer.ALIGNMENT_CENTER
		col.add_theme_constant_override("separation", 4)
		reel_row.add_child(col)

		# Header
		var header := Label.new()
		header.text = "ACTION %d" % (i + 1)
		header.add_theme_font_size_override("font_size", 11)
		header.add_theme_color_override("font_color", Color(0.55, 0.50, 0.65))
		header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		col.add_child(header)

		# Frame panel
		var panel := PanelContainer.new()
		panel.custom_minimum_size = Vector2(SLOT_WIDTH, 0)
		var style := StyleBoxFlat.new()
		style.bg_color = BG_COLOR
		style.corner_radius_top_left = 8
		style.corner_radius_top_right = 8
		style.corner_radius_bottom_left = 8
		style.corner_radius_bottom_right = 8
		style.border_width_left = 3
		style.border_width_right = 3
		style.border_width_top = 3
		style.border_width_bottom = 3
		style.border_color = FRAME_COLOR if i == 0 else Color(0.25, 0.22, 0.35)
		style.content_margin_left = 4
		style.content_margin_right = 4
		style.content_margin_top = 6
		style.content_margin_bottom = 6
		panel.add_theme_stylebox_override("panel", style)
		col.add_child(panel)
		_slot_panels.append(panel)

		# Button container inside panel
		var btn_col := VBoxContainer.new()
		btn_col.alignment = BoxContainer.ALIGNMENT_CENTER
		btn_col.add_theme_constant_override("separation", 4)
		panel.add_child(btn_col)
		_slot_columns.append(btn_col)

	# Triple match label (hidden)
	_triple_label = Label.new()
	_triple_label.text = ""
	_triple_label.add_theme_font_size_override("font_size", 26)
	_triple_label.add_theme_color_override("font_color", GOLD)
	_triple_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_triple_label.visible = false
	root.add_child(_triple_label)

	_populate_reel(0)


## Fill a reel column with action buttons based on the unique symbols in that reel.
func _populate_reel(reel_index: int) -> void:
	# Clear all columns
	for col in _slot_columns:
		for child in (col as VBoxContainer).get_children():
			child.queue_free()

	# Show locked selections for previous reels
	for i in reel_index:
		var locked_lbl := Label.new()
		locked_lbl.text = ReelSystem.symbol_name(_selections[i])
		locked_lbl.add_theme_font_size_override("font_size", 20)
		locked_lbl.add_theme_color_override("font_color", ReelSystem.symbol_accent(_selections[i]))
		locked_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		locked_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		locked_lbl.custom_minimum_size = Vector2(0, 44)
		(_slot_columns[i] as VBoxContainer).add_child(locked_lbl)

	# Show action buttons for the current reel
	if reel_index < 3:
		var reel: Array = _reels[reel_index]
		var unique_symbols := _get_unique_symbols(reel)

		for sym in unique_symbols:
			var btn := Button.new()
			var all_actions := BoxingAction.create_all()
			var action: BoxingAction = all_actions[sym]
			var dmg := action.damage
			if sym == BoxingAction.ActionType.JAB:
				dmg += GameManager.get_jab_damage_bonus()
			btn.text = "%s (%d)" % [action.name, dmg]
			btn.custom_minimum_size = Vector2(SLOT_WIDTH - 12, 40)
			btn.add_theme_font_size_override("font_size", 15)
			btn.tooltip_text = action.description

			var style := StyleBoxFlat.new()
			style.bg_color = ReelSystem.symbol_color(sym)
			style.corner_radius_top_left = 6
			style.corner_radius_top_right = 6
			style.corner_radius_bottom_left = 6
			style.corner_radius_bottom_right = 6
			btn.add_theme_stylebox_override("normal", style)

			var hover_style := style.duplicate()
			hover_style.bg_color = style.bg_color.lightened(0.2)
			btn.add_theme_stylebox_override("hover", hover_style)

			btn.pressed.connect(_on_action_picked.bind(reel_index, sym))
			btn.mouse_entered.connect(AudioManager.play_button_hover)
			(_slot_columns[reel_index] as VBoxContainer).add_child(btn)

	# Show empty placeholders for future reels
	for i in range(reel_index + 1, 3):
		var placeholder := Label.new()
		placeholder.text = "..."
		placeholder.add_theme_font_size_override("font_size", 18)
		placeholder.add_theme_color_override("font_color", Color(0.3, 0.28, 0.35))
		placeholder.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		placeholder.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		placeholder.custom_minimum_size = Vector2(0, 44)
		(_slot_columns[i] as VBoxContainer).add_child(placeholder)

	# Update panel highlights
	for i in 3:
		var style: StyleBoxFlat = (_slot_panels[i] as PanelContainer).get_theme_stylebox("panel") as StyleBoxFlat
		if i < reel_index:
			style.border_color = FRAME_LOCKED
			style.bg_color = LOCKED_BG
		elif i == reel_index:
			style.border_color = FRAME_COLOR
			style.bg_color = BG_COLOR
		else:
			style.border_color = Color(0.25, 0.22, 0.35)
			style.bg_color = BG_COLOR


func _on_action_picked(reel_index: int, symbol: BoxingAction.ActionType) -> void:
	AudioManager.play_button_click()
	_selections[reel_index] = symbol
	_current_reel = reel_index + 1

	# Lock the panel
	var panel: PanelContainer = _slot_panels[reel_index]
	Juice.scale_bounce(panel, 1.06, 0.18)

	if _current_reel >= 3:
		# All 3 selected — finalize
		_on_all_selected()
	else:
		_prompt_label.text = "SELECT ACTION %d" % (_current_reel + 1)
		_populate_reel(_current_reel)


func _on_all_selected() -> void:
	var results: Array = [_selections[0], _selections[1], _selections[2]]
	var is_triple := ReelSystem.is_triple(results)

	_populate_reel(3)  # Show all locked

	if is_triple:
		var sym_name := ReelSystem.symbol_name(results[0])
		_triple_label.text = "TRIPLE %s!" % sym_name.to_upper()
		_triple_label.visible = true
		_prompt_label.text = "CRITICAL HIT!"
		Juice.punch_text(_triple_label)
		Juice.screen_shake(self, 10.0, 0.3)
		Juice.screen_flash(self, Color(0.9, 0.8, 0.2, 0.25), 0.3)
	else:
		_prompt_label.text = "%s - %s - %s" % [
			ReelSystem.symbol_name(results[0]),
			ReelSystem.symbol_name(results[1]),
			ReelSystem.symbol_name(results[2]),
		]

	await get_tree().create_timer(0.5 if not is_triple else 1.0).timeout
	reels_stopped.emit(results)


## Get unique symbols from a reel array, preserving ActionType order.
func _get_unique_symbols(reel: Array) -> Array:
	var seen := {}
	var unique := []
	for sym in reel:
		if sym not in seen:
			seen[sym] = true
			unique.append(sym)
	return unique
