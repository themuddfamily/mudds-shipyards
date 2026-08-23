extends SceneTree

const Presenter := preload("res://scripts/ui/network_session_status_presenter.gd")
const HudType := preload("res://scripts/ui/hud.gd")

var _assertions := 0
var _failures: PackedStringArray = []


func _init() -> void:
	call_deferred(&"_run")


func _run() -> void:
	var presenter := Presenter.new()
	var pilot := presenter.present_snapshot({"generation": 2, "state": &"connected", "local_role": &"pilot", "controlled_craft": "Cinder", "detail": "Session ready."})
	_check(pilot.ownership_text == "PILOT" and pilot.controlled_craft == "Cinder", "connected snapshot exposes pilot and controlled craft")
	var stale := presenter.present_snapshot({"generation": 1, "state": &"disconnected", "local_role": &"observer", "controlled_craft": "Old Craft"})
	_check(stale.state == &"connected" and stale.ownership_text == "PILOT", "stale generation cannot overwrite role state")
	var migrating := presenter.present_snapshot({"generation": 3, "state": &"migrating", "local_role": &"passenger", "controlled_craft": "Halyard"})
	_check(migrating.title == "Host Migration" and migrating.ownership_text == "PASSENGER" and migrating.actions[0].focusable, "migration remains text-first and focusable")
	var hud := HudType.new()
	root.add_child(hud)
	await process_frame
	hud.update_network_session_status({"generation": 1, "state": &"connected", "local_role": &"pilot", "controlled_craft": "Cinder", "detail": "Ready."})
	var detail := (hud.get("_runtime_status_detail") as Label).text
	_check(detail.contains("ROLE // PILOT") and detail.contains("CRAFT // Cinder"), "HUD renders role and craft text")
	hud.update_network_session_status({"generation": 2, "state": &"disconnected", "local_role": &"observer", "detail": "Disconnected."})
	detail = (hud.get("_runtime_status_detail") as Label).text
	_check(detail.contains("ROLE // OBSERVER") and detail.contains("STATE // DISCONNECTED"), "HUD renders disconnected observer state")
	hud.queue_free()
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
