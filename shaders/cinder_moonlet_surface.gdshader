shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;

// The Cinder Reach moonlet's surface. A 90 m sphere with one albedo reads as a
// decorative ball, so this shades it as a place: two octaves of procedural
// craters on the body's own direction (dark bowls, bright rims, pale ejecta),
// low-frequency maria, and a derivative bump from the same height field so
// the terminator picks out crater relief. Everything is object-space, so the
// surface is fixed to the body rather than swimming with the camera.

uniform vec3 base_color : source_color = vec3(0.247, 0.561, 0.478);
uniform vec3 maria_color : source_color = vec3(0.16, 0.33, 0.31);
uniform vec3 rim_color : source_color = vec3(0.56, 0.66, 0.6);
uniform float large_crater_frequency = 3.2;
uniform float small_crater_frequency = 8.5;
uniform float body_radius = 90.0;
// Relief exaggeration over a true bowl depth, so craters read from 300 m.
uniform float relief = 0.4;
uniform float seed = 4.17;

varying vec3 body_direction;

void vertex() {
	body_direction = normalize(VERTEX);
}

vec3 hash33(vec3 p) {
	p = fract(p * vec3(0.1031, 0.1030, 0.0973));
	p += dot(p, p.yxz + 33.33);
	return fract((p.xxy + p.yxx) * p.zyx);
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
	return mix(
		mix(mix(hash13(cell), hash13(cell + vec3(1, 0, 0)), u.x),
			mix(hash13(cell + vec3(0, 1, 0)), hash13(cell + vec3(1, 1, 0)), u.x), u.y),
		mix(mix(hash13(cell + vec3(0, 0, 1)), hash13(cell + vec3(1, 0, 1)), u.x),
			mix(hash13(cell + vec3(0, 1, 1)), hash13(cell + vec3(1, 1, 1)), u.x), u.y),
		u.z
	);
}

// Returns (height, albedo factor) for one crater octave.
vec2 crater_octave(vec3 p) {
	vec3 cell = floor(p);
	vec3 f = fract(p);
	float best = 8.0;
	float best_radius = 0.0;
	for (int z = -1; z <= 1; z++) {
		for (int y = -1; y <= 1; y++) {
			for (int x = -1; x <= 1; x++) {
				vec3 offset = vec3(float(x), float(y), float(z));
				vec3 h = hash33(cell + offset + seed);
				// Only some cells hold a crater; the rest are open plain.
				float radius = h.z > 0.38 ? mix(0.22, 0.48, fract(h.z * 7.13)) : 0.0;
				float d = length(offset + h * 0.8 + 0.1 - f);
				if (radius > 0.0 && d / radius < best) {
					best = d / radius;
					best_radius = radius;
				}
			}
		}
	}
	if (best_radius <= 0.0 || best > 2.2) {
		return vec2(0.0, 1.0);
	}
	float x = best;
	float bowl = x < 1.0 ? (x * x - 1.0) * 0.7 : 0.0;
	float rim = 0.32 * exp(-pow((x - 1.0) / 0.16, 2.0));
	float height = (bowl + rim) * best_radius;
	float albedo = x < 0.85 ? mix(0.72, 0.86, x) : 1.0;
	albedo += 0.2 * exp(-pow((x - 1.0) / 0.2, 2.0));
	albedo += x > 1.0 ? 0.12 * exp(-(x - 1.0) * 3.0) : 0.0;
	return vec2(height, albedo);
}

void fragment() {
	vec3 dir = normalize(body_direction);
	vec2 large = crater_octave(dir * large_crater_frequency);
	vec2 small = crater_octave(dir * small_crater_frequency + 17.0);
	float maria = smoothstep(0.42, 0.68, value_noise(dir * 2.3 + seed));
	float grain = value_noise(dir * 38.0);
	vec3 albedo = mix(base_color, maria_color, maria * 0.75);
	float factor = large.y * mix(1.0, small.y, 0.45) * mix(0.9, 1.06, grain);
	albedo *= factor;
	// Fresh rims catch a paler, less teal regolith.
	float rim_mix = clamp((large.y - 1.08) * 2.5, 0.0, 0.5);
	albedo = mix(albedo, rim_color, rim_mix);
	ALBEDO = albedo;
	ROUGHNESS = mix(0.97, 0.88, rim_mix);
	METALLIC = 0.0;

	// Derivative bump: the crater height field in metres tilts the shading
	// normal, so relief reads at the terminator without extra geometry.
	float height = (large.x / large_crater_frequency + small.x / small_crater_frequency * 0.4)
		* body_radius * relief;
	vec3 dpdx = dFdx(VERTEX);
	vec3 dpdy = dFdy(VERTEX);
	float dhdx = dFdx(height);
	float dhdy = dFdy(height);
	vec3 r1 = cross(dpdy, NORMAL);
	vec3 r2 = cross(NORMAL, dpdx);
	float det = dot(dpdx, r1);
	if (abs(det) > 1e-8) {
		vec3 grad = sign(det) * (dhdx * r1 + dhdy * r2);
		NORMAL = normalize(abs(det) * NORMAL - grad);
	}
}
