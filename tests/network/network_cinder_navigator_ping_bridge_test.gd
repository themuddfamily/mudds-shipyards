extends SceneTree

const Bridge := preload("res://scripts/network/network_cinder_navigator_ping_bridge.gd")
const Adapter := preload("res://scripts/network/network_enet_session_adapter.gd")
const Cinder := preload("res://scripts/ships/cinder_cargo_hauler.gd")
const Authority := preload("res://scripts/ships/crew_seat_role_authority.gd")

var _assertions := 0
var _failures := PackedStringArray()


func _init() -> void:
	call_deferred(&"_run")


func _run() -> void:
	var adapter := Adapter.new()
	root.add_child(adapter)
	var hosted := adapter.host(29207, 1)
	_check(bool(hosted.get("accepted", false)), "the real network session starts for navigator publication")
	var rotated: Dictionary = adapter._migration.rotate_server(1)
	_check(bool(rotated.get("accepted", false)) and int(rotated.get("migration_generation", 0)) == 2, "the authoritative network session advances its migration generation")

	var cinder := Cinder.new()
	root.add_child(cinder)
	await process_frame
	await physics_frame
	var authority := Authority.new(1)
	for record in [
		[&"cinder_pilot", Authority.ROLE_PILOT],
		[&"cinder_gunner", Authority.ROLE_GUNNER],
		[&"cinder_engineer", Authority.ROLE_ENGINEER],
		[Cinder.LOADMASTER_STATION_SEAT_ID, Authority.ROLE_PASSENGER],
		[Cinder.NAVIGATOR_STATION_SEAT_ID, Authority.ROLE_PASSENGER],
	]:
		_check(
			bool(authority.register_seat(
				StringName(record[0]),
				Cinder.COMPONENT_ID,
				StringName(record[1]),
				&"cinder_cargo_walkable_interior",
				1,
				StringName(record[0])
			).get("accepted", false)),
			"the real Cinder navigator roster seat registers"
		)
	_check(bool(authority.seal_roster().get("accepted", false)), "the navigator authority roster seals")
	_check(bool(cinder.attach_crew_role_authority(authority).get("accepted", false)), "the real Cinder authority attaches")

	var actor := CharacterBody3D.new()
	root.add_child(actor)
	var interaction := cinder.get_navigator_interaction()
	actor.global_position = interaction.global_position
	var physical_claim := interaction.try_claim(actor, 1, 62, &"navigator_avatar", 1)
	_check(bool(physical_claim.get("accepted", false)), "the physical navigator seat admits the network actor")

	var bridge := Bridge.new()
	_check(bool(bridge.attach(adapter, cinder).get("accepted", false)), "bridge attaches one session and the real Cinder")
	var accepted := bridge.submit_ping(
		62,
		3,
		&"navigator_avatar",
		1,
		2,
		{"channel": &"sensor", "marker_id": &"route_beacon"},
		12,
		2
	)
	_check(bool(accepted.get("accepted", false)), "bridge publishes the accepted navigator ping")
	var wire_receipt := accepted.get("wire_receipt", {}) as Dictionary
	_check(
		StringName(wire_receipt.get("seat_id", &"")) == Cinder.NAVIGATOR_STATION_SEAT_ID
		and StringName(wire_receipt.get("role", &"")) == Authority.ROLE_PASSENGER
			and int(wire_receipt.get("seat_generation", 0)) == 1
			and int(wire_receipt.get("peer_id", 0)) == 62
			and int(wire_receipt.get("server_tick", 0)) == 12
			and int(wire_receipt.get("migration_generation", 0)) == 2,
		"publication carries exact navigator actor and generation identity"
	)
	_check(bool((accepted.get("publication", {}) as Dictionary).get("accepted", false)), "network session accepts the detached crew snapshot")
	var accepted_snapshot := cinder.get_navigator_ping_snapshot()
	var inactive_adapter := Adapter.new()
	root.add_child(inactive_adapter)
	var inactive_bridge := Bridge.new()
	_check(bool(inactive_bridge.attach(inactive_adapter, cinder).get("accepted", false)), "bridge can attach before a production session chooses its lifecycle mode")
	_check(inactive_bridge.submit_ping(62, 3, &"navigator_avatar", 1, 3, {"channel": &"sensor", "marker_id": &"client_mutation"}, 13, 2).get("status", &"") == &"server_authority_required", "an inactive/client adapter is rejected before Cinder mutation")
	_check(cinder.get_navigator_ping_snapshot() == accepted_snapshot, "the rejected non-server path leaves the authoritative Cinder receipt unchanged")
	inactive_bridge.detach()
	inactive_adapter.queue_free()
	_check(bridge.submit_ping(62, 3, &"navigator_avatar", 1, 2, {}, 13, 2).get("status", &"") == &"stale_request_sequence", "replayed navigator request is rejected")
	_check(bridge.submit_ping(62, 3, &"navigator_avatar", 1, 3, {}, 13, 1).get("status", &"") == &"stale_migration_generation", "stale migration generation is rejected")
	_check(bridge.submit_ping(62, 2, &"navigator_avatar", 1, 3, {}, 13, 2).get("status", &"") == &"stale_peer_generation", "stale network generation is rejected")
	_check(bridge.submit_ping(62, 3, &"wrong_avatar", 1, 3, {}, 13, 2).get("status", &"") == &"navigator_identity_mismatch", "foreign navigator actor is rejected")
	var released_peer := bridge.release_peer(62)
	_check(bool(released_peer.get("tombstone_publication", {}).get("accepted", false)) and int(released_peer.get("tombstone_count", 0)) == 1, "peer release publishes a bounded navigator clear tombstone")
	var release_tombstones := released_peer.get("tombstones", []) as Array
	var release_tombstone := (release_tombstones[0] as Dictionary).get("receipt", {}) as Dictionary
	_check(
		StringName(release_tombstone.get("action", &"")) == &"passenger_ping_clear"
			and int(release_tombstone.get("request_sequence", 0)) == 3
			and int(release_tombstone.get("migration_generation", 0)) == 2,
		"peer release tombstone is generation-fenced and advances the receipt sequence"
	)

	_check(bridge.submit_ping(62, 3, &"navigator_avatar", 1, 3, {}, 14, 2).get("status", &"") == &"cinder_rejected", "peer release still respects the Cinder authority sequence")
	bridge.detach()
	_check(bridge.submit_ping(62, 3, &"navigator_avatar", 1, 3, {}, 14, 2).get("status", &"") == &"detached", "detach closes navigator publication")
	_check(bool(bridge.attach(adapter, cinder).get("accepted", false)), "re-entry reattaches the bridge without stale bridge cursors")
	_check(bridge.submit_ping(62, 3, &"navigator_avatar", 1, 2, {}, 14, 2).get("status", &"") == &"cinder_rejected", "re-entry still respects the Cinder authority sequence")
	var reentry := bridge.submit_ping(
		62,
		3,
		&"navigator_avatar",
		1,
		3,
		{"channel": &"sensor", "marker_id": &"fresh_beacon"},
		15,
		2
	)
	_check(bool(reentry.get("accepted", false)), "fresh post-reentry sequence publishes")
	var detached := bridge.detach()
	_check(bool(detached.get("tombstone_publication", {}).get("accepted", false)) and int(detached.get("tombstone_count", 0)) == 1, "bridge detach publishes a generation-fenced navigator clear tombstone")
	var detach_tombstones := detached.get("tombstones", []) as Array
	var detach_tombstone := (detach_tombstones[0] as Dictionary).get("receipt", {}) as Dictionary
	_check(
		StringName(detach_tombstone.get("action", &"")) == &"passenger_ping_clear"
			and int(detach_tombstone.get("request_sequence", 0)) == 4
			and int(detach_tombstone.get("migration_generation", 0)) == 2,
		"detach tombstone is generation-fenced and advances the receipt sequence"
	)
	_check(bridge.submit_ping(62, 3, &"navigator_avatar", 1, 4, {}, 16, 2).get("status", &"") == &"detached", "detach closes navigator publication")
	var released := interaction.release(actor, 1, 62, &"navigator_avatar", 4)
	_check(bool(released.get("accepted", false)), "physical navigator actor releases cleanly")
	_check(authority.get_assignment(62, &"navigator_avatar").is_empty(), "release clears the shared navigator assignment")

	actor.queue_free()
	cinder.queue_free()
	adapter.shutdown(&"test_complete")
	adapter.queue_free()
	await process_frame
	if _failures.is_empty():
		print("CINDER_NAVIGATOR_PING_BRIDGE_TEST_OK: %d checks" % _assertions)
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)


func _check(condition: bool, description: String) -> void:
	_assertions += 1
	if not condition:
		_failures.append("FAIL: " + description)
