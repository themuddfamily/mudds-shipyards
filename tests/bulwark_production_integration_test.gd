extends SceneTree

const WORLD_SCENE := preload("res://scenes/world/shipyard_world.tscn")
const SHIP_SCENE := preload("res://scenes/ships/bulwark_heavy_gunship.tscn")

var _checks := 0
var _failures := 0


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var world := WORLD_SCENE.instantiate() as ShipyardWorld
	_check(world != null, "production world instantiates with Fleet Dock 03")
	if world == null:
		_finish()
		return
	root.add_child(world)
	await process_frame
	await physics_frame
	await physics_frame

	var ship := SHIP_SCENE.instantiate() as HeroShip
	_check(ship != null, "Bulwark production scene instantiates as a HeroShip")
	if ship == null:
		world.queue_free()
		_finish()
		return
	root.add_child(ship)
	await process_frame
	await physics_frame

	_test_production_identity(ship)
	_test_dock_three(world, ship)
	_test_berth_contract(world, ship)

	ship.queue_free()
	world.queue_free()
	await process_frame
	_finish()


func _test_production_identity(ship: HeroShip) -> void:
	var definition := ship.get_ship_definition()
	_check(definition != null and definition.is_definition_valid(), "Bulwark production scene owns a valid definition")
	if definition == null:
		return
	_check(definition.get_ship_id() == &"bulwark_heavy_gunship", "production identity is the stable Bulwark ID")
	_check(definition.get_evidence_status_id() == &"new", "production definition remains EvidenceStatus.NEW")
	_check(definition.evidence_references.is_empty(), "production definition carries no historical references")
	_check(not definition.is_historical_claim(), "production definition makes no historical claim")
	_check(definition.get_compatibility_tags().has(&"bulwark_gunship"), "production definition publishes a dedicated berth tag")
	var audit: Dictionary = ship.call("get_bulwark_audit_report")
	_check(bool(audit.get("valid", false)), "production Bulwark passes its component audit")


func _test_dock_three(world: ShipyardWorld, ship: HeroShip) -> void:
	var module := world.get_fleet_dock_comb()
	var assigned := module.get_assigned_dock_roster()
	var dock_three := _find_dock(assigned, &"deferred-dock-03")
	_check(assigned.size() == 3 and module.get_deferred_dock_roster().is_empty(), "Fleet Dock 03 is the third assigned modern dock")
	_check(
		dock_three.get("ship_assignment", &"") == &"bulwark_heavy_gunship"
		and dock_three.get("berth_id", &"") == &"bulwark_fleet_dock_berth"
		and not bool(dock_three.get("historical_class_to_berth_mapping", true)),
		"Dock 03 assigns Bulwark without creating a historical class mapping"
	)
	var report: Dictionary = world.get_fleet_dock_comb_integration_audit_report()
	_check(bool(report.get("valid", false)), "world integration audit accepts all three modern dock assignments")
	_check(int(report.get("external_assignment_count", 0)) == 3 and int(report.get("deferred_empty_dock_count", -1)) == 0, "world audit reports three assigned and zero deferred docks")
	_check(report.get("bulwark_ship_id", &"") == &"bulwark_heavy_gunship", "world audit exposes the Bulwark production identity")
	_check(ship.get_home_berth_id() == &"bulwark_fleet_dock_berth", "Bulwark home berth matches Dock 03")


func _test_berth_contract(world: ShipyardWorld, ship: HeroShip) -> void:
	var berth := world.get_berth_node(&"bulwark_fleet_dock_berth")
	_check(berth != null, "world owns the Bulwark physical berth")
	if berth == null:
		return
	_check(berth.get_parent() == world, "Bulwark berth is world-owned rather than comb-owned")
	_check(berth.is_compatible_with(ship.get_ship_definition()), "Dock 03 accepts the Bulwark definition")
	var clearance: Dictionary = ship.call("get_berth_clearance_report")
	var bounds := clearance.get("flight_collision_bounds", AABB()) as AABB
	var dock_transform := berth.get_dock_transform()
	_check(berth.contains_oriented_bounds(dock_transform, bounds), "Bulwark collision envelope fits the strict Dock 03 landing volume")
	_check(bool(clearance.get("physical_boarding_contract", false)), "Bulwark publishes a physical boarding contract")
	_check(clearance.get("recovery_contract", &"") == &"HeroShip.request_berth_landing", "recovery delegates to the shared HeroShip landing authority")
	var collision: Dictionary = ship.get_landing_collision_report()
	_check(bool(collision.get("valid", false)) and int(collision.get("shape_count", 0)) >= 3, "Bulwark publishes a valid root collision envelope for landing")
	var token := berth.try_reserve(ship, ship.get_ship_definition())
	_check(not token.is_empty() and berth.has_valid_lease(ship, token, ship.get_ship_id()), "Dock 03 issues a valid Bulwark berth lease")
	_check(berth.release(ship, token), "Bulwark berth lease releases cleanly")


func _find_dock(roster: Array[Dictionary], dock_id: StringName) -> Dictionary:
	for entry in roster:
		if entry.get("dock_id", &"") == dock_id:
			return entry
	return {}


func _finish() -> void:
	print("BULWARK_PRODUCTION_INTEGRATION: %d checks, %d failures" % [_checks, _failures])
	quit(1 if _failures > 0 else 0)


func _check(condition: bool, message: String) -> void:
	_checks += 1
	if condition:
		print("PASS: %s" % message)
	else:
		_failures += 1
		push_error("FAIL: %s" % message)
