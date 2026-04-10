class_name QTEPendulum
extends Control

## QTE for Jab / Cross — horizontal timing bar.
## Shows a "ready" prompt, waits for player press, THEN cursor sweeps.
## Center = success_zone, edges = partial_zone.
## Returns: "perfect", "partial", or "miss".

signal completed(result: String)

const BAR_WIDTH := 380.0
const BAR_HEIGHT := 26.0
const CURSOR_W := 8.0
const BAR_RADIUS := 6.0

# Zone ratios (fraction of BAR_WIDTH)
const SUCCESS_RATIO := 0.14
const PARTIAL_RATIO := 0.12

var cursor_speed := 620.0
var _cursor_x := 0.0
var _active := false
var _resolved := false
var _waiting := false     # waiting for player to press start
var _result := ""
var _flash_timer := 0.0
var _intro_timer := 0.0   # pulsing prompt timer
var _intro_scale := 1.0

# Zone pixel boundaries (computed in _ready)
var _success_start := 0.0
var _success_end := 0.0
var _partial_left_start := 0.0
var _partial_right_end := 0.0

var prompt_text := "ATTACK!"
var prompt_color := Color(0.88, 0.36, 0.32)

# ── Palette ──
const BG_COLOR := Color(0.05, 0.04, 0.09, 0.95)
const BG_GLOW := Color(0.12, 0.08, 0.20, 0.60)
const BORDER_COLOR := Color(0.45, 0.35, 0.65, 0.9)
const SUCCESS_COLOR := Color(0.90, 0.78, 0.28, 0.50)
const SUCCESS_GLOW := Color(0.95, 0.85, 0.35, 0.25)
const PARTIAL_COLOR := Color(0.55, 0.50, 0.35, 0.28)
const MISS_ZONE_COLOR := Color(0.30, 0.15, 0.15, 0.18)
const CURSOR_COLOR := Color(0.98, 0.95, 0.88)
const CURSOR_GLOW := Color(0.98, 0.92, 0.70, 0.40)
const PERFECT_FLASH := Color(0.95, 0.88, 0.35)
const PARTIAL_FLASH := Color(0.70, 0.82, 0.95)
const MISS_FLASH := Color(0.60, 0.25, 0.22)
const TICK_COLOR := Color(0.40, 0.35, 0.55, 0.35)
const READY_COLOR := Color(0.75, 0.70, 0.55, 0.85)
const READY_KEY_COLOR := Color(0.90, 0.82, 0.45)

func _ready() -> void:
	custom_minimum_size = Vector2(BAR_WIDTH + 50, BAR_HEIGHT + 90)
	size = custom_minimum_size
	mouse_filter = Control.MOUSE_FILTER_STOP

	var center := BAR_WIDTH * 0.5
	var half_success := BAR_WIDTH * SUCCESS_RATIO * 0.5
	_success_start = center - half_success
	_success_end = center + half_success
	_partial_left_start = _success_start - BAR_WIDTH * PARTIAL_RATIO
	_partial_right_end = _success_end + BAR_WIDTH * PARTIAL_RATIO

func run() -> String:
	_cursor_x = 0.0
	_active = true
	_resolved = false
	_waiting = false
	_result = ""
	_flash_timer = 0.0
	_intro_timer = 0.0
	_intro_scale = 1.0
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

	_cursor_x += cursor_speed * delta
	if _cursor_x >= BAR_WIDTH:
		_resolve("miss")
		return
	queue_redraw()

func _unhandled_input(event: InputEvent) -> void:
	if not _active or _resolved:
		return
	if event.is_action_pressed("ui_accept"):
		get_viewport().set_input_as_handled()
		if _cursor_x >= _success_start and _cursor_x <= _success_end:
			_resolve("perfect")
		elif _cursor_x >= _partial_left_start and _cursor_x <= _partial_right_end:
			_resolve("partial")
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
	var ox := 25.0
	var oy := 46.0

	# ── Prompt text with bounce-in ──
	var prompt_scale := _ease_out_back(_intro_scale) if _waiting else 1.0
	var prompt_size := int(18 * prompt_scale)
	if prompt_size > 0:
		draw_string(ThemeDB.fallback_font, Vector2(ox, oy - 14), prompt_text,
			HORIZONTAL_ALIGNMENT_CENTER, BAR_WIDTH, prompt_size, prompt_color)

	# ── Active / resolved bar ──
	_draw_bar(ox, oy, 1.0)

	# Cursor
	if not _resolved or _flash_timer > 0.0:
		var cx := clampf(_cursor_x, 0.0, BAR_WIDTH)
		var cc := CURSOR_COLOR
		if _resolved:
			match _result:
				"perfect": cc = PERFECT_FLASH
				"partial": cc = PARTIAL_FLASH
				"miss": cc = MISS_FLASH

		# Cursor glow
		var glow_w := CURSOR_W * 3.0
		draw_rect(Rect2(ox + cx - glow_w * 0.5, oy - 4, glow_w, BAR_HEIGHT + 8),
			Color(cc, 0.20))
		# Cursor bar
		draw_rect(Rect2(ox + cx - CURSOR_W * 0.5, oy - 3, CURSOR_W, BAR_HEIGHT + 6), cc)
		# Cursor cap dots
		draw_circle(Vector2(ox + cx, oy - 3), 4.0, cc)
		draw_circle(Vector2(ox + cx, oy + BAR_HEIGHT + 3), 4.0, cc)

	# Result label
	if _resolved and _flash_timer > 0.0:
		var txt := ""
		var tc := Color.WHITE
		match _result:
			"perfect":
				txt = "PERFECT!"
				tc = PERFECT_FLASH
			"partial":
				txt = "GOOD"
				tc = PARTIAL_FLASH
			"miss":
				txt = "MISS"
				tc = MISS_FLASH
		var result_alpha := clampf(_flash_timer / 0.55, 0.0, 1.0)
		draw_string(ThemeDB.fallback_font, Vector2(ox, oy + BAR_HEIGHT + 28), txt,
			HORIZONTAL_ALIGNMENT_CENTER, BAR_WIDTH, 22, Color(tc, result_alpha))


func _draw_bar(ox: float, oy: float, alpha: float) -> void:
	var bar := Rect2(ox, oy, BAR_WIDTH, BAR_HEIGHT)

	# Outer glow
	draw_rect(Rect2(ox - 4, oy - 4, BAR_WIDTH + 8, BAR_HEIGHT + 8),
		Color(BG_GLOW, BG_GLOW.a * alpha))

	# Bar BG
	draw_rect(bar, Color(BG_COLOR, BG_COLOR.a * alpha))

	# Miss zone tint (full bar, underneath zones)
	draw_rect(Rect2(ox, oy, BAR_WIDTH, BAR_HEIGHT), Color(MISS_ZONE_COLOR, MISS_ZONE_COLOR.a * alpha))

	# Partial zones
	draw_rect(Rect2(ox + _partial_left_start, oy,
		_success_start - _partial_left_start, BAR_HEIGHT), Color(PARTIAL_COLOR, PARTIAL_COLOR.a * alpha))
	draw_rect(Rect2(ox + _success_end, oy,
		_partial_right_end - _success_end, BAR_HEIGHT), Color(PARTIAL_COLOR, PARTIAL_COLOR.a * alpha))

	# Success zone with glow
	var sc := SUCCESS_COLOR
	if _resolved and _result == "perfect":
		sc = PERFECT_FLASH
	draw_rect(Rect2(ox + _success_start - 3, oy - 3,
		_success_end - _success_start + 6, BAR_HEIGHT + 6), Color(SUCCESS_GLOW, SUCCESS_GLOW.a * alpha))
	draw_rect(Rect2(ox + _success_start, oy,
		_success_end - _success_start, BAR_HEIGHT), Color(sc, sc.a * alpha))

	# Tick marks along the bar
	for i in range(1, 10):
		var tx := BAR_WIDTH * (float(i) / 10.0)
		draw_line(Vector2(ox + tx, oy), Vector2(ox + tx, oy + BAR_HEIGHT),
			Color(TICK_COLOR, TICK_COLOR.a * alpha), 1.0)

	# Zone edge markers (bright lines at zone boundaries)
	for edge_x in [_partial_left_start, _success_start, _success_end, _partial_right_end]:
		draw_line(Vector2(ox + edge_x, oy - 2), Vector2(ox + edge_x, oy + BAR_HEIGHT + 2),
			Color(BORDER_COLOR, BORDER_COLOR.a * alpha), 1.5)

	# Border
	draw_rect(bar, Color(BORDER_COLOR, BORDER_COLOR.a * alpha), false, 2.0)


## Attempt an ease-out-back curve for bouncy intro
static func _ease_out_back(t: float) -> float:
	var c := 1.70158
	var t1 := t - 1.0
	return 1.0 + (c + 1.0) * t1 * t1 * t1 + c * t1 * t1
