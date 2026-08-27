extends SceneTree

## Native Forward+ witness for the retained Derelict Scan recovery row. Every
## state is reached through the production HUD button and GameFlow route; the
## harness never injects a presenter snapshot or calls scan lifecycle methods.

const HUD_SCENE := preload("res://scenes/ui/hud.tscn")
const GameFlowType := preload("res://scripts/game/game_flow.gd")
const BindingType := preload("res://scripts/world/nearby_sector_activity_binding.gd")
const ConvoyHostType := preload("res://scripts/activities/cinder_convoy_escort_host.gd")
const ScanActivityType := preload("res://scripts/world/cinder_abandoned_structure_scan_activity.gd")
const RESOLUTION := Vector2i(1280, 720)
const CAPTURE_STATES: Array[String] = ["ready", "wrong_position", "scanning", "reset"]


class WorldProbe extends Node3D:
	var cluster := Node3D.new()

	func _init(binding: NearbySectorActivityBinding) -> void:
		cluster.name = "NearbySectorCluster"
		binding.name = "ActivityBinding"
		cluster.add_child(binding)
		add_child(cluster)

	func get_nearby_sector_cluster() -> Node3D:
		return cluster


class ShipProbe extends HeroShip:
	func _ready() -> void:
		pass


var _failures: Array[String] = []
var _images: Dictionary = {}
var _panel_hashes: Dictionary = {}
var _hud: GameHUD
var _flow: Node
var _binding: NearbySectorActivityBinding


func _init() -> void:
	call_deferred(&"_run")


func _run() -> void:
	root.size = RESOLUTION
	root.content_scale_size = Vector2i.ZERO
	root.use_taa = false
	root.msaa_3d = Viewport.MSAA_DISABLED
	_check(
		RenderingServer.get_current_rendering_method() == &"forward_plus"
			and DisplayServer.get_name() == "X11"
			and not RenderingServer.get_video_adapter_name().is_empty(),
		"capture has a native X11 Forward+ rendering device",
	)

	_binding = BindingType.new() as NearbySectorActivityBinding
	_binding.add_child(ConvoyHostType.new())
	var world := WorldProbe.new(_binding)
	root.add_child(world)
	_hud = HUD_SCENE.instantiate() as GameHUD
	root.add_child(_hud)
	var ship := ShipProbe.new()
	root.add_child(ship)
	var convoy_host := ConvoyHostType.new() as CinderConvoyEscortHost
	root.add_child(convoy_host)
	_flow = GameFlowType.new()
	_flow.set("world", world)
	_flow.set("hud", _hud)
	_flow.set("active_ship", ship)
	_flow.set("cinder_convoy_host", convoy_host)
	_hud.nearby_activity_intent_requested.connect(
		Callable(_flow, &"_on_hud_nearby_activity_intent_requested")
	)
	await process_frame
	await physics_frame
	_flow.call(&"_sync_nearby_activity_hud")
	(_hud.get("_intro") as Control).visible = false
	(_hud.get("_pause") as Control).visible = true
	(_hud.get("_pause_main_page") as Control).visible = false
	(_hud.get("_nearby_activity_page") as Control).visible = true
	await process_frame

	var row := _scan_row()
	var start_button := row.get_child(2) as Button if row != null else null
	_check(
		start_button != null
			and _scan_text(row).contains("SCAN READY")
			and _scan_text(row).contains("APPROACH DERELICT DATUM"),
		"the production retained row exposes READY and its START action",
	)
	await _capture("ready")

	if start_button != null:
		start_button.emit_signal(&"pressed")
	await process_frame
	row = _scan_row()
	var rejected := _scan_snapshot()
	_check(
		StringName(rejected.get("presentation_reason", &"")) == &"outside_scan_approach"
			and _scan_text(row).contains(
				"WRONG POSITION  //  MOVE TO DERELICT SCAN MARKER"
			),
		"the real rejected START displays explicit non-colour recovery guidance",
	)
	await _capture("wrong_position")

	ship.global_position = ScanActivityType.APPROACH_ANCHOR
	start_button = row.get_child(2) as Button if row != null else null
	if start_button != null:
		start_button.emit_signal(&"pressed")
	await process_frame
	row = _scan_row()
	var active := _scan_snapshot()
	_check(
		int(active.get("state", -1)) == 1
			and StringName(active.get("presentation_reason", &"stale")).is_empty()
			and _scan_text(row).contains("SCANNING STRUCTURE  //  0%"),
		"a valid real START clears rejection feedback and displays SCANNING",
	)
	await _capture("scanning")

	var reset_button := row.get_child(3) as Button if row != null else null
	if reset_button != null:
		reset_button.emit_signal(&"pressed")
	_check(
		reset_button != null and reset_button.text == "CONFIRM RESET",
		"the first real RESET press remains confirmation-only",
	)
	if reset_button != null:
		reset_button.emit_signal(&"pressed")
	await process_frame
	row = _scan_row()
	var reset := _scan_snapshot()
	_check(
		int(reset.get("state", -1)) == 3
			and StringName(reset.get("presentation_reason", &"stale")).is_empty()
			and _scan_text(row).contains("INTERRUPTED  //  PROGRESS RESET"),
		"the confirmed real RESET displays the normal restart state",
	)
	await _capture("reset")
	_validate_capture_set()

	_flow.set("hud", null)
	_flow.set("world", null)
	_flow.set("active_ship", null)
	_flow.set("cinder_convoy_host", null)
	_flow.free()
	_hud.queue_free()
	world.queue_free()
	ship.queue_free()
	convoy_host.queue_free()
	for _frame in 4:
		await process_frame
	if _failures.is_empty():
		print("CINDER_STRUCTURE_SCAN_REJECTION_HUD_CAPTURE_OK: 4 routed Forward+ states")
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)


func _capture(state: String) -> void:
	var page := _hud.get("_nearby_activity_page") as Control
	if page != null:
		page.visible = false
		await process_frame
		page.visible = true
		page.propagate_call(&"queue_redraw", [], true)
	for _frame in 16:
		await process_frame
	RenderingServer.force_draw()
	await process_frame
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	var row := _scan_row()
	var label := row.get_child(0) as Label if row != null else null
	_check(
		image != null and not image.is_empty() and image.get_size() == RESOLUTION,
		"%s renders a nonempty exact-size frame" % state.to_upper(),
	)
	_check(
		page != null and page.is_visible_in_tree()
			and label != null and label.is_visible_in_tree()
			and _rect_fully_onscreen(label.get_global_rect()),
		"%s keeps the retained scan text visible and fully onscreen" % state.to_upper(),
	)
	if image == null or image.is_empty() or page == null:
		return
	var panel_region := _screen_region(page.get_global_rect())
	_check(
		panel_region.size.x > 0 and panel_region.size.y > 0,
		"%s projects the retained activity panel onscreen" % state.to_upper(),
	)
	if panel_region.size.x <= 0 or panel_region.size.y <= 0:
		return
	var panel_sample := image.get_pixelv(panel_region.position + Vector2i(20, 20))
	_check(
		panel_sample.get_luminance() > 0.01,
		"%s retains its substantive panel background" % state.to_upper(),
	)
	_images[state] = image
	_panel_hashes[state] = _image_hash(image.get_region(panel_region))
	var directory := OS.get_environment("CINDER_SCAN_REJECTION_CAPTURE_DIR")
	if directory.is_empty():
		directory = "/tmp/cinder_structure_scan_rejection_hud"
	DirAccess.make_dir_recursive_absolute(directory)
	_check(
		image.save_png(directory.path_join("%s.png" % state)) == OK,
		"%s frame saves" % state.to_upper(),
	)


func _validate_capture_set() -> void:
	_check(_images.size() == CAPTURE_STATES.size(), "all four routed HUD states were captured")
	_check(
		_panel_hashes.size() == CAPTURE_STATES.size(),
		"all four retained activity panels were hashed",
	)
	var unique_hashes: Dictionary = {}
	for state in CAPTURE_STATES:
		unique_hashes[_panel_hashes.get(state, "")] = true
	_check(
		unique_hashes.size() == CAPTURE_STATES.size(),
		"READY, WRONG POSITION, SCANNING, and RESET panels are visibly distinct",
	)


func _scan_snapshot() -> Dictionary:
	return (
		_binding.get_snapshot().get("structure_scan", {}) as Dictionary
	).duplicate(true) if _binding != null else {}


func _scan_row() -> Control:
	var rows := _hud.get("_nearby_activity_rows") as VBoxContainer if _hud != null else null
	for candidate in rows.get_children() if rows != null else []:
		if StringName(candidate.get_meta(&"activity_id", &"")) \
				== &"cinder_derelict_structure_scan":
			return candidate as Control
	return null


func _scan_text(row: Control) -> String:
	return str((row.get_child(0) as Label).text) if row != null else ""


func _rect_fully_onscreen(rect: Rect2) -> bool:
	return rect.position.x >= 0.0 and rect.position.y >= 0.0 \
		and rect.end.x <= float(RESOLUTION.x) and rect.end.y <= float(RESOLUTION.y)


func _screen_region(rect: Rect2) -> Rect2i:
	var origin := Vector2i(floori(maxf(rect.position.x, 0.0)), floori(maxf(rect.position.y, 0.0)))
	var end := Vector2i(
		ceili(minf(rect.end.x, float(RESOLUTION.x))),
		ceili(minf(rect.end.y, float(RESOLUTION.y))),
	)
	return Rect2i(origin, end - origin)


func _image_hash(image: Image) -> String:
	var context := HashingContext.new()
	context.start(HashingContext.HASH_SHA256)
	context.update(image.get_data())
	return context.finish().hex_encode()


func _check(condition: bool, message: String) -> void:
	if condition:
		print("PASS: ", message)
		return
	_failures.append("FAIL: " + message)
