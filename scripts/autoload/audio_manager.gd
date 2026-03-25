extends Node

## SFX playback manager — uses the "SFX" audio bus
## Music is handled separately by MusicManager autoload

var sfx_players: Array[AudioStreamPlayer] = []
const MAX_SFX_PLAYERS := 8

func _ready() -> void:
	# Pre-create a pool of AudioStreamPlayers for SFX
	for i in MAX_SFX_PLAYERS:
		var player := AudioStreamPlayer.new()
		player.bus = "SFX"
		add_child(player)
		sfx_players.append(player)

func play_sfx(stream: AudioStream, volume_db: float = 0.0) -> void:
	if stream == null:
		return
	for player in sfx_players:
		if not player.playing:
			player.stream = stream
			player.volume_db = volume_db
			player.play()
			return
	# All players busy — skip this sound
	push_warning("All SFX players busy, skipping sound")
