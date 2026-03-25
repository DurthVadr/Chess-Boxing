shader_type canvas_item;

// Balatro-inspired CRT: scanlines, curvature, chromatic aberration, vignette, grain
uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_nearest;
uniform float scanline_intensity : hint_range(0.0, 1.0) = 0.18;
uniform float vignette_intensity : hint_range(0.0, 1.0) = 0.35;
uniform float aberration_amount : hint_range(0.0, 5.0) = 1.2;
uniform float curvature : hint_range(0.0, 10.0) = 2.5;
uniform float grain_amount : hint_range(0.0, 0.5) = 0.06;
uniform float brightness : hint_range(0.8, 1.2) = 1.0;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

vec2 curve_uv(vec2 uv) {
	uv = uv * 2.0 - 1.0;
	vec2 offset = abs(uv.yx) / vec2(curvature);
	uv = uv + uv * offset * offset;
	uv = uv * 0.5 + 0.5;
	return uv;
}

void fragment() {
	vec2 uv = curve_uv(SCREEN_UV);

	// Out of bounds — black border; otherwise apply CRT effects
	bool in_bounds = uv.x >= 0.0 && uv.x <= 1.0 && uv.y >= 0.0 && uv.y <= 1.0;

	vec3 col = vec3(0.0);

	if (in_bounds) {
		// Chromatic aberration — RGB split
		float ab = aberration_amount / 1000.0;
		float r = texture(screen_texture, vec2(uv.x + ab, uv.y)).r;
		float g = texture(screen_texture, uv).g;
		float b = texture(screen_texture, vec2(uv.x - ab, uv.y)).b;
		col = vec3(r, g, b);

		// Scanlines
		float scanline = sin(uv.y * 720.0 * 3.14159) * 0.5 + 0.5;
		scanline = pow(scanline, 1.8);
		col *= 1.0 - scanline_intensity * (1.0 - scanline);

		// Vignette — dark edges
		float vig = uv.x * uv.y * (1.0 - uv.x) * (1.0 - uv.y);
		vig = clamp(pow(16.0 * vig, vignette_intensity), 0.0, 1.0);
		col *= vig;

		// Film grain — animated
		float grain = (hash(uv * 512.0 + vec2(TIME * 5.0)) - 0.5) * grain_amount;
		col += grain;

		// Brightness
		col *= brightness;
	}

	COLOR = vec4(col, 1.0);
}
