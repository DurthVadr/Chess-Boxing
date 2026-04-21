extends Control

## Tournament Bracket — 8-player elimination tree with 3 columns (QF / SF / Finals).
## Uses container-based layout for responsive sizing + a custom _draw() overlay for lines.

# ── Column labels ────────────────────────────────────────────────────────────
const COL_LABELS := ["QUARTERFINALS", "SEMIFINALS", "FINALS"]

# ── Palette ──────────────────────────────────────────────────────────────────
const C_GOLD      := Color(0.90, 0.78, 0.30, 1.00)
const C_GOLD_DIM  := Color(0.42, 0.36, 0.15, 0.65)
const C_LINE_LIVE := Color(1.00, 0.76, 0.22, 0.90)
const C_LINE_DEAD := Color(0.26, 0.26, 0.22, 0.30)

const C_SLOT_PLAYER  := Color(0.04, 0.08, 0.13, 1.00)
const C_SLOT_ACTIVE  := Color(0.12, 0.09, 0.03, 1.00)
const C_SLOT_DARK    := Color(0.06, 0.06, 0.06, 1.00)
const C_BDR_PLAYER   := Color(0.35, 0.62, 0.90, 1.00)
const C_BDR_GOLD     := Color(0.90, 0.78, 0.30, 1.00)
const C_BDR_DIM      := Color(0.22, 0.22, 0.20, 0.35)
const C_BDR_DEFEATED := Color(0.28, 0.55, 0.28, 0.70)

# ── Connector gap between columns (fraction of column width) ────────────────
const CONN_RATIO := 0.35

# ── Node refs ────────────────────────────────────────────────────────────────
@onready var proceed_btn: Button = %ProceedBtn
@onready var bracket_area: HBoxContainer = %BracketArea
@onready var bracket_lines: Control = %BracketLines
@onready var tournament_num_label: Label = %TournamentNum
@onready var elo_info_label: Label = %EloInfo

# ── Slot tracking for line drawing ───────────────────────────────────────────
# Each entry is a PanelContainer whose global rect we read after layout.
var _r1_slots: Array[PanelContainer] = []  # 8 slots (4 matches × 2)
var _sf_slots: Array[PanelContainer] = []  # 4 slots (2 matches × 2)
var _fn_slots: Array[PanelContainer] = []  # 2 slots (1 match × 2)

var _r1_to_sf_active := false
var _sf_to_fn_active := false
var _active_col := 0

var _vignette: GradientTexture2D


func _ready() -> void:
	_setup_vignette()
	proceed_btn.pressed.connect(_on_proceed)
	bracket_lines.draw.connect(_on_draw_lines)
	_build_bracket()
	Juice.fade_in(self, 0.4)


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED and is_node_ready():
		bracket_lines.queue_redraw()


# ── Vignette ─────────────────────────────────────────────────────────────────

func _setup_vignette() -> void:
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.50, 1.0])
	g.colors = PackedColorArray([
		Color(0.0, 0.0, 0.0, 0.00),
		Color(0.0, 0.0, 0.0, 0.00),
		Color(0.0, 0.0, 0.0, 0.68),
	])
	_vignette = GradientTexture2D.new()
	_vignette.gradient = g
	_vignette.width = 256
	_vignette.height = 256
	_vignette.fill = GradientTexture2D.FILL_RADIAL
	_vignette.fill_from = Vector2(0.5, 0.5)
	_vignette.fill_to = Vector2(1.0, 0.5)


# ── Bracket construction ─────────────────────────────────────────────────────

func _build_bracket() -> void:
	# Clear previous
	for child in bracket_area.get_children():
		child.queue_free()
	_r1_slots.clear()
	_sf_slots.clear()
	_fn_slots.clear()

	var opp_idx: int = GameManager.current_opponent_index
	var finals_idx: int = GameManager.total_opponents - 1
	_r1_to_sf_active = opp_idx >= 1
	_sf_to_fn_active = opp_idx >= finals_idx

	if opp_idx == 0:
		_active_col = 0
	elif opp_idx < finals_idx:
		_active_col = 1
	else:
		_active_col = 2

	# ── Header info ──
	tournament_num_label.text = "TOURNAMENT %d" % GameManager.run_tournament_number
	var elo_text := "Your ELO: %d" % SaveManager.player_elo
	var cur_opp := _get_current_opponent(opp_idx)
	if not cur_opp.is_empty():
		var opp_elo := GameManager.get_opponent_elo(cur_opp)
		elo_text += "  |  vs ELO: %d" % opp_elo
	elo_info_label.text = elo_text

	# ── Player & opponent data ──
	var player_name := (GameManager.player_fighter.get("name", "THE ROOKIE") as String).to_upper()
	var cur_name := (cur_opp.get("name", "???") as String).to_upper()
	var cur_tex: Texture2D = _load_portrait(cur_opp.get("sprite_base", "") as String, cur_opp)

	var beaten: Array[Dictionary] = []
	for i in opp_idx:
		if i < GameManager.fight_order.size():
			beaten.append(GameManager._get_opponent_by_id(GameManager.fight_order[i]))

	# ── Build 3 columns with connector spacers ──
	# Layout: [Col0] [Spacer] [Col1] [Spacer] [Col2]
	for col_i in 3:
		var col := _make_column(col_i)
		bracket_area.add_child(col)

		var match_count: int = [4, 2, 1][col_i]
		_populate_column(col, col_i, match_count, opp_idx, finals_idx,
			player_name, cur_name, cur_tex, beaten)

		# Add connector spacer after columns 0 and 1
		if col_i < 2:
			var spacer := Control.new()
			spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			spacer.size_flags_stretch_ratio = CONN_RATIO
			bracket_area.add_child(spacer)

	# Redraw lines after layout settles
	call_deferred("_deferred_redraw")


func _deferred_redraw() -> void:
	bracket_lines.queue_redraw()


func _make_column(col_i: int) -> VBoxContainer:
	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.size_flags_stretch_ratio = 1.0
	col.add_theme_constant_override("separation", 0)

	# Column header
	var header := Label.new()
	header.text = COL_LABELS[col_i]
	header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	header.add_theme_font_size_override("font_size", 13)
	header.add_theme_color_override("font_color", C_GOLD if col_i == _active_col else C_GOLD_DIM)
	header.custom_minimum_size.y = 24.0
	col.add_child(header)

	return col


func _populate_column(col: VBoxContainer, col_i: int, match_count: int,
		opp_idx: int, finals_idx: int, player_name: String, cur_name: String,
		cur_tex: Texture2D, beaten: Array[Dictionary]) -> void:

	for m in match_count:
		if m > 0:
			# Spacer between matches
			var gap := Control.new()
			gap.size_flags_vertical = Control.SIZE_EXPAND_FILL
			gap.size_flags_stretch_ratio = 0.3
			col.add_child(gap)

		var match_box := VBoxContainer.new()
		match_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
		match_box.size_flags_stretch_ratio = 1.0
		match_box.add_theme_constant_override("separation", 6)
		match_box.alignment = BoxContainer.ALIGNMENT_CENTER
		col.add_child(match_box)

		# Two slots per match
		var slot_data := _get_slot_data(col_i, m, opp_idx, finals_idx,
			player_name, cur_name, cur_tex, beaten)

		for s in 2:
			var panel := _make_slot(
				slot_data[s].type, slot_data[s].label,
				slot_data[s].sub, slot_data[s].get("tex", null) as Texture2D,
				slot_data[s].get("is_match_active", false)
			)
			match_box.add_child(panel)

			# Track slots for line drawing
			match col_i:
				0: _r1_slots.append(panel)
				1: _sf_slots.append(panel)
				2: _fn_slots.append(panel)


func _get_slot_data(col_i: int, match_i: int, opp_idx: int, finals_idx: int,
		player_name: String, cur_name: String, cur_tex: Texture2D,
		beaten: Array[Dictionary]) -> Array[Dictionary]:
	# Returns [{type, label, sub, tex, is_match_active}, {same}] for the two slots in a match.

	# Column 0 = Quarterfinals: match 0 is the player's match
	if col_i == 0:
		if match_i == 0:
			if opp_idx == 0:
				return [
					{"type": "player", "label": player_name, "sub": "PLAYER", "is_match_active": true},
					{"type": "active_opp", "label": cur_name, "sub": "NOW FIGHTING", "tex": cur_tex, "is_match_active": true},
				]
			else:
				var r1_beaten: Dictionary = beaten[0] if beaten.size() > 0 else {}
				return [
					{"type": "player_past", "label": player_name, "sub": "ADVANCED"},
					{"type": "defeated", "label": (r1_beaten.get("name", "???") as String).to_upper(), "sub": "DEFEATED",
						"tex": _load_portrait(r1_beaten.get("sprite_base", "") as String, r1_beaten)},
				]
		return [
			{"type": "unknown", "label": "???", "sub": ""},
			{"type": "unknown", "label": "???", "sub": ""},
		]

	# Column 1 = Semifinals: match 0 is the player's match
	if col_i == 1:
		if match_i == 0:
			if opp_idx >= 1 and opp_idx < finals_idx:
				return [
					{"type": "player", "label": player_name, "sub": "PLAYER", "is_match_active": true},
					{"type": "active_opp", "label": cur_name, "sub": "NOW FIGHTING", "tex": cur_tex, "is_match_active": true},
				]
			elif opp_idx >= finals_idx:
				var sf_beaten: Dictionary = beaten[finals_idx - 1] if beaten.size() >= finals_idx else {}
				return [
					{"type": "player_past", "label": player_name, "sub": "ADVANCED"},
					{"type": "defeated", "label": (sf_beaten.get("name", "???") as String).to_upper(), "sub": "DEFEATED",
						"tex": _load_portrait(sf_beaten.get("sprite_base", "") as String, sf_beaten)},
				]
		return [
			{"type": "unknown", "label": "???", "sub": ""},
			{"type": "unknown", "label": "???", "sub": ""},
		]

	# Column 2 = Finals
	if opp_idx >= finals_idx:
		return [
			{"type": "player", "label": player_name, "sub": "PLAYER", "is_match_active": true},
			{"type": "active_opp", "label": cur_name, "sub": "NOW FIGHTING", "tex": cur_tex, "is_match_active": true},
		]
	return [
		{"type": "unknown", "label": "???", "sub": ""},
		{"type": "unknown", "label": "???", "sub": ""},
	]


# ── Slot creation ────────────────────────────────────────────────────────────

func _make_slot(slot_type: String, label: String, sub: String,
		texture: Texture2D = null, is_match_active: bool = false) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.custom_minimum_size = Vector2(0, 48)

	var sb := StyleBoxFlat.new()
	sb.content_margin_left = 8.0
	sb.content_margin_right = 8.0
	sb.content_margin_top = 6.0
	sb.content_margin_bottom = 6.0
	sb.corner_radius_top_left = 6
	sb.corner_radius_top_right = 6
	sb.corner_radius_bottom_left = 6
	sb.corner_radius_bottom_right = 6
	sb.border_width_left = 2
	sb.border_width_top = 2
	sb.border_width_right = 2
	sb.border_width_bottom = 2

	var name_color := Color(0.30, 0.30, 0.28, 0.70)
	var sub_color := C_GOLD_DIM
	var dim_panel := true

	match slot_type:
		"player":
			sb.bg_color = C_SLOT_PLAYER
			sb.border_color = C_BDR_PLAYER
			name_color = Color(0.65, 0.82, 1.00, 1.00)
			sub_color = Color(0.35, 0.62, 0.90, 0.80)
			dim_panel = false
			_pulse_style(sb, C_BDR_PLAYER, Color(C_BDR_PLAYER.r, C_BDR_PLAYER.g, C_BDR_PLAYER.b, 0.38))
		"player_past":
			sb.bg_color = Color(0.03, 0.05, 0.09, 1.0)
			sb.border_color = Color(0.25, 0.45, 0.68, 0.55)
			name_color = Color(0.48, 0.66, 0.85, 0.80)
			sub_color = Color(0.35, 0.55, 0.78, 0.60)
			dim_panel = false
		"active_opp":
			sb.bg_color = C_SLOT_ACTIVE
			sb.border_color = C_BDR_GOLD
			name_color = C_GOLD
			sub_color = Color(C_BDR_GOLD.r, C_BDR_GOLD.g, C_BDR_GOLD.b, 0.72)
			dim_panel = false
			_pulse_style(sb, C_BDR_GOLD, Color(C_BDR_GOLD.r, C_BDR_GOLD.g, C_BDR_GOLD.b, 0.38))
		"defeated":
			sb.bg_color = Color(0.04, 0.08, 0.04, 1.0)
			sb.border_color = C_BDR_DEFEATED
			name_color = Color(0.42, 0.72, 0.45, 1.0)
			sub_color = Color(0.42, 0.72, 0.45, 0.80)
			dim_panel = false
		_:  # unknown
			sb.bg_color = C_SLOT_DARK
			sb.border_color = C_BDR_DIM

	panel.add_theme_stylebox_override("panel", sb)

	# Dim unknown matches
	if dim_panel:
		panel.modulate.a = 0.5

	# Content layout
	var hbox := HBoxContainer.new()
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	hbox.add_theme_constant_override("separation", 8)
	panel.add_child(hbox)

	if texture != null:
		var portrait := TextureRect.new()
		portrait.texture = texture
		portrait.custom_minimum_size = Vector2(40, 40)
		portrait.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
		portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		hbox.add_child(portrait)

	var text_vbox := VBoxContainer.new()
	text_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	text_vbox.add_theme_constant_override("separation", 1)
	text_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(text_vbox)

	var name_lbl := Label.new()
	name_lbl.text = label
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER if texture == null else HORIZONTAL_ALIGNMENT_LEFT
	name_lbl.add_theme_font_size_override("font_size", 14)
	name_lbl.add_theme_color_override("font_color", name_color)
	name_lbl.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	text_vbox.add_child(name_lbl)

	if sub != "":
		var sub_lbl := Label.new()
		sub_lbl.text = sub
		sub_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER if texture == null else HORIZONTAL_ALIGNMENT_LEFT
		sub_lbl.add_theme_font_size_override("font_size", 10)
		sub_lbl.add_theme_color_override("font_color", sub_color)
		text_vbox.add_child(sub_lbl)

	return panel


# ── Line drawing ─────────────────────────────────────────────────────────────

func _on_draw_lines() -> void:
	var sz := bracket_lines.get_rect().size
	if _vignette:
		bracket_lines.draw_texture_rect(_vignette, Rect2(Vector2.ZERO, sz), false)

	# R1 → SF connectors (4 matches in R1, connecting to 4 SF slots)
	if _r1_slots.size() >= 8 and _sf_slots.size() >= 4:
		for i in 4:
			var slot_a := _r1_slots[i * 2]
			var slot_b := _r1_slots[i * 2 + 1]
			var dest := _sf_slots[i]
			var active := _r1_to_sf_active and i == 0
			_draw_bracket_line(slot_a, slot_b, dest, active)

	# SF → Finals connectors (2 matches in SF, connecting to 2 Finals slots)
	if _sf_slots.size() >= 4 and _fn_slots.size() >= 2:
		for i in 2:
			var slot_a := _sf_slots[i * 2]
			var slot_b := _sf_slots[i * 2 + 1]
			var dest := _fn_slots[i]
			var active := _sf_to_fn_active and i == 0
			_draw_bracket_line(slot_a, slot_b, dest, active)


func _draw_bracket_line(slot_a: PanelContainer, slot_b: PanelContainer,
		dest: PanelContainer, is_active: bool) -> void:
	if not slot_a.is_visible_in_tree() or not slot_b.is_visible_in_tree() or not dest.is_visible_in_tree():
		return

	var lc := C_LINE_LIVE if is_active else C_LINE_DEAD
	var lw := 2.5 if is_active else 1.5

	# Convert global rects to bracket_lines local coords
	var ra := _to_local_rect(slot_a)
	var rb := _to_local_rect(slot_b)
	var rd := _to_local_rect(dest)

	var x_exit := ra.end.x
	var x_enter := rd.position.x
	var x_mid := x_exit + (x_enter - x_exit) * 0.5

	var ya := ra.get_center().y
	var yb := rb.get_center().y
	var yd := rd.get_center().y

	# H-lines from each source slot to junction
	bracket_lines.draw_line(Vector2(x_exit, ya), Vector2(x_mid, ya), lc, lw)
	bracket_lines.draw_line(Vector2(x_exit, yb), Vector2(x_mid, yb), lc, lw)
	# Vertical bracket arm
	bracket_lines.draw_line(Vector2(x_mid, ya), Vector2(x_mid, yb), lc, lw)

	# Midpoint to destination
	var y_junc := (ya + yb) * 0.5
	if is_equal_approx(y_junc, yd):
		bracket_lines.draw_line(Vector2(x_mid, y_junc), Vector2(x_enter, yd), lc, lw)
	else:
		# Orthogonal routing: H → V → H
		var x_pivot := x_mid + (x_enter - x_mid) * 0.5
		bracket_lines.draw_line(Vector2(x_mid, y_junc), Vector2(x_pivot, y_junc), lc, lw)
		bracket_lines.draw_line(Vector2(x_pivot, y_junc), Vector2(x_pivot, yd), lc, lw)
		bracket_lines.draw_line(Vector2(x_pivot, yd), Vector2(x_enter, yd), lc, lw)


func _to_local_rect(ctrl: Control) -> Rect2:
	var global_pos := ctrl.get_global_rect().position
	var local_pos := bracket_lines.get_global_transform().affine_inverse() * global_pos
	return Rect2(local_pos, ctrl.get_global_rect().size)


# ── Helpers ──────────────────────────────────────────────────────────────────

func _get_current_opponent(opp_idx: int) -> Dictionary:
	if opp_idx < GameManager.fight_order.size():
		return GameManager._get_opponent_by_id(GameManager.fight_order[opp_idx])
	return {}


func _load_portrait(sprite_base: String, opponent_data: Dictionary = {}) -> Texture2D:
	if sprite_base == "":
		return null
	# Prefer transparent (_tr) portrait sheet; fall back to opaque sheet
	var folder_sheet_tr := "res://assets/sprites/opponents/%s/%s_sheet_tr.png" % [sprite_base, sprite_base]
	var folder_sheet := "res://assets/sprites/opponents/%s/%s_sheet.png" % [sprite_base, sprite_base]
	var sheet_to_use := folder_sheet_tr if ResourceLoader.exists(folder_sheet_tr) else folder_sheet
	if ResourceLoader.exists(sheet_to_use):
		var hf: int = opponent_data.get("sprite_hframes", 5)
		var portrait := AnimatedPortrait.portrait_from_sheet(sheet_to_use, hf, 2)
		if portrait:
			return portrait
	# Legacy: single sprite_sheet field
	var sheet_path: String = opponent_data.get("sprite_sheet", "")
	if sheet_path != "":
		var portrait := AnimatedPortrait.portrait_from_sheet(sheet_path, 4, 2)
		if portrait:
			return portrait
	var path_64 := "res://assets/sprites/opponents/%s_64.png" % sprite_base
	if ResourceLoader.exists(path_64):
		return load(path_64)
	var path_neutral := "res://assets/sprites/opponents/%s_neutral.png" % sprite_base
	if ResourceLoader.exists(path_neutral):
		return load(path_neutral)
	return null


func _pulse_style(style: StyleBoxFlat, c_hi: Color, c_lo: Color) -> void:
	var tw := create_tween().set_loops()
	tw.tween_method(
		func(t: float) -> void: style.border_color = c_lo.lerp(c_hi, t),
		0.0, 1.0, 1.0
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_method(
		func(t: float) -> void: style.border_color = c_lo.lerp(c_hi, t),
		1.0, 0.0, 1.0
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


func _on_proceed() -> void:
	AudioManager.play_confirm()
	GameManager.start_fight()
