class_name HeavyHandsCard
extends PerkCard

func modify_player_attack_damage(base_damage: int, context: Dictionary, _game_manager: Node) -> int:
	var piece: String = str(context.get("last_chess_piece_moved", ""))
	if piece == "":
		return base_damage
	piece = piece.to_upper()
	if piece == "Q" or piece == "R":
		return base_damage * 2
	return base_damage

