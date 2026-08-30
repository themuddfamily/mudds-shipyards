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
const LoadingScreenType := preload("res://scripts/ui/loading_screen.gd")
const MainStartupStagerType := preload("res://scripts/game/main_startup_stager.gd")

var _failures := PackedStringArray()


class YieldingStagedChild extends Node:
	func get_staged_construction_stage_count() -> int:
		return 1


	func run_staged_construction(on_stage: Callable) -> void:
		await get_tree().process_frame
		on_stage.call("Finishing yielded child")


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	await _test_queued_loading_screen_public_mutators_are_inert()
	await _test_stager_rejects_stale_host_generation_after_yield()
	await _test_detached_boot_joins_resource_worker()
	await _test_detached_boot_cancels_stale_continuation()
	await _test_boot_presents_before_it_builds()
	await _test_direct_instantiation_is_unstaged()
	_finish()


static func _short_worker_job() -> int:
	OS.delay_msec(25)
	return 1


func _test_detached_boot_joins_resource_worker() -> void:
	var boot := BOOT_SCENE.instantiate() as StartupLoader
	_check(boot != null, "boot worker-lifetime fixture instantiates")
	if boot == null:
		return
	boot.auto_start = false
	root.add_child(boot)
	await process_frame
	var worker := Thread.new()
	var start_error := worker.start(_short_worker_job)
	_check(start_error == OK, "boot worker-lifetime fixture starts an in-flight worker")
	if start_error != OK:
		boot.queue_free()
		await process_frame
		return
	boot.set("_resource_worker", worker)
	root.remove_child(boot)
	_check(
		boot.get("_resource_worker") == null
		and not worker.is_started()
		and not worker.is_alive(),
		"detaching Boot joins and releases its in-flight resource worker"
	)
	root.add_child(boot)
	boot.queue_free()
	await process_frame


func _test_stager_rejects_stale_host_generation_after_yield() -> void:
	var host := Node3D.new()
	var child := YieldingStagedChild.new()
	host.add_child(child)
	var stale_stages: Array[String] = []
	var stale_resolutions: Array[int] = []
	var stale_startups: Array[int] = []
	var stager := MainStartupStagerType.new(
		host,
		func() -> void:
			stale_resolutions.append(1),
		func() -> void:
			stale_startups.append(1)
	)
	_check(stager.prepare(false), "a pre-tree startup stager still prepares its authored child transaction")
	root.add_child(host)
	stager.run(
		false,
		func(label: String, _ratio: float) -> void:
			stale_stages.append(label)
	)
	# The child is now suspended at its real staged-build yield. Reattaching the
	# same host before it resumes must not make that old run current again.
	root.remove_child(host)
	root.add_child(host)
	var stages_before_resume := stale_stages.duplicate()
	var children_before_resume := host.get_child_count()
	await process_frame
	await process_frame
	_check(
		host.is_inside_tree()
			and stale_stages == stages_before_resume
			and host.get_child_count() == children_before_resume
			and stale_resolutions.is_empty()
			and stale_startups.is_empty(),
		"a detached-and-reentered staged host rejects its stale yielded continuation atomically"
	)
	host.queue_free()
	await process_frame

	var fresh_host := Node3D.new()
	fresh_host.add_child(YieldingStagedChild.new())
	var fresh_resolutions: Array[int] = []
	var fresh_startups: Array[int] = []
	var fresh_stager := MainStartupStagerType.new(
		fresh_host,
		func() -> void:
			fresh_resolutions.append(1),
		func() -> void:
			fresh_startups.append(1)
	)
	_check(fresh_stager.prepare(false), "a fresh pre-tree stager remains eligible after stale-host cancellation")
	root.add_child(fresh_host)
	await fresh_stager.run(false)
	_check(
		fresh_resolutions.size() == 1
			and fresh_startups.size() == 1
			and fresh_host.get_child_count() == 1,
		"a fresh attached host still resolves and starts exactly once after its yielded stage"
	)
	fresh_host.queue_free()
	await process_frame


func _test_queued_loading_screen_public_mutators_are_inert() -> void:
	var pre_tree := LoadingScreenType.new() as LoadingScreen
	pre_tree.configure({
		"colorblind_palette_id": &"tritanopia",
		"ui_scale": 1.15,
		"reduced_motion": true,
	})
	var pre_tree_report := pre_tree.get_report()
	var pre_tree_palette := (pre_tree.get("_palette") as Dictionary).duplicate(true)
	root.add_child(pre_tree)
	await process_frame
	_check(
		is_equal_approx(float(pre_tree.get_report().ui_scale), 1.15)
			and bool(pre_tree.get_report().reduced_motion)
			and (pre_tree.get("_palette") as Dictionary) == pre_tree_palette
			and pre_tree.get_report() == pre_tree_report,
		"pre-tree loading-screen configuration remains available to startup construction"
	)
	pre_tree.queue_free()
	await process_frame

	var screen := LoadingScreenType.new() as LoadingScreen
	root.add_child(screen)
	await process_frame
	screen.configure({
		"colorblind_palette_id": &"deuteranopia",
		"ui_scale": 1.25,
		"reduced_motion": false,
	})
	screen.set_stage("Live stage", 0.35, "Live detail")
	var backdrop_slot := screen.get_node_or_null("LoadingRoot/BackdropSlot") as Control
	var report_before := screen.get_report()
	var palette_before := (screen.get("_palette") as Dictionary).duplicate(true)
	var backdrop_count_before := backdrop_slot.get_child_count() if backdrop_slot != null else -1
	screen.queue_free()
	screen.configure({
		"colorblind_palette_id": &"protanopia",
		"ui_scale": 1.6,
		"reduced_motion": true,
	})
	screen.set_stage("Stale stage", 1.0, "Stale detail")
	screen.attach_backdrop()
	screen.dismiss()
	_check(
		screen.is_inside_tree()
		and screen.is_queued_for_deletion()
		and screen.get_report() == report_before
		and (screen.get("_palette") as Dictionary) == palette_before
		and (backdrop_slot.get_child_count() if backdrop_slot != null else -1) == backdrop_count_before,
		"a queued loading screen rejects public configuration, stage, backdrop, and dismissal mutation atomically"
	)
	await process_frame
	_check(not is_instance_valid(screen), "the queued loading-screen fixture frees normally")

	var detached := LoadingScreenType.new() as LoadingScreen
	root.add_child(detached)
	await process_frame
	detached.configure({"ui_scale": 1.3, "reduced_motion": false})
	detached.set_stage("Live stage", 0.35, "Live detail")
	var detached_backdrop_slot := detached.get_node_or_null("LoadingRoot/BackdropSlot") as Control
	var detached_palette_before := (detached.get("_palette") as Dictionary).duplicate(true)
	var detached_backdrop_count_before := (
		detached_backdrop_slot.get_child_count() if detached_backdrop_slot != null else -1
	)
	root.remove_child(detached)
	detached.configure({
		"colorblind_palette_id": &"protanopia",
		"ui_scale": 1.6,
		"reduced_motion": true,
	})
	detached.set_stage("Stale stage", 1.0, "Stale detail")
	detached.attach_backdrop()
	detached.dismiss()
	var detached_report := detached.get_report()
	_check(
		not detached.is_inside_tree()
			and not detached.is_queued_for_deletion()
			and is_zero_approx(float(detached_report.progress))
			and str(detached_report.stage).is_empty()
			and str(detached_report.detail).is_empty()
			and is_equal_approx(float(detached_report.ui_scale), 1.3)
			and not bool(detached_report.reduced_motion)
			and not bool(detached_report.dismissed)
			and (detached.get("_palette") as Dictionary) == detached_palette_before
			and (detached_backdrop_slot.get_child_count() if detached_backdrop_slot != null else -1) == detached_backdrop_count_before,
		"detach clears transition state while rejecting stale configuration, stage, backdrop, and dismissal mutation"
	)
	root.add_child(detached)
	await process_frame
	detached.configure({"colorblind_palette_id": &"protanopia", "ui_scale": 1.15})
	detached.set_stage("Reentered stage", 0.6, "Current detail")
	detached.attach_backdrop()
	detached.dismiss()
	var reentered_report := detached.get_report()
	_check(
		is_equal_approx(float(reentered_report.ui_scale), 1.15)
		and not bool(reentered_report.reduced_motion)
		and str(reentered_report.stage) == "Reentered stage"
		and str(reentered_report.detail) == "Current detail"
		and bool(reentered_report.backdrop_attached)
		and bool(reentered_report.dismissed)
		and not detached.is_queued_for_deletion(),
		"a fresh live re-entry still accepts current loading-screen stage, backdrop, and dismissal updates"
	)
	detached.queue_free()
	await process_frame


func _test_detached_boot_cancels_stale_continuation() -> void:
	var boot := BOOT_SCENE.instantiate() as StartupLoader
	_check(boot != null, "boot lifetime fixture instantiates")
	if boot == null:
		return
	boot.auto_start = false
	root.add_child(boot)
	await process_frame
	var completions: Array[Node] = []
	boot.startup_completed.connect(
		func(main: Node) -> void:
			completions.append(main)
	)
	# Detach only after Main has attached and staged construction has published a
	# real stage. This is the high-risk await boundary: an incomplete Main must not
	# survive to block the next boot generation.
	boot.run_startup()
	var staged := await _wait_for_staged_main(boot)
	_check(staged, "boot reaches real staged construction before the cancellation boundary")
	if not staged:
		boot.queue_free()
		await process_frame
		return
	root.remove_child(boot)
	_check(
		boot.get_main() == null
			and completions.is_empty()
			and boot.find_children("*", "GameFlow", false, false).is_empty(),
		"detaching staged boot retires its incomplete Main before a completion exists"
	)
	root.add_child(boot)
	var fresh := await boot.run_startup()
	await process_frame
	await process_frame
	var main_children: Array[Node] = []
	for child in boot.get_children():
		if child is GameFlow:
			main_children.append(child)
	_check(
		fresh != null
			and boot.get_main() == fresh
			and fresh.get_parent() == boot
			and completions.size() == 1
			and completions[0] == fresh
			and main_children == [fresh],
		"stale boot continuation cannot orphan or duplicate Main; re-entry completes one fresh generation"
	)
	boot.queue_free()
	await process_frame
	await process_frame


func _wait_for_staged_main(boot: StartupLoader) -> bool:
	for _frame_index in 720:
		if boot.get_main() != null and bool(boot.get("_running")):
			for entry_value in boot.get_startup_report().get("stages", []) as Array:
				var entry := entry_value as Dictionary
				if entry.get("phase", "") == "construction":
					return true
		await process_frame
	return false


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
	_check(
		boot.get("_resource_worker") == null,
		"successful startup joins and releases its scene resource worker before construction"
	)

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
	var binding := flow.get_node_or_null(
		^"CinderStreamingProductionBinding"
	) as CinderStreamingProductionBinding
	var bootstrap := flow.get_node_or_null(
		^"CinderStreamingBootstrap"
	) as CinderStreamingBootstrap
	_check(world != null and player != null and hud != null, "every authored Main child is back in the tree")
	_check(
		flow.get_node_or_null("ShipyardWorld") == flow.world,
		"the coordinator's bindings resolve to the re-added children"
	)
	var fleet: Array[HeroShip] = flow.get_flyable_ships()
	_check(fleet.size() == 9, "the staged startup registers the complete nine-craft fleet")
	_check(
		world != null and world.get_target_count() > 0,
		"the staged world finished its procedural build, not just its authored modules"
	)
	var berth_ids := world.get_berth_ids() if world != null else []
	_check(
		berth_ids.size() == 9
		and berth_ids.has(&"dock_04_cargo")
		and berth_ids.has(&"dock_05_bomber")
		and berth_ids.has(&"dock_06_interceptor"),
		"the staged world indexes all nine physical berths before fleet admission"
	)
	_check(
		hud != null and not bool(hud.get("_started")),
		"the shift has not auto-started: the player still presses BEGIN SHIFT"
	)
	_check(
		binding != null
		and bootstrap != null
		and bool(binding.audit().get("valid", false))
		and bootstrap.get_loaded_instance() == null
		and flow.find_children("*", "NearbySectorCluster", true, false).is_empty(),
		"staged startup restores one active production streaming binding with Cinder absent at station"
	)
	if binding == null or bootstrap == null:
		boot.queue_free()
		await process_frame
		return
	var coordinator := bootstrap.get_node_or_null(
		^"WorldStreamingCoordinator"
	) as WorldStreamingCoordinator
	var policy := bootstrap.get_node_or_null(
		^"WorldStreamingDistancePolicy"
	) as WorldStreamingDistancePolicy
	_check(
		coordinator != null and policy != null,
		"the staged bootstrap owns its coordinator and distance policy"
	)
	if coordinator == null or policy == null:
		boot.queue_free()
		await process_frame
		return
	var safe_start_before := flow.get_safe_start_recovery_report()
	var binding_id := binding.get_instance_id()
	var bootstrap_id := bootstrap.get_instance_id()
	var coordinator_id := coordinator.get_instance_id()
	var policy_id := policy.get_instance_id()
	var settings_id := flow.runtime_settings.get_instance_id()

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
		flow.get_flyable_ships().size() == 9,
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
	var safe_start_after := flow.get_safe_start_recovery_report()
	_check(
		binding.get_instance_id() == binding_id
		and bootstrap.get_instance_id() == bootstrap_id
		and coordinator.get_instance_id() == coordinator_id
		and policy.get_instance_id() == policy_id
		and int(safe_start_after.get("policy_instance_id", 0))
			== int(safe_start_before.get("policy_instance_id", -1))
		and flow.runtime_settings.get_instance_id() == settings_id
		and bootstrap.get_loaded_instance() == null
		and flow.find_children("*", "NearbySectorCluster", true, false).is_empty()
		and bool(binding.audit().get("valid", false)),
		"staged detach/re-entry preserves streaming, SafeStart, and RuntimeSettings identities without duplicates"
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
	await process_frame
	await physics_frame
	var binding := main.get_node_or_null(
		^"CinderStreamingProductionBinding"
	) as CinderStreamingProductionBinding
	var bootstrap := main.get_node_or_null(
		^"CinderStreamingBootstrap"
	) as CinderStreamingBootstrap
	_check(
		binding != null
		and bootstrap != null
		and bool(binding.audit().get("valid", false))
		and bootstrap.get_loaded_instance() == null
		and main.find_children("*", "NearbySectorCluster", true, false).is_empty(),
		"direct Main activates one production streaming binding with Cinder absent at station"
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
