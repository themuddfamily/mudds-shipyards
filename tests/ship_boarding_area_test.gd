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
	_check(area.is_reserved(), "reservation state is observable")
	_check(area.get_reservation_token() == first_player_token, "reservation retains the exact occupant token")
	_check(not area.is_available(), "reserved seat is unavailable to unqualified callers")
	_check(area.is_available_for(first_player_token), "reservation owner may complete its boarding handoff")
	_check(not area.is_available_for(second_player_token), "second contender cannot use the occupied seat")
	_check(area.try_reserve(first_player_token), "same-token reservation is idempotent")
	_check(not area.try_reserve(second_player_token), "second contender cannot steal the reservation")
	_check(not area.release_reservation(second_player_token), "non-owner cannot release another player's seat")
	_check(area.release_reservation(first_player_token), "reservation owner releases the seat")
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

	_check(area.try_reserve(first_player_token), "object token reserves before lifetime cleanup")
	first_player_token.queue_free()
	await process_frame
	_check(area.is_available(), "freed object reservation is detected and released safely")
	_check(not area.is_reserved(), "stale occupant token does not retain the seat")

	var incompatible_parent := Node3D.new()
	incompatible_parent.name = "IncompatibleOwner"
	host.add_child(incompatible_parent)
	var invalid_area := area_scene.instantiate() as ShipBoardingArea
	incompatible_parent.add_child(invalid_area)
	await process_frame
	_check(invalid_area.get_ship() == null, "owner resolution rejects a ship without the boarding contract")
	_check(not invalid_area.is_available(), "invalid owner cannot expose an available boarding prompt")

	_check(_reservation_events.size() == 6, "reservation signals report claims, releases, disable, and stale cleanup exactly once")
	_check(_availability_events.has(false) and _availability_events.has(true), "availability transitions are signalled in both directions")

	host.queue_free()
	await process_frame
	await process_frame
	await process_frame
	_check(root.get_child_count() == original_root_child_count, "boarding-area fixture cleans up every node")
	_finish()


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
