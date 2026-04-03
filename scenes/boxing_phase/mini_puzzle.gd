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
var _turn_label: Label
var _status_label: Label
var _intro_timer := 0.0
var _mistakes := 0
var _error_penalty := 2.0

const SQ := 48
const LIGHT_SQ := Color(0.55, 0.45, 0.65)
const DARK_SQ := Color(0.22, 0.18, 0.32)
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

func _ready() -> void:
	mouse_filter = MOUSE_FILTER_STOP
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
	_status_label.text = "Your move!"
	_status_label.add_theme_color_override("font_color", Color(0.7, 0.68, 0.6))
	set_process(true)

func run(p: Dictionary, time: float = 12.0, error_penalty: float = 2.0) -> Dictionary:
	setup(p, time, error_penalty)
	var result: Dictionary = await completed
	return result

func _process(delta: float) -> void:
	if not _active or _resolved:
		return

	_intro_timer += delta
	_time_remaining -= delta
	_time_remaining = maxf(_time_remaining, 0.0)

	# Update timer bar
	var pct := _time_remaining / _time_limit
	_timer_bar.anchor_right = pct
	if pct < 0.25:
		_timer_bar.color = Color(0.85, 0.25, 0.2)
	elif pct < 0.5:
		_timer_bar.color = Color(0.85, 0.65, 0.2)
	else:
		_timer_bar.color = Color(0.35, 0.85, 0.45)

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
	bg.custom_minimum_size = Vector2(SQ * 8 + 28, SQ * 8 + 104)
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

	var root := VBoxContainer.new()
	root.alignment = BoxContainer.ALIGNMENT_CENTER
	root.add_theme_constant_override("separation", 4)
	bg.add_child(root)

	_prompt_label = Label.new()
	_prompt_label.text = "SOLVE TO PUNCH!"
	_prompt_label.add_theme_font_size_override("font_size", 14)
	_prompt_label.add_theme_color_override("font_color", GOLD)
	_prompt_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(_prompt_label)

	_turn_label = Label.new()
	_turn_label.text = ""
	_turn_label.add_theme_font_size_override("font_size", 13)
	_turn_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(_turn_label)

	# Timer bar
	_timer_bg = Control.new()
	_timer_bg.custom_minimum_size = Vector2(SQ * 8, 5)
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

			btn.add_theme_font_size_override("font_size", 28)
			btn.pressed.connect(_on_square.bind(row, col))
			_grid.add_child(btn)
			row_arr.append(btn)
		_square_buttons.append(row_arr)

	_status_label = Label.new()
	_status_label.text = ""
	_status_label.add_theme_font_size_override("font_size", 12)
	_status_label.add_theme_color_override("font_color", Color(0.7, 0.68, 0.6))
	_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(_status_label)

func _update_turn_label() -> void:
	if _turn_label == null or board_logic == null:
		return
	if board_logic.active_color == "b":
		_turn_label.text = "BLACK TO MOVE"
		_turn_label.add_theme_color_override("font_color", Color(0.70, 0.74, 0.85))
	else:
		_turn_label.text = "WHITE TO MOVE"
		_turn_label.add_theme_color_override("font_color", W_PIECE)

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
	else:
		var from_row := _selected_square.y
		var from_col := _selected_square.x

		if row == from_row and col == from_col:
			_deselect()
			return

		if board_logic.is_player_piece(row, col):
			_deselect()
			_selected_square = Vector2i(col, row)
			var style: StyleBoxFlat = _square_buttons[row][col].get_theme_stylebox("normal")
			style.bg_color = SELECTED
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
				_on_correct_step(row, col)
			2:
				await _animate_move(from_row, from_col, row, col, captured_piece != "")
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

func _deselect() -> void:
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

	# Sync the full board to show the opponent's auto-response move
	_refresh_board()
	_update_turn_label()

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
	}

	await get_tree().create_timer(0.5).timeout
	completed.emit(result)
