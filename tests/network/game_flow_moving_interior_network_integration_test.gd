extends SceneTree

const Adapter := preload("res://scripts/network/network_enet_session_adapter.gd")
const Relationship := preload("res://scripts/network/moving_interior_relationship.gd")
const GameFlow := preload("res://scripts/game/game_flow.gd")
const Presenter := preload("res://scripts/network/network_moving_interior_presenter.gd")
const BodySource := preload("res://scripts/network/network_remote_body_intent_source.gd")

const PLAYER_SCENE := preload("res://scenes/player/player.tscn")

class CabinCapabilityProbe extends HeroShip:
	var capability_queries := 0
	var cabin_supported := true
	var report_queries := 0
	var fixture_frame: MovingInteriorFrame
	var fixture_ship_id: StringName

	func _ready() -> void:
		set_process(false)
		set_physics_process(false)

	func get_ship_id() -> StringName:
		return fixture_ship_id

	func get_in_flight_cabin_report() -> Dictionary:
		report_queries += 1
		return {"frame": fixture_frame}

	func supports_in_flight_cabin_access() -> bool:
		capability_queries += 1
		return cabin_supported

var _assertions := 0
var _failures := PackedStringArray()


func _init() -> void:
	call_deferred(&"_run")


func _run() -> void:
	var server := Adapter.new()
	server._is_server = true
	server._configured = true
	server._peer_generations[2] = 1
	var relationship := Relationship.create(4, &"pilot_cinder", 1, &"frame_cinder", 1, Transform3D.IDENTITY)
	var published := server.publish_moving_interior_snapshot(relationship.get_snapshot(), [2], 4)
	_check(bool(published.get("accepted", false)), "server publishes frame-local relationship")
	var client := Adapter.new()
	var applied := client.consume_moving_interior_snapshot(published.get("packet", {}) as Dictionary)
	_check(bool(applied.get("accepted", false)), "client consumes presentation relationship")
	_check(int(client.get_presentation_cursor_audit().get("moving_interior_count", 0)) == 1,
		"client retains one moving-interior presentation cursor")
	var stale := (published.get("packet", {}) as Dictionary).duplicate(true)
	stale["migration_generation"] = 0
	_check(not bool(client.consume_moving_interior_snapshot(stale).get("accepted", false)),
		"stale migration relationship is rejected")
	var released := server.publish_moving_interior_release(&"pilot_cinder", 1, [2])
	_check(bool(released.get("accepted", false)), "server publishes relationship release")
	client._broadcast_moving_interior_release(released.get("packet", {}) as Dictionary)
	_check(int(client.get_presentation_cursor_audit().get("moving_interior_count", 0)) == 0,
		"release clears client relationship presentation")
	server._on_peer_disconnected(2)
	server.free()
	client.free()
	await _check_presenter_fleet_lifecycle()
	await _check_client_shutdown_prediction_lifecycle()
	if _failures.is_empty():
		print("OK: GameFlow moving interior network integration (%d assertions)" % _assertions)
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)


## Capability reports may read cabin global transforms. Presentation must only
## request them while both the presenter and the candidate craft are live.
func _check_presenter_fleet_lifecycle() -> void:
	var flow := GameFlow.new()
	var presenter := Presenter.new()
	root.add_child(presenter)
	flow._network_moving_interior_presenter = presenter
	var source := BodySource.new()
	source.bind(&"own_body", 3, 2)
	flow._network_remote_body_intent_source = source
	var live := CabinCapabilityProbe.new()
	live.fixture_ship_id = &"live_cabin"
	root.add_child(live)
	var unsupported := CabinCapabilityProbe.new()
	unsupported.fixture_ship_id = &"no_cabin"
	unsupported.cabin_supported = false
	root.add_child(unsupported)
	var detached := CabinCapabilityProbe.new()
	detached.fixture_ship_id = &"detached_cabin"
	var queued := CabinCapabilityProbe.new()
	queued.fixture_ship_id = &"queued_cabin"
	root.add_child(queued)
	queued.queue_free()
	flow.ships.assign([live, unsupported, detached, queued])
	flow._sync_network_moving_interior_presenter()
	_check(live.capability_queries == 1 and unsupported.capability_queries == 1,
		"live craft retain their supported-cabin capability queries")
	_check(detached.capability_queries == 0 and queued.capability_queries == 0,
		"detached and queued craft are never capability queried")
	_check(presenter._frames.size() == 1 and presenter._frames.has(&"frame_live_cabin"),
		"only a live supported cabin is registered for presentation")
	var frame: Dictionary = presenter._frames.get(&"frame_live_cabin", {})
	_check(frame.get("node") == live and int(frame.get("generation", 0)) == 1,
		"live cabin registration preserves its frame node and generation")
	_check(presenter._local_entity_ids.has(&"own_body")
		and not presenter._local_entity_ids.has(&"pilot_live_cabin"),
		"local body exclusion still allows the host pilot to be presented")
	var audit := presenter.get_presentation_audit()
	_check(not audit.owns_physics_authority and not audit.owns_seat_authority
		and not audit.owns_movement_authority,
		"presentation registration grants no gameplay authority")
	# Give a removed/replacement actor a fresh identity so accidental
	# registration cannot be hidden by the presenter's idempotent frame path.
	root.remove_child(live)
	live.fixture_ship_id = &"retired_cabin"
	flow.ships.assign([live, unsupported, detached])
	flow._sync_network_moving_interior_presenter()
	_check(live.capability_queries == 1 and not presenter._frames.has(&"frame_retired_cabin"),
		"a formerly live craft is neither queried nor newly registered after detaching")
	root.add_child(live)
	flow._sync_network_moving_interior_presenter()
	_check(live.capability_queries == 2 and presenter._frames.has(&"frame_retired_cabin"),
		"a supported cabin registers again after re-entry")
	root.remove_child(presenter)
	flow._sync_network_moving_interior_presenter()
	_check(live.capability_queries == 2,
		"a detached presenter does not query the remaining fleet during teardown")
	root.add_child(presenter)
	flow._sync_network_moving_interior_presenter()
	_check(live.capability_queries == 3,
		"presenter re-entry resumes live cabin synchronization")
	presenter.queue_free()
	flow._sync_network_moving_interior_presenter()
	_check(live.capability_queries == 3,
		"a queued presenter cannot query or register the fleet")
	flow.ships.clear()
	flow._network_moving_interior_presenter = null
	flow._network_remote_body_intent_source = null
	flow.free()
	live.free()
	unsupported.free()
	detached.free()
	await process_frame


func _check_client_shutdown_prediction_lifecycle() -> void:
	var flow := GameFlow.new()
	var craft := CabinCapabilityProbe.new()
	root.add_child(craft)
	var body := PLAYER_SCENE.instantiate() as PlayerController
	root.add_child(body)
	body.set_process(false)
	body.set_physics_process(false)
	var frame := MovingInteriorFrame.new()
	root.add_child(frame)
	frame.set_physics_process(false)
	frame.configure(craft)
	_check(bool(frame.register_occupant(body, {"require_inside_bounds": false}).get("registered", false)),
		"shutdown fixture registers the client body with a real moving frame")
	# Seed an existing grant directly: this bounded regression exercises grant
	# retirement, while admission itself is covered by the ENet prediction suite.
	var state: Dictionary = frame._occupants[body.get_instance_id()]
	state["prediction_peer_id"] = 7
	state["prediction_peer"] = weakref(body)
	state["prediction_admission"] = func() -> bool: return true
	craft.fixture_frame = frame
	flow.player = body
	flow._cabin_ship = craft
	flow._network_session_mode = &"client"
	flow._on_network_session_stopped(&"prediction_lifecycle_test")
	_check(craft.report_queries == 1,
		"client shutdown still resolves the live cabin prediction frame")
	_check(not state.has("prediction_peer_id") and not state.has("prediction_peer")
		and not state.has("prediction_admission"),
		"client shutdown clears every local prediction grant field on a live frame")
	root.remove_child(craft)
	flow._network_session_mode = &"client"
	flow._on_network_session_stopped(&"detached_prediction_test")
	_check(craft.report_queries == 1,
		"client shutdown never queries geometry reports on a detached cabin")
	root.add_child(craft)
	craft.queue_free()
	flow._network_session_mode = &"client"
	flow._on_network_session_stopped(&"queued_prediction_test")
	_check(craft.report_queries == 1,
		"client shutdown never queries geometry reports on a queued cabin")
	flow._cabin_ship = null
	flow.player = null
	flow.free()
	frame.free()
	body.free()
	await process_frame


func _check(condition: bool, description: String) -> void:
	_assertions += 1
	if not condition:
		_failures.append("FAIL: " + description)
