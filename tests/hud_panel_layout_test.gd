extends SceneTree

## Proves the gameplay HUD panels never occlude one another anywhere in the
## supported UI-scale range.
##
## WHY THIS SUITE EXISTS. The accessibility UI-scale work capped the requested
## factor at the largest one whose logical layout "fits"
## ([method GameHUD.compute_effective_ui_scale]), but the panels were authored
## against fixed pixel offsets that needed a 1512 px logical width, while
## [constant GameHUD.MIN_LOGICAL_WIDTH] promised 1180. The gap was not academic:
## at the shipping 1600x900 stretch viewport the ceiling resolves to 1.3043, and
## at that factor the centre-top enemy readout covered the objective card by
## 120x86 viewport px -- the objective text, which tells the player what to do,
## was unreadable. The layout was already colliding at a plain 100% on a 1280x720
## viewport, before any accessibility preset was touched.
##
## The panels were re-anchored to honour the existing contract rather than
## raising it, so both properties hold at once: the ceiling is collision-free
## *and* a 100% request is still never capped on a 1280x720 viewport. Nothing
## here replaces or relaxes an assertion in `tests/accessibility_presets_test.gd`
## -- that suite's "the authored one-to-one presentation is never capped" is
## still true and still asserted there.
##
## Everything below is measured from the real `Control.get_rect()` of the live
## panels, laid out through the same [method GameHUD.layout_for_viewport] the
## running game uses. Nothing is asserted by inspection.

## Worst-case authored strings, taken from the live callers in
## `scripts/game/game_flow.gd`. A layout proof against placeholder text proves
## nothing, because these panels size themselves to their contents.
const LONGEST_OBJECTIVE := "Free flight — explore, fight, or return to a compatible registered berth"
const LONGEST_INTERACTION := "Clear the berth before requesting a return approach"
const LONGEST_TOAST_TITLE := "Welcome back to Mudds Shipyards"
const LONGEST_TOAST_DETAIL := "Guided Torrent test and free-flight fleet access are available"
const LONGEST_ENEMY := "Mudds range defence interceptor"
const LONGEST_PATROL_FAILURE: StringName = &"activity_patrol_desynchronized"

## Viewports the game is expected to run in. 1600x900 is the project's stretch
## viewport, which is what the HUD actually sees under `canvas_items` stretch
## whatever the window size is, so it is swept most densely.
const SUPPORTED_VIEWPORTS := [
	Vector2(1280.0, 720.0),
	Vector2(1600.0, 900.0),
	Vector2(1920.0, 1080.0),
	Vector2(2560.0, 1440.0),
	Vector2(3440.0, 1440.0),
	Vector2(3840.0, 2160.0),
]

## Scales called out in the defect report, kept as named cases so the numbers in
## the report stay checkable.
const REPORTED_SCALES := [1.0, 1.12, 1.14, 1.30, 1.60]

## Two panels closer than this are treated as passing but are reported, so a
## future edit that eats the margin is visible before it becomes a collision.
const CLEARANCE_WATCH := 8.0

## The layout must not merely reach the contract, it must clear it: a layout that
## is clean at exactly the floor and dirty one pixel under it is one font-metric
## change away from the defect returning.
const MINIMUM_HEADROOM := 16.0

var _failures: Array[String] = []
var _hud: GameHUD
var _worst_clearance := INF
var _worst_clearance_label := ""


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_hud = GameHUD.new()
	_hud.name = "PanelLayoutHUD"
	root.add_child(_hud)
	await process_frame
	await _seed_worst_case_content()

	await _test_contract_floor()
	await _test_supported_scale_range()
	await _test_objective_is_never_occluded()
	await _test_ceiling_delivers_the_contract()
	await _test_headroom_below_the_contract()
	_test_uncapped_hundred_percent_still_holds()

	print("MEASURED: tightest clearance anywhere in the supported range -> %.1f logical px (%s)"
		% [_worst_clearance, _worst_clearance_label])
	_hud.queue_free()
	await process_frame
	_finish()


## Drives every panel to the largest content the game ever gives it, and makes
## every panel visible so a hidden one cannot silently skip the proof.
func _seed_worst_case_content() -> void:
	_hud.set("_started", true)
	(_hud.get("_intro") as Control).visible = false
	(_hud.get("_hud") as Control).visible = true
	# Piloting mode publishes the 15-row controls card, the tallest one there is.
	_hud.set_ship_identity("Torrent-class Interceptor", "Interceptor")
	_hud.set_mode("piloting")
	_hud.set_objective(LONGEST_OBJECTIVE)
	_hud.set_activity_objective("Cinder Reach beacon route", {
		"activity_id": &"cinder_reach_checkpoint_route",
		"activity_kind": &"patrol",
		"state_id": &"failed",
		"phase_id": &"failed",
		"generation": 9,
		"session_generation": 9,
		"activity_generation": 12,
		"next_checkpoint_index": 4,
		"checkpoint_count": 5,
		"completed_checkpoint_count": 4,
		"current_time_seconds": 119.9,
		"last_duration_seconds": -1.0,
		"failure_reason": LONGEST_PATROL_FAILURE,
		"terminal_reason": LONGEST_PATROL_FAILURE,
	})
	_hud.set_target_count(2, 3)
	_hud.set_interaction(LONGEST_INTERACTION, true)
	_hud.set_enemy_status(LONGEST_ENEMY, 22.0, 100.0, true)
	_hud.toast(LONGEST_TOAST_TITLE, LONGEST_TOAST_DETAIL, 600.0)
	_hud.set_captions_enabled(true)
	var caption_service := CaptionPresentationService.new()
	var caption_event := CaptionPresentationEvent.new(
		&"layout.worst-visible-cue",
		CaptionPresentationEvent.Category.AMBIENT,
		"S".repeat(CaptionPresentationEvent.MAX_SPEAKER_LENGTH),
		"[ hostile craft destroyed ]",
		12.0,
		90
	)
	_check(caption_event.is_valid(), "worst-case caption event is valid")
	caption_service.enqueue(caption_event)
	var caption_snapshot := caption_service.get_presentation_snapshot()
	_check(
		_hud.apply_caption_presentation_snapshot(caption_snapshot),
		"worst-case caption snapshot reaches the production presenter"
	)
	_hud.update_ship_telemetry({
		"speed": 999.0,
		"altitude": 9999.0,
		"throttle": -1.0,
		"hull": 12.0,
		"maximum_hull": 100.0,
		"damage_status": "critical",
		"engine_power": 0.62,
		"engine_state": "OFFLINE",
	})
	await process_frame
	await process_frame
	var rects := _hud.get_hud_panel_rects()
	_check(
		rects.size() == 8,
		"seven legacy HUD panels plus the snapshot presenter are laid out and measurable (found %d)" % rects.size()
	)


## The contract itself. Every clearance in this layout is monotone in the logical
## size -- the gutters are pinned to the viewport edges while the centre panels
## track the midpoint -- so a clean layout exactly at the floor is a clean layout
## at every larger size, and the sweeps below confirm that empirically.
func _test_contract_floor() -> void:
	var floor_size := Vector2(GameHUD.MIN_LOGICAL_WIDTH, GameHUD.MIN_LOGICAL_HEIGHT)
	var rects := await _layout(floor_size, 1.0)
	var caption_report := _hud.get_caption_presentation_report()
	var caption_panel := caption_report.panel_rect as Rect2
	var caption_speaker := caption_report.speaker_rect as Rect2
	_check(
		str(caption_report.rendered_speaker).length()
			== CaptionPresentationEvent.MAX_SPEAKER_LENGTH
		and caption_speaker.position.x >= caption_panel.position.x
		and caption_speaker.end.x <= caption_panel.end.x,
		"the maximum 64-character speaker stays inside the narrow production host"
	)
	var logical := _hud.get_hud_logical_size()
	var objective_panel := _hud.get("_objective_panel") as Control
	var objective_label := _hud.get("_objective_label") as Label
	var activity_label := _hud.get("_activity_objective_label") as Label
	var target_label := _hud.get("_target_label") as Label
	var objective_panel_rect := objective_panel.get_global_rect()
	_check(
		activity_label.visible
		and "PATROL  FAILED — ACTIVITY PATROL DESYNCHRONIZED  4/5"
		in activity_label.text
		and objective_panel_rect.encloses(activity_label.get_global_rect())
		and objective_panel_rect.encloses(target_label.get_global_rect())
		and not activity_label.get_global_rect().intersects(
			objective_label.get_global_rect()
		)
		and not activity_label.get_global_rect().intersects(
			target_label.get_global_rect()
		),
		"the longest patrol failure remains visible inside the objective card without clipping adjacent rows"
	)
	_check(
		logical.is_equal_approx(floor_size),
		"a viewport at the contract floor lays the panels out at exactly %s (got %s)"
		% [str(floor_size), str(logical)]
	)
	var collisions := _collisions(rects)
	_check(
		collisions.is_empty(),
		"no two panels overlap at the %.0fx%.0f logical floor%s"
		% [floor_size.x, floor_size.y, "" if collisions.is_empty() else " -- " + ", ".join(collisions)]
	)
	var tightest := _tightest_clearance(rects)
	print("MEASURED: at the %.0fx%.0f floor the tightest pair is %s at %.1f logical px"
		% [floor_size.x, floor_size.y, str(tightest["pair"]), float(tightest["clearance"])])
	for key: String in rects:
		var rect: Rect2 = rects[key]
		print("   floor rect %-12s [%.0f,%.0f %.0fx%.0f]"
			% [key, rect.position.x, rect.position.y, rect.size.x, rect.size.y])
	_check(
		float(tightest["clearance"]) > 0.0,
		"the tightest pair at the floor is a gap, not a touch (%.1f px)" % float(tightest["clearance"])
	)


## The regression proper: every supported viewport crossed with every requested
## factor the settings slider can produce, laid out through the shipping code
## path, must leave every pair of panels disjoint.
func _test_supported_scale_range() -> void:
	var dirty: Array[String] = []
	var cases := 0
	for viewport: Vector2 in SUPPORTED_VIEWPORTS:
		var step := 0.02 if viewport.is_equal_approx(Vector2(1600.0, 900.0)) else 0.05
		var requested_scales: Array[float] = []
		var requested := GameHUD.MIN_UI_SCALE
		while requested <= GameHUD.MAX_UI_SCALE + 0.0001:
			requested_scales.append(requested)
			requested += step
		for named: float in REPORTED_SCALES:
			requested_scales.append(named)
		for scale_request: float in requested_scales:
			var rects := await _layout(viewport, scale_request)
			cases += 1
			var collisions := _collisions(rects)
			if not collisions.is_empty():
				dirty.append("%.0fx%.0f @%.2f -> %s"
					% [viewport.x, viewport.y, scale_request, ", ".join(collisions)])
			_record_clearance(rects, "%.0fx%.0f @%.2f" % [viewport.x, viewport.y, scale_request])
	_check(
		dirty.is_empty(),
		"no two HUD panels overlap across %d supported viewport/scale combinations%s"
		% [cases, "" if dirty.is_empty() else " -- " + "; ".join(dirty.slice(0, 6))]
	)

	# The report's named cases, printed with their measured geometry so the
	# before/after numbers in the commit stay checkable against a re-run.
	for viewport: Vector2 in [Vector2(1280.0, 720.0), Vector2(1600.0, 900.0), Vector2(1920.0, 1080.0)]:
		for scale_request: float in REPORTED_SCALES:
			var rects := await _layout(viewport, scale_request)
			var effective := GameHUD.compute_effective_ui_scale(scale_request, viewport)
			var tightest := _tightest_clearance(rects)
			print("MEASURED: %.0fx%.0f request %.2f -> effective %.4f, logical %.0fx%.0f, overlaps %s, tightest %s %.1f px"
				% [
					viewport.x, viewport.y, scale_request, effective,
					_hud.get_hud_logical_size().x, _hud.get_hud_logical_size().y,
					str(_collisions(rects)), str(tightest["pair"]), float(tightest["clearance"]),
				])


## The reported defect was specifically the objective card being covered. It gets
## its own assertion so a future regression names the right thing.
func _test_objective_is_never_occluded() -> void:
	var covered: Array[String] = []
	for viewport: Vector2 in SUPPORTED_VIEWPORTS:
		for scale_request: float in REPORTED_SCALES:
			var rects := await _layout(viewport, scale_request)
			if not rects.has("objective"):
				covered.append("objective panel missing at %s" % str(viewport))
				continue
			var objective: Rect2 = rects["objective"]
			for key: String in rects:
				if key == "objective":
					continue
				var other: Rect2 = rects[key]
				var overlap := objective.intersection(other)
				if overlap.size.x > 0.0 and overlap.size.y > 0.0:
					covered.append("%s covers objective by %.0fx%.0f at %.0fx%.0f @%.2f"
						% [key, overlap.size.x, overlap.size.y, viewport.x, viewport.y, scale_request])
	_check(
		covered.is_empty(),
		"the objective card is never covered by another panel%s"
		% ["" if covered.is_empty() else " -- " + "; ".join(covered.slice(0, 6))]
	)


## The cap is only worth having if it actually delivers the logical size the
## layout was proved against. Above the readable-minimum floor it always does;
## below it [constant GameHUD.MIN_UI_SCALE] deliberately wins, and this states
## exactly where that changeover is instead of leaving it implicit.
func _test_ceiling_delivers_the_contract() -> void:
	var contract := Vector2(GameHUD.MIN_LOGICAL_WIDTH, GameHUD.MIN_LOGICAL_HEIGHT)
	var honoured := true
	var breach := ""
	for width: float in [1180.0, 1280.0, 1366.0, 1600.0, 1920.0, 2560.0, 3840.0]:
		for height: float in [690.0, 720.0, 768.0, 900.0, 1080.0, 1440.0, 2160.0]:
			var viewport := Vector2(width, height)
			for scale_request: float in [0.75, 1.0, 1.2, 1.4, 1.6]:
				var effective := GameHUD.compute_effective_ui_scale(scale_request, viewport)
				var logical := viewport / effective
				if logical.x < contract.x - 0.001 or logical.y < contract.y - 0.001:
					honoured = false
					breach = "%s @%.2f -> logical %s" % [str(viewport), scale_request, str(logical)]
	_check(
		honoured,
		"every viewport at or above the contract resolves to a logical layout at or above it%s"
		% ["" if honoured else " -- " + breach]
	)

	# Below MIN_LOGICAL * MIN_UI_SCALE the readable minimum overrides the ceiling
	# by design, so the logical layout does fall under the contract there.
	var tiny := contract * GameHUD.MIN_UI_SCALE - Vector2(1.0, 1.0)
	var tiny_logical := tiny / GameHUD.compute_effective_ui_scale(1.0, tiny)
	_check(
		tiny_logical.x < contract.x,
		"below %.0fx%.0f the readable minimum wins over the layout ceiling, as designed (logical %s)"
		% [contract.x * GameHUD.MIN_UI_SCALE, contract.y * GameHUD.MIN_UI_SCALE, str(tiny_logical)]
	)


## Headroom. A layout that is clean at exactly the contract and dirty one pixel
## under it would be one font-metric change away from the defect returning, so
## the margin is measured and asserted rather than hoped for.
func _test_headroom_below_the_contract() -> void:
	var width_floor := await _smallest_clean_axis(true)
	var height_floor := await _smallest_clean_axis(false)
	var width_headroom := GameHUD.MIN_LOGICAL_WIDTH - float(width_floor["smallest_clean"])
	var height_headroom := GameHUD.MIN_LOGICAL_HEIGHT - float(height_floor["smallest_clean"])
	print("MEASURED: smallest collision-free logical width %.0f px (%.0f px of headroom), first collision %s"
		% [float(width_floor["smallest_clean"]), width_headroom, str(width_floor["first_collision"])])
	print("MEASURED: smallest collision-free logical height %.0f px (%.0f px of headroom), first collision %s"
		% [float(height_floor["smallest_clean"]), height_headroom, str(height_floor["first_collision"])])
	_check(
		width_headroom >= MINIMUM_HEADROOM,
		"the layout stays clean at least %.0f px below the contract width (measured %.0f px)"
		% [MINIMUM_HEADROOM, width_headroom]
	)
	_check(
		height_headroom >= MINIMUM_HEADROOM,
		"the layout stays clean at least %.0f px below the contract height (measured %.0f px)"
		% [MINIMUM_HEADROOM, height_headroom]
	)


## Walks one axis of the logical layout downwards from the contract until a pair
## collides, and reports where. A viewport this small pins the effective factor
## at [constant GameHUD.MIN_UI_SCALE], which is the one case where the logical
## layout drops below the contract, so these sizes are reachable rather than
## synthetic.
func _smallest_clean_axis(sweep_width: bool) -> Dictionary:
	var size := Vector2(GameHUD.MIN_LOGICAL_WIDTH, GameHUD.MIN_LOGICAL_HEIGHT)
	var smallest_clean: float = size.x if sweep_width else size.y
	var first_collision: Array[String] = []
	for step in 60:
		var probe := size
		if sweep_width:
			probe.x -= float(step) * 2.0
		else:
			probe.y -= float(step) * 2.0
		var rects := await _layout(probe * GameHUD.MIN_UI_SCALE, 1.0)
		var collisions := _collisions(rects)
		if not collisions.is_empty():
			first_collision = collisions
			break
		smallest_clean = probe.x if sweep_width else probe.y
	return {"smallest_clean": smallest_clean, "first_collision": first_collision}


## The property the previous agent refused to trade away. It is restated here
## because this suite's fix is only correct if it did not cost that property --
## the assertion itself still lives in `tests/accessibility_presets_test.gd`.
func _test_uncapped_hundred_percent_still_holds() -> void:
	_check(
		is_equal_approx(GameHUD.compute_effective_ui_scale(1.0, Vector2(1280.0, 720.0)), 1.0),
		"a 100% request on a 1280x720 viewport is still uncapped after the re-anchoring"
	)
	_check(
		GameHUD.MIN_LOGICAL_WIDTH <= 1280.0 and GameHUD.MIN_LOGICAL_HEIGHT <= 720.0,
		"the layout contract stays inside 1280x720, which is what keeps 100% uncapped there"
	)


func _layout(viewport: Vector2, requested: float) -> Dictionary:
	_hud.set_ui_scale(requested)
	_hud.layout_for_viewport(viewport)
	await process_frame
	await process_frame
	return _hud.get_hud_panel_rects()


func _collisions(rects: Dictionary) -> Array[String]:
	var keys: Array = rects.keys()
	keys.sort()
	var out: Array[String] = []
	for i in keys.size():
		for j in range(i + 1, keys.size()):
			var a: Rect2 = rects[keys[i]]
			var b: Rect2 = rects[keys[j]]
			var overlap := a.intersection(b)
			if overlap.size.x > 0.0 and overlap.size.y > 0.0:
				out.append("%s/%s %.0fx%.0f" % [keys[i], keys[j], overlap.size.x, overlap.size.y])
	return out


## Smallest axis separation between any pair, in logical px. Two rectangles are
## disjoint when they are separated on at least one axis, so the clearance of a
## pair is the larger of its two axis gaps.
func _tightest_clearance(rects: Dictionary) -> Dictionary:
	var keys: Array = rects.keys()
	keys.sort()
	var best := INF
	var pair := ""
	for i in keys.size():
		for j in range(i + 1, keys.size()):
			var a: Rect2 = rects[keys[i]]
			var b: Rect2 = rects[keys[j]]
			var horizontal := maxf(a.position.x - b.end.x, b.position.x - a.end.x)
			var vertical := maxf(a.position.y - b.end.y, b.position.y - a.end.y)
			var clearance := maxf(horizontal, vertical)
			if clearance < best:
				best = clearance
				pair = "%s/%s" % [keys[i], keys[j]]
	return {"clearance": best, "pair": pair}


func _record_clearance(rects: Dictionary, label: String) -> void:
	var tightest := _tightest_clearance(rects)
	var clearance := float(tightest["clearance"])
	if clearance < _worst_clearance:
		_worst_clearance = clearance
		_worst_clearance_label = "%s, %s" % [str(tightest["pair"]), label]
	if clearance < CLEARANCE_WATCH:
		print("WATCH: %s clears by only %.1f logical px at %s" % [str(tightest["pair"]), clearance, label])


func _check(condition: bool, description: String) -> void:
	if condition:
		print("PASS: ", description)
	else:
		_failures.append(description)
		push_error("FAIL: " + description)


func _finish() -> void:
	if _failures.is_empty():
		print("HUD_PANEL_LAYOUT_TEST_OK")
		quit(0)
	else:
		print("HUD_PANEL_LAYOUT_TEST_FAILED: ", ", ".join(_failures))
		quit(1)
