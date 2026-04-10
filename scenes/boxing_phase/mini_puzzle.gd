class_name MiniPuzzle
extends Control

## Compact 1-move chess puzzle for the boxing phase.
## Solve the puzzle to land your punch. Fail = miss.
## Emits completed(result: Dictionary) when done.

signal completed(result: Dictionary)

var board_logic: ChessBoardLogic
var puzzle: Dictionary = {}
var _active := false
var _resolved := false
var _time_limit := 8.0
var _time_remaining := 8.0
var _selected_square := Vector2i(-1, -1)
var _square_buttons: Array = []  # 2D [row][col]
var _grid: GridContainer
var _timer_bar: ColorRect
var _timer_bg: Control
var _prompt_label: Label
var _turn_panel: PanelContainer
var _turn_icon: Label
var _turn_label: Label
var _status_label: Label
var _bg_panel: PanelContainer
var _valid_moves: Array[Vector2i] = []
var _intro_timer := 0.0
var _mistakes := 0
var _error_penalty := 2.0
var _last_moved_piece: String = ""  # Uppercase piece letter: P/N/B/R/Q/K

const SQ := 64
const LIGHT_SQ := Color(0.55, 0.45, 0.65)  # Base (overridden by neon animation)
const DARK_SQ := Color(0.22, 0.18, 0.32)  # Base (overridden by neon animation)
const NEON_MAGENTA := Color(0.9, 0.1, 0.7)
const NEON_CYAN := Color(0.1, 0.9, 0.85)
const NEON_PURPLE := Color(0.6, 0.1, 0.95)
const SELECTED := Color(0.9, 0.75, 0.2, 0.85)
const CORRECT_COL := Color(0.3, 0.85, 0.4, 0.6)
const WRONG_COL := Color(0.85, 0.2, 0.2, 0.7)
const W_PIECE := Color(0.98, 0.95, 0.85)
const B_PIECE := Color(0.12, 0.1, 0.15)
const GOLD := Color(0.92, 0.80, 0.28)
const BG := Color(0.06, 0.05, 0.10, 0.95)
const BORDER := Color(0.35, 0.30, 0.50, 0.8)

const PIECE_SYMBOLS := {
	"K": "♔", "Q": "♕", "R": "♖", "B": "♗", "N": "♘", "P": "♙",
	"k": "♚", "q": "♛", "r": "♜", "b": "♝", "n": "♞", "p": "♟",
}

const MOVE_DOT_COLOR := Color(0.9, 0.78, 0.3, 0.7)
const CAPTURE_RING_COLOR := Color(0.85, 0.30, 0.25, 0.85)

var _sym_font: Font  # Fallback font for chess piece Unicode glyphs

func _ready() -> void:
	mouse_filter = MOUSE_FILTER_STOP
	_sym_font = ThemeDB.fallback_font
	_build_ui()

func setup(p: Dictionary, time: float = 12.0, error_penalty: float = 2.0) -> void:
	puzzle = p
	_time_limit = time
	_time_remaining = time
	_error_penalty = maxf(error_penalty, 0.0)
	board_logic = ChessBoardLogic.new()
	board_logic.setup_puzzle(puzzle)
	_update_turn_label()
	_refresh_board()
	_active = true
	_resolved = false
	_selected_square = Vector2i(-1, -1)
	_intro_timer = 0.0
	_mistakes = 0
	_last_moved_piece = ""
	_status_label.text = "Your move!"
	_setup_neon_prompt()
	_status_label.add_theme_color_override("font_color", Color(0.7, 0.68, 0.6))
	set_process(true)

func run(p: Dictionary, time: float = 12.0, error_penalty: float = 2.0) -> Dictionary:
	setup(p, time, error_penalty)
	var result: Dictionary = await completed
	return result

## Dev / playtest — unblock await without the normal resolve delay.
func debug_force_complete() -> void:
	if _resolved:
		return
	_active = false
	_resolved = true
	set_process(false)
	var moved := _last_moved_piece if _last_moved_piece != "" else "P"
	var result := {
		"solved": true,
		"time_remaining": maxf(_time_remaining, 0.0),
		"solve_time": 0.0,
		"time_limit": _time_limit,
		"mistakes": _mistakes,
		"moved_piece": moved,
	}
	completed.emit(result)

func _process(delta: float) -> void:
	if not _active or _resolved:
		return

	_intro_timer += delta
	_time_remaining -= delta
	_time_remaining = maxf(_time_remaining, 0.0)

	# Update timer bar — rainbow cycle instead of static colors
	var pct := _time_remaining / _time_limit
	_timer_bar.anchor_right = pct
	var hue := fmod(Time.get_ticks_msec() / 1000.0 * 0.3 + pct * 2.0, 1.0)
	_timer_bar.color = Color.from_hsv(hue, 0.7, 0.9)

	# Animate neon board squares
	_animate_mini_neon_board()

	if _time_remaining <= 0.0:
		_resolve(false)

func _build_ui() -> void:
	# Dim: starts transparent, tweens to 0.72 alpha so fighters fade into bg.
	var dim := ColorRect.new()
	dim.color = Color(0.02, 0.02, 0.04, 0.0)
	dim.set_anchors_preset(PRESET_FULL_RECT)
	dim.mouse_filter = MOUSE_FILTER_STOP
	add_child(dim)
	var dim_tw := dim.create_tween()
	dim_tw.tween_property(dim, "color", Color(0.02, 0.02, 0.04, 0.72), 0.3)

	# Centered popup panel
	var center := CenterContainer.new()
	center.set_anchors_preset(PRESET_FULL_RECT)
	center.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(center)

	var bg := PanelContainer.new()
	bg.custom_minimum_size = Vector2(SQ * 8 + 32, SQ * 8 + 130)
	var bg_style := StyleBoxFlat.new()
	bg_style.bg_color = BG
	bg_style.border_width_left = 2
	bg_style.border_width_right = 2
	bg_style.border_width_top = 2
	bg_style.border_width_bottom = 2
	bg_style.border_color = BORDER
	bg_style.corner_radius_top_left = 8
	bg_style.corner_radius_top_right = 8
	bg_style.corner_radius_bottom_left = 8
	bg_style.corner_radius_bottom_right = 8
	bg_style.content_margin_left = 8
	bg_style.content_margin_right = 8
	bg_style.content_margin_top = 6
	bg_style.content_margin_bottom = 6
	bg.add_theme_stylebox_override("panel", bg_style)
	bg.mouse_filter = MOUSE_FILTER_STOP
	center.add_child(bg)
	_bg_panel = bg

	var root := VBoxContainer.new()
	root.alignment = BoxContainer.ALIGNMENT_CENTER
	root.add_theme_constant_override("separation", 4)
	bg.add_child(root)

	_prompt_label = Label.new()
	_prompt_label.text = "SOLVE TO PUNCH!"
	_prompt_label.add_theme_font_size_override("font_size", 18)
	_prompt_label.add_theme_color_override("font_color", GOLD)
	_prompt_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(_prompt_label)

	# Turn indicator with piece icon and colored background
	_turn_panel = PanelContainer.new()
	var turn_style := StyleBoxFlat.new()
	turn_style.corner_radius_top_left = 4
	turn_style.corner_radius_top_right = 4
	turn_style.corner_radius_bottom_left = 4
	turn_style.corner_radius_bottom_right = 4
	turn_style.content_margin_left = 10
	turn_style.content_margin_right = 10
	turn_style.content_margin_top = 4
	turn_style.content_margin_bottom = 4
	turn_style.border_width_left = 2
	turn_style.border_width_right = 2
	turn_style.border_width_top = 2
	turn_style.border_width_bottom = 2
	_turn_panel.add_theme_stylebox_override("panel", turn_style)
	root.add_child(_turn_panel)

	var turn_hbox := HBoxContainer.new()
	turn_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	turn_hbox.add_theme_constant_override("separation", 6)
	_turn_panel.add_child(turn_hbox)

	_turn_icon = Label.new()
	_turn_icon.add_theme_font_size_override("font_size", 18)
	_turn_icon.add_theme_font_override("font", _sym_font)
	turn_hbox.add_child(_turn_icon)

	_turn_label = Label.new()
	_turn_label.text = ""
	_turn_label.add_theme_font_size_override("font_size", 14)
	_turn_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	turn_hbox.add_child(_turn_label)

	# Timer bar
	_timer_bg = Control.new()
	_timer_bg.custom_minimum_size = Vector2(SQ * 8, 6)
	root.add_child(_timer_bg)

	var tbg := ColorRect.new()
	tbg.color = Color(0.1, 0.08, 0.15)
	tbg.set_anchors_preset(PRESET_FULL_RECT)
	_timer_bg.add_child(tbg)

	_timer_bar = ColorRect.new()
	_timer_bar.color = Color(0.35, 0.85, 0.45)
	_timer_bar.anchor_right = 1.0
	_timer_bar.anchor_bottom = 1.0
	_timer_bg.add_child(_timer_bar)

	# Board grid
	_grid = GridContainer.new()
	_grid.columns = 8
	_grid.add_theme_constant_override("h_separation", 0)
	_grid.add_theme_constant_override("v_separation", 0)
	root.add_child(_grid)

	_square_buttons = []
	for row in 8:
		var row_arr := []
		for col in 8:
			var btn := Button.new()
			btn.custom_minimum_size = Vector2(SQ, SQ)
			btn.focus_mode = FOCUS_NONE

			var is_light := (row + col) % 2 == 0
			var base := LIGHT_SQ if is_light else DARK_SQ

			var style := StyleBoxFlat.new()
			style.bg_color = base
			style.border_width_bottom = 1
			style.border_width_right = 1
			style.border_color = base.darkened(0.15)
			btn.add_theme_stylebox_override("normal", style)

			var hover := style.duplicate()
			hover.bg_color = base.lightened(0.12)
			hover.border_color = Color(0.9, 0.8, 0.3, 0.5)
			btn.add_theme_stylebox_override("hover", hover)
			btn.add_theme_stylebox_override("pressed", style.duplicate())
			btn.add_theme_stylebox_override("focus", StyleBoxEmpty.new())

			btn.add_theme_font_size_override("font_size", 36)
			btn.add_theme_font_override("font", _sym_font)
			btn.pressed.connect(_on_square.bind(row, col))
			_grid.add_child(btn)
			row_arr.append(btn)
		_square_buttons.append(row_arr)

	_status_label = Label.new()
	_status_label.text = ""
	_status_label.add_theme_font_size_override("font_size", 15)
	_status_label.add_theme_color_override("font_color", Color(0.7, 0.68, 0.6))
	_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(_status_label)

func _animate_mini_neon_board() -> void:
	if _square_buttons.is_empty():
		return
	var t := Time.get_ticks_msec() / 1000.0 * 0.2
	for row in 8:
		for col in 8:
			if _selected_square == Vector2i(col, row):
				continue
			var is_light := (row + col) % 2 == 0
			var phase := (row + col) * 0.3 + t
			var wave := sin(phase) * 0.5 + 0.5
			var base: Color
			if is_light:
				var neon := NEON_MAGENTA.lerp(NEON_CYAN, wave)
				base = LIGHT_SQ.lerp(neon * 0.4, 0.12)
			else:
				var neon := NEON_PURPLE.lerp(Color(0.05, 0.35, 0.45), wave)
				base = DARK_SQ.lerp(neon * 0.3, 0.1)
			var btn: Button = _square_buttons[row][col]
			var style: StyleBoxFlat = btn.get_theme_stylebox("normal")
			style.bg_color = base

func _setup_neon_prompt() -> void:
	var shader := load("res://assets/shaders/neon_text.gdshader") as Shader
	if shader and _prompt_label:
		var mat := ShaderMaterial.new()
		mat.shader = shader
		mat.set_shader_parameter("neon_color", Color(0.95, 0.85, 0.1, 1.0))
		mat.set_shader_parameter("glow_intensity", 1.0)
		mat.set_shader_parameter("pulse_speed", 1.2)
		mat.set_shader_parameter("rainbow_mode", true)
		_prompt_label.material = mat

func _update_turn_label() -> void:
	if _turn_label == null or board_logic == null:
		return
	var turn_style: StyleBoxFlat = _turn_panel.get_theme_stylebox("panel")
	var is_black := board_logic.active_color == "b"

	if is_black:
		_turn_icon.text = "♚"
		_turn_icon.add_theme_color_override("font_color", Color(0.7, 0.74, 0.85))
		_turn_label.text = "YOU PLAY BLACK"
		_turn_label.add_theme_color_override("font_color", Color(0.7, 0.74, 0.85))
		turn_style.bg_color = Color(0.06, 0.06, 0.12, 0.9)
		turn_style.border_color = Color(0.4, 0.42, 0.6, 0.7)
	else:
		_turn_icon.text = "♔"
		_turn_icon.add_theme_color_override("font_color", W_PIECE)
		_turn_label.text = "YOU PLAY WHITE"
		_turn_label.add_theme_color_override("font_color", W_PIECE)
		turn_style.bg_color = Color(0.18, 0.16, 0.12, 0.9)
		turn_style.border_color = Color(0.85, 0.78, 0.55, 0.7)

	# Paint popup border + padding based on player color
	if _bg_panel:
		var bg_style: StyleBoxFlat = _bg_panel.get_theme_stylebox("panel")
		if is_black:
			bg_style.border_color = Color(0.15, 0.15, 0.2, 0.9)
			bg_style.bg_color = Color(0.04, 0.04, 0.07, 0.95)
			bg_style.border_width_left = 4
			bg_style.border_width_right = 4
			bg_style.border_width_top = 4
			bg_style.border_width_bottom = 4
		else:
			bg_style.border_color = Color(0.85, 0.82, 0.75, 0.9)
			bg_style.bg_color = Color(0.1, 0.09, 0.12, 0.95)
			bg_style.border_width_left = 4
			bg_style.border_width_right = 4
			bg_style.border_width_top = 4
			bg_style.border_width_bottom = 4

func _refresh_board() -> void:
	for row in 8:
		for col in 8:
			var btn: Button = _square_buttons[row][col]
			var piece := board_logic.get_piece_at(row, col)
			var sym: String = PIECE_SYMBOLS.get(piece, "")
			btn.text = sym

			if board_logic.is_white_piece(piece):
				btn.add_theme_color_override("font_color", W_PIECE)
			elif board_logic.is_black_piece(piece):
				btn.add_theme_color_override("font_color", B_PIECE)
			else:
				btn.add_theme_color_override("font_color", Color(0.4, 0.38, 0.35))

			# Reset square color
			var is_light := (row + col) % 2 == 0
			var base := LIGHT_SQ if is_light else DARK_SQ
			var style: StyleBoxFlat = btn.get_theme_stylebox("normal")
			style.bg_color = base

func _on_square(row: int, col: int) -> void:
	if not _active or _resolved:
		return

	if _selected_square == Vector2i(-1, -1):
		# Select piece
		if board_logic.is_player_piece(row, col):
			_selected_square = Vector2i(col, row)
			var style: StyleBoxFlat = _square_buttons[row][col].get_theme_stylebox("normal")
			style.bg_color = SELECTED
			Juice.scale_bounce(_square_buttons[row][col], 1.08, 0.15)
			_show_valid_moves(row, col)
	else:
		var from_row := _selected_square.y
		var from_col := _selected_square.x
		var moved_piece := board_logic.get_piece_at(from_row, from_col)

		if row == from_row and col == from_col:
			_deselect()
			return

		if board_logic.is_player_piece(row, col):
			_deselect()
			_selected_square = Vector2i(col, row)
			var style: StyleBoxFlat = _square_buttons[row][col].get_theme_stylebox("normal")
			style.bg_color = SELECTED
			_show_valid_moves(row, col)
			return

		# Snapshot what's on the destination before the move
		var captured_piece := board_logic.get_piece_at(row, col)
		var result := board_logic.try_move(from_row, from_col, row, col)
		_deselect()

		match result:
			0:
				_on_wrong_move(row, col)
			1:
				await _animate_move(from_row, from_col, row, col, captured_piece != "")
				_last_moved_piece = str(moved_piece).to_upper()
				_on_correct_step(row, col)
			2:
				await _animate_move(from_row, from_col, row, col, captured_piece != "")
				_last_moved_piece = str(moved_piece).to_upper()
				_resolve(true)

func _animate_move(from_row: int, from_col: int, to_row: int, to_col: int, is_capture: bool) -> void:
	var from_btn: Button = _square_buttons[from_row][from_col]
	var to_btn: Button = _square_buttons[to_row][to_col]

	# Read the piece symbol from the board logic (move already executed)
	var moved_piece := board_logic.get_piece_at(to_row, to_col)
	var sym: String = PIECE_SYMBOLS.get(moved_piece, "")

	# Clear source square immediately
	from_btn.text = ""

	# If capture, flash the destination red and clear it
	if is_capture:
		var to_style: StyleBoxFlat = to_btn.get_theme_stylebox("normal")
		var orig_color := to_style.bg_color
		to_style.bg_color = Color(0.85, 0.2, 0.15, 0.7)
		to_btn.text = ""
		AudioManager.play_sfx_varied(AudioManager.sfx_whoosh, -6.0)
		Juice.screen_shake(_grid, 3.0, 0.1)
		await get_tree().create_timer(0.1).timeout
		to_style.bg_color = orig_color

	# Place piece on destination
	to_btn.text = sym
	if board_logic.is_white_piece(moved_piece):
		to_btn.add_theme_color_override("font_color", W_PIECE)
	elif board_logic.is_black_piece(moved_piece):
		to_btn.add_theme_color_override("font_color", B_PIECE)

	# Bounce the destination square
	Juice.scale_bounce(to_btn, 1.12, 0.15)
	await get_tree().create_timer(0.12).timeout

func _show_valid_moves(row: int, col: int) -> void:
	_valid_moves = board_logic.get_valid_squares_for_piece(row, col)
	for move in _valid_moves:
		var mr := move.y
		var mc := move.x
		if mr >= 0 and mr < 8 and mc >= 0 and mc < 8:
			var btn: Button = _square_buttons[mr][mc]
			var target := board_logic.get_piece_at(mr, mc)
			if target == "":
				# Gold dot centered via CenterContainer (avoids btn.size=0 bug)
				var cc := CenterContainer.new()
				cc.set_anchors_preset(Control.PRESET_FULL_RECT)
				cc.mouse_filter = Control.MOUSE_FILTER_IGNORE
				var dot := Panel.new()
				var dot_style := StyleBoxFlat.new()
				dot_style.bg_color = MOVE_DOT_COLOR
				dot_style.corner_radius_top_left = 7
				dot_style.corner_radius_top_right = 7
				dot_style.corner_radius_bottom_left = 7
				dot_style.corner_radius_bottom_right = 7
				dot.add_theme_stylebox_override("panel", dot_style)
				dot.custom_minimum_size = Vector2(14, 14)
				dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
				cc.add_child(dot)
				btn.add_child(cc)
				btn.set_meta("move_dot", cc)
				# Pulse animation
				var tw := dot.create_tween().set_loops()
				tw.tween_property(dot_style, "bg_color", Color(MOVE_DOT_COLOR, 0.35), 0.6)
				tw.tween_property(dot_style, "bg_color", MOVE_DOT_COLOR, 0.6)
				btn.set_meta("move_dot_pulse", tw)
			else:
				# Capture indicator: bold ring overlay on enemy piece
				var ring_cc := CenterContainer.new()
				ring_cc.set_anchors_preset(Control.PRESET_FULL_RECT)
				ring_cc.mouse_filter = Control.MOUSE_FILTER_IGNORE
				var ring := Panel.new()
				var ring_style := StyleBoxFlat.new()
				ring_style.bg_color = Color(0, 0, 0, 0)  # Transparent center
				ring_style.draw_center = false
				ring_style.border_width_left = 3
				ring_style.border_width_right = 3
				ring_style.border_width_top = 3
				ring_style.border_width_bottom = 3
				ring_style.border_color = CAPTURE_RING_COLOR
				ring_style.corner_radius_top_left = 26
				ring_style.corner_radius_top_right = 26
				ring_style.corner_radius_bottom_left = 26
				ring_style.corner_radius_bottom_right = 26
				ring.add_theme_stylebox_override("panel", ring_style)
				ring.custom_minimum_size = Vector2(52, 52)
				ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
				ring_cc.add_child(ring)
				btn.add_child(ring_cc)
				btn.set_meta("capture_ring_node", ring_cc)
				# Pulse the ring
				var tw := ring.create_tween().set_loops()
				tw.tween_property(ring_style, "border_color", Color(CAPTURE_RING_COLOR, 0.4), 0.5)
				tw.tween_property(ring_style, "border_color", CAPTURE_RING_COLOR, 0.5)
				btn.set_meta("capture_pulse", tw)

func _clear_move_indicators() -> void:
	for move in _valid_moves:
		var mr := move.y
		var mc := move.x
		if mr >= 0 and mr < 8 and mc >= 0 and mc < 8:
			var btn: Button = _square_buttons[mr][mc]
			# Clean up move dots
			if btn.has_meta("move_dot"):
				var dot: Node = btn.get_meta("move_dot")
				if is_instance_valid(dot):
					dot.queue_free()
				btn.remove_meta("move_dot")
			if btn.has_meta("move_dot_pulse"):
				var tw: Tween = btn.get_meta("move_dot_pulse")
				if tw and tw.is_valid():
					tw.kill()
				btn.remove_meta("move_dot_pulse")
			# Clean up capture rings
			if btn.has_meta("capture_ring_node"):
				var ring: Node = btn.get_meta("capture_ring_node")
				if is_instance_valid(ring):
					ring.queue_free()
				btn.remove_meta("capture_ring_node")
			if btn.has_meta("capture_pulse"):
				var tw: Tween = btn.get_meta("capture_pulse")
				if tw and tw.is_valid():
					tw.kill()
				btn.remove_meta("capture_pulse")
			# Reset square color
			var is_light := (mr + mc) % 2 == 0
			var style: StyleBoxFlat = btn.get_theme_stylebox("normal")
			style.bg_color = LIGHT_SQ if is_light else DARK_SQ
	_valid_moves.clear()

func _deselect() -> void:
	_clear_move_indicators()
	if _selected_square != Vector2i(-1, -1):
		var r := _selected_square.y
		var c := _selected_square.x
		var is_light := (r + c) % 2 == 0
		var style: StyleBoxFlat = _square_buttons[r][c].get_theme_stylebox("normal")
		style.bg_color = LIGHT_SQ if is_light else DARK_SQ
		_selected_square = Vector2i(-1, -1)

func _on_wrong_move(row: int, col: int) -> void:
	_status_label.text = "Wrong! -%.1fs" % _error_penalty
	_status_label.add_theme_color_override("font_color", Color(0.9, 0.3, 0.25))
	Juice.screen_shake(_grid, 4.0, 0.12)
	_mistakes += 1

	# Flash square red
	var style: StyleBoxFlat = _square_buttons[row][col].get_theme_stylebox("normal")
	var orig := style.bg_color
	style.bg_color = WRONG_COL
	var tw := create_tween()
	tw.tween_property(style, "bg_color", orig, 0.3)

	# Penalty
	_time_remaining -= _error_penalty

func _on_correct_step(row: int, col: int) -> void:
	_status_label.text = "Correct! Keep going..."
	_status_label.add_theme_color_override("font_color", Color(0.3, 0.9, 0.4))

	# Flash the destination green
	var style: StyleBoxFlat = _square_buttons[row][col].get_theme_stylebox("normal")
	var orig := style.bg_color
	style.bg_color = CORRECT_COL
	var tw := create_tween()
	tw.tween_property(style, "bg_color", orig, 0.3)

	# Execute the opponent's response move on the logic, then refresh the board
	var opp_uci := board_logic.peek_opponent_response()
	if opp_uci != "":
		# Brief pause so the player sees their move before opponent responds
		_active = false  # Block input during opponent response
		var delay := create_tween()
		delay.tween_interval(0.4)
		delay.tween_callback(_execute_mini_opponent_response.bind(opp_uci))
	else:
		_refresh_board()
		_update_turn_label()

func _execute_mini_opponent_response(opp_uci: String) -> void:
	# Parse for animation
	var opp_from := board_logic.uci_to_coords(opp_uci.substr(0, 2))
	var opp_to := board_logic.uci_to_coords(opp_uci.substr(2, 2))

	# Execute on logic
	board_logic.execute_opponent_response()

	# Refresh and animate
	_refresh_board()
	_update_turn_label()

	# Animate the opponent's moved piece
	var to_btn: Button = _square_buttons[opp_to.y][opp_to.x]
	Juice.scale_bounce(to_btn, 1.12, 0.15)

	# Flash opponent's destination
	var s: StyleBoxFlat = to_btn.get_theme_stylebox("normal")
	var orig_color := s.bg_color
	s.bg_color = Color(0.7, 0.3, 0.3, 0.7)
	var color_tw := create_tween()
	color_tw.tween_property(s, "bg_color", orig_color, 0.3)

	_status_label.text = "Your move!"
	_status_label.add_theme_color_override("font_color", Color(0.7, 0.68, 0.6))
	_active = true  # Re-enable input

func _resolve(solved: bool) -> void:
	_active = false
	_resolved = true
	set_process(false)

	if solved:
		_refresh_board()
		_prompt_label.text = "SOLVED!"
		_prompt_label.add_theme_color_override("font_color", Color(0.3, 0.95, 0.4))
		_status_label.text = "Punch lands!"
		_status_label.add_theme_color_override("font_color", Color(0.3, 0.95, 0.4))
		Juice.screen_flash(self, Color(0.3, 0.95, 0.3, 0.15), 0.15)
		Juice.scale_bounce(_grid, 1.03, 0.2)
	else:
		_prompt_label.text = "FAILED!"
		_prompt_label.add_theme_color_override("font_color", Color(0.9, 0.3, 0.25))
		_status_label.text = "Punch misses!"
		_status_label.add_theme_color_override("font_color", Color(0.9, 0.3, 0.25))
		Juice.screen_shake(self, 5.0, 0.15)

	var result := {
		"solved": solved,
		"time_remaining": maxf(_time_remaining, 0.0),
		"solve_time": clampf(_time_limit - _time_remaining, 0.0, _time_limit),
		"time_limit": _time_limit,
		"mistakes": _mistakes,
		"moved_piece": _last_moved_piece,
	}

	await get_tree().create_timer(0.5).timeout
	completed.emit(result)
