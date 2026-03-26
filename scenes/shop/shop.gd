extends Control

## The Corner — dual-shop screen between fights.
## Left side: The Study (chess shop). Right side: The Gym (boxing shop).
## Player spends shared Rep currency on tactic cards, stat upgrades,
## intel, and services.

@onready var study_container: VBoxContainer = %StudyContainer
@onready var gym_container: VBoxContainer = %GymContainer
@onready var rep_label: Label = %RepLabel
@onready var hand_label: Label = %HandLabel
@onready var continue_btn: Button = %ContinueBtn
@onready var title_label: Label = %TitleLabel
@onready var rep_breakdown_label: Label = %RepBreakdownLabel
@onready var perk_removal_panel: PanelContainer = %PerkRemovalPanel

var study_items: Array = []
var gym_items: Array = []

const STUDY_COLOR := Color(0.3, 0.42, 0.68)   # Blue — chess
const GYM_COLOR := Color(0.68, 0.3, 0.28)      # Red — boxing
const GOLD := Color(0.9, 0.75, 0.3)
const DISABLED_COLOR := Color(0.4, 0.4, 0.4)

func _ready() -> void:
	continue_btn.pressed.connect(_on_continue)

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
	rep_label.text = "Rep: %d" % GameManager.player_rep
	var hand_count := GameManager.tactic_hand.size()
	hand_label.text = "Tactic Hand: %d/%d" % [hand_count, TacticCardSystem.MAX_HAND_SIZE]

# =============================================================================
# Shop Columns
# =============================================================================

func _build_shop_column(container: VBoxContainer, items: Array, shop_type: String) -> void:
	# Clear existing children (keep the header label if present)
	for child in container.get_children():
		if child is Label and child.name.ends_with("Header"):
			continue
		child.queue_free()

	if items.is_empty():
		var empty := Label.new()
		empty.text = "Nothing available"
		empty.add_theme_font_size_override("font_size", 14)
		empty.add_theme_color_override("font_color", DISABLED_COLOR)
		empty.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		container.add_child(empty)
		return

	for i in items.size():
		var item: Dictionary = items[i]
		var card := _create_item_card(item, shop_type, i)
		container.add_child(card)

		# Staggered pop-in
		card.modulate.a = 0.0
		var tween := create_tween()
		tween.tween_property(card, "modulate:a", 1.0, 0.25).set_delay(0.1 + i * 0.1)

func _create_item_card(item: Dictionary, shop_type: String, index: int) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(240, 0)

	var base_color: Color = STUDY_COLOR if shop_type == "study" else GYM_COLOR
	var style := StyleBoxFlat.new()
	style.bg_color = base_color.darkened(0.6)
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8
	style.border_width_left = 2
	style.border_width_right = 2
	style.border_width_top = 2
	style.border_width_bottom = 2
	style.border_color = base_color.darkened(0.2)
	panel.add_theme_stylebox_override("panel", style)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 4)

	# Category badge
	var cat_label := Label.new()
	var category: String = item.get("category", "")
	cat_label.text = _category_display(category)
	cat_label.add_theme_font_size_override("font_size", 10)
	cat_label.add_theme_color_override("font_color", base_color.lightened(0.3))
	cat_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(cat_label)

	# Item name + cost
	var name_row := HBoxContainer.new()
	name_row.alignment = BoxContainer.ALIGNMENT_CENTER
	name_row.add_theme_constant_override("separation", 8)

	var name_label := Label.new()
	name_label.text = item.get("name", "???")
	name_label.add_theme_font_size_override("font_size", 17)
	name_label.add_theme_color_override("font_color", Color(0.95, 0.92, 0.82))
	name_row.add_child(name_label)

	var cost_label := Label.new()
	cost_label.text = "%d Rep" % item.get("cost", 0)
	cost_label.add_theme_font_size_override("font_size", 13)
	cost_label.add_theme_color_override("font_color", GOLD)
	name_row.add_child(cost_label)
	vbox.add_child(name_row)

	# Description
	var desc_label := Label.new()
	desc_label.text = item.get("description", "")
	desc_label.add_theme_font_size_override("font_size", 12)
	desc_label.add_theme_color_override("font_color", Color(0.75, 0.75, 0.72))
	desc_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(desc_label)

	# Flavor text
	var flavor: String = item.get("flavor", "")
	if flavor != "":
		var flavor_label := Label.new()
		flavor_label.text = flavor
		flavor_label.add_theme_font_size_override("font_size", 10)
		flavor_label.add_theme_color_override("font_color", Color(0.5, 0.5, 0.48))
		flavor_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		flavor_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		vbox.add_child(flavor_label)

	# Cap warning for stat upgrades
	if category == "stat_upgrade":
		var cap_text: String = item.get("cap_description", "")
		var times_bought: int = GameManager.shop_purchase_counts.get(item.get("id", ""), 0)
		var max_p: int = item.get("max_purchases", 99)
		if cap_text != "":
			var cap_label := Label.new()
			cap_label.text = "(%d/%d) %s" % [times_bought, max_p, cap_text]
			cap_label.add_theme_font_size_override("font_size", 9)
			cap_label.add_theme_color_override("font_color", Color(0.6, 0.55, 0.4))
			cap_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			vbox.add_child(cap_label)

	panel.add_child(vbox)

	# Buy button
	var buy_btn := Button.new()
	buy_btn.flat = true
	buy_btn.anchors_preset = Control.PRESET_FULL_RECT
	buy_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND

	# Check affordability
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

# =============================================================================
# Purchase
# =============================================================================

func _on_buy_item(item: Dictionary, shop_type: String) -> void:
	var result := GameManager.purchase_shop_item(item)
	if not result.success:
		return

	# Refresh UI
	_update_header()

	# Rebuild both columns (stock may have changed due to hand limit, etc.)
	var inventory := GameManager.get_shop_inventory()
	study_items = inventory.study
	gym_items = inventory.gym
	_build_shop_column(study_container, study_items, "study")
	_build_shop_column(gym_container, gym_items, "gym")
	_update_perk_removal_panel()

	# Flash the bought item's shop title
	Juice.scale_bounce(continue_btn, 1.05, 0.15)

# =============================================================================
# Perk Removal
# =============================================================================

func _update_perk_removal_panel() -> void:
	if not GameManager.pending_perk_removal:
		perk_removal_panel.visible = false
		return

	perk_removal_panel.visible = true
	# Clear old children
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
		vbox.add_child(btn)

	var skip_btn := Button.new()
	skip_btn.text = "Skip removal"
	skip_btn.add_theme_font_size_override("font_size", 11)
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
	# Consume intel items (they only last until next fight)
	# puzzle_scout and scouting_report are consumed in opponent_reveal.gd

	# Route to path fork or tournament
	if GameManager.current_opponent_index == 2 and GameManager.chosen_path == "":
		GameManager.change_phase(GameManager.GamePhase.PATH_FORK)
	else:
		GameManager.change_phase(GameManager.GamePhase.TOURNAMENT)
