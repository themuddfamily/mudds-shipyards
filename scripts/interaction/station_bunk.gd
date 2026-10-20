class_name StationBunk
extends StationSeat

## Fixed station berth. Reservation and animated handoff remain the StationSeat
## contract; GameFlow supplies the existing sleeping/wake presentation.
static func install_bunk(
		bunk_root: Node3D,
		rest_local: Transform3D,
		wake_local: Transform3D,
		label: String
	) -> StationBunk:
	var bunk := StationBunk.new()
	bunk.name = "StationBunkInteraction"
	bunk.set_meta("seat_label", label.strip_edges().to_upper())
	bunk_root.add_child(bunk)
	# The component origin is also the facing-based discovery target. Keep it
	# forward of the standing Player's own interaction origin, in the bunk mouth.
	bunk.position = wake_local.origin - wake_local.basis.z * 0.65 + Vector3.UP * 1.10
	var to_component := bunk.transform.affine_inverse()
	bunk._seat_anchor = Marker3D.new()
	bunk._seat_anchor.name = "RestAnchor"
	bunk._seat_anchor.transform = to_component * rest_local
	bunk.add_child(bunk._seat_anchor)
	bunk._entry_anchor = Marker3D.new()
	bunk._entry_anchor.name = "WakeAnchor"
	bunk._entry_anchor.transform = to_component * wake_local
	bunk.add_child(bunk._entry_anchor)
	bunk._exit_anchor = bunk._entry_anchor
	var shape := SphereShape3D.new()
	shape.radius = DEFAULT_REACH
	var collision := CollisionShape3D.new()
	collision.name = "InteractionShape"
	collision.shape = shape
	bunk.add_child(collision)
	return bunk


func get_interaction_prompt() -> String:
	if not is_available():
		return ""
	return "[ E ] SLEEP // %s" % str(get_meta("seat_label", "STATION BUNK"))


func get_seated_prompt() -> String:
	return "[ E ] WAKE UP"
