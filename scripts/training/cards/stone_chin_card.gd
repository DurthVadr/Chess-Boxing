class_name StoneChinCard
extends PerkCard

func modify_pressure_damage(base_damage: int, _game_manager: Node) -> int:
	# Reduce passive pressure damage by 20%
	return int(round(float(base_damage) * 0.8))

