class_name QTEClinch
extends Control

## QTE for Clinch — vertical tug-of-war meter.
## Marker starts at center and drifts down. Rapidly alternate ui_left / ui_right
## to push it to the top. Win = marker reaches top within time limit.
## Returns: "clinch_won" or "clinch_lost".

signal completed(result: String)

const METER_WIDTH := 36.0
const METER_HEIGHT := 160.0
const TIME_LIMIT := 2.5
const WIN_THRESHOLD := 0.92    # marker at 92% = win
const DRIFT_SPEED := 0.28      # downward drift per second (0→1 scale)
const PUSH_AMOUNT := 0.09      # upward push per correct press

var _fill := 0.5               # 0.0 = bottom (fail), 1.0 = top (win)
var _time_remaining := TIME_LIMIT
var _last_dir := ""             # tracks alternation: "left" or "right"
var _active := false
var _resolved := false
var _result := ""
var _flash_timer := 0.0

var prompt_text := "CLINCH! Mash ◄ ► !"
var prompt_color := Color(0.72, 0.65, 0.45)

const BG_COLOR := Color(0.06, 0.05, 0.10, 0.92)
const BORDER_COLOR := Color(0.40, 0.38, 0.50, 0.7)
const FILL_LOW := Color(0.70, 0.30, 0.25)
const FILL_MID := Color(0.85, 0.70, 0.25)
const FILL_HIGH := Color(0.30, 0.80, 0.45)
const MARKER_COLOR := Color(0.95, 0.92, 0.85)
const WIN_COLOR := Color(0.35, 0.90, 0.50)
const LOSE_COLOR := Color(0.85, 0.30, 0.25)
const WIN_LINE_COLOR := Color(0.35, 0.85, 0.45, 0.4)

func _ready() -> void:
	custom_minimum_size = Vector2(METER_WIDTH + 80, METER_HEIGHT + 70)
	size = custom_minimum_size
	mouse_filter = Control.MOUSE_FILTER_STOP

func run() -> String:
	_fill = 0.5
	_time_remaining = TIME_LIMIT
	_last_dir = ""
	_active = true
	_resolved = false
	_result = ""
	_flash_timer = 0.0
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

	# Drift downward
	_fill = maxf(0.0, _fill - DRIFT_SPEED * delta)
	_time_remaining -= delta
	queue_redraw()

	# Win check
	if _fill >= WIN_THRESHOLD:
		_resolve("clinch_won")
		return

	# Timeout or bottomed out
	if _time_remaining <= 0.0 or _fill <= 0.0:
		_resolve("clinch_lost")

func _unhandled_input(event: InputEvent) -> void:
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
	var meter_y := 44.0

	# Prompt
	draw_string(ThemeDB.fallback_font, Vector2(0, 30), prompt_text,
		HORIZONTAL_ALIGNMENT_CENTER, size.x, 14, prompt_color)

	# Meter background
	draw_rect(Rect2(meter_x, meter_y, METER_WIDTH, METER_HEIGHT), BG_COLOR)

	# Fill (bottom-up)
	var fill_h := METER_HEIGHT * clampf(_fill, 0.0, 1.0)
	var fill_color := FILL_LOW
	if _fill > 0.65:
		fill_color = FILL_HIGH
	elif _fill > 0.35:
		fill_color = FILL_MID
	draw_rect(Rect2(meter_x, meter_y + METER_HEIGHT - fill_h, METER_WIDTH, fill_h), fill_color)

	# Win line
	var win_y := meter_y + METER_HEIGHT * (1.0 - WIN_THRESHOLD)
	draw_line(Vector2(meter_x - 6, win_y), Vector2(meter_x + METER_WIDTH + 6, win_y), WIN_LINE_COLOR, 2.0)

	# Meter border
	draw_rect(Rect2(meter_x, meter_y, METER_WIDTH, METER_HEIGHT), BORDER_COLOR, false, 2.0)

	# Marker line at current fill level
	var marker_y := meter_y + METER_HEIGHT * (1.0 - clampf(_fill, 0.0, 1.0))
	var mc := MARKER_COLOR
	if _resolved:
		mc = WIN_COLOR if _result == "clinch_won" else LOSE_COLOR
	draw_line(Vector2(meter_x - 4, marker_y), Vector2(meter_x + METER_WIDTH + 4, marker_y), mc, 3.0)

	# Timer
	if not _resolved:
		var timer_text := "%.1fs" % _time_remaining
		draw_string(ThemeDB.fallback_font, Vector2(0, meter_y + METER_HEIGHT + 18), timer_text,
			HORIZONTAL_ALIGNMENT_CENTER, size.x, 12, Color(0.6, 0.6, 0.55))

	# Key hint arrows
	if not _resolved:
		var hint_y := meter_y + METER_HEIGHT + 34
		var hint_color := Color(0.7, 0.65, 0.50, 0.7)
		draw_string(ThemeDB.fallback_font, Vector2(0, hint_y), "◄  ►",
			HORIZONTAL_ALIGNMENT_CENTER, size.x, 18, hint_color)

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
		draw_string(ThemeDB.fallback_font, Vector2(0, meter_y + METER_HEIGHT + 34), txt,
			HORIZONTAL_ALIGNMENT_CENTER, size.x, 20, tc)
