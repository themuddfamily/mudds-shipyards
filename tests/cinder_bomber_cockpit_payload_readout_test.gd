extends SceneTree

## Focused physical-cockpit regression for Cinder's existing payload authority.
## The test drives the real bomber and Label3D without HUD or GameFlow owners.

const Bomber := preload("res://scripts/ships/cinder_long_range_bomber.gd")

var _checks := 0
var _failures := PackedStringArray()


func _init() -> void:
	call_deferred(&"_run")


func _run() -> void:
	var bomber := Bomber.new() as CinderLongRangeBomber
	root.add_child(bomber)
	await process_frame
	await physics_frame
	var readout := bomber.find_child("FlightDataReadout", true, false) as Label3D
	_check(readout != null, "Cinder retains the physical HeroShip cockpit readout")
	if readout == null:
		_finish(bomber)
		return

	_check(
		readout.text.contains("PAYLOAD OFFLINE")
			and readout.text.contains("AMMO 0")
			and readout.text.contains("RELEASE LOCKED")
			and _excludes_cannon_language(readout.text),
		"detached payload authority presents an explicit locked cockpit state",
	)

	_check(
		bool(bomber.begin_payload_generation(1).get("accepted", false)),
		"the production payload authority begins one caller-owned generation",
	)
	await physics_frame
	_check(
		readout.text.contains("PAYLOAD READY")
			and readout.text.contains("AMMO 4")
			and readout.text.contains("RELEASE READY")
			and _excludes_cannon_language(readout.text),
		"armed Cinder shows payload ammunition and release readiness",
	)

	# Poison inherited cannon presentation state. Cinder's physical readout must
	# remain sourced only from the detached payload snapshot.
	bomber.set("_weapon_overheated", true)
	bomber.set("_weapon_heat", 1.0)
	bomber.set("_weapon_timer", 5.0)
	await physics_frame
	_check(
		readout.text.contains("PAYLOAD READY") and _excludes_cannon_language(readout.text),
		"inherited cannon heat and cooldown cannot repaint the Cinder cockpit",
	)

	var first := bomber.request_payload_release(
		1,
		&"player_pilot",
		1,
		1,
		0,
		Vector3(0.0, 0.0, -220.0),
	)
	_check(bool(first.get("accepted", false)), "one real Cinder payload release is admitted")
	await physics_frame
	_check(
		readout.text.contains("PAYLOAD COOLDOWN")
			and readout.text.contains("AMMO 3")
			and readout.text.contains("RELEASE WAIT")
			and _excludes_cannon_language(readout.text),
		"cooldown presents remaining payloads and release wait truthfully",
	)

	bomber.advance_payload_cooldown(2.0)
	await physics_frame
	_check(
		readout.text.contains("PAYLOAD READY")
			and readout.text.contains("AMMO 3")
			and readout.text.contains("RELEASE READY"),
		"authority cooldown recovery returns the cockpit to payload-ready",
	)

	for request_sequence in range(2, 5):
		var release := bomber.request_payload_release(
			1,
			&"player_pilot",
			1,
			request_sequence,
			request_sequence - 1,
			Vector3(0.0, 0.0, -220.0),
		)
		_check(
			bool(release.get("accepted", false)),
			"payload release %d consumes its authored hardpoint" % request_sequence,
		)
		if request_sequence < 4:
			bomber.advance_payload_cooldown(2.0)
	await physics_frame
	_check(
		readout.text.contains("PAYLOAD EMPTY")
			and readout.text.contains("AMMO 0")
			and readout.text.contains("RELEASE LOCKED")
			and _excludes_cannon_language(readout.text),
		"exhausted Cinder payloads take precedence over inherited weapon state",
	)

	_check(
		bool(bomber.detach_payload_authority(&"cockpit_test_complete").get("accepted", false)),
		"payload authority detaches through its existing lifecycle",
	)
	await physics_frame
	_check(
		readout.text.contains("PAYLOAD OFFLINE")
			and readout.text.contains("RELEASE LOCKED")
			and _excludes_cannon_language(readout.text),
		"authority detach immediately restores a truthful offline cockpit state",
	)

	_check(
		bool(bomber.reset_payload_for_reuse(2).get("accepted", false)),
		"a newer payload generation re-arms the retained Cinder for reuse coverage",
	)
	await physics_frame
	_check(
		readout.text.contains("PAYLOAD READY")
			and readout.text.contains("AMMO 4")
			and readout.text.contains("RELEASE READY"),
		"the re-armed generation is visible before whole-ship reuse",
	)

	var reset := bomber.reset_for_reuse(Transform3D.IDENTITY)
	await physics_frame
	var payload_after_reset := bomber.get_payload_authority_snapshot()
	var audio_after_reset := bomber.get_payload_audio_binding().get_snapshot() as Dictionary
	_check(
		bool(reset.get("accepted", false))
			and not bool(payload_after_reset.get("active", true))
			and not bool(audio_after_reset.get("attached", true))
			and readout.text.contains("PAYLOAD OFFLINE")
			and readout.text.contains("AMMO 0")
			and readout.text.contains("RELEASE LOCKED")
			and _excludes_cannon_language(readout.text),
		"whole-ship reuse leaves cockpit and payload audio consistently offline",
	)

	_finish(bomber)


func _excludes_cannon_language(text: String) -> bool:
	return not text.contains("WPN") \
		and not text.contains("HEAT") \
		and not text.contains("CYCLING") \
		and not text.contains("OVERHEAT")


func _check(condition: bool, description: String) -> void:
	_checks += 1
	if not condition:
		_failures.append("FAIL: " + description)


func _finish(bomber: CinderLongRangeBomber) -> void:
	if is_instance_valid(bomber):
		bomber.queue_free()
	await process_frame
	print("CINDER_BOMBER_COCKPIT_PAYLOAD_READOUT: %d checks, %d failures" % [
		_checks,
		_failures.size(),
	])
	if _failures.is_empty():
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)
