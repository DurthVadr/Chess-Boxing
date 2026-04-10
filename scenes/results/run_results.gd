extends Control

## Run Results — Score, rating, stats, achievements, perks, ELO changes

@onready var result_label: Label = %ResultLabel
@onready var stats_container: VBoxContainer = %StatsContainer
@onready var retry_btn: Button = %RetryBtn
@onready var next_tournament_btn: Button = %NextTournamentBtn

func _ready() -> void:
	retry_btn.pressed.connect(_on_retry)
	next_tournament_btn.pressed.connect(_on_next_tournament)

	var won: bool = GameManager.stats.get("fights_won", 0) >= GameManager.total_opponents
	var score_data: Dictionary = GameManager.run_score

	# Title
	if won:
		result_label.text = "CHAMPION!"
		result_label.add_theme_color_override("font_color", Color(0.9, 0.78, 0.3))
		AudioManager.play_victory()
		Juice.screen_flash(self, Color(0.92, 0.78, 0.22, 0.3), 0.32)
		Juice.screen_shake(self, 11.0, 0.38)
		Juice.confetti(self, 6)
		var tw_celebrate := create_tween()
		tw_celebrate.tween_interval(0.36)
		tw_celebrate.tween_callback(func() -> void:
			Juice.screen_flash(self, Color(0.45, 0.55, 0.98, 0.14), 0.22)
			Juice.confetti(self, 3, false)
		)
		# Show "Next Tournament" button only on victory
		next_tournament_btn.visible = true
	else:
		result_label.text = "KNOCKED OUT"
		result_label.add_theme_color_override("font_color", Color(0.8, 0.3, 0.3))
		AudioManager.play_defeat()
		Juice.screen_shake(self, 10.0, 0.35)
		next_tournament_btn.visible = false

	# Tournament & ELO header
	_add_tournament_info(won)

	# Rating
	_add_rating(score_data)

	# Stats
	_build_stats()

	# Score breakdown
	_add_score_breakdown(score_data)

	# ELO breakdown per fight
	_add_elo_breakdown()

	# Achievements
	_add_achievements()

	# Perks collected
	_add_perks()

	Juice.fade_in(self, 0.5)
	Juice.scale_bounce(result_label, 1.2, 0.6)

func _add_tournament_info(won: bool) -> void:
	var tourney := GameManager.run_tournament_number
	var elo := SaveManager.player_elo
	var elo_delta := GameManager.get_run_elo_total()
	var delta_text := ""
	if elo_delta >= 0:
		delta_text = "[color=#6edc6e]+%d[/color]" % elo_delta
	else:
		delta_text = "[color=#dc6e6e]%d[/color]" % elo_delta

	var info := RichTextLabel.new()
	info.bbcode_enabled = true
	info.fit_content = true
	info.scroll_active = false
	info.custom_minimum_size = Vector2(0, 30)
	info.text = "[center]TOURNAMENT %d  |  ELO: %d (%s)[/center]" % [tourney, elo, delta_text]
	info.add_theme_font_size_override("normal_font_size", 18)
	stats_container.add_child(info)

	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 4)
	stats_container.add_child(spacer)

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

func _add_elo_breakdown() -> void:
	if GameManager.run_elo_deltas.is_empty():
		return

	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 8)
	stats_container.add_child(spacer)

	var header := Label.new()
	header.text = "ELO Changes"
	header.add_theme_font_size_override("font_size", 14)
	header.add_theme_color_override("font_color", Color(0.7, 0.68, 0.6))
	header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stats_container.add_child(header)

	for entry in GameManager.run_elo_deltas:
		var opp_name: String = entry.get("opponent", "?")
		var delta: int = entry.get("delta", 0)
		var won: bool = entry.get("won", false)
		var result_text := "W" if won else "L"
		var delta_str := "+%d" % delta if delta >= 0 else "%d" % delta
		var color := Color(0.43, 0.86, 0.43) if won else Color(0.86, 0.43, 0.43)

		var label := Label.new()
		label.text = "  %s [%s] %s" % [opp_name, result_text, delta_str]
		label.add_theme_font_size_override("font_size", 13)
		label.add_theme_color_override("font_color", color)
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

func _on_next_tournament() -> void:
	AudioManager.play_confirm()
	SaveManager.advance_tournament()
	# Go straight to fighter select for the next tournament
	GameManager.change_phase(GameManager.GamePhase.FIGHTER_SELECT)
