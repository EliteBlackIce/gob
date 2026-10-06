shader_type spatial;
render_mode diffuse_lambert, cull_back, blend_mix, depth_draw_opaque;
// Translucent voxel material (slime, glass, water-like blocks). Same pixel look as voxel.gdshader.

uniform float vox = 0.04;
uniform float ppv = 4.0;
uniform float tex = 0.09;
uniform vec4 tint : source_color = vec4(1.0);
uniform float alpha = 0.7;
uniform float emission_strength = 0.6;
uniform float edge_boost = 0.6;

varying vec3 lpos;
varying vec3 lnorm;

float hash3(vec3 p) {
	p = fract(p * 0.3183099 + vec3(0.71, 0.113, 0.419));
	p *= 17.0;
	return fract(p.x * p.y * p.z * (p.x + p.y + p.z));
}

void vertex() {
	lpos = VERTEX;
	lnorm = NORMAL;
}

void fragment() {
	vec3 q = floor((lpos - lnorm * vox * 0.02) / (vox / ppv));
	float n = hash3(q) - 0.5;
	vec3 base = COLOR.rgb * tint.rgb * (1.0 + n * tex * 2.0);
	ALBEDO = base;
	float fres = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 2.0);
	ALPHA = clamp(alpha + fres * edge_boost * (1.0 - alpha), 0.0, 1.0) * COLOR.a;
	ROUGHNESS = 0.9;
	SPECULAR = 0.2;
	EMISSION = base * emission_strength;
}
