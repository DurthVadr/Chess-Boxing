class_name OpponentAI
extends RefCounted

## AI behavior for boxing opponents — picks 2-action sequences per turn.
## Supports archetype-specific patterns and learnable telegraph tells.

enum Archetype { BRAWLER, TECHNICIAN, TURTLE, GLASS_CANNON, BOSS }

var archetype: Archetype = Archetype.BRAWLER
var last_player_actions: Array = []  # Last [action1, action2] the player used
var turn_count: int = 0
var telegraph_data: Dictionary = {}  # Loaded from telegraphs.json
var boss_round: int = 0  # Magnus phase tracking

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

## Choose 2 actions for this turn. Returns [action1, action2].
func choose_actions(opp_hp_pct: float, opp_stamina: int, player_hp_pct: float) -> Array:
	turn_count += 1

	if opp_stamina < 10:
		return [BoxingAction.ActionType.CLINCH, BoxingAction.ActionType.JAB]

	match archetype:
		Archetype.BRAWLER:
			return _brawler_actions(opp_hp_pct, opp_stamina)
		Archetype.TECHNICIAN:
			return _technician_actions(opp_hp_pct, opp_stamina, player_hp_pct)
		Archetype.TURTLE:
			return _turtle_actions(opp_hp_pct, opp_stamina, player_hp_pct)
		Archetype.GLASS_CANNON:
			return _glass_cannon_actions(opp_hp_pct, opp_stamina)
		Archetype.BOSS:
			return _boss_actions(opp_hp_pct, opp_stamina, player_hp_pct)

	return [BoxingAction.ActionType.JAB, BoxingAction.ActionType.CROSS]

## Legacy single-action compat.
func choose_action(opp_hp_pct: float, opp_stamina: int, player_hp_pct: float) -> BoxingAction.ActionType:
	var actions := choose_actions(opp_hp_pct, opp_stamina, player_hp_pct)
	return actions[0]

## Get telegraph text for opponent's chosen actions.
## Rolls honest_ratio — may feint (show wrong tell).
func get_telegraph_for_actions(actions: Array) -> String:
	if telegraph_data.is_empty():
		return "Opponent is sizing you up..."

	var honest_ratio: float = telegraph_data.get("honest_ratio", 1.0)

	# Magnus: honest_ratio decays per round
	if archetype == Archetype.BOSS:
		honest_ratio = maxf(0.3, honest_ratio - boss_round * 0.15)

	var first_action: BoxingAction.ActionType = actions[0]
	var action_name := ComboSystem.action_to_string(first_action)

	var tells: Dictionary = telegraph_data.get("tells", {})
	var feint_pool: Array = telegraph_data.get("feint_pool", [])

	if randf() < honest_ratio or feint_pool.is_empty():
		# Honest tell
		return tells.get(action_name, "...")
	else:
		# Feint — show a tell from the feint pool instead
		var feint_action: String = feint_pool[randi() % feint_pool.size()]
		return tells.get(feint_action, "...")

## Legacy telegraph compat.
func get_telegraph_hint(action: BoxingAction.ActionType) -> String:
	return get_telegraph_for_actions([action])

func record_player_actions(actions: Array) -> void:
	last_player_actions = actions

func record_player_action(action: BoxingAction.ActionType) -> void:
	last_player_actions = [action]

# =============================================================================
# Archetype AIs — all return [Action1, Action2]
# =============================================================================

func _brawler_actions(hp_pct: float, stamina: int) -> Array:
	# Predictable aggression. No combo awareness. Tutorial opponent.
	if stamina < 20:
		return [BoxingAction.ActionType.CLINCH, BoxingAction.ActionType.JAB]

	if hp_pct < 0.3:
		# Desperate
		return _pick_weighted([
			[[BoxingAction.ActionType.HOOK, BoxingAction.ActionType.UPPERCUT], 3],
			[[BoxingAction.ActionType.CROSS, BoxingAction.ActionType.HOOK], 3],
			[[BoxingAction.ActionType.JAB, BoxingAction.ActionType.CROSS], 2],
		])

	return _pick_weighted([
		[[BoxingAction.ActionType.JAB, BoxingAction.ActionType.CROSS], 4],
		[[BoxingAction.ActionType.JAB, BoxingAction.ActionType.JAB], 3],
		[[BoxingAction.ActionType.CROSS, BoxingAction.ActionType.HOOK], 2],
		[[BoxingAction.ActionType.JAB, BoxingAction.ActionType.HOOK], 1],
	])

func _technician_actions(_hp_pct: float, stamina: int, player_hp_pct: float) -> Array:
	# Deliberate combos. Counter-plays player's last combo.
	if stamina < 20:
		return [BoxingAction.ActionType.BLOCK, BoxingAction.ActionType.BLOCK]

	# Counter-play based on player's last actions
	if not last_player_actions.is_empty():
		var last1: BoxingAction.ActionType = last_player_actions[0]
		# If player was aggressive, dodge then counter
		if ComboSystem.is_attack(last1):
			if randf() < 0.5:
				return [BoxingAction.ActionType.DODGE, BoxingAction.ActionType.CROSS]
		# If player was defensive, punish
		if last1 == BoxingAction.ActionType.BLOCK or last1 == BoxingAction.ActionType.CLINCH:
			if randf() < 0.5:
				return [BoxingAction.ActionType.HOOK, BoxingAction.ActionType.UPPERCUT]

	# Finisher
	if player_hp_pct < 0.25 and stamina >= 30:
		return [BoxingAction.ActionType.HOOK, BoxingAction.ActionType.UPPERCUT]

	return _pick_weighted([
		[[BoxingAction.ActionType.JAB, BoxingAction.ActionType.CROSS], 3],
		[[BoxingAction.ActionType.DODGE, BoxingAction.ActionType.CROSS], 3],
		[[BoxingAction.ActionType.BLOCK, BoxingAction.ActionType.HOOK], 2],
		[[BoxingAction.ActionType.CROSS, BoxingAction.ActionType.HOOK], 2],
	])

func _turtle_actions(hp_pct: float, stamina: int, _player_hp_pct: float) -> Array:
	# Very defensive. BLOCK+BLOCK is signature. Counter-punches.
	if stamina < 15:
		return [BoxingAction.ActionType.CLINCH, BoxingAction.ActionType.BLOCK]

	if hp_pct > 0.5:
		return _pick_weighted([
			[[BoxingAction.ActionType.BLOCK, BoxingAction.ActionType.BLOCK], 4],
			[[BoxingAction.ActionType.BLOCK, BoxingAction.ActionType.CROSS], 3],
			[[BoxingAction.ActionType.DODGE, BoxingAction.ActionType.JAB], 2],
			[[BoxingAction.ActionType.JAB, BoxingAction.ActionType.BLOCK], 1],
		])
	else:
		# More aggressive when low
		return _pick_weighted([
			[[BoxingAction.ActionType.BLOCK, BoxingAction.ActionType.HOOK], 3],
			[[BoxingAction.ActionType.CROSS, BoxingAction.ActionType.CROSS], 2],
			[[BoxingAction.ActionType.BLOCK, BoxingAction.ActionType.BLOCK], 2],
			[[BoxingAction.ActionType.HOOK, BoxingAction.ActionType.UPPERCUT], 1],
		])

func _glass_cannon_actions(_hp_pct: float, stamina: int) -> Array:
	# All offense, no defense. L-shaped combos (alternate attack/defense).
	if stamina < 10:
		return [BoxingAction.ActionType.CLINCH, BoxingAction.ActionType.UPPERCUT]

	return _pick_weighted([
		[[BoxingAction.ActionType.DODGE, BoxingAction.ActionType.HOOK], 3],   # L-shape
		[[BoxingAction.ActionType.HOOK, BoxingAction.ActionType.UPPERCUT], 3],
		[[BoxingAction.ActionType.CROSS, BoxingAction.ActionType.HOOK], 2],
		[[BoxingAction.ActionType.JAB, BoxingAction.ActionType.UPPERCUT], 2],
		[[BoxingAction.ActionType.DODGE, BoxingAction.ActionType.UPPERCUT], 1], # L-shape
	])

func _boss_actions(hp_pct: float, stamina: int, player_hp_pct: float) -> Array:
	# Smart and dangerous. Uses full combo awareness. Adapts per phase.
	if stamina < 15:
		if randf() < 0.5:
			return [BoxingAction.ActionType.BLOCK, BoxingAction.ActionType.BLOCK]
		return [BoxingAction.ActionType.CLINCH, BoxingAction.ActionType.JAB]

	# Phase 1: Controlled (HP > 60%)
	if hp_pct > 0.6:
		# Counter-play
		if not last_player_actions.is_empty():
			var last1: BoxingAction.ActionType = last_player_actions[0]
			if last1 == BoxingAction.ActionType.HOOK or last1 == BoxingAction.ActionType.UPPERCUT:
				if randf() < 0.6:
					return [BoxingAction.ActionType.DODGE, BoxingAction.ActionType.UPPERCUT]

		return _pick_weighted([
			[[BoxingAction.ActionType.JAB, BoxingAction.ActionType.CROSS], 3],
			[[BoxingAction.ActionType.DODGE, BoxingAction.ActionType.CROSS], 2],
			[[BoxingAction.ActionType.BLOCK, BoxingAction.ActionType.HOOK], 2],
			[[BoxingAction.ActionType.CROSS, BoxingAction.ActionType.HOOK], 2],
			[[BoxingAction.ActionType.BLOCK, BoxingAction.ActionType.BLOCK], 1],
		])

	# Phase 2: Aggressive (HP 30-60%)
	if hp_pct > 0.3:
		if player_hp_pct < 0.25:
			return [BoxingAction.ActionType.HOOK, BoxingAction.ActionType.UPPERCUT]

		return _pick_weighted([
			[[BoxingAction.ActionType.HOOK, BoxingAction.ActionType.UPPERCUT], 3],
			[[BoxingAction.ActionType.CROSS, BoxingAction.ActionType.HOOK], 3],
			[[BoxingAction.ActionType.DODGE, BoxingAction.ActionType.UPPERCUT], 2],
			[[BoxingAction.ActionType.BLOCK, BoxingAction.ActionType.HOOK], 2],
		])

	# Phase 3: Desperate but precise (HP < 30%)
	return _pick_weighted([
		[[BoxingAction.ActionType.DODGE, BoxingAction.ActionType.UPPERCUT], 4],
		[[BoxingAction.ActionType.HOOK, BoxingAction.ActionType.UPPERCUT], 3],
		[[BoxingAction.ActionType.BLOCK, BoxingAction.ActionType.HOOK], 2],
		[[BoxingAction.ActionType.JAB, BoxingAction.ActionType.CROSS], 1],
	])

# =============================================================================
# Utility
# =============================================================================

## Pick from weighted options. Each item is [value, weight].
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
