extends SceneTree

const FlowScript := preload("res://scripts/game/game_flow.gd")
const HalyardScene := preload("res://scenes/ships/halyard_crew_transport.tscn")
const Authority := preload("res://scripts/ships/crew_seat_role_authority.gd")
const ComponentDamage := preload("res://scripts/combat/ship_component_damage.gd")
const Presenter := preload("res://scripts/ui/semantic_audio_cue_presenter.gd")

# Observe the real dispatch boundary, including under Dummy, then retain the
# real Director's backend guard. This proves requests, never physical output.
class RequestSpy:
	extends AudioDirector
	var requests: Array[Dictionary] = []

	func _play_resident(stream_id: StringName, bus: StringName, volume_db: float) -> bool:
		requests.append({"stream_id": stream_id, "bus": bus, "volume_db": volume_db,
			"effective_volume_db": volume_db + _effect_attenuation_db()})
		return super._play_resident(stream_id, bus, volume_db)


var _events: Array[Dictionary] = []
var _captions: Array[Dictionary] = []
var _generic_cues: Array[StringName] = []
var _presenter := Presenter.new()
var _assertions := 0
var _failures := PackedStringArray()


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_check(AudioServer.get_driver_name() == "Dummy", "repair dispatch test requires silent Dummy output")
	if AudioServer.get_driver_name() != "Dummy":
		_finish()
		return
	var flow := FlowScript.new()
	var audio := RequestSpy.new()
	var halyard := HalyardScene.instantiate() as HalyardCrewTransport
	var replacement := HalyardScene.instantiate() as HalyardCrewTransport
	root.add_child(audio)
	root.add_child(halyard)
	root.add_child(replacement)
	await process_frame
	await physics_frame
	# Step the actual elapsed-work routine deterministically. No fake source
	# snapshot or fabricated repair receipt substitutes for accepted gameplay.
	halyard.set_physics_process(false)
	replacement.set_physics_process(false)
	_configure_source(halyard)
	_configure_source(replacement)
	flow.audio = audio
	flow.active_ship = halyard
	audio.semantic_cue_emitted.connect(_on_cue)
	audio.cue_started.connect(func(cue: StringName) -> void: _generic_cues.append(cue))
	flow._initialize_halyard_crew_semantic_audio()
	flow._sync_halyard_crew_semantic_audio()
	var binding: Node = flow.get("halyard_crew_semantic_audio_binding")
	_check(bool(binding.get_snapshot().attached) and audio.get_semantic_audio_binding_count() == 1,
		"production GameFlow binds the actual Halyard source through the real Director")
	_check(_has_cue(&"crew_engineer_joined"), "actual authority occupant reaches the existing crew caption route")
	var model := halyard.get_component_damage()
	var component_id := _damaged_component(model)
	var integrity_before := model.get_component_integrity(component_id)
	var started := _submit(halyard, component_id, 2)
	_check(bool(started.get("consumed", false)), "actual role authority admits real Halyard repair start")
	flow._sync_halyard_crew_semantic_audio()
	var first_started := halyard.get_crew_role_gameplay_snapshot()
	var sequence := int(first_started.authority_event_sequence)
	_check_request(audio, 0, AudioDirector.STREAM_UI_CONFIRM, -7.0)
	_check(_count_cue(&"crew_engineer_repair_started") == 1, "real start publishes one semantic caption identity")
	var count := audio.requests.size()
	flow._sync_halyard_crew_semantic_audio()
	binding.present_crew_snapshot(first_started)
	_check(audio.requests.size() == count, "duplicate source and normalized sequence observations cannot replay start")
	halyard.call(&"_advance_engineer_repair", 0.1)
	flow._sync_halyard_crew_semantic_audio()
	_check(float(halyard.get_engineer_repair_state().progress) > 0.0
		and int(halyard.get_crew_role_gameplay_snapshot().authority_event_sequence) == sequence,
		"real elapsed progress advances while role-authority ordering stays unchanged")
	_check(audio.requests.size() == count and _count_cue(&"crew_engineer_repair_progress") == 0,
		"elapsed progress creates neither sound requests nor repeated progress captions")
	halyard.set("_landed", false)
	halyard.call(&"_advance_engineer_repair", 0.1)
	flow._sync_halyard_crew_semantic_audio()
	var interrupted := halyard.get_crew_role_gameplay_snapshot()
	_check(interrupted.engineer_repair.status == &"interrupted"
		and interrupted.engineer_repair.reason == &"left_berth"
		and int(interrupted.authority_event_sequence) == sequence,
		"actual departure interruption reaches the bridge without a new role event")
	_check_request(audio, 1, AudioDirector.STREAM_COMBAT_ALERT_PRIMARY, -4.0)
	_check(int(interrupted.engineer_repair.resource_units) == 6
		and is_equal_approx(model.get_component_integrity(component_id), integrity_before),
		"interruption leaves repair truth and all six kits with their existing owners")
	binding.present_crew_snapshot(interrupted)
	flow._sync_halyard_crew_semantic_audio()
	_check(_count_cue(&"crew_engineer_repair_interrupted") == 1, "terminal interruption is once-only")
	halyard.set("_landed", true)
	_check(bool(_submit(halyard, component_id, 3).get("consumed", false)), "actual authority admits a fresh retry token")
	flow._sync_halyard_crew_semantic_audio()
	var second_started := halyard.get_crew_role_gameplay_snapshot()
	sequence = int(second_started.authority_event_sequence)
	_check_request(audio, 2, AudioDirector.STREAM_UI_CONFIRM, -7.0)
	count = audio.requests.size()
	binding.present_crew_snapshot(first_started)
	binding.present_crew_snapshot(interrupted)
	_check(audio.requests.size() == count, "stale previous-token start and terminal are silent during the retry")
	audio.set_reduced_dynamic_range(true)
	halyard.call(&"_advance_engineer_repair", HalyardCrewTransport.ENGINEER_REPAIR_DURATION_SECONDS)
	flow._sync_halyard_crew_semantic_audio()
	var completed := halyard.get_crew_role_gameplay_snapshot()
	_check(completed.engineer_repair.status == &"completed"
		and int(completed.authority_event_sequence) == sequence,
		"real elapsed completion forwards with unchanged role sequence")
	_check_request(audio, 3, AudioDirector.STREAM_TARGET_DESTROYED_PRIMARY, -1.0)
	_check(is_equal_approx(float(audio.requests[3].effective_volume_db), -13.0),
		"repair completion uses the current reduced-range effect attenuation")
	_check(int(completed.engineer_repair.resource_units) == 5
		and model.get_component_integrity(component_id) > integrity_before
		and int(completed.engineer_repair.receipt.operation.repaired_components) == 1,
		"real completion commits exactly one component repair and debits exactly one kit")
	count = audio.requests.size()
	flow._sync_halyard_crew_semantic_audio()
	binding.present_crew_snapshot(completed)
	binding.present_crew_snapshot(second_started)
	var invalid := completed.duplicate(true)
	(invalid.engineer_repair as Dictionary)["progress"] = NAN
	_check(not bool(binding.present_crew_snapshot(invalid).accepted), "invalid raw progress is rejected")
	var stale_generation := second_started.duplicate(true)
	(stale_generation.engineer_repair as Dictionary)["generation"] = -1
	_check(not bool(binding.present_crew_snapshot(stale_generation).accepted), "explicit stale raw presentation generation is rejected")
	_check(audio.requests.size() == count and _count_cue(&"crew_engineer_repair_completed") == 1,
		"duplicate terminal, stale active and invalid snapshots emit no extra request")
	_check(_caption_count(&"crew_engineer_repair_started", "Engineer repair started") == 2
		and _caption_count(&"crew_engineer_repair_interrupted", "Engineer repair interrupted") == 1
		and _caption_count(&"crew_engineer_repair_completed", "Engineer repair complete") == 1
		and _generic_cues.is_empty(), "existing captions retain their IDs exactly once per edge without generic caption echoes")
	_check(_all_timers_stopped(audio) and bool(audio.get_audit_report().valid),
		"repair requests reuse the fixed resident bank and voices without scheduling any tail")
	# Completion's priority must not occupy presentation admission forever.
	halyard.call(&"_advance_engineer_repair", HalyardCrewTransport.ENGINEER_REPAIR_COOLDOWN_SECONDS)
	model.record_damage(70.0, Vector3.INF)
	var next_component := _damaged_component(model)
	_check(bool(_submit(halyard, next_component, 4).get("consumed", false)), "real post-completion repair is admitted after cooldown")
	flow._sync_halyard_crew_semantic_audio()
	_check(audio.requests.size() == count + 1 and audio.requests[-1].stream_id == AudioDirector.STREAM_UI_CONFIRM,
		"a completed repair's old priority slots cannot suppress the next real start")
	halyard.call(&"_advance_engineer_repair", HalyardCrewTransport.ENGINEER_REPAIR_DURATION_SECONDS)
	flow._sync_halyard_crew_semantic_audio()
	_check(audio.requests.size() == count + 2 and audio.requests[-1].stream_id == AudioDirector.STREAM_TARGET_DESTROYED_PRIMARY,
		"the next real token also completes with one resident request")
	count = audio.requests.size()
	# A second real source may have the same role sequence and first token.
	_check(bool(_submit(replacement, _damaged_component(replacement.get_component_damage()), 2).get("consumed", false)),
		"replacement actual Halyard begins its own first token")
	flow.active_ship = replacement
	flow._sync_halyard_crew_semantic_audio()
	_check(audio.requests.size() == count + 1 and audio.get_semantic_audio_binding_count() == 1,
		"Halyard-to-Halyard source replacement resets independent repair ordering")
	flow.active_ship = halyard
	flow._sync_halyard_crew_semantic_audio()
	_check(audio.requests.size() == count + 1, "return to a retained completed source seeds history silently")
	flow._detach_halyard_crew_semantic_audio()
	_check(not bool(binding.get_snapshot().attached) and audio.get_semantic_audio_binding_count() == 0,
		"session detach retires the binding and exact semantic source")
	binding.semantic_crew_cue_emitted.emit(&"crew_engineer_repair_started", &"engineer", 1.0)
	_check(not bool(binding.present_crew_snapshot(first_started).accepted)
		and audio.requests.size() == count + 1, "unbound and detached input is silent")
	flow._initialize_halyard_crew_semantic_audio()
	flow._sync_halyard_crew_semantic_audio()
	_check(audio.requests.size() == count + 1, "re-entry seeds historical completion without replay")
	# The interruption snapshot retained on the other source is equally silent.
	replacement.set("_landed", false)
	replacement.call(&"_advance_engineer_repair", 0.1)
	flow.active_ship = replacement
	flow._sync_halyard_crew_semantic_audio()
	_check(audio.requests.size() == count + 1, "source entry seeds historical interruption without replay")
	flow.active_ship = null
	flow._sync_halyard_crew_semantic_audio()
	_check(not bool(binding.get_snapshot().attached) and audio.get_semantic_audio_binding_count() == 0,
		"leaving the crew ship retires the source without waiting for session cleanup")
	flow.active_ship = halyard
	flow._sync_halyard_crew_semantic_audio()
	_check(bool(binding.get_snapshot().attached) and audio.get_semantic_audio_binding_count() == 1
		and audio.requests.size() == count + 1, "crew ship re-entry rebinds once and keeps retained terminal history silent")
	flow._detach_halyard_crew_semantic_audio()
	flow.free()
	for node in [audio, halyard, replacement]:
		if is_instance_valid(node):
			node.free()
	_finish()


func _configure_source(craft: HalyardCrewTransport) -> void:
	var authority := Authority.new(1)
	_check(bool(authority.register_halyard_roster().accepted), "real session role roster is registered")
	_check(bool(craft.attach_crew_role_authority(authority).accepted), "real Halyard accepts role authority")
	_check(bool(authority.claim(1, 77, &"engineer_avatar", &"crew_port_01", Authority.ROLE_ENGINEER, 1).accepted),
		"actual authority admits an engineer assignment")
	craft.set("_landed", true)
	_check(bool(craft.get_component_damage().record_damage(70.0, Vector3.INF).accepted), "actual component owner records repairable damage")


func _damaged_component(model: ShipComponentDamage) -> StringName:
	for component_id: StringName in ComponentDamage.COMPONENT_ORDER:
		if model.get_component_integrity(component_id) < 1.0:
			return component_id
	return ComponentDamage.COMPONENT_ENGINE_BAY


func _submit(craft: HalyardCrewTransport, component_id: StringName, sequence: int) -> Dictionary:
	return craft.submit_crew_intent(1, 77, &"engineer_avatar", Authority.ACTION_ENGINEER_REPAIR,
		{"system_id": component_id, "repair": 0.5, "system_generation": 1}, sequence)


func _check_request(audio: RequestSpy, index: int, stream_id: StringName, volume_db: float) -> void:
	_check(audio.requests.size() == index + 1, "repair edge %d generates exactly one resident request" % index)
	if audio.requests.size() <= index:
		return
	var request := audio.requests[index]
	_check(request.stream_id == stream_id and request.bus == &"UI"
		and is_equal_approx(float(request.volume_db), volume_db), "repair edge %d uses its distinct resident template, UI bus and authored level" % index)


func _all_timers_stopped(audio: AudioDirector) -> bool:
	for candidate in audio.find_children("*", "Timer", true, false):
		if not (candidate as Timer).is_stopped():
			return false
	return true


func _on_cue(source_id: StringName, cue_id: StringName, intensity: float, position: Vector3) -> void:
	_events.append({"source_id": source_id, "cue_id": cue_id})
	var caption := _presenter.present_cue(cue_id, source_id, intensity, position)
	if bool(caption.get("accepted", false)):
		_captions.append(caption)


func _count_cue(cue_id: StringName) -> int:
	var count := 0
	for event in _events:
		if event.source_id == &"crew" and event.cue_id == cue_id:
			count += 1
	return count


func _has_cue(cue_id: StringName) -> bool:
	return _count_cue(cue_id) > 0


func _caption_count(cue_id: StringName, text: String) -> int:
	var count := 0
	for caption in _captions:
		if caption.cue_id == cue_id and caption.caption == text:
			count += 1
	return count


func _check(condition: bool, message: String) -> void:
	_assertions += 1
	if not condition:
		_failures.append(message)


func _finish() -> void:
	for failure in _failures:
		push_error(failure)
	print("game_flow_halyard_crew_audio_integration_test: %d assertions" % _assertions)
	quit(0 if _failures.is_empty() else 1)
