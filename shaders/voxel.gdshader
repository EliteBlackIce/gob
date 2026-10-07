shader_type spatial;
render_mode diffuse_lambert, cull_back;
// Blocky "Minecraft Dungeons" surface: flat Lambert light on vertex-coloured voxels (baked
// per-corner ambient occlusion), a crisp pixel-grid noise so every block face looks textured,
// and vertex alpha as an emission mask (alpha < 1 = glowing block).

uniform float vox = 0.04;            // voxel edge length in metres
uniform float ppv = 4.0;             // texture pixels per voxel edge
uniform float tex = 0.075;           // pixel noise strength
uniform vec4 tint : source_color = vec4(1.0);
uniform float emission_strength = 1.7;
uniform float wind = 0.0;
uniform float flash = 0.0;           // white flash (hit feedback)

varying vec3 lpos;
varying vec3 lnorm;

float hash3(vec3 p) {
	p = fract(p * 0.3183099 + vec3(0.71, 0.113, 0.419));
	p *= 17.0;
	return fract(p.x * p.y * p.z * (p.x + p.y + p.z));
}

void vertex() {
	if (wind > 0.0) {
		vec3 w0 = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
		float amt = wind * clamp(VERTEX.y * 0.12, 0.0, 1.2);
		VERTEX.x += sin(TIME * 1.4 + w0.x * 0.4 + w0.z * 0.3) * amt;
		VERTEX.z += cos(TIME * 1.1 + w0.z * 0.35 + w0.x * 0.25) * amt * 0.6;
	}
	lpos = VERTEX;
	lnorm = NORMAL;
}

void fragment() {
	// Clean Minecraft block look: nearly flat colour, a whisper of grain, and every large block
	// gets a 1-texel bevel (light top/left, dark bottom/right) like the stone-brick reference.
	float pix = clamp(vox * 0.5, 0.03, 0.125);
	vec3 q = floor((lpos - lnorm * vox * 0.02) / pix);
	float n = hash3(q);
	float lvl = n < 0.22 ? -1.0 : (n > 0.78 ? 1.0 : 0.0);
	vec3 base = COLOR.rgb * tint.rgb;
	base *= 1.0 + lvl * tex;
	// a faint per-voxel tint shift so neighbouring blocks read as separate stones
	vec3 vq = floor((lpos - lnorm * vox * 0.02) / vox);
	base *= 1.0 + (hash3(vq + 7.0) - 0.5) * tex * 0.8;
	if (vox >= 0.2) {
		vec3 f = fract((lpos - lnorm * vox * 0.02) / vox);
		vec3 an = abs(lnorm);
		float ew = pix / vox;
		float dark = 0.0;
		float light = 0.0;
		if (an.y < 0.5) {
			if (f.y > 1.0 - ew) light = 1.0;
			if (f.y < ew) dark = 1.0;
		}
		if (an.x < 0.5) {
			if (f.x < ew) light = max(light, 0.6);
			if (f.x > 1.0 - ew) dark = max(dark, 0.6);
		}
		if (an.z < 0.5 && an.x > 0.5) {
			if (f.z < ew) light = max(light, 0.6);
			if (f.z > 1.0 - ew) dark = max(dark, 0.6);
		}
		base *= 1.0 + light * 0.09 - dark * 0.16;
	}
	ALBEDO = mix(base, vec3(1.0), flash);
	ROUGHNESS = 1.0;
	SPECULAR = 0.0;
	EMISSION = base * (1.0 - COLOR.a) * emission_strength;
}
