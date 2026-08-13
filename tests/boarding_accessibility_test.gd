extends SceneTree

## Production regression for forgiving walk-up boarding. The larger ship-owned
## discovery volume must reach a collision-clear approach without becoming a
## through-hull shortcut, while GameFlow always chooses the nearest seat that is
## genuinely available to this player.

const MAIN_SCENE := preload("res://scenes/main.tscn")
const BOARDING_RADIUS_METRES := 4.5
const PLAYER_INTERACTION_RADIUS_METRES := 2.35
const FALLBACK_REACH_METRES := 7.0
const TEST_ALTITUDE := 80.0
const COLLISION_CLEARANCE_METRES := 0.12

var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var game := MAIN_SCENE.instantiate() as GameFlow
	_check(game != null, "production Main scene instantiates for boarding accessibility")
	if game == null:
		_finish()
		return
	root.add_child(game)
	await process_frame
	await _physics_frames(3)

	var player := game.get_node_or_null("Player") as CharacterBody3D
	var torrent := game.get_node_or_null("TorrentInterceptor") as HeroShip
	var arrow := game.get_node_or_null("ArrowReconShip") as HeroShip
	var jovian := game.get_node_or_null("JovianLightFreighter") as HeroShip
	var fleet: Array[HeroShip] = game.get_flyable_ships()
	_check(
		player != null and torrent != null and arrow != null and jovian != null,
		"production player and complete three-craft fleet resolve"
	)
	_check(fleet.size() == 3, "accessibility fixture covers all three production spacecraft")
	if player == null or torrent == null or arrow == null or jovian == null or fleet.size() != 3:
		game.queue_free()
		await process_frame
		_finish()
		return

	# Freeze gameplay motion while retaining live PhysicsServer overlap discovery.
	game.set_process(false)
	game.set_physics_process(false)
	player.set_process(false)
	player.set_physics_process(false)
	for craft in fleet:
		craft.set_process(false)
		craft.set_physics_process(false)

	_test_exact_radius_contract(player, fleet)
	await _test_arrow_collision_clear_approach(game, player, fleet, arrow)
	await _test_torrent_opposite_side_rejection(game, player, fleet, torrent)
	await _test_nearest_eligible_choice(game, player, fleet, torrent, arrow, jovian)
	await _test_unavailable_and_reserved_exclusion(game, player, fleet, torrent, arrow)
	await _test_exact_fallback_reach(game, player, fleet, arrow)
	await _test_reboard_block(game, player, fleet, arrow)

	game.queue_free()
	await process_frame
	await process_frame
	await process_frame
	_finish()


func _test_exact_radius_contract(player: CharacterBody3D, fleet: Array[HeroShip]) -> void:
	for craft in fleet:
		var area := _get_boarding_area(craft)
		var shape := area.get_node_or_null("BoardingRange") as CollisionShape3D if area != null else null
		_check(area != null, "%s retains its ship-owned boarding area" % craft.name)
		_check(
			shape != null
			and shape.shape is SphereShape3D
			and is_equal_approx((shape.shape as SphereShape3D).radius, BOARDING_RADIUS_METRES),
			"%s inherits the exact 4.5-metre craft-side radius" % craft.name
		)
	var player_shape := player.get_node_or_null(
		"InteractionArea/InteractionShape"
	) as CollisionShape3D
	_check(
		player_shape != null
		and player_shape.shape is SphereShape3D
		and is_equal_approx(
			(player_shape.shape as SphereShape3D).radius,
			PLAYER_INTERACTION_RADIUS_METRES
		),
		"production Player interaction sphere remains exactly 2.35 metres"
	)


func _test_arrow_collision_clear_approach(
		game: GameFlow,
		player: CharacterBody3D,
		fleet: Array[HeroShip],
		arrow: HeroShip
	) -> void:
	_park_fleet_far(fleet)
	arrow.global_transform = Transform3D(Basis.IDENTITY, Vector3(0.0, TEST_ALTITUDE, 0.0))
	var port_extent := _fleet_side_extent(arrow, false)
	var capsule_radius := _player_capsule_radius(player)
	var boarding_local := arrow.to_local(arrow.get_boarding_position())
	var approach_local := Vector3(
		port_extent - capsule_radius - COLLISION_CLEARANCE_METRES,
		boarding_local.y,
		boarding_local.z
	)
	_place_player_interaction_origin(player, arrow.to_global(approach_local))
	await _physics_frames(3)

	_check(
		approach_local.x + capsule_radius < port_extent,
		"Arrow approach leaves the production player capsule collision-clear of its broad wing"
	)
	_check(
		player.get_interaction_origin().distance_to(arrow.get_boarding_position()) < FALLBACK_REACH_METRES,
		"Arrow's widened access reaches the collision-clear port approach"
	)
	_check(
		_find_candidate(game) == arrow,
		"collision-clear Arrow approach exposes the physical recon-ship seat"
	)


func _test_torrent_opposite_side_rejection(
		game: GameFlow,
		player: CharacterBody3D,
		fleet: Array[HeroShip],
		torrent: HeroShip
	) -> void:
	_park_fleet_far(fleet)
	torrent.global_transform = Transform3D(Basis.IDENTITY, Vector3(0.0, TEST_ALTITUDE, 0.0))
	var capsule_radius := _player_capsule_radius(player)
	var boarding_local := torrent.to_local(torrent.get_boarding_position())
	var port_extent := _fleet_side_extent(torrent, false)
	var starboard_extent := _fleet_side_extent(torrent, true)

	var correct_approach := Vector3(
		port_extent - capsule_radius - COLLISION_CLEARANCE_METRES,
		boarding_local.y,
		boarding_local.z
	)
	_place_player_interaction_origin(player, torrent.to_global(correct_approach))
	await _physics_frames(3)
	_check(
		_find_candidate(game) == torrent,
		"Torrent remains accessible from its collision-clear port boarding side"
	)

	var opposite_approach := Vector3(
		starboard_extent + capsule_radius + COLLISION_CLEARANCE_METRES,
		boarding_local.y,
		boarding_local.z
	)
	_place_player_interaction_origin(player, torrent.to_global(opposite_approach))
	await _physics_frames(3)
	_check(
		opposite_approach.x - capsule_radius > starboard_extent,
		"Torrent opposite-side sample is collision-clear rather than embedded in the hull"
	)
	_check(
		player.get_interaction_origin().distance_to(torrent.get_boarding_position()) > FALLBACK_REACH_METRES,
		"collision-clear opposite side lies beyond the bounded 7-metre boarding reach"
	)
	_check(
		_find_candidate(game) == null,
		"Torrent cannot be boarded through the hull from its wrong/opposite side"
	)


func _test_nearest_eligible_choice(
		game: GameFlow,
		player: CharacterBody3D,
		fleet: Array[HeroShip],
		torrent: HeroShip,
		arrow: HeroShip,
		jovian: HeroShip
	) -> void:
	var origin := Vector3(0.0, TEST_ALTITUDE, 0.0)
	_place_player_interaction_origin(player, origin)
	# Torrent is registered first, but Arrow is physically closest. Jovian is
	# also in the widened overlap so this proves a three-way spatial choice.
	_place_boarding_point(torrent, origin + Vector3(5.2, 0.0, 0.0))
	_place_boarding_point(arrow, origin + Vector3(3.1, 0.0, 0.0))
	_place_boarding_point(jovian, origin + Vector3(6.1, 0.0, 0.0))
	await _physics_frames(3)
	_check(
		player.get_nearby_interactables().has(_get_boarding_area(torrent))
		and player.get_nearby_interactables().has(_get_boarding_area(arrow))
		and player.get_nearby_interactables().has(_get_boarding_area(jovian)),
		"all three production boarding areas overlap during nearest-choice regression"
	)
	_check(
		_find_candidate(game) == arrow,
		"nearest eligible spacecraft wins independently of fleet registration order"
	)


func _test_unavailable_and_reserved_exclusion(
		game: GameFlow,
		player: CharacterBody3D,
		fleet: Array[HeroShip],
		torrent: HeroShip,
		arrow: HeroShip
	) -> void:
	var origin := Vector3(0.0, TEST_ALTITUDE, 0.0)
	_place_player_interaction_origin(player, origin)
	_park_fleet_far(fleet)
	_place_boarding_point(arrow, origin + Vector3(2.4, 0.0, 0.0))
	_place_boarding_point(torrent, origin + Vector3(4.0, 0.0, 0.0))
	var arrow_area := _get_boarding_area(arrow)

	arrow_area.set_boarding_enabled(false)
	await _physics_frames(3)
	_check(
		_find_candidate(game) == torrent,
		"disabled nearer area is excluded instead of being recovered by distance fallback"
	)
	arrow_area.set_boarding_enabled(true)
	await _physics_frames(3)

	var other_pilot := Node.new()
	other_pilot.name = "OtherBoardingPilot"
	game.add_child(other_pilot)
	_check(arrow_area.try_reserve(other_pilot), "nearer Arrow seat accepts another pilot's reservation")
	_check(
		_find_candidate(game) == torrent,
		"another pilot's nearer reservation is excluded in favour of the next eligible craft"
	)
	_check(arrow_area.release_reservation(other_pilot), "reservation fixture releases the nearer Arrow seat")
	other_pilot.queue_free()
	await process_frame
	_check(_find_candidate(game) == arrow, "released nearer seat immediately regains nearest priority")


func _test_exact_fallback_reach(
		game: GameFlow,
		player: CharacterBody3D,
		fleet: Array[HeroShip],
		arrow: HeroShip
	) -> void:
	var origin := Vector3(0.0, TEST_ALTITUDE, 0.0)
	_place_player_interaction_origin(player, origin)
	_park_fleet_far(fleet)
	var area := _get_boarding_area(arrow)

	_place_boarding_point(arrow, origin + Vector3(FALLBACK_REACH_METRES, 0.0, 0.0))
	await _physics_frames(3)
	_check(
		not player.get_nearby_interactables().has(area),
		"exact 7-metre sample lies beyond combined physics overlap and exercises fallback"
	)
	_check(_find_candidate(game) == arrow, "fallback reach includes exactly 7.0 metres")

	_place_boarding_point(arrow, origin + Vector3(FALLBACK_REACH_METRES + 0.01, 0.0, 0.0))
	await _physics_frames(3)
	_check(_find_candidate(game) == null, "fallback reach rejects 7.01 metres")

	_place_boarding_point(arrow, origin + Vector3(FALLBACK_REACH_METRES - 0.05, 0.0, 0.0))
	area.set_boarding_enabled(false)
	await _physics_frames(3)
	_check(_find_candidate(game) == null, "fallback cannot bypass a disabled area inside 7 metres")
	area.set_boarding_enabled(true)
	await _physics_frames(3)
	var other_pilot := Node.new()
	other_pilot.name = "FallbackReservationPilot"
	game.add_child(other_pilot)
	_check(area.try_reserve(other_pilot), "fallback fixture reserves the out-of-overlap seat")
	_check(_find_candidate(game) == null, "fallback cannot bypass another pilot's reservation")
	_check(area.release_reservation(other_pilot), "fallback reservation releases cleanly")
	other_pilot.queue_free()
	await process_frame
	_check(_find_candidate(game) == arrow, "available seat inside 7 metres is restored through fallback")


func _test_reboard_block(
		game: GameFlow,
		player: CharacterBody3D,
		fleet: Array[HeroShip],
		arrow: HeroShip
	) -> void:
	var origin := Vector3(0.0, TEST_ALTITUDE, 0.0)
	_place_player_interaction_origin(player, origin)
	_park_fleet_far(fleet)
	_place_boarding_point(arrow, origin + Vector3(2.0, 0.0, 0.0))
	await _physics_frames(3)
	game.set("_reboard_blocked_ship", arrow)
	_check(_find_candidate(game) == null, "wider radius preserves immediate same-ship reboard suppression")
	game.set("_reboard_blocked_ship", null)
	_check(_find_candidate(game) == arrow, "clearing the reboard latch restores the nearby ship")


func _park_fleet_far(fleet: Array[HeroShip]) -> void:
	for index in fleet.size():
		_place_boarding_point(
			fleet[index],
			Vector3(120.0 + float(index) * 40.0, TEST_ALTITUDE, 80.0)
		)


func _place_boarding_point(craft: HeroShip, target: Vector3) -> void:
	craft.global_transform = Transform3D(Basis.IDENTITY, Vector3.ZERO)
	craft.global_position += target - craft.get_boarding_position()
	craft.reset_physics_interpolation()


func _place_player_interaction_origin(player: CharacterBody3D, target: Vector3) -> void:
	player.teleport_to(Transform3D.IDENTITY)
	player.global_position += target - player.get_interaction_origin()
	player.reset_physics_interpolation()


func _get_boarding_area(craft: HeroShip) -> ShipBoardingArea:
	return craft.get_node_or_null("ShipBoardingArea") as ShipBoardingArea


func _find_candidate(game: GameFlow) -> HeroShip:
	return game.call("_find_boarding_candidate") as HeroShip


func _player_capsule_radius(player: CharacterBody3D) -> float:
	var collision := player.get_node_or_null("PlayerCollision") as CollisionShape3D
	if collision == null or collision.shape is not CapsuleShape3D:
		return 0.0
	return (collision.shape as CapsuleShape3D).radius


func _fleet_side_extent(craft: HeroShip, starboard: bool) -> float:
	var extent := -INF if starboard else INF
	for child in craft.get_children():
		if child is not CollisionShape3D:
			continue
		var collision := child as CollisionShape3D
		if collision.disabled or collision.shape is not BoxShape3D:
			continue
		var half_width := (collision.shape as BoxShape3D).size.x * 0.5
		if starboard:
			extent = maxf(extent, collision.position.x + half_width)
		else:
			extent = minf(extent, collision.position.x - half_width)
	return extent


func _physics_frames(count: int) -> void:
	for _index in count:
		await physics_frame


func _check(condition: bool, description: String) -> void:
	if condition:
		print("PASS: ", description)
	else:
		_failures.append(description)
		push_error("FAIL: " + description)


func _finish() -> void:
	if _failures.is_empty():
		print("BOARDING_ACCESSIBILITY_TEST_OK")
		quit(0)
	else:
		print("BOARDING_ACCESSIBILITY_TEST_FAILED: ", ", ".join(_failures))
		quit(1)
