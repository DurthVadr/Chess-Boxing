extends Control

## Tournament Bracket — Classic 8-player left-to-right elimination tree

# ── Layout constants ──────────────────────────────────────────────────────────
const SLOT_W    := 118.0   # Width of each fighter slot card
const SLOT_H    := 56.0    # Height of each fighter slot card
const PAIR_GAP  := 8.0     # Gap between the two fighters within one match
const MATCH_GAP := 14.0    # Gap between separate matches in the same column
const CONN_W    := 74.0    # Width of connector zone between columns
const HEADER_H  := 28.0    # Height of column header labels
const BRACKET_TOP := 98.0  # Y where slot content begins (below title + headers)

const COL_LABELS := ["FIRST ROUND", "SEMI FINALS", "FINALS"]

# ── Palette ───────────────────────────────────────────────────────────────────
const C_GOLD      := Color(0.90, 0.78, 0.30, 1.00)
const C_GOLD_DIM  := Color(0.42, 0.36, 0.15, 0.65)
const C_LINE_LIVE := Color(1.00, 0.76, 0.22, 1.00)   # active connector line
const C_LINE_DEAD := Color(0.26, 0.36, 0.22, 0.40)   # inactive connector line
const C_SLOT_PLAYER  := Color(0.04, 0.08, 0.13, 1.00)
const C_SLOT_ACTIVE  := Color(0.12, 0.09, 0.03, 1.00)
const C_SLOT_DARK    := Color(0.03, 0.06, 0.03, 1.00)
const C_BDR_PLAYER   := Color(0.35, 0.62, 0.90, 1.00)
const C_BDR_GOLD     := Color(0.90, 0.78, 0.30, 1.00)
const C_BDR_DIM      := Color(0.22, 0.30, 0.20, 0.40)
const C_BDR_DEFEATED := Color(0.28, 0.55, 0.28, 0.70)

@onready var proceed_btn: Button = %ProceedBtn

# Slot rects in screen-absolute coordinates
var _r1: Array = []   # 8 Rect2 — 4 matches × 2 fighters
var _sf: Array = []   # 4 Rect2 — 2 matches × 2 slots
var _fn: Array = []   # 2 Rect2 — 1 match × 2 slots

var _r1_to_sf_active: bool = false   # true once player has cleared R1
var _sf_to_fn_active: bool = false   # true once player has cleared SF
var _vignette: GradientTexture2D


func _ready() -> void:
	_setup_vignette()
	proceed_btn.pressed.connect(_on_proceed)
	_build_bracket()
	Juice.fade_in(self, 0.4)


func _draw() -> void:
	var sz := get_viewport_rect().size
	if _vignette:
		draw_texture_rect(_vignette, Rect2(Vector2.ZERO, sz), false)
	# R1 → SF connectors (4 connections, one per R1 match)
	for i in 4:
		_draw_connector(_r1[i * 2] as Rect2, _r1[i * 2 + 1] as Rect2, _sf[i] as Rect2, _r1_to_sf_active and i == 0)
	# SF → Final connectors (2 connections, one per SF match)
	for i in 2:
		_draw_connector(_sf[i * 2] as Rect2, _sf[i * 2 + 1] as Rect2, _fn[i] as Rect2, _sf_to_fn_active and i == 0)


# ── Vignette setup ────────────────────────────────────────────────────────────

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


# ── Bracket construction ──────────────────────────────────────────────────────

func _build_bracket() -> void:
	var sw := get_viewport_rect().size.x
	var total_w := SLOT_W * 3.0 + CONN_W * 2.0
	var left := (sw - total_w) * 0.5
	var col_x := [
		left,
		left + SLOT_W + CONN_W,
		left + (SLOT_W + CONN_W) * 2.0,
	]

	var opp_idx: int = GameManager.current_opponent_index
	var finals_idx: int = GameManager.total_opponents - 1
	_r1_to_sf_active = opp_idx >= 1
	_sf_to_fn_active = opp_idx >= finals_idx

	# ── Build slot geometry (positions only) ──
	_r1.clear()
	var match_h := 2.0 * SLOT_H + PAIR_GAP
	for m in 4:
		var mt := m * (match_h + MATCH_GAP)
		for s in 2:
			_r1.append(Rect2(col_x[0], BRACKET_TOP + mt + s * (SLOT_H + PAIR_GAP), SLOT_W, SLOT_H))

	_sf.clear()
	for m in 4:
		var cy: float = ((_r1[m * 2] as Rect2).get_center().y + (_r1[m * 2 + 1] as Rect2).get_center().y) * 0.5
		_sf.append(Rect2(col_x[1], cy - SLOT_H * 0.5, SLOT_W, SLOT_H))

	# Finals: two slots stacked tightly at the vertical center of the whole bracket.
	# The bracket spans from the top of _r1[0] to the bottom of _r1[7].
	_fn.clear()
	var bracket_h: float = 4.0 * (2.0 * SLOT_H + PAIR_GAP) + 3.0 * MATCH_GAP
	var center_y: float = BRACKET_TOP + bracket_h * 0.5
	_fn.append(Rect2(col_x[2], center_y - PAIR_GAP * 0.5 - SLOT_H, SLOT_W, SLOT_H))
	_fn.append(Rect2(col_x[2], center_y + PAIR_GAP * 0.5,           SLOT_W, SLOT_H))

	# ── Collect player + opponent data ──
	var player_name := (GameManager.player_fighter.get("name", "THE ROOKIE") as String).to_upper()
	var cur_opp: Dictionary = GameManager.current_opponent
	var cur_name := (cur_opp.get("name", "???") as String).to_upper()
	var cur_tex: Texture2D = _load_portrait(cur_opp.get("sprite_base", "") as String)

	# Opponents already beaten, in fight order
	var beaten: Array = []
	for i in opp_idx:
		if i < GameManager.fight_order.size():
			beaten.append(GameManager._get_opponent_by_id(GameManager.fight_order[i]))

	# ── R1 slots ──
	# [0] Player: active if opp_idx==0, otherwise shows past result
	# [1] Opponent: current if opp_idx==0, first beaten opponent otherwise
	# [2..7] All ???
	if opp_idx == 0:
		_make_slot(_r1[0], "player",      player_name, "PLAYER")
		_make_slot(_r1[1], "active_opp",  cur_name, "◄ NOW FIGHTING ►", cur_tex)
	else:
		var r1_beaten: Dictionary = beaten[0] if beaten.size() > 0 else {}
		_make_slot(_r1[0], "player_past", player_name, "✓ ADVANCED")
		_make_slot(_r1[1], "defeated",
			(r1_beaten.get("name", "???") as String).to_upper(), "✓ DEFEATED",
			_load_portrait(r1_beaten.get("sprite_base", "") as String))
	for i in range(2, 8):
		_make_slot(_r1[i] as Rect2, "unknown", "???", "")

	# ── SF slots ──
	# [0] Player: active if opp_idx in SF range, past result if beyond SF
	# [1] Opponent: current if opp_idx in SF range, most recent SF beaten if beyond
	# [2..3] All ???
	if opp_idx >= 1 and opp_idx < finals_idx:
		_make_slot(_sf[0], "player",     player_name, "PLAYER")
		_make_slot(_sf[1], "active_opp", cur_name, "◄ NOW FIGHTING ►", cur_tex)
	elif opp_idx >= finals_idx:
		# Show the last SF opponent as defeated (the one just before finals)
		var sf_beaten: Dictionary = beaten[finals_idx - 1] if beaten.size() >= finals_idx else {}
		_make_slot(_sf[0], "player_past", player_name, "✓ ADVANCED")
		_make_slot(_sf[1], "defeated",
			(sf_beaten.get("name", "???") as String).to_upper(), "✓ DEFEATED",
			_load_portrait(sf_beaten.get("sprite_base", "") as String))
	else:
		_make_slot(_sf[0] as Rect2, "unknown", "???", "")
		_make_slot(_sf[1] as Rect2, "unknown", "???", "")
	_make_slot(_sf[2] as Rect2, "unknown", "???", "")
	_make_slot(_sf[3] as Rect2, "unknown", "???", "")

	# ── Final slots ──
	# [0] Player: active if opp_idx == finals_idx
	# [1] Opponent: current if opp_idx == finals_idx
	if opp_idx >= finals_idx:
		_make_slot(_fn[0], "player",     player_name, "PLAYER")
		_make_slot(_fn[1], "active_opp", cur_name, "◄ NOW FIGHTING ►", cur_tex)
	else:
		_make_slot(_fn[0] as Rect2, "unknown", "???", "")
		_make_slot(_fn[1] as Rect2, "unknown", "???", "")

	# ── Column header labels — highlight the active round ──
	# Map opp_idx to column: 0→R1, 1..(finals_idx-1)→SF, finals_idx→Finals
	var active_col: int
	if opp_idx == 0:
		active_col = 0
	elif opp_idx < finals_idx:
		active_col = 1
	else:
		active_col = 2
	for i in 3:
		var lbl := Label.new()
		lbl.text = COL_LABELS[i]
		lbl.add_theme_font_size_override("font_size", 12)
		lbl.add_theme_color_override("font_color", C_GOLD if i == active_col else C_GOLD_DIM)
		lbl.set_position(Vector2(col_x[i], BRACKET_TOP - HEADER_H - 2.0))
		lbl.set_size(Vector2(SLOT_W, HEADER_H))
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		add_child(lbl)

	queue_redraw()


func _make_slot(rect: Rect2, slot_type: String, label: String, sub: String,
		texture: Texture2D = null) -> void:
	var panel := PanelContainer.new()
	panel.set_position(rect.position)
	panel.set_size(rect.size)

	var sb := StyleBoxFlat.new()
	sb.corner_radius_top_left     = 5
	sb.corner_radius_top_right    = 5
	sb.corner_radius_bottom_left  = 5
	sb.corner_radius_bottom_right = 5
	sb.border_width_left   = 2
	sb.border_width_top    = 2
	sb.border_width_right  = 2
	sb.border_width_bottom = 2

	var name_color := Color(0.22, 0.32, 0.20, 0.70)
	var sub_color  := C_GOLD_DIM

	match slot_type:
		"player":
			sb.bg_color     = C_SLOT_PLAYER
			sb.border_color = C_BDR_PLAYER
			name_color = Color(0.65, 0.82, 1.00, 1.00)
			sub_color  = Color(0.35, 0.62, 0.90, 0.80)
			_pulse_style(sb, C_BDR_PLAYER, Color(C_BDR_PLAYER.r, C_BDR_PLAYER.g, C_BDR_PLAYER.b, 0.38))
		"player_past":
			sb.bg_color     = Color(0.03, 0.05, 0.09, 1.0)
			sb.border_color = Color(0.25, 0.45, 0.68, 0.55)
			name_color = Color(0.48, 0.66, 0.85, 0.80)
			sub_color  = Color(0.35, 0.55, 0.78, 0.60)
		"active_opp":
			sb.bg_color     = C_SLOT_ACTIVE
			sb.border_color = C_BDR_GOLD
			name_color = C_GOLD
			sub_color  = Color(C_BDR_GOLD.r, C_BDR_GOLD.g, C_BDR_GOLD.b, 0.72)
			_pulse_style(sb, C_BDR_GOLD, Color(C_BDR_GOLD.r, C_BDR_GOLD.g, C_BDR_GOLD.b, 0.38))
		"defeated":
			sb.bg_color     = Color(0.04, 0.08, 0.04, 1.0)
			sb.border_color = C_BDR_DEFEATED
			name_color = Color(0.42, 0.72, 0.45, 1.0)
			sub_color  = Color(0.42, 0.72, 0.45, 0.80)
		_:  # unknown / ???
			sb.bg_color     = C_SLOT_DARK
			sb.border_color = C_BDR_DIM

	panel.add_theme_stylebox_override("panel", sb)

	# ── Portrait + text layout (HBox) when texture provided, else centered text ──
	if texture != null:
		var hbox := HBoxContainer.new()
		hbox.alignment = BoxContainer.ALIGNMENT_CENTER
		hbox.add_theme_constant_override("separation", 5)
		panel.add_child(hbox)

		var portrait := TextureRect.new()
		portrait.texture = texture
		portrait.custom_minimum_size = Vector2(44.0, 44.0)
		portrait.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
		portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		hbox.add_child(portrait)

		var vbox := VBoxContainer.new()
		vbox.alignment = BoxContainer.ALIGNMENT_CENTER
		vbox.add_theme_constant_override("separation", 2)
		vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		hbox.add_child(vbox)

		var lbl := Label.new()
		lbl.text = label
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		lbl.add_theme_font_size_override("font_size", 10)
		lbl.add_theme_color_override("font_color", name_color)
		lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		vbox.add_child(lbl)

		if sub != "":
			var slbl := Label.new()
			slbl.text = sub
			slbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
			slbl.add_theme_font_size_override("font_size", 8)
			slbl.add_theme_color_override("font_color", sub_color)
			vbox.add_child(slbl)
	else:
		var vbox := VBoxContainer.new()
		vbox.alignment = BoxContainer.ALIGNMENT_CENTER
		vbox.add_theme_constant_override("separation", 2)
		panel.add_child(vbox)

		var lbl := Label.new()
		lbl.text = label
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl.add_theme_font_size_override("font_size", 10)
		lbl.add_theme_color_override("font_color", name_color)
		lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		vbox.add_child(lbl)

		if sub != "":
			var slbl := Label.new()
			slbl.text = sub
			slbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			slbl.add_theme_font_size_override("font_size", 8)
			slbl.add_theme_color_override("font_color", sub_color)
			vbox.add_child(slbl)

	add_child(panel)


# ── Connector line drawing ────────────────────────────────────────────────────

## Draws orthogonal bracket lines from two source slots to one destination slot.
## R1→SF:   y_mid == y_dest (by geometry) → single H-line exit.
## SF→Final: Finals are centered, so y_mid ≠ y_dest → H-V-H converging path.
func _draw_connector(slot_a: Rect2, slot_b: Rect2, dest: Rect2, is_active: bool) -> void:
	var lc := C_LINE_LIVE if is_active else C_LINE_DEAD
	var lw := 2.0 if is_active else 1.5

	var x_right := slot_a.end.x
	var x_left  := dest.position.x
	var x_junc  := x_right + (x_left - x_right) * 0.42  # bracket arm at 42%

	var ya     := slot_a.get_center().y
	var yb     := slot_b.get_center().y
	var y_mid  := (ya + yb) * 0.5
	var y_dest := dest.get_center().y

	# H-lines exiting each source slot
	draw_line(Vector2(x_right, ya), Vector2(x_junc, ya), lc, lw)
	draw_line(Vector2(x_right, yb), Vector2(x_junc, yb), lc, lw)
	# V-line closing the bracket arm
	draw_line(Vector2(x_junc, ya), Vector2(x_junc, yb), lc, lw)

	if is_equal_approx(y_mid, y_dest):
		# R1→SF: destination aligns with midpoint — straight horizontal exit
		draw_line(Vector2(x_junc, y_mid), Vector2(x_left, y_dest), lc, lw)
	else:
		# SF→Final: destination is centered, lines must angle inward.
		# H → V → H so all segments remain orthogonal.
		var x_pivot := x_right + (x_left - x_right) * 0.72
		draw_line(Vector2(x_junc,  y_mid),  Vector2(x_pivot, y_mid),  lc, lw)
		draw_line(Vector2(x_pivot, y_mid),  Vector2(x_pivot, y_dest), lc, lw)
		draw_line(Vector2(x_pivot, y_dest), Vector2(x_left,  y_dest), lc, lw)


# ── Helpers ───────────────────────────────────────────────────────────────────

func _load_portrait(sprite_base: String) -> Texture2D:
	if sprite_base == "":
		return null
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
	GameManager.start_fight()
