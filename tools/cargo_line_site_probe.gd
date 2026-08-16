extends SceneTree

## Placement probe for candidate cargo transfer line sites.
##
## The station's own audits cannot answer this question: `audit_production_roster`
## is a pure budget count, and the only spatial clearance test in the lattice
## suite is against berth landing volumes. Nothing checks an activity envelope
## against the station's own masts, portal legs, rails and props — which is how
## the live `CentralCargoTransferLine` ended up with a structural column standing
## inside its rail. This probe asks the built world directly.
##
## Usage:
##   godot --headless --audio-driver Dummy --script res://tools/cargo_line_site_probe.gd
##
## Candidates are given as `KETH_SITE_CANDIDATES`, a `;`-separated list of
## `name,cx,cy,cz,hx,hy,hz` world AABB centres and half extents.

const MAIN_SCENE := preload("res://scenes/main.tscn")


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var game := MAIN_SCENE.instantiate()
	root.add_child(game)
	for _frame in 8:
		await process_frame
	var world := game.get_node_or_null(^"ShipyardWorld") as Node3D
	if world == null:
		printerr("SITE_PROBE: no ShipyardWorld")
		quit(1)
		return

	for row in OS.get_environment("KETH_SITE_CANDIDATES").split(";", false):
		var parts := row.split(",", false)
		if parts.size() != 7:
			continue
		var centre := Vector3(parts[1].to_float(), parts[2].to_float(), parts[3].to_float())
		var half := Vector3(parts[4].to_float(), parts[5].to_float(), parts[6].to_float())
		var envelope := AABB(centre - half, half * 2.0)
		print("=== ", parts[0], " ", envelope)
		_report_overlaps(world, envelope)
		_report_support(world, envelope)
		_report_berth_gaps(world, envelope)
	quit(0)


func _report_overlaps(world: Node3D, envelope: AABB) -> void:
	var hits := PackedStringArray()
	for candidate in world.find_children("*", "MeshInstance3D", true, false):
		var mesh_instance := candidate as MeshInstance3D
		if (
			mesh_instance.mesh == null
			or not mesh_instance.is_inside_tree()
			or not mesh_instance.is_visible_in_tree()
		):
			continue
		if _is_activity_owned(mesh_instance):
			continue
		var box := (mesh_instance.global_transform * mesh_instance.mesh.get_aabb()).abs()
		if not envelope.intersects(box):
			continue
		# Decks the line is meant to stand on are reported separately.
		if box.end.y <= envelope.position.y + 0.05:
			continue
		hits.append("%s %s" % [mesh_instance.name, box])
	hits.sort()
	print("  overlaps(", hits.size(), "): ", hits)


func _report_support(world: Node3D, envelope: AABB) -> void:
	var space := world.get_world_3d().direct_space_state
	var missing := PackedStringArray()
	var lowest := 1000.0
	var highest := -1000.0
	for corner in 4:
		var x: float = envelope.position.x + (envelope.size.x if corner & 1 else 0.0)
		var z: float = envelope.position.z + (envelope.size.z if corner & 2 else 0.0)
		var ray := PhysicsRayQueryParameters3D.create(
			Vector3(x, envelope.position.y + 0.4, z),
			Vector3(x, envelope.position.y - 2.5, z),
			1
		)
		var hit := space.intersect_ray(ray)
		if hit.is_empty():
			missing.append("%0.2f,%0.2f" % [x, z])
		else:
			var y := (hit.position as Vector3).y
			lowest = minf(lowest, y)
			highest = maxf(highest, y)
			print("    support %0.2f,%0.2f -> y=%0.3f on %s" % [x, z, y, (hit.collider as Node).name])
	print("  unsupported corners: ", missing, " support spread=", highest - lowest)


func _report_berth_gaps(world: Node3D, envelope: AABB) -> void:
	var worst := 1000.0
	var worst_id := ""
	for candidate in world.get_parent().find_children("*", "Node3D", true, false):
		var berth := candidate as Node3D
		if not berth.has_method("get_landing_half_extents") or not berth.is_inside_tree():
			continue
		var half: Vector3 = berth.call("get_landing_half_extents")
		var dock: Transform3D = berth.call("get_dock_transform")
		var volume := (dock * AABB(-half, half * 2.0)).abs()
		var gap := _gap_between(envelope, volume)
		if gap < worst:
			worst = gap
			worst_id = str(berth.name)
	print("  nearest berth landing volume: ", worst_id, " gap=", worst)
	for candidate in world.get_parent().find_children("*", "Node3D", true, false):
		var berth := candidate as Node3D
		if not berth.has_method("get_landing_half_extents") or not berth.is_inside_tree():
			continue
		var half: Vector3 = berth.call("get_landing_half_extents")
		var dock: Transform3D = berth.call("get_dock_transform")
		print("    berth ", berth.name, " dock=", (dock * AABB(-half, half * 2.0)).abs(), " gap=", _gap_between(envelope, (dock * AABB(-half, half * 2.0)).abs()))


func _gap_between(first: AABB, second: AABB) -> float:
	var dx := maxf(first.position.x - second.end.x, second.position.x - first.end.x)
	var dy := maxf(first.position.y - second.end.y, second.position.y - first.end.y)
	var dz := maxf(first.position.z - second.end.z, second.position.z - first.end.z)
	if dx <= 0.0 and dy <= 0.0 and dz <= 0.0:
		return maxf(maxf(dx, dy), dz)
	return Vector3(maxf(dx, 0.0), maxf(dy, 0.0), maxf(dz, 0.0)).length()


func _is_activity_owned(node: Node) -> bool:
	var current := node
	while current != null:
		if current is StationOperationsActivity:
			return true
		current = current.get_parent()
	return false
