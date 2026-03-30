class_name BoxingAction
extends RefCounted

## Defines all boxing actions and their properties

enum ActionType { JAB, CROSS, UPPERCUT }

var type: ActionType
var name: String
var damage: int
var description: String

static func create_all() -> Dictionary:
	var actions := {}

	var jab := BoxingAction.new()
	jab.type = ActionType.JAB
	jab.name = "Jab"
	jab.damage = 6
	jab.description = "Quick jab. Reliable damage, easy timing."
	actions[ActionType.JAB] = jab

	var cross := BoxingAction.new()
	cross.type = ActionType.CROSS
	cross.name = "Cross"
	cross.damage = 10
	cross.description = "Straight cross. Gradual timing reward."
	actions[ActionType.CROSS] = cross

	var uppercut := BoxingAction.new()
	uppercut.type = ActionType.UPPERCUT
	uppercut.name = "Uppercut"
	uppercut.damage = 25
	uppercut.description = "Devastating uppercut. Huge on critical, weak otherwise."
	actions[ActionType.UPPERCUT] = uppercut

	return actions
