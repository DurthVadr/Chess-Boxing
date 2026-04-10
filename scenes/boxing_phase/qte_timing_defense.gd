class_name QTETimingDefense
extends Control

## Guitar Hero-style scrolling lane defense QTE — chess-boxing themed.
## Notes (boxing gloves) scroll down 4 directional lanes styled as chessboard columns.
## Player presses the matching arrow when the note reaches the hit zone (the rope line).
## Supports pattern variety: singles, doubles (two at once), rapid bursts, zigzags.
##
## Block qualities per note:
##   "perfect"  → 0% damage   (PARRY!)
##   "good"     → 30% damage  (BLOCK!)
##   "weak"     → 70% damage  (GRAZE)
##   "miss"     → 100% damage (HIT!)

signal completed(result: Dictionary)
# result = { "block_qualities": Array[String], "damage_multiplier": float, "streak": int }

# Layout
const LANE_COUNT := 4
const LANE_WIDTH := 56.0
const LANE_GAP := 4.0
const HIT_ZONE_Y := 130.0
const NOTE_SPAWN_Y := -20.0
const NOTE_SIZE := 40.0
const WIDGET_HEIGHT := 170.0

# Timing (distance-based thresholds from hit zone center)
const PERFECT_DIST := 10.0
const GOOD_DIST := 22.0
const WEAK_DIST := 38.0

# Speed — starts slow, ramps to target over RAMP_DURATION seconds
const BASE_SCROLL_SPEED := 180.0
const START_SCROLL_SPEED := 90.0
const RAMP_DURATION := 1.2
const LEAD_IN_GAP := 80.0  # Extra blank space before first note
var scroll_speed := BASE_SCROLL_SPEED
var _target_scroll_speed := BASE_SCROLL_SPEED

# Directions mapped to lane indices
const LANE_DIRS := ["left", "up", "down", "right"]
const DIR_ACTIONS := {
	"left": "ui_left", "up": "ui_up",
	"down": "ui_down", "right": "ui_right",
}
# Boxing-themed directional icons (glove directions)
const DIR_ARROWS := {
	"left": "◄", "up": "▲", "down": "▼", "right": "►",
}
# Chess piece receptors — one per lane
const LANE_RECEPTORS := ["♜", "♞", "♝", "♛"]

# =============================================================================
# Chess-Boxing Palette
# =============================================================================

# Background — deep black from the game palette
const BG_COLOR := Color(0.05, 0.04, 0.08, 0.95)

# Chessboard lane colors — alternating dark indigo / deep purple
const LANE_DARK := Color(0.10, 0.08, 0.16, 0.85)    # Dark square
const LANE_LIGHT := Color(0.16, 0.13, 0.24, 0.7)     # Light square

# Lane separator — subtle gold thread (like board inlay)
const LANE_LINE_COLOR := Color(0.45, 0.38, 0.18, 0.3)

# Hit zone — boxing ring rope (gold/cream)
const ROPE_COLOR := Color(0.9, 0.75, 0.3, 0.6)         # Gold rope line
const ROPE_GLOW := Color(0.9, 0.75, 0.3, 0.12)         # Glow behind rope

# Per-lane note colors — boxing glove themed, jewel tones
const LANE_COLORS := [
	Color(0.28, 0.42, 0.78),   # Lane 0 (left)  — Blue corner
	Color(0.82, 0.30, 0.25),   # Lane 1 (up)    — Red corner
	Color(0.35, 0.72, 0.45),   # Lane 2 (down)  — Green (body shot)
	Color(0.78, 0.55, 0.20),   # Lane 3 (right) — Gold (power)
]

# Receptor colors — muted chess-piece tint per lane
const RECEPTOR_DIM := [
	Color(0.20, 0.30, 0.55, 0.45),
	Color(0.55, 0.20, 0.18, 0.45),
	Color(0.22, 0.48, 0.30, 0.45),
	Color(0.52, 0.38, 0.14, 0.45),
]

# Result feedback
const RESULT_PERFECT := Color(0.92, 0.80, 0.28)   # Gold
const RESULT_GOOD := Color(0.35, 0.72, 0.45)      # Green
const RESULT_WEAK := Color(0.60, 0.55, 0.42)      # Dull bronze
const RESULT_MISS := Color(0.82, 0.25, 0.22)      # Red

const GOLD := Color(0.92, 0.80, 0.28)
const CREAM := Color(0.95, 0.92, 0.82)

# Note data: { lane: int, y: float, hit: bool, quality: String }
var _notes: Array = []
var _block_qualities: Array = []
var _active := false
var _resolved := false
var _waiting := false
var _flash_timer := 0.0
var _streak := 0
var _max_streak := 0
var _last_result := ""
var _last_result_timer := 0.0
var _lane_flash := [0.0, 0.0, 0.0, 0.0]
var _total_notes := 0
var _combo_text_timer := 0.0
var _combo_text := ""
var _time := 0.0  # For animations

var prompt_text := "DEFEND!"
var prompt_color := Color(0.82, 0.30, 0.25)

var _font: Font       # Balatro — for text labels
var _sym_font: Font   # Fallback — for arrows and chess pieces

func _ready() -> void:
	mouse_filter = MOUSE_FILTER_STOP
	_font = load("res://assets/fonts/balatro.otf") as Font
	if _font == null:
		_font = ThemeDB.fallback_font
	_sym_font = ThemeDB.fallback_font

func run(punch_count: int = 3) -> Dictionary:
	_generate_note_pattern(punch_count)
	_total_notes = _notes.size()
	_block_qualities.clear()
	_active = true
	_waiting = false
	_resolved = false
	_streak = 0
	_max_streak = 0
	_last_result = ""
	_last_result_timer = 0.0
	_flash_timer = 0.0
	_combo_text_timer = 0.0
	_lane_flash = [0.0, 0.0, 0.0, 0.0]
	_time = 0.0
	_target_scroll_speed = scroll_speed
	scroll_speed = START_SCROLL_SPEED

	var total_width := LANE_COUNT * LANE_WIDTH + (LANE_COUNT - 1) * LANE_GAP + 40.0
	custom_minimum_size = Vector2(total_width, WIDGET_HEIGHT)
	size = custom_minimum_size

	set_process(true)
	queue_redraw()
	var result: Dictionary = await completed
	return result

## Dev / playtest — unblock await (perfect block, no damage).
func debug_force_complete() -> void:
	if _resolved:
		return
	_active = false
	_resolved = true
	set_process(false)
	var n := maxi(_notes.size(), 1)
	var bq: Array = []
	for i in n:
		bq.append("perfect")
	completed.emit({
		"block_qualities": bq,
		"damage_multiplier": 0.0,
		"streak": 0,
	})

# =============================================================================
# Pattern Generation
# =============================================================================

func _generate_note_pattern(punch_count: int) -> void:
	_notes.clear()
	var note_count: int
	var pattern_type: int
	match punch_count:
		1:  # Uppercut — 2-3 quick notes
			note_count = randi_range(2, 3)
			pattern_type = randi_range(0, 1)
		2:  # Cross — 4-5 notes with doubles
			note_count = randi_range(4, 5)
			pattern_type = randi_range(0, 2)
		_:  # Jab — 5-7 notes, all patterns
			note_count = randi_range(5, 7)
			pattern_type = randi_range(0, 3)

	var base_spacing := 65.0
	if punch_count >= 3:
		base_spacing = 55.0

	match pattern_type:
		0: _gen_cascade(note_count, base_spacing)
		1: _gen_with_doubles(note_count, base_spacing)
		2: _gen_burst(note_count, base_spacing)
		3: _gen_zigzag(note_count, base_spacing)

func _gen_cascade(count: int, spacing: float) -> void:
	var last_lane := -1
	for i in count:
		var lane := randi() % LANE_COUNT
		while lane == last_lane:
			lane = randi() % LANE_COUNT
		last_lane = lane
		_notes.append({"lane": lane, "y": NOTE_SPAWN_Y - LEAD_IN_GAP - i * spacing, "hit": false, "quality": ""})

func _gen_with_doubles(count: int, spacing: float) -> void:
	var i := 0
	var note_idx := 0
	while note_idx < count:
		if i > 0 and i % 3 == 0 and note_idx + 1 < count:
			var lane_a := randi() % LANE_COUNT
			var lane_b := (lane_a + randi_range(1, 3)) % LANE_COUNT
			var y_pos := NOTE_SPAWN_Y - LEAD_IN_GAP - i * spacing
			_notes.append({"lane": lane_a, "y": y_pos, "hit": false, "quality": ""})
			_notes.append({"lane": lane_b, "y": y_pos, "hit": false, "quality": ""})
			note_idx += 2
		else:
			var lane := randi() % LANE_COUNT
			_notes.append({"lane": lane, "y": NOTE_SPAWN_Y - LEAD_IN_GAP - i * spacing, "hit": false, "quality": ""})
			note_idx += 1
		i += 1

func _gen_burst(count: int, spacing: float) -> void:
	var burst_lane := randi() % LANE_COUNT
	var burst_count := mini(3, count)
	var tight_spacing := spacing * 0.6
	for i in burst_count:
		var lane := burst_lane if i % 2 == 0 else (burst_lane + 1) % LANE_COUNT
		_notes.append({"lane": lane, "y": NOTE_SPAWN_Y - LEAD_IN_GAP - i * tight_spacing, "hit": false, "quality": ""})
	var offset_y := burst_count * tight_spacing + spacing
	for i in range(burst_count, count):
		var lane := randi() % LANE_COUNT
		_notes.append({"lane": lane, "y": NOTE_SPAWN_Y - LEAD_IN_GAP - offset_y - (i - burst_count) * spacing, "hit": false, "quality": ""})

func _gen_zigzag(count: int, spacing: float) -> void:
	var lane_a := randi() % LANE_COUNT
	var lane_b := (lane_a + randi_range(1, 3)) % LANE_COUNT
	for i in count:
		var lane := lane_a if i % 2 == 0 else lane_b
		_notes.append({"lane": lane, "y": NOTE_SPAWN_Y - LEAD_IN_GAP - i * spacing, "hit": false, "quality": ""})

# =============================================================================
# Processing
# =============================================================================

func _process(delta: float) -> void:
	_time += delta

	if _resolved:
		_flash_timer -= delta
		queue_redraw()
		if _flash_timer <= 0.0:
			set_process(false)
		return

	if not _active:
		return

	for i in LANE_COUNT:
		_lane_flash[i] = maxf(0.0, _lane_flash[i] - delta * 4.0)

	if _combo_text_timer > 0.0:
		_combo_text_timer -= delta
	if _last_result_timer > 0.0:
		_last_result_timer -= delta

	# Ramp scroll speed from slow start to target
	if _time < RAMP_DURATION:
		scroll_speed = lerpf(START_SCROLL_SPEED, _target_scroll_speed, _time / RAMP_DURATION)
	elif scroll_speed != _target_scroll_speed:
		scroll_speed = _target_scroll_speed

	var all_done := true
	for note in _notes:
		if not note.hit:
			note.y += scroll_speed * delta
			all_done = false
			if note.y > HIT_ZONE_Y + WEAK_DIST + 10.0:
				note.hit = true
				note.quality = "miss"
				_block_qualities.append("miss")
				_streak = 0
				_last_result = "miss"
				_last_result_timer = 0.25
		else:
			note.y += scroll_speed * delta

	queue_redraw()

	if all_done and not _resolved:
		_finish()

func _unhandled_input(event: InputEvent) -> void:
	if not _active or _resolved:
		return

	for lane_idx in LANE_COUNT:
		var dir: String = LANE_DIRS[lane_idx]
		if event.is_action_pressed(DIR_ACTIONS[dir]):
			get_viewport().set_input_as_handled()
			_check_lane_press(lane_idx)
			return

func _check_lane_press(lane_idx: int) -> void:
	_lane_flash[lane_idx] = 1.0

	var best_note: Dictionary = {}
	var best_dist := 999.0
	for note in _notes:
		if note.hit or note.lane != lane_idx:
			continue
		var dist := absf(note.y - HIT_ZONE_Y)
		if dist < best_dist:
			best_dist = dist
			best_note = note

	if best_note.is_empty() or best_dist > WEAK_DIST + 5.0:
		return

	var quality: String
	if best_dist <= PERFECT_DIST:
		quality = "perfect"
	elif best_dist <= GOOD_DIST:
		quality = "good"
	elif best_dist <= WEAK_DIST:
		quality = "weak"
	else:
		quality = "miss"

	best_note.hit = true
	best_note.quality = quality
	_block_qualities.append(quality)

	if quality == "miss":
		_streak = 0
	else:
		_streak += 1
		_max_streak = maxi(_max_streak, _streak)

	_last_result = quality
	_last_result_timer = 0.3

	# Boxing announcer-style combo callouts
	if _streak >= 3 and quality != "miss":
		if _streak >= 7:
			_combo_text = "UNTOUCHABLE! x%d" % _streak
		elif _streak >= 5:
			_combo_text = "FLURRY! x%d" % _streak
		else:
			_combo_text = "COMBO x%d!" % _streak
		_combo_text_timer = 0.5

func _finish() -> void:
	_active = false
	_resolved = true
	_flash_timer = 0.6

	var mult := _calc_damage_multiplier()
	queue_redraw()
	await get_tree().create_timer(0.5).timeout
	completed.emit({
		"block_qualities": _block_qualities,
		"damage_multiplier": mult,
		"streak": _max_streak,
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

# =============================================================================
# Drawing
# =============================================================================

func _draw() -> void:
	var total_lanes_width := LANE_COUNT * LANE_WIDTH + (LANE_COUNT - 1) * LANE_GAP
	var x_offset := (size.x - total_lanes_width) * 0.5

	# --- Background: deep black ring canvas ---
	draw_rect(Rect2(Vector2.ZERO, size), BG_COLOR)

	# --- Chessboard lane columns ---
	for i in LANE_COUNT:
		var lx := x_offset + i * (LANE_WIDTH + LANE_GAP)
		var lane_color := LANE_DARK if i % 2 == 0 else LANE_LIGHT
		# Flash lane on press — lights up in the lane's boxing color
		var flash: float = _lane_flash[i]
		if flash > 0.0:
			lane_color = lane_color.lerp(Color(LANE_COLORS[i] as Color, 0.25), flash)
		draw_rect(Rect2(lx, 0, LANE_WIDTH, size.y), lane_color)
		# Gold inlay separator
		if i > 0:
			var sep_x := lx - LANE_GAP * 0.5
			draw_line(Vector2(sep_x, 0), Vector2(sep_x, size.y), LANE_LINE_COLOR, 1.0)

	# --- Chessboard rank markers (decorative horizontal lines) ---
	var rank_spacing := size.y / 5.0
	for r in 4:
		var ry := rank_spacing * (r + 1)
		if absf(ry - HIT_ZONE_Y) > 15.0:  # Don't draw over the rope
			draw_line(Vector2(x_offset, ry), Vector2(x_offset + total_lanes_width, ry),
				Color(0.18, 0.15, 0.22, 0.15), 1.0)

	# --- Hit zone: boxing ring rope ---
	# Outer glow
	draw_rect(Rect2(x_offset, HIT_ZONE_Y - GOOD_DIST, total_lanes_width, GOOD_DIST * 2.0), ROPE_GLOW)
	# Inner perfect zone
	draw_rect(Rect2(x_offset, HIT_ZONE_Y - PERFECT_DIST, total_lanes_width, PERFECT_DIST * 2.0),
		Color(ROPE_COLOR, 0.18))
	# Rope lines (double rope like a real ring)
	draw_line(Vector2(x_offset, HIT_ZONE_Y - 1), Vector2(x_offset + total_lanes_width, HIT_ZONE_Y - 1),
		ROPE_COLOR, 2.0)
	draw_line(Vector2(x_offset, HIT_ZONE_Y + 3), Vector2(x_offset + total_lanes_width, HIT_ZONE_Y + 3),
		Color(ROPE_COLOR, 0.35), 1.0)

	# --- Receptors: chess piece per lane ---
	for i in LANE_COUNT:
		var lx := x_offset + i * (LANE_WIDTH + LANE_GAP)
		var cx := lx + LANE_WIDTH * 0.5
		var flash: float = _lane_flash[i]

		# Receptor square (chessboard tile feel)
		var rec_half := NOTE_SIZE * 0.5 + 2.0
		var rec_rect := Rect2(cx - rec_half, HIT_ZONE_Y - rec_half, rec_half * 2.0, rec_half * 2.0)
		var rec_bg: Color = (RECEPTOR_DIM[i] as Color).lerp(Color(LANE_COLORS[i] as Color, 0.5), flash)
		draw_rect(rec_rect, rec_bg)

		# Chess piece symbol in receptor
		var piece: String = LANE_RECEPTORS[i]
		var piece_col: Color = Color(CREAM, 0.25 + flash * 0.6)
		draw_string(_sym_font, Vector2(cx - 8, HIT_ZONE_Y + 8), piece,
			HORIZONTAL_ALIGNMENT_LEFT, 20, 22, piece_col)

		# Receptor border — glows on press
		if flash > 0.0:
			var glow_col := Color(LANE_COLORS[i] as Color, flash * 0.8)
			_draw_rect_border(rec_rect, glow_col, 2.0)

	# --- Prompt label at top ---
	draw_string(_font, Vector2(0, 14), prompt_text,
		HORIZONTAL_ALIGNMENT_CENTER, size.x, 13, prompt_color)

	# --- Draw notes (boxing gloves scrolling down) ---
	for note in _notes:
		if note.y > size.y + NOTE_SIZE or note.y < -NOTE_SIZE * 2:
			continue
		_draw_note(note, x_offset)

	# --- HUD overlay ---
	if not _resolved:
		_draw_hud(x_offset, total_lanes_width)

	if _resolved:
		_draw_final_result()


func _draw_note(note: Dictionary, x_offset: float) -> void:
	var i: int = note.lane
	var lx := x_offset + i * (LANE_WIDTH + LANE_GAP)
	var cx := lx + LANE_WIDTH * 0.5
	var ny: float = note.y
	var lane_col: Color = LANE_COLORS[i] as Color

	if note.hit:
		# Resolved: burst ring in result color
		var fade := clampf(1.0 - (ny - HIT_ZONE_Y) / 40.0, 0.0, 1.0)
		if fade <= 0.0:
			return
		var result_col: Color
		match note.quality:
			"perfect": result_col = RESULT_PERFECT
			"good": result_col = RESULT_GOOD
			"weak": result_col = RESULT_WEAK
			_: result_col = RESULT_MISS
		var burst_r := NOTE_SIZE * 0.5 + (1.0 - fade) * 22.0
		draw_arc(Vector2(cx, ny), burst_r, 0, TAU, 16, Color(result_col, fade * 0.7), 2.5)
		# Inner flash
		if fade > 0.5:
			draw_circle(Vector2(cx, ny), burst_r * 0.3, Color(result_col, (fade - 0.5) * 0.4))
	else:
		# Active note: boxing glove tile
		var note_half := NOTE_SIZE * 0.5
		var note_rect := Rect2(cx - note_half, ny - note_half, NOTE_SIZE, NOTE_SIZE)

		# Intensify as it approaches the rope
		var dist_to_hit := absf(ny - HIT_ZONE_Y)
		var intensity := clampf(1.0 - dist_to_hit / 90.0, 0.0, 1.0)

		# Note body — lane-colored with increasing brightness
		var note_bg := Color(lane_col, 0.12 + intensity * 0.25)
		draw_rect(note_rect, note_bg)

		# Note border — boxing glove silhouette outline
		var border_col := Color(lane_col, 0.45 + intensity * 0.55)
		_draw_rect_border(note_rect, border_col, 2.0 + intensity)

		# Arrow direction on the note
		var arrow: String = DIR_ARROWS[LANE_DIRS[i]]
		var arrow_alpha := 0.5 + intensity * 0.5
		draw_string(_sym_font, Vector2(cx - 8, ny + 7), arrow,
			HORIZONTAL_ALIGNMENT_LEFT, 20, 22, Color(CREAM, arrow_alpha))

		# Glow trail behind the note (subtle)
		if intensity > 0.3:
			var trail_alpha := (intensity - 0.3) * 0.15
			draw_rect(Rect2(cx - note_half, ny - note_half - 8, NOTE_SIZE, 8),
				Color(lane_col, trail_alpha))


func _draw_hud(x_offset: float, _total_w: float) -> void:
	# Note counter (top-left) — styled like round counter
	var hit_count := _block_qualities.size()
	var counter_text := "%d/%d" % [hit_count, _total_notes]
	draw_string(_font, Vector2(4, 13), counter_text,
		HORIZONTAL_ALIGNMENT_LEFT, 60, 10, Color(0.5, 0.45, 0.38))

	# Streak (top-right) — boxing combo counter
	if _streak >= 2:
		var streak_col: Color
		if _streak >= 7:
			streak_col = RESULT_PERFECT  # Gold — untouchable
		elif _streak >= 5:
			streak_col = LANE_COLORS[1] as Color  # Red — on fire
		else:
			streak_col = RESULT_GOOD     # Green — building
		var streak_pulse := 1.0 + sin(_time * 6.0) * 0.1 if _streak >= 5 else 1.0
		draw_string(_font, Vector2(size.x - 70, 13), "x%d" % _streak,
			HORIZONTAL_ALIGNMENT_RIGHT, 66, int(13 * streak_pulse), streak_col)

	# Last result flash (bottom center)
	if _last_result_timer > 0.0 and _last_result != "":
		var alpha := clampf(_last_result_timer / 0.3, 0.0, 1.0)
		var txt := ""
		var col := Color.WHITE
		match _last_result:
			"perfect":
				txt = "PARRY!"
				col = RESULT_PERFECT
			"good":
				txt = "BLOCK!"
				col = RESULT_GOOD
			"weak":
				txt = "GRAZE"
				col = RESULT_WEAK
			"miss":
				txt = "HIT!"
				col = RESULT_MISS
		draw_string(_font, Vector2(0, size.y - 6), txt,
			HORIZONTAL_ALIGNMENT_CENTER, size.x, 16, Color(col, alpha))

	# Combo callout (above result)
	if _combo_text_timer > 0.0:
		var alpha := clampf(_combo_text_timer / 0.5, 0.0, 1.0)
		var combo_col := GOLD if _streak >= 5 else RESULT_GOOD
		draw_string(_font, Vector2(0, size.y - 22), _combo_text,
			HORIZONTAL_ALIGNMENT_CENTER, size.x, 12, Color(combo_col, alpha))


func _draw_final_result() -> void:
	var mult := _calc_damage_multiplier()
	var txt := ""
	var col := Color.WHITE
	# Chess-boxing themed result text
	if mult <= 0.05:
		txt = "CHECKMATE BLOCK!"
		col = RESULT_PERFECT
	elif mult <= 0.35:
		txt = "SOLID GUARD!"
		col = RESULT_GOOD
	elif mult <= 0.65:
		txt = "PARTIAL GUARD"
		col = RESULT_WEAK
	else:
		txt = "GUARD BROKEN!"
		col = RESULT_MISS

	var alpha := clampf(_flash_timer / 0.6, 0.0, 1.0)

	# Darkened overlay
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.04, 0.03, 0.07, 0.6 * alpha))

	var cy := size.y * 0.35

	# Chess piece decorative flankers
	draw_string(_sym_font, Vector2(8, cy + 6), "♛",
		HORIZONTAL_ALIGNMENT_LEFT, 20, 20, Color(CREAM, alpha * 0.2))
	draw_string(_sym_font, Vector2(size.x - 24, cy + 6), "♛",
		HORIZONTAL_ALIGNMENT_LEFT, 20, 20, Color(CREAM, alpha * 0.2))

	# Main result text
	draw_string(_font, Vector2(0, cy), txt,
		HORIZONTAL_ALIGNMENT_CENTER, size.x, 20, Color(col, alpha))

	# Percentage blocked
	var pct_text := "%d%% blocked" % int((1.0 - mult) * 100.0)
	draw_string(_font, Vector2(0, cy + 20), pct_text,
		HORIZONTAL_ALIGNMENT_CENTER, size.x, 12, Color(col, alpha * 0.7))

	# Streak display
	if _max_streak >= 3:
		var streak_text := "Best combo: %d" % _max_streak
		draw_string(_font, Vector2(0, cy + 36), streak_text,
			HORIZONTAL_ALIGNMENT_CENTER, size.x, 10, Color(GOLD, alpha * 0.5))


func _draw_rect_border(rect: Rect2, color: Color, width: float) -> void:
	# Top
	draw_line(rect.position, Vector2(rect.end.x, rect.position.y), color, width)
	# Bottom
	draw_line(Vector2(rect.position.x, rect.end.y), rect.end, color, width)
	# Left
	draw_line(rect.position, Vector2(rect.position.x, rect.end.y), color, width)
	# Right
	draw_line(Vector2(rect.end.x, rect.position.y), rect.end, color, width)
