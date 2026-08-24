extends SceneTree

## Real Main proves a non-active registered Jovian ShipAudioRig traverses the
## production AudioDirector/router/HUD path and that the exact fleet source set
## is retired and restored without replaying its retained interruption state.

const MAIN_SCENE := preload("res://scenes/main.tscn")
const RoleAuthorityType := preload("res://scripts/ships/crew_seat_role_authority.gd")
const ComponentDamageType := preload("res://scripts/combat/ship_component_damage.gd")

var _assertions := 0
var _failures: Array[String] = []
var _events: Array[Dictionary] = []


func _init() -> void:
	call_deferred(&"_run")


func _run() -> void:
	var game := MAIN_SCENE.instantiate() as GameFlow
	root.add_child(game)
	await process_frame
	await physics_frame
	await process_frame
	var director := game.audio as AudioDirector
	var hud := game.hud as GameHUD
	var craft := game.get_node_or_null(^"JovianLightFreighter") as JovianLightFreighter
	_check(director != null and hud != null and craft != null, "production Main resolves routing endpoints and Jovian")
	if director == null or hud == null or craft == null:
		await _finish(game)
		return
	director.semantic_cue_emitted.connect(_on_semantic_cue)
	var fleet_report := game.get_fleet_ship_semantic_audio_report()
	_check(
		bool(fleet_report.get("all_registered_ships_bound", false))
			and bool(fleet_report.get("active_ship_bound", false))
			and int(fleet_report.get("bound_source_count", 0)) >= 5
			and craft.get_ship_id() in (fleet_report.get("bound_ship_ids", []) as Array),
		"GameFlow binds the active rig and every registered fleet rig exactly once"
	)
	_check(craft != game.active_ship, "Jovian exercises all-ship routing rather than active-ship-only routing")
	hud.set_captions_enabled(true)
	var authority := _build_authority()
	_check(
		bool(craft.attach_crew_role_authority(authority).get("accepted", false)),
		"production Jovian retains the existing sealed engineer authority"
	)
	var component_id := ComponentDamageType.COMPONENT_ENGINE_BAY
	craft.get_component_damage().record_damage(
		70.0, _component_local_position(craft, component_id)
	)
	craft.set("_landed", true)
	var started := _submit(craft, component_id, 2)
	await process_frame
	_check(
		bool(started.get("consumed", false))
			and _count_cue(&"crew_engineer_repair_started") == 1
			and _last_source_for(&"crew_engineer_repair_started") == &"ship",
		"authoritative non-active Jovian repair reaches AudioDirector through the ship router"
	)
	var presenter := hud.get("_semantic_audio_cue_presenter") as RefCounted
	var transcript: Array[Dictionary] = presenter.call(&"get_transcript") as Array[Dictionary]
	_check(
		_transcript_has(transcript, "Engineer repair started"),
		"production HUD consumes the routed cue with its truthful semantic caption"
	)

	root.remove_child(game)
	var events_after_detach := _events.size()
	var detached_report := game.get_fleet_ship_semantic_audio_report()
	craft.get_ship_audio_rig().semantic_engine_cue_emitted.emit(
		&"crew_engineer_repair_started", 0.5
	)
	_check(
		int(detached_report.get("bound_source_count", -1)) == 0
			and _events.size() == events_after_detach,
		"Main exit unbinds every exact fleet rig before detached sources can reach the director"
	)
	root.add_child(game)
	await process_frame
	await process_frame
	await process_frame
	var restored_report := game.get_fleet_ship_semantic_audio_report()
	_check(
		bool(restored_report.get("all_registered_ships_bound", false))
			and bool(restored_report.get("active_ship_bound", false))
			and _events.size() == events_after_detach
			and craft.get_engineer_repair_audio_snapshot().get("last_state", &"unexpected") == &"",
		"Main re-entry restores the fleet route without replaying the retained interruption snapshot"
	)
	var restarted := _submit(craft, component_id, 3)
	await process_frame
	_check(
		bool(restarted.get("consumed", false))
			and _count_cue(&"crew_engineer_repair_started") == 2,
		"one fresh authoritative repair restarts production routing after re-entry"
	)
	await _finish(game)


func _submit(
		craft: JovianLightFreighter, component_id: StringName, request_sequence: int
	) -> Dictionary:
	return craft.submit_crew_intent(
		1,
		77,
		&"production_route_engineer",
		RoleAuthorityType.ACTION_ENGINEER_REPAIR,
		{
			"system_id": component_id,
			"repair": 0.2,
			"system_generation": int(
				craft.get_engineer_gameplay_state().get("component_generation", 1)
			),
		},
		request_sequence
	)


func _build_authority() -> CrewSeatRoleAuthority:
	var authority := RoleAuthorityType.new(1) as CrewSeatRoleAuthority
	for seat: Array in [
		[&"pilot_station", RoleAuthorityType.ROLE_PILOT, &"pilot_seat_anchor"],
		[&"passenger_port_01", RoleAuthorityType.ROLE_ENGINEER, &"passenger_port_01"],
		[&"co_pilot_station", RoleAuthorityType.ROLE_PASSENGER, &"co_pilot_station"],
		[&"passenger_port_00", RoleAuthorityType.ROLE_PASSENGER, &"passenger_port_00"],
		[&"freight_defense_slot", RoleAuthorityType.ROLE_GUNNER, &""],
	]:
		authority.register_seat(
			seat[0], &"jovian_provisional", seat[1], &"jovian_walkable_interior", 1, seat[2]
		)
	authority.seal_roster()
	authority.claim(
		1, 77, &"production_route_engineer", &"passenger_port_01",
		RoleAuthorityType.ROLE_ENGINEER, 1
	)
	return authority


func _component_local_position(craft: HeroShip, component_id: StringName) -> Vector3:
	for state: Dictionary in craft.get_component_damage().get_component_states():
		if StringName(state.get("id", &"")) == component_id:
			return state.get("local_position", Vector3.INF) as Vector3
	return Vector3.INF


func _on_semantic_cue(
		source_id: StringName, cue_id: StringName, intensity: float, world_position: Vector3
	) -> void:
	if String(cue_id).begins_with("crew_engineer_repair_"):
		_events.append({
			"source_id": source_id,
			"cue_id": cue_id,
			"intensity": intensity,
			"world_position": world_position,
		})


func _count_cue(cue_id: StringName) -> int:
	var count := 0
	for event: Dictionary in _events:
		if event.get("cue_id", &"") == cue_id:
			count += 1
	return count


func _last_source_for(cue_id: StringName) -> StringName:
	for index in range(_events.size() - 1, -1, -1):
		if (_events[index] as Dictionary).get("cue_id", &"") == cue_id:
			return StringName((_events[index] as Dictionary).get("source_id", &""))
	return &""


func _transcript_has(transcript: Array[Dictionary], caption: String) -> bool:
	for entry: Dictionary in transcript:
		if str(entry.get("label", "")) == caption:
			return true
	return false


func _check(condition: bool, message: String) -> void:
	_assertions += 1
	if not condition:
		_failures.append(message)


func _finish(game: GameFlow) -> void:
	if is_instance_valid(game):
		game.queue_free()
		await process_frame
	for failure: String in _failures:
		push_error(failure)
	print("jovian_engineer_repair_production_audio_routing_test: %d assertions" % _assertions)
	quit(0 if _failures.is_empty() else 1)
