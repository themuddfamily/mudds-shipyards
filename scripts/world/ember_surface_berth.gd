class_name EmberSurfaceBerth
extends ShipBerth

## Exact, non-rendering ShipBerth adapter for Ember Caldera's authored pad.
##
## The landing-region resource supplies the pad and approach volumes. This
## adapter supplies only the production lease/occupancy contract HeroShip
## requires; it creates no geometry, collision, terrain, or gameplay state.

const ADAPTER_SCHEMA_VERSION := 1
const BERTH_ID: StringName = &"ember_caldera_pad"
const WORLD_ID: StringName = &"ember_moon"
const REGION_ID: StringName = &"ember_caldera"
const REGION_PATH := "res://assets/world/planets/ember_caldera_landing_region.tres"
const ASSIST_HANDOFF_REGION_LOCAL_M := Vector3(0.0, 60.0, 30.0)

const _REGION: PlanetaryLandingRegionDefinition = preload(REGION_PATH)

var _configured_ship_id: StringName = &""
var _configured_collision_bounds := AABB()


func _init() -> void:
	name = "EmberSurfaceBerth"
	position = _REGION.body_local_center_m
	berth_id = BERTH_ID
	compatibility_tags = _REGION.compatible_ship_tags.duplicate()
	landing_half_extents = Vector3(
		_REGION.touchdown_pad_sizes_m[0].x * 0.5,
		_REGION.minimum_vertical_clearance_m * 0.5,
		_REGION.touchdown_pad_sizes_m[0].y * 0.5
	)
	assist_capture_half_extents = _REGION.approach_corridor_half_extents_m[0]
	assist_capture_maximum_speed = 32.0
	assist_maximum_tilt_degrees = 75.0


## Freezes the exact dock-root height from the live compatible hull envelope.
## Configuration is one-shot and is forbidden after any lease exists.
func configure_for_ship(ship: HeroShip) -> Dictionary:
	if not _configured_ship_id.is_empty():
		return _result(false, &"already_configured")
	if ship == null or not is_instance_valid(ship) or ship.is_queued_for_deletion():
		return _result(false, &"ship_unavailable")
	var definition := ship.get_ship_definition()
	if definition == null or not definition.is_definition_valid() \
			or not is_compatible_with(definition):
		return _result(false, &"ship_incompatible")
	var collision := ship.get_landing_collision_report()
	if not bool(collision.get("valid", false)):
		return _result(false, &"ship_collision_invalid")
	var bounds := collision.get("local_bounds", AABB()) as AABB
	var pad_half := landing_half_extents
	if maxf(absf(bounds.position.x), absf(bounds.end.x)) > pad_half.x - 0.05 \
			or maxf(absf(bounds.position.z), absf(bounds.end.z)) > pad_half.z - 0.05 \
			or bounds.size.y > _REGION.minimum_vertical_clearance_m - 0.1:
		return _result(false, &"ship_pad_fit_rejected")
	var dock_root_height := -bounds.position.y
	dock_transform = Transform3D(Basis.IDENTITY, Vector3(0.0, dock_root_height, 0.0))
	assist_capture_center = ASSIST_HANDOFF_REGION_LOCAL_M - dock_transform.origin
	_configured_ship_id = definition.ship_id
	_configured_collision_bounds = bounds
	return _result(true, &"configured")


func is_configured_for(ship: HeroShip) -> bool:
	return ship != null and is_instance_valid(ship) \
		and not _configured_ship_id.is_empty() \
		and ship.get_ship_definition() != null \
		and ship.get_ship_definition().ship_id == _configured_ship_id


func audit() -> Dictionary:
	var report := super.audit()
	var errors := PackedStringArray(report.get("errors", PackedStringArray()))
	if _configured_ship_id.is_empty():
		errors.append("surface berth has not frozen a compatible ship envelope")
	if berth_id != BERTH_ID:
		errors.append("surface berth identity drifted")
	if compatibility_tags != _REGION.compatible_ship_tags:
		errors.append("surface berth compatibility drifted")
	if landing_half_extents != Vector3(14.0, 9.0, 16.0):
		errors.append("surface berth pad volume drifted")
	if assist_capture_half_extents != Vector3(45.0, 60.0, 300.0):
		errors.append("surface berth approach volume drifted")
	if not _configured_ship_id.is_empty():
		if not get_assist_capture_transform().origin.is_equal_approx(
			global_transform * ASSIST_HANDOFF_REGION_LOCAL_M
		):
			errors.append("surface berth assist handoff drifted")
	report["adapter_schema_version"] = ADAPTER_SCHEMA_VERSION
	report["valid"] = errors.is_empty()
	report["errors"] = errors
	report["world_id"] = WORLD_ID
	report["region_id"] = REGION_ID
	report["configured_ship_id"] = _configured_ship_id
	report["configured_collision_bounds"] = _configured_collision_bounds
	report["resource_path"] = REGION_PATH
	report["owned_capabilities"] = {
		"berth_lease": true,
		"berth_occupancy": true,
		"landing_assist_volume": true,
	}
	report["adjacent_authority"] = {
		"geometry": false,
		"collision": false,
		"ship_movement": false,
		"player_movement": false,
		"terrain": false,
		"streaming": false,
		"game_flow": false,
	}
	return report.duplicate(true)


func _result(accepted: bool, reason: StringName) -> Dictionary:
	return {
		"accepted": accepted,
		"reason": reason,
		"audit": audit(),
	}.duplicate(true)
