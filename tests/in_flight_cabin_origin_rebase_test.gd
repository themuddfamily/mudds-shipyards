extends SceneTree

## A crew member walking the Halyard's cabin under way keeps their place aboard
## across a real common-world origin rebase.
##
## Reproduction on real Main: board the Halyard, fly it clear of the yard, idle
## it offline and leave the seat into the cabin, walk aft, then let the hull
## carry the walker past the 10 km origin-shift threshold. The production
## rebase owner translates the hull and the player by the same delta; the
## interior frame then read that translation as hull motion and carried the
## player by it a second time, 12 km outside the hull, where cabin containment
## hard-recalled them to the stand pose at the cockpit.

const MAIN_SCENE := preload("res://scenes/main.tscn")
const FLIGHT_CONTROL_ACTIONS := [
	&"move_forward", &"move_back", &"move_left", &"move_right",
	&"pitch_up", &"pitch_down", &"roll_left", &"roll_right",
	&"sprint_boost", &"brake", &"hover", &"fire", &"barrel_roll",
	&"landing_assist", &"interact",
]
const FAR_CARRY := Vector3(12000.0, 0.0, 0.0)

var _assertions := 0
var _failures: Array[String] = []


func _initialize() -> void:
	var flow := MAIN_SCENE.instantiate() as GameFlow
	root.add_child(flow)
	for i in 60:
		await physics_frame
	flow.canopy_motion_time = 0.02
	flow.boarding_motion_time = 0.04
	flow.disembarking_motion_time = 0.04
	flow.start_shift()
	var craft := flow.get_node("HalyardCrewTransport") as HalyardCrewTransport
	var player := flow.player as PlayerController
	var frame := craft.get_moving_interior_component()
	var owner := flow.get_node(^"CommonWorldOriginRebaseOwner") as CommonWorldOriginRebaseOwner

	player.teleport_to(Transform3D(Basis.IDENTITY, craft.get_boarding_position() + Vector3.UP * 0.05))
	await _settle(4)
	flow.call(&"_board_ship", craft)
	for i in 600:
		if flow.phase == GameFlow.Phase.START_ENGINES and not bool(flow.get(&"_transition_busy")):
			break
		await physics_frame
	_check(player.is_seated() and craft.is_piloted(), "the Halyard seats its pilot")
	var start := craft.global_position
	Input.action_press(&"move_forward")
	for tick in 420:
		await physics_frame
		if Vector2(craft.global_position.x - start.x, craft.global_position.z - start.z).length() > 150.0:
			break
	Input.action_release(&"move_forward")
	await _idle(craft)
	_dispatch(flow, &"interact")
	for i in 120:
		await _settle(1)
		if bool(flow.get_in_flight_cabin_status().get("carried", false)):
			break
	_check(
		flow.phase == GameFlow.Phase.IN_FLIGHT_CABIN and frame.is_occupant_registered(player),
		"the pilot leaves the seat into the cabin of the flying Halyard"
	)

	# Walk aft, away from the stand pose, so a containment recall is visible.
	Input.action_press(&"move_forward")
	for i in 240:
		await _settle(1)
		if craft.to_local(player.global_position).z > HalyardCrewTransport.CABIN_STAND_LOCAL_ORIGIN.z + 6.0:
			break
	Input.action_release(&"move_forward")
	await _settle(8)
	craft.velocity = Vector3.ZERO
	await _settle(2)

	var transactions_before := int(owner.get_snapshot().get("transaction_count", 0))
	# The hull carries its walker far from the origin; the running game rebases.
	var local_before := craft.to_local(player.global_position)
	var recalls_before := int(player.get_cabin_containment_report().get("recall_count", 0))
	craft.global_position += FAR_CARRY
	var committed := false
	for i in 30:
		await _settle(1)
		if int(owner.get_snapshot().get("transaction_count", 0)) != transactions_before:
			committed = true
			break
	await _settle(6)
	var local_after := craft.to_local(player.global_position)
	var report := player.get_cabin_containment_report()
	print("CABIN_REBASE: committed=", committed, " delta=",
		owner.get_snapshot().get("last_translation_delta"),
		" local ", local_before, " -> ", local_after,
		" recalls ", recalls_before, " -> ", report.get("recall_count"))
	_check(committed, "the running game commits a real origin rebase while the pilot walks the cabin")
	_check(
		local_after.distance_to(local_before) < 0.1,
		"the walker keeps their exact place aboard across the rebase (moved %.3f m)"
			% local_after.distance_to(local_before)
	)
	_check(
		int(report.get("recall_count", 0)) == recalls_before
			and bool(report.get("contained", false))
			and frame.is_occupant_registered(player),
		"the rebase does not throw the walker out of the hull into a containment recall"
	)
	_check(
		craft.global_position.distance_to(player.global_position) < 20.0,
		"the walker is still aboard the hull in the rebased world"
	)

	for action: StringName in FLIGHT_CONTROL_ACTIONS:
		Input.action_release(action)
	flow.queue_free()
	await _settle(2)
	if _failures.is_empty():
		print("IN_FLIGHT_CABIN_ORIGIN_REBASE_TEST_OK: %d assertions" % _assertions)
		quit(0)
	else:
		print("IN_FLIGHT_CABIN_ORIGIN_REBASE_TEST_FAILED: %s" % "; ".join(_failures))
		quit(1)


func _settle(n: int) -> void:
	for i in n:
		await physics_frame
		await process_frame


func _idle(craft: HeroShip) -> void:
	for action: StringName in FLIGHT_CONTROL_ACTIONS:
		Input.action_release(action)
	var ticks := int(ceil(
		(HeroShip.AUTOMATIC_ENGINE_IDLE_SHUTDOWN_SECONDS + 0.1) * Engine.physics_ticks_per_second
	))
	await _settle(ticks)
	_check(
		StringName(craft.get_telemetry().get("engine_state", &"")) == HeroShip.ENGINE_OFFLINE,
		"released controls idle the Halyard offline in open space"
	)


func _dispatch(flow: GameFlow, action: StringName) -> void:
	var event := InputEventAction.new()
	event.action = action
	event.pressed = true
	flow._unhandled_input(event)


func _check(condition: bool, description: String) -> void:
	_assertions += 1
	if condition:
		print("PASS: ", description)
	else:
		_failures.append(description)
		push_error("FAIL: " + description)
