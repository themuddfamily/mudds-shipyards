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
	_check(game != null, "production Main instantiates for static hull-frame grading")
	if game == null:
		_finish()
		return
	root.add_child(game)
	await process_frame
	await physics_frame
	var hud := game.get_node("HUD") as GameHUD
	hud.set_mode("piloting")
	hud.set_reduced_flash(true)
	var retained_panel_id := 0
	var retained_flash_id := 0
	var retained_panel_offsets := Vector4.ZERO

	for craft_name: String in CRAFTS:
		var craft := game.get_node(craft_name) as HeroShip
		craft.set_physics_process(false)
		hud.bind_hero_component_ship(craft)
		hud.update_ship_telemetry(craft.get_telemetry())
		var healthy := hud.get_hull_frame_damage_snapshot()
		if retained_panel_id == 0:
			retained_panel_id = int(healthy.get("telemetry_panel_instance_id", 0))
			retained_flash_id = int(healthy.get("damage_flash_instance_id", 0))
			retained_panel_offsets = healthy.get("panel_offsets", Vector4.ZERO) as Vector4
		_check(
			healthy.get("stage") == &"healthy"
			and int(healthy.get("horizontal_border_width", -1)) == 1
			and int(healthy.get("vertical_border_width", -1)) == 1
			and int(healthy.get("corner_radius", -1)) == 8
			and int(healthy.get("telemetry_panel_instance_id", 0)) == retained_panel_id,
			"%s healthy hull uses the retained thin rounded telemetry frame" % craft_name
		)

		_damage_hull_to(craft, 0.60)
		var reticle_before := hud.get_sensor_reticle_component_snapshot()
		hud.update_ship_telemetry(craft.get_telemetry())
		var damaged := hud.get_hull_frame_damage_snapshot()
		_check(
			damaged.get("stage") == &"damaged"
			and int(damaged.get("horizontal_border_width", -1)) == 3
			and int(damaged.get("vertical_border_width", -1)) == 3
			and int(damaged.get("corner_radius", -1)) == 4
			and (damaged.get("panel_offsets", Vector4.ZERO) as Vector4).is_equal_approx(
				retained_panel_offsets
			)
			and (damaged.get("content_margins", Vector4.ZERO) as Vector4).is_equal_approx(
				Vector4.ONE
			),
			"%s damaged hull thickens and tightens the existing frame without moving controls" % craft_name
		)
		_check(
			_reticle_ids(reticle_before) == _reticle_ids(
				(damaged.get("reticle_snapshot", {}) as Dictionary)
			)
			and reticle_before.get("stage") == (
				damaged.get("reticle_snapshot", {}) as Dictionary
			).get("stage"),
			"%s hull telemetry does not rebuild or overwrite component-reticle presentation" % craft_name
		)

		_damage_hull_to(craft, 0.25)
		reticle_before = hud.get_sensor_reticle_component_snapshot()
		hud.update_ship_telemetry(craft.get_telemetry())
		var critical := hud.get_hull_frame_damage_snapshot()
		_check(
			critical.get("stage") == &"critical"
			and int(critical.get("horizontal_border_width", -1)) == 6
			and int(critical.get("vertical_border_width", -1)) == 2
			and int(critical.get("corner_radius", -1)) == 0
			and bool(critical.get("reduced_flash_safe", false))
			and not bool(critical.get("flashing", true)),
			"%s critical hull becomes hard asymmetric rails with no flash or motion" % craft_name
		)
		_check(
			int(critical.get("frame_node_count", -1)) == 1
			and int(critical.get("added_nodes", -1)) == 0
			and not bool(critical.get("changes_panel_bounds", true))
			and not bool(critical.get("changes_content_margins", true))
			and int(critical.get("damage_flash_instance_id", 0)) == retained_flash_id
			and _reticle_ids(reticle_before) == _reticle_ids(
				(critical.get("reticle_snapshot", {}) as Dictionary)
			),
			"%s static hull rails reuse one frame and leave flash, content, and reticle ownership intact" % craft_name
		)

		var reset := craft.reset_for_reuse(craft.global_transform)
		hud.update_ship_telemetry(craft.get_telemetry())
		var regenerated := hud.get_hull_frame_damage_snapshot()
		_check(
			bool(reset.get("accepted", false))
			and regenerated.get("stage") == &"healthy"
			and int(regenerated.get("horizontal_border_width", -1)) == 1
			and int(regenerated.get("corner_radius", -1)) == 8
			and int(regenerated.get("telemetry_panel_instance_id", 0)) == retained_panel_id,
			"%s respawn/regeneration restores the healthy geometry on the same frame" % craft_name
		)

	var halyard := game.get_node("HalyardCrewTransport") as HeroShip
	_damage_hull_to(halyard, 0.25)
	hud.bind_hero_component_ship(halyard)
	hud.update_ship_telemetry(halyard.get_telemetry())
	var critical_hull := float(halyard.get_telemetry().get("hull", -1.0))
	var destroyed_telemetry := halyard.get_telemetry()
	destroyed_telemetry["hull"] = 0.0
	destroyed_telemetry["damage_status"] = &"destroyed"
	hud.update_ship_telemetry(destroyed_telemetry)
	var destroyed := hud.get_hull_frame_damage_snapshot()
	_check(
		destroyed.get("stage") == &"destroyed"
		and int(destroyed.get("horizontal_border_width", -1)) == 0
		and int(destroyed.get("vertical_border_width", -1)) == 0
		and is_equal_approx(float(halyard.get_telemetry().get("hull", -2.0)), critical_hull)
		and not bool(destroyed.get("authority", true)),
		"terminal telemetry removes the frame silhouette without mutating authoritative hull"
	)
	# Restore the actual live observation before exercising retained-tree lifecycle.
	hud.update_ship_telemetry(halyard.get_telemetry())
	root.remove_child(game)
	await process_frame
	var detached := hud.get_hull_frame_damage_snapshot()
	_check(
		detached.get("stage") == &"healthy"
		and int(detached.get("telemetry_panel_instance_id", 0)) == retained_panel_id,
		"whole-Main detach clears the hull grade without rebuilding the retained frame"
	)
	root.add_child(game)
	await process_frame
	await physics_frame
	hud.update_ship_telemetry(halyard.get_telemetry())
	var reentered := hud.get_hull_frame_damage_snapshot()
	_check(
		reentered.get("stage") == &"critical"
		and int(reentered.get("telemetry_panel_instance_id", 0)) == retained_panel_id
		and (reentered.get("panel_offsets", Vector4.ZERO) as Vector4).is_equal_approx(
			retained_panel_offsets
		),
		"whole-Main re-entry restores the live hull grade on the same unmoved frame"
	)

	hud.set_mode("on-foot")
	var disembarked := hud.get_hull_frame_damage_snapshot()
	_check(
		disembarked.get("stage") == &"healthy"
		and not (hud.get("_telemetry_panel") as PanelContainer).visible
		and int(disembarked.get("telemetry_panel_instance_id", 0)) == retained_panel_id,
		"disembark hides the panel and clears its retained hull grade"
	)

	game.queue_free()
	await process_frame
	_finish()


func _damage_hull_to(craft: HeroShip, target_ratio: float) -> void:
	var telemetry := craft.get_telemetry()
	var maximum_hull := float(telemetry.get("maximum_hull", 1.0))
	var current_hull := float(telemetry.get("hull", maximum_hull))
	var target_hull := maximum_hull * target_ratio
	if current_hull <= target_hull:
		return
	var local_position := _component_local_position(
		craft, ShipComponentDamageType.COMPONENT_FORWARD_HULL
	)
	craft.apply_damage(
		current_hull - target_hull,
		craft.to_global(local_position),
		Vector3.FORWARD,
		-1,
		false
	)


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
		print("HERO_HULL_FRAME_DAMAGE_PRESENTATION_TEST_OK (%d assertions)" % _assertions)
		quit(0)
		return
	print("HERO_HULL_FRAME_DAMAGE_PRESENTATION_TEST_FAILED: %s" % "; ".join(_failures))
	quit(1)
