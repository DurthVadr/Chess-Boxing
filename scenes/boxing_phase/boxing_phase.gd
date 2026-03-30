extends Control

## Boxing Phase — Sequential QTE combat with heat-scaled perks.
## Player selects 2 actions, then the turn executes step-by-step:
##   Step 1: Player Action 1  (Offensive QTE)
##   Step 2: Enemy Action 1   (Defensive QTE)
##   Step 3: Player Action 2  (Offensive QTE)
##   Step 4: Enemy Action 2   (Defensive QTE)

@onready var player_hp_bar: ProgressBar = %PlayerHPBar
@onready var player_hp_label: Label = %PlayerHPLabel
@onready var player_name_label: Label = %PlayerNameLabel
@onready var opponent_hp_bar: ProgressBar = %OpponentHPBar
@onready var opponent_hp_label: Label = %OpponentHPLabel
@onready var opponent_name_label: Label = %OpponentNameLabel
@onready var combat_log: RichTextLabel = %CombatLog
@onready var action_container: GridContainer = %ActionContainer
@onready var bonus_label: Label = %BonusLabel
@onready var player_sprite: AnimatedPortrait = %PlayerSprite
@onready var opponent_sprite: TextureRect = %OpponentSprite
@onready var combo_label: Label = %ComboLabel
@onready var action_phase_label: Label = %ActionPhaseLabel
@onready var round_timer_label: Label = %RoundTimerLabel
@onready var center_stage: Control = %CenterSpacer

var combat_mgr: CombatManager
var opponent_ai: OpponentAI
var is_player_turn: bool = true
var round_over: bool = false
var turn_count: int = 0
var second_wind_used: bool = false
var round_time_remaining: float = 180.0

# 2-action selection state
var action_selection_phase: int = 0
var selected_action_1: BoxingAction.ActionType = BoxingAction.ActionType.JAB
var opponent_next_actions: Array = []

# Execution state
var _executing: bool = false

# Tactic card state for this turn
var tactic_played_this_turn: bool = false

const ACTION_COLORS := {
	"Jab":      Color(0.52, 0.22, 0.18),
	"Cross":    Color(0.58, 0.26, 0.16),
	"Uppercut": Color(0.62, 0.26, 0.14),
}

const GOLD := Color(0.92, 0.80, 0.28)

func _process(delta: float) -> void:
	if round_over:
		return
	round_time_remaining = maxf(round_time_remaining - delta, 0.0)
	var mins := int(round_time_remaining) / 60
	var secs := int(round_time_remaining) % 60
	round_timer_label.text = "%02d:%02d" % [mins, secs]


func _ready() -> void:
	combat_mgr = CombatManager.new()
	opponent_ai = OpponentAI.new()
	opponent_ai.setup(GameManager.current_opponent.get("archetype", "brawler"))
	opponent_ai.setup_telegraphs(GameManager.current_opponent.get("id", ""))

	combo_label.text = ""
	action_phase_label.text = "SELECT ACTION 1"

	var sprite_base: String = GameManager.current_opponent.get("sprite_base", "")
	if sprite_base != "":
		var tex_path := "res://assets/sprites/opponents/%s_neutral.png" % sprite_base
		opponent_sprite.texture = load(tex_path)

	# Load player idle animation from sprite sheet frames
	var player_sprite_base: String = GameManager.player_fighter.get("sprite_base", "rookie")
	var anim_folder := "res://assets/sprites/fighters/%s_idle" % player_sprite_base
	player_sprite.load_animation(anim_folder)

	_update_ui()
	_build_action_buttons()
	_build_tactic_hand()
	_show_heat()
	_prepare_opponent_actions()

	AudioManager.play_round_bell()
	Juice.fade_in(self, 0.3)
	Juice.screen_shake(self, 6.0, 0.2)

func _show_heat() -> void:
	var current_heat := GameManager.get_heat()
	bonus_label.text = HeatSystem.get_heat_text(current_heat)
	bonus_label.add_theme_color_override("font_color", HeatSystem.get_heat_color(current_heat))

func _build_action_buttons() -> void:
	for child in action_container.get_children():
		child.queue_free()

	var all_actions := BoxingAction.create_all()
	var equipped := GameManager.equipped_moves

	# If only 1 slot, auto-fill both with that move
	if GameManager.move_slots == 1:
		_auto_select_single_move(equipped[0])
		return

	for move_type in equipped:
		var action: BoxingAction = all_actions[move_type]
		var btn := Button.new()
		btn.custom_minimum_size = Vector2(160, 55)
		var dmg := action.damage
		if move_type == BoxingAction.ActionType.JAB:
			dmg += GameManager.get_jab_damage_bonus()
		btn.text = "%s (DMG: %d)" % [action.name, dmg]

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
		btn.tooltip_text = action.description

		btn.pressed.connect(_on_action_selected.bind(move_type))
		action_container.add_child(btn)

## When player only has 1 move slot, auto-select both actions
func _auto_select_single_move(move_type: BoxingAction.ActionType) -> void:
	selected_action_1 = move_type
	action_selection_phase = 0
	action_phase_label.text = "AUTO: Double %s" % BoxingAction.create_all()[move_type].name
	_set_actions_disabled(true)
	# Small delay then auto-execute
	await get_tree().create_timer(0.3).timeout
	_on_action_selected(move_type)
	await get_tree().create_timer(0.2).timeout
	_on_action_selected(move_type)

func _build_tactic_hand() -> void:
	var tactic_container: HBoxContainer = get_node_or_null("%TacticHandContainer")
	if tactic_container == null:
		tactic_container = HBoxContainer.new()
		tactic_container.name = "TacticHandContainer"
		tactic_container.alignment = BoxContainer.ALIGNMENT_CENTER
		tactic_container.add_theme_constant_override("separation", 8)
		var parent: Node = action_container.get_parent()
		parent.add_child(tactic_container)
		parent.move_child(tactic_container, action_container.get_index())

	for child in tactic_container.get_children():
		child.queue_free()

	if GameManager.tactic_hand.is_empty():
		return

	var label := Label.new()
	label.text = "TACTICS:"
	label.add_theme_font_size_override("font_size", 11)
	label.add_theme_color_override("font_color", Color(0.7, 0.65, 0.5))
	tactic_container.add_child(label)

	for i in GameManager.tactic_hand.size():
		var card: Dictionary = GameManager.tactic_hand[i]

		var panel := PanelContainer.new()
		panel.custom_minimum_size = Vector2(80, 100)

		var style := StyleBoxFlat.new()
		var shop_type: String = card.get("shop", "study")
		if shop_type == "study":
			style.bg_color = Color(0.2, 0.28, 0.45)
		else:
			style.bg_color = Color(0.45, 0.2, 0.18)
		style.corner_radius_top_left = 6
		style.corner_radius_top_right = 6
		style.corner_radius_bottom_left = 6
		style.corner_radius_bottom_right = 6
		style.border_width_left = 2
		style.border_width_right = 2
		style.border_width_top = 2
		style.border_width_bottom = 2
		style.border_color = Color(0.9, 0.75, 0.3, 0.6)
		panel.add_theme_stylebox_override("panel", style)

		var vbox := VBoxContainer.new()
		vbox.alignment = BoxContainer.ALIGNMENT_CENTER
		vbox.add_theme_constant_override("separation", 2)

		var art := TextureRect.new()
		art.custom_minimum_size = Vector2(64, 64)
		art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		var art_path := "res://assets/sprites/cards/tactic_%s.png" % card.get("effect", "")
		if ResourceLoader.exists(art_path):
			art.texture = load(art_path)
		vbox.add_child(art)

		var name_label := Label.new()
		name_label.text = card.get("name", "?")
		name_label.add_theme_font_size_override("font_size", 10)
		name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		vbox.add_child(name_label)

		panel.add_child(vbox)

		var btn := Button.new()
		btn.flat = true
		btn.anchors_preset = Control.PRESET_FULL_RECT
		btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		btn.tooltip_text = TacticCardSystem.get_card_combat_text(card)

		if tactic_played_this_turn:
			btn.disabled = true
			btn.tooltip_text = "1 tactic per turn"
			panel.modulate = Color(0.5, 0.5, 0.5)

		btn.pressed.connect(_on_play_tactic.bind(i))
		panel.add_child(btn)

		tactic_container.add_child(panel)

func _on_play_tactic(index: int) -> void:
	if not is_player_turn or round_over or tactic_played_this_turn or _executing:
		return

	var card := GameManager.play_tactic_card(index)
	if card.is_empty():
		return
	AudioManager.play_card_play()

	tactic_played_this_turn = true

	var card_name: String = card.get("name", "?")
	var combat_text := TacticCardSystem.get_card_combat_text(card)
	_add_to_log("[color=gold]TACTIC: %s — %s[/color]" % [card_name, combat_text])

	if card.get("effect", "") == "fork":
		_add_to_log("[color=gray]> ??? (opponent is blinded)[/color]")

	if card.get("effect", "") == "pin":
		if opponent_next_actions.size() >= 2:
			opponent_next_actions[1] = BoxingAction.ActionType.JAB
			_add_to_log("[color=gold]Pin: Opponent's second action forced to JAB![/color]")

	_build_tactic_hand()
	Juice.scale_bounce(action_container, 1.02, 0.15)

func _prepare_opponent_actions() -> void:
	var opp_hp_pct := float(GameManager.opponent_hp) / float(GameManager.opponent_max_hp)
	var player_hp_pct := float(GameManager.player_hp) / float(GameManager.player_max_hp)
	opponent_next_actions = opponent_ai.choose_actions(opp_hp_pct, 100, player_hp_pct)

	var telegraph_text := opponent_ai.get_telegraph_for_actions(opponent_next_actions)
	_add_to_log("[color=#e89926]> %s[/color]" % telegraph_text)

	if GameManager.has_perk("see_first_move") and turn_count == 0:
		var all_actions := BoxingAction.create_all()
		var first_action: BoxingAction = all_actions[opponent_next_actions[0]]
		_add_to_log("[color=#e6c44c]HUSTLER SENSE: %s![/color]" % first_action.name)

# =============================================================================
# Action Selection
# =============================================================================

func _on_action_selected(action_type: BoxingAction.ActionType) -> void:
	if not is_player_turn or round_over or _executing:
		return
	AudioManager.play_button_click()

	# All In perk no longer restricts actions (no block/dodge in new system)

	if action_selection_phase == 0:
		selected_action_1 = action_type
		action_selection_phase = 1

		var all_actions := BoxingAction.create_all()
		var act1_name: String = (all_actions[action_type] as BoxingAction).name
		action_phase_label.text = "Action 1: %s — SELECT ACTION 2" % act1_name

		_highlight_action_button(action_type)
		return

	# Second action selected — begin sequential execution
	action_selection_phase = 0
	is_player_turn = false
	_executing = true
	turn_count += 1

	var player_actions: Array = [selected_action_1, action_type]
	opponent_ai.record_player_actions(player_actions)

	# Combo detection
	var combo_name := ComboSystem.get_combo_name(selected_action_1, action_type)
	if combo_name != "":
		combo_label.text = combo_name
		combo_label.add_theme_color_override("font_color", GOLD)
		Juice.punch_text(combo_label)
		Juice.screen_flash(self, Color(0.9, 0.8, 0.2, 0.15), 0.2)
		Juice.screen_shake(self, 3.0, 0.1)

	# Resolve tactic modifiers
	var opp_hp_pct := float(GameManager.opponent_hp) / float(GameManager.opponent_max_hp)
	var tactic_mods := TacticCardSystem.resolve_tactics(GameManager.active_tactics, opp_hp_pct)

	if tactic_mods.sacrifice_hp_cost > 0:
		GameManager.player_hp = maxi(1, GameManager.player_hp - tactic_mods.sacrifice_hp_cost)
		_add_to_log("[color=red]Sacrifice: -%d HP for guaranteed hits![/color]" % tactic_mods.sacrifice_hp_cost)
		_update_ui()

	var player_stats := {
		"damage_mod": 1.0,
		"tactic_guaranteed_hit": tactic_mods.player_guaranteed_hit,
		"tactic_back_rank": tactic_mods.back_rank_active,
		"tactic_dodge_auto_fail": tactic_mods.dodge_auto_fail,
		"tactic_en_passant_multiplier": tactic_mods.en_passant_multiplier,
		"tactic_block_deals_damage": tactic_mods.block_deals_damage,
		"endgame_damage_bonus": GameManager.endgame_damage_stacks,
		"shop_base_damage_bonus": GameManager.shop_base_damage_bonus,
	}
	var opponent_stats := {
		"damage_mod": GameManager.current_opponent.get("damage_mod", 1.0),
		"defense_mod": GameManager.current_opponent.get("defense_mod", 1.0),
	}

	# Disable all action buttons during execution
	_set_actions_disabled(true)
	action_phase_label.text = ""

	# --- SEQUENTIAL EXECUTION ---
	await _execute_turn(player_actions, opponent_next_actions, player_stats, opponent_stats, tactic_mods)

	_executing = false

	# Check end conditions
	if GameManager.opponent_hp <= 0:
		_on_ko("player")
		return
	if GameManager.player_hp <= 0:
		_on_ko("opponent")
		return

	if turn_count >= 5:
		_end_boxing_round()
		return

	# Reset for next turn
	await get_tree().create_timer(0.5).timeout
	combo_label.text = ""
	GameManager.clear_turn_tactics()
	tactic_played_this_turn = false
	_build_tactic_hand()
	_prepare_opponent_actions()
	action_phase_label.text = "SELECT ACTION 1"
	_set_actions_disabled(false)
	_reset_action_highlights()
	is_player_turn = true

# =============================================================================
# Sequential Turn Execution
# =============================================================================

func _execute_turn(
	player_actions: Array,
	opp_actions: Array,
	player_stats: Dictionary,
	opponent_stats: Dictionary,
	tactic_mods: Dictionary,
) -> void:
	var all_actions := BoxingAction.create_all()

	# Detect combos for post-step bonuses
	var player_combo := ComboSystem.detect_combo(player_actions[0], player_actions[1])
	var opp_combo := ComboSystem.detect_combo(opp_actions[0], opp_actions[1])

	# Track action results for combo application
	var step_results := []

	# ---------- STEP 1: Player Action 1 (Offensive QTE) ----------
	var p1_act: BoxingAction = all_actions[player_actions[0]]
	AudioManager.play_whoosh()
	_add_to_log("[color=#6eaadc]You throw a %s![/color]" % p1_act.name)
	var qte1: String = await _run_offensive_qte(player_actions[0])

	var r1 := combat_mgr.resolve_single_action(
		player_actions[0], opp_actions[0], qte1, true, player_stats, opponent_stats
	)
	step_results.append(r1)
	_apply_step_damage(r1, true, qte1)
	for msg in r1.messages:
		_add_to_log(msg)

	if _check_ko():
		return

	await get_tree().create_timer(0.4).timeout

	# ---------- STEP 2: Enemy Action 1 (Defensive QTE) ----------
	AudioManager.play_whoosh()
	_add_to_log("[color=#d96050]Opponent attacks![/color]")
	var qte2: String = await _run_defensive_qte()

	var r2 := combat_mgr.resolve_single_action(
		opp_actions[0], player_actions[0], qte2, false, player_stats, opponent_stats
	)
	step_results.append(r2)
	_apply_step_damage(r2, false, qte2)
	for msg in r2.messages:
		_add_to_log(msg)

	if _check_ko():
		return

	await get_tree().create_timer(0.4).timeout

	# ---------- STEP 3: Player Action 2 (Offensive QTE) ----------
	var p2_act: BoxingAction = all_actions[player_actions[1]]
	AudioManager.play_whoosh()
	_add_to_log("[color=#6eaadc]You throw a %s![/color]" % p2_act.name)
	var qte3: String = await _run_offensive_qte(player_actions[1])

	var r3 := combat_mgr.resolve_single_action(
		player_actions[1], opp_actions[1], qte3, true, player_stats, opponent_stats
	)
	step_results.append(r3)

	if not player_combo.is_empty():
		_apply_sequential_combo(player_combo, step_results[0], r3, true)

	_apply_step_damage(r3, true, qte3)
	for msg in r3.messages:
		_add_to_log(msg)

	if _check_ko():
		return

	await get_tree().create_timer(0.4).timeout

	# ---------- STEP 4: Enemy Action 2 (Defensive QTE) ----------
	AudioManager.play_whoosh()
	_add_to_log("[color=#d96050]Opponent attacks![/color]")
	var qte4: String = await _run_defensive_qte()

	var r4 := combat_mgr.resolve_single_action(
		opp_actions[1], player_actions[1], qte4, false, player_stats, opponent_stats
	)
	step_results.append(r4)

	if not opp_combo.is_empty():
		_apply_sequential_combo(opp_combo, step_results[1], r4, false)

	_apply_step_damage(r4, false, qte4)
	for msg in r4.messages:
		_add_to_log(msg)

	# --- Zwischenzug: free JAB between opponent's actions ---
	if tactic_mods.free_interrupt_action != "":
		var interrupt_dmg := 5 + GameManager.shop_base_damage_bonus + GameManager.endgame_damage_stacks
		GameManager.opponent_hp = maxi(0, GameManager.opponent_hp - interrupt_dmg)
		_add_to_log("[color=gold]Zwischenzug! Free JAB for %d damage![/color]" % interrupt_dmg)
		Juice.screen_shake(opponent_sprite, 5.0, 0.10)
		Juice.flash(opponent_sprite, Color(1, 0.8, 0.3), 0.12)
		Juice.damage_popup(self, interrupt_dmg, opponent_sprite.global_position + Vector2(60, 0), true)
		_update_ui()

	# --- Opponent gimmick effects ---
	var gimmick = GameManager.current_opponent.get("gimmick", null)
	if gimmick is Dictionary and not gimmick.is_empty():
		# Build a compat result for gimmick system
		var compat_result := _build_compat_result(step_results)
		var gimmick_msgs := GimmickSystem.apply_post_turn(
			gimmick, compat_result,
			GameManager.current_round_in_fight,
			GameManager.opponent_hp,
			GameManager.opponent_max_hp
		)
		for msg in gimmick_msgs:
			_add_to_log(msg)

		var block_heal := GimmickSystem.apply_fortress_block_heal(gimmick, compat_result)
		if block_heal > 0:
			GameManager.opponent_hp = mini(GameManager.opponent_hp + block_heal, GameManager.opponent_max_hp)
			_add_to_log("[color=gray]Fortress block heals +%d HP[/color]" % block_heal)

		var boss_mods := GimmickSystem.get_boss_perk_modifiers(
			GameManager.opponent_perks,
			GameManager.current_round_in_fight
		)
		if boss_mods.damage_bonus > 0:
			var extra_dmg: int = boss_mods.damage_bonus
			GameManager.player_hp = maxi(0, GameManager.player_hp - extra_dmg)
			_add_to_log("[color=red]Magnus perk: +%d damage![/color]" % extra_dmg)

	# --- Second Wind perk ---
	if not second_wind_used and GameManager.has_perk("second_wind"):
		var hp_pct := float(GameManager.player_hp) / float(GameManager.player_max_hp)
		var threshold := GameManager.get_perk_named_value("second_wind", "threshold", 0.1)
		if hp_pct <= threshold and GameManager.player_hp > 0:
			var recovery := GameManager.get_perk_scaled_value("second_wind", 0.3)
			var heal := int(GameManager.player_max_hp * recovery)
			GameManager.player_hp = mini(GameManager.player_hp + heal, GameManager.player_max_hp)
			second_wind_used = true
			_add_to_log("[color=green]SECOND WIND! +%d HP![/color]" % heal)

	# Track total stats
	var total_dealt := 0
	var total_taken := 0
	for i in [0, 2]:  # Steps 0 and 2 are player attacks
		total_dealt += step_results[i].get("damage", 0)
	for i in [1, 3]:  # Steps 1 and 3 are opponent attacks
		total_taken += step_results[i].get("damage", 0)
	GameManager.stats.total_damage_dealt += total_dealt
	GameManager.stats.total_damage_taken += total_taken

	_update_ui()
	_update_music_intensity()

# =============================================================================
# QTE Runners — one per mini-game type
# =============================================================================

## Offensive QTE: JAB → Pendulum (slow), CROSS → Cross QTE, UPPERCUT → Convergence.
func _run_offensive_qte(action: BoxingAction.ActionType) -> String:
	var result: String
	match action:
		BoxingAction.ActionType.JAB:
			result = await _run_pendulum_qte()
		BoxingAction.ActionType.CROSS:
			result = await _run_cross_qte()
		BoxingAction.ActionType.UPPERCUT:
			result = await _run_convergence_qte()
		_:
			result = await _run_pendulum_qte()
	return result

## Defensive QTE: Knight's Leap directional sequence.
func _run_defensive_qte() -> String:
	return await _run_knights_leap_qte()

## Pendulum (Jab) — slow horizontal timing bar, easy to hit.
func _run_pendulum_qte() -> String:
	var qte := QTEPendulum.new()
	qte.prompt_text = "JAB!"
	qte.prompt_color = Color(0.88, 0.36, 0.32)
	qte.cursor_speed = 420.0  # Slower = easier for jab
	qte.position = _get_center_stage_pos(QTEPendulum.BAR_WIDTH + 40, 60)
	qte.z_index = 150
	add_child(qte)
	AudioManager.play_qte_appear()
	var result: String = await qte.run()
	AudioManager.play_qte_result(result)
	_spawn_qte_result_popup(result, qte.global_position + Vector2(QTEPendulum.BAR_WIDTH * 0.5, -10))
	qte.queue_free()
	return result

## Cross QTE — two perpendicular timing bars, gradual curve.
func _run_cross_qte() -> String:
	var qte := QTECross.new()
	qte.prompt_text = "CROSS!"
	qte.prompt_color = Color(0.88, 0.36, 0.32)
	var cross_size := QTECross.ARM_LENGTH * 2 + 60
	qte.position = _get_center_stage_pos(cross_size, cross_size + 40)
	qte.z_index = 150
	add_child(qte)
	AudioManager.play_qte_appear()
	var result: String = await qte.run()
	AudioManager.play_qte_result(result)
	_spawn_qte_result_popup(result, qte.global_position + Vector2(cross_size * 0.5, -10))
	qte.queue_free()
	return result

## Convergence (Uppercut) — shrinking circles over enemy portrait.
func _run_convergence_qte() -> String:
	var qte := QTEConvergence.new()
	qte.prompt_text = "UPPERCUT!"
	qte.prompt_color = Color(0.88, 0.36, 0.32)
	# Center over opponent sprite
	var opp_center := opponent_sprite.global_position + opponent_sprite.size * 0.5
	var qte_half := Vector2(QTEConvergence.START_RADIUS + 20, QTEConvergence.START_RADIUS + 30)
	qte.position = opp_center - qte_half
	qte.z_index = 150
	add_child(qte)
	AudioManager.play_qte_appear()
	var result: String = await qte.run()
	AudioManager.play_qte_result(result)
	_spawn_qte_result_popup(result, opp_center + Vector2(0, -QTEConvergence.START_RADIUS - 20))
	qte.queue_free()
	return result

## Knight's Leap (Defense) — directional arrow sequence.
func _run_knights_leap_qte() -> String:
	var qte := QTEKnightsLeap.new()
	qte.prompt_text = "DEFEND!"
	qte.prompt_color = Color(0.32, 0.52, 0.82)
	qte.position = _get_center_stage_pos(320, 110)
	qte.z_index = 150
	add_child(qte)
	AudioManager.play_qte_appear()
	var result: String = await qte.run()
	AudioManager.play_qte_result(result)
	_spawn_qte_result_popup(result, qte.global_position + Vector2(160, -10))
	qte.queue_free()
	return result

## Position helper — centers a QTE of given size within the center stage area.
func _get_center_stage_pos(w: float, h: float) -> Vector2:
	return Vector2(
		center_stage.global_position.x + (center_stage.size.x - w) * 0.5,
		center_stage.global_position.y + (center_stage.size.y - h) * 0.5
	)

## Floating result text popup above the QTE.
func _spawn_qte_result_popup(result: String, pos: Vector2) -> void:
	var label := Label.new()
	var text := ""
	var color := Color.WHITE
	var font_size := 22

	match result:
		"perfect":
			text = "PERFECT!"
			color = GOLD
			font_size = 26
		"good":
			text = "GREAT!"
			color = Color(0.80, 0.88, 0.55)
			font_size = 24
		"partial":
			text = "OK"
			color = Color(0.70, 0.82, 0.95)
			font_size = 22
		"critical":
			text = "CRITICAL!"
			color = Color(1.0, 0.90, 0.30)
			font_size = 28
		"normal":
			text = "WEAK"
			color = Color(0.65, 0.55, 0.50)
			font_size = 20
		"perfect_defense":
			text = "DODGED!"
			color = Color(0.30, 0.85, 0.55)
			font_size = 26
		"failed_defense":
			text = "HIT!"
			color = Color(0.85, 0.30, 0.25)
			font_size = 22
		_:
			text = "MISS"
			color = Color(0.55, 0.3, 0.25)
			font_size = 22

	label.text = text
	label.add_theme_color_override("font_color", color)
	label.add_theme_font_size_override("font_size", font_size)
	label.position = pos
	label.z_index = 200
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.pivot_offset = Vector2(60, 15)
	add_child(label)

	var tween := label.create_tween()
	tween.set_parallel(true)
	tween.tween_property(label, "position:y", pos.y - 50.0, 0.7).set_ease(Tween.EASE_OUT)
	tween.tween_property(label, "modulate:a", 0.0, 0.7).set_delay(0.2)
	tween.chain().tween_callback(label.queue_free)

	if result in ["perfect", "critical", "good", "perfect_defense"]:
		Juice.scale_bounce(label, 1.4, 0.3)
		Juice.screen_flash(self, Color(1, 1, 1, 0.12), 0.1)

# =============================================================================
# Step Damage Application
# =============================================================================

func _apply_step_damage(result: Dictionary, is_player_attacking: bool, qte_result: String) -> void:
	var damage: int = result.get("damage", 0)
	var heat := GameManager.get_heat()
	var is_heated := heat >= 2.5

	# QTE quality tiers for visual intensity
	var is_big_hit := qte_result in ["perfect", "critical"]
	var is_good_defense := qte_result == "perfect_defense"

	if is_player_attacking:
		GameManager.opponent_hp = maxi(0, GameManager.opponent_hp - damage)

		if damage > 0:
			# Punch impact sound based on action name
			var action_name: String = result.get("action_name", "jab")
			AudioManager.play_punch(action_name, is_big_hit)
			# Attacker lunges forward
			Juice.hit_lunge(player_sprite, 1.0, 15.0, 0.18)
			# Target recoils
			var shake := 12.0 if is_big_hit else 6.0
			Juice.screen_shake(opponent_sprite, shake, 0.16)
			Juice.flash(opponent_sprite, Color(1, 0.3, 0.3), 0.15)
			Juice.damage_popup(self, damage, opponent_sprite.global_position + Vector2(60, 0), is_heated or is_big_hit)
			# Impact burst at hit point
			var hit_pos := opponent_sprite.global_position + opponent_sprite.size * 0.5
			if is_big_hit:
				Juice.impact_burst(self, hit_pos, Color(1.0, 0.9, 0.3, 0.95), 55.0)
				Juice.screen_shake(self, 4.0, 0.1)
				Juice.bar_punch(opponent_hp_bar)
			else:
				Juice.impact_burst(self, hit_pos, Color(1.0, 0.7, 0.4, 0.7), 35.0)
			Juice.bar_punch(opponent_hp_bar)
		elif result.get("dodged", false):
			# Opponent dodged — they sway smoothly
			AudioManager.play_dodge()
			Juice.dodge_slide(opponent_sprite, 1.0, 25.0, 0.3)
			Juice.afterimage(self, opponent_sprite, Color(0.5, 0.5, 0.8, 0.4))
		elif qte_result == "miss":
			AudioManager.play_miss()
	else:
		GameManager.player_hp = maxi(0, GameManager.player_hp - damage)

		if damage > 0:
			AudioManager.play_hit_taken()
			Juice.screen_shake(player_sprite, 6.0, 0.14)
			Juice.flash(player_sprite, Color(1, 0.3, 0.3), 0.15)
			Juice.damage_popup(self, damage, player_sprite.global_position + Vector2(60, 0), false)
			var hit_pos := player_sprite.global_position + player_sprite.size * 0.5
			Juice.impact_burst(self, hit_pos, Color(0.9, 0.3, 0.3, 0.7), 30.0)
			Juice.bar_punch(player_hp_bar)
			# Screen shake the whole scene for heavy hits
			if damage >= 15:
				Juice.screen_shake(self, 3.0, 0.08)
		elif is_good_defense:
			# Perfect defense — satisfying block
			AudioManager.play_perfect_block()
			Juice.dodge_slide(player_sprite, -1.0, 12.0, 0.25)
			Juice.flash(player_sprite, Color(0.3, 0.6, 1.0, 0.7), 0.15)
			Juice.screen_shake(player_sprite, 3.0, 0.08)
			var block_pos := player_sprite.global_position + player_sprite.size * 0.5
			Juice.impact_burst(self, block_pos, Color(0.3, 0.6, 1.0, 0.6), 30.0)
		elif result.get("dodged", false):
			# Player dodged — smooth sway + afterimage
			AudioManager.play_dodge_smooth()
			Juice.dodge_slide(player_sprite, -1.0, 28.0, 0.35)
			Juice.afterimage(self, player_sprite, Color(0.3, 0.8, 0.5, 0.4))

	_update_ui()

func _check_ko() -> bool:
	if GameManager.opponent_hp <= 0:
		_on_ko("player")
		return true
	if GameManager.player_hp <= 0:
		_on_ko("opponent")
		return true
	return false

# =============================================================================
# Combo Application (Sequential)
# =============================================================================

## Adapt combo bonuses for sequential resolution.
## result1 = first action result, result2 = second action result (being modified).
func _apply_sequential_combo(combo: Dictionary, result1: Dictionary, result2: Dictionary, is_player: bool) -> void:
	var effect: String = combo.get("effect", "")

	match effect:
		"bonus_damage_action2":
			var bonus: int = combo.get("bonus_damage", 3)
			result2["damage"] = result2.get("damage", 0) + bonus
			result2.messages.append("[color=yellow]COMBO: %s! +%d![/color]" % [combo.get("name", ""), bonus])

	if not combo.is_empty():
		GameManager.stats["combos_landed"] = GameManager.stats.get("combos_landed", 0) + 1

## Build a backwards-compatible result dict for GimmickSystem.
func _build_compat_result(step_results: Array) -> Dictionary:
	var total_dealt := 0
	var total_taken := 0

	for i in step_results.size():
		var r: Dictionary = step_results[i]
		if i == 0 or i == 2:  # player attack steps
			total_dealt += r.get("damage", 0)
		else:  # opponent attack steps
			total_taken += r.get("damage", 0)

	return {
		"player_damage_dealt": total_dealt,
		"player_damage_taken": total_taken,
		"action1_result": step_results[0] if step_results.size() > 0 else {},
		"action2_result": step_results[2] if step_results.size() > 2 else {},
		"messages": [],
	}

# =============================================================================
# UI Helpers
# =============================================================================

func _highlight_action_button(action_type: BoxingAction.ActionType) -> void:
	var all_actions := BoxingAction.create_all()
	var i := 0
	for at in all_actions:
		if i < action_container.get_child_count():
			var btn: Button = action_container.get_child(i)
			if at == action_type:
				var style: StyleBoxFlat = btn.get_theme_stylebox("normal")
				style.border_color = GOLD
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

func _set_actions_disabled(disabled: bool) -> void:
	for btn in action_container.get_children():
		var b := btn as Button
		b.disabled = disabled
		if disabled:
			b.focus_mode = Control.FOCUS_NONE
			b.release_focus()
		else:
			b.focus_mode = Control.FOCUS_ALL
	# Also disable tactic buttons to prevent focus stealing during QTE
	var tactic_container := get_node_or_null("%TacticHandContainer")
	if tactic_container:
		for child in tactic_container.get_children():
			if child is PanelContainer:
				for sub in child.get_children():
					if sub is Button:
						sub.disabled = disabled
						if disabled:
							sub.focus_mode = Control.FOCUS_NONE
							sub.release_focus()
						else:
							sub.focus_mode = Control.FOCUS_ALL

func _update_ui() -> void:
	player_hp_bar.max_value = GameManager.player_max_hp
	player_hp_bar.value = GameManager.player_hp
	player_hp_label.text = "HP: %d/%d" % [GameManager.player_hp, GameManager.player_max_hp]
	player_name_label.text = GameManager.player_fighter.get("name", "Player")

	opponent_hp_bar.max_value = GameManager.opponent_max_hp
	opponent_hp_bar.value = GameManager.opponent_hp
	opponent_hp_label.text = "HP: %d/%d" % [GameManager.opponent_hp, GameManager.opponent_max_hp]
	opponent_name_label.text = GameManager.current_opponent.get("name", "Opponent")

func _add_to_log(text: String) -> void:
	combat_log.append_text(text + "\n")
	combat_log.scroll_to_line(combat_log.get_line_count())

func _on_ko(winner: String) -> void:
	round_over = true
	is_player_turn = false
	_executing = false

	AudioManager.play_ko()
	MusicManager.muffle(true, 0.2)
	Juice.ko_slowmo(get_tree(), 1.0)
	Juice.screen_flash(self, Color(1, 1, 1, 0.5), 0.25)

	if winner == "player":
		_add_to_log("[color=green]KO! You win the fight![/color]")
		Juice.screen_shake(self, 20.0, 0.5)
		Juice.hit_lunge(player_sprite, 1.0, 25.0, 0.3)
		var ko_pos := opponent_sprite.global_position + opponent_sprite.size * 0.5
		Juice.impact_burst(self, ko_pos, Color(1.0, 0.85, 0.2, 1.0), 80.0)
		Juice.flash(opponent_sprite, Color(1, 0.2, 0.2), 0.3)
	else:
		_add_to_log("[color=red]KO! You've been knocked out![/color]")
		Juice.screen_shake(self, 20.0, 0.5)
		var ko_pos := player_sprite.global_position + player_sprite.size * 0.5
		Juice.impact_burst(self, ko_pos, Color(0.9, 0.2, 0.2, 1.0), 80.0)
		Juice.flash(player_sprite, Color(1, 0.2, 0.2), 0.3)

	_set_actions_disabled(true)

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
