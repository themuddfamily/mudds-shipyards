extends SceneTree

const BindingScript := preload("res://scripts/world/ember_surface_loop_production_binding.gd")
const HostScript := preload("res://scripts/world/ember_surface_loop_host.gd")
const AdapterScript := preload("res://scripts/world/ember_relay_survey_return_travel_adapter.gd")
const SessionScript := preload("res://scripts/world/planetary_travel_session.gd")
const ReturnContractScript := preload("res://scripts/world/planetary_landing_return_contract.gd")
const FrameScript := preload("res://scripts/world/planetary_coordinate_frame.gd")
const WorldValidatorScript := preload("res://scripts/world/planetary_world_composition_validator.gd")
const LandingValidatorScript := preload("res://scripts/world/planetary_landing_composition_validator.gd")

const WORLD := preload("res://assets/world/planets/ember_moon_world.tres")
const TERRAIN := preload("res://assets/world/planets/ember_basalt_terrain.tres")
const REGION := preload("res://assets/world/planets/ember_caldera_landing_region.tres")

const ACTOR_INSTANCE_ID := 101
const CRAFT_INSTANCE_ID := 202
const ACTIVITY_GENERATION := 17
const ORBITAL_FRAME_ID: StringName = &"ember_system"


func _init() -> void:
	call_deferred(&"_run")


func _run() -> void:
	var frame := _frame()
	var world_report: Dictionary = WorldValidatorScript.new().validate_composition(
		WORLD, null, TERRAIN
	)
	var landing_report: Dictionary = LandingValidatorScript.new().validate_composition(
		WORLD, TERRAIN, frame.get_snapshot(), REGION
	)
	var session := SessionScript.new(
		&"ember_retained_return", WORLD, frame, world_report
	) as PlanetaryTravelSession
	var prepared := _drive_to_on_foot(session, frame, landing_report)

	# This real Host retains the same session that its physical cadence advances.
	# The focused binding fixture supplies only identities normally captured by
	# configure(); it does not substitute movement, berth, or GameFlow owners.
	var host := HostScript.new() as EmberSurfaceLoopHost
	root.add_child(host)
	host.set("_generation", session.get_generation())
	host.set("_attachment_generation", session.get_attachment_generation())
	host.set("_attached", true)
	host.set("_phase", EmberSurfaceLoopHost.Phase.ON_FOOT)
	host.set("_player_instance_id", ACTOR_INSTANCE_ID)
	host.set("_ship_instance_id", CRAFT_INSTANCE_ID)
	host.set("_session", session)
	var binding := BindingScript.new() as EmberSurfaceLoopProductionBinding
	binding.set("_host", host)
	binding.set("_player_instance_id", ACTOR_INSTANCE_ID)
	binding.set("_ship_instance_id", CRAFT_INSTANCE_ID)
	binding.set("_relay_return_travel", AdapterScript.new())

	var manifest := {
		"accepted": true,
		"reason": &"return_manifest_ready",
		"manifest": {
			"activity_id": &"ember_beacon_survey",
			"activity_generation": ACTIVITY_GENERATION,
			"attachment_generation": session.get_attachment_generation(),
			"destination_id": &"mudds_shipyards",
			"movement_authority": false,
			"berth_authority": false,
			"reward_authority": false,
		},
	}.duplicate(true)
	var foreign_actor := binding.admit_planetary_relay_survey_return(
		manifest, ACTOR_INSTANCE_ID + 1, CRAFT_INSTANCE_ID
	)
	var admitted := binding.admit_planetary_relay_survey_return(
		manifest, ACTOR_INSTANCE_ID, CRAFT_INSTANCE_ID
	)
	var after_admission := session.get_presentation_snapshot()
	var wrong_reboard := binding.submit_planetary_return_reboard(
		null, ACTOR_INSTANCE_ID + 1, CRAFT_INSTANCE_ID, true, true
	)
	var reboarded := binding.submit_planetary_return_reboard(
		null, ACTOR_INSTANCE_ID, CRAFT_INSTANCE_ID, true, true
	)
	var reboard_snapshot := host.get_snapshot()
	var reboard_replay := binding.submit_planetary_return_reboard(
		null, ACTOR_INSTANCE_ID, CRAFT_INSTANCE_ID, true, true
	)
	var reboard_after_replay := host.get_snapshot()
	var took_off := binding.submit_planetary_return_takeoff(
		null, ACTOR_INSTANCE_ID, CRAFT_INSTANCE_ID, true, false
	)
	var takeoff_snapshot := host.get_snapshot()
	var takeoff_replay := binding.submit_planetary_return_takeoff(
		null, ACTOR_INSTANCE_ID, CRAFT_INSTANCE_ID, true, false
	)
	var takeoff_after_replay := host.get_snapshot()
	var ascended := binding.submit_planetary_return_ascent(
		null, ACTOR_INSTANCE_ID, CRAFT_INSTANCE_ID, true,
		_absolute(frame, Vector3(0.0, 128_500.0, 0.0)), 5.0,
		frame.get_generation()
	)
	var ascent_snapshot := host.get_snapshot()
	var ascent_replay := binding.submit_planetary_return_ascent(
		null, ACTOR_INSTANCE_ID, CRAFT_INSTANCE_ID, true,
		_absolute(frame, Vector3(0.0, 128_500.0, 0.0)), 5.0,
		frame.get_generation()
	)
	var ascent_after_replay := host.get_snapshot()
	var orbit_return := binding.submit_planetary_return_orbit(
		null, ACTOR_INSTANCE_ID, CRAFT_INSTANCE_ID,
		_absolute(frame, Vector3(0.0, 140_000.0, 0.0)), 900.0,
		frame.get_generation()
	)
	var orbit_snapshot := host.get_snapshot()
	var orbit_replay := binding.submit_planetary_return_orbit(
		null, ACTOR_INSTANCE_ID, CRAFT_INSTANCE_ID,
		_absolute(frame, Vector3(0.0, 140_000.0, 0.0)), 900.0,
		frame.get_generation()
	)
	var orbit_after_replay := host.get_snapshot()
	var return_contract := ReturnContractScript.new() as PlanetaryLandingReturnContract
	var contract_ready := _drive_return_contract_to_takeoff(return_contract, frame)
	var stale_prepare := host.prepare_return_approach(
		return_contract, ACTOR_INSTANCE_ID, CRAFT_INSTANCE_ID,
		host.get_generation(), host.get_attachment_generation() + 1
	)
	var foreign_prepare := binding.prepare_planetary_return_approach(
		null, return_contract, ACTOR_INSTANCE_ID + 1, CRAFT_INSTANCE_ID
	)
	var approach_prepared := binding.prepare_planetary_return_approach(
		null, return_contract, ACTOR_INSTANCE_ID, CRAFT_INSTANCE_ID
	)
	var prepared_snapshot := host.get_snapshot()
	var contract_after_prepare := return_contract.get_snapshot()
	var prepare_replay := binding.prepare_planetary_return_approach(
		null, return_contract, ACTOR_INSTANCE_ID, CRAFT_INSTANCE_ID
	)
	var prepared_after_replay := host.get_snapshot()
	var approach_admitted := binding.admit_planetary_return_contract_approach(
		null, return_contract, ACTOR_INSTANCE_ID, CRAFT_INSTANCE_ID
	)
	var admitted_snapshot := host.get_snapshot()
	var contract_after_admission := return_contract.get_snapshot()
	var admit_replay := binding.admit_planetary_return_contract_approach(
		null, return_contract, ACTOR_INSTANCE_ID, CRAFT_INSTANCE_ID
	)
	var admitted_after_replay := host.get_snapshot()
	var arrival_observation := {
		"position": Vector3(0.0, 0.0, 50_000.0),
		"speed_meters_per_second": 900.0,
	}.duplicate(true)
	var stale_arrival := host.confirm_return_arrival_ready(
		return_contract, ACTOR_INSTANCE_ID, CRAFT_INSTANCE_ID,
		arrival_observation, host.get_generation(),
		host.get_attachment_generation() + 1
	)
	var foreign_arrival := binding.confirm_planetary_return_arrival_ready(
		null, return_contract, ACTOR_INSTANCE_ID + 1, CRAFT_INSTANCE_ID,
		arrival_observation
	)
	var invalid_arrival := binding.confirm_planetary_return_arrival_ready(
		null, return_contract, ACTOR_INSTANCE_ID, CRAFT_INSTANCE_ID,
		{"position": Vector3.INF, "speed_meters_per_second": 900.0}
	)
	var after_invalid_arrival := host.get_snapshot()
	var arrival_ready := binding.confirm_planetary_return_arrival_ready(
		null, return_contract, ACTOR_INSTANCE_ID, CRAFT_INSTANCE_ID,
		arrival_observation
	)
	var arrival_snapshot := host.get_snapshot()
	var contract_after_arrival := return_contract.get_snapshot()
	var arrival_replay := binding.confirm_planetary_return_arrival_ready(
		null, return_contract, ACTOR_INSTANCE_ID, CRAFT_INSTANCE_ID,
		arrival_observation
	)
	var arrival_after_replay := host.get_snapshot()
	var final_snapshot := session.get_presentation_snapshot()
	var adapter_snapshot := binding.get_planetary_relay_survey_return_snapshot()
	var valid: bool = prepared \
		and not foreign_actor.accepted \
		and foreign_actor.reason == &"return_travel_bound_actor_mismatch" \
		and admitted.accepted \
		and admitted.reason == &"return_travel_intent_admitted" \
		and after_admission.state_id == &"on_foot" \
		and after_admission.last_return_activity_generation == ACTIVITY_GENERATION \
		and after_admission.last_return_intent.actor_instance_id == ACTOR_INSTANCE_ID \
		and after_admission.last_return_intent.craft_instance_id == CRAFT_INSTANCE_ID \
		and not wrong_reboard.accepted \
		and wrong_reboard.reason == &"return_travel_bound_actor_mismatch" \
		and reboarded.accepted and reboarded.phase_id == &"reboarded" \
		and reboarded.travel_session.state_id == &"reboarded" \
		and reboard_snapshot.phase_id == &"reboarded" \
		and reboard_snapshot.travel_session.state_id == &"reboarded" \
		and not reboard_replay.accepted \
		and reboard_replay.reason == &"return_reboard_evidence_replayed" \
		and reboard_after_replay == reboard_snapshot \
		and took_off.accepted and took_off.phase_id == &"ascent" \
		and took_off.travel_session.state_id == &"takeoff" \
		and takeoff_snapshot.phase_id == &"ascent" \
		and takeoff_snapshot.travel_session.state_id == &"takeoff" \
		and not takeoff_replay.accepted \
		and takeoff_replay.reason == &"return_takeoff_evidence_replayed" \
		and takeoff_after_replay == takeoff_snapshot \
		and ascended.accepted and ascended.phase_id == &"ascent" \
		and ascended.travel_session.state_id == &"ascent" \
		and ascent_snapshot.phase_id == &"ascent" \
		and ascent_snapshot.travel_session.state_id == &"ascent" \
		and not ascent_replay.accepted \
		and ascent_replay.reason == &"return_ascent_evidence_replayed" \
		and ascent_after_replay == ascent_snapshot \
		and orbit_return.accepted and orbit_return.phase_id == &"orbit_return" \
		and orbit_return.travel_session.state_id == &"orbit_return" \
		and orbit_snapshot.phase_id == &"orbit_return" \
		and orbit_snapshot.travel_session.state_id == &"orbit_return" \
		and orbit_snapshot.transition_count == 3 \
		and not orbit_replay.accepted \
		and orbit_replay.reason == &"return_orbit_evidence_replayed" \
		and orbit_after_replay == orbit_snapshot \
		and contract_ready \
		and not stale_prepare.accepted \
		and stale_prepare.reason == &"stale_attachment_generation" \
		and not foreign_prepare.accepted \
		and foreign_prepare.reason == &"return_travel_bound_actor_mismatch" \
		and approach_prepared.accepted \
		and approach_prepared.reason == &"return_approach_ready" \
		and prepared_snapshot.phase_id == &"orbit_return" \
		and prepared_snapshot.travel_session.state_id == &"orbit_return" \
		and prepared_snapshot.travel_session.return_approach_ready \
		and not prepared_snapshot.travel_session.return_contract_approach_admitted \
		and prepared_snapshot.transition_count == orbit_snapshot.transition_count \
		and prepared_snapshot.actor_state == orbit_snapshot.actor_state \
		and not contract_after_prepare.return_approach_admitted \
		and not contract_after_prepare.arrival_ready \
		and contract_after_prepare.phase_id == &"takeoff" \
		and not prepare_replay.accepted \
		and prepare_replay.reason == &"return_approach_already_prepared" \
		and prepared_after_replay == prepared_snapshot \
		and approach_admitted.accepted \
		and approach_admitted.reason == &"orbit_return_approach_admitted" \
		and approach_admitted.return_target_id == &"mudds_shipyards" \
		and approach_admitted.next_caller_state == &"confirm_orbit_return" \
		and admitted_snapshot.phase_id == &"orbit_return" \
		and admitted_snapshot.travel_session.state_id == &"orbit_return" \
		and admitted_snapshot.travel_session.return_approach_ready \
		and admitted_snapshot.travel_session.return_contract_approach_admitted \
		and not admitted_snapshot.travel_session.arrival_ready_receipt \
		and admitted_snapshot.transition_count == orbit_snapshot.transition_count \
		and admitted_snapshot.actor_state == orbit_snapshot.actor_state \
		and contract_after_admission.return_approach_admitted \
		and not contract_after_admission.arrival_ready \
		and contract_after_admission.phase_id == &"takeoff" \
		and not admit_replay.accepted \
		and admit_replay.reason == &"return_contract_approach_already_admitted" \
		and admitted_after_replay == admitted_snapshot \
		and not stale_arrival.accepted \
		and stale_arrival.reason == &"stale_attachment_generation" \
		and not foreign_arrival.accepted \
		and foreign_arrival.reason == &"return_travel_bound_actor_mismatch" \
		and not invalid_arrival.accepted \
		and invalid_arrival.reason == &"orbit_arrival_prerequisites_not_met" \
		and after_invalid_arrival == admitted_snapshot \
		and arrival_ready.accepted \
		and arrival_ready.reason == &"orbit_arrival_ready" \
		and arrival_ready.return_target_id == &"mudds_shipyards" \
		and arrival_ready.next_caller_state == &"confirm_orbit_return" \
		and arrival_snapshot.phase_id == &"orbit_return" \
		and arrival_snapshot.travel_session.state_id == &"orbit_return" \
		and arrival_snapshot.travel_session.arrival_ready_receipt \
		and arrival_snapshot.transition_count == orbit_snapshot.transition_count \
		and arrival_snapshot.actor_state == orbit_snapshot.actor_state \
		and contract_after_arrival.phase_id == &"takeoff" \
		and contract_after_arrival.return_approach_admitted \
		and contract_after_arrival.arrival_ready \
		and contract_after_arrival.last_evidence.arrival_ready.observation \
			== arrival_observation \
		and not arrival_replay.accepted \
		and arrival_replay.reason == &"return_arrival_already_ready" \
		and arrival_after_replay == arrival_snapshot \
		and binding.get("_return_berth_adapter") == null \
		and final_snapshot.state_id == &"orbit_return" \
		and final_snapshot.last_return_activity_generation == ACTIVITY_GENERATION \
		and not adapter_snapshot.authority.movement \
		and not adapter_snapshot.authority.berth \
		and not adapter_snapshot.authority.reward \
		and not adapter_snapshot.authority.game_flow \
		and not session.audit().ship_movement_authority \
		and not session.audit().landing_authority \
		and not session.audit().reward_authority
	if not valid:
		push_error("retained Ember return journey production handoff failed")
		binding.free()
		host.free()
		session = null
		frame = null
		await process_frame
		quit(1)
		return
	binding.free()
	host.free()
	session = null
	frame = null
	await process_frame
	print("EMBER_RETAINED_RETURN_JOURNEY_PRODUCTION_TEST_OK: retained Mudds approach confirms detached arrival readiness")
	quit(0)


func _drive_to_on_foot(
		session: PlanetaryTravelSession,
		frame: PlanetaryCoordinateFrame,
		landing_report: Dictionary
	) -> bool:
	if not session.is_configuration_valid():
		return false
	if not session.attach(&"ember_moon", frame, frame.get_generation(), 0, 0).accepted:
		return false
	if not session.start(0, 1).accepted:
		return false
	if not session.submit_orbit_approach_sample(
		true, _absolute(frame, Vector3(0.0, 140_000.0, 0.0)), 300.0,
		frame.get_generation(), 1, 1
	).accepted:
		return false
	if not session.bind_landing_composition_report(landing_report, 1, 1).accepted:
		return false
	if not session.submit_descent_sample(
		_absolute(frame, Vector3(0.0, 122_500.0, 0.0)), 40.0,
		frame.get_generation(), 1, 1
	).accepted:
		return false
	var identity := {
		"world_id": landing_report.world_id,
		"body_id": landing_report.body_id,
		"region_id": landing_report.region_id,
		"terrain_profile_id": landing_report.terrain_profile_id,
	}
	return session.submit_landing_sample(true, identity, 1, 1).accepted \
		and session.submit_disembark_sample(true, true, 1, 1).accepted \
		and session.get_presentation_snapshot().state_id == &"on_foot"


func _drive_return_contract_to_takeoff(
		contract: PlanetaryLandingReturnContract,
		frame: PlanetaryCoordinateFrame
	) -> bool:
	var generation := 1
	var attachment_generation := 1
	if not contract.begin(
		generation, attachment_generation, frame.get_generation(), 1
	).accepted:
		return false
	if not contract.confirm_orbit_approach(
		true,
		{"position": Vector3(0.0, 140_000.0, 0.0), "speed_meters_per_second": 300.0},
		generation, attachment_generation
	).accepted:
		return false
	if not contract.confirm_landing(
		true, &"ember_caldera",
		{"world_id": &"ember_moon", "region_id": &"ember_caldera", "landing_confirmed": true},
		true, generation, attachment_generation
	).accepted:
		return false
	return contract.confirm_on_foot(
		&"pad_alpha_egress", &"caldera_relay_scan", true,
		generation, attachment_generation
	).accepted \
		and contract.confirm_reboarded(
			true, true, generation, attachment_generation
		).accepted \
		and contract.confirm_takeoff(
			true, false, generation, attachment_generation
		).accepted \
		and contract.get_phase_id() == &"takeoff"


func _frame() -> PlanetaryCoordinateFrame:
	var frame := FrameScript.new() as PlanetaryCoordinateFrame
	var body_center := _orbital_coordinate(100, -200, 30, Vector3.ZERO)
	frame.configure(
		&"ember_body", 120_000.0, ORBITAL_FRAME_ID, 10_000.0,
		body_center, Vector3.UP, Vector3.FORWARD, 5000.0, body_center
	)
	return frame


func _absolute(
		frame: PlanetaryCoordinateFrame, body_local: Vector3
	) -> Dictionary:
	var result := frame.body_local_to_orbital_position(
		body_local, frame.get_generation()
	)
	return (result.get("coordinate", {}) as Dictionary).duplicate(true)


func _orbital_coordinate(
		cell_x: int, cell_y: int, cell_z: int, offset: Vector3
	) -> Dictionary:
	return {
		"schema_version": FrameScript.COORDINATE_SCHEMA_VERSION,
		"frame_id": ORBITAL_FRAME_ID,
		"cell_x": cell_x,
		"cell_y": cell_y,
		"cell_z": cell_z,
		"offset_meters": offset,
	}
