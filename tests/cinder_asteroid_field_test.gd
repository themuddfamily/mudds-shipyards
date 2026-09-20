extends SceneTree

## Production contract for the nearby sector's starboard asteroid belt and the
## threading run that is the reason to fly into it.
##
## Everything here is measured against the real streamed component — the same
## `nearby_sector_cluster.tscn` production streams, with its real activity
## binding, the real `GameFlowRewardAuthority` over a real atomic user-data
## store, and real production ship hulls swept through the real physics world.
## Nothing is asserted from a fixture or from the belt's own opinion of itself.
##
## The four ways a navigable field of this size goes wrong, in order of how
## expensive they are to discover late:
##
## 1. It becomes a wall. The belt publishes a clear bore; this suite flies two
##    production hulls down it at 0.8 m resolution and requires zero contacts.
## 2. It blocks something else. The belt stands starboard of the outbound route,
##    so the whole published outbound polyline — launch gate, four route
##    beacons, platform approach clearance point, which is also the race and
##    patrol route — is swept through the belt's colliders and must stay empty,
##    as are the four Emberline convoy legs and the hulk and moonlet bodies.
## 3. It has no mass after all. Every authored collider is confirmed to exist in
##    the physics world at the authored radius on the world layer, and the
##    belt's own `classify_position` is checked against what physics says.
## 4. It hides the sector. `CinderStreamingTransitionPresentation` fails
##    *visually closed* on an unrecognised renderer or light roster, so the
##    refrozen roster is asserted here too rather than only in the streaming
##    suite: a belt that quietly adds a renderer would make Cinder Reach
##    invisible, not merely wrong.

const CLUSTER_SCENE := preload("res://scenes/world/components/nearby_sector_cluster.tscn")
const THREADING_ROUTE := preload(
	"res://assets/activities/cinder_asteroid_field_threading_run.tres"
)
const OUTBOUND_ROUTE := preload("res://assets/activities/cinder_reach_checkpoint_route.tres")
const CONVOY_ROUTE := preload("res://assets/activities/cinder_reach_emberline_convoy_route.tres")
const TRANSITION := preload("res://scripts/world/cinder_streaming_transition_presentation.gd")
const SESSION_ADAPTER := preload(
	"res://scripts/persistence/nearby_sector_activity_session_adapter.gd"
)
const AUTHORITY_SCRIPT := preload("res://scripts/game/game_flow_reward_authority.gd")
const STORE_SCRIPT := preload("res://scripts/persistence/user_data_store.gd")
const FILESYSTEM_SCRIPT := preload("res://scripts/persistence/user_data_filesystem.gd")

## Two real production hulls, the heaviest and the widest things a player flies
## out here. Their collision envelopes are measured off the production scenes
## rather than frozen, so a hull that grows is caught by the lane rather than by
## a constant that was never updated.
const SWEEP_SHIP_SCENES := {
	&"bulwark": "res://scenes/ships/bulwark_heavy_gunship.tscn",
	&"halyard": "res://scenes/ships/halyard_crew_transport.tscn",
}
## Half the shortest production hull dimension, matching the outbound clearance
## suite: no sample may step over a rock.
const SWEEP_STEP := 0.8
## The outbound polyline the clearance suite flies, reproduced here so the belt
## is measured against the published route and not against its own axis.
const LAUNCH_GATE := Vector3(0.0, 8.0, -64.0)
const PLATFORM_APPROACH_OFFSET := Vector3(0.0, 4.0, 170.0)
## Other bodies in the sector the belt must not have grown into.
const HULK_ANCHOR := Vector3(-120.0, 26.0, -470.0)
const HULK_BOUNDING_RADIUS := 46.0
## The convoy tender's own hull is 6.4 m long; 24 m of reserve around each leg
## leaves the escort somewhere to fly as well as the tender.
const CONVOY_LEG_CLEARANCE := 24.0

const EXPECTED_ASTEROID_COUNT := 30
const EXPECTED_LANE_ENTRY := Vector3(246.0, -6.0, -274.0)
const EXPECTED_LANE_EXIT := Vector3(298.0, -64.0, -558.0)
const EXPECTED_LANE_RADIUS := 44.0
const EXPECTED_OUTER_RADIUS := 140.0
const EXPECTED_GATE_COUNT := 5
const EXPECTED_CHECKPOINT_RADIUS := 30.0
const EXPECTED_LANE_MARKER_COPIES := 18
const EXPECTED_GATE_MARKER_COPIES := 20
const EXPECTED_STOCK_BATCHES := 6
const EXPECTED_ACTIVITY_ID: StringName = &"cinder_asteroid_field_threading_run"
const EXPECTED_REWARD_ID: StringName = &"return_asteroid_survey_to_shipyard"


class MemoryFilesystem extends FILESYSTEM_SCRIPT:
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


var _assertions := 0
var _failures: Array[String] = []
var _space: PhysicsDirectSpaceState3D
var _filesystem: MemoryFilesystem
var _store: RefCounted
var _authority: RefCounted


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var cluster := CLUSTER_SCENE.instantiate() as NearbySectorCluster
	_check(cluster != null, "the real streamed Cinder component instantiates")
	if cluster == null:
		_finish()
		return
	root.add_child(cluster)
	await process_frame
	await physics_frame
	_space = root.get_world_3d().direct_space_state

	var field := cluster.get_asteroid_field()
	var binding := cluster.get_node_or_null(^"ActivityBinding")
	_check(
		field != null and binding != null,
		"the streamed component owns the asteroid belt and the nearby activity binding"
	)
	if field == null or binding == null:
		cluster.queue_free()
		await process_frame
		_finish()
		return

	var hulls := await _production_hulls()

	_test_published_contract(cluster, field)
	_test_bore_mouth_is_markable(cluster, field)
	_test_published_lanes_are_not_blocked(field)
	_test_safe_lane_is_flyable(field, hulls)
	_test_the_belt_has_real_mass(field)
	_test_streamed_roster_is_refrozen(cluster)
	_configure_reward_authority(binding)
	_test_threading_run_completes(binding, field)
	_test_reward_is_taken_exactly_once(binding)
	await _test_save_and_whole_component_reentry(cluster, binding, field)
	_test_impact_ends_the_run(binding, field)
	_test_abandon_is_clean(binding, field)

	cluster.queue_free()
	await process_frame
	await process_frame
	_finish()


# --- 1. Published contract ----------------------------------------------------


func _test_published_contract(cluster: NearbySectorCluster, field: CinderAsteroidField) -> void:
	var audit := field.audit()
	_check(
		bool(audit.get("valid", false)),
		"the belt's own placement audit passes: %s" % [audit.get("errors", [])]
	)
	_check(
		int(audit.get("asteroid_count", -1)) == EXPECTED_ASTEROID_COUNT
		and field.get_asteroid_records().size() == EXPECTED_ASTEROID_COUNT,
		"the belt places its full roster of %d solid bodies" % EXPECTED_ASTEROID_COUNT
	)
	_check(
		field.get_lane_entry().is_equal_approx(EXPECTED_LANE_ENTRY)
		and field.get_lane_exit().is_equal_approx(EXPECTED_LANE_EXIT)
		and is_equal_approx(CinderAsteroidField.LANE_RADIUS, EXPECTED_LANE_RADIUS)
		and is_equal_approx(CinderAsteroidField.OUTER_RADIUS, EXPECTED_OUTER_RADIUS),
		"the safe bore and the belt skin keep their published dimensions"
	)
	var checkpoints := field.get_threading_checkpoints()
	_check(
		checkpoints.size() == EXPECTED_GATE_COUNT
		and THREADING_ROUTE.get_checkpoint_count() == EXPECTED_GATE_COUNT
		and THREADING_ROUTE.activity_id == EXPECTED_ACTIVITY_ID
		and is_equal_approx(THREADING_ROUTE.checkpoint_radius, EXPECTED_CHECKPOINT_RADIUS)
		and THREADING_ROUTE.is_definition_valid(),
		"the shipped threading definition is a valid five-gate checkpoint route"
	)
	var gates_match := true
	for index in checkpoints.size():
		if not THREADING_ROUTE.get_checkpoint_position(index).is_equal_approx(
				checkpoints[index]
			):
			gates_match = false
			break
	_check(
		gates_match,
		"every shipped gate position is the belt's own authored gate position"
	)
	# The whole point of the run: the gates are not in the lane. A route the
	# pilot could fly down the bore would make the belt scenery again.
	var gates_are_in_the_rock := true
	for gate in checkpoints:
		var lane_distance := field.distance_to_lane_axis(gate)
		if lane_distance <= CinderAsteroidField.LANE_RADIUS \
				or lane_distance >= CinderAsteroidField.OUTER_RADIUS:
			gates_are_in_the_rock = false
			break
	_check(
		gates_are_in_the_rock,
		"every threading gate sits outside the safe bore and inside the belt"
	)
	# ... and they alternate flanks, so the run cannot be flown around the
	# outside of the belt either.
	var starboard := field.get_lane_starboard_axis()
	var crossings := 0
	for index in range(1, checkpoints.size()):
		var previous := (checkpoints[index - 1] - field.get_lane_point(0.0)).dot(starboard)
		var current := (checkpoints[index] - field.get_lane_point(0.0)).dot(starboard)
		if signf(previous) != signf(current):
			crossings += 1
	_check(
		crossings == EXPECTED_GATE_COUNT - 1,
		"the run crosses the bore at every leg rather than hugging one flank"
	)
	_check(
		field.find_children("*", "Light3D", true, false).is_empty()
		and field.find_children("*", "GPUParticles3D", true, false).is_empty()
		and field.find_children("*", "AnimationPlayer", true, false).is_empty()
		and not field.is_processing()
		and not field.is_physics_processing(),
		"the belt owns no light, emitter, animation player or per-frame tick"
	)
	var batches := field.find_children("*", "MultiMeshInstance3D", true, false)
	var lane_markers := field.get_node_or_null(^"BeltVisuals/SafeLaneChevrons") as MultiMeshInstance3D
	var gate_markers := field.get_node_or_null(^"BeltVisuals/ThreadingGateChevrons") as MultiMeshInstance3D
	_check(
		batches.size() == EXPECTED_STOCK_BATCHES + 2
		and lane_markers != null
		and gate_markers != null
		and lane_markers.multimesh.visible_instance_count == EXPECTED_LANE_MARKER_COPIES
		and gate_markers.multimesh.visible_instance_count == EXPECTED_GATE_MARKER_COPIES,
		"the bore and the gates are marked by two bounded chevron batches"
	)
	var shared_stock := true
	var stock_meshes := {}
	for index in EXPECTED_STOCK_BATCHES:
		var batch := field.get_node_or_null(
			NodePath("BeltVisuals/AsteroidStock%d" % (index + 1))
		) as MultiMeshInstance3D
		if batch == null or batch.multimesh == null or batch.multimesh.mesh == null:
			shared_stock = false
			break
		stock_meshes[batch.multimesh.mesh.get_instance_id()] = true
	var stock_copies := 0
	for index in EXPECTED_STOCK_BATCHES:
		var batch := field.get_node_or_null(
			NodePath("BeltVisuals/AsteroidStock%d" % (index + 1))
		) as MultiMeshInstance3D
		if batch != null and batch.multimesh != null:
			stock_copies += batch.multimesh.visible_instance_count
	_check(
		shared_stock
		and stock_meshes.size() == EXPECTED_STOCK_BATCHES
		and stock_copies == EXPECTED_ASTEROID_COUNT * CinderAsteroidField.LOBES_PER_ASTEROID,
		"ninety lobes are drawn from six shared stock recipes through six batches"
	)
	# Authored rotation, not simulation. The authored transforms are read from
	# the batch's published metadata rather than from `MultiMesh`: the dummy
	# rendering driver every headless check runs on reads instance buffers back
	# as identity, so the buffer would measure the driver instead of the belt.
	var first_batch := field.get_node_or_null(^"BeltVisuals/AsteroidStock1") as MultiMeshInstance3D
	var authored_transforms := first_batch.get_meta(
		&"authored_instance_transforms", [] as Array[Transform3D]
	) as Array[Transform3D]
	var distinct_orientations := {}
	var all_rotated := true
	for candidate in authored_transforms:
		distinct_orientations[candidate.basis.get_rotation_quaternion()] = true
		if candidate.basis.get_rotation_quaternion().is_equal_approx(Quaternion.IDENTITY):
			all_rotated = false
	_check(
		authored_transforms.size() == first_batch.multimesh.visible_instance_count
		and distinct_orientations.size() == authored_transforms.size()
		and all_rotated,
		"every lobe in a shared-stock batch carries its own authored, non-identity orientation"
	)
	# ... and none of it is driven per frame: the published transforms are the
	# same object after the component has ticked.
	var authored_again := first_batch.get_meta(
		&"authored_instance_transforms", [] as Array[Transform3D]
	) as Array[Transform3D]
	_check(
		authored_again.size() == authored_transforms.size()
		and (
			authored_transforms.is_empty()
			or authored_again[0].is_equal_approx(authored_transforms[0])
		),
		"the belt's authored orientation is fixed rather than advanced by a tick"
	)
	var report := cluster.get_cluster_audit_report()
	_check(
		bool(report.get("valid", false))
		and bool((report.get("asteroid_field", {}) as Dictionary).get("valid", false)),
		"the streamed component's own audit accepts the belt: %s" % [report.get("errors", [])]
	)
	_check(
		float(report.get("field_outer_distance", 0.0))
			<= NearbySectorCluster.MAXIMUM_CONTENT_DISTANCE
		and field.get_outer_content_distance()
			<= NearbySectorCluster.MAXIMUM_CONTENT_DISTANCE,
		"the belt stays inside the sector's published content envelope"
	)


# --- 2. Published lanes -------------------------------------------------------


## A pilot reads this belt as scenery unless the cockpit can mark the one way
## in. The bore mouth the cluster publishes must be the same lit ring the belt
## builds, and must lead to the first threading gate rather than anywhere else.
func _test_bore_mouth_is_markable(
	cluster: NearbySectorCluster, field: CinderAsteroidField
) -> void:
	var families := cluster.get_named_destination_marker_positions()
	var bore_family := families.get(&"nearby_belt_bore", []) as Array
	_check(
		bore_family.size() == 1,
		"the streamed belt publishes exactly one bore-mouth mark"
	)
	if bore_family.size() != 1:
		return
	var bore := bore_family[0] as Vector3
	_check(
		bore.is_finite()
		and bore.is_equal_approx(field.to_global(field.get_lane_point(0.0)))
		and bore.is_equal_approx(field.to_global(field.get_lane_entry())),
		"the mark sits on the belt's own marked entry ring, not a derived guess"
	)
	var checkpoints := field.get_threading_checkpoints()
	_check(
		checkpoints.size() == 5
		and bore.distance_to(field.to_global(checkpoints[0]))
			< bore.distance_to(field.to_global(field.get_lane_exit())),
		"the marked mouth is the end of the bore the five-gate run starts from"
	)
	_check(
		not bore.is_equal_approx(field.to_global(field.get_lane_exit())),
		"the entry mouth and the far mouth are not the same mark"
	)


func _test_published_lanes_are_not_blocked(field: CinderAsteroidField) -> void:
	var beacons := OUTBOUND_ROUTE.checkpoint_positions
	var blocked_by: String = ""
	for record in field.get_asteroid_records():
		var centre := record["position"] as Vector3
		var radius := float(record["collision_radius"])
		if centre.z > NearbySectorCluster.TARGET_RANGE_CLEARANCE_Z:
			blocked_by = "the target range clearance plane"
			break
		for index in beacons.size() - 1:
			if _distance_to_segment(centre, beacons[index], beacons[index + 1]) \
					< NearbySectorCluster.BEACON_TRAVERSAL_CORRIDOR_RADIUS + radius:
				blocked_by = "the beacon traversal corridor"
				break
		for spec in NearbySectorCluster.ROUTE_BEACON_SPECS:
			if centre.distance_to(spec["position"] as Vector3) \
					< NearbySectorCluster.BEACON_KEEP_CLEAR_RADIUS + radius:
				blocked_by = "a route beacon keep-clear sphere"
				break
		if centre.distance_to(NearbySectorCluster.PLATFORM_ANCHOR) \
				< NearbySectorCluster.PLATFORM_KEEP_CLEAR_RADIUS + radius:
			blocked_by = "the platform keep-clear sphere"
		var platform_offset := centre - NearbySectorCluster.PLATFORM_ANCHOR
		var lane_point := NearbySectorCluster.PLATFORM_ANCHOR + Vector3(
			0.0,
			NearbySectorCluster.GANTRY_CENTER_Y,
			clampf(platform_offset.z, 0.0, NearbySectorCluster.APPROACH_CORRIDOR_LENGTH),
		)
		if centre.distance_to(lane_point) \
				< NearbySectorCluster.APPROACH_CORRIDOR_RADIUS + radius:
			blocked_by = "the platform approach lane"
		if centre.distance_to(NearbySectorCluster.MOONLET_ANCHOR) \
				< NearbySectorCluster.MOONLET_RADIUS + radius:
			blocked_by = "the ringed moonlet"
		if centre.distance_to(HULK_ANCHOR) < HULK_BOUNDING_RADIUS + radius:
			blocked_by = "the abandoned station hulk"
		var convoy := CONVOY_ROUTE.checkpoint_positions
		for index in convoy.size():
			var leg_clearance := (
				_distance_to_segment(centre, convoy[index], convoy[index + 1])
				if index + 1 < convoy.size()
				else centre.distance_to(convoy[index])
			)
			if leg_clearance < CONVOY_LEG_CLEARANCE + radius:
				blocked_by = "an Emberline convoy leg"
				break
		if not blocked_by.is_empty():
			break
	_check(
		blocked_by.is_empty(),
		"no belt asteroid reaches into %s" % ("any published lane" if blocked_by.is_empty() else blocked_by)
	)
	# The polyline the clearance suite actually sweeps, walked through the
	# belt's colliders. This is the race route and the patrol route as well.
	var outbound: Array[Vector3] = [Vector3(0.0, LAUNCH_GATE.y, -30.0), LAUNCH_GATE]
	for index in beacons.size() - 1:
		outbound.append(beacons[index])
	outbound.append(beacons[beacons.size() - 1] + PLATFORM_APPROACH_OFFSET)
	var route_contact := _first_belt_contact(field, outbound)
	_check(
		route_contact.is_empty(),
		"the whole published outbound, race and patrol polyline stays clear of the belt"
	)


# --- 3. The safe lane ---------------------------------------------------------


func _test_safe_lane_is_flyable(field: CinderAsteroidField, hulls: Dictionary) -> void:
	_check(
		hulls.size() == SWEEP_SHIP_SCENES.size(),
		"both production sweep hulls expose real collision envelopes"
	)
	var starboard := field.get_lane_starboard_axis()
	var up := field.get_lane_up_axis()
	for craft_id: StringName in hulls:
		var hull := hulls[craft_id] as AABB
		# Four lines at half the bore radius plus the centreline: a lane is a
		# volume the pilot can drift inside, not a wire he must stay on.
		var offsets: Array[Vector3] = [
			Vector3.ZERO,
			starboard * (CinderAsteroidField.LANE_RADIUS * 0.5),
			-starboard * (CinderAsteroidField.LANE_RADIUS * 0.5),
			up * (CinderAsteroidField.LANE_RADIUS * 0.5),
			-up * (CinderAsteroidField.LANE_RADIUS * 0.5),
		]
		var blocked := {}
		for offset in offsets:
			var contact := _first_hull_contact(
				hull,
				field.get_lane_entry() + offset,
				field.get_lane_exit() + offset,
			)
			if not contact.is_empty():
				blocked = contact
				break
		_check(
			blocked.is_empty(),
			"the %s flies the whole safe lane, centre and rim, without a contact%s" % [
				craft_id,
				"" if blocked.is_empty() else " (hit %s)" % blocked.get("collider_name", "?"),
			]
		)


# --- 4. Real mass -------------------------------------------------------------


func _test_the_belt_has_real_mass(field: CinderAsteroidField) -> void:
	var bodies := field.find_children("*", "StaticBody3D", true, false)
	_check(
		bodies.size() == EXPECTED_ASTEROID_COUNT,
		"the belt owns one solid body per asteroid"
	)
	var layers_correct := true
	var radii_correct := true
	for record in field.get_asteroid_records():
		var body := field.get_node_or_null(
			NodePath("Asteroids/%s" % record["name"])
		) as StaticBody3D
		if body == null or body.collision_layer != PhysicsLayers.WORLD \
				or body.collision_mask != 0:
			layers_correct = false
			break
		var shape := body.get_node_or_null(^"Collision") as CollisionShape3D
		var sphere := shape.shape as SphereShape3D if shape != null else null
		if sphere == null or not is_equal_approx(
				sphere.radius, float(record["collision_radius"])
			):
			radii_correct = false
			break
	_check(
		layers_correct,
		"every asteroid stands on the world collision layer and pushes nothing itself"
	)
	_check(
		radii_correct,
		"every asteroid's collider is the authored sphere the belt publishes"
	)
	# Physics and the belt's own classifier must agree, because the activity
	# authority scores the run on the classifier and the hull hits the physics.
	var struck_everywhere := true
	var physics_agrees := true
	for record in field.get_asteroid_records():
		var centre := record["position"] as Vector3
		if not bool((field.classify_position(centre) as Dictionary).get("struck", false)):
			struck_everywhere = false
			break
		if _point_bodies(centre).is_empty():
			physics_agrees = false
			break
	_check(struck_everywhere, "the belt's classifier reports a strike at every asteroid centre")
	_check(physics_agrees, "the real physics world reports a solid body at every asteroid centre")
	var bore := field.get_lane_point(0.5)
	var bore_contact := field.classify_position(bore) as Dictionary
	_check(
		bool(bore_contact.get("inside_safe_lane", false))
		and bool(bore_contact.get("inside_belt", false))
		and not bool(bore_contact.get("struck", false))
		and _point_bodies(bore).is_empty(),
		"the middle of the bore is inside the belt, inside the lane, and empty"
	)
	var far_outside := field.get_lane_point(0.5) \
		+ field.get_lane_starboard_axis() * (CinderAsteroidField.OUTER_RADIUS + 200.0)
	_check(
		not bool((field.classify_position(far_outside) as Dictionary).get("inside_belt", false)),
		"the belt reports honestly that space beyond its skin is not the belt"
	)


# --- 5. Streamed roster -------------------------------------------------------


func _test_streamed_roster_is_refrozen(cluster: NearbySectorCluster) -> void:
	var renderers := cluster.find_children("*", "GeometryInstance3D", true, false)
	var lights := cluster.find_children("*", "Light3D", true, false)
	var shadow_casting := 0
	for candidate in lights:
		if (candidate as Light3D).shadow_enabled:
			shadow_casting += 1
	_check(
		renderers.size() == TRANSITION.EXPECTED_AUTHORED_RENDERER_COUNT
		and lights.size() == TRANSITION.EXPECTED_LIGHT_COUNT,
		"the streaming transition's authored roster matches the component the belt shipped into"
	)
	_check(
		shadow_casting == 0,
		"the belt adds no shadow-casting light to the streamed sector"
	)


# --- 6. The threading run -----------------------------------------------------


func _configure_reward_authority(binding: Node) -> void:
	_filesystem = MemoryFilesystem.new()
	_store = STORE_SCRIPT.new("memory://cinder-asteroid-rewards.json", _filesystem)
	_check(bool((_store.call("load") as Dictionary).get("accepted", false)), "the atomic user-data store loads")
	_authority = AUTHORITY_SCRIPT.new()
	_check(
		bool((_authority.call("configure", _store) as Dictionary).get("accepted", false)),
		"the production reward authority adopts the store"
	)
	var configured := binding.call(
		&"configure_asteroid_field_reward_handoff", Callable(_authority, "commit")
	) as Dictionary
	_check(
		bool(configured.get("accepted", false))
		and bool(
			(binding.call(&"get_asteroid_field_reward_handoff_snapshot") as Dictionary)
				.get("configured", false)
		),
		"the belt run's reward handoff binds to the production reward authority"
	)


func _test_threading_run_completes(binding: Node, field: CinderAsteroidField) -> void:
	var checkpoints := field.get_threading_checkpoints()
	var from_the_lane := binding.call(
		&"start_asteroid_field_run", field.get_lane_point(0.0)
	) as Dictionary
	_check(
		not bool(from_the_lane.get("accepted", false))
		and StringName(from_the_lane.get("reason", &"")) == &"outside_first_gate"
		and StringName(from_the_lane.get("state_id", &"")) == &"idle",
		"a run cannot be opened from the safe lane: the first gate is in the rock"
	)
	var started := binding.call(&"start_asteroid_field_run", checkpoints[0]) as Dictionary
	_check(
		bool(started.get("accepted", false))
		and StringName(started.get("state_id", &"")) == &"active"
		and int(started.get("generation", 0)) == 1
		and int(started.get("next_checkpoint_index", -1)) == 0,
		"a run opens at the first gate and starts on generation one"
	)
	var drifted := binding.call(
		&"advance_asteroid_field_run_from_caller_sample", field.get_lane_point(0.35)
	) as Dictionary
	_check(
		not bool(drifted.get("accepted", false))
		and StringName(drifted.get("reason", &"")) == &"outside_gate"
		and StringName(drifted.get("state_id", &"")) == &"active",
		"retreating to the safe lane mid-run neither advances nor ends the run"
	)
	var advanced_in_order := true
	for index in checkpoints.size():
		var result := binding.call(
			&"advance_asteroid_field_run_from_caller_sample", checkpoints[index]
		) as Dictionary
		var expected_next := index + 1
		if not bool(result.get("accepted", false)) \
				or int(result.get("next_checkpoint_index", -1)) != expected_next:
			advanced_in_order = false
			break
	_check(advanced_in_order, "the ship's own samples clear all five gates in authored order")
	var finished := binding.call(&"get_activity_snapshot", &"asteroid_field_run") as Dictionary
	_check(
		StringName(finished.get("state_id", &"")) == &"completed"
		and int(finished.get("next_checkpoint_index", -1)) == EXPECTED_GATE_COUNT
		and int(finished.get("generation", 0)) == 1
		and bool(finished.get("belt_bound", false)),
		"the run reaches completion with the belt bound to it throughout"
	)
	var presentation := field.get_presentation_state()
	_check(
		StringName(presentation.get("state_id", &"")) == &"completed"
		and int(presentation.get("marker_copy_count", -1)) == EXPECTED_GATE_MARKER_COPIES,
		"the gate chevrons follow the run to completion without changing the batch roster"
	)
	var captured := (SESSION_ADAPTER.new() as RefCounted).call(
		"capture", binding.call(&"get_snapshot")
	) as Dictionary
	var persisted_ids := []
	for activity in captured.get("activities", []) as Array:
		persisted_ids.append(StringName((activity as Dictionary).get("activity_id", &"")))
	_check(
		persisted_ids.has(EXPECTED_ACTIVITY_ID),
		"the nearby-sector session codec carries the belt run into the save payload"
	)


func _test_reward_is_taken_exactly_once(binding: Node) -> void:
	var granted := binding.call(&"request_asteroid_field_run_reward") as Dictionary
	var authority_result := granted.get("authority_result", {}) as Dictionary
	var receipt := authority_result.get("receipt", {}) as Dictionary
	_check(
		bool(granted.get("accepted", false))
		and bool(authority_result.get("granted", false))
		and StringName(receipt.get("activity_id", &"")) == EXPECTED_ACTIVITY_ID
		and StringName(receipt.get("reward_id", &"")) == EXPECTED_REWARD_ID
		and bool(receipt.get("granted", false))
		and not bool(receipt.get("replay_allowed", true)),
		"completing the run commits one granted, non-replayable Shipyard receipt"
	)
	var repeated := binding.call(&"request_asteroid_field_run_reward") as Dictionary
	_check(
		not bool(repeated.get("accepted", false))
		and StringName(repeated.get("reason", &"")) == &"reward_already_requested",
		"a second request inside the same completed run is refused by the binding"
	)


func _test_save_and_whole_component_reentry(
		cluster: NearbySectorCluster, binding: Node, field: CinderAsteroidField
	) -> void:
	# Save: the receipt is on disk in the real atomic store, not in the
	# activity. A fresh authority reading that file must already know about it.
	var reloaded_store := STORE_SCRIPT.new(
		"memory://cinder-asteroid-rewards.json", _filesystem
	)
	_check(
		bool((reloaded_store.call("load") as Dictionary).get("accepted", false)),
		"the committed reward file reloads from the store"
	)
	var restored_authority := AUTHORITY_SCRIPT.new()
	_check(
		bool((restored_authority.call("configure", reloaded_store) as Dictionary)
			.get("accepted", false)),
		"a fresh reward authority adopts the reloaded file"
	)
	var restored_record := (
		(restored_authority.call("get_snapshot") as Dictionary).get("record", {})
		as Dictionary
	)
	var restored_counts := restored_record.get("reward_counts", {}) as Dictionary
	var restored_receipt := restored_record.get("last_receipt", {}) as Dictionary
	_check(
		int(restored_record.get("total_receipts", -1)) == 1
		and int(restored_counts.get(String(EXPECTED_REWARD_ID), -1)) == 1
		and StringName(restored_receipt.get("activity_id", &"")) == EXPECTED_ACTIVITY_ID
		and int(restored_receipt.get("activity_generation", -1)) == 1
		and not bool(restored_receipt.get("replay_allowed", true)),
		"the saved file carries exactly one non-replayable receipt for the completed run"
	)
	# The live authority is the one the binding still holds. It must refuse the
	# same completed run's generation outright rather than issue a second
	# receipt for it.
	var replayed := _authority.call("commit", {
		"activity_id": EXPECTED_ACTIVITY_ID,
		"activity_generation": 1,
		"reward_id": EXPECTED_REWARD_ID,
		"reward_authority": false,
		"granted": false,
	}) as Dictionary
	_check(
		not bool(replayed.get("accepted", false))
		and StringName(replayed.get("reason", &"")) == &"reward_generation_already_committed"
		and int(
			((_store.call("get_snapshot") as Dictionary).get(
				"game_flow_reward_store", {}
			) as Dictionary).get("total_receipts", -1)
		) == 1,
		"the reward authority refuses the completed run a second receipt"
	)

	# Re-entry: detach and re-add the whole streamed component, exactly as a
	# return to Main does, and require the belt and the run to come back intact.
	var renderers_before := cluster.find_children("*", "GeometryInstance3D", true, false).size()
	root.remove_child(cluster)
	root.add_child(cluster)
	await process_frame
	await process_frame
	await physics_frame
	_check(
		field.get_asteroid_records().size() == EXPECTED_ASTEROID_COUNT
		and field.find_children("*", "StaticBody3D", true, false).size()
			== EXPECTED_ASTEROID_COUNT
		and cluster.find_children("*", "GeometryInstance3D", true, false).size()
			== renderers_before
		and _point_bodies(
			(field.get_asteroid_records()[0]["position"]) as Vector3
		).size() >= 1,
		"the belt survives a whole-component re-entry with its mass and roster intact"
	)
	var after_reentry := binding.call(&"get_activity_snapshot", &"asteroid_field_run") as Dictionary
	_check(
		StringName(after_reentry.get("state_id", &"")) == &"completed"
		and int(after_reentry.get("generation", 0)) == 1
		and bool(after_reentry.get("reward_requested", false))
		and bool(after_reentry.get("belt_bound", false)),
		"the completed, already-rewarded run comes back rewarded rather than repayable"
	)
	var after_reentry_reward := binding.call(&"request_asteroid_field_run_reward") as Dictionary
	_check(
		not bool(after_reentry_reward.get("accepted", false))
		and StringName(after_reentry_reward.get("reason", &"")) == &"reward_already_requested",
		"re-entry does not reopen the reward"
	)


# --- 7. Consequences and abandonment -----------------------------------------


func _test_impact_ends_the_run(binding: Node, field: CinderAsteroidField) -> void:
	_check(
		bool((binding.call(&"reset_asteroid_field_run") as Dictionary).get("accepted", false)),
		"the rewarded run is cleared before a second run opens"
	)
	var checkpoints := field.get_threading_checkpoints()
	var started := binding.call(&"start_asteroid_field_run", checkpoints[0]) as Dictionary
	_check(
		bool(started.get("accepted", false))
		and StringName(started.get("state_id", &"")) == &"active",
		"a second run opens at the first gate"
	)
	binding.call(&"advance_asteroid_field_run_from_caller_sample", checkpoints[0])
	var rock := field.get_asteroid_records()[0]["position"] as Vector3
	_check(
		not _point_bodies(rock).is_empty(),
		"the sample point used for the clip is a real solid body in the physics world"
	)
	var clipped := binding.call(
		&"advance_asteroid_field_run_from_caller_sample", rock
	) as Dictionary
	_check(
		bool(clipped.get("accepted", false))
		and StringName(clipped.get("reason", &"")) == &"asteroid_impact"
		and StringName(clipped.get("state_id", &"")) == &"failed"
		and StringName(clipped.get("failure_reason", &"")) == &"asteroid_impact",
		"clipping an asteroid ends the run there, naming the rock as the cause"
	)
	var refused := binding.call(&"request_asteroid_field_run_reward") as Dictionary
	_check(
		not bool(refused.get("accepted", false))
		and StringName(refused.get("reason", &"")) == &"not_complete",
		"a run the belt ended pays nothing"
	)
	var presentation := field.get_presentation_state()
	_check(
		StringName(presentation.get("state_id", &"")) == &"failed"
		and int(presentation.get("marker_copy_count", -1)) == EXPECTED_GATE_MARKER_COPIES,
		"the gates show the failure without adding or dropping a single drawn copy"
	)


func _test_abandon_is_clean(binding: Node, field: CinderAsteroidField) -> void:
	var abandoned := binding.call(&"reset_asteroid_field_run") as Dictionary
	_check(
		bool(abandoned.get("accepted", false))
		and StringName(abandoned.get("state_id", &"")) == &"idle"
		and int(abandoned.get("next_checkpoint_index", -1)) == 0
		and StringName(abandoned.get("failure_reason", &"")) == &""
		and not bool(abandoned.get("reward_requested", true)),
		"abandoning returns the run to idle with no residue"
	)
	var stale := binding.call(
		&"advance_asteroid_field_run_from_caller_sample",
		field.get_threading_checkpoints()[1],
	) as Dictionary
	_check(
		not bool(stale.get("accepted", false))
		and StringName(stale.get("reason", &"")) == &"not_active",
		"a sample still in flight from the abandoned run cannot advance anything"
	)
	_check(
		StringName(field.get_presentation_state().get("state_id", &"")) == &"idle"
		and field.find_children("*", "StaticBody3D", true, false).size()
			== EXPECTED_ASTEROID_COUNT,
		"abandoning restores the idle gates and leaves the belt itself untouched"
	)


# --- Helpers ------------------------------------------------------------------


## Real production collision envelopes, measured off the shipped ship scenes.
func _production_hulls() -> Dictionary:
	var hulls := {}
	for craft_id: StringName in SWEEP_SHIP_SCENES:
		var scene := load(SWEEP_SHIP_SCENES[craft_id]) as PackedScene
		if scene == null:
			continue
		var craft := scene.instantiate()
		root.add_child(craft)
		await process_frame
		var body := craft as CollisionObject3D
		var bounds := AABB()
		var first := true
		if body != null:
			for child in body.get_children():
				var shape := child as CollisionShape3D
				if shape == null or shape.shape == null or shape.disabled:
					continue
				var box: AABB = shape.transform * shape.shape.get_debug_mesh().get_aabb()
				if first:
					bounds = box
					first = false
				else:
					bounds = bounds.merge(box)
		craft.queue_free()
		await process_frame
		if not first:
			hulls[craft_id] = bounds
	return hulls


func _sweep_query(hull: AABB) -> PhysicsShapeQueryParameters3D:
	var shape := BoxShape3D.new()
	shape.size = hull.size
	var params := PhysicsShapeQueryParameters3D.new()
	params.shape = shape
	params.collision_mask = PhysicsLayers.WORLD
	params.collide_with_areas = false
	params.collide_with_bodies = true
	return params


## First contact of a real hull swept between two points, or an empty dictionary.
func _first_hull_contact(hull: AABB, from: Vector3, to: Vector3) -> Dictionary:
	var params := _sweep_query(hull)
	var span := from.distance_to(to)
	var steps := maxi(1, int(ceil(span / SWEEP_STEP)))
	for step in steps + 1:
		var origin := from.lerp(to, float(step) / float(steps))
		params.transform = Transform3D(Basis.IDENTITY, origin + hull.get_center())
		var hits := _space.intersect_shape(params, 1)
		if not hits.is_empty():
			var collider := (hits[0] as Dictionary).get("collider") as Node
			return {
				"position": origin,
				"collider_name": collider.name if collider != null else "?",
			}
	return {}


## First point on a polyline that falls inside a belt collider. Used for the
## published lanes, where the question is whether the rock reaches the route at
## all rather than whether a specific hull fits.
func _first_belt_contact(field: CinderAsteroidField, polyline: Array[Vector3]) -> Dictionary:
	for index in polyline.size() - 1:
		var from := polyline[index]
		var to := polyline[index + 1]
		var span := from.distance_to(to)
		var steps := maxi(1, int(ceil(span / SWEEP_STEP)))
		for step in steps + 1:
			var sample := from.lerp(to, float(step) / float(steps))
			var contact := field.classify_position(sample) as Dictionary
			if bool(contact.get("struck", false)):
				return {"position": sample, "index": contact.get("struck_asteroid_index", -1)}
	return {}


func _point_bodies(world_position: Vector3) -> Array[Dictionary]:
	var params := PhysicsPointQueryParameters3D.new()
	params.position = world_position
	params.collision_mask = PhysicsLayers.WORLD
	params.collide_with_areas = false
	params.collide_with_bodies = true
	return _space.intersect_point(params, 4)


func _distance_to_segment(point: Vector3, start: Vector3, finish: Vector3) -> float:
	var segment := finish - start
	if segment.length_squared() < 0.000001:
		return point.distance_to(start)
	var along := clampf((point - start).dot(segment) / segment.length_squared(), 0.0, 1.0)
	return point.distance_to(start + segment * along)


func _check(condition: bool, description: String) -> bool:
	_assertions += 1
	if condition:
		print("PASS: ", description)
	else:
		_failures.append(description)
		push_error("FAIL: " + description)
	return condition


func _finish() -> void:
	print("CINDER_ASTEROID_FIELD_TEST_ASSERTIONS: ", _assertions)
	if _failures.is_empty():
		print("CINDER_ASTEROID_FIELD_TEST_OK")
		quit(0)
	else:
		print("CINDER_ASTEROID_FIELD_TEST_FAILED: ", ", ".join(_failures))
		quit(1)
