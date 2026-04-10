shader_type canvas_item;

// Psychedelic CRT: heavy bloom, wavy scanlines, fisheye warp,
// chromatic aberration, phosphor glow, vignette, grain, flicker
uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_nearest;
uniform float scanline_intensity : hint_range(0.0, 1.0) = 0.12;
uniform float vignette_intensity : hint_range(0.0, 1.0) = 0.30;
uniform float aberration_amount : hint_range(0.0, 5.0) = 0.8;
uniform float curvature : hint_range(0.0, 10.0) = 6.0;
uniform float grain_amount : hint_range(0.0, 0.5) = 0.04;
uniform float brightness : hint_range(0.8, 1.5) = 1.02;
uniform float bloom_amount : hint_range(0.0, 1.0) = 0.08;
uniform float flicker_amount : hint_range(0.0, 0.05) = 0.008;
uniform float phosphor_strength : hint_range(0.0, 1.0) = 0.15;
// Psychedelic additions
uniform float scanline_warp : hint_range(0.0, 10.0) = 0.0;
uniform float fisheye : hint_range(0.0, 1.0) = 0.0;
uniform float bloom_glow : hint_range(0.0, 1.0) = 0.0;
uniform float color_bleed : hint_range(0.0, 1.0) = 0.0;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

vec2 curve_uv(vec2 uv) {
	uv = uv * 2.0 - 1.0;
	// Barrel distortion (original)
	vec2 offset = abs(uv.yx) / vec2(curvature);
	uv = uv + uv * offset * offset;
	// Fisheye warp (additional radial distortion)
	if (fisheye > 0.0) {
		float r2 = dot(uv, uv);
		uv *= 1.0 + fisheye * r2 * 0.3;
	}
	uv = uv * 0.5 + 0.5;
	return uv;
}

void fragment() {
	vec2 uv = curve_uv(SCREEN_UV);

	bool in_bounds = uv.x >= 0.0 && uv.x <= 1.0 && uv.y >= 0.0 && uv.y <= 1.0;
	vec3 col = vec3(0.0);

	if (in_bounds) {
		// Chromatic aberration — RGB split with slight vertical offset
		float ab = aberration_amount / 1000.0;
		float r = texture(screen_texture, vec2(uv.x + ab, uv.y + ab * 0.3)).r;
		float g = texture(screen_texture, uv).g;
		float b = texture(screen_texture, vec2(uv.x - ab, uv.y - ab * 0.3)).b;
		col = vec3(r, g, b);

		// Multi-pass bloom: 8-tap Gaussian-ish sampling at two radii
		vec3 bloom = vec3(0.0);
		float bloom_size_near = 2.0 / 1024.0;
		float bloom_size_far = 5.0 / 1024.0;
		// Near samples (4-tap)
		bloom += texture(screen_texture, uv + vec2(-bloom_size_near, 0.0)).rgb;
		bloom += texture(screen_texture, uv + vec2(bloom_size_near, 0.0)).rgb;
		bloom += texture(screen_texture, uv + vec2(0.0, -bloom_size_near)).rgb;
		bloom += texture(screen_texture, uv + vec2(0.0, bloom_size_near)).rgb;
		// Far samples (4-tap diagonal) — gives wider glow spread
		bloom += texture(screen_texture, uv + vec2(-bloom_size_far, -bloom_size_far)).rgb * 0.7;
		bloom += texture(screen_texture, uv + vec2(bloom_size_far, -bloom_size_far)).rgb * 0.7;
		bloom += texture(screen_texture, uv + vec2(-bloom_size_far, bloom_size_far)).rgb * 0.7;
		bloom += texture(screen_texture, uv + vec2(bloom_size_far, bloom_size_far)).rgb * 0.7;
		bloom /= 6.8; // Weighted average
		// Standard bloom: brighten bright areas
		col += max(bloom - 0.4, vec3(0.0)) * bloom_amount * 5.0;
		// Bloom glow: add soft overall glow to all bright elements
		col += bloom * bloom_glow * 0.6;

		// Color bleed: slight hue leak between channels for psychedelic warmth
		if (color_bleed > 0.0) {
			col.r += col.g * color_bleed * 0.15;
			col.g += col.b * color_bleed * 0.12;
			col.b += col.r * color_bleed * 0.1;
		}

		// Phosphor sub-pixel pattern (RGB stripes)
		float px = fract(uv.x * 640.0);
		vec3 phosphor = vec3(
			smoothstep(0.0, 0.33, px) - smoothstep(0.33, 0.66, px),
			smoothstep(0.33, 0.66, px) - smoothstep(0.66, 1.0, px),
			smoothstep(0.66, 1.0, px)
		);
		col = mix(col, col * (vec3(1.0) + phosphor * 0.5), phosphor_strength);

		// Wavy scanlines — sine displacement makes them wobble
		float scan_y = uv.y;
		if (scanline_warp > 0.0) {
			scan_y += sin(uv.x * 15.0 + TIME * 2.5) * scanline_warp * 0.001;
			scan_y += sin(uv.x * 7.0 - TIME * 1.8) * scanline_warp * 0.0006;
		}
		float scanline = sin(scan_y * 720.0 * 3.14159) * 0.5 + 0.5;
		scanline = pow(scanline, 1.5);
		col *= 1.0 - scanline_intensity * (1.0 - scanline);

		// Secondary fine scanlines (subtle)
		float fine_scan = sin(scan_y * 1440.0 * 3.14159) * 0.5 + 0.5;
		col *= 1.0 - scanline_intensity * 0.15 * (1.0 - fine_scan);

		// Vignette — smooth dark edges
		float vig = uv.x * uv.y * (1.0 - uv.x) * (1.0 - uv.y);
		vig = clamp(pow(16.0 * vig, vignette_intensity), 0.0, 1.0);
		col *= vig;

		// Film grain — animated
		float grain = (hash(uv * 512.0 + vec2(TIME * 5.0)) - 0.5) * grain_amount;
		col += grain;

		// Subtle flicker (whole-screen brightness variation)
		float flicker = 1.0 + flicker_amount * sin(TIME * 8.0) * cos(TIME * 3.7);
		col *= flicker;

		// Brightness
		col *= brightness;
	}

	COLOR = vec4(col, 1.0);
}
