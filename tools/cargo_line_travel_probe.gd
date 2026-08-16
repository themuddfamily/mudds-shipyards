extends SceneTree

## Mid-travel clearance probe for the cargo transfer lines.
##
## Both defects this family has produced were invisible at rest and only appeared
## while a mover was moving: a hoist carriage that left its own beam when it
## dipped, and a sled that sank through its rail. A still render cannot rule
## either out, and neither can a single-frame audit. This walks the whole travel
## in 0.25 s steps and reports the worst case of each relationship.
##
##   godot --headless --audio-driver Dummy --script res://tools/cargo_line_travel_probe.gd

const MAIN_SCENE := preload("res://scenes/main.tscn")

const STEP_SECONDS := 0.25
const STEPS := 400


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var game := MAIN_SCENE.instantiate()
	root.add_child(game)
	for _frame in 6:
		await process_frame

	var failures := PackedStringArray()
	for candidate in game.find_children("*", "StationOperationsActivity", true, false):
		var activity := candidate as StationOperationsActivity
		var profile := str(activity.get_activity_profile_id())
		if not profile.begins_with("cargo_line"):
			continue
		var long_line := profile == "cargo_line_long"
		var worst_rail_gap := 1000.0
		var worst_bridge_overlap := 1000.0
		var worst_hook_clearance := 1000.0
		var worst_sled_stop_gap := 1000.0
		var worst_sled_crate_gap := 1000.0
		var worst_sled_post_gap := 1000.0
		var lowest_point := 1000.0
		for step in STEPS:
			activity.set_activity_time(float(step) * STEP_SECONDS)
			var rails := _boxes(activity, ["RailBeam"])
			var stops := _boxes(activity, ["RailStop"])
			var crates := _boxes(activity, ["Crate"])
			var posts := _boxes(activity, ["HoistPost", "HoistRail", "HoistBeam"])
			var hoist_rails := _boxes(activity, ["HoistRail", "HoistBeam"])
			var sled := _merged(activity, ["SledDeck", "SledSkirt", "SledContainer", "ContainerManifest", "SledStrobe"])
			var wheels := _merged(activity, ["SledWheel"])
			var bridge := _merged(activity, ["HoistBridge", "HoistCarriage"])
			var hook := _merged(activity, ["HoistHook"])
			var container := _merged(activity, ["SledContainer"])

			# The sled must ride on the rail heads, never through them.
			var rail_top := -1000.0
			for rail in rails:
				rail_top = maxf(rail_top, rail.end.y)
			if long_line:
				worst_rail_gap = minf(worst_rail_gap, wheels.position.y - (rail_top - 0.1))
			else:
				worst_rail_gap = minf(worst_rail_gap, wheels.position.y - (rail_top - 0.1))

			# The travelling bridge must always share space with a rail it rides.
			var overlap := -1000.0
			for rail in hoist_rails:
				if bridge.intersects(rail):
					overlap = maxf(overlap, minf(bridge.end.y, rail.end.y) - maxf(bridge.position.y, rail.position.y))
			worst_bridge_overlap = minf(worst_bridge_overlap, overlap)

			# The hook must clear the container it passes over.
			if hook.size.y > 0.0 and container.size.y > 0.0:
				if _overlaps_xz(hook, container):
					worst_hook_clearance = minf(worst_hook_clearance, hook.position.y - container.end.y)

			worst_sled_stop_gap = minf(worst_sled_stop_gap, _gap_to_all(sled, stops))
			worst_sled_crate_gap = minf(worst_sled_crate_gap, _gap_to_all(sled, crates))
			worst_sled_post_gap = minf(worst_sled_post_gap, _gap_to_all(sled, posts))
			lowest_point = minf(lowest_point, minf(wheels.position.y, sled.position.y))
		activity.set_activity_time(0.0)

		print("=== ", activity.name, " (", profile, ")")
		print("  wheel tread above rail head        : %+0.4f" % worst_rail_gap)
		print("  bridge/beam vertical overlap (min) : %+0.4f" % worst_bridge_overlap)
		print("  hook above container roof (min)    : %+0.4f" % worst_hook_clearance)
		print("  sled to rail stop (min)            : %+0.4f" % worst_sled_stop_gap)
		print("  sled to crate stack (min)          : %+0.4f" % worst_sled_crate_gap)
		print("  sled to gantry (min)               : %+0.4f" % worst_sled_post_gap)
		print("  lowest mover point above mount     : %+0.4f" % lowest_point)
		if worst_rail_gap < -0.001:
			failures.append("%s sled sinks through its rail" % activity.name)
		if worst_bridge_overlap <= 0.0:
			failures.append("%s hoist leaves its beam" % activity.name)
		if worst_hook_clearance < 0.0:
			failures.append("%s hook passes through the container" % activity.name)
		if minf(worst_sled_stop_gap, minf(worst_sled_crate_gap, worst_sled_post_gap)) < 0.0:
			failures.append("%s sled intersects fixed structure" % activity.name)
		if lowest_point < -0.001:
			failures.append("%s mover drops below its mount plane" % activity.name)
		_report_static_interpenetration(activity)
	print("CARGO_TRAVEL_PROBE_FAILURES: ", failures)
	quit(0 if failures.is_empty() else 1)


## Every pair of static pieces that shares space, deepest first.
##
## Overlap is not automatically a defect here — a crate resting on a crate, a
## gantry rail bearing on its posts and a manifest plate stuck to a container all
## overlap on purpose, and are meant to, because a zero-overlap seat is what
## produces a floating object the moment anything moves by a millimetre. What
## this exists to surface is the other kind: a 2.9 m post standing *through* a
## crate stack, which is what x = -9.6 produced and what no other audit noticed.
## The rule of thumb is that a seat overlaps in one axis by a few centimetres,
## and a clip overlaps in all three by a lot.
func _report_static_interpenetration(activity: Node3D) -> void:
	var pieces: Array = []
	for candidate in activity.find_children("*", "MeshInstance3D", true, false):
		var mesh_instance := candidate as MeshInstance3D
		if mesh_instance.mesh == null:
			continue
		var mover := false
		var walker: Node = mesh_instance
		while walker != null and walker != activity:
			if str(walker.name).begins_with("Animated"):
				mover = true
			walker = walker.get_parent()
		if mover:
			continue
		pieces.append({
			"name": str(mesh_instance.name),
			"box": (mesh_instance.global_transform * mesh_instance.mesh.get_aabb()).abs(),
		})
	var rows: Array = []
	for first in pieces.size():
		for second in range(first + 1, pieces.size()):
			var a := pieces[first]["box"] as AABB
			var b := pieces[second]["box"] as AABB
			if not a.intersects(b):
				continue
			var overlap := Vector3(
				minf(a.end.x, b.end.x) - maxf(a.position.x, b.position.x),
				minf(a.end.y, b.end.y) - maxf(a.position.y, b.position.y),
				minf(a.end.z, b.end.z) - maxf(a.position.z, b.position.z)
			)
			rows.append({
				"depth": minf(minf(overlap.x, overlap.y), overlap.z),
				"text": "%s / %s overlap=%v" % [pieces[first]["name"], pieces[second]["name"], overlap],
			})
	rows.sort_custom(func(x, y): return float(x["depth"]) > float(y["depth"]))
	print("  static overlaps (deepest 8 of %d):" % rows.size())
	for index in mini(8, rows.size()):
		print("    %+0.3f  %s" % [float(rows[index]["depth"]), rows[index]["text"]])


func _boxes(activity: Node3D, prefixes: Array) -> Array[AABB]:
	var result: Array[AABB] = []
	for candidate in activity.find_children("*", "MeshInstance3D", true, false):
		var mesh_instance := candidate as MeshInstance3D
		if mesh_instance.mesh == null:
			continue
		for prefix: String in prefixes:
			if mesh_instance.name.begins_with(prefix):
				result.append(
					(mesh_instance.global_transform * mesh_instance.mesh.get_aabb()).abs()
				)
				break
	return result


func _merged(activity: Node3D, prefixes: Array) -> AABB:
	var boxes := _boxes(activity, prefixes)
	# `SledWheel` is instanced on the long run, so its bodies are not
	# `MeshInstance3D` nodes; fall back to the batch's own authored transforms.
	if boxes.is_empty():
		for candidate in activity.find_children("*", "MultiMeshInstance3D", true, false):
			var batch := candidate as MultiMeshInstance3D
			for prefix: String in prefixes:
				if not batch.name.begins_with(prefix):
					continue
				var authored: Array = activity.call("_batch_transforms", batch)
				for instance_transform: Transform3D in authored:
					boxes.append((
						batch.global_transform
						* instance_transform
						* batch.multimesh.mesh.get_aabb()
					).abs())
	if boxes.is_empty():
		return AABB()
	var merged := boxes[0]
	for index in range(1, boxes.size()):
		merged = merged.merge(boxes[index])
	return merged


func _overlaps_xz(first: AABB, second: AABB) -> bool:
	return (
		first.position.x < second.end.x and second.position.x < first.end.x
		and first.position.z < second.end.z and second.position.z < first.end.z
	)


func _gap_to_all(box: AABB, others: Array[AABB]) -> float:
	var worst := 1000.0
	for other in others:
		var dx := maxf(box.position.x - other.end.x, other.position.x - box.end.x)
		var dy := maxf(box.position.y - other.end.y, other.position.y - box.end.y)
		var dz := maxf(box.position.z - other.end.z, other.position.z - box.end.z)
		var gap := maxf(maxf(dx, dy), dz)
		worst = minf(worst, gap)
	return worst
