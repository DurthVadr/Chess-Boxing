extends Control

## The Corner — dual-shop screen between fights.
## Left side: The Study (chess shop). Right side: The Gym (boxing shop).
## Player spends shared Rep currency on tactic cards, stat upgrades,
## intel, and services.

@onready var study_container: VBoxContainer = %StudyContainer
@onready var gym_container: VBoxContainer = %GymContainer
@onready var rep_big_label: Label = %RepBigLabel
@onready var hand_stat_label: Label = %HandStatLabel
@onready var hp_stat_label: Label = %HpStatLabel
@onready var stamina_stat_label: Label = %StaminaStatLabel
@onready var perks_container: VBoxContainer = %PerksContainer
@onready var continue_btn: Button = %ContinueBtn
@onready var rep_breakdown_label: Label = %RepBreakdownLabel
@onready var perk_removal_panel: PanelContainer = %PerkRemovalPanel

var study_items: Array = []
var gym_items: Array = []
var _is_rebuilding_shop: bool = false

const STUDY_COLOR := Color(0.3, 0.42, 0.68)   # Blue — chess
const GYM_COLOR := Color(0.68, 0.3, 0.28)      # Red — boxing
const GOLD := Color(0.9, 0.75, 0.3)
const DISABLED_COLOR := Color(0.4, 0.4, 0.4)

func _ready() -> void:
	continue_btn.pressed.connect(_on_continue)
	_wire_button_hover(continue_btn)

	var inventory := GameManager.get_shop_inventory()
	study_items = inventory.study
	gym_items = inventory.gym

	_show_rep_breakdown()
	_update_header()
	_build_shop_column(study_container, study_items, "study")
	_build_shop_column(gym_container, gym_items, "gym")
	_update_perk_removal_panel()

	Juice.fade_in(self, 0.4)

# =============================================================================
# Header / Status
# =============================================================================

func _show_rep_breakdown() -> void:
	var breakdown: Dictionary = GameManager.stats.get("last_rep_breakdown", {})
	if breakdown.is_empty():
		rep_breakdown_label.text = ""
		return

	var parts := ["+%d base" % breakdown.get("base", 3)]
	if breakdown.get("perfect_puzzle", 0) > 0:
		parts.append("+%d perfect puzzle" % breakdown.perfect_puzzle)
	if breakdown.get("fast_solve", 0) > 0:
		parts.append("+%d fast solve" % breakdown.fast_solve)
	if breakdown.get("high_heat", 0) > 0:
		parts.append("+%d high heat" % breakdown.high_heat)
	if breakdown.get("knockout", 0) > 0:
		parts.append("+%d knockout" % breakdown.knockout)
	if breakdown.get("low_damage", 0) > 0:
		parts.append("+%d untouchable" % breakdown.low_damage)

	rep_breakdown_label.text = "Earned: %s = %d Rep" % [", ".join(parts), breakdown.get("total", 0)]

func _update_header() -> void:
	rep_big_label.text = "%d" % GameManager.player_rep
	var hand_count := GameManager.tactic_hand.size()
	hand_stat_label.text = "%d / %d" % [hand_count, TacticCardSystem.MAX_HAND_SIZE]
	hp_stat_label.text = "%d" % GameManager.player_max_hp
	stamina_stat_label.text = "%d" % GameManager.player_max_stamina
	_build_perks_list()

func _build_perks_list() -> void:
	for child in perks_container.get_children():
		child.queue_free()

	if GameManager.active_perks.is_empty():
		var empty := Label.new()
		empty.text = "None"
		empty.add_theme_font_size_override("font_size", 11)
		empty.add_theme_color_override("font_color", DISABLED_COLOR)
		empty.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		perks_container.add_child(empty)
		return

	for perk in GameManager.active_perks:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 4)

		var dot := Label.new()
		dot.text = "•"
		dot.add_theme_font_size_override("font_size", 11)
		var rarity: String = perk.get("rarity", "common")
		var rarity_color := Color(0.75, 0.72, 0.65)
		match rarity:
			"rare":   rarity_color = Color(0.42, 0.68, 0.92)
			"epic":   rarity_color = Color(0.78, 0.45, 0.92)
			"unique": rarity_color = GOLD
		dot.add_theme_color_override("font_color", rarity_color)
		row.add_child(dot)

		var name_label := Label.new()
		name_label.text = perk.get("name", "?")
		name_label.add_theme_font_size_override("font_size", 14)
		name_label.add_theme_color_override("font_color", rarity_color)
		name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		name_label.clip_text = true
		row.add_child(name_label)

		var perk_panel := PanelContainer.new()
		var perk_style := StyleBoxFlat.new()
		perk_style.bg_color = Color(0.0, 0.0, 0.0, 0.30)
		perk_style.corner_radius_top_left = 4
		perk_style.corner_radius_top_right = 4
		perk_style.corner_radius_bottom_left = 4
		perk_style.corner_radius_bottom_right = 4
		perk_style.content_margin_left = 6.0
		perk_style.content_margin_right = 6.0
		perk_style.content_margin_top = 4.0
		perk_style.content_margin_bottom = 4.0
		perk_panel.add_theme_stylebox_override("panel", perk_style)
		perk_panel.add_child(row)
		perks_container.add_child(perk_panel)

# =============================================================================
# Shop Columns
# =============================================================================

func _build_shop_column(container: VBoxContainer, items: Array, shop_type: String) -> void:
	for child in container.get_children():
		child.queue_free()

	if items.is_empty():
		var empty := Label.new()
		empty.text = "Nothing available"
		empty.add_theme_font_size_override("font_size", 13)
		empty.add_theme_color_override("font_color", DISABLED_COLOR)
		empty.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		container.add_child(empty)
		return

	for i in items.size():
		var item: Dictionary = items[i]
		var card := _create_item_card(item, shop_type, i)
		container.add_child(card)

		card.modulate.a = 0.0
		var tween := create_tween()
		tween.tween_property(card, "modulate:a", 1.0, 0.22).set_delay(0.06 + i * 0.08)

func _create_item_card(item: Dictionary, shop_type: String, _index: int) -> PanelContainer:
	var panel := PanelContainer.new()

	var base_color: Color = STUDY_COLOR if shop_type == "study" else GYM_COLOR
	var style := StyleBoxFlat.new()
	style.bg_color = base_color.darkened(0.62)
	style.corner_radius_top_left = 6
	style.corner_radius_top_right = 6
	style.corner_radius_bottom_left = 6
	style.corner_radius_bottom_right = 6
	style.border_width_left = 1
	style.border_width_right = 1
	style.border_width_top = 1
	style.border_width_bottom = 1
	style.border_color = base_color.darkened(0.25)
	style.content_margin_left = 16.0
	style.content_margin_right = 16.0
	style.content_margin_top = 12.0
	style.content_margin_bottom = 12.0
	panel.add_theme_stylebox_override("panel", style)

	# Main row: [icon 32×32] | [info vbox EXPAND] | [cost vbox SHRINK]
	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 10)

	# Icon — always shown; specific sprite or colored fallback
	var category: String = item.get("category", "")
	var art := TextureRect.new()
	art.custom_minimum_size = Vector2(32, 32)
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	art.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var art_path := ""
	if category == "tactic_card":
		art_path = "res://assets/sprites/cards/tactic_%s.png" % item.get("effect", "")
	else:
		art_path = "res://assets/sprites/shop/%s.png" % item.get("id", "")
	if art_path != "" and ResourceLoader.exists(art_path):
		art.texture = load(art_path)
	else:
		# Colored square fallback — keeps layout uniform
		var img := Image.create(32, 32, false, Image.FORMAT_RGBA8)
		img.fill(base_color.darkened(0.2))
		art.texture = ImageTexture.create_from_image(img)
	hbox.add_child(art)

	# Info vbox (left-aligned, expands)
	var info_vbox := VBoxContainer.new()
	info_vbox.add_theme_constant_override("separation", 2)
	info_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var cat_label := Label.new()
	cat_label.text = _category_display(category)
	cat_label.add_theme_font_size_override("font_size", 10)
	cat_label.add_theme_color_override("font_color", base_color.lightened(0.25))
	info_vbox.add_child(cat_label)

	var name_label := Label.new()
	name_label.text = item.get("name", "???")
	name_label.add_theme_font_size_override("font_size", 18)
	name_label.add_theme_color_override("font_color", Color(0.95, 0.92, 0.82))
	name_label.clip_text = true
	info_vbox.add_child(name_label)

	var desc_label := Label.new()
	desc_label.text = item.get("description", "")
	desc_label.add_theme_font_size_override("font_size", 12)
	desc_label.add_theme_color_override("font_color", Color(0.62, 0.62, 0.60))
	desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info_vbox.add_child(desc_label)

	# Cap info for stat upgrades
	if category == "stat_upgrade":
		var cap_text: String = item.get("cap_description", "")
		var times_bought: int = GameManager.shop_purchase_counts.get(item.get("id", ""), 0)
		var max_p: int = item.get("max_purchases", 99)
		if cap_text != "":
			var cap_label := Label.new()
			cap_label.text = "(%d/%d) %s" % [times_bought, max_p, cap_text]
			cap_label.add_theme_font_size_override("font_size", 8)
			cap_label.add_theme_color_override("font_color", Color(0.55, 0.50, 0.38))
			info_vbox.add_child(cap_label)

	hbox.add_child(info_vbox)

	# Cost vbox (right-aligned, shrinks)
	var cost_vbox := VBoxContainer.new()
	cost_vbox.add_theme_constant_override("separation", 0)
	cost_vbox.size_flags_horizontal = Control.SIZE_SHRINK_END
	cost_vbox.size_flags_vertical = Control.SIZE_SHRINK_CENTER

	var cost_label := Label.new()
	cost_label.text = "%d" % item.get("cost", 0)
	cost_label.add_theme_font_size_override("font_size", 18)
	cost_label.add_theme_color_override("font_color", GOLD)
	cost_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	cost_vbox.add_child(cost_label)

	var rep_caption := Label.new()
	rep_caption.text = "REP"
	rep_caption.add_theme_font_size_override("font_size", 7)
	rep_caption.add_theme_color_override("font_color", Color(0.55, 0.50, 0.28, 0.80))
	rep_caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	cost_vbox.add_child(rep_caption)

	hbox.add_child(cost_vbox)
	panel.add_child(hbox)

	# Invisible buy button over the whole card
	var buy_btn := Button.new()
	buy_btn.flat = true
	buy_btn.anchors_preset = Control.PRESET_FULL_RECT
	buy_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND

	var base_bg_color: Color = style.bg_color
	var base_border_color: Color = style.border_color
	buy_btn.mouse_entered.connect(func():
		if buy_btn.disabled or not is_instance_valid(panel):
			return
		var s := panel.get_theme_stylebox("panel")
		if s is StyleBoxFlat:
			(s as StyleBoxFlat).bg_color = base_bg_color.lightened(0.14)
			(s as StyleBoxFlat).border_color = GOLD
		Juice.scale_bounce(panel, 1.02, 0.10)
	)
	buy_btn.mouse_exited.connect(func():
		if not is_instance_valid(panel):
			return
		var s := panel.get_theme_stylebox("panel")
		if s is StyleBoxFlat:
			(s as StyleBoxFlat).bg_color = base_bg_color
			(s as StyleBoxFlat).border_color = base_border_color
	)

	var check := ShopSystem.can_purchase(item, GameManager.player_rep, GameManager.tactic_hand, GameManager.shop_purchase_counts)
	if check.allowed:
		buy_btn.pressed.connect(_on_buy_item.bind(item, shop_type))
		buy_btn.tooltip_text = "Buy for %d Rep" % item.get("cost", 0)
	else:
		buy_btn.disabled = true
		buy_btn.tooltip_text = check.reason
		panel.modulate = Color(0.5, 0.5, 0.5)

	panel.add_child(buy_btn)
	return panel

func _category_display(category: String) -> String:
	match category:
		"tactic_card": return "TACTIC CARD"
		"stat_upgrade": return "TRAINING"
		"intel": return "INTEL"
		"service": return "SERVICE"
	return category.to_upper()

func _wire_button_hover(btn: Button) -> void:
	btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	btn.mouse_entered.connect(func():
		if btn.disabled:
			return
		Juice.scale_bounce(btn, 1.05, 0.14)
		btn.add_theme_color_override("font_color", GOLD)
	)
	btn.mouse_exited.connect(func():
		btn.remove_theme_color_override("font_color")
	)

# =============================================================================
# Purchase
# =============================================================================

func _on_buy_item(item: Dictionary, _unused_shop_type: String) -> void:
	if _is_rebuilding_shop:
		return

	var result := GameManager.purchase_shop_item(item)
	if not result.success:
		return

	_is_rebuilding_shop = true

	_update_header()

	call_deferred("_rebuild_shop_after_purchase")

	Juice.scale_bounce(continue_btn, 1.05, 0.15)

func _rebuild_shop_after_purchase() -> void:
	var inventory := GameManager.get_shop_inventory()
	study_items = inventory.study
	gym_items = inventory.gym
	_build_shop_column(study_container, study_items, "study")
	_build_shop_column(gym_container, gym_items, "gym")
	_update_perk_removal_panel()
	_is_rebuilding_shop = false

# =============================================================================
# Perk Removal
# =============================================================================

func _update_perk_removal_panel() -> void:
	if not GameManager.pending_perk_removal:
		perk_removal_panel.visible = false
		return

	perk_removal_panel.visible = true
	for child in perk_removal_panel.get_children():
		child.queue_free()

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 4)

	var header := Label.new()
	header.text = "Choose a perk to REMOVE:"
	header.add_theme_font_size_override("font_size", 14)
	header.add_theme_color_override("font_color", Color(0.9, 0.4, 0.3))
	header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(header)

	for i in GameManager.active_perks.size():
		var perk: Dictionary = GameManager.active_perks[i]
		var btn := Button.new()
		btn.text = "%s — %s" % [perk.get("name", "?"), perk.get("description", "")]
		btn.add_theme_font_size_override("font_size", 12)
		btn.pressed.connect(_on_remove_perk.bind(i))
		_wire_button_hover(btn)
		vbox.add_child(btn)

	var skip_btn := Button.new()
	skip_btn.text = "Skip removal"
	skip_btn.add_theme_font_size_override("font_size", 11)
	_wire_button_hover(skip_btn)
	skip_btn.pressed.connect(func():
		GameManager.pending_perk_removal = false
		_update_perk_removal_panel()
	)
	vbox.add_child(skip_btn)

	perk_removal_panel.add_child(vbox)

func _on_remove_perk(index: int) -> void:
	GameManager.remove_perk(index)
	_update_perk_removal_panel()

# =============================================================================
# Continue
# =============================================================================

func _on_continue() -> void:
	if not GameManager.fight_order_complete and GameManager.current_opponent_index >= 2:
		GameManager.select_random_boss()
	GameManager.change_phase(GameManager.GamePhase.TOURNAMENT)
