extends SceneTree

## The whole abandoned-station-hulk loop, driven once through production `Main`.
##
## Every other nearby-sector suite proves a piece of the sector you fly *past*.
## This one proves the piece you go *inside*, end to end and in order: fly out
## of the launch corridor until the sector streams, park against the hulk's
## docking face through the existing berth lease, leave the seat, walk the three
## connected interior spaces on real collision, throw the auxiliary breaker,
## take the reward exactly once, save, re-enter the whole of `Main`, confirm the
## cell is still claimed and cannot be claimed again, and fly home until the
## sector unloads and nothing is left behind.
##
## It drives the production composition, not a fixture: the same `GameFlow`,
## the same `ShipBerth`, the same `PlayerController`, the same
## `GameFlowRewardAuthority` and the same atomic store the game ships with. The
## only injection is the store's filesystem, so no test writes a real save.

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
const EXPECTED_MESH_INSTANCES := 39
const EXPECTED_BREAKER_ANCHOR := Vector3(-146.0, 23.8, -467.0)
## Nothing the hulk builds may crowd the station or leave the sector envelope.
const STATION_EXCLUSION_RADIUS := 200.0
const CONTENT_ENVELOPE := 940.0
## The streaming policy loads at or inside 500 m of the Cinder anchor and
## unloads only beyond 650 m.
const STREAM_LOAD_SAMPLE := 480.0
const STREAM_UNLOAD_SAMPLE := 700.0

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


func _init() -> void:
	call_deferred(&"_run")


func _run() -> void:
	_test_frozen_contract()
	_test_component_shape_and_budget()
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


## Fly out, dock, disembark, walk, restore power, take the reward once, save,
## re-enter, confirm, fly home.
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

	# --- Fly out -------------------------------------------------------------
	var anchor := NearbySectorCluster.PLATFORM_ANCHOR
	var toward_station := (Vector3.ZERO - anchor).normalized()
	game.active_ship = ship
	ship.set_piloted(true)
	ship.global_position = anchor + toward_station * STREAM_LOAD_SAMPLE
	await _wait_for_cluster(bootstrap, true)
	var cluster := bootstrap.get_loaded_instance() as NearbySectorCluster
	_check(
		cluster != null and world.get_nearby_sector_cluster() == cluster,
		"flying out streams exactly one live Cinder generation"
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
	player.teleport_to(Transform3D(Basis.IDENTITY, route[0] + Vector3(0.0, 1.0, 0.0)))
	player.set_camera_active(true)
	player.set_control_enabled(true)
	await physics_frame
	await physics_frame
	_check(
		not player.is_seated()
		and player.global_position.distance_to(route[0]) < 6.0,
		"the pilot leaves the seat and stands on the hulk's dock shelf"
	)
	game.set("_piloting", false)
	_check(
		_marker_positions(game).is_empty(),
		"a pilot out of the seat gets no flight destination marks"
	)

	# --- Walk the interior ---------------------------------------------------
	# Real collision, walked rather than asserted: at every waypoint the deck
	# has to hold the capsule up, and between waypoints the doorways have to be
	# genuinely open in the physics world.
	var space_state := player.get_world_3d().direct_space_state
	var supported := 0
	var blocked_legs := 0
	for index in route.size():
		player.teleport_to(
			Transform3D(Basis.IDENTITY, route[index] + Vector3(0.0, 0.6, 0.0))
		)
		player.velocity = Vector3.ZERO
		for _settle in 12:
			await physics_frame
		if absf(player.global_position.y - route[index].y) < 2.0:
			supported += 1
		if index > 0:
			var query := PhysicsRayQueryParameters3D.create(
				route[index - 1], route[index], PhysicsLayers.WORLD
			)
			if not space_state.intersect_ray(query).is_empty():
				blocked_legs += 1
	_check(
		supported == route.size(),
		"the deck holds the capsule up at every point on the interior route"
	)
	_check(
		blocked_legs == 0,
		"every doorway on the route is a real opening in the physics world"
	)

	# --- Complete the activity ----------------------------------------------
	var breaker := hulk.get_breaker()
	player.teleport_to(
		Transform3D(Basis.IDENTITY, hulk.get_breaker_world_position())
	)
	await physics_frame
	await physics_frame
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
	_check(
		breaker.call(&"interact", player),
		"the on-foot pilot can operate the auxiliary breaker"
	)
	var engaged := game.get_hulk_power_restoration_snapshot()
	_check(
		StringName(engaged.get("state_id", &"")) == &"active"
		and int(engaged.get("generation", 0)) == 1,
		"throwing the breaker starts exactly one generation of the salvage run"
	)
	await _advance_until_claimed(game)
	var claimed := game.get_hulk_power_restoration_snapshot()
	_check(
		StringName(claimed.get("state_id", &"")) == &"claimed"
		and bool(claimed.get("reward_claimed", false)),
		"holding the gallery brings the auxiliary bus up and claims the cell"
	)

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


# --- Helpers -----------------------------------------------------------------


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
	if is_instance_valid(game):
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
	print("ABANDONED_HULK_LOOP_TEST_ASSERTIONS: ", _assertions)
	if _failures.is_empty():
		print("ABANDONED_HULK_LOOP_TEST_OK")
		quit(0)
	else:
		print("ABANDONED_HULK_LOOP_TEST_FAILED: ", ", ".join(_failures))
		quit(1)
