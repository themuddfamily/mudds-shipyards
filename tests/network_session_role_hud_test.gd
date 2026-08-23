extends SceneTree

const Presenter := preload("res://scripts/ui/network_session_status_presenter.gd")
const HudType := preload("res://scripts/ui/hud.gd")
const GameFlowType := preload("res://scripts/game/game_flow.gd")
const AdapterType := preload("res://scripts/network/network_enet_session_adapter.gd")
const BomberType := preload("res://scripts/ships/cinder_long_range_bomber.gd")

var _assertions := 0
var _failures: PackedStringArray = []


class SessionProbe extends AdapterType:
	var authoritative_snapshot: Dictionary = {}

	func get_authoritative_snapshot() -> Dictionary:
		return authoritative_snapshot.duplicate(true)


func _init() -> void:
	call_deferred(&"_run")


func _run() -> void:
	var presenter := Presenter.new()
	var pilot := presenter.present_snapshot(_session_snapshot(2, 4, 2))
	_check(pilot.ownership_text == "PILOT" and pilot.controlled_craft == "Cinder", "connected snapshot exposes pilot and controlled craft")
	_check(pilot.ownership_rows.has("CRAFT CINDER // LOCAL PEER 2") and pilot.ownership_rows.has("PILOT CINDER_PILOT // LOCAL PEER 2"), "authoritative snapshot identifies local craft and pilot-seat ownership")
	var stale := presenter.present_snapshot({"generation": 1, "state": &"disconnected", "local_role": &"observer", "controlled_craft": "Old Craft"})
	_check(stale.state == &"connected" and stale.ownership_text == "PILOT", "stale generation cannot overwrite role state")
	var stale_authority := presenter.present_snapshot(_session_snapshot(3, 3, 7))
	_check(stale_authority.ownership_rows.has("CRAFT CINDER // LOCAL PEER 2"), "stale authoritative revision cannot replace visible ownership")
	var transferred := presenter.present_snapshot(_session_snapshot(4, 5, 7))
	_check(transferred.ownership_rows.has("CRAFT CINDER // REMOTE PEER 7") and transferred.ownership_rows.has("PILOT CINDER_PILOT // REMOTE PEER 7"), "new authoritative revision identifies remote craft and pilot-seat ownership")
	_check(transferred.ownership_notices.has("TRANSFER // CINDER // LOCAL PEER 2 TO REMOTE PEER 7") and transferred.ownership_notices.has("CONTROL DENIED // CINDER OWNED BY REMOTE PEER 7") and transferred.ownership_notices.has("SEAT DENIED // CINDER_PILOT OCCUPIED BY REMOTE PEER 7"), "authoritative ownership change surfaces transfer and local control denial")
	var migrating := presenter.present_snapshot({"generation": 5, "state": &"migrating", "local_role": &"passenger", "controlled_craft": "Halyard"})
	_check(migrating.title == "Host Migration" and migrating.ownership_text == "PASSENGER" and migrating.actions[0].focusable, "migration remains text-first and focusable")
	var hud := HudType.new()
	root.add_child(hud)
	await process_frame
	hud.update_network_session_status(_session_snapshot(1, 8, 2))
	var detail := (hud.get("_runtime_status_detail") as Label).text
	_check(detail.contains("ROLE // PILOT") and detail.contains("OWNERSHIP // CRAFT CINDER // LOCAL PEER 2") and detail.contains("OWNERSHIP // PILOT CINDER_PILOT // LOCAL PEER 2"), "HUD renders local authoritative pilot ownership")
	hud.update_network_session_status(_session_snapshot(2, 9, 7))
	detail = (hud.get("_runtime_status_detail") as Label).text
	_check(detail.contains("OWNERSHIP // CRAFT CINDER // REMOTE PEER 7") and detail.contains("TRANSFER // CINDER // LOCAL PEER 2 TO REMOTE PEER 7") and detail.contains("CONTROL DENIED // CINDER OWNED BY REMOTE PEER 7") and detail.contains("SEAT DENIED // CINDER_PILOT OCCUPIED BY REMOTE PEER 7"), "HUD renders remote transfer and denial state")
	hud.update_network_session_status({"generation": 3, "state": &"disconnected", "local_role": &"observer", "detail": "Disconnected."})
	detail = (hud.get("_runtime_status_detail") as Label).text
	_check(detail.contains("ROLE // OBSERVER") and detail.contains("STATE // DISCONNECTED"), "HUD renders disconnected observer state")
	hud.queue_free()
	await process_frame
	var production_hud := HudType.new()
	var production_flow := GameFlowType.new()
	var production_session := SessionProbe.new()
	var production_bomber := BomberType.new()
	root.add_child(production_hud)
	root.add_child(production_session)
	root.add_child(production_bomber)
	await process_frame
	production_flow.hud = production_hud
	production_flow.network_session = production_session
	production_flow.active_ship = production_bomber
	production_flow._piloting = true
	var production_ship_id := production_bomber.get_ship_id()
	production_session.authoritative_snapshot = _authority_snapshot(
		12, production_ship_id, 1
	)
	var caller_snapshot := production_flow._network_local_role_presentation()
	production_flow._publish_network_session_snapshot(&"connected", &"server", "Ready.")
	detail = (production_hud.get("_runtime_status_detail") as Label).text
	_check(caller_snapshot.local_peer_id == production_session.multiplayer.get_unique_id()
		and caller_snapshot.controlled_craft_id == production_ship_id
		and int((caller_snapshot.authoritative_snapshot as Dictionary).get("revision", 0)) == 12
		and detail.contains("OWNERSHIP // CRAFT %s // LOCAL PEER 1" % str(production_ship_id).to_upper())
		and detail.contains("CRAFT LIFECYCLE // HEALTHY"),
		"production GameFlow caller binds live peer, craft identity, and authoritative snapshot into HUD")
	production_session.authoritative_snapshot = _authority_snapshot(
		11, production_ship_id, 7, &"destroyed"
	)
	production_flow._publish_network_session_snapshot(&"connected", &"server", "Still ready.")
	detail = (production_hud.get("_runtime_status_detail") as Label).text
	_check(detail.contains("OWNERSHIP // CRAFT %s // LOCAL PEER 1" % str(production_ship_id).to_upper())
		and detail.contains("CRAFT LIFECYCLE // HEALTHY")
		and not detail.contains("CONTROL UNAVAILABLE"),
		"production caller cannot let a reordered authority revision replace ownership or damage lifecycle")
	production_session.authoritative_snapshot = _authority_snapshot(
		13, production_ship_id, 1, &"damaged"
	)
	production_flow._publish_network_session_snapshot(&"connected", &"server", "Hull damaged.")
	detail = (production_hud.get("_runtime_status_detail") as Label).text
	_check(detail.contains("CRAFT LIFECYCLE // DAMAGED")
		and not detail.contains("CONTROL UNAVAILABLE"),
		"authoritative damage lifecycle presents a damaged but controllable craft")
	production_session.authoritative_snapshot = _authority_snapshot(
		14, production_ship_id, 7, &"destroyed"
	)
	production_flow._publish_network_session_snapshot(&"connected", &"server", "Destroyed.")
	detail = (production_hud.get("_runtime_status_detail") as Label).text
	var production_presentation := (
		production_hud.get("_network_status_presenter") as NetworkSessionStatusPresenter
	).get_snapshot()
	_check(detail.contains("OWNERSHIP // CRAFT %s // REMOTE PEER 7" % str(production_ship_id).to_upper())
		and detail.contains("CONTROL DENIED")
		and detail.contains("CRAFT LIFECYCLE // DESTROYED")
		and detail.contains("CONTROL UNAVAILABLE // %s DESTROYED" % str(production_ship_id).to_upper())
		and not bool(production_presentation.get("craft_control_available", true))
		and bool(production_presentation.get("presentation_only", false))
		and not production_presentation.has("control_authority"),
		"destroyed authority revision presents explicit unavailability without granting control")
	production_session.authoritative_snapshot = _authority_snapshot(
		15, production_ship_id, 7, &"respawn_pending"
	)
	production_flow._publish_network_session_snapshot(&"connected", &"server", "Respawning.")
	detail = (production_hud.get("_runtime_status_detail") as Label).text
	_check(detail.contains("CRAFT LIFECYCLE // RESPAWNING")
		and not detail.contains("CONTROL UNAVAILABLE //"),
		"authoritative respawn-pending state presents as respawning")
	production_session.authoritative_snapshot = _authority_snapshot(
		16, production_ship_id, 7, &"recovery_ready"
	)
	production_flow._publish_network_session_snapshot(&"connected", &"server", "Ready.")
	detail = (production_hud.get("_runtime_status_detail") as Label).text
	_check(detail.contains("CRAFT LIFECYCLE // READY")
		and not detail.contains("CONTROL UNAVAILABLE //"),
		"authoritative recovery-ready state presents as ready")
	production_flow.free()
	production_bomber.queue_free()
	production_session.queue_free()
	production_hud.queue_free()
	await process_frame
	if _failures.is_empty():
		print("NETWORK_SESSION_ROLE_HUD_TEST_OK (%d assertions)" % _assertions)
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)


func _check(condition: bool, message: String) -> void:
	_assertions += 1
	if not condition:
		_failures.append("FAIL: " + message)


func _session_snapshot(generation: int, revision: int, owner_peer_id: int) -> Dictionary:
	return {
		"generation": generation,
		"state": &"connected",
		"local_role": &"pilot",
		"local_peer_id": 2,
		"controlled_craft": "Cinder",
		"controlled_craft_id": &"cinder",
		"detail": "Session ready.",
		"authoritative_snapshot": {
			"authority_peer_id": 1,
			"revision": revision,
			"sections": {
				&"ownership": [{
					"ship_id": &"cinder",
					"ship_generation": 1,
					"owner_peer_id": owner_peer_id,
					"ownership_generation": 2 if owner_peer_id == 2 else 3,
				}],
				&"boarding": [{
					"seat_id": &"cinder_pilot",
					"seat_generation": 1,
					"occupant_peer_id": owner_peer_id,
					"avatar_id": &"pilot_avatar",
					"vessel_id": &"cinder",
					"role": &"pilot",
				}],
			},
		},
	}


func _authority_snapshot(
	revision: int,
	ship_id: StringName,
	owner_peer_id: int,
	lifecycle_state: StringName = &"healthy",
) -> Dictionary:
	return {
		"authority_peer_id": 1,
		"revision": revision,
		"sections": {
			&"ownership": [{
				"ship_id": ship_id,
				"ship_generation": 1,
				"owner_peer_id": owner_peer_id,
				"ownership_generation": 1 if owner_peer_id == 1 else 2,
			}],
			&"boarding": [{
				"seat_id": &"production_pilot",
				"seat_generation": 1,
				"occupant_peer_id": owner_peer_id,
				"avatar_id": &"production_avatar",
				"vessel_id": ship_id,
				"role": &"pilot",
			}],
			&"respawn": [{
				"entity_id": ship_id,
				"entity_generation": 1,
				"component_generation": 1,
				"state": lifecycle_state,
			}],
		},
	}
