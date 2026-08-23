extends SceneTree

const HudType := preload("res://scripts/ui/hud.gd")

var _assertions := 0
var _failures: PackedStringArray = []


func _init() -> void:
	call_deferred(&"_run")


func _run() -> void:
	var acquired := HudType.get_target_lock_presentation(&"acquired", "drone_07")
	_check(acquired.marker == "[+]", "acquired state uses lock shape")
	_check(acquired.label == "LOCKED  DRONE_07", "acquired state names target")
	var friendly := HudType.get_target_lock_presentation(&"friendly_blocked")
	_check(friendly.marker == "[=]" and friendly.label == "FRIENDLY  HOLD FIRE", "friendly block is explicit")
	var invalid := HudType.get_target_lock_presentation(&"invalid")
	_check(invalid.marker == "[?]" and invalid.label == "INVALID TARGET", "invalid state is explicit")
	var searching := HudType.get_target_lock_presentation(&"unknown")
	_check(searching.marker == "[...]" and searching.label == "SEARCHING", "unknown state fails safe to searching")
	_check(HudType.compute_effective_ui_scale(1.4, Vector2(1920.0, 1080.0)) > 1.0, "reticle can follow authored UI scale")
	if _failures.is_empty():
		print("TARGET_LOCK_HUD_TEST_OK (%d assertions)" % _assertions)
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)


func _check(condition: bool, message: String) -> void:
	_assertions += 1
	if condition:
		print("PASS: %s" % message)
	else:
		_failures.append("FAIL: " + message)
