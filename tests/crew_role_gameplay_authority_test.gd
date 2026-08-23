extends SceneTree

## Focused runtime coverage for role-specific multicrew gameplay intents.
## This stays detached from Main, networking peers, ship movement, combat,
## damage, landing, and MovingInteriorFrame physics.

const Authority := preload("res://scripts/ships/crew_seat_role_authority.gd")
const Profile := preload("res://scripts/fleet/crew_role_gameplay_profile.gd")

var _checks := 0
var _failures := PackedStringArray()


func _init() -> void:
	call_deferred(&"_run")


func _run() -> void:
	_test_profile_shapes_and_normalization()
	_test_role_intent_authority_and_capabilities()
	_test_intent_sequence_and_lifecycle_cleanup()
	if _failures.is_empty():
		print("OK: crew role gameplay authority (%d assertions)" % _checks)
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)


func _test_profile_shapes_and_normalization() -> void:
	_check(Profile.get_supported_roles().size() == 4, "gameplay profile declares four runtime crew roles")
	var pilot := Profile.validate_intent(
		Profile.ROLE_PILOT,
		Profile.ACTION_FLIGHT_COMMAND,
		{
			"throttle": 2.0,
			"pitch": -2.0,
			"yaw": 0.25,
			"roll": 0.0,
			"boost": true,
			"brake": false,
		}
	)
	var pilot_payload: Dictionary = pilot.get("payload", {})
	_check(
		bool(pilot.accepted)
		and is_equal_approx(float(pilot_payload.get("throttle", -1.0)), 1.0)
		and is_equal_approx(float(pilot_payload.get("pitch", 2.0)), -1.0),
		"pilot flight axes normalize into bounded command intent"
	)
	var invalid_extra := Profile.validate_intent(
		Profile.ROLE_GUNNER,
		Profile.ACTION_GUNNER_FIRE,
		{"weapon_id": "pulse", "target_id": "drone", "trigger": true, "spoof": true}
	)
	_check(not invalid_extra.accepted and invalid_extra.status == &"invalid_gunner_fire_schema", "unknown gunner fields fail closed")
	var repair := Profile.validate_intent(
		Profile.ROLE_ENGINEER,
		Profile.ACTION_ENGINEER_REPAIR,
		{"system_id": "reactor", "repair": 4.0}
	)
	_check(bool(repair.accepted) and is_equal_approx(float((repair.payload as Dictionary).repair), 1.0), "engineer repair intent is bounded")
	var passenger := Profile.validate_intent(
		Profile.ROLE_PASSENGER,
		Profile.ACTION_PASSENGER_PING,
		{"channel": "crew", "marker_id": "hazard_a"}
	)
	_check(bool(passenger.accepted), "passenger can publish a bounded interior ping intent")
	var wrong_role := Profile.validate_intent(
		Profile.ROLE_PASSENGER,
		Profile.ACTION_ENGINEER_REPAIR,
		{"system_id": "reactor", "repair": 0.5}
	)
	_check(not wrong_role.accepted and wrong_role.status == &"action_not_allowed", "role cannot submit another role's action")


func _test_role_intent_authority_and_capabilities() -> void:
	var authority := Authority.new(77)
	_check(authority.register_halyard_roster().accepted, "Halyard role roster seals before gameplay intents")
	_check(authority.claim(77, 7, &"pilot_avatar", &"pilot_station", Authority.ROLE_PILOT, 1).accepted, "server seats pilot")
	_check(authority.claim(77, 8, &"gunner_avatar", &"co_pilot_station", Authority.ROLE_GUNNER, 1).accepted, "server seats gunner")
	_check(authority.claim(77, 9, &"engineer_avatar", &"crew_port_01", Authority.ROLE_ENGINEER, 1).accepted, "server seats engineer")
	_check(authority.claim(77, 10, &"passenger_avatar", &"crew_port_00", Authority.ROLE_PASSENGER, 1).accepted, "server seats passenger")
	var pilot_intent := authority.submit_intent(
		77, 7, &"pilot_avatar", Authority.ACTION_FLIGHT_COMMAND,
		{"throttle": 0.7, "pitch": 0.0, "yaw": 0.1, "roll": -0.2, "boost": false, "brake": false}, 2
	)
	_check(bool(pilot_intent.accepted) and pilot_intent.status == &"intent_accepted", "pilot flight intent is admitted by the seat authority")
	var gunner_intent := authority.submit_intent(
		77, 8, &"gunner_avatar", Authority.ACTION_GUNNER_FIRE,
		{"weapon_id": "defensive_pulse", "target_id": "range_drone", "trigger": true}, 2
	)
	_check(bool(gunner_intent.accepted), "gunner fire intent is admitted by the seat authority")
	var engineer_intent := authority.submit_intent(
		77, 9, &"engineer_avatar", Authority.ACTION_ENGINEER_REPAIR,
		{"system_id": "drive", "repair": 0.35}, 2
	)
	_check(bool(engineer_intent.accepted), "engineer repair intent is admitted by the seat authority")
	var passenger_intent := authority.submit_intent(
		77, 10, &"passenger_avatar", Authority.ACTION_PASSENGER_PING,
		{"channel": "crew", "marker_id": "airlock"}, 2
	)
	_check(bool(passenger_intent.accepted), "passenger ping intent is admitted by the seat authority")
	var spoofed := authority.submit_intent(
		8, 7, &"pilot_avatar", Authority.ACTION_FLIGHT_COMMAND,
		{"throttle": 1.0, "pitch": 0.0, "yaw": 0.0, "roll": 0.0, "boost": true, "brake": false}, 3
	)
	_check(not spoofed.accepted and spoofed.status == &"unauthorized_source", "client cannot inject a role intent")
	var passenger_flight := authority.submit_intent(
		77, 10, &"passenger_avatar", Authority.ACTION_FLIGHT_COMMAND,
		{"throttle": 1.0, "pitch": 0.0, "yaw": 0.0, "roll": 0.0, "boost": false, "brake": false}, 3
	)
	_check(not passenger_flight.accepted and passenger_flight.status == &"action_not_allowed", "passenger cannot obtain pilot command authority")
	var gunner_command := authority.authorize_action(8, &"gunner_avatar", Authority.CAPABILITY_SHIP_COMMAND)
	_check(not gunner_command.accepted, "gunner retains no movement capability")
	var snapshot := authority.get_snapshot()
	_check((snapshot.intents as Array).size() == 4, "snapshot exposes one latest normalized intent per seated role")
	_check(
		StringName(((authority.get_last_intent(8, &"gunner_avatar").get("payload", {}) as Dictionary).get("target_id", &""))) == &"range_drone",
		"latest gunner intent retains its target identity for downstream combat authority"
	)


func _test_intent_sequence_and_lifecycle_cleanup() -> void:
	var authority := Authority.new(77)
	authority.register_halyard_roster()
	authority.claim(77, 11, &"pilot_avatar", &"pilot_station", Authority.ROLE_PILOT, 1)
	var invalid := authority.submit_intent(
		77, 11, &"pilot_avatar", Authority.ACTION_FLIGHT_COMMAND,
		{"throttle": 0.2, "pitch": 0.0, "yaw": 0.0, "roll": 0.0, "boost": false, "brake": false, "unexpected": false}, 2
	)
	_check(not invalid.accepted and invalid.status == &"invalid_flight_command_schema", "invalid intent does not enter the role stream")
	var accepted := authority.submit_intent(
		77, 11, &"pilot_avatar", Authority.ACTION_FLIGHT_COMMAND,
		{"throttle": 0.2, "pitch": 0.0, "yaw": 0.0, "roll": 0.0, "boost": false, "brake": false}, 2
	)
	_check(bool(accepted.accepted), "valid intent can reuse the sequence after a rejected payload")
	var replay := authority.submit_intent(
		77, 11, &"pilot_avatar", Authority.ACTION_FLIGHT_COMMAND,
		{"throttle": 0.3, "pitch": 0.0, "yaw": 0.0, "roll": 0.0, "boost": false, "brake": false}, 2
	)
	_check(not replay.accepted and replay.status == &"stale_request_sequence", "duplicate intent sequence cannot replay gameplay")
	var before_release := int(authority.get_snapshot().event_sequence)
	var release := authority.release(77, 11, &"pilot_avatar", &"pilot_station", 3, 1)
	_check(bool(release.accepted) and authority.get_last_intent(11, &"pilot_avatar").is_empty(), "seat release clears the role intent exactly once")
	_check(int(authority.get_snapshot().event_sequence) == before_release + 1, "release advances lifecycle once after an accepted intent")
	var duplicate_release := authority.release(77, 11, &"pilot_avatar", &"pilot_station", 4, 1)
	_check(not duplicate_release.accepted and duplicate_release.status == &"assignment_not_found", "duplicate release cannot emit a second role lifecycle event")


func _check(condition: bool, description: String) -> void:
	_checks += 1
	if not condition:
		_failures.append("FAIL: " + description)
