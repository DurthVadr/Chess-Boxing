shader_type canvas_item;

uniform float speed : hint_range(0.0, 0.5) = 0.04;
uniform float cell_size : hint_range(0.01, 0.5) = 0.055;
uniform vec4 color_a : source_color = vec4(0.07, 0.05, 0.11, 1.0);
uniform vec4 color_b : source_color = vec4(0.04, 0.03, 0.07, 1.0);

void fragment() {
	// Diagonal scroll: same offset in X and Y creates 45-degree movement
	vec2 uv = UV + vec2(TIME * speed, TIME * speed);
	float check = mod(floor(uv.x / cell_size) + floor(uv.y / cell_size), 2.0);
	COLOR = mix(color_a, color_b, check);
}
