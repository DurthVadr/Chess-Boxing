extends Control

## Run Results — Victory/Defeat screen with stats summary

@onready var result_label: Label = %ResultLabel
@onready var stats_container: VBoxContainer = %StatsContainer
@onready var retry_btn: Button = %RetryBtn

func _ready() -> void:
	retry_btn.pressed.connect(_on_retry)

	var won := GameManager.stats.fights_won >= GameManager.total_opponents

	if won:
		result_label.text = "CHAMPION!"
		result_label.add_theme_color_override("font_color", Color(0.9, 0.78, 0.3))
	else:
		result_label.text = "KNOCKED OUT"
		result_label.add_theme_color_override("font_color", Color(0.8, 0.2, 0.2))

	_build_stats()
	Juice.fade_in(self, 0.5)
	Juice.scale_bounce(result_label, 1.2, 0.6)

func _build_stats() -> void:
	var s := GameManager.stats

	var stat_lines := [
		"Fights Won: %d / %d" % [s.fights_won, GameManager.total_opponents],
		"Puzzles Solved: %d" % s.puzzles_solved,
		"Puzzles Failed: %d" % s.puzzles_failed,
		"Total Damage Dealt: %d" % s.total_damage_dealt,
		"Total Damage Taken: %d" % s.total_damage_taken,
		"Perks Drafted: %d" % s.perks_drafted,
	]

	if s.fastest_puzzle_time < 900.0:
		stat_lines.append("Fastest Puzzle Solve: %.1fs" % s.fastest_puzzle_time)

	for line in stat_lines:
		var label := Label.new()
		label.text = line
		label.add_theme_font_size_override("font_size", 18)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		stats_container.add_child(label)

	# Show perks collected
	if GameManager.active_perks.size() > 0:
		var perk_header := Label.new()
		perk_header.text = "\nPerks Collected:"
		perk_header.add_theme_font_size_override("font_size", 16)
		perk_header.add_theme_color_override("font_color", Color(0.9, 0.78, 0.3))
		perk_header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		stats_container.add_child(perk_header)

		for perk in GameManager.active_perks:
			var plabel := Label.new()
			plabel.text = "• " + perk.name + " — " + perk.description
			plabel.add_theme_font_size_override("font_size", 14)
			plabel.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
			plabel.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			stats_container.add_child(plabel)

func _on_retry() -> void:
	GameManager.change_phase(GameManager.GamePhase.MENU)
