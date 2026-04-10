extends Control

## The Corner — perk shop between fights.
## Player spends Rep currency to buy perk cards for their build.

@onready var perk_shop_container: VBoxContainer = %PerkShopContainer
@onready var rep_big_label: Label = %RepBigLabel
@onready var perks_container: VBoxContainer = %PerksContainer
@onready var continue_btn: Button = %ContinueBtn
@onready var rep_breakdown_label: Label = %RepBreakdownLabel
@onready var perk_removal_panel: PanelContainer = %PerkRemovalPanel

var shop_perks: Array = []  # Perk dicts offered this visit
var _is_rebuilding_shop: bool = false

const GOLD := Color(0.9, 0.75, 0.3)
const DISABLED_COLOR := Color(0.4, 0.4, 0.4)

const RARITY_COLORS := {
	"common": Color(0.75, 0.72, 0.65),
	"rare": Color(0.42, 0.68, 0.92),
	"epic": Color(0.78, 0.45, 0.92),
	"unique": Color(0.9, 0.75, 0.3),
}

# Cost per rarity
const RARITY_COST := {
	"common": 2,
	"rare": 4,
	"epic": 6,
	"unique": 8,
}

func _ready() -> void:
	continue_btn.pressed.connect(_on_continue)
	_wire_button_hover(continue_btn)

	shop_perks = _generate_perk_offers()

	_show_rep_breakdown()
	_update_header()
	_build_perk_shop()
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
		var rarity_color: Color = RARITY_COLORS.get(rarity, RARITY_COLORS.common)
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
# Perk Shop
# =============================================================================

func _generate_perk_offers() -> Array:
	# Pull from the global perk pool, excluding perks the player already has
	var owned_ids := {}
	for p in GameManager.active_perks:
		owned_ids[p.get("id", "")] = true

	var pool: Array = []
	for perk in GameManager.all_perks:
		if owned_ids.has(perk.get("id", "")):
			continue
		# Respect unlock requirements
		var req: String = perk.get("requires_unlock", "")
		if req != "" and req not in SaveManager.unlocked_perks:
			continue
		pool.append(perk)

	pool.shuffle()

	# Offer 4 perks (mix of rarities weighted by fight progress)
	var count := mini(4, pool.size())
	return pool.slice(0, count)

func _build_perk_shop() -> void:
	for child in perk_shop_container.get_children():
		child.queue_free()

	if shop_perks.is_empty():
		var empty := Label.new()
		empty.text = "No perks available"
		empty.add_theme_font_size_override("font_size", 13)
		empty.add_theme_color_override("font_color", DISABLED_COLOR)
		empty.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		perk_shop_container.add_child(empty)
		return

	for i in shop_perks.size():
		var perk: Dictionary = shop_perks[i]
		var card := _create_perk_card(perk, i)
		perk_shop_container.add_child(card)

		# Staggered fade-in
		card.modulate.a = 0.0
		var tween := create_tween()
		tween.tween_property(card, "modulate:a", 1.0, 0.22).set_delay(0.06 + i * 0.08)

func _create_perk_card(perk: Dictionary, _index: int) -> PanelContainer:
	var panel := PanelContainer.new()
	var rarity: String = perk.get("rarity", "common")
	var rarity_color: Color = RARITY_COLORS.get(rarity, RARITY_COLORS.common)
	var cost: int = RARITY_COST.get(rarity, 3)

	var style := StyleBoxFlat.new()
	style.bg_color = rarity_color.darkened(0.78)
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8
	style.border_width_left = 2
	style.border_width_right = 2
	style.border_width_top = 2
	style.border_width_bottom = 2
	style.border_color = rarity_color.darkened(0.3)
	style.content_margin_left = 16.0
	style.content_margin_right = 16.0
	style.content_margin_top = 14.0
	style.content_margin_bottom = 14.0
	panel.add_theme_stylebox_override("panel", style)

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 12)

	# Tags column — small colored pills
	var tags_vbox := VBoxContainer.new()
	tags_vbox.add_theme_constant_override("separation", 2)
	tags_vbox.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var tags: Array = perk.get("tags", [])
	for tag in tags:
		var tag_label := Label.new()
		tag_label.text = str(tag).to_upper()
		tag_label.add_theme_font_size_override("font_size", 8)
		tag_label.add_theme_color_override("font_color", rarity_color.lightened(0.3))
		tags_vbox.add_child(tag_label)
	if tags.is_empty():
		var spacer := Control.new()
		spacer.custom_minimum_size = Vector2(30, 0)
		tags_vbox.add_child(spacer)
	hbox.add_child(tags_vbox)

	# Info
	var info_vbox := VBoxContainer.new()
	info_vbox.add_theme_constant_override("separation", 3)
	info_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var rarity_label := Label.new()
	rarity_label.text = rarity.to_upper()
	rarity_label.add_theme_font_size_override("font_size", 9)
	rarity_label.add_theme_color_override("font_color", rarity_color.darkened(0.1))
	info_vbox.add_child(rarity_label)

	var name_label := Label.new()
	name_label.text = perk.get("name", "???")
	name_label.add_theme_font_size_override("font_size", 20)
	name_label.add_theme_color_override("font_color", Color(0.95, 0.92, 0.82))
	name_label.clip_text = true
	info_vbox.add_child(name_label)

	var desc_label := Label.new()
	desc_label.text = perk.get("description", "")
	desc_label.add_theme_font_size_override("font_size", 12)
	desc_label.add_theme_color_override("font_color", Color(0.62, 0.62, 0.60))
	desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info_vbox.add_child(desc_label)

	# Heat-scaled indicator
	if perk.get("heat_scaled", false):
		var heat_label := Label.new()
		heat_label.text = "🔥 Heat-scaled"
		heat_label.add_theme_font_size_override("font_size", 9)
		heat_label.add_theme_color_override("font_color", Color(0.9, 0.5, 0.2, 0.7))
		info_vbox.add_child(heat_label)

	hbox.add_child(info_vbox)

	# Cost
	var cost_vbox := VBoxContainer.new()
	cost_vbox.add_theme_constant_override("separation", 0)
	cost_vbox.size_flags_horizontal = Control.SIZE_SHRINK_END
	cost_vbox.size_flags_vertical = Control.SIZE_SHRINK_CENTER

	var cost_label := Label.new()
	cost_label.text = "%d" % cost
	cost_label.add_theme_font_size_override("font_size", 22)
	cost_label.add_theme_color_override("font_color", GOLD)
	cost_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	cost_vbox.add_child(cost_label)

	var rep_caption := Label.new()
	rep_caption.text = "REP"
	rep_caption.add_theme_font_size_override("font_size", 8)
	rep_caption.add_theme_color_override("font_color", Color(0.55, 0.50, 0.28, 0.80))
	rep_caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	cost_vbox.add_child(rep_caption)

	hbox.add_child(cost_vbox)
	panel.add_child(hbox)

	# Buy button overlay
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

	if GameManager.player_rep >= cost:
		buy_btn.pressed.connect(_on_buy_perk.bind(perk, cost))
		buy_btn.tooltip_text = "Buy for %d Rep" % cost
	else:
		buy_btn.disabled = true
		buy_btn.tooltip_text = "Not enough Rep (%d/%d)" % [GameManager.player_rep, cost]
		panel.modulate = Color(0.5, 0.5, 0.5)

	panel.add_child(buy_btn)
	return panel

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

func _on_buy_perk(perk: Dictionary, cost: int) -> void:
	if _is_rebuilding_shop:
		return
	if GameManager.player_rep < cost:
		AudioManager.play_error()
		return

	# Check if already owned (shouldn't happen, but guard)
	for p in GameManager.active_perks:
		if p.get("id", "") == perk.get("id", ""):
			AudioManager.play_error()
			return

	GameManager.player_rep -= cost
	GameManager.add_perk(perk)

	AudioManager.play_shop_buy()
	Juice.screen_flash(self, Color(0.9, 0.85, 0.3, 0.15), 0.15)

	# Remove from offers
	shop_perks.erase(perk)

	_is_rebuilding_shop = true
	_update_header()
	call_deferred("_rebuild_shop")

func _rebuild_shop() -> void:
	_build_perk_shop()
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
	_update_header()
	_update_perk_removal_panel()

# =============================================================================
# Continue
# =============================================================================

func _on_continue() -> void:
	if not GameManager.fight_order_complete and GameManager.current_opponent_index >= 2:
		GameManager.select_random_boss()
	GameManager.change_phase(GameManager.GamePhase.TOURNAMENT)
