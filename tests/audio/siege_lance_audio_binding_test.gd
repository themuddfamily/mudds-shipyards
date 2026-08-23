extends SceneTree

const BINDING := preload("res://scripts/audio/siege_lance_audio_binding.gd")

var _assertions := 0
var _failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var binding := BINDING.new()
	_check(bool(binding.attach().get("accepted", false)), "siege-lance audio binding attaches")
	var cues: Array[StringName] = []
	binding.semantic_weapon_cue_emitted.connect(func(cue_id: StringName, _transaction_id: StringName, _intensity: float): cues.append(cue_id))
	for event_id: StringName in [&"charge_started", &"dispatch", &"impact", &"aborted"]:
		var record := {"generation": 0, "sequence": cues.size(), "transaction_id": StringName("lance_%s" % event_id), "weapon_id": &"picket_siege_lance", "event_id": event_id, "accepted": true}
		_check(bool(binding.present_record(record).get("accepted", false)), "exact %s record emits" % event_id)
	_check(cues.size() == 4, "charge, dispatch, impact, and abort each emit once")
	var duplicate := {"generation": 0, "sequence": 0, "transaction_id": &"lance_charge_started", "weapon_id": &"picket_siege_lance", "event_id": &"charge_started", "accepted": true}
	_check(binding.present_record(duplicate).get("reason", &"") == &"duplicate_record", "duplicate weapon record is deduplicated")
	_check(binding.present_record({"generation": 0, "sequence": 5, "transaction_id": &"foreign", "weapon_id": &"other_weapon", "event_id": &"impact", "accepted": true}).get("reason", &"") == &"invalid_weapon_record", "foreign weapon record fails closed")
	binding.set_reduced_dynamic_range(true)
	var reset := binding.reset_for_reuse()
	var reset_snapshot: Dictionary = binding.get_snapshot()
	_check(bool(reset.get("accepted", false)) and int(reset.get("generation", -1)) == 1, "reuse reset advances the presentation generation")
	_check(bool(reset_snapshot.get("attached", false)) and (reset_snapshot.get("active_cue_slots", []) as Array).is_empty() and reset_snapshot.get("last_cue_id", &"_") == &"", "reuse reset stops only the binding-owned active cues without detaching")
	_check(bool(reset_snapshot.get("reduced_dynamic_range", false)), "reuse reset preserves configured mix resources")
	_check(binding.present_record({"generation": 0, "sequence": 6, "transaction_id": &"old_generation", "weapon_id": &"picket_siege_lance", "event_id": &"impact", "accepted": true}).get("reason", &"") == &"stale_generation", "reuse reset fences records from the old generation")
	var reused_intensities: Array[float] = []
	binding.semantic_weapon_cue_emitted.connect(func(_cue_id: StringName, transaction_id: StringName, intensity: float):
		if transaction_id == &"lance_charge_started":
			reused_intensities.append(intensity)
	)
	_check(bool(binding.present_record({"generation": 1, "sequence": 0, "transaction_id": &"lance_charge_started", "weapon_id": &"picket_siege_lance", "event_id": &"charge_started", "accepted": true}).get("accepted", false)) and reused_intensities == [0.75], "new-generation events can reuse transaction identities with preserved mix configuration")
	_check(bool(binding.detach().get("accepted", false)), "detach clears weapon presentation lifecycle")
	_check(binding.present_record(duplicate).get("reason", &"") == &"not_attached", "detached binding rejects stale records")
	_check(binding.reset_for_reuse().get("reason", &"") == &"not_attached", "detached binding cannot reset into an attached lifecycle")
	_check(bool(binding.attach(null, 2).get("accepted", false)), "detached binding cleanly re-enters at its fenced generation")
	_check(binding.present_record({"generation": 1, "sequence": 1, "transaction_id": &"detached_generation", "weapon_id": &"picket_siege_lance", "event_id": &"impact", "accepted": true}).get("reason", &"") == &"stale_generation", "detach and re-entry retain the generation fence")
	_check(int(binding.get_snapshot().get("maximum_simultaneous_voices", 0)) == 2, "siege-lance voice ceiling remains two")
	if _failures.is_empty():
		print("PASS siege_lance_audio_binding_test (%d assertions)" % _assertions)
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)

func _check(condition: bool, message: String) -> void:
	_assertions += 1
	if not condition:
		_failures.append(message)
