extends SceneTree

## Focused retained-resource and behavior contract for ShipyardWorld's childless
## guide-light stock, including the UpperOperations observation-post practical.

const WORLD_SCENE := preload("res://scenes/world/shipyard_world.tscn")
const BASELINE_BEHAVIOR_FINGERPRINT := "790d4162ba1c9e4369d79c69afe066390d4f34c65780068d3cf6f6a88f867f3a"
const EXPECTED_COLOR_COUNTS := {
	"48dbe2ff": 16,
	"ff9f43ff": 13,
	"ff5f57ff": 20,
	"cfe6eeff": 1,
}

var _failures: Array[String] = []
var _assertions := 0


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var world := WORLD_SCENE.instantiate() as ShipyardWorld
	_check(world != null, "production ShipyardWorld scene instantiates")
	if world == null:
		_finish()
		return
	root.add_child(world)
	await process_frame

	var lenses := _guide_lenses(world)
	var lights := _guide_lights(world)
	var audit := world.get_guide_light_allocation_audit()
	var independent_behavior_rows := _guide_light_behavior_rows(world, lights)
	var independent_behavior_json := JSON.stringify(independent_behavior_rows)
	var independent_behavior_fingerprint := independent_behavior_json.sha256_text()
	var canonical_paths_have_runtime_names := false
	for row: Dictionary in independent_behavior_rows:
		canonical_paths_have_runtime_names = canonical_paths_have_runtime_names \
			or str(row.path).contains("@")
	_check(bool(audit.valid), "guide-light retained-resource audit starts green: %s" % [audit.errors])
	_check(
		lenses.size() == 50 and lights.size() == 50
		and int(audit.lens_node_count) == 50 and int(audit.light_node_count) == 50,
		"exactly 50 childless lens-anchor/light pairs remain in the production world"
	)
	_check(
		int(audit.scope_node_count) == 104
		and int(audit.baseline_scope_node_count) == 100
		and int(audit.node_delta) == 4
		and int(audit.baseline_renderer_node_count) == 50
		and int(audit.renderer_node_count) == 4
		and int(audit.renderer_node_delta) == -46,
		"four batch nodes retain all 100 stable guide nodes while renderers drop 50 -> 4"
	)
	_check(
		int(audit.structural_submission_count) == 4
		and int(audit.baseline_structural_submission_count) == 50
		and int(audit.submission_delta) == -46
		and int(audit.drawn_copy_count) == 50
		and int(audit.drawn_copy_delta) == 0,
		"color batching reduces structural submissions 50 -> 4 while retaining 50 copies"
	)
	_check(
		audit.before == {
			"scope_nodes": 100,
			"renderer_nodes": 50,
			"structural_submissions": 50,
			"drawn_copies": 50,
			"retained_visual_resources": 5,
		}
		and audit.current == {
			"scope_nodes": 104,
			"renderer_nodes": 4,
			"structural_submissions": 4,
			"drawn_copies": 50,
			"retained_visual_resources": 5,
		}
		and (audit.batch_instance_counts as Dictionary) == EXPECTED_COLOR_COUNTS,
		"allocation evidence freezes nodes, renderers, submissions, resources, and copies before/after"
	)
	_check(
		int(audit.mesh_resource_identity_count) == 1
		and int(audit.material_resource_identity_count) == 4
		and int(audit.retained_visual_resource_identity_count) == 5
		and int(audit.baseline_retained_visual_resource_identity_count) == 100
		and int(audit.retained_visual_resource_identity_delta) == -95,
		"50 mesh plus 50 material identities become one mesh plus four immutable recipes (100 -> 5, delta -95)"
	)
	_check(
		(audit.color_counts as Dictionary) == EXPECTED_COLOR_COUNTS,
		"shared recipes retain the exact 16 cyan, 13 orange, 20 red, and one neutral lens roster"
	)
	_check(
		str(audit.behavior_fingerprint) == BASELINE_BEHAVIOR_FINGERPRINT
		and bool(audit.behavior_fingerprint_matches_baseline)
		and independent_behavior_fingerprint == BASELINE_BEHAVIOR_FINGERPRINT,
		"canonical paths, positions, colors, energy, range, shadows, pulse phases, and pulse bases match the current baseline: %s" % independent_behavior_fingerprint
	)
	_check(
		not canonical_paths_have_runtime_names,
		"runtime fallback light names are canonicalized to stable sibling ordinals"
	)
	_check(
		int(audit.authority_node_count) == 0
		and int(audit.scripted_node_count) == 0
		and int(audit.child_node_count) == 0
		and bool(audit.batched)
		and not bool(audit.frame_time_claimed)
		and not bool(audit.gpu_draw_call_claimed),
		"guide stock remains childless presentation with no collision, script, lifecycle, or GPU-performance claim"
	)

	_test_upper_operations_identity(world, lenses, lights)
	_test_detached_report(world)
	_test_resource_mutations(world, lenses)
	await _test_detach_reentry(world, lenses)

	world.queue_free()
	await process_frame
	await process_frame
	_finish()


func _test_upper_operations_identity(
	world: ShipyardWorld,
	lenses: Array[Marker3D],
	lights: Array[OmniLight3D]
) -> void:
	var upper := world.get_node_or_null("UpperOperations") as Node3D
	var upper_lenses: Array[Marker3D] = []
	var upper_lights: Array[OmniLight3D] = []
	for lens in lenses:
		if upper != null and upper.is_ancestor_of(lens):
			upper_lenses.append(lens)
	for light in lights:
		if upper != null and upper.is_ancestor_of(light):
			upper_lights.append(light)
	_check(
		upper != null and upper_lenses.size() == 1 and upper_lights.size() == 1,
		"UpperOperations retains exactly its one observation-post lens/light pair"
	)
	if upper_lenses.size() != 1 or upper_lights.size() != 1:
		return
	var lens := upper_lenses[0]
	var light := upper_lights[0]
	_check(
		str(world.get_path_to(lens)) == "UpperOperations/GuideLens"
		and str(world.get_path_to(light)) == "UpperOperations/GuideLight"
		and lens.position.is_equal_approx(Vector3(-12.75, 4.45, 2.4))
		and light.position.is_equal_approx(lens.position),
		"UpperOperations guide nodes retain their names, hierarchy, and exact transform"
	)
	_check(
		light.light_color.is_equal_approx(Color("48dbe2"))
		and is_equal_approx(light.light_energy, 1.2)
		and is_equal_approx(light.omni_range, 5.5)
		and not light.shadow_enabled
		and not light.has_meta("pulse_phase"),
		"UpperOperations light keeps its exact color, energy, range, shadow, and non-pulsing behavior"
	)
	var cyan_batch: MultiMeshInstance3D = null
	for batch in _guide_batches(world):
		if (batch.material_override as StandardMaterial3D).albedo_color.is_equal_approx(
			Color("48dbe2")
		):
			cyan_batch = batch
			break
	var sphere := cyan_batch.multimesh.mesh as SphereMesh if cyan_batch != null else null
	var material := cyan_batch.material_override as StandardMaterial3D if cyan_batch != null else null
	_check(
		sphere != null
		and is_equal_approx(sphere.radius, 0.16)
		and is_equal_approx(sphere.height, 0.32)
		and sphere.radial_segments == 24 and sphere.rings == 12,
		"batched guide geometry retains the exact former SphereMesh recipe"
	)
	_check(
		material != null
		and material.albedo_color.is_equal_approx(Color("48dbe2"))
		and is_zero_approx(material.metallic)
		and is_equal_approx(material.roughness, 0.25)
		and material.emission_enabled
		and material.emission.is_equal_approx(Color("48dbe2"))
		and is_equal_approx(material.emission_energy_multiplier, 1.35),
		"batched cyan material retains the exact immutable material recipe"
	)


func _test_detached_report(world: ShipyardWorld) -> void:
	var detached := world.get_guide_light_allocation_audit()
	(detached.color_counts as Dictionary)["48dbe2ff"] = 999
	(detached.errors as PackedStringArray).append("caller mutation")
	var fresh := world.get_guide_light_allocation_audit()
	_check(
		int((fresh.color_counts as Dictionary).get("48dbe2ff", 0)) == 16
		and "caller mutation" not in (fresh.errors as PackedStringArray)
		and bool(fresh.valid),
		"allocation reports are deeply detached from caller mutation"
	)


func _test_resource_mutations(world: ShipyardWorld, lenses: Array[Marker3D]) -> void:
	var batches := _guide_batches(world)
	var shared_mesh := batches[0].multimesh.mesh as SphereMesh
	var original_radius := shared_mesh.radius
	shared_mesh.radius = 0.19
	var mesh_mutation := world.get_guide_light_allocation_audit()
	var all_batches_observe_mesh_mutation := true
	for batch in batches:
		all_batches_observe_mesh_mutation = all_batches_observe_mesh_mutation \
			and is_equal_approx((batch.multimesh.mesh as SphereMesh).radius, 0.19)
	_check(
		not bool(mesh_mutation.valid)
		and _has_error(mesh_mutation, "guide_lens_mesh_recipe_drift")
		and all_batches_observe_mesh_mutation,
		"in-place shared-mesh mutation reaches all four batches and turns the audit red"
	)
	shared_mesh.radius = original_radius
	_check(bool(world.get_guide_light_allocation_audit().valid), "restoring the exact mesh recipe returns the audit green")

	var shared_material := batches[0].material_override as StandardMaterial3D
	var original_roughness := shared_material.roughness
	shared_material.roughness = 0.61
	var material_mutation := world.get_guide_light_allocation_audit()
	_check(
		not bool(material_mutation.valid)
		and _has_error(material_mutation, "guide_lens_material_recipe_drift")
		and is_equal_approx((batches[0].material_override as StandardMaterial3D).roughness, 0.61),
		"in-place batch-material mutation turns the exact recipe audit red"
	)
	shared_material.roughness = original_roughness
	_check(bool(world.get_guide_light_allocation_audit().valid), "restoring the exact material recipe returns the audit green")

	var original_material := batches[0].material_override
	batches[0].material_override = original_material.duplicate(true) as Material
	var identity_mutation := world.get_guide_light_allocation_audit()
	_check(
		not bool(identity_mutation.valid)
		and _has_error(identity_mutation, "guide_lens_batch_recipe_or_transform_drift"),
		"an exact-looking private material copy is rejected as batch recipe identity drift"
	)
	batches[0].material_override = original_material
	_check(bool(world.get_guide_light_allocation_audit().valid), "restoring the shared material identity returns the audit green")

	var original_anchor_transform := lenses[0].transform
	lenses[0].position.x += 0.03
	var transform_mutation := world.get_guide_light_allocation_audit()
	_check(
		not bool(transform_mutation.valid)
		and _has_error(transform_mutation, "guide_lens_batch_recipe_or_transform_drift"),
		"moving one stable lens anchor turns the exact batched-transform audit red"
	)
	lenses[0].transform = original_anchor_transform
	_check(bool(world.get_guide_light_allocation_audit().valid), "restoring the exact lens-anchor transform returns the audit green")

	var rogue_authority := Area3D.new()
	lenses[0].add_child(rogue_authority)
	var authority_mutation := world.get_guide_light_allocation_audit()
	_check(
		not bool(authority_mutation.valid)
		and int(authority_mutation.authority_node_count) == 1
		and _has_error(authority_mutation, "guide_light_stock_gained_authority_or_lifecycle_children"),
		"collision/interaction-shaped descendants violate the exact childless presentation boundary"
	)
	lenses[0].remove_child(rogue_authority)
	rogue_authority.free()
	_check(bool(world.get_guide_light_allocation_audit().valid), "removing rogue authority restores the exact green allocation audit")


func _test_detach_reentry(world: ShipyardWorld, lenses: Array[Marker3D]) -> void:
	var batches := _guide_batches(world)
	var mesh_id := batches[0].multimesh.mesh.get_instance_id()
	var material_ids: Dictionary = {}
	for batch in batches:
		material_ids[batch.material_override.get_instance_id()] = true
	root.remove_child(world)
	await process_frame
	_check(
		bool(world.get_guide_light_allocation_audit().valid),
		"detached world retains the same green childless guide-light stock"
	)
	root.add_child(world)
	await process_frame
	await process_frame
	var reentered_lenses := _guide_lenses(world)
	var reentered_batches := _guide_batches(world)
	var reentered_material_ids: Dictionary = {}
	for batch in reentered_batches:
		reentered_material_ids[batch.material_override.get_instance_id()] = true
	var reentered_audit := world.get_guide_light_allocation_audit()
	_check(
		reentered_lenses.size() == 50
		and reentered_batches.size() == 4
		and reentered_batches[0].multimesh.mesh.get_instance_id() == mesh_id
		and reentered_material_ids == material_ids
		and bool(reentered_audit.valid),
		"detach/re-entry retains exact batch mesh/material identities, node count, behavior, and audit validity: count=%d mesh=%s materials=%s errors=%s" % [
			reentered_lenses.size(),
			str(reentered_batches[0].multimesh.mesh.get_instance_id() == mesh_id),
			str(reentered_material_ids == material_ids),
			reentered_audit.errors,
		]
	)


func _guide_lenses(world: ShipyardWorld) -> Array[Marker3D]:
	var lenses: Array[Marker3D] = []
	for light in _guide_lights(world):
		var lens := _guide_lens_for(light)
		if lens != null:
			lenses.append(lens)
	return lenses


func _guide_lights(world: ShipyardWorld) -> Array[OmniLight3D]:
	var lights: Array[OmniLight3D] = []
	for candidate in world.find_children("*", "OmniLight3D", true, false):
		var light := candidate as OmniLight3D
		if _guide_lens_for(light) != null:
			lights.append(light)
	return lights


func _guide_lens_for(light: OmniLight3D) -> Marker3D:
	var parent := light.get_parent()
	var index := light.get_index()
	if parent == null or index <= 0:
		return null
	var lens := parent.get_child(index - 1) as Marker3D
	if lens == null or not lens.position.is_equal_approx(light.position):
		return null
	if (
		not bool(lens.get_meta("batched_visual_anchor", false))
		or not (lens.get_meta("guide_lens_color", Color.TRANSPARENT) as Color).is_equal_approx(
			light.light_color
		)
	):
		return null
	return lens


func _guide_batches(world: ShipyardWorld) -> Array[MultiMeshInstance3D]:
	var batches: Array[MultiMeshInstance3D] = []
	for candidate in world.find_children("*", "MultiMeshInstance3D", true, false):
		var batch := candidate as MultiMeshInstance3D
		if bool(batch.get_meta("guide_lens_batch", false)):
			batches.append(batch)
	batches.sort_custom(func(a: MultiMeshInstance3D, b: MultiMeshInstance3D) -> bool:
		return str(a.name) < str(b.name)
	)
	return batches


func _guide_light_behavior_rows(world: ShipyardWorld, lights: Array[OmniLight3D]) -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	for light in lights:
		rows.append({
			"path": _stable_guide_node_path(world, light),
			"position": [light.position.x, light.position.y, light.position.z],
			"color": light.light_color.to_html(true),
			"energy": float(light.get_meta("base_energy", light.light_energy)),
			"range": light.omni_range,
			"shadow": light.shadow_enabled,
			"pulsing": light.has_meta("pulse_phase"),
			"pulse_phase": float(light.get_meta("pulse_phase", -1.0)),
			"base_energy": float(light.get_meta("base_energy", -1.0)),
		})
	rows.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return str(a.path) < str(b.path))
	return rows


## Independent copy of the production path policy: explicit names are retained,
## while runtime fallback names use deterministic same-class sibling ordinals.
## This avoids deriving the test fingerprint from the implementation under test.
static func _stable_guide_node_path(scene_root: Node, node: Node) -> String:
	if node == scene_root:
		return "."
	var segments := PackedStringArray()
	var cursor := node
	while cursor != null and cursor != scene_root:
		segments.append(_stable_guide_sibling_segment(cursor))
		cursor = cursor.get_parent()
	if cursor != scene_root:
		return "<outside-scene>/%s" % "/".join(segments)
	segments.reverse()
	return "/".join(segments)


static func _stable_guide_sibling_segment(node: Node) -> String:
	var runtime_name := str(node.name)
	if not runtime_name.begins_with("@"):
		return runtime_name
	var parent := node.get_parent()
	if parent == null:
		return "%s[01]" % node.get_class()
	var ordinal := 0
	for sibling in parent.get_children():
		if sibling.get_class() == node.get_class() and str(sibling.name).begins_with("@"):
			ordinal += 1
		if sibling == node:
			break
	return "%s[%02d]" % [node.get_class(), ordinal]


func _has_error(report: Dictionary, error: String) -> bool:
	return error in (report.get("errors", PackedStringArray()) as PackedStringArray)


func _check(condition: bool, message: String) -> void:
	_assertions += 1
	if condition:
		print("PASS: ", message)
	else:
		_failures.append(message)
		push_error("FAIL: " + message)


func _finish() -> void:
	if _failures.is_empty():
		print("UPPER_OPERATIONS_ALLOCATION_TEST_OK: %d assertions" % _assertions)
		quit(0)
	else:
		push_error("Upper operations allocation tests failed (%d/%d): %s" % [
			_failures.size(), _assertions, "; ".join(_failures)
		])
		quit(1)
