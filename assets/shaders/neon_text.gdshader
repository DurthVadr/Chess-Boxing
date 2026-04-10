shader_type canvas_item;

// Neon-tube glow text effect.
// Apply to Label or RichTextLabel nodes.

uniform vec4 neon_color : source_color = vec4(0.9, 0.2, 1.0, 1.0);
uniform float glow_radius : hint_range(0.0, 0.03) = 0.012;
uniform float glow_intensity : hint_range(0.0, 4.0) = 2.0;
uniform float pulse_speed : hint_range(0.0, 5.0) = 1.8;
uniform float pulse_amount : hint_range(0.0, 0.5) = 0.2;
uniform float hue_shift : hint_range(0.0, 1.0) = 0.0;
uniform bool rainbow_mode = false;

vec3 hsv2rgb(vec3 c) {
	vec3 p = abs(fract(c.xxx + vec3(1.0, 2.0/3.0, 1.0/3.0)) * 6.0 - 3.0);
	return c.z * mix(vec3(1.0), clamp(p - 1.0, 0.0, 1.0), c.y);
}

vec3 rgb2hsv(vec3 c) {
	vec4 K = vec4(0.0, -1.0 / 3.0, 2.0 / 3.0, -1.0);
	vec4 p = mix(vec4(c.bg, K.wz), vec4(c.gb, K.xy), step(c.b, c.g));
	vec4 q = mix(vec4(p.xyw, c.r), vec4(c.r, p.yzx), step(p.x, c.r));
	float d = q.x - min(q.w, q.y);
	float e = 1.0e-10;
	return vec3(abs(q.z + (q.w - q.y) / (6.0 * d + e)), d / (q.x + e), q.x);
}

void fragment() {
	vec4 tex = texture(TEXTURE, UV);
	float t = TIME;

	// Pulse brightness
	float pulse = 1.0 - pulse_amount + pulse_amount * (sin(t * pulse_speed) * 0.5 + 0.5);

	// Sample glow by spreading alpha outward
	float glow_alpha = 0.0;
	float samples = 16.0;
	for (float i = 0.0; i < 16.0; i += 1.0) {
		float angle = i / samples * 6.28318;
		vec2 offset = vec2(cos(angle), sin(angle)) * glow_radius;
		glow_alpha += texture(TEXTURE, UV + offset).a;
	}
	glow_alpha /= samples;

	// Determine neon color (rainbow or fixed)
	vec3 n_color;
	if (rainbow_mode) {
		float hue = fract(t * 0.3 + UV.x * 0.5);
		n_color = hsv2rgb(vec3(hue, 1.0, 1.0));
	} else {
		vec3 hsv = rgb2hsv(neon_color.rgb);
		hsv.x = fract(hsv.x + hue_shift);
		n_color = hsv2rgb(hsv);
	}

	// Outer glow
	vec3 glow = n_color * glow_alpha * glow_intensity * pulse;

	// Core text: brighten the original text color, tinted with neon
	vec3 core = mix(tex.rgb, n_color, 0.3) * (1.0 + glow_intensity * 0.3) * pulse;

	// Composite
	vec3 result = mix(glow, core, tex.a);
	float result_a = max(tex.a, glow_alpha * 0.6);

	COLOR = vec4(result, result_a);
}
