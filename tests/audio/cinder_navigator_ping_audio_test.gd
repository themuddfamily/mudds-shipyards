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
var _generic_cues: Array[StringName] = []
var _presenter := CuePresenter.new()


class RequestSpy extends Director:
	var requests: Array[Dictionary] = []

	func _play_resident(stream_id: StringName, bus: StringName, volume_db: float) -> bool:
		requests.append({"stream_id": stream_id, "bus": bus, "volume_db": volume_db,
			"effective_volume_db": volume_db + _effect_attenuation_db()})
		return super._play_resident(stream_id, bus, volume_db)


class BridgeAdapter:
	var migration_generation := 2
	func get_migration_snapshot() -> Dictionary:
		return {"migration_generation": migration_generation}
	func publish_crew_snapshot(_snapshot: Array) -> Dictionary:
		return {"accepted": true}


func _init() -> void:
	call_deferred(&"_run")


func _run() -> void:
	_check(AudioServer.get_driver_name() == "Dummy", "navigator dispatch test requires silent Dummy output")
	if AudioServer.get_driver_name() != "Dummy":
		quit(1)
		return
	var director := RequestSpy.new()
	var composition := Composition.new()
	var cinder := Cinder.new()
	root.add_child(director)
	root.add_child(composition)
	root.add_child(cinder)
	await process_frame
	director.semantic_cue_emitted.connect(_on_cue)
	director.cue_started.connect(func(cue_id: StringName) -> void: _generic_cues.append(cue_id))
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

	var silent_count := director.requests.size()
	var malformed_results: Array[Dictionary] = [
		{}, {"accepted": false},
		{"accepted": false, "status": &"authority_unavailable"},
		{"accepted": false, "status": &"", "policy_version": Bridge.POLICY_VERSION},
		{"accepted": 0, "status": &"authority_unavailable", "policy_version": Bridge.POLICY_VERSION},
		{"accepted": false, "status": 1, "policy_version": Bridge.POLICY_VERSION},
		{"accepted": false, "status": &"authority_unavailable", "policy_version": &"foreign"},
	]
	for malformed in malformed_results:
		_check(not composition.present_bridge_result(malformed).get("accepted", false), "malformed rejection envelope is refused")
		_check(not composition._binding.present_rejected(malformed).get("accepted", false), "direct rejection entry preserves envelope validation")
	_check(director.requests.size() == silent_count and _events.size() == silent_count, "malformed rejected dictionaries remain silent")

	var receipt := _wire_receipt()
	var accepted_result := _accepted_result(receipt)
	_check(bool(composition.present_bridge_result(accepted_result).get("accepted", false)), "real accepted bridge-result shape emits the navigator acceptance cue")
	var typed_after_accept := _typed_cues.size()
	_check(not composition.present_bridge_result(accepted_result).get("accepted", false) and _typed_cues.size() == typed_after_accept, "exact accepted receipt replay is deduplicated before fencing")

	var next_receipt := receipt.duplicate(true)
	next_receipt.request_sequence = 3
	next_receipt.server_tick = 13
	var requests_before_next := director.requests.size()
	_check(bool(composition.present_bridge_result(_accepted_result(next_receipt)).get("accepted", false)), "distinct consecutive accepted receipt is admitted")
	_check(director.requests.size() == requests_before_next + 1 and _events.size() == _typed_cues.size(), "identical acceptance cue tuples dispatch once per distinct receipt")

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
	_check(director.requests.size() == _events.size() and _events.size() == _typed_cues.size(), "replay and stale lifecycle, peer, seat, migration and clear results add no requests")
	director.set_reduced_dynamic_range(true)
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
	var expected_streams := {
		&"cinder_navigator_ping_accepted": Director.STREAM_UI_CONFIRM,
		&"cinder_navigator_ping_rejected": Director.STREAM_COMBAT_ALERT_PRIMARY,
		&"cinder_navigator_ping_cleared": Director.STREAM_CANOPY_CLOSE,
	}
	_check(director.requests.size() == _events.size(), "each forwarded navigator cue selects exactly one resident request")
	for index in range(mini(director.requests.size(), _events.size())):
		var request: Dictionary = director.requests[index]
		_check(request.stream_id == expected_streams[_events[index].cue_id] and request.bus == &"UI", "navigator outcome selects its distinct existing resident UI one-shot")
		_check(director.get_resident_stream_ids().has(str(request.stream_id)), "requested navigator sound belongs to the resident bank")
	_check(is_equal_approx(float(director.requests.back().effective_volume_db), -17.0), "navigator clear keeps reduced-range effect attenuation")
	_check(_generic_cues.is_empty(), "resident navigator dispatch never echoes a generic caption cue")
	_check(bool(director.get_audit_report().get("valid", false)), "Dummy request spy preserves Director resource and backend contract")
	var snapshot: Dictionary = composition._binding.get_snapshot()
	_check(bool(snapshot.get("presentation_only", false)) and not snapshot.has("max_voices"), "binding reports truthful presentation-only capability without an unenforced voice ceiling")

	var retired_binding: Node = composition._binding
	var requests_before_detach := director.requests.size()
	_check(bool(composition.detach().get("accepted", false)), "targeted detach clears navigator source")
	_check(director.get_semantic_audio_binding_count() == 0, "detach removes only navigator source")
	retired_binding.semantic_navigator_ping_cue_emitted.emit(&"cinder_navigator_ping_accepted", 0.7)
	_check(not composition.present_bridge_result(accepted_result).get("accepted", false) and director.requests.size() == requests_before_detach, "exact unbound source and detached composition cannot request playback")
	_check(bool(composition.attach(director, 1).get("accepted", false)), "composition can attach a fresh binding after targeted detach")
	composition.queue_free()
	await process_frame
	_check(director.get_semantic_audio_binding_count() == 0, "exit-tree cleanup unbinds the exact navigator source")

	bridge.detach()
	_test_local(director, cinder)
	_test_raw_client_commands(director)
	_test_client_results(director)
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


func _test_client_results(director: RequestSpy) -> void:
	var client := Composition.new()
	root.add_child(client)
	client.attach(director)
	var request := {"action": &"navigator_ping", "request_sequence": 1,
		"avatar_id": &"navigator", "ship_id": Cinder.COMPONENT_ID,
		"seat_id": Cinder.NAVIGATOR_STATION_SEAT_ID}
	var actual_unavailable := {"accepted": false, "status": &"navigator_consumer_unavailable"}
	var before := director.requests.size()
	_check(bool(client.present_client_request_result(actual_unavailable, request).accepted), "explicit correlated pre-bridge refusal requires no forged bridge policy")
	_check(not bool(client.present_client_request_result(actual_unavailable, request).accepted), "same original requester identity refuses duplicate result")
	request.request_sequence = 2
	_check(bool(client.present_client_request_result(actual_unavailable, request).accepted) and director.requests.size() == before + 2, "distinct original requests with equal refusal results each select resident playback")
	_check(director.requests.back().stream_id == Director.STREAM_COMBAT_ALERT_PRIMARY and director.requests.back().bus == &"UI", "correlated rejection retains existing resident alert")
	for result in [{"accepted": true, "status": &"navigator_ping_published"},
		{"accepted": false, "status": &"invalid_cinder_receipt"},
		{"accepted": false, "status": &"invalid_cinder_snapshot"},
		{"accepted": false, "status": &"network_publish_failed", "mutation_committed": true},
		{"accepted": false, "status": &"cinder_rejected", "effect": {"accepted": true, "consumed": true}},
		{"accepted": false, "status": 7}]:
		request.request_sequence += 1
		_check(not bool(client.present_client_request_result(result, request).accepted), "success, committed/internal or malformed terminal never fabricates denied gameplay")
	_check(director.requests.size() == before + 2, "internal results and success acknowledgement produce no navigator echo")
	client.detach()
	client.queue_free()


## Focused raw-command forwarding, not two-peer transport acceptance.
func _test_raw_client_commands(director: RequestSpy) -> void:
	var client := Composition.new()
	root.add_child(client)
	_check(bool(client.attach(director, 6).get("accepted", false)), "client raw-command composition attaches at actual wire generation")
	var first := _wire_receipt()
	first.ship_generation = 6
	var second := first.duplicate(true)
	second.request_sequence = int(first.request_sequence) + 1
	second.server_tick = int(first.server_tick) + 1
	var first_before := first.duplicate(true)
	var second_before := second.duplicate(true)
	var count := director.requests.size()
	_check(bool(client.present_receipt(first).get("accepted", false)) and bool(client.present_receipt(second).get("accepted", false)), "two actual shaped receipts forward independently in one client source")
	_check(director.requests.size() == count + 2 and first == first_before and second == second_before, "raw forwarding requests twice without changing transported identity")
	_check(not bool(client.present_receipt(first).get("accepted", false)), "raw accepted replay is silent")
	var clear := _clear_receipt(second, int(second.request_sequence) + 1, int(second.server_tick) + 1, int(second.migration_generation))
	var clear_before := clear.duplicate(true)
	_check(bool(client.present_receipt_clear(clear).get("accepted", false)) and clear == clear_before, "raw matching clear forwards unchanged")
	_check(not bool(client.present_receipt_clear(clear).get("accepted", false)) and director.requests.size() == count + 3, "raw duplicate clear stays silent")
	var binding: Node = client._binding
	client.detach()
	binding.semantic_navigator_ping_cue_emitted.emit(&"cinder_navigator_ping_accepted", 0.7)
	_check(director.requests.size() == count + 3, "raw client detach unregisters the exact source")
	client.queue_free()


func _test_local(director: RequestSpy, craft: CinderCargoHauler) -> void:
	var authority := CrewSeatRoleAuthority.new(1)
	_check(bool(authority.register_cinder_roster().accepted), "local roster registers")
	_check(bool(craft.attach_crew_role_authority(authority).accepted), "local craft owns real authority")
	_check(bool(authority.claim(1, 1, &"solo_navigator", Cinder.NAVIGATOR_STATION_SEAT_ID, &"passenger", 1).accepted), "local navigator uses actual ledger claim")
	var claim := {"craft": craft, "authority": authority, "avatar_id": &"solo_navigator", "seat_generation": 1, "claim_sequence": 1}
	var local := Composition.new()
	root.add_child(local)
	var before := director.requests.size()
	_check(bool(local.attach_local(director, claim).accepted), "explicit local composition attaches without wire identity")
	_check(director.requests.size() == before, "local attachment never replays history")
	var refused := craft.submit_navigator_ping(1, &"solo_navigator", 1)
	_check(refused.get("accepted") == false and bool(local.present_local_result(refused, claim, 1).accepted), "real authority refusal requests local rejection feedback")
	_check(director.requests.size() == before + 1 and director.requests.back().stream_id == Director.STREAM_COMBAT_ALERT_PRIMARY, "local refusal uses existing alert request")
	_check(not local.present_local_result(refused, claim, 1).accepted, "same refused request is silent on replay")
	var accepted := craft.submit_navigator_ping(1, &"solo_navigator", 2)
	_check(bool(accepted.get("consumed", false)) and bool(local.present_local_result(accepted, claim, 2).accepted), "actual consumed solo receipt requests accepted feedback")
	_check(director.requests.size() == before + 2 and director.requests.back().stream_id == Director.STREAM_UI_CONFIRM, "local acceptance uses existing confirmation request")
	_check(not local.present_local_result(accepted, claim, 2).accepted and not local.present_bridge_result(_accepted_result(_wire_receipt())).accepted, "local lane refuses result replay and wire entry")
	var old_callback: Callable = local._local_clear_callback
	var old_receipt: Dictionary = accepted.effect.receipt.duplicate(true)
	_check(bool(authority.release(1, 1, &"solo_navigator", Cinder.NAVIGATOR_STATION_SEAT_ID, 3, 1).accepted), "forced ledger release retires exact local claim")
	craft._cleanup_detached_navigator()
	_check(director.requests.size() == before + 3 and director.requests.back().stream_id == Director.STREAM_CANOPY_CLOSE and not local.local_is_attached(), "ship-owned forced clear requests one clear and retires source")
	craft._cleanup_detached_navigator()
	old_callback.call(old_receipt, &"late")
	_check(director.requests.size() == before + 3, "duplicate clear and retired callback remain silent")
	_check(bool(craft.detach_crew_role_authority(authority).accepted), "old local authority detaches")
	var replacement := CrewSeatRoleAuthority.new(1)
	replacement.register_cinder_roster()
	craft.attach_crew_role_authority(replacement)
	replacement.claim(1, 1, &"solo_navigator", Cinder.NAVIGATOR_STATION_SEAT_ID, &"passenger", 1)
	var fresh_claim := claim.duplicate()
	fresh_claim.authority = replacement
	_check(bool(local.attach_local(director, fresh_claim).accepted), "new authority may reuse the same numeric seat claim")
	var fresh := craft.submit_navigator_ping(1, &"solo_navigator", 2)
	_check(not local.present_local_result(accepted, claim, 2).accepted, "old authority result cannot enter numerically equal replacement")
	_check(bool(local.present_local_result(fresh, fresh_claim, 2).accepted), "replacement actual first ping remains fresh")
	old_callback.call(old_receipt, &"late")
	_check(local.local_is_attached() and director.requests.size() == before + 4, "old authority callback cannot clear replacement")
	local.detach()
	_check(bool(local.attach_local(director, fresh_claim).accepted), "local lane can reattach to retained exact claim")
	_check(not local.present_local_result(fresh, fresh_claim, 2).accepted and director.requests.size() == before + 4, "historical actual receipt seeds silence on attach")
	local.detach()
	craft.detach_crew_role_authority(replacement)
	local.queue_free()


func _wire_receipt() -> Dictionary:
	return {
		"peer_id": 7,
		"peer_generation": 3,
		"avatar_id": &"navigator",
		"seat_id": &"cinder_navigator_station",
		"seat_generation": 1,
		"role": &"passenger",
		"ship_id": &"cinder_cargo_hauler",
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
