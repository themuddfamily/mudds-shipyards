extends SceneTree

const Adapter := preload("res://scripts/network/network_enet_session_adapter.gd")
const Codec := preload("res://scripts/network/network_crew_snapshot_codec.gd")
const Fragmenter := preload("res://scripts/network/network_snapshot_fragmenter.gd")

var _assertions := 0
var _failures := PackedStringArray()


func _init() -> void:
	call_deferred(&"_run")


func _run() -> void:
	var adapter := Adapter.new()
	root.add_child(adapter)
	var hosted := adapter.host(29123, 1)
	_check(hosted.accepted, "server session is configured for crew publication")
	var published := adapter.publish_crew_snapshot()
	_check(published.accepted and published.status == &"crew_snapshot_published",
		"server publishes detached crew snapshot through transport seam")
	_check(int(published.get("entry_count", -1)) == 0 and adapter.get_crew_replica_snapshot().is_empty(),
		"server publication does not mutate client presentation state")
	var documents: Dictionary = _test_real_server_rotation(adapter)
	adapter.shutdown(&"test_complete")
	_check(adapter.get_crew_replica_snapshot().is_empty(), "shutdown clears crew replica state")
	var roles := {
		"7:pilot": {"peer_id": 7, "ship_id": &"ship_7"},
		"8:gunner": {"peer_id": 8, "ship_id": &"ship_8"},
		"9:engineer": {"peer_id": 9, "ship_id": &"ship_7"},
	}
	var receipts: Array = [
		{"receipt": {"peer_id": 8, "ship_id": &"ship_8"}},
		{"receipt": {"peer_id": 9, "ship_id": &"ship_7"}},
	]
	var filtered := adapter._crew_snapshot_for_peer(7, {"roles": roles}, receipts)
	_check(filtered.roles.roles.size() == 2 and filtered.receipts.size() == 1
		and filtered.receipts[0].receipt.ship_id == &"ship_7",
		"publication filter keeps only recipient ship state")
	adapter.free()
	_test_injected_receive(documents)
	if _failures.is_empty():
		print("OK: ENet crew snapshot integration (%d assertions)" % _assertions)
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)


func _test_real_server_rotation(adapter: NetworkEnetSessionAdapter) -> Dictionary:
	# Seed the adapter's actual detached authorities; rotation itself uses the
	# hosted server entry point. The two-peer physical route proves real delivery.
	var seats: NetworkSeatAuthority = adapter.get("_seat_authority") as NetworkSeatAuthority
	var roles: NetworkCrewRoleAuthority = adapter.get("_crew_roles") as NetworkCrewRoleAuthority
	_check(seats.register_seat(&"navigator_seat", &"ship_7", &"passenger", &"frame_7", 2).accepted
		and seats.claim(1, 7, &"avatar_7", &"navigator_seat", &"passenger", 1).accepted
		and roles.admit_peer(1, 7, 4).accepted, "real authority fixture establishes seated admitted crew")
	_check(adapter.accept_crew_role_intent(7, 4, &"avatar_7", &"passenger", 10).accepted,
		"prior epoch has an accepted role and request cursor")
	var old_receipts: Array = []
	for sequence in range(10, 14):
		var command: Dictionary = adapter.accept_crew_command(7, 4, &"avatar_7", &"ping", sequence, 100,
			{"marker_id": &"route_hint"})
		_check(command.accepted, "prior epoch fills the actual per-tick command budget")
		old_receipts.append(command.get("receipt", {}))
	var role_before: Dictionary = adapter.get_crew_role_snapshot()
	var command_before: Dictionary = adapter.get_crew_command_snapshot()
	var assignment_before: Dictionary = adapter.get_crew_assignment(7, &"avatar_7")
	var codec: NetworkCrewSnapshotCodec = Codec.new()
	var old_encoded: Dictionary = codec.encode(role_before, command_before, old_receipts)
	_check(old_encoded.accepted and role_before.migration_generation == 1
		and command_before.tracked_stream_count == 1 and command_before.tracked_tick_count == 1,
		"prior epoch document contains seeded role and command state")
	var refused: Dictionary = adapter.rotate_session_migration(1)
	_check(not refused.accepted and refused.status == &"invalid_package_generation"
		and adapter.get_crew_role_snapshot() == role_before
		and adapter.get_crew_command_snapshot() == command_before,
		"refused real server rotation preserves both crew authorities exactly")
	var completion_states: Array[Dictionary] = []
	adapter.migration_result.connect(func(result: Dictionary) -> void:
		if bool(result.get("accepted", false)):
			completion_states.append({"roles": adapter.get_crew_role_snapshot(),
				"commands": adapter.get_crew_command_snapshot()})
	)
	var rotated: Dictionary = adapter.rotate_session_migration()
	var role_after: Dictionary = adapter.get_crew_role_snapshot()
	var command_after: Dictionary = adapter.get_crew_command_snapshot()
	_check(rotated.accepted and rotated.migration_generation == 2
		and role_after.migration_generation == 2 and command_after.migration_generation == 2,
		"accepted real server rotation advances both crew authorities to its epoch")
	_check(role_after.role_count == 0 and role_after.admitted_peer_count == 1
		and command_after.tracked_stream_count == 0 and command_after.tracked_tick_count == 0
		and adapter.get_crew_assignment(7, &"avatar_7") == assignment_before,
		"rotation retires old role and command cursors while preserving peer admission and physical seat owner")
	_check(completion_states.size() == 1 and completion_states[0].roles == role_after
		and completion_states[0].commands == command_after,
		"both crew authority resets precede migration completion emission")
	var new_role: Dictionary = adapter.accept_crew_role_intent(7, 4, &"avatar_7", &"passenger", 1)
	_check(new_role.accepted and int((new_role.get("role", {}) as Dictionary).get("migration_generation", 0)) == 2,
		"new role uses the new epoch and restarts its retired request cursor")
	var new_receipts: Array = []
	for sequence in range(1, 5):
		var command: Dictionary = adapter.accept_crew_command(7, 4, &"avatar_7", &"ping", sequence, 100,
			{"marker_id": &"route_hint"})
		_check(command.accepted and int((command.get("receipt", {}) as Dictionary).get("migration_generation", 0)) == 2,
			"new commands restart sequence and same-tick budget in the new epoch")
		new_receipts.append(command.get("receipt", {}))
	var encoded: Dictionary = codec.encode(adapter.get_crew_role_snapshot(), adapter.get_crew_command_snapshot(), new_receipts)
	var decoded: Dictionary = codec.decode(encoded.get("bytes", PackedByteArray()))
	var snapshot: Dictionary = decoded.get("snapshot", {}) as Dictionary
	_check(encoded.accepted and decoded.accepted and int(snapshot.get("migration_generation", 0)) == 2
		and (snapshot.get("roles", []) as Array).size() == 1
		and (snapshot.get("commands", []) as Array).size() == 4,
		"actual new authority state encodes a new-epoch document without relabeling old records")
	var published: Dictionary = adapter.publish_crew_snapshot(new_receipts)
	_check(published.accepted and published.generation == 2 and published.entry_count == 5,
		"actual server publishes the newly accepted crew state in the current epoch")
	return {"old": old_encoded.get("bytes", PackedByteArray()), "current": encoded.get("bytes", PackedByteArray())}


func _test_injected_receive(documents: Dictionary) -> void:
	# Focused injected fragments isolate the receive fence. These are not the
	# authenticated two-peer route or proof of production transport delivery.
	var client: NetworkEnetSessionAdapter = Adapter.new()
	root.add_child(client)
	client._adopt_client_migration_epoch(1, {"package_generation": 1,
		"session_generation": 2, "migration_generation": 2})
	var applied: Array[Dictionary] = []
	client.crew_snapshot_applied.connect(func(result: Dictionary) -> void: applied.append(result.duplicate(true)))
	_inject_document(client, documents.current, 1)
	var baseline: Dictionary = client.get_crew_replica_snapshot()
	_check(applied.size() == 1 and applied[0].accepted and int(baseline.get("migration_generation", 0)) == 2,
		"focused injected matching-epoch document establishes a replica baseline")
	_inject_document(client, documents.old, 2)
	_check(applied.size() == 2 and not applied[1].accepted and applied[1].status == &"stale_crew_snapshot"
		and client.get_crew_replica_snapshot() == baseline and int(client.get("_crew_snapshot_revision")) == 1,
		"focused injected current fragment with stale inner epoch rejects before replica or revision commit")
	_inject_document(client, documents.current, 3)
	_check(applied.size() == 3 and applied[2].accepted and int(client.get("_crew_snapshot_revision")) == 3
		and client.get_crew_replica_snapshot() == baseline,
		"focused injected matching-epoch positive control still commits after stale document rejection")
	client.free()


func _inject_document(client: NetworkEnetSessionAdapter, encoded: PackedByteArray, revision: int) -> void:
	var fragmenter: NetworkSnapshotFragmenter = Fragmenter.new()
	for fragment in fragmenter.fragment({"crew_snapshot": encoded.get_string_from_utf8()}, 2, revision):
		client._broadcast_crew_snapshot_fragment(fragment as Dictionary)


func _check(condition: bool, description: String) -> void:
	_assertions += 1
	if not condition:
		_failures.append("FAIL: " + description)
