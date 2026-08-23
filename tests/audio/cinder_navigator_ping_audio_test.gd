extends SceneTree

const Director := preload("res://scripts/audio/audio_director.gd")
const Composition := preload("res://scripts/audio/cinder_navigator_ping_audio_composition.gd")
const Bridge := preload("res://scripts/network/network_cinder_navigator_ping_bridge.gd")
const Cinder := preload("res://scripts/ships/cinder_cargo_hauler.gd")
const CuePresenter := preload("res://scripts/ui/semantic_audio_cue_presenter.gd")

var _assertions := 0
var _failures := PackedStringArray()
var _events: Array[Dictionary] = []
var _captions: Array[String] = []
var _typed_cues: Array[StringName] = []
var _presenter := CuePresenter.new()


class BridgeAdapter:
	var migration_generation := 2
	func get_migration_snapshot() -> Dictionary:
		return {"migration_generation": migration_generation}
	func publish_crew_snapshot(_snapshot: Array) -> Dictionary:
		return {"accepted": true}


func _init() -> void:
	call_deferred(&"_run")


func _run() -> void:
	var director := Director.new()
	var composition := Composition.new()
	var cinder := Cinder.new()
	root.add_child(director)
	root.add_child(composition)
	root.add_child(cinder)
	await process_frame
	director.semantic_cue_emitted.connect(_on_cue)
	_check(bool(composition.attach(director, 1).get("accepted", false)), "navigator composition binds to AudioDirector")
	_check(director.get_semantic_audio_binding_count() == 1, "one targeted navigator source is registered")
	composition._binding.semantic_navigator_ping_cue_emitted.connect(func(cue_id: StringName, _intensity: float) -> void: _typed_cues.append(cue_id))

	var bridge := Bridge.new()
	var bridge_adapter := BridgeAdapter.new()
	_check(bool(bridge.attach(bridge_adapter, cinder).get("accepted", false)), "real Cinder navigator bridge attaches")
	var rejected := bridge.submit_ping(7, 3, &"navigator", 1, 1, {}, 2, 2)
	_check(StringName(rejected.get("status", &"")) == &"authority_unavailable", "real bridge rejection retains its production result shape")
	_check(bool(composition.present_bridge_result(rejected).get("accepted", false)), "bridge rejection becomes a navigator-specific semantic cue")
	var typed_after_rejection := _typed_cues.size()
	_check(not composition.present_bridge_result(rejected).get("accepted", false) and _typed_cues.size() == typed_after_rejection, "exact rejected-result replay is deduplicated")

	var receipt := _wire_receipt()
	var accepted_result := _accepted_result(receipt)
	_check(bool(composition.present_bridge_result(accepted_result).get("accepted", false)), "real accepted bridge-result shape emits the navigator acceptance cue")
	var typed_after_accept := _typed_cues.size()
	_check(not composition.present_bridge_result(accepted_result).get("accepted", false) and _typed_cues.size() == typed_after_accept, "exact accepted receipt replay is deduplicated before fencing")

	var altered_replay := receipt.duplicate(true)
	altered_replay.server_tick = 13
	_check(composition._binding.present_receipt(altered_replay).get("reason") == &"stale_request_sequence", "same request with a changed tick is stale rather than an exact replay")
	var wrong_lifecycle := receipt.duplicate(true)
	wrong_lifecycle.ship_generation = 2
	wrong_lifecycle.request_sequence = 3
	wrong_lifecycle.server_tick = 13
	_check(composition._binding.present_receipt(wrong_lifecycle).get("reason") == &"stale_lifecycle_generation", "foreign ship lifecycle generation is fenced")

	var new_seat := receipt.duplicate(true)
	new_seat.seat_generation = 2
	new_seat.request_sequence = 1
	new_seat.server_tick = 13
	_check(bool(composition._binding.present_receipt(new_seat).get("accepted", false)), "new seat generation starts a fresh request fence")
	var stale_seat := receipt.duplicate(true)
	stale_seat.request_sequence = 99
	stale_seat.server_tick = 99
	_check(composition._binding.present_receipt(stale_seat).get("reason") == &"stale_seat_generation", "older seat generation cannot return with a higher sequence")

	var new_peer := receipt.duplicate(true)
	new_peer.peer_generation = 4
	new_peer.seat_generation = 1
	new_peer.request_sequence = 1
	new_peer.server_tick = 14
	_check(bool(composition._binding.present_receipt(new_peer).get("accepted", false)), "new peer generation starts fresh seat and request fences")
	var stale_peer := receipt.duplicate(true)
	stale_peer.peer_generation = 3
	stale_peer.seat_generation = 3
	stale_peer.request_sequence = 100
	stale_peer.server_tick = 100
	_check(composition._binding.present_receipt(stale_peer).get("reason") == &"stale_peer_generation", "older peer generation cannot return through a newer seat")

	var migrated := receipt.duplicate(true)
	migrated.migration_generation = 3
	migrated.peer_generation = 1
	migrated.request_sequence = 1
	migrated.server_tick = 1
	_check(bool(composition._binding.present_receipt(migrated).get("accepted", false)), "new migration generation starts fresh subordinate fences")
	var stale_migration := migrated.duplicate(true)
	stale_migration.migration_generation = 2
	stale_migration.peer_generation = 99
	stale_migration.request_sequence = 100
	stale_migration.server_tick = 100
	_check(composition._binding.present_receipt(stale_migration).get("reason") == &"stale_migration_generation", "older migration cannot return through newer peer data")

	var stale_clear := _clear_receipt(migrated, 2, 2, 3)
	stale_clear.peer_generation = 4
	_check(composition._binding.present_receipt_clear(stale_clear).get("reason") == &"stale_tombstone", "clear must match the active peer and seat generations")
	var clear := _clear_receipt(migrated, 2, 2, 4)
	var released_result := {
		"accepted": true,
		"status": &"peer_released",
		"policy_version": &"network_cinder_navigator_ping_bridge_v1",
		"tombstone_count": 1,
		"tombstone_publication": {"accepted": true},
		"tombstones": [{"receipt": clear}],
	}
	var cleared := composition.present_bridge_result(released_result)
	_check(bool(cleared.get("accepted", false)) and int(cleared.get("emitted", 0)) == 1, "real peer-release result shape clears the matching active ping across migration")
	var typed_after_clear := _typed_cues.size()
	var replayed_clear := composition.present_bridge_result(released_result)
	_check(int(replayed_clear.get("emitted", -1)) == 0 and _typed_cues.size() == typed_after_clear, "exact clear tombstone replay is deduplicated")

	_check(_has(&"cinder_navigator_ping_accepted") and _has(&"cinder_navigator_ping_rejected") and _has(&"cinder_navigator_ping_cleared"), "AudioDirector receives all three navigator-specific cues")
	_check(not _has(&"crew_passenger_joined") and not _has(&"crew_passenger_left"), "navigator ping outcomes never masquerade as passenger lifecycle cues")
	_check(_captions.has("Navigator ping accepted") and _captions.has("Navigator ping rejected") and _captions.has("Navigator ping cleared"), "real semantic caption presenter labels all navigator outcomes")
	var snapshot: Dictionary = composition._binding.get_snapshot()
	_check(bool(snapshot.get("presentation_only", false)) and not snapshot.has("max_voices"), "binding reports truthful presentation-only capability without an unenforced voice ceiling")

	_check(bool(composition.detach().get("accepted", false)), "targeted detach clears navigator source")
	_check(director.get_semantic_audio_binding_count() == 0, "detach removes only navigator source")
	_check(bool(composition.attach(director, 1).get("accepted", false)), "composition can attach a fresh binding after targeted detach")
	composition.queue_free()
	await process_frame
	_check(director.get_semantic_audio_binding_count() == 0, "exit-tree cleanup unbinds the exact navigator source")

	bridge.detach()
	cinder.queue_free()
	director.queue_free()
	await process_frame
	if _failures.is_empty():
		print("CINDER_NAVIGATOR_PING_AUDIO_TEST_OK: %d checks" % _assertions)
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)


func _wire_receipt() -> Dictionary:
	return {
		"peer_id": 7,
		"peer_generation": 3,
		"avatar_id": &"navigator",
		"seat_id": &"cinder_navigator_station",
		"seat_generation": 1,
		"role": &"passenger",
		"ship_id": &"cinder-cargo-hauler",
		"ship_generation": 1,
		"request_sequence": 2,
		"server_tick": 12,
		"migration_generation": 2,
		"action": &"passenger_ping",
		"payload": {"channel": &"sensor", "marker_id": &"route_beacon"},
	}


func _accepted_result(receipt: Dictionary) -> Dictionary:
	return {
		"accepted": true,
		"status": &"navigator_ping_published",
		"policy_version": &"network_cinder_navigator_ping_bridge_v1",
		"receipt": {
			"occupant_peer_id": receipt.peer_id,
			"avatar_id": receipt.avatar_id,
			"seat_generation": receipt.seat_generation,
			"request_sequence": receipt.request_sequence,
		},
		"snapshot": {"station_id": receipt.seat_id, "receipt": receipt.payload.duplicate(true)},
		"wire_receipt": receipt.duplicate(true),
		"publication": {"accepted": true},
	}


func _clear_receipt(active: Dictionary, request_sequence: int, server_tick: int, migration_generation: int) -> Dictionary:
	var clear := active.duplicate(true)
	clear.action = &"passenger_ping_clear"
	clear.request_sequence = request_sequence
	clear.server_tick = server_tick
	clear.migration_generation = migration_generation
	clear.payload = {
		"channel": StringName((active.get("payload", {}) as Dictionary).get("channel", &"sensor")),
		"marker_id": StringName((active.get("payload", {}) as Dictionary).get("marker_id", &"")),
		"clear": true,
		"reason": &"peer_released",
		"source_request_sequence": int(active.get("request_sequence", 0)),
	}
	return clear


func _on_cue(source_id: StringName, cue_id: StringName, intensity: float, position: Vector3) -> void:
	_events.append({"source_id": source_id, "cue_id": cue_id, "intensity": intensity, "position": position})
	var presentation: Dictionary = _presenter.present_cue(cue_id, source_id, intensity, position)
	if bool(presentation.get("accepted", false)):
		_captions.append(str(presentation.get("caption", "")))


func _has(cue_id: StringName) -> bool:
	for event in _events:
		if event.get("cue_id") == cue_id:
			return true
	return false


func _check(condition: bool, message: String) -> void:
	_assertions += 1
	if not condition:
		_failures.append("FAIL: " + message)
