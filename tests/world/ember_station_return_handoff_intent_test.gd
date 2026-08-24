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
const ORBITAL_FRAME_ID: StringName = &"ember_system"

var _failures := 0
var _publication_count := 0
var _published_intent: Dictionary = {}
var _publication_binding: EmberSurfaceLoopProductionBinding
var _publication_reentry: Dictionary = {}


func _init() -> void:
	call_deferred(&"_run")


func _run() -> void:
	await _test_complete_evidence_publishes_once()
	await _test_host_and_actor_drift_abort()
	if _failures > 0:
		push_error("Ember station-return handoff intent failed: %d checks" % _failures)
		quit(1)
		return
	print("EMBER_STATION_RETURN_HANDOFF_INTENT_TEST_OK: generation-matched physical return publishes one authority-free Mudds intent")
	quit(0)


func _test_complete_evidence_publishes_once() -> void:
	var fixture := _fixture()
	var frame := fixture.frame as PlanetaryCoordinateFrame
	var session := fixture.session as PlanetaryTravelSession
	var host := fixture.host as EmberSurfaceLoopHost
	var binding := fixture.binding as EmberSurfaceLoopProductionBinding
	_publication_binding = binding
	binding.station_return_handoff_ready.connect(_on_handoff_ready)
	var stale_manifest := _manifest(session.get_attachment_generation() + 1)
	_check(
		session.admit_return_travel_intent(
			stale_manifest.manifest, ACTOR_INSTANCE_ID, CRAFT_INSTANCE_ID,
			session.get_generation(), session.get_attachment_generation()
		).reason == &"return_travel_attachment_mismatch",
		"stale manifest attachment is rejected before admission",
	)
	var admitted := binding.admit_planetary_relay_survey_return(
		_manifest(session.get_attachment_generation()),
		ACTOR_INSTANCE_ID, CRAFT_INSTANCE_ID
	)
	var actor_state_before := host.get_snapshot().actor_state as Dictionary
	var stale_reboard := session.submit_authorized_return_reboard(
		ACTOR_INSTANCE_ID, CRAFT_INSTANCE_ID, true, true,
		session.get_generation() + 1, session.get_attachment_generation()
	)
	var out_of_order := binding.submit_planetary_return_takeoff(
		null, ACTOR_INSTANCE_ID, CRAFT_INSTANCE_ID, true, false
	)
	var reboard := binding.submit_planetary_return_reboard(
		null, ACTOR_INSTANCE_ID, CRAFT_INSTANCE_ID, true, true
	)
	var reboard_replay := binding.submit_planetary_return_reboard(
		null, ACTOR_INSTANCE_ID, CRAFT_INSTANCE_ID, true, true
	)
	var takeoff := binding.submit_planetary_return_takeoff(
		null, ACTOR_INSTANCE_ID, CRAFT_INSTANCE_ID, true, false
	)
	var ascent := binding.submit_planetary_return_ascent(
		null, ACTOR_INSTANCE_ID, CRAFT_INSTANCE_ID, true,
		_absolute(frame, Vector3(0.0, 128_500.0, 0.0)), 5.0,
		frame.get_generation()
	)
	var orbit := binding.submit_planetary_return_orbit(
		null, ACTOR_INSTANCE_ID, CRAFT_INSTANCE_ID,
		_absolute(frame, Vector3(0.0, 140_000.0, 0.0)), 900.0,
		frame.get_generation()
	)
	var intent := orbit.get("station_return_handoff_intent", {}) as Dictionary
	var authority := intent.get("authority", {}) as Dictionary
	var snapshot := session.get_presentation_snapshot()
	var stale_take := binding.take_planetary_station_return_handoff_intent(
		binding.get_generation() + 1
	)
	var taken := binding.take_planetary_station_return_handoff_intent(
		binding.get_generation()
	)
	var take_replay := binding.take_planetary_station_return_handoff_intent(
		binding.get_generation()
	)
	var publish_replay := host.publish_station_return_handoff_intent(
		ACTOR_INSTANCE_ID, CRAFT_INSTANCE_ID,
		host.get_generation(), host.get_attachment_generation(),
		frame.get_generation()
	)
	_check(admitted.accepted, "accepted manifest is admitted into the retained session")
	_check(stale_reboard.reason == &"stale_generation", "stale evidence generation is rejected")
	_check(out_of_order.reason == &"return_takeoff_evidence_replayed", "out-of-order takeoff evidence is rejected")
	_check(reboard.accepted and takeoff.accepted and ascent.accepted and orbit.accepted, "real return evidence advances in exact order")
	_check(reboard_replay.reason == &"return_reboard_evidence_replayed", "duplicate reboard evidence is rejected")
	_check(
		_publication_count == 1 and _published_intent == intent \
			and _publication_reentry.reason == &"reentrant_call",
		"the binding publishes exactly one detached handoff",
	)
	_check(
		intent.get("destination_id") == &"mudds_shipyards" \
			and intent.get("evidence_sequence") == PackedStringArray(["reboard", "takeoff", "ascent", "orbit"]) \
			and int(intent.get("session_generation", 0)) == session.get_generation() \
			and int(intent.get("attachment_generation", 0)) == session.get_attachment_generation() \
			and int(intent.get("coordinate_frame_generation", 0)) == frame.get_generation(),
		"handoff correlates destination and all live generations",
	)
	_check(
		not bool(intent.get("arrival_confirmed", true)) \
			and authority.size() == 8 \
			and authority.values().all(func(value: Variant) -> bool: return value == false),
		"handoff explicitly claims neither arrival nor adjacent authority",
	)
	_check(
		snapshot.state_id == &"orbit_return" \
			and snapshot.station_return_handoff_published \
			and not snapshot.arrival_ready_receipt \
			and host.get_snapshot().actor_state == actor_state_before,
		"publication leaves travel in orbit and does not mutate the craft",
	)
	_check(stale_take.reason == &"stale_generation", "stale binding take is rejected")
	_check(
		taken.accepted and taken.intent == intent \
			and take_replay.reason == &"station_return_handoff_already_delivered" \
			and publish_replay.reason == &"station_return_handoff_already_published",
		"handoff delivery and publication are exactly once",
	)
	await _cleanup(fixture)
	_publication_binding = null


func _test_host_and_actor_drift_abort() -> void:
	var fixture := _fixture()
	var session := fixture.session as PlanetaryTravelSession
	var host := fixture.host as EmberSurfaceLoopHost
	var binding := fixture.binding as EmberSurfaceLoopProductionBinding
	binding.admit_planetary_relay_survey_return(
		_manifest(session.get_attachment_generation()),
		ACTOR_INSTANCE_ID, CRAFT_INSTANCE_ID
	)
	host.set("_attachment_generation", host.get_attachment_generation() + 1)
	var host_drift := binding.submit_planetary_return_reboard(
		null, ACTOR_INSTANCE_ID, CRAFT_INSTANCE_ID, true, true
	)
	_check(
		host_drift.reason == &"return_host_drift" \
			and bool((host_drift.get("return_session_abort", {}) as Dictionary).get("accepted", false)) \
			and session.get_presentation_snapshot().state_id == &"aborted" \
			and binding.get_planetary_relay_survey_return_snapshot().state == &"aborted",
		"retained host generation drift cleanly aborts the admitted return",
	)
	await _cleanup(fixture)

	fixture = _fixture()
	session = fixture.session as PlanetaryTravelSession
	host = fixture.host as EmberSurfaceLoopHost
	binding = fixture.binding as EmberSurfaceLoopProductionBinding
	binding.admit_planetary_relay_survey_return(
		_manifest(session.get_attachment_generation()),
		ACTOR_INSTANCE_ID, CRAFT_INSTANCE_ID
	)
	host.set("_player_instance_id", ACTOR_INSTANCE_ID + 1)
	var actor_drift := binding.submit_planetary_return_reboard(
		null, ACTOR_INSTANCE_ID, CRAFT_INSTANCE_ID, true, true
	)
	_check(
		actor_drift.reason == &"return_actor_drift" \
			and session.get_presentation_snapshot().state_id == &"aborted" \
			and (binding.get_snapshot().station_return_handoff_intent as Dictionary).is_empty(),
		"retained actor drift aborts without publishing a handoff",
	)
	await _cleanup(fixture)


func _fixture() -> Dictionary:
	var frame := _frame()
	var world_report: Dictionary = WorldValidatorScript.new().validate_composition(
		WORLD, null, TERRAIN
	)
	var landing_report: Dictionary = LandingValidatorScript.new().validate_composition(
		WORLD, TERRAIN, frame.get_snapshot(), REGION
	)
	var session := SessionScript.new(
		&"ember_station_return_handoff", WORLD, frame, world_report
	) as PlanetaryTravelSession
	_check(_drive_to_on_foot(session, frame, landing_report), "fixture reaches on-foot return admission")
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
	return {"frame": frame, "session": session, "host": host, "binding": binding}


func _manifest(attachment_generation: int) -> Dictionary:
	return {
		"accepted": true,
		"reason": &"return_manifest_ready",
		"manifest": {
			"activity_id": &"ember_beacon_survey",
			"activity_generation": 17,
			"attachment_generation": attachment_generation,
			"destination_id": &"mudds_shipyards",
			"movement_authority": false,
			"berth_authority": false,
			"reward_authority": false,
		},
	}.duplicate(true)


func _drive_to_on_foot(
		session: PlanetaryTravelSession,
		frame: PlanetaryCoordinateFrame,
		landing_report: Dictionary
	) -> bool:
	if not session.is_configuration_valid() \
			or not session.attach(&"ember_moon", frame, frame.get_generation(), 0, 0).accepted \
			or not session.start(0, 1).accepted:
		return false
	if not session.submit_orbit_approach_sample(
		true, _absolute(frame, Vector3(0.0, 140_000.0, 0.0)), 300.0,
		frame.get_generation(), 1, 1
	).accepted or not session.bind_landing_composition_report(landing_report, 1, 1).accepted:
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
		and session.submit_disembark_sample(true, true, 1, 1).accepted


func _frame() -> PlanetaryCoordinateFrame:
	var frame := FrameScript.new() as PlanetaryCoordinateFrame
	var body_center := _orbital_coordinate(100, -200, 30, Vector3.ZERO)
	frame.configure(
		&"ember_body", 120_000.0, ORBITAL_FRAME_ID, 10_000.0,
		body_center, Vector3.UP, Vector3.FORWARD, 5000.0, body_center
	)
	return frame


func _absolute(frame: PlanetaryCoordinateFrame, body_local: Vector3) -> Dictionary:
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


func _on_handoff_ready(intent: Dictionary) -> void:
	_publication_count += 1
	_published_intent = intent.duplicate(true)
	_publication_reentry = _publication_binding.take_planetary_station_return_handoff_intent(
		_publication_binding.get_generation()
	)


func _cleanup(fixture: Dictionary) -> void:
	(fixture.binding as EmberSurfaceLoopProductionBinding).free()
	(fixture.host as EmberSurfaceLoopHost).free()
	await process_frame


func _check(condition: bool, message: String) -> void:
	if condition:
		return
	_failures += 1
	push_error(message)
