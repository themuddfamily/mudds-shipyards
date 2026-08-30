extends SceneTree

## Focused production proof for the read-only Fleet Registry terminal. The real
## PlayerController walks into the shared station candidate, uses the ordinary
## interaction dispatch, and receives detached fleet rows without changing any
## berth lease or pending-regeneration entry.

const MAIN_SCENE := preload("res://scenes/main.tscn")
const VALID_STATES: Array[StringName] = [
	&"available", &"occupied", &"destroyed", &"regenerating",
]

var _failures := PackedStringArray()
var _assertions := 0


func _init() -> void:
	call_deferred(&"_run")


func _run() -> void:
	var game := MAIN_SCENE.instantiate() as GameFlow
	root.add_child(game)
	await process_frame
	await physics_frame
	game.start_shift()
	await process_frame

	var player := game.player as PlayerController
	var console := game.world.call(&"get_fleet_registry_console") as Area3D
	_check(
		player != null and console != null,
		"production Main exposes the real Player and Fleet Registry terminal"
	)
	if player == null or console == null:
		await _finish(game)
		return

	var staged_position := console.global_position + Vector3(0.0, 0.0, -2.8)
	player.teleport_to(Transform3D(Basis(Vector3.UP, PI), staged_position))
	await physics_frame
	var walk_start := player.global_position
	Input.action_press(&"move_forward")
	for _frame in 50:
		await physics_frame
		await process_frame
		if game.station_interaction_candidate == console:
			break
	Input.action_release(&"move_forward")
	await physics_frame
	await process_frame
	_check(
		player.global_position.distance_to(walk_start) > 0.35
			and game.station_interaction_candidate == console
			and str(console.call(&"get_interaction_prompt")).contains("VIEW FLEET REGISTRY"),
		"normal locomotion reaches the existing shared interaction candidate and prompt"
	)

	var berths_before := _berth_snapshot(game.world)
	var regeneration_before := _regeneration_snapshot(game)
	game.call(&"_on_interact_requested")
	await process_frame
	var presented := console.call(&"get_presentation_snapshot") as Dictionary
	var live_snapshot := presented.get("last_snapshot", {}) as Dictionary
	var rows := live_snapshot.get("rows", []) as Array
	var text := str(presented.get("screen_text", ""))
	var rows_are_live_and_complete := rows.size() == game.ships.size() and not rows.is_empty()
	for row_raw: Variant in rows:
		var row := row_raw as Dictionary
		var state := StringName(row.get("state", &""))
		rows_are_live_and_complete = (
			rows_are_live_and_complete
			and state in VALID_STATES
			and text.contains(String(row.get("display_name", "")).to_upper().left(18))
			and text.contains(String(state).to_upper())
		)
	_check(
		int(presented.get("presentation_sequence", 0)) == 1
			and rows_are_live_and_complete
			and not _contains_object(live_snapshot),
		"one shared interaction paints every retained craft as detached available/occupied/destroyed/regenerating data"
	)
	_check(
		_berth_snapshot(game.world) == berths_before
			and _regeneration_snapshot(game) == regeneration_before,
		"reading the registry changes no berth owner, occupant, token, or regeneration entry"
	)
	var authority := presented.get("authority", {}) as Dictionary
	_check(
		authority == {
			"berth": false,
			"regeneration": false,
			"ship_lifecycle": false,
			"fleet_membership": false,
		},
		"the terminal publishes explicit zero-authority presentation ownership"
	)

	# Exercise the complete screen vocabulary with detached values only. This is
	# presentation input, not a forged ship/berth fixture, and must remain unable
	# to alter production lifecycle state.
	var vocabulary_snapshot := live_snapshot.duplicate(true)
	vocabulary_snapshot["rows"] = [
		{"ship_id": &"a", "display_name": "Available", "berth_id": &"a", "state": &"available"},
		{"ship_id": &"b", "display_name": "Occupied", "berth_id": &"b", "state": &"occupied"},
		{"ship_id": &"c", "display_name": "Destroyed", "berth_id": &"c", "state": &"destroyed"},
		{"ship_id": &"d", "display_name": "Regenerating", "berth_id": &"d", "state": &"regenerating"},
	]
	var receipt := console.call(&"present_fleet_snapshot", vocabulary_snapshot) as Dictionary
	presented = console.call(&"get_presentation_snapshot") as Dictionary
	text = str(presented.get("screen_text", ""))
	_check(
		bool(receipt.get("accepted", false))
			and text.contains("AVAILABLE")
			and text.contains("OCCUPIED")
			and text.contains("DESTROYED")
			and text.contains("REGENERATING")
			and _berth_snapshot(game.world) == berths_before
			and _regeneration_snapshot(game) == regeneration_before,
		"the detached screen renders all four promised states with no authority side effect"
	)
	var sequence_before_rejection := int(presented.get("presentation_sequence", 0))
	var authority_bearing_snapshot := vocabulary_snapshot.duplicate(true)
	authority_bearing_snapshot["live_world"] = game.world
	receipt = console.call(&"present_fleet_snapshot", authority_bearing_snapshot) as Dictionary
	presented = console.call(&"get_presentation_snapshot") as Dictionary
	_check(
		not bool(receipt.get("accepted", true))
			and StringName(receipt.get("reason", &"")) == &"registry_snapshot_not_detached"
			and int(presented.get("presentation_sequence", 0)) == sequence_before_rejection,
		"the terminal refuses Object-bearing input instead of retaining live authority"
	)
	var callable_bearing_snapshot := vocabulary_snapshot.duplicate(true)
	callable_bearing_snapshot["live_callback"] = Callable(game, &"queue_free")
	receipt = console.call(
		&"present_fleet_snapshot", callable_bearing_snapshot
	) as Dictionary
	presented = console.call(&"get_presentation_snapshot") as Dictionary
	_check(
		not bool(receipt.get("accepted", true))
			and StringName(receipt.get("reason", &"")) \
				== &"registry_snapshot_not_detached"
			and int(presented.get("presentation_sequence", 0)) \
				== sequence_before_rejection,
		"the terminal refuses Callables that retain live object/method authority"
	)

	await _finish(game)


func _berth_snapshot(world: Node) -> Dictionary:
	var snapshot := {}
	for berth_id: StringName in world.call(&"get_berth_ids") as Array[StringName]:
		var berth := world.call(&"get_berth_node", berth_id) as ShipBerth
		var owner := berth.get_reservation_owner() if berth != null else null
		var occupant := berth.get_occupant() if berth != null else null
		snapshot[berth_id] = {
			"owner_instance_id": owner.get_instance_id() if is_instance_valid(owner) else 0,
			"occupant_instance_id": occupant.get_instance_id() if is_instance_valid(occupant) else 0,
			"reserved_ship_id": berth.get_reserved_ship_id() if berth != null else &"",
			"token": berth.get_reservation_token(owner) if is_instance_valid(owner) else &"",
		}
	return snapshot


func _regeneration_snapshot(game: GameFlow) -> Dictionary:
	var snapshot := {}
	var pending := game.get("_regeneration_pending") as Dictionary
	for instance_id_raw: Variant in pending.keys():
		var entry := pending.get(instance_id_raw, {}) as Dictionary
		var ship_ref := entry.get("ship") as WeakRef
		var pending_ship: Object = ship_ref.get_ref() if ship_ref != null else null
		snapshot[int(instance_id_raw)] = {
			"ready_at_msec": int(entry.get("ready_at_msec", 0)),
			"ship_instance_id": (
				pending_ship.get_instance_id() if is_instance_valid(pending_ship) else 0
			),
		}
	return snapshot


func _contains_object(value: Variant) -> bool:
	if value is Object:
		return true
	if value is Dictionary:
		for key: Variant in (value as Dictionary).keys():
			if _contains_object(key) or _contains_object((value as Dictionary).get(key)):
				return true
	elif value is Array:
		for item: Variant in value as Array:
			if _contains_object(item):
				return true
	return false


func _check(condition: bool, message: String) -> void:
	_assertions += 1
	if not condition:
		_failures.append("FAIL: " + message)


func _finish(game: GameFlow) -> void:
	Input.action_release(&"move_forward")
	if is_instance_valid(game):
		game.queue_free()
	await process_frame
	await process_frame
	if _failures.is_empty():
		print("FLEET_REGISTRY_CONSOLE_PRODUCTION_TEST_OK: %d assertions" % _assertions)
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)
