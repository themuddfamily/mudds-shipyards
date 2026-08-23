extends SceneTree

const BindingScene := preload("res://scripts/world/fleet_expansion_production_binding.gd")

var _assertions := 0
var _failures := PackedStringArray()


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var fleet := BindingScene.new()
	root.add_child(fleet)
	await process_frame
	await process_frame
	var snapshot: Dictionary = fleet.get_fleet_snapshot()
	_check(bool(snapshot.built), "fleet production composition builds")
	var crafts := snapshot.craft as Array
	_check(crafts.size() == 3, "three fleet expansion craft remain composed")
	for craft: Dictionary in crafts:
		var audio := craft.audio as Dictionary
		_check(bool(audio.attached), "%s receives an audio recipe binding" % craft.craft_id)
		_check((audio.authority as Dictionary).flight == false, "%s audio binding owns no flight authority" % craft.craft_id)
	_check(bool(fleet.set_reduced_dynamic_range(true).accepted), "fleet forwards reduced-range policy")
	var reduced: Dictionary = fleet.get_fleet_snapshot()
	var all_reduced := true
	for craft: Dictionary in reduced.craft as Array:
		all_reduced = all_reduced and bool((craft.audio as Dictionary).reduced_dynamic_range)
	_check(all_reduced, "reduced-range policy reaches every fleet audio binding")
	_check(bool(fleet.detach_craft(&"cinder_light_interceptor").accepted), "craft detach releases audio binding")
	_check(bool(fleet.reattach_craft(&"cinder_light_interceptor").accepted), "craft reattach restores audio binding")
	var audit := fleet.get_audit_report()
	_check(bool(audit.valid), "fleet audio composition remains auditable after reuse")
	fleet.queue_free()
	for failure in _failures:
		push_error(failure)
	print("fleet_expansion_production_audio_integration_test: %d assertions" % _assertions)
	quit(0 if _failures.is_empty() else 1)


func _check(condition: bool, message: String) -> void:
	_assertions += 1
	if not condition:
		_failures.append(message)
