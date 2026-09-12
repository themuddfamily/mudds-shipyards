shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_back, shadows_disabled;

uniform vec4 exhaust_color : source_color = vec4(0.388, 0.937, 1.0, 1.0);
uniform float intensity = 4.0;
uniform bool damage_pass = false;
instance uniform vec3 plume_center = vec3(0.0);
instance uniform vec3 plume_half_size = vec3(0.5);
instance uniform vec3 plume_axis = vec3(0.0, 1.0, 0.0);
instance uniform float plume_damage_mix = 0.0;
instance uniform float plume_boost = 0.0;

varying vec3 volume_position;
varying vec3 volume_camera;

void vertex() {
	vec3 extent = max(plume_half_size, vec3(0.0001));
	volume_position = (VERTEX - plume_center) / extent;
	volume_camera = ((inverse(MODELVIEW_MATRIX) * vec4(0.0, 0.0, 0.0, 1.0)).xyz - plume_center) / extent;
}

vec2 density_at(vec3 point) {
	float axial = dot(point, plume_axis);
	float along = clamp(axial * 0.5 + 0.5, 0.0, 1.0);
	vec3 radial = point - plume_axis * axial;
	// Boost keeps a longer pressure column inside the authored envelope.
	// Two shallow compression cells are stationary, including reduced motion.
	float boost = damage_pass ? 0.0 : plume_boost;
	float compression = 0.0;
	// The per-instance branch keeps cruise and damage off the boost-only
	// trigonometric path across all eight interior samples.
	if (boost > 0.0) {
		compression = sin(along * 12.56637) * sin(along * 3.14159);
	}
	float radius = 0.88 * (1.0 - along * mix(0.78, 0.74, boost));
	radius *= 1.0 + boost * compression * 0.10;
	float radial_squared = dot(radial, radial) / (radius * radius);
	float fade = smoothstep(0.0, 0.07, along) * (1.0 - smoothstep(mix(0.30, 0.72, boost), 1.0, along));
	float soft_edge = 1.0 - smoothstep(0.25, 1.0, radial_squared);
	float density = exp(-1.8 * radial_squared) * soft_edge * fade;
	return vec2(density, density * exp(-9.0 * radial_squared) * (1.0 + boost * 0.16 * compression));
}

// Eight fixed interior samples soften the radial edge and remove the solid
// end cap. Keep these explicit: looped uniform-color integration is unstable
// on the software Vulkan renderer used for isolated visual checks.
void fragment() {
	vec3 ray = normalize(volume_position - volume_camera);
	vec3 safe_ray = sign(ray + vec3(0.000001)) * max(abs(ray), vec3(0.00001));
	vec3 exit_distance = (sign(safe_ray) - volume_position) / safe_ray;
	float travel = max(0.0, min(exit_distance.x, min(exit_distance.y, exit_distance.z)));
	vec2 density = density_at(volume_position + ray * (travel * 0.0625));
	density += density_at(volume_position + ray * (travel * 0.1875));
	density += density_at(volume_position + ray * (travel * 0.3125));
	density += density_at(volume_position + ray * (travel * 0.4375));
	density += density_at(volume_position + ray * (travel * 0.5625));
	density += density_at(volume_position + ray * (travel * 0.6875));
	density += density_at(volume_position + ray * (travel * 0.8125));
	density += density_at(volume_position + ray * (travel * 0.9375));
	density *= travel * 0.125;
	ALBEDO = (exhaust_color.rgb * density.x + vec3(0.82, 0.94, 1.0) * density.y * (damage_pass ? 0.08 : 0.38)) * intensity;
	ALPHA = damage_pass ? 1.0 : 1.0 - plume_damage_mix;
}
