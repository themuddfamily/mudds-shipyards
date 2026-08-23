extends SceneTree

const BINDING := preload("res://scripts/audio/water_contact_audio_binding.gd")
const SCENE := preload("res://scenes/world/planets/aurora_temperate_world.tscn")

var _assertions := 0
var _failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var world := SCENE.instantiate()
	root.add_child(world)
	await process_frame
	_check(bool(world.get_water_contact_audio_snapshot().get("attached", false)), "Aurora composes water-contact audio")
	var enter := {"generation": 1, "sequence": 1, "event_id": &"enter", "accepted": true, "runtime": {"attachment_generation": 1}}
	var sample := {"generation": 1, "sequence": 2, "event_id": &"sample", "accepted": true, "drag_request": {"unitless": 0.8}, "runtime": {"attachment_generation": 1}}
	var exit := {"generation": 1, "sequence": 3, "event_id": &"exit", "accepted": true, "runtime": {"attachment_generation": 1}}
	_check(bool(world.present_water_contact_audio_receipt(enter).get("accepted", false)), "enter receipt emits splash")
	_check(bool(world.present_water_contact_audio_receipt(sample).get("accepted", false)), "sample receipt emits wake/drag")
	_check(bool(world.present_water_contact_audio_receipt(exit).get("accepted", false)), "exit receipt emits dry cue")
	_check(world.present_water_contact_audio_receipt(sample).get("reason", &"") == &"duplicate_receipt", "duplicate contact receipt is deduplicated")
	_check(bool(world.set_water_contact_audio_perspective(&"cockpit").get("accepted", false)), "perspective remains caller-driven")
	var binding := BINDING.new()
	_check(bool(binding.attach().get("accepted", false)), "standalone contact binding attaches")
	_check(bool(binding.set_reduced_dynamic_range(true).get("accepted", false)), "reduced range remains caller-driven")
	_check(int(binding.get_snapshot().get("maximum_simultaneous_voices", 0)) == 2, "water audio keeps two voices")
	_check(bool(binding.detach().get("accepted", false)), "detach clears contact lifecycle")
	_check(binding.present_receipt(enter).get("reason", &"") == &"not_attached", "detached binding rejects stale contact")
	world.queue_free()
	await process_frame
	if _failures.is_empty():
		print("PASS water_contact_audio_binding_test (%d assertions)" % _assertions)
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)

func _check(condition: bool, message: String) -> void:
	_assertions += 1
	if not condition:
		_failures.append(message)
