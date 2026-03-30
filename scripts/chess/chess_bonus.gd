class_name ChessBonus
extends RefCounted

## Calculates chess bonus effects that carry into the boxing phase

## Calculate bonus damage based on chess performance
static func get_bonus_damage(chess_bonus: float) -> int:
	return int(chess_bonus * 5.0)  # 0 to 5 bonus damage

## Calculate bonus defense based on chess performance
static func get_bonus_defense(chess_bonus: float) -> int:
	return int(chess_bonus * 3.0)  # 0 to 3 bonus defense

## Get descriptive text for the bonus level
static func get_bonus_text(chess_bonus: float) -> String:
	if chess_bonus >= 0.8:
		return "BRILLIANT! Massive bonus!"
	elif chess_bonus >= 0.5:
		return "Great solve! Good bonus."
	elif chess_bonus >= 0.2:
		return "Solved. Small bonus."
	elif chess_bonus > 0.0:
		return "Barely made it. Tiny bonus."
	else:
		return "Failed! Opponent gets the bonus!"
