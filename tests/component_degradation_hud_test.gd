extends SceneTree

const ShipComponentDamageType := preload("res://scripts/combat/ship_component_damage.gd")

var _assertions := 0
var _failures: PackedStringArray = []


class ComponentReportSource:
	extends Node

	signal component_damage_changed(component_id: StringName, state: int, integrity: float)

	var report: Dictionary = {}


	func get_component_damage_report() -> Dictionary:
		return report.duplicate(true)


	func publish(next_report: Dictionary) -> void:
		report = next_report.duplicate(true)
		component_damage_changed.emit(&"engine_bay", 0, 1.0)


func _init() -> void:
	call_deferred(&"_run")


func _run() -> void:
	var packed := load("res://scenes/main.tscn") as PackedScene
	var game := packed.instantiate() as GameFlow if packed != null else null
	_check(game != null, "production Main instantiates for retained component HUD coverage")
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
	hud.set_mode("piloting")
	_check(
		hud.bind_hero_component_ship(torrent)
		and label.visible
		and label.text == "COMPONENT  //  FORWARD HULL  100%  //  NOMINAL",
		"the real flight HUD binds the active craft and names its nominal worst section"
	)

	_damage_component_to(torrent, ShipComponentDamageType.COMPONENT_ENGINE_BAY, 0.58)
	var degraded := hud.get_hero_component_hud_snapshot()
	_check(
		label.visible
		and label.text.begins_with("[!] DAMAGE  //  ENGINE BAY")
		and label.text.contains("ENGINE BAY")
		and label.text.contains("DEGRADED")
		and label.text.contains("%")
		and degraded.get("authoritative_stage") == &"impaired"
		and degraded.get("wording") == &"degraded",
		"a real component signal publishes section, integrity, and explicit DEGRADED wording"
	)

	_damage_component_to(torrent, ShipComponentDamageType.COMPONENT_ENGINE_BAY, 0.35)
	var critical := hud.get_hero_component_hud_snapshot()
	_check(
		label.text.begins_with("[!] DAMAGE  //  ENGINE BAY")
		and label.text.contains("CRITICAL")
		and critical.get("authoritative_stage") == &"impaired"
		and critical.get("wording") == &"critical",
		"authoritative impaired integrity below forty percent gains explicit non-color CRITICAL wording"
	)

	var repair := torrent.get_component_damage().tick_component_repair(
		ShipComponentDamageType.COMPONENT_ENGINE_BAY, 0.10, true
	)
	_check(
		bool(repair.get("accepted", false))
		and label.text.begins_with("[+] RECOVERY  //  ENGINE BAY")
		and label.text.contains("REPAIRING"),
		"authorized recovery leads with a steady non-color repair mark and names its component"
	)

	_damage_component_to(torrent, ShipComponentDamageType.COMPONENT_ENGINE_BAY, 0.20)
	var failed := hud.get_hero_component_hud_snapshot()
	_check(
		label.text.begins_with("[X] FAILURE  //  ENGINE BAY")
		and label.text.contains("FAILED")
		and failed.get("authoritative_stage") == &"failed"
		and failed.get("wording") == &"failed"
		and bool(failed.get("presentation_only", false))
		and not bool(failed.get("authority", true)),
		"failed component wording remains an explicitly authority-free HUD presentation"
	)

	var torrent_reset := torrent.reset_for_reuse(torrent.global_transform)
	_check(
		bool(torrent_reset.get("accepted", false))
		and label.text == "COMPONENT  //  FORWARD HULL  100%  //  NOMINAL",
		"respawn component signals restore the compact HUD line to nominal"
	)

	_check(
		hud.bind_hero_component_ship(arrow)
		and label.text == "COMPONENT  //  FORWARD HULL  100%  //  NOMINAL",
		"craft switching atomically replaces the observed component snapshot"
	)
	_damage_component_to(torrent, ShipComponentDamageType.COMPONENT_ENGINE_BAY, 0.58)
	_check(
		label.text == "COMPONENT  //  FORWARD HULL  100%  //  NOMINAL",
		"damage signals from the previously observed craft cannot overwrite the switched HUD"
	)

	var report_source := ComponentReportSource.new()
	game.add_child(report_source)
	var accepted_report := torrent.get_component_damage_report()
	accepted_report["ledger_generation"] = 12
	report_source.report = accepted_report
	_check(
		hud.bind_hero_component_ship(report_source)
		and label.text.begins_with("[!] DAMAGE  //  ENGINE BAY"),
		"the production HUD accepts the current authoritative component generation"
	)
	var accepted_text := label.text
	var stale_report := arrow.get_component_damage_report()
	stale_report["ledger_generation"] = 11
	report_source.publish(stale_report)
	_check(
		label.text == accepted_text,
		"a stale ledger generation cannot repaint the retained component line"
	)
	var replacement_report := arrow.get_component_damage_report()
	replacement_report["ledger_generation"] = 13
	report_source.publish(replacement_report)
	_check(
		label.text == "COMPONENT  //  FORWARD HULL  100%  //  NOMINAL",
		"a newer actor lifecycle generation atomically replaces the prior damage cue"
	)

	hud.set_mode("on-foot")
	hud.clear_hero_component_ship()
	_check(
		not label.visible
		and label.text.is_empty()
		and hud.get_hero_component_hud_snapshot().is_empty(),
		"disembark clears the component line and disconnects the retained craft"
	)

	hud.set_mode("piloting")
	hud.bind_hero_component_ship(arrow)
	root.remove_child(game)
	await process_frame
	_check(not label.visible and label.text.is_empty(), "whole-Main detach clears component presentation")
	root.add_child(game)
	await process_frame
	await process_frame
	_check(
		label.visible
		and label.text == "COMPONENT  //  FORWARD HULL  100%  //  NOMINAL",
		"whole-Main re-entry restores one retained active-craft component presentation"
	)

	game.queue_free()
	await process_frame
	_finish()


func _damage_component_to(ship: HeroShip, component_id: StringName, target_integrity: float) -> void:
	var guard := 0
	while _component_integrity(ship, component_id) > target_integrity and guard < 32:
		var local_position := _component_local_position(ship, component_id)
		ship.apply_damage(2.0, ship.to_global(local_position), Vector3.UP, -1, false)
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
		print("COMPONENT_DEGRADATION_HUD_TEST_OK (%d assertions)" % _assertions)
		quit(0)
		return
	print("COMPONENT_DEGRADATION_HUD_TEST_FAILED: %s" % "; ".join(_failures))
	quit(1)
