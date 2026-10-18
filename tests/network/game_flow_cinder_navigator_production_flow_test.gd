extends SceneTree

const GameFlowType := preload("res://scripts/game/game_flow.gd")
const NetworkAdapter := preload("res://scripts/network/network_enet_session_adapter.gd")
const Cinder := preload("res://scripts/ships/cinder_cargo_hauler.gd")
const Authority := preload("res://scripts/ships/crew_seat_role_authority.gd")
const Director := preload("res://scripts/audio/audio_director.gd")
const CuePresenter := preload("res://scripts/ui/semantic_audio_cue_presenter.gd")

var _assertions := 0
var _failures := PackedStringArray()
var _cues: Array[StringName] = []
var _captions: Array[String] = []
var _generic_cues: Array[StringName] = []
var _presenter := CuePresenter.new()


class RequestSpy extends Director:
	var requests: Array[Dictionary] = []

	func _play_resident(stream_id: StringName, bus: StringName, volume_db: float) -> bool:
		requests.append({"stream_id": stream_id, "bus": bus, "volume_db": volume_db,
			"effective_volume_db": volume_db + _effect_attenuation_db()})
		return super._play_resident(stream_id, bus, volume_db)


class HudProbe extends CanvasLayer:
	var crew_snapshots: Array[Dictionary] = []

	func update_crew_role_status(snapshot: Dictionary) -> void:
		crew_snapshots.append(snapshot.duplicate(true))


func _init() -> void:
	call_deferred(&"_run")


func _run() -> void:
	_check(AudioServer.get_driver_name() == "Dummy", "production navigator request test requires silent Dummy output")
	if AudioServer.get_driver_name() != "Dummy":
		quit(1)
		return
	var session := NetworkAdapter.new()
	var cinder := Cinder.new()
	var replacement_cinder := Cinder.new()
	var director := RequestSpy.new()
	var hud := HudProbe.new()
	root.add_child(session)
	root.add_child(cinder)
	root.add_child(replacement_cinder)
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
	director.semantic_cue_emitted.connect(_on_cue)
	director.cue_started.connect(func(cue_id: StringName) -> void: _generic_cues.append(cue_id))
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

	_check(director.requests.size() == 1 and director.requests.back().stream_id == Director.STREAM_UI_CONFIRM and director.requests.back().bus == &"UI", "actual host bridge acceptance selects the resident UI confirmation")
	var second_ping: Dictionary = composition.submit_cinder_navigator_ping(
		62, 3, &"navigator_avatar", 1, 3,
		{"channel": &"sensor", "marker_id": &"second_beacon"}, 13, 1
	)
	_check(bool(second_ping.get("accepted", false)) and director.requests.size() == 2 and _cues.size() == 2, "two actual distinct consecutive accepted receipts both select playback and captions")
	var silent_count := director.requests.size()
	flow._forward_cinder_navigator_presentation(second_ping, false)
	flow._forward_cinder_navigator_presentation(ping, false)
	flow._forward_cinder_navigator_presentation({}, false)
	_check(director.requests.size() == silent_count and _cues.size() == silent_count, "actual accepted replay, older receipt and malformed host result remain silent")
	director.set_reduced_dynamic_range(true)
	flow.active_ship = replacement_cinder
	var replacement: Dictionary = flow._attach_network_ship_authority_composition()
	var replacement_generation := int(flow._network_ship_generation)
	_check(bool(replacement.get("accepted", false)) and replacement_generation == first_generation + 1, "ship replacement advances exactly one network generation")
	_check(not observed_tombstones.is_empty() and int(observed_tombstones.back().get("tombstones", [])[0].get("receipt", {}).get("ship_generation", 0)) == first_generation, "replacement forwards the old generation's real detach tombstone before advancing presentation authority")
	_check(_cues.has(&"cinder_navigator_ping_cleared"), "replacement tombstone reaches retained optional semantic audio")
	_check(hud.crew_snapshots.back().get("cinder_navigator_ping", {}).get("state") == &"cleared", "replacement tombstone reaches retained navigator HUD")
	_check(director.requests.size() == silent_count + 1 and director.requests.back().stream_id == Director.STREAM_CANOPY_CLOSE and director.requests.back().bus == &"UI", "real replacement tombstone selects one distinct resident clear sound")
	_check(is_equal_approx(float(director.requests.back().effective_volume_db), -17.0), "real replacement clear respects reduced dynamic range")
	silent_count = director.requests.size()
	flow._forward_cinder_navigator_presentation(second_ping, false)
	flow._forward_cinder_navigator_presentation(observed_tombstones.back(), true)
	_check(director.requests.size() == silent_count, "old-generation receipt and clear cannot request playback after replacement")

	flow.active_ship = cinder
	var reattached: Dictionary = flow._attach_network_ship_authority_composition()
	var reentry_generation := int(flow._network_ship_generation)
	_check(bool(reattached.get("accepted", false)) and reentry_generation == first_generation + 2, "network composition re-entry advances once from the replacement generation")
	_check(int(flow.optional_semantic_audio_composition.get_snapshot().get("navigator", {}).get("generation", 0)) == reentry_generation and flow._cinder_navigator_presentation_ship_generation == reentry_generation, "retained consumers rebind the exact re-entry generation")
	var fresh: Dictionary = composition.submit_cinder_navigator_ping(
		62, 3, &"navigator_avatar", 1, 4,
		{"channel": &"sensor", "marker_id": &"reentry_beacon"}, 14, 1
	)
	_check(bool(fresh.get("accepted", false)), "re-entry publishes a fresh navigator receipt")
	_check(director.requests.size() == silent_count + 1 and director.requests.back().stream_id == Director.STREAM_UI_CONFIRM, "fresh re-entry generation selects acceptance playback")
	_check(is_equal_approx(float(director.requests.back().effective_volume_db), -19.0), "fresh acceptance preserves reduced-range attenuation across generation replacement")
	_check(bool(authority.handoff(
		1, 62, &"navigator_avatar", Cinder.NAVIGATOR_STATION_SEAT_ID, 5,
		63, &"replacement_navigator", Authority.ROLE_PASSENGER, 1, 1
	).get("accepted", false)), "physical navigator authority hands the seat to a new passenger")
	var hud_count_before_old_clear := hud.crew_snapshots.size()
	var old_peer_release: Dictionary = composition.release_peer(62)
	_check(bool(old_peer_release.get("accepted", false)) and not (old_peer_release.get("cinder_navigator_ping", {}).get("tombstones", []) as Array).is_empty(), "old navigator peer publishes its real clear tombstone after handoff")
	_check(hud.crew_snapshots.size() == hud_count_before_old_clear and str(flow._get_cinder_navigator_crew_snapshot().get("roles", {}).get("passenger", {}).get("occupant", "")) == "replacement_navigator", "old navigator clear cannot decorate the new physical passenger")
	_check(bool(authority.release(1, 63, &"replacement_navigator", Cinder.NAVIGATOR_STATION_SEAT_ID, 2, 1).get("accepted", false)), "replacement navigator releases before the unoccupied rejection")
	var hud_count_before_unoccupied_rejection := hud.crew_snapshots.size()
	var rejected: Dictionary = composition.submit_cinder_navigator_ping(
		62, 3, &"navigator_avatar", 1, 6, {}, 15, 1
	)
	_check(rejected.get("status", &"") == &"navigator_identity_mismatch" and observed_results.back() == rejected and _cues.has(&"cinder_navigator_ping_rejected"), "real re-entry rejection forwards unchanged to semantic audio")
	_check(hud.crew_snapshots.size() == hud_count_before_unoccupied_rejection and flow._get_cinder_navigator_crew_snapshot().is_empty(), "GameFlow never fabricates passenger occupancy from an unoccupied ping rejection")

	_check(director.requests.back().stream_id == Director.STREAM_COMBAT_ALERT_PRIMARY and director.requests.back().bus == &"UI", "genuine host rejection selects the distinct resident UI alert")
	_check(is_equal_approx(float(director.requests.back().effective_volume_db), -16.0), "genuine rejection respects reduced dynamic range")
	silent_count = director.requests.size()
	flow._forward_cinder_navigator_presentation(rejected, false)
	_check(director.requests.size() == silent_count, "exact genuine rejection replay cannot repeat playback")
	_check(_captions.has("Navigator ping accepted") and _captions.has("Navigator ping rejected") and _captions.has("Navigator ping cleared"), "actual host outcomes retain all navigator captions")
	_check(_generic_cues.is_empty(), "production navigator dispatch emits no generic cue echo")
	_check(bool(director.get_audit_report().get("valid", false)), "Dummy production requests preserve the resident bank and playback guard")
	flow._detach_network_ship_authority_composition(&"test_complete")
	flow._detach_optional_semantic_audio()
	silent_count = director.requests.size()
	flow._forward_cinder_navigator_presentation(fresh, false)
	flow._forward_cinder_navigator_presentation(rejected, false)
	_check(director.requests.size() == silent_count, "detached host presentation cannot select navigator playback")
	flow.free()
	session.shutdown(&"test_complete")
	session.queue_free()
	cinder.queue_free()
	replacement_cinder.queue_free()
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


func _on_cue(source_id: StringName, cue_id: StringName, intensity: float, position: Vector3) -> void:
	if source_id != &"navigator":
		return
	_cues.append(cue_id)
	var presentation: Dictionary = _presenter.present_cue(cue_id, source_id, intensity, position)
	if bool(presentation.get("accepted", false)):
		_captions.append(str(presentation.get("caption", "")))


func _check(condition: bool, description: String) -> void:
	_assertions += 1
	if not condition:
		_failures.append("FAIL: " + description)
