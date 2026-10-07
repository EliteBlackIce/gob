shader_type canvas_item;
// Cheap handheld-camcorder look: chunky pixels, a little colour fringing, ordered dither,
// scanlines, tape noise and a heavy vignette. Runs over the 3D view only; menus stay crisp.

uniform sampler2D screen_tex : hint_screen_texture, filter_nearest, repeat_disable;
uniform float pixel = 2.0;
uniform float levels = 28.0;
uniform float vignette = 0.5;
uniform float noise_amt = 0.05;
uniform float time_s = 0.0;

float bayer(vec2 p) {
	int x = int(mod(p.x, 4.0));
	int y = int(mod(p.y, 4.0));
	int i = x + y * 4;
	float m[16] = float[16](0.0, 8.0, 2.0, 10.0, 12.0, 4.0, 14.0, 6.0, 3.0, 11.0, 1.0, 9.0, 15.0, 7.0, 13.0, 5.0);
	return m[i] / 16.0 - 0.5;
}

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(12.9898, 78.233)) + time_s) * 43758.5453);
}

void fragment() {
	vec2 res = 1.0 / SCREEN_PIXEL_SIZE;
	vec2 blocks = res / pixel;
	vec2 cell = floor(SCREEN_UV * blocks);
	vec2 uv = (cell + 0.5) / blocks;
	float fringe = 1.2 / res.x;
	vec3 c;
	c.r = texture(screen_tex, uv + vec2(fringe, 0.0)).r;
	c.g = texture(screen_tex, uv).g;
	c.b = texture(screen_tex, uv - vec2(fringe, 0.0)).b;
	c += bayer(cell) / levels;
	c = floor(c * levels + 0.5) / levels;
	float luma = dot(c, vec3(0.299, 0.587, 0.114));
	c = mix(vec3(luma), c, 0.92);
	c *= 0.93 + 0.07 * sin(cell.y * 3.14159);
	c += (hash(cell) - 0.5) * noise_amt;
	vec2 q = SCREEN_UV - 0.5;
	float vig = smoothstep(0.85, 0.2, length(q * vec2(1.0, 1.15)));
	c *= mix(1.0 - vignette, 1.0, vig);
	COLOR = vec4(c, 1.0);
}
