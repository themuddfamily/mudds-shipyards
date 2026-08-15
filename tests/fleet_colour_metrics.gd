extends RefCounted

## Perceptual colour separation maths shared by the fleet colour audit and by the
## palette design probes that produced the current fleet palette.
##
## The implementation is the one introduced by
## tests/fleet_role_differentiation_test.gd and cross-checked there against an
## independent Python reference: sRGB -> linear -> optional Viénot 1999
## dichromat simulation -> CIE L*a*b* -> CIEDE2000. It lives here so that the
## audit suite and any design-time probe measure with exactly one implementation
## rather than two that can drift apart.
##
## No production colour is defined in this file; it only measures.

const VISION_MODELS: Array[String] = ["normal", "protanopia", "deuteranopia", "tritanopia"]


## CIEDE2000 between two sRGB hex colours, optionally through a Viénot 1999
## dichromat simulation, so separation is measured perceptually rather than by
## comparing hex digits.
static func separation(first_hex: String, second_hex: String, mode: String) -> float:
	return ciede2000(
		linear_to_lab(simulate(hex_to_linear(first_hex), mode)),
		linear_to_lab(simulate(hex_to_linear(second_hex), mode))
	)


## Smallest pairwise separation across a {key: hex} set, under one vision model.
static func minimum_separation(values: Dictionary, mode: String) -> float:
	var keys: Array = values.keys()
	keys.sort()
	var minimum := INF
	for first_index in keys.size():
		for second_index in range(first_index + 1, keys.size()):
			minimum = minf(
				minimum,
				separation(str(values[keys[first_index]]), str(values[keys[second_index]]), mode)
			)
	return minimum


## CIE L* of an sRGB hex colour, used to rank candidate body tones by lightness.
static func lightness(hex: String) -> float:
	return linear_to_lab(hex_to_linear(hex)).x


static func hex_to_linear(hex: String) -> Vector3:
	var colour := Color(hex)
	return Vector3(
		srgb_component_to_linear(colour.r),
		srgb_component_to_linear(colour.g),
		srgb_component_to_linear(colour.b)
	)


static func srgb_component_to_linear(value: float) -> float:
	if value <= 0.04045:
		return value / 12.92
	return pow((value + 0.055) / 1.055, 2.4)


static func simulate(linear: Vector3, mode: String) -> Vector3:
	if mode == "normal":
		return linear
	var long_wave := 17.8824 * linear.x + 43.5161 * linear.y + 4.11935 * linear.z
	var medium_wave := 3.45565 * linear.x + 27.1554 * linear.y + 3.86714 * linear.z
	var short_wave := 0.0299566 * linear.x + 0.184309 * linear.y + 1.46709 * linear.z
	match mode:
		"protanopia":
			long_wave = 2.02344 * medium_wave - 2.52581 * short_wave
		"deuteranopia":
			medium_wave = 0.494207 * long_wave + 1.24827 * short_wave
		"tritanopia":
			short_wave = -0.395913 * long_wave + 0.801109 * medium_wave
	return Vector3(
		0.080944 * long_wave - 0.130504 * medium_wave + 0.116721 * short_wave,
		-0.0102485 * long_wave + 0.0540194 * medium_wave - 0.113615 * short_wave,
		-0.000365294 * long_wave - 0.00412163 * medium_wave + 0.693513 * short_wave
	)


static func linear_to_lab(linear: Vector3) -> Vector3:
	var x := 0.4124564 * linear.x + 0.3575761 * linear.y + 0.1804375 * linear.z
	var y := 0.2126729 * linear.x + 0.7151522 * linear.y + 0.0721750 * linear.z
	var z := 0.0193339 * linear.x + 0.1191920 * linear.y + 0.9503041 * linear.z
	var fx := lab_transfer(x / 0.95047)
	var fy := lab_transfer(y)
	var fz := lab_transfer(z / 1.08883)
	return Vector3(116.0 * fy - 16.0, 500.0 * (fx - fy), 200.0 * (fy - fz))


static func lab_transfer(value: float) -> float:
	var safe := maxf(value, 0.0)
	if safe > 216.0 / 24389.0:
		return pow(safe, 1.0 / 3.0)
	return (841.0 / 108.0) * safe + 4.0 / 29.0


static func ciede2000(first: Vector3, second: Vector3) -> float:
	var chroma_first := Vector2(first.y, first.z).length()
	var chroma_second := Vector2(second.y, second.z).length()
	var chroma_mean := (chroma_first + chroma_second) * 0.5
	var chroma_seventh := pow(chroma_mean, 7.0)
	var g_factor := 0.5 * (1.0 - sqrt(chroma_seventh / (chroma_seventh + pow(25.0, 7.0))))
	var a_first := (1.0 + g_factor) * first.y
	var a_second := (1.0 + g_factor) * second.y
	var chroma_first_prime := Vector2(a_first, first.z).length()
	var chroma_second_prime := Vector2(a_second, second.z).length()
	var hue_first := positive_degrees(rad_to_deg(atan2(first.z, a_first)))
	var hue_second := positive_degrees(rad_to_deg(atan2(second.z, a_second)))
	var delta_lightness := second.x - first.x
	var delta_chroma := chroma_second_prime - chroma_first_prime
	var delta_hue := 0.0
	if chroma_first_prime * chroma_second_prime != 0.0:
		delta_hue = hue_second - hue_first
		if delta_hue > 180.0:
			delta_hue -= 360.0
		elif delta_hue < -180.0:
			delta_hue += 360.0
	var delta_hue_term := 2.0 * sqrt(chroma_first_prime * chroma_second_prime) \
		* sin(deg_to_rad(delta_hue) * 0.5)
	var lightness_mean := (first.x + second.x) * 0.5
	var chroma_prime_mean := (chroma_first_prime + chroma_second_prime) * 0.5
	var hue_mean := hue_first + hue_second
	if chroma_first_prime * chroma_second_prime != 0.0:
		if absf(hue_first - hue_second) <= 180.0:
			hue_mean = (hue_first + hue_second) * 0.5
		elif hue_first + hue_second < 360.0:
			hue_mean = (hue_first + hue_second + 360.0) * 0.5
		else:
			hue_mean = (hue_first + hue_second - 360.0) * 0.5
	var t_factor := 1.0 \
		- 0.17 * cos(deg_to_rad(hue_mean - 30.0)) \
		+ 0.24 * cos(deg_to_rad(2.0 * hue_mean)) \
		+ 0.32 * cos(deg_to_rad(3.0 * hue_mean + 6.0)) \
		- 0.20 * cos(deg_to_rad(4.0 * hue_mean - 63.0))
	var delta_theta := 30.0 * exp(-pow((hue_mean - 275.0) / 25.0, 2.0))
	var chroma_prime_seventh := pow(chroma_prime_mean, 7.0)
	var rotation_chroma := 2.0 * sqrt(chroma_prime_seventh / (chroma_prime_seventh + pow(25.0, 7.0)))
	var lightness_scale := 1.0 + (0.015 * pow(lightness_mean - 50.0, 2.0)) \
		/ sqrt(20.0 + pow(lightness_mean - 50.0, 2.0))
	var chroma_scale := 1.0 + 0.045 * chroma_prime_mean
	var hue_scale := 1.0 + 0.015 * chroma_prime_mean * t_factor
	var rotation := -sin(deg_to_rad(2.0 * delta_theta)) * rotation_chroma
	var lightness_term := delta_lightness / lightness_scale
	var chroma_term := delta_chroma / chroma_scale
	var hue_term := delta_hue_term / hue_scale
	return sqrt(
		lightness_term * lightness_term
		+ chroma_term * chroma_term
		+ hue_term * hue_term
		+ rotation * chroma_term * hue_term
	)


static func positive_degrees(degrees: float) -> float:
	return fposmod(degrees, 360.0)
