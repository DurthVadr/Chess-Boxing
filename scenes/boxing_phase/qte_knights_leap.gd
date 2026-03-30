class_name QTEKnightsLeap
extends Control

## QTE for defending against enemy attacks — directional arrow sequence.
## Shows "ready" prompt with the arrow sequence visible, waits for player
## to press any direction to start, THEN the timer begins.
## Returns: "perfect_defense" or "failed_defense".

signal completed(result: String)

const TIME_LIMIT := 1.5
const MIN_ARROWS := 2
const MAX_ARROWS := 3

var _sequence: Array = []
var _input_index: int = 0
var _time_remaining := TIME_LIMIT
var _active := false
var _resolved := false
var _waiting := false
var _result := ""
var _flash_timer := 0.0
var _intro_timer := 0.0
var _intro_scale := 0.0

var prompt_text := "DEFEND!"
var prompt_color := Color(0.32, 0.52, 0.82)

const DIRECTIONS := ["up", "down", "left", "right"]
const DIR_ACTIONS := {
	"up": "ui_up",
	"down": "ui_down",
	"left": "ui_left",
	"right": "ui_right",
}
const DIR_ARROWS := {
	"up": "▲",
	"down": "▼",
	"left": "◄",
	"right": "►",
}

# ── Palette ──
const BG_COLOR := Color(0.05, 0.04, 0.09, 0.95)
const BG_GLOW := Color(0.08, 0.12, 0.25, 0.50)
const BORDER_COLOR := Color(0.30, 0.45, 0.65, 0.8)
const ARROW_PENDING := Color(0.55, 0.58, 0.68)
const ARROW_DONE := Color(0.35, 0.85, 0.45)
const ARROW_FAIL := Color(0.85, 0.30, 0.25)
const ARROW_ACTIVE := Color(0.95, 0.90, 0.40)
const ARROW_ACTIVE_GLOW := Color(0.95, 0.90, 0.40, 0.25)
const SUCCESS_COLOR := Color(0.30, 0.85, 0.55)
const FAIL_COLOR := Color(0.85, 0.30, 0.25)
const TIMER_OK := Color(0.35, 0.70, 0.45)
const TIMER_LOW := Color(0.85, 0.35, 0.25)
const READY_KEY := Color(0.90, 0.82, 0.45)
const READY_HINT := Color(0.75, 0.70, 0.55, 0.85)
const ARROW_BG := Color(0.08, 0.06, 0.15, 0.80)
const ARROW_BG_DONE := Color(0.06, 0.14, 0.06, 0.60)

func _ready() -> void:
	custom_minimum_size = Vector2(320, 110)
	size = custom_minimum_size
	mouse_filter = Control.MOUSE_FILTER_STOP

func run() -> String:
	_generate_sequence()
	_input_index = 0
	_time_remaining = TIME_LIMIT
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

func _generate_sequence() -> void:
	var count := randi_range(MIN_ARROWS, MAX_ARROWS)
	_sequence.clear()
	for i in count:
		_sequence.append(DIRECTIONS[randi() % DIRECTIONS.size()])

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

	_time_remaining -= delta
	queue_redraw()

	if _time_remaining <= 0.0:
		_resolve("failed_defense")

func _unhandled_input(event: InputEvent) -> void:
	if _waiting:
		# Any direction press starts the QTE
		for dir in DIRECTIONS:
			if event.is_action_pressed(DIR_ACTIONS[dir]):
				get_viewport().set_input_as_handled()
				_waiting = false
				_active = true
				# Also process this as the first input
				if _sequence[_input_index] == dir:
					_input_index += 1
					queue_redraw()
					if _input_index >= _sequence.size():
						_resolve("perfect_defense")
				else:
					_resolve("failed_defense")
				return
		return

	if not _active or _resolved:
		return

	for dir in DIRECTIONS:
		if event.is_action_pressed(DIR_ACTIONS[dir]):
			get_viewport().set_input_as_handled()
			if _sequence[_input_index] == dir:
				_input_index += 1
				queue_redraw()
				if _input_index >= _sequence.size():
					_resolve("perfect_defense")
			else:
				_resolve("failed_defense")
			return

func _resolve(result: String) -> void:
	_active = false
	_resolved = true
	_result = result
	_flash_timer = 0.55
	queue_redraw()
	await get_tree().create_timer(0.50).timeout
	completed.emit(result)

func _draw() -> void:
	var ox := 10.0
	var oy := 38.0
	var w := size.x - 20.0
	var h := 56.0

	# ── Prompt with bounce-in ──
	var prompt_s := _ease_out_back(_intro_scale) if _waiting else 1.0
	var ps := int(17 * prompt_s)
	if ps > 0:
		draw_string(ThemeDB.fallback_font, Vector2(ox, oy - 10), prompt_text,
			HORIZONTAL_ALIGNMENT_CENTER, w, ps, prompt_color)

	# Outer glow
	draw_rect(Rect2(ox - 3, oy - 3, w + 6, h + 6), BG_GLOW)

	# Background
	draw_rect(Rect2(ox, oy, w, h), BG_COLOR)

	# Timer bar at top
	if _active and not _resolved:
		var pct := clampf(_time_remaining / TIME_LIMIT, 0.0, 1.0)
		var bar_color := TIMER_OK if pct > 0.3 else TIMER_LOW
		draw_rect(Rect2(ox + 2, oy + 2, (w - 4) * pct, 5), bar_color)
		# Timer glow when low
		if pct <= 0.3:
			draw_rect(Rect2(ox + 2, oy + 2, (w - 4) * pct, 5), Color(TIMER_LOW, 0.3))

	# Border
	draw_rect(Rect2(ox, oy, w, h), BORDER_COLOR, false, 2.0)

	# ── Arrow slots ──
	var arrow_w := w / float(_sequence.size())
	var slot_size := minf(arrow_w - 12, 40.0)

	for i in _sequence.size():
		var dir: String = _sequence[i]
		var arrow_str: String = DIR_ARROWS[dir]

		var ax := ox + arrow_w * float(i) + arrow_w * 0.5
		var ay := oy + h * 0.5

		# Arrow background box
		var slot_rect := Rect2(ax - slot_size * 0.5, ay - slot_size * 0.5 + 2, slot_size, slot_size)
		var slot_bg := ARROW_BG
		var col := ARROW_PENDING

		if _resolved:
			if _result == "perfect_defense":
				col = ARROW_DONE
				slot_bg = ARROW_BG_DONE
			elif i < _input_index:
				col = ARROW_DONE
				slot_bg = ARROW_BG_DONE
			else:
				col = ARROW_FAIL
		elif i < _input_index:
			col = ARROW_DONE
			slot_bg = ARROW_BG_DONE
		elif i == _input_index and _active:
			col = ARROW_ACTIVE
			# Glow behind active arrow
			draw_rect(Rect2(slot_rect.position - Vector2(4, 4),
				slot_rect.size + Vector2(8, 8)), ARROW_ACTIVE_GLOW)

		draw_rect(slot_rect, slot_bg)
		draw_rect(slot_rect, Color(BORDER_COLOR, 0.4), false, 1.5)

		# Arrow character
		draw_string(ThemeDB.fallback_font, Vector2(ax - 14, ay + 10), arrow_str,
			HORIZONTAL_ALIGNMENT_CENTER, 28, 30, col)

	# ── Waiting: show "press a direction" ──
	if _waiting:
		var pulse := 0.6 + 0.4 * sin(_intro_timer * 4.0)
		draw_string(ThemeDB.fallback_font, Vector2(ox, oy + h + 18),
			"► Press the first arrow ◄", HORIZONTAL_ALIGNMENT_CENTER, w, 13, Color(READY_KEY, pulse))

	# ── Result ──
	if _resolved and _flash_timer > 0.0:
		var txt := ""
		var tc := Color.WHITE
		if _result == "perfect_defense":
			txt = "BLOCKED!"
			tc = SUCCESS_COLOR
		else:
			txt = "HIT!"
			tc = FAIL_COLOR
		var alpha := clampf(_flash_timer / 0.55, 0.0, 1.0)
		draw_string(ThemeDB.fallback_font, Vector2(ox, oy + h + 20), txt,
			HORIZONTAL_ALIGNMENT_CENTER, w, 22, Color(tc, alpha))


static func _ease_out_back(t: float) -> float:
	var c := 1.70158
	var t1 := t - 1.0
	return 1.0 + (c + 1.0) * t1 * t1 * t1 + c * t1 * t1
