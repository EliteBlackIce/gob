shader_type spatial;
render_mode cull_disabled, depth_draw_always, unshaded;
// Blocky sea. Everything is quantised to a 0.25 m pixel grid so the water looks like animated
// Minecraft water tiles: turquoise shallows, deep blue offshore, foam pixels along the shore,
// caustic sparkles in the shallows and a square-pixel sun glitter. A height texture of the
// island tells the shader how deep the water is at each point.

uniform sampler2D height_tex : filter_nearest, repeat_disable;
uniform vec2 tex_origin = vec2(-72.0, -96.0);
uniform vec2 tex_size = vec2(144.0, 192.0);
uniform vec4 deep_color : source_color = vec4(0.07, 0.30, 0.78, 1.0);
uniform vec4 mid_color : source_color = vec4(0.10, 0.52, 0.86, 1.0);
uniform vec4 shallow_color : source_color = vec4(0.30, 0.86, 0.84, 1.0);
uniform vec4 foam_color : source_color = vec4(0.96, 1.0, 1.0, 1.0);
uniform float pixel = 0.25;

varying vec3 wpos;

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 g = floor(wpos.xz / pixel) * pixel;
	vec2 uv = (g - tex_origin) / tex_size;
	float inside = step(0.0, uv.x) * step(uv.x, 1.0) * step(0.0, uv.y) * step(uv.y, 1.0);
	float ground = mix(-6.0, texture(height_tex, clamp(uv, 0.0, 1.0)).r, inside);
	float depth = -ground;
	float t = TIME;

	float n1 = hash(g * 0.9 + floor(t * 0.6));
	float tile = hash(floor(g * 0.5));
	vec3 col = mix(deep_color.rgb, mid_color.rgb, 1.0 - smoothstep(1.2, 6.0, depth));
	col = mix(col, shallow_color.rgb, 1.0 - smoothstep(0.1, 1.6, depth));
	col *= 0.92 + 0.12 * tile + 0.05 * n1;

	// drifting highlight pixels (water texture)
	float drift = hash(floor((g + vec2(t * 0.35, t * 0.2)) * 1.3));
	col += vec3(0.05, 0.09, 0.12) * step(0.9, drift);

	// caustic sparkles in the shallows
	float c = hash(floor((g + vec2(-t * 0.5, t * 0.3)) * 2.0));
	col += vec3(0.5, 0.9, 0.9) * step(0.94, c) * (1.0 - smoothstep(0.2, 2.2, depth));

	// shoreline foam: bands of pixels that wash in and out
	float wave = sin(depth * 6.0 - t * 1.3 + hash(floor(g * 0.5)) * 2.0);
	float foam = (1.0 - smoothstep(0.05, 0.55, depth)) * step(0.15, wave * 0.5 + 0.5 - 0.35 * smoothstep(0.1, 0.5, depth));
	foam = max(foam, 1.0 - smoothstep(0.0, 0.12, depth));
	col = mix(col, foam_color.rgb, clamp(foam, 0.0, 1.0) * 0.9);

	// square sun glitter
	float glit = step(0.985, hash(floor((g + vec2(t * 0.8, 0.0)) * 1.0)));
	col += vec3(1.0, 0.95, 0.8) * glit * 0.7;

	ALBEDO = col;
	float a = mix(0.55, 0.94, smoothstep(0.3, 4.0, depth));
	a = max(a * smoothstep(0.0, 0.18, depth + 0.02), foam * 0.85);
	ALPHA = inside > 0.5 ? clamp(a, 0.0, 1.0) : 0.94;
}
