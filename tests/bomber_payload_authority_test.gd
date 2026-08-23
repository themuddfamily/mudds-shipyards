extends SceneTree

## Focused contract test for the reusable bomber payload admission seam. It
## does not instantiate a bomber, scene, physics world, combat resolver, or
## presentation/audio consumer.

const Authority := preload("res://scripts/combat/bomber_payload_authority.gd")

var _assertions := 0
var _failures := PackedStringArray()


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var authority = Authority.new(7, 2, 1.0)
	_check(authority.is_configuration_valid(), "the bounded payload envelope validates")
	var contract: Dictionary = authority.get_snapshot().get("authority", {}) as Dictionary
	_check(
		bool(contract.server_admission)
			and contract.raycast == false
			and contract.movement == false
			and contract.damage == false
			and contract.visual_spawn == false
			and contract.audio_playback == false
			and contract.score == false,
		"the component owns admission only and no runtime side effect authority"
	)
	_check(authority.begin_generation(0).reason == &"invalid_generation", "zero generation is rejected")
	_check(bool(authority.begin_generation(1).accepted), "the first lifecycle generation starts")
	_check(authority.begin_generation(1).reason == &"stale_generation", "a duplicate generation cannot refill ammo")
	_check(authority.begin_generation(2).reason == &"authority_active", "an active generation cannot be replaced implicitly")

	var malformed := _payload(1, 1)
	malformed["unexpected"] = true
	_check(authority.submit_release_intent(7, &"gunner", malformed, 1).reason == &"invalid_payload", "extra fields fail closed")
	_check(authority.submit_release_intent(8, &"gunner", _payload(1, 1), 1).reason == &"unauthorized_source", "a non-server caller cannot admit a release")
	var nonfinite := _payload(1, 1)
	nonfinite.release_velocity = Vector3(INF, 0.0, 0.0)
	_check(authority.submit_release_intent(7, &"gunner", nonfinite, 1).reason == &"invalid_release_vector", "non-finite release velocity is rejected")

	var accepted := authority.submit_release_intent(7, &"gunner", _payload(1, 1), 1)
	var record: Dictionary = accepted.get("record", {})
	_check(
		bool(accepted.accepted)
			and accepted.reason == &"payload_release_accepted"
			and record.generation == 1
			and record.request_sequence == 1
			and record.payload_id == &"cinder_payload_alpha"
			and record.weapon_id == &"bomber_payload_release"
			and record.presentation_id == &"payload_release_flash"
			and record.audio_id == &"payload_release_audio"
			and record.release_position == Vector3(2.0, 3.0, 4.0)
			and record.release_velocity == Vector3(0.0, 0.0, -40.0)
			and authority.get_snapshot().ammunition_remaining == 1,
		"a valid intent returns one detached, fully identified release record"
	)
	record.payload_id = &"caller_mutation"
	_check(authority.get_release_records()[0].payload_id == &"cinder_payload_alpha", "accepted records cannot be mutated through the returned copy")
	_check(authority.submit_release_intent(7, &"gunner", _payload(1, 2), 2).reason == &"cooldown", "release cadence is bounded")
	_check(authority.advance(-0.1).reason == &"invalid_delta", "negative owner deltas are rejected")
	_check(bool(authority.advance(1.0).accepted), "the caller advances cooldown explicitly")
	_check(bool(authority.submit_release_intent(7, &"gunner", _payload(1, 2), 2).accepted), "a newer sequence can release after cooldown")
	_check(authority.advance(1.0).accepted, "the second release cooldown can be advanced")
	_check(authority.submit_release_intent(7, &"gunner", _payload(1, 3), 3).reason == &"ammunition_exhausted", "ammunition exhaustion fails closed")
	_check(authority.submit_release_intent(7, &"gunner", _payload(1, 2), 2).reason == &"stale_request_sequence", "a replayed actor sequence is rejected")
	_check(authority.get_release_records().size() == 2, "only accepted releases are retained")

	var detached := authority.detach(&"seat_lost")
	_check(bool(detached.accepted) and detached.reason == &"detached", "detach closes the active lifecycle")
	_check(
		not bool(authority.get_snapshot().active)
			and authority.get_snapshot().release_records.is_empty()
			and authority.get_snapshot().ammunition_remaining == 0
			and authority.submit_release_intent(7, &"gunner", _payload(1, 1), 1).reason == &"authority_detached",
		"detach clears records, ammo, cooldown state, and old admission"
	)
	_check(authority.reset_for_reuse(1).reason == &"stale_generation", "re-entry cannot reuse the detached generation")
	var reentered := authority.reset_for_reuse(2)
	_check(
		bool(reentered.accepted)
			and reentered.reason == &"reentered"
			and authority.get_snapshot().ammunition_remaining == 2,
		"a newer generation re-enters with a fresh bounded budget"
	)
	_check(authority.submit_release_intent(7, &"gunner", _payload(1, 1), 1).reason == &"stale_generation", "an old generation cannot release after re-entry")
	_check(bool(authority.submit_release_intent(7, &"gunner", _payload(2, 1), 1).accepted), "the new generation starts its own sequence fence")
	_finish()


func _payload(generation: int, sequence: int) -> Dictionary:
	return {
		"generation": generation,
		"payload_id": &"cinder_payload_alpha",
		"weapon_id": &"bomber_payload_release",
		"presentation_id": &"payload_release_flash",
		"audio_id": &"payload_release_audio",
		"release_position": Vector3(2.0, 3.0, 4.0),
		"release_velocity": Vector3(0.0, 0.0, -40.0),
	}


func _check(condition: bool, message: String) -> void:
	_assertions += 1
	if not condition:
		_failures.append(message)


func _finish() -> void:
	if _failures.is_empty():
		print("PASS: bomber payload authority (", _assertions, " assertions)")
		quit(0)
	else:
		for failure in _failures:
			push_error("FAIL: " + failure)
		quit(1)
