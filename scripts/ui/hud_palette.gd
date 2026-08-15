class_name HudPalette
extends RefCounted

## Authored HUD state-signal palettes plus the colour science used to verify them.
##
## The HUD signals craft and combat state with four semantic roles. The authored
## set leans on cyan/amber/red, which collapses under red-green colour-vision
## deficiency: amber and red are only ~11.6 CIEDE2000 apart once deuteranopia is
## simulated. Each alternative preset here is chosen so the minimum pairwise
## separation between state roles, measured after simulating the deficiency it
## targets, clears [constant MINIMUM_STATE_SEPARATION], while every role keeps at
## least [constant MINIMUM_PANEL_CONTRAST] contrast against the HUD panel.
##
## Constructing this class or reading a palette has no side effects. The numbers
## are re-derived from these constants by `tests/accessibility_presets_test.gd`
## rather than being asserted by hand, so a future palette edit that quietly
## reintroduces a confusable pair fails the matrix.

const MODE_NONE: StringName = &"none"
const MODE_DEUTERANOPIA: StringName = &"deuteranopia"
const MODE_PROTANOPIA: StringName = &"protanopia"
const MODE_TRITANOPIA: StringName = &"tritanopia"

const ROLE_NOMINAL: StringName = &"nominal"
const ROLE_CAUTION: StringName = &"caution"
const ROLE_DANGER: StringName = &"danger"
const ROLE_MUTED: StringName = &"muted"
const ROLE_PRIMARY: StringName = &"primary"
const ROLE_NOMINAL_SOFT: StringName = &"nominal_soft"

## Panel fill every HUD readout is drawn over.
const PANEL_BACKGROUND := Color("0c1724")

## Minimum CIEDE2000 separation required between any two state roles once the
## targeted deficiency has been simulated. The authored set scores 11.6 under
## deuteranopia, so this threshold is a real gate rather than a formality.
const MINIMUM_STATE_SEPARATION := 24.0

## Minimum separation required with normal colour vision, so an accessibility
## preset never trades one audience's legibility for another's.
const MINIMUM_NORMAL_SEPARATION := 20.0

## WCAG 2.x non-text/large-text contrast floor against [constant PANEL_BACKGROUND].
const MINIMUM_PANEL_CONTRAST := 4.5

## Roles that carry craft or combat state and must therefore stay mutually
## distinguishable. `primary` and `nominal_soft` are typography, not signalling.
const STATE_ROLES: Array[StringName] = [
	ROLE_NOMINAL,
	ROLE_CAUTION,
	ROLE_DANGER,
	ROLE_MUTED,
]

# Machado, Oliveira & Fernandes (2009) severity-1.0 dichromacy matrices, applied
# in linear RGB. These are the same matrices used by the widely deployed
# colour-vision simulators, so the reported separations are comparable to what a
# reviewer would measure with an external tool.
const _SIMULATION_MATRICES := {
	MODE_PROTANOPIA: [
		Vector3(0.152286, 1.052583, -0.204868),
		Vector3(0.114503, 0.786281, 0.099216),
		Vector3(-0.003882, -0.048116, 1.051998),
	],
	MODE_DEUTERANOPIA: [
		Vector3(0.367322, 0.860646, -0.227968),
		Vector3(0.280085, 0.672501, 0.047413),
		Vector3(-0.011820, 0.042940, 0.968881),
	],
	MODE_TRITANOPIA: [
		Vector3(1.255528, -0.076749, -0.178779),
		Vector3(-0.078411, 0.930809, 0.147602),
		Vector3(0.004733, 0.691367, 0.303900),
	],
}

# `none` reproduces the authored HUD constants exactly, so leaving the preset off
# is bit-identical to the pre-accessibility build.
const _PALETTES := {
	MODE_NONE: {
		ROLE_NOMINAL: Color("62e6ef"),
		ROLE_CAUTION: Color("ffb85c"),
		ROLE_DANGER: Color("ff6b64"),
		ROLE_MUTED: Color("87a8b5"),
		ROLE_PRIMARY: Color("edfaff"),
		ROLE_NOMINAL_SOFT: Color("a9f7f5"),
	},
	# Minimum simulated separation 24.4 (danger/muted); normal-vision minimum 26.0.
	MODE_DEUTERANOPIA: {
		ROLE_NOMINAL: Color("7f9cff"),
		ROLE_CAUTION: Color("ffff00"),
		ROLE_DANGER: Color("df7038"),
		ROLE_MUTED: Color("8a918f"),
		ROLE_PRIMARY: Color("edfaff"),
		ROLE_NOMINAL_SOFT: Color("b3c4ff"),
	},
	# Minimum simulated separation 29.2 (danger/muted); normal-vision minimum 29.7.
	MODE_PROTANOPIA: {
		ROLE_NOMINAL: Color("0099ff"),
		ROLE_CAUTION: Color("f2e63d"),
		ROLE_DANGER: Color("ff5500"),
		ROLE_MUTED: Color("aab2aa"),
		ROLE_PRIMARY: Color("edfaff"),
		ROLE_NOMINAL_SOFT: Color("8fd0ff"),
	},
	# Minimum simulated separation 30.6 (caution/muted); normal-vision minimum 33.8.
	MODE_TRITANOPIA: {
		ROLE_NOMINAL: Color("85f2f2"),
		ROLE_CAUTION: Color("f9e03e"),
		ROLE_DANGER: Color("ff5226"),
		ROLE_MUTED: Color("8b8d9e"),
		ROLE_PRIMARY: Color("edfaff"),
		ROLE_NOMINAL_SOFT: Color("c2f9f9"),
	},
}

## The deficiency each preset is designed against. `none` has no target: it is
## the authored palette, recorded here so the tests can measure and report the
## defect that motivates the other three rather than assuming it.
const MODE_TARGETS := {
	MODE_DEUTERANOPIA: MODE_DEUTERANOPIA,
	MODE_PROTANOPIA: MODE_PROTANOPIA,
	MODE_TRITANOPIA: MODE_TRITANOPIA,
}


## Every stable palette ID, in menu order.
static func get_mode_ids() -> Array[StringName]:
	return [MODE_NONE, MODE_DEUTERANOPIA, MODE_PROTANOPIA, MODE_TRITANOPIA]


static func has_mode(mode_id: StringName) -> bool:
	return _PALETTES.has(mode_id)


## Returns a detached role/colour map. An unknown ID falls back to the authored
## palette instead of returning a partially populated dictionary.
static func get_palette(mode_id: StringName) -> Dictionary:
	var source: Dictionary = _PALETTES.get(mode_id, _PALETTES[MODE_NONE])
	return source.duplicate(true)


static func get_role_color(mode_id: StringName, role: StringName) -> Color:
	var palette: Dictionary = _PALETTES.get(mode_id, _PALETTES[MODE_NONE])
	return palette.get(role, palette[ROLE_PRIMARY]) as Color


## Every role a palette must define. Used to reject an incomplete preset.
static func get_required_roles() -> Array[StringName]:
	return [
		ROLE_NOMINAL,
		ROLE_CAUTION,
		ROLE_DANGER,
		ROLE_MUTED,
		ROLE_PRIMARY,
		ROLE_NOMINAL_SOFT,
	]


## Simulates how a dichromat perceives `color`. An unknown deficiency returns the
## colour unchanged so callers cannot silently measure the wrong thing.
static func simulate_dichromacy(color: Color, deficiency: StringName) -> Color:
	if not _SIMULATION_MATRICES.has(deficiency):
		return color
	var rows: Array = _SIMULATION_MATRICES[deficiency]
	var linear := color.srgb_to_linear()
	var source := Vector3(linear.r, linear.g, linear.b)
	var simulated := Color(
		clampf((rows[0] as Vector3).dot(source), 0.0, 1.0),
		clampf((rows[1] as Vector3).dot(source), 0.0, 1.0),
		clampf((rows[2] as Vector3).dot(source), 0.0, 1.0),
		color.a
	)
	return simulated.linear_to_srgb()


## CIEDE2000 difference between two sRGB colours under D65.
static func color_difference(first: Color, second: Color) -> float:
	return _delta_e_2000(_to_lab(first), _to_lab(second))


## WCAG 2.x relative-luminance contrast ratio.
static func contrast_ratio(first: Color, second: Color) -> float:
	var a := _relative_luminance(first)
	var b := _relative_luminance(second)
	var high := maxf(a, b)
	var low := minf(a, b)
	return (high + 0.05) / (low + 0.05)


## Measures a palette's state-role separation. `deficiency` may be
## [constant MODE_NONE] to measure normal colour vision. The returned report is
## the evidence a preset is judged on.
static func get_separation_report(mode_id: StringName, deficiency: StringName) -> Dictionary:
	var palette := get_palette(mode_id)
	var pairs := {}
	var minimum := INF
	var minimum_pair := PackedStringArray()
	for index in STATE_ROLES.size():
		for other in range(index + 1, STATE_ROLES.size()):
			var first_role := STATE_ROLES[index]
			var second_role := STATE_ROLES[other]
			var first := simulate_dichromacy(palette[first_role] as Color, deficiency)
			var second := simulate_dichromacy(palette[second_role] as Color, deficiency)
			var difference := color_difference(first, second)
			pairs["%s|%s" % [first_role, second_role]] = difference
			if difference < minimum:
				minimum = difference
				minimum_pair = PackedStringArray([String(first_role), String(second_role)])

	var minimum_contrast := INF
	var minimum_contrast_role := &""
	for role in STATE_ROLES:
		var ratio := contrast_ratio(palette[role] as Color, PANEL_BACKGROUND)
		if ratio < minimum_contrast:
			minimum_contrast = ratio
			minimum_contrast_role = role
	return {
		"mode": mode_id,
		"deficiency": deficiency,
		"pairs": pairs,
		"minimum_difference": minimum,
		"minimum_pair": minimum_pair,
		"minimum_panel_contrast": minimum_contrast,
		"minimum_panel_contrast_role": minimum_contrast_role,
	}


static func _relative_luminance(color: Color) -> float:
	var linear := color.srgb_to_linear()
	return 0.2126 * linear.r + 0.7152 * linear.g + 0.0722 * linear.b


static func _to_lab(color: Color) -> Vector3:
	var linear := color.srgb_to_linear()
	var x := 0.4124564 * linear.r + 0.3575761 * linear.g + 0.1804375 * linear.b
	var y := 0.2126729 * linear.r + 0.7151522 * linear.g + 0.0721750 * linear.b
	var z := 0.0193339 * linear.r + 0.1191920 * linear.g + 0.9503041 * linear.b
	var fx := _lab_transfer(x / 0.95047)
	var fy := _lab_transfer(y / 1.0)
	var fz := _lab_transfer(z / 1.08883)
	return Vector3(116.0 * fy - 16.0, 500.0 * (fx - fy), 200.0 * (fy - fz))


static func _lab_transfer(value: float) -> float:
	return pow(value, 1.0 / 3.0) if value > 216.0 / 24389.0 else (841.0 / 108.0) * value + 4.0 / 29.0


static func _delta_e_2000(first: Vector3, second: Vector3) -> float:
	var l1 := first.x
	var a1 := first.y
	var b1 := first.z
	var l2 := second.x
	var a2 := second.y
	var b2 := second.z
	var c1 := sqrt(a1 * a1 + b1 * b1)
	var c2 := sqrt(a2 * a2 + b2 * b2)
	var c_bar := (c1 + c2) * 0.5
	var c_bar_7 := pow(c_bar, 7.0)
	var g := 0.5 * (1.0 - sqrt(c_bar_7 / (c_bar_7 + 6103515625.0)))
	var a1p := (1.0 + g) * a1
	var a2p := (1.0 + g) * a2
	var c1p := sqrt(a1p * a1p + b1 * b1)
	var c2p := sqrt(a2p * a2p + b2 * b2)
	var h1p := fposmod(rad_to_deg(atan2(b1, a1p)), 360.0) if not (is_zero_approx(a1p) and is_zero_approx(b1)) else 0.0
	var h2p := fposmod(rad_to_deg(atan2(b2, a2p)), 360.0) if not (is_zero_approx(a2p) and is_zero_approx(b2)) else 0.0

	var delta_l := l2 - l1
	var delta_c := c2p - c1p
	var delta_h_angle := 0.0
	if not is_zero_approx(c1p * c2p):
		delta_h_angle = h2p - h1p
		if delta_h_angle > 180.0:
			delta_h_angle -= 360.0
		elif delta_h_angle < -180.0:
			delta_h_angle += 360.0
	var delta_h := 2.0 * sqrt(c1p * c2p) * sin(deg_to_rad(delta_h_angle) * 0.5)

	var l_bar := (l1 + l2) * 0.5
	var c_bar_p := (c1p + c2p) * 0.5
	var h_bar := h1p + h2p
	if not is_zero_approx(c1p * c2p):
		if absf(h1p - h2p) > 180.0:
			h_bar = (h1p + h2p + 360.0) * 0.5 if h1p + h2p < 360.0 else (h1p + h2p - 360.0) * 0.5
		else:
			h_bar = (h1p + h2p) * 0.5

	var t := (
		1.0
		- 0.17 * cos(deg_to_rad(h_bar - 30.0))
		+ 0.24 * cos(deg_to_rad(2.0 * h_bar))
		+ 0.32 * cos(deg_to_rad(3.0 * h_bar + 6.0))
		- 0.20 * cos(deg_to_rad(4.0 * h_bar - 63.0))
	)
	var delta_theta := 30.0 * exp(-pow((h_bar - 275.0) / 25.0, 2.0))
	var c_bar_p_7 := pow(c_bar_p, 7.0)
	var rc := 2.0 * sqrt(c_bar_p_7 / (c_bar_p_7 + 6103515625.0))
	var l_offset := l_bar - 50.0
	var sl := 1.0 + (0.015 * l_offset * l_offset) / sqrt(20.0 + l_offset * l_offset)
	var sc := 1.0 + 0.045 * c_bar_p
	var sh := 1.0 + 0.015 * c_bar_p * t
	var rt := -sin(deg_to_rad(2.0 * delta_theta)) * rc
	var term_l := delta_l / sl
	var term_c := delta_c / sc
	var term_h := delta_h / sh
	return sqrt(term_l * term_l + term_c * term_c + term_h * term_h + rt * term_c * term_h)
