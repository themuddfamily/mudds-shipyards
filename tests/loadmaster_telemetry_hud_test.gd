extends SceneTree

const HudType := preload("res://scripts/ui/hud.gd")
const HALYARD_SCENE := preload("res://scenes/ships/halyard_crew_transport.tscn")
const Authority := preload("res://scripts/ships/crew_seat_role_authority.gd")
const RoleProfile := preload("res://scripts/fleet/crew_role_gameplay_profile.gd")

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
		{"state": "manifest_ready", "manifest_id": "cinder_manifest", "route_id": "stale_status_route", "generation": 4},
		{"station_id": &"cinder_loadmaster_station", "manifest_generation": 4, "receipt": {"ready": true, "route_id": &"dock_04_cargo", "manifest_generation": 4, "request_sequence": 40}}
	)
	_check(detail.text.contains("CRAFT // CINDER_CARGO_HAULER") and detail.text.contains("SEAT MANIFEST_READY"), "Cinder craft and detached seat state are explicit")
	_check(detail.text.contains("GENERATION // 4  //  REVISION // 40") and detail.text.contains("ROUTE // dock_04_cargo") and not detail.text.contains("stale_status_route"), "Cinder uses the current receipt route when status publication has not refreshed yet")
	_check(detail.text.contains("READINESS STATE // [READY]") and detail.text.contains("NEXT ACTION // CREW REVIEW // CONFIRM ROUTE dock_04_cargo"), "readiness and next action remain explicit without relying on colour")
	_check(detail.text.contains("ROSTER STATE // [=] SECURED // MANIFEST READY"), "Cinder manifest readiness has an explicit secured shape and label")
	_check(detail.get_combined_minimum_size().x <= 350.0 and detail.size.x >= 350.0, "the roster label remains within the existing retained card width")
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
	_check(detail.text.contains("READINESS STATE // [ACTION REQUIRED]") and detail.text.contains("ROSTER STATE // [!] BLOCKED // MANIFEST REVIEW") and detail.text.contains("NEXT ACTION // RESOLVE MANIFEST BLOCKERS // ROUTE dock_04_cargo"), "a newer authoritative revision publishes a concrete blocked next action and shape")
	hud.update_cinder_loadmaster_telemetry(&"cinder_cargo_hauler", &"loadmaster", {"state": "released", "generation": 5}, {"manifest_generation": 5, "receipt": {}})
	_check(detail.text.contains("SEAT RELEASED") and detail.text.contains("ROSTER STATE // [/] DETACHED // STATION OPEN") and detail.text.contains("GENERATION // 5"), "Cinder release/re-entry state remains readable")
	var released_text := detail.text
	hud.update_cinder_loadmaster_telemetry(
		&"cinder_cargo_hauler", &"loadmaster",
		{"state": "manifest_ready", "route_id": "retired_route", "generation": 4},
		{"manifest_generation": 4, "receipt": {"ready": true, "route_id": &"retired_route", "manifest_generation": 4, "request_sequence": 99}}
	)
	_check(detail.text == released_text, "a retired generation cannot repaint after release")
	hud.clear_loadmaster_telemetry()
	_check(not panel.visible, "loadmaster status clears on detach")
	var craft := HALYARD_SCENE.instantiate() as HalyardCrewTransport
	root.add_child(craft)
	await process_frame
	await physics_frame
	await physics_frame
	var authority := Authority.new(1)
	_check(bool(authority.register_halyard_roster().get("accepted", false)), "the real Halyard roster seals for HUD receipt coverage")
	_check(bool(craft.attach_crew_role_authority(authority).get("accepted", false)), "the HUD test binds the real Halyard role authority")
	_check(
		bool(authority.claim(
			1, 81, &"hud_loadmaster", HalyardCrewTransport.LOADMASTER_STATION_SEAT_ID,
			Authority.ROLE_PASSENGER, 1
		).get("accepted", false)),
		"the HUD receipt originates at Halyard's physical loadmaster station"
	)
	var accepted := craft.submit_crew_intent(
		1,
		81,
		&"hud_loadmaster",
		RoleProfile.ACTION_PASSENGER_CARGO_MANIFEST,
		{"manifest_id": &"halyard_manifest", "route_id": &"fleet_dock_03", "ready": true},
		2
	)
	_check(bool(accepted.get("consumed", false)), "the HUD consumes only an authority-admitted Halyard manifest receipt")
	var halyard_snapshot := craft.get_loadmaster_manifest_snapshot()
	halyard_snapshot["craft_id"] = craft.get_ship_id()
	halyard_snapshot["role"] = &"loadmaster"
	hud.update_loadmaster_telemetry(halyard_snapshot)
	_check(
		panel.visible
			and detail.text.contains("CRAFT // %s" % str(craft.get_ship_id()).to_upper())
			and detail.text.contains("ROUTE // fleet_dock_03")
			and detail.text.contains("GENERATION // 1  //  REVISION // 2"),
		"the HUD consumes Halyard's real {manifest_generation, receipt} API shape"
	)
	_check(
		bool(authority.release(
			1, 81, &"hud_loadmaster", HalyardCrewTransport.LOADMASTER_STATION_SEAT_ID, 3
		).get("accepted", false)),
		"the Halyard loadmaster releases before pooled reuse"
	)
	await physics_frame
	var released_halyard_snapshot := craft.get_loadmaster_manifest_snapshot()
	released_halyard_snapshot["craft_id"] = craft.get_ship_id()
	released_halyard_snapshot["role"] = &"loadmaster"
	hud.update_loadmaster_telemetry(released_halyard_snapshot)
	_check(detail.text.contains("GENERATION // 2"), "the pre-reuse Halyard clear advances the HUD generation fence")
	_check(bool(craft.reset_for_reuse(Transform3D.IDENTITY).get("accepted", false)), "the real Halyard pooled-reuse lifecycle resets cleanly")
	var reset_halyard_snapshot := craft.get_loadmaster_manifest_snapshot()
	reset_halyard_snapshot["craft_id"] = craft.get_ship_id()
	reset_halyard_snapshot["role"] = &"loadmaster"
	var pre_reset_text := detail.text
	hud.update_loadmaster_telemetry(reset_halyard_snapshot)
	_check(detail.text == pre_reset_text, "same-craft generation reset is rejected until the caller clears the HUD lifecycle")
	hud.clear_loadmaster_telemetry()
	hud.update_loadmaster_telemetry(reset_halyard_snapshot)
	_check(detail.text.contains("CRAFT // %s" % str(craft.get_ship_id()).to_upper()) and detail.text.contains("GENERATION // 1"), "explicit HUD detach admits the real same-craft generation-1 reuse snapshot")
	craft.queue_free()
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
