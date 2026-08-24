extends SceneTree

const Presenter := preload("res://scripts/ui/network_session_status_presenter.gd")
const HudType := preload("res://scripts/ui/hud.gd")

var _assertions := 0
var _failures: PackedStringArray = []


func _init() -> void:
	call_deferred(&"_run")


func _run() -> void:
	var presenter := Presenter.new()
	var started := presenter.present_snapshot(_session_snapshot(1, 10, [
		_repair_respawn(&"halyard_new_design", &"started", 0.0, 1, 1, 7, 3),
		_repair_respawn(&"jovian_provisional", &"progress", 0.4, 1, 2, 8, 4),
		_repair_respawn(&"bulwark_heavy_gunship", &"completed", 1.0, 2, 3, 9, 5),
	]))
	_check(
		started.repair_rows.size() == 3
		and started.repair_rows.has(
			"HALYARD_NEW_DESIGN // ENGINE_BAY // STARTED // 0% // ENGINEER REMOTE PEER 7"
		)
		and started.repair_rows.has(
			"JOVIAN_PROVISIONAL // ENGINE_BAY // IN PROGRESS // 40% // ENGINEER REMOTE PEER 8"
		)
		and started.repair_rows.has(
			"BULWARK_HEAVY_GUNSHIP // ENGINE_BAY // COMPLETED // 100% // ENGINEER REMOTE PEER 9"
		),
		"one canonical multi-craft snapshot presents started, progress, and completed remote engineer repairs"
	)
	var reordered := presenter.present_snapshot(_session_snapshot(2, 11, [
		_repair_respawn(&"halyard_new_design", &"progress", 0.6, 1, 2, 7, 3),
		_repair_respawn(&"jovian_provisional", &"started", 0.0, 1, 1, 8, 4),
		_repair_respawn(&"bulwark_heavy_gunship", &"progress", 0.8, 1, 4, 9, 5),
	]))
	_check(
		_repair_lifecycle(reordered, &"halyard_new_design").state == &"progress"
		and is_equal_approx(
			float(_repair_lifecycle(reordered, &"halyard_new_design").progress), 0.6
		)
		and _repair_lifecycle(reordered, &"jovian_provisional").state == &"progress"
		and is_equal_approx(
			float(_repair_lifecycle(reordered, &"jovian_provisional").progress), 0.4
		)
		and _repair_lifecycle(reordered, &"bulwark_heavy_gunship").state == &"completed",
		"each craft accepts its own newer sequence while stale nested generations or sequences retain the last presentation"
	)
	var terminal := presenter.present_snapshot(_session_snapshot(3, 12, [
		_repair_respawn(&"halyard_new_design", &"completed", 1.0, 1, 3, 7, 3),
		_repair_respawn(&"jovian_provisional", &"aborted", 0.4, 1, 3, 8, 4),
		_repair_respawn(&"bulwark_heavy_gunship", &"completed", 1.0, 1, 3, 9, 5),
	]))
	_check(
		_repair_lifecycle(terminal, &"halyard_new_design").state == &"completed"
		and _repair_lifecycle(terminal, &"jovian_provisional").state == &"aborted"
		and bool(_repair_lifecycle(terminal, &"jovian_provisional").terminal),
		"completed and aborted canonical tombstones remain explicit"
	)
	var stale_source := presenter.present_snapshot(_session_snapshot(2, 13, [
		_repair_respawn(&"jovian_provisional", &"completed", 1.0, 2, 1, 8, 4),
	]))
	_check(
		_repair_lifecycle(stale_source, &"jovian_provisional").state == &"aborted"
		and stale_source.repair_rows.size() == 3,
		"a stale retained-session generation cannot replace or remove repair presentation"
	)
	var hud := HudType.new()
	root.add_child(hud)
	await process_frame
	hud.update_network_session_status(_session_snapshot(1, 20, [
		_repair_respawn(&"halyard_new_design", &"started", 0.0, 1, 1, 7, 3),
		_repair_respawn(&"jovian_provisional", &"aborted", 0.4, 1, 3, 8, 4),
	]))
	var detail := (hud.get("_runtime_status_detail") as Label).text
	_check(
		detail.contains(
			"REPAIR // HALYARD_NEW_DESIGN // ENGINE_BAY // STARTED // 0% // ENGINEER REMOTE PEER 7"
		)
		and detail.contains(
			"REPAIR // JOVIAN_PROVISIONAL // ENGINE_BAY // ABORTED // 40% // ENGINEER REMOTE PEER 8"
		),
		"the retained HUD consumer renders the canonical remote repair lifecycle as readable text"
	)
	hud.update_network_session_status({
		"generation": 2,
		"state": &"disconnected",
		"local_role": &"observer",
		"detail": "Disconnected.",
	})
	detail = (hud.get("_runtime_status_detail") as Label).text
	var detached_presenter: RefCounted = hud.get("_network_status_presenter") as RefCounted
	var detached: Dictionary = detached_presenter.call("get_snapshot") as Dictionary
	_check(
		not detail.contains("REPAIR //")
		and (detached.get("repair_rows", []) as Array).is_empty()
		and (detached.get("repair_lifecycles", []) as Array).is_empty(),
		"disconnect teardown clears all retained repair rows and cursors"
	)
	hud.update_network_session_status(_session_snapshot(3, 1, [
		_repair_respawn(&"jovian_provisional", &"started", 0.0, 1, 1, 8, 6),
	]))
	var rejoined_presenter: RefCounted = hud.get("_network_status_presenter") as RefCounted
	var rejoined: Dictionary = rejoined_presenter.call("get_snapshot") as Dictionary
	_check(
		_repair_lifecycle(rejoined, &"jovian_provisional").state == &"started"
		and int(_repair_lifecycle(rejoined, &"jovian_provisional").repair_sequence) == 1,
		"a new session after teardown starts with a fresh per-craft repair cursor"
	)
	_check(
		bool(rejoined.get("presentation_only", false))
		and not rejoined.has("repair_authority")
		and not _repair_lifecycle(rejoined, &"jovian_provisional").has("receipt_token"),
		"repair status exposes no repair token or mutation authority"
	)
	hud.queue_free()
	await process_frame
	if _failures.is_empty():
		print("NETWORK_SESSION_REPAIR_HUD_TEST_OK (%d assertions)" % _assertions)
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)


func _session_snapshot(generation: int, revision: int, respawn: Array) -> Dictionary:
	return {
		"generation": generation,
		"state": &"connected",
		"local_role": &"observer",
		"local_peer_id": 2,
		"detail": "Session ready.",
		"authoritative_snapshot": {
			"authority_peer_id": 1,
			"revision": revision,
			"sections": {
				&"ownership": [],
				&"boarding": [],
				&"respawn": respawn,
			},
		},
	}


func _repair_respawn(
	craft_id: StringName,
	state: StringName,
	progress: float,
	repair_generation: int,
	repair_sequence: int,
	owner_peer_id: int,
	owner_peer_generation: int
) -> Dictionary:
	return {
		"entity_id": craft_id,
		"entity_generation": 1,
		"component_generation": 4,
		"state": &"damaged",
		"repair": {
			"repair_generation": repair_generation,
			"repair_sequence": repair_sequence,
			"component_id": &"engine_bay",
			"component_generation": 4,
			"owner_peer_id": owner_peer_id,
			"owner_peer_generation": owner_peer_generation,
			"progress": progress,
			"state": state,
			"terminal": state in [&"completed", &"aborted"],
		},
	}


func _repair_lifecycle(snapshot: Dictionary, craft_id: StringName) -> Dictionary:
	for lifecycle_variant in snapshot.get("repair_lifecycles", []) as Array:
		var lifecycle := lifecycle_variant as Dictionary
		if StringName(lifecycle.get("craft_id", &"")) == craft_id:
			return lifecycle
	return {}


func _check(condition: bool, description: String) -> void:
	_assertions += 1
	if not condition:
		_failures.append("FAIL: " + description)
