shader_type spatial;
render_mode unshaded, blend_mix, cull_disabled, depth_draw_never;

// Six parameters are exclusively driven by PlanetaryCloudPresentation.
uniform float cloud_base_radius_m = 1.0;
uniform float cloud_top_radius_m = 2.0;
uniform float cloud_coverage_unitless : hint_range(0.0, 1.0) = 0.0;
uniform float cloud_observer_layer_factor_unitless : hint_range(0.0, 1.0) = 0.0;
uniform vec3 cloud_wind_velocity_mps = vec3(0.0);
uniform vec3 cloud_wind_offset_m = vec3(0.0);

varying vec3 body_direction;

void vertex() {
	body_direction = normalize(VERTEX);
}

void fragment() {
	float shell_width_m = max(cloud_top_radius_m - cloud_base_radius_m, 1.0);
	vec3 advected = body_direction * 11.0
		+ cloud_wind_offset_m / shell_width_m;
	float broad = sin(advected.x * 1.7 + advected.z * 1.1);
	float detail = sin(advected.y * 3.1 - advected.x * 0.8);
	float pattern = clamp(0.5 + broad * 0.27 + detail * 0.18, 0.0, 1.0);
	float threshold = 1.0 - cloud_coverage_unitless;
	float coverage_mask = smoothstep(threshold - 0.12, threshold + 0.12, pattern);
	float inside_layer_lift = mix(
		0.85,
		1.0,
		cloud_observer_layer_factor_unitless
	);
	// Display colour/opacity are immutable shader-authored constants. The six
	// reflected uniforms remain the adapter's exact and only mutable contract.
	ALBEDO = vec3(0.82, 0.88, 0.94);
	ALPHA = clamp(
		coverage_mask * 0.36 * inside_layer_lift,
		0.0,
		1.0
	);
}
