extends Node

## PuzzleService — Fetches chess puzzles from the Lichess API with offline fallback.
## Converts Lichess format (PGN + initialPly + solution) into the internal puzzle format
## used by ChessBoardLogic.
##
## Lichess puzzle format:
##   solution[0] = opponent's setup move (played automatically before player input)
##   solution[1] = player's first move
##   solution[2] = opponent's response
##   solution[3] = player's second move  ...etc
##
## Internal format after conversion:
##   fen         = board state AFTER the setup move (solution[0]) is played
##   solution[]  = remaining moves (solution[1..]), alternating player/opponent
##   player_moves[]  = indices into solution[] that are player moves (0, 2, 4...)
##   opponent_moves[] = indices into solution[] that are opponent responses (1, 3, 5...)

signal puzzle_fetched(puzzle: Dictionary)
signal puzzle_fetch_failed(reason: String)

const LICHESS_API_DAILY := "https://lichess.org/api/puzzle/daily"
const LICHESS_API_NEXT  := "https://lichess.org/api/puzzle/next"

## Minimum number of player moves a puzzle must have (solution moves excluding setup + opponent responses)
const MIN_PLAYER_MOVES := 2
## Maximum player moves (keeps puzzles from dragging on during pressure cooker)
const MAX_PLAYER_MOVES := 5

var _http: HTTPRequest
var _cache: Array[Dictionary] = []  # Pre-fetched puzzles ready to serve
const CACHE_TARGET := 3

func _ready() -> void:
	_http = HTTPRequest.new()
	_http.timeout = 8.0
	add_child(_http)


# =============================================================================
# Public API
# =============================================================================

## Request a puzzle. Emits puzzle_fetched or puzzle_fetch_failed.
## If a cached puzzle is available it's returned immediately.
func fetch_puzzle() -> void:
	if not _cache.is_empty():
		var puzzle: Dictionary = _cache.pop_front()
		puzzle_fetched.emit(puzzle)
		# Top up cache in background
		_prefetch_one()
		return

	_request_from_lichess()


## Blocking-style helper: returns a puzzle Dictionary directly.
## Falls back to local JSON if the network request fails or times out.
func get_puzzle_or_fallback() -> Dictionary:
	if not _cache.is_empty():
		var puzzle: Dictionary = _cache.pop_front()
		_prefetch_one()
		return puzzle

	# Try a synchronous-ish fetch — but since Godot HTTP is async,
	# callers should prefer fetch_puzzle() + signal. This is the fallback path
	# used when the caller needs a puzzle NOW (e.g., GameManager.get_puzzle_for_opponent).
	return _get_local_fallback()


## Pre-warm the cache (call once at game start or between fights).
func prefetch(count: int = CACHE_TARGET) -> void:
	for i in count:
		_prefetch_one()


# =============================================================================
# Lichess API
# =============================================================================

func _request_from_lichess() -> void:
	if _http.get_http_client_status() != HTTPClient.STATUS_DISCONNECTED:
		# Already in-flight — fall back
		puzzle_fetch_failed.emit("HTTP client busy")
		return

	_http.request_completed.connect(_on_request_completed, CONNECT_ONE_SHOT)
	var err := _http.request(LICHESS_API_NEXT, ["Accept: application/json"])
	if err != OK:
		puzzle_fetch_failed.emit("HTTP request failed: %d" % err)


func _on_request_completed(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	if result != HTTPRequest.RESULT_SUCCESS or response_code != 200:
		puzzle_fetch_failed.emit("Lichess API error: result=%d code=%d" % [result, response_code])
		return

	var json := JSON.new()
	if json.parse(body.get_string_from_utf8()) != OK:
		puzzle_fetch_failed.emit("JSON parse error")
		return

	var data: Dictionary = json.data
	var puzzle := _convert_lichess_puzzle(data)
	if puzzle.is_empty():
		puzzle_fetch_failed.emit("Puzzle conversion failed or filtered out")
		return

	puzzle_fetched.emit(puzzle)


func _prefetch_one() -> void:
	# Use a dedicated HTTPRequest node so we don't collide with the main one
	var http := HTTPRequest.new()
	http.timeout = 10.0
	add_child(http)
	http.request_completed.connect(_on_prefetch_completed.bind(http), CONNECT_ONE_SHOT)
	var err := http.request(LICHESS_API_NEXT, ["Accept: application/json"])
	if err != OK:
		http.queue_free()


func _on_prefetch_completed(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray, http: HTTPRequest) -> void:
	http.queue_free()
	if result != HTTPRequest.RESULT_SUCCESS or response_code != 200:
		return

	var json := JSON.new()
	if json.parse(body.get_string_from_utf8()) != OK:
		return

	var puzzle := _convert_lichess_puzzle(json.data)
	if puzzle.is_empty():
		return

	if _cache.size() < CACHE_TARGET * 2:
		_cache.append(puzzle)


# =============================================================================
# Conversion: Lichess → Internal Format
# =============================================================================

## Converts a Lichess API response into our internal puzzle Dictionary.
##
## Lichess gives us:
##   game.pgn        — full game in SAN (e.g. "e4 e5 Nf3 Nc6 ...")
##   puzzle.initialPly — ply count where the puzzle begins
##   puzzle.solution  — UCI moves, first is opponent's setup move
##   puzzle.rating    — Lichess rating
##   puzzle.themes    — ["fork", "short", ...]
##   puzzle.id        — unique ID
##
## Some endpoints (like /daily) also include puzzle.fen directly.
##
## We produce:
##   { id, fen, setup_move, solution, themes, difficulty, description, rating,
##     player_moves, opponent_moves }
func _convert_lichess_puzzle(data: Dictionary) -> Dictionary:
	var game_data: Dictionary = data.get("game", {})
	var puzzle_data: Dictionary = data.get("puzzle", {})

	var lichess_solution: Array = puzzle_data.get("solution", [])
	if lichess_solution.size() < 3:
		# Need at least: setup + player_move_1 + opponent_response + player_move_2
		# That's 4 moves minimum for 2 player moves, but we accept 3 (2 player moves
		# if the last move is the final player move with no opponent response)
		return {}

	# --- Determine the FEN at puzzle start ---
	var fen: String = puzzle_data.get("fen", "")
	if fen == "":
		# No FEN provided — derive from PGN + initialPly
		var pgn: String = game_data.get("pgn", "")
		var initial_ply: int = puzzle_data.get("initialPly", 0)
		fen = _fen_from_pgn(pgn, initial_ply)
		if fen == "":
			return {}

	# --- Apply the setup move (solution[0]) to get the actual puzzle position ---
	var setup_move: String = lichess_solution[0]
	var post_setup_fen := _apply_uci_move_to_fen(fen, setup_move)
	if post_setup_fen == "":
		post_setup_fen = fen  # Fallback: use original FEN if move application fails

	# --- Build internal solution (everything after setup move) ---
	var internal_solution: Array = lichess_solution.slice(1)

	# Count player moves (indices 0, 2, 4... in internal_solution)
	var player_move_count := ceili(float(internal_solution.size()) / 2.0)
	if player_move_count < MIN_PLAYER_MOVES or player_move_count > MAX_PLAYER_MOVES:
		return {}

	# --- Classify moves ---
	var player_moves: Array[int] = []
	var opponent_moves: Array[int] = []
	for i in internal_solution.size():
		if i % 2 == 0:
			player_moves.append(i)
		else:
			opponent_moves.append(i)

	# --- Map Lichess rating to difficulty 1–5 ---
	var rating: int = puzzle_data.get("rating", 1500)
	var difficulty := _rating_to_difficulty(rating)

	var themes: Array = puzzle_data.get("themes", [])
	var description := _build_description(themes, player_move_count)

	return {
		"id": puzzle_data.get("id", "lichess_%d" % randi()),
		"fen": post_setup_fen,
		"setup_move": setup_move,
		"solution": internal_solution,
		"player_moves": player_moves,
		"opponent_moves": opponent_moves,
		"themes": themes,
		"difficulty": difficulty,
		"rating": rating,
		"description": description,
		"source": "lichess",
	}


## Replay a PGN (SAN move list) up to a given ply and return the resulting FEN.
## This uses ChessBoardLogic for board state tracking.
func _fen_from_pgn(pgn: String, target_ply: int) -> String:
	if pgn == "" or target_ply <= 0:
		return "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1"

	# PGN from Lichess is space-separated SAN moves (no move numbers)
	var san_moves := pgn.split(" ")
	# We only need to replay `target_ply` moves
	var moves_to_play := mini(target_ply, san_moves.size())

	# Use a temporary board to replay
	var board := ChessBoardLogic.new()
	board.load_fen("rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1")

	for i in moves_to_play:
		var san: String = san_moves[i].strip_edges()
		if san == "" or san.ends_with("."):
			continue
		# Strip check/mate symbols and annotations
		san = san.replace("+", "").replace("#", "").replace("!", "").replace("?", "")
		var is_white := (i % 2 == 0)
		if not board.apply_san_move(san, is_white):
			push_warning("PuzzleService: Failed to apply SAN move '%s' at ply %d" % [san, i])
			break

	return board.to_fen()


## Apply a single UCI move to a FEN string and return the new FEN.
func _apply_uci_move_to_fen(fen: String, uci_move: String) -> String:
	var board := ChessBoardLogic.new()
	board.load_fen(fen)
	var from := board.uci_to_coords(uci_move.substr(0, 2))
	var to := board.uci_to_coords(uci_move.substr(2, 2))
	board._execute_move(from.y, from.x, to.y, to.x)
	# Handle promotion (5th char in UCI, e.g. "e7e8q")
	if uci_move.length() == 5:
		var promo_char: String = uci_move[4]
		# Determine color from FEN active side
		var is_white := fen.split(" ")[1] == "w" if " " in fen else true
		board.board[to.y][to.x] = promo_char.to_upper() if is_white else promo_char.to_lower()
	board.flip_active_color()
	return board.to_fen()


func _rating_to_difficulty(rating: int) -> int:
	if rating < 1200:
		return 1
	elif rating < 1500:
		return 2
	elif rating < 1800:
		return 3
	elif rating < 2100:
		return 4
	else:
		return 5


func _build_description(themes: Array, move_count: int) -> String:
	var theme_str := ""
	# Pick the most interesting theme for display
	var display_themes := ["mateIn1", "mateIn2", "mateIn3", "fork", "pin",
		"discoveredAttack", "sacrifice", "deflection", "skewer",
		"backRankMate", "smotheredMate", "hookMate", "arabianMate"]
	for t in display_themes:
		if t in themes:
			theme_str = t.capitalize()
			break
	if theme_str == "":
		theme_str = themes[0].capitalize() if not themes.is_empty() else "Tactics"

	var moves_text := "%d move%s" % [move_count, "" if move_count == 1 else "s"]
	return "%s — Find the best %s!" % [theme_str, moves_text]


# =============================================================================
# Offline Fallback
# =============================================================================

func _get_local_fallback() -> Dictionary:
	# Delegate to GameManager's existing local puzzle pools
	var difficulty: int = GameManager.current_opponent.get("chess_difficulty", 1)
	var pool: Array = []

	if difficulty <= 2:
		pool = GameManager.all_puzzles_easy.duplicate()
	elif difficulty <= 4:
		pool = GameManager.all_puzzles_medium.duplicate()
	else:
		pool = GameManager.all_puzzles_hard.duplicate()

	if pool.is_empty():
		pool = GameManager.all_puzzles_easy.duplicate()

	pool = GameManager._filter_unused(pool)
	pool.shuffle()
	var puzzle: Dictionary = pool[0]

	# Normalize local puzzles to have player_moves/opponent_moves arrays
	if not puzzle.has("player_moves"):
		var sol: Array = puzzle.get("solution", [])
		var player_moves: Array[int] = []
		var opponent_moves: Array[int] = []
		for i in sol.size():
			if i % 2 == 0:
				player_moves.append(i)
			else:
				opponent_moves.append(i)
		puzzle["player_moves"] = player_moves
		puzzle["opponent_moves"] = opponent_moves
		puzzle["source"] = "local"
		if not puzzle.has("setup_move"):
			puzzle["setup_move"] = ""

	return puzzle
