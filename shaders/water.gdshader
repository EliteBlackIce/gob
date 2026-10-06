shader_type spatial;
render_mode cull_disabled, depth_draw_always, unshaded;
// Depth-aware stylised sea. A height texture of the island lets the water know exactly
// how deep it is: turquoise shallows, animated foam where it meets the shore, deep blue
// offshore, sun glints on a ripple normal.

uniform sampler2D height_tex : filter_linear, repeat_disable;
uniform vec2 tex_origin = vec2(-72.0, -96.0);
uniform vec2 tex_size = vec2(144.0, 192.0);
uniform vec3 sun_dir = vec3(0.4, 0.8, 0.4);
uniform vec4 deep_color : source_color = vec4(0.03, 0.27, 0.5, 1.0);
uniform vec4 mid_color : source_color = vec4(0.06, 0.55, 0.7, 1.0);
uniform vec4 shallow_color : source_color = vec4(0.28, 0.84, 0.76, 1.0);
uniform vec4 foam_color : source_color = vec4(0.97, 1.0, 1.0, 1.0);
uniform vec4 sky_tint : source_color = vec4(0.68, 0.86, 0.96, 1.0);

varying vec3 wpos;

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1, 0)), f.x), mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), f.x), f.y);
}

void vertex() {
	vec3 w = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float h = sin(w.x * 0.33 + TIME * 1.0) * 0.1 + sin(w.z * 0.27 + TIME * 0.75) * 0.1 + sin((w.x + w.z) * 0.6 + TIME * 1.7) * 0.04;
	VERTEX.y += h;
	wpos = w;
}

void fragment() {
	vec2 uv = (wpos.xz - tex_origin) / tex_size;
	float inside = step(0.0, uv.x) * step(uv.x, 1.0) * step(0.0, uv.y) * step(uv.y, 1.0);
	float ground = mix(-6.0, texture(height_tex, clamp(uv, 0.0, 1.0)).r, inside);
	float depth = 0.0 - ground;

	// colour by depth
	float s1 = 1.0 - smoothstep(0.0, 1.6, depth);
	float s2 = 1.0 - smoothstep(0.8, 5.5, depth);
	vec3 col = mix(deep_color.rgb, mid_color.rgb, s2);
	col = mix(col, shallow_color.rgb, s1);
	float bands = vnoise(wpos.xz * 0.12 + TIME * 0.03) * 0.5 + vnoise(wpos.xz * 0.5 - TIME * 0.05) * 0.25;
	col *= 0.9 + 0.2 * bands;

	// caustic shimmer in the shallows
	float c1 = vnoise(wpos.xz * 1.6 + vec2(TIME * 0.5, TIME * 0.3));
	float c2 = vnoise(wpos.xz * 2.2 - vec2(TIME * 0.4, -TIME * 0.35));
	float caus = smoothstep(0.55, 0.9, c1 * c2 * 2.2);
	col += shallow_color.rgb * caus * 0.35 * s1;

	// shoreline foam: lapping bands that travel in and out
	float wave = sin(depth * 5.0 - TIME * 1.2 + vnoise(wpos.xz * 0.7) * 3.0) * 0.5 + 0.5;
	float edge = 1.0 - smoothstep(0.0, 0.55, depth);
	float foam = edge * smoothstep(0.35, 0.8, wave + (1.0 - smoothstep(0.0, 0.18, depth)) * 0.6);
	foam += (1.0 - smoothstep(0.0, 0.1, depth)) * 0.6;
	float lap = 1.0 - smoothstep(0.55, 1.3, depth);
	foam += lap * smoothstep(0.82, 1.0, sin(depth * 7.0 - TIME * 1.6 + vnoise(wpos.xz * 0.9) * 4.0) * 0.5 + 0.5) * 0.35;
	foam = clamp(foam, 0.0, 1.0);
	col = mix(col, foam_color.rgb, foam * 0.9);

	// sky reflection at grazing angles + sun glints on a ripple normal
	vec3 V = normalize(CAMERA_POSITION_WORLD - wpos);
	vec3 n = normalize(vec3((vnoise(wpos.xz * 1.1 + TIME * 0.4) - 0.5) * 0.5, 1.0, (vnoise(wpos.xz * 1.1 - TIME * 0.35 + 7.0) - 0.5) * 0.5));
	float fres = pow(1.0 - clamp(dot(vec3(0.0, 1.0, 0.0), V), 0.0, 1.0), 3.0);
	col = mix(col, sky_tint.rgb, fres * 0.6);
	vec3 R = reflect(-normalize(sun_dir), n);
	float glint = pow(max(dot(R, V), 0.0), 220.0);
	col += vec3(1.0, 0.95, 0.8) * glint * 1.2;

	ALBEDO = col;
	float shore_fade = smoothstep(0.0, 0.25, depth);
	ALPHA = mix(0.0, mix(0.62, 0.97, smoothstep(0.4, 3.5, depth)), shore_fade);
	ALPHA = max(ALPHA, foam * 0.9 * step(0.0, depth));
	ALPHA = max(ALPHA, fres * 0.4 * shore_fade);
	if (inside < 0.5) { ALPHA = 0.97; }
}
