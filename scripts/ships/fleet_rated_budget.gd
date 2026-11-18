class_name FleetRatedBudget
extends Resource

## Authored rated handling only; no overall score or full-role qualification.
## Metadata keeps actual profile provenance and never scores undirected feel.
const FIELD_SPECS := {
	"maximum_speed": ["m/s", "benefit", "flight"],
	"maximum_hull": ["hull point", "benefit", "systems"],
	"boost_speed": ["m/s", "benefit", "flight"],
	"thrust_acceleration": ["m/s2", "benefit", "flight"],
	"yaw_speed_degrees": ["degree/s", "benefit", "flight"],
	"roll_speed_degrees": ["degree/s", "benefit", "flight"],
	"brake_acceleration": ["m/s2", "benefit", "flight"],
	"passive_drag": ["m/s2", "cost", "flight"],
	"boost_multiplier": ["ratio", "benefit", "flight"],
	"landing_maximum_speed": ["m/s", "benefit", "systems"],
	"engine_start_time": ["s", "cost", "systems"],
	"weapon_cooldown": ["s", "cost", "systems"],
	"throttle_response": ["1/s", "benefit", "flight"],
	"flight_assist_strength": ["1/s", "undirected", "flight"],
	"visual_bank_degrees": ["degree", "undirected", "flight"],
	"maximum_mouse_turn_degrees": ["degree", "undirected", "flight"],
}
const MISSING_DIMENSIONS := [
	"component_consequences_and_repair", "firepower_and_range", "cargo",
	"passenger_and_support", "collision_footprint", "boarding_time", "skill_floor",
	"complete_role_and_capability_metadata",
]

var _valid: bool = false
var _reason: StringName = &"missing_definition"
var _ship_id: StringName = &""
var _fields: Dictionary = {}


func _init(definition: ShipDefinition = null) -> void:
	if definition == null:
		return
	_reason = &"invalid_definition"
	if not definition.is_definition_valid():
		return
	var flight := definition.get_flight_profile()
	var systems := definition.get_systems_profile()
	var sourced: Dictionary = {}
	for axis: String in FIELD_SPECS:
		var spec: Array = FIELD_SPECS[axis]
		var profile: Dictionary = flight if spec[2] == "flight" else systems
		var raw: float = profile[axis]
		if not is_finite(raw) or raw < 0.0:
			return
		sourced[axis] = _field(raw, spec[0], spec[1], "ShipDefinition.get_%s_profile.%s" % [spec[2], axis])
	_ship_id = definition.get_ship_id()
	_fields = sourced
	_valid = true
	_reason = &"rated_handling_sourced"


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
		snapshot["fields"] = _fields.duplicate(true)
	return snapshot.duplicate(true)


func _field(raw: float, unit: String, direction: String, source: String) -> Dictionary:
	var field := {"raw": raw, "unit": unit, "direction": direction,
		"unit_scale": 1.0, "source": source}
	if direction != "undirected":
		field["normalized"] = raw / (1.0 + raw) if direction == "benefit" else 1.0 / (1.0 + raw)
	return field
