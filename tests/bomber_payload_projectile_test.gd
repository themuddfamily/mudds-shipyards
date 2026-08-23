extends SceneTree

## Focused regression for the detached bomber payload projectile authority. No
## world, raycast, damage, score, presentation, audio, or ship node is used.

const Projectile := preload("res://scripts/combat/bomber_payload_projectile.gd")

var _assertions := 0
var _failures := PackedStringArray()


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var projectile = Projectile.new(9, Vector3(0.0, -10.0, 0.0), 1.0, 100.0, 100.0)
	_check(projectile.is_configuration_valid(), "the finite ballistic envelope validates")
	var authority: Dictionary = projectile.get_snapshot().get("authority", {}) as Dictionary
	_check(
		bool(authority.server_admission)
			and bool(authority.projectile_motion)
			and authority.ship_movement == false
			and authority.raycast == false
			and authority.damage == false
			and authority.visual_spawn == false
			and authority.audio_playback == false
			and authority.score == false,
		"the component owns bounded projectile motion but no world or gameplay side effects"
	)
	_check(projectile.consume_release_record(9, _release(1, 1)).reason == &"authority_detached", "a release cannot be consumed before lifecycle admission")
	_check(bool(projectile.begin_generation(1).accepted), "the projectile generation starts explicitly")
	_check(projectile.begin_generation(1).reason == &"stale_generation", "a duplicate generation cannot reset an active projectile")
	_check(projectile.consume_release_record(8, _release(1, 1)).reason == &"unauthorized_source", "only the configured server can consume a release")
	_check(projectile.consume_release_record(9, _release(2, 1)).reason == &"stale_generation", "a release from another generation is rejected")

	var consumed := projectile.consume_release_record(9, _release(1, 1))
	_check(
		bool(consumed.accepted)
			and consumed.reason == &"release_consumed"
			and projectile.get_snapshot().state == &"flying"
			and projectile.get_snapshot().position == Vector3.ZERO
			and projectile.get_snapshot().velocity == Vector3(0.0, 10.0, 0.0),
		"one accepted release starts a detached ballistic state"
	)
	_check(projectile.consume_release_record(9, _release(1, 1)).reason == &"duplicate_release", "the same release record cannot spawn twice")
	_check(projectile.consume_release_record(9, _release(1, 2)).reason == &"projectile_active", "a live projectile cannot consume a second release")

	var advanced := projectile.advance(0.5)
	var snapshot: Dictionary = advanced.get("projectile", {}) as Dictionary
	_check(
		bool(advanced.accepted)
			and advanced.reason == &"advanced"
			and is_equal_approx(float(snapshot.position.y), 3.75)
			and is_equal_approx(float(snapshot.velocity.y), 5.0)
			and is_equal_approx(float(snapshot.remaining_lifetime), 0.5),
		"caller physics advances position, gravity, and lifetime deterministically"
	)
	_check(projectile.advance(-0.1).reason == &"invalid_delta", "negative physics time is rejected")
	var impact := projectile.submit_impact(9, Vector3(0.0, 3.0, 0.0), Vector3.UP, &"target_a", 4)
	var impact_intent: Dictionary = impact.get("terminal_intent", {}) as Dictionary
	_check(
		bool(impact.accepted)
			and impact.reason == &"terminal_intent"
			and impact_intent.kind == &"impact"
			and impact_intent.target_id == &"target_a"
			and impact_intent.target_generation == 4
			and bool(impact_intent.resolver_ready),
		"caller collision evidence produces one resolver-ready impact intent"
	)
	_check(projectile.submit_impact(9, Vector3.ZERO, Vector3.UP).reason == &"terminal_already_emitted", "a terminal impact cannot be emitted twice")
	_check(projectile.advance(1.0).reason == &"terminal_already_emitted", "a terminal projectile cannot advance or emit a second intent")
	impact_intent.target_id = &"caller_mutation"
	_check(projectile.get_terminal_intent().target_id == &"target_a", "terminal intent snapshots are detached from caller mutation")

	var expiring = Projectile.new(9, Vector3.ZERO, 1.0, 100.0, 100.0)
	expiring.begin_generation(1)
	expiring.consume_release_record(9, _release(1, 7))
	var hitch := expiring.advance(99.0)
	var expiry_intent: Dictionary = hitch.get("terminal_intent", {}) as Dictionary
	_check(
		bool(hitch.accepted)
			and hitch.reason == &"terminal_intent"
			and expiry_intent.kind == &"expiry"
			and expiry_intent.expiry_reason == &"lifetime"
			and is_equal_approx(float(expiry_intent.position.y), 10.0),
		"a hitch larger than lifetime clamps motion and emits one expiry intent"
	)
	_check(expiring.advance(99.0).reason == &"terminal_already_emitted", "hitch expiry is exactly once")
	_check(bool(expiring.detach(&"pool_return").accepted), "detach clears the terminal lifecycle")
	_check(expiring.reset_for_reuse(1).reason == &"stale_generation", "re-entry cannot reuse the detached generation")
	_check(bool(expiring.reset_for_reuse(2).accepted), "a newer generation re-enters the projectile authority")
	_check(expiring.consume_release_record(9, _release(1, 7)).reason == &"stale_generation", "old release generation cannot re-enter")
	_check(bool(expiring.consume_release_record(9, _release(2, 1)).accepted), "the new generation accepts a fresh release sequence")
	_check(expiring.detach(&"done").accepted, "the fresh projectile can detach cleanly")
	_finish()


func _release(generation: int, request_sequence: int) -> Dictionary:
	return {
		"schema_version": 1,
		"record_id": "bomber_payload_release_%06d" % request_sequence,
		"release_sequence": request_sequence,
		"generation": generation,
		"actor_id": &"bomber_gunner",
		"request_sequence": request_sequence,
		"payload_id": &"cinder_payload_alpha",
		"weapon_id": &"bomber_payload_release",
		"presentation_id": &"payload_release_flash",
		"audio_id": &"payload_release_audio",
		"release_position": Vector3.ZERO,
		"release_velocity": Vector3(0.0, 10.0, 0.0),
		"ammunition_remaining": 3,
		"cooldown_remaining": 1.0,
	}


func _check(condition: bool, message: String) -> void:
	_assertions += 1
	if not condition:
		_failures.append(message)


func _finish() -> void:
	if _failures.is_empty():
		print("PASS: bomber payload projectile (", _assertions, " assertions)")
		quit(0)
	else:
		for failure in _failures:
			push_error("FAIL: " + failure)
		quit(1)
