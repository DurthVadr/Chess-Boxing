class_name GimmickSystem
extends RefCounted

## Applies per-opponent gimmick effects during and between combat rounds.
## Each gimmick type has its own logic.

## Apply gimmick effects AFTER a turn resolves.
## Modifies the result dict in-place and returns any extra messages.
static func apply_post_turn(
	gimmick: Dictionary,
	result: Dictionary,
	round_number: int,
	opponent_hp: int,
	opponent_max_hp: int
) -> Array:
	if gimmick.is_empty():
		return []

	var gimmick_type: String = gimmick.get("type", "")
	var messages: Array = []

	match gimmick_type:
		"scaling_damage":
			# Elena: +N damage per round applied to opponent's attacks
			var per_round: int = gimmick.get("per_round", 2)
			var bonus: int = per_round * round_number
			var taken: int = result.get("player_damage_taken", 0)
			if taken > 0:
				result["player_damage_taken"] = taken + bonus
				messages.append("[color=orange]+%d dmg from Diagonal Thinking![/color]" % bonus)

		"fortress":
			# Marcus: can't be KO'd by single hit (min 1 HP)
			# Applied to each action result's damage to opponent
			var r1: Dictionary = result.get("action1_result", {})
			var r2: Dictionary = result.get("action2_result", {})
			var total_dealt: int = result.get("player_damage_dealt", 0)

			# If this would KO from a single action, cap it
			if total_dealt > 0 and opponent_hp - total_dealt <= 0:
				# Only allow KO if BOTH actions dealt damage (combo KO)
				var a1_dmg: int = r1.get("player_damage_dealt", 0)
				var a2_dmg: int = r2.get("player_damage_dealt", 0)
				if a1_dmg > 0 and a2_dmg == 0:
					# Single-hit KO attempt — cap damage
					var max_dmg := opponent_hp - 1
					result["player_damage_dealt"] = max_dmg
					r1["player_damage_dealt"] = max_dmg
					messages.append("[color=gray]Fortress! Can't be KO'd by a single hit.[/color]")
				elif a2_dmg > 0 and a1_dmg == 0:
					var max_dmg := opponent_hp - 1
					result["player_damage_dealt"] = max_dmg
					r2["player_damage_dealt"] = max_dmg
					messages.append("[color=gray]Fortress! Can't be KO'd by a single hit.[/color]")

		"l_shaped_combos":
			# Suki: gets bonus damage when her combo alternates attack/defense
			var opp_combo: Dictionary = result.get("opponent_combo", {})
			if not opp_combo.is_empty():
				var bonus: int = gimmick.get("bonus_damage", 5)
				var taken: int = result.get("player_damage_taken", 0)
				result["player_damage_taken"] = taken + bonus
				messages.append("[color=orange]L-Shaped combo! +%d damage![/color]" % bonus)

		"perk_drafter":
			# Magnus: perk effects applied via boss_perks (handled separately)
			pass

	return messages

## Apply Marcus's fortress block-heal effect.
## Called after HP is applied, to heal when Marcus blocks.
static func apply_fortress_block_heal(gimmick: Dictionary, result: Dictionary) -> int:
	if gimmick.get("type", "") != "fortress":
		return 0

	var block_heal: int = gimmick.get("block_heal", 2)
	var heal := 0

	var r1: Dictionary = result.get("action1_result", {})
	var r2: Dictionary = result.get("action2_result", {})

	if r1.get("opponent_blocked", false):
		heal += block_heal
	if r2.get("opponent_blocked", false):
		heal += block_heal

	return heal

## Draft a boss perk for Magnus between rounds.
## Returns the drafted perk dict, or {} if pool is empty.
static func draft_boss_perk(boss_perk_pool: Array, already_drafted: Array) -> Dictionary:
	var available: Array = []
	var drafted_ids: Array = []
	for p in already_drafted:
		drafted_ids.append(p.get("id", ""))

	for p in boss_perk_pool:
		if p.get("id", "") not in drafted_ids:
			available.append(p)

	if available.is_empty():
		return {}

	available.shuffle()
	return available[0]

## Apply boss perk effects to opponent stats.
## Returns modifier dict: {damage_bonus, damage_reduction, block_heal}
static func get_boss_perk_modifiers(boss_perks: Array, round_number: int) -> Dictionary:
	var mods := {
		"damage_bonus": 0,
		"damage_reduction": 0.0,
		"block_heal": 0,
	}

	for perk in boss_perks:
		var effect: String = perk.get("effect", "")
		var values: Dictionary = perk.get("values", {})

		match effect:
			"boss_damage_bonus":
				mods["damage_bonus"] += int(values.get("damage", 3))
			"boss_block_heal":
				mods["block_heal"] += int(values.get("hp", 5))
			"boss_late_damage":
				var threshold: int = int(values.get("round_threshold", 3))
				if round_number >= threshold:
					mods["damage_bonus"] += int(values.get("damage", 3))
			"boss_damage_reduction":
				mods["damage_reduction"] += values.get("reduction", 0.25)
			"boss_read_action":
				pass  # Handled in OpponentAI

	return mods
