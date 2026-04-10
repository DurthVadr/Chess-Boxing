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

## Check if a move matches the next expected solution move.
## Returns: 0 = wrong, 1 = correct (more moves — opponent response pending),
##          2 = puzzle complete (no more moves)
## IMPORTANT: Does NOT auto-execute opponent's response. The caller must
## call execute_opponent_response() after animating the player's move.
func try_move(from_row: int, from_col: int, to_row: int, to_col: int) -> int:
	if current_solution_step >= solution_moves.size():
		return 0

	var move_uci := coords_to_uci(from_row, from_col) + coords_to_uci(to_row, to_col)
	var expected: String = solution_moves[current_solution_step]

	# Also match promotion moves: player may send "e7e8" but expected is "e7e8q"
	if move_uci != expected and expected.length() == 5 and move_uci == expected.substr(0, 4):
		move_uci = expected  # Accept and apply promotion

	if move_uci == expected:
		_execute_move(from_row, from_col, to_row, to_col)
		# Handle promotion
		if expected.length() == 5:
			var promo_char: String = expected[4]
			var is_white_promo := is_white_piece(board[to_row][to_col]) or active_color == "w"
			board[to_row][to_col] = promo_char.to_upper() if is_white_promo else promo_char.to_lower()
		current_solution_step += 1

		if current_solution_step >= solution_moves.size():
			return 2  # Puzzle complete!

		return 1  # Correct, opponent response pending
	else:
		return 0  # Wrong move


## Execute the opponent's next response move from the solution.
## Returns true if there are still more player moves after this, false if puzzle is now complete.
## Call this after animating the player's correct move.
func execute_opponent_response() -> bool:
	if current_solution_step >= solution_moves.size():
		return false  # No opponent move to play — puzzle already done

	var opp_move: String = solution_moves[current_solution_step]
	_execute_solution_move(opp_move)
	current_solution_step += 1

	return current_solution_step < solution_moves.size()


## Get the opponent's next response move as UCI string, without executing it.
func peek_opponent_response() -> String:
	if current_solution_step >= solution_moves.size():
		return ""
	return solution_moves[current_solution_step]


## Get how many player moves remain in the puzzle.
func get_remaining_player_moves() -> int:
	var remaining := solution_moves.size() - current_solution_step
	return ceili(float(remaining) / 2.0)

func _execute_move(from_row: int, from_col: int, to_row: int, to_col: int) -> void:
	var piece: String = board[from_row][from_col]
	board[from_row][from_col] = ""
	board[to_row][to_col] = piece

func _execute_solution_move(uci_move: String) -> void:
	var from := uci_to_coords(uci_move.substr(0, 2))
	var to := uci_to_coords(uci_move.substr(2, 2))
	_execute_move(from.y, from.x, to.y, to.x)

## Return all squares this piece can legally move to (basic rules, no pin/check validation).
func get_valid_squares_for_piece(row: int, col: int) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	var piece := get_piece_at(row, col)
	if piece == "":
		return result
	var is_white := is_white_piece(piece)
	var piece_type := piece.to_upper()
	for r in 8:
		for c in 8:
			if r == row and c == col:
				continue
			# Can't capture own pieces
			var target := get_piece_at(r, c)
			if target != "":
				if (is_white and is_white_piece(target)) or (not is_white and is_black_piece(target)):
					continue
			if _can_reach(piece_type, row, col, r, c, is_white):
				result.append(Vector2i(c, r))  # (col, row) to match coordinate convention
	return result

func is_puzzle_complete() -> bool:
	return current_solution_step >= solution_moves.size()

## Flip active color between "w" and "b".
func flip_active_color() -> void:
	active_color = "b" if active_color == "w" else "w"

## Serialize the current board state back to a FEN string.
func to_fen() -> String:
	var fen := ""
	for row in 8:
		var empty_count := 0
		for col in 8:
			var piece: String = board[row][col]
			if piece == "":
				empty_count += 1
			else:
				if empty_count > 0:
					fen += str(empty_count)
					empty_count = 0
				fen += piece
		if empty_count > 0:
			fen += str(empty_count)
		if row < 7:
			fen += "/"
	fen += " " + active_color + " KQkq - 0 1"
	return fen

## Apply a Standard Algebraic Notation move (e.g., "Nf3", "exd5", "O-O", "e8=Q").
## is_white: true if this is white's move.
## Returns true on success.
func apply_san_move(san: String, is_white: bool) -> bool:
	var color := "w" if is_white else "b"

	# Castling
	if san == "O-O" or san == "O-O-O":
		return _apply_castling(san, is_white)

	# Strip capture marker, check/mate symbols
	san = san.replace("x", "").replace("+", "").replace("#", "")

	# Promotion: e8=Q or e8Q
	var promo_piece := ""
	if "=" in san:
		var parts := san.split("=")
		san = parts[0]
		promo_piece = parts[1]
	elif san.length() >= 3 and san[-1] in "QRBNqrbn":
		# Check if last char is a promotion piece and second-to-last is a rank (1 or 8)
		var last_char: String = san[-1]
		var rank_char: String = san[-2]
		if rank_char == "1" or rank_char == "8":
			if last_char.to_upper() in ["Q", "R", "B", "N"]:
				promo_piece = last_char
				san = san.substr(0, san.length() - 1)

	# Destination square is always the last two characters
	if san.length() < 2:
		return false
	var dest_str := san.substr(san.length() - 2, 2)
	var dest := uci_to_coords(dest_str)
	var to_row := dest.y
	var to_col := dest.x

	# Determine piece type
	var piece_type := "P"
	var disambig := ""
	if san.length() >= 3 and san[0] >= "A" and san[0] <= "Z":
		piece_type = san[0]
		disambig = san.substr(1, san.length() - 3)
	elif san.length() == 3 and san[0] >= "a" and san[0] <= "h":
		# Pawn capture with file disambiguation: exd5 -> "ed5" after strip
		piece_type = "P"
		disambig = san[0]
	else:
		piece_type = "P"

	var target_piece: String = piece_type if is_white else piece_type.to_lower()

	# Find the source square
	for row in 8:
		for col in 8:
			if board[row][col] != target_piece:
				continue
			# Check disambiguation
			if disambig != "":
				var matches := true
				for ch in disambig:
					if ch >= "a" and ch <= "h":
						if col != ch.unicode_at(0) - "a".unicode_at(0):
							matches = false
					elif ch >= "1" and ch <= "8":
						if row != 8 - int(ch):
							matches = false
				if not matches:
					continue

			# Basic legality check: can this piece reach the dest?
			if _can_reach(piece_type, row, col, to_row, to_col, is_white):
				_execute_move(row, col, to_row, to_col)
				if promo_piece != "":
					board[to_row][to_col] = promo_piece.to_upper() if is_white else promo_piece.to_lower()
				active_color = "b" if is_white else "w"
				return true

	return false


## Simple reachability check for SAN move replay. Not full legality (no pin checks).
func _can_reach(piece_type: String, from_row: int, from_col: int, to_row: int, to_col: int, is_white: bool) -> bool:
	var dr := to_row - from_row
	var dc := to_col - from_col
	var adr := absi(dr)
	var adc := absi(dc)

	match piece_type:
		"P":
			var dir := -1 if is_white else 1
			# Forward 1
			if dc == 0 and dr == dir and board[to_row][to_col] == "":
				return true
			# Forward 2 from starting rank
			var start_rank := 6 if is_white else 1
			if dc == 0 and from_row == start_rank and dr == dir * 2 and board[to_row][to_col] == "" and board[from_row + dir][from_col] == "":
				return true
			# Capture diagonally
			if adc == 1 and dr == dir:
				return true  # Captures (including en passant)
			return false
		"N":
			return (adr == 2 and adc == 1) or (adr == 1 and adc == 2)
		"B":
			return adr == adc and adr > 0 and _path_clear(from_row, from_col, to_row, to_col)
		"R":
			return (dr == 0 or dc == 0) and (adr + adc > 0) and _path_clear(from_row, from_col, to_row, to_col)
		"Q":
			return ((adr == adc) or (dr == 0 or dc == 0)) and (adr + adc > 0) and _path_clear(from_row, from_col, to_row, to_col)
		"K":
			return adr <= 1 and adc <= 1 and (adr + adc > 0)
	return false


func _path_clear(from_row: int, from_col: int, to_row: int, to_col: int) -> bool:
	var dr := signi(to_row - from_row)
	var dc := signi(to_col - from_col)
	var r := from_row + dr
	var c := from_col + dc
	while r != to_row or c != to_col:
		if board[r][c] != "":
			return false
		r += dr
		c += dc
	return true


func _apply_castling(san: String, is_white: bool) -> bool:
	var row := 7 if is_white else 0
	if san == "O-O":
		# Kingside
		_execute_move(row, 4, row, 6)  # King e->g
		_execute_move(row, 7, row, 5)  # Rook h->f
	else:
		# Queenside
		_execute_move(row, 4, row, 2)  # King e->c
		_execute_move(row, 0, row, 3)  # Rook a->d
	active_color = "b" if is_white else "w"
	return true
