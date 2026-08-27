extends SceneTree

## Native Forward+ witness for the retained component HUD lifecycle row. The
## production Arrow publishes the actual destruction and post-reuse snapshots;
## this harness owns only a neutral render background and never writes lifecycle.

const HudType := preload("res://scripts/ui/hud.gd")
const ArrowScene := preload("res://scenes/ships/arrow_recon_ship.tscn")
const OUTPUT_DIR := "user://screenshots/ship_destroyed_hud_states"

var _assertions := 0
var _failures: PackedStringArray = []
var _baseline_bounds := Rect2()


func _init() -> void:
	call_deferred(&"_run")


func _run() -> void:
	_check(RenderingServer.get_current_rendering_method() == &"forward_plus", "capture uses the Forward+ renderer")
	_check(DisplayServer.get_name() == "X11", "capture uses the display-backed X11 path")
	if not _failures.is_empty():
		_finish()
		return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	var background := ColorRect.new()
	background.color = Color("071321")
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(background)
	var hud := HudType.new()
	root.add_child(hud)
	var arrow := ArrowScene.instantiate() as HeroShip
	root.add_child(arrow)
	await process_frame
	await physics_frame
	hud.set("_reduced_motion", true)
	hud.call("_begin")
	await _settle()
	hud.set_mode("piloting")
	var label := hud.get("_component_status_label") as Label
	_check(hud.bind_hero_component_ship(arrow), "capture binds the real Arrow component roster")
	await _settle()
	_baseline_bounds = label.get_global_rect()
	_capture("01_nominal", label, "COMPONENT  //  FORWARD HULL  100%  //  NOMINAL", true)

	arrow.apply_damage(999.0, arrow.global_position, Vector3.UP, -1, false)
	await _settle()
	_capture("02_destroyed", label, "[X] DESTROYED  //  HULL LOST", true)

	var reset := arrow.reset_for_reuse(arrow.global_transform)
	_check(bool(reset.get("accepted", false)), "capture accepts the production post-destruction reset")
	await _settle()
	var recovery := arrow.get_component_recovery_report()
	_check(bool(recovery.get("valid", false)), "capture observes the complete public recovery audit")
	_capture("03_respawn_ready", label, "[+] RESPAWN READY  //  RECOVERY VERIFIED", true)

	hud.clear_hero_component_ship()
	await _settle()
	_capture("04_detached", label, "", false)
	arrow.queue_free()
	hud.queue_free()
	background.queue_free()
	await process_frame
	_finish()


func _settle() -> void:
	for _pass in 3:
		await process_frame
	RenderingServer.force_draw()
	await process_frame


func _capture(name: String, label: Label, expected_text: String, expected_visible: bool) -> void:
	var bounds := label.get_global_rect()
	_check(label.visible == expected_visible and label.text == expected_text, "%s retains the expected visible text" % name)
	_check(bounds == _baseline_bounds, "%s keeps the component row at exact settled bounds %s" % [name, bounds])
	var image := root.get_texture().get_image()
	var output := "%s/%s.png" % [OUTPUT_DIR, name]
	_check(not image.is_empty() and image.save_png(output) == OK, "%s Forward+ PNG saves" % name)


func _check(condition: bool, message: String) -> void:
	_assertions += 1
	if condition:
		print("PASS: %s" % message)
	else:
		_failures.append(message)
		push_error("FAIL: %s" % message)


func _finish() -> void:
	if _failures.is_empty():
		print("SHIP_DESTROYED_HUD_STATES_CAPTURE_OK (%d assertions)" % _assertions)
		quit(0)
		return
	print("SHIP_DESTROYED_HUD_STATES_CAPTURE_FAILED: %s" % "; ".join(_failures))
	quit(1)
