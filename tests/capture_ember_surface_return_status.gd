extends SceneTree

## Production-scale Forward+ witness of every Ember return state through the
## real retained HUD adapter/card. The fixture mutates presentation evidence
## only; it owns no return-loop, boarding, movement, or reward authority.

class FakeBinding:
	extends RefCounted
	signal presentation_changed(view: Dictionary)
	var view: Dictionary = {}
	func get_presenter_snapshot() -> Dictionary:
		return view.duplicate(true)
	func publish(next: Dictionary) -> void:
		view = next.duplicate(true)
		presentation_changed.emit(view.duplicate(true))


const PresenterType := preload("res://scripts/ui/ember_surface_return_status_presenter.gd")
const AdapterType := preload("res://scripts/ui/ember_surface_return_hud_adapter.gd")
const HudType := preload("res://scripts/ui/hud.gd")
const CAPTURE_SIZE := Vector2i(2560, 1440)
const OUTPUT_DIR := "/tmp/mudds-wave33-ember-return-status-frames"
const CONTACT_PATH := OUTPUT_DIR + "/ember_return_status_contact_sheet.png"
const ROSTER := [
	["01_descent", &"descent", true, {}],
	["02_landed", &"landed", true, {}],
	["03_on_foot", &"on_foot", true, {}],
	["04_return_manifest", &"on_foot", true, {"accepted": true, "reason": &"return_manifest_ready"}],
	["05_reboard", &"reboard", true, {}],
	["06_reboarded", &"reboarded", true, {}],
	["07_takeoff", &"takeoff", true, {}],
	["08_ascent", &"ascent", true, {}],
	["09_orbit_return", &"orbit_return", true, {}],
	["10_blocked", &"on_foot", true, {"accepted": false, "reason": &"return_manifest_denied"}],
	["11_detached", &"on_foot", false, {}],
]

var _failures: PackedStringArray = []


func _init() -> void:
	call_deferred(&"_run")


func _run() -> void:
	root.size = CAPTURE_SIZE
	root.content_scale_size = Vector2i.ZERO
	_check(
		RenderingServer.get_current_rendering_method() == &"forward_plus"
			and not RenderingServer.get_video_adapter_name().is_empty(),
		"capture uses a live Forward+ Vulkan renderer",
	)
	var hud := HudType.new()
	root.add_child(hud)
	await process_frame
	await process_frame
	var intro := hud.get("_intro") as Control
	if intro != null:
		intro.visible = false
	var live_hud := hud.get("_hud") as Control
	if live_hud != null:
		live_hud.visible = true
	var presenter := PresenterType.new()
	var binding := FakeBinding.new()
	binding.view = presenter.present(_snapshot(1, ROSTER[0]))
	var adapter := AdapterType.new()
	_check(
		bool((adapter.call(&"attach", binding, hud) as Dictionary).get("accepted", false)),
		"existing production HUD adapter accepts the state presenter",
	)
	var title := hud.get("_runtime_status_title") as Label
	var runtime_panel := hud.get("_runtime_status_panel") as PanelContainer
	var title_hashes := {}
	var titles := {}
	var card_images: Array[Image] = []
	DirAccess.make_dir_recursive_absolute(OUTPUT_DIR)
	for index in ROSTER.size():
		var row := ROSTER[index] as Array
		var view := binding.view if index == 0 else presenter.present(
			_snapshot(index + 1, row)
		)
		if index > 0:
			binding.publish(view)
		for _frame in 3:
			await process_frame
		await RenderingServer.frame_post_draw
		var expected_title := str(view.get("visible_title", ""))
		_check(
			runtime_panel != null and runtime_panel.visible and title != null
				and title.visible and title.text == expected_title,
			"%s reaches the retained production HUD title" % row[0],
		)
		_check(_title_fits(title), "%s title fits without ellipsis or clipping" % row[0])
		_check(not titles.has(title.text), "%s title text differs from every prior state" % row[0])
		titles[title.text] = true
		var image := root.get_texture().get_image()
		_check(
			image != null and not image.is_empty() and image.get_size() == CAPTURE_SIZE,
			"%s renders a real 2560x1440 frame" % row[0],
		)
		if image == null or image.is_empty():
			continue
		var header := image.get_region(_pixel_rect(title.get_global_rect(), image.get_size(), 2))
		var header_hash := _image_hash(header)
		_check(
			not title_hashes.has(header_hash),
			"%s visible header pixels differ from every prior production state" % row[0],
		)
		title_hashes[header_hash] = true
		var output_path := OUTPUT_DIR.path_join(str(row[0]) + ".png")
		_check(image.save_png(output_path) == OK, "%s frame saves successfully" % row[0])
		card_images.append(image.get_region(_pixel_rect(
			runtime_panel.get_global_rect(), image.get_size(), 2
		)))
		print("EMBER_SURFACE_RETURN_STATUS_FRAME: ", output_path)
	_check(
		titles.size() == 11 and title_hashes.size() == 11 and card_images.size() == 11,
		"all 11 production states have unique visible title text and rendered header pixels",
	)
	if card_images.size() == 11:
		_check(_save_contact_sheet(card_images) == OK, "11-state HUD contact sheet saves successfully")
		print("EMBER_SURFACE_RETURN_STATUS_CONTACT_SHEET: ", CONTACT_PATH)
	adapter.call(&"detach")
	hud.queue_free()
	await process_frame
	if _failures.is_empty():
		print("EMBER_SURFACE_RETURN_STATUS_CAPTURE_OK")
		quit(0)
		return
	for failure in _failures:
		push_error("EMBER_SURFACE_RETURN_STATUS_CAPTURE_FAILED: " + failure)
	quit(1)


func _snapshot(generation: int, row: Array) -> Dictionary:
	return {
		"generation": generation,
		"host": {"phase_id": row[1], "attached": row[2]},
		"binding": {"attached": row[2]},
		"last_result": (row[3] as Dictionary).duplicate(true),
	}.duplicate(true)


func _title_fits(title: Label) -> bool:
	if title == null or title.text.is_empty() or title.text.contains("\n"):
		return false
	var font := title.get_theme_font(&"font")
	var font_size := title.get_theme_font_size(&"font_size")
	var text_size := font.get_string_size(
		title.text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size
	)
	return text_size.x <= title.size.x + 0.5 \
		and font.get_height(font_size) <= title.size.y + 0.5


func _pixel_rect(rect: Rect2, image_size: Vector2i, padding: int) -> Rect2i:
	var left := clampi(floori(rect.position.x) - padding, 0, image_size.x - 1)
	var top := clampi(floori(rect.position.y) - padding, 0, image_size.y - 1)
	var right := clampi(ceili(rect.end.x) + padding, left + 1, image_size.x)
	var bottom := clampi(ceili(rect.end.y) + padding, top + 1, image_size.y)
	return Rect2i(left, top, right - left, bottom - top)


func _image_hash(image: Image) -> String:
	var context := HashingContext.new()
	context.start(HashingContext.HASH_SHA256)
	context.update(image.get_data())
	return context.finish().hex_encode()


func _save_contact_sheet(cards: Array[Image]) -> Error:
	var card_size := cards[0].get_size()
	var columns := 3
	var rows := ceili(float(cards.size()) / float(columns))
	var sheet := Image.create(
		card_size.x * columns, card_size.y * rows, false, cards[0].get_format()
	)
	sheet.fill(Color("10151d"))
	for index in cards.size():
		var card := cards[index]
		sheet.blit_rect(
			card, Rect2i(Vector2i.ZERO, card_size),
			Vector2i((index % columns) * card_size.x, (index / columns) * card_size.y),
		)
	return sheet.save_png(CONTACT_PATH)


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
