extends Control

## Boxing Phase — 2-action combo combat with heat-scaled perks

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
@onready var combo_label: Label = %ComboLabel
@onready var action_phase_label: Label = %ActionPhaseLabel

var combat_mgr: CombatManager
var opponent_ai: OpponentAI
var is_player_turn: bool = true
var round_over: bool = false
var turn_count: int = 0
var second_wind_used: bool = false

# 2-action selection state
var action_selection_phase: int = 0  # 0 = picking action 1, 1 = picking action 2
var selected_action_1: BoxingAction.ActionType = BoxingAction.ActionType.JAB
var opponent_next_actions: Array = []  # [action1, action2]

const ACTION_COLORS := {
	"Jab": Color(0.35, 0.55, 0.38),
	"Cross": Color(0.55, 0.5, 0.3),
	"Hook": Color(0.65, 0.42, 0.28),
	"Uppercut": Color(0.72, 0.32, 0.28),
	"Block": Color(0.35, 0.42, 0.6),
	"Dodge": Color(0.3, 0.52, 0.58),
	"Clinch": Color(0.45, 0.45, 0.42),
}

func _ready() -> void:
	combat_mgr = CombatManager.new()
	opponent_ai = OpponentAI.new()
	opponent_ai.setup(GameManager.current_opponent.get("archetype", "brawler"))
	opponent_ai.setup_telegraphs(GameManager.current_opponent.get("id", ""))

	combo_label.text = ""
	action_phase_label.text = "SELECT ACTION 1"

	_update_ui()
	_build_action_buttons()
	_show_heat()
	_prepare_opponent_actions()

	Juice.fade_in(self, 0.3)

func _show_heat() -> void:
	var current_heat := GameManager.get_heat()
	bonus_label.text = HeatSystem.get_heat_text(current_heat)
	bonus_label.add_theme_color_override("font_color", HeatSystem.get_heat_color(current_heat))

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

func _prepare_opponent_actions() -> void:
	var opp_hp_pct := float(GameManager.opponent_hp) / float(GameManager.opponent_max_hp)
	var player_hp_pct := float(GameManager.player_hp) / float(GameManager.player_max_hp)
	opponent_next_actions = opponent_ai.choose_actions(opp_hp_pct, GameManager.opponent_stamina, player_hp_pct)

	# Telegraph — shows hint for first action
	telegraph_label.text = opponent_ai.get_telegraph_for_actions(opponent_next_actions)
	telegraph_label.add_theme_color_override("font_color", Color(0.9, 0.6, 0.15))

	# Perk: Hustler sees exact first move
	if GameManager.has_perk("see_first_move") and turn_count == 0:
		var all_actions := BoxingAction.create_all()
		var first_action: BoxingAction = all_actions[opponent_next_actions[0]]
		telegraph_label.text = "HUSTLER SENSE: %s!" % first_action.name
		telegraph_label.add_theme_color_override("font_color", Color(0.9, 0.78, 0.3))

func _on_action_selected(action_type: BoxingAction.ActionType) -> void:
	if not is_player_turn or round_over:
		return

	# All In perk: can't block or dodge
	if GameManager.has_perk("all_in"):
		if action_type == BoxingAction.ActionType.BLOCK or action_type == BoxingAction.ActionType.DODGE:
			_add_to_log("[color=red]All In: You can't block or dodge![/color]")
			return

	if action_selection_phase == 0:
		# First action selected
		selected_action_1 = action_type
		action_selection_phase = 1
		action_phase_label.text = "SELECT ACTION 2"

		var all_actions := BoxingAction.create_all()
		var act1_name: String = (all_actions[action_type] as BoxingAction).name
		action_phase_label.text = "Action 1: %s — SELECT ACTION 2" % act1_name

		# Highlight selected button
		_highlight_action_button(action_type)
		return

	# Second action selected — resolve the turn
	action_selection_phase = 0
	is_player_turn = false
	turn_count += 1

	var player_actions: Array = [selected_action_1, action_type]
	opponent_ai.record_player_actions(player_actions)

	# Check for named combo and show it
	var combo_name := ComboSystem.get_combo_name(selected_action_1, action_type)
	if combo_name != "":
		combo_label.text = combo_name
		combo_label.add_theme_color_override("font_color", Color(0.9, 0.78, 0.3))
		Juice.punch_text(combo_label)

	# Resolve combat
	var player_stats := {"damage_mod": 1.0}
	var opponent_stats := {
		"damage_mod": GameManager.current_opponent.get("damage_mod", 1.0),
		"defense_mod": GameManager.current_opponent.get("defense_mod", 1.0),
	}

	var result := combat_mgr.resolve_turn_v2(
		player_actions,
		opponent_next_actions,
		player_stats,
		opponent_stats,
		GameManager.get_heat()
	)

	# Apply opponent gimmick effects
	var gimmick = GameManager.current_opponent.get("gimmick", null)
	if gimmick is Dictionary and not gimmick.is_empty():
		var gimmick_msgs := GimmickSystem.apply_post_turn(
			gimmick, result,
			GameManager.current_round_in_fight,
			GameManager.opponent_hp,
			GameManager.opponent_max_hp
		)
		result.messages.append_array(gimmick_msgs)

	# Apply HP changes
	GameManager.opponent_hp = maxi(0, GameManager.opponent_hp - result.player_damage_dealt)
	GameManager.player_hp = maxi(0, GameManager.player_hp - result.player_damage_taken)

	# Fortress: block heals opponent
	if gimmick is Dictionary and not gimmick.is_empty():
		var block_heal := GimmickSystem.apply_fortress_block_heal(gimmick, result)
		if block_heal > 0:
			GameManager.opponent_hp = mini(GameManager.opponent_hp + block_heal, GameManager.opponent_max_hp)
			_add_to_log("[color=gray]Fortress block heals +%d HP[/color]" % block_heal)

		# Boss: apply boss perk modifiers to damage
		var boss_mods := GimmickSystem.get_boss_perk_modifiers(
			GameManager.opponent_perks,
			GameManager.current_round_in_fight
		)
		if boss_mods.damage_bonus > 0:
			var extra_dmg: int = boss_mods.damage_bonus
			GameManager.player_hp = maxi(0, GameManager.player_hp - extra_dmg)
			_add_to_log("[color=red]Magnus perk: +%d damage![/color]" % extra_dmg)

	# Apply stamina changes
	GameManager.player_stamina = clampi(
		GameManager.player_stamina + result.player_stamina_change,
		0, GameManager.player_max_stamina
	)
	GameManager.opponent_stamina = clampi(
		GameManager.opponent_stamina + result.opponent_stamina_change,
		0, GameManager.opponent_max_stamina
	)

	# Second Wind perk (heat-scaled)
	if not second_wind_used and GameManager.has_perk("second_wind"):
		var hp_pct := float(GameManager.player_hp) / float(GameManager.player_max_hp)
		var threshold := GameManager.get_perk_named_value("second_wind", "threshold", 0.1)
		if hp_pct <= threshold and GameManager.player_hp > 0:
			var recovery := GameManager.get_perk_scaled_value("second_wind", 0.3)
			var heal := int(GameManager.player_max_hp * recovery)
			GameManager.player_hp = mini(GameManager.player_hp + heal, GameManager.player_max_hp)
			second_wind_used = true
			_add_to_log("[color=green]SECOND WIND! +%d HP![/color]" % heal)

	# Animate
	_animate_turn_result(result)

	# Log messages
	for msg in result.messages:
		_add_to_log(msg)

	_update_ui()
	_update_music_intensity()
	_reset_action_highlights()
	action_phase_label.text = ""

	# Check end conditions
	if GameManager.opponent_hp <= 0:
		_on_ko("player")
		return
	if GameManager.player_hp <= 0:
		_on_ko("opponent")
		return

	# 5 turns with 2 actions each = 10 actions total
	if turn_count >= 5:
		_end_boxing_round()
		return

	# Clear combo label after a moment
	await get_tree().create_timer(0.8).timeout
	combo_label.text = ""
	_prepare_opponent_actions()
	action_phase_label.text = "SELECT ACTION 1"
	is_player_turn = true

func _highlight_action_button(action_type: BoxingAction.ActionType) -> void:
	var all_actions := BoxingAction.create_all()
	var i := 0
	for at in all_actions:
		if i < action_container.get_child_count():
			var btn: Button = action_container.get_child(i)
			if at == action_type:
				var style: StyleBoxFlat = btn.get_theme_stylebox("normal")
				style.border_color = Color(0.9, 0.78, 0.3)
				style.border_width_left = 3
				style.border_width_right = 3
				style.border_width_top = 3
				style.border_width_bottom = 3
		i += 1

func _reset_action_highlights() -> void:
	var all_actions := BoxingAction.create_all()
	var i := 0
	for at in all_actions:
		if i < action_container.get_child_count():
			var btn: Button = action_container.get_child(i)
			var style: StyleBoxFlat = btn.get_theme_stylebox("normal")
			style.border_color = Color(0, 0, 0, 0)
			style.border_width_left = 0
			style.border_width_right = 0
			style.border_width_top = 0
			style.border_width_bottom = 0
		i += 1

func _animate_turn_result(result: Dictionary) -> void:
	var r1: Dictionary = result.get("action1_result", {})
	var r2: Dictionary = result.get("action2_result", {})
	var heat := GameManager.get_heat()
	var is_heated := heat >= 2.5

	# Action 1 animations + damage popup
	var a1_dealt: int = r1.get("player_damage_dealt", 0)
	if a1_dealt > 0:
		Juice.screen_shake(opponent_sprite, 6.0, 0.12)
		Juice.flash(opponent_sprite, Color(1, 0.3, 0.3), 0.15)
		Juice.damage_popup(self, a1_dealt, opponent_sprite.global_position + Vector2(60, 0), is_heated)

	var a1_taken: int = r1.get("player_damage_taken", 0)
	if a1_taken > 0:
		Juice.screen_shake(player_sprite, 5.0, 0.12)
		Juice.flash(player_sprite, Color(1, 0.3, 0.3), 0.15)
		Juice.damage_popup(self, a1_taken, player_sprite.global_position + Vector2(60, 0), false)

	# Action 2 animations + damage popup
	var a2_dealt: int = r2.get("player_damage_dealt", 0)
	if a2_dealt > 0:
		Juice.screen_shake(opponent_sprite, 8.0, 0.15)
		Juice.flash(opponent_sprite, Color(1, 0.2, 0.2), 0.2)
		Juice.damage_popup(self, a2_dealt, opponent_sprite.global_position + Vector2(60, -20), is_heated)

	var a2_taken: int = r2.get("player_damage_taken", 0)
	if a2_taken > 0:
		Juice.screen_shake(player_sprite, 7.0, 0.15)
		Juice.flash(player_sprite, Color(1, 0.2, 0.2), 0.2)
		Juice.damage_popup(self, a2_taken, player_sprite.global_position + Vector2(60, -20), false)

	# Combo flash
	var player_combo: Dictionary = result.get("player_combo", {})
	if not player_combo.is_empty():
		Juice.combo_flash(self, player_combo.get("name", ""))

func _update_ui() -> void:
	player_hp_bar.max_value = GameManager.player_max_hp
	player_hp_bar.value = GameManager.player_hp
	player_hp_label.text = "HP: %d/%d" % [GameManager.player_hp, GameManager.player_max_hp]
	player_stamina_bar.max_value = GameManager.player_max_stamina
	player_stamina_bar.value = GameManager.player_stamina
	player_name_label.text = GameManager.player_fighter.get("name", "Player")

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
	combat_log.scroll_to_line(combat_log.get_line_count())

func _on_ko(winner: String) -> void:
	round_over = true
	is_player_turn = false

	MusicManager.muffle(true, 0.2)
	Juice.ko_slowmo(get_tree(), 1.0)

	if winner == "player":
		_add_to_log("[color=green]KO! You win the fight![/color]")
		Juice.screen_shake(self, 15.0, 0.4)
	else:
		_add_to_log("[color=red]KO! You've been knocked out![/color]")
		Juice.screen_shake(self, 15.0, 0.4)

	for btn in action_container.get_children():
		(btn as Button).disabled = true

	await get_tree().create_timer(2.0).timeout

	if winner == "player":
		GameManager.opponent_hp = 0
	else:
		GameManager.player_hp = 0
	GameManager.advance_fight_round()

func _update_music_intensity() -> void:
	var player_hp_pct := float(GameManager.player_hp) / float(GameManager.player_max_hp)
	var opp_hp_pct := float(GameManager.opponent_hp) / float(GameManager.opponent_max_hp)
	if player_hp_pct < 0.3 or opp_hp_pct < 0.3:
		MusicManager.shift_intensity("boxing_intense")

func _end_boxing_round() -> void:
	round_over = true
	is_player_turn = false
	_add_to_log("Round over! Back to the chess board...")

	await get_tree().create_timer(1.5).timeout
	GameManager.advance_fight_round()
