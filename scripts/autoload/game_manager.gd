extends Node

## Global game state manager — holds all run state, handles transitions

signal phase_changed(phase: String)
signal fight_started(opponent_index: int)
signal fight_ended(won: bool)
signal run_ended(won: bool)

# --- Enums ---
enum GamePhase { MENU, FIGHTER_SELECT, TOURNAMENT, OPPONENT_REVEAL, CHESS, BOXING, PERK_DRAFT, RESULTS }
enum FightResult { IN_PROGRESS, PLAYER_WIN, PLAYER_LOSE }

# --- Run State ---
var current_phase: GamePhase = GamePhase.MENU
var run_active: bool = false
var current_opponent_index: int = 0
var total_opponents: int = 3  # MVP: 3 opponents
var current_round_in_fight: int = 0  # Alternating chess/boxing rounds within a fight
var max_rounds_per_fight: int = 4  # 2 chess + 2 boxing rounds

# --- Fighter State ---
var player_fighter: Dictionary = {}
var player_hp: int = 100
var player_max_hp: int = 100
var player_stamina: int = 100
var player_max_stamina: int = 100

# --- Opponent State ---
var current_opponent: Dictionary = {}
var opponent_hp: int = 0
var opponent_max_hp: int = 0
var opponent_stamina: int = 0
var opponent_max_stamina: int = 0

# --- Chess Bonus ---
var chess_bonus: float = 0.0  # 0.0 to 1.0, how well the player did in chess phase
var chess_time_remaining: float = 0.0
var chess_solved_fast: bool = false

# --- Perks ---
var active_perks: Array[Dictionary] = []

# --- Stats (for results screen) ---
var stats: Dictionary = {
	"puzzles_solved": 0,
	"puzzles_failed": 0,
	"total_damage_dealt": 0,
	"total_damage_taken": 0,
	"fastest_puzzle_time": 999.0,
	"fights_won": 0,
	"perks_drafted": 0,
}

# --- Loaded Data ---
var all_puzzles_easy: Array = []
var all_puzzles_medium: Array = []
var all_puzzles_hard: Array = []
var all_perks: Array = []
var all_opponents: Array = []
var all_fighters: Array = []

func _ready() -> void:
	_load_data()

func _load_data() -> void:
	all_puzzles_easy = _load_json("res://data/puzzles/puzzles_easy.json")
	all_puzzles_medium = _load_json("res://data/puzzles/puzzles_medium.json")
	all_puzzles_hard = _load_json("res://data/puzzles/puzzles_hard.json")
	all_perks = _load_json("res://data/perks.json")
	all_opponents = _load_json("res://data/opponents.json")
	all_fighters = _load_json("res://data/fighters.json")

func _load_json(path: String) -> Array:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_warning("Failed to load: " + path)
		return []
	var json := JSON.new()
	var result := json.parse(file.get_as_text())
	file.close()
	if result != OK:
		push_warning("Failed to parse JSON: " + path)
		return []
	return json.data

# --- Run Management ---

func start_new_run(fighter: Dictionary) -> void:
	run_active = true
	current_opponent_index = 0
	current_round_in_fight = 0

	player_fighter = fighter
	player_max_hp = fighter.get("hp", 100)
	player_hp = player_max_hp
	player_max_stamina = fighter.get("stamina", 100)
	player_stamina = player_max_stamina

	active_perks.clear()
	_reset_stats()

	chess_bonus = 0.0
	chess_time_remaining = 0.0
	chess_solved_fast = false

	change_phase(GamePhase.TOURNAMENT)

func _reset_stats() -> void:
	stats = {
		"puzzles_solved": 0,
		"puzzles_failed": 0,
		"total_damage_dealt": 0,
		"total_damage_taken": 0,
		"fastest_puzzle_time": 999.0,
		"fights_won": 0,
		"perks_drafted": 0,
	}

func start_fight() -> void:
	if current_opponent_index >= all_opponents.size():
		end_run(true)
		return

	current_opponent = all_opponents[current_opponent_index]
	opponent_max_hp = current_opponent.get("hp", 80)
	opponent_hp = opponent_max_hp
	opponent_max_stamina = current_opponent.get("stamina", 90)
	opponent_stamina = opponent_max_stamina
	current_round_in_fight = 0

	# Restore player stamina between fights (HP persists but gets partial heal)
	player_stamina = player_max_stamina
	player_hp = mini(player_hp + int(player_max_hp * 0.3), player_max_hp)

	fight_started.emit(current_opponent_index)
	change_phase(GamePhase.OPPONENT_REVEAL)

func advance_fight_round() -> void:
	current_round_in_fight += 1

	# Check win/lose conditions
	if opponent_hp <= 0:
		_win_fight()
		return
	if player_hp <= 0:
		_lose_fight()
		return

	# Alternate chess/boxing - even rounds = chess, odd = boxing
	if current_round_in_fight >= max_rounds_per_fight:
		# Fight goes to decision - whoever has more HP% wins
		var player_hp_pct := float(player_hp) / float(player_max_hp)
		var opp_hp_pct := float(opponent_hp) / float(opponent_max_hp)
		if player_hp_pct >= opp_hp_pct:
			_win_fight()
		else:
			_lose_fight()
		return

	if current_round_in_fight % 2 == 0:
		change_phase(GamePhase.CHESS)
	else:
		change_phase(GamePhase.BOXING)

func _win_fight() -> void:
	stats.fights_won += 1
	current_opponent_index += 1
	fight_ended.emit(true)

	if current_opponent_index >= total_opponents:
		end_run(true)
	else:
		change_phase(GamePhase.PERK_DRAFT)

func _lose_fight() -> void:
	fight_ended.emit(false)
	end_run(false)

func end_run(won: bool) -> void:
	run_active = false
	run_ended.emit(won)
	change_phase(GamePhase.RESULTS)

# --- Chess Bonus ---

func set_chess_result(solved: bool, time_remaining: float, solve_time: float) -> void:
	chess_time_remaining = time_remaining
	if solved:
		stats.puzzles_solved += 1
		if solve_time < stats.fastest_puzzle_time:
			stats.fastest_puzzle_time = solve_time
		# Bonus scales with time remaining (0.0 to 1.0)
		chess_bonus = clampf(time_remaining / 60.0, 0.1, 1.0)
		chess_solved_fast = solve_time < 10.0
	else:
		stats.puzzles_failed += 1
		chess_bonus = 0.0
		chess_solved_fast = false

	# Apply perk modifiers to chess bonus
	var bonus_multiplier := 1.0
	for perk in active_perks:
		if perk.effect == "chess_bonus_multiplier":
			bonus_multiplier *= perk.value
		if perk.effect == "blitz":
			bonus_multiplier *= perk.value
	chess_bonus *= bonus_multiplier

func get_chess_time_limit() -> float:
	var base_time := 60.0
	for perk in active_perks:
		if perk.effect == "chess_time_bonus":
			base_time += perk.value
		if perk.effect == "blitz":
			base_time *= 0.5
		if perk.effect == "block_chess_time":
			base_time += perk.get("accumulated", 0.0)
	return base_time

func get_free_mistakes() -> int:
	var count := 0
	for perk in active_perks:
		if perk.effect == "free_mistake":
			count += int(perk.value)
	return count

# --- Perk Helpers ---

func has_perk(effect_id: String) -> bool:
	for perk in active_perks:
		if perk.effect == effect_id:
			return true
	return false

func get_perk_value(effect_id: String, default_val: float = 0.0) -> float:
	for perk in active_perks:
		if perk.effect == effect_id:
			return perk.value
	return default_val

func add_perk(perk: Dictionary) -> void:
	active_perks.append(perk)
	stats.perks_drafted += 1

func get_perk_count_by_type(type: String) -> int:
	var count := 0
	for perk in active_perks:
		if perk.type == type:
			count += 1
	return count

# --- Puzzle Selection ---

func get_puzzle_for_opponent() -> Dictionary:
	var difficulty: int = current_opponent.get("chess_difficulty", 1)
	var pool: Array = []

	if difficulty <= 2:
		pool = all_puzzles_easy.duplicate()
	elif difficulty <= 4:
		pool = all_puzzles_medium.duplicate()
	else:
		pool = all_puzzles_hard.duplicate()

	if pool.is_empty():
		pool = all_puzzles_easy.duplicate()

	pool.shuffle()
	return pool[0]

# --- Draft Perks ---

func get_draft_choices(count: int = 3) -> Array:
	var available := all_perks.duplicate()
	# Remove perks already owned
	var owned_ids := []
	for p in active_perks:
		owned_ids.append(p.id)
	available = available.filter(func(p): return p.id not in owned_ids)

	available.shuffle()
	return available.slice(0, mini(count, available.size()))

# --- Phase Management ---

func change_phase(new_phase: GamePhase) -> void:
	current_phase = new_phase
	phase_changed.emit(_phase_to_string(new_phase))

	var scene_path := _get_scene_for_phase(new_phase)
	if scene_path != "":
		get_tree().change_scene_to_file(scene_path)

func _get_scene_for_phase(phase: GamePhase) -> String:
	match phase:
		GamePhase.MENU:
			return "res://scenes/main_menu/main_menu.tscn"
		GamePhase.FIGHTER_SELECT:
			return "res://scenes/fighter_select/fighter_select.tscn"
		GamePhase.TOURNAMENT:
			return "res://scenes/tournament/tournament_bracket.tscn"
		GamePhase.OPPONENT_REVEAL:
			return "res://scenes/tournament/opponent_reveal.tscn"
		GamePhase.CHESS:
			return "res://scenes/chess_phase/chess_phase.tscn"
		GamePhase.BOXING:
			return "res://scenes/boxing_phase/boxing_phase.tscn"
		GamePhase.PERK_DRAFT:
			return "res://scenes/perk_draft/perk_draft.tscn"
		GamePhase.RESULTS:
			return "res://scenes/results/run_results.tscn"
	return ""

func _phase_to_string(phase: GamePhase) -> String:
	match phase:
		GamePhase.MENU: return "menu"
		GamePhase.FIGHTER_SELECT: return "fighter_select"
		GamePhase.TOURNAMENT: return "tournament"
		GamePhase.OPPONENT_REVEAL: return "opponent_reveal"
		GamePhase.CHESS: return "chess"
		GamePhase.BOXING: return "boxing"
		GamePhase.PERK_DRAFT: return "perk_draft"
		GamePhase.RESULTS: return "results"
	return "unknown"
