extends SceneTree

## Focused proof of the Phase 10 §2 dressing consolidation contract.
##
## The production pass runs over the whole station; this fixture runs the same
## static helper over a hand-built subtree whose expected arithmetic can be
## written down exactly. It asserts the three things the station depends on:
##
## 1. the merged renderer carries every source triangle at its former world
##    placement, and nothing else changes about how it draws;
## 2. every collision shape survives as its own `CollisionShape3D` with an
##    unchanged world-space box, so the physical station is untouched;
## 3. a node carrying metadata, a script, a group, a child, a protected name or
##    a live script reference is never removed.

const BATCH := preload("res://scripts/world/station_dressing_batch.gd")
const WORLD_LAYER := 1

var _assertions := 0
var _failures := PackedStringArray()


class ReferenceHolder:
	extends Node3D

	var kept: MeshInstance3D


func _init() -> void:
	call_deferred("_run")


func _check(condition: bool, label: String) -> void:
	_assertions += 1
	if not condition:
		_failures.append(label)


func _box_mesh(size: Vector3) -> ArrayMesh:
	return StationSurfaceKit.rounded_box_mesh_with_bevel_cached(
		size,
		StationSurfaceKit.proportional_bevel_for_size(size, 0.2),
		{},
		StationSurfaceKit.BevelUV.FACE_GRID
	)


func _solid(parent: Node3D, node_name: String, at: Vector3, size: Vector3, material: Material) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.name = node_name
	body.position = at
	body.collision_layer = WORLD_LAYER
	body.collision_mask = 0
	parent.add_child(body)
	var visual := MeshInstance3D.new()
	visual.name = "Mesh"
	visual.mesh = _box_mesh(size)
	visual.material_override = material
	body.add_child(visual)
	var collision := CollisionShape3D.new()
	collision.name = "Collision"
	var shape := BoxShape3D.new()
	shape.size = size
	collision.shape = shape
	body.add_child(collision)
	return body


func _visual(parent: Node3D, node_name: String, at: Vector3, size: Vector3, material: Material) -> MeshInstance3D:
	var visual := MeshInstance3D.new()
	visual.name = node_name
	visual.position = at
	visual.mesh = _box_mesh(size)
	visual.material_override = material
	parent.add_child(visual)
	return visual


func _triangles(node: Node) -> int:
	var total := 0
	if node is MeshInstance3D and (node as MeshInstance3D).mesh != null:
		total += (node as MeshInstance3D).mesh.get_faces().size() / 3
	for child in node.get_children():
		total += _triangles(child)
	return total


func _shape_boxes(node: Node) -> Array[AABB]:
	var boxes: Array[AABB] = []
	for candidate in node.find_children("*", "CollisionShape3D", true, false):
		var collision := candidate as CollisionShape3D
		var box := collision.shape as BoxShape3D
		if box == null:
			continue
		boxes.append(AABB(
			collision.global_position - box.size * 0.5, box.size
		))
	boxes.sort_custom(_sort_boxes)
	return boxes


static func _sort_boxes(a: AABB, b: AABB) -> bool:
	if not is_equal_approx(a.position.x, b.position.x):
		return a.position.x < b.position.x
	if not is_equal_approx(a.position.y, b.position.y):
		return a.position.y < b.position.y
	return a.position.z < b.position.z


func _count(node: Node) -> int:
	var total := 1
	for child in node.get_children():
		total += _count(child)
	return total


func _run() -> void:
	var material := StandardMaterial3D.new()
	var other_material := StandardMaterial3D.new()
	var holder := ReferenceHolder.new()
	holder.name = "Module"
	root.add_child(holder)

	var posts: Array[StaticBody3D] = []
	for index in 4:
		posts.append(_solid(
			holder, "Post%02d" % index, Vector3(index * 2.0, 0.6, 0.0),
			Vector3(0.2, 1.2, 0.2), material
		))
	# Different material: its own batch, never mixed with the posts.
	var rail := _solid(holder, "Rail", Vector3(3.0, 1.2, 0.0), Vector3(7.0, 0.2, 0.2), other_material)
	# Authority cases that must survive untouched.
	var walkable := _solid(holder, "Deck", Vector3(3.0, -0.2, 0.0), Vector3(8.0, 0.4, 4.0), material)
	walkable.set_meta(&"walkable_surface", true)
	var protected := _solid(holder, "NamedPost", Vector3(-2.0, 0.6, 0.0), Vector3(0.2, 1.2, 0.2), material)
	var braces: Array[MeshInstance3D] = []
	for index in 3:
		braces.append(_visual(
			holder, "Brace%02d" % index, Vector3(index * 2.0, 2.0, 1.0),
			Vector3(0.3, 0.3, 2.0), material
		))
	var fascia := _visual(holder, "Fascia", Vector3(3.0, 3.0, 1.0), Vector3(6.0, 0.4, 0.2), other_material)
	holder.kept = _visual(holder, "HeldBrace", Vector3(8.0, 2.0, 1.0), Vector3(0.3, 0.3, 2.0), material)
	var grouped := _visual(holder, "GroupedBrace", Vector3(10.0, 2.0, 1.0), Vector3(0.3, 0.3, 2.0), material)
	grouped.add_to_group(&"station_dressing_batch_fixture")

	await process_frame
	var before_nodes := _count(holder)
	var before_triangles := _triangles(holder)
	var before_boxes := _shape_boxes(holder)

	var report := BATCH.consolidate(holder, PackedStringArray(["NamedPost"]), holder)
	await process_frame

	_check(bool(report.get("applied", false)), "consolidation reports that it ran")
	_check(
		int(report.get("solid_batches", 0)) == 1
			and int(report.get("solid_sources", 0)) == 5,
		"the four posts and the rail become one solid batch with a surface each"
	)
	_check(
		int(report.get("visual_batches", 0)) == 1
			and int(report.get("visual_sources", 0)) == 4,
		"the three braces and the fascia become one visual batch"
	)
	_check(
		int(report.get("folded_body_meshes", 0)) == 0,
		"no metadata-bearing body's renderer is folded when it has no same-material sibling"
	)

	var after_nodes := _count(holder)
	# 5 solids (15 nodes) -> body + 5 shapes + mesh (7); 4 renderers -> 1 batch.
	_check(
		before_nodes - after_nodes == 11,
		"node arithmetic is exactly the published 15->7 solid and 4->1 visual trim (was %d, now %d)"
			% [before_nodes, after_nodes]
	)
	_check(
		_triangles(holder) == before_triangles,
		"merged geometry carries every source triangle (%d)" % before_triangles
	)

	var after_boxes := _shape_boxes(holder)
	var boxes_match := before_boxes.size() == after_boxes.size()
	if boxes_match:
		for index in before_boxes.size():
			if not before_boxes[index].position.is_equal_approx(after_boxes[index].position) \
					or not before_boxes[index].size.is_equal_approx(after_boxes[index].size):
				boxes_match = false
				break
	_check(
		boxes_match,
		"every collision box keeps its exact world position and extent"
	)

	_check(
		is_instance_valid(walkable) and walkable.get_parent() == holder
			and walkable.get_node_or_null(^"Mesh") != null,
		"a walkable-surface body keeps its own node and renderer"
	)
	_check(
		is_instance_valid(protected) and protected.get_parent() == holder,
		"a protected name is never merged away"
	)
	_check(
		is_instance_valid(holder.kept) and holder.kept.get_parent() == holder,
		"a renderer a live script variable still holds is never merged away"
	)
	_check(
		is_instance_valid(grouped) and grouped.get_parent() == holder,
		"a grouped renderer is never merged away"
	)
	for post in posts:
		_check(not is_instance_valid(post), "batched post is released")
	_check(not is_instance_valid(rail), "a second-material sibling joins the same batch")
	_check(not is_instance_valid(fascia), "a second-material renderer joins the same batch")

	var batch := holder.get_node_or_null(^"SolidBatch01") as StaticBody3D
	_check(
		batch != null and batch.collision_layer == WORLD_LAYER and batch.collision_mask == 0
			and batch.find_children("*", "CollisionShape3D", false, false).size() == 5
			and batch.get_node_or_null(^"Mesh") != null,
		"the solid batch keeps the static collision profile and one shape per source"
	)
	_check(
		batch != null and (batch.get_meta(&"authored_instance_transforms", []) as Array).size() == 5,
		"the solid batch publishes the authored placement of every piece it absorbed"
	)
	var batch_mesh := batch.get_node_or_null(^"Mesh") as MeshInstance3D if batch != null else null
	_check(
		batch_mesh != null and batch_mesh.mesh.get_surface_count() == 2
			and batch_mesh.material_override == null
			and batch_mesh.get_surface_override_material(0) == material
			and batch_mesh.get_surface_override_material(1) == other_material,
		"each source material keeps its own surface and its own binding"
	)
	var visual_batch := holder.get_node_or_null(^"DressingRenderBatch01") as MeshInstance3D
	_check(
		visual_batch != null and visual_batch.mesh.get_surface_count() == 2
			and visual_batch.get_surface_override_material(0) == material
			and visual_batch.get_surface_override_material(1) == other_material,
		"the visual batch keeps one surface and one binding per source material"
	)

	holder.queue_free()
	await process_frame
	_finish()


func _finish() -> void:
	if _failures.is_empty():
		print("STATION_DRESSING_BATCH_TEST_OK assertions=%d" % _assertions)
		quit(0)
		return
	for failure in _failures:
		printerr("STATION_DRESSING_BATCH_TEST_FAILED: %s" % failure)
	quit(1)
