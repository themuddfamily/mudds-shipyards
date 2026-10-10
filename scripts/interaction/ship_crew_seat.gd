class_name ShipCrewSeat
extends Area3D

## Discovery and authored poses only. CrewSeatRoleAuthority owns the claim;
## GameFlow and Player own the physical transition into the existing chair.
var _ship: HeroShip
var _anchor: Marker3D
var _seat_id: StringName
var _role: StringName


static func install(anchor: Marker3D, ship: HeroShip) -> ShipCrewSeat:
	var seat := ShipCrewSeat.new()
	seat._ship = ship
	seat._anchor = anchor
	var contract := _contract_for_ship(ship)
	if contract.get("seat") != anchor or contract.get("vessel_id") != ship.get_ship_id() \
			or StringName(contract.get("seat_id", &"")).is_empty() or contract.get("role") not in [&"passenger", &"gunner", &"engineer"]:
		seat.free()
		return null
	seat._seat_id = contract.seat_id
	seat._role = contract.role
	seat.name = "Solo%sSeatInteraction" % String(seat._role).capitalize()
	anchor.add_child(seat)
	seat.position = Vector3.UP * 1.2
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


func get_role_contract() -> Dictionary:
	if not is_inside_tree() or is_queued_for_deletion() \
			or not is_instance_valid(_ship) or not _ship.is_inside_tree() or _ship.is_queued_for_deletion() \
			or not is_instance_valid(_anchor) or not _anchor.is_inside_tree() \
			or _anchor.is_queued_for_deletion() or not _ship.is_ancestor_of(_anchor):
		return {}
	var contract := _contract_for_ship(_ship)
	var frame := contract.get("frame") as MovingInteriorFrame
	var entry: Variant = contract.get("entry_transform")
	var exit_pose: Variant = contract.get("exit_transform")
	if contract.get("vessel_id") != _ship.get_ship_id() or contract.get("seat") != _anchor \
			or StringName(contract.get("seat_id", &"")).is_empty() \
			or contract.get("role") not in [&"passenger", &"gunner", &"engineer"] \
			or (_seat_id != &"" and contract.get("seat_id") != _seat_id) \
			or (_role != &"" and contract.get("role") != _role) \
			or not is_instance_valid(frame) or not frame.is_inside_tree() or frame.is_queued_for_deletion() \
			or frame.get_moving_frame() != _ship or not _ship.is_ancestor_of(frame) \
			or not entry is Transform3D or not exit_pose is Transform3D:
		return {}
	var bounds := (_ship.get_in_flight_cabin_report().get("local_bounds", AABB()) as AABB)
	for pose: Transform3D in [entry, exit_pose]:
		if not pose.origin.is_finite() or not pose.basis.is_finite() \
				or not bounds.has_point(_ship.to_local(pose.origin)):
			return {}
	return contract


func get_ship() -> HeroShip:
	return _ship if is_instance_valid(_ship) else null


func get_seat_id() -> StringName:
	return _seat_id


func get_role() -> StringName:
	return _role


func get_seat_anchor() -> Marker3D:
	return _anchor if is_instance_valid(_anchor) else null


func get_entry_transform() -> Transform3D:
	return get_role_contract().get("entry_transform", Transform3D.IDENTITY)


func get_exit_transform() -> Transform3D:
	return get_role_contract().get("exit_transform", Transform3D.IDENTITY)


func get_interaction_prompt() -> String:
	if get_role_contract().is_empty() or not _ship.is_boardable():
		return ""
	var authority: CrewSeatRoleAuthority = _ship.call(&"get_crew_role_authority")
	if authority != null:
		for assignment: Dictionary in authority.get_snapshot().get("assignments", []):
			if assignment.get("seat_id") == _seat_id:
				return "[ E ] %s SEAT OCCUPIED" % get_role_label().to_upper()
	return "[ E ] SIT // %s %s" % [_ship.get_display_name().to_upper(), get_role_label().to_upper()]


func get_role_label() -> String:
	return str(get_role_contract().get("role_label", String(_role)))


func get_seated_prompt() -> String:
	return "[ E ] STAND // %s %s" % [_ship.get_display_name().to_upper(), get_role_label().to_upper()]


func interact(_actor: Node = null) -> bool:
	# Main intercepts this typed discovery component before generic interactions.
	return false


static func _contract_for_ship(ship: HeroShip) -> Dictionary:
	for method: StringName in [&"get_passenger_station_role_contract", &"get_gunner_station_role_contract", &"get_engineer_station_role_contract"]:
		if ship.has_method(method):
			return ship.call(method)
	return {}
