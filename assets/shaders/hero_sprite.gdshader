shader_type canvas_item;
render_mode blend_premul_alpha, unshaded;

void fragment() {
	vec4 tex = texture(TEXTURE, UV);
	vec2 p = (UV - vec2(0.5, 0.46)) / vec2(0.55, 0.50);
	float r = length(p);
	float vignette = smoothstep(1.0, 0.42, r);
	float frame = smoothstep(0.0, 0.055, UV.x) * smoothstep(1.0, 0.945, UV.x);
	frame *= smoothstep(0.0, 0.05, UV.y) * smoothstep(1.0, 0.95, UV.y);
	float lum = dot(tex.rgb, vec3(0.2126, 0.7152, 0.0722));
	float haze = smoothstep(0.22, 0.06, lum) * smoothstep(0.88, 0.22, tex.a);
	float a = tex.a * vignette * frame * (1.0 - haze);
	COLOR = vec4(tex.rgb * a, a);
}
