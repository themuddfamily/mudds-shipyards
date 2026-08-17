shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled;

// The presentation adapter owns only this normalized value. Everything else
// remains authored by the target material.
uniform float entry_effect_intensity_unitless : hint_range(0.0, 1.0) = 0.0;
uniform vec4 entry_heat_color : source_color = vec4(1.0, 0.22, 0.035, 1.0);
uniform float entry_heat_max_alpha : hint_range(0.0, 1.0) = 0.62;
uniform float entry_heat_emission_multiplier : hint_range(0.0, 16.0) = 5.0;
uniform float entry_heat_fresnel_exponent : hint_range(0.25, 8.0) = 2.4;

void fragment() {
	float rim = pow(clamp(1.0 - abs(dot(NORMAL, VIEW)), 0.0, 1.0), entry_heat_fresnel_exponent);
	float envelope = entry_effect_intensity_unitless * mix(0.18, 1.0, rim);
	ALBEDO = entry_heat_color.rgb * envelope;
	EMISSION = entry_heat_color.rgb * entry_heat_emission_multiplier * envelope;
	ALPHA = entry_heat_color.a * entry_heat_max_alpha * envelope;
}
