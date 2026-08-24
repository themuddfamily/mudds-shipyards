extends SceneTree

const COURIER_SCENE := preload("res://scenes/ships/courier_runner_opponent.tscn")

var _assertions := 0
var _failures: Array[String] = []


func _initialize() -> void:
	var host := Node3D.new()
	host.name = "TransformedEncounterHost"
	host.transform = Transform3D(
		Basis(Vector3.UP, deg_to_rad(31.0)), Vector3(140.0, -18.0, 72.0)
	)
	root.add_child(host)
	var threat := Node3D.new()
	threat.name = "PlayerThreat"
	host.add_child(threat)
	var courier := COURIER_SCENE.instantiate() as CourierRunnerOpponent
	courier.acceleration = 0.0
	host.add_child(courier)
	await process_frame

	var cue := courier.get_node_or_null(^"EscapeRouteIntentCue") as Node3D
	var pieces := _mesh_pieces(cue)
	_check(
		cue != null
			and cue.top_level
			and not cue.visible
			and pieces.size() == 3,
		"the production courier retains one dormant top-level three-piece route arrow"
	)
	var meshes := {} as Dictionary
	var engine_material_id := int(
		(courier.get_visual_resource_audit().identity_by_key as Dictionary).get(
			&"courier_engine", 0
		)
	)
	var bounded_geometry := pieces.size() == 3
	for piece in pieces:
		meshes[(piece.mesh as Mesh).get_instance_id()] = true
		bounded_geometry = (
			bounded_geometry
			and piece.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			and piece.mesh.get_surface_count() == 1
			and piece.mesh.surface_get_material(0) != null
			and piece.mesh.surface_get_material(0).get_instance_id() == engine_material_id
		)
	_check(
		bounded_geometry
			and meshes.size() == 2
			and pieces[0].mesh is BoxMesh
			and pieces[1].mesh == pieces[2].mesh,
		"the readable arrow is bounded to two immutable box recipes and the shared emissive engine material"
	)
	_check(
		cue.find_children("*", "Light3D", true, false).is_empty()
			and cue.find_children("*", "CollisionShape3D", true, false).is_empty()
			and cue.find_children("*", "Timer", true, false).is_empty()
			and cue.get_script() == null,
		"the cue owns no lights, collision, timer, script, input, or process loop"
	)

	var origin := Vector3(38.0, 12.0, -46.0)
	var heading := Vector3(0.78, 0.12, -0.61).normalized()
	var spawn := Transform3D(
		Basis.looking_at(heading, Vector3.UP).orthonormalized(), origin
	)
	var activation := courier.activate(spawn)
	courier.set_target(threat)
	_check(
		bool(activation.get("accepted", false))
			and courier.set_escape_run(origin, heading, 500.0),
		"a live courier accepts the scenario-owned threat and boundary route"
	)
	await process_frame
	_check(
		cue.visible
			and (-cue.global_basis.z).is_equal_approx(heading)
			and cue.global_position.is_equal_approx(
				courier.global_position
					+ Vector3.UP * CourierRunnerOpponent.ROUTE_INTENT_CUE_HEIGHT
			),
		"the combat-distance arrow follows the courier in world space and points down the authoritative route"
	)
	var immutable_piece_contract := _piece_contract(pieces)
	courier.global_basis = Basis.looking_at(Vector3.LEFT, Vector3.UP)
	await process_frame
	await process_frame
	_check(
		cue.visible
			and (-cue.global_basis.z).is_equal_approx(heading)
			and _piece_contract(pieces) == immutable_piece_contract,
		"hull attitude changes neither bend nor animate the steady route arrow"
	)

	courier.set_target(null)
	_check(not cue.visible, "explicit threat loss clears the route cue immediately")
	courier.set_target(threat)
	await process_frame
	_check(
		not cue.visible,
		"restoring a threat cannot resurrect the cleared cue without a fresh route"
	)
	_check(
		courier.set_escape_run(courier.global_position, heading, 500.0),
		"the scenario can publish a fresh route after reacquiring its threat"
	)
	await process_frame
	_check(cue.visible, "the fresh current-generation route restores the cue")

	host.remove_child(courier)
	_check(not cue.visible, "detaching the courier clears its route cue")
	host.add_child(courier)
	await process_frame
	_check(
		not cue.visible
			and courier.set_escape_run(courier.global_position, heading, 500.0),
		"re-entry stays dark until the active generation receives a fresh route"
	)
	await process_frame
	_check(cue.visible, "the refreshed re-entry route is readable again")

	courier.deactivate()
	_check(not cue.visible, "scenario stand-down clears the route cue")
	courier.activate(spawn)
	courier.set_target(threat)
	await process_frame
	_check(
		not cue.visible
			and courier.set_escape_run(origin, heading, 500.0),
		"activation reuse cannot inherit the previous generation's cue"
	)
	await process_frame
	_check(cue.visible, "reuse shows only its newly published route")
	courier.global_position = origin + heading * 500.0
	await process_frame
	_check(not cue.visible, "reaching the authoritative destination clears the cue")
	courier.global_position = origin
	await process_frame
	_check(
		not cue.visible,
		"moving a retained terminal fixture cannot replay the cleared route cue"
	)
	_check(
		courier.set_escape_run(origin, heading, 500.0),
		"a final fresh route arms destruction cleanup evidence"
	)
	await process_frame
	courier.apply_damage(courier.maximum_health, courier.global_position)
	_check(
		not courier.is_active() and not cue.visible,
		"courier destruction clears the cue with no damage or objective authority added"
	)

	host.queue_free()
	await process_frame
	if _failures.is_empty():
		print(
			"COURIER_ROUTE_INTENT_CUE: world_space=true steady=true pieces=3 meshes=2 lifecycle=clear"
		)
		print("PASS courier_runner_route_intent_cue_test (%d assertions)" % _assertions)
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _mesh_pieces(cue: Node3D) -> Array[MeshInstance3D]:
	var pieces: Array[MeshInstance3D] = []
	if cue == null:
		return pieces
	for child in cue.get_children():
		if child is MeshInstance3D:
			pieces.append(child as MeshInstance3D)
	return pieces


func _piece_contract(pieces: Array[MeshInstance3D]) -> Array:
	var contract: Array = []
	for piece in pieces:
		contract.append({
			"transform": piece.transform,
			"mesh_id": piece.mesh.get_instance_id(),
			"visible": piece.visible,
		})
	return contract


func _check(condition: bool, message: String) -> void:
	_assertions += 1
	if not condition:
		_failures.append(message)
