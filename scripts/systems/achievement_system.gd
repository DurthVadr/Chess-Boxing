class_name AchievementSystem
extends RefCounted

## Checks run stats against achievement conditions.
## Returns list of newly unlocked achievement IDs.

static func check_achievements(
	stats: Dictionary,
	run_score: Dictionary,
	perks: Array,
	won: bool,
	already_unlocked: Array
) -> Array:
	var newly_unlocked: Array = []
	var all_achievements: Array = _load_achievements()

	for ach in all_achievements:
		var ach_id: String = ach.get("id", "")
		if ach_id in already_unlocked:
			continue

		var condition: String = ach.get("condition", "")
		if _check_condition(condition, stats, run_score, perks, won):
			newly_unlocked.append(ach)

	return newly_unlocked

static func _check_condition(
	condition: String,
	stats: Dictionary,
	run_score: Dictionary,
	perks: Array,
	won: bool
) -> bool:
	match condition:
		"win_run":
			return won

		"fastest_puzzle_under_5":
			return stats.get("fastest_puzzle_time", 999.0) < 5.0

		"low_damage_fight":
			return won and stats.get("total_damage_taken", 999) < 10

		"high_heat":
			var heat_history: Array = stats.get("heat_history", [])
			for h in heat_history:
				if h >= 4.5:
					return true
			return false

		"no_blocks":
			# Would need block tracking in stats — check if tracked
			return false  # TODO: track blocks_used in stats

		"zero_mistakes":
			return won and stats.get("puzzles_failed", 1) == 0

		"sacrifice_build":
			var sacrifice_count := 0
			for perk in perks:
				var tags: Array = perk.get("tags", [])
				if "sacrifice" in tags:
					sacrifice_count += 1
			return won and sacrifice_count >= 3

		"s_rating":
			var rating: String = run_score.get("rating", "F")
			return rating == "S" or rating == "S+"

		"combo_count_10":
			return stats.get("combos_landed", 0) >= 10

		"beat_boss_with_perks":
			# Check if boss had 3+ perks when defeated
			return won and stats.get("boss_perks_at_defeat", 0) >= 3

	return false

static func _load_achievements() -> Array:
	var file := FileAccess.open("res://data/achievements.json", FileAccess.READ)
	if file == null:
		return []
	var json := JSON.new()
	if json.parse(file.get_as_text()) != OK:
		return []
	if json.data is Array:
		return json.data
	return []
