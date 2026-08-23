extends SceneTree

## Presentation-only production check for the real Halyard loadmaster seat.
## The sign consumes detached receipts and never gains gameplay authority.

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

	var sign_node := craft.get_node_or_null(^"LoadmasterStationSign") as Label3D
	_check(
		sign_node != null
			and sign_node.get_meta("presentation_only", false)
			and sign_node.get_meta("seat_id", &"") == HalyardCrewTransport.LOADMASTER_STATION_SEAT_ID,
		"the loadmaster sign is presentation-only and anchored to the physical seat"
	)
	_check(
		craft.get_loadmaster_station_display_readout().contains("LOADMASTER")
			and craft.get_loadmaster_station_display_readout().contains("[STANDBY]"),
		"the retained seat sign starts in a text-safe standby state"
	)
	var render := craft.get_halyard_render_allocation_report()
	_check(
		bool(render.get("exact_counts", false))
			and craft.get_loadmaster_station_display_snapshot().get("presentation_only", false),
		"the seat sign preserves the authored visual renderer budget"
	)

	var authority := Authority.new(1)
	_check(bool(authority.register_halyard_roster().get("accepted", false)), "the real Halyard roster seals")
	_check(bool(craft.attach_crew_role_authority(authority).get("accepted", false)), "the Halyard accepts its role authority")
	_check(
		bool(authority.claim(
			1, 81, &"loadmaster_display_avatar", HalyardCrewTransport.LOADMASTER_STATION_SEAT_ID,
			Authority.ROLE_PASSENGER, 1
		).get("accepted", false)),
		"the display is driven by an admitted physical loadmaster seat"
	)

	var ready := craft.submit_crew_intent(
		1,
		81,
		&"loadmaster_display_avatar",
		RoleProfile.ACTION_PASSENGER_CARGO_MANIFEST,
		{"manifest_id": &"manifest_display", "route_id": &"dock_04_cargo", "ready": true},
		2
	)
	_check(
		bool(ready.get("consumed", false))
			and craft.get_loadmaster_station_display_readout().contains("[READY]")
			and craft.get_loadmaster_station_display_readout().contains("ROUTE dock_04_cargo")
			and craft.get_loadmaster_station_display_readout().contains("MANIFEST manifest_display"),
		"a detached ready receipt renders manifest and selected route at the seat"
	)
	var ready_snapshot := craft.get_loadmaster_station_display_snapshot()
	_check(
		ready_snapshot.get("state", &"") == &"ready"
			and bool(ready_snapshot.get("ready", false))
			and not bool(ready_snapshot.get("cargo_transfer_authority", true))
			and not bool(ready_snapshot.get("helm_authority", true)),
		"the ready sign snapshot remains presentation-only"
	)

	var blocked := craft.submit_crew_intent(
		1,
		81,
		&"loadmaster_display_avatar",
		RoleProfile.ACTION_PASSENGER_CARGO_MANIFEST,
		{"manifest_id": &"manifest_display", "route_id": &"dock_05", "ready": false},
		3
	)
	_check(
		bool(blocked.get("consumed", false))
			and craft.get_loadmaster_station_display_readout().contains("[BLOCKED]")
			and craft.get_loadmaster_station_display_readout().contains("ROUTE dock_05"),
		"a caller-owned blocked receipt replaces the sign state without cargo mutation"
	)

	var released := authority.release(
		1, 81, &"loadmaster_display_avatar", HalyardCrewTransport.LOADMASTER_STATION_SEAT_ID, 4
	)
	_check(bool(released.get("accepted", false)), "the loadmaster role releases through the existing authority")
	await physics_frame
	_check(
		craft.get_loadmaster_station_display_readout().contains("[STANDBY]")
			and craft.get_loadmaster_station_display_snapshot().get("state", &"") == &"standby",
		"release clears the sign and route/readiness presentation"
	)

	var reentry_claim := authority.claim(
		1, 82, &"reentry_display_avatar", HalyardCrewTransport.LOADMASTER_STATION_SEAT_ID,
		Authority.ROLE_PASSENGER, 1
	)
	_check(bool(reentry_claim.get("accepted", false)), "a replacement occupant can reclaim the seat")
	var reentry := craft.submit_crew_intent(
		1,
		82,
		&"reentry_display_avatar",
		RoleProfile.ACTION_PASSENGER_CARGO_MANIFEST,
		{"manifest_id": &"manifest_reentry", "route_id": &"dock_06", "ready": true},
		2
	)
	_check(bool(reentry.get("consumed", false)), "the replacement receipt is consumed")
	root.remove_child(craft)
	await process_frame
	_check(
		craft.get_loadmaster_station_display_readout().contains("[STANDBY]")
			and craft.get_loadmaster_station_display_snapshot().get("state", &"") == &"standby",
		"detach clears the sign before re-entry"
	)
	root.add_child(craft)
	await process_frame
	_check(
		craft.get_loadmaster_station_display_readout().contains("[STANDBY]")
			and craft.get_loadmaster_station_display_snapshot().get("state", &"") == &"standby",
		"re-entry retains a clean sign until a new detached receipt arrives"
	)

	craft.queue_free()
	await process_frame
	if _failures.is_empty():
		print("HALYARD_LOADMASTER_PRESENTATION_TEST_OK: %d checks" % _assertions)
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _check(condition: bool, message: String) -> void:
	_assertions += 1
	if not condition:
		_failures.append(message)
