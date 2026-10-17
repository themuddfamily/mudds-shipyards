extends SceneTree

## Production Main hulk regression with staged outbound/dock/return poses.
## After one dock-shelf Player placement, ordinary held forward input walks
## every authored interior waypoint on real collision to the breaker. Flight
## and disembarkation are staging, not continuous-flight coverage. Separate
## fringe/rebase and reward/persistence checks follow the continuous walk.
## The persistence store uses an isolated filesystem, never a user save.

const MAIN_SCENE := preload("res://scenes/main.tscn")
const CLUSTER_SCENE := preload("res://scenes/world/components/nearby_sector_cluster.tscn")
const Store := preload("res://scripts/persistence/user_data_store.gd")
const HULK := preload("res://scripts/world/abandoned_station_hulk.gd")
const POWER_ACTIVITY := preload(
	"res://scripts/activities/derelict_power_restoration_activity.gd"
)
const STORE_PATH := "memory://abandoned-hulk-loop-settings.json"
const LEGACY_PATH := "memory://abandoned-hulk-loop-legacy.cfg"
const PHYSICS_DELTA := 1.0 / 60.0

## The authored contract, frozen here rather than read back off the component.
## Reading the class's own constants to check the class would move the rule and
## the ruler together; these numbers are what a deliberate design change has to
## come and edit.
const EXPECTED_HULK_ANCHOR := Vector3(-120.0, 26.0, -470.0)
const EXPECTED_BERTH_ID: StringName = &"cinder_hulk_dock"
const EXPECTED_ACTIVITY_ID: StringName = &"cinder_hulk_power_restoration"
const EXPECTED_REWARD_ID: StringName = &"hulk_auxiliary_power_cell"
const EXPECTED_INTERIOR_SPACES := 3
const EXPECTED_LIGHT_BUDGET := 8
const EXPECTED_STATIC_BODIES := 18
# 39 structural/fitting meshes plus the merged silhouette-detail renderer
# added by the Cinder Reach art pass (fcd9389bc).
const EXPECTED_MESH_INSTANCES := 40
const EXPECTED_BREAKER_ANCHOR := Vector3(-146.0, 23.8, -467.0)
## Nothing the hulk builds may crowd the station or leave the sector envelope.
const STATION_EXCLUSION_RADIUS := 200.0
const CONTENT_ENVELOPE := 940.0
## The streaming policy loads at or inside 500 m of the Cinder anchor and
## unloads only beyond 650 m.
const STREAM_LOAD_SAMPLE := 480.0
const STREAM_UNLOAD_SAMPLE := 700.0

const WALK_TARGET_TOLERANCE := 0.6
const WALK_STOP_DISTANCE := 0.22
const SUITE_WALL_BUDGET_MSEC := 300000

var _suite_started_msec := Time.get_ticks_msec()
var _assertions := 0
var _failures: Array[String] = []


class MemoryFilesystem extends UserDataFilesystem:
	var files: Dictionary = {}

	func file_exists(path: String) -> bool:
		return files.has(path)

	func directory_exists(_path: String) -> bool:
		return false

	func ensure_parent_directory(_path: String) -> Error:
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
		if files.has(to_path):
			return ERR_ALREADY_EXISTS
		files[to_path] = (files[from_path] as PackedByteArray).duplicate()
		files.erase(from_path)
		return OK


class RewardFaultFilesystem extends UserDataFilesystem:
	var reject_rewards := true
	var rejected_rewards := 0
	var reject_terminals := true

	func write_bytes_and_flush(path: String, bytes: PackedByteArray) -> Error:
		var document: Variant = JSON.parse_string(bytes.get_string_from_utf8())
		if reject_terminals and document is Dictionary and str(document.get("commit", {}).get("id", "")).begins_with("game-flow-hulk-"):
			return ERR_UNAVAILABLE
		if reject_rewards and document is Dictionary and str(document.get("commit", {}).get("id", "")).begins_with("game-flow-reward-"):
			rejected_rewards += 1
			return ERR_UNAVAILABLE
		return super.write_bytes_and_flush(path, bytes)


func _init() -> void:
	call_deferred(&"_run")


func _run() -> void:
	_test_frozen_contract()
	_test_component_shape_and_budget()
	await _test_unpaid_recovery()
	await _test_production_loop()
	_finish()


## The authored placement and cost of the destination, measured against the
## frozen numbers above rather than against the component's own constants.
func _test_frozen_contract() -> void:
	_check(
		HULK.HULK_ANCHOR.is_equal_approx(EXPECTED_HULK_ANCHOR),
		"the hulk sits at its published anchor"
	)
	var distance := (HULK.HULK_ANCHOR as Vector3).length()
	_check(
		distance > STATION_EXCLUSION_RADIUS
		and distance + float(HULK.HULL_BOUNDING_RADIUS) < CONTENT_ENVELOPE,
		"the hulk is %.0f m out: clear of the corridor, inside the sector envelope"
		% distance
	)
	_check(
		HULK.BERTH_ID == EXPECTED_BERTH_ID
		and (HULK.SPACE_IDS as Array).size() == EXPECTED_INTERIOR_SPACES
		and int(HULK.LIGHT_BUDGET) == EXPECTED_LIGHT_BUDGET,
		"the destination publishes one berth, three interior spaces and eight practicals"
	)
	_check(
		POWER_ACTIVITY.ACTIVITY_ID == EXPECTED_ACTIVITY_ID
		and POWER_ACTIVITY.REWARD_ID == EXPECTED_REWARD_ID
		and not bool(POWER_ACTIVITY.REPEATABLE)
		and (POWER_ACTIVITY.BREAKER_ANCHOR as Vector3).is_equal_approx(
			EXPECTED_BREAKER_ANCHOR
		),
		"the one activity inside is an explicitly one-shot salvage at the authored panel"
	)
	_check(
		GameFlowRewardAuthority.ACTIVITY_REWARDS.get(EXPECTED_ACTIVITY_ID, &"")
			== EXPECTED_REWARD_ID
		and GameFlowRewardAuthority.REWARD_LABELS.has(EXPECTED_REWARD_ID),
		"the existing reward authority owns the hulk reward instead of a second ledger"
	)


## The destination's shape, collision and cost, measured on the real component
## scene. The sector streams, so this is exactly what one loaded generation
## gains and the resident station gains nothing at all.
func _test_component_shape_and_budget() -> void:
	var cluster := CLUSTER_SCENE.instantiate() as NearbySectorCluster
	root.add_child(cluster)
	var hulk := cluster.get_station_hulk()
	_check(
		hulk != null and hulk.is_built(),
		"the streamed sector scene carries one built station hulk"
	)
	if hulk == null:
		cluster.queue_free()
		return

	var audit := hulk.get_audit_report()
	_check(
		bool(audit.get("valid", false))
		and not bool(audit.get("grants_rewards", true))
		and not bool(audit.get("berth_lease_authority", true))
		and not bool(audit.get("landing_authority", true)),
		"the hulk audits clean and claims no reward, lease or landing authority"
	)

	var counts := hulk.count_live_nodes()
	_check(
		int(counts.get("static_bodies", -1)) == EXPECTED_STATIC_BODIES
		and int(counts.get("mesh_instances", -1)) == EXPECTED_MESH_INSTANCES
		and int(counts.get("omni_lights", -1)) == EXPECTED_LIGHT_BUDGET
		and int(counts.get("ship_berths", -1)) == 1,
		"the destination costs %d solid bodies, %d meshes and %d practicals"
		% [EXPECTED_STATIC_BODIES, EXPECTED_MESH_INSTANCES, EXPECTED_LIGHT_BUDGET]
	)
	_check(
		int(counts.get("shadow_casting_lights", -1)) == 0
		and int(counts.get("particle_emitters", -1)) == 0
		and int(counts.get("animation_players", -1)) == 0
		and int(counts.get("audio_nodes", -1)) == 0,
		"powered-down means shadowless practicals and no particle, animation or audio load"
	)
	var dim_practicals := 0
	for light in hulk.get_light_nodes():
		if light.light_energy <= 1.0 and not light.shadow_enabled \
				and light.distance_fade_enabled:
			dim_practicals += 1
	_check(
		dim_practicals == EXPECTED_LIGHT_BUDGET,
		"every interior light is a dim, shadowless, distance-faded emergency practical"
	)

	# Real collision, not a visual shell: the deck, the hull plates, the two
	# bulkheads and the fittings must all carry a shape on the World layer.
	var world_bodies := 0
	var shaped_bodies := 0
	for candidate in hulk.find_children("*", "StaticBody3D", true, false):
		var body := candidate as StaticBody3D
		if body.collision_layer != PhysicsLayers.WORLD:
			continue
		world_bodies += 1
		var shape := body.get_node_or_null(^"Collision") as CollisionShape3D
		if shape != null and shape.shape != null:
			shaped_bodies += 1
	_check(
		world_bodies == EXPECTED_STATIC_BODIES and shaped_bodies == world_bodies,
		"every solid piece of the hulk is on the World layer with a real shape"
	)

	# The intact port rib run has the station's shallow formed edge. It retains
	# one renderer per rib and the exact authored envelope on each shared mesh.
	var rib_nodes := hulk.get_node(^"Exterior/HullRibTrim").get_children()
	var rib_size := Vector3(1.4, 13.6, 1.0)
	var rib_mesh: Mesh = null
	var rib_geometry_valid := rib_nodes.size() == 6
	for rib_node in rib_nodes:
		var rib := rib_node as MeshInstance3D
		if rib == null or rib.mesh == null:
			rib_geometry_valid = false
			continue
		if rib_mesh == null:
			rib_mesh = rib.mesh
		rib_geometry_valid = rib_geometry_valid \
			and rib.mesh == rib_mesh \
			and rib.mesh.get_surface_count() == 1 \
			and rib.mesh.get_faces().size() == 44 * 3 \
			and rib.mesh.get_aabb().is_equal_approx(AABB(-rib_size * 0.5, rib_size))
	_check(rib_geometry_valid, "six intact port ribs share one shallow 44-triangle formed mesh at their authored extents")

	var nearest := INF
	var furthest := 0.0
	for candidate in hulk.find_children("*", "Node3D", true, false):
		var node := candidate as Node3D
		if not (node is StaticBody3D or node is MeshInstance3D or node is Light3D):
			continue
		var node_distance := node.global_position.length()
		nearest = minf(nearest, node_distance)
		furthest = maxf(furthest, node_distance)
	_check(
		nearest >= STATION_EXCLUSION_RADIUS and furthest <= CONTENT_ENVELOPE,
		"no hulk body crowds the station (%.0f m) or leaves the envelope (%.0f m)"
		% [nearest, furthest]
	)

	var berth := hulk.get_dock_berth()
	_check(
		berth != null
		and berth.get_berth_id() == EXPECTED_BERTH_ID
		and berth.get_validation_errors().is_empty()
		and not berth.is_reserved()
		and not berth.is_occupied(),
		"the docking face is one valid, unleased ShipBerth"
	)

	# The route the pilot actually walks: dock shelf, aperture, then the three
	# spaces in order, ending at the breaker. Consecutive points must be close
	# enough to be one continuous walk and the whole run must stay on one deck.
	var route := hulk.get_interior_route_points()
	var contiguous := route.size() >= EXPECTED_INTERIOR_SPACES + 2
	var deck_level := true
	for index in range(1, route.size()):
		if route[index].distance_to(route[index - 1]) > 30.0:
			contiguous = false
		if absf(route[index].y - route[0].y) > 1.5:
			deck_level = false
	_check(
		contiguous and deck_level,
		"the interior route is one contiguous, level walk through every space"
	)

	cluster.queue_free()
	await process_frame


## Stage the outbound/dock poses, walk continuously, then check the separate
## activity, persistence and staged return/unload scenarios.
func _test_production_loop() -> void:
	var game := MAIN_SCENE.instantiate() as GameFlow
	_check(game != null, "production Main instantiates for the hulk loop")
	if game == null:
		return
	var filesystem := MemoryFilesystem.new()
	var store := Store.new(STORE_PATH, filesystem) as UserDataStore
	_check(
		game.configure_runtime_settings_persistence(store, LEGACY_PATH),
		"the loop injects an isolated atomic store before Main startup"
	)
	root.add_child(game)
	await process_frame
	await physics_frame
	await process_frame

	var world := game.get_node_or_null(^"ShipyardWorld") as ShipyardWorld
	var bootstrap := game.get_node_or_null(
		^"CinderStreamingBootstrap"
	) as CinderStreamingBootstrap
	var binding := game.get_node_or_null(
		^"CinderStreamingProductionBinding"
	) as CinderStreamingProductionBinding
	var player := game.get_node_or_null(^"Player") as PlayerController
	var ship := game.get_guided_ship()
	var hud := game.hud as GameHUD
	_check(
		world != null and bootstrap != null and binding != null
		and player != null and ship != null,
		"Main exposes the station, the streaming composition, the pilot and the craft"
	)
	if world == null or bootstrap == null or binding == null \
			or player == null or ship == null:
		await _cleanup(game)
		return

	_check(
		world.get_nearby_sector_cluster() == null
		and game.get_station_hulk_berth() == null,
		"the station starts with no hulk and no streamed berth at all"
	)
	var hulk_board_row := _hulk_board_row(hud)
	_check(hulk_board_row != null and hulk_board_row.get_child_count() == 2
		and "FLY TOWARD CINDER REACH" in (hulk_board_row.get_child(0) as Label).text
		and (hulk_board_row.get_child(1) as Button).disabled
		and int(_reward_counts(game).get(String(EXPECTED_REWARD_ID), 0)) == 0,
		"the Activity Board discovers unloaded salvage without a reward action")

	# Use the same public INTRO exit as BEGIN SHIFT; startup deliberately
	# disables Player control. A manual control toggle would leave menu state.
	game.start_shift()
	await process_frame
	if not _check(not paused and player.can_process()
			and player.is_control_enabled() and not player.is_seated(),
			"BEGIN SHIFT enables ordinary unpaused on-foot Player control"):
		await _cleanup(game)
		return

	# --- Stage outbound streaming position -----------------------------------
	var anchor := NearbySectorCluster.PLATFORM_ANCHOR
	var toward_station := (Vector3.ZERO - anchor).normalized()
	game.active_ship = ship
	ship.set_piloted(true)
	ship.global_position = anchor + toward_station * STREAM_LOAD_SAMPLE
	await _wait_for_cluster(bootstrap, true)
	var cluster := bootstrap.get_loaded_instance() as NearbySectorCluster
	_check(
		cluster != null and world.get_nearby_sector_cluster() == cluster,
		"the staged outbound pose streams exactly one live Cinder generation"
	)
	if cluster == null:
		await _cleanup(game)
		return
	var hulk := cluster.get_station_hulk()
	var berth := game.get_station_hulk_berth()
	_check(
		hulk != null and berth != null and berth == hulk.get_dock_berth(),
		"the loaded sector publishes the hulk and its docking face to GameFlow"
	)
	if hulk == null or berth == null:
		await _cleanup(game)
		return
	hulk_board_row = _hulk_board_row(hud)
	var hulk_board_snapshot := (hud.get_nearby_activity_report().get("snapshot", {}) as Dictionary).get(
		"hulk_power", {}
	) as Dictionary
	_check(hulk_board_row != null and hulk_board_row.get_child_count() == 2
		and "HULK DOCK MINIMAP MARK" in (hulk_board_row.get_child(0) as Label).text
		and not (hulk_board_row.get_child(1) as Button).disabled
		and (hulk_board_snapshot.get("dock_position", Vector3.ZERO) as Vector3)
			.is_equal_approx(berth.get_dock_transform().origin)
		and int(_reward_counts(game).get(String(EXPECTED_REWARD_ID), 0)) == 0,
		"the loaded board points to the streamed dock without starting salvage")

	# --- The cockpit can see where this place is -----------------------------
	# Until now the hulk was reached by walking to a breaker you had to already
	# know about. Flying out with the sector resident must mark it.
	var was_piloting := bool(game.get("_piloting"))
	game.set("_piloting", true)
	var flying_markers := _marker_positions(game)
	_check(
		flying_markers.has(&"nearby_hulk_dock")
		and flying_markers.has(&"nearby_belt_bore")
		and flying_markers.has(&"nearby_route_beacon")
		and flying_markers.has(&"nearby_ringed_moonlet")
		and flying_markers.has(&"nearby_extraction_platform")
		and flying_markers.has(&"nearby_debris_field"),
		"a resident sector marks every named place on the cockpit minimap"
	)
	_check(
		(flying_markers.get(&"nearby_route_beacon", []) as Array).size() == 4
		and ((flying_markers.get(&"nearby_hulk_dock", []) as Array)[0] as Vector3)
			.is_equal_approx(hulk.get_dock_world_transform().origin),
		"the hulk's mark is its real dock and the beacon chain marks all four"
	)

	# One briefing, the first time the pilot comes close, then silence.
	var dock_position := hulk.get_dock_world_transform().origin
	game.set("_piloting", true)
	_check(
		not game.has_seen_activity_tutorial(&"cinder_hulk_power_restoration"),
		"the hulk has not briefed the pilot before the first approach"
	)
	game.call(&"_advance_nearby_destination_briefings", {
		"available": true, "position": dock_position,
	})
	_check(
		game.has_seen_activity_tutorial(&"cinder_hulk_power_restoration")
		and StringName(game.get("_activity_tutorial_active_id"))
			== &"cinder_hulk_power_restoration"
		and not game.has_seen_activity_tutorial(
			&"cinder_asteroid_field_threading_run"
		),
		"the first approach to the hulk briefs that place and only that place"
	)
	game.set("_activity_tutorial_active_id", &"")
	game.call(&"_advance_nearby_destination_briefings", {
		"available": true, "position": dock_position,
	})
	_check(
		StringName(game.get("_activity_tutorial_active_id")).is_empty(),
		"a second approach to the hulk is silent"
	)
	# Far away in the same resident sector, nothing is published.
	var distant := dock_position + Vector3(0.0, 0.0, 5000.0)
	game.call(&"_advance_nearby_destination_briefings", {
		"available": true, "position": distant,
	})
	_check(
		StringName(game.get("_activity_tutorial_active_id")).is_empty()
		and not game.has_seen_activity_tutorial(
			&"cinder_asteroid_field_threading_run"
		),
		"a place the pilot has not flown near is never briefed"
	)
	var belt_family := flying_markers.get(&"nearby_belt_bore", []) as Array
	game.call(&"_advance_nearby_destination_briefings", {
		"available": true, "position": belt_family[0] as Vector3,
	})
	_check(
		game.has_seen_activity_tutorial(&"cinder_asteroid_field_threading_run"),
		"coming up on the belt bore briefs the threading run once"
	)
	game.set("_activity_tutorial_active_id", &"")

	# The Destination Board now offers both places, because they are out there.
	var resident_board := game.get_planetary_destination_catalog_snapshot()
	_check(
		int(resident_board.get("sector_site_count", -1)) == 2
		and (resident_board.get("available_sector_site_ids", PackedStringArray())
			as PackedStringArray).size() == 2,
		"the Destination Board offers both places while the sector is resident"
	)
	(hulk_board_row.get_child(1) as Button).emit_signal("pressed")
	_check(StringName(game.get("_activity_tutorial_active_id")) == EXPECTED_ACTIVITY_ID
		and StringName(game.get_hulk_power_restoration_snapshot().get("state_id", &""))
			== &"idle"
		and int(_reward_counts(game).get(String(EXPECTED_REWARD_ID), 0)) == 0,
		"the board's briefing button reopens the authored card without starting or rewarding salvage")
	game.set("_piloting", was_piloting)

	# --- Dock ----------------------------------------------------------------
	# Park on the berth's own clear staging pose and hand the existing landing
	# path the same request the pause-menu landing command issues.
	var staging := berth.get_assist_staging_transform()
	ship.global_transform = staging
	ship.velocity = Vector3.ZERO
	await physics_frame
	var assist := game.call(&"_get_active_landing_assist_report") as Dictionary
	_check(
		StringName(assist.get("selected_berth_id", &"")) == EXPECTED_BERTH_ID
		and bool(assist.get("assist_capture_accepted", false))
		and bool(assist.get("streamed_destination", false)),
		"the existing landing-assist path selects the streamed hulk berth"
	)

	var token := berth.try_reserve(ship, ship.get_ship_definition())
	_check(
		not token.is_empty() and berth.is_reserved(),
		"the hulk grants an ordinary berth lease to the arriving craft"
	)
	var docked := berth.occupy(ship, token)
	ship.global_transform = berth.get_dock_transform()
	ship.velocity = Vector3.ZERO
	await physics_frame
	_check(
		docked and berth.is_occupied() and berth.get_occupant() == ship
		and berth.contains(ship.global_position),
		"the craft is physically parked inside the hulk's docking volume"
	)
	_check(
		game.call(&"_resolve_berth_node", EXPECTED_BERTH_ID) == berth
		and game.call(&"_resolve_berth_node", &"central_berth") != berth,
		"one berth resolver answers for both the resident station and the hulk"
	)

	# --- Disembark -----------------------------------------------------------
	var route := hulk.get_interior_route_points()
	ship.set_piloted(false)
	# Temporary read-only onset trace: arm before the unchanged staging placement
	# so the cached pre-teleport floor state is captured separately from motor ticks.
	player.set_meta(&"_hulk_landing_onset_trace", {
		"shelf": weakref(hulk.find_child("DockShelf", true, false)),
	})
	player.call(&"_hulk_landing_onset_capture_initial")
	player.teleport_to(Transform3D(Basis.IDENTITY, route[0] + Vector3(0.0, 1.0, 0.0)))
	# Settle only by the production controller's gravity after the one staging
	# placement. No body pose/velocity writes occur until the later fringe test.
	for _settle in 60:
		await physics_frame
		if player.is_on_floor():
			break
	if not _check(
		not paused and player.can_process() and player.is_control_enabled()
		and not player.is_seated() and _has_hulk_support(player, hulk)
		and player.global_position.distance_to(route[0]) < 6.0,
		"the staged unseated pilot settles on actual hulk dock-shelf collision"
	):
		await _cleanup(game)
		return
	game.set("_piloting", false)
	_check(
		_marker_positions(game).is_empty(),
		"a pilot out of the seat gets no flight destination marks"
	)

	# --- Walk the interior ---------------------------------------------------
	var space_state := player.get_world_3d().direct_space_state
	var blocked_legs := 0
	for index in range(1, route.size()):
		var query := PhysicsRayQueryParameters3D.create(
			route[index - 1], route[index], PhysicsLayers.WORLD
		)
		if not space_state.intersect_ray(query).is_empty():
			blocked_legs += 1
	if not _check(blocked_legs == 0,
			"every doorway on the authored route is a real opening"):
		await _cleanup(game)
		return
	if not await _walk_hulk_route(player, hulk, route):
		await _cleanup(game)
		return

	# --- Complete the activity at the walked-to breaker ----------------------
	var breaker := hulk.get_breaker()
	# The breaker has to be a control the walking pilot actually finds, not a
	# node a test can reach: it must turn up in the production interaction
	# query with a prompt, on the interactable layer, exactly as the station's
	# own consoles do.
	_check(
		breaker.collision_layer == PhysicsLayers.INTERACTABLE_AREA_LAYER
		and breaker.has_method(&"get_interaction_prompt")
		and breaker.has_method(&"interact")
		and not str(breaker.call(&"get_interaction_prompt")).is_empty()
		and player.get_nearby_interactables().has(breaker),
		"the walking pilot's own interaction query finds the breaker and its prompt"
	)
	game.call(&"_sync_hulk_power_restoration_binding")
	var before := game.get_hulk_power_restoration_snapshot()
	_check(
		bool(before.get("available", false))
		and bool(before.get("breaker_bound", false))
		and StringName(before.get("state_id", &"")) == &"idle",
		"the physical breaker is bound and the salvage run has not started"
	)
	_check(_interior_lighting_matches(hulk, false),
		"unclaimed hulk fixtures retain dim emergency lighting")
	# The pilot's 2.35 m interaction sphere reaches the breaker's box from
	# diagonally off its corner, more than the activity's 4 m reach from the
	# breaker itself. That press is refused, and the panel must keep offering
	# the breaker rather than claiming the bus is engaged.
	var fringe := hulk.get_breaker_world_position() + Vector3(3.1, 0.0, 3.1)
	player.teleport_to(Transform3D(
		Basis.looking_at(Vector3(-1.0, 0.0, -1.0).normalized(), Vector3.UP), fringe
	))
	player.velocity = Vector3.ZERO
	for _settle in 6:
		await physics_frame
	var fringe_reachable := player.get_nearby_interactables().has(breaker) \
		and player.global_position.distance_to(
			POWER_ACTIVITY.BREAKER_ANCHOR
		) > POWER_ACTIVITY.INTERACTION_RADIUS
	breaker.call(&"interact", player)
	var refused := game.get_hulk_power_restoration_snapshot()
	_check(
		fringe_reachable
		and StringName(refused.get("state_id", &"")) == &"idle"
		and str(breaker.call(&"get_interaction_prompt")).contains(
			"ENGAGE AUXILIARY POWER BREAKER"
		),
		"a refused press from the fringe of reach leaves the breaker offered, not engaged (%s, %s, reach %s)"
			% [str(breaker.call(&"get_interaction_prompt")), refused.get("state_id", &""),
				fringe_reachable]
	)
	# A common-origin rebase leaves the streamed Cinder roots away from their
	# authored world position; the breaker must still be reachable there.
	var rebase_offset := Vector3(2000.0, 0.0, 0.0)
	bootstrap.global_position += rebase_offset
	player.teleport_to(
		Transform3D(Basis.IDENTITY, hulk.get_breaker_world_position())
	)
	await physics_frame
	await physics_frame
	_check(
		breaker.call(&"interact", player),
		"the on-foot pilot can operate the auxiliary breaker"
	)
	var engaged := game.get_hulk_power_restoration_snapshot()
	_check(
		StringName(engaged.get("state_id", &"")) == &"active"
		and int(engaged.get("generation", 0)) == 1,
		"throwing the breaker starts exactly one generation of the salvage run, even after an origin rebase (%s)"
			% str(engaged.get("state_id", &""))
	)
	_check(
		str(breaker.call(&"get_interaction_prompt")).contains("ENGAGED"),
		"an accepted throw shows the bus engaged while it restores (%s)"
			% str(breaker.call(&"get_interaction_prompt"))
	)
	bootstrap.global_position -= rebase_offset
	player.teleport_to(
		Transform3D(Basis.IDENTITY, hulk.get_breaker_world_position())
	)
	await physics_frame
	_check(_interior_lighting_matches(hulk, false),
		"throwing the breaker alone does not light the bus before its reward commits")
	await _advance_until_claimed(game)
	var claimed := game.get_hulk_power_restoration_snapshot()
	_check(
		StringName(claimed.get("state_id", &"")) == &"claimed"
		and bool(claimed.get("reward_claimed", false)),
		"holding the gallery brings the auxiliary bus up and claims the cell"
	)
	_check(_interior_lighting_matches(hulk, true),
		"the committed claim changes seven existing interior fixtures to restored bus lighting")
	_check(bool(cluster.get_streaming_transition_audit().get("valid", false)),
		"the restored fixture energy remains on the sector's audited stream fade")
	hulk_board_row = _hulk_board_row(hud)
	_check(hulk_board_row != null and hulk_board_row.get_child_count() == 2
		and "COMPLETED" in (hulk_board_row.get_child(0) as Label).text
		and "POWER CELL SECURED" in (hulk_board_row.get_child(0) as Label).text
		and (hulk_board_row.get_child(1) as Button).disabled,
		"the Activity Board reports the persisted one-shot completion")

	# --- Exactly once --------------------------------------------------------
	var ledger := _reward_counts(game)
	_check(
		int(ledger.get(String(EXPECTED_REWARD_ID), 0)) == 1,
		"the reward authority holds exactly one committed power-cell receipt"
	)
	breaker.call(&"interact", player)
	await _advance_physics(game, 12)
	_check(
		int(_reward_counts(game).get(String(EXPECTED_REWARD_ID), 0)) == 1
		and StringName(
			game.get_hulk_power_restoration_snapshot().get("state_id", &"")
		) == &"claimed",
		"operating the breaker again cannot produce a second cell"
	)

	# --- Save and whole-Main re-entry ---------------------------------------
	var saved_generation := store.get_generation()
	_check(
		saved_generation > 0
		and (store.get_snapshot() as Dictionary).has(
			String(GameFlowRewardAuthority.SLOT_ID)
		),
		"the claim is committed to the atomic store, not only to memory"
	)
	var parent := game.get_parent()
	parent.remove_child(game)
	await process_frame
	parent.add_child(game)
	await process_frame
	await physics_frame
	game.call(&"_sync_hulk_power_restoration_binding")
	var after_reentry := game.get_hulk_power_restoration_snapshot()
	_check(
		StringName(after_reentry.get("state_id", &"")) == &"claimed"
		and int(_reward_counts(game).get(String(EXPECTED_REWARD_ID), 0)) == 1,
		"whole-Main re-entry keeps the cell claimed and the ledger at one receipt"
	)
	_check(_interior_lighting_matches(hulk, true),
		"whole-Main re-entry preserves restored lighting on the loaded hulk")
	hulk_board_row = _hulk_board_row(hud)
	_check(hulk_board_row != null and "COMPLETED" in
		(hulk_board_row.get_child(0) as Label).text,
		"whole-Main re-entry restores the completed Activity Board row")

	# A fresh authority configured from the same saved store — the shape a new
	# process takes — must also read the claim back rather than reopening it.
	var reloaded_authority := GameFlowRewardAuthority.new()
	var reloaded_store := Store.new(STORE_PATH, filesystem) as UserDataStore
	reloaded_store.load()
	reloaded_authority.configure(reloaded_store)
	var reloaded_activity := POWER_ACTIVITY.new()
	var restored := reloaded_activity.restore_from_reward_ledger(
		(reloaded_authority.get_snapshot().get("record", {}) as Dictionary).get(
			"reward_counts", {}
		) as Dictionary
	)
	_check(
		bool(restored.get("accepted", false))
		and reloaded_activity.is_claimed()
		and not bool(reloaded_activity.engage(EXPECTED_BREAKER_ANCHOR).get(
			"accepted", true
		)),
		"a fresh session restores the claim from the saved ledger and refuses a replay"
	)

	# --- Fly home ------------------------------------------------------------
	berth.release(ship, token)
	ship.set_piloted(true)
	ship.global_position = anchor + toward_station * STREAM_UNLOAD_SAMPLE
	await _wait_for_cluster(bootstrap, false)
	_check(
		bootstrap.get_loaded_instance() == null
		and world.get_nearby_sector_cluster() == null
		and game.get_station_hulk_berth() == null
		and game.find_children("*", "AbandonedStationHulk", true, false).is_empty(),
		"flying home unloads the sector and leaves no hulk, berth or phantom behind"
	)
	_check(
		StringName(
			game.get_hulk_power_restoration_snapshot().get("state_id", &"")
		) == &"claimed",
		"the recovered cell survives the trip home with the destination unloaded"
	)
	ship.global_position = anchor + toward_station * STREAM_LOAD_SAMPLE
	await _wait_for_cluster(bootstrap, true)
	for _fade_frame in 36:
		await physics_frame
	var reloaded_hulk := _get_reloaded_hulk(bootstrap)
	_check(reloaded_hulk != null and reloaded_hulk != hulk
		and _interior_lighting_matches(reloaded_hulk, true)
		and bool((bootstrap.get_loaded_instance() as NearbySectorCluster)
			.get_streaming_transition_audit().get("valid", false))
		and int(_reward_counts(game).get(String(EXPECTED_REWARD_ID), 0)) == 1,
		"stream re-entry restores bus lighting on a new hulk with one reward receipt")
	ship.global_position = anchor + toward_station * STREAM_UNLOAD_SAMPLE
	await _wait_for_cluster(bootstrap, false)
	game.set("_piloting", true)
	_check(
		_marker_positions(game).is_empty(),
		"the streamed-out sector takes every one of its marks off the map"
	)
	var away_board := game.get_planetary_destination_catalog_snapshot()
	_check(
		int(away_board.get("sector_site_count", -1)) == 2
		and (away_board.get("available_sector_site_ids", PackedStringArray())
			as PackedStringArray).is_empty()
		and not bool(game.call(
			&"_on_hud_sector_site_briefing_requested", &"cinder_hulk_dock_site"
		)),
		"the board still lists both places but refuses them once the sector is away"
	)
	# A pilot who comes back is not briefed a second time.
	game.set("_activity_tutorial_active_id", &"")
	_check(
		not game.publish_activity_tutorial_briefing(
			&"cinder_hulk_power_restoration"
		)
		and game.has_seen_activity_tutorial(&"cinder_hulk_power_restoration"),
		"the sector briefings stay remembered across the round trip"
	)

	await _cleanup(game)


## A genuine panel completion on real disk must remain recoverable while the
## reward transaction is refused. Samples position the actor; no flight claim.
func _test_unpaid_recovery() -> void:
	var path := "user://hulk_unpaid_recovery_%d.json" % Time.get_ticks_usec()
	var fault := RewardFaultFilesystem.new()
	var first := await _recovery_game(path, fault)
	var hulk := await _recovery_hulk(first)
	first.call(&"_on_settings_save_requested")
	var settings_before: Dictionary = first.get("_runtime_settings_user_data_store").get_snapshot().runtime_settings
	first.player.teleport_to(Transform3D(Basis.IDENTITY, hulk.get_breaker_world_position()))
	_check(hulk.get_breaker().call(&"interact", first.player), "the production breaker accepts the on-foot unpaid recovery attempt")
	var disk_before := FileAccess.get_file_as_bytes(path)
	first.call(&"_advance_hulk_power_restoration", 3.0)
	var unsaved := first.get_hulk_power_restoration_snapshot()
	var owner := first.get("_hulk_power_activity") as DerelictPowerRestorationActivity
	var reset := owner.reset()
	var card := _hulk_board_row(first.hud)
	_check(unsaved.state_id == &"complete" and unsaved.reward_pending and not reset.accepted
		and fault.rejected_rewards == 0 and FileAccess.get_file_as_bytes(path) == disk_before
		and "POWER CELL SAVE PENDING" in (card.get_child(0) as Label).text,
		"a refused first terminal save preserves the earned owner and disk, blocks reset, and reports pending without paying")
	fault.reject_terminals = false
	first.call(&"_advance_hulk_power_restoration", 1.0)
	var completed := first.get_hulk_power_restoration_snapshot()
	_check(completed.state_id == &"complete" and completed.reward_pending and fault.rejected_rewards > 0
		and int(_reward_counts(first).get(String(EXPECTED_REWARD_ID), 0)) == 0,
		"the genuine completed breaker run remains pending when its real reward write is refused")
	var saved: Dictionary = first.get("_runtime_settings_user_data_store").get_snapshot()
	var pending := saved.get("cinder_hulk_power_session", {}) as Dictionary
	_check(not pending.is_empty() and pending.get("state") == POWER_ACTIVITY.State.COMPLETE,
		"real disk retains the typed earned hulk completion before any reward is published")
	reset = owner.reset()
	_check(not reset.accepted and owner.get_snapshot().state_id == &"complete",
		"the public attempt reset cannot discard a genuinely earned unpaid cell")
	var rejected_before := fault.rejected_rewards
	for _frame in 180:
		await physics_frame
		first.call(&"_advance_hulk_power_restoration", PHYSICS_DELTA)
	var attempts := fault.rejected_rewards - rejected_before
	_check(attempts >= 2 and attempts <= 3 and first.get_hulk_power_restoration_snapshot().reward_pending,
		"sustained refusal retries the live earned completion at a bounded cadence across 180 real physics frames (%d attempts)" % attempts)
	await _cleanup(first)
	var second := await _recovery_game(path, fault)
	var restored := second.get_hulk_power_restoration_snapshot()
	_check(restored.state_id == &"complete" and restored.reward_pending and not restored.hulk_loaded
		and restored.elapsed_seconds == POWER_ACTIVITY.RESTORE_SECONDS and int(restored.generation) == int(completed.generation)
		and int(_reward_counts(second).get(String(EXPECTED_REWARD_ID), 0)) == 0,
		"fresh Main restores the genuine earned pending completion without a reward receipt")
	fault.reject_rewards = false
	second.call(&"_advance_hulk_power_restoration", 1.0)
	var claimed := second.get_hulk_power_restoration_snapshot()
	_check(claimed.state_id == &"claimed" and claimed.reward_claimed
		and int(_reward_counts(second).get(String(EXPECTED_REWARD_ID), 0)) == 1,
		"the production retry owner commits the recovered power cell exactly once after storage recovers")
	second.call(&"_advance_hulk_power_restoration", 0.0)
	_check(int(_reward_counts(second).get(String(EXPECTED_REWARD_ID), 0)) == 1,
		"a later production tick does not pay the recovered one-shot cell again")
	await _cleanup(second)
	var third := await _recovery_game(path, UserDataFilesystem.new())
	var paid := third.get_hulk_power_restoration_snapshot()
	_check(paid.state_id == &"claimed" and int(_reward_counts(third).get(String(EXPECTED_REWARD_ID), 0)) == 1,
		"another fresh Main restores permanent one-shot claimed state from its legitimate receipt ledger")
	_check(third.get("_runtime_settings_user_data_store").get_snapshot().runtime_settings == settings_before,
		"hulk completion staging and payment preserve the saved runtime settings namespace")
	await _cleanup(third)


func _recovery_game(path: String, filesystem: UserDataFilesystem) -> GameFlow:
	var game := MAIN_SCENE.instantiate() as GameFlow
	game.configure_runtime_settings_persistence(UserDataStore.new(path, filesystem), path + ".legacy.cfg")
	root.add_child(game)
	await process_frame
	await physics_frame
	await process_frame
	game.set_physics_process(false)
	game.call(&"_sync_hulk_power_restoration_binding")
	return game


func _recovery_hulk(game: GameFlow) -> AbandonedStationHulk:
	game.cinder_streaming_bootstrap.update_position(CinderStreamingBootstrap.EXPECTED_NAVIGATION_ANCHOR)
	for _frame in 180:
		if is_instance_valid(game.call(&"_get_station_hulk")):
			break
		await process_frame
	game.call(&"_sync_hulk_power_restoration_binding")
	return game.call(&"_get_station_hulk") as AbandonedStationHulk


# --- Helpers -----------------------------------------------------------------


## Require both the capsule floor flag and a World collider belonging to this
## streamed hulk, rather than accepting the parked ship or a nearby platform.
func _has_hulk_support(player: PlayerController, hulk: AbandonedStationHulk) -> bool:
	if not player.is_on_floor():
		return false
	var query := PhysicsRayQueryParameters3D.create(
		player.global_position + Vector3.UP * 0.2,
		player.global_position - Vector3.UP * 0.3, PhysicsLayers.WORLD
	)
	var hit := player.get_world_3d().direct_space_state.intersect_ray(query)
	var collider := hit.get("collider") as Node
	return collider != null and hulk.is_ancestor_of(collider)


func _walk_hulk_route(
		player: PlayerController, hulk: AbandonedStationHulk, route: Array[Vector3]
	) -> bool:
	var camera_yaw := player.get_node(^"CameraRig/CameraYaw") as Node3D
	var capsule := player.get_node(^"PlayerCollision") as CollisionShape3D
	var capsule_shape := capsule.shape
	var player_id := player.get_instance_id()
	var authored_length := 0.0
	for index in range(1, route.size()):
		authored_length += Vector2(route[index].x - route[index - 1].x,
			route[index].z - route[index - 1].z).length()
	# Headroom covers acceleration, turning and ordinary stopping. The wall
	# deadline also bounds a paused/stalled scene within the existing suite cap.
	var walk_seconds := authored_length / player.walk_speed * 2.0 + route.size() * 2.0
	var deadline := mini(Time.get_ticks_msec() + int(ceil(walk_seconds * 1000.0)),
		_suite_started_msec + SUITE_WALL_BUDGET_MSEC - 10000)
	var path_length := 0.0
	var max_step := 0.0
	var max_step_per_tick := 0.0
	var observed_physics_ticks := 0
	var samples := 0
	var previous := player.global_position
	var step_limit := player.walk_speed / float(Engine.physics_ticks_per_second) * 1.25 + 0.02
	var reached := 0
	var support_colliders: Dictionary = {}
	for index in route.size():
		var leg_distance := 0.0
		if index > 0:
			leg_distance = Vector2(route[index].x - route[index - 1].x,
				route[index].z - route[index - 1].z).length()
		var frame_budget := int(ceil((leg_distance / player.walk_speed * 2.0 + 1.0)
			* float(Engine.physics_ticks_per_second)))
		var leg_reached := false
		var reason := "leg frame budget exhausted"
		var last_movement_trace: Dictionary = {}
		for _frame in frame_budget:
			if Time.get_ticks_msec() >= deadline:
				reason = "walk wall deadline exceeded"
				break
			if paused or not player.can_process() or not player.is_control_enabled() \
					or player.is_seated() or player.get_instance_id() != player_id \
					or capsule.shape != capsule_shape or capsule.disabled \
					or not _has_hulk_support(player, hulk):
				reason = "capsule, control or actual hulk support lost"
				break
			var query := PhysicsRayQueryParameters3D.create(
				player.global_position + Vector3.UP * 0.2,
				player.global_position - Vector3.UP * 0.3, PhysicsLayers.WORLD)
			var hit := player.get_world_3d().direct_space_state.intersect_ray(query)
			support_colliders[str(hulk.get_path_to(hit.collider))] = true
			var delta := Vector2(route[index].x - player.global_position.x,
				route[index].z - player.global_position.z)
			# Stop through normal deceleration; retain every settled waypoint as
			# the start of the next leg, never repositioning the capsule.
			if delta.length() <= WALK_STOP_DISTANCE:
				Input.action_release(&"move_forward")
			else:
				camera_yaw.rotation.y = atan2(-delta.x, -delta.y)
				Input.action_press(&"move_forward")
			var before_physics_tick := Engine.get_physics_frames()
			await physics_frame
			# Sample after production physics has consumed the action.
			await process_frame
			var elapsed_physics_ticks := maxi(1,
				Engine.get_physics_frames() - before_physics_tick)
			observed_physics_ticks += elapsed_physics_ticks
			var current := player.global_position
			var step := Vector2(current.x - previous.x, current.z - previous.z).length()
			path_length += step
			max_step = maxf(max_step, step)
			max_step_per_tick = maxf(max_step_per_tick, step / float(elapsed_physics_ticks))
			samples += 1
			previous = current
			last_movement_trace = _hulk_movement_trace(player)
			if step > step_limit * elapsed_physics_ticks or not _has_hulk_support(player, hulk) \
					or paused or not player.can_process() or not player.is_control_enabled() \
					or player.is_seated() or capsule.shape != capsule_shape or capsule.disabled:
				reason = "control/support lost or discontinuous capsule movement sample"
				break
			if delta.length() <= WALK_STOP_DISTANCE \
					and Vector2(player.velocity.x, player.velocity.z).length() < 0.05:
				leg_reached = Vector2(current.x - route[index].x,
					current.z - route[index].z).length() <= WALK_TARGET_TOLERANCE
				break
		if not leg_reached:
			print("HULK_WALK_STALL_CONTACT: ", JSON.stringify({
				"waypoint": index, "reason": reason,
				"position": player.global_position, "target": route[index],
				"last_held_sample": last_movement_trace,
			}))
		Input.action_release(&"move_forward")
		if not _check(leg_reached,
				"ordinary supported walk reaches authored hulk waypoint %d (%s; position %s, target %s)"
				% [index, "reached" if leg_reached else reason, player.global_position, route[index]]):
			return false
		reached += 1
	var minimum_path := authored_length - 2.0 * WALK_TARGET_TOLERANCE * (route.size() - 1)
	var minimum_physics_ticks := int(floor(minimum_path / step_limit))
	print("HULK_CONTINUOUS_INTERIOR_WALK: route=", route, " reached=", reached,
		" authored_m=", authored_length, " sampled_m=", path_length,
		" samples=", samples, " physics_ticks=", observed_physics_ticks,
		" max_sample_m=", max_step, " max_step_per_tick_estimate_m=", max_step_per_tick,
		" support_colliders=", support_colliders.keys(), " player_id=", player_id)
	return _check(path_length >= minimum_path and observed_physics_ticks >= minimum_physics_ticks,
		"sampled continuous movement covers the authored route within waypoint tolerance")


## Read-only context captured before the leg releases its held input. Keep
## collider identities and contact details so a stalled capsule is not guessed
## to be an input, scene, or geometry failure from its position alone.
func _hulk_movement_trace(player: PlayerController) -> Dictionary:
	var contacts: Array[Dictionary] = []
	for index in player.get_slide_collision_count():
		var contact := player.get_slide_collision(index)
		var collider := contact.get_collider() as Node
		contacts.append({
			"collider": str(collider.get_path()) if collider != null else "",
			"normal": contact.get_normal(), "depth": contact.get_depth(),
			"travel": contact.get_travel(), "remainder": contact.get_remainder(),
		})
	var raw := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	return {
		"raw_move": raw, "sampled_move": player.call(&"_sample_move_vector"),
		"forward_held": Input.is_action_pressed(&"move_forward"),
		"physics_processing": player.is_physics_processing(),
		"can_process": player.can_process(), "paused": paused,
		"embodiment_state": player.get("_embodiment_state"),
		"control_enabled": player.is_control_enabled(),
		"remote_drive": player.get_remote_drive_audit(),
		"velocity": player.velocity, "on_floor": player.is_on_floor(),
		"on_wall": player.is_on_wall(), "slide_contacts": contacts,
	}


func _get_reloaded_hulk(bootstrap: CinderStreamingBootstrap) -> AbandonedStationHulk:
	var cluster := bootstrap.get_loaded_instance() as NearbySectorCluster
	return cluster.get_station_hulk() if cluster != null else null


func _interior_lighting_matches(hulk: AbandonedStationHulk, restored: bool) -> bool:
	if hulk == null or hulk.is_auxiliary_power_restored() != restored:
		return false
	var interiors := 0
	var dock := 0
	for light in hulk.get_light_nodes():
		if light.name == "DockShelfPractical":
			if (light.light_color.is_equal_approx(HULK.DOCK_CYAN)
					and light.light_energy < 1.0):
				dock += 1
			continue
		if restored:
			if (light.light_color.is_equal_approx(HULK.RESTORED_BUS_COLOR)
					and is_equal_approx(light.light_energy, HULK.RESTORED_PRACTICAL_ENERGY)
					and is_equal_approx(light.omni_range, HULK.RESTORED_PRACTICAL_RANGE)
					and is_equal_approx(light.omni_attenuation,
						HULK.RESTORED_PRACTICAL_ATTENUATION)):
				interiors += 1
		elif (light.light_energy <= 1.0 and light.omni_range == HULK.PRACTICAL_RANGE
				and is_equal_approx(light.omni_attenuation,
					HULK.EMERGENCY_PRACTICAL_ATTENUATION)
				and not light.light_color.is_equal_approx(HULK.RESTORED_BUS_COLOR)):
			interiors += 1
	return interiors == 7 and dock == 1 and hulk.get_light_nodes().size() == 8


## Nearby-sector destination marks currently on the published minimap roster,
## grouped by family. Every other objective marker is ignored.
func _marker_positions(game: GameFlow) -> Dictionary:
	var families: Dictionary = {}
	for marker_variant: Variant in (
		game.get_minimap_snapshot().get("objective_markers", []) as Array
	):
		var marker := marker_variant as Dictionary
		var marker_id := StringName(marker.get("id", &""))
		if not String(marker_id).begins_with("nearby_"):
			continue
		if not families.has(marker_id):
			families[marker_id] = []
		(families[marker_id] as Array).append(marker.get("position", Vector3.INF))
	return families


func _hulk_board_row(hud: GameHUD) -> Control:
	if not is_instance_valid(hud):
		return null
	return hud.find_child(
		"NearbyActivityRow_cinder_hulk_power_restoration", true, false
	) as Control


func _reward_counts(game: GameFlow) -> Dictionary:
	var report := game.get_activity_reward_report()
	var record := (report.get("authority", {}) as Dictionary).get(
		"record", {}
	) as Dictionary
	return record.get("reward_counts", {}) as Dictionary


func _advance_physics(game: GameFlow, frames: int) -> void:
	for _frame in frames:
		if not is_instance_valid(game):
			return
		await physics_frame


func _advance_until_claimed(game: GameFlow) -> void:
	for _frame in 240:
		await physics_frame
		var snapshot := game.get_hulk_power_restoration_snapshot()
		if StringName(snapshot.get("state_id", &"")) == &"claimed":
			return


func _wait_for_cluster(
		bootstrap: CinderStreamingBootstrap,
		expect_loaded: bool
	) -> void:
	for _frame in 120:
		await physics_frame
		if (bootstrap.get_loaded_instance() != null) == expect_loaded:
			return


func _cleanup(game: GameFlow) -> void:
	Input.action_release(&"move_forward")
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if is_instance_valid(game):
		if is_instance_valid(game.player) and game.player.has_meta(&"_hulk_landing_onset_trace"):
			game.player.remove_meta(&"_hulk_landing_onset_trace")
		game.queue_free()
	await process_frame
	await process_frame


func _check(condition: bool, description: String) -> bool:
	_assertions += 1
	if condition:
		print("PASS: ", description)
	else:
		_failures.append(description)
		push_error("FAIL: " + description)
	return condition


func _finish() -> void:
	Input.action_release(&"move_forward")
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	print("ABANDONED_HULK_LOOP_TEST_ASSERTIONS: ", _assertions)
	if _failures.is_empty():
		print("ABANDONED_HULK_LOOP_TEST_OK")
		quit(0)
	else:
		print("ABANDONED_HULK_LOOP_TEST_FAILED: ", ", ".join(_failures))
		quit(1)
