extends Control

## Fighter Select — Card-style display of available fighters

@onready var fighter_container: HBoxContainer = %FighterContainer
@onready var confirm_btn: Button = %ConfirmBtn
@onready var fighter_name_label: Label = %FighterNameLabel
@onready var fighter_stats_label: Label = %FighterStatsLabel
@onready var fighter_passive_label: Label = %FighterPassiveLabel

var selected_fighter: Dictionary = {}
var fighter_cards: Array[Button] = []

const CARD_COLORS := {
	"rookie": Color(0.3, 0.5, 0.3),
	"grandmaster": Color(0.3, 0.3, 0.6),
	"brawler": Color(0.6, 0.25, 0.25),
	"hustler": Color(0.5, 0.4, 0.2),
	"prodigy": Color(0.45, 0.25, 0.55),
}

func _ready() -> void:
	confirm_btn.pressed.connect(_on_confirm)
	confirm_btn.disabled = true
	_build_fighter_cards()
	Juice.fade_in(self, 0.4)

func _build_fighter_cards() -> void:
	for fighter in GameManager.all_fighters:
		if not fighter.get("unlocked", false):
			continue

		var card := Button.new()
		card.custom_minimum_size = Vector2(200, 260)
		card.text = fighter.name

		var style := StyleBoxFlat.new()
		style.bg_color = CARD_COLORS.get(fighter.id, Color(0.3, 0.3, 0.3))
		style.corner_radius_top_left = 12
		style.corner_radius_top_right = 12
		style.corner_radius_bottom_left = 12
		style.corner_radius_bottom_right = 12
		style.border_width_left = 3
		style.border_width_right = 3
		style.border_width_top = 3
		style.border_width_bottom = 3
		style.border_color = Color(0.9, 0.78, 0.3, 0)
		card.add_theme_stylebox_override("normal", style)

		var hover_style := style.duplicate()
		hover_style.bg_color = style.bg_color.lightened(0.15)
		card.add_theme_stylebox_override("hover", hover_style)

		var pressed_style := style.duplicate()
		pressed_style.border_color = Color(0.9, 0.78, 0.3, 1)
		card.add_theme_stylebox_override("pressed", pressed_style)

		card.add_theme_font_size_override("font_size", 20)

		card.pressed.connect(_on_fighter_selected.bind(fighter, card))
		fighter_container.add_child(card)
		fighter_cards.append(card)

func _on_fighter_selected(fighter: Dictionary, card: Button) -> void:
	selected_fighter = fighter
	confirm_btn.disabled = false

	# Update info panel
	fighter_name_label.text = fighter.name
	fighter_stats_label.text = "HP: %d  |  Stamina: %d" % [fighter.hp, fighter.stamina]
	fighter_passive_label.text = fighter.get("passive_description", "No passive")

	# Highlight selected card
	for c in fighter_cards:
		var style: StyleBoxFlat = c.get_theme_stylebox("normal")
		style.border_color = Color(0.9, 0.78, 0.3, 0)

	var selected_style: StyleBoxFlat = card.get_theme_stylebox("normal")
	selected_style.border_color = Color(0.9, 0.78, 0.3, 1)

	Juice.scale_bounce(card, 1.08, 0.25)

func _on_confirm() -> void:
	if selected_fighter.is_empty():
		return
	GameManager.start_new_run(selected_fighter)
