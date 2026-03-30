extends Node

## SFX playback manager — preloads all game sounds and exposes named play methods.
## Uses a pool of AudioStreamPlayers on the "SFX" bus.

var sfx_players: Array[AudioStreamPlayer] = []
const MAX_SFX_PLAYERS := 12

# ── Sound base path ──
const SFX_ROOT := "res://assets/sounds/Shapeforms Audio Free Sound Effects/Shapeforms Audio Free Sound Effects/"

# ── Preloaded sounds ──
# Boxing — punches
var sfx_jab: AudioStream
var sfx_cross: AudioStream
var sfx_hook: AudioStream
var sfx_uppercut: AudioStream
var sfx_punch_heavy: AudioStream
var sfx_punch_critical: AudioStream
var sfx_whoosh: AudioStream
var sfx_whoosh_light: AudioStream

# Boxing — defense
var sfx_block: AudioStream
var sfx_dodge: AudioStream
var sfx_dodge_smooth: AudioStream
var sfx_perfect_block: AudioStream
var sfx_miss: AudioStream
var sfx_hit_taken: AudioStream

# Boxing — clinch
var sfx_clinch_struggle: AudioStream
var sfx_clinch_won: AudioStream
var sfx_clinch_lost: AudioStream

# QTE
var sfx_qte_appear: AudioStream
var sfx_qte_perfect: AudioStream
var sfx_qte_good: AudioStream
var sfx_qte_fail: AudioStream
var sfx_qte_tick: AudioStream

# UI — general
var sfx_button_click: AudioStream
var sfx_button_hover: AudioStream
var sfx_navigate: AudioStream
var sfx_error: AudioStream
var sfx_confirm: AudioStream
var sfx_back: AudioStream

# Chess
var sfx_piece_move: AudioStream
var sfx_piece_capture: AudioStream
var sfx_puzzle_solved: AudioStream
var sfx_puzzle_failed: AudioStream
var sfx_chess_check: AudioStream

# Game flow
var sfx_fight_start: AudioStream
var sfx_round_bell: AudioStream
var sfx_ko: AudioStream
var sfx_victory: AudioStream
var sfx_defeat: AudioStream
var sfx_sub_drop: AudioStream

# Shop / draft
var sfx_coin_spend: AudioStream
var sfx_coin_earn: AudioStream
var sfx_perk_draft: AudioStream
var sfx_card_play: AudioStream
var sfx_shop_buy: AudioStream

# Transitions
var sfx_transition_in: AudioStream
var sfx_transition_out: AudioStream
var sfx_reveal: AudioStream


func _ready() -> void:
	for i in MAX_SFX_PLAYERS:
		var player := AudioStreamPlayer.new()
		player.bus = "SFX"
		add_child(player)
		sfx_players.append(player)

	_preload_all()


func _preload_all() -> void:
	# ── Boxing punches ──
	sfx_jab = _load("Hit and Punch Preview/AUDIO/PUNCH_CLEAN_HEAVY_10.wav")
	sfx_cross = _load("Hit and Punch Preview/AUDIO/PUNCH_PERCUSSIVE_HEAVY_08.wav")
	sfx_hook = _load("Hit and Punch Preview/AUDIO/PUNCH_DESIGNED_HEAVY_74.wav")
	sfx_uppercut = _load("Hit and Punch Preview/AUDIO/PUNCH_INTENSE_HEAVY_03.wav")
	sfx_punch_heavy = _load("Hit and Punch Preview/AUDIO/PUNCH_DESIGNED_HEAVY_86.wav")
	sfx_punch_critical = _load("Hit and Punch Preview/AUDIO/PUNCH_ELECTRIC_HEAVY_02.wav")
	sfx_whoosh = _load("Hit and Punch Preview/AUDIO/WHOOSH_ARM_SWING_01_WIDE.wav")
	sfx_whoosh_light = _load("Hit and Punch Preview/AUDIO/WHOOSH_AIRY_FLUTTER_01.wav")

	# ── Boxing defense ──
	sfx_block = _load("Hack and Slash Melee Combat Preview/Blade Metal Impact Recoil 01.wav")
	sfx_dodge = _load("Hack and Slash Melee Combat Preview/Whoosh Short Light 03.wav")
	sfx_dodge_smooth = _load("Hit and Punch Preview/AUDIO/WHOOSH_AIRY_FLUTTER_01.wav")
	sfx_perfect_block = _load("Hack and Slash Melee Combat Preview/Blade Metal Impact Recoil 01.wav")
	sfx_miss = _load("Hit and Punch Preview/AUDIO/CLOTHING_MATERIAL_MOVEMENT_01.wav")
	sfx_hit_taken = _load("Hit and Punch Preview/AUDIO/HIT_SLAP_07.wav")

	# ── Clinch ──
	sfx_clinch_struggle = _load("Hit and Punch Preview/AUDIO/PUNCH_SQUELCH_HEAVY_01.wav")
	sfx_clinch_won = _load("Hit and Punch Preview/AUDIO/HIGH_SNAP_02.wav")
	sfx_clinch_lost = _load("Hit and Punch Preview/AUDIO/PUNCH_SQUELCH_HEAVY_05.wav")

	# ── QTE feedback ──
	sfx_qte_appear = _load("Future UI Preview/Audio/Hologram Menu Open-2.wav")
	sfx_qte_perfect = _load("Future UI Preview/Audio/FUI Ping Triplet Echo.wav")
	sfx_qte_good = _load("Future UI Preview/Audio/FUI Button Beep Clean.wav")
	sfx_qte_fail = _load("Future UI Preview/Audio/Error Triplet-5.wav")
	sfx_qte_tick = _load("Future UI Preview/Audio/Holographic Tap Interaction.wav")

	# ── UI ──
	sfx_button_click = _load("Cassette Preview/AUDIO/BUTTON_03.wav")
	sfx_button_hover = _load("Future UI Preview/Audio/Holographic Interaction-32.wav")
	sfx_navigate = _load("Future UI Preview/Audio/FUI Navigation Tone Stereo Flutter.wav")
	sfx_error = _load("Future UI Preview/Audio/Error Triplet-5.wav")
	sfx_confirm = _load("Future UI Preview/Audio/High-Tech Gadget Activate.wav")
	sfx_back = _load("Cassette Preview/AUDIO/BUTTON_STOP_02.wav")

	# ── Chess ──
	sfx_piece_move = _load("Cassette Preview/AUDIO/BUTTON_05.wav")
	sfx_piece_capture = _load("Hack and Slash Melee Combat Preview/Blade Slash Short 01.wav")
	sfx_puzzle_solved = _load("Arcane Activations Preview/AUDIO/Glyph Activation Light 01.wav")
	sfx_puzzle_failed = _load("Glitch and Noise Preview/Electric Glitch_01.wav")
	sfx_chess_check = _load("Arcane Activations Preview/AUDIO/Arcane Symbol Activate 01.wav")

	# ── Game flow ──
	sfx_fight_start = _load("Cassette Preview/AUDIO/LOAD_CASSETTE_08.wav")
	sfx_round_bell = _load("Hit and Punch Preview/AUDIO/HIT_METAL_WRENCH_HEAVIEST_02.wav")
	sfx_ko = _load("Sci Fi Weapons Cyberpunk Arsenal Preview/AUDIO/EXPLDsgn_Explosion Impact_14.wav")
	sfx_victory = _load("Arcane Activations Preview/AUDIO/Arcane Beacon.wav")
	sfx_defeat = _load("Glitch and Noise Preview/Future Hologram Turn Off_02.wav")
	sfx_sub_drop = _load("Dystopia \u2013 Ambience and Drone Preview/AUDIO/SUB_DROP_DEEP.wav")

	# ── Shop / draft ──
	sfx_coin_spend = _load("The Mint \u2013 Coins and Money Preview/AUDIO/Coin Dropped on Ceramic Dish.wav")
	sfx_coin_earn = _load("The Mint \u2013 Coins and Money Preview/AUDIO/Coin Flung.wav")
	sfx_perk_draft = _load("Arcane Activations Preview/AUDIO/Glyph Activation Warm Aura.wav")
	sfx_card_play = _load("Cassette Preview/AUDIO/REMOVE_CASSETTE_07.wav")
	sfx_shop_buy = _load("The Mint \u2013 Coins and Money Preview/AUDIO/Coins_Placed_Down_Hardcover_Pitched.wav")

	# ── Transitions ──
	sfx_transition_in = _load("Hack and Slash Melee Combat Preview/Blade Swing Noise Slice 02.wav")
	sfx_transition_out = _load("Glitch and Noise Preview/Short Transient Burst_01.wav")
	sfx_reveal = _load("Arcane Activations Preview/AUDIO/Activate Plinth 03.wav")


func _load(relative_path: String) -> AudioStream:
	var full_path := SFX_ROOT + relative_path
	if ResourceLoader.exists(full_path):
		return load(full_path)
	push_warning("AudioManager: Sound not found: " + full_path)
	return null


# =============================================================================
# Core playback
# =============================================================================

func play_sfx(stream: AudioStream, volume_db: float = 0.0, pitch: float = 1.0) -> void:
	if stream == null:
		return
	for player in sfx_players:
		if not player.playing:
			player.stream = stream
			player.volume_db = volume_db
			player.pitch_scale = pitch
			player.play()
			return
	push_warning("All SFX players busy, skipping sound")


## Play with slight random pitch variation for organic feel.
func play_sfx_varied(stream: AudioStream, volume_db: float = 0.0, variation: float = 0.08) -> void:
	play_sfx(stream, volume_db, randf_range(1.0 - variation, 1.0 + variation))


# =============================================================================
# Named convenience methods — call these from game code
# =============================================================================

# ── Boxing punches ──
func play_punch(action_name: String, is_critical: bool = false) -> void:
	if is_critical:
		play_sfx_varied(sfx_punch_critical, 1.0)
		return
	match action_name.to_lower():
		"jab":    play_sfx_varied(sfx_jab, -2.0)
		"cross":  play_sfx_varied(sfx_cross, -1.0)
		"hook":   play_sfx_varied(sfx_hook, 0.0)
		"uppercut": play_sfx_varied(sfx_uppercut, 1.0)
		_:        play_sfx_varied(sfx_punch_heavy, 0.0)

func play_whoosh() -> void:
	play_sfx_varied(sfx_whoosh, -6.0)

func play_whoosh_light() -> void:
	play_sfx_varied(sfx_whoosh_light, -8.0)

# ── Defense ──
func play_block() -> void:
	play_sfx_varied(sfx_block, -3.0)

func play_dodge() -> void:
	play_sfx_varied(sfx_dodge, -4.0)

## Smooth satisfying dodge sound for successful character timing dodges
func play_dodge_smooth() -> void:
	play_sfx_varied(sfx_dodge_smooth, -3.0, 0.05)

## Meaty perfect block clang
func play_perfect_block() -> void:
	play_sfx(sfx_perfect_block, -1.0, 0.95)

func play_miss() -> void:
	play_sfx_varied(sfx_miss, -6.0)

func play_hit_taken() -> void:
	play_sfx_varied(sfx_hit_taken, -2.0)

# ── Clinch ──
func play_clinch_struggle() -> void:
	play_sfx_varied(sfx_clinch_struggle, -4.0)

func play_clinch_won() -> void:
	play_sfx(sfx_clinch_won, -2.0)

func play_clinch_lost() -> void:
	play_sfx(sfx_clinch_lost, -3.0)

# ── QTE ──
func play_qte_appear() -> void:
	play_sfx(sfx_qte_appear, -6.0)

func play_qte_result(result: String) -> void:
	match result:
		"perfect", "critical", "perfect_defense":
			play_sfx(sfx_qte_perfect, -3.0)
		"good", "partial", "normal":
			play_sfx(sfx_qte_good, -4.0)
		"miss", "failed_defense":
			play_sfx(sfx_qte_fail, -4.0)

func play_qte_tick() -> void:
	play_sfx(sfx_qte_tick, -10.0, randf_range(0.9, 1.1))

# ── UI ──
func play_button_click() -> void:
	play_sfx(sfx_button_click, -6.0)

func play_button_hover() -> void:
	play_sfx(sfx_button_hover, -14.0)

func play_navigate() -> void:
	play_sfx(sfx_navigate, -10.0)

func play_error() -> void:
	play_sfx(sfx_error, -4.0)

func play_confirm() -> void:
	play_sfx(sfx_confirm, -4.0)

func play_back() -> void:
	play_sfx(sfx_back, -6.0)

# ── Chess ──
func play_piece_move() -> void:
	play_sfx_varied(sfx_piece_move, -6.0)

func play_piece_capture() -> void:
	play_sfx_varied(sfx_piece_capture, -4.0)

func play_puzzle_solved() -> void:
	play_sfx(sfx_puzzle_solved, -2.0)

func play_puzzle_failed() -> void:
	play_sfx(sfx_puzzle_failed, -3.0)

func play_chess_check() -> void:
	play_sfx(sfx_chess_check, -4.0)

# ── Game flow ──
func play_fight_start() -> void:
	play_sfx(sfx_fight_start, -3.0)

func play_round_bell() -> void:
	play_sfx(sfx_round_bell, -2.0)

func play_ko() -> void:
	play_sfx(sfx_ko, 2.0)
	play_sfx(sfx_sub_drop, 0.0)

func play_victory() -> void:
	play_sfx(sfx_victory, -1.0)

func play_defeat() -> void:
	play_sfx(sfx_defeat, -2.0)

# ── Shop / draft ──
func play_coin_spend() -> void:
	play_sfx_varied(sfx_coin_spend, -4.0)

func play_coin_earn() -> void:
	play_sfx_varied(sfx_coin_earn, -3.0)

func play_perk_draft() -> void:
	play_sfx(sfx_perk_draft, -3.0)

func play_card_play() -> void:
	play_sfx(sfx_card_play, -4.0)

func play_shop_buy() -> void:
	play_sfx(sfx_shop_buy, -3.0)

# ── Transitions ──
func play_transition_in() -> void:
	play_sfx(sfx_transition_in, -6.0)

func play_transition_out() -> void:
	play_sfx(sfx_transition_out, -6.0)

func play_reveal() -> void:
	play_sfx(sfx_reveal, -3.0)
