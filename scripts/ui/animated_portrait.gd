class_name AnimatedPortrait
extends TextureRect

## Cycles through a folder of frame_N.png images on a TextureRect.
## Drop-in replacement: keeps TextureRect type so Juice effects still work.

@export var fps: float = 10.0
@export var autoplay: bool = true

var _frames: Array[Texture2D] = []
var _current_frame: int = 0
var _elapsed: float = 0.0
var _playing: bool = false

func load_animation(folder_path: String) -> void:
	_frames.clear()
	var i := 0
	while true:
		var path := "%s/frame_%d.png" % [folder_path, i]
		if not ResourceLoader.exists(path):
			break
		_frames.append(load(path))
		i += 1

	if _frames.is_empty():
		push_warning("AnimatedPortrait: No frames found in " + folder_path)
		return

	_current_frame = 0
	texture = _frames[0]
	if autoplay:
		play()

func play() -> void:
	_playing = true

func stop() -> void:
	_playing = false

func set_frame(index: int) -> void:
	if index >= 0 and index < _frames.size():
		_current_frame = index
		texture = _frames[index]

func get_frame_count() -> int:
	return _frames.size()

func _process(delta: float) -> void:
	if not _playing or _frames.is_empty():
		return
	_elapsed += delta
	var frame_time := 1.0 / fps
	if _elapsed >= frame_time:
		_elapsed -= frame_time
		_current_frame = (_current_frame + 1) % _frames.size()
		texture = _frames[_current_frame]
