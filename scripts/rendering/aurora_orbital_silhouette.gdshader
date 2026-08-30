shader_type spatial;
render_mode cull_back, diffuse_burley, specular_schlick_ggx;

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


float aurora_field(vec3 direction) {
	float broad = sin(direction.x * 7.0 + direction.z * 3.1);
	broad += sin(direction.z * 9.3 - direction.y * 4.7) * 0.65;
	broad += sin((direction.x + direction.y - direction.z) * 15.1) * 0.34;
	return broad / 1.99;
}


float aurora_detail(vec3 direction) {
	float first = sin(direction.x * 29.0 + direction.y * 17.0);
	float second = sin(direction.z * 37.0 - direction.x * 11.0);
	return (first + second) * 0.25 + 0.5;
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
		land_threshold - 0.10,
		land_threshold + 0.10,
		field - polar_breakup
	);
	float shelf = smoothstep(
		land_threshold - 0.20,
		land_threshold + 0.02,
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
	float cloud_field = aurora_field(weather_direction.zxy * 1.37);
	cloud_field += (aurora_detail(weather_direction.yzx) - 0.5) * 0.52;
	float clouds = smoothstep(
		cloud_coverage - 0.12,
		cloud_coverage + 0.12,
		cloud_field * 0.5 + 0.5
	);
	// Break the cloud mask over the warmest low latitudes so it reads as moving
	// weather bands rather than another solid land layer.
	clouds *= 0.72 + abs(direction.y) * 0.28;
	surface = mix(surface, cloud_color.rgb, clouds * 0.70);

	float view_facing = clamp(dot(normalize(NORMAL), normalize(VIEW)), 0.0, 1.0);
	float limb = pow(1.0 - view_facing, 3.0);
	ALBEDO = surface;
	ROUGHNESS = mix(0.34, 0.92, clamp(land + clouds * 0.65, 0.0, 1.0));
	METALLIC = 0.0;
	EMISSION = surface * 0.018 + atmosphere_color.rgb * limb * atmosphere_strength;
}
