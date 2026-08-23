extends SceneTree

const Adapter := preload("res://scripts/network/network_enet_session_adapter.gd")
const Relationship := preload("res://scripts/network/moving_interior_relationship.gd")

var _assertions := 0
var _failures := PackedStringArray()


func _init() -> void:
	call_deferred(&"_run")


func _run() -> void:
	var holder := Node3D.new()
	get_root().add_child(holder)
	var frame := Node3D.new()
	frame.position = Vector3(10.0, 0.0, 0.0)
	holder.add_child(frame)
	var avatar := Node3D.new()
	holder.add_child(avatar)
	var adapter := Adapter.new()
	adapter._configured = true
	_check(adapter.consume_moving_interior_snapshot(_packet(1, 1, 1.0)).accepted,
		"accepted relationship feeds bound presentation")
	_check(adapter.bind_moving_interior_replica(&"crew_7", 3, avatar, frame, 5).accepted,
		"caller registers remote avatar and frame")
	var applied: Dictionary = adapter.apply_moving_interior_replica(&"crew_7", 1.0)
	_check(applied.get("status") == &"interpolated", "caller-time sample applies presentation")
	_check(is_equal_approx(avatar.global_position.x, 11.0), "frame-relative pose reaches avatar node")
	_check(adapter.bind_moving_interior_replica(&"crew_7", 2, avatar, frame, 5).accepted,
		"rebind updates entity generation")
	_check(adapter.apply_moving_interior_replica(&"crew_7", 1.0).accepted,
		"rebound generation remains adapter-owned")
	frame.free()
	_check(adapter.apply_moving_interior_replica(&"crew_7", 2.0).get("status") == &"frame_unavailable",
		"frame loss freezes presentation")
	_check(adapter.reset_snapshot_jitter(2).accepted, "migration clears registered bindings")
	_check(adapter.apply_moving_interior_replica(&"crew_7", 2.0).get("status") == &"entity_not_tracked",
		"migration prevents stale binding reuse")
	var physics := StaticBody3D.new()
	holder.add_child(physics)
	_check(adapter.bind_moving_interior_replica(&"physics", 1, physics, avatar, 1).get("status") == &"physics_body_rejected",
		"adapter rejects physics presentation targets")
	_check(adapter.detach_moving_interior_replica(&"crew_7").accepted, "detach is idempotent for cleared binding")
	adapter.free()
	holder.free()
	if _failures.is_empty():
		print("OK: ENet moving interior binding (%d assertions)" % _assertions)
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)


func _packet(revision: int, tick: int, x: float) -> Dictionary:
	var relationship := Relationship.create(
		tick, &"crew_7", 1, &"halyard_frame", 1,
		Transform3D(Basis.IDENTITY, Vector3(x, 0.0, 0.0))
	).get_snapshot()
	return {"revision": revision, "server_tick": tick, "relationship": relationship}


func _check(condition: bool, description: String) -> void:
	_assertions += 1
	if not condition:
		_failures.append("FAIL: " + description)
