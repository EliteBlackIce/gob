shader_type spatial;
render_mode cull_disabled;
// "Hand-painted" look: warm key light, cool tinted fill in shade, soft light wrap,
// procedural brush-stroke variation, wood grain, painted-edge wear and a rim glint.
// Vertex colour: rgb = baked ambient-occlusion tint, a = 1 - edge-wear mask.

uniform vec4 albedo : source_color = vec4(1.0);
uniform vec4 albedo_b : source_color = vec4(1.0);
uniform float variation = 0.25;
uniform float noise_scale = 2.5;
uniform vec3 stroke_axis = vec3(0.0, 1.0, 0.0);
uniform float stroke_stretch = 1.0;
uniform float grain = 0.0;
uniform float grain_scale = 9.0;
uniform vec4 wear_color : source_color = vec4(0.86, 0.72, 0.5, 1.0);
uniform float wear = 0.0;
uniform float flat_amount = 0.0;
uniform float roughness = 0.8;
uniform float specular = 0.2;
uniform float metallic = 0.0;
uniform vec4 rim_color : source_color = vec4(1.0, 0.8, 0.55, 1.0);
uniform float rim = 0.3;
uniform vec4 emission_color : source_color = vec4(1.0, 1.0, 1.0, 0.0);
uniform float emission_strength = 0.0;
uniform float wrap = 0.2;
uniform vec4 shadow_tint : source_color = vec4(0.42, 0.38, 0.72, 1.0);
uniform float shade_fill = 0.22;
uniform float sss = 0.0;
uniform vec4 sss_color : source_color = vec4(1.0, 0.55, 0.3, 1.0);
uniform float ao_strength = 1.0;
uniform float bottom_dark = 0.0;
uniform float wind = 0.0;

varying vec3 lpos;
varying vec3 wpos;
varying vec4 vcol;

float hash3(vec3 p) {
	p = fract(p * 0.3183099 + vec3(0.1, 0.2, 0.3));
	p *= 17.0;
	return fract(p.x * p.y * p.z * (p.x + p.y + p.z));
}

float vnoise(vec3 p) {
	vec3 i = floor(p);
	vec3 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(
		mix(mix(hash3(i), hash3(i + vec3(1, 0, 0)), f.x), mix(hash3(i + vec3(0, 1, 0)), hash3(i + vec3(1, 1, 0)), f.x), f.y),
		mix(mix(hash3(i + vec3(0, 0, 1)), hash3(i + vec3(1, 0, 1)), f.x), mix(hash3(i + vec3(0, 1, 1)), hash3(i + vec3(1, 1, 1)), f.x), f.y),
		f.z);
}

float fbm(vec3 p) {
	return vnoise(p) * 0.55 + vnoise(p * 2.1) * 0.3 + vnoise(p * 4.3) * 0.15;
}

void vertex() {
	if (wind > 0.0) {
		vec3 w0 = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
		float amt = wind * (clamp(VERTEX.y * 0.22, 0.0, 1.5) + length(VERTEX.xz) * 0.2);
		VERTEX.x += sin(TIME * 1.5 + w0.x * 0.35 + w0.z * 0.27) * amt;
		VERTEX.z += cos(TIME * 1.2 + w0.z * 0.31 + w0.x * 0.22) * amt * 0.6;
	}
	lpos = VERTEX;
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	vcol = COLOR;
}

void fragment() {
	// brush-stroke colour variation, optionally stretched along an axis
	vec3 sa = normalize(stroke_axis);
	vec3 q = lpos * noise_scale;
	q -= sa * dot(q, sa) * (1.0 - 1.0 / max(stroke_stretch, 0.01));
	float n = fbm(q);
	vec3 base = mix(albedo.rgb, albedo_b.rgb, smoothstep(0.25, 0.75, n) * variation * 2.0);
	base *= 0.92 + 0.16 * vnoise(lpos * noise_scale * 7.0);

	// wood grain streaks (stretched along stroke_axis)
	if (grain > 0.0) {
		vec3 g = lpos * grain_scale;
		g -= sa * dot(g, sa) * 0.93;
		float streak = vnoise(g) * 0.6 + vnoise(g * 2.3) * 0.4;
		float rings = 0.5 + 0.5 * sin(dot(lpos, cross(sa, vec3(0.0, 0.0, 1.0)) ) * grain_scale * 2.2 + streak * 6.0);
		base *= 1.0 - grain * (0.55 * (streak - 0.5) + 0.25 * (rings - 0.5));
	}

	// edge wear: paint chips away to bare material on bevels
	float edge = 1.0 - vcol.a;
	float chip = smoothstep(0.35, 0.8, vnoise(lpos * 14.0) + edge * 0.6);
	base = mix(base, wear_color.rgb, clamp(wear * edge * chip * 1.6, 0.0, 1.0));

	// baked AO + a little darkening toward the base of objects
	vec3 ao = mix(vec3(1.0), vcol.rgb, ao_strength);
	base *= ao;
	ALBEDO = base;

	vec3 n_s = FRONT_FACING ? NORMAL : -NORMAL;
	vec3 n_f = normalize(cross(dFdx(VERTEX), dFdy(VERTEX)));
	NORMAL = normalize(mix(n_s, n_f, flat_amount));
	ROUGHNESS = roughness;
	SPECULAR = specular;
	METALLIC = metallic;

	float fres = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 3.0);
	vec3 em = mix(base, emission_color.rgb, emission_color.a) * emission_strength;
	EMISSION = rim_color.rgb * fres * rim * 0.4 + em;
}

void light() {
	float ndl = dot(NORMAL, LIGHT);
	float wr = clamp((ndl + wrap) / (1.0 + wrap), 0.0, 1.0);
	float soft = smoothstep(0.02, 0.98, wr);
	soft = soft * soft * (1.6 - 0.6 * soft);
	float lit = soft * ATTENUATION;
	vec3 diff = LIGHT_COLOR * lit;
	if (LIGHT_IS_DIRECTIONAL) {
		diff += LIGHT_COLOR * (1.0 - lit) * shade_fill * shadow_tint.rgb;
	}
	if (sss > 0.0) {
		float t = pow(clamp(dot(VIEW, -LIGHT + NORMAL * 0.35), 0.0, 1.0), 2.5);
		diff += sss_color.rgb * LIGHT_COLOR * t * sss * ATTENUATION;
	}
	DIFFUSE_LIGHT += diff * (1.0 / PI);
	vec3 h = normalize(LIGHT + VIEW);
	float shin = mix(6.0, 120.0, 1.0 - roughness);
	float s = pow(max(dot(NORMAL, h), 0.0), shin) * specular * ATTENUATION * step(0.0, ndl);
	SPECULAR_LIGHT += LIGHT_COLOR * s * (1.0 / PI) * (0.5 + metallic);
}
