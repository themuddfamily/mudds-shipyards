extends SceneTree

const HUD_SCENE := preload("res://scenes/ui/hud.tscn")

var _assertions := 0
var _failures: Array[String] = []
var _intent: Dictionary = {}


func _initialize() -> void:
	var hud := HUD_SCENE.instantiate() as GameHUD
	root.add_child(hud)
	hud.nearby_activity_intent_requested.connect(func(intent: Dictionary) -> void: _intent = intent.duplicate(true))
	await process_frame
	var view := hud.set_nearby_activity_snapshot({
		"host": {"activity": {"state_id": "active"}},
		"mining": {"state": 2, "elapsed_seconds": 6.0, "extraction_seconds": 6.0, "reward_requested": true},
	})
	_check(bool(view.get("focusable", false)), "HUD accepts the detached presenter view")
	_check(int(hud.get_nearby_activity_report().get("row_count", 0)) == 7, "HUD retains one focusable row per nearby activity")
	hud.show_nearby_activity_page()
	_check(bool(hud.get_nearby_activity_report().get("visible", false)), "nearby activity page can be shown explicitly")
	var page := hud.find_child("NearbyActivityPage", true, false)
	var rows := hud.get("_nearby_activity_rows") as VBoxContainer
	var row: Control = null
	for candidate in rows.get_children() if rows != null else []:
		if "cinder_platform_mining_run" in str(candidate.name):
			row = candidate as Control
			break
	var start := row.get_child(2) as Button if row != null else null
	if start != null:
		start.emit_signal("pressed")
	_check(_intent.get("reason", &"") == &"start_requested", "HUD forwards a start intent without invoking activity authority")
	hud.clear_nearby_activity_snapshot()
	_check(hud.get_nearby_activity_report().get("snapshot", {}) == {}, "detaching/clearing removes retained activity snapshot")
	hud.queue_free()
	await process_frame
	if _failures.is_empty():
		print("PASS nearby_activity_hud_integration_test (%d assertions)" % _assertions)
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _check(condition: bool, message: String) -> void:
	_assertions += 1
	if not condition:
		_failures.append(message)
