class_name CombatManager
extends RefCounted

## Resolves combat actions between player and opponent.
## Supports reel-based 3-action turns with critical hit (match-3).

var actions: Dictionary  # ActionType -> BoxingAction

const PIECE_VALUES := {
	"P": 1,
	"N": 1, # Knight is grouped with Pawn for LightPunch category
	"B": 1, # Bishop grouped with Rook for HeavyPunch category
	"R": 1,
	"Q": 1,
	"K": 1,
}

const PIECE_VALUE_MULTIPLIERS := {
	"P": 1,
	"N": 3,
	"B": 3,
	"R": 5,
	"Q": 9,
	"K": 1,
}

const PUNCH_BASE_DAMAGE := {
	"LightPunch": 2,
	"HeavyPunch": 3,
	"SpecialUppercut": 4,
}

func _init() -> void:
	actions = BoxingAction.create_all()


## Resolve a critical hit (triple match on reels). Bypasses QTE — auto-perfect.
## Returns { damage: int, action_name: String, messages: Array }
func resolve_critical_hit(
	action_type: BoxingAction.ActionType,
	player_stats: Dictionary,
	opponent_stats: Dictionary,
) -> Dictionary:
	var atk_act: BoxingAction = actions[action_type]
	var multiplier := ReelSystem.get_critical_multiplier()

	var base_damage := _calculate_attack_damage(atk_act, player_stats, true)
	var damage := int(float(base_damage) * multiplier)

	# Blood Sacrifice stacks
	if GameManager.blood_sacrifice_stacks > 0:
		damage += GameManager.blood_sacrifice_stacks

	# Jab upgrade bonus
	if action_type == BoxingAction.ActionType.JAB:
		damage += GameManager.get_jab_damage_bonus()

	var name_upper := atk_act.name.to_upper()
	return {
		"damage": maxi(1, damage),
		"action_name": atk_act.name.to_lower(),
		"messages": [
			"[color=gold]★ TRIPLE %s! CRITICAL HIT! ★[/color]" % name_upper,
			"[color=gold]%s deals %d damage! (x%s)[/color]" % [atk_act.name, maxi(1, damage), str(multiplier)],
		],
	}


## Resolve player attack: puzzle determines hit, QTE determines bonus.
## puzzle_solved: true = punch lands, false = miss
## qte_result: "perfect"/"good"/"partial"/"critical"/"normal"/"miss"
## Returns: { damage: int, action_name: String, messages: Array }
func resolve_player_attack(
	attack_action: BoxingAction.ActionType,
	puzzle_solved: bool,
	qte_result: String,
	player_stats: Dictionary,
) -> Dictionary:
	var atk_act: BoxingAction = actions[attack_action]
	var result := {
		"damage": 0,
		"action_name": atk_act.name.to_lower(),
		"messages": [],
	}

	if not puzzle_solved:
		result.messages.append("[color=gray]%s misses! (puzzle failed)[/color]" % atk_act.name)
		return result

	# Base damage
	var damage := _calculate_attack_damage(atk_act, player_stats, true)
	damage = int(float(damage) * 1.35)

	# QTE bonus modifier
	match attack_action:
		BoxingAction.ActionType.JAB:
			match qte_result:
				"perfect":
					damage = int(float(damage) * 1.5)
					result.messages.append("[color=gold]PERFECT JAB! x1.5![/color]")
				"partial":
					damage = int(float(damage) * 1.2)
					result.messages.append("[color=yellow]Good jab! x1.2[/color]")
				_:
					pass  # base damage

		BoxingAction.ActionType.CROSS:
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
					damage = int(float(damage) * 0.8)
					result.messages.append("Weak cross...")

		BoxingAction.ActionType.UPPERCUT:
			match qte_result:
				"critical":
					damage = int(float(damage) * 1.75)
					result.messages.append("[color=gold]CRITICAL UPPERCUT! x1.75![/color]")
				"normal":
					damage = int(float(damage) * 0.5)
					result.messages.append("Uppercut glances... x0.5")
				_:
					damage = int(float(damage) * 0.3)
					result.messages.append("Uppercut weak...")

	# Tactic: guaranteed hit
	if player_stats.get("tactic_guaranteed_hit", false) and damage > 0:
		result.messages.append("[color=gold]Sacrifice! Guaranteed hit![/color]")

	# Blood Sacrifice stacks
	if GameManager.blood_sacrifice_stacks > 0 and damage > 0:
		damage += GameManager.blood_sacrifice_stacks

	# Jab upgrade bonus
	if attack_action == BoxingAction.ActionType.JAB:
		damage += GameManager.get_jab_damage_bonus()

	# Fighter-specific solved puzzle bonus damage
	damage += int(player_stats.get("solve_bonus_damage", 0))

	# Training Camp cards (e.g., Heavy Hands)
	damage = GameManager.modify_player_attack_damage(damage)

	result.damage = maxi(1, damage)
	result.messages.append("%s deals %d!" % [atk_act.name, result.damage])
	return result

func resolve_player_attack_from_piece(
	moved_piece: String,
	puzzle_solved: bool,
	player_stats: Dictionary,
) -> Dictionary:
	var piece := str(moved_piece).to_upper()
	var result := {
		"damage": 0,
		"action_name": "punch",
		"messages": [],
		"moved_piece": piece,
		"punch_anim": _piece_to_punch_anim(piece),
	}

	if not puzzle_solved:
		result.messages.append("[color=gray]Punch misses! (puzzle failed)[/color]")
		return result

	var base := int(PUNCH_BASE_DAMAGE.get(result.punch_anim, 2))
	var piece_mult := int(PIECE_VALUE_MULTIPLIERS.get(piece, 1))
	var damage_mod: float = float(player_stats.get("damage_mod", 1.0))
	var total := int(float(base) * float(piece_mult) * damage_mod)

	# Shop bonus and fight stacks are additive to base output (kept from old system)
	total += int(player_stats.get("shop_base_damage_bonus", 0))
	total += int(player_stats.get("endgame_damage_bonus", 0))

	# Training Camp cards (multipliers/conditionals)
	total = GameManager.modify_player_attack_damage(total)

	result.damage = maxi(1, total)
	result.messages.append("%s hits for %d!" % [_piece_display(piece), result.damage])
	return result

func _piece_to_punch_anim(piece: String) -> String:
	match piece:
		"P", "N":
			return "LightPunch"
		"B", "R":
			return "HeavyPunch"
		"Q":
			return "SpecialUppercut"
		_:
			return "LightPunch"

func _piece_display(piece: String) -> String:
	match piece:
		"P": return "Pawn"
		"N": return "Knight"
		"B": return "Bishop"
		"R": return "Rook"
		"Q": return "Queen"
		"K": return "King"
	return piece


## Resolve opponent attack with timing-based defense.
## damage_multiplier: 0.0 (perfect block) to 1.0 (no block) from QTETimingDefense.
## Returns: { damage: int, damage_multiplier: float, action_name: String, messages: Array }
func resolve_opponent_attack(
	attack_action: BoxingAction.ActionType,
	damage_multiplier: float,
	opponent_stats: Dictionary,
	player_stats: Dictionary,
) -> Dictionary:
	var atk_act: BoxingAction = actions[attack_action]
	var result := {
		"damage": 0,
		"damage_multiplier": damage_multiplier,
		"action_name": atk_act.name.to_lower(),
		"messages": [],
	}

	var raw_damage := _calculate_attack_damage(atk_act, opponent_stats, false)

	# Apply block multiplier
	var damage := int(float(raw_damage) * damage_multiplier)

	# Perk: damage reduction (heat-scaled)
	var dmg_red := int(GameManager.get_perk_scaled_value("damage_reduction", 0.0))
	if dmg_red > 0 and damage > 0:
		damage = maxi(0, damage - dmg_red)

	result.damage = maxi(0, damage)

	if damage_multiplier <= 0.05:
		result.messages.append("[color=cyan]PERFECT BLOCK! No damage![/color]")
	elif damage_multiplier <= 0.35:
		result.messages.append("[color=#6eaadc]Solid block! %s deals only %d.[/color]" % [atk_act.name, result.damage])
	elif damage_multiplier <= 0.65:
		result.messages.append("Partial block. %s deals %d." % [atk_act.name, result.damage])
	elif result.damage > 0:
		result.messages.append("[color=#d96050]%s breaks through for %d![/color]" % [atk_act.name, result.damage])

	return result


## Legacy: resolve a single action (kept for critical hit opponent counter-attacks).
func resolve_single_action(
	attacker_action: BoxingAction.ActionType,
	_defender_action: BoxingAction.ActionType,
	qte_result: String,
	is_player_attacking: bool,
	player_stats: Dictionary,
	opponent_stats: Dictionary,
) -> Dictionary:
	if is_player_attacking:
		return resolve_player_attack(attacker_action, true, qte_result, player_stats)
	else:
		# Legacy defense path: map old QTE results to damage multiplier
		var mult := 1.0
		if qte_result == "perfect_defense":
			mult = 0.0
		return resolve_opponent_attack(attacker_action, mult, opponent_stats, player_stats)


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
