extends SceneTree

## Exact focused proof for the picket's steady assigned-target pressure cue.
## The test calls only the presentation seam: target selection, physics motion,
## weapon dispatch, damage and rewards remain outside the cue's authority.

const PICKET_SCENE := preload("res://scenes/ships/standoff_picket_opponent.tscn")


class IntentTarget extends Node3D:
	var active := true
	var health := 100.0

	func is_active() -> bool:
		return active

	func get_health() -> float:
		return health


var _failures: Array[String] = []
var _assertions := 0


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var original_root_children := root.get_child_count()
	var host := Node3D.new()
	host.name = "PicketIntentCueFixture"
	root.add_child(host)

	var target := IntentTarget.new()
	target.name = "ProtectedAsset"
	target.position = Vector3(22.0, 4.0, -132.0)
	host.add_child(target)

	var picket := PICKET_SCENE.instantiate() as StandoffPicketOpponent
	picket.name = "IntentPicket"
	picket.escort_enabled = false
	picket.acceleration = 0.0
	host.add_child(picket)
	await process_frame

	var cue := picket.get_node_or_null("StandoffTargetingRails") as MultiMeshInstance3D
	var posture := picket.get_node_or_null("MovementPostureCue") as Node3D
	var port_stroke := posture.get_node_or_null("PortStroke") as MeshInstance3D
	var starboard_stroke := posture.get_node_or_null("StarboardStroke") as MeshInstance3D
	var dormant := picket.get_standoff_intent_cue_snapshot()
	_check(
		cue != null
		and cue.multimesh != null
		and cue.multimesh.mesh is BoxMesh
		and cue.multimesh.instance_count
			== StandoffPicketOpponent.STANDOFF_INTENT_RAIL_COPY_COUNT
		and not cue.visible
		and not bool(dormant.active),
		"the dormant picket retains one hidden two-rail cue renderer"
	)
	_check(
		posture != null and port_stroke != null and starboard_stroke != null
		and port_stroke.mesh == starboard_stroke.mesh
		and not posture.visible
		and not bool(picket.get_posture_cue_snapshot().active),
		"the dormant picket retains two hidden movement-posture strokes"
	)
	_check(
		not posture.is_processing() and not posture.is_physics_processing()
		and not _tree_contains_type(posture, "Timer")
		and not _tree_contains_type(posture, "Light3D")
		and not _tree_contains_type(posture, "CollisionObject3D")
		and not _tree_contains_type(posture, "CollisionShape3D"),
		"the posture cue owns only retained renderers, with no timer, light or collision"
	)
	_check(
		cue.get_child_count() == 0
		and not cue.is_processing()
		and not cue.is_physics_processing()
		and cue.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		and not _tree_contains_type(cue, "Timer")
		and not _tree_contains_type(cue, "Light3D")
		and not _tree_contains_type(cue, "CollisionObject3D")
		and not _tree_contains_type(cue, "CollisionShape3D"),
		"the cue adds no process, timer, light or collision authority"
	)

	# Production station-defense wiring assigns the protected asset while this
	# retained picket is dormant; activation must derive the cue without asking
	# presentation code to select or rewrite that target.
	picket.set_target(target)
	_check(not cue.visible, "a dormant target assignment does not leak a cue")
	var activation := picket.activate(Transform3D.IDENTITY)
	picket.call("_update_presentation", 0.0)
	var active := picket.get_standoff_intent_cue_snapshot()
	var cue_mesh := cue.multimesh.mesh as BoxMesh
	var cue_material := cue_mesh.material
	var expected_direction := (target.global_position - cue.global_position).normalized()
	var authored_rails := cue.get_meta(&"authored_instance_transforms", []) as Array
	_check(
		bool(activation.get("accepted", false))
		and bool(active.active)
		and active.cue_id == &"picket_standoff_targeting_rails"
		and active.role_id == &"standoff_protected_asset_pressure"
		and active.behavior == &"steady_non_flashing"
		and int(active.target_instance_id) == target.get_instance_id()
		and int(active.activation_generation) > 0
		and cue.visible
		and (-cue.global_basis.z).dot(expected_direction) > 0.9999,
		"an active assigned target raises steady twin rails from the muzzle toward the protected asset"
	)
	_check(
		posture.visible
		and picket.get_posture_cue_snapshot().state == StandoffPicketOpponent.STATE_CLOSING
		and port_stroke.position.z < -5.0
		and starboard_stroke.position.z < -5.0,
		"activation shows a forward chevron for the published closing posture"
	)
	_check(
		is_equal_approx(cue_mesh.size.z, 14.0)
		and is_equal_approx(cue_mesh.size.x, 0.22)
		and authored_rails.size() == 2
		and is_equal_approx((authored_rails[0] as Transform3D).origin.x, -0.85)
		and is_equal_approx((authored_rails[1] as Transform3D).origin.x, 0.85)
		and cue_material == picket._materials.picket_magenta_emissive
		and int(active.renderer_nodes) == 1
		and int(active.visible_geometry_copies) == 2
		and int(active.mesh_resources) == 1
		and int(active.material_resources_added) == 0,
		"the combat-distance read is a bounded 14 m sighting corridor using one mesh and the existing emissive material"
	)
	_check(
		bool(active.steady)
		and not bool(active.flashing)
		and not bool(active.timer_driven)
		and not bool(active.raw_input_driven)
		and bool(active.uses_existing_target_assignment)
		and not bool(active.selects_target)
		and not bool(active.movement_authority)
		and not bool(active.fire_authority)
		and not bool(active.damage_authority)
		and not bool(active.reward_authority),
		"the detached cue contract explicitly owns presentation and no gameplay authority"
	)

	var picket_pose := picket.global_transform
	var picket_velocity := picket.velocity
	var target_pose := target.global_transform
	var target_health := target.health
	var target_id := picket._target.get_instance_id()
	var mesh_id := cue.multimesh.mesh.get_instance_id()
	var multimesh_id := cue.multimesh.get_instance_id()
	var material_id := cue_material.get_instance_id()
	var first_rail := authored_rails[0] as Transform3D
	var second_rail := authored_rails[1] as Transform3D
	var shots_fired := int(picket.get_audit_report().lifecycle.shots_fired)
	var shots_aborted := int(picket.get_audit_report().lifecycle.shots_aborted)
	var target_generation := int(active.target_generation)
	for _frame in 12:
		picket.call("_update_presentation", 0.5)
	var steady := picket.get_standoff_intent_cue_snapshot()
	_check(
		picket.global_transform == picket_pose
		and picket.velocity == picket_velocity
		and target.global_transform == target_pose
		and is_equal_approx(target.health, target_health)
		and picket._target.get_instance_id() == target_id
		and int(picket.get_audit_report().lifecycle.shots_fired) == shots_fired
		and int(picket.get_audit_report().lifecycle.shots_aborted) == shots_aborted
		and is_zero_approx(float(picket.get("_telegraph_remaining"))),
		"presentation updates do not select, move, fire at or damage either actor"
	)
	_check(
		bool(steady.active)
		and int(steady.target_generation) == target_generation
		and int(steady.mesh_instance_id) == mesh_id
		and int(steady.multimesh_instance_id) == multimesh_id
		and cue.multimesh.mesh.material.get_instance_id() == material_id
		and (cue.get_meta(&"authored_instance_transforms", [])[0] as Transform3D) == first_rail
		and (cue.get_meta(&"authored_instance_transforms", [])[1] as Transform3D) == second_rail,
		"the steady cue retains the same immutable resources and rail recipes across frames"
	)

	target.position = Vector3(-38.0, -7.0, -118.0)
	target_pose = target.global_transform
	picket.call("_update_presentation", 0.0)
	var redirected_direction := (target.global_position - cue.global_position).normalized()
	_check(
		picket._target.get_instance_id() == target_id
		and target.global_transform == target_pose
		and is_equal_approx(target.health, target_health)
		and (-cue.global_basis.z).dot(redirected_direction) > 0.9999
		and cue.multimesh.mesh.get_instance_id() == mesh_id,
		"the same rails follow the already-assigned actor without replacing resources or target identity"
	)

	# The cue follows the physics state, with a distinct silhouette for each
	# distance band. These target positions are test controls; the state machine
	# still makes each transition on its real fixed step.
	target.position = Vector3(0.0, 0.0, -picket.standoff_range)
	await physics_frame
	await physics_frame
	_check(
		picket.get_engagement_state() == StandoffPicketOpponent.STATE_HOLDING
		and picket.get_posture_cue_snapshot().state == StandoffPicketOpponent.STATE_HOLDING
		and posture.visible
		and is_equal_approx(port_stroke.position.z, -4.0)
		and is_equal_approx(starboard_stroke.position.z, -4.0),
		"the holding band shows a level pair of strokes"
	)
	target.position = Vector3(0.0, 0.0, -picket.minimum_arming_range * 0.5)
	await physics_frame
	await physics_frame
	_check(
		picket.get_engagement_state() == StandoffPicketOpponent.STATE_BREAKING
		and picket.get_posture_cue_snapshot().state == StandoffPicketOpponent.STATE_BREAKING
		and port_stroke.position.z > 4.0
		and starboard_stroke.position.z > 4.0,
		"inside the arming radius the published breaking state shows an aft chevron"
	)
	target.position = Vector3(0.0, 0.0, -picket.standoff_range * 1.5)
	await physics_frame
	await physics_frame
	_check(
		picket.get_engagement_state() == StandoffPicketOpponent.STATE_CLOSING
		and picket.get_posture_cue_snapshot().state == StandoffPicketOpponent.STATE_CLOSING,
		"leaving the band restores the closing read from the state machine"
	)

	# Terminal target state clears the cue and cannot revive without a fresh
	# assignment, even if a pooled fixture toggles the same actor active again.
	target.active = false
	picket.call("_update_presentation", 0.0)
	_check(
		not cue.visible
		and not posture.visible
		and not bool(picket.get_standoff_intent_cue_snapshot().active)
		and int(picket.get_standoff_intent_cue_snapshot().target_instance_id) == 0,
		"terminal target state clears the targeting cue"
	)
	target.active = true
	picket.call("_update_presentation", 0.0)
	_check(not cue.visible and not posture.visible,
		"actor reuse alone cannot revive a cleared target generation")
	picket.set_target(target)
	picket.call("_update_presentation", 0.0)
	_check(cue.visible, "a fresh authoritative assignment restores the reused actor cue")

	host.remove_child(target)
	picket.call("_update_presentation", 0.0)
	_check(not cue.visible and not posture.visible,
		"detached target loss clears both cues immediately")
	host.add_child(target)
	picket.call("_update_presentation", 0.0)
	_check(not cue.visible and not posture.visible,
		"reattaching an actor cannot resurrect its cleared cue")
	picket.set_target(target)
	picket.call("_update_presentation", 0.0)
	_check(cue.visible, "the reattached actor requires a current assignment")

	# Picket detach clears immediately; validated re-entry may re-derive the cue
	# from this same active generation and current authoritative target.
	host.remove_child(picket)
	_check(not cue.visible and not posture.visible,
		"picket detach clears both cues before re-entry")
	host.add_child(picket)
	await process_frame
	await process_frame
	picket.call("_update_presentation", 0.0)
	_check(
		cue.visible
		and posture.visible
		and int(picket.get_standoff_intent_cue_snapshot().activation_generation)
			== int(active.activation_generation),
		"validated re-entry re-derives the cue only for the retained current generation"
	)

	var previous_activation_generation := int(
		picket.get_standoff_intent_cue_snapshot().activation_generation
	)
	picket.deactivate()
	_check(not cue.visible and not posture.visible,
		"withdrawal clears target and posture cues synchronously")
	picket.activate(Transform3D.IDENTITY)
	picket.call("_update_presentation", 0.0)
	var reused := picket.get_standoff_intent_cue_snapshot()
	_check(
		bool(reused.active)
		and int(reused.activation_generation) > previous_activation_generation
		and int(reused.mesh_instance_id) == mesh_id
		and int(picket.get_posture_cue_snapshot().activation_generation)
			== int(reused.activation_generation),
		"activation reuse re-derives the retained authoritative target only in the new generation"
	)

	var target_pose_before_terminal := target.global_transform
	picket.apply_damage(picket.maximum_health + 1.0, picket.global_position)
	_check(
		not picket.is_active()
		and not cue.visible
		and not posture.visible
		and target.global_transform == target_pose_before_terminal
		and target.active,
		"picket terminal loss clears the cue without affecting the protected actor"
	)

	host.queue_free()
	await process_frame
	await process_frame
	_check(
		root.get_child_count() == original_root_children,
		"the exact cue fixture leaves no nodes behind"
	)
	_finish()


func _tree_contains_type(node: Node, type_name: String) -> bool:
	if node.is_class(type_name):
		return true
	for child: Node in node.get_children():
		if _tree_contains_type(child, type_name):
			return true
	return false


func _check(condition: bool, message: String) -> void:
	_assertions += 1
	if not condition:
		_failures.append(message)
		push_error("FAIL: %s" % message)


func _finish() -> void:
	if _failures.is_empty():
		print("PASS: standoff picket intent cue (%d assertions)" % _assertions)
		quit(0)
		return
	print("FAIL: standoff picket intent cue (%d failures / %d assertions)" % [
		_failures.size(), _assertions,
	])
	quit(1)
