class_name CargoDeliveryContract
extends RefCounted

## Snapshot-owning typed definition for one authority-backed cargo delivery.
##
## The contract snapshots generation-bearing CargoTransferAuthority handles. It
## owns no manifest quantities and exposes only detached primitive snapshots.

const MAX_ORDERED_PHASES := 16
const MAX_CONTRACT_ID_LENGTH := 46

var _contract_id: StringName
var _source_handle: Dictionary
var _destination_handle: Dictionary
var _item_id: StringName
var _quantity: int
var _ordered_phases: Array[StringName]
var _deadline_seconds: float


func _init(
	p_contract_id: StringName,
	p_source_handle: Dictionary,
	p_destination_handle: Dictionary,
	p_item_id: StringName,
	p_quantity: int,
	p_ordered_phases: Array[StringName] = [],
	p_deadline_seconds: float = 120.0
	) -> void:
	_contract_id = p_contract_id
	_source_handle = _canonical_handle(p_source_handle)
	_destination_handle = _canonical_handle(p_destination_handle)
	_item_id = p_item_id
	_quantity = p_quantity
	_ordered_phases = p_ordered_phases.duplicate()
	_deadline_seconds = p_deadline_seconds


func is_configuration_valid() -> bool:
	return get_configuration_errors().is_empty()


func get_configuration_errors() -> PackedStringArray:
	var errors := PackedStringArray()
	if (
		not CargoItemDefinition.is_stable_id(_contract_id)
		or str(_contract_id).length() > MAX_CONTRACT_ID_LENGTH
	):
		errors.append("contract_id must be a stable identifier of at most %d characters" % MAX_CONTRACT_ID_LENGTH)
	_append_handle_errors(errors, _source_handle, "source")
	_append_handle_errors(errors, _destination_handle, "destination")
	if _handles_equal(_source_handle, _destination_handle):
		errors.append("source and destination handles must be different")
	if not CargoItemDefinition.is_stable_id(_item_id):
		errors.append("item_id must be a stable identifier")
	if _quantity <= 0 or _quantity > CargoManifest.MAX_QUANTITY:
		errors.append("quantity must be within the cargo authority integer bound")
	if _ordered_phases.size() > MAX_ORDERED_PHASES:
		errors.append("ordered phase count exceeds %d" % MAX_ORDERED_PHASES)
	var seen_phases: Dictionary = {}
	for phase_id: StringName in _ordered_phases:
		if not CargoItemDefinition.is_stable_id(phase_id):
			errors.append("ordered phase IDs must be stable identifiers")
		elif seen_phases.has(phase_id):
			errors.append("ordered phase IDs must be unique")
		else:
			seen_phases[phase_id] = true
	if not is_finite(_deadline_seconds) or _deadline_seconds <= 0.0:
		errors.append("deadline_seconds must be finite and greater than zero")
	errors.sort()
	return errors


func get_contract_id() -> StringName:
	return _contract_id


func get_source_handle() -> Dictionary:
	return _source_handle.duplicate(true)


func get_destination_handle() -> Dictionary:
	return _destination_handle.duplicate(true)


func get_item_id() -> StringName:
	return _item_id


func get_quantity() -> int:
	return _quantity


func get_ordered_phases() -> Array[StringName]:
	return _ordered_phases.duplicate()


func get_deadline_seconds() -> float:
	return _deadline_seconds


func get_transfer_id(generation: int) -> StringName:
	if generation <= 0 or generation > CargoTransferAuthority.MAX_SAFE_INTEGER:
		return &""
	var transfer_id := StringName("%s_g%d" % [_contract_id, generation])
	return transfer_id if CargoItemDefinition.is_stable_id(transfer_id) else &""


func get_snapshot() -> Dictionary:
	return {
		"contract_id": _contract_id,
		"source_handle": _source_handle.duplicate(true),
		"destination_handle": _destination_handle.duplicate(true),
		"item_id": _item_id,
		"quantity": _quantity,
		"ordered_phases": _ordered_phases.duplicate(),
		"deadline_seconds": _deadline_seconds,
	}


func audit() -> Dictionary:
	var errors := get_configuration_errors()
	var report := get_snapshot()
	report["valid"] = errors.is_empty()
	report["errors"] = errors
	report["owns_inventory"] = false
	report["uses_cargo_transfer_authority"] = true
	report["reward_authority"] = false
	report["ship_authority"] = false
	report["berth_authority"] = false
	report["combat_authority"] = false
	report["network_authority"] = false
	return report.duplicate(true)


static func _canonical_handle(handle: Dictionary) -> Dictionary:
	var result: Dictionary = {}
	for field: StringName in [&"entity_id", &"entity_generation", &"manifest_id", &"manifest_generation"]:
		if handle.has(field):
			result[field] = handle[field]
	return result


static func _append_handle_errors(errors: PackedStringArray, handle: Dictionary, label: String) -> void:
	for field: StringName in [&"entity_id", &"entity_generation", &"manifest_id", &"manifest_generation"]:
		if not handle.has(field):
			errors.append("%s handle is missing %s" % [label, field])
			return
	if (
		(not handle.entity_id is String and not handle.entity_id is StringName)
		or (not handle.manifest_id is String and not handle.manifest_id is StringName)
		or not CargoItemDefinition.is_stable_id(StringName(handle.entity_id))
		or not CargoItemDefinition.is_stable_id(StringName(handle.manifest_id))
	):
		errors.append("%s handle has an invalid stable identity" % label)
	if (
		not handle.entity_generation is int
		or int(handle.entity_generation) <= 0
		or int(handle.entity_generation) > CargoTransferAuthority.MAX_SAFE_INTEGER
		or not handle.manifest_generation is int
		or int(handle.manifest_generation) <= 0
		or int(handle.manifest_generation) > CargoTransferAuthority.MAX_SAFE_INTEGER
	):
		errors.append("%s handle has an invalid generation" % label)


static func _handles_equal(left: Dictionary, right: Dictionary) -> bool:
	return (
		left.size() == 4
		and right.size() == 4
		and StringName(left.get("entity_id", &"")) == StringName(right.get("entity_id", &""))
		and int(left.get("entity_generation", 0)) == int(right.get("entity_generation", 0))
		and StringName(left.get("manifest_id", &"")) == StringName(right.get("manifest_id", &""))
		and int(left.get("manifest_generation", 0)) == int(right.get("manifest_generation", 0))
	)
