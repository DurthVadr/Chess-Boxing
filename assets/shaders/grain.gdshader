shader_type canvas_item;

// Subtle film grain overlay

uniform float grain_amount : hint_range(0.0, 0.3) = 0.05;
uniform float grain_speed : hint_range(0.0, 20.0) = 10.0;

float random(vec2 co) {
	return fract(sin(dot(co.xy, vec2(12.9898, 78.233))) * 43758.5453);
}

void fragment() {
	vec4 original = texture(TEXTURE, UV);
	float noise = random(UV * TIME * grain_speed) * 2.0 - 1.0;
	vec3 grain = original.rgb + vec3(noise * grain_amount);
	COLOR = vec4(grain, original.a);
}
