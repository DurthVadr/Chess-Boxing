class_name BoxingAction
extends RefCounted

## Defines all boxing actions and their properties

enum ActionType { JAB, CROSS, HOOK, UPPERCUT, BLOCK, DODGE, CLINCH }

var type: ActionType
var name: String
var damage: int
var stamina_cost: int
var speed: int  # Lower = faster. Affects dodge chance against this move
var description: String

static func create_all() -> Dictionary:
	var actions := {}

	var jab := BoxingAction.new()
	jab.type = ActionType.JAB
	jab.name = "Jab"
	jab.damage = 5
	jab.stamina_cost = 8
	jab.speed = 1
	jab.description = "Quick punch. Low damage, low cost."
	actions[ActionType.JAB] = jab

	var cross := BoxingAction.new()
	cross.type = ActionType.CROSS
	cross.name = "Cross"
	cross.damage = 10
	cross.stamina_cost = 15
	cross.speed = 2
	cross.description = "Solid hit. Medium damage."
	actions[ActionType.CROSS] = cross

	var hook := BoxingAction.new()
	hook.type = ActionType.HOOK
	hook.name = "Hook"
	hook.damage = 15
	hook.stamina_cost = 22
	hook.speed = 3
	hook.description = "Heavy swing. Can be dodged."
	actions[ActionType.HOOK] = hook

	var uppercut := BoxingAction.new()
	uppercut.type = ActionType.UPPERCUT
	uppercut.name = "Uppercut"
	uppercut.damage = 22
	uppercut.stamina_cost = 30
	uppercut.speed = 4
	uppercut.description = "Devastating blow. Very slow windup."
	actions[ActionType.UPPERCUT] = uppercut

	var block := BoxingAction.new()
	block.type = ActionType.BLOCK
	block.name = "Block"
	block.damage = 0
	block.stamina_cost = -10  # Recovers stamina
	block.speed = 0
	block.description = "Guard up. Reduces damage, recovers stamina."
	actions[ActionType.BLOCK] = block

	var dodge := BoxingAction.new()
	dodge.type = ActionType.DODGE
	dodge.name = "Dodge"
	dodge.damage = 0
	dodge.stamina_cost = 12
	dodge.speed = 0
	dodge.description = "Slip the punch. Better vs slow attacks."
	actions[ActionType.DODGE] = dodge

	var clinch := BoxingAction.new()
	clinch.type = ActionType.CLINCH
	clinch.name = "Clinch"
	clinch.damage = 0
	clinch.stamina_cost = -20  # Big stamina recovery
	clinch.speed = 0
	clinch.description = "Hold on. Both fighters recover stamina."
	actions[ActionType.CLINCH] = clinch

	return actions
