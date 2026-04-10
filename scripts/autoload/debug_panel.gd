extends CanvasLayer

## Debug Panel — playtesting shortcuts. Only active in debug builds.
## Toggle with F12. Buttons are context-aware based on the current scene.

const PANEL_W := 200
const PANEL_H_COLLAPSED := 36
const BTN_H := 32
const MARGIN := 6

var _panel: PanelContainer
var _vbox: VBoxContainer
var _header: Button
var _expanded: bool = false

func _ready() -> void:
	if not OS.is_debug_build():
		queue_free()
		return

	layer = 200  # Above CRT (100) and dialogue (90)
	name = "DebugPanel"

	_panel = PanelContainer.new()
	_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	# Position: top-right corner
	_panel.anchor_left   = 1.0
	_panel.anchor_top    = 0.0
	_panel.anchor_right  = 1.0
	_panel.anchor_bottom = 0.0
	_panel.offset_left   = -PANEL_W - 4.0
	_panel.offset_top    = 4.0
	_panel.offset_right  = -4.0
	_panel.offset_bottom = float(PANEL_H_COLLAPSED) + 4.0
	add_child(_panel)

	_vbox = VBoxContainer.new()
	_vbox.add_theme_constant_override("separation", 4)
	_panel.add_child(_vbox)

	# Header toggle button
	_header = Button.new()
	_header.text = "DEV ▼"
	_header.custom_minimum_size = Vector2(PANEL_W - MARGIN * 2, BTN_H - 4)
	_header.add_theme_color_override("font_color", Color(0.4, 1.0, 0.5))
	_header.pressed.connect(_toggle_expanded)
	_vbox.add_child(_header)

	_set_style()


func _input(event: InputEvent) -> void:
	if not OS.is_debug_build():
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_F12:
			_toggle_expanded()


func _toggle_expanded() -> void:
	_expanded = not _expanded
	_header.text = "DEV ▲" if _expanded else "DEV ▼"
	_rebuild_buttons()


func _rebuild_buttons() -> void:
	# Remove all children except header
	for child in _vbox.get_children():
		if child != _header:
			child.queue_free()

	if not _expanded:
		_panel.offset_bottom = _panel.offset_top + float(PANEL_H_COLLAPSED)
		return

	var buttons: Array[Dictionary] = _get_context_buttons()

	for btn_def: Dictionary in buttons:
		var btn := Button.new()
		btn.text = btn_def.get("label", "?")
		btn.custom_minimum_size = Vector2(PANEL_W - MARGIN * 2, BTN_H)
		btn.pressed.connect(btn_def.get("action"))
		_vbox.add_child(btn)

	# Always add a separator + generic buttons
	_add_separator()
	_add_btn("→ Results (Win)",    _go_results_win)
	_add_btn("→ Results (Lose)",   _go_results_lose)
	_add_btn("→ Main Menu",        _go_menu)

	# Resize panel to fit content
	var total_rows: int = 1 + buttons.size() + 1 + 3  # header + ctx + sep + generic
	var height: float = float(total_rows) * (BTN_H + 4) + MARGIN * 2
	_panel.offset_bottom = _panel.offset_top + height


func _get_context_buttons() -> Array[Dictionary]:
	var scene := get_tree().current_scene
	if scene == null:
		return []
	var scene_name := scene.name

	var result: Array[Dictionary] = []

	# Boxing phase
	if scene.has_method("debug_instant_win"):
		result.append({"label": "★ Win Fight (KO)", "action": _instant_win})
		result.append({"label": "✗ Lose Fight (KO)", "action": _instant_lose})

	# Cutscene — only the cutscene scene (not any future scene that adds debug_skip)
	if scene_name == "Cutscene":
		result.append({"label": "⏭ Skip Cutscene", "action": _skip_cutscene})

	# Shop / perk draft — just advance
	if scene_name in ["Shop", "PerkDraft", "MoveUpgrade", "PathFork"]:
		result.append({"label": "⏭ Skip Screen", "action": _skip_screen})

	return result


func _add_btn(label: String, action: Callable) -> void:
	var btn := Button.new()
	btn.text = label
	btn.custom_minimum_size = Vector2(PANEL_W - MARGIN * 2, BTN_H)
	btn.pressed.connect(action)
	_vbox.add_child(btn)


func _add_separator() -> void:
	var sep := HSeparator.new()
	_vbox.add_child(sep)


# ── Context actions ─────────────────────────────────────────────────

func _instant_win() -> void:
	var scene := get_tree().current_scene
	if scene and scene.has_method("debug_instant_win"):
		scene.debug_instant_win()


func _instant_lose() -> void:
	var scene := get_tree().current_scene
	if scene and scene.has_method("debug_instant_lose"):
		scene.debug_instant_lose()


func _skip_cutscene() -> void:
	var scene := get_tree().current_scene
	if scene and scene.has_method("debug_skip"):
		scene.debug_skip()
	elif scene and scene.has_method("force_close"):
		scene.force_close()


func _skip_screen() -> void:
	# Generic skip: try debug_skip, then simulate confirm
	var scene := get_tree().current_scene
	if scene and scene.has_method("debug_skip"):
		scene.debug_skip()


# ── Generic phase jumps ─────────────────────────────────────────────

func _go_results_win() -> void:
	# Make sure the run looks like a win before jumping
	GameManager.stats["fights_won"] = GameManager.total_opponents
	GameManager.change_phase(GameManager.GamePhase.RESULTS)


func _go_results_lose() -> void:
	GameManager.stats["fights_won"] = 0
	GameManager.change_phase(GameManager.GamePhase.RESULTS)


func _go_menu() -> void:
	GameManager.change_phase(GameManager.GamePhase.MENU)


# ── Style ───────────────────────────────────────────────────────────

func _set_style() -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.06, 0.04, 0.10, 0.88)
	style.border_color = Color(0.4, 1.0, 0.5, 0.7)
	style.set_border_width_all(1)
	style.set_corner_radius_all(4)
	style.set_content_margin_all(MARGIN)
	_panel.add_theme_stylebox_override("panel", style)
