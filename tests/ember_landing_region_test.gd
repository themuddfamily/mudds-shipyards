extends SceneTree

## Drives the authored Ember caldera as a landing region: the three walk-to
## landmarks and their routes on real terrain collision, and the two bounded
## caldera errands that stand beside the relay survey. Everything runs against
## the real streamed scene, the real `EmberSurfaceLoopHost`, the real
## `ActivityDirector`, the real planetary surface reward adapter and the real
## `GameFlowRewardAuthority` store.

const BOOTSTRAP_SCENE := preload(
	"res://scenes/world/components/ember_moon_streaming_bootstrap.tscn"
)
const EMBER_SCENE := preload("res://scenes/world/planets/ember_moon.tscn")
const ARROW_SCENE := preload("res://scenes/ships/arrow_recon_ship.tscn")
const PLAYER_SCENE := preload("res://scenes/player/player.tscn")
const CompositionScript := preload(
	"res://scripts/world/ember_planetary_surface_production_binding.gd"
)
const ExpeditionScript := preload(
	"res://scripts/activities/ember_caldera_expedition_activity.gd"
)
const AuthorityScript := preload("res://scripts/game/game_flow_reward_authority.gd")
const StoreScript := preload("res://scripts/persistence/user_data_store.gd")
const FilesystemScript := preload("res://scripts/persistence/user_data_filesystem.gd")

const PHYSICS_DELTA := 1.0 / 12.0
const TEST_TIME_SCALE := 5.0
const LEG_FRAME_BUDGET := 900
const BODY_RADIUS_M := 120_000.0

## Axis-aligned walking legs, region-local. Each errand's checkpoints sit on
## the authored route, so the pilot reaches them by walking the route.
const LANDER_WRECK_LEGS := [
	Vector3(56.0, 0.0, 0.5),
	Vector3(56.0, 0.0, 46.0),
	Vector3(52.0, 0.0, 46.0),
]
const LAVA_TUBE_LEGS := [
	Vector3(18.0, 0.0, 46.0),
	Vector3(18.0, 0.0, -38.0),
	Vector3(-32.0, 0.0, -38.0),
	Vector3(-32.0, 0.0, 16.0),
	Vector3(-74.0, 0.0, 16.0),
]
const SIGHTLINE_TARGETS := {
	&"ember_collapsed_lava_tube": Vector3(-86.0, 3.5, 18.0),
	&"ember_caldera_survey_mast": Vector3(14.0, 9.0, -92.0),
	&"ember_wrecked_survey_lander": Vector3(62.0, 2.0, 54.0),
}

var _failures := PackedStringArray()
var _original_time_scale := 1.0


class MemoryFilesystem extends FilesystemScript:
	var files: Dictionary = {}

	func file_exists(path: String) -> bool:
		return files.has(path)

	func directory_exists(_path: String) -> bool:
		return false

	func ensure_parent_directory(_path: String) -> Error:
		return OK

	func sync_directory(_path: String) -> Error:
		return OK

	func read_bytes(path: String, maximum_bytes: int) -> Dictionary:
		if not files.has(path):
			return {"error": ERR_FILE_NOT_FOUND, "bytes": PackedByteArray()}
		var bytes := (files[path] as PackedByteArray).duplicate()
		return {
			"error": OK if bytes.size() <= maximum_bytes else ERR_FILE_CORRUPT,
			"bytes": bytes if bytes.size() <= maximum_bytes else PackedByteArray(),
		}

	func write_bytes_and_flush(path: String, bytes: PackedByteArray) -> Error:
		files[path] = bytes.duplicate()
		return OK

	func remove_path(path: String) -> Error:
		if not files.has(path):
			return ERR_FILE_NOT_FOUND
		files.erase(path)
		return OK

	func rename_path(from_path: String, to_path: String) -> Error:
		if not files.has(from_path):
			return ERR_FILE_NOT_FOUND
		files[to_path] = (files[from_path] as PackedByteArray).duplicate()
		files.erase(from_path)
		return OK


func _init() -> void:
	call_deferred(&"_run")


func _run() -> void:
	_original_time_scale = Engine.time_scale
	Engine.time_scale = TEST_TIME_SCALE
	await _test_authored_landmarks_and_routes()
	await _test_caldera_expedition_visit()
	await _test_abandoned_expedition_leaves_the_pilot_free()
	Engine.time_scale = _original_time_scale
	_finish()


# ---------------------------------------------------------------- content ---


func _test_authored_landmarks_and_routes() -> void:
	var scene := EMBER_SCENE.instantiate() as EmberMoonAuthoredScene
	root.add_child(scene)
	await process_frame
	await physics_frame
	await physics_frame
	var audit := scene.audit()
	var census := audit.get("performance", {}) as Dictionary
	_check(
		bool(audit.get("valid", false))
			and int(census.get("node_count", -1)) <= 400
			and int(census.get("triangle_count", -1)) <= 60_000,
		"the expanded caldera still audits clean inside its node and triangle budget: %s"
			% [audit.get("error_codes", PackedStringArray())],
	)
	var lights := 0
	for node in scene.find_children("*", "Light3D", true, false):
		lights += 1
	_check(lights == 0, "the expanded caldera adds no light and therefore no shadow caster")

	var region := scene.get_node(^"LandingRegion") as Node3D
	var space := scene.get_world_3d().direct_space_state
	var silhouettes := {}
	var solids_exact := true
	for landmark_id: StringName in SIGHTLINE_TARGETS:
		var body := scene.get_node_or_null(
			EmberMoonAuthoredScene.SURFACE_LANDMARK_NODE_PATHS[landmark_id] as NodePath
		) as StaticBody3D
		if body == null:
			solids_exact = false
			continue
		var shapes := 0
		var batches := 0
		var highest := -INF
		for child in body.get_children():
			if child is CollisionShape3D:
				var box := (child as CollisionShape3D).shape as BoxShape3D
				shapes += 1
				solids_exact = solids_exact and box != null \
					and not (child as CollisionShape3D).disabled
				if box != null:
					highest = maxf(
						highest,
						(child as CollisionShape3D).position.y + box.size.y * 0.5
					)
			elif child is MultiMeshInstance3D:
				batches += 1
		solids_exact = solids_exact and shapes >= 4 and batches == 1 \
			and body.collision_layer == PhysicsLayers.WORLD_BODY_LAYER \
			and StringName(body.get_meta("landmark_id", &"")) == landmark_id \
			and bool(body.get_meta("solid_visual_collision", false)) \
			and not bool(body.get_meta("historical_geometry_authenticated", true))
		silhouettes[landmark_id] = {
			"height_m": highest,
			"material": (
				(body.get_child(0) as MultiMeshInstance3D).material_override
				if body.get_child(0) is MultiMeshInstance3D else null
			),
		}
	_check(
		solids_exact and silhouettes.size() == 3,
		"all three caldera landmarks are solid World-layer bodies with batched authored geometry",
	)

	var visible_from_pad := true
	var eye := Vector3(0.0, 1.7, 0.0)
	for landmark_id: StringName in SIGHTLINE_TARGETS:
		var target := SIGHTLINE_TARGETS[landmark_id] as Vector3
		var query := PhysicsRayQueryParameters3D.create(
			region.to_global(eye),
			region.to_global(target),
			PhysicsLayers.WORLD_BODY_LAYER
		)
		query.collide_with_areas = false
		var hit := space.intersect_ray(query)
		var expected := scene.get_node_or_null(
			EmberMoonAuthoredScene.SURFACE_LANDMARK_NODE_PATHS[landmark_id] as NodePath
		)
		visible_from_pad = visible_from_pad and not hit.is_empty() \
			and hit.get("collider") == expected \
			and eye.distance_to(target) > 60.0
	_check(
		visible_from_pad,
		"each landmark stands more than 60 m out and is in clear line of sight from the pad",
	)

	var heights: Array[float] = []
	var materials: Array = []
	for landmark_id: StringName in silhouettes:
		heights.append(float((silhouettes[landmark_id] as Dictionary).height_m))
		var material: Variant = (silhouettes[landmark_id] as Dictionary).material
		if material != null and not materials.has(material):
			materials.append(material)
	heights.sort()
	_check(
		materials.size() == 3 and heights.size() == 3
			and heights[1] - heights[0] > 1.0 and heights[2] - heights[1] > 8.0,
		"the three silhouettes read apart at distance by both height and surface: %s" % [heights],
	)

	var routes := scene.get_expedition_route_snapshot()
	var route_markers_exact := routes.size() == 3
	var walkable_everywhere := true
	for record: Dictionary in routes:
		var marker := scene.get_node_or_null(
			EmberMoonAuthoredScene.SURFACE_MARKER_NODE_PATHS[
				StringName(record.marker_id)
			] as NodePath
		) as Marker3D
		var points := record.points_region_local_m as PackedVector3Array
		route_markers_exact = route_markers_exact and marker != null \
			and StringName(marker.get_meta("route_id", &"")) == StringName(record.route_id) \
			and StringName(marker.get_meta("landmark_id", &"")) == StringName(record.landmark_id) \
			and marker.position == points[points.size() - 1]
		for index in points.size() - 1:
			walkable_everywhere = walkable_everywhere and _segment_is_supported(
				region, space, points[index], points[index + 1]
			)
	_check(
		route_markers_exact,
		"every expedition route ends on its own authored approach marker",
	)
	_check(
		walkable_everywhere,
		"every authored expedition route is continuously supported by real world collision",
	)
	var spine := scene.get_node_or_null(
		^"LandingRegion/SurfaceLandmarks/ExpeditionRouteSpineVisuals"
	) as MultiMeshInstance3D
	var accent := scene.get_node_or_null(
		^"LandingRegion/SurfaceLandmarks/EgressRouteVisual"
	) as MeshInstance3D
	_check(
		spine != null and accent != null
			and spine.multimesh != null
			and spine.multimesh.instance_count
				== EmberMoonAuthoredScene.EXPEDITION_ROUTE_INSTANCE_COUNT
			and spine.material_override == accent.material_override
			and spine.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			and spine.get_meta("route_ids", PackedStringArray()).size() == 3,
		"one batched chevron spine marks all three routes in the existing route colour",
	)
	scene.queue_free()
	await process_frame
	await process_frame


func _segment_is_supported(
		region: Node3D,
		space: PhysicsDirectSpaceState3D,
		from_local: Vector3,
		to_local: Vector3
	) -> bool:
	var steps := maxi(1, int(ceil(from_local.distance_to(to_local) / 2.0)))
	for index in steps + 1:
		var point := from_local.lerp(to_local, float(index) / float(steps))
		var query := PhysicsRayQueryParameters3D.create(
			region.to_global(point + Vector3(0.0, 4.0, 0.0)),
			region.to_global(point + Vector3(0.0, -6.0, 0.0)),
			PhysicsLayers.WORLD_BODY_LAYER
		)
		query.collide_with_areas = false
		var hit := space.intersect_ray(query)
		if hit.is_empty():
			return false
		var local_hit := region.to_local(hit.get("position", Vector3.INF) as Vector3)
		if absf(local_hit.y) > 0.4:
			return false
	return true


# -------------------------------------------------------------- expedition ---


func _test_caldera_expedition_visit() -> void:
	var fixture := await _fixture()
	if fixture.is_empty():
		return
	if not await _reach_on_foot(fixture):
		await _cleanup(fixture)
		return
	var composition := fixture.composition as Node
	var authority: RefCounted = fixture.authority
	var host := fixture.host as EmberSurfaceLoopHost

	var wreck_id := ExpeditionScript.LANDER_WRECK_ACTIVITY_ID
	var tube_id := ExpeditionScript.LAVA_TUBE_ACTIVITY_ID

	var wreck_done := await _run_expedition(fixture, wreck_id, LANDER_WRECK_LEGS)
	_check(wreck_done, "walking the authored wreck route completes the lander-wreck survey")
	var tube_done := await _run_expedition(fixture, tube_id, LAVA_TUBE_LEGS)
	_check(tube_done, "walking the authored tube route completes the lava-tube sounding")
	if not wreck_done or not tube_done:
		await _cleanup(fixture)
		return

	var store_snapshot := _reward_record(authority)
	var counts := store_snapshot.get("reward_counts", {}) as Dictionary
	_check(
		int(counts.get(String(ExpeditionScript.LANDER_WRECK_REWARD_ID), 0)) == 1
			and int(counts.get(String(ExpeditionScript.LAVA_TUBE_REWARD_ID), 0)) == 1
			and int(store_snapshot.get("total_receipts", 0)) == 2,
		"the one existing GameFlow reward store holds exactly one receipt per errand: %s" % [counts],
	)
	var replayed: Dictionary = composition.call(
		&"commit_caldera_expedition_reward", wreck_id
	)
	var replayed_counts := _reward_record(authority).get(
		"reward_counts", {}
	) as Dictionary
	_check(
		not bool(replayed.get("accepted", true))
			and replayed_counts == counts,
		"a second commit for a finished errand is refused and writes no second receipt",
	)

	var saved: Dictionary = composition.call(&"get_session_snapshot")
	var saved_expeditions := saved.get("caldera_expeditions", {}) as Dictionary
	var completed_ids := saved_expeditions.get(
		"completed_activity_ids", PackedStringArray()
	) as PackedStringArray
	_check(
		completed_ids.size() == 2
			and completed_ids.has(String(wreck_id))
			and completed_ids.has(String(tube_id)),
		"the mid-visit save records both finished errands",
	)

	var phase_before := host.get_phase()
	var attachment_before := host.get_attachment_generation()
	var composition_root := fixture.composition_root as Node
	var parent := composition_root.get_parent()
	parent.remove_child(composition_root)
	await process_frame
	parent.add_child(composition_root)
	await process_frame
	await physics_frame
	var after_reentry: Dictionary = composition.call(&"get_caldera_expedition_snapshot")
	var after_activities := after_reentry.get("activities", {}) as Dictionary
	var replay_after_reentry: Dictionary = composition.call(
		&"commit_caldera_expedition_reward", tube_id
	)
	_check(
		host.get_phase() == phase_before and host.is_attached()
			and host.get_attachment_generation() == attachment_before
			and int(host.get_snapshot().get("composition_reentry_count", 0)) == 1
			and bool((after_activities.get(wreck_id, {}) as Dictionary).get("reward_committed", false))
			and bool((after_activities.get(tube_id, {}) as Dictionary).get("reward_committed", false))
			and not bool(replay_after_reentry.get("accepted", true))
			and int(_reward_record(authority).get("total_receipts", 0)) == 2,
		"a whole-composition re-entry keeps the visit and both paid errands without re-paying either",
	)

	var restored := ExpeditionScript.new()
	var restore_result: Dictionary = restored.call(
		&"restore_persistence_snapshot", saved_expeditions
	)
	var restored_begin: Dictionary = restored.call(&"begin", tube_id, null)
	_check(
		bool(restore_result.get("accepted", false))
			and bool(restored.call(&"is_completed", wreck_id))
			and bool(restored.call(&"is_completed", tube_id))
			and StringName(restored_begin.get("reason", &""))
				== &"caldera_expedition_already_completed",
		"a saved caldera record restores both errands as already paid and refuses to reopen them",
	)

	var flew_home := await _return_and_fly_home(fixture)
	_check(flew_home, "the pilot walks back, boards and flies home after both errands")
	await _cleanup(fixture)


func _test_abandoned_expedition_leaves_the_pilot_free() -> void:
	var fixture := await _fixture()
	if fixture.is_empty():
		return
	if not await _reach_on_foot(fixture):
		await _cleanup(fixture)
		return
	var composition := fixture.composition as Node
	var host := fixture.host as EmberSurfaceLoopHost
	var player := fixture.player as PlayerController
	var authority: RefCounted = fixture.authority
	var wreck_id := ExpeditionScript.LANDER_WRECK_ACTIVITY_ID
	var started: Dictionary = composition.call(&"start_caldera_expedition", wreck_id)
	_check(bool(started.get("accepted", false)),
		"an errand starts on foot: %s" % [started.get("reason", &"?")])
	if not bool(started.get("accepted", false)):
		await _cleanup(fixture)
		return
	if not await _walk_to(fixture, LANDER_WRECK_LEGS[0]):
		_check(false, "the abandoning pilot walks the first authored leg")
		await _cleanup(fixture)
		return
	var abandoned: Dictionary = composition.call(
		&"abandon_caldera_expedition", wreck_id, &"player_abandoned"
	)
	var snapshot: Dictionary = composition.call(&"get_caldera_expedition_snapshot")
	var record := (snapshot.get("activities", {}) as Dictionary).get(
		wreck_id, {}
	) as Dictionary
	_check(
		bool(abandoned.get("accepted", false))
			and StringName(snapshot.get("active_activity_id", &"?")).is_empty()
			and StringName(record.get("state", &"")) == &"failed"
			and not bool(record.get("reward_committed", true))
			and int(_reward_record(authority).get("total_receipts", 0)) == 0,
		"abandoning an errand drops only the objective and pays nothing",
	)
	var advanced := await _tick(fixture)
	_check(
		bool(advanced.get("accepted", false))
			and host.get_phase() == EmberSurfaceLoopHost.Phase.ON_FOOT
			and player.is_control_enabled() and player.is_on_floor(),
		"the abandoning pilot keeps control, support and the live visit",
	)
	var flew_home := await _return_and_fly_home(fixture)
	_check(flew_home, "an abandoned errand still leaves a clean walk back, boarding and flight home")
	await _cleanup(fixture)


func _run_expedition(
		fixture: Dictionary, activity_id: StringName, legs: Array
	) -> bool:
	var composition := fixture.composition as Node
	var started: Dictionary = composition.call(&"start_caldera_expedition", activity_id)
	if not bool(started.get("accepted", false)):
		push_error("EXPEDITION start rejected %s: %s" % [
			activity_id, started.get("reason", &"?")
		])
		return false
	for target: Vector3 in legs:
		if not await _walk_to(fixture, target):
			return false
	var snapshot: Dictionary = composition.call(&"get_caldera_expedition_snapshot")
	var record := (snapshot.get("activities", {}) as Dictionary).get(
		activity_id, {}
	) as Dictionary
	if not bool(record.get("reward_committed", false)):
		push_error("EXPEDITION %s incomplete: %s" % [activity_id, record])
		return false
	return true


# ------------------------------------------------------------- locomotion ---


func _walk_to(fixture: Dictionary, target_region_local: Vector3) -> bool:
	if not await _walk_axis(fixture, 0, target_region_local.x):
		return false
	return await _walk_axis(fixture, 2, target_region_local.z)


func _walk_axis(fixture: Dictionary, axis: int, target: float) -> bool:
	var landing_root := fixture.landing_root as Node3D
	var player := fixture.player as PlayerController
	var start := landing_root.to_local(player.global_position)
	var forward := target > start[axis]
	if absf(target - start[axis]) <= 0.35:
		return true
	var action: StringName = (
		(&"move_forward" if forward else &"move_back") if axis == 0
		else (&"move_right" if forward else &"move_left")
	)
	Input.action_press(action)
	for _index in LEG_FRAME_BUDGET:
		var tick := await _tick(fixture)
		if not bool(tick.get("accepted", false)):
			Input.action_release(action)
			push_error("WALK rejected action=%s reason=%s local=%s" % [
				action, tick.get("reason", &"?"),
				landing_root.to_local(player.global_position),
			])
			return false
		var local := landing_root.to_local(player.global_position)
		if (forward and local[axis] >= target) or (not forward and local[axis] <= target):
			Input.action_release(action)
			return true
	Input.action_release(action)
	push_error("WALK exhausted action=%s target=%.2f local=%s" % [
		action, target, landing_root.to_local(player.global_position),
	])
	return false


func _reach_on_foot(fixture: Dictionary) -> bool:
	if not await _drive_to_phase(fixture, EmberSurfaceLoopHost.Phase.LANDED, 660):
		_check(false, "the caldera visit reaches LANDED through the real berth")
		return false
	var host := fixture.host as EmberSurfaceLoopHost
	host.request_disembark(host.get_generation(), host.get_attachment_generation())
	if not await _drive_to_phase(fixture, EmberSurfaceLoopHost.Phase.SURFACE_OUTBOUND, 600):
		_check(false, "the caldera visit disembarks onto the surface")
		return false
	if not await _walk_outbound_route(fixture):
		_check(false, "the caldera visit walks the authored egress to ON_FOOT")
		return false
	var configured := _configure_composition(fixture)
	if not bool(configured.get("accepted", false)):
		_check(false, "the planetary surface composition binds: %s"
			% [configured.get("reason", &"?")])
		return false
	return true


func _walk_outbound_route(fixture: Dictionary) -> bool:
	if not await _walk_axis(fixture, 0, -9.0):
		return false
	if not await _walk_axis(fixture, 2, 8.0):
		return false
	if not await _walk_axis(fixture, 0, 17.5):
		return false
	if not await _walk_axis(fixture, 2, 0.5):
		return false
	if not await _walk_axis(fixture, 0, 41.5):
		return false
	return (fixture.host as EmberSurfaceLoopHost).get_phase() \
		== EmberSurfaceLoopHost.Phase.ON_FOOT


func _return_and_fly_home(fixture: Dictionary) -> bool:
	var host := fixture.host as EmberSurfaceLoopHost
	var player := fixture.player as PlayerController
	var area := fixture.area as ShipBoardingArea
	# Come home along the far side of the staging relay, then down the authored
	# egress lane: the same corridor the outbound walk used, in reverse.
	if not await _walk_axis(fixture, 2, 16.0) \
			or not await _walk_axis(fixture, 0, 18.0) \
			or not await _walk_axis(fixture, 2, 0.0):
		return false
	if not bool((host.get_snapshot().surface_route as Dictionary).return_complete):
		push_error("RETURN route not complete at egress: %s"
			% [(fixture.landing_root as Node3D).to_local(player.global_position)])
		return false
	if not await _walk_axis(fixture, 2, 8.0) \
			or not await _walk_axis(fixture, 0, -9.0) \
			or not await _walk_axis(fixture, 2, 0.5):
		return false
	Input.action_press(&"move_forward")
	var near := false
	for _index in 120:
		await _tick(fixture)
		if area in player.get_nearby_interactables():
			near = true
			break
	Input.action_release(&"move_forward")
	if not near:
		push_error("RETURN never reached the BoardingArea")
		return false
	if not bool(host.request_reboard(
		host.get_generation(), host.get_attachment_generation()
	).get("accepted", false)):
		push_error("RETURN reboard rejected")
		return false
	if not await _drive_to_phase(fixture, EmberSurfaceLoopHost.Phase.REBOARDED, 60):
		return false
	if not bool(host.request_takeoff(
		host.get_generation(), host.get_attachment_generation()
	).get("accepted", false)):
		push_error("RETURN takeoff rejected")
		return false
	for _index in 2700:
		var tick := await _tick(fixture)
		if not bool(tick.get("accepted", false)):
			push_error("RETURN ascent rejected %s" % [tick.get("reason", &"?")])
			return false
		if host.get_phase() == EmberSurfaceLoopHost.Phase.COMPLETED:
			return true
	push_error("RETURN never completed the orbital return")
	return false


# ---------------------------------------------------------------- fixture ---


func _configure_composition(fixture: Dictionary) -> Dictionary:
	var host := fixture.host as EmberSurfaceLoopHost
	var director := fixture.director as ActivityDirector
	var authority: RefCounted = fixture.authority
	var composition := fixture.composition as Node
	return composition.call(
		&"configure", host, director,
		Callable(self, "_relay_reward_sink_stub"),
		host.get_generation(),
		Callable(),
		Callable(authority, "commit")
	)


## The relay survey keeps its own evidence-bearing production sink; this suite
## exercises the two caldera errands, so the relay seam is only kept valid.
func _reward_record(authority: RefCounted) -> Dictionary:
	return (authority.call(&"get_snapshot") as Dictionary).get(
		"record", {}
	) as Dictionary


func _relay_reward_sink_stub(_intent: Variant) -> Dictionary:
	return {"accepted": false, "reason": &"relay_reward_not_exercised"}


func _fixture() -> Dictionary:
	var world := Node3D.new()
	world.name = "SharedCompositionRoot"
	root.add_child(world)
	var host := EmberSurfaceLoopHost.new()
	host.name = "EmberSurfaceLoopHost"
	var bootstrap := BOOTSTRAP_SCENE.instantiate() as EmberMoonStreamingBootstrap
	bootstrap.name = "EmberMoonStreamingBootstrap"
	world.add_child(bootstrap)
	var frame := bootstrap.get_coordinate_frame_for_session()
	var origin_binding := EmberMoonStreamingProductionBinding.new()
	origin_binding.name = "EmberMoonStreamingProductionBinding"
	world.add_child(origin_binding)
	var origin_owner := CommonWorldOriginRebaseOwner.new()
	origin_owner.name = "CommonWorldOriginRebaseOwner"
	world.add_child(origin_owner)
	var origin_probe := Node3D.new()
	origin_probe.name = "OriginActorProbe"
	world.add_child(origin_probe)
	await process_frame
	await process_frame
	if not bool(origin_binding.audit().get("valid", false)) \
			or not bool(origin_owner.audit().get("valid", false)):
		_check(false, "fixture activates the exact Ember binding and common-origin owner")
		return {}
	origin_probe.global_position = bootstrap.global_position
	if not bool(_consume_real_origin_rebase(
		origin_binding, origin_owner, origin_probe
	).get("accepted", false)):
		_check(false, "fixture consumes the required Ember origin transaction")
		return {}
	await process_frame
	await process_frame
	var scene := bootstrap.get_loaded_instance() as EmberMoonAuthoredScene
	if scene == null:
		_check(false, "fixture resolves the current authored Ember root")
		return {}
	origin_probe.global_position = (
		scene.get_node(^"LandingRegion") as Node3D
	).global_position
	if not bool(_consume_real_origin_rebase(
		origin_binding, origin_owner, origin_probe
	).get("accepted", false)):
		_check(false, "fixture consumes the real surface-local origin transaction")
		return {}
	origin_probe.queue_free()
	await process_frame
	world.add_child(host)
	var berth := EmberSurfaceBerth.new()
	world.add_child(berth)
	berth.global_transform = (scene.get_node(^"LandingRegion") as Node3D).global_transform
	var ship := ARROW_SCENE.instantiate() as ArrowReconShip
	ship.name = "ArrowReconShip"
	world.add_child(ship)
	var player := PLAYER_SCENE.instantiate() as PlayerController
	player.name = "Player"
	world.add_child(player)
	var director := ActivityDirector.new()
	director.name = "ActivityDirector"
	world.add_child(director)
	var composition := CompositionScript.new() as Node
	composition.name = "EmberPlanetarySurfaceProductionBinding"
	world.add_child(composition)
	await process_frame
	await physics_frame
	ship.global_transform = (scene.get_node(^"LandingRegion") as Node3D).global_transform \
		* Transform3D(Basis.IDENTITY, EmberSurfaceLoopHost.APPROACH_ENTRY_REGION_LOCAL_M)
	ship.velocity = Vector3.ZERO
	var area := ship.get_node_or_null(^"ShipBoardingArea") as ShipBoardingArea
	player.teleport_to(area.global_transform)
	await physics_frame
	await physics_frame
	if not area.try_reserve(player) or not player.begin_boarding(
		ship.get_boarding_entry_transform(), ship.get_pilot_seat_anchor(), 0.0, ship
	):
		_check(false, "fixture establishes public seated/reservation state")
		return {}
	ship.set_piloted(true)
	var filesystem := MemoryFilesystem.new()
	var store := StoreScript.new("memory://ember-caldera-rewards.json", filesystem)
	if not bool((store.load() as Dictionary).get("accepted", false)):
		_check(false, "fixture loads the existing atomic user-data store")
		return {}
	var authority := AuthorityScript.new()
	if not bool((authority.call(&"configure", store) as Dictionary).get("accepted", false)):
		_check(false, "fixture configures the real GameFlow reward store")
		return {}
	var fixture := {
		"world": world,
		"host": host,
		"composition_root": world,
		"bootstrap": bootstrap,
		"frame": frame,
		"scene": scene,
		"landing_root": scene.get_node(^"LandingRegion"),
		"walkable": scene.get_node(^"LandingRegion/WalkablePatch"),
		"berth": berth,
		"ship": ship,
		"player": player,
		"area": area,
		"director": director,
		"composition": composition,
		"authority": authority,
		"origin_binding": origin_binding,
		"origin_owner": origin_owner,
	}
	var bound := host.bind_dependencies(
		bootstrap, berth, ship, player, 1.62, 1, 0, 0, world, origin_owner
	)
	if not bool(bound.get("accepted", false)):
		_check(false, "exact current dependencies bind: %s" % bound.get("reason", &""))
		return {}
	var started := host.start(
		host.get_generation(),
		host.get_attachment_generation(),
		int(host.get_snapshot().coordinate_frame_generation)
	)
	if not bool(started.get("accepted", false)):
		_check(false, "one measured staged fixture starts: %s" % started.get("reason", &""))
		return {}
	return fixture


func _consume_real_origin_rebase(
		binding: EmberMoonStreamingProductionBinding,
		owner: CommonWorldOriginRebaseOwner,
		actor: Node3D
	) -> Dictionary:
	var sample := {
		"available": true,
		"position": actor.global_position,
		"actor_kind": &"ship",
		"actor_instance_id": actor.get_instance_id(),
	}
	binding.physics_tick_from_caller_sample(PHYSICS_DELTA, sample)
	var generation := int(
		binding.get_snapshot().get("bound_coordinate_frame_generation", 0)
	)
	var preview := binding.preview_origin_rebase(generation)
	if not bool(preview.get("accepted", false)) \
			or not bool(preview.get("rebase_required", false)):
		return {
			"accepted": false,
			"reason": preview.get("reason", &"origin_preview_rejected"),
		}
	return owner.consume_rebase_preview(preview, sample)


func _drive_to_phase(fixture: Dictionary, phase: int, frame_budget: int) -> bool:
	var host := fixture.host as EmberSurfaceLoopHost
	var last_result := {}
	for _index in frame_budget:
		if host.get_phase() == phase:
			return true
		if host.get_phase() == EmberSurfaceLoopHost.Phase.FAILED:
			break
		last_result = await _tick(fixture)
		if not bool(last_result.get("accepted", false)):
			break
	if host.get_phase() != phase:
		push_error("DRIVE target=%d phase=%d reason=%s" % [
			phase, host.get_phase(), last_result.get("reason", &"budget_exhausted"),
		])
		return false
	return true


## Every caller tick feeds the composition the same already-admitted body-local
## player observation the production binding forwards, so an errand only
## advances on evidence the surface owner already accepted.
func _tick(fixture: Dictionary) -> Dictionary:
	await physics_frame
	var host := fixture.host as EmberSurfaceLoopHost
	var result := host.advance_physics(
		PHYSICS_DELTA,
		host.get_generation(),
		host.get_attachment_generation(),
		(fixture.frame as PlanetaryCoordinateFrame).get_generation(),
		1
	)
	_forward_expedition_observation(fixture)
	return result


func _forward_expedition_observation(fixture: Dictionary) -> void:
	var composition := fixture.composition as Node
	if composition == null or not composition.is_inside_tree():
		return
	var active := StringName(composition.call(&"get_active_caldera_expedition_id"))
	if active.is_empty():
		return
	var landing_root := fixture.landing_root as Node3D
	var player := fixture.player as PlayerController
	var body_local := landing_root.to_local(player.global_position) \
		+ Vector3(0.0, BODY_RADIUS_M, 0.0)
	composition.call(&"submit_caldera_expedition_position", active, body_local)
	var snapshot: Dictionary = composition.call(&"get_caldera_expedition_snapshot")
	var record := (snapshot.get("activities", {}) as Dictionary).get(
		active, {}
	) as Dictionary
	if StringName(
		(record.get("activity_reward", {}) as Dictionary).get("state", &"")
	) == &"awaiting_reward":
		composition.call(&"commit_caldera_expedition_reward", active)


func _cleanup(fixture: Dictionary) -> void:
	for action in [
		&"move_left", &"move_right", &"move_forward", &"move_back",
		&"sprint_boost", &"jump",
	]:
		Input.action_release(action)
	var world := fixture.get("world") as Node
	if is_instance_valid(world):
		world.queue_free()
	await process_frame
	await process_frame


func _check(condition: bool, message: String) -> void:
	if condition:
		print("PASS: ", message)
	else:
		_failures.append(message)
		push_error("FAIL: " + message)


func _finish() -> void:
	if _failures.is_empty():
		print("EMBER_LANDING_REGION_TEST_OK")
		quit(0)
		return
	for failure in _failures:
		push_error("EMBER_LANDING_REGION_TEST: " + failure)
	quit(1)
