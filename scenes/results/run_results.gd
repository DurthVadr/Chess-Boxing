extends Control

## Run Results — Score, rating, stats, achievements, and perks

@onready var result_label: Label = %ResultLabel
@onready var stats_container: VBoxContainer = %StatsContainer
@onready var retry_btn: Button = %RetryBtn

func _ready() -> void:
	retry_btn.pressed.connect(_on_retry)

	var won: bool = GameManager.stats.get("fights_won", 0) >= GameManager.total_opponents
	var score_data: Dictionary = GameManager.run_score

	# Title
	if won:
		result_label.text = "CHAMPION!"
		result_label.add_theme_color_override("font_color", Color(0.9, 0.78, 0.3))
		AudioManager.play_victory()
		Juice.screen_flash(self, Color(0.9, 0.8, 0.2, 0.25), 0.3)
		Juice.screen_shake(self, 8.0, 0.3)
	else:
		result_label.text = "KNOCKED OUT"
		result_label.add_theme_color_override("font_color", Color(0.8, 0.3, 0.3))
		AudioManager.play_defeat()
		Juice.screen_shake(self, 10.0, 0.35)

	# Rating
	_add_rating(score_data)

	# Stats
	_build_stats()

	# Score breakdown
	_add_score_breakdown(score_data)

	# Achievements
	_add_achievements()

	# Perks collected
	_add_perks()

	Juice.fade_in(self, 0.5)
	Juice.scale_bounce(result_label, 1.2, 0.6)

func _add_rating(score_data: Dictionary) -> void:
	var rating: String = score_data.get("rating", "F")
	var rating_color: Color = score_data.get("rating_color", Color.WHITE)
	var score: int = score_data.get("score", 0)

	var rating_label := Label.new()
	rating_label.text = "RATING: %s" % rating
	rating_label.add_theme_font_size_override("font_size", 40)
	rating_label.add_theme_color_override("font_color", rating_color)
	rating_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stats_container.add_child(rating_label)
	Juice.punch_text(rating_label, 0.5)

	var score_label := Label.new()
	score_label.text = "Score: %d" % score
	score_label.add_theme_font_size_override("font_size", 18)
	score_label.add_theme_color_override("font_color", Color(0.8, 0.78, 0.7))
	score_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stats_container.add_child(score_label)

	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 10)
	stats_container.add_child(spacer)

func _build_stats() -> void:
	var s: Dictionary = GameManager.stats

	var stat_lines := [
		"Fights Won: %d / %d" % [s.get("fights_won", 0), GameManager.total_opponents],
		"Puzzles Solved: %d  |  Failed: %d" % [s.get("puzzles_solved", 0), s.get("puzzles_failed", 0)],
		"Damage Dealt: %d  |  Taken: %d" % [s.get("total_damage_dealt", 0), s.get("total_damage_taken", 0)],
		"Perks Drafted: %d" % s.get("perks_drafted", 0),
	]

	var fastest: float = s.get("fastest_puzzle_time", 999.0)
	if fastest < 900.0:
		stat_lines.append("Fastest Puzzle: %.1fs" % fastest)

	# Average heat
	var heat_history: Array = s.get("heat_history", [])
	if not heat_history.is_empty():
		var total := 0.0
		for h in heat_history:
			total += h
		stat_lines.append("Avg Heat: %.1fx" % (total / heat_history.size()))

	for line in stat_lines:
		var label := Label.new()
		label.text = line
		label.add_theme_font_size_override("font_size", 15)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		stats_container.add_child(label)

func _add_score_breakdown(score_data: Dictionary) -> void:
	var breakdown: Dictionary = score_data.get("breakdown", {})
	if breakdown.is_empty():
		return

	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 8)
	stats_container.add_child(spacer)

	var header := Label.new()
	header.text = "Score Breakdown"
	header.add_theme_font_size_override("font_size", 14)
	header.add_theme_color_override("font_color", Color(0.7, 0.68, 0.6))
	header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stats_container.add_child(header)

	var display_names := {
		"combat": "Combat",
		"win_bonus": "Win Bonus",
		"chess": "Chess",
		"speed": "Speed",
		"heat": "Heat",
		"efficiency": "Efficiency",
		"synergy": "Synergy",
	}

	for key in breakdown:
		var val: int = breakdown[key]
		if val == 0:
			continue
		var display_name: String = display_names.get(key, key)
		var label := Label.new()
		label.text = "  %s: +%d" % [display_name, val]
		label.add_theme_font_size_override("font_size", 13)
		label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.58))
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		stats_container.add_child(label)

func _add_achievements() -> void:
	if GameManager.run_achievements.is_empty():
		return

	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 10)
	stats_container.add_child(spacer)

	var header := Label.new()
	header.text = "NEW UNLOCKS!"
	header.add_theme_font_size_override("font_size", 18)
	header.add_theme_color_override("font_color", Color(0.9, 0.78, 0.3))
	header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stats_container.add_child(header)
	Juice.scale_bounce(header, 1.1, 0.4)

	for ach in GameManager.run_achievements:
		var label := Label.new()
		label.text = "%s — %s" % [ach.get("name", "?"), ach.get("description", "")]
		label.add_theme_font_size_override("font_size", 14)
		label.add_theme_color_override("font_color", Color(0.85, 0.75, 0.35))
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		stats_container.add_child(label)

func _add_perks() -> void:
	if GameManager.active_perks.is_empty():
		return

	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 8)
	stats_container.add_child(spacer)

	var header := Label.new()
	header.text = "Perks Collected"
	header.add_theme_font_size_override("font_size", 14)
	header.add_theme_color_override("font_color", Color(0.7, 0.68, 0.6))
	header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stats_container.add_child(header)

	for perk in GameManager.active_perks:
		var label := Label.new()
		label.text = "  %s — %s" % [perk.get("name", "?"), perk.get("description", "")]
		label.add_theme_font_size_override("font_size", 12)
		label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.58))
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		stats_container.add_child(label)

func _on_retry() -> void:
	AudioManager.play_button_click()
	GameManager.change_phase(GameManager.GamePhase.MENU)
