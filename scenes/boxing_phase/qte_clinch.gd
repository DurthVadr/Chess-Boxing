class_name QTEClinch
extends Control

## QTE for Clinch — vertical tug-of-war meter.
## Shows "ready" prompt, waits for first ◄/► press, THEN meter activates.
## Marker starts at center and drifts down. Alternate ui_left / ui_right
## to push it to the top. Win = marker reaches top within time limit.
## Returns: "clinch_won" or "clinch_lost".

signal completed(result: String)

const METER_WIDTH := 36.0
const METER_HEIGHT := 160.0
const TIME_LIMIT := 2.5
const WIN_THRESHOLD := 0.92
const DRIFT_SPEED := 0.28
const PUSH_AMOUNT := 0.09

var _fill := 0.5
var _time_remaining := TIME_LIMIT
var _last_dir := ""
var _active := false
var _resolved := false
var _waiting := false
var _result := ""
var _flash_timer := 0.0
var _intro_timer := 0.0
var _intro_scale := 0.0

var prompt_text := "CLINCH! Mash ◄ ► !"
var prompt_color := Color(0.72, 0.65, 0.45)

# ── Palette ──
const BG_COLOR := Color(0.05, 0.04, 0.09, 0.95)
const BG_GLOW := Color(0.15, 0.12, 0.08, 0.50)
const BORDER_COLOR := Color(0.45, 0.40, 0.55, 0.8)
const FILL_LOW := Color(0.70, 0.30, 0.25)
const FILL_MID := Color(0.85, 0.70, 0.25)
const FILL_HIGH := Color(0.30, 0.80, 0.45)
const FILL_GLOW_LO := Color(0.70, 0.25, 0.20, 0.20)
const FILL_GLOW_HI := Color(0.30, 0.80, 0.45, 0.20)
const MARKER_COLOR := Color(0.95, 0.92, 0.85)
const WIN_COLOR := Color(0.35, 0.90, 0.50)
const LOSE_COLOR := Color(0.85, 0.30, 0.25)
const WIN_LINE_COLOR := Color(0.35, 0.85, 0.45, 0.45)
const TICK_COLOR := Color(0.35, 0.30, 0.50, 0.25)
const READY_KEY := Color(0.90, 0.82, 0.45)
const READY_HINT := Color(0.75, 0.70, 0.55, 0.85)

func _ready() -> void:
	custom_minimum_size = Vector2(METER_WIDTH + 90, METER_HEIGHT + 80)
	size = custom_minimum_size
	mouse_filter = Control.MOUSE_FILTER_STOP

func run() -> String:
	_fill = 0.5
	_time_remaining = TIME_LIMIT
	_last_dir = ""
	_active = false
	_resolved = false
	_waiting = true
	_result = ""
	_flash_timer = 0.0
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

	_fill = maxf(0.0, _fill - DRIFT_SPEED * delta)
	_time_remaining -= delta
	queue_redraw()

	if _fill >= WIN_THRESHOLD:
		_resolve("clinch_won")
		return
	if _time_remaining <= 0.0 or _fill <= 0.0:
		_resolve("clinch_lost")

func _unhandled_input(event: InputEvent) -> void:
	if _waiting:
		if event.is_action_pressed("ui_left") or event.is_action_pressed("ui_right"):
			get_viewport().set_input_as_handled()
			_waiting = false
			_active = true
			# Process the first press
			if event.is_action_pressed("ui_left"):
				_last_dir = "left"
			else:
				_last_dir = "right"
			_fill = minf(1.0, _fill + PUSH_AMOUNT)
			queue_redraw()
		return

	if not _active or _resolved:
		return

	if event.is_action_pressed("ui_left"):
		get_viewport().set_input_as_handled()
		if _last_dir != "left":
			_last_dir = "left"
			_fill = minf(1.0, _fill + PUSH_AMOUNT)
			queue_redraw()
	elif event.is_action_pressed("ui_right"):
		get_viewport().set_input_as_handled()
		if _last_dir != "right":
			_last_dir = "right"
			_fill = minf(1.0, _fill + PUSH_AMOUNT)
			queue_redraw()

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
	var meter_x := cx - METER_WIDTH * 0.5
	var meter_y := 48.0

	# ── Prompt with bounce-in ──
	var prompt_s := _ease_out_back(_intro_scale) if _waiting else 1.0
	var ps := int(15 * prompt_s)
	if ps > 0:
		draw_string(ThemeDB.fallback_font, Vector2(0, 32), prompt_text,
			HORIZONTAL_ALIGNMENT_CENTER, size.x, ps, prompt_color)

	# Outer glow
	draw_rect(Rect2(meter_x - 5, meter_y - 5, METER_WIDTH + 10, METER_HEIGHT + 10), BG_GLOW)

	# Meter background
	draw_rect(Rect2(meter_x, meter_y, METER_WIDTH, METER_HEIGHT), BG_COLOR)

	# Tick marks
	for i in range(1, 10):
		var ty := meter_y + METER_HEIGHT * (float(i) / 10.0)
		draw_line(Vector2(meter_x, ty), Vector2(meter_x + METER_WIDTH, ty), TICK_COLOR, 1.0)

	# Fill (bottom-up) with side glow
	var fill_h := METER_HEIGHT * clampf(_fill, 0.0, 1.0)
	var fill_color := FILL_LOW
	var fill_glow := FILL_GLOW_LO
	if _fill > 0.65:
		fill_color = FILL_HIGH
		fill_glow = FILL_GLOW_HI
	elif _fill > 0.35:
		fill_color = FILL_MID
		fill_glow = Color(0.85, 0.70, 0.25, 0.20)

	var fill_rect := Rect2(meter_x, meter_y + METER_HEIGHT - fill_h, METER_WIDTH, fill_h)
	# Side glow
	draw_rect(Rect2(fill_rect.position.x - 4, fill_rect.position.y,
		fill_rect.size.x + 8, fill_rect.size.y), fill_glow)
	# Fill
	draw_rect(fill_rect, fill_color)

	# Win line with label
	var win_y := meter_y + METER_HEIGHT * (1.0 - WIN_THRESHOLD)
	draw_line(Vector2(meter_x - 8, win_y), Vector2(meter_x + METER_WIDTH + 8, win_y), WIN_LINE_COLOR, 2.0)
	draw_string(ThemeDB.fallback_font, Vector2(meter_x + METER_WIDTH + 10, win_y + 4),
		"WIN", HORIZONTAL_ALIGNMENT_LEFT, 40, 9, Color(WIN_LINE_COLOR, 0.7))

	# Meter border
	draw_rect(Rect2(meter_x, meter_y, METER_WIDTH, METER_HEIGHT), BORDER_COLOR, false, 2.0)

	# Marker line at current fill level
	var marker_y := meter_y + METER_HEIGHT * (1.0 - clampf(_fill, 0.0, 1.0))
	var mc := MARKER_COLOR
	if _resolved:
		mc = WIN_COLOR if _result == "clinch_won" else LOSE_COLOR
	# Marker glow
	draw_line(Vector2(meter_x - 6, marker_y), Vector2(meter_x + METER_WIDTH + 6, marker_y),
		Color(mc, 0.25), 8.0)
	# Marker line
	draw_line(Vector2(meter_x - 5, marker_y), Vector2(meter_x + METER_WIDTH + 5, marker_y), mc, 3.0)
	# Marker endpoints
	draw_circle(Vector2(meter_x - 5, marker_y), 3.0, mc)
	draw_circle(Vector2(meter_x + METER_WIDTH + 5, marker_y), 3.0, mc)

	# Timer
	if _active and not _resolved:
		var timer_text := "%.1fs" % _time_remaining
		var timer_col := Color(0.6, 0.6, 0.55) if _time_remaining > 0.8 else LOSE_COLOR
		draw_string(ThemeDB.fallback_font, Vector2(0, meter_y + METER_HEIGHT + 20), timer_text,
			HORIZONTAL_ALIGNMENT_CENTER, size.x, 13, timer_col)

	# Key hint arrows (pulsing when active)
	if _active and not _resolved:
		var hint_y := meter_y + METER_HEIGHT + 38
		var pulse := 0.6 + 0.4 * sin(_intro_timer * 6.0) if not _active else 1.0
		var hint_color := Color(0.7, 0.65, 0.50, 0.8 * pulse)
		draw_string(ThemeDB.fallback_font, Vector2(0, hint_y), "◄  ►",
			HORIZONTAL_ALIGNMENT_CENTER, size.x, 20, hint_color)

	# ── Waiting state ──
	if _waiting:
		var pulse := 0.6 + 0.4 * sin(_intro_timer * 4.0)
		draw_string(ThemeDB.fallback_font, Vector2(0, meter_y + METER_HEIGHT + 22),
			"► Press ◄ or ► ◄", HORIZONTAL_ALIGNMENT_CENTER, size.x, 14, Color(READY_KEY, pulse))
		draw_string(ThemeDB.fallback_font, Vector2(0, meter_y + METER_HEIGHT + 40),
			"Mash to fill the meter!", HORIZONTAL_ALIGNMENT_CENTER, size.x, 10, READY_HINT)

	# Result text
	if _resolved and _flash_timer > 0.0:
		var txt := ""
		var tc := Color.WHITE
		if _result == "clinch_won":
			txt = "CLINCH WON!"
			tc = WIN_COLOR
		else:
			txt = "CLINCH LOST"
			tc = LOSE_COLOR
		var alpha := clampf(_flash_timer / 0.55, 0.0, 1.0)
		draw_string(ThemeDB.fallback_font, Vector2(0, meter_y + METER_HEIGHT + 38), txt,
			HORIZONTAL_ALIGNMENT_CENTER, size.x, 22, Color(tc, alpha))


static func _ease_out_back(t: float) -> float:
	var c := 1.70158
	var t1 := t - 1.0
	return 1.0 + (c + 1.0) * t1 * t1 * t1 + c * t1 * t1
