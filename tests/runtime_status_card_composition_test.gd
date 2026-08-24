extends SceneTree

const HudType := preload("res://scripts/ui/hud.gd")

const VIEWPORTS := [Vector2(1280.0, 720.0), Vector2(1920.0, 1080.0)]
const REQUESTED_SCALES := [1.0, 1.6]

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
			"step_id": &"board", "generation": 8, "revision": 1,
		}),
		"tutorial supplies the ordinary runtime card",
	)
	await _check_composed_rects(hud, &"runtime_status")
	_check(
		hud.apply_bomber_payload_snapshot({
			"generation": 1, "active": true, "ammo": 2, "cooldown_remaining": 0.0,
		}),
		"bomber supplies the dedicated payload band",
	)
	await _check_composed_rects(hud, &"bomber_payload")
	_check(
		hud.clear_runtime_status_card(&"surface") == false
		and (hud.get("_bomber_status_panel") as Control).visible,
		"clearing an absent source cannot erase the active bomber card",
	)
	hud.clear_bomber_payload_status()
	_check(
		(hud.get("_runtime_status_panel") as Control).visible
		and not (hud.get("_bomber_status_panel") as Control).visible,
		"bomber clear restores the retained tutorial composition",
	)
	hud.queue_free()
	await process_frame
	if _failures.is_empty():
		print("RUNTIME_STATUS_CARD_COMPOSITION_TEST_OK (%d assertions)" % _assertions)
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)


func _check_composed_rects(hud: GameHUD, active_key: StringName) -> void:
	for viewport in VIEWPORTS:
		for requested_scale in REQUESTED_SCALES:
			hud.set_ui_scale(requested_scale)
			hud.layout_for_viewport(viewport)
			await process_frame
			await process_frame
			var rects := hud.get_hud_panel_rects()
			var key := String(active_key)
			var inactive_key := "bomber_payload" if key == "runtime_status" else "runtime_status"
			var active_rect := rects.get(key, Rect2()) as Rect2
			print("MEASURED: %s %.0fx%.0f scale %.2f -> %s" % [key, viewport.x, viewport.y, requested_scale, str(active_rect)])
			var overlaps: PackedStringArray = []
			for other_key_variant: Variant in rects.keys():
				var other_key := str(other_key_variant)
				if other_key == key:
					continue
				if other_key == "caption" and not (hud.get("_caption_presenter") as Control).visible:
					continue
				var intersection := active_rect.intersection(rects[other_key] as Rect2)
				if intersection.size.x > 0.0 and intersection.size.y > 0.0:
					overlaps.append(other_key)
			_check(
				rects.has(key)
				and not rects.has(inactive_key)
				and active_rect.size.x > 0.0
				and active_rect.size.y > 0.0
				and overlaps.is_empty(),
				"%s is registered and disjoint at %.0fx%.0f scale %.2f%s" % [
					key, viewport.x, viewport.y, requested_scale,
					"" if overlaps.is_empty() else " (overlaps " + ", ".join(overlaps) + ")",
				],
			)


func _check(condition: bool, message: String) -> void:
	_assertions += 1
	if condition:
		print("PASS: %s" % message)
	else:
		_failures.append("FAIL: " + message)
