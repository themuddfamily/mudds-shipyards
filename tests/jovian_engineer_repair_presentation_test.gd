extends SceneTree

const PresentationType := preload(
	"res://scripts/ships/jovian_engineer_repair_presentation.gd"
)

var _checks := 0
var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var host := Node3D.new()
	host.position = Vector3(4.0, 2.0, -3.0)
	root.add_child(host)
	var presentation = PresentationType.new()
	host.add_child(presentation)
	await process_frame

	_check(
		bool(presentation.attach(0).get("accepted", false)),
		"presentation attaches to its exact initial generation"
	)
	var target := Vector3(2.5, 0.6, 7.0)
	_check(
		bool(presentation.present_snapshot(
			_envelope(0, 0, &"repairing", 0.0, true), target
		).get("accepted", false)),
		"an admitted seated engineer repair presents at its resolved component"
	)
	var active: Dictionary = presentation.get_snapshot()
	var authority := active.get("authority", {}) as Dictionary
	var bounds := active.get("local_effect_bounds", AABB()) as AABB
	_check(
		bool(active.get("visible", false))
			and StringName(active.get("component_id", &"")) == &"engine_bay"
			and int(active.get("component_generation", 0)) == 8
			and (active.get("target_local_position", Vector3.INF) as Vector3).is_equal_approx(target)
			and (active.get("effect_local_position", Vector3.INF) as Vector3).is_equal_approx(
				target + PresentationType.COMPONENT_CLEARANCE
			)
			and int(active.get("visible_segment_count", 0)) == 1,
		"work arc and lamp are component-local from the first accepted progress sample"
	)
	_check(
		active.get("visual_phase", &"") == &"work_in_progress"
			and active.get("shape_hierarchy", &"")
				== &"segmented_work_arc_to_full_ready_crown"
			and int(active.get("inactive_slot_count", -1)) == 6
			and _count_arc_materials(presentation, PresentationType.WORK_COLOR) == 1
			and _count_arc_materials(
				presentation, PresentationType.INACTIVE_SLOT_COLOR
			) == 6,
		"work-in-progress reads as a cyan filled arc against six dark physical slots"
	)
	_check(
		bounds.size.x <= 2.401 and bounds.size.y <= 1.101 and bounds.size.z <= 2.401
			and int(active.get("arc_segment_count", 0)) == 7
			and int(active.get("collision_nodes", -1)) == 0
			and not bool(active.get("processes", true))
			and bool(active.get("steady", false)),
		"the steady effect is spatially bounded and owns no collision or timer loop"
	)
	var work_light := presentation.get_node_or_null(^"RepairWorkLight") as OmniLight3D
	_check(
		work_light != null
			and is_equal_approx(PresentationType.READY_EMISSION_ENERGY, 2.5)
			and PresentationType.WORK_EMISSION_ENERGY
				<= PresentationType.READY_EMISSION_ENERGY
			and PresentationType.WORK_LIGHT_ENERGY
				<= PresentationType.READY_LIGHT_ENERGY
			and is_equal_approx(work_light.light_energy, PresentationType.WORK_LIGHT_ENERGY)
			and bool(work_light.get_meta(&"reduced_flash_safe", false)),
		"the steady work state stays below the inherited emission/light peaks and declares no-flash safety"
	)
	_check(
		_all_component_anchors_clear_hull(),
		"every selectable component resolves the complete bounded cue above the hull"
	)
	_check(
		not bool(authority.get("repair", true))
			and not bool(authority.get("admission", true))
			and not bool(authority.get("movement", true))
			and not bool(authority.get("collision", true))
			and not bool(authority.get("network", true))
			and not bool(authority.get("persistence", true))
			and bool(authority.get("presentation", false)),
		"the node declares presentation ownership only"
	)

	_check(
		presentation.present_snapshot(
			_envelope(0, 0, &"completed", 1.0, true), Vector3.ZERO
		).get("reason", &"") == &"duplicate_sequence"
			and bool(presentation.get_snapshot().get("visible", false)),
		"a duplicate completion cannot clear accepted active work"
	)
	_check(
		presentation.present_snapshot(
			_envelope(1, 1, &"completed", 1.0, true), Vector3.ZERO
		).get("reason", &"") == &"stale_generation"
			and bool(presentation.get_snapshot().get("visible", false)),
		"a foreign generation cannot cross the active attachment"
	)
	_check(
		presentation.present_snapshot(
			_envelope(0, 1, &"repairing", 0.5, false), target * 2.0
		).get("reason", &"") == &"engineer_owner_missing"
			and (presentation.get_snapshot().get(
				"target_local_position", Vector3.INF
			) as Vector3).is_equal_approx(target),
		"an unseated repair claim cannot move or replace the accepted cue"
	)
	_check(
		bool(presentation.present_snapshot(
			_envelope(0, 1, &"repairing", 0.8, true), target
		).get("accepted", false))
			and int(presentation.get_snapshot().get("visible_segment_count", 0)) == 6,
		"monotonic authority progress fills the bounded arc"
	)
	_check(
		bool(presentation.present_snapshot(
			_envelope(0, 2, &"repairing", 1.0, true), target
		).get("accepted", false))
			and presentation.get_snapshot().get("visual_phase", &"") == &"ready_to_commit"
			and int(presentation.get_snapshot().get("inactive_slot_count", -1)) == 0
			and _count_arc_materials(presentation, PresentationType.READY_COLOR) == 7
			and (presentation.get_node(^"RepairWorkLamp") as MeshInstance3D)
				.material_override.albedo_color.is_equal_approx(PresentationType.READY_COLOR)
			and work_light.light_color.is_equal_approx(PresentationType.READY_COLOR)
			and is_equal_approx(work_light.light_energy, PresentationType.READY_LIGHT_ENERGY),
		"the terminal admitted sample becomes a full amber crown with an amber center"
	)
	_check(
		bool(presentation.present_snapshot(
			_envelope(0, 3, &"completed", 1.0, true), Vector3.ZERO
		).get("accepted", false))
			and not bool(presentation.get_snapshot().get("visible", true))
			and presentation.get_snapshot().get("last_clear_reason", &"") == &"repair_committed",
		"authoritative completion clears the world-space work cue"
	)

	_check(
		bool(presentation.begin_generation(1).get("accepted", false))
			and presentation.present_snapshot(
				_envelope(0, 3, &"repairing", 0.2, true), target
			).get("reason", &"") == &"stale_generation",
		"role/reset generation advance fences all prior repair samples"
	)
	_check(
		bool(presentation.present_snapshot(
			_envelope(1, 0, &"repairing", 0.2, true), target
		).get("accepted", false))
			and bool(presentation.get_snapshot().get("visible", false)),
		"a fresh generation can present fresh admitted work"
	)
	_check(
		bool(presentation.detach(1).get("accepted", false))
			and not bool(presentation.get_snapshot().get("attached", true))
			and not bool(presentation.get_snapshot().get("visible", true))
			and int(presentation.get_snapshot().get("generation", -1)) == 2,
		"detach clears work and advances its attachment generation"
	)
	_check(
		presentation.present_snapshot(
			_envelope(1, 1, &"repairing", 0.3, true), target
		).get("reason", &"") == &"not_attached"
			and bool(presentation.attach(2).get("accepted", false))
			and bool(presentation.present_snapshot(
				_envelope(2, 0, &"repairing", 0.3, true), target
			).get("accepted", false)),
		"re-entry requires a freshly attached generation before work returns"
	)

	host.queue_free()
	await process_frame
	_finish()


func _envelope(
		generation: int,
		sequence: int,
		status: StringName,
		progress: float,
		admitted_engineer: bool
	) -> Dictionary:
	return {
		"generation": generation,
		"sequence": sequence,
		"repair_snapshot": {
			"repair": {
				"status": status,
				"reason": &"repair_committed" if status == &"completed" else &"",
				"component_id": &"engine_bay",
				"component_generation": 8,
				"progress": progress,
				"active": status == &"repairing",
			},
			"owner": {
				"seat_id": &"passenger_port_01" if admitted_engineer else &"",
				"occupant_peer_id": 77 if admitted_engineer else 0,
				"avatar_id": &"engineer" if admitted_engineer else &"",
			},
			"presentation_only": true,
		},
	}


func _all_component_anchors_clear_hull() -> bool:
	var hull_bounds := AABB(Vector3(-7.5, -2.0, -11.0), Vector3(15.0, 6.0, 22.0))
	var component_points := [
		Vector3(0.0, 0.0, -8.0),
		Vector3(-5.8, 0.0, 0.0),
		Vector3(5.8, 0.0, 0.0),
		Vector3(0.0, 1.0, 0.0),
		Vector3(0.0, 0.0, 8.2),
	]
	for component_position: Vector3 in component_points:
		var anchor := PresentationType.resolve_exterior_anchor(
			component_position,
			hull_bounds
		)
		var effect_position := anchor + PresentationType.COMPONENT_CLEARANCE
		if not is_equal_approx(anchor.x, component_position.x) \
				or not is_equal_approx(anchor.z, component_position.z) \
				or effect_position.y + PresentationType.LOCAL_EFFECT_BOUNDS.position.y \
					<= hull_bounds.end.y:
			return false
	return true


func _count_arc_materials(presentation: Node, color: Color) -> int:
	var matches := 0
	for index in PresentationType.ARC_SEGMENT_COUNT:
		var segment := presentation.get_node_or_null(
			NodePath("RepairArcSegment%02d" % index)
		) as MeshInstance3D
		if segment == null or not segment.visible:
			continue
		var material := segment.material_override as StandardMaterial3D
		if material != null and material.albedo_color.is_equal_approx(color):
			matches += 1
	return matches


func _check(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures.append("FAIL: " + message)


func _finish() -> void:
	print("JOVIAN_ENGINEER_REPAIR_PRESENTATION: %d checks, %d failures" % [
		_checks, _failures.size()
	])
	for failure in _failures:
		push_error(failure)
	quit(0 if _failures.is_empty() else 1)
