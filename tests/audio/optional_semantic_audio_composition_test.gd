extends SceneTree

const Director := preload("res://scripts/audio/audio_director.gd")
const Composition := preload("res://scripts/audio/optional_semantic_audio_composition.gd")
const Cinder := preload("res://scripts/ships/cinder_cargo_hauler.gd")

class MockCruise:
	extends Node
	signal engagement_changed(snapshot: Dictionary)
	signal tick_committed(receipt: Dictionary)
	signal final_approach_completed(receipt: Dictionary)

class RetainedSource:
	extends Node
	signal semantic_music_cue_emitted(cue_id: StringName, intensity: float)

var _assertions := 0
var _failures := PackedStringArray()
var _events: Array[Dictionary] = []

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var director := Director.new()
	var composition := Composition.new()
	var cinder := Cinder.new()
	var cruise := MockCruise.new()
	var retained := RetainedSource.new()
	root.add_child(director)
	await process_frame
	root.add_child(composition)
	root.add_child(cinder)
	root.add_child(cruise)
	root.add_child(retained)
	director.semantic_cue_emitted.connect(_on_cue)
	_check(bool(director.bind_semantic_audio_source(retained, &"music").accepted), "unrelated source binds")
	_check(bool(composition.attach(director, cinder, cruise, 1).accepted), "optional composition attaches with navigator presentation")
	_check(director.get_semantic_audio_binding_count() == 4, "four independent sources are registered")
	cinder.loadmaster_manifest_intent_accepted.emit({"seat_id": &"cinder_loadmaster_station", "manifest_generation": 1, "request_sequence": 2, "manifest_id": &"m", "route_id": &"r", "ready": true})
	cruise.engagement_changed.emit({"final_approach": {"target_generation": 1, "state_id": &"armed", "reason": &"final_approach_armed"}})
	_check(_has(&"cinder_loadmaster_manifest_ready") and _has(&"planetary_final_approach_armed"), "both optional sources route cues")
	_check(bool(composition.present_cinder_rejected({"reason": &"stale_sequence"}).accepted), "Cinder rejection forwards")
	_check(_has(&"cinder_loadmaster_rejected"), "Cinder rejection reaches director")
	var receipt := _navigator_receipt(1, 2, 12)
	var accepted := {
		"accepted": true,
		"status": &"navigator_ping_published",
		"wire_receipt": receipt.duplicate(true),
	}
	var accepted_before := accepted.duplicate(true)
	_check(bool(composition.present_cinder_navigator_bridge_result(accepted).accepted), "accepted navigator bridge envelope forwards")
	_check(accepted == accepted_before and _has(&"cinder_navigator_ping_accepted"), "navigator forwarding preserves the caller envelope and routes its receipt")
	var rejected := {"accepted": false, "status": &"navigator_identity_mismatch"}
	var rejected_before := rejected.duplicate(true)
	_check(bool(composition.present_cinder_navigator_bridge_result(rejected).accepted), "rejected navigator bridge envelope forwards")
	_check(rejected == rejected_before and _has(&"cinder_navigator_ping_rejected"), "navigator rejection routes without mutating its envelope")
	var released := {
		"accepted": true,
		"status": &"peer_released",
		"tombstones": [{"receipt": _navigator_clear(receipt, &"peer_released")}],
	}
	var released_before := released.duplicate(true)
	var release_result: Dictionary = composition.present_cinder_navigator_bridge_result(released)
	_check(bool(release_result.accepted) and int(release_result.emitted) == 1, "peer-release tombstone envelope clears the navigator cue")
	_check(released == released_before and _has(&"cinder_navigator_ping_cleared"), "release routing preserves the caller-owned tombstone")
	_check(bool(composition.set_navigator_generation(2).accepted), "navigator presentation re-enters at the next ship generation")
	_check(director.get_semantic_audio_binding_count() == 4, "generation replacement targets only the navigator router source")
	_check(not bool(composition.present_cinder_navigator_bridge_result(accepted).accepted), "prior-generation receipt is fenced after re-entry")
	var current_receipt := _navigator_receipt(2, 1, 20)
	_check(bool(composition.present_cinder_navigator_bridge_result({
		"accepted": true,
		"status": &"navigator_ping_published",
		"wire_receipt": current_receipt,
	}).accepted), "current-generation receipt routes after re-entry")
	var detached_envelope := {
		"accepted": true,
		"status": &"detached",
		"tombstones": [{"receipt": _navigator_clear(current_receipt, &"detached")}],
	}
	var detached_before := detached_envelope.duplicate(true)
	var detached_result: Dictionary = composition.present_cinder_navigator_bridge_result(detached_envelope)
	_check(bool(detached_result.accepted) and int(detached_result.emitted) == 1 and detached_envelope == detached_before, "bridge detach tombstone routes unchanged")
	var replacement := Cinder.new()
	root.add_child(replacement)
	_check(bool(composition.set_sources(replacement, null).accepted), "ship replacement unbinds old sources")
	_check(director.get_semantic_audio_binding_count() == 3, "replacement preserves navigator and unrelated sources")
	retained.semantic_music_cue_emitted.emit(&"retained_music", 1.0)
	_check(_has(&"retained_music"), "unrelated source survives replacement")
	_check(bool(composition.set_navigator_generation(0).accepted), "navigator presentation can be targeted off")
	_check(director.get_semantic_audio_binding_count() == 2, "navigator targeted unbind preserves Cinder and unrelated sources")
	_check(bool(composition.detach().accepted), "composition detaches")
	_check(director.get_semantic_audio_binding_count() == 1, "composition detach preserves unrelated source")
	_check(bool(composition.attach(director).accepted), "legacy attach remains valid without navigator configuration")
	_check(director.get_semantic_audio_binding_count() == 1 and not bool(composition.get_snapshot().navigator.attached), "legacy attach does not invent a navigator generation or source")
	_check(bool(composition.detach().accepted), "legacy attachment detaches cleanly")
	_check(bool(composition.attach(director, null, null, 3).accepted), "retained optional owner re-attaches with a fresh navigator generation")
	_check(director.get_semantic_audio_binding_count() == 2, "re-entry restores exactly the navigator source")
	composition.queue_free()
	await process_frame
	_check(director.get_semantic_audio_binding_count() == 1, "exit-tree cleanup removes only optional-owned router sources")
	for failure in _failures:
		push_error(failure)
	print("OPTIONAL_SEMANTIC_AUDIO_COMPOSITION_TEST: %d assertions" % _assertions)
	quit(0 if _failures.is_empty() else 1)

func _on_cue(source_id: StringName, cue_id: StringName, intensity: float, position: Vector3) -> void:
	_events.append({"source_id": source_id, "cue_id": cue_id, "intensity": intensity, "position": position})

func _has(cue_id: StringName) -> bool:
	for event in _events:
		if event.cue_id == cue_id:
			return true
	return false

func _navigator_receipt(ship_generation: int, request_sequence: int, server_tick: int) -> Dictionary:
	return {
		"peer_id": 7,
		"peer_generation": 3,
		"avatar_id": &"navigator",
		"seat_id": &"cinder_navigator_station",
		"seat_generation": 1,
		"role": &"passenger",
		"ship_id": &"cinder_cargo_hauler",
		"ship_generation": ship_generation,
		"request_sequence": request_sequence,
		"server_tick": server_tick,
		"migration_generation": 2,
		"action": &"passenger_ping",
		"payload": {"channel": &"sensor", "marker_id": &"route_beacon"},
	}

func _navigator_clear(receipt: Dictionary, reason: StringName) -> Dictionary:
	var clear := receipt.duplicate(true)
	clear.action = &"passenger_ping_clear"
	clear.request_sequence = int(receipt.request_sequence) + 1
	clear.server_tick = int(receipt.server_tick) + 1
	clear.payload = {
		"channel": receipt.payload.channel,
		"marker_id": receipt.payload.marker_id,
		"clear": true,
		"reason": reason,
		"source_request_sequence": receipt.request_sequence,
	}
	return clear

func _check(condition: bool, message: String) -> void:
	_assertions += 1
	if not condition:
		_failures.append(message)
