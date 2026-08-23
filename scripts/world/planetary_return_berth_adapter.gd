class_name PlanetaryReturnBerthAdapter
extends RefCounted

## Caller-routed Mudds return berth handoff. ShipBerth remains the lease and
## occupancy authority; this adapter only validates the receipt and delegates.

const DESTINATION_ID: StringName = &"mudds_shipyards"
var _state: StringName = &"ready"
var _berth: ShipBerth
var _ship: Node
var _definition: ShipDefinition
var _token: StringName = &""
var _actor_instance_id := 0
var _craft_instance_id := 0
var _session_generation := 0

func request(
		arrival_receipt: Variant,
		berth: ShipBerth,
		ship: Node,
		definition: ShipDefinition,
		actor_instance_id: int,
		craft_instance_id: int,
		session_generation: int
	) -> Dictionary:
	if _state != &"ready" or not arrival_receipt is Dictionary \
			or berth == null or ship == null or definition == null \
			or actor_instance_id < 1 or craft_instance_id < 1 \
			or session_generation < 1:
		return _reject(&"invalid_return_berth_request")
	var receipt := arrival_receipt as Dictionary
	if not bool(receipt.get("accepted", false)) \
			or StringName(receipt.get("return_target_id", &"")) != DESTINATION_ID:
		return _reject(&"return_arrival_receipt_invalid")
	if not berth.is_inside_tree() or not ship.is_inside_tree() \
			or not berth.can_accept(definition, ship):
		return _reject(&"return_berth_unavailable")
	var token := berth.try_reserve(ship, definition)
	if token.is_empty():
		return _reject(&"return_berth_reservation_rejected")
	_berth = berth
	_ship = ship
	_definition = definition
	_token = token
	_actor_instance_id = actor_instance_id
	_craft_instance_id = craft_instance_id
	_session_generation = session_generation
	_state = &"reserved"
	return {"accepted": true, "reason": &"return_berth_reserved", "berth_id": berth.get_berth_id(), "token": token, "actor_instance_id": actor_instance_id, "craft_instance_id": craft_instance_id, "session_generation": session_generation}.duplicate(true)

func confirm_occupied(landing_evidence: Variant) -> Dictionary:
	if _state != &"reserved" or _berth == null or _ship == null:
		return _reject(&"return_berth_reservation_required")
	if not landing_evidence is Dictionary:
		return _reject(&"landing_evidence_required")
	var evidence := landing_evidence as Dictionary
	if not bool(evidence.get("accepted", false)) or not bool(evidence.get("strict_dock_acceptance", false)):
		return _reject(&"landing_evidence_rejected")
	if not _berth.has_valid_lease(_ship, _token, _definition.ship_id):
		return _reject(&"return_berth_lease_lost")
	if not _berth.occupy(_ship, _token):
		return _reject(&"return_berth_occupancy_rejected")
	_state = &"occupied"
	return {"accepted": true, "reason": &"return_berth_occupied", "berth_id": _berth.get_berth_id(), "actor_instance_id": _actor_instance_id, "craft_instance_id": _craft_instance_id, "session_generation": _session_generation}.duplicate(true)

func reset() -> Dictionary:
	if _berth != null and _ship != null and not _token.is_empty():
		_berth.release(_ship, _token)
	_state = &"ready"
	_token = &""
	return {"accepted": true, "reason": &"return_berth_reset"}

func get_snapshot() -> Dictionary:
	return {"state": _state, "berth_id": _berth.get_berth_id() if _berth != null else &"", "token": _token, "actor_instance_id": _actor_instance_id, "craft_instance_id": _craft_instance_id, "session_generation": _session_generation, "authority": {"movement": false, "teleport": false, "game_flow": false, "reward": false}}.duplicate(true)

func _reject(reason: StringName) -> Dictionary:
	return {"accepted": false, "reason": reason}
