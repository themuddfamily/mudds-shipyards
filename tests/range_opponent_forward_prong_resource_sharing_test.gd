extends SceneTree

## Focused allocation contract for the base defender's immutable forward-prong
## pair. The mirrored silhouette keeps two renderers/submissions and one mesh.

const OPPONENT_SCENE := preload("res://scenes/ships/range_opponent.tscn")

var _assertions := 0
var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var opponent := OPPONENT_SCENE.instantiate() as RangeOpponent
	root.add_child(opponent)
	await process_frame

	var visual := opponent.get_node_or_null(^"RangeInterceptorVisual") as Node3D
	var prongs: Array[MeshInstance3D] = []
	if visual != null:
		for raw_child in visual.get_children():
			var child := raw_child as MeshInstance3D
			if child != null and (
				child.position.is_equal_approx(RangeOpponent.FORWARD_PRONG_POSITIONS[0])
					or child.position.is_equal_approx(RangeOpponent.FORWARD_PRONG_POSITIONS[1])
			):
				prongs.append(child)
	_check(
		prongs.size() == 2
			and prongs[0].mesh == prongs[1].mesh
			and prongs[0].mesh.get_surface_count() == 1,
		"two visible prong renderers retain two submissions while mesh allocations fall 2 -> 1"
	)

	var expected_port_aabb := AABB(Vector3(-3.24, -0.38, -4.825), Vector3(1.18, 0.72, 8.35))
	var expected_starboard_aabb := AABB(Vector3(2.06, -0.38, -4.825), Vector3(1.18, 0.72, 8.35))
	var port_aabb := (prongs[0].transform * prongs[0].mesh.get_aabb()).abs()
	var starboard_aabb := (prongs[1].transform * prongs[1].mesh.get_aabb()).abs()
	_check(
		prongs[0].position.is_equal_approx(RangeOpponent.FORWARD_PRONG_POSITIONS[0])
			and prongs[0].basis.is_equal_approx(Basis.IDENTITY)
			and prongs[1].position.is_equal_approx(RangeOpponent.FORWARD_PRONG_POSITIONS[1])
			and prongs[1].basis.is_equal_approx(Basis.from_euler(Vector3(0.0, 0.0, PI)))
			and prongs[1].basis.determinant() > 0.0
			and port_aabb.is_equal_approx(expected_port_aabb)
			and starboard_aabb.is_equal_approx(expected_starboard_aabb),
		"the proper mirrored transform preserves both exact authored silhouette bounds and winding"
	)

	var material := prongs[0].mesh.surface_get_material(0) as StandardMaterial3D
	_check(
		material != null
			and material.albedo_color.is_equal_approx(RangeOpponent.HULL_IVORY)
			and prongs[0].get_child_count() == 0
			and prongs[1].get_child_count() == 0
			and prongs[0].get_script() == null
			and prongs[1].get_script() == null,
		"shared stock retains ivory presentation and gains no child, script or authority"
	)

	var colliders := opponent.find_children("*", "CollisionShape3D", false, false)
	var activated := opponent.activate_with_result(Transform3D(Basis.IDENTITY, Vector3(4.0, 2.0, -8.0)))
	var maximum_health := opponent.get_maximum_health()
	opponent.apply_damage(maximum_health * 0.7, opponent.global_position)
	var smoke := opponent.get_node_or_null(^"EngineSmoke") as CPUParticles3D
	var damaged := opponent.is_active() and smoke != null and smoke.emitting
	opponent.deactivate()
	activated = opponent.activate_with_result(Transform3D(Basis.IDENTITY, Vector3(-3.0, 1.0, 6.0)))
	_check(
		colliders.size() == 7
			and opponent.get_node_or_null(^"PortMuzzle") is Marker3D
			and opponent.get_node_or_null(^"StarboardMuzzle") is Marker3D
			and damaged
			and bool(activated.get("accepted", false))
			and opponent.is_active()
			and is_equal_approx(opponent.get_health(), maximum_health)
			and smoke != null
			and not smoke.emitting,
		"collision, weapon anchors, staged component cues and same-instance reuse remain intact"
	)

	opponent.queue_free()
	await process_frame
	if _failures.is_empty():
		print("RANGE_OPPONENT_FORWARD_PRONG_RESOURCE_SHARING_TEST_OK: %d checks" % _assertions)
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _check(condition: bool, message: String) -> void:
	_assertions += 1
	if not condition:
		_failures.append(message)
