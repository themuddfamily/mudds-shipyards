extends SceneTree

## Production integration regression for the B7-observed Zenith partial
## reconstruction and its first Fleet Dock Comb berth. The historical evidence
## stops at the observed broad visual language; the exact berth assignment,
## handling, systems, weapons and landing assistance remain modern gameplay.

const MAIN_SCENE := preload("res://scenes/main.tscn")
const ZENITH_SHIP_ID: StringName = &"zenith_b7_observed"
const ZENITH_BERTH_ID: StringName = &"zenith_fleet_dock_berth"
const EXPECTED_DOCK_TRANSFORM := Transform3D(
	Basis.IDENTITY,
	Vector3(22.0, 5.28, 53.3)
)
const EXPECTED_EXIT_LOCAL := Vector3(-7.85, -0.55, 0.85)
const EXPECTED_EXIT_WORLD := Vector3(14.15, 4.73, 54.15)

## Extra simulated physics frames granted on top of the frames a wait's nominal
## duration implies. This is a frame count, never a wall-clock grace. See
## [method _wait_until] for why every wait in this suite is budgeted in frames.
const FRAME_BUDGET_GRACE := 30

var _failures: Array[String] = []
var _assertion_count := 0


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var game := MAIN_SCENE.instantiate() as GameFlow
	_check(game != null, "four-craft production Main instantiates")
	if game == null:
		_finish()
		return
	root.add_child(game)
	await process_frame
	await physics_frame
	await physics_frame

	var player := game.get_node("Player") as PlayerController
	var world := game.get_node("ShipyardWorld") as ShipyardWorld
	var torrent := game.get_node("TorrentInterceptor") as HeroShip
	var arrow := game.get_node("ArrowReconShip") as ArrowReconShip
	var jovian := game.get_node("JovianLightFreighter") as JovianLightFreighter
	var zenith := game.get_node("ZenithInterceptor") as ZenithInterceptor
	var opponent := game.get_node("RangeOpponent") as CharacterBody3D
	var authority := game.get_combat_authority()
	var fleet := game.get_flyable_ships()
	_check(
		player != null and world != null and torrent != null and arrow != null
		and jovian != null and zenith != null and opponent != null and authority != null,
		"production player, world, four hulls, defender and combat authority resolve"
	)
	if player == null or world == null or zenith == null or authority == null:
		await _clean_up(game)
		_finish()
		return

	_test_fleet_definition_and_combat(game, fleet, torrent, arrow, jovian, zenith, authority)
	var berth := world.get_berth_node(ZENITH_BERTH_ID)
	var feedback := (
		berth.get_node_or_null("BerthFeedback") as ShipBerthFeedback
		if berth != null
		else null
	)
	_test_comb_assignment_and_initial_lease(world, zenith, berth, feedback)
	_test_live_docked_collision_clearance(world, zenith, berth)
	await _test_collision_backed_access(world, zenith)
	await _test_physical_sortie(
		game, player, world, torrent, zenith, opponent, authority, berth, feedback
	)

	await _clean_up(game)
	_finish()


func _test_fleet_definition_and_combat(
	game: GameFlow,
	fleet: Array[HeroShip],
	torrent: HeroShip,
	arrow: ArrowReconShip,
	jovian: JovianLightFreighter,
	zenith: ZenithInterceptor,
	authority: Node
	) -> void:
	_check(
		fleet.size() == 4
		and fleet.has(torrent) and fleet.has(arrow)
		and fleet.has(jovian) and fleet.has(zenith),
		"Main registers exactly the four physical production flyables"
	)
	var ship_ids: Dictionary = {}
	var berth_ids: Dictionary = {}
	var source_ids: Dictionary = {}
	for craft in fleet:
		ship_ids[craft.get_ship_id()] = true
		berth_ids[craft.get_home_berth_id()] = true
		var source_id := int(authority.call("get_source_id", craft))
		if source_id > 0:
			source_ids[source_id] = true
	_check(
		ship_ids.size() == 4 and berth_ids.size() == 4 and source_ids.size() == 4,
		"the four-craft registry has unique ship, home-berth and combat-source identities"
	)
	_check(
		game.get_guided_ship() == torrent
		and int(authority.call("get_source_id", zenith)) == 1104,
		"Torrent remains guided while Zenith owns stable combat source 1104"
	)

	var definition := zenith.get_ship_definition()
	var evidence := zenith.get_zenith_evidence_report()
	_check(
		definition != null and definition.is_definition_valid()
		and definition.resource_path == "res://assets/ships/zenith_b7_observed.tres"
		and definition.get_ship_id() == ZENITH_SHIP_ID
		and zenith.get_ship_id() == ZENITH_SHIP_ID
		and zenith.get_home_berth_id() == ZENITH_BERTH_ID,
		"Zenith runtime identity matches its valid checked-in definition and Fleet Dock berth"
	)
	_check(
		definition != null
		and definition.get_evidence_status_id() == &"provisional"
		and not definition.is_authenticated()
		and str(evidence.get("evidence_status", &"")) == "b7_observed_partial"
		and str(evidence.get("evidence_scope", &"")) == "B7_frames_373_467_only",
		"production Zenith preserves the bounded provisional B7 evidence scope"
	)
	_check(
		definition != null and definition.audio_profile_id == &"standard_fighter"
		and zenith.get_ship_audio_rig().get_profile_id() == &"standard_fighter",
		"definition and live audio rig agree on the immutable standard_fighter profile"
	)
	_check(
		not bool(evidence.get("authenticated_historical_geometry", true))
		and not bool(evidence.get("historical_handling_claim", true))
		and definition != null and "No historical handling claim" in definition.evidence_notes,
		"neither the modern geometry nor handling is promoted to an historical claim"
	)

	var combat_profile := authority.call(
		"get_weapon_profile", zenith, GameFlow.COMBAT_WEAPON_ID
	) as Dictionary
	_check(
		combat_profile.size() == 3
		and is_equal_approx(float(combat_profile.get("range", -1.0)), 390.0)
		and is_equal_approx(float(combat_profile.get("damage", -1.0)), 27.0)
		and is_equal_approx(float(combat_profile.get("origin_tolerance", -1.0)), 24.0),
		"live combat authority owns the exact modern Zenith pulse profile"
	)


func _test_comb_assignment_and_initial_lease(
	world: ShipyardWorld,
	zenith: ZenithInterceptor,
	berth: ShipBerth,
	feedback: ShipBerthFeedback
	) -> void:
	var integration := world.get_fleet_dock_comb_integration_audit_report()
	var module := world.get_fleet_dock_comb()
	var assigned := module.get_assigned_dock_roster() if module != null else []
	_check(
		bool(integration.get("valid", false))
		and int(integration.get("schema_version", 0)) == 2
		and int(integration.get("external_assignment_count", 0)) == 1
		and int(integration.get("deferred_empty_dock_count", 0)) == 2,
		"Fleet Dock integration audit keeps one external assignment and two deferred docks"
	)
	_check(
		assigned.size() == 1
		and assigned[0].get("dock_id", &"") == &"assigned-dock-01"
		and assigned[0].get("ship_assignment", &"") == ZENITH_SHIP_ID
		and assigned[0].get("berth_id", &"") == ZENITH_BERTH_ID
		and not bool(assigned[0].get("owns_berth_authority", true))
		and not bool(assigned[0].get("historical_class_to_berth_mapping", true))
		and not bool(integration.get("historical_class_to_berth_mapping", true)),
		"dock 01 records a modern non-authoritative assignment with no historical class-to-berth claim"
	)
	var marker_transform := (
		assigned[0].get("marker_transform", Transform3D.IDENTITY) as Transform3D
		if assigned.size() == 1
		else Transform3D.IDENTITY
	)
	_check(
		berth != null and berth.get_parent() == world
		and berth.global_transform.is_equal_approx(EXPECTED_DOCK_TRANSFORM)
		and berth.global_position.is_equal_approx(marker_transform.origin + Vector3.UP * 0.93)
		and zenith.global_transform.is_equal_approx(berth.get_dock_transform()),
		"world-owned Zenith berth aligns exactly above the comb marker and owns the parked transform"
	)
	_check(
		berth != null
		and berth.get_reservation_owner() == zenith
		and berth.get_occupant() == zenith
		and berth.get_reserved_ship_id() == ZENITH_SHIP_ID
		and not berth.get_reservation_token(zenith).is_empty(),
		"Zenith begins with one occupied authoritative home-berth lease"
	)
	var feedback_evidence := feedback.get_evidence_metadata() if feedback != null else {}
	_check(
		feedback != null and feedback.get_parent() == berth
		and feedback.get_feedback_state() == ShipBerthFeedback.STATE_OCCUPIED
		and bool(feedback.get_audit_report().get("valid", false))
		and not bool(feedback_evidence.get("authenticated_original_docking_feedback", true)),
		"modern presentation-only berth feedback mirrors the occupied lease without claiming original feedback"
	)


func _test_live_docked_collision_clearance(
	world: ShipyardWorld,
	zenith: ZenithInterceptor,
	berth: ShipBerth
	) -> void:
	var module := world.get_fleet_dock_comb()
	var slab_body := (
		module.find_child("DockSlab01", true, false) as StaticBody3D
		if module != null
		else null
	)
	var slab_collision := (
		slab_body.get_node_or_null(^"Collision") as CollisionShape3D
		if slab_body != null
		else null
	)
	var slab_box := (
		slab_collision.shape as BoxShape3D
		if slab_collision != null
		else null
	)
	var slab_top_world := -INF
	if slab_collision != null and slab_box != null and not slab_collision.disabled:
		var slab_half_size := slab_box.size * 0.5
		for x_sign in [-1.0, 1.0]:
			for y_sign in [-1.0, 1.0]:
				for z_sign in [-1.0, 1.0]:
					var slab_corner := Vector3(
						slab_half_size.x * x_sign,
						slab_half_size.y * y_sign,
						slab_half_size.z * z_sign
					)
					slab_top_world = maxf(
						slab_top_world,
						(slab_collision.global_transform * slab_corner).y
					)
	_check(
		slab_body != null
		and slab_body.get_meta("surface_id", &"") == &"dock-slab-01"
		and slab_box != null
		and slab_box.size.is_equal_approx(Vector3(12.0, 0.6, 15.0))
		and is_equal_approx(slab_top_world, 4.2),
		"assigned dock 01 exposes its exact live walkable slab top at world Y 4.2"
	)

	var collision_report := zenith.get_landing_collision_report()
	var local_bounds := collision_report.get("local_bounds", AABB()) as AABB
	var runtime_collision := zenith.get_zenith_collision_contract_report()
	var shape_type_counts := runtime_collision.get("shape_type_counts", {}) as Dictionary
	_check(
		bool(runtime_collision.get("valid", false))
		and str(runtime_collision.get("oracle_id", "")) == "zenith_b7_runtime_24_mixed_v2"
		and int(runtime_collision.get("shape_count", 0)) == 24
		and int(shape_type_counts.get(&"ConvexPolygonShape3D", 0)) == 18
		and int(shape_type_counts.get(&"CylinderShape3D", 0)) == 3
		and int(shape_type_counts.get(&"BoxShape3D", 0)) == 3,
		"live collision authority uses the exact V2 roster of eighteen convex, three cylinder and three box shapes"
	)
	var complete_hull_minimum_y := INF
	for x_ratio in [0.0, 1.0]:
		for y_ratio in [0.0, 1.0]:
			for z_ratio in [0.0, 1.0]:
				var local_corner := local_bounds.position + local_bounds.size * Vector3(
					x_ratio, y_ratio, z_ratio
				)
				complete_hull_minimum_y = minf(
					complete_hull_minimum_y,
					(zenith.global_transform * local_corner).y
				)
	var complete_hull_clearance := complete_hull_minimum_y - slab_top_world
	_check(
		is_equal_approx(complete_hull_minimum_y, 4.23)
		and is_equal_approx(complete_hull_clearance, 0.03),
		"complete mixed-shape hull retains the exact 30 mm clearance above dock 01"
	)
	_check(
		berth != null
		and bool(collision_report.get("valid", false))
		and int(collision_report.get("shape_count", 0)) == 24
		and berth.contains_oriented_bounds(berth.get_dock_transform(), local_bounds, 0.05),
		"raised dock transform preserves strict twenty-four-shape landing containment"
	)
	_check(
		berth != null
		and berth.get_occupant() == zenith
		and berth.get_reservation_owner() == zenith
		and berth.get_reserved_ship_id() == ZENITH_SHIP_ID,
		"raised dock transform preserves the live occupied Zenith berth lease"
	)


func _test_collision_backed_access(world: ShipyardWorld, zenith: ZenithInterceptor) -> void:
	var module := world.get_fleet_dock_comb()
	var route_samples := PackedVector3Array([
		Vector3(-0.15, 4.2, 68.3),
		Vector3(3.0, 4.2, 68.3),
		Vector3(6.0, 4.2, 68.3),
		Vector3(9.0, 4.2, 68.3),
		Vector3(11.8, 4.2, 68.3),
		module.to_global(Vector3(0.0, 0.0, 0.35)),
		module.to_global(Vector3(0.0, 0.0, 4.0)),
		Vector3(14.15, 4.2, 54.15),
	])
	var route_supported := true
	var maximum_surface_error := 0.0
	for sample in route_samples:
		var hit := await _ray(
			world, sample + Vector3.UP * 2.5, sample + Vector3.DOWN * 2.5
		)
		route_supported = route_supported and not hit.is_empty()
		if not hit.is_empty():
			maximum_surface_error = maxf(
				maximum_surface_error,
				absf((hit.get("position", Vector3.INF) as Vector3).y - 4.2)
			)
	_check(
		route_supported and maximum_surface_error <= 0.02,
		"Aft upper deck, visible connector, comb trunk and dock 01 form one flush collision-backed route"
	)
	_check(
		zenith.to_local(zenith.get_exit_transform().origin).distance_to(EXPECTED_EXIT_LOCAL) <= 0.002
		and zenith.get_exit_transform().origin.distance_to(EXPECTED_EXIT_WORLD) <= 0.002,
		"the live ExitPoint preserves its exact authored local and docked world transforms"
	)
	var exit_support := await _ray(
		world,
		Vector3(EXPECTED_EXIT_WORLD.x, 6.7, EXPECTED_EXIT_WORLD.z),
		Vector3(EXPECTED_EXIT_WORLD.x, 2.2, EXPECTED_EXIT_WORLD.z)
	)
	_check(
		not exit_support.is_empty()
		and absf((exit_support.get("position", Vector3.INF) as Vector3).y - 4.2) <= 0.02,
		"dock 01 physically supports the exact Zenith disembark projection"
	)


func _test_physical_sortie(
	game: GameFlow,
	player: PlayerController,
	world: ShipyardWorld,
	torrent: HeroShip,
	zenith: ZenithInterceptor,
	opponent: CharacterBody3D,
	authority: Node,
	berth: ShipBerth,
	feedback: ShipBerthFeedback
	) -> void:
	var targets := _get_live_range_targets(world)
	var health_before: Dictionary = {}
	for target in targets:
		health_before[target.get_instance_id()] = float(target.get_meta("health", -1.0))
	var target_count_before := world.get_target_count()
	var destroyed_before := world.get_destroyed_target_count()

	game.canopy_motion_time = 0.02
	game.boarding_motion_time = 0.04
	game.disembarking_motion_time = 0.04
	game.start_shift()
	await process_frame
	_check(game.phase == GameFlow.Phase.APPROACH_SHIP, "shift begins on foot with the Torrent guide pending")

	# Stage at the aft end of dock 01's exterior port-edge lane, then cover the
	# final four metres through the production PlayerController. Acquisition must
	# come from real W locomotion; only the starting fixture is positioned here.
	# The destination stays dynamic so this does not freeze the component's
	# evidence-reviewed local boarding-marker coordinate.
	var boarding_target := (
		zenith.get_boarding_position() + zenith.global_basis.y.normalized() * 0.05
	)
	var approach_start := boarding_target + zenith.global_basis.z.normalized() * 4.2
	var approach_direction := (boarding_target - approach_start).slide(Vector3.UP).normalized()
	player.teleport_to(Transform3D(
		Basis.looking_at(approach_direction, Vector3.UP).orthonormalized(),
		approach_start
	))
	for _grounding_tick in 8:
		await physics_frame
	var grounded_walk_origin := player.global_position
	var previous_walk_position := grounded_walk_origin
	var stationary_ticks := 0
	var walk_stalled := false
	Input.action_press(&"move_forward")
	for approach_tick in 90:
		await physics_frame
		await process_frame
		var remaining := _horizontal_distance(player.global_position, boarding_target)
		if remaining <= 0.45:
			break
		var step_distance := _horizontal_distance(
			player.global_position, previous_walk_position
		)
		if approach_tick > 10 and step_distance < 0.005:
			stationary_ticks += 1
		else:
			stationary_ticks = 0
		if stationary_ticks >= 18:
			walk_stalled = true
			break
		previous_walk_position = player.global_position
	Input.action_release(&"move_forward")
	for _approach_settle in 10:
		await physics_frame
		await process_frame
	var walked_distance := _horizontal_distance(
		grounded_walk_origin, player.global_position
	)
	var boarding_distance := _horizontal_distance(
		player.global_position, boarding_target
	)
	_check(
		walked_distance > 3.5 and boarding_distance < 0.8,
		"real W locomotion traverses dock 01's exterior lane and reaches the dynamic boarding point"
	)
	_check(
		not walk_stalled and stationary_ticks < 18,
		"production collision permits the exterior Zenith approach without an invisible-wall stall"
	)
	_check(
		player.is_on_floor(),
		"physical boarding approach remains grounded on dock 01 collision"
	)
	for _refresh in 5:
		await physics_frame
		await process_frame
	_check(
		game.boarding_candidate == zenith,
		"physical proximity to the collision-backed dock selects Zenith's real boarding area"
	)
	await _press_live_action(&"interact", 1)
	_check(
		await _wait_for_phase(game, GameFlow.Phase.START_ENGINES, 0.8),
		"live E interaction completes Zenith boarding through GameFlow"
	)
	_check(
		game.get_active_ship() == zenith and player.is_seated() and zenith.is_piloted(),
		"the same production player occupies Zenith's physical pilot seat"
	)
	_check(
		not game.is_guided_activity_complete() and game.get_guided_ship() == torrent
		and not bool(opponent.call("is_active")),
		"Zenith boarding preserves the dormant pending Torrent guide"
	)

	zenith.engine_start_time = 0.03
	_dispatch_pilot_action(game, &"engine_start")
	_check(await _wait_for_engine_state(zenith, "ONLINE", 0.4), "live Y action starts Zenith's real engine lifecycle")
	_check(await _wait_for_phase(game, GameFlow.Phase.FREE_FLIGHT, 0.4), "Zenith startup enters unrestricted free flight")
	_check(
		berth.get_occupant() == zenith and berth.get_reservation_owner() == zenith,
		"engine startup alone retains the occupied Fleet Dock lease"
	)

	var fired_events: Array[Dictionary] = []
	zenith.projectile_fired.connect(func(origin: Vector3, direction: Vector3) -> void:
		fired_events.append({"origin": origin, "direction": direction})
	)
	zenith.weapon_cooldown = 0.02
	await _press_live_action(&"fire", 2)
	await process_frame
	var protected_result := game.get_last_player_shot_result()
	_check(
		not fired_events.is_empty(),
		"live fire input emits at least one real Zenith projectile event"
	)
	_check(
		protected_result.get("status", &"") == &"guided_range_reserved"
		and protected_result.get("source_entity") == zenith
		and int(protected_result.get("source_id", 0)) == 1104,
		"combat authority protects the pending guided range while retaining Zenith source 1104"
	)
	_check(
		world.get_target_count() == target_count_before
		and world.get_destroyed_target_count() == destroyed_before
		and _targets_match_health(targets, health_before),
		"protected Zenith fire cannot damage, remove or credit any Torrent range contact"
	)

	var departure_origin := zenith.global_position
	var departure_forward := -zenith.global_basis.z.normalized()
	Input.action_press(&"move_forward")
	for _departure_tick in 24:
		await physics_frame
		await process_frame
	Input.action_release(&"move_forward")
	for _settle in 3:
		await physics_frame
		await process_frame
	var departure_offset := zenith.global_position - departure_origin
	_check(
		departure_offset.length() > 0.05
		and departure_offset.normalized().dot(departure_forward) > 0.85
		and not bool(zenith.get_telemetry().get("landed", true)),
		"real W thrust moves Zenith nose-first and clears its landed latch"
	)
	_check(
		berth.get_occupant() == null and berth.get_reservation_owner() == null
		and feedback.get_feedback_state() == ShipBerthFeedback.STATE_RELEASED,
		"physical departure releases the authoritative home lease and feedback follows it"
	)

	# Stage a realistic nose-first return from one side of the broad capture box.
	# The craft points toward the dock with nonzero pitch and nearly opposite berth
	# yaw; unrestricted heading acquisition must accept it and align at staging.
	var return_origin := EXPECTED_DOCK_TRANSFORM.origin + Vector3(8.0, 9.0, -19.0)
	var nose_to_dock := (EXPECTED_DOCK_TRANSFORM.origin - return_origin).normalized()
	var return_basis := Basis.looking_at(nose_to_dock, Vector3.UP).orthonormalized()
	zenith.global_transform = Transform3D(return_basis, return_origin)
	zenith.velocity = nose_to_dock * 8.0
	await physics_frame
	var capture := world.get_landing_assist_report(zenith, ZENITH_BERTH_ID)
	_check(
		bool(capture.get("valid", false))
		and bool(capture.get("assist_capture_accepted", false))
		and bool(capture.get("heading_unrestricted", false))
		and float(capture.get("heading_error_degrees", 0.0)) > 120.0
		and (capture.get("capture_local_root_offset", Vector3.ZERO) as Vector3).x > 7.5,
		"broad assist accepts a moving, pitched, off-axis natural nose-first return despite opposite berth yaw"
	)
	_dispatch_pilot_action(game, &"landing_assist")
	await physics_frame
	var active_contract := zenith.get_landing_contract_report()
	_check(
		bool(active_contract.get("active", false))
		and bool(active_contract.get("contract_accepted", false))
		and bool(active_contract.get("strict_dock_acceptance", false))
		and active_contract.get("berth_id", &"") == ZENITH_BERTH_ID,
		"live L action binds the broad capture to Zenith's exact strict dock contract"
	)
	_check(
		await _wait_for_phase(game, GameFlow.Phase.SHUT_DOWN, 12.0),
		"landing assist completes the collision-aware Fleet Dock return from the off-axis capture"
	)
	_check(
		bool(zenith.get_telemetry().get("landed", false))
		and zenith.global_transform.is_equal_approx(EXPECTED_DOCK_TRANSFORM)
		and berth.get_occupant() == zenith and berth.get_reservation_owner() == zenith
		and feedback.get_feedback_state() == ShipBerthFeedback.STATE_OCCUPIED,
		"completed return restores the exact dock transform, occupied lease and feedback"
	)

	_dispatch_pilot_action(game, &"engine_stop")
	_check(await _wait_for_engine_state(zenith, "OFFLINE", 0.3), "live X action stops Zenith at the occupied berth")
	var exit_target := zenith.get_exit_transform().origin
	_dispatch_pilot_action(game, &"interact")
	_check(
		await _wait_for_phase(game, GameFlow.Phase.APPROACH_SHIP, 0.8),
		"live E action completes Zenith disembarkation"
	)
	for _exit_settle in 4:
		await physics_frame
	_check(
		not player.is_seated() and player.is_control_enabled()
		and not zenith.is_piloted() and zenith.is_boardable()
		and player.global_position.distance_to(exit_target) < 0.8,
		"the same player returns to on-foot control at the exact supported ExitPoint"
	)
	_check(
		not game.is_guided_activity_complete() and game.get_guided_ship() == torrent
		and world.get_target_count() == target_count_before
		and _targets_match_health(targets, health_before),
		"complete Zenith sortie leaves the Torrent guide and every range contact untouched"
	)

	var game_id := game.get_instance_id()
	var player_id := player.get_instance_id()
	var zenith_id := zenith.get_instance_id()
	var berth_id := berth.get_instance_id()
	var feedback_id := feedback.get_instance_id()
	var presentation_id := zenith.get_zenith_authored_presentation().get_instance_id()
	var identity_before := zenith.get_zenith_runtime_identity_report().current as Dictionary
	root.remove_child(game)
	await process_frame
	root.add_child(game)
	await process_frame
	await physics_frame
	_check(
		game.get_instance_id() == game_id and player.get_instance_id() == player_id
		and zenith.get_instance_id() == zenith_id and berth.get_instance_id() == berth_id
		and feedback.get_instance_id() == feedback_id
		and zenith.get_zenith_authored_presentation().get_instance_id() == presentation_id,
		"whole-Main detach/re-entry preserves world, player, Zenith, berth, feedback and authored-art identities"
	)
	_check(
		game.get_flyable_ships().size() == 4
		and int(authority.call("get_source_id", zenith)) == 1104
		and (zenith.get_zenith_runtime_identity_report().current as Dictionary) == identity_before
		and bool(zenith.get_zenith_runtime_identity_report().stable)
		and bool(zenith.get_zenith_audit_report().get("valid", false))
		and bool(world.get_fleet_dock_comb_integration_audit_report().get("valid", false)),
		"re-entry retains the four-craft registry, source 1104 and all Zenith/Fleet Dock audits without rebuilding"
	)


func _get_live_range_targets(world: Node) -> Array[StaticBody3D]:
	var targets: Array[StaticBody3D] = []
	for candidate in world.find_children("*", "StaticBody3D", true, false):
		if candidate.get_meta("is_shipyard_target", false):
			targets.append(candidate as StaticBody3D)
	return targets


func _targets_match_health(
	targets: Array[StaticBody3D],
	expected_health: Dictionary
	) -> bool:
	for target in targets:
		if not is_instance_valid(target) or bool(target.get_meta("destroyed", false)):
			return false
		if not is_equal_approx(
			float(target.get_meta("health", -2.0)),
			float(expected_health.get(target.get_instance_id(), -1.0))
		):
			return false
	return true


func _horizontal_distance(first: Vector3, second: Vector3) -> float:
	return Vector2(first.x - second.x, first.z - second.z).length()


func _ray(world: Node3D, from: Vector3, to: Vector3) -> Dictionary:
	await physics_frame
	var query := PhysicsRayQueryParameters3D.create(from, to, PhysicsLayers.WORLD)
	query.collide_with_areas = false
	query.collide_with_bodies = true
	return world.get_world_3d().direct_space_state.intersect_ray(query)


func _press_live_action(action: StringName, physics_ticks: int) -> void:
	Input.action_press(action)
	for _tick in maxi(1, physics_ticks):
		await physics_frame
	Input.action_release(action)
	await physics_frame


func _dispatch_pilot_action(game: GameFlow, action: StringName) -> void:
	var event := InputEventAction.new()
	event.action = action
	event.pressed = true
	game._unhandled_input(event)


func _wait_for_phase(game: GameFlow, expected_phase: int, timeout_seconds: float) -> bool:
	return await _wait_until(
		func() -> bool: return game.phase == expected_phase,
		timeout_seconds
	)


func _wait_for_engine_state(
	ship: HeroShip,
	expected_state: String,
	timeout_seconds: float
	) -> bool:
	return await _wait_until(
		func() -> bool:
			return str(ship.get_telemetry().get("engine_state", &"")).to_upper() == expected_state,
		timeout_seconds
	)


## Waits for `predicate` on both the simulation clock and the monotonic clock,
## giving up only once both budgets are spent.
##
## Phase transitions and engine spin-up are advanced by `GameFlow` and
## `HeroShip` from their frame callbacks. Under load Godot drops physics steps
## rather than letting the simulation spiral while the wall clock keeps running,
## so a `Time.get_ticks_msec()`-only deadline ends the wait after far fewer
## simulated steps than the transition needs and scores a perfectly healthy
## sequence as a failure. `timeout_seconds` is kept as the *nominal* duration and
## becomes both a frame budget and a wall-clock deadline; both stay finite, so a
## genuinely stuck transition still fails the suite.
func _wait_until(predicate: Callable, timeout_seconds: float) -> bool:
	var frame_budget := (
		int(ceil(maxf(timeout_seconds, 0.0) * float(Engine.physics_ticks_per_second)))
		+ FRAME_BUDGET_GRACE
	)
	var deadline := Time.get_ticks_msec() + int(ceil(maxf(timeout_seconds, 0.0) * 1000.0))
	var frames := 0
	while not bool(predicate.call()):
		if frames >= frame_budget and Time.get_ticks_msec() >= deadline:
			return false
		await physics_frame
		await process_frame
		frames += 1
	return true


func _clean_up(game: Node) -> void:
	for action in [
		&"interact", &"move_forward", &"move_back", &"move_left", &"move_right",
		&"fire", &"engine_start", &"engine_stop", &"landing_assist",
	]:
		Input.action_release(action)
	await _release_combat_audio_before_main_teardown(game)
	game.queue_free()
	await process_frame
	await physics_frame
	await process_frame


func _release_combat_audio_before_main_teardown(game: Node) -> void:
	var combat_audio := game.get_node_or_null("CombatAudioPresentation") as CombatAudioPresentation
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
	_assertion_count += 1
	if condition:
		print("PASS: ", description)
	else:
		_failures.append(description)
		push_error("FAIL: " + description)


func _finish() -> void:
	if _failures.is_empty():
		print("ZENITH_FLEET_DOCK_INTEGRATION_TEST_OK: %d assertions" % _assertion_count)
		quit(0)
	else:
		print(
			"ZENITH_FLEET_DOCK_INTEGRATION_TEST_FAILED: %d/%d assertions failed: %s"
			% [_failures.size(), _assertion_count, "; ".join(_failures)]
		)
		quit(1)
