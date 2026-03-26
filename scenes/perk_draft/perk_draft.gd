extends Control

## Perk Draft — Pick 1 of 3 perks between fights
## Shows tag pips, set bonus preview, and synergy highlighting

@onready var card_container: HBoxContainer = %CardContainer
@onready var title_label: Label = %TitleLabel
@onready var perk_count_label: Label = %PerkCountLabel
@onready var continue_btn: Button = %ContinueBtn

var choices: Array = []
var selected_index: int = -1
var card_panels: Array = []

const TYPE_COLORS := {
	"chess": Color(0.3, 0.42, 0.68),
	"boxing": Color(0.68, 0.3, 0.28),
	"hybrid": Color(0.52, 0.32, 0.6),
	"wild": Color(0.75, 0.65, 0.25),
}

const TYPE_LABELS := {
	"chess": "CHESS",
	"boxing": "BOXING",
	"hybrid": "HYBRID",
	"wild": "WILD",
}

func _ready() -> void:
	continue_btn.pressed.connect(_on_continue)
	continue_btn.disabled = true

	choices = GameManager.get_draft_choices(3)
	_update_perk_count()
	_build_cards()

	Juice.fade_in(self, 0.4)

func _update_perk_count() -> void:
	var tag_counts := GameManager.get_tag_counts()
	var parts := []
	for tag in PerkSystem.TAGS:
		var count: int = tag_counts.get(tag, 0)
		if count > 0:
			parts.append("%s %d" % [PerkSystem.TAG_ICONS.get(tag, "?"), count])

	if parts.is_empty():
		perk_count_label.text = "No perks yet"
	else:
		perk_count_label.text = "Tags: " + "  ".join(parts)

	# Show active set bonuses
	var bonuses := GameManager.get_active_set_bonuses_list()
	if not bonuses.is_empty():
		var bonus_names := []
		for b in bonuses:
			bonus_names.append(b.get("name", "?"))
		perk_count_label.text += "\nActive: " + ", ".join(bonus_names)

func _build_cards() -> void:
	card_panels.clear()

	for i in choices.size():
		var perk: Dictionary = choices[i]
		var card := _create_perk_card(perk, i)
		card_container.add_child(card)
		card_panels.append(card)

		# Staggered card flip animation
		card.scale = Vector2(0.01, 1.0)
		card.pivot_offset = Vector2(130, 120)
		var tween := create_tween()
		tween.set_ease(Tween.EASE_OUT)
		tween.set_trans(Tween.TRANS_BACK)
		tween.tween_property(card, "scale:x", 1.0, 0.4).set_delay(0.2 + i * 0.2)

func _create_perk_card(perk: Dictionary, index: int) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(260, 240)

	var style := StyleBoxFlat.new()
	var type_color: Color = TYPE_COLORS.get(perk.get("type", ""), Color(0.3, 0.3, 0.3))
	style.bg_color = type_color.darkened(0.55)
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
	vbox.add_theme_constant_override("separation", 6)

	# Type badge
	var type_label := Label.new()
	type_label.text = TYPE_LABELS.get(perk.get("type", ""), "?")
	type_label.add_theme_font_size_override("font_size", 11)
	type_label.add_theme_color_override("font_color", type_color.lightened(0.3))
	type_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(type_label)

	# Perk name
	var name_label := Label.new()
	name_label.text = perk.get("name", "???")
	name_label.add_theme_font_size_override("font_size", 20)
	name_label.add_theme_color_override("font_color", Color(0.95, 0.92, 0.82))
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(name_label)

	# Tag pips row
	var tag_row := HBoxContainer.new()
	tag_row.alignment = BoxContainer.ALIGNMENT_CENTER
	tag_row.add_theme_constant_override("separation", 4)
	var tags: Array = perk.get("tags", [])
	for tag in tags:
		var pip := Label.new()
		pip.text = " %s " % tag.to_upper()
		pip.add_theme_font_size_override("font_size", 9)
		var tag_color: Color = PerkSystem.TAG_COLORS.get(tag, Color(0.5, 0.5, 0.5))
		pip.add_theme_color_override("font_color", tag_color)
		tag_row.add_child(pip)
	vbox.add_child(tag_row)

	# Separator
	var sep := HSeparator.new()
	vbox.add_child(sep)

	# Description
	var desc_label := Label.new()
	desc_label.text = perk.get("description", "")
	desc_label.add_theme_font_size_override("font_size", 14)
	desc_label.add_theme_color_override("font_color", Color(0.78, 0.78, 0.75))
	desc_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(desc_label)

	# Flavor text
	var flavor: String = perk.get("flavor", "")
	if flavor != "":
		var flavor_label := Label.new()
		flavor_label.text = flavor
		flavor_label.add_theme_font_size_override("font_size", 10)
		flavor_label.add_theme_color_override("font_color", Color(0.55, 0.55, 0.52))
		flavor_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		flavor_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		vbox.add_child(flavor_label)

	# Rarity + heat indicator
	var bottom_row := HBoxContainer.new()
	bottom_row.alignment = BoxContainer.ALIGNMENT_CENTER
	bottom_row.add_theme_constant_override("separation", 8)

	var rarity_label := Label.new()
	rarity_label.text = perk.get("rarity", "common").to_upper()
	rarity_label.add_theme_font_size_override("font_size", 10)
	match perk.get("rarity", "common"):
		"common": rarity_label.add_theme_color_override("font_color", Color(0.55, 0.55, 0.55))
		"uncommon": rarity_label.add_theme_color_override("font_color", Color(0.35, 0.68, 0.38))
		"rare": rarity_label.add_theme_color_override("font_color", Color(0.88, 0.75, 0.3))
	bottom_row.add_child(rarity_label)

	if perk.get("heat_scaled", false):
		var heat_label := Label.new()
		heat_label.text = "HEAT"
		heat_label.add_theme_font_size_override("font_size", 9)
		heat_label.add_theme_color_override("font_color", Color(0.9, 0.45, 0.2))
		bottom_row.add_child(heat_label)

	vbox.add_child(bottom_row)

	# Set bonus preview
	var would_trigger := PerkSystem.would_trigger_set_bonus(perk, GameManager.active_perks, GameManager.all_set_bonuses)
	if not would_trigger.is_empty():
		var bonus_label := Label.new()
		var bonus_name: String = would_trigger[0].get("name", "Set Bonus")
		var bonus_desc: String = would_trigger[0].get("description", "")
		bonus_label.text = ">> %s: %s" % [bonus_name, bonus_desc]
		bonus_label.add_theme_font_size_override("font_size", 10)
		bonus_label.add_theme_color_override("font_color", Color(0.9, 0.78, 0.3))
		bonus_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		bonus_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		vbox.add_child(bonus_label)

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
			panel.modulate = Color.WHITE
		else:
			var type_color: Color = TYPE_COLORS.get(choices[i].get("type", ""), Color(0.3, 0.3, 0.3))
			style.border_color = type_color.darkened(0.3)
			style.border_width_left = 2
			style.border_width_right = 2
			style.border_width_top = 2
			style.border_width_bottom = 2
			panel.modulate = Color(0.6, 0.6, 0.6)

func _on_continue() -> void:
	if selected_index < 0 or selected_index >= choices.size():
		return

	var chosen_perk: Dictionary = choices[selected_index]

	# Queen's Gambit: skip this draft, next one is 5 Rares
	if chosen_perk.get("effect", "") == "queens_gambit":
		GameManager.queens_gambit_active = true
		_go_to_shop_or_next()
		return

	GameManager.add_perk(chosen_perk)

	# Apply immediate perk effects
	_apply_immediate_effects(chosen_perk)
	_go_to_shop_or_next()

## Route to The Corner (shop) after drafting, then to path fork or tournament.
func _go_to_shop_or_next() -> void:
	# Always visit the shop between fights
	GameManager.change_phase(GameManager.GamePhase.SHOP)

func _apply_immediate_effects(perk: Dictionary) -> void:
	var effect: String = perk.get("effect", "")

	# Glass Cannon: halve max HP
	if effect == "glass_cannon":
		var mult: float = PerkSystem.get_named_value(perk, "hp_multiplier", 0.5)
		GameManager.player_max_hp = int(GameManager.player_max_hp * mult)
		GameManager.player_hp = mini(GameManager.player_hp, GameManager.player_max_hp)

	# Endurance: +max stamina
	if effect == "max_stamina_bonus":
		var bonus := int(PerkSystem.get_named_value(perk, "stamina", 20.0))
		GameManager.player_max_stamina += bonus
		GameManager.player_stamina = mini(GameManager.player_stamina + bonus, GameManager.player_max_stamina)
