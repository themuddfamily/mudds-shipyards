extends SceneTree

## Forward+ witness of production-reachable Ember entry states. Every frame is
## sourced from the real Host -> production binding -> status binding -> HUD
## adapter path. No phase dictionaries or presentation snapshots are forged.

const BOOTSTRAP_SCENE := preload(
	"res://scenes/world/components/ember_moon_streaming_bootstrap.tscn"
)
const ARROW_SCENE := preload("res://scenes/ships/arrow_recon_ship.tscn")
const PLAYER_SCENE := preload("res://scenes/player/player.tscn")
const StatusBindingType := preload(
	"res://scripts/ui/ember_surface_return_status_binding.gd"
)
const AdapterType := preload("res://scripts/ui/ember_surface_return_hud_adapter.gd")
const HudType := preload("res://scripts/ui/hud.gd")

const CAPTURE_SIZE := Vector2i(2560, 1440)
const SETTLED_PANEL_RECT := Rect2(1102.0, 204.0, 396.0, 112.0)
const CARD_PADDING := 2
const CALLER_DELTA := 1.0 / 12.0
const TEST_TIME_SCALE := 5.0
const ROSTER := [
	["01_orbit_approach", EmberSurfaceLoopHost.Phase.ORBIT_APPROACH, &"orbit_approach"],
	["02_descent", EmberSurfaceLoopHost.Phase.DESCENT, &"descent"],
	["03_entry_corridor", EmberSurfaceLoopHost.Phase.SURFACE_APPROACH, &"surface_approach"],
	["04_landing_commit", EmberSurfaceLoopHost.Phase.LANDING_APPROACH, &"landing_approach"],
	["05_landed", EmberSurfaceLoopHost.Phase.LANDED, &"landed"],
	["06_detached_session_lost", EmberSurfaceLoopHost.Phase.FAILED, &"rejected"],
]


class EarlyCaller:
	extends Node
	signal prepare_finished

	var production: EmberSurfaceLoopProductionBinding
	var streaming: EmberMoonStreamingProductionBinding
	var origin_owner: CommonWorldOriginRebaseOwner
	var frame: PlanetaryCoordinateFrame
	var host: EmberSurfaceLoopHost
	var ship: ArrowReconShip
	var enabled := false
	var last_prepare: Dictionary = {}


	func _ready() -> void:
		process_physics_priority = -100


	func _physics_process(_delta: float) -> void:
		if not enabled:
			return
		var sample := {
			"available": true,
			"position": ship.global_position,
			"actor_kind": &"ship",
			"actor_instance_id": ship.get_instance_id(),
		}.duplicate(true)
		var stream_result := streaming.physics_tick_from_caller_sample(
			CALLER_DELTA, sample
		)
		var preview := streaming.preview_origin_rebase(int(stream_result.get(
			"coordinate_frame_generation", frame.get_generation()
		)))
		var origin_result := origin_owner.consume_rebase_preview(preview, sample)
		if bool(origin_result.get("accepted", false)) \
				and origin_result.has("actor_sample"):
			sample = (origin_result.actor_sample as Dictionary).duplicate(true)
		var serial := int(production.get_snapshot().last_caller_serial) + 1
		last_prepare = production.prepare_early_tick(
			serial, CALLER_DELTA, sample, origin_result,
			int(origin_result.get(
				"coordinate_frame_generation", frame.get_generation()
			)),
			1, production.get_generation(),
		)
		prepare_finished.emit()


var _failures: PackedStringArray = []
var _original_time_scale := 1.0
var _output_dir := ""
var _contact_path := ""


func _init() -> void:
	call_deferred(&"_run")


func _run() -> void:
	_original_time_scale = Engine.time_scale
	Engine.time_scale = TEST_TIME_SCALE
	_output_dir = OS.get_environment("MUDDS_EMBER_SURFACE_ENTRY_CAPTURE_DIR")
	if _output_dir.is_empty():
		_output_dir = "/tmp/mudds-ember-surface-entry-%d" % Time.get_ticks_usec()
	_contact_path = _output_dir.path_join("ember_surface_entry_contact_sheet.png")
	_check(_prepare_fresh_output(), "capture output starts in one fresh directory")
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

	var fixture := await _fixture()
	if fixture.is_empty():
		await _finish(hud, {})
		return
	var world := fixture.world as Node3D
	var host := fixture.host as EmberSurfaceLoopHost
	var production := EmberSurfaceLoopProductionBinding.new()
	production.name = "EmberSurfaceLoopProductionBinding"
	world.add_child(production)
	var early := EarlyCaller.new()
	early.name = "GameFlowEarlyCaller"
	early.production = production
	early.streaming = fixture.origin_binding
	early.origin_owner = fixture.origin_owner
	early.frame = fixture.frame
	early.host = host
	early.ship = fixture.ship
	world.add_child(early)
	await process_frame
	_check(
		bool(production.configure(host, 0).get("accepted", false)),
		"real production owner configures against the real bound Host",
	)
	early.enabled = true
	await production.state_changed
	early.enabled = false
	_check(
		bool(early.last_prepare.get("accepted", false))
			and host.get_phase() == EmberSurfaceLoopHost.Phase.ORBIT_APPROACH,
		"public scheduler starts the Host in orbit approach",
	)
	var director := ActivityDirector.new()
	director.name = "PlanetaryActivityDirector"
	world.add_child(director)
	await process_frame
	_check(
		bool(production.configure_planetary_surface(
			director, Callable(self, &"_reward_sink")
		).get("accepted", false)),
		"real production owner binds its authenticated planetary surface",
	)

	var binding := StatusBindingType.new()
	_check(
		bool(binding.attach(production, host, null, true).get("accepted", false)),
		"real status binding attaches to the exact production Host tuple",
	)
	var adapter := AdapterType.new()
	_check(
		bool(adapter.attach(binding, hud, production).get("accepted", false)),
		"real HUD adapter attaches through its public production seam",
	)

	var titles := {}
	var card_hashes := {}
	var card_images: Array[Image] = []
	await _capture_current(
		ROSTER[0], binding, hud, titles, card_hashes, card_images
	)
	for index in range(1, ROSTER.size() - 1):
		var row := ROSTER[index] as Array
		_check(
			await _advance_to_phase(fixture, production, early, int(row[1]), 720),
			"public advance_physics reaches %s" % row[0],
		)
		await _capture_current(row, binding, hud, titles, card_hashes, card_images)

	var detached := host.detach(
		host.get_generation(), host.get_attachment_generation()
	)
	_check(
		bool(detached.get("accepted", false)) and not bool(
			host.get_snapshot().get("attached", true)
		),
		"public Host detach retires the exact surface session",
	)
	await process_frame
	var detached_view := binding.get_presenter_snapshot()
	if StringName((detached_view.get("status_semantics", {}) as Dictionary).get(
		"kind", &""
	)) != &"detached":
		early.enabled = true
		await early.prepare_finished
		early.enabled = false
		_check(
			bool(early.last_prepare.get("accepted", false)),
			"detached Host observation is accepted by the public early scheduler",
		)
		if bool(early.last_prepare.get("accepted", false)):
			await production.state_changed
		detached_view = binding.get_presenter_snapshot()
	_check(
		StringName((detached_view.get("status_semantics", {}) as Dictionary).get(
			"kind", &""
		)) == &"detached",
		"real production failure publication resolves to detached/session-lost",
	)
	await _capture_current(
		ROSTER[ROSTER.size() - 1], binding, hud,
		titles, card_hashes, card_images
	)

	_check(
		titles.size() == ROSTER.size()
			and card_hashes.size() == ROSTER.size()
			and card_images.size() == ROSTER.size(),
		"all reachable states have unique visible titles and complete card ROIs",
	)
	if card_images.size() == ROSTER.size():
		_check(
			_save_contact_sheet(card_images) == OK,
			"all-reachable-state contact sheet saves successfully",
		)
		print("EMBER_SURFACE_ENTRY_CONTACT_SHEET: ", _contact_path)
	adapter.detach()
	binding.detach()
	await _finish(hud, fixture)


func _capture_current(
	row: Array, binding: RefCounted, hud: GameHUD,
	titles: Dictionary, card_hashes: Dictionary, card_images: Array[Image]
) -> void:
	# Freeze actor physics while the renderer settles. The Host scheduler is also
	# paused by its caller, so the captured lifecycle state and the live Arrow
	# cannot drift apart during these presentation-only frames.
	var live_time_scale := Engine.time_scale
	Engine.time_scale = 0.0
	for _frame in 3:
		await process_frame
	await RenderingServer.frame_post_draw
	Engine.time_scale = live_time_scale
	var view := binding.call(&"get_presenter_snapshot") as Dictionary
	var expected_state := row[2] as StringName
	var title := hud.get("_runtime_status_title") as Label
	var detail := hud.get("_runtime_status_detail") as Label
	var scroll := hud.get("_runtime_status_scroll") as ScrollContainer
	var actions := hud.get("_runtime_status_actions") as HBoxContainer
	var panel := hud.get("_runtime_status_panel") as PanelContainer
	var expected_title := str(view.get("visible_title", ""))
	_check(
		view.get("state", &"") == expected_state
			and panel != null and panel.visible
			and title != null and title.visible and title.text == expected_title,
		"%s is published by the real binding into the retained HUD" % row[0],
	)
	_check(_title_fits(title), "%s title fits without ellipsis" % row[0])
	_check(
		detail != null and not detail.text.is_empty()
			and scroll != null and not scroll.get_v_scroll_bar().visible
			and detail.size.y <= scroll.size.y + 0.5,
		"%s player-relevant text fits without hidden scrolling" % row[0],
	)
	_check(
		actions != null and actions.get_child_count() == 0,
		"%s exposes no fabricated Resume/Abort action" % row[0],
	)
	_check(
		panel.get_global_rect().is_equal_approx(SETTLED_PANEL_RECT),
		"%s keeps the exact settled 396x112 card bounds" % row[0],
	)
	_check(not titles.has(title.text), "%s title is unique" % row[0])
	titles[title.text] = true
	var image := root.get_texture().get_image()
	_check(
		image != null and not image.is_empty() and image.get_size() == CAPTURE_SIZE,
		"%s renders a real 2560x1440 frame" % row[0],
	)
	if image == null or image.is_empty():
		return
	var card := image.get_region(_pixel_rect(
		panel.get_global_rect(), image.get_size(), CARD_PADDING
	))
	var card_hash := _image_hash(card)
	_check(not card_hashes.has(card_hash), "%s card ROI is unique" % row[0])
	card_hashes[card_hash] = true
	var output_path := _output_dir.path_join(str(row[0]) + ".png")
	_check(image.save_png(output_path) == OK, "%s frame saves" % row[0])
	card_images.append(card)
	print("EMBER_SURFACE_ENTRY_FRAME: ", output_path)
	print("EMBER_SURFACE_ENTRY_CARD_ROI: %s %s" % [row[0], card_hash])


func _advance_to_phase(
	fixture: Dictionary, production: EmberSurfaceLoopProductionBinding,
	early: EarlyCaller, target_phase: int, budget: int
) -> bool:
	var host := fixture.host as EmberSurfaceLoopHost
	early.enabled = true
	for _index in budget:
		await production.state_changed
		if host.get_phase() == target_phase:
			early.enabled = false
			return true
		if host.get_phase() == EmberSurfaceLoopHost.Phase.FAILED:
			break
	early.enabled = false
	if host.get_phase() != target_phase:
		var host_snapshot := host.get_snapshot()
		print("EMBER_SURFACE_ENTRY_DRIVE_FAILED: target=%s phase=%s terminal=%s production=%s" % [
			target_phase,
			host_snapshot.get("phase_id", &""),
			host_snapshot.get("terminal_reason", &""),
			production.get_snapshot().get("last_late_result", {}),
		])
	return host.get_phase() == target_phase


func _fixture() -> Dictionary:
	var world := Node3D.new()
	world.name = "SharedCompositionRoot"
	root.add_child(world)
	var bootstrap := BOOTSTRAP_SCENE.instantiate() as EmberMoonStreamingBootstrap
	bootstrap.name = "EmberMoonStreamingBootstrap"
	world.add_child(bootstrap)
	var origin_binding := EmberMoonStreamingProductionBinding.new()
	origin_binding.name = "EmberMoonStreamingProductionBinding"
	world.add_child(origin_binding)
	var origin_owner := CommonWorldOriginRebaseOwner.new()
	origin_owner.name = "CommonWorldOriginRebaseOwner"
	world.add_child(origin_owner)
	var probe := Node3D.new()
	probe.name = "OriginActorProbe"
	world.add_child(probe)
	await process_frame
	await process_frame
	probe.global_position = bootstrap.global_position
	if not bool(_consume_origin(origin_binding, origin_owner, probe).get(
		"accepted", false
	)):
		_check(false, "fixture commits initial Ember origin")
		return {}
	await process_frame
	await process_frame
	var scene := bootstrap.get_loaded_instance() as EmberMoonAuthoredScene
	if scene == null:
		_check(false, "fixture loads the authored Ember root")
		return {}
	probe.global_position = (scene.get_node(^"LandingRegion") as Node3D).global_position
	if not bool(_consume_origin(origin_binding, origin_owner, probe).get(
		"accepted", false
	)):
		_check(false, "fixture commits the surface-local Ember origin")
		return {}
	probe.queue_free()
	var host := EmberSurfaceLoopHost.new()
	host.name = "EmberSurfaceLoopHost"
	world.add_child(host)
	var berth := EmberSurfaceBerth.new()
	berth.name = "EmberSurfaceBerth"
	world.add_child(berth)
	berth.global_transform = (scene.get_node(^"LandingRegion") as Node3D).global_transform
	var ship := ARROW_SCENE.instantiate() as ArrowReconShip
	ship.name = "ArrowReconShip"
	world.add_child(ship)
	var player := PLAYER_SCENE.instantiate() as PlayerController
	player.name = "Player"
	world.add_child(player)
	await process_frame
	await physics_frame
	ship.global_transform = (scene.get_node(^"LandingRegion") as Node3D).global_transform \
		* Transform3D(
			Basis.IDENTITY, EmberSurfaceLoopHost.APPROACH_ENTRY_REGION_LOCAL_M
		)
	ship.velocity = Vector3.ZERO
	var area := ship.get_node(^"ShipBoardingArea") as ShipBoardingArea
	player.teleport_to(area.global_transform)
	await physics_frame
	await physics_frame
	if not area.try_reserve(player) or not player.begin_boarding(
		ship.get_boarding_entry_transform(), ship.get_pilot_seat_anchor(),
		0.0, ship
	):
		_check(false, "fixture establishes the public seated reservation")
		return {}
	ship.set_piloted(true)
	var bound := host.bind_dependencies(
		bootstrap, berth, ship, player, 1.62, 1, 0, 0, world, origin_owner
	)
	if not bool(bound.get("accepted", false)):
		_check(false, "real Host dependency bind succeeds: %s" % bound.get(
			"reason", &""
		))
		return {}
	return {
		"world": world,
		"host": host,
		"bootstrap": bootstrap,
		"origin_binding": origin_binding,
		"origin_owner": origin_owner,
		"frame": bootstrap.get_coordinate_frame_for_session(),
		"scene": scene,
		"berth": berth,
		"ship": ship,
		"player": player,
		"area": area,
	}.duplicate(true)


func _consume_origin(
	binding: EmberMoonStreamingProductionBinding,
	owner: CommonWorldOriginRebaseOwner,
	actor: Node3D
) -> Dictionary:
	var sample := {
		"available": true,
		"position": actor.global_position,
		"actor_kind": &"ship" if actor is ArrowReconShip else &"player",
		"actor_instance_id": actor.get_instance_id(),
	}.duplicate(true)
	var tick := binding.physics_tick_from_caller_sample(CALLER_DELTA, sample)
	var preview := binding.preview_origin_rebase(int(tick.get(
		"coordinate_frame_generation", 0
	)))
	if not bool(preview.get("accepted", false)):
		return preview
	return owner.consume_rebase_preview(preview, sample)


func _prepare_fresh_output() -> bool:
	if DirAccess.dir_exists_absolute(_output_dir):
		var existing := DirAccess.open(_output_dir)
		if existing == null or not existing.get_files().is_empty() \
				or not existing.get_directories().is_empty():
			return false
		return true
	return DirAccess.make_dir_recursive_absolute(_output_dir) == OK


func _reward_sink(_receipt: Dictionary) -> Dictionary:
	return {"accepted": true, "reason": &"capture_reward_sink"}


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
		card_size.x * columns, card_size.y * rows,
		false, cards[0].get_format()
	)
	sheet.fill(Color("10151d"))
	for index in cards.size():
		sheet.blit_rect(
			cards[index], Rect2i(Vector2i.ZERO, card_size),
			Vector2i(
				(index % columns) * card_size.x,
				(index / columns) * card_size.y,
			),
		)
	return sheet.save_png(_contact_path)


func _finish(hud: GameHUD, fixture: Dictionary) -> void:
	Engine.time_scale = _original_time_scale
	if not fixture.is_empty() and is_instance_valid(fixture.get("world")):
		(fixture.world as Node).queue_free()
	if is_instance_valid(hud):
		hud.queue_free()
	await process_frame
	if _failures.is_empty():
		print("EMBER_SURFACE_ENTRY_CAPTURE_OK")
		quit(0)
		return
	for failure in _failures:
		push_error("EMBER_SURFACE_ENTRY_CAPTURE_FAILED: " + failure)
	quit(1)


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
