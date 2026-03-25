class_name CombatManager
extends RefCounted

## Resolves combat turns between player and opponent.
## Heat scales perk effects, NOT base action damage.

signal turn_resolved(result: Dictionary)

var actions: Dictionary  # ActionType -> BoxingAction

func _init() -> void:
	actions = BoxingAction.create_all()

## Resolve a single-action turn (legacy + current).
func resolve_turn(
	player_action: BoxingAction.ActionType,
	opponent_action: BoxingAction.ActionType,
	player_stats: Dictionary,
	opponent_stats: Dictionary,
	_heat: float = 1.0
) -> Dictionary:

	var p_act: BoxingAction = actions[player_action]
	var o_act: BoxingAction = actions[opponent_action]

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
		var clinch_recovery := 20
		# Perk: Clinch Master
		if player_action == BoxingAction.ActionType.CLINCH and GameManager.has_perk("clinch_stamina_bonus"):
			clinch_recovery = int(GameManager.get_perk_raw_value("clinch_stamina_bonus"))
		result.player_stamina_change = clinch_recovery
		result.opponent_stamina_change = 20
		result.messages.append("Clinch! Both fighters catch their breath.")
		return result

	# --- Calculate Player's Attack ---
	var player_damage := _calculate_attack_damage(p_act, player_stats, true)
	var player_stam_cost := _calculate_stamina_cost(p_act, true)

	# --- Calculate Opponent's Attack ---
	var opp_damage := _calculate_attack_damage(o_act, opponent_stats, false)
	var opp_stam_cost := _calculate_stamina_cost(o_act, false)

	# --- Resolve Player's Defense ---
	if player_action == BoxingAction.ActionType.DODGE:
		var dodge_chance := _get_dodge_chance(o_act.speed, true)
		if randf() < dodge_chance:
			result.player_dodged = true
			opp_damage = 0
			result.messages.append("You dodged the " + o_act.name + "!")
		else:
			result.messages.append("Dodge failed!")
	elif player_action == BoxingAction.ActionType.BLOCK:
		result.player_blocked = true
		var block_reduction := 0.5
		# Perk: Turtle Shell — 60% reduction
		if GameManager.has_perk("block_damage_reduction"):
			block_reduction = GameManager.get_perk_raw_value("block_damage_reduction")
		opp_damage = maxi(1, int(float(opp_damage) * (1.0 - block_reduction)))
		result.messages.append("You blocked! Reduced damage.")

	# --- Resolve Opponent's Defense ---
	if opponent_action == BoxingAction.ActionType.DODGE:
		var dodge_chance := _get_dodge_chance(p_act.speed, false)
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

	# --- Apply Perk: Damage Reduction (heat-scaled) ---
	var damage_reduction := int(GameManager.get_perk_scaled_value("damage_reduction", 0.0))
	if damage_reduction > 0 and opp_damage > 0:
		opp_damage = maxi(1, opp_damage - damage_reduction)

	# --- Apply Blood Sacrifice permanent damage bonus ---
	if GameManager.blood_sacrifice_stacks > 0 and player_damage > 0:
		player_damage += GameManager.blood_sacrifice_stacks

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

## Calculate attack damage. Heat scales PERK effects, not base damage.
func _calculate_attack_damage(action: BoxingAction, stats: Dictionary, is_player: bool) -> int:
	if action.damage <= 0:
		return 0

	var base_damage := action.damage
	var damage_mod: float = stats.get("damage_mod", 1.0)
	var total := int(float(base_damage) * damage_mod)

	if not is_player:
		return maxi(1, total)

	# --- Player-only perk bonuses (heat-scaled where marked) ---

	# Jab damage bonus (heat-scaled)
	if action.type == BoxingAction.ActionType.JAB:
		total += int(GameManager.get_perk_scaled_value("jab_damage_bonus", 0.0))

	# Cross damage bonus (heat-scaled)
	if action.type == BoxingAction.ActionType.CROSS:
		total += int(GameManager.get_perk_scaled_value("cross_damage_bonus", 0.0))

	# Hook damage bonus (heat-scaled)
	if action.type == BoxingAction.ActionType.HOOK:
		total += int(GameManager.get_perk_scaled_value("hook_damage_bonus", 0.0))

	# Glass Cannon: all damage x2 (not heat-scaled — already huge)
	if GameManager.has_perk("glass_cannon"):
		var mult: float = GameManager.get_perk_named_value("glass_cannon", "damage_multiplier", 2.0)
		total = int(float(total) * mult)

	# All In: +50% damage (not heat-scaled)
	if GameManager.has_perk("all_in"):
		var mult: float = GameManager.get_perk_named_value("all_in", "damage_multiplier", 1.5)
		total = int(float(total) * mult)

	return maxi(1, total)

## Calculate stamina cost for an action.
func _calculate_stamina_cost(action: BoxingAction, is_player: bool) -> int:
	var cost := action.stamina_cost

	if not is_player:
		return cost

	# Perk: Haymaker (uppercut stamina discount)
	if action.type == BoxingAction.ActionType.UPPERCUT:
		var discount := GameManager.get_perk_raw_value("uppercut_stamina_discount", 0.0)
		if discount > 0.0:
			cost = int(float(cost) * (1.0 - discount))

	# Set bonus: speed_2 — jabs cost 3 less stamina
	if action.type == BoxingAction.ActionType.JAB:
		for bonus in GameManager.get_active_set_bonuses_list():
			var effect: String = bonus.get("effect", "")
			if effect == "jab_stamina_reduction":
				cost -= int(bonus.get("values", {}).get("stamina_reduction", 3))
			elif effect == "jab_free":
				cost = 0

	return cost

## Get dodge chance. Accounts for player perks.
func _get_dodge_chance(attacker_speed: int, is_player_dodging: bool) -> float:
	var base_chance := 0.5
	match attacker_speed:
		1: base_chance = 0.25  # Jab
		2: base_chance = 0.40  # Cross
		3: base_chance = 0.60  # Hook
		4: base_chance = 0.75  # Uppercut

	if is_player_dodging:
		# Perk: Lightning Reflexes (+15% dodge)
		if GameManager.has_perk("dodge_bonus"):
			base_chance += GameManager.get_perk_raw_value("dodge_bonus")

	return clampf(base_chance, 0.0, 0.95)

# =============================================================================
# 2-Action Combo Resolution (v0.2)
# =============================================================================

## Resolve a 2-action turn for both player and opponent.
## Returns a result dict with sub-results and combo info.
func resolve_turn_v2(
	player_actions: Array,
	opponent_actions: Array,
	player_stats: Dictionary,
	opponent_stats: Dictionary,
	_current_heat: float
) -> Dictionary:
	# Resolve each action pair independently
	var result1 := _resolve_action_pair(
		player_actions[0], opponent_actions[0],
		player_stats, opponent_stats, false
	)
	var result2 := _resolve_action_pair(
		player_actions[1], opponent_actions[1],
		player_stats, opponent_stats, false
	)

	# Detect combos
	var player_combo := ComboSystem.detect_combo(player_actions[0], player_actions[1])
	var opponent_combo := ComboSystem.detect_combo(opponent_actions[0], opponent_actions[1])

	# Apply player combo bonuses to result2
	if not player_combo.is_empty():
		_apply_combo_to_result(player_combo, result1, result2, true)

	# Apply opponent combo bonuses to result2
	if not opponent_combo.is_empty():
		_apply_combo_to_result(opponent_combo, result1, result2, false)

	# Tally totals
	var total_result := {
		"action1_result": result1,
		"action2_result": result2,
		"player_combo": player_combo,
		"opponent_combo": opponent_combo,
		"player_damage_dealt": result1.player_damage_dealt + result2.player_damage_dealt,
		"player_damage_taken": result1.player_damage_taken + result2.player_damage_taken,
		"player_stamina_change": result1.player_stamina_change + result2.player_stamina_change,
		"opponent_stamina_change": result1.opponent_stamina_change + result2.opponent_stamina_change,
		"messages": [],
	}

	# Combine messages
	total_result.messages.append_array(result1.messages)
	total_result.messages.append_array(result2.messages)

	if not player_combo.is_empty():
		total_result.messages.append("[color=yellow]COMBO: %s![/color]" % player_combo.get("name", ""))
		GameManager.stats["combos_landed"] = GameManager.stats.get("combos_landed", 0) + 1
	if not opponent_combo.is_empty():
		total_result.messages.append("[color=red]Opponent COMBO: %s![/color]" % opponent_combo.get("name", ""))

	# Track stats
	GameManager.stats.total_damage_dealt += total_result.player_damage_dealt
	GameManager.stats.total_damage_taken += total_result.player_damage_taken

	return total_result

## Resolve a single action pair (player action vs opponent action).
## Does NOT track stats — the caller (resolve_turn_v2) does that.
func _resolve_action_pair(
	player_action: BoxingAction.ActionType,
	opponent_action: BoxingAction.ActionType,
	player_stats: Dictionary,
	opponent_stats: Dictionary,
	_track_stats: bool
) -> Dictionary:
	var p_act: BoxingAction = actions[player_action]
	var o_act: BoxingAction = actions[opponent_action]

	var result := {
		"player_action": p_act.name,
		"opponent_action": o_act.name,
		"player_action_type": player_action,
		"opponent_action_type": opponent_action,
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

	# Clinch
	if player_action == BoxingAction.ActionType.CLINCH or opponent_action == BoxingAction.ActionType.CLINCH:
		result.clinch = true
		var clinch_recovery := 20
		if player_action == BoxingAction.ActionType.CLINCH and GameManager.has_perk("clinch_stamina_bonus"):
			clinch_recovery = int(GameManager.get_perk_raw_value("clinch_stamina_bonus"))
		result.player_stamina_change = clinch_recovery if player_action == BoxingAction.ActionType.CLINCH else 0
		result.opponent_stamina_change = 20 if opponent_action == BoxingAction.ActionType.CLINCH else 0
		result.messages.append("Clinch!")
		return result

	# Damage calculation
	var player_damage := _calculate_attack_damage(p_act, player_stats, true)
	var player_stam := _calculate_stamina_cost(p_act, true)
	var opp_damage := _calculate_attack_damage(o_act, opponent_stats, false)
	var opp_stam := _calculate_stamina_cost(o_act, false)

	# Player defense
	if player_action == BoxingAction.ActionType.DODGE:
		var dodge_chance := _get_dodge_chance(o_act.speed, true)
		if randf() < dodge_chance:
			result.player_dodged = true
			opp_damage = 0
		else:
			result.messages.append("Dodge failed!")
	elif player_action == BoxingAction.ActionType.BLOCK:
		result.player_blocked = true
		var reduction := 0.5
		if GameManager.has_perk("block_damage_reduction"):
			reduction = GameManager.get_perk_raw_value("block_damage_reduction")
		opp_damage = maxi(1, int(float(opp_damage) * (1.0 - reduction)))

	# Opponent defense
	if opponent_action == BoxingAction.ActionType.DODGE:
		var dodge_chance := _get_dodge_chance(p_act.speed, false)
		if randf() < dodge_chance:
			result.opponent_dodged = true
			player_damage = 0
	elif opponent_action == BoxingAction.ActionType.BLOCK:
		result.opponent_blocked = true
		player_damage = maxi(1, player_damage / 2)

	# Perk: damage reduction (heat-scaled)
	var dmg_red := int(GameManager.get_perk_scaled_value("damage_reduction", 0.0))
	if dmg_red > 0 and opp_damage > 0:
		opp_damage = maxi(1, opp_damage - dmg_red)

	# Blood Sacrifice stacks
	if GameManager.blood_sacrifice_stacks > 0 and player_damage > 0:
		player_damage += GameManager.blood_sacrifice_stacks

	result.player_damage_dealt = player_damage
	result.player_damage_taken = opp_damage
	result.player_stamina_change = -player_stam
	result.opponent_stamina_change = -opp_stam

	if player_damage > 0:
		result.messages.append("%s deals %d!" % [p_act.name, player_damage])
	if opp_damage > 0:
		result.messages.append("Opp %s deals %d!" % [o_act.name, opp_damage])

	return result

## Apply combo bonus effects to the action results.
func _apply_combo_to_result(combo: Dictionary, result1: Dictionary, result2: Dictionary, is_player: bool) -> void:
	var effect: String = combo.get("effect", "")
	var dmg_key := "player_damage_dealt" if is_player else "player_damage_taken"

	match effect:
		"guaranteed_hit_action2":
			# If action1 was a successful dodge, action2 can't be dodged
			if is_player:
				if result1.get("player_dodged", false):
					# Undo any dodge the opponent did on action2
					if result2.get("opponent_dodged", false):
						result2["opponent_dodged"] = false
						# Recalculate damage (set to base)
						result2["player_damage_dealt"] = maxi(result2.get("player_damage_dealt", 0), 5)

		"half_stamina_action2":
			# Second action costs half stamina
			if is_player:
				result2["player_stamina_change"] = result2.get("player_stamina_change", 0) / 2

		"bonus_damage_action2":
			# Add flat bonus damage to action2
			var bonus: int = combo.get("bonus_damage", 3)
			if is_player:
				result2["player_damage_dealt"] = result2.get("player_damage_dealt", 0) + bonus
			else:
				result2["player_damage_taken"] = result2.get("player_damage_taken", 0) + bonus

		"stored_damage_action2":
			# Damage blocked in action1 is added to action2's attack
			if is_player and result1.get("player_blocked", false):
				var blocked_dmg: int = result1.get("player_damage_taken", 0)  # already reduced
				result2["player_damage_dealt"] = result2.get("player_damage_dealt", 0) + blocked_dmg

		"enhanced_block_action2":
			# Second block reduces 75% instead of 50%, recover HP
			if is_player:
				var hp_rec: int = combo.get("hp_recovery", 5)
				result2["messages"] = result2.get("messages", [])
				result2.messages.append("+%d HP from Hunker Down!" % hp_rec)
				# HP recovery applied by boxing_phase.gd

		"reduced_dodge_action2":
			# If action1 (hook) landed, action2 (uppercut) is harder to dodge
			if is_player and result1.get("player_damage_dealt", 0) > 0:
				if result2.get("opponent_dodged", false):
					# 50% chance to override the dodge
					if randf() < 0.5:
						result2["opponent_dodged"] = false
						result2["player_damage_dealt"] = maxi(result2.get("player_damage_dealt", 0), 10)

		"enhanced_dodge":
			# Both dodges get bonus, recover stamina
			var stam_rec: int = combo.get("stamina_recovery", 5)
			if is_player:
				result1["player_stamina_change"] = result1.get("player_stamina_change", 0) + stam_rec

		"stamina_drain":
			# Drain opponent stamina extra
			var drain: int = combo.get("stamina_drain", 8)
			if is_player:
				result2["opponent_stamina_change"] = result2.get("opponent_stamina_change", 0) - drain
