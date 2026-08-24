extends SceneTree

const Binding := preload("res://scripts/world/fleet_expansion_production_binding.gd")

var _assertions := 0
var _failures: Array[String] = []


func _initialize() -> void:
	var binding := Binding.new()
	root.add_child(binding)
	await process_frame
	await process_frame
	var audit := binding.get_audit_report()
	_check(bool(audit.get("valid", false)) and int(audit.get("fleet_count", 0)) == 3, "production binding composes three NEW craft and three typed berth slots")
	var snapshot := binding.get_fleet_snapshot()
	_check((snapshot.get("craft", []) as Array).size() == 3, "fleet snapshot publishes all composed craft")
	var berths := binding.get_node_or_null(^"FleetExpansionBerths") as Node3D
	var endpoint_paths := {
		&"dock_04_cargo": ^"AccessCirculation/CargoBoardingLeg",
		&"dock_05_bomber": ^"AccessCirculation/BomberBoardingLeg",
		&"dock_06_interceptor": ^"AccessCirculation/InterceptorBoardingToe",
	}
	for craft in snapshot.get("craft", []) as Array:
		var row := craft as Dictionary
		var pad_id := StringName(row.get("pad_id", &""))
		var endpoint := berths.get_node_or_null(endpoint_paths.get(pad_id, NodePath())) as StaticBody3D \
			if berths != null else null
		var boarding_anchor := row.get("boarding_anchor", Vector3.INF) as Vector3
		_check(
			bool(row.get("attached", false)) and boarding_anchor.is_finite()
			and _body_top_contains_xz(endpoint, boarding_anchor),
			"each attached craft's live boarding anchor projects onto its declared no-jump endpoint"
		)
	var detached := binding.detach_craft(&"cinder_long_range_bomber")
	_check(bool(detached.get("accepted", false)), "typed bomber detach succeeds")
	var reattached := binding.reattach_craft(&"cinder_long_range_bomber")
	_check(bool(reattached.get("accepted", false)), "detached bomber can be safely reused")
	_check(bool(binding.get_audit_report().get("valid", false)), "detach/reuse leaves the composition valid")
	binding.queue_free()
	await process_frame
	if _failures.is_empty():
		print("PASS fleet_expansion_production_binding_test (%d assertions)" % _assertions)
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _check(condition: bool, message: String) -> void:
	_assertions += 1
	if not condition:
		_failures.append(message)


func _body_top_contains_xz(body: StaticBody3D, point: Vector3) -> bool:
	var collision := body.get_node_or_null(^"Collision") as CollisionShape3D if body != null else null
	var shape := collision.shape as BoxShape3D if collision != null else null
	if shape == null:
		return false
	var bounds := (collision.global_transform * AABB(-shape.size * 0.5, shape.size)).abs()
	return point.x >= bounds.position.x - 0.001 and point.x <= bounds.end.x + 0.001 \
		and point.z >= bounds.position.z - 0.001 and point.z <= bounds.end.z + 0.001
