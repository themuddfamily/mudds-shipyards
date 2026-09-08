extends SceneTree

const ShipComponentDamageType := preload("res://scripts/combat/ship_component_damage.gd")

const CRAFT_EXHAUST := {
	"TorrentInterceptor": {"plumes": "_engine_glows", "lights": "_engine_lights", "axis": &"z"},
	"ArrowReconShip": {"plumes": "_engine_plumes", "lights": "_arrow_engine_lights", "axis": &"y"},
	"JovianLightFreighter": {"plumes": "_engine_plumes", "lights": "_jovian_engine_lights", "axis": &"y"},
	"ZenithInterceptor": {"plumes": "_engine_plumes", "lights": "", "axis": &"z"},
	"HalyardCrewTransport": {"plumes": "_engine_plumes", "lights": "_halyard_engine_lights", "axis": &"y"},
	"BulwarkHeavyGunship": {"plumes": "_engine_glows", "lights": "_engine_lights", "axis": &"z"},
	"CinderLightInterceptor": {"plumes": "_engine_glows", "lights": "_engine_lights", "axis": &"z"},
	"CinderLongRangeBomber": {"plumes": "_engine_glows", "lights": "_engine_lights", "axis": &"z"},
	"CinderCargoHauler": {"plumes": "_engine_glows", "lights": "_engine_lights", "axis": &"z"},
}
const STREAMED_CRAFT := {
	"CinderLightInterceptor": preload("res://scripts/ships/cinder_light_interceptor.gd"),
	"CinderLongRangeBomber": preload("res://scripts/ships/cinder_long_range_bomber.gd"),
	"CinderCargoHauler": preload("res://scripts/ships/cinder_cargo_hauler.gd"),
}

var _assertions := 0
var _failures: PackedStringArray = []


func _init() -> void:
	call_deferred(&"_run")


func _run() -> void:
	var packed := load("res://scenes/main.tscn") as PackedScene
	var game := packed.instantiate() as GameFlow if packed != null else null
	_check(game != null, "production Main instantiates for component-graded hero exhaust")
	if game == null:
		_finish()
		return
	root.add_child(game)
	await process_frame
	await physics_frame

	for craft_name: String in CRAFT_EXHAUST:
		var craft := game.get_node_or_null(craft_name) as HeroShip
		# Streamed craft are normally absent from the station fixture. Instantiate
		# their production components here to exercise the same exhaust contract.
		if craft == null and STREAMED_CRAFT.has(craft_name):
			craft = STREAMED_CRAFT[craft_name].new() as HeroShip
			craft.name = craft_name
			game.add_child(craft)
			await process_frame
		var exhaust: Dictionary = CRAFT_EXHAUST[craft_name]
		var plumes := craft.get(StringName(exhaust.plumes)) as Array
		var lights: Array = [] if str(exhaust.lights).is_empty() else craft.get(
			StringName(exhaust.lights)
		) as Array
		var axis := StringName(exhaust.axis)
		craft.set_physics_process(false)
		craft.set("_landed", false)
		craft.set("_engine_state", HeroShip.ENGINE_ONLINE)
		craft.set("_throttle", 1.0)
		craft.call("_sync_engine_visuals_immediately")
		var nominal_profile := craft.get_engine_exhaust_damage_presentation_profile()
		var nominal_extent := _plume_extent(plumes[0] as MeshInstance3D, axis)
		var original_overlays: Array[Material] = []
		var original_meshes: Array[Mesh] = []
		for plume_value in plumes:
			original_overlays.append((plume_value as MeshInstance3D).material_overlay)
			original_meshes.append((plume_value as MeshInstance3D).mesh)
		_check(
			nominal_profile.get("stage") == &"nominal"
			and _visible_plume_count(plumes) == plumes.size()
			and not bool(nominal_profile.get("flashing", true))
			and nominal_profile.get("transition_policy") == &"static",
			"%s nominal output keeps every real plume with a static accessibility-safe grade" % craft_name
		)
		if craft is HalyardCrewTransport:
			var core_material := craft.get_variant_materials().engine as StandardMaterial3D
			var idle_energy := core_material.emission_energy_multiplier
			craft.velocity = Vector3.BACK * craft.maximum_speed
			craft.call("_update_halyard_presentation", 0.0)
			_check(core_material.emission_energy_multiplier > idle_energy \
				and core_material.emission_energy_multiplier < 2.0,
				"Halyard physical throat brightens with output without returning to full-white core glare")
			craft.velocity = Vector3.ZERO
			craft.call("_sync_engine_visuals_immediately")

		var model := craft.get_component_damage()
		var engine_position := _component_local_position(
			craft, ShipComponentDamageType.COMPONENT_ENGINE_BAY
		)
		var damage_guard := 0
		while model.get_component_state(ShipComponentDamageType.COMPONENT_ENGINE_BAY) \
				< ShipComponentDamageType.ComponentState.FAILED and damage_guard < 4:
			model.record_damage(craft.maximum_hull * 2.0, engine_position)
			damage_guard += 1
		craft.call("_sync_engine_visuals_immediately")
		var failed_profile := craft.get_engine_exhaust_damage_presentation_profile()
		_check(
			failed_profile.get("stage") == &"failed"
			and _visible_plume_count(plumes) == 0
			and is_zero_approx(float(failed_profile.get("intensity_multiplier", 1.0)))
			and StringName(craft.get_telemetry().get("engine_state", &"")) == HeroShip.ENGINE_ONLINE
			and not bool(failed_profile.get("gameplay_authority", true)),
			"%s failed engine bay suppresses exhaust without changing engine ONLINE authority" % craft_name
		)
		_check_halyard_core_mounts(craft, HalyardCrewTransport.ENGINE_CYAN, 0)

		_repair_engine_to(craft, 0.32)
		craft.call("_sync_engine_visuals_immediately")
		var critical_profile := craft.get_engine_exhaust_damage_presentation_profile()
		var critical_extent := _plume_extent(plumes[0] as MeshInstance3D, axis)
		var critical_overlay := (plumes[0] as MeshInstance3D).material_overlay as ShaderMaterial
		_check(
			critical_profile.get("stage") == &"critical"
			and _visible_plume_count(plumes) == ceili(float(plumes.size()) * 0.5)
			and critical_extent < nominal_extent
			and critical_overlay != null
			and (critical_overlay.get_shader_parameter(&"exhaust_color") as Color).is_equal_approx(Color("ff653a"))
			and bool(critical_overlay.get_shader_parameter(&"damage_pass"))
			and is_equal_approx(float((plumes[0] as MeshInstance3D).get_instance_shader_parameter(&"plume_damage_mix")), 1.0),
			"%s critical output is short red-orange exhaust on alternating propulsion mounts" % craft_name
		)
		_check_halyard_core_mounts(craft, Color("ff653a"), 2)

		_repair_engine_to(craft, 0.55)
		craft.call("_sync_engine_visuals_immediately")
		var degraded_profile := craft.get_engine_exhaust_damage_presentation_profile()
		var degraded_extent := _plume_extent(plumes[0] as MeshInstance3D, axis)
		var degraded_overlay := (plumes[0] as MeshInstance3D).material_overlay as ShaderMaterial
		_check(
			degraded_profile.get("stage") == &"degraded"
			and _visible_plume_count(plumes) == plumes.size()
			and degraded_extent > critical_extent
			and degraded_extent < nominal_extent
			and degraded_overlay != null
			and (degraded_overlay.get_shader_parameter(&"exhaust_color") as Color).is_equal_approx(Color("ffd166")),
			"%s degraded output keeps all mounts but shortens, dims, and warms their exhaust" % craft_name
		)
		_check_halyard_core_mounts(craft, Color("ffd166"), 4)
		if not lights.is_empty():
			_check(
				(lights[0] as OmniLight3D).light_color.is_equal_approx(Color("ffd166")),
				"%s existing engine practical follows the degraded exhaust color" % craft_name
			)

		_repair_engine_to(craft, 1.0)
		craft.call("_sync_engine_visuals_immediately")
		var repaired_profile := craft.get_engine_exhaust_damage_presentation_profile()
		var overlays_restored := true
		for index in plumes.size():
			overlays_restored = overlays_restored \
				and (plumes[index] as MeshInstance3D).material_overlay == original_overlays[index] \
				and (plumes[index] as MeshInstance3D).mesh == original_meshes[index] \
				and is_zero_approx(float((plumes[index] as MeshInstance3D).get_instance_shader_parameter(&"plume_damage_mix")))
		_check(
			repaired_profile.get("stage") == &"nominal"
			and _visible_plume_count(plumes) == plumes.size()
			and _plume_extent(plumes[0] as MeshInstance3D, axis) >= nominal_extent
			and overlays_restored
			and int(repaired_profile.get("maximum_overlay_material_resources_per_ship", 0)) == 1
			and int(repaired_profile.get("added_nodes", -1)) == 0
			and int(repaired_profile.get("added_meshes", -1)) == 0,
			"%s repair restores nominal geometry and authored materials with one retained overlay resource" % craft_name
		)
		if craft is HalyardCrewTransport:
			_check_halyard_core_mounts(craft, HalyardCrewTransport.ENGINE_CYAN, 4)

		craft.set("_engine_state", HeroShip.ENGINE_OFFLINE)
		craft.call("_sync_engine_visuals_immediately")
		_check(
			_visible_plume_count(plumes) == 0
			and craft.get_engine_exhaust_damage_presentation_profile().get("stage") == &"nominal"
			and craft.find_children("*", "ShipComponentDamage", true, false).size() == 1,
			"%s preserves engine-offline suppression and its single component ledger" % craft_name
		)

	var zenith := game.get_node("ZenithInterceptor") as HeroShip
	zenith.set("_engine_state", HeroShip.ENGINE_ONLINE)
	var zenith_model := zenith.get_component_damage()
	var zenith_engine_position := _component_local_position(
		zenith, ShipComponentDamageType.COMPONENT_ENGINE_BAY
	)
	zenith_model.record_damage(zenith.maximum_hull * 2.0, zenith_engine_position)
	_repair_engine_to(zenith, 0.55)
	zenith.call("_sync_engine_visuals_immediately")
	var zenith_plumes := zenith.get("_engine_plumes") as Array
	var plume_ids_before: Array[int] = []
	for plume_value in zenith_plumes:
		plume_ids_before.append((plume_value as MeshInstance3D).get_instance_id())
	root.remove_child(game)
	await process_frame
	root.add_child(game)
	await process_frame
	var plume_ids_after: Array[int] = []
	for plume_value in zenith.get("_engine_plumes") as Array:
		plume_ids_after.append((plume_value as MeshInstance3D).get_instance_id())
	_check(
		plume_ids_before == plume_ids_after
		and _visible_plume_count(zenith.get("_engine_plumes") as Array) == zenith_plumes.size()
		and zenith.get_engine_exhaust_damage_presentation_profile().get("stage") == &"degraded",
		"whole-Main detach/re-entry preserves the same graded exhaust nodes without duplication"
	)

	for craft_name: String in CRAFT_EXHAUST:
		var craft := game.get_node(craft_name) as HeroShip
		var reset := craft.reset_for_reuse(craft.global_transform)
		var plumes := craft.get(StringName((CRAFT_EXHAUST[craft_name] as Dictionary).plumes)) as Array
		_check(
			bool(reset.get("accepted", false))
			and craft.get_engine_exhaust_damage_presentation_profile().get("stage") == &"nominal"
			and _visible_plume_count(plumes) == 0,
			"%s respawn/reuse restores nominal component grade with propulsion offline" % craft_name
		)
		_check_halyard_core_mounts(craft, HalyardCrewTransport.ENGINE_CYAN, 0)

	game.queue_free()
	await process_frame
	_finish()


func _check_halyard_core_mounts(craft: HeroShip, tint: Color, expected_visible: int) -> void:
	if not craft is HalyardCrewTransport:
		return
	var cores := craft.get("_engine_cores") as Array
	var plumes := craft.get("_engine_plumes") as Array
	var lights := craft.get("_halyard_engine_lights") as Array
	var material := craft.get_variant_materials().engine as StandardMaterial3D
	var correct := _visible_plume_count(cores) == expected_visible
	for index in cores.size():
		var core := cores[index] as MeshInstance3D
		correct = correct and core.visible == (plumes[index] as MeshInstance3D).visible \
			and core.get_active_material(0) == material
		if not core.visible:
			correct = correct and is_zero_approx((lights[index] as OmniLight3D).light_energy)
	if expected_visible > 0:
		correct = correct and material.emission.is_equal_approx(tint)
	_check(correct, "Halyard %s keeps its four physical cores and practicals aligned with the real exhaust mounts" \
		% craft.get_engine_exhaust_damage_presentation_profile().stage)


func _repair_engine_to(craft: HeroShip, target_integrity: float) -> void:
	var model := craft.get_component_damage()
	var before := model.get_component_integrity(ShipComponentDamageType.COMPONENT_ENGINE_BAY)
	var delta := maxf(
		(target_integrity - before) / maxf(model.repair_rate_per_second, 0.001),
		0.001
	)
	model.tick_component_repair(ShipComponentDamageType.COMPONENT_ENGINE_BAY, delta, true)


func _component_local_position(ship: HeroShip, component_id: StringName) -> Vector3:
	for component in ship.get_component_damage_report().get("components", []) as Array:
		if StringName((component as Dictionary).get("id", &"")) == component_id:
			return (component as Dictionary).get("local_position", Vector3.ZERO) as Vector3
	return Vector3.ZERO


func _visible_plume_count(plumes: Array) -> int:
	var count := 0
	for plume_value in plumes:
		var plume := plume_value as MeshInstance3D
		if is_instance_valid(plume) and plume.visible:
			count += 1
	return count


func _plume_extent(plume: MeshInstance3D, axis: StringName) -> float:
	return plume.scale.y if axis == &"y" else plume.scale.z


func _check(condition: bool, message: String) -> void:
	_assertions += 1
	if condition:
		print("PASS: %s" % message)
	else:
		_failures.append(message)
		push_error("FAIL: %s" % message)


func _finish() -> void:
	if _failures.is_empty():
		print("HERO_ENGINE_EXHAUST_COMPONENT_DAMAGE_TEST_OK (%d assertions)" % _assertions)
		quit(0)
		return
	print("HERO_ENGINE_EXHAUST_COMPONENT_DAMAGE_TEST_FAILED: %s" % "; ".join(_failures))
	quit(1)
