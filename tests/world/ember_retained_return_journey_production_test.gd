extends SceneTree

const BindingScript := preload("res://scripts/world/ember_surface_loop_production_binding.gd")
const HostScript := preload("res://scripts/world/ember_surface_loop_host.gd")
const AdapterScript := preload("res://scripts/world/ember_relay_survey_return_travel_adapter.gd")
const SessionScript := preload("res://scripts/world/planetary_travel_session.gd")
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
		and host.get_snapshot() == orbit_snapshot \
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
	print("EMBER_RETAINED_RETURN_JOURNEY_PRODUCTION_TEST_OK: manifest-driven evidence reaches retained orbit return")
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
