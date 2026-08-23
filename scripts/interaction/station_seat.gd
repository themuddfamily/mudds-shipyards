class_name StationSeat
extends Area3D

## Reusable interaction and occupancy contract for fixed station furniture.
##
## The gameplay coordinator owns the player's animated handoff; this component
## owns only the physical discovery point, the authored sitting/standing poses,
## and one local occupant reservation.

const INTERACTABLE_LAYER := PhysicsLayers.INTERACTABLE_AREA_LAYER
const DEFAULT_REACH := 0.55

var _seat_anchor: Marker3D
var _entry_anchor: Marker3D
var _exit_anchor: Marker3D
var _occupant: Node
var _transitioning := false
var _enabled := true


static func install(
		seat_root: Node3D,
		seat_root_height: float,
		facing_yaw_degrees: float,
		exit_distance: float = 1.15,
		exit_height: float = 0.0,
		label: String = "SEAT"
	) -> StationSeat:
	var station_seat := StationSeat.new()
	station_seat.name = "StationSeatInteraction"
	station_seat.set_meta("seat_label", label.strip_edges().to_upper())
	seat_root.add_child(station_seat)
	station_seat._build_contract(
		seat_root_height,
		facing_yaw_degrees,
		exit_distance,
		exit_height
	)
	return station_seat


func _ready() -> void:
	monitoring = false
	collision_mask = PhysicsLayers.INTERACTABLE_AREA_MASK
	_apply_availability()


func _build_contract(
		seat_root_height: float,
		facing_yaw_degrees: float,
		exit_distance: float,
		exit_height: float
	) -> void:
	rotation_degrees.y = facing_yaw_degrees

	_seat_anchor = Marker3D.new()
	_seat_anchor.name = "SeatAnchor"
	_seat_anchor.position.y = seat_root_height
	add_child(_seat_anchor)

	_exit_anchor = Marker3D.new()
	_exit_anchor.name = "ExitAnchor"
	_exit_anchor.position = Vector3(0.0, exit_height, -absf(exit_distance))
	add_child(_exit_anchor)
	_entry_anchor = Marker3D.new()
	_entry_anchor.name = "EntryAnchor"
	_entry_anchor.position = _exit_anchor.position
	_entry_anchor.rotation.y = PI
	add_child(_entry_anchor)

	var shape := SphereShape3D.new()
	shape.radius = DEFAULT_REACH
	var collision_shape := CollisionShape3D.new()
	collision_shape.name = "InteractionShape"
	collision_shape.position = _exit_anchor.position + Vector3.UP * 0.9
	collision_shape.shape = shape
	add_child(collision_shape)


func get_interaction_prompt() -> String:
	if not is_available():
		return ""
	var label := str(get_meta("seat_label", "SEAT"))
	return "[ E ]  SIT  //  %s" % label


func get_seated_prompt() -> String:
	return "[ E ]  STAND"


func get_seat_anchor() -> Marker3D:
	return _seat_anchor


func get_entry_transform() -> Transform3D:
	return _entry_anchor.global_transform if is_instance_valid(_entry_anchor) else global_transform


func get_exit_transform() -> Transform3D:
	return get_entry_transform()


func is_available() -> bool:
	return (
		_enabled
		and is_inside_tree()
		and not is_queued_for_deletion()
		and not _transitioning
		and not is_instance_valid(_occupant)
	)


func set_enabled(enabled: bool) -> void:
	_enabled = enabled
	_apply_availability()


func is_enabled() -> bool:
	return _enabled


func is_reserved_for(actor: Node) -> bool:
	return is_instance_valid(actor) and _occupant == actor


func try_reserve(actor: Node) -> bool:
	if not is_instance_valid(actor) or not is_available():
		return false
	_occupant = actor
	_transitioning = true
	_apply_availability()
	return true


func finish_transition(actor: Node) -> bool:
	if not is_reserved_for(actor):
		return false
	_transitioning = false
	_apply_availability()
	return true


func begin_release(actor: Node) -> bool:
	if not is_reserved_for(actor) or _transitioning:
		return false
	_transitioning = true
	return true


func release(actor: Node) -> bool:
	if not is_reserved_for(actor):
		return false
	_occupant = null
	_transitioning = false
	_apply_availability()
	return true


func cancel_reservation(actor: Node) -> void:
	if is_reserved_for(actor):
		release(actor)


## GameFlow intercepts this typed component before invoking generic station
## interactions. Keeping the method makes the component honour the shared
## prompt/interact surface without allowing an uncoordinated teleport.
func interact(_actor: Node = null) -> bool:
	return false


func _apply_availability() -> void:
	var available := _enabled and not _transitioning and not is_instance_valid(_occupant)
	collision_layer = INTERACTABLE_LAYER if available else 0
	monitorable = available
	for child in get_children():
		if child is CollisionShape3D:
			(child as CollisionShape3D).set_deferred(&"disabled", not available)
