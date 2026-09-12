shader_type spatial;
render_mode cull_back, diffuse_lambert, specular_disabled, ambient_light_disabled, shadows_disabled, fog_disabled;

// A single-submission orbital read for the production shipyard backdrop. The
// world is still a distant presentation-only sphere; these parameters give the
// authored Aurora destination recognisable oceans, land, weather and a thin
// atmospheric limb without adding a light, camera, clock, physics or gameplay
// owner to the backdrop.
uniform vec4 ocean_color : source_color = vec4(0.055, 0.19, 0.27, 1.0);
uniform vec4 shelf_color : source_color = vec4(0.16, 0.37, 0.35, 1.0);
uniform vec4 lowland_color : source_color = vec4(0.20, 0.42, 0.25, 1.0);
uniform vec4 highland_color : source_color = vec4(0.45, 0.50, 0.36, 1.0);
uniform vec4 cloud_color : source_color = vec4(0.78, 0.88, 0.91, 1.0);
uniform vec4 atmosphere_color : source_color = vec4(0.22, 0.66, 0.86, 1.0);
uniform float land_threshold : hint_range(-1.0, 1.0) = 0.04;
uniform float cloud_coverage : hint_range(0.0, 1.0) = 0.48;
uniform float atmosphere_strength : hint_range(0.0, 1.0) = 0.30;

varying vec3 body_direction;


float aurora_hash(vec3 p) {
	p = fract(p * 0.1031);
	p += dot(p, p.yzx + 33.33);
	return fract((p.x + p.y) * p.z);
}

float aurora_noise(vec3 p) {
	vec3 cell = floor(p);
	vec3 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(mix(aurora_hash(cell), aurora_hash(cell + vec3(1,0,0)), f.x),
		mix(aurora_hash(cell + vec3(0,1,0)), aurora_hash(cell + vec3(1,1,0)), f.x), f.y),
		mix(mix(aurora_hash(cell + vec3(0,0,1)), aurora_hash(cell + vec3(1,0,1)), f.x),
		mix(aurora_hash(cell + vec3(0,1,1)), aurora_hash(cell + vec3(1,1,1)), f.x), f.y), f.z);
}

// Three non-periodic scales preserve broad land masses with broken coastlines.
float aurora_field(vec3 direction) {
 vec3 p = direction * 2.3 + vec3(5.7, 8.2, 2.6);
 float warp = aurora_noise(p * 0.73 + vec3(9.1, 1.7, 6.2)) - 0.5;
 p += direction.yzx * warp * 1.15;
 return (aurora_noise(p) * 0.67 + aurora_noise(p * 2.13 + vec3(3.1, 6.4, 8.7)) * 0.24
  + aurora_noise(p * 4.61 + vec3(7.2, 2.3, 4.1)) * 0.09) * 2.0 - 1.0;
}

float aurora_detail(vec3 direction) {
 return aurora_noise(direction * 29.0 + vec3(4.7, 8.9, 1.2));
}


void vertex() {
	body_direction = normalize(VERTEX);
}


void fragment() {
	vec3 direction = normalize(body_direction);
	float latitude = abs(direction.y);
	float field = aurora_field(direction);
	float polar_breakup = smoothstep(0.70, 0.94, latitude) * 0.18;
	float land = smoothstep(
		land_threshold - 0.028,
		land_threshold + 0.018,
		field - polar_breakup
	);
	float shelf = smoothstep(
		land_threshold - 0.070,
		land_threshold + 0.01,
		field
	) * (1.0 - land);
	float elevation = clamp(
		0.52 + field * 0.40 + (aurora_detail(direction) - 0.5) * 0.22,
		0.0,
		1.0
	);
	vec3 terrain = mix(lowland_color.rgb, highland_color.rgb, elevation);
	vec3 surface = mix(ocean_color.rgb, shelf_color.rgb, shelf * 0.72);
	surface = mix(surface, terrain, land);

	vec3 weather_direction = normalize(direction + vec3(0.11, -0.04, 0.08));
	float cloud_field = aurora_field(weather_direction.zxy * 2.3);
	cloud_field += (aurora_detail(weather_direction.yzx) - 0.5) * 0.52;
	float clouds = smoothstep(
		cloud_coverage + 0.02,
		cloud_coverage + 0.16,
		cloud_field * 0.5 + 0.5
	);
	// Break the cloud mask over the warmest low latitudes so it reads as moving
	// weather bands rather than another solid land layer.
	clouds *= 0.72 + abs(direction.y) * 0.28;
	surface = mix(surface, cloud_color.rgb, clouds * 0.78);

	float view_facing = clamp(dot(normalize(NORMAL), normalize(VIEW)), 0.0, 1.0);
	float limb = pow(1.0 - view_facing, 3.0);
	// The atmospheric limb receives the same day/night illumination as terrain.
	ALBEDO = mix(surface, atmosphere_color.rgb, limb * atmosphere_strength);
	ROUGHNESS = mix(0.34, 0.92, clamp(land + clouds * 0.65, 0.0, 1.0));
	METALLIC = 0.0;
	EMISSION = surface * 0.003;
}
