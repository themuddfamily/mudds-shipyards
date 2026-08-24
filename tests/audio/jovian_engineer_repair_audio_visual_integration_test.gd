extends SceneTree

## One production Jovian proves that its authority-owned repair state drives
## matching visual and semantic-audio presentation without either presenter
## owning repair, component, collision, or audio-bank state.

const JOVIAN_SCENE := preload("res://scenes/ships/jovian_light_freighter.tscn")
const RoleAuthorityType := preload("res://scripts/ships/crew_seat_role_authority.gd")
const ComponentDamageType := preload("res://scripts/combat/ship_component_damage.gd")
const CaptionPresenterType := preload("res://scripts/ui/semantic_audio_cue_presenter.gd")

var _checks := 0
var _failures: Array[String] = []
var _repair_events: Array[Dictionary] = []
var _captions: Dictionary = {}
var _caption_presenter


func _init() -> void:
	call_deferred(&"_run")


func _run() -> void:
	_caption_presenter = CaptionPresenterType.new()
	var craft := JOVIAN_SCENE.instantiate() as JovianLightFreighter
	root.add_child(craft)
	await process_frame
	craft.get_ship_audio_rig().semantic_engine_cue_emitted.connect(_on_semantic_cue)
	var authority := _build_authority()
	_check(
		bool(craft.attach_crew_role_authority(authority).get("accepted", false)),
		"Jovian retains its sealed engineer-role authority"
	)
	var model := craft.get_component_damage()
	var component_id := ComponentDamageType.COMPONENT_ENGINE_BAY
	model.record_damage(70.0, _component_local_position(craft, component_id))
	craft.set("_landed", true)

	var started := _submit(craft, component_id, 1, 2)
	var started_audio := craft.get_engineer_repair_audio_snapshot()
	var started_visual := craft.get_engineer_repair_presentation_snapshot()
	_check(
		bool(started.get("consumed", false))
			and bool(started_visual.get("visible", false))
			and started_audio.get("last_state", &"") == &"started"
			and _last_repair_cue() == &"crew_engineer_repair_started",
		"authority-admitted repair starts matching visual and semantic audio cues"
	)
	_check(
		_authority_is_presentation_only(started_audio),
		"repair audio owns cues only, never repair or component authority"
	)

	craft.call(&"_advance_engineer_repair", 0.2)
	var progress_audio := craft.get_engineer_repair_audio_snapshot()
	var progress_visual := craft.get_engineer_repair_presentation_snapshot()
	_check(
		bool(progress_visual.get("visible", false))
			and int(progress_visual.get("visible_segment_count", 0)) == 4
			and progress_audio.get("last_state", &"") == &"progress"
			and _last_repair_cue() == &"crew_engineer_repair_progress",
		"authoritative progress advances the arc and matching bounded audio cue"
	)

	craft.call(&"_advance_engineer_repair", 0.2)
	var completed_audio := craft.get_engineer_repair_audio_snapshot()
	_check(
		craft.get_engineer_repair_state().get("status", &"") == &"completed"
			and not bool(craft.get_engineer_repair_presentation_snapshot().get("visible", true))
			and completed_audio.get("last_state", &"") == &"completed"
			and _last_repair_cue() == &"crew_engineer_repair_completed"
			and _audio_voices_clear(completed_audio)
			and completed_audio.get("last_retire_reason", &"") == &"repair_committed",
		"completion emits once and retires audio as the visual cue clears"
	)
	_check(
		_captions.get(&"crew_engineer_repair_started", "") == "Engineer repair started"
			and _captions.get(&"crew_engineer_repair_progress", "") == "Engineer repair progressing"
			and _captions.get(&"crew_engineer_repair_completed", "") == "Engineer repair complete",
		"start, progress, and completion retain truthful semantic captions"
	)

	craft.call(&"_advance_engineer_repair", 0.8)
	model.record_damage(5.0, _component_local_position(craft, component_id))
	_check(bool(_submit(craft, component_id, 1, 3).get("consumed", false)), "fresh repair starts after cooldown")
	craft.apply_damage(2.0, craft.to_global(_component_local_position(craft, component_id)), Vector3.UP)
	var interrupted_audio := craft.get_engineer_repair_audio_snapshot()
	_check(
		craft.get_engineer_repair_state().get("status", &"") == &"interrupted"
			and not bool(craft.get_engineer_repair_presentation_snapshot().get("visible", true))
			and interrupted_audio.get("last_state", &"") == &"interrupted"
			and _last_repair_cue() == &"crew_engineer_repair_interrupted"
			and _audio_voices_clear(interrupted_audio)
			and _captions.get(&"crew_engineer_repair_interrupted", "") == "Engineer repair interrupted",
		"authoritative damage interruption clears both presenters with a semantic caption"
	)

	_check(bool(_submit(craft, component_id, 1, 4).get("consumed", false)), "repair restarts before role release")
	var generation_before_release := int(craft.get_engineer_repair_audio_snapshot().get("generation", -1))
	var released := craft.release_crew_role(
		1, 77, &"repair_audio_engineer", &"passenger_port_01", 5
	)
	var released_audio := craft.get_engineer_repair_audio_snapshot()
	_check(
		bool(released.get("accepted", false))
			and int(released_audio.get("generation", -1)) > generation_before_release
			and bool(released_audio.get("attached", false))
			and released_audio.get("last_state", &"unexpected") == &""
			and _audio_voices_clear(released_audio)
			and not bool(craft.get_engineer_repair_presentation_snapshot().get("visible", true)),
		"role release retires audio and advances the same clear boundary as the work arc"
	)

	_check(
		bool(authority.claim(
			1, 77, &"repair_audio_engineer", &"passenger_port_01",
			RoleAuthorityType.ROLE_ENGINEER, 6
		).get("accepted", false)),
		"engineer can reclaim the released seat"
	)
	var selected_generation := int(craft.get_engineer_gameplay_state().get("component_generation", 0))
	_check(bool(_submit(craft, component_id, selected_generation, 7).get("consumed", false)), "repair starts before detach")
	var generation_before_detach := int(craft.get_engineer_repair_audio_snapshot().get("generation", -1))
	root.remove_child(craft)
	var detached_audio := craft.get_engineer_repair_audio_snapshot()
	_check(
		not bool(detached_audio.get("attached", true))
			and int(detached_audio.get("generation", -1)) > generation_before_detach
			and _audio_voices_clear(detached_audio)
			and not bool(craft.get_engineer_repair_presentation_snapshot().get("visible", true)),
		"ship detach emits interruption synchronously then leaves no stale audio or visual"
	)
	root.add_child(craft)
	await process_frame
	await process_frame
	_check(
		bool(craft.get_engineer_repair_audio_snapshot().get("attached", false))
			and craft.get_engineer_repair_audio_snapshot().get("last_state", &"unexpected") == &""
			and not bool(craft.get_engineer_repair_presentation_snapshot().get("visible", true)),
		"re-entry restores fresh hidden audio and visual generations"
	)

	_check(bool(_submit(craft, component_id, selected_generation, 8).get("consumed", false)), "fresh receipt restores work after re-entry")
	craft.apply_damage(craft.maximum_hull * 10.0, craft.global_position, Vector3.UP)
	var destroyed_audio := craft.get_engineer_repair_audio_snapshot()
	_check(
		craft.is_destroyed()
			and _audio_voices_clear(destroyed_audio)
			and destroyed_audio.get("last_state", &"unexpected") == &""
			and not bool(craft.get_engineer_repair_presentation_snapshot().get("visible", true)),
		"destruction retires repair audio and visual state without stale voices"
	)

	var generation_before_reuse := int(destroyed_audio.get("generation", -1))
	var reset := craft.reset_for_reuse(Transform3D.IDENTITY)
	var reused_audio := craft.get_engineer_repair_audio_snapshot()
	_check(
		bool(reset.get("accepted", false))
			and int(reused_audio.get("generation", -1)) > generation_before_reuse
			and bool(reused_audio.get("attached", false))
			and reused_audio.get("last_state", &"unexpected") == &""
			and _audio_voices_clear(reused_audio),
		"pooled reuse advances a fresh empty audio generation"
	)
	model.record_damage(70.0, _component_local_position(craft, component_id))
	craft.set("_landed", true)
	_check(
		bool(_submit(craft, component_id, 1, 9).get("consumed", false))
			and craft.get_engineer_repair_audio_snapshot().get("last_state", &"") == &"started"
			and bool(craft.get_engineer_repair_presentation_snapshot().get("visible", false)),
		"fresh authoritative receipt restores synchronized cues after reuse"
	)

	craft.queue_free()
	await process_frame
	_finish()


func _submit(
	craft: JovianLightFreighter,
	component_id: StringName,
	component_generation: int,
	request_sequence: int
	) -> Dictionary:
	return craft.submit_crew_intent(
		1,
		77,
		&"repair_audio_engineer",
		RoleAuthorityType.ACTION_ENGINEER_REPAIR,
		{
			"system_id": component_id,
			"repair": 0.2,
			"system_generation": component_generation,
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
		1, 77, &"repair_audio_engineer", &"passenger_port_01",
		RoleAuthorityType.ROLE_ENGINEER, 1
	)
	return authority


func _component_local_position(craft: HeroShip, component_id: StringName) -> Vector3:
	for state: Dictionary in craft.get_component_damage().get_component_states():
		if StringName(state.get("id", &"")) == component_id:
			return state.get("local_position", Vector3.INF) as Vector3
	return Vector3.INF


func _on_semantic_cue(cue_id: StringName, intensity: float) -> void:
	if not String(cue_id).begins_with("crew_engineer_repair_"):
		return
	_repair_events.append({"cue_id": cue_id, "intensity": intensity})
	var caption: Dictionary = _caption_presenter.present_cue(
		cue_id,
		&"Jovian engineer",
		intensity,
		Vector3.ZERO,
		{"transition_id": "repair_%d" % _repair_events.size()}
	)
	if bool(caption.get("accepted", false)):
		_captions[cue_id] = str(caption.get("caption", ""))


func _last_repair_cue() -> StringName:
	return StringName(_repair_events.back().get("cue_id", &"")) \
		if not _repair_events.is_empty() else &""


func _audio_voices_clear(snapshot: Dictionary) -> bool:
	return (snapshot.get("active_cue_slots", []) as Array).is_empty()


func _authority_is_presentation_only(snapshot: Dictionary) -> bool:
	var authority := snapshot.get("authority", {}) as Dictionary
	return not bool(authority.get("repair", true)) \
		and not bool(authority.get("components", true)) \
		and bool(authority.get("audio_cues", false))


func _check(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(message)


func _finish() -> void:
	if _failures.is_empty():
		print("JOVIAN_ENGINEER_REPAIR_AUDIO_VISUAL: %d checks, 0 failures" % _checks)
		quit(0)
		return
	for failure in _failures:
		push_error("FAIL: " + failure)
	quit(1)
