extends SceneTree

## Every parked craft whose nose faces station structure leaves its berth on the
## control the HUD names — "[ W/S / LEFT STICK ] APPLY THRUST" — without
## touching anything.
##
## Reproduction: on real Main, boarding and holding `move_forward` flew the
## Cinder light interceptor into Dock 04's threshold beam and destroyed it, the
## long-range bomber into the Modern Fleet Registry roof, the cargo hauler into
## the VIP reception glazing 1.2 m ahead of its nose, and the Halyard into the
## Upper Operations pod. The craft sit on their decks among kerbs, beams and
## buildings, and nose-forward thrust alone cannot climb. Their berths now
## publish a departure lift that mirrors the landing assist's vertical descent.
##
## Each craft gets its own fresh Main, is boarded through the production seat
## seam and flown only by holding the real `move_forward` action. Floor contact
## while it is still resting on its deck is not a collision; anything else is.

const MAIN_SCENE := preload("res://scenes/main.tscn")
const CRAFT_IDS: Array[StringName] = [
	&"cinder_cargo_hauler",
	&"cinder_long_range_bomber",
	&"cinder_light_interceptor",
	&"halyard_new_design",
]
const HOLD_TICKS := 420
## The departure corridor: horizontal distance from the berth that the craft must
## cover, cleanly, while the pilot does nothing but hold thrust.
const CORRIDOR_METRES := 120.0

var _assertions := 0
var _failures: Array[String] = []


func _initialize() -> void:
	for craft_id in CRAFT_IDS:
		await _launch(craft_id)
	Input.action_release(&"move_forward")
	if _failures.is_empty():
		print("PASS berth_departure_launch_test (%d assertions)" % _assertions)
		print("BERTH_DEPARTURE_LAUNCH_OK")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		print("FAIL berth_departure_launch_test (%d failures)" % _failures.size())
		quit(1)


func _launch(craft_id: StringName) -> void:
	var flow := MAIN_SCENE.instantiate() as GameFlow
	root.add_child(flow)
	for i in 120:
		await physics_frame
	flow.start_shift()
	var craft: HeroShip = null
	for candidate: HeroShip in flow.get_flyable_ships():
		if candidate.get_ship_id() == craft_id:
			craft = candidate
	_check(craft != null, "%s is registered as flyable" % craft_id)
	if craft == null:
		await _dispose(flow)
		return
	var player := flow.player as PlayerController
	player.teleport_to(Transform3D(Basis.IDENTITY, craft.get_boarding_position() + Vector3.UP * 0.05))
	for i in 4:
		await physics_frame
	flow.call(&"_board_ship", craft)
	var seated := false
	for i in 600:
		if flow.phase == GameFlow.Phase.START_ENGINES and not bool(flow.get(&"_transition_busy")):
			seated = true
			break
		await physics_frame
	_check(seated, "%s seats its pilot through the production boarding seam" % craft_id)
	if not seated:
		await _dispose(flow)
		return
	var start := craft.global_position
	var hull_before := float(craft.get_telemetry().get("hull", -1.0))
	var foreign_contacts: Array[String] = []
	var peak_horizontal := 0.0
	Input.action_press(&"move_forward")
	for tick in HOLD_TICKS:
		await physics_frame
		var offset := craft.global_position - start
		var horizontal := Vector2(offset.x, offset.z).length()
		peak_horizontal = maxf(peak_horizontal, horizontal)
		for index in craft.get_slide_collision_count():
			var contact := craft.get_slide_collision(index)
			# Resting and lift-off contact with the deck under the craft.
			if contact.get_normal().y > 0.9 and offset.y < 0.5 and horizontal < 0.5:
				continue
			var collider := contact.get_collider()
			foreign_contacts.append("tick %d %s at %s" % [
				tick,
				(collider as Node).get_path() if collider is Node else "?",
				contact.get_position(),
			])
		if peak_horizontal >= CORRIDOR_METRES:
			break
	Input.action_release(&"move_forward")
	var hull_after := float(craft.get_telemetry().get("hull", -1.0))
	_check(
		foreign_contacts.is_empty(),
		"%s holds thrust out of its berth without touching structure (%s)" % [
			craft_id, ", ".join(foreign_contacts.slice(0, 3))
		]
	)
	_check(
		is_equal_approx(hull_after, hull_before),
		"%s leaves its berth undamaged (hull %.1f -> %.1f)" % [craft_id, hull_before, hull_after]
	)
	_check(
		peak_horizontal >= CORRIDOR_METRES,
		"%s clears its %.0f m departure corridor on thrust alone (reached %.1f m)" % [
			craft_id, CORRIDOR_METRES, peak_horizontal
		]
	)
	_check(
		not bool(craft.get_telemetry().get("landed", true)) and flow.phase != GameFlow.Phase.START_ENGINES,
		"%s is airborne and the sortie advanced past START_ENGINES" % craft_id
	)
	print("LAUNCH %s corridor=%.1f m rise=%.2f m hull %.1f -> %.1f contacts=%d" % [
		craft_id, peak_horizontal, craft.global_position.y - start.y,
		hull_before, hull_after, foreign_contacts.size()
	])
	await _dispose(flow)


func _dispose(flow: GameFlow) -> void:
	Input.action_release(&"move_forward")
	root.remove_child(flow)
	flow.free()
	for i in 4:
		await process_frame


func _check(condition: bool, message: String) -> void:
	_assertions += 1
	if not condition:
		_failures.append(message)
