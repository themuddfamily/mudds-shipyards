extends SceneTree

const AFT_SCENE := preload("res://scenes/world/modules/aft_junction_stack.tscn")
const HABITAT_SCENE := preload("res://scenes/world/modules/habitat_spine.tscn")

var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var host := Node3D.new()
	host.name = "StationInteriorWarmthTestRoot"
	root.add_child(host)
	var aft := AFT_SCENE.instantiate() as AftJunctionStack
	var habitat := HABITAT_SCENE.instantiate() as HabitatSpine
	_check(aft != null and habitat != null, "both production station-room modules instantiate")
	if aft == null or habitat == null:
		_finish()
		return
	host.add_child(aft)
	host.add_child(habitat)
	await process_frame

	_test_operations_warmth(aft)
	_test_common_room_warmth(habitat)
	_test_exact_scene_contracts(aft, habitat)

	host.queue_free()
	await process_frame
	_finish()


func _test_operations_warmth(aft: AftJunctionStack) -> void:
	var lighting := aft.get_node_or_null(
		^"Structure/OperationsRoom/LocalizedLighting"
	) as Node3D
	_check(lighting != null, "operations room retains its localized-lighting construction seam")
	if lighting == null:
		return
	var warm_rail := lighting.get_node_or_null(^"WarmCeilingCoveRail") as MeshInstance3D
	var cool_rail := lighting.get_node_or_null(^"CoolCeilingCoveRail") as MeshInstance3D
	var warm_spills := _nodes_with_role(lighting, &"operations_cove_spill")
	var cool_spills := _lights_with_color(lighting, Color("bfeef2"))
	_check(
		warm_rail != null and cool_rail != null
		and warm_rail.material_override != cool_rail.material_override,
		"operations coves expose distinct warm-source and cool-source materials"
	)
	_check(
		warm_spills.size() == 3 and cool_spills.size() == 3
		and lighting.find_children("*", "OmniLight3D", true, false).size() == 16,
		"operations warmth uses the exact existing 3+3 cove roster inside the frozen 16-light room rig"
	)
	_test_static_authored_practicals(
		warm_spills,
		&"operations_cove_spill",
		AftJunctionStack.OPERATIONS_WARM_COVE_COLOR,
		6.4
	)
	_test_bounded_overlap(warm_spills, 2.5, "operations warm cove pools overlap only along their authored rail")
	_check(
		warm_rail != null
		and StringName(warm_rail.get_meta("station_interior_warmth", &"")) == &"operations_cove_source"
		and StringName(warm_rail.get_meta("evidence_status", &"")) == &"modern_interpretation"
		and bool(warm_rail.get_meta("reduced_flash_safe", false)),
		"operations warm source is explicitly authored modern interpretation and static reduced-flash-safe presentation"
	)
	if not warm_spills.is_empty() and not cool_spills.is_empty():
		var warm := warm_spills[0] as OmniLight3D
		var cool := cool_spills[0] as OmniLight3D
		_check(
			warm.light_color.r > warm.light_color.b
			and cool.light_color.b > cool.light_color.r,
			"operations practicals preserve readable amber/cyan hue separation without cue-palette changes"
		)


func _test_common_room_warmth(habitat: HabitatSpine) -> void:
	var common := habitat.get_node_or_null(^"Structure/ObservationCommon") as Node3D
	_check(common != null, "habitat common room retains its authored room construction seam")
	if common == null:
		return
	var sill := common.get_node_or_null(^"RearSillCoveLens") as MeshInstance3D
	var warm_spills := _nodes_with_role(common, &"common_room_sill_spill")
	var table_glow := common.get_node_or_null(^"TableDisplayGlow") as OmniLight3D
	_check(
		warm_spills.size() == 3
		and common.find_children("*", "OmniLight3D", false, false).size() == 11,
		"common-room warmth reuses the exact three sill pools inside the frozen 11-light room rig"
	)
	_test_static_authored_practicals(
		warm_spills,
		&"common_room_sill_spill",
		HabitatSpine.COMMON_WARM_SILL_COLOR,
		4.2
	)
	_test_bounded_overlap(warm_spills, 5.2, "habitat sill pools overlap only enough to carry the existing long lens")
	_check(
		sill != null
		and StringName(sill.get_meta("station_interior_warmth", &"")) == &"common_room_sill_source"
		and StringName(sill.get_meta("evidence_status", &"")) == &"modern_interpretation"
		and bool(sill.get_meta("reduced_flash_safe", false)),
		"habitat sill source is explicitly authored modern interpretation and static reduced-flash-safe presentation"
	)
	if not warm_spills.is_empty() and table_glow != null:
		var warm := warm_spills[0] as OmniLight3D
		_check(
			warm.light_color.r > warm.light_color.b
			and table_glow.light_color.b > table_glow.light_color.r,
			"warm sill spill remains hue-separated from the common room's cool table-display counterpoint"
		)


func _test_static_authored_practicals(
		nodes: Array[Node],
		expected_role: StringName,
		expected_color: Color,
		expected_range: float
	) -> void:
	var valid := true
	for raw_node in nodes:
		var light := raw_node as OmniLight3D
		valid = valid and light != null
		if light == null:
			continue
		valid = (
			valid
			and light.light_color.is_equal_approx(expected_color)
			and is_equal_approx(light.omni_range, expected_range)
			and is_equal_approx(light.omni_attenuation, 2.1)
			and not light.shadow_enabled
			and light.distance_fade_enabled
			and is_equal_approx(light.distance_fade_begin, 60.0)
			and is_equal_approx(light.distance_fade_length, 25.0)
			and StringName(light.get_meta("station_interior_warmth", &"")) == expected_role
			and StringName(light.get_meta("evidence_status", &"")) == &"modern_interpretation"
			and bool(light.get_meta("reduced_flash_safe", false))
			and bool(light.get_meta("presentation_only", false))
			and light.get_script() == null
			and not light.is_processing()
			and not light.is_physics_processing()
			and light.get_child_count() == 0
		)
	_check(valid, "warm practical roster is static, shadowless, range/fade bounded, authority-free, and reduced-flash compatible")


func _test_bounded_overlap(nodes: Array[Node], expected_spacing: float, message: String) -> void:
	var valid := nodes.size() == 3
	if nodes.size() != 3:
		_check(false, message)
		return
	for index in 2:
		var first := nodes[index] as OmniLight3D
		var second := nodes[index + 1] as OmniLight3D
		if first == null or second == null:
			valid = false
			continue
		var spacing := first.position.distance_to(second.position)
		valid = (
			valid
			and is_equal_approx(spacing, expected_spacing)
			and spacing < first.omni_range + second.omni_range
			and spacing > minf(first.omni_range, second.omni_range) * 0.3
		)
	_check(valid, message)


func _nodes_with_role(parent: Node, role: StringName) -> Array[Node]:
	var result: Array[Node] = []
	for candidate in parent.find_children("*", "", true, false):
		if StringName(candidate.get_meta("station_interior_warmth", &"")) == role:
			result.append(candidate)
	return result


func _lights_with_color(parent: Node, color: Color) -> Array[Node]:
	var result: Array[Node] = []
	for candidate in parent.find_children("*", "OmniLight3D", true, false):
		var light := candidate as OmniLight3D
		if light != null and light.light_color.is_equal_approx(color):
			result.append(light)
	return result


func _test_exact_scene_contracts(aft: AftJunctionStack, habitat: HabitatSpine) -> void:
	var aft_performance: Dictionary = aft.get_performance_contract()
	var habitat_performance: Dictionary = habitat.get_performance_contract()
	var aft_render: Dictionary = aft.get_pod_corner_collar_visual_allocation_audit().current
	var habitat_render: Dictionary = habitat.get_render_allocation_report()
	_check(
		int(aft_performance.lights) == 50
		and int(aft_performance.budgets.lights) == 50
		and int(aft_performance.mesh_instances) == 788
		and int(aft_performance.budgets.mesh_instances) == 828
		and int(aft_render.descendant_nodes) == 1182
		and int(aft_render.renderer_nodes) == 800
		and bool(aft_performance.within_budget),
		"Aft keeps exact 50-light, 788/828-mesh, 1182-node, and 800-renderer-node budgets"
	)
	_check(
		int(habitat_performance.lights) == 35
		and int(habitat_performance.budgets.lights) == 35
		and int(habitat_performance.mesh_instances) == 1216
		and int(habitat_render.descendant_nodes) == 1874
		and int(habitat_render.multimesh_batches) == 27
		and bool(habitat_performance.within_budget),
		"Habitat keeps exact 35-light, 1216-mesh, 1874-node, and 27-MultiMesh budgets"
	)
	for module in [aft, habitat]:
		var authority: Dictionary = module.get_authority_contract()
		_check(
			int(authority.lease_authority_count) == 0
			and int(authority.spawn_authority_count) == 0
			and str(authority.network_authority_role) == "none",
			"interior warmth adds no lease, spawn, or network authority"
		)
	_check(
		int(aft.get_collision_contract().body_count) == 106
		and int(aft.get_collision_contract().shape_count) == 117
		and int(habitat.get_collision_contract().body_count) == 245
		and int(habitat.get_collision_contract().shape_count) == 266,
		"collision, layout, and navigation-facing scene bodies remain at their exact existing counts"
	)


func _check(condition: bool, message: String) -> void:
	if condition:
		print("PASS: %s" % message)
	else:
		_failures.append(message)
		push_error("FAIL: %s" % message)


func _finish() -> void:
	if _failures.is_empty():
		print("STATION_INTERIOR_WARMTH_TEST_PASS")
		quit(0)
	else:
		print("STATION_INTERIOR_WARMTH_TEST_FAIL: %s" % ", ".join(_failures))
		quit(1)
