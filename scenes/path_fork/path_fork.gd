extends Control

## Path Fork — Choose between two tournament paths after fight 2

@onready var path_container: HBoxContainer = %PathContainer

func _ready() -> void:
	_build_path_cards()
	Juice.fade_in(self, 0.4)

func _build_path_cards() -> void:
	# Find the two path opponents (fight_position 3, different paths)
	var path_opponents: Array = []
	for opp in GameManager.all_opponents:
		var pos: int = int(opp.get("fight_position", 0))
		var path: String = opp.get("path", "both")
		if pos == 3 and path != "both":
			path_opponents.append(opp)

	for opp in path_opponents:
		var card := _create_path_card(opp)
		path_container.add_child(card)

func _create_path_card(opp: Dictionary) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(300, 340)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)

	var name_label := Label.new()
	name_label.text = opp.get("name", "???")
	name_label.add_theme_font_size_override("font_size", 22)
	name_label.add_theme_color_override("font_color", Color(0.92, 0.8, 0.38))
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(name_label)

	# Opponent portrait
	var sprite_base: String = opp.get("sprite_base", "")
	var sheet_path: String = opp.get("sprite_sheet", "")
	var portrait := TextureRect.new()
	portrait.custom_minimum_size = Vector2(96, 96)
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	portrait.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	if sheet_path != "":
		var sheet_portrait := AnimatedPortrait.portrait_from_sheet(sheet_path, 4, 2)
		if sheet_portrait:
			portrait.texture = sheet_portrait
			vbox.add_child(portrait)
	elif sprite_base != "":
		var tex_path := "res://assets/sprites/opponents/%s_neutral.png" % sprite_base
		portrait.texture = load(tex_path)
		vbox.add_child(portrait)

	var archetype_label := Label.new()
	archetype_label.text = opp.get("archetype", "").to_upper()
	archetype_label.add_theme_font_size_override("font_size", 14)
	archetype_label.add_theme_color_override("font_color", Color(0.7, 0.4, 0.35))
	archetype_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(archetype_label)

	var sep := HSeparator.new()
	vbox.add_child(sep)

	# Gimmick
	var gimmick = opp.get("gimmick", null)
	if gimmick is Dictionary and not gimmick.is_empty():
		var gimmick_label := Label.new()
		gimmick_label.text = gimmick.get("name", "") + ": " + gimmick.get("description", "")
		gimmick_label.add_theme_font_size_override("font_size", 12)
		gimmick_label.add_theme_color_override("font_color", Color(0.78, 0.65, 0.35))
		gimmick_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		gimmick_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		vbox.add_child(gimmick_label)

	var stats_label := Label.new()
	stats_label.text = "HP: %d" % opp.get("hp", 80)
	stats_label.add_theme_font_size_override("font_size", 14)
	stats_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(stats_label)

	var flavor_label := Label.new()
	flavor_label.text = opp.get("flavor_text", "")
	flavor_label.add_theme_font_size_override("font_size", 11)
	flavor_label.add_theme_color_override("font_color", Color(0.55, 0.55, 0.52))
	flavor_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	flavor_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(flavor_label)

	panel.add_child(vbox)

	# Click button
	var btn := Button.new()
	btn.flat = true
	btn.anchors_preset = Control.PRESET_FULL_RECT
	btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	var path: String = opp.get("path", "")
	btn.pressed.connect(_on_path_selected.bind(path))
	panel.add_child(btn)

	return panel

func _on_path_selected(path: String) -> void:
	GameManager.set_path_choice(path)
	GameManager.change_phase(GameManager.GamePhase.TOURNAMENT)
