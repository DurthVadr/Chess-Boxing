class_name ChessBoardLogic
extends RefCounted

## Chess board state management and move validation for puzzles
## Does NOT implement full chess engine — only validates puzzle solution moves

# Piece representation: lowercase = black, uppercase = white
# "K" = white king, "q" = black queen, etc.
# Empty = ""

var board: Array = []  # 8x8 array of strings
var active_color: String = "w"  # "w" or "b"
var solution_moves: Array = []  # Expected solution moves in UCI format (e.g., "e2e4")
var current_solution_step: int = 0

# Piece symbols for display
const PIECE_SYMBOLS := {
	"K": "♔", "Q": "♕", "R": "♖", "B": "♗", "N": "♘", "P": "♙",
	"k": "♚", "q": "♛", "r": "♜", "b": "♝", "n": "♞", "p": "♟",
}

const PIECE_NAMES := {
	"K": "King", "Q": "Queen", "R": "Rook", "B": "Bishop", "N": "Knight", "P": "Pawn",
	"k": "King", "q": "Queen", "r": "Rook", "b": "Bishop", "n": "Knight", "p": "Pawn",
}

func _init() -> void:
	_clear_board()

func _clear_board() -> void:
	board = []
	for _row in 8:
		var row_arr: Array = []
		for _col in 8:
			row_arr.append("")
		board.append(row_arr)

func load_fen(fen: String) -> void:
	_clear_board()
	var parts := fen.split(" ")
	var rows := parts[0].split("/")

	for row_idx in 8:
		var col := 0
		for ch in rows[row_idx]:
			if ch.is_valid_int():
				col += int(ch)
			else:
				board[row_idx][col] = ch
				col += 1

	if parts.size() > 1:
		active_color = parts[1]

func setup_puzzle(puzzle: Dictionary) -> void:
	load_fen(puzzle.fen)
	solution_moves = puzzle.solution.duplicate()
	current_solution_step = 0

func get_piece_at(row: int, col: int) -> String:
	if row < 0 or row > 7 or col < 0 or col > 7:
		return ""
	return board[row][col]

func get_piece_symbol(row: int, col: int) -> String:
	var piece := get_piece_at(row, col)
	var symbol: String = PIECE_SYMBOLS.get(piece, "")
	return symbol

func is_white_piece(piece: String) -> bool:
	return piece != "" and piece == piece.to_upper()

func is_black_piece(piece: String) -> bool:
	return piece != "" and piece == piece.to_lower()

func is_player_piece(row: int, col: int) -> bool:
	var piece := get_piece_at(row, col)
	if piece == "":
		return false
	if active_color == "w":
		return is_white_piece(piece)
	else:
		return is_black_piece(piece)

## Convert board coordinates to UCI notation (e.g., row=7, col=0 -> "a1")
func coords_to_uci(row: int, col: int) -> String:
	var file := String.chr("a".unicode_at(0) + col)
	var rank := str(8 - row)
	return file + rank

## Convert UCI notation to board coordinates
func uci_to_coords(uci: String) -> Vector2i:
	var col := uci.unicode_at(0) - "a".unicode_at(0)
	var row := 8 - int(uci[1])
	return Vector2i(col, row)

## Check if a move matches the next expected solution move
## Returns: 0 = wrong, 1 = correct (more moves), 2 = puzzle complete
func try_move(from_row: int, from_col: int, to_row: int, to_col: int) -> int:
	if current_solution_step >= solution_moves.size():
		return 0

	var move_uci := coords_to_uci(from_row, from_col) + coords_to_uci(to_row, to_col)
	var expected: String = solution_moves[current_solution_step]

	if move_uci == expected:
		# Execute the move on the board
		_execute_move(from_row, from_col, to_row, to_col)
		current_solution_step += 1

		if current_solution_step >= solution_moves.size():
			return 2  # Puzzle complete!

		# Execute opponent's response move (if multi-move puzzle)
		if current_solution_step < solution_moves.size():
			_execute_solution_move(solution_moves[current_solution_step])
			current_solution_step += 1

			if current_solution_step >= solution_moves.size():
				return 2  # Puzzle complete after opponent's move

		return 1  # Correct, but more moves needed
	else:
		return 0  # Wrong move

func _execute_move(from_row: int, from_col: int, to_row: int, to_col: int) -> void:
	var piece: String = board[from_row][from_col]
	board[from_row][from_col] = ""
	board[to_row][to_col] = piece

func _execute_solution_move(uci_move: String) -> void:
	var from := uci_to_coords(uci_move.substr(0, 2))
	var to := uci_to_coords(uci_move.substr(2, 2))
	_execute_move(from.y, from.x, to.y, to.x)

func get_valid_squares_for_piece(_row: int, _col: int) -> Array[Vector2i]:
	# Simplified: for MVP, we don't show valid moves — player just tries moves
	# and gets feedback if correct or not
	return []

func is_puzzle_complete() -> bool:
	return current_solution_step >= solution_moves.size()
