extends Node

## Global game state manager — holds all run state, handles transitions

signal phase_changed(phase: String)
signal fight_started(opponent_index: int)
signal fight_ended(won: bool)
signal run_ended(won: bool)
signal set_bonus_activated(bonus: Dictionary)

# --- Enums ---
enum GamePhase { MENU, FIGHTER_SELECT, TOURNAMENT, OPPONENT_REVEAL, CHESS, BOXING, PERK_DRAFT, PATH_FORK, RESULTS }
enum FightResult { IN_PROGRESS, PLAYER_WIN, PLAYER_LOSE }

# --- Run State ---
var current_phase: GamePhase = GamePhase.MENU
var run_active: bool = false
var current_opponent_index: int = 0
var total_opponents: int = 3
var current_round_in_fight: int = 0
var max_rounds_per_fight: int = 4

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

# --- Heat System (replaces chess_bonus) ---
var heat: float = 1.0            # Current heat multiplier (1.0–5.0)
var previous_heat: float = 0.0   # Retained heat from last round
var base_heat_bonus: float = 0.0 # Permanent bonuses (Flow State, sacrifice set bonus)
var chess_time_remaining: float = 0.0
var chess_solve_time: float = 0.0
var chess_mistakes: int = 0

# --- Legacy compat (read-only, computed from heat) ---
var chess_bonus: float:
	get: return clampf((heat - 1.0) / 4.0, 0.0, 1.0)

# --- Perks ---
var active_perks: Array[Dictionary] = []
var tag_counts: Dictionary = {}
var active_set_bonuses: Array = []
var blood_sacrifice_stacks: int = 0
var queens_gambit_active: bool = false  # Next draft = 5 Rare choices
var opponent_perks: Array = []  # Boss perks (Magnus only)
var chosen_path: String = ""  # "elena" or "marcus"
var fight_order: Array = []  # Ordered opponent IDs for this run

# --- Stats ---
var stats: Dictionary = {}

# --- Loaded Data ---
var all_puzzles_easy: Array = []
var all_puzzles_medium: Array = []
var all_puzzles_hard: Array = []
var all_perks: Array = []
var all_opponents: Array = []
var all_fighters: Array = []
var all_set_bonuses: Array = []
var all_boss_perks: Array = []

func _ready() -> void:
	_load_data()

func _load_data() -> void:
	all_puzzles_easy = _load_json("res://data/puzzles/puzzles_easy.json")
	all_puzzles_medium = _load_json("res://data/puzzles/puzzles_medium.json")
	all_puzzles_hard = _load_json("res://data/puzzles/puzzles_hard.json")
	all_perks = _load_json("res://data/perks.json")
	all_opponents = _load_json("res://data/opponents.json")
	all_fighters = _load_json("res://data/fighters.json")
	all_set_bonuses = _load_json("res://data/set_bonuses.json")
	all_boss_perks = _load_json("res://data/boss_perks.json")

func _load_json(path: String) -> Array:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_warning("Failed to load: " + path)
		return []
	var json := JSON.new()
	var parse_result := json.parse(file.get_as_text())
	file.close()
	if parse_result != OK:
		push_warning("Failed to parse JSON: " + path)
		return []
	if json.data is Array:
		return json.data
	return []

# =============================================================================
# Run Management
# =============================================================================

func start_new_run(fighter: Dictionary) -> void:
	run_active = true
	current_opponent_index = 0
	current_round_in_fight = 0

	player_fighter = fighter
	player_max_hp = int(fighter.get("hp", 100))
	player_hp = player_max_hp
	player_max_stamina = int(fighter.get("stamina", 100))
	player_stamina = player_max_stamina

	active_perks.clear()
	tag_counts.clear()
	active_set_bonuses.clear()
	blood_sacrifice_stacks = 0
	queens_gambit_active = false
	base_heat_bonus = 0.0
	heat = 1.0
	previous_heat = 0.0
	opponent_perks.clear()
	chosen_path = ""

	# Build initial fight order (first 2 opponents are mandatory)
	fight_order.clear()
	for opp in all_opponents:
		var pos: int = int(opp.get("fight_position", 99))
		var path: String = opp.get("path", "both")
		if pos <= 2 and (path == "both" or path == ""):
			fight_order.append(opp.get("id", ""))
	fight_order.sort_custom(func(a: String, b: String) -> bool:
		var a_opp := _get_opponent_by_id(a)
		var b_opp := _get_opponent_by_id(b)
		return int(a_opp.get("fight_position", 99)) < int(b_opp.get("fight_position", 99))
	)
	# Remaining opponents added after path fork
	total_opponents = 5

	_reset_stats()
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
		"heat_history": [],
	}

func _get_opponent_by_id(opp_id: String) -> Dictionary:
	for opp in all_opponents:
		if opp.get("id", "") == opp_id:
			return opp
	return {}

func set_path_choice(path: String) -> void:
	chosen_path = path
	# Add remaining opponents based on chosen path
	for opp in all_opponents:
		var opp_id: String = opp.get("id", "")
		if opp_id in fight_order:
			continue
		var opp_path: String = opp.get("path", "both")
		if opp_path == "both" or opp_path == chosen_path:
			fight_order.append(opp_id)
	# Boss is always last
	# Sort by fight_position to ensure correct order
	fight_order.sort_custom(func(a: String, b: String) -> bool:
		var a_opp := _get_opponent_by_id(a)
		var b_opp := _get_opponent_by_id(b)
		return int(a_opp.get("fight_position", 99)) < int(b_opp.get("fight_position", 99))
	)

func start_fight() -> void:
	if current_opponent_index >= fight_order.size():
		end_run(true)
		return

	var opp_id: String = fight_order[current_opponent_index]
	current_opponent = _get_opponent_by_id(opp_id)
	if current_opponent.is_empty():
		end_run(true)
		return
	opponent_max_hp = int(current_opponent.get("hp", 80))
	opponent_hp = opponent_max_hp
	opponent_max_stamina = int(current_opponent.get("stamina", 90))
	opponent_stamina = opponent_max_stamina
	current_round_in_fight = 0
	previous_heat = 0.0

	# Restore player stamina; HP gets decreasing heal per fight
	player_stamina = player_max_stamina
	var heal_pcts := [0.4, 0.3, 0.3, 0.2, 0.0]
	var heal_pct: float = heal_pcts[mini(current_opponent_index, heal_pcts.size() - 1)]
	player_hp = mini(player_hp + int(player_max_hp * heal_pct), player_max_hp)

	# Apply sacrifice set bonus (start at reduced HP but with heat bonus)
	_apply_fight_start_set_bonuses()

	# Apply max stamina perk
	if has_perk("max_stamina_bonus"):
		var bonus := int(get_perk_raw_value("max_stamina_bonus"))
		player_max_stamina += bonus
		player_stamina = player_max_stamina

	# Reset boss perks for new fight
	opponent_perks.clear()

	fight_started.emit(current_opponent_index)
	change_phase(GamePhase.OPPONENT_REVEAL)

func _apply_fight_start_set_bonuses() -> void:
	for bonus in active_set_bonuses:
		var effect: String = bonus.get("effect", "")
		if effect == "sacrifice_hp_heat":
			var hp_pct: float = bonus.get("values", {}).get("hp_percent", 0.8)
			var heat_add: float = bonus.get("values", {}).get("heat_bonus", 1.0)
			player_hp = int(player_max_hp * hp_pct)
			base_heat_bonus += heat_add
		elif effect == "sacrifice_hp_heat_extreme":
			var hp_pct: float = bonus.get("values", {}).get("hp_percent", 0.5)
			var heat_add: float = bonus.get("values", {}).get("heat_bonus", 2.0)
			player_hp = int(player_max_hp * hp_pct)
			base_heat_bonus += heat_add

func advance_fight_round() -> void:
	current_round_in_fight += 1

	# Retain heat between rounds
	previous_heat = HeatSystem.get_retained_heat(heat)

	# Check heat retention set bonus override
	for bonus in active_set_bonuses:
		if bonus.get("effect", "") == "heat_retention_bonus":
			var retention: float = bonus.get("values", {}).get("retention", 0.5)
			previous_heat = heat * retention

	# Corner Man perk: heal between boxing rounds
	if has_perk("corner_man") and current_round_in_fight > 1:
		var recovery := get_perk_raw_value("corner_man")
		player_hp = mini(player_hp + int(player_max_hp * recovery), player_max_hp)

	# Check win/lose conditions
	if opponent_hp <= 0:
		_win_fight()
		return
	if player_hp <= 0:
		_lose_fight()
		return

	if current_round_in_fight >= max_rounds_per_fight:
		var player_hp_pct := float(player_hp) / float(player_max_hp)
		var opp_hp_pct := float(opponent_hp) / float(opponent_max_hp)
		if player_hp_pct >= opp_hp_pct:
			_win_fight()
		else:
			_lose_fight()
		return

	# Boss: draft a perk before each boxing round
	var gimmick = current_opponent.get("gimmick", null)
	if gimmick is Dictionary and gimmick.get("type", "") == "perk_drafter":
		var drafted := GimmickSystem.draft_boss_perk(all_boss_perks, opponent_perks)
		if not drafted.is_empty():
			opponent_perks.append(drafted)

	if current_round_in_fight % 2 == 0:
		change_phase(GamePhase.CHESS)
	else:
		change_phase(GamePhase.BOXING)

func _win_fight() -> void:
	stats.fights_won += 1
	current_opponent_index += 1
	fight_ended.emit(true)

	if current_opponent_index >= fight_order.size():
		end_run(true)
	elif current_opponent_index == 2 and chosen_path == "":
		# After fight 2, show path fork (if path not yet chosen)
		change_phase(GamePhase.PERK_DRAFT)  # Draft first, then path fork
	else:
		change_phase(GamePhase.PERK_DRAFT)

func _lose_fight() -> void:
	fight_ended.emit(false)
	end_run(false)

var run_score: Dictionary = {}
var run_achievements: Array = []

func end_run(won: bool) -> void:
	run_active = false

	# Track boss perks at defeat for achievement
	stats["boss_perks_at_defeat"] = opponent_perks.size()

	# Calculate score
	run_score = ScoringSystem.calculate_score(stats, active_perks, total_opponents)

	# Check achievements
	run_achievements = AchievementSystem.check_achievements(
		stats, run_score, active_perks, won, SaveManager.unlocked_achievements
	)

	# Apply unlocks
	for ach in run_achievements:
		SaveManager.unlock_achievement(ach.get("id", ""))
		var unlock_type: String = ach.get("unlock_type", "")
		var unlock_id: String = ach.get("unlock_id", "")
		if unlock_type == "fighter":
			SaveManager.unlock_fighter(unlock_id)
		elif unlock_type == "perk":
			SaveManager.unlock_perk(unlock_id)

	# Record run
	SaveManager.record_run(run_score, chosen_path)

	run_ended.emit(won)
	change_phase(GamePhase.RESULTS)

# =============================================================================
# Heat System
# =============================================================================

func set_chess_result(solved: bool, time_remaining: float, solve_time: float, mistakes: int = 0) -> void:
	chess_time_remaining = time_remaining
	chess_solve_time = solve_time
	chess_mistakes = mistakes

	var difficulty: int = current_opponent.get("chess_difficulty", 1)

	if solved:
		stats.puzzles_solved += 1
		if solve_time < stats.fastest_puzzle_time:
			stats.fastest_puzzle_time = solve_time

		heat = HeatSystem.calculate_heat(
			time_remaining,
			get_chess_time_limit(),
			mistakes,
			difficulty,
			previous_heat,
			base_heat_bonus
		)

		# Perk: Blitz Mode — double heat from puzzles
		if has_perk("blitz"):
			var mult: float = get_perk_named_value("blitz", "heat_multiplier", 2.0)
			heat = clampf(heat * mult, HeatSystem.HEAT_MIN, HeatSystem.HEAT_MAX)

		# Perk: Last Second — triple heat if solved with <5s
		if has_perk("last_second"):
			var threshold: float = get_perk_named_value("last_second", "threshold_seconds", 5.0)
			if time_remaining <= threshold:
				var mult: float = get_perk_named_value("last_second", "heat_multiplier", 3.0)
				heat = clampf(heat * mult, HeatSystem.HEAT_MIN, HeatSystem.HEAT_MAX)

		# Perk: Deep Calculation — applied in chess_phase.gd where puzzle data is available

		# Perk: Mind Over Muscle — heat amplifier
		if has_perk("heat_amplifier"):
			var amp: float = get_perk_named_value("heat_amplifier", "amplifier", 1.5)
			heat = clampf(1.0 + (heat - 1.0) * amp, HeatSystem.HEAT_MIN, HeatSystem.HEAT_MAX)
	else:
		stats.puzzles_failed += 1
		heat = HeatSystem.calculate_fail_heat(previous_heat)

		# Perk: Last Second penalty on fail
		if has_perk("last_second"):
			var hp_cost := int(get_perk_named_value("last_second", "fail_hp_cost", 15.0))
			player_hp = maxi(1, player_hp - hp_cost)

	# Perk: Blood Sacrifice — lose HP per puzzle
	if has_perk("blood_sacrifice"):
		var hp_cost := int(get_perk_named_value("blood_sacrifice", "hp_cost", 5.0))
		player_hp = maxi(1, player_hp - hp_cost)
		blood_sacrifice_stacks += 1

	# Record heat history
	stats.heat_history.append(heat)

func get_heat() -> float:
	return heat

# =============================================================================
# Chess Time
# =============================================================================

func get_chess_time_limit() -> float:
	var base_time := 60.0
	for perk in active_perks:
		var effect: String = perk.get("effect", "")
		if effect == "chess_time_bonus":
			base_time += PerkSystem.get_named_value(perk, "time", 15.0)
		elif effect == "blitz":
			base_time *= PerkSystem.get_named_value(perk, "time_multiplier", 0.5)
		elif effect == "borrowed_time":
			base_time += PerkSystem.get_named_value(perk, "time_bonus", 30.0)

	# Set bonus: timing_2 adds +5s
	for bonus in active_set_bonuses:
		if bonus.get("effect", "") == "chess_time_set_bonus":
			base_time += bonus.get("values", {}).get("time", 5.0)

	return base_time

func get_free_mistakes() -> int:
	var count := 0
	for perk in active_perks:
		if perk.get("effect", "") == "free_mistake":
			count += int(PerkSystem.get_named_value(perk, "count", 1.0))
	return count

# =============================================================================
# Perk Helpers
# =============================================================================

func has_perk(effect_id: String) -> bool:
	for perk in active_perks:
		if perk.get("effect", "") == effect_id:
			return true
	return false

## Get the raw (unscaled) first value of a perk by effect ID.
func get_perk_raw_value(effect_id: String, default_val: float = 0.0) -> float:
	for perk in active_perks:
		if perk.get("effect", "") == effect_id:
			return PerkSystem.get_first_value(perk)
	return default_val

## Get a specific named value from a perk.
func get_perk_named_value(effect_id: String, value_name: String, default_val: float = 0.0) -> float:
	for perk in active_perks:
		if perk.get("effect", "") == effect_id:
			return PerkSystem.get_named_value(perk, value_name, default_val)
	return default_val

## Get perk value scaled by heat (if heat_scaled is true for that perk).
func get_perk_scaled_value(effect_id: String, default_val: float = 0.0) -> float:
	for perk in active_perks:
		if perk.get("effect", "") == effect_id:
			var raw := PerkSystem.get_first_value(perk)
			if PerkSystem.is_heat_scaled(perk):
				return HeatSystem.get_perk_multiplier(heat, raw)
			return raw
	return default_val

## Legacy compat: old callers that used get_perk_value
func get_perk_value(effect_id: String, default_val: float = 0.0) -> float:
	return get_perk_raw_value(effect_id, default_val)

func add_perk(perk: Dictionary) -> void:
	active_perks.append(perk)
	stats.perks_drafted += 1

	# Recalculate tags and set bonuses
	var old_bonuses := active_set_bonuses.duplicate()
	tag_counts = PerkSystem.count_tags(active_perks)
	active_set_bonuses = PerkSystem.get_active_set_bonuses(tag_counts, all_set_bonuses)

	# Check for newly activated set bonuses
	var old_ids := []
	for b in old_bonuses:
		old_ids.append(b.get("id", ""))
	for b in active_set_bonuses:
		if b.get("id", "") not in old_ids:
			set_bonus_activated.emit(b)

	# Apply immediate set bonus effects
	_apply_immediate_set_bonuses()

func _apply_immediate_set_bonuses() -> void:
	for bonus in active_set_bonuses:
		var effect: String = bonus.get("effect", "")
		if effect == "max_stamina_set_bonus":
			# Only apply once — check if already applied
			if not bonus.get("_applied", false):
				var stam: int = int(bonus.get("values", {}).get("stamina", 10))
				player_max_stamina += stam
				player_stamina = mini(player_stamina + stam, player_max_stamina)
				bonus["_applied"] = true

func get_perk_count_by_type(type: String) -> int:
	var count := 0
	for perk in active_perks:
		if perk.get("type", "") == type:
			count += 1
	return count

func get_tag_counts() -> Dictionary:
	return tag_counts

func get_active_set_bonuses_list() -> Array:
	return active_set_bonuses

# =============================================================================
# Puzzle Selection
# =============================================================================

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

# =============================================================================
# Draft Perks
# =============================================================================

func get_draft_choices(count: int = 3) -> Array:
	# Queen's Gambit: 5 rare choices
	if queens_gambit_active:
		queens_gambit_active = false
		var rare_perks := all_perks.filter(func(p): return p.get("rarity", "") == "rare")
		var owned_ids := []
		for p in active_perks:
			owned_ids.append(p.get("id", ""))
		rare_perks = rare_perks.filter(func(p): return p.get("id", "") not in owned_ids)
		rare_perks.shuffle()
		return rare_perks.slice(0, mini(5, rare_perks.size()))

	var available := all_perks.duplicate()
	var owned_ids := []
	for p in active_perks:
		owned_ids.append(p.get("id", ""))
	available = available.filter(func(p): return p.get("id", "") not in owned_ids)

	available.shuffle()
	return available.slice(0, mini(count, available.size()))

# =============================================================================
# Phase Management
# =============================================================================

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
		GamePhase.PATH_FORK:
			return "res://scenes/path_fork/path_fork.tscn"
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
		GamePhase.PATH_FORK: return "path_fork"
		GamePhase.RESULTS: return "results"
	return "unknown"
