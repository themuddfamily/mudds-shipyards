extends SceneTree

## Focused Phase 7 runtime slice: the Halyard's real cabin passenger seat can
## publish a caller-owned loadmaster manifest/readiness receipt. It never owns
## inventory, reward, berth, movement, weapon, or helm authority.

const HALYARD_SCENE := preload("res://scenes/ships/halyard_crew_transport.tscn")
const Authority := preload("res://scripts/ships/crew_seat_role_authority.gd")
const RoleProfile := preload("res://scripts/fleet/crew_role_gameplay_profile.gd")

var _assertions := 0
var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var craft := HALYARD_SCENE.instantiate() as HalyardCrewTransport
	root.add_child(craft)
	await process_frame
	await physics_frame
	await physics_frame

	var authority := Authority.new(1)
	_check(
		bool(authority.register_halyard_roster().get("accepted", false)),
		"the physical Halyard roster seals before loadmaster admission"
	)
	_check(
		bool(craft.attach_crew_role_authority(authority).get("accepted", false)),
		"the Halyard accepts the session-owned roster"
	)
	var station := craft.get_loadmaster_station_anchor()
	_check(
		station != null
			and StringName(station.get_meta("seat_id", &"")) == HalyardCrewTransport.LOADMASTER_STATION_SEAT_ID,
		"the loadmaster contract points to a real authored cabin seat"
	)
	_check(
		not craft.get_loadmaster_manifest_snapshot().get("cargo_transfer_authority", true)
			and not craft.get_loadmaster_manifest_snapshot().get("helm_authority", true),
		"the loadmaster snapshot grants no cargo or helm authority"
	)

	_check(
		bool(authority.claim(
			1, 91, &"loadmaster_avatar", HalyardCrewTransport.LOADMASTER_STATION_SEAT_ID,
			Authority.ROLE_PASSENGER, 1
		).get("accepted", false)),
		"the loadmaster occupant claims the physical passenger seat"
	)
	var accepted := craft.submit_crew_intent(
		1,
		91,
		&"loadmaster_avatar",
		RoleProfile.ACTION_PASSENGER_CARGO_MANIFEST,
		{"manifest_id": &"manifest_alpha", "route_id": &"dock_04_cargo", "ready": true},
		2
	)
	var effect := accepted.get("effect", {}) as Dictionary
	var receipt := effect.get("receipt", {}) as Dictionary
	_check(
		bool(accepted.get("accepted", false))
			and bool(accepted.get("consumed", false))
			and effect.get("status", &"") == &"loadmaster_manifest_recorded",
		"the authority-admitted loadmaster intent is consumed once"
	)
	_check(
		receipt.get("manifest_id", &"") == &"manifest_alpha"
			and receipt.get("route_id", &"") == &"dock_04_cargo"
			and bool(receipt.get("ready", false))
			and int(receipt.get("seat_generation", 0)) == 1,
		"the receipt preserves manifest, route, readiness, and seat generation"
	)
	var snapshot := craft.get_loadmaster_manifest_snapshot()
	_check(
		(snapshot.get("receipt", {}) as Dictionary).get("manifest_id", &"") == &"manifest_alpha"
			and int(snapshot.get("manifest_generation", 0)) == 1,
		"the detached loadmaster snapshot exposes the current generation-fenced receipt"
	)

	var replay := craft.submit_crew_intent(
		1,
		91,
		&"loadmaster_avatar",
		RoleProfile.ACTION_PASSENGER_CARGO_MANIFEST,
		{"manifest_id": &"manifest_alpha", "route_id": &"dock_04_cargo", "ready": true},
		2
	)
	_check(
		not bool(replay.get("accepted", false))
			and replay.get("status", &"") == &"stale_request_sequence",
		"the loadmaster receipt cannot replay through the authority sequence"
	)

	var wrong_station := authority.claim(
		1, 92, &"ordinary_passenger", &"crew_starboard_00", Authority.ROLE_PASSENGER, 1
	)
	_check(bool(wrong_station.get("accepted", false)), "a second ordinary passenger can occupy another seat")
	var denied := craft.submit_crew_intent(
		1,
		92,
		&"ordinary_passenger",
		RoleProfile.ACTION_PASSENGER_CARGO_MANIFEST,
		{"manifest_id": &"manifest_beta", "route_id": &"dock_05", "ready": true},
		2
	)
	_check(
		not bool(denied.get("accepted", false))
			and denied.get("status", &"") == &"unsupported_halyard_role_action",
		"only the physical loadmaster seat can submit the loadmaster action"
	)

	var handoff := craft.handoff_crew_role(
		1,
		91,
		&"loadmaster_avatar",
		HalyardCrewTransport.LOADMASTER_STATION_SEAT_ID,
		3,
		93,
		&"replacement_loadmaster",
		Authority.ROLE_PASSENGER,
		1
	)
	_check(
		bool(handoff.get("accepted", false))
			and (craft.get_loadmaster_manifest_snapshot().get("receipt", {}) as Dictionary).is_empty()
			and int(craft.get_loadmaster_manifest_snapshot().get("manifest_generation", 0)) == 2,
		"an atomic seat handoff clears the outgoing receipt and advances generation"
	)
	var replacement := craft.submit_crew_intent(
		1,
		93,
		&"replacement_loadmaster",
		RoleProfile.ACTION_PASSENGER_CARGO_MANIFEST,
		{"manifest_id": &"manifest_gamma", "route_id": &"dock_06", "ready": false},
		2
	)
	var replacement_receipt := (replacement.get("effect", {}) as Dictionary).get("receipt", {}) as Dictionary
	_check(
		bool(replacement.get("consumed", false))
			and replacement_receipt.get("manifest_id", &"") == &"manifest_gamma"
			and int(replacement_receipt.get("manifest_generation", 0)) == 2,
		"the replacement occupant acts on a fresh loadmaster generation"
	)

	var released := authority.release(
		1, 93, &"replacement_loadmaster", HalyardCrewTransport.LOADMASTER_STATION_SEAT_ID, 3
	)
	_check(bool(released.get("accepted", false)), "the replacement loadmaster can be released")
	await physics_frame
	_check(
		(craft.get_loadmaster_manifest_snapshot().get("receipt", {}) as Dictionary).is_empty()
			and int(craft.get_loadmaster_manifest_snapshot().get("manifest_generation", 0)) == 3,
		"authority detach clears the receipt exactly once and fences its generation"
	)

	var reset := craft.reset_for_reuse(Transform3D.IDENTITY)
	_check(bool(reset.get("accepted", false)), "the Halyard reset lifecycle commits after role release")
	_check(
		(craft.get_loadmaster_manifest_snapshot().get("receipt", {}) as Dictionary).is_empty()
			and int(craft.get_loadmaster_manifest_snapshot().get("manifest_generation", 0)) == 1,
		"reuse resets loadmaster receipt state to a clean generation"
	)

	var reentry_claim := authority.claim(
		1, 94, &"reentry_loadmaster", HalyardCrewTransport.LOADMASTER_STATION_SEAT_ID,
		Authority.ROLE_PASSENGER, 1
	)
	_check(bool(reentry_claim.get("accepted", false)), "a re-entry occupant can claim the same physical station")
	var reentry := craft.submit_crew_intent(
		1,
		94,
		&"reentry_loadmaster",
		RoleProfile.ACTION_PASSENGER_CARGO_MANIFEST,
		{"manifest_id": &"manifest_delta", "route_id": &"dock_07", "ready": true},
		2
	)
	_check(bool(reentry.get("consumed", false)), "the clean post-reset station accepts a fresh intent")
	root.remove_child(craft)
	await process_frame
	root.add_child(craft)
	await process_frame
	_check(
		(craft.get_loadmaster_manifest_snapshot().get("receipt", {}) as Dictionary).is_empty()
			and int(craft.get_loadmaster_manifest_snapshot().get("manifest_generation", 0)) == 2,
		"detach and re-entry clear the prior receipt without changing the physical station"
	)

	craft.queue_free()
	await process_frame
	if _failures.is_empty():
		print("HALYARD_LOADMASTER_ROLE_GAMEPLAY_TEST_OK: %d checks" % _assertions)
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _check(condition: bool, message: String) -> void:
	_assertions += 1
	if not condition:
		_failures.append(message)
