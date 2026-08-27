extends SceneTree

## Six-state production HUD witness. Run display-backed at 1600x900 so the
## actual 112 px public card, its scroll clip, and the shipping font participate.

const Adapter := preload("res://scripts/ui/cinder_navigator_ping_hud_adapter.gd")
const Presenter := preload("res://scripts/ui/cinder_navigator_ping_presenter.gd")
const Hud := preload("res://scripts/ui/hud.gd")

const STATE_CASES := [
	[&"active", "active"],
	[&"cleared", "clear"],
	[&"available", "ready"],
	[&"detached", "detached"],
	[&"stale", "stale"],
	[&"rejected", "rejected"],
]

var _assertions := 0
var _failures := PackedStringArray()
var _production_card_size := Vector2.ZERO
var _production_card_node_count := -1


func _init() -> void:
	call_deferred(&"_run")


func _run() -> void:
	_check(RenderingServer.get_current_rendering_method() == &"forward_plus", "capture uses the Forward+ renderer")
	_check(DisplayServer.get_name() == "X11", "capture uses the display-backed X11 path")
	_check(root.size == Vector2i(1600, 900), "capture viewport is exactly 1600x900")

	var background := ColorRect.new()
	background.color = Color("071321")
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(background)
	var hud := Hud.new()
	hud.name = "CinderNavigatorPingProductionHud"
	root.add_child(hud)
	await process_frame
	# Enter the same public HUD layer that normal interact/jump input reveals.
	# Reduced motion makes the production intro transition deterministic here.
	hud.set("_reduced_motion", true)
	hud.call("_begin")
	await process_frame
	await process_frame

	var presenter := Presenter.new()
	var adapter := Adapter.new()
	_check(bool(adapter.attach(hud, presenter).get("accepted", false)), "adapter binds the real production HUD")
	var base := {
		"roles": {
			&"pilot": {"occupant": "pilot_avatar", "available": false},
			&"gunner": {"occupant": "", "available": true},
			&"engineer": {"occupant": "engineer_avatar", "available": false},
			&"passenger": {"occupant": "navigator_avatar", "available": false, "seat_id": &"cinder_navigator_station"},
		},
		"actor_id": "navigator_avatar",
	}
	var views := _state_views()
	var output_root := OS.get_environment("NAVIGATOR_PING_CAPTURE_DIR").strip_edges()
	if output_root.is_empty():
		output_root = ProjectSettings.globalize_path("user://navigator_ping_capture")
	_check(DirAccess.make_dir_recursive_absolute(output_root) == OK, "capture output directory is available")

	var image_payloads: Array[PackedByteArray] = []
	var visible_texts := {}
	for state_case: Array in STATE_CASES:
		var state := StringName(state_case[0])
		var file_stem := str(state_case[1])
		var applied: Dictionary = adapter.apply_view(views.get(state, {}) as Dictionary, base)
		_check(bool(applied.get("accepted", false)) and applied.get("source_state") == state, "%s presenter view reaches the real HUD" % state)
		await process_frame
		RenderingServer.force_draw()
		await process_frame
		var title := hud.get("_runtime_status_title") as Label
		var detail := hud.get("_runtime_status_detail") as Label
		var panel := hud.get("_runtime_status_panel") as PanelContainer
		var scroll := hud.get("_runtime_status_scroll") as ScrollContainer
		var visible_text := "%s\n%s" % [title.text, detail.text.get_slice("\n", 0)]
		_check(not visible_texts.has(visible_text), "%s has production-visible text distinct from every prior state" % state)
		visible_texts[visible_text] = state
		_inspect_card_clip(state, panel, title, detail, scroll)

		var image := root.get_texture().get_image()
		_check(image != null and image.get_size() == Vector2i(1600, 900), "%s capture returns a 1600x900 image" % state)
		var output_path := output_root.path_join(file_stem + ".png")
		_check(image.save_png(output_path) == OK, "%s Forward+ PNG saves" % state)
		var png_bytes := FileAccess.get_file_as_bytes(output_path)
		var bytes_unique := true
		for prior_bytes: PackedByteArray in image_payloads:
			bytes_unique = bytes_unique and png_bytes != prior_bytes
		_check(bytes_unique, "%s PNG bytes differ from every prior navigator state" % state)
		image_payloads.append(png_bytes)

	_check(visible_texts.size() == 6 and image_payloads.size() == 6, "all six navigator states have distinct visible text and rendered PNG bytes")
	adapter.detach()
	hud.queue_free()
	background.queue_free()
	await process_frame
	if _failures.is_empty():
		print("CINDER_NAVIGATOR_PING_HUD_RENDER_TEST_OK: %d checks; captures=%s" % [_assertions, output_root])
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)


func _inspect_card_clip(
		state: StringName,
		panel: PanelContainer,
		title: Label,
		detail: Label,
		scroll: ScrollContainer
	) -> void:
	_check(panel != null and panel.visible and panel.size.y == 112.0 and panel.size.x >= 396.0, "%s keeps the unchanged 112 px public-card band" % state)
	var node_count := panel.find_children("*").size()
	if _production_card_size == Vector2.ZERO:
		_production_card_size = panel.size
		_production_card_node_count = node_count
	_check(panel.size == _production_card_size and node_count == _production_card_node_count, "%s preserves production card layout and node density" % state)
	var panel_rect := panel.get_global_rect()
	var title_rect := title.get_global_rect()
	var scroll_rect := scroll.get_global_rect()
	var detail_rect := detail.get_global_rect()
	_check(panel_rect.encloses(title_rect), "%s headline remains inside the fixed card clip" % state)
	var visible_detail := detail_rect.intersection(scroll_rect)
	_check(
		visible_detail.size.y >= float(detail.get_theme_font_size(&"font_size")),
		"%s status/value glyph band remains visible while lower crew rows clip" % state
	)
	var title_width := title.get_theme_font(&"font").get_string_size(
		title.text, HORIZONTAL_ALIGNMENT_LEFT, -1, title.get_theme_font_size(&"font_size")
	).x
	_check(title_width <= title.size.x, "%s headline is not horizontally clipped" % state)


func _state_views() -> Dictionary:
	var receipt := _wire_receipt()
	var active_presenter := Presenter.new()
	var active: Dictionary = active_presenter.present_wire_receipt(receipt)
	var clear_receipt := receipt.duplicate(true)
	clear_receipt.action = &"passenger_ping_clear"
	clear_receipt.request_sequence = 3
	clear_receipt.server_tick = 13
	clear_receipt.payload = {
		"channel": &"sensor",
		"marker_id": &"route_beacon",
		"clear": true,
		"reason": &"peer_released",
		"source_request_sequence": 2,
	}
	var cleared: Dictionary = active_presenter.present_tombstones([{"receipt": clear_receipt}])
	var lifecycle_presenter := Presenter.new()
	var available: Dictionary = lifecycle_presenter.present_bridge_result({"accepted": true, "status": &"attached"})
	var detached: Dictionary = lifecycle_presenter.present_bridge_result({"accepted": true, "status": &"detached"})
	var transient_presenter := Presenter.new()
	var stale: Dictionary = transient_presenter.present_bridge_result({"accepted": false, "status": &"stale_request_sequence"})
	var rejected: Dictionary = transient_presenter.present_bridge_result({"accepted": false, "status": &"navigator_identity_mismatch"})
	return {
		&"active": active,
		&"cleared": cleared,
		&"available": available,
		&"detached": detached,
		&"stale": stale,
		&"rejected": rejected,
	}


func _wire_receipt() -> Dictionary:
	return {
		"peer_id": 62,
		"peer_generation": 3,
		"avatar_id": &"navigator_avatar",
		"seat_id": &"cinder_navigator_station",
		"seat_generation": 1,
		"role": &"passenger",
		"ship_id": &"cinder-cargo-hauler",
		"ship_generation": 1,
		"request_sequence": 2,
		"server_tick": 12,
		"migration_generation": 2,
		"action": &"passenger_ping",
		"payload": {"channel": &"sensor", "marker_id": &"route_beacon"},
	}


func _check(condition: bool, description: String) -> void:
	_assertions += 1
	if not condition:
		_failures.append("FAIL: " + description)
