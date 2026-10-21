extends SceneTree

## Focused integration for Cinder's production payload-release seam. HeroShip
## remains the owner of flight, fire, damage, and lifecycle; this test only
## verifies hardpoint mapping and delegation into BomberPayloadAuthority.

const Bomber := preload("res://scripts/ships/cinder_long_range_bomber.gd")

var _assertions := 0
var _failures: Array[String] = []


func _initialize() -> void:
	var bomber := Bomber.new()
	root.add_child(bomber)
	await process_frame
	_check(bool(bomber.begin_payload_generation(1).get("accepted", false)), "the Cinder payload lifecycle starts explicitly")
	_check(bomber.request_payload_release(1, &"bomber_gunner", 1, 1, -1, Vector3(0.0, 0.0, -40.0)).reason == &"invalid_hardpoint", "an unknown hardpoint fails without consuming authority state")
	_check(bomber.request_payload_release(2, &"bomber_gunner", 1, 1, 0, Vector3(0.0, 0.0, -40.0)).reason == &"unauthorized_source", "Cinder delegates server-source fencing to payload authority")

	var hardpoints := bomber.get_payload_hardpoints()
	var accepted := bomber.request_payload_release(
		1,
		&"bomber_gunner",
		1,
		1,
		0,
		Vector3(0.0, 0.0, -40.0)
	)
	var record: Dictionary = accepted.get("record", {}) as Dictionary
	_check(
		bool(accepted.get("accepted", false))
			and bool((accepted.get("presentation", {}) as Dictionary).get("accepted", false))
			and accepted.get("hardpoint_index", -1) == 0
			and record.get("generation", -1) == 1
			and record.get("request_sequence", -1) == 1
			and record.get("release_position", Vector3.INF) == hardpoints[0].global_position
			and record.get("release_velocity", Vector3.ZERO) == Vector3(0.0, 0.0, -40.0)
			and record.get("payload_id", &"") == &"cinder_payload_alpha",
		"a valid Cinder release maps the authored hardpoint into an unresolved record"
	)
	_check(
		bomber.request_payload_release(1, &"bomber_gunner", 1, 2, 1, Vector3(0.0, 0.0, -40.0)).reason == &"cooldown",
		"the production API preserves bounded release cadence"
	)
	_check(bool(bomber.advance_payload_cooldown(1.0).get("accepted", false)), "the caller can advance the injected release cooldown")
	_check(bool(bomber.request_payload_release(1, &"bomber_gunner", 1, 2, 1, Vector3(0.0, 0.0, -40.0)).get("accepted", false)), "a newer sequence releases from a second hardpoint")
	_check(bomber.advance_payload_cooldown(1.0).get("accepted", false), "the second release cooldown can be advanced")
	_check(bool(bomber.request_payload_release(1, &"bomber_gunner", 1, 3, 2, Vector3(0.0, 0.0, -40.0)).get("accepted", false)), "the third bounded payload can be admitted")
	_check(bool(bomber.advance_payload_cooldown(1.0).get("accepted", false)), "the third release cooldown can be advanced")
	_check(bool(bomber.request_payload_release(1, &"bomber_gunner", 1, 4, 3, Vector3(0.0, 0.0, -40.0)).get("accepted", false)), "the fourth hardpoint consumes the final payload")
	_check(bool(bomber.advance_payload_cooldown(1.0).get("accepted", false)), "the final release cooldown can be advanced")
	_check(bomber.request_payload_release(1, &"bomber_gunner", 1, 5, 2, Vector3(0.0, 0.0, -40.0)).reason == &"ammunition_exhausted", "the authored ammunition budget remains bounded")
	_check(bomber.request_payload_release(1, &"bomber_gunner", 1, 4, 2, Vector3(0.0, 0.0, -40.0)).reason == &"stale_request_sequence", "the production API rejects replayed sequences")
	_check(
		bomber.get_audit_report().get("flight_authority", false)
			and bomber.get_audit_report().get("damage_authority", false)
			and not bomber.get_audit_report().get("combat_authority", true)
			and not bomber.get_audit_report().get("ordnance_authority", true)
			and bomber.get_audit_report().get("payload_records_unresolved", false),
		"HeroShip retains flight/damage while payload admission does not resolve ordnance"
	)

	var detached := bomber.detach_payload_authority(&"seat_lost")
	_check(bool(detached.get("accepted", false)), "explicit payload detach succeeds")
	_check(
		bomber.request_payload_release(1, &"bomber_gunner", 1, 1, 3, Vector3(0.0, 0.0, -40.0)).reason == &"authority_detached",
		"detached payload authority rejects old releases"
	)
	var presentation := bomber.get_payload_presentation() as BomberPayloadPresentation
	var detached_statistics := presentation.get_statistics()
	_check(
		bomber.begin_payload_generation(1).reason == &"stale_generation"
			and bool(presentation.get("_explicitly_detached"))
			and presentation.get_statistics() == detached_statistics,
		"a stale ordinary begin cannot reattach detached presentation or reset counters"
	)
	_check(bool(bomber.begin_payload_generation(2).get("accepted", false)), "ordinary seat retake begins a newer generation after detach")
	var retaken_release := bomber.request_payload_release(1, &"new_gunner", 2, 1, 3, Vector3(0.0, 0.0, -40.0))
	var retaken_visuals := presentation.get_active_snapshots()
	_check(
		bool(retaken_release.get("accepted", false))
			and bool((retaken_release.get("presentation", {}) as Dictionary).get("accepted", false))
			and retaken_visuals.size() == 1 and int(retaken_visuals[0].generation) == 2
			and int(bomber.get_payload_authority_snapshot().ammunition_remaining) == 3,
		"detach then ordinary newer begin presents the fresh payload while preserving the four-to-three budget"
	)
	var live_statistics := presentation.get_statistics()
	_check(
		bomber.begin_payload_generation(3).reason == &"authority_active"
			and bomber.begin_payload_generation(2).reason == &"stale_generation"
			and presentation.get_active_snapshots() == retaken_visuals
			and presentation.get_statistics() == live_statistics
			and not bool(presentation.get("_explicitly_detached")),
		"refused active and stale begins preserve the live payload effect and its counters"
	)
	_check(bool(bomber.detach_payload_authority(&"seat_lost_again").get("accepted", false)), "the retaken seat can detach normally")
	_check(bomber.reset_payload_for_reuse(2).reason == &"stale_generation", "payload reuse cannot replay a detached generation")
	_check(bool(bomber.reset_payload_for_reuse(3).get("accepted", false)), "payload reuse requires a newer generation")
	_check(bool(bomber.request_payload_release(1, &"new_gunner", 3, 1, 3, Vector3(0.0, 0.0, -40.0)).get("accepted", false)), "the re-entered generation starts a fresh sequence and budget")

	bomber.queue_free()
	await process_frame
	if _failures.is_empty():
		print("PASS cinder_bomber_payload_integration_test (%d assertions)" % _assertions)
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _check(condition: bool, message: String) -> void:
	_assertions += 1
	if not condition:
		_failures.append(message)
