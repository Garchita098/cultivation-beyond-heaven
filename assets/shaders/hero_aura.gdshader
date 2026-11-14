shader_type canvas_item;
render_mode blend_add, unshaded;

uniform float tier = 0.0;
uniform float progress = 0.0;
uniform vec2 canvas_size = vec2(720.0, 760.0);
uniform vec3 path_tint = vec3(-1.0, -1.0, -1.0);
uniform float reduced = 0.0;

float hsh(float n) {
	return fract(sin(n) * 43758.5453);
}

vec3 aura_rgb(float t) {
	vec3 mortal = vec3(0.55, 0.64, 0.75);
	vec3 qi = vec3(0.361, 0.882, 1.0);
	vec3 jade = vec3(0.239, 0.859, 0.627);
	vec3 gold = vec3(0.941, 0.780, 0.369);
	vec3 dao = vec3(0.655, 0.545, 0.980);
	if (t < 1.0) {
		return mix(mortal, qi, clamp(t, 0.0, 1.0));
	}
	if (t < 2.0) {
		return mix(qi, jade, clamp(t - 1.0, 0.0, 1.0));
	}
	if (t < 3.0) {
		return mix(jade, gold, clamp(t - 2.0, 0.0, 1.0));
	}
	return mix(gold, dao, clamp(t - 3.0, 0.0, 1.0));
}

void fragment() {
	vec2 shortest = vec2(min(canvas_size.x, canvas_size.y));
	vec2 p = (UV - vec2(0.5, 0.42)) * canvas_size / max(shortest.x, 1.0);
	vec3 aura = aura_rgb(tier);
	if (path_tint.x >= 0.0) {
		aura = mix(aura, path_tint, 0.72);
	}
	float motion = reduced > 0.5 ? 0.0 : 1.0;
	float pulse = 0.72 + 0.28 * sin(TIME * (1.2 + tier * 0.12)) * motion;
	vec2 c = p;
	float glow = exp(-dot(c, c) * (7.5 - tier * 0.4)) * pulse;
	vec3 col = aura * glow * 0.55;
	int rings = reduced > 0.5 ? 2 : 3;
	for (int i = 0; i < 3; i++) {
		if (i >= rings) {
			break;
		}
		float fi = float(i);
		float breathe = 0.01 * sin(TIME * 1.3 + fi) * motion;
		float rr = 0.18 + fi * 0.07 + breathe;
		float w = abs(length(c * vec2(1.0, 0.9)) - rr);
		col += aura * smoothstep(0.02, 0.0, w) * (0.35 + tier * 0.05) * pulse;
	}
	int motes = reduced > 0.5 ? 0 : 10;
	for (int i = 0; i < 10; i++) {
		if (i >= motes) {
			break;
		}
		float fi = float(i);
		float dir = hsh(fi + 3.0) > 0.5 ? 1.0 : -1.0;
		float ang = fi * 0.9 + TIME * (0.28 + tier * 0.08) * dir * motion;
		float rad = 0.12 + hsh(fi + 9.0) * 0.22;
		vec2 sp = vec2(cos(ang), sin(ang) * 0.72) * rad;
		float d = length(c - sp);
		col += aura * smoothstep(0.02, 0.0, d) * 0.7;
	}
	float ang = atan(c.x, -c.y);
	float a01 = fract((ang + 3.14159265) / 6.2831853);
	float ring_d = abs(length(c * vec2(1.0, 0.9)) - 0.42);
	float on_ring = smoothstep(0.018, 0.004, ring_d);
	col += aura * on_ring * step(a01, clamp(progress, 0.0, 1.0)) * 0.85;
	COLOR = vec4(col, 1.0);
}
