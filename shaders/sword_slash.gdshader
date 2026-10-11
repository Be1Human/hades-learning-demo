shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, shadows_disabled, blend_mix;

// Explicit simulation time: pause and hit-stop never depend on wall-clock TIME.
uniform float age = 0.0;
uniform float duration = 0.23;
uniform float strength = 1.0;

float hash21(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}
float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash21(i), hash21(i + vec2(1.0,0.0)), f.x),
		mix(hash21(i + vec2(0.0,1.0)), hash21(i + vec2(1.0)), f.x), f.y);
}
void fragment() {
	float u = UV.x;
	float head = 1.0-pow(1.0-clamp(age/0.07,0.0,1.0),2.6);
	// Pinch the moving front into a point, instead of cropping a rectangular end.
	float moving_tip = smoothstep(0.0,0.14,head-u);
	float v = UV.y / max(moving_tip,0.001);
	float n = noise(vec2(u * 9.0 - age * 9.0 + noise(vec2(u*3.0,v*5.0-age*4.0))*0.8, v * 13.0));
	float fine = noise(vec2(u * 23.0 - age * 22.0, v * 41.0));
	float reveal = 1.0 - smoothstep(head - 0.035, head + 0.008, u);
	float tail = max(0.0, (age - 0.025) / (duration - 0.025));
	float erosion = u + (1.0-v)*0.075 + (n-0.5)*0.21;
	float dissolve = smoothstep(tail-0.035,tail+0.02,erosion);
	float inner_edge = 0.40 + n * 0.38 + fine * 0.17;
	float silhouette = 1.0-smoothstep(inner_edge-0.03,inner_edge+0.015,v);
	// Sparse, elongated cut-outs read as brush marks, not round smoke blobs.
	float cuts = smoothstep(0.36,0.51,noise(vec2(u*4.0-age*8.0,v*29.0)));
	silhouette *= mix(1.0,cuts,smoothstep(0.15,0.65,v)*0.95);
	float blade = 1.0-smoothstep(0.23,0.43+0.04*n,v);
	float gold = 1.0-smoothstep(0.40,0.55,v);
	float red = 1.0-smoothstep(0.40,0.75,v);
	vec3 ink = vec3(0.13,0.018,0.028);
	vec3 scarlet = vec3(0.75,0.025,0.018);
	vec3 amber = vec3(1.0,0.36,0.075);
	vec3 ivory = vec3(1.0,0.94,0.72);
	vec3 color = mix(ink,scarlet,red);
	color = mix(color,amber,gold);
	color = mix(color,ivory,blade);
	float tip_flash = exp(-pow((u-head+0.055)*14.0,2.0)) * (1.0-v);
	ALBEDO = color;
	EMISSION = ivory * blade * (0.35+tip_flash*0.35) + amber*gold*0.08;
	float fade = 1.0-smoothstep(duration*0.76,duration,age);
	ALPHA = reveal*dissolve*silhouette*fade*strength;
}
