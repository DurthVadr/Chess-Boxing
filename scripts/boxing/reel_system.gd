class_name ReelSystem
extends RefCounted

## Static utility for the slot-reel action selection system.
## Each reel has an array of symbols (BoxingAction.ActionType).
## The player stops 3 spinning reels to determine their 3 actions per turn.

const DEFAULT_REEL_SIZE := 4
const CRITICAL_MULTIPLIER := 3.0

## Check if 3 reel results are a triple match (all same symbol).
static func is_triple(results: Array) -> bool:
	if results.size() != 3:
		return false
	return results[0] == results[1] and results[1] == results[2]

## Get the critical hit multiplier for a triple match.
## Factors in perk bonuses from PerkSystem.
static func get_critical_multiplier() -> float:
	var base := CRITICAL_MULTIPLIER
	if GameManager.has_perk("slot_master"):
		base += GameManager.get_perk_scaled_value("slot_master", 0.0)
	return base

## Pick a random symbol from a reel array (used for spin animation).
static func random_symbol(reel: Array) -> BoxingAction.ActionType:
	if reel.is_empty():
		return BoxingAction.ActionType.JAB
	return reel[randi() % reel.size()]

## Pick the final landing symbol for a reel (weighted by pool contents).
## More copies of a symbol = higher chance of landing on it.
static func spin_reel(reel: Array) -> BoxingAction.ActionType:
	if reel.is_empty():
		return BoxingAction.ActionType.JAB
	reel.shuffle()
	return reel[0]

## Build the default starting reels (3 reels, each with JAB symbols).
static func create_default_reels() -> Array:
	return [
		[BoxingAction.ActionType.JAB, BoxingAction.ActionType.JAB, BoxingAction.ActionType.JAB, BoxingAction.ActionType.JAB],
		[BoxingAction.ActionType.JAB, BoxingAction.ActionType.JAB, BoxingAction.ActionType.JAB, BoxingAction.ActionType.JAB],
		[BoxingAction.ActionType.JAB, BoxingAction.ActionType.JAB, BoxingAction.ActionType.JAB, BoxingAction.ActionType.JAB],
	]

## Add a symbol to a specific reel (0, 1, or 2).
static func add_symbol(reels: Array, reel_index: int, symbol: BoxingAction.ActionType) -> void:
	if reel_index >= 0 and reel_index < reels.size():
		reels[reel_index].append(symbol)

## Remove one instance of a symbol from a specific reel. Returns true if removed.
static func remove_symbol(reels: Array, reel_index: int, symbol: BoxingAction.ActionType) -> bool:
	if reel_index >= 0 and reel_index < reels.size():
		var idx := (reels[reel_index] as Array).find(symbol)
		if idx >= 0:
			reels[reel_index].remove_at(idx)
			return true
	return false

## Get symbol distribution for a reel as {ActionType: count}.
static func get_reel_distribution(reel: Array) -> Dictionary:
	var dist := {}
	for symbol in reel:
		dist[symbol] = dist.get(symbol, 0) + 1
	return dist

## Get the probability of a specific symbol landing on a reel.
static func get_symbol_chance(reel: Array, symbol: BoxingAction.ActionType) -> float:
	if reel.is_empty():
		return 0.0
	var count := 0
	for s in reel:
		if s == symbol:
			count += 1
	return float(count) / float(reel.size())

## Get display name for a symbol.
static func symbol_name(symbol: BoxingAction.ActionType) -> String:
	var all_actions := BoxingAction.create_all()
	if symbol in all_actions:
		return (all_actions[symbol] as BoxingAction).name
	return "?"

## Get symbol color for UI rendering.
static func symbol_color(symbol: BoxingAction.ActionType) -> Color:
	match symbol:
		BoxingAction.ActionType.JAB:
			return Color(0.52, 0.22, 0.18)
		BoxingAction.ActionType.CROSS:
			return Color(0.58, 0.26, 0.16)
		BoxingAction.ActionType.UPPERCUT:
			return Color(0.62, 0.26, 0.14)
	return Color(0.3, 0.3, 0.3)

## Get symbol accent (lighter, for text).
static func symbol_accent(symbol: BoxingAction.ActionType) -> Color:
	return symbol_color(symbol).lightened(0.35)

## Get available draft symbols based on opponent index (progression).
## Fight 1 win: can draft JAB or CROSS
## Fight 2 win: can draft JAB, CROSS, or UPPERCUT
## Fight 3+: all types
static func get_draft_pool(opponent_index: int) -> Array:
	if opponent_index <= 1:
		return [BoxingAction.ActionType.JAB, BoxingAction.ActionType.CROSS]
	return [BoxingAction.ActionType.JAB, BoxingAction.ActionType.CROSS, BoxingAction.ActionType.UPPERCUT]
