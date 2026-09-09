extends SceneTree

const ArrowShipType := preload("res://scripts/ships/arrow_recon_ship.gd")
const JOVIAN := preload("res://scenes/ships/jovian_light_freighter.tscn")
const CARGO := preload("res://scripts/ships/cinder_cargo_hauler.gd")
const Ship := preload("res://scripts/ships/bulwark_heavy_gunship.gd")
const BEZEL_PAIRS := [
	["DisplayBezelTop", "DisplayBezelBottom"],
	["PortDisplayBezelSide", "StarboardDisplayBezelSide"],
]
const EXPECTED_TRANSFORMS := {
	"DisplayBezelTop": Transform3D(Basis.IDENTITY, Vector3(0.0, 0.245, 0.145)),
	"DisplayBezelBottom": Transform3D(Basis(Vector3.BACK, PI), Vector3(0.0, -0.125, 0.145)),
	"PortDisplayBezelSide": Transform3D(Basis.IDENTITY, Vector3(-0.385, 0.06, 0.145)),
	"StarboardDisplayBezelSide": Transform3D(Basis(Vector3.BACK, PI), Vector3(0.385, 0.06, 0.145)),
}
const EXPECTED_SIZES := [Vector3(0.82, 0.055, 0.08), Vector3(0.055, 0.32, 0.08)]

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

	_test_fitted_housing(ship, cluster)
	ship.queue_free()
	await process_frame
	for other: HeroShip in [JOVIAN.instantiate(), CARGO.new()]:
		root.add_child(other)
		await process_frame
		other.set_physics_process(false)
		_test_fitted_housing(other, other.find_child("InstrumentCluster", true, false))
		other.queue_free()
		await process_frame
	if _failures.is_empty():
		print("BULWARK DISPLAY BEZEL MESH SHARING TEST PASS")
		call_deferred("quit", 0)
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


func _test_fitted_housing(ship: HeroShip, cluster: Node3D) -> void:
	var readout := cluster.get_node("FlightDataReadout") as Label3D
	var live := readout.get_node("LiveFlightInstruments")
	_check(readout == ship.get("_cockpit_readout") and not readout.no_depth_test,
		ship.name + " retains its existing depth-tested live display owner")
	live.update_readings(237.0, -0.43, 0.21)
	_check(live.get_node("SpeedReadout").text == "SPD 237"
		and live.get_node("LiveStatusRepeaters/ThrottleReadout").text.begins_with("-43")
		and live.get_node("LiveStatusRepeaters/HullReadout").text.begins_with("021"),
		ship.name + " retained instruments display changed flight readings")
	var camera := ship.get("_cockpit_camera") as Camera3D
	var geometry_valid := true
	var clear_dials := true
	for node_name in ["InstrumentHood", "DisplayBezelTop", "DisplayBezelBottom", "PortDisplayBezelSide", "StarboardDisplayBezelSide", "PortStatusRepeater", "StarboardStatusRepeater"]:
		var stock := cluster.get_node(node_name) as MeshInstance3D
		for surface in stock.mesh.get_surface_count():
			var arrays := stock.mesh.surface_get_arrays(surface)
			var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
			var uvs: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
			geometry_valid = geometry_valid and normals.size() == vertices.size() and uvs.size() == vertices.size()
			for index in vertices.size():
				geometry_valid = geometry_valid and vertices[index].is_finite() and normals[index].is_finite() and normals[index].length() > 0.99 and uvs[index].is_finite()
			for index in range(0, vertices.size(), 3):
				var a := vertices[index]
				var b := vertices[index + 1]
				var c := vertices[index + 2]
				geometry_valid = geometry_valid and (b - a).cross(c - a).dot(normals[index]) < 0.0
				geometry_valid = geometry_valid and absf((uvs[index + 1] - uvs[index]).cross(uvs[index + 2] - uvs[index])) > 0.00000001
				# Sample the outer dial ticks from the real pilot eye, including
				# the off-axis far rim, against every new opaque mounting face.
				for side in [-1.0, 1.0]:
					for sample in 24:
						var angle := TAU * float(sample) / 24.0
						var target := cluster.to_global(Vector3(side * 0.57 + cos(angle) * 0.116, 0.08 + sin(angle) * 0.116, 0.165))
						clear_dials = clear_dials and Geometry3D.segment_intersects_triangle(stock.to_local(camera.global_position), stock.to_local(target), a, b, c) == null
	_check(geometry_valid, "instrument stock retains outward winding, finite unit normals and nonsingular UVs")
	_check(clear_dials, "both complete dial sweeps clear the new mounting geometry from the authored pilot eye")
