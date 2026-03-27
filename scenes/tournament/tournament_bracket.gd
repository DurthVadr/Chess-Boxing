extends Control

## Tournament Bracket — Shows opponents in fight order

@onready var bracket_container: VBoxContainer = %BracketContainer
@onready var proceed_btn: Button = %ProceedBtn

func _ready() -> void:
	proceed_btn.pressed.connect(_on_proceed)
	_build_bracket()
	Juice.fade_in(self, 0.4)

func _build_bracket() -> void:
	# Show opponents from fight_order (only known ones)
	var fight_order: Array = GameManager.fight_order

	for i in fight_order.size():
		var opp_id: String = fight_order[i]
		var opp := GameManager._get_opponent_by_id(opp_id)
		var row := HBoxContainer.new()
		row.alignment = BoxContainer.ALIGNMENT_CENTER
		row.add_theme_constant_override("separation", 10)

		# Add small portrait for known opponents
		var sprite_base: String = opp.get("sprite_base", "")
		if sprite_base != "" and i <= GameManager.current_opponent_index:
			var portrait := TextureRect.new()
			portrait.custom_minimum_size = Vector2(40, 40)
			portrait.expand_mode = 1
			portrait.stretch_mode = 5
			var tex_path := "res://assets/sprites/opponents/%s_64.png" % sprite_base
			portrait.texture = load(tex_path)
			row.add_child(portrait)

		var label := Label.new()
		label.custom_minimum_size = Vector2(450, 50)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER

		if i < GameManager.current_opponent_index:
			label.text = "✓ " + opp.get("name", "???") + " — DEFEATED"
			label.add_theme_color_override("font_color", Color(0.35, 0.7, 0.38))
		elif i == GameManager.current_opponent_index:
			label.text = "► " + opp.get("name", "???")
			label.add_theme_color_override("font_color", Color(0.9, 0.78, 0.35))
			label.add_theme_font_size_override("font_size", 24)
			Juice.scale_bounce(label, 1.05, 0.4)
		else:
			label.text = "? ? ?"
			label.add_theme_color_override("font_color", Color(0.45, 0.45, 0.42))

		row.add_child(label)
		bracket_container.add_child(row)

	# If path not chosen yet and we're past fight 2, show fork hint
	if GameManager.chosen_path == "" and GameManager.current_opponent_index >= 2:
		var fork_label := Label.new()
		fork_label.text = "— PATH FORK AHEAD —"
		fork_label.add_theme_font_size_override("font_size", 16)
		fork_label.add_theme_color_override("font_color", Color(0.8, 0.65, 0.3))
		fork_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		bracket_container.add_child(fork_label)

	# Always show boss at the end
	if GameManager.chosen_path != "":
		var remaining := fight_order.size() - GameManager.current_opponent_index
		if remaining > 1:
			var boss_label := Label.new()
			boss_label.text = "... → FINAL BOSS"
			boss_label.add_theme_font_size_override("font_size", 14)
			boss_label.add_theme_color_override("font_color", Color(0.55, 0.55, 0.52))
			boss_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			bracket_container.add_child(boss_label)

func _on_proceed() -> void:
	GameManager.start_fight()
