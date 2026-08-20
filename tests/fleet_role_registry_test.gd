extends SceneTree

## Focused resource-level regression for the Phase 4/7 fleet role contract.
## This intentionally does not boot Main or exercise boarding, landing, combat,
## audio, rendering, or lifecycle; those authorities have their own suites.

const Registry := preload("res://scripts/ships/fleet_role_registry.gd")
const DEFINITIONS := [
	preload("res://assets/ships/torrent_provisional.tres"),
	preload("res://assets/ships/arrow_provisional.tres"),
	preload("res://assets/ships/jovian_provisional.tres"),
	preload("res://assets/ships/zenith_b7_observed.tres"),
	preload("res://assets/ships/halyard_new_design.tres"),
]

var _failures := 0
var _checks := 0


func _initialize() -> void:
	var report: Dictionary = Registry.audit_definitions(DEFINITIONS)
	_check(bool(report.get("valid", false)), "the five production definitions satisfy the role registry")
	_check(int(report.get("craft_count", 0)) == 5, "the role registry audits all five current craft")
	_check(int(report.get("role_count", 0)) == 5, "each current craft owns a distinct stable role ID")
	_check(int(report.get("schema_version", 0)) == Registry.SCHEMA_VERSION, "role audit exposes its schema version")

	var drifted_arrow := (DEFINITIONS[1] as ShipDefinition).duplicate(true) as ShipDefinition
	drifted_arrow.role_name = "Interceptor"
	var drift_report: Dictionary = Registry.audit_definitions([
		DEFINITIONS[0], drifted_arrow, DEFINITIONS[2], DEFINITIONS[3], DEFINITIONS[4],
	])
	_check(not bool(drift_report.get("valid", false)), "role-name drift is rejected by the registry")
	_check(
		str(drift_report.get("errors", PackedStringArray())).contains("role name drifted"),
		"role-name drift reports the owning contract"
	)

	var expected_stories := {
		&"torrent_provisional": "quickest weapon cadence",
		&"arrow_provisional": "high boost ceiling",
		&"jovian_provisional": "connected hold and cabin",
		&"zenith_b7_observed": "high-response interceptor",
		&"halyard_new_design": "walkable flight deck and cabin",
	}
	for definition in DEFINITIONS:
		var contract: Dictionary = Registry.get_role_contract(definition.get_ship_id())
		_check(not contract.is_empty(), "%s has a role contract" % definition.get_ship_id())
		_check(
			str(contract.get("crew_story", "")).contains(expected_stories[definition.get_ship_id()]),
			"%s role contract records its intended player story" % definition.get_ship_id()
		)
		_check(
			not (contract.get("signature_axes", {}) as Dictionary).is_empty(),
			"%s role contract declares at least one signature axis" % definition.get_ship_id()
		)

	print("FLEET_ROLE_REGISTRY: %d checks, %d failures" % [_checks, _failures])
	quit(1 if _failures > 0 else 0)


func _check(condition: bool, message: String) -> void:
	_checks += 1
	if condition:
		print("PASS: %s" % message)
	else:
		_failures += 1
		push_error("FAIL: %s" % message)
