extends SceneTree

const PolicyScript := preload(
	"res://scripts/world/planetary_surface_gravity_policy.gd"
)
const WorldScript := preload(
	"res://scripts/world/definitions/planetary_world_definition.gd"
)
const TerrainScript := preload(
	"res://scripts/world/planetary_terrain_profile.gd"
)
const FrameScript := preload(
	"res://scripts/world/planetary_coordinate_frame.gd"
)

const BODY_RADIUS_M := 120_000.0
const MINIMUM_SURFACE_RADIUS_M := 117_500.0
const MAXIMUM_SURFACE_RADIUS_M := 128_500.0
const REFERENCE_GRAVITY_MPS2 := 9.81
const EXPECTED_ASSERTIONS := 26
const COMMON_AUTHORITY_KEYS := [
	"renderer", "gameplay", "streaming", "save", "network", "physics",
	"world_generation", "terrain_generation", "collision_generation",
	"origin_shift", "weather_clock", "audio",
]
const ADJACENT_AUTHORITY_KEYS := [
	"node_movement", "physics_integration", "collision", "origin_rebase",
	"landing_decision", "renderer", "clock", "streaming", "save", "network",
]

var _assertions := 0
var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_test_configuration_composition_and_freeze()
	_test_gravity_and_shell_boundaries()
	_test_tangent_orientation_hints()
	_test_invalid_sample_boundaries_and_purity()
	_test_detachment_authority_and_structured_red()
	_finish()


func _test_configuration_composition_and_freeze() -> void:
	var policy := PolicyScript.new() as PlanetarySurfaceGravityPolicy
	_check(
		policy is RefCounted
			and not (policy as Object).is_class("Node")
			and policy.sample(Vector3.UP * BODY_RADIUS_M).reason
				== &"not_configured"
			and not bool(policy.audit().valid),
		"the policy is a pure RefCounted and fails closed before configuration"
	)
	var world := _world()
	var terrain := _terrain()
	var frame := _frame(BODY_RADIUS_M)
	_check(
		policy.configure(null, terrain, frame, REFERENCE_GRAVITY_MPS2).reason
			== &"missing_world_definition"
			and policy.configure(world, null, frame, REFERENCE_GRAVITY_MPS2).reason
				== &"missing_terrain_profile"
			and policy.configure(world, terrain, null, REFERENCE_GRAVITY_MPS2).reason
				== &"missing_coordinate_frame"
			and not policy.is_configured(),
		"missing composition inputs reject without partially configuring"
	)
	var invalid_world := _world()
	invalid_world.scene_path = ""
	var invalid_terrain := _terrain()
	invalid_terrain.maximum_elevation_meters = NAN
	var invalid_frame := FrameScript.new() as PlanetaryCoordinateFrame
	_check(
		policy.configure(
			invalid_world, terrain, frame, REFERENCE_GRAVITY_MPS2
		).reason == &"invalid_world_definition"
			and policy.configure(
				world, invalid_terrain, frame, REFERENCE_GRAVITY_MPS2
			).reason == &"invalid_terrain_profile"
			and policy.configure(
				world, terrain, invalid_frame, REFERENCE_GRAVITY_MPS2
			).reason == &"invalid_coordinate_frame"
			and not policy.is_configured(),
		"malformed source contracts are structured red and leave the policy retryable"
	)
	var wrong_id_terrain := _terrain()
	wrong_id_terrain.profile_id = &"other_terrain"
	var wrong_radius_terrain := _terrain()
	wrong_radius_terrain.reference_planet_radius_meters += 0.001
	_check(
		policy.configure(
			world, wrong_id_terrain, frame, REFERENCE_GRAVITY_MPS2
		).reason == &"terrain_profile_id_mismatch"
			and policy.configure(
				world, wrong_radius_terrain, frame, REFERENCE_GRAVITY_MPS2
			).reason == &"body_radius_mismatch"
			and policy.configure(
				world, terrain, _frame(BODY_RADIUS_M + 0.001),
				REFERENCE_GRAVITY_MPS2
			).reason == &"body_radius_mismatch",
		"terrain identity and every composed sea-level radius use exact equality"
	)
	_check(
		policy.configure(world, terrain, frame, NAN).reason
			== &"invalid_reference_surface_gravity"
			and policy.configure(world, terrain, frame, 0.0).reason
				== &"invalid_reference_surface_gravity"
			and policy.configure(
				world,
				terrain,
				frame,
				PolicyScript.MAX_REFERENCE_GRAVITY_MPS2 + 0.001
			).reason == &"invalid_reference_surface_gravity",
		"reference acceleration rejects nonfinite, zero, and out-of-range values"
	)
	var configured := policy.configure(
		world, terrain, frame, REFERENCE_GRAVITY_MPS2
	)
	var frozen := policy.get_snapshot()
	_check(
		bool(configured.accepted)
			and configured.reason == &"configured"
			and policy.is_configured()
			and bool(policy.audit().valid)
			and frozen.radius_datum == &"body_center_to_sea_level"
			and frozen.sample_frame == &"planetary_body_local"
			and frozen.body_id == &"vertical_slice_body"
			and float(frozen.body_radius_meters) == BODY_RADIUS_M
			and float(frozen.minimum_surface_radius_meters)
				== MINIMUM_SURFACE_RADIUS_M
			and float(frozen.maximum_surface_radius_meters)
				== MAXIMUM_SURFACE_RADIUS_M,
		"one valid composition freezes exact identity, body datum, and terrain shell"
	)
	_check(
		policy.configure(
			_world(), _terrain(), _frame(BODY_RADIUS_M), 1.0
		).reason == &"already_configured",
		"a configured policy is immutable"
	)

	world.world_id = &"caller_mutated"
	world.body_radius_metres = 130_000.0
	terrain.profile_id = &"caller_mutated"
	terrain.reference_planet_radius_meters = 130_000.0
	terrain.evidence_notes = "Caller mutation"
	var rebase := frame.request_rebase(
		Vector3(5_000.0, 0.0, 0.0), frame.get_generation()
	)
	_check(
		bool(rebase.accepted)
			and policy.get_snapshot() == frozen
			and policy.sample(Vector3.UP * BODY_RADIUS_M).body_id
				== &"vertical_slice_body",
		"source mutation and a coordinate-frame rebase request cannot retune frozen body-local policy"
	)


func _test_gravity_and_shell_boundaries() -> void:
	var policy := _policy()
	var sea_level := policy.sample(Vector3.UP * BODY_RADIUS_M)
	_check(
		bool(sea_level.accepted)
			and sea_level.reason == &"sampled"
			and sea_level.radial_up == Vector3.UP
			and is_equal_approx(
				float(sea_level.gravity_magnitude_mps2),
				REFERENCE_GRAVITY_MPS2
			)
			and (sea_level.gravity_vector_mps2 as Vector3).is_equal_approx(
				Vector3.DOWN * REFERENCE_GRAVITY_MPS2
			)
			and float(sea_level.altitude_meters) == 0.0
			and (sea_level.shell as Dictionary).state == &"sea_level_boundary",
		"sea level returns exact altitude, radial up, inward vector, and reference magnitude"
	)
	var minimum := policy.sample(Vector3.UP * MINIMUM_SURFACE_RADIUS_M)
	var expected_minimum_gravity := REFERENCE_GRAVITY_MPS2 * pow(
		BODY_RADIUS_M / MINIMUM_SURFACE_RADIUS_M, 2.0
	)
	_check(
		bool(minimum.accepted)
			and float(minimum.altitude_meters) == -2500.0
			and is_equal_approx(
				float(minimum.gravity_magnitude_mps2),
				expected_minimum_gravity
			)
			and bool((minimum.shell as Dictionary).at_minimum_surface_radius)
			and bool((minimum.shell as Dictionary).within_terrain_envelope),
		"the exact minimum terrain radius is inclusive and follows inverse-square gravity"
	)
	var maximum := policy.sample(Vector3.UP * MAXIMUM_SURFACE_RADIUS_M)
	_check(
		bool(maximum.accepted)
			and float(maximum.altitude_meters) == 8500.0
			and (maximum.shell as Dictionary).state
				== &"maximum_surface_boundary"
			and bool((maximum.shell as Dictionary).at_maximum_surface_radius)
			and bool((maximum.shell as Dictionary).within_terrain_envelope),
		"the exact maximum terrain radius remains an inclusive named boundary"
	)
	var above := policy.sample(Vector3.UP * (BODY_RADIUS_M * 2.0))
	_check(
		bool(above.accepted)
			and is_equal_approx(
				float(above.gravity_magnitude_mps2),
				REFERENCE_GRAVITY_MPS2 * 0.25
			)
			and (above.shell as Dictionary).state == &"above_terrain_shell"
			and bool((above.shell as Dictionary).above_terrain_envelope)
			and not bool((above.shell as Dictionary).within_terrain_envelope),
		"above the terrain shell, inverse-square falloff continues without inventing a cutoff"
	)
	var within := policy.sample(Vector3.UP * 121_000.0)
	_check(
		(within.shell as Dictionary).state == &"within_terrain_envelope"
			and not bool((within.shell as Dictionary).at_sea_level_radius)
			and float(within.altitude_meters) == 1000.0,
		"non-boundary terrain samples are distinguished from the three inclusive endpoints"
	)


func _test_tangent_orientation_hints() -> void:
	var policy := _policy()
	var equator := policy.sample(Vector3.UP * BODY_RADIUS_M)
	var basis := equator.tangent_basis_body_local as Basis
	_check(
		basis.is_finite()
			and basis.is_orthonormal()
			and basis.determinant() > 0.0
			and basis.x.is_equal_approx(Vector3.RIGHT)
			and basis.y.is_equal_approx(Vector3.UP)
			and basis.z.is_equal_approx(Vector3.BACK)
			and (equator.tangent_north as Vector3).is_equal_approx(
				Vector3.FORWARD
			)
			and not bool(equator.tangent_fallback_used),
		"projected north yields the documented +X east, +Y up, +Z south tangent hint"
	)
	var diagonal_position := Vector3(1.0, 2.0, 3.0).normalized() \
		* BODY_RADIUS_M
	var diagonal := policy.sample(diagonal_position)
	var diagonal_basis := diagonal.tangent_basis_body_local as Basis
	var diagonal_up := diagonal.radial_up as Vector3
	_check(
		bool(diagonal.accepted)
			and diagonal_basis.is_orthonormal()
			and diagonal_basis.y.is_equal_approx(diagonal_up)
			and is_zero_approx(
				(diagonal.tangent_north as Vector3).dot(diagonal_up)
			)
			and is_equal_approx(
				(diagonal.gravity_vector_mps2 as Vector3).dot(diagonal_up),
				-float(diagonal.gravity_magnitude_mps2)
			),
		"arbitrary finite positions retain orthonormal tangent hints and exactly inward gravity"
	)
	var north_pole := policy.sample(Vector3.FORWARD * BODY_RADIUS_M)
	var pole_basis := north_pole.tangent_basis_body_local as Basis
	_check(
		bool(north_pole.accepted)
			and bool(north_pole.tangent_fallback_used)
			and pole_basis.is_orthonormal()
			and pole_basis.determinant() > 0.0
			and pole_basis.y.is_equal_approx(Vector3.FORWARD),
		"a north-seed pole uses the declared deterministic fallback without losing orientation"
	)


func _test_invalid_sample_boundaries_and_purity() -> void:
	var policy := _policy()
	_check(
		policy.sample(Vector3(NAN, 0.0, 0.0)).reason
			== &"nonfinite_body_local_position"
			and policy.sample(Vector3(0.0, INF, 0.0)).reason
				== &"nonfinite_body_local_position",
		"NaN and infinity reject before any radial or gravity output is produced"
	)
	_check(
		policy.sample(Vector3.ZERO).reason
			== &"radial_up_undefined_at_center"
			and policy.sample(
				Vector3.UP * PolicyScript.CENTER_BOUNDARY_RADIUS_METERS
			).reason == &"radial_up_undefined_at_center",
		"the exact centre boundary rejects because radial up is undefined"
	)
	_check(
		policy.sample(
			Vector3.UP * (MINIMUM_SURFACE_RADIUS_M - 1.0)
		).reason == &"below_minimum_surface_shell"
			and policy.sample(
				Vector3.UP * (PolicyScript.CENTER_BOUNDARY_RADIUS_METERS * 2.0)
			).reason == &"below_minimum_surface_shell",
		"positive radii below the minimum shell reject without inventing an interior model"
	)
	var at_maximum_domain := policy.sample(
		Vector3.UP * PolicyScript.MAX_SAMPLE_RADIUS_METERS
	)
	_check(
		bool(at_maximum_domain.accepted)
			and is_finite(float(at_maximum_domain.gravity_magnitude_mps2))
			and float(at_maximum_domain.gravity_magnitude_mps2) > 0.0
			and policy.sample(
				Vector3.UP * (PolicyScript.MAX_SAMPLE_RADIUS_METERS + 1024.0)
			).reason == &"body_local_position_out_of_bounds",
		"the maximum finite body-local sample radius is inclusive and the next representable probe fails closed"
	)
	var before := policy.get_snapshot()
	var first := policy.sample(Vector3(10.0, BODY_RADIUS_M, 20.0))
	var second := policy.sample(Vector3(10.0, BODY_RADIUS_M, 20.0))
	_check(
		first == second and policy.get_snapshot() == before,
		"identical explicit samples are deterministic, delta-free, and state-free"
	)


func _test_detachment_authority_and_structured_red() -> void:
	var policy := _policy()
	var sample := policy.sample(Vector3.UP * BODY_RADIUS_M)
	(sample.shell as Dictionary)["state"] = &"tampered"
	sample["gravity_magnitude_mps2"] = -1.0
	var fresh_sample := policy.sample(Vector3.UP * BODY_RADIUS_M)
	_check(
		fresh_sample.gravity_magnitude_mps2 == REFERENCE_GRAVITY_MPS2
			and (fresh_sample.shell as Dictionary).state
				== &"sea_level_boundary",
		"sample dictionaries and nested shell hints are deeply detached"
	)
	var frozen := policy.get_snapshot()
	var audit := policy.audit()
	((frozen.source_evidence as Dictionary).terrain as Dictionary)["status"] \
		= &"tampered"
	(audit.authority as Dictionary)["physics"] = true
	(audit.adjacent_authority as Dictionary)["landing_decision"] = true
	var fresh_audit := policy.audit()
	_check(
		bool(fresh_audit.valid)
			and not bool((fresh_audit.authority as Dictionary).physics)
			and not bool(
				(fresh_audit.adjacent_authority as Dictionary).landing_decision
			)
			and ((policy.get_snapshot().source_evidence as Dictionary).terrain
				as Dictionary).status == &"modern_interpretation",
		"snapshots, source evidence, audits, and authority rosters are deeply detached"
	)
	var authority := policy.get_authority_report()
	_check(
		_has_exact_false_keys(authority, COMMON_AUTHORITY_KEYS),
		"the policy publishes the exact common 12-key all-false authority roster"
	)
	var adjacent := fresh_audit.adjacent_authority as Dictionary
	_check(
		_has_exact_false_keys(adjacent, ADJACENT_AUTHORITY_KEYS)
			and not bool(fresh_audit.purity.delta_input)
			and not bool(fresh_audit.purity.clock_input)
			and not bool(fresh_audit.purity.retains_source_objects),
		"adjacent movement, physics, collision, rebase, landing, renderer, clock, streaming, persistence, and network authority remain false"
	)
	var corrupted := _policy()
	corrupted.set("_reference_surface_gravity_mps2", NAN)
	_check(
		not bool(corrupted.audit().valid)
			and corrupted.sample(Vector3.UP * BODY_RADIUS_M).reason
				== &"sample_out_of_bounds"
			and bool(_policy().audit().valid),
		"an adversarial frozen-coefficient mutation fails audit and sampling without contaminating another policy"
	)


func _policy() -> PlanetarySurfaceGravityPolicy:
	var policy := PolicyScript.new() as PlanetarySurfaceGravityPolicy
	var result := policy.configure(
		_world(), _terrain(), _frame(BODY_RADIUS_M), REFERENCE_GRAVITY_MPS2
	)
	if not bool(result.accepted):
		_failures.append("fixture policy failed to configure: %s" % result.reason)
	return policy


func _world() -> PlanetaryWorldDefinition:
	var world := WorldScript.new() as PlanetaryWorldDefinition
	world.world_id = &"vertical_slice_world"
	world.display_name = "Vertical Slice World"
	world.sector_id = &"planetary_test_sector"
	world.content_note = "Invented gravity-policy fixture; no real destination is claimed."
	world.scene_path = "res://scenes/world/planets/vertical_slice_world.tscn"
	world.scene_anchor_id = &"vertical_slice_scene"
	world.scene_anchor = Transform3D.IDENTITY
	world.navigation_anchor_id = &"vertical_slice_navigation"
	world.navigation_anchor = Transform3D(
		Basis.IDENTITY, Vector3(0.0, 130_000.0, 0.0)
	)
	world.orbital_anchor_id = &"vertical_slice_orbit"
	world.orbital_anchor = Transform3D(
		Basis.IDENTITY, Vector3(0.0, 140_000.0, 0.0)
	)
	world.surface_anchor_id = &"vertical_slice_surface"
	world.surface_anchor = Transform3D(
		Basis.IDENTITY, Vector3(0.0, BODY_RADIUS_M, 0.0)
	)
	world.body_radius_metres = BODY_RADIUS_M
	world.has_atmosphere = false
	world.atmosphere_definition_id = &""
	world.terrain_definition_id = &"default_planetary_terrain"
	world.landing_region_ids = PackedStringArray([
		"vertical_slice_landing_region",
	])
	world.evidence_status = WorldScript.EvidenceStatus.MODERN_INTERPRETATION
	world.evidence_notes = "Invented gravity-policy fixture."
	return world


func _terrain() -> PlanetaryTerrainProfile:
	var terrain := TerrainScript.new() as PlanetaryTerrainProfile
	terrain.evidence_notes = "Invented gravity-policy fixture."
	return terrain


func _frame(radius_meters: float) -> PlanetaryCoordinateFrame:
	var frame := FrameScript.new() as PlanetaryCoordinateFrame
	var body_coordinate := _orbital_coordinate(&"vertical_slice_system")
	var origin_coordinate := _orbital_coordinate(&"vertical_slice_system")
	var configured := frame.configure(
		&"vertical_slice_body",
		radius_meters,
		&"vertical_slice_system",
		10_000.0,
		body_coordinate,
		Vector3.UP,
		Vector3.FORWARD,
		5_000.0,
		origin_coordinate
	)
	if not bool(configured.accepted):
		_failures.append("fixture frame failed to configure: %s" % configured.reason)
	return frame


func _orbital_coordinate(frame_id: StringName) -> Dictionary:
	return {
		"schema_version": FrameScript.COORDINATE_SCHEMA_VERSION,
		"frame_id": frame_id,
		"cell_x": 0,
		"cell_y": 0,
		"cell_z": 0,
		"offset_meters": Vector3.ZERO,
	}


func _has_exact_false_keys(candidate: Dictionary, expected: Array) -> bool:
	if candidate.size() != expected.size():
		return false
	for key in expected:
		if not candidate.has(key) or not candidate[key] is bool \
			or bool(candidate[key]):
			return false
	return true


func _check(condition: bool, message: String) -> void:
	_assertions += 1
	if condition:
		print("PASS: %s" % message)
	else:
		_failures.append(message)
		push_error("FAIL: %s" % message)


func _finish() -> void:
	if _assertions != EXPECTED_ASSERTIONS:
		_failures.append(
			"expected %d assertions, ran %d"
			% [EXPECTED_ASSERTIONS, _assertions]
		)
	if _failures.is_empty():
		print(
			"PLANETARY_SURFACE_GRAVITY_POLICY_TEST_OK: %d assertions"
			% _assertions
		)
		quit(0)
	else:
		print(
			"PLANETARY_SURFACE_GRAVITY_POLICY_TEST_FAILED: %s"
			% "; ".join(_failures)
		)
		quit(1)
