extends SceneTree

const HudType := preload("res://scripts/ui/hud.gd")
const PresenterType := preload("res://scripts/ui/heavy_breach_activity_presenter.gd")
var _assertions := 0
var _failures: PackedStringArray = []

func _init() -> void:
	call_deferred(&"_run")

func _run() -> void:
	var presenter := PresenterType.new()
	var snapshot := {
		"activity_id": &"shipyard_heavy_breach",
		"generation": 7,
		"protected_objective": "Habitat Core",
		"director": {
			"state": &"running", "scenario": &"heavy_breach", "outcome": &"pending",
			"launched": true, "elapsed": 12.5, "scenario_generation": 7,
			"protected_anchor": "Habitat Core", "breach_picket": "Heavy Picket",
		},
		"reward_handoff": {"configured": true, "last_result": {}},
	}
	var presented := presenter.present(snapshot)
	_check(bool(presented.get("presentation_only", false)), "presenter remains presentation-only")
	_check(str(presented.get("text", "")).contains("PHASE RUNNING / HEAVY BREACH"), "published phase is readable")
	_check(str(presented.get("text", "")).contains("PROTECTED Habitat Core") and str(presented.get("text", "")).contains("PICKET Heavy Picket"), "published assets are readable")
	_check(str(presented.get("text", "")).contains("REWARD  HANDOFF READY"), "reward handoff state is readable")

	var hud := HudType.new()
	root.add_child(hud)
	await process_frame
	hud.set_activity_objective("Heavy Breach", snapshot)
	var report := hud.get_activity_objective_report()
	_check(str(report.get("text", "")).contains("HEAVY BREACH"), "HUD generic objective path renders heavy breach")
	_check(bool((report.get("heavy_breach", {}) as Dictionary).get("presentation_only", false)), "HUD retains presenter receipt")
	hud.queue_free()
	await process_frame
	if _failures.is_empty():
		print("HEAVY_BREACH_ACTIVITY_HUD_TEST_OK (%d assertions)" % _assertions)
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)

func _check(condition: bool, message: String) -> void:
	_assertions += 1
	if not condition:
		_failures.append("FAIL: " + message)
