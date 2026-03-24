extends Control

## Tournament Bracket — Shows upcoming opponents

@onready var bracket_container: VBoxContainer = %BracketContainer
@onready var proceed_btn: Button = %ProceedBtn

func _ready() -> void:
	proceed_btn.pressed.connect(_on_proceed)
	_build_bracket()
	Juice.fade_in(self, 0.4)

func _build_bracket() -> void:
	for i in GameManager.all_opponents.size():
		var opp: Dictionary = GameManager.all_opponents[i]
		var row := HBoxContainer.new()
		row.alignment = BoxContainer.ALIGNMENT_CENTER

		var label := Label.new()
		label.custom_minimum_size = Vector2(400, 50)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER

		if i < GameManager.current_opponent_index:
			# Already defeated
			label.text = "✓ " + opp.name + " — DEFEATED"
			label.add_theme_color_override("font_color", Color(0.3, 0.7, 0.3))
		elif i == GameManager.current_opponent_index:
			# Current fight
			label.text = "► " + opp.name
			label.add_theme_color_override("font_color", Color(0.9, 0.78, 0.3))
			label.add_theme_font_size_override("font_size", 24)
			Juice.scale_bounce(label, 1.05, 0.4)
		else:
			# Future — silhouette
			label.text = "? ? ?"
			label.add_theme_color_override("font_color", Color(0.4, 0.4, 0.4))

		row.add_child(label)
		bracket_container.add_child(row)

func _on_proceed() -> void:
	GameManager.start_fight()
