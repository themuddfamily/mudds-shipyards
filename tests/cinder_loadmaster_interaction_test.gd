extends SceneTree

## Focused embodied interaction contract: public ShipBoardingArea discovery and
## the reachable loadmaster Area3D both delegate identity/generation/occupancy
## to CrewSeatRoleAuthority without taking input, cargo or flight authority.

const Hauler := preload("res://scripts/ships/cinder_cargo_hauler.gd")
const Authority := preload("res://scripts/ships/crew_seat_role_authority.gd")
const PlayerScene := preload("res://scenes/player/player.tscn")

# Discovery-only fixture: represent the client's existing admission readback,
# never request a seat or mutate a role, flight or input authority.
class CabinSelectionFlow:
	extends GameFlow
	var client_live := true

	func _network_client_boarding_is_live() -> bool:
		return client_live

var _assertions := 0
var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var craft := Hauler.new() as CinderCargoHauler
	root.add_child(craft)
	await process_frame
	await physics_frame

	var boarding := craft.get_node_or_null(^"ShipBoardingArea") as ShipBoardingArea
	_check(boarding != null, "Cinder exposes the shared public ShipBoardingArea")
	_check(boarding != null and boarding.get_ship() == craft, "boarding resolves its physical Cinder owner")
	_check(boarding != null and boarding.is_available(), "the boarding aperture is available through the public flow")
	_check(boarding != null and boarding.get_prompt().contains("BOARD CINDER"), "boarding publishes the authored Cinder prompt")

	var interaction := craft.get_loadmaster_interaction()
	_check(interaction != null, "the loadmaster station exposes a ship-owned Area3D interaction")
	_check(interaction != null and interaction.get_seat_id() == Hauler.LOADMASTER_STATION_SEAT_ID, "the interaction names the exact physical seat")
	_check(interaction != null and interaction.get_seat_generation() == 1, "the interaction publishes the current seat generation")
	_check(interaction != null and interaction.get_node_or_null(^"InteractionShape") is CollisionShape3D, "the station interaction has a physical range shape")

	var authority := Authority.new(1)
	for seat_record in [
		[&"cinder_pilot", Authority.ROLE_PILOT],
		[&"cinder_gunner", Authority.ROLE_GUNNER],
		[&"cinder_engineer", Authority.ROLE_ENGINEER],
		[Hauler.LOADMASTER_STATION_SEAT_ID, Authority.ROLE_PASSENGER],
	]:
		var seat_id := StringName(seat_record[0])
		var role := StringName(seat_record[1])
		_check(
			bool(authority.register_seat(
				seat_id,
				Hauler.COMPONENT_ID,
				role,
				&"cinder_cargo_walkable_interior",
				1,
				seat_id
			).get("accepted", false)),
			"the authority registers Cinder %s" % role
		)
	_check(bool(authority.seal_roster().get("accepted", false)), "the authority roster seals")
	_check(bool(craft.attach_crew_role_authority(authority).get("accepted", false)), "the station binds to the injected authority")

	var actor := CharacterBody3D.new()
	actor.name = "CinderLoadmasterActor"
	root.add_child(actor)
	actor.global_position = interaction.global_position + Vector3(0.0, 0.0, 2.0)
	var out_of_range := interaction.try_claim(actor, 1, 73, &"interaction_loadmaster", 1)
	_check(not bool(out_of_range.get("accepted", true)) and out_of_range.get("status", &"") == &"interaction_out_of_range", "the station rejects an out-of-range actor")
	actor.global_position = interaction.global_position
	craft.get_loadmaster_station_anchor().set_meta(&"seat_generation", 2)
	var stale_generation := interaction.try_claim(actor, 1, 73, &"interaction_loadmaster", 1)
	_check(
		not bool(stale_generation.get("accepted", true))
			and stale_generation.get("status", &"") == &"stale_seat_generation",
		"a generation-one interaction cannot claim a generation-two seat"
	)
	craft.get_loadmaster_station_anchor().set_meta(&"seat_generation", 1)
	var claimed := interaction.try_claim(actor, 1, 73, &"interaction_loadmaster", 1)
	_check(bool(claimed.get("accepted", false)), "the in-range station interaction delegates an atomic authority claim")
	_check(
		StringName((authority.get_assignment(73, &"interaction_loadmaster")).get("seat_id", &"")) == Hauler.LOADMASTER_STATION_SEAT_ID,
		"the claim records the exact Cinder seat in the shared ledger"
	)
	_check(not interaction.is_available(), "the station interaction closes while its authority assignment is occupied")
	var wrong_actor := CharacterBody3D.new()
	root.add_child(wrong_actor)
	var wrong_release := interaction.release(wrong_actor, 1, 73, &"interaction_loadmaster", 2)
	_check(not bool(wrong_release.get("accepted", true)), "a different actor cannot release the station")

	var reset := craft.reset_for_reuse(Transform3D(Basis.IDENTITY, Vector3(8.0, 0.0, -4.0)))
	_check(bool(reset.get("accepted", false)), "Cinder reset completes through the existing lifecycle")
	_check(authority.get_assignment(73, &"interaction_loadmaster").is_empty(), "reset releases the physical authority assignment")
	_check(interaction.is_available(), "reset leaves a clean re-entry interaction")
	_check(boarding.is_available(), "reset leaves the public boarding area available")
	var fresh_actor := CharacterBody3D.new()
	fresh_actor.name = "CinderLoadmasterFreshActor"
	root.add_child(fresh_actor)
	fresh_actor.global_position = interaction.global_position
	var fresh_claim := interaction.try_claim(fresh_actor, 1, 74, &"interaction_loadmaster_fresh", 1)
	_check(bool(fresh_claim.get("accepted", false)), "a fresh generation can claim after reset cleanup")
	var released := interaction.release(fresh_actor, 1, 74, &"interaction_loadmaster_fresh", 2)
	_check(bool(released.get("accepted", false)), "the fresh owner releases through the interaction seam")
	_check(interaction.is_available(), "release reopens the station interaction")
	_check(authority.get_assignment(74, &"interaction_loadmaster_fresh").is_empty(), "release removes the fresh authority assignment exactly once")
	await _test_cabin_cockpit_selection(craft)

	wrong_actor.queue_free()
	actor.queue_free()
	fresh_actor.queue_free()
	craft.queue_free()
	await process_frame
	await _test_landed_host_halyard_cockpit_selection()
	if _failures.is_empty():
		print("CINDER_LOADMASTER_INTERACTION_TEST_OK: %d checks" % _assertions)
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _test_cabin_cockpit_selection(craft: CinderCargoHauler) -> void:
	var player := PlayerScene.instantiate() as PlayerController
	root.add_child(player)
	await process_frame
	player.set_process(false)
	player.set_physics_process(false)
	craft.set_process(false)
	craft.set_physics_process(false)
	var seat := craft.get_loadmaster_station_anchor().get_node("SoloPassengerSeatInteraction") as ShipCrewSeat
	var game := CabinSelectionFlow.new()
	game.player = player
	game.ships.append(craft)
	game.phase = GameFlow.Phase.IN_FLIGHT_CABIN
	game.set("_cabin_ship", craft)
	game.set("_network_client_boarding_claim", {"ship_id": craft.get_ship_id(), "role": &"passenger"})
	# This is the supported overlapping approach from the failed ordinary route.
	# Use the real discovery spheres and authored anchors, not injected candidates.
	player.teleport_to(craft.global_transform * Transform3D(Basis.IDENTITY, Vector3(-0.60, -0.97, 0.60)))
	await physics_frame
	await physics_frame
	var pilot := craft.get_pilot_seat_anchor()
	var camera := player.get_camera()
	camera.global_basis = Basis.looking_at(pilot.global_position - player.get_interaction_origin(), craft.global_basis.y.normalized())
	_check(player.get_nearby_interactables().has(seat) and game._network_client_near_pilot_seat(craft) and game._find_boarding_candidate() == craft, "real Cinder discovery overlaps the loadmaster chair and in-reach cockpit on the admitted cabin craft")
	var owner_before := craft.get_crew_role_authority().get_snapshot()
	game.client_live = false
	_check(game._find_station_interaction_candidate() == seat, "the original nearby crew-chair selection remains outside the admitted client cabin flow")
	game.client_live = true
	_check(game._find_station_interaction_candidate() == null, "aiming at the real Cinder cockpit lets ordinary boarding selection reach the existing pilot swap")
	camera.global_basis = Basis.looking_at(seat.global_position - player.get_interaction_origin(), craft.global_basis.y.normalized())
	_check(game._find_station_interaction_candidate() == seat, "aiming at the real overlapping loadmaster chair retains its ordinary SIT interaction")
	camera.global_basis = Basis.looking_at(pilot.global_position - player.get_interaction_origin(), craft.global_basis.y.normalized())
	game.phase = GameFlow.Phase.APPROACH_SHIP
	_check(game._find_station_interaction_candidate() == seat, "cockpit comparison does not alter exterior station selection")
	game.phase = GameFlow.Phase.IN_FLIGHT_CABIN
	game.set("_network_client_boarding_claim", {})
	_check(game._find_station_interaction_candidate() == seat, "unclaimed cabin discovery cannot take precedence over the valid chair")
	game.set("_network_client_boarding_claim", {"ship_id": &"other_craft", "role": &"passenger"})
	_check(game._find_station_interaction_candidate() == seat, "another craft's admission cannot select this cockpit")
	game.set("_network_client_boarding_claim", {"ship_id": craft.get_ship_id(), "role": &"passenger"})
	var area := craft.get_node("ShipBoardingArea") as ShipBoardingArea
	area.boarding_enabled = false
	_check(game._find_station_interaction_candidate() == seat, "disabled ordinary boarding discovery keeps the chair rather than bypassing the cockpit gate")
	area.boarding_enabled = true
	player.teleport_to(craft.global_transform * Transform3D(Basis.IDENTITY, Vector3(-2.40, -0.97, 1.40)))
	camera.global_basis = Basis.looking_at(pilot.global_position - player.get_interaction_origin(), craft.global_basis.y.normalized())
	_check(not game._cabin_cockpit_precedes_crew_seat(seat, player.get_interaction_origin(), player.get_interaction_direction()), "cockpit selection preserves the existing planar pilot-seat reach")
	_check(craft.get_crew_role_authority().get_snapshot() == owner_before and not craft.is_piloted(), "aim discovery leaves the real role ledger and pilot authority unchanged")
	game.free()
	player.queue_free()
	await process_frame


func _test_landed_host_halyard_cockpit_selection() -> void:
	var game := preload("res://scenes/main.tscn").instantiate() as GameFlow
	var store_path := "user://host-cockpit-selection-%d.json" % OS.get_process_id()
	var store := UserDataStore.new(store_path)
	store.load()
	game.configure_runtime_settings_persistence(store)
	root.add_child(game)
	await process_frame
	game.start_shift()
	var craft := game.get_node("HalyardCrewTransport") as HalyardCrewTransport
	var player := game.player as PlayerController
	var pilot := craft.get_pilot_seat_anchor()
	var seat := craft.get_gunner_station_anchor().get_node("SoloGunnerSeatInteraction") as ShipCrewSeat
	_check(game.host_network_session(43000 + OS.get_process_id() % 10000).accepted, "landed cockpit discovery uses an actual production server adapter")
	craft.set_canopy_open(true, 0.0)
	player.teleport_to(Transform3D(craft.global_basis, pilot.global_position + craft.global_basis * Vector3(-0.6, 0.0, 0.6)))
	for tick in range(20):
		await physics_frame
	var frame := craft.get_in_flight_cabin_report().get("frame") as MovingInteriorFrame
	var camera := player.get_camera()
	camera.global_basis = Basis.looking_at(pilot.global_position - player.get_interaction_origin(), craft.global_basis.y.normalized())
	_check(game.phase == GameFlow.Phase.APPROACH_SHIP and player.is_on_floor() and frame.is_occupant_registered(player) and frame.contains_world_position(player.global_position) and player.get_nearby_interactables().has(seat), "real landed Halyard frame registers the on-foot cockpit approach and overlapping gunner interaction")
	var ledger_before := game.network_session.get_boarding_snapshot()
	_check(game._find_station_interaction_candidate() == null, "actual host aiming at landed Halyard pilot reaches ordinary boarding instead of nearby gunner")
	camera.global_basis = Basis.looking_at(seat.global_position - player.get_interaction_origin(), craft.global_basis.y.normalized())
	_check(game._find_station_interaction_candidate() == seat, "actual host aiming at gunner retains the gunner chair")
	camera.global_basis = Basis.looking_at(pilot.global_position - player.get_interaction_origin(), craft.global_basis.y.normalized())
	var area := craft.get_node("ShipBoardingArea") as ShipBoardingArea
	_check(area.try_reserve(seat), "another physical contender reserves the boarding area")
	_check(game._find_station_interaction_candidate() == seat, "an occupied boarding reservation cannot receive pilot aim priority")
	area.release_reservation(seat)
	craft.set_piloted(true)
	_check(game._find_station_interaction_candidate() == seat, "occupied pilot availability keeps ordinary chair discovery without seating the host")
	craft.set_piloted(false)
	frame.unregister_occupant(player)
	_check(game._find_station_interaction_candidate() == seat, "an unregistered exterior body cannot suppress the nearby chair")
	_check(game.network_session.get_boarding_snapshot() == ledger_before and not game._piloting and not player.is_seated(), "discovery does not acquire pilot ledger, posture or authority")
	game.shutdown_network_session(&"host_cockpit_selection_done")
	game.release_mouse_capture()
	game.queue_free()
	await process_frame
	DirAccess.remove_absolute(store_path)


func _check(condition: bool, message: String) -> void:
	_assertions += 1
	if not condition:
		_failures.append(message)
