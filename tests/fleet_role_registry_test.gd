extends SceneTree

const EXPECTED_RATED_FIELDS := {
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
const EXPECTED_MISSING_DIMENSIONS := [
	"component_consequences_and_repair", "firepower_and_range", "cargo",
	"passenger_and_support", "collision_footprint", "boarding_time", "skill_floor",
	"complete_role_and_capability_metadata",
]

## Focused resource-level regression for the Phase 4/7 fleet role contract.
## This does not boot Main. Literal inert HeroShip nodes test collision snapshots;
## boarding, flight, audio and rendering remain in their focused suites.

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

class LiteralHull extends HeroShip:
	func _ready() -> void:
		pass
	func _physics_process(_delta: float) -> void:
		pass
	func _process(_delta: float) -> void:
		pass

var _failures := 0
var _checks := 0


func _initialize() -> void:
	call_deferred(&"_run")


func _run() -> void:
	var original_resources := _definition_snapshots()
	_check_rated_budgets()
	_check_literal_footprint()
	_check_pilot_budget_detachment()
	_check_boarding_budget()
	_check_cargo_budget()
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
	for path in ["titan_provisional", "predator_provisional", "paradox_provisional", "dynamic_provisional", "utopia_provisional", "katana_provisional", "vortex_provisional", "salyut_provisional"]:
		definitions.append(load("res://assets/ships/%s.tres" % path))
	_check(definitions.size() == 17, "all seventeen authored definitions expose the complete authored rated handling without changing Main membership")
	for definition: ShipDefinition in definitions:
		var before := {"flight": definition.get_flight_profile(), "systems": definition.get_systems_profile()}
		var budget := Registry.create_rated_budget(definition)
		_check(budget is Resource and budget is RatedBudgetType and budget.is_valid() and budget.get_ship_id() == definition.get_ship_id(), "rated budget is a real valid typed Resource for %s" % definition.get_ship_id())
		var snapshot := budget.get_snapshot()
		_check(snapshot.valid and snapshot.ship_id == definition.get_ship_id() and snapshot.qualification == &"NOT_QUALIFIED" and snapshot.missing_dimensions == EXPECTED_MISSING_DIMENSIONS and snapshot.fields.size() == 16, "rated subset retains identity and explicitly leaves full-role dimensions unqualified")
		_check(snapshot.pilot_weapon == {"status": "UNKNOWN", "reason": "live_craft_not_supplied", "source": "actual_registered_pilot_weapon_and_firing_constraints"}, "definition-only pilot weapon remains explicitly UNKNOWN without numeric invention")
		_check(snapshot.footprint == {"status": "UNKNOWN", "reason": "live_craft_not_supplied", "source": "actual_enabled_direct_root_collision_shapes"}, "definition-only footprints are explicitly unmeasured without numeric geometry")
		for axis: String in EXPECTED_RATED_FIELDS:
			var field: Dictionary = snapshot.fields[axis]
			var spec: Array = EXPECTED_RATED_FIELDS[axis]
			var profile: Dictionary = definition.get_flight_profile() if spec[2] == "flight" else definition.get_systems_profile()
			var raw: float = profile[axis]
			_check(field.raw is float and field.raw == raw and field.direction == spec[1] and field.unit_scale == 1.0 and field.unit == spec[0] and field.source == "ShipDefinition.get_%s_profile.%s" % [spec[2], axis], "%s %s retains exact raw/unit/direction/profile provenance" % [definition.get_ship_id(), axis])
			if spec[1] == "undirected":
				_check(not field.has("normalized"), "feel axes never receive a favorable index")
			else:
				var expected := raw / (1.0 + raw) if spec[1] == "benefit" else 1.0 / (1.0 + raw)
				_check(field.normalized is float and field.normalized == expected, "directed rated field retains full precision")
		snapshot.fields.maximum_speed.raw = 999.0
		snapshot.missing_dimensions.clear()
		_check(budget.get_snapshot().fields.maximum_speed.raw == definition.maximum_speed and budget.get_snapshot().missing_dimensions.size() == 8 and before == {"flight": definition.get_flight_profile(), "systems": definition.get_systems_profile()}, "detached budget mutation cannot change resource or authored definition")
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

	for axis: String in EXPECTED_RATED_FIELDS:
		for invalid: float in [-1.0, INF, NAN]:
			var bad := DEFINITIONS[0].duplicate(true) as ShipDefinition
			bad.set(axis, invalid)
			_check(not Registry.create_rated_budget(bad).is_valid() and not Registry.create_rated_budget(bad).get_snapshot().has("fields"), "invalid %s refuses all handling fields atomically" % axis)
	var zero_bank := DEFINITIONS[0].duplicate(true) as ShipDefinition
	zero_bank.visual_bank_degrees = 0.0
	var zero_snapshot := Registry.create_rated_budget(zero_bank).get_snapshot()
	_check(zero_snapshot.valid and zero_snapshot.fields.visual_bank_degrees.raw == 0.0 and not zero_snapshot.fields.visual_bank_degrees.has("normalized"), "allowed zero bank is honest undirected feel")


func _literal_shape(craft: HeroShip, shape: Shape3D, pose: Transform3D = Transform3D.IDENTITY, disabled: bool = false) -> CollisionShape3D:
	var collision := CollisionShape3D.new()
	collision.shape = shape
	collision.transform = pose
	collision.disabled = disabled
	craft.add_child(collision)
	return collision


func _check_literal_footprint() -> void:
	var definition := DEFINITIONS[0].duplicate(true) as ShipDefinition
	var craft := LiteralHull.new()
	craft.ship_definition = definition
	craft.ship_id = definition.get_ship_id()
	root.add_child(craft)
	var box := BoxShape3D.new()
	box.size = Vector3(2, 4, 6)
	var first := _literal_shape(craft, box, Transform3D(Basis.IDENTITY, Vector3(-4, 0, 0)))
	var convex := ConvexPolygonShape3D.new()
	convex.points = PackedVector3Array([Vector3(0,0,0), Vector3(2,0,0), Vector3(0,2,0), Vector3(0,0,4)])
	var second := _literal_shape(craft, convex, Transform3D(Basis(Vector3.UP, PI / 2.0), Vector3(4,1,0)))
	var huge := BoxShape3D.new()
	huge.size = Vector3.ONE * 1000
	_literal_shape(craft, huge, Transform3D.IDENTITY, true)
	var resource := Registry.create_rated_budget(definition, craft)
	var snapshot := resource.get_snapshot()
	var measured: Dictionary = snapshot.footprint
	_check(measured.status == "MEASURED", "literal live root geometry is measured")
	if measured.status != "MEASURED":
		craft.free()
		return
	# Box [-5,-2,-3]..[-3,2,3], rotated tetrahedron [4,1,-2]..[8,3,0].
	_check(measured.local_bounds == {"position": {"x": -5.0, "y": -2.0, "z": -3.0}, "size": {"x": 13.0, "y": 5.0, "z": 6.0}} and measured.shape_count == 2, "complete literal union includes offset rotated actual vertices and ignores disabled geometry")
	var missing := EXPECTED_MISSING_DIMENSIONS.duplicate()
	missing.erase("collision_footprint")
	_check(snapshot.missing_dimensions == missing and snapshot.qualification == &"NOT_QUALIFIED", "only measured collision dimension leaves the missing set")
	for axis: String in ["span", "height", "length"]:
		var field: Dictionary = measured.fields[axis]
		_check(field.unit == "m" and field.direction == "cost" and field.unit_scale == 1.0 and field.normalized == 1.0 / (1.0 + field.raw), "literal footprint uses fixed metre cost normalization")
	craft.transform = Transform3D(Basis.from_euler(Vector3(0.2,0.6,0.1)), Vector3(20,30,40))
	_check(Registry.create_rated_budget(definition, craft).get_snapshot().footprint == measured, "root rigid rotation and translation preserve local physical dimensions")
	craft.scale = Vector3.ONE * 2.0
	_check_unavailable_footprint(definition, craft, "root_transform_not_proper_rigid")
	craft.transform = Transform3D.IDENTITY
	_check(not resource._valid_root_transform(Transform3D(Basis(Vector3(-1,0,0), Vector3.UP, Vector3.BACK), Vector3.ZERO)), "reflected root basis cannot produce physical metre measurements")
	var wrong := definition.duplicate(true) as ShipDefinition
	_check_unavailable_footprint(wrong, craft, "live_definition_identity_mismatch")
	var unsupported := _literal_shape(craft, SeparationRayShape3D.new())
	_check_unavailable_footprint(definition, craft, "enabled_shape_unsupported_or_empty")
	unsupported.shape = null
	_check_unavailable_footprint(definition, craft, "enabled_shape_unavailable")
	unsupported.free()
	# Invalid empty/singular inputs stay outside the live PhysicsServer owner.
	_check(not resource._shape_bounds(ConvexPolygonShape3D.new(), Transform3D.IDENTITY).has_volume(), "empty convex geometry is explicitly unmeasurable before union")
	_check(not resource._valid_shape_transform(Transform3D(Basis(Vector3.ZERO, Vector3.UP, Vector3.BACK), Vector3.ZERO)), "singular child transform is rejected by the production transform gate")
	_check(not resource._valid_shape_transform(Transform3D(Basis.IDENTITY, Vector3(INF, 0, 0))), "nonfinite child transform is rejected by the production transform gate")
	second.free()
	first.disabled = true
	_check_unavailable_footprint(definition, craft, "no_enabled_root_shapes")
	craft.set("_destroyed", true)
	_check_unavailable_footprint(definition, craft, "live_craft_unavailable")
	craft.free()
	_check(resource.get_snapshot() == snapshot, "resource retains no live geometry and survives source node mutation and destruction")
	var roundtrip: Dictionary = JSON.parse_string(JSON.stringify(snapshot))
	_check(roundtrip.footprint.local_bounds == measured.local_bounds and roundtrip.footprint.shape_count == 2, "JSON round-trip retains numeric full bounds and count")
	roundtrip.footprint.local_bounds.size.x = 999.0
	_check(resource.get_snapshot().footprint.local_bounds.size.x == 13.0, "nested detached geometry mutations cannot alter resource")
	_check_literal_round_shapes(definition)


func _check_unavailable_footprint(definition: ShipDefinition, craft: HeroShip, reason: String) -> void:
	var snapshot := Registry.create_rated_budget(definition, craft).get_snapshot()
	_check(snapshot.valid and snapshot.footprint == {"status": "UNAVAILABLE", "reason": reason, "source": "actual_enabled_direct_root_collision_shapes"} and snapshot.missing_dimensions == EXPECTED_MISSING_DIMENSIONS, "unavailable footprint preserves missing data without invented zero: %s" % reason)


func _check_literal_round_shapes(definition: ShipDefinition) -> void:
	var craft := LiteralHull.new()
	craft.ship_definition = definition
	craft.ship_id = definition.get_ship_id()
	root.add_child(craft)
	var cylinder := CylinderShape3D.new()
	cylinder.radius = 2.0
	cylinder.height = 6.0
	var collision := _literal_shape(craft, cylinder, Transform3D(Basis(Vector3.FORWARD, PI / 4.0), Vector3(1,2,3)))
	var footprint: Dictionary = Registry.create_rated_budget(definition, craft).get_snapshot().footprint
	var side := 5.0 * sqrt(0.5)
	_check(footprint.status == "MEASURED" and is_equal_approx(footprint.local_bounds.size.x, side * 2.0) and is_equal_approx(footprint.local_bounds.size.y, side * 2.0) and is_equal_approx(footprint.local_bounds.size.z, 4.0), "rotated cylinder uses circular support extent rather than enclosing box corners")
	var sphere := SphereShape3D.new()
	sphere.radius = 2.0
	collision.shape = sphere
	footprint = Registry.create_rated_budget(definition, craft).get_snapshot().footprint
	_check(footprint.status == "MEASURED" and is_equal_approx(footprint.local_bounds.size.x, 4.0) and is_equal_approx(footprint.local_bounds.size.y, 4.0), "rotated sphere remains exact four-metre diameter")
	var capsule := CapsuleShape3D.new()
	capsule.radius = 1.0
	capsule.height = 6.0
	collision.shape = capsule
	footprint = Registry.create_rated_budget(definition, craft).get_snapshot().footprint
	_check(footprint.status == "MEASURED" and is_equal_approx(footprint.local_bounds.size.x, 2.0 + 4.0 * sqrt(0.5)) and is_equal_approx(footprint.local_bounds.size.z, 2.0), "rotated capsule uses sphere plus segment support extent")
	craft.free()


func _check_pilot_budget_detachment() -> void:
	var definition := DEFINITIONS[0].duplicate(true) as ShipDefinition
	var craft := LiteralHull.new()
	craft.ship_definition = definition
	craft.ship_id = definition.get_ship_id()
	root.add_child(craft)
	var profile := {"damage": 34.0, "range": 360.0, "origin_tolerance": 24.0}
	var source := {"ship_id": "torrent_provisional", "status": "SOURCED", "selected_context": "combat",
		"profiles": {"combat": {"weapon_id": "literal_combat", "resolver_profile": profile},
			"tutorial_range": {"weapon_id": "literal_range", "resolver_profile": {"damage": 50.0, "range": 360.0, "origin_tolerance": 24.0}}},
		"constraints": craft.get_pilot_weapon_constraints()}
	var resource := Registry.create_rated_budget(definition, craft, source)
	var snapshot := resource.get_snapshot()
	_check(snapshot.pilot_weapon.status == "SOURCED" and snapshot.pilot_weapon.contexts.size() == 2, "literal detached source retains both pilot contexts")
	_check(RatedBudgetType.valid_pilot_weapon(JSON.parse_string(JSON.stringify(snapshot.pilot_weapon)), "torrent_provisional"), "all pilot quantities survive JSON roundtrip")
	var fields: Dictionary = snapshot.pilot_weapon.contexts.combat.fields
	for axis: String in ["damage", "range", "cooldown", "warmup", "heatlockout", "minimum_operators"]:
		var field: Dictionary = fields[axis]
		var expected := float(field.raw) / (1.0 + float(field.raw)) if axis in ["damage", "range"] else 1.0 / (1.0 + float(field.raw))
		_check(field.normalized == expected and field.unit_scale == 1.0, "literal pilot directed indices use fixed unit-one benefit/cost curves")
	_check(fields.ammo_capacity.unbounded and fields.ammo_capacity.normalized == 1.0 and not fields.ammo_capacity.has("raw"), "unbounded ammo carries explicit flag and no numeric Infinity or fake zero")
	for patch: Dictionary in [{"ship_id": "wrong"}, {"constraints": {"live": craft}}, {"profiles": []}, {"selected_context": "unknown"}]:
		var malformed := source.duplicate(true)
		malformed.merge(patch, true)
		_check(Registry.create_rated_budget(definition, craft, malformed).get_snapshot().pilot_weapon.status == "UNAVAILABLE", "invalid or object-bearing pilot source fails closed without retaining authority")
	for metadata: String in ["ship_id", "status", "selected_context"]:
		for bad: Variant in [[], {}, {"nested": []}, [{"nested": []}]]:
			var malformed := source.duplicate(true)
			malformed[metadata] = bad
			_check(Registry.create_rated_budget(definition, craft, malformed).get_snapshot().pilot_weapon.status == "UNAVAILABLE", "heterogeneous pilot source metadata refuses before comparison")
	for metadata: String in ["model", "refill_rule", "weapon_id"]:
		for bad: Variant in [[], {}, {"nested": []}, [{"nested": []}]]:
			var malformed := source.duplicate(true)
			if metadata == "model":
				malformed.constraints.thermal.model = bad
			elif metadata == "refill_rule":
				malformed.constraints.refill_rule = bad
			else:
				malformed.profiles.combat.weapon_id = bad
			_check(Registry.create_rated_budget(definition, craft, malformed).get_snapshot().pilot_weapon.status == "UNAVAILABLE", "heterogeneous nested pilot source metadata refuses before comparison")
	_check(Registry.create_rated_budget(definition, craft).get_snapshot().pilot_weapon.status == "UNAVAILABLE", "live craft without authority source is unavailable rather than inferred from definition")
	var scatter := source.duplicate(true)
	scatter.profiles.combat.resolver_profile = {"damage": 14.0, "trigger_damage": 42.0, "range": 180.0, "origin_tolerance": 24.0, "spread_degrees": 3.0, "pellet_count": 3}
	var scatter_pilot: Dictionary = Registry.create_rated_budget(definition, craft, scatter).get_snapshot().pilot_weapon
	_check(scatter_pilot.contexts.combat.fields.damage.raw == 42.0 and scatter_pilot.contexts.combat.fields.range.raw == 180.0 and scatter_pilot.contexts.combat.fields.damage.source.ends_with("trigger_damage"), "scatter reports actual trigger budget and resolver range rather than one pellet or convergence")
	var wrong_definition := definition.duplicate(true) as ShipDefinition
	_check(Registry.create_rated_budget(wrong_definition, craft, source).get_snapshot().pilot_weapon.status == "UNAVAILABLE", "pilot report requires the exact live definition identity")
	craft.set("_destroyed", true)
	_check(Registry.create_rated_budget(definition, craft, source).get_snapshot().pilot_weapon.status == "UNAVAILABLE", "destroyed craft cannot publish a usable pilot weapon configuration")
	craft.set("_destroyed", false)
	var frozen := resource.get_snapshot()
	source.constraints.cooldown = 9.0
	source.profiles.combat.resolver_profile.damage = 999.0
	snapshot.pilot_weapon.contexts.combat.fields.damage.raw = 999.0
	craft.free()
	_check(resource.get_snapshot() == frozen, "pilot snapshot is frozen after input mutation and craft destruction/free")


func _check_boarding_budget() -> void:
	var definition := DEFINITIONS[0].duplicate(true) as ShipDefinition
	var craft := LiteralHull.new()
	craft.ship_definition = definition
	craft.ship_id = definition.get_ship_id()
	var ledger := ShipComponentDamage.new()
	ledger.configure(AABB(Vector3(-1, -1, -1), Vector3(2, 2, 2)), definition.maximum_hull)
	craft.set("_component_damage", ledger)
	craft.add_child(ledger)
	root.add_child(craft)
	var observation := {"status": "MEASURED", "source": "ordinary_E_to_settled_pilot", "ship_id": "torrent_provisional",
		"craft_instance_id": craft.get_instance_id(), "player_instance_id": 123, "transition_generation": 1,
		"lifecycle_generation": craft.get_component_damage().get_ledger_generation(), "started_usec": 1000000,
		"settled_usec": 3500000, "seconds": 2.5, "context": {"home_berth_id": "central_berth", "closed_canopy": true,
			"healthy": true, "offline": true, "default_handoff": true, "fresh_home": true, "input": "physical_E"}}
	var resource := Registry.create_rated_budget(definition, craft, {}, observation)
	var budget := resource.get_snapshot()
	_check(budget.boarding_time.status == "MEASURED" and budget.boarding_time.field.raw == 2.5
		and budget.boarding_time.field.normalized == 1.0 / 3.5 and not budget.missing_dimensions.has("boarding_time")
		and budget.qualification == &"NOT_QUALIFIED", "literal resource interval uses seconds/cost index without qualifying remaining role dimensions")
	_check(RatedBudgetType.valid_boarding_time(JSON.parse_string(JSON.stringify(budget.boarding_time)), "torrent_provisional"), "boarding observation and index survive detached JSON roundtrip")
	_check(Registry.create_rated_budget(definition, craft).get_snapshot().boarding_time.status == "UNKNOWN", "missing observation never becomes zero seconds")
	for key: String in observation:
		for bad: Variant in [null, [], {}, true, INF, NAN]:
			var malformed := observation.duplicate(true)
			malformed[key] = bad
			_check(Registry.create_rated_budget(definition, craft, {}, malformed).get_snapshot().boarding_time.status == "UNAVAILABLE", "heterogeneous boarding observation refuses before conversion: %s" % key)
	for patch: Dictionary in [{"seconds": 0.0}, {"seconds": -1.0}, {"seconds": 3.0}, {"craft_instance_id": 1}, {"lifecycle_generation": 999}, {"ship_id": "arrow_provisional"}, {"settled_usec": 1000000}]:
		var malformed := observation.duplicate(true)
		malformed.merge(patch, true)
		_check(Registry.create_rated_budget(definition, craft, {}, malformed).get_snapshot().boarding_time.status == "UNAVAILABLE", "inconsistent boarding identity/ticks/interval is unavailable")
	for key: String in observation.context:
		var malformed := observation.duplicate(true)
		malformed.context[key] = false
		_check(Registry.create_rated_budget(definition, craft, {}, malformed).get_snapshot().boarding_time.status == "UNAVAILABLE", "boarding context requires exact typed qualification: %s" % key)
	for patch: Dictionary in [{"raw": true}, {"raw": NAN}, {"unit": "ms"}, {"direction": "benefit"}, {"source": "tooltip"}, {"normalized": 0.1}, {"unit_scale": 1000.0}]:
		var malformed: Dictionary = budget.boarding_time.duplicate(true)
		malformed.field.merge(patch, true)
		_check(not RatedBudgetType.valid_boarding_time(malformed, "torrent_provisional"), "whole boarding payload validates raw/index/units/source before presentation")
	var frozen := resource.get_snapshot()
	observation.context.healthy = false
	budget.boarding_time.field.raw = 99.0
	craft.free()
	_check(resource.get_snapshot() == frozen, "boarding resource retains detached observation after caller mutation and craft release")


func _check_cargo_budget() -> void:
	var definition := load("res://assets/ships/titan_provisional.tres") as ShipDefinition
	var craft := LiteralHull.new()
	craft.ship_definition = definition
	craft.ship_id = definition.get_ship_id()
	root.add_child(craft)
	var projection := {"status": "SOURCED", "source": "actual_titan_parcel_custody_and_transfer", "ship_id": "titan_provisional",
		"craft_instance_id": craft.get_instance_id(), "custody_instance_id": 123, "authority_instance_id": 124,
		"manifest_id": "titan_cargo_manifest", "manifest_generation": 1, "owner_generation": 1,
		"item_id": "titan_repair_kit_parcel", "capacity": 4, "aboard": 2, "free": 2, "locker": 2,
		"handoff": {"load_panel_instance_id": 125, "return_panel_instance_id": 126, "quantity": 1,
			"load": "supply_locker", "return": "parcel_hold", "conditions": "on_foot_at_own_offline_home"}}
	var resource := Registry.create_rated_budget(definition, craft, {}, {}, projection)
	var frozen := resource.get_snapshot()
	_check(frozen.cargo.status == "SOURCED" and frozen.cargo.field.raw == 4.0 and frozen.cargo.field.normalized == 0.8
		and frozen.cargo.projection.aboard == 2 and frozen.cargo.projection.free == 2 and frozen.cargo.projection.locker == 2
		and frozen.missing_dimensions.has("cargo") and frozen.qualification == &"NOT_QUALIFIED", "parcel capacity4/.8 is separate from conserved2/2 stock and incomplete full cargo")
	_check(RatedBudgetType.valid_cargo(JSON.parse_string(JSON.stringify(frozen.cargo)), "titan_provisional"), "parcel projection survives exact detached JSON roundtrip")
	_check(Registry.create_rated_budget(definition, craft).get_snapshot().cargo.status == "UNKNOWN", "missing parcel source remains unknown without numeric zeros")
	for key: String in projection:
		for bad: Variant in [null, [], {}, true, INF, NAN]:
			var malformed := projection.duplicate(true)
			malformed[key] = bad
			_check(Registry.create_rated_budget(definition, craft, {}, {}, malformed).get_snapshot().cargo.status == "UNAVAILABLE", "malformed parcel projection refuses before comparison: %s" % key)
	for key: String in projection.handoff:
		var malformed := projection.duplicate(true)
		malformed.handoff[key] = []
		_check(Registry.create_rated_budget(definition, craft, {}, {}, malformed).get_snapshot().cargo.status == "UNAVAILABLE", "malformed parcel handoff refuses atomically: %s" % key)
	for patch: Dictionary in [{"capacity": 5}, {"aboard": -1}, {"free": 0}, {"locker": 0}, {"manifest_id": "wrong"}, {"item_id": "repair_kit"}, {"craft_instance_id": 1}, {"ship_id": "torrent_provisional"}]:
		var malformed := projection.duplicate(true)
		malformed.merge(patch, true)
		_check(Registry.create_rated_budget(definition, craft, {}, {}, malformed).get_snapshot().cargo.status == "UNAVAILABLE", "parcel identity/capacity/stock consistency is exact")
	projection.aboard = 4
	var detached := resource.get_snapshot()
	detached.cargo.field.raw = 99.0
	craft.free()
	_check(resource.get_snapshot() == frozen, "parcel resource keeps no live craft reference and detaches all nested values")
