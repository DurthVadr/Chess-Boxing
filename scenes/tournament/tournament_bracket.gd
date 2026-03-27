extends Control

## Tournament Bracket — 4-round tournament tree showing full fight progression

@onready var bracket_container: VBoxContainer = %BracketContainer
@onready var proceed_btn: Button = %ProceedBtn

func _ready() -> void:
	proceed_btn.pressed.connect(_on_proceed)
	_build_bracket()
	Juice.fade_in(self, 0.4)


func _build_bracket() -> void:
	var rounds := _get_rounds_data()

	# ── Round header labels ──────────────────────────────────────────────────
	var header_row := HBoxContainer.new()
	header_row.alignment = BoxContainer.ALIGNMENT_CENTER
	header_row.add_theme_constant_override("separation", 0)
	header_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	for i in 4:
		var col := Control.new()
		col.custom_minimum_size = Vector2(150, 28)
		col.size_flags_horizontal = Control.SIZE_SHRINK_CENTER

		var lbl := Label.new()
		lbl.text = "ROUND %d" % (i + 1)
		lbl.add_theme_font_size_override("font_size", 11)
		lbl.add_theme_color_override("font_color",
			Color(0.92, 0.80, 0.30, 1.0) if rounds[i]["status"] == "current"
			else Color(0.45, 0.40, 0.30, 0.75))
		lbl.anchors_preset = Control.PRESET_FULL_RECT
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		col.add_child(lbl)
		header_row.add_child(col)

		if i < 3:
			var spacer := Control.new()
			spacer.custom_minimum_size = Vector2(60, 0)
			spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			header_row.add_child(spacer)

	bracket_container.add_child(header_row)

	# ── Main bracket row: cards + connectors ─────────────────────────────────
	var main_row := HBoxContainer.new()
	main_row.alignment = BoxContainer.ALIGNMENT_CENTER
	main_row.add_theme_constant_override("separation", 0)
	main_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	main_row.size_flags_vertical = Control.SIZE_EXPAND_FILL

	for i in 4:
		main_row.add_child(_make_bracket_card(rounds[i]))
		if i < 3:
			main_row.add_child(_make_connector(rounds[i]["status"] == "defeated"))

	bracket_container.add_child(main_row)

	# ── Path fork notice ─────────────────────────────────────────────────────
	if GameManager.chosen_path == "" and GameManager.current_opponent_index >= 2:
		var fork_lbl := Label.new()
		fork_lbl.text = "— PATH FORK AHEAD —"
		fork_lbl.add_theme_font_size_override("font_size", 13)
		fork_lbl.add_theme_color_override("font_color", Color(0.8, 0.65, 0.3))
		fork_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		bracket_container.add_child(fork_lbl)


func _get_rounds_data() -> Array:
	var idx: int = GameManager.current_opponent_index
	var rounds: Array = []

	for round_num in range(4):
		var status: String
		var opponent: Dictionary = {}

		if round_num < idx:
			# Already fought — show who was defeated
			status = "defeated"
			if round_num < GameManager.fight_order.size():
				opponent = GameManager._get_opponent_by_id(GameManager.fight_order[round_num])
		elif round_num == idx:
			# Active fight
			status = "current"
			opponent = GameManager.current_opponent
		else:
			# Future — known if already in fight_order (post path-fork), unknown otherwise
			if round_num < GameManager.fight_order.size():
				opponent = GameManager._get_opponent_by_id(GameManager.fight_order[round_num])
				status = "future_known"
			else:
				status = "future_unknown"

		rounds.append({
			"round": round_num + 1,
			"status": status,
			"opponent": opponent,
		})

	return rounds


func _make_bracket_card(round_data: Dictionary) -> PanelContainer:
	var status: String = round_data["status"]
	var opponent: Dictionary = round_data["opponent"]
	var round_num: int = round_data["round"]
	var is_unknown := status == "future_unknown"

	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(150, 190)

	var card_bg := StyleBoxFlat.new()
	card_bg.corner_radius_top_left = 10
	card_bg.corner_radius_top_right = 10
	card_bg.corner_radius_bottom_left = 10
	card_bg.corner_radius_bottom_right = 10
	card_bg.border_width_left = 3
	card_bg.border_width_right = 3
	card_bg.border_width_top = 3
	card_bg.border_width_bottom = 3

	match status:
		"defeated":
			card_bg.bg_color = Color(0.05, 0.09, 0.06, 1)
			card_bg.border_color = Color(0.28, 0.58, 0.30, 0.8)
		"current":
			card_bg.bg_color = Color(0.10, 0.08, 0.04, 1)
			card_bg.border_color = Color(0.9, 0.78, 0.3, 1)
			_pulse_border(card_bg)
		"future_known":
			card_bg.bg_color = Color(0.07, 0.06, 0.10, 1)
			card_bg.border_color = Color(0.30, 0.26, 0.18, 0.45)
		_:
			card_bg.bg_color = Color(0.06, 0.05, 0.09, 1)
			card_bg.border_color = Color(0.22, 0.20, 0.28, 0.35)

	card.add_theme_stylebox_override("panel", card_bg)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	card.add_child(vbox)

	# ── Portrait ─────────────────────────────────────────────────────────────
	var portrait_wrap := PanelContainer.new()
	portrait_wrap.custom_minimum_size = Vector2(110, 110)
	portrait_wrap.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var pw_bg := StyleBoxFlat.new()
	pw_bg.corner_radius_top_left = 6
	pw_bg.corner_radius_top_right = 6
	pw_bg.corner_radius_bottom_left = 6
	pw_bg.corner_radius_bottom_right = 6

	if is_unknown:
		pw_bg.bg_color = Color(0.04, 0.03, 0.06)
		portrait_wrap.add_theme_stylebox_override("panel", pw_bg)

		var q_lbl := Label.new()
		q_lbl.text = "?"
		q_lbl.add_theme_font_size_override("font_size", 64)
		q_lbl.add_theme_color_override("font_color", Color(0.18, 0.15, 0.22, 1))
		q_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		q_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		q_lbl.custom_minimum_size = Vector2(100, 100)
		portrait_wrap.add_child(q_lbl)
	else:
		pw_bg.bg_color = Color(0.05, 0.04, 0.08)
		portrait_wrap.add_theme_stylebox_override("panel", pw_bg)

		var portrait := TextureRect.new()
		portrait.custom_minimum_size = Vector2(100, 100)
		portrait.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
		portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		var sprite_base: String = opponent.get("sprite_base", "")
		if sprite_base != "":
			portrait.texture = _load_opponent_portrait(sprite_base)
		if status == "future_known":
			portrait_wrap.modulate = Color(1, 1, 1, 0.55)
		portrait_wrap.add_child(portrait)

	vbox.add_child(portrait_wrap)

	# ── Name label ───────────────────────────────────────────────────────────
	var name_lbl := Label.new()
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_lbl.custom_minimum_size = Vector2(140, 0)

	if is_unknown:
		name_lbl.text = "???"
		name_lbl.add_theme_font_size_override("font_size", 20)
		name_lbl.add_theme_color_override("font_color", Color(0.28, 0.25, 0.35, 1))
	else:
		name_lbl.text = opponent.get("name", "???")
		name_lbl.add_theme_font_size_override("font_size", 12)
		name_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		match status:
			"defeated":
				name_lbl.add_theme_color_override("font_color", Color(0.45, 0.78, 0.50, 1))
			"current":
				name_lbl.add_theme_color_override("font_color", Color(0.92, 0.80, 0.35, 1))
			"future_known":
				name_lbl.add_theme_color_override("font_color", Color(0.50, 0.46, 0.36, 0.6))

	vbox.add_child(name_lbl)

	# ── Status tag ───────────────────────────────────────────────────────────
	var tag := Label.new()
	tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tag.add_theme_font_size_override("font_size", 10)

	match status:
		"current":
			tag.text = "◄ NOW FIGHTING ►"
			tag.add_theme_color_override("font_color", Color(0.9, 0.78, 0.3, 0.85))
			vbox.add_child(tag)
		"defeated":
			tag.text = "✓ DEFEATED"
			tag.add_theme_color_override("font_color", Color(0.35, 0.72, 0.38, 1))
			vbox.add_child(tag)
		"future_known":
			if round_num == 4:
				tag.text = "— FINAL BOSS —"
				tag.add_theme_color_override("font_color", Color(0.75, 0.28, 0.28, 0.75))
				vbox.add_child(tag)

	return card


func _load_opponent_portrait(sprite_base: String) -> Texture2D:
	var path_64 := "res://assets/sprites/opponents/%s_64.png" % sprite_base
	if ResourceLoader.exists(path_64):
		return load(path_64)
	var path_neutral := "res://assets/sprites/opponents/%s_neutral.png" % sprite_base
	if ResourceLoader.exists(path_neutral):
		return load(path_neutral)
	return null


func _make_connector(is_active: bool) -> Control:
	var wrapper := Control.new()
	wrapper.custom_minimum_size = Vector2(60, 190)
	wrapper.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var line := ColorRect.new()
	line.anchor_left = 0.0
	line.anchor_top = 0.5
	line.anchor_right = 1.0
	line.anchor_bottom = 0.5
	line.offset_top = -2.0
	line.offset_bottom = 2.0
	line.color = Color(0.62, 0.52, 0.20, 0.75) if is_active else Color(0.28, 0.24, 0.32, 0.35)
	wrapper.add_child(line)

	# Arrowhead chevron at midpoint
	var arrow := Label.new()
	arrow.text = "›"
	arrow.add_theme_font_size_override("font_size", 20)
	arrow.add_theme_color_override("font_color",
		Color(0.62, 0.52, 0.20, 0.85) if is_active else Color(0.28, 0.24, 0.32, 0.45))
	arrow.anchor_left = 0.5
	arrow.anchor_top = 0.5
	arrow.anchor_right = 0.5
	arrow.anchor_bottom = 0.5
	arrow.offset_left = -8.0
	arrow.offset_top = -14.0
	arrow.offset_right = 8.0
	arrow.offset_bottom = 14.0
	arrow.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	arrow.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	wrapper.add_child(arrow)

	return wrapper


func _pulse_border(style: StyleBoxFlat) -> void:
	var tween := create_tween()
	tween.set_loops()
	tween.tween_method(
		func(a: float) -> void: style.border_color = Color(0.9, 0.78, 0.3, a),
		0.55, 1.0, 0.9
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_method(
		func(a: float) -> void: style.border_color = Color(0.9, 0.78, 0.3, a),
		1.0, 0.55, 0.9
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


func _on_proceed() -> void:
	GameManager.start_fight()
