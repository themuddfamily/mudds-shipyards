extends SceneTree

## Focused layout and authority contract for the reusable visual presenter.

const PRESENTER_SCENE := preload("res://scenes/ui/caption_presenter.tscn")
const VIEWPORTS := [
	Vector2i(1280, 720),
	Vector2i(1920, 1080),
	Vector2i(1920, 1200),
	Vector2i(3440, 1440),
]
const UI_SCALES := [0.75, 0.8, 1.0, 1.5, 1.6]

var _assertions := 0
var _failures: Array[String] = []


func _initialize() -> void:
	_run()


func _run() -> void:
	var viewport := SubViewport.new()
	viewport.name = "CaptionLayoutViewport"
	viewport.size = Vector2i(1280, 720)
	viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	root.add_child(viewport)
	var presenter := PRESENTER_SCENE.instantiate() as CaptionPresenter
	viewport.add_child(presenter)
	await process_frame
	await _test_contract_and_snapshot_boundary(presenter)
	await _test_supported_layout_sweep(viewport, presenter)
	await _test_detached_layout_currentness(viewport, presenter)
	await _test_queued_layout_currentness(viewport)
	await _test_hidden_and_reduced_flash(presenter)
	_test_authority_audit(presenter)
	presenter.queue_free()
	viewport.queue_free()
	await process_frame
	_finish()


func _test_contract_and_snapshot_boundary(presenter: CaptionPresenter) -> void:
	var contract := presenter.get_layout_contract()
	_check(
		float(contract.minimum_ui_scale) == 0.75
		and float(contract.maximum_ui_scale) == 1.6
		and float(contract.base_minimum_panel_width) == 560.0
		and float(contract.base_maximum_panel_width) == 960.0
		and float(contract.base_minimum_panel_height) == 104.0
		and float(contract.base_safe_margin_x) == 32.0
		and float(contract.base_safe_margin_top) == 24.0
		and float(contract.base_safe_margin_bottom) == 42.0
		and contract.host_bottom_safe_margin_unit == &"physical_viewport_pixels"
		and contract.maximum_panel_height_policy == &"viewport_minus_scaled_safe_top_and_bottom"
		and int(contract.maximum_text_characters) == 512,
		"layout contract freezes exact UI-scale, panel, safe-area and text bounds"
	)
	_check(
		not presenter.set_ui_scale(0.74)
		and not presenter.set_ui_scale(1.61)
		and not presenter.set_ui_scale(NAN)
		and is_equal_approx(presenter.get_ui_scale(), 1.0),
		"UI scale outside 0.75..1.6 rejects without changing committed scale"
	)
	_check(
		presenter.set_host_bottom_safe_margin(272.0)
		and not presenter.set_host_bottom_safe_margin(-1.0)
		and not presenter.set_host_bottom_safe_margin(NAN),
		"a host can reserve a validated physical bottom band without weakening other safe margins"
	)
	presenter.clear_host_bottom_safe_margin()
	var source := _snapshot(false, "Detached snapshot text.")
	_check(presenter.apply_presentation_snapshot(source), "valid service presentation snapshot is accepted")
	(source.caption as Dictionary)["text"] = "caller mutation"
	var detached := presenter.get_applied_snapshot()
	(detached.caption as Dictionary)["speaker"] = "snapshot mutation"
	await _settle()
	var report := presenter.get_layout_report()
	_check(
		str(report.rendered_text) == "Detached snapshot text."
		and str(report.rendered_speaker) == "Mudds Controller"
		and str(presenter.get_applied_snapshot().caption.speaker) == "Mudds Controller",
		"input and returned presentation snapshots are deeply detached from rendered state"
	)
	var before := presenter.get_applied_snapshot()
	var malformed := _snapshot(false, "Malformed")
	malformed["service_id"] = &"lookalike"
	_check(not presenter.apply_presentation_snapshot(malformed) and presenter.get_applied_snapshot() == before, "non-service snapshot lookalikes reject without visual mutation")
	var mismatched_category := _snapshot(false, "Malformed")
	(mismatched_category.caption as Dictionary)["category_id"] = &"system"
	_check(not presenter.apply_presentation_snapshot(mismatched_category), "category integer and colour-independent label ID must agree")
	var wrong_scalar_types := _snapshot(false, "Malformed")
	wrong_scalar_types["generation"] = "3"
	(wrong_scalar_types.caption as Dictionary).erase("sequence")
	_check(
		not presenter.apply_presentation_snapshot(wrong_scalar_types),
		"service generation and caption sequence retain their exact scalar types"
	)


func _test_supported_layout_sweep(viewport: SubViewport, presenter: CaptionPresenter) -> void:
	var failures := PackedStringArray()
	var cases := 0
	var long_text := _maximum_text()
	for viewport_size: Vector2i in VIEWPORTS:
		viewport.size = viewport_size
		for scale: float in UI_SCALES:
			presenter.set_ui_scale(scale)
			presenter.apply_presentation_snapshot(_snapshot(false, long_text))
			await _settle()
			var report := presenter.get_layout_report()
			var panel := report.panel_rect as Rect2
			var safe := report.safe_rect as Rect2
			var available_width := float(viewport_size.x) - 2.0 * CaptionPresenter.BASE_SAFE_MARGIN_X * scale
			var expected_width := minf(CaptionPresenter.BASE_MAX_PANEL_WIDTH * scale, available_width)
			var inside_safe := (
				panel.position.x >= safe.position.x - 0.51
				and panel.end.x <= safe.end.x + 0.51
				and panel.position.y >= safe.position.y - 0.51
				and panel.end.y <= safe.end.y + 0.51
			)
			var dimensions_valid := (
				is_equal_approx(panel.size.x, expected_width)
				and panel.size.y >= CaptionPresenter.BASE_MIN_PANEL_HEIGHT * scale - 0.51
				and panel.size.y <= float(report.panel_maximum_height) + 0.51
			)
			var typography_valid := (
				str(report.rendered_category) == "[ RADIO ]"
				and str(report.rendered_speaker) == "Mudds Controller"
				and str(report.rendered_text).length() == 512
				and int(report.text_line_count) > 1
				and not bool(report.text_clipped)
			)
			if not inside_safe or not dimensions_valid or not typography_valid:
				failures.append(
					"%dx%d @ %.1f panel=%s safe=%s content=%.1f text=%s"
					% [
						viewport_size.x,
						viewport_size.y,
						scale,
						str(panel),
						str(safe),
						float(report.text_content_height),
						str(report.text_rect),
					]
				)
			print(
				"MEASURED caption layout %dx%d @ %.2f panel=%s lines=%d content=%.1f"
				% [
					viewport_size.x,
					viewport_size.y,
					scale,
					str(panel),
					int(report.text_line_count),
					float(report.text_content_height),
				]
			)
			cases += 1
	_check(
		failures.is_empty(),
		"512-character text wraps without clipping inside safe bounds across %d 1280x720/16:9/16:10/ultrawide scale cases%s"
		% [cases, "" if failures.is_empty() else " -- " + "; ".join(failures)]
	)
	_check(
		_contrast_ratio(CaptionPresenter.TEXT_INK, CaptionPresenter.PANEL_BACKGROUND) >= 7.0
		and _contrast_ratio(CaptionPresenter.SPEAKER_INK, CaptionPresenter.PANEL_BACKGROUND) >= 7.0
		and _contrast_ratio(CaptionPresenter.CATEGORY_INK, CaptionPresenter.PANEL_BACKGROUND) >= 7.0
		and _contrast_ratio(CaptionPresenter.PANEL_BORDER, CaptionPresenter.PANEL_BACKGROUND) >= 7.0,
		"body, speaker, category and border each retain high contrast against the panel"
	)


func _test_detached_layout_currentness(viewport: SubViewport, presenter: CaptionPresenter) -> void:
	presenter.set_ui_scale(1.0)
	presenter.apply_presentation_snapshot(_snapshot(false, "Retained layout baseline."))
	await _settle()
	var baseline := presenter.get_layout_report()
	presenter.set_ui_scale(1.5)
	viewport.remove_child(presenter)
	await process_frame
	await process_frame
	var detached := presenter.get_layout_report()
	_check(
		not presenter.is_inside_tree()
		and (detached.panel_rect as Rect2).is_equal_approx(baseline.panel_rect as Rect2),
		"detached deferred layout leaves the retained panel geometry unchanged"
	)
	viewport.add_child(presenter)
	await _settle()
	var reentered := presenter.get_layout_report()
	_check(
		presenter.is_inside_tree()
		and is_equal_approx(float(reentered.ui_scale), 1.5)
		and not (reentered.panel_rect as Rect2).is_equal_approx(baseline.panel_rect as Rect2),
		"re-entry schedules one current layout pass using the retained scale and live viewport"
	)


func _test_queued_layout_currentness(viewport: SubViewport) -> void:
	var queued := PRESENTER_SCENE.instantiate() as CaptionPresenter
	viewport.add_child(queued)
	await _settle()
	queued.set_ui_scale(1.5)
	var token := int(queued.get("_layout_token"))
	var before := queued.get_layout_report()
	queued.queue_free()
	queued.call("_layout_pass_one", token)
	queued.call("_layout_pass_two", token)
	var after := queued.get_layout_report()
	_check(
		queued.is_inside_tree()
		and queued.is_queued_for_deletion()
		and (after.panel_rect as Rect2).is_equal_approx(before.panel_rect as Rect2),
		"queued-but-live presenter rejects its pending layout callback before Control mutation"
	)
	await process_frame


func _test_hidden_and_reduced_flash(presenter: CaptionPresenter) -> void:
	presenter.set_ui_scale(1.0)
	presenter.apply_presentation_snapshot(_snapshot(false, "Standard immediate presentation."))
	await _settle()
	var standard := presenter.get_layout_report()
	presenter.apply_presentation_snapshot(_snapshot(true, "Reduced-flash steady presentation."))
	await _settle()
	var reduced := presenter.get_layout_report()
	_check(
		standard.transition_policy == &"consumer_standard"
		and reduced.transition_policy == &"steady_no_flash"
		and int(reduced.animation_player_count) == 0
		and int(reduced.owned_tween_count) == 0
		and int(reduced.tween_count) == 0
		and presenter.modulate == Color.WHITE
		and presenter.self_modulate == Color.WHITE,
		"reduced-flash snapshots commit a steady full-opacity presentation with no animation owner"
	)
	var hidden := _hidden_snapshot(true)
	_check(presenter.apply_presentation_snapshot(hidden), "hidden service snapshot is accepted")
	await _settle()
	var hidden_report := presenter.get_layout_report()
	_check(
		not presenter.visible
		and not bool(hidden_report.visible)
		and bool(hidden_report.input_transparent)
		and str(hidden_report.rendered_category).is_empty()
		and str(hidden_report.rendered_speaker).is_empty()
		and str(hidden_report.rendered_text).is_empty(),
		"hidden snapshots are invisible, stale-text-free and input-transparent"
	)


func _test_authority_audit(presenter: CaptionPresenter) -> void:
	var first := presenter.audit()
	var second := presenter.audit()
	_check(
		bool(first.valid)
		and first == second
		and first.snapshot_input == &"caption_presentation_service_presentation_dictionary_only"
		and first.reduced_flash_policy == &"steady_no_animation"
		and not bool(first.audio_authority)
		and not bool(first.gameplay_authority)
		and not bool(first.activity_authority)
		and not bool(first.reward_authority)
		and not bool(first.ship_authority)
		and not bool(first.berth_authority),
		"deterministic audit grants only reusable caption presentation authority"
	)
	(first.layout_contract as Dictionary)["base_maximum_panel_width"] = -1.0
	_check(float(presenter.audit().layout_contract.base_maximum_panel_width) == 960.0, "audit dictionaries are deeply detached")


func _snapshot(reduced_flash: bool, text: String) -> Dictionary:
	return {
		"schema_version": 1,
		"service_id": &"caption-presentation-service",
		"generation": 3,
		"revision": 9,
		"visible": true,
		"captions_enabled": true,
		"reduced_flash": reduced_flash,
		"transition_policy": &"steady_no_flash" if reduced_flash else &"consumer_standard",
		"caption": {
			"stable_id": &"radio.layout-proof",
			"category": CaptionPresentationEvent.Category.RADIO,
			"category_id": &"radio",
			"speaker": "Mudds Controller",
			"text": text,
			"duration_physics_seconds": 12.0,
			"remaining_physics_seconds": 8.5,
			"priority": 70,
			"sequence": 4,
		},
	}.duplicate(true)


func _hidden_snapshot(reduced_flash: bool) -> Dictionary:
	return {
		"schema_version": 1,
		"service_id": &"caption-presentation-service",
		"generation": 3,
		"revision": 10,
		"visible": false,
		"captions_enabled": false,
		"reduced_flash": reduced_flash,
		"transition_policy": &"steady_no_flash" if reduced_flash else &"consumer_standard",
		"caption": {},
	}


func _maximum_text() -> String:
	var seed := "WIDE CAPTION ROUTE STATUS — maintain corridor separation while traffic clears the fabrication annex. "
	var result := ""
	while result.length() < CaptionPresentationEvent.MAX_TEXT_LENGTH:
		result += seed
	return result.substr(0, CaptionPresentationEvent.MAX_TEXT_LENGTH)


func _settle() -> void:
	for _frame in 5:
		await process_frame


func _contrast_ratio(first: Color, second: Color) -> float:
	var a := _relative_luminance(first)
	var b := _relative_luminance(second)
	return (maxf(a, b) + 0.05) / (minf(a, b) + 0.05)


func _relative_luminance(color: Color) -> float:
	var linear := color.srgb_to_linear()
	return 0.2126 * linear.r + 0.7152 * linear.g + 0.0722 * linear.b


func _check(condition: bool, message: String) -> void:
	_assertions += 1
	if condition:
		print("PASS: ", message)
	else:
		_failures.append(message)
		push_error("FAIL: %s" % message)


func _finish() -> void:
	if _failures.is_empty():
		print("CAPTION_PRESENTER_LAYOUT_TEST_OK: %d assertions" % _assertions)
		quit(0)
		return
	printerr("CAPTION_PRESENTER_LAYOUT_TEST_FAILED: %s" % "; ".join(_failures))
	quit(1)
