extends Node

## Persistent save/load for meta-progression (unlocks, achievements, best scores).
## Run state is NOT saved (roguelike permadeath).

const SAVE_PATH := "user://save_data.json"

var unlocked_fighters: Array = ["rookie"]
var unlocked_achievements: Array = []
var unlocked_perks: Array = []  # Perks unlocked via achievements
var best_scores: Dictionary = {}  # {path: {score, rating}}
var total_runs: int = 0

# --- ELO & Tournament Progression ---
var player_elo: int = 0
var elo_history: Array = []        # Array of {tournament, elo_before, elo_after, won}
var tournament_number: int = 1     # Current tournament (persists across runs)

## User settings (audio, display, CRT) — persisted alongside meta-progression.
var settings: Dictionary = {
	"master_volume": 80,
	"music_volume": 80,
	"sfx_volume": 80,
	"crt_enabled": true,
	"crt_intensity": 100,
	"screen_shake": true,
	"fullscreen": false,
}

func _ready() -> void:
	load_save()
	call_deferred("_apply_settings")

func save_data() -> void:
	var data := {
		"unlocked_fighters": unlocked_fighters,
		"unlocked_achievements": unlocked_achievements,
		"unlocked_perks": unlocked_perks,
		"best_scores": best_scores,
		"total_runs": total_runs,
		"player_elo": player_elo,
		"elo_history": elo_history,
		"tournament_number": tournament_number,
		"settings": settings,
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
	player_elo = int(data.get("player_elo", 0))
	elo_history = data.get("elo_history", [])
	tournament_number = int(data.get("tournament_number", 1))

	# Merge saved settings over defaults (so new keys get defaults)
	var saved_settings: Dictionary = data.get("settings", {})
	for key in saved_settings:
		settings[key] = saved_settings[key]

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

func get_fighter_required_elo(fighter_id: String) -> int:
	for fighter in GameManager.all_fighters:
		if fighter.get("id", "") == fighter_id:
			return int(fighter.get("required_elo", 0))
	return 0

func is_fighter_elo_unlocked(fighter_id: String) -> bool:
	return player_elo >= get_fighter_required_elo(fighter_id)

func reset_all_progress() -> void:
	unlocked_fighters = ["rookie"]
	unlocked_achievements = []
	unlocked_perks = []
	best_scores = {}
	total_runs = 0
	player_elo = 0
	elo_history = []
	tournament_number = 1
	# Keep settings intact — only reset progression
	save_data()

func record_run(score_data: Dictionary, path: String) -> void:
	total_runs += 1
	var key := path if path != "" else "default"
	var current_best: Dictionary = best_scores.get(key, {})
	if score_data.get("score", 0) > current_best.get("score", 0):
		best_scores[key] = {"score": score_data.score, "rating": score_data.rating}
	save_data()

# =============================================================================
# ELO System
# =============================================================================

const ELO_WIN_PER_FIGHT := 75
const ELO_LOSS_PENALTY_PER_FIGHT := 0

## Apply ELO change from a fight and record it in history.
func apply_fight_elo(opponent_elo: int, won: bool) -> int:
	var elo_before := player_elo
	var delta := ELO_WIN_PER_FIGHT if won else -ELO_LOSS_PENALTY_PER_FIGHT
	player_elo = maxi(0, player_elo + delta)
	elo_history.append({
		"tournament": tournament_number,
		"elo_before": elo_before,
		"elo_after": player_elo,
		"opponent_elo": opponent_elo,
		"won": won,
		"delta": delta,
	})
	save_data()
	return delta

## Advance to the next tournament.
func advance_tournament() -> void:
	tournament_number += 1
	save_data()

## Apply persisted settings to audio buses, CRT overlay, and display mode.
## Called deferred from _ready so all autoloads are initialized first.
func _apply_settings() -> void:
	# Audio buses
	var master_vol: float = settings.get("master_volume", 80)
	var music_vol: float = settings.get("music_volume", 80)
	var sfx_vol: float = settings.get("sfx_volume", 80)

	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Master"), _percent_to_db(master_vol))
	var music_idx := AudioServer.get_bus_index("Music")
	if music_idx >= 0:
		AudioServer.set_bus_volume_db(music_idx, _percent_to_db(music_vol))
	var sfx_idx := AudioServer.get_bus_index("SFX")
	if sfx_idx >= 0:
		AudioServer.set_bus_volume_db(sfx_idx, _percent_to_db(sfx_vol))

	# CRT overlay
	if is_instance_valid(CRTOverlay):
		CRTOverlay.set_enabled(settings.get("crt_enabled", true))
		CRTOverlay.set_intensity(float(settings.get("crt_intensity", 100)) / 100.0)

	# Fullscreen
	if settings.get("fullscreen", false):
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)

static func _percent_to_db(percent: float) -> float:
	if percent <= 0:
		return -80.0
	return linear_to_db(percent / 100.0)
