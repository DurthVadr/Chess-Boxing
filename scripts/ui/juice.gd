class_name Juice
extends RefCounted

## Utility class for screen shake, scale bounce, and other juicy effects

static func screen_shake(node: Node, intensity: float = 10.0, duration: float = 0.2) -> void:
	var original_pos := (node as Control).position if node is Control else (node as Node2D).position
	var tween := node.create_tween()
	var steps := int(duration / 0.03)
	for i in steps:
		var offset := Vector2(randf_range(-intensity, intensity), randf_range(-intensity, intensity))
		# Decay intensity over time
		offset *= (1.0 - float(i) / float(steps))
		if node is Control:
			tween.tween_property(node, "position", original_pos + offset, 0.03)
		else:
			tween.tween_property(node, "position", original_pos + offset, 0.03)
	if node is Control:
		tween.tween_property(node, "position", original_pos, 0.03)
	else:
		tween.tween_property(node, "position", original_pos, 0.03)

static func scale_bounce(node: Node, scale_up: float = 1.3, duration: float = 0.3) -> void:
	var tween := node.create_tween()
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_ELASTIC)
	tween.tween_property(node, "scale", Vector2(scale_up, scale_up), duration * 0.3)
	tween.tween_property(node, "scale", Vector2.ONE, duration * 0.7)

static func fade_in(node: CanvasItem, duration: float = 0.3) -> void:
	node.modulate.a = 0.0
	var tween := node.create_tween()
	tween.tween_property(node, "modulate:a", 1.0, duration)

static func flash(node: CanvasItem, color: Color = Color.WHITE, duration: float = 0.15) -> void:
	var original := node.modulate
	var tween := node.create_tween()
	tween.tween_property(node, "modulate", color, duration * 0.3)
	tween.tween_property(node, "modulate", original, duration * 0.7)

static func punch_text(label: Label, duration: float = 0.4) -> void:
	label.pivot_offset = label.size / 2.0
	var tween := label.create_tween()
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_BACK)
	label.scale = Vector2(1.5, 1.5)
	tween.tween_property(label, "scale", Vector2.ONE, duration)

static func slide_in_from_left(node: Control, duration: float = 0.4) -> void:
	var target_pos := node.position
	node.position.x = -node.size.x
	var tween := node.create_tween()
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_BACK)
	tween.tween_property(node, "position", target_pos, duration)

static func slide_in_from_right(node: Control, duration: float = 0.4) -> void:
	var target_pos := node.position
	node.position.x = node.get_viewport_rect().size.x + node.size.x
	var tween := node.create_tween()
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_BACK)
	tween.tween_property(node, "position", target_pos, duration)

static func typewriter(label: Label, text: String, chars_per_sec: float = 30.0) -> void:
	label.text = ""
	label.visible_characters = 0
	label.text = text
	var tween := label.create_tween()
	tween.tween_property(label, "visible_characters", text.length(), text.length() / chars_per_sec)
