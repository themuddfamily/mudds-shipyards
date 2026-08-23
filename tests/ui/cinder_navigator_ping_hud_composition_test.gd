extends SceneTree

const Composition := preload("res://scripts/ui/cinder_navigator_ping_hud_composition.gd")
const NetworkAdapter := preload("res://scripts/network/network_enet_session_adapter.gd")
const Bridge := preload("res://scripts/network/network_cinder_navigator_ping_bridge.gd")
const Cinder := preload("res://scripts/ships/cinder_cargo_hauler.gd")
const Authority := preload("res://scripts/ships/crew_seat_role_authority.gd")
const Hud := preload("res://scripts/ui/hud.gd")

var _assertions := 0
var _failures := PackedStringArray()


func _init() -> void:
	call_deferred(&"_run")


func _run() -> void:
	var session := NetworkAdapter.new()
	var cinder := Cinder.new()
	var hud := Hud.new()
	root.add_child(session)
	root.add_child(cinder)
	root.add_child(hud)
	await process_frame
	_check(bool(session.host(29209, 1).get("accepted", false)), "real session hosts Cinder bridge output")
	_check(bool(session._migration.rotate_server(1).get("accepted", false)), "real session supplies migration generation two")
	var authority := Authority.new(1)
	for record in [
		[&"cinder_pilot", Authority.ROLE_PILOT],
		[&"cinder_gunner", Authority.ROLE_GUNNER],
		[&"cinder_engineer", Authority.ROLE_ENGINEER],
		[Cinder.LOADMASTER_STATION_SEAT_ID, Authority.ROLE_PASSENGER],
		[Cinder.NAVIGATOR_STATION_SEAT_ID, Authority.ROLE_PASSENGER],
	]:
		_check(bool(authority.register_seat(
			StringName(record[0]), Cinder.COMPONENT_ID, StringName(record[1]),
			&"cinder_cargo_walkable_interior", 1, StringName(record[0])
		).get("accepted", false)), "real Cinder roster seat registers")
	_check(bool(authority.seal_roster().get("accepted", false)), "Cinder roster seals")
	_check(bool(cinder.attach_crew_role_authority(authority).get("accepted", false)), "Cinder retains navigator role authority")
	var actor := CharacterBody3D.new()
	root.add_child(actor)
	var interaction := cinder.get_navigator_interaction()
	actor.global_position = interaction.global_position
	_check(bool(interaction.try_claim(actor, 1, 62, &"navigator_avatar", 1).get("accepted", false)), "real navigator actor claims its physical seat")

	var bridge := Bridge.new()
	_check(bool(bridge.attach(session, cinder).get("accepted", false)), "real Cinder navigator bridge attaches")
	var composition := Composition.new()
	_check(bool(composition.attach(hud).get("accepted", false)), "composition binds its committed presenter and adapter to the real HUD")
	var base := {"roles": {&"passenger": {"occupant": "navigator_avatar", "available": false, "seat_id": &"navigator_station"}}}
	var active := bridge.submit_ping(62, 3, &"navigator_avatar", 1, 2, {"channel": &"sensor", "marker_id": &"route_beacon"}, 12, 2)
	var active_applied := composition.apply_bridge_result(active, base)
	_check(bool(active_applied.get("accepted", false)) and active_applied.get("source_state") == &"active", "authorized bridge receipt reaches the real crew HUD")
	_check(str((active_applied.get("composed", {}) as Dictionary).get("roles", {}).get("passenger", {}).get("occupant", "")).contains("PING ACTIVE"), "active view preserves the caller-owned crew context")
	var snapshot := composition.get_snapshot()
	_check(int(snapshot.get("migration_generation", 0)) == 2 and int(snapshot.get("server_tick", 0)) == 12, "composition preserves authoritative migration and server-tick fences")
	_check(composition.apply_bridge_result(active, base).get("reason") == &"duplicate", "replayed bridge receipt is deduplicated without another HUD update")

	var stale := bridge.submit_ping(62, 3, &"navigator_avatar", 1, 2, {}, 13, 2)
	_check(composition.apply_bridge_result(stale, base).get("source_state") == &"stale", "stale bridge result is projected through the same HUD seam")
	snapshot = composition.get_snapshot()
	_check(int(snapshot.get("migration_generation", 0)) == 2 and int(snapshot.get("server_tick", 0)) == 12, "stale status retains the last committed migration and server-tick fence")
	var released := bridge.release_peer(62)
	var cleared := composition.apply_tombstones(released.get("tombstones", []) as Array, base)
	_check(bool(cleared.get("accepted", false)) and cleared.get("source_state") == &"cleared", "real bridge tombstone clears the HUD ping")
	snapshot = composition.get_snapshot()
	_check(int(snapshot.get("migration_generation", 0)) == 2 and int(snapshot.get("server_tick", 0)) == 13, "tombstone keeps its migration and server-tick fence")

	var detached_generation := int(composition.get_snapshot().get("generation", 0))
	_check(bool(composition.detach().get("accepted", false)), "composition detaches without taking HUD lifecycle authority")
	_check(not bool(composition.apply_bridge_result(active, base).get("accepted", true)), "detached composition cannot mutate the retained HUD")
	_check(bool(composition.attach(hud).get("accepted", false)), "composition supports clean HUD re-entry")
	var available := composition.apply_bridge_result({"accepted": true, "status": &"attached"}, base)
	_check(available.get("source_state") == &"available", "re-entry restores caller-owned ordinary crew fallback")
	_check(not str((available.get("composed", {}) as Dictionary).get("roles", {}).get("passenger", {}).get("occupant", "")).contains("PING"), "ordinary fallback is not retained as navigator overlay")
	_check(int(composition.get_snapshot().get("generation", 0)) > detached_generation, "composition generation advances across detach and re-entry")
	_check(bool(composition.get_snapshot().get("presentation_only", false)) and not bool(composition.get_snapshot().get("network_authority", true)), "composition declares presentation-only network boundary")

	composition.detach()
	bridge.detach()
	_check(bool(interaction.release(actor, 1, 62, &"navigator_avatar", 4).get("accepted", false)), "physical navigator actor releases cleanly")
	actor.queue_free()
	hud.queue_free()
	cinder.queue_free()
	session.shutdown(&"test_complete")
	session.queue_free()
	await process_frame
	if _failures.is_empty():
		print("CINDER_NAVIGATOR_PING_HUD_COMPOSITION_TEST_OK: %d checks" % _assertions)
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)


func _check(condition: bool, description: String) -> void:
	_assertions += 1
	if not condition:
		_failures.append("FAIL: " + description)
