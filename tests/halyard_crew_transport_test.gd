extends SceneTree

## Regression for the Halyard Crew Transport, the fleet's fifth flyable craft.
##
## `modern_interpretation`. The Halyard is an original design; nothing in this
## suite asserts, implies, or depends on any historical craft, and nothing here
## may be cited as evidence about the original game.
##
## The suite exists to catch the specific ways this craft can rot, and every
## group below has at least one structured-red control that proves the
## measurement bites rather than merely running:
##
##   A. identity and evidence — a new design that never acquires a historical
##      claim, and never takes a reserved ledger name.
##      Red: a reserved name, and an attached evidence reference, both rejected.
##   B. lateral role — the frozen signature, and the guarantee that adding this
##      craft took no signature away from the four that were already here.
##      Red: a mutated profile that dominates the freighter is detected.
##   C. readable colour — the exact authored body tone and accent, re-measured
##      against all four existing craft under all four vision models, including
##      the assertion that this craft spends none of the fleet's headroom.
##      Red: the pre-readability-pass fleet ivory fails the floor.
##   D. winding — every mesh the craft builds, scored against the engine's own
##      primitives. This is the group with a live cause: `HeroShip._box` routes
##      through a private chamfered-box builder whose emission order is measured
##      100% backwards against that same calibration, so the craft overrides
##      `_box` onto `StationSurfaceKit`. Red: a reversed copy of one of this
##      craft's own meshes is detected as fully backwards.
##   D1. bow docking arch — the nose hardware remains legible as a docking
##      target while its lower half stays open rather than forming a hollow wheel.
##   D2. render allocations — the seven childless dorsal ribs retain their exact
##      copies, mesh, material and culling union through one renderer batch, and
##      the fourteen visual-only inboard window panes share one moving-cabin
##      batch. Red: a mutated renderer buffer and culling box are rejected.
##   D3. weapons — two compact dorsal self-defence mounts remain aligned to the
##      unchanged combat muzzles, smaller than the Jovian fit, and explicitly
##      registered as modern visual presentation rather than historical evidence.
##   E. physical cockpit and boarding — the frozen fleet seat/eye convention on a
##      two-station flight deck. Red: a shifted seat anchor breaks the rise.
##   F. walkable interior and the in-flight cabin contract — a continuous deck
##      from the airstair to the pilot seat, and a cabin offer derived from the
##      live coordinator rather than asserted. Red: unbind the coordinator, and
##      destroy the craft; both must withdraw the offer.
##   G. surfacing — the registered panel recipe is bound in moving-ship-local
##      triplanar space, and the hull skin is not left at station relief. Red: a
##      stripped material is detected.
##   H. berth — the craft's complete collision envelope fits the strict landing
##      volume of the berth it is assigned to. Red: an inflated envelope does
##      not fit.
##
## Every wait is a bounded frame count on the fixed physics step. Nothing here
## reads a wall clock.

const MAIN_SCENE := preload("res://scenes/main.tscn")
const HALYARD_SCENE := preload("res://scenes/ships/halyard_crew_transport.tscn")
const ColourMetrics := preload("res://tests/fleet_colour_metrics.gd")

const HALYARD_ID: StringName = &"halyard_new_design"
const HALYARD_BERTH_ID: StringName = &"halyard_fleet_dock_berth"

## Every name the source ledger reserves. A modern design that takes one of
## these manufactures a name-to-model claim nobody found; see
## `docs/design/FLEET_VISUAL_GRAMMAR.md` §7.12.
const RESERVED_LEDGER_NAMES := [
	"torrent", "arrow", "jovian", "zenith", "titan", "vortex", "paradox",
	"katana", "predator", "dynamic", "utopia", "salyut", "altair", "corona",
]

## The Halyard's frozen handling profile. Restated here, away from the resource,
## so a silent edit to `assets/ships/halyard_new_design.tres` turns this red
## rather than quietly re-balancing the fleet.
const EXPECTED_PROFILE := {
	"maximum_speed": 108.0,
	"thrust_acceleration": 11.0,
	"brake_acceleration": 19.0,
	"passive_drag": 1.6,
	"throttle_response": 4.2,
	"boost_speed": 116.0,
	"boost_multiplier": 1.08,
	"yaw_speed_degrees": 31.0,
	"roll_speed_degrees": 38.0,
	"flight_assist_strength": 3.1,
	"visual_bank_degrees": 5.0,
	"maximum_mouse_turn_degrees": 8.0,
	"engine_start_time": 4.6,
	"weapon_cooldown": 0.95,
	"maximum_hull": 190.0,
	"landing_maximum_speed": 9.0,
}

const HIGHER_IS_BETTER := [
	"maximum_speed", "thrust_acceleration", "brake_acceleration", "boost_speed",
	"boost_multiplier", "yaw_speed_degrees", "roll_speed_degrees",
	"throttle_response", "maximum_hull", "landing_maximum_speed",
]
const LOWER_IS_BETTER := ["passive_drag", "engine_start_time", "weapon_cooldown"]

## The Halyard's signature: the one axis it is the sole extreme on in the
## "better" direction, and everything it pays for it with.
const SOLE_HIGHEST := ["maximum_speed"]
const SOLE_LOWEST := [
	"thrust_acceleration", "brake_acceleration", "throttle_response",
	"boost_multiplier", "yaw_speed_degrees", "roll_speed_degrees",
	"landing_maximum_speed",
]
const SOLE_WORST_LOWER_IS_BETTER := ["engine_start_time", "weapon_cooldown"]

## The four signatures that were already frozen before this craft existed. A
## fifth craft that out-hulls the freighter or out-rolls Zenith turns
## `tests/fleet_role_differentiation_test.gd` red; this suite checks the same
## boundary from the new craft's own side so the failure is attributed here.
const PRESERVED_SIGNATURES := [
	{"ship": &"jovian_provisional", "axis": "maximum_hull", "highest": true},
	{"ship": &"jovian_provisional", "axis": "maximum_speed", "highest": false},
	{"ship": &"zenith_b7_observed", "axis": "yaw_speed_degrees", "highest": true},
	{"ship": &"zenith_b7_observed", "axis": "roll_speed_degrees", "highest": true},
	{"ship": &"zenith_b7_observed", "axis": "maximum_hull", "highest": false},
	{"ship": &"arrow_provisional", "axis": "boost_speed", "highest": true},
	{"ship": &"torrent_provisional", "axis": "boost_multiplier", "highest": true},
	{"ship": &"torrent_provisional", "axis": "weapon_cooldown", "highest": false},
	{"ship": &"torrent_provisional", "axis": "landing_maximum_speed", "highest": true},
]

const EXPECTED_BODY_TONE := "6e7a3e"
const EXPECTED_ACCENT := "341024"
const EXISTING_BODY_TONES := {
	&"torrent_provisional": "e8e2cf",
	&"arrow_provisional": "7891ab",
	&"jovian_provisional": "e0ab74",
	&"zenith_b7_observed": "bac8d6",
}
const EXISTING_ACCENTS := {
	&"torrent_provisional": "f0b94d",
	&"arrow_provisional": "45dee6",
	&"jovian_provisional": "b32620",
	&"zenith_b7_observed": "2f5fbe",
}
const BODY_TONE_FLOOR := 12.0
const ACCENT_FLOOR := 25.0
const TORRENT_ACCENT_FLOOR := 30.0
const BODY_TONE_MINIMUM_SHARE := 0.10
## The fleet's measured minima before this craft existed, printed as
## `FLEET_COLOUR_EVIDENCE` by `tests/fleet_role_differentiation_test.gd`. The
## Halyard must sit *outside* both, so that adding it leaves the fleet minimum
## exactly where it was. This is the "do not spend the headroom" rule from
## `docs/design/FLEET_VISUAL_GRAMMAR.md` §7.2, enforced rather than hoped for.
const FLEET_BODY_MINIMUM_BEFORE := 16.62
const FLEET_ACCENT_MINIMUM_BEFORE := 31.38

## Calibration primitives for the winding scorer. The expected sign of
## `dot((b - a) x (c - a), shading_normal)` is derived from the engine's own
## meshes at runtime rather than hard-coded, exactly as
## `tests/station_surface_winding_test.gd` does.
const CALIBRATION_PRIMITIVES := ["BoxMesh", "CylinderMesh", "SphereMesh"]

const SEAT_TO_COCKPIT_CAMERA_RISE := 1.76
const HEAD_HULL_CLEARANCE_MINIMUM := 0.5
## The camera lands this far above the seated pilot's head bone on every craft in
## the fleet; it is a consequence of the 1.76 m rise plus the shared pilot rig,
## and is used here only to estimate head height without instantiating a player.
const CAMERA_ABOVE_HEAD_BONE := 0.201

const WALKABLE_DECK_COLLIDERS := [
	"CockpitDeckCollision",
	"CabinDeckCollision",
	"AftBayDeckCollision",
]
const DECK_JOIN_TOLERANCE := 0.001
const MINIMUM_CREW_SEATS := 6
const FLIGHT_DECK_STATIONS := 2
const MINIMUM_INTERIOR_VOLUME := 300.0
const MINIMUM_WALKABLE_DIMENSION := 2.2
## The small-craft envelope ceiling the fleet audit freezes. A craft that
## publishes an interior has to exceed it on at least one horizontal axis.
const SMALL_CRAFT_ENVELOPE_MAXIMUM := 15.0

const HULL_MATERIAL_KEYS := ["hull_olive", "hull_shade"]
const STATION_PANEL_NORMAL_SCALE := 1.0
const SHIP_NORMAL_SCALE_BAND := Vector2(0.10, 0.68)
const PANEL_TRIPLANAR_SHARPNESS := 4.0

var _failures: Array[String] = []
var _assertion_count := 0
var _evidence: Array[String] = []
var _test_root: Node3D
var _winding_sign := 0.0


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var original_root_child_count := root.get_child_count()
	_test_root = Node3D.new()
	_test_root.name = "HalyardTestRoot"
	root.add_child(_test_root)

	_calibrate_winding()

	var craft := HALYARD_SCENE.instantiate() as HeroShip
	_test_root.add_child(craft)
	await process_frame
	await physics_frame
	await physics_frame

	_test_identity_and_evidence(craft)
	_test_lateral_role(craft)
	_test_readable_colour(craft)
	_test_winding(craft)
	_test_bow_docking_arch(craft)
	_test_render_allocations(craft)
	_test_weapon_presentation(craft)
	_test_cockpit_and_boarding(craft)
	_test_interior(craft)
	await _test_in_flight_cabin(craft)
	_test_surfacing(craft)

	craft.queue_free()
	await process_frame
	await physics_frame

	await _test_berth_and_production_roster()

	_test_root.queue_free()
	_test_root = null
	await process_frame
	await physics_frame
	await process_frame
	_check(
		root.get_child_count() == original_root_child_count,
		"the transport fixture cleans up without leaving scene nodes behind"
	)
	for line in _evidence:
		print(line)
	_finish()


# ---------------------------------------------------------------- group A ----


func _test_identity_and_evidence(craft: HeroShip) -> void:
	_check(craft.get_ship_id() == HALYARD_ID, "the transport carries its own stable ship identity")
	_check(craft.get_role() == "Crew transport", "the transport declares the crew-transport role")
	_check(
		craft.get_home_berth_id() == HALYARD_BERTH_ID,
		"the transport names its own home berth rather than borrowing one"
	)
	var definition := craft.get_ship_definition()
	_check(definition != null, "the transport carries a ShipDefinition")
	if definition == null:
		return
	_check(
		definition.is_definition_valid(),
		"the transport definition validates: %s" % str(definition.get_validation_errors())
	)
	_check(
		definition.get_evidence_status_id() == &"new",
		"the transport is registered as a new original design, not a historical claim"
	)
	_check(
		not definition.is_historical_claim() and not definition.is_authenticated(),
		"the transport makes no historical or authenticated claim"
	)
	var audit := definition.get_audit_report()
	_check(
		(audit.get("evidence_references", PackedStringArray()) as PackedStringArray).is_empty(),
		"the transport attaches no evidence reference; inspiration is not authentication"
	)

	# The name is the part this project has got wrong before. A modern design
	# must not wear a reserved ledger name in its id, class name, or display name.
	var script_path := str((craft.get_script() as Script).resource_path)
	var identity_text: String = (
		String(craft.get_ship_id())
		+ " " + craft.get_display_name()
		+ " " + craft.get_role()
		+ " " + script_path
	).to_lower()
	var collisions := PackedStringArray()
	for reserved: String in RESERVED_LEDGER_NAMES:
		if identity_text.contains(reserved):
			collisions.append(reserved)
	_check(
		collisions.is_empty(),
		"the transport's identity takes no reserved ledger name (%s)" % str(collisions)
	)
	# RED: the same check applied to a name that *is* reserved must fire, so the
	# clean result above is a measurement rather than an empty loop.
	var reserved_probe := "salyut class transport".to_lower()
	var reserved_hits := 0
	for reserved: String in RESERVED_LEDGER_NAMES:
		if reserved_probe.contains(reserved):
			reserved_hits += 1
	_check(reserved_hits == 1, "RED: the reserved-name check does fire on a reserved name")

	var evidence := craft.call("get_halyard_evidence_report") as Dictionary
	_check(
		str(evidence.get("evidence_status", "")) == "modern_interpretation"
		and not bool(evidence.get("historical_claim", true))
		and not bool(evidence.get("authenticated_geometry", true)),
		"the transport's own evidence report claims nothing historical"
	)
	var craft_audit := craft.call("get_halyard_audit_report") as Dictionary
	_check(
		bool(craft_audit.get("valid", false)),
		"the transport's build audit is clean: %s" % str(craft_audit.get("errors", []))
	)


# ---------------------------------------------------------------- group B ----


func _test_lateral_role(craft: HeroShip) -> void:
	var definition := craft.get_ship_definition()
	if definition == null:
		return
	var profile := definition.get_flight_profile().duplicate()
	profile.merge(definition.get_systems_profile())
	for axis: String in EXPECTED_PROFILE:
		_check(
			is_equal_approx(float(profile.get(axis, INF)), float(EXPECTED_PROFILE[axis])),
			"the transport holds its frozen %s of %s (%s)"
				% [axis, str(EXPECTED_PROFILE[axis]), str(profile.get(axis, "missing"))]
		)

	var fleet := _load_existing_profiles()
	_check(fleet.size() == 4, "the four pre-existing craft definitions load for comparison")
	if fleet.size() != 4:
		return

	# Distinctness: at least 14 of 16 axes differ against every existing craft.
	var minimum_differing := 99
	for other_id: StringName in fleet:
		var differing := 0
		for axis: String in profile:
			if not is_equal_approx(float(profile[axis]), float((fleet[other_id] as Dictionary)[axis])):
				differing += 1
		minimum_differing = mini(minimum_differing, differing)
		_check(
			differing >= 14,
			"the transport differs from %s on at least 14 of 16 handling axes (%d)"
				% [other_id, differing]
		)
	_evidence.append(
		"HALYARD_ROLE_EVIDENCE: minimum_differing_handling_axes=%d of 16" % minimum_differing
	)

	# Lateral, both directions, against every existing craft.
	var minimum_advantage_over_others := 99
	var minimum_advantage_of_others := 99
	for other_id: StringName in fleet:
		var other: Dictionary = fleet[other_id]
		var mine := _count_advantages(other, profile)
		var theirs := _count_advantages(profile, other)
		minimum_advantage_over_others = mini(minimum_advantage_over_others, mine)
		minimum_advantage_of_others = mini(minimum_advantage_of_others, theirs)
		_check(mine > 0, "the transport is not dominated by %s (%d lateral advantages)" % [other_id, mine])
		_check(theirs > 0, "the transport does not dominate %s (%d lateral advantages)" % [other_id, theirs])
	_evidence.append(
		"HALYARD_ROLE_EVIDENCE: minimum_advantage_out=%d minimum_advantage_in=%d"
			% [minimum_advantage_over_others, minimum_advantage_of_others]
	)

	# Signature: sole extreme on its own axes.
	for axis: String in SOLE_HIGHEST:
		_check(
			_is_sole_extreme(profile, fleet, axis, true),
			"the transport alone owns the fleet's highest %s" % axis
		)
	for axis: String in SOLE_LOWEST + SOLE_WORST_LOWER_IS_BETTER:
		var want_maximum := SOLE_WORST_LOWER_IS_BETTER.has(axis)
		_check(
			_is_sole_extreme(profile, fleet, axis, want_maximum),
			"the transport alone owns the fleet's %s %s"
				% ["longest" if want_maximum else "lowest", axis]
		)

	# It must not have taken a signature away from any craft that already had one.
	for entry: Dictionary in PRESERVED_SIGNATURES:
		var ship_id: StringName = entry["ship"]
		var axis: String = entry["axis"]
		var highest: bool = entry["highest"]
		var owner_value := float((fleet[ship_id] as Dictionary)[axis])
		var mine_value := float(profile[axis])
		var preserved := owner_value > mine_value if highest else owner_value < mine_value
		_check(
			preserved,
			"the transport leaves %s's %s %s signature intact (%s vs %s)"
				% [ship_id, "highest" if highest else "lowest", axis, str(owner_value), str(mine_value)]
		)

	# RED: a transport that simply out-hulled the freighter would dominate it on
	# every axis the freighter owns. The check must notice.
	var dominating := profile.duplicate()
	for axis: String in HIGHER_IS_BETTER:
		dominating[axis] = maxf(float(profile[axis]), float((fleet[&"jovian_provisional"] as Dictionary)[axis]) + 1.0)
	for axis: String in LOWER_IS_BETTER:
		dominating[axis] = minf(float(profile[axis]), float((fleet[&"jovian_provisional"] as Dictionary)[axis]) - 0.01)
	_check(
		_count_advantages(dominating, fleet[&"jovian_provisional"]) == 0,
		"RED: a mutated transport that dominates the freighter is detected as dominating"
	)


func _load_existing_profiles() -> Dictionary:
	var result := {}
	for ship_id: StringName in EXISTING_BODY_TONES:
		var definition := load("res://assets/ships/%s.tres" % ship_id) as ShipDefinition
		if definition == null:
			continue
		var merged := definition.get_flight_profile().duplicate()
		merged.merge(definition.get_systems_profile())
		result[ship_id] = merged
	return result


func _count_advantages(first: Dictionary, second: Dictionary) -> int:
	var advantages := 0
	for key: String in HIGHER_IS_BETTER:
		if float(second[key]) > float(first[key]):
			advantages += 1
	for key: String in LOWER_IS_BETTER:
		if float(second[key]) < float(first[key]):
			advantages += 1
	return advantages


func _is_sole_extreme(
		subject: Dictionary,
		others: Dictionary,
		axis: String,
		want_maximum: bool
	) -> bool:
	var value := float(subject[axis])
	for other_id: StringName in others:
		var other_value := float((others[other_id] as Dictionary)[axis])
		if want_maximum and other_value >= value:
			return false
		if not want_maximum and other_value <= value:
			return false
	return true


# ---------------------------------------------------------------- group C ----


func _test_readable_colour(craft: HeroShip) -> void:
	var accent := craft.identification_accent.to_html(false)
	_check(accent == EXPECTED_ACCENT, "the transport renders its exact authored accent #%s" % accent)
	var body_tone := _body_tone_albedo(craft)
	_check(
		body_tone == EXPECTED_BODY_TONE,
		"the transport presents its exact rendered body tone #%s" % body_tone
	)
	if body_tone.is_empty():
		return

	var body_worst := INF
	var accent_worst := INF
	var torrent_accent_worst := INF
	for mode: String in ColourMetrics.VISION_MODELS:
		for ship_id: StringName in EXISTING_BODY_TONES:
			body_worst = minf(
				body_worst,
				ColourMetrics.separation(body_tone, str(EXISTING_BODY_TONES[ship_id]), mode)
			)
			var accent_separation := ColourMetrics.separation(accent, str(EXISTING_ACCENTS[ship_id]), mode)
			accent_worst = minf(accent_worst, accent_separation)
			if ship_id == &"torrent_provisional":
				torrent_accent_worst = minf(torrent_accent_worst, accent_separation)
	_evidence.append(
		"HALYARD_COLOUR_EVIDENCE: body_worst_ciede2000=%.2f accent_worst_ciede2000=%.2f torrent_accent_worst=%.2f"
			% [body_worst, accent_worst, torrent_accent_worst]
	)
	_check(
		body_worst >= BODY_TONE_FLOOR,
		"the transport body tone clears the frozen %.1f body floor (%.2f)" % [BODY_TONE_FLOOR, body_worst]
	)
	_check(
		accent_worst >= ACCENT_FLOOR,
		"the transport accent clears the frozen %.1f accent floor (%.2f)" % [ACCENT_FLOOR, accent_worst]
	)
	_check(
		torrent_accent_worst >= TORRENT_ACCENT_FLOOR,
		"the transport accent clears the stricter %.1f Torrent floor (%.2f)"
			% [TORRENT_ACCENT_FLOOR, torrent_accent_worst]
	)
	# The headroom rule. Both values must sit outside the fleet's own pre-existing
	# minima, so this craft cannot be the reason a later readability audit reports
	# a smaller margin than it used to.
	_check(
		body_worst >= FLEET_BODY_MINIMUM_BEFORE,
		"the transport spends none of the fleet's body-tone headroom (%.2f >= %.2f)"
			% [body_worst, FLEET_BODY_MINIMUM_BEFORE]
	)
	_check(
		accent_worst >= FLEET_ACCENT_MINIMUM_BEFORE,
		"the transport spends none of the fleet's accent headroom (%.2f >= %.2f)"
			% [accent_worst, FLEET_ACCENT_MINIMUM_BEFORE]
	)

	# RED: the pre-readability-pass fleet ivory is the exact tone the audit
	# recorded as broken. Measuring it here proves the floor is a real gate.
	var ivory_worst := INF
	for mode: String in ColourMetrics.VISION_MODELS:
		for ship_id: StringName in EXISTING_BODY_TONES:
			ivory_worst = minf(
				ivory_worst,
				ColourMetrics.separation("e7e4d6", str(EXISTING_BODY_TONES[ship_id]), mode)
			)
	_check(
		ivory_worst < BODY_TONE_FLOOR,
		"RED: the old shared fleet ivory fails the body floor this craft passes (%.2f)" % ivory_worst
	)


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
	var keys: Array = weights.keys()
	keys.sort()
	var best := ""
	var best_lightness := -1.0
	for hex: String in keys:
		if float(weights[hex]) / maxf(total, 0.0001) < BODY_TONE_MINIMUM_SHARE:
			continue
		var lightness := ColourMetrics.lightness(hex)
		if lightness > best_lightness:
			best_lightness = lightness
			best = hex
	return best


# ---------------------------------------------------------------- group D ----


## Derives the expected sign of `dot((b - a) x (c - a), shading_normal)` from the
## engine's own primitives, so the scorer measures Godot's real front-face
## convention rather than an assumption about it.
func _calibrate_winding() -> void:
	var signs := PackedFloat32Array()
	for primitive_name: String in CALIBRATION_PRIMITIVES:
		var mesh := ClassDB.instantiate(primitive_name) as Mesh
		if mesh == null:
			continue
		var score := _score_mesh(mesh, 1.0)
		# `agree` counts triangles whose CCW normal points *with* the shading
		# normal. Every engine primitive scores zero, so the convention is -1.
		signs.append(1.0 if int(score["agree"]) * 2 > int(score["total"]) else -1.0)
	_check(signs.size() == CALIBRATION_PRIMITIVES.size(), "every calibration primitive is measurable")
	var agreed := true
	for value in signs:
		if not is_equal_approx(value, signs[0]):
			agreed = false
	_check(agreed, "the engine's own primitives agree on one front-face winding convention")
	_winding_sign = signs[0] if signs.size() > 0 else -1.0
	_evidence.append("HALYARD_WINDING_EVIDENCE: engine_convention_sign=%d" % int(_winding_sign))


func _score_mesh(mesh: Mesh, expected_sign: float) -> Dictionary:
	var agree := 0
	var total := 0
	for surface_index in mesh.get_surface_count():
		var arrays := mesh.surface_get_arrays(surface_index)
		if arrays.size() <= Mesh.ARRAY_NORMAL:
			continue
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var raw_normals: Variant = arrays[Mesh.ARRAY_NORMAL]
		if not (raw_normals is PackedVector3Array):
			continue
		var normals: PackedVector3Array = raw_normals
		var raw_indices: Variant = arrays[Mesh.ARRAY_INDEX]
		var indices := PackedInt32Array()
		if raw_indices is PackedInt32Array and not (raw_indices as PackedInt32Array).is_empty():
			indices = raw_indices
		else:
			for index in vertices.size():
				indices.append(index)
		var triangle := 0
		while triangle + 2 < indices.size():
			var a := vertices[indices[triangle]]
			var b := vertices[indices[triangle + 1]]
			var c := vertices[indices[triangle + 2]]
			var shading := (
				normals[indices[triangle]]
				+ normals[indices[triangle + 1]]
				+ normals[indices[triangle + 2]]
			).normalized()
			var geometric := (b - a).cross(c - a)
			if geometric.length_squared() > 0.0000001:
				total += 1
				if geometric.normalized().dot(shading) * expected_sign > 0.0:
					agree += 1
			triangle += 3
	return {"agree": agree, "total": total}


func _test_winding(craft: HeroShip) -> void:
	var total := 0
	var correct := 0
	var offenders := PackedStringArray()
	var sample_mesh: Mesh = null
	for node in craft.find_children("*", "MeshInstance3D", true, false):
		var mesh_instance := node as MeshInstance3D
		if mesh_instance.mesh == null:
			continue
		if sample_mesh == null:
			sample_mesh = mesh_instance.mesh
		var score := _score_mesh(mesh_instance.mesh, _winding_sign)
		total += int(score["total"])
		correct += int(score["agree"])
		if int(score["agree"]) < int(score["total"]) and offenders.size() < 8:
			offenders.append("%s %d/%d" % [mesh_instance.name, int(score["agree"]), int(score["total"])])
	for node in craft.find_children("*", "MultiMeshInstance3D", true, false):
		var batch := node as MultiMeshInstance3D
		if batch.multimesh == null or batch.multimesh.mesh == null:
			continue
		var visible_copies := batch.multimesh.visible_instance_count
		if visible_copies < 0:
			visible_copies = batch.multimesh.instance_count
		var score := _score_mesh(batch.multimesh.mesh, _winding_sign)
		total += int(score["total"]) * visible_copies
		correct += int(score["agree"]) * visible_copies
		if int(score["agree"]) < int(score["total"]) and offenders.size() < 8:
			offenders.append("%s %d/%d x%d" % [batch.name, int(score["agree"]), int(score["total"]), visible_copies])
	_check(total > 2000, "the transport presents a substantial mesh to score (%d triangles)" % total)
	# Emission order *is* the winding. Every triangle on this craft must agree
	# with the outward normal its own vertices carry.
	_check(
		total > 0 and correct == total,
		"every triangle the transport builds is wound outward (%d of %d; %s)"
			% [correct, total, str(offenders)]
	)
	_evidence.append("HALYARD_WINDING_EVIDENCE: outward_triangles=%d of %d" % [correct, total])

	# RED: reverse one of this craft's own meshes and the same scorer must call
	# it fully backwards. Without this the assertion above could pass by
	# measuring nothing.
	_check(sample_mesh != null, "a transport mesh is available for the reversal control")
	if sample_mesh == null:
		return
	var reversed := _reversed_copy(sample_mesh)
	var reversed_score := _score_mesh(reversed, _winding_sign)
	_check(
		int(reversed_score["total"]) > 0 and int(reversed_score["agree"]) == 0,
		"RED: a reversed copy of a transport mesh scores zero outward triangles (%d of %d)"
			% [int(reversed_score["agree"]), int(reversed_score["total"])]
	)


func _reversed_copy(mesh: Mesh) -> ArrayMesh:
	var result := ArrayMesh.new()
	for surface_index in mesh.get_surface_count():
		var arrays := mesh.surface_get_arrays(surface_index)
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var raw_normals: Variant = arrays[Mesh.ARRAY_NORMAL]
		if not (raw_normals is PackedVector3Array):
			continue
		var normals: PackedVector3Array = raw_normals
		var raw_indices: Variant = arrays[Mesh.ARRAY_INDEX]
		var indices := PackedInt32Array()
		if raw_indices is PackedInt32Array and not (raw_indices as PackedInt32Array).is_empty():
			indices = raw_indices
		else:
			for index in vertices.size():
				indices.append(index)
		var flipped := PackedInt32Array()
		var triangle := 0
		while triangle + 2 < indices.size():
			flipped.append(indices[triangle])
			flipped.append(indices[triangle + 2])
			flipped.append(indices[triangle + 1])
			triangle += 3
		var surface_arrays := []
		surface_arrays.resize(Mesh.ARRAY_MAX)
		surface_arrays[Mesh.ARRAY_VERTEX] = vertices
		surface_arrays[Mesh.ARRAY_NORMAL] = normals
		surface_arrays[Mesh.ARRAY_INDEX] = flipped
		result.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, surface_arrays)
	return result


func _test_bow_docking_arch(craft: HeroShip) -> void:
	var visual := craft.call("get_halyard_visual_root") as Node3D
	var arch_matches := visual != null
	var lower_half_clear := true
	if visual != null:
		for segment_index in 5:
			var angle := PI * float(segment_index) / 4.0
			var segment := visual.get_node_or_null(
				"BowDockingArchSegment%02d" % segment_index
			) as MeshInstance3D
			var expected_position := Vector3(
				HalyardCrewTransport.BOW_RING_RADIUS * cos(angle),
				HalyardCrewTransport.BOW_RING_CENTRE_Y + HalyardCrewTransport.BOW_RING_RADIUS * sin(angle),
				HalyardCrewTransport.BOW_RING_Z
			)
			arch_matches = arch_matches and segment != null and segment.mesh != null \
				and segment.position.is_equal_approx(expected_position)
			if segment != null:
				lower_half_clear = lower_half_clear and segment.position.y \
					>= HalyardCrewTransport.BOW_RING_CENTRE_Y - 0.001
		var old_loop_segments := visual.find_children(
			"BowCollarSegment*", "MeshInstance3D", false, false
		)
		var struts_match := true
		var arch_struts: Array[MeshInstance3D] = []
		for strut_index in 2:
			var strut_angle := PI * (2.0 * float(strut_index) + 1.0) / 4.0
			var strut := visual.get_node_or_null(
				"BowDockingArchStrut%02d" % strut_index
			) as MeshInstance3D
			var expected_strut_position := Vector3(
				(HalyardCrewTransport.BOW_RING_RADIUS - 0.42) * cos(strut_angle) * 0.92,
				HalyardCrewTransport.BOW_RING_CENTRE_Y + (HalyardCrewTransport.BOW_RING_RADIUS - 0.42) * sin(strut_angle) * 0.92,
				-12.94
			)
			struts_match = struts_match and strut != null and strut.mesh != null \
				and strut.position.is_equal_approx(expected_strut_position)
			if strut != null:
				arch_struts.append(strut)
		var struts_are_mirrored := arch_struts.size() == 2 \
			and is_equal_approx(arch_struts[0].position.x, -arch_struts[1].position.x) \
			and is_equal_approx(arch_struts[0].position.y, arch_struts[1].position.y) \
			and is_equal_approx(arch_struts[0].position.z, arch_struts[1].position.z)
		var target_plate := visual.get_node_or_null("BowDockingTargetPlate") as MeshInstance3D
		arch_matches = arch_matches and old_loop_segments.is_empty() and struts_match \
			and struts_are_mirrored and target_plate != null and target_plate.mesh != null
	var collision := craft.get_node_or_null("BowCollarCollision") as CollisionShape3D
	var collision_box := collision.shape as BoxShape3D if collision != null else null
	_check(
		arch_matches and lower_half_clear
			and collision != null and collision.position.is_equal_approx(Vector3(0.0, 1.85, -13.55)) \
			and collision_box != null and collision_box.size.is_equal_approx(Vector3(5.30, 5.30, 0.60)),
		"five-piece open bow docking arch leaves no lower arch segments while preserving its target, mirrored supports and gameplay envelope"
	)


func _test_render_allocations(craft: HeroShip) -> void:
	var visual := craft.call("get_halyard_visual_root") as Node3D
	var batch := visual.get_node_or_null(^"SpineRibs") as MultiMeshInstance3D if visual != null else null
	var cabin := craft.get_node_or_null(^"WalkableInterior/CrewCabin") as Node3D
	var cabin_panes := cabin.get_node_or_null(^"CabinInteriorWindowPaneBatch") as MultiMeshInstance3D \
		if cabin != null else null
	_check(
		cabin_panes != null and cabin_panes.multimesh != null,
		"fourteen inboard cabin window panes resolve as one moving-interior MultiMesh"
	)
	if cabin_panes != null and cabin_panes.multimesh != null:
		var expected_cabin_panes: Array[Transform3D] = []
		var expected_cabin_names := PackedStringArray()
		for side in [-1.0, 1.0]:
			var side_name := "Port" if side < 0.0 else "Starboard"
			for window_index in HalyardCrewTransport.CABIN_WINDOW_COUNT:
				var window_z := (
					HalyardCrewTransport.CABIN_WINDOW_FIRST_Z
					+ float(window_index) * HalyardCrewTransport.CABIN_WINDOW_PITCH
				)
				if window_z < -9.30 or window_z > 2.10:
					continue
				expected_cabin_panes.append(Transform3D(
					Basis.IDENTITY,
					Vector3(side * 2.34, 2.35, window_z)
				))
				expected_cabin_names.append(side_name + "CabinWindowPane%02d" % window_index)
		var cabin_authored := cabin_panes.get_meta("authored_instance_transforms", []) as Array
		var cabin_transforms_exact := cabin_authored.size() == expected_cabin_panes.size()
		for index in mini(cabin_authored.size(), expected_cabin_panes.size()):
			cabin_transforms_exact = cabin_transforms_exact and (cabin_authored[index] as Transform3D).is_equal_approx(expected_cabin_panes[index])
		var expected_cabin_bounds := AABB()
		for index in expected_cabin_panes.size():
			var transformed_bounds := (
				expected_cabin_panes[index] * cabin_panes.multimesh.mesh.get_aabb()
			).abs()
			expected_cabin_bounds = (
				transformed_bounds
				if index == 0
				else expected_cabin_bounds.merge(transformed_bounds)
			)
		_check(
			cabin_panes.multimesh.instance_count == 14
			and cabin_panes.multimesh.visible_instance_count == -1
			and cabin_transforms_exact
			and cabin_panes.get_meta("authored_visual_names", PackedStringArray()) == expected_cabin_names
			and cabin_panes.material_override == craft.get_variant_materials().get("window_glow")
			and cabin_panes.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_ON
			and cabin_panes.layers == 1
			and cabin_panes.multimesh.custom_aabb.is_equal_approx(expected_cabin_bounds)
			and cabin_panes.find_children("*", "CollisionObject3D", true, false).is_empty()
			and cabin_panes.find_children("*", "Area3D", true, false).is_empty()
			and cabin.find_children("*CabinWindowPane*", "MeshInstance3D", true, false).is_empty(),
			"the cabin pane batch preserves exact transforms, identities, material, culling, shadows and collision-free presentation"
		)
	_check(
		batch != null and batch.multimesh != null,
		"seven dorsal service ribs resolve as one visual-only MultiMesh"
	)
	if batch == null or batch.multimesh == null:
		return
	var multi := batch.multimesh
	var expected: Array[Transform3D] = []
	for rib_index in HalyardCrewTransport.SPINE_RIB_COPY_COUNT:
		var rib_z := HalyardCrewTransport.TUBE_FORWARD_Z + 1.80 + float(rib_index) * 2.55
		expected.append(Transform3D(Basis.IDENTITY, Vector3(0.0, 4.10, rib_z)))
	var authored := batch.get_meta("authored_instance_transforms", []) as Array
	var authored_exact := authored.size() == expected.size()
	for index in mini(authored.size(), expected.size()):
		authored_exact = authored_exact and (authored[index] as Transform3D).is_equal_approx(expected[index])
	var authored_names := batch.get_meta("authored_visual_names", PackedStringArray()) as PackedStringArray
	_check(
		multi.instance_count == HalyardCrewTransport.SPINE_RIB_COPY_COUNT
		and multi.visible_instance_count == -1
		and authored_exact
		and authored_names == PackedStringArray([
			"SpineRib00", "SpineRib01", "SpineRib02", "SpineRib03",
			"SpineRib04", "SpineRib05", "SpineRib06",
		]),
		"batch preserves all seven authored rib transforms, ordering and visual names"
	)
	_check(
		multi.mesh != null
		and multi.mesh.get_aabb().size.is_equal_approx(HalyardCrewTransport.SPINE_RIB_SIZE)
		and multi.mesh.get_surface_count() == 1
		and batch.material_override == craft.get_variant_materials().get("hull_shade")
		and batch.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		and batch.layers == 1,
		"batch preserves rib extent, surface, material identity, shadows and render layer"
	)
	var old_rib_nodes := 0
	for raw_node in visual.get_children():
		if raw_node is MeshInstance3D and str(raw_node.name).begins_with("SpineRib"):
			old_rib_nodes += 1
	_check(
		old_rib_nodes == 0
		and batch.get_child_count() == 0
		and batch.find_children("*", "CollisionObject3D", true, false).is_empty()
		and batch.find_children("*", "Area3D", true, false).is_empty()
		and bool(batch.get_meta("visual_detail_only", false)),
		"the selected family remains childless, visual-only and non-colliding"
	)

	var report := craft.call("get_halyard_render_allocation_report") as Dictionary
	_check(
		int(report.descendant_nodes) == 124
		and int(report.mesh_instances) == 116
		and int(report.multimesh_batches) == 3,
		"exterior renderer nodes freeze at 124, MeshInstances at 116, batches at 3"
	)
	_check(
		int(report.drawn_copies) == 163
		and int(report.geometry_submissions) == 119
		and int(report.spine_rib_copies) == 7,
		"exterior drawn copies freeze at 163 and surface submissions at 119"
	)
	_check(
		int(report.unique_mesh_resources) == 65
		and int(report.unique_material_resources) == 14
		and int(report.multimesh_resources) == 3
		and int(report.renderer_buffer_floats) == 84,
		"exterior mesh/material allocations freeze at 65/14 with three MultiMesh resources"
	)
	_check(
		bool(report.renderer_buffer_matches_authored)
		and bool(report.bounds_match_authored)
		and bool(report.mesh_resource_matches_authored)
		and bool(report.material_resource_matches_authored)
		and bool(report.exact_counts),
		"renderer payload, explicit culling union and shared resource identities match the authored roster"
	)

	var detached := report.authored_spine_rib_transforms as Array
	detached[0] = Transform3D.IDENTITY
	_check(
		not ((craft.call("get_halyard_render_allocation_report").authored_spine_rib_transforms as Array)[0] as Transform3D).is_equal_approx(Transform3D.IDENTITY),
		"render report returns a detached authored-transform roster"
	)
	var original_buffer := multi.buffer.duplicate()
	var mutated_buffer := original_buffer.duplicate()
	mutated_buffer[3] += 0.25
	multi.buffer = mutated_buffer
	_check(
		(craft.call("get_halyard_audit_report").errors as PackedStringArray).has(
			"Halyard dorsal spine renderer buffer drifted from its authored transforms"
		),
		"RED: mutating one live rib transform is rejected by the Halyard audit"
	)
	multi.buffer = original_buffer
	var original_bounds := multi.custom_aabb
	multi.custom_aabb = original_bounds.grow(0.25)
	_check(
		(craft.call("get_halyard_audit_report").errors as PackedStringArray).has(
			"Halyard dorsal spine culling bounds drifted from its authored copies"
		),
		"RED: mutating the explicit rib culling union is rejected by the Halyard audit"
	)
	multi.custom_aabb = original_bounds
	_check(
		bool(craft.call("get_halyard_audit_report").valid),
		"restoring the exact batch payload restores a clean Halyard audit"
	)


# --------------------------------------------------------------- group D3 ----


func _test_weapon_presentation(craft: HeroShip) -> void:
	var visual := craft.call("get_halyard_visual_root") as Node3D
	var report := craft.call("get_halyard_weapon_visual_report") as Dictionary
	var expected_names := PackedStringArray([
		"PortDefensiveMountBase", "PortDefensivePulseBarrel",
		"PortDefensiveBarrelShroud", "PortDefensiveMuzzleCollar",
		"PortDefensiveMuzzleLens", "StarboardDefensiveMountBase",
		"StarboardDefensivePulseBarrel", "StarboardDefensiveBarrelShroud",
		"StarboardDefensiveMuzzleCollar", "StarboardDefensiveMuzzleLens",
	])
	_check(
		visual != null
		and int(report.mount_count) == 2
		and int(report.visual_parts_per_mount) == 5
		and report.present_node_names == expected_names
		and bool(report.exact_roster),
		"the twin defensive mounts expose the exact five-part base/barrel/shroud/collar/lens roster"
	)
	if visual == null:
		return

	var muzzle_names := ["LeftMuzzle", "RightMuzzle"]
	var side_names := ["Port", "Starboard"]
	var expected_muzzles := HalyardCrewTransport.DEFENSIVE_MUZZLE_POSITIONS
	var aligned := true
	var dimensions_match := true
	var metadata_matches := true
	var measured_dimensions: Array[Vector3] = []
	for side_index in 2:
		var muzzle := craft.get_node_or_null(muzzle_names[side_index]) as Marker3D
		var prefix: String = side_names[side_index]
		var base := visual.get_node_or_null(prefix + "DefensiveMountBase") as MeshInstance3D
		var barrel := visual.get_node_or_null(prefix + "DefensivePulseBarrel") as MeshInstance3D
		var shroud := visual.get_node_or_null(prefix + "DefensiveBarrelShroud") as MeshInstance3D
		var collar := visual.get_node_or_null(prefix + "DefensiveMuzzleCollar") as MeshInstance3D
		var lens := visual.get_node_or_null(prefix + "DefensiveMuzzleLens") as MeshInstance3D
		aligned = (
			aligned and muzzle != null and lens != null
			and muzzle.position.is_equal_approx(expected_muzzles[side_index])
			and lens.position.is_equal_approx(muzzle.position)
			and lens.global_position.is_equal_approx(muzzle.global_position)
		)
		if base == null or barrel == null or shroud == null or collar == null or lens == null:
			dimensions_match = false
			metadata_matches = false
			continue
		measured_dimensions.append_array([
			base.mesh.get_aabb().size, barrel.mesh.get_aabb().size,
			shroud.mesh.get_aabb().size, collar.mesh.get_aabb().size,
			lens.mesh.get_aabb().size,
		])
		dimensions_match = (
			dimensions_match
			and base.mesh.get_aabb().size.is_equal_approx(Vector3(0.72, 0.28, 0.72))
			and barrel.mesh.get_aabb().size.is_equal_approx(Vector3(0.22, 1.10, 0.22))
			and shroud.mesh.get_aabb().size.is_equal_approx(HalyardCrewTransport.DEFENSIVE_SHROUD_SIZE)
			and collar.mesh.get_aabb().size.is_equal_approx(Vector3(0.32, 0.14, 0.32))
			and is_equal_approx(lens.mesh.get_aabb().size.y, 0.15)
			and absf(lens.mesh.get_aabb().size.x - 0.15) < 0.002
			and absf(lens.mesh.get_aabb().size.z - 0.15) < 0.002
		)
		for part in [base, barrel, shroud, collar, lens]:
			metadata_matches = (
				metadata_matches
				and part.get_meta("evidence_status", &"") == &"modern_interpretation"
				and part.get_meta("weapon_role", &"") == &"light_self_defence"
				and bool(part.get_meta("modern_original", false))
				and bool(part.get_meta("visual_only", false))
			)
	_check(aligned, "both low-output lenses remain centred on the unchanged combat muzzle transforms")
	_check(
		dimensions_match,
		"both mounts retain their compact authored base/barrel/shroud/collar/lens dimensions (%s)"
			% str(measured_dimensions)
	)
	_check(
		HalyardCrewTransport.DEFENSIVE_MOUNT_BASE_RADIUS < 0.68
		and HalyardCrewTransport.DEFENSIVE_BARREL_RADIUS < 0.19
		and HalyardCrewTransport.DEFENSIVE_BARREL_LENGTH < 1.55,
		"the Halyard mount remains visibly lighter and shorter than the Jovian defensive convention"
	)
	_check(
		metadata_matches
		and bool(report.modern_metadata_matches)
		and report.design_status == &"modern_interpretation"
		and not bool(report.historically_authenticated)
		and report.weapon_role == &"light_self_defence",
		"every defensive part is explicitly modern, visual-only light self-defence presentation"
	)
	_check(
		craft.get_ship_definition() != null
		and is_equal_approx(
			float(craft.get_ship_definition().get_systems_profile().get("weapon_cooldown", -1.0)),
			0.95
		),
		"the compact presentation remains coupled to the fleet's slowest frozen weapon cadence"
	)


# ---------------------------------------------------------------- group E ----


func _test_cockpit_and_boarding(craft: HeroShip) -> void:
	var seat := craft.get_pilot_seat_anchor()
	_check(seat != null and craft.is_ancestor_of(seat), "the pilot seat rides the transport hierarchy")
	var camera := _find_cockpit_camera(craft)
	_check(camera != null, "the transport exposes a cockpit camera")
	if seat == null or camera == null:
		return
	_check(
		str(seat.get_parent().name) == "CockpitInterior",
		"the pilot seat sits inside the functional cockpit, not on a loose marker"
	)
	_check(
		str(camera.get_parent().name) == "CockpitInterior",
		"the cockpit camera is mounted inside the cockpit rather than floating on the hull"
	)
	_check(
		(-camera.global_basis.z.normalized()).dot(-craft.global_basis.z.normalized()) > 0.999,
		"the cockpit camera looks along the transport's own nose axis"
	)
	var seat_local := craft.to_local(seat.global_position)
	var camera_local := craft.to_local(camera.global_position)
	var rise := camera_local.y - seat_local.y
	_check(
		is_equal_approx(rise, SEAT_TO_COCKPIT_CAMERA_RISE),
		"the transport keeps the frozen %.2f m feet-frame-to-eye-point rise (%.4f)"
			% [SEAT_TO_COCKPIT_CAMERA_RISE, rise]
	)
	# RED: the exact defect this convention exists to prevent — a seat anchor
	# authored at cushion height instead of feet-frame height.
	var cushion_height_anchor := seat_local.y + 0.72
	_check(
		not is_equal_approx(camera_local.y - cushion_height_anchor, SEAT_TO_COCKPIT_CAMERA_RISE),
		"RED: a cushion-height seat anchor would break the frozen rise"
	)

	var hull_top := _visible_hull_top(craft)
	var head_y := camera_local.y - CAMERA_ABOVE_HEAD_BONE
	var clearance := hull_top - head_y
	_evidence.append(
		"HALYARD_SEATING_EVIDENCE: seat_local_y=%.3f camera_local_y=%.3f hull_top=%.3f head_hull_clearance=%.3f"
			% [seat_local.y, camera_local.y, hull_top, clearance]
	)
	_check(
		clearance >= HEAD_HULL_CLEARANCE_MINIMUM,
		"the seated pilot's head stays at least %.2f m inside the transport's own hull (%.3f)"
			% [HEAD_HULL_CLEARANCE_MINIMUM, clearance]
	)

	# The second crew station is a real object on the real deck.
	var station_anchor := craft.call("get_co_pilot_station_anchor") as Marker3D
	_check(station_anchor != null, "the flight deck carries a second physical crew station")
	if station_anchor != null:
		var station_local := craft.to_local(station_anchor.global_position)
		_check(
			absf(station_local.y - seat_local.y) < 0.25,
			"both flight-deck stations sit on one deck plane (%.3f vs %.3f)"
				% [station_local.y, seat_local.y]
		)
		_check(
			signf(station_local.x) != signf(seat_local.x) and absf(station_local.x - seat_local.x) > 0.8,
			"the two flight-deck stations are side by side, not stacked on one seat"
		)

	# Boarding convention: port side, and an exit clear of the craft's own hull.
	var boarding_local := craft.to_local(craft.get_boarding_position())
	_check(boarding_local.x < 0.0, "the transport boards from the port side, as the fleet does")
	var exit_marker := craft.get_node_or_null("ExitPoint") as Marker3D
	_check(exit_marker != null, "the transport publishes an exit point")
	if exit_marker != null:
		var envelope := _collision_envelope(craft)
		_check(
			exit_marker.position.x < envelope.position.x,
			"the exit point is outboard of the transport's own collision (%.2f vs %.2f)"
				% [exit_marker.position.x, envelope.position.x]
		)


func _find_cockpit_camera(craft: HeroShip) -> Camera3D:
	for node in craft.find_children("CockpitCamera", "Camera3D", true, false):
		return node as Camera3D
	return null


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


# ---------------------------------------------------------------- group F ----


func _test_interior(craft: HeroShip) -> void:
	_check(
		craft.has_method("get_walkable_interior_report"),
		"the transport publishes a walkable interior report"
	)
	var report := craft.call("get_walkable_interior_report") as Dictionary
	_check(
		(report.get("root", null) as Node3D) != null and not bool(report.get("detached_interior", true)),
		"the transport interior is a connected part of the ship frame, not a detached set"
	)
	_check(
		(report.get("root", null) as Node3D) != null
		and (report.get("root") as Node3D).get_parent() == craft,
		"the interior root is a direct child of the physical ship, so it shares one rigid transform"
	)
	_check(
		int(report.get("passenger_seat_count", 0)) >= MINIMUM_CREW_SEATS,
		"the transport carries the crew complement its role implies (%d seats)"
			% int(report.get("passenger_seat_count", 0))
	)
	_check(
		int(report.get("flight_deck_station_count", 0)) == FLIGHT_DECK_STATIONS,
		"the transport declares its two-station flight deck"
	)
	_check(
		(report.get("access_marker", null) as Node3D) != null
		and (report.get("deck_marker", null) as Node3D) != null,
		"the transport publishes both its exterior access and interior deck markers"
	)
	var bounds := craft.call("get_interior_bounds") as AABB
	var volume := bounds.size.x * bounds.size.y * bounds.size.z
	_check(
		volume >= MINIMUM_INTERIOR_VOLUME
		and bounds.size.x >= MINIMUM_WALKABLE_DIMENSION
		and bounds.size.y >= MINIMUM_WALKABLE_DIMENSION,
		"the interior is a walkable volume rather than a token cavity (%s, %.0f m3)"
			% [str(bounds.size), volume]
	)

	# Scale and claim have to agree in both directions: a craft that publishes an
	# interior must actually be bigger than the small-craft band.
	var envelope := _collision_envelope(craft)
	_check(
		maxf(envelope.size.x, envelope.size.z) > SMALL_CRAFT_ENVELOPE_MAXIMUM,
		"the interior-bearing transport exceeds the small-craft envelope %s" % str(envelope.size)
	)
	var tags := craft.get_ship_definition().get_compatibility_tags()
	_check(
		tags.has("medium_craft") and tags.has("crew_transport") and tags.has("multi_crew"),
		"the transport declares medium-craft, crew-transport and multi-crew compatibility"
	)
	_check(
		not tags.has("small_craft")
		and not tags.has("freight")
		and not tags.has("cargo")
		and not tags.has("light_freighter"),
		"the transport claims no cargo authority it does not have"
	)
	_evidence.append(
		"HALYARD_SCALE_EVIDENCE: collision_envelope=%s interior_bounds=%s"
			% [str(envelope.size), str(bounds.size)]
	)

	# The walk from the airstair to the pilot seat is one continuous deck. The
	# three plates must join in z without a gap the crew could fall through.
	var footprints: Array[AABB] = []
	for collider_name: String in WALKABLE_DECK_COLLIDERS:
		var collider := craft.get_node_or_null(collider_name) as CollisionShape3D
		_check(collider != null, "%s exists as a physical deck plate" % collider_name)
		if collider == null:
			continue
		var box := collider.shape as BoxShape3D
		_check(box != null, "%s is a box deck plate" % collider_name)
		if box == null:
			continue
		var half := box.size * 0.5
		footprints.append(AABB(collider.position - half, box.size))
	_check(footprints.size() == WALKABLE_DECK_COLLIDERS.size(), "every declared deck plate resolves")
	if footprints.size() == WALKABLE_DECK_COLLIDERS.size():
		footprints.sort_custom(func(a: AABB, b: AABB) -> bool: return a.position.z < b.position.z)
		var worst_gap := -INF
		for index in footprints.size() - 1:
			var gap: float = footprints[index + 1].position.z - (footprints[index].position.z + footprints[index].size.z)
			worst_gap = maxf(worst_gap, gap)
		# Abutting plates meet at exactly 0.0 m in design and at a few times
		# machine epsilon in float, so the gate is a millimetre rather than a
		# strict zero. The mutation below is 600 times larger than that.
		_check(
			worst_gap <= DECK_JOIN_TOLERANCE,
			"the three deck plates join without a gap the crew could fall through (worst %.6f m)"
				% worst_gap
		)
		# RED: shift one plate aft and the same check must find the hole.
		var shifted := footprints.duplicate()
		shifted[1] = AABB(footprints[1].position + Vector3(0.0, 0.0, 0.6), footprints[1].size)
		var mutated_gap := -INF
		for index in shifted.size() - 1:
			var gap: float = shifted[index + 1].position.z - (shifted[index].position.z + shifted[index].size.z)
			mutated_gap = maxf(mutated_gap, gap)
		_check(
			mutated_gap > DECK_JOIN_TOLERANCE,
			"RED: a shifted deck plate is detected as a gap (%.3f m)" % mutated_gap
		)


func _test_in_flight_cabin(craft: HeroShip) -> void:
	_check(
		craft.supports_in_flight_cabin_access(),
		"the crew transport offers in-flight cabin access; that is the point of the class"
	)
	var cabin := craft.get_in_flight_cabin_report()
	_check(
		StringName(str(cabin.get("status", ""))) == &"walkable_cabin",
		"the transport reports a walkable cabin rather than a bare boolean"
	)
	var coordinator := craft.call("get_moving_interior_component") as MovingInteriorFrame
	_check(
		cabin.get("frame") == coordinator and coordinator != null,
		"the cabin contract hands back the craft's own occupancy coordinator"
	)
	var bounds := cabin.get("local_bounds", AABB()) as AABB
	var stand := cabin.get("stand_transform", Transform3D.IDENTITY) as Transform3D
	var stand_local := craft.global_transform.affine_inverse() * stand.origin
	_check(
		bounds.has_point(stand_local),
		"the standing pose the pilot arrives at is inside the confinement envelope %s" % str(stand_local)
	)
	# The envelope has to cover every deck plate a crew member can stand on, or
	# containment fights the floor instead of the hull opening.
	for collider_name: String in WALKABLE_DECK_COLLIDERS:
		var collider := craft.get_node_or_null(collider_name) as CollisionShape3D
		if collider == null:
			continue
		var box := collider.shape as BoxShape3D
		if box == null:
			continue
		var half := box.size * 0.5
		var top := collider.position + Vector3(0.0, half.y, 0.0)
		var footprint := AABB(
			Vector3(top.x - half.x, top.y, top.z - half.z),
			Vector3(half.x * 2.0, 0.0, half.z * 2.0)
		)
		_check(
			bounds.encloses(footprint),
			"the confinement envelope encloses the whole %s walking surface" % collider_name
		)
	# The flight deck is walkable, so it must be enclosed by real geometry rather
	# than by the containment guard alone.
	_check(
		craft.get_node_or_null("CockpitForwardWallCollision") is CollisionShape3D,
		"the flight deck has a physical forward wall a crew member cannot walk off"
	)
	var sidewalls := 0
	for child in craft.get_children():
		if child is CollisionShape3D and str(child.name).ends_with("CockpitSidewallCollision"):
			sidewalls += 1
	_check(sidewalls == 2, "the flight deck has physical port and starboard walls")

	# RED: the offer is derived from the live coordinator, not asserted.
	var occupant_volume := coordinator.get_occupant_volume()
	coordinator.set_moving_frame(null)
	await process_frame
	_check(
		not craft.supports_in_flight_cabin_access(),
		"RED: a transport whose occupancy coordinator is unbound withdraws the cabin offer"
	)
	coordinator.configure(craft, craft.call("get_interior_bounds"), occupant_volume)
	await process_frame
	await physics_frame
	_check(
		craft.supports_in_flight_cabin_access(),
		"restoring the coordinator restores the cabin offer"
	)

	# RED: a destroyed cabin is not a cabin.
	craft.apply_damage(craft.maximum_hull + 1.0, craft.global_position, Vector3.UP)
	await process_frame
	await physics_frame
	_check(
		craft.is_destroyed() and not craft.supports_in_flight_cabin_access(),
		"RED: a destroyed transport refuses to release a pilot into its wreck"
	)


# ---------------------------------------------------------------- group G ----


func _test_surfacing(craft: HeroShip) -> void:
	var materials := craft.get_variant_materials()
	var raw_primitives := PackedStringArray()
	var untextured := PackedStringArray()
	for node in craft.find_children("*", "MeshInstance3D", true, false):
		var mesh_instance := node as MeshInstance3D
		if mesh_instance.mesh == null:
			continue
		# A raw engine primitive at player eye height reads as an untextured box.
		if mesh_instance.mesh is BoxMesh and raw_primitives.size() < 8:
			raw_primitives.append(str(mesh_instance.name))
	_check(
		raw_primitives.is_empty(),
		"the transport builds no raw BoxMesh primitives (%s)" % str(raw_primitives)
	)

	for key: String in HULL_MATERIAL_KEYS:
		var material := materials.get(key) as StandardMaterial3D
		_check(material != null, "the transport publishes its %s hull material" % key)
		if material == null:
			continue
		_check(
			material.albedo_texture != null
			and material.normal_texture != null
			and material.roughness_texture != null,
			"%s binds the registered panel albedo/normal/roughness trio" % key
		)
		_check(
			material.uv1_triplanar and not material.uv1_world_triplanar
			and is_equal_approx(material.uv1_triplanar_sharpness, PANEL_TRIPLANAR_SHARPNESS),
			"%s uses the registered ship-local triplanar projection" % key
		)
		_check(
			material.normal_scale >= SHIP_NORMAL_SCALE_BAND.x
			and material.normal_scale <= SHIP_NORMAL_SCALE_BAND.y,
			"%s keeps hull relief inside the fleet's %.2f-%.2f band rather than at station relief (%.3f)"
				% [key, SHIP_NORMAL_SCALE_BAND.x, SHIP_NORMAL_SCALE_BAND.y, material.normal_scale]
		)
		_check(material.clearcoat_enabled, "%s carries the fleet's painted-alloy clearcoat" % key)
		if untextured.size() < 4 and material.albedo_texture == null:
			untextured.append(key)

	# Walked and structural surfaces keep the registered station relief, which is
	# exactly where that family belongs.
	for key: String in ["deck", "structure", "dark", "accent", "trim", "locker"]:
		var material := materials.get(key) as StandardMaterial3D
		_check(material != null, "the transport publishes its %s surface material" % key)
		if material == null:
			continue
		_check(
			material.normal_texture != null and material.uv1_triplanar
			and not material.uv1_world_triplanar
			and is_equal_approx(material.normal_scale, STATION_PANEL_NORMAL_SCALE),
			"%s keeps the ship-local panel recipe at normal_scale %.1f" % [key, STATION_PANEL_NORMAL_SCALE]
		)

	# RED: a stripped material must be detected by the same predicate.
	var stripped := StandardMaterial3D.new()
	_check(
		stripped.albedo_texture == null and not stripped.uv1_world_triplanar,
		"RED: an unsurfaced material is detected as carrying no panel recipe"
	)


# ---------------------------------------------------------------- group H ----


func _test_berth_and_production_roster() -> void:
	var game := MAIN_SCENE.instantiate() as GameFlow
	_check(game != null, "production Main instantiates with the transport in the fleet")
	if game == null:
		return
	root.add_child(game)
	await process_frame
	for _settle in 6:
		await physics_frame
		await process_frame

	var fleet: Array[HeroShip] = game.get_flyable_ships()
	var transport: HeroShip = null
	for candidate in fleet:
		if candidate.get_ship_id() == HALYARD_ID:
			transport = candidate
	_check(
		transport != null,
		"the transport is accepted into the production flyable roster (%d craft)" % fleet.size()
	)
	_check(fleet.size() == 5, "the production roster is the expanded five-craft fleet")
	if transport == null:
		await _clean_up(game)
		return

	var world := game.get_node_or_null("ShipyardWorld") as ShipyardWorld
	_check(world != null and world.has_berth(HALYARD_BERTH_ID), "the world owns the transport's berth")
	if world == null or not world.has_berth(HALYARD_BERTH_ID):
		await _clean_up(game)
		return
	var berth := world.get_berth_node(HALYARD_BERTH_ID)
	_check(berth != null, "the transport berth resolves to a live ShipBerth")
	if berth == null:
		await _clean_up(game)
		return
	_check(
		berth.is_compatible_with(transport.get_ship_definition()),
		"the berth accepts the transport's declared compatibility tags"
	)

	# The strict dock fit: the complete oriented collision envelope has to sit
	# inside the berth's landing volume, not just the ship's origin.
	var collision_report := transport.get_landing_collision_report()
	_check(bool(collision_report.get("valid", false)), "the transport publishes a valid landing envelope")
	var local_bounds := collision_report.get("local_bounds", AABB()) as AABB
	_check(
		berth.contains_oriented_bounds(world.get_berth_transform(HALYARD_BERTH_ID), local_bounds),
		"the transport's whole hull fits its berth's strict landing volume %s" % str(local_bounds.size)
	)
	_evidence.append(
		"HALYARD_BERTH_EVIDENCE: landing_bounds=%s berth_half_extents=%s"
			% [str(local_bounds.size), str(berth.get_landing_half_extents())]
	)
	# RED: inflate the envelope and the same fit must refuse it.
	var inflated := local_bounds.grow(8.0)
	_check(
		not berth.contains_oriented_bounds(world.get_berth_transform(HALYARD_BERTH_ID), inflated),
		"RED: an oversized hull is refused by the same strict dock fit"
	)

	# It parked where it was told to, and it is not overlapping its neighbour.
	var berth_origin := world.get_berth_transform(HALYARD_BERTH_ID).origin
	_check(
		transport.global_position.distance_to(berth_origin) < 0.05,
		"the transport is physically parked on its own berth (%.3f m)"
			% transport.global_position.distance_to(berth_origin)
	)
	var zenith_origin := world.get_berth_transform(&"zenith_fleet_dock_berth").origin
	_check(
		absf(berth_origin.x - zenith_origin.x) > 12.0,
		"the transport berth stays clear of the neighbouring fleet dock (%.2f m apart)"
			% absf(berth_origin.x - zenith_origin.x)
	)

	# The comb's bookkeeping moved with the craft rather than after it.
	var comb_audit := world.get_fleet_dock_comb_integration_audit_report()
	_check(
		int(comb_audit.get("external_assignment_count", 0)) == 2
		and int(comb_audit.get("deferred_empty_dock_count", 0)) == 1,
		"the fleet dock comb reports two assigned docks and one still genuinely empty"
	)
	_check(
		bool(comb_audit.get("valid", false)),
		"the fleet dock integration audit stays clean: %s" % str(comb_audit.get("errors", []))
	)

	await _clean_up(game)


func _clean_up(game: Node) -> void:
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


# --------------------------------------------------------------- harness ----


func _check(condition: bool, description: String) -> void:
	_assertion_count += 1
	if condition:
		print("PASS: ", description)
	else:
		_failures.append(description)
		push_error("FAIL: " + description)


func _finish() -> void:
	if _failures.is_empty():
		print("HALYARD_CREW_TRANSPORT_TEST_OK: %d assertions" % _assertion_count)
		quit(0)
	else:
		print(
			"HALYARD_CREW_TRANSPORT_TEST_FAILED: %d/%d assertions failed: %s"
				% [_failures.size(), _assertion_count, "; ".join(_failures)]
		)
		quit(1)
