extends SceneTree

## Exercise the real production physics branch after automatic engine shutdown.
var _failures: Array[String] = []

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var stage := Node3D.new()
	root.add_child(stage)
	var wall := StaticBody3D.new()
	wall.collision_layer = PhysicsLayers.WORLD_BODY_LAYER
	var wall_shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(100.0, 100.0, 2.0)
	wall_shape.shape = box
	wall.add_child(wall_shape)
	stage.add_child(wall)
	var ship := (load("res://scenes/ships/torrent_interceptor.tscn") as PackedScene).instantiate() as HeroShip
	ship.position = Vector3(0.0, 0.0, 200.0)
	stage.add_child(ship)
	ship.set_piloted(true)
	ship.engine_start_time = 0.01
	ship.request_engine_start()
	ship.velocity = Vector3.FORWARD * 80.0
	var idled_before_contact := false
	var collided := false
	for tick in 250:
		await physics_frame
		var telemetry := ship.get_telemetry()
		if telemetry.engine_state == HeroShip.ENGINE_OFFLINE and ship.position.z > 20.0:
			idled_before_contact = true
		if ship.get_slide_collision_count() > 0:
			collided = true
			break
	_check(idled_before_contact, "engine automatically idles before the coasting impact")
	_check(collided, "production collision hull reaches the static wall")
	_check(float(ship.get_telemetry().hull) < ship.maximum_hull, "unpowered real impact damages the hull")
	var hull_after_contact := float(ship.get_telemetry().hull)
	for tick in 10:
		await physics_frame
	_check(is_equal_approx(float(ship.get_telemetry().hull), hull_after_contact), "resting contact does not apply repeated damage")
	stage.queue_free()
	await process_frame
	print("HERO_COASTING_COLLISION_TEST: %d failures" % _failures.size())
	quit(0 if _failures.is_empty() else 1)

func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
		push_error(message)
