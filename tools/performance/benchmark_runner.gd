extends SceneTree

## Production-scene benchmark runner. This records measurements; it does not
## turn a software renderer or an undeclared machine into performance evidence.

const MAIN_SCENE := preload("res://scenes/main.tscn")
const SCHEMA_VERSION := 1
const REPORT_KIND := "keths_performance_benchmark"
const DEFAULT_RESOLUTION := Vector2i(1920, 1080)
const DEFAULT_QUALITY_LEVEL := 2
const DEFAULT_WARMUP_FRAMES := 3600
const DEFAULT_SAMPLE_FRAMES := 18000
const MINIMUM_WARMUP_SECONDS := 60.0
const MINIMUM_SAMPLE_SECONDS := 600.0
const SMOKE_WARMUP_FRAMES := 2
const SMOKE_SAMPLE_FRAMES := 4
const DEFAULT_SCENARIO_ORDER := [&"station_embodied_route", &"nearby_sector_ship_flight_route"]
const SCENARIO_NAMES := [&"station_embodied_route", &"nearby_sector_ship_flight_route", &"halyard_cabin_walk_route", &"torrent_range_combat_reuse_route", &"ember_surface_walk_route", &"aurora_surface_walk_route"]
const MINIMUM_SMOKE_MOVEMENT_METERS := 0.001
const MINIMUM_FULL_STATION_PATH_METERS := 1.0
const FLIGHT_ENDPOINT_RADIUS_METERS := 20.0
const STREAMING_READY_FRAME_BUDGET := 24
const EMBER_REGION := preload("res://assets/world/planets/ember_caldera_landing_region.tres")
const EMBER_WORLD := preload("res://assets/world/planets/ember_moon_world.tres")
const EMBER_TERRAIN := preload("res://assets/world/planets/ember_basalt_terrain.tres")
const AURORA_REGION := preload("res://assets/world/planets/aurora_foundation_landing.tres")
const AURORA_WORLD := preload("res://assets/world/planets/aurora_temperate_world.tres")
const AURORA_TERRAIN := preload("res://assets/world/planets/aurora_temperate_terrain.tres")
# Existing coastal trail/sign/lookout route from aurora_visit_loop_test.gd.
# The reverse visits the same authored points, keeping clear of landmark props.
const AURORA_COASTAL_POINTS: Array[Vector3] = [
	Vector3(-7, 0, -17), Vector3(8, 0, -17), Vector3(20, 0, -7),
	Vector3(25, 0, 2), Vector3(29, 0, 1), Vector3(33, 0, 2),
	Vector3(43, 0, -8), Vector3(55, 0, -20), Vector3(60, 0, -20), Vector3(66, 0, -17),
]
# Exact ordered tangent-frame boundaries from ember_loop_soak_evidence.gd.
# A complete repeat covers about 131 metres at the production 5.8 m/s walk.
const EMBER_ROUTE_LEGS: Array = [
	["x", -9.0, false, &"move_back"],
	["z", 8.0, true, &"move_right"],
	["x", 17.5, true, &"move_forward"],
	["z", 0.5, false, &"move_left"],
	["x", 41.5, true, &"move_forward"],
	["x", 18.5, false, &"move_back"],
	["z", 8.0, true, &"move_right"],
	["x", -9.0, false, &"move_back"],
	["z", 0.5, false, &"move_left"],
]
# Software-rendered startup may advance the production fade slowly. This wait
# remains outside measurement and keeps the independent abort guard active.
const BEGIN_SHIFT_READY_TIMEOUT_MS := 60_000

const MONITORS := {
	"engine_fps": Performance.TIME_FPS,
	"cpu_process_ms": Performance.TIME_PROCESS,
	"cpu_physics_ms": Performance.TIME_PHYSICS_PROCESS,
	"navigation_ms": Performance.TIME_NAVIGATION_PROCESS,
	"render_objects": Performance.RENDER_TOTAL_OBJECTS_IN_FRAME,
	"render_primitives": Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME,
	"render_draw_calls": Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME,
	"scene_nodes": Performance.OBJECT_NODE_COUNT,
	"resources": Performance.OBJECT_RESOURCE_COUNT,
	"static_memory_bytes": Performance.MEMORY_STATIC,
}


class BenchmarkInputGuard extends Node:
	var aborted := false
	var reason := ""

	func _init() -> void:
		process_mode = Node.PROCESS_MODE_ALWAYS

	func _input(event: InputEvent) -> void:
		if event is InputEventKey and event.pressed and not event.echo \
				and (event.physical_keycode == KEY_ESCAPE or event.keycode == KEY_ESCAPE):
			request_abort("Escape pressed")
			get_viewport().set_input_as_handled()

	func request_abort(abort_reason: String) -> void:
		if aborted:
			return
		aborted = true
		reason = abort_reason
		release_inputs()
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		get_tree().paused = false

	func on_close_requested() -> void:
		request_abort("window close requested")

	func on_focus_exited() -> void:
		request_abort("benchmark window lost focus")


	static func release_inputs() -> void:
		for action in [
			&"move_forward", &"move_back", &"move_left", &"move_right",
			&"pitch_up", &"pitch_down", &"roll_left", &"roll_right",
			&"sprint_boost", &"brake", &"hover", &"fire", &"barrel_roll",
			&"landing_assist", &"interact",
		]:
			Input.action_release(action)

## Refresh before the ship's physics authority, including physics catch-up ticks
## between rendered frames. Only normal local Input actions drive the craft.
class BenchmarkFlightPilot extends Node:
	var ship: HeroShip
	var guard: BenchmarkInputGuard
	var target := Vector3.ZERO
	var start := Vector3.ZERO
	var returning := false
	var direction := Vector3.FORWARD
	var route_frame := 0
	var total_frames := 1

	func _physics_process(_delta: float) -> void:
		apply_input()

	func apply_input() -> void:
		BenchmarkInputGuard.release_inputs()
		if guard.aborted or not is_instance_valid(ship) or ship.is_destroyed():
			return
		var destination := start if returning else target
		var leg_direction := -direction if returning else direction
		var remaining := (destination - ship.global_position).dot(leg_direction)
		var speed := ship.velocity.dot(leg_direction)
		if ship.velocity.length() < 1.0 and remaining <= FLIGHT_ENDPOINT_RADIUS_METERS:
			returning = not returning
			Input.action_press(&"brake")
			return
		# Allow for the production throttle response after releasing thrust, plus
		# a small stand-off inside the endpoint aperture's accepted radius.
		var stopping_distance := speed * speed / (2.0 * maxf(ship.brake_acceleration, 1.0)) + absf(speed) * 0.3 + 3.0
		if speed < -0.5 or remaining <= stopping_distance:
			Input.action_press(&"brake")
			return
		Input.action_press(&"move_back" if returning else &"move_forward")
		if not returning and route_frame >= total_frames / 4 and route_frame < total_frames * 3 / 4:
			Input.action_press(&"sprint_boost")


## Uses the same live seat-derived aisle and camera-yaw steering as the
## continuous Halyard role route. No body transform writes after staging.
class BenchmarkCabinWalker extends Node:
	var player: PlayerController
	var craft: HalyardCrewTransport
	var guard: BenchmarkInputGuard
	var endpoints: Array[Vector3] = []
	var destination := 1

	func _physics_process(_delta: float) -> void:
		apply_input()

	func apply_input() -> void:
		BenchmarkInputGuard.release_inputs()
		if guard.aborted or not is_instance_valid(player) or not is_instance_valid(craft):
			return
		var local := craft.to_local(player.global_position)
		var target := endpoints[destination]
		var delta := Vector2(target.x - local.x, target.z - local.z)
		if delta.length() < 0.22:
			destination = 1 - destination
			target = endpoints[destination]
			delta = Vector2(target.x - local.x, target.z - local.z)
		var camera_yaw := player.get_node(^"CameraRig/CameraYaw") as Node3D
		var world_direction := craft.global_basis * Vector3(delta.x, 0.0, delta.y)
		var camera_parent := camera_yaw.get_parent() as Node3D
		var parent_direction := camera_parent.global_basis.inverse() * world_direction
		camera_yaw.rotation.y = atan2(-parent_direction.x, -parent_direction.z)
		Input.action_press(&"move_forward")


## Surface-only benchmark adapter: production policy and its existing read-only
## projection helper compose the public multiplier. This is not a Host journey.
class BenchmarkEmberWalker extends Node:
	var player: PlayerController
	var game: GameFlow
	var scene: Node3D
	var region: Node3D
	var patch: StaticBody3D
	var policy: PlanetarySurfaceGravityPolicy
	var guard: BenchmarkInputGuard
	var original_gravity := 1.0
	var frame_generation := 0
	var location_generation := 0
	var destination := 0
	var previous_local := Vector3.ZERO
	var start_local := Vector3.ZERO
	var local_path := 0.0
	var maximum_local_displacement := 0.0
	var maximum_step := 0.0
	var minimum_gravity := INF
	var maximum_gravity := 0.0
	var minimum_multiplier := INF
	var maximum_multiplier := 0.0
	var observations := 0
	var sampling := false
	var sampled_path := 0.0
	var sampled_observations := 0
	var outbound_visits := 0
	var return_visits := 0
	var sampled_outbound_visits := 0
	var sampled_return_visits := 0
	var support_valid := true
	var control_valid := true
	var world_valid := true
	var gravity_valid := true
	var input_valid := true
	var bounded_valid := true
	var stopped := false

	func _ready() -> void:
		previous_local = region.to_local(player.global_position)
		start_local = previous_local

	func _physics_process(_delta: float) -> void:
		observe()
		apply_input()

	func observe() -> void:
		if stopped or guard.aborted:
			return
		var bootstrap := _bootstrap()
		world_valid = world_valid and is_instance_valid(scene) and is_instance_valid(region) \
			and bootstrap.get_loaded_instance() == scene and scene.get_parent() != null \
			and game.is_ancestor_of(scene) and bootstrap.get_world_id() == _world_id() \
			and bootstrap.get_location_generation() == location_generation \
			and _frame_valid(bootstrap.get_coordinate_frame_for_session().get_generation()) \
			and scene.get_node_or_null(^"LandingRegion") == region \
			and region.get_node_or_null(^"WalkablePatch") == patch
		if not world_valid:
			return
		var local := region.to_local(player.global_position)
		var step := Vector2(local.x - previous_local.x, local.z - previous_local.z).length()
		local_path += step
		maximum_step = maxf(maximum_step, step)
		maximum_local_displacement = maxf(maximum_local_displacement, local.distance_to(start_local))
		bounded_valid = bounded_valid and _in_bounds(local) and step < 0.5
		previous_local = local
		control_valid = control_valid and player.is_control_enabled() and not player.is_seated()
		support_valid = support_valid and _has_support()
		var commanded := false
		for action in [&"move_forward", &"move_back", &"move_left", &"move_right"]:
			commanded = commanded or Input.is_action_pressed(action)
		input_valid = input_valid and (step <= 0.001 or commanded)
		var multiplier := game._network_ember_passenger_gravity(player.global_position, policy)
		var gravity := multiplier * float(ProjectSettings.get_setting("physics/3d/default_gravity", 9.8))
		gravity_valid = gravity_valid and is_finite(multiplier) and multiplier > 0.0 \
			and is_equal_approx(player.gravity_multiplier, multiplier) and _gravity_in_range(gravity)
		minimum_gravity = minf(minimum_gravity, gravity)
		maximum_gravity = maxf(maximum_gravity, gravity)
		minimum_multiplier = minf(minimum_multiplier, player.gravity_multiplier)
		maximum_multiplier = maxf(maximum_multiplier, player.gravity_multiplier)
		observations += 1
		if sampling:
			sampled_path += step
			sampled_observations += 1

	func apply_input() -> void:
		BenchmarkInputGuard.release_inputs()
		if stopped or guard.aborted or not world_valid or not is_instance_valid(player):
			return
		var multiplier := game._network_ember_passenger_gravity(player.global_position, policy)
		if not is_finite(multiplier) or multiplier <= 0.0:
			gravity_valid = false
			return
		player.gravity_multiplier = multiplier
		var local := region.to_local(player.global_position)
		var leg := EMBER_ROUTE_LEGS[destination] as Array
		var value := local.x if str(leg[0]) == "x" else local.z
		if (value >= float(leg[1]) if bool(leg[2]) else value <= float(leg[1])):
			if destination == 4:
				outbound_visits += 1
				if sampling:
					sampled_outbound_visits += 1
			if destination == 8:
				return_visits += 1
				if sampling:
					sampled_return_visits += 1
			destination = (destination + 1) % EMBER_ROUTE_LEGS.size()
			leg = EMBER_ROUTE_LEGS[destination] as Array
		var camera_yaw := player.get_node(^"CameraRig/CameraYaw") as Node3D
		var camera_parent := camera_yaw.get_parent() as Node3D
		var direction := camera_parent.global_basis.inverse() * region.global_basis.x
		camera_yaw.rotation.y = atan2(-direction.x, -direction.z)
		Input.action_press(StringName(leg[3]))

	func start_sampling() -> void:
		# Observe completed warm-up motion before marking the first sample.
		observe()
		sampling = true

	func stop() -> void:
		if stopped:
			return
		stopped = true
		set_physics_process(false)
		BenchmarkInputGuard.release_inputs()
		if is_instance_valid(player):
			player.gravity_multiplier = original_gravity

	func _exit_tree() -> void:
		stop()

	func finish() -> Dictionary:
		return {
			"actor_type": "PlayerController", "world_id": String(_world_id()),
			"route_source": _route_source(),
			"gravity_source": "production_policy_benchmark_adapter",
			"scene_instance_id": scene.get_instance_id() if is_instance_valid(scene) else 0,
			"region_instance_id": region.get_instance_id() if is_instance_valid(region) else 0,
			"patch_instance_id": patch.get_instance_id() if is_instance_valid(patch) else 0,
			"player_instance_id": player.get_instance_id() if is_instance_valid(player) else 0,
			"coordinate_frame_generation": frame_generation, "location_generation": location_generation,
			"observations": observations, "sample_observations": sampled_observations,
			"support_throughout": support_valid, "control_throughout": control_valid,
			"world_identity_throughout": world_valid, "gravity_throughout": gravity_valid,
			"held_input_throughout": input_valid, "bounded_path_throughout": bounded_valid,
			"local_path_distance_m": local_path, "sample_local_path_distance_m": sampled_path,
			"maximum_local_displacement_m": maximum_local_displacement, "maximum_physics_step_m": maximum_step,
			"minimum_gravity_mps2": minimum_gravity, "maximum_gravity_mps2": maximum_gravity,
			"minimum_gravity_multiplier": minimum_multiplier, "maximum_gravity_multiplier": maximum_multiplier,
			"outbound_visits": outbound_visits, "return_visits": return_visits,
			"sample_outbound_visits": sampled_outbound_visits, "sample_return_visits": sampled_return_visits,
		}

	func _bootstrap() -> PlanetaryStreamingBootstrap:
		return game.ember_streaming_bootstrap

	func _world_id() -> StringName:
		return &"ember_moon"

	func _route_source() -> String:
		return "authored_ember_pad_egress_staging_loop"

	func _gravity_in_range(gravity: float) -> bool:
		return gravity > 1.60 and gravity < 1.64

	func _frame_valid(generation: int) -> bool:
		return generation == frame_generation

	func _in_bounds(local: Vector3) -> bool:
		return local.is_finite() and absf(local.x) < 45.0 \
			and local.z > -2.0 and local.z < 11.0 and absf(local.y) < 0.5

	func _has_support() -> bool:
		return has_support(player, region, patch)

	static func has_support(body: PlayerController, landing: Node3D, floor_patch: StaticBody3D) -> bool:
		if not body.is_on_floor():
			return false
		var up := landing.global_basis.y.normalized()
		var query := PhysicsRayQueryParameters3D.create(body.global_position + up * 0.5,
			body.global_position - up * 2.5, PhysicsLayers.WORLD_BODY_LAYER, [body.get_rid()])
		query.collide_with_areas = false
		var hit := body.get_world_3d().direct_space_state.intersect_ray(query)
		return hit.get("collider") == floor_patch


## Same surface observation/cleanup machinery; only the authored walking path,
## world binding and terrain support differ. No actor placement after staging.
class BenchmarkAuroraWalker extends BenchmarkEmberWalker:
	var returning := false
	var terrain_observations := 0
	var sampled_terrain_observations := 0
	var lookout_floor_observations := 0
	var sampled_lookout_floor_observations := 0

	func _bootstrap() -> PlanetaryStreamingBootstrap:
		return game.aurora_streaming_bootstrap

	func _world_id() -> StringName:
		return &"aurora_temperate_world"

	func _route_source() -> String:
		return "authored_aurora_coastal_trail_lookout_loop"

	func _gravity_in_range(gravity: float) -> bool:
		return gravity > 9.78 and gravity < 9.82

	func _frame_valid(generation: int) -> bool:
		# Region-local observations and freshly resolved targets survive rebases.
		if generation < frame_generation:
			return false
		frame_generation = generation
		return true

	func _in_bounds(local: Vector3) -> bool:
		return local.is_finite() and local.x > -10.0 and local.x < 69.0 \
			and local.z > -24.0 and local.z < 5.0 and absf(local.y) < 0.5

	func _has_support() -> bool:
		if not player.is_on_floor():
			return false
		var up := region.global_basis.y.normalized()
		var query := PhysicsRayQueryParameters3D.create(player.global_position + up * 0.5,
			player.global_position - up * 2.5, PhysicsLayers.WORLD_BODY_LAYER, [player.get_rid()])
		query.collide_with_areas = false
		var hit := player.get_world_3d().direct_space_state.intersect_ray(query)
		var collider := hit.get("collider") as Node
		var terrain := scene.get_node_or_null(^"TerrainClipmap")
		var on_terrain := is_instance_valid(collider) and is_instance_valid(terrain) \
			and terrain.is_ancestor_of(collider) and collider.get_meta(&"generated_planetary_terrain", false) == true
		if on_terrain:
			terrain_observations += 1
			if sampling:
				sampled_terrain_observations += 1
		# The existing lookout is a low solid deck reached by its authored step.
		# Qualify these exact floor owners, never arbitrary landmark collisions.
		var on_lookout_floor := false
		for path: NodePath in [^"CoastalExploration/CoastalLookoutDeck", ^"CoastalExploration/LookoutStep"]:
			var floor_visual := region.get_node_or_null(path)
			on_lookout_floor = on_lookout_floor or (collider is StaticBody3D \
				and is_instance_valid(floor_visual) and collider.get_parent() == floor_visual)
		if on_lookout_floor:
			lookout_floor_observations += 1
			if sampling:
				sampled_lookout_floor_observations += 1
		return collider == patch or on_terrain or on_lookout_floor

	func apply_input() -> void:
		BenchmarkInputGuard.release_inputs()
		if stopped or guard.aborted or not world_valid or not is_instance_valid(player):
			return
		var multiplier := game._network_ember_passenger_gravity(player.global_position, policy)
		if not is_finite(multiplier) or multiplier <= 0.0:
			gravity_valid = false
			return
		player.gravity_multiplier = multiplier
		# Never cache world-space targets: Main can translate the whole surface.
		var target := region.to_global(AURORA_COASTAL_POINTS[destination])
		var local := region.to_local(player.global_position)
		var point := AURORA_COASTAL_POINTS[destination]
		if Vector2(local.x - point.x, local.z - point.z).length() < 0.7:
			if destination == AURORA_COASTAL_POINTS.size() - 1 and not returning:
				outbound_visits += 1
				if sampling:
					sampled_outbound_visits += 1
				returning = true
			elif destination == 0 and returning:
				return_visits += 1
				if sampling:
					sampled_return_visits += 1
				returning = false
			destination += -1 if returning else 1
			target = region.to_global(AURORA_COASTAL_POINTS[destination])
		var camera_yaw := player.get_node(^"CameraRig/CameraYaw") as Node3D
		var camera_parent := camera_yaw.get_parent() as Node3D
		var direction := camera_parent.global_basis.inverse() * (target - player.global_position)
		camera_yaw.rotation.y = atan2(-direction.x, -direction.z)
		Input.action_press(&"move_forward")

	func finish() -> Dictionary:
		var result := super.finish()
		result["terrain_support_observations"] = terrain_observations
		result["sample_terrain_support_observations"] = sampled_terrain_observations
		result["lookout_floor_support_observations"] = lookout_floor_observations
		result["sample_lookout_floor_support_observations"] = sampled_lookout_floor_observations
		return result


## Drives the production local weapon and observes its existing authority. The
## only lifecycle mutation is the world's reuse operation after real destruction.
class BenchmarkRangeCombat extends Node:
	var ship: HeroShip
	var game: GameFlow
	var world: ShipyardWorld
	var target: StaticBody3D
	var adapter: RangeTargetDamageableAdapter
	var authority: LiveCombatAuthority
	var guard: BenchmarkInputGuard
	var source_id := 0
	var generation := 0
	var last_sequence := -1
	var pending_destruction := false
	var pending_destruction_sampled := false
	var destroyed_at := 0
	var sampling := false
	var sample_started := 0
	var last_shot_at := 0
	var last_hit_at := 0
	var maximum_shot_gap := 0.0
	var maximum_hit_gap := 0.0
	var valid := true
	var first_shot := {}
	var totals := {"projectiles": 0, "shots": 0, "hits": 0, "damage_events": 0, "destructions": 0, "reuses": 0}
	var sample := {"projectiles": 0, "shots": 0, "hits": 0, "damage_events": 0, "destructions": 0, "reuses": 0}

	func _ready() -> void:
		source_id = authority.get_source_id(ship)
		generation = int(adapter.get_component_snapshot().get("generation", -1))
		ship.projectile_fired.connect(_on_projectile)
		authority.authoritative_shot_submitted.connect(_on_shot)
		adapter.damage_applied.connect(_on_damage)

	func start_sampling() -> void:
		sampling = true
		sample_started = Time.get_ticks_usec()
		last_shot_at = sample_started
		last_hit_at = sample_started

	func _count(field: String, sample_event: bool = true) -> void:
		totals[field] = int(totals[field]) + 1
		if sampling and sample_event:
			sample[field] = int(sample[field]) + 1

	func _on_projectile(_origin: Vector3, _direction: Vector3) -> void:
		_count("projectiles")
		valid = valid and Input.is_action_pressed(&"fire") and ship.is_piloted()

	func _on_damage(_amount: float, _health: float, _maximum: float, _position: Vector3, _normal: Vector3, _context: Dictionary) -> void:
		_count("damage_events")

	func _on_shot(request: ShotRequest, result: Dictionary) -> void:
		if request.source_entity != ship:
			return
		if first_shot.is_empty():
			var collider: Variant = result.get("collider")
			var hit_target: Variant = result.get("target_entity")
			first_shot = {
				"origin": [request.origin.x, request.origin.y, request.origin.z],
				"direction": [request.direction.x, request.direction.y, request.direction.z],
				"status": String(result.get("status", &"")),
				"collider_path": String(collider.get_path()) if collider is Node else "",
				"target_id": String(hit_target.get_meta("target_id", &"")) if hit_target is Node else "",
			}
		var command := ship.get_last_ship_command()
		valid = valid and request.source_id == source_id and source_id > 0 \
			and request.sequence > last_sequence and request.weapon_id == GameFlow.TORRENT_COMBAT_WEAPON_ID \
			and Input.is_action_pressed(&"fire") and command != null and command.fire
		last_sequence = request.sequence
		if not bool(result.get("accepted", false)):
			return
		_count("shots")
		var now := Time.get_ticks_usec()
		if sampling:
			maximum_shot_gap = maxf(maximum_shot_gap, float(now - last_shot_at) / 1_000_000.0)
			last_shot_at = now
		if result.get("target_entity") != target or not bool(result.get("damaged", false)):
			return
		valid = valid and result.get("damageable") == adapter and float(result.get("applied_damage", 0.0)) > 0.0
		_count("hits")
		if sampling:
			maximum_hit_gap = maxf(maximum_hit_gap, float(now - last_hit_at) / 1_000_000.0)
			last_hit_at = now
		if bool(result.get("destroyed", false)):
			valid = valid and not pending_destruction and adapter.is_destroyed() and adapter.get_health() <= 0.0 \
				and bool(target.get_meta("destruction_authority_committed", false))
			pending_destruction = true
			pending_destruction_sampled = sampling
			destroyed_at = now
			_count("destructions")

	func _physics_process(_delta: float) -> void:
		apply_input()

	func apply_input() -> void:
		BenchmarkInputGuard.release_inputs()
		if guard.aborted:
			return
		valid = valid and is_instance_valid(target) and is_instance_valid(adapter) \
			and game.combat_authority == authority and authority.get_source_id(ship) == source_id \
			and target.get_node_or_null("AuthoritativeDamageable") == adapter \
			and adapter.get_target_entity() == target and game.active_ship == ship \
			and game._piloting and ship.is_piloted() and not ship.is_destroyed() \
			and float(ship.get_telemetry().get("hull", 0.0)) > 0.0
		if not valid:
			return
		if int(totals.destructions) > 0:
			valid = valid and bool(target.get_meta("destruction_authority_committed", false))
		if adapter.is_destroyed():
			valid = valid and pending_destruction
			if valid and pending_destruction and Time.get_ticks_usec() - destroyed_at >= 1_000_000:
				var reset := world.reset_range_target_for_reuse(target)
				valid = valid and bool(reset.get("accepted", false)) and int(reset.get("generation", -1)) == generation + 1 and not adapter.is_destroyed() \
					and bool(target.get_meta("destruction_authority_committed", false))
				if valid:
					generation += 1
					pending_destruction = false
					_count("reuses", pending_destruction_sampled)
			return
		Input.action_press(&"fire")

	func finish() -> Dictionary:
		var now := Time.get_ticks_usec()
		return {
			"actor_type": "HeroShip", "combat_source": "production_local_fire_live_authority",
			"target_id": String(target.get_meta("target_id", &"")),
			"source_id": source_id, "source_instance_id": ship.get_instance_id(),
			"target_instance_id": target.get_instance_id(), "adapter_instance_id": adapter.get_instance_id(),
			"authority_instance_id": authority.get_instance_id(),
			"identity_and_control_throughout": valid, "first_authoritative_shot": first_shot.duplicate(),
			"totals": totals.duplicate(), "sampling": sample.duplicate(),
			"maximum_sample_shot_gap_seconds": maxf(maximum_shot_gap, float(now - last_shot_at) / 1_000_000.0),
			"maximum_sample_hit_gap_seconds": maxf(maximum_hit_gap, float(now - last_hit_at) / 1_000_000.0),
		}


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var selection := OS.get_environment("KETH_BENCHMARK_SCENARIO")
	var smoke := _environment_bool("KETH_BENCHMARK_SMOKE", false)
	var warmup_frames := _environment_int(
		"KETH_BENCHMARK_WARMUP_FRAMES",
		SMOKE_WARMUP_FRAMES if smoke else DEFAULT_WARMUP_FRAMES,
		1
	)
	var sample_frames := _environment_int(
		"KETH_BENCHMARK_SAMPLE_FRAMES",
		SMOKE_SAMPLE_FRAMES if smoke else DEFAULT_SAMPLE_FRAMES,
		2
	)
	var resolution := _environment_resolution("KETH_BENCHMARK_RESOLUTION", DEFAULT_RESOLUTION)
	var quality_level := clampi(
		_environment_int("KETH_BENCHMARK_QUALITY_LEVEL", DEFAULT_QUALITY_LEVEL, 0),
		0,
		2
	)
	var target := load_target_profile(OS.get_environment("KETH_BENCHMARK_TARGET_PROFILE"))
	var report := await run_benchmark(
		self, warmup_frames, sample_frames, resolution, quality_level, target, smoke, selection
	)
	if report.has("selection_error"):
		printerr("PERFORMANCE_BENCHMARK_SELECTION_FAILED: ", report.selection_error)
		quit(1)
		return
	if bool(report.get("aborted", false)):
		printerr("PERFORMANCE_BENCHMARK_ABORTED: ", report.get("reason", "operator abort"))
		quit(130)
		return
	var errors := validate_report(report) if selection.is_empty() else validate_selected_diagnostic_report(report, selection)
	if not errors.is_empty():
		printerr("PERFORMANCE_BENCHMARK_SCHEMA_FAILED: ", "; ".join(errors))
		quit(1)
		return
	var output_path := OS.get_environment("KETH_BENCHMARK_JSON")
	if output_path.is_empty():
		output_path = "user://performance_benchmark.json"
	var absolute_path := ProjectSettings.globalize_path(output_path)
	var output_directory := absolute_path.get_base_dir()
	if not output_directory.is_empty():
		DirAccess.make_dir_recursive_absolute(output_directory)
	var file := FileAccess.open(absolute_path, FileAccess.WRITE)
	if file == null:
		printerr("PERFORMANCE_BENCHMARK_WRITE_FAILED: ", absolute_path)
		quit(1)
		return
	file.store_string(JSON.stringify(report, "\t"))
	file.close()
	print("PERFORMANCE_BENCHMARK_OK: ", absolute_path)
	print("representative_pass=", report.representativeness.representative_pass)
	quit(0)


static func run_benchmark(
		tree: SceneTree,
		warmup_frames: int,
		sample_frames: int,
		resolution: Vector2i,
		quality_level: int,
		target_profile: Dictionary = {},
		smoke_run: bool = false,
		scenario_selection: String = ""
	) -> Dictionary:
	# Validate before installing guards, changing the window or instantiating Main.
	if not scenario_selection.is_empty() and not SCENARIO_NAMES.has(StringName(scenario_selection)):
		return {"selection_error": "unknown benchmark scenario: %s" % scenario_selection}
	var selected_names := PackedStringArray(DEFAULT_SCENARIO_ORDER) if scenario_selection.is_empty() else PackedStringArray([scenario_selection])
	var frame_counts := required_phase_frames(warmup_frames, sample_frames, smoke_run)
	warmup_frames = frame_counts.warmup
	sample_frames = frame_counts.sample
	# Keep physical Escape available through startup and deterministic staging,
	# independently of gameplay pause/input.
	var input_guard := BenchmarkInputGuard.new()
	tree.root.add_child(input_guard)
	var original_paused := tree.paused
	var original_auto_quit := tree.auto_accept_quit
	tree.auto_accept_quit = false
	tree.root.window_input.connect(input_guard._input)
	tree.root.close_requested.connect(input_guard.on_close_requested)
	tree.root.focus_exited.connect(input_guard.on_focus_exited)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var original_root_size := tree.root.size
	var original_content_mode := tree.root.content_scale_mode
	var original_content_size := tree.root.content_scale_size
	var original_content_factor := tree.root.content_scale_factor
	var original_window_mode := tree.root.mode
	var requested_resolution := Vector2i(maxi(resolution.x, 1), maxi(resolution.y, 1))
	tree.root.size = requested_resolution
	if DisplayServer.get_name() != "headless":
		DisplayServer.window_set_size(requested_resolution)
	var durations := required_phase_seconds(target_profile, smoke_run)
	var scenarios: Array[Dictionary] = []
	for scenario_name: StringName in selected_names:
		scenarios.append(await _run_scenario(
			tree,
			scenario_name,
			maxi(warmup_frames, 1),
			maxi(sample_frames, 2),
			quality_level,
			smoke_run,
			durations,
			requested_resolution,
			input_guard
		))
		if input_guard.aborted:
			break
	_release_inputs()
	# Capture the live viewport before restoring the caller's display.
	var observed := capture_environment(Vector2i(tree.root.get_visible_rect().size), quality_level)
	tree.root.content_scale_mode = original_content_mode
	tree.root.content_scale_size = original_content_size
	tree.root.content_scale_factor = original_content_factor
	tree.root.mode = original_window_mode
	tree.root.size = original_root_size
	var abort_reason := input_guard.reason
	var aborted := input_guard.aborted
	input_guard.free()
	tree.auto_accept_quit = original_auto_quit
	tree.paused = original_paused
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if aborted:
		return {"aborted": true, "reason": abort_reason}
	var source := capture_source_state()
	var representativeness := classify_representativeness(observed, target_profile)
	var representativeness_reasons := (
		representativeness.get("reasons", PackedStringArray()) as PackedStringArray
	)
	var completed := true
	for scenario in scenarios:
		completed = completed and bool(scenario.get("completed", false))
	if bool(source.get("git_dirty", true)):
		representativeness_reasons.append("source tree is dirty")
	if not scenario_selection.is_empty():
		representativeness_reasons.append("selected scenario is diagnostic-only; full protocol requires both scenarios")
	if smoke_run:
		representativeness_reasons.append("smoke protocol is bounded-progress-only")
	representativeness["reasons"] = representativeness_reasons
	representativeness["representative_pass"] = (
		bool(representativeness.get("hardware_match", false))
		and not bool(source.get("git_dirty", true))
		and completed
		and not smoke_run
		and scenario_selection.is_empty()
	)
	representativeness["performance_budget_pass"] = null
	return build_report(
		source,
		observed,
		target_profile,
		representativeness,
		scenarios,
		{
			"warmup_frames_per_scenario": maxi(warmup_frames, 1),
			"sample_frames_per_scenario": maxi(sample_frames, 2),
			"scenario_order": selected_names,
			"frame_delta_clock": "Time.get_ticks_usec wall interval between consecutive process_frame signals",
			"quality_level": quality_level,
			"resolution": [requested_resolution.x, requested_resolution.y],
			"physics_ticks_per_second": Engine.physics_ticks_per_second,
			"engine_max_fps": Engine.max_fps,
			"smoke_run": smoke_run,
			"minimum_warmup_seconds": durations.warmup,
			"minimum_sample_seconds": durations.sample,
		}
	)


static func required_phase_frames(warmup_frames: int, sample_frames: int, smoke_run: bool) -> Dictionary:
	return {
		"warmup": maxi(warmup_frames, 1 if smoke_run else DEFAULT_WARMUP_FRAMES),
		"sample": maxi(sample_frames, 2 if smoke_run else DEFAULT_SAMPLE_FRAMES),
	}


static func _run_scenario(
		tree: SceneTree,
		scenario_name: StringName,
		warmup_frames: int,
		sample_frames: int,
		quality_level: int,
		smoke_run: bool,
		durations: Dictionary,
		requested_resolution: Vector2i,
		input_guard: BenchmarkInputGuard
	) -> Dictionary:
	_release_inputs()
	seed(_scenario_seed(scenario_name))
	var instantiate_started := Time.get_ticks_usec()
	var game := MAIN_SCENE.instantiate() as GameFlow
	var instantiated_ms := float(Time.get_ticks_usec() - instantiate_started) / 1000.0
	if game == null:
		return {"name": String(scenario_name), "completed": false, "error": "Main failed to instantiate"}
	var startup_world := game.get_node_or_null("ShipyardWorld") as ShipyardWorld
	if startup_world != null:
		startup_world.visual_quality_level = quality_level
	var ready_started := Time.get_ticks_usec()
	tree.root.add_child(game)
	await tree.process_frame
	await tree.physics_frame
	await tree.process_frame
	var ready_ms := float(Time.get_ticks_usec() - ready_started) / 1000.0
	var world := game.get_node_or_null("ShipyardWorld") as ShipyardWorld
	var player := game.get_node_or_null("Player") as PlayerController
	var ship := game.get_node_or_null("HalyardCrewTransport" if scenario_name == &"halyard_cabin_walk_route" else "TorrentInterceptor") as HeroShip
	if world == null or player == null or ship == null:
		game.queue_free()
		await tree.process_frame
		return {"name": String(scenario_name), "completed": false, "error": "production actors unavailable"}
	if input_guard.aborted:
		game.queue_free()
		await tree.process_frame
		return {"completed": false}
	var quality_report := world.apply_visual_quality(quality_level)
	# Main startup applies persisted display settings; benchmark sizing must win
	# after that startup, with one render pixel per requested viewport pixel.
	tree.root.mode = Window.MODE_WINDOWED
	tree.root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	tree.root.content_scale_size = Vector2i.ZERO
	tree.root.content_scale_factor = 1.0
	tree.root.size = requested_resolution
	if DisplayServer.get_name() != "headless":
		DisplayServer.window_set_size(requested_resolution)
	await tree.process_frame
	await tree.process_frame
	if input_guard.aborted:
		game.queue_free()
		await tree.process_frame
		return {"completed": false}
	var original_player_gravity := player.gravity_multiplier
	var inputs := await _stage_scenario(tree, game, world, player, ship, scenario_name, input_guard)
	if input_guard.aborted or not bool(inputs.get("staging_valid", false)):
		player.gravity_multiplier = original_player_gravity
		_release_inputs()
		if is_instance_valid(ship):
			ship.set_piloted(false)
		game.queue_free()
		await tree.process_frame
		await tree.process_frame
		return {
			"name": String(scenario_name),
			"completed": false,
			"error": str(inputs.get("staging_error", "scenario staging failed")),
			"deterministic_inputs": inputs,
		}
	var resolution_before := await capture_resolution(tree, requested_resolution, input_guard)
	var progress_tracker := _begin_scenario_progress(player, ship, scenario_name, inputs, smoke_run)
	var combat: BenchmarkRangeCombat
	if scenario_name == &"torrent_range_combat_reuse_route":
		combat = BenchmarkRangeCombat.new()
		combat.ship = ship
		combat.game = game
		combat.world = world
		combat.target = world.get_node(^"ExteriorTargetRange/TargetDrone01") as StaticBody3D
		combat.adapter = combat.target.get_node(^"AuthoritativeDamageable") as RangeTargetDamageableAdapter
		combat.authority = game.combat_authority
		combat.guard = input_guard
		combat.process_physics_priority = ship.process_physics_priority - 1
		game.add_child(combat)
	var surface_walker: BenchmarkEmberWalker
	if scenario_name in [&"ember_surface_walk_route", &"aurora_surface_walk_route"]:
		var aurora := scenario_name == &"aurora_surface_walk_route"
		surface_walker = BenchmarkAuroraWalker.new() if aurora else BenchmarkEmberWalker.new()
		surface_walker.player = player
		surface_walker.game = game
		surface_walker.guard = input_guard
		surface_walker.original_gravity = original_player_gravity
		surface_walker.scene = surface_walker._bootstrap().get_loaded_instance() as Node3D
		surface_walker.region = surface_walker.scene.get_node(^"LandingRegion") as Node3D
		surface_walker.patch = surface_walker.region.get_node(^"WalkablePatch") as StaticBody3D
		surface_walker.policy = _aurora_gravity_policy(game) if aurora else _ember_gravity_policy(game)
		surface_walker.frame_generation = int(inputs.coordinate_frame_generation)
		surface_walker.location_generation = int(inputs.streamed_generation)
		surface_walker.process_physics_priority = player.process_physics_priority - 1
		game.add_child(surface_walker)
	var cabin_walker: BenchmarkCabinWalker
	if scenario_name == &"halyard_cabin_walk_route":
		cabin_walker = BenchmarkCabinWalker.new()
		cabin_walker.player = player
		cabin_walker.craft = ship as HalyardCrewTransport
		cabin_walker.guard = input_guard
		cabin_walker.endpoints = _cabin_endpoints(ship as HalyardCrewTransport)
		cabin_walker.process_physics_priority = player.process_physics_priority - 1
		game.add_child(cabin_walker)
	var flight_pilot: BenchmarkFlightPilot
	if scenario_name == &"nearby_sector_ship_flight_route":
		flight_pilot = BenchmarkFlightPilot.new()
		flight_pilot.ship = ship
		flight_pilot.guard = input_guard
		flight_pilot.target = progress_tracker.route_target as Vector3
		flight_pilot.start = ship.global_position
		flight_pilot.direction = (flight_pilot.target - ship.global_position).normalized()
		flight_pilot.total_frames = warmup_frames + sample_frames
		flight_pilot.process_physics_priority = ship.process_physics_priority - 1
		game.add_child(flight_pilot)
	# One declared activation tick guarantees that a short smoke actually offers
	# its input to the production physics authority before timing continues.
	if not input_guard.aborted:
		_apply_scenario_input(scenario_name, 0, warmup_frames + sample_frames, flight_pilot, cabin_walker, combat, surface_walker)
	await tree.physics_frame
	await tree.process_frame
	_update_scenario_progress(progress_tracker, player, ship, scenario_name)

	var total_frames := warmup_frames + sample_frames
	var previous_tick := Time.get_ticks_usec()
	var warmup_started := Time.get_ticks_usec()
	var actual_warmup_frames := 0
	while not input_guard.aborted and phase_incomplete(actual_warmup_frames, warmup_frames,
			float(Time.get_ticks_usec() - warmup_started) / 1_000_000.0, durations.warmup):
		var route_frame := int(warmup_frames * phase_progress(actual_warmup_frames, warmup_frames,
			float(Time.get_ticks_usec() - warmup_started) / 1_000_000.0, durations.warmup))
		_apply_scenario_input(scenario_name, route_frame, total_frames, flight_pilot, cabin_walker, combat, surface_walker)
		if smoke_run and (cabin_walker != null or combat != null or surface_walker != null):
			await tree.physics_frame
		await tree.process_frame
		_update_scenario_progress(progress_tracker, player, ship, scenario_name)
		previous_tick = Time.get_ticks_usec()
		actual_warmup_frames += 1
	var warmup_elapsed := float(Time.get_ticks_usec() - warmup_started) / 1_000_000.0

	var frame_deltas: Array[float] = []
	var monitor_samples: Dictionary = {}
	for monitor_name in MONITORS:
		monitor_samples[monitor_name] = [] as Array[float]
	var sample_path_start := float(progress_tracker.path_distance_m)
	var sample_local_path_start := float(progress_tracker.get("local_path_distance_m", 0.0))
	if surface_walker != null:
		surface_walker.start_sampling()
	if combat != null:
		combat.start_sampling()
	var sample_started := Time.get_ticks_usec()
	previous_tick = sample_started
	while not input_guard.aborted and phase_incomplete(frame_deltas.size(), sample_frames,
			float(Time.get_ticks_usec() - sample_started) / 1_000_000.0, maxf(float(durations.sample), 8.0 if combat != null and smoke_run else 0.0)):
		var route_frame := warmup_frames + int(sample_frames * phase_progress(frame_deltas.size(), sample_frames,
			float(Time.get_ticks_usec() - sample_started) / 1_000_000.0, durations.sample))
		_apply_scenario_input(scenario_name, route_frame, total_frames, flight_pilot, cabin_walker, combat, surface_walker)
		if smoke_run and (cabin_walker != null or combat != null or surface_walker != null):
			await tree.physics_frame
		await tree.process_frame
		_update_scenario_progress(progress_tracker, player, ship, scenario_name)
		var now := Time.get_ticks_usec()
		frame_deltas.append(float(now - previous_tick) / 1000.0)
		previous_tick = now
		_capture_monitor_sample(monitor_samples)

	var sample_elapsed := float(Time.get_ticks_usec() - sample_started) / 1_000_000.0
	var surface_progress := {}
	if surface_walker != null:
		surface_walker.observe()
		surface_progress = surface_walker.finish()
		surface_walker.stop()
	var combat_progress := {}
	if combat != null:
		combat.set_physics_process(false)
		combat_progress = combat.finish()
		_release_inputs()
	if cabin_walker != null:
		cabin_walker.set_physics_process(false)
		_release_inputs()
	if flight_pilot != null:
		flight_pilot.set_physics_process(false)
		_release_inputs()
	if input_guard.aborted:
		_release_inputs()
		ship.set_piloted(false)
		game.queue_free()
		await tree.process_frame
		await tree.process_frame
		return {"completed": false}
	var resolution_after := await capture_resolution(tree, requested_resolution, input_guard)
	var progress := _finish_scenario_progress(progress_tracker, player, ship, scenario_name)
	if cabin_walker != null:
		progress["sample_local_path_distance_m"] = float(progress_tracker.local_path_distance_m) - sample_local_path_start
	if flight_pilot != null:
		progress["sample_path_distance_m"] = float(progress_tracker.path_distance_m) - sample_path_start
	if surface_walker != null:
		progress.merge(surface_progress)
	if combat != null:
		progress.merge(combat_progress)
	var progress_errors := validate_scenario_progress(scenario_name, progress)
	_release_inputs()
	var result := {
		"resolution_before": resolution_before,
		"resolution_after": resolution_after,
		"name": String(scenario_name),
		"completed": progress_errors.is_empty(),
		"error": "; ".join(progress_errors),
		"deterministic_inputs": inputs,
		"scenario_progress": progress,
		"warmup_frames": actual_warmup_frames,
		"warmup_elapsed_seconds": warmup_elapsed,
		"sample_elapsed_seconds": sample_elapsed,
		"sample_count": frame_deltas.size(),
		"frame_delta_ms": summarize_samples(frame_deltas),
		"monitors": _summarize_monitors(monitor_samples),
		"ram": {
			"static_bytes_after_sample": OS.get_static_memory_usage(),
			"static_peak_bytes": OS.get_static_memory_peak_usage(),
		},
		"scene_counts": capture_scene_counts(game),
		"startup": {
			"main_instantiate_ms": instantiated_ms,
			"main_first_ready_frames_ms": ready_ms,
		},
		"quality_report": quality_report,
	}
	if is_instance_valid(ship):
		ship.set_piloted(false)
	game.queue_free()
	await tree.process_frame
	await tree.process_frame
	return result


static func _begin_scenario_progress(
		player: PlayerController,
		ship: HeroShip,
		scenario_name: StringName,
		inputs: Dictionary,
		smoke_run: bool
	) -> Dictionary:
	var actor := player as Node3D if scenario_name not in [&"nearby_sector_ship_flight_route", &"torrent_range_combat_reuse_route"] else ship as Node3D
	var start_position := actor.global_position
	var target_array := inputs.get("route_target", []) as Array
	var target := Vector3.ZERO
	if target_array.size() == 3:
		target = Vector3(float(target_array[0]), float(target_array[1]), float(target_array[2]))
	var start_hull := float(ship.get_telemetry().get("hull", -1.0))
	var tracker := {
		"smoke_run": smoke_run,
		"start_transform_value": actor.global_transform,
		"previous_position": start_position,
		"path_distance_m": 0.0,
		"horizontal_path_distance_m": 0.0,
		"maximum_displacement_m": 0.0,
		"maximum_horizontal_displacement_m": 0.0,
		"route_target": target,
		"start_target_distance_m": start_position.distance_to(target),
		"minimum_target_distance_m": start_position.distance_to(target),
		"engine_online_observed": false,
		"accepted_propulsion_observed": false,
		"start_hull": start_hull,
		"minimum_hull": start_hull,
		"healthy_throughout": start_hull > 0.0 and not ship.is_destroyed(),
	}

	if scenario_name == &"halyard_cabin_walk_route":
		tracker.merge({
			"previous_local": ship.to_local(player.global_position),
			"start_local": ship.to_local(player.global_position),
			"local_path_distance_m": 0.0, "maximum_local_displacement_m": 0.0,
			"support_throughout": true, "occupancy_throughout": true,
			"control_throughout": true, "inside_throughout": true,
			"stationary_throughout": true, "craft_start": ship.global_transform,
			"outbound_reached": false, "return_reached": false,
			"endpoints": _cabin_endpoints(ship as HalyardCrewTransport),
		})
	return tracker


static func _update_scenario_progress(
		tracker: Dictionary,
		player: PlayerController,
		ship: HeroShip,
		scenario_name: StringName
	) -> void:
	var actor := player as Node3D if scenario_name not in [&"nearby_sector_ship_flight_route", &"torrent_range_combat_reuse_route"] else ship as Node3D
	var position := actor.global_position
	var previous := tracker.previous_position as Vector3
	var start := (tracker.start_transform_value as Transform3D).origin
	tracker.path_distance_m = float(tracker.path_distance_m) + position.distance_to(previous)
	tracker.horizontal_path_distance_m = float(tracker.horizontal_path_distance_m) + Vector2(
		position.x - previous.x, position.z - previous.z
	).length()
	tracker.maximum_displacement_m = maxf(
		float(tracker.maximum_displacement_m), position.distance_to(start)
	)
	tracker.maximum_horizontal_displacement_m = maxf(
		float(tracker.maximum_horizontal_displacement_m),
		Vector2(position.x - start.x, position.z - start.z).length()
	)
	tracker.previous_position = position
	if scenario_name == &"halyard_cabin_walk_route":
		var craft := ship as HalyardCrewTransport
		var local := craft.to_local(player.global_position)
		tracker.local_path_distance_m = float(tracker.local_path_distance_m) + Vector2(local.x - tracker.previous_local.x, local.z - tracker.previous_local.z).length()
		tracker.maximum_local_displacement_m = maxf(float(tracker.maximum_local_displacement_m), Vector2(local.x - tracker.start_local.x, local.z - tracker.start_local.z).length())
		tracker.previous_local = local
		tracker.support_throughout = bool(tracker.support_throughout) and player.is_on_floor()
		tracker.occupancy_throughout = bool(tracker.occupancy_throughout) and craft.get_moving_interior_component().is_occupant_registered(player)
		tracker.control_throughout = bool(tracker.control_throughout) and player.is_control_enabled() and not player.is_seated()
		tracker.inside_throughout = bool(tracker.inside_throughout) and craft.get_interior_bounds().has_point(local)
		tracker.stationary_throughout = bool(tracker.stationary_throughout) and craft.global_transform.is_equal_approx(tracker.craft_start) and craft.velocity.length() < 0.01 and not craft.is_piloted()
		tracker.healthy_throughout = bool(tracker.healthy_throughout) and not craft.is_destroyed() and float(craft.get_telemetry().get("hull", 0.0)) > 0.0
		var endpoints := tracker.endpoints as Array[Vector3]
		if Vector2(local.x - endpoints[1].x, local.z - endpoints[1].z).length() < 0.3:
			tracker.outbound_reached = true
		if bool(tracker.outbound_reached) and Vector2(local.x - endpoints[0].x, local.z - endpoints[0].z).length() < 0.3:
			tracker.return_reached = true
		return
	if scenario_name != &"nearby_sector_ship_flight_route":
		return
	var telemetry := ship.get_telemetry()
	var engine_online := StringName(telemetry.get("engine_state", &"")) == HeroShip.ENGINE_ONLINE
	var command := ship.get_last_ship_command()
	tracker.engine_online_observed = bool(tracker.engine_online_observed) or engine_online
	tracker.accepted_propulsion_observed = (
		bool(tracker.accepted_propulsion_observed)
		or (engine_online and command != null and command.throttle > 0.0)
	)
	var hull := float(telemetry.get("hull", -1.0))
	tracker.minimum_hull = minf(float(tracker.minimum_hull), hull)
	tracker.healthy_throughout = (
		bool(tracker.healthy_throughout)
		and hull > 0.0
		and not ship.is_destroyed()
	)
	var target := tracker.route_target as Vector3
	tracker.minimum_target_distance_m = minf(
		float(tracker.minimum_target_distance_m), position.distance_to(target)
	)


static func _finish_scenario_progress(
		tracker: Dictionary,
		player: PlayerController,
		ship: HeroShip,
		scenario_name: StringName
	) -> Dictionary:
	var actor := player as Node3D if scenario_name not in [&"nearby_sector_ship_flight_route", &"torrent_range_combat_reuse_route"] else ship as Node3D
	var start_transform := tracker.start_transform_value as Transform3D
	var end_transform := actor.global_transform
	var result := {
		"policy": "bounded_progress_smoke" if bool(tracker.smoke_run) else "full_route",
		"endpoint_required": not bool(tracker.smoke_run) and scenario_name == &"nearby_sector_ship_flight_route",
		"start_transform": _transform_record(start_transform),
		"end_transform": _transform_record(end_transform),
		"path_distance_m": float(tracker.path_distance_m),
		"horizontal_path_distance_m": float(tracker.horizontal_path_distance_m),
		"displacement_m": end_transform.origin.distance_to(start_transform.origin),
		"horizontal_displacement_m": Vector2(
			end_transform.origin.x - start_transform.origin.x,
			end_transform.origin.z - start_transform.origin.z
		).length(),
		"maximum_displacement_m": float(tracker.maximum_displacement_m),
		"maximum_horizontal_displacement_m": float(tracker.maximum_horizontal_displacement_m),
	}
	if scenario_name == &"halyard_cabin_walk_route":
		result["actor_type"] = "PlayerController"
		result["aisle_length_m"] = (tracker.endpoints[0] as Vector3).distance_to(tracker.endpoints[1] as Vector3)
		for field in ["local_path_distance_m", "maximum_local_displacement_m", "support_throughout", "occupancy_throughout", "control_throughout", "inside_throughout", "stationary_throughout", "healthy_throughout", "outbound_reached", "return_reached"]:
			result[field] = tracker[field]
		return result
	if scenario_name in [&"station_embodied_route", &"ember_surface_walk_route", &"aurora_surface_walk_route"]:
		result["actor_type"] = "PlayerController"
		result["control_enabled_end"] = player.is_control_enabled()
		return result
	var target := tracker.route_target as Vector3
	var end_hull := float(ship.get_telemetry().get("hull", -1.0))
	result.merge({
		"actor_type": "HeroShip",
		"route_target": [target.x, target.y, target.z],
		"start_target_distance_m": float(tracker.start_target_distance_m),
		"end_target_distance_m": end_transform.origin.distance_to(target),
		"minimum_target_distance_m": float(tracker.minimum_target_distance_m),
		"maximum_target_progress_m": (
			float(tracker.start_target_distance_m) - float(tracker.minimum_target_distance_m)
		),
		"engine_online_observed": bool(tracker.engine_online_observed),
		"accepted_propulsion_observed": bool(tracker.accepted_propulsion_observed),
		"start_hull": float(tracker.start_hull),
		"end_hull": end_hull,
		"minimum_hull": float(tracker.minimum_hull),
		"healthy_throughout": bool(tracker.healthy_throughout) and end_hull > 0.0 and not ship.is_destroyed(),
		"destroyed_end": ship.is_destroyed(),
	})
	return result


static func validate_scenario_progress(
		scenario_name: StringName,
		progress: Dictionary
	) -> PackedStringArray:
	var errors := PackedStringArray()
	if progress.is_empty():
		return PackedStringArray(["scenario_progress is required"])
	for field in ["start_transform", "end_transform", "path_distance_m", "maximum_displacement_m"]:
		if not progress.has(field):
			errors.append("scenario_progress.%s is required" % field)
	if not errors.is_empty():
		return errors
	if scenario_name == &"torrent_range_combat_reuse_route":
		return _validate_combat_progress(progress)
	if scenario_name in [&"ember_surface_walk_route", &"aurora_surface_walk_route"]:
		return _validate_surface_progress(progress, scenario_name == &"aurora_surface_walk_route")
	if not _finite_number(progress.get("path_distance_m")) \
		or float(progress.get("path_distance_m", 0.0)) <= MINIMUM_SMOKE_MOVEMENT_METERS:
		errors.append("actor path did not advance")
	if not _finite_number(progress.get("maximum_displacement_m")) \
		or float(progress.get("maximum_displacement_m", 0.0)) <= MINIMUM_SMOKE_MOVEMENT_METERS:
		errors.append("actor transform did not move")
	if scenario_name == &"halyard_cabin_walk_route":
		if str(progress.get("actor_type", "")) != "PlayerController":
			errors.append("cabin actor is not PlayerController")
		for field in ["support_throughout", "occupancy_throughout", "control_throughout", "inside_throughout", "stationary_throughout", "healthy_throughout"]:
			if not bool(progress.get(field, false)):
				errors.append("cabin requires " + field)
		for field in ["local_path_distance_m", "maximum_local_displacement_m", "sample_local_path_distance_m"]:
			if not _finite_number(progress.get(field)) or float(progress.get(field, 0.0)) <= MINIMUM_SMOKE_MOVEMENT_METERS:
				errors.append("cabin did not move: " + field)
		if str(progress.get("policy", "")) == "full_route":
			if not bool(progress.get("outbound_reached", false)) or not bool(progress.get("return_reached", false)):
				errors.append("cabin did not complete an out-and-back")
			if not _finite_number(progress.get("aisle_length_m")) or float(progress.get("aisle_length_m", 0.0)) < 1.0 or float(progress.get("sample_local_path_distance_m", 0.0)) < float(progress.get("aisle_length_m", INF)):
				errors.append("cabin sampling did not cover one aisle length")
		return errors
	if scenario_name == &"station_embodied_route":
		if str(progress.get("actor_type", "")) != "PlayerController":
			errors.append("station actor is not PlayerController")
		if not _finite_number(progress.get("horizontal_path_distance_m")) \
			or float(progress.get("horizontal_path_distance_m", 0.0)) <= MINIMUM_SMOKE_MOVEMENT_METERS:
			errors.append("PlayerController horizontal route did not advance")
		if not bool(progress.get("control_enabled_end", false)):
			errors.append("PlayerController control was not enabled")
		if str(progress.get("policy", "")) == "full_route" \
			and float(progress.get("path_distance_m", 0.0)) < MINIMUM_FULL_STATION_PATH_METERS:
			errors.append("full station route did not cover its minimum path")
		return errors
	if scenario_name != &"nearby_sector_ship_flight_route":
		errors.append("unknown scenario progress contract")
		return errors
	if not bool(progress.get("engine_online_observed", false)):
		errors.append("flight never observed ONLINE propulsion")
	if not bool(progress.get("accepted_propulsion_observed", false)):
		errors.append("flight never observed accepted propulsion demand")
	if not _finite_number(progress.get("maximum_target_progress_m")) \
		or float(progress.get("maximum_target_progress_m", 0.0)) <= MINIMUM_SMOKE_MOVEMENT_METERS:
		errors.append("ship made no progress toward the route target")
	if not _finite_number(progress.get("minimum_hull")) \
		or not bool(progress.get("healthy_throughout", false)) \
		or bool(progress.get("destroyed_end", true)) \
		or float(progress.get("minimum_hull", 0.0)) <= 0.0:
		errors.append("ship did not remain healthy")
	if bool(progress.get("endpoint_required", false)) and (
		not _finite_number(progress.get("sample_path_distance_m"))
		or float(progress.get("sample_path_distance_m", 0.0)) <= MINIMUM_SMOKE_MOVEMENT_METERS
	):
		errors.append("flight did not move during sampling")
	if bool(progress.get("endpoint_required", false)) \
		and (
			not _finite_number(progress.get("minimum_target_distance_m"))
			or float(progress.get("minimum_target_distance_m", INF)) > FLIGHT_ENDPOINT_RADIUS_METERS
		):
		errors.append("full flight never entered the route endpoint radius")
	return errors


## JSON readers produce floats. Restrict identities/counts to positive exact
## integers in JSON's safe range rather than truncating fractions or strings.
static func _positive_json_integer(value: Variant) -> bool:
	return _finite_number(value) and float(value) >= 1.0 \
		and float(value) <= 9007199254740991.0 and floorf(float(value)) == float(value)


static func _validate_combat_progress(progress: Dictionary) -> PackedStringArray:
	var errors := PackedStringArray()
	if str(progress.get("actor_type", "")) != "HeroShip" or str(progress.get("combat_source", "")) != "production_local_fire_live_authority" or str(progress.get("target_id", "")) != "DRONE-01":
		errors.append("combat requires production Torrent local fire at DRONE-01")
	if not bool(progress.get("identity_and_control_throughout", false)):
		errors.append("combat identity or piloting control changed")
	for field in ["source_id", "source_instance_id", "target_instance_id", "adapter_instance_id", "authority_instance_id"]:
		if not _positive_json_integer(progress.get(field)):
			errors.append("combat requires positive " + field)
	var required_cycles := 2 if str(progress.get("policy", "")) == "full_route" else 1
	for phase in ["totals", "sampling"]:
		var counts := progress.get(phase, {}) as Dictionary
		for field in ["projectiles", "shots", "hits", "damage_events", "destructions", "reuses"]:
			if not _positive_json_integer(counts.get(field)):
				errors.append("combat %s requires actual %s" % [phase, field])
		if int(counts.get("projectiles", 0)) < int(counts.get("shots", 0)) or int(counts.get("shots", 0)) < int(counts.get("hits", 0)) or counts.get("hits") != counts.get("damage_events"):
			errors.append("combat damage must correlate with production shots")
		if int(counts.get("destructions", 0)) < required_cycles or int(counts.get("reuses", 0)) < required_cycles or int(counts.get("reuses", 0)) > int(counts.get("destructions", 0)) or int(counts.get("destructions", 0)) > int(counts.get("hits", 0)):
			errors.append("combat requires destroyed-target reuse cycles during " + phase)
	for field in ["maximum_sample_shot_gap_seconds", "maximum_sample_hit_gap_seconds"]:
		if not _finite_number(progress.get(field)) or float(progress.get(field, -1.0)) < 0.0 or float(progress.get(field, INF)) > 10.0:
			errors.append("combat sampling activity stalled: " + field)
	return errors


static func _stage_scenario(
		tree: SceneTree,
		game: GameFlow,
		world: ShipyardWorld,
		player: PlayerController,
		ship: HeroShip,
		scenario_name: StringName,
		input_guard: BenchmarkInputGuard
	) -> Dictionary:
	# Use the production Begin Shift transition: calling GameFlow directly leaves
	# the opaque intro over the world and never reveals the gameplay HUD.
	var hud := game.get_node_or_null("HUD") as GameHUD
	if hud == null:
		return {"staging_valid": false, "staging_error": "production HUD unavailable"}
	var began := [false]
	var on_begin := func() -> void: began[0] = true
	hud.start_requested.connect(on_begin, CONNECT_ONE_SHOT)
	hud._begin()
	var begin_started := Time.get_ticks_msec()
	while not began[0] and not input_guard.aborted and Time.get_ticks_msec() - begin_started < BEGIN_SHIFT_READY_TIMEOUT_MS:
		await tree.process_frame
	if hud.start_requested.is_connected(on_begin):
		hud.start_requested.disconnect(on_begin)
	if input_guard.aborted or not began[0]:
		return {"staging_valid": false, "staging_error": "benchmark aborted" if input_guard.aborted else "Begin Shift transition did not complete"}
	if scenario_name == &"aurora_surface_walk_route":
		return await _stage_aurora_surface(tree, game, player, input_guard)
	if scenario_name == &"ember_surface_walk_route":
		return await _stage_ember_surface(tree, game, player, input_guard)
	if scenario_name == &"station_embodied_route":
		player.teleport_to(world.get_player_spawn())
		player.set_control_enabled(true)
		return {
			"staging_valid": true,
			"actor": "production PlayerController",
			"global_rng_seed": _scenario_seed(scenario_name),
			"start_transform": _transform_record(world.get_player_spawn()),
			"sequence": "forward, forward+right, forward, forward+left in four equal frame segments",
		}
	if scenario_name == &"halyard_cabin_walk_route":
		var craft := ship as HalyardCrewTransport
		var berth := world.get_berth_node(craft.get_home_berth_id())
		if berth == null or berth.get_occupant() != craft or not craft.global_transform.is_equal_approx(world.get_berth_transform(craft.get_home_berth_id())) or craft.is_piloted() or craft.is_destroyed() or craft.get_crew_seat_anchors().size() != 6:
			return {"staging_valid": false, "staging_error": "healthy stationary home Halyard unavailable"}
		var endpoints := _cabin_endpoints(craft)
		player.teleport_to(Transform3D(craft.global_basis.orthonormalized(), craft.to_global(endpoints[0])))
		player.set_control_enabled(true)
		for _index in 12:
			await tree.physics_frame
			if input_guard.aborted:
				return {"staging_valid": false, "staging_error": "benchmark aborted"}
		var supported := player.is_on_floor() and not player.is_seated() and craft.get_moving_interior_component().is_occupant_registered(player)
		return {
			"staging_valid": supported, "staging_error": "cabin support/occupancy unavailable" if not supported else "",
			"actor": "production PlayerController", "route_source": "live_halyard_crew_seat_aisle",
			"global_rng_seed": _scenario_seed(scenario_name), "start_transform": _transform_record(player.global_transform),
			"aisle_endpoints_local": [[endpoints[0].x, endpoints[0].y, endpoints[0].z], [endpoints[1].x, endpoints[1].y, endpoints[1].z]],
			"sequence": "normal forward input with camera-yaw steering, repeated craft-local aisle out-and-back",
		}
	if scenario_name == &"torrent_range_combat_reuse_route":
		var target := world.get_node_or_null(^"ExteriorTargetRange/TargetDrone01") as StaticBody3D
		var adapter := target.get_node_or_null(^"AuthoritativeDamageable") as RangeTargetDamageableAdapter if target != null else null
		if adapter == null or adapter.is_destroyed() or game.combat_authority == null or game.combat_authority.get_source_id(ship) <= 0:
			return {"staging_valid": false, "staging_error": "registered production Torrent/range target unavailable"}
		var marker := (target.get_parent() as Node3D).to_global(target.get_meta("base_position") as Vector3)
		game.active_ship = ship
		# DRONE-01 shares x=-13 with the station launch gantry's SignalMast
		# at z=-66. Approach from the exterior side so neither the camera's
		# reticle ray nor the converging muzzle rays encounter that mast first.
		ship.global_transform = Transform3D(Basis.looking_at(Vector3.BACK, Vector3.UP), marker - Vector3(0.0, 0.0, 35.0))
		ship.velocity = Vector3.ZERO
		player.set_control_enabled(false)
		player.set_camera_active(false)
		game._piloting = true
		game.phase = GameFlow.Phase.FREE_FLIGHT
		ship.set_piloted(true)
		ship.get_camera().current = true
		hud.set_mode("piloting")
		hud.bind_hero_component_ship(ship)
		game.audio.set_on_foot(false)
		# Settle the production chase arm, then align its real centre ray using
		# ship translation only. Target, adapter, health and camera stay authored.
		var camera_settled := false
		for index in 120:
			await tree.physics_frame
			await tree.process_frame
			if input_guard.aborted:
				return {"staging_valid": false, "staging_error": "benchmark aborted"}
			if index >= 11 and ship.get_current_chase_camera_rotation_lag_degrees() <= 0.01:
				camera_settled = true
				break
		if not camera_settled:
			return {"staging_valid": false, "staging_error": "production chase camera did not settle"}
		var camera := ship.get_camera()
		var direction := camera.project_ray_normal(camera.get_viewport().get_visible_rect().size * 0.5).normalized()
		var ray_point := camera.global_position + direction * (marker - camera.global_position).dot(direction)
		ship.global_position += marker - ray_point
		ship.velocity = Vector3.ZERO
		await tree.physics_frame
		await tree.process_frame
		# Verify the same read-only reticle query used by HeroShip before any
		# weapon input or measurement. Obstruction is a staging failure, never
		# permission to move a target or bypass the production combat path.
		direction = camera.project_ray_normal(camera.get_viewport().get_visible_rect().size * 0.5).normalized()
		var query := PhysicsRayQueryParameters3D.create(camera.global_position,
			camera.global_position + direction * ship._get_weapon_targeting_distance(),
			HeroShip.WEAPON_AIM_MASK, [ship.get_rid()])
		query.collide_with_areas = true
		query.collide_with_bodies = true
		var reticle_hit := ship.get_world_3d().direct_space_state.intersect_ray(query)
		var collider: Variant = reticle_hit.get("collider")
		var target_visible: bool = collider == target
		return {
			"staging_valid": not input_guard.aborted and target_visible,
			"staging_error": "production reticle ray does not intersect DRONE-01" if not target_visible else "",
			"staging_reticle": {
				"origin": [camera.global_position.x, camera.global_position.y, camera.global_position.z],
				"direction": [direction.x, direction.y, direction.z],
				"target_base": [marker.x, marker.y, marker.z],
				"target_intersection": target_visible,
				"collider_path": String(collider.get_path()) if collider is Node else "",
			},
			"actor": "production TorrentInterceptor and LocalShipInputSource",
			"route_source": "live_exterior_range_destroyed_target_reuse", "target_id": "DRONE-01",
			"global_rng_seed": _scenario_seed(scenario_name), "start_transform": _transform_record(ship.global_transform),
			"sequence": "held local fire; one-second destruction presentation; production reset after authoritative destruction",
		}
	var binding := game.get_node_or_null(
		^"CinderStreamingProductionBinding"
	) as CinderStreamingProductionBinding
	var bootstrap := game.get_node_or_null(
		^"CinderStreamingBootstrap"
	) as CinderStreamingBootstrap
	if binding == null or bootstrap == null:
		return {
			"staging_valid": false,
			"staging_error": "production Cinder streaming composition unavailable",
		}
	var bootstrap_snapshot := bootstrap.get_snapshot()
	var anchor_value: Variant = bootstrap_snapshot.get("navigation_anchor_position")
	if not anchor_value is Vector3 or not (anchor_value as Vector3).is_finite():
		return {
			"staging_valid": false,
			"staging_error": "production Cinder navigation anchor unavailable",
		}
	# The nearby-sector benchmark is a production streaming consumer. Stage its
	# already-selected production ship at the registered navigation anchor and
	# let the one production physics binding request/commit the real generation
	# before resolving geometry-owned route markers. There is deliberately no
	# unrelated coordinate fallback.
	game.active_ship = ship
	ship.velocity = Vector3.ZERO
	ship.global_position = anchor_value as Vector3
	ship.set_piloted(true)
	var cluster: NearbySectorCluster
	for frame_index in STREAMING_READY_FRAME_BUDGET:
		await tree.physics_frame
		if input_guard.aborted:
			return {"staging_valid": false, "staging_error": "benchmark aborted"}
		await tree.process_frame
		if input_guard.aborted:
			return {"staging_valid": false, "staging_error": "benchmark aborted"}
		cluster = bootstrap.get_loaded_instance() as NearbySectorCluster
		if is_instance_valid(cluster):
			break
	if not is_instance_valid(cluster) or world.get_nearby_sector_cluster() != cluster:
		return {
			"staging_valid": false,
			"staging_error": "coordinator-owned Cinder generation did not become available",
		}
	var route_start := cluster.get_approach_lane_point(170.0)
	var route_target := cluster.get_dock_gate_center()
	if not route_start.is_finite() or not route_target.is_finite() \
		or route_start.is_equal_approx(route_target):
		return {
			"staging_valid": false,
			"staging_error": "streamed Cinder route markers are invalid",
		}
	var direction := (route_target - route_start).normalized()
	if direction.is_zero_approx():
		direction = Vector3.FORWARD
	ship.global_transform = Transform3D(Basis.looking_at(direction, Vector3.UP), route_start)
	ship.velocity = Vector3.ZERO
	# Match the completed boarding ownership before offering flight input.
	player.set_control_enabled(false)
	player.set_camera_active(false)
	game._piloting = true
	game.phase = GameFlow.Phase.FREE_FLIGHT
	ship.set_piloted(true)
	ship.get_camera().current = true
	hud.set_mode("piloting")
	hud.bind_hero_component_ship(ship)
	game.audio.set_on_foot(false)
	return {
		"staging_valid": true,
		"actor": "production TorrentInterceptor and LocalShipInputSource",
		"route_source": "coordinator_owned_cinder_streaming_generation",
		"streamed_location_id": String(CinderStreamingBootstrap.LOCATION_ID),
		"streamed_generation": int(cluster.get_meta(&"world_location_generation", -1)),
		"streaming_owner": "CinderStreamingBootstrap/WorldStreamingCoordinator",
		"global_rng_seed": _scenario_seed(scenario_name),
		"start_transform": _transform_record(ship.global_transform),
		"route_target": [route_target.x, route_target.y, route_target.z],
		"sequence": "continuous forward/reverse approach-lane shuttle with velocity-based braking at both endpoints",
	}


static func _ember_gravity_policy(game: GameFlow) -> PlanetarySurfaceGravityPolicy:
	var policy := PlanetarySurfaceGravityPolicy.new()
	var configured := policy.configure(EMBER_WORLD, EMBER_TERRAIN,
		game.ember_streaming_bootstrap.get_coordinate_frame_for_session(), 1.62)
	return policy if bool(configured.get("accepted", false)) else null


static func _stage_ember_surface(tree: SceneTree, game: GameFlow,
		player: PlayerController, guard: BenchmarkInputGuard) -> Dictionary:
	return await _stage_surface(tree, game, player, guard, false)


static func _stage_aurora_surface(tree: SceneTree, game: GameFlow,
		player: PlayerController, guard: BenchmarkInputGuard) -> Dictionary:
	return await _stage_surface(tree, game, player, guard, true)


static func _stage_surface(tree: SceneTree, game: GameFlow,
		player: PlayerController, guard: BenchmarkInputGuard, aurora: bool) -> Dictionary:
	var label := "Aurora" if aurora else "Ember"
	var bootstrap: PlanetaryStreamingBootstrap = game.aurora_streaming_bootstrap if aurora else game.ember_streaming_bootstrap
	var definition := AURORA_REGION if aurora else EMBER_REGION
	var initial_local := Vector3(-7.0, 0.2, -17.0) if aurora else Vector3(-5.0, 0.2, 0.5)
	if not is_instance_valid(bootstrap) or not is_instance_valid(game.common_world_origin_rebase_owner):
		return {"staging_valid": false, "staging_error": "Main " + label + " streaming/origin owners unavailable"}
	var frame := bootstrap.get_coordinate_frame_for_session()
	var initial_generation := frame.get_generation()
	var body_local: Vector3 = definition.body_local_center_m \
		+ definition.body_local_basis * initial_local
	var encoded := frame.body_local_to_orbital_position(body_local, initial_generation)
	if not bool(encoded.get("accepted", false)):
		return {"staging_valid": false, "staging_error": label + " initial body coordinate unavailable"}
	var decoded := frame.orbital_to_world_streaming_position(encoded.coordinate, initial_generation)
	if not bool(decoded.get("accepted", false)):
		return {"staging_valid": false, "staging_error": label + " initial world coordinate unavailable"}
	# The only actor placement. Main observes this real Player on the next tick,
	# loads the selected surface through its binding and commits the origin rebase.
	player.teleport_to(Transform3D(Basis.IDENTITY, decoded.position as Vector3))
	player.set_control_enabled(true)
	var scene: Node3D
	var region: Node3D
	var patch: StaticBody3D
	var ready := false
	var policy: PlanetarySurfaceGravityPolicy
	var started := Time.get_ticks_msec()
	for _index in 240:
		await tree.physics_frame
		await tree.process_frame
		if guard.aborted or Time.get_ticks_msec() - started > 15_000:
			break
		scene = bootstrap.get_loaded_instance() as Node3D
		if not is_instance_valid(scene) or frame.get_generation() <= initial_generation:
			continue
		if not (scene is AuroraTemperateAuthoredScene if aurora else scene is EmberMoonAuthoredScene):
			continue
		region = scene.get_node_or_null(^"LandingRegion") as Node3D
		patch = scene.get_node_or_null(^"LandingRegion/WalkablePatch") as StaticBody3D
		if not is_instance_valid(region) or not is_instance_valid(patch) or not game.is_ancestor_of(scene):
			continue
		policy = _aurora_gravity_policy(game) if aurora else _ember_gravity_policy(game)
		if policy == null:
			break
		var multiplier := game._network_ember_passenger_gravity(player.global_position, policy)
		if not is_finite(multiplier) or multiplier <= 0.0:
			break
		player.gravity_multiplier = multiplier
		if BenchmarkEmberWalker.has_support(player, region, patch):
			ready = true
			break
	if not ready:
		return {"staging_valid": false, "staging_error": "real " + label + " generation, committed origin rebase, gravity or floor support unavailable"}
	var legs: Array = []
	if aurora:
		for point: Vector3 in AURORA_COASTAL_POINTS:
			legs.append([point.x, point.y, point.z])
	else:
		for leg: Array in EMBER_ROUTE_LEGS:
			legs.append([str(leg[0]), float(leg[1]), bool(leg[2]), String(leg[3])])
	return {
		"staging_valid": true, "actor": "production PlayerController",
		"route_source": "authored_aurora_coastal_trail_lookout_loop" if aurora else "authored_ember_pad_egress_staging_loop",
		("route_points_region_local" if aurora else "route_legs_region_local"): legs,
		"initial_region_local_m": [initial_local.x, initial_local.y, initial_local.z],
		"streamed_location_id": String(bootstrap.get_location_id()),
		"streamed_generation": bootstrap.get_location_generation(),
		"coordinate_frame_generation": frame.get_generation(),
		"initial_coordinate_frame_generation": initial_generation,
		"streaming_owner": "Main/PlanetaryJourneyCoordinator/" + ("AuroraTemperateStreamingBootstrap" if aurora else "EmberMoonStreamingBootstrap"),
		"origin_owner": "Main/CommonWorldOriginRebaseOwner", "initial_player_placements": 1,
		"gravity_source": "production_policy_benchmark_adapter",
		"global_rng_seed": _scenario_seed(&"aurora_surface_walk_route" if aurora else &"ember_surface_walk_route"),
		"start_transform": _transform_record(player.global_transform),
		"sequence": "held authored movement actions in landing tangent frame; " + ("repeat coastal trail to lookout and back" if aurora else "repeat five outbound and four return legs"),
		"scope": "staged surface only; outbound/landing/return travel, Host journey gravity binding, rewards, endurance and native hardware NOT_RUN",
	}


static func _aurora_gravity_policy(game: GameFlow) -> PlanetarySurfaceGravityPolicy:
	var policy := PlanetarySurfaceGravityPolicy.new()
	var configured := policy.configure(AURORA_WORLD, AURORA_TERRAIN,
		game.aurora_streaming_bootstrap.get_coordinate_frame_for_session(), 9.8)
	return policy if bool(configured.get("accepted", false)) else null


static func _validate_surface_progress(progress: Dictionary, aurora: bool = false) -> PackedStringArray:
	var errors := PackedStringArray()
	var label := "Aurora" if aurora else "Ember"
	var minimum_gravity := 9.78 if aurora else 1.60
	var maximum_gravity := 9.82 if aurora else 1.64
	if progress.get("actor_type") != "PlayerController" or progress.get("world_id") != ("aurora_temperate_world" if aurora else "ember_moon") \
		or progress.get("route_source") != ("authored_aurora_coastal_trail_lookout_loop" if aurora else "authored_ember_pad_egress_staging_loop") \
		or progress.get("gravity_source") != "production_policy_benchmark_adapter":
		errors.append(label + " requires its production actor, world, route and gravity source")
	for field in ["scene_instance_id", "region_instance_id", "patch_instance_id", "player_instance_id",
			"coordinate_frame_generation", "location_generation", "observations", "sample_observations"]:
		if not _positive_json_integer(progress.get(field)):
			errors.append(label + " requires positive exact identity/count: " + field)
	for field in ["support_throughout", "control_throughout", "world_identity_throughout",
			"gravity_throughout", "held_input_throughout", "bounded_path_throughout"]:
		if progress.get(field) != true:
			errors.append(label + " requires " + field)
	for field in ["path_distance_m", "maximum_displacement_m", "local_path_distance_m",
			"maximum_local_displacement_m", "sample_local_path_distance_m"]:
		if not _finite_number(progress.get(field)) or float(progress.get(field, 0.0)) <= MINIMUM_SMOKE_MOVEMENT_METERS:
			errors.append(label + " did not move: " + field)
	for field in ["minimum_gravity_mps2", "maximum_gravity_mps2"]:
		if not _finite_number(progress.get(field)) or float(progress.get(field, 0.0)) < minimum_gravity or float(progress.get(field, 0.0)) > maximum_gravity:
			errors.append(label + " gravity outside production surface range: " + field)
	for field in ["minimum_gravity_multiplier", "maximum_gravity_multiplier"]:
		if not _finite_number(progress.get(field)) or float(progress.get(field, 0.0)) <= 0.0:
			errors.append(label + " multiplier invalid: " + field)
	if not _finite_number(progress.get("maximum_physics_step_m")) or float(progress.get("maximum_physics_step_m", INF)) >= 0.5:
		errors.append(label + " route contains a discontinuous step")
	for field in ["outbound_visits", "return_visits", "sample_outbound_visits", "sample_return_visits"]:
		var count: Variant = progress.get(field)
		if not _finite_number(count) or float(count) < 0.0 or floorf(float(count)) != float(count):
			errors.append(label + " endpoint count invalid: " + field)
	if float(progress.get("sample_local_path_distance_m", INF)) > float(progress.get("local_path_distance_m", 0.0)) + 0.001 \
		or float(progress.get("sample_observations", INF)) > float(progress.get("observations", 0.0)):
		errors.append(label + " sampling exceeds observed physical progress")
	if progress.get("policy") == "full_route":
		if not _positive_json_integer(progress.get("sample_outbound_visits")) or not _positive_json_integer(progress.get("sample_return_visits")) \
			or float(progress.get("sample_local_path_distance_m", 0.0)) < 100.0:
			errors.append(label + " sampling did not walk the authored out-and-back")
	if aurora and progress.get("policy") == "full_route":
		for field in ["terrain_support_observations", "sample_terrain_support_observations",
				"lookout_floor_support_observations", "sample_lookout_floor_support_observations"]:
			if not _positive_json_integer(progress.get(field)):
				errors.append("Aurora requires authored terrain/lookout floor support: " + field)
	return errors


static func capture_resolution(
		tree: SceneTree, requested: Vector2i, input_guard: BenchmarkInputGuard = null
	) -> Dictionary:
	var native_display := DisplayServer.get_name() != "headless"
	var framebuffer := Vector2i.ZERO
	if native_display:
		# A hidden/minimized window may stop drawing. Keep operator abort live
		# while waiting for the real framebuffer required by a successful report.
		var drawn := [false]
		var on_draw := func() -> void: drawn[0] = true
		RenderingServer.frame_post_draw.connect(on_draw, CONNECT_ONE_SHOT)
		while not drawn[0] and (input_guard == null or not input_guard.aborted):
			await tree.process_frame
		if RenderingServer.frame_post_draw.is_connected(on_draw):
			RenderingServer.frame_post_draw.disconnect(on_draw)
		if input_guard != null and input_guard.aborted:
			return {}
		var pixels := tree.root.get_texture().get_image()
		if pixels != null:
			framebuffer = pixels.get_size()
	var viewport := Vector2i(tree.root.get_visible_rect().size)
	var window := DisplayServer.window_get_size() if native_display else viewport
	return {
		"requested": [requested.x, requested.y],
		"viewport": [viewport.x, viewport.y],
		"window": [window.x, window.y],
		"framebuffer_available": native_display,
		"framebuffer": [framebuffer.x, framebuffer.y] if native_display else null,
		"matches_requested": viewport == requested and window == requested
			and (not native_display or framebuffer == requested),
	}


static func required_phase_seconds(target: Dictionary, smoke_run: bool) -> Dictionary:
	if smoke_run:
		return {"warmup": 0.0, "sample": 0.0}
	var budgets := target.get("budgets", {}) as Dictionary
	var result := {"warmup": MINIMUM_WARMUP_SECONDS, "sample": MINIMUM_SAMPLE_SECONDS}
	for phase: String in result:
		var value: Variant = budgets.get(phase + "_seconds", result[phase])
		if (value is int or value is float) and is_finite(float(value)):
			result[phase] = maxf(result[phase], float(value))
	return result


static func phase_incomplete(frames: int, minimum_frames: int, elapsed: float, minimum_seconds: float) -> bool:
	return frames < minimum_frames or elapsed < minimum_seconds


static func phase_progress(frames: int, minimum_frames: int, elapsed: float, minimum_seconds: float) -> float:
	var frame_progress := float(frames) / maxi(minimum_frames, 1)
	var time_progress := elapsed / minimum_seconds if minimum_seconds > 0.0 else 1.0
	return clampf(minf(frame_progress, time_progress), 0.0, 1.0)


static func _apply_scenario_input(
		scenario_name: StringName, frame: int, total_frames: int,
		flight_pilot: BenchmarkFlightPilot = null, cabin_walker: BenchmarkCabinWalker = null,
		combat: BenchmarkRangeCombat = null, surface_walker: BenchmarkEmberWalker = null
	) -> void:
	if surface_walker != null:
		surface_walker.apply_input()
		return
	if combat != null:
		combat.apply_input()
		return
	if cabin_walker != null:
		cabin_walker.apply_input()
		return
	if flight_pilot != null:
		flight_pilot.route_frame = frame
		flight_pilot.apply_input()
		return
	_release_inputs()
	Input.action_press(&"move_forward")
	if scenario_name == &"station_embodied_route":
		var quarter := maxi(total_frames / 4, 1)
		if frame >= quarter and frame < quarter * 2:
			Input.action_press(&"move_right")
		elif frame >= quarter * 3:
			Input.action_press(&"move_left")
	elif frame >= total_frames / 4 and frame < total_frames * 3 / 4:
		Input.action_press(&"sprint_boost")


static func _cabin_endpoints(craft: HalyardCrewTransport) -> Array[Vector3]:
	var min_z := INF
	var max_z := -INF
	for anchor in craft.get_crew_seat_anchors():
		var local := craft.to_local(anchor.global_position)
		min_z = minf(min_z, local.z)
		max_z = maxf(max_z, local.z)
	var deck_y := craft.to_local(craft.get_interior_deck_marker().global_position).y
	return [Vector3(0.0, deck_y, min_z), Vector3(0.0, deck_y, max_z)]


static func _release_inputs() -> void:
	BenchmarkInputGuard.release_inputs()

static func _scenario_seed(scenario_name: StringName) -> int:
	return 9005 if scenario_name == &"aurora_surface_walk_route" else (9004 if scenario_name == &"ember_surface_walk_route" else (9003 if scenario_name == &"torrent_range_combat_reuse_route" else (9001 if scenario_name == &"station_embodied_route" else 9002)))


static func percentile(samples: Array[float], fraction: float) -> float:
	if samples.is_empty():
		return -1.0
	var ordered := samples.duplicate()
	ordered.sort()
	var rank := ceili(clampf(fraction, 0.0, 1.0) * float(ordered.size()))
	return float(ordered[clampi(rank - 1, 0, ordered.size() - 1)])


static func summarize_samples(samples: Array[float]) -> Dictionary:
	return {
		"count": samples.size(),
		"p50": percentile(samples, 0.50),
		"p95": percentile(samples, 0.95),
		"p99": percentile(samples, 0.99),
		"max": percentile(samples, 1.0),
	}


static func _capture_monitor_sample(samples: Dictionary) -> void:
	for monitor_name in MONITORS:
		var value := float(Performance.get_monitor(int(MONITORS[monitor_name])))
		if String(monitor_name).ends_with("_ms"):
			value *= 1000.0
		(samples[monitor_name] as Array[float]).append(value)


static func _summarize_monitors(samples: Dictionary) -> Dictionary:
	var result := {}
	var names := samples.keys()
	names.sort()
	for monitor_name in names:
		result[monitor_name] = {
			"available": true,
			"summary": summarize_samples(samples[monitor_name] as Array[float]),
		}
	return result


static func capture_scene_counts(root_node: Node) -> Dictionary:
	var counts := {
		"nodes": 0,
		"mesh_instances": 0,
		"multimesh_nodes": 0,
		"multimesh_visible_copies": 0,
		"lights": 0,
		"particle_systems": 0,
	}
	var pending: Array[Node] = [root_node]
	while not pending.is_empty():
		var node := pending.pop_back() as Node
		counts.nodes = int(counts.nodes) + 1
		if node is MultiMeshInstance3D:
			counts.multimesh_nodes = int(counts.multimesh_nodes) + 1
			var multimesh := (node as MultiMeshInstance3D).multimesh
			if multimesh != null:
				var visible := multimesh.visible_instance_count
				counts.multimesh_visible_copies = int(counts.multimesh_visible_copies) + (
					multimesh.instance_count if visible < 0 else visible
				)
		elif node is MeshInstance3D:
			counts.mesh_instances = int(counts.mesh_instances) + 1
		if node is Light3D:
			counts.lights = int(counts.lights) + 1
		if node is GPUParticles3D or node is CPUParticles3D:
			counts.particle_systems = int(counts.particle_systems) + 1
		for child in node.get_children():
			pending.append(child as Node)
	return counts


static func capture_source_state() -> Dictionary:
	var revision_output: Array = []
	var revision_exit := OS.execute("git", ["rev-parse", "HEAD"], revision_output, true)
	var status_output: Array = []
	var status_exit := OS.execute("git", ["status", "--porcelain=v1"], status_output, true)
	return {
		"git_sha": str(revision_output[0]).strip_edges() if revision_exit == 0 and not revision_output.is_empty() else "unknown",
		"git_dirty": status_exit != 0 or (not status_output.is_empty() and not str(status_output[0]).strip_edges().is_empty()),
	}


static func capture_environment(resolution: Vector2i, quality_level: int) -> Dictionary:
	var driver_info: Variant = PackedStringArray()
	if RenderingServer.has_method("get_video_adapter_driver_info"):
		driver_info = RenderingServer.call("get_video_adapter_driver_info")
	var api_version := "unavailable"
	if RenderingServer.has_method("get_video_adapter_api_version"):
		api_version = str(RenderingServer.call("get_video_adapter_api_version"))
	return {
		"godot_version": str(Engine.get_version_info().get("string", "unknown")),
		"os": {
			"name": OS.get_name(),
			"version": OS.get_version(),
			"distribution": OS.get_distribution_name(),
		},
		"cpu": {
			"name": OS.get_processor_name(),
			"logical_processors": OS.get_processor_count(),
		},
		"gpu": {
			"adapter": RenderingServer.get_video_adapter_name(),
			"vendor": RenderingServer.get_video_adapter_vendor(),
			"driver": driver_info,
			"api_version": api_version,
		},
		"render": {
			"method": RenderingServer.get_current_rendering_method(),
			"project_method": str(ProjectSettings.get_setting("rendering/renderer/rendering_method", "unknown")),
			"display_server": DisplayServer.get_name(),
			"resolution": [resolution.x, resolution.y],
			"vsync_mode": DisplayServer.window_get_vsync_mode(),
		},
		"profile": {
			"quality_level": quality_level,
			"quality_name": ["Low", "Medium", "High"][clampi(quality_level, 0, 2)],
		},
	}


static func classify_representativeness(observed: Dictionary, target: Dictionary) -> Dictionary:
	var reasons := PackedStringArray()
	var adapter := str((observed.get("gpu", {}) as Dictionary).get("adapter", "")).to_lower()
	var display := str((observed.get("render", {}) as Dictionary).get("display_server", "")).to_lower()
	for software_name in ["llvmpipe", "softpipe", "software", "swiftshader"]:
		if adapter.contains(software_name):
			reasons.append("software renderer detected: %s" % adapter)
	if display == "headless":
		reasons.append("headless display server is not representative")
	if target.is_empty():
		reasons.append("no separately declared target profile supplied")
	else:
		for key_path in [
			"os.name", "cpu.name", "gpu.adapter", "gpu.driver",
			"render.method", "render.display_server", "render.resolution",
			"profile.quality_name",
		]:
			var expected: Variant = _dictionary_path(target, key_path)
			var actual: Variant = _dictionary_path(observed, key_path)
			if expected == null:
				reasons.append("target profile missing required field %s" % key_path)
			elif JSON.stringify(expected) != JSON.stringify(actual):
				reasons.append("target mismatch %s: expected %s, observed %s" % [key_path, str(expected), str(actual)])
	return {
		"target_declared": not target.is_empty(),
		"hardware_match": reasons.is_empty(),
		"representative_pass": false,
		"performance_budget_pass": null,
		"reasons": reasons,
	}


static func build_report(
		source: Dictionary,
		environment: Dictionary,
		target: Dictionary,
		representativeness: Dictionary,
		scenarios: Array[Dictionary],
		configuration: Dictionary
	) -> Dictionary:
	return {
		"schema_version": SCHEMA_VERSION,
		"report_kind": REPORT_KIND,
		"generated_utc": Time.get_datetime_string_from_system(true, true),
		"source": source.duplicate(true),
		"environment": environment.duplicate(true),
		"target_profile": target.duplicate(true),
		"configuration": configuration.duplicate(true),
		"representativeness": representativeness.duplicate(true),
		"unavailable_metrics": {
			"gpu_frame_time_ms": {
				"available": false,
				"value": null,
				"reason": "no reliable per-frame GPU timer is exposed by this harness",
			},
			"vram_bytes": {
				"available": false,
				"value": null,
				"reason": "renderer memory counters are not portable enough for an acceptance claim",
			},
		},
		"scenarios": scenarios.duplicate(true),
	}


static func validate_report(report: Dictionary) -> PackedStringArray:
	return _validate_report(report, PackedStringArray(DEFAULT_SCENARIO_ORDER), false)


## Structural validation for one diagnostic route; never full-protocol acceptance.
static func validate_selected_diagnostic_report(report: Dictionary, scenario_selection: String) -> PackedStringArray:
	if not SCENARIO_NAMES.has(StringName(scenario_selection)):
		return PackedStringArray(["a known single diagnostic scenario is required"])
	return _validate_report(report, PackedStringArray([scenario_selection]), true)


static func _validate_report(report: Dictionary, expected_names: PackedStringArray, diagnostic_only: bool) -> PackedStringArray:
	var errors := PackedStringArray()
	if int(report.get("schema_version", -1)) != SCHEMA_VERSION:
		errors.append("schema_version must be %d" % SCHEMA_VERSION)
	if str(report.get("report_kind", "")) != REPORT_KIND:
		errors.append("report_kind is invalid")
	var source := report.get("source", {}) as Dictionary
	for field in ["git_sha", "git_dirty"]:
		if not source.has(field):
			errors.append("source.%s is required" % field)
	var environment := report.get("environment", {}) as Dictionary
	for path in [
		"godot_version", "os.name", "cpu.name", "gpu.adapter", "gpu.driver",
		"render.method", "render.display_server", "render.resolution",
		"profile.quality_name",
	]:
		if _dictionary_path(environment, path) == null:
			errors.append("environment.%s is required" % path)
	var unavailable := report.get("unavailable_metrics", {}) as Dictionary
	for metric in ["gpu_frame_time_ms", "vram_bytes"]:
		var entry := unavailable.get(metric, {}) as Dictionary
		if entry.is_empty() or bool(entry.get("available", true)) or entry.get("value", 0) != null:
			errors.append("%s must be explicitly unavailable with a null value" % metric)
	var configuration := report.get("configuration", {}) as Dictionary
	if not configuration.has("smoke_run") or not configuration.smoke_run is bool:
		errors.append("configuration.smoke_run boolean is required")
	var smoke_run := bool(configuration.get("smoke_run", false))
	var scenarios := report.get("scenarios", []) as Array
	if scenarios.size() != expected_names.size():
		errors.append("exactly one selected diagnostic scenario is required" if diagnostic_only else "exactly two named scenarios are required")
	var actual_names := PackedStringArray()
	for scenario_variant in scenarios:
		actual_names.append(str((scenario_variant as Dictionary).get("name", "")))
	if actual_names != expected_names or PackedStringArray(configuration.get("scenario_order", [])) != expected_names:
		errors.append("scenario names and configuration.scenario_order must match the required protocol")
	for scenario_variant in scenarios:
		var scenario := scenario_variant as Dictionary
		var scenario_name := StringName(scenario.get("name", ""))
		if not SCENARIO_NAMES.has(scenario_name):
			errors.append("unknown scenario name")
		if not bool(scenario.get("completed", false)):
			errors.append("scenario %s did not complete: %s" % [scenario_name, str(scenario.get("error", ""))])
		for progress_error in validate_scenario_progress(
			scenario_name, scenario.get("scenario_progress", {}) as Dictionary
		):
			errors.append("scenario %s: %s" % [scenario_name, progress_error])
		var progress := scenario.get("scenario_progress", {}) as Dictionary
		var expected_policy := "bounded_progress_smoke" if smoke_run else "full_route"
		if str(progress.get("policy", "")) != expected_policy:
			errors.append("scenario %s progress policy does not match configuration" % scenario_name)
		var endpoint_expected := not smoke_run and scenario_name == &"nearby_sector_ship_flight_route"
		if bool(progress.get("endpoint_required", false)) != endpoint_expected:
			errors.append("scenario %s endpoint requirement does not match configuration" % scenario_name)
		for observation in ["resolution_before", "resolution_after"]:
			var evidence := scenario.get(observation, {}) as Dictionary
			var expected_resolution: Variant = configuration.get("resolution", [])
			if evidence.get("requested") != expected_resolution \
					or evidence.get("viewport") != expected_resolution \
					or evidence.get("window") != expected_resolution \
					or (bool(evidence.get("framebuffer_available", false)) and evidence.get("framebuffer") != expected_resolution):
				errors.append("scenario %s %s does not match requested framebuffer" % [scenario_name, observation])
			if not smoke_run and not bool(evidence.get("framebuffer_available", false)):
				errors.append("full scenario requires observed framebuffer dimensions")
		var required := required_phase_seconds(report.get("target_profile", {}) as Dictionary, smoke_run)
		for phase: String in required:
			var elapsed := float(scenario.get(phase + "_elapsed_seconds", -1.0))
			if not is_finite(elapsed) or elapsed < float(required[phase]):
				errors.append("scenario %s %s elapsed duration is below required minimum" % [scenario_name, phase])
		var frame_delta := scenario.get("frame_delta_ms", {}) as Dictionary
		if not _valid_summary(frame_delta):
			errors.append("scenario frame_delta_ms summary is invalid")
		if int(scenario.get("warmup_frames", 0)) < (1 if smoke_run else DEFAULT_WARMUP_FRAMES) \
				or int(scenario.get("sample_count", 0)) < (2 if smoke_run else DEFAULT_SAMPLE_FRAMES):
			errors.append("scenario warm-up/sample counts are invalid")
	var representative := report.get("representativeness", {}) as Dictionary
	if diagnostic_only and bool(representative.get("representative_pass", false)):
		errors.append("representative_pass is forbidden for selected diagnostic protocol")
	if bool(representative.get("representative_pass", false)) and not bool(representative.get("hardware_match", false)):
		errors.append("representative_pass requires an exact target hardware match")
	if bool(representative.get("representative_pass", false)) and bool(source.get("git_dirty", true)):
		errors.append("representative_pass requires a clean source tree")
	if bool(representative.get("representative_pass", false)) and smoke_run:
		errors.append("representative_pass is forbidden for smoke protocol")
	return errors


static func _valid_summary(summary: Dictionary) -> bool:
	if int(summary.get("count", 0)) < 2:
		return false
	var p50 := float(summary.get("p50", -1.0))
	var p95 := float(summary.get("p95", -1.0))
	var p99 := float(summary.get("p99", -1.0))
	var maximum := float(summary.get("max", -1.0))
	return p50 >= 0.0 and p50 <= p95 and p95 <= p99 and p99 <= maximum


static func _finite_number(value: Variant) -> bool:
	if not value is int and not value is float:
		return false
	var number := float(value)
	return not is_nan(number) and not is_inf(number)


static func load_target_profile(path: String) -> Dictionary:
	if path.is_empty():
		return {}
	var absolute := ProjectSettings.globalize_path(path)
	var file := FileAccess.open(absolute, FileAccess.READ)
	if file == null:
		return {}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	return parsed as Dictionary if parsed is Dictionary else {}


static func _dictionary_path(dictionary: Dictionary, path: String) -> Variant:
	var cursor: Variant = dictionary
	for component in path.split("."):
		if not (cursor is Dictionary) or not (cursor as Dictionary).has(component):
			return null
		cursor = (cursor as Dictionary)[component]
	return cursor


static func _transform_record(transform: Transform3D) -> Dictionary:
	return {
		"origin": [transform.origin.x, transform.origin.y, transform.origin.z],
		"basis_x": [transform.basis.x.x, transform.basis.x.y, transform.basis.x.z],
		"basis_y": [transform.basis.y.x, transform.basis.y.y, transform.basis.y.z],
		"basis_z": [transform.basis.z.x, transform.basis.z.y, transform.basis.z.z],
	}


func _environment_int(name: String, fallback: int, minimum: int) -> int:
	var value := OS.get_environment(name)
	return maxi(value.to_int(), minimum) if value.is_valid_int() else fallback


func _environment_bool(name: String, fallback: bool) -> bool:
	var value := OS.get_environment(name).strip_edges().to_lower()
	if value in ["1", "true", "yes", "on"]:
		return true
	if value in ["0", "false", "no", "off"]:
		return false
	return fallback


func _environment_resolution(name: String, fallback: Vector2i) -> Vector2i:
	var value := OS.get_environment(name).to_lower().split("x")
	if value.size() != 2 or not value[0].is_valid_int() or not value[1].is_valid_int():
		return fallback
	return Vector2i(maxi(value[0].to_int(), 1), maxi(value[1].to_int(), 1))
