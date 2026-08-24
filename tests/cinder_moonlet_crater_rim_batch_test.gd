extends SceneTree

## Focused production proof for the reachable Cinder moonlet's visual crater rims.

const CLUSTER_SCENE := preload("res://scenes/world/components/nearby_sector_cluster.tscn")
const MOONLET_PATH := ^"Landmarks/ReachMoonlet"
const BATCH_PATH := ^"MoonletCraterRims"

var _assertions := 0
var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var cluster := CLUSTER_SCENE.instantiate() as NearbySectorCluster
	root.add_child(cluster)
	await process_frame

	var moonlet := cluster.get_node_or_null(MOONLET_PATH) as StaticBody3D
	var batch := moonlet.get_node_or_null(BATCH_PATH) as MeshInstance3D \
		if moonlet != null else null
	_check(
		moonlet != null and batch != null and batch.mesh != null,
		"the production moonlet owns one retained crater-rim batch"
	)
	if moonlet == null or batch == null or batch.mesh == null:
		cluster.queue_free()
		await process_frame
		_finish()
		return

	var transforms := batch.get_meta(&"authored_instance_transforms", []) as Array
	var batch_mesh := batch.mesh as ArrayMesh
	_check(
		int(batch.get_meta(&"authored_visible_copy_count", 0))
		== NearbySectorCluster.MOONLET_CRATER_COUNT
		and transforms.size() == NearbySectorCluster.MOONLET_CRATER_COUNT
		and moonlet.find_children("CraterRim*", "MeshInstance3D", false, false).is_empty(),
		"six visual copies replace the six former renderer nodes without losing a rim"
	)
	var torus := TorusMesh.new()
	torus.inner_radius = NearbySectorCluster.MOONLET_CRATER_RIM_INNER_RADIUS
	torus.outer_radius = NearbySectorCluster.MOONLET_CRATER_RIM_OUTER_RADIUS
	torus.rings = NearbySectorCluster.TORUS_RINGS
	torus.ring_segments = NearbySectorCluster.TORUS_RING_SEGMENTS
	var source_arrays := torus.surface_get_arrays(0)
	var batch_arrays := batch_mesh.surface_get_arrays(0) if batch_mesh != null else []
	_check(
		batch_mesh != null and batch_mesh.get_surface_count() == 1
		and (batch_arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()
		== (source_arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()
		* NearbySectorCluster.MOONLET_CRATER_COUNT,
		"one immutable proportional torus recipe serves every authored radius"
	)

	var expected := _expected_transforms()
	var transforms_exact := transforms.size() == expected.size()
	var all_bounds := AABB()
	var first_bound := true
	var source_vertices := source_arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array
	for index in mini(transforms.size(), expected.size()):
		var actual := transforms[index] as Transform3D
		transforms_exact = transforms_exact and actual.is_equal_approx(expected[index])
		for vertex in source_vertices:
			var transformed := actual * vertex
			if first_bound:
				all_bounds = AABB(transformed, Vector3.ZERO)
				first_bound = false
			else:
				all_bounds = all_bounds.expand(transformed)
	_check(
		transforms_exact,
		"the deterministic six positions, orientations, and 9-21 metre scale cues remain exact"
	)
	_check(
		not first_bound
		and batch.mesh.get_aabb().is_equal_approx(all_bounds),
		"the single renderer publishes bounds covering the complete moonlet silhouette"
	)
	_check(
		batch.material_override == cluster._materials["moonlet_crater"]
		and StringName(batch.get_meta(&"visual_batch_family_id", &""))
		== NearbySectorCluster.MOONLET_CRATER_RIM_FAMILY_ID
		and bool(batch.get_meta(&"presentation_only", false))
		and bool(batch.get_meta(&"physically_supported", false))
		and batch.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_OFF,
		"the batched family retains the steady crater material and visual-only contract"
	)

	var collision := moonlet.get_node_or_null(^"Collision") as CollisionShape3D
	var sphere := collision.shape as SphereShape3D if collision != null else null
	_check(
		sphere != null and is_equal_approx(sphere.radius, NearbySectorCluster.MOONLET_RADIUS)
		and batch.find_children("*", "CollisionObject3D", true, false).is_empty()
		and batch.find_children("*", "CollisionShape3D", true, false).is_empty()
		and batch.find_children("*", "Light3D", true, false).is_empty()
		and batch.find_children("*", "Area3D", true, false).is_empty()
		and not batch.is_processing() and not batch.is_physics_processing(),
		"the moon collision is unchanged and the visual family gains no authority or lights"
	)

	var retained_id := batch.get_instance_id()
	cluster.set_cluster_enabled(false)
	cluster.set_cluster_enabled(true)
	_check(
		moonlet.get_node(BATCH_PATH).get_instance_id() == retained_id,
		"streaming visibility reuses the exact crater renderer and immutable resources"
	)
	var allocation := cluster.get_torus_allocation_audit()
	var cluster_audit := cluster.get_cluster_audit_report()
	if not bool(allocation.get("valid", false)):
		print("TORUS_ALLOCATION_ERRORS: ", allocation.get("errors", []))
	if not bool(cluster_audit.get("valid", false)):
		print("CLUSTER_AUDIT_ERRORS: ", cluster_audit.get("errors", []))
	_check(
		bool(allocation.get("valid", false))
		and int(allocation.get("copy_count", -1)) == NearbySectorCluster.TORUS_COPY_COUNT
		and int(allocation.get("crater_rim_copy_count", -1)) == NearbySectorCluster.MOONLET_CRATER_COUNT
		and int(allocation.get("mesh_resource_allocations", -1))
		== NearbySectorCluster.TORUS_MESH_RESOURCE_ALLOCATIONS
		and bool(cluster_audit.get("valid", false)),
		"the production allocation and unchanged cluster performance ceilings remain valid"
	)

	cluster.queue_free()
	await process_frame
	_finish()


func _expected_transforms() -> Array[Transform3D]:
	var random := RandomNumberGenerator.new()
	random.seed = NearbySectorCluster.FIELD_SEED + 4111
	var result: Array[Transform3D] = []
	for crater_index in NearbySectorCluster.MOONLET_CRATER_COUNT:
		var latitude := random.randf_range(-0.75, 0.75)
		var longitude := random.randf_range(-PI, PI)
		var planar := sqrt(maxf(0.0, 1.0 - latitude * latitude))
		var normal := Vector3(planar * cos(longitude), latitude, planar * sin(longitude))
		var radius := random.randf_range(9.0, 21.0)
		result.append(Transform3D(
			_basis_facing(normal) * Basis(Vector3.RIGHT, PI * 0.5) \
				* Basis.from_scale(Vector3.ONE * radius),
			normal * (NearbySectorCluster.MOONLET_RADIUS - radius * 0.22)
		))
	return result


func _basis_facing(forward: Vector3) -> Basis:
	var z_axis := forward.normalized()
	var up_hint := Vector3.UP if absf(z_axis.dot(Vector3.UP)) < 0.98 else Vector3.RIGHT
	var x_axis := up_hint.cross(z_axis).normalized()
	var y_axis := z_axis.cross(x_axis).normalized()
	return Basis(x_axis, y_axis, z_axis)


func _check(condition: bool, message: String) -> void:
	_assertions += 1
	if condition:
		print("PASS: ", message)
	else:
		_failures.append(message)
		print("FAIL: ", message)


func _finish() -> void:
	print("CINDER_MOONLET_CRATER_RIM_BATCH_TEST_ASSERTIONS: ", _assertions)
	if _failures.is_empty():
		print("CINDER_MOONLET_CRATER_RIM_BATCH_TEST_OK")
		quit(0)
		return
	for failure in _failures:
		print("CINDER_MOONLET_CRATER_RIM_BATCH_TEST_FAILURE: ", failure)
	quit(1)
