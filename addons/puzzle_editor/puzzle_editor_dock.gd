@tool
extends Control

## Dock UI: browse puzzles by pool (easy/medium/hard) and fight filter; CRUD + JSON save.

const POOL_PATHS := {
	"easy": "res://data/puzzles/puzzles_easy.json",
	"medium": "res://data/puzzles/puzzles_medium.json",
	"hard": "res://data/puzzles/puzzles_hard.json",
}
const OPPONENTS_PATH := "res://data/opponents.json"

var _plugin: EditorPlugin

var _last_fight_idx: int = 0

var _pools: Dictionary = {"easy": [], "medium": [], "hard": []}
var _current_pool: String = "easy"
var _selected_index: int = -1
var _dirty: bool = false

var _opponents: Array = []

var _fight_filter: OptionButton
var _pool_option: OptionButton
var _puzzle_list: ItemList
var _status_label: Label

var _id_edit: LineEdit
var _fen_edit: LineEdit
var _solution_edit: TextEdit
var _themes_edit: LineEdit
var _description_edit: TextEdit
var _difficulty_spin: SpinBox
var _source_edit: LineEdit

var _info_label: Label


func setup(plugin: EditorPlugin) -> void:
	_plugin = plugin


func _ready() -> void:
	name = "Puzzles"
	set_anchors_preset(Control.PRESET_FULL_RECT)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	_build_ui()
	_load_opponents()
	_load_all_pools()
	_refresh_fight_filter()
	_refresh_pool_ui()
	_connect_fields()


func _build_ui() -> void:
	var root := VBoxContainer.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(root)

	_info_label = Label.new()
	_info_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_info_label.text = "Pools map to fights: easy = chess_difficulty 1–2, medium = 3–4, hard = 5+."
	root.add_child(_info_label)

	var fight_row := HBoxContainer.new()
	fight_row.add_child(Label.new())
	fight_row.get_child(0).text = "Fight filter"
	_fight_filter = OptionButton.new()
	_fight_filter.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_fight_filter.item_selected.connect(_on_fight_filter_changed)
	fight_row.add_child(_fight_filter)
	root.add_child(fight_row)

	var pool_row := HBoxContainer.new()
	pool_row.add_child(Label.new())
	pool_row.get_child(0).text = "Pool"
	_pool_option = OptionButton.new()
	_pool_option.add_item("Easy (difficulty 1–2)", 0)
	_pool_option.add_item("Medium (difficulty 3–4)", 1)
	_pool_option.add_item("Hard (difficulty 5+)", 2)
	_pool_option.item_selected.connect(_on_pool_selected)
	pool_row.add_child(_pool_option)
	root.add_child(pool_row)

	_puzzle_list = ItemList.new()
	_puzzle_list.custom_minimum_size = Vector2(0, 180)
	_puzzle_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_puzzle_list.item_selected.connect(_on_puzzle_list_selected)
	root.add_child(_puzzle_list)

	var btn_row := HBoxContainer.new()
	for label_text in ["Reload", "Save", "New", "Duplicate", "Delete"]:
		var b := Button.new()
		b.text = label_text
		btn_row.add_child(b)
		match label_text:
			"Reload":
				b.pressed.connect(_on_reload_pressed)
			"Save":
				b.pressed.connect(_on_save_pressed)
			"New":
				b.pressed.connect(_on_new_pressed)
			"Duplicate":
				b.pressed.connect(_on_duplicate_pressed)
			"Delete":
				b.pressed.connect(_on_delete_pressed)
	root.add_child(btn_row)

	_status_label = Label.new()
	_status_label.text = "Ready."
	root.add_child(_status_label)

	var form := GridContainer.new()
	form.columns = 2
	form.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root.add_child(form)

	_add_form_row(form, "id", _make_line_edit_ref(Callable(self, "_set_id_edit")))
	_add_form_row(form, "fen", _make_line_edit_ref(Callable(self, "_set_fen_edit")))
	_add_form_row(form, "solution (UCI, space or newline)", _make_text_edit_ref(Callable(self, "_set_solution_edit"), Vector2(0, 72)))
	_add_form_row(form, "themes (comma-separated)", _make_line_edit_ref(Callable(self, "_set_themes_edit")))
	_add_form_row(form, "description", _make_text_edit_ref(Callable(self, "_set_description_edit"), Vector2(0, 56)))
	_add_form_row(form, "difficulty", _make_spin_ref(Callable(self, "_set_difficulty_spin")))
	_add_form_row(form, "source", _make_line_edit_ref(Callable(self, "_set_source_edit")))


func _make_line_edit_ref(setter: Callable) -> LineEdit:
	var le := LineEdit.new()
	setter.call(le)
	le.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return le


func _set_id_edit(le: LineEdit) -> void:
	_id_edit = le


func _set_fen_edit(le: LineEdit) -> void:
	_fen_edit = le


func _set_themes_edit(le: LineEdit) -> void:
	_themes_edit = le


func _set_source_edit(le: LineEdit) -> void:
	_source_edit = le


func _make_text_edit_ref(setter: Callable, min_sz: Vector2) -> TextEdit:
	var te := TextEdit.new()
	setter.call(te)
	te.custom_minimum_size = min_sz
	te.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return te


func _set_solution_edit(te: TextEdit) -> void:
	_solution_edit = te


func _set_description_edit(te: TextEdit) -> void:
	_description_edit = te


func _make_spin_ref(setter: Callable) -> SpinBox:
	var sb := SpinBox.new()
	sb.min_value = 1
	sb.max_value = 10
	sb.value = 1
	setter.call(sb)
	sb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return sb


func _set_difficulty_spin(sb: SpinBox) -> void:
	_difficulty_spin = sb


func _add_form_row(grid: GridContainer, title: String, field: Control) -> void:
	var la := Label.new()
	la.text = title
	grid.add_child(la)
	grid.add_child(field)


func _connect_fields() -> void:
	for node in [_id_edit, _fen_edit, _solution_edit, _themes_edit, _description_edit, _difficulty_spin, _source_edit]:
		if node is LineEdit:
			(node as LineEdit).text_changed.connect(_mark_dirty.unbind(1))
		elif node is TextEdit:
			(node as TextEdit).text_changed.connect(_mark_dirty)
		elif node is SpinBox:
			(node as SpinBox).value_changed.connect(_mark_dirty.unbind(1))


func _mark_dirty(_arg = null) -> void:
	_dirty = true
	_status_label.text = "Unsaved changes"
	_status_label.add_theme_color_override("font_color", Color(1.0, 0.65, 0.35))


func _clear_dirty_status() -> void:
	_dirty = false
	_status_label.text = "Saved."
	_status_label.remove_theme_color_override("font_color")


func _load_opponents() -> void:
	_opponents = _load_json_array(OPPONENTS_PATH)


func _load_json_array(path: String) -> Array:
	if not FileAccess.file_exists(path):
		push_warning("Puzzle editor: missing %s" % path)
		return []
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return []
	var txt := f.get_as_text()
	f.close()
	var j := JSON.new()
	if j.parse(txt) != OK:
		return []
	if j.data is Array:
		return j.data
	return []


func _load_all_pools() -> void:
	for key in POOL_PATHS:
		_pools[key] = _load_json_array(POOL_PATHS[key])


func _refresh_fight_filter() -> void:
	_fight_filter.clear()
	_fight_filter.add_item("All fights (no auto pool)", -1)
	for opp in _opponents:
		if not opp is Dictionary:
			continue
		var pos: int = int(opp.get("fight_position", 0))
		var nm: String = str(opp.get("name", "?"))
		var cd: int = int(opp.get("chess_difficulty", 1))
		var pool := chess_difficulty_to_pool(cd)
		_fight_filter.add_item("%d. %s → %s" % [pos, nm, pool], -1)


static func chess_difficulty_to_pool(cd: int) -> String:
	if cd <= 2:
		return "easy"
	if cd <= 4:
		return "medium"
	return "hard"


func _on_fight_filter_changed(idx: int) -> void:
	if idx <= 0:
		_last_fight_idx = idx
		return
	var opp: Dictionary = _opponents[idx - 1]
	var cd: int = int(opp.get("chess_difficulty", 1))
	var pool := chess_difficulty_to_pool(cd)
	match pool:
		"easy":
			_pool_option.select(0)
		"medium":
			_pool_option.select(1)
		"hard":
			_pool_option.select(2)
	if not _switch_pool(pool):
		_fight_filter.select(_last_fight_idx)
		return
	_last_fight_idx = idx


func _on_pool_selected(idx: int) -> void:
	var pool := "easy"
	match idx:
		0:
			pool = "easy"
		1:
			pool = "medium"
		2:
			pool = "hard"
	if not _switch_pool(pool):
		_sync_pool_option()


func _switch_pool(pool: String) -> bool:
	if _dirty:
		_status_label.text = "Save or Reload before changing pool."
		_status_label.add_theme_color_override("font_color", Color(1.0, 0.45, 0.45))
		_sync_pool_option()
		return false
	_current_pool = pool
	_selected_index = -1
	_clear_form()
	_refresh_puzzle_list()
	_clear_dirty_status()
	_status_label.text = "Pool: %s" % pool
	return true


func _sync_pool_option() -> void:
	match _current_pool:
		"easy":
			_pool_option.select(0)
		"medium":
			_pool_option.select(1)
		"hard":
			_pool_option.select(2)


func _refresh_pool_ui() -> void:
	_sync_pool_option()
	_refresh_puzzle_list()


func _current_array() -> Array:
	return _pools[_current_pool]


func _refresh_puzzle_list() -> void:
	_puzzle_list.set_block_signals(true)
	_puzzle_list.clear()
	var arr: Array = _current_array()
	for i in arr.size():
		var p: Dictionary = arr[i]
		var pid: String = str(p.get("id", "?"))
		var desc: String = str(p.get("description", ""))
		if desc.length() > 48:
			desc = desc.substr(0, 45) + "..."
		_puzzle_list.add_item("%s — %s" % [pid, desc])
	_puzzle_list.deselect_all()
	_puzzle_list.set_block_signals(false)


func _on_puzzle_list_selected(idx: int) -> void:
	if idx < 0:
		return
	if _dirty:
		_status_label.text = "Save or Reload before selecting another puzzle."
		_status_label.add_theme_color_override("font_color", Color(1.0, 0.45, 0.45))
		if _selected_index >= 0:
			_puzzle_list.set_block_signals(true)
			_puzzle_list.select(_selected_index)
			_puzzle_list.set_block_signals(false)
		return
	_selected_index = idx
	_load_puzzle_into_form(_current_array()[idx])


func _load_puzzle_into_form(p: Dictionary) -> void:
	_id_edit.text = str(p.get("id", ""))
	_fen_edit.text = str(p.get("fen", ""))
	var sol: Array = p.get("solution", [])
	var sol_lines: PackedStringArray = []
	for m in sol:
		sol_lines.append(str(m))
	_solution_edit.text = "\n".join(sol_lines)
	var themes: Array = p.get("themes", [])
	_themes_edit.text = ", ".join(themes)
	_description_edit.text = str(p.get("description", ""))
	_difficulty_spin.value = float(p.get("difficulty", 1))
	_source_edit.text = str(p.get("source", "local"))


func _clear_form() -> void:
	_id_edit.text = ""
	_fen_edit.text = ""
	_solution_edit.text = ""
	_themes_edit.text = ""
	_description_edit.text = ""
	_difficulty_spin.value = 1.0
	_source_edit.text = "local"
	_selected_index = -1


func _read_form_into_dict() -> Dictionary:
	var sol_text: String = _solution_edit.text.strip_edges()
	var moves: Array = []
	for part in sol_text.split("\n"):
		for w in part.split(" ", false):
			var mv := w.strip_edges()
			if mv != "":
				moves.append(mv)
	var themes: Array = []
	for t in _themes_edit.text.split(","):
		var s := t.strip_edges()
		if s != "":
			themes.append(s)
	return {
		"id": _id_edit.text.strip_edges(),
		"fen": _fen_edit.text.strip_edges(),
		"solution": moves,
		"themes": themes,
		"description": _description_edit.text,
		"difficulty": int(_difficulty_spin.value),
		"source": _source_edit.text.strip_edges() if _source_edit.text.strip_edges() != "" else "local",
	}


func _on_save_pressed() -> void:
	if _selected_index < 0:
		_status_label.text = "Select a puzzle or create New first."
		return
	var err := _validate_current()
	if err != "":
		_status_label.text = "Cannot save: %s" % err
		_status_label.add_theme_color_override("font_color", Color(1.0, 0.45, 0.45))
		return
	var arr: Array = _current_array()
	if _selected_index >= arr.size():
		return
	arr[_selected_index] = _read_form_into_dict()
	_save_pool_file(_current_pool)
	_clear_dirty_status()
	_refresh_puzzle_list()
	_puzzle_list.select(_selected_index)
	_notify_fs()


func _on_reload_pressed() -> void:
	_load_all_pools()
	_selected_index = -1
	_clear_form()
	_refresh_puzzle_list()
	_clear_dirty_status()
	_status_label.text = "Reloaded from disk."


func _on_new_pressed() -> void:
	if _dirty:
		_status_label.text = "Save or Reload first."
		return
	var nid := _next_puzzle_id()
	var blank := {
		"id": nid,
		"fen": "rnbqkbnr/pppppppp/8/8/4P3/8/PPPP1PPP/RNBQKBNR b KQkq e3 0 1",
		"solution": ["e7e5"],
		"themes": ["opening"],
		"difficulty": 1,
		"description": "New puzzle",
		"source": "local",
	}
	_current_array().append(blank)
	_selected_index = _current_array().size() - 1
	_save_pool_file(_current_pool)
	_refresh_puzzle_list()
	_puzzle_list.select(_selected_index)
	_load_puzzle_into_form(blank)
	_clear_dirty_status()
	_notify_fs()
	_status_label.text = "Created %s (saved)." % nid


func _on_duplicate_pressed() -> void:
	if _selected_index < 0:
		return
	var verr := _validate_current()
	if verr != "":
		_status_label.text = "Fix puzzle before duplicate: %s" % verr
		_status_label.add_theme_color_override("font_color", Color(1.0, 0.45, 0.45))
		return
	var copy: Dictionary = _read_form_into_dict()
	copy["id"] = _next_puzzle_id()
	_current_array().append(copy)
	_save_pool_file(_current_pool)
	_selected_index = _current_array().size() - 1
	_refresh_puzzle_list()
	_puzzle_list.select(_selected_index)
	_load_puzzle_into_form(copy)
	_clear_dirty_status()
	_notify_fs()


func _on_delete_pressed() -> void:
	if _selected_index < 0:
		return
	var arr: Array = _current_array()
	arr.remove_at(_selected_index)
	_save_pool_file(_current_pool)
	_selected_index = -1
	_clear_form()
	_refresh_puzzle_list()
	_clear_dirty_status()
	_notify_fs()
	_status_label.text = "Deleted puzzle."


func _next_puzzle_id() -> String:
	var max_n := 0
	for pool in _pools.values():
		for p in pool:
			var id: String = str(p.get("id", ""))
			if id.begins_with("puzzle_"):
				var rest := id.substr(7)
				if rest.is_valid_int():
					max_n = maxi(max_n, int(rest))
	return "puzzle_%03d" % (max_n + 1)


func _save_pool_file(pool: String) -> void:
	var path: String = POOL_PATHS[pool]
	var data: Array = _pools[pool]
	var json_text := JSON.stringify(data, "\t")
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		push_error("Puzzle editor: cannot write %s" % path)
		return
	f.store_string(json_text)
	f.close()


func _notify_fs() -> void:
	if _plugin:
		var iface := _plugin.get_editor_interface()
		if iface:
			iface.get_resource_filesystem().scan()


func _validate_current() -> String:
	var p := _read_form_into_dict()
	if str(p.get("id", "")).is_empty():
		return "id is empty"
	if str(p.get("fen", "")).is_empty():
		return "fen is empty"
	var sol: Array = p.get("solution", [])
	if sol.is_empty():
		return "solution is empty"
	for m in sol:
		var u := str(m)
		if u.length() < 4 or u.length() > 5:
			return "invalid UCI move: %s" % u
	return ""
