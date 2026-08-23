extends SceneTree

const STANDOFF_SCENE := preload("res://scenes/ships/standoff_picket_opponent.tscn")
const BULWARK_SCENE := preload("res://scenes/ships/bulwark_heavy_gunship.tscn")

var _assertions := 0
var _failures := PackedStringArray()

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var host := Node3D.new()
	root.add_child(host)
	var standoff := STANDOFF_SCENE.instantiate()
	var bulwark := BULWARK_SCENE.instantiate()
	host.add_child(standoff)
	host.add_child(bulwark)
	await process_frame
	var standoff_binding: RefCounted = standoff.get_siege_lance_audio_binding()
	var bulwark_binding: RefCounted = bulwark.get_siege_lance_audio_binding()
	_check(standoff_binding != null and bool(standoff_binding.get_snapshot().attached), "Standoff production node composes an attached SiegeLance binding")
	_check(bulwark_binding != null and bool(bulwark_binding.get_snapshot().attached), "Bulwark production node composes an attached SiegeLance binding")
	_check(int(standoff_binding.get_snapshot().maximum_simultaneous_voices) == 2 and int(bulwark_binding.get_snapshot().maximum_simultaneous_voices) == 2, "both production bindings preserve the two-voice ceiling")
	var standoff_cues: Array[StringName] = []
	var bulwark_cues: Array[StringName] = []
	standoff_binding.semantic_weapon_cue_emitted.connect(func(cue_id: StringName, _transaction: StringName, _intensity: float) -> void: standoff_cues.append(cue_id))
	bulwark_binding.semantic_weapon_cue_emitted.connect(func(cue_id: StringName, _transaction: StringName, _intensity: float) -> void: bulwark_cues.append(cue_id))
	var record := {"generation": 0, "sequence": 1, "transaction_id": &"production_lance_1", "weapon_id": &"picket_siege_lance", "event_id": &"charge_started", "accepted": true}
	standoff.siege_lance_audio_record.emit(record)
	bulwark.siege_lance_audio_record.emit(record)
	_check(standoff_cues == [&"siege_lance_charge"] and bulwark_cues == [&"siege_lance_charge"], "real Standoff and Bulwark signals reach their audio bindings")
	_check(standoff_binding.present_record(record).get("reason", &"") == &"duplicate_record" and bulwark_binding.present_record(record).get("reason", &"") == &"duplicate_record", "production bindings deduplicate replayed weapon records")
	standoff_binding.set_reduced_dynamic_range(true)
	bulwark_binding.set_reduced_dynamic_range(true)
	_check(bool(standoff_binding.reset_for_reuse().get("accepted", false)) and bool(bulwark_binding.reset_for_reuse().get("accepted", false)), "production bindings reset their attached reuse lifecycle")
	var standoff_reset: Dictionary = standoff_binding.get_snapshot()
	var bulwark_reset: Dictionary = bulwark_binding.get_snapshot()
	_check(int(standoff_reset.generation) == 1 and int(bulwark_reset.generation) == 1 and bool(standoff_reset.attached) and bool(bulwark_reset.attached), "production reuse advances generation without disconnecting weapon sources")
	_check((standoff_reset.active_cue_slots as Array).is_empty() and (bulwark_reset.active_cue_slots as Array).is_empty() and bool(standoff_reset.reduced_dynamic_range) and bool(bulwark_reset.reduced_dynamic_range), "production reuse clears owned voices and preserves configured mix resources")
	_check(standoff_binding.present_record(record).get("reason", &"") == &"stale_generation" and bulwark_binding.present_record(record).get("reason", &"") == &"stale_generation", "production reuse fences pre-reset weapon records")
	var reused_record := record.duplicate(true)
	reused_record.generation = 1
	standoff.siege_lance_audio_record.emit(reused_record)
	bulwark.siege_lance_audio_record.emit(reused_record)
	_check(standoff_cues.size() == 2 and bulwark_cues.size() == 2, "production sources remain connected after reuse and accept the new generation")
	var old_standoff := standoff_binding
	var old_bulwark := bulwark_binding
	host.remove_child(standoff)
	host.remove_child(bulwark)
	await process_frame
	_check(not bool(old_standoff.get_snapshot().attached) and not bool(old_bulwark.get_snapshot().attached), "production detach clears both weapon audio lifecycles")
	host.add_child(standoff)
	host.add_child(bulwark)
	await process_frame
	var reentered_standoff: RefCounted = standoff.get_siege_lance_audio_binding()
	var reentered_bulwark: RefCounted = bulwark.get_siege_lance_audio_binding()
	_check(bool(reentered_standoff.get_snapshot().attached) and bool(reentered_bulwark.get_snapshot().attached), "production re-entry creates fresh attached bindings")
	_check(reentered_standoff.present_record(reused_record).get("reason", &"") == &"stale_generation" and reentered_bulwark.present_record(reused_record).get("reason", &"") == &"stale_generation", "pre-detach records cannot replay after re-entry")
	host.queue_free()
	await process_frame
	if _failures.is_empty():
		print("SIEGE_LANCE_PRODUCTION_AUDIO_TEST_OK: %d assertions" % _assertions)
		quit(0)
	for failure in _failures:
		push_error(failure)
	quit(1)

func _check(condition: bool, message: String) -> void:
	_assertions += 1
	if not condition:
		_failures.append(message)
