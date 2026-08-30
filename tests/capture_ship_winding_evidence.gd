extends SceneTree

## Before/after visual evidence for the ship procedural-surface winding fixes.
##
## Instantiates the four original production craft, lights them with a single key
## plus a weak fill, and renders hull / cockpit / engine framings from angles
## where a reversed rounded box, closed-loft sidewall, or end cap reads hollow.
##
## Run with `MUDDS_WINDING_EVIDENCE_LABEL=before` or `=after`.

const SHIP_SCENES := {
	"torrent": "res://scenes/ships/torrent_interceptor.tscn",
	"arrow": "res://scenes/ships/arrow_recon_ship.tscn",
	"zenith": "res://scenes/ships/zenith_interceptor.tscn",
	"jovian": "res://scenes/ships/jovian_light_freighter.tscn",
}

const RESOLUTION := Vector2i(1280, 800)

# name -> [azimuth degrees, elevation degrees, distance multiplier, height fraction of aabb]
const VIEWS := {
	"hull_three_quarter": [38.0, 16.0, 1.85, 0.5],
	"cockpit_exterior": [155.0, 12.0, 0.78, 0.72],
	"engine_cluster": [-25.0, 10.0, 0.85, 0.5],
	"dorsal": [0.0, 78.0, 1.7, 0.5],
}


func _init() -> void:
	call_deferred("_run")


func _visual_aabb(node: Node) -> AABB:
	var box := AABB()
	var seeded := false
	for child in node.find_children("*", "VisualInstance3D", true, false):
		var visual := child as VisualInstance3D
		if visual == null or not visual.is_visible_in_tree():
			continue
		var local := visual.get_aabb()
		if local.size == Vector3.ZERO:
			continue
		var global := visual.global_transform * local
		if not seeded:
			box = global
			seeded = true
		else:
			box = box.merge(global)
	return box


func _run() -> void:
	var label := OS.get_environment("MUDDS_WINDING_EVIDENCE_LABEL")
	if label == "":
		label = "unlabelled"
	var out_dir := "res://artifacts/ship_winding_evidence/%s" % label
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out_dir))

	var viewport := root
	viewport.size = RESOLUTION

	var world := Node3D.new()
	root.add_child(world)

	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(0.06, 0.07, 0.09)
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.16, 0.18, 0.22)
	environment.ambient_light_energy = 0.35
	var world_env := WorldEnvironment.new()
	world_env.environment = environment
	world.add_child(world_env)

	var key := DirectionalLight3D.new()
	key.light_energy = 2.6
	key.rotation_degrees = Vector3(-38.0, -46.0, 0.0)
	world.add_child(key)

	var fill := DirectionalLight3D.new()
	fill.light_energy = 0.5
	fill.light_color = Color(0.72, 0.80, 1.0)
	fill.rotation_degrees = Vector3(-14.0, 148.0, 0.0)
	world.add_child(fill)

	var camera := Camera3D.new()
	camera.fov = 42.0
	camera.current = true
	world.add_child(camera)

	var written: Array[String] = []
	for ship_key: String in SHIP_SCENES:
		var packed := load(SHIP_SCENES[ship_key]) as PackedScene
		if packed == null:
			push_error("could not load %s" % SHIP_SCENES[ship_key])
			continue
		var ship := packed.instantiate()
		world.add_child(ship)
		var ship_3d := ship as Node3D
		if ship_3d != null:
			ship_3d.global_position = Vector3.ZERO
		if ship.has_method("set_physics_process"):
			ship.set_physics_process(false)
			ship.set_process(false)
		await process_frame
		await process_frame
		await process_frame

		var box := _visual_aabb(ship)
		var centre := box.get_center()
		var radius := maxf(box.size.length() * 0.5, 0.5)

		for view_name: String in VIEWS:
			var spec: Array = VIEWS[view_name]
			var azimuth: float = deg_to_rad(spec[0])
			var elevation: float = deg_to_rad(spec[1])
			var distance: float = radius * float(spec[2]) + 1.0
			var target := centre + Vector3(0.0, (float(spec[3]) - 0.5) * box.size.y, 0.0)
			var offset := Vector3(
				sin(azimuth) * cos(elevation),
				sin(elevation),
				cos(azimuth) * cos(elevation)
			) * distance
			camera.global_position = target + offset
			camera.look_at(target, Vector3.UP)
			camera.near = maxf(0.05, distance * 0.01)
			camera.far = distance * 8.0 + 200.0
			await process_frame
			await process_frame
			var image := viewport.get_texture().get_image()
			var path := "%s/%s_%s.png" % [out_dir, ship_key, view_name]
			image.save_png(ProjectSettings.globalize_path(path))
			written.append(path)
			print("wrote ", path)

		world.remove_child(ship)
		ship.queue_free()
		await process_frame

	print("WINDING_EVIDENCE_WROTE %d" % written.size())
	quit(0)
