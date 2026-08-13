extends SceneTree

const DefinitionScript := preload("res://scripts/ships/ship_definition.gd")
const BerthScript := preload("res://scripts/world/ship_berth.gd")
const BerthScene := preload("res://scenes/world/components/ship_berth.tscn")

var _failures := PackedStringArray()


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_test_definition_evidence_and_validation()
	_test_definition_profiles_and_detached_audit()
	await _test_definition_resource_round_trip()
	await _test_berth_transform_volume_and_lookup()
	await _test_berth_reservation_and_occupancy()
	_finish()


func _test_definition_evidence_and_validation() -> void:
	var provisional := _definition(
		&"torrent_test_article_01",
		"Torrent-class Interceptor",
		"Interceptor",
		DefinitionScript.EvidenceStatus.PROVISIONAL,
		PackedStringArray(["A3", "B3@05:13"])
	)
	_check(provisional.is_definition_valid(), "a sourced provisional original-ship definition validates")
	var provisional_audit: Dictionary = provisional.audit()
	_check(provisional.get_evidence_status_id() == &"provisional", "provisional evidence has a stable textual ID")
	_check(bool(provisional_audit.historical_claim) and not bool(provisional_audit.authenticated), "provisional is an explicit unauthenticated historical claim")
	_check(provisional_audit.evidence_scope == &"name_to_model", "audit scopes evidence to the name-to-model mapping")

	var authenticated := _definition(
		&"documented_craft",
		"Documented craft",
		"Recon ship",
		DefinitionScript.EvidenceStatus.AUTHENTICATED,
		PackedStringArray(["A3", "B3@06:15"])
	)
	var authenticated_audit: Dictionary = authenticated.audit()
	_check(authenticated.is_definition_valid() and authenticated.is_authenticated(), "authenticated is a distinct valid evidence state")
	_check(authenticated.get_evidence_status_id() == &"authenticated", "authenticated evidence has a stable textual ID")
	_check(bool(authenticated_audit.manual_evidence_review_required), "authenticated audit preserves the manual dossier-review requirement")
	_check(not (authenticated_audit.warnings as PackedStringArray).is_empty(), "authenticated audit warns that evidence and rights review remain manual")

	var new_design := _definition(
		&"kestrel_scout",
		"Kestrel Scout",
		"Scout",
		DefinitionScript.EvidenceStatus.NEW,
		PackedStringArray()
	)
	_check(new_design.is_definition_valid(), "a new design does not require historical references")
	_check(new_design.get_evidence_status_id() == &"new" and not new_design.is_historical_claim(), "new design cannot masquerade as a historical claim")

	var invalid_status := new_design.duplicate() as ShipDefinition
	invalid_status.evidence_status = 99
	_check(invalid_status.get_evidence_status_id() == &"invalid", "invalid evidence enums have no implicit fallback")
	_check(_has_error(invalid_status.get_validation_errors(), "evidence_status"), "invalid evidence enum is reported")

	var unsourced := provisional.duplicate() as ShipDefinition
	unsourced.evidence_references = PackedStringArray()
	_check(not unsourced.is_definition_valid(), "provisional historical claims cannot omit evidence")
	var duplicate_reference := provisional.duplicate() as ShipDefinition
	duplicate_reference.evidence_references = PackedStringArray(["A3", "A3"])
	_check(_has_error(duplicate_reference.get_validation_errors(), "duplicated"), "duplicate evidence references are rejected")
	var padded_reference := provisional.duplicate() as ShipDefinition
	spadded_reference_fix(padded_reference)
	_check(_has_error(padded_reference.get_validation_errors(), "trimmed"), "padded evidence references are rejected rather than silently normalized")

	for invalid_id in ["", "9ship", "Ship", "ship id", "ship-01", "_ship", "ship_", "ship__01"]:
		var bad_id := new_design.duplicate() as ShipDefinition
		bad_id.ship_id = StringName(invalid_id)
		_check(not bad_id.is_definition_valid(), "invalid stable ship ID is rejected: '%s'" % invalid_id)
	var invalid_copy := new_design.duplicate() as ShipDefinition
	invalid_copy.display_name = " Padded name"
	invalid_copy.role_name = "Multi\nline"
	invalid_copy.entry_noun = ""
	_check(invalid_copy.get_validation_errors().size() >= 3, "blank, padded, and multiline UI terminology is rejected")

	var invalid_audio := new_design.duplicate() as ShipDefinition
	invalid_audio.audio_profile_id = &"Standard_Fighter"
	_check(_has_error(invalid_audio.get_validation_errors(), "audio_profile_id"), "audio profile uses the stable ID grammar")
	var duplicate_tag := new_design.duplicate() as ShipDefinition
	duplicate_tag.compatibility_tags = PackedStringArray(["small_craft", "small_craft"])
	_check(_has_error(duplicate_tag.get_validation_errors(), "duplicated"), "duplicate compatibility tags are rejected")

	var invalid_number := new_design.duplicate() as ShipDefinition
	invalid_number.maximum_speed = NAN
	_check(_has_error(invalid_number.get_validation_errors(), "maximum_speed"), "non-finite flight values are rejected")
	var invalid_relationships := new_design.duplicate() as ShipDefinition
	invalid_relationships.maximum_speed = 40.0
	invalid_relationships.boost_speed = 30.0
	invalid_relationships.brake_acceleration = 1.0
	invalid_relationships.passive_drag = 2.0
	invalid_relationships.landing_maximum_speed = 40.0
	var relationship_errors := invalid_relationships.get_validation_errors()
	_check(_has_error(relationship_errors, "boost_speed"), "boost speed cannot be below maximum speed")
	_check(_has_error(relationship_errors, "brake_acceleration"), "active braking cannot be weaker than passive drag")
	var slow_craft := new_design.duplicate() as ShipDefinition
	slow_craft.maximum_speed = 10.0
	slow_craft.boost_speed = 20.0
	slow_craft.landing_maximum_speed = 20.0
	_check(_has_error(slow_craft.get_validation_errors(), "landing_maximum_speed"), "landing threshold cannot exceed top speed")


func _test_definition_profiles_and_detached_audit() -> void:
	var interceptor := _definition(
		&"interceptor_profile",
		"Interceptor profile",
		"Interceptor",
		DefinitionScript.EvidenceStatus.NEW,
		PackedStringArray()
	)
	var transport := _definition(
		&"transport_profile",
		"Transport profile",
		"Medium transport",
		DefinitionScript.EvidenceStatus.NEW,
		PackedStringArray()
	)
	transport.maximum_speed = 48.0
	transport.boost_speed = 62.0
	transport.thrust_acceleration = 18.0
	transport.brake_acceleration = 26.0
	transport.yaw_speed_degrees = 38.0
	transport.roll_speed_degrees = 44.0
	transport.maximum_hull = 260.0
	_check(transport.is_definition_valid(), "a slower, heavier-role flight profile validates")

	var interceptor_flight := interceptor.get_flight_profile()
	var transport_flight := transport.get_flight_profile()
	_check(interceptor_flight.maximum_speed != transport_flight.maximum_speed, "definitions support distinct top speeds")
	_check(interceptor_flight.thrust_acceleration != transport_flight.thrust_acceleration, "definitions support distinct acceleration")
	_check(interceptor_flight.yaw_speed_degrees != transport_flight.yaw_speed_degrees, "definitions support distinct turning")
	_check(interceptor_flight.roll_speed_degrees != transport_flight.roll_speed_degrees, "definitions support distinct roll rates")
	_check(not interceptor_flight.has("mouse_sensitivity") and not interceptor_flight.has("invert_mouse_y"), "runtime input preferences are not baked into ship definitions")

	var audit := interceptor.get_audit_report()
	_check(int(audit.schema_version) == DefinitionScript.SCHEMA_VERSION, "definition audit carries a stable schema version")
	_check((audit.entry as Dictionary).noun == "canopy" and audit.audio_profile_id == &"standard_fighter", "entry terminology and audio profile are exposed")
	(audit.flight_profile as Dictionary)["maximum_speed"] = -1.0
	var returned_tags := interceptor.get_compatibility_tags()
	returned_tags.append("mutation")
	_check(interceptor.maximum_speed == 82.0, "mutating an audit flight dictionary cannot alter the definition")
	_check(not interceptor.compatibility_tags.has("mutation"), "compatibility tag getters return detached data")


func _test_definition_resource_round_trip() -> void:
	var definition := _definition(
		&"round_trip_craft",
		"Round-trip craft",
		"Test craft",
		DefinitionScript.EvidenceStatus.AUTHENTICATED,
		PackedStringArray(["A3", "B3@01:00"])
	)
	definition.evidence_notes = "Manual fixture for serialization."
	definition.entry_noun = "hatch"
	definition.audio_profile_id = &"transport_heavy"
	var resource_path := "user://ship_definition_berth_test_%d.tres" % Time.get_ticks_usec()
	var absolute_path := ProjectSettings.globalize_path(resource_path)
	var save_error := ResourceSaver.save(definition, resource_path)
	_check(save_error == OK, "ShipDefinition saves as a normal Godot Resource")
	var loaded := ResourceLoader.load(resource_path, "", ResourceLoader.CACHE_MODE_IGNORE) as ShipDefinition
	_check(loaded != null, "saved ShipDefinition reloads")
	if loaded != null:
		_check(loaded.ship_id == definition.ship_id, "resource round trip preserves stable ship ID")
		_check(loaded.get_evidence_status_id() == &"authenticated", "resource round trip preserves evidence meaning")
		_check(loaded.entry_noun == "hatch" and loaded.audio_profile_id == &"transport_heavy", "resource round trip preserves entry and audio profiles")
	if FileAccess.file_exists(resource_path):
		var remove_error := DirAccess.remove_absolute(absolute_path)
		_check(remove_error == OK, "temporary definition resource is removed")


func _test_berth_transform_volume_and_lookup() -> void:
	var stage := Node3D.new()
	stage.name = "BerthTestStage"
	root.add_child(stage)
	stage.transform = Transform3D(Basis(Vector3.UP, deg_to_rad(-17.0)), Vector3(8.0, 3.0, -11.0))
	var berth := BerthScene.instantiate() as ShipBerth
	stage.add_child(berth)
	berth.berth_id = &"port_berth"
	berth.transform = Transform3D(Basis(Vector3.UP, deg_to_rad(53.0)), Vector3(-4.0, 2.0, 9.0))
	berth.dock_transform = Transform3D(Basis(Vector3.RIGHT, deg_to_rad(12.0)), Vector3(1.5, 0.6, -2.2))
	berth.landing_half_extents = Vector3(4.0, 2.0, 7.0)
	var expected := berth.global_transform * berth.dock_transform
	var actual := berth.get_dock_transform()
	_check(actual.origin.is_equal_approx(expected.origin), "berth exposes the full composed dock position")
	_check(actual.basis.is_equal_approx(expected.basis), "berth preserves the full dock orientation")

	var inside := actual * Vector3(3.95, -1.95, 6.95)
	var outside := actual * Vector3(4.05, 0.0, 0.0)
	_check(berth.contains(inside), "oriented landing volume contains a point inside all local extents")
	_check(not berth.contains(outside), "oriented landing volume rejects a point beyond a local extent")
	_check(berth.contains_transform(Transform3D(Basis.IDENTITY, inside)), "landing volume accepts a transform by its origin")
	_check(BerthScript.find(stage, &"port_berth") == berth, "berth can be found recursively by stable ID")
	_check(BerthScript.find(stage, &"missing_berth") == null, "unknown berth lookup returns no implicit fallback")
	_check(bool(berth.audit().valid), "well-formed berth reports a valid audit")

	var invalid_berth := BerthScript.new() as ShipBerth
	invalid_berth.berth_id = &"Bad_Berth"
	invalid_berth.landing_half_extents = Vector3(2.0, 0.0, 3.0)
	invalid_berth.dock_transform = Transform3D(Basis(Vector3.ZERO, Vector3.ZERO, Vector3.ZERO), Vector3.ZERO)
	_check(invalid_berth.get_validation_errors().size() >= 3, "invalid berth ID, transform, and volume are reported")
	invalid_berth.free()
	stage.queue_free()
	await process_frame
	await process_frame


func _test_berth_reservation_and_occupancy() -> void:
	var stage := Node3D.new()
	root.add_child(stage)
	var berth := BerthScript.new() as ShipBerth
	berth.berth_id = &"central_berth"
	berth.compatibility_tags = PackedStringArray(["small_craft", "fighter"])
	stage.add_child(berth)
	var compatible := _definition(
		&"compatible_craft",
		"Compatible craft",
		"Fighter",
		DefinitionScript.EvidenceStatus.NEW,
		PackedStringArray()
	)
	compatible.compatibility_tags = PackedStringArray(["small_craft"])
	var incompatible := compatible.duplicate() as ShipDefinition
	incompatible.ship_id = &"incompatible_craft"
	incompatible.compatibility_tags = PackedStringArray(["capital_ship"])
	var requester_a := Node3D.new()
	requester_a.name = "RequesterA"
	stage.add_child(requester_a)
	var requester_b := Node3D.new()
	requester_b.name = "RequesterB"
	stage.add_child(requester_b)

	_check(berth.can_accept(compatible, requester_a), "compatible empty berth accepts a requester")
	_check(not berth.can_accept(incompatible, requester_a), "berth rejects incompatible definition tags")
	var token_a := berth.try_reserve(requester_a, compatible)
	_check(not token_a.is_empty(), "successful reservation returns an opaque token")
	_check(berth.try_reserve(requester_a, compatible) == token_a, "duplicate reservation by the same requester is idempotent")
	_check(berth.get_reservation_token(requester_a) == token_a, "reservation owner can retrieve its token")
	_check(berth.get_reservation_token(requester_b).is_empty(), "foreign requester cannot retrieve a token")
	_check(not berth.can_accept(compatible, requester_b), "reserved berth rejects another requester")
	_check(berth.try_reserve(requester_b, compatible).is_empty(), "duplicate reservation by another requester fails")
	_check(not berth.occupy(requester_a, &"wrong-token"), "wrong token cannot occupy a berth")
	_check(not berth.occupy(requester_b, token_a), "foreign requester cannot use another ship's token")
	_check(berth.occupy(requester_a, token_a), "reservation owner can occupy the berth")
	_check(berth.occupy(requester_a, token_a), "duplicate occupancy by the same lease is idempotent")
	_check(berth.get_occupant() == requester_a and berth.is_occupied(), "occupied berth exposes its physical occupant")
	_check(not berth.release(requester_a, &"wrong-token"), "wrong token cannot release an occupied berth")
	_check(not berth.release(requester_b, token_a), "foreign requester cannot release an occupied berth")
	_check(berth.is_occupied(), "failed releases preserve occupancy")
	_check(berth.release(requester_a, token_a), "correct owner and token release the berth")
	_check(not berth.release(requester_a, token_a), "duplicate release is rejected")
	_check(not berth.is_reserved() and not berth.is_occupied(), "release clears reservation and occupancy together")

	var unrestricted := BerthScript.new() as ShipBerth
	unrestricted.berth_id = &"unrestricted_berth"
	stage.add_child(unrestricted)
	_check(unrestricted.can_accept(incompatible, requester_b), "berth with no compatibility tags accepts any valid definition")
	var stale_token := unrestricted.try_reserve(requester_b, incompatible)
	_check(not stale_token.is_empty(), "unrestricted berth can be reserved")
	requester_b.queue_free()
	await process_frame
	await process_frame
	_check(not unrestricted.is_reserved() and not unrestricted.is_occupied(), "freed requester cannot leave a stale berth claim")

	stage.queue_free()
	await process_frame
	await process_frame


func _definition(
		ship_id: StringName,
		display_name: String,
		role: String,
		status: int,
		references: PackedStringArray
	) -> ShipDefinition:
	var definition := DefinitionScript.new() as ShipDefinition
	definition.ship_id = ship_id
	definition.display_name = display_name
	definition.role_name = role
	definition.evidence_status = status
	definition.evidence_references = references
	return definition


func spadded_reference_fix(definition: ShipDefinition) -> void:
	definition.evidence_references = PackedStringArray([" A3"])


func _has_error(errors: PackedStringArray, fragment: String) -> bool:
	for error in errors:
		if error.contains(fragment):
			return true
	return false


func _check(condition: bool, description: String) -> void:
	if condition:
		print("PASS: ", description)
	else:
		_failures.append(description)
		push_error("FAIL: " + description)


func _finish() -> void:
	if _failures.is_empty():
		print("SHIP_DEFINITION_BERTH_TEST_OK")
		quit(0)
	else:
		print("SHIP_DEFINITION_BERTH_TEST_FAILED: ", ", ".join(_failures))
		quit(1)
