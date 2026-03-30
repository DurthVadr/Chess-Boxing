class_name ComboSystem
extends RefCounted

## Detects named 2-action combos and applies their bonuses.
## A combo is [Action1, Action2] → bonus effect.

const NAMED_COMBOS := {
	"JAB_JAB": {
		"name": "Double Tap",
		"description": "Two quick jabs — second gets +2 damage",
		"effect": "bonus_damage_action2",
		"bonus_damage": 2,
	},
	"JAB_CROSS": {
		"name": "One-Two",
		"description": "Classic combo — cross gets +3 damage",
		"effect": "bonus_damage_action2",
		"bonus_damage": 3,
	},
	"CROSS_UPPERCUT": {
		"name": "Setup Shot",
		"description": "Cross sets up the uppercut — uppercut gets +4 damage",
		"effect": "bonus_damage_action2",
		"bonus_damage": 4,
	},
	"JAB_UPPERCUT": {
		"name": "Flash KO",
		"description": "Jab then uppercut — uppercut gets +3 damage",
		"effect": "bonus_damage_action2",
		"bonus_damage": 3,
	},
	"CROSS_CROSS": {
		"name": "Power Straight",
		"description": "Double cross — second cross gets +2 damage",
		"effect": "bonus_damage_action2",
		"bonus_damage": 2,
	},
	"UPPERCUT_JAB": {
		"name": "Follow Through",
		"description": "Uppercut then jab — jab gets +2 damage",
		"effect": "bonus_damage_action2",
		"bonus_damage": 2,
	},
}

## Detect if a [action1, action2] pair is a named combo.
static func detect_combo(action1: BoxingAction.ActionType, action2: BoxingAction.ActionType) -> Dictionary:
	var key := action_to_string(action1) + "_" + action_to_string(action2)
	if key in NAMED_COMBOS:
		var combo: Dictionary = NAMED_COMBOS[key].duplicate()
		combo["key"] = key
		return combo
	return {}

## Get the display name for a combo, or "" if not a named combo.
static func get_combo_name(action1: BoxingAction.ActionType, action2: BoxingAction.ActionType) -> String:
	var combo := detect_combo(action1, action2)
	return combo.get("name", "")

## Convert ActionType enum to string key.
static func action_to_string(action: BoxingAction.ActionType) -> String:
	match action:
		BoxingAction.ActionType.JAB: return "JAB"
		BoxingAction.ActionType.CROSS: return "CROSS"
		BoxingAction.ActionType.UPPERCUT: return "UPPERCUT"
	return "UNKNOWN"

## All actions are attacks now.
static func is_attack(_action: BoxingAction.ActionType) -> bool:
	return true
