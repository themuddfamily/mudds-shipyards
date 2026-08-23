extends SceneTree

const BINDING := preload("res://scripts/audio/settlement_interaction_audio_binding.gd")
const SCENE := preload("res://scenes/world/planets/aurora_temperate_world.tscn")

var _assertions := 0
var _failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var world := SCENE.instantiate()
	root.add_child(world)
	await process_frame
	_check(bool(world.get_settlement_audio_snapshot().get("attached", false)), "Aurora composes settlement interaction audio")
	var enter := {"generation": 1, "interaction_id": &"structure:aurora_terminal:enter", "interaction_kind": &"terminal", "event_id": &"success", "accepted": true, "runtime": {"attachment_generation": 1}}
	var denied := {"generation": 1, "interaction_id": &"structure:aurora_airlock:enter", "interaction_kind": &"airlock", "event_id": &"denied", "accepted": true, "runtime": {"attachment_generation": 1}}
	var reset := {"generation": 1, "interaction_id": &"structure:aurora_door:reset", "interaction_kind": &"door", "event_id": &"reset", "accepted": true, "runtime": {"attachment_generation": 1}}
	_check(bool(world.present_settlement_interaction_audio_receipt(enter).get("accepted", false)), "terminal success emits")
	_check(bool(world.present_settlement_interaction_audio_receipt(denied).get("accepted", false)), "airlock denied emits")
	_check(bool(world.present_settlement_interaction_audio_receipt(reset).get("accepted", false)), "door reset emits")
	_check(world.present_settlement_interaction_audio_receipt(reset).get("reason", &"") == &"duplicate_receipt", "settlement receipt deduplicates")
	_check(bool(world.set_settlement_audio_perspective(&"cockpit").get("accepted", false)), "perspective is caller-driven")
	_check(bool(world.set_surface_audio_reduced_dynamic_range(true).get("accepted", false)), "owner retains reduced-range policy seam")
	var binding := BINDING.new()
	_check(bool(binding.attach().get("accepted", false)), "standalone settlement binding attaches")
	_check(int(binding.get_snapshot().get("maximum_simultaneous_voices", 0)) == 2, "settlement audio keeps two voices")
	_check(bool(binding.detach().get("accepted", false)), "detach clears settlement lifecycle")
	_check(binding.present_receipt(enter).get("reason", &"") == &"not_attached", "detached binding rejects stale settlement receipt")
	world.queue_free()
	await process_frame
	if _failures.is_empty():
		print("PASS settlement_interaction_audio_binding_test (%d assertions)" % _assertions)
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)

func _check(condition: bool, message: String) -> void:
	_assertions += 1
	if not condition:
		_failures.append(message)
