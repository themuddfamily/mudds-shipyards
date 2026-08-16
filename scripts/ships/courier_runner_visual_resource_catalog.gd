extends RefCounted

## Process-owned immutable Material identities for CourierRunner presentation.
## This standalone holder avoids coupling catalog lifetime to the opponent's
## scripted inheritance chain; consumers always receive a shallow map copy.

static var _materials: Dictionary = {}
static var _build_count := 0


static func get_catalog() -> Dictionary:
	return _materials.duplicate(false)


static func publish_catalog(materials: Dictionary) -> Dictionary:
	if _materials.is_empty():
		_materials = materials.duplicate(false)
		_build_count += 1
	return get_catalog()


static func get_material(key: Variant) -> StandardMaterial3D:
	return _materials.get(key) as StandardMaterial3D


static func get_entry_count() -> int:
	return _materials.size()


static func get_build_count() -> int:
	return _build_count
