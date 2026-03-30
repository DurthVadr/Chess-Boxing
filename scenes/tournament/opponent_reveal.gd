extends Control

## Opponent Reveal — Retro fighting game VS screen with split-screen layout

@onready var player_portrait: TextureRect = %PlayerPortrait
@onready var player_name_label: Label = %PlayerNameLabel
@onready var player_class_label: Label = %PlayerClassLabel
@onready var player_stats_label: Label = %PlayerStatsLabel
@onready var opponent_portrait: TextureRect = %OpponentPortrait
@onready var opponent_name_label: Label = %OpponentNameLabel
@onready var archetype_label: Label = %ArchetypeLabel
@onready var stats_label: Label = %StatsLabel
@onready var gimmick_label: Label = %GimmickLabel
@onready var flavor_label: Label = %FlavorLabel
@onready var vs_label: Label = %VSLabel
@onready var fight_btn: Button = %FightBtn
@onready var player_side: VBoxContainer = %PlayerSide
@onready var opponent_side: VBoxContainer = %OpponentSide

var reveal_done := false

func _ready() -> void:
	fight_btn.pressed.connect(_on_fight)
	fight_btn.visible = false

	var opp := GameManager.current_opponent
	var player := GameManager.player_fighter

	# ── Player info ──────────────────────────────────────────────────────────
	player_name_label.text = player.get("name", "The Rookie")
	player_class_label.text = "CHALLENGER"
	player_stats_label.text = "HP: %d" % GameManager.player_max_hp

	var player_sprite: String = player.get("sprite_base", "")
	if player_sprite != "":
		var player_tex := "res://assets/sprites/fighters/%s_neutral.png" % player_sprite
		if ResourceLoader.exists(player_tex):
			player_portrait.texture = load(player_tex)

	# ── Opponent info ────────────────────────────────────────────────────────
	opponent_name_label.text = opp.get("name", "???")
	archetype_label.text = opp.get("archetype", "unknown").to_upper()
	stats_label.text = "HP: %d" % opp.get("hp", 80)
	flavor_label.text = opp.get("flavor_text", "")

	var gimmick = opp.get("gimmick", null)
	if gimmick is Dictionary and not gimmick.is_empty():
		gimmick_label.text = "%s — %s" % [gimmick.get("name", ""), gimmick.get("description", "")]
		gimmick_label.visible = true
	else:
		gimmick_label.visible = false

	var sprite_base: String = opp.get("sprite_base", "")
	if sprite_base != "":
		var tex_path := "res://assets/sprites/opponents/%s_neutral.png" % sprite_base
		if ResourceLoader.exists(tex_path):
			opponent_portrait.texture = load(tex_path)

	_animate_reveal()


func _animate_reveal() -> void:
	# ── Slide player in from left ────────────────────────────────────────────
	player_side.modulate.a = 0.0
	var player_offset := player_side.position.x
	player_side.position.x -= 500
	var tw_p := create_tween()
	tw_p.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	tw_p.tween_callback(func(): AudioManager.play_sfx_varied(AudioManager.sfx_whoosh, -8.0))
	tw_p.tween_property(player_side, "position:x", player_offset, 0.6)
	tw_p.parallel().tween_property(player_side, "modulate:a", 1.0, 0.3)

	# ── Slide opponent in from right ─────────────────────────────────────────
	opponent_side.modulate.a = 0.0
	var opp_offset := opponent_side.position.x
	opponent_side.position.x += 500
	var tw_o := create_tween()
	tw_o.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	tw_o.tween_callback(func(): AudioManager.play_sfx_varied(AudioManager.sfx_whoosh, -8.0)).set_delay(0.15)
	tw_o.tween_property(opponent_side, "position:x", opp_offset, 0.6)
	tw_o.parallel().tween_property(opponent_side, "modulate:a", 1.0, 0.3)

	# ── VS slams in with scale pop ───────────────────────────────────────────
	vs_label.modulate.a = 0.0
	vs_label.scale = Vector2(4.0, 4.0)
	vs_label.pivot_offset = vs_label.size / 2.0
	var tw_vs := create_tween()
	tw_vs.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	tw_vs.tween_interval(0.55)
	tw_vs.tween_property(vs_label, "modulate:a", 1.0, 0.15)
	tw_vs.parallel().tween_property(vs_label, "scale", Vector2.ONE, 0.35)
	tw_vs.tween_callback(func():
		Juice.screen_shake(self, 14.0, 0.25)
		Juice.screen_flash(self, Color(1, 1, 1, 0.35), 0.2)
		AudioManager.play_sfx(AudioManager.sfx_sub_drop, -2.0)
	)
	tw_vs.tween_callback(_on_reveal_complete).set_delay(0.6)


func _on_reveal_complete() -> void:
	reveal_done = true
	fight_btn.visible = true
	AudioManager.play_reveal()
	Juice.scale_bounce(fight_btn, 1.15, 0.3)


func _on_fight() -> void:
	AudioManager.play_fight_start()
	GameManager.current_round_in_fight = 0
	GameManager.change_phase(GameManager.GamePhase.CHESS)
