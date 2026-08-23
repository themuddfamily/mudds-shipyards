extends SceneTree

class FakeHost:
	extends RefCounted
	var snapshot: Dictionary = {"attached": true, "generation": 4, "attachment_generation": 2, "phase_id": &"descent", "distance_meters": 120.0, "speed_meters_per_second": 8.0}
	func get_snapshot() -> Dictionary: return snapshot.duplicate(true)

const ProductionType := preload("res://scripts/world/ember_surface_loop_production_binding.gd")
const HostType := preload("res://scripts/world/ember_surface_loop_host.gd")
const BindingType := preload("res://scripts/ui/ember_surface_return_status_binding.gd")
var _assertions := 0
var _failures: PackedStringArray = []

func _init() -> void:
	call_deferred(&"_run")

func _run() -> void:
	var production := ProductionType.new()
	var host := FakeHost.new()
	root.add_child(production)
	await process_frame
	var binding = BindingType.new()
	_check(bool(binding.attach(production, host, null, true).get("accepted", false)), "binding attaches real Ember production source and detached host")
	production.state_changed.emit({})
	var initial := binding.get_presenter_snapshot()
	_check(initial.state == &"descent" and initial.text.contains("TRANSITION  //  STATIC"), "descent snapshot is readable and reduced-motion safe")
	host.snapshot = {"attached": true, "generation": 5, "attachment_generation": 2, "phase_id": &"landed"}
	production.state_changed.emit({})
	_check(binding.get_presenter_snapshot().state == &"landed", "host landed phase reaches presenter")
	var manifest := binding.apply_return_manifest_receipt({"accepted": true, "reason": &"return_manifest_ready", "manifest": {"destination_id": &"mudds_shipyards"}}, true)
	_check(bool(manifest.get("accepted", false)) and binding.get_presenter_snapshot().state == &"return_manifest", "return manifest receipt presents bounded return state")
	host.snapshot = {"attached": true, "generation": 4, "attachment_generation": 2, "phase_id": &"on_foot"}
	production.state_changed.emit({})
	_check(binding.get_presenter_snapshot().state == &"return_manifest", "stale host generation cannot overwrite view")
	binding.detach()
	host.snapshot = {"attached": false, "generation": 6, "attachment_generation": 3, "phase_id": &"on_foot"}
	production.state_changed.emit({})
	_check(not bool(binding.get_snapshot().attached), "detach fences future source updates")
	host.snapshot = {"attached": true, "generation": 7, "attachment_generation": 4, "phase_id": &"orbit_return"}
	_check(bool(binding.attach(production, host, null, false).get("accepted", false)), "re-entry binds a fresh production generation")
	_check(binding.get_presenter_snapshot().state == &"orbit_return", "re-entry presents fresh orbit return state")
	binding.detach()
	production.queue_free()
	await process_frame
	if _failures.is_empty():
		print("EMBER_SURFACE_RETURN_STATUS_BINDING_TEST_OK (%d assertions)" % _assertions)
		quit(0)
		return
	for failure in _failures: push_error(failure)
	quit(1)

func _check(condition: bool, message: String) -> void:
	_assertions += 1
	if not condition: _failures.append("FAIL: " + message)
