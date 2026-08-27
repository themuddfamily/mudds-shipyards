extends SceneTree

const Presenter := preload("res://scripts/ui/cinder_navigator_ping_presenter.gd")
const Bridge := preload("res://scripts/network/network_cinder_navigator_ping_bridge.gd")
const Adapter := preload("res://scripts/network/network_enet_session_adapter.gd")
const Cinder := preload("res://scripts/ships/cinder_cargo_hauler.gd")
const Authority := preload("res://scripts/ships/crew_seat_role_authority.gd")

var _assertions := 0
var _failures := PackedStringArray()


func _init() -> void:
	call_deferred(&"_run")


func _run() -> void:
	var adapter := Adapter.new()
	root.add_child(adapter)
	_check(bool(adapter.host(29208, 1).get("accepted", false)), "real session hosts for presenter input")
	var rotated: Dictionary = adapter._migration.rotate_server(1)
	_check(bool(rotated.get("accepted", false)) and int(rotated.get("migration_generation", 0)) == 2, "presenter receives a non-default authoritative migration")

	var cinder := Cinder.new()
	root.add_child(cinder)
	await process_frame
	await physics_frame
	var authority := Authority.new(1)
	for record in [
		[&"cinder_pilot", Authority.ROLE_PILOT],
		[&"cinder_gunner", Authority.ROLE_GUNNER],
		[&"cinder_engineer", Authority.ROLE_ENGINEER],
		[Cinder.LOADMASTER_STATION_SEAT_ID, Authority.ROLE_PASSENGER],
		[Cinder.NAVIGATOR_STATION_SEAT_ID, Authority.ROLE_PASSENGER],
	]:
		_check(bool(authority.register_seat(
			StringName(record[0]), Cinder.COMPONENT_ID, StringName(record[1]),
			&"cinder_cargo_walkable_interior", 1, StringName(record[0])
		).get("accepted", false)), "real Cinder roster seat registers")
	_check(bool(authority.seal_roster().get("accepted", false)), "navigator roster seals")
	_check(bool(cinder.attach_crew_role_authority(authority).get("accepted", false)), "Cinder owns the admitted seat authority")
	var actor := CharacterBody3D.new()
	root.add_child(actor)
	var interaction := cinder.get_navigator_interaction()
	actor.global_position = interaction.global_position
	_check(bool(interaction.try_claim(actor, 1, 62, &"navigator_avatar", 1).get("accepted", false)), "physical navigator actor claims the real seat")

	var bridge := Bridge.new()
	_check(bool(bridge.attach(adapter, cinder).get("accepted", false)), "bridge attaches to the real Cinder")
	var presenter := Presenter.new()
	var accepted := bridge.submit_ping(
		62, 3, &"navigator_avatar", 1, 2,
		{"channel": &"sensor", "marker_id": &"route_beacon"}, 12, 2
	)
	var active := presenter.present_bridge_result(accepted)
	_check(active.get("state") == &"active" and active.get("state_marker") == &"*", "accepted wire receipt becomes an accessible active state")
	_check(
		active.get("marker_status") == &"set"
			and active.get("state_label") == "ACTIVE"
			and str(active.get("accessibility_label", "")).contains("marker set"),
		"active navigator pings expose a set navigation marker beside their active state"
	)
	_check(active.get("channel") == "SENSOR" and active.get("marker_id") == "route_beacon", "active presentation exposes bounded channel and marker")
	_check(int(active.get("migration_generation", 0)) == 2 and int(active.get("server_tick", 0)) == 12, "active presentation preserves migration and server tick")
	_check(active.get("ship_id") == Cinder.COMPONENT_ID and int(active.get("ship_generation", 0)) == 1 and active.get("seat_id") == Cinder.NAVIGATOR_STATION_SEAT_ID, "active presentation preserves exact Cinder ship lifecycle and navigator seat identity")
	_check(active.get("presentation_only", false) and not active.get("authority", true), "active presentation declares no authority")
	var accepted_snapshot := presenter.get_snapshot()
	var missing_role := (accepted.get("wire_receipt", {}) as Dictionary).duplicate(true)
	missing_role.erase("role")
	missing_role.request_sequence = 3
	missing_role.server_tick = 13
	_check(presenter.present_wire_receipt(missing_role).get("reason") == &"invalid_navigator_seat_identity", "missing role never defaults to passenger")
	var foreign_ship := (accepted.get("wire_receipt", {}) as Dictionary).duplicate(true)
	foreign_ship.ship_id = &"foreign_ship"
	foreign_ship.request_sequence = 3
	foreign_ship.server_tick = 13
	_check(presenter.present_wire_receipt(foreign_ship).get("reason") == &"invalid_cinder_ship_identity", "foreign ship receipts are rejected at the HUD boundary")
	_check(presenter.get_snapshot() == accepted_snapshot, "invalid receipts do not corrupt the last accepted presentation snapshot")
	var fence_presenter := Presenter.new()
	_check(fence_presenter.present_bridge_result(accepted).get("state") == &"active", "fence presenter accepts the production bridge result")
	var wrong_lifecycle := (accepted.get("wire_receipt", {}) as Dictionary).duplicate(true)
	wrong_lifecycle.ship_generation = 2
	wrong_lifecycle.request_sequence = 3
	wrong_lifecycle.server_tick = 13
	_check(fence_presenter.present_wire_receipt(wrong_lifecycle).get("reason") == &"stale_lifecycle_generation", "foreign Cinder lifecycle generations are fenced")
	var foreign_actor := (accepted.get("wire_receipt", {}) as Dictionary).duplicate(true)
	foreign_actor.peer_id = 99
	foreign_actor.avatar_id = &"foreign_navigator"
	foreign_actor.peer_generation = 1
	foreign_actor.request_sequence = 1
	foreign_actor.server_tick = 13
	_check(fence_presenter.present_wire_receipt(foreign_actor).get("reason") == &"stale_seat_generation", "foreign peer identity cannot replace an active navigator without a newer seat generation")
	var next_peer := (accepted.get("wire_receipt", {}) as Dictionary).duplicate(true)
	next_peer.peer_generation = 4
	next_peer.request_sequence = 1
	next_peer.server_tick = 13
	_check(fence_presenter.present_wire_receipt(next_peer).get("state") == &"active", "new peer generation starts fresh subordinate fences")
	var stale_peer := next_peer.duplicate(true)
	stale_peer.peer_generation = 3
	stale_peer.seat_generation = 9
	stale_peer.request_sequence = 99
	stale_peer.server_tick = 99
	_check(fence_presenter.present_wire_receipt(stale_peer).get("reason") == &"stale_peer_generation", "old peer generation cannot return through newer seat data")
	var next_seat := next_peer.duplicate(true)
	next_seat.seat_generation = 2
	next_seat.request_sequence = 1
	next_seat.server_tick = 14
	_check(fence_presenter.present_wire_receipt(next_seat).get("state") == &"active", "new seat generation starts fresh request fences")
	var stale_seat := next_seat.duplicate(true)
	stale_seat.seat_generation = 1
	stale_seat.request_sequence = 99
	stale_seat.server_tick = 99
	_check(fence_presenter.present_wire_receipt(stale_seat).get("reason") == &"stale_seat_generation", "old seat generation cannot return with a higher sequence")
	var stale_tick := next_seat.duplicate(true)
	stale_tick.request_sequence = 2
	stale_tick.server_tick = 13
	_check(fence_presenter.present_wire_receipt(stale_tick).get("reason") == &"stale_server_tick", "server tick regression is fenced after peer and seat generations match")

	var stale := bridge.submit_ping(62, 3, &"navigator_avatar", 1, 2, {}, 13, 2)
	var stale_view := presenter.present_bridge_result(stale)
	_check(stale_view.get("state") == &"stale" and stale_view.get("state_marker") == &"!", "replayed bridge result is explicitly stale")
	_check(presenter.get_snapshot() == accepted_snapshot, "real rejected bridge envelopes report bounded status without replacing accepted state")
	var detached_bridge := Bridge.new()
	var real_detached_rejection := detached_bridge.submit_ping(62, 3, &"navigator_avatar", 1, 3, {}, 13, 2)
	_check(real_detached_rejection.get("status") == &"detached" and presenter.present_bridge_result(real_detached_rejection).get("state") == &"rejected" and presenter.get_snapshot() == accepted_snapshot, "a real rejected detached envelope cannot masquerade as accepted HUD lifecycle detach")
	var oversized_status := presenter.present_bridge_result({"accepted": false, "status": "x".repeat(200), "policy_version": Bridge.POLICY_VERSION})
	_check(str(oversized_status.get("reason", "")).length() == 64 and presenter.get_snapshot() == accepted_snapshot, "untrusted rejection status is bounded without corrupting accepted state")
	var rotated_release: Dictionary = adapter._migration.rotate_server(1)
	_check(bool(rotated_release.get("accepted", false)) and int(rotated_release.get("migration_generation", 0)) == 3, "release exercises a real migration boundary")
	var released := bridge.release_peer(62)
	var clear_receipt := (((released.get("tombstones", []) as Array)[0] as Dictionary).get("receipt", {}) as Dictionary)
	var foreign_peer := clear_receipt.duplicate(true)
	foreign_peer.peer_id = 99
	_check(presenter.present_tombstones([{"receipt": foreign_peer}]).get("reason") == &"stale_clear_tombstone" and presenter.get_snapshot() == accepted_snapshot, "foreign peer tombstone cannot clear the active navigator")
	var foreign_seat := clear_receipt.duplicate(true)
	foreign_seat.seat_id = &"cinder_loadmaster_station"
	_check(presenter.present_tombstones([{"receipt": foreign_seat}]).get("reason") == &"stale_clear_tombstone" and presenter.get_snapshot() == accepted_snapshot, "foreign seat tombstone cannot clear the active navigator")
	var foreign_clear_ship := clear_receipt.duplicate(true)
	foreign_clear_ship.ship_id = &"foreign_ship"
	_check(presenter.present_tombstones([{"receipt": foreign_clear_ship}]).get("reason") == &"stale_clear_tombstone" and presenter.get_snapshot() == accepted_snapshot, "foreign ship tombstone cannot clear the active navigator")
	var foreign_request := clear_receipt.duplicate(true)
	foreign_request.payload = (foreign_request.get("payload", {}) as Dictionary).duplicate(true)
	foreign_request.payload.source_request_sequence = 999
	_check(presenter.present_tombstones([{"receipt": foreign_request}]).get("reason") == &"stale_clear_tombstone" and presenter.get_snapshot() == accepted_snapshot, "tombstone must name the exact active request")
	var released_view := presenter.present_bridge_result(released)
	_check(released_view.get("state") == &"cleared" and released_view.get("state_marker") == &"—", "peer release tombstone clears the visible ping")
	_check(
		released_view.get("marker_status") == &"clear"
			and released_view.get("state_marker") != active.get("state_marker")
			and str(released_view.get("accessibility_label", "")).contains("marker cleared"),
		"cleared markers use a distinct horizontal marker and explicit non-hue status"
	)
	_check(released_view.get("reason") == &"peer_released", "clear reason is retained for accessible presentation")
	_check(int(released_view.get("migration_generation", 0)) == 3, "exact tombstone clears across a newer migration generation")

	var fresh := bridge.submit_ping(
		62, 3, &"navigator_avatar", 1, 3,
		{"channel": &"sensor", "marker_id": &"fresh_beacon"}, 14, 3
	)
	_check(bool(fresh.get("accepted", false)), "fresh sequence remains consumable after peer cursor cleanup")
	_check(presenter.present_bridge_result(fresh).get("state") == &"active", "a real fresh receipt may reuse the synthetic clear sequence")
	var detached := bridge.detach()
	var detached_view := presenter.present_bridge_result(detached)
	_check(detached_view.get("state") == &"cleared" and not detached_view.get("attached", true), "detach tombstone clears stale remote state and marks lifecycle detached")
	_check(int(detached_view.get("migration_generation", 0)) == 3, "detach clear keeps the authoritative migration fence")
	var attached := presenter.present_bridge_result({"accepted": true, "status": &"attached"})
	_check(attached.get("state") == &"available" and attached.get("attached", false), "re-entry resets the presenter to an available state")
	_check(
		attached.get("state_marker") == &"+"
			and attached.get("marker_status") == &"ready"
			and attached.get("state_marker") != released_view.get("state_marker"),
		"ready and clear navigator states remain shape-distinct at small HUD scale"
	)
	var rejected := presenter.present_bridge_result({"accepted": false, "status": &"navigator_identity_mismatch"})
	_check(rejected.get("state") == &"rejected" and rejected.get("state_marker") == &"×", "rejected bridge result is explicitly accessible")
	_check(
		rejected.get("marker_status") == &"rejected"
			and rejected.get("state_marker") != attached.get("state_marker")
			and str(rejected.get("accessibility_label", "")).contains("rejected"),
		"rejected ping status remains readable without a color cue"
	)

	_check(bool(interaction.release(actor, 1, 62, &"navigator_avatar", 4).get("accepted", false)), "physical navigator actor releases cleanly")
	actor.queue_free()
	cinder.queue_free()
	adapter.shutdown(&"test_complete")
	adapter.queue_free()
	await process_frame
	if _failures.is_empty():
		print("CINDER_NAVIGATOR_PING_PRESENTER_TEST_OK: %d checks" % _assertions)
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)


func _check(condition: bool, description: String) -> void:
	_assertions += 1
	if not condition:
		_failures.append("FAIL: " + description)
