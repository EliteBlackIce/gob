shader_type spatial;
render_mode cull_disabled;
// Painterly low-poly look: flat facets, warm rim light, per-patch colour jitter.

uniform vec4 albedo : source_color = vec4(1.0);
uniform float rim_amount = 0.5;
uniform vec4 rim_color : source_color = vec4(1.0, 0.78, 0.45, 1.0);
uniform float emission_strength = 0.0;
uniform float flat_shade = 1.0;
uniform float jitter = 0.1;

varying vec3 local_pos;
varying vec4 vcol;

float hash3(vec3 p) {
	p = fract(p * 0.3183099 + 0.1);
	p *= 17.0;
	return fract(p.x * p.y * p.z * (p.x + p.y + p.z));
}

void vertex() {
	local_pos = VERTEX;
	vcol = COLOR;
}

void fragment() {
	vec3 base = albedo.rgb * vcol.rgb;
	float n = hash3(floor(local_pos * 2.0));
	base *= (1.0 - jitter * 0.5) + jitter * n;
	ALBEDO = base;
	if (flat_shade > 0.5) {
		NORMAL = normalize(cross(dFdx(VERTEX), dFdy(VERTEX)));
	}
	ROUGHNESS = 0.92;
	SPECULAR = 0.12;
	float fres = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 3.0);
	EMISSION = rim_color.rgb * fres * rim_amount * 0.35 + base * emission_strength;
}
