shader_type canvas_item;
render_mode blend_mix, unshaded;

// tier: 0 mortal, 1 qi, 2 foundation, 3 core, 4+ beyond
uniform float tier = 0.0;
uniform float progress = 0.0;
uniform vec2 canvas_size = vec2(720.0, 760.0);
uniform vec3 path_tint = vec3(-1.0, -1.0, -1.0);

float hsh(float n) {
	return fract(sin(n) * 43758.5453);
}

float sd_circle(vec2 p, float r) {
	return length(p) - r;
}

float sd_seg(vec2 p, vec2 a, vec2 b, float r) {
	vec2 pa = p - a;
	vec2 ba = b - a;
	float h = clamp(dot(pa, ba) / max(dot(ba, ba), 0.0001), 0.0, 1.0);
	return length(pa - ba * h) - r;
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
	vec2 p = (UV - vec2(0.5, 0.44)) * canvas_size / shortest.x;
	vec3 sky_top = vec3(0.07, 0.09, 0.16);
	vec3 sky_bot = vec3(0.027, 0.035, 0.06);
	vec3 col = mix(sky_bot, sky_top, smoothstep(0.95, 0.15, UV.y));

	// Stars.
	for (int i = 0; i < 18; i++) {
		float fi = float(i);
		vec2 sp = vec2(hsh(fi * 2.3), hsh(fi * 5.1) * 0.42 + 0.02);
		float tw = 0.45 + 0.55 * sin(TIME * (0.8 + hsh(fi)) + fi);
		float d = length((UV - sp) * vec2(canvas_size.x / canvas_size.y, 1.0));
		col += vec3(0.75, 0.85, 1.0) * smoothstep(0.006, 0.0, d) * tw * 0.85;
	}

	// Moon.
	vec2 moon = vec2(0.72, 0.16);
	vec2 muv = (UV - moon) * vec2(canvas_size.x / canvas_size.y, 1.0);
	float md = length(muv);
	col += vec3(0.85, 0.88, 0.95) * smoothstep(0.055, 0.0, md);
	col += vec3(0.25, 0.35, 0.55) * smoothstep(0.22, 0.05, md) * 0.55;

	// Distant ridge, then a nearer one.
	float ridge_far = 0.62 + 0.045 * sin(UV.x * 9.0) + 0.03 * sin(UV.x * 17.0 + 1.2);
	float ridge_near = 0.74 + 0.07 * abs(sin(UV.x * 3.14159)) * -1.0 + 0.05 * sin(UV.x * 6.5);
	ridge_near = 0.78 - 0.09 * smoothstep(0.0, 1.0, abs(sin(UV.x * 3.2)));
	float far_m = smoothstep(0.012, -0.012, UV.y - ridge_far);
	float near_m = smoothstep(0.01, -0.02, UV.y - (0.80 - 0.07 * sin(UV.x * 2.4) * sin(UV.x * 2.4)));
	col = mix(col, vec3(0.09, 0.11, 0.16), far_m);
	col = mix(col, vec3(0.045, 0.055, 0.085), near_m);
	// Mist over the ridge.
	float mist = smoothstep(0.78, 0.62, UV.y) * smoothstep(0.95, 0.78, UV.y);
	col += vec3(0.18, 0.28, 0.32) * mist * 0.28;

	vec3 aura = aura_rgb(tier);
	if (path_tint.x >= 0.0) {
		aura = mix(aura, path_tint, 0.72);
	}
	float pulse = 0.70 + 0.30 * sin(TIME * (1.35 + tier * 0.15));
	float strength = 0.55 + tier * 0.22;
	vec2 c = p - vec2(0.0, 0.02);

	float glow = exp(-dot(c, c) * (10.0 - tier * 0.7)) * pulse * strength;
	col += aura * glow;

	// Concentric aura rings. More of them read as a higher rank.
	int rings = 2 + int(clamp(tier + 0.2, 0.0, 3.0));
	for (int i = 0; i < 5; i++) {
		if (i >= rings) {
			break;
		}
		float fi = float(i);
		float breathe = 0.012 * sin(TIME * 1.4 + fi);
		float rr = 0.16 + fi * 0.055 + breathe + tier * 0.008;
		float w = abs(length(c * vec2(1.0, 0.92)) - rr);
		float band = smoothstep(0.014, 0.0, w);
		col += aura * band * (0.28 + tier * 0.08) * pulse;
	}

	// Orbiting motes. Count scales a little with rank via alpha.
	for (int i = 0; i < 12; i++) {
		float fi = float(i);
		float dir = hsh(fi + 4.0) > 0.5 ? 1.0 : -1.0;
		float ang = fi * 0.85 + TIME * (0.35 + tier * 0.18) * dir;
		float rad = 0.12 + hsh(fi + 8.0) * (0.16 + tier * 0.03);
		vec2 sp = vec2(cos(ang), sin(ang) * 0.78) * rad;
		float d = length(c - sp);
		float spark = smoothstep(0.018 + tier * 0.002, 0.0, d);
		col += aura * spark * (0.45 + tier * 0.12);
	}

	// Meditating silhouette, in the same pixel-corrected space.
	vec2 f = c;
	float fig = sd_circle(f - vec2(0.0, -0.155), 0.038);
	fig = min(fig, sd_seg(f, vec2(0.0, -0.12), vec2(0.0, 0.01), 0.030));
	fig = min(fig, sd_seg(f, vec2(0.0, 0.0), vec2(-0.10, 0.09), 0.018));
	fig = min(fig, sd_seg(f, vec2(0.0, 0.0), vec2(0.10, 0.09), 0.018));
	fig = min(fig, sd_seg(f, vec2(-0.10, 0.09), vec2(-0.015, 0.115), 0.015));
	fig = min(fig, sd_seg(f, vec2(0.10, 0.09), vec2(0.015, 0.115), 0.015));
	fig = min(fig, sd_seg(f, vec2(-0.02, -0.04), vec2(-0.075, 0.055), 0.013));
	fig = min(fig, sd_seg(f, vec2(0.02, -0.04), vec2(0.075, 0.055), 0.013));
	fig = min(fig, sd_seg(f, vec2(0.0, -0.02), vec2(-0.11, 0.13), 0.022));
	fig = min(fig, sd_seg(f, vec2(0.0, -0.02), vec2(0.11, 0.13), 0.022));
	float body = smoothstep(0.010, 0.0, fig);
	col = mix(col, vec3(0.015, 0.02, 0.035), body);
	float rim = smoothstep(0.028, 0.0, abs(fig)) * (1.0 - body);
	col += aura * rim * (0.85 + 0.35 * pulse) * strength;

	// Lotus under the figure.
	float lotus = sd_seg(f, vec2(-0.13, 0.145), vec2(0.0, 0.105), 0.007);
	lotus = min(lotus, sd_seg(f, vec2(0.13, 0.145), vec2(0.0, 0.105), 0.007));
	lotus = min(lotus, sd_seg(f, vec2(-0.07, 0.165), vec2(0.0, 0.12), 0.006));
	lotus = min(lotus, sd_seg(f, vec2(0.07, 0.165), vec2(0.0, 0.12), 0.006));
	col += vec3(0.20, 0.55, 0.42) * smoothstep(0.012, 0.0, lotus) * 0.9;

	// Breakthrough ring. Track is faint; fill follows progress from the top.
	float ang = atan(c.x, -c.y);
	float a01 = fract((ang + 3.14159265) / 6.2831853);
	float ring_r = 0.34 + tier * 0.012;
	float ring_d = abs(length(c * vec2(1.0, 0.92)) - ring_r);
	float on_ring = smoothstep(0.016, 0.004, ring_d);
	float filled = step(a01, clamp(progress, 0.0, 1.0));
	col += vec3(0.10, 0.14, 0.20) * on_ring * 0.65;
	col += aura * on_ring * filled * (0.95 + 0.25 * pulse);

	// Ground glow where the lotus sits.
	float ground = smoothstep(0.22, 0.0, length((c - vec2(0.0, 0.16)) * vec2(1.4, 2.2)));
	col += aura * ground * 0.18 * strength;

	col = clamp(col, vec3(0.0), vec3(1.0));
	COLOR = vec4(col, 1.0);
}
