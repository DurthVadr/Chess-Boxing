class_name QTECross
extends Control

## QTE for Cross — two perpendicular timing bars forming a + shape.
## Both cursors sweep simultaneously (horizontal L→R, vertical T→B).
## Player presses when both cursors are near center.
## Result based on average closeness to center of both cursors.
## Returns: "perfect", "good", "partial", or "miss".

signal completed(result: String)

const ARM_LENGTH := 160.0
const ARM_THICKNESS := 22.0
const CURSOR_SIZE := 8.0

# Zone ratios (fraction of arm length from center)
const PERFECT_RATIO := 0.12    # very tight center zone
const GOOD_RATIO := 0.22       # decent zone
const PARTIAL_RATIO := 0.38    # wider zone

var cursor_speed := 480.0
var _h_cursor := 0.0          # 0 → ARM_LENGTH*2 (left to right)
var _v_cursor := 0.0          # 0 → ARM_LENGTH*2 (top to bottom)
var _active := false
var _resolved := false
var _waiting := false
var _result := ""
var _flash_timer := 0.0
var _intro_timer := 0.0
var _intro_scale := 0.0

var prompt_text := "CROSS!"
var prompt_color := Color(0.88, 0.36, 0.32)

# ── Palette ──
const BG_COLOR := Color(0.05, 0.04, 0.09, 0.92)
const BG_GLOW := Color(0.12, 0.08, 0.20, 0.50)
const BORDER_COLOR := Color(0.45, 0.35, 0.65, 0.9)
const PERFECT_ZONE := Color(0.90, 0.78, 0.28, 0.50)
const PERFECT_GLOW := Color(0.95, 0.85, 0.35, 0.20)
const GOOD_ZONE := Color(0.70, 0.65, 0.35, 0.30)
const PARTIAL_ZONE := Color(0.55, 0.50, 0.35, 0.20)
const MISS_TINT := Color(0.30, 0.15, 0.15, 0.15)
const CURSOR_COLOR := Color(0.98, 0.95, 0.88)
const CURSOR_GLOW_COL := Color(0.98, 0.92, 0.70, 0.35)
const PERFECT_FLASH := Color(0.95, 0.88, 0.35)
const GOOD_FLASH := Color(0.80, 0.88, 0.55)
const PARTIAL_FLASH := Color(0.70, 0.82, 0.95)
const MISS_FLASH := Color(0.60, 0.25, 0.22)
const TICK_COLOR := Color(0.40, 0.35, 0.55, 0.30)
const READY_KEY := Color(0.90, 0.82, 0.45)
const READY_HINT := Color(0.75, 0.70, 0.55, 0.85)
const CROSSHAIR_COLOR := Color(0.50, 0.45, 0.40, 0.12)

func _ready() -> void:
	var total := ARM_LENGTH * 2 + 60
	custom_minimum_size = Vector2(total, total + 40)
	size = custom_minimum_size
	mouse_filter = Control.MOUSE_FILTER_STOP

func run() -> String:
	_h_cursor = 0.0
	_v_cursor = 0.0
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

	_h_cursor += cursor_speed * delta
	_v_cursor += cursor_speed * delta * 0.85  # vertical slightly slower for variety
	var arm_full := ARM_LENGTH * 2.0
	if _h_cursor >= arm_full or _v_cursor >= arm_full:
		_resolve("miss")
		return
	queue_redraw()

func _unhandled_input(event: InputEvent) -> void:
	if not _active or _resolved:
		return
	if event.is_action_pressed("ui_accept"):
		get_viewport().set_input_as_handled()
		var arm_full := ARM_LENGTH * 2.0
		var center := ARM_LENGTH
		# Distance from center as ratio (0 = perfect center, 1 = edge)
		var h_dist := absf(_h_cursor - center) / ARM_LENGTH
		var v_dist := absf(_v_cursor - center) / ARM_LENGTH
		var avg_dist := (h_dist + v_dist) * 0.5

		if avg_dist <= PERFECT_RATIO:
			_resolve("perfect")
		elif avg_dist <= GOOD_RATIO:
			_resolve("good")
		elif avg_dist <= PARTIAL_RATIO:
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
	var cx := size.x * 0.5
	var cy := size.y * 0.5 - 5.0

	# ── Prompt text with bounce-in ──
	var prompt_scale := _ease_out_back(_intro_scale) if _waiting else 1.0
	var ps := int(18 * prompt_scale)
	if ps > 0:
		draw_string(ThemeDB.fallback_font, Vector2(0, cy - ARM_LENGTH - 20), prompt_text,
			HORIZONTAL_ALIGNMENT_CENTER, size.x, ps, prompt_color)

	# ── Active / resolved cross ──
	_draw_cross_shape(cx, cy, 1.0)

	# ── Cursors ──
	if not _resolved or _flash_timer > 0.0:
		var hx := cx - ARM_LENGTH + clampf(_h_cursor, 0.0, ARM_LENGTH * 2.0)
		var vy := cy - ARM_LENGTH + clampf(_v_cursor, 0.0, ARM_LENGTH * 2.0)

		var cc := CURSOR_COLOR
		if _resolved:
			match _result:
				"perfect": cc = PERFECT_FLASH
				"good": cc = GOOD_FLASH
				"partial": cc = PARTIAL_FLASH
				"miss": cc = MISS_FLASH

		# Horizontal cursor (vertical line on the horizontal bar)
		draw_rect(Rect2(hx - CURSOR_SIZE * 0.5, cy - ARM_THICKNESS * 0.5 - 4,
			CURSOR_SIZE, ARM_THICKNESS + 8), Color(cc, 0.2))
		draw_rect(Rect2(hx - CURSOR_SIZE * 0.4, cy - ARM_THICKNESS * 0.5 - 2,
			CURSOR_SIZE * 0.8, ARM_THICKNESS + 4), cc)

		# Vertical cursor (horizontal line on the vertical bar)
		draw_rect(Rect2(cx - ARM_THICKNESS * 0.5 - 4, vy - CURSOR_SIZE * 0.5,
			ARM_THICKNESS + 8, CURSOR_SIZE), Color(cc, 0.2))
		draw_rect(Rect2(cx - ARM_THICKNESS * 0.5 - 2, vy - CURSOR_SIZE * 0.4,
			ARM_THICKNESS + 4, CURSOR_SIZE * 0.8), cc)

		# Intersection highlight
		if not _resolved:
			draw_circle(Vector2(hx, vy), 5.0, Color(cc, 0.5))

	# ── Result label ──
	if _resolved and _flash_timer > 0.0:
		var txt := ""
		var tc := Color.WHITE
		match _result:
			"perfect":
				txt = "PERFECT!"
				tc = PERFECT_FLASH
			"good":
				txt = "GOOD!"
				tc = GOOD_FLASH
			"partial":
				txt = "OK"
				tc = PARTIAL_FLASH
			"miss":
				txt = "MISS"
				tc = MISS_FLASH
		var result_alpha := clampf(_flash_timer / 0.55, 0.0, 1.0)
		draw_string(ThemeDB.fallback_font, Vector2(0, cy + ARM_LENGTH + 28), txt,
			HORIZONTAL_ALIGNMENT_CENTER, size.x, 22, Color(tc, result_alpha))


func _draw_cross_shape(cx: float, cy: float, alpha: float) -> void:
	var half_t := ARM_THICKNESS * 0.5
	var perfect_px := ARM_LENGTH * PERFECT_RATIO
	var good_px := ARM_LENGTH * GOOD_RATIO
	var partial_px := ARM_LENGTH * PARTIAL_RATIO

	# ── Horizontal arm ──
	var h_rect := Rect2(cx - ARM_LENGTH, cy - half_t, ARM_LENGTH * 2, ARM_THICKNESS)
	# Glow
	draw_rect(Rect2(h_rect.position.x - 3, h_rect.position.y - 3,
		h_rect.size.x + 6, h_rect.size.y + 6), Color(BG_GLOW, BG_GLOW.a * alpha))
	# BG
	draw_rect(h_rect, Color(BG_COLOR, BG_COLOR.a * alpha))
	draw_rect(h_rect, Color(MISS_TINT, MISS_TINT.a * alpha))

	# ── Vertical arm ──
	var v_rect := Rect2(cx - half_t, cy - ARM_LENGTH, ARM_THICKNESS, ARM_LENGTH * 2)
	draw_rect(Rect2(v_rect.position.x - 3, v_rect.position.y - 3,
		v_rect.size.x + 6, v_rect.size.y + 6), Color(BG_GLOW, BG_GLOW.a * alpha))
	draw_rect(v_rect, Color(BG_COLOR, BG_COLOR.a * alpha))
	draw_rect(v_rect, Color(MISS_TINT, MISS_TINT.a * alpha))

	# ── Zones on horizontal arm (symmetric from center) ──
	# Partial
	draw_rect(Rect2(cx - partial_px, cy - half_t, partial_px * 2, ARM_THICKNESS),
		Color(PARTIAL_ZONE, PARTIAL_ZONE.a * alpha))
	# Good
	draw_rect(Rect2(cx - good_px, cy - half_t, good_px * 2, ARM_THICKNESS),
		Color(GOOD_ZONE, GOOD_ZONE.a * alpha))
	# Perfect glow + fill
	draw_rect(Rect2(cx - perfect_px - 2, cy - half_t - 2, perfect_px * 2 + 4, ARM_THICKNESS + 4),
		Color(PERFECT_GLOW, PERFECT_GLOW.a * alpha))
	draw_rect(Rect2(cx - perfect_px, cy - half_t, perfect_px * 2, ARM_THICKNESS),
		Color(PERFECT_ZONE, PERFECT_ZONE.a * alpha))

	# ── Zones on vertical arm ──
	draw_rect(Rect2(cx - half_t, cy - partial_px, ARM_THICKNESS, partial_px * 2),
		Color(PARTIAL_ZONE, PARTIAL_ZONE.a * alpha))
	draw_rect(Rect2(cx - half_t, cy - good_px, ARM_THICKNESS, good_px * 2),
		Color(GOOD_ZONE, GOOD_ZONE.a * alpha))
	draw_rect(Rect2(cx - half_t - 2, cy - perfect_px - 2, ARM_THICKNESS + 4, perfect_px * 2 + 4),
		Color(PERFECT_GLOW, PERFECT_GLOW.a * alpha))
	draw_rect(Rect2(cx - half_t, cy - perfect_px, ARM_THICKNESS, perfect_px * 2),
		Color(PERFECT_ZONE, PERFECT_ZONE.a * alpha))

	# ── Center intersection highlight ──
	draw_rect(Rect2(cx - half_t, cy - half_t, ARM_THICKNESS, ARM_THICKNESS),
		Color(PERFECT_ZONE, PERFECT_ZONE.a * alpha * 1.3))

	# ── Tick marks on horizontal ──
	for i in range(1, 8):
		var tx := cx - ARM_LENGTH + ARM_LENGTH * 2 * (float(i) / 8.0)
		draw_line(Vector2(tx, cy - half_t), Vector2(tx, cy + half_t),
			Color(TICK_COLOR, TICK_COLOR.a * alpha), 1.0)

	# ── Tick marks on vertical ──
	for i in range(1, 8):
		var ty := cy - ARM_LENGTH + ARM_LENGTH * 2 * (float(i) / 8.0)
		draw_line(Vector2(cx - half_t, ty), Vector2(cx + half_t, ty),
			Color(TICK_COLOR, TICK_COLOR.a * alpha), 1.0)

	# ── Crosshair lines through center ──
	draw_line(Vector2(cx - ARM_LENGTH, cy), Vector2(cx + ARM_LENGTH, cy),
		Color(CROSSHAIR_COLOR, CROSSHAIR_COLOR.a * alpha), 1.0)
	draw_line(Vector2(cx, cy - ARM_LENGTH), Vector2(cx, cy + ARM_LENGTH),
		Color(CROSSHAIR_COLOR, CROSSHAIR_COLOR.a * alpha), 1.0)

	# ── Borders ──
	draw_rect(h_rect, Color(BORDER_COLOR, BORDER_COLOR.a * alpha), false, 1.5)
	draw_rect(v_rect, Color(BORDER_COLOR, BORDER_COLOR.a * alpha), false, 1.5)


static func _ease_out_back(t: float) -> float:
	var c := 1.70158
	var t1 := t - 1.0
	return 1.0 + (c + 1.0) * t1 * t1 * t1 + c * t1 * t1
