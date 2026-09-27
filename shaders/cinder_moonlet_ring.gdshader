shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;

// Dust-band shading for the moonlet's two rings. The torus geometry is shared
// with the sector's audited torus family and stays untouched; this only gives
// the band radial structure (ringlets and a dark gap) and fine speckle so it
// reads as particulate rather than a solid hoop.

uniform vec3 band_color : source_color = vec3(0.545, 0.498, 0.388);
uniform float inner_radius = 116.0;
uniform float outer_radius = 132.0;
uniform float ringlet_count = 7.0;
uniform float gap_position = 0.62;

varying vec3 ring_local;

void vertex() {
	ring_local = VERTEX;
}

float hash13(vec3 p) {
	p = fract(p * 0.1031);
	p += dot(p, p.zyx + 31.32);
	return fract((p.x + p.y) * p.z);
}

void fragment() {
	float radial = length(ring_local.xz);
	float t = clamp((radial - inner_radius) / max(outer_radius - inner_radius, 0.001), 0.0, 1.0);
	float ringlets = 0.5 + 0.5 * sin(t * ringlet_count * 6.2831 + sin(t * 13.0) * 1.3);
	float gap = 1.0 - 0.55 * exp(-pow((t - gap_position) / 0.035, 2.0));
	float edge = smoothstep(0.0, 0.12, t) * smoothstep(1.0, 0.86, t);
	float speckle = hash13(floor(ring_local * 1.7));
	float factor = mix(0.66, 1.1, ringlets) * gap * mix(0.7, 1.0, edge) * mix(0.9, 1.08, speckle);
	ALBEDO = band_color * factor;
	ROUGHNESS = 1.0;
	METALLIC = 0.0;
}
