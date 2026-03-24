extends Control

## Main Menu — Title screen with New Run / Quit

@onready var title_label: Label = %TitleLabel
@onready var subtitle_label: Label = %SubtitleLabel
@onready var new_run_btn: Button = %NewRunBtn
@onready var quit_btn: Button = %QuitBtn
@onready var crt_overlay: ColorRect = %CRTOverlay

func _ready() -> void:
	new_run_btn.pressed.connect(_on_new_run)
	quit_btn.pressed.connect(_on_quit)

	# Juice: fade in elements
	Juice.fade_in(self, 0.5)
	Juice.scale_bounce(title_label, 1.1, 0.6)

func _on_new_run() -> void:
	GameManager.change_phase(GameManager.GamePhase.FIGHTER_SELECT)

func _on_quit() -> void:
	get_tree().quit()
