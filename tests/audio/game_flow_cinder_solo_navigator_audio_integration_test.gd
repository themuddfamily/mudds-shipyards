extends SceneTree

const Flow := preload("res://scripts/game/game_flow.gd")
const Cinder := preload("res://scripts/ships/cinder_cargo_hauler.gd")
const PlayerScene := preload("res://scenes/player/player.tscn")
const Director := preload("res://scripts/audio/audio_director.gd")
const Presenter := preload("res://scripts/ui/semantic_audio_cue_presenter.gd")
const Session := preload("res://scripts/network/network_enet_session_adapter.gd")

# Omit unrelated Main construction and autonomous processing. All chair, floor,
# range, boarding, frame, ledger and input admission below are production code.
class FlowRig extends Flow:
	func _enter_tree() -> void:
		pass
	func _ready() -> void:
		pass
	func _process(_delta: float) -> void:
		pass
	func _physics_process(_delta: float) -> void:
		pass
	func _exit_tree() -> void:
		_cancel_solo_crew_seat()
		_release_solo_crew_authority()
		_detach_optional_semantic_audio()


# The production source explicitly supports a deterministic headless focus
# query. InputMap sampling, transformations, streams and owner guards stay real.
class FocusedLocalInput extends LocalShipInputSource:
	func _query_application_focus() -> bool:
		return true


class HudProbe extends CanvasLayer:
	func set_mode(_mode: String, _location: String = "") -> void:
		pass
	func set_objective(_text: String) -> void:
		pass
	func set_interaction(_text: String, _visible: bool = true) -> void:
		pass
	func toast(_title: String, _text: String = "") -> void:
		pass
	func _action_bindings_text(action: StringName) -> String:
		return str(action)
	func get_action_prompt(action: StringName) -> String:
		return str(action)


class RequestSpy extends Director:
	var requests: Array[Dictionary] = []
	func _play_resident(stream_id: StringName, bus: StringName, volume_db: float) -> bool:
		requests.append({"stream_id": stream_id, "bus": bus, "volume_db": volume_db,
			"effective_volume_db": volume_db + _effect_attenuation_db()})
		return super._play_resident(stream_id, bus, volume_db)


var _assertions := 0
var _failures := PackedStringArray()
var _cues: Array[StringName] = []
var _captions: Array[String] = []
var _presenter := Presenter.new()
var _flow: FlowRig
var _craft: CinderCargoHauler
var _player: PlayerController
var _audio: RequestSpy


func _init() -> void:
	call_deferred(&"_run")


func _run() -> void:
	if not _check(AudioServer.get_driver_name() == "Dummy", "fixture requires silent Dummy output"):
		_finish()
		return
	_flow = FlowRig.new()
	_craft = Cinder.new()
	_player = PlayerScene.instantiate() as PlayerController
	_audio = RequestSpy.new()
	var source := FocusedLocalInput.new()
	source.name = "LocalShipInputSource"
	_craft.add_child(source)
	_flow.player = _player
	_flow.audio = _audio
	_flow.hud = HudProbe.new()
	_flow.ships.append(_craft)
	_flow.active_ship = _craft
	_flow.phase = Flow.Phase.APPROACH_SHIP
	_flow.boarding_motion_time = 0.05
	_flow.disembarking_motion_time = 0.05
	_flow.add_child(_craft)
	_flow.add_child(_player)
	_flow.add_child(_audio)
	_flow.add_child(_flow.hud)
	root.add_child(_flow)
	await process_frame
	await physics_frame
	_craft.set_physics_process(false)
	_audio.semantic_cue_emitted.connect(_on_cue)
	_flow._initialize_optional_semantic_audio()
	_check(not _local_attached(), "solo navigator is absent before ordinary chair acquisition")
	if not await _sit():
		_finish()
		return
	_check(_craft.get_local_input_source() == source and _flow._solo_gunner_input_is_available(), "real retained local source passes production owner/focus/profile guards")
	_check(_local_attached() and _cues.is_empty(), "ordinary claim binds a silent explicit local lane")
	var first_authority := _flow._solo_crew_authority
	var first_claim: Dictionary = _flow._solo_navigator_audio_claim()
	var local_composition: Node = _flow.optional_semantic_audio_composition._local_navigator_composition
	var old_callback: Callable = local_composition._local_clear_callback
	var first_generation := _flow._solo_crew_seat_generation
	await _sample_fire(true)
	var first_receipt: Dictionary = _craft.get_navigator_ping_snapshot().receipt
	_check(not first_receipt.is_empty() and _count(&"cinder_navigator_ping_accepted") == 1, "actual FIRE submission records a real local receipt and one accepted cue")
	_check(_audio.requests.back().stream_id == Director.STREAM_UI_CONFIRM and _audio.requests.back().bus == &"UI", "actual FIRE selects existing resident confirmation")
	await _sample_fire(true)
	await _sample_fire(true)
	_check(_count(&"cinder_navigator_ping_accepted") == 1, "held FIRE creates no beep loop")
	await _sample_fire(false)
	await _sample_fire(true)
	_check(_count(&"cinder_navigator_ping_accepted") == 2, "release and repress creates exactly one fresh ping")
	await _sample_fire(false)
	var second_receipt: Dictionary = _craft.get_navigator_ping_snapshot().receipt
	_audio.set_reduced_dynamic_range(true)
	_flow._stand_from_solo_crew_seat()
	if not _check(await _until(func() -> bool: return not _flow._station_seated and not _flow._transition_busy and not _player.is_seated()), "ordinary stand completes real disembark and claim release"):
		_finish()
		return
	_check(_count(&"cinder_navigator_ping_cleared") == 1 and not _local_attached() and _craft.get_crew_role_authority() == null, "stand's actual authority detach clears once before unbinding local source")
	_check(_audio.requests[-2].stream_id == Director.STREAM_CANOPY_CLOSE and is_equal_approx(float(_audio.requests[-2].effective_volume_db), -17.0), "actual stand clear uses existing reduced-range resident request")
	if not await _sit():
		_finish()
		return
	_check(_flow._solo_crew_authority != first_authority and _flow._solo_crew_seat_generation == first_generation, "ordinary reseat replaces authority despite reused numeric generation")
	var before := _cues.size()
	old_callback.call(second_receipt, &"late_old_authority")
	_flow.optional_semantic_audio_composition.present_cinder_local_navigator_result({"accepted": false, "status": &"late"}, first_claim, 100)
	_check(_cues.size() == before and _local_attached(), "old callback and old exact claim cannot affect replacement")
	await _sample_fire(true)
	_check(_count(&"cinder_navigator_ping_accepted") == 3, "reseat's actual first FIRE requests fresh feedback")
	await _sample_fire(false)
	var authority := _flow._solo_crew_authority
	var generation := _flow._solo_crew_seat_generation
	var sequence := int(authority.get_last_intent(1, Flow.SOLO_CREW_AVATAR_ID).get("request_sequence", 0)) + 1
	_check(bool(authority.release(1, 1, Flow.SOLO_CREW_AVATAR_ID, Cinder.NAVIGATOR_STATION_SEAT_ID, sequence, generation).accepted), "external ledger release targets the exact actual solo claim")
	_craft._cleanup_detached_navigator()
	_flow._update_station_seat_flow()
	_check(_count(&"cinder_navigator_ping_cleared") == 2 and not _local_attached() and not _player.is_seated(), "forced ledger release clears once and production cancellation retires body/source")
	if not await _sit():
		_finish()
		return
	await _sample_fire(true)
	await _sample_fire(false)
	# A live host cannot acquire the standalone lane, even if stale local claim
	# fields survive a session boundary. Host-local feedback remains separate.
	var session := Session.new()
	root.add_child(session)
	_check(bool(session.host(31500 + OS.get_process_id() % 500, 1).accepted), "host boundary uses a real live network adapter")
	_flow.network_session = session
	_flow._network_session_mode = &"server"
	_check(_flow._solo_crew_claim_is_current(), "host boundary starts with an actual surviving local claim")
	_flow._sync_optional_semantic_audio()
	_flow._bind_solo_navigator_audio_claim()
	_check(_flow._network_session_is_live() and _flow._solo_navigator_audio_claim().is_empty() and not _local_attached(), "live host is excluded from the standalone local lane")
	_flow.network_session = null
	session.shutdown(&"test_complete")
	session.queue_free()
	_flow._network_session_mode = &""
	_flow._stand_from_solo_crew_seat()
	if not _check(await _until(func() -> bool: return not _flow._station_seated and not _flow._transition_busy and not _player.is_seated()), "post-session stand completes before a fresh standalone acquisition"):
		_finish()
		return
	if not await _sit():
		_finish()
		return
	await _sample_fire(true)
	await _sample_fire(false)
	before = _cues.size()
	_craft.queue_free()
	await process_frame
	_check(_count(&"cinder_navigator_ping_cleared") == 3 and _cues.size() == before + 1 and not _local_attached(), "exact ship removal delivers one active clear and retires local source")
	_check(_captions.has("Navigator ping accepted") and _captions.has("Navigator ping cleared"), "ordinary solo events use existing navigator caption presenter")
	_check(bool(_audio.get_audit_report().get("valid", false)), "request spy retains real Director Dummy/resource guards")

	_finish()


func _sit() -> bool:
	var seat := _craft.get_navigator_station_anchor().get_node("SoloPassengerSeatInteraction") as ShipCrewSeat
	# Only stage the real on-foot Player near the authored chair. No claim,
	# occupant tag, reservation, frame registration or floor flag is injected.
	_player.teleport_to(seat.get_entry_transform())
	await physics_frame
	await physics_frame
	if not _check(await _until(func() -> bool: return _player.is_on_floor() and _player.is_control_enabled()), "real Player settles on actual cabin floor before admission"):
		return false
	var frame := seat.get_role_contract().get("frame") as MovingInteriorFrame
	var area := _craft.get_node("ShipBoardingArea") as ShipBoardingArea
	if not _check(_player.get_interaction_origin().distance_to(seat.global_position) <= Flow.STATION_SEAT_MAX_REACH and frame.get_moving_frame() == _craft and area.is_available_for(_player) and not _flow._solo_safe_recovery_cabin(_craft).is_empty(), "staged approach retains production range/frame/boarding/floor support guards"):
		return false
	_flow._sit_in_solo_crew_seat(seat)
	return _check(await _until(func() -> bool: return bool(_flow.get_solo_crew_seat_status().get("seated", false)) and not _flow._transition_busy and _player.is_seated_at(seat.get_seat_anchor())), "actual ordinary navigator chair admission completes; refusal ends the attempt")


func _sample_fire(held: bool) -> void:
	if held:
		Input.action_press(&"fire")
	else:
		Input.action_release(&"fire")
	await physics_frame
	_flow._update_solo_gunner_input(1.0 / 60.0)


func _local_attached() -> bool:
	return bool(_flow.optional_semantic_audio_composition.get_snapshot().get("local_navigator", {}).get("attached", false))


func _until(predicate: Callable) -> bool:
	for tick in range(240):
		if bool(predicate.call()):
			return true
		await physics_frame
	return bool(predicate.call())


func _count(cue_id: StringName) -> int:
	return _cues.count(cue_id)


func _on_cue(source_id: StringName, cue_id: StringName, intensity: float, position: Vector3) -> void:
	if source_id != &"navigator":
		return
	_cues.append(cue_id)
	var caption: Dictionary = _presenter.present_cue(cue_id, source_id, intensity, position)
	if bool(caption.get("accepted", false)):
		_captions.append(str(caption.get("caption", "")))


func _check(condition: bool, description: String) -> bool:
	_assertions += 1
	if not condition:
		_failures.append("FAIL: " + description)
	return condition


func _finish() -> void:
	Input.action_release(&"fire")
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if is_instance_valid(_flow):
		_flow.queue_free()
	for failure in _failures:
		push_error(failure)
	if _failures.is_empty():
		print("GAME_FLOW_CINDER_SOLO_NAVIGATOR_AUDIO_INTEGRATION_TEST_OK: %d checks" % _assertions)
	quit(0 if _failures.is_empty() else 1)
