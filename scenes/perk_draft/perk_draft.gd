extends Control

## Perk Draft — Pick 1 of 3 perks between fights

@onready var card_container: HBoxContainer = %CardContainer
@onready var title_label: Label = %TitleLabel
@onready var perk_count_label: Label = %PerkCountLabel
@onready var continue_btn: Button = %ContinueBtn

var choices: Array = []
var selected_index: int = -1
var card_panels: Array = []

const TYPE_COLORS := {
	"chess": Color(0.2, 0.3, 0.7),
	"boxing": Color(0.7, 0.2, 0.2),
	"hybrid": Color(0.5, 0.2, 0.6),
	"wild": Color(0.7, 0.6, 0.1),
}

const TYPE_LABELS := {
	"chess": "♟ CHESS",
	"boxing": "🥊 BOXING",
	"hybrid": "⚡ HYBRID",
	"wild": "★ WILD",
}

func _ready() -> void:
	continue_btn.pressed.connect(_on_continue)
	continue_btn.disabled = true

	choices = GameManager.get_draft_choices(3)
	_update_perk_count()
	_build_cards()

	Juice.fade_in(self, 0.4)

func _update_perk_count() -> void:
	var chess_count := GameManager.get_perk_count_by_type("chess")
	var boxing_count := GameManager.get_perk_count_by_type("boxing")
	var hybrid_count := GameManager.get_perk_count_by_type("hybrid")
	perk_count_label.text = "Perks: ♟%d  🥊%d  ⚡%d" % [chess_count, boxing_count, hybrid_count]

	# Show set bonus hint
	if chess_count >= 2:
		perk_count_label.text += "  (1 more ♟ = SET BONUS!)"
	if boxing_count >= 2:
		perk_count_label.text += "  (1 more 🥊 = SET BONUS!)"

func _build_cards() -> void:
	card_panels.clear()

	for i in choices.size():
		var perk: Dictionary = choices[i]
		var card := _create_perk_card(perk, i)
		card_container.add_child(card)
		card_panels.append(card)

		# Staggered card flip animation
		card.scale = Vector2(0.01, 1.0)
		card.pivot_offset = Vector2(130, 100)
		var tween := create_tween()
		tween.set_ease(Tween.EASE_OUT)
		tween.set_trans(Tween.TRANS_BACK)
		tween.tween_property(card, "scale:x", 1.0, 0.4).set_delay(0.2 + i * 0.2)

func _create_perk_card(perk: Dictionary, index: int) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(260, 200)

	var style := StyleBoxFlat.new()
	var type_color: Color = TYPE_COLORS.get(perk.type, Color(0.3, 0.3, 0.3))
	style.bg_color = type_color.darkened(0.5)
	style.corner_radius_top_left = 12
	style.corner_radius_top_right = 12
	style.corner_radius_bottom_left = 12
	style.corner_radius_bottom_right = 12
	style.border_width_left = 3
	style.border_width_right = 3
	style.border_width_top = 3
	style.border_width_bottom = 3
	style.border_color = type_color
	panel.add_theme_stylebox_override("panel", style)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)

	# Type badge
	var type_label := Label.new()
	type_label.text = TYPE_LABELS.get(perk.type, "?")
	type_label.add_theme_font_size_override("font_size", 12)
	type_label.add_theme_color_override("font_color", type_color.lightened(0.3))
	type_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(type_label)

	# Perk name
	var name_label := Label.new()
	name_label.text = perk.name
	name_label.add_theme_font_size_override("font_size", 22)
	name_label.add_theme_color_override("font_color", Color(0.95, 0.9, 0.8))
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(name_label)

	# Separator
	var sep := HSeparator.new()
	vbox.add_child(sep)

	# Description
	var desc_label := Label.new()
	desc_label.text = perk.description
	desc_label.add_theme_font_size_override("font_size", 15)
	desc_label.add_theme_color_override("font_color", Color(0.75, 0.75, 0.75))
	desc_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(desc_label)

	# Rarity
	var rarity_label := Label.new()
	rarity_label.text = perk.get("rarity", "common").to_upper()
	rarity_label.add_theme_font_size_override("font_size", 11)
	match perk.get("rarity", "common"):
		"common": rarity_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
		"uncommon": rarity_label.add_theme_color_override("font_color", Color(0.3, 0.7, 0.3))
		"rare": rarity_label.add_theme_color_override("font_color", Color(0.9, 0.78, 0.3))
	rarity_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(rarity_label)

	panel.add_child(vbox)

	# Make clickable
	var btn := Button.new()
	btn.flat = true
	btn.anchors_preset = Control.PRESET_FULL_RECT
	btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	btn.pressed.connect(_on_card_selected.bind(index))
	panel.add_child(btn)

	return panel

func _on_card_selected(index: int) -> void:
	selected_index = index
	continue_btn.disabled = false

	# Highlight selected, dim others
	for i in card_panels.size():
		var panel: PanelContainer = card_panels[i]
		var style: StyleBoxFlat = panel.get_theme_stylebox("panel")
		if i == index:
			style.border_color = Color(0.9, 0.78, 0.3)
			style.border_width_left = 4
			style.border_width_right = 4
			style.border_width_top = 4
			style.border_width_bottom = 4
			Juice.scale_bounce(panel, 1.05, 0.2)
		else:
			var type_color: Color = TYPE_COLORS.get(choices[i].type, Color(0.3, 0.3, 0.3))
			style.border_color = type_color.darkened(0.3)
			style.border_width_left = 2
			style.border_width_right = 2
			style.border_width_top = 2
			style.border_width_bottom = 2
			panel.modulate = Color(0.6, 0.6, 0.6)

	card_panels[index].modulate = Color.WHITE

func _on_continue() -> void:
	if selected_index < 0 or selected_index >= choices.size():
		return

	GameManager.add_perk(choices[selected_index])

	# Check set bonuses
	_check_set_bonuses()

	# Go to tournament bracket for next fight
	GameManager.change_phase(GameManager.GamePhase.TOURNAMENT)

func _check_set_bonuses() -> void:
	var chess_count := GameManager.get_perk_count_by_type("chess")
	var boxing_count := GameManager.get_perk_count_by_type("boxing")

	# Set bonus: 3 chess perks = hints
	if chess_count >= 3:
		pass  # Could add hint mechanic here in future

	# Set bonus: 3 boxing perks = +10 max HP
	if boxing_count >= 3:
		GameManager.player_max_hp += 10
		GameManager.player_hp = mini(GameManager.player_hp + 10, GameManager.player_max_hp)
