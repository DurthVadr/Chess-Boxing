extends Control

## Opponent Reveal — Dramatic card flip showing opponent info

@onready var card_panel: PanelContainer = %CardPanel
@onready var opponent_name_label: Label = %OpponentNameLabel
@onready var archetype_label: Label = %ArchetypeLabel
@onready var flavor_label: Label = %FlavorLabel
@onready var stats_label: Label = %StatsLabel
@onready var fight_btn: Button = %FightBtn

var reveal_done := false

func _ready() -> void:
	fight_btn.pressed.connect(_on_fight)
	fight_btn.visible = false

	var opp := GameManager.current_opponent
	opponent_name_label.text = opp.get("name", "???")
	archetype_label.text = opp.get("archetype", "unknown").to_upper()
	flavor_label.text = opp.get("flavor_text", "")
	stats_label.text = "HP: %d  |  Stamina: %d" % [opp.get("hp", 80), opp.get("stamina", 90)]

	# Show gimmick if present
	var gimmick = opp.get("gimmick", null)
	if gimmick is Dictionary and not gimmick.is_empty():
		stats_label.text += "\n\n%s: %s" % [gimmick.get("name", ""), gimmick.get("description", "")]

	# Card flip animation
	card_panel.scale = Vector2(0.01, 1.0)
	card_panel.pivot_offset = card_panel.size / 2.0

	var tween := create_tween()
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_BACK)
	tween.tween_property(card_panel, "scale:x", 1.0, 0.5).set_delay(0.3)
	tween.tween_callback(_on_reveal_complete)

func _on_reveal_complete() -> void:
	reveal_done = true
	fight_btn.visible = true
	Juice.scale_bounce(fight_btn, 1.1, 0.3)

func _on_fight() -> void:
	# Start with chess phase (round 0 = chess)
	GameManager.current_round_in_fight = 0
	GameManager.change_phase(GameManager.GamePhase.CHESS)
