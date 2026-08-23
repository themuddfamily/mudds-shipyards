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
	_check(game != null, "production Main instantiates for component-graded weapon heat HUD")
	if game == null:
		_finish()
		return
	root.add_child(game)
	await process_frame
	await physics_frame
	var hud := game.get_node("HUD") as GameHUD
	hud.set_mode("piloting")
	hud.set_reduced_flash(true)
	var retained_label_id := 0
	var retained_reticle_ids: Array[int] = []
	var retained_hull_frame_id := 0

	for craft_name: String in CRAFTS:
		var craft := game.get_node(craft_name) as HeroShip
		craft.set_physics_process(false)
		craft.set("_landed", false)
		craft.set("_engine_state", HeroShip.ENGINE_ONLINE)
		craft.set("_weapon_heat", 0.50)
		craft.set("_weapon_timer", 0.0)
		craft.set("_weapon_overheated", false)
		_check(hud.bind_hero_component_ship(craft), "%s binds to the retained component HUD" % craft_name)
		hud.update_ship_telemetry(craft.get_telemetry())
		var nominal := hud.get_weapon_heat_component_hud_snapshot()
		var hull_before := hud.get_hull_frame_damage_snapshot()
		var reticle_before := hud.get_sensor_reticle_component_snapshot()
		if retained_label_id == 0:
			retained_label_id = int(nominal.get("label_instance_id", 0))
			retained_reticle_ids = _reticle_ids(reticle_before)
			retained_hull_frame_id = int(hull_before.get("telemetry_panel_instance_id", 0))
		_check(
			nominal.get("stage") == &"nominal"
			and nominal.get("pips") == "[##..]"
			and nominal.get("readiness") == "READY"
			and (nominal.get("label_text", "") as String).contains(
				"WEAPON READY / HEAT  //  [##..]  READY  050%"
			)
			and is_equal_approx(float(craft.get_telemetry().get("weapon_heat", -1.0)), 0.50),
			"%s nominal weapons show four heat slots without consuming authoritative heat" % craft_name
		)

		_damage_weapon_to(craft, 0.58)
		var degraded := hud.get_weapon_heat_component_hud_snapshot()
		_check(
			degraded.get("stage") == &"degraded"
			and degraded.get("pips") == "[## ..]"
			and int(degraded.get("label_instance_id", 0)) == retained_label_id
			and is_equal_approx(float(craft.get_telemetry().get("weapon_power", -1.0)), 0.62),
			"%s degraded wing splits the four-slot heat silhouette while fire authority remains impaired" % craft_name
		)

		_damage_weapon_to(craft, 0.35)
		var critical := hud.get_weapon_heat_component_hud_snapshot()
		_check(
			critical.get("stage") == &"critical"
			and critical.get("pips") == "[#  .]"
			and critical.get("geometry_policy") == &"static"
			and not bool(critical.get("flashing", true))
			and bool(critical.get("reduced_flash_safe", false)),
			"%s critical wing leaves two separated static heat slots without flashing" % craft_name
		)

		_damage_weapon_to(craft, 0.20)
		hud.update_ship_telemetry(craft.get_telemetry())
		var failed := hud.get_weapon_heat_component_hud_snapshot()
		_check(
			failed.get("stage") == &"failed"
			and failed.get("pips") == "[XXXX]"
			and failed.get("readiness") == "UNAVAILABLE"
			and craft.get_weapon_fire_status().get("reason") == &"weapon_component_failed"
			and not bool(failed.get("authority", true)),
			"%s failed wing replaces heat slots with a blocked silhouette while existing fire authority denies" % craft_name
		)
		var hull_after_component := hud.get_hull_frame_damage_snapshot()
		var reticle_after_component := hud.get_sensor_reticle_component_snapshot()
		_check(
			int(failed.get("added_nodes", -1)) == 0
			and int(hull_after_component.get("telemetry_panel_instance_id", 0)) == retained_hull_frame_id
			and _reticle_ids(reticle_after_component) == retained_reticle_ids
			and not (hud.get("_damage_status_label") as Label).get_global_rect().intersects(
				(hud.get("_reticle") as Control).get_global_rect()
			),
			"%s reuses one bottom telemetry label without rebuilding or overlapping reticle/frame nodes" % craft_name
		)

		_repair_weapon_to(craft, 0.55)
		hud.update_ship_telemetry(craft.get_telemetry())
		var repaired_degraded := hud.get_weapon_heat_component_hud_snapshot()
		_check(
			repaired_degraded.get("stage") == &"degraded"
			and repaired_degraded.get("pips") == "[## ..]",
			"%s authorized component repair immediately restores the degraded pip geometry" % craft_name
		)

		_repair_weapon_to(craft, 1.0)
		hud.update_ship_telemetry(craft.get_telemetry())
		var repaired := hud.get_weapon_heat_component_hud_snapshot()
		_check(
			repaired.get("stage") == &"nominal"
			and repaired.get("pips") == "[##..]"
			and int(repaired.get("label_instance_id", 0)) == retained_label_id,
			"%s full repair restores four nominal slots on the same retained label" % craft_name
		)

		var reset := craft.reset_for_reuse(craft.global_transform)
		hud.update_ship_telemetry(craft.get_telemetry())
		var reset_snapshot := hud.get_weapon_heat_component_hud_snapshot()
		_check(
			bool(reset.get("accepted", false))
			and reset_snapshot.get("stage") == &"nominal"
			and reset_snapshot.get("pips") == "[....]"
			and is_zero_approx(float(reset_snapshot.get("heat", -1.0)))
			and int(reset_snapshot.get("label_instance_id", 0)) == retained_label_id,
			"%s respawn/reuse clears heat and restores nominal geometry without replacing HUD nodes" % craft_name
		)

	var halyard := game.get_node("HalyardCrewTransport") as HeroShip
	_damage_weapon_to(halyard, 0.35)
	hud.bind_hero_component_ship(halyard)
	hud.update_ship_telemetry(halyard.get_telemetry())
	root.remove_child(game)
	await process_frame
	var detached := hud.get_weapon_heat_component_hud_snapshot()
	_check(
		detached.get("stage") == &"nominal"
		and int(detached.get("label_instance_id", 0)) == retained_label_id,
		"whole-Main detach clears the component pip grade on the retained label"
	)
	root.add_child(game)
	await process_frame
	await process_frame
	hud.update_ship_telemetry(halyard.get_telemetry())
	var reentered := hud.get_weapon_heat_component_hud_snapshot()
	_check(
		reentered.get("stage") == &"critical"
		and reentered.get("pips") == "[.  .]"
		and int(reentered.get("label_instance_id", 0)) == retained_label_id,
		"whole-Main re-entry restores the live wing grade on the same heat readout"
	)

	hud.set_mode("on-foot")
	var disembarked := hud.get_weapon_heat_component_hud_snapshot()
	_check(
		disembarked.get("stage") == &"nominal"
		and not (hud.get("_telemetry_panel") as PanelContainer).visible
		and int(disembarked.get("label_instance_id", 0)) == retained_label_id,
		"disembark hides telemetry and clears the retained weapon-component grade"
	)

	game.queue_free()
	await process_frame
	_finish()


func _damage_weapon_to(craft: HeroShip, target_integrity: float) -> void:
	var guard := 0
	while _component_integrity(craft, ShipComponentDamageType.COMPONENT_PORT_WING) \
			> target_integrity and guard < 48:
		var local_position := _component_local_position(
			craft, ShipComponentDamageType.COMPONENT_PORT_WING
		)
		craft.apply_damage(2.0, craft.to_global(local_position), Vector3.UP, -1, false)
		guard += 1


func _repair_weapon_to(craft: HeroShip, target_integrity: float) -> void:
	var model := craft.get_component_damage()
	for component_id in [
		ShipComponentDamageType.COMPONENT_PORT_WING,
		ShipComponentDamageType.COMPONENT_STARBOARD_WING,
	]:
		var before := model.get_component_integrity(component_id)
		if before >= target_integrity:
			continue
		model.tick_component_repair(
			component_id,
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
		print("HERO_WEAPON_COMPONENT_HEAT_HUD_TEST_OK (%d assertions)" % _assertions)
		quit(0)
		return
	print("HERO_WEAPON_COMPONENT_HEAT_HUD_TEST_FAILED: %s" % "; ".join(_failures))
	quit(1)
