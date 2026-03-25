extends Node

## Persistent save/load for meta-progression (unlocks, achievements, best scores).
## Run state is NOT saved (roguelike permadeath).

const SAVE_PATH := "user://save_data.json"

var unlocked_fighters: Array = ["rookie"]
var unlocked_achievements: Array = []
var unlocked_perks: Array = []  # Perks unlocked via achievements
var best_scores: Dictionary = {}  # {path: {score, rating}}
var total_runs: int = 0

func _ready() -> void:
	load_save()

func save_data() -> void:
	var data := {
		"unlocked_fighters": unlocked_fighters,
		"unlocked_achievements": unlocked_achievements,
		"unlocked_perks": unlocked_perks,
		"best_scores": best_scores,
		"total_runs": total_runs,
	}
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		push_warning("Failed to save: " + SAVE_PATH)
		return
	file.store_string(JSON.stringify(data, "\t"))
	file.close()

func load_save() -> void:
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		return  # No save file yet, use defaults
	var json := JSON.new()
	if json.parse(file.get_as_text()) != OK:
		return
	file.close()

	var data: Dictionary = json.data if json.data is Dictionary else {}
	unlocked_fighters = data.get("unlocked_fighters", ["rookie"])
	unlocked_achievements = data.get("unlocked_achievements", [])
	unlocked_perks = data.get("unlocked_perks", [])
	best_scores = data.get("best_scores", {})
	total_runs = int(data.get("total_runs", 0))

func unlock_fighter(fighter_id: String) -> void:
	if fighter_id not in unlocked_fighters:
		unlocked_fighters.append(fighter_id)
		save_data()

func unlock_achievement(achievement_id: String) -> void:
	if achievement_id not in unlocked_achievements:
		unlocked_achievements.append(achievement_id)
		save_data()

func unlock_perk(perk_id: String) -> void:
	if perk_id not in unlocked_perks:
		unlocked_perks.append(perk_id)
		save_data()

func is_fighter_unlocked(fighter_id: String) -> bool:
	return fighter_id in unlocked_fighters

func record_run(score_data: Dictionary, path: String) -> void:
	total_runs += 1
	var key := path if path != "" else "default"
	var current_best: Dictionary = best_scores.get(key, {})
	if score_data.get("score", 0) > current_best.get("score", 0):
		best_scores[key] = {"score": score_data.score, "rating": score_data.rating}
	save_data()
