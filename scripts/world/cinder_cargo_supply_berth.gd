extends ShipBerth

## Cinder's two authored hulls share one exclusive berth. Select the exact
## physical dock by the current lease owner; the lease and HeroShip's frozen
## landing snapshot retain their existing authority and tolerances.
const HAULER_ID: StringName = &"cinder_cargo_hauler"
var hauler_dock_transform := Transform3D.IDENTITY


func get_dock_transform() -> Transform3D:
	var owner := get_reservation_owner() as HeroShip
	if owner != null and owner.get_ship_id() == HAULER_ID:
		return global_transform * hauler_dock_transform
	return super.get_dock_transform()


func get_assist_staging_transform() -> Transform3D:
	var owner := get_reservation_owner() as CinderCargoHauler
	if owner != null and owner.get_ship_id() == HAULER_ID:
		# Cross the deck lip at capture height, then let normal Hero landing
		# descend vertically onto the Hauler's exact physical contact pose.
		var dock := get_dock_transform()
		return Transform3D(dock.basis, dock * Vector3(0.0, assist_capture_center.y, 0.0))
	return super.get_assist_staging_transform()
