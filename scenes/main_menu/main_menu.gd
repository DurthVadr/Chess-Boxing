extends Control

## Main Menu — Arcade-style title screen with sprite cursor, blink, and scrolling bg.

const SETTINGS_SCENE := preload("res://scenes/settings/settings.tscn")

@onready var title_label: Label = %TitleLabel
@onready var subtitle_label: Label = %SubtitleLabel
@onready var new_run_btn: Button = %NewRunBtn
@onready var settings_btn: Button = %SettingsBtn
@onready var quit_btn: Button = %QuitBtn
@onready var cursor: Label = %Cursor

var _buttons: Array = []
var _focused_index := 0
var _blink_timer := 0.0
var _blink_visible := true

func _ready() -> void:
	_buttons = [new_run_btn, settings_btn, quit_btn]

	new_run_btn.pressed.connect(_on_new_run)
	settings_btn.pressed.connect(_on_settings)
	quit_btn.pressed.connect(_on_quit)

	for i in _buttons.size():
		_buttons[i].focus_entered.connect(_on_btn_focus.bind(i))
		_buttons[i].mouse_entered.connect(_buttons[i].grab_focus)

	subtitle_label.text = "— Tournament %d  |  ELO: %d —" % [
		SaveManager.tournament_number,
		SaveManager.player_elo,
	]

	Juice.fade_in(self, 0.5)
	Juice.scale_bounce(title_label, 1.1, 0.6)

	# Wait two frames so layout is fully computed before positioning cursor
	await get_tree().process_frame
	await get_tree().process_frame
	new_run_btn.grab_focus()

func _process(delta: float) -> void:
	_blink_timer += delta
	if _blink_timer >= 0.5:
		_blink_timer = 0.0
		_blink_visible = !_blink_visible
		_buttons[_focused_index].modulate.a = 1.0 if _blink_visible else 0.2

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_down"):
		_buttons[(_focused_index + 1) % _buttons.size()].grab_focus()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_up"):
		_buttons[(_focused_index - 1 + _buttons.size()) % _buttons.size()].grab_focus()
		get_viewport().set_input_as_handled()

func _on_btn_focus(index: int) -> void:
	_buttons[_focused_index].modulate.a = 1.0  # restore previous button
	_focused_index = index
	_blink_timer = 0.0
	_blink_visible = true
	_move_cursor_to(index)

func _move_cursor_to(index: int) -> void:
	var btn: Button = _buttons[index]
	# Snap X immediately; tween Y for the sliding effect
	cursor.global_position.x = btn.global_position.x - cursor.size.x - 14.0
	var target_y := btn.global_position.y + btn.size.y * 0.5 - cursor.size.y * 0.5
	var tw := create_tween()
	tw.tween_property(cursor, "global_position:y", target_y, 0.12) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func _on_new_run() -> void:
	AudioManager.play_confirm()
	GameManager.change_phase(GameManager.GamePhase.FIGHTER_SELECT)

func _on_settings() -> void:
	AudioManager.play_button_click()
	var settings_panel := SETTINGS_SCENE.instantiate()
	add_child(settings_panel)

func _on_quit() -> void:
	AudioManager.play_back()
	get_tree().quit()
