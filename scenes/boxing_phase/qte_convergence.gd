class_name QTEConvergence
extends Control

## QTE for Hook / Uppercut — two concentric circles.
## Shows "ready" prompt and waits for player press, THEN outer ring shrinks.
## Press ui_accept when rings align.
## Returns: "critical", "normal", or "miss".

signal completed(result: String)

const TARGET_RADIUS := 28.0
const START_RADIUS := 120.0
const SHRINK_DURATION := 1.1

const CRITICAL_THRESHOLD := 8.0
const NORMAL_THRESHOLD := 22.0

var _outer_radius := START_RADIUS
var _active := false
var _resolved := false
var _waiting := false
var _result := ""
var _flash_timer := 0.0
var _elapsed := 0.0
var _intro_timer := 0.0
var _intro_scale := 0.0

var prompt_text := "STRIKE!"
var prompt_color := Color(0.88, 0.36, 0.32)

# ── Palette ──
const TARGET_COLOR := Color(0.90, 0.78, 0.28, 0.50)
const TARGET_GLOW := Color(0.95, 0.85, 0.35, 0.15)
const OUTER_COLOR := Color(0.95, 0.30, 0.25, 0.75)
const OUTER_TRAIL := Color(0.85, 0.25, 0.20, 0.12)
const CRITICAL_FLASH := Color(1.0, 0.90, 0.30)
const NORMAL_FLASH := Color(0.70, 0.82, 0.95)
const MISS_FLASH := Color(0.55, 0.25, 0.22)
const BG_DIM := Color(0.0, 0.0, 0.0, 0.40)
const RING_GUIDE := Color(0.5, 0.5, 0.4, 0.12)
const READY_KEY := Color(0.90, 0.82, 0.45)
const READY_HINT := Color(0.75, 0.70, 0.55, 0.85)
const CROSSHAIR := Color(0.60, 0.55, 0.45, 0.18)

func _ready() -> void:
	custom_minimum_size = Vector2(START_RADIUS * 2 + 40, START_RADIUS * 2 + 60)
	size = custom_minimum_size
	mouse_filter = Control.MOUSE_FILTER_STOP

func run() -> String:
	_outer_radius = START_RADIUS
	_active = false
	_resolved = false
	_waiting = true
	_result = ""
	_flash_timer = 0.0
	_elapsed = 0.0
	_intro_timer = 0.0
	_intro_scale = 0.0
	set_process(true)
	queue_redraw()
	var result: String = await completed
	return result

func _process(delta: float) -> void:
	if _waiting:
		_intro_timer += delta
		if _intro_scale < 1.0:
			_intro_scale = minf(1.0, _intro_scale + delta * 4.5)
		queue_redraw()
		return

	if _resolved:
		_flash_timer -= delta
		queue_redraw()
		if _flash_timer <= 0.0:
			set_process(false)
		return
	if not _active:
		return

	_elapsed += delta
	_outer_radius = lerpf(START_RADIUS, 0.0, _elapsed / SHRINK_DURATION)

	if _outer_radius <= 0.0:
		_resolve("miss")
		return
	queue_redraw()

func _unhandled_input(event: InputEvent) -> void:
	if _waiting:
		if event.is_action_pressed("ui_accept"):
			get_viewport().set_input_as_handled()
			_waiting = false
			_active = true
			queue_redraw()
		return

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

	# Dim backdrop
	draw_circle(center, START_RADIUS + 12, BG_DIM)

	# Prompt text with bounce-in
	var prompt_s := _ease_out_back(_intro_scale) if _waiting else 1.0
	var ps := int(18 * prompt_s)
	if ps > 0:
		draw_string(ThemeDB.fallback_font, Vector2(0, 20), prompt_text,
			HORIZONTAL_ALIGNMENT_CENTER, size.x, ps, prompt_color)

	# ── Waiting state ──
	if _waiting:
		# Show target ring (dimmed)
		draw_arc(center, TARGET_RADIUS, 0, TAU, 48, Color(TARGET_COLOR, 0.30), 3.0)
		# Show outer ring at starting position (dimmed)
		draw_arc(center, START_RADIUS, 0, TAU, 48, Color(OUTER_COLOR, 0.25), 2.0)
		# Crosshair
		_draw_crosshair(center, TARGET_RADIUS * 0.6, Color(CROSSHAIR, 0.20))

		# Pulsing prompt
		var pulse := 0.6 + 0.4 * sin(_intro_timer * 4.0)
		draw_string(ThemeDB.fallback_font, Vector2(0, cy + START_RADIUS + 24),
			"► Press SPACE ◄", HORIZONTAL_ALIGNMENT_CENTER, size.x, 15, Color(READY_KEY, pulse))
		draw_string(ThemeDB.fallback_font, Vector2(0, cy + START_RADIUS + 44),
			"Time the rings!", HORIZONTAL_ALIGNMENT_CENTER, size.x, 11, READY_HINT)
		return

	# ── Crosshair ──
	_draw_crosshair(center, TARGET_RADIUS * 0.6, CROSSHAIR)

	# Target ring glow
	draw_arc(center, TARGET_RADIUS + 4, 0, TAU, 48, TARGET_GLOW, 8.0)

	# Target ring
	var target_c := TARGET_COLOR
	if _resolved and _result == "critical":
		target_c = CRITICAL_FLASH
	draw_arc(center, TARGET_RADIUS, 0, TAU, 48, target_c, 3.0)

	# Normal threshold ring (faint guide)
	if not _resolved:
		draw_arc(center, TARGET_RADIUS + NORMAL_THRESHOLD, 0, TAU, 48, RING_GUIDE, 1.0)

	# Outer shrinking ring with trail
	if not _resolved or _flash_timer > 0.0:
		var oc := OUTER_COLOR
		if _resolved:
			match _result:
				"critical": oc = CRITICAL_FLASH
				"normal": oc = NORMAL_FLASH
				"miss": oc = MISS_FLASH
		var r := maxf(_outer_radius, 1.0)
		# Trail rings
		if not _resolved:
			draw_arc(center, r + 8, 0, TAU, 48, OUTER_TRAIL, 6.0)
			draw_arc(center, r + 3, 0, TAU, 48, Color(oc, oc.a * 0.3), 4.0)
		# Main ring
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
				txt = "HIT"
				tc = NORMAL_FLASH
			"miss":
				txt = "MISS"
				tc = MISS_FLASH
		var alpha := clampf(_flash_timer / 0.55, 0.0, 1.0)
		draw_string(ThemeDB.fallback_font, Vector2(0, cy + TARGET_RADIUS + 30), txt,
			HORIZONTAL_ALIGNMENT_CENTER, size.x, 22, Color(tc, alpha))


func _draw_crosshair(center: Vector2, half_len: float, col: Color) -> void:
	draw_line(center - Vector2(half_len, 0), center + Vector2(half_len, 0), col, 1.0)
	draw_line(center - Vector2(0, half_len), center + Vector2(0, half_len), col, 1.0)


static func _ease_out_back(t: float) -> float:
	var c := 1.70158
	var t1 := t - 1.0
	return 1.0 + (c + 1.0) * t1 * t1 * t1 + c * t1 * t1
