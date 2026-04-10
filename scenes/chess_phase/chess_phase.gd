extends Control

## Chess Phase — Puzzle solving with timer and bonus calculation
## Pressure Cooker: opponent jabs the player on a loop while the puzzle is unsolved.

@onready var board_grid: GridContainer = %BoardGrid
@onready var timer_label: Label = %TimerLabel
@onready var puzzle_desc_label: Label = %PuzzleDescLabel
@onready var status_label: Label = %StatusLabel
@onready var bonus_bar: ProgressBar = %BonusBar
@onready var mistake_label: Label = %MistakeLabel
@onready var enemy_clock_label: Label = %EnemyClockLabel
@onready var opponent_portrait: AnimatedPortrait = %OpponentPortrait
@onready var player_hp_bar: ProgressBar = %PlayerHPBar
@onready var pressure_dmg_label: Label = %PressureDmgLabel
@onready var terminal_header: Label = %TerminalHeader

@onready var _focus_breath_btn: Button
var _turn_indicator: PanelContainer
@onready var fog_of_war: CanvasGroup = %FogOfWar
@onready var _background: ColorRect = $Background
@onready var _board_bezel: PanelContainer = $BoardArea/BoardBezel
@onready var fog_rect: ColorRect = %FogRect

## Passive damage dealt every tick while the puzzle is unsolved.
@export var pressure_damage: int = 3
## Seconds between each passive damage tick.
@export var pressure_interval: float = 4.0

var board_logic: ChessBoardLogic
var current_puzzle: Dictionary = {}
var time_limit: float = 60.0
var time_remaining: float = 60.0
var solve_start_time: float = 0.0
var is_active: bool = false
var mistakes: int = 0
var free_mistakes: int = 0

var _pressure_timer: Timer
var _base_vignette: float = 0.0
var _awaiting_opponent_response: bool = false  # True while animating between player/opponent moves
var _total_player_moves: int = 1
var _completed_player_moves: int = 0

# ConcussionSystem (Chess UI)
var _fog_alpha: float = 0.0
var _fog_blur: float = 0.0

const FOG_ALPHA_PER_HIT := 0.10
const FOG_BLUR_PER_HIT := 0.08
const FOG_ALPHA_MAX := 0.90
const FOG_BLUR_MAX := 1.00
const FOG_CLEAR_ON_CORRECT := 0.50

var selected_square: Vector2i = Vector2i(-1, -1)
var square_buttons: Array = []  # 2D array of buttons

# Psychedelic neon board colors — animated in _process
const LIGHT_SQUARE := Color(0.55, 0.45, 0.65)      # Base muted lavender (overridden by animation)
const DARK_SQUARE := Color(0.22, 0.18, 0.32)       # Base deep purple (overridden by animation)
const SELECTED_COLOR := Color(0.9, 0.75, 0.2, 0.85) # Bright gold
const VALID_MOVE_COLOR := Color(0.9, 0.78, 0.3, 0.2) # Subtle gold tint behind move indicators
const WRONG_COLOR := Color(0.85, 0.2, 0.2, 0.7)     # Vibrant red
const CORRECT_COLOR := Color(0.3, 0.85, 0.4, 0.6)   # Vibrant green
const LAST_MOVE_COLOR := Color(0.5, 0.2, 0.9, 0.5)  # UV purple highlight

# Neon gradient palette for board animation
const NEON_MAGENTA := Color(0.9, 0.1, 0.7)
const NEON_CYAN := Color(0.1, 0.9, 0.85)
const NEON_YELLOW := Color(0.95, 0.9, 0.1)
const NEON_PURPLE := Color(0.6, 0.1, 0.95)

var _board_breathe_time: float = 0.0
const BREATHE_SPEED := 0.7
const BREATHE_AMPLITUDE := 1.0  # Pixels of sine displacement
const NEON_CYCLE_SPEED := 0.2

# Piece colors with better contrast
const WHITE_PIECE_COLOR := Color(0.98, 0.95, 0.85)  # Warm cream
const BLACK_PIECE_COLOR := Color(0.12, 0.1, 0.15)   # Near black
const WHITE_PIECE_SHADOW := Color(0.3, 0.25, 0.2, 0.5)
const BLACK_PIECE_SHADOW := Color(0.0, 0.0, 0.0, 0.3)

var last_move_from := Vector2i(-1, -1)
var last_move_to := Vector2i(-1, -1)
var valid_moves: Array[Vector2i] = []

func _ready() -> void:
	board_logic = ChessBoardLogic.new()
	current_puzzle = GameManager.get_puzzle_for_opponent()

	time_limit = GameManager.get_chess_time_limit()
	time_remaining = time_limit
	free_mistakes = GameManager.get_free_mistakes()
	solve_start_time = 0.0

	board_logic.setup_puzzle(current_puzzle)
	puzzle_desc_label.text = current_puzzle.get("description", "Solve this puzzle!")
	bonus_bar.value = 100.0

	# Calculate total player moves for progress display
	var sol: Array = current_puzzle.get("solution", [])
	_total_player_moves = ceili(float(sol.size()) / 2.0)
	_completed_player_moves = 0
	_update_move_progress()

	# Enemy clock — show difficulty as stars
	var diff: int = int(GameManager.current_opponent.get("chess_difficulty", 1))
	enemy_clock_label.text = "★".repeat(diff) + "☆".repeat(maxi(0, 5 - diff))

	_setup_opponent_portrait()
	_setup_player_hp_bar()
	_setup_pressure_timer()
	_setup_focus_breath_button()
	_setup_concussion_ui()
	_setup_turn_indicator()

	_build_board()
	is_active = true
	solve_start_time = Time.get_ticks_msec() / 1000.0

	# Store baseline vignette so we can restore it later
	_base_vignette = CRTOverlay.DEFAULTS["vignette_intensity"]

	_setup_psychedelic_background()
	_apply_neon_text_shader(status_label)
	_apply_neon_text_shader(timer_label)
	_apply_rainbow_bar(player_hp_bar)
	_apply_rainbow_bar(bonus_bar)
	Juice.fade_in(self, 0.3)

func _process(delta: float) -> void:
	_board_breathe_time += delta
	_animate_neon_board()
	_animate_board_breathe()
	if not is_active:
		return

	time_remaining -= delta
	time_remaining = maxf(time_remaining, 0.0)

	# Update timer display
	var seconds := int(time_remaining)
	timer_label.text = "%d:%02d" % [seconds / 60, seconds % 60]  # Integer division intended (time display)

	# Color timer based on urgency + shift music intensity
	if time_remaining < 10.0:
		timer_label.add_theme_color_override("font_color", Color(0.92, 0.22, 0.22))
		MusicManager.shift_intensity("chess_tense")
	elif time_remaining < 20.0:
		timer_label.add_theme_color_override("font_color", Color(0.92, 0.72, 0.22))
	else:
		timer_label.add_theme_color_override("font_color", Color(0.35, 0.85, 0.45))

	# Update bonus bar (decays with time)
	bonus_bar.value = (time_remaining / time_limit) * 100.0

	# Pressure Cooker visual feedback — scales with missing HP
	apply_pressure_fx()

	# Time's up!
	if time_remaining <= 0.0:
		_on_puzzle_failed()

# =============================================================================
# Pressure Cooker Setup
# =============================================================================

func _setup_opponent_portrait() -> void:
	var sprite_sheet: String = GameManager.current_opponent.get("sprite_sheet", "")
	if sprite_sheet != "":
		var json_path := "res://data/sprite_frames/%s_frames.json" % sprite_sheet.get_file().get_basename()
		if FileAccess.file_exists(json_path):
			opponent_portrait.load_spritesheet_json(sprite_sheet, json_path)
		else:
			opponent_portrait.load_spritesheet(sprite_sheet, 4, 2)
	else:
		var sprite_base: String = GameManager.current_opponent.get("sprite_base", "")
		if sprite_base != "":
			var tex_path := "res://assets/sprites/opponents/%s_neutral.png" % sprite_base
			if ResourceLoader.exists(tex_path):
				opponent_portrait.texture = load(tex_path)
	# Loop a light jab animation throughout the puzzle
	if opponent_portrait._animations.has("punch"):
		opponent_portrait.play_anim("punch", true)
	elif opponent_portrait._animations.has("idle"):
		opponent_portrait.play_anim("idle", true)

func _setup_player_hp_bar() -> void:
	player_hp_bar.max_value = GameManager.player_max_hp
	player_hp_bar.value = GameManager.player_hp

func _setup_pressure_timer() -> void:
	_pressure_timer = Timer.new()
	_pressure_timer.wait_time = pressure_interval
	_pressure_timer.one_shot = false
	_pressure_timer.autostart = false
	_pressure_timer.timeout.connect(_on_pressure_tick)
	add_child(_pressure_timer)
	_pressure_timer.start()

func _on_pressure_tick() -> void:
	if not is_active:
		return
	var tick_damage := GameManager.modify_pressure_damage(pressure_damage)
	GameManager.player_hp = maxi(0, GameManager.player_hp - tick_damage)
	player_hp_bar.value = GameManager.player_hp

	_on_concussion_hit()

	# Opponent lunge + hit feedback
	Juice.hit_lunge(opponent_portrait, -1.0, 12.0, 0.18)
	Juice.flash(opponent_portrait, Color(1, 0.3, 0.3), 0.12)
	Juice.bar_punch(player_hp_bar)
	Juice.damage_popup(self, tick_damage, opponent_portrait.global_position + Vector2(40, 60))
	CRTOverlay.punch_impact(0.3)
	AudioManager.play_hit_taken()

	# Show cumulative damage taken during this puzzle
	var hp_lost := GameManager.player_max_hp - GameManager.player_hp
	pressure_dmg_label.text = "-%d HP" % hp_lost if hp_lost > 0 else ""

	# KO check — fail the puzzle if player drops to 0
	if GameManager.player_hp <= 0:
		_on_puzzle_failed()

## Increase vignette redness and camera shake proportional to missing HP.
func apply_pressure_fx() -> void:
	var hp_ratio := float(GameManager.player_hp) / float(GameManager.player_max_hp)
	var danger := 1.0 - hp_ratio  # 0.0 = full HP, 1.0 = dead

	# Vignette: ramp from baseline to heavy (up to 0.7) as HP drops
	var target_vignette := lerpf(_base_vignette, 0.7, danger)
	if CRTOverlay._crt_rect and CRTOverlay._crt_rect.material:
		var mat: ShaderMaterial = CRTOverlay._crt_rect.material
		var current_vig: float = mat.get_shader_parameter("vignette_intensity")
		# Smooth lerp toward target each frame
		mat.set_shader_parameter("vignette_intensity", lerpf(current_vig, target_vignette, 0.08))

	# Camera shake: subtle persistent wobble that intensifies at low HP
	if danger > 0.3:
		var shake_intensity := lerpf(0.0, 4.0, (danger - 0.3) / 0.7)
		Juice.screen_shake(board_grid, shake_intensity, 0.06)

# =============================================================================
# Psychedelic Visuals
# =============================================================================

func _setup_psychedelic_background() -> void:
	var shader := load("res://assets/shaders/psychedelic_bg.gdshader") as Shader
	if shader and _background:
		var mat := ShaderMaterial.new()
		mat.shader = shader
		_background.material = mat

func _apply_neon_text_shader(label: Label) -> void:
	var shader := load("res://assets/shaders/neon_text.gdshader") as Shader
	if shader == null:
		return
	var mat := ShaderMaterial.new()
	mat.shader = shader
	mat.set_shader_parameter("neon_color", Color(0.2, 1.0, 0.8, 1.0))
	mat.set_shader_parameter("glow_radius", 0.006)
	mat.set_shader_parameter("glow_intensity", 1.0)
	mat.set_shader_parameter("pulse_speed", 1.2)
	mat.set_shader_parameter("rainbow_mode", false)
	label.material = mat

func _apply_rainbow_bar(bar: ProgressBar) -> void:
	var shader := load("res://assets/shaders/rainbow_bar.gdshader") as Shader
	if shader == null:
		return
	var mat := ShaderMaterial.new()
	mat.shader = shader
	bar.material = mat

## Animate board squares with shifting neon gradients.
func _animate_neon_board() -> void:
	if square_buttons.is_empty():
		return
	var t := _board_breathe_time * NEON_CYCLE_SPEED
	for row in 8:
		for col in 8:
			# Skip squares currently highlighted (selected, valid moves, last move)
			var pos := Vector2i(col, row)
			if pos == Vector2i(selected_square.x, selected_square.y):
				continue
			if pos in valid_moves:
				continue
			if pos == last_move_from or pos == last_move_to:
				continue

			var is_light := (row + col) % 2 == 0
			# Phase offset per square for traveling wave
			var phase := (row + col) * 0.3 + t
			var wave := sin(phase) * 0.5 + 0.5

			var base: Color
			if is_light:
				# Light squares: very subtle neon tint over the lavender base
				var neon := NEON_MAGENTA.lerp(NEON_CYAN, wave)
				base = LIGHT_SQUARE.lerp(neon * 0.4, 0.12)
			else:
				# Dark squares: very subtle neon tint over the dark base
				var neon := NEON_PURPLE.lerp(Color(0.05, 0.35, 0.45), wave)
				base = DARK_SQUARE.lerp(neon * 0.3, 0.1)

			var btn: Button = square_buttons[row][col]
			var style: StyleBoxFlat = btn.get_theme_stylebox("normal")
			style.bg_color = base

## Sine-wave displacement on the board grid — board appears to breathe/melt.
## Uses pivot_offset for the displacement so it doesn't accumulate drift.
func _animate_board_breathe() -> void:
	if square_buttons.is_empty():
		return
	var t := _board_breathe_time * BREATHE_SPEED
	for row in 8:
		for col in 8:
			var btn: Button = square_buttons[row][col]
			var dx := sin(t + row * 0.6 + col * 0.3) * BREATHE_AMPLITUDE
			var dy := cos(t * 0.8 + col * 0.5 + row * 0.4) * BREATHE_AMPLITUDE * 0.6
			# Use pivot_offset trick: shifting pivot displaces the visual without affecting layout
			btn.pivot_offset = btn.size * 0.5 + Vector2(dx, dy)

# =============================================================================
# Turn Indicator
# =============================================================================

func _setup_turn_indicator() -> void:
	_turn_indicator = PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.corner_radius_top_left = 6
	style.corner_radius_top_right = 6
	style.corner_radius_bottom_left = 6
	style.corner_radius_bottom_right = 6
	style.content_margin_left = 12
	style.content_margin_right = 12
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	style.border_width_left = 2
	style.border_width_right = 2
	style.border_width_top = 2
	style.border_width_bottom = 2
	_turn_indicator.add_theme_stylebox_override("panel", style)

	var hbox := HBoxContainer.new()
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	hbox.add_theme_constant_override("separation", 8)
	_turn_indicator.add_child(hbox)

	var piece_icon := Label.new()
	piece_icon.name = "PieceIcon"
	piece_icon.add_theme_font_size_override("font_size", 22)
	hbox.add_child(piece_icon)

	var turn_text := Label.new()
	turn_text.name = "TurnText"
	turn_text.add_theme_font_size_override("font_size", 16)
	hbox.add_child(turn_text)

	# Insert after TerminalHeader
	var parent := terminal_header.get_parent()
	var idx := terminal_header.get_index() + 1
	parent.add_child(_turn_indicator)
	parent.move_child(_turn_indicator, idx)

	_update_turn_indicator()

func _update_turn_indicator() -> void:
	if _turn_indicator == null:
		return
	var hbox: HBoxContainer = _turn_indicator.get_child(0)
	var icon: Label = hbox.get_node("PieceIcon")
	var text_label: Label = hbox.get_node("TurnText")
	var style: StyleBoxFlat = _turn_indicator.get_theme_stylebox("panel")
	var is_white := board_logic.active_color == "w"

	if is_white:
		icon.text = "♔"
		icon.add_theme_color_override("font_color", WHITE_PIECE_COLOR)
		text_label.text = "YOU PLAY WHITE"
		text_label.add_theme_color_override("font_color", WHITE_PIECE_COLOR)
		style.bg_color = Color(0.18, 0.16, 0.12, 0.9)
		style.border_color = Color(0.85, 0.78, 0.55, 0.7)
	else:
		icon.text = "♚"
		icon.add_theme_color_override("font_color", Color(0.7, 0.74, 0.85))
		text_label.text = "YOU PLAY BLACK"
		text_label.add_theme_color_override("font_color", Color(0.7, 0.74, 0.85))
		style.bg_color = Color(0.06, 0.06, 0.12, 0.9)
		style.border_color = Color(0.4, 0.42, 0.6, 0.7)

	# Paint board bezel border to match player color
	if _board_bezel:
		var bezel_style: StyleBoxFlat = _board_bezel.get_theme_stylebox("panel")
		if is_white:
			bezel_style.border_color = Color(0.82, 0.78, 0.65, 0.9)
		else:
			bezel_style.border_color = Color(0.18, 0.18, 0.25, 0.9)

# =============================================================================
# Board Setup
# =============================================================================

func _build_board() -> void:
	# Clear existing
	for child in board_grid.get_children():
		child.queue_free()

	square_buttons = []
	board_grid.columns = 8

	for row in 8:
		var row_arr: Array = []
		for col in 8:
			var btn := Button.new()
			btn.custom_minimum_size = Vector2(64, 64)
			btn.focus_mode = Control.FOCUS_NONE

			# Square color with subtle gradient effect
			var is_light := (row + col) % 2 == 0
			var base_color := LIGHT_SQUARE if is_light else DARK_SQUARE

			var style := StyleBoxFlat.new()
			style.bg_color = base_color
			style.border_width_bottom = 2
			style.border_width_right = 1
			style.border_color = base_color.darkened(0.2)
			
			# Hover style with glow
			var hover_style := StyleBoxFlat.new()
			hover_style.bg_color = base_color.lightened(0.15)
			hover_style.border_width_bottom = 2
			hover_style.border_width_right = 1
			hover_style.border_color = Color(0.9, 0.8, 0.3, 0.6)
			
			btn.add_theme_stylebox_override("normal", style)
			btn.add_theme_stylebox_override("hover", hover_style)
			btn.add_theme_stylebox_override("pressed", style.duplicate())
			btn.add_theme_stylebox_override("focus", StyleBoxEmpty.new())

			# Piece text with shadow effect
			var piece_symbol := board_logic.get_piece_symbol(row, col)
			btn.text = piece_symbol
			btn.add_theme_font_size_override("font_size", 38)

			# Color pieces with better contrast
			var piece := board_logic.get_piece_at(row, col)
			if board_logic.is_white_piece(piece):
				btn.add_theme_color_override("font_color", WHITE_PIECE_COLOR)
				btn.add_theme_constant_override("outline_size", 2)
				btn.add_theme_color_override("font_outline_color", WHITE_PIECE_SHADOW)
			elif board_logic.is_black_piece(piece):
				btn.add_theme_color_override("font_color", BLACK_PIECE_COLOR)
				btn.add_theme_constant_override("outline_size", 3)
				btn.add_theme_color_override("font_outline_color", Color(0.6, 0.55, 0.7, 0.8))

			btn.pressed.connect(_on_square_pressed.bind(row, col))
			btn.mouse_entered.connect(_on_square_hovered.bind(row, col))
			board_grid.add_child(btn)
			row_arr.append(btn)
		square_buttons.append(row_arr)
	
	# Entry animation - stagger the squares
	_animate_board_entry()

func _animate_board_entry() -> void:
	for row in 8:
		for col in 8:
			var btn: Button = square_buttons[row][col]
			btn.modulate.a = 0.0
			btn.scale = Vector2(0.8, 0.8)
			btn.pivot_offset = btn.size / 2.0
			
			var delay := (row + col) * 0.02
			var tween := create_tween()
			tween.tween_interval(delay)
			tween.tween_property(btn, "modulate:a", 1.0, 0.15)
			tween.parallel().tween_property(btn, "scale", Vector2.ONE, 0.2).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)

func _on_square_hovered(row: int, col: int) -> void:
	if not is_active:
		return
	# Subtle hover feedback
	if board_logic.is_player_piece(row, col) or Vector2i(col, row) in valid_moves:
		var btn: Button = square_buttons[row][col]
		Juice.scale_bounce(btn, 1.05, 0.15)

func _refresh_board() -> void:
	for row in 8:
		for col in 8:
			var btn: Button = square_buttons[row][col]
			var piece_symbol := board_logic.get_piece_symbol(row, col)
			btn.text = piece_symbol

			var piece := board_logic.get_piece_at(row, col)
			if board_logic.is_white_piece(piece):
				btn.add_theme_color_override("font_color", WHITE_PIECE_COLOR)
				btn.add_theme_constant_override("outline_size", 2)
				btn.add_theme_color_override("font_outline_color", WHITE_PIECE_SHADOW)
			elif board_logic.is_black_piece(piece):
				btn.add_theme_color_override("font_color", BLACK_PIECE_COLOR)
				btn.add_theme_constant_override("outline_size", 3)
				btn.add_theme_color_override("font_outline_color", Color(0.6, 0.55, 0.7, 0.8))
			else:
				btn.add_theme_color_override("font_color", Color(0.5, 0.48, 0.42))

			# Reset square color, but highlight last move
			var is_light := (row + col) % 2 == 0
			var base_color := LIGHT_SQUARE if is_light else DARK_SQUARE
			var pos := Vector2i(col, row)
			
			if pos == last_move_from or pos == last_move_to:
				base_color = base_color.blend(LAST_MOVE_COLOR)
			
			var style: StyleBoxFlat = btn.get_theme_stylebox("normal")
			style.bg_color = base_color
	
	# Clear valid move hints
	valid_moves.clear()
	_update_turn_indicator()

func _on_square_pressed(row: int, col: int) -> void:
	if not is_active or _awaiting_opponent_response:
		return

	if selected_square == Vector2i(-1, -1):
		# First click — select a piece
		if board_logic.is_player_piece(row, col):
			selected_square = Vector2i(col, row)
			_highlight_selection(row, col)
			_show_valid_moves(row, col)
			# Bounce the selected piece
			Juice.scale_bounce(square_buttons[row][col], 1.1, 0.2)
	else:
		# Second click — try to move
		var from_row := selected_square.y
		var from_col := selected_square.x
		var moved_piece := board_logic.get_piece_at(from_row, from_col)

		if row == from_row and col == from_col:
			# Deselect
			_deselect()
			return

		# If clicking another own piece, reselect
		if board_logic.is_player_piece(row, col):
			_deselect()
			selected_square = Vector2i(col, row)
			_highlight_selection(row, col)
			_show_valid_moves(row, col)
			Juice.scale_bounce(square_buttons[row][col], 1.1, 0.2)
			return

		var result := board_logic.try_move(from_row, from_col, row, col)
		if result > 0:
			GameManager.set_last_chess_piece_moved(moved_piece)
		
		# Store last move for highlighting
		if result > 0:
			last_move_from = Vector2i(from_col, from_row)
			last_move_to = Vector2i(col, row)
		
		_deselect()

		match result:
			0:  # Wrong move
				_on_wrong_move(row, col)
			1:  # Correct, opponent response pending
				_on_correct_move(from_row, from_col, row, col)
			2:  # Final move — puzzle complete!
				_completed_player_moves += 1
				_on_final_correct_move(from_row, from_col, row, col)

func _highlight_selection(row: int, col: int) -> void:
	var btn: Button = square_buttons[row][col]
	var style: StyleBoxFlat = btn.get_theme_stylebox("normal")
	var prev_color := style.bg_color

	# Animate border in
	style.border_color = Color(1.0, 0.85, 0.2, 0.0)
	style.border_width_top = 3
	style.border_width_left = 3
	style.border_width_bottom = 3
	style.border_width_right = 3

	# Gold glow shadow
	style.shadow_color = Color(0.9, 0.75, 0.2, 0.35)
	style.shadow_size = 8

	var tw := create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tw.tween_property(style, "bg_color", SELECTED_COLOR, 0.12)
	tw.parallel().tween_property(style, "border_color:a", 0.9, 0.15)

func _show_valid_moves(row: int, col: int) -> void:
	valid_moves = board_logic.get_valid_squares_for_piece(row, col)
	# Sort by distance from selected piece for radial stagger effect
	var origin := Vector2(col, row)
	var sorted_moves := valid_moves.duplicate()
	sorted_moves.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		return Vector2(a).distance_to(origin) < Vector2(b).distance_to(origin)
	)
	for i in sorted_moves.size():
		var move: Vector2i = sorted_moves[i]
		var mr := move.y
		var mc := move.x
		if mr >= 0 and mr < 8 and mc >= 0 and mc < 8:
			var btn: Button = square_buttons[mr][mc]
			var style: StyleBoxFlat = btn.get_theme_stylebox("normal")
			var is_light := (mr + mc) % 2 == 0
			var base := LIGHT_SQUARE if is_light else DARK_SQUARE
			# Smooth color transition to valid-move tint
			var target_color := base.blend(VALID_MOVE_COLOR)
			var tw := create_tween()
			tw.tween_property(style, "bg_color", target_color, 0.12 + i * 0.02)
			# Draw a dot for empty squares, corner triangles for captures
			var target := board_logic.get_piece_at(mr, mc)
			if target == "":
				_draw_move_dot(btn)
			else:
				_draw_capture_ring(btn)

func _draw_move_dot(btn: Button) -> void:
	# Rounded glowing circle centered in the square via anchor layout
	var dot_key := "move_dot"
	if btn.has_meta(dot_key):
		return

	# Use a CenterContainer to guarantee centering regardless of button size
	var center := CenterContainer.new()
	center.anchors_preset = Control.PRESET_FULL_RECT
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var dot_size := 18
	var dot := Panel.new()
	dot.custom_minimum_size = Vector2(dot_size, dot_size)
	dot.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var dot_style := StyleBoxFlat.new()
	dot_style.bg_color = Color(0.9, 0.78, 0.3, 0.7)  # Gold to contrast purple board
	dot_style.corner_radius_top_left = dot_size
	dot_style.corner_radius_top_right = dot_size
	dot_style.corner_radius_bottom_left = dot_size
	dot_style.corner_radius_bottom_right = dot_size
	dot_style.shadow_color = Color(0.9, 0.75, 0.2, 0.35)
	dot_style.shadow_size = 5
	dot.add_theme_stylebox_override("panel", dot_style)

	center.add_child(dot)
	btn.add_child(center)
	btn.set_meta(dot_key, center)

	# Fade-in + scale entrance
	dot.modulate.a = 0.0
	dot.scale = Vector2(0.3, 0.3)
	dot.pivot_offset = Vector2(dot_size, dot_size) / 2.0
	var tw := create_tween()
	tw.set_ease(Tween.EASE_OUT)
	tw.set_trans(Tween.TRANS_BACK)
	tw.tween_property(dot, "modulate:a", 1.0, 0.18)
	tw.parallel().tween_property(dot, "scale", Vector2.ONE, 0.22)

	# Gentle pulse loop
	var pulse_tw := create_tween()
	pulse_tw.set_loops()
	pulse_tw.tween_property(dot_style, "bg_color:a", 0.4, 0.8).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
	pulse_tw.tween_property(dot_style, "bg_color:a", 0.7, 0.8).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
	btn.set_meta("move_dot_pulse", pulse_tw)

func _draw_capture_ring(btn: Button) -> void:
	# Thick inset ring around capturable squares using an anchored border overlay
	var ring_key := "capture_ring"
	if btn.has_meta(ring_key):
		return

	var capture_color := Color(0.92, 0.35, 0.3, 0.75)  # Warm red, visible on purple

	# Full-rect panel with thick rounded border, transparent center
	var ring := Panel.new()
	ring.anchors_preset = Control.PRESET_FULL_RECT
	ring.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var ring_style := StyleBoxFlat.new()
	ring_style.draw_center = false
	ring_style.border_width_top = 4
	ring_style.border_width_left = 4
	ring_style.border_width_bottom = 4
	ring_style.border_width_right = 4
	ring_style.border_color = capture_color
	ring_style.corner_radius_top_left = 3
	ring_style.corner_radius_top_right = 3
	ring_style.corner_radius_bottom_left = 3
	ring_style.corner_radius_bottom_right = 3
	ring.add_theme_stylebox_override("panel", ring_style)

	btn.add_child(ring)

	# Fade-in
	ring.modulate.a = 0.0
	var tw := create_tween()
	tw.tween_property(ring, "modulate:a", 1.0, 0.15)

	# Pulse the border alpha
	var pulse_tw := create_tween()
	pulse_tw.set_loops()
	pulse_tw.tween_property(ring_style, "border_color:a", 0.4, 0.7).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
	pulse_tw.tween_property(ring_style, "border_color:a", 0.75, 0.7).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)

	btn.set_meta(ring_key, true)
	btn.set_meta("capture_ring_node", ring)
	btn.set_meta("capture_pulse", pulse_tw)

func _clear_move_indicators() -> void:
	for row in 8:
		for col in 8:
			var btn: Button = square_buttons[row][col]
			if btn.has_meta("move_dot"):
				var dot: Node = btn.get_meta("move_dot")
				if is_instance_valid(dot):
					dot.queue_free()
				btn.remove_meta("move_dot")
			if btn.has_meta("move_dot_pulse"):
				var tw: Tween = btn.get_meta("move_dot_pulse")
				if tw and tw.is_valid():
					tw.kill()
				btn.remove_meta("move_dot_pulse")
			if btn.has_meta("capture_ring"):
				if btn.has_meta("capture_ring_node"):
					var ring: Node = btn.get_meta("capture_ring_node")
					if is_instance_valid(ring):
						ring.queue_free()
					btn.remove_meta("capture_ring_node")
				if btn.has_meta("capture_pulse"):
					var tw: Tween = btn.get_meta("capture_pulse")
					if tw and tw.is_valid():
						tw.kill()
					btn.remove_meta("capture_pulse")
				_reset_square_style(row, col)
				btn.remove_meta("capture_ring")

func _deselect() -> void:
	if selected_square != Vector2i(-1, -1):
		var r := selected_square.y
		var c := selected_square.x
		_reset_square_style(r, c)
		selected_square = Vector2i(-1, -1)

	# Clear valid move highlights and indicators
	_clear_move_indicators()
	for move in valid_moves:
		var mr := move.y
		var mc := move.x
		if mr >= 0 and mr < 8 and mc >= 0 and mc < 8:
			_reset_square_style(mr, mc)
	valid_moves.clear()

func _reset_square_style(row: int, col: int) -> void:
	var is_light := (row + col) % 2 == 0
	var base_color := LIGHT_SQUARE if is_light else DARK_SQUARE
	var pos := Vector2i(col, row)

	if pos == last_move_from or pos == last_move_to:
		base_color = base_color.blend(LAST_MOVE_COLOR)

	var style: StyleBoxFlat = square_buttons[row][col].get_theme_stylebox("normal")
	style.bg_color = base_color
	style.border_width_top = 0
	style.border_width_left = 0
	style.border_width_bottom = 2
	style.border_width_right = 1
	style.border_color = base_color.darkened(0.2)
	style.shadow_color = Color(0, 0, 0, 0)
	style.shadow_size = 0

func _on_wrong_move(row: int, col: int) -> void:
	AudioManager.play_sfx_varied(AudioManager.sfx_error, -4.0)
	Juice.screen_shake(self, 5.0, 0.15)
	Juice.flash(board_grid, Color(0.9, 0.2, 0.2, 0.4), 0.12)
	mistakes += 1

	if mistakes <= free_mistakes:
		status_label.text = "Wrong! (Free mistake used)"
		mistake_label.text = "Free mistakes left: %d" % (free_mistakes - mistakes)
	else:
		status_label.text = "Wrong move! Try again."
		mistake_label.text = "Mistakes: %d" % (mistakes - free_mistakes)

	# Flash the target square red
	var style: StyleBoxFlat = square_buttons[row][col].get_theme_stylebox("normal")
	var original_color := style.bg_color
	style.bg_color = WRONG_COLOR
	var tween := create_tween()
	tween.tween_property(style, "bg_color", original_color, 0.4)

	# Penalty: lose time
	var real_mistakes := mistakes - free_mistakes
	if real_mistakes > 0:
		time_remaining -= 5.0 * real_mistakes

	# Too many mistakes = fail
	if real_mistakes >= 3:
		_on_puzzle_failed()

	Juice.screen_shake(board_grid, 5.0, 0.15)

func _on_correct_move(from_row: int, from_col: int, to_row: int, to_col: int) -> void:
	_awaiting_opponent_response = true
	_completed_player_moves += 1

	# Reset timer on each correct move in multi-move puzzles
	if _total_player_moves > 1:
		time_remaining = time_limit

	# --- Phase 1: Player attack animation ---
	AudioManager.play_piece_move()
	status_label.text = "Correct!"
	status_label.add_theme_color_override("font_color", Color(0.3, 0.9, 0.3))
	Juice.punch_text(status_label)

	# Animate the moved piece
	var to_btn: Button = square_buttons[to_row][to_col]
	to_btn.pivot_offset = to_btn.size / 2.0
	to_btn.scale = Vector2(1.3, 1.3)
	var scale_tween := create_tween()
	scale_tween.set_ease(Tween.EASE_OUT)
	scale_tween.set_trans(Tween.TRANS_ELASTIC)
	scale_tween.tween_property(to_btn, "scale", Vector2.ONE, 0.3)

	# Flash the destination square green
	var style: StyleBoxFlat = to_btn.get_theme_stylebox("normal")
	var original_color := style.bg_color
	style.bg_color = CORRECT_COLOR
	var color_tween := create_tween()
	color_tween.tween_property(style, "bg_color", original_color.blend(LAST_MOVE_COLOR), 0.4)

	_refresh_board()

	# Player "attack" — opponent gets hit visually
	Juice.screen_shake(opponent_portrait, 6.0, 0.15)
	Juice.flash(opponent_portrait, Color(0.3, 0.9, 0.3, 0.5), 0.15)
	CRTOverlay.punch_impact(0.4)

	_clear_fog_fraction(FOG_CLEAR_ON_CORRECT)

	# --- Phase 2: After a brief pause, play opponent's auto-response ---
	var opp_uci := board_logic.peek_opponent_response()
	if opp_uci == "":
		# No opponent response — this shouldn't happen for result=1, but be safe
		_awaiting_opponent_response = false
		_update_move_progress()
		return

	var delay_tween := create_tween()
	delay_tween.tween_interval(0.6)
	delay_tween.tween_callback(_execute_opponent_response.bind(opp_uci))


## Execute the opponent's auto-response move on the board with animation.
func _execute_opponent_response(opp_uci: String) -> void:
	# Parse opponent move coordinates for highlighting
	var opp_from := board_logic.uci_to_coords(opp_uci.substr(0, 2))
	var opp_to := board_logic.uci_to_coords(opp_uci.substr(2, 2))

	# Execute on the board logic (advances solution step)
	var more_moves := board_logic.execute_opponent_response()

	# Update last-move highlights
	last_move_from = opp_from
	last_move_to = opp_to

	# Animate opponent's response on the visual board
	_refresh_board()
	AudioManager.play_piece_move()

	# Opponent portrait punches during their response
	if opponent_portrait._animations.has("punch"):
		opponent_portrait.play_anim("punch", false)

	# Visual feedback on the board for opponent's move
	var opp_to_btn: Button = square_buttons[opp_to.y][opp_to.x]
	opp_to_btn.pivot_offset = opp_to_btn.size / 2.0
	opp_to_btn.scale = Vector2(1.25, 1.25)
	var opp_scale_tween := create_tween()
	opp_scale_tween.set_ease(Tween.EASE_OUT)
	opp_scale_tween.set_trans(Tween.TRANS_ELASTIC)
	opp_scale_tween.tween_property(opp_to_btn, "scale", Vector2.ONE, 0.3)

	# Flash opponent's destination in a reddish tone
	var opp_style: StyleBoxFlat = opp_to_btn.get_theme_stylebox("normal")
	var opp_original_color := opp_style.bg_color
	opp_style.bg_color = Color(0.7, 0.3, 0.3, 0.7)
	var opp_color_tween := create_tween()
	opp_color_tween.tween_property(opp_style, "bg_color", opp_original_color.blend(LAST_MOVE_COLOR), 0.4)

	Juice.screen_shake(board_grid, 4.0, 0.1)

	if more_moves:
		# More player moves needed — re-enable input after a brief pause
		status_label.text = "Opponent responds... Your move!"
		status_label.add_theme_color_override("font_color", Color(0.92, 0.72, 0.22))
		_update_move_progress()
		var resume_tween := create_tween()
		resume_tween.tween_interval(0.4)
		resume_tween.tween_callback(func():
			_awaiting_opponent_response = false
			status_label.text = "Your move!"
			status_label.add_theme_color_override("font_color", Color.WHITE)
		)
	else:
		# Opponent's response was the final move — puzzle complete
		_on_puzzle_solved()


func _update_move_progress() -> void:
	var remaining := board_logic.get_remaining_player_moves()
	if _total_player_moves > 1:
		mistake_label.text = "Move %d / %d" % [_completed_player_moves + 1, _total_player_moves]
	else:
		mistake_label.text = ""

func _is_mate_puzzle() -> bool:
	var themes: Array = current_puzzle.get("themes", [])
	for t in themes:
		if str(t).begins_with("mateIn") or str(t) == "mate" or str(t) == "backRankMate" \
			or str(t) == "smotheredMate" or str(t) == "hookMate" or str(t) == "arabianMate":
			return true
	return false

func _on_final_correct_move(from_row: int, from_col: int, to_row: int, to_col: int) -> void:
	AudioManager.play_piece_move()
	var is_mate := _is_mate_puzzle()

	# Animate the finishing move — bigger for mate
	var to_btn: Button = square_buttons[to_row][to_col]
	to_btn.pivot_offset = to_btn.size / 2.0
	to_btn.scale = Vector2(1.6, 1.6) if is_mate else Vector2(1.4, 1.4)
	var scale_tween := create_tween()
	scale_tween.set_ease(Tween.EASE_OUT)
	scale_tween.set_trans(Tween.TRANS_ELASTIC)
	scale_tween.tween_property(to_btn, "scale", Vector2.ONE, 0.4 if is_mate else 0.35)

	var style: StyleBoxFlat = to_btn.get_theme_stylebox("normal")
	style.bg_color = CORRECT_COLOR

	_refresh_board()

	if is_mate:
		# CHECKMATE — extra celebration effects
		Juice.screen_shake(self, 16.0, 0.35)
		Juice.screen_flash(self, Color(1.0, 0.85, 0.2, 0.25), 0.3)
		Juice.screen_shake(opponent_portrait, 18.0, 0.3)
		Juice.flash(opponent_portrait, Color(1.0, 0.9, 0.3, 0.8), 0.3)
		CRTOverlay.punch_impact(1.2)
		# Flash all squares with a radiant white-gold burst
		_mate_board_flash()
		status_label.text = "CHECKMATE!"
		status_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2))
		Juice.punch_text(status_label)
	else:
		Juice.screen_shake(opponent_portrait, 10.0, 0.2)
		Juice.flash(opponent_portrait, Color(0.3, 1.0, 0.3, 0.6), 0.2)
		CRTOverlay.punch_impact(0.7)

	_on_puzzle_solved()

func _mate_board_flash() -> void:
	# Radiating white-gold shockwave from center outward
	var center_row := 3.5
	var center_col := 3.5
	for row in 8:
		for col in 8:
			var btn: Button = square_buttons[row][col]
			var dist := sqrt(pow(row - center_row, 2) + pow(col - center_col, 2))
			var delay := dist * 0.04
			var s: StyleBoxFlat = btn.get_theme_stylebox("normal")
			var original := s.bg_color

			var flash_color := Color(1.0, 0.92, 0.5, 0.8)
			var tw := create_tween()
			tw.tween_interval(delay)
			tw.tween_property(s, "bg_color", flash_color, 0.1)
			tw.tween_property(s, "bg_color", original, 0.4)

			# Bounce each square outward from center
			btn.pivot_offset = btn.size / 2.0
			var bounce_tw := create_tween()
			bounce_tw.tween_interval(delay)
			bounce_tw.tween_property(btn, "scale", Vector2(1.15, 1.15), 0.08)
			bounce_tw.tween_property(btn, "scale", Vector2.ONE, 0.2).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_ELASTIC)

func _on_puzzle_solved() -> void:
	AudioManager.play_puzzle_solved()
	is_active = false
	_stop_pressure()
	_update_focus_breath_state()
	_clear_fog_all()
	var solve_time := (Time.get_ticks_msec() / 1000.0) - solve_start_time
	var real_mistakes := maxi(0, mistakes - free_mistakes)
	GameManager.set_chess_result(true, time_remaining, solve_time, real_mistakes)

	status_label.text = HeatSystem.get_heat_text(GameManager.get_heat())
	status_label.add_theme_color_override("font_color", Color(0.3, 0.95, 0.4))
	Juice.punch_text(status_label)
	Juice.screen_flash(self, Color(0.3, 0.95, 0.3, 0.15), 0.2)
	Juice.scale_bounce(board_grid, 1.02, 0.3)

	_refresh_board()
	_celebrate_solve()

	# Transition to boxing after a short delay
	var tween := create_tween()
	tween.tween_callback(_go_to_boxing).set_delay(2.0)

func _celebrate_solve() -> void:
	# Golden ripple effect across the board
	for row in 8:
		for col in 8:
			var btn: Button = square_buttons[row][col]
			var delay := (row + col) * 0.03
			var style: StyleBoxFlat = btn.get_theme_stylebox("normal")
			var original_color := style.bg_color
			var gold := Color(0.95, 0.82, 0.25, 0.6)
			
			var tween := create_tween()
			tween.tween_interval(delay)
			tween.tween_property(style, "bg_color", original_color.blend(gold), 0.15)
			tween.tween_property(style, "bg_color", original_color, 0.3)
			
			# Subtle bounce
			btn.pivot_offset = btn.size / 2.0
			var bounce_tween := create_tween()
			bounce_tween.tween_interval(delay)
			bounce_tween.tween_property(btn, "scale", Vector2(1.08, 1.08), 0.1)
			bounce_tween.tween_property(btn, "scale", Vector2.ONE, 0.15).set_ease(Tween.EASE_OUT)

func _on_puzzle_failed() -> void:
	AudioManager.play_puzzle_failed()
	is_active = false
	_stop_pressure()
	_update_focus_breath_state()
	# Failure doesn't clear fog; leave it as-is for feedback.
	var real_mistakes := maxi(0, mistakes - free_mistakes)
	GameManager.set_chess_result(false, 0.0, time_limit, real_mistakes)

	status_label.text = "Time's up! Opponent gets the bonus!"
	status_label.add_theme_color_override("font_color", Color(0.9, 0.2, 0.2))
	Juice.screen_shake(self, 10.0, 0.35)
	Juice.screen_flash(self, Color(0.9, 0.15, 0.15, 0.2), 0.2)
	MusicManager.muffle(true, 0.3)

	var tween := create_tween()
	tween.tween_callback(_go_to_boxing).set_delay(2.0)

func _stop_pressure() -> void:
	if _pressure_timer:
		_pressure_timer.stop()
	# Restore vignette to baseline
	if CRTOverlay._crt_rect and CRTOverlay._crt_rect.material:
		var mat: ShaderMaterial = CRTOverlay._crt_rect.material
		var tween := create_tween()
		tween.tween_method(
			func(v: float) -> void: mat.set_shader_parameter("vignette_intensity", v),
			mat.get_shader_parameter("vignette_intensity"), _base_vignette, 0.5
		).set_ease(Tween.EASE_OUT)
	# Return opponent to idle
	if opponent_portrait._animations.has("idle"):
		opponent_portrait.play_anim("idle", true)

# =============================================================================
# ConcussionSystem (Fog + Shake)
# =============================================================================

func _setup_concussion_ui() -> void:
	_fog_alpha = 0.0
	_fog_blur = 0.0
	_apply_fog_params()

func _on_concussion_hit() -> void:
	_fog_alpha = clampf(_fog_alpha + FOG_ALPHA_PER_HIT, 0.0, FOG_ALPHA_MAX)
	_fog_blur = clampf(_fog_blur + FOG_BLUR_PER_HIT, 0.0, FOG_BLUR_MAX)
	_apply_fog_params()
	_shake_random_pieces(randi_range(2, 3))

func _clear_fog_fraction(fraction: float) -> void:
	var f := clampf(fraction, 0.0, 1.0)
	_fog_alpha = clampf(_fog_alpha * (1.0 - f), 0.0, FOG_ALPHA_MAX)
	_fog_blur = clampf(_fog_blur * (1.0 - f), 0.0, FOG_BLUR_MAX)
	_apply_fog_params()

func _clear_fog_all() -> void:
	_fog_alpha = 0.0
	_fog_blur = 0.0
	_apply_fog_params()

func _apply_fog_params() -> void:
	if fog_rect == null:
		return
	var mat := fog_rect.material
	if mat is ShaderMaterial:
		(mat as ShaderMaterial).set_shader_parameter("fog_alpha", _fog_alpha)
		(mat as ShaderMaterial).set_shader_parameter("fog_blur", _fog_blur)

func _shake_random_pieces(count: int) -> void:
	if square_buttons.is_empty():
		return
	var positions: Array[Vector2i] = []
	for row in 8:
		for col in 8:
			if board_logic.get_piece_at(row, col) != "":
				positions.append(Vector2i(row, col))
	if positions.is_empty():
		return
	positions.shuffle()
	var pick_count := mini(count, positions.size())
	for i in pick_count:
		var pos := positions[i]
		var btn: Button = square_buttons[pos.x][pos.y]
		if btn == null:
			continue
		_shake_piece(btn)

func _shake_piece(btn: Control) -> void:
	# Physically jiggle + tilt ~5 degrees.
	btn.pivot_offset = btn.size * 0.5
	var base_pos := btn.position
	var base_rot := btn.rotation
	var tilt := deg_to_rad(5.0) * (1.0 if randf() > 0.5 else -1.0)
	var offset := Vector2(randi_range(-2, 2), randi_range(-2, 2))

	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(btn, "rotation", base_rot + tilt, 0.08).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tw.tween_property(btn, "position", base_pos + offset, 0.08).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tw.chain().set_parallel(true)
	tw.tween_property(btn, "rotation", base_rot, 0.10).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(btn, "position", base_pos, 0.10).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

func pause_pressure_for_seconds(seconds: float) -> void:
	if _pressure_timer == null:
		return
	_pressure_timer.paused = true
	_update_focus_breath_state()
	var t := get_tree().create_timer(maxf(0.0, seconds))
	await t.timeout
	if is_active and _pressure_timer:
		_pressure_timer.paused = false
	_update_focus_breath_state()

func _setup_focus_breath_button() -> void:
	_focus_breath_btn = Button.new()
	_focus_breath_btn.text = "FOCUS BREATH"
	_focus_breath_btn.add_theme_font_size_override("font_size", 11)
	_focus_breath_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_focus_breath_btn.tooltip_text = "Once per run: pause pressure damage for 3s"
	_focus_breath_btn.pressed.connect(_on_focus_breath_pressed)

	var parent := pressure_dmg_label.get_parent()
	if parent is Control:
		parent.add_child(_focus_breath_btn)
	else:
		add_child(_focus_breath_btn)
		_focus_breath_btn.position = Vector2(16, 16)

	_update_focus_breath_state()

func _update_focus_breath_state() -> void:
	if _focus_breath_btn == null:
		return
	var has_card := GameManager.has_training_card("focus_breath")
	var used := GameManager.has_training_card_used("focus_breath")
	_focus_breath_btn.visible = has_card
	_focus_breath_btn.disabled = (not is_active) or used or (_pressure_timer != null and _pressure_timer.paused)
	if used:
		_focus_breath_btn.text = "FOCUS BREATH (USED)"
	elif _pressure_timer != null and _pressure_timer.paused:
		_focus_breath_btn.text = "FOCUS BREATH (ACTIVE)"
	else:
		_focus_breath_btn.text = "FOCUS BREATH"

func _on_focus_breath_pressed() -> void:
	if not is_active:
		return
	for c in GameManager.owned_training_cards:
		if c != null and c.id == "focus_breath":
			var activated := c.try_activate(self, GameManager)
			if activated:
				AudioManager.play_qte_appear()
				Juice.screen_flash(self, Color(0.8, 0.9, 1.0, 0.12), 0.12)
			_update_focus_breath_state()
			return

func _go_to_boxing() -> void:
	GameManager.advance_fight_round()
