extends SceneTree

const CinderType := preload("res://scripts/ships/cinder_cargo_hauler.gd")
const CruiseType := preload("res://scripts/control/planetary_cruise_production_binding.gd")
const HudType := preload("res://scripts/ui/hud.gd")
var _assertions := 0
var _failures: PackedStringArray = []


func _init() -> void:
	call_deferred(&"_run")


func _run() -> void:
	var game := GameFlow.new()
	var hud := HudType.new()
	var cruise_binding := CruiseType.new()
	root.add_child(hud)
	root.add_child(cruise_binding)
	game.set("hud", hud)
	game.set("planetary_cruise_binding", cruise_binding)
	await process_frame
	await process_frame
	await physics_frame
	_check(hud != null and cruise_binding != null, "GameFlow-owned HUD and cruise seams are available")
	if hud == null or cruise_binding == null:
		await _cleanup(game, hud, cruise_binding, null)
		_finish()
		return
	game.set_physics_process(false)
	game.call("_ensure_final_approach_hud_composition")
	var composition := game.get("_final_approach_hud_composition") as FinalApproachHudComposition
	_check(composition != null and bool(composition.get_snapshot().get("attached", false)), "GameFlow composes final approach after startup")
	if composition != null:
		composition.set_cruise_controls(true, true)
		cruise_binding.engagement_changed.emit({
			"generation": 20,
			"engagement_requested": true,
			"controller": {"final_approach": {"state_id": &"final_approach"}},
		})
		_check(
			hud.get_planetary_cruise_presentation_report().status_id == &"accelerating",
			"final approach receipt overrides the ordinary cruise row"
		)
		game.call("_detach_final_approach_hud_composition")
		cruise_binding.engagement_changed.emit({
			"generation": 21,
			"engagement_requested": true,
			"controller": {"final_approach": {"state_id": &"final_approach"}},
		})
		_check(game.get("_final_approach_hud_composition") == null, "final approach composition detaches on lifecycle boundary")
	var cinder := CinderType.new() as CinderCargoHauler
	root.add_child(cinder)
	await process_frame
	game.set("active_ship", cinder)
	game.call("_sync_cinder_loadmaster_hud_binding")
	var loadmaster_binding := game.get("_cinder_loadmaster_hud_binding") as CinderLoadmasterHudBinding
	_check(loadmaster_binding != null and loadmaster_binding.is_attached(), "GameFlow attaches Cinder loadmaster only for active Cinder")
	var detail := hud.get("_runtime_status_detail") as Label
	_check(detail != null and detail.text.contains("CRAFT // CINDER-CARGO-HAULER"), "Cinder binding publishes through the production HUD seam")
	game.set("active_ship", game.get_guided_ship())
	game.call("_sync_cinder_loadmaster_hud_binding")
	_check(game.get("_cinder_loadmaster_hud_binding") == null, "switching away detaches Cinder loadmaster presentation")
	await _cleanup(game, hud, cruise_binding, cinder)
	_finish()


func _cleanup(game: GameFlow, hud: GameHUD, cruise_binding: PlanetaryCruiseProductionBinding, cinder: CinderCargoHauler) -> void:
	if is_instance_valid(game):
		game.free()
	if is_instance_valid(hud):
		hud.queue_free()
	if is_instance_valid(cruise_binding):
		cruise_binding.queue_free()
	if is_instance_valid(cinder):
		cinder.queue_free()
	await process_frame


func _finish() -> void:
	if _failures.is_empty():
		print("GAME_FLOW_FINAL_APPROACH_LOADMASTER_INTEGRATION_TEST_OK (%d assertions)" % _assertions)
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)


func _check(condition: bool, message: String) -> void:
	_assertions += 1
	if not condition:
		_failures.append("FAIL: " + message)
