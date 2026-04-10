class_name FocusBreathCard
extends PerkCard

## One-time use per run. Pauses the chess pressure timer for 3 seconds.
func try_activate(chess_phase: Node, game_manager: Node) -> bool:
	if not is_instance_valid(game_manager):
		return false
	if game_manager.has_training_card_used(id):
		return false

	# chess_phase is expected to provide a pause API.
	if not chess_phase.has_method("pause_pressure_for_seconds"):
		return false

	game_manager.mark_training_card_used(id)
	chess_phase.pause_pressure_for_seconds(3.0)
	return true

