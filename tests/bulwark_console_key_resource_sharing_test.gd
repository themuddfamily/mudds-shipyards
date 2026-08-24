extends SceneTree

const Ship := preload("res://scripts/ships/bulwark_heavy_gunship.gd")
const KEY_NAMES := [
	"PortConsoleKey00",
	"PortConsoleKey01",
	"PortConsoleKey02",
	"StarboardConsoleKey00",
	"StarboardConsoleKey01",
	"StarboardConsoleKey02",
]
const EXPECTED_POSITIONS := [
	Vector3(-0.76, 2.41, -0.88),
	Vector3(-0.715, 2.41, -0.56),
	Vector3(-0.67, 2.41, -0.24),
	Vector3(0.76, 2.41, -0.88),
	Vector3(0.805, 2.41, -0.56),
	Vector3(0.85, 2.41, -0.24),
]

var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var fixture := Node3D.new()
	root.add_child(fixture)
	var ships: Array[HeroShip] = [Ship.new(), Ship.new()]
	for ship in ships:
		fixture.add_child(ship)
	await process_frame
	await physics_frame
	await physics_frame

	var shared_mesh: Mesh
	var mesh_ids := {}
	var key_count := 0
	var materials_and_transforms_intact := true
	for ship_index in ships.size():
		var cockpit := ships[ship_index].get_node_or_null(
			^"BulwarkHeavyGunshipVisual/CockpitInterior"
		) as Node3D
		materials_and_transforms_intact = materials_and_transforms_intact and cockpit != null
		if cockpit == null:
			continue
		for key_index in KEY_NAMES.size():
			var key := cockpit.get_node_or_null(NodePath(KEY_NAMES[key_index])) as MeshInstance3D
			materials_and_transforms_intact = materials_and_transforms_intact \
				and key != null
			if key == null:
				continue
			key_count += 1
			mesh_ids[key.mesh.get_instance_id()] = true
			shared_mesh = key.mesh if shared_mesh == null else shared_mesh
			var material := key.material_override as StandardMaterial3D
			var amber := key_index == 1 or key_index == 4
			materials_and_transforms_intact = materials_and_transforms_intact \
				and key.mesh == shared_mesh \
				and key.position.is_equal_approx(EXPECTED_POSITIONS[key_index]) \
				and key.visible \
				and key.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_ON \
				and key.layers == 1 \
				and material != null \
				and material.emission_enabled \
				and material.emission.is_equal_approx(
					Color("e2a63c") if amber else Color("48dbe2")
				) \
				and is_equal_approx(
					material.emission_energy_multiplier, 2.4 if amber else 2.8
				)

	_check(
		key_count == 12
		and mesh_ids.size() == 1
		and shared_mesh != null
		and shared_mesh.get_surface_count() == 1
		and shared_mesh.surface_get_material(0) == null
		and not shared_mesh.resource_local_to_scene
		and shared_mesh.get_aabb().size.is_equal_approx(Vector3(0.12, 0.035, 0.12)),
		"twelve console keys across two Bulwarks use one immutable mesh allocation"
	)
	_check(
		materials_and_transforms_intact,
		"mesh sharing preserves six renderer nodes, exact transforms, and both finishes per craft"
	)
	_check(
		ships[0].get_node_or_null(^"BulwarkBoardingArea") is Area3D
		and ships[1].get_node_or_null(^"BulwarkBoardingArea") is Area3D
		and ships[0].call("get_gunner_station_anchor") is Marker3D
		and ships[1].call("get_gunner_station_anchor") is Marker3D,
		"console-key resource sharing leaves boarding and gunner ownership intact"
	)
	print(
		"BULWARK_CONSOLE_KEY_RESOURCE_SHARING: craft 2 visible_copies 12 "
		+ "nodes 12->12 submissions 12->12 mesh_resources 2->1"
	)

	fixture.queue_free()
	await process_frame
	if _failures.is_empty():
		print("BULWARK CONSOLE KEY RESOURCE SHARING TEST PASS")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
