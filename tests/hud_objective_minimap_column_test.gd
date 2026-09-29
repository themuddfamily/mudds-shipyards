extends SceneTree

## The objective card and the minimap share the left gutter. At a large UI
## scale the logical height falls to the 690 px floor, and the start-of-shift
## boarding objective (three wrapped lines) plus a live activity row made the
## card run 12 px into the minimap, hiding the card's last row. The minimap
## must yield to the card while staying readable and inside the safe
## band, and must return to its authored size once the card shrinks.

const Contract := preload("res://scripts/ui/ultrawide_safe_area_contract.gd")
const BOARDING_OBJECTIVE := (
	"Board the Torrent interceptor for the guided test — other berthed craft are available for free sorties"
)
const HEAVY_BREACH := {
	"activity_id": &"shipyard_heavy_breach",
	"generation": 7,
	"protected_objective": "Habitat Core",
	"director": {
		"state": &"running", "scenario": &"heavy_breach", "outcome": &"pending",
		"launched": true, "elapsed": 12.5, "scenario_generation": 7,
		"protected_anchor": "Habitat Core", "breach_picket": "Heavy Picket",
		"board_sortie": true,
	},
	"reward_handoff": {"configured": true, "last_result": {}},
}
## Logical viewports the HUD sees under canvas_items/expand stretch: 16:9,
## 21:9, 32:9 and 4:3 windows, plus a raw 1280x720 viewport.
const VIEWPORTS := [
	Vector2(1600, 900), Vector2(2150, 900), Vector2(3200, 900),
	Vector2(1600, 1200), Vector2(1280, 720),
]
const SCALES := [1.0, 1.3, 1.6]
const AUTHORED_MINIMAP := 240.0

var _assertions := 0
var _failures: PackedStringArray = []


func _init() -> void:
	call_deferred(&"_run")


func _run() -> void:
	var hud := GameHUD.new()
	root.add_child(hud)
	await process_frame
	hud.set("_started", true)
	(hud.get("_intro") as Control).visible = false
	(hud.get("_hud") as Control).visible = true
	hud.set_mode("on-foot")
	hud.set_objective(BOARDING_OBJECTIVE)
	hud.set_activity_objective("Heavy breach", HEAVY_BREACH)
	hud.set_target_count(0, 4)
	var objective := hud.get("_objective_panel") as Control
	var minimap := hud.get("_minimap") as Control
	for viewport: Vector2 in VIEWPORTS:
		for requested: float in SCALES:
			hud.set_ui_scale(requested)
			hud.layout_for_viewport(viewport)
			await process_frame
			await process_frame
			var label := "%dx%d @%.1f" % [viewport.x, viewport.y, requested]
			var rects := hud.get_hud_panel_rects()
			var objective_rect := rects["objective"] as Rect2
			var minimap_rect := rects["minimap"] as Rect2
			_check(
				not objective_rect.intersects(minimap_rect),
				"%s: the objective card %s clears the minimap %s"
				% [label, objective_rect, minimap_rect]
			)
			var effective := float(hud.get("_layout_effective_ui_scale"))
			var safe := Contract.safe_rect(viewport, effective)
			var physical := Rect2(minimap_rect.position * effective, minimap_rect.size * effective)
			_check(
				safe.grow(0.5).encloses(physical),
				"%s: the minimap stays inside the safe band" % label
			)
			_check(
				minimap_rect.size.x >= minimap.custom_minimum_size.x - 0.01
				and minimap_rect.size.y >= minimap.custom_minimum_size.y - 0.01,
				"%s: the minimap keeps at least its minimum size (%s)"
				% [label, minimap_rect.size]
			)
			_check(
				objective.get_global_rect().encloses(
					(hud.get("_target_label") as Control).get_global_rect()
				),
				"%s: the card's last row is inside the card" % label
			)
	# The minimap returns to its authored footprint once the card is short again.
	hud.clear_activity_objective()
	hud.set_objective("Launch")
	hud.set_ui_scale(1.6)
	hud.layout_for_viewport(Vector2(1600, 900))
	for _frame in 3:
		await process_frame
	var restored := hud.get_hud_panel_rects()["minimap"] as Rect2
	_check(
		is_equal_approx(restored.size.x, AUTHORED_MINIMAP)
		and restored.size.y >= AUTHORED_MINIMAP,
		"a short objective restores the authored minimap size (%s)" % restored.size
	)
	hud.queue_free()
	await process_frame
	if _failures.is_empty():
		print("HUD_OBJECTIVE_MINIMAP_COLUMN_TEST_OK (%d assertions)" % _assertions)
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)


func _check(condition: bool, message: String) -> void:
	_assertions += 1
	if not condition:
		_failures.append("FAIL: " + message)
