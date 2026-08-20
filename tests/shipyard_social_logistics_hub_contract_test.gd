extends SceneTree

## Focused contract checks for the authored shipyard social/logistics heart.
## This does not launch Main, render, or run the wider test matrix.

const ContractScript := preload("res://scripts/world/shipyard_social_logistics_hub_contract.gd")

var _assertions := 0
var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_test_default_hub()
	_test_service_and_activity_handoffs()
	_test_snapshot_detachment()
	_test_invalid_configuration_fails_closed()
	_finish()


func _test_default_hub() -> void:
	var contract := ContractScript.new()
	_check(contract.is_definition_valid(), "default shipyard social/logistics hub is valid")
	var snapshot: Dictionary = contract.get_snapshot()
	var identity: Dictionary = snapshot.get("identity", {})
	var evidence: Dictionary = snapshot.get("evidence", {})
	var authority: Dictionary = snapshot.get("authority", {})
	_check(snapshot.get("schema_version", -1) == 1, "schema version is explicit")
	_check(identity.get("station_id") == &"mudds_shipyards", "hub station identity is stable")
	_check(identity.get("hub_id") == &"mudds_shipyards_social_logistics_hub", "hub identity is stable")
	_check(identity.get("return_target_id") == &"mudds_shipyards", "return target is the shipyard")
	_check((identity.get("heart_roles", []) as PackedStringArray).has("social"), "hub exposes social role")
	_check((identity.get("heart_roles", []) as PackedStringArray).has("logistics"), "hub exposes logistics role")
	_check((identity.get("heart_roles", []) as PackedStringArray).has("return_anchor"), "hub exposes return-anchor role")
	_check(snapshot.get("services", []).size() == 4, "hub has four fixed service anchors")
	_check(snapshot.get("activities", []).size() == 5, "hub has five fixed activity handoffs")
	_check(evidence.get("procedural_galaxy", true) == false, "hub explicitly forbids procedural galaxy expansion")
	_check(evidence.get("procedural_generation", true) == false, "hub explicitly forbids procedural generation")
	_check(evidence.get("historical_claim", true) == false, "hub makes no historical claim")
	_check(authority.get("activity", true) == false, "contract owns no activity authority")
	_check(authority.get("logistics", true) == false, "contract owns no logistics authority")
	_check(authority.get("return", true) == false, "contract owns no return authority")


func _test_service_and_activity_handoffs() -> void:
	var contract := ContractScript.new()
	var social := contract.get_service_by_id(&"crew_social_deck")
	var cargo := contract.get_service_by_id(&"cargo_transfer_terminal")
	var board := contract.get_service_by_id(&"activity_board")
	var berth := contract.get_service_by_id(&"shipyard_return_berth")
	_check(social.get("kind") == &"social", "crew deck is the social service")
	_check(cargo.get("kind") == &"logistics", "cargo terminal is the logistics service")
	_check(board.get("kind") == &"activity", "activity board is the activity service")
	_check(berth.get("kind") == &"return", "return berth is the return service")
	var defense := contract.get_activity_by_id(&"shipyard_perimeter_defense")
	var delivery := contract.get_activity_by_id(&"cinder_kit_cargo_run")
	var convoy := contract.get_activity_by_id(&"ember_convoy_escort")
	_check(defense.get("handoff_authority_id") == &"station_defense_encounter_host", "defense uses existing encounter authority")
	_check(delivery.get("handoff_authority_id") == &"cargo_delivery_activity", "cargo uses existing delivery authority")
	_check(convoy.get("handoff_authority_id") == &"convoy_escort_activity", "convoy uses existing escort authority")
	for activity in contract.get_snapshot().get("activities", []):
		_check(activity.get("finish_service_id") == &"shipyard_return_berth", "activity returns to the fixed shipyard berth")
		_check(String(activity.get("return_route_id", "")).contains("return"), "activity exposes an explicit return route")
		_check(String(activity.get("return_incentive_id", "")).begins_with("return_"), "activity exposes a return incentive")
		_check(not String(activity.get("recovery_id", "")).is_empty(), "activity exposes a recovery handoff")
	_check(contract.get_activity_by_id(&"unknown_activity").is_empty(), "unknown activity does not fabricate a handoff")
	_check(contract.get_service(-1).is_empty() and contract.get_service(99).is_empty(), "invalid service indexes fail closed")


func _test_snapshot_detachment() -> void:
	var contract := ContractScript.new()
	var snapshot := contract.get_snapshot()
	(snapshot.get("identity", {}) as Dictionary)["hub_id"] = &"forged_hub"
	(snapshot.get("services", []) as Array).clear()
	(snapshot.get("activities", []) as Array).clear()
	var fresh := contract.get_snapshot()
	_check(fresh.get("identity", {}).get("hub_id") == &"mudds_shipyards_social_logistics_hub", "snapshot identity is detached")
	_check(fresh.get("services", []).size() == 4, "snapshot services are detached")
	_check(fresh.get("activities", []).size() == 5, "snapshot activities are detached")


func _test_invalid_configuration_fails_closed() -> void:
	var duplicate_service := ContractScript.new()
	duplicate_service.service_ids[1] = duplicate_service.service_ids[0]
	_check(not duplicate_service.is_definition_valid() and _has_error(duplicate_service, "service_ids must not contain duplicate IDs"), "duplicate service IDs are rejected")
	var missing_role := ContractScript.new()
	missing_role.hub_role_ids.remove_at(0)
	_check(not missing_role.is_definition_valid() and _has_error(missing_role, "hub must expose the social heart role"), "missing social heart role is rejected")
	var broken_parallel := ContractScript.new()
	broken_parallel.activity_return_route_ids.remove_at(0)
	_check(not broken_parallel.is_definition_valid() and _has_error(broken_parallel, "activity return routes must be parallel to IDs"), "parallel return-route drift is rejected")
	var broken_finish := ContractScript.new()
	broken_finish.activity_finish_service_ids[0] = "unknown_service"
	_check(not broken_finish.is_definition_valid() and _has_error(broken_finish, "activity 0 references unknown service"), "unknown return service is rejected")
	var procedural := ContractScript.new()
	procedural.hub_id = &"generated_galaxy"
	_check(not procedural.is_definition_valid() and _has_error(procedural, "hub_id must identify the fixed shipyard social/logistics hub"), "galaxy identity is rejected")
	var unbounded := ContractScript.new()
	unbounded.maximum_activity_radius_m = 0.0
	_check(not unbounded.is_definition_valid() and _has_error(unbounded, "maximum_activity_radius_m is outside the bounded activity envelope"), "unbounded hub radius is rejected")


func _has_error(contract: Resource, expected: String) -> bool:
	return (contract.get_validation_errors() as PackedStringArray).has(expected)


func _check(condition: bool, description: String) -> void:
	_assertions += 1
	if not condition:
		_failures.append(description)


func _finish() -> void:
	if _failures.is_empty():
		print("SHIPYARD_SOCIAL_LOGISTICS_HUB_CONTRACT_TEST_OK: %d assertions" % _assertions)
		quit(0)
		return
	for failure in _failures:
		push_error("FAIL: " + failure)
	push_error("%d/%d assertions failed" % [_failures.size(), _assertions])
	quit(1)
