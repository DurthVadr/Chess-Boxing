class_name QTEKnightsLeap
extends Control

## QTE for defending against enemy attacks — directional arrow sequence.
## 2-3 random arrows spawn. Player must input the exact sequence within a
## time window. Returns: "perfect_defense" or "failed_defense".

signal completed(result: String)

const TIME_LIMIT := 1.2  # seconds to complete the sequence
const MIN_ARROWS := 2
const MAX_ARROWS := 3

var _sequence: Array = []        # e.g. ["up", "left", "down"]
var _input_index: int = 0
var _time_remaining := TIME_LIMIT
var _active := false
var _resolved := false
var _result := ""
var _flash_timer := 0.0

var prompt_text := "DEFEND!"
var prompt_color := Color(0.32, 0.52, 0.82)

# Directional mappings
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

const BG_COLOR := Color(0.06, 0.05, 0.10, 0.92)
const BORDER_COLOR := Color(0.30, 0.45, 0.65, 0.7)
const ARROW_PENDING := Color(0.60, 0.65, 0.72)
const ARROW_DONE := Color(0.35, 0.85, 0.45)
const ARROW_FAIL := Color(0.85, 0.30, 0.25)
const ARROW_ACTIVE := Color(0.95, 0.90, 0.40)
const SUCCESS_COLOR := Color(0.30, 0.85, 0.55)
const FAIL_COLOR := Color(0.85, 0.30, 0.25)

func _ready() -> void:
	custom_minimum_size = Vector2(300, 90)
	size = custom_minimum_size
	mouse_filter = Control.MOUSE_FILTER_STOP

func run() -> String:
	_generate_sequence()
	_input_index = 0
	_time_remaining = TIME_LIMIT
	_active = true
	_resolved = false
	_result = ""
	_flash_timer = 0.0
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
	if not _active or _resolved:
		return

	# Check each direction
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
	var oy := 36.0
	var w := size.x - 20.0
	var h := 48.0

	# Prompt
	draw_string(ThemeDB.fallback_font, Vector2(ox, oy - 8), prompt_text,
		HORIZONTAL_ALIGNMENT_CENTER, w, 15, prompt_color)

	# Background
	draw_rect(Rect2(ox, oy, w, h), BG_COLOR)
	draw_rect(Rect2(ox, oy, w, h), BORDER_COLOR, false, 2.0)

	# Timer bar at top
	if not _resolved:
		var pct := clampf(_time_remaining / TIME_LIMIT, 0.0, 1.0)
		var bar_color := Color(0.35, 0.70, 0.45) if pct > 0.3 else Color(0.85, 0.35, 0.25)
		draw_rect(Rect2(ox + 2, oy + 2, (w - 4) * pct, 4), bar_color)

	# Arrows
	var arrow_w := w / float(_sequence.size())
	for i in _sequence.size():
		var dir: String = _sequence[i]
		var arrow_str: String = DIR_ARROWS[dir]

		var col := ARROW_PENDING
		if _resolved:
			if _result == "perfect_defense":
				col = ARROW_DONE
			elif i < _input_index:
				col = ARROW_DONE
			else:
				col = ARROW_FAIL
		elif i < _input_index:
			col = ARROW_DONE
		elif i == _input_index:
			col = ARROW_ACTIVE

		var ax := ox + arrow_w * float(i) + arrow_w * 0.5
		var ay := oy + h * 0.5 + 8
		draw_string(ThemeDB.fallback_font, Vector2(ax - 12, ay), arrow_str,
			HORIZONTAL_ALIGNMENT_CENTER, 24, 28, col)

	# Result
	if _resolved and _flash_timer > 0.0:
		var txt := ""
		var tc := Color.WHITE
		if _result == "perfect_defense":
			txt = "BLOCKED!"
			tc = SUCCESS_COLOR
		else:
			txt = "HIT!"
			tc = FAIL_COLOR
		draw_string(ThemeDB.fallback_font, Vector2(ox, oy + h + 16), txt,
			HORIZONTAL_ALIGNMENT_CENTER, w, 20, tc)
