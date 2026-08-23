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
	hud.set_objective("Board the Torrent interceptor for the guided test — other berthed craft are available for free sorties")
	await process_frame
	var cases := [Vector2(7680.0, 1440.0), Vector2(2560.0, 1440.0), Vector2(1280.0, 1024.0), Vector2(1600.0, 1200.0)]
	for requested_scale in [0.75, 1.0, 1.6]:
		hud.set_ui_scale(requested_scale)
		for viewport in cases:
			var effective := hud.layout_for_viewport(viewport)
			var logical: Vector2 = viewport / maxf(effective, 0.01)
			var safe := hud.get_safe_area_insets()
			var status := HudType.compute_runtime_status_panel_rect(viewport, safe, effective)
			_check(status.position.x >= 0.0 and status.end.x <= logical.x + 0.5, "%s status stays within horizontal band at scale %.2f" % [viewport, requested_scale])
			_check(status.position.y >= 0.0 and status.end.y <= logical.y + 0.5, "%s status stays within vertical band at scale %.2f" % [viewport, requested_scale])
	hud.layout_for_viewport(Vector2(1600.0, 900.0))
	await process_frame
	var report := hud.get_hud_panel_rects()
	_check(report.has("objective") and report.has("help") and report.has("telemetry"), "extreme aspect layout retains key readable panels")
	var objective := report.get("objective", Rect2()) as Rect2
	var minimap := report.get("minimap", Rect2()) as Rect2
	_check(
		objective.size.y < 200.0 and objective.end.y <= minimap.position.y,
		"the wrapped current objective stays compact and above the minimap"
	)
	var compact_height := objective.size.y
	hud.set_activity_objective("Station perimeter defense", {
		"activity_kind": &"station_defense",
		"state_id": &"failed",
		"phase_id": &"failed",
		"current_wave_index": 1,
		"wave_count": 3,
		"failure_reason": &"protected_assets_destroyed_during_final_defense_wave",
	})
	await process_frame
	await process_frame
	var expanded_height := (hud.get_hud_panel_rects().get("objective", Rect2()) as Rect2).size.y
	hud.clear_activity_objective()
	await process_frame
	await process_frame
	var cleared := hud.get_hud_panel_rects().get("objective", Rect2()) as Rect2
	_check(
		expanded_height > compact_height and is_equal_approx(cleared.size.y, compact_height),
		"the objective card shrinks back after a long activity objective is cleared"
	)
	hud.queue_free()
	await process_frame
	if _failures.is_empty():
		print("HUD_EXTREME_ASPECT_LAYOUT_TEST_OK (%d assertions)" % _assertions)
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)


func _check(condition: bool, message: String) -> void:
	_assertions += 1
	if not condition:
		_failures.append("FAIL: " + message)
