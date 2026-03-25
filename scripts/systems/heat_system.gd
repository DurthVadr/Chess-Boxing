class_name HeatSystem
extends RefCounted

## Heat is a 1.0–5.0 multiplier that scales perk effects during boxing.
## Calculated from chess puzzle performance: speed, accuracy, and difficulty.
## Partially retained between rounds within a fight.

const HEAT_MIN := 1.0
const HEAT_MAX := 5.0
const HEAT_FAIL := 0.5
const RETENTION_FACTOR := 0.3

## Calculate heat from chess puzzle performance.
## Returns a float in range [HEAT_FAIL, HEAT_MAX].
static func calculate_heat(
	time_remaining: float,
	time_limit: float,
	mistakes: int,
	difficulty: int,
	retained_heat: float,
	base_heat_bonus: float
) -> float:
	var base := 1.0

	# Time component: 0.0 – 2.0 bonus (faster solve = more heat)
	var time_ratio := clampf(time_remaining / maxf(time_limit, 1.0), 0.0, 1.0)
	var time_heat := time_ratio * 2.0

	# Accuracy component: 0.0 – 1.5 bonus
	var accuracy_heat := 0.0
	if mistakes == 0:
		accuracy_heat = 1.5
	elif mistakes == 1:
		accuracy_heat = 0.75
	elif mistakes == 2:
		accuracy_heat = 0.25
	# 3+ mistakes = 0.0

	# Difficulty component: 0.0 – 0.5 bonus (difficulty 1–5)
	var difficulty_heat := clampf(float(difficulty) * 0.1, 0.0, 0.5)

	var heat := base + time_heat + accuracy_heat + difficulty_heat + retained_heat + base_heat_bonus
	return clampf(heat, HEAT_MIN, HEAT_MAX)

## Calculate heat for a failed puzzle (timeout or too many mistakes).
## Returns HEAT_FAIL (0.5) as a penalty — intentionally below HEAT_MIN.
static func calculate_fail_heat(retained_heat: float) -> float:
	return clampf(maxf(HEAT_FAIL, retained_heat * 0.5), HEAT_FAIL, HEAT_MAX)

## Multiply a perk's base value by heat.
static func get_perk_multiplier(heat: float, base_value: float) -> float:
	return base_value * heat

## Get the retained heat to carry into the next round.
static func get_retained_heat(current_heat: float) -> float:
	return current_heat * RETENTION_FACTOR

## Get a descriptive tier name for the current heat level.
static func get_heat_tier(heat: float) -> String:
	if heat >= 4.0:
		return "blazing"
	elif heat >= 3.0:
		return "hot"
	elif heat >= 2.0:
		return "warm"
	elif heat >= 1.0:
		return "cold"
	else:
		return "frozen"

## Get display text for heat level.
static func get_heat_text(heat: float) -> String:
	var tier := get_heat_tier(heat)
	match tier:
		"blazing": return "BLAZING! Heat x%.1f" % heat
		"hot": return "Hot! Heat x%.1f" % heat
		"warm": return "Warm. Heat x%.1f" % heat
		"cold": return "Cold. Heat x%.1f" % heat
		"frozen": return "Frozen... Heat x%.1f" % heat
	return "Heat x%.1f" % heat

## Get the color for the heat bar UI.
static func get_heat_color(heat: float) -> Color:
	if heat >= 4.0:
		return Color(0.95, 0.3, 0.15)   # Blazing red-orange
	elif heat >= 3.0:
		return Color(0.9, 0.55, 0.15)   # Hot orange
	elif heat >= 2.0:
		return Color(0.85, 0.75, 0.25)  # Warm gold
	elif heat >= 1.0:
		return Color(0.4, 0.6, 0.85)    # Cold blue
	else:
		return Color(0.3, 0.4, 0.65)    # Frozen deep blue
