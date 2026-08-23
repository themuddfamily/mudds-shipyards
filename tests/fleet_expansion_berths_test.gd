extends SceneTree

const Berths := preload("res://scripts/world/fleet_expansion_berths.gd")
const EXPECTED_PAD_IDS: Array[StringName] = [
	&"dock_04_cargo", &"dock_05_bomber", &"dock_06_interceptor"
]
const EXPECTED_PAD_POSITIONS: Array[Vector3] = [
	Vector3(-34.0, 0.0, -18.0), Vector3(34.0, 0.0, -18.0), Vector3(0.0, 0.0, 34.0)
]
const EXPECTED_PAD_SIZE := Vector3(28.0, 0.6, 42.0)
const EXPECTED_SERVICE_MESHES := [6, 5, 5]
const EXPECTED_SERVICE_ROLES: Array[StringName] = [
	&"cargo_crane_and_container_apron",
	&"ordnance_safe_gantry_markers",
	&"rapid_launch_guide_frame",
]

var _assertions := 0
var _failures: Array[String] = []


func _initialize() -> void:
	var berths := Berths.new()
	root.add_child(berths)
	await process_frame
	var audit := berths.get_audit_report()
	_check(bool(audit.get("valid", false)), "three expansion pads build within their geometry budget")
	_check(audit.get("evidence_status", &"") == &"NEW" and not bool(audit.get("historically_supported", true)), "the expansion makes no historical berth claim")
	_check(berths.get_pad_ids() == EXPECTED_PAD_IDS, "Dock 04 cargo, Dock 05 bomber, and Dock 06 interceptor are stable authored IDs")
	_test_service_presentations(berths, audit)
	for pad_id in berths.get_pad_ids():
		var contract := berths.get_landing_contract(pad_id)
		_check(bool(contract.get("accepted", false)) and (contract.get("landing_anchor", Vector3.INF) as Vector3).is_finite(), "landing contract is finite for %s" % pad_id)
		_check(not bool(contract.get("ship_authority", true)) and not bool(contract.get("berth_lease_authority", true)), "contract remains caller-owned for %s" % pad_id)
	var unknown := berths.get_landing_contract(&"dock_99")
	_check(not bool(unknown.get("accepted", true)), "unknown pad IDs fail closed")
	var craft := Node3D.new()
	craft.set_meta(&"evidence_status", &"NEW")
	root.add_child(craft)
	await process_frame
	var attached := berths.attach_craft(&"dock_04_cargo", craft, &"cinder_cargo_hauler")
	_check(bool(attached.get("accepted", false)) and craft.global_position == attached.get("landing_anchor", Vector3.INF), "Dock 04 accepts a NEW craft at its exact landing anchor")
	var duplicate := berths.attach_craft(&"dock_05_bomber", craft, &"cinder_cargo_hauler")
	_check(not bool(duplicate.get("accepted", true)) and duplicate.get("reason", &"") == &"craft_already_attached", "one craft cannot occupy multiple expansion pads")
	var foreign := Node3D.new()
	foreign.set_meta(&"evidence_status", &"NEW")
	root.add_child(foreign)
	await process_frame
	var foreign_detach := berths.detach_craft(&"dock_04_cargo", foreign)
	_check(not bool(foreign_detach.get("accepted", true)) and foreign_detach.get("reason", &"") == &"foreign_craft", "foreign detach requests fail closed")
	var detached := berths.detach_craft(&"dock_04_cargo", craft)
	_check(bool(detached.get("accepted", false)) and not bool(berths.get_attachment_snapshot(&"dock_04_cargo").get("attached", true)), "the owner detaches and clears a reusable pad")
	craft.queue_free()
	foreign.queue_free()
	berths.queue_free()
	await process_frame
	if _failures.is_empty():
		print("PASS fleet_expansion_berths_test (%d assertions)" % _assertions)
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _test_service_presentations(berths: Node3D, audit: Dictionary) -> void:
	var presentation: Dictionary = berths.call("get_service_presentation_audit")
	var budgets := presentation.get("budgets", {}) as Dictionary
	_check(
		bool(presentation.get("valid", false))
		and (presentation.get("errors", PackedStringArray()) as PackedStringArray).is_empty()
		and int(audit.get("static_bodies", -1)) == 3
		and int(audit.get("collision_shapes", -1)) == 3
		and int(audit.get("mesh_instances", -1)) == 19
		and int(audit.get("guide_lights", -1)) == 6
		and int(audit.get("descendants", -1)) == 46
		and int(budgets.get("static_bodies", -1)) == 3
		and int(budgets.get("collision_shapes", -1)) == 3
		and int(budgets.get("mesh_instances", -1)) == 19
		and int(budgets.get("guide_lights", -1)) == 6
		and int(budgets.get("descendants", -1)) == 46,
		"the three service silhouettes freeze at 19 meshes, 6 guide lights, 46 descendants, and the original 3 pad bodies/shapes"
	)
	var expected_bounds: Array[AABB] = [
		AABB(Vector3(-18.75, 0.0, -13.5), Vector3(40.25, 12.0, 27.0)),
		AABB(Vector3(-19.5, 0.0, -19.0), Vector3(39.0, 11.0, 17.0)),
		AABB(Vector3(-16.75, 0.0, -16.75), Vector3(33.5, 10.5, 40.75)),
	]
	var required_nodes := [
		["CargoCraneMast", "CargoCraneJib", "CargoContainer01", "CargoContainer02", "CargoContainer03"],
		["OrdnanceGantryPort", "OrdnanceGantryStarboard", "OrdnanceMarkerPort", "BlastSafetyDatum"],
		["LaunchRailPort", "LaunchRailStarboard", "LaunchFramePort", "LaunchFrameHeader"],
	]
	var material_signatures := PackedStringArray()
	for pad_index in EXPECTED_PAD_IDS.size():
		var pad_id := EXPECTED_PAD_IDS[pad_index]
		var pad := berths.get_node_or_null(NodePath(String(pad_id))) as Node3D
		var service := pad.get_node_or_null(^"ServicePresentation") as Node3D \
			if pad != null else null
		var pad_report := (presentation.get("pads", {}) as Dictionary).get(pad_id, {}) as Dictionary
		var contract: Dictionary = berths.call("get_landing_contract", pad_id)
		var expected_landing := EXPECTED_PAD_POSITIONS[pad_index] + Vector3(0.0, 4.0, 0.0)
		var expected_approach := EXPECTED_PAD_POSITIONS[pad_index] + Vector3(0.0, 0.0, 30.0)
		var sign := pad.get_node_or_null(^"PadSign") as Label3D if pad != null else null
		var expected_sign := "DOCK %02d  %s" % [pad_index + 4, ["CARGO", "BOMBER", "INTERCEPTOR"][pad_index]]
		_check(
			pad != null and service != null
			and pad.position.is_equal_approx(EXPECTED_PAD_POSITIONS[pad_index])
			and (contract.get("landing_anchor", Vector3.INF) as Vector3).is_equal_approx(expected_landing)
			and (contract.get("approach_anchor", Vector3.INF) as Vector3).is_equal_approx(expected_approach)
			and sign != null and sign.text == expected_sign
			and StringName(service.get_meta(&"service_role", &"")) == EXPECTED_SERVICE_ROLES[pad_index],
			"%s retains its frozen pad, landing, approach, sign, and distinct service-role identity" % pad_id
		)
		var meshes := service.find_children("*", "MeshInstance3D", true, false)
		var lights := service.find_children("*", "OmniLight3D", true, false)
		var roster_complete := true
		for node_name in required_nodes[pad_index]:
			roster_complete = roster_complete and service.get_node_or_null(NodePath(node_name)) != null
		_check(
			meshes.size() == EXPECTED_SERVICE_MESHES[pad_index]
			and lights.size() == 2 and roster_complete
			and (pad_report.get("local_bounds", AABB()) as AABB).is_equal_approx(expected_bounds[pad_index])
			and bool(pad_report.get("landing_clear", false))
			and bool(pad_report.get("approach_clear", false))
			and bool(pad_report.get("readable", false)),
			"%s has its exact bounded readable service roster outside the landing and approach clearances" % pad_id
		)
		var lights_safe := true
		for raw_light in lights:
			var light := raw_light as OmniLight3D
			lights_safe = lights_safe and not light.shadow_enabled \
				and is_equal_approx(light.light_energy, 1.15) \
				and is_equal_approx(light.omni_range, 12.0)
		_check(lights_safe, "%s uses exactly two bounded shadowless service guides" % pad_id)
		var first_material := (meshes[0] as MeshInstance3D).material_override as StandardMaterial3D
		material_signatures.append(first_material.albedo_color.to_html(false))
		var body := pad.get_node_or_null(^"WalkablePadCollision") as StaticBody3D
		var shape_node := body.get_child(0) as CollisionShape3D if body != null else null
		var box_shape := shape_node.shape as BoxShape3D if shape_node != null else null
		_check(
			body != null and box_shape != null and box_shape.size.is_equal_approx(EXPECTED_PAD_SIZE)
			and service.find_children("*", "CollisionObject3D", true, false).is_empty()
			and service.find_children("*", "CollisionShape3D", true, false).is_empty()
			and service.find_children("*", "Area3D", true, false).is_empty(),
			"%s preserves its one walkable pad collider and gives presentation no collision or interaction" % pad_id
		)
	_check(
		material_signatures[0] != material_signatures[1]
		and material_signatures[1] != material_signatures[2]
		and material_signatures[0] != material_signatures[2],
		"cargo ochre, bomber charcoal, and interceptor teal remain visually distinct material families"
	)
	_check(
		not bool(presentation.get("ship_authority", true))
		and not bool(presentation.get("berth_lease_authority", true))
		and not bool(presentation.get("interaction_authority", true)),
		"the three service silhouettes own no ship, lease, or interaction authority"
	)
	var detached: Dictionary = berths.call("get_service_presentation_audit")
	detached["ship_authority"] = true
	(detached["errors"] as PackedStringArray).append("injected")
	_check(bool(berths.get_service_presentation_audit().valid), "the service presentation audit is detached from caller mutation")
	var cargo_container := berths.get_node_or_null(
		^"dock_04_cargo/ServicePresentation/CargoContainer01"
	) as MeshInstance3D
	if cargo_container == null:
		return
	var original_position := cargo_container.position
	cargo_container.position = Vector3(0.0, original_position.y, 0.0)
	var clearance_drift: Dictionary = berths.call("get_service_presentation_audit")
	_check(
		not bool(clearance_drift.valid)
		and (clearance_drift.errors as PackedStringArray).has(
			"service silhouette entered landing or approach clearance: dock_04_cargo"
		),
		"moving cargo stock into the landing volume is structured clearance red"
	)
	cargo_container.position = original_position
	_check(bool(berths.get_service_presentation_audit().valid), "restoring the cargo apron returns all three service presentations green")
	print(
		"FLEET_EXPANSION_SERVICE_BUDGET: meshes=%d lights=%d descendants=%d bodies=%d shapes=%d" % [
			int(audit.get("mesh_instances", -1)), int(audit.get("guide_lights", -1)),
			int(audit.get("descendants", -1)), int(audit.get("static_bodies", -1)),
			int(audit.get("collision_shapes", -1)),
		]
	)


func _check(condition: bool, message: String) -> void:
	_assertions += 1
	if not condition:
		_failures.append(message)
