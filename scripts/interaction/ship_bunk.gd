class_name ShipBunk
extends StationSeat

## Ship-local sleeping berth. GameFlow owns sleep and waking; the inherited
## furniture contract owns reservation and discovery without moving the player.
var _ship: HeroShip


## Poses are authored in ship-local coordinates, even if the berth root has an
## offset. Every anchor remains a child of the real moving interior.
static func install_bunk(
		bunk_root: Node3D,
		ship: HeroShip,
		rest_local: Transform3D,
		wake_local: Transform3D,
		label: String
	) -> ShipBunk:
	var bunk := ShipBunk.new()
	bunk.name = "ShipBunkInteraction"
	bunk._ship = ship
	bunk.set_meta("seat_label", label.strip_edges().to_upper())
	bunk_root.add_child(bunk)
	# Keep the discovery point at standing eye/chest height beside the mattress,
	# so normal facing-based interaction can target the berth from the aisle.
	bunk.global_transform = ship.global_transform * Transform3D(
		Basis.IDENTITY, wake_local.origin + Vector3.UP * 0.9
	)
	bunk._seat_anchor = Marker3D.new()
	bunk._seat_anchor.name = "RestAnchor"
	bunk.add_child(bunk._seat_anchor)
	bunk._seat_anchor.global_transform = ship.global_transform * rest_local
	bunk._entry_anchor = Marker3D.new()
	bunk._entry_anchor.name = "WakeAnchor"
	bunk.add_child(bunk._entry_anchor)
	bunk._entry_anchor.global_transform = ship.global_transform * wake_local
	bunk._exit_anchor = bunk._entry_anchor
	var shape := SphereShape3D.new()
	shape.radius = DEFAULT_REACH
	var collision := CollisionShape3D.new()
	collision.name = "InteractionShape"
	collision.shape = shape
	bunk.add_child(collision)
	return bunk


func get_ship() -> HeroShip:
	return _ship if is_instance_valid(_ship) else null


func is_available() -> bool:
	return super.is_available() and is_instance_valid(_ship) and not _ship.is_destroyed()


func get_interaction_prompt() -> String:
	if not is_available():
		return ""
	return "[ E ] SLEEP // %s" % str(get_meta("seat_label", "BUNK"))


func get_seated_prompt() -> String:
	return "[ E ] WAKE UP"
