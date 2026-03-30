extends Control

## Move Upgrade — Shown after winning a fight.
## Fight 1: Choose "Upgrade Jab" or "Unlock Cross"
## Fight 2: Unlock Uppercut + choose 2 of 3 to equip
## Fight 3+: Skip straight to perk draft

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
var _selected_choice: String = ""
var _equip_selection: Array = []  # For equip_select phase
var _card_panels: Array = []
var _card_styles: Array = []

func _ready() -> void:
	confirm_btn.pressed.connect(_on_confirm)
	confirm_btn.disabled = true

	_options = GameManager.get_move_upgrade_options()

	match _options.get("type", "none"):
		"choose_unlock":
			_build_unlock_choice()
		"equip_select":
			_build_equip_select()
		_:
			# No upgrades — skip to perk draft
			_proceed()
			return

	Juice.fade_in(self, 0.4)
	Juice.scale_bounce(title_label, 1.1, 0.5)


func _build_unlock_choice() -> void:
	title_label.text = "MOVE UPGRADE"
	subtitle_label.text = "Choose your reward"

	# Option 1: Upgrade Jab
	_add_choice_card(
		"upgrade_jab",
		"UPGRADE JAB",
		"Jab deals +3 damage\nMore reliable, more punishing",
		Color(0.52, 0.22, 0.18),
	)

	# Option 2: Unlock Cross
	_add_choice_card(
		"unlock_cross",
		"UNLOCK CROSS",
		"New move: Cross\nGradual timing, medium damage",
		Color(0.58, 0.26, 0.16),
	)


func _build_equip_select() -> void:
	title_label.text = "UPPERCUT UNLOCKED!"
	subtitle_label.text = "Equip 2 moves for your loadout"
	Juice.screen_flash(self, Color(0.9, 0.8, 0.2, 0.2), 0.3)

	# Unlock uppercut
	GameManager.unlock_uppercut()

	var all_moves := BoxingAction.create_all()
	for move_type in GameManager.unlocked_moves:
		var action: BoxingAction = all_moves[move_type]
		var id := action.name.to_lower()
		_add_equip_card(move_type, action)

	# Also add uppercut
	var uppercut: BoxingAction = all_moves[BoxingAction.ActionType.UPPERCUT]
	_add_equip_card(BoxingAction.ActionType.UPPERCUT, uppercut)

	_update_equip_confirm()


func _add_choice_card(choice_id: String, title: String, desc: String, accent: Color) -> void:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(240, 200)

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
	vbox.add_theme_constant_override("separation", 12)

	var title_lbl := Label.new()
	title_lbl.text = title
	title_lbl.add_theme_font_size_override("font_size", 22)
	title_lbl.add_theme_color_override("font_color", accent.lightened(0.3))
	title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title_lbl)

	var accent_bar := ColorRect.new()
	accent_bar.custom_minimum_size = Vector2(80, 3)
	accent_bar.color = accent
	accent_bar.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	vbox.add_child(accent_bar)

	var desc_lbl := Label.new()
	desc_lbl.text = desc
	desc_lbl.add_theme_font_size_override("font_size", 14)
	desc_lbl.add_theme_color_override("font_color", Color(0.75, 0.72, 0.65))
	desc_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
	vbox.add_child(desc_lbl)

	panel.add_child(vbox)

	# Click handling via button overlay
	var btn := Button.new()
	btn.flat = true
	btn.anchors_preset = Control.PRESET_FULL_RECT
	btn.mouse_filter = Control.MOUSE_FILTER_STOP
	btn.pressed.connect(_on_choice_selected.bind(choice_id, _card_panels.size()))
	btn.mouse_entered.connect(func():
		AudioManager.play_button_hover()
		if _selected_choice != choice_id:
			style.border_color = accent.lightened(0.2)
	)
	btn.mouse_exited.connect(func():
		if _selected_choice != choice_id:
			style.border_color = CARD_BORDER
	)
	panel.add_child(btn)

	_card_panels.append(panel)
	_card_styles.append(style)
	card_container.add_child(panel)


func _add_equip_card(move_type: BoxingAction.ActionType, action: BoxingAction) -> void:
	var accent := Color(0.5, 0.4, 0.6)
	match action.name:
		"Jab": accent = Color(0.52, 0.22, 0.18)
		"Cross": accent = Color(0.58, 0.26, 0.16)
		"Uppercut": accent = Color(0.62, 0.26, 0.14)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(200, 180)

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
	vbox.add_theme_constant_override("separation", 8)

	var title_lbl := Label.new()
	title_lbl.text = action.name.to_upper()
	title_lbl.add_theme_font_size_override("font_size", 22)
	title_lbl.add_theme_color_override("font_color", accent.lightened(0.3))
	title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title_lbl)

	var desc_lbl := Label.new()
	desc_lbl.text = action.description
	desc_lbl.add_theme_font_size_override("font_size", 13)
	desc_lbl.add_theme_color_override("font_color", Color(0.7, 0.68, 0.6))
	desc_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
	vbox.add_child(desc_lbl)

	var dmg_lbl := Label.new()
	var dmg_text := "DMG: %d" % action.damage
	if move_type == BoxingAction.ActionType.JAB and GameManager.jab_upgraded:
		dmg_text = "DMG: %d (+3)" % (action.damage + 3)
	dmg_lbl.text = dmg_text
	dmg_lbl.add_theme_font_size_override("font_size", 14)
	dmg_lbl.add_theme_color_override("font_color", Color(0.85, 0.75, 0.35))
	dmg_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(dmg_lbl)

	panel.add_child(vbox)

	var idx := _card_panels.size()
	var btn := Button.new()
	btn.flat = true
	btn.anchors_preset = Control.PRESET_FULL_RECT
	btn.mouse_filter = Control.MOUSE_FILTER_STOP
	btn.pressed.connect(_on_equip_toggled.bind(move_type, idx))
	btn.mouse_entered.connect(func():
		AudioManager.play_button_hover()
	)
	panel.add_child(btn)

	panel.set_meta("move_type", move_type)
	_card_panels.append(panel)
	_card_styles.append(style)
	card_container.add_child(panel)


func _on_choice_selected(choice_id: String, index: int) -> void:
	AudioManager.play_button_click()
	_selected_choice = choice_id
	confirm_btn.disabled = false

	for i in _card_panels.size():
		if i == index:
			_card_styles[i].border_color = CARD_BORDER_SELECTED
			_card_styles[i].bg_color = CARD_SELECTED
			Juice.scale_bounce(_card_panels[i], 1.05, 0.2)
		else:
			_card_styles[i].border_color = CARD_BORDER
			_card_styles[i].bg_color = CARD_BG


func _on_equip_toggled(move_type: BoxingAction.ActionType, index: int) -> void:
	AudioManager.play_button_click()

	if move_type in _equip_selection:
		_equip_selection.erase(move_type)
	else:
		if _equip_selection.size() >= 2:
			# Remove oldest selection
			_equip_selection.pop_front()
		_equip_selection.append(move_type)

	# Update card visuals
	for i in _card_panels.size():
		var mt = _card_panels[i].get_meta("move_type")
		if mt in _equip_selection:
			_card_styles[i].border_color = CARD_BORDER_SELECTED
			_card_styles[i].bg_color = CARD_SELECTED
		else:
			_card_styles[i].border_color = CARD_BORDER
			_card_styles[i].bg_color = CARD_BG

	Juice.scale_bounce(_card_panels[index], 1.05, 0.2)
	_update_equip_confirm()


func _update_equip_confirm() -> void:
	confirm_btn.disabled = _equip_selection.size() != 2
	if _equip_selection.size() == 2:
		confirm_btn.text = "CONFIRM LOADOUT"
	else:
		confirm_btn.text = "Select 2 moves (%d/2)" % _equip_selection.size()


func _on_confirm() -> void:
	AudioManager.play_confirm()
	Juice.screen_flash(self, Color(0.9, 0.8, 0.2, 0.2), 0.2)

	match _options.get("type", "none"):
		"choose_unlock":
			GameManager.apply_move_choice(_selected_choice)
		"equip_select":
			GameManager.set_equipped_moves(_equip_selection)

	_proceed()


func _proceed() -> void:
	GameManager.change_phase(GameManager.GamePhase.PERK_DRAFT)
