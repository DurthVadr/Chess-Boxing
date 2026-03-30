class_name TacticCardSystem
extends RefCounted

## Manages the player's hand of Tactic Cards — consumable chess-themed
## abilities played during boxing rounds.
##
## Hand limit: 3 cards max. Cards are one-use (consumed on play).
## Cards are bought from The Study / The Gym shops.

const MAX_HAND_SIZE := 3

## Check if the player can add a card to their hand.
static func can_add_card(hand: Array) -> bool:
	return hand.size() < MAX_HAND_SIZE

## Add a card to the hand. Returns true if added, false if hand is full.
static func add_card(hand: Array, card: Dictionary) -> bool:
	if hand.size() >= MAX_HAND_SIZE:
		return false
	hand.append(card.duplicate())
	return true

## Remove and return a card from the hand by index.
static func play_card(hand: Array, index: int) -> Dictionary:
	if index < 0 or index >= hand.size():
		return {}
	var card: Dictionary = hand[index]
	hand.remove_at(index)
	return card

## Count how many of a specific card the player holds.
static func count_card(hand: Array, card_id: String) -> int:
	var count := 0
	for card in hand:
		if card.get("id", "") == card_id:
			count += 1
	return count

## Check if a tactic card effect is active for the current turn.
## active_tactics is an Array of played card Dictionaries for this turn.
static func has_active_tactic(active_tactics: Array, effect_id: String) -> bool:
	for card in active_tactics:
		if card.get("effect", "") == effect_id:
			return true
	return false

## Get the values dict from an active tactic.
static func get_tactic_values(active_tactics: Array, effect_id: String) -> Dictionary:
	for card in active_tactics:
		if card.get("effect", "") == effect_id:
			return card.get("values", {})
	return {}

# =============================================================================
# Card Effect Descriptions (for combat resolution)
# =============================================================================

## Apply pre-resolution effects (before actions resolve).
## Returns a Dictionary of modifications to apply:
## {
##   "opponent_blind": bool,         # Fork: opponent has no telegraph
##   "force_opponent_action": {},     # Pin: {slot: int, action: String}
##   "player_guaranteed_hit": bool,   # Sacrifice: both actions auto-hit
##   "player_acts_first": bool,       # Tempo: action 1 resolves before opp action 2
##   "free_interrupt_action": String, # Zwischenzug: insert action between opp actions
##   "block_deals_damage": float,     # Discovery: block does X% of other action damage
##   "dodge_auto_fail": bool,         # En Passant: opponent dodge fails
##   "en_passant_multiplier": float,  # En Passant: damage multiplier on failed dodge
##   "back_rank_threshold": float,    # Back Rank: HP% threshold for ignoring defenses
##   "endgame_damage_bonus": int,     # Endgame: permanent +damage for rest of fight
##   "sacrifice_hp_cost": int,        # Sacrifice: HP cost to activate
## }
static func resolve_tactics(active_tactics: Array, opponent_hp_pct: float) -> Dictionary:
	var mods := {
		"opponent_blind": false,
		"force_opponent_action": {},
		"player_guaranteed_hit": false,
		"player_acts_first": false,
		"free_interrupt_action": "",
		"block_deals_damage": 0.0,
		"dodge_auto_fail": false,
		"en_passant_multiplier": 1.0,
		"back_rank_active": false,
		"endgame_damage_bonus": 0,
		"sacrifice_hp_cost": 0,
	}

	for card in active_tactics:
		var effect: String = card.get("effect", "")
		var values: Dictionary = card.get("values", {})

		match effect:
			"fork":
				mods.opponent_blind = true

			"pin":
				mods.force_opponent_action = {
					"slot": int(values.get("slot", 1)),
					"action": values.get("forced_action", "JAB"),
				}

			"en_passant":
				mods.dodge_auto_fail = true
				mods.en_passant_multiplier = values.get("damage_multiplier", 1.5)

			"discovery":
				mods.block_deals_damage = values.get("damage_ratio", 0.5)

			"zwischenzug":
				mods.free_interrupt_action = values.get("free_action", "JAB")

			"sacrifice":
				mods.player_guaranteed_hit = true
				mods.sacrifice_hp_cost = int(values.get("hp_cost", 8))

			"back_rank":
				var threshold: float = values.get("hp_threshold", 0.3)
				if opponent_hp_pct <= threshold:
					mods.back_rank_active = true

			"tempo":
				mods.player_acts_first = true

			"endgame":
				mods.endgame_damage_bonus += int(values.get("damage_bonus", 3))

	return mods

## Get a short description of what a card does in combat (for UI tooltips).
static func get_card_combat_text(card: Dictionary) -> String:
	var effect: String = card.get("effect", "")
	match effect:
		"fork": return "Opponent acts blind this turn"
		"pin": return "Force opponent to JAB (slot 2)"
		"en_passant": return "Weak hit guaranteed, 1.5x damage"
		"discovery": return "Your defense also deals damage"
		"zwischenzug": return "Free JAB between opponent actions"
		"sacrifice": return "Lose 8 HP, both actions guaranteed hit"
		"back_rank": return "If opp <30% HP: UPPERCUT ignores all defense"
		"tempo": return "You act first this turn"
		"endgame": return "+3 damage all attacks (rest of fight)"
	return card.get("description", "")
