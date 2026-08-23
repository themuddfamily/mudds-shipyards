extends SceneTree

const Composition := preload("res://scripts/network/network_ship_authority_composition.gd")
const Cinder := preload("res://scripts/ships/cinder_cargo_hauler.gd")
const Authority := preload("res://scripts/ships/crew_seat_role_authority.gd")
const Snapshot := preload("res://scripts/network/network_authoritative_snapshot.gd")

class AdapterProbe extends RefCounted:
	var snapshot: Dictionary = {}
	var manifests: Array = []
	func publish_snapshot(tick: int, movement: Array, _projectiles: Array, _respawn: Array) -> Dictionary:
		var authority := Snapshot.new(1)
		var result := authority.publish(1, tick, tick, movement, [], [], [], [])
		snapshot = result.get("snapshot", {})
		return {"accepted": result.get("accepted", false), "status": &"snapshot_published", "packet": snapshot}
	func publish_cargo_manifest_snapshot(manifest: Dictionary) -> Dictionary:
		manifests.append(manifest.duplicate(true))
		return {"accepted": true, "status": &"cargo_manifest_published"}

var _assertions := 0
var _failures := PackedStringArray()

func _init() -> void: call_deferred(&"_run")

func _run() -> void:
	var session := AdapterProbe.new()
	var cinder := Cinder.new()
	root.add_child(cinder)
	await process_frame
	var authority := Authority.new(1)
	for record in [[&"cinder_pilot", Authority.ROLE_PILOT], [&"cinder_gunner", Authority.ROLE_GUNNER], [&"cinder_engineer", Authority.ROLE_ENGINEER], [Cinder.LOADMASTER_STATION_SEAT_ID, Authority.ROLE_PASSENGER]]:
		_check(authority.register_seat(record[0], Cinder.COMPONENT_ID, record[1], &"cinder_cargo_walkable_interior", 1, record[0]).accepted, "composition roster registers")
	_check(authority.seal_roster().accepted and cinder.attach_crew_role_authority(authority).accepted, "composition binds real Cinder role authority")
	_check(authority.claim(1, 62, &"loadmaster", Cinder.LOADMASTER_STATION_SEAT_ID, Authority.ROLE_PASSENGER, 1).accepted, "composition role is admitted")
	var composition := Composition.new()
	root.add_child(composition)
	_check(composition.attach(session, cinder, 4).accepted, "composition attaches telemetry and Cinder bridges")
	_check(composition.submit_server_physics_tick(10, 1).accepted, "composition publishes caller tick")
	var movement := (session.snapshot.sections.movement as Array)[0] as Dictionary
	_check(movement.has("engine_power") and movement.has("weapon_power") and movement.has("targeting_power"), "telemetry modifiers reach authoritative snapshot")
	var receipt := composition.submit_cinder_manifest(62, 3, &"loadmaster", 1, 2, {"manifest_id": &"cinder_manifest", "route_id": &"dock_04_cargo", "ready": true})
	_check(receipt.accepted and receipt.receipt.manifest_id == &"cinder_manifest", "real Cinder receipt reaches manifest publisher")
	_check(composition.submit_cinder_manifest(62, 3, &"loadmaster", 1, 2, {}).status == &"stale_request_sequence", "composition rejects manifest replay")
	composition.detach(&"ship_replaced")
	_check(composition.submit_server_physics_tick(11, 2).status == &"detached", "replacement detaches old bridges atomically")
	_check(composition.attach(session, cinder, 5).accepted and composition.submit_server_physics_tick(12, 1).accepted, "re-entry starts a fresh ship generation")
	if _failures.is_empty(): print("OK: network ship authority composition (%d assertions)" % _assertions); quit(0); return
	for failure in _failures: push_error(failure)
	quit(1)

func _check(condition: bool, description: String) -> void:
	_assertions += 1
	if not condition: _failures.append("FAIL: " + description)
