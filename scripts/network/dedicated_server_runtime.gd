extends Node

## Normal Boot owns this coordinator; Main retains all transport and gameplay
## authority. This node only selects hosting and an optional one-session stop.
signal stop_requested(exit_code: int)

var port: int = 0
var max_clients: int = 0
var exit_after_guests: int = 0

var _main: Node
var _session: Node
var _started: bool = false
var _stopping: bool = false
var _armed: bool = false
var _check_pending: bool = false
var _admitted_tuples: Array[Dictionary] = []
var _moving_entities: Dictionary = {}
var _crew_claims: Dictionary = {}
var _owned_ships: Dictionary = {}


func _ready() -> void:
	set_process(false)


func on_startup_completed(main: Node) -> void:
	if _started or _stopping:
		return
	_started = true
	_main = main
	if port < 1 or port > 65535 or max_clients < 1 or max_clients > 32 \
			or exit_after_guests < 0 or exit_after_guests > max_clients:
		_fail("invalid configuration")
		return
	if not _local_authority_is_idle():
		_fail("nonplaying Main authority required")
		return
	# Main creates and owns its usual adapter. The accepted return follows the
	# synchronous server_started signal and the actual ENet listen operation.
	var hosted: Dictionary = _main.call(&"host_network_session", port, max_clients)
	_session = _main.call(&"get_network_session") as Node
	if not bool(hosted.get("accepted", false)) or hosted.get("status") != &"server_started":
		_fail("listen refused")
		return
	if not is_instance_valid(_session):
		_fail("session unavailable")
		return
	var capacity: Dictionary = _session.call(&"get_session_capacity_snapshot")
	var listening: bool = bool(_session.call(&"is_server"))
	var actual_port: int = int(_session.call(&"get_local_port"))
	var peer_id: int = _session.multiplayer.get_unique_id()
	if not listening or actual_port != port or int(capacity.get("max_players", 0)) != max_clients \
			or peer_id != 1 or not _local_authority_is_idle():
		_fail("listener authority mismatch")
		return
	_session.connect(&"session_stopped", _on_session_stopped)
	if exit_after_guests > 0:
		_session.connect(&"peer_admitted", _on_peer_admitted)
		_session.connect(&"peer_disconnected", _on_peer_disconnected)
		_session.connect(&"moving_interior_result", _on_moving_interior_result)
		_session.connect(&"seat_occupancy_result", _on_seat_occupancy_result)
		_session.connect(&"ship_ownership_result", _on_ship_ownership_result)
		set_process(true)
	print("DEDICATED_SERVER_READY pid=%d port=%d max_clients=%d peer_id=%d" % [
		OS.get_process_id(), actual_port, int(capacity.get("max_players", 0)), peer_id])


func _local_authority_is_idle() -> bool:
	if not is_instance_valid(_main) or not _main.is_inside_tree() or int(_main.get(&"phase")) != 0:
		return false
	var player: Node = _main.get(&"player") as Node
	if not is_instance_valid(player) or bool(player.call(&"is_control_enabled")) \
			or bool(player.call(&"is_seated")):
		return false
	var host_seat: Dictionary = _main.call(&"get_network_host_boarding_seat")
	var solo_seat: Dictionary = _main.call(&"get_solo_crew_seat_status")
	var bodies: Dictionary = _main.call(&"get_network_remote_body_audit")
	return host_seat.is_empty() and not bool(solo_seat.get("seated", false)) \
		and (solo_seat.get("assignment", {}) as Dictionary).is_empty() \
		and int(bodies.get("bodies", -1)) == 0


func _on_peer_admitted(_peer_id: int, _receipt: Dictionary) -> void:
	# Admission state is already committed here. Reading it synchronously records
	# real concurrent guests even if a transport leaves before the next frame.
	_refresh_admissions()


func _on_peer_disconnected(_peer_id: int, _receipt: Dictionary) -> void:
	_queue_retirement_check()


func _on_moving_interior_result(result: Dictionary) -> void:
	if not bool(result.get("accepted", false)):
		return
	var occupancy: Dictionary = result.get("occupancy", {}) as Dictionary
	var entity_id: StringName = StringName(occupancy.get("entity_id", &""))
	if not entity_id.is_empty():
		_moving_entities[entity_id] = true


func _on_seat_occupancy_result(result: Dictionary) -> void:
	if not bool(result.get("accepted", false)):
		return
	var assignment: Dictionary = result.get("assignment", {}) as Dictionary
	var peer_id: int = int(assignment.get("occupant_peer_id", 0))
	var avatar_id: StringName = StringName(assignment.get("avatar_id", &""))
	if peer_id > 1 and not avatar_id.is_empty():
		_crew_claims["%d:%s" % [peer_id, avatar_id]] = {"peer_id": peer_id, "avatar_id": avatar_id}


func _on_ship_ownership_result(result: Dictionary) -> void:
	if not bool(result.get("accepted", false)):
		return
	var ship: Dictionary = result.get("ship", {}) as Dictionary
	var ship_id: StringName = StringName(result.get("ship_id", ship.get("ship_id", &"")))
	if not ship_id.is_empty():
		_owned_ships[ship_id] = true


func _refresh_admissions() -> void:
	if _stopping or _armed or not is_instance_valid(_session) or not bool(_session.call(&"is_server")):
		return
	var snapshot: Dictionary = _session.call(&"get_snapshot")
	var lifecycle: Dictionary = snapshot.get("lifecycle", {}) as Dictionary
	var current: Array[Dictionary] = []
	var peer_ids: Dictionary = {}
	for peer: Dictionary in lifecycle.get("peers", []) as Array:
		var peer_id: int = int(peer.get("peer_id", 0))
		var generation: int = int(peer.get("peer_generation", 0))
		if peer_id > 1 and generation > 0 and bool(peer.get("connected", false)) and not peer_ids.has(peer_id):
			peer_ids[peer_id] = true
			current.append({"peer_id": peer_id, "peer_generation": generation})
	var capacity: Dictionary = _session.call(&"get_session_capacity_snapshot")
	if current.size() >= exit_after_guests and int(capacity.get("occupancy", -1)) == current.size():
		_admitted_tuples = current
		_armed = true
		print("DEDICATED_SERVER_GUESTS_ARMED count=%d" % _admitted_tuples.size())


func _process(_delta: float) -> void:
	if _stopping:
		return
	_refresh_admissions()
	if _armed:
		_queue_retirement_check()


func _queue_retirement_check() -> void:
	if _stopping or not _armed or _check_pending:
		return
	_check_pending = true
	_finish_when_retired.call_deferred()


func _ownership_is_retired() -> bool:
	if not is_instance_valid(_main) or not is_instance_valid(_session) \
			or not bool(_session.call(&"is_server")):
		return false
	var capacity: Dictionary = _session.call(&"get_session_capacity_snapshot")
	if int(capacity.get("occupancy", -1)) != 0:
		return false
	var snapshot: Dictionary = _session.call(&"get_snapshot")
	var lifecycle: Dictionary = snapshot.get("lifecycle", {}) as Dictionary
	if not (lifecycle.get("peers", []) as Array).is_empty():
		return false
	var seats: Dictionary = lifecycle.get("seats", {}) as Dictionary
	if not (seats.get("assignments", []) as Array).is_empty():
		return false
	var ships: Dictionary = lifecycle.get("ships", {}) as Dictionary
	for ship: Dictionary in ships.get("ships", []) as Array:
		if int(ship.get("owner_peer_id", 0)) != 0:
			return false
	var roles: Dictionary = _session.call(&"get_crew_role_snapshot")
	var boarding: Dictionary = _session.call(&"get_boarding_snapshot")
	var movement: Dictionary = _session.call(&"get_movement_authority_audit")
	var bodies: Dictionary = _main.call(&"get_network_remote_body_audit")
	var pilots: Dictionary = _main.call(&"get_network_remote_pilot_audit")
	if int(roles.get("role_count", -1)) != 0 or not (boarding.get("occupancies", []) as Array).is_empty() \
			or int(movement.get("registered_avatar_count", -1)) != 0 or int(bodies.get("bodies", -1)) != 0 \
			or not (pilots.get("pilots", []) as Array).is_empty():
		return false
	# These are the adapter's actual crew/ship ledgers, distinct from the
	# disconnect lifecycle's own seat/ship registration tables above.
	for claim: Dictionary in _crew_claims.values():
		var assignment: Dictionary = _session.call(&"get_crew_assignment", int(claim.peer_id), StringName(claim.avatar_id))
		var relationship: Dictionary = _session.call(&"get_crew_moving_interior_relationship", int(claim.peer_id), StringName(claim.avatar_id))
		if not assignment.is_empty() or not relationship.is_empty():
			return false
	for ship_id: StringName in _owned_ships:
		var owned: Dictionary = _session.call(&"get_owned_ship", ship_id)
		if int(owned.get("owner_peer_id", 0)) != 0:
			return false
	for entity_id: StringName in _moving_entities:
		var occupancy: Dictionary = _session.call(&"get_moving_interior_occupancy", entity_id)
		if not occupancy.is_empty():
			return false
	return true


func _finish_when_retired() -> void:
	_check_pending = false
	if _stopping or not _armed or not _ownership_is_retired():
		return
	_stopping = true
	set_process(false)
	var stopped: Dictionary = _main.call(&"shutdown_network_session", &"dedicated_guests_departed")
	var orderly: Dictionary = _main.call(&"mark_orderly_shutdown")
	var accepted: bool = bool(stopped.get("accepted", false)) and bool(orderly.get("accepted", false))
	if not accepted:
		print("DEDICATED_SERVER_FAILED: orderly shutdown refused")
	_request_process_exit(0 if accepted else 1)


func _on_session_stopped(_reason: StringName) -> void:
	if not _stopping:
		_fail("session stopped unexpectedly")


func _fail(reason: String) -> void:
	if _stopping:
		return
	_stopping = true
	set_process(false)
	print("DEDICATED_SERVER_FAILED: " + reason)
	if is_instance_valid(_main):
		if is_instance_valid(_session) and bool(_session.call(&"is_session_active")):
			_main.call(&"shutdown_network_session", &"dedicated_start_failed")
		_main.call(&"mark_orderly_shutdown")
	_request_process_exit(1)


## A source test may override process exit while observing this same lifecycle.
## Packaged Boot uses the implementation below and really exits the process.
func _request_process_exit(exit_code: int) -> void:
	stop_requested.emit(exit_code)
	get_tree().quit(exit_code)
