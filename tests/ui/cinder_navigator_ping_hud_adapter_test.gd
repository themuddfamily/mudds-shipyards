extends SceneTree

const Adapter := preload("res://scripts/ui/cinder_navigator_ping_hud_adapter.gd")
const Presenter := preload("res://scripts/ui/cinder_navigator_ping_presenter.gd")
const Hud := preload("res://scripts/ui/hud.gd")

var _assertions := 0
var _failures := PackedStringArray()


func _init() -> void:
	call_deferred(&"_run")


func _run() -> void:
	var hud := Hud.new()
	hud.name = "CinderNavigatorPingHudTest"
	root.add_child(hud)
	await process_frame
	var presenter := Presenter.new()
	var adapter := Adapter.new()
	_check(bool(adapter.attach(hud, presenter).get("accepted", false)), "adapter binds the real HUD crew-role seam")
	var base := {
		"roles": {
			&"pilot": {"occupant": "pilot_avatar", "available": false},
			&"gunner": {"occupant": "", "available": true},
			&"engineer": {"occupant": "engineer_avatar", "available": false},
			&"passenger": {"occupant": "navigator_avatar", "available": false, "seat_id": &"cinder_navigator_station"},
		},
		"actor_id": "navigator_avatar",
	}
	var receipt := _wire_receipt()
	var accepted_result := _accepted_result(receipt)
	var accepted := adapter.apply_bridge_result(accepted_result, base)
	_check(bool(accepted.get("accepted", false)), "active bridge receipt reaches the real HUD seam")
	_check(str((accepted.get("composed", {}) as Dictionary).get("cinder_navigator_ping", {}).get("state", &"")) == "active", "active composition preserves presenter state")
	_check(str((accepted.get("composed", {}).get("roles", {}).get("passenger", {}).get("occupant", ""))).contains("PING ACTIVE"), "active composition keeps ordinary crew context and adds a bounded ping marker")
	_check(str(hud.get("_runtime_status_title").text) == "Crew Roles and Seats", "real HUD receives the composed crew-role update")
	var duplicate := adapter.apply_bridge_result(accepted_result, base)
	_check(duplicate.get("reason") == &"duplicate", "identical generation and sequence are deduplicated")
	var missing_role := receipt.duplicate(true)
	missing_role.erase("role")
	missing_role.request_sequence = 3
	missing_role.server_tick = 13
	var invalid_role := adapter.apply_bridge_result(_accepted_result(missing_role), base)
	_check(invalid_role.get("source_state") == &"rejected", "a receipt without the explicit navigator role is rejected")
	_check(str((invalid_role.get("composed", {}) as Dictionary).get("roles", {}).get("passenger", {}).get("occupant", "")).contains("PING ACTIVE"), "invalid role input cannot replace the last accepted navigator overlay")
	_check((invalid_role.get("composed", {}) as Dictionary).get("cinder_navigator_ping_status", {}).get("reason") == &"invalid_navigator_seat_identity", "invalid role input is exposed as bounded status instead of defaulting to passenger")
	var stale_envelope := {"accepted": false, "status": &"stale_request_sequence", "policy_version": &"network_cinder_navigator_ping_bridge_v1"}
	var stale := adapter.apply_bridge_result(stale_envelope, base)
	_check(bool(stale.get("accepted", false)) and stale.get("source_state") == &"stale", "stale bridge result reaches the HUD as an accessible state")
	_check(str((stale.get("composed", {}) as Dictionary).get("roles", {}).get("passenger", {}).get("occupant", "")).contains("PING ACTIVE"), "stale status cannot corrupt the accepted crew HUD row")
	_check((stale.get("composed", {}) as Dictionary).get("cinder_navigator_ping_status", {}).get("state") == &"stale", "stale bridge status remains separately accessible")
	var rejected_envelope := {"accepted": false, "status": &"navigator_identity_mismatch", "policy_version": &"network_cinder_navigator_ping_bridge_v1"}
	var rejected := adapter.apply_bridge_result(rejected_envelope, base)
	_check(bool(rejected.get("accepted", false)) and rejected.get("source_state") == &"rejected", "rejected bridge result reaches the HUD as an accessible state")
	_check(str((rejected.get("composed", {}) as Dictionary).get("roles", {}).get("passenger", {}).get("occupant", "")).contains("PING ACTIVE"), "rejected status cannot corrupt the accepted crew HUD row")
	_check((adapter.get_snapshot().get("source_view", {}) as Dictionary).get("state") == &"active" and (adapter.get_snapshot().get("status_view", {}) as Dictionary).get("state") == &"rejected", "adapter snapshots retain accepted state beside the latest bounded status")
	var clear_receipt := receipt.duplicate(true)
	clear_receipt.action = &"passenger_ping_clear"
	clear_receipt.request_sequence = 3
	clear_receipt.server_tick = 13
	clear_receipt.payload = {"channel": &"sensor", "marker_id": &"route_beacon", "clear": true, "reason": &"peer_released", "source_request_sequence": 2}
	var wrong_request_clear := clear_receipt.duplicate(true)
	wrong_request_clear.payload = (clear_receipt.get("payload", {}) as Dictionary).duplicate(true)
	wrong_request_clear.payload.source_request_sequence = 99
	var refused_clear := adapter.apply_bridge_result({
		"accepted": true,
		"status": &"peer_released",
		"policy_version": &"network_cinder_navigator_ping_bridge_v1",
		"tombstone_count": 1,
		"tombstone_publication": {"accepted": true},
		"tombstones": [{"receipt": wrong_request_clear}],
	}, base)
	_check(refused_clear.get("source_state") == &"stale" and (refused_clear.get("composed", {}) as Dictionary).get("cinder_navigator_ping", {}).get("state") == &"active", "foreign request tombstone leaves the accepted navigator active")
	var cleared := adapter.apply_bridge_result({
		"accepted": true,
		"status": &"peer_released",
		"policy_version": &"network_cinder_navigator_ping_bridge_v1",
		"tombstone_count": 1,
		"tombstone_publication": {"accepted": true},
		"tombstones": [{"receipt": clear_receipt}],
	}, base)
	_check(bool(cleared.get("accepted", false)) and cleared.get("source_state") == &"cleared", "release tombstone reaches the HUD as cleared")
	_check(str((cleared.get("composed", {}) as Dictionary).get("roles", {}).get("passenger", {}).get("occupant", "")).contains("PING CLEARED"), "tombstone clear is visible through the crew HUD seam")
	_check(bool(adapter.detach().get("accepted", false)), "adapter detaches without owning HUD lifecycle")
	var detached := adapter.apply_bridge_result({"accepted": true, "status": &"attached"}, base)
	_check(not bool(detached.get("accepted", true)) and detached.get("reason") == &"detached", "detached adapter cannot mutate the retained HUD")
	var rebound := adapter.attach(hud, presenter)
	_check(bool(rebound.get("accepted", false)), "adapter supports clean re-entry")
	var available := adapter.apply_bridge_result({"accepted": true, "status": &"attached"}, base)
	_check(available.get("source_state") == &"available", "re-entry restores ordinary crew fallback state")
	_check(not str((available.get("composed", {}) as Dictionary).get("roles", {}).get("passenger", {}).get("occupant", "")).contains("PING"), "ordinary crew fallback is not polluted after re-entry")
	var foreign_view := adapter.apply_view({"component_id": &"foreign", "state": &"active", "presentation_only": true}, base)
	_check(not bool(foreign_view.get("accepted", true)) and foreign_view.get("reason") == &"presenter_view_required", "adapter accepts only committed navigator presenter views")
	hud.queue_free()
	await process_frame
	if _failures.is_empty():
		print("CINDER_NAVIGATOR_PING_HUD_ADAPTER_TEST_OK: %d checks" % _assertions)
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)


func _check(condition: bool, description: String) -> void:
	_assertions += 1
	if not condition:
		_failures.append("FAIL: " + description)


func _wire_receipt() -> Dictionary:
	return {
		"peer_id": 62,
		"peer_generation": 3,
		"avatar_id": &"navigator_avatar",
		"seat_id": &"cinder_navigator_station",
		"seat_generation": 1,
		"role": &"passenger",
		"ship_id": &"cinder-cargo-hauler",
		"ship_generation": 1,
		"request_sequence": 2,
		"server_tick": 12,
		"migration_generation": 2,
		"action": &"passenger_ping",
		"payload": {"channel": &"sensor", "marker_id": &"route_beacon"},
	}


func _accepted_result(receipt: Dictionary) -> Dictionary:
	return {
		"accepted": true,
		"status": &"navigator_ping_published",
		"policy_version": &"network_cinder_navigator_ping_bridge_v1",
		"receipt": {
			"occupant_peer_id": receipt.get("peer_id", 0),
			"avatar_id": receipt.get("avatar_id", &""),
			"seat_generation": receipt.get("seat_generation", 0),
			"request_sequence": receipt.get("request_sequence", 0),
		},
		"snapshot": {"station_id": receipt.get("seat_id", &""), "receipt": (receipt.get("payload", {}) as Dictionary).duplicate(true)},
		"wire_receipt": receipt.duplicate(true),
		"publication": {"accepted": true},
	}
