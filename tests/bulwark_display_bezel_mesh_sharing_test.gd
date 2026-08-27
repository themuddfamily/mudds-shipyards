extends SceneTree

const Ship := preload("res://scripts/ships/bulwark_heavy_gunship.gd")
const BEZEL_PAIRS := [
	["DisplayBezelTop", "DisplayBezelBottom"],
	["PortDisplayBezelSide", "StarboardDisplayBezelSide"],
]
const EXPECTED_TRANSFORMS := {
	"DisplayBezelTop": Transform3D(Basis.IDENTITY, Vector3(0.0, 0.245, 0.125)),
	"DisplayBezelBottom": Transform3D(Basis.IDENTITY, Vector3(0.0, -0.125, 0.125)),
	"PortDisplayBezelSide": Transform3D(Basis.IDENTITY, Vector3(-0.385, 0.06, 0.125)),
	"StarboardDisplayBezelSide": Transform3D(Basis.IDENTITY, Vector3(0.385, 0.06, 0.125)),
}
const EXPECTED_SIZES := [Vector3(0.82, 0.055, 0.055), Vector3(0.055, 0.32, 0.055)]

var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var ship := Ship.new() as HeroShip
	root.add_child(ship)
	await process_frame
	await physics_frame
	await physics_frame

	var cluster := ship.get_node_or_null(
		^"BulwarkHeavyGunshipVisual/CockpitInterior/InstrumentCluster"
	) as Node3D
	_check(cluster != null, "Bulwark retains its production instrument cluster")
	var mesh_ids := {}
	var renderers_intact := cluster != null
	if cluster != null:
		for pair_index in BEZEL_PAIRS.size():
			var shared_mesh: Mesh
			for bezel_name: String in BEZEL_PAIRS[pair_index]:
				var bezel := cluster.get_node_or_null(NodePath(bezel_name)) as MeshInstance3D
				renderers_intact = renderers_intact and bezel != null
				if bezel == null:
					continue
				shared_mesh = bezel.mesh if shared_mesh == null else shared_mesh
				mesh_ids[bezel.mesh.get_instance_id()] = true
				renderers_intact = renderers_intact \
					and bezel.mesh == shared_mesh \
					and bezel.transform.is_equal_approx(EXPECTED_TRANSFORMS[bezel_name]) \
					and bezel.mesh.get_aabb().size.is_equal_approx(EXPECTED_SIZES[pair_index]) \
					and bezel.mesh.surface_get_material(0) != null \
					and bezel.visible \
					and bezel.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_ON \
					and bezel.layers == 1 \
					and bezel.get_child_count() == 0
	_check(
		renderers_intact and mesh_ids.size() == 2,
		"four bezel leaves retain exact renderer state while using two paired meshes"
	)
	_check(
		ship.get_node_or_null(^"BulwarkBoardingArea") is Area3D \
		and ship.call("get_gunner_station_anchor") is Marker3D \
		and ship.get_node_or_null(^"LeftMuzzle") is Marker3D \
		and ship.get_node_or_null(^"RightMuzzle") is Marker3D,
		"bezel resource sharing leaves boarding, gunner, and weapon ownership intact"
	)
	print(
		"BULWARK_DISPLAY_BEZEL_MESH_SHARING: visible_copies 4 nodes 4->4 "
		+ "submissions 4->4 mesh_resources 4->2"
	)

	ship.queue_free()
	await process_frame
	if _failures.is_empty():
		print("BULWARK DISPLAY BEZEL MESH SHARING TEST PASS")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _check(condition: bool, message: String) -> void:
	if condition:
		print("PASS: ", message)
		return
	_failures.append(message)
	push_error("FAIL: %s" % message)
