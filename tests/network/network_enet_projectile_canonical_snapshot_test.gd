extends SceneTree

## Focused production composition from the existing server projectile
## replication seam into canonical late-join snapshots. No ENet peer or game
## node is created; projectile mutation remains in NetworkProjectileAuthority.

const Adapter := preload("res://scripts/network/network_enet_session_adapter.gd")
const LifecycleAdapter := preload("res://scripts/network/network_snapshot_lifecycle_adapter.gd")
const ProjectileIntent := preload("res://scripts/network/network_projectile_intent.gd")

var _assertions := 0
var _failures := PackedStringArray()


func _init() -> void:
	call_deferred(&"_run")


func _run() -> void:
	var server := Adapter.new()
	root.add_child(server)
	server._is_server = true
	server._configured = true
	server._peer_generations[2] = 1
	var injected := _canonical_record(&"injected", &"fighter_a", &"active", false, 1, 1)
	var injection_snapshot := server.publish_snapshot(1, [], [injected], [])
	_check(
		injection_snapshot.accepted
		and (injection_snapshot.packet.sections.projectiles as Array).is_empty(),
		"canonical publication ignores projectile arrays that bypass server admission"
	)
	_check(server.register_projectile_source(
		2, &"fighter_a", 3, &"allied", {
			&"pulse": {"speed": 10.0, "damage": 20.0, "lifetime": 0.1},
		}
	).accepted, "server registers the authoritative projectile source generation")
	_check(server.set_projectile_server_tick(10).accepted,
		"server projectile clock advances before accepting fire")
	var spawned_receipt: Dictionary = server._projectile.accept_fire(
		2, _intent(3, 0, 1, 10).to_dictionary()
	)
	var spawned := (spawned_receipt.get("projectile", {}) as Dictionary).duplicate(true)
	var projectile_id := StringName(spawned.get("projectile_id", &""))
	var spawned_publication := server.publish_projectile_snapshot(spawned, [2], false, 10)
	var canonical_spawned := server.publish_snapshot(10, [], [], [])
	var spawned_record := _projectile_record(canonical_spawned.packet, projectile_id)
	_check(
		spawned_receipt.accepted and spawned_publication.accepted and canonical_spawned.accepted
		and spawned_record.state == &"spawned" and not bool(spawned_record.terminal)
		and int(spawned_record.projectile_generation) == 1
		and int(spawned_record.source_generation) == 3
		and int(spawned_record.projectile_server_tick) == 10,
		"accepted fire enters the canonical snapshot as a generation-fenced spawn"
	)
	var late_replica := LifecycleAdapter.new(1, 1, 1, 1)
	_check(late_replica.apply_replica_snapshot(1, canonical_spawned.packet).accepted,
		"late replica accepts the server-issued spawned lifecycle")
	var advanced: Dictionary = server._projectile.advance(1, 11, 0.05)
	var active := (advanced.get("projectiles", []) as Array)[0] as Dictionary
	var active_publication := server.publish_projectile_snapshot(active, [2], false, 11)
	var canonical_active := server.publish_snapshot(11, [], [], [])
	_check(
		advanced.accepted and active_publication.accepted and canonical_active.accepted
		and _projectile_record(canonical_active.packet, projectile_id).state == &"active"
		and int(_projectile_record(canonical_active.packet, projectile_id).projectile_revision)
		> int(spawned_record.projectile_revision),
		"server motion advances the canonical projectile revision and active state"
	)
	_check(late_replica.apply_replica_snapshot(1, canonical_active.packet).accepted
		and late_replica.apply_replica_snapshot(1, canonical_spawned.packet).status == &"stale_snapshot",
		"replica accepts active motion and rejects a reordered spawn envelope")
	var impact: Dictionary = server._projectile.resolve_impact(
		1, projectile_id, &"target_a", 1, active.position, Vector3.BACK
	)
	var committed: Dictionary = server._projectile.commit_damage_application(
		1, projectile_id, 20.0, 80.0, false
	)
	var impacted := (committed.get("projectile", {}) as Dictionary).duplicate(true)
	var impact_publication := server.publish_projectile_snapshot(impacted, [2], true, 12)
	var canonical_impact := server.publish_snapshot(12, [], [], [])
	var impact_record := _projectile_record(canonical_impact.packet, projectile_id)
	_check(
		impact.accepted and committed.accepted and impact_publication.accepted
		and canonical_impact.accepted and impact_record.state == &"impacted"
		and bool(impact_record.terminal),
		"committed impact becomes an authoritative terminal tombstone"
	)
	var resurrection := active.duplicate(true)
	resurrection["last_update_tick"] = 13
	_check(server.publish_projectile_snapshot(resurrection, [2], false, 13).status
		== &"projectile_generation_terminal",
		"standalone replication cannot resurrect an impacted generation")
	var impact_replica := LifecycleAdapter.new(1, 1, 1, 1)
	_check(impact_replica.apply_replica_snapshot(1, canonical_impact.packet).accepted
		and _projectile_record(
			impact_replica.get_authoritative_snapshot(), projectile_id
		).state == &"impacted",
		"a fresh late join receives the impact tombstone without replaying damage")

	_check(server.set_projectile_server_tick(20).accepted,
		"server advances to the next bounded projectile lifecycle")
	var expiring_receipt: Dictionary = server._projectile.accept_fire(
		2, _intent(3, 0, 2, 20).to_dictionary()
	)
	var expiring := (expiring_receipt.get("projectile", {}) as Dictionary).duplicate(true)
	var expiring_id := StringName(expiring.get("projectile_id", &""))
	server.publish_projectile_snapshot(expiring, [2], false, 20)
	var expiration: Dictionary = server._projectile.advance(1, 21, 0.1)
	expiring["position"] = (expiring.get("position", Vector3.ZERO) as Vector3) \
		+ (expiring.get("direction", Vector3.ZERO) as Vector3) * float(expiring.get("speed", 0.0)) * 0.1
	expiring["last_update_tick"] = 21
	expiring["state"] = &"expired"
	var expiration_publication := server.publish_projectile_snapshot(expiring, [2], false, 21)
	var canonical_expiration := server.publish_snapshot(21, [], [], [])
	_check(
		expiring_receipt.accepted and expiring_id in expiration.expired_projectile_ids
		and expiration_publication.accepted and canonical_expiration.accepted
		and _projectile_record(canonical_expiration.packet, expiring_id).state == &"expired"
		and bool(_projectile_record(canonical_expiration.packet, expiring_id).terminal),
		"server lifetime expiry publishes an explicit terminal tombstone"
	)

	_check(server.set_projectile_server_tick(22).accepted,
		"server advances before the disconnect-abort fixture")
	var aborting_receipt: Dictionary = server._projectile.accept_fire(
		2, _intent(3, 0, 3, 22).to_dictionary()
	)
	var aborting := (aborting_receipt.get("projectile", {}) as Dictionary).duplicate(true)
	var aborting_id := StringName(aborting.get("projectile_id", &""))
	server.publish_projectile_snapshot(aborting, [2], false, 22)
	server.publish_snapshot(22, [], [], [])
	server._on_peer_disconnected(2)
	var canonical_abort := server.publish_snapshot(23, [], [], [])
	var abort_record := _projectile_record(canonical_abort.packet, aborting_id)
	_check(
		aborting_receipt.accepted and canonical_abort.accepted
		and abort_record.state == &"aborted" and bool(abort_record.terminal)
		and server.get_projectile(aborting_id).is_empty(),
		"source retirement aborts active projectiles before publishing disconnect state"
	)
	var retired := server.publish_snapshot(
		23 + Adapter.PROJECTILE_TOMBSTONE_RETENTION_TICKS + 1, [], [], []
	)
	_check(retired.accepted and (retired.packet.sections.projectiles as Array).is_empty()
		and server._projectile_authoritative_records.size() <= Adapter.PROJECTILE_CANONICAL_MAX_RECORDS,
		"terminal records retire after the bounded late-join window and cache remains capped")
	var bounded_publications := true
	for index in Adapter.PROJECTILE_CANONICAL_MAX_RECORDS + 1:
		var bounded := spawned.duplicate(true)
		bounded["projectile_id"] = StringName("bounded_terminal_%03d" % index)
		bounded["last_update_tick"] = 300 + index
		bounded["state"] = &"expired"
		bounded_publications = bounded_publications and bool(
			server.publish_projectile_snapshot(bounded, [], true, 300 + index).accepted
		)
	_check(
		bounded_publications
		and server._projectile_authoritative_records.size()
		== Adapter.PROJECTILE_CANONICAL_MAX_RECORDS
		and not server._projectile_authoritative_records.has(&"bounded_terminal_000")
		and server._projectile_authoritative_records.has(&"bounded_terminal_256"),
		"the canonical cache evicts its oldest tombstone at the hard record bound"
	)

	var client := Adapter.new()
	root.add_child(client)
	client._configured = true
	_check(
		client.publish_projectile_snapshot(spawned).status == &"authority_required"
		and client.publish_snapshot(200, [], [], []).status == &"authority_required"
		and client.register_projectile_source(
			2, &"forged", 1, &"allied", {&"pulse": {
				"speed": 10.0, "damage": 20.0, "lifetime": 1.0,
			}}
		).status == &"authority_required",
		"presentation clients cannot publish canonical state or create projectile authority"
	)
	client._configured = false
	server._configured = false
	client.queue_free()
	server.queue_free()
	await process_frame
	if _failures.is_empty():
		print("NETWORK_ENET_PROJECTILE_CANONICAL_SNAPSHOT_TEST_OK (%d assertions)" % _assertions)
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)


func _intent(
	source_generation: int, stream_id: int, sequence: int, client_tick: int
):
	return ProjectileIntent.create(
		2, &"fighter_a", source_generation, stream_id, sequence, client_tick,
		&"pulse", Vector3.ZERO, Vector3.FORWARD
	)


func _canonical_record(
	projectile_id: StringName,
	source_entity_id: StringName,
	state: StringName,
	terminal: bool,
	revision: int,
	tick: int
) -> Dictionary:
	return {
		"projectile_id": projectile_id,
		"projectile_generation": 1,
		"source_entity_id": source_entity_id,
		"source_generation": 1,
		"owner_peer_id": 2,
		"projectile_revision": revision,
		"projectile_server_tick": tick,
		"position": Vector3.ZERO,
		"terminal": terminal,
		"state": state,
	}


func _projectile_record(packet: Dictionary, projectile_id: StringName) -> Dictionary:
	var sections := packet.get("sections", {}) as Dictionary
	for record_variant in sections.get(&"projectiles", []) as Array:
		var record := record_variant as Dictionary
		if StringName(record.get("projectile_id", &"")) == projectile_id:
			return record
	return {}


func _check(condition: bool, description: String) -> void:
	_assertions += 1
	if not condition:
		_failures.append("FAIL: " + description)
