extends SceneTree

const GameFlowType := preload("res://scripts/game/game_flow.gd")
const NetworkAdapter := preload("res://scripts/network/network_enet_session_adapter.gd")
const Cinder := preload("res://scripts/ships/cinder_cargo_hauler.gd")
const Authority := preload("res://scripts/ships/crew_seat_role_authority.gd")
const Director := preload("res://scripts/audio/audio_director.gd")

var _assertions := 0
var _failures := PackedStringArray()
var _cues: Array[StringName] = []


class HudProbe extends CanvasLayer:
	var crew_snapshots: Array[Dictionary] = []

	func update_crew_role_status(snapshot: Dictionary) -> void:
		crew_snapshots.append(snapshot.duplicate(true))


func _init() -> void:
	call_deferred(&"_run")


func _run() -> void:
	var session := NetworkAdapter.new()
	var cinder := Cinder.new()
	var director := Director.new()
	var hud := HudProbe.new()
	root.add_child(session)
	root.add_child(cinder)
	root.add_child(director)
	root.add_child(hud)
	await process_frame
	var port := 30600 + (OS.get_process_id() % 500)
	_check(bool(session.host(port, 1).get("accepted", false)), "real production network adapter hosts navigator publication")

	var authority := Authority.new(1)
	for record in [
		[&"cinder_pilot", Authority.ROLE_PILOT],
		[&"cinder_gunner", Authority.ROLE_GUNNER],
		[&"cinder_engineer", Authority.ROLE_ENGINEER],
		[Cinder.LOADMASTER_STATION_SEAT_ID, Authority.ROLE_PASSENGER],
		[Cinder.NAVIGATOR_STATION_SEAT_ID, Authority.ROLE_PASSENGER],
	]:
		authority.register_seat(
			StringName(record[0]), Cinder.COMPONENT_ID, StringName(record[1]),
			&"cinder_cargo_walkable_interior", 1, StringName(record[0])
		)
	_check(bool(authority.seal_roster().get("accepted", false)) and bool(cinder.attach_crew_role_authority(authority).get("accepted", false)), "real Cinder retains its sealed physical navigator authority")
	_check(bool(authority.claim(1, 62, &"navigator_avatar", Cinder.NAVIGATOR_STATION_SEAT_ID, Authority.ROLE_PASSENGER, 1).get("accepted", false)), "navigator passenger occupies the exact physical station")

	var flow := GameFlowType.new()
	flow.network_session = session
	flow._network_session_mode = &"server"
	flow.active_ship = cinder
	flow.audio = director
	flow.hud = hud
	director.semantic_cue_emitted.connect(func(
		_source_id: StringName, cue_id: StringName, _intensity: float,
		_world_position: Vector3
	) -> void: _cues.append(cue_id))
	flow._initialize_optional_semantic_audio()
	var attached: Dictionary = flow._attach_network_ship_authority_composition()
	var composition := flow._network_ship_authority_composition
	var first_generation := int(flow._network_ship_generation)
	_check(bool(attached.get("accepted", false)) and first_generation > 0, "GameFlow attaches the real ship authority composition")
	_check(int(flow.optional_semantic_audio_composition.get_snapshot().get("navigator", {}).get("generation", 0)) == first_generation and flow._cinder_navigator_presentation_ship_generation == first_generation, "audio and HUD consumers bind the exact network ship generation")

	var observed_results: Array[Dictionary] = []
	var observed_tombstones: Array[Dictionary] = []
	composition.cinder_navigator_ping_result_forwarded.connect(func(result: Dictionary) -> void:
		observed_results.append(result.duplicate(true))
	)
	composition.cinder_navigator_ping_tombstones_forwarded.connect(func(result: Dictionary) -> void:
		observed_tombstones.append(result.duplicate(true))
	)
	var ping: Dictionary = composition.submit_cinder_navigator_ping(
		62, 3, &"navigator_avatar", 1, 2,
		{"channel": &"sensor", "marker_id": &"game_flow_beacon"}, 12, 1
	)
	_check(bool(ping.get("accepted", false)) and observed_results == [ping], "GameFlow consumers leave the real forwarded result envelope unchanged")
	_check(_cues.has(&"cinder_navigator_ping_accepted"), "forwarded navigator result reaches retained optional semantic audio")
	var active_hud: Dictionary = (
		hud.crew_snapshots.back() if not hud.crew_snapshots.is_empty() else {}
	)
	_check(str(active_hud.get("roles", {}).get("passenger", {}).get("occupant", "")).begins_with("navigator_avatar // PING ACTIVE"), "HUD overlay starts from the exact physical passenger assignment")
	_check(active_hud.get("cinder_navigator_ping", {}).get("ship_generation", 0) == first_generation, "HUD receives the current composition generation receipt")

	var detached: Dictionary = flow._detach_network_ship_authority_composition(&"production_reentry")
	var navigator_detach := detached.get("cinder_navigator_ping", {}) as Dictionary
	_check(not observed_tombstones.is_empty() and observed_tombstones.back() == navigator_detach, "GameFlow forwards the real detach tombstone envelope unchanged")
	_check(_cues.has(&"cinder_navigator_ping_cleared"), "detach tombstone reaches retained optional semantic audio before unbind")
	_check(hud.crew_snapshots.back().get("cinder_navigator_ping", {}).get("state") == &"cleared", "detach tombstone reaches retained navigator HUD before unbind")
	_check(not bool(flow.optional_semantic_audio_composition.get_snapshot().get("navigator", {}).get("attached", true)) and not bool(flow._cinder_navigator_ping_hud_composition.get_snapshot().get("attached", true)), "targeted detach unbinds navigator audio and HUD without discarding their owners")

	_check(bool(authority.release(1, 62, &"navigator_avatar", Cinder.NAVIGATOR_STATION_SEAT_ID, 3, 1).get("accepted", false)), "physical navigator passenger releases before re-entry rejection")
	var reattached: Dictionary = flow._attach_network_ship_authority_composition()
	var reentry_generation := int(flow._network_ship_generation)
	_check(bool(reattached.get("accepted", false)) and reentry_generation == first_generation + 1, "network composition re-entry advances one ship generation")
	_check(int(flow.optional_semantic_audio_composition.get_snapshot().get("navigator", {}).get("generation", 0)) == reentry_generation and flow._cinder_navigator_presentation_ship_generation == reentry_generation, "retained consumers rebind the exact re-entry generation")
	var hud_count_before_unoccupied_rejection := hud.crew_snapshots.size()
	var rejected: Dictionary = composition.submit_cinder_navigator_ping(
		62, 3, &"navigator_avatar", 1, 4, {}, 13, 1
	)
	_check(rejected.get("status", &"") == &"navigator_identity_mismatch" and observed_results.back() == rejected and _cues.has(&"cinder_navigator_ping_rejected"), "real re-entry rejection forwards unchanged to semantic audio")
	_check(hud.crew_snapshots.size() == hud_count_before_unoccupied_rejection and flow._get_cinder_navigator_crew_snapshot().is_empty(), "GameFlow never fabricates passenger occupancy from an unoccupied ping rejection")

	flow._detach_network_ship_authority_composition(&"test_complete")
	flow._detach_optional_semantic_audio()
	flow.free()
	session.shutdown(&"test_complete")
	session.queue_free()
	cinder.queue_free()
	director.queue_free()
	hud.queue_free()
	await process_frame
	if _failures.is_empty():
		print("GAME_FLOW_CINDER_NAVIGATOR_PRODUCTION_FLOW_TEST_OK: %d assertions" % _assertions)
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)


func _check(condition: bool, description: String) -> void:
	_assertions += 1
	if not condition:
		_failures.append("FAIL: " + description)
