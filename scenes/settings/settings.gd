extends Control

## Settings menu — overlay panel with audio, display, and CRT controls.
## Can be opened from main menu or during gameplay (pauses the tree).

signal closed

@onready var panel: PanelContainer = %SettingsPanel
@onready var master_slider: HSlider = %MasterSlider
@onready var master_value: Label = %MasterValue
@onready var music_slider: HSlider = %MusicSlider
@onready var music_value: Label = %MusicValue
@onready var sfx_slider: HSlider = %SFXSlider
@onready var sfx_value: Label = %SFXValue
@onready var crt_toggle: CheckButton = %CRTToggle
@onready var crt_slider: HSlider = %CRTSlider
@onready var crt_value: Label = %CRTValue
@onready var screen_shake_toggle: CheckButton = %ScreenShakeToggle
@onready var fullscreen_toggle: CheckButton = %FullscreenToggle
@onready var back_btn: Button = %BackBtn

var _was_paused: bool = false

func _ready() -> void:
	# Connect controls
	master_slider.value_changed.connect(_on_master_changed)
	music_slider.value_changed.connect(_on_music_changed)
	sfx_slider.value_changed.connect(_on_sfx_changed)
	crt_toggle.toggled.connect(_on_crt_toggled)
	crt_slider.value_changed.connect(_on_crt_intensity_changed)
	screen_shake_toggle.toggled.connect(_on_screen_shake_toggled)
	fullscreen_toggle.toggled.connect(_on_fullscreen_toggled)
	back_btn.pressed.connect(_on_back)

	# Load current settings into controls
	_load_settings_into_ui()

	# Juice
	Juice.fade_in(self, 0.25)
	Juice.scale_bounce(panel, 1.03, 0.3)

func _load_settings_into_ui() -> void:
	var settings := SaveManager.settings

	master_slider.value = settings.get("master_volume", 80)
	music_slider.value = settings.get("music_volume", 80)
	sfx_slider.value = settings.get("sfx_volume", 80)
	crt_toggle.button_pressed = settings.get("crt_enabled", true)
	crt_slider.value = settings.get("crt_intensity", 100)
	crt_slider.editable = crt_toggle.button_pressed
	screen_shake_toggle.button_pressed = settings.get("screen_shake", true)
	fullscreen_toggle.button_pressed = _is_fullscreen()

	_update_value_labels()

func _update_value_labels() -> void:
	master_value.text = "%d%%" % int(master_slider.value)
	music_value.text = "%d%%" % int(music_slider.value)
	sfx_value.text = "%d%%" % int(sfx_slider.value)
	crt_value.text = "%d%%" % int(crt_slider.value)

# --- Audio ---

func _on_master_changed(value: float) -> void:
	var db := _percent_to_db(value)
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Master"), db)
	SaveManager.settings["master_volume"] = value
	_update_value_labels()
	SaveManager.save_data()

func _on_music_changed(value: float) -> void:
	var bus_idx := AudioServer.get_bus_index("Music")
	if bus_idx >= 0:
		AudioServer.set_bus_volume_db(bus_idx, _percent_to_db(value))
	SaveManager.settings["music_volume"] = value
	_update_value_labels()
	SaveManager.save_data()

func _on_sfx_changed(value: float) -> void:
	var bus_idx := AudioServer.get_bus_index("SFX")
	if bus_idx >= 0:
		AudioServer.set_bus_volume_db(bus_idx, _percent_to_db(value))
	SaveManager.settings["sfx_volume"] = value
	_update_value_labels()
	# Play a sample SFX so the user can hear the level
	AudioManager.play_button_click()
	SaveManager.save_data()

# --- Display ---

func _on_crt_toggled(enabled: bool) -> void:
	CRTOverlay.set_enabled(enabled)
	crt_slider.editable = enabled
	SaveManager.settings["crt_enabled"] = enabled
	SaveManager.save_data()

func _on_crt_intensity_changed(value: float) -> void:
	CRTOverlay.set_intensity(value / 100.0)
	SaveManager.settings["crt_intensity"] = value
	crt_value.text = "%d%%" % int(value)
	SaveManager.save_data()

func _on_screen_shake_toggled(enabled: bool) -> void:
	SaveManager.settings["screen_shake"] = enabled
	SaveManager.save_data()

func _on_fullscreen_toggled(enabled: bool) -> void:
	if enabled:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	SaveManager.settings["fullscreen"] = enabled
	SaveManager.save_data()

# --- Navigation ---

func _on_back() -> void:
	AudioManager.play_back()
	closed.emit()
	queue_free()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_on_back()
		get_viewport().set_input_as_handled()

# --- Helpers ---

static func _percent_to_db(percent: float) -> float:
	if percent <= 0:
		return -80.0
	return linear_to_db(percent / 100.0)

static func _is_fullscreen() -> bool:
	return DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN
