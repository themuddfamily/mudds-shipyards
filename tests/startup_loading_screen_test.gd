extends SceneTree

## Covers the packaged build's boot path: the loading screen, the staged
## construction behind it, and the two properties a player actually felt when
## this was broken - the window presenting something immediately, and the cursor
## staying theirs until the game is playable.
##
## The staged path is opt-in, so this suite also pins the two guarantees that
## make that safe: a directly instantiated Main still builds synchronously in
## `_ready()`, and a Main built by the loader still survives a whole-subtree
## detach and re-add.

const BOOT_SCENE := preload("res://scenes/boot.tscn")
const MAIN_SCENE := preload("res://scenes/main.tscn")

var _failures := PackedStringArray()


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	await _test_boot_presents_before_it_builds()
	await _test_direct_instantiation_is_unstaged()
	_finish()


func _test_boot_presents_before_it_builds() -> void:
	var boot := BOOT_SCENE.instantiate() as StartupLoader
	_check(boot != null, "boot scene instantiates a startup loader")
	if boot == null:
		return
	boot.auto_start = false
	root.add_child(boot)
	await process_frame

	var screen := boot.get_loading_screen()
	_check(screen != null, "the loading screen exists on the boot scene's first frame")
	_check(
		screen != null and not screen.get_stage_text().is_empty(),
		"the loading screen names a stage before any construction has started"
	)
	_check(
		boot.get_main() == null,
		"no world has been constructed while the loading screen is being presented"
	)

	# Progress is sampled every frame for the whole of startup. A bar that jumps
	# straight from nothing to done is the dishonest failure mode this guards.
	var samples: Array[float] = []
	var stages := {}
	var watcher := func() -> void:
		var live := boot.get_loading_screen()
		if is_instance_valid(live):
			samples.append(live.get_progress())
			stages[live.get_stage_text()] = true
	process_frame.connect(watcher)
	var main := await boot.run_startup()
	process_frame.disconnect(watcher)

	_check(main != null, "the staged startup produces the Main scene")
	if main == null:
		boot.queue_free()
		await process_frame
		return

	var distinct: Array[float] = []
	var monotonic := true
	var previous := -1.0
	for sample in samples:
		if sample < previous:
			monotonic = false
		if not distinct.has(sample):
			distinct.append(sample)
		previous = sample
	_check(monotonic, "reported progress never moves backwards")
	_check(
		distinct.size() >= 5,
		"progress advances through real intermediate values rather than one jump (%d observed)" % distinct.size()
	)
	_check(
		stages.size() >= 3,
		"the loading screen names more than one real stage (%d observed)" % stages.size()
	)

	var report := boot.get_startup_report()
	_check(
		float(report["time_to_first_frame_ms"]) < float(report["time_to_interactive_ms"]),
		"the window presents long before the world is interactive"
	)
	_check(
		bool(report["mouse_free_during_load"]),
		"nothing captured the cursor while the loading screen owned the window"
	)
	_check(
		Input.mouse_mode != Input.MOUSE_MODE_CAPTURED,
		"the cursor is not captured once startup finishes and the title screen is up"
	)
	_check(
		(report["stages"] as Array).size() >= 10,
		"the startup report records the individual stages that ran"
	)

	var flow := main as GameFlow
	_check(flow != null, "the staged startup yields the ordinary gameplay coordinator")
	if flow == null:
		boot.queue_free()
		await process_frame
		return

	var world := flow.get_node_or_null("ShipyardWorld") as ShipyardWorld
	var player := flow.get_node_or_null("Player")
	var hud := flow.get_node_or_null("HUD")
	_check(world != null and player != null and hud != null, "every authored Main child is back in the tree")
	_check(
		flow.get_node_or_null("ShipyardWorld") == flow.world,
		"the coordinator's bindings resolve to the re-added children"
	)
	var fleet: Array[HeroShip] = flow.get_flyable_ships()
	_check(fleet.size() == 5, "the staged startup registers the same five flyable craft")
	_check(
		world != null and world.get_target_count() > 0,
		"the staged world finished its procedural build, not just its authored modules"
	)
	_check(
		world != null and world.get_berth_ids().size() >= 5,
		"the staged world registered its berths"
	)
	_check(
		hud != null and not bool(hud.get("_started")),
		"the shift has not auto-started: the player still presses BEGIN SHIFT"
	)

	# The re-entry suites detach and re-add a Main that `_ready()` built. A Main
	# the loader built must behave identically, or the staged path would be a
	# second lifecycle nobody else tests.
	var parent := flow.get_parent()
	parent.remove_child(flow)
	await process_frame
	_check(
		Input.mouse_mode != Input.MOUSE_MODE_CAPTURED,
		"detaching Main releases the cursor"
	)
	parent.add_child(flow)
	await process_frame
	await physics_frame
	await process_frame
	_check(
		flow.get_flyable_ships().size() == 5,
		"a loader-built Main survives a whole-subtree detach and re-add"
	)
	_check(
		world != null and world.get_target_count() > 0,
		"the re-added staged world kept its built contents"
	)
	_check(
		world != null and not world.get_station_navigation_audit_report().is_empty(),
		"the re-added staged world restored its station lattice bindings"
	)

	boot.queue_free()
	await process_frame
	await process_frame


func _test_direct_instantiation_is_unstaged() -> void:
	# Everything except the boot scene gets the original synchronous build, in
	# one `_ready()`, with no loader present to drive stages.
	var main := MAIN_SCENE.instantiate() as GameFlow
	root.add_child(main)
	var world := main.get_node_or_null("ShipyardWorld") as ShipyardWorld
	_check(
		world != null and world.get_target_count() > 0,
		"a directly instantiated world is fully built the moment it enters the tree"
	)
	_check(
		main.world != null and main.player != null and main.hud != null,
		"a directly instantiated coordinator resolves its bindings in _ready()"
	)
	_check(
		not main.prepare_staged_startup(),
		"staged startup is refused once Main is already in the tree"
	)
	main.queue_free()
	await process_frame
	await process_frame


func _check(condition: bool, description: String) -> void:
	if condition:
		print("PASS: ", description)
	else:
		_failures.append(description)
		push_error("FAIL: " + description)


func _finish() -> void:
	if _failures.is_empty():
		print("STARTUP_LOADING_SCREEN_TEST_OK")
		quit(0)
	else:
		print("STARTUP_LOADING_SCREEN_TEST_FAILED: ", ", ".join(_failures))
		quit(1)
