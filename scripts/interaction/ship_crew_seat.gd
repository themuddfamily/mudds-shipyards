class_name ShipCrewSeat
extends Area3D

## Discovery and authored poses only. CrewSeatRoleAuthority owns the claim;
## GameFlow and Player own the physical transition into the existing chair.
var _ship: HalyardCrewTransport
var _anchor: Marker3D
var _entry_local := Transform3D.IDENTITY


static func install(anchor: Marker3D, ship: HalyardCrewTransport) -> ShipCrewSeat:
	var seat := ShipCrewSeat.new()
	seat.name = "SoloPassengerSeatInteraction"
	seat._ship = ship
	seat._anchor = anchor
	anchor.add_child(seat)
	seat.position = Vector3.UP * 1.2
	seat._entry_local = Transform3D(
		Basis(Vector3.UP, PI / 2.0),
		Vector3(0.0, 0.52, ship.to_local(anchor.global_position).z)
	)
	var collision := CollisionShape3D.new()
	collision.name = "InteractionShape"
	var shape := SphereShape3D.new()
	shape.radius = 0.55
	collision.shape = shape
	seat.add_child(collision)
	return seat


func _ready() -> void:
	monitoring = false
	collision_mask = PhysicsLayers.INTERACTABLE_AREA_MASK
	collision_layer = PhysicsLayers.INTERACTABLE_AREA_LAYER


func get_ship() -> HalyardCrewTransport:
	return _ship if is_instance_valid(_ship) else null


func get_seat_anchor() -> Marker3D:
	return _anchor if is_instance_valid(_anchor) else null


func get_entry_transform() -> Transform3D:
	return _ship.global_transform * _entry_local if is_instance_valid(_ship) else Transform3D.IDENTITY


func get_exit_transform() -> Transform3D:
	return get_entry_transform()


func get_interaction_prompt() -> String:
	if not is_instance_valid(_ship) or not _ship.is_boardable():
		return ""
	var authority := _ship.get_crew_role_authority()
	if authority != null:
		for assignment: Dictionary in authority.get_snapshot().get("assignments", []):
			if assignment.get("seat_id") == HalyardCrewTransport.LOADMASTER_STATION_SEAT_ID:
				return "[ E ] PASSENGER SEAT OCCUPIED"
	return "[ E ] SIT // HALYARD PASSENGER"


func get_seated_prompt() -> String:
	return "[ E ] STAND // HALYARD PASSENGER"


func interact(_actor: Node = null) -> bool:
	# Main intercepts this typed discovery component before generic interactions.
	return false
