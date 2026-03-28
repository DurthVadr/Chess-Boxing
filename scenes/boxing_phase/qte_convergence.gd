class_name QTEConvergence
extends Control

## QTE for Hook / Uppercut — two concentric circles.
## Outer ring shrinks towards the inner target. Press ui_accept at the right
## moment. Rendered over the enemy portrait.
## Returns: "critical", "normal", or "miss".

signal completed(result: String)

const TARGET_RADIUS := 28.0
const START_RADIUS := 120.0
const SHRINK_DURATION := 1.1  # seconds for outer to reach zero

# Thresholds (difference between outer and target radii)
const CRITICAL_THRESHOLD := 8.0   # Within 8px = critical
const NORMAL_THRESHOLD := 22.0    # Within 22px = normal

var _outer_radius := START_RADIUS
var _active := false
var _resolved := false
var _result := ""
var _flash_timer := 0.0
var _elapsed := 0.0

var prompt_text := "STRIKE!"
var prompt_color := Color(0.88, 0.36, 0.32)

const TARGET_COLOR := Color(0.90, 0.78, 0.28, 0.45)
const OUTER_COLOR := Color(0.95, 0.30, 0.25, 0.70)
const CRITICAL_FLASH := Color(1.0, 0.90, 0.30)
const NORMAL_FLASH := Color(0.70, 0.82, 0.95)
const MISS_FLASH := Color(0.55, 0.25, 0.22)
const BG_DIM := Color(0.0, 0.0, 0.0, 0.35)

func _ready() -> void:
	custom_minimum_size = Vector2(START_RADIUS * 2 + 40, START_RADIUS * 2 + 60)
	size = custom_minimum_size
	mouse_filter = Control.MOUSE_FILTER_STOP

func run() -> String:
	_outer_radius = START_RADIUS
	_active = true
	_resolved = false
	_result = ""
	_flash_timer = 0.0
	_elapsed = 0.0
	set_process(true)
	queue_redraw()
	var result: String = await completed
	return result

func _process(delta: float) -> void:
	if _resolved:
		_flash_timer -= delta
		queue_redraw()
		if _flash_timer <= 0.0:
			set_process(false)
		return
	if not _active:
		return

	_elapsed += delta
	# Linear shrink
	_outer_radius = lerpf(START_RADIUS, 0.0, _elapsed / SHRINK_DURATION)

	if _outer_radius <= 0.0:
		_resolve("miss")
		return
	queue_redraw()

func _unhandled_input(event: InputEvent) -> void:
	if not _active or _resolved:
		return
	if event.is_action_pressed("ui_accept"):
		get_viewport().set_input_as_handled()
		var diff := absf(_outer_radius - TARGET_RADIUS)
		if diff <= CRITICAL_THRESHOLD:
			_resolve("critical")
		elif diff <= NORMAL_THRESHOLD:
			_resolve("normal")
		else:
			_resolve("miss")

func _resolve(result: String) -> void:
	_active = false
	_resolved = true
	_result = result
	_flash_timer = 0.55
	queue_redraw()
	await get_tree().create_timer(0.50).timeout
	completed.emit(result)

func _draw() -> void:
	var cx := size.x * 0.5
	var cy := size.y * 0.5 + 10.0
	var center := Vector2(cx, cy)

	# Dim backdrop circle
	draw_circle(center, START_RADIUS + 8, BG_DIM)

	# Prompt text
	draw_string(ThemeDB.fallback_font, Vector2(0, 18), prompt_text,
		HORIZONTAL_ALIGNMENT_CENTER, size.x, 16, prompt_color)

	# Target ring
	var target_c := TARGET_COLOR
	if _resolved and _result == "critical":
		target_c = CRITICAL_FLASH
	draw_arc(center, TARGET_RADIUS, 0, TAU, 48, target_c, 3.0)

	# Normal threshold ring (faint guide)
	if not _resolved:
		draw_arc(center, TARGET_RADIUS + NORMAL_THRESHOLD, 0, TAU, 48,
			Color(0.5, 0.5, 0.4, 0.15), 1.0)

	# Outer shrinking ring
	if not _resolved or _flash_timer > 0.0:
		var oc := OUTER_COLOR
		if _resolved:
			match _result:
				"critical": oc = CRITICAL_FLASH
				"normal": oc = NORMAL_FLASH
				"miss": oc = MISS_FLASH
		var r := maxf(_outer_radius, 1.0)
		draw_arc(center, r, 0, TAU, 48, oc, 3.5)

	# Result text
	if _resolved and _flash_timer > 0.0:
		var txt := ""
		var tc := Color.WHITE
		match _result:
			"critical":
				txt = "CRITICAL!"
				tc = CRITICAL_FLASH
			"normal":
				txt = "NORMAL"
				tc = NORMAL_FLASH
			"miss":
				txt = "MISS"
				tc = MISS_FLASH
		draw_string(ThemeDB.fallback_font, Vector2(0, cy + TARGET_RADIUS + 30), txt,
			HORIZONTAL_ALIGNMENT_CENTER, size.x, 22, tc)
