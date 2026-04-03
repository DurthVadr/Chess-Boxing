extends Control

## Boxing Phase — Integrated chess puzzles + boxing exchange.
## Each player attack step is: mini puzzle -> attack QTE -> damage resolve.
## Opponent defense remains timing-based per incoming punch.

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
@onready var opponent_sprite: AnimatedPortrait = %OpponentSprite
@onready var combo_label: Label = %ComboLabel
@onready var action_phase_label: Label = %ActionPhaseLabel
@onready var round_timer_label: Label = %RoundTimerLabel
@onready var puzzle_layer: CanvasLayer = $PuzzleLayer

var combat_mgr: CombatManager
var opponent_ai: OpponentAI
var is_player_turn: bool = true
var round_over: bool = false
var turn_count: int = 0
var second_wind_used: bool = false
var round_time_remaining: float = 180.0

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

var _round_puzzle_solved: bool = false
var _round_puzzle_mistakes: int = 0
var _round_puzzle_solve_time: float = 0.0
var _round_puzzle_time_limit: float = 0.0
var _round_puzzle_attempts: int = 0

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
	action_phase_label.text = "PRESS ATTACK TO START"

	var sprite_sheet: String = GameManager.current_opponent.get("sprite_sheet", "")
	if sprite_sheet != "":
		var json_path := "res://data/sprite_frames/%s_frames.json" % sprite_sheet.get_file().get_basename()
		if FileAccess.file_exists(json_path):
			opponent_sprite.load_spritesheet_json(sprite_sheet, json_path)
		else:
			opponent_sprite.load_spritesheet(sprite_sheet, 4, 2)
	else:
		var sprite_base: String = GameManager.current_opponent.get("sprite_base", "")
		if sprite_base != "":
			var tex_path := "res://assets/sprites/opponents/%s_neutral.png" % sprite_base
			opponent_sprite.texture = load(tex_path)

	# Load player sprite — use per-animation sheets if available, else fall back to folder frames
	var player_sprite_base: String = GameManager.player_fighter.get("sprite_base", "rookie")
	var sheets_base := "res://assets/sprites/fighters/%s/" % player_sprite_base
	var idle_sheet := sheets_base + "%s_idle.png" % player_sprite_base
	if ResourceLoader.exists(idle_sheet):
		player_sprite.load_anim_sheet("idle",     idle_sheet,                               5, 2)
		player_sprite.load_anim_sheet("punch",    sheets_base + "%s_punch.png"    % player_sprite_base, 5, 2)
		player_sprite.load_anim_sheet("block",    sheets_base + "%s_block.png"    % player_sprite_base, 5, 2)
		player_sprite.load_anim_sheet("hitted",   sheets_base + "%s_hitted.png"   % player_sprite_base, 5, 2)
		player_sprite.load_anim_sheet("knockout", sheets_base + "%s_knockout.png" % player_sprite_base, 5, 2)
		# Punch/block/hitted play fast so they finish within QTE timing windows
		player_sprite.set_anim_fps("punch", 20.0)
		player_sprite.set_anim_fps("block", 18.0)
		player_sprite.set_anim_fps("hitted", 18.0)
		player_sprite.set_anim_fps("knockout", 8.0)
	else:
		player_sprite.load_animation("res://assets/sprites/fighters/%s_idle" % player_sprite_base)

	_update_ui()
	_build_attack_controls()
	_build_tactic_hand()
	_show_heat()
	_prepare_opponent_actions()
	_reset_round_puzzle_metrics()

	_add_to_log("[color=#c9b38f]Round %d — FIGHT![/color]" % (GameManager.current_round_in_fight + 1))

	AudioManager.play_round_bell()
	Juice.fade_in(self, 0.3)
	Juice.screen_shake(self, 6.0, 0.2)

func _show_heat() -> void:
	var current_heat := GameManager.get_heat()
	bonus_label.text = HeatSystem.get_heat_text(current_heat)
	bonus_label.add_theme_color_override("font_color", HeatSystem.get_heat_color(current_heat))

func _build_attack_controls() -> void:
	# Clear old action buttons
	for child in action_container.get_children():
		child.queue_free()

	action_container.columns = 1
	var attack_btn := Button.new()
	attack_btn.text = "START ATTACK EXCHANGE"
	attack_btn.custom_minimum_size = Vector2(300, 52)
	attack_btn.disabled = (not is_player_turn) or round_over or _executing
	attack_btn.pressed.connect(_on_start_attack_pressed)
	action_container.add_child(attack_btn)

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
	var retaliation_count: int = GameManager.current_opponent.get("retaliation_count", 2)
	var opp_hp_pct := float(GameManager.opponent_hp) / float(GameManager.opponent_max_hp)
	var player_hp_pct := float(GameManager.player_hp) / float(GameManager.player_max_hp)

	# Fill opponent_next_actions to exactly retaliation_count entries by
	# batching AI calls (AI returns 2 at a time).
	opponent_next_actions = []
	while opponent_next_actions.size() < retaliation_count:
		var batch := opponent_ai.choose_actions(opp_hp_pct, 100, player_hp_pct)
		for action in batch:
			if opponent_next_actions.size() < retaliation_count:
				opponent_next_actions.append(action)

	var telegraph_text := opponent_ai.get_telegraph_for_actions(opponent_next_actions)
	_add_to_log("[color=#e89926]> %s[/color]" % telegraph_text)

	if GameManager.has_perk("see_first_move") and turn_count == 0:
		var all_actions := BoxingAction.create_all()
		var first_action: BoxingAction = all_actions[opponent_next_actions[0]]
		_add_to_log("[color=#e6c44c]HUSTLER SENSE: %s![/color]" % first_action.name)

# =============================================================================
# Turn Start → Execution
# =============================================================================

func _roll_player_actions() -> Array:
	# Action patterns are fixed per character — Rookie always throws Jab x3.
	var fighter_id: String = str(GameManager.player_fighter.get("id", "")).to_lower()
	if fighter_id == "rookie":
		return [BoxingAction.ActionType.JAB, BoxingAction.ActionType.JAB, BoxingAction.ActionType.JAB]
	return GameManager.get_player_attack_pattern(3)

func _on_start_attack_pressed() -> void:
	if round_over or _executing:
		return

	is_player_turn = false
	_executing = true
	turn_count += 1
	_build_attack_controls()

	var player_actions: Array = _roll_player_actions()
	opponent_ai.record_player_actions(player_actions)

	var all_actions := BoxingAction.create_all()
	var rolled_names: Array[String] = []
	for action_type in player_actions:
		var act: BoxingAction = all_actions[action_type]
		rolled_names.append(act.name)
	_add_to_log("[color=#c9b38f]Your combo: %s[/color]" % " - ".join(rolled_names))

	# Check for critical hit (triple match)
	var is_triple := ReelSystem.is_triple(player_actions)
	if is_triple:
		combo_label.text = "TRIPLE RHYTHM!"
		combo_label.add_theme_color_override("font_color", GOLD)
		Juice.punch_text(combo_label)

	# Resolve tactic modifiers
	var opp_hp_pct := float(GameManager.opponent_hp) / float(GameManager.opponent_max_hp)
	var tactic_mods := TacticCardSystem.resolve_tactics(GameManager.active_tactics, opp_hp_pct)

	if tactic_mods.sacrifice_hp_cost > 0:
		GameManager.player_hp = maxi(1, GameManager.player_hp - tactic_mods.sacrifice_hp_cost)
		_add_to_log("[color=red]Sacrifice: -%d HP for guaranteed hits![/color]" % tactic_mods.sacrifice_hp_cost)
		_update_ui()

	var player_stats := {
		"damage_mod": float(GameManager.player_fighter.get("damage_mod", 1.0)),
		"tactic_guaranteed_hit": tactic_mods.player_guaranteed_hit,
		"tactic_back_rank": tactic_mods.back_rank_active,
		"tactic_dodge_auto_fail": tactic_mods.dodge_auto_fail,
		"tactic_en_passant_multiplier": tactic_mods.en_passant_multiplier,
		"tactic_block_deals_damage": tactic_mods.block_deals_damage,
		"endgame_damage_bonus": GameManager.endgame_damage_stacks,
		"shop_base_damage_bonus": GameManager.shop_base_damage_bonus,
		"solve_bonus_damage": int(GameManager.player_fighter.get("solve_bonus_damage", 0)),
	}
	var tourney_scale := GameManager.get_tournament_scale()
	var opponent_stats := {
		"damage_mod": GameManager.current_opponent.get("damage_mod", 1.0) * tourney_scale.damage,
		"defense_mod": GameManager.current_opponent.get("defense_mod", 1.0),
	}

	action_phase_label.text = ""

	# --- EXECUTE ---
	await _execute_puzzle_turn(player_actions, opponent_next_actions, player_stats, opponent_stats, tactic_mods)

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
	is_player_turn = true
	action_phase_label.text = "PRESS ATTACK TO START"
	_build_attack_controls()

# =============================================================================
# Sequential Turn Execution
# =============================================================================

## Critical Hit — triple match bypasses puzzle, auto-lands massive hit.
func _execute_critical_hit_turn(
	action_type: BoxingAction.ActionType,
	opp_actions: Array,
	player_stats: Dictionary,
	opponent_stats: Dictionary,
	tactic_mods: Dictionary,
) -> void:
	var all_actions := BoxingAction.create_all()
	var act: BoxingAction = all_actions[action_type]

	_add_to_log("[color=gold]★ TRIPLE %s — CRITICAL HIT! ★[/color]" % act.name.to_upper())
	await get_tree().create_timer(0.4).timeout

	var crit := combat_mgr.resolve_critical_hit(action_type, player_stats, opponent_stats)
	for msg in crit.messages:
		_add_to_log(msg)

	GameManager.opponent_hp = maxi(0, GameManager.opponent_hp - crit.damage)
	AudioManager.play_punch(act.name.to_lower(), true)
	Juice.hit_lunge(player_sprite, 1.0, 25.0, 0.25)
	Juice.screen_shake(self, 18.0, 0.4)
	Juice.flash(opponent_sprite, Color(1, 0.85, 0.2), 0.3)
	Juice.damage_popup(self, crit.damage, opponent_sprite.global_position + Vector2(60, 0), true)
	var hit_pos := opponent_sprite.global_position + opponent_sprite.size * 0.5
	Juice.impact_burst(self, hit_pos, Color(1.0, 0.9, 0.3, 1.0), 70.0)
	Juice.bar_punch(opponent_hp_bar)
	_update_ui()

	if _check_ko():
		return

	# Opponent still attacks back (2 of 3 as penalty for crit)
	await get_tree().create_timer(0.6).timeout
	var crit_taken := 0
	for i in mini(2, opp_actions.size()):
		var opp_r := await _run_opponent_attack(opp_actions[i], player_stats, opponent_stats)
		crit_taken += opp_r.get("damage", 0)
		if _check_ko():
			return
	GameManager.stats.total_damage_taken += crit_taken

	GameManager.stats.total_damage_dealt += crit.damage
	_update_ui()
	_update_music_intensity()

## Main turn: ONE chess puzzle gates the whole combo.
## Phase A — player throws all 3 actions consecutively (puzzle → 3× QTE → 3× damage).
## Phase B — opponent retaliates with their 3 actions.
func _execute_puzzle_turn(
	player_actions: Array,
	opp_actions: Array,
	player_stats: Dictionary,
	opponent_stats: Dictionary,
	tactic_mods: Dictionary,
) -> void:
	var all_actions := BoxingAction.create_all()
	var player_step_results := []
	var opp_step_results := []
	var total_dealt := 0
	var total_taken := 0

	# ── PHASE A: ONE puzzle gates the entire combo ──
	var first_action: BoxingAction.ActionType = player_actions[0] if not player_actions.is_empty() else BoxingAction.ActionType.JAB
	var first_act: BoxingAction = all_actions[first_action]
	_add_to_log("[color=#6eaadc]You wind up %s x3![/color]" % first_act.name)
	AudioManager.play_whoosh()

	var puzzle_result: Dictionary = await _run_mini_puzzle()
	var puzzle_solved: bool = puzzle_result.get("solved", false)
	_record_round_puzzle_result(puzzle_result)
	_show_heat()

	# 3 consecutive player attacks — no opponent retaliation between them
	for i in 3:
		var p_action: BoxingAction.ActionType = player_actions[i] if i < player_actions.size() else BoxingAction.ActionType.JAB
		var p_act: BoxingAction = all_actions[p_action]

		_add_to_log("[color=#6eaadc]%s (%d/3)[/color]" % [p_act.name, i + 1])
		AudioManager.play_whoosh()

		var qte_atk := "normal"
		if puzzle_solved or _should_force_qte_for_jab(p_action):
			player_sprite.play_anim("punch", false)
			qte_atk = await _run_offensive_qte(p_action)

		var r_atk := combat_mgr.resolve_player_attack(p_action, puzzle_solved, qte_atk, player_stats)
		player_step_results.append(r_atk)
		_apply_player_attack_damage(r_atk, puzzle_solved, qte_atk)
		for msg in r_atk.messages:
			_add_to_log(msg)

		total_dealt += r_atk.get("damage", 0)

		if _check_ko():
			return

		if i < 2:
			await get_tree().create_timer(0.2).timeout

	await get_tree().create_timer(0.4).timeout

	# ── PHASE B: Opponent retaliates (count driven by retaliation_count in data) ──
	for i in opp_actions.size():
		var o_action: BoxingAction.ActionType = opp_actions[i]
		var opp_damage_result := await _run_opponent_attack(o_action, player_stats, opponent_stats)
		opp_step_results.append(opp_damage_result)
		total_taken += opp_damage_result.get("damage", 0)

		if _check_ko():
			return

		if i < opp_actions.size() - 1:
			await get_tree().create_timer(0.35).timeout

	# Rebuild step_results in alternating order for _build_compat_result compatibility
	var step_results := []
	for i in 3:
		step_results.append(player_step_results[i] if i < player_step_results.size() else {})
		step_results.append(opp_step_results[i] if i < opp_step_results.size() else {})

	# --- Zwischenzug: free JAB ---
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

	GameManager.stats.total_damage_dealt += total_dealt
	GameManager.stats.total_damage_taken += total_taken
	_apply_fighter_regen()
	_update_ui()
	_update_music_intensity()

func _should_force_qte_for_jab(action: BoxingAction.ActionType) -> bool:
	if action != BoxingAction.ActionType.JAB:
		return false
	return str(GameManager.player_fighter.get("id", "")).to_lower() == "rookie"

# =============================================================================
# Puzzle & QTE Runners
# =============================================================================

## Mini chess puzzle — player must solve to land their punch.
func _run_mini_puzzle() -> Dictionary:
	var puzzle_data := GameManager.get_mini_puzzle()
	var puzzle_time := 12.0
	var difficulty: int = GameManager.current_opponent.get("chess_difficulty", 1)
	if difficulty >= 4:
		puzzle_time = 9.0
	elif difficulty >= 3:
		puzzle_time = 10.0

	var chess_time_ratio := GameManager.get_chess_time_limit() / 60.0
	puzzle_time *= chess_time_ratio
	puzzle_time += float(GameManager.player_fighter.get("puzzle_time_bonus", 0.0))
	puzzle_time = clampf(puzzle_time, 6.0, 18.0)
	if puzzle_time <= 0.25:
		puzzle_time = 0.25
	var fighter_error_penalty := float(GameManager.player_fighter.get("puzzle_error_penalty", 2.0))

	# MiniPuzzle lives on the CanvasLayer so it renders above all UI.
	# It handles its own full-screen dim + centered panel internally.
	var mini_puz := MiniPuzzle.new()
	mini_puz.set_anchors_preset(Control.PRESET_FULL_RECT)
	puzzle_layer.add_child(mini_puz)
	AudioManager.play_qte_appear()
	var result: Dictionary = await mini_puz.run(puzzle_data, puzzle_time, fighter_error_penalty)
	mini_puz.queue_free()
	return result

## Offensive QTE: bonus modifier after puzzle solve.
## JAB → Pendulum, CROSS → Cross QTE, UPPERCUT → Convergence.
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

## Opponent attack with timing-based defense.
## Returns a result dict with final damage dealt.
func _run_opponent_attack(
	opp_action: BoxingAction.ActionType,
	player_stats: Dictionary,
	opponent_stats: Dictionary,
) -> Dictionary:
	var all_actions := BoxingAction.create_all()
	var o_act: BoxingAction = all_actions[opp_action]
	var punch_count := _get_punch_count(opp_action)

	AudioManager.play_whoosh()
	_add_to_log("[color=#d96050]%s throws %s! (%d hits)[/color]" % [
		GameManager.current_opponent.get("name", "Opponent"), o_act.name, punch_count])

	var defense_qte := QTETimingDefense.new()
	defense_qte.prompt_text = "BLOCK %s!" % o_act.name.to_upper()
	defense_qte.prompt_color = Color(0.32, 0.52, 0.82)
	defense_qte.custom_minimum_size = Vector2(320, 160)
	_spawn_in_center_stage(defense_qte)
	AudioManager.play_qte_appear()
	var def_result: Dictionary = await defense_qte.run(punch_count)
	defense_qte.queue_free()

	var damage_mult: float = def_result.get("damage_multiplier", 1.0)
	var block_qualities: Array = def_result.get("block_qualities", [])

	if damage_mult <= 0.05:
		player_sprite.play_anim("block", false)
	else:
		player_sprite.play_anim("hitted", false)

	var r := combat_mgr.resolve_opponent_attack(opp_action, damage_mult, opponent_stats, player_stats)
	_apply_opponent_attack_damage(r, block_qualities)
	for msg in r.messages:
		_add_to_log(msg)

	await get_tree().create_timer(0.3).timeout
	return r

## How many individual punches an opponent action consists of.
func _get_punch_count(action: BoxingAction.ActionType) -> int:
	match action:
		BoxingAction.ActionType.JAB:
			return 3
		BoxingAction.ActionType.CROSS:
			return 2
		BoxingAction.ActionType.UPPERCUT:
			return 1
	return 2

## Pendulum (Jab) — slow horizontal timing bar, easy to hit.
func _run_pendulum_qte() -> String:
	var qte := QTEPendulum.new()
	qte.prompt_text = "BONUS!"
	qte.prompt_color = Color(0.88, 0.72, 0.28)
	qte.cursor_speed = 420.0
	qte.custom_minimum_size = Vector2(QTEPendulum.BAR_WIDTH + 40, 60)
	_spawn_in_center_stage(qte)
	AudioManager.play_qte_appear()
	var result: String = await qte.run()
	AudioManager.play_qte_result(result)
	_spawn_qte_result_popup(result, qte.global_position + Vector2(QTEPendulum.BAR_WIDTH * 0.5, -10))
	qte.queue_free()
	return result

## Cross QTE — two perpendicular timing bars, gradual curve.
func _run_cross_qte() -> String:
	var qte := QTECross.new()
	qte.prompt_text = "BONUS!"
	qte.prompt_color = Color(0.88, 0.72, 0.28)
	var cross_size := QTECross.ARM_LENGTH * 2 + 60
	qte.custom_minimum_size = Vector2(cross_size, cross_size + 40)
	_spawn_in_center_stage(qte)
	AudioManager.play_qte_appear()
	var result: String = await qte.run()
	AudioManager.play_qte_result(result)
	_spawn_qte_result_popup(result, qte.global_position + Vector2(cross_size * 0.5, -10))
	qte.queue_free()
	return result

## Convergence (Uppercut) — shrinking circles over enemy portrait.
func _run_convergence_qte() -> String:
	var qte := QTEConvergence.new()
	qte.prompt_text = "BONUS!"
	qte.prompt_color = Color(0.88, 0.72, 0.28)
	# Convergence overlays opponent portrait — positioned absolutely on root
	var opp_center := opponent_sprite.global_position + opponent_sprite.size * 0.5
	var qte_half := Vector2(QTEConvergence.START_RADIUS + 20, QTEConvergence.START_RADIUS + 30)
	var qte_size := qte_half * 2.0
	qte.custom_minimum_size = qte_size
	qte.position = opp_center - qte_half
	qte.z_index = 150
	add_child(qte)
	AudioManager.play_qte_appear()
	var result: String = await qte.run()
	AudioManager.play_qte_result(result)
	_spawn_qte_result_popup(result, opp_center + Vector2(0, -QTEConvergence.START_RADIUS - 20))
	qte.queue_free()
	return result

## Spawn a QTE widget centered on screen, parented to self so it sits above
## the layout but below the CanvasLayer puzzle popup.
func _spawn_in_center_stage(node: Control) -> void:
	var w := node.custom_minimum_size.x
	var h := node.custom_minimum_size.y
	var vp := get_viewport_rect().size
	node.position = Vector2(
		(vp.x - w) * 0.5,
		(vp.y - h) * 0.5,
	)
	node.z_index = 150
	add_child(node)

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
# Damage Application
# =============================================================================

## Apply player attack damage — puzzle determined hit/miss, QTE gave bonus.
func _apply_player_attack_damage(result: Dictionary, puzzle_solved: bool, qte_result: String) -> void:
	var damage: int = result.get("damage", 0)
	var heat := GameManager.get_heat()
	var is_heated := heat >= 2.5
	var is_big_hit := qte_result in ["perfect", "critical"]

	if not puzzle_solved:
		# Puzzle failed → whiff
		AudioManager.play_miss()
		_add_to_log("[color=gray]Puzzle failed — punch misses![/color]")
		_update_ui()
		return

	GameManager.opponent_hp = maxi(0, GameManager.opponent_hp - damage)

	if damage > 0:
		var action_name: String = result.get("action_name", "jab")
		AudioManager.play_punch(action_name, is_big_hit)
		Juice.hit_lunge(player_sprite, 1.0, 15.0, 0.18)
		var shake := 12.0 if is_big_hit else 6.0
		Juice.screen_shake(opponent_sprite, shake, 0.16)
		Juice.flash(opponent_sprite, Color(1, 0.3, 0.3), 0.15)
		Juice.screen_flash(self, Color(1, 0.9, 0.3, 0.15), 0.1)
		CRTOverlay.punch_impact(0.5 if not is_big_hit else 1.0)
		Juice.damage_popup(self, damage, opponent_sprite.global_position + Vector2(60, 0), is_heated or is_big_hit)
		var hit_pos := opponent_sprite.global_position + opponent_sprite.size * 0.5
		if is_big_hit:
			Juice.impact_burst(self, hit_pos, Color(1.0, 0.9, 0.3, 0.95), 55.0)
			Juice.screen_shake(self, 5.0, 0.12)
			Juice.screen_flash(self, Color(1, 0.95, 0.4, 0.25), 0.15)
		else:
			Juice.impact_burst(self, hit_pos, Color(1.0, 0.7, 0.4, 0.7), 35.0)
			Juice.screen_shake(self, 2.0, 0.08)
		Juice.bar_punch(opponent_hp_bar)

	_update_ui()

func _apply_fighter_regen() -> void:
	var regen := int(GameManager.player_fighter.get("regen_per_turn", 0))
	if regen <= 0 or GameManager.player_hp <= 0:
		return
	var before := GameManager.player_hp
	GameManager.player_hp = mini(GameManager.player_hp + regen, GameManager.player_max_hp)
	var healed := GameManager.player_hp - before
	if healed > 0:
		_add_to_log("[color=green]%s regenerates %d HP.[/color]" % [
			GameManager.player_fighter.get("name", "Fighter"), healed
		])

## Apply opponent attack damage — timing defense determined block quality.
func _apply_opponent_attack_damage(result: Dictionary, block_qualities: Array) -> void:
	var damage: int = result.get("damage", 0)
	var avg_mult: float = result.get("damage_multiplier", 1.0)
	var is_perfect_block := avg_mult <= 0.05

	if is_perfect_block:
		# Perfect block — no damage
		opponent_sprite.play_anim("punch", false)
		Juice.hit_lunge(opponent_sprite, -1.0, 14.0, 0.2)
		AudioManager.play_perfect_block()
		Juice.dodge_slide(player_sprite, -1.0, 12.0, 0.25)
		Juice.flash(player_sprite, Color(0.3, 0.6, 1.0, 0.7), 0.15)
		Juice.screen_shake(player_sprite, 4.0, 0.1)
		Juice.screen_flash(self, Color(0.3, 0.5, 1.0, 0.15), 0.1)
		CRTOverlay.punch_impact(0.4)
		var block_pos := player_sprite.global_position + player_sprite.size * 0.5
		Juice.impact_burst(self, block_pos, Color(0.3, 0.6, 1.0, 0.7), 35.0)
		Juice.blocked_popup(self, block_pos + Vector2(0, -30))
	elif damage > 0:
		GameManager.player_hp = maxi(0, GameManager.player_hp - damage)
		opponent_sprite.play_anim("punch", false)
		Juice.hit_lunge(opponent_sprite, -1.0, 18.0, 0.2)
		AudioManager.play_hit_taken()
		var shake_str := 8.0 * avg_mult
		Juice.screen_shake(player_sprite, shake_str, 0.18)
		Juice.screen_shake(self, 3.0 * avg_mult, 0.12)
		Juice.flash(player_sprite, Color(1, 0.3, 0.3), 0.18)
		Juice.screen_flash(self, Color(1, 0.15, 0.1, 0.2 * avg_mult), 0.12)
		CRTOverlay.punch_impact(0.7 * avg_mult)
		Juice.damage_popup(self, damage, player_sprite.global_position + Vector2(60, 0), false)
		var hit_pos := player_sprite.global_position + player_sprite.size * 0.5
		Juice.impact_burst(self, hit_pos, Color(0.9, 0.3, 0.3, 0.8 * avg_mult), 38.0)
		Juice.bar_punch(player_hp_bar)
		if damage >= 15:
			Juice.screen_shake(self, 5.0, 0.12)
			CRTOverlay.punch_impact(1.0)
			Juice.screen_flash(self, Color(1, 0.2, 0.15, 0.3), 0.18)
	else:
		# Blocked enough to take no damage
		opponent_sprite.play_anim("punch", false)
		Juice.hit_lunge(opponent_sprite, -1.0, 10.0, 0.15)
		AudioManager.play_perfect_block()
		Juice.dodge_slide(player_sprite, -1.0, 8.0, 0.2)

	_update_ui()

func _check_ko() -> bool:
	if GameManager.opponent_hp <= 0:
		_on_ko("player")
		return true
	if GameManager.player_hp <= 0:
		_on_ko("opponent")
		return true
	return false

## Build a backwards-compatible result dict for GimmickSystem.
func _build_compat_result(step_results: Array) -> Dictionary:
	var total_dealt := 0
	var total_taken := 0

	for i in step_results.size():
		var r: Dictionary = step_results[i]
		if i % 2 == 0:  # player attack steps (0, 2, 4)
			total_dealt += r.get("damage", 0)
		else:  # opponent attack steps (1, 3, 5)
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

func _set_actions_disabled(disabled: bool) -> void:
	# Disable tactic buttons to prevent focus stealing during QTE
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

func _reset_round_puzzle_metrics() -> void:
	_round_puzzle_solved = true
	_round_puzzle_mistakes = 0
	_round_puzzle_solve_time = 0.0
	_round_puzzle_time_limit = 0.0
	_round_puzzle_attempts = 0

func _record_round_puzzle_result(puzzle_result: Dictionary) -> void:
	var solved: bool = puzzle_result.get("solved", false)
	var mistakes: int = int(puzzle_result.get("mistakes", 0))
	var raw_time_limit: float = float(puzzle_result.get("time_limit", 0.0))
	var raw_solve_time: float = float(puzzle_result.get("solve_time", raw_time_limit))
	var raw_time_remaining: float = float(puzzle_result.get("time_remaining", 0.0))
	var free_mistakes := GameManager.get_free_mistakes()
	var real_mistakes := maxi(0, mistakes - free_mistakes)
	var effective_time_limit := GameManager.get_chess_time_limit()
	var solve_ratio := 1.0
	var remaining_ratio := 0.0
	if raw_time_limit > 0.0:
		solve_ratio = clampf(raw_solve_time / raw_time_limit, 0.0, 1.0)
		remaining_ratio = clampf(raw_time_remaining / raw_time_limit, 0.0, 1.0)
	var solve_time := effective_time_limit * solve_ratio
	var time_remaining := effective_time_limit * remaining_ratio

	GameManager.set_chess_result(solved, time_remaining, solve_time, real_mistakes)

	_round_puzzle_solved = _round_puzzle_solved and solved
	_round_puzzle_attempts += 1
	_round_puzzle_mistakes += real_mistakes
	_round_puzzle_solve_time += solve_time
	_round_puzzle_time_limit += effective_time_limit

func _finalize_round_puzzle_stats() -> void:
	if _round_puzzle_attempts <= 0:
		GameManager.current_fight_puzzle_solved = false
		GameManager.chess_mistakes = 0
		GameManager.chess_solve_time = 0.0
		GameManager.chess_time_remaining = 0.0
		return

	GameManager.current_fight_puzzle_solved = _round_puzzle_solved
	GameManager.chess_mistakes = _round_puzzle_mistakes
	var avg_solve_time := _round_puzzle_solve_time / float(_round_puzzle_attempts)
	var avg_time_limit := _round_puzzle_time_limit / float(_round_puzzle_attempts)
	GameManager.chess_solve_time = avg_solve_time
	GameManager.chess_time_remaining = maxf(avg_time_limit - avg_solve_time, 0.0)

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
		player_sprite.play_anim("knockout", false, func():
			player_sprite.set_frame(9)
			player_sprite.stop()
		)
		Juice.flash(player_sprite, Color(1, 0.2, 0.2), 0.3)

	_set_actions_disabled(true)

	await get_tree().create_timer(2.0).timeout

	if winner == "player":
		GameManager.opponent_hp = 0
	else:
		GameManager.player_hp = 0
	_finalize_round_puzzle_stats()
	GameManager.advance_fight_round()

func _update_music_intensity() -> void:
	var player_hp_pct := float(GameManager.player_hp) / float(GameManager.player_max_hp)
	var opp_hp_pct := float(GameManager.opponent_hp) / float(GameManager.opponent_max_hp)
	if player_hp_pct < 0.3 or opp_hp_pct < 0.3:
		MusicManager.shift_intensity("boxing_intense")

func _end_boxing_round() -> void:
	round_over = true
	is_player_turn = false
	_add_to_log("Round over! Corner break...")

	await get_tree().create_timer(1.5).timeout
	_finalize_round_puzzle_stats()
	GameManager.advance_fight_round()
