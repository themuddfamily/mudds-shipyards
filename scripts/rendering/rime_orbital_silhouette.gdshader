shader_type spatial;
render_mode cull_back, diffuse_lambert, specular_disabled, ambient_light_disabled, shadows_disabled, fog_disabled;

// Single-submission orbital read of Rime for the production shipyard backdrop:
// a pale glacial world with wind-combed ice bands, dark blue fracture lines,
// bright polar caps, streaks of ice-crystal cloud and a thin cold limb. It is a
// presentation-only sphere with no light, camera, clock, physics or gameplay
// owner.
uniform vec4 ice_color : source_color = vec4(0.74, 0.84, 0.89, 1.0);
uniform vec4 shelf_color : source_color = vec4(0.52, 0.66, 0.76, 1.0);
uniform vec4 fracture_color : source_color = vec4(0.16, 0.30, 0.44, 1.0);
uniform vec4 cap_color : source_color = vec4(0.93, 0.96, 0.98, 1.0);
uniform vec4 haze_color : source_color = vec4(0.62, 0.78, 0.92, 1.0);
uniform float band_frequency : hint_range(1.0, 40.0) = 11.0;
uniform float fracture_strength : hint_range(0.0, 1.0) = 0.55;
uniform float haze_strength : hint_range(0.0, 1.0) = 0.36;

varying vec3 body_direction;


float rime_hash(vec3 p) {
	p = fract(p * 0.1031);
	p += dot(p, p.yzx + 33.33);
	return fract((p.x + p.y) * p.z);
}

float rime_noise(vec3 p) {
	vec3 cell = floor(p);
	vec3 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(mix(rime_hash(cell), rime_hash(cell + vec3(1, 0, 0)), f.x),
		mix(rime_hash(cell + vec3(0, 1, 0)), rime_hash(cell + vec3(1, 1, 0)), f.x), f.y),
		mix(mix(rime_hash(cell + vec3(0, 0, 1)), rime_hash(cell + vec3(1, 0, 1)), f.x),
		mix(rime_hash(cell + vec3(0, 1, 1)), rime_hash(cell + vec3(1, 1, 1)), f.x), f.y), f.z);
}


void vertex() {
	body_direction = normalize(VERTEX);
}


void fragment() {
	vec3 direction = normalize(body_direction);
	float latitude = abs(direction.y);
	float warp = rime_noise(direction * 3.1 + vec3(2.3, 7.1, 4.4)) - 0.5;
	// Wind-combed ice: latitude bands bent by a slow noise warp.
	float bands = sin((direction.y + warp * 0.35) * band_frequency) * 0.5 + 0.5;
	vec3 surface = mix(shelf_color.rgb, ice_color.rgb, smoothstep(0.2, 0.8, bands));
	// Long dark fractures where two noise fields cross zero.
	float crack_a = abs(rime_noise(direction * 7.3 + vec3(5.1, 1.2, 9.8)) - 0.5);
	float crack_b = abs(rime_noise(direction.zxy * 9.7 + vec3(3.3, 8.8, 0.7)) - 0.5);
	float fractures = (1.0 - smoothstep(0.0, 0.035, min(crack_a, crack_b))) * fracture_strength;
	surface = mix(surface, fracture_color.rgb, fractures * (1.0 - smoothstep(0.6, 0.85, latitude)));
	surface = mix(surface, cap_color.rgb, smoothstep(0.62, 0.86, latitude + warp * 0.1));
	// Thin streaks of ice-crystal cloud drifting along the bands.
	float streaks = smoothstep(0.62, 0.9, rime_noise(vec3(direction.x * 2.0, direction.y * 16.0, direction.z * 2.0) + vec3(1.7)));
	surface = mix(surface, cap_color.rgb, streaks * 0.45);

	float view_facing = clamp(dot(normalize(NORMAL), normalize(VIEW)), 0.0, 1.0);
	float limb = pow(1.0 - view_facing, 2.4);
	ALBEDO = mix(surface, haze_color.rgb, limb * haze_strength);
	ROUGHNESS = 0.55;
	METALLIC = 0.0;
	EMISSION = surface * 0.004;
}
