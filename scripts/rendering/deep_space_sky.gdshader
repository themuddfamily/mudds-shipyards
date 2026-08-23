shader_type sky;

// Deep-space sky for the shipyard.
//
// This replaces ProceduralSkyMaterial, which could not produce the thing the
// scene needed. That material blends a sky hemisphere into a ground hemisphere,
// and with the two horizon colours the station used it drew a hard ruled line
// straight across every wide frame at eye level. In a vacuum scene there is no
// ground, so half the sky's model was being spent drawing a horizon that should
// not exist, and the line read as a distant wall behind the station.
//
// It also could not do the two jobs the sky is actually load-bearing for here:
//
//  * Ambient. The environment draws ambient from the sky, so a sky with no
//    lateral structure produces fill that lands on every face the same way. A
//    galactic band that is bright on one side of the sphere and dark on the
//    other makes the ambient itself directional, which is the difference
//    between a scene that is *lit* and a scene that is *filled*.
//  * Reflections. Reflections are sourced from the background. Against a
//    uniformly near-black background a metallic surface has nothing to reflect,
//    so raising metalness only subtracted diffuse and every metal role had to be
//    kept artificially low. A sky with a band and a sun glow gives metal
//    something to return, which is what makes bare steel readable as steel.
//
// Everything here is analytic. There is no noise texture to import and no
// dependency on a probe, so the whole sky is one resource whose entire authored
// state is the uniform block below and can be frozen exactly by a test.

// Great-circle dust band. `band_axis` is the *pole* of the band, so the band
// itself lies in the plane perpendicular to it.
uniform vec3 band_axis = vec3(0.34, 0.88, -0.33);
uniform float band_width : hint_range(0.05, 1.0) = 0.42;
uniform vec3 band_color : source_color = vec3(0.0);
uniform vec3 core_color : source_color = vec3(0.0);
uniform vec3 core_axis = vec3(-0.62, -0.12, -0.77);
uniform float core_focus : hint_range(1.0, 64.0) = 7.0;

// Vertical grade. Deliberately a single smooth curve across the whole sphere
// rather than two hemispheres meeting at an equator: there is no horizon to
// draw, only a slow shift that gives the hemispheric ambient term something to
// vary with.
uniform vec3 zenith_color : source_color = vec3(0.0);
uniform vec3 nadir_color : source_color = vec3(0.0);

// The sun's own glow. This is a halo, not a disc: the station's key light
// direction is fed in here from the same constant that aims the light, so the
// bright side of the sky and the lit side of every surface agree.
uniform vec3 sun_direction = vec3(0.0, 0.0, 1.0);
uniform vec3 sun_color : source_color = vec3(0.0);
uniform float sun_focus : hint_range(4.0, 4096.0) = 260.0;
uniform float sun_halo : hint_range(0.0, 4.0) = 0.18;
uniform float sun_halo_focus : hint_range(4.0, 256.0) = 48.0;

// Project-original nebula, retained as faint modern atmosphere. Mapped
// equirectangularly over the whole sphere and faded out at both poles, so it
// contributes structure without the pinch showing.
uniform sampler2D nebula_cover : source_color, filter_linear, repeat_enable;
uniform float nebula_strength : hint_range(0.0, 1.0) = 0.08;

uniform float dust_scale : hint_range(0.5, 24.0) = 3.4;


float hash31(vec3 p) {
	p = fract(p * 0.3183099 + vec3(0.71, 0.113, 0.419));
	p *= 17.0;
	return fract(p.x * p.y * p.z * (p.x + p.y + p.z));
}


float value_noise(vec3 x) {
	vec3 i = floor(x);
	vec3 f = fract(x);
	f = f * f * (3.0 - 2.0 * f);
	float n000 = hash31(i + vec3(0.0, 0.0, 0.0));
	float n100 = hash31(i + vec3(1.0, 0.0, 0.0));
	float n010 = hash31(i + vec3(0.0, 1.0, 0.0));
	float n110 = hash31(i + vec3(1.0, 1.0, 0.0));
	float n001 = hash31(i + vec3(0.0, 0.0, 1.0));
	float n101 = hash31(i + vec3(1.0, 0.0, 1.0));
	float n011 = hash31(i + vec3(0.0, 1.0, 1.0));
	float n111 = hash31(i + vec3(1.0, 1.0, 1.0));
	return mix(
		mix(mix(n000, n100, f.x), mix(n010, n110, f.x), f.y),
		mix(mix(n001, n101, f.x), mix(n011, n111, f.x), f.y),
		f.z
	);
}


float dust_fbm(vec3 p) {
	float amplitude = 0.5;
	float total = 0.0;
	for (int octave = 0; octave < 4; octave++) {
		total += amplitude * value_noise(p);
		p *= 2.07;
		amplitude *= 0.5;
	}
	return total;
}


void sky() {
	vec3 direction = normalize(EYEDIR);

	float grade = smoothstep(-1.0, 1.0, direction.y);
	vec3 color = mix(nadir_color, zenith_color, grade);

	float band_offset = dot(direction, normalize(band_axis));
	float band = exp(-(band_offset * band_offset) / (band_width * band_width));
	float coarse = dust_fbm(direction * dust_scale);
	float fine = dust_fbm(direction * dust_scale * 3.3 + vec3(19.7, 4.1, 31.3));
	// Two octave sets multiplied rather than added: dust lanes read as gaps
	// carved out of the band, not as a second brighter band laid over it.
	float structure = mix(0.18, 1.0, coarse) * mix(0.45, 1.0, fine);
	float core = pow(max(dot(direction, normalize(core_axis)), 0.0), core_focus);
	color += band * structure * (band_color + core_color * core);

	float sun_offset = max(dot(direction, normalize(sun_direction)), 0.0);
	// Keep the bright, tightly focused sun silhouette, but do not let its
	// secondary lobe become a large full-screen exposure wash. The former fixed
	// fifth-power halo still contributed almost half strength thirty degrees away.
	color += sun_color * (
		pow(sun_offset, sun_focus)
		+ sun_halo * pow(sun_offset, sun_halo_focus)
	);

	vec2 cover_uv = vec2(
		atan(direction.z, direction.x) / (2.0 * PI) + 0.5,
		acos(clamp(direction.y, -1.0, 1.0)) / PI
	);
	float pole_fade = smoothstep(0.0, 0.24, cover_uv.y) * smoothstep(0.0, 0.24, 1.0 - cover_uv.y);
	// The legacy cover is panoramic but its two image edges do not match. It is
	// intentionally only a faint layer over the analytic sky, so fade it out at
	// the equirectangular wrap rather than allowing a full-height discontinuity
	// to leak into the frame. The analytic band/core sky remains continuous at
	// that meridian and carries the missing few degrees of backdrop.
	float wrap_distance = min(cover_uv.x, 1.0 - cover_uv.x);
	float wrap_fade = smoothstep(0.0, 0.035, wrap_distance);
	color += texture(nebula_cover, cover_uv).rgb * nebula_strength * pole_fade * wrap_fade;

	COLOR = color;
}
