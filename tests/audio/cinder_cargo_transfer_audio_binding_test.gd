extends SceneTree

const BINDING := preload("res://scripts/audio/cinder_cargo_transfer_audio_binding.gd")
const BRIDGE := preload("res://scripts/ships/cinder_cargo_activity_bridge.gd")

var _assertions := 0
var _failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var binding := BINDING.new()
	var bridge := BRIDGE.new()
	_check(bridge.present_audio_receipt({}).get("reason", &"") == &"audio_binding_unavailable", "bridge exposes the audio receipt seam without owning cargo")
	_check(bool(binding.attach().get("accepted", false)), "binding attaches at generation zero")
	var cues: Array[StringName] = []
	binding.semantic_activity_cue_emitted.connect(func(cue_id: StringName, _transaction_id: StringName, _intensity: float): cues.append(cue_id))
	var receipt := {"generation": 0, "transaction_id": &"cinder_run_g1", "event_id": &"pickup_accepted", "accepted": true}
	_check(bool(binding.present_transfer_receipt(receipt).get("accepted", false)), "accepted pickup receipt emits")
	_check(binding.present_transfer_receipt(receipt).get("reason", &"") == &"duplicate_receipt", "duplicate pickup receipt is deduplicated")
	for event_id: StringName in [&"destination_delivered", &"transfer_rejected", &"activity_completed", &"activity_aborted"]:
		var event_receipt := {"generation": 0, "transaction_id": StringName("tx_%s" % event_id), "event_id": event_id, "accepted": true}
		_check(bool(binding.present_transfer_receipt(event_receipt).get("accepted", false)), "receipt emits for %s" % event_id)
	_check(cues.size() == 5, "five accepted receipt types produce five cues")
	_check(int(binding.get_snapshot().get("maximum_simultaneous_voices", 0)) == 2, "voice ceiling remains two")
	_check(binding.present_transfer_receipt({"generation": 0, "transaction_id": &"bad", "event_id": &"pickup_accepted", "accepted": false}).get("reason", &"") == &"rejected_receipt", "unaccepted receipt fails closed")
	_check(bool(binding.detach().get("accepted", false)), "detach clears the presentation lifecycle")
	_check(binding.present_transfer_receipt(receipt).get("reason", &"") == &"not_attached", "detached binding rejects stale presentation")
	_check((binding.get_snapshot().get("active_cue_slots", []) as Array).is_empty(), "detach silences every transfer cue slot")
	_check(bool(binding.attach(1).get("accepted", false)), "fresh transfer generation re-attaches")
	_check(binding.present_transfer_receipt(receipt).get("reason", &"") == &"stale_generation", "completed receipt cannot replay into a fresh transfer generation")
	var restart := {"generation": 1, "transaction_id": &"cinder_run_g2", "event_id": &"pickup_accepted", "accepted": true}
	_check(bool(binding.present_transfer_receipt(restart).get("accepted", false)), "fresh transfer generation receives one restart cue")
	_check(cues.count(&"cargo_transfer_pickup_accepted") == 2, "restart cue remains bounded to its new receipt")
	binding.set("_generation", BINDING.MAX_SAFE_GENERATION)
	_check(not bool(binding.detach().get("accepted", true)), "exhausted transfer detach fails closed")
	_check((binding.get_snapshot().get("active_cue_slots", []) as Array).is_empty(), "failed transfer detach still silences cue slots")
	if _failures.is_empty():
		print("PASS cinder_cargo_transfer_audio_binding_test (%d assertions)" % _assertions)
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)

func _check(condition: bool, message: String) -> void:
	_assertions += 1
	if not condition:
		_failures.append(message)
