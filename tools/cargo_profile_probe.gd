extends SceneTree

## Measures a freshly built `StationOperationsActivity` profile so its frozen
## budget row can be re-frozen against a live build rather than against
## arithmetic. Also reports every drawn and instanced piece's local bounds, which
## is how the published envelope is checked before it is written down.
##
##   godot --headless --audio-driver Dummy --script res://tools/cargo_profile_probe.gd

const ACTIVITY_SCENE := preload("res://scenes/world/components/station_operations_activity.tscn")


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	for profile in [
		StationOperationsActivity.ActivityProfile.CARGO_LINE,
		StationOperationsActivity.ActivityProfile.CARGO_LINE_LONG,
	]:
		var activity := ACTIVITY_SCENE.instantiate() as StationOperationsActivity
		activity.activity_profile = profile
		activity.variation_seed = 5507
		root.add_child(activity)
		await process_frame
		var audit := activity.get_audit_report()
		print("=== ", activity.get_activity_profile_id())
		print("  valid=", audit.valid, " errors=", audit.errors)
		print("  counts=", (audit.performance as Dictionary).counts)
		print("  equipment=", audit.equipment)
		var extremes := AABB()
		var first := true
		for candidate in activity.find_children("*", "MeshInstance3D", true, false):
			var mesh_instance := candidate as MeshInstance3D
			var box := (
				activity.global_transform.affine_inverse()
				* mesh_instance.global_transform
				* mesh_instance.mesh.get_aabb()
			).abs()
			extremes = box if first else extremes.merge(box)
			first = false
		for candidate in activity.find_children("*", "MultiMeshInstance3D", true, false):
			var batch := candidate as MultiMeshInstance3D
			for index in batch.multimesh.instance_count:
				var box := (
					activity.global_transform.affine_inverse()
					* batch.global_transform
					* (activity.call("_batch_transforms", batch)[index] as Transform3D)
					* batch.multimesh.mesh.get_aabb()
				).abs()
				extremes = extremes.merge(box)
		print("  static local bounds=", extremes)
		# Movers are photographed across their whole cycle, because the envelope
		# has to hold at every phase and not only at t = 0.
		var moving := extremes
		for step in 240:
			activity.set_activity_time(float(step) * 0.25)
			for candidate in activity.find_children("Animated*", "Node3D", true, false):
				for mesh_candidate in candidate.find_children("*", "MeshInstance3D", true, false):
					var mesh_instance := mesh_candidate as MeshInstance3D
					moving = moving.merge((
						activity.global_transform.affine_inverse()
						* mesh_instance.global_transform
						* mesh_instance.mesh.get_aabb()
					).abs())
				for batch_candidate in candidate.find_children("*", "MultiMeshInstance3D", true, false):
					var batch := batch_candidate as MultiMeshInstance3D
					for index in batch.multimesh.instance_count:
						moving = moving.merge((
							activity.global_transform.affine_inverse()
							* batch.global_transform
							* (activity.call("_batch_transforms", batch)[index] as Transform3D)
							* batch.multimesh.mesh.get_aabb()
						).abs())
		print("  bounds over 60 s of motion=", moving)
		activity.set_activity_time(0.0)
		print("  solid volumes=", activity.get_solid_volume_contract().size())
		root.remove_child(activity)
		activity.free()
	quit(0)
