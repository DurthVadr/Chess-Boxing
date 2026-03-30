extends Control

## Chess Phase — Puzzle solving with timer and bonus calculation

@onready var board_grid: GridContainer = %BoardGrid
@onready var timer_label: Label = %TimerLabel
@onready var puzzle_desc_label: Label = %PuzzleDescLabel
@onready var status_label: Label = %StatusLabel
@onready var bonus_bar: ProgressBar = %BonusBar
@onready var mistake_label: Label = %MistakeLabel
@onready var enemy_clock_label: Label = %EnemyClockLabel

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

# Rich jewel-tone board colors
const LIGHT_SQUARE := Color(0.55, 0.45, 0.65)      # Muted lavender
const DARK_SQUARE := Color(0.22, 0.18, 0.32)       # Deep purple
const SELECTED_COLOR := Color(0.9, 0.75, 0.2, 0.85) # Bright gold
const VALID_MOVE_COLOR := Color(0.4, 0.8, 0.5, 0.5) # Green hint
const WRONG_COLOR := Color(0.85, 0.2, 0.2, 0.7)     # Vibrant red
const CORRECT_COLOR := Color(0.3, 0.85, 0.4, 0.6)   # Vibrant green
const LAST_MOVE_COLOR := Color(0.65, 0.5, 0.9, 0.4) # Subtle purple highlight

# Piece colors with better contrast
const WHITE_PIECE_COLOR := Color(0.98, 0.95, 0.85)  # Warm cream
const BLACK_PIECE_COLOR := Color(0.12, 0.1, 0.15)   # Near black
const WHITE_PIECE_SHADOW := Color(0.3, 0.25, 0.2, 0.5)
const BLACK_PIECE_SHADOW := Color(0.0, 0.0, 0.0, 0.3)

var last_move_from := Vector2i(-1, -1)
var last_move_to := Vector2i(-1, -1)
var valid_moves: Array[Vector2i] = []

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

	# Enemy clock — show difficulty as stars
	var diff: int = int(GameManager.current_opponent.get("chess_difficulty", 1))
	enemy_clock_label.text = "★".repeat(diff) + "☆".repeat(maxi(0, 5 - diff))

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
	timer_label.text = "%d:%02d" % [seconds / 60, seconds % 60]  # Integer division intended (time display)

	# Color timer based on urgency + shift music intensity
	if time_remaining < 10.0:
		timer_label.add_theme_color_override("font_color", Color(0.92, 0.22, 0.22))
		MusicManager.shift_intensity("chess_tense")
	elif time_remaining < 20.0:
		timer_label.add_theme_color_override("font_color", Color(0.92, 0.72, 0.22))
	else:
		timer_label.add_theme_color_override("font_color", Color(0.35, 0.85, 0.45))

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
			btn.custom_minimum_size = Vector2(64, 64)
			btn.focus_mode = Control.FOCUS_NONE

			# Square color with subtle gradient effect
			var is_light := (row + col) % 2 == 0
			var base_color := LIGHT_SQUARE if is_light else DARK_SQUARE

			var style := StyleBoxFlat.new()
			style.bg_color = base_color
			style.border_width_bottom = 2
			style.border_width_right = 1
			style.border_color = base_color.darkened(0.2)
			
			# Hover style with glow
			var hover_style := StyleBoxFlat.new()
			hover_style.bg_color = base_color.lightened(0.15)
			hover_style.border_width_bottom = 2
			hover_style.border_width_right = 1
			hover_style.border_color = Color(0.9, 0.8, 0.3, 0.6)
			
			btn.add_theme_stylebox_override("normal", style)
			btn.add_theme_stylebox_override("hover", hover_style)
			btn.add_theme_stylebox_override("pressed", style.duplicate())
			btn.add_theme_stylebox_override("focus", StyleBoxEmpty.new())

			# Piece text with shadow effect
			var piece_symbol := board_logic.get_piece_symbol(row, col)
			btn.text = piece_symbol
			btn.add_theme_font_size_override("font_size", 38)

			# Color pieces with better contrast
			var piece := board_logic.get_piece_at(row, col)
			if board_logic.is_white_piece(piece):
				btn.add_theme_color_override("font_color", WHITE_PIECE_COLOR)
				btn.add_theme_constant_override("outline_size", 2)
				btn.add_theme_color_override("font_outline_color", WHITE_PIECE_SHADOW)
			elif board_logic.is_black_piece(piece):
				btn.add_theme_color_override("font_color", BLACK_PIECE_COLOR)
				btn.add_theme_constant_override("outline_size", 3)
				btn.add_theme_color_override("font_outline_color", Color(0.6, 0.55, 0.7, 0.8))

			btn.pressed.connect(_on_square_pressed.bind(row, col))
			btn.mouse_entered.connect(_on_square_hovered.bind(row, col))
			board_grid.add_child(btn)
			row_arr.append(btn)
		square_buttons.append(row_arr)
	
	# Entry animation - stagger the squares
	_animate_board_entry()

func _animate_board_entry() -> void:
	for row in 8:
		for col in 8:
			var btn: Button = square_buttons[row][col]
			btn.modulate.a = 0.0
			btn.scale = Vector2(0.8, 0.8)
			btn.pivot_offset = btn.size / 2.0
			
			var delay := (row + col) * 0.02
			var tween := create_tween()
			tween.tween_interval(delay)
			tween.tween_property(btn, "modulate:a", 1.0, 0.15)
			tween.parallel().tween_property(btn, "scale", Vector2.ONE, 0.2).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)

func _on_square_hovered(row: int, col: int) -> void:
	if not is_active:
		return
	# Subtle hover feedback
	if board_logic.is_player_piece(row, col) or Vector2i(col, row) in valid_moves:
		var btn: Button = square_buttons[row][col]
		Juice.scale_bounce(btn, 1.05, 0.15)

func _refresh_board() -> void:
	for row in 8:
		for col in 8:
			var btn: Button = square_buttons[row][col]
			var piece_symbol := board_logic.get_piece_symbol(row, col)
			btn.text = piece_symbol

			var piece := board_logic.get_piece_at(row, col)
			if board_logic.is_white_piece(piece):
				btn.add_theme_color_override("font_color", WHITE_PIECE_COLOR)
				btn.add_theme_constant_override("outline_size", 2)
				btn.add_theme_color_override("font_outline_color", WHITE_PIECE_SHADOW)
			elif board_logic.is_black_piece(piece):
				btn.add_theme_color_override("font_color", BLACK_PIECE_COLOR)
				btn.add_theme_constant_override("outline_size", 3)
				btn.add_theme_color_override("font_outline_color", Color(0.6, 0.55, 0.7, 0.8))
			else:
				btn.add_theme_color_override("font_color", Color(0.5, 0.48, 0.42))

			# Reset square color, but highlight last move
			var is_light := (row + col) % 2 == 0
			var base_color := LIGHT_SQUARE if is_light else DARK_SQUARE
			var pos := Vector2i(col, row)
			
			if pos == last_move_from or pos == last_move_to:
				base_color = base_color.blend(LAST_MOVE_COLOR)
			
			var style: StyleBoxFlat = btn.get_theme_stylebox("normal")
			style.bg_color = base_color
	
	# Clear valid move hints
	valid_moves.clear()

func _on_square_pressed(row: int, col: int) -> void:
	if not is_active:
		return

	if selected_square == Vector2i(-1, -1):
		# First click — select a piece
		if board_logic.is_player_piece(row, col):
			selected_square = Vector2i(col, row)
			_highlight_selection(row, col)
			_show_valid_moves(row, col)
			# Bounce the selected piece
			Juice.scale_bounce(square_buttons[row][col], 1.1, 0.2)
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
			_highlight_selection(row, col)
			_show_valid_moves(row, col)
			Juice.scale_bounce(square_buttons[row][col], 1.1, 0.2)
			return

		var result := board_logic.try_move(from_row, from_col, row, col)
		
		# Store last move for highlighting
		if result > 0:
			last_move_from = Vector2i(from_col, from_row)
			last_move_to = Vector2i(col, row)
		
		_deselect()

		match result:
			0:  # Wrong move
				_on_wrong_move(row, col)
			1:  # Correct, more moves needed
				_on_correct_move(from_row, from_col, row, col)
			2:  # Puzzle complete!
				_on_puzzle_solved()

func _highlight_selection(row: int, col: int) -> void:
	var style: StyleBoxFlat = square_buttons[row][col].get_theme_stylebox("normal")
	style.bg_color = SELECTED_COLOR
	style.border_color = Color(1.0, 0.85, 0.2, 0.9)
	style.border_width_top = 3
	style.border_width_left = 3
	style.border_width_bottom = 3
	style.border_width_right = 3

func _show_valid_moves(row: int, col: int) -> void:
	valid_moves.clear()
	if board_logic.has_method("get_valid_moves"):
		for move in board_logic.get_valid_moves(row, col):
			valid_moves.append(move as Vector2i)
	for move in valid_moves:
		var mr := move.y
		var mc := move.x
		if mr >= 0 and mr < 8 and mc >= 0 and mc < 8:
			var style: StyleBoxFlat = square_buttons[mr][mc].get_theme_stylebox("normal")
			var is_light := (mr + mc) % 2 == 0
			var base := LIGHT_SQUARE if is_light else DARK_SQUARE
			style.bg_color = base.blend(VALID_MOVE_COLOR)

func _deselect() -> void:
	if selected_square != Vector2i(-1, -1):
		var r := selected_square.y
		var c := selected_square.x
		_reset_square_style(r, c)
		selected_square = Vector2i(-1, -1)
	
	# Clear valid move highlights
	for move in valid_moves:
		var mr := move.y
		var mc := move.x
		if mr >= 0 and mr < 8 and mc >= 0 and mc < 8:
			_reset_square_style(mr, mc)
	valid_moves.clear()

func _reset_square_style(row: int, col: int) -> void:
	var is_light := (row + col) % 2 == 0
	var base_color := LIGHT_SQUARE if is_light else DARK_SQUARE
	var pos := Vector2i(col, row)
	
	if pos == last_move_from or pos == last_move_to:
		base_color = base_color.blend(LAST_MOVE_COLOR)
	
	var style: StyleBoxFlat = square_buttons[row][col].get_theme_stylebox("normal")
	style.bg_color = base_color
	style.border_width_top = 0
	style.border_width_left = 0
	style.border_width_bottom = 2
	style.border_width_right = 1
	style.border_color = base_color.darkened(0.2)

func _on_wrong_move(row: int, col: int) -> void:
	AudioManager.play_sfx_varied(AudioManager.sfx_error, -4.0)
	Juice.screen_shake(self, 5.0, 0.15)
	Juice.flash(board_grid, Color(0.9, 0.2, 0.2, 0.4), 0.12)
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

func _on_correct_move(from_row: int, from_col: int, to_row: int, to_col: int) -> void:
	AudioManager.play_piece_move()
	status_label.text = "Correct! Keep going..."
	status_label.add_theme_color_override("font_color", Color(0.3, 0.9, 0.3))
	
	# Animate the moved piece
	var to_btn: Button = square_buttons[to_row][to_col]
	to_btn.pivot_offset = to_btn.size / 2.0
	to_btn.scale = Vector2(1.3, 1.3)
	var scale_tween := create_tween()
	scale_tween.set_ease(Tween.EASE_OUT)
	scale_tween.set_trans(Tween.TRANS_ELASTIC)
	scale_tween.tween_property(to_btn, "scale", Vector2.ONE, 0.3)
	
	# Flash the destination square green
	var style: StyleBoxFlat = to_btn.get_theme_stylebox("normal")
	var original_color := style.bg_color
	style.bg_color = CORRECT_COLOR
	var color_tween := create_tween()
	color_tween.tween_property(style, "bg_color", original_color.blend(LAST_MOVE_COLOR), 0.4)
	
	_refresh_board()
	Juice.punch_text(status_label)

	# Fade status back to white
	var tween := create_tween()
	tween.tween_callback(func(): status_label.add_theme_color_override("font_color", Color.WHITE)).set_delay(0.5)

func _on_puzzle_solved() -> void:
	AudioManager.play_puzzle_solved()
	is_active = false
	var solve_time := (Time.get_ticks_msec() / 1000.0) - solve_start_time
	var real_mistakes := maxi(0, mistakes - free_mistakes)
	GameManager.set_chess_result(true, time_remaining, solve_time, real_mistakes)

	status_label.text = HeatSystem.get_heat_text(GameManager.get_heat())
	status_label.add_theme_color_override("font_color", Color(0.3, 0.95, 0.4))
	Juice.punch_text(status_label)
	Juice.screen_flash(self, Color(0.3, 0.95, 0.3, 0.15), 0.2)
	Juice.scale_bounce(board_grid, 1.02, 0.3)

	_refresh_board()
	_celebrate_solve()

	# Transition to boxing after a short delay
	var tween := create_tween()
	tween.tween_callback(_go_to_boxing).set_delay(2.0)

func _celebrate_solve() -> void:
	# Golden ripple effect across the board
	for row in 8:
		for col in 8:
			var btn: Button = square_buttons[row][col]
			var delay := (row + col) * 0.03
			var style: StyleBoxFlat = btn.get_theme_stylebox("normal")
			var original_color := style.bg_color
			var gold := Color(0.95, 0.82, 0.25, 0.6)
			
			var tween := create_tween()
			tween.tween_interval(delay)
			tween.tween_property(style, "bg_color", original_color.blend(gold), 0.15)
			tween.tween_property(style, "bg_color", original_color, 0.3)
			
			# Subtle bounce
			btn.pivot_offset = btn.size / 2.0
			var bounce_tween := create_tween()
			bounce_tween.tween_interval(delay)
			bounce_tween.tween_property(btn, "scale", Vector2(1.08, 1.08), 0.1)
			bounce_tween.tween_property(btn, "scale", Vector2.ONE, 0.15).set_ease(Tween.EASE_OUT)

func _on_puzzle_failed() -> void:
	AudioManager.play_puzzle_failed()
	is_active = false
	var real_mistakes := maxi(0, mistakes - free_mistakes)
	GameManager.set_chess_result(false, 0.0, time_limit, real_mistakes)

	status_label.text = "Time's up! Opponent gets the bonus!"
	status_label.add_theme_color_override("font_color", Color(0.9, 0.2, 0.2))
	Juice.screen_shake(self, 10.0, 0.35)
	Juice.screen_flash(self, Color(0.9, 0.15, 0.15, 0.2), 0.2)
	MusicManager.muffle(true, 0.3)

	var tween := create_tween()
	tween.tween_callback(_go_to_boxing).set_delay(2.0)

func _go_to_boxing() -> void:
	GameManager.advance_fight_round()
