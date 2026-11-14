shader_type canvas_item;
render_mode blend_mix, unshaded;

uniform float reduced = 0.0;

void fragment() {
	float motion = reduced > 0.5 ? 0.0 : 1.0;
	float drift = sin(TIME * 0.1 + UV.x * 4.0) * 0.03 * motion;
	float low = smoothstep(0.42, 1.0, UV.y + drift);
	float top = smoothstep(0.22, 0.0, UV.y);
	float band = sin(UV.y * 9.0 + TIME * 0.15 * motion) * 0.5 + 0.5;
	float alpha = max(low * 0.38, top * 0.5) + band * low * 0.06 * motion;
	COLOR = vec4(0.02, 0.03, 0.07, alpha);
}
