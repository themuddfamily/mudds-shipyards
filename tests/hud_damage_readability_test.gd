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
	hud.update_ship_telemetry({"hull": 18.0, "maximum_hull": 100.0, "damage_status": "critical", "engine_power": 0.42})
	var label := hud.get("_damage_status_label") as Label
	_check(label.text.contains("!! CRITICAL !!") and label.text.contains("ENGINE OUTPUT  042%") and label.text.contains("HULL INTEGRITY  018%"), "critical damage exposes text-only severity, engine output, and hull integrity")
	hud.set_reduced_motion(true)
	hud.update_ship_telemetry({"hull": 76.0, "maximum_hull": 100.0, "damage_status": "healthy", "engine_power": 1.0})
	_check(label.text.contains("HULL  //  OK") and label.text.contains("HULL INTEGRITY  076%") and hud.is_reduced_motion(), "healthy component status remains readable with reduced motion")
	hud.queue_free()
	await process_frame
	if _failures.is_empty():
		print("HUD_DAMAGE_READABILITY_TEST_OK (%d assertions)" % _assertions)
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)

func _check(condition: bool, message: String) -> void:
	_assertions += 1
	if not condition:
		_failures.append("FAIL: " + message)
