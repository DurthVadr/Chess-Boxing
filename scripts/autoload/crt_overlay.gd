extends CanvasLayer

## Global CRT overlay — autoloaded, renders on top of every scene.
## Also manages ambient floating dust particles for atmosphere.

var _crt_rect: ColorRect
var _particle_rect: ColorRect
var _intensity: float = 1.0  # 0.0–1.0 multiplier for all CRT shader params

const CRT_SHADER_PATH := "res://assets/shaders/crt.gdshader"
const PARTICLE_SHADER_PATH := "res://assets/shaders/particles.gdshader"
# Default shader values at full intensity (1.0)
const DEFAULTS := {
	"scanline_intensity": 0.24,   # stronger defined lines — classic CRT look
	"vignette_intensity": 0.48,   # deep corner darkening — old monitor feel
	"aberration_amount": 0.55,    # keep some RGB split, less hallucinogenic
	"curvature": 9.0,             # more barrel = more retro tube screen
	"grain_amount": 0.055,        # grainier = more analog/VHS
	"bloom_amount": 0.06,         # less bloom = crisper, less dreamy
	"flicker_amount": 0.014,      # more flicker = old phosphor tube aging
	"phosphor_strength": 0.28,    # stronger RGB stripes = authentic phosphor
	# Psychedelic params — dialed back
	"scanline_warp": 0.3,         # nearly straight scanlines
	"fisheye": 0.02,              # very slight extra barrel
	"bloom_glow": 0.06,           # almost no soft haze
	"color_bleed": 0.06,          # minimal channel bleed
}
# These don't scale — they stay constant
const FIXED := {
	"brightness": 1.06,           # slight boost to compensate stronger scanlines
}

func _ready() -> void:
	layer = 100
	_setup_crt()
	_setup_particles()

func _setup_crt() -> void:
	var shader := load(CRT_SHADER_PATH) as Shader
	if shader == null:
		push_warning("CRT shader not found at: " + CRT_SHADER_PATH)
		return

	var mat := ShaderMaterial.new()
	mat.shader = shader
	for key in DEFAULTS:
		mat.set_shader_parameter(key, DEFAULTS[key])
	for key in FIXED:
		mat.set_shader_parameter(key, FIXED[key])

	_crt_rect = ColorRect.new()
	_crt_rect.material = mat
	_crt_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_crt_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_crt_rect)

## Show or hide the CRT effect entirely.
func set_enabled(enabled: bool) -> void:
	if _crt_rect:
		_crt_rect.visible = enabled

## Set CRT intensity (0.0 = off, 1.0 = full). Scales all effect parameters.
func set_intensity(value: float) -> void:
	_intensity = clampf(value, 0.0, 1.0)
	if _crt_rect and _crt_rect.material:
		var mat: ShaderMaterial = _crt_rect.material
		for key in DEFAULTS:
			mat.set_shader_parameter(key, DEFAULTS[key] * _intensity)

## Briefly spike CRT aberration + scanlines for a punch impact feel.
func punch_impact(strength: float = 1.0) -> void:
	if not _crt_rect or not _crt_rect.material:
		return
	var mat: ShaderMaterial = _crt_rect.material
	var ab_peak := 3.5 * strength
	var scan_peak := 0.35 * strength
	mat.set_shader_parameter("aberration_amount", ab_peak)
	mat.set_shader_parameter("scanline_intensity", scan_peak)
	var tween := _crt_rect.create_tween()
	tween.set_parallel(true)
	tween.tween_method(
		func(v: float) -> void: mat.set_shader_parameter("aberration_amount", v),
		ab_peak, DEFAULTS["aberration_amount"] * _intensity, 0.25
	).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_EXPO)
	tween.tween_method(
		func(v: float) -> void: mat.set_shader_parameter("scanline_intensity", v),
		scan_peak, DEFAULTS["scanline_intensity"] * _intensity, 0.3
	).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_EXPO)


func _setup_particles() -> void:
	var shader := load(PARTICLE_SHADER_PATH) as Shader
	if shader == null:
		# Particles are optional — no warning
		return

	var mat := ShaderMaterial.new()
	mat.shader = shader

	_particle_rect = ColorRect.new()
	_particle_rect.material = mat
	_particle_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_particle_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	# Insert below CRT so particles get the CRT treatment
	add_child(_particle_rect)
	move_child(_particle_rect, 0)
