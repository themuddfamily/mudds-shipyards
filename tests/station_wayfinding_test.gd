extends SceneTree

## Phase 10 §3 station wayfinding layer.
##
## Drives the production `res://scenes/main.tscn` and proves the registry-driven
## sign layer the world builds: every panel derives from a live
## `StationRouteRegistry` route, faces the direction the reader approaches from,
## covers eye height, sits clear of every physics collider (checked with real
## physics shape queries, independently of the component's own OBB placement
## test), stays inside its budget (<= 60 signs, <= 400 triangles, one renderer,
## one material, no lights, no collision, no TextMesh/Label3D), carries non-empty
## labels, and moves when a registry route marker moves.

const MAIN_SCENE := preload("res://scenes/main.tscn")
const WAYFINDING := preload("res://scripts/world/station_wayfinding_signage.gd")

const MAX_SIGNS := 60
const MAX_TRIANGLES := 400
const EYE_HEIGHT := 1.65
const EXPECTED_THRESHOLD_COUNT := 7

var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var game := MAIN_SCENE.instantiate() as GameFlow
	_check(game != null, "production main scene instantiates for the wayfinding audit")
	if game == null:
		_finish()
		return
	root.add_child(game)
	for _frame in 30:
		await process_frame
	await physics_frame
	await physics_frame

	var world := game.get_node_or_null("ShipyardWorld") as ShipyardWorld
	_check(world != null, "main scene owns the production ShipyardWorld")
	if world == null:
		await _cleanup(game)
		_finish()
		return
	var signage := world.get_station_wayfinding()
	_check(signage != null and signage.is_built(), "world builds the station wayfinding layer")
	if signage == null:
		await _cleanup(game)
		_finish()
		return

	var report := world.get_station_wayfinding_report()
	var registry := world.get_station_route_registry_report()
	_test_budget_and_renderer(signage, report)
	_test_labels(report)
	_test_registry_derivation(report, registry)
	_test_facing_and_height(report, registry)
	_test_clear_of_collision(world, report)
	_test_atlas_table()
	_test_concave_collision()
	_test_static_floor_support()
	_test_deferred_berths(world, signage)
	await _test_follows_registry_marker(world, signage)
	await _test_origin_rebase(game, world, signage)

	await _cleanup(game)
	_finish()


func _test_budget_and_renderer(signage: StationWayfindingSignage, report: Dictionary) -> void:
	var sign_count := int(report.get("sign_count", 0))
	_check(sign_count > EXPECTED_THRESHOLD_COUNT and sign_count <= MAX_SIGNS, "sign count is within 8..60 (got %d)" % sign_count)
	_check(report.has("concave_shapes_ignored") and int(report.get("concave_shapes_ignored", -1)) == 0, "report explicitly records zero ignored concave shapes")
	_check(report.has("concave_shapes_checked"), "report counts trimeshes checked against actual triangles")
	var triangle_count := int(report.get("triangle_count", 0))
	_check(triangle_count > 0 and triangle_count <= MAX_TRIANGLES, "sign triangles stay within 400 (got %d)" % triangle_count)
	for entry: Dictionary in (report.get("skipped", []) as Array):
		print("WAYFINDING_SKIPPED: ", entry)
	var skipped_sites := {}
	for entry: Dictionary in (report.get("skipped", []) as Array):
		skipped_sites[String(entry.get("site", ""))] = true
	for entry: Dictionary in (report.get("conflicts", []) as Array):
		print("WAYFINDING_CONFLICT: ", entry)
		_check(skipped_sites.has(String(entry.get("site", ""))), "every blocked site is listed as skipped")

	var meshes := signage.find_children("*", "MeshInstance3D", true, false)
	_check(meshes.size() == 1, "wayfinding draws through exactly one renderer")
	var batch := signage.get_sign_batch()
	_check(batch != null and meshes.has(batch), "the one renderer is the published sign batch")
	if batch != null:
		var mesh := batch.mesh as ArrayMesh
		_check(mesh != null and mesh.get_surface_count() == 1, "sign batch is a single ArrayMesh surface")
		if mesh != null and mesh.get_surface_count() == 1:
			var arrays := mesh.surface_get_arrays(0)
			var vertices := arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array
			_check(vertices.size() / 3 == triangle_count, "reported triangles match the drawn mesh")
			_check(mesh.surface_get_material(0) == null, "no per-surface material beside the override")
		var material := batch.material_override as StandardMaterial3D
		_check(material != null and material.albedo_texture != null, "one material samples the generated atlas")
		_check(material != null and material.shading_mode == BaseMaterial3D.SHADING_MODE_UNSHADED, "plates are unshaded, high-contrast and light-independent")
		_check(batch.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_OFF, "signs cast no shadows")
		_check(batch.gi_mode == GeometryInstance3D.GI_MODE_DISABLED, "signs add no GI contribution")
		_check(batch.layers == 1, "signs render on the station's default visual layer like other signage")
	_check(signage.find_children("*", "TextMesh", true, false).is_empty(), "no TextMesh nodes")
	var text_meshes := 0
	for node in meshes:
		if (node as MeshInstance3D).mesh is TextMesh:
			text_meshes += 1
	_check(text_meshes == 0, "no TextMesh lettering")
	_check(signage.find_children("*", "Label3D", true, false).is_empty(), "no Label3D lettering")
	_check(signage.find_children("*", "Light3D", true, false).is_empty(), "no lights")
	_check(signage.find_children("*", "CollisionObject3D", true, false).is_empty(), "no collision bodies")
	_check(signage.find_children("*", "CollisionShape3D", true, false).is_empty(), "no collision shapes")
	_check(signage.find_children("*", "AnimationPlayer", true, false).is_empty() \
		and not signage.is_processing() and not signage.is_physics_processing(), "signs never animate (reduced flash safe)")


func _test_labels(report: Dictionary) -> void:
	var all_labeled := true
	var every_face_has_rows := true
	for sign: Dictionary in (report.get("signs", []) as Array):
		var front := sign.get("front", []) as Array
		every_face_has_rows = every_face_has_rows and not front.is_empty()
		for row: Dictionary in front + (sign.get("back", []) as Array):
			all_labeled = all_labeled and not String(row.get("text", "")).strip_edges().is_empty() \
				and not String(row.get("source", "")).is_empty()
			var degrees := int(row.get("arrow_degrees", 999))
			all_labeled = all_labeled and degrees % 45 == 0 and absi(degrees) <= 180
	_check(every_face_has_rows, "every sign names at least one destination")
	_check(all_labeled, "every row carries non-empty text, a registry source and a 45-degree arrow")


func _test_registry_derivation(report: Dictionary, registry: Dictionary) -> void:
	var edge_slots := {}
	for edge: Dictionary in ((registry.get("adjacency", {}) as Dictionary).get("edges", []) as Array):
		edge_slots[String(edge.get("slot_id", ""))] = true
	var modules := registry.get("modules", {}) as Dictionary
	var thresholds := 0
	var directories := 0
	var derived := true
	for sign: Dictionary in (report.get("signs", []) as Array):
		var source := String(sign.get("source", ""))
		match StringName(sign.get("kind", &"")):
			&"directory":
				directories += 1
				derived = derived and source.begins_with(String(StationRouteRegistry.HUB_ENDPOINT_ID) + ":")
			&"threshold":
				thresholds += 1
				derived = derived and source.begins_with("edge:") and edge_slots.has(source.trim_prefix("edge:"))
			&"junction":
				var parts := source.split(":")
				var entry := modules.get(StringName(parts[0]), {}) as Dictionary
				derived = derived and parts.size() == 2 \
					and (entry.get("route_ids", PackedStringArray()) as PackedStringArray).has(parts[1])
			_:
				derived = false
	_check(derived, "every sign derives from a registry edge, a registry route marker or the hub")
	_check(directories == 1, "exactly one station directory")
	_check(thresholds == EXPECTED_THRESHOLD_COUNT, "one threshold panel per registry edge (got %d)" % thresholds)


func _test_facing_and_height(report: Dictionary, registry: Dictionary) -> void:
	var faces_approach := true
	var eye_height := true
	var threshold_matches_edge := true
	var hub_endpoints := registry.get("hub_endpoints", {}) as Dictionary
	var modules := registry.get("modules", {}) as Dictionary
	for sign: Dictionary in (report.get("signs", []) as Array):
		var normal := sign.get("normal", Vector3.ZERO) as Vector3
		var approach := sign.get("approach_direction", Vector3.ZERO) as Vector3
		faces_approach = faces_approach and is_equal_approx(normal.length(), 1.0) \
			and absf(normal.y) < 0.001 and normal.dot(approach) < -0.999
		var floor_y := (sign.get("position", Vector3.ZERO) as Vector3).y
		eye_height = eye_height and float(sign.get("panel_bottom", 0.0)) - floor_y <= EYE_HEIGHT \
			and float(sign.get("panel_top", 0.0)) - floor_y >= EYE_HEIGHT
		if StringName(sign.get("kind", &"")) == &"threshold":
			var slot_id := StringName(String(sign.get("source", "")).trim_prefix("edge:"))
			var anchor := ((hub_endpoints.get(slot_id, {}) as Dictionary).get("anchor_transform", Transform3D.IDENTITY) as Transform3D).origin
			var entry := Vector3.INF
			for module_id in modules.keys():
				var slots := (modules[module_id] as Dictionary).get("connection_slots", {}) as Dictionary
				if slots.has(slot_id):
					entry = ((slots[slot_id] as Dictionary).get("transform", Transform3D.IDENTITY) as Transform3D).origin
			var edge := Vector3(entry.x - anchor.x, 0.0, entry.z - anchor.z)
			threshold_matches_edge = threshold_matches_edge and edge.length() > 0.01 \
				and edge.normalized().dot(approach) > 0.999
	_check(faces_approach, "every sign faces the approaching reader (normal opposes approach, level)")
	_check(eye_height, "every panel spans eye height above its floor")
	_check(threshold_matches_edge, "threshold panels face along the registry edge from hub anchor to module slot")


func _test_clear_of_collision(world: ShipyardWorld, report: Dictionary) -> void:
	var space := world.get_world_3d().direct_space_state
	var clear := true
	var doors_clear := true
	for sign: Dictionary in (report.get("signs", []) as Array):
		var normal := sign.get("normal", Vector3.ZERO) as Vector3
		var right := (-normal).cross(Vector3.UP).normalized()
		var basis := Basis(right, Vector3.UP, normal)
		var position := sign.get("position", Vector3.ZERO) as Vector3
		var bottom := float(sign.get("panel_bottom", 0.0))
		var top := float(sign.get("panel_top", 0.0))
		var panel := BoxShape3D.new()
		panel.size = Vector3(float(sign.get("half_width", 0.9)) * 2.0, top - bottom, 0.04)
		var post := BoxShape3D.new()
		post.size = Vector3(0.1, maxf(bottom - position.y - 0.1, 0.02), 0.04)
		for probe: Array in [
			[panel, Vector3(position.x, (top + bottom) * 0.5, position.z)],
			[post, Vector3(position.x, (bottom + position.y + 0.1) * 0.5, position.z)],
		]:
			var query := PhysicsShapeQueryParameters3D.new()
			query.shape = probe[0] as Shape3D
			query.transform = Transform3D(basis, probe[1] as Vector3)
			query.collide_with_areas = false
			query.collide_with_bodies = true
			var hits := space.intersect_shape(query, 4)
			if not hits.is_empty():
				clear = false
				print("WAYFINDING_COLLISION: ", sign.get("id"), " hits ", (hits[0] as Dictionary).get("collider"))
			# Independent physics query of the same panel/post expanded horizontally
			# by 0.9 m, checking door-named colliders separately from other walls.
			var door_probe := (probe[0] as BoxShape3D).duplicate() as BoxShape3D
			door_probe.size += Vector3(1.8, 0.0, 1.8)
			query.shape = door_probe
			for hit: Dictionary in space.intersect_shape(query, 256):
				var body := hit.get("collider") as CollisionObject3D
				if body == null:
					continue
				var owner_id := body.shape_find_owner(int(hit.get("shape", 0)))
				var node := body.shape_owner_get_owner(owner_id) as Node
				while node != null:
					if String(node.name).containsn("door"):
						doors_clear = false
						print("WAYFINDING_DOOR_CLEARANCE: ", sign.get("id"), " hits ", node.get_path())
						break
					node = node.get_parent()
	_check(clear, "no sign panel or post intersects station collision")
	_check(doors_clear, "every sign panel and post has 0.9 m horizontal clearance from door-named colliders")


func _test_atlas_table() -> void:
	var keys := {}
	var unique := true
	for entry: Array in WAYFINDING.SIGN_LABELS:
		unique = unique and not keys.has(entry[0]) and not String(entry[1]).is_empty()
		keys[entry[0]] = true
	_check(unique, "atlas label keys are unique and non-empty")
	_check(WAYFINDING.SIGN_LABELS.size() <= WAYFINDING.ARROW_CELL_INDEX, "labels fit in the atlas before the arrow cell")
	_check(load(WAYFINDING.ATLAS_TEXTURE_PATH) is Texture2D, "generated sign atlas imports as a texture")
	var titled := true
	for module_id in WAYFINDING.MODULE_TITLES.keys():
		titled = titled and keys.has(WAYFINDING.MODULE_TITLES[module_id])
	_check(titled, "every registry module title is an atlas label")


## A real concave wall must block a panel, while empty space inside the
## trimesh's coarse bounds remains usable. This protects triangle narrow-phase.
func _test_concave_collision() -> void:
	var fixture := Node3D.new()
	fixture.name = "WayfindingConcaveFixture"
	root.add_child(fixture)
	var body := StaticBody3D.new()
	fixture.add_child(body)
	var collider := CollisionShape3D.new()
	var shape := ConcavePolygonShape3D.new()
	shape.set_faces(PackedVector3Array([
		Vector3(-2, 0, 0), Vector3(2, 0, 0), Vector3(2, 3, 0),
		Vector3(-2, 0, 0), Vector3(2, 3, 0), Vector3(-2, 3, 0),
	]))
	collider.shape = shape
	body.add_child(collider)
	var signage := WAYFINDING.new()
	fixture.add_child(signage)
	signage._collect_solids(fixture)
	_check(not signage._obstruction(Vector3.ZERO, Vector3.RIGHT, Vector3.BACK, 2.0, 0.5).is_empty(), "concave wall blocks an intersecting sign")
	_check(signage._obstruction(Vector3(0, 0, 2), Vector3.RIGHT, Vector3.BACK, 2.0, 0.5).is_empty(), "sign clear of concave wall remains placeable")
	_check(int(signage.get_wayfinding_report().get("concave_shapes_checked", 0)) == 1, "concave collision is counted instead of ignored")
	var corners := PackedVector3Array([
		Vector3(-3, 0, 0), Vector3(-2, 0, 0), Vector3(-2, 3, 0),
		Vector3(2, 0, 0), Vector3(3, 0, 0), Vector3(2, 3, 0),
	])
	shape.set_faces(corners)
	signage._collect_solids(fixture)
	_check(signage._obstruction(Vector3.ZERO, Vector3.RIGHT, Vector3.BACK, 2.0, 0.5).is_empty(), "trimesh bounds do not falsely close an empty doorway")
	fixture.free()


func _test_static_floor_support() -> void:
	var fixture := Node3D.new()
	fixture.name = "WayfindingFloorFixture"
	root.add_child(fixture)
	var floor_body := StaticBody3D.new()
	fixture.add_child(floor_body)
	var ramp := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(4.0, 0.4, 4.0)
	ramp.shape = box
	ramp.rotation.z = 0.2
	floor_body.add_child(ramp)
	var signage := WAYFINDING.new()
	fixture.add_child(signage)
	signage._collect_solids(fixture)
	var height: Variant = signage._find_floor(Vector3.ZERO, 0.0)
	_check(height != null and is_equal_approx(float(height), 0.2 / cos(0.2)), "ramp support uses its real face instead of the AABB top")
	floor_body.name = "TestDoorSupport"
	signage._collect_solids(fixture)
	_check(signage._find_floor(Vector3.ZERO, 0.0) == null, "door geometry cannot support a static sign")
	var moving := AnimatableBody3D.new()
	fixture.add_child(moving)
	ramp.reparent(moving, false)
	signage._collect_solids(fixture)
	_check(signage._find_floor(Vector3.ZERO, 0.0) == null, "moving body geometry cannot support a static sign")
	fixture.free()


func _test_deferred_berths(world: ShipyardWorld, signage: StationWayfindingSignage) -> void:
	_check(world.refresh_deferred_fleet_expansion_berths(), "deferred fleet berths are built and indexed")
	var report := signage.get_wayfinding_report()
	var before := int(report.get("build_count", 0))
	var batch := signage.get_sign_batch()
	var labels := {}
	for sign: Dictionary in (report.get("signs", []) as Array):
		for row: Dictionary in (sign.get("front", []) as Array):
			labels[StringName(row.get("label", &""))] = true
	for label: StringName in [&"dock_04", &"dock_05", &"dock_06"]:
		_check(labels.has(label), "%s appears on a placed panel after berth indexing" % label)
	_check(before <= 2, "initial build plus at most one rebuild admits deferred berths")
	_check(world.refresh_deferred_fleet_expansion_berths(), "repeated deferred berth notification succeeds")
	_check(int(signage.get_wayfinding_report().get("build_count", 0)) == before, "unchanged berth rows do not trigger a second full rebuild")
	_check(signage.get_sign_batch() == batch, "repeated berth refresh retains the same renderer")


## Moving a registry route marker moves the sign derived from it.
func _test_follows_registry_marker(world: ShipyardWorld, signage: StationWayfindingSignage) -> void:
	var comb := world.get_fleet_dock_comb()
	var marker := comb.get_route_marker(&"trunk-mid") as Node3D if comb != null else null
	_check(marker != null, "fleet dock comb publishes its trunk-mid route marker")
	if marker == null:
		return
	var before := _sign_by_id(signage.get_wayfinding_report(), "junction:fleet-dock-comb:trunk-mid")
	var original := marker.global_position
	marker.global_position = original + Vector3(1.5, 0.0, 0.0)
	signage.rebuild(world)
	var after := _sign_by_id(signage.get_wayfinding_report(), "junction:fleet-dock-comb:trunk-mid")
	_check(
		not before.is_empty() and not after.is_empty()
		and ((after.get("route_origin", Vector3.ZERO) as Vector3) - (before.get("route_origin", Vector3.ZERO) as Vector3)).is_equal_approx(Vector3(1.5, 0.0, 0.0)),
		"a moved registry route marker carries its junction sign"
	)
	marker.global_position = original
	signage.rebuild(world)
	await process_frame


## A planet visit leaves every Main root translated by the common-origin rebase
## (measured about (-31, -4, -48)). The signs travel with the world; a later
## berth refresh must neither rebuild for the translation alone nor, when it
## does rebuild, route panels from the registry's construction-time anchors.
func _test_origin_rebase(game: Node, world: ShipyardWorld, signage: StationWayfindingSignage) -> void:
	var offset := Vector3(-31.0, -4.0, -48.0)
	var before := signage.get_wayfinding_report()
	var batch := signage.get_sign_batch()
	for child in game.get_children():
		if child is Node3D:
			(child as Node3D).global_position += offset
	await physics_frame
	await physics_frame
	world.refresh_deferred_fleet_expansion_berths()
	_check(
		int(signage.get_wayfinding_report().get("build_count", 0)) == int(before.get("build_count", -1))
		and signage.get_sign_batch() == batch,
		"a berth refresh after an origin rebase keeps the translated sign layer instead of rebuilding"
	)
	var rebuilt := signage.rebuild(world)
	var matches := int(rebuilt.get("sign_count", 0)) == int(before.get("sign_count", -1))
	var drift := PackedStringArray()
	for sign: Dictionary in (before.get("signs", []) as Array):
		var moved := _sign_by_id(rebuilt, String(sign.get("id", "")))
		if moved.is_empty() or not ((moved.get("position", Vector3.INF) as Vector3) - offset).is_equal_approx(sign.get("position", Vector3.ZERO) as Vector3):
			drift.append(String(sign.get("id", "")))
	_check(
		matches and drift.is_empty(),
		"a rebuild after an origin rebase places every sign where it was, translated (drift=%s count %d->%d)"
			% [drift, int(before.get("sign_count", -1)), int(rebuilt.get("sign_count", -1))]
	)
	for child in game.get_children():
		if child is Node3D:
			(child as Node3D).global_position -= offset
	await physics_frame


func _sign_by_id(report: Dictionary, id: String) -> Dictionary:
	for sign: Dictionary in (report.get("signs", []) as Array):
		if String(sign.get("id", "")) == id:
			return sign
	return {}


func _cleanup(game: Node) -> void:
	game.queue_free()
	await process_frame
	await physics_frame
	await process_frame


func _check(condition: bool, description: String) -> void:
	if condition:
		print("PASS: ", description)
	else:
		_failures.append(description)
		push_error("FAIL: " + description)


func _finish() -> void:
	if _failures.is_empty():
		print("STATION_WAYFINDING_TEST_OK")
		quit(0)
	else:
		print("STATION_WAYFINDING_TEST_FAILED: ", "; ".join(_failures))
		quit(1)
