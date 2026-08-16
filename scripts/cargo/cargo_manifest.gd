class_name CargoManifest
extends RefCounted

## Authority-owned integer inventory state.
##
## Callers never receive this object from `CargoTransferAuthority`; every public
## boundary returns a detached primitive snapshot instead.

const MAX_QUANTITY := 1_000_000
const MAX_CAPACITY := 1_000_000

var manifest_id: StringName
var generation: int
var owner_entity_id: StringName
var owner_generation: int
var capacity: int
var _quantities: Dictionary = {}


func _init(
	p_manifest_id: StringName,
	p_generation: int,
	p_owner_entity_id: StringName,
	p_owner_generation: int,
	p_capacity: int,
	p_quantities: Dictionary
	) -> void:
	manifest_id = p_manifest_id
	generation = p_generation
	owner_entity_id = p_owner_entity_id
	owner_generation = p_owner_generation
	capacity = p_capacity
	_quantities = p_quantities.duplicate(true)


func get_quantity(item_id: StringName) -> int:
	return int(_quantities.get(item_id, 0))


func get_used_capacity(unit_capacities: Dictionary) -> int:
	var total := 0
	for item_id: StringName in _quantities:
		total += get_quantity(item_id) * int(unit_capacities.get(item_id, 0))
	return total


func can_remove(item_id: StringName, quantity: int) -> bool:
	return quantity > 0 and get_quantity(item_id) >= quantity


func can_add(item_id: StringName, quantity: int, unit_capacity: int, unit_capacities: Dictionary) -> StringName:
	if quantity <= 0:
		return &"invalid_quantity"
	if quantity > MAX_QUANTITY:
		return &"quantity_overflow"
	var current := get_quantity(item_id)
	if current > MAX_QUANTITY - quantity:
		return &"quantity_overflow"
	var remaining_capacity := capacity - get_used_capacity(unit_capacities)
	if unit_capacity <= 0 or quantity > remaining_capacity / unit_capacity:
		return &"capacity_exceeded"
	return &""


func commit_remove(item_id: StringName, quantity: int) -> bool:
	if not can_remove(item_id, quantity):
		return false
	var remaining := get_quantity(item_id) - quantity
	if remaining == 0:
		_quantities.erase(item_id)
	else:
		_quantities[item_id] = remaining
	return true


func commit_add(item_id: StringName, quantity: int) -> bool:
	if quantity <= 0 or quantity > MAX_QUANTITY:
		return false
	var current := get_quantity(item_id)
	if current > MAX_QUANTITY - quantity:
		return false
	_quantities[item_id] = current + quantity
	return true


func get_snapshot(unit_capacities: Dictionary, attached: bool) -> Dictionary:
	var entries: Array[Dictionary] = []
	var item_ids: Array[String] = []
	for item_id: StringName in _quantities:
		item_ids.append(str(item_id))
	item_ids.sort()
	for item_text in item_ids:
		var item_id := StringName(item_text)
		entries.append({"item_id": item_id, "quantity": get_quantity(item_id)})
	return {
		"manifest_id": manifest_id,
		"generation": generation,
		"owner_entity_id": owner_entity_id,
		"owner_generation": owner_generation,
		"capacity": capacity,
		"used_capacity": get_used_capacity(unit_capacities),
		"remaining_capacity": capacity - get_used_capacity(unit_capacities),
		"attached": attached,
		"entries": entries,
	}


func get_validation_errors(unit_capacities: Dictionary) -> PackedStringArray:
	var errors := PackedStringArray()
	if not CargoItemDefinition.is_stable_id(manifest_id):
		errors.append("invalid manifest_id")
	if generation <= 0:
		errors.append("invalid manifest generation")
	if not CargoItemDefinition.is_stable_id(owner_entity_id):
		errors.append("invalid owner_entity_id")
	if owner_generation <= 0:
		errors.append("invalid owner generation")
	if capacity <= 0 or capacity > MAX_CAPACITY:
		errors.append("invalid capacity")
	var used := 0
	for raw_item_id: Variant in _quantities:
		var item_id := StringName(raw_item_id)
		var quantity := get_quantity(item_id)
		var unit_capacity := int(unit_capacities.get(item_id, 0))
		if not CargoItemDefinition.is_stable_id(item_id) or unit_capacity <= 0:
			errors.append("unknown or invalid item %s" % item_id)
		elif quantity <= 0 or quantity > MAX_QUANTITY:
			errors.append("invalid quantity for %s" % item_id)
		elif quantity > capacity / unit_capacity:
			errors.append("capacity multiplication overflow for %s" % item_id)
		else:
			used += quantity * unit_capacity
	if used > capacity:
		errors.append("manifest exceeds capacity")
	return errors
