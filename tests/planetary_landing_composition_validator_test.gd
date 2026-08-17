extends SceneTree

const ValidatorScript := preload("res://scripts/world/planetary_landing_composition_validator.gd")
const CoordinateFrameScript := preload("res://scripts/world/planetary_coordinate_frame.gd")
const WorldScript := preload("res://scripts/world/definitions/planetary_world_definition.gd")
const TerrainScript := preload("res://scripts/world/planetary_terrain_profile.gd")
const RegionScript := preload("res://scripts/world/definitions/planetary_landing_region_definition.gd")

const BODY_ID: StringName = &"vertical_slice_body"
const ORBITAL_FRAME_ID: StringName = &"vertical_slice_system"
const REGION_ID: StringName = &"vertical_slice_landing_region"
const WORLD_ID: StringName = &"vertical_slice_world"
const BODY_RADIUS_M := 120_000.0
const CELL_SIZE_M := 10_000.0
const SHIFT_THRESHOLD_M := 5_000.0
const HUGE_X := CoordinateFrameScript.MAX_SAFE_INTEGER - 100
const HUGE_Y := -CoordinateFrameScript.MAX_SAFE_INTEGER + 100

const COMMON_AUTHORITY_KEYS := [
	"renderer", "gameplay", "streaming", "save", "network", "physics",
	"world_generation", "terrain_generation", "collision_generation",
	"origin_shift", "weather_clock", "audio",
]

var _assertions := 0
var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_test_valid_join_detachment_and_authority()
	_test_identity_and_datum_mismatches()
	_test_invalid_inputs_and_radial_basis()
	_test_body_local_orbital_world_rebase_invariant()
	_finish()


func _test_valid_join_detachment_and_authority() -> void:
	var validator := ValidatorScript.new() as PlanetaryLandingCompositionValidator
	var frame := _coordinate_frame()
	var report := validator.validate_composition(
		_world(), _terrain(), frame.get_snapshot(), _region()
	)
	_check(
		report.valid and (report.errors as Array).is_empty()
			and report.radius_datum == &"body_center_to_sea_level"
			and report.frame_seam == &"landing_region_via_planetary_body_local"
			and report.world_id == WORLD_ID and report.body_id == BODY_ID
			and report.region_id == REGION_ID
			and int(report.coordinate_frame_generation) == 1,
		"the canonical landing region joins the exact world, terrain, and configured body frame",
	)
	var authority := report.authority as Dictionary
	var all_zero := _has_exact_keys(authority, COMMON_AUTHORITY_KEYS)
	for key in COMMON_AUTHORITY_KEYS:
		all_zero = all_zero and authority[key] is bool and not bool(authority[key])
	_check(all_zero, "the landing join publishes the exact common 12-key zero-authority roster")
	(report.errors as Array).append({"code": &"tampered"})
	(report.evidence as Dictionary)["landing_region"] = {"status": &"tampered"}
	(report.authority as Dictionary)["physics"] = true
	var fresh := validator.audit(_world(), _terrain(), frame.get_snapshot(), _region())
	_check(
		fresh.valid and (fresh.errors as Array).is_empty()
			and ((fresh.evidence as Dictionary).landing_region as Dictionary).status == &"modern_interpretation"
			and not bool((fresh.authority as Dictionary).physics),
		"results, evidence, errors, and authority are deeply detached",
	)


func _test_identity_and_datum_mismatches() -> void:
	var validator := ValidatorScript.new() as PlanetaryLandingCompositionValidator
	var frame_snapshot := _coordinate_frame().get_snapshot()
	var wrong_world := _region()
	wrong_world.world_id = &"foreign_world"
	_check(_has_code(validator.validate_composition(_world(), _terrain(), frame_snapshot, wrong_world), &"landing_world_id_mismatch"), "foreign landing world identity fails with a structured code")
	var unreferenced_world := _world()
	unreferenced_world.landing_region_ids = PackedStringArray(["other_region"])
	_check(_has_code(validator.validate_composition(unreferenced_world, _terrain(), frame_snapshot, _region()), &"landing_region_not_referenced"), "world landing roster must contain the resolved region ID")
	var wrong_body := _region()
	wrong_body.body_id = &"foreign_body"
	_check(_has_code(validator.validate_composition(_world(), _terrain(), frame_snapshot, wrong_body), &"landing_body_id_mismatch"), "landing body identity must equal the configured coordinate-frame body")
	var wrong_terrain_id := _terrain()
	wrong_terrain_id.profile_id = &"foreign_terrain"
	_check(_has_code(validator.validate_composition(_world(), wrong_terrain_id, frame_snapshot, _region()), &"landing_terrain_profile_id_mismatch"), "world terrain identity must equal the resolved terrain profile")

	var wrong_radius := _region()
	wrong_radius.body_radius_m += 1.0
	wrong_radius.body_local_center_m = Vector3(0.0, BODY_RADIUS_M + 1.0, 0.0)
	_check(_has_code(validator.validate_composition(_world(), _terrain(), frame_snapshot, wrong_radius), &"landing_body_radius_mismatch"), "landing sea-level radius equality is exact")
	var wrong_minimum := _region()
	wrong_minimum.minimum_elevation_m += 1.0
	_check(_has_code(validator.validate_composition(_world(), _terrain(), frame_snapshot, wrong_minimum), &"landing_minimum_elevation_mismatch"), "landing and terrain minimum elevation equality is exact")
	var wrong_maximum := _region()
	wrong_maximum.maximum_elevation_m -= 1.0
	_check(_has_code(validator.validate_composition(_world(), _terrain(), frame_snapshot, wrong_maximum), &"landing_maximum_elevation_mismatch"), "landing and terrain maximum elevation equality is exact")
	var wrong_frame := _coordinate_frame(BODY_RADIUS_M + 1.0)
	_check(_has_code(validator.validate_composition(_world(), _terrain(), wrong_frame.get_snapshot(), _region()), &"landing_body_radius_mismatch"), "coordinate-frame radius must share the exact composed datum")


func _test_invalid_inputs_and_radial_basis() -> void:
	var validator := ValidatorScript.new() as PlanetaryLandingCompositionValidator
	var world := _world()
	var terrain := _terrain()
	var snapshot := _coordinate_frame().get_snapshot()
	var region := _region()
	_check(_has_code(validator.validate_composition(null, terrain, snapshot, region), &"missing_world_definition"), "missing world input fails closed")
	_check(_has_code(validator.validate_composition(world, null, snapshot, region), &"missing_terrain_profile"), "missing terrain input fails closed")
	_check(_has_code(validator.validate_composition(world, terrain, snapshot, null), &"missing_landing_region"), "missing landing input fails closed")
	_check(_has_code(validator.validate_composition(world, terrain, {}, region), &"missing_coordinate_frame_snapshot"), "missing frame snapshot fails closed")
	var unconfigured_snapshot := snapshot.duplicate(true)
	unconfigured_snapshot["configured"] = false
	_check(_has_code(validator.validate_composition(world, terrain, unconfigured_snapshot, region), &"invalid_coordinate_frame_snapshot"), "an unconfigured coordinate-frame snapshot fails closed")
	var extra_snapshot := snapshot.duplicate(true)
	extra_snapshot["authority"] = true
	_check(_has_code(validator.validate_composition(world, terrain, extra_snapshot, region), &"invalid_coordinate_frame_snapshot"), "the frame snapshot schema rejects extra fields")
	var malformed_coordinate := snapshot.duplicate(true)
	(malformed_coordinate.body_center_orbital_coordinate as Dictionary)["offset_meters"] = Vector3(CELL_SIZE_M * 0.5, 0.0, 0.0)
	_check(_has_code(validator.validate_composition(world, terrain, malformed_coordinate, region), &"invalid_coordinate_frame_snapshot"), "noncanonical orbital data cannot forge a configured frame snapshot")
	var sideways := _region()
	sideways.body_local_basis = Basis(Vector3.FORWARD, Vector3.RIGHT, Vector3.UP)
	var sideways_report := validator.validate_composition(world, terrain, snapshot, sideways)
	_check(
		_has_code(sideways_report, &"invalid_landing_region")
			and _has_code(sideways_report, &"landing_basis_not_radially_outward"),
		"a sideways region normal fails both its source contract and the defensive join code",
	)


func _test_body_local_orbital_world_rebase_invariant() -> void:
	var frame := _coordinate_frame()
	var region := _region()
	region.body_local_basis = Basis(Vector3.UP, deg_to_rad(37.0))
	var validator := ValidatorScript.new() as PlanetaryLandingCompositionValidator
	_check(validator.validate_composition(_world(), _terrain(), frame.get_snapshot(), region).valid, "arbitrary tangent yaw composes while radial +Y remains outward")
	var region_local := Vector3(0.125, 15.0, 0.25)
	var body_local := region.body_local_center_m + region.body_local_basis * region_local
	var generation := frame.get_generation()
	var absolute_before := frame.body_local_to_orbital_position(body_local, generation)
	var world_before_result := frame.orbital_to_world_streaming_position(
		absolute_before.coordinate, generation
	)
	var world_before := world_before_result.position as Vector3
	var tangent := frame.body_local_to_surface_tangent(body_local, generation)
	_check(
		absolute_before.accepted and world_before_result.accepted
			and not (tangent.position as Vector3).is_equal_approx(region_local),
		"region-local yaw composes through body-local; it is not silently treated as the frame's single north-aligned tangent patch",
	)
	var request := frame.request_rebase(world_before, generation)
	var committed := frame.commit_rebase(int(request.request.request_id), generation)
	var next_generation := frame.get_generation()
	var absolute_after := frame.body_local_to_orbital_position(body_local, next_generation)
	var world_after := frame.orbital_to_world_streaming_position(
		absolute_after.coordinate, next_generation
	)
	_check(
		request.accepted and committed.accepted
			and absolute_after.coordinate == absolute_before.coordinate
			and (world_after.position as Vector3).is_equal_approx(
				world_before + (committed.rebase.world_translation_delta as Vector3)
			)
			and (world_after.position as Vector3).is_equal_approx(Vector3.ZERO),
		"body-local to absolute orbital identity survives rebase while world-local moves by the committed delta",
	)


func _world() -> PlanetaryWorldDefinition:
	var world := WorldScript.new() as PlanetaryWorldDefinition
	world.world_id = WORLD_ID
	world.display_name = "Vertical Slice World"
	world.sector_id = &"planetary_test_sector"
	world.content_note = "Invented landing composition fixture."
	world.scene_path = "res://scenes/world/planets/vertical_slice_world.tscn"
	world.scene_anchor_id = &"vertical_slice_scene"
	world.scene_anchor = Transform3D.IDENTITY
	world.navigation_anchor_id = &"vertical_slice_navigation"
	world.navigation_anchor = Transform3D(Basis.IDENTITY, Vector3(0.0, 130_000.0, 0.0))
	world.orbital_anchor_id = &"vertical_slice_orbit"
	world.orbital_anchor = Transform3D(Basis.IDENTITY, Vector3(0.0, 140_000.0, 0.0))
	world.surface_anchor_id = &"vertical_slice_surface"
	world.surface_anchor = Transform3D(Basis.IDENTITY, Vector3(0.0, BODY_RADIUS_M, 0.0))
	world.body_radius_metres = BODY_RADIUS_M
	world.has_atmosphere = true
	world.atmosphere_definition_id = &"temperate_game_scale"
	world.terrain_definition_id = &"default_planetary_terrain"
	world.landing_region_ids = PackedStringArray([REGION_ID])
	world.evidence_status = WorldScript.EvidenceStatus.MODERN_INTERPRETATION
	world.evidence_notes = "Invented landing composition fixture."
	return world


func _terrain() -> PlanetaryTerrainProfile:
	return TerrainScript.new() as PlanetaryTerrainProfile


func _region() -> PlanetaryLandingRegionDefinition:
	var region := RegionScript.new() as PlanetaryLandingRegionDefinition
	region.world_id = WORLD_ID
	region.body_id = BODY_ID
	region.region_id = REGION_ID
	return region


func _coordinate_frame(radius: float = BODY_RADIUS_M) -> PlanetaryCoordinateFrame:
	var frame := CoordinateFrameScript.new() as PlanetaryCoordinateFrame
	var configured := frame.configure(
		BODY_ID,
		radius,
		ORBITAL_FRAME_ID,
		CELL_SIZE_M,
		_orbital_coordinate(HUGE_X, HUGE_Y, 12_345, Vector3(0.125, -0.25, 0.5)),
		Vector3.UP,
		Vector3.FORWARD,
		SHIFT_THRESHOLD_M,
		_orbital_coordinate(HUGE_X, HUGE_Y, 12_345, Vector3(0.125, -0.25, 0.5)),
	)
	if not configured.accepted:
		_failures.append("coordinate fixture failed: %s" % configured)
	return frame


func _orbital_coordinate(
		cell_x: int, cell_y: int, cell_z: int, offset: Vector3
	) -> Dictionary:
	return {
		"schema_version": CoordinateFrameScript.COORDINATE_SCHEMA_VERSION,
		"frame_id": ORBITAL_FRAME_ID,
		"cell_x": cell_x,
		"cell_y": cell_y,
		"cell_z": cell_z,
		"offset_meters": offset,
	}


func _has_code(report: Dictionary, code: StringName) -> bool:
	return (report.get("error_codes", PackedStringArray()) as PackedStringArray).has(str(code))


func _has_exact_keys(candidate: Dictionary, expected: Array) -> bool:
	if candidate.size() != expected.size():
		return false
	for key in expected:
		if not candidate.has(key):
			return false
	return true


func _check(condition: bool, description: String) -> void:
	_assertions += 1
	if condition:
		print("PASS: ", description)
	else:
		_failures.append(description)
		push_error("FAIL: %s" % description)


func _finish() -> void:
	print("PLANETARY_LANDING_COMPOSITION_VALIDATOR_TEST_ASSERTIONS: %d" % _assertions)
	if _failures.is_empty():
		print("PLANETARY_LANDING_COMPOSITION_VALIDATOR_TEST_OK")
		quit(0)
		return
	print("PLANETARY_LANDING_COMPOSITION_VALIDATOR_TEST_FAILURES: %s" % _failures)
	quit(1)
