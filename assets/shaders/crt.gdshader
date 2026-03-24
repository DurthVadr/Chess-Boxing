shader_type canvas_item;

// CRT/Scanline shader — Balatro-inspired
uniform float scanline_intensity : hint_range(0.0, 1.0) = 0.15;
uniform float vignette_intensity : hint_range(0.0, 1.0) = 0.3;
uniform float aberration_amount : hint_range(0.0, 5.0) = 1.0;
uniform float curvature : hint_range(0.0, 10.0) = 2.0;
uniform float grain_amount : hint_range(0.0, 0.5) = 0.05;

// Simple hash for grain
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
	vec2 uv = curve_uv(UV);

	// Out of bounds — black
	if (uv.x < 0.0 || uv.x > 1.0 || uv.y < 0.0 || uv.y > 1.0) {
		COLOR = vec4(0.0, 0.0, 0.0, 1.0);
		return;
	}

	// Chromatic aberration
	float aberration = aberration_amount / 1000.0;
	float r = texture(TEXTURE, vec2(uv.x + aberration, uv.y)).r;
	float g = texture(TEXTURE, uv).g;
	float b = texture(TEXTURE, vec2(uv.x - aberration, uv.y)).b;
	vec3 col = vec3(r, g, b);

	// Scanlines
	float scanline = sin(uv.y * 800.0) * 0.5 + 0.5;
	col *= 1.0 - scanline_intensity * (1.0 - scanline);

	// Vignette
	float vignette = uv.x * uv.y * (1.0 - uv.x) * (1.0 - uv.y);
	vignette = clamp(pow(16.0 * vignette, vignette_intensity), 0.0, 1.0);
	col *= vignette;

	// Film grain
	float grain = hash(uv + vec2(TIME * 0.1)) * grain_amount;
	col += grain;

	COLOR = vec4(col, texture(TEXTURE, uv).a);
}
