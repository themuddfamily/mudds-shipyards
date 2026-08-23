extends SceneTree

const BOARDING_AREA_SCENE := "res://scenes/interaction/ship_boarding_area.tscn"
const PLAYER_SCENE := "res://scenes/player/player.tscn"
const INTERACTABLE_LAYER := 1 << 3
const BOARDING_RADIUS_METRES := 4.5
const PLAYER_INTERACTION_RADIUS_METRES := 2.35

var _failures: Array[String] = []
var _reservation_events: Array[Dictionary] = []
var _availability_events: Array[bool] = []


class DummyCompatibleShip extends Node3D:
	var boardable := true
	var seat_anchor: Marker3D


	func _init() -> void:
		seat_anchor = Marker3D.new()
		seat_anchor.name = "PilotSeatAnchor"
		add_child(seat_anchor)


	func get_boarding_entry_transform() -> Transform3D:
		return global_transform


	func get_pilot_seat_anchor() -> Node3D:
		return seat_anchor


	func is_boardable() -> bool:
		return boardable


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var original_root_child_count := root.get_child_count()
	var area_scene := load(BOARDING_AREA_SCENE) as PackedScene
	var player_scene := load(PLAYER_SCENE) as PackedScene
	_check(area_scene != null, "boarding-area scene loads")
	_check(player_scene != null, "production player scene loads")
	if area_scene == null or player_scene == null:
		_finish()
		return

	var host := Node3D.new()
	host.name = "ShipBoardingAreaTestWorld"
	root.add_child(host)

	var ship := DummyCompatibleShip.new()
	ship.name = "DummyCompatibleShip"
	host.add_child(ship)
	var area := area_scene.instantiate() as ShipBoardingArea
	area.name = "BoardingPoint"
	area.position = Vector3(0.0, 1.05, 0.0)
	area.interaction_id = &"board_test_ship"
	area.prompt_text = "[ E ]  BOARD TEST SHIP"
	area.reservation_changed.connect(_on_reservation_changed)
	area.availability_changed.connect(_on_availability_changed)
	ship.add_child(area)

	var player := player_scene.instantiate() as CharacterBody3D
	player.name = "DiscoveryPlayer"
	host.add_child(player)
	player.set_physics_process(false)
	player.set_process(false)
	player.global_position = Vector3.ZERO

	await _physics_frames(3)

	_check(area.collision_layer == INTERACTABLE_LAYER, "enabled area occupies the named Interactable layer")
	_check(area.collision_mask == 0, "boarding point has no collision scan mask")
	_check(not area.monitoring and area.monitorable, "boarding point is discoverable without scanning other bodies")
	var shape := area.get_node_or_null("BoardingRange") as CollisionShape3D
	_check(shape != null and shape.shape is SphereShape3D, "boarding point contains a physical spherical discovery volume")
	_check(
		shape != null
		and is_equal_approx((shape.shape as SphereShape3D).radius, BOARDING_RADIUS_METRES),
		"craft-side boarding discovery radius is exactly 4.5 metres"
	)
	_check(shape != null and not shape.disabled, "enabled boarding discovery shape is active")
	var player_interaction_shape := player.get_node_or_null(
		"InteractionArea/InteractionShape"
	) as CollisionShape3D
	_check(
		player_interaction_shape != null
		and player_interaction_shape.shape is SphereShape3D
		and is_equal_approx(
			(player_interaction_shape.shape as SphereShape3D).radius,
			PLAYER_INTERACTION_RADIUS_METRES
		),
		"wider craft access leaves the production player's 2.35-metre interaction sphere unchanged"
	)
	_check(area.get_ship() == ship, "default relative owner path resolves the compatible parent ship")
	_check(area.get_interaction_id() == &"board_test_ship", "exported interaction identifier is exposed exactly")
	_check(area.get_prompt() == "[ E ]  BOARD TEST SHIP", "exported boarding prompt is exposed exactly")
	var boarding_audio: RefCounted = area.get_audio_binding()
	var boarding_cues: Array[StringName] = []
	boarding_audio.semantic_boarding_cue_emitted.connect(func(cue_id: StringName, _seat_id: StringName, _intensity: float) -> void: boarding_cues.append(cue_id))
	_check(bool(boarding_audio.get_snapshot().attached), "boarding area composes an attached seat audio binding")
	_check(int(boarding_audio.get_snapshot().maximum_simultaneous_voices) == 2, "boarding audio stays within a two-voice ceiling")
	_check(area.is_available(), "unoccupied boardable ship begins available")
	_check(_player_discovers(player, area), "production player interaction area discovers the layer-4 boarding point")

	ship.boardable = false
	_check(not area.is_available(), "owner-level boarding denial suppresses availability")
	ship.boardable = true
	_check(area.is_available(), "owner-level boarding recovery restores availability")

	var first_player_token := Node.new()
	first_player_token.name = "FirstPilotToken"
	host.add_child(first_player_token)
	var second_player_token := Node.new()
	second_player_token.name = "SecondPilotToken"
	host.add_child(second_player_token)

	_check(area.try_reserve(first_player_token), "first contender atomically reserves the seat")
	_check(boarding_cues == [&"boarding_seat_reserved", &"boarding_started"], "accepted reservation emits reserve and boarding-start cues")
	_check(area.is_reserved(), "reservation state is observable")
	_check(area.get_reservation_token() == first_player_token, "reservation retains the exact occupant token")
	_check(not area.is_available(), "reserved seat is unavailable to unqualified callers")
	_check(area.is_available_for(first_player_token), "reservation owner may complete its boarding handoff")
	_check(not area.is_available_for(second_player_token), "second contender cannot use the occupied seat")
	_check(area.try_reserve(first_player_token), "same-token reservation is idempotent")
	_check(not area.try_reserve(second_player_token), "second contender cannot steal the reservation")
	_check(not area.release_reservation(second_player_token), "non-owner cannot release another player's seat")
	_check(area.release_reservation(first_player_token), "reservation owner releases the seat")
	_check(boarding_cues == [&"boarding_seat_reserved", &"boarding_started", &"boarding_release"], "release emits one boarding-release cue")
	_check(bool(boarding_audio.present_event({"event_id": &"seated", "generation": int(boarding_audio.get_snapshot().generation), "sequence": 10, "accepted": true}).accepted), "seated transition accepts the matching generation")
	_check(not bool(boarding_audio.present_event({"event_id": &"seated", "generation": int(boarding_audio.get_snapshot().generation), "sequence": 10, "accepted": true}).accepted), "duplicate seat transition is suppressed")
	_check(bool(boarding_audio.present_event({"event_id": &"controls_ready", "generation": int(boarding_audio.get_snapshot().generation), "sequence": 11, "accepted": true}).accepted), "controls-ready transition emits a semantic cue")
	_check(bool(boarding_audio.present_event({"event_id": &"disembark", "generation": int(boarding_audio.get_snapshot().generation), "sequence": 12, "accepted": true}).accepted), "disembark transition emits a semantic cue")
	_check(bool(boarding_audio.present_event({"event_id": &"rejected", "generation": int(boarding_audio.get_snapshot().generation), "sequence": 13, "accepted": true}).accepted), "rejected boarding transition emits a semantic cue")
	_check(not bool(boarding_audio.present_event({"event_id": &"release", "generation": int(boarding_audio.get_snapshot().generation) - 1, "sequence": 14, "accepted": true}).accepted), "stale boarding generation is rejected")
	_check(area.is_available(), "released seat becomes available again")

	_check(area.try_reserve(first_player_token), "seat can be reserved again before disabling")
	area.set_boarding_enabled(false)
	await _physics_frames(3)
	_check(not area.is_reserved(), "safe disable clears the occupant reservation")
	_check(not area.is_available(), "disabled boarding point reports unavailable")
	_check(area.collision_layer == 0 and not area.monitorable, "disabled point leaves physics discovery")
	_check(shape != null and shape.disabled, "disabled point deactivates its collision shape")
	_check(not _player_discovers(player, area), "production player no longer discovers a disabled point")

	area.set_boarding_enabled(true)
	await _physics_frames(3)
	_check(area.collision_layer == INTERACTABLE_LAYER and area.monitorable, "reenabling restores Interactable discovery")
	_check(shape != null and not shape.disabled, "reenabling restores the physical discovery shape")
	_check(area.is_available(), "reenabled unoccupied seat becomes available")
	_check(_player_discovers(player, area), "production player rediscovers the reenabled point")

	_check(area.try_reserve(first_player_token), "seat reserves before owner detach")
	var detach_reentry_probe := {"attempted": false, "accepted": true}
	area.reservation_changed.connect(
		func(reserved: bool, released_token: Variant) -> void:
			if reserved or released_token != first_player_token:
				return
			detach_reentry_probe["attempted"] = true
			detach_reentry_probe["accepted"] = area.try_reserve(second_player_token),
		CONNECT_ONE_SHOT
	)
	host.remove_child(ship)
	await process_frame
	_check(not bool(boarding_audio.get_snapshot().attached), "boarding-area detach clears seat audio lifecycle")
	_check(
		bool(detach_reentry_probe.attempted)
		and not bool(detach_reentry_probe.accepted)
		and not area.is_inside_tree()
		and not area.is_reserved()
		and area.get_reservation_token() == null
		and not area.is_available()
		and not area.is_available_for(first_player_token)
		and not area.try_reserve(first_player_token),
		"detached ship clears its reservation and rejects ordinary or hostile boarding handoffs"
	)
	host.add_child(ship)
	await _physics_frames(3)
	_check(
		area.is_available()
		and _player_discovers(player, area)
		and area.try_reserve(second_player_token)
		and area.get_reservation_token() == second_player_token,
		"re-entry restores physical discovery without carrying the detached pilot token"
	)
	_check(area.release_reservation(second_player_token), "new pilot releases the re-entered seat")
	_availability_events.clear()
	host.remove_child(ship)
	await process_frame
	host.add_child(ship)
	await _physics_frames(3)
	_check(
		_availability_events == [false, true]
		and area.is_available()
		and _player_discovers(player, area)
		and not area.is_reserved()
		and area.get_reservation_token() == null,
		"unreserved ship re-entry publishes false then true availability without reviving a reservation"
	)

	_check(area.try_reserve(first_player_token), "object token reserves before lifetime cleanup")
	first_player_token.queue_free()
	await process_frame
	_check(area.is_available(), "freed object reservation is detected and released safely")
	_check(not area.is_reserved(), "stale occupant token does not retain the seat")
	var availability_count_before_queued_reentry := _availability_events.size()
	host.remove_child(ship)
	await process_frame
	host.add_child(ship)
	area.queue_free()
	area.call("_publish_availability_after_reentry")
	_check(
		area.is_queued_for_deletion()
		and not area.is_available()
		and not area.try_reserve(second_player_token)
		and not area.is_reserved()
		and area.get_reservation_token() == null
		and _availability_events.size() == availability_count_before_queued_reentry + 1
		and _availability_events.back() == false,
		"queued re-entry rejects deferred availability and reservation before reviving a boarding prompt"
	)
	for _frame in 3:
		await process_frame
	_check(
		_availability_events.size() == availability_count_before_queued_reentry + 1
		and _availability_events.back() == false,
		"queued boarding-area disposal publishes no late availability after the deferred turn"
	)

	await _test_live_enablement_currentness(area_scene, host)

	var incompatible_parent := Node3D.new()
	incompatible_parent.name = "IncompatibleOwner"
	host.add_child(incompatible_parent)
	var invalid_area := area_scene.instantiate() as ShipBoardingArea
	incompatible_parent.add_child(invalid_area)
	await process_frame
	_check(invalid_area.get_ship() == null, "owner resolution rejects a ship without the boarding contract")
	_check(not invalid_area.is_available(), "invalid owner cannot expose an available boarding prompt")

	_check(_reservation_events.size() == 10, "reservation signals report claims, releases, disable, detach, re-entry, and stale cleanup exactly once")
	_check(_availability_events.has(false) and _availability_events.has(true), "availability transitions are signalled in both directions")

	host.queue_free()
	await process_frame
	await process_frame
	await process_frame
	_check(root.get_child_count() == original_root_child_count, "boarding-area fixture cleans up every node")
	_finish()


func _test_live_enablement_currentness(area_scene: PackedScene, host: Node3D) -> void:
	var ship := DummyCompatibleShip.new()
	ship.name = "LifecycleCurrentnessShip"
	host.add_child(ship)
	var area := area_scene.instantiate() as ShipBoardingArea
	ship.add_child(area)
	await _physics_frames(2)
	var shape := area.get_node_or_null("BoardingRange") as CollisionShape3D
	var availability_events: Array[bool] = []
	area.availability_changed.connect(
		func(available: bool) -> void:
			availability_events.append(available)
	)

	host.remove_child(ship)
	await process_frame
	availability_events.clear()
	var detached_snapshot := _enablement_snapshot(area, shape)
	area.set_boarding_enabled(false)
	area.boarding_enabled = false
	_check(
		not area.is_inside_tree()
			and _enablement_snapshot(area, shape) == detached_snapshot
			and availability_events.is_empty(),
		"detached initialized boarding-area enablement calls preserve retained discovery state and availability"
	)

	host.add_child(ship)
	await _physics_frames(2)
	area.set_boarding_enabled(false)
	await _physics_frames(2)
	var disabled_live := not area.boarding_enabled \
		and area.collision_layer == 0 \
		and not area.monitorable \
		and shape != null and shape.disabled
	area.boarding_enabled = true
	await _physics_frames(2)
	_check(
		disabled_live
			and area.boarding_enabled
			and area.collision_layer == INTERACTABLE_LAYER
			and area.monitorable
			and shape != null and not shape.disabled,
		"reentered live boarding-area enablement still updates the authored discovery contract"
	)

	availability_events.clear()
	var queued_snapshot := _enablement_snapshot(area, shape)
	area.queue_free()
	area.set_boarding_enabled(false)
	area.boarding_enabled = false
	_check(
		area.is_inside_tree()
			and area.is_queued_for_deletion()
			and _enablement_snapshot(area, shape) == queued_snapshot
			and availability_events.is_empty(),
		"queued boarding-area enablement calls preserve discovery state and publish no availability change"
	)
	await process_frame
	ship.queue_free()
	await process_frame


func _enablement_snapshot(area: ShipBoardingArea, shape: CollisionShape3D) -> Dictionary:
	return {
		"enabled": area.boarding_enabled,
		"collision_layer": area.collision_layer,
		"collision_mask": area.collision_mask,
		"monitoring": area.monitoring,
		"monitorable": area.monitorable,
		"shape_disabled": shape.disabled if shape != null else true,
		"reserved": area.is_reserved(),
		"reservation_token": area.get_reservation_token(),
	}.duplicate(true)


func _player_discovers(player: Node, area: ShipBoardingArea) -> bool:
	var nearby: Array[Node3D] = player.call("get_nearby_interactables")
	return nearby.has(area)


func _physics_frames(count: int) -> void:
	for _index in count:
		await physics_frame


func _on_reservation_changed(reserved: bool, token: Variant) -> void:
	_reservation_events.append({"reserved": reserved, "token": token})


func _on_availability_changed(available: bool) -> void:
	_availability_events.append(available)


func _check(condition: bool, description: String) -> void:
	if condition:
		print("PASS: ", description)
	else:
		_failures.append(description)
		push_error("FAIL: " + description)


func _finish() -> void:
	if _failures.is_empty():
		print("SHIP_BOARDING_AREA_TEST_OK")
		quit(0)
	else:
		print("SHIP_BOARDING_AREA_TEST_FAILED: ", ", ".join(_failures))
		quit(1)
