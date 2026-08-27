extends SceneTree

const HudType := preload("res://scripts/ui/hud.gd")

var _assertions := 0
var _failures: PackedStringArray = []


func _init() -> void:
	call_deferred(&"_run")


func _run() -> void:
	var hud := HudType.new()
	root.add_child(hud)
	await process_frame
	_check(
		hud.apply_first_sortie_tutorial_snapshot({
			"step_id": &"board", "generation": 1, "revision": 1,
		}),
		"live HUD presents a focusable tutorial card"
	)
	await process_frame
	var viewport := hud.get_viewport()
	var focus_owner := viewport.gui_get_focus_owner()
	_check(
		is_instance_valid(focus_owner)
		and (hud.get("_runtime_status_panel") as Control).is_ancestor_of(focus_owner),
		"live tutorial owns focus before its card is cleared"
	)
	hud.clear_first_sortie_tutorial(&"live_clear")
	_check(
		viewport.gui_get_focus_owner() == null,
		"live tutorial clear preserves the existing focus release handoff"
	)

	_check(
		hud.apply_first_sortie_tutorial_snapshot({
			"step_id": &"board", "generation": 2, "revision": 1,
		}),
		"HUD presents a second tutorial before retained-tree teardown"
	)
	root.remove_child(hud)
	_check(
		not hud.is_inside_tree() and hud.get_viewport() == null,
		"retained HUD has no viewport after tree teardown"
	)
	var result := hud.clear_first_sortie_tutorial(&"game_flow_detached")
	_check(
		bool(result.get("accepted", false))
		and not (hud.get("_runtime_status_cards") as Dictionary).has(&"tutorial")
		and (hud.get("_first_sortie_tutorial_source_snapshot") as Dictionary).is_empty(),
		"detached HUD clears tutorial state without requiring a live viewport"
	)
	hud.free()

	if _failures.is_empty():
		print("HUD_TUTORIAL_TEARDOWN_LIFECYCLE_TEST_OK (%d assertions)" % _assertions)
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)


func _check(condition: bool, message: String) -> void:
	_assertions += 1
	if condition:
		print("PASS: %s" % message)
	else:
		_failures.append("FAIL: " + message)
