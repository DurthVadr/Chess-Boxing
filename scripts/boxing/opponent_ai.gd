class_name OpponentAI
extends RefCounted

## AI behavior for boxing opponents based on archetype

enum Archetype { BRAWLER, TECHNICIAN, TURTLE, GLASS_CANNON, BOSS }

var archetype: Archetype = Archetype.BRAWLER
var last_player_action: BoxingAction.ActionType = BoxingAction.ActionType.JAB
var turn_count: int = 0

func setup(archetype_name: String) -> void:
	match archetype_name:
		"brawler": archetype = Archetype.BRAWLER
		"technician": archetype = Archetype.TECHNICIAN
		"turtle": archetype = Archetype.TURTLE
		"glass_cannon": archetype = Archetype.GLASS_CANNON
		"boss": archetype = Archetype.BOSS
		_: archetype = Archetype.BRAWLER

func choose_action(opponent_hp_pct: float, opponent_stamina: int, player_hp_pct: float) -> BoxingAction.ActionType:
	turn_count += 1

	# Need stamina to attack
	if opponent_stamina < 10:
		return BoxingAction.ActionType.CLINCH

	var action: BoxingAction.ActionType

	match archetype:
		Archetype.BRAWLER:
			action = _brawler_ai(opponent_hp_pct, opponent_stamina)
		Archetype.TECHNICIAN:
			action = _technician_ai(opponent_hp_pct, opponent_stamina, player_hp_pct)
		Archetype.TURTLE:
			action = _turtle_ai(opponent_hp_pct, opponent_stamina, player_hp_pct)
		Archetype.GLASS_CANNON:
			action = _glass_cannon_ai(opponent_hp_pct, opponent_stamina)
		Archetype.BOSS:
			action = _boss_ai(opponent_hp_pct, opponent_stamina, player_hp_pct)
		_:
			action = _brawler_ai(opponent_hp_pct, opponent_stamina)

	return action

func get_telegraph_hint(action: BoxingAction.ActionType) -> String:
	match action:
		BoxingAction.ActionType.JAB: return "Quick jab incoming..."
		BoxingAction.ActionType.CROSS: return "Winding up a cross..."
		BoxingAction.ActionType.HOOK: return "Setting up a hook!"
		BoxingAction.ActionType.UPPERCUT: return "BIG windup — UPPERCUT!"
		BoxingAction.ActionType.BLOCK: return "Getting defensive..."
		BoxingAction.ActionType.DODGE: return "Looking to slip..."
		BoxingAction.ActionType.CLINCH: return "Moving in to clinch..."
	return "..."

func record_player_action(action: BoxingAction.ActionType) -> void:
	last_player_action = action

# --- Archetype AIs ---

func _brawler_ai(hp_pct: float, stamina: int) -> BoxingAction.ActionType:
	# Aggressive and predictable: mostly jabs and crosses, occasional hook
	if stamina < 20:
		return BoxingAction.ActionType.CLINCH

	var roll := randf()
	if hp_pct < 0.3:
		# Desperate — go for big hits
		if roll < 0.4: return BoxingAction.ActionType.HOOK
		if roll < 0.7: return BoxingAction.ActionType.UPPERCUT
		return BoxingAction.ActionType.CROSS

	if roll < 0.35: return BoxingAction.ActionType.JAB
	if roll < 0.65: return BoxingAction.ActionType.CROSS
	if roll < 0.85: return BoxingAction.ActionType.HOOK
	return BoxingAction.ActionType.JAB

func _technician_ai(hp_pct: float, stamina: int, player_hp_pct: float) -> BoxingAction.ActionType:
	# Adapts to player — counters their last move
	if stamina < 20:
		return BoxingAction.ActionType.BLOCK

	# Counter-play based on last player action
	match last_player_action:
		BoxingAction.ActionType.HOOK, BoxingAction.ActionType.UPPERCUT:
			if randf() < 0.6: return BoxingAction.ActionType.DODGE
		BoxingAction.ActionType.BLOCK, BoxingAction.ActionType.CLINCH:
			if randf() < 0.5: return BoxingAction.ActionType.HOOK  # Punish passivity
		BoxingAction.ActionType.JAB:
			if randf() < 0.4: return BoxingAction.ActionType.CROSS  # Trade up

	# Default balanced play
	if player_hp_pct < 0.3 and stamina >= 30:
		return BoxingAction.ActionType.UPPERCUT  # Finish them

	var roll := randf()
	if roll < 0.3: return BoxingAction.ActionType.JAB
	if roll < 0.55: return BoxingAction.ActionType.CROSS
	if roll < 0.75: return BoxingAction.ActionType.BLOCK
	return BoxingAction.ActionType.HOOK

func _turtle_ai(hp_pct: float, stamina: int, player_hp_pct: float) -> BoxingAction.ActionType:
	# Very defensive — blocks a lot, waits for counter opportunities
	if stamina < 15:
		return BoxingAction.ActionType.CLINCH

	# If player just used a big attack, counter
	if last_player_action == BoxingAction.ActionType.UPPERCUT or last_player_action == BoxingAction.ActionType.HOOK:
		if randf() < 0.5: return BoxingAction.ActionType.CROSS

	# Mostly block
	var roll := randf()
	if hp_pct > 0.5:
		if roll < 0.45: return BoxingAction.ActionType.BLOCK
		if roll < 0.65: return BoxingAction.ActionType.JAB
		if roll < 0.80: return BoxingAction.ActionType.DODGE
		return BoxingAction.ActionType.CROSS
	else:
		# More aggressive when low HP
		if roll < 0.25: return BoxingAction.ActionType.BLOCK
		if roll < 0.50: return BoxingAction.ActionType.CROSS
		if roll < 0.70: return BoxingAction.ActionType.HOOK
		return BoxingAction.ActionType.JAB

func _glass_cannon_ai(_hp_pct: float, stamina: int) -> BoxingAction.ActionType:
	# All-out attack, rarely blocks
	if stamina < 10:
		return BoxingAction.ActionType.CLINCH

	var roll := randf()
	if roll < 0.25: return BoxingAction.ActionType.UPPERCUT
	if roll < 0.50: return BoxingAction.ActionType.HOOK
	if roll < 0.75: return BoxingAction.ActionType.CROSS
	return BoxingAction.ActionType.JAB

func _boss_ai(hp_pct: float, stamina: int, player_hp_pct: float) -> BoxingAction.ActionType:
	# Smart and dangerous — adapts, uses full toolkit
	if stamina < 15:
		if randf() < 0.5: return BoxingAction.ActionType.BLOCK
		return BoxingAction.ActionType.CLINCH

	# Phase 1: Controlled aggression
	if hp_pct > 0.6:
		match last_player_action:
			BoxingAction.ActionType.HOOK, BoxingAction.ActionType.UPPERCUT:
				if randf() < 0.7: return BoxingAction.ActionType.DODGE
			BoxingAction.ActionType.BLOCK, BoxingAction.ActionType.CLINCH:
				if randf() < 0.6: return BoxingAction.ActionType.UPPERCUT

		var roll := randf()
		if roll < 0.25: return BoxingAction.ActionType.CROSS
		if roll < 0.45: return BoxingAction.ActionType.HOOK
		if roll < 0.65: return BoxingAction.ActionType.JAB
		if roll < 0.80: return BoxingAction.ActionType.BLOCK
		return BoxingAction.ActionType.DODGE

	# Phase 2: Desperate but smart
	if player_hp_pct < 0.3 and stamina >= 30:
		return BoxingAction.ActionType.UPPERCUT

	var roll := randf()
	if roll < 0.3: return BoxingAction.ActionType.HOOK
	if roll < 0.5: return BoxingAction.ActionType.CROSS
	if roll < 0.65: return BoxingAction.ActionType.DODGE
	if roll < 0.80: return BoxingAction.ActionType.JAB
	return BoxingAction.ActionType.BLOCK
