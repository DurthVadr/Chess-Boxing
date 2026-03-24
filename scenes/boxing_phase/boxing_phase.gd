extends Control

## Boxing Phase — Turn-based combat with stamina management

@onready var player_hp_bar: ProgressBar = %PlayerHPBar
@onready var player_hp_label: Label = %PlayerHPLabel
@onready var player_stamina_bar: ProgressBar = %PlayerStaminaBar
@onready var player_name_label: Label = %PlayerNameLabel
@onready var opponent_hp_bar: ProgressBar = %OpponentHPBar
@onready var opponent_hp_label: Label = %OpponentHPLabel
@onready var opponent_stamina_bar: ProgressBar = %OpponentStaminaBar
@onready var opponent_name_label: Label = %OpponentNameLabel
@onready var telegraph_label: Label = %TelegraphLabel
@onready var combat_log: RichTextLabel = %CombatLog
@onready var action_container: GridContainer = %ActionContainer
@onready var bonus_label: Label = %BonusLabel
@onready var player_sprite: ColorRect = %PlayerSprite
@onready var opponent_sprite: ColorRect = %OpponentSprite

var combat_mgr: CombatManager
var opponent_ai: OpponentAI
var is_player_turn: bool = true
var round_over: bool = false
var turn_count: int = 0
var opponent_next_action: BoxingAction.ActionType
var second_wind_used: bool = false

const ACTION_COLORS := {
	"Jab": Color(0.3, 0.6, 0.3),
	"Cross": Color(0.5, 0.5, 0.2),
	"Hook": Color(0.7, 0.4, 0.2),
	"Uppercut": Color(0.8, 0.2, 0.2),
	"Block": Color(0.3, 0.3, 0.6),
	"Dodge": Color(0.2, 0.5, 0.6),
	"Clinch": Color(0.4, 0.4, 0.4),
}

func _ready() -> void:
	combat_mgr = CombatManager.new()
	opponent_ai = OpponentAI.new()
	opponent_ai.setup(GameManager.current_opponent.get("archetype", "brawler"))

	_update_ui()
	_build_action_buttons()
	_show_chess_bonus()
	_prepare_opponent_action()

	Juice.fade_in(self, 0.3)

func _show_chess_bonus() -> void:
	var bonus := GameManager.chess_bonus
	if bonus > 0.0:
		bonus_label.text = "Chess Bonus: +%d DMG, +%d DEF" % [
			ChessBonus.get_bonus_damage(bonus),
			ChessBonus.get_bonus_defense(bonus)
		]
		bonus_label.add_theme_color_override("font_color", Color(0.3, 0.7, 0.9))
	else:
		bonus_label.text = "No Chess Bonus — Opponent is powered up!"
		bonus_label.add_theme_color_override("font_color", Color(0.8, 0.3, 0.3))

func _build_action_buttons() -> void:
	for child in action_container.get_children():
		child.queue_free()

	var all_actions := BoxingAction.create_all()
	for action_type in all_actions:
		var action: BoxingAction = all_actions[action_type]
		var btn := Button.new()
		btn.custom_minimum_size = Vector2(140, 50)
		btn.text = action.name

		var style := StyleBoxFlat.new()
		style.bg_color = ACTION_COLORS.get(action.name, Color(0.3, 0.3, 0.3))
		style.corner_radius_top_left = 8
		style.corner_radius_top_right = 8
		style.corner_radius_bottom_left = 8
		style.corner_radius_bottom_right = 8
		btn.add_theme_stylebox_override("normal", style)

		var hover := style.duplicate()
		hover.bg_color = style.bg_color.lightened(0.2)
		btn.add_theme_stylebox_override("hover", hover)

		btn.add_theme_font_size_override("font_size", 16)
		btn.tooltip_text = action.description + "\nDMG: %d | Cost: %d" % [action.damage, action.stamina_cost]

		btn.pressed.connect(_on_action_selected.bind(action_type))
		action_container.add_child(btn)

func _prepare_opponent_action() -> void:
	var opp_hp_pct := float(GameManager.opponent_hp) / float(GameManager.opponent_max_hp)
	var player_hp_pct := float(GameManager.player_hp) / float(GameManager.player_max_hp)
	opponent_next_action = opponent_ai.choose_action(opp_hp_pct, GameManager.opponent_stamina, player_hp_pct)

	# Telegraph hint
	telegraph_label.text = opponent_ai.get_telegraph_hint(opponent_next_action)

	# Perk: Hustler sees exact move
	if GameManager.has_perk("see_first_move") and turn_count == 0:
		var actions := BoxingAction.create_all()
		telegraph_label.text = "HUSTLER SENSE: " + actions[opponent_next_action].name + "!"
		telegraph_label.add_theme_color_override("font_color", Color(0.9, 0.78, 0.3))

func _on_action_selected(action_type: BoxingAction.ActionType) -> void:
	if not is_player_turn or round_over:
		return
	is_player_turn = false
	turn_count += 1

	# Record for AI adaptation
	opponent_ai.record_player_action(action_type)

	# Resolve combat
	var player_stats := {"damage_mod": 1.0}
	var opponent_stats := {
		"damage_mod": GameManager.current_opponent.get("damage_mod", 1.0),
		"defense_mod": GameManager.current_opponent.get("defense_mod", 1.0),
	}

	var result := combat_mgr.resolve_turn(
		action_type,
		opponent_next_action,
		player_stats,
		opponent_stats,
		GameManager.chess_bonus
	)

	# Apply results
	GameManager.opponent_hp = maxi(0, GameManager.opponent_hp - result.player_damage_dealt)
	GameManager.player_hp = maxi(0, GameManager.player_hp - result.player_damage_taken)

	# Stamina changes
	GameManager.player_stamina = clampi(
		GameManager.player_stamina + result.player_stamina_change,
		0, GameManager.player_max_stamina
	)
	GameManager.opponent_stamina = clampi(
		GameManager.opponent_stamina + result.opponent_stamina_change,
		0, GameManager.opponent_max_stamina
	)

	# Perk: Block grants chess time
	if action_type == BoxingAction.ActionType.BLOCK and GameManager.has_perk("block_chess_time"):
		var bonus_time := GameManager.get_perk_value("block_chess_time", 5.0)
		# Store accumulated bonus for next chess round
		for perk in GameManager.active_perks:
			if perk.effect == "block_chess_time":
				perk["accumulated"] = perk.get("accumulated", 0.0) + bonus_time

	# Second Wind perk
	if not second_wind_used and GameManager.has_perk("second_wind"):
		var hp_pct := float(GameManager.player_hp) / float(GameManager.player_max_hp)
		if hp_pct <= 0.1 and GameManager.player_hp > 0:
			var heal := int(GameManager.player_max_hp * GameManager.get_perk_value("second_wind", 0.3))
			GameManager.player_hp = mini(GameManager.player_hp + heal, GameManager.player_max_hp)
			second_wind_used = true
			result.messages.append("SECOND WIND! Recovered %d HP!" % heal)

	# Animate results
	_animate_turn_result(result)

	# Log messages
	for msg in result.messages:
		_add_to_log(msg)

	_update_ui()

	# Check end conditions
	if GameManager.opponent_hp <= 0:
		_on_ko("player")
		return
	if GameManager.player_hp <= 0:
		_on_ko("opponent")
		return

	# After N turns, end boxing round and go back to chess
	if turn_count >= 8:
		_end_boxing_round()
		return

	# Next turn
	await get_tree().create_timer(0.8).timeout
	_prepare_opponent_action()
	is_player_turn = true

func _animate_turn_result(result: Dictionary) -> void:
	if result.player_damage_dealt > 0:
		Juice.screen_shake(opponent_sprite, 8.0, 0.15)
		Juice.flash(opponent_sprite, Color(1, 0.3, 0.3), 0.2)
	if result.player_damage_taken > 0:
		Juice.screen_shake(player_sprite, 6.0, 0.15)
		Juice.flash(player_sprite, Color(1, 0.3, 0.3), 0.2)
	if result.player_dodged:
		Juice.flash(player_sprite, Color(0.3, 0.8, 1), 0.2)
	if result.opponent_dodged:
		Juice.flash(opponent_sprite, Color(0.3, 0.8, 1), 0.2)

func _update_ui() -> void:
	# Player bars
	player_hp_bar.max_value = GameManager.player_max_hp
	player_hp_bar.value = GameManager.player_hp
	player_hp_label.text = "HP: %d/%d" % [GameManager.player_hp, GameManager.player_max_hp]
	player_stamina_bar.max_value = GameManager.player_max_stamina
	player_stamina_bar.value = GameManager.player_stamina
	player_name_label.text = GameManager.player_fighter.get("name", "Player")

	# Opponent bars
	opponent_hp_bar.max_value = GameManager.opponent_max_hp
	opponent_hp_bar.value = GameManager.opponent_hp
	opponent_hp_label.text = "HP: %d/%d" % [GameManager.opponent_hp, GameManager.opponent_max_hp]
	opponent_stamina_bar.max_value = GameManager.opponent_max_stamina
	opponent_stamina_bar.value = GameManager.opponent_stamina
	opponent_name_label.text = GameManager.current_opponent.get("name", "Opponent")

	# Disable actions if not enough stamina
	var all_actions := BoxingAction.create_all()
	var i := 0
	for action_type in all_actions:
		if i < action_container.get_child_count():
			var btn: Button = action_container.get_child(i)
			var action: BoxingAction = all_actions[action_type]
			btn.disabled = action.stamina_cost > GameManager.player_stamina and action.stamina_cost > 0
		i += 1

func _add_to_log(text: String) -> void:
	combat_log.append_text(text + "\n")
	# Auto-scroll to bottom
	combat_log.scroll_to_line(combat_log.get_line_count())

func _on_ko(winner: String) -> void:
	round_over = true
	is_player_turn = false

	if winner == "player":
		_add_to_log("[color=green]KO! You win the fight![/color]")
		Juice.screen_shake(self, 15.0, 0.4)
	else:
		_add_to_log("[color=red]KO! You've been knocked out![/color]")
		Juice.screen_shake(self, 15.0, 0.4)

	# Disable all buttons
	for btn in action_container.get_children():
		(btn as Button).disabled = true

	await get_tree().create_timer(2.0).timeout

	if winner == "player":
		GameManager.opponent_hp = 0
	else:
		GameManager.player_hp = 0
	GameManager.advance_fight_round()

func _end_boxing_round() -> void:
	round_over = true
	is_player_turn = false
	_add_to_log("Round over! Back to the chess board...")

	await get_tree().create_timer(1.5).timeout
	GameManager.advance_fight_round()
