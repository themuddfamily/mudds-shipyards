extends SceneTree

const ShipComponentDamageType := preload("res://scripts/combat/ship_component_damage.gd")

var _assertions := 0
var _failures: PackedStringArray = []


func _init() -> void:
	call_deferred(&"_run")


func _run() -> void:
	var packed := load("res://scenes/main.tscn") as PackedScene
	var game := packed.instantiate() as GameFlow if packed != null else null
	_check(game != null, "production Main instantiates for repair HUD progress coverage")
	if game == null:
		_finish()
		return
	root.add_child(game)
	await process_frame
	await physics_frame
	var hud := game.get_node("HUD") as GameHUD
	var torrent := game.get_node("TorrentInterceptor") as HeroShip
	var arrow := game.get_node("ArrowReconShip") as HeroShip
	var label := hud.get("_component_status_label") as Label
	for ship_name in [
		"TorrentInterceptor",
		"ArrowReconShip",
		"JovianLightFreighter",
		"ZenithInterceptor",
		"HalyardCrewTransport",
	]:
		var ship := game.get_node(ship_name) as HeroShip
		ship.set_physics_process(false)
		_check(
			ship.get_component_damage().get_signal_connection_list(
				&"component_repair_committed"
			).size() == 1,
			"%s republishes exactly one shared repair-progress connection" % ship_name
		)

	hud.set_mode("piloting")
	_check(hud.bind_hero_component_ship(torrent), "the real flight HUD binds the retained craft")
	_damage_component_to(torrent, ShipComponentDamageType.COMPONENT_ENGINE_BAY, 0.35)
	var damaged_integrity := _component_integrity(
		torrent, ShipComponentDamageType.COMPONENT_ENGINE_BAY
	)
	_check(
		label.text.contains("ENGINE BAY") and label.text.contains("CRITICAL"),
		"ordinary damage wording remains visible before repair starts"
	)

	var berth_first := torrent.get_component_damage().tick_repair(0.10, true)
	var berth_snapshot := hud.get_hero_component_hud_snapshot()
	var first_integrity := float(berth_snapshot.get("integrity", -1.0))
	_check(
		bool(berth_first.get("accepted", false))
		and label.text.contains("ENGINE BAY")
		and label.text.contains("REPAIRING")
		and first_integrity > damaged_integrity,
		"an authorized passive berth commit immediately shows REPAIRING and rising integrity"
	)

	var engineer_second := torrent.get_component_damage().tick_component_repair(
		ShipComponentDamageType.COMPONENT_ENGINE_BAY, 0.10, true
	)
	var second_snapshot := hud.get_hero_component_hud_snapshot()
	var second_integrity := float(second_snapshot.get("integrity", -1.0))
	_check(
		bool(engineer_second.get("accepted", false))
		and second_integrity > first_integrity
		and int(second_snapshot.get("percentage", -1)) > int(berth_snapshot.get("percentage", -1))
		and second_snapshot.get("wording") == &"repairing"
		and second_snapshot.get("authoritative_stage") == berth_snapshot.get("authoritative_stage"),
		"targeted engineer commits advance the displayed percentage without requiring a stage crossing"
	)

	root.remove_child(game)
	await process_frame
	_check(not label.visible and label.text.is_empty(), "whole-Main detach clears in-progress repair text")
	root.add_child(game)
	await process_frame
	await process_frame
	_check(
		label.visible
		and label.text.contains("ENGINE BAY")
		and label.text.contains("REPAIRING")
		and int(hud.get_hero_component_hud_snapshot().get("percentage", -1))
		== int(second_snapshot.get("percentage", -2)),
		"whole-Main re-entry restores the retained repair progress without another mutation"
	)

	_check(
		hud.bind_hero_component_ship(arrow)
		and label.text == "COMPONENT  //  FORWARD HULL  100%  //  NOMINAL",
		"craft switching clears the previous craft's repair status"
	)
	torrent.get_component_damage().tick_component_repair(
		ShipComponentDamageType.COMPONENT_ENGINE_BAY, 0.10, true
	)
	_check(
		label.text == "COMPONENT  //  FORWARD HULL  100%  //  NOMINAL",
		"repair commits from the previously bound craft cannot overwrite the switched HUD"
	)

	hud.bind_hero_component_ship(torrent)
	var guard := 0
	while _component_integrity(torrent, ShipComponentDamageType.COMPONENT_ENGINE_BAY) < 1.0 and guard < 32:
		torrent.get_component_damage().tick_component_repair(
			ShipComponentDamageType.COMPONENT_ENGINE_BAY, 0.25, true
		)
		guard += 1
	_check(
		is_equal_approx(
			_component_integrity(torrent, ShipComponentDamageType.COMPONENT_ENGINE_BAY), 1.0
		)
		and not label.text.contains("REPAIRING")
		and not bool(hud.get_hero_component_hud_snapshot().get("repairing", true)),
		"the explicit repair state clears at nominal integrity and returns to damage wording"
	)

	_damage_component_to(torrent, ShipComponentDamageType.COMPONENT_ENGINE_BAY, 0.58)
	torrent.get_component_damage().tick_component_repair(
		ShipComponentDamageType.COMPONENT_ENGINE_BAY, 0.10, true
	)
	var reset := torrent.reset_for_reuse(torrent.global_transform)
	_check(
		bool(reset.get("accepted", false))
		and label.text == "COMPONENT  //  FORWARD HULL  100%  //  NOMINAL",
		"respawn/reuse clears repair status and restores the authoritative nominal report"
	)

	hud.set_mode("on-foot")
	hud.clear_hero_component_ship()
	_check(
		not label.visible
		and label.text.is_empty()
		and hud.get_hero_component_hud_snapshot().is_empty(),
		"disembark clears repair progress and disconnects the retained craft"
	)

	game.queue_free()
	await process_frame
	_finish()


func _damage_component_to(ship: HeroShip, component_id: StringName, target_integrity: float) -> void:
	var guard := 0
	while _component_integrity(ship, component_id) > target_integrity and guard < 32:
		ship.apply_damage(
			2.0,
			ship.to_global(_component_local_position(ship, component_id)),
			Vector3.UP,
			-1,
			false
		)
		guard += 1


func _component_integrity(ship: HeroShip, component_id: StringName) -> float:
	for component in ship.get_component_damage_report().get("components", []) as Array:
		if StringName((component as Dictionary).get("id", &"")) == component_id:
			return float((component as Dictionary).get("integrity", -1.0))
	return -1.0


func _component_local_position(ship: HeroShip, component_id: StringName) -> Vector3:
	for component in ship.get_component_damage_report().get("components", []) as Array:
		if StringName((component as Dictionary).get("id", &"")) == component_id:
			return (component as Dictionary).get("local_position", Vector3.ZERO) as Vector3
	return Vector3.ZERO


func _check(condition: bool, message: String) -> void:
	_assertions += 1
	if condition:
		print("PASS: %s" % message)
	else:
		_failures.append(message)
		push_error("FAIL: %s" % message)


func _finish() -> void:
	if _failures.is_empty():
		print("COMPONENT_REPAIR_HUD_PROGRESS_TEST_OK (%d assertions)" % _assertions)
		quit(0)
		return
	print("COMPONENT_REPAIR_HUD_PROGRESS_TEST_FAILED: %s" % "; ".join(_failures))
	quit(1)
