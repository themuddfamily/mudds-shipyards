extends SceneTree

const ShipComponentDamageType := preload("res://scripts/combat/ship_component_damage.gd")

const CRAFTS := [
	"TorrentInterceptor",
	"ArrowReconShip",
	"JovianLightFreighter",
	"ZenithInterceptor",
	"HalyardCrewTransport",
]

var _assertions := 0
var _failures: PackedStringArray = []


func _init() -> void:
	call_deferred(&"_run")


func _run() -> void:
	var packed := load("res://scenes/main.tscn") as PackedScene
	var game := packed.instantiate() as GameFlow if packed != null else null
	_check(game != null, "production Main instantiates for component-graded targeting reticle")
	if game == null:
		_finish()
		return
	root.add_child(game)
	await process_frame
	await physics_frame
	var hud := game.get_node("HUD") as GameHUD
	hud.set_mode("piloting")
	hud.set_reduced_flash(true)
	hud.set_target_lock_state(&"acquired", "RANGE DRONE")
	var retained_mark_ids: Array[int] = []

	for craft_name: String in CRAFTS:
		var craft := game.get_node(craft_name) as HeroShip
		craft.set_physics_process(false)
		_check(hud.bind_hero_component_ship(craft), "%s binds to the retained flight HUD" % craft_name)
		var nominal := hud.get_sensor_reticle_component_snapshot()
		if retained_mark_ids.is_empty():
			retained_mark_ids = _mark_ids(nominal)
		_check(
			nominal.get("stage") == &"nominal"
			and int(nominal.get("visible_mark_count", -1)) == 4
			and is_equal_approx(float(nominal.get("mark_length", 0.0)), 12.0)
			and _mark_ids(nominal) == retained_mark_ids
			and nominal.get("lock_text") == "[+]  LOCKED  RANGE DRONE",
			"%s nominal sensors retain the four full bars and existing acquired-lock copy" % craft_name
		)

		_damage_sensor_to(craft, 0.58)
		var degraded := hud.get_sensor_reticle_component_snapshot()
		_check(
			degraded.get("stage") == &"degraded"
			and int(degraded.get("visible_mark_count", -1)) == 4
			and is_equal_approx(float(degraded.get("mark_length", 0.0)), 8.0)
			and _all_visible_marks_have_length(degraded, 8.0)
			and is_equal_approx(float(craft.get_telemetry().get("targeting_power", -1.0)), 0.62),
			"%s degraded sensor visibly shortens all bars while HeroShip retains targeting authority" % craft_name
		)

		_damage_sensor_to(craft, 0.35)
		var critical := hud.get_sensor_reticle_component_snapshot()
		_check(
			critical.get("stage") == &"critical"
			and int(critical.get("visible_mark_count", -1)) == 2
			and is_equal_approx(float(critical.get("mark_length", 0.0)), 6.0)
			and _visible_mark_count(critical) == 2
			and critical.get("lock_state") == &"acquired",
			"%s critical sensor leaves two short axial bars without rewriting target-lock state" % craft_name
		)

		_damage_sensor_to(craft, 0.20)
		var failed := hud.get_sensor_reticle_component_snapshot()
		_check(
			failed.get("stage") == &"failed"
			and int(failed.get("visible_mark_count", -1)) == 0
			and _visible_mark_count(failed) == 0
			and is_zero_approx(float(craft.get_telemetry().get("targeting_power", 1.0)))
			and bool(failed.get("reduced_flash_safe", false))
			and not bool(failed.get("flashing", true))
			and not bool(failed.get("authority", true)),
			"%s failed sensor removes the bracket silhouette statically while existing sensing disables" % craft_name
		)

		_repair_sensor_to(craft, 0.55)
		var repairing := hud.get_sensor_reticle_component_snapshot()
		_check(
			repairing.get("stage") == &"degraded"
			and int(repairing.get("visible_mark_count", -1)) == 4
			and is_equal_approx(float(repairing.get("mark_length", 0.0)), 8.0),
			"%s authorized repair immediately restores the degraded four-bar silhouette" % craft_name
		)

		_repair_sensor_to(craft, 1.0)
		var repaired := hud.get_sensor_reticle_component_snapshot()
		_check(
			repaired.get("stage") == &"nominal"
			and int(repaired.get("visible_mark_count", -1)) == 4
			and _mark_ids(repaired) == retained_mark_ids,
			"%s full repair restores nominal geometry on the same four HUD nodes" % craft_name
		)

		_damage_sensor_to(craft, 0.20)
		var reset := craft.reset_for_reuse(craft.global_transform)
		var reset_snapshot := hud.get_sensor_reticle_component_snapshot()
		_check(
			bool(reset.get("accepted", false))
			and reset_snapshot.get("stage") == &"nominal"
			and int(reset_snapshot.get("visible_mark_count", -1)) == 4
			and _mark_ids(reset_snapshot) == retained_mark_ids,
			"%s respawn/reuse restores the nominal retained reticle" % craft_name
		)

	var halyard := game.get_node("HalyardCrewTransport") as HeroShip
	_damage_sensor_to(halyard, 0.58)
	var before_detach := hud.get_sensor_reticle_component_snapshot()
	root.remove_child(game)
	await process_frame
	var detached := hud.get_sensor_reticle_component_snapshot()
	_check(
		before_detach.get("stage") == &"degraded"
		and detached.get("stage") == &"nominal"
		and _mark_ids(detached) == retained_mark_ids,
		"whole-Main detach clears the bound damage grade without rebuilding reticle nodes"
	)
	root.add_child(game)
	await process_frame
	await process_frame
	var reentered := hud.get_sensor_reticle_component_snapshot()
	_check(
		reentered.get("stage") == &"degraded"
		and int(reentered.get("visible_mark_count", -1)) == 4
		and _mark_ids(reentered) == retained_mark_ids,
		"whole-Main re-entry restores the active craft sensor grade on the same bars"
	)

	hud.set_mode("on-foot")
	var disembarked := hud.get_sensor_reticle_component_snapshot()
	_check(
		disembarked.get("stage") == &"nominal"
		and not (hud.get("_reticle") as Control).visible
		and _mark_ids(disembarked) == retained_mark_ids,
		"disembark hides the reticle and clears its retained component grade"
	)

	game.queue_free()
	await process_frame
	_finish()


func _damage_sensor_to(craft: HeroShip, target_integrity: float) -> void:
	var guard := 0
	while _component_integrity(craft, ShipComponentDamageType.COMPONENT_CORE_SYSTEMS) \
			> target_integrity and guard < 48:
		var local_position := _component_local_position(
			craft, ShipComponentDamageType.COMPONENT_CORE_SYSTEMS
		)
		craft.apply_damage(2.0, craft.to_global(local_position), Vector3.UP, -1, false)
		guard += 1


func _repair_sensor_to(craft: HeroShip, target_integrity: float) -> void:
	var model := craft.get_component_damage()
	var before := model.get_component_integrity(ShipComponentDamageType.COMPONENT_CORE_SYSTEMS)
	if before >= target_integrity:
		return
	var delta := (target_integrity - before) / maxf(model.repair_rate_per_second, 0.001)
	model.tick_component_repair(
		ShipComponentDamageType.COMPONENT_CORE_SYSTEMS,
		maxf(delta, 0.001),
		true
	)


func _component_integrity(craft: HeroShip, component_id: StringName) -> float:
	for component in craft.get_component_damage_report().get("components", []) as Array:
		if StringName((component as Dictionary).get("id", &"")) == component_id:
			return float((component as Dictionary).get("integrity", -1.0))
	return -1.0


func _component_local_position(craft: HeroShip, component_id: StringName) -> Vector3:
	for component in craft.get_component_damage_report().get("components", []) as Array:
		if StringName((component as Dictionary).get("id", &"")) == component_id:
			return (component as Dictionary).get("local_position", Vector3.ZERO) as Vector3
	return Vector3.ZERO


func _mark_ids(snapshot: Dictionary) -> Array[int]:
	var ids: Array[int] = []
	for mark in snapshot.get("marks", []) as Array:
		ids.append(int((mark as Dictionary).get("instance_id", 0)))
	return ids


func _visible_mark_count(snapshot: Dictionary) -> int:
	var count := 0
	for mark in snapshot.get("marks", []) as Array:
		if bool((mark as Dictionary).get("visible", false)):
			count += 1
	return count


func _all_visible_marks_have_length(snapshot: Dictionary, expected: float) -> bool:
	for mark in snapshot.get("marks", []) as Array:
		var record := mark as Dictionary
		if not bool(record.get("visible", false)):
			continue
		var size := record.get("size", Vector2.ZERO) as Vector2
		if not (is_equal_approx(size.x, expected) or is_equal_approx(size.y, expected)):
			return false
	return true


func _check(condition: bool, message: String) -> void:
	_assertions += 1
	if condition:
		print("PASS: %s" % message)
	else:
		_failures.append(message)
		push_error("FAIL: %s" % message)


func _finish() -> void:
	if _failures.is_empty():
		print("HERO_SENSOR_RETICLE_COMPONENT_DAMAGE_TEST_OK (%d assertions)" % _assertions)
		quit(0)
		return
	print("HERO_SENSOR_RETICLE_COMPONENT_DAMAGE_TEST_FAILED: %s" % "; ".join(_failures))
	quit(1)
