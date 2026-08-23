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
	_check(game != null, "production Main instantiates for component-graded throttle geometry")
	if game == null:
		_finish()
		return
	root.add_child(game)
	await process_frame
	await physics_frame
	var hud := game.get_node("HUD") as GameHUD
	(hud.get("_hud") as Control).visible = true
	hud.set_mode("piloting")
	hud.set_reduced_flash(true)
	await process_frame
	var retained_bar_id := 0
	var retained_minimum_size := Vector2.ZERO
	var retained_reticle_ids: Array[int] = []
	var retained_weapon_label_id := 0
	var retained_hull_frame_id := 0

	for craft_name: String in CRAFTS:
		var craft := game.get_node(craft_name) as HeroShip
		craft.set_physics_process(false)
		craft.set("_landed", false)
		craft.set("_engine_state", HeroShip.ENGINE_ONLINE)
		craft.set("_throttle", 0.80)
		_check(hud.bind_hero_component_ship(craft), "%s binds to the retained component HUD" % craft_name)
		hud.update_ship_telemetry(craft.get_telemetry())
		var nominal := hud.get_engine_throttle_component_hud_snapshot()
		if retained_bar_id == 0:
			retained_bar_id = int(nominal.get("bar_instance_id", 0))
			retained_minimum_size = nominal.get("custom_minimum_size", Vector2.ZERO) as Vector2
			retained_reticle_ids = _reticle_ids(
				nominal.get("reticle_snapshot", {}) as Dictionary
			)
			retained_weapon_label_id = int((
				nominal.get("weapon_snapshot", {}) as Dictionary
			).get("label_instance_id", 0))
			retained_hull_frame_id = int((
				nominal.get("hull_frame_snapshot", {}) as Dictionary
			).get("telemetry_panel_instance_id", 0))
		_check(
			nominal.get("stage") == &"nominal"
			and is_equal_approx(float(nominal.get("geometry_scale_y", 0.0)), 1.0)
			and int(nominal.get("corner_radius", -1)) == 3
			and is_equal_approx(float(nominal.get("bar_value", -1.0)), 80.0)
			and int(nominal.get("bar_instance_id", 0)) == retained_bar_id,
			"%s nominal engine keeps the full rounded 80%% throttle bar" % craft_name
		)

		_damage_engine_to(craft, 0.58)
		hud.update_ship_telemetry(craft.get_telemetry())
		var degraded := hud.get_engine_throttle_component_hud_snapshot()
		_check(
			degraded.get("stage") == &"degraded"
			and is_equal_approx(float(degraded.get("geometry_scale_y", 0.0)), 0.75)
			and int(degraded.get("corner_radius", -1)) == 2
			and is_equal_approx(float(degraded.get("bar_value", -1.0)), 80.0)
			and is_equal_approx(float(craft.get_telemetry().get("engine_power", -1.0)), 0.62),
			"%s degraded engine shortens bar height while HeroShip retains impaired mobility authority" % craft_name
		)

		_damage_engine_to(craft, 0.35)
		hud.update_ship_telemetry(craft.get_telemetry())
		var critical := hud.get_engine_throttle_component_hud_snapshot()
		_check(
			critical.get("stage") == &"critical"
			and is_equal_approx(float(critical.get("geometry_scale_y", 0.0)), 0.45)
			and int(critical.get("corner_radius", -1)) == 0
			and not bool(critical.get("flashing", true))
			and bool(critical.get("reduced_flash_safe", false)),
			"%s critical engine becomes a thin square static bar without flashing" % craft_name
		)

		_damage_engine_to(craft, 0.20)
		hud.update_ship_telemetry(craft.get_telemetry())
		var failed := hud.get_engine_throttle_component_hud_snapshot()
		_check(
			failed.get("stage") == &"failed"
			and is_equal_approx(float(failed.get("geometry_scale_y", 0.0)), 0.12)
			and is_equal_approx(float(failed.get("bar_value", -1.0)), 80.0)
			and is_equal_approx(float(craft.get_telemetry().get("throttle", -1.0)), 0.80)
			and is_zero_approx(float(craft.get_telemetry().get("engine_power", 1.0)))
			and not bool(failed.get("authority", true)),
			"%s failed engine collapses to a rail without rewriting throttle or thrust authority" % craft_name
		)
		_check(
			int(failed.get("bar_node_count", -1)) == 1
			and int(failed.get("added_nodes", -1)) == 0
			and not bool(failed.get("changes_layout_box", true))
			and (failed.get("custom_minimum_size", Vector2.ZERO) as Vector2).is_equal_approx(
				retained_minimum_size
			)
			and _reticle_ids(failed.get("reticle_snapshot", {}) as Dictionary) == retained_reticle_ids
			and int((failed.get("weapon_snapshot", {}) as Dictionary).get("label_instance_id", 0)) \
				== retained_weapon_label_id
			and int((failed.get("hull_frame_snapshot", {}) as Dictionary).get(
				"telemetry_panel_instance_id", 0
			)) == retained_hull_frame_id,
			"%s reuses one layout-stable bar without replacing sensor, weapon, or hull cues" % craft_name
		)
		await process_frame
		failed = hud.get_engine_throttle_component_hud_snapshot()
		_check(
			not ((failed.get("bar_rect", Rect2()) as Rect2).intersects(
				(hud.get("_reticle") as Control).get_global_rect()
			))
			and not ((failed.get("bar_rect", Rect2()) as Rect2).intersects(
				(hud.get("_damage_status_label") as Label).get_global_rect()
			)),
			"%s throttle geometry remains in its authored row without overlapping center or weapon heat" % craft_name
		)

		_repair_engine_to(craft, 0.55)
		var repaired_degraded := hud.get_engine_throttle_component_hud_snapshot()
		_check(
			repaired_degraded.get("stage") == &"degraded"
			and is_equal_approx(float(repaired_degraded.get("geometry_scale_y", 0.0)), 0.75),
			"%s authorized repair immediately restores degraded throttle geometry" % craft_name
		)

		_repair_engine_to(craft, 1.0)
		var repaired := hud.get_engine_throttle_component_hud_snapshot()
		_check(
			repaired.get("stage") == &"nominal"
			and is_equal_approx(float(repaired.get("geometry_scale_y", 0.0)), 1.0)
			and int(repaired.get("bar_instance_id", 0)) == retained_bar_id,
			"%s full repair restores the full-height bar on the same retained node" % craft_name
		)

		var reset := craft.reset_for_reuse(craft.global_transform)
		hud.update_ship_telemetry(craft.get_telemetry())
		var reset_snapshot := hud.get_engine_throttle_component_hud_snapshot()
		_check(
			bool(reset.get("accepted", false))
			and reset_snapshot.get("stage") == &"nominal"
			and is_equal_approx(float(reset_snapshot.get("bar_value", -1.0)), 0.0)
			and is_equal_approx(float(reset_snapshot.get("geometry_scale_y", 0.0)), 1.0)
			and int(reset_snapshot.get("bar_instance_id", 0)) == retained_bar_id,
			"%s respawn/reuse resets throttle and geometry without replacing the HUD bar" % craft_name
		)

	var halyard := game.get_node("HalyardCrewTransport") as HeroShip
	_damage_engine_to(halyard, 0.35)
	hud.bind_hero_component_ship(halyard)
	root.remove_child(game)
	await process_frame
	var detached := hud.get_engine_throttle_component_hud_snapshot()
	_check(
		detached.get("stage") == &"nominal"
		and int(detached.get("bar_instance_id", 0)) == retained_bar_id,
		"whole-Main detach clears the engine grade on the retained throttle bar"
	)
	root.add_child(game)
	await process_frame
	await process_frame
	var reentered := hud.get_engine_throttle_component_hud_snapshot()
	_check(
		reentered.get("stage") == &"critical"
		and is_equal_approx(float(reentered.get("geometry_scale_y", 0.0)), 0.45)
		and int(reentered.get("bar_instance_id", 0)) == retained_bar_id,
		"whole-Main re-entry restores the live engine grade on the same throttle bar"
	)

	hud.set_mode("on-foot")
	var disembarked := hud.get_engine_throttle_component_hud_snapshot()
	_check(
		disembarked.get("stage") == &"nominal"
		and not (hud.get("_telemetry_panel") as PanelContainer).visible
		and int(disembarked.get("bar_instance_id", 0)) == retained_bar_id,
		"disembark hides telemetry and clears the retained engine-component grade"
	)

	game.queue_free()
	await process_frame
	_finish()


func _damage_engine_to(craft: HeroShip, target_integrity: float) -> void:
	var guard := 0
	while _component_integrity(craft, ShipComponentDamageType.COMPONENT_ENGINE_BAY) \
			> target_integrity and guard < 48:
		var local_position := _component_local_position(
			craft, ShipComponentDamageType.COMPONENT_ENGINE_BAY
		)
		craft.apply_damage(2.0, craft.to_global(local_position), Vector3.UP, -1, false)
		guard += 1


func _repair_engine_to(craft: HeroShip, target_integrity: float) -> void:
	var model := craft.get_component_damage()
	var before := model.get_component_integrity(ShipComponentDamageType.COMPONENT_ENGINE_BAY)
	if before >= target_integrity:
		return
	model.tick_component_repair(
		ShipComponentDamageType.COMPONENT_ENGINE_BAY,
		(target_integrity - before) / maxf(model.repair_rate_per_second, 0.001),
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


func _reticle_ids(snapshot: Dictionary) -> Array[int]:
	var ids: Array[int] = []
	for mark in snapshot.get("marks", []) as Array:
		ids.append(int((mark as Dictionary).get("instance_id", 0)))
	return ids


func _check(condition: bool, message: String) -> void:
	_assertions += 1
	if condition:
		print("PASS: %s" % message)
	else:
		_failures.append(message)
		push_error("FAIL: %s" % message)


func _finish() -> void:
	if _failures.is_empty():
		print("HERO_ENGINE_THROTTLE_COMPONENT_HUD_TEST_OK (%d assertions)" % _assertions)
		quit(0)
		return
	print("HERO_ENGINE_THROTTLE_COMPONENT_HUD_TEST_FAILED: %s" % "; ".join(_failures))
	quit(1)
