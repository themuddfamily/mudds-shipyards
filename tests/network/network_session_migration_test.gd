extends SceneTree

## Focused detached regression for server rotation and reconnect rebind.
## It covers only epoch/attachment fencing; no MultiplayerPeer, production
## scene, physics, renderer, or network soak is run.

const Migration := preload("res://scripts/network/network_session_migration.gd")

var _assertions := 0
var _failures := PackedStringArray()


func _init() -> void:
	call_deferred(&"_run")


func _run() -> void:
	_test_server_owned_registration_and_attachment()
	_test_rotation_and_stale_packet_fences()
	_test_rebind_restores_all_authoritative_attachments()
	_test_disconnect_reconnect_requires_fresh_generation()
	if _failures.is_empty():
		print("OK: network session migration (%d assertions)" % _assertions)
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)


func _new_migration() -> Migration:
	return Migration.new(99, 4, 12, 3, 1)


func _test_server_owned_registration_and_attachment() -> void:
	var migration := _new_migration()
	_check(
		not migration.register_peer(7, 7, 1).accepted,
		"client cannot register a migration peer"
	)
	_check(
		migration.register_peer(99, 7, 1).accepted,
		"server registers the current peer generation"
	)
	_check(
		not migration.register_peer(99, 7, 1).accepted,
		"duplicate peer registration is rejected"
	)
	_check(
		migration.bind_attachment(
			99, 7, 1, &"jovian_pilot", 4, &"jovian_a", 7,
			Vector3(2.0, 0.0, -3.0), 40.0, 6
		).accepted,
		"server binds seat, ship, and interest metadata atomically"
	)
	var packet := migration.make_packet(7, 1, 0)
	_check(
		migration.accept_packet(7, packet).accepted,
		"current packet envelope is accepted for the active peer"
	)
	var snapshot := migration.get_snapshot()
	_check(
		int(snapshot.package_generation) == 12
		and int(snapshot.session_generation) == 3
		and int(snapshot.migration_generation) == 1
		and (snapshot.peers as Array).size() == 1,
		"snapshot exposes one current peer and exact epoch generations"
	)
	_check(
		not migration.bind_attachment(
			7, 7, 1, &"bad", 1, &"jovian_a", 7, Vector3.ZERO, 40.0
		).accepted,
		"client cannot mutate the retained attachment"
	)


func _test_rotation_and_stale_packet_fences() -> void:
	var migration := _new_migration()
	_check(migration.register_peer(99, 7, 1).accepted, "rotation test registers peer")
	_check(
		migration.bind_attachment(99, 7, 1, &"pilot", 1, &"ship", 1, Vector3.ZERO, 20.0).accepted,
		"rotation test seeds an attachment"
	)
	var old_packet := migration.make_packet(7, 1, 1)
	_check(
		not migration.rotate_server(7, 13).accepted,
		"client cannot rotate the authoritative server"
	)
	var rotated := migration.rotate_server(99, 13)
	_check(
		rotated.accepted
		and rotated.status == &"server_rotated"
		and int(rotated.package_generation) == 13
		and int(rotated.session_generation) == 4
		and int(rotated.migration_generation) == 2,
		"server rotation advances package, session, and migration generations"
	)
	_check(
		int((migration.get_peer(7) as Dictionary).get("peer_generation", 0)) == 1
		and not bool((migration.get_peer(7) as Dictionary).get("active", true))
		and bool((migration.get_peer(7) as Dictionary).get("rebind_required", false)),
		"rotation detaches the old transport while retaining its peer generation"
	)
	_check(
		not migration.accept_packet(7, old_packet).accepted
		and migration.get_last_result().status == &"stale_package_generation",
		"old package packets fail before they can mutate stream state"
	)
	var stale_session := old_packet.duplicate(true)
	stale_session["package_generation"] = 13
	_check(
		not migration.accept_packet(7, stale_session).accepted
		and migration.get_last_result().status == &"stale_session_generation",
		"old session packets fail after package compatibility is restored"
	)
	var stale_migration := stale_session.duplicate(true)
	stale_migration["session_generation"] = 4
	_check(
		not migration.accept_packet(7, stale_migration).accepted
		and migration.get_last_result().status == &"stale_migration_generation",
		"old migration packets fail after session compatibility is restored"
	)
	var too_old_package := migration.make_packet(7, 1, 0)
	too_old_package["kind"] = &"rebind"
	_check(
		not migration.rebind_peer(7, too_old_package).accepted
		and migration.get_last_result().status == &"stale_peer_generation",
		"rebind with the retired peer generation cannot resurrect transport state"
	)
	_check(
		not migration.rotate_server(99, 13).accepted,
		"package generation must advance strictly on a repeated rotation"
	)


func _test_rebind_restores_all_authoritative_attachments() -> void:
	var migration := _new_migration()
	_check(migration.register_peer(99, 7, 5).accepted, "rebind test registers peer")
	_check(
		migration.bind_attachment(
			99, 7, 5, &"gunner", 9, &"ship_b", 12,
			Vector3(9.0, 1.0, -4.0), 80.0, 3
		).accepted,
		"rebind test commits generation-bearing attachment metadata"
	)
	_check(migration.rotate_server(99).accepted, "rebind test rotates the server epoch")
	var rebind := migration.make_packet(7, 6, 0, &"rebind")
	var rebound := migration.rebind_peer(7, rebind)
	_check(
		rebound.accepted
		and rebound.status == &"peer_rebound"
		and int(rebound.peer_generation) == 6,
		"new peer generation is accepted for a current epoch rebind"
	)
	var attachment: Dictionary = rebound.attachment
	_check(
		attachment.seat.seat_id == &"gunner"
		and int(attachment.seat.seat_generation) == 9
		and attachment.ship.ship_id == &"ship_b"
		and int(attachment.ship.ship_generation) == 12,
		"rebind receipt restores seat and ship identity generations"
	)
	_check(
		attachment.interest.center == Vector3(9.0, 1.0, -4.0)
		and is_equal_approx(float(attachment.interest.radius), 80.0)
		and int(attachment.interest.max_entities) == 3,
		"rebind receipt restores bounded replication-interest metadata"
	)
	var current := migration.make_packet(7, 6, 1)
	_check(migration.accept_packet(7, current).accepted, "rebound peer accepts the next packet sequence")
	_check(
		not migration.accept_packet(7, current).accepted
		and migration.get_last_result().status == &"stale_packet_sequence",
		"duplicate current packet is rejected without reapplying the attachment"
	)
	var stale_rebind := migration.make_packet(7, 5, 2, &"rebind")
	_check(
		not migration.rebind_peer(7, stale_rebind).accepted
		and migration.get_last_result().status == &"peer_already_active",
		"rebind cannot replace the already-active current generation"
	)
	var detached_copy: Dictionary = migration.get_peer(7)
	(detached_copy.attachment as Dictionary).seat.seat_id = &"mutated"
	_check(
		migration.get_peer(7).attachment.seat.seat_id == &"gunner",
		"peer snapshots remain detached from the migration authority"
	)
	var audit := migration.audit()
	_check(
		bool(audit.server_owns_rotation)
		and bool(audit.server_owns_package_generation)
		and bool(audit.server_owns_session_generation)
		and bool(audit.server_owns_attachment_rebind)
		and bool(audit.stale_packets_rejected)
		and not bool(audit.client_can_mutate_attachment),
		"audit exposes server ownership and stale-packet boundaries"
	)


func _test_disconnect_reconnect_requires_fresh_generation() -> void:
	var migration := _new_migration()
	_check(migration.register_peer(99, 7, 1).accepted, "reconnect fixture registers the original peer")
	_check(
		migration.bind_attachment(99, 7, 1, &"pilot", 2, &"ship", 3, Vector3.ZERO, 25.0).accepted,
		"reconnect fixture retains the authoritative attachment"
	)
	_check(
		migration.disconnect_peer(99, 7, 1).accepted
		and bool(migration.get_peer(7).get("rebind_required", false)),
		"server disconnect marks the old transport for rebind without dropping attachment"
	)
	var stale := migration.make_packet(7, 1, 0, &"rebind")
	_check(
		not migration.rebind_peer(7, stale).accepted
		and migration.get_last_result().status == &"stale_peer_generation",
		"reconnect cannot reuse the retired peer generation"
	)
	var fresh := migration.make_packet(7, 2, 0, &"rebind")
	var rebound := migration.rebind_peer(7, fresh)
	_check(
		rebound.accepted
		and rebound.status == &"peer_rebound"
		and rebound.attachment.ship.ship_id == &"ship",
		"fresh peer generation rebinds the retained ownership attachment"
	)


func _check(condition: bool, description: String) -> void:
	_assertions += 1
	if not condition:
		_failures.append("FAIL: " + description)
