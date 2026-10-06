shader_type spatial;
render_mode cull_disabled, depth_draw_always, unshaded;
// Stylised sea. Unshaded on purpose: the palette is authored, not lit.
// Turquoise near the island, deep blue offshore, foam rings, sun glints.

uniform vec3 island_center = vec3(0.0);
uniform vec2 island_radii = vec2(60.0, 86.0);
uniform vec4 deep_color : source_color = vec4(0.04, 0.33, 0.6, 0.96);
uniform vec4 shallow_color : source_color = vec4(0.22, 0.82, 0.76, 0.72);
uniform vec4 foam_color : source_color = vec4(0.97, 1.0, 1.0, 1.0);
uniform vec4 sky_tint : source_color = vec4(0.62, 0.84, 0.95, 1.0);

varying vec3 wpos;

void vertex() {
	vec3 w = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float h = sin(w.x * 0.35 + TIME * 1.1) * 0.12 + sin(w.z * 0.27 + TIME * 0.8) * 0.12;
	VERTEX.y += h;
	wpos = w;
}

void fragment() {
	vec2 q = (wpos.xz - island_center.xz) / island_radii;
	float r = length(q);
	float shore = 1.0 - smoothstep(0.86, 1.3, r);
	vec4 c = mix(deep_color, shallow_color, shore);
	// gentle bands of lighter / darker water
	float band = sin(wpos.x * 0.09 + sin(wpos.z * 0.07 + TIME * 0.2) * 2.0) * 0.5 + 0.5;
	vec3 col = c.rgb * (0.9 + 0.2 * band);
	// foam rings lapping at the shore
	float ring = sin((r - TIME * 0.02) * 95.0 + sin(wpos.x * 0.4 + TIME) * 1.5);
	float foam = smoothstep(0.84, 1.0, ring) * smoothstep(0.82, 0.93, r) * (1.0 - smoothstep(0.96, 1.1, r));
	col = mix(col, foam_color.rgb, foam * 0.75);
	// horizon fresnel: far water reflects the sky
	float fres = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 3.0);
	col = mix(col, sky_tint.rgb, fres * 0.55);
	// sun glints
	vec2 cell = floor(wpos.xz * 1.5 + vec2(TIME * 0.6, TIME * 0.3));
	float glint = step(0.992, fract(sin(dot(cell, vec2(12.9898, 78.233))) * 43758.5453));
	col += vec3(glint * 0.6);
	ALBEDO = col;
	ALPHA = mix(c.a, 1.0, max(foam * 0.7, fres * 0.4));
}
