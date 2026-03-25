class_name ComboSystem
extends RefCounted

## Detects named 2-action combos and applies their bonuses.
## A combo is [Action1, Action2] → bonus effect.

# Combo definitions: key = "ACTION1_ACTION2", value = combo data
const NAMED_COMBOS := {
	"DODGE_UPPERCUT": {
		"name": "Slip Counter",
		"description": "Dodge then uppercut — guaranteed hit if dodge succeeds",
		"effect": "guaranteed_hit_action2",
	},
	"JAB_JAB": {
		"name": "Double Tap",
		"description": "Two quick jabs — second costs half stamina",
		"effect": "half_stamina_action2",
	},
	"JAB_CROSS": {
		"name": "One-Two",
		"description": "Classic combo — cross gets +3 damage",
		"effect": "bonus_damage_action2",
		"bonus_damage": 3,
	},
	"BLOCK_HOOK": {
		"name": "Parry Hook",
		"description": "Block then hook — hook gets bonus equal to damage blocked",
		"effect": "stored_damage_action2",
	},
	"BLOCK_BLOCK": {
		"name": "Hunker Down",
		"description": "Double block — second block reduces 75%, recover 5 HP",
		"effect": "enhanced_block_action2",
		"hp_recovery": 5,
	},
	"HOOK_UPPERCUT": {
		"name": "Haymaker Combo",
		"description": "Hook then uppercut — if hook lands, uppercut dodge chance halved",
		"effect": "reduced_dodge_action2",
	},
	"CLINCH_JAB": {
		"name": "Dirty Boxing",
		"description": "Clinch then jab — jab is guaranteed hit",
		"effect": "guaranteed_hit_action2",
	},
	"DODGE_DODGE": {
		"name": "Float",
		"description": "Double dodge — recover 5 stamina, both get +10% success",
		"effect": "enhanced_dodge",
		"stamina_recovery": 5,
		"dodge_bonus": 0.1,
	},
	"DODGE_CROSS": {
		"name": "Counter Cross",
		"description": "Dodge then cross — cross gets +4 damage if dodge succeeds",
		"effect": "bonus_damage_action2",
		"bonus_damage": 4,
	},
	"CROSS_HOOK": {
		"name": "Body Work",
		"description": "Cross to body then hook — drains opponent stamina",
		"effect": "stamina_drain",
		"stamina_drain": 8,
	},
}

## Detect if a [action1, action2] pair is a named combo.
## Returns combo dict with "name", "effect", etc. or empty dict.
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
		BoxingAction.ActionType.HOOK: return "HOOK"
		BoxingAction.ActionType.UPPERCUT: return "UPPERCUT"
		BoxingAction.ActionType.BLOCK: return "BLOCK"
		BoxingAction.ActionType.DODGE: return "DODGE"
		BoxingAction.ActionType.CLINCH: return "CLINCH"
	return "UNKNOWN"

## Check if an action is an attack (deals damage).
static func is_attack(action: BoxingAction.ActionType) -> bool:
	return action in [
		BoxingAction.ActionType.JAB,
		BoxingAction.ActionType.CROSS,
		BoxingAction.ActionType.HOOK,
		BoxingAction.ActionType.UPPERCUT,
	]
