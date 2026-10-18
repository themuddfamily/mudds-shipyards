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
	var rejected := {"accepted": false, "status": &"navigator_identity_mismatch", "policy_version": &"network_cinder_navigator_ping_bridge_v1"}
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
	# A whole-Main re-entry detaches and re-attaches this composition. Re-creating
	# the two adapters on each re-attach abandoned the previous pair here, growing
	# one dead loadmaster and final-approach adapter per station re-entry for the
	# life of the session. The retained pair is the contract.
	var adapters_after_first_attach := composition.get_child_count()
	for _reattach_round in 4:
		_check(
			bool(composition.attach(director, null, null, 3).accepted),
			"retained optional owner re-attaches with a fresh navigator generation"
		)
		_check(
			director.get_semantic_audio_binding_count() == 2,
			"re-entry restores exactly the navigator source"
		)
		_check(
			composition.get_child_count() == adapters_after_first_attach,
			"re-attaching reuses the retained adapters instead of adding a dead pair"
		)
		_check(bool(composition.detach().accepted), "the re-attached composition detaches cleanly")
	_check(bool(composition.attach(director, null, null, 3).accepted), "final re-attach restores the navigator presentation")
	_check(director.get_semantic_audio_binding_count() == 2, "the final re-attach owns exactly the navigator source")
	var authority := CrewSeatRoleAuthority.new(1)
	_check(bool(authority.register_cinder_roster().accepted) and bool(cinder.attach_crew_role_authority(authority).accepted), "coexisting local source uses an actual Cinder roster")
	_check(bool(authority.claim(1, 1, &"local_navigator", Cinder.NAVIGATOR_STATION_SEAT_ID, &"passenger", 1).accepted), "coexisting local source owns the real navigator claim")
	var claim := {"craft": cinder, "authority": authority, "avatar_id": &"local_navigator", "seat_generation": 1, "claim_sequence": 1}
	_check(bool(composition.set_local_navigator_claim(claim).accepted) and director.get_semantic_audio_binding_count() == 3, "explicit local source registers independently beside bridge and unrelated source")
	var local_composition: Node = composition._local_navigator_composition
	var old_callback: Callable = local_composition._local_clear_callback
	_check(bool(composition.set_navigator_generation(3).accepted) and bool(composition.get_snapshot().local_navigator.attached) and director.get_semantic_audio_binding_count() == 3, "unchanged positive bridge generation preserves local registration")
	var event_count := _events.size()
	var local_outcome: Dictionary = cinder.submit_navigator_ping(1, &"local_navigator", 2)
	_check(bool(composition.present_cinder_local_navigator_result(local_outcome, claim, 2).accepted), "actual local outcome routes while bridge is registered")
	_check(bool(composition.present_cinder_navigator_bridge_result({"accepted": true, "status": &"navigator_ping_published", "wire_receipt": _navigator_receipt(3, 1, 30)}).accepted) and _events.size() == event_count + 2, "independent explicit presentation inputs each request one cue")
	_check(bool(composition.set_navigator_generation(4).accepted) and bool(composition.get_snapshot().local_navigator.attached) and director.get_semantic_audio_binding_count() == 3, "bridge replacement preserves exact local owner")
	_check(not bool(composition.present_cinder_local_navigator_result(local_outcome, claim, 2).accepted), "coexisting local result replay stays silent")
	var local_receipt: Dictionary = cinder.get_navigator_ping_snapshot().receipt
	_check(bool(authority.release(1, 1, &"local_navigator", Cinder.NAVIGATOR_STATION_SEAT_ID, 3, 1).accepted), "coexisting source releases exact shared ledger claim")
	composition.retire_local_navigator_if_lost()
	_check(bool(composition.get_snapshot().local_navigator.attached) and director.get_semantic_audio_binding_count() == 3, "lost local ledger claim retains source until ship commits real clear")
	event_count = _events.size()
	cinder._cleanup_detached_navigator()
	_check(_events.size() == event_count + 1 and not bool(composition.get_snapshot().local_navigator.attached) and bool(composition.get_snapshot().navigator.attached) and director.get_semantic_audio_binding_count() == 2, "ship-owned clear retires only local source and preserves bridge")
	old_callback.call(local_receipt, &"late_coexisting_clear")
	composition.clear_local_navigator()
	_check(_events.size() == event_count + 1 and director.get_semantic_audio_binding_count() == 2, "late local callback and repeated cleanup preserve independent bridge")
	_check(bool(authority.claim(1, 1, &"local_navigator", Cinder.NAVIGATOR_STATION_SEAT_ID, &"passenger", 4).accepted), "local source may reseat beside the retained bridge")
	var fresh_assignment: Dictionary = authority.get_assignment(1, &"local_navigator")
	var fresh_claim := {"craft": cinder, "authority": authority, "avatar_id": &"local_navigator", "seat_generation": int(fresh_assignment.seat_generation), "claim_sequence": int(fresh_assignment.claim_sequence)}
	_check(bool(composition.set_local_navigator_claim(fresh_claim).accepted), "fresh exact local claim binds after real clear")
	var fresh_outcome: Dictionary = cinder.submit_navigator_ping(1, &"local_navigator", 5)
	_check(bool(composition.present_cinder_local_navigator_result(fresh_outcome, fresh_claim, 5).accepted), "fresh actual result routes before whole composition teardown")
	var retiring_callback: Callable = composition._local_navigator_composition._local_clear_callback
	var retiring_receipt: Dictionary = cinder.get_navigator_ping_snapshot().receipt
	event_count = _events.size()
	composition.detach()
	_check(_events.size() == event_count and director.get_semantic_audio_binding_count() == 1, "whole composition detach retires both navigator sources without fabricating a ship clear")
	cinder.detach_crew_role_authority(authority)
	retiring_callback.call(retiring_receipt, &"late_whole_composition")
	_check(_events.size() == event_count and director.get_semantic_audio_binding_count() == 1, "actual ship clear and old callback remain silent after whole teardown")
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
