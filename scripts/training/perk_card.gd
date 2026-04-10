class_name PerkCard
extends Resource

@export var id: String = ""
@export var card_name: String = ""
@export_multiline var description: String = ""
@export var cost: int = 3

## Called when the card is purchased.
func on_purchase(_game_manager: Node) -> void:
	pass

## Called from chess pressure tick to allow cards to modify passive damage.
func modify_pressure_damage(base_damage: int, _game_manager: Node) -> int:
	return base_damage

## Called from player attack damage calculation to allow cards to modify damage.
## context may contain: {"last_chess_piece_moved": "Q"/"R"/...}
func modify_player_attack_damage(base_damage: int, _context: Dictionary, _game_manager: Node) -> int:
	return base_damage

## Called from chess phase to attempt an active ability.
## Returns true if it activated.
func try_activate(_chess_phase: Node, _game_manager: Node) -> bool:
	return false

