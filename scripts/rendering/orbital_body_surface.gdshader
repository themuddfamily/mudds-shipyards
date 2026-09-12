shader_type spatial;
render_mode cull_back, diffuse_lambert, specular_disabled, ambient_light_disabled, shadows_disabled, fog_disabled;

// Static spherical surfaces share one program and the yard's directional key.
// Object-space sampling has no longitude seam or polar UV distortion. These
// modern terrain interpretations add no textures, lights or update owner.
uniform vec4 body_color : source_color;
uniform int surface_kind = 0; // tan gas bands, grey cratered moon, orange rock
varying vec3 body_direction;
varying mat3 body_normal_to_view;

// Baked Fibonacci centers/radii: no per-fragment trig or square-root setup.
const vec4 CRATERS[28] = vec4[28](
	vec4(0.264864232, 0.964285714, 0.000000000, 0.055000000),
	vec4(-0.332066636, 0.892857143, 0.304200381, 0.126073910),
	vec4(0.049859627, 0.821428571, -0.568127732, 0.082147820),
	vec4(0.402444840, 0.750000000, 0.524917280, 0.153221730),
	vec4(-0.723306068, 0.678571429, -0.127941973, 0.109295640),
	vec4(0.670441304, 0.607142857, -0.426480960, 0.065369550),
	vec4(-0.219208573, 0.535714286, 0.815449450, 0.136443460),
	vec4(-0.408219925, 0.464285714, -0.785999535, 0.092517370),
	vec4(0.863799987, 0.392857143, 0.315456571, 0.163591280),
	vec4(-0.875293328, 0.321428571, 0.361310480, 0.119665190),
	vec4(0.410385105, 0.250000000, -0.876974381, 0.075739100),
	vec4(0.294475833, 0.178571429, 0.938827050, 0.146813010),
	vec4(-0.860232114, 0.107142857, -0.498518925, 0.102886920),
	vec4(0.976052054, 0.035714286, -0.214585362, 0.058960830),
	vec4(-0.574759891, -0.035714286, 0.817542389, 0.130034740),
	vec4(-0.127774333, -0.107142857, -0.985999051, 0.086108650),
	vec4(0.752361085, -0.178571429, 0.634085990, 0.157182560),
	vec4(-0.967418851, -0.250000000, 0.040009591, 0.113256470),
	vec4(0.671211788, -0.321428571, -0.667950903, 0.069330380),
	vec4(-0.042473622, -0.392857143, 0.918618123, 0.140404290),
	vec4(-0.567469913, -0.464285714, -0.680012260, 0.096478200),
	vec4(0.836858877, -0.535714286, 0.112594068, 0.167552110),
	vec4(-0.652245745, -0.607142857, 0.453820493, 0.123626020),
	vec4(0.161212834, -0.678571429, -0.716624894, 0.079699930),
	vec4(0.328857402, -0.750000000, 0.573892681, 0.150773840),
	vec4(-0.543332555, -0.821428571, -0.173334466, 0.106847750),
	vec4(0.408813538, -0.892857143, -0.188885187, 0.062921660),
	vec4(-0.102252256, -0.964285714, 0.244330795, 0.133995570)
);

float hash(vec3 p) {
	p = fract(p * 0.1031);
	p += dot(p, p.yzx + 33.33);
	return fract((p.x + p.y) * p.z);
}

float noise3(vec3 p) {
	vec3 cell = floor(p);
	vec3 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(mix(hash(cell), hash(cell + vec3(1,0,0)), f.x),
		mix(hash(cell + vec3(0,1,0)), hash(cell + vec3(1,1,0)), f.x), f.y),
		mix(mix(hash(cell + vec3(0,0,1)), hash(cell + vec3(1,0,1)), f.x),
		mix(hash(cell + vec3(0,1,1)), hash(cell + vec3(1,1,1)), f.x), f.y), f.z);
}

void vertex() {
	body_direction = normalize(VERTEX);
	body_normal_to_view = MODELVIEW_NORMAL_MATRIX;
}

void fragment() {
	vec3 d = normalize(body_direction);
	float broad = noise3(d * 4.5 + vec3(7.3, 3.9, 1.7));
	float detail = noise3(d * 19.0 + vec3(2.1, 8.5, 4.3));
	vec3 surface;
	if (surface_kind == 0) {
		// Broad ochre belts, thinner cream zones and irregular shear at their edges.
		float latitude = dot(d, normalize(vec3(0.18, 1.0, 0.12)));
		float shear = (broad - 0.5) * 0.075 + (detail - 0.5) * 0.009;
		float belt_position = latitude + shear;
		float belts = noise3(vec3(belt_position * 16.0, 7.31, 4.17));
		float fine_bands = noise3(vec3(belt_position * 61.0, 2.74, 8.91));
		belts = smoothstep(0.24, 0.77, belts * 0.87 + fine_bands * 0.13);
		surface = body_color.rgb * mix(vec3(0.53, 0.45, 0.37), vec3(0.96, 0.93, 0.85), belts);
		surface *= 0.95 + (fine_bands - 0.5) * 0.12 + detail * 0.045;
	} else if (surface_kind == 1) {
		// Basin floors and raised crater shoulders change the surface normal:
		// sunlight makes the rims legible, rather than bright painted circles.
		vec3 gradient = vec3(0.0);
		float ejecta = 0.0;
		for (int i = 0; i < 28; i++) {
			vec3 delta = d - CRATERS[i].xyz;
			float separation = length(delta);
			float radius = CRATERS[i].w;
			float distance = separation / radius;
			float age = 0.40 + fract(float(i) * 0.381966) * 0.60;
			float slope = 0.0;
			// Derivative of a smooth depressed bowl with a raised, weathered rim.
			if (distance < 0.87) {
				float t = clamp((distance - 0.28) / 0.59, 0.0, 1.0);
				slope = 0.13 * age * 6.0 * t * (1.0 - t) / 0.59;
			} else if (distance < 1.32) {
				float t = (distance - 0.87) / 0.45;
				slope = -0.06 * age * 6.0 * t * (1.0 - t) / 0.45;
			}
			vec3 tangent = (delta - d * dot(delta, d)) / max(separation, 0.0001);
			gradient += tangent * slope * (0.75 + detail * 0.5);
			ejecta += (1.0 - smoothstep(0.92, 1.70, distance)) * age * (detail - 0.32) * 0.045;
		}
		NORMAL = normalize(body_normal_to_view * normalize(d - gradient));
		float fine = noise3(d * 63.0 + vec3(1.3, 7.5, 3.9));
		float maria = smoothstep(0.29, 0.65, broad * 0.85 + detail * 0.15);
		surface = body_color.rgb * (0.59 + maria * 0.24 + detail * 0.09 + fine * 0.065 + ejecta);
	} else {
		// Broad mineral basins cut through warm oxidised highlands, with restrained
		// fine striation rather than luminous lava or a second cloud/weather layer.
		float basins = smoothstep(0.34, 0.69, broad + (detail - 0.5) * 0.12);
		vec3 mineral = mix(body_color.rgb, vec3(dot(body_color.rgb, vec3(0.2126, 0.7152, 0.0722))), 0.38);
		surface = mineral * mix(vec3(0.43, 0.42, 0.40), vec3(0.80, 0.77, 0.71), basins);
		surface *= 0.87 + detail * 0.20;
	}
	ALBEDO = surface;
	ROUGHNESS = 1.0;
	EMISSION = surface * 0.003;
}
