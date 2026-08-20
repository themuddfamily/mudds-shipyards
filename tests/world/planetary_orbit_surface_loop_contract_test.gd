extends SceneTree

const ContractScript := preload("res://scripts/world/planetary_orbit_surface_loop_contract.gd")

var _assertions := 0
var _failures := PackedStringArray()


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var contract := ContractScript.new(&"aurora_temperate_world", &"aurora_landing", &"mudds_shipyards", true)
	_check(contract.is_configuration_valid(), "valid world, region, and return target configure")
	_check(contract.begin(7).accepted, "begin enters orbit approach")
	_check(
		contract.confirm_descent(true, &"aurora_landing", true, _observation(), 7).reason
			== &"out_of_order",
		"descent cannot skip orbital approach and entry",
	)
	_check(
		contract.confirm_orbit_approach(false, _observation(), 7).reason
			== &"orbit_approach_prerequisites_not_met",
		"position alone cannot claim orbital handoff",
	)
	_check(
		contract.confirm_orbit_approach(true, _observation(), 6).reason == &"stale_generation",
		"stale orbit producer is rejected",
	)
	_check(contract.confirm_orbit_approach(true, _observation(), 7).accepted, "approach commits")
	_check(
		contract.confirm_atmospheric_entry(false, _observation(), 7).reason
			== &"atmospheric_entry_prerequisites_not_met",
		"entry requires an authority-owned completion fact",
	)
	_check(contract.confirm_atmospheric_entry(true, _observation(), 7).accepted, "entry commits")
	_check(
		contract.confirm_descent(true, &"foreign_region", true, _observation(), 7).reason
			== &"descent_prerequisites_not_met",
		"descent rejects a foreign landing region",
	)
	_check(contract.confirm_descent(true, &"aurora_landing", true, _observation(), 7).accepted, "descent commits")
	_check(
		contract.confirm_landing(true, &"aurora_landing", true, false, 7).reason
			== &"landing_prerequisites_not_met",
		"landing requires stable supported ship state",
	)
	_check(contract.confirm_landing(true, &"aurora_landing", true, true, 7).accepted, "landing commits")
	_check(contract.confirm_on_foot(true, true, 7).accepted, "on-foot route commits")
	_check(contract.confirm_reboarded(true, true, 7).accepted, "reboarding commits")
	_check(
		contract.confirm_takeoff(true, true, 7).reason == &"takeoff_prerequisites_not_met",
		"takeoff cannot claim clearance while still landed",
	)
	_check(contract.confirm_takeoff(true, false, 7).accepted, "takeoff commits")
	_check(contract.confirm_ascent(true, _observation(), 7).accepted, "surface clearance commits ascent")
	_check(contract.confirm_orbit(false, _observation(), 7).reason == &"orbit_prerequisites_not_met", "orbit requires achieved orbit")
	_check(contract.confirm_orbit(true, _observation(), 7).accepted, "orbit commits")
	_check(
		contract.confirm_return_approach(true, &"wrong_station", _observation(), 7).reason
			== &"return_approach_prerequisites_not_met",
		"return rejects an unknown station target",
	)
	_check(contract.confirm_return_approach(true, &"mudds_shipyards", _observation(), 7).accepted, "return corridor commits")
	_check(contract.confirm_return(false, &"mudds_shipyards", 7).reason == &"return_prerequisites_not_met", "station handoff is required")
	_check(contract.confirm_return(true, &"mudds_shipyards", 7).accepted, "station return completes")
	_check(contract.get_phase_id() == &"completed", "completed loop has explicit terminal phase")
	_check(contract.confirm_orbit_approach(true, _observation(), 7).reason == &"terminal_state", "completed loop rejects a second approach")
	_check(contract.confirm_return(true, &"mudds_shipyards", 6).reason == &"terminal_state", "completed loop rejects stale terminal retries")
	var audit := contract.audit()
	_check(bool(audit.valid) and bool(audit.terminal), "audit exposes valid terminal lifecycle")
	_check(audit.authority.movement == false and audit.authority.game_flow == false and audit.authority.save == false, "contract owns no production authority")

	_test_airless_entry_skip()
	_finish()


func _test_airless_entry_skip() -> void:
	var contract := ContractScript.new(&"ember_moon", &"ember_caldera", &"mudds_shipyards", false)
	_check(contract.begin(1).accepted, "airless visit begins")
	_check(contract.confirm_orbit_approach(true, _observation(), 1).accepted, "airless approach skips entry")
	_check(contract.get_phase_id() == &"descent", "airless branch exposes descent directly")
	_check(contract.confirm_atmospheric_entry(true, _observation(), 1).reason == &"out_of_order", "airless branch rejects atmospheric entry")


func _observation() -> Dictionary:
	return {"position": Vector3(0.0, 220_000.0, 0.0), "speed_meters_per_second": 300.0}


func _check(condition: bool, label: String) -> void:
	_assertions += 1
	if not condition:
		_failures.append(label)


func _finish() -> void:
	if _failures.is_empty():
		print("PLANETARY_ORBIT_SURFACE_LOOP_CONTRACT_TEST_OK: %d assertions" % _assertions)
		quit(0)
	else:
		printerr("PLANETARY_ORBIT_SURFACE_LOOP_CONTRACT_TEST_FAIL: " + "; ".join(_failures))
		quit(1)
