class_name StationDressingBatch
extends RefCounted

## Scene-node consolidation for procedurally built station dressing (Phase 10 §2).
##
## `StaticShadowBatch` already merges an explicitly supplied roster into one
## shadow caster. This does the same arithmetic for the *colour* pass and for the
## scene tree itself: sibling dressing is replaced by one merged
## `MeshInstance3D`, and sibling `_box(collidable = true)` triples
## (`StaticBody3D` + `Mesh` + `Collision`) that share one static collision
## profile collapse into a single `StaticBody3D` that keeps **one
## `CollisionShape3D` per original piece**.
##
## A batch carries one surface per distinct source material, in first-appearance
## order, bound through `set_surface_override_material()`. Triangle count, surface
## count, material bindings and world placement are therefore all identical to
## the separate nodes; only the node and renderer counts fall.
##
## What this deliberately never does, because each of those is an indexing
## contract another system reads by node identity:
##
## * It never merges, moves, resizes or reorders a collision shape. Every shape
##   resource is reused untouched and re-seated at the exact transform that
##   reproduces its former world placement, so the physical station is bit-for-bit
##   the station that was authored.
## * It never touches a node that carries metadata, a script, a group, an
##   incoming signal connection, a child, or a name a caller passes in the
##   protected roster. Walkable-surface, evidence, route, interaction, berth and
##   lifecycle authority all live on metadata or on a looked-up name.
## * It never touches a node that any live script variable anywhere in the scene
##   still holds a reference to. That scan is the guard against freeing something
##   a module is going to call back into.
## * It never crosses a parent boundary. A batch is always built in the exact
##   parent its sources stood in, so a container that a module hides, moves or
##   swaps still owns the same geometry afterwards.
##
## The result is fewer scene nodes and fewer renderers for identical triangles at
## identical world transforms.

## Transform components below this are treated as the identity for the mirrored
## basis check; `_rounded_box_mesh` output is axis aligned to well within it.
const DETERMINANT_EPSILON := 1e-6

const MESH_CHILD_NAME := "Mesh"
const COLLISION_CHILD_NAME := "Collision"

## A merged bound this broad and this thin, facing up, is the exact shape the
## station's route-surface discovery reads as a walkable plate
## (`tests/station_surface_playability_test.gd`). Several separate props can
## aggregate into that shape while the space between them stays empty, so a batch
## that would produce one is refused and its sources are left alone. The numbers
## are that audit's own published thresholds.
const PLATE_MIN_BREADTH := 0.65
const PLATE_MAX_THICKNESS := 0.82

## No batch may span more than this on any axis.
##
## A merged mesh is one bounding volume, and the station reads bounding volumes:
## the walkability sweep decides what is a discrete prop, the service-line audit
## decides what a piece is resting on, and the renderer decides what to cull. A
## batch that spanned a whole module would answer all three questions about
## volumes it does not actually occupy. Groups are therefore split into
## locality-bounded runs instead of being merged wholesale. Uncapped, the same
## groups produced an 89 x 17 x 75 m box across most of the station, which
## reported a deliberately lifted service-line piece as still seated and made
## route-surface discovery read two aggregate boxes as unsupported walkable
## plates.
##
## Sixteen metres is also the value that measured the least rendered deviation
## under the Compatibility renderer, whose per-object light list is capped: a
## batch's bound decides which lights reach it, so an over-large batch can pick up
## a practical none of its pieces stood in, or drop one they all did. Caps of 8,
## 16 and 32 m were each captured against the untrimmed build from four
## walking-distance framings; 16 m won on every one of them. Forward+, which the
## desktop build ships and which clusters lights instead of capping them per
## object, is inside its own same-build noise floor at all three caps.
const MAX_BATCH_EXTENT := 16.0


## One consolidation pass over `module_root`'s subtree.
##
## `protected` names are never removed and never folded, at any depth. Returns a
## report with the exact node arithmetic so a caller or test can assert it.
static func consolidate(
		module_root: Node3D,
		protected: PackedStringArray = PackedStringArray(),
		reference_root: Node = null
	) -> Dictionary:
	if not is_instance_valid(module_root) or not module_root.is_inside_tree():
		return _empty_report(&"module_root_unavailable")
	return consolidate_with_references(
		module_root,
		protected,
		_collect_script_referenced_objects(
			reference_root if reference_root != null else module_root.get_tree().root
		)
	)


## Several module roots under one reference scan.
##
## The scan walks every script variable in the scene, so it is the expensive half
## of this pass and must not be repeated per module.
static func consolidate_modules(
		module_roots: Array,
		protected: PackedStringArray,
		reference_root: Node
	) -> Array[Dictionary]:
	var reports: Array[Dictionary] = []
	if reference_root == null or not is_instance_valid(reference_root):
		return reports
	var referenced := _collect_script_referenced_objects(reference_root)
	for module_variant in module_roots:
		var module := module_variant as Node3D
		if not is_instance_valid(module) or not module.is_inside_tree():
			reports.append(_empty_report(&"module_root_unavailable"))
			continue
		reports.append(consolidate_with_references(module, protected, referenced))
	return reports


static func _empty_report(reason: StringName) -> Dictionary:
	return {
		"applied": false,
		"reason": reason,
		"removed_nodes": 0,
		"added_nodes": 0,
		"solid_batches": 0,
		"solid_sources": 0,
		"visual_batches": 0,
		"visual_sources": 0,
		"folded_body_meshes": 0,
		"folded_mesh_batches": 0,
	}


static func consolidate_with_references(
		module_root: Node3D,
		protected: PackedStringArray,
		referenced: Dictionary
	) -> Dictionary:
	var report := {
		"applied": false,
		"reason": &"",
		"removed_nodes": 0,
		"added_nodes": 0,
		"solid_batches": 0,
		"solid_sources": 0,
		"visual_batches": 0,
		"visual_sources": 0,
		"folded_body_meshes": 0,
		"folded_mesh_batches": 0,
	}
	if not is_instance_valid(module_root) or not module_root.is_inside_tree():
		report["reason"] = &"module_root_unavailable"
		return report
	var protected_set := {}
	for name_value in protected:
		protected_set[String(name_value)] = true
	var parents: Array[Node] = []
	_collect_parents(module_root, parents)
	for parent in parents:
		_consolidate_parent(parent as Node3D, protected_set, referenced, report)
	report["applied"] = true
	report["reason"] = &"consolidated"
	return report


static func _collect_parents(node: Node, out: Array[Node]) -> void:
	if node is Node3D:
		out.append(node)
	for child in node.get_children():
		_collect_parents(child, out)


static func _consolidate_parent(
		parent: Node3D,
		protected_set: Dictionary,
		referenced: Dictionary,
		report: Dictionary
	) -> void:
	# A parent that this pass already emptied is still in the collected roster
	# until its deferred free lands, and a detached node has no global transform.
	if parent == null or not is_instance_valid(parent) or not parent.is_inside_tree():
		return
	# Sibling order is the authored order; grouping keeps it so a merged mesh
	# emits its surfaces in the same sequence the separate nodes submitted them.
	var solid_groups := {}
	var visual_groups := {}
	for child in parent.get_children():
		if child is StaticBody3D:
			var body := child as StaticBody3D
			var mesh_child := body.get_node_or_null(NodePath(MESH_CHILD_NAME)) as MeshInstance3D
			if mesh_child == null or not _mesh_is_mergeable(mesh_child, referenced):
				continue
			if _is_mergeable_solid(body, protected_set, referenced):
				var solid_key := "%d|%d|%d|%d" % [
					int(mesh_child.cast_shadow),
					int(mesh_child.gi_mode),
					body.collision_layer,
					body.collision_mask,
				]
				if not solid_groups.has(solid_key):
					solid_groups[solid_key] = []
				(solid_groups[solid_key] as Array).append(body)
				continue
			# A body that keeps its own node keeps its own `Mesh` child. The
			# station's route-surface roster resolves `<body>/Mesh` and compares
			# that renderer's bounds against the body's collider, so lifting the
			# renderer out of a surviving body would break an audit even though
			# nothing visible moved.
			continue
		if child is MultiMeshInstance3D:
			continue
		if child is MeshInstance3D:
			var visual := child as MeshInstance3D
			if not _node_is_free_standing(visual, protected_set, referenced):
				continue
			if not _mesh_is_mergeable(visual, referenced):
				continue
			var visual_key := "%d|%d" % [
				int(visual.cast_shadow), int(visual.gi_mode)
			]
			if not visual_groups.has(visual_key):
				visual_groups[visual_key] = []
			(visual_groups[visual_key] as Array).append(visual)

	for key in solid_groups:
		for bodies in _local_chunks(parent, solid_groups[key] as Array):
			if bodies.size() < 2:
				continue
			if _build_solid_batch(parent, bodies):
				report["solid_batches"] = int(report["solid_batches"]) + 1
				report["solid_sources"] = int(report["solid_sources"]) + bodies.size()
				report["removed_nodes"] = int(report["removed_nodes"]) + bodies.size() * 3
				report["added_nodes"] = int(report["added_nodes"]) + bodies.size() + 2
	for key in visual_groups:
		for visuals in _local_chunks(parent, visual_groups[key] as Array):
			if visuals.size() < 2:
				continue
			if _build_visual_batch(parent, visuals, "DressingRenderBatch"):
				report["visual_batches"] = int(report["visual_batches"]) + 1
				report["visual_sources"] = int(report["visual_sources"]) + visuals.size()
				report["removed_nodes"] = int(report["removed_nodes"]) + visuals.size()
				report["added_nodes"] = int(report["added_nodes"]) + 1


## Splits one same-render-state group into runs that each stay inside
## `MAX_BATCH_EXTENT` on every axis, walking the children in their authored
## order so a run is a contiguous stretch of the thing the module built.
static func _local_chunks(parent: Node3D, sources: Array) -> Array:
	var chunks: Array = []
	var current: Array = []
	var bounds := AABB()
	for source_variant in sources:
		var box := _source_bounds_in_parent(parent, source_variant as Node3D)
		if current.is_empty():
			current = [source_variant]
			bounds = box
			continue
		var merged := bounds.merge(box)
		if merged.size.x > MAX_BATCH_EXTENT \
				or merged.size.y > MAX_BATCH_EXTENT \
				or merged.size.z > MAX_BATCH_EXTENT:
			chunks.append(current)
			current = [source_variant]
			bounds = box
			continue
		current.append(source_variant)
		bounds = merged
	if not current.is_empty():
		chunks.append(current)
	return chunks


## Where a source's drawn volume sits in its batch parent's own space.
static func _source_bounds_in_parent(parent: Node3D, source: Node3D) -> AABB:
	var visual := source as MeshInstance3D
	if visual == null:
		visual = source.get_node_or_null(NodePath(MESH_CHILD_NAME)) as MeshInstance3D
	if visual == null or visual.mesh == null:
		return AABB(parent.to_local(source.global_position), Vector3.ZERO)
	var placement := parent.global_transform.affine_inverse() * visual.global_transform
	return placement * visual.mesh.get_aabb()


## A node nothing else can be holding on to: no script, no metadata, no group,
## no incoming signal, no children, and not reachable from any script variable.
static func _node_is_free_standing(
		node: Node,
		protected_set: Dictionary,
		referenced: Dictionary
	) -> bool:
	if node == null or not is_instance_valid(node):
		return false
	if protected_set.has(String(node.name)):
		return false
	if node.get_script() != null:
		return false
	if not node.get_meta_list().is_empty():
		return false
	if not node.get_groups().is_empty():
		return false
	if _has_node_driven_connection(node):
		return false
	if node.owner != null:
		return false
	if referenced.has(node.get_instance_id()):
		return false
	return true


## Whether another *node* drives this one through a signal.
##
## Every `MeshInstance3D` that owns a mesh carries engine-internal connections
## from that resource's `changed` signal, so "no incoming connection at all" is
## never true for a renderer. What matters here is whether some other node in the
## scene is wired to this one, because that is a live dependency the merge would
## break.
static func _has_node_driven_connection(node: Node) -> bool:
	for connection in node.get_incoming_connections():
		var source_signal := connection.get("signal") as Signal
		if source_signal == null:
			continue
		if source_signal.get_object() is Node:
			return true
	for signal_info in node.get_signal_list():
		for connection in node.get_signal_connection_list(signal_info["name"]):
			var callable_value := connection.get("callable") as Callable
			if callable_value != null and callable_value.get_object() != null:
				return true
	return false


## One ordinary opaque triangle renderer with a resolvable material on every
## surface, drawn on the default layer with no fade, LOD band or skin.
##
## The material may arrive as a `material_override`, a per-surface override, or
## the surface's own material; `_surface_material()` resolves each surface the
## way the renderer itself does, so a batch reproduces the exact binding.
static func _mesh_is_mergeable(visual: MeshInstance3D, referenced: Dictionary) -> bool:
	if not is_instance_valid(visual) or visual.get_child_count() != 0:
		return false
	if not visual.visible:
		return false
	if visual.skin != null or visual.material_overlay != null:
		return false
	if visual.layers != 1:
		return false
	if not is_zero_approx(visual.transparency):
		return false
	if not is_zero_approx(visual.visibility_range_begin) \
			or not is_zero_approx(visual.visibility_range_end):
		return false
	if not visual.visibility_parent.is_empty():
		return false
	if visual.gi_mode != GeometryInstance3D.GI_MODE_DISABLED \
			and visual.gi_mode != GeometryInstance3D.GI_MODE_STATIC:
		return false
	var mesh := visual.mesh as ArrayMesh
	if mesh == null or mesh.get_surface_count() < 1:
		return false
	if mesh.get_blend_shape_count() != 0 or mesh.shadow_mesh != null:
		return false
	for surface_index in mesh.get_surface_count():
		if mesh.surface_get_primitive_type(surface_index) != Mesh.PRIMITIVE_TRIANGLES:
			return false
		if _surface_material(visual, surface_index) == null:
			return false
	if visual.transform.basis.determinant() <= DETERMINANT_EPSILON:
		return false
	return true


## The material this renderer actually draws `surface_index` with, in Godot's own
## precedence: instance override, then per-surface override, then the surface's
## own material.
static func _surface_material(visual: MeshInstance3D, surface_index: int) -> Material:
	if visual.material_override != null:
		return visual.material_override
	var surface_override := visual.get_surface_override_material(surface_index)
	if surface_override != null:
		return surface_override
	var mesh := visual.mesh as ArrayMesh
	if mesh == null:
		return null
	return mesh.surface_get_material(surface_index)


## A `_box(collidable = true)` triple with no authority of its own: exactly the
## generated `Mesh`/`Collision` pair, a box shape, default static-body physics.
static func _is_mergeable_solid(
		body: StaticBody3D,
		protected_set: Dictionary,
		referenced: Dictionary
	) -> bool:
	if not _node_is_free_standing(body, protected_set, referenced):
		return false
	if body.get_child_count() != 2:
		return false
	var mesh_child := body.get_node_or_null(NodePath(MESH_CHILD_NAME)) as MeshInstance3D
	var collision_child := body.get_node_or_null(
		NodePath(COLLISION_CHILD_NAME)
	) as CollisionShape3D
	if mesh_child == null or collision_child == null:
		return false
	if not _mesh_is_mergeable(mesh_child, referenced):
		return false
	if not mesh_child.get_meta_list().is_empty() or mesh_child.get_script() != null:
		return false
	if not collision_child.get_meta_list().is_empty() or collision_child.get_script() != null:
		return false
	if collision_child.get_child_count() != 0 or collision_child.disabled:
		return false
	if not (collision_child.shape is BoxShape3D):
		return false
	if referenced.has(mesh_child.get_instance_id()) \
			or referenced.has(collision_child.get_instance_id()):
		return false
	if body.physics_material_override != null:
		return false
	if not body.constant_linear_velocity.is_zero_approx() \
			or not body.constant_angular_velocity.is_zero_approx():
		return false
	if not is_equal_approx(body.collision_priority, 1.0):
		return false
	if body.process_mode != Node.PROCESS_MODE_INHERIT:
		return false
	return true


## Replaces N `_box` triples with one body, N shapes and one merged renderer.
static func _build_solid_batch(parent: Node3D, bodies: Array) -> bool:
	var sources: Array[MeshInstance3D] = []
	var offsets: Array[Transform3D] = []
	for body_variant in bodies:
		var body := body_variant as StaticBody3D
		var mesh_child := body.get_node(NodePath(MESH_CHILD_NAME)) as MeshInstance3D
		sources.append(mesh_child)
		offsets.append(body.transform * mesh_child.transform)
	var merged := _merge(sources, offsets)
	if merged.is_empty() or _reads_as_walkable_plate(merged["mesh"] as ArrayMesh):
		return false
	var first := bodies[0] as StaticBody3D
	var first_mesh := first.get_node(NodePath(MESH_CHILD_NAME)) as MeshInstance3D
	var batch := StaticBody3D.new()
	batch.name = _batch_name(parent, "SolidBatch")
	batch.collision_layer = first.collision_layer
	batch.collision_mask = first.collision_mask
	batch.input_ray_pickable = first.input_ray_pickable

	var visual := MeshInstance3D.new()
	visual.name = MESH_CHILD_NAME
	visual.mesh = merged["mesh"] as ArrayMesh
	visual.cast_shadow = first_mesh.cast_shadow
	visual.gi_mode = first_mesh.gi_mode
	batch.add_child(visual)
	_apply_surface_materials(visual, merged["materials"] as Array)

	var authored: Array[Transform3D] = []
	var index := 0
	for body_variant in bodies:
		var body := body_variant as StaticBody3D
		var collision_child := body.get_node(NodePath(COLLISION_CHILD_NAME)) as CollisionShape3D
		var seated := CollisionShape3D.new()
		seated.name = "Collision%02d" % (index + 1)
		seated.shape = collision_child.shape
		seated.transform = body.transform * collision_child.transform
		batch.add_child(seated)
		authored.append(offsets[index])
		index += 1
	batch.set_meta(&"authored_instance_transforms", authored.duplicate())
	batch.set_meta(&"station_dressing_batch", true)
	batch.set_meta(&"batched_source_count", bodies.size())
	parent.add_child(batch)
	for body_variant in bodies:
		var body := body_variant as StaticBody3D
		parent.remove_child(body)
		body.queue_free()
	return true


## Replaces N sibling renderers with one merged renderer in the same parent.
static func _build_visual_batch(parent: Node3D, visuals: Array, suffix: String) -> bool:
	var sources: Array[MeshInstance3D] = []
	var offsets: Array[Transform3D] = []
	var parent_inverse := parent.global_transform.affine_inverse()
	for visual_variant in visuals:
		var visual := visual_variant as MeshInstance3D
		sources.append(visual)
		offsets.append(parent_inverse * visual.global_transform)
	var merged := _merge(sources, offsets)
	if merged.is_empty() or _reads_as_walkable_plate(merged["mesh"] as ArrayMesh):
		return false
	var first := visuals[0] as MeshInstance3D
	var batch := MeshInstance3D.new()
	batch.name = _batch_name(parent, suffix)
	batch.mesh = merged["mesh"] as ArrayMesh
	batch.cast_shadow = first.cast_shadow
	batch.gi_mode = first.gi_mode
	batch.set_meta(&"authored_instance_transforms", offsets.duplicate())
	batch.set_meta(&"station_dressing_batch", true)
	batch.set_meta(&"batched_source_count", visuals.size())
	parent.add_child(batch)
	_apply_surface_materials(batch, merged["materials"] as Array)
	for visual_variant in visuals:
		var visual := visual_variant as MeshInstance3D
		var holder := visual.get_parent()
		if holder != null:
			holder.remove_child(visual)
		visual.queue_free()
	return true


## One surface per source material, bound exactly as the sources bound it.
##
## The sources each carried their material as a `material_override`, which
## overrides every surface of its own mesh and only that mesh. The merged mesh
## has one surface per distinct material, so the same binding is expressed as a
## per-surface override; nothing about the shading, the surface count or the
## submission order changes.
static func _apply_surface_materials(visual: MeshInstance3D, materials: Array) -> void:
	for index in materials.size():
		visual.set_surface_override_material(index, materials[index] as Material)


## Whether a merged bound would present itself as a floor plate. See the
## `PLATE_*` constants: the aggregate of several props can take that shape while
## the volume between them is empty, and a rendered plate with nothing under it
## is a real defect the station audits for.
static func _reads_as_walkable_plate(mesh: ArrayMesh) -> bool:
	if mesh == null:
		return false
	var size := mesh.get_aabb().size
	return size.x >= PLATE_MIN_BREADTH \
		and size.z >= PLATE_MIN_BREADTH \
		and size.y <= PLATE_MAX_THICKNESS


static func _batch_name(parent: Node3D, suffix: String) -> String:
	var index := 1
	var candidate := "%s%02d" % [suffix, index]
	while parent.has_node(NodePath(candidate)):
		index += 1
		candidate = "%s%02d" % [suffix, index]
	return candidate


## Exact triangle-for-triangle merge of `sources` placed at `offsets`, emitted as
## one surface per distinct source material in first-appearance order.
##
## Returns `{}` when any source cannot be merged losslessly, so the caller leaves
## the originals exactly as they were.
static func _merge(sources: Array[MeshInstance3D], offsets: Array[Transform3D]) -> Dictionary:
	if sources.is_empty() or sources.size() != offsets.size():
		return {}
	var materials: Array[Material] = []
	var order: Array[int] = []
	var buckets: Dictionary = {}
	for source_index in sources.size():
		var mesh := sources[source_index].mesh as ArrayMesh
		if mesh == null:
			return {}
		for surface_index in mesh.get_surface_count():
			var material := _surface_material(sources[source_index], surface_index)
			if material == null:
				return {}
			var material_id := material.get_instance_id()
			if not buckets.has(material_id):
				buckets[material_id] = []
				order.append(material_id)
				materials.append(material)
			(buckets[material_id] as Array).append(
				Vector2i(source_index, surface_index)
			)
	var merged := ArrayMesh.new()
	for material_id in order:
		var surface := _merge_surface(sources, offsets, buckets[material_id] as Array)
		if surface.is_empty():
			return {}
		merged.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, surface)
	if merged.get_surface_count() != materials.size():
		return {}
	return {"mesh": merged, "materials": materials}


static func _merge_surface(
		sources: Array[MeshInstance3D],
		offsets: Array[Transform3D],
		members: Array
	) -> Array:
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var tangents := PackedFloat32Array()
	var uvs := PackedVector2Array()
	var indices := PackedInt32Array()
	var has_tangents := true
	var has_uvs := true
	for member_variant in members:
		var member := member_variant as Vector2i
		var mesh := sources[member.x].mesh as ArrayMesh
		var arrays := mesh.surface_get_arrays(member.y)
		var source_vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var source_normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
		if source_vertices.is_empty() or source_normals.size() != source_vertices.size():
			return []
		var placement := offsets[member.x]
		var normal_basis := placement.basis.inverse().transposed()
		var offset := vertices.size()
		for index in source_vertices.size():
			vertices.append(placement * source_vertices[index])
			normals.append((normal_basis * source_normals[index]).normalized())
		if has_tangents and arrays[Mesh.ARRAY_TANGENT] is PackedFloat32Array \
				and (arrays[Mesh.ARRAY_TANGENT] as PackedFloat32Array).size() \
					== source_vertices.size() * 4:
			var source_tangents: PackedFloat32Array = arrays[Mesh.ARRAY_TANGENT]
			for index in source_vertices.size():
				var tangent := (placement.basis * Vector3(
					source_tangents[index * 4],
					source_tangents[index * 4 + 1],
					source_tangents[index * 4 + 2]
				)).normalized()
				tangents.append(tangent.x)
				tangents.append(tangent.y)
				tangents.append(tangent.z)
				tangents.append(source_tangents[index * 4 + 3])
		else:
			has_tangents = false
		if has_uvs and arrays[Mesh.ARRAY_TEX_UV] is PackedVector2Array \
				and (arrays[Mesh.ARRAY_TEX_UV] as PackedVector2Array).size() \
					== source_vertices.size():
			uvs.append_array(arrays[Mesh.ARRAY_TEX_UV] as PackedVector2Array)
		else:
			has_uvs = false
		var source_indices := PackedInt32Array()
		if arrays[Mesh.ARRAY_INDEX] is PackedInt32Array:
			source_indices = arrays[Mesh.ARRAY_INDEX]
		if source_indices.is_empty():
			if source_vertices.size() % 3 != 0:
				return []
			for index in source_vertices.size():
				indices.append(offset + index)
		else:
			if source_indices.size() % 3 != 0:
				return []
			for index in source_indices:
				if index < 0 or index >= source_vertices.size():
					return []
				indices.append(offset + index)
	if vertices.is_empty() or indices.is_empty():
		return []
	var surface := []
	surface.resize(Mesh.ARRAY_MAX)
	surface[Mesh.ARRAY_VERTEX] = vertices
	surface[Mesh.ARRAY_NORMAL] = normals
	if has_tangents and tangents.size() == vertices.size() * 4:
		surface[Mesh.ARRAY_TANGENT] = tangents
	if has_uvs and uvs.size() == vertices.size():
		surface[Mesh.ARRAY_TEX_UV] = uvs
	surface[Mesh.ARRAY_INDEX] = indices
	return surface


## Every **node** any live script variable in the scene can still reach.
##
## The merge frees nodes, so anything a module is still holding must be off
## limits even when its own node looks anonymous. Only node identities are
## recorded: meshes and shapes are shared, cached resources here, and this pass
## never frees a resource.
static func _collect_script_referenced_objects(root: Node) -> Dictionary:
	var referenced := {}
	var visited := {}
	_visit_node_tree(root, referenced, visited)
	return referenced


static func _visit_node_tree(node: Node, referenced: Dictionary, visited: Dictionary) -> void:
	if node == null or not is_instance_valid(node):
		return
	_visit_script_variables(node, referenced, visited)
	for child in node.get_children():
		_visit_node_tree(child, referenced, visited)


static func _visit_script_variables(
		value: Object,
		referenced: Dictionary,
		visited: Dictionary
	) -> void:
	if value == null or not is_instance_valid(value) or value.get_script() == null:
		return
	var id := value.get_instance_id()
	if visited.has(id):
		return
	visited[id] = true
	for property in value.get_property_list():
		if int(property.get("usage", 0)) & PROPERTY_USAGE_SCRIPT_VARIABLE == 0:
			continue
		_visit_variant(value.get(property["name"]), referenced, visited)


static func _visit_variant(value: Variant, referenced: Dictionary, visited: Dictionary) -> void:
	match typeof(value):
		TYPE_OBJECT:
			if not is_instance_valid(value):
				return
			var object := value as Object
			if object is WeakRef:
				_visit_variant((object as WeakRef).get_ref(), referenced, visited)
				return
			if object is Node:
				referenced[object.get_instance_id()] = true
				return
			# A module's helper object can hold the node references instead.
			_visit_script_variables(object, referenced, visited)
		TYPE_ARRAY:
			for entry in value as Array:
				_visit_variant(entry, referenced, visited)
		TYPE_DICTIONARY:
			for key in value as Dictionary:
				_visit_variant(key, referenced, visited)
				_visit_variant((value as Dictionary)[key], referenced, visited)
