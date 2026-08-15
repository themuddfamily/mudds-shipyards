extends SceneTree

## Freezes the fleet-wide properties that the Phase 4 "differentiated roles,
## readable colours, physical boarding, cockpit seating, interiors appropriate
## to vessel size" item actually delivers today, measured from the production
## Main scene rather than from source constants.
##
## This is an audit regression, not a tuning pass. Where a property does not
## hold across all four craft the suite freezes it only for the craft where it
## genuinely holds, and records the measured deficiency as a non-regression
## floor so a later player-led feel pass can only improve it. Two deficiencies
## are deliberately NOT asserted as passing and are documented instead:
##
##   * All four craft share one near-white body tone. The measured CIEDE2000
##     between the closest pair (Jovian #e7e4d6 and Zenith #e6e2d5) is 0.82,
##     below the just-noticeable difference, and the widest pair reaches only
##     7.3. The Arrow/Jovian/Zenith identification accents also cluster in
##     cyan-teal (min CIEDE2000 6.40 under simulated protanopia), so only the
##     warm-gold Torrent accent separates at a glance. Body-tone separations
##     are printed as evidence rather than asserted, because no floor over
##     numbers this small would mean anything.
##   * Zenith places its cockpit camera 0.86 m BELOW the seated pilot's head
##     bone (the other three place it 0.20 m above), and the seated pilot's
##     head bone clears Zenith's outer hull by only 0.06 m against 0.56 m or
##     more elsewhere. Zenith's eye point is therefore not frozen as plausible.
##
## No handling value, colour, or geometry is modified anywhere in this suite.

const MAIN_SCENE := preload("res://scenes/main.tscn")

# Staging is a single placement outside the production 7.0 m boarding fallback
# reach. Every metre after that is real joypad locomotion through the live
# PlayerController; the suite proves no candidate exists before the walk.
const APPROACH_OFFSETS := {
	&"torrent_provisional": Vector3(0.0, 0.0, 12.0),
	&"arrow_provisional": Vector3(0.0, 0.0, 12.0),
	&"jovian_provisional": Vector3(0.0, 0.0, 12.0),
	# Fleet Dock 01 is an elevated 12 x 15 m slab; a longer aft stage walks off
	# its edge, so Zenith is staged diagonally at 8.06 m instead.
	&"zenith_b7_observed": Vector3(-4.0, 0.0, 7.0),
}
const MINIMUM_STAGED_DISTANCE := 7.05
const MINIMUM_WALK_METRES := 1.2
const BOARDING_FALLBACK_REACH := 7.0

const AXIS_LEFT_X := 0
const AXIS_LEFT_Y := 1
const BUTTON_X := 2
const BUTTON_LEFT_STICK := 7
const WALK_TIMEOUT_SECONDS := 8.0

# Trade-off axes with an unambiguous "more is better for the pilot" reading.
# Feel-only axes (flight_assist_strength, maximum_mouse_turn_degrees,
# visual_bank_degrees) are excluded from the dominance test on purpose.
const HIGHER_IS_BETTER := [
	"maximum_speed", "thrust_acceleration", "brake_acceleration", "boost_speed",
	"boost_multiplier", "yaw_speed_degrees", "roll_speed_degrees",
	"throttle_response", "maximum_hull", "landing_maximum_speed",
]
const LOWER_IS_BETTER := ["passive_drag", "engine_start_time", "weapon_cooldown"]

# Exact identification accents as authored in the four production ship scenes.
const EXPECTED_ACCENTS := {
	&"torrent_provisional": "f0b94d",
	&"arrow_provisional": "45dee6",
	&"jovian_provisional": "38bdb5",
	&"zenith_b7_observed": "c9dee0",
}

# Each craft's body tone: the brightest rendered opaque albedo holding at least
# a tenth of the craft's visible surface area. This is the colour a player reads
# off the hull at a glance, as opposed to trim, machinery, or emissive detail.
const EXPECTED_BODY_TONE := {
	&"torrent_provisional": "e8e2cf",
	&"arrow_provisional": "e9eee9",
	&"jovian_provisional": "e7e4d6",
	&"zenith_b7_observed": "e6e2d5",
}
const BODY_TONE_MINIMUM_SHARE := 0.10

# Measured CIEDE2000 floors. Accents: separation is genuine only for Torrent.
const ACCENT_FLOORS := {
	"normal": 10.0, "protanopia": 6.3, "deuteranopia": 10.4, "tritanopia": 8.7,
}
const TORRENT_ACCENT_FLOOR := 25.0
const VISION_MODELS := ["normal", "protanopia", "deuteranopia", "tritanopia"]

# Craft whose cockpit camera sits at a plausible seated eye point.
const PLAUSIBLE_EYE_POINT_CRAFT := [
	&"torrent_provisional", &"arrow_provisional", &"jovian_provisional",
]
const EYE_ABOVE_HEAD_BONE_MINIMUM := 0.15
const EYE_ABOVE_HEAD_BONE_MAXIMUM := 0.35
const HEAD_HULL_CLEARANCE_MINIMUM := 0.5

const FIGHTER_IDS := [&"torrent_provisional", &"arrow_provisional", &"zenith_b7_observed"]
const INTERIOR_NODE_NAMES := [
	"WalkableInterior", "CargoBay", "PassengerCabin", "InteriorOccupantVolume",
]

var _failures: Array[String] = []
var _assertion_count := 0
var _seat_evidence: Array[String] = []
var _colour_evidence: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var game := MAIN_SCENE.instantiate() as GameFlow
	_check(game != null, "production Main instantiates for the fleet role audit")
	if game == null:
		_finish()
		return
	root.add_child(game)
	await process_frame
	await process_frame
	for _settle in 6:
		await physics_frame
		await process_frame

	var player := game.get_node_or_null("Player") as PlayerController
	var fleet: Array[HeroShip] = game.get_flyable_ships()
	_check(player != null and fleet.size() == 4, "the audit resolves the live player and all four flyables")
	if player == null or fleet.size() != 4:
		await _clean_up(game)
		_finish()
		return

	var by_id := {}
	for craft in fleet:
		by_id[craft.get_ship_id()] = craft
	_check(by_id.size() == 4, "the four flyables carry four distinct stable ship identities")

	_test_role_differentiation(by_id)
	_test_readable_colours(by_id)
	await _test_physical_boarding_and_cockpit_seating(game, player, by_id)
	_test_interior_provision(by_id)

	for line in _colour_evidence:
		print(line)
	for line in _seat_evidence:
		print(line)
	await _clean_up(game)
	_finish()


# ---------------------------------------------------------------- roles ----

func _test_role_differentiation(by_id: Dictionary) -> void:
	var profiles := {}
	var roles := PackedStringArray()
	for ship_id: StringName in by_id:
		var definition := (by_id[ship_id] as HeroShip).get_ship_definition()
		_check(definition != null, "%s carries a ShipDefinition in the production scene" % ship_id)
		if definition == null:
			return
		var merged := definition.get_flight_profile().duplicate()
		merged.merge(definition.get_systems_profile())
		profiles[ship_id] = merged
		if not roles.has(definition.get_role()):
			roles.append(definition.get_role())
	_check(roles.size() == 4, "the four craft declare four distinct role names")

	var ids: Array = by_id.keys()
	ids.sort()
	var minimum_differing := 99
	for first_index in ids.size():
		for second_index in range(first_index + 1, ids.size()):
			var first: StringName = ids[first_index]
			var second: StringName = ids[second_index]
			var first_profile: Dictionary = profiles[first]
			var second_profile: Dictionary = profiles[second]
			var differing := 0
			for key: String in first_profile:
				if not is_equal_approx(float(first_profile[key]), float(second_profile[key])):
					differing += 1
			minimum_differing = mini(minimum_differing, differing)
			_check(
				differing >= 14,
				"%s and %s differ on at least 14 of the 16 handling axes (%d)"
					% [first, second, differing]
			)
	_seat_evidence.append(
		"FLEET_ROLE_EVIDENCE: minimum_differing_handling_axes=%d of 16" % minimum_differing
	)

	# Lateral trade-offs, not straight statistical upgrades: for every ordered
	# pair the second craft must beat the first on at least one trade-off axis.
	for first: StringName in ids:
		for second: StringName in ids:
			if first == second:
				continue
			var advantages := _count_advantages(profiles[first], profiles[second])
			_check(
				advantages > 0,
				"%s is not a strict statistical upgrade over %s (%d lateral advantages)"
					% [second, first, advantages]
			)

	# Frozen role signatures. Each craft is the sole extreme on its own axis.
	_check(
		_is_sole_extreme(profiles, &"jovian_provisional", "maximum_hull", true)
		and _is_sole_extreme(profiles, &"jovian_provisional", "maximum_speed", false),
		"the freighter alone owns the highest hull and the lowest top speed"
	)
	_check(
		_is_sole_extreme(profiles, &"zenith_b7_observed", "roll_speed_degrees", true)
		and _is_sole_extreme(profiles, &"zenith_b7_observed", "yaw_speed_degrees", true)
		and _is_sole_extreme(profiles, &"zenith_b7_observed", "maximum_hull", false),
		"Zenith alone owns the highest yaw and roll while owning the lowest hull"
	)
	var arrow_profile: Dictionary = profiles[&"arrow_provisional"]
	_check(
		_is_sole_extreme(profiles, &"arrow_provisional", "boost_speed", true)
		and float(arrow_profile["thrust_acceleration"])
			< float((profiles[&"torrent_provisional"] as Dictionary)["thrust_acceleration"])
		and float(arrow_profile["thrust_acceleration"])
			< float((profiles[&"zenith_b7_observed"] as Dictionary)["thrust_acceleration"])
		and float(arrow_profile["weapon_cooldown"])
			> float((profiles[&"zenith_b7_observed"] as Dictionary)["weapon_cooldown"]),
		"Arrow alone owns the highest boost speed while trading launch acceleration and weapon cadence for it"
	)
	_check(
		_is_sole_extreme(profiles, &"torrent_provisional", "boost_multiplier", true)
		and _is_sole_extreme(profiles, &"torrent_provisional", "weapon_cooldown", false)
		and _is_sole_extreme(profiles, &"torrent_provisional", "landing_maximum_speed", true),
		"Torrent alone owns the strongest boost multiplier, fastest cadence, and most forgiving landing gate"
	)


func _count_advantages(first: Dictionary, second: Dictionary) -> int:
	var advantages := 0
	for key: String in HIGHER_IS_BETTER:
		if float(second[key]) > float(first[key]):
			advantages += 1
	for key: String in LOWER_IS_BETTER:
		if float(second[key]) < float(first[key]):
			advantages += 1
	return advantages


func _is_sole_extreme(profiles: Dictionary, ship_id: StringName, key: String, want_maximum: bool) -> bool:
	var subject := float((profiles[ship_id] as Dictionary)[key])
	for other: StringName in profiles:
		if other == ship_id:
			continue
		var value := float((profiles[other] as Dictionary)[key])
		if want_maximum and value >= subject:
			return false
		if not want_maximum and value <= subject:
			return false
	return true


# -------------------------------------------------------------- colours ----

func _test_readable_colours(by_id: Dictionary) -> void:
	var accents := {}
	var hulls := {}
	for ship_id: StringName in by_id:
		var craft := by_id[ship_id] as HeroShip
		# Colour readability is judged at the close level of detail, so the
		# measurement drives each authored presentation's public LOD API to its
		# close state first. Nothing else about the craft is touched.
		_force_close_lod(craft)
		var accent := craft.identification_accent.to_html(false)
		accents[ship_id] = accent
		_check(
			accent == EXPECTED_ACCENTS[ship_id],
			"%s renders its exact authored identification accent #%s" % [ship_id, accent]
		)
		var body_tone := _body_tone_albedo(craft)
		hulls[ship_id] = body_tone
		_check(
			body_tone == EXPECTED_BODY_TONE[ship_id],
			"%s presents its exact rendered body tone #%s" % [ship_id, body_tone]
		)
	_check(_distinct_value_count(accents) == 4, "all four craft carry distinct identification accents")

	for mode: String in VISION_MODELS:
		var accent_minimum := _minimum_separation(accents, mode)
		_check(
			accent_minimum >= float(ACCENT_FLOORS[mode]),
			"accent separation under %s stays at or above its %.1f floor (%.2f)"
				% [mode, ACCENT_FLOORS[mode], accent_minimum]
		)
		# Body-tone separation is recorded rather than asserted: the four hulls
		# are the same off-white and no floor here would mean anything. The
		# measured numbers are the audit finding for the feel pass.
		_colour_evidence.append(
			"FLEET_COLOUR_EVIDENCE: body_tone_min_ciede2000 under %s = %.2f"
				% [mode, _minimum_separation(hulls, mode)]
		)

	# Only the warm-gold Torrent accent is genuinely readable against the rest.
	var torrent_minimum := INF
	for mode: String in VISION_MODELS:
		for ship_id: StringName in accents:
			if ship_id == &"torrent_provisional":
				continue
			torrent_minimum = minf(
				torrent_minimum,
				_separation(str(accents[&"torrent_provisional"]), str(accents[ship_id]), mode)
			)
	_check(
		torrent_minimum >= TORRENT_ACCENT_FLOOR,
		"the Torrent gold accent stays strongly separated from every other accent in normal and dichromatic vision (%.2f)"
			% torrent_minimum
	)


func _force_close_lod(craft: HeroShip) -> void:
	for node in craft.find_children("*", "Node3D", true, false):
		if node.has_method("update_lod_for_distance"):
			node.call("update_lod_for_distance", 0.0)


func _distinct_value_count(values: Dictionary) -> int:
	var seen := PackedStringArray()
	for key: StringName in values:
		var value := str(values[key])
		if not seen.has(value):
			seen.append(value)
	return seen.size()


func _minimum_separation(values: Dictionary, mode: String) -> float:
	var keys: Array = values.keys()
	keys.sort()
	var minimum := INF
	for first_index in keys.size():
		for second_index in range(first_index + 1, keys.size()):
			minimum = minf(
				minimum,
				_separation(str(values[keys[first_index]]), str(values[keys[second_index]]), mode)
			)
	return minimum


func _body_tone_albedo(craft: HeroShip) -> String:
	var weights := {}
	var total := 0.0
	for node in craft.find_children("*", "MeshInstance3D", true, false):
		var mesh_instance := node as MeshInstance3D
		if not mesh_instance.is_visible_in_tree() or mesh_instance.mesh == null:
			continue
		var material := mesh_instance.material_override as StandardMaterial3D
		if material == null:
			material = mesh_instance.mesh.surface_get_material(0) as StandardMaterial3D
		if material == null:
			continue
		if material.transparency != BaseMaterial3D.TRANSPARENCY_DISABLED \
			or material.albedo_color.a < 0.95:
			continue
		var size := mesh_instance.get_aabb().size * mesh_instance.global_transform.basis.get_scale()
		var area := 2.0 * (size.x * size.y + size.y * size.z + size.x * size.z)
		if area <= 0.0:
			continue
		var hex := material.albedo_color.to_html(false)
		weights[hex] = float(weights.get(hex, 0.0)) + area
		total += area
	var best := ""
	var best_lightness := -1.0
	var keys: Array = weights.keys()
	keys.sort()
	for hex: String in keys:
		if float(weights[hex]) / maxf(total, 0.0001) < BODY_TONE_MINIMUM_SHARE:
			continue
		var lightness := _linear_to_lab(_hex_to_linear(hex)).x
		if lightness > best_lightness:
			best_lightness = lightness
			best = hex
	return best


## CIEDE2000 between two sRGB hex colours, optionally through a Viénot 1999
## dichromat simulation, so separation is measured perceptually rather than by
## comparing hex digits.
func _separation(first_hex: String, second_hex: String, mode: String) -> float:
	return _ciede2000(
		_linear_to_lab(_simulate(_hex_to_linear(first_hex), mode)),
		_linear_to_lab(_simulate(_hex_to_linear(second_hex), mode))
	)


func _hex_to_linear(hex: String) -> Vector3:
	var colour := Color(hex)
	return Vector3(
		_srgb_component_to_linear(colour.r),
		_srgb_component_to_linear(colour.g),
		_srgb_component_to_linear(colour.b)
	)


func _srgb_component_to_linear(value: float) -> float:
	if value <= 0.04045:
		return value / 12.92
	return pow((value + 0.055) / 1.055, 2.4)


func _simulate(linear: Vector3, mode: String) -> Vector3:
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


func _linear_to_lab(linear: Vector3) -> Vector3:
	var x := 0.4124564 * linear.x + 0.3575761 * linear.y + 0.1804375 * linear.z
	var y := 0.2126729 * linear.x + 0.7151522 * linear.y + 0.0721750 * linear.z
	var z := 0.0193339 * linear.x + 0.1191920 * linear.y + 0.9503041 * linear.z
	var fx := _lab_transfer(x / 0.95047)
	var fy := _lab_transfer(y)
	var fz := _lab_transfer(z / 1.08883)
	return Vector3(116.0 * fy - 16.0, 500.0 * (fx - fy), 200.0 * (fy - fz))


func _lab_transfer(value: float) -> float:
	var safe := maxf(value, 0.0)
	if safe > 216.0 / 24389.0:
		return pow(safe, 1.0 / 3.0)
	return (841.0 / 108.0) * safe + 4.0 / 29.0


func _ciede2000(first: Vector3, second: Vector3) -> float:
	var chroma_first := Vector2(first.y, first.z).length()
	var chroma_second := Vector2(second.y, second.z).length()
	var chroma_mean := (chroma_first + chroma_second) * 0.5
	var chroma_seventh := pow(chroma_mean, 7.0)
	var g_factor := 0.5 * (1.0 - sqrt(chroma_seventh / (chroma_seventh + pow(25.0, 7.0))))
	var a_first := (1.0 + g_factor) * first.y
	var a_second := (1.0 + g_factor) * second.y
	var chroma_first_prime := Vector2(a_first, first.z).length()
	var chroma_second_prime := Vector2(a_second, second.z).length()
	var hue_first := _positive_degrees(rad_to_deg(atan2(first.z, a_first)))
	var hue_second := _positive_degrees(rad_to_deg(atan2(second.z, a_second)))
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


func _positive_degrees(degrees: float) -> float:
	return fposmod(degrees, 360.0)


# --------------------------------------------- boarding and seating ----

func _test_physical_boarding_and_cockpit_seating(
		game: GameFlow,
		player: PlayerController,
		by_id: Dictionary
	) -> void:
	game.canopy_motion_time = 0.0
	game.boarding_motion_time = 0.05
	game.disembarking_motion_time = 0.05
	await _tap_button(BUTTON_X)
	var approach_ready := await _wait_until(
		func() -> bool:
			return game.phase == GameFlow.Phase.APPROACH_SHIP and player.is_control_enabled(),
		2.0
	)
	_check(
		approach_ready,
		"controller X grants live on-foot approach authority before any craft is boarded"
	)

	var skeleton := _find_skeleton(player)
	_check(skeleton != null, "the production player exposes its skinned pilot skeleton")
	var head_bone := _find_bone(skeleton, "head")
	_check(head_bone >= 0, "the skinned pilot rig exposes a head bone for eye-point measurement")

	var ids: Array = by_id.keys()
	ids.sort()
	for ship_id: StringName in ids:
		var craft := by_id[ship_id] as HeroShip
		var boarding := craft.get_boarding_position() + craft.global_basis.y.normalized() * 0.05
		var offset: Vector3 = APPROACH_OFFSETS[ship_id]
		var start := boarding + craft.global_basis * offset
		var direction := (boarding - start).slide(Vector3.UP).normalized()
		player.teleport_to(Transform3D(Basis.looking_at(direction, Vector3.UP).orthonormalized(), start))
		for _settle in 24:
			await physics_frame
			await process_frame

		var staged_distance := player.get_interaction_origin().distance_to(craft.get_boarding_position())
		_check(
			staged_distance > MINIMUM_STAGED_DISTANCE,
			"%s approach begins beyond the production %.1f m boarding reach (%.2f m)"
				% [ship_id, BOARDING_FALLBACK_REACH, staged_distance]
		)
		_check(
			game.boarding_candidate == null,
			"%s offers no boarding prompt from the staged approach start" % ship_id
		)

		var staged_position := player.global_position
		var grounded_ticks := await _walk_to_candidate(player, craft, game)
		var walked := player.global_position.distance_to(staged_position)
		_check(
			walked >= MINIMUM_WALK_METRES,
			"%s is reached by real left-stick locomotion, not by placement (%.2f m walked)"
				% [ship_id, walked]
		)
		_check(
			grounded_ticks > 0,
			"%s approach stays on production collision while walking (%d grounded ticks)"
				% [ship_id, grounded_ticks]
		)
		_check(
			game.boarding_candidate == craft,
			"%s exposes its boarding prompt only after the physical approach" % ship_id
		)
		if game.boarding_candidate != craft:
			continue

		await _tap_button(BUTTON_X)
		var boarded := await _wait_until(
			func() -> bool: return game.phase == GameFlow.Phase.START_ENGINES,
			3.0
		)
		_check(boarded, "%s completes production boarding from the walked-up prompt" % ship_id)
		_check(
			player.is_seated() and craft.is_piloted() and game.get_active_ship() == craft,
			"%s seats the same visible player and takes piloting authority" % ship_id
		)
		if not boarded:
			continue

		_assert_cockpit_seating(craft, player, skeleton, head_bone, ship_id)

		await _tap_button(BUTTON_X)
		await player.disembarking_completed
		await _wait_until(func() -> bool: return player.is_control_enabled(), 2.0)
		for _settle in 10:
			await physics_frame
			await process_frame
		_check(
			not player.is_seated(),
			"%s returns the player to on-foot authority for the next physical approach" % ship_id
		)


func _assert_cockpit_seating(
		craft: HeroShip,
		player: PlayerController,
		skeleton: Skeleton3D,
		head_bone: int,
		ship_id: StringName
	) -> void:
	var seat := craft.get_pilot_seat_anchor()
	_check(seat != null and craft.is_ancestor_of(seat), "%s pilot seat rides the craft hierarchy" % ship_id)
	_check(
		seat != null and str(seat.get_parent().name) == "CockpitInterior",
		"%s seats its pilot inside the functional cockpit, not on a loose marker" % ship_id
	)
	_check(
		seat != null and player.global_position.distance_to(seat.global_position) < 0.001,
		"%s holds the seated player exactly on its live seat anchor" % ship_id
	)

	var camera := _find_cockpit_camera(craft)
	_check(camera != null, "%s exposes a cockpit camera" % ship_id)
	if camera == null or seat == null or skeleton == null or head_bone < 0:
		return
	_check(
		str(camera.get_parent().name) == "CockpitInterior",
		"%s cockpit camera is mounted inside the cockpit rather than floating on the hull" % ship_id
	)
	_check(
		(-camera.global_basis.z.normalized()).dot(-craft.global_basis.z.normalized()) > 0.999,
		"%s cockpit camera looks along the craft's own nose axis" % ship_id
	)
	var camera_local := craft.to_local(camera.global_position)
	var seat_local := craft.to_local(seat.global_position)
	_check(
		camera_local.y > seat_local.y,
		"%s cockpit camera sits above its seat pan rather than under the floor" % ship_id
	)

	var head_world := skeleton.global_transform * skeleton.get_bone_global_pose(head_bone)
	var head_local := craft.to_local(head_world.origin)
	var eye_offset := camera_local.y - head_local.y
	var hull_top := _visible_hull_top(craft)
	var head_clearance := hull_top - head_local.y
	_seat_evidence.append(
		"FLEET_SEATING_EVIDENCE: %s camera_above_head_bone=%.3f head_hull_clearance=%.3f"
			% [ship_id, eye_offset, head_clearance]
	)
	if not PLAUSIBLE_EYE_POINT_CRAFT.has(ship_id):
		# Zenith is deliberately excluded; see the suite header.
		return
	_check(
		eye_offset >= EYE_ABOVE_HEAD_BONE_MINIMUM and eye_offset <= EYE_ABOVE_HEAD_BONE_MAXIMUM,
		"%s places its cockpit camera at a seated eye point above the pilot's head bone (%.3f m)"
			% [ship_id, eye_offset]
	)
	_check(
		head_clearance >= HEAD_HULL_CLEARANCE_MINIMUM,
		"%s seats the pilot's head inside its own outer hull (%.3f m clearance)"
			% [ship_id, head_clearance]
	)


func _visible_hull_top(craft: HeroShip) -> float:
	var top := -INF
	for node in craft.find_children("*", "MeshInstance3D", true, false):
		var mesh_instance := node as MeshInstance3D
		if not mesh_instance.is_visible_in_tree() or mesh_instance.mesh == null:
			continue
		var to_craft := craft.global_transform.affine_inverse() * mesh_instance.global_transform
		var box: AABB = to_craft * mesh_instance.get_aabb()
		top = maxf(top, box.position.y + box.size.y)
	return top


func _find_cockpit_camera(craft: HeroShip) -> Camera3D:
	for node in craft.find_children("CockpitCamera", "Camera3D", true, false):
		return node as Camera3D
	return null


func _find_skeleton(player: PlayerController) -> Skeleton3D:
	for node in player.find_children("*", "Skeleton3D", true, false):
		return node as Skeleton3D
	return null


func _find_bone(skeleton: Skeleton3D, bone_name: String) -> int:
	if skeleton == null:
		return -1
	for index in skeleton.get_bone_count():
		if skeleton.get_bone_name(index).to_lower() == bone_name:
			return index
	return -1


# ------------------------------------------------------------ interiors ----

func _test_interior_provision(by_id: Dictionary) -> void:
	var jovian := by_id[&"jovian_provisional"] as HeroShip
	_check(
		jovian.has_method("get_walkable_interior_report"),
		"the declared light freighter is the craft that publishes a walkable interior"
	)
	var report: Dictionary = jovian.call("get_walkable_interior_report")
	_check(
		(report.get("root", null) as Node3D) != null and not bool(report.get("detached_interior", true)),
		"the freighter interior is a connected part of the ship frame, not a detached set"
	)
	_check(
		int(report.get("passenger_seat_count", 0)) >= 4,
		"the freighter interior carries a passenger complement its role implies (%d seats)"
			% int(report.get("passenger_seat_count", 0))
	)
	_check(
		(report.get("access_marker", null) as Node3D) != null
		and (report.get("deck_marker", null) as Node3D) != null,
		"the freighter interior publishes both its exterior access and interior deck markers"
	)
	var bounds: AABB = jovian.call("get_interior_bounds")
	_check(
		bounds.size.x > 11.0 and bounds.size.y > 4.0 and bounds.size.z > 17.0,
		"the freighter interior is a walkable volume rather than a token cavity %s" % str(bounds.size)
	)
	var jovian_tags := jovian.get_ship_definition().get_compatibility_tags()
	_check(
		jovian_tags.has("medium_craft") and jovian_tags.has("light_freighter"),
		"the only craft with an interior is the only craft declared medium/light-freighter class"
	)
	var jovian_envelope := _collision_envelope(jovian)
	_check(
		jovian_envelope.size.x > 15.0 and jovian_envelope.size.z > 25.0,
		"the interior-bearing craft is the physically largest hull %s" % str(jovian_envelope.size)
	)

	for ship_id: StringName in FIGHTER_IDS:
		var fighter := by_id[ship_id] as HeroShip
		_check(
			not fighter.has_method("get_walkable_interior_report")
			and not fighter.has_method("get_interior_root"),
			"%s claims no walkable interior it does not have" % ship_id
		)
		var interior_nodes := 0
		for node_name: String in INTERIOR_NODE_NAMES:
			interior_nodes += fighter.find_children(node_name, "", true, false).size()
		_check(
			interior_nodes == 0,
			"%s carries no cargo bay, passenger cabin, or interior occupant volume" % ship_id
		)
		_check(
			fighter.find_children("*", "MovingInteriorFrame", true, false).is_empty(),
			"%s runs no moving-interior coordinator a fighter has no use for" % ship_id
		)
		var tags := fighter.get_ship_definition().get_compatibility_tags()
		_check(
			tags.has("small_craft")
			and not tags.has("freight")
			and not tags.has("cargo")
			and not tags.has("light_freighter"),
			"%s declares small-craft compatibility with no freight claim" % ship_id
		)
		var cockpit := fighter.find_children("CockpitInterior", "Node3D", true, false)
		_check(cockpit.size() == 1, "%s owns exactly one functional cockpit volume" % ship_id)
		if cockpit.size() == 1:
			var seats := (cockpit[0] as Node3D).find_children("*SeatAnchor*", "Marker3D", true, false)
			_check(
				seats.size() == 1,
				"%s provides exactly the single pilot station its fighter role implies" % ship_id
			)
		var envelope := _collision_envelope(fighter)
		_check(
			envelope.size.x < 15.0 and envelope.size.z < 15.0,
			"%s stays inside the small-craft envelope %s" % [ship_id, str(envelope.size)]
		)


func _collision_envelope(craft: HeroShip) -> AABB:
	var result := AABB()
	var first := true
	for child in craft.get_children():
		var collision := child as CollisionShape3D
		if collision == null or collision.disabled or collision.shape == null:
			continue
		var box: AABB = collision.transform * collision.shape.get_debug_mesh().get_aabb()
		if first:
			result = box
			first = false
		else:
			result = result.merge(box)
	return result


# -------------------------------------------------------------- harness ----

func _walk_to_candidate(player: PlayerController, craft: HeroShip, game: GameFlow) -> int:
	var deadline := Time.get_ticks_msec() + int(WALK_TIMEOUT_SECONDS * 1000.0)
	var grounded_ticks := 0
	_set_button(BUTTON_LEFT_STICK, true)
	while Time.get_ticks_msec() < deadline:
		if game.boarding_candidate == craft:
			break
		var offset := craft.get_boarding_position() - player.get_interaction_origin()
		var flat := offset.slide(Vector3.UP)
		if flat.length() <= 1.2:
			break
		var desired := flat.normalized()
		var yaw := player.get_node_or_null("CameraYaw") as Node3D
		var reference := yaw.global_basis if yaw != null else player.global_basis
		var forward := (-reference.z).slide(Vector3.UP).normalized()
		var right := forward.cross(Vector3.UP).normalized()
		_set_axis(AXIS_LEFT_X, clampf(desired.dot(right), -1.0, 1.0))
		_set_axis(AXIS_LEFT_Y, clampf(-desired.dot(forward), -1.0, 1.0))
		await physics_frame
		if player.is_on_floor():
			grounded_ticks += 1
		await process_frame
	_release_joypad()
	for _settle in 5:
		await physics_frame
		await process_frame
	return grounded_ticks


func _tap_button(index: int) -> void:
	_set_button(index, true)
	await physics_frame
	await process_frame
	_set_button(index, false)
	await physics_frame
	await process_frame


func _set_axis(axis: int, value: float) -> void:
	var event := InputEventJoypadMotion.new()
	event.device = 0
	event.axis = axis
	event.axis_value = clampf(value, -1.0, 1.0)
	Input.parse_input_event(event)


func _set_button(index: int, pressed: bool) -> void:
	var event := InputEventJoypadButton.new()
	event.device = 0
	event.button_index = index
	event.pressed = pressed
	Input.parse_input_event(event)


func _release_joypad() -> void:
	for axis in [0, 1, 2, 3, 4, 5]:
		_set_axis(axis, 0.0)
	for button in [0, 2, 3, 7, 10, 11, 12, 13]:
		_set_button(button, false)


func _wait_until(predicate: Callable, timeout_seconds: float) -> bool:
	var deadline := Time.get_ticks_msec() + int(timeout_seconds * 1000.0)
	while Time.get_ticks_msec() < deadline:
		if bool(predicate.call()):
			return true
		await physics_frame
		await process_frame
	return bool(predicate.call())


func _clean_up(game: Node) -> void:
	_release_joypad()
	for action in [&"interact", &"move_forward", &"fire", &"engine_start", &"engine_stop", &"landing_assist"]:
		Input.action_release(action)
	await _release_combat_audio_before_main_teardown(game)
	game.queue_free()
	await process_frame
	await physics_frame
	await process_frame


func _release_combat_audio_before_main_teardown(game: Node) -> void:
	var combat_audio := game.get_node_or_null("CombatAudioPresentation") as CombatAudioPresentation
	if combat_audio == null:
		return
	for candidate in combat_audio.find_children("*", "AudioStreamPlayer3D", true, false):
		var audio_player := candidate as AudioStreamPlayer3D
		audio_player.stop()
		audio_player.stream_paused = false
		audio_player.stream = null
	await process_frame
	var mixer_release_seconds := maxf(
		0.05,
		AudioServer.get_time_to_next_mix() + AudioServer.get_output_latency()
	)
	await create_timer(mixer_release_seconds).timeout
	var parent := combat_audio.get_parent()
	if parent != null:
		parent.remove_child(combat_audio)
	combat_audio.free()
	await process_frame


func _check(condition: bool, description: String) -> void:
	_assertion_count += 1
	if condition:
		print("PASS: ", description)
	else:
		_failures.append(description)
		push_error("FAIL: " + description)


func _finish() -> void:
	if _failures.is_empty():
		print("FLEET_ROLE_DIFFERENTIATION_TEST_OK: %d assertions" % _assertion_count)
		quit(0)
	else:
		print(
			"FLEET_ROLE_DIFFERENTIATION_TEST_FAILED: %d/%d assertions failed: %s"
				% [_failures.size(), _assertion_count, "; ".join(_failures)]
		)
		quit(1)
