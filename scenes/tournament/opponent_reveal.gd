extends Control

## Opponent Reveal — Retro fighting game VS screen with split-screen layout.
## Player slides from left, opponent from right, VS slams center, then FIGHT fades in.

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
	# Hide button via alpha (not visibility) so it keeps layout space
	fight_btn.modulate.a = 0.0
	fight_btn.disabled = true

	var opp := GameManager.current_opponent
	var player := GameManager.player_fighter

	# ── Player info ──
	player_name_label.text = player.get("name", "The Rookie")
	player_class_label.text = "CHALLENGER"
	player_stats_label.text = "HP: %d" % GameManager.player_max_hp

	var player_sprite: String = player.get("sprite_base", "")
	if player_sprite != "":
		var player_sheet_tr := "res://assets/sprites/fighters/%s/%s_sheet_tr.png" % [player_sprite, player_sprite]
		var player_sheet_portrait := AnimatedPortrait.portrait_from_sheet(player_sheet_tr, 5, 2) if ResourceLoader.exists(player_sheet_tr) else null
		if player_sheet_portrait:
			player_portrait.texture = player_sheet_portrait
		else:
			var player_tex := "res://assets/sprites/fighters/%s_neutral.png" % player_sprite
			if ResourceLoader.exists(player_tex):
				player_portrait.texture = load(player_tex)

	# ── Opponent info ──
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

	opponent_portrait.flip_h = true   # face the player on the VS screen
	var sprite_base: String = opp.get("sprite_base", "")
	var folder_sheet_tr := "res://assets/sprites/opponents/%s/%s_sheet_tr.png" % [sprite_base, sprite_base]
	var folder_sheet := "res://assets/sprites/opponents/%s/%s_sheet.png" % [sprite_base, sprite_base]
	var sheet_to_use := folder_sheet_tr if ResourceLoader.exists(folder_sheet_tr) else folder_sheet
	if sprite_base != "" and ResourceLoader.exists(sheet_to_use):
		var hf: int = opp.get("sprite_hframes", 5)
		var portrait := AnimatedPortrait.portrait_from_sheet(sheet_to_use, hf, 2)
		if portrait:
			opponent_portrait.texture = portrait
	else:
		var sheet_path: String = opp.get("sprite_sheet", "")
		if sheet_path != "":
			var portrait := AnimatedPortrait.portrait_from_sheet(sheet_path, 4, 2)
			if portrait:
				opponent_portrait.texture = portrait
		elif sprite_base != "":
			var tex_path := "res://assets/sprites/opponents/%s_neutral.png" % sprite_base
			if ResourceLoader.exists(tex_path):
				opponent_portrait.texture = load(tex_path)

	_animate_reveal()


func _animate_reveal() -> void:
	var sw := get_viewport_rect().size.x

	# ── Player slides in from off-screen left ──
	player_side.modulate.a = 0.0
	var player_rest_x := player_side.position.x
	player_side.position.x = -sw * 0.5
	var tw_p := create_tween()
	tw_p.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_EXPO)
	tw_p.tween_callback(func(): AudioManager.play_sfx_varied(AudioManager.sfx_whoosh, -8.0))
	tw_p.tween_property(player_side, "position:x", player_rest_x, 0.7)
	tw_p.parallel().tween_property(player_side, "modulate:a", 1.0, 0.35)

	# ── Opponent slides in from off-screen right ──
	opponent_side.modulate.a = 0.0
	var opp_rest_x := opponent_side.position.x
	opponent_side.position.x = sw * 1.2
	var tw_o := create_tween()
	tw_o.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_EXPO)
	tw_o.tween_callback(func(): AudioManager.play_sfx_varied(AudioManager.sfx_whoosh, -8.0)).set_delay(0.12)
	tw_o.tween_property(opponent_side, "position:x", opp_rest_x, 0.7)
	tw_o.parallel().tween_property(opponent_side, "modulate:a", 1.0, 0.35)

	# ── VS slams in from massive scale ──
	vs_label.modulate.a = 0.0
	vs_label.scale = Vector2(3.5, 3.5)
	vs_label.pivot_offset = vs_label.size * 0.5
	var tw_vs := create_tween()
	tw_vs.tween_interval(0.5)
	# Fast slam with elastic overshoot
	tw_vs.tween_property(vs_label, "modulate:a", 1.0, 0.1)
	tw_vs.parallel().tween_property(vs_label, "scale", Vector2.ONE, 0.4) \
		.set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	tw_vs.tween_callback(func():
		Juice.screen_shake(self, 16.0, 0.3)
		Juice.screen_flash(self, Color(1, 1, 1, 0.4), 0.2)
		AudioManager.play_sfx(AudioManager.sfx_sub_drop, -2.0)
	)

	# ── FIGHT button fades in after everything settles ──
	tw_vs.tween_interval(0.5)
	tw_vs.tween_callback(_on_reveal_complete)


func _on_reveal_complete() -> void:
	reveal_done = true
	fight_btn.disabled = false
	var tw := create_tween()
	tw.tween_property(fight_btn, "modulate:a", 1.0, 0.35) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_callback(func():
		AudioManager.play_reveal()
		Juice.scale_bounce(fight_btn, 1.15, 0.3)
	)


func _on_fight() -> void:
	AudioManager.play_fight_start()
	GameManager.current_round_in_fight = 0
	GameManager.change_phase(GameManager.GamePhase.BOXING)
