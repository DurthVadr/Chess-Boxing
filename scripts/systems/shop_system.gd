class_name ShopSystem
extends RefCounted

## Manages the dual-shop system: The Study (chess) and The Gym (boxing).
## Uses shared currency (Rep) to create tension between chess and boxing investment.

const SHOP_DISPLAY_COUNT := 4  # Items shown per shop each visit

# =============================================================================
# Rep (Currency) Calculation
# =============================================================================

## Calculate Rep earned from a completed fight.
## Called after each fight win, before the shop opens.
static func calculate_rep_earned(
	puzzle_solved: bool,
	puzzle_mistakes: int,
	solve_time: float,
	time_limit: float,
	heat: float,
	opponent_hp: int,
	_opponent_max_hp: int,
	player_hp: int,
	player_max_hp: int
) -> Dictionary:
	var breakdown := {
		"base": 3,
		"perfect_puzzle": 0,
		"fast_solve": 0,
		"high_heat": 0,
		"knockout": 0,
		"low_damage": 0,
		"total": 3,
	}

	# Perfect puzzle: 0 mistakes
	if puzzle_solved and puzzle_mistakes == 0:
		breakdown.perfect_puzzle = 2

	# Fast solve: more than 75% time remaining
	if puzzle_solved and time_limit > 0:
		var time_ratio := solve_time / time_limit
		if time_ratio < 0.25:  # Solved using less than 25% of time
			breakdown.fast_solve = 1

	# High heat (3.0+)
	if heat >= 3.0:
		breakdown.high_heat = 1

	# KO (opponent HP reached 0)
	if opponent_hp <= 0:
		breakdown.knockout = 1

	# Low damage taken (lost less than 20% of max HP during fight)
	var hp_lost_pct := 1.0 - (float(player_hp) / float(maxi(player_max_hp, 1)))
	if hp_lost_pct < 0.2:
		breakdown.low_damage = 1

	breakdown.total = (
		breakdown.base
		+ breakdown.perfect_puzzle
		+ breakdown.fast_solve
		+ breakdown.high_heat
		+ breakdown.knockout
		+ breakdown.low_damage
	)

	return breakdown

# =============================================================================
# Shop Inventory Generation
# =============================================================================

## Build the shop inventory for one visit.
## Returns {"study": [...items], "gym": [...items]}.
static func generate_shop_inventory(
	study_pool: Array,
	gym_pool: Array,
	player_hand: Array,
	purchase_counts: Dictionary
) -> Dictionary:
	var study_items := _filter_and_pick(study_pool, player_hand, purchase_counts, SHOP_DISPLAY_COUNT)
	var gym_items := _filter_and_pick(gym_pool, player_hand, purchase_counts, SHOP_DISPLAY_COUNT)
	return {"study": study_items, "gym": gym_items}

## Filter out items the player can't buy (maxed out) and pick a random selection.
static func _filter_and_pick(
	pool: Array,
	player_hand: Array,
	purchase_counts: Dictionary,
	count: int
) -> Array:
	var available: Array = []

	for item in pool:
		var item_id: String = item.get("id", "")
		var category: String = item.get("category", "")

		# Check tactic card hand limit and per-card ownership cap
		if category == "tactic_card":
			var max_owned: int = item.get("max_owned", 2)
			var currently_owned := TacticCardSystem.count_card(player_hand, item_id)
			if currently_owned >= max_owned:
				continue
			if not TacticCardSystem.can_add_card(player_hand):
				continue

		# Check stat upgrade purchase cap
		if category == "stat_upgrade":
			var max_purchases: int = item.get("max_purchases", 99)
			var times_bought: int = purchase_counts.get(item_id, 0)
			if times_bought >= max_purchases:
				continue

		# Services and intel are always available (consumed on use)
		available.append(item)

	available.shuffle()

	# Ensure category variety: try to include at least 1 card and 1 non-card
	var cards := available.filter(func(i): return i.get("category", "") == "tactic_card")
	var non_cards := available.filter(func(i): return i.get("category", "") != "tactic_card")

	var result: Array = []

	# Pick 1-2 cards if available
	var card_count := mini(randi_range(1, 2), cards.size())
	for i in card_count:
		result.append(cards[i])

	# Fill remaining with non-cards, then overflow back to cards
	var remaining := count - result.size()
	for i in mini(remaining, non_cards.size()):
		result.append(non_cards[i])

	remaining = count - result.size()
	for i in range(card_count, mini(card_count + remaining, cards.size())):
		result.append(cards[i])

	return result.slice(0, mini(count, result.size()))

# =============================================================================
# Purchase Validation
# =============================================================================

## Check if the player can afford and is allowed to buy an item.
static func can_purchase(
	item: Dictionary,
	player_rep: int,
	player_hand: Array,
	purchase_counts: Dictionary
) -> Dictionary:
	var result := {"allowed": true, "reason": ""}
	var cost: int = item.get("cost", 999)
	var category: String = item.get("category", "")
	var item_id: String = item.get("id", "")

	# Check currency
	if player_rep < cost:
		result.allowed = false
		result.reason = "Not enough Rep (%d/%d)" % [player_rep, cost]
		return result

	# Check tactic card limits
	if category == "tactic_card":
		if not TacticCardSystem.can_add_card(player_hand):
			result.allowed = false
			result.reason = "Hand full (%d/%d cards)" % [player_hand.size(), TacticCardSystem.MAX_HAND_SIZE]
			return result
		var max_owned: int = item.get("max_owned", 2)
		if TacticCardSystem.count_card(player_hand, item_id) >= max_owned:
			result.allowed = false
			result.reason = "Already own max copies"
			return result

	# Check stat upgrade caps
	if category == "stat_upgrade":
		var max_purchases: int = item.get("max_purchases", 99)
		if purchase_counts.get(item_id, 0) >= max_purchases:
			result.allowed = false
			result.reason = "Maxed out"
			return result

	return result

# =============================================================================
# Purchase Execution
# =============================================================================

## Execute a purchase. Returns true if successful.
## Caller is responsible for deducting Rep and applying effects.
static func get_purchase_effects(item: Dictionary) -> Dictionary:
	return {
		"id": item.get("id", ""),
		"effect": item.get("effect", ""),
		"category": item.get("category", ""),
		"values": item.get("values", {}),
		"cost": item.get("cost", 0),
	}
