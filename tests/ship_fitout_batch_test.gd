extends SceneTree

## Focused proof of the Phase 10 §2 *ship* fitout consolidation contract.
##
## The production pass runs inside eight hero/fleet craft; this fixture runs the
## same static helper over a hand-built fitout whose expected arithmetic can be
## written down exactly. It asserts the things every craft depends on:
##
## 1. the merged renderer carries every source triangle at its former local
##    placement, with the same materials in the same submission order, and the
##    batch is composed from local transforms only so a craft that is detached,
##    parked or in flight folds identically;
## 2. nothing that carries authority is ever removed -- metadata, a script, a
##    group, a child, a protected name or a live script reference;
## 3. deliberately shared stock meshes, live `PrimitiveMesh` stock and
##    camera-distance LOD bands are left standing, because folding those would
##    duplicate the geometry the sharing exists to avoid, take the piece out of
##    the tree-wide geometry budget sweep, or change which pieces carry a band;
## 4. the authored census a batch records reproduces exactly the roster it
##    replaced, so a craft's allocation report still describes what it builds.

const BATCH := preload("res://scripts/rendering/ship_fitout_batch.gd")

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


func _material(colour: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = colour
	return material


func _stock(size: Vector3, material: Material) -> ArrayMesh:
	var mesh := BoxMesh.new()
	mesh.size = size
	var tool := SurfaceTool.new()
	tool.create_from(mesh, 0)
	var array_mesh := tool.commit()
	array_mesh.surface_set_material(0, material)
	return array_mesh


func _piece(
		parent: Node3D,
		node_name: String,
		at: Vector3,
		size: Vector3,
		material: Material
	) -> MeshInstance3D:
	var visual := MeshInstance3D.new()
	visual.name = node_name
	visual.position = at
	visual.mesh = _stock(size, material)
	parent.add_child(visual)
	return visual


func _triangles(mesh: Mesh) -> int:
	var total := 0
	for surface_index in mesh.get_surface_count():
		var arrays := mesh.surface_get_arrays(surface_index)
		var indices = arrays[Mesh.ARRAY_INDEX]
		if indices != null and indices.size() > 0:
			total += indices.size() / 3
		else:
			total += (arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array).size() / 3
	return total


func _batches(root: Node) -> Array[MeshInstance3D]:
	var found: Array[MeshInstance3D] = []
	for candidate in root.find_children("*", "MeshInstance3D", true, false):
		if candidate.has_meta(BATCH.BATCH_META):
			found.append(candidate as MeshInstance3D)
	return found


func _run() -> void:
	_test_merge_is_lossless_and_local()
	_test_authority_is_never_folded()
	_test_shared_stock_and_bands_stand()
	_test_authored_census_reproduces_the_roster()

	if _failures.is_empty():
		print("SHIP_FITOUT_BATCH_TEST_OK: %d assertions" % _assertions)
		quit(0)
		return
	for failure in _failures:
		printerr("FAIL: %s" % failure)
	printerr("SHIP_FITOUT_BATCH_TEST_FAILED: %d of %d assertions failed" % [
		_failures.size(), _assertions
	])
	quit(1)


## The merge is triangle-for-triangle at the former local placement, and it is
## composed from local transforms only: the same fitout folds identically
## whether the craft is in the tree or detached, and wherever it stands.
func _test_merge_is_lossless_and_local() -> void:
	var liner := _material(Color(0.4, 0.42, 0.44))
	var trim := _material(Color(0.8, 0.6, 0.2))
	var results: Array[Dictionary] = []
	var merged_triangles: Array[int] = []
	var merged_bounds: Array[AABB] = []
	for attached in [true, false]:
		var craft := Node3D.new()
		craft.name = "Craft"
		if attached:
			root.add_child(craft)
			# A parked craft stands somewhere and faces somewhere; neither may
			# reach the answer.
			craft.global_transform = Transform3D(
				Basis.from_euler(Vector3(0.0, 0.9, 0.0)), Vector3(-37.0, 4.5, 61.0)
			)
		var cabin := Node3D.new()
		cabin.name = "CrewCabin"
		craft.add_child(cabin)
		var sources: Array[MeshInstance3D] = [
			_piece(cabin, "@MeshInstance3D@1", Vector3(-1.2, 1.1, 0.0), Vector3(0.05, 0.6, 2.4), liner),
			_piece(cabin, "@MeshInstance3D@2", Vector3(1.2, 1.1, 0.0), Vector3(0.05, 0.6, 2.4), liner),
			_piece(cabin, "@MeshInstance3D@3", Vector3(0.0, 1.9, 0.6), Vector3(0.9, 0.04, 0.3), trim),
		]
		var source_triangles := 0
		var source_bounds := AABB()
		for index in sources.size():
			source_triangles += _triangles(sources[index].mesh)
			var piece := sources[index].transform * sources[index].mesh.get_aabb()
			source_bounds = piece if index == 0 else source_bounds.merge(piece)
		var report := BATCH.consolidate(
			[craft], PackedStringArray(), root if attached else craft
		)
		results.append(report)
		var batches := _batches(cabin)
		_check(batches.size() == 1, "one batch replaces the three anonymous liners (attached=%s)" % attached)
		if batches.is_empty():
			craft.free()
			continue
		var batch := batches[0]
		_check(cabin.get_child_count() == 1, "the folded sources leave the cabin (attached=%s)" % attached)
		_check(
			_triangles(batch.mesh) == source_triangles,
			"the merge is triangle-for-triangle (attached=%s)" % attached
		)
		_check(
			batch.mesh.get_surface_count() == 2
				and batch.get_surface_override_material(0) == liner
				and batch.get_surface_override_material(1) == trim,
			"one surface per distinct source material, in first-appearance order (attached=%s)" % attached
		)
		_check(
			(batch.transform * batch.mesh.get_aabb()).is_equal_approx(source_bounds),
			"the merged bound is the bound the separate pieces occupied (attached=%s)" % attached
		)
		merged_triangles.append(_triangles(batch.mesh))
		merged_bounds.append(batch.transform * batch.mesh.get_aabb())
		if attached:
			root.remove_child(craft)
		craft.free()
	_check(
		results.size() == 2
			and int(results[0]["visual_sources"]) == 3
			and int(results[0]["removed_nodes"]) == 3
			and int(results[0]["added_nodes"]) == 1
			and results[0]["visual_batches"] == results[1]["visual_batches"]
			and results[0]["removed_nodes"] == results[1]["removed_nodes"],
		"the report is the exact node arithmetic and is independent of tree membership"
	)
	_check(
		merged_triangles.size() == 2 and merged_triangles[0] == merged_triangles[1]
			and merged_bounds.size() == 2 and merged_bounds[0].is_equal_approx(merged_bounds[1]),
		"a detached craft and a parked one at a rotated station berth fold identically"
	)


## Everything a consumer can still reach keeps its own node.
func _test_authority_is_never_folded() -> void:
	var finish := _material(Color(0.5, 0.5, 0.5))
	var holder := ReferenceHolder.new()
	holder.name = "Craft"
	root.add_child(holder)
	var bay := Node3D.new()
	bay.name = "CargoBay"
	holder.add_child(bay)

	var with_meta := _piece(bay, "Plain01", Vector3(0.0, 0.2, 0.0), Vector3(0.3, 0.3, 0.3), finish)
	with_meta.set_meta(&"walkable_surface", true)
	var with_group := _piece(bay, "Plain02", Vector3(0.4, 0.2, 0.0), Vector3(0.3, 0.3, 0.3), finish)
	with_group.add_to_group(&"cargo_interaction")
	var with_child := _piece(bay, "Plain03", Vector3(0.8, 0.2, 0.0), Vector3(0.3, 0.3, 0.3), finish)
	with_child.add_child(Marker3D.new())
	var protected := _piece(bay, "CargoDeck", Vector3(1.2, 0.2, 0.0), Vector3(0.3, 0.3, 0.3), finish)
	holder.kept = _piece(bay, "Plain04", Vector3(1.6, 0.2, 0.0), Vector3(0.3, 0.3, 0.3), finish)
	var foldable_a := _piece(bay, "Plain05", Vector3(2.0, 0.2, 0.0), Vector3(0.3, 0.3, 0.3), finish)
	var foldable_b := _piece(bay, "Plain06", Vector3(2.4, 0.2, 0.0), Vector3(0.3, 0.3, 0.3), finish)

	BATCH.consolidate([holder], PackedStringArray(["CargoDeck"]), root)

	_check(
		is_instance_valid(with_meta) and is_instance_valid(with_group)
			and is_instance_valid(with_child) and is_instance_valid(protected)
			and is_instance_valid(holder.kept),
		"metadata, group, child, protected name and live script reference each keep their node"
	)
	# The fold detaches immediately and frees on the next idle pass, so
	# parentage -- not validity -- is what says the node has left the craft.
	_check(
		foldable_a.get_parent() == null and foldable_b.get_parent() == null
			and with_meta.get_parent() == bay and holder.kept.get_parent() == bay,
		"the two pieces nothing can reach are the two that leave the bay"
	)
	_check(_batches(bay).size() == 1, "exactly one batch stands in for them")
	root.remove_child(holder)
	holder.free()


## Shared stock, live primitive stock and LOD bands are all left standing.
func _test_shared_stock_and_bands_stand() -> void:
	var finish := _material(Color(0.3, 0.33, 0.36))
	var craft := Node3D.new()
	craft.name = "Craft"
	root.add_child(craft)
	var bay := Node3D.new()
	bay.name = "AftSystemsBay"
	craft.add_child(bay)

	# One cached stock mesh drawn twice. This *is* folded now, and the identity
	# the old refusal protected is restated rather than dropped: the batch's
	# piece index retains the very resource both pieces drew, so a
	# resource-sharing audit still compares the same `Mesh` it always compared.
	var shared_mesh := _stock(Vector3(0.2, 0.2, 0.2), finish)
	for index in 2:
		var shared := MeshInstance3D.new()
		shared.name = "Shared%02d" % index
		shared.position = Vector3(float(index) * 0.4, 0.2, 0.0)
		shared.mesh = shared_mesh
		bay.add_child(shared)

	# Live turned stock the tree-wide geometry budget still re-tessellates.
	for index in 2:
		var turned := MeshInstance3D.new()
		turned.name = "Turned%02d" % index
		turned.position = Vector3(float(index) * 0.4, 0.8, 0.0)
		var sphere := SphereMesh.new()
		sphere.radius = 0.1
		sphere.height = 0.2
		sphere.material = finish
		turned.mesh = sphere
		bay.add_child(turned)

	# Camera-distance banded furniture.
	for index in 2:
		var banded := _piece(
			bay, "Banded%02d" % index, Vector3(float(index) * 0.4, 1.4, 0.0),
			Vector3(0.2, 0.2, 0.2), finish
		)
		banded.visibility_range_end = 100.0
		banded.visibility_range_end_margin = 10.0

	BATCH.consolidate([craft], PackedStringArray(), root)

	# Live primitive stock and banded furniture still stand piece by piece: one
	# is re-tessellated after this pass, the other carries a per-instance
	# camera-distance band, and neither is a fact an index can restate.
	var standing := PackedStringArray()
	for child in bay.get_children():
		standing.append(String(child.name))
	_check(
		standing.has("Turned00") and standing.has("Turned01")
			and standing.has("Banded00") and standing.has("Banded01")
			and not standing.has("Shared00") and not standing.has("Shared01"),
		"live primitive stock and banded furniture stand; shared stock folds"
	)

	# The upgraded contract: the shared pieces are gone as nodes, and the batch
	# still proves the exact fact their nodes proved — one mesh allocation drawn
	# by both of them. `find_authored_piece` answers for a batched member the way
	# it answers for a live node, and the resource it returns is the same object,
	# not an equal-looking copy.
	var first := BATCH.find_authored_piece(craft, "Shared00")
	var second := BATCH.find_authored_piece(craft, "Shared01")
	_check(
		not first.is_empty() and not second.is_empty()
			and bool(first["batched"]) and bool(second["batched"])
			and first["mesh"] == shared_mesh and second["mesh"] == shared_mesh
			and first["mesh"] == second["mesh"]
			and int(first["mesh_id"]) == shared_mesh.get_instance_id()
			and int(second["mesh_id"]) == shared_mesh.get_instance_id(),
		"the piece index proves both folded pieces share one retained mesh allocation"
	)
	_check(
		(first["transform"] as Transform3D).origin.is_equal_approx(Vector3(0.0, 0.2, 0.0))
			and (second["transform"] as Transform3D).origin.is_equal_approx(
				Vector3(0.4, 0.2, 0.0)
			)
			and (first["aabb"] as AABB).size.is_equal_approx(Vector3(0.2, 0.2, 0.2))
			and int(first["surfaces"]) == 1
			and (first["materials"] as Array)[0] == finish,
		"the piece index reproduces each folded piece's placement, bound and finish"
	)
	# A mesh only one piece drew is still freed, so the merge's unique-mesh
	# arithmetic is unchanged and the index retains nothing it need not.
	var private_bay := Node3D.new()
	private_bay.name = "PrivateBay"
	craft.add_child(private_bay)
	for index in 2:
		_piece(
			private_bay, "Private%02d" % index, Vector3(float(index) * 0.4, 0.0, 0.0),
			Vector3(0.2, 0.2, 0.2), finish
		)
	BATCH.consolidate([craft], PackedStringArray(), root)
	var private_record := BATCH.find_authored_piece(craft, "Private00")
	_check(
		not private_record.is_empty() and bool(private_record["batched"])
			and not bool(private_record["mesh_retained"])
			and not private_record.has("mesh"),
		"a mesh only one folded piece drew is not retained by the index"
	)
	root.remove_child(craft)
	craft.free()


## The authored census reproduces exactly the roster the batch replaced, so a
## craft's allocation report still describes what it builds.
func _test_authored_census_reproduces_the_roster() -> void:
	var finish := _material(Color(0.6, 0.6, 0.62))
	var craft := Node3D.new()
	craft.name = "Craft"
	root.add_child(craft)
	var cabin := Node3D.new()
	cabin.name = "PassengerCabin"
	craft.add_child(cabin)
	var authored_names := PackedStringArray()
	var authored_meshes := {}
	for index in 4:
		var piece := _piece(
			cabin, "@MeshInstance3D@%d" % (index + 10),
			Vector3(float(index) * 0.5, 0.5, 0.0), Vector3(0.3, 0.3, 0.3), finish
		)
		authored_names.append(String(piece.name))
		authored_meshes[piece.mesh.get_instance_id()] = true

	var empty := BATCH.authored_render_census_delta(craft)
	_check(
		int(empty.descendant_nodes) == 0 and int(empty.renderer_nodes) == 0
			and (empty.mesh_resource_ids as PackedInt64Array).is_empty(),
		"the census delta is zero on a craft that has not been folded"
	)

	BATCH.consolidate([craft], PackedStringArray(), root)
	var batches := _batches(cabin)
	_check(batches.size() == 1, "one batch replaces the four anonymous fittings")
	if batches.is_empty():
		root.remove_child(craft)
		craft.free()
		return
	var batch := batches[0]
	var delta := BATCH.authored_render_census_delta(craft)
	_check(
		int(delta.descendant_nodes) == 3 and int(delta.renderer_nodes) == 3
			and int(delta.drawn_copies) == 3,
		"three folded renderers are added back to a four-piece roster that now draws one"
	)
	_check(
		int(delta.surface_submissions) == 3,
		"the submissions the four separate pieces made are added back to the one the batch makes"
	)
	var restored := {}
	for mesh_id in delta.mesh_resource_ids as PackedInt64Array:
		restored[mesh_id] = true
	_check(
		restored.size() == authored_meshes.size()
			and (delta.retired_mesh_resource_ids as PackedInt64Array).has(
				batch.mesh.get_instance_id()
			),
		"the four authored meshes are restored and the merged mesh is retired"
	)
	_check(
		batch.get_meta(BATCH.AUTHORED_NAMES_META, PackedStringArray()) == authored_names
			and int(batch.get_meta(&"batched_source_count", 0)) == 4
			and (batch.get_meta(&"authored_instance_transforms", []) as Array).size() == 4,
		"the batch records every name and placement it stands in for"
	)
	_check(
		BATCH.authored_node_delta(batch) == 3 and BATCH.authored_node_delta(cabin) == 0,
		"only a batch stands in for nodes; every other node reads zero"
	)
	root.remove_child(craft)
	craft.free()
