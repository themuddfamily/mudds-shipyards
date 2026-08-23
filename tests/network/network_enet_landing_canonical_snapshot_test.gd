extends SceneTree

## Focused adapter composition for standalone server landing publications ->
## canonical authoritative snapshots. No ENet peer or gameplay node is created;
## landing/berth mutation remains in NetworkLandingAuthority.

const Adapter := preload("res://scripts/network/network_enet_session_adapter.gd")
const LifecycleAdapter := preload("res://scripts/network/network_snapshot_lifecycle_adapter.gd")

var _assertions := 0
var _failures := PackedStringArray()


func _init() -> void:
	call_deferred(&"_run")


func _run() -> void:
	var server := Adapter.new()
	root.add_child(server)
	server._is_server = true
	server._configured = true
	_check(server.register_landing_entity(1, &"landing_ship", 1).accepted,
		"server registers the landing entity generation")
	_check(server.register_landing_target(&"berth_alpha", &"shipyard", 1).accepted,
		"server registers the berth target")
	var reserved := server.reserve_server_landing(
		&"landing_ship", 1, &"shipyard", &"berth_alpha", 0, 0, 1
	)
	var lease_id := StringName(server.get_landing_entity(&"landing_ship").get("lease_id", &""))
	_check(reserved.accepted and not lease_id.is_empty(),
		"server authority reserves the first approach")
	var pending := server.publish_landing_snapshot(
		&"landing_ship", 1, Vector3(4.0, 0.0, 2.0), &"landing_pending", [], 1
	)
	var canonical_pending := server.publish_snapshot(1, [], [], [])
	var pending_record := _landing_record(canonical_pending.get("packet", {}), &"landing_ship")
	_check(
		pending.accepted and canonical_pending.accepted
		and int(canonical_pending.packet.authority_peer_id) == 1
		and int(canonical_pending.packet.revision) == 1
		and int(pending_record.landing_revision) == 1
		and pending_record.state == &"landing_pending",
		"standalone approach publication enters the canonical authority envelope"
	)
	var replica := LifecycleAdapter.new(1, 1, 1, 1)
	_check(replica.apply_replica_snapshot(1, canonical_pending.packet).accepted
		and replica.get_authoritative_snapshot().sections.landing[0].state == &"landing_pending",
		"a fresh replica receives the canonical pending record for late presentation")
	var aborted := server.abort_server_landing(&"landing_ship", 1, lease_id)
	var flying := server.publish_landing_snapshot(
		&"landing_ship", 1, Vector3(5.0, 0.0, 2.0), &"flying", [], 2
	)
	var canonical_abort := server.publish_snapshot(2, [], [], [])
	_check(
		aborted.accepted and flying.accepted and canonical_abort.accepted
		and _landing_record(canonical_abort.packet, &"landing_ship").state == &"flying"
		and int(_landing_record(canonical_abort.packet, &"landing_ship").landing_revision) == 2,
		"abort advances the canonical record back to flying"
	)
	_check(replica.apply_replica_snapshot(1, canonical_abort.packet).accepted
		and replica.apply_replica_snapshot(1, canonical_pending.packet).status == &"stale_snapshot",
		"replica rejects a reordered pre-abort canonical envelope")
	var reserved_again := server.reserve_server_landing(
		&"landing_ship", 1, &"shipyard", &"berth_alpha", 0, 1, 3
	)
	lease_id = StringName(server.get_landing_entity(&"landing_ship").get("lease_id", &""))
	_check(reserved_again.accepted and not lease_id.is_empty(),
		"server reserves a later approach after abort")
	server.publish_landing_snapshot(
		&"landing_ship", 1, Vector3(6.0, 0.0, 2.0), &"landing_pending", [], 3
	)
	var committed := server.commit_server_landing(&"landing_ship", 1, lease_id)
	var landed := server.publish_landing_snapshot(
		&"landing_ship", 1, Vector3(6.0, 0.0, 2.0), &"landed", [], 4
	)
	var canonical_landed := server.publish_snapshot(3, [], [], [])
	_check(
		committed.accepted and landed.accepted and canonical_landed.accepted
		and _landing_record(canonical_landed.packet, &"landing_ship").state == &"landed",
		"committed berth occupancy reaches the canonical snapshot"
	)
	var released := server.release_server_landing(&"landing_ship", 1, lease_id)
	var released_flying := server.publish_landing_snapshot(
		&"landing_ship", 2, Vector3(8.0, 0.0, 2.0), &"flying", [], 5
	)
	var canonical_release := server.publish_snapshot(4, [], [], [])
	var release_record := _landing_record(canonical_release.packet, &"landing_ship")
	_check(
		released.accepted and int(released.entity_generation) == 2
		and released_flying.accepted and canonical_release.accepted
		and int(release_record.entity_generation) == 2
		and int(release_record.landing_revision) == 5
		and release_record.state == &"flying",
		"release advances entity generation before publishing canonical flying state"
	)
	var uncommitted := server.publish_landing_snapshot(
		&"landing_ship", 2, Vector3.ZERO, &"landed", [], 6
	)
	var canonical_unchanged := server.publish_snapshot(5, [], [], [])
	_check(
		uncommitted.status == &"landing_state_not_committed"
		and _landing_record(canonical_unchanged.packet, &"landing_ship").state == &"flying"
		and int(_landing_record(canonical_unchanged.packet, &"landing_ship").landing_revision) == 5,
		"adapter cannot promote a landing state not committed by server authority"
	)
	var late_replica := LifecycleAdapter.new(1, 1, 1, 1)
	_check(late_replica.apply_replica_snapshot(1, canonical_release.packet).accepted
		and int(late_replica.get_authoritative_snapshot().sections.landing[0].entity_generation) == 2,
		"late replica receives the released generation without replaying berth mutation")
	var client := Adapter.new()
	root.add_child(client)
	client._configured = true
	_check(client.publish_snapshot(1, [], [], []).status == &"authority_required"
		and client.commit_server_landing(&"landing_ship", 2, lease_id).status == &"authority_required",
		"presentation replicas cannot publish or commit landing authority")
	client._configured = false
	server._configured = false
	client.queue_free()
	server.queue_free()
	await process_frame
	if _failures.is_empty():
		print("NETWORK_ENET_LANDING_CANONICAL_SNAPSHOT_TEST_OK (%d assertions)" % _assertions)
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)


func _landing_record(packet: Dictionary, entity_id: StringName) -> Dictionary:
	var sections := packet.get("sections", {}) as Dictionary
	for record_variant in sections.get(&"landing", []) as Array:
		var record := record_variant as Dictionary
		if StringName(record.get("entity_id", &"")) == entity_id:
			return record
	return {}


func _check(condition: bool, description: String) -> void:
	_assertions += 1
	if not condition:
		_failures.append("FAIL: " + description)
