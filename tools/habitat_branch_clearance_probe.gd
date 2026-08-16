extends SceneTree

## Reports every drawn world mesh whose AABB enters the volume a habitat side
## branch would occupy, so the decision to build there is made against the live
## scene rather than against the scene file's node list.
##
## Safe headless: never asks for a frame.

const MAIN_SCENE := preload("res://scenes/main.tscn")


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var game := MAIN_SCENE.instantiate()
	root.add_child(game)
	await process_frame
	await physics_frame
	var world := game.get_node_or_null(^"ShipyardWorld") as Node3D
	var habitat := world.call("get_habitat_spine") as Node3D
	print("HABITAT_XFORM ", habitat.global_transform)
	# Candidate branch volume, expressed in habitat-local metres and converted.
	var probe := AABB(Vector3(58.0, -4.0, -9.0), Vector3(26.0, 16.0, 17.0))
	print("PROBE_WORLD_AABB ", probe)
	var hits := {}
	for candidate in world.find_children("*", "MeshInstance3D", true, false):
		var mesh_instance := candidate as MeshInstance3D
		if not mesh_instance.is_visible_in_tree() or mesh_instance.mesh == null:
			continue
		var box := mesh_instance.global_transform * mesh_instance.mesh.get_aabb()
		if not box.intersects(probe):
			continue
		var owner_path := str(world.get_path_to(mesh_instance))
		var top := owner_path.split("/")[0]
		hits[top] = int(hits.get(top, 0)) + 1
		if int(hits[top]) <= 2:
			print("  HIT %s  aabb=%s" % [owner_path, box])
	print("PROBE_HIT_GROUPS ", hits)
	game.queue_free()
	await process_frame
	quit(0)
