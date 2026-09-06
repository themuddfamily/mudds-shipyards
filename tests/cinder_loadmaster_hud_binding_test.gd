extends SceneTree

const Hauler := preload("res://scripts/ships/cinder_cargo_hauler.gd")
const Authority := preload("res://scripts/ships/crew_seat_role_authority.gd")
const RoleProfile := preload("res://scripts/fleet/crew_role_gameplay_profile.gd")
const HudType := preload("res://scripts/ui/hud.gd")
const BindingType := preload("res://scripts/ui/cinder_loadmaster_hud_binding.gd")
var _assertions := 0
var _failures: PackedStringArray = []

func _init() -> void:
	call_deferred(&"_run")

func _run() -> void:
	var craft := Hauler.new() as CinderCargoHauler
	var hud := HudType.new()
	root.add_child(craft)
	root.add_child(hud)
	await process_frame
	var authority := Authority.new(1)
	for seat_record in [
		[&"cinder_pilot", Authority.ROLE_PILOT],
		[&"cinder_gunner", Authority.ROLE_GUNNER],
		[&"cinder_engineer", Authority.ROLE_ENGINEER],
		[Hauler.LOADMASTER_STATION_SEAT_ID, Authority.ROLE_PASSENGER],
	]:
		_check(bool(authority.register_seat(StringName(seat_record[0]), Hauler.COMPONENT_ID, StringName(seat_record[1]), &"cinder_cargo_walkable_interior", 1, StringName(seat_record[0])).get("accepted", false)), "Cinder role seat is registered")
	_check(bool(authority.seal_roster().get("accepted", false)), "Cinder role roster seals")
	_check(bool(craft.attach_crew_role_authority(authority).get("accepted", false)), "Cinder role authority attaches")
	var binding := BindingType.new()
	_check(bool(binding.attach(craft, hud, &"loadmaster").get("accepted", false)), "binding attaches through explicit caller seam")
	var detail := hud.get("_runtime_status_detail") as Label
	_check(detail.text.contains("CRAFT // " + str(Hauler.COMPONENT_ID).to_upper()) and detail.text.contains("SEAT AVAILABLE") and detail.text.contains("ROSTER STATE // [/] DETACHED // STATION OPEN"), "initial detached Cinder state has a text-and-shape roster reading")
	_check(bool(authority.claim(1, 72, &"binding_loadmaster", Hauler.LOADMASTER_STATION_SEAT_ID, Authority.ROLE_PASSENGER, 1).get("accepted", false)), "caller claims the physical loadmaster seat")
	craft.refresh_loadmaster_status_display()
	binding.detach()
	_check(bool(binding.attach(craft, hud, &"loadmaster").get("accepted", false)), "occupied state republishes through the binding")
	_check(detail.text.contains("SEAT OCCUPIED") and detail.text.contains("ROSTER STATE // [>] LOADING // MANIFEST PENDING"), "claimed station has the loading text-and-shape roster reading")
	var blocked_receipt := craft.submit_crew_intent(1, 72, &"binding_loadmaster", RoleProfile.ACTION_PASSENGER_CARGO_MANIFEST, {"manifest_id": &"binding_manifest", "route_id": &"dock_04_cargo", "ready": false}, 2)
	_check(bool(blocked_receipt.get("consumed", false)), "caller submits the blocked manifest receipt")
	_check(detail.text.contains("SEAT OCCUPIED") and detail.text.contains("ROSTER STATE // [!] BLOCKED // MANIFEST REVIEW"), "not-ready receipt has the blocked text-and-shape roster reading")
	var receipt := craft.submit_crew_intent(1, 72, &"binding_loadmaster", RoleProfile.ACTION_PASSENGER_CARGO_MANIFEST, {"manifest_id": &"binding_manifest", "route_id": &"dock_04_cargo", "ready": true}, 3)
	_check(bool(receipt.get("consumed", false)), "caller submits the ready manifest receipt")
	_check(detail.text.contains("SEAT MANIFEST_READY") and detail.text.contains("ROSTER STATE // [=] SECURED // MANIFEST READY") and detail.text.contains("GENERATION // 1"), "accepted manifest signal updates HUD with a secured shape")
	var released := craft.release_crew_role(1, 72, &"binding_loadmaster", Hauler.LOADMASTER_STATION_SEAT_ID, 4, 1)
	_check(bool(released.get("accepted", false)), "caller releases the loadmaster role")
	_check(detail.text.contains("SEAT RELEASED") and detail.text.contains("ROSTER STATE // [/] DETACHED // STATION OPEN") and detail.text.contains("GENERATION // 2"), "release signal updates HUD with fenced detached shape")
	_check(bool(binding.detach().get("accepted", false)) and not (hud.get("_runtime_status_panel") as Control).visible, "detach clears HUD and disconnects binding")
	craft.queue_free()
	hud.queue_free()
	await process_frame
	if _failures.is_empty():
		print("CINDER_LOADMASTER_HUD_BINDING_TEST_OK (%d assertions)" % _assertions)
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)

func _check(condition: bool, message: String) -> void:
	_assertions += 1
	if not condition:
		_failures.append("FAIL: " + message)
