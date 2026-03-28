class_name QTEBar
extends Control

## Quick Time Event timing bar.
## A cursor sweeps left→right across a bar with a highlighted "sweet spot".
## Player presses ui_accept to land the cursor — "perfect" if in the sweet spot,
## "miss" otherwise.
##
## Usage:
##   var bar := QTEBar.new()
##   parent.add_child(bar)
##   var result: String = await bar.run()   # "perfect" or "miss"
##   bar.queue_free()

signal qte_finished(result: String)

# Layout
const BAR_WIDTH := 400.0
const BAR_HEIGHT := 24.0
const CURSOR_WIDTH := 6.0
const SWEET_SPOT_RATIO := 0.18   # 18% of bar is sweet spot

# Speed — pixels per second. Higher = harder
var cursor_speed := 600.0

# Visual colors
const BAR_BG := Color(0.08, 0.06, 0.12, 0.92)
const BAR_BORDER := Color(0.35, 0.30, 0.50, 0.8)
const SWEET_COLOR := Color(0.90, 0.78, 0.28, 0.55)
const SWEET_PERFECT_FLASH := Color(0.95, 0.88, 0.35, 0.85)
const CURSOR_COLOR := Color(0.95, 0.92, 0.85)
const MISS_COLOR := Color(0.55, 0.25, 0.22)

# State
var _cursor_x := 0.0
var _active := false
var _resolved := false
var _sweet_start := 0.0
var _sweet_end := 0.0
var _result_text := ""
var _flash_timer := 0.0

# Label shown above the bar ("ATTACK!" / "DEFEND!")
var prompt_text := "PRESS SPACE"
var prompt_color := Color(0.92, 0.80, 0.28)

func _ready() -> void:
	# Center self in parent
	custom_minimum_size = Vector2(BAR_WIDTH + 40, BAR_HEIGHT + 60)
	size = custom_minimum_size
	mouse_filter = Control.MOUSE_FILTER_STOP

	# Sweet spot centered
	_sweet_start = (BAR_WIDTH - BAR_WIDTH * SWEET_SPOT_RATIO) * 0.5
	_sweet_end = _sweet_start + BAR_WIDTH * SWEET_SPOT_RATIO

func run() -> String:
	_cursor_x = 0.0
	_active = true
	_resolved = false
	_result_text = ""
	_flash_timer = 0.0
	set_process(true)
	queue_redraw()

	var result: String = await qte_finished
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

	# If cursor runs off the right edge, it's an automatic miss
	if _cursor_x >= BAR_WIDTH:
		_resolve("miss")
		return

	queue_redraw()

func _unhandled_input(event: InputEvent) -> void:
	if not _active or _resolved:
		return
	if event.is_action_pressed("ui_accept"):
		get_viewport().set_input_as_handled()
		if _cursor_x >= _sweet_start and _cursor_x <= _sweet_end:
			_resolve("perfect")
		else:
			_resolve("miss")

func _resolve(result: String) -> void:
	_active = false
	_resolved = true
	_result_text = result
	_flash_timer = 0.55
	queue_redraw()

	# Brief hold so the player sees the result flash
	await get_tree().create_timer(0.5).timeout
	qte_finished.emit(result)

func _draw() -> void:
	var ox := 20.0   # horizontal padding
	var oy := 40.0   # vertical offset below prompt text

	# Prompt label
	draw_string(
		ThemeDB.fallback_font, Vector2(ox, oy - 10),
		prompt_text, HORIZONTAL_ALIGNMENT_CENTER, BAR_WIDTH,
		16, prompt_color
	)

	# Bar background
	var bar_rect := Rect2(ox, oy, BAR_WIDTH, BAR_HEIGHT)
	draw_rect(bar_rect, BAR_BG)

	# Sweet spot
	var sweet_rect := Rect2(ox + _sweet_start, oy, _sweet_end - _sweet_start, BAR_HEIGHT)
	var sweet_color := SWEET_COLOR
	if _resolved and _result_text == "perfect":
		sweet_color = SWEET_PERFECT_FLASH
	draw_rect(sweet_rect, sweet_color)

	# Bar border
	draw_rect(bar_rect, BAR_BORDER, false, 2.0)

	# Cursor
	if not _resolved or _flash_timer > 0.0:
		var cx := clampf(_cursor_x, 0.0, BAR_WIDTH)
		var cursor_color := CURSOR_COLOR
		if _resolved:
			cursor_color = SWEET_PERFECT_FLASH if _result_text == "perfect" else MISS_COLOR
		draw_rect(Rect2(ox + cx - CURSOR_WIDTH * 0.5, oy - 2, CURSOR_WIDTH, BAR_HEIGHT + 4), cursor_color)

	# Result text flash
	if _resolved and _flash_timer > 0.0:
		var txt := "PERFECT!" if _result_text == "perfect" else "MISS"
		var txt_color := Color(0.95, 0.85, 0.25) if _result_text == "perfect" else Color(0.6, 0.3, 0.25)
		draw_string(
			ThemeDB.fallback_font,
			Vector2(ox, oy + BAR_HEIGHT + 22),
			txt, HORIZONTAL_ALIGNMENT_CENTER, BAR_WIDTH,
			20, txt_color
		)
