extends SceneTree

class FakeHost:
	extends RefCounted
	var snapshot: Dictionary = {"attached": true, "generation": 4, "attachment_generation": 2, "phase_id": &"descent"}
	func get_snapshot() -> Dictionary: return snapshot.duplicate(true)

const ProductionType := preload("res://scripts/world/ember_surface_loop_production_binding.gd")
const BindingType := preload("res://scripts/ui/ember_surface_return_status_binding.gd")
const AdapterType := preload("res://scripts/ui/ember_surface_return_hud_adapter.gd")
const HudType := preload("res://scripts/ui/hud.gd")
var _assertions := 0
var _failures: PackedStringArray = []

func _init() -> void:
	call_deferred(&"_run")

func _run() -> void:
	var production := ProductionType.new()
	var host := FakeHost.new()
	var hud := HudType.new()
	root.add_child(hud)
	await process_frame
	await process_frame
	root.add_child(production)
	await process_frame
	var binding := BindingType.new()
	_check(bool(binding.attach(production, host, null, true).get("accepted", false)), "real Ember binding attaches before HUD adapter")
	var adapter := AdapterType.new()
	_check(bool(adapter.attach(binding, hud).get("accepted", false)), "adapter attaches to existing HUD route seam")
	var detail := hud.get("_runtime_status_detail") as Label
	_check(detail != null and detail.text.contains("NEXT // EMBER RETURN // DESCENT") and str(adapter.get_snapshot().surface_route.message).contains("TRANSITION  //  STATIC"), "descent state is readable in surface route HUD")
	host.snapshot = {"attached": true, "generation": 5, "attachment_generation": 2, "phase_id": &"landed"}
	production.state_changed.emit({})
	_check(detail.text.contains("NEXT // EMBER RETURN // LANDED"), "landed state updates the existing HUD row")
	var before_stale := detail.text
	host.snapshot = {"attached": true, "generation": 4, "attachment_generation": 2, "phase_id": &"on_foot"}
	production.state_changed.emit({})
	_check(detail.text == before_stale, "stale return generation cannot overwrite HUD")
	adapter.detach()
	host.snapshot = {"attached": true, "generation": 6, "attachment_generation": 3, "phase_id": &"orbit_return"}
	production.state_changed.emit({})
	_check(detail.text == before_stale and not bool(adapter.get_snapshot().attached), "detached adapter ignores source updates")
	_check(bool(adapter.attach(binding, hud).get("accepted", false)), "adapter re-entry reconnects to binding")
	_check(detail.text.contains("NEXT // EMBER RETURN // ORBIT RETURN"), "re-entry applies current detached presenter view")
	adapter.detach()
	binding.detach()
	production.queue_free()
	hud.queue_free()
	await process_frame
	if _failures.is_empty():
		print("EMBER_SURFACE_RETURN_HUD_ADAPTER_TEST_OK (%d assertions)" % _assertions)
		quit(0)
		return
	for failure in _failures: push_error(failure)
	quit(1)

func _check(condition: bool, message: String) -> void:
	_assertions += 1
	if not condition: _failures.append("FAIL: " + message)
