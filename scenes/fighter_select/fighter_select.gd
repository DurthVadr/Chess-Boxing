extends Control

## Fighter Select — Card-style character picker with portrait, name panel, and locked state

@onready var fighter_container: HBoxContainer = %FighterContainer
@onready var confirm_btn: Button = %ConfirmBtn
@onready var fighter_name_label: Label = %FighterNameLabel
@onready var fighter_stats_label: Label = %FighterStatsLabel
@onready var fighter_passive_label: Label = %FighterPassiveLabel

var selected_fighter: Dictionary = {}
var fighter_cards: Array[PanelContainer] = []
var fighter_card_styles: Array[StyleBoxFlat] = []

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
	_build_fighter_cards()
	Juice.fade_in(self, 0.4)

func _build_fighter_cards() -> void:
	for fighter in GameManager.all_fighters:
		var fighter_id: String = fighter.get("id", "")
		var is_unlocked := SaveManager.is_fighter_unlocked(fighter_id)

		# ── Card frame ───────────────────────────────────────────────────
		var card := PanelContainer.new()
		card.custom_minimum_size = Vector2(200, 300)

		var card_bg := StyleBoxFlat.new()
		card_bg.corner_radius_top_left = 12
		card_bg.corner_radius_top_right = 12
		card_bg.corner_radius_bottom_left = 12
		card_bg.corner_radius_bottom_right = 12
		card_bg.border_width_left = 3
		card_bg.border_width_right = 3
		card_bg.border_width_top = 3
		card_bg.border_width_bottom = 3
		if is_unlocked:
			card_bg.bg_color = CARD_COLORS.get(fighter_id, Color(0.2, 0.2, 0.22))
			card_bg.border_color = Color(0.9, 0.78, 0.3, 0)
		else:
			card_bg.bg_color = Color(0.22, 0.22, 0.22)
			card_bg.border_color = Color(0.4, 0.4, 0.4, 0)
			card.modulate = Color(1.0, 1.0, 1.0, 0.55)
		card.add_theme_stylebox_override("panel", card_bg)

		var vbox := VBoxContainer.new()
		vbox.add_theme_constant_override("separation", 0)
		card.add_child(vbox)

		# ── Top 60% — portrait area (180 px) ────────────────────────────
		var portrait_area := Control.new()
		portrait_area.custom_minimum_size = Vector2(200, 180)
		portrait_area.size_flags_horizontal = Control.SIZE_FILL
		portrait_area.clip_contents = true
		vbox.add_child(portrait_area)

		if is_unlocked:
			var portrait := TextureRect.new()
			portrait.anchors_preset = Control.PRESET_FULL_RECT
			portrait.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
			portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			var sprite_base: String = fighter.get("sprite_base", "")
			if sprite_base != "":
				var tex_path := "res://assets/sprites/fighters/%s_neutral.png" % sprite_base
				if ResourceLoader.exists(tex_path):
					portrait.texture = load(tex_path)
			portrait_area.add_child(portrait)
		else:
			var lock_lbl := Label.new()
			lock_lbl.text = "🔒"
			lock_lbl.add_theme_font_size_override("font_size", 72)
			lock_lbl.anchors_preset = Control.PRESET_FULL_RECT
			lock_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			lock_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			lock_lbl.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5, 0.8))
			portrait_area.add_child(lock_lbl)

		# ── Bottom 40% — name panel (fills remaining height) ────────────
		var name_panel := PanelContainer.new()
		name_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
		var name_style := StyleBoxFlat.new()
		name_style.bg_color = Color(0.04, 0.03, 0.07, 0.92)
		name_style.content_margin_left = 8.0
		name_style.content_margin_right = 8.0
		name_style.content_margin_top = 10.0
		name_style.content_margin_bottom = 10.0
		name_panel.add_theme_stylebox_override("panel", name_style)
		vbox.add_child(name_panel)

		var name_lbl := Label.new()
		name_lbl.text = fighter.get("name", "???")
		name_lbl.add_theme_font_size_override("font_size", 17)
		name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		name_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		name_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		name_lbl.size_flags_horizontal = Control.SIZE_FILL
		name_lbl.size_flags_vertical = Control.SIZE_EXPAND_FILL
		if is_unlocked:
			name_lbl.add_theme_color_override("font_color", Color(0.97, 0.95, 0.88, 1))
		else:
			name_lbl.add_theme_color_override("font_color", Color(0.55, 0.55, 0.55, 0.5))
		name_panel.add_child(name_lbl)

		# ── Invisible click/hover overlay ────────────────────────────────
		var btn := Button.new()
		btn.flat = true
		btn.anchors_preset = Control.PRESET_FULL_RECT
		btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		if not is_unlocked:
			btn.disabled = true
		btn.pressed.connect(_on_fighter_selected.bind(fighter, card, card_bg))
		btn.mouse_entered.connect(_on_card_hover_enter.bind(card_bg))
		btn.mouse_exited.connect(_on_card_hover_exit.bind(card_bg))
		card.add_child(btn)

		fighter_container.add_child(card)
		fighter_cards.append(card)
		fighter_card_styles.append(card_bg)

func _on_card_hover_enter(style: StyleBoxFlat) -> void:
	if style.border_color.a < 0.9:
		style.border_color = Color(0.9, 0.78, 0.3, 0.45)

func _on_card_hover_exit(style: StyleBoxFlat) -> void:
	if style.border_color.a < 0.9:
		style.border_color = Color(0.9, 0.78, 0.3, 0)

func _on_fighter_selected(fighter: Dictionary, card: PanelContainer, card_bg: StyleBoxFlat) -> void:
	selected_fighter = fighter
	confirm_btn.disabled = false

	fighter_name_label.text = fighter.get("name", "???")
	fighter_stats_label.text = "HP: %d  |  Stamina: %d" % [fighter.get("hp", 0), fighter.get("stamina", 0)]
	fighter_passive_label.text = fighter.get("passive_description", "No passive")

	for style in fighter_card_styles:
		style.border_color = Color(0.9, 0.78, 0.3, 0)
	card_bg.border_color = Color(0.9, 0.78, 0.3, 1)

	Juice.scale_bounce(card, 1.08, 0.25)

func _on_confirm() -> void:
	if selected_fighter.is_empty():
		return
	GameManager.start_new_run(selected_fighter)
