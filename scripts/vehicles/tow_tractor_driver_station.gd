class_name TowTractorDriverStation
extends Area3D

## The tow tractor's driver step, expressed as an ordinary station interactable.
##
## This is deliberately *not* a [ShipBoardingArea]. That component resolves to a
## craft the fleet registry owns, and `GameFlow._find_station_interaction_candidate()`
## skips it by type precisely because boarding a spacecraft is a different code
## path with berth, lease and landing consequences. A tow tractor must acquire
## none of those, so it advertises the same `get_interaction_prompt()` /
## `interact()` pair the station's pressure doors use, and reaches the player
## through the identical prompt-and-press path — including the refresh
## `GameFlow` performs inside the interact handler itself (SANDBOX-001).

const INTERACTABLE_LAYER := PhysicsLayers.INTERACTABLE_AREA_LAYER

@export var vehicle_path := NodePath("..")

var _available := true


func _ready() -> void:
	collision_mask = PhysicsLayers.INTERACTABLE_AREA_MASK
	monitoring = false
	_apply_availability()


## Withdraws the step from physics discovery entirely while the seat cannot be
## taken, rather than leaving a discoverable interactable that answers with an
## empty prompt. An empty-prompt candidate would still win the coordinator's
## station-interaction selection and could therefore silently suppress a
## spacecraft boarding prompt for anyone standing between the two.
func set_available(value: bool) -> void:
	if _available == value:
		return
	_available = value
	_apply_availability()


func is_available() -> bool:
	return _available


func _apply_availability() -> void:
	collision_layer = INTERACTABLE_LAYER if _available else 0
	monitorable = _available
	for child in get_children():
		if child is CollisionShape3D:
			(child as CollisionShape3D).set_deferred(&"disabled", not _available)


## The vehicle this step belongs to, or null when it is not a live drivable one.
func get_vehicle() -> Node3D:
	if vehicle_path.is_empty():
		return null
	var candidate := get_node_or_null(vehicle_path) as Node3D
	if candidate == null or not candidate.has_method(&"request_boarding"):
		return null
	return candidate


func get_interaction_prompt() -> String:
	var vehicle := get_vehicle()
	if vehicle == null:
		return ""
	return str(vehicle.call(&"get_interaction_prompt"))


func can_interact(_actor: Node = null) -> bool:
	var vehicle := get_vehicle()
	return vehicle != null and bool(vehicle.call(&"is_boardable"))


## Returns true only when the request was actually accepted, so the coordinator's
## confirmation cue never fires for a seat that is occupied or recovering.
func interact(actor: Node = null) -> bool:
	var vehicle := get_vehicle()
	if vehicle == null:
		return false
	return bool(vehicle.call(&"request_boarding", actor))
