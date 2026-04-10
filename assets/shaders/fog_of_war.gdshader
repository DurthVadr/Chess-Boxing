shader_type canvas_item;

uniform float fog_alpha : hint_range(0.0, 1.0) = 0.0;
uniform float fog_blur : hint_range(0.0, 1.0) = 0.0;
uniform float noise_scale : hint_range(1.0, 12.0) = 5.0;
uniform vec4 fog_color : source_color = vec4(0.05, 0.04, 0.08, 1.0);

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

void fragment() {
	vec2 uv = UV;
	float t = TIME * 0.35;

	// Base noise field
	vec2 p = uv * noise_scale * 6.0;
	float n1 = noise(p + vec2(t, -t));
	float n2 = noise(p * 1.7 + vec2(-t * 1.3, t * 0.9));
	float n = (n1 * 0.65 + n2 * 0.35);

	// "Blur" here is interpreted as softening / spreading the fog blobs.
	// Higher blur => smoother threshold and less high-frequency detail.
	float blur = clamp(fog_blur, 0.0, 1.0);
	float softness = mix(0.08, 0.28, blur);
	float threshold = mix(0.55, 0.42, blur);

	float fog_mask = smoothstep(threshold - softness, threshold + softness, n);
	float a = fog_alpha * fog_mask;

	COLOR = vec4(fog_color.rgb, a);
}

