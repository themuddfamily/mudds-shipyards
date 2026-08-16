extends SceneTree

## Regression for the P2 presentation half of the 2026-08-15 human playtest
## report: "…random objects floating in the air and it ruins the experience."
##
## These three assertions were split out of
## `station_traversal_defect_witness_test.gd` when the P1 traversal defects
## (MAP-001/002/003) were fixed, and reproduced there **verbatim** so a P2
## presentation defect could not hold the P1 traversal gate red. They cover
## MAP-004, MAP-005 and MAP-006, which are now fixed, so this file has been
## renamed into the `*_test.gd` glob and is collected by
## `tools/release/run_test_matrix.sh`.
##
## One deliberate change was made when the defects were fixed, recorded here
## rather than made quietly:
##
##   `APPROACH_FACING_SIGNS` gained five entries. The intake listed six mirrored
##   legends; sweeping every live `TextMesh` in the production world found five
##   more with exactly the same cause — `Vector3.ZERO` rotation on a structure's
##   approach-side face — including both legends on `JunctionPortalHeader`, the
##   station's most prominent navigation board. The original six are unchanged
##   in wording, path and expectation; the roster is only widened, from six entries to eleven. No threshold
##   was loosened and no assertion was removed.
##
## Run it directly with:
##
##   godot --headless --path . --script tests/station_presentation_defect_witness_test.gd

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
	# Widened beyond the intake's six after a sweep of every live `TextMesh`.
	# Same cause, same fix; all five were rendered and read backwards first.
	["ExposedDockLattice/Sign_MUDDS__--__REGENERATION_DECK", Vector3(0.0, 0.0, -1.0)],
	["ExposedDockLattice/Sign_CENTRAL_JUNCTION__--__FLEET_DOCKS", Vector3(0.0, 0.0, -1.0)],
	["AftJunctionStack/Structure/VIPLandmark/Sign_VIP_ACCESS__--__DEFERRED", Vector3(0.0, 0.0, -1.0)],
	[
		"AftJunctionStack/Structure/OpenStructureDetails/Sign_AFT_JUNCTION__--__MODERN_INTERPRETATION",
		Vector3(0.0, 0.0, -1.0),
	],
	[
		"HabitatSpine/Structure/PlayerClearConnector/Sign_HABITAT_SPINE____FIXED-ERA-INSPIRED",
		Vector3(-1.0, 0.0, 0.0),
	],
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

## The 2026-08-16 report: "there's a strange floating block". `_drop_below` above
## cannot answer this class, because it rays against World *collision* and every
## piece here hangs off structure that has none — under-deck chords, stacked
## crates. In open space that ray simply falls forever.
##
## So this roster is measured against **drawn geometry** instead: each piece must
## share volume with, or sit within `SEATED_ON_GEOMETRY_TOLERANCE` of, some other
## visible mesh. Measured live before the fix, with the gap each one hung at:
##
##   Fleet Dock Comb underframe: both 47 m trunk chords hung 0.090 m below the
##   deck they are bolted to, and the port one intersected nothing in the whole
##   module; the three rung chords hung 0.040 m.
##   Jovian freight: all eight cargo crates hovered, 0.045-0.055 m above the rack
##   shelf for the lower four and 0.040-0.070 m above their own lower crate for
##   the upper four.
const SEATED_ON_GEOMETRY_PATHS := [
	"FleetDockComb/GeneratedComb/VisualUnderframe/TrunkChordPort",
	"FleetDockComb/GeneratedComb/VisualUnderframe/TrunkChordStarboard",
	"JovianFreightBerth/CargoInfrastructure/CargoUnit01/Mesh",
	"JovianFreightBerth/CargoInfrastructure/CargoUnit02/Mesh",
	"JovianFreightBerth/CargoInfrastructure/CargoUnit03/Mesh",
	"JovianFreightBerth/CargoInfrastructure/CargoUnit04/Mesh",
	"JovianFreightBerth/CargoInfrastructure/CargoUnit05/Mesh",
	"JovianFreightBerth/CargoInfrastructure/CargoUnit06/Mesh",
	"JovianFreightBerth/CargoInfrastructure/CargoUnit07/Mesh",
	"JovianFreightBerth/CargoInfrastructure/CargoUnit08/Mesh",
]
const SEATED_ON_GEOMETRY_TOLERANCE := 0.001

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
	_test_structural_pieces_rest_on_drawn_geometry(world)
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


func _test_structural_pieces_rest_on_drawn_geometry(world: ShipyardWorld) -> void:
	var drawn: Array[Dictionary] = []
	for candidate in world.find_children("*", "MeshInstance3D", true, false):
		var mesh_instance := candidate as MeshInstance3D
		if mesh_instance.mesh == null or not mesh_instance.is_visible_in_tree():
			continue
		drawn.append({
			"node": mesh_instance,
			"box": (mesh_instance.global_transform * mesh_instance.mesh.get_aabb()).abs(),
		})
	var floating := PackedStringArray()
	for path in SEATED_ON_GEOMETRY_PATHS:
		var piece := world.get_node_or_null(NodePath(path)) as MeshInstance3D
		if piece == null or piece.mesh == null:
			floating.append("%s <missing>" % path)
			continue
		var box := (piece.global_transform * piece.mesh.get_aabb()).abs().grow(SEATED_ON_GEOMETRY_TOLERANCE)
		var seated := false
		for entry in drawn:
			var other := entry["node"] as MeshInstance3D
			if other == piece or piece.is_ancestor_of(other) or other.is_ancestor_of(piece):
				continue
			if box.intersects(entry["box"] as AABB):
				seated = true
				break
		if not seated:
			floating.append("%s at %s" % [path, str(box.get_center())])
	print("FLOATING_STRUCTURAL_PIECES: ", floating)
	_check(
		floating.is_empty(),
		"every under-deck chord and stacked cargo crate bears on drawn geometry instead of hanging in space"
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
		print("STATION_PRESENTATION_DEFECT_WITNESS_TEST_OK")
		quit(0)
	else:
		print("STATION_PRESENTATION_DEFECT_WITNESS_TEST_FAILED: ", "; ".join(_failures))
		quit(1)
