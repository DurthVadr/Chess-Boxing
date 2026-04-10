shader_type canvas_item;

// Rainbow-cycling HP bar fill.
// Apply to the fill StyleBox of a ProgressBar or a ColorRect.

uniform float cycle_speed : hint_range(0.1, 3.0) = 0.35;
uniform float wave_frequency : hint_range(1.0, 10.0) = 3.0;
uniform float glow_amount : hint_range(0.0, 1.0) = 0.2;

vec3 hsv2rgb(vec3 c) {
	vec3 p = abs(fract(c.xxx + vec3(1.0, 2.0/3.0, 1.0/3.0)) * 6.0 - 3.0);
	return c.z * mix(vec3(1.0), clamp(p - 1.0, 0.0, 1.0), c.y);
}

void fragment() {
	vec4 tex = texture(TEXTURE, UV);

	// Rainbow hue slides across the bar and shifts over time
	float hue = fract(UV.x * wave_frequency * 0.1 + TIME * cycle_speed);
	vec3 rainbow = hsv2rgb(vec3(hue, 0.9, 1.0));

	// Glow pulse
	float pulse = 1.0 + glow_amount * (sin(TIME * 3.0 + UV.x * 10.0) * 0.5 + 0.5);

	// Apply rainbow to the bar fill (preserving alpha mask)
	vec3 result = rainbow * pulse * tex.a;

	COLOR = vec4(result, tex.a);
}
