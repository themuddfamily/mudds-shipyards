extends SceneTree

const ShipComponentDamageType := preload("res://scripts/combat/ship_component_damage.gd")

const CRAFTS := [
	"TorrentInterceptor",
	"ArrowReconShip",
	"JovianLightFreighter",
	"ZenithInterceptor",
	"HalyardCrewTransport",
]
const FALLBACK_CRAFTS := ["TorrentInterceptor", "ZenithInterceptor"]

var _assertions := 0
var _failures: PackedStringArray = []


func _init() -> void:
	call_deferred(&"_run")


func _run() -> void:
	var packed := load("res://scenes/main.tscn") as PackedScene
	var game := packed.instantiate() as GameFlow if packed != null else null
	_check(game != null, "production Main instantiates for component-graded weapon emitters")
	if game == null:
		_finish()
		return
	root.add_child(game)
	await process_frame
	await physics_frame

	var retained_ids := {}
	for craft_name: String in CRAFTS:
		var craft := game.get_node(craft_name) as HeroShip
		craft.set_physics_process(false)
		craft.set("_landed", false)
		craft.set("_engine_state", HeroShip.ENGINE_ONLINE)
		craft.set("_weapon_timer", 0.0)
		craft.call("_sync_weapon_component_presentation")
		var nominal := craft.get_weapon_component_emitter_snapshot()
		var nominal_extent := _first_emitter_extent(nominal)
		var nominal_overlays := _overlay_colors(nominal)
		var expected_fallback_nodes := 2 if craft_name in FALLBACK_CRAFTS else 0
		_check(
			(nominal.get("emitters", []) as Array).size() == 2
			and int(nominal.get("visible_emitter_count", -1)) == 2
			and int(nominal.get("fallback_node_count", -1)) == expected_fallback_nodes
			and int(nominal.get("fallback_mesh_count", -1)) <= 1
			and nominal.get("transition_policy") == &"static"
			and not bool(nominal.get("flashing", true)),
			"%s nominal stage uses two static real-muzzle emitters within its bounded fallback budget" % craft_name
		)
		_check(
			_emitters_align_to_muzzles(craft, nominal)
			and craft.find_children("*", "ShipComponentDamage", true, false).size() == 1,
			"%s presentation stays at authoritative muzzle anchors with one component ledger" % craft_name
		)

		var shots: Array[Vector3] = []
		craft.projectile_fired.connect(
			func(origin: Vector3, _direction: Vector3) -> void: shots.append(origin)
		)
		craft.call("_fire_weapon")
		_check(shots.size() == 1, "%s nominal component state preserves existing fire dispatch" % craft_name)

		_fail_weapon_component(craft)
		craft.call("_sync_weapon_component_presentation")
		craft.set("_weapon_timer", 0.0)
		craft.call("_fire_weapon")
		var failed := craft.get_weapon_component_emitter_snapshot()
		_check(
			failed.get("stage") == &"failed"
			and int(failed.get("visible_emitter_count", -1)) == 0
			and is_zero_approx(float(failed.get("geometry_multiplier", 1.0)))
			and craft.get_weapon_fire_status().get("reason") == &"weapon_component_failed"
			and shots.size() == 1
			and not bool(failed.get("fire_authority", true)),
			"%s failed wing blanks both charge silhouettes while existing fire authority blocks the shot" % craft_name
		)

		_repair_weapon_components_to(craft, 0.32)
		craft.call("_sync_weapon_component_presentation")
		craft.set("_weapon_timer", 0.0)
		craft.call("_fire_weapon")
		var critical := craft.get_weapon_component_emitter_snapshot()
		_check(
			critical.get("stage") == &"critical"
			and int(critical.get("visible_emitter_count", -1)) == 1
			and _first_emitter_extent(critical) < nominal_extent
			and _first_overlay_color(critical).is_equal_approx(Color("ff5944"))
			and shots.size() == 2,
			"%s critical stage leaves one short red-orange charge point while impaired firing still works" % craft_name
		)

		_repair_weapon_components_to(craft, 0.55)
		craft.call("_sync_weapon_component_presentation")
		var degraded := craft.get_weapon_component_emitter_snapshot()
		_check(
			degraded.get("stage") == &"degraded"
			and int(degraded.get("visible_emitter_count", -1)) == 2
			and _first_emitter_extent(degraded) > _first_emitter_extent(critical)
			and _first_emitter_extent(degraded) < nominal_extent
			and _first_overlay_color(degraded).is_equal_approx(Color("ffd166")),
			"%s degraded stage keeps two shortened amber charge points" % craft_name
		)

		_repair_weapon_components_to(craft, 1.0)
		craft.call("_sync_weapon_component_presentation")
		var repaired := craft.get_weapon_component_emitter_snapshot()
		_check(
			repaired.get("stage") == &"nominal"
			and int(repaired.get("visible_emitter_count", -1)) == 2
			and is_equal_approx(_first_emitter_extent(repaired), nominal_extent)
			and _overlay_colors(repaired) == nominal_overlays,
			"%s authorized repair restores authored scale, visibility, and material state" % craft_name
		)
		retained_ids[craft_name] = _emitter_ids(repaired)

	root.remove_child(game)
	await process_frame
	root.add_child(game)
	await process_frame
	for craft_name: String in CRAFTS:
		var craft := game.get_node(craft_name) as HeroShip
		craft.call("_sync_weapon_component_presentation")
		var reentered := craft.get_weapon_component_emitter_snapshot()
		_check(
			_emitter_ids(reentered) == retained_ids[craft_name]
			and int(reentered.get("visible_emitter_count", -1)) == 2,
			"%s whole-Main detach/re-entry retains the same emitter nodes without duplication" % craft_name
		)

	for craft_name: String in CRAFTS:
		var craft := game.get_node(craft_name) as HeroShip
		_fail_weapon_component(craft)
		craft.call("_sync_weapon_component_presentation")
		var reset := craft.reset_for_reuse(craft.global_transform)
		var restored := craft.get_weapon_component_emitter_snapshot()
		_check(
			bool(reset.get("accepted", false))
			and restored.get("stage") == &"nominal"
			and int(restored.get("visible_emitter_count", -1)) == 2
			and _emitter_ids(restored) == retained_ids[craft_name],
			"%s respawn/reuse restores nominal output on the same bounded presentation nodes" % craft_name
		)

	game.queue_free()
	await process_frame
	_finish()


func _fail_weapon_component(craft: HeroShip) -> void:
	var model := craft.get_component_damage()
	var component_id := ShipComponentDamageType.COMPONENT_PORT_WING
	var position := _component_local_position(craft, component_id)
	var guard := 0
	while model.get_component_state(component_id) < ShipComponentDamageType.ComponentState.FAILED \
			and guard < 4:
		model.record_damage(craft.maximum_hull * 2.0, position)
		guard += 1


func _repair_weapon_components_to(craft: HeroShip, target_integrity: float) -> void:
	var model := craft.get_component_damage()
	for component_id in [
		ShipComponentDamageType.COMPONENT_PORT_WING,
		ShipComponentDamageType.COMPONENT_STARBOARD_WING,
	]:
		var before := model.get_component_integrity(component_id)
		if before >= target_integrity:
			continue
		var delta := (target_integrity - before) / maxf(model.repair_rate_per_second, 0.001)
		model.tick_component_repair(component_id, maxf(delta, 0.001), true)


func _component_local_position(craft: HeroShip, component_id: StringName) -> Vector3:
	for component in craft.get_component_damage_report().get("components", []) as Array:
		if StringName((component as Dictionary).get("id", &"")) == component_id:
			return (component as Dictionary).get("local_position", Vector3.ZERO) as Vector3
	return Vector3.ZERO


func _emitters_align_to_muzzles(craft: HeroShip, snapshot: Dictionary) -> bool:
	var expected := [
		(craft.get("_muzzle_left") as Marker3D).global_position,
		(craft.get("_muzzle_right") as Marker3D).global_position,
	]
	for record in snapshot.get("emitters", []) as Array:
		var position := (record as Dictionary).get("global_position", Vector3.INF) as Vector3
		var aligned := false
		for muzzle_position: Vector3 in expected:
			if position.distance_to(muzzle_position) <= 0.05:
				aligned = true
				break
		if not aligned:
			return false
	return true


func _emitter_ids(snapshot: Dictionary) -> Array[int]:
	var ids: Array[int] = []
	for record in snapshot.get("emitters", []) as Array:
		ids.append(int((record as Dictionary).get("instance_id", 0)))
	return ids


func _first_emitter_extent(snapshot: Dictionary) -> float:
	var emitters := snapshot.get("emitters", []) as Array
	if emitters.is_empty():
		return 0.0
	return ((emitters[0] as Dictionary).get("scale", Vector3.ZERO) as Vector3).length()


func _overlay_colors(snapshot: Dictionary) -> Array[Color]:
	var colors: Array[Color] = []
	for record in snapshot.get("emitters", []) as Array:
		colors.append((record as Dictionary).get("overlay_color", Color.TRANSPARENT) as Color)
	return colors


func _first_overlay_color(snapshot: Dictionary) -> Color:
	var colors := _overlay_colors(snapshot)
	return colors[0] if not colors.is_empty() else Color.TRANSPARENT


func _check(condition: bool, message: String) -> void:
	_assertions += 1
	if condition:
		print("PASS: %s" % message)
	else:
		_failures.append(message)
		push_error("FAIL: %s" % message)


func _finish() -> void:
	if _failures.is_empty():
		print("HERO_WEAPON_EMITTER_COMPONENT_DAMAGE_TEST_OK (%d assertions)" % _assertions)
		quit(0)
		return
	print("HERO_WEAPON_EMITTER_COMPONENT_DAMAGE_TEST_FAILED: %s" % "; ".join(_failures))
	quit(1)
