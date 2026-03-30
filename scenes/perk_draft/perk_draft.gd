extends Control

## Perk Draft — Pick 1 of 3 perks between fights
## Cards with discipline badge, bold title, colored tags, description, rarity, hover juice

@onready var card_container: HBoxContainer = %CardContainer
@onready var title_label: Label = %TitleLabel
@onready var perk_count_label: Label = %PerkCountLabel
@onready var continue_btn: Button = %ContinueBtn

var choices: Array = []
var selected_index: int = -1
var card_panels: Array = []
var card_styles: Array = []
var card_rest_positions: Array = []

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

const TAG_COLORS := {
	"speed": Color(0.35, 0.55, 0.85),
	"power": Color(0.85, 0.32, 0.28),
	"defense": Color(0.45, 0.65, 0.45),
	"strategy": Color(0.70, 0.55, 0.82),
	"timing": Color(0.82, 0.72, 0.32),
	"stamina": Color(0.55, 0.78, 0.42),
	"risk": Color(0.88, 0.45, 0.22),
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

	var bonuses := GameManager.get_active_set_bonuses_list()
	if not bonuses.is_empty():
		var bonus_names := []
		for b in bonuses:
			bonus_names.append(b.get("name", "?"))
		perk_count_label.text += "\nActive: " + ", ".join(bonus_names)

func _build_cards() -> void:
	card_panels.clear()
	card_styles.clear()
	card_rest_positions.clear()

	for i in choices.size():
		var perk: Dictionary = choices[i]
		var card := _create_perk_card(perk, i)
		card_container.add_child(card)
		card_panels.append(card)

		# Staggered card flip animation
		card.scale = Vector2(0.01, 1.0)
		card.pivot_offset = Vector2(130, 140)
		var tween := create_tween()
		tween.set_ease(Tween.EASE_OUT)
		tween.set_trans(Tween.TRANS_BACK)
		tween.tween_property(card, "scale:x", 1.0, 0.4).set_delay(0.2 + i * 0.2)


func _create_perk_card(perk: Dictionary, index: int) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(260, 280)

	var type_color: Color = TYPE_COLORS.get(perk.get("type", ""), Color(0.3, 0.3, 0.3))

	var style := StyleBoxFlat.new()
	style.bg_color = type_color.darkened(0.65)
	style.corner_radius_top_left = 12
	style.corner_radius_top_right = 12
	style.corner_radius_bottom_left = 12
	style.corner_radius_bottom_right = 12
	style.border_width_left = 3
	style.border_width_right = 3
	style.border_width_top = 3
	style.border_width_bottom = 3
	style.border_color = type_color.darkened(0.1)
	style.content_margin_left = 14.0
	style.content_margin_right = 14.0
	style.content_margin_top = 12.0
	style.content_margin_bottom = 12.0
	panel.add_theme_stylebox_override("panel", style)
	card_styles.append(style)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER

	# ── Discipline pill badge ────────────────────────────────────────────────
	var badge_wrap := PanelContainer.new()
	badge_wrap.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var badge_style := StyleBoxFlat.new()
	badge_style.bg_color = type_color.darkened(0.3)
	badge_style.corner_radius_top_left = 8
	badge_style.corner_radius_top_right = 8
	badge_style.corner_radius_bottom_left = 8
	badge_style.corner_radius_bottom_right = 8
	badge_style.content_margin_left = 10.0
	badge_style.content_margin_right = 10.0
	badge_style.content_margin_top = 3.0
	badge_style.content_margin_bottom = 3.0
	badge_wrap.add_theme_stylebox_override("panel", badge_style)

	var badge_lbl := Label.new()
	badge_lbl.text = TYPE_LABELS.get(perk.get("type", ""), "?")
	badge_lbl.add_theme_font_size_override("font_size", 10)
	badge_lbl.add_theme_color_override("font_color", type_color.lightened(0.4))
	badge_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	badge_wrap.add_child(badge_lbl)
	vbox.add_child(badge_wrap)

	# ── Perk title ───────────────────────────────────────────────────────────
	var name_label := Label.new()
	name_label.text = perk.get("name", "???")
	name_label.add_theme_font_size_override("font_size", 22)
	name_label.add_theme_color_override("font_color", Color(0.97, 0.94, 0.85))
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(name_label)

	# ── Color-coded tag pills ────────────────────────────────────────────────
	var tag_row := HBoxContainer.new()
	tag_row.alignment = BoxContainer.ALIGNMENT_CENTER
	tag_row.add_theme_constant_override("separation", 6)
	var tags: Array = perk.get("tags", [])
	for tag in tags:
		var tag_pill := PanelContainer.new()
		var tag_style := StyleBoxFlat.new()
		var t_color: Color = TAG_COLORS.get(tag, PerkSystem.TAG_COLORS.get(tag, Color(0.5, 0.5, 0.5)))
		tag_style.bg_color = t_color.darkened(0.5)
		tag_style.corner_radius_top_left = 6
		tag_style.corner_radius_top_right = 6
		tag_style.corner_radius_bottom_left = 6
		tag_style.corner_radius_bottom_right = 6
		tag_style.content_margin_left = 6.0
		tag_style.content_margin_right = 6.0
		tag_style.content_margin_top = 1.0
		tag_style.content_margin_bottom = 1.0
		tag_pill.add_theme_stylebox_override("panel", tag_style)

		var tag_lbl := Label.new()
		tag_lbl.text = tag.to_upper()
		tag_lbl.add_theme_font_size_override("font_size", 9)
		tag_lbl.add_theme_color_override("font_color", t_color.lightened(0.3))
		tag_pill.add_child(tag_lbl)
		tag_row.add_child(tag_pill)
	vbox.add_child(tag_row)

	# ── Separator ────────────────────────────────────────────────────────────
	var sep := HSeparator.new()
	vbox.add_child(sep)

	# ── Description body ─────────────────────────────────────────────────────
	var desc_label := Label.new()
	desc_label.text = perk.get("description", "")
	desc_label.add_theme_font_size_override("font_size", 13)
	desc_label.add_theme_color_override("font_color", Color(0.78, 0.78, 0.75))
	desc_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(desc_label)

	# ── Flavor text (italic feel) ────────────────────────────────────────────
	var flavor: String = perk.get("flavor", "")
	if flavor != "":
		var flavor_label := Label.new()
		flavor_label.text = "— %s —" % flavor
		flavor_label.add_theme_font_size_override("font_size", 10)
		flavor_label.add_theme_color_override("font_color", Color(0.48, 0.48, 0.45))
		flavor_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		flavor_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		vbox.add_child(flavor_label)

	# ── Bottom row: rarity + heat indicator ──────────────────────────────────
	var bottom_row := HBoxContainer.new()
	bottom_row.alignment = BoxContainer.ALIGNMENT_CENTER
	bottom_row.add_theme_constant_override("separation", 10)

	var rarity_pill := PanelContainer.new()
	var rarity_style := StyleBoxFlat.new()
	rarity_style.corner_radius_top_left = 4
	rarity_style.corner_radius_top_right = 4
	rarity_style.corner_radius_bottom_left = 4
	rarity_style.corner_radius_bottom_right = 4
	rarity_style.content_margin_left = 8.0
	rarity_style.content_margin_right = 8.0
	rarity_style.content_margin_top = 2.0
	rarity_style.content_margin_bottom = 2.0

	var rarity_text: String = (perk.get("rarity", "common") as String).to_upper()
	var rarity_label := Label.new()
	rarity_label.text = rarity_text
	rarity_label.add_theme_font_size_override("font_size", 10)

	match perk.get("rarity", "common"):
		"common":
			rarity_style.bg_color = Color(0.2, 0.2, 0.2, 0.6)
			rarity_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
		"uncommon":
			rarity_style.bg_color = Color(0.12, 0.28, 0.14, 0.6)
			rarity_label.add_theme_color_override("font_color", Color(0.38, 0.72, 0.42))
		"rare":
			rarity_style.bg_color = Color(0.3, 0.24, 0.08, 0.6)
			rarity_label.add_theme_color_override("font_color", Color(0.92, 0.78, 0.32))

	rarity_pill.add_theme_stylebox_override("panel", rarity_style)
	rarity_pill.add_child(rarity_label)
	bottom_row.add_child(rarity_pill)

	if perk.get("heat_scaled", false):
		var heat_label := Label.new()
		heat_label.text = "🔥 HEAT"
		heat_label.add_theme_font_size_override("font_size", 10)
		heat_label.add_theme_color_override("font_color", Color(0.92, 0.45, 0.20))
		bottom_row.add_child(heat_label)

	vbox.add_child(bottom_row)

	# ── Set bonus preview ────────────────────────────────────────────────────
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

	# ── Invisible click + hover overlay ──────────────────────────────────────
	var btn := Button.new()
	btn.flat = true
	btn.anchors_preset = Control.PRESET_FULL_RECT
	btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	btn.pressed.connect(_on_card_selected.bind(index))
	btn.mouse_entered.connect(_on_card_hover_enter.bind(index, panel, style))
	btn.mouse_exited.connect(_on_card_hover_exit.bind(index, panel, style))
	panel.add_child(btn)

	return panel


# ── Hover juice ──────────────────────────────────────────────────────────────

func _on_card_hover_enter(index: int, panel: PanelContainer, style: StyleBoxFlat) -> void:
	if index == selected_index:
		return
	AudioManager.play_button_hover()
	# Lift up and brighten border
	var tween := create_tween()
	tween.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	tween.tween_property(panel, "position:y", panel.position.y - 10, 0.15)
	style.shadow_size = 12
	style.shadow_color = Color(0, 0, 0, 0.5)
	var type_color: Color = TYPE_COLORS.get(choices[index].get("type", ""), Color(0.3, 0.3, 0.3))
	style.border_color = type_color.lightened(0.2)


func _on_card_hover_exit(index: int, panel: PanelContainer, style: StyleBoxFlat) -> void:
	if index == selected_index:
		return
	# Drop back down and reset border
	var tween := create_tween()
	tween.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	tween.tween_property(panel, "position:y", panel.position.y + 10, 0.15)
	style.shadow_size = 0
	var type_color: Color = TYPE_COLORS.get(choices[index].get("type", ""), Color(0.3, 0.3, 0.3))
	style.border_color = type_color.darkened(0.1)


func _on_card_selected(index: int) -> void:
	AudioManager.play_button_click()
	selected_index = index
	continue_btn.disabled = false
	Juice.scale_bounce(card_panels[index], 1.06, 0.25)

	for i in card_panels.size():
		var panel: PanelContainer = card_panels[i]
		var style: StyleBoxFlat = card_styles[i]
		if i == index:
			style.border_color = Color(0.92, 0.80, 0.32)
			style.border_width_left = 4
			style.border_width_right = 4
			style.border_width_top = 4
			style.border_width_bottom = 4
			style.shadow_size = 16
			style.shadow_color = Color(0.9, 0.78, 0.3, 0.35)
			Juice.scale_bounce(panel, 1.05, 0.2)
			panel.modulate = Color.WHITE
		else:
			var type_color: Color = TYPE_COLORS.get(choices[i].get("type", ""), Color(0.3, 0.3, 0.3))
			style.border_color = type_color.darkened(0.3)
			style.border_width_left = 2
			style.border_width_right = 2
			style.border_width_top = 2
			style.border_width_bottom = 2
			style.shadow_size = 0
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

	AudioManager.play_perk_draft()
	Juice.screen_flash(self, Color(0.9, 0.8, 0.2, 0.2), 0.2)
	GameManager.add_perk(chosen_perk)

	_apply_immediate_effects(chosen_perk)
	_go_to_shop_or_next()


## Route to The Corner (shop) after drafting, then to path fork or tournament.
func _go_to_shop_or_next() -> void:
	GameManager.change_phase(GameManager.GamePhase.SHOP)


func _apply_immediate_effects(perk: Dictionary) -> void:
	var effect: String = perk.get("effect", "")

	# Glass Cannon: halve max HP
	if effect == "glass_cannon":
		var mult: float = PerkSystem.get_named_value(perk, "hp_multiplier", 0.5)
		GameManager.player_max_hp = int(GameManager.player_max_hp * mult)
		GameManager.player_hp = mini(GameManager.player_hp, GameManager.player_max_hp)

	# Endurance: stamina removed, perk is a no-op
	if effect == "max_stamina_bonus":
		pass
