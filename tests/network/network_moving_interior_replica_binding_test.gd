extends SceneTree

const Binding := preload("res://scripts/network/network_moving_interior_replica_binding.gd")

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
	var binding := Binding.new(4.0)
	_check(binding.bind(&"crew_7", 3, avatar, frame, 5).accepted, "presentation node binds")
	var applied: Dictionary = binding.apply_sample(&"crew_7", _sample(Vector3(2.0, 0.0, 0.0), &"interpolated"), 3, 5)
	_check(applied.get("status") == &"interpolated", "interpolated sample applies")
	_check(is_equal_approx(avatar.global_position.x, 12.0), "local pose resolves against moving frame")
	_check(binding.apply_sample(&"crew_7", _sample(Vector3(3.0, 0.0, 0.0), &"interpolated"), 2, 5).get("status") == &"stale_entity_generation",
		"stale entity generation is rejected")
	var invalid := _sample(Vector3(NAN, 0.0, 0.0), &"interpolated")
	_check(binding.apply_sample(&"crew_7", invalid, 3, 5).get("status") == &"invalid_sample_transform",
		"non-finite transforms are rejected")
	var frozen_position := avatar.global_position
	frame.free()
	_check(binding.apply_sample(&"crew_7", _sample(Vector3(4.0, 0.0, 0.0), &"interpolated"), 3, 5).get("status") == &"frame_unavailable",
		"missing frame freezes presentation")
	_check(avatar.global_position == frozen_position, "frame loss leaves last pose untouched")
	var physics := StaticBody3D.new()
	holder.add_child(physics)
	_check(binding.bind(&"physics", 1, physics, avatar, 5).get("status") == &"physics_body_rejected",
		"physics bodies are rejected")
	var reentry_frame := Node3D.new()
	holder.add_child(reentry_frame)
	_check(binding.bind(&"crew_7", 3, avatar, reentry_frame, 6).accepted, "re-entry binds a new frame generation")
	_check(binding.apply_sample(&"crew_7", _sample(Vector3(20.0, 0.0, 0.0), &"teleported"), 3, 6).get("status") == &"teleported",
		"teleport sample snaps presentation")
	_check(binding.detach(&"crew_7").accepted, "detach clears presentation binding")
	_check(binding.apply_sample(&"crew_7", _sample(Vector3.ZERO, &"interpolated"), 3, 6).get("status") == &"entity_not_bound",
		"detached entity cannot be applied")
	holder.free()
	if _failures.is_empty():
		print("OK: moving interior replica binding (%d assertions)" % _assertions)
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)


func _sample(position: Vector3, status: StringName) -> Dictionary:
	return {"accepted": true, "status": status, "transform": Transform3D(Basis.IDENTITY, position)}


func _check(condition: bool, description: String) -> void:
	_assertions += 1
	if not condition:
		_failures.append("FAIL: " + description)
