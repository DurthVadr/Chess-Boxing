class_name ScoringSystem
extends RefCounted

## Calculates run score and letter rating (F to S+).

const RATING_THRESHOLDS := {
	"S+": 7000,
	"S": 5500,
	"A": 4000,
	"B": 3000,
	"C": 2000,
	"D": 1000,
	"F": 0,
}

const RATING_COLORS := {
	"S+": Color(0.95, 0.85, 0.2),
	"S": Color(0.9, 0.75, 0.3),
	"A": Color(0.3, 0.8, 0.4),
	"B": Color(0.4, 0.6, 0.85),
	"C": Color(0.6, 0.6, 0.65),
	"D": Color(0.65, 0.45, 0.3),
	"F": Color(0.7, 0.3, 0.3),
}

## Calculate final run score and rating.
## Returns {score, rating, rating_color, breakdown}
static func calculate_score(stats: Dictionary, perks: Array, total_opponents: int) -> Dictionary:
	var breakdown := {}

	# Combat score: opponents defeated × 1000
	var fights_won: int = stats.get("fights_won", 0)
	breakdown["combat"] = fights_won * 1000

	# Win bonus
	var won := fights_won >= total_opponents
	breakdown["win_bonus"] = 500 if won else 0

	# Chess score: puzzles solved × 300, minus failed × 100
	var puzzles_solved: int = stats.get("puzzles_solved", 0)
	var puzzles_failed: int = stats.get("puzzles_failed", 0)
	breakdown["chess"] = puzzles_solved * 300 - puzzles_failed * 100

	# Speed bonus: fast puzzle solves
	var fastest: float = stats.get("fastest_puzzle_time", 999.0)
	if fastest < 10.0:
		breakdown["speed"] = 500
	elif fastest < 20.0:
		breakdown["speed"] = 250
	else:
		breakdown["speed"] = 0

	# Heat bonus: average heat across all rounds
	var heat_history: Array = stats.get("heat_history", [])
	var avg_heat := 1.0
	if not heat_history.is_empty():
		var total := 0.0
		for h in heat_history:
			total += h
		avg_heat = total / heat_history.size()
	breakdown["heat"] = int(avg_heat * 400)

	# Efficiency: damage ratio
	var dealt: int = stats.get("total_damage_dealt", 0)
	var taken: int = stats.get("total_damage_taken", 1)
	var ratio := float(dealt) / maxf(float(taken), 1.0)
	if ratio > 3.0:
		breakdown["efficiency"] = 400
	elif ratio > 2.0:
		breakdown["efficiency"] = 250
	elif ratio > 1.0:
		breakdown["efficiency"] = 100
	else:
		breakdown["efficiency"] = 0

	# Synergy bonus: perks collected and set bonuses
	breakdown["synergy"] = mini(perks.size() * 50, 400)

	# Total
	var total_score := 0
	for key in breakdown:
		total_score += breakdown[key]

	var rating := _get_rating(total_score)

	return {
		"score": total_score,
		"rating": rating,
		"rating_color": RATING_COLORS.get(rating, Color.WHITE),
		"breakdown": breakdown,
	}

static func _get_rating(score: int) -> String:
	for rating in ["S+", "S", "A", "B", "C", "D", "F"]:
		if score >= RATING_THRESHOLDS[rating]:
			return rating
	return "F"
