class_name QTETimingDefense
extends Control

## Timing-based defense QTE for blocking opponent punches.
## Shows N consecutive arrows, each with a shrinking ring.
## Player presses the correct arrow when the ring is small.
## Returns per-punch block quality and overall damage multiplier.
##
## Block qualities per punch:
##   "perfect"  → 0% damage
##   "good"     → 30% damage
##   "weak"     → 70% damage
##   "miss"     → 100% damage

signal completed(result: Dictionary)
# result = { "block_qualities": Array[String], "damage_multiplier": float }

const RING_START := 60.0
const RING_PERFECT := 14.0    # ≤ this = perfect
const RING_GOOD := 24.0       # ≤ this = good
const RING_WEAK := 38.0       # ≤ this = weak
const SHRINK_SPEED := 55.0    # pixels per second shrink rate
const PUNCH_TIMEOUT := 2.0    # seconds before auto-miss

const DIRECTIONS := ["up", "down", "left", "right"]
const DIR_ACTIONS := {
	"up": "ui_up", "down": "ui_down",
	"left": "ui_left", "right": "ui_right",
}
const DIR_ARROWS := {
	"up": "▲", "down": "▼", "left": "◄", "right": "►",
}

# Palette
const BG_COLOR := Color(0.05, 0.04, 0.09, 0.95)
const BORDER_COLOR := Color(0.30, 0.45, 0.65, 0.8)
const RING_COLOR := Color(0.55, 0.50, 0.70, 0.8)
const RING_PERFECT_COL := Color(0.92, 0.80, 0.28, 0.9)
const RING_GOOD_COL := Color(0.35, 0.85, 0.45, 0.7)
const ARROW_COLOR := Color(0.85, 0.82, 0.75)
const ARROW_DIM := Color(0.4, 0.38, 0.35)
const RESULT_PERFECT := Color(0.92, 0.80, 0.28)
const RESULT_GOOD := Color(0.35, 0.85, 0.45)
const RESULT_WEAK := Color(0.70, 0.65, 0.50)
const RESULT_MISS := Color(0.85, 0.30, 0.25)
const GOLD := Color(0.92, 0.80, 0.28)

var _punches: Array = []        # Array of direction strings
var _current_punch: int = 0
var _ring_radius: float = RING_START
var _active := false
var _resolved := false
var _waiting := false
var _punch_timer := 0.0
var _block_qualities: Array = []
var _flash_timer := 0.0
var _last_result := ""
var _last_result_timer := 0.0

var prompt_text := "DEFEND!"
var prompt_color := Color(0.32, 0.52, 0.82)

func _ready() -> void:
	mouse_filter = MOUSE_FILTER_STOP

func run(punch_count: int = 3) -> Dictionary:
	_generate_punches(punch_count)
	_current_punch = 0
	_block_qualities.clear()
	_ring_radius = RING_START
	_punch_timer = 0.0
	_active = false
	_waiting = true
	_resolved = false
	_last_result = ""
	_last_result_timer = 0.0
	custom_minimum_size = Vector2(320, 160)
	size = custom_minimum_size
	set_process(true)
	queue_redraw()
	var result: Dictionary = await completed
	return result

func _generate_punches(count: int) -> void:
	_punches.clear()
	for i in count:
		_punches.append(DIRECTIONS[randi() % DIRECTIONS.size()])

func _process(delta: float) -> void:
	if _waiting:
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

	# Show last result briefly
	if _last_result_timer > 0.0:
		_last_result_timer -= delta
		queue_redraw()
		return

	# Shrink ring
	_ring_radius -= SHRINK_SPEED * delta
	_punch_timer += delta
	queue_redraw()

	# Auto-miss if ring shrinks to 0 or timeout
	if _ring_radius <= 0.0 or _punch_timer >= PUNCH_TIMEOUT:
		_register_block("miss")

func _unhandled_input(event: InputEvent) -> void:
	if _waiting:
		for dir in DIRECTIONS:
			if event.is_action_pressed(DIR_ACTIONS[dir]):
				get_viewport().set_input_as_handled()
				_waiting = false
				_active = true
				# First press only starts the block timing; do not evaluate it.
				_ring_radius = RING_START
				_punch_timer = 0.0
				_last_result_timer = 0.0
				return
		return

	if not _active or _resolved or _last_result_timer > 0.0:
		return

	for dir in DIRECTIONS:
		if event.is_action_pressed(DIR_ACTIONS[dir]):
			get_viewport().set_input_as_handled()
			_check_press(dir)
			return

func _check_press(dir: String) -> void:
	if _current_punch >= _punches.size():
		return

	var expected: String = _punches[_current_punch]
	if dir != expected:
		_register_block("miss")
		return

	# Correct direction — evaluate timing
	if _ring_radius <= RING_PERFECT:
		_register_block("perfect")
	elif _ring_radius <= RING_GOOD:
		_register_block("good")
	elif _ring_radius <= RING_WEAK:
		_register_block("weak")
	else:
		# Pressed too early
		_register_block("weak")

func _register_block(quality: String) -> void:
	_block_qualities.append(quality)
	_last_result = quality
	_last_result_timer = 0.35

	_current_punch += 1
	if _current_punch >= _punches.size():
		# All punches defended
		_last_result_timer = 0.0
		_finish()
	else:
		# Reset ring for next punch
		_ring_radius = RING_START
		_punch_timer = 0.0

func _finish() -> void:
	_active = false
	_resolved = true
	_flash_timer = 0.5

	var mult := _calc_damage_multiplier()
	queue_redraw()
	await get_tree().create_timer(0.45).timeout
	completed.emit({
		"block_qualities": _block_qualities,
		"damage_multiplier": mult,
	})

func _calc_damage_multiplier() -> float:
	if _block_qualities.is_empty():
		return 1.0
	var total := 0.0
	for q in _block_qualities:
		match q:
			"perfect": total += 0.0
			"good": total += 0.3
			"weak": total += 0.7
			"miss": total += 1.0
	return total / float(_block_qualities.size())

func _draw() -> void:
	var cx := size.x * 0.5
	var cy := size.y * 0.5 + 10.0
	var w := size.x - 20.0

	# Background
	draw_rect(Rect2(10, 0, w, size.y), BG_COLOR)
	draw_rect(Rect2(10, 0, w, size.y), BORDER_COLOR, false, 2.0)

	# Prompt
	draw_string(ThemeDB.fallback_font, Vector2(10, 20), prompt_text,
		HORIZONTAL_ALIGNMENT_CENTER, w, 16, prompt_color)

	# Punch counter
	var counter_text := "PUNCH %d/%d" % [mini(_current_punch + 1, _punches.size()), _punches.size()]
	if _resolved:
		counter_text = "DEFENDED!"
	draw_string(ThemeDB.fallback_font, Vector2(10, 36), counter_text,
		HORIZONTAL_ALIGNMENT_CENTER, w, 12, Color(0.6, 0.58, 0.52))

	# Draw punch indicators at top
	var indicator_y := 42.0
	var dot_spacing := 20.0
	var dots_start := cx - (float(_punches.size()) - 1.0) * dot_spacing * 0.5
	for i in _punches.size():
		var dx := dots_start + float(i) * dot_spacing
		var col := ARROW_DIM
		if i < _block_qualities.size():
			match _block_qualities[i]:
				"perfect": col = RESULT_PERFECT
				"good": col = RESULT_GOOD
				"weak": col = RESULT_WEAK
				"miss": col = RESULT_MISS
		elif i == _current_punch and not _resolved:
			col = ARROW_COLOR
		draw_circle(Vector2(dx, indicator_y), 5.0, col)

	if _resolved:
		_draw_final_result(cx, cy, w)
		return

	if _current_punch >= _punches.size():
		return

	# Current punch: ring + arrow
	var dir: String = _punches[_current_punch]
	var arrow: String = DIR_ARROWS[dir]

	# Target circle (static, small)
	draw_arc(Vector2(cx, cy), RING_PERFECT, 0, TAU, 32, RING_PERFECT_COL, 2.0)
	draw_arc(Vector2(cx, cy), RING_GOOD, 0, TAU, 32, RING_GOOD_COL, 1.5)

	if _active and _last_result_timer <= 0.0:
		# Shrinking ring
		var ring_col := RING_COLOR
		if _ring_radius <= RING_PERFECT:
			ring_col = RING_PERFECT_COL
		elif _ring_radius <= RING_GOOD:
			ring_col = RING_GOOD_COL
		draw_arc(Vector2(cx, cy), maxf(_ring_radius, 1.0), 0, TAU, 32, ring_col, 3.0)

	# Arrow character
	draw_string(ThemeDB.fallback_font, Vector2(cx - 16, cy + 12), arrow,
		HORIZONTAL_ALIGNMENT_CENTER, 32, 36, ARROW_COLOR)

	# Show last result flash
	if _last_result_timer > 0.0 and _last_result != "":
		var alpha := clampf(_last_result_timer / 0.35, 0.0, 1.0)
		var txt := ""
		var col := Color.WHITE
		match _last_result:
			"perfect":
				txt = "PERFECT!"
				col = RESULT_PERFECT
			"good":
				txt = "GOOD!"
				col = RESULT_GOOD
			"weak":
				txt = "WEAK"
				col = RESULT_WEAK
			"miss":
				txt = "MISS!"
				col = RESULT_MISS
		draw_string(ThemeDB.fallback_font, Vector2(10, size.y - 10), txt,
			HORIZONTAL_ALIGNMENT_CENTER, w, 20, Color(col, alpha))

	# Waiting prompt
	if _waiting:
		var pulse := 0.6 + 0.4 * sin(Time.get_ticks_msec() / 250.0)
		draw_string(ThemeDB.fallback_font, Vector2(10, size.y - 10),
			"► Press the arrow ◄", HORIZONTAL_ALIGNMENT_CENTER, w, 13,
			Color(GOLD, pulse))

func _draw_final_result(cx: float, cy: float, w: float) -> void:
	var mult := _calc_damage_multiplier()
	var txt := ""
	var col := Color.WHITE
	if mult <= 0.05:
		txt = "PERFECT BLOCK!"
		col = RESULT_PERFECT
	elif mult <= 0.35:
		txt = "SOLID BLOCK!"
		col = RESULT_GOOD
	elif mult <= 0.65:
		txt = "PARTIAL BLOCK"
		col = RESULT_WEAK
	else:
		txt = "GUARD BROKEN!"
		col = RESULT_MISS

	var alpha := clampf(_flash_timer / 0.5, 0.0, 1.0)
	draw_string(ThemeDB.fallback_font, Vector2(10, cy + 10), txt,
		HORIZONTAL_ALIGNMENT_CENTER, w, 24, Color(col, alpha))

	var pct_text := "%d%% blocked" % int((1.0 - mult) * 100.0)
	draw_string(ThemeDB.fallback_font, Vector2(10, cy + 30), pct_text,
		HORIZONTAL_ALIGNMENT_CENTER, w, 14, Color(col, alpha * 0.7))
