extends SceneTree

const AdapterScript := preload("res://scripts/world/planetary_return_berth_adapter.gd")
const BerthScript := preload("res://scripts/world/ship_berth.gd")
const ARROW_DEFINITION := preload("res://assets/ships/arrow_provisional.tres")
const BindingScript := preload("res://scripts/world/ember_surface_loop_production_binding.gd")

class FakeLandingReturnContract:
	var calls := 0
	func confirm_orbit_return(_confirmed: bool, target: StringName, _observation: Dictionary, run_generation: int, attachment_generation: int) -> Dictionary:
		calls += 1
		return {"accepted": target == &"mudds_shipyards", "reason": &"completed", "run_generation": run_generation, "attachment_generation": attachment_generation}


class PhysicalArrivalShip extends Node3D:
	var home_berth_id: StringName = &"arrow_recon_berth"
	var attachment_report: Dictionary = {}

	func get_home_berth_id() -> StringName:
		return home_berth_id

	func get_ship_id() -> StringName:
		return &"arrow_provisional"

	func get_planetary_cruise_attachment_report() -> Dictionary:
		return attachment_report.duplicate(true)

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var checks := {
		"legacy": _test_legacy_contract_path(),
		"physical_happy": _test_physical_arrival_happy_path(),
		"adoption_fences": _test_physical_arrival_adoption_fences(),
		"live_berth_fences": _test_physical_arrival_live_berth_fences(),
		"generation_retry_fences": _test_physical_arrival_generation_and_retry_fences(),
	}
	var valid := true
	for check_name: String in checks:
		if not bool(checks[check_name]):
			push_error("planetary return berth adapter check failed: %s" % check_name)
			valid = false
	var binding := BindingScript.new()
	valid = binding.has_method(&"request_planetary_return_berth") \
			and binding.has_method(&"confirm_planetary_return_berth_occupied") \
			and binding.has_method(&"complete_planetary_return_contract") \
			and binding.has_method(&"retire_planetary_return") and valid
	binding.free()
	await process_frame
	if not valid:
		push_error("planetary return berth adapter failed")
		quit(1)
		return
	print("PLANETARY_RETURN_BERTH_ADAPTER_TEST_OK: legacy and adopt-only physical arrival")
	quit(0)


func _test_legacy_contract_path() -> bool:
	var berth := BerthScript.new()
	berth.berth_id = &"mudds_return_berth"
	var ship := Node.new()
	root.add_child(berth)
	root.add_child(ship)
	var adapter := AdapterScript.new()
	var receipt := {"accepted": true, "return_target_id": &"mudds_shipyards"}
	var requested := adapter.request(receipt, berth, ship, ARROW_DEFINITION, 11, 22, 4, 6)
	var occupied := adapter.confirm_occupied({"accepted": true, "strict_dock_acceptance": true})
	var duplicate := adapter.confirm_occupied({"accepted": true, "strict_dock_acceptance": true})
	var contract := FakeLandingReturnContract.new()
	var foreign := occupied.duplicate(true)
	foreign.token = &"foreign"
	var foreign_result := adapter.complete_return_contract(foreign, contract, {"position": Vector3.ZERO})
	var returned := adapter.complete_return_contract(occupied, contract, {"position": Vector3.ZERO})
	var returned_duplicate := adapter.complete_return_contract(occupied, contract, {"position": Vector3.ZERO})
	var reset := adapter.reset()
	var retired := adapter.retire(5)
	var second_request := adapter.request(receipt, berth, ship, ARROW_DEFINITION, 11, 22, 5, 7)
	var second_occupied := adapter.confirm_occupied({"accepted": true, "strict_dock_acceptance": true})
	var stale_first_receipt := adapter.complete_return_contract(occupied, contract, {"position": Vector3.ZERO})
	var valid: bool = requested.accepted and occupied.accepted \
			and not duplicate.accepted and reset.accepted \
			and not foreign_result.accepted and returned.accepted \
			and not returned_duplicate.accepted and contract.calls == 1 \
			and retired.accepted and int(retired.attachment_generation) == 7 \
			and second_request.accepted and second_occupied.accepted \
			and not stale_first_receipt.accepted \
			and berth.is_occupied() == true \
			and occupied.berth_id == &"mudds_return_berth"
	ship.free()
	berth.free()
	return valid


func _test_physical_arrival_happy_path() -> bool:
	var fixture := _new_physical_fixture("Happy", 40)
	var adapter := AdapterScript.new()
	var ship := fixture.ship as PhysicalArrivalShip
	var berth := fixture.berth as ShipBerth
	var shell := _shell_receipt(ship, 17, 23)
	var parent_before := ship.get_parent()
	var transform_before: Transform3D = ship.transform
	var berth_parent_before := berth.get_parent()
	var token_before := berth.get_reservation_token(ship)
	var adopted := adapter.adopt_physical_arrival(
		shell, 17, 23, 9, 6, berth, ship, ARROW_DEFINITION,
		token_before, 501, ship.get_instance_id()
	)
	var adoption_did_not_mutate: bool = ship.get_parent() == parent_before \
			and ship.transform == transform_before \
			and berth.get_parent() == berth_parent_before \
			and berth.get_reservation_token(ship) == token_before \
			and berth.get_occupant() == null
	var occupied_by_owner := berth.occupy(ship, token_before)
	ship.attachment_report = _hero_report(ship, 41, false, false, &"landing_completed")
	var evidence := _landing_evidence(berth, ARROW_DEFINITION.ship_id)
	var confirmed := adapter.confirm_physical_arrival(evidence, 17, 23, 9, 6)
	var terminal := adapter.complete_physical_arrival(confirmed, 17, 23, 9, 6)
	var replay := adapter.complete_physical_arrival(confirmed, 17, 23, 9, 6)
	var contract := terminal.get("contract_receipt", {}) as Dictionary
	var authority := contract.get("authority", {}) as Dictionary
	var valid: bool = bool(adopted.get("accepted", false)) \
			and adopted.get("reason") == &"physical_arrival_adopted" \
			and adoption_did_not_mutate and occupied_by_owner \
			and bool(confirmed.get("accepted", false)) \
			and confirmed.get("reason") == &"return_berth_occupied" \
			and bool(terminal.get("accepted", false)) \
			and terminal.get("reason") == &"returned_to_station" \
			and contract.get("reason") == &"physical_station_arrival_completed" \
			and int(contract.get("hero_attachment_generation", 0)) == 41 \
			and not bool(authority.get("movement", true)) \
			and not bool(authority.get("teleport", true)) \
			and not bool(authority.get("reparent", true)) \
			and not bool(authority.get("berth", true)) \
			and not bool(authority.get("reservation", true)) \
			and not bool(authority.get("occupancy", true)) \
			and not bool(authority.get("release", true)) \
			and not bool(authority.get("reward", true)) \
			and not bool(replay.get("accepted", true)) \
			and berth.get_reservation_token(ship) == token_before \
			and berth.get_occupant() == ship \
			and ship.get_parent() == parent_before
	(fixture.root as Node).free()
	return valid


func _test_physical_arrival_adoption_fences() -> bool:
	var wrong_home := _new_physical_fixture("WrongHome", 50)
	(wrong_home.ship as PhysicalArrivalShip).home_berth_id = &"central_berth"
	var wrong_adapter := AdapterScript.new()
	var wrong_result := _adopt_fixture(wrong_adapter, wrong_home, 17, 23, 9, 6)
	var valid: bool = not bool(wrong_result.get("accepted", true)) \
			and wrong_result.get("reason") == &"physical_arrival_wrong_home_berth"
	(wrong_home.root as Node).free()

	var stale_shell := _new_physical_fixture("StaleShell", 51)
	var stale_shell_adapter := AdapterScript.new()
	var stale_shell_result := _adopt_fixture(
		stale_shell_adapter, stale_shell, 18, 23, 9, 6
	)
	valid = not bool(stale_shell_result.get("accepted", true)) \
			and stale_shell_result.get("reason") == &"physical_arrival_shell_stale" \
			and valid
	(stale_shell.root as Node).free()

	var stale_frame := _new_physical_fixture("StaleFrame", 52)
	var stale_frame_adapter := AdapterScript.new()
	var stale_frame_shell := _shell_receipt(stale_frame.ship, 17, 22)
	var stale_frame_result := stale_frame_adapter.adopt_physical_arrival(
		stale_frame_shell, 17, 23, 9, 6, stale_frame.berth, stale_frame.ship,
		ARROW_DEFINITION, stale_frame.token, 501,
		(stale_frame.ship as Node).get_instance_id()
	)
	valid = not bool(stale_frame_result.get("accepted", true)) \
			and stale_frame_result.get("reason") == &"physical_arrival_shell_stale" \
			and valid
	(stale_frame.root as Node).free()

	var no_lease := _new_physical_fixture("NoLease", 53)
	(no_lease.berth as ShipBerth).release(no_lease.ship, no_lease.token)
	var no_lease_result := _adopt_fixture(
		AdapterScript.new(), no_lease, 17, 23, 9, 6
	)
	valid = not bool(no_lease_result.get("accepted", true)) \
			and no_lease_result.get("reason") \
				== &"physical_arrival_existing_lease_invalid" and valid
	(no_lease.root as Node).free()
	return valid


func _test_physical_arrival_live_berth_fences() -> bool:
	var moved := _new_physical_fixture("Moved", 60)
	var moved_adapter := AdapterScript.new()
	var moved_adopted := _adopt_fixture(moved_adapter, moved, 17, 23, 9, 6)
	var moved_evidence := _landing_evidence(moved.berth, ARROW_DEFINITION.ship_id)
	(moved.berth as ShipBerth).position += Vector3(1.0, 0.0, 0.0)
	(moved.berth as ShipBerth).occupy(moved.ship, moved.token)
	(moved.ship as PhysicalArrivalShip).attachment_report = _hero_report(
		moved.ship, 61, false, false, &"landing_completed"
	)
	var moved_result := moved_adapter.confirm_physical_arrival(
		moved_evidence, 17, 23, 9, 6
	)
	var valid: bool = bool(moved_adopted.get("accepted", false)) \
			and not bool(moved_result.get("accepted", true)) \
			and moved_result.get("reason") == &"physical_arrival_berth_changed"
	if not valid:
		push_error("moved berth fence failed: adopted=%s result=%s" % [moved_adopted, moved_result])
	(moved.root as Node).free()

	var reparented := _new_physical_fixture("Reparented", 62, true)
	var reparented_adapter := AdapterScript.new()
	var reparented_adopted := _adopt_fixture(
		reparented_adapter, reparented, 17, 23, 9, 6
	)
	var reparented_evidence := _landing_evidence(
		reparented.berth, ARROW_DEFINITION.ship_id
	)
	(reparented.berth as Node).reparent(reparented.second_parent as Node, true)
	(reparented.berth as ShipBerth).occupy(reparented.ship, reparented.token)
	(reparented.ship as PhysicalArrivalShip).attachment_report = _hero_report(
		reparented.ship, 63, false, false, &"landing_completed"
	)
	var reparented_result := reparented_adapter.confirm_physical_arrival(
		reparented_evidence, 17, 23, 9, 6
	)
	var reparented_valid: bool = bool(reparented_adopted.get("accepted", false)) \
			and not bool(reparented_result.get("accepted", true)) \
			and reparented_result.get("reason") \
				== &"physical_arrival_berth_changed"
	if not reparented_valid:
		push_error("reparented berth fence failed: adopted=%s result=%s" % [reparented_adopted, reparented_result])
	valid = reparented_valid and valid
	(reparented.root as Node).free()

	var reissued := _new_physical_fixture("Reissued", 64)
	var reissued_adapter := AdapterScript.new()
	var reissued_adopted := _adopt_fixture(
		reissued_adapter, reissued, 17, 23, 9, 6
	)
	(reissued.berth as ShipBerth).release(reissued.ship, reissued.token)
	var new_token := (reissued.berth as ShipBerth).try_reserve(
		reissued.ship, ARROW_DEFINITION
	)
	(reissued.berth as ShipBerth).occupy(reissued.ship, new_token)
	(reissued.ship as PhysicalArrivalShip).attachment_report = _hero_report(
		reissued.ship, 65, false, false, &"landing_completed"
	)
	var reissued_result := reissued_adapter.confirm_physical_arrival(
		_landing_evidence(reissued.berth, ARROW_DEFINITION.ship_id),
		17, 23, 9, 6
	)
	var reissued_valid: bool = bool(reissued_adopted.get("accepted", false)) \
			and new_token != reissued.token \
			and not bool(reissued_result.get("accepted", true)) \
			and reissued_result.get("reason") \
				== &"physical_arrival_lease_changed"
	if not reissued_valid:
		push_error("reissued lease fence failed: adopted=%s old=%s new=%s result=%s" % [reissued_adopted, reissued.token, new_token, reissued_result])
	valid = reissued_valid and valid
	(reissued.root as Node).free()
	return valid


func _test_physical_arrival_generation_and_retry_fences() -> bool:
	var identities := _new_physical_fixture("Identities", 70)
	var identity_adapter := AdapterScript.new()
	var adopted := _adopt_fixture(identity_adapter, identities, 17, 23, 9, 6)
	(identities.berth as ShipBerth).occupy(identities.ship, identities.token)
	(identities.ship as PhysicalArrivalShip).attachment_report = _hero_report(
		identities.ship, 71, false, false, &"landing_completed"
	)
	var evidence := _landing_evidence(identities.berth, ARROW_DEFINITION.ship_id)
	var stale_shell := identity_adapter.confirm_physical_arrival(
		evidence, 18, 23, 9, 6
	)
	var stale_frame := identity_adapter.confirm_physical_arrival(
		evidence, 17, 24, 9, 6
	)
	var stale_session := identity_adapter.confirm_physical_arrival(
		evidence, 17, 23, 10, 6
	)
	var stale_attachment := identity_adapter.confirm_physical_arrival(
		evidence, 17, 23, 9, 7
	)
	var valid: bool = bool(adopted.get("accepted", false)) \
			and stale_shell.get("reason") == &"physical_arrival_shell_stale" \
			and stale_frame.get("reason") == &"physical_arrival_frame_stale" \
			and stale_session.get("reason") == &"physical_arrival_session_stale" \
			and stale_attachment.get("reason") \
				== &"physical_arrival_attachment_stale"
	(identities.root as Node).free()

	var retry := _new_physical_fixture("Retry", 72)
	var retry_adapter := AdapterScript.new()
	var first_adopt := _adopt_fixture(retry_adapter, retry, 17, 23, 9, 6)
	var retry_token := (retry.berth as ShipBerth).get_reservation_token(retry.ship)
	var aborted := retry_adapter.abort_physical_arrival(&"landing_aborted")
	(retry.ship as PhysicalArrivalShip).attachment_report = _hero_report(
		retry.ship, 74, true, false, &"landing_started"
	)
	var second_adopt := _adopt_fixture(retry_adapter, retry, 17, 23, 9, 6)
	valid = bool(first_adopt.get("accepted", false)) \
			and bool(aborted.get("accepted", false)) \
			and not bool(aborted.get("lease_mutated", true)) \
			and (retry.berth as ShipBerth).get_reservation_token(retry.ship) \
				== retry_token \
			and bool(second_adopt.get("accepted", false)) and valid
	(retry.root as Node).free()

	var destroyed := _new_physical_fixture("Destroyed", 80)
	var destroyed_adapter := AdapterScript.new()
	var destruction_adopted := _adopt_fixture(
		destroyed_adapter, destroyed, 17, 23, 9, 6
	)
	(destroyed.berth as ShipBerth).occupy(destroyed.ship, destroyed.token)
	(destroyed.ship as PhysicalArrivalShip).attachment_report = _hero_report(
		destroyed.ship, 81, false, true, &"ship_destroyed"
	)
	var destruction_result := destroyed_adapter.confirm_physical_arrival(
		_landing_evidence(destroyed.berth, ARROW_DEFINITION.ship_id),
		17, 23, 9, 6
	)
	valid = bool(destruction_adopted.get("accepted", false)) \
			and not bool(destruction_result.get("accepted", true)) \
			and destruction_result.get("reason") \
				== &"physical_arrival_hero_generation_mismatch" and valid
	(destroyed.root as Node).free()

	var reentered := _new_physical_fixture("Reentered", 82)
	var reentry_adapter := AdapterScript.new()
	var reentry_adopted := _adopt_fixture(
		reentry_adapter, reentered, 17, 23, 9, 6
	)
	(reentered.berth as ShipBerth).occupy(reentered.ship, reentered.token)
	(reentered.ship as PhysicalArrivalShip).attachment_report = _hero_report(
		reentered.ship, 83, false, false, &"ship_detached"
	)
	var reentry_result := reentry_adapter.confirm_physical_arrival(
		_landing_evidence(reentered.berth, ARROW_DEFINITION.ship_id),
		17, 23, 9, 6
	)
	valid = bool(reentry_adopted.get("accepted", false)) \
			and not bool(reentry_result.get("accepted", true)) \
			and reentry_result.get("reason") \
				== &"physical_arrival_hero_generation_mismatch" and valid
	(reentered.root as Node).free()
	return valid


func _new_physical_fixture(
		label: String, hero_generation: int, two_parents: bool = false
	) -> Dictionary:
	var fixture_root := Node.new()
	fixture_root.name = "Physical%s" % label
	root.add_child(fixture_root)
	var first_parent := Node3D.new()
	first_parent.name = "BerthParentA"
	fixture_root.add_child(first_parent)
	var second_parent: Node3D
	if two_parents:
		second_parent = Node3D.new()
		second_parent.name = "BerthParentB"
		fixture_root.add_child(second_parent)
	var berth := BerthScript.new()
	berth.name = "ArrowHomeBerth"
	berth.berth_id = &"arrow_recon_berth"
	berth.compatibility_tags = PackedStringArray(["recon"])
	first_parent.add_child(berth)
	var ship := PhysicalArrivalShip.new()
	ship.name = "PhysicalArrow"
	fixture_root.add_child(ship)
	ship.attachment_report = _hero_report(
		ship, hero_generation, true, false, &"landing_started"
	)
	var token := berth.try_reserve(ship, ARROW_DEFINITION)
	return {
		"root": fixture_root,
		"first_parent": first_parent,
		"second_parent": second_parent,
		"berth": berth,
		"ship": ship,
		"token": token,
	}


func _adopt_fixture(
		adapter: RefCounted, fixture: Dictionary,
		shell_generation: int, frame_generation: int,
		session_generation: int, attachment_generation: int
	) -> Dictionary:
	var ship := fixture.ship as PhysicalArrivalShip
	return adapter.call(
		&"adopt_physical_arrival",
		_shell_receipt(ship, 17, 23), shell_generation, frame_generation,
		session_generation, attachment_generation, fixture.berth, ship,
		ARROW_DEFINITION, fixture.token, 501, ship.get_instance_id()
	) as Dictionary


func _shell_receipt(
		ship: Node, shell_generation: int, frame_generation: int
	) -> Dictionary:
	return {
		"accepted": true,
		"reason": &"return_approach_handoff_ready",
		"generation": shell_generation,
		"target_generation": 3,
		"coordinate_frame_generation": frame_generation,
		"ship_instance_id": ship.get_instance_id(),
		"released_ship_attachment_generation": 39,
		"home_target_id": &"mudds_shipyards",
		"controller_release": {"accepted": true, "reason": &"disengaged"},
		"controller_completion": {
			"accepted": true,
			"reason": &"return_approach_completed",
			"target_generation": 3,
			"coordinate_frame_generation": frame_generation,
			"ship_instance_id": ship.get_instance_id(),
			"target": {"home_target_id": &"mudds_shipyards"},
			"measurement": {
				"accepted": true,
				"inside_brake_complete_shell": true,
				"full_flyable_fleet_corridor_proven": true,
			},
		},
	}.duplicate(true)


func _hero_report(
		ship: Node, generation: int, landing_active: bool,
		destroyed: bool, reason: StringName
	) -> Dictionary:
	return {
		"ship_instance_id": ship.get_instance_id(),
		"ship_attachment_generation": generation,
		"controller_instance_id": 0,
		"attached": false,
		"inside_tree": ship.is_inside_tree(),
		"piloted": true,
		"destroyed": destroyed,
		"landing_active": landing_active,
		"reason": reason,
	}.duplicate(true)


func _landing_evidence(berth: ShipBerth, ship_id: StringName) -> Dictionary:
	var berth_parent := berth.get_parent()
	return {
		"active": false,
		"phase": &"docked",
		"contract_accepted": true,
		"strict_dock_acceptance": true,
		"berth_id": berth.get_berth_id(),
		"berth_instance_id": berth.get_instance_id(),
		"berth_parent_instance_id": (
			berth_parent.get_instance_id() if is_instance_valid(berth_parent) else 0
		),
		"reserved_ship_id": ship_id,
		"reservation_token_bound": true,
		"dock_transform_snapshot": berth.get_dock_transform(),
		"landing_half_extents_snapshot": berth.get_landing_half_extents(),
	}.duplicate(true)
