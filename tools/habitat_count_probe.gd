extends SceneTree

## Counts the built Habitat Spine so budget re-freezes are measured, not guessed.
## Safe to run with `--headless`: it never asks for a frame.

const MODULE_SCENE := preload("res://scenes/world/modules/habitat_spine.tscn")


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var module := MODULE_SCENE.instantiate()
	root.add_child(module)
	await process_frame
	var performance: Dictionary = module.call("get_performance_contract")
	print("PERF ", JSON.stringify(performance, "  "))
	var roster: Dictionary = module.call("get_component_roster")
	print("ROSTER meshes=%s bodies=%s shapes=%s lights=%s" % [
		roster.get("mesh_instances", "?"),
		roster.get("static_bodies", "?"),
		roster.get("collision_shapes", "?"),
		roster.get("lights", "?"),
	])
	var mapped := 0
	var by_scale := {}
	for candidate in module.find_children("*", "MeshInstance3D", true, false):
		var mesh_instance := candidate as MeshInstance3D
		var material := mesh_instance.material_override as StandardMaterial3D
		if material == null or material.albedo_texture == null or not material.uv1_triplanar:
			continue
		mapped += 1
		var key := "%.2f" % material.uv1_scale.x
		by_scale[key] = int(by_scale.get(key, 0)) + 1
	print("TRIPLANAR mapped=%d by_scale=%s" % [mapped, JSON.stringify(by_scale)])
	print("VALIDATION ", module.call("get_validation_errors"))
	module.queue_free()
	await process_frame
	quit(0)
