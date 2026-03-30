class_name OpponentAI
extends RefCounted

## AI behavior for boxing opponents — picks 2 attack actions per turn.
## Only uses JAB, CROSS, UPPERCUT. Player defends via defensive QTE.

enum Archetype { BRAWLER, TECHNICIAN, TURTLE, GLASS_CANNON, BOSS }

var archetype: Archetype = Archetype.BRAWLER
var last_player_actions: Array = []
var turn_count: int = 0
var telegraph_data: Dictionary = {}
var boss_round: int = 0

func setup(archetype_name: String) -> void:
	match archetype_name:
		"brawler": archetype = Archetype.BRAWLER
		"technician": archetype = Archetype.TECHNICIAN
		"turtle": archetype = Archetype.TURTLE
		"glass_cannon": archetype = Archetype.GLASS_CANNON
		"boss": archetype = Archetype.BOSS
		_: archetype = Archetype.BRAWLER

func setup_telegraphs(opponent_id: String) -> void:
	var all_telegraphs: Array = _load_telegraphs()
	for t in all_telegraphs:
		if t.get("opponent_id", "") == opponent_id:
			telegraph_data = t
			return

func _load_telegraphs() -> Array:
	var file := FileAccess.open("res://data/telegraphs.json", FileAccess.READ)
	if file == null:
		return []
	var json := JSON.new()
	if json.parse(file.get_as_text()) != OK:
		return []
	if json.data is Array:
		return json.data
	return []

## Choose 2 attack actions for this turn. Returns [action1, action2].
func choose_actions(opp_hp_pct: float, _opp_stamina: int, player_hp_pct: float) -> Array:
	turn_count += 1

	match archetype:
		Archetype.BRAWLER:
			return _brawler_actions(opp_hp_pct)
		Archetype.TECHNICIAN:
			return _technician_actions(opp_hp_pct, player_hp_pct)
		Archetype.TURTLE:
			return _turtle_actions(opp_hp_pct)
		Archetype.GLASS_CANNON:
			return _glass_cannon_actions(opp_hp_pct)
		Archetype.BOSS:
			return _boss_actions(opp_hp_pct, player_hp_pct)

	return [BoxingAction.ActionType.JAB, BoxingAction.ActionType.JAB]

func choose_action(opp_hp_pct: float, opp_stamina: int, player_hp_pct: float) -> BoxingAction.ActionType:
	var actions := choose_actions(opp_hp_pct, opp_stamina, player_hp_pct)
	return actions[0]

func get_telegraph_for_actions(actions: Array) -> String:
	if telegraph_data.is_empty():
		return "Opponent is sizing you up..."

	var honest_ratio: float = telegraph_data.get("honest_ratio", 1.0)
	if archetype == Archetype.BOSS:
		honest_ratio = maxf(0.3, honest_ratio - boss_round * 0.15)

	var first_action: BoxingAction.ActionType = actions[0]
	var action_name := _action_to_string(first_action)
	var tells: Dictionary = telegraph_data.get("tells", {})
	var feint_pool: Array = telegraph_data.get("feint_pool", [])

	if randf() < honest_ratio or feint_pool.is_empty():
		return tells.get(action_name, "...")
	else:
		var feint_action: String = feint_pool[randi() % feint_pool.size()]
		return tells.get(feint_action, "...")

func get_telegraph_hint(action: BoxingAction.ActionType) -> String:
	return get_telegraph_for_actions([action])

func record_player_actions(actions: Array) -> void:
	last_player_actions = actions

func record_player_action(action: BoxingAction.ActionType) -> void:
	last_player_actions = [action]

static func _action_to_string(action: BoxingAction.ActionType) -> String:
	match action:
		BoxingAction.ActionType.JAB: return "jab"
		BoxingAction.ActionType.CROSS: return "cross"
		BoxingAction.ActionType.UPPERCUT: return "uppercut"
	return "jab"

# =============================================================================
# Archetype AIs — all return [Attack1, Attack2]
# =============================================================================

func _brawler_actions(hp_pct: float) -> Array:
	# Predictable. Mostly jabs and crosses. Tutorial opponent.
	if hp_pct < 0.3:
		return _pick_weighted([
			[[BoxingAction.ActionType.CROSS, BoxingAction.ActionType.UPPERCUT], 3],
			[[BoxingAction.ActionType.CROSS, BoxingAction.ActionType.CROSS], 3],
			[[BoxingAction.ActionType.JAB, BoxingAction.ActionType.CROSS], 2],
		])

	return _pick_weighted([
		[[BoxingAction.ActionType.JAB, BoxingAction.ActionType.JAB], 4],
		[[BoxingAction.ActionType.JAB, BoxingAction.ActionType.CROSS], 3],
		[[BoxingAction.ActionType.CROSS, BoxingAction.ActionType.JAB], 2],
		[[BoxingAction.ActionType.JAB, BoxingAction.ActionType.UPPERCUT], 1],
	])

func _technician_actions(hp_pct: float, player_hp_pct: float) -> Array:
	# Varied combos, adapts to player.
	if player_hp_pct < 0.25:
		return [BoxingAction.ActionType.CROSS, BoxingAction.ActionType.UPPERCUT]

	if hp_pct < 0.4:
		return _pick_weighted([
			[[BoxingAction.ActionType.CROSS, BoxingAction.ActionType.UPPERCUT], 3],
			[[BoxingAction.ActionType.UPPERCUT, BoxingAction.ActionType.JAB], 2],
			[[BoxingAction.ActionType.JAB, BoxingAction.ActionType.CROSS], 2],
		])

	return _pick_weighted([
		[[BoxingAction.ActionType.JAB, BoxingAction.ActionType.CROSS], 3],
		[[BoxingAction.ActionType.CROSS, BoxingAction.ActionType.JAB], 3],
		[[BoxingAction.ActionType.CROSS, BoxingAction.ActionType.CROSS], 2],
		[[BoxingAction.ActionType.JAB, BoxingAction.ActionType.UPPERCUT], 1],
	])

func _turtle_actions(hp_pct: float) -> Array:
	# Slow and careful. Jabs mostly, occasional big punch.
	if hp_pct < 0.4:
		return _pick_weighted([
			[[BoxingAction.ActionType.JAB, BoxingAction.ActionType.CROSS], 3],
			[[BoxingAction.ActionType.CROSS, BoxingAction.ActionType.UPPERCUT], 2],
			[[BoxingAction.ActionType.JAB, BoxingAction.ActionType.JAB], 2],
		])

	return _pick_weighted([
		[[BoxingAction.ActionType.JAB, BoxingAction.ActionType.JAB], 5],
		[[BoxingAction.ActionType.JAB, BoxingAction.ActionType.CROSS], 3],
		[[BoxingAction.ActionType.CROSS, BoxingAction.ActionType.JAB], 2],
	])

func _glass_cannon_actions(hp_pct: float) -> Array:
	# All-in aggression. Uppercuts and crosses.
	if hp_pct < 0.3:
		return [BoxingAction.ActionType.UPPERCUT, BoxingAction.ActionType.UPPERCUT]

	return _pick_weighted([
		[[BoxingAction.ActionType.CROSS, BoxingAction.ActionType.UPPERCUT], 4],
		[[BoxingAction.ActionType.UPPERCUT, BoxingAction.ActionType.CROSS], 3],
		[[BoxingAction.ActionType.CROSS, BoxingAction.ActionType.CROSS], 2],
		[[BoxingAction.ActionType.JAB, BoxingAction.ActionType.UPPERCUT], 1],
	])

func _boss_actions(hp_pct: float, player_hp_pct: float) -> Array:
	# Phases with escalating aggression.
	if hp_pct > 0.6:
		return _pick_weighted([
			[[BoxingAction.ActionType.JAB, BoxingAction.ActionType.CROSS], 3],
			[[BoxingAction.ActionType.CROSS, BoxingAction.ActionType.JAB], 2],
			[[BoxingAction.ActionType.JAB, BoxingAction.ActionType.UPPERCUT], 2],
			[[BoxingAction.ActionType.CROSS, BoxingAction.ActionType.CROSS], 1],
		])

	if hp_pct > 0.3:
		if player_hp_pct < 0.25:
			return [BoxingAction.ActionType.UPPERCUT, BoxingAction.ActionType.UPPERCUT]
		return _pick_weighted([
			[[BoxingAction.ActionType.CROSS, BoxingAction.ActionType.UPPERCUT], 3],
			[[BoxingAction.ActionType.UPPERCUT, BoxingAction.ActionType.CROSS], 3],
			[[BoxingAction.ActionType.JAB, BoxingAction.ActionType.UPPERCUT], 2],
		])

	# Desperate phase
	return _pick_weighted([
		[[BoxingAction.ActionType.UPPERCUT, BoxingAction.ActionType.UPPERCUT], 4],
		[[BoxingAction.ActionType.CROSS, BoxingAction.ActionType.UPPERCUT], 3],
		[[BoxingAction.ActionType.UPPERCUT, BoxingAction.ActionType.CROSS], 2],
	])

# =============================================================================
# Utility
# =============================================================================

func _pick_weighted(options: Array) -> Array:
	var total_weight := 0
	for opt in options:
		total_weight += opt[1]
	var roll := randi() % total_weight
	var cumulative := 0
	for opt in options:
		cumulative += opt[1]
		if roll < cumulative:
			return opt[0]
	return options[0][0]
