extends SceneTree

const Bridge := preload("res://scripts/network/network_cinder_loadmaster_manifest_bridge.gd")
const Cinder := preload("res://scripts/ships/cinder_cargo_hauler.gd")
const Authority := preload("res://scripts/ships/crew_seat_role_authority.gd")
const Snapshot := preload("res://scripts/network/network_authoritative_snapshot.gd")

class AdapterProbe extends RefCounted:
	var manifests: Array = []
	func publish_cargo_manifest_snapshot(manifest: Dictionary) -> Dictionary:
		manifests.append(manifest.duplicate(true))
		return {"accepted": true, "status": &"cargo_manifest_published"}

var _assertions := 0
var _failures := PackedStringArray()

func _init() -> void: call_deferred(&"_run")

func _run() -> void:
	var cinder := Cinder.new()
	root.add_child(cinder)
	await process_frame
	var authority := Authority.new(1)
	for record in [[&"cinder_pilot", Authority.ROLE_PILOT], [&"cinder_gunner", Authority.ROLE_GUNNER], [&"cinder_engineer", Authority.ROLE_ENGINEER], [Cinder.LOADMASTER_STATION_SEAT_ID, Authority.ROLE_PASSENGER]]:
		_check(authority.register_seat(record[0], Cinder.COMPONENT_ID, record[1], &"cinder_cargo_walkable_interior", 1, record[0]).accepted, "Cinder roster seat registers")
	_check(authority.seal_roster().accepted and cinder.attach_crew_role_authority(authority).accepted, "real Cinder role authority attaches")
	_check(authority.claim(1, 62, &"loadmaster", Cinder.LOADMASTER_STATION_SEAT_ID, Authority.ROLE_PASSENGER, 1).accepted, "server admits exact loadmaster seat")
	var adapter := AdapterProbe.new()
	var bridge := Bridge.new()
	_check(bridge.attach(adapter, cinder).accepted, "bridge attaches Cinder")
	var accepted := bridge.submit_manifest(62, 3, &"loadmaster", 1, 2, {"manifest_id": &"cinder_manifest", "route_id": &"dock_04_cargo", "ready": true})
	_check(accepted.accepted and accepted.receipt.manifest_id == &"cinder_manifest", "real Cinder receipt publishes")
	_check(bridge.submit_manifest(62, 3, &"loadmaster", 1, 2, {}).status == &"stale_request_sequence", "replay is rejected")
	_check(bridge.submit_manifest(62, 3, &"wrong", 1, 3, {}).status == &"loadmaster_identity_mismatch", "foreign occupant is rejected")
	bridge.detach()
	_check(bridge.submit_manifest(62, 3, &"loadmaster", 1, 3, {}).status == &"detached", "detach clears network bridge")
	_check(bridge.attach(adapter, cinder).accepted and bridge.release_peer(62).accepted, "re-entry clears peer cursor")
	if _failures.is_empty(): print("OK: Cinder loadmaster manifest bridge (%d assertions)" % _assertions); quit(0); return
	for failure in _failures: push_error(failure)
	quit(1)

func _check(condition: bool, description: String) -> void:
	_assertions += 1
	if not condition: _failures.append("FAIL: " + description)
