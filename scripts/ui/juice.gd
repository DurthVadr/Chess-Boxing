class_name Juice
extends RefCounted

## Utility class for screen shake, scale bounce, and other juicy effects
## All methods are static — call as Juice.method_name()

## Screen shake using pivot_offset so it works inside containers
static func screen_shake(node: CanvasItem, intensity: float = 10.0, duration: float = 0.2) -> void:
	if not is_instance_valid(node):
		return
	if not SaveManager.settings.get("screen_shake", true):
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

## "BLOCKED" text that pops in big then slowly drifts down and fades
static func blocked_popup(parent: Control, position: Vector2) -> void:
	if not is_instance_valid(parent):
		return
	var label := Label.new()
	label.text = "BLOCKED"
	label.add_theme_font_size_override("font_size", 36)
	label.add_theme_color_override("font_color", Color(0.35, 0.65, 1.0))
	label.add_theme_color_override("font_outline_color", Color(0.08, 0.06, 0.18))
	label.add_theme_constant_override("outline_size", 4)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.z_index = 200
	label.pivot_offset = Vector2(80, 20)
	label.position = position - Vector2(80, 20)
	label.scale = Vector2(0.3, 0.3)
	label.modulate.a = 0.0
	parent.add_child(label)

	var tween := label.create_tween()
	# Pop in
	tween.set_parallel(true)
	tween.tween_property(label, "scale", Vector2(1.2, 1.2), 0.12).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	tween.tween_property(label, "modulate:a", 1.0, 0.08)
	# Settle
	tween.chain().tween_property(label, "scale", Vector2.ONE, 0.15).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_ELASTIC)
	# Hold briefly then drift down and fade
	tween.tween_interval(0.3)
	tween.set_parallel(true)
	tween.tween_property(label, "position:y", position.y + 40.0, 0.7).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
	tween.tween_property(label, "modulate:a", 0.0, 0.5).set_delay(0.2)
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

## Dodge slide — character sways sideways and snaps back smoothly
static func dodge_slide(node: CanvasItem, direction: float = 1.0, distance: float = 30.0, duration: float = 0.35) -> void:
	if not is_instance_valid(node):
		return
	var prop := "pivot_offset" if node is Control else "position"
	var base: Vector2 = node.get(prop)
	var offset := base + Vector2(distance * direction, -8.0)
	var tween := node.create_tween()
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_BACK)
	tween.tween_property(node, prop, offset, duration * 0.3)
	tween.tween_property(node, prop, base, duration * 0.7).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_ELASTIC)

## Hit lunge — attacker slides toward target then snaps back
static func hit_lunge(node: CanvasItem, direction: float = 1.0, distance: float = 20.0, duration: float = 0.2) -> void:
	if not is_instance_valid(node):
		return
	var prop := "pivot_offset" if node is Control else "position"
	var base: Vector2 = node.get(prop)
	var lunge := base + Vector2(distance * direction, 0.0)
	var tween := node.create_tween()
	tween.tween_property(node, prop, lunge, duration * 0.35).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	tween.tween_property(node, prop, base, duration * 0.65).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)

## Impact burst — expanding ring at hit position, fades out
static func impact_burst(parent: Control, pos: Vector2, color: Color = Color(1.0, 0.85, 0.3, 0.9), radius: float = 40.0) -> void:
	if not is_instance_valid(parent):
		return
	var ring := _ImpactRing.new()
	ring.burst_color = color
	ring.max_radius = radius
	ring.z_index = 150
	ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Pre-set size so position calc works before _ready
	var ring_size := Vector2(radius * 2 + 10, radius * 2 + 10)
	ring.custom_minimum_size = ring_size
	ring.size = ring_size
	ring.position = pos - ring_size / 2.0
	parent.add_child(ring)

## Full-screen flash overlay — brief white/color flash for big moments
static func screen_flash(parent: Control, color: Color = Color(1, 1, 1, 0.3), duration: float = 0.15) -> void:
	if not is_instance_valid(parent):
		return
	var overlay := ColorRect.new()
	overlay.color = color
	overlay.anchors_preset = Control.PRESET_FULL_RECT
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.z_index = 300
	parent.add_child(overlay)
	var tween := overlay.create_tween()
	tween.tween_property(overlay, "color:a", 0.0, duration).set_ease(Tween.EASE_OUT)
	tween.tween_callback(overlay.queue_free)

## HP bar punch — makes an HP bar jump when taking damage
static func bar_punch(bar: ProgressBar, duration: float = 0.25) -> void:
	if not is_instance_valid(bar):
		return
	bar.pivot_offset = bar.size / 2.0
	var tween := bar.create_tween()
	tween.tween_property(bar, "scale", Vector2(1.08, 1.15), duration * 0.25).set_ease(Tween.EASE_OUT)
	tween.tween_property(bar, "scale", Vector2.ONE, duration * 0.75).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_ELASTIC)

## Ghostly afterimage — spawns a fading duplicate at the node's position
static func afterimage(parent: Control, source: CanvasItem, color: Color = Color(0.4, 0.6, 1.0, 0.5), count: int = 3, spacing: float = 0.06) -> void:
	if not is_instance_valid(parent) or not is_instance_valid(source):
		return
	for i in count:
		var ghost := ColorRect.new()
		ghost.size = source.size if source is Control else Vector2(60, 80)
		ghost.color = Color(color.r, color.g, color.b, color.a * (1.0 - float(i) * 0.3))
		ghost.position = source.global_position + Vector2(float(i) * 8.0, 0)
		ghost.z_index = 90
		ghost.mouse_filter = Control.MOUSE_FILTER_IGNORE
		parent.add_child(ghost)
		var tween := ghost.create_tween()
		tween.set_ease(Tween.EASE_OUT)
		tween.tween_property(ghost, "modulate:a", 0.0, 0.4).set_delay(spacing * i)
		tween.tween_callback(ghost.queue_free)

## Confetti burst — falling colored rectangles celebrating a win.
## intensity: 1–6 (more pieces + staggered follow-up waves at 3+).
## chain_waves: when false, only this wave (used for staggered bursts).
static func confetti(parent: Control, intensity: int = 1, chain_waves: bool = true) -> void:
	if not is_instance_valid(parent):
		return
	var lv := clampi(intensity, 1, 6)
	var counts: Array = [32, 50, 72, 100, 130, 165]
	var count: int = counts[lv - 1]
	var palette: Array[Color] = [
		Color(0.9, 0.78, 0.3),   # gold
		Color(0.35, 0.82, 0.45), # green
		Color(0.40, 0.65, 1.0),  # blue
		Color(0.95, 0.38, 0.38), # red
		Color(0.78, 0.42, 0.95), # purple
		Color(1.0,  0.92, 0.38), # yellow
		Color(0.95, 0.95, 0.95), # white
		Color(0.35, 0.92, 0.88), # cyan
		Color(1.0, 0.55, 0.35),  # orange
		Color(0.55, 0.95, 0.55), # mint
	]
	var vp := parent.get_viewport_rect().size
	for i in count:
		var piece := ColorRect.new()
		if lv >= 4:
			piece.size = Vector2(randf_range(7.0, 18.0), randf_range(5.0, 11.0))
		else:
			piece.size = Vector2(randf_range(6.0, 15.0), randf_range(4.0, 9.0))
		piece.color = palette[randi() % palette.size()]
		piece.mouse_filter = Control.MOUSE_FILTER_IGNORE
		piece.z_index = 210
		var sx := randf_range(-40.0, vp.x + 40.0)
		piece.position = Vector2(sx, randf_range(-80.0, -6.0))
		piece.pivot_offset = piece.size / 2.0
		piece.rotation = randf_range(0.0, TAU)
		parent.add_child(piece)

		var delay := randf_range(0.0, 0.95)
		var fall_t := randf_range(1.15, 2.75)
		var wind := sin(float(i) * 0.37 + randf() * 2.2) * 48.0
		var end_pos := Vector2(sx + randf_range(-120.0, 120.0) + wind, vp.y + 40.0)
		var end_rot := piece.rotation + randf_range(-PI * 5.0, PI * 5.0)

		var tw := piece.create_tween()
		tw.set_parallel(true)
		tw.tween_property(piece, "position", end_pos, fall_t).set_delay(delay).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tw.tween_property(piece, "rotation", end_rot, fall_t).set_delay(delay)
		tw.tween_property(piece, "modulate:a", 0.0, fall_t * 0.5).set_delay(delay + fall_t * 0.55)
		tw.set_parallel(false)
		tw.tween_callback(piece.queue_free)

	if not chain_waves:
		return
	var seq := parent.create_tween()
	if lv >= 3:
		seq.tween_interval(0.4)
		seq.tween_callback(func() -> void: Juice.confetti(parent, clampi(lv - 2, 1, 5), false))
	if lv >= 5:
		seq.tween_interval(0.5)
		seq.tween_callback(func() -> void: Juice.confetti(parent, clampi(lv - 3, 1, 4), false))


## Big centered stamp — pops in then fades (fight win / celebration).
static func victory_banner(parent: Control, text: String = "WINNER!") -> void:
	if not is_instance_valid(parent):
		return
	var vp := parent.get_viewport_rect().size
	var lbl := Label.new()
	lbl.text = text
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl.add_theme_font_size_override("font_size", 52)
	lbl.add_theme_color_override("font_color", Color(0.94, 0.82, 0.32))
	lbl.add_theme_color_override("font_outline_color", Color(0.06, 0.04, 0.12))
	lbl.add_theme_constant_override("outline_size", 8)
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lbl.z_index = 400
	lbl.custom_minimum_size = Vector2(mini(vp.x - 40.0, 720.0), 88.0)
	lbl.position = Vector2((vp.x - lbl.custom_minimum_size.x) * 0.5, vp.y * 0.16)
	lbl.pivot_offset = lbl.custom_minimum_size * 0.5
	lbl.scale = Vector2(1.45, 1.45)
	lbl.modulate.a = 0.0
	parent.add_child(lbl)

	var tw := lbl.create_tween()
	tw.set_parallel(true)
	tw.tween_property(lbl, "modulate:a", 1.0, 0.12)
	tw.tween_property(lbl, "scale", Vector2.ONE, 0.42).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.set_parallel(false)
	tw.tween_interval(0.95)
	tw.tween_property(lbl, "modulate:a", 0.0, 0.4)
	tw.tween_callback(lbl.queue_free)

## KO slow-motion effect
static func ko_slowmo(tree: SceneTree, duration: float = 1.0) -> void:
	Engine.time_scale = 0.3
	tree.create_timer(duration * 0.3, true, false, true).timeout.connect(
		func(): Engine.time_scale = 1.0
	)

## ─── Internal helper: expanding impact ring drawn via _draw ───
class _ImpactRing extends Control:
	var burst_color: Color = Color(1.0, 0.85, 0.3, 0.9)
	var max_radius: float = 40.0
	var _t: float = 0.0
	var _duration: float = 0.35

	func _ready() -> void:
		mouse_filter = MOUSE_FILTER_IGNORE

	func _process(delta: float) -> void:
		_t += delta
		if _t >= _duration:
			queue_free()
			return
		queue_redraw()

	func _draw() -> void:
		var progress := _t / _duration
		var current_radius := max_radius * progress
		var alpha := (1.0 - progress) * burst_color.a
		var width := lerpf(4.0, 1.0, progress)
		var c := Color(burst_color.r, burst_color.g, burst_color.b, alpha)
		var center := size / 2.0
		draw_arc(center, current_radius, 0, TAU, 32, c, width, true)
		# Inner glow ring
		if progress < 0.6:
			var inner_r := current_radius * 0.6
			var inner_a := alpha * 0.5
			draw_arc(center, inner_r, 0, TAU, 24, Color(c.r, c.g, c.b, inner_a), width * 0.5, true)
