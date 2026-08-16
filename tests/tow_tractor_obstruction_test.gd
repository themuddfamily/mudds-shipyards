extends SceneTree

## The playtest report, turned into a vehicle that has to stop.
##
## > "So Im just looking at the tow truck and it drives well but the collision
## > logic isn't fully there - if I drive into a spaceship I just clip through
## > it... the same with certain poles"
##
## Two separate causes sat behind that one sentence, and this suite drives the
## real vehicle into one of each in `res://scenes/main.tscn` rather than asserting
## anything about layer arithmetic:
##
## 1. **The hulls.** Every craft body is on `SHIP`; the tractor masked `WORLD`
##    alone, so no hull could stop it. Fixed in `PhysicsLayers.GROUND_VEHICLE_BODY_MASK`.
## 2. **The poles.** `StationOperationsActivity` created no collision node of any
##    kind, and the `FULL` vignette four metres from the tractor's parking spot
##    draws four 5.5 m maintenance-gantry columns. Fixed by giving that component's
##    `get_solid_volume_contract()` naming its gantry columns, which the world
##    already realises as World-layer bodies for every volume a vignette declares.
##
## Every case is run twice. The green run drives the shipped vehicle at the
## obstacle and requires it to end up outside; the red witness re-runs the exact
## same drive with only the fix undone — the mask reverted to `WORLD`, or the
## vignette's collision layer cleared — and requires the vehicle to end up inside.
## Without the red half, a tractor that simply failed to move would pass every
## green assertion in this file.

const MAIN_SCENE := preload("res://scenes/main.tscn")

## How far in front of an obstacle the tractor starts. Long enough to be at real
## speed on contact, short enough that nothing else gets between them.
const APPROACH_GAP := 7.0
const DRIVE_TICKS := 150
const SETTLE_TICKS := 8

var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var game := MAIN_SCENE.instantiate() as GameFlow
	_check(game != null, "the production scene instantiates")
	if game == null:
		_finish()
		return
	root.add_child(game)
	await _advance(4)

	var world := game.get_node("ShipyardWorld") as ShipyardWorld
	var tractor := game.get_tow_tractor()
	_check(tractor != null and world != null, "the production world ships a drivable tow tractor")
	if tractor == null or world == null:
		await _clean_up(game)
		_finish()
		return

	_test_declared_contract(tractor)
	await _test_drives_into_a_hull(game, tractor)
	await _test_drives_into_a_gantry_column(game, world, tractor)
	await _test_drives_up_aft_ramp_into_workpost(world, tractor)
	await _test_the_tractor_took_no_authority(game, world, tractor)

	await _clean_up(game)
	_finish()


## The shipped vehicle uses the published ground-vehicle contract, not a literal
## composed at the call site.
func _test_declared_contract(tractor: TowTractor) -> void:
	_check(
		tractor.collision_layer == PhysicsLayers.GROUND_VEHICLE_BODY_LAYER
		and tractor.collision_mask == PhysicsLayers.GROUND_VEHICLE_BODY_MASK,
		"the live tractor body carries the published ground-vehicle layer and mask"
	)
	_check(
		(tractor.collision_mask & PhysicsLayers.SHIP) != 0,
		"the live tractor masks the Ship layer used by all five parked craft"
	)
	_check(
		(tractor.collision_mask & PhysicsLayers.PLAYER) == 0,
		"the live tractor still refuses to solve against a walking player"
	)


## Group 1: the spaceship half of the report.
func _test_drives_into_a_hull(game: GameFlow, tractor: TowTractor) -> void:
	var torrent := game.get_node_or_null(^"TorrentInterceptor") as CharacterBody3D
	_check(torrent != null, "the guided Torrent resolves as the hull to drive into")
	if torrent == null:
		return
	var hull := _body_world_aabb(torrent)
	_check(hull.size.length() > 1.0, "the Torrent publishes a real hull volume to collide with")

	# Approach down the deck from aft, on the hull's own centre line.
	var approach := Vector3(hull.get_center().x, 0.0, hull.end.z + APPROACH_GAP + 0.5)
	var travelled := await _drive_at(
		tractor, approach, Vector3.FORWARD, hull, &"TorrentInterceptor"
	)
	print("TRACTOR_HULL_APPROACH: ", travelled)
	print("TRACTOR_HULL_CONTACT_SPEED_MPS: %.6f" % float(travelled.contact_speed))
	_check(
		bool(travelled.get("started_on_floor", false))
		and bool(travelled.get("started_clear", false)),
		"the tractor starts its run standing on real deck, clear of the hull"
	)
	_check(
		float(travelled.get("distance", 0.0)) > 2.0,
		"the tractor covers real ground on its way to the hull"
	)
	_check(
		not bool(travelled.get("entered_target", true)),
		"driving a real held throttle into the Torrent never puts the tractor inside the hull"
	)
	_check(
		float(travelled.get("closest_approach", 999.0)) < 0.5,
		"the tractor is stopped *by* the hull rather than by something short of it"
	)
	_check(
		float(travelled.get("contact_speed", 0.0))
		>= tractor.maximum_forward_speed - 0.5
		and float(travelled.get("contact_speed", INF))
		<= tractor.maximum_forward_speed + 0.01,
		"the tractor reaches approximately its 11.5 m/s authored limit before the hull stops it"
	)
	_check(
		(travelled.get("blocked_by", PackedStringArray()) as PackedStringArray).has(
			"TorrentInterceptor"
		),
		"the live Torrent hull is the exact collider that stops the tractor"
	)
	_check(
		not tractor.has_reported_recovery(),
		"colliding with a hull never costs the driver their vehicle"
	)
	_check(
		torrent.global_position.distance_to(Vector3(0.0, 1.15, -10.0)) < 0.05,
		"the tractor cannot shove a berthed craft off its pad"
	)

	# Red witness: the same drive with the mask back the way the playtester found
	# it. A tractor that masks World alone must end up inside the hull.
	tractor.collision_mask = PhysicsLayers.WORLD
	var red := await _drive_at(
		tractor, approach, Vector3.FORWARD, hull, &"TorrentInterceptor"
	)
	tractor.collision_mask = PhysicsLayers.GROUND_VEHICLE_BODY_MASK
	print("TRACTOR_HULL_RED_WITNESS: ", red)
	_check(
		bool(red.get("entered_target", false)),
		"red witness: masking World alone drives the tractor straight through the hull"
	)


## Group 2: the "certain poles" half of the report.
func _test_drives_into_a_gantry_column(
		game: GameFlow,
		world: ShipyardWorld,
		tractor: TowTractor
	) -> void:
	var column: MeshInstance3D = null
	var activity: StationOperationsActivity = null
	for candidate in world.find_children("*", "StationOperationsActivity", true, false):
		var vignette := candidate as StationOperationsActivity
		# The one mounted on the lattice deck beside the tractor's parking spot.
		if vignette.global_position.distance_to(tractor.get_home_transform().origin) > 12.0:
			continue
		for mesh_candidate in vignette.find_children("Column*", "MeshInstance3D", true, false):
			var mesh_instance := mesh_candidate as MeshInstance3D
			if not str(mesh_instance.name).begins_with("Column") or mesh_instance.mesh == null:
				continue
			# The first one the tractor meets driving outboard: three of the four
			# stand behind it and would never be reached.
			if column == null or mesh_instance.global_position.x < column.global_position.x:
				column = mesh_instance
				activity = vignette
	_check(column != null, "a maintenance-gantry column stands within driving range of the tractor")
	if column == null or activity == null:
		return

	var drawn := column.global_transform * column.mesh.get_aabb()
	print("TRACTOR_COLUMN_TARGET: ", column.get_path(), " drawn=", drawn)
	var bodies := world.find_children(
		"%sSolids" % activity.name, "StaticBody3D", true, false
	)
	_check(bodies.size() == 1, "the world builds exactly one solid-volume body for this vignette")
	if bodies.is_empty():
		return
	var solid_volume_body := bodies[0] as StaticBody3D
	var expected_blocker := StringName(solid_volume_body.name)
	# Approach along +X, which is the axis the tractor is parked facing. Measured
	# off the column's near face, so the gap is a real run-up and not eaten by the
	# vehicle's own 1.9 m half-length.
	var approach := Vector3(drawn.position.x - APPROACH_GAP, 0.0, drawn.get_center().z)
	var travelled := await _drive_at(
		tractor, approach, Vector3.RIGHT, drawn, expected_blocker
	)
	print("TRACTOR_COLUMN_APPROACH: ", travelled)
	print("TRACTOR_COLUMN_CONTACT_SPEED_MPS: %.6f" % float(travelled.contact_speed))
	_check(
		bool(travelled.get("started_clear", false)),
		"the tractor starts its run clear of the column"
	)
	_check(
		float(travelled.get("distance", 0.0)) > 2.0,
		"the tractor covers real ground on its way to the column"
	)
	_check(
		not bool(travelled.get("entered_target", true)),
		"driving a real held throttle at a gantry column never puts the tractor inside the drawn column"
	)
	_check(
		float(travelled.get("closest_approach", 999.0)) < 0.5,
		"the tractor is stopped *by* the column rather than by something short of it"
	)
	_check(
		float(travelled.get("contact_speed", 0.0))
		>= tractor.maximum_forward_speed - 0.5
		and float(travelled.get("contact_speed", INF))
		<= tractor.maximum_forward_speed + 0.01,
		"the tractor reaches approximately its 11.5 m/s authored limit before the column stops it"
	)
	_check(
		(travelled.get("blocked_by", PackedStringArray()) as PackedStringArray).has(
			"%sSolids" % activity.name
		),
		"the thing that stopped the tractor is the vignette's own declared solid volumes"
	)

	# The column is solid because the vignette *declares* it as a solid volume and
	# the world realises that declaration. Both halves have to be checked, because
	# a column missing from the contract fails silently: the world builds the
	# bodies it is told about and nothing complains about the one it was not.
	var declared_columns := 0
	for volume in activity.get_solid_volume_contract():
		if str(volume["name"]) == "Column":
			declared_columns += 1
	_check(
		declared_columns == 4,
		"the vignette declares all four of its maintenance-gantry columns as solid volumes"
	)

	# Red witness through the public lifecycle, not an internal layer mutation.
	# Hiding the presentation must also disable the sibling body; otherwise the
	# player meets an invisible column. Re-enable then proves the same body returns.
	var solid_body_identity := solid_volume_body.get_instance_id()
	activity.set_activity_enabled(false)
	await _advance(2)
	_check(
		not bool(activity.get_activity_state().visible)
		and solid_volume_body.collision_layer == PhysicsLayers.NONE,
		"disabling one activity hides it and disables its world-owned solids together"
	)
	var red := await _drive_at(
		tractor, approach, Vector3.RIGHT, drawn, expected_blocker
	)
	print("TRACTOR_COLUMN_RED_WITNESS: ", red)
	_check(
		bool(red.get("entered_target", false)),
		"red witness: with the declaring activity disabled the tractor drives through its saved 5.5 m column bound"
	)
	activity.set_activity_enabled(true)
	await _advance(2)
	_check(
		bool(activity.get_activity_state().visible)
		and solid_volume_body.collision_layer == PhysicsLayers.WORLD_BODY_LAYER
		and solid_volume_body.get_instance_id() == solid_body_identity,
		"re-enabling the activity restores the same world-owned solid body"
	)
	var reenabled := await _drive_at(
		tractor, approach, Vector3.RIGHT, drawn, expected_blocker
	)
	print("TRACTOR_COLUMN_REENABLED: ", reenabled)
	_check(
		not bool(reenabled.get("entered_target", true))
		and (reenabled.blocked_by as PackedStringArray).has(expected_blocker),
		"the re-enabled lifecycle again stops the tractor at the exact column body"
	)


## The false Fleet census hid a second reachable family: the actual Aft ramp
## delivers this chassis directly into the fixed crew work post at its head.
func _test_drives_up_aft_ramp_into_workpost(
		world: ShipyardWorld,
		tractor: TowTractor
	) -> void:
	var activity := world.get_node_or_null(
		^"OperationalLattice/Activities/AftCrewWorkPost"
	) as StationOperationsActivity
	var body := world.get_node_or_null(
		^"OperationalLattice/ActivityCollision/AftCrewWorkPostSolids"
	) as StaticBody3D
	var crate := activity.find_child("SupplyCrate", true, false) as MeshInstance3D if activity != null else null
	_check(activity != null and body != null and crate != null, "Aft upper route resolves its crew workpost, exact sibling body, and east supply crate")
	if activity == null or body == null or crate == null:
		return
	var target := crate.global_transform * crate.mesh.get_aabb()
	var target_shape := BoxShape3D.new()
	target_shape.size = crate.mesh.get_aabb().size - Vector3.ONE * 0.02
	var target_transform := crate.global_transform * Transform3D(
		Basis.IDENTITY, crate.mesh.get_aabb().get_center()
	)
	var approach := Vector3(-5.36, 0.0, 52.0)
	var travelled := await _drive_at(
		tractor, approach, Vector3.BACK, target, StringName(body.name),
		target_shape, target_transform
	)
	print("TRACTOR_AFT_WORKPOST_APPROACH: ", travelled)
	print("TRACTOR_AFT_WORKPOST_CONTACT_SPEED_MPS: %.6f" % float(travelled.contact_speed))
	_check(
		bool(travelled.started_on_floor) and float(travelled.distance) > 7.0
		and tractor.global_position.y >= 4.0 and tractor.is_on_floor()
		and not tractor.has_reported_recovery(),
		"held production input climbs the real 23.2-degree Aft ramp before reaching the workpost"
	)
	_check(
		not bool(travelled.entered_target)
		and float(travelled.closest_approach) < 0.5
		and (travelled.blocked_by as PackedStringArray).has(String(body.name)),
		"the exact AftCrewWorkPostSolids body stops the tractor outside the drawn supply crate"
	)
	_check(
		is_finite(float(travelled.contact_speed))
		and float(travelled.contact_speed) >= tractor.maximum_forward_speed - 0.5,
		"the workpost stops a measured near-limit impact after the full ramp-foot run-up"
	)
	var volumes := activity.get_solid_volume_contract()
	var boxes := 0
	var cylinders := 0
	var rotated_cylinders := 0
	var names := {}
	for volume in volumes:
		var volume_name := StringName(volume.name)
		names[volume_name] = int(names.get(volume_name, 0)) + 1
		if StringName(volume.get("shape_kind", &"box")) == &"cylinder":
			cylinders += 1
			if not (volume.get("basis", Basis.IDENTITY) as Basis).is_equal_approx(Basis.IDENTITY):
				rotated_cylinders += 1
		else:
			boxes += 1
	_check(
		volumes.size() == 12 and boxes == 8 and cylinders == 4 and rotated_cylinders == 3,
		"crew workpost declares exactly 8 fixed boxes plus 4 cylinders, including all 3 sideways drums"
	)
	_check(
		names == {
			&"BenchTop": 1, &"BenchLeg": 4, &"ToolWall": 1,
			&"CableDrum": 1, &"DrumFlange": 2,
			&"SupplyCrate": 1, &"SupplyCrateTop": 1, &"JigPost": 1,
		},
		"crew workpost freezes the exact static semantic roster without promoting trim or animated tools"
	)
	activity.set_activity_enabled(false)
	await _advance(2)
	var red := await _drive_at(
		tractor, approach, Vector3.BACK, target, StringName(body.name),
		target_shape, target_transform
	)
	print("TRACTOR_AFT_WORKPOST_RED_WITNESS: ", red)
	_check(
		bool(red.entered_target) and tractor.global_position.y >= 4.0
		and not (red.blocked_by as PackedStringArray).has(String(body.name)),
		"red witness: disabling the workpost continuously drives the production tractor up the ramp and through the saved crate bound onto the upper deck"
	)
	activity.set_activity_enabled(true)
	await _advance(2)


## The mask fix may not hand this deck toy any craft authority. Physics-layer
## semantics and registry/type authority are deliberately asserted separately:
## berth, lease, fleet and landing systems do not derive identity from SHIP.
func _test_the_tractor_took_no_authority(
		game: GameFlow,
		world: ShipyardWorld,
		tractor: TowTractor
	) -> void:
	_check(game.get_flyable_ships().size() == 5, "the fleet registry still holds exactly five flyable craft")
	_check(
		tractor.collision_layer == PhysicsLayers.WORLD
		and (tractor.collision_layer & PhysicsLayers.SHIP) == 0,
		"the tractor keeps exact World-scenery collision semantics without advertising Ship"
	)
	for berth_id in [
		&"central_berth", &"arrow_recon_berth", &"jovian_freight_berth",
		&"zenith_fleet_dock_berth", &"halyard_fleet_dock_berth"
	]:
		var berth := world.get_berth_node(berth_id)
		_check(
			berth != null and berth.get_occupant() != tractor,
			"%s registry/type authority does not lease the tractor after it has been driven into things" % berth_id
		)
	# The walking player is stopped by the tractor through the player's own mask,
	# which is the direction of that pair that has always worked.
	var player := game.get_node_or_null(^"Player") as PlayerController
	_check(
		player != null and (player.collision_mask & PhysicsLayers.WORLD) != 0,
		"a walking player still collides with the tractor through its World bit"
	)


## Parks the tractor `gap` metres short of `target`, points it at it, holds the
## throttle, and watches the whole run rather than only where it ended up.
##
## Watching every tick is what makes the red witnesses honest. A tractor that
## masks `WORLD` alone does not *stop* inside a hull, it sails through and out the
## far side, so a finish-line check would find it clear of the ship and call that
## a pass. `entered_target` is true if the vehicle's own chassis volume shared
## space with the obstacle at any point in the run.
func _drive_at(
		tractor: TowTractor,
		from: Vector3,
		heading: Vector3,
		target: AABB,
		expected_blocker: StringName,
		exact_target_shape: Shape3D = null,
		exact_target_transform: Transform3D = Transform3D.IDENTITY
	) -> Dictionary:
	var ground := _deck_under(tractor, from)
	tractor.set_driven(false)
	tractor.velocity = Vector3.ZERO
	tractor.global_transform = Transform3D(
		Basis.looking_at(heading, Vector3.UP),
		Vector3(from.x, ground + 0.35, from.z)
	)
	tractor.reset_physics_interpolation()
	await _advance(SETTLE_TICKS)

	var start := tractor.global_position
	var started_on_floor := tractor.is_on_floor()
	var started_clear := not _chassis_world_aabb(tractor).intersects(target)
	var closest := INF
	var entered := false
	var blockers := PackedStringArray()
	var peak_approach_speed := 0.0
	var last_clear_speed := 0.0
	var contact_speed := NAN
	tractor.set_driven(true)
	Input.action_press(&"move_forward")
	for _tick in DRIVE_TICKS:
		await physics_frame
		await process_frame
		var sampled_speed := absf(tractor.get_drive_speed())
		peak_approach_speed = maxf(peak_approach_speed, sampled_speed)
		var chassis := _chassis_world_aabb(tractor)
		closest = minf(closest, _aabb_separation(chassis, target))
		if exact_target_shape != null:
			var target_query := PhysicsShapeQueryParameters3D.new()
			target_query.shape = exact_target_shape
			target_query.transform = exact_target_transform
			target_query.collision_mask = PhysicsLayers.WORLD
			target_query.collide_with_areas = false
			for hit in tractor.get_world_3d().direct_space_state.intersect_shape(target_query, 64):
				if hit.get("collider") == tractor:
					entered = true
					break
		elif chassis.intersects(target):
			entered = true
		# What actually stopped it, by name. Without this a red witness that fails
		# to disarm the thing it is testing looks exactly like a green pass.
		var expected_blocker_this_tick := false
		for index in tractor.get_slide_collision_count():
			var collider := tractor.get_slide_collision(index).get_collider() as Node
			if collider == null:
				continue
			var label := str(collider.name)
			if not blockers.has(label):
				blockers.append(label)
			if StringName(collider.name) == expected_blocker:
				expected_blocker_this_tick = true
		if expected_blocker_this_tick:
			if not is_finite(contact_speed):
				# `get_drive_speed()` is sampled after `move_and_slide()` and the
				# wall-response braking step. The immediately preceding clear sample
				# and this first blocked sample bracket contact; the greater of them is
				# the measured inbound speed, not a value inferred from run-up length.
				contact_speed = maxf(last_clear_speed, sampled_speed)
		elif not is_finite(contact_speed):
			# Updated on every tick before the expected obstacle is first observed,
			# including the whole clear run-up rather than only AABB-overlap ticks.
			last_clear_speed = sampled_speed
	Input.action_release(&"move_forward")
	await _advance(SETTLE_TICKS)
	tractor.set_driven(false)

	return {
		"started_on_floor": started_on_floor,
		"started_clear": started_clear,
		"start": start,
		"finish": tractor.global_position,
		"distance": start.distance_to(tractor.global_position),
		"closest_approach": closest,
		"entered_target": entered,
		"blocked_by": blockers,
		"peak_approach_speed": peak_approach_speed,
		"last_clear_speed": last_clear_speed,
		"contact_speed": contact_speed,
	}


## Axis-aligned world bound of the tractor's own collision shapes. Every approach
## in this suite runs along a world axis, so this is the chassis box itself rather
## than a loose bound of a rotated one.
func _chassis_world_aabb(tractor: TowTractor) -> AABB:
	return _body_world_aabb(tractor)


## Gap between two boxes: 0.0 once they touch.
func _aabb_separation(first: AABB, second: AABB) -> float:
	var gap := Vector3(
		maxf(0.0, maxf(second.position.x - first.end.x, first.position.x - second.end.x)),
		maxf(0.0, maxf(second.position.y - first.end.y, first.position.y - second.end.y)),
		maxf(0.0, maxf(second.position.z - first.end.z, first.position.z - second.end.z))
	)
	return gap.length()


## World-space volume of a body's own collision shapes.
func _body_world_aabb(body: CollisionObject3D) -> AABB:
	var result := AABB()
	var first := true
	for candidate in body.get_children():
		var collision := candidate as CollisionShape3D
		if collision == null or collision.shape == null or collision.disabled:
			continue
		var local := collision.shape.get_debug_mesh().get_aabb()
		var world := (body.global_transform * collision.transform) * local
		if first:
			result = world
			first = false
		else:
			result = result.merge(world)
	return result


func _deck_under(tractor: TowTractor, point: Vector3) -> float:
	var space := tractor.get_world_3d().direct_space_state
	var query := PhysicsRayQueryParameters3D.create(
		Vector3(point.x, point.y + 8.0, point.z),
		Vector3(point.x, point.y - 12.0, point.z),
		PhysicsLayers.WORLD
	)
	query.collide_with_areas = false
	query.exclude = [tractor.get_rid()]
	var hit := space.intersect_ray(query)
	if hit.is_empty():
		return point.y
	return (hit.position as Vector3).y


func _advance(frames: int) -> void:
	for _frame in maxi(1, frames):
		await physics_frame
		await process_frame


func _clean_up(game: Node) -> void:
	for action in [&"move_forward", &"move_back", &"move_left", &"move_right", &"brake", &"interact"]:
		Input.action_release(action)
	await _release_combat_audio_before_main_teardown(game)
	game.queue_free()
	await _advance(2)


func _release_combat_audio_before_main_teardown(game: Node) -> void:
	var combat_audio := game.get_node_or_null("CombatAudioPresentation")
	if combat_audio == null:
		return
	for candidate in combat_audio.find_children("*", "AudioStreamPlayer3D", true, false):
		var audio_player := candidate as AudioStreamPlayer3D
		audio_player.stop()
		audio_player.stream_paused = false
		audio_player.stream = null
	await process_frame
	var mixer_release_seconds := maxf(
		0.05,
		AudioServer.get_time_to_next_mix() + AudioServer.get_output_latency()
	)
	await create_timer(mixer_release_seconds).timeout
	var parent := combat_audio.get_parent()
	if parent != null:
		parent.remove_child(combat_audio)
	combat_audio.free()
	await process_frame


func _check(condition: bool, description: String) -> void:
	if condition:
		print("PASS: ", description)
	else:
		_failures.append(description)
		push_error("FAIL: " + description)


func _finish() -> void:
	if _failures.is_empty():
		print("TOW_TRACTOR_OBSTRUCTION_TEST_OK")
		quit(0)
	else:
		print("TOW_TRACTOR_OBSTRUCTION_TEST_FAILED: ", "; ".join(_failures))
		quit(1)
