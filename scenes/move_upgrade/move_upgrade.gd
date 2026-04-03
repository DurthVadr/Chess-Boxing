extends Control

## Move Upgrade — Now a Symbol Draft phase.
## After winning a fight, player drafts action symbols to add to their reels.
## Each draft offers a choice of symbols; player picks one and assigns it to a reel.

@onready var title_label: Label = %TitleLabel
@onready var subtitle_label: Label = %SubtitleLabel
@onready var card_container: HBoxContainer = %CardContainer
@onready var confirm_btn: Button = %ConfirmBtn

const GOLD := Color(0.92, 0.80, 0.28)
const CARD_BG := Color(0.12, 0.10, 0.18)
const CARD_SELECTED := Color(0.22, 0.18, 0.32)
const CARD_BORDER := Color(0.35, 0.30, 0.50)
const CARD_BORDER_SELECTED := Color(0.92, 0.80, 0.28)

var _options: Dictionary = {}
var _picks_remaining: int = 0
var _selected_symbol: BoxingAction.ActionType = BoxingAction.ActionType.JAB
var _selected_reel: int = -1
var _has_symbol_selected: bool = false
var _card_panels: Array = []
var _card_styles: Array = []
var _reel_buttons: Array = []
var _reel_styles: Array = []

func _ready() -> void:
	confirm_btn.pressed.connect(_on_confirm)
	confirm_btn.disabled = true

	_options = GameManager.get_move_upgrade_options()

	if _options.get("type", "none") == "symbol_draft":
		_picks_remaining = _options.get("picks", 2)
		_build_symbol_draft()
	else:
		_proceed()
		return

	Juice.fade_in(self, 0.4)
	Juice.scale_bounce(title_label, 1.1, 0.5)


func _build_symbol_draft() -> void:
	title_label.text = "SYMBOL DRAFT"
	subtitle_label.text = "Pick a symbol to add to a reel (%d remaining)" % _picks_remaining

	_clear_cards()

	var pool: Array = _options.get("pool", [])
	var all_actions := BoxingAction.create_all()

	for symbol_type in pool:
		var action: BoxingAction = all_actions[symbol_type]
		_add_symbol_card(symbol_type, action)

	# Reel selection buttons (below the cards)
	_build_reel_selector()
	_update_confirm()


func _clear_cards() -> void:
	for child in card_container.get_children():
		child.queue_free()
	_card_panels.clear()
	_card_styles.clear()
	_has_symbol_selected = false
	_selected_reel = -1

	# Remove old reel selector if present
	var old_selector := get_node_or_null("ReelSelector")
	if old_selector:
		old_selector.queue_free()
	_reel_buttons.clear()
	_reel_styles.clear()


func _add_symbol_card(symbol_type: BoxingAction.ActionType, action: BoxingAction) -> void:
	var accent := ReelSystem.symbol_color(symbol_type)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(200, 200)

	var style := StyleBoxFlat.new()
	style.bg_color = CARD_BG
	style.corner_radius_top_left = 12
	style.corner_radius_top_right = 12
	style.corner_radius_bottom_left = 12
	style.corner_radius_bottom_right = 12
	style.border_width_left = 3
	style.border_width_right = 3
	style.border_width_top = 3
	style.border_width_bottom = 3
	style.border_color = CARD_BORDER
	style.content_margin_left = 16
	style.content_margin_right = 16
	style.content_margin_top = 16
	style.content_margin_bottom = 16
	panel.add_theme_stylebox_override("panel", style)

	var vbox := VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 10)

	# Symbol name
	var title_lbl := Label.new()
	title_lbl.text = action.name.to_upper()
	title_lbl.add_theme_font_size_override("font_size", 24)
	title_lbl.add_theme_color_override("font_color", ReelSystem.symbol_accent(symbol_type))
	title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title_lbl)

	# Accent bar
	var bar := ColorRect.new()
	bar.custom_minimum_size = Vector2(80, 3)
	bar.color = accent
	bar.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	vbox.add_child(bar)

	# Description
	var desc_lbl := Label.new()
	desc_lbl.text = action.description
	desc_lbl.add_theme_font_size_override("font_size", 13)
	desc_lbl.add_theme_color_override("font_color", Color(0.7, 0.68, 0.6))
	desc_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
	vbox.add_child(desc_lbl)

	# Damage
	var dmg_lbl := Label.new()
	dmg_lbl.text = "DMG: %d" % action.damage
	dmg_lbl.add_theme_font_size_override("font_size", 14)
	dmg_lbl.add_theme_color_override("font_color", GOLD)
	dmg_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(dmg_lbl)

	panel.add_child(vbox)

	# Click overlay
	var idx := _card_panels.size()
	var btn := Button.new()
	btn.flat = true
	btn.anchors_preset = Control.PRESET_FULL_RECT
	btn.mouse_filter = Control.MOUSE_FILTER_STOP
	btn.pressed.connect(_on_symbol_selected.bind(symbol_type, idx))
	btn.mouse_entered.connect(func():
		AudioManager.play_button_hover()
		if not _has_symbol_selected or _selected_symbol != symbol_type:
			style.border_color = accent.lightened(0.2)
	)
	btn.mouse_exited.connect(func():
		if not _has_symbol_selected or _selected_symbol != symbol_type:
			style.border_color = CARD_BORDER
	)
	panel.add_child(btn)

	_card_panels.append(panel)
	_card_styles.append(style)
	card_container.add_child(panel)


func _build_reel_selector() -> void:
	var selector := HBoxContainer.new()
	selector.name = "ReelSelector"
	selector.alignment = BoxContainer.ALIGNMENT_CENTER
	selector.add_theme_constant_override("separation", 16)

	# Position it below the card container
	var parent := card_container.get_parent()
	var idx := card_container.get_index() + 1
	parent.add_child(selector)
	parent.move_child(selector, idx)

	var header := Label.new()
	header.text = "ADD TO REEL:"
	header.add_theme_font_size_override("font_size", 14)
	header.add_theme_color_override("font_color", Color(0.65, 0.60, 0.55))
	selector.add_child(header)

	for i in 3:
		var reel: Array = GameManager.reel_symbols[i]
		var dist := ReelSystem.get_reel_distribution(reel)

		var reel_panel := PanelContainer.new()
		reel_panel.custom_minimum_size = Vector2(130, 80)

		var style := StyleBoxFlat.new()
		style.bg_color = CARD_BG
		style.corner_radius_top_left = 8
		style.corner_radius_top_right = 8
		style.corner_radius_bottom_left = 8
		style.corner_radius_bottom_right = 8
		style.border_width_left = 2
		style.border_width_right = 2
		style.border_width_top = 2
		style.border_width_bottom = 2
		style.border_color = CARD_BORDER
		style.content_margin_left = 8
		style.content_margin_right = 8
		style.content_margin_top = 6
		style.content_margin_bottom = 6
		reel_panel.add_theme_stylebox_override("panel", style)

		var vbox := VBoxContainer.new()
		vbox.alignment = BoxContainer.ALIGNMENT_CENTER
		vbox.add_theme_constant_override("separation", 2)

		var title_lbl := Label.new()
		title_lbl.text = "REEL %d" % (i + 1)
		title_lbl.add_theme_font_size_override("font_size", 13)
		title_lbl.add_theme_color_override("font_color", Color(0.75, 0.72, 0.65))
		title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		vbox.add_child(title_lbl)

		# Show current symbol distribution
		var dist_text := ""
		var all_actions := BoxingAction.create_all()
		for action_type in dist:
			var act: BoxingAction = all_actions[action_type]
			dist_text += "%s x%d  " % [act.name, dist[action_type]]
		var dist_lbl := Label.new()
		dist_lbl.text = dist_text.strip_edges()
		dist_lbl.add_theme_font_size_override("font_size", 11)
		dist_lbl.add_theme_color_override("font_color", Color(0.55, 0.52, 0.48))
		dist_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		dist_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
		vbox.add_child(dist_lbl)

		reel_panel.add_child(vbox)

		var btn := Button.new()
		btn.flat = true
		btn.anchors_preset = Control.PRESET_FULL_RECT
		btn.mouse_filter = Control.MOUSE_FILTER_STOP
		btn.pressed.connect(_on_reel_selected.bind(i))
		btn.mouse_entered.connect(func():
			AudioManager.play_button_hover()
		)
		reel_panel.add_child(btn)

		selector.add_child(reel_panel)
		_reel_buttons.append(reel_panel)
		_reel_styles.append(style)


func _on_symbol_selected(symbol_type: BoxingAction.ActionType, index: int) -> void:
	AudioManager.play_button_click()
	_selected_symbol = symbol_type
	_has_symbol_selected = true

	for i in _card_panels.size():
		if i == index:
			_card_styles[i].border_color = CARD_BORDER_SELECTED
			_card_styles[i].bg_color = CARD_SELECTED
			Juice.scale_bounce(_card_panels[i], 1.05, 0.2)
		else:
			_card_styles[i].border_color = CARD_BORDER
			_card_styles[i].bg_color = CARD_BG

	_update_confirm()


func _on_reel_selected(reel_index: int) -> void:
	AudioManager.play_button_click()
	_selected_reel = reel_index

	for i in _reel_styles.size():
		if i == reel_index:
			_reel_styles[i].border_color = CARD_BORDER_SELECTED
			_reel_styles[i].bg_color = CARD_SELECTED
			Juice.scale_bounce(_reel_buttons[i], 1.05, 0.15)
		else:
			_reel_styles[i].border_color = CARD_BORDER
			_reel_styles[i].bg_color = CARD_BG

	_update_confirm()


func _update_confirm() -> void:
	var ready := _has_symbol_selected and _selected_reel >= 0
	confirm_btn.disabled = not ready
	if ready:
		var sym_name := ReelSystem.symbol_name(_selected_symbol)
		confirm_btn.text = "ADD %s TO REEL %d" % [sym_name.to_upper(), _selected_reel + 1]
	else:
		confirm_btn.text = "Select symbol & reel"


func _on_confirm() -> void:
	AudioManager.play_confirm()
	Juice.screen_flash(self, Color(0.9, 0.8, 0.2, 0.2), 0.2)

	# Add the symbol to the chosen reel
	GameManager.add_reel_symbol(_selected_reel, _selected_symbol)

	_picks_remaining -= 1
	if _picks_remaining > 0:
		# Another pick
		_build_symbol_draft()
	else:
		_proceed()


func _proceed() -> void:
	GameManager.change_phase(GameManager.GamePhase.SHOP)
