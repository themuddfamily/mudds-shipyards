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
	snapshot.director.scenario = &"paired_wing"
	snapshot.director.active_roster = 2
	snapshot.reward_handoff.last_result = {"accepted": true, "reason": &"old_breach_reward"}
	hud.set_activity_objective("Paired wing", snapshot)
	var wing_report := hud.get_activity_objective_report()
	var wing_text := str(wing_report.get("text", ""))
	_check("PAIRED WING" in wing_text and "2 WING CONTACTS" in wing_text
		and "NO CREDIT REWARD" in wing_text and not "PICKET" in wing_text
		and not "REWARD  ACCEPTED" in wing_text,
		"Wing HUD describes both targets and no credit even after an old paid contract")
	snapshot.sortie_armed = true
	snapshot.offered_scenario = &"paired_wing"
	var armed_wing := presenter.present(snapshot)
	_check(armed_wing.title == "PAIRED WING" and "SORTIE ARMED" in armed_wing.text
		and "NO CREDIT REWARD" in armed_wing.text,
		"armed Wing retains its own name and unpaid encounter disclosure")
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
