class_name Juice
extends RefCounted

## Utility class for screen shake, scale bounce, and other juicy effects
## All methods are static — call as Juice.method_name()

## Screen shake using pivot_offset so it works inside containers
static func screen_shake(node: CanvasItem, intensity: float = 10.0, duration: float = 0.2) -> void:
	if not is_instance_valid(node):
		return
	var tween := node.create_tween()
	var steps := int(duration / 0.03)
	for i in steps:
		var offset := Vector2(randf_range(-intensity, intensity), randf_range(-intensity, intensity))
		offset *= (1.0 - float(i) / float(steps))
		if node is Control:
			tween.tween_property(node, "pivot_offset", offset, 0.03)
		else:
			tween.tween_property(node, "position", offset, 0.03)
	if node is Control:
		tween.tween_property(node, "pivot_offset", Vector2.ZERO, 0.03)
	else:
		tween.tween_property(node, "position", Vector2.ZERO, 0.03)

## Scale bounce — works on any CanvasItem
static func scale_bounce(node: CanvasItem, scale_up: float = 1.3, duration: float = 0.3) -> void:
	if not is_instance_valid(node):
		return
	if node is Control:
		(node as Control).pivot_offset = (node as Control).size / 2.0
	var tween := node.create_tween()
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_ELASTIC)
	tween.tween_property(node, "scale", Vector2(scale_up, scale_up), duration * 0.3)
	tween.tween_property(node, "scale", Vector2.ONE, duration * 0.7)

## Fade in from transparent
static func fade_in(node: CanvasItem, duration: float = 0.3) -> void:
	if not is_instance_valid(node):
		return
	node.modulate.a = 0.0
	var tween := node.create_tween()
	tween.tween_property(node, "modulate:a", 1.0, duration)

## Flash a color then restore
static func flash(node: CanvasItem, color: Color = Color.WHITE, duration: float = 0.15) -> void:
	if not is_instance_valid(node):
		return
	var original := node.modulate
	var tween := node.create_tween()
	tween.tween_property(node, "modulate", color, duration * 0.3)
	tween.tween_property(node, "modulate", original, duration * 0.7)

## Punch-scale text from large to normal
static func punch_text(label: Label, duration: float = 0.4) -> void:
	if not is_instance_valid(label):
		return
	label.pivot_offset = label.size / 2.0
	label.scale = Vector2(1.5, 1.5)
	var tween := label.create_tween()
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_BACK)
	tween.tween_property(label, "scale", Vector2.ONE, duration)

## Slide in from left edge
static func slide_in_from_left(node: Control, duration: float = 0.4) -> void:
	if not is_instance_valid(node):
		return
	var target_pos := node.position
	node.position.x = -node.size.x
	var tween := node.create_tween()
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_BACK)
	tween.tween_property(node, "position", target_pos, duration)

## Typewriter text reveal
static func typewriter(label: Label, text: String, chars_per_sec: float = 30.0) -> void:
	if not is_instance_valid(label):
		return
	label.text = text
	label.visible_characters = 0
	var tween := label.create_tween()
	tween.tween_property(label, "visible_characters", text.length(), text.length() / chars_per_sec)

## Floating damage number popup — spawns a label that floats up and fades
static func damage_popup(parent: Control, damage: int, position: Vector2, is_heat_boosted: bool = false) -> void:
	if not is_instance_valid(parent):
		return
	var label := Label.new()
	label.text = str(damage)
	label.add_theme_font_size_override("font_size", 28 if is_heat_boosted else 22)
	if is_heat_boosted:
		label.add_theme_color_override("font_color", Color(0.95, 0.75, 0.2))
	else:
		label.add_theme_color_override("font_color", Color(0.95, 0.92, 0.85))
	label.position = position
	label.z_index = 100
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	parent.add_child(label)

	var tween := label.create_tween()
	tween.set_parallel(true)
	tween.tween_property(label, "position:y", position.y - 60.0, 0.8).set_ease(Tween.EASE_OUT)
	tween.tween_property(label, "modulate:a", 0.0, 0.8).set_delay(0.3)
	tween.chain().tween_callback(label.queue_free)

## Full-screen combo name flash
static func combo_flash(parent: Control, combo_name: String) -> void:
	if not is_instance_valid(parent):
		return
	var label := Label.new()
	label.text = combo_name
	label.add_theme_font_size_override("font_size", 42)
	label.add_theme_color_override("font_color", Color(0.95, 0.82, 0.25))
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.anchors_preset = Control.PRESET_CENTER
	label.size = Vector2(600, 60)
	label.position = Vector2(
		parent.get_viewport_rect().size.x / 2.0 - 300,
		parent.get_viewport_rect().size.y * 0.35
	)
	label.z_index = 200
	label.pivot_offset = Vector2(300, 30)
	label.scale = Vector2(2.0, 2.0)
	label.modulate.a = 0.0
	parent.add_child(label)

	var tween := label.create_tween()
	tween.tween_property(label, "modulate:a", 1.0, 0.1)
	tween.parallel().tween_property(label, "scale", Vector2.ONE, 0.3).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	tween.tween_interval(0.6)
	tween.tween_property(label, "modulate:a", 0.0, 0.3)
	tween.tween_callback(label.queue_free)

## Heat math display — small floating text showing multiplied value
static func heat_math_display(parent: Control, text: String, position: Vector2) -> void:
	if not is_instance_valid(parent):
		return
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 13)
	label.add_theme_color_override("font_color", Color(0.85, 0.65, 0.2, 0.9))
	label.position = position + Vector2(10, -15)
	label.z_index = 90
	parent.add_child(label)

	var tween := label.create_tween()
	tween.tween_property(label, "position:y", position.y - 40.0, 1.0)
	tween.parallel().tween_property(label, "modulate:a", 0.0, 1.0).set_delay(0.4)
	tween.tween_callback(label.queue_free)

## Set bonus activation — golden flash banner
static func set_bonus_activation(parent: Control, bonus_name: String) -> void:
	if not is_instance_valid(parent):
		return
	var label := Label.new()
	label.text = "SET BONUS: " + bonus_name
	label.add_theme_font_size_override("font_size", 32)
	label.add_theme_color_override("font_color", Color(0.95, 0.82, 0.25))
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.size = Vector2(parent.get_viewport_rect().size.x, 50)
	label.position = Vector2(0, parent.get_viewport_rect().size.y * 0.4)
	label.z_index = 200
	label.pivot_offset = Vector2(label.size.x / 2.0, 25)
	label.scale = Vector2(0.5, 0.5)
	label.modulate.a = 0.0
	parent.add_child(label)

	var tween := label.create_tween()
	tween.tween_property(label, "modulate:a", 1.0, 0.15)
	tween.parallel().tween_property(label, "scale", Vector2(1.1, 1.1), 0.2).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	tween.tween_property(label, "scale", Vector2.ONE, 0.1)
	tween.tween_interval(0.8)
	tween.tween_property(label, "modulate:a", 0.0, 0.3)
	tween.tween_callback(label.queue_free)

## KO slow-motion effect
static func ko_slowmo(tree: SceneTree, duration: float = 1.0) -> void:
	Engine.time_scale = 0.3
	tree.create_timer(duration * 0.3, true, false, true).timeout.connect(
		func(): Engine.time_scale = 1.0
	)
