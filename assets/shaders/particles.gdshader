shader_type canvas_item;

// Ambient floating dust / ember particles rendered as a full-screen overlay.
// Procedural — no textures needed. Draws small glowing dots that drift upward.

uniform float particle_count : hint_range(10.0, 120.0) = 45.0;
uniform float particle_speed : hint_range(0.01, 0.15) = 0.04;
uniform float particle_size : hint_range(0.5, 4.0) = 1.8;
uniform vec4 particle_color_a : source_color = vec4(0.90, 0.78, 0.30, 0.35); // gold
uniform vec4 particle_color_b : source_color = vec4(0.55, 0.45, 0.25, 0.20); // dim amber
uniform float drift_amount : hint_range(0.0, 0.1) = 0.03;
uniform float depth_variation : hint_range(0.0, 1.0) = 0.6;

float hash_f(float n) {
	return fract(sin(n) * 43758.5453);
}

vec2 hash_v2(float n) {
	return vec2(hash_f(n), hash_f(n + 127.231));
}

void fragment() {
	vec2 uv = UV;
	float aspect = SCREEN_PIXEL_SIZE.y / SCREEN_PIXEL_SIZE.x;
	vec2 screen_size = 1.0 / SCREEN_PIXEL_SIZE;
	float t = TIME;

	float total_alpha = 0.0;
	vec3 total_color = vec3(0.0);

	for (float i = 0.0; i < particle_count; i += 1.0) {
		// Unique seed per particle
		vec2 seed = hash_v2(i * 73.156);
		float depth = mix(0.4, 1.0, seed.x * depth_variation + (1.0 - depth_variation));

		// Base position (wrapping)
		float px = fract(seed.x + sin(t * 0.3 * depth + i * 1.7) * drift_amount);
		float py = fract(seed.y - t * particle_speed * depth);

		// Distance from this pixel to particle center
		vec2 p_pos = vec2(px, py);
		vec2 diff = uv - p_pos;
		diff.x *= aspect;

		float dist = length(diff) * screen_size.x;
		float radius = particle_size * depth;

		// Soft circle falloff
		float alpha = smoothstep(radius, radius * 0.2, dist);

		// Twinkle
		float twinkle = 0.6 + 0.4 * sin(t * (2.0 + seed.y * 3.0) + i * 5.0);
		alpha *= twinkle * depth;

		// Color blend based on depth
		vec3 pc = mix(particle_color_b.rgb, particle_color_a.rgb, depth);
		float pa = mix(particle_color_b.a, particle_color_a.a, depth);

		total_color += pc * alpha * pa;
		total_alpha += alpha * pa;
	}

	total_alpha = clamp(total_alpha, 0.0, 0.5);
	COLOR = vec4(total_color, total_alpha);
}
