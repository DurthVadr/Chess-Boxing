class_name CombatManager
extends RefCounted

## Resolves combat turns between player and opponent

signal turn_resolved(result: Dictionary)

var actions: Dictionary  # ActionType -> BoxingAction

func _init() -> void:
	actions = BoxingAction.create_all()

## Resolve a turn given player and opponent actions
## Returns a result dictionary with all the details
func resolve_turn(
	player_action: BoxingAction.ActionType,
	opponent_action: BoxingAction.ActionType,
	player_stats: Dictionary,
	opponent_stats: Dictionary,
	chess_bonus: float
) -> Dictionary:

	var p_act := actions[player_action]
	var o_act := actions[opponent_action]

	var result := {
		"player_action": p_act.name,
		"opponent_action": o_act.name,
		"player_damage_dealt": 0,
		"player_damage_taken": 0,
		"player_stamina_change": 0,
		"opponent_stamina_change": 0,
		"player_dodged": false,
		"opponent_dodged": false,
		"player_blocked": false,
		"opponent_blocked": false,
		"clinch": false,
		"messages": [],
	}

	# --- Handle Clinch ---
	if player_action == BoxingAction.ActionType.CLINCH or opponent_action == BoxingAction.ActionType.CLINCH:
		result.clinch = true
		result.player_stamina_change = 20
		result.opponent_stamina_change = 20
		result.messages.append("Clinch! Both fighters catch their breath.")
		return result

	# --- Calculate Player's Attack ---
	var player_damage := _calculate_attack_damage(p_act, player_stats, chess_bonus, true)
	var player_stam_cost := _calculate_stamina_cost(p_act, player_stats, true)

	# --- Calculate Opponent's Attack ---
	var opp_damage := _calculate_attack_damage(o_act, opponent_stats, 0.0, false)
	var opp_stam_cost := _calculate_stamina_cost(o_act, opponent_stats, false)

	# --- Resolve Player's Defense ---
	if player_action == BoxingAction.ActionType.DODGE:
		var dodge_chance := _get_dodge_chance(o_act.speed)
		if randf() < dodge_chance:
			result.player_dodged = true
			opp_damage = 0
			result.messages.append("You dodged the " + o_act.name + "!")
		else:
			result.messages.append("Dodge failed!")
	elif player_action == BoxingAction.ActionType.BLOCK:
		result.player_blocked = true
		opp_damage = maxi(1, opp_damage / 2)
		result.messages.append("You blocked! Reduced damage.")

	# --- Resolve Opponent's Defense ---
	if opponent_action == BoxingAction.ActionType.DODGE:
		var dodge_chance := _get_dodge_chance(p_act.speed)
		if randf() < dodge_chance:
			result.opponent_dodged = true
			player_damage = 0
			result.messages.append("Opponent dodged your " + p_act.name + "!")
		else:
			result.messages.append("Opponent's dodge failed!")
	elif opponent_action == BoxingAction.ActionType.BLOCK:
		result.opponent_blocked = true
		player_damage = maxi(1, player_damage / 2)
		result.messages.append("Opponent blocked! Your damage reduced.")

	# --- Apply Perk: Damage Reduction ---
	var damage_reduction := int(GameManager.get_perk_value("damage_reduction", 0.0))
	if damage_reduction > 0 and opp_damage > 0:
		opp_damage = maxi(1, opp_damage - damage_reduction)

	# --- Finalize ---
	result.player_damage_dealt = player_damage
	result.player_damage_taken = opp_damage
	result.player_stamina_change = -player_stam_cost
	result.opponent_stamina_change = -opp_stam_cost

	if player_damage > 0:
		result.messages.append("Your " + p_act.name + " deals " + str(player_damage) + " damage!")
	if opp_damage > 0:
		result.messages.append("Opponent's " + o_act.name + " deals " + str(opp_damage) + " damage!")

	# Track stats
	GameManager.stats.total_damage_dealt += player_damage
	GameManager.stats.total_damage_taken += opp_damage

	return result

func _calculate_attack_damage(action: BoxingAction, stats: Dictionary, chess_bonus: float, is_player: bool) -> int:
	if action.damage <= 0:
		return 0

	var base_damage := action.damage
	var damage_mod: float = stats.get("damage_mod", 1.0)
	var total := int(float(base_damage) * damage_mod)

	# Chess bonus for player only
	if is_player and chess_bonus > 0.0:
		total += ChessBonus.get_bonus_damage(chess_bonus)

	# Perk: jab damage bonus
	if is_player and action.type == BoxingAction.ActionType.JAB:
		total += int(GameManager.get_perk_value("jab_damage_bonus", 0.0))

	return maxi(1, total)

func _calculate_stamina_cost(action: BoxingAction, _stats: Dictionary, is_player: bool) -> int:
	var cost := action.stamina_cost

	# Perk: Haymaker (uppercut discount)
	if is_player and action.type == BoxingAction.ActionType.UPPERCUT:
		var discount := GameManager.get_perk_value("uppercut_stamina_discount", 0.0)
		if discount > 0.0:
			cost = int(float(cost) * (1.0 - discount))

	return cost

func _get_dodge_chance(attacker_speed: int) -> float:
	# Faster attacks are harder to dodge
	match attacker_speed:
		1: return 0.25  # Jab - very hard to dodge
		2: return 0.40  # Cross
		3: return 0.60  # Hook
		4: return 0.75  # Uppercut - easy to dodge
		_: return 0.50
