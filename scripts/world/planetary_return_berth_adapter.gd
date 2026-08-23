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
var _attachment_generation := 0
var _occupied_receipt: Dictionary = {}
var _contract_completed := false

func request(
		arrival_receipt: Variant,
		berth: ShipBerth,
		ship: Node,
		definition: ShipDefinition,
		actor_instance_id: int,
		craft_instance_id: int,
		session_generation: int,
		attachment_generation: int = 1
	) -> Dictionary:
	if _state != &"ready" or not arrival_receipt is Dictionary \
			or berth == null or ship == null or definition == null \
			or actor_instance_id < 1 or craft_instance_id < 1 \
			or session_generation < 1 or attachment_generation < 1:
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
	_attachment_generation = attachment_generation
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
	_occupied_receipt = {"accepted": true, "reason": &"return_berth_occupied", "berth_id": _berth.get_berth_id(), "token": _token, "actor_instance_id": _actor_instance_id, "craft_instance_id": _craft_instance_id, "session_generation": _session_generation, "attachment_generation": _attachment_generation}.duplicate(true)
	return _occupied_receipt.duplicate(true)

func complete_return_contract(
		occupied_receipt: Variant, landing_return_contract: Object,
		observation: Dictionary
	) -> Dictionary:
	if _state != &"occupied" or _contract_completed:
		return _reject(&"return_contract_completion_unavailable")
	if not occupied_receipt is Dictionary or landing_return_contract == null \
			or not landing_return_contract.has_method(&"confirm_orbit_return"):
		return _reject(&"invalid_return_contract_completion")
	var receipt := occupied_receipt as Dictionary
	if not bool(receipt.get("accepted", false)) \
			or StringName(receipt.get("berth_id", &"")) != _berth.get_berth_id() \
			or StringName(receipt.get("token", &"")) != _token \
			or int(receipt.get("actor_instance_id", 0)) != _actor_instance_id \
			or int(receipt.get("craft_instance_id", 0)) != _craft_instance_id \
			or int(receipt.get("session_generation", 0)) != _session_generation \
			or int(receipt.get("attachment_generation", 0)) != _attachment_generation:
		return _reject(&"foreign_or_stale_berth_receipt")
	var result: Dictionary = landing_return_contract.call(
		&"confirm_orbit_return", true, DESTINATION_ID, observation,
		_session_generation, _attachment_generation
	)
	if not bool(result.get("accepted", false)):
		return result
	_contract_completed = true
	return {"accepted": true, "reason": &"returned_to_station", "berth_receipt": _occupied_receipt.duplicate(true), "contract_receipt": result.duplicate(true)}

func reset() -> Dictionary:
	if _berth != null and _ship != null and not _token.is_empty():
		_berth.release(_ship, _token)
	_state = &"ready"
	_token = &""
	_occupied_receipt.clear()
	_contract_completed = false
	return {"accepted": true, "reason": &"return_berth_reset"}

func get_snapshot() -> Dictionary:
	return {"state": _state, "berth_id": _berth.get_berth_id() if _berth != null else &"", "token": _token, "actor_instance_id": _actor_instance_id, "craft_instance_id": _craft_instance_id, "session_generation": _session_generation, "attachment_generation": _attachment_generation, "contract_completed": _contract_completed, "authority": {"movement": false, "teleport": false, "game_flow": false, "reward": false}}.duplicate(true)

func _reject(reason: StringName) -> Dictionary:
	return {"accepted": false, "reason": reason}
