extends SceneTree

const DefinitionScript := preload(
	"res://scripts/world/definitions/planetary_world_definition.gd"
)

var _assertions := 0
var _failures := PackedStringArray()


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_test_valid_definition_and_authority_boundary()
	_test_identity_scene_and_reference_validation()
	_test_finite_coordinate_and_radius_bounds()
	_test_evidence_validation()
	_test_deep_copy_and_deterministic_audit()
	await _test_resource_round_trip()
	_finish()


func _test_valid_definition_and_authority_boundary() -> void:
	var definition := _valid_definition()
	var audit := definition.audit()
	_check(definition.is_definition_valid(), "a complete planetary definition validates")
	_check(
		int(audit.schema_version) == DefinitionScript.SCHEMA_VERSION
		and audit.world_id == &"ember_moon"
		and audit.scene_path == "res://scenes/world/planets/ember_moon.tscn",
		"audit publishes stable schema, world identity, and scene reference"
	)
	var anchors := audit.anchors as Dictionary
	_check(
		(anchors.scene as Dictionary).anchor_id == &"ember_scene_origin"
		and (anchors.navigation as Dictionary).anchor_id == &"ember_navigation"
		and (anchors.orbital as Dictionary).anchor_id == &"ember_orbit_entry"
		and (anchors.surface as Dictionary).anchor_id == &"ember_surface_entry",
		"scene, navigation, orbital, and surface frames retain distinct stable IDs"
	)
	_check(
		definition.get_scene_anchor().is_equal_approx(definition.scene_anchor)
		and definition.get_navigation_anchor().is_equal_approx(
			definition.navigation_anchor
		)
		and definition.get_orbital_anchor().is_equal_approx(
			definition.orbital_anchor
		)
		and definition.get_surface_anchor().is_equal_approx(
			definition.surface_anchor
		),
		"typed anchor getters preserve full transforms"
	)
	var body := audit.body as Dictionary
	_check(
		is_equal_approx(float(body.radius_metres), 1800.0)
		and bool(body.has_atmosphere)
		and body.atmosphere_definition_id == &"ember_thin_atmosphere"
		and body.terrain_definition_id == &"ember_basalt_terrain"
		and body.landing_region_ids == PackedStringArray([
			"ember_caldera",
			"ember_north_ridge",
		]),
		"body scale and atmosphere, terrain, and landing-region references are explicit"
	)
	var evidence := audit.evidence as Dictionary
	var authority := audit.authority as Dictionary
	_check(
		evidence.status == &"modern_interpretation"
		and not bool(evidence.historical_claim)
		and not bool(evidence.authenticated),
		"modern planetary content cannot imply a historical claim"
	)
	_check(
		not bool(audit.gameplay_authority)
		and not bool(audit.streaming_authority)
		and not bool(audit.save_authority)
		and authority == {
			"gameplay": false,
			"streaming": false,
			"save": false,
		},
		"resource explicitly owns zero gameplay, streaming, or save authority"
	)


func _test_identity_scene_and_reference_validation() -> void:
	var canonical := _valid_definition()
	for invalid_id in [
		"", "9world", "World", "world id", "world-id", "_world", "world_", "world__id",
	]:
		var invalid := canonical.duplicate_definition()
		invalid.world_id = StringName(invalid_id)
		_check(
			not invalid.is_definition_valid(),
			"invalid stable world ID is rejected: '%s'" % invalid_id
		)
	var oversized_id := canonical.duplicate_definition()
	oversized_id.world_id = StringName("w".repeat(DefinitionScript.MAX_ID_LENGTH + 1))
	_check(
		not oversized_id.is_definition_valid(),
		"stable IDs reject the first character beyond the 64-character limit"
	)
	var invalid_sector := canonical.duplicate_definition()
	invalid_sector.sector_id = &"Nearby_Sector"
	_check(
		_has_error(invalid_sector.get_validation_errors(), "sector_id"),
		"sector identity uses the same stable ID grammar"
	)
	var padded_name := canonical.duplicate_definition()
	padded_name.display_name = " Ember Moon"
	_check(
		_has_error(padded_name.get_validation_errors(), "display_name"),
		"padded display copy is rejected"
	)
	var long_note := canonical.duplicate_definition()
	long_note.content_note = "n".repeat(DefinitionScript.MAX_CONTENT_NOTE_LENGTH + 1)
	_check(
		_has_error(long_note.get_validation_errors(), "content_note"),
		"content notes have an exact bounded length"
	)
	for invalid_path in [
		"", "user://ember.tscn", " res://ember.tscn", "res://../ember.tscn",
		"res://ember.scn", "res:\\ember.tscn", "res://ember.tscn\n",
	]:
		var invalid_scene := canonical.duplicate_definition()
		invalid_scene.scene_path = invalid_path
		_check(
			_has_error(invalid_scene.get_validation_errors(), "scene_path"),
			"invalid scene reference is rejected: '%s'" % invalid_path.c_escape()
		)
	var duplicate_anchor := canonical.duplicate_definition()
	duplicate_anchor.surface_anchor_id = duplicate_anchor.orbital_anchor_id
	_check(
		_has_error(duplicate_anchor.get_validation_errors(), "duplicates another anchor"),
		"anchor identities must be unique within a world definition"
	)
	var invalid_anchor_id := canonical.duplicate_definition()
	invalid_anchor_id.navigation_anchor_id = &"Bad_Anchor"
	_check(
		_has_error(invalid_anchor_id.get_validation_errors(), "navigation_anchor_id"),
		"anchor identities use the stable ID grammar"
	)
	var missing_terrain := canonical.duplicate_definition()
	missing_terrain.terrain_definition_id = &""
	_check(
		_has_error(missing_terrain.get_validation_errors(), "terrain_definition_id"),
		"terrain requires a stable catalog reference"
	)
	var no_regions := canonical.duplicate_definition()
	no_regions.landing_region_ids = PackedStringArray()
	_check(
		_has_error(no_regions.get_validation_errors(), "landing_region_ids"),
		"at least one authored landing region is required"
	)
	var duplicate_region := canonical.duplicate_definition()
	duplicate_region.landing_region_ids = PackedStringArray([
		"ember_caldera", "ember_caldera",
	])
	_check(
		_has_error(duplicate_region.get_validation_errors(), "duplicated"),
		"duplicate landing-region references are rejected"
	)
	var invalid_region := canonical.duplicate_definition()
	invalid_region.landing_region_ids = PackedStringArray(["Bad-Region"])
	_check(
		_has_error(invalid_region.get_validation_errors(), "landing region reference"),
		"landing-region references use the stable ID grammar"
	)
	var too_many_regions := canonical.duplicate_definition()
	var oversized_regions := PackedStringArray()
	for index in DefinitionScript.MAX_LANDING_REGION_REFERENCES + 1:
		oversized_regions.append("landing_region_%02d" % index)
	too_many_regions.landing_region_ids = oversized_regions
	_check(
		_has_error(too_many_regions.get_validation_errors(), "1 to 32"),
		"landing-region reference count is exactly bounded"
	)
	var airless_with_profile := canonical.duplicate_definition()
	airless_with_profile.has_atmosphere = false
	_check(
		_has_error(
			airless_with_profile.get_validation_errors(),
			"must not declare atmosphere_definition_id"
		),
		"airless bodies cannot retain a misleading atmosphere reference"
	)
	var atmospheric_without_profile := canonical.duplicate_definition()
	atmospheric_without_profile.atmosphere_definition_id = &""
	_check(
		_has_error(
			atmospheric_without_profile.get_validation_errors(),
			"atmosphere_definition_id"
		),
		"atmospheric bodies require a stable atmosphere reference"
	)


func _test_finite_coordinate_and_radius_bounds() -> void:
	var canonical := _valid_definition()
	var minimum_radius := canonical.duplicate_definition()
	minimum_radius.body_radius_metres = DefinitionScript.MIN_BODY_RADIUS_METRES
	var maximum_radius := canonical.duplicate_definition()
	maximum_radius.body_radius_metres = DefinitionScript.MAX_BODY_RADIUS_METRES
	_check(
		minimum_radius.is_definition_valid() and maximum_radius.is_definition_valid(),
		"exact minimum and maximum body-radius endpoints validate"
	)
	for radius in [
		NAN,
		INF,
		DefinitionScript.MIN_BODY_RADIUS_METRES - 0.01,
		DefinitionScript.MAX_BODY_RADIUS_METRES + 1.0,
	]:
		var invalid_radius := canonical.duplicate_definition()
		invalid_radius.body_radius_metres = radius
		_check(
			_has_error(invalid_radius.get_validation_errors(), "body_radius_metres"),
			"non-finite or out-of-range body radius is rejected"
		)
	var nonfinite := canonical.duplicate_definition()
	nonfinite.orbital_anchor.origin.x = NAN
	_check(
		_has_error(nonfinite.get_validation_errors(), "only finite values"),
		"non-finite anchor components are rejected"
	)
	var unbounded := canonical.duplicate_definition()
	var unbounded_anchor := unbounded.navigation_anchor
	unbounded_anchor.origin.z = DefinitionScript.MAX_ANCHOR_COMPONENT_METRES + 1024.0
	unbounded.navigation_anchor = unbounded_anchor
	_check(
		_has_error(unbounded.get_validation_errors(), "must not exceed"),
		"finite but out-of-bound anchor components are rejected"
	)
	var scaled := canonical.duplicate_definition()
	scaled.surface_anchor.basis = Basis.from_scale(Vector3(1.0, 2.0, 1.0))
	_check(
		_has_error(scaled.get_validation_errors(), "unit-scale and orthonormal"),
		"scaled coordinate frames are rejected"
	)
	var skewed := canonical.duplicate_definition()
	skewed.scene_anchor.basis = Basis(
		Vector3.RIGHT,
		Vector3(0.25, 1.0, 0.0),
		Vector3.BACK
	)
	_check(
		_has_error(skewed.get_validation_errors(), "unit-scale and orthonormal"),
		"skewed coordinate frames are rejected"
	)
	var reflected := canonical.duplicate_definition()
	reflected.scene_anchor.basis = Basis(
		Vector3.LEFT,
		Vector3.UP,
		Vector3.BACK
	)
	_check(
		_has_error(reflected.get_validation_errors(), "unit-scale and orthonormal"),
		"reflected coordinate frames are rejected to preserve Godot handedness"
	)


func _test_evidence_validation() -> void:
	var canonical := _valid_definition()
	var authenticated := canonical.duplicate_definition()
	authenticated.evidence_status = DefinitionScript.EvidenceStatus.AUTHENTICATED
	authenticated.evidence_references = PackedStringArray(["LEDGER-P1@00:30"])
	authenticated.evidence_notes = "Manual planetary-evidence fixture."
	var authenticated_audit := authenticated.audit()
	_check(
		authenticated.is_definition_valid()
		and authenticated.get_evidence_status_id() == &"authenticated"
		and bool((authenticated_audit.evidence as Dictionary).manual_review_required)
		and not (authenticated_audit.warnings as PackedStringArray).is_empty(),
		"authenticated evidence remains explicit and requires manual review"
	)
	for historical_status in [
		DefinitionScript.EvidenceStatus.AUTHENTICATED,
		DefinitionScript.EvidenceStatus.BOUNDED_PARTIAL_RECONSTRUCTION,
		DefinitionScript.EvidenceStatus.PROVISIONAL_CANDIDATE,
	]:
		var unsourced := canonical.duplicate_definition()
		unsourced.evidence_status = historical_status
		unsourced.evidence_references = PackedStringArray()
		unsourced.evidence_notes = "Historical claim without a source."
		_check(
			_has_error(unsourced.get_validation_errors(), "require at least one"),
			"historical evidence status %d cannot omit source references" % historical_status
		)
	var invalid_status := canonical.duplicate_definition()
	invalid_status.evidence_status = 99
	_check(
		invalid_status.get_evidence_status_id() == &"invalid"
		and _has_error(invalid_status.get_validation_errors(), "outside the supported enum"),
		"invalid evidence enum has no fallback"
	)
	var duplicate_reference := canonical.duplicate_definition()
	duplicate_reference.evidence_references = PackedStringArray(["A1", "A1"])
	_check(
		_has_error(duplicate_reference.get_validation_errors(), "duplicated"),
		"duplicate evidence references are rejected"
	)
	var padded_reference := canonical.duplicate_definition()
	padded_reference.evidence_references = PackedStringArray([" A1"])
	_check(
		_has_error(padded_reference.get_validation_errors(), "trimmed single-line"),
		"evidence references cannot be padded or multiline"
	)
	var overlong_reference := canonical.duplicate_definition()
	overlong_reference.evidence_references = PackedStringArray([
		"r".repeat(DefinitionScript.MAX_EVIDENCE_REFERENCE_LENGTH + 1),
	])
	_check(
		_has_error(overlong_reference.get_validation_errors(), "at most 192"),
		"evidence-reference text rejects the first character beyond its limit"
	)
	var too_many_references := canonical.duplicate_definition()
	var oversized_references := PackedStringArray()
	for index in DefinitionScript.MAX_EVIDENCE_REFERENCES + 1:
		oversized_references.append("SOURCE-%02d" % index)
	too_many_references.evidence_references = oversized_references
	_check(
		_has_error(too_many_references.get_validation_errors(), "at most 32 entries"),
		"evidence-reference count is exactly bounded"
	)


func _test_deep_copy_and_deterministic_audit() -> void:
	var definition := _valid_definition()
	var baseline := definition.get_audit_report()
	var repeated := definition.get_audit_report()
	_check(baseline == repeated, "unchanged definitions produce deterministic audit dictionaries")
	((baseline.anchors as Dictionary).orbital as Dictionary)["anchor_id"] = &"mutated"
	(baseline.body as Dictionary)["landing_region_ids"] = PackedStringArray(["mutated"])
	(baseline.evidence as Dictionary)["references"] = PackedStringArray(["mutated"])
	(baseline.authority as Dictionary)["streaming"] = true
	var after_mutation := definition.get_audit_report()
	_check(
		((after_mutation.anchors as Dictionary).orbital as Dictionary).anchor_id
		== &"ember_orbit_entry"
		and (after_mutation.body as Dictionary).landing_region_ids
		== PackedStringArray(["ember_caldera", "ember_north_ridge"])
		and (after_mutation.evidence as Dictionary).references
		== PackedStringArray(["PLANETARY-VERTICAL-SLICE"])
		and not bool((after_mutation.authority as Dictionary).streaming),
		"mutating nested audit data cannot alter retained definition state"
	)
	var returned_regions := definition.get_landing_region_ids()
	returned_regions[0] = "mutated"
	_check(
		definition.landing_region_ids[0] == "ember_caldera",
		"landing-region getter returns detached packed data"
	)
	var copy := definition.duplicate_definition()
	copy.world_id = &"copy_world"
	var copy_orbital_anchor := copy.orbital_anchor
	copy_orbital_anchor.origin += Vector3.ONE
	copy.orbital_anchor = copy_orbital_anchor
	copy.landing_region_ids[0] = "copy_region"
	copy.evidence_references[0] = "COPY-SOURCE"
	_check(
		copy.orbital_anchor.origin == Vector3(1.0, 1.0, 3601.0)
		and definition.world_id == &"ember_moon"
		and definition.orbital_anchor.origin == Vector3(0.0, 0.0, 3600.0)
		and definition.landing_region_ids[0] == "ember_caldera"
		and definition.evidence_references[0] == "PLANETARY-VERTICAL-SLICE",
		"typed duplicate_definition deeply detaches mutable packed references"
	)


func _test_resource_round_trip() -> void:
	var definition := _valid_definition()
	var resource_path := "user://planetary_world_definition_test_%d.tres" % Time.get_ticks_usec()
	var absolute_path := ProjectSettings.globalize_path(resource_path)
	var save_error := ResourceSaver.save(definition, resource_path)
	_check(save_error == OK, "PlanetaryWorldDefinition saves as a normal Resource")
	var loaded := ResourceLoader.load(
		resource_path,
		"",
		ResourceLoader.CACHE_MODE_IGNORE
	) as PlanetaryWorldDefinition
	_check(loaded != null, "saved planetary definition reloads with its typed class")
	if loaded != null:
		_check(
			loaded.is_definition_valid()
			and loaded.world_id == definition.world_id
			and loaded.orbital_anchor.is_equal_approx(definition.orbital_anchor)
			and loaded.landing_region_ids == definition.landing_region_ids,
			"resource round trip preserves identity, frame, and logical references"
		)
		_check(
			not bool(loaded.audit().save_authority),
			"serializability does not grant save authority"
		)
	if FileAccess.file_exists(resource_path):
		var remove_error := DirAccess.remove_absolute(absolute_path)
		_check(remove_error == OK, "temporary planetary definition resource is removed")


func _valid_definition() -> PlanetaryWorldDefinition:
	var definition := DefinitionScript.new() as PlanetaryWorldDefinition
	definition.world_id = &"ember_moon"
	definition.display_name = "Ember Moon"
	definition.sector_id = &"nearby_sector"
	definition.content_note = "Typed Phase 10 contract fixture; no production world is claimed."
	definition.scene_path = "res://scenes/world/planets/ember_moon.tscn"
	definition.scene_anchor_id = &"ember_scene_origin"
	definition.scene_anchor = Transform3D.IDENTITY
	definition.navigation_anchor_id = &"ember_navigation"
	definition.navigation_anchor = Transform3D(
		Basis(Vector3.UP, deg_to_rad(15.0)),
		Vector3(0.0, 0.0, 3400.0)
	)
	definition.orbital_anchor_id = &"ember_orbit_entry"
	definition.orbital_anchor = Transform3D(
		Basis(Vector3.UP, deg_to_rad(30.0)),
		Vector3(0.0, 0.0, 3600.0)
	)
	definition.surface_anchor_id = &"ember_surface_entry"
	definition.surface_anchor = Transform3D(
		Basis(Vector3.UP, deg_to_rad(-20.0)),
		Vector3(0.0, 1800.0, 0.0)
	)
	definition.body_radius_metres = 1800.0
	definition.has_atmosphere = true
	definition.atmosphere_definition_id = &"ember_thin_atmosphere"
	definition.terrain_definition_id = &"ember_basalt_terrain"
	definition.landing_region_ids = PackedStringArray([
		"ember_caldera",
		"ember_north_ridge",
	])
	definition.evidence_status = DefinitionScript.EvidenceStatus.MODERN_INTERPRETATION
	definition.evidence_references = PackedStringArray(["PLANETARY-VERTICAL-SLICE"])
	definition.evidence_notes = "Invented fixture used only to exercise the schema."
	return definition


func _has_error(errors: PackedStringArray, fragment: String) -> bool:
	for error in errors:
		if String(error).contains(fragment):
			return true
	return false


func _check(condition: bool, description: String) -> bool:
	_assertions += 1
	if condition:
		print("PASS: ", description)
	else:
		_failures.append(description)
		push_error("FAIL: " + description)
	return condition


func _finish() -> void:
	if _failures.is_empty():
		print("PLANETARY_WORLD_DEFINITION_TEST_OK: %d assertions" % _assertions)
		quit(0)
	else:
		print(
			"PLANETARY_WORLD_DEFINITION_TEST_FAILED: ",
			", ".join(_failures)
		)
		quit(1)
