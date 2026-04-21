shader_type canvas_item;

// Psychedelic sprite effect: rainbow aura, chromatic aberration, ghost trail.
// Apply to TextureRect or Sprite2D nodes.

uniform float aura_size : hint_range(0.0, 0.05) = 0.008;
uniform float aura_intensity : hint_range(0.0, 2.0) = 0.45;
uniform float aberration_amount : hint_range(0.0, 0.02) = 0.003;
uniform float aberration_pulse_speed : hint_range(0.0, 10.0) = 1.2;
uniform float ghost_count : hint_range(0.0, 5.0) = 1.0;
uniform float ghost_spacing : hint_range(0.001, 0.05) = 0.012;
uniform float ghost_opacity : hint_range(0.0, 0.5) = 0.10;
uniform float hue_shift_speed : hint_range(0.0, 3.0) = 0.3;

vec3 hsv2rgb(vec3 c) {
	vec3 p = abs(fract(c.xxx + vec3(1.0, 2.0/3.0, 1.0/3.0)) * 6.0 - 3.0);
	return c.z * mix(vec3(1.0), clamp(p - 1.0, 0.0, 1.0), c.y);
}

void fragment() {
	vec2 uv = UV;
	float t = TIME;

	// --- Ghost / echo trail ---
	vec4 ghost_col = vec4(0.0);
	for (float i = 1.0; i <= 5.0; i += 1.0) {
		if (i > ghost_count) break;
		float offset = i * ghost_spacing;
		// Trail goes in -X direction (behind the sprite during idle sway)
		vec2 ghost_uv = uv + vec2(offset * sin(t * 1.5 + i), offset * 0.3 * cos(t * 2.0 + i * 0.7));
		vec4 g = texture(TEXTURE, ghost_uv);
		float ghost_hue = fract(t * hue_shift_speed * 0.3 + i * 0.15);
		vec3 tint = hsv2rgb(vec3(ghost_hue, 0.7, 1.0));
		ghost_col += vec4(g.rgb * tint * ghost_opacity * (1.0 - i / (ghost_count + 1.0)), g.a * ghost_opacity * (1.0 - i / (ghost_count + 1.0)));
	}

	// --- Chromatic aberration (pulsing) ---
	float pulse = sin(t * aberration_pulse_speed) * 0.5 + 0.5;
	float ab = aberration_amount * (0.5 + pulse * 0.5);
	float r = texture(TEXTURE, uv + vec2(ab, 0.0)).r;
	float g = texture(TEXTURE, uv).g;
	float b = texture(TEXTURE, uv - vec2(ab, 0.0)).b;
	float a = texture(TEXTURE, uv).a;
	vec4 main_col = vec4(r, g, b, a);

	// --- Rainbow aura (glow around sprite edges) ---
	vec4 aura = vec4(0.0);
	float aura_alpha = 0.0;
	float samples = 12.0;
	for (float i = 0.0; i < 12.0; i += 1.0) {
		float angle = i / samples * 6.28318;
		vec2 offset = vec2(cos(angle), sin(angle)) * aura_size;
		float sample_a = texture(TEXTURE, uv + offset).a;
		aura_alpha = max(aura_alpha, sample_a);
	}
	// Aura only appears outside the sprite
	float aura_mask = clamp(aura_alpha - a, 0.0, 1.0);
	float aura_hue = fract(t * hue_shift_speed + atan(uv.y - 0.5, uv.x - 0.5) / 6.28318);
	vec3 aura_rgb = hsv2rgb(vec3(aura_hue, 1.0, 1.0));
	aura = vec4(aura_rgb * aura_intensity, aura_mask * aura_intensity);

	// --- Composite: aura behind, ghosts behind, main sprite on top ---
	vec4 result = aura;
	// Blend ghosts over aura
	result.rgb = mix(result.rgb, ghost_col.rgb, ghost_col.a);
	result.a = max(result.a, ghost_col.a);
	// Blend main sprite on top
	result.rgb = mix(result.rgb, main_col.rgb, main_col.a);
	result.a = max(result.a, main_col.a);

	COLOR = result;
}
