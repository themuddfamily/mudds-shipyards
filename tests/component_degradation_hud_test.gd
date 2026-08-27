extends SceneTree

const ShipComponentDamageType := preload("res://scripts/combat/ship_component_damage.gd")

var _assertions := 0
var _failures: PackedStringArray = []


class ComponentReportSource:
	extends Node

	signal component_damage_changed(component_id: StringName, state: int, integrity: float)
	signal component_repair_progressed(progress: Dictionary)

	var report: Dictionary = {}


	func get_component_damage_report() -> Dictionary:
		return report.duplicate(true)


	func publish(next_report: Dictionary) -> void:
		report = next_report.duplicate(true)
		component_damage_changed.emit(&"engine_bay", 0, 1.0)


	func publish_repair(progress: Dictionary, next_report: Dictionary = {}) -> void:
		if not next_report.is_empty():
			report = next_report.duplicate(true)
		component_repair_progressed.emit(progress.duplicate(true))


class LifecycleReportSource:
	extends Node

	signal component_damage_changed(component_id: StringName, state: int, integrity: float)
	signal destroyed(world_position: Vector3, inherited_velocity: Vector3)

	var report: Dictionary = {}
	var telemetry: Dictionary = {"destroyed": false}
	var recovery: Dictionary = {}


	func get_component_damage_report() -> Dictionary:
		return report.duplicate(true)


	func get_telemetry() -> Dictionary:
		return telemetry.duplicate(true)


	func get_component_recovery_report() -> Dictionary:
		return recovery.duplicate(true)


	func publish(
		next_telemetry: Dictionary,
		next_recovery: Dictionary,
		next_report: Dictionary = {}
	) -> void:
		telemetry = next_telemetry.duplicate(true)
		recovery = next_recovery.duplicate(true)
		if not next_report.is_empty():
			report = next_report.duplicate(true)
		component_damage_changed.emit(&"forward_hull", 0, 1.0)


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
		and degraded.get("component_stage") == &"impaired"
		and not degraded.has("authoritative_stage")
		and degraded.get("wording") == &"degraded"
		and degraded.get("text") == label.text,
		"a real component signal publishes section, integrity, and explicit DEGRADED wording"
	)

	_damage_component_to(torrent, ShipComponentDamageType.COMPONENT_ENGINE_BAY, 0.35)
	var critical := hud.get_hero_component_hud_snapshot()
	_check(
		label.text.begins_with("[!] DAMAGE  //  ENGINE BAY")
		and label.text.contains("CRITICAL")
		and critical.get("component_stage") == &"impaired"
		and critical.get("wording") == &"critical"
		and critical.get("text") == label.text,
		"authoritative impaired integrity below forty percent gains explicit non-color CRITICAL wording"
	)

	var repair := torrent.get_component_damage().tick_component_repair(
		ShipComponentDamageType.COMPONENT_ENGINE_BAY, 0.10, true
	)
	var repair_snapshot := hud.get_hero_component_hud_snapshot()
	_check(
		bool(repair.get("accepted", false))
		and label.text.begins_with("[+] RECOVERY  //  ENGINE BAY")
		and label.text.contains("REPAIRING")
		and repair_snapshot.get("text") == label.text,
		"authorized recovery leads with a steady non-color repair mark and names its component"
	)

	_damage_component_to(torrent, ShipComponentDamageType.COMPONENT_ENGINE_BAY, 0.20)
	var failed := hud.get_hero_component_hud_snapshot()
	_check(
		label.text.begins_with("[X] FAILURE  //  ENGINE BAY")
		and label.text.contains("FAILED")
		and failed.get("component_stage") == &"failed"
		and failed.get("wording") == &"failed"
		and bool(failed.get("presentation_only", false))
		and not bool(failed.get("authority", true))
		and failed.get("text") == label.text,
		"failed component wording remains an explicitly authority-free HUD presentation"
	)

	var torrent_reset := torrent.reset_for_reuse(torrent.global_transform)
	_check(
		bool(torrent_reset.get("accepted", false))
		and bool(torrent.get_component_recovery_report().get("valid", false))
		and label.text == "[+] RESPAWN READY  //  RECOVERY VERIFIED",
		"reset component signals publish only complete audited recovery readiness"
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
	var accepted_revision := int(accepted_report.get("revision", -1))
	_check(
		hud.bind_hero_component_ship(report_source)
		and label.text.begins_with("[!] DAMAGE  //  ENGINE BAY"),
		"the production HUD accepts the current authoritative component generation"
	)
	var accepted_text := label.text
	var stale_report := arrow.get_component_damage_report()
	stale_report["ledger_generation"] = 12
	stale_report["revision"] = accepted_revision - 1
	report_source.publish(stale_report)
	_check(
		label.text == accepted_text,
		"an older revision in the accepted generation cannot repaint the component line"
	)
	stale_report["revision"] = accepted_revision
	report_source.publish(stale_report)
	_check(
		label.text == accepted_text,
		"divergent payload at an equal generation and revision replays the accepted snapshot"
	)
	var replacement_report := arrow.get_component_damage_report()
	replacement_report["ledger_generation"] = 12
	replacement_report["revision"] = accepted_revision + 1
	report_source.publish(replacement_report)
	_check(
		label.text == "COMPONENT  //  FORWARD HULL  100%  //  NOMINAL",
		"a newer same-generation report revision replaces the prior damage cue"
	)

	var repair_base := accepted_report.duplicate(true)
	repair_base["ledger_generation"] = 13
	repair_base["revision"] = accepted_revision + 2
	report_source.publish(repair_base)
	var repair_base_text := label.text
	var stale_progress := _repair_progress_for(repair_base, accepted_revision + 2)
	report_source.publish_repair(stale_progress)
	_check(
		label.text == repair_base_text and not label.text.contains("RECOVERY"),
		"same-generation repair progress cannot replay an already accepted revision"
	)
	var future_progress := _repair_progress_for(repair_base, accepted_revision + 3)
	future_progress["generation"] = 14
	report_source.publish_repair(future_progress)
	_check(
		label.text == repair_base_text,
		"an unpaired future-generation repair receipt fails closed"
	)
	var mismatched_progress := _repair_progress_for(repair_base, accepted_revision + 3)
	report_source.publish_repair(mismatched_progress)
	_check(
		label.text == repair_base_text,
		"repair progress cannot advance without an exactly matching live report revision"
	)
	var paired_repair_report := repair_base.duplicate(true)
	paired_repair_report["revision"] = accepted_revision + 3
	_set_component_state(
		paired_repair_report,
		ShipComponentDamageType.COMPONENT_ENGINE_BAY,
		0.60,
		&"impaired"
	)
	var component_mismatch_progress := _repair_progress_for(
		repair_base, accepted_revision + 3
	)
	report_source.publish_repair(component_mismatch_progress, paired_repair_report)
	_check(
		label.text == repair_base_text,
		"matching chronology still rejects repair component data that disagrees with its report"
	)
	var paired_progress := _repair_progress_for(paired_repair_report, accepted_revision + 3)
	report_source.publish_repair(paired_progress, paired_repair_report)
	_check(
		label.text.begins_with("[+] RECOVERY  //  ENGINE BAY")
		and hud.get_hero_component_hud_snapshot().get("text") == label.text,
		"only matching report and progress chronology publishes steady recovery semantics"
	)

	game.remove_child(report_source)
	_check(
		not label.visible
		and label.text.is_empty()
		and hud.get_hero_component_hud_snapshot().is_empty(),
		"observed actor loss clears both rendered and inspectable component state"
	)
	report_source.free()
	_check(
		hud.bind_hero_component_ship(arrow)
		and label.text == "COMPONENT  //  FORWARD HULL  100%  //  NOMINAL",
		"switching after actor loss starts a fresh report chronology"
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

	# Lifecycle presentation is a pure projection of current public facts. The
	# fake source makes a nominal roster disagree with an invalid complete audit,
	# then changes only the current snapshots to prove no destroyed latch survives.
	var lifecycle_source := LifecycleReportSource.new()
	game.add_child(lifecycle_source)
	var lifecycle_report := arrow.get_component_damage_report()
	lifecycle_report["ledger_generation"] = 2
	lifecycle_report["revision"] = int(lifecycle_report.get("revision", 0)) + 20
	lifecycle_source.report = lifecycle_report.duplicate(true)
	var invalid_recovery := _recovery_audit(2, false)
	lifecycle_source.recovery = invalid_recovery.duplicate(true)
	_check(
		hud.bind_hero_component_ship(lifecycle_source)
		and label.text == "[!] RECOVERY PENDING  //  AUDIT NOT READY"
		and hud.get_hero_component_hud_snapshot().get("wording") == &"recovery_pending",
		"a nominal roster cannot upgrade an invalid complete recovery audit to readiness"
	)
	lifecycle_source.publish({"destroyed": true}, invalid_recovery)
	_check(
		label.text == "[X] DESTROYED  //  HULL LOST"
		and not label.text.contains("BERTH")
		and hud.get_hero_component_hud_snapshot().get("wording") == &"destroyed",
		"destroyed telemetry reports hull loss without inventing berth recovery"
	)
	lifecycle_source.publish({"destroyed": false}, invalid_recovery)
	_check(
		label.text == "[!] RECOVERY PENDING  //  AUDIT NOT READY",
		"clearing current destroyed telemetry leaves no HUD-owned destroyed lifecycle memory"
	)
	var valid_recovery := _recovery_audit(2, true)
	lifecycle_source.publish({"destroyed": false}, valid_recovery)
	var verified_snapshot := hud.get_hero_component_hud_snapshot()
	_check(
		label.text == "[+] RESPAWN READY  //  RECOVERY VERIFIED"
		and verified_snapshot.get("wording") == &"respawn_ready"
		and not verified_snapshot.has("authoritative_stage"),
		"only the complete current recovery audit publishes readiness"
	)
	game.remove_child(lifecycle_source)
	lifecycle_source.free()

	# The retained flight row also exercises the production Arrow's current
	# telemetry, reset transaction, and detached recovery audit.
	hud.bind_hero_component_ship(arrow)
	arrow.apply_damage(999.0, arrow.global_position, Vector3.UP, -1, false)
	await process_frame
	var destroyed_snapshot := hud.get_hero_component_hud_snapshot()
	_check(
		label.visible
		and label.text == "[X] DESTROYED  //  HULL LOST"
		and destroyed_snapshot.get("wording") == &"destroyed"
		and not destroyed_snapshot.has("authoritative_stage")
		and bool(destroyed_snapshot.get("presentation_only", false))
		and not bool(destroyed_snapshot.get("authority", true)),
		"a real destroyed ship publishes a persistent non-color destruction marker"
	)
	var respawn := arrow.reset_for_reuse(arrow.global_transform)
	await process_frame
	var recovery := arrow.get_component_recovery_report()
	var respawn_snapshot := hud.get_hero_component_hud_snapshot()
	_check(
		bool(respawn.get("accepted", false))
		and bool(recovery.get("valid", false))
		and label.text == "[+] RESPAWN READY  //  RECOVERY VERIFIED"
		and respawn_snapshot.get("wording") == &"respawn_ready"
		and not respawn_snapshot.has("authoritative_stage"),
		"the actual post-reuse audit reports verified readiness with distinct text and shape"
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


func _set_component_state(
	report: Dictionary,
	component_id: StringName,
	integrity: float,
	state_id: StringName
	) -> void:
	for raw_component in report.get("components", []) as Array:
		if not raw_component is Dictionary:
			continue
		var component := raw_component as Dictionary
		if StringName(component.get("id", &"")) == component_id:
			component["integrity"] = integrity
			component["state_id"] = state_id
			return


func _repair_progress_for(report: Dictionary, revision: int) -> Dictionary:
	for raw_component in report.get("components", []) as Array:
		if not raw_component is Dictionary:
			continue
		var component := raw_component as Dictionary
		if StringName(component.get("id", &"")) == ShipComponentDamageType.COMPONENT_ENGINE_BAY:
			return {
				"generation": int(report.get("ledger_generation", 0)),
				"revision": revision,
				"component_count": 1,
				"components": [{
					"component_id": ShipComponentDamageType.COMPONENT_ENGINE_BAY,
					"integrity": float(component.get("integrity", 0.0)),
					"state_id": StringName(component.get("state_id", &"")),
				}],
			}
	return {}


func _recovery_audit(generation: int, valid: bool) -> Dictionary:
	var errors := PackedStringArray() if valid else PackedStringArray(["presentation_residue"])
	return {
		"valid": valid,
		"errors": errors,
		"scope": &"hero_ship_component_recovery",
		"model_generation": generation,
		"presentation_generation": generation,
		"component_sequence": -1,
		"pending_presentations": 0,
		"presentation": {
			"valid": valid,
			"errors": errors.duplicate(),
			"scope": &"hero_damage_component_recovery",
			"presentation_generation": generation,
			"pending_presentations": 0,
			"localized_component_effects": 0,
			"component_repair_cues": 0,
			"impact_effects": 0,
			"debris": 0,
		},
	}.duplicate(true)


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
