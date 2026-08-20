extends SceneTree

const Relationship := preload("res://scripts/network/moving_interior_relationship.gd")
const Validator := preload("res://scripts/network/moving_interior_relationship_validator.gd")

var _failures: Array[String] = []
var _passes := 0


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_test_wire_contract()
	_test_authority_ordering()
	if _failures.is_empty():
		print("OK: moving interior relationship network contract (%d assertions)" % _passes)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)
		return
	quit(0)


func _test_wire_contract() -> void:
	var local_transform := Transform3D(Basis(Vector3.UP, 0.4), Vector3(2.0, 1.5, -3.0))
	var relationship := Relationship.create(
		12, &"pilot_7", 4, &"jovian_frame", 9, local_transform,
		Vector3(3.0, 0.0, -1.0), Vector3(0.0, 0.2, 0.0), 18
	)
	_check(relationship.is_valid(), "authoritative frame-local relationship accepts finite generation-bearing data")
	var wire := relationship.get_snapshot()
	var decoded := Relationship.from_dictionary(wire)
	_check(decoded.is_valid(), "wire snapshot reconstructs as an independent valid relationship")
	_check(decoded.get_frame_local_transform().is_equal_approx(local_transform), "frame-local transform survives transport encoding")
	_check(decoded.get_linear_velocity().is_equal_approx(Vector3(3.0, 0.0, -1.0)), "velocity survives transport encoding")
	var frame_transform := Transform3D(Basis(Vector3.UP, -0.2), Vector3(100.0, 8.0, 20.0))
	_check(decoded.resolve_world_transform(frame_transform).is_equal_approx(frame_transform * local_transform), "replica resolves world pose from its caller-owned frame")
	wire.frame_local_transform[9] = 999.0
	_check(not decoded.get_frame_local_transform().origin.is_equal_approx(Vector3(999.0, 1.5, -3.0)), "decoded snapshots are detached from mutable wire arrays")
	var missing := relationship.get_snapshot()
	missing.erase("event_sequence")
	_check(not Relationship.from_dictionary(missing).is_valid(), "missing wire fields fail closed")
	var nonfinite := relationship.get_snapshot()
	nonfinite.frame_local_transform[0] = NAN
	_check(not Relationship.from_dictionary(nonfinite).is_valid(), "non-finite transform components fail closed")
	var root := Relationship.create(1, &"station_player", 1, &"", 0, Transform3D.IDENTITY)
	_check(root.is_valid(), "world-root relationships use an explicit zero frame generation")
	_check(root.audit().get("owns_movement", true) == false, "relationship contract does not claim movement authority")


func _test_authority_ordering() -> void:
	var validator := Validator.new(42)
	var first := Relationship.create(100, &"pilot_7", 1, &"jovian_frame", 2, Transform3D.IDENTITY).get_snapshot()
	var spoofed := validator.accept(7, first)
	_check(not spoofed.accepted and spoofed.status == &"unauthorized_sender", "non-authoritative peers cannot publish interior relationships")
	var accepted := validator.accept(42, first)
	_check(accepted.accepted and not accepted.gap_detected, "authoritative first relationship is accepted")
	var later := Relationship.create(103, &"pilot_7", 1, &"jovian_frame", 2, Transform3D(Basis.IDENTITY, Vector3(0, 1, 0))).get_snapshot()
	var gap := validator.accept(42, later)
	_check(gap.accepted and gap.gap_detected, "packet gaps are tolerated and exposed to interpolation")
	var duplicate := validator.accept(42, later)
	_check(not duplicate.accepted and duplicate.status == &"stale_or_duplicate_tick", "duplicate snapshots cannot replay a relationship")
	var reordered := Relationship.create(102, &"pilot_7", 1, &"jovian_frame", 2, Transform3D.IDENTITY).get_snapshot()
	_check(not validator.accept(42, reordered).accepted, "out-of-order snapshots are rejected")
	var stale_frame := Relationship.create(104, &"pilot_7", 1, &"jovian_frame", 1, Transform3D.IDENTITY).get_snapshot()
	_check(validator.accept(42, stale_frame).status == &"stale_frame_generation", "stale moving-frame generations are rejected")
	var stale_entity := Relationship.create(105, &"pilot_7", 0, &"jovian_frame", 2, Transform3D.IDENTITY).get_snapshot()
	# Invalid generation is rejected at the relationship boundary before authority state changes.
	_check(validator.accept(42, stale_entity).status == &"invalid_snapshot", "invalid entity generations cannot enter authority history")
	var replacement := Relationship.create(106, &"pilot_7", 2, &"jovian_frame", 1, Transform3D.IDENTITY).get_snapshot()
	_check(validator.accept(42, replacement).accepted, "new entity generations replace the prior lifecycle")
	_check(validator.get_latest(&"pilot_7").get("entity_generation", 0) == 2, "latest generation is queryable by stable entity ID")
	_check(validator.resolve_world_transform(&"pilot_7", Transform3D(Basis.IDENTITY, Vector3(4, 0, 0))).origin.is_equal_approx(Vector3(4, 0, 0)), "validator resolves only presentation pose from a supplied frame")
	_check(validator.retire(&"pilot_7") and validator.get_latest(&"pilot_7").is_empty(), "retirement removes relationship history")


func _check(condition: bool, label: String) -> void:
	if condition:
		_passes += 1
	else:
		_failures.append("FAIL: " + label)
