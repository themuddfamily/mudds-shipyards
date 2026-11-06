class_name TitanCargoCustody
extends Node

## Exact four-parcel composition. Quantities belong exclusively to the shared
## cargo authority; this adapter owns only admission and the durable pair slot.
signal custody_committed(context: Dictionary, generation: int)
const ITEM := &"titan_repair_kit_parcel"
const SLOT := "titan_parcel_custody"
const MARKER := "titan_parcels_initialized"
const SAFE_SLOT := "solo_safe_recovery"
const SAFE_CONTEXT := {"location": "mudds_home_berth", "mode": "on_foot", "craft_id": "titan_provisional", "berth_id": "titan_home_berth"}
var authority: CargoTransferAuthority
var store: UserDataStore
var ship: HeroShip
var locker: Node3D
var locker_handle: Dictionary = {}
var ship_handle: Dictionary = {}
var authorize_actor: Callable
var _available := false
var _initialization_attempted := false
var _endpoint_generation := 0
var _request_serial := 0
var _last_pair: Dictionary = {}
var _committing := false
var status := "Cargo custody unavailable"

func initialize(owner: CargoTransferAuthority, persistence: UserDataStore, craft: HeroShip, supply: Node3D, admission: Callable) -> Dictionary:
	if not is_inside_tree() or is_queued_for_deletion():
		return {"accepted": false, "reason": &"custody_unavailable"}
	if _initialization_attempted:
		return {"accepted": false, "reason": &"already_initialized"}
	_initialization_attempted = true
	authority = owner
	store = persistence
	ship = craft
	locker = supply
	authorize_actor = admission
	var loaded := _read_pair(true)
	if not bool(loaded.get("accepted", false)):
		return _refuse(StringName(loaded.get("reason", &"custody_unavailable")))
	# Cold replacement returns existing committed total, never adds authored
	# stock to a live manifest. New authority handles retire with the old Main.
	var committed := _commit_pair(4, 0)
	if not bool(committed.get("accepted", false)):
		return committed
	var item := CargoItemDefinition.new()
	item.item_id = ITEM
	item.display_name = "Sealed repair kit"
	item.unit_capacity = 1
	var registered := authority.register_item(item)
	if not bool(registered.get("accepted", false)):
		return _refuse(&"item_registration_failed")
	var first := authority.register_entity(locker, &"titan_supply_locker", &"titan_supply_manifest", 4, {ITEM: 4})
	if not bool(first.get("accepted", false)):
		return _refuse(&"locker_registration_failed")
	locker_handle = first.handle
	var second := authority.register_entity(ship, &"titan_provisional", &"titan_cargo_manifest", 4)
	if not bool(second.get("accepted", false)):
		authority.retire_entity(locker_handle)
		return _refuse(&"ship_registration_failed")
	ship_handle = second.handle
	_endpoint_generation = store.get_generation()
	_available = true
	status = "Parcels ready"
	custody_committed.emit(SAFE_CONTEXT.duplicate(true), store.get_generation())
	return {"accepted": true, "reason": &"ready"}

func is_available() -> bool:
	if not is_inside_tree() or is_queued_for_deletion() or not _available or not is_instance_valid(authority) or not authority.is_inside_tree() \
			or authority.is_queued_for_deletion() or not is_instance_valid(ship) or ship.is_destroyed():
		return false
	var first := authority.get_manifest_snapshot(locker_handle)
	var second := authority.get_manifest_snapshot(ship_handle)
	return bool(first.get("attached", false)) and bool(second.get("attached", false)) \
		and authority.get_quantity(locker_handle, ITEM) + authority.get_quantity(ship_handle, ITEM) == 4

func restore_live_binding() -> void:
	if not _available:
		return
	var restored := authority.reattach_entity_pair(locker, locker_handle, ship, ship_handle)
	if not bool(restored.get("accepted", false)):
		_refuse(&"custody_unavailable")

func snapshot() -> Dictionary:
	return {"available": is_available(), "locker": authority.get_quantity(locker_handle, ITEM) if is_instance_valid(authority) else -1,
		"titan": authority.get_quantity(ship_handle, ITEM) if is_instance_valid(authority) else -1, "status": status,
		"locker_handle": _endpoint_handle(locker_handle), "ship_handle": _endpoint_handle(ship_handle)}

func request_transfer(actor: Node, panel: Node3D, loading: bool, quantity: Variant = 1, transfer_id: StringName = &"", source: Dictionary = {}, destination: Dictionary = {}) -> Dictionary:
	if not is_inside_tree() or is_queued_for_deletion():
		return _reject(&"custody_unavailable")
	if _committing:
		return {"accepted": false, "reason": &"transfer_busy"}
	if not is_available() and not retry_custody():
		return _refuse(&"custody_unavailable")
	if not quantity is int or int(quantity) < 1 or int(quantity) > 4:
		return _reject(&"invalid_quantity")
	var expected_source := locker_handle if loading else ship_handle
	var expected_destination := ship_handle if loading else locker_handle
	if (not source.is_empty() and source != _endpoint_handle(expected_source)) or (not destination.is_empty() and destination != _endpoint_handle(expected_destination)):
		return _reject(&"stale_or_wrong_endpoint")
	var admission: Dictionary = authorize_actor.call(actor, panel, loading) if authorize_actor.is_valid() else {}
	if not bool(admission.get("accepted", false)):
		return _reject(StringName(admission.get("reason", &"actor_unavailable")))
	_request_serial += 1
	if transfer_id.is_empty():
		transfer_id = StringName("titan_parcel_%d_%d" % [get_instance_id(), _request_serial])
	_committing = true
	var result := authority.transfer(transfer_id, expected_source, expected_destination, ITEM, int(quantity), _persist_proposal.bind(loading))
	_committing = false
	if not bool(result.get("accepted", false)):
		if result.get("reason") == &"precommit_custody_unavailable":
			return _refuse(&"custody_unavailable")
		return _reject(StringName(result.get("reason", &"transfer_refused")))
	custody_committed.emit(SAFE_CONTEXT.duplicate(true), store.get_generation())
	status = "Saved: locker %d / Titan %d" % [authority.get_quantity(locker_handle, ITEM), authority.get_quantity(ship_handle, ITEM)]
	return result

func _persist_proposal(proposal: Dictionary, loading: bool) -> Dictionary:
	var loaded := _read_pair(false)
	if not bool(loaded.get("accepted", false)):
		return _refuse(StringName(loaded.get("reason", &"custody_unavailable")))
	var current := {"locker": authority.get_quantity(locker_handle, ITEM), "titan": authority.get_quantity(ship_handle, ITEM)}
	if loaded.pair != current or current != _last_pair:
		return _refuse(&"committed_pair_changed")
	return _commit_pair(int(proposal.source_quantity_after) if loading else int(proposal.destination_quantity_after),
		int(proposal.destination_quantity_after) if loading else int(proposal.source_quantity_after))

func _read_pair(first_use: bool) -> Dictionary:
	if store == null:
		return {"accepted": false, "reason": &"store_unavailable"}
	var loaded := store.load_read_only()
	if not bool(loaded.get("accepted", false)) or store.get_loaded_source() not in [&"primary", &"empty"]:
		return {"accepted": false, "reason": &"store_recovery_required"}
	var payload := store.get_snapshot()
	if not payload.has(MARKER) and not payload.has(SLOT) and first_use:
		return {"accepted": true, "pair": {"locker": 4, "titan": 0}}
	if payload.get(MARKER) != true or not payload.get(SLOT) is Dictionary:
		return {"accepted": false, "reason": &"initialized_custody_missing"}
	var pair := payload[SLOT] as Dictionary
	if pair.size() != 2 or not _whole(pair.get("locker")) or not _whole(pair.get("titan")) \
			or int(pair.locker) < 0 or int(pair.titan) < 0 or int(pair.locker) + int(pair.titan) != 4:
		return {"accepted": false, "reason": &"invalid_committed_custody"}
	return {"accepted": true, "pair": {"locker": int(pair.locker), "titan": int(pair.titan)}}

func _commit_pair(locker_quantity: int, titan_quantity: int) -> Dictionary:
	var payload := store.get_snapshot()
	payload[MARKER] = true
	payload[SLOT] = {"locker": locker_quantity, "titan": titan_quantity}
	payload[SAFE_SLOT] = SAFE_CONTEXT.duplicate(true)
	var generation := store.get_generation()
	var result := store.commit(payload, generation, "titan-parcels-%d" % (generation + 1))
	if bool(result.get("accepted", false)):
		_last_pair = payload[SLOT].duplicate(true)
	else:
		_available = false
		status = "Cargo save refused: %s. Retry after recovery." % str(result.get("reason", "write failed"))
	return result

func _whole(value: Variant) -> bool:
	return value is int or (value is float and is_finite(value) and value == floor(value))

func _reject(reason: StringName) -> Dictionary:
	status = "Parcel transfer refused: " + String(reason).replace("_", " ")
	return {"accepted": false, "reason": reason}

func _refuse(reason: StringName) -> Dictionary:
	_available = false
	status = "Cargo custody unavailable: " + String(reason).replace("_", " ") + ". Launch blocked."
	return {"accepted": false, "reason": reason}


## Retrying a repaired store may unlock only the unchanged last committed pair.
## An interrupted document or different durable pair remains fail-closed.
func retry_custody() -> bool:
	if not is_instance_valid(authority) or locker_handle.is_empty() or ship_handle.is_empty():
		return false
	var read := _read_pair(false)
	var live := {"locker": authority.get_quantity(locker_handle, ITEM), "titan": authority.get_quantity(ship_handle, ITEM)}
	if not bool(read.get("accepted", false)) or read.pair != live or live != _last_pair:
		return false
	_available = true
	return is_available()

func can_launch() -> bool:
	if not is_available():
		return false
	var read := _read_pair(false)
	var live := {"locker": authority.get_quantity(locker_handle, ITEM), "titan": authority.get_quantity(ship_handle, ITEM)}
	if not bool(read.get("accepted", false)) or read.pair != live or live != _last_pair:
		_refuse(&"store_recovery_required")
		return false
	return true


## Service endpoints carry composition identity outside the shared authority's
## generation schema. A stale endpoint from a replaced Main cannot alias a new
## authority whose local generation counters independently begin at one.
func _endpoint_handle(handle: Dictionary) -> Dictionary:
	var endpoint := handle.duplicate(true)
	endpoint["titan_custody_instance"] = get_instance_id()
	endpoint["titan_custody_generation"] = _endpoint_generation
	return endpoint
