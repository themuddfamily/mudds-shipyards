extends SceneTree

const Flow := preload("res://scripts/game/game_flow.gd")
const Cinder := preload("res://scripts/ships/cinder_cargo_hauler.gd")
const PlayerScene := preload("res://scenes/player/player.tscn")
const Director := preload("res://scripts/audio/audio_director.gd")
const Presenter := preload("res://scripts/ui/semantic_audio_cue_presenter.gd")
const EngineerBinding := preload("res://scripts/network/network_jovian_engineer_binding.gd")
const PassengerBinding := preload("res://scripts/network/network_halyard_passenger_binding.gd")
const Jovian := preload("res://scenes/ships/jovian_light_freighter.tscn")
const BodySimulation := preload("res://scripts/network/network_remote_body_simulation.gd")
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


# Count the real direct entry without replacing its consumer or outcome.
class CinderSubmissionSpy extends Cinder:
	var direct_submissions := 0
	func submit_navigator_ping(peer: int, avatar: StringName, sequence: int) -> Dictionary:
		direct_submissions += 1
		return super.submit_navigator_ping(peer, avatar, sequence)


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
var _host_session: NetworkEnetSessionAdapter
var _host_jovian: JovianLightFreighter
var _host_simulation: NetworkRemoteBodySimulation
var _bridge_results: Array[Dictionary] = []


func _init() -> void:
	call_deferred(&"_run")


func _run() -> void:
	if not _check(AudioServer.get_driver_name() == "Dummy", "fixture requires silent Dummy output"):
		_finish()
		return
	_flow = FlowRig.new()
	_craft = CinderSubmissionSpy.new()
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
	# A surviving standalone authority is foreign to a newly started host.
	# The positive host case below must acquire the actual network-owned roster.
	var session := Session.new()
	root.add_child(session)
	_check(bool(session.host(31500 + OS.get_process_id() % 500, 1).accepted), "host boundary uses a real live network adapter")
	_flow.network_session = session
	_flow._network_session_mode = &"server"
	_check(_flow._solo_crew_claim_is_current(), "host boundary starts with an actual surviving local claim")
	_flow._sync_optional_semantic_audio()
	_flow._bind_solo_navigator_audio_claim()
	_check(_flow._network_session_is_live() and _flow._solo_navigator_audio_claim().is_empty() and not _local_attached(), "pre-host solo authority remains excluded from the host local lane")
	_flow.network_session = null
	session.shutdown(&"test_complete")
	session.queue_free()
	_flow._network_session_mode = &""
	_flow._stand_from_solo_crew_seat()
	if not _check(await _until(func() -> bool: return not _flow._station_seated and not _flow._transition_busy and not _player.is_seated()), "post-session stand completes before a fresh standalone acquisition"):
		_finish()
		return
	if not await _exercise_host_local():
		_finish()
		return
	if not await _sit():
		_finish()
		return
	await _sample_fire(true)
	await _sample_fire(false)
	var clears_before_removal := _count(&"cinder_navigator_ping_cleared")
	before = _cues.size()
	_craft.queue_free()
	await process_frame
	_check(_count(&"cinder_navigator_ping_cleared") == clears_before_removal + 1 and _cues.size() == before + 1 and not _local_attached(), "exact ship removal delivers one active clear and retires local source")
	_check(_captions.has("Navigator ping accepted") and _captions.has("Navigator ping cleared"), "ordinary solo events use existing navigator caption presenter")
	_check(bool(_audio.get_audit_report().get("valid", false)), "request spy retains real Director Dummy/resource guards")

	_finish()


func _exercise_host_local() -> bool:
	_host_jovian = Jovian.instantiate() as JovianLightFreighter
	_host_jovian.position.x = 1000.0
	_host_simulation = BodySimulation.new()
	_flow.add_child(_host_jovian)
	_flow.add_child(_host_simulation)
	_host_jovian.set_physics_process(false)
	if not _start_host(11) or not await _sit():
		return false
	var owner := _flow._solo_crew_authority
	var first_claim: Dictionary = _flow._solo_navigator_audio_claim()
	var first_generation := _flow._solo_crew_seat_generation
	var local_composition: Node = _flow.optional_semantic_audio_composition._local_navigator_composition
	var old_callback: Callable = local_composition._local_clear_callback
	_check(owner == _flow._network_engineer_binding.role_authority_for(_craft) and _flow._network_engineer_binding.owns_role_authority(owner), "physical host chair acquires the actual engineer binding's Cinder roster")
	_check(_local_attached() and _bridge_attached() and _audio.get_semantic_audio_binding_count() == 3, "host local and independent bridge sources coexist beside the Cinder source")
	var refusal_sequence := int(first_claim.claim_sequence)
	var refused: Dictionary = _craft.submit_navigator_ping(1, Flow.SOLO_CREW_AVATAR_ID, refusal_sequence)
	var before_refusal := _cues.size()
	var refusal_requests := _audio.requests.size()
	_check(refused.get("accepted") == false and bool(_flow.optional_semantic_audio_composition.present_cinder_local_navigator_result(refused, first_claim, refusal_sequence).accepted), "actual host authority refusal forwards unchanged through the exact local claim")
	_check(_cues.size() == before_refusal + 1 and _count(&"cinder_navigator_ping_rejected") == 1 and _audio.requests.size() == refusal_requests + 1 and _audio.requests.back().stream_id == Director.STREAM_COMBAT_ALERT_PRIMARY and _captions.has("Navigator ping rejected"), "genuine local host refusal requests one existing alert and caption")
	_flow.optional_semantic_audio_composition.present_cinder_local_navigator_result(refused, first_claim, refusal_sequence)
	_check(_cues.size() == before_refusal + 1 and _audio.requests.size() == refusal_requests + 1, "actual refused host request is silent on replay")
	var accepted_before := _count(&"cinder_navigator_ping_accepted")
	var requests_before := _audio.requests.size()
	var direct_submissions := (_craft as CinderSubmissionSpy).direct_submissions
	await _sample_fire(true)
	var first_receipt: Dictionary = _craft.get_navigator_ping_snapshot().receipt
	_check(not first_receipt.is_empty() and _count(&"cinder_navigator_ping_accepted") == accepted_before + 1 and _audio.requests.size() == requests_before + 1, "host FIRE submits once and requests one accepted resident cue")
	_check((_craft as CinderSubmissionSpy).direct_submissions == direct_submissions + 1 and _bridge_results.is_empty(), "direct host input enters the actual ship consumer once without bridge resubmission")
	await _sample_fire(true)
	await _sample_fire(true)
	_check(_count(&"cinder_navigator_ping_accepted") == accepted_before + 1, "host held FIRE stays silent")
	await _sample_fire(false)
	await _sample_fire(true)
	await _sample_fire(false)
	var second_receipt: Dictionary = _craft.get_navigator_ping_snapshot().receipt
	_check(_count(&"cinder_navigator_ping_accepted") == accepted_before + 2 and second_receipt != first_receipt and (_craft as CinderSubmissionSpy).direct_submissions == direct_submissions + 2, "host release and repress produces one distinct actual result")
	var before := _cues.size()
	_flow.optional_semantic_audio_composition.present_cinder_local_navigator_result({"accepted": true, "consumed": true, "status": &"accepted", "effect": {"accepted": true, "receipt": second_receipt}}, first_claim, int(second_receipt.request_sequence))
	_check(_cues.size() == before, "replayed host result cannot request feedback twice")
	# No remote navigator can own this same chair concurrently. Exercise the
	# actual bridge's refusal, preserving its own result identity and replay fence.
	_flow._network_engineer_binding.loadmaster.publish_navigator_ping(1, &"unclaimed_bridge_navigator", first_generation, int(second_receipt.request_sequence) + 1)
	_check(_bridge_results.size() == 1 and _bridge_results[0].accepted == false and _count(&"cinder_navigator_ping_rejected") == 2 and _local_attached() and (_craft as CinderSubmissionSpy).direct_submissions == direct_submissions + 2 and _craft.get_navigator_ping_snapshot().receipt == second_receipt, "actual independent bridge refusal routes once while host local source remains attached")
	before = _cues.size()
	_flow._on_cinder_navigator_ping_result_forwarded(_bridge_results[0])
	_check(_cues.size() == before and _bridge_attached(), "bridge replay remains silent with both sources registered")
	var clears_before := _count(&"cinder_navigator_ping_cleared")
	_flow._stand_from_solo_crew_seat()
	if not _check(await _until(func() -> bool: return not _flow._station_seated and not _flow._transition_busy and not _player.is_seated()), "host ordinary stand completes physical occupant and ledger release"):
		return false
	_check(owner.get_assignment(1, Flow.SOLO_CREW_AVATAR_ID).is_empty() and _craft.get_crew_role_authority() == owner and _flow._solo_crew_authority == null, "host stand releases generic ledger while retaining network-owned authority")
	_flow._sync_optional_semantic_audio()
	_check(_local_attached() and _bridge_attached() and _count(&"cinder_navigator_ping_cleared") == clears_before and _craft.get_navigator_ping_snapshot().receipt == second_receipt, "captured local source survives retired GameFlow fields until genuine ship physics clear")
	_craft.set_physics_process(true)
	await physics_frame
	await process_frame
	_craft.set_physics_process(false)
	_check(_count(&"cinder_navigator_ping_cleared") == clears_before + 1 and not _local_attached() and _bridge_attached() and _audio.get_semantic_audio_binding_count() == 2, "actual Cinder physics cleanup clears once then retires only local source")
	_flow._update_solo_gunner_input(1.0 / 60.0)
	_craft._cleanup_detached_navigator()
	_check(_count(&"cinder_navigator_ping_cleared") == clears_before + 1, "repeated host cleanup creates no fabricated clear")
	if not await _sit():
		return false
	_check(_flow._solo_crew_authority == owner and _flow._solo_crew_seat_generation > first_generation, "host reseat uses shared authority with a fresh physical generation")
	before = _cues.size()
	old_callback.call(second_receipt, &"late_host_stand")
	_flow.optional_semantic_audio_composition.present_cinder_local_navigator_result({"accepted": false, "status": &"late"}, first_claim, 100)
	_check(_cues.size() == before and _local_attached(), "old host callback and old claim cannot affect reseat")
	await _sample_fire(true)
	await _sample_fire(false)
	_check(_count(&"cinder_navigator_ping_accepted") == accepted_before + 3, "host reseat first FIRE is fresh")
	var retiring_claim: Dictionary = _flow._solo_navigator_audio_claim()
	var retiring_composition: Node = _flow.optional_semantic_audio_composition._local_navigator_composition
	var retiring_callback: Callable = retiring_composition._local_clear_callback
	var retiring_receipt: Dictionary = _craft.get_navigator_ping_snapshot().receipt
	clears_before = _count(&"cinder_navigator_ping_cleared")
	before = _cues.size()
	requests_before = _audio.requests.size()
	_host_session.shutdown(&"host_audio_reentry")
	_check(not _local_attached() and not _bridge_attached() and _craft.get_crew_role_authority() == null and _count(&"cinder_navigator_ping_cleared") == clears_before and _cues.size() == before and _audio.requests.size() == requests_before and not _player.is_seated() and _flow._solo_navigator_audio_claim().is_empty() and _audio.get_semantic_audio_binding_count() == 0, "actual production session stop cancels physical claim and retires exact sources without stale feedback")
	_host_session.queue_free()
	if not _start_host(12) or not await _sit():
		return false
	before = _cues.size()
	retiring_callback.call(retiring_receipt, &"late_stopped_session")
	_flow.optional_semantic_audio_composition.present_cinder_local_navigator_result({"accepted": false, "status": &"late"}, retiring_claim, 100)
	_check(_cues.size() == before and _local_attached() and _bridge_attached() and _flow._solo_crew_authority != owner, "session re-entry fences old authority callbacks and restores both sources")
	await _sample_fire(true)
	await _sample_fire(false)
	_check(_count(&"cinder_navigator_ping_accepted") == accepted_before + 4, "new actual host session requests fresh local feedback")
	_host_session.shutdown(&"host_audio_complete")
	_host_session.queue_free()
	_flow.network_session = null
	_host_simulation.detach()
	_host_jovian.queue_free()
	_host_simulation.queue_free()
	return true


func _start_host(generation: int) -> bool:
	_host_session = Session.new()
	root.add_child(_host_session)
	if not _check(bool(_host_session.host(32000 + OS.get_process_id() % 500, 1).accepted), "host-local fixture starts an actual live adapter"):
		return false
	_flow.network_session = _host_session
	_flow._network_session_mode = &"server"
	_host_simulation.attach(_host_session)
	var binding := EngineerBinding.new()
	if not _check(binding.attach(_host_session, _host_jovian, _host_simulation, generation), "real engineer binding acquires its production Jovian authority"):
		return false
	var passenger := PassengerBinding.new()
	if not _check(passenger.attach(_host_session, _craft, _host_simulation, generation), "real passenger binding acquires Cinder roster and bridge"):
		binding.detach()
		return false
	binding.loadmaster = passenger
	_flow._network_engineer_binding = binding
	passenger.cinder_navigator_ping_result_forwarded.connect(_flow._on_cinder_navigator_ping_result_forwarded)
	passenger.cinder_navigator_ping_tombstones_forwarded.connect(_flow._on_cinder_navigator_ping_tombstones_forwarded)
	passenger.cinder_navigator_ping_result_forwarded.connect(func(result: Dictionary) -> void: _bridge_results.append(result.duplicate(true)))
	_host_session.session_stopped.connect(_flow._on_network_session_stopped)
	_flow._sync_optional_semantic_audio()
	return true


func _bridge_attached() -> bool:
	return bool(_flow.optional_semantic_audio_composition.get_snapshot().get("navigator", {}).get("attached", false))


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
