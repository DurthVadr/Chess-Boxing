class_name AnimatedPortrait
extends TextureRect

## Cycles through animation frames on a TextureRect.
## Supports two sources:
##   1. Folder of frame_N.png images (load_animation)
##   2. Sprite sheet with named sequences (load_spritesheet)
## Drop-in replacement: keeps TextureRect type so Juice effects still work.

@export var fps: float = 10.0
@export var idle_fps: float = 4.0
@export var autoplay: bool = true

var _frames: Array[Texture2D] = []
var _current_frame: int = 0
var _elapsed: float = 0.0
var _playing: bool = false

# Sprite sheet support
var _sheet_texture: Texture2D = null
var _sheet_hframes: int = 4
var _sheet_vframes: int = 2
var _atlas_frames: Array[AtlasTexture] = []

# Named animation sequences (frame indices)
var _animations: Dictionary = {}  # name -> Array[int]
var _current_anim: String = "idle"
var _anim_index: int = 0
var _anim_looping: bool = true
var _anim_finished_callback: Callable


## Load animation from a folder of frame_N.png images (original method)
func load_animation(folder_path: String) -> void:
	_frames.clear()
	_atlas_frames.clear()
	_animations.clear()
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


## Load from a sprite sheet using a JSON config with per-frame regions.
## json_path points to a file exported by the sprite sheet editor tool.
## Format: { "frames": [{"x":..,"y":..,"w":..,"h":..}, ...],
##           "animations": {"idle": [0,1,2,1,0], "punch": [0,1,...]} }
func load_spritesheet_json(sheet_path: String, json_path: String) -> void:
	_frames.clear()
	_atlas_frames.clear()
	_animations.clear()

	if not ResourceLoader.exists(sheet_path):
		push_warning("AnimatedPortrait: Sheet not found: " + sheet_path)
		return
	if not FileAccess.file_exists(json_path):
		push_warning("AnimatedPortrait: JSON not found: " + json_path)
		load_spritesheet(sheet_path)
		return

	_sheet_texture = load(sheet_path)
	var file := FileAccess.open(json_path, FileAccess.READ)
	var data: Dictionary = JSON.parse_string(file.get_as_text())
	file.close()

	if not data or not data.has("frames"):
		push_warning("AnimatedPortrait: Invalid JSON config: " + json_path)
		load_spritesheet(sheet_path)
		return

	for f_data in data["frames"]:
		var atlas := AtlasTexture.new()
		atlas.atlas = _sheet_texture
		atlas.region = Rect2(f_data["x"], f_data["y"], f_data["w"], f_data["h"])
		_atlas_frames.append(atlas)

	# Load animations from JSON or use defaults
	if data.has("animations"):
		var anims: Dictionary = data["animations"]
		for anim_name in anims:
			_animations[anim_name] = Array(anims[anim_name])
	if not _animations.has("idle"):
		_animations["idle"] = [0, 1, 2, 1, 0]
	if not _animations.has("punch"):
		var punch_seq := []
		for i in _atlas_frames.size():
			punch_seq.append(i)
		punch_seq.append(0)
		_animations["punch"] = punch_seq

	_current_anim = "idle"
	_anim_index = 0
	_anim_looping = true
	texture = _atlas_frames[0]

	if autoplay:
		play()


## Load animation from a sprite sheet with hframes x vframes uniform grid.
## Reads frames left-to-right, top-to-bottom.
## Sets up default animations: idle (0,1,2,1,0) and punch (0..7,0).
func load_spritesheet(sheet_path: String, hframes: int = 4, vframes: int = 2) -> void:
	_frames.clear()
	_atlas_frames.clear()

	if not ResourceLoader.exists(sheet_path):
		push_warning("AnimatedPortrait: Sheet not found: " + sheet_path)
		return

	_sheet_texture = load(sheet_path)
	_sheet_hframes = hframes
	_sheet_vframes = vframes

	var frame_w := _sheet_texture.get_width() / hframes
	var frame_h := _sheet_texture.get_height() / vframes
	var total_frames := hframes * vframes

	for i in total_frames:
		var col := i % hframes
		var row := i / hframes
		var atlas := AtlasTexture.new()
		atlas.atlas = _sheet_texture
		atlas.region = Rect2(col * frame_w, row * frame_h, frame_w, frame_h)
		_atlas_frames.append(atlas)

	# Default animations
	# Idle: 1-2-3-2-1 (0-indexed: 0,1,2,1,0)
	_animations["idle"] = [0, 1, 2, 1, 0]
	# Punch: full sequence 1-2-3-4-5-6-7-8-1 (0-indexed: 0,1,2,3,4,5,6,7,0)
	_animations["punch"] = [0, 1, 2, 3, 4, 5, 6, 7, 0]

	_current_anim = "idle"
	_anim_index = 0
	_anim_looping = true
	texture = _atlas_frames[0]

	if autoplay:
		play()


## Set custom animation sequences. sequences is { "name": [frame_indices] }
func set_animations(sequences: Dictionary) -> void:
	_animations = sequences


## Play a named animation. If loop is false, plays once then returns to idle.
func play_anim(anim_name: String, loop: bool = true, on_finished: Callable = Callable()) -> void:
	if not _animations.has(anim_name):
		push_warning("AnimatedPortrait: Unknown animation: " + anim_name)
		return
	_current_anim = anim_name
	_anim_index = 0
	_anim_looping = loop
	_anim_finished_callback = on_finished
	_playing = true
	_elapsed = 0.0
	# Show first frame of the animation
	var seq: Array = _animations[_current_anim]
	if not seq.is_empty():
		_show_atlas_or_folder_frame(seq[0])


## Get frame 0 as a texture (for portraits/thumbnails)
func get_portrait_frame() -> Texture2D:
	if not _atlas_frames.is_empty():
		return _atlas_frames[0]
	if not _frames.is_empty():
		return _frames[0]
	return null


## Static helper: extract frame 0 from a sprite sheet for use as portrait.
## If json_path is provided, uses per-frame regions from JSON config.
## Otherwise falls back to uniform grid.
static func portrait_from_sheet(sheet_path: String, hframes: int = 4, vframes: int = 2) -> Texture2D:
	if not ResourceLoader.exists(sheet_path):
		return null
	var tex: Texture2D = load(sheet_path)

	# Check for JSON config alongside the sheet
	var json_path := "res://data/sprite_frames/%s_frames.json" % sheet_path.get_file().get_basename()
	if FileAccess.file_exists(json_path):
		var file := FileAccess.open(json_path, FileAccess.READ)
		var data: Dictionary = JSON.parse_string(file.get_as_text())
		file.close()
		if data and data.has("frames") and data["frames"].size() > 0:
			var f0: Dictionary = data["frames"][0]
			var atlas := AtlasTexture.new()
			atlas.atlas = tex
			atlas.region = Rect2(f0["x"], f0["y"], f0["w"], f0["h"])
			return atlas

	# Uniform grid fallback
	var frame_w := tex.get_width() / hframes
	var frame_h := tex.get_height() / vframes
	var atlas := AtlasTexture.new()
	atlas.atlas = tex
	atlas.region = Rect2(0, 0, frame_w, frame_h)
	return atlas


func play() -> void:
	_playing = true

func stop() -> void:
	_playing = false

func set_frame(index: int) -> void:
	_show_atlas_or_folder_frame(index)

func get_frame_count() -> int:
	if not _atlas_frames.is_empty():
		return _atlas_frames.size()
	return _frames.size()


func _show_atlas_or_folder_frame(index: int) -> void:
	if not _atlas_frames.is_empty():
		if index >= 0 and index < _atlas_frames.size():
			_current_frame = index
			texture = _atlas_frames[index]
	elif not _frames.is_empty():
		if index >= 0 and index < _frames.size():
			_current_frame = index
			texture = _frames[index]


func _process(delta: float) -> void:
	if not _playing:
		return

	# Sprite sheet with named animations
	if not _atlas_frames.is_empty() and _animations.has(_current_anim):
		_elapsed += delta
		var active_fps := idle_fps if _current_anim == "idle" else fps
		var frame_time := 1.0 / active_fps
		if _elapsed >= frame_time:
			_elapsed -= frame_time
			var seq: Array = _animations[_current_anim]
			_anim_index += 1
			if _anim_index >= seq.size():
				if _anim_looping:
					_anim_index = 0
				else:
					# Animation finished — return to idle
					var cb := _anim_finished_callback
					_anim_finished_callback = Callable()
					_current_anim = "idle"
					_anim_index = 0
					_anim_looping = true
					if cb.is_valid():
						cb.call()
					return
			texture = _atlas_frames[seq[_anim_index]]
		return

	# Folder-based frame cycling (original behavior)
	if _frames.is_empty():
		return
	_elapsed += delta
	var frame_time := 1.0 / fps
	if _elapsed >= frame_time:
		_elapsed -= frame_time
		_current_frame = (_current_frame + 1) % _frames.size()
		texture = _frames[_current_frame]
