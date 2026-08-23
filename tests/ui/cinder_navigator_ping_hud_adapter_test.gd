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
			&"passenger": {"occupant": "navigator_avatar", "available": false, "seat_id": &"navigator_station"},
		},
		"actor_id": "navigator_avatar",
	}
	var accepted := adapter.apply_bridge_result({
		"accepted": true,
		"status": &"navigator_ping_published",
		"wire_receipt": {
			"peer_id": 62,
			"peer_generation": 3,
			"avatar_id": &"navigator_avatar",
			"seat_id": &"navigator_station",
			"seat_generation": 1,
			"role": &"passenger",
			"request_sequence": 2,
			"server_tick": 12,
			"migration_generation": 2,
			"action": &"passenger_ping",
			"payload": {"channel": &"sensor", "marker_id": &"route_beacon"},
		},
	}, base)
	_check(bool(accepted.get("accepted", false)), "active bridge receipt reaches the real HUD seam")
	_check(str((accepted.get("composed", {}) as Dictionary).get("cinder_navigator_ping", {}).get("state", &"")) == "active", "active composition preserves presenter state")
	_check(str((accepted.get("composed", {}).get("roles", {}).get("passenger", {}).get("occupant", ""))).contains("PING ACTIVE"), "active composition keeps ordinary crew context and adds a bounded ping marker")
	_check(str(hud.get("_runtime_status_title").text) == "Crew Roles and Seats", "real HUD receives the composed crew-role update")
	var duplicate := adapter.apply_bridge_result({
		"accepted": true,
		"status": &"navigator_ping_published",
		"wire_receipt": {
			"peer_id": 62, "peer_generation": 3, "avatar_id": &"navigator_avatar",
			"seat_id": &"navigator_station", "seat_generation": 1, "role": &"passenger",
			"request_sequence": 2, "server_tick": 12, "migration_generation": 2,
			"action": &"passenger_ping", "payload": {"channel": &"sensor", "marker_id": &"route_beacon"},
		},
	}, base)
	_check(duplicate.get("reason") == &"duplicate", "identical generation and sequence are deduplicated")
	var stale := adapter.apply_bridge_result({"accepted": false, "status": &"stale_request_sequence"}, base)
	_check(bool(stale.get("accepted", false)) and stale.get("source_state") == &"stale", "stale bridge result reaches the HUD as an accessible state")
	_check(str((stale.get("composed", {}) as Dictionary).get("roles", {}).get("passenger", {}).get("occupant", "")).contains("PING STALE"), "stale composition remains bounded to the crew HUD row")
	var rejected := adapter.apply_bridge_result({"accepted": false, "status": &"navigator_identity_mismatch"}, base)
	_check(bool(rejected.get("accepted", false)) and rejected.get("source_state") == &"rejected", "rejected bridge result reaches the HUD as an accessible state")
	_check(str((rejected.get("composed", {}) as Dictionary).get("roles", {}).get("passenger", {}).get("occupant", "")).contains("PING REJECTED"), "rejected composition remains bounded to the crew HUD row")
	var cleared := adapter.apply_bridge_result({
		"accepted": true,
		"status": &"peer_released",
		"tombstones": [{"receipt": {
			"peer_id": 62, "peer_generation": 3, "avatar_id": &"navigator_avatar",
			"seat_id": &"navigator_station", "seat_generation": 1, "role": &"passenger",
			"request_sequence": 3, "server_tick": 13, "migration_generation": 2,
			"action": &"passenger_ping_clear",
			"payload": {"channel": &"sensor", "marker_id": &"route_beacon", "clear": true, "reason": &"peer_released"},
		}}],
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
