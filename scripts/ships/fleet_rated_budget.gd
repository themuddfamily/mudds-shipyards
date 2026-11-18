class_name FleetRatedBudget
extends Resource

## Initial rated subset only. No overall score or full-role qualification.
## Values are copied once from the authored definition; public reads detach.
const MISSING_DIMENSIONS := [
	"boost_speed_and_thrust", "rotational_response", "braking_and_passive_drag",
	"component_consequences_and_repair", "firepower_and_range", "cargo",
	"passenger_and_support", "collision_footprint", "boarding_time", "skill_floor",
	"complete_role_and_capability_metadata",
]

var _valid: bool = false
var _reason: StringName = &"missing_definition"
var _ship_id: StringName = &""
var _maximum_speed: float = 0.0
var _maximum_hull: float = 0.0


func _init(definition: ShipDefinition = null) -> void:
	if definition == null:
		return
	_reason = &"invalid_definition"
	if not definition.is_definition_valid():
		return
	var flight := definition.get_flight_profile()
	var systems := definition.get_systems_profile()
	var speed: float = flight.maximum_speed
	var hull: float = systems.maximum_hull
	if not is_finite(speed) or speed <= 0.0 or not is_finite(hull) or hull <= 0.0:
		return
	_ship_id = definition.get_ship_id()
	_maximum_speed = speed
	_maximum_hull = hull
	_valid = true
	_reason = &"rated_subset_sourced"


func is_valid() -> bool:
	return _valid


func get_ship_id() -> StringName:
	return _ship_id


func get_snapshot() -> Dictionary:
	var snapshot := {
		"valid": _valid, "reason": _reason, "ship_id": _ship_id,
		"qualification": &"NOT_QUALIFIED",
		"missing_dimensions": MISSING_DIMENSIONS.duplicate(),
	}
	if _valid:
		snapshot["fields"] = {
			"maximum_speed": _field(_maximum_speed, "m/s", "ShipDefinition.get_flight_profile.maximum_speed"),
			"maximum_hull": _field(_maximum_hull, "hull point", "ShipDefinition.get_systems_profile.maximum_hull"),
		}
	return snapshot.duplicate(true)


func _field(raw: float, unit: String, source: String) -> Dictionary:
	return {"raw": raw, "unit": unit, "direction": "benefit", "unit_scale": 1.0,
		"normalized": raw / (1.0 + raw), "source": source}
