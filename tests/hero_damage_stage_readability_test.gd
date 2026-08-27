extends SceneTree

## Focused Phase 6 regression for the visual seam between a resolved component
## hit and terminal destruction. This fixture feeds already-resolved records to
## presentation and owns no damage, collision, reward, or physics authority.

const PresentationType := preload("res://scripts/effects/hero_damage_presentation.gd")

var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var host := Node3D.new()
	root.add_child(host)
	var presentation := PresentationType.new()
	presentation.impact_effect_lifetime = 1.0
	presentation.destruction_effect_lifetime = 2.0
	presentation.destruction_debris_count = 4
	host.add_child(presentation)
	presentation.update_state(0.55, PresentationType.STATE_ACTIVE)

	var component_position := Vector3(-2.0, 0.5, -4.0)
	_check(
		_queue_and_commit(
			presentation, 101, component_position, false, Transform3D.IDENTITY
		),
		"an exact non-terminal component receipt commits once"
	)
	var component_root := root.get_node_or_null("HeroDamageImpact") as Node3D
	var component_brace := _child(component_root, "ComponentImpactBrace") as MeshInstance3D
	var component_light := _child(component_root, "ImpactLight") as OmniLight3D
	var meshes := presentation.get("_meshes") as Dictionary
	var generic_mesh := meshes.get(&"impact_flash") as PrimitiveMesh
	var component_mesh := component_brace.mesh as TorusMesh if component_brace != null else null
	_check(
		component_root != null
		and component_root.global_position.is_equal_approx(component_position)
		and component_brace != null
		and component_mesh != null
		and _child(component_root, "ImpactFlash") == null,
		"a component hit renders one tight ring rather than the round hull flare"
	)
	_check(
		component_mesh != null
		and component_mesh.get_surface_count() == 1
		and component_mesh.material == generic_mesh.material
		and component_light != null
		and component_root.get_child_count() == 3,
		"the ring reuses the existing one-surface emission, practical, and transient node budget"
	)
	_check(
		component_brace != null
		and component_brace.basis.y.normalized().dot(Vector3.BACK) > 0.999,
		"the component ring faces the already-resolved surface normal"
	)
	var component_scale := component_brace.scale.x if component_brace != null else 0.0
	presentation.call("_update_transient_effects", 0.30)
	_check(
		component_brace != null
		and component_brace.scale.x > component_scale
		and component_brace.transparency > 0.0,
		"the ring expands and fades on the existing bounded impact clock"
	)

	presentation.reset_for_reuse(1.0, PresentationType.STATE_ACTIVE)
	var terminal_position := Vector3(2.0, 0.5, -4.0)
	_check(
		_queue_and_commit(
			presentation,
			102,
			terminal_position,
			true,
			Transform3D(Basis.IDENTITY, terminal_position)
		),
		"an exact terminal receipt carrying the same component id commits once"
	)
	var terminal_impact := root.get_node_or_null("HeroDamageImpact") as Node3D
	var destruction := presentation.get_destruction_effect_root() as Node3D
	var terminal_core := _child(terminal_impact, "ImpactFlash") as MeshInstance3D
	var terminal_wave := _child(destruction, "ExplosionShockwave") as MeshInstance3D
	_check(
		terminal_core != null
		and terminal_core.mesh is SphereMesh
		and _child(terminal_impact, "ComponentImpactBrace") == null
		and terminal_wave != null
		and terminal_wave.mesh is TorusMesh
		and terminal_wave.scale.x >= component_scale * 3.0,
		"terminal damage retains a round contact core plus a shockwave at least three times broader"
	)
	_check(
		_count_lights(terminal_impact) == 1
		and _count_lights(destruction) == 1,
		"the semantic silhouette split adds no impact or destruction lights"
	)
	presentation.reset_for_reuse(1.0, PresentationType.STATE_ACTIVE)
	_check(
		presentation.get_live_world_effect_count() == 0
		and presentation.get_pending_damage_presentation_count() == 0,
		"reuse clears both stages through the existing generation-safe cleanup"
	)

	host.queue_free()
	await process_frame
	if _failures.is_empty():
		print("HERO_DAMAGE_STAGE_READABILITY_TEST_OK")
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)


func _queue_and_commit(
		presentation: Node,
		receipt_id: int,
		position: Vector3,
		terminal: bool,
		world_pose: Transform3D
	) -> bool:
	return presentation.defer_damage_presentation(
		receipt_id,
		position,
		Vector3.BACK,
		1.0,
		terminal,
		Vector3.ZERO,
		world_pose,
		&"engine_bay"
	) and presentation.commit_deferred_damage_presentation(receipt_id)


func _child(parent: Node, path: String) -> Node:
	return parent.get_node_or_null(path) if parent != null else null


func _count_lights(parent: Node) -> int:
	if parent == null:
		return 0
	var count := 0
	for child in parent.get_children():
		if child is Light3D:
			count += 1
	return count


func _check(condition: bool, message: String) -> void:
	if condition:
		print("PASS: %s" % message)
		return
	_failures.append(message)
