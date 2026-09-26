extends SceneTree

## Focused proof for the wing skirmisher's posture strokes. The test drives only
## the existing role, target, rear-arc and rear-cross state; the cue observes it
## and must never change movement, fire, target or tactic state.

const AUTHORITY_SCRIPT := preload("res://scripts/combat/live_combat_authority.gd")
const SKIRMISHER_SCENE := preload("res://scenes/ships/flanking_skirmisher_opponent.tscn")


class PostureTarget extends Node3D:
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
	host.name = "SkirmisherPostureFixture"
	root.add_child(host)

	var authority := AUTHORITY_SCRIPT.new() as LiveCombatAuthority
	authority.name = "CombatAuthority"
	host.add_child(authority)

	# The player faces -Z, so +Z is the rear hemisphere.
	var target := PostureTarget.new()
	target.name = "PostureTarget"
	host.add_child(target)

	var skirmisher := SKIRMISHER_SCENE.instantiate() as FlankingSkirmisherOpponent
	skirmisher.name = "PostureSkirmisher"
	skirmisher.process_mode = Node.PROCESS_MODE_DISABLED
	skirmisher.combat_authority_path = NodePath("../CombatAuthority")
	skirmisher.pulse_presentation_path = NodePath("../MissingPulsePresentation")
	skirmisher.combat_audio_path = NodePath("../MissingCombatAudio")
	skirmisher.hud_path = NodePath("../MissingHud")
	skirmisher.scenario_director_path = NodePath("../MissingScenarioDirector")
	host.add_child(skirmisher)
	await process_frame

	var posture := skirmisher.get_node_or_null("WingPostureCue") as Node3D
	var port_stroke := posture.get_node_or_null("PortStroke") as MeshInstance3D if posture else null
	var starboard_stroke := posture.get_node_or_null("StarboardStroke") as MeshInstance3D \
		if posture else null
	var stroke_material := port_stroke.mesh.material as StandardMaterial3D \
		if port_stroke != null and port_stroke.mesh is BoxMesh else null
	_check(
		posture != null and port_stroke != null and starboard_stroke != null
		and port_stroke.mesh == starboard_stroke.mesh
		and stroke_material != null
		and stroke_material.emission.is_equal_approx(FlankingSkirmisherOpponent.POSTURE_CORAL)
		and posture.get_parent() == skirmisher
		and not posture.visible
		and not bool(skirmisher.get_posture_cue_snapshot().active),
		"the dormant skirmisher retains two hidden coral posture strokes on its body"
	)
	_check(
		posture != null
		and not posture.is_processing() and not posture.is_physics_processing()
		and posture.find_children("*", "Timer", true, false).is_empty()
		and posture.find_children("*", "Light3D", true, false).is_empty()
		and posture.find_children("*", "CollisionObject3D", true, false).is_empty()
		and posture.find_children("*", "CollisionShape3D", true, false).is_empty()
		and bool(skirmisher.get_wing_chalk_band_resource_audit().valid),
		"the cue owns only retained renderers and keeps the hull presentation budget valid"
	)

	var activation := skirmisher.activate(
		Transform3D(Basis.IDENTITY, Vector3(12.0, 0.0, -40.0))
	)
	skirmisher.set_target(target)
	_check(bool(activation.accepted) and not posture.visible,
		"an active craft without a wing role shows no posture")

	skirmisher.assign_wing_role(WingCoordinator.ROLE_FLANKER)
	var flanking := skirmisher.get_posture_cue_snapshot()
	_check(
		posture.visible
		and flanking.posture == FlankingSkirmisherOpponent.POSTURE_FLANKING
		and absf(float(flanking.direction_sign)) == 1.0
		and int(flanking.target_instance_id) == target.get_instance_id()
		and skirmisher.is_weapon_safed(),
		"a flanker in the player's front hemisphere shows the flanking chevron while safed"
	)
	var flanking_port := port_stroke.transform

	# Move behind the player: the existing rear-arc test opens.
	var position_before := Vector3(12.0, 0.0, 40.0)
	skirmisher.global_position = position_before
	var tactics_before := skirmisher.get_tactics_profile()
	var cross_before := skirmisher.get_rear_cross_snapshot()
	skirmisher.call("_update_presentation", 0.016)
	_check(
		posture.visible
		and skirmisher.get_posture_cue_snapshot().posture
			== FlankingSkirmisherOpponent.POSTURE_ATTACKING
		and not port_stroke.transform.is_equal_approx(flanking_port),
		"inside the rear arc the strokes repaint as the attacking reticle"
	)
	_check(
		skirmisher.global_position.is_equal_approx(position_before)
		and skirmisher.get_tactics_profile() == tactics_before
		and skirmisher.get_rear_cross_snapshot() == cross_before
		and skirmisher.get_wing_role() == WingCoordinator.ROLE_FLANKER
		and skirmisher.get_shots_fired() == 0,
		"the presentation pass changes no position, tactic, role or weapon state"
	)

	skirmisher.call("_begin_rear_cross")
	_check(
		skirmisher.get_posture_cue_snapshot().posture
			== FlankingSkirmisherOpponent.POSTURE_CROSSING
		and skirmisher.get_rear_cross_snapshot().state_id == &"active",
		"the committed rear cross shows the crossing bars"
	)
	skirmisher.call("_complete_rear_cross")
	_check(
		skirmisher.get_posture_cue_snapshot().posture
			== FlankingSkirmisherOpponent.POSTURE_ATTACKING,
		"completing the cross returns to the attacking read synchronously"
	)

	skirmisher.assign_wing_role(WingCoordinator.ROLE_ANCHOR)
	_check(
		skirmisher.get_posture_cue_snapshot().posture
			== FlankingSkirmisherOpponent.POSTURE_SCREENING,
		"the anchor shows the screening bars"
	)

	target.active = false
	skirmisher.call("_update_presentation", 0.016)
	_check(not posture.visible and not bool(skirmisher.get_posture_cue_snapshot().active),
		"an inactive target clears the posture")
	target.active = true
	skirmisher.call("_update_presentation", 0.016)
	_check(posture.visible, "a live target restores the posture")

	skirmisher.set_target(null)
	_check(not posture.visible and not bool(skirmisher.get_posture_cue_snapshot().active),
		"losing the target clears the posture synchronously")
	skirmisher.set_target(target)
	var old_generation := int(skirmisher.get_posture_cue_snapshot().activation_generation)
	_check(posture.visible and old_generation > 0,
		"reassigning the target restores the posture in the current generation")

	skirmisher.deactivate()
	_check(not posture.visible, "stand-down clears the posture")
	skirmisher.call("_sync_posture_cue")
	skirmisher.call("_update_presentation", 0.016)
	_check(not posture.visible and not bool(skirmisher.get_posture_cue_snapshot().active),
		"a stale encounter generation cannot repaint a stood-down craft")

	skirmisher.activate(Transform3D(Basis.IDENTITY, Vector3(12.0, 0.0, 40.0)))
	skirmisher.set_target(target)
	_check(not posture.visible,
		"a reused craft shows nothing until the new encounter assigns a role")
	skirmisher.assign_wing_role(WingCoordinator.ROLE_FLANKER)
	var reused := skirmisher.get_posture_cue_snapshot()
	_check(
		posture.visible
		and int(reused.activation_generation) > old_generation
		and reused.posture == FlankingSkirmisherOpponent.POSTURE_ATTACKING,
		"the reused craft repaints only for its new activation generation"
	)

	skirmisher.call("_destroy_interceptor", skirmisher.global_position)
	_check(not posture.visible, "destruction clears the posture")

	host.queue_free()
	await process_frame
	await process_frame
	_check(root.get_child_count() == original_root_children,
		"the posture fixture leaves no nodes behind")
	_finish()


func _check(condition: bool, message: String) -> void:
	_assertions += 1
	if not condition:
		_failures.append(message)
		push_error("FAIL: %s" % message)


func _finish() -> void:
	if _failures.is_empty():
		print("PASS: flanking skirmisher posture cue (%d assertions)" % _assertions)
		quit(0)
		return
	print("FAIL: flanking skirmisher posture cue (%d failures / %d assertions)" % [
		_failures.size(), _assertions,
	])
	quit(1)
