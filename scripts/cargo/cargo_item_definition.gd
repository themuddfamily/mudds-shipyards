class_name CargoItemDefinition
extends Resource

## Declarative identity and integer capacity cost for one cargo kind.
##
## Runtime quantities never live on this Resource. `CargoTransferAuthority`
## snapshots accepted definitions so later Resource edits cannot alter a live
## manifest's capacity accounting.

const MAX_ID_LENGTH := 64
const MAX_DISPLAY_NAME_LENGTH := 96
const MAX_UNIT_CAPACITY := 1_000_000

@export var item_id: StringName = &""
@export var display_name := ""
@export_range(1, MAX_UNIT_CAPACITY, 1) var unit_capacity := 1


func is_definition_valid() -> bool:
	return get_validation_errors().is_empty()


func get_validation_errors() -> PackedStringArray:
	var errors := PackedStringArray()
	if not is_stable_id(item_id):
		errors.append("item_id must be a stable lowercase identifier")
	if display_name.strip_edges().is_empty() or display_name.length() > MAX_DISPLAY_NAME_LENGTH:
		errors.append("display_name must contain 1..%d characters" % MAX_DISPLAY_NAME_LENGTH)
	if unit_capacity <= 0 or unit_capacity > MAX_UNIT_CAPACITY:
		errors.append("unit_capacity must be within 1..%d" % MAX_UNIT_CAPACITY)
	return errors


func to_dictionary() -> Dictionary:
	return {
		"item_id": item_id,
		"display_name": display_name,
		"unit_capacity": unit_capacity,
	}


static func is_stable_id(value: StringName) -> bool:
	var text := str(value)
	if text.is_empty() or text.length() > MAX_ID_LENGTH:
		return false
	for index in text.length():
		var code := text.unicode_at(index)
		var lowercase := code >= 97 and code <= 122
		var digit := code >= 48 and code <= 57
		if not lowercase and not digit and code != 95 and code != 45:
			return false
	return true
