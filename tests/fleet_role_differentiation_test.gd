extends SceneTree

## Freezes the fleet-wide properties that the Phase 4 "differentiated roles,
## readable colours, physical boarding, cockpit seating, interiors appropriate
## to vessel size" item actually delivers today, measured from the production
## Main scene rather than from source constants.
##
## This is an audit regression, not a tuning pass. Where a property does not
## hold across all four craft the suite freezes it only for the craft where it
## genuinely holds, and records the measured deficiency as a non-regression
## floor so a later player-led feel pass can only improve it. One deficiency is
## deliberately NOT asserted as passing and is documented instead:
##
<<<<<<< HEAD
##   * All four craft share one near-white body tone. The measured CIEDE2000
##     between the closest pair (Jovian #e7e4d6 and Zenith #e6e2d5) is 0.82,
##     below the just-noticeable difference, and the widest pair reaches only
##     7.3. The Arrow/Jovian/Zenith identification accents also cluster in
##     cyan-teal (min CIEDE2000 6.40 under simulated protanopia), so only the
##     warm-gold Torrent accent separates at a glance. Body-tone separations
##     are printed as evidence rather than asserted, because no floor over
##     numbers this small would mean anything.
##
## Cockpit seating was the second recorded deficiency and is now fixed rather
## than recorded. Zenith used to place its cockpit camera 0.859 m BELOW the
## seated pilot's head bone and left that head bone only 0.061 m under its own
## hull crown, so the skull crossed the closed canopy. Its `PilotSeatAnchor`
## had been authored at seat-cushion height instead of the feet-frame height
## `PlayerController` expects. Both Zenith anchors were re-frozen at corrected
## values — see the re-freeze note in `tests/zenith_interceptor_test.gd` — and
## the eye-point and head-inside-hull assertions below now cover all four
## craft, so the defect cannot silently return.
=======
##   * Zenith places its cockpit camera 0.86 m BELOW the seated pilot's head
##     bone (the other three place it 0.20 m above), and the seated pilot's
##     head bone clears Zenith's outer hull by only 0.06 m against 0.56 m or
##     more elsewhere. Zenith's eye point is therefore not frozen as plausible.
>>>>>>> worktree-agent-a95094a8e503e2d38
##
## The colour deficiency this suite originally recorded has since been fixed and
## is now asserted rather than merely printed. The audited state was four craft
## sharing one near-white body tone (Torrent #e8e2cf, Arrow #e9eee9, Jovian
## #e7e4d6, Zenith #e6e2d5) whose closest pair measured CIEDE2000 0.82 in normal
## vision and 0.45 under simulated deuteranopia — below the just-noticeable
## difference — while the widest pair reached only 7.3; the Arrow/Jovian/Zenith
## accents additionally clustered in cyan-teal at 6.40 under protanopia. The
## floors below freeze the replacement palette.
##
## Why these floors. CIEDE2000 is scaled so that roughly 1.0 is a just-noticeable
## difference for two large patches held side by side, and ~2.3 is the value
## usually quoted as the practical JND. At-a-glance craft identification is a
## much harder task than side-by-side comparison: the two hulls are never
## adjacent, are seen at different distances and attitudes, under different
## lighting, and are matched against colour memory rather than against each
## other. On top of that the runtime multiplies each authored albedo tint by a
## bound hull map and then tonemaps it, which compresses authored differences
## further. BODY_TONE_FLOOR is therefore set at 12.0 — an order of magnitude
## above the patch JND — and the accent floor at 25.0. The body floor is capped
## by the evidence boundary rather than by taste: Torrent's warm off-white and
## Zenith's pale exterior are both source-observed claims (see
## docs/TORRENT_2011_RECONSTRUCTION_SPEC.md and
## docs/ZENITH_B7_RECONSTRUCTION_SPEC.md), so those two craft cannot be pulled
## apart in hue or value without contradicting a registered source observation.
## PALE_BODY_CRAFT freezes that boundary alongside the separation floors.
##
## Waiting. Every wait in this suite is bounded by a budget of simulated frames
## rather than by the wall clock, and every production input request is re-issued
## until the state machine accepts it. Nothing about what the suite proves
## changed; only how it waits. Measured at load average 14-17 on a 32-core box,
## the previous waits produced two hangs in five runs — 409 s runs killed by the
## harness where the bounded version finished in 11-13 s — because a single
## swallowed input edge left an unbounded `await player.disembarking_completed`
## with no signal to receive. See FRAME_BUDGET_GRACE and _tap_button_until.
##
## No handling value, colour, or geometry is modified anywhere in this suite.

const MAIN_SCENE := preload("res://scenes/main.tscn")
# One implementation of the sRGB -> Viénot dichromat -> CIE L*a*b* -> CIEDE2000
# chain, shared with the design probes that chose the palette below.
const ColourMetrics := preload("res://tests/fleet_colour_metrics.gd")

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
## Simulated seconds of walking each approach is allowed, converted below into a
## physics-frame budget. It is never used as a wall-clock deadline.
const WALK_BUDGET_SECONDS := 8.0

## Extra simulated physics frames granted on top of the frames a wait's nominal
## duration implies. This is a frame count, never a wall-clock grace: locomotion,
## boarding motion and every other physical result advance on the physics clock,
## and Godot drops physics steps under load rather than letting the simulation
## spiral, so only a frame budget measures the same amount of simulation on a
## busy box as on an idle one. Measured on this suite: a full matrix run under
## five concurrent agents took 175 s and timed out where the identical commit
## finished in 10.6 s in isolation, because the old wall-clock deadlines expired
## while the avatar still had metres to walk in simulated time.
const FRAME_BUDGET_GRACE := 30

## Simulated seconds allowed for one disembark request to be accepted, and how
## many times the same production input may be re-issued before the suite calls
## the request genuinely unaccepted. Both bounds are finite, so a state machine
## that never accepts the request still fails instead of hanging.
const DISEMBARK_REQUEST_BUDGET_SECONDS := 1.0
const DISEMBARK_REQUEST_ATTEMPTS := 8
const DISEMBARK_BUDGET_SECONDS := 3.0

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
# Torrent's warm gold and Arrow's cyan are unchanged; Jovian moved off teal to
# crimson and Zenith off pale cyan to deep blue so the four no longer cluster.
const EXPECTED_ACCENTS := {
	&"torrent_provisional": "f0b94d",
	&"arrow_provisional": "45dee6",
	&"jovian_provisional": "b32620",
	&"zenith_b7_observed": "2f5fbe",
}

# Each craft's body tone: the brightest rendered opaque albedo holding at least
# a tenth of the craft's visible surface area. This is the colour a player reads
# off the hull at a glance, as opposed to trim, machinery, or emissive detail.
const EXPECTED_BODY_TONE := {
	# Unchanged: B5/B6 record a high-value low-saturation off-white across every
	# silhouette-defining Torrent mass, so this warm ivory is evidence-bounded.
	&"torrent_provisional": "e8e2cf",
	&"arrow_provisional": "7891ab",
	&"jovian_provisional": "e0ab74",
	# B7 observes a pale exterior as a relative value only, so Zenith keeps a
	# pale light-grey read while moving off the shared warm ivory.
	&"zenith_b7_observed": "bac8d6",
}
const BODY_TONE_MINIMUM_SHARE := 0.10

# Craft whose body tone carries a source-observed "pale" claim and must stay
# pale whatever else the readability pass does to it.
const PALE_BODY_CRAFT := [&"torrent_provisional", &"zenith_b7_observed"]
const PALE_BODY_MINIMUM_LIGHTNESS := 78.0

# Frozen CIEDE2000 floors; see the "Why these floors" note in the header.
const BODY_TONE_FLOOR := 12.0
const ACCENT_FLOOR := 25.0
const TORRENT_ACCENT_FLOOR := 30.0
const VISION_MODELS := ColourMetrics.VISION_MODELS

# Every craft must now sit its cockpit camera at a plausible seated eye point
# and keep the seated pilot's head bone inside its own outer hull. Zenith joined
# this list once its seat/camera anchors were re-frozen; see the suite header.
const PLAUSIBLE_EYE_POINT_CRAFT := [
	&"torrent_provisional", &"arrow_provisional", &"jovian_provisional",
	&"zenith_b7_observed",
]
const EYE_ABOVE_HEAD_BONE_MINIMUM := 0.15
const EYE_ABOVE_HEAD_BONE_MAXIMUM := 0.35
# Stated minimum vertical gap between the seated pilot's head bone and the top
# of the craft's own rendered hull. Below this the skull is at or through the
# outer surface with the canopy shut. Measured today: Zenith 0.531 (the tightest
# cockpit in the fleet), Torrent 0.561, Arrow 1.401, Jovian 3.256.
const HEAD_HULL_CLEARANCE_MINIMUM := 0.5
# Exact fleet-wide seat-to-eye rise. `PilotSeatAnchor` is a feet-frame marker,
# so this is what makes the camera land 0.201 m above the head bone on every
# craft. Frozen exactly, not as a band: it is the convention Zenith broke.
const SEAT_TO_COCKPIT_CAMERA_RISE := 1.76

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
	_check(_distinct_value_count(hulls) == 4, "all four craft carry distinct body tones")

	# The two craft carrying a source-observed pale claim must still read pale.
	# This is the boundary that caps how far the palette may be pulled apart, so
	# it is frozen next to the separation floors rather than left to review.
	for ship_id: StringName in PALE_BODY_CRAFT:
		var pale_lightness := ColourMetrics.lightness(str(hulls[ship_id]))
		_check(
			pale_lightness >= PALE_BODY_MINIMUM_LIGHTNESS,
			"%s keeps the pale exterior its registered source observation records (L* %.2f)"
				% [ship_id, pale_lightness]
		)

	for mode: String in VISION_MODELS:
		var accent_minimum := _minimum_separation(accents, mode)
		_check(
			accent_minimum >= ACCENT_FLOOR,
			"accent separation under %s stays at or above its %.1f floor (%.2f)"
				% [mode, ACCENT_FLOOR, accent_minimum]
		)
		var body_minimum := _minimum_separation(hulls, mode)
		_check(
			body_minimum >= BODY_TONE_FLOOR,
			"body-tone separation under %s stays at or above its %.1f floor (%.2f)"
				% [mode, BODY_TONE_FLOOR, body_minimum]
		)
		_colour_evidence.append(
			"FLEET_COLOUR_EVIDENCE: under %s body_tone_min_ciede2000=%.2f accent_min_ciede2000=%.2f"
				% [mode, body_minimum, accent_minimum]
		)

	# The warm-gold Torrent accent carries the strongest separation of the four.
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
		var lightness := ColourMetrics.lightness(hex)
		if lightness > best_lightness:
			best_lightness = lightness
			best = hex
	return best


## CIEDE2000 between two sRGB hex colours, optionally through a Viénot 1999
## dichromat simulation, so separation is measured perceptually rather than by
## comparing hex digits. The maths lives in tests/fleet_colour_metrics.gd so
## that this audit and the palette design probes share one implementation.
func _separation(first_hex: String, second_hex: String, mode: String) -> float:
	return ColourMetrics.separation(first_hex, second_hex, mode)


# --------------------------------------------- boarding and seating ----

func _test_physical_boarding_and_cockpit_seating(
		game: GameFlow,
		player: PlayerController,
		by_id: Dictionary
	) -> void:
	game.canopy_motion_time = 0.0
	game.boarding_motion_time = 0.05
	game.disembarking_motion_time = 0.05
	var approach_ready := await _tap_button_until(
		BUTTON_X,
		func() -> bool:
			return game.phase == GameFlow.Phase.APPROACH_SHIP and player.is_control_enabled(),
		2.0,
		DISEMBARK_REQUEST_ATTEMPTS
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
		var walk: Dictionary = await _walk_to_candidate(player, craft, game)
		var grounded_ticks := int(walk["grounded_ticks"])
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
			int(walk["frames"]) < int(walk["frame_budget"]),
			"%s approach reaches its prompt inside its own physics-frame budget (%d of %d frames)"
				% [ship_id, int(walk["frames"]), int(walk["frame_budget"])]
		)
		_check(
			game.boarding_candidate == craft,
			"%s exposes its boarding prompt only after the physical approach" % ship_id
		)
		if game.boarding_candidate != craft:
			continue

		var boarded := await _tap_button_until(
			BUTTON_X,
			func() -> bool: return game.phase == GameFlow.Phase.START_ENGINES,
			3.0,
			DISEMBARK_REQUEST_ATTEMPTS
		)
		_check(boarded, "%s completes production boarding from the walked-up prompt" % ship_id)
		_check(
			player.is_seated() and craft.is_piloted() and game.get_active_ship() == craft,
			"%s seats the same visible player and takes piloting authority" % ship_id
		)
		if not boarded:
			continue

		_assert_cockpit_seating(craft, player, skeleton, head_bone, ship_id)

		# GameFlow drops an input edge outright while a transition is still busy
		# (`_transition_busy` in `_unhandled_input`), so a single one-frame tap can
		# be swallowed with no retry. The old code then awaited
		# `player.disembarking_completed` unbounded, and a swallowed tap meant that
		# signal never arrived and the suite hung until the harness killed it —
		# measured here as a 409 s `exit=124` where neighbouring runs finished in
		# 9 s. Re-issue the same production input until the state machine accepts
		# it, then wait for the real completion on a bounded frame budget.
		var disembark_completed := [false]
		var on_disembarked := func() -> void: disembark_completed[0] = true
		player.disembarking_completed.connect(on_disembarked, CONNECT_ONE_SHOT)
		var disembark_requested := await _tap_button_until(
			BUTTON_X,
			func() -> bool:
				return bool(disembark_completed[0]) \
					or game.phase == GameFlow.Phase.DISEMBARKING,
			DISEMBARK_REQUEST_BUDGET_SECONDS,
			DISEMBARK_REQUEST_ATTEMPTS
		)
		_check(
			disembark_requested,
			"%s accepts the production disembark request through the real input path" % ship_id
		)
		var disembarked := await _wait_until(
			func() -> bool: return bool(disembark_completed[0]),
			DISEMBARK_BUDGET_SECONDS
		)
		if player.disembarking_completed.is_connected(on_disembarked):
			player.disembarking_completed.disconnect(on_disembarked)
		_check(
			disembarked,
			"%s completes its physical disembark inside its physics-frame budget" % ship_id
		)
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
	_check(
		PLAUSIBLE_EYE_POINT_CRAFT.has(ship_id),
		"%s is covered by the seated eye-point and head-clearance gates" % ship_id
	)
	_check(
		eye_offset >= EYE_ABOVE_HEAD_BONE_MINIMUM and eye_offset <= EYE_ABOVE_HEAD_BONE_MAXIMUM,
		"%s places its cockpit camera at a seated eye point above the pilot's head bone (%.3f m)"
			% [ship_id, eye_offset]
	)
	# The specific defect this guards: a cockpit camera authored below the seated
	# pilot's head is a chest-height view, never an eye point.
	_check(
		eye_offset > 0.0,
		"%s cockpit camera is above the seated pilot's head bone, not at chest height (%.3f m)"
			% [ship_id, eye_offset]
	)
	_check(
		is_equal_approx(camera_local.y - seat_local.y, SEAT_TO_COCKPIT_CAMERA_RISE),
		"%s raises its cockpit camera exactly %.2f m above its feet-frame seat anchor (%.3f m)"
			% [ship_id, SEAT_TO_COCKPIT_CAMERA_RISE, camera_local.y - seat_local.y]
	)
	# The seated pilot's skull must not cross the outer hull with the canopy shut.
	_check(
		head_clearance >= HEAD_HULL_CLEARANCE_MINIMUM,
		"%s seats the pilot's head at least %.2f m inside its own outer hull (%.3f m clearance)"
			% [ship_id, HEAD_HULL_CLEARANCE_MINIMUM, head_clearance]
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

## Walks the production avatar to `craft` with real left-stick Input, bounded by
## the number of physics frames `WALK_BUDGET_SECONDS` of simulated walking
## implies rather than by the wall clock.
##
## Locomotion is integrated in `_physics_process`. On a loaded machine Godot
## drops physics steps to avoid a spiral of death while the wall clock keeps
## running, so a wall-clock budget ends the walk after far fewer simulated steps
## than the avatar needs to cover the staged distance and scores a perfectly
## healthy traversal as a failure. Counting frames gives the avatar the same
## amount of simulation however busy the box is, and still fails a genuinely
## blocked route because the budget remains finite.
##
## Returns the grounded physics ticks, the frames spent, and the budget, so the
## caller can assert on the budget instead of assuming it was never reached.
func _walk_to_candidate(player: PlayerController, craft: HeroShip, game: GameFlow) -> Dictionary:
	var frame_budget := _frame_budget(WALK_BUDGET_SECONDS)
	var frames := 0
	var grounded_ticks := 0
	_set_button(BUTTON_LEFT_STICK, true)
	while frames < frame_budget:
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
		frames += 1
		if player.is_on_floor():
			grounded_ticks += 1
		await process_frame
	_release_joypad()
	for _settle in 5:
		await physics_frame
		await process_frame
	return {
		"grounded_ticks": grounded_ticks,
		"frames": frames,
		"frame_budget": frame_budget,
	}


## Re-issues the same production button until `predicate` holds, bounded both by
## a per-attempt frame budget and by a fixed attempt count.
##
## Re-sending a dropped input does not weaken anything the suite proves: the
## transition must still be produced by the real production input path, and the
## attempt count stays finite so a request the game genuinely refuses still
## fails. It only stops a single swallowed edge from turning into an unbounded
## wait on a signal that will now never be emitted.
func _tap_button_until(
		index: int,
		predicate: Callable,
		budget_seconds: float,
		attempts: int
	) -> bool:
	for _attempt in attempts:
		if bool(predicate.call()):
			return true
		await _tap_button(index)
		if await _wait_until(predicate, budget_seconds):
			return true
	return bool(predicate.call())


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


## Physics frames a nominal duration of simulated time is worth at the project's
## configured tick rate, plus the fixed frame grace.
func _frame_budget(seconds: float) -> int:
	var required := int(ceil(maxf(seconds, 0.0) * float(Engine.physics_ticks_per_second)))
	return maxi(required, 1) + FRAME_BUDGET_GRACE


## Waits for `predicate` on the simulation clock. `budget_seconds` is a nominal
## amount of simulated time, converted to a frame budget for the same reason the
## walk is: GameFlow advances boarding, seating and control authority from its
## own frame callbacks, so a wall-clock deadline expires part-way through a
## perfectly healthy transition whenever the machine is busy. The budget stays
## finite, so a genuinely stuck transition still fails.
func _wait_until(predicate: Callable, budget_seconds: float) -> bool:
	var frame_budget := _frame_budget(budget_seconds)
	for _frame in frame_budget:
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
