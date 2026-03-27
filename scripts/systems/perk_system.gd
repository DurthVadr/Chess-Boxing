class_name PerkSystem
extends RefCounted

## Manages perk tags, set bonuses, and perk queries.
## Perks use the new schema: {id, name, description, type, tags[], rarity, effect, values{}, heat_scaled, flavor}

const TAGS := ["speed", "power", "timing", "defensive", "tempo", "sacrifice", "chess", "boxing"]

const TAG_COLORS := {
	"speed": Color(0.3, 0.75, 0.9),     # Electric blue
	"power": Color(0.85, 0.25, 0.25),    # Crimson
	"timing": Color(0.9, 0.78, 0.3),     # Gold
	"defensive": Color(0.3, 0.75, 0.4),  # Emerald
	"tempo": Color(0.6, 0.35, 0.75),     # Purple
	"sacrifice": Color(0.85, 0.45, 0.15),# Blood orange
	"chess": Color(0.88, 0.85, 0.78),    # Ivory
	"boxing": Color(0.55, 0.55, 0.6),    # Steel gray
}

const TAG_ICONS := {
	"speed": ">>",
	"power": "!!",
	"timing": "())",
	"defensive": "[]",
	"tempo": "~~",
	"sacrifice": "**",
	"chess": "K",
	"boxing": "x",
}

## Count how many perks have each tag.
static func count_tags(active_perks: Array) -> Dictionary:
	var counts := {}
	for tag in TAGS:
		counts[tag] = 0
	for perk in active_perks:
		var tags: Array = perk.get("tags", [])
		for tag in tags:
			if tag in counts:
				counts[tag] += 1
	return counts

## Get active set bonuses based on tag counts.
## Returns array of {tag, tier, name, effect, description, values}
static func get_active_set_bonuses(tag_counts: Dictionary, all_set_bonuses: Array) -> Array:
	var active := []
	for bonus in all_set_bonuses:
		var tag: String = bonus.get("tag", "")
		var threshold: int = bonus.get("threshold", 99)
		var count: int = tag_counts.get(tag, 0)
		if count >= threshold:
			active.append(bonus)
	return active

## Check if adding a perk would trigger a NEW set bonus.
## Returns the bonus dict if so, or {} if not.
static func would_trigger_set_bonus(perk: Dictionary, current_perks: Array, all_set_bonuses: Array) -> Array:
	var current_counts := count_tags(current_perks)
	var current_bonuses := get_active_set_bonuses(current_counts, all_set_bonuses)
	var current_bonus_ids := []
	for b in current_bonuses:
		current_bonus_ids.append(b.get("id", ""))

	# Simulate adding this perk
	var simulated := current_perks.duplicate()
	simulated.append(perk)
	var new_counts := count_tags(simulated)
	var new_bonuses := get_active_set_bonuses(new_counts, all_set_bonuses)

	var triggered := []
	for b in new_bonuses:
		if b.get("id", "") not in current_bonus_ids:
			triggered.append(b)
	return triggered

## Get the first value from a perk's values dict.
## Handles both old schema (perk.value) and new schema (perk.values).
static func get_first_value(perk: Dictionary) -> float:
	# New schema: values is a Dictionary
	var values = perk.get("values", {})
	if values is Dictionary and not values.is_empty():
		# Return the first value
		for key in values:
			var first_val = values[key]
			if first_val is float or first_val is int:
				return float(first_val)
		return 0.0
	# Old schema fallback: single value field
	var single_val = perk.get("value", 0.0)
	if single_val is float or single_val is int:
		return float(single_val)
	return 0.0

## Get a specific named value from a perk's values dict.
static func get_named_value(perk: Dictionary, value_name: String, default_val: float = 0.0) -> float:
	var values = perk.get("values", {})
	if values is Dictionary:
		var named_val = values.get(value_name, default_val)
		if named_val is float or named_val is int:
			return float(named_val)
	return default_val

## Check if a perk's effects scale with heat.
static func is_heat_scaled(perk: Dictionary) -> bool:
	return perk.get("heat_scaled", false)
