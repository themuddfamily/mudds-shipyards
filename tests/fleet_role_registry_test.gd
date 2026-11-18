extends SceneTree

## Focused resource-level regression for the Phase 4/7 fleet role contract.
## This intentionally does not boot Main or exercise boarding, landing, combat,
## audio, rendering, or lifecycle; those authorities have their own suites.

const RatedBudgetType := preload("res://scripts/ships/fleet_rated_budget.gd")
const Registry := preload("res://scripts/ships/fleet_role_registry.gd")
const DEFINITIONS := [
	preload("res://assets/ships/torrent_provisional.tres"),
	preload("res://assets/ships/arrow_provisional.tres"),
	preload("res://assets/ships/jovian_provisional.tres"),
	preload("res://assets/ships/zenith_b7_observed.tres"),
	preload("res://assets/ships/halyard_new_design.tres"),
	preload("res://assets/ships/bulwark_new_design.tres"),
	preload("res://assets/ships/cinder_light_interceptor_new_design.tres"),
	preload("res://assets/ships/cinder_long_range_bomber_new_design.tres"),
	preload("res://assets/ships/cinder_cargo_hauler_new_design.tres"),
]

var _failures := 0
var _checks := 0


func _initialize() -> void:
	var original_resources := _definition_snapshots()
	_check_rated_budgets()
	var report: Dictionary = Registry.audit_definitions(DEFINITIONS)
	_check(bool(report.get("valid", false)), "the nine production definitions satisfy the role registry")
	_check(int(report.get("craft_count", 0)) == 9, "the role registry audits all nine supported craft")
	_check(int(report.get("role_count", 0)) == 9, "each current craft owns a distinct stable role ID")
	_check(int(report.get("schema_version", 0)) == Registry.SCHEMA_VERSION, "role audit exposes its schema version")
	var jovian_engineer := Registry.get_crew_role_contract(&"jovian_provisional", &"engineer")
	_check(not jovian_engineer.is_empty(), "Jovian engineer capability is discoverable without constructing the ship")
	_check(
		jovian_engineer.get("seat_id", &"") == &"passenger_port_01"
			and jovian_engineer.get("anchor_id", &"") == &"passenger_port_01"
			and bool(jovian_engineer.get("physical", false)),
		"Jovian engineer publishes its physical passenger-cabin station"
	)
	_check(
		(jovian_engineer.get("capabilities", []) as Array).has(&"systems_control")
			and (jovian_engineer.get("actions", []) as Array).has(&"engineer_repair")
			and jovian_engineer.get("authority_owner", &"") == &"CrewSeatRoleAuthority"
			and jovian_engineer.get("consumer_owner", &"") == &"JovianLightFreighter",
		"Jovian engineer publishes its bounded systems capability and consumer"
	)
	_check(
		bool(jovian_engineer.get("generation_fenced", false))
			and bool(jovian_engineer.get("sequence_fenced", false)),
		"Jovian engineer discoverability retains generation and sequence fencing"
	)
	var detached_engineer := Registry.get_crew_role_contract(&"jovian_provisional", &"engineer")
	detached_engineer["seat_id"] = &"tampered"
	_check(
		Registry.get_crew_role_contract(&"jovian_provisional", &"engineer").get("seat_id", &"") == &"passenger_port_01",
		"Jovian engineer capability returns detached policy data"
	)

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
		&"bulwark_heavy_gunship": "durable sustained fire",
		&"cinder_light_interceptor": "fast-response interceptor",
		&"cinder_long_range_bomber": "trades turn rate and weapon cadence",
		&"cinder_cargo_hauler": "trades speed and thrust",
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

	_check_bomber_contract()
	_check_hauler_contract()
	_check_light_contract()
	_check(_definition_snapshots() == original_resources, "all stored definition properties survive registry reads and detached policy mutation")
	print("FLEET_ROLE_REGISTRY: %d checks, %d failures" % [_checks, _failures])
	quit(1 if _failures > 0 else 0)


func _check(condition: bool, message: String) -> void:
	_checks += 1
	if condition:
		print("PASS: %s" % message)
	else:
		_failures += 1
		push_error("FAIL: %s" % message)


func _check_light_contract() -> void:
	var light := DEFINITIONS[6] as ShipDefinition
	var contract := Registry.get_role_contract(light.get_ship_id())
	_check(Registry.get_supported_ship_ids().size() == 9, "all nine approved original/Cinder craft now have supported contracts")
	_check(not Registry.get_role_contract(&"cinder_cargo_hauler").is_empty(), "Hauler now has the remaining approved Cinder contract")
	_check(contract.role_id == &"cinder_light_interceptor" and contract.role_name == "Light interceptor"
		and contract.scale_band == &"small" and not contract.interior_expected,
		"Light preserves stable identity, role and small-craft band")
	_check(contract.required_tags == [&"small_craft", &"interceptor", &"rapid_response"], "Light contract requires its exact live role tags")
	_check(contract.signature_scope == &"same_scale_band"
		and contract.signature_axes == {"maximum_speed": &"maximum"}, "only Light's base-speed signature explicitly compares its own scale band")
	var old_signatures := [
		{"boost_multiplier": &"maximum", "weapon_cooldown": &"minimum", "landing_maximum_speed": &"maximum"},
		{"boost_speed": &"maximum"}, {"maximum_speed": &"minimum"},
		{"yaw_speed_degrees": &"maximum", "roll_speed_degrees": &"maximum", "maximum_hull": &"minimum"},
		{"maximum_speed": &"maximum", "thrust_acceleration": &"minimum", "brake_acceleration": &"minimum", "boost_multiplier": &"minimum", "landing_maximum_speed": &"minimum", "engine_start_time": &"maximum", "weapon_cooldown": &"maximum"},
		{"maximum_hull": &"maximum"},
	]
	for index in 6:
		var old := Registry.get_role_contract(DEFINITIONS[index].get_ship_id())
		_check(old.get("signature_scope", &"global") == &"global" and old.signature_axes == old_signatures[index], "original %s global signature remains exact" % DEFINITIONS[index].get_ship_id())
	_check(Registry.MINIMUM_DIFFERING_HANDLING_AXES == 14, "the original 14-of-16 separation floor is unchanged")
	var facts := Registry.get_boarding_choice_facts(light)
	_check(facts.advantage == "FAST RESPONSE" and facts.weakness == "HIGH DRAG WHEN COASTING"
		and facts.maximum_speed == 102.0 and facts.passive_drag == 3.0
		and facts.source_axes == {"advantage": &"maximum_speed", "weakness": &"passive_drag"},
		"Light choice text carries actual 102 base-speed / 3 passive-drag sources")
	_check(not contract.has("crew_role_capabilities") and facts.size() == 7,
		"choice facts advertise no invented cargo, crew, weapon or authority budget")
	facts.source_axes.advantage = &"maximum_hull"
	facts.advantage = "TAMPERED"
	contract.required_tags.clear()
	contract.signature_axes.maximum_speed = &"minimum"
	_check(Registry.get_boarding_choice_facts(light).advantage == "FAST RESPONSE"
		and Registry.get_role_contract(light.get_ship_id()).required_tags.size() == 3
		and Registry.get_role_contract(light.get_ship_id()).signature_axes.maximum_speed == &"maximum"
		and Registry.get_boarding_choice_facts(light).source_axes.advantage == &"maximum_speed",
		"nested public contract and choice mutations cannot alter retained policy")
	_check(Registry.get_boarding_choice_facts(null).is_empty(), "null definition yields no choice facts")
	for index in 6:
		_check(Registry.get_boarding_choice_facts(DEFINITIONS[index]).is_empty(), "other craft have no Light choice claim")
	var tied_arrow := DEFINITIONS[1].duplicate(true) as ShipDefinition
	tied_arrow.maximum_speed = 102.0
	var tied: Array = DEFINITIONS.duplicate()
	tied[1] = tied_arrow
	_check(str(Registry.audit_definitions(tied).errors).contains("cinder_light_interceptor no longer owns the contracted maximum of maximum_speed"), "same-band base-speed tie rejects Light's signature")
	var fast_medium := DEFINITIONS[4] as ShipDefinition
	_check(fast_medium.maximum_speed > light.maximum_speed and bool(Registry.audit_definitions(DEFINITIONS).valid), "a faster medium hull retains its global signature without invalidating Light's small-band signature")
	var dominating_light := light.duplicate(true) as ShipDefinition
	for axis in Registry.HIGHER_IS_BETTER:
		dominating_light.set(axis, float(DEFINITIONS[1].get(axis)) + 1.0)
	for axis in Registry.LOWER_IS_BETTER:
		dominating_light.set(axis, float(DEFINITIONS[1].get(axis)) * 0.5)
	var dominated: Array = DEFINITIONS.duplicate()
	dominated[6] = dominating_light
	_check(str(Registry.audit_definitions(dominated).errors).contains("cinder_light_interceptor is a strict upgrade over arrow_provisional"), "non-dominance failure names the actual dominating craft before its victim")
	var duplicate_profile := light.duplicate(true) as ShipDefinition
	for key in DEFINITIONS[1].get_flight_profile():
		duplicate_profile.set(key, DEFINITIONS[1].get_flight_profile()[key])
	for key in DEFINITIONS[1].get_systems_profile():
		duplicate_profile.set(key, DEFINITIONS[1].get_systems_profile()[key])
	var collapsed: Array = DEFINITIONS.duplicate()
	collapsed[6] = duplicate_profile
	var collapsed_errors := str(Registry.audit_definitions(collapsed).errors)
	_check(collapsed_errors.contains("differ on only 0 handling axes") and collapsed_errors.contains("strict upgrade"), "new same-band scope never weakens global separation or non-dominance")


func _definition_snapshots() -> Array:
	var snapshots: Array = []
	for definition in DEFINITIONS:
		var properties := {}
		for property in definition.get_property_list():
			if int(property.usage) & PROPERTY_USAGE_STORAGE:
				properties[property.name] = definition.get(property.name)
		snapshots.append(properties.duplicate(true))
	return snapshots


func _check_bomber_contract() -> void:
	var bomber := DEFINITIONS[7] as ShipDefinition
	var contract := Registry.get_role_contract(bomber.get_ship_id())
	_check(not contract.is_empty(), "Bomber has its approved role contract")
	if contract.is_empty():
		return
	_check(contract.role_id == &"cinder_long_range_bomber" and contract.role_name == "Long-range bomber" and contract.scale_band == &"medium" and not contract.interior_expected, "Bomber preserves its actual identity and medium single-cockpit role")
	_check(contract.required_tags == [&"medium_craft", &"bomber", &"ordnance"], "Bomber uses its existing exact tags")
	_check(contract.signature_scope == &"cinder_siblings" and contract.signature_axes == {"maximum_hull": &"maximum", "yaw_speed_degrees": &"minimum", "roll_speed_degrees": &"minimum", "weapon_cooldown": &"maximum"}, "Bomber hull, turn and cadence extremes compare only approved Cinder siblings")
	var facts := Registry.get_boarding_choice_facts(bomber)
	_check(facts.get("advantage") == "TOUGH HULL & BRAKES" and facts.get("weakness") == "SLOW TURN / FIRE", "Bomber publishes its exact bounded trade-off")
	for axis in ["maximum_speed", "maximum_hull", "brake_acceleration", "yaw_speed_degrees", "roll_speed_degrees", "weapon_cooldown"]:
		_check(facts.get(axis) == bomber.get(axis), "Bomber %s choice fact comes from its existing definition" % axis)
	_check(facts.get("source_axes") == {"advantage": [&"maximum_hull", &"brake_acceleration"], "weakness": [&"yaw_speed_degrees", &"roll_speed_degrees", &"weapon_cooldown"]} and facts.size() == 11 and not contract.has("crew_role_capabilities"), "Bomber advertises exactly the approved source axes without invented capabilities")
	facts.source_axes.advantage.clear()
	facts.maximum_hull = 999.0
	_check(Registry.get_boarding_choice_facts(bomber).maximum_hull == 240.0 and Registry.get_boarding_choice_facts(bomber).source_axes.advantage.size() == 2, "Bomber nested facts remain detached")
	var hauler := load("res://assets/ships/cinder_cargo_hauler_new_design.tres") as ShipDefinition
	for sibling in [DEFINITIONS[6], hauler]:
		_check(bomber.maximum_hull > sibling.maximum_hull and bomber.yaw_speed_degrees < sibling.yaw_speed_degrees and bomber.roll_speed_degrees < sibling.roll_speed_degrees and bomber.weapon_cooldown > sibling.weapon_cooldown, "Bomber hull and turn/cadence trade-off holds against each actual Cinder sibling")
	_check(bomber.brake_acceleration > hauler.brake_acceleration and bomber.brake_acceleration < DEFINITIONS[6].brake_acceleration, "Bomber braking improves on Hauler while remaining below Light")
	var tied_bomber := bomber.duplicate(true) as ShipDefinition
	tied_bomber.maximum_hull = DEFINITIONS[6].maximum_hull
	var tied: Array = DEFINITIONS.duplicate()
	tied[7] = tied_bomber
	_check(str(Registry.audit_definitions(tied).errors).contains("cinder_long_range_bomber no longer owns the contracted maximum of maximum_hull"), "Bomber sibling signature tie is rejected without weakening original signatures")


func _check_hauler_contract() -> void:
	var hauler := DEFINITIONS[8] as ShipDefinition
	var contract := Registry.get_role_contract(hauler.get_ship_id())
	_check(not contract.is_empty(), "Hauler has its approved role contract")
	if contract.is_empty():
		return
	_check(contract.role_id == &"cinder_cargo_hauler" and contract.role_name == "Cargo hauler" and contract.scale_band == &"medium" and not contract.interior_expected, "Hauler preserves actual identity and medium single-cockpit role")
	_check(contract.required_tags == [&"medium_craft", &"cargo_hauler", &"freight"], "Hauler uses its existing exact tags")
	_check(contract.signature_scope == &"cinder_siblings" and contract.signature_axes == {"passive_drag": &"minimum"} and contract.signature_ship_ids == [&"cinder_cargo_hauler", &"cinder_long_range_bomber", &"cinder_light_interceptor"], "Hauler minimum drag compares only its exact approved Cinder siblings")
	var facts := Registry.get_boarding_choice_facts(hauler)
	_check(facts.get("advantage") == "HULL & LOW DRAG" and facts.get("weakness") == "SLOW SPEED / THRUST", "Hauler publishes its exact approved trade-off")
	for axis in ["maximum_speed", "maximum_hull", "thrust_acceleration", "passive_drag"]:
		_check(facts.get(axis) == hauler.get(axis), "Hauler %s choice fact comes from its existing definition" % axis)
	_check(facts.get("source_axes") == {"advantage": [&"maximum_hull", &"passive_drag"], "weakness": [&"maximum_speed", &"thrust_acceleration"]} and facts.size() == 9 and not contract.has("crew_role_capabilities"), "Hauler advertises exactly approved source axes without invented cargo, crew or authority capabilities")
	facts.source_axes.advantage.clear()
	facts.passive_drag = 999.0
	_check(Registry.get_boarding_choice_facts(hauler).passive_drag == 1.5 and Registry.get_boarding_choice_facts(hauler).source_axes.advantage.size() == 2, "Hauler nested facts remain detached")
	for sibling in [DEFINITIONS[6], DEFINITIONS[7]]:
		_check(hauler.passive_drag < sibling.passive_drag and hauler.maximum_speed < sibling.maximum_speed and hauler.thrust_acceleration < sibling.thrust_acceleration, "Hauler low drag versus slow speed/thrust holds against each actual Cinder sibling")
	_check(hauler.maximum_hull > DEFINITIONS[6].maximum_hull and hauler.maximum_hull < DEFINITIONS[7].maximum_hull, "Hauler hull margin exceeds Light while remaining below Bomber")
	_check(DEFINITIONS[2].maximum_speed == 56.0 and DEFINITIONS[2].maximum_speed < hauler.maximum_speed, "Jovian keeps its actual global minimum speed below Hauler")
	var tied_hauler := hauler.duplicate(true) as ShipDefinition
	tied_hauler.passive_drag = DEFINITIONS[7].passive_drag
	var tied: Array = DEFINITIONS.duplicate()
	tied[8] = tied_hauler
	_check(str(Registry.audit_definitions(tied).errors).contains("cinder_cargo_hauler no longer owns the contracted minimum of passive_drag"), "Hauler sibling drag tie is rejected without weakening any previous signature")


func _check_rated_budgets() -> void:
	var definitions: Array = DEFINITIONS.duplicate()
	for path in ["titan_provisional", "predator_provisional", "paradox_provisional", "dynamic_provisional", "utopia_provisional", "katana_provisional", "vortex_new_design", "salyut_new_design"]:
		definitions.append(load("res://assets/ships/%s.tres" % path))
	_check(definitions.size() == 17, "all seventeen authored definitions expose the initial rated subset without changing Main membership")
	for definition: ShipDefinition in definitions:
		var before := {"flight": definition.get_flight_profile(), "systems": definition.get_systems_profile()}
		var budget := Registry.create_rated_budget(definition)
		_check(budget is Resource and budget is RatedBudgetType and budget.is_valid() and budget.get_ship_id() == definition.get_ship_id(), "rated budget is a real valid typed Resource for %s" % definition.get_ship_id())
		var snapshot := budget.get_snapshot()
		_check(snapshot.valid and snapshot.ship_id == definition.get_ship_id() and snapshot.qualification == &"NOT_QUALIFIED" and snapshot.missing_dimensions == ["boost_speed_and_thrust", "rotational_response", "braking_and_passive_drag", "component_consequences_and_repair", "firepower_and_range", "cargo", "passenger_and_support", "collision_footprint", "boarding_time", "skill_floor", "complete_role_and_capability_metadata"] and snapshot.fields.size() == 2, "rated subset retains identity and explicitly leaves full-role dimensions unqualified")
		for axis: String in ["maximum_speed", "maximum_hull"]:
			var field: Dictionary = snapshot.fields[axis]
			var raw := float(definition.get(axis))
			_check(field.raw is float and field.normalized is float and field.raw == raw and field.normalized == raw / (1.0 + raw) and field.direction == "benefit" and field.unit_scale == 1.0 and field.unit == ("m/s" if axis == "maximum_speed" else "hull point"), "%s %s retains exact raw/unit/benefit/normalization without display rounding" % [definition.get_ship_id(), axis])
		snapshot.fields.maximum_speed.raw = 999.0
		snapshot.missing_dimensions.clear()
		_check(budget.get_snapshot().fields.maximum_speed.raw == definition.maximum_speed and budget.get_snapshot().missing_dimensions.size() == 11 and before == {"flight": definition.get_flight_profile(), "systems": definition.get_systems_profile()}, "detached budget mutation cannot change resource or authored definition")
	var source := DEFINITIONS[0].duplicate(true) as ShipDefinition
	var frozen := Registry.create_rated_budget(source)
	var copied := frozen.get_snapshot()
	source.maximum_speed += 1.0
	_check(frozen.get_snapshot() == copied, "later definition mutation cannot alter an already sourced rated Resource")
	_check(not Registry.create_rated_budget(null).is_valid() and not Registry.create_rated_budget(null).get_snapshot().has("fields"), "null source is explicitly invalid without fabricated zero ratings")
	for invalid in [0.0, -1.0, INF, NAN]:
		var bad := DEFINITIONS[0].duplicate(true) as ShipDefinition
		bad.maximum_speed = invalid
		_check(not Registry.create_rated_budget(bad).is_valid() and not Registry.create_rated_budget(bad).get_snapshot().has("fields"), "invalid authored rated speed refuses the resource explicitly")
		var bad_hull := DEFINITIONS[0].duplicate(true) as ShipDefinition
		bad_hull.maximum_hull = invalid
		_check(not Registry.create_rated_budget(bad_hull).is_valid() and not Registry.create_rated_budget(bad_hull).get_snapshot().has("fields"), "invalid authored rated hull refuses the resource explicitly")
