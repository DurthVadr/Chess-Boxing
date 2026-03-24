extends Control

## Chess Phase — Puzzle solving with timer and bonus calculation

@onready var board_grid: GridContainer = %BoardGrid
@onready var timer_label: Label = %TimerLabel
@onready var puzzle_desc_label: Label = %PuzzleDescLabel
@onready var status_label: Label = %StatusLabel
@onready var bonus_bar: ProgressBar = %BonusBar
@onready var mistake_label: Label = %MistakeLabel

var board_logic: ChessBoardLogic
var current_puzzle: Dictionary = {}
var time_limit: float = 60.0
var time_remaining: float = 60.0
var solve_start_time: float = 0.0
var is_active: bool = false
var mistakes: int = 0
var free_mistakes: int = 0

var selected_square: Vector2i = Vector2i(-1, -1)
var square_buttons: Array = []  # 2D array of buttons

const LIGHT_SQUARE := Color(0.93, 0.89, 0.78)
const DARK_SQUARE := Color(0.47, 0.36, 0.27)
const SELECTED_COLOR := Color(0.9, 0.78, 0.3, 0.6)
const WRONG_COLOR := Color(0.8, 0.2, 0.2, 0.5)
const CORRECT_COLOR := Color(0.2, 0.8, 0.3, 0.5)

func _ready() -> void:
	board_logic = ChessBoardLogic.new()
	current_puzzle = GameManager.get_puzzle_for_opponent()

	time_limit = GameManager.get_chess_time_limit()
	time_remaining = time_limit
	free_mistakes = GameManager.get_free_mistakes()
	solve_start_time = 0.0

	board_logic.setup_puzzle(current_puzzle)
	puzzle_desc_label.text = current_puzzle.get("description", "Solve this puzzle!")
	mistake_label.text = ""
	status_label.text = "Your move!"
	bonus_bar.value = 100.0

	_build_board()
	is_active = true
	solve_start_time = Time.get_ticks_msec() / 1000.0

	Juice.fade_in(self, 0.3)

func _process(delta: float) -> void:
	if not is_active:
		return

	time_remaining -= delta
	time_remaining = maxf(time_remaining, 0.0)

	# Update timer display
	var seconds := int(time_remaining)
	timer_label.text = "%d:%02d" % [seconds / 60, seconds % 60]

	# Color timer based on urgency
	if time_remaining < 10.0:
		timer_label.add_theme_color_override("font_color", Color(0.9, 0.2, 0.2))
	elif time_remaining < 20.0:
		timer_label.add_theme_color_override("font_color", Color(0.9, 0.7, 0.2))
	else:
		timer_label.add_theme_color_override("font_color", Color.WHITE)

	# Update bonus bar (decays with time)
	bonus_bar.value = (time_remaining / time_limit) * 100.0

	# Time's up!
	if time_remaining <= 0.0:
		_on_puzzle_failed()

func _build_board() -> void:
	# Clear existing
	for child in board_grid.get_children():
		child.queue_free()

	square_buttons = []
	board_grid.columns = 8

	for row in 8:
		var row_arr: Array = []
		for col in 8:
			var btn := Button.new()
			btn.custom_minimum_size = Vector2(60, 60)
			btn.focus_mode = Control.FOCUS_NONE

			# Square color
			var is_light := (row + col) % 2 == 0
			var base_color := LIGHT_SQUARE if is_light else DARK_SQUARE

			var style := StyleBoxFlat.new()
			style.bg_color = base_color
			style.corner_radius_top_left = 0
			style.corner_radius_top_right = 0
			style.corner_radius_bottom_left = 0
			style.corner_radius_bottom_right = 0
			btn.add_theme_stylebox_override("normal", style)
			btn.add_theme_stylebox_override("hover", style.duplicate())
			btn.add_theme_stylebox_override("pressed", style.duplicate())
			btn.add_theme_stylebox_override("focus", StyleBoxEmpty.new())

			# Piece text
			var piece_symbol := board_logic.get_piece_symbol(row, col)
			btn.text = piece_symbol
			btn.add_theme_font_size_override("font_size", 32)

			# Color pieces
			var piece := board_logic.get_piece_at(row, col)
			if board_logic.is_white_piece(piece):
				btn.add_theme_color_override("font_color", Color(1, 1, 1))
			elif board_logic.is_black_piece(piece):
				btn.add_theme_color_override("font_color", Color(0.1, 0.1, 0.1))

			btn.pressed.connect(_on_square_pressed.bind(row, col))
			board_grid.add_child(btn)
			row_arr.append(btn)
		square_buttons.append(row_arr)

func _refresh_board() -> void:
	for row in 8:
		for col in 8:
			var btn: Button = square_buttons[row][col]
			var piece_symbol := board_logic.get_piece_symbol(row, col)
			btn.text = piece_symbol

			var piece := board_logic.get_piece_at(row, col)
			if board_logic.is_white_piece(piece):
				btn.add_theme_color_override("font_color", Color(1, 1, 1))
			elif board_logic.is_black_piece(piece):
				btn.add_theme_color_override("font_color", Color(0.1, 0.1, 0.1))
			else:
				btn.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))

			# Reset square color
			var is_light := (row + col) % 2 == 0
			var base_color := LIGHT_SQUARE if is_light else DARK_SQUARE
			var style: StyleBoxFlat = btn.get_theme_stylebox("normal")
			style.bg_color = base_color

func _on_square_pressed(row: int, col: int) -> void:
	if not is_active:
		return

	if selected_square == Vector2i(-1, -1):
		# First click — select a piece
		if board_logic.is_player_piece(row, col):
			selected_square = Vector2i(col, row)
			# Highlight selected square
			var style: StyleBoxFlat = square_buttons[row][col].get_theme_stylebox("normal")
			style.bg_color = SELECTED_COLOR
	else:
		# Second click — try to move
		var from_row := selected_square.y
		var from_col := selected_square.x

		if row == from_row and col == from_col:
			# Deselect
			_deselect()
			return

		# If clicking another own piece, reselect
		if board_logic.is_player_piece(row, col):
			_deselect()
			selected_square = Vector2i(col, row)
			var style: StyleBoxFlat = square_buttons[row][col].get_theme_stylebox("normal")
			style.bg_color = SELECTED_COLOR
			return

		var result := board_logic.try_move(from_row, from_col, row, col)
		_deselect()

		match result:
			0:  # Wrong move
				_on_wrong_move(row, col)
			1:  # Correct, more moves needed
				_on_correct_move()
			2:  # Puzzle complete!
				_on_puzzle_solved()

func _deselect() -> void:
	if selected_square != Vector2i(-1, -1):
		var r := selected_square.y
		var c := selected_square.x
		var is_light := (r + c) % 2 == 0
		var style: StyleBoxFlat = square_buttons[r][c].get_theme_stylebox("normal")
		style.bg_color = LIGHT_SQUARE if is_light else DARK_SQUARE
		selected_square = Vector2i(-1, -1)

func _on_wrong_move(row: int, col: int) -> void:
	mistakes += 1

	if mistakes <= free_mistakes:
		status_label.text = "Wrong! (Free mistake used)"
		mistake_label.text = "Free mistakes left: %d" % (free_mistakes - mistakes)
	else:
		status_label.text = "Wrong move! Try again."
		mistake_label.text = "Mistakes: %d" % (mistakes - free_mistakes)

	# Flash the target square red
	var style: StyleBoxFlat = square_buttons[row][col].get_theme_stylebox("normal")
	var original_color := style.bg_color
	style.bg_color = WRONG_COLOR
	var tween := create_tween()
	tween.tween_property(style, "bg_color", original_color, 0.4)

	# Penalty: lose time
	var real_mistakes := mistakes - free_mistakes
	if real_mistakes > 0:
		time_remaining -= 5.0 * real_mistakes

	# Too many mistakes = fail
	if real_mistakes >= 3:
		_on_puzzle_failed()

	Juice.screen_shake(board_grid, 5.0, 0.15)

func _on_correct_move() -> void:
	status_label.text = "Correct! Keep going..."
	status_label.add_theme_color_override("font_color", Color(0.3, 0.9, 0.3))
	_refresh_board()

	# Flash green briefly
	var tween := create_tween()
	tween.tween_callback(func(): status_label.add_theme_color_override("font_color", Color.WHITE)).set_delay(0.5)

func _on_puzzle_solved() -> void:
	is_active = false
	var solve_time := (Time.get_ticks_msec() / 1000.0) - solve_start_time
	GameManager.set_chess_result(true, time_remaining, solve_time)

	status_label.text = ChessBonus.get_bonus_text(GameManager.chess_bonus)
	status_label.add_theme_color_override("font_color", Color(0.3, 0.9, 0.3))
	Juice.punch_text(status_label)

	_refresh_board()

	# Transition to boxing after a short delay
	var tween := create_tween()
	tween.tween_callback(_go_to_boxing).set_delay(2.0)

func _on_puzzle_failed() -> void:
	is_active = false
	GameManager.set_chess_result(false, 0.0, time_limit)

	status_label.text = "Time's up! Opponent gets the bonus!"
	status_label.add_theme_color_override("font_color", Color(0.9, 0.2, 0.2))
	Juice.screen_shake(self, 8.0, 0.3)

	var tween := create_tween()
	tween.tween_callback(_go_to_boxing).set_delay(2.0)

func _go_to_boxing() -> void:
	GameManager.advance_fight_round()
