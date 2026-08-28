extends SceneTree

## Freezes the fleet-wide properties that the Phase 4 "differentiated roles,
## readable colours, physical boarding, cockpit seating, interiors appropriate
## to vessel size" item actually delivers today, measured from the production
## Main scene rather than from source constants.
##
## This is an audit regression, not a tuning pass. Where a property does not
## hold across all five craft the suite freezes it only for the craft where it
## genuinely holds, and records the measured deficiency as a non-regression
## floor so a later player-led feel pass can only improve it. One deficiency is
## deliberately NOT asserted as passing and is documented instead:
##
## Cockpit seating was the second recorded deficiency and is now fixed rather
## than recorded. Zenith used to place its cockpit camera 0.859 m BELOW the
## seated pilot's head bone and left that head bone only 0.061 m under its own
## hull crown, so the skull crossed the closed canopy. Its `PilotSeatAnchor`
## had been authored at seat-cushion height instead of the feet-frame height
## `PlayerController` expects. Both Zenith anchors were re-frozen at corrected
## values — see the re-freeze note in `tests/zenith_interceptor_test.gd` — and
## the eye-point and head-inside-hull assertions below now cover all five
## craft, so the defect cannot silently return.
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
## Expanded to five craft. The Halyard Crew Transport joined the fleet and the
## suite was generalised rather than duplicated. Two assertions changed shape and
## both are recorded here because they read as weakenings and are not:
##
## `_test_interior_provision` used to say "the only craft with an interior is the
## only craft declared medium/light-freighter class" and "the interior-bearing
## craft is the physically largest hull". Both were true *descriptions* of a
## four-craft fleet rather than rules, and both stop being true the moment a
## second interior-bearing craft exists. The rule they were standing in for is
## the one docs/design/FLEET_VISUAL_GRAMMAR.md §4 states: interior provision is a
## consequence of envelope, and the declared tags must agree with both. That rule
## is now checked in both directions over *every* craft in the fleet — an
## interior-bearing craft must exceed the small-craft envelope and publish a real
## interior at its own frozen scale, and any craft without one must stay inside
## the small-craft envelope — which is strictly more coverage than one named
## craft received before. Every number the Jovian was previously held to is
## carried forward unchanged in INTERIOR_CRAFT.
##
## The colour and handling floors are untouched, and the new craft was required
## to clear the fleet's *measured minima* rather than the frozen floors, so the
## separation reported by this suite does not fall because it was added.
##
## No handling value, colour, or geometry is modified anywhere in this suite.

const MAIN_SCENE := preload("res://scenes/main.tscn")
const Settings := preload("res://scripts/settings/runtime_settings.gd")
const Store := preload("res://scripts/persistence/user_data_store.gd")
const Adapter := preload("res://scripts/settings/runtime_settings_store_adapter.gd")
const EXPANDED_DEFINITIONS := {
	&"cinder_cargo_hauler": preload("res://assets/ships/cinder_cargo_hauler_new_design.tres"),
	&"cinder_long_range_bomber": preload("res://assets/ships/cinder_long_range_bomber_new_design.tres"),
	&"cinder_light_interceptor": preload("res://assets/ships/cinder_light_interceptor_new_design.tres"),
}
# One implementation of the sRGB -> Viénot dichromat -> CIE L*a*b* -> CIEDE2000
# chain, shared with the design probes that chose the palette below.
const ColourMetrics := preload("res://tests/fleet_colour_metrics.gd")

# Staging is a single placement outside the production 7.0 m boarding fallback
# reach. Every metre after that is real joypad locomotion through the live
# PlayerController; the suite proves no candidate exists before the walk.
const APPROACH_OFFSETS := {
	&"torrent_provisional": Vector3(0.0, 0.0, 12.0),
	# PORT-LANE. Restaged from a straight 12 m stage, which walked the centre of
	# the port branch arm — 7.0 m wide, z 12.0-19.0, and the sole route to this
	# berth — straight into PortBranchCargoLine's gantry posts once the cargo pass
	# gave its solid parts real collision. A capsule sweep of the whole arm found
	# z 12.5-14.5 unobstructed across every x from -34 to -11, so the route exists
	# and a player walks round the line; only the straight-line stage did not.
	# The lateral 4.0 m puts the stage in that clear lane. The line, its collision
	# and its placement are all unchanged — this is the approach a player takes.
	&"arrow_provisional": Vector3(4.0, 0.0, 12.0),
	# Restaged from a straight 12 m aft stage, which put the avatar at ship-local
	# (-3.4, -0.47, 3.85) — *inside the cargo hold*, standing on the ship's own
	# cargo deck under its roof, and walked it in a straight unpathfound line
	# through where the port crates stand.
	#
	# That only worked because the freight had no collision, and the freight has
	# collision now: secured cargo you can walk through is the same defect class as
	# every other solid-looking-but-empty volume the station sweep closed, and a
	# crew member can walk this hold since in-flight cabin access landed. Making
	# the crates solid jams the old approach against `CargoContainerCollisionPort00`
	# 2.0 m out, which is exactly what an earlier pass measured before reverting the
	# crates and recording this for an owner.
	#
	# The suite's subject is role differentiation and boarding through the
	# *exterior* pilot hatch, so the approach belongs on the apron the player
	# actually walks, not inside the hull. This lands at ship-local
	# (-12.0, -0.47, -16.15) — 1.4 m outboard of the port hull line and clear of
	# the bow, on `ApronDeck04`, 11.75 m from the hatch, with a straight capsule
	# sweep to it that touches nothing. Measured against the live world: of 1681
	# sampled apron points 7.5-15.0 m from the hatch, 286 are standable and 82 have
	# a clear straight walk; this is one of them, chosen for staying near the 12 m
	# the two fighters use so the suite's own distance and walk assertions keep
	# their existing margins.
	&"jovian_provisional": Vector3(-8.6, 0.0, -8.0),
	# Fleet Dock 01 is an elevated 12 x 15 m slab; a longer aft stage walks off
	# its edge, so Zenith is staged diagonally at 8.06 m instead.
	&"zenith_b7_observed": Vector3(-4.0, 0.0, 7.0),
	# HALYARD-DECK-001. Re-derived, because the premise of the old 9.6 m stage no
	# longer holds. It read: "Fleet Dock 02 is a 12 x 12 m slab and the Halyard is
	# 26.9 m long, so its bow and tail overhang the deck and only the strip
	# alongside the midships hull is walkable." That overhang was the defect, not
	# the design — 16.35 m of a 28.35 m craft stood over open space. The dock now
	# carries a berth apron and the pad runs z = 36.3 … 70.7 under it.
	#
	# So this stages the approach a player actually makes: standing on the comb
	# trunk at the aft end of the dock, walking straight forward down the port
	# lane toward the airstair. 21.5 m out, which is 0.7 m inside the trunk's far
	# edge, and pure aft so the whole walk is down the 12 m wide pad. The prompt
	# is acquired 2.37 m in, where the craft-shaped approach volume begins.
	&"halyard_new_design": Vector3(0.0, 0.0, 21.5),
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

# Exact identification accents as authored across the five production craft.
# Torrent's warm gold and Arrow's cyan are unchanged; Jovian moved off teal to
# crimson and Zenith off pale cyan to deep blue so the original four no longer
# cluster. Halyard's fifth accent is frozen alongside them below.
const EXPECTED_ACCENTS := {
	&"torrent_provisional": "f0b94d",
	&"arrow_provisional": "45dee6",
	&"jovian_provisional": "b32620",
	&"zenith_b7_observed": "2f5fbe",
	# The Halyard's deep aubergine. It is dark because the chromatic accent space
	# is exhausted: a full sRGB sweep against the four accents above, under all
	# four vision models, found that every colour clearing both floors is either a
	# near-neutral grey barely over the 25.0 line or a dark violet. This value is
	# the lightest that clears today's fleet minimum of 31.38 outright, so adding
	# it costs the fleet no accent headroom at all. See the palette note in
	# scripts/ships/halyard_crew_transport.gd.
	&"halyard_new_design": "341024",
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
	# Utility olive. Green is the one hue region the fleet did not occupy, and at
	# L* 49.0 it still reads against near-black space. Measured 19.06 against its
	# nearest neighbour (Jovian under protanopia), which is above the fleet's own
	# 16.62 body-tone minimum, so this craft is not the reason any later audit
	# reports a narrower margin than it used to.
	&"halyard_new_design": "6e7a3e",
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
	&"zenith_b7_observed", &"halyard_new_design",
]
const EYE_ABOVE_HEAD_BONE_MINIMUM := 0.15
const EYE_ABOVE_HEAD_BONE_MAXIMUM := 0.35
# Stated minimum vertical gap between the seated pilot's head bone and the top
# of the craft's own rendered hull. Below this the skull is at or through the
# outer surface with the canopy shut. Measured today: Zenith 0.531 (the tightest
# cockpit in the fleet), Torrent 0.561, Arrow 1.401, Halyard 3.010, Jovian 3.256.
const HEAD_HULL_CLEARANCE_MINIMUM := 0.5
# Exact fleet-wide seat-to-eye rise. `PilotSeatAnchor` is a feet-frame marker,
# so this is what makes the camera land 0.201 m above the head bone on every
# craft. Frozen exactly, not as a band: it is the convention Zenith broke.
const SEAT_TO_COCKPIT_CAMERA_RISE := 1.76

const FLEET_SIZE := 5
const PRODUCTION_FLEET_SIZE := 9
const FIGHTER_IDS := [&"torrent_provisional", &"arrow_provisional", &"zenith_b7_observed"]
## Craft that publish a connected walkable interior, with the per-craft floors
## their own hulls have to keep. The suite used to assert that exactly one craft
## had an interior and that it was the physically largest hull; both were true
## statements about a four-craft fleet, not rules. The rule underneath them is
## the one §4 of docs/design/FLEET_VISUAL_GRAMMAR.md actually states — interior
## provision is a consequence of envelope, and the declared tags must agree with
## both — and it is now checked in both directions over every craft rather than
## on one named craft. Nothing about the Jovian's own floors was relaxed: its
## exact x > 15 / z > 25 envelope and 4-seat complement are still frozen below.
const INTERIOR_CRAFT := {
	&"jovian_provisional": {
		"role_tag": "light_freighter",
		"minimum_envelope_x": 15.0,
		"minimum_envelope_z": 25.0,
		"minimum_interior_size": Vector3(11.0, 4.0, 17.0),
		"minimum_seats": 4,
	},
	&"halyard_new_design": {
		"role_tag": "crew_transport",
		# A long narrow pressure tube rather than a slab: it clears the
		# small-craft band on length, not on span.
		"minimum_envelope_x": 8.0,
		"minimum_envelope_z": 25.0,
		"minimum_interior_size": Vector3(5.0, 3.0, 20.0),
		"minimum_seats": 6,
	},
}
## Any craft with an interior must exceed the small-craft envelope on at least
## one horizontal axis, and any craft that does must publish an interior.
const SMALL_CRAFT_ENVELOPE_MAXIMUM := 15.0
## A walkable volume rather than a token cavity, whatever its shape.
const INTERIOR_MINIMUM_VOLUME := 300.0
const INTERIOR_NODE_NAMES := [
	"WalkableInterior", "CargoBay", "PassengerCabin", "InteriorOccupantVolume",
]


class IsolatedFilesystem extends UserDataFilesystem:
	var files: Dictionary = {}

	func file_exists(path: String) -> bool:
		return files.has(path)

	func directory_exists(_path: String) -> bool:
		return false

	func ensure_parent_directory(_path: String) -> Error:
		return OK

	func read_bytes(path: String, maximum_bytes: int) -> Dictionary:
		if not files.has(path):
			return {"error": ERR_FILE_NOT_FOUND, "bytes": PackedByteArray()}
		var bytes := (files[path] as PackedByteArray).duplicate()
		return {
			"error": OK if bytes.size() <= maximum_bytes else ERR_FILE_CORRUPT,
			"bytes": bytes,
		}

	func write_bytes_and_flush(path: String, bytes: PackedByteArray) -> Error:
		files[path] = bytes.duplicate()
		return OK

	func remove_path(path: String) -> Error:
		if not files.has(path):
			return ERR_FILE_NOT_FOUND
		files.erase(path)
		return OK

	func rename_path(from_path: String, to_path: String) -> Error:
		if not files.has(from_path):
			return ERR_FILE_NOT_FOUND
		if files.has(to_path):
			return ERR_ALREADY_EXISTS
		files[to_path] = (files[from_path] as PackedByteArray).duplicate()
		files.erase(from_path)
		return OK

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
	var filesystem := IsolatedFilesystem.new()
	var store := Store.new("memory://fleet-role-audit.json", filesystem)
	var settings := Settings.new("memory://fleet-role-audit.cfg")
	store.load()
	store.commit({Adapter.SETTINGS_PAYLOAD_KEY: settings.to_user_data_payload()}, 0, "fixture")
	game.configure_runtime_settings_persistence(store, "memory://fleet-role-audit.cfg")
	root.add_child(game)
	await process_frame
	await process_frame
	for _settle in 6:
		await physics_frame
		await process_frame

	var player := game.get_node_or_null("Player") as PlayerController
	var fleet: Array[HeroShip] = game.get_flyable_ships()
	_check(
		player != null and fleet.size() == PRODUCTION_FLEET_SIZE,
		"the audit resolves the live player and all %d production flyables" % PRODUCTION_FLEET_SIZE
	)
	if player == null or fleet.size() != PRODUCTION_FLEET_SIZE:
		await _clean_up(game)
		_finish()
		return

	var by_id := {}
	for craft in fleet:
		by_id[craft.get_ship_id()] = craft
	_check(
		by_id.size() == PRODUCTION_FLEET_SIZE,
		"the %d flyables carry %d distinct stable ship identities" % [PRODUCTION_FLEET_SIZE, PRODUCTION_FLEET_SIZE]
	)

	_test_role_differentiation(by_id)
	var original_fleet := {}
	for original_id: StringName in [
		&"torrent_provisional", &"arrow_provisional", &"jovian_provisional",
		&"zenith_b7_observed", &"halyard_new_design",
	]:
		if by_id.has(original_id):
			original_fleet[original_id] = by_id[original_id]
	_test_readable_colours(original_fleet)
	await _test_physical_boarding_and_cockpit_seating(game, player, original_fleet)
	_test_interior_provision(original_fleet)

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
		if definition == null and EXPANDED_DEFINITIONS.has(ship_id):
			definition = EXPANDED_DEFINITIONS[ship_id] as ShipDefinition
		_check(definition != null, "%s carries a ShipDefinition in the production scene" % ship_id)
		if definition == null:
			return
		var merged := definition.get_flight_profile().duplicate()
		merged.merge(definition.get_systems_profile())
		profiles[ship_id] = merged
		if not roles.has(definition.get_role()):
			roles.append(definition.get_role())
	_check(
		roles.size() == PRODUCTION_FLEET_SIZE,
		"the %d craft declare %d distinct role names" % [PRODUCTION_FLEET_SIZE, PRODUCTION_FLEET_SIZE]
	)

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
		_is_sole_extreme(profiles, &"jovian_provisional", "maximum_speed", false)
		and _is_sole_extreme(profiles, &"bulwark_heavy_gunship", "maximum_hull", true),
		"the Jovian freighter alone owns the lowest top speed while Bulwark owns the highest hull"
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
	# The crew transport is the fleet's long-haul cruiser: fastest sustained top
	# speed, and the price is paid on every axis that gets it there or stops it.
	# Its boost is the weakest in the fleet, so a fighter still out-sprints it.
	_check(
		_is_sole_extreme(profiles, &"halyard_new_design", "maximum_speed", true)
		and _is_sole_extreme(profiles, &"halyard_new_design", "thrust_acceleration", false)
		and _is_sole_extreme(profiles, &"halyard_new_design", "brake_acceleration", false)
		and _is_sole_extreme(profiles, &"halyard_new_design", "boost_multiplier", false)
		and _is_sole_extreme(profiles, &"halyard_new_design", "landing_maximum_speed", false)
		and _is_sole_extreme(profiles, &"halyard_new_design", "engine_start_time", true)
		and _is_sole_extreme(profiles, &"halyard_new_design", "weapon_cooldown", true),
		"the crew transport alone owns the highest top speed while owning the worst acceleration, braking, boost, landing gate, spool and cadence"
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
	_check(
		_distinct_value_count(accents) == FLEET_SIZE,
		"all %d craft carry distinct identification accents" % FLEET_SIZE
	)
	_check(
		_distinct_value_count(hulls) == FLEET_SIZE,
		"all %d craft carry distinct body tones" % FLEET_SIZE
	)

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
	# Direction 1: every craft declared as interior-bearing publishes a real,
	# connected, walkable interior at its own frozen scale.
	for ship_id: StringName in INTERIOR_CRAFT:
		var spec: Dictionary = INTERIOR_CRAFT[ship_id]
		var craft := by_id.get(ship_id) as HeroShip
		_check(craft != null, "%s is present in the production fleet" % ship_id)
		if craft == null:
			continue
		_check(
			craft.has_method("get_walkable_interior_report"),
			"%s publishes a walkable interior report" % ship_id
		)
		var report: Dictionary = craft.call("get_walkable_interior_report")
		_check(
			(report.get("root", null) as Node3D) != null
			and not bool(report.get("detached_interior", true)),
			"%s interior is a connected part of the ship frame, not a detached set" % ship_id
		)
		_check(
			int(report.get("passenger_seat_count", 0)) >= int(spec["minimum_seats"]),
			"%s interior carries the complement its role implies (%d of %d seats)"
				% [ship_id, int(report.get("passenger_seat_count", 0)), int(spec["minimum_seats"])]
		)
		_check(
			(report.get("access_marker", null) as Node3D) != null
			and (report.get("deck_marker", null) as Node3D) != null,
			"%s interior publishes both its exterior access and interior deck markers" % ship_id
		)
		var bounds: AABB = craft.call("get_interior_bounds")
		var minimum_size: Vector3 = spec["minimum_interior_size"]
		var volume := bounds.size.x * bounds.size.y * bounds.size.z
		_check(
			bounds.size.x > minimum_size.x
			and bounds.size.y > minimum_size.y
			and bounds.size.z > minimum_size.z
			and volume >= INTERIOR_MINIMUM_VOLUME,
			"%s interior is a walkable volume rather than a token cavity %s (%.0f m3)"
				% [ship_id, str(bounds.size), volume]
		)
		var tags := craft.get_ship_definition().get_compatibility_tags()
		_check(
			tags.has("medium_craft") and tags.has(str(spec["role_tag"])) and not tags.has("small_craft"),
			"%s declares the medium-craft and %s class its interior implies"
				% [ship_id, str(spec["role_tag"])]
		)
		var envelope := _collision_envelope(craft)
		_check(
			envelope.size.x > float(spec["minimum_envelope_x"])
			and envelope.size.z > float(spec["minimum_envelope_z"]),
			"%s keeps the hull scale its interior claims %s" % [ship_id, str(envelope.size)]
		)
		# The rule underneath the per-craft floors: a craft may not be small and
		# carry an interior.
		_check(
			maxf(envelope.size.x, envelope.size.z) > SMALL_CRAFT_ENVELOPE_MAXIMUM,
			"%s exceeds the small-craft envelope on at least one horizontal axis %s"
				% [ship_id, str(envelope.size)]
		)
		_check(
			craft.supports_in_flight_cabin_access(),
			"%s offers the in-flight cabin its connected interior makes possible" % ship_id
		)

	# Direction 2: and no craft may be large and publish no interior. Every craft
	# outside the interior roster has to stay inside the small-craft band, which
	# is what stops a large empty hull being shipped as a scale claim the
	# gameplay does not honour.
	for ship_id: StringName in by_id:
		if INTERIOR_CRAFT.has(ship_id):
			continue
		var envelope := _collision_envelope(by_id[ship_id] as HeroShip)
		_check(
			maxf(envelope.size.x, envelope.size.z) <= SMALL_CRAFT_ENVELOPE_MAXIMUM,
			"%s publishes no interior, so it stays inside the small-craft envelope %s"
				% [ship_id, str(envelope.size)]
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
	for action in [&"interact", &"move_forward", &"fire", &"landing_assist"]:
		Input.action_release(action)
	await _release_combat_audio_before_main_teardown(game)
	var world := game.get_node_or_null(^"ShipyardWorld") as ShipyardWorld
	var expansion := world.get_fleet_expansion_production_binding() if world != null else null
	if expansion != null:
		for craft_id: StringName in [
			&"cinder_cargo_hauler",
			&"cinder_long_range_bomber",
			&"cinder_light_interceptor",
		]:
			expansion.detach_craft(craft_id)
	await process_frame
	if is_instance_valid(game):
		game.free()
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
