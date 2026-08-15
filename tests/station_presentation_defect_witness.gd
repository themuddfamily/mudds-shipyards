extends SceneTree

## Failing witnesses for the P2 presentation half of the 2026-08-15 human
## playtest report: "…random objects floating in the air and it ruins the
## experience."
##
## These three assertions were split out of
## `station_traversal_defect_witness_test.gd` when the P1 traversal defects
## (MAP-001/002/003) were fixed. They cover MAP-004, MAP-005 and MAP-006, which
## are explicitly reserved for a separate presentation pass, and they are
## reproduced here **verbatim** — thresholds, node rosters and expectations are
## unchanged from the original witness. They are expected to be RED until that
## pass lands.
##
## Like the original witness this file is deliberately **not** named `*_test.gd`,
## so `tools/release/run_test_matrix.sh` does not collect it and the gate stays
## meaningful. Run it directly:
##
##   godot --headless --path . --script tests/station_presentation_defect_witness.gd
##
## Rename it into the `*_test.gd` glob once MAP-004/005/006 are fixed.

const MAIN_SCENE := preload("res://scenes/main.tscn")
const WORLD_LAYER := PhysicsLayers.WORLD

## MAP-004. Facade and terminal legends whose readable face must point at the
## deck the player actually approaches them from. TextMesh renders its readable
## face toward local +Z, so `expected_facing` is the direction a reader stands in.
const APPROACH_FACING_SIGNS := [
	["UpperOperations/Sign_DOCK_OPERATIONS", Vector3(0.0, 0.0, -1.0)],
	["ModernFleetRegistry/Sign_FLEET_REGISTRY__--__MODERN_INTERFACE", Vector3(0.0, 0.0, -1.0)],
	["ModernFleetRegistry/Sign_SAY_SHIP_NAME", Vector3(0.0, 0.0, -1.0)],
	["ModernFleetRegistry/Sign_TORRENT__JOVIAN__TITAN__VORTEX", Vector3(0.0, 0.0, -1.0)],
	["ModernFleetRegistry/Sign_KATANA__PARADOX__PREDATOR__DYNAMIC", Vector3(0.0, 0.0, -1.0)],
	["ModernFleetRegistry/Sign_UTOPIA__ARROW", Vector3(0.0, 0.0, -1.0)],
]

## MAP-005. Decorative pieces that must rest on the surface they are placed against.
const SEATED_DECORATION_PATHS := [
	"OperationalLattice/Activities/AftOperationsActivity/PresentationRoot/SafetyBeacon01/Base",
	"OperationalLattice/Activities/AftOperationsActivity/PresentationRoot/SafetyBeacon02/Base",
	"OperationalLattice/Activities/AftOperationsActivity/PresentationRoot/SafetyBeacon03/Base",
	"OperationalLattice/Activities/AftOperationsActivity/PresentationRoot/SafetyBeacon04/Base",
	"OperationalLattice/Activities/HabitatServicePatrol/PresentationRoot/SafetyBeacon01/Base",
	"OperationalLattice/Activities/HabitatServicePatrol/PresentationRoot/SafetyBeacon02/Base",
	"OperationalLattice/Activities/HabitatServicePatrol/PresentationRoot/SafetyBeacon03/Base",
	"OperationalLattice/Activities/HabitatServicePatrol/PresentationRoot/SafetyBeacon04/Base",
]
const SEATED_DECORATION_TOLERANCE := 0.03

var _failures: Array[String] = []
var _space: PhysicsDirectSpaceState3D


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var game := MAIN_SCENE.instantiate() as GameFlow
	_check(game != null, "production Main instantiates for the presentation defect witness")
	if game == null:
		_finish()
		return
	root.add_child(game)
	await process_frame
	await physics_frame
	game.start_shift()
	for _settle in 8:
		await physics_frame

	var world := game.get_node_or_null(^"ShipyardWorld") as ShipyardWorld
	var player := game.get_node_or_null(^"PlayerController") as PlayerController
	if player == null:
		player = game.get_node_or_null(^"Player") as PlayerController
	_check(world != null, "production world is live")
	if world == null:
		game.queue_free()
		await process_frame
		_finish()
		return

	# The player body would otherwise occlude the downward support probes.
	if player != null:
		player.teleport_to(Transform3D(Basis.IDENTITY, Vector3(0.0, 500.0, 0.0)))
		await physics_frame

	_space = world.get_world_3d().direct_space_state

	_test_approach_facing_signs(world)
	_test_seated_decorations_rest_on_their_surface(world)
	_test_orphan_dock_guide_lens(world)

	game.queue_free()
	await process_frame
	await physics_frame
	await process_frame
	_finish()


func _test_approach_facing_signs(world: ShipyardWorld) -> void:
	var reversed_signs := PackedStringArray()
	for entry in APPROACH_FACING_SIGNS:
		var sign_mesh := world.get_node_or_null(NodePath(entry[0] as String)) as MeshInstance3D
		if sign_mesh == null or sign_mesh.mesh is not TextMesh:
			reversed_signs.append("%s <missing>" % entry[0])
			continue
		# TextMesh renders its readable face toward local +Z.
		var readable_from := sign_mesh.global_basis.z.normalized()
		if readable_from.dot(entry[1] as Vector3) <= 0.5:
			reversed_signs.append("%s readable_from=%s expected=%s" % [
				entry[0], str(readable_from), str(entry[1])
			])
	print("REVERSED_APPROACH_SIGNS: ", reversed_signs)
	_check(
		reversed_signs.is_empty(),
		"pod facade and registry terminal legends read forwards from the deck they are approached from"
	)


func _test_seated_decorations_rest_on_their_surface(world: ShipyardWorld) -> void:
	var floating := PackedStringArray()
	for path in SEATED_DECORATION_PATHS:
		var mesh_instance := world.get_node_or_null(NodePath(path)) as MeshInstance3D
		if mesh_instance == null or mesh_instance.mesh == null:
			floating.append("%s <missing>" % path)
			continue
		var drop := _drop_below(mesh_instance)
		if drop > SEATED_DECORATION_TOLERANCE:
			floating.append("%s drop=%.3f" % [path, drop])
	print("FLOATING_SEATED_DECORATIONS: ", floating)
	_check(
		floating.is_empty(),
		"every roof-mounted safety beacon rests on the surface it is placed against"
	)


func _test_orphan_dock_guide_lens(world: ShipyardWorld) -> void:
	var lens := world.get_node_or_null(
		^"JovianFreightBerth/FreightPresentation/DockGuideLens18"
	) as MeshInstance3D
	if lens == null or lens.mesh == null:
		_check(false, "the freight dock guide lens roster resolves")
		return
	var apron := world.get_node_or_null(
		^"JovianFreightBerth/LoadingApron/ApronDeck04"
	) as StaticBody3D
	var apron_box := _body_world_box(apron) if apron != null else AABB()
	var lens_box := lens.global_transform * lens.mesh.get_aabb()
	var drop := _drop_below(lens)
	print(
		"DOCK_GUIDE_LENS_18: centre=", lens_box.get_center(),
		" drop=", drop,
		" apron_max_z=", apron_box.end.z
	)
	_check(
		drop <= 0.35,
		"the freight dock guide lens sits on the apron it marks instead of hanging in open space"
	)


func _drop_below(mesh_instance: MeshInstance3D) -> float:
	var box := mesh_instance.global_transform * mesh_instance.mesh.get_aabb()
	var origin := Vector3(box.get_center().x, box.position.y + 0.01, box.get_center().z)
	var ray := PhysicsRayQueryParameters3D.create(origin, origin + Vector3.DOWN * 400.0, WORLD_LAYER)
	ray.collide_with_areas = false
	var body := _owning_body(mesh_instance)
	if body != null:
		ray.exclude = [body.get_rid()]
	var hit := _space.intersect_ray(ray)
	if hit.is_empty():
		return 400.0
	return origin.y - float((hit.position as Vector3).y)


func _owning_body(node: Node) -> PhysicsBody3D:
	var cursor := node.get_parent()
	while cursor != null:
		if cursor is PhysicsBody3D:
			return cursor as PhysicsBody3D
		cursor = cursor.get_parent()
	return null


func _body_world_box(body: Node3D) -> AABB:
	var box := AABB()
	var first := true
	for candidate in body.find_children("*", "MeshInstance3D", true, false):
		var mesh_instance := candidate as MeshInstance3D
		if mesh_instance.mesh == null:
			continue
		var world_box := mesh_instance.global_transform * mesh_instance.mesh.get_aabb()
		if first:
			box = world_box
			first = false
		else:
			box = box.merge(world_box)
	return box


func _check(condition: bool, description: String) -> void:
	if condition:
		print("PASS: ", description)
	else:
		_failures.append(description)
		push_error("FAIL: " + description)


func _finish() -> void:
	if _failures.is_empty():
		print("STATION_PRESENTATION_DEFECT_WITNESS_OK")
		quit(0)
	else:
		print("STATION_PRESENTATION_DEFECT_WITNESS_FAILED: ", "; ".join(_failures))
		quit(1)
