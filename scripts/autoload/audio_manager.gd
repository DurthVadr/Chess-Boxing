extends Node

## SFX playback manager — preloads all game sounds and exposes named play methods.
## Uses a pool of AudioStreamPlayers on the "SFX" bus.

var sfx_players: Array[AudioStreamPlayer] = []
const MAX_SFX_PLAYERS := 16   # bumped from 12 — dialogue tick fires rapidly

const SFX_ROOT := "res://assets/sounds/Shapeforms Audio Free Sound Effects/Shapeforms Audio Free Sound Effects/"

# ── Boxing — punches ──────────────────────────────────────────────────────────
var sfx_jab: AudioStream             # clean, snappy
var sfx_cross: AudioStream           # percussive, heavier than jab
var sfx_hook: AudioStream            # designed heavy
var sfx_uppercut: AudioStream        # intense upward
var sfx_punch_heavy: AudioStream     # generic heavy land
var sfx_punch_critical: AudioStream  # electric/critical
var sfx_whoosh: AudioStream          # wide arm swing miss
var sfx_whoosh_light: AudioStream    # light flutter miss

# ── Boxing — defense ──────────────────────────────────────────────────────────
var sfx_block: AudioStream           # solid metal impact
var sfx_dodge: AudioStream           # quick whoosh
var sfx_dodge_smooth: AudioStream    # clean flutter dodge
var sfx_perfect_block: AudioStream   # shield surge (very satisfying)
var sfx_miss: AudioStream            # clothing brush
var sfx_hit_taken: AudioStream       # taking a hit

# ── Boxing — clinch ───────────────────────────────────────────────────────────
var sfx_clinch_struggle: AudioStream
var sfx_clinch_won: AudioStream
var sfx_clinch_lost: AudioStream

# ── QTE ───────────────────────────────────────────────────────────────────────
var sfx_qte_appear: AudioStream      # lock-on targeting beep
var sfx_qte_perfect: AudioStream     # metallic kill confirm
var sfx_qte_good: AudioStream        # hit marker
var sfx_qte_fail: AudioStream        # glitch error tone
var sfx_qte_tick: AudioStream        # anticipation countdown beeps

# ── UI — general ──────────────────────────────────────────────────────────────
var sfx_button_click: AudioStream    # mechanical Amiga drive click
var sfx_button_hover: AudioStream    # holographic radiate
var sfx_navigate: AudioStream        # navigation flutter tone
var sfx_error: AudioStream           # audio jack noise triplet
var sfx_confirm: AudioStream         # high-tech gadget activate
var sfx_back: AudioStream            # tape stop

# ── Dialogue ──────────────────────────────────────────────────────────────────
var sfx_dialogue_tick: AudioStream   # single laptop keystroke (typewriter)
var sfx_dialogue_advance: AudioStream # spacebar press (advance line)
var sfx_dialogue_open: AudioStream   # old terminal popup appear

# ── Chess ─────────────────────────────────────────────────────────────────────
var sfx_piece_move: AudioStream      # tablet tap (precise, digital)
var sfx_piece_capture: AudioStream   # heavy punch impact (piece taken)
var sfx_puzzle_solved: AudioStream   # warm glyph aura (triumph)
var sfx_puzzle_failed: AudioStream   # glitch error tone
var sfx_chess_check: AudioStream     # energy orb surge (threatening)

# ── Game flow ─────────────────────────────────────────────────────────────────
var sfx_fight_start: AudioStream     # stone pillar rising (building tension)
var sfx_round_bell: AudioStream      # heavy metal wrench (perfect bell)
var sfx_ko: AudioStream              # implode (body dropping)
var sfx_victory: AudioStream         # arcane beacon (grand)
var sfx_defeat: AudioStream          # hologram turning off (deflating)
var sfx_sub_drop: AudioStream        # sub bass drop

# ── Shop / draft ──────────────────────────────────────────────────────────────
var sfx_coin_spend: AudioStream      # coin on wood (weight)
var sfx_coin_earn: AudioStream       # coin flung
var sfx_perk_draft: AudioStream      # forcefield activate (power surge)
var sfx_card_play: AudioStream       # card slapped down
var sfx_shop_buy: AudioStream        # coins placed down pitched

# ── Transitions ───────────────────────────────────────────────────────────────
var sfx_transition_in: AudioStream   # dramatic space tear
var sfx_transition_out: AudioStream  # static glitch burst
var sfx_reveal: AudioStream          # UI message appear


func _ready() -> void:
	for i in MAX_SFX_PLAYERS:
		var player := AudioStreamPlayer.new()
		player.bus = "SFX"
		add_child(player)
		sfx_players.append(player)
	_preload_all()


func _preload_all() -> void:
	# ── Boxing punches ────────────────────────────────────────────────────────
	sfx_jab             = _load("Hit and Punch Preview/AUDIO/PUNCH_CLEAN_HEAVY_10.wav")
	sfx_cross           = _load("Hit and Punch Preview/AUDIO/PUNCH_PERCUSSIVE_HEAVY_09.wav")
	sfx_hook            = _load("Hit and Punch Preview/AUDIO/PUNCH_DESIGNED_HEAVY_74.wav")
	sfx_uppercut        = _load("Hit and Punch Preview/AUDIO/PUNCH_INTENSE_HEAVY_03.wav")
	sfx_punch_heavy     = _load("Hit and Punch Preview/AUDIO/PUNCH_DESIGNED_HEAVY_86.wav")
	sfx_punch_critical  = _load("Hit and Punch Preview/AUDIO/PUNCH_ELECTRIC_HEAVY_02.wav")
	sfx_whoosh          = _load("Hit and Punch Preview/AUDIO/WHOOSH_ARM_SWING_01_WIDE.wav")
	sfx_whoosh_light    = _load("Hit and Punch Preview/AUDIO/WHOOSH_AIRY_FLUTTER_01.wav")

	# ── Boxing defense ────────────────────────────────────────────────────────
	sfx_block           = _load("Hack and Slash Melee Combat Preview/Blade Metal Impact Recoil 01.wav")
	sfx_dodge           = _load("Hack and Slash Melee Combat Preview/Whoosh Short Light 03.wav")
	sfx_dodge_smooth    = _load("Hit and Punch Preview/AUDIO/WHOOSH_AIRY_FLUTTER_01.wav")
	sfx_perfect_block   = _load("Sci Fi Weapons Cyberpunk Arsenal Preview/AUDIO/SCIEnrg_Shield Activate Deactivate_02.wav")
	sfx_miss            = _load("Hit and Punch Preview/AUDIO/CLOTHING_MATERIAL_MOVEMENT_01.wav")
	sfx_hit_taken       = _load("Hit and Punch Preview/AUDIO/HIT_SLAP_07.wav")

	# ── Clinch ────────────────────────────────────────────────────────────────
	sfx_clinch_struggle = _load("Hit and Punch Preview/AUDIO/PUNCH_SQUELCH_HEAVY_01.wav")
	sfx_clinch_won      = _load("Hit and Punch Preview/AUDIO/HIGH_SNAP_02.wav")
	sfx_clinch_lost     = _load("Hit and Punch Preview/AUDIO/PUNCH_SQUELCH_HEAVY_05.wav")

	# ── QTE ───────────────────────────────────────────────────────────────────
	sfx_qte_appear      = _load("Sci Fi Weapons Cyberpunk Arsenal Preview/AUDIO/UIBeep_Lock On_05.wav")
	sfx_qte_perfect     = _load("Sci Fi Weapons Cyberpunk Arsenal Preview/AUDIO/DSGNStngr_Kill Confirm Metallic_02.wav")
	sfx_qte_good        = _load("Sci Fi Weapons Cyberpunk Arsenal Preview/AUDIO/BLLTImpt_Hit Marker_07.wav")
	sfx_qte_fail        = _load("Sci Fi Weapons Cyberpunk Arsenal Preview/AUDIO/UIGlitch_Error Tone_03.wav")
	sfx_qte_tick        = _load("Sci Fi Weapons Cyberpunk Arsenal Preview/AUDIO/BEEPTimer_Anticipation Beeps_05.wav")

	# ── UI ────────────────────────────────────────────────────────────────────
	sfx_button_click    = _load("Floppy Disk Preview/Amiga Disk Drive Button Click-15.wav")
	sfx_button_hover    = _load("Future UI Preview/Audio/FUI Holographic Interaction Radiate.wav")
	sfx_navigate        = _load("Future UI Preview/Audio/FUI Navigation Tone Stereo Flutter.wav")
	sfx_error           = _load("Glitch and Noise Preview/Audio Jack Noise Triplet_01.wav")
	sfx_confirm         = _load("Future UI Preview/Audio/High-Tech Gadget Activate.wav")
	sfx_back            = _load("Cassette Preview/AUDIO/TAPE STOP_15.wav")

	# ── Dialogue ──────────────────────────────────────────────────────────────
	sfx_dialogue_tick    = _load("Type Preview/Laptop/Laptop_Keystroke_82.wav")
	sfx_dialogue_advance = _load("Type Preview/Laptop/Laptop_Spacebar_06.wav")
	sfx_dialogue_open    = _load("Future UI Preview/Audio/Old Terminal Popup Appear Low.wav")

	# ── Chess ─────────────────────────────────────────────────────────────────
	sfx_piece_move      = _load("Type Preview/Tablet/Tablet_Tap_07.wav")
	sfx_piece_capture   = _load("Hit and Punch Preview/AUDIO/PUNCH_DESIGNED_HEAVY_23.wav")
	sfx_puzzle_solved   = _load("Arcane Activations Preview/AUDIO/Glyph Activation Warm Aura.wav")
	sfx_puzzle_failed   = _load("Glitch and Noise Preview/Electric Glitch_01.wav")
	sfx_chess_check     = _load("Sci Fi Weapons Cyberpunk Arsenal Preview/AUDIO/SCIEnrg_Energy Orb_05.wav")

	# ── Game flow ─────────────────────────────────────────────────────────────
	sfx_fight_start     = _load("Arcane Activations Preview/AUDIO/Raise Stone Pillar Long.wav")
	sfx_round_bell      = _load("Hit and Punch Preview/AUDIO/HIT_METAL_WRENCH_HEAVIEST_02.wav")
	sfx_ko              = _load("Sci Fi Weapons Cyberpunk Arsenal Preview/AUDIO/EXPLDsgn_Implode_15.wav")
	sfx_victory         = _load("Arcane Activations Preview/AUDIO/Arcane Beacon.wav")
	sfx_defeat          = _load("Glitch and Noise Preview/Future Hologram Turn Off_02.wav")
	sfx_sub_drop        = _load("Dystopia \u2013 Ambience and Drone Preview/AUDIO/SUB_DROP_DEEP.wav")

	# ── Shop / draft ──────────────────────────────────────────────────────────
	sfx_coin_spend      = _load("The Mint \u2013 Coins and Money Preview/AUDIO/Coin Dropped on Wood Rattle.wav")
	sfx_coin_earn       = _load("The Mint \u2013 Coins and Money Preview/AUDIO/Coin Flung.wav")
	sfx_perk_draft      = _load("Arcane Activations Preview/AUDIO/Activate Glyph Forcefield.wav")
	sfx_card_play       = _load("The Mint \u2013 Coins and Money Preview/AUDIO/Bank Card Placed Down 03.wav")
	sfx_shop_buy        = _load("The Mint \u2013 Coins and Money Preview/AUDIO/Coins_Placed_Down_Hardcover_Pitched.wav")

	# ── Transitions ───────────────────────────────────────────────────────────
	sfx_transition_in   = _load("Dystopia \u2013 Ambience and Drone Preview/AUDIO/ONE_SHOT_SPACE_TEAR.wav")
	sfx_transition_out  = _load("Future UI Preview/Audio/Static Glitch Short.wav")
	sfx_reveal          = _load("Arcane Activations Preview/AUDIO/UI Message Appear 01.wav")


func _load(relative_path: String) -> AudioStream:
	var full_path := SFX_ROOT + relative_path
	if ResourceLoader.exists(full_path):
		return load(full_path)
	push_warning("AudioManager: sound not found — " + full_path)
	return null


# =============================================================================
# Core playback
# =============================================================================

func play_sfx(stream: AudioStream, volume_db: float = 0.0, pitch: float = 1.0) -> void:
	if stream == null:
		return
	for player in sfx_players:
		if not player.playing:
			player.stream    = stream
			player.volume_db = volume_db
			player.pitch_scale = pitch
			player.play()
			return
	# All players busy — steal the oldest (first in pool)
	sfx_players[0].stop()
	sfx_players[0].stream     = stream
	sfx_players[0].volume_db  = volume_db
	sfx_players[0].pitch_scale = pitch
	sfx_players[0].play()


## Play with slight random pitch variation for organic feel.
func play_sfx_varied(stream: AudioStream, volume_db: float = 0.0, variation: float = 0.08) -> void:
	play_sfx(stream, volume_db, randf_range(1.0 - variation, 1.0 + variation))


# =============================================================================
# Named convenience methods
# =============================================================================

# ── Boxing punches ────────────────────────────────────────────────────────────
func play_punch(action_name: String, is_critical: bool = false) -> void:
	if is_critical:
		play_sfx_varied(sfx_punch_critical, 1.0)
		return
	match action_name.to_lower():
		"jab":      play_sfx_varied(sfx_jab,         -2.0)
		"cross":    play_sfx_varied(sfx_cross,        -1.0)
		"hook":     play_sfx_varied(sfx_hook,          0.0)
		"uppercut": play_sfx_varied(sfx_uppercut,      1.0)
		_:          play_sfx_varied(sfx_punch_heavy,   0.0)

func play_whoosh() -> void:
	play_sfx_varied(sfx_whoosh, -6.0)

func play_whoosh_light() -> void:
	play_sfx_varied(sfx_whoosh_light, -8.0)

# ── Defense ───────────────────────────────────────────────────────────────────
func play_block() -> void:
	play_sfx_varied(sfx_block, -3.0)

func play_dodge() -> void:
	play_sfx_varied(sfx_dodge, -4.0)

func play_dodge_smooth() -> void:
	play_sfx_varied(sfx_dodge_smooth, -3.0, 0.05)

func play_perfect_block() -> void:
	# Shield surge — very satisfying, distinct from regular block
	play_sfx(sfx_perfect_block, 0.0, 0.98)

func play_miss() -> void:
	play_sfx_varied(sfx_miss, -6.0)

func play_hit_taken() -> void:
	play_sfx_varied(sfx_hit_taken, -1.0)

# ── Clinch ────────────────────────────────────────────────────────────────────
func play_clinch_struggle() -> void:
	play_sfx_varied(sfx_clinch_struggle, -4.0)

func play_clinch_won() -> void:
	play_sfx(sfx_clinch_won, -2.0)

func play_clinch_lost() -> void:
	play_sfx(sfx_clinch_lost, -3.0)

# ── QTE ───────────────────────────────────────────────────────────────────────
func play_qte_appear() -> void:
	play_sfx(sfx_qte_appear, -4.0)

func play_qte_result(result: String) -> void:
	match result:
		"perfect", "critical", "perfect_defense":
			play_sfx(sfx_qte_perfect, -1.0)
		"good", "partial", "normal":
			play_sfx(sfx_qte_good, -4.0)
		"miss", "failed_defense":
			play_sfx(sfx_qte_fail, -3.0)

func play_qte_tick() -> void:
	play_sfx(sfx_qte_tick, -8.0, randf_range(0.95, 1.05))

# ── UI ────────────────────────────────────────────────────────────────────────
func play_button_click() -> void:
	play_sfx(sfx_button_click, -4.0)

func play_button_hover() -> void:
	play_sfx(sfx_button_hover, -12.0)

func play_navigate() -> void:
	play_sfx(sfx_navigate, -8.0)

func play_error() -> void:
	play_sfx(sfx_error, -3.0)

func play_confirm() -> void:
	play_sfx(sfx_confirm, -3.0)

func play_back() -> void:
	play_sfx(sfx_back, -5.0)

# ── Dialogue ──────────────────────────────────────────────────────────────────
func play_dialogue_tick() -> void:
	## Tablet tap — softer than keystroke, called once per revealed character.
	play_sfx(sfx_piece_move, -2.0, randf_range(0.80, 1.20))

func play_dialogue_advance() -> void:
	## Spacebar press — called when the player acknowledges a line.
	play_sfx(sfx_dialogue_advance, -7.0, randf_range(0.95, 1.05))

func play_dialogue_open() -> void:
	## Old terminal popup — called when the dialogue box first appears.
	play_sfx(sfx_dialogue_open, -5.0)

# ── Chess ─────────────────────────────────────────────────────────────────────
func play_piece_move() -> void:
	play_sfx_varied(sfx_piece_move, -4.0, 0.10)

func play_piece_capture() -> void:
	play_sfx_varied(sfx_piece_capture, -2.0)

func play_puzzle_solved() -> void:
	play_sfx(sfx_puzzle_solved, -1.0)

func play_puzzle_failed() -> void:
	play_sfx(sfx_puzzle_failed, -2.0)

func play_chess_check() -> void:
	play_sfx(sfx_chess_check, -2.0)

# ── Game flow ─────────────────────────────────────────────────────────────────
func play_fight_start() -> void:
	play_sfx(sfx_fight_start, -2.0)

func play_round_bell() -> void:
	play_sfx(sfx_round_bell, 0.0)

func play_ko() -> void:
	play_sfx(sfx_ko, 2.0)
	play_sfx(sfx_sub_drop, 0.0)

func play_victory() -> void:
	play_sfx(sfx_victory, 0.0)

func play_defeat() -> void:
	play_sfx(sfx_defeat, -1.0)
	play_sfx(sfx_sub_drop, -3.0)

# ── Shop / draft ──────────────────────────────────────────────────────────────
func play_coin_spend() -> void:
	play_sfx_varied(sfx_coin_spend, -3.0)

func play_coin_earn() -> void:
	play_sfx_varied(sfx_coin_earn, -2.0)

func play_perk_draft() -> void:
	play_sfx(sfx_perk_draft, -1.0)

func play_card_play() -> void:
	play_sfx(sfx_card_play, -3.0)

func play_shop_buy() -> void:
	play_sfx(sfx_shop_buy, -2.0)

# ── Transitions ───────────────────────────────────────────────────────────────
func play_transition_in() -> void:
	play_sfx(sfx_transition_in, -4.0)

func play_transition_out() -> void:
	play_sfx(sfx_transition_out, -5.0)

func play_reveal() -> void:
	play_sfx(sfx_reveal, -3.0)
