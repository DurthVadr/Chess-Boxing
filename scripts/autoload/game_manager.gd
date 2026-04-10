extends Node

## Global game state manager — holds all run state, handles transitions

signal phase_changed(phase: String)
signal fight_started(opponent_index: int)
signal fight_ended(won: bool)
signal run_ended(won: bool)
signal set_bonus_activated(bonus: Dictionary)

# --- Enums ---
enum GamePhase { MENU, FIGHTER_SELECT, TOURNAMENT, OPPONENT_REVEAL, CHESS, BOXING, MOVE_UPGRADE, PERK_DRAFT, SHOP, RESULTS, CUTSCENE }
enum FightResult { IN_PROGRESS, PLAYER_WIN, PLAYER_LOSE }

# --- Cutscene State ---
## Key into data/story.json; set before calling change_phase(CUTSCENE).
var pending_cutscene: String = ""
## Phase to transition to once the cutscene ends.
var post_cutscene_phase: GamePhase = GamePhase.TOURNAMENT
## Cutscenes already seen this run; prevents double-triggers.
var seen_cutscenes: Array[String] = []

# --- Run State ---
var current_phase: GamePhase = GamePhase.MENU
var run_active: bool = false
var current_opponent_index: int = 0
var total_opponents: int = 3
var current_round_in_fight: int = 0
var max_rounds_per_fight: int = 4
var run_tournament_number: int = 1   # Snapshot of tournament number for this run
var run_elo_deltas: Array = []       # ELO changes per fight this run

# --- Fighter State ---
var player_fighter: Dictionary = {}
var player_hp: int = 100
var player_max_hp: int = 100
# --- Opponent State ---
var current_opponent: Dictionary = {}
var opponent_hp: int = 0
var opponent_max_hp: int = 0

# --- Move Progression (Legacy — kept for compat) ---
var unlocked_moves: Array = []
var equipped_moves: Array = []
var move_slots: int = 1
var jab_upgraded: bool = false

# --- Reel System ---
var reel_symbols: Array = []         # Array of 3 Arrays, each containing BoxingAction.ActionType
									 # e.g. [[JAB,JAB,JAB,JAB], [JAB,JAB,JAB,JAB], [JAB,JAB,JAB,JAB]]

# --- Heat System (replaces chess_bonus) ---
var heat: float = 1.0            # Current heat multiplier (1.0–5.0)
var previous_heat: float = 0.0   # Retained heat from last round
var base_heat_bonus: float = 0.0 # Permanent bonuses (Flow State, sacrifice set bonus)
var chess_time_remaining: float = 0.0
var chess_solve_time: float = 0.0
var chess_mistakes: int = 0
var current_fight_puzzle_solved: bool = false  # Reset per fight

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
var fight_order: Array = []         # Ordered opponent IDs for this run
var fight_order_complete: bool = false  # True once the position-3 boss has been selected

# --- Shop & Tactic Cards ---
var player_rep: int = 0                    # Shared currency
var tactic_hand: Array = []                # Current tactic cards (max 3)
var active_tactics: Array = []             # Tactics played THIS turn (cleared each turn)
var endgame_damage_stacks: int = 0         # Permanent +damage from Endgame cards (per fight)
var shop_purchase_counts: Dictionary = {}  # {item_id: times_bought} for cap tracking
var shop_chess_time_bonus: float = 0.0     # Cumulative chess time from shop
var shop_free_mistakes: int = 0            # Cumulative free mistakes from shop
var shop_base_damage_bonus: int = 0        # Cumulative base damage from shop
var has_draft_reroll: bool = false          # Next draft gets rerolled
var has_puzzle_scout: bool = false          # Show puzzle theme before next fight
var has_scouting_report: bool = false       # Show opponent gimmick before next fight
var pending_perk_removal: bool = false      # Player needs to pick a perk to remove

# --- Training Camp (Perk Cards) ---
var owned_training_cards: Array[PerkCard] = []
var training_card_used_flags: Dictionary = {} # {card_id: true} for one-time actives
var last_chess_piece_moved: String = ""        # e.g. "Q", "R", "P"

# --- Puzzle dedup within a run ---
var _used_puzzle_ids: Array = []

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
	run_tournament_number = SaveManager.tournament_number
	run_elo_deltas.clear()
	seen_cutscenes.clear()
	pending_cutscene = ""
	post_cutscene_phase = GamePhase.TOURNAMENT

	player_fighter = fighter
	player_max_hp = int(fighter.get("hp", 100))
	player_hp = player_max_hp

	# Move progression — legacy
	unlocked_moves = [BoxingAction.ActionType.JAB]
	equipped_moves = [BoxingAction.ActionType.JAB]
	move_slots = 1
	jab_upgraded = false

	# Reel system — 3 reels, each starts with 4x JAB
	reel_symbols = ReelSystem.create_default_reels()

	_used_puzzle_ids.clear()
	active_perks.clear()
	tag_counts.clear()
	active_set_bonuses.clear()
	blood_sacrifice_stacks = 0
	queens_gambit_active = false
	base_heat_bonus = 0.0
	heat = 1.0
	previous_heat = 0.0
	opponent_perks.clear()

	# Shop & tactic card reset
	player_rep = 0
	tactic_hand.clear()
	active_tactics.clear()
	endgame_damage_stacks = 0
	shop_purchase_counts.clear()
	shop_chess_time_bonus = 0.0
	shop_free_mistakes = 0
	shop_base_damage_bonus = 0
	has_draft_reroll = false
	has_puzzle_scout = false
	has_scouting_report = false
	pending_perk_removal = false

	# Training Camp reset
	owned_training_cards.clear()
	training_card_used_flags.clear()
	last_chess_piece_moved = ""

	# Build initial fight order — the first 2 mandatory opponents (position 1 & 2)
	fight_order.clear()
	fight_order_complete = false
	for opp in all_opponents:
		var pos: int = int(opp.get("fight_position", 99))
		if pos <= 2:
			fight_order.append(opp.get("id", ""))
	fight_order.sort_custom(func(a: String, b: String) -> bool:
		var a_opp := _get_opponent_by_id(a)
		var b_opp := _get_opponent_by_id(b)
		return int(a_opp.get("fight_position", 99)) < int(b_opp.get("fight_position", 99))
	)
	# The position-3 boss + final boss are appended by select_random_boss() after SF
	total_opponents = 4

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

## Automatically picks the position-3 semi-final boss using drafted perk tags, then
## appends any remaining "both"-path opponents and finalises the fight_order.
## Called by shop.gd after the post-SF shop visit.
func select_random_boss() -> void:
	# Gather candidates at fight_position == 3 not already in the run
	var candidates: Array = []
	for opp in all_opponents:
		if int(opp.get("fight_position", 99)) == 3 and opp.get("id", "") not in fight_order:
			candidates.append(opp)

	if candidates.is_empty():
		_finalize_fight_order()
		return

	var chosen: Dictionary
	if candidates.size() == 1:
		chosen = candidates[0]
	else:
		# Weight by perk tags:
		#   power / speed / boxing  → Turtle  (walls up against brute-force players)
		#   defensive / chess / timing / tempo → Technician (exploits strategic builds)
		var aggro_score: int = (
			tag_counts.get("power", 0) +
			tag_counts.get("speed", 0) +
			tag_counts.get("boxing", 0)
		)
		var strat_score: int = (
			tag_counts.get("defensive", 0) +
			tag_counts.get("chess", 0) +
			tag_counts.get("timing", 0) +
			tag_counts.get("tempo", 0)
		)

		var turtle_opp: Dictionary = {}
		var tech_opp: Dictionary = {}
		for c in candidates:
			match c.get("archetype", ""):
				"turtle":      turtle_opp = c
				"technician":  tech_opp   = c

		if aggro_score > strat_score and not turtle_opp.is_empty():
			chosen = turtle_opp
		elif strat_score > aggro_score and not tech_opp.is_empty():
			chosen = tech_opp
		else:
			# Tied — pure random
			candidates.shuffle()
			chosen = candidates[0]

	fight_order.append(chosen.get("id", ""))
	_finalize_fight_order()


## Appends all remaining path=="both" opponents (e.g. Magnus) and sorts fight_order.
func _finalize_fight_order() -> void:
	for opp in all_opponents:
		var opp_id: String = opp.get("id", "")
		if opp_id in fight_order:
			continue
		if opp.get("path", "both") == "both":
			fight_order.append(opp_id)
	fight_order.sort_custom(func(a: String, b: String) -> bool:
		return int(_get_opponent_by_id(a).get("fight_position", 99)) < \
			   int(_get_opponent_by_id(b).get("fight_position", 99))
	)
	fight_order_complete = true

func start_fight() -> void:
	if current_opponent_index >= fight_order.size():
		end_run(true)
		return

	var opp_id: String = fight_order[current_opponent_index]
	current_opponent = _get_opponent_by_id(opp_id)
	if current_opponent.is_empty():
		end_run(true)
		return
	# Scale opponent stats by tournament number (each tournament = +15% HP, +10% damage)
	var tourney_scale := get_tournament_scale()
	opponent_max_hp = int(current_opponent.get("hp", 80) * tourney_scale.hp)
	opponent_hp = opponent_max_hp
	current_round_in_fight = 0
	previous_heat = 0.0
	current_fight_puzzle_solved = false

	# HP gets decreasing heal per fight
	var heal_pcts := [0.4, 0.3, 0.3, 0.2, 0.0]
	var heal_pct: float = heal_pcts[mini(current_opponent_index, heal_pcts.size() - 1)]
	player_hp = mini(player_hp + int(player_max_hp * heal_pct), player_max_hp)

	# Apply sacrifice set bonus (start at reduced HP but with heat bonus)
	_apply_fight_start_set_bonuses()

	# Reset boss perks for new fight
	opponent_perks.clear()

	# Pre-warm puzzle cache for this fight
	PuzzleService.prefetch()

	# Reset per-fight tactic state (endgame stacks, active tactics)
	reset_fight_tactics()

	# Consume intel items
	has_puzzle_scout = false
	has_scouting_report = false

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

	change_phase(GamePhase.BOXING)

func _win_fight() -> void:
	stats.fights_won += 1

	# Apply ELO change for this fight
	var opp_elo := get_opponent_elo(current_opponent)
	var delta := SaveManager.apply_fight_elo(opp_elo, true)
	run_elo_deltas.append({"opponent": current_opponent.get("name", "?"), "delta": delta, "won": true})

	current_opponent_index += 1
	fight_ended.emit(true)

	# Award Rep for shop purchases
	var rep_earned := award_fight_rep()
	stats["last_rep_breakdown"] = rep_earned

	# Reset per-fight tactic state
	reset_fight_tactics()

	if fight_order_complete and current_opponent_index >= fight_order.size():
		end_run(true)
	else:
		change_phase(GamePhase.SHOP)

func _lose_fight() -> void:
	# Apply ELO change for the loss
	var opp_elo := get_opponent_elo(current_opponent)
	var delta := SaveManager.apply_fight_elo(opp_elo, false)
	run_elo_deltas.append({"opponent": current_opponent.get("name", "?"), "delta": delta, "won": false})

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
	SaveManager.record_run(run_score, "")

	run_ended.emit(won)
	change_phase(GamePhase.RESULTS)

# =============================================================================
# ELO & Tournament Scaling
# =============================================================================

## Get an opponent's effective ELO (base + tournament scaling).
func get_opponent_elo(opp: Dictionary) -> int:
	var base_elo: int = int(opp.get("base_elo", 1000))
	# Each tournament beyond the first adds 75 ELO to opponents
	return base_elo + (run_tournament_number - 1) * 75

## Get HP and damage scaling multipliers for the current tournament.
## Tournament 1 = 1.0x, Tournament 2 = 1.15x HP / 1.10x dmg, etc.
func get_tournament_scale() -> Dictionary:
	var extra := run_tournament_number - 1
	return {
		"hp": 1.0 + extra * 0.15,
		"damage": 1.0 + extra * 0.10,
	}

## Get the total ELO change across all fights this run.
func get_run_elo_total() -> int:
	var total := 0
	for entry in run_elo_deltas:
		total += entry.get("delta", 0)
	return total

# =============================================================================
# Heat System
# =============================================================================

func set_chess_result(solved: bool, time_remaining: float, solve_time: float, mistakes: int = 0) -> void:
	chess_time_remaining = time_remaining
	chess_solve_time = solve_time
	chess_mistakes = mistakes
	current_fight_puzzle_solved = solved

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
	var base_time := 75.0
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

	# Shop bonus: cumulative chess time from Time Extension purchases
	base_time += shop_chess_time_bonus

	return base_time

func get_free_mistakes() -> int:
	var count := 0
	for perk in active_perks:
		if perk.get("effect", "") == "free_mistake":
			count += int(PerkSystem.get_named_value(perk, "count", 1.0))
	# Shop bonus: cumulative free mistakes from Error Margin purchases
	count += shop_free_mistakes
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
	pass  # Reserved for future set bonus effects

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
# Move Progression
# =============================================================================

## Returns what upgrade options are available after the current fight win.
## Now uses reel symbol drafting: player picks symbols to add to their reels.
func get_move_upgrade_options() -> Dictionary:
	var pool := ReelSystem.get_draft_pool(current_opponent_index)
	if pool.is_empty():
		return {"type": "none"}
	return {
		"type": "symbol_draft",
		"pool": pool,
		"picks": 2,  # Player drafts 2 symbols per upgrade phase
	}

## Add a drafted symbol to a specific reel.
func add_reel_symbol(reel_index: int, symbol: BoxingAction.ActionType) -> void:
	ReelSystem.add_symbol(reel_symbols, reel_index, symbol)

## Legacy compat
func apply_move_choice(_choice: String) -> void:
	pass

func unlock_uppercut() -> void:
	if BoxingAction.ActionType.UPPERCUT not in unlocked_moves:
		unlocked_moves.append(BoxingAction.ActionType.UPPERCUT)

func set_equipped_moves(moves: Array) -> void:
	equipped_moves = moves.duplicate()

## Get the effective damage for JAB (considering upgrade)
func get_jab_damage_bonus() -> int:
	return 3 if jab_upgraded else 0

func get_player_attack_pattern(count: int = 3) -> Array:
	# Action patterns are fixed per character — no reel randomness.
	var fighter_id: String = str(player_fighter.get("id", "")).to_lower()

	# Explicit Rookie guard — always Jab x3.
	if fighter_id == "rookie":
		var jabs: Array = []
		for i in count:
			jabs.append(BoxingAction.ActionType.JAB)
		return jabs

	# All other fighters use their attack_pattern from fighters.json.
	var raw_pattern: Array = player_fighter.get("attack_pattern", [])
	var converted: Array = []
	for entry in raw_pattern:
		converted.append(_attack_token_to_action(str(entry)))

	if converted.is_empty():
		converted = [BoxingAction.ActionType.JAB]

	var result: Array = []
	for i in count:
		result.append(converted[i % converted.size()])
	return result

func _attack_token_to_action(token: String) -> BoxingAction.ActionType:
	match token.to_lower():
		"cross":
			return BoxingAction.ActionType.CROSS
		"uppercut":
			return BoxingAction.ActionType.UPPERCUT
		_:
			return BoxingAction.ActionType.JAB

# =============================================================================
# Puzzle Selection
# =============================================================================

func get_puzzle_for_opponent() -> Dictionary:
	# Primary: use PuzzleService (Lichess API with cache). Falls back to local JSON.
	var puzzle := PuzzleService.get_puzzle_or_fallback()
	_mark_puzzle_used(puzzle)
	return puzzle

## Mark a puzzle as used so it won't be selected again this run.
func _mark_puzzle_used(puzzle: Dictionary) -> void:
	var pid: String = puzzle.get("id", "")
	if pid != "" and pid not in _used_puzzle_ids:
		_used_puzzle_ids.append(pid)

## Filter out puzzles already seen this run. If all are used, returns the full pool.
func _filter_unused(pool: Array) -> Array:
	var fresh := pool.filter(func(p): return p.get("id", "") not in _used_puzzle_ids)
	return fresh if not fresh.is_empty() else pool

## Legacy local puzzle selection — used as fallback by PuzzleService.
func get_local_puzzle_for_opponent() -> Dictionary:
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

	pool = _filter_unused(pool)
	pool.shuffle()
	var puzzle: Dictionary = pool[0]
	_mark_puzzle_used(puzzle)
	return puzzle

## Get a quick 1-move puzzle for boxing mini-puzzles. Prefers puzzles with
## single-move solutions so the player can solve them fast mid-fight.
func get_mini_puzzle() -> Dictionary:
	var difficulty: int = current_opponent.get("chess_difficulty", 1)
	var pool: Array = []

	if difficulty <= 2:
		pool = all_puzzles_easy.duplicate()
	elif difficulty <= 4:
		pool = all_puzzles_medium.duplicate()
	else:
		pool = all_puzzles_hard.duplicate()

	pool = _filter_unused(pool)

	# Prefer 1-move solutions for speed
	var quick: Array = pool.filter(func(p): return p.get("solution", []).size() <= 2)
	if not quick.is_empty():
		pool = quick

	if pool.is_empty():
		pool = all_puzzles_easy.duplicate()

	pool.shuffle()
	var puzzle: Dictionary = pool[0]
	_mark_puzzle_used(puzzle)
	return puzzle

# =============================================================================
# Draft Perks
# =============================================================================

func get_draft_choices(count: int = 3) -> Array:
	# Queen's Gambit: 5 rare choices
	if queens_gambit_active:
		queens_gambit_active = false
		var rare_perks := all_perks.filter(func(p): return p.get("rarity", "") == "rare")
		var rare_owned_ids := []
		for p in active_perks:
			rare_owned_ids.append(p.get("id", ""))
		rare_perks = rare_perks.filter(func(p): return p.get("id", "") not in rare_owned_ids)
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
	# Check whether a story cutscene should play before this phase.
	# Skip the check when we're already entering the CUTSCENE phase itself
	# to prevent an infinite redirect loop.
	if new_phase != GamePhase.CUTSCENE:
		var cutscene_id := _get_cutscene_for_transition(new_phase)
		if cutscene_id != "":
			pending_cutscene    = cutscene_id
			post_cutscene_phase = new_phase
			new_phase           = GamePhase.CUTSCENE   # redirect to cutscene first
		else:
			# No cutscene for this transition — clear stale pending/post from earlier runs.
			# Otherwise post_cutscene_phase can stay RESULTS and skipping a later cutscene
			# calls change_phase(RESULTS) by mistake (tournament win).
			pending_cutscene = ""
			post_cutscene_phase = new_phase

	current_phase = new_phase
	phase_changed.emit(_phase_to_string(new_phase))

	var scene_path := _get_scene_for_phase(new_phase)
	if scene_path != "":
		var err := get_tree().change_scene_to_file(scene_path)
		if err != OK:
			push_error("Failed to change scene to %s (error %d)" % [scene_path, err])

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
		GamePhase.MOVE_UPGRADE:
			return "res://scenes/move_upgrade/move_upgrade.tscn"
		GamePhase.PERK_DRAFT:
			return "res://scenes/perk_draft/perk_draft.tscn"
		GamePhase.SHOP:
			return "res://scenes/shop/shop.tscn"
		GamePhase.RESULTS:
			return "res://scenes/results/run_results.tscn"
		GamePhase.CUTSCENE:
			return "res://scenes/cutscene/cutscene.tscn"
	return ""

func _phase_to_string(phase: GamePhase) -> String:
	match phase:
		GamePhase.MENU: return "menu"
		GamePhase.FIGHTER_SELECT: return "fighter_select"
		GamePhase.TOURNAMENT: return "tournament"
		GamePhase.OPPONENT_REVEAL: return "opponent_reveal"
		GamePhase.CHESS: return "chess"
		GamePhase.BOXING: return "boxing"
		GamePhase.MOVE_UPGRADE: return "move_upgrade"
		GamePhase.PERK_DRAFT: return "perk_draft"
		GamePhase.SHOP: return "shop"
		GamePhase.RESULTS: return "results"
		GamePhase.CUTSCENE: return "cutscene"
	return "unknown"

# =============================================================================
# Cutscene System
# =============================================================================

## Called by cutscene.gd when the player finishes or skips a cutscene.
func mark_cutscene_seen(cutscene_id: String) -> void:
	if not seen_cutscenes.has(cutscene_id):
		seen_cutscenes.append(cutscene_id)
	pending_cutscene = ""

## Returns a story.json key if a cutscene should play before entering `phase`,
## or an empty string if the transition should proceed normally.
##
## Trigger map (6 stages across a 4-fight run):
##
##   stage_1 — TOURNAMENT          : The Setup      (bedroom recruitment)
##   stage_2 — BOXING, opponent 0  : The Dev Cameo  (locker room pre-fight 1)
##   stage_3 — BOXING, opponent 1  : First Blood    (hallway post-fight 1 / pre-fight 2)
##   stage_4 — BOXING, opponent 2  : The Rival      (press conference, Magnus appears)
##   stage_5 — BOXING, opponent 3  : The Finals     (tunnel pre-championship)
##   stage_6 — RESULTS, player won : The Champion   (victory celebration)
##
## Note: GamePhase.CHESS is defined but currently unused in the flow;
##       chess puzzles run inline inside boxing_phase via mini_puzzle.gd.
func _get_cutscene_for_transition(phase: GamePhase) -> String:
	match phase:
		GamePhase.TOURNAMENT:
			if not seen_cutscenes.has("stage_1"):
				return "stage_1"
		GamePhase.BOXING:
			if current_opponent_index == 0 and not seen_cutscenes.has("stage_2"):
				return "stage_2"
			if current_opponent_index == 1 and not seen_cutscenes.has("stage_3"):
				return "stage_3"
			if current_opponent_index == 2 and not seen_cutscenes.has("stage_4"):
				return "stage_4"
			if current_opponent_index == total_opponents - 1 and not seen_cutscenes.has("stage_5"):
				return "stage_5"
		GamePhase.RESULTS:
			var won: bool = stats.get("fights_won", 0) >= total_opponents
			if won and not seen_cutscenes.has("stage_6"):
				return "stage_6"
	return ""

# =============================================================================
# Shop & Tactic Cards
# =============================================================================

## Award Rep after a fight. Call this from _win_fight().
func award_fight_rep() -> Dictionary:
	var breakdown := ShopSystem.calculate_rep_earned(
		current_fight_puzzle_solved,
		chess_mistakes,
		chess_solve_time,
		get_chess_time_limit(),
		heat,
		opponent_hp,
		opponent_max_hp,
		player_hp,
		player_max_hp
	)
	player_rep += breakdown.total
	return breakdown


# =============================================================================
# Training Camp (Perk Cards)
# =============================================================================

func get_training_cards_for_shop(count: int = 3) -> Array[PerkCard]:
	var folder := "res://resources/perk_cards"
	var cards: Array[PerkCard] = []
	var dir := DirAccess.open(folder)
	if dir == null:
		return cards
	dir.list_dir_begin()
	var file_name := dir.get_next()
	while file_name != "":
		if not dir.current_is_dir() and file_name.ends_with(".tres"):
			var path := "%s/%s" % [folder, file_name]
			var res := load(path)
			if res is PerkCard:
				var card := res as PerkCard
				if not has_training_card(card.id):
					cards.append(card)
		file_name = dir.get_next()
	dir.list_dir_end()

	cards.shuffle()
	return cards.slice(0, mini(count, cards.size()))

func has_training_card(card_id: String) -> bool:
	for c in owned_training_cards:
		if c != null and c.id == card_id:
			return true
	return false

func purchase_training_card(card: PerkCard) -> Dictionary:
	if card == null:
		return {"success": false, "reason": "Invalid card"}
	if has_training_card(card.id):
		return {"success": false, "reason": "Already owned"}
	if player_rep < card.cost:
		return {"success": false, "reason": "Not enough Gold (%d/%d)" % [player_rep, card.cost]}

	player_rep -= card.cost
	owned_training_cards.append(card)
	card.on_purchase(self)
	return {"success": true, "reason": ""}

func modify_pressure_damage(base_damage: int) -> int:
	var dmg := base_damage
	for c in owned_training_cards:
		if c != null:
			dmg = c.modify_pressure_damage(dmg, self)
	return dmg

func modify_player_attack_damage(base_damage: int) -> int:
	var dmg := base_damage
	var ctx := {"last_chess_piece_moved": last_chess_piece_moved}
	for c in owned_training_cards:
		if c != null:
			dmg = c.modify_player_attack_damage(dmg, ctx, self)
	return dmg

func set_last_chess_piece_moved(piece: String) -> void:
	last_chess_piece_moved = piece

func has_training_card_used(card_id: String) -> bool:
	return bool(training_card_used_flags.get(card_id, false))

func mark_training_card_used(card_id: String) -> void:
	training_card_used_flags[card_id] = true

func _apply_stat_upgrade(effect: String, values: Dictionary) -> void:
	match effect:
		"shop_chess_time":
			shop_chess_time_bonus += values.get("time", 10.0)
		"shop_free_mistake":
			shop_free_mistakes += int(values.get("count", 1))
		"shop_max_hp":
			var hp_add := int(values.get("hp", 8))
			player_max_hp += hp_add
			player_hp = mini(player_hp + hp_add, player_max_hp)
		"shop_max_stamina":
			pass  # Stamina removed
		"shop_base_damage":
			shop_base_damage_bonus += int(values.get("damage", 1))

## Play a tactic card from hand during boxing. Returns the card or {}.
func play_tactic_card(index: int) -> Dictionary:
	var card := TacticCardSystem.play_card(tactic_hand, index)
	if not card.is_empty():
		active_tactics.append(card)
		# Endgame stacks persist for the whole fight
		if card.get("effect", "") == "endgame":
			endgame_damage_stacks += int(card.get("values", {}).get("damage_bonus", 3))
		# Sacrifice HP cost is applied in boxing_phase.gd via resolve_tactics()
	return card

## Clear active tactics at end of turn (except persistent effects).
func clear_turn_tactics() -> void:
	active_tactics.clear()

## Reset per-fight tactic state (endgame stacks, etc.)
func reset_fight_tactics() -> void:
	endgame_damage_stacks = 0
	active_tactics.clear()

## Remove a perk by index (for Perk Removal shop service).
func remove_perk(index: int) -> Dictionary:
	if index < 0 or index >= active_perks.size():
		return {}
	var removed: Dictionary = active_perks[index]
	active_perks.remove_at(index)
	pending_perk_removal = false

	# Recalculate tags and set bonuses
	tag_counts = PerkSystem.count_tags(active_perks)
	active_set_bonuses = PerkSystem.get_active_set_bonuses(tag_counts, all_set_bonuses)
	return removed
