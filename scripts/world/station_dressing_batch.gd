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
## * It never touches a node that carries a script, a group, an incoming signal
##   connection, a child, or a name a caller passes in the protected roster.
##   Walkable-surface, evidence, route, interaction, berth and lifecycle
##   authority all live on metadata or on a looked-up name.
## * Authored **metadata** no longer refuses a piece outright, but it constrains
##   the group: a batch only ever absorbs pieces whose metadata is identical key
##   for key and value for value, it carries that metadata verbatim, and
##   `AUTHORED_PIECE_INDEX_META` records each piece's own copy, so a reader that
##   resolves metadata off the renderer reads what it read before. A key in
##   `KEEP_OUT_META_KEYS` still refuses, because those exist for no other
##   purpose than to keep this pass out.
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

## Marks a node this pass created.
const BATCH_META := &"station_dressing_batch"

## What the batch replaced, in the exact currencies a station module's own render
## census counts, so that census can still report the module as it was *built*.
##
## Several modules publish a frozen component-local allocation roster — node,
## renderer, drawn-copy, submission and unique-resource counts — and gate
## `validate()` on it. That roster is a statement about what the module builds,
## and this pass runs afterwards, from the world, over dressing the module no
## longer indexes by name. Without this record the module would have to either
## abandon the roster or restate it as a number that is only true while this pass
## is enabled; with it the module adds each batch's authored row back and keeps
## reporting exactly what it built, while `get_dressing_consolidation_report()`
## keeps reporting what the world folded.
const AUTHORED_CENSUS_META := &"station_dressing_batch_authored_census"

## The authored pieces a batch stands in for, one record each, in authored order.
##
## `AUTHORED_CENSUS_META` restores *counts*. This restores *identity*: it is the
## indexing contract that lets a suite ask the same question of a batched member
## that it used to ask of its own node. Each record carries the piece's authored
## name, its placement in the batch parent's space, its own metadata verbatim,
## the mesh's untransformed bound, its surface count and visibility, the resolved
## material of every surface, and — when the mesh outlives the merge — the source
## `Mesh` resource itself.
##
## The retained mesh is the reason a shared-stock audit survives batching without
## being weakened. Those audits prove "these N pieces are drawn from one mesh
## allocation" by comparing `a.mesh == b.mesh`; after a merge both nodes are gone
## and `a.mesh` would be the merged buffer. The index hands the audit the same
## resource it used to read off the node, so the identity it compares is the one
## it always compared. Holding the resource is also a *stronger* record than the
## `mesh_resource_ids` beside it: an instance id names a resource that may since
## have been freed, while a retained reference cannot be anything else.
##
## Retention is deliberately conditional. A mesh drawn only by the one piece the
## merge replaced is freed exactly as before, so the unique-mesh count still
## falls by the merge's full arithmetic. A mesh that is *shared* — drawn by
## another renderer, or held by a live script variable — is retained here, and
## that costs nothing, because the merge never had the right to free it.
const AUTHORED_PIECE_INDEX_META := &"station_dressing_batch_authored_pieces"

## The meta keys this pass writes. A node carrying any of them is something a
## previous pass produced, and is never folded again: its own index would
## otherwise be absorbed into a second batch that no longer records it.
const BATCH_OWNED_META_KEYS: Array[StringName] = [
	BATCH_META,
	AUTHORED_CENSUS_META,
	AUTHORED_PIECE_INDEX_META,
	&"authored_instance_transforms",
	&"batched_source_count",
	&"authored_piece",
]

## Metadata whose only job is to keep this pass out of a family.
##
## Until the tenth trim, *any* metadata refused a piece, and two habitat
## families quietly relied on that: the builder sets a marker and its comment
## says outright that the marker is what keeps `StationDressingBatch` away. When
## the blanket metadata refusal was relaxed, both families started folding and
## one of them immediately produced a real defect —
## `tools/station_walkability_sweep.gd` reported a twentieth `walk_through`,
## a 1.32 m board face merged out of 5 cm plates that reaches into the standing
## capsule of the cells in front of it.
##
## So the opt-out is now a contract instead of a side effect.
## `NO_BATCH_META` is the key a builder should use from here; the two legacy
## markers are honoured by name because their builders document them as the
## refusal and it would be dishonest to quietly drop an authored decision while
## claiming the pass weakens nothing:
##
## * `crew_berth_roster_piece` — `habitat_spine.gd::_build_common_berth_roster`,
##   the board face above.
## * `side_window_frame` — `habitat_spine.gd`, where
##   `tests/station_surface_playability_test.gd` measures the annex connector's
##   clearance to a *named discrete frame* rather than to an aggregate bound.
const NO_BATCH_META := &"station_dressing_batch_opt_out"
const KEEP_OUT_META_KEYS: Array[StringName] = [
	NO_BATCH_META,
	&"crew_berth_roster_piece",
	&"side_window_frame",
]

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
##
## The second node trim re-tested 4 m and 8 m against the habitat and the Aft
## operations room and **left the cap at 16 m**, because there the Compatibility
## deviation is not a function of the bound at all: the Aft coordinator desk top
## renders byte-identically at 4 m and at 16 m (RGB 192/188/173 either way
## against 90/113/119 unbatched) and the habitat corridor measured *worse* at
## 4 m than at 16. What moves under that renderer is which eight lights win an
## instance's per-object slots, and that ordering depends on how many instances
## the room has, not on how large any one of them is. Tightening the cap buys
## nothing there and costs 339 of the 840 nodes this pass saves.
const MAX_BATCH_EXTENT := 16.0

## A merge may be as tall as its tallest piece and no taller.
##
## `_reads_as_walkable_plate` refuses an aggregate that would read as a *floor*.
## This refuses the other shape the same sweep blames: an aggregate that reads as
## a **standing solid**. `tools/station_walkability_sweep.gd` reports
## `walk_through` for any rendered piece at least `SWEEP_PIECE_HEIGHT` tall on a
## walkable cell with no collider anywhere in its volume, and a stack of short
## shelf boards at different heights satisfies that the moment they share one
## bounding volume, even though the air between them is still air.
##
## The tenth trim found this the honest way: relaxing the metadata refusal let
## the habitat's crew-berth roster fold, and the sweep immediately reported one
## new `walk_through` at 1.32 m that no individual board had produced. A merged
## bound taller than its own tallest source is manufacturing occupancy, so it is
## refused and the sources are left standing.
##
## Only visual batches need this. A solid batch keeps one `CollisionShape3D` per
## authored piece, so its volume is collided exactly where it was before.
const SWEEP_PIECE_HEIGHT := 0.4
const AGGREGATE_HEIGHT_TOLERANCE := 0.002


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
	var scan_root := reference_root if reference_root != null else module_root.get_tree().root
	return consolidate_with_references(
		module_root,
		protected,
		_collect_script_referenced_objects(scan_root),
		count_mesh_uses(scan_root)
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
	var mesh_uses := count_mesh_uses(reference_root)
	for module_variant in module_roots:
		var module := module_variant as Node3D
		if not is_instance_valid(module) or not module.is_inside_tree():
			reports.append(_empty_report(&"module_root_unavailable"))
			continue
		reports.append(
			consolidate_with_references(module, protected, referenced, mesh_uses)
		)
	return reports


## How many renderers in `root`'s tree draw each mesh resource, keyed by the
## resource's instance id.
##
## The piece index uses this to decide whether a merge is allowed to let a source
## mesh go. A mesh drawn once is the merge's to free; a mesh drawn more than once
## is shared stock the merge never owned, and the index keeps the resource so the
## audits that prove that sharing can still read it.
static func count_mesh_uses(root: Node) -> Dictionary:
	var uses := {}
	_count_mesh_uses_into(root, uses)
	return uses


static func _count_mesh_uses_into(node: Node, uses: Dictionary) -> void:
	var visual := node as MeshInstance3D
	if visual != null and visual.mesh != null:
		var id := visual.mesh.get_instance_id()
		uses[id] = int(uses.get(id, 0)) + 1
	var multi := node as MultiMeshInstance3D
	if multi != null and multi.multimesh != null and multi.multimesh.mesh != null:
		var multi_id := multi.multimesh.mesh.get_instance_id()
		uses[multi_id] = int(uses.get(multi_id, 0)) + 1
	for child in node.get_children():
		_count_mesh_uses_into(child, uses)


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
	}


static func consolidate_with_references(
		module_root: Node3D,
		protected: PackedStringArray,
		referenced: Dictionary,
		mesh_uses: Dictionary = {}
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
	}
	if not is_instance_valid(module_root) or not module_root.is_inside_tree():
		report["reason"] = &"module_root_unavailable"
		return report
	var protected_set := {}
	for name_value in protected:
		protected_set[String(name_value)] = true
	var uses := mesh_uses
	if uses.is_empty():
		uses = count_mesh_uses(module_root)
	var parents: Array[Node] = []
	_collect_parents(module_root, parents)
	for parent in parents:
		_consolidate_parent(parent as Node3D, protected_set, referenced, uses, report)
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
		mesh_uses: Dictionary,
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
				var solid_key := "%d|%d|%d|%d|%s|%s" % [
					int(mesh_child.cast_shadow),
					int(mesh_child.gi_mode),
					body.collision_layer,
					body.collision_mask,
					_metadata_digest(body),
					_metadata_digest(mesh_child),
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
			var visual_key := "%d|%d|%s" % [
				int(visual.cast_shadow), int(visual.gi_mode), _metadata_digest(visual)
			]
			if not visual_groups.has(visual_key):
				visual_groups[visual_key] = []
			(visual_groups[visual_key] as Array).append(visual)

	for key in solid_groups:
		for bodies in _local_chunks(parent, solid_groups[key] as Array):
			if bodies.size() < 2:
				continue
			if _build_solid_batch(parent, bodies, mesh_uses):
				report["solid_batches"] = int(report["solid_batches"]) + 1
				report["solid_sources"] = int(report["solid_sources"]) + bodies.size()
				report["removed_nodes"] = int(report["removed_nodes"]) + bodies.size() * 3
				report["added_nodes"] = int(report["added_nodes"]) + bodies.size() + 2
	for key in visual_groups:
		for visuals in _local_chunks(parent, visual_groups[key] as Array):
			if visuals.size() < 2:
				continue
			if _build_visual_batch(parent, visuals, "DressingRenderBatch", mesh_uses):
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


## A node nothing else can be holding on to: no script, no group, no incoming
## signal, no children, not reachable from any script variable, and no metadata
## this pass itself wrote.
##
## Ordinary authored metadata no longer disqualifies a piece. It used to, because
## a merged node could not answer a per-piece metadata question; it can now,
## because a batch only ever absorbs pieces whose metadata is *identical* key for
## key and value for value (`_metadata_digest` is part of every group key), it
## carries that metadata verbatim, and `AUTHORED_PIECE_INDEX_META` records each
## piece's own copy. A reader that resolves metadata off the renderer therefore
## reads the same answer it read before, whether it reaches the batch or the
## index. Metadata whose value differs between two pieces keeps them in separate
## groups, so a per-piece value is never averaged into one.
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
	if _carries_batch_metadata(node):
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


## Whether `node` carries a meta key this pass itself writes.
static func _carries_batch_metadata(node: Node) -> bool:
	for key in BATCH_OWNED_META_KEYS:
		if node.has_meta(key):
			return true
	for key in KEEP_OUT_META_KEYS:
		if node.has_meta(key):
			return true
	return false


## A node's metadata as a stable string, so two pieces group together only when
## every key *and* every value matches.
##
## `var_to_str` is used rather than `hash()` because a hash collision would let
## two different values share a group, which is exactly the mistake this guard
## exists to prevent. Keys are sorted so authoring order cannot split a group.
static func _metadata_digest(node: Node) -> String:
	var keys := node.get_meta_list()
	if keys.is_empty():
		return ""
	var names := PackedStringArray()
	for key in keys:
		names.append(String(key))
	names.sort()
	var parts := PackedStringArray()
	for name_value in names:
		parts.append("%s=%s" % [
			name_value, var_to_str(node.get_meta(StringName(name_value)))
		])
	return "|".join(parts)


## `node`'s metadata as a dictionary, for the piece index and for re-seating the
## same metadata on the batch that stands in for it.
static func _metadata_of(node: Node) -> Dictionary:
	var out := {}
	for key in node.get_meta_list():
		out[String(key)] = node.get_meta(key)
	return out


## Copies the group's shared metadata onto the batch that replaces it.
static func _seat_shared_metadata(batch: Node, metadata: Dictionary) -> void:
	for key in metadata:
		batch.set_meta(StringName(String(key)), metadata[key])


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
	if _carries_batch_metadata(mesh_child) or mesh_child.get_script() != null:
		return false
	# Collision authority is never restated. A shape this pass re-seats keeps its
	# own node, and the only meta it is given is the `authored_piece` name that
	# lets a seam or overlap audit blame the piece rather than the batch, so a
	# shape that already carries authored metadata is left where it stands.
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
## One index record per authored piece a batch is about to replace.
##
## `names` and `offsets` run parallel to `sources`. `mesh_uses` decides
## retention: a mesh some other renderer also draws is kept in the record, a mesh
## only this piece drew is recorded by id and left for the merge to free.
static func _build_piece_index(
		names: PackedStringArray,
		sources: Array[MeshInstance3D],
		offsets: Array[Transform3D],
		metadata: Array[Dictionary],
		mesh_uses: Dictionary
	) -> Array:
	var index: Array = []
	for position in sources.size():
		var source := sources[position]
		var mesh := source.mesh as ArrayMesh
		var materials: Array[Material] = []
		var surfaces := 0
		if mesh != null:
			surfaces = mesh.get_surface_count()
			for surface_index in surfaces:
				materials.append(_surface_material(source, surface_index))
		var record := {
			"name": names[position],
			"transform": offsets[position],
			"local_transform": source.transform,
			"metadata": metadata[position],
			"materials": materials,
			"surfaces": surfaces,
			"visible": source.visible,
			"cast_shadow": int(source.cast_shadow),
			"gi_mode": int(source.gi_mode),
			"mesh_id": mesh.get_instance_id() if mesh != null else 0,
			"aabb": mesh.get_aabb() if mesh != null else AABB(),
		}
		if mesh != null and int(mesh_uses.get(mesh.get_instance_id(), 0)) > 1:
			record["mesh"] = mesh
			record["mesh_retained"] = true
		else:
			record["mesh_retained"] = false
		index.append(record)
	return index


static func _build_solid_batch(
		parent: Node3D,
		bodies: Array,
		mesh_uses: Dictionary = {}
	) -> bool:
	var sources: Array[MeshInstance3D] = []
	var offsets: Array[Transform3D] = []
	var piece_names := PackedStringArray()
	var piece_metadata: Array[Dictionary] = []
	for body_variant in bodies:
		var body := body_variant as StaticBody3D
		var mesh_child := body.get_node(NodePath(MESH_CHILD_NAME)) as MeshInstance3D
		sources.append(mesh_child)
		offsets.append(body.transform * mesh_child.transform)
		# A solid piece is named by its body; its `Mesh` child is the generated
		# renderer inside it, and the seam and overlap audits blame the body.
		piece_names.append(String(body.name))
		piece_metadata.append(_metadata_of(body))
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
		# Seam and overlap audits name pieces, not batches.
		seated.set_meta(&"authored_piece", String(body.name))
		batch.add_child(seated)
		authored.append(offsets[index])
		index += 1
	# The group's metadata is identical across every member by construction, so
	# the batch carries it verbatim and a reader that resolves it off the
	# renderer reads exactly what it read before. Seated first, so a batch-owned
	# key below can never be overwritten by an authored one.
	_seat_shared_metadata(batch, piece_metadata[0] if not piece_metadata.is_empty() else {})
	_seat_shared_metadata(
		visual, _metadata_of(first_mesh)
	)
	batch.set_meta(&"authored_instance_transforms", authored.duplicate())
	batch.set_meta(BATCH_META, true)
	batch.set_meta(&"batched_source_count", bodies.size())
	batch.set_meta(
		AUTHORED_CENSUS_META,
		_authored_census(sources, bodies.size() * 3, bodies.size())
	)
	batch.set_meta(
		AUTHORED_PIECE_INDEX_META,
		_build_piece_index(piece_names, sources, offsets, piece_metadata, mesh_uses)
	)
	parent.add_child(batch)
	for body_variant in bodies:
		var body := body_variant as StaticBody3D
		parent.remove_child(body)
		body.queue_free()
	return true


## Replaces N sibling renderers with one merged renderer in the same parent.
static func _build_visual_batch(
		parent: Node3D,
		visuals: Array,
		suffix: String,
		mesh_uses: Dictionary = {}
	) -> bool:
	var sources: Array[MeshInstance3D] = []
	var offsets: Array[Transform3D] = []
	var piece_names := PackedStringArray()
	var piece_metadata: Array[Dictionary] = []
	var parent_inverse := parent.global_transform.affine_inverse()
	for visual_variant in visuals:
		var visual := visual_variant as MeshInstance3D
		sources.append(visual)
		offsets.append(parent_inverse * visual.global_transform)
		piece_names.append(String(visual.name))
		piece_metadata.append(_metadata_of(visual))
	var merged := _merge(sources, offsets)
	if merged.is_empty() or _reads_as_walkable_plate(merged["mesh"] as ArrayMesh):
		return false
	var carries_metadata := false
	for entry in piece_metadata:
		if not entry.is_empty():
			carries_metadata = true
			break
	if _manufactures_standing_solid(
			merged["mesh"] as ArrayMesh, sources, offsets, carries_metadata
		):
		return false
	var first := visuals[0] as MeshInstance3D
	var batch := MeshInstance3D.new()
	batch.name = _batch_name(parent, suffix)
	batch.mesh = merged["mesh"] as ArrayMesh
	batch.cast_shadow = first.cast_shadow
	batch.gi_mode = first.gi_mode
	_seat_shared_metadata(batch, piece_metadata[0] if not piece_metadata.is_empty() else {})
	batch.set_meta(&"authored_instance_transforms", offsets.duplicate())
	batch.set_meta(BATCH_META, true)
	batch.set_meta(&"batched_source_count", visuals.size())
	batch.set_meta(AUTHORED_CENSUS_META, _authored_census(sources, visuals.size(), 0))
	batch.set_meta(
		AUTHORED_PIECE_INDEX_META,
		_build_piece_index(piece_names, sources, offsets, piece_metadata, mesh_uses)
	)
	parent.add_child(batch)
	_apply_surface_materials(batch, merged["materials"] as Array)
	for visual_variant in visuals:
		var visual := visual_variant as MeshInstance3D
		var holder := visual.get_parent()
		if holder != null:
			holder.remove_child(visual)
		visual.queue_free()
	return true


## The render census of the nodes a batch is about to replace.
##
## `source_nodes` is how many scene nodes they occupied (three per `_box` triple,
## one per free-standing renderer) and `source_static_bodies` how many of those
## were bodies. Resource identities are recorded rather than the resources
## themselves: a module's census counts *distinct* meshes and materials, and
## holding the source meshes alive here would give back the memory the merge just
## freed. Godot's object ids are monotonic, so a recorded id is never a live
## resource other than the one it names.
static func _authored_census(
		sources: Array[MeshInstance3D],
		source_nodes: int,
		source_static_bodies: int
	) -> Dictionary:
	var submissions := 0
	var drawn_copies := 0
	var mesh_ids := PackedInt64Array()
	var material_ids := PackedInt64Array()
	for source in sources:
		var mesh := source.mesh as ArrayMesh
		if mesh == null:
			continue
		submissions += mesh.get_surface_count()
		drawn_copies += 1 if source.visible else 0
		if not mesh_ids.has(mesh.get_instance_id()):
			mesh_ids.append(mesh.get_instance_id())
		for surface_index in mesh.get_surface_count():
			var material := _surface_material(source, surface_index)
			if material != null and not material_ids.has(material.get_instance_id()):
				material_ids.append(material.get_instance_id())
	return {
		"descendant_nodes": source_nodes,
		"renderer_nodes": sources.size(),
		"drawn_copies": drawn_copies,
		"surface_submissions": submissions,
		"static_bodies": source_static_bodies,
		"mesh_resource_ids": mesh_ids,
		"material_resource_ids": material_ids,
	}


## The authored pieces `node` stands in for, or an empty array for anything this
## pass did not create.
static func authored_piece_index(node: Node) -> Array:
	if node == null or not is_instance_valid(node) \
			or not node.has_meta(AUTHORED_PIECE_INDEX_META):
		return []
	return node.get_meta(AUTHORED_PIECE_INDEX_META) as Array


## The authored piece named `piece_name` under `search_root`, whether it still
## stands as its own node or has been folded into a batch.
##
## This is the whole point of the indexing contract: an audit asks one question
## and gets the same answer on a batched and an unbatched build. The result is
## `{}` when nothing of that name was ever built, and otherwise carries:
##
## * `batched` — whether the piece is now drawn by a batch,
## * `node` — the piece's own node, or the batch that stands in for it,
## * `name`, `metadata`, `surfaces`, `visible`, `cast_shadow`, `gi_mode`,
## * `transform` — the placement in the batch parent's space, which for a live
##   node is its own local transform,
## * `aabb` — the piece's own untransformed mesh bound,
## * `mesh` — the piece's own mesh resource when that resource is still alive
##   (always for a live node; for a batched piece exactly when it was shared),
## * `mesh_id` — the identity of that resource either way,
## * `materials` — the resolved material of every surface.
##
## `search_root` is walked, so a caller may hand it a module, a craft or a single
## parent. A live node of that name always wins over an index record, because a
## piece that kept its own node is the stronger answer.
static func find_authored_piece(search_root: Node, piece_name: String) -> Dictionary:
	if search_root == null or not is_instance_valid(search_root):
		return {}
	var live := _find_live_piece(search_root, piece_name)
	if live != null:
		return _live_piece_record(live)
	var candidates := search_root.find_children("*", "", true, false)
	candidates.append(search_root)
	for candidate in candidates:
		for record_variant in authored_piece_index(candidate):
			var record := record_variant as Dictionary
			if String(record.get("name", "")) != piece_name:
				continue
			var resolved := record.duplicate()
			resolved["batched"] = true
			resolved["node"] = candidate
			return resolved
	return {}


static func _find_live_piece(search_root: Node, piece_name: String) -> MeshInstance3D:
	if search_root is MeshInstance3D and String(search_root.name) == piece_name:
		return search_root as MeshInstance3D
	for candidate in search_root.find_children(piece_name, "", true, false):
		var visual := candidate as MeshInstance3D
		if visual != null:
			return visual
		# A `_box` piece is named by its body and draws through its `Mesh` child.
		var mesh_child := candidate.get_node_or_null(NodePath(MESH_CHILD_NAME))
		if mesh_child is MeshInstance3D:
			return mesh_child as MeshInstance3D
	return null


static func _live_piece_record(visual: MeshInstance3D) -> Dictionary:
	var mesh := visual.mesh as ArrayMesh
	var materials: Array[Material] = []
	var surfaces := 0
	if mesh != null:
		surfaces = mesh.get_surface_count()
		for surface_index in surfaces:
			materials.append(_surface_material(visual, surface_index))
	var owner_node := visual.get_parent() if String(visual.name) == MESH_CHILD_NAME else visual
	return {
		"batched": false,
		"node": visual,
		"name": String(owner_node.name),
		"transform": visual.transform,
		"local_transform": visual.transform,
		"metadata": _metadata_of(owner_node),
		"materials": materials,
		"surfaces": surfaces,
		"visible": visual.visible,
		"cast_shadow": int(visual.cast_shadow),
		"gi_mode": int(visual.gi_mode),
		"mesh": mesh,
		"mesh_id": mesh.get_instance_id() if mesh != null else 0,
		"mesh_retained": true,
		"aabb": mesh.get_aabb() if mesh != null else AABB(),
	}


## The mesh resource authored piece `piece_name` is drawn from, or `null`.
##
## A resource-sharing audit compares this between two pieces exactly as it used
## to compare `a.mesh == b.mesh`, and gets the identical answer whether either
## piece is a node or a batched member. `null` means the piece is unknown, or
## that it was batched and its mesh was private to it — never that the sharing
## it once had has quietly stopped being proven, because a mesh that was shared
## is always retained.
static func authored_piece_mesh(search_root: Node, piece_name: String) -> Mesh:
	var record := find_authored_piece(search_root, piece_name)
	if record.is_empty():
		return null
	return record.get("mesh", null) as Mesh


## How many scene nodes `node` stands in for, beyond the ones it now occupies.
##
## Zero for everything this pass did not create, so a module's descendant walk
## can add it unconditionally and read identically on an unbatched build.
static func authored_node_delta(node: Node) -> int:
	if node == null or not is_instance_valid(node) or not node.has_meta(AUTHORED_CENSUS_META):
		return 0
	var census: Dictionary = node.get_meta(AUTHORED_CENSUS_META)
	return maxi(0, int(census.get("descendant_nodes", 0)) - _live_node_count(node))


static func _live_node_count(node: Node) -> int:
	return 1 + node.find_children("*", "", true, false).size()


## How many authored `_box(collidable = true)` pieces a solid batch stands in for.
##
## Zero for everything this pass did not create, so an audit that pairs one drawn
## mesh to one collider can restate that pairing per authored piece and read
## identically on an unbatched build. A batch keeps one `CollisionShape3D` per
## piece and draws all of them through one merged renderer, so the shape count and
## this number are the same statement from two directions.
static func authored_solid_piece_count(node: Node) -> int:
	if node == null or not is_instance_valid(node) or not node.has_meta(AUTHORED_CENSUS_META):
		return 0
	var census: Dictionary = node.get_meta(AUTHORED_CENSUS_META)
	return maxi(0, int(census.get("static_bodies", 0)))


## Whether a solid batch's colliders and its merged renderer describe one solid.
##
## The audits this pass runs under state "looks solid, is solid" as *one drawn
## mesh per matched collider*, which a merged renderer cannot satisfy node for
## node. This restates the same property for a batch, and reads the live merged
## triangles rather than any record of what was merged:
##
## * every collider is **filled** — the drawn vertices inside it span its box to
##   `tolerance`, so no collider stands in front of empty space, and
## * every drawn vertex is **inside** some collider, so no triangle is drawn where
##   the player would pass through.
##
## Together those are the node-for-node assertion applied to the merged pair, and
## on a body this pass did not create the check is skipped (an empty result), so a
## caller can run it over a whole module unconditionally.
static func solid_batch_pairing_errors(
		body: StaticBody3D,
		tolerance := 0.002
	) -> PackedStringArray:
	var errors := PackedStringArray()
	if body == null or not is_instance_valid(body) or not body.has_meta(BATCH_META):
		return errors
	if authored_solid_piece_count(body) <= 0:
		return errors
	var visual := body.get_node_or_null(NodePath(MESH_CHILD_NAME)) as MeshInstance3D
	var mesh := visual.mesh as ArrayMesh if visual != null else null
	if visual == null or mesh == null or not visual.transform.is_equal_approx(Transform3D.IDENTITY):
		errors.append("%s does not draw one merged renderer at the batch origin" % body.name)
		return errors
	var vertices := PackedVector3Array()
	for surface_index in mesh.get_surface_count():
		var arrays := mesh.surface_get_arrays(surface_index)
		vertices.append_array(arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array)
	if vertices.is_empty():
		errors.append("%s draws no merged geometry" % body.name)
		return errors
	var boxes: Array[AABB] = []
	for child in body.get_children():
		var collision := child as CollisionShape3D
		if collision == null:
			continue
		var box := collision.shape as BoxShape3D
		if box == null:
			errors.append("%s carries a collider this pass never seats: %s" % [body.name, collision.name])
			continue
		boxes.append(collision.transform * AABB(-box.size * 0.5, box.size))
	if boxes.size() != authored_solid_piece_count(body):
		errors.append("%s no longer keeps one collider per authored piece" % body.name)
		return errors
	var covered := PackedInt32Array()
	covered.resize(vertices.size())
	for box_index in boxes.size():
		var box := boxes[box_index] as AABB
		var grown := box.grow(tolerance)
		var filled := AABB()
		var found := false
		for vertex_index in vertices.size():
			if not grown.has_point(vertices[vertex_index]):
				continue
			covered[vertex_index] = 1
			if found:
				filled = filled.expand(vertices[vertex_index])
			else:
				filled = AABB(vertices[vertex_index], Vector3.ZERO)
				found = true
		# Under-fill only. A piece that touches its neighbour puts a few of the
		# neighbour's vertices inside this box, which can only make `filled` larger,
		# never smaller — so "the drawn geometry spans this collider" is the half of
		# the comparison that means something here. The loop below is the other
		# half: nothing may be drawn outside every collider.
		var under_filled := (
			filled.size.x < box.size.x - tolerance
			or filled.size.y < box.size.y - tolerance
			or filled.size.z < box.size.z - tolerance
		)
		if not found or under_filled:
			errors.append(
				"%s collider %d is not filled by the geometry drawn at it" % [body.name, box_index + 1]
			)
	for vertex_index in covered.size():
		if covered[vertex_index] == 0:
			errors.append("%s draws geometry no collider stands behind" % body.name)
			break
	return errors


## The renderer census a module must add back to read as it was built, summed
## over every batch this pass left under `module_root`.
##
## `mesh_resource_ids` are the source meshes to union back in and
## `retired_mesh_resource_ids` the merged meshes to drop; the batches bind their
## materials as per-surface overrides rather than a `material_override`, so a
## census that reads `material_override` sees none of them and
## `material_resource_ids` is a pure addition. Every counter is zero and every
## roster empty when nothing under `module_root` was batched.
static func authored_render_census_delta(module_root: Node) -> Dictionary:
	var delta := {
		"descendant_nodes": 0,
		"renderer_nodes": 0,
		"drawn_copies": 0,
		"surface_submissions": 0,
		"static_bodies": 0,
		"mesh_resource_ids": PackedInt64Array(),
		"retired_mesh_resource_ids": PackedInt64Array(),
		"material_resource_ids": PackedInt64Array(),
	}
	if module_root == null or not is_instance_valid(module_root):
		return delta
	var batches := module_root.find_children("*", "", true, false)
	batches.append(module_root)
	for candidate in batches:
		if not candidate.has_meta(AUTHORED_CENSUS_META):
			continue
		var census: Dictionary = candidate.get_meta(AUTHORED_CENSUS_META)
		var visual := candidate as MeshInstance3D
		if visual == null:
			visual = candidate.get_node_or_null(NodePath(MESH_CHILD_NAME)) as MeshInstance3D
		var live_submissions := 0
		if visual != null and visual.mesh != null:
			live_submissions = visual.mesh.get_surface_count()
			delta["retired_mesh_resource_ids"] = _appended(
				delta["retired_mesh_resource_ids"], visual.mesh.get_instance_id()
			)
		delta["descendant_nodes"] = int(delta["descendant_nodes"]) \
			+ authored_node_delta(candidate)
		delta["renderer_nodes"] = int(delta["renderer_nodes"]) \
			+ int(census.get("renderer_nodes", 0)) - (1 if visual != null else 0)
		delta["drawn_copies"] = int(delta["drawn_copies"]) \
			+ int(census.get("drawn_copies", 0)) \
			- (1 if visual != null and visual.visible else 0)
		delta["surface_submissions"] = int(delta["surface_submissions"]) \
			+ int(census.get("surface_submissions", 0)) - live_submissions
		delta["static_bodies"] = int(delta["static_bodies"]) \
			+ int(census.get("static_bodies", 0)) - (1 if candidate is StaticBody3D else 0)
		for mesh_id in census.get("mesh_resource_ids", PackedInt64Array()) as PackedInt64Array:
			delta["mesh_resource_ids"] = _appended(delta["mesh_resource_ids"], mesh_id)
		for material_id in census.get(
			"material_resource_ids", PackedInt64Array()
		) as PackedInt64Array:
			delta["material_resource_ids"] = _appended(
				delta["material_resource_ids"], material_id
			)
	return delta


static func _appended(ids: PackedInt64Array, id: int) -> PackedInt64Array:
	if not ids.has(id):
		ids.append(id)
	return ids


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


## Whether a merge would present a standing solid none of its pieces presented.
##
## See `SWEEP_PIECE_HEIGHT`. The comparison is against the tallest *placed*
## source, not the tallest authored mesh, because a piece's own rotation is part
## of the volume it occupies.
static func _manufactures_standing_solid(
		mesh: ArrayMesh,
		sources: Array[MeshInstance3D],
		offsets: Array[Transform3D],
		newly_reachable: bool
	) -> bool:
	# Scoped to the groups this trim newly reaches. Every batch the shipped pass
	# already formed was measured against the sweep by the trim that introduced
	# it, and re-refusing those costs 136 nodes to re-litigate findings that
	# were already clean. The rule exists so that *relaxing* a refusal cannot
	# manufacture a standing solid, not to re-open settled ground.
	if not newly_reachable:
		return false
	if mesh == null:
		return false
	var merged_height := mesh.get_aabb().size.y
	if merged_height < SWEEP_PIECE_HEIGHT:
		return false
	# If any source already stood that tall, the sweep already had a piece of
	# flaggable height here and the merge manufactures nothing. The refusal is
	# only for a run of individually short pieces whose aggregate crosses the
	# threshold for the first time.
	for index in sources.size():
		var source_mesh := sources[index].mesh
		if source_mesh == null:
			continue
		if (offsets[index] * source_mesh.get_aabb()).size.y \
				>= SWEEP_PIECE_HEIGHT - AGGREGATE_HEIGHT_TOLERANCE:
			return false
	return true


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
