shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;

// Shared surface for every lobe in the Cinder Reach asteroid belt. One material
// covers all six stock batches: the per-rock tint arrives as the MultiMesh
// instance colour (authored in sRGB, converted here), and INSTANCE_CUSTOM
// carries the rock's roughness (r) and a stable seed (g) that offsets the
// procedural breakup so no two rocks share the same mottling.

varying vec3 rock_local;
varying float rock_roughness;
varying float rock_seed;

void vertex() {
	rock_local = VERTEX;
	rock_roughness = INSTANCE_CUSTOM.r;
	rock_seed = INSTANCE_CUSTOM.g;
}

float hash13(vec3 p) {
	p = fract(p * 0.1031);
	p += dot(p, p.zyx + 31.32);
	return fract((p.x + p.y) * p.z);
}

float value_noise(vec3 p) {
	vec3 cell = floor(p);
	vec3 f = fract(p);
	vec3 u = f * f * (3.0 - 2.0 * f);
	float n000 = hash13(cell);
	float n100 = hash13(cell + vec3(1.0, 0.0, 0.0));
	float n010 = hash13(cell + vec3(0.0, 1.0, 0.0));
	float n110 = hash13(cell + vec3(1.0, 1.0, 0.0));
	float n001 = hash13(cell + vec3(0.0, 0.0, 1.0));
	float n101 = hash13(cell + vec3(1.0, 0.0, 1.0));
	float n011 = hash13(cell + vec3(0.0, 1.0, 1.0));
	float n111 = hash13(cell + vec3(1.0, 1.0, 1.0));
	return mix(
		mix(mix(n000, n100, u.x), mix(n010, n110, u.x), u.y),
		mix(mix(n001, n101, u.x), mix(n011, n111, u.x), u.y),
		u.z
	);
}

vec3 srgb_to_linear(vec3 c) {
	return mix(c / 12.92, pow((c + 0.055) / 1.055, vec3(2.4)), step(vec3(0.04045), c));
}

void fragment() {
	vec3 p = rock_local * 3.1 + vec3(rock_seed * 37.0, rock_seed * 11.0, rock_seed * 23.0);
	float broad = value_noise(p);
	float fine = value_noise(p * 3.7);
	float mottle = broad * 0.65 + fine * 0.35;
	// Faint strata across the rock's own Y so a lobe reads as stone, not a box.
	float strata = sin(rock_local.y * 11.0 + broad * 4.0 + rock_seed * 6.2831) * 0.5 + 0.5;
	float shade = mix(0.68, 1.14, mottle) * mix(0.9, 1.05, strata);
	ALBEDO = srgb_to_linear(COLOR.rgb) * shade;
	ROUGHNESS = clamp(rock_roughness + (fine - 0.5) * 0.14, 0.05, 1.0);
	METALLIC = 0.03;
}
