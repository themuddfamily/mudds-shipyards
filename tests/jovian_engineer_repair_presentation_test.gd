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
		bounds.size.x <= 2.401 and bounds.size.y <= 1.101 and bounds.size.z <= 2.401
			and int(active.get("arc_segment_count", 0)) == 7
			and int(active.get("collision_nodes", -1)) == 0
			and not bool(active.get("processes", true))
			and bool(active.get("steady", false)),
		"the steady effect is spatially bounded and owns no collision or timer loop"
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
			_envelope(0, 2, &"completed", 1.0, true), Vector3.ZERO
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
