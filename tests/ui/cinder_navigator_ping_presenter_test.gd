extends SceneTree

const Presenter := preload("res://scripts/ui/cinder_navigator_ping_presenter.gd")
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
	_check(bool(adapter.host(29208, 1).get("accepted", false)), "real session hosts for presenter input")
	var rotated: Dictionary = adapter._migration.rotate_server(1)
	_check(bool(rotated.get("accepted", false)) and int(rotated.get("migration_generation", 0)) == 2, "presenter receives a non-default authoritative migration")

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
		_check(bool(authority.register_seat(
			StringName(record[0]), Cinder.COMPONENT_ID, StringName(record[1]),
			&"cinder_cargo_walkable_interior", 1, StringName(record[0])
		).get("accepted", false)), "real Cinder roster seat registers")
	_check(bool(authority.seal_roster().get("accepted", false)), "navigator roster seals")
	_check(bool(cinder.attach_crew_role_authority(authority).get("accepted", false)), "Cinder owns the admitted seat authority")
	var actor := CharacterBody3D.new()
	root.add_child(actor)
	var interaction := cinder.get_navigator_interaction()
	actor.global_position = interaction.global_position
	_check(bool(interaction.try_claim(actor, 1, 62, &"navigator_avatar", 1).get("accepted", false)), "physical navigator actor claims the real seat")

	var bridge := Bridge.new()
	_check(bool(bridge.attach(adapter, cinder).get("accepted", false)), "bridge attaches to the real Cinder")
	var presenter := Presenter.new()
	var accepted := bridge.submit_ping(
		62, 3, &"navigator_avatar", 1, 2,
		{"channel": &"sensor", "marker_id": &"route_beacon"}, 12, 2
	)
	var active := presenter.present_bridge_result(accepted)
	_check(active.get("state") == &"active" and active.get("state_marker") == &"●", "accepted wire receipt becomes an accessible active state")
	_check(active.get("channel") == "SENSOR" and active.get("marker_id") == "route_beacon", "active presentation exposes bounded channel and marker")
	_check(int(active.get("migration_generation", 0)) == 2 and int(active.get("server_tick", 0)) == 12, "active presentation preserves migration and server tick")
	_check(active.get("presentation_only", false) and not active.get("authority", true), "active presentation declares no authority")

	var stale := bridge.submit_ping(62, 3, &"navigator_avatar", 1, 2, {}, 13, 2)
	var stale_view := presenter.present_bridge_result(stale)
	_check(stale_view.get("state") == &"stale" and stale_view.get("state_marker") == &"!", "replayed bridge result is explicitly stale")
	var released := bridge.release_peer(62)
	var released_view := presenter.present_bridge_result(released)
	_check(released_view.get("state") == &"cleared" and released_view.get("state_marker") == &"○", "peer release tombstone clears the visible ping")
	_check(released_view.get("reason") == &"peer_released", "clear reason is retained for accessible presentation")

	var fresh := bridge.submit_ping(
		62, 3, &"navigator_avatar", 1, 3,
		{"channel": &"sensor", "marker_id": &"fresh_beacon"}, 14, 2
	)
	_check(bool(fresh.get("accepted", false)), "fresh sequence remains consumable after peer cursor cleanup")
	presenter.present_bridge_result(fresh)
	var detached := bridge.detach()
	var detached_view := presenter.present_bridge_result(detached)
	_check(detached_view.get("state") == &"cleared" and not detached_view.get("attached", true), "detach tombstone clears stale remote state and marks lifecycle detached")
	_check(int(detached_view.get("migration_generation", 0)) == 2, "detach clear keeps the authoritative migration fence")
	var attached := presenter.present_bridge_result({"accepted": true, "status": &"attached"})
	_check(attached.get("state") == &"available" and attached.get("attached", false), "re-entry resets the presenter to an available state")
	var rejected := presenter.present_bridge_result({"accepted": false, "status": &"navigator_identity_mismatch"})
	_check(rejected.get("state") == &"rejected" and rejected.get("state_marker") == &"×", "rejected bridge result is explicitly accessible")

	_check(bool(interaction.release(actor, 1, 62, &"navigator_avatar", 4).get("accepted", false)), "physical navigator actor releases cleanly")
	actor.queue_free()
	cinder.queue_free()
	adapter.shutdown(&"test_complete")
	adapter.queue_free()
	await process_frame
	if _failures.is_empty():
		print("CINDER_NAVIGATOR_PING_PRESENTER_TEST_OK: %d checks" % _assertions)
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)


func _check(condition: bool, description: String) -> void:
	_assertions += 1
	if not condition:
		_failures.append("FAIL: " + description)
