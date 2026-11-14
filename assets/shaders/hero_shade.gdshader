shader_type canvas_item;
render_mode blend_mix, unshaded;

uniform float strength = 0.48;

void fragment() {
	vec2 p = (UV - vec2(0.5, 0.46)) / vec2(0.78, 0.66);
	float r = length(p);
	float a = smoothstep(1.2, 0.02, r) * strength;
	COLOR = vec4(0.012, 0.016, 0.03, a);
}
