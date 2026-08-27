extends SceneTree

const TORRENT_SCENE := preload("res://scenes/ships/torrent_interceptor.tscn")
const ComponentDamage := preload("res://scripts/combat/ship_component_damage.gd")

var _assertions := 0
var _failures: PackedStringArray = []


func _init() -> void:
	call_deferred(&"_run")


func _run() -> void:
	var craft := TORRENT_SCENE.instantiate() as HeroShip
	root.add_child(craft)
	await process_frame
	await process_frame
	var presentation := craft.get_node_or_null(
		^"TorrentVisual/TorrentHeroPresentation"
	) as TorrentHeroPresentation
	_check(presentation != null, "production Torrent owns its close hero presentation")
	if presentation == null:
		_finish()
		return

	craft.set_physics_process(false)
	craft.set("_landed", false)
	craft.set("_engine_state", HeroShip.ENGINE_ONLINE)
	craft.set("_throttle", 1.0)
	craft.call("_sync_engine_visuals_immediately")
	await process_frame
	var nominal := presentation.get_engine_damage_silhouette_snapshot()
	var nominal_starboard := _core_by_name(nominal, &"StarboardEngineCore")
	var node_count := _count_descendants(presentation)
	var mesh_ids := _mesh_ids(presentation)
	_check(
		nominal.stage == &"nominal"
			and int(nominal.canted_core_count) == 0
			and nominal_starboard.transform.is_equal_approx(nominal_starboard.nominal_transform),
		"nominal engine output retains the authored symmetric core faces"
	)

	var model := craft.get_component_damage()
	var engine_position := _component_local_position(craft, ComponentDamage.COMPONENT_ENGINE_BAY)
	model.record_damage(craft.maximum_hull * 2.0, engine_position)
	_repair_engine_to(craft, 0.32)
	craft.call("_sync_engine_visuals_immediately")
	await process_frame
	var critical_profile := craft.get_engine_exhaust_damage_presentation_profile()
	var critical := presentation.get_engine_damage_silhouette_snapshot()
	var critical_starboard := _core_by_name(critical, &"StarboardEngineCore")
	var critical_port := _core_by_name(critical, &"PortEngineCore")
	_check(
		critical_profile.stage == &"critical"
			and int(critical.canted_core_count) == 1
			and bool(critical_starboard.canted)
			and not bool(critical_port.canted),
		"the existing critical engine state drops and cants only the failed-side core face"
	)
	_check(
		is_equal_approx(float(critical.cant_degrees), 42.0)
			and (critical.drop_offset as Vector3).is_equal_approx(Vector3(0.0, -0.22, 0.06))
			and critical_starboard.transform.origin.y
				< (critical_starboard.nominal_transform as Transform3D).origin.y - 0.2,
		"critical damage has a localized non-color-only silhouette displacement"
	)
	_check(
		_count_descendants(presentation) == node_count
			and _mesh_ids(presentation) == mesh_ids
			and int(critical.added_nodes) == 0
			and int(critical.added_meshes) == 0
			and int(critical.added_lights) == 0
			and not bool(critical.gameplay_authority),
		"damage staging reuses the exact retained nodes and meshes without authority or lights"
	)
	var critical_audit := presentation.get_asset_audit_report()
	_check(
		bool(critical_audit.valid),
		"the dynamic critical pose remains inside the imported Torrent integrity contract"
	)

	_repair_engine_to(craft, 1.0)
	craft.call("_sync_engine_visuals_immediately")
	await process_frame
	var repaired := presentation.get_engine_damage_silhouette_snapshot()
	var repaired_starboard := _core_by_name(repaired, &"StarboardEngineCore")
	_check(
		repaired.stage == &"nominal"
			and int(repaired.canted_core_count) == 0
			and repaired_starboard.transform.is_equal_approx(repaired_starboard.nominal_transform)
			and _count_descendants(presentation) == node_count
			and _mesh_ids(presentation) == mesh_ids,
		"component repair restores the exact authored pose without replacing resources"
	)

	craft.queue_free()
	await process_frame
	_finish()


func _core_by_name(snapshot: Dictionary, core_name: StringName) -> Dictionary:
	for record_variant in snapshot.get("cores", []) as Array:
		var record := record_variant as Dictionary
		if StringName(record.get("name", &"")) == core_name:
			return record
	return {}


func _component_local_position(craft: HeroShip, component_id: StringName) -> Vector3:
	for component_variant in craft.get_component_damage_report().get("components", []) as Array:
		var component := component_variant as Dictionary
		if StringName(component.get("id", &"")) == component_id:
			return component.get("local_position", Vector3.ZERO) as Vector3
	return Vector3.ZERO


func _repair_engine_to(craft: HeroShip, target_integrity: float) -> void:
	var model := craft.get_component_damage()
	var before := model.get_component_integrity(ComponentDamage.COMPONENT_ENGINE_BAY)
	var delta := maxf(
		(target_integrity - before) / maxf(model.repair_rate_per_second, 0.001),
		0.001
	)
	model.tick_component_repair(ComponentDamage.COMPONENT_ENGINE_BAY, delta, true)


func _mesh_ids(node: Node) -> PackedInt64Array:
	var result := PackedInt64Array()
	for candidate in node.find_children("*", "MeshInstance3D", true, false):
		var mesh := (candidate as MeshInstance3D).mesh
		result.append(mesh.get_instance_id() if mesh != null else 0)
	return result


func _count_descendants(node: Node) -> int:
	var count := 0
	for child in node.get_children():
		count += 1 + _count_descendants(child)
	return count


func _check(condition: bool, message: String) -> void:
	_assertions += 1
	if condition:
		print("PASS: ", message)
		return
	_failures.append(message)
	push_error("FAIL: %s" % message)


func _finish() -> void:
	if _failures.is_empty():
		print("TORRENT_ENGINE_DAMAGE_SILHOUETTE_TEST_OK (%d assertions)" % _assertions)
		quit(0)
		return
	print("TORRENT_ENGINE_DAMAGE_SILHOUETTE_TEST_FAILED: %s" % "; ".join(_failures))
	quit(1)
