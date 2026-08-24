extends SceneTree

const HudType := preload("res://scripts/ui/hud.gd")

var _assertions := 0
var _failures: PackedStringArray = []


func _init() -> void:
	call_deferred(&"_run")


func _run() -> void:
	var hud := HudType.new()
	root.add_child(hud)
	await process_frame
	hud.update_loadmaster_telemetry({
		"role": "loadmaster",
		"occupant": "Rhea",
		"manifest_state": "blocked",
		"route": "JOVIAN-BERTH-03",
		"readiness_receipt": "manifest sealed // berth clearance pending",
		"history": ["manifest checked", "cargo receipt ready", "reward receipt pending", "old receipt", "ignored overflow"],
	})
	var panel := hud.get("_runtime_status_panel") as Control
	var detail := hud.get("_runtime_status_detail") as Label
	var actions := hud.get("_runtime_status_actions") as HBoxContainer
	_check(panel.visible, "loadmaster status is visible in the production HUD")
	_check(detail.text.contains("ROLE // LOADMASTER") and detail.text.contains("OCCUPANT // Rhea"), "role and occupant are readable")
	_check(detail.text.contains("MANIFEST // BLOCKED") and detail.text.contains("ROUTE // JOVIAN-BERTH-03"), "manifest and route state are explicit")
	_check(detail.text.contains("READINESS // manifest sealed // berth clearance pending"), "readiness receipt is text-first")
	_check(detail.text.contains("MANIFEST CHECKED") and detail.text.contains("OLD RECEIPT") and not detail.text.contains("IGNORED OVERFLOW"), "receipt history is bounded")
	_check(detail.text.contains("NO INVENTORY TRANSFER") and detail.text.contains("NO REWARD AUTHORITY") and detail.text.contains("NO HELM AUTHORITY"), "authority boundaries are explicit")
	_check(actions.get_child_count() == 1 and (actions.get_child(0) as Button).focus_mode == Control.FOCUS_ALL, "loadmaster review is controller and keyboard focusable")
	hud.update_cinder_loadmaster_telemetry(
		&"cinder_cargo_hauler", &"loadmaster",
		{"state": "manifest_ready", "manifest_id": "cinder_manifest", "route_id": "dock_04_cargo", "generation": 4},
		{"station_id": &"cinder_loadmaster_station", "manifest_generation": 4, "receipt": {"ready": true, "route_id": &"dock_04_cargo", "manifest_generation": 4, "request_sequence": 40}}
	)
	_check(detail.text.contains("CRAFT // CINDER_CARGO_HAULER") and detail.text.contains("SEAT MANIFEST_READY"), "Cinder craft and detached seat state are explicit")
	_check(detail.text.contains("GENERATION // 4  //  REVISION // 40") and detail.text.contains("ROUTE // dock_04_cargo"), "Cinder manifest route and exact receipt cursor are readable")
	_check(detail.text.contains("READINESS STATE // [READY]") and detail.text.contains("NEXT ACTION // CREW REVIEW // CONFIRM ROUTE dock_04_cargo"), "readiness and next action remain explicit without relying on colour")
	var ready_text := detail.text
	hud.update_cinder_loadmaster_telemetry(
		&"cinder_cargo_hauler", &"loadmaster",
		{"state": "occupied", "manifest_id": "stale_manifest", "route_id": "stale_route", "generation": 4},
		{"manifest_generation": 4, "receipt": {"ready": false, "route_id": &"stale_route", "manifest_generation": 4, "request_sequence": 39}}
	)
	_check(detail.text == ready_text, "an older revision in the current generation cannot repaint readiness")
	hud.update_cinder_loadmaster_telemetry(
		&"cinder_cargo_hauler", &"loadmaster",
		{"state": "occupied", "manifest_id": "mismatched_manifest", "route_id": "wrong_generation", "generation": 5},
		{"manifest_generation": 5, "receipt": {"ready": false, "route_id": &"wrong_generation", "manifest_generation": 4, "request_sequence": 41}}
	)
	_check(detail.text == ready_text, "a receipt from a different generation cannot repaint readiness")
	hud.update_cinder_loadmaster_telemetry(
		&"cinder_cargo_hauler", &"loadmaster",
		{"state": "occupied", "manifest_id": "cinder_manifest", "route_id": "dock_04_cargo", "generation": 4},
		{"manifest_generation": 4, "receipt": {"ready": false, "route_id": &"dock_04_cargo", "manifest_generation": 4, "request_sequence": 41}}
	)
	_check(detail.text.contains("READINESS STATE // [ACTION REQUIRED]") and detail.text.contains("NEXT ACTION // RESOLVE MANIFEST BLOCKERS // ROUTE dock_04_cargo"), "a newer authoritative revision publishes a concrete blocked next action")
	hud.update_cinder_loadmaster_telemetry(&"cinder_cargo_hauler", &"loadmaster", {"state": "released", "generation": 5}, {"manifest_generation": 5, "receipt": {}})
	_check(detail.text.contains("SEAT RELEASED") and detail.text.contains("GENERATION // 5"), "Cinder release/re-entry state remains readable")
	var released_text := detail.text
	hud.update_cinder_loadmaster_telemetry(
		&"cinder_cargo_hauler", &"loadmaster",
		{"state": "manifest_ready", "route_id": "retired_route", "generation": 4},
		{"manifest_generation": 4, "receipt": {"ready": true, "route_id": &"retired_route", "manifest_generation": 4, "request_sequence": 99}}
	)
	_check(detail.text == released_text, "a retired generation cannot repaint after release")
	hud.clear_loadmaster_telemetry()
	_check(not panel.visible, "loadmaster status clears on detach")
	hud.update_loadmaster_telemetry({
		"craft_id": &"halyard_crew_transport",
		"role": &"loadmaster",
		"state": &"manifest_ready",
		"manifest_id": &"halyard_manifest",
		"route_id": &"fleet_dock_03",
		"generation": 1,
		"manifest_generation": 1,
		"manifest_receipt": {"ready": true, "route_id": &"fleet_dock_03", "manifest_generation": 1, "request_sequence": 1},
	})
	_check(panel.visible and detail.text.contains("CRAFT // HALYARD_CREW_TRANSPORT") and detail.text.contains("GENERATION // 1  //  REVISION // 1"), "detach clears receipt fencing for lower-generation Halyard reuse")
	hud.update_cinder_loadmaster_telemetry(
		&"cinder_cargo_hauler", &"loadmaster",
		{"state": "manifest_ready", "route_id": "dock_02_cargo", "generation": 1},
		{"manifest_generation": 1, "receipt": {"ready": true, "route_id": &"dock_02_cargo", "manifest_generation": 1, "request_sequence": 1}}
	)
	_check(detail.text.contains("CRAFT // CINDER_CARGO_HAULER") and not detail.text.contains("HALYARD_CREW_TRANSPORT"), "craft reuse clears the prior craft cursor and presentation")
	hud.queue_free()
	await process_frame
	if _failures.is_empty():
		print("LOADMASTER_TELEMETRY_HUD_TEST_OK (%d assertions)" % _assertions)
		quit(0)
		return
	for failure in _failures:
		push_error("FAIL: " + failure)
	quit(1)


func _check(condition: bool, message: String) -> void:
	_assertions += 1
	if not condition:
		_failures.append(message)
