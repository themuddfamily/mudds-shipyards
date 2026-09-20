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
	Vector3(18.0, 0.0, -38.0),
	Vector3(-32.0, 0.0, -38.0),
	Vector3(-32.0, 0.0, 16.0),
	Vector3(-74.0, 0.0, 16.0),
]
const INTERACTION_LAYER := 1 << 3
## Every authored cue this composition owns is placed from a reading in an
## authored frame -- body-local, where the caldera floor reads y = 120,000 m,
## or the landing region's own frame, where it reads y = 0. The composition
## holding them is a plain `Node`, so a reading used straight as a node
## position lands in neither frame. Two interaction points were found 120 km
## overhead that way and nothing caught it, because a route cue or a practical
## has no reachability contract to fail. These bounds are what "on the caldera
## floor" means for the whole family: a cue is within 64 m of the floor
## vertically and inside the 1.5 km the authored surface content spans -- the
## furthest is the return beacon at 712 m.
const SURFACE_CUE_MAX_HEIGHT_M := 64.0
const SURFACE_CUE_MAX_RANGE_M := 1500.0
## The one cue in this composition that is not a surface cue. The orbital
## approach datum is authored 140 km from the moon's centre -- 20 km above the
## caldera -- and belongs in the body frame, so it is measured against that
## frame instead and skipped with its subtree here.
const ORBITAL_DATUM_NODE: StringName = &"OwnedOrbitalApproachRing"
const ORBITAL_DATUM_ALTITUDE_M := 20_000.0
## The two authored interaction points, in the caldera region's own frame.
## Both are authored as floor spots the pilot walks onto, so the live point
## has to stand there too -- not 120 km up in the body frame.
const SAMPLE_RACK_ACCESS_REGION_LOCAL := Vector3(28.0, 0.0, -4.8)
const BUNKER_ACCESS_REGION_LOCAL := Vector3(-17.5, 0.0, -17.5)
## Axis-aligned approach legs onto each authored spot, region-local.
const SAMPLE_RACK_ACCESS_LEGS := [
	Vector3(28.0, 0.0, 0.5),
	SAMPLE_RACK_ACCESS_REGION_LOCAL,
]
## The landed craft sits across the pad lane, so the walk to the bunker takes
## the same clear z = 8 corridor the authored egress route uses.
const BUNKER_ACCESS_LEGS := [
	Vector3(17.5, 0.0, 8.0),
	Vector3(-17.5, 0.0, 8.0),
	BUNKER_ACCESS_REGION_LOCAL,
]
const SIGHTLINE_TARGETS := {
	&"ember_collapsed_lava_tube": Vector3(-86.0, 3.5, 18.0),
	&"ember_caldera_survey_mast": Vector3(14.0, 9.0, -92.0),
	&"ember_wrecked_survey_lander": Vector3(62.0, 2.0, 54.0),
}

var _failures := PackedStringArray()
var _original_time_scale := 1.0
var _expedition_intent_composition: Node


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
	await _test_authored_interaction_points_stand_on_the_floor()
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


# ------------------------------------------------------------ interaction ---


## The sample rack and the survey bunker are authored as spots on the caldera
## floor. This measures where their live interaction points actually stand and
## walks the pilot onto each authored spot, because an interaction point that
## reports the right state from 120 km overhead is still unreachable.
func _test_authored_interaction_points_stand_on_the_floor() -> void:
	var fixture := await _fixture()
	if fixture.is_empty():
		return
	if not await _reach_on_foot(fixture):
		await _cleanup(fixture)
		return
	var composition := fixture.composition as Node
	var landing_root := fixture.landing_root as Node3D
	var player := fixture.player as PlayerController
	# The rack only joins the interaction layer while the relay survey owns a
	# live activity generation; the bunker is live for the whole visit.
	var survey_started: Dictionary = composition.call(&"start_relay_survey")
	_check(
		bool(survey_started.get("accepted", false)),
		"the relay survey starts so the rack point carries its press: %s"
			% [survey_started.get("reason", &"?")],
	)
	# The pad-guide tilt is driven off the live authored batch. Reading the
	# Host's scene id from the wrong place left this unbound and silent, so
	# the real Host has to be able to resolve it here.
	var authored_guides := (fixture.scene as Node).get_node_or_null(
		^"LandingRegion/SurfaceLandmarks/PadGuideVisuals"
	) as MultiMeshInstance3D
	var pad_status := (
		(composition.call(&"get_snapshot") as Dictionary).get(
			"relay_survey_presentation", {}
		) as Dictionary
	).get("landing_pad_survey_status", {}) as Dictionary
	_check(
		authored_guides != null
			and int(pad_status.get("guide_instance_id", 0)) \
				== authored_guides.get_instance_id()
			and int(pad_status.get("loaded_scene_instance_id", 0)) \
				== (fixture.scene as Node).get_instance_id(),
		"the relay survey's pad guides bind to the live authored batch: %s"
			% [pad_status],
	)
	for probe: Dictionary in [
		{
			"node": "OwnedSampleRackInteraction",
			"label": "sample rack",
			"prompt": "[ E ]  ANALYSE SAMPLE RACK",
			"authored": SAMPLE_RACK_ACCESS_REGION_LOCAL,
			"legs": SAMPLE_RACK_ACCESS_LEGS,
		},
		{
			"node": "OwnedSurveyBunkerInteraction",
			"label": "survey bunker",
			"prompt": "[ E ]  LOG BUNKER / GANTRY SURVEY",
			"authored": BUNKER_ACCESS_REGION_LOCAL,
			"legs": BUNKER_ACCESS_LEGS,
		},
	]:
		var point := composition.get_node_or_null(
			NodePath(str(probe.node))
		) as Area3D
		if point == null:
			_check(false, "the %s interaction point is composed" % [probe.label])
			continue
		var authored := probe.authored as Vector3
		var placed := landing_root.to_local(point.global_position)
		_check(
			placed.distance_to(authored) <= 1.0,
			"the %s point stands on its authored caldera spot: region-local %s, authored %s"
				% [probe.label, placed, authored],
		)
		var walked := true
		for leg: Vector3 in probe.legs as Array:
			if not await _walk_to(fixture, leg):
				walked = false
				break
		if not walked:
			_check(false, "the pilot walks onto the authored %s spot" % [probe.label])
			continue
		await _tick(fixture)
		var reach := player.global_position.distance_to(point.global_position)
		_check(
			point in player.get_nearby_interactables()
				and str(point.call(&"get_interaction_prompt")) == str(probe.prompt),
			"a pilot standing on the authored %s spot reaches its press %.1f m away: %s"
				% [probe.label, reach, point.call(&"get_interaction_prompt")],
		)
	_check_surface_cues_stand_on_the_caldera_floor(composition, landing_root, "")
	await _cleanup(fixture)


## The whole-family placement measurement. It walks everything the composition
## puts in the world that a pilot can see or touch -- meshes, batches, lights
## and collision -- and requires each one to stand on the caldera floor the
## pilot is walking on. One sweep covers every cue at once, which is the point:
## the family that broke here is exactly the set nobody writes a per-node
## contract for.
func _check_surface_cues_stand_on_the_caldera_floor(
		composition: Node, region: Node3D, label: String
	) -> void:
	var offenders := PackedStringArray()
	var measured := 0
	var orbital_datum_local := Vector3.INF
	var stack: Array[Node] = [composition]
	while not stack.is_empty():
		var node: Node = stack.pop_back()
		var spatial := node as Node3D
		# Anything the composition places itself has to stand in an authored
		# frame of its own rather than inherit the composition's, which is a
		# plain `Node` and therefore whatever frame it happens to hang under.
		# This catches the same defect at any magnitude, including the small
		# offsets a bounded distance cannot separate from an authored height.
		if spatial != null and node.get_parent() == composition \
				and not spatial.top_level:
			offenders.append("%s is not anchored to an authored frame" % [node.name])
		if node.name == ORBITAL_DATUM_NODE and node.get_parent() == composition:
			orbital_datum_local = region.to_local(spatial.global_position)
			continue
		for child in node.get_children():
			stack.append(child)
		if spatial == null or not (
			spatial is VisualInstance3D or spatial is CollisionShape3D
				or spatial is CollisionObject3D
		):
			continue
		measured += 1
		var placed := region.to_local(spatial.global_position)
		if absf(placed.y) > SURFACE_CUE_MAX_HEIGHT_M \
				or Vector2(placed.x, placed.z).length() > SURFACE_CUE_MAX_RANGE_M:
			offenders.append("%s at region-local %s" % [
				composition.get_path_to(spatial), placed,
			])
	_check(
		measured >= 20 and offenders.is_empty(),
		"%severy authored surface cue stands on the caldera floor (%d measured): %s"
			% [label, measured, offenders],
	)
	_check(
		absf(orbital_datum_local.y - ORBITAL_DATUM_ALTITUDE_M) <= 1.0
			and Vector2(orbital_datum_local.x, orbital_datum_local.z).length() <= 1.0,
		"%sthe orbital approach datum keeps its body-frame anchor %.0f km over the caldera: region-local %s"
			% [label, ORBITAL_DATUM_ALTITUDE_M / 1000.0, orbital_datum_local],
	)


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

	var offers_after_reentry := true
	for activity_id: StringName in ExpeditionScript.ACTIVITY_IDS:
		var offer := _offer_snapshot(fixture, activity_id)
		if StringName(offer.get("offer_state", &"")) != &"completed" \
				or bool(offer.get("pressable", true)) \
				or not str(offer.get("prompt", "")).begins_with("[ COMPLETE ]") \
				or int((offer.get("physical", {}) as Dictionary).get(
					"collision_layer", -1
				)) != 0 \
				or not bool(offer.get("intent_sink_bound", false)):
			offers_after_reentry = false
	_check(
		offers_after_reentry,
		"after a whole-composition re-entry both trailheads still read LOGGED and offer no second start",
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
	var started := await _walk_to_offer_and_press(fixture, wreck_id)
	_check(bool(started.get("accepted", false)),
		"an errand starts from its authored trailhead on foot: %s" % [started.get("reason", &"?")])
	if not bool(started.get("accepted", false)):
		await _cleanup(fixture)
		return
	if not await _walk_to(fixture, LANDER_WRECK_LEGS[0]):
		_check(false, "the abandoning pilot walks the first authored leg")
		await _cleanup(fixture)
		return
	var gave_up := await _walk_to_offer_and_press(fixture, wreck_id)
	_check(
		bool(gave_up.get("accepted", false))
			and str(gave_up.get("prompt_before", "")) \
				== "[ E ]  ABANDON LANDER WRECK SURVEY",
		"walking back to the trailhead offers the way out and one press takes it",
	)
	var abandoned := {"accepted": bool(gave_up.get("accepted", false))}
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
	var reoffered := _offer_snapshot(fixture, wreck_id)
	var sibling_free := _offer_snapshot(
		fixture, ExpeditionScript.LAVA_TUBE_ACTIVITY_ID
	)
	_check(
		StringName(reoffered.get("offer_state", &"")) == &"available"
			and bool(reoffered.get("pressable", false))
			and str(reoffered.get("prompt", "")) == "[ E ]  BEGIN LANDER WRECK SURVEY"
			and StringName(sibling_free.get("offer_state", &"")) == &"available",
		"abandoning clears the standing objective and re-offers both errands",
	)
	var flew_home := await _return_and_fly_home(fixture)
	_check(flew_home, "an abandoned errand still leaves a clean walk back, boarding and flight home")
	var aboard_and_away := true
	for activity_id: StringName in ExpeditionScript.ACTIVITY_IDS:
		var offer := _offer_snapshot(fixture, activity_id)
		var physical := offer.get("physical", {}) as Dictionary
		if bool(offer.get("active", true)) \
				or not str(offer.get("prompt", "?")).is_empty() \
				or bool(offer.get("pressable", true)) \
				or int(physical.get("collision_layer", -1)) != 0 \
				or bool(physical.get("marker_visible", true)):
			aboard_and_away = false
	_check(
		aboard_and_away
			and (fixture.player as PlayerController).get_nearby_interactables().is_empty(),
		"aboard the craft and away from the surface neither trailhead offers, prompts or shows anything",
	)
	await _cleanup(fixture)


func _run_expedition(
		fixture: Dictionary, activity_id: StringName, legs: Array
	) -> bool:
	var composition := fixture.composition as Node
	var display_name := str(
		(ExpeditionScript.ACTIVITY_SPECS[activity_id] as Dictionary).display_name
	).to_upper()
	var offered := _offer_snapshot(fixture, activity_id)
	_check(
		bool(offered.get("active", false))
			and StringName(offered.get("offer_state", &"")) == &"available"
			and bool(offered.get("pressable", false))
			and str(offered.get("prompt", "")) == "[ E ]  BEGIN %s" % display_name
			and int((offered.get("physical", {}) as Dictionary).get(
				"collision_layer", 0
			)) == INTERACTION_LAYER
			and str((offered.get("physical", {}) as Dictionary).get(
				"marker_text", ""
			)) == "%s\nERRAND AVAILABLE" % display_name
			and not bool((offered.get("authority", {}) as Dictionary).get(
				"activity", true
			))
			and bool((offered.get("accessibility", {}) as Dictionary).get(
				"reduced_flash_safe", false
			))
			and not bool((offered.get("accessibility", {}) as Dictionary).get(
				"animated", true
			)),
		"%s is offered on foot by name, with a press and a static marker" % activity_id,
	)
	var pressed := await _walk_to_offer_and_press(fixture, activity_id)
	if not bool(pressed.get("accepted", false)):
		push_error("EXPEDITION start rejected %s: %s" % [
			activity_id, pressed.get("reason", &"?")
		])
		return false
	var in_hand := _offer_snapshot(fixture, activity_id)
	_check(
		StringName(composition.call(&"get_active_caldera_expedition_id")) == activity_id
			and StringName(in_hand.get("offer_state", &"")) == &"active"
			and str(in_hand.get("prompt", "")) == "[ E ]  ABANDON %s" % display_name,
		"pressing the %s trailhead takes the errand and turns the point into the way out" % activity_id,
	)
	for other_id: StringName in ExpeditionScript.ACTIVITY_IDS:
		if other_id == activity_id:
			continue
		var sibling := _offer_snapshot(fixture, other_id)
		if StringName(sibling.get("offer_state", &"")) == &"completed":
			continue
		_check(
			StringName(sibling.get("offer_state", &"")) == &"busy"
				and not bool(sibling.get("pressable", true))
				and int((sibling.get("physical", {}) as Dictionary).get(
					"collision_layer", -1
				)) == 0
				and not bool((fixture.player as PlayerController).call(
					&"get_nearby_interactables"
				).has(_offer_point(fixture, other_id))),
			"the other errand's point stands down while %s is in hand" % activity_id,
		)
	var leg_index := 0
	for target: Vector3 in legs:
		if not await _walk_to(fixture, target):
			return false
		leg_index += 1
		if leg_index == 1:
			var walked := (composition.call(
				&"get_caldera_expedition_snapshot"
			) as Dictionary).get("activities", {}).get(activity_id, {}) as Dictionary
			_check(
				int(walked.get("checkpoint_count", -1)) == 2
					and int(walked.get("checkpoints_reached", -1)) >= 0
					and not bool(walked.get("reward_committed", true)),
				"%s reports live route progress out of two checkpoints while it is walked" % activity_id,
			)
	var snapshot: Dictionary = composition.call(&"get_caldera_expedition_snapshot")
	var record := (snapshot.get("activities", {}) as Dictionary).get(
		activity_id, {}
	) as Dictionary
	if not bool(record.get("reward_committed", false)):
		push_error("EXPEDITION %s incomplete: %s" % [activity_id, record])
		return false
	var logged := _offer_snapshot(fixture, activity_id)
	_check(
		StringName(logged.get("offer_state", &"")) == &"completed"
			and not bool(logged.get("pressable", true))
			and str(logged.get("prompt", "")) == "[ COMPLETE ]  %s LOGGED" % display_name
			and int((logged.get("physical", {}) as Dictionary).get(
				"collision_layer", -1
			)) == 0
			and not bool(_offer_point(fixture, activity_id).call(
				&"can_interact", fixture.player
			)),
		"finishing %s clears its standing objective and retires the press" % activity_id,
	)
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
	var configured: Dictionary = composition.call(
		&"configure", host, director,
		Callable(self, "_relay_reward_sink_stub"),
		host.get_generation(),
		Callable(),
		Callable(authority, "commit")
	)
	if not bool(configured.get("accepted", false)):
		return configured
	# GameFlow owns this seam in production. Standing in for it here keeps the
	# press on exactly the composition calls `begin_ember_caldera_expedition`
	# and `abandon_ember_caldera_expedition` terminate in.
	_expedition_intent_composition = composition
	var sink_installed: Dictionary = composition.call(
		&"configure_caldera_expedition_intent_sink",
		Callable(self, "_expedition_intent_sink")
	)
	if not bool(sink_installed.get("accepted", false)):
		return sink_installed
	return configured


## The caller-owned errand seam behind both trailhead offer points.
func _expedition_intent_sink(intent: Variant) -> Dictionary:
	if not intent is Dictionary \
			or not is_instance_valid(_expedition_intent_composition):
		return {"accepted": false, "reason": &"invalid_caldera_expedition_intent"}
	var request := intent as Dictionary
	var activity_id := StringName(request.get("activity_id", &""))
	if StringName(request.get("world_id", &"")) != &"ember_moon" \
			or not ExpeditionScript.is_expedition_activity(activity_id):
		return {"accepted": false, "reason": &"invalid_caldera_expedition_intent"}
	match StringName(request.get("action", &"")):
		&"begin":
			return _expedition_intent_composition.call(
				&"start_caldera_expedition", activity_id
			)
		&"abandon":
			return _expedition_intent_composition.call(
				&"abandon_caldera_expedition", activity_id, &"player_abandoned"
			)
	return {"accepted": false, "reason": &"invalid_caldera_expedition_intent"}


func _offer_point(fixture: Dictionary, activity_id: StringName) -> Area3D:
	return (fixture.composition as Node).get_node_or_null(
		NodePath("OwnedCalderaExpeditionOffer_%s" % activity_id)
	) as Area3D


func _offer_snapshot(fixture: Dictionary, activity_id: StringName) -> Dictionary:
	var offer := _offer_point(fixture, activity_id)
	return offer.call(&"get_snapshot") as Dictionary if offer != null else {}


func _trailhead_region_local(activity_id: StringName) -> Vector3:
	return (ExpeditionScript.ACTIVITY_SPECS[activity_id] as Dictionary).trailhead as Vector3


## Walks the pilot onto the authored trailhead and presses it the way the
## generic on-foot interaction seam does: the point must be discoverable
## through the player's own nearby-interactable scan first.
func _walk_to_offer_and_press(
		fixture: Dictionary, activity_id: StringName
	) -> Dictionary:
	var player := fixture.player as PlayerController
	var offer := _offer_point(fixture, activity_id)
	if offer == null:
		return {"accepted": false, "reason": &"offer_point_missing"}
	if not await _walk_to(fixture, _trailhead_region_local(activity_id)):
		return {"accepted": false, "reason": &"offer_point_unreachable"}
	await _tick(fixture)
	if offer not in player.get_nearby_interactables():
		push_error("OFFER %s not discoverable at %s (offer %s / player %s)" % [
			activity_id,
			(fixture.landing_root as Node3D).to_local(player.global_position),
			offer.global_position, player.global_position,
		])
		return {"accepted": false, "reason": &"offer_point_not_discoverable"}
	var prompt_before := str(offer.call(&"get_interaction_prompt"))
	return {
		"accepted": bool(offer.call(&"interact", player)),
		"reason": &"offer_pressed",
		"prompt_before": prompt_before,
	}


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
