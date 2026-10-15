extends SceneTree

## Focused presentation regression for the wider lattice, catwalk, and control
## room's station-family finish hierarchy and immutable impact geometry reuse.
## This does not claim lighting or native performance completion.

const WORLD_SCENE := preload("res://scenes/world/shipyard_world.tscn")

var _assertions := 0
var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var world := WORLD_SCENE.instantiate() as ShipyardWorld
	_check(world != null, "ShipyardWorld instantiates for finish-profile audit")
	if world == null:
		_finish()
		return
	root.add_child(world)
	await process_frame
	var materials := world.get("_materials") as Dictionary
	_check(materials != null, "world exposes its constructed material roster")
	if materials != null:
		_check(_finish_matches(materials.get("deck"), 0.06, 0.72), "walked deck uses the restrained matte finish")
		_check(_finish_matches(materials.get("deck_light"), 0.06, 0.72), "light deck uses the restrained matte finish")
		_check(_finish_matches(materials.get("steel_blue"), 0.30, 0.24), "lattice/control-room trim uses the tight edge finish")
		_check(_finish_matches(materials.get("navy"), 0.18, 0.38), "control-room structural panels use the alloy finish")
		for key in ["ivory", "orange", "red"]:
			_check(
				_finish_matches(materials.get(key), 0.45, 0.12),
				"exterior safety-paint %s retains its coated-metal finish" % key,
			)
		for key in ["deck", "deck_light", "navy", "steel_blue"]:
			var material := materials.get(key) as StandardMaterial3D
			_check(
				material != null and material.uv1_triplanar and material.uv1_world_triplanar
				and material.uv1_scale.is_equal_approx(Vector3.ONE * 0.3),
				"wide-station %s keeps the shared world-metric panel mapping" % key
			)
		for key in ["ivory", "orange", "red"]:
			var painted := materials.get(key) as StandardMaterial3D
			_check(
				painted != null and painted.uv1_triplanar and painted.uv1_world_triplanar
				and painted.uv1_scale.is_equal_approx(Vector3.ONE * 0.3),
				"exterior safety-paint %s joins the shared panel family" % key,
			)
		var rail := world.find_child("BranchRail", true, false) as StaticBody3D
		var post := world.find_child("BranchRailPost", true, false) as StaticBody3D
		var toolbox := world.find_child("StandToolbox", true, false) as StaticBody3D
		_check(
			_surface_material(rail) == materials.get("ivory")
			and _surface_material(post) == materials.get("orange")
			and _surface_material(toolbox) == materials.get("red"),
			"paired catwalk guards and service equipment use the coherent safety-paint family",
		)
		var berth := world.get_central_berth_hero_presentation()
		var deck := berth.get_runtime_material(&"DeckComposite") if berth != null else null
		var edge := berth.get_runtime_material(&"EdgeIvory") if berth != null else null
		var structure := berth.get_runtime_material(&"StructuralAlloy") if berth != null else null
		var service := berth.get_runtime_material(&"ServiceGraphite") if berth != null else null
		_check(
			_panel_mapped(deck) and _finish_matches(deck, 0.06, 0.72)
			and _panel_mapped(edge) and _finish_matches(edge, 0.30, 0.24)
			and _panel_mapped(structure) and _finish_matches(structure, 0.18, 0.38)
			and _panel_mapped(service) and _finish_matches(service, 0.45, 0.12),
			"central berth separates walked, grip, frame, and service finishes on shared world-metric maps",
		)
		var primary := berth.get_semantic_root(&"primary_structure") if berth != null else null
		var secondary := berth.get_semantic_root(&"secondary_structure") if berth != null else null
		_check(
			_role_root_uses_material(primary, &"StructuralAlloy", structure)
			and _role_root_uses_material(secondary, &"StructuralAlloy", structure),
			"both authored central-berth beam/frame batches use the mapped structural alloy",
		)
		var berth_audit := berth.get_asset_audit_report() if berth != null else {}
		_check(
			bool(berth_audit.get("valid", false))
			and int(berth_audit.get("runtime_mesh_count", 0)) == 8
			and int(berth_audit.get("runtime_triangle_count", 0)) == 11508 + CentralBerthHeroPresentation.APPROACH_FASCIA_RUNTIME_TRIANGLE_DELTA,
			"material-only berth finish preserves the authored mesh and triangle contract",
		)
	await _check_impact_resources(world)
	world.queue_free()
	await process_frame
	_finish()


func _check_impact_resources(world: ShipyardWorld) -> void:
	var impacts: Array[MeshInstance3D] = []
	var mesh_ids := {}
	var material_ids := {}
	var colors := [Color(1.0, 0.4, 0.1), Color(0.1, 0.7, 1.0)]
	var authored_state := true
	var authored_observations: Array[Dictionary] = []
	var existing_tweens := get_processed_tweens()
	for index in 4:
		var at := Vector3(float(index), 2.0, -3.0)
		var color: Color = colors[index % colors.size()]
		var impact := world.call(&"_spawn_impact", at, color) as MeshInstance3D
		impacts.append(impact)
		mesh_ids[impact.mesh.get_instance_id()] = true
		material_ids[impact.material_override.get_instance_id()] = true
		var material := impact.material_override as StandardMaterial3D
		authored_observations.append({"top_level": impact.is_set_as_top_level(),
			"position": impact.global_position, "expected_position": at, "scale": impact.scale,
			"children": impact.get_child_count(), "albedo": material.albedo_color,
			"emission": material.emission, "expected_color": color,
			"emission_energy": material.emission_energy_multiplier})
		authored_state = authored_state and impact.is_set_as_top_level() \
			and impact.global_position.is_equal_approx(at) and impact.scale == Vector3.ONE \
			and impact.get_child_count() == 0 and material.albedo_color == color \
			and material.emission == color and is_equal_approx(material.emission_energy_multiplier, 6.0)
	_check(impacts.size() == 4 and mesh_ids.size() == 1 and material_ids.size() == 4,
		"four simultaneous impact flashes share one immutable mesh while retaining four independent materials")
	var shared := impacts[0].mesh as SphereMesh
	var original_recipe := SphereMesh.new()
	original_recipe.radius = 0.16
	original_recipe.height = 0.16 * 2.0
	original_recipe.radial_segments = 24
	original_recipe.rings = 12
	var original_arrays := original_recipe.get_mesh_arrays()
	var shared_arrays: Array = shared.get_mesh_arrays() if shared != null else []
	var geometry_matches := shared != null and is_equal_approx(shared.radius, 0.16) and is_equal_approx(shared.height, 0.32) \
		and shared.radial_segments == 24 and shared.rings == 12 and shared.get_surface_count() == 1 \
		and shared.get_aabb().is_equal_approx(original_recipe.get_aabb()) \
		and not original_arrays.is_empty() and (original_arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array).size() > 0 \
		and shared_arrays == original_arrays and authored_state
	if not geometry_matches:
		print("IMPACT_GEOMETRY_DIAGNOSTIC: ", {"authored_state": authored_state,
			"shared_is_sphere": shared != null, "arrays_match": shared_arrays == original_arrays,
			"aabb": shared.get_aabb() if shared != null else AABB(), "original_recipe_aabb": original_recipe.get_aabb(),
			"instances": authored_observations})
	_check(geometry_matches,
		"shared impacts retain their exact authored sphere, colors, placement and collision-free node envelope")
	var impact_tweens: Array[Tween] = []
	for tween in get_processed_tweens():
		if not existing_tweens.has(tween):
			impact_tweens.append(tween)
	var finished_tweens := {}
	for tween in impact_tweens:
		tween.finished.connect(_record_impact_tween_finished.bind(tween.get_instance_id(), finished_tweens), CONNECT_ONE_SHOT)
	var retirement_started := Time.get_ticks_usec()
	var frame_started := Engine.get_process_frames()
	var retirement_deadline := Time.get_ticks_msec() + 5_000
	# A SceneTreeTimer and an idle Tween do not consume the same startup delta.
	# Observe the owned animations, then allow their queued deletion to flush.
	while finished_tweens.size() < impact_tweens.size() and Time.get_ticks_msec() < retirement_deadline:
		await process_frame
	await process_frame
	var all_retired := true
	for impact in impacts:
		all_retired = all_retired and not is_instance_valid(impact)
	var elapsed_matches := true
	for tween in impact_tweens:
		elapsed_matches = elapsed_matches and not tween.is_running() and tween.get_total_elapsed_time() >= 0.18
	var retirement_matches := all_retired and impact_tweens.size() == 4 and finished_tweens.size() == 4 and elapsed_matches
	_check(retirement_matches, "each shared-geometry impact finishes its original 0.18-second animation and retires")
	if not retirement_matches:
		var retirement_observations: Array[Dictionary] = []
		for impact in impacts:
			retirement_observations.append({"valid": is_instance_valid(impact),
				"queued": impact.is_queued_for_deletion() if is_instance_valid(impact) else false,
				"scale": impact.scale if is_instance_valid(impact) else Vector3.ZERO})
		var tween_observations: Array[Dictionary] = []
		for tween in impact_tweens:
			tween_observations.append({"valid": tween.is_valid(), "running": tween.is_running(),
				"elapsed": tween.get_total_elapsed_time(), "loops_left": tween.get_loops_left()})
		print("IMPACT_RETIREMENT_DIAGNOSTIC: ", {"wall_seconds": float(Time.get_ticks_usec() - retirement_started) / 1000000.0,
			"process_frames": Engine.get_process_frames() - frame_started,
			"finished_count": finished_tweens.size(), "tree_paused": paused, "time_scale": Engine.time_scale,
			"instances": retirement_observations, "tweens": tween_observations})
	var next := world.call(&"_spawn_impact", Vector3.ZERO, colors[0]) as MeshInstance3D
	_check(next.mesh == shared, "a later impact reuses the same geometry after the prior flashes retire")
	var separate := ShipyardWorld.new()
	_check(separate.call(&"_shared_projectile_impact_mesh") != shared,
		"impact geometry ownership stays local to each world rather than a global cache")
	separate.free()


func _record_impact_tween_finished(tween_id: int, finished_tweens: Dictionary) -> void:
	finished_tweens[tween_id] = true


func _finish_matches(value: Variant, clearcoat: float, roughness: float) -> bool:
	var material := value as StandardMaterial3D
	return material != null and material.clearcoat_enabled \
		and is_equal_approx(material.clearcoat, clearcoat) \
		and is_equal_approx(material.clearcoat_roughness, roughness)


func _panel_mapped(material: StandardMaterial3D) -> bool:
	return material != null and material.albedo_texture != null \
		and material.albedo_texture.resource_path == StationSurfaceKit.PANEL_ALBEDO_PATH \
		and material.normal_texture != null \
		and material.normal_texture.resource_path == StationSurfaceKit.PANEL_NORMAL_PATH \
		and material.roughness_texture != null \
		and material.roughness_texture.resource_path == StationSurfaceKit.PANEL_ROUGHNESS_PATH \
		and material.uv1_triplanar and material.uv1_world_triplanar \
		and material.uv1_scale.is_equal_approx(Vector3.ONE * 0.3)


func _surface_material(body: StaticBody3D) -> Material:
	if body == null:
		return null
	var mesh := body.get_node_or_null(^"Mesh") as MeshInstance3D
	return mesh.material_override if mesh != null else null


func _role_root_uses_material(root_node: Node3D, role: StringName, material: Material) -> bool:
	if root_node == null or material == null:
		return false
	var matched := false
	for candidate in root_node.find_children("*", "MeshInstance3D", true, false):
		var mesh := candidate as MeshInstance3D
		if StringName(mesh.get_meta("central_berth_material_role", &"")) != role:
			continue
		matched = true
		if mesh.material_override != material:
			return false
	return matched


func _check(condition: bool, message: String) -> void:
	_assertions += 1
	if not condition:
		_failures.append(message)


func _finish() -> void:
	if _failures.is_empty():
		print("PASS: shipyard_world_material_finish_test (%d assertions)" % _assertions)
	else:
		for failure in _failures:
			push_error("FAIL: " + failure)
		print("FAIL: shipyard_world_material_finish_test (%d assertions, %d failures)" % [_assertions, _failures.size()])
	quit(1 if not _failures.is_empty() else 0)
