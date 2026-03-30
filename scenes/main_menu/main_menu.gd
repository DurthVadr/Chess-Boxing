extends Control

## Main Menu — Title screen with New Run / Settings / Quit

const SETTINGS_SCENE := preload("res://scenes/settings/settings.tscn")

@onready var title_label: Label = %TitleLabel
@onready var subtitle_label: Label = %SubtitleLabel
@onready var new_run_btn: Button = %NewRunBtn
@onready var settings_btn: Button = %SettingsBtn
@onready var quit_btn: Button = %QuitBtn

func _ready() -> void:
	new_run_btn.pressed.connect(_on_new_run)
	settings_btn.pressed.connect(_on_settings)
	quit_btn.pressed.connect(_on_quit)

	# Juice: fade in elements
	Juice.fade_in(self, 0.5)
	Juice.scale_bounce(title_label, 1.1, 0.6)

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
