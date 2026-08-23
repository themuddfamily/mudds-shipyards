extends SceneTree

const Composition := preload("res://scripts/network/network_ship_authority_composition.gd")
const Cinder := preload("res://scripts/ships/cinder_cargo_hauler.gd")
const Authority := preload("res://scripts/ships/crew_seat_role_authority.gd")
const Snapshot := preload("res://scripts/network/network_authoritative_snapshot.gd")

class AdapterProbe extends RefCounted:
	var snapshot: Dictionary = {}
	var manifests: Array = []
	var crew_publications: Array = []
	var server := true
	var migration_generation := 1
	func is_server() -> bool:
		return server
	func get_migration_snapshot() -> Dictionary:
		return {"migration_generation": migration_generation}
	func publish_snapshot(tick: int, movement: Array, _projectiles: Array, _respawn: Array) -> Dictionary:
		var authority := Snapshot.new(1)
		var result := authority.publish(1, tick, tick, movement, [], [], [], [])
		snapshot = result.get("snapshot", {})
		return {"accepted": result.get("accepted", false), "status": &"snapshot_published", "packet": snapshot}
	func publish_cargo_manifest_snapshot(manifest: Dictionary) -> Dictionary:
		manifests.append(manifest.duplicate(true))
		return {"accepted": true, "status": &"cargo_manifest_published"}
	func publish_crew_snapshot(receipts: Array) -> Dictionary:
		if not server:
			return {"accepted": false, "status": &"authority_required"}
		crew_publications.append(receipts.duplicate(true))
		return {"accepted": true, "status": &"crew_snapshot_published"}

var _assertions := 0
var _failures := PackedStringArray()

func _init() -> void: call_deferred(&"_run")

func _run() -> void:
	var session := AdapterProbe.new()
	var cinder := Cinder.new()
	root.add_child(cinder)
	await process_frame
	var authority := Authority.new(1)
	for record in [[&"cinder_pilot", Authority.ROLE_PILOT], [&"cinder_gunner", Authority.ROLE_GUNNER], [&"cinder_engineer", Authority.ROLE_ENGINEER], [Cinder.LOADMASTER_STATION_SEAT_ID, Authority.ROLE_PASSENGER], [Cinder.NAVIGATOR_STATION_SEAT_ID, Authority.ROLE_PASSENGER]]:
		_check(authority.register_seat(record[0], Cinder.COMPONENT_ID, record[1], &"cinder_cargo_walkable_interior", 1, record[0]).accepted, "composition roster registers")
	_check(authority.seal_roster().accepted and cinder.attach_crew_role_authority(authority).accepted, "composition binds real Cinder role authority")
	_check(authority.claim(1, 62, &"loadmaster", Cinder.LOADMASTER_STATION_SEAT_ID, Authority.ROLE_PASSENGER, 1).accepted, "composition role is admitted")
	_check(authority.claim(1, 63, &"navigator", Cinder.NAVIGATOR_STATION_SEAT_ID, Authority.ROLE_PASSENGER, 1).accepted, "composition navigator role is admitted")
	var composition := Composition.new()
	root.add_child(composition)
	var forwarded_receipts: Array = []
	var forwarded_results: Array = []
	var forwarded_tombstones: Array = []
	composition.cinder_navigator_ping_receipt_forwarded.connect(func(result: Dictionary) -> void: forwarded_receipts.append(result))
	composition.cinder_navigator_ping_result_forwarded.connect(func(result: Dictionary) -> void: forwarded_results.append(result))
	composition.cinder_navigator_ping_tombstones_forwarded.connect(func(result: Dictionary) -> void: forwarded_tombstones.append(result))
	var attached := composition.attach(session, cinder, 4)
	_check(attached.accepted and attached.cinder_navigator_attached, "composition attaches telemetry and both Cinder bridges")
	_check(composition.submit_server_physics_tick(10, 1).accepted, "composition publishes caller tick")
	var movement := (session.snapshot.sections.movement as Array)[0] as Dictionary
	_check(movement.has("engine_power") and movement.has("weapon_power") and movement.has("targeting_power"), "telemetry modifiers reach authoritative snapshot")
	var receipt := composition.submit_cinder_manifest(62, 3, &"loadmaster", 1, 2, {"manifest_id": &"cinder_manifest", "route_id": &"dock_04_cargo", "ready": true})
	_check(receipt.accepted and receipt.receipt.manifest_id == &"cinder_manifest", "real Cinder receipt reaches manifest publisher")
	_check(composition.submit_cinder_manifest(62, 3, &"loadmaster", 1, 2, {}).status == &"stale_request_sequence", "composition rejects manifest replay")
	var ping := composition.submit_cinder_navigator_ping(63, 3, &"navigator", 1, 2, {"channel": &"sensor", "marker_id": &"route_beacon"}, 11, 1)
	_check(ping.accepted and ping.wire_receipt.payload.marker_id == &"route_beacon" and ping.wire_receipt.ship_generation == 4 and forwarded_receipts.size() == 1 and forwarded_results == [ping], "accepted navigator receipt and result forward once with the composition ship generation")
	var before_client_attempt := cinder.get_navigator_ping_snapshot()
	session.server = false
	var client_attempt := composition.submit_cinder_navigator_ping(63, 3, &"navigator", 1, 3, {"channel": &"sensor", "marker_id": &"client_mutation"}, 12, 1)
	_check(client_attempt.status == &"server_authority_required" and client_attempt.policy_version == &"network_cinder_navigator_ping_bridge_v1" and forwarded_results.size() == 2 and forwarded_results[1] == client_attempt and forwarded_receipts.size() == 1, "rejected navigator result forwards once with bridge provenance and no accepted receipt")
	_check(cinder.get_navigator_ping_snapshot() == before_client_attempt, "client mode cannot mutate the Cinder navigator receipt")
	session.server = true
	session.migration_generation = 2
	var stale_migration := composition.submit_cinder_navigator_ping(63, 3, &"navigator", 1, 3, {}, 12, 1)
	_check(stale_migration.status == &"stale_migration_generation" and forwarded_results.size() == 3 and forwarded_results[2] == stale_migration, "composition forwards the retired migration rejection exactly once")
	var migrated := composition.submit_cinder_navigator_ping(63, 3, &"navigator", 1, 3, {"channel": &"sensor", "marker_id": &"migrated_beacon"}, 12, 2)
	_check(migrated.accepted and int(migrated.wire_receipt.migration_generation) == 2 and forwarded_results.size() == 4 and forwarded_receipts.size() == 2, "current migration generation publishes through both composition result channels")
	var peer_release := composition.release_peer(63)
	var navigator_release := peer_release.cinder_navigator_ping as Dictionary
	_check(peer_release.accepted and navigator_release.tombstone_count == 1 and forwarded_tombstones.size() == 1, "peer release forwards the navigator clear tombstone")
	_check(composition.submit_cinder_manifest(62, 3, &"loadmaster", 1, 2, {}).status == &"stale_request_sequence", "navigator peer release preserves the loadmaster cursor")
	var post_release := composition.submit_cinder_navigator_ping(63, 3, &"navigator", 1, 4, {"channel": &"sensor", "marker_id": &"reentry_beacon"}, 13, 2)
	_check(post_release.accepted and forwarded_results.size() == 5 and forwarded_receipts.size() == 3, "released bridge cursor accepts and forwards the next authority-valid navigator request once")
	var detached := composition.detach(&"ship_replaced")
	_check((detached.cinder_navigator_ping as Dictionary).tombstone_count == 1 and forwarded_tombstones.size() == 2, "composition detach forwards its final navigator tombstone")
	_check(composition.submit_server_physics_tick(11, 2).status == &"detached", "replacement detaches old bridges atomically")
	var detached_attempt := composition.submit_cinder_navigator_ping(63, 3, &"navigator", 1, 5, {}, 14, 2)
	_check(detached_attempt.status == &"cinder_navigator_unavailable" and forwarded_results.size() == 5, "detached synthetic navigator result is not published as a real bridge submission")
	var reattached := composition.attach(session, cinder, 5)
	_check(reattached.accepted and reattached.cinder_navigator_attached and composition.get_cinder_navigator_ping_snapshot().ship_generation == 5 and composition.submit_server_physics_tick(12, 1).accepted, "re-entry starts fresh telemetry and navigator bridge generations")
	var before_reentry_client_attempt := cinder.get_navigator_ping_snapshot()
	session.server = false
	var reentry_client_attempt := composition.submit_cinder_navigator_ping(63, 3, &"navigator", 1, 5, {"channel": &"sensor", "marker_id": &"reentry_client_mutation"}, 14, 2)
	_check(reentry_client_attempt.status == &"server_authority_required" and forwarded_results.size() == 6 and forwarded_results[5] == reentry_client_attempt and forwarded_receipts.size() == 3, "re-entry forwards one real rejection without duplicating an accepted receipt")
	_check(cinder.get_navigator_ping_snapshot() == before_reentry_client_attempt, "re-entry client rejection cannot mutate Cinder")
	if _failures.is_empty(): print("OK: network ship authority composition (%d assertions)" % _assertions); quit(0); return
	for failure in _failures: push_error(failure)
	quit(1)

func _check(condition: bool, description: String) -> void:
	_assertions += 1
	if not condition: _failures.append("FAIL: " + description)
