extends Node

## Dynamic music manager — crossfades between tracks based on game phase
## Supports layered intensity (calm → tense → boss) and smooth transitions
##
## SETUP: Place .ogg files in res://assets/audio/music/ and configure TRACK_MAP below.
## Each phase maps to a track key. Tracks can have intensity variants (e.g., "boxing", "boxing_intense").

# --- Configuration ---

## Map of track_key -> file path (relative to res://assets/audio/music/)
## Update these paths as you add real tracks
const TRACK_MAP := {
	# Menu / UI
	"menu":            "menu_jazz.ogg",
	"fighter_select":  "menu_jazz.ogg",        # Reuses menu track
	"tournament":      "tournament_tension.ogg",
	"opponent_reveal": "tournament_tension.ogg",

	# Chess phase
	"chess":           "chess_lofi.ogg",
	"chess_tense":     "chess_tense.ogg",       # When timer < 15s

	# Boxing phase
	"boxing":          "boxing_groove.ogg",
	"boxing_intense":  "boxing_intense.ogg",    # When either fighter < 30% HP
	"boxing_boss":     "boxing_boss.ogg",       # Magnus fight

	# Perk draft
	"perk_draft":      "draft_smooth.ogg",

	# Results
	"results_win":     "victory_fanfare.ogg",
	"results_lose":    "defeat_blues.ogg",
}

## Phase -> default track key mapping
const PHASE_TRACKS := {
	"menu":            "menu",
	"fighter_select":  "fighter_select",
	"tournament":      "tournament",
	"opponent_reveal": "opponent_reveal",
	"chess":           "chess",
	"boxing":          "boxing",
	"perk_draft":      "perk_draft",
	"results":         "results_win",  # Overridden based on win/lose
}

## Crossfade duration in seconds
const CROSSFADE_DURATION := 1.5
## Default music volume (dB)
const DEFAULT_VOLUME_DB := -8.0
## Low pass filter cutoff when muffled (Hz) — used during transitions
const MUFFLE_CUTOFF := 800.0

# --- State ---

var _current_track_key: String = ""
var _player_a: AudioStreamPlayer
var _player_b: AudioStreamPlayer
var _active_player: AudioStreamPlayer  # Which player is currently audible
var _tween: Tween = null
var _loaded_streams: Dictionary = {}  # track_key -> AudioStream (cache)
var _music_bus_idx: int = -1
var _intensity_state: String = ""  # For tracking within-phase shifts

# --- Lifecycle ---

func _ready() -> void:
	# Create two AudioStreamPlayers for crossfading
	_player_a = AudioStreamPlayer.new()
	_player_b = AudioStreamPlayer.new()

	# Use Music bus if it exists, otherwise Master
	_music_bus_idx = AudioServer.get_bus_index("Music")
	var bus_name := "Music" if _music_bus_idx >= 0 else "Master"

	_player_a.bus = bus_name
	_player_b.bus = bus_name
	_player_a.volume_db = DEFAULT_VOLUME_DB
	_player_b.volume_db = -80.0  # Start silent

	add_child(_player_a)
	add_child(_player_b)

	_active_player = _player_a

	# Connect to GameManager phase changes
	if GameManager:
		GameManager.phase_changed.connect(_on_phase_changed)
		GameManager.run_ended.connect(_on_run_ended)

# --- Public API ---

## Play a track by key with crossfade. If same track is already playing, does nothing.
func play_track(track_key: String, force_restart: bool = false) -> void:
	if track_key == _current_track_key and not force_restart:
		return

	var stream := _get_stream(track_key)
	if stream == null:
		push_warning("MusicManager: No stream for track key '%s'" % track_key)
		return

	_current_track_key = track_key
	_crossfade_to(stream)

## Shift intensity within current phase (e.g., chess -> chess_tense)
func shift_intensity(intensity_key: String) -> void:
	if intensity_key == _intensity_state:
		return
	_intensity_state = intensity_key

	# Try to play the intensity variant; if it doesn't exist, ignore
	if TRACK_MAP.has(intensity_key):
		play_track(intensity_key)

## Stop all music with fade out
func stop(fade_duration: float = 1.0) -> void:
	_current_track_key = ""
	_intensity_state = ""

	if _tween and _tween.is_valid():
		_tween.kill()

	_tween = create_tween().set_parallel(true)
	_tween.tween_property(_player_a, "volume_db", -80.0, fade_duration)
	_tween.tween_property(_player_b, "volume_db", -80.0, fade_duration)
	_tween.chain().tween_callback(_stop_both)

## Set master music volume (0.0 to 1.0)
func set_volume(normalized: float) -> void:
	var db := linear_to_db(clampf(normalized, 0.0, 1.0))
	if _music_bus_idx >= 0:
		AudioServer.set_bus_volume_db(_music_bus_idx, db)
	else:
		_player_a.volume_db = db
		_player_b.volume_db = db

## Muffle the music (e.g., during a dramatic moment)
func muffle(enabled: bool, duration: float = 0.5) -> void:
	# This requires a LowPassFilter effect on the Music bus
	# If not set up, this is a no-op
	if _music_bus_idx < 0:
		return
	var effect_count := AudioServer.get_bus_effect_count(_music_bus_idx)
	for i in effect_count:
		var effect := AudioServer.get_bus_effect(_music_bus_idx, i)
		if effect is AudioEffectLowPassFilter:
			if _tween and _tween.is_valid():
				_tween.kill()
			_tween = create_tween()
			var target := MUFFLE_CUTOFF if enabled else 20500.0
			_tween.tween_property(effect, "cutoff_hz", target, duration)
			return

# --- Internal ---

func _on_phase_changed(phase_string: String) -> void:
	_intensity_state = ""

	var track_key: String = PHASE_TRACKS.get(phase_string, "")
	if track_key == "":
		return

	# Special case: results screen depends on win/lose
	if phase_string == "results":
		track_key = "results_win" if GameManager.stats.fights_won >= GameManager.total_opponents else "results_lose"

	# Special case: boxing against final boss gets boss track
	if phase_string == "boxing":
		if GameManager.current_opponent_index >= GameManager.total_opponents - 1:
			track_key = "boxing_boss"

	play_track(track_key)

func _on_run_ended(_won: bool) -> void:
	# Results screen handles its own music via phase_changed
	pass

func _crossfade_to(stream: AudioStream) -> void:
	if _tween and _tween.is_valid():
		_tween.kill()

	# Determine which player is inactive
	var incoming: AudioStreamPlayer
	if _active_player == _player_a:
		incoming = _player_b
	else:
		incoming = _player_a

	# Set up incoming player
	incoming.stream = stream
	incoming.volume_db = -80.0
	incoming.play()

	# Crossfade: fade out active, fade in incoming
	_tween = create_tween().set_parallel(true)
	_tween.tween_property(_active_player, "volume_db", -80.0, CROSSFADE_DURATION)
	_tween.tween_property(incoming, "volume_db", DEFAULT_VOLUME_DB, CROSSFADE_DURATION)

	# After crossfade, stop the old player to free resources
	_tween.chain().tween_callback(func(): _active_player.stop())

	_active_player = incoming

func _get_stream(track_key: String) -> AudioStream:
	# Return from cache if already loaded
	if _loaded_streams.has(track_key):
		return _loaded_streams[track_key]

	var filename: String = TRACK_MAP.get(track_key, "")
	if filename == "":
		return null

	var path := "res://assets/audio/music/" + filename
	if not ResourceLoader.exists(path):
		push_warning("MusicManager: Track file not found: %s" % path)
		return null

	var stream: AudioStream = load(path)
	if stream:
		# Enable looping for OGG files
		if stream is AudioStreamOggVorbis:
			stream.loop = true
		_loaded_streams[track_key] = stream
	return stream

func _stop_both() -> void:
	_player_a.stop()
	_player_b.stop()
