extends SceneTree

## Per-ring breakdown of what `TorusGeometryBudget` does to the production scene.
##
## The whole-scene census in `tools/geometry_census.gd` reports `TorusMesh` as a
## single row. That row is what identified rings and collars as the worst
## value-per-triangle in the project, but it cannot show the thing that actually
## matters about them: that a 148-metre moonlet ring and a 10-centimetre pipe
## clamp are the same class of object and must not get the same tessellation.
## This tool prints every ring with the world-space radii the budget reads, the
## tessellation its builder authored, and the tessellation the budget chose.
##
## Both columns come from one build of the world, via
## `TorusGeometryBudget.restore_authored`, so nothing here is a reconstruction.
##
## Usage:
##   godot --headless --audio-driver Dummy --script res://tools/torus_census.gd

const MAIN_SCENE := preload("res://scenes/main.tscn")

var _rows: Array = []


func _initialize() -> void:
	_run()


func _run() -> void:
	var game := MAIN_SCENE.instantiate()
	root.add_child(game)
	for _frame in 8:
		await process_frame
	await physics_frame
	await process_frame

	# The world budgets itself as it comes up, so this pass reads the result.
	_walk(game, "", "budgeted")
	# ...and this one reads what the builders asked for.
	TorusGeometryBudget.restore_authored(game)
	_walk(game, "", "authored")

	_report()
	game.queue_free()
	await process_frame
	quit(0)


func _walk(node: Node, path: String, phase: String) -> void:
	var here := path
	if here != "":
		here += "/"
	here += String(node.name)
	var instance := node as MeshInstance3D
	if instance != null:
		var mesh := instance.mesh as TorusMesh
		if mesh != null:
			if phase == "budgeted":
				var basis := instance.global_transform.basis
				var world_scale := maxf(maxf(basis.x.length(), basis.y.length()), basis.z.length())
				_rows.append({
					"path": here,
					"world_outer": mesh.outer_radius * world_scale,
					"world_tube": (mesh.outer_radius - mesh.inner_radius) * 0.5 * world_scale,
					"new_rings": mesh.rings,
					"new_segments": mesh.ring_segments,
				})
			else:
				for row in _rows:
					if String(row["path"]) == here:
						row["rings"] = mesh.rings
						row["segments"] = mesh.ring_segments
						break
	for child in node.get_children():
		_walk(child, here, phase)


func _report() -> void:
	_rows.sort_custom(func(a, b): return float(a["world_outer"]) > float(b["world_outer"]))
	var total := 0
	var new_total := 0
	var untouched := 0
	print("")
	print("%11s %10s %11s %13s %14s  %s" % [
		"world_outer", "world_tube", "rings", "ring_segments", "triangles", "path",
	])
	for row in _rows:
		var rings := int(row.get("rings", row["new_rings"]))
		var segments := int(row.get("segments", row["new_segments"]))
		var before := rings * segments * 2
		var after := int(row["new_rings"]) * int(row["new_segments"]) * 2
		total += before
		new_total += after
		if before == after:
			untouched += 1
		print("%11.3f %10.4f %5d -> %-3d %6d -> %-4d %5d -> %-6d  %s" % [
			float(row["world_outer"]), float(row["world_tube"]),
			rings, int(row["new_rings"]), segments, int(row["new_segments"]),
			before, after, String(row["path"]),
		])
	print("")
	print("torus meshes: %d (%d left exactly as authored)" % [_rows.size(), untouched])
	print("triangles: %d -> %d (%.1f%% cut, %d saved)" % [
		total, new_total,
		0.0 if total == 0 else 100.0 * float(total - new_total) / float(total),
		total - new_total,
	])
