class_name CombatManager
extends RefCounted

## Resolves combat actions between player and opponent.
## Uses sequential QTE-based resolution (v0.3).


var actions: Dictionary  # ActionType -> BoxingAction

func _init() -> void:
	actions = BoxingAction.create_all()


## Resolve a single attack action with a QTE modifier.
## attacker_action: the attack being thrown (JAB, CROSS, UPPERCUT)
## qte_result: offensive → "perfect"/"good"/"partial"/"critical"/"normal"/"miss"
##             defensive → "perfect_defense"/"failed_defense"
## is_player_attacking: true = player attacks opponent, false = opponent attacks player
## Returns: { damage: int, dodged: bool, action_name: String, messages: Array }
func resolve_single_action(
	attacker_action: BoxingAction.ActionType,
	_defender_action: BoxingAction.ActionType,
	qte_result: String,
	is_player_attacking: bool,
	player_stats: Dictionary,
	opponent_stats: Dictionary,
) -> Dictionary:
	var atk_act: BoxingAction = actions[attacker_action]

	var result := {
		"damage": 0,
		"dodged": false,
		"action_name": atk_act.name.to_lower(),
		"messages": [],
	}

	# --- Calculate base damage ---
	var stats := player_stats if is_player_attacking else opponent_stats
	var raw_damage := _calculate_attack_damage(atk_act, stats, is_player_attacking)
	var damage := raw_damage

	# --- Offensive QTE (player attacking) ---
	if is_player_attacking:
		match attacker_action:
			BoxingAction.ActionType.JAB:
				# Jab: slow/easy QTE, reliable damage
				match qte_result:
					"perfect":
						damage = int(float(damage) * 1.5)
						result.messages.append("[color=gold]PERFECT JAB! x1.5![/color]")
					"partial":
						damage = int(float(damage) * 1.2)
						result.messages.append("[color=yellow]Good jab! x1.2[/color]")
					_:
						pass  # miss = base damage (jab always connects)

			BoxingAction.ActionType.CROSS:
				# Cross: gradual curve with 4 tiers
				match qte_result:
					"perfect":
						damage = int(float(damage) * 1.6)
						result.messages.append("[color=gold]PERFECT CROSS! x1.6![/color]")
					"good":
						damage = int(float(damage) * 1.35)
						result.messages.append("[color=yellow]Great cross! x1.35[/color]")
					"partial":
						damage = int(float(damage) * 1.1)
						result.messages.append("[color=yellow]Cross connects. x1.1[/color]")
					_:
						damage = int(float(damage) * 0.7)
						result.messages.append("Weak cross...")

			BoxingAction.ActionType.UPPERCUT:
				# Uppercut: only critical hits hard, otherwise bad
				match qte_result:
					"critical":
						damage = int(float(damage) * 1.75)
						result.messages.append("[color=gold]CRITICAL UPPERCUT! x1.75![/color]")
					"normal":
						damage = int(float(damage) * 0.4)
						result.messages.append("Uppercut glances... x0.4")
					_:
						damage = int(float(damage) * 0.2)
						result.messages.append("Uppercut whiffs...")

		# Tactic: guaranteed hit overrides
		if player_stats.get("tactic_guaranteed_hit", false) and damage > 0:
			result.messages.append("[color=gold]Sacrifice! Guaranteed hit![/color]")

	# --- Defensive QTE (opponent attacking, player defends) ---
	else:
		if qte_result == "perfect_defense":
			result.damage = 0
			result.dodged = true
			result.messages.append("[color=cyan]PERFECT DEFENSE! No damage![/color]")
			return result
		else:
			# failed_defense — take full damage
			pass

	# --- Perk: damage reduction (heat-scaled) — player defending only ---
	if not is_player_attacking:
		var dmg_red := int(GameManager.get_perk_scaled_value("damage_reduction", 0.0))
		if dmg_red > 0 and damage > 0:
			damage = maxi(1, damage - dmg_red)

	# --- Blood Sacrifice stacks — player attacking only ---
	if is_player_attacking and GameManager.blood_sacrifice_stacks > 0 and damage > 0:
		damage += GameManager.blood_sacrifice_stacks

	# --- Jab upgrade bonus ---
	if is_player_attacking and attacker_action == BoxingAction.ActionType.JAB:
		damage += GameManager.get_jab_damage_bonus()

	result.damage = maxi(0, damage)
	if result.damage > 0:
		if is_player_attacking:
			result.messages.append("%s deals %d!" % [atk_act.name, result.damage])
		else:
			result.messages.append("Opp %s deals %d!" % [atk_act.name, result.damage])

	return result


## Calculate attack damage. Perk effects scale with heat, not base damage.
func _calculate_attack_damage(action: BoxingAction, stats: Dictionary, is_player: bool) -> int:
	if action.damage <= 0:
		return 0

	var base_damage := action.damage
	var damage_mod: float = stats.get("damage_mod", 1.0)
	var total := int(float(base_damage) * damage_mod)

	if not is_player:
		return maxi(1, total)

	# --- Player-only perk bonuses ---

	# Jab damage bonus (heat-scaled)
	if action.type == BoxingAction.ActionType.JAB:
		total += int(GameManager.get_perk_scaled_value("jab_damage_bonus", 0.0))

	# Cross damage bonus (heat-scaled)
	if action.type == BoxingAction.ActionType.CROSS:
		total += int(GameManager.get_perk_scaled_value("cross_damage_bonus", 0.0))

	# Glass Cannon: all damage x2 (not heat-scaled)
	if GameManager.has_perk("glass_cannon"):
		var mult: float = GameManager.get_perk_named_value("glass_cannon", "damage_multiplier", 2.0)
		total = int(float(total) * mult)

	# All In: +50% damage (not heat-scaled)
	if GameManager.has_perk("all_in"):
		var mult: float = GameManager.get_perk_named_value("all_in", "damage_multiplier", 1.5)
		total = int(float(total) * mult)

	# Shop: base damage bonus (permanent from Heavy Bag)
	total += int(stats.get("shop_base_damage_bonus", 0))

	# Tactic: Endgame stacks (+damage for rest of fight)
	total += int(stats.get("endgame_damage_bonus", 0))

	return maxi(1, total)
