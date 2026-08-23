extends SceneTree

const Binding := preload("res://scripts/audio/station_defense_audio_binding.gd")
const HudType := preload("res://scripts/ui/hud.gd")
const Settings := preload("res://scripts/settings/runtime_settings.gd")


class ContentSnapshotSource extends Node:
	signal snapshot_changed(snapshot: Dictionary)

	var retained_snapshot := {
		"component_id": &"shipyard_perimeter_defense_content",
	}.duplicate(true)

	func get_snapshot() -> Dictionary:
		return retained_snapshot.duplicate(true)

	func publish(snapshot: Dictionary) -> void:
		retained_snapshot = snapshot.duplicate(true)
		snapshot_changed.emit(retained_snapshot.duplicate(true))


var _assertions := 0
var _failures := PackedStringArray()
var _events: Array[StringName] = []
var _caption_requests: Array[Dictionary] = []
var _pincer_semantic_events: Array[Dictionary] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var host := Node.new()
	host.add_user_signal("snapshot_changed")
	root.add_child(host)
	var settings := Settings.new()
	settings.captions_enabled = true
	var hud := HudType.new()
	root.add_child(hud)
	await process_frame
	hud.set_accessibility(settings.get_accessibility_descriptor())
	hud.bind_caption_event_submitter(Callable(self, &"_capture_caption_request"))
	var binding := Binding.new()
	binding.semantic_activity_cue_emitted.connect(_on_cue)
	binding.semantic_cue_emitted.connect(_on_semantic_cue.bind(hud))
	_check(bool(binding.attach(host).accepted), "station-defense host snapshot binding attaches")
	var base := _snapshot(&"idle", 0, false, [])
	_check(bool(binding.present_snapshot(base).accepted), "idle snapshot is accepted")
	_check(bool(binding.present_snapshot(_snapshot(&"active", 0, true, [])).accepted), "wave start snapshot is accepted")
	_check(_events.has(&"station_defense_wave_started"), "wave start emits a typed cue")
	var safe_asset := {"handle": {"asset_id": &"berth_safe"}, "damage_event_count": 0, "destroyed": false}
	_check(bool(binding.present_snapshot(_snapshot(&"active", 0, true, [safe_asset])).accepted), "safe asset snapshot is accepted")
	_check(_events.has(&"station_defense_asset_safe"), "safe asset emits a readiness cue")
	var danger_asset := {"handle": {"asset_id": &"berth_core"}, "damage_event_count": 1, "destroyed": false}
	_check(bool(binding.present_snapshot(_snapshot(&"active", 0, true, [danger_asset])).accepted), "asset danger snapshot is accepted")
	_check(_events.has(&"station_defense_asset_danger"), "asset damage emits danger cue")
	var count := _events.size()
	binding.present_snapshot(_snapshot(&"active", 0, true, [danger_asset]))
	_check(_events.size() == count, "duplicate asset damage is suppressed")
	var critical_asset := danger_asset.duplicate(true)
	critical_asset.destroyed = true
	_check(bool(binding.present_snapshot(_snapshot(&"active", 0, true, [critical_asset])).accepted), "asset critical snapshot is accepted")
	_check(_events.has(&"station_defense_asset_critical"), "asset destruction emits critical cue")
	_check(_events.has(&"station_defense_asset_destroyed"), "asset destruction emits destroyed cue")
	_check(
		_has_caption_text("! Station defense asset destroyed"),
		"the priority-100 asset-destroyed audio cue reaches the enabled production caption seam"
	)
	var recovered_asset := danger_asset.duplicate(true)
	recovered_asset.destroyed = false
	recovered_asset.damage_event_count = 0
	_check(bool(binding.present_snapshot(_snapshot(&"active", 0, true, [recovered_asset])).accepted), "asset recovery snapshot is accepted")
	_check(_events.has(&"station_defense_asset_recovered"), "asset recovery emits recovered cue")
	settings.captions_enabled = false
	hud.set_accessibility(settings.get_accessibility_descriptor())
	var caption_count := _caption_requests.size()
	_check(bool(binding.present_snapshot(_snapshot(&"completed", 1, false, [critical_asset])).accepted), "completion snapshot is accepted")
	_check(_events.has(&"station_defense_completed"), "completion emits a typed cue")
	_check(_caption_requests.size() == caption_count, "RuntimeSettings captions-off suppresses the cue without changing audio emission")
	_check(bool(binding.present_snapshot(_snapshot(&"aborted", 1, false, [critical_asset])).accepted), "abort snapshot is accepted")
	_check(_events.has(&"station_defense_aborted"), "abort emits a typed cue")
	_check(int(binding.get_snapshot().maximum_simultaneous_voices) == 2, "station-defense cues retain a two-voice ceiling")
	_check(bool(binding.detach().accepted), "detach clears station-defense binding")
	_check(binding.present_snapshot(base).reason == &"not_attached", "detached binding rejects stale snapshots")
	_check(int(binding.get_snapshot().generation) == 1, "detach advances station-defense generation")
	_test_generation_fenced_pincer_cues()
	host.free()
	hud.free()
	for failure in _failures:
		push_error(failure)
	print("station_defense_audio_binding_test: %d assertions" % _assertions)
	quit(0 if _failures.is_empty() else 1)


func _snapshot(
	state: StringName,
	wave_index: int,
	wave_active: bool,
	assets: Array,
	generation: int = 0,
	wave_id: StringName = &"",
	active_hostile_handles: Array = []
	) -> Dictionary:
	return {
		"activity_id": &"station_defense_alpha",
		"state_id": state,
		"generation": generation,
		"current_wave_index": wave_index,
		"wave_id": wave_id,
		"wave_active": wave_active,
		"active_hostile_handles": active_hostile_handles,
		"protected_assets": assets,
	}


func _content_snapshot(activity: Dictionary, breaker_state: StringName) -> Dictionary:
	var enriched_activity := activity.duplicate(true)
	enriched_activity["opening_tactic_id"] = &"core_breaker_outer_feint"
	enriched_activity["opening_tactic_state_id"] = breaker_state
	return {
		"component_id": &"shipyard_perimeter_defense_content",
		"host": {"activity": enriched_activity},
		"breaker_feint": {
			"tactic_id": &"core_breaker_outer_feint",
			"state_id": breaker_state,
			"generation": int(activity.generation),
		},
	}.duplicate(true)


func _test_generation_fenced_pincer_cues() -> void:
	var content_source := ContentSnapshotSource.new()
	root.add_child(content_source)
	var host := Node.new()
	host.add_user_signal("snapshot_changed")
	content_source.add_child(host)
	var binding := Binding.new()
	binding.semantic_cue_emitted.connect(_capture_pincer_semantic_cue)
	_check(bool(binding.set_reduced_dynamic_range(true).accepted), "tactic cues accept reduced dynamic range")
	_check(
		bool(binding.attach(host).accepted),
		"audio binding attaches through the host to its authoritative encounter-content snapshot source"
	)
	var beta := {"hostile_id": &"perimeter_raider_beta", "generation": 2}
	var gamma := {"hostile_id": &"perimeter_raider_gamma", "generation": 3}
	var inbound := _content_snapshot(
		_snapshot(&"active", 1, false, [], 7, &"dockside_relief", []), &"inbound"
	)
	var breaker_active := _content_snapshot(
		_snapshot(&"active", 1, true, [], 7, &"dockside_relief", [beta, gamma]), &"active"
	)
	var transitioned := _content_snapshot(
		_snapshot(&"active", 1, true, [], 7, &"dockside_relief", [beta, gamma]), &"transitioned"
	)
	var interrupted := _content_snapshot(
		_snapshot(&"active", 1, true, [], 7, &"dockside_relief", [gamma]), &"interrupted"
	)
	var cleared := _content_snapshot(_snapshot(&"completed", 1, false, [], 7), &"completed")
	content_source.publish(inbound)
	content_source.publish(inbound)
	content_source.publish(breaker_active)
	content_source.publish(breaker_active)
	_check(
		_count_pincer_cue(&"station_defense_breaker_inbound") == 1
		and _count_pincer_cue(&"station_defense_breaker_active") == 1
		and _count_pincer_cue(&"station_defense_crossfire_active") == 0,
		"inbound and active breaker cues are distinct while crossfire stays silent before handoff"
	)
	var before_reentry := _count_pincer_cue(&"station_defense_breaker_active")
	binding.detach()
	binding.attach(host)
	content_source.publish(breaker_active)
	_check(
		_count_pincer_cue(&"station_defense_breaker_active") == before_reentry
		and _count_pincer_cue(&"station_defense_crossfire_active") == 0,
		"same-generation detach/re-entry neither replays breaker-active nor announces crossfire early"
	)
	content_source.publish(transitioned)
	content_source.publish(transitioned)
	content_source.publish(interrupted)
	content_source.publish(interrupted)
	content_source.publish(cleared)
	content_source.publish(cleared)
	_check(
		_count_pincer_cue(&"station_defense_crossfire_active") == 1
		and _count_pincer_cue(&"station_defense_breaker_interrupted") == 1
		and _count_pincer_cue(&"station_defense_pincer_cleared") == 1,
		"authoritative handoff, interruption, and clear each emit their distinct cue once per generation"
	)
	_check(
		is_equal_approx(_pincer_cue_intensity(&"station_defense_breaker_inbound"), 0.525)
		and is_equal_approx(_pincer_cue_intensity(&"station_defense_breaker_active"), 0.675)
		and is_equal_approx(_pincer_cue_intensity(&"station_defense_crossfire_active"), 0.75)
		and is_equal_approx(_pincer_cue_intensity(&"station_defense_breaker_interrupted"), 0.6375)
		and is_equal_approx(_pincer_cue_intensity(&"station_defense_pincer_cleared"), 0.4875)
		and bool(binding.get_snapshot().reduced_dynamic_range),
		"all breaker and pincer semantic intensities follow the retained reduced-range policy"
	)
	var before_stale := _pincer_transition_count()
	content_source.publish(_content_snapshot(_snapshot(&"idle", 0, false, [], 8), &"idle"))
	content_source.publish(interrupted)
	_check(
		_pincer_transition_count() == before_stale
		and int(binding.get_snapshot().tactic_generation_fences.station_defense_alpha) == 8,
		"reset generation fences stale pre-reset breaker snapshots without replay"
	)
	var next_inbound := _content_snapshot(
		_snapshot(&"active", 1, false, [], 8, &"dockside_relief", []), &"inbound"
	)
	content_source.publish(next_inbound)
	content_source.publish(next_inbound)
	_check(
		_count_pincer_cue(&"station_defense_breaker_inbound") == 2,
		"a fresh activity generation admits one new breaker-inbound cue and deduplicates repeats"
	)
	binding.detach()
	content_source.free()


func _on_cue(cue_id: StringName, _activity_id: StringName, _intensity: float) -> void:
	_events.append(cue_id)


func _on_semantic_cue(
		source_id: StringName,
		cue_id: StringName,
		intensity: float,
		world_position: Vector3,
		hud: Node
	) -> void:
	hud.call(&"present_semantic_audio_cue", cue_id, source_id, intensity, world_position)


func _capture_caption_request(request: Dictionary) -> bool:
	_caption_requests.append(request.duplicate(true))
	return true


func _capture_pincer_semantic_cue(
	source_id: StringName,
	cue_id: StringName,
	intensity: float,
	world_position: Vector3
	) -> void:
	_pincer_semantic_events.append({
		"source_id": source_id,
		"cue_id": cue_id,
		"intensity": intensity,
		"world_position": world_position,
	})


func _count_pincer_cue(cue_id: StringName) -> int:
	var count := 0
	for event in _pincer_semantic_events:
		if event.cue_id == cue_id:
			count += 1
	return count


func _pincer_transition_count() -> int:
	return (
		_count_pincer_cue(&"station_defense_breaker_inbound")
		+ _count_pincer_cue(&"station_defense_breaker_active")
		+ _count_pincer_cue(&"station_defense_breaker_interrupted")
		+ _count_pincer_cue(&"station_defense_pincer_inbound")
		+ _count_pincer_cue(&"station_defense_crossfire_active")
		+ _count_pincer_cue(&"station_defense_pincer_wing_broken")
		+ _count_pincer_cue(&"station_defense_pincer_cleared")
	)


func _pincer_cue_intensity(cue_id: StringName) -> float:
	for event in _pincer_semantic_events:
		if event.cue_id == cue_id:
			return float(event.intensity)
	return -1.0


func _has_caption_text(text: String) -> bool:
	for request in _caption_requests:
		if str(request.get("text", "")) == text:
			return true
	return false


func _check(condition: bool, message: String) -> void:
	_assertions += 1
	if not condition:
		_failures.append(message)
