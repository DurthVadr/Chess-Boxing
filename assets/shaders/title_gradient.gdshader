shader_type canvas_item;

uniform vec4 top_color : source_color = vec4(1.0, 0.98, 0.9, 1.0);
uniform vec4 bottom_color : source_color = vec4(0.9, 0.75, 0.25, 1.0);

void fragment() {
	// TEXTURE holds the label's rendered glyphs; UV.y drives the gradient
	vec4 tex = texture(TEXTURE, UV);
	vec4 grad = mix(top_color, bottom_color, UV.y);
	// Preserve the text alpha so the gradient only appears on glyph pixels
	COLOR = vec4(grad.rgb, tex.a * grad.a);
}
