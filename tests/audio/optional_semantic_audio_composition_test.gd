extends SceneTree

const Director := preload("res://scripts/audio/audio_director.gd")
const Composition := preload("res://scripts/audio/optional_semantic_audio_composition.gd")
const Cinder := preload("res://scripts/ships/cinder_cargo_hauler.gd")
const Flow := preload("res://scripts/game/game_flow.gd")
const Session := preload("res://scripts/network/network_enet_session_adapter.gd")
const CuePresenter := preload("res://scripts/ui/semantic_audio_cue_presenter.gd")

# Wire-shaped applied input isolates coordinator fences; the existing two-peer
# passenger route remains the production transport and Main acceptance.
class RequestSpy extends Director:
	var requests: Array[Dictionary] = []
	func _play_resident(stream_id: StringName, bus: StringName, volume_db: float) -> bool:
		requests.append({"stream_id": stream_id, "bus": bus, "volume_db": volume_db})
		return super._play_resident(stream_id, bus, volume_db)

class RequestSeat extends Node:
	func get_seat_id() -> StringName:
		return Cinder.NAVIGATOR_STATION_SEAT_ID

class ClientAdapterFixture extends Session:
	var sent: Array[Dictionary] = []
	var queue_success := true
	var immediate_result := false
	func send_engineer_intent(payload: Dictionary) -> Dictionary:
		sent.append(payload.duplicate(true))
		if immediate_result:
			navigator_request_result_received.emit(response(payload))
		return {"accepted": queue_success}
	func response(payload: Dictionary) -> Dictionary:
		var request := payload.duplicate(true)
		request["ship_id"] = Cinder.COMPONENT_ID
		request["seat_id"] = Cinder.NAVIGATOR_STATION_SEAT_ID
		return {"request": request, "result": {"accepted": false, "status": &"navigator_consumer_unavailable"},
			"recipient_peer_id": 7, "peer_generation": 3, "session_generation": 1, "migration_generation": migration}
	var active := true
	var migration := 2
	var cached_reads := 0
	func is_server() -> bool:
		return false
	func is_session_active() -> bool:
		return active
	func get_migration_snapshot() -> Dictionary:
		return {"migration_generation": migration, "session_generation": 1, "package_generation": 1}
	func get_server_offer() -> Dictionary:
		return {"admission": {"accepted": true, "peer": {"peer_id": 7, "peer_generation": 3}},
			"transport": {"peer_id": 7, "peer_generation": 3}, "migration": {"epoch": get_migration_snapshot()}}
	func get_crew_replica_snapshot() -> Dictionary:
		cached_reads += 1
		return {}

class ClientFlowFixture extends Flow:
	var request_claim: Dictionary = {}
	func _client_navigator_request_claim() -> Dictionary:
		return request_claim.duplicate()
	func _enter_tree() -> void:
		pass
	func _ready() -> void:
		pass
	func _process(_delta: float) -> void:
		pass
	func _physics_process(_delta: float) -> void:
		pass
	func _network_client_peer_id() -> int:
		return 7
	func _exit_tree() -> void:
		_detach_optional_semantic_audio()

class CaptionFixture extends CanvasLayer:
	var presenter := CuePresenter.new()
	var captions: Array[Dictionary] = []
	func present_semantic_audio_cue(cue: StringName, source: StringName, intensity: float, position: Vector3, metadata: Dictionary = {}) -> bool:
		var result: Dictionary = presenter.present_cue(cue, source, intensity, position, metadata)
		if bool(result.get("accepted", false)):
			captions.append(result)
		return bool(result.get("accepted", false))


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
	var director := RequestSpy.new()
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
	_test_client_generation_replacement(director)
	await _test_client_applied_commands(director)
	await _test_client_request_results(director)
	for failure in _failures:
		push_error(failure)
	print("OPTIONAL_SEMANTIC_AUDIO_COMPOSITION_TEST: %d assertions" % _assertions)
	quit(0 if _failures.is_empty() else 1)

func _test_client_generation_replacement(director: Node) -> void:
	var optional := Composition.new()
	root.add_child(optional)
	optional.attach(director)
	var context := {"fixture": &"wire_shaped_client"}
	optional.set_client_navigator_context(context)
	var first := _navigator_receipt(40, 1, 40)
	var count := _events.size()
	_check(bool(optional.present_cinder_client_navigator_command(first, context).accepted), "focused client generation source accepts unchanged wire-shaped receipt")
	var malformed := _navigator_receipt(41, 1, 41)
	malformed.payload = null
	_check(not bool(optional.present_cinder_client_navigator_command(malformed, context).accepted) and int(optional.get_snapshot().client_navigator.generation) == 40, "malformed newer generation cannot retire active client source")
	var unknown := _navigator_clear(_navigator_receipt(41, 1, 41), &"unknown_owner")
	_check(not bool(optional.present_cinder_client_navigator_command(unknown, context).accepted), "unknown newer clear cannot replace client generation")
	var fresh := _navigator_receipt(41, 1, 41)
	_check(bool(optional.present_cinder_client_navigator_command(fresh, context).accepted) and int(optional.get_snapshot().client_navigator.generation) == 41, "valid newer accepted publication replaces same-craft transported ship owner")
	_check(not bool(optional.present_cinder_client_navigator_command(first, context).accepted) and _events.size() == count + 2, "retired lower ship generation cannot return after valid replacement")
	optional.detach()
	_check(not bool(optional.get_snapshot().client_navigator.attached), "exact client detach resets generation attachment")
	optional.queue_free()


func _test_client_applied_commands(director: Node) -> void:
	var flow := ClientFlowFixture.new()
	var adapter := ClientAdapterFixture.new()
	var craft := Cinder.new()
	var optional := Composition.new()
	var caption := CaptionFixture.new()
	flow.add_child(adapter)
	flow.add_child(craft)
	flow.add_child(optional)
	flow.add_child(caption)
	flow.network_session = adapter
	flow._network_session_mode = &"client"
	flow._cabin_ship = craft
	flow.phase = Flow.Phase.IN_FLIGHT_CABIN
	flow._network_client_boarding_claim = {"ship_id": Cinder.COMPONENT_ID, "seat_id": &"berth_1", "role": &"cabin_berth"}
	flow.optional_semantic_audio_composition = optional
	flow.hud = caption
	flow.audio = director
	root.add_child(flow)
	optional.attach(director)
	director.semantic_cue_emitted.connect(flow._on_semantic_audio_cue_emitted)
	# Use the same production advancement that precedes role FIRE, rather
	# than manually priming the optional receipt source before the first ping.
	flow._advance_network_engineer(1.0 / 60.0)
	var callback: Callable = flow._client_navigator_audio_callback
	var before := _events.size()
	_check(adapter.cached_reads == 0 and not bool(optional.get_snapshot().client_navigator.attached), "production client advancement establishes listener without reading cached crew state or inventing a source")
	var first := _navigator_receipt(8, 2, 12)
	var first_result := _applied(first)
	var first_before := first_result.duplicate(true)
	adapter.crew_snapshot_applied.emit(first_result)
	var second := _navigator_receipt(8, 3, 13)
	var second_result := _applied(second)
	adapter.crew_snapshot_applied.emit(second_result)
	_check(_events.size() == before + 2 and caption.captions.size() == 2, "two consecutive applied receipts in one client context each produce sound and real presenter caption")
	_check(caption.captions[0].caption == "Navigator ping accepted" and caption.captions[1].caption == "Navigator ping accepted", "identity handoff preserves both accepted captions")
	_check(first_result == first_before and int(optional.get_snapshot().client_navigator.generation) == 8, "client generation comes from unchanged actual command, independent of host counter")
	_check(flow._get_cinder_navigator_presentation_generation() == 0, "client never acquires host navigator generation")
	optional.set_navigator_generation(0)
	_check(bool(optional.get_snapshot().client_navigator.attached), "host HUD generation zero preserves independent client registration")
	adapter.crew_snapshot_applied.emit(first_result)
	var invalid := _applied(_navigator_receipt(8, 4, 14))
	invalid.accepted = false
	adapter.crew_snapshot_applied.emit(invalid)
	adapter.crew_snapshot_applied.emit({"accepted": true, "status": &"crew_snapshot_applied", "snapshot": {"migration_generation": 2, "commands": [null, "bad"]}})
	for field: String in ["ship_id", "seat_id", "role", "avatar_id"]:
		var unrelated := _navigator_receipt(8, 5, 15)
		unrelated[field] = &"unrelated"
		if field == "avatar_id":
			unrelated.peer_id = 999
		adapter.crew_snapshot_applied.emit(_applied(unrelated))
	var stale_owner := _navigator_receipt(8, 6, 16)
	stale_owner.peer_generation = 2
	adapter.crew_snapshot_applied.emit(_applied(stale_owner))
	var malformed := _navigator_receipt(8, 7, 17)
	malformed.payload = null
	adapter.crew_snapshot_applied.emit(_applied(malformed))
	var unknown_clear := _navigator_clear(second, &"unknown")
	unknown_clear.avatar_id = &"unknown"
	adapter.crew_snapshot_applied.emit(_applied(unknown_clear))
	_check(_events.size() == before + 2 and caption.captions.size() == 2, "replay, failed apply, malformed and unrelated source and unknown clear remain silent")
	# Physical assignment is absent; exact active command ownership survives.
	var clear := _navigator_clear(second, &"ordinary_stand")
	var clear_result := _applied(clear)
	adapter.crew_snapshot_applied.emit(clear_result)
	adapter.crew_snapshot_applied.emit(clear_result)
	adapter.crew_snapshot_applied.emit(_applied({}))
	_check(_events.size() == before + 3 and caption.captions.size() == 3 and caption.captions.back().caption == "Navigator ping cleared", "matching assignment-empty clear emits once; duplicate and missing command do not clear again")
	# Existing authorized same-ship role recipients are not limited to navigator.
	var shared := _navigator_receipt(8, 8, 20)
	shared.peer_id = 9
	shared.avatar_id = &"other_navigator"
	var shared_result := _applied(shared)
	shared_result.snapshot.roles = [{"peer_id": 7, "peer_generation": 3, "ship_id": Cinder.COMPONENT_ID, "ship_generation": 8, "migration_generation": 2, "role": &"pilot"}]
	adapter.crew_snapshot_applied.emit(shared_result)
	_check(_events.size() == before + 4, "actual applied local-peer ship role authorizes same-ship navigator recipient")
	adapter.crew_snapshot_applied.emit(_applied(_navigator_clear(shared, &"role_already_empty")))
	_check(_events.size() == before + 5, "known shared recipient retains matching real clear after role publication emptied")
	var retired_binding: Node = optional._client_navigator_composition._binding
	flow.phase = Flow.Phase.INTRO
	flow._sync_client_navigator_audio_lifetime()
	retired_binding.semantic_navigator_ping_cue_emitted.emit(&"cinder_navigator_ping_accepted", 0.7)
	adapter.crew_snapshot_applied.emit(_applied(_navigator_receipt(8, 10, 25)))
	flow.phase = Flow.Phase.IN_FLIGHT_CABIN
	flow._sync_client_navigator_audio_lifetime()
	adapter.crew_snapshot_applied.emit(second_result)
	adapter.crew_snapshot_applied.emit(_applied(_navigator_receipt(8, 10, 25)))
	_check(_events.size() == before + 5 and not bool(optional.get_snapshot().client_navigator.attached), "leaving exact craft unbinds source and re-entry cannot replay commands observed while absent")
	var new_ship := Cinder.new()
	flow.add_child(new_ship)
	flow._cabin_ship = new_ship
	flow._sync_client_navigator_audio_lifetime()
	var old_context: Dictionary = optional._client_navigator_context.duplicate()
	adapter.migration = 3
	flow._sync_client_navigator_audio_lifetime()
	callback.call(_applied(_navigator_receipt(8, 11, 26)))
	_check(not bool(optional.get_snapshot().client_navigator.attached), "old migration callback cannot attach replacement craft source")
	var migrated := _navigator_receipt(9, 1, 30)
	migrated.migration_generation = 3
	var migrated_result := _applied(migrated)
	migrated_result.snapshot.migration_generation = 3
	adapter.crew_snapshot_applied.emit(migrated_result)
	_check(_events.size() == before + 6 and bool(optional.get_snapshot().client_navigator.attached), "actual new migration and transported ship generation establish fresh client feedback")
	_check(not bool(optional.present_cinder_client_navigator_command(migrated, old_context).accepted), "retired exact client context cannot forward into replacement source")
	var migration_callback: Callable = flow._client_navigator_audio_callback
	var replacement := ClientAdapterFixture.new()
	replacement.migration = 3
	flow.add_child(replacement)
	flow.network_session = replacement
	flow._sync_client_navigator_audio_lifetime()
	migration_callback.call(migrated_result)
	_check(_events.size() == before + 6 and not bool(optional.get_snapshot().client_navigator.attached) and not adapter.crew_snapshot_applied.is_connected(migration_callback), "session adapter replacement disconnects exact old callback and retires source")
	var final_callback: Callable = flow._client_navigator_audio_callback
	flow._detach_optional_semantic_audio()
	final_callback.call(migrated_result)
	_check(_events.size() == before + 6 and not bool(optional.get_snapshot().attached), "whole-Main detach resets client attachment and stale callback")
	optional.attach(director)
	flow._sync_client_navigator_audio_lifetime()
	_check(replacement.cached_reads == 0 and not bool(optional.get_snapshot().client_navigator.attached), "whole-Main re-entry awaits fresh applied state without replaying cache")
	var stopped_callback: Callable = flow._client_navigator_audio_callback
	var reentrant := _navigator_receipt(10, 50, 50)
	reentrant.migration_generation = 3
	var after_reentrant := reentrant.duplicate(true)
	after_reentrant.request_sequence = 51
	after_reentrant.server_tick = 51
	var reentrant_result := _applied(reentrant)
	reentrant_result.snapshot.migration_generation = 3
	reentrant_result.snapshot.commands.append(after_reentrant)
	director.semantic_cue_emitted.connect(func(_source: StringName, _cue: StringName, _intensity: float, _position: Vector3) -> void:
		flow._disconnect_client_navigator_audio()
	, CONNECT_ONE_SHOT)
	var events_before_reentrant := _events.size()
	replacement.crew_snapshot_applied.emit(reentrant_result)
	_check(_events.size() == events_before_reentrant + 1 and not bool(optional.get_snapshot().client_navigator.attached) and int(optional.get_snapshot().client_navigator.generation) == 0, "synchronous first-cue teardown cannot restore retired attachment or forward remaining old commands")
	flow._sync_client_navigator_audio_lifetime()
	stopped_callback = flow._client_navigator_audio_callback
	replacement.active = false
	flow._sync_client_navigator_audio_lifetime()
	_check(not replacement.crew_snapshot_applied.is_connected(stopped_callback), "stopped client session disconnects owned receipt callback")
	director.semantic_cue_emitted.disconnect(flow._on_semantic_audio_cue_emitted)
	flow.queue_free()
	await process_frame
	_check(director.get_semantic_audio_binding_count() == 1, "client fixture teardown preserves exact unrelated source")


func _test_client_request_results(director: RequestSpy) -> void:
	_check(AudioServer.get_driver_name() == "Dummy", "requester fixture retains real silent backend")
	var flow := ClientFlowFixture.new()
	var adapter := ClientAdapterFixture.new()
	var craft := Cinder.new()
	var optional := Composition.new()
	var caption := CaptionFixture.new()
	var seat := RequestSeat.new()
	for child in [adapter, craft, optional, caption, seat]:
		flow.add_child(child)
	flow.network_session = adapter
	flow._network_session_mode = &"client"
	flow._cabin_ship = craft
	flow.phase = Flow.Phase.IN_FLIGHT_CABIN
	flow._network_client_boarding_claim = {"ship_id": Cinder.COMPONENT_ID, "role": &"cabin_berth"}
	flow.optional_semantic_audio_composition = optional
	flow.hud = caption
	flow.audio = director
	root.add_child(flow)
	optional.attach(director)
	flow._sync_client_navigator_audio_lifetime()
	flow.request_claim = {"context": flow._client_navigator_audio_context.duplicate(), "seat": seat,
		"entity_generation": 1, "seat_generation": 1, "claim_sequence": 2, "binding_generation": 4}
	var view := {"entity_generation": 1, "binding_generation": 4, "migration_generation": 2,
		"assignment": {"avatar_id": &"navigator", "seat_generation": 1, "claim_sequence": 2}}
	director.semantic_cue_emitted.connect(flow._on_semantic_audio_cue_emitted)
	var before := director.requests.size()
	flow._send_network_loadmaster_intent(view, &"navigator_ping")
	flow._send_network_loadmaster_intent(view, &"navigator_ping")
	_check(flow._client_navigator_pending.size() == 2, "multiple exact original requests stay independently pending")
	var packets: Array[Dictionary] = [adapter.response(adapter.sent[0]), adapter.response(adapter.sent[1])]
	for field in ["recipient_peer_id", "peer_generation", "session_generation", "migration_generation"]:
		var foreign := packets[0].duplicate(true)
		foreign[field] += 1
		adapter.navigator_request_result_received.emit(foreign)
	for field in ["action", "avatar_id", "ship_id", "seat_id", "entity_generation", "seat_generation", "claim_sequence", "binding_generation", "migration_generation", "server_tick"]:
		var foreign := packets[0].duplicate(true)
		foreign.request[field] = &"foreign" if field in ["action", "avatar_id", "ship_id", "seat_id"] else int(foreign.request[field]) + 1
		adapter.navigator_request_result_received.emit(foreign)
	_check(director.requests.size() == before and flow._client_navigator_pending.size() == 2, "foreign recipient and original identity fields cannot retire or present a live pending request")
	for packet in packets:
		adapter.navigator_request_result_received.emit(packet)
		adapter.navigator_request_result_received.emit(packet)
	_check(director.requests.size() == before + 2 and caption.captions.size() == 2 and flow._client_navigator_pending.is_empty(), "two equal authenticated refusals each select one resident alert and real transition caption; replay stays silent")
	_check(not optional.get_snapshot().client_navigator.attached and optional._client_navigator_result_composition._binding.get_snapshot().lifecycle_generation == 0, "pre-first-accept refusal uses no invented wire ship generation")
	for index in range(before, director.requests.size()):
		_check(director.requests[index].stream_id == Director.STREAM_COMBAT_ALERT_PRIMARY and director.requests[index].bus == &"UI", "requester refusal uses the existing resident UI alert")
	adapter.immediate_result = true
	flow._send_network_loadmaster_intent(view, &"navigator_ping")
	_check(director.requests.size() == before + 3 and flow._client_navigator_pending.is_empty(), "pending registration precedes the actual send even for synchronous terminal delivery")
	adapter.immediate_result = false
	adapter.queue_success = false
	flow._send_network_loadmaster_intent(view, &"navigator_ping")
	_check(flow._client_navigator_pending.is_empty(), "immediate queue failure retires only its registered request")
	adapter.queue_success = true
	for terminal in [{"accepted": true, "status": &"navigator_ping_published"},
		{"accepted": false, "status": &"invalid_cinder_receipt"},
		{"accepted": false, "status": &"invalid_cinder_snapshot"},
		{"accepted": false, "status": &"network_publish_failed", "mutation_committed": true}]:
		flow._send_network_loadmaster_intent(view, &"navigator_ping")
		var packet := adapter.response(adapter.sent.back())
		packet.result = terminal
		adapter.navigator_request_result_received.emit(packet)
	_check(director.requests.size() == before + 3 and flow._client_navigator_pending.is_empty(), "success acknowledgement and internal committed terminals retire without acceptance echo or denial")
	flow._send_network_loadmaster_intent(view, &"navigator_ping")
	var translated := adapter.response(adapter.sent.back())
	translated.result = {"accepted": false, "status": &"cinder_rejected", "effect": {"accepted": false, "status": &"stale_request_sequence"}}
	adapter.navigator_request_result_received.emit(translated)
	_check(director.requests.size() == before + 4, "fresh original sequence may present a genuine unconsumed translated authority refusal")
	var active := _navigator_receipt(8, 10, 40)
	adapter.crew_snapshot_applied.emit(_applied(active))
	var active_source: Node = optional._client_navigator_composition
	for _request in 40:
		flow._send_network_loadmaster_intent(view, &"navigator_ping")
	_check(flow._client_navigator_pending.size() == Flow.CLIENT_NAVIGATOR_PENDING_LIMIT, "pending storage remains bounded without collapsing distinct outstanding requests")
	flow.request_claim.claim_sequence += 1
	flow._sync_client_navigator_audio_lifetime()
	_check(flow._client_navigator_pending.is_empty() and optional._client_navigator_composition == active_source and optional.get_snapshot().client_navigator.attached, "claim loss retires pending refusals while preserving actual accepted clear owner")
	adapter.crew_snapshot_applied.emit(_applied(_navigator_clear(active, &"real_clear_after_claim_loss")))
	_check(caption.captions.back().caption == "Navigator ping cleared", "actual matching clear still presents after pending retirement")
	flow._send_network_loadmaster_intent(view, &"navigator_ping")
	var stale := adapter.response(adapter.sent.back())
	var retired_callback: Callable = flow._client_navigator_result_callback
	adapter.migration = 3
	flow._sync_client_navigator_audio_lifetime()
	var count := director.requests.size()
	retired_callback.call(stale)
	_check(director.requests.size() == count and flow._client_navigator_pending.is_empty(), "old migration callback cannot reattach refusal presentation")
	director.semantic_cue_emitted.disconnect(flow._on_semantic_audio_cue_emitted)
	flow.queue_free()
	await process_frame


func _applied(command: Dictionary) -> Dictionary:
	return {"accepted": true, "status": &"crew_snapshot_applied", "revision": int(command.get("server_tick", 1)),
		"snapshot": {"migration_generation": 2, "roles": [], "commands": [] if command.is_empty() else [command]}}


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
