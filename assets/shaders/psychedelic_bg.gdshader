shader_type canvas_item;

// Swirling lava-lamp / kaleidoscope background.
// Procedural — no textures required.

uniform float speed : hint_range(0.01, 1.0) = 0.08;
uniform float warp_strength : hint_range(0.0, 5.0) = 1.8;
uniform float color_shift_speed : hint_range(0.01, 2.0) = 0.25;
uniform float kaleidoscope_segments : hint_range(2.0, 12.0) = 6.0;
uniform float brightness : hint_range(0.0, 1.0) = 0.2;
uniform float saturation : hint_range(0.0, 2.0) = 1.0;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	float a = hash(i);
	float b = hash(i + vec2(1.0, 0.0));
	float c = hash(i + vec2(0.0, 1.0));
	float d = hash(i + vec2(1.0, 1.0));
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(a, b, u.x) + (c - a) * u.y * (1.0 - u.x) + (d - b) * u.x * u.y;
}

float fbm(vec2 p) {
	float val = 0.0;
	float amp = 0.5;
	for (int i = 0; i < 5; i++) {
		val += amp * noise(p);
		p *= 2.1;
		amp *= 0.5;
	}
	return val;
}

vec3 hsv2rgb(vec3 c) {
	vec3 p = abs(fract(c.xxx + vec3(1.0, 2.0/3.0, 1.0/3.0)) * 6.0 - 3.0);
	return c.z * mix(vec3(1.0), clamp(p - 1.0, 0.0, 1.0), c.y);
}

void fragment() {
	vec2 uv = UV * 2.0 - 1.0;
	float t = TIME * speed;

	// Kaleidoscope fold
	float angle = atan(uv.y, uv.x);
	float radius = length(uv);
	float segment = 3.14159265 * 2.0 / kaleidoscope_segments;
	angle = mod(angle, segment);
	angle = abs(angle - segment * 0.5);
	uv = vec2(cos(angle), sin(angle)) * radius;

	// Domain warp for the lava-lamp look
	vec2 warp = vec2(
		fbm(uv * 2.0 + vec2(t * 0.7, -t * 0.3)),
		fbm(uv * 2.0 + vec2(-t * 0.5, t * 0.9))
	);
	vec2 warped = uv + warp * warp_strength * 0.4;

	// Second pass warp for extra swirl
	float n1 = fbm(warped * 1.5 + vec2(t * 0.3));
	float n2 = fbm(warped * 2.3 - vec2(t * 0.4, t * 0.2));
	float pattern = n1 * 0.6 + n2 * 0.4;

	// Map to shifting hues
	float hue = fract(pattern * 0.8 + t * color_shift_speed);
	vec3 col = hsv2rgb(vec3(hue, saturation, brightness));

	// Add deep black wells for contrast
	float depth = smoothstep(0.2, 0.6, pattern);
	col *= depth;

	// Pulsating rim glow at edges
	float rim = 1.0 - smoothstep(0.6, 1.4, radius);
	col *= rim * 0.9 + 0.1;

	COLOR = vec4(col, 1.0);
}
