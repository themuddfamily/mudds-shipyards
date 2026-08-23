extends SceneTree

## Focused Phase 7 runtime slice: an authority-admitted engineer receipt is
## consumed by the real Halyard and delegated to its existing component owner.
## No test here claims network transport, avatar control, or human sign-off.

const HALYARD_SCENE := preload("res://scenes/ships/halyard_crew_transport.tscn")
const Authority := preload("res://scripts/ships/crew_seat_role_authority.gd")
const ShipComponentDamageType := preload("res://scripts/combat/ship_component_damage.gd")

var _failures: Array[String] = []
var _assertions := 0


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var craft := HALYARD_SCENE.instantiate() as HalyardCrewTransport
	root.add_child(craft)
	await process_frame
	await physics_frame
	await physics_frame

	var authority := Authority.new(1)
	var registered := authority.register_halyard_roster()
	_check(bool(registered.get("accepted", false)), "the Halyard roster seals in the session authority")
	var attached := craft.attach_crew_role_authority(authority)
	_check(bool(attached.get("accepted", false)), "the real Halyard accepts the sealed session authority")

	var claimed := authority.claim(
		1, 77, &"engineer_avatar", &"crew_port_01", Authority.ROLE_ENGINEER, 1
	)
	_check(bool(claimed.get("accepted", false)), "the engineer claim is admitted for the physical systems seat")
	_check(
		bool(authority.claim(1, 71, &"pilot_avatar", &"pilot_station", Authority.ROLE_PILOT, 1).get("accepted", false)),
		"the pilot assignment is visible to the detached gameplay view"
	)
	_check(
		bool(authority.claim(1, 72, &"gunner_avatar", &"co_pilot_station", Authority.ROLE_GUNNER, 1).get("accepted", false)),
		"the gunner assignment is visible to the detached gameplay view"
	)
	_check(
		bool(authority.claim(1, 73, &"passenger_avatar", &"crew_port_00", Authority.ROLE_PASSENGER, 1).get("accepted", false)),
		"the passenger assignment is visible to the detached gameplay view"
	)
	var crew_avatar := CharacterBody3D.new()
	crew_avatar.name = "gunner_crew_avatar"
	root.add_child(crew_avatar)
	crew_avatar.global_position = craft.global_position + Vector3(0.0, 1.0, 0.0)
	await process_frame
	var frame := craft.get_moving_interior_component()
	var occupancy := craft.attach_crew_role_occupant(
		72, &"gunner_avatar", &"co_pilot_station", crew_avatar
	)
	_check(
		bool(occupancy.get("accepted", false))
			and frame.is_occupant_registered(crew_avatar)
			and frame.get_occupant_count() == 1
			and frame.get_moving_frame() == craft,
		"an admitted non-pilot role attaches to the existing moving-interior frame"
	)
	var duplicate_occupancy := craft.attach_crew_role_occupant(
		72, &"gunner_avatar", &"co_pilot_station", crew_avatar
	)
	_check(
		bool(duplicate_occupancy.get("accepted", false))
			and duplicate_occupancy.get("status", &"") == &"already_registered"
			and frame.get_occupant_count() == 1,
		"re-attaching one role occupant does not create a second physical registration"
	)
	_check(
		frame.get_status_report().get("occupant_count", 0) == 1,
		"the moving-interior frame retains one canonical non-pilot occupant"
	)

	var model := craft.get_component_damage()
	var selected := [0]
	var cleared := [0]
	var selected_generation := [0]
	var clear_reason := [StringName(&"")]
	var route_changes := [0]
	var last_route := [StringName(&"")]
	craft.engineer_component_selected.connect(
		func(_component_id: StringName, generation: int, _receipt: Dictionary) -> void:
			selected[0] += 1
			selected_generation[0] = generation
	)
	craft.engineer_component_cleared.connect(
		func(_component_id: StringName, _generation: int, reason: StringName) -> void:
			cleared[0] += 1
			clear_reason[0] = reason
	)
	craft.engineer_power_route_changed.connect(
		func(_component_id: StringName, route: StringName, _bonus: float, _receipt: Dictionary) -> void:
			route_changes[0] += 1
			last_route[0] = route
	)
	var damaged := model.record_damage(70.0, Vector3.ZERO)
	_check(bool(damaged.get("accepted", false)), "the existing Halyard component owner accepts a live damage observation")
	model.tick_repair(10.0, true)
	var targeted_damage := model.record_damage(70.0, Vector3(0.0, 2.88, 0.325))
	_check(bool(targeted_damage.get("accepted", false)), "the component owner can isolate one damaged systems target")
	var system_id := ShipComponentDamageType.COMPONENT_ENGINE_BAY
	if model.get_component_integrity(system_id) >= 1.0:
		system_id = _first_damaged_system(model)
	var integrity_before := model.get_component_integrity(system_id)
	_check(integrity_before >= 0.0 and integrity_before < 1.0, "the engineer has a damaged system to repair")
	var foreign := craft.submit_crew_intent(
		1, 77, &"engineer_avatar", Authority.ACTION_ENGINEER_REPAIR,
		{"system_id": &"foreign_reactor", "repair": 0.0, "system_generation": 1}, 2
	)
	_check(
		bool(foreign.get("accepted", false))
			and not bool(foreign.get("consumed", false))
			and (foreign.get("effect", {}) as Dictionary).get("status", &"") == &"foreign_component",
		"a foreign component identity is rejected before repair routing"
	)
	craft.set("_landed", true)
	var consumed := craft.submit_crew_intent(
		1,
		77,
		&"engineer_avatar",
		Authority.ACTION_ENGINEER_REPAIR,
		{"system_id": system_id, "repair": 0.5, "system_generation": 1},
		3
	)
	var effect := consumed.get("effect", {}) as Dictionary
	_check(
		bool(consumed.get("accepted", false))
			and bool(consumed.get("consumed", false))
			and consumed.get("status", &"") == &"intent_consumed"
			and bool(effect.get("accepted", false)),
		"the Halyard consumes the authoritative engineer receipt exactly once"
	)
	_check(
		model.get_component_integrity(system_id) > integrity_before,
		"the consumed engineer receipt delegates a bounded repair pulse to the component owner"
	)
	_check(selected[0] == 1 and selected_generation[0] == 1, "the repair receipt selects its component target")
	var selection_result := effect.get("selection", {}) as Dictionary
	var selection := selection_result.get("selection", {}) as Dictionary
	var route_modifiers := craft.get_operational_modifiers()
	var route := route_modifiers.get("engineer_power_route", {}) as Dictionary
	_check(
		StringName(selection.get("power_route", &"none")) == &"mobility_multiplier"
			and StringName(route.get("channel", &"")) == &"mobility_multiplier"
			and int(route.get("component_generation", 0)) == 1,
		"the generation-fenced engineer selection activates the Halyard engine power route"
	)
	_check(
		is_equal_approx(float(route.get("bonus", 0.0)), HalyardCrewTransport.ENGINEER_POWER_ROUTE_BONUS)
			and float(route_modifiers.get("mobility_multiplier", 0.0)) > 0.0
			and route_changes[0] == 1
			and last_route[0] == &"mobility_multiplier",
		"the engineer route adds a bounded live mobility priority without mutating damage"
	)
	var healthy := craft.submit_crew_intent(
		1, 77, &"engineer_avatar", Authority.ACTION_ENGINEER_REPAIR,
		{"system_id": system_id, "repair": 0.0, "system_generation": 1}, 4
	)
	_check(
		bool(healthy.get("accepted", false))
			and not bool(healthy.get("consumed", false))
			and (healthy.get("effect", {}) as Dictionary).get("status", &"") == &"healthy_component",
		"a healthy component cannot be selected as a repair target"
	)

	var replay := craft.submit_crew_intent(
		1,
		77,
		&"engineer_avatar",
		Authority.ACTION_ENGINEER_REPAIR,
			{"system_id": system_id, "repair": 0.5, "system_generation": 1},
		4
	)
	_check(
		not bool(replay.get("accepted", false))
			and replay.get("status", &"") == &"stale_request_sequence",
		"a replayed receipt cannot mutate the Halyard twice"
	)
	craft.set("_engine_state", HeroShip.ENGINE_ONLINE)
	var gunner_intent := craft.submit_crew_intent(
		1,
		72,
		&"gunner_avatar",
		Authority.ACTION_GUNNER_FIRE,
		{
			"weapon_id": HalyardCrewTransport.HALYARD_CREW_WEAPON_ID,
			"target_id": &"snapshot_target",
			"trigger": false,
			"target_generation": 1,
		},
		2
	)
	_check(bool(gunner_intent.get("consumed", false)), "the gunner target is available to the gameplay snapshot")
	var passenger_intent := craft.submit_crew_intent(
		1,
		73,
		&"passenger_avatar",
		Authority.ACTION_PASSENGER_PING,
		{"channel": &"cabin", "marker_id": &"snapshot_marker"},
		2
	)
	_check(bool(passenger_intent.get("consumed", false)), "the passenger marker is available to the gameplay snapshot")
	var gameplay_snapshot := craft.get_crew_role_gameplay_snapshot()
	var role_occupancy := gameplay_snapshot.get("role_occupancy", {}) as Dictionary
	_check(
		int(gameplay_snapshot.get("schema_version", 0)) == HalyardCrewTransport.CREW_ROLE_GAMEPLAY_SNAPSHOT_SCHEMA_VERSION
			and int(gameplay_snapshot.get("authority_event_sequence", -1)) == int(authority.get_snapshot().get("event_sequence", -2))
			and (gameplay_snapshot.get("occupants", []) as Array).size() == 4,
		"the detached snapshot carries the authority generation fence and all four role occupants"
	)
	_check(
		(role_occupancy.get(Authority.ROLE_PILOT, []) as Array).size() == 1
			and (role_occupancy.get(Authority.ROLE_GUNNER, []) as Array).size() == 1
			and (role_occupancy.get(Authority.ROLE_ENGINEER, []) as Array).size() == 1
			and (role_occupancy.get(Authority.ROLE_PASSENGER, []) as Array).size() == 1,
		"the snapshot groups pilot, gunner, engineer, and passenger occupancy"
	)
	var gunner_view := (role_occupancy.get(Authority.ROLE_GUNNER, []) as Array)[0] as Dictionary
	var passenger_view := (role_occupancy.get(Authority.ROLE_PASSENGER, []) as Array)[0] as Dictionary
	_check(
		StringName((gunner_view.get("selected_target", {}) as Dictionary).get("target_id", &"")) == &"snapshot_target"
			and is_zero_approx(float(gunner_view.get("cooldown_remaining", -1.0)))
			and bool(gunner_view.get("cooldown_ready", false)),
		"the snapshot carries generation-fenced gunner selection and cooldown readiness"
	)
	_check(
		StringName((passenger_view.get("active_marker", {}) as Dictionary).get("marker_id", &"")) == &"snapshot_marker"
			and (gameplay_snapshot.get("active_markers", []) as Array).size() == 1
			and float(passenger_view.get("cooldown_remaining", 0.0)) > 0.0,
		"the snapshot carries the passenger marker and active ping cadence"
	)
	var power_routing := gameplay_snapshot.get("power_routing", {}) as Dictionary
	var snapshot_engineer_route := power_routing.get("engineer", {}) as Dictionary
	var effective_outputs := power_routing.get("effective_outputs", {}) as Dictionary
	_check(
		StringName(snapshot_engineer_route.get("component_id", &"")) == system_id
			and int(snapshot_engineer_route.get("component_generation", 0)) == 1
			and StringName(snapshot_engineer_route.get("channel", &"")) == &"mobility_multiplier",
		"the detached snapshot exposes the live engineer route and component generation"
	)
	_check(
		effective_outputs.has("mobility_multiplier")
			and effective_outputs.has("fire_multiplier")
			and effective_outputs.has("targeting_multiplier")
			and is_equal_approx(
				float(effective_outputs.get("mobility_multiplier", -1.0)),
				float(route_modifiers.get("mobility_multiplier", -2.0))
			),
		"the detached snapshot exposes bounded effective mobility, fire, and targeting outputs"
	)
	var departure_readiness := gameplay_snapshot.get("departure_readiness", {}) as Dictionary
	var optional_roles := departure_readiness.get("optional_roles", {}) as Dictionary
	_check(
		bool(departure_readiness.get("pilot_required", false))
			and bool(departure_readiness.get("pilot_present", false))
			and bool(departure_readiness.get("ready", false))
			and int(departure_readiness.get("pilot_seat_generation", 0)) == 1
			and int(departure_readiness.get("authority_event_sequence", -1))
			== int(gameplay_snapshot.get("authority_event_sequence", -2)),
		"the detached snapshot reports pilot-gated departure readiness with its authority fence"
	)
	_check(
		int(departure_readiness.get("optional_crew_count", 0)) == 3
			and bool((optional_roles.get(Authority.ROLE_ENGINEER, {}) as Dictionary).get("occupied", false))
			and int((optional_roles.get(Authority.ROLE_ENGINEER, {}) as Dictionary).get("seat_generation", 0)) == 1,
		"the detached snapshot reports optional crew occupancy and seat generations"
	)
	var detached_copy := gameplay_snapshot.duplicate(true)
	((detached_copy.get("occupants", []) as Array)[0] as Dictionary)["avatar_id"] = &"tampered"
	var fresh_snapshot := craft.get_crew_role_gameplay_snapshot()
	_check(
		StringName(((fresh_snapshot.get("occupants", []) as Array)[0] as Dictionary).get("avatar_id", &"")) != &"tampered",
		"snapshot consumers receive detached copies rather than mutable Halyard internals"
	)
	craft.set("_landed", false)
	var pilot_intent := craft.submit_crew_intent(
		1,
		71,
		&"pilot_avatar",
		Authority.ACTION_FLIGHT_COMMAND,
		{
			"throttle": 0.8,
			"pitch": 0.25,
			"yaw": -0.35,
			"roll": 0.1,
			"boost": true,
			"brake": false,
		},
		2
	)
	var pilot_effect := pilot_intent.get("effect", {}) as Dictionary
	_check(
		bool(pilot_intent.get("accepted", false))
			and bool(pilot_intent.get("consumed", false))
			and pilot_effect.get("status", &"") == &"pilot_command_applied",
		"the admitted pilot receipt reaches the Halyard command source"
	)
	await physics_frame
	await physics_frame
	var pilot_command := craft.get_last_ship_command()
	_check(
		is_equal_approx(pilot_command.throttle, 0.8)
			and is_equal_approx(pilot_command.pitch, 0.25)
			and is_equal_approx(pilot_command.yaw, -0.35)
			and pilot_command.boost,
		"the existing HeroShip seam consumes bounded pilot thrust and rotation"
	)
	var pilot_replay := craft.submit_crew_intent(
		1,
		71,
		&"pilot_avatar",
		Authority.ACTION_FLIGHT_COMMAND,
		{
			"throttle": 1.0,
			"pitch": 0.0,
			"yaw": 0.0,
			"roll": 0.0,
			"boost": true,
			"brake": false,
		},
		2
	)
	_check(
		not bool(pilot_replay.get("accepted", false))
			and pilot_replay.get("status", &"") == &"stale_request_sequence",
		"the pilot authority rejects a replayed command sequence"
	)
	var pilot_handoff := craft.handoff_crew_role(
		1,
		71,
		&"pilot_avatar",
		&"pilot_station",
		3,
		74,
		&"replacement_pilot",
		Authority.ROLE_PILOT,
		4
	)
	_check(
		bool(pilot_handoff.get("accepted", false))
			and not bool(craft.get("_piloted")),
		"pilot handoff neutralizes the outgoing held controls"
	)
	await physics_frame
	var neutral_after_handoff := craft.get_last_ship_command()
	_check(
		neutral_after_handoff.is_neutral(),
		"the outgoing pilot command cannot steer after handoff"
	)
	var replacement_pilot_intent := craft.submit_crew_intent(
		1,
		74,
		&"replacement_pilot",
		Authority.ACTION_FLIGHT_COMMAND,
		{
			"throttle": 0.3,
			"pitch": 0.0,
			"yaw": 0.0,
			"roll": 0.0,
			"boost": false,
			"brake": true,
		},
		5
	)
	_check(
		bool(replacement_pilot_intent.get("consumed", false)),
		"the replacement pilot starts a fresh admitted command stream"
	)
	var pilot_release := craft.release_crew_role(
		1, 74, &"replacement_pilot", &"pilot_station", 6
	)
	_check(bool(pilot_release.get("accepted", false)) and not bool(craft.get("_piloted")), "pilot release neutralizes controls")
	var pilotless_snapshot := craft.get_crew_role_gameplay_snapshot()
	var pilotless_departure := pilotless_snapshot.get("departure_readiness", {}) as Dictionary
	_check(
		not bool(pilotless_departure.get("pilot_present", true))
			and not bool(pilotless_departure.get("ready", true))
			and int(pilotless_departure.get("pilot_seat_generation", -1)) == 0
			and int(pilotless_departure.get("optional_crew_count", 0)) == 3,
		"detaching the pilot resets departure readiness without removing optional crew"
	)
	craft.set("_landed", true)

	var handoff := craft.handoff_crew_role(
		1,
		77,
		&"engineer_avatar",
		&"crew_port_01",
		5,
		78,
		&"replacement_engineer",
		Authority.ROLE_ENGINEER,
		6
	)
	_check(
		bool(handoff.get("accepted", false))
			and cleared[0] == 1
			and clear_reason[0] == &"role_handoff",
		"engineer handoff clears the outgoing component selection"
	)
	var replacement_system_id := _first_damaged_system(model)
	var stale_generation := craft.submit_crew_intent(
		1,
		78,
		&"replacement_engineer",
		Authority.ACTION_ENGINEER_REPAIR,
		{"system_id": replacement_system_id, "repair": 0.0, "system_generation": 1},
		7
	)
	_check(
		bool(stale_generation.get("accepted", false))
			and not bool(stale_generation.get("consumed", false))
			and (stale_generation.get("effect", {}) as Dictionary).get("status", &"")
			== &"stale_component_generation",
		"a stale component generation cannot route a replacement repair"
	)
	var replacement := craft.submit_crew_intent(
		1,
		78,
		&"replacement_engineer",
		Authority.ACTION_ENGINEER_REPAIR,
		{"system_id": replacement_system_id, "repair": 0.0, "system_generation": 2},
		8
	)
	_check(
		bool(replacement.get("accepted", false))
			and bool(replacement.get("consumed", false))
			and selected[0] == 2
			and selected_generation[0] == 2,
		"the replacement engineer selects the fresh component generation"
	)
	var released := authority.release(1, 78, &"replacement_engineer", &"crew_port_01", 9)
	_check(bool(released.get("accepted", false)), "the replacement engineer can be detached")
	await physics_frame
	_check(cleared[0] == 2 and clear_reason[0] == &"role_detached", "detach clears the replacement component selection")
	_check(
		route_changes[0] == 4
			and last_route[0] == &"none"
			and not craft.get_operational_modifiers().has("engineer_power_route"),
		"handoff and detach clear the engineer power route before a new occupant acts"
	)
	var after_detach := craft.get_crew_role_gameplay_snapshot()
	_check(
		(after_detach.get("role_occupancy", {}).get(Authority.ROLE_ENGINEER, []) as Array).is_empty()
			and (after_detach.get("selected_targets", {}).get("engineer", {}) as Dictionary).is_empty(),
		"the detached snapshot removes the released engineer and stale selection"
	)
	_check(
		(after_detach.get("power_routing", {}).get("engineer", {}) as Dictionary).is_empty()
			and (after_detach.get("power_routing", {}).get("effective_outputs", {}) as Dictionary).has("mobility_multiplier"),
		"handoff and detach reset routed engineer state while retaining detached effective outputs"
	)
	var occupancy_release := craft.release_crew_role_occupant(
		1, 72, &"gunner_avatar", &"co_pilot_station", crew_avatar, 3
	)
	_check(
		bool(occupancy_release.get("accepted", false))
			and not frame.is_occupant_registered(crew_avatar)
			and frame.get_occupant_count() == 0,
		"releasing the role clears its physical moving-interior occupancy exactly once"
	)
	crew_avatar.queue_free()
	var emergency_avatar := CharacterBody3D.new()
	emergency_avatar.name = "emergency_passenger_avatar"
	root.add_child(emergency_avatar)
	emergency_avatar.global_position = craft.global_position + Vector3(0.0, 1.0, -1.0)
	await process_frame
	var emergency_occupancy := craft.attach_crew_role_occupant(
		73, &"passenger_avatar", &"crew_port_00", emergency_avatar
	)
	_check(
		bool(emergency_occupancy.get("accepted", false))
			and frame.is_occupant_registered(emergency_avatar)
			and frame.get_occupant_count() == 1,
		"an admitted seated passenger is eligible for an explicit emergency handoff"
	)
	var invalid_emergency_sequence := craft.request_emergency_pilot_handoff(
		1,
		73,
		&"passenger_avatar",
		&"crew_port_00",
		3,
		3,
		emergency_avatar,
		1
	)
	_check(
		not bool(invalid_emergency_sequence.get("accepted", false))
			and invalid_emergency_sequence.get("status", &"") == &"invalid_handoff_sequence"
			and not authority.get_assignment(73, &"passenger_avatar").is_empty()
			and frame.is_occupant_registered(emergency_avatar),
		"an invalid emergency sequence is rejected before authority or occupancy mutation"
	)
	var emergency_handoff := craft.request_emergency_pilot_handoff(
		1,
		73,
		&"passenger_avatar",
		&"crew_port_00",
		3,
		4,
		emergency_avatar,
		1
	)
	_check(
		bool(emergency_handoff.get("accepted", false))
			and emergency_handoff.get("status", &"") == &"emergency_pilot_handoff"
			and bool(emergency_handoff.get("occupancy_preserved", false))
			and frame.is_occupant_registered(emergency_avatar)
			and frame.get_occupant_count() == 1,
		"the caller-authorized emergency handoff preserves moving-interior occupancy"
	)
	var emergency_assignment := authority.get_assignment(73, &"passenger_avatar")
	_check(
		StringName(emergency_assignment.get("role", &"")) == Authority.ROLE_PILOT
			and StringName(emergency_assignment.get("seat_id", &"")) == &"pilot_station"
			and craft.get_crew_pilot_command_state().is_empty()
			and not bool(craft.get("_piloted")),
		"the emergency replacement receives only the pilot role and starts neutral"
	)
	var emergency_snapshot := craft.get_crew_role_gameplay_snapshot()
	var handoff_snapshot := emergency_snapshot.get("emergency_pilot_handoff", {}) as Dictionary
	_check(
		StringName(handoff_snapshot.get("previous_role", &"")) == Authority.ROLE_PASSENGER
			and StringName(handoff_snapshot.get("new_role", &"")) == Authority.ROLE_PILOT
			and int(handoff_snapshot.get("previous_seat_generation", 0)) == 1
			and int(handoff_snapshot.get("new_seat_generation", 0)) == 1
			and int(handoff_snapshot.get("release_request_sequence", -1)) == 3
			and int(handoff_snapshot.get("claim_request_sequence", -1)) == 4
			and bool(handoff_snapshot.get("ready", false))
			and bool(handoff_snapshot.get("neutral_command_confirmed", false)),
		"the detached snapshot exposes generation-fenced emergency handoff readiness"
	)
	_check(
		not handoff_snapshot.has("occupant_peer_id")
			and not handoff_snapshot.has("avatar_id")
			and not handoff_snapshot.has("occupant")
			and int(handoff_snapshot.get("authority_event_sequence", -1))
			== int(emergency_snapshot.get("authority_event_sequence", -2)),
		"the emergency snapshot receipt contains no PII or object references"
	)
	var emergency_replay := craft.request_emergency_pilot_handoff(
		1,
		73,
		&"passenger_avatar",
		&"crew_port_00",
		3,
		4,
		emergency_avatar,
		1
	)
	_check(
		not bool(emergency_replay.get("accepted", false))
			and emergency_replay.get("status", &"") == &"seat_mismatch",
		"a replayed or cross-seat emergency request cannot escalate the replacement"
	)
	var emergency_release := craft.release_crew_role_occupant(
		1, 73, &"passenger_avatar", &"pilot_station", emergency_avatar, 5, 1
	)
	_check(
		bool(emergency_release.get("accepted", false))
			and not frame.is_occupant_registered(emergency_avatar)
			and authority.get_assignment(73, &"passenger_avatar").is_empty(),
		"the emergency pilot can be released through the normal authority and occupancy path"
	)
	var cleared_emergency_snapshot := craft.get_crew_role_gameplay_snapshot()
	_check(
		(cleared_emergency_snapshot.get("emergency_pilot_handoff", {}) as Dictionary).is_empty(),
		"detaching the emergency pilot clears the detached handoff receipt"
	)
	emergency_avatar.queue_free()

	craft.queue_free()
	await process_frame
	if _failures.is_empty():
		print("HALYARD_CREW_ROLE_GAMEPLAY_TEST: %d assertions passed" % _assertions)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)
		return
	quit(0)


func _first_damaged_system(model: ShipComponentDamage) -> StringName:
	for component_id: StringName in ShipComponentDamageType.COMPONENT_ORDER:
		if model.get_component_integrity(component_id) < 1.0:
			return component_id
	return ShipComponentDamageType.COMPONENT_FORWARD_HULL


func _check(condition: bool, message: String) -> void:
	_assertions += 1
	if not condition:
		_failures.append("FAIL: " + message)
