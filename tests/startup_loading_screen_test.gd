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


class InterruptedFleetLoader extends StartupLoader:
	var queue_fleet := false
	var interrupted_fleet: FleetExpansionProductionBinding
	var owned_main_children: Array[WeakRef] = []

	func _on_construction_stage(generation: int, label: String, ratio: float) -> void:
		super._on_construction_stage(generation, label, ratio)
		if label != "Preparing Cinder Cargo Hauler":
			return
		var main := get_main()
		var stager := main.get("_startup_stager") as MainStartupStager
		for child: Node in stager.get("_staged_children"):
			owned_main_children.append(weakref(child))
		interrupted_fleet = main.get_node(
			"ShipyardWorld/FleetExpansionProductionBinding"
		) as FleetExpansionProductionBinding
		if queue_fleet:
			# Retire after the sink returns, while the binding driver is awaiting
			# its settle frame and Main itself remains live.
			interrupted_fleet.queue_free.call_deferred()
		else:
			interrupted_fleet.get_parent().remove_child(interrupted_fleet)


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	await _test_queued_loading_screen_public_mutators_are_inert()
	await _test_prepared_main_frees_detached_children()
	await _test_stager_rejects_stale_host_generation_after_yield()
	await _test_gameplay_startup_phases()
	await _test_world_stages_authored_children_and_rejects_stale_yield()
	await _test_detached_boot_joins_resource_worker()
	await _test_detached_boot_cancels_stale_continuation()
	await _test_boot_presents_before_it_builds()
	await _test_live_boot_rejects_incomplete_fleet()
	await _test_direct_instantiation_is_unstaged()
	await _test_atomic_graphics_profile_precedes_world_construction()
	_finish()


func _test_prepared_main_frees_detached_children() -> void:
	var main := MAIN_SCENE.instantiate() as GameFlow
	var child_refs: Array[WeakRef] = []
	for child in main.get_children():
		child_refs.append(weakref(child))
		if child is ShipyardWorld:
			for authored_world_child in child.get_children():
				child_refs.append(weakref(authored_world_child))
	var transferred := Node.new()
	main.add_child(transferred)
	_check(main.prepare_staged_startup(), "Main prepares detached children before entering the tree")
	_check(main.get_child_count() == 0 and not child_refs.is_empty(),
		"prepared Main transfers all authored children to the stager")
	var new_owner := Node.new()
	new_owner.add_child(transferred)
	(child_refs[0].get_ref() as Node).queue_free()
	var retained_stager := main.get("_startup_stager") as MainStartupStager
	main.free()
	await process_frame
	var all_freed := true
	for child_ref in child_refs:
		all_freed = all_freed and child_ref.get_ref() == null
	_check(all_freed, "freeing prepared Main releases every detached authored child with the stager retained")
	_check(is_instance_valid(transferred) and transferred.get_parent() == new_owner,
		"final stager disposal preserves children transferred to another parent")
	new_owner.free()
	retained_stager.dispose()
	_check(not retained_stager.prepare(false), "disposed stager remains inert after repeated disposal")


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
	var temporary_texture := ImageTexture.new()
	var temporary_ref: WeakRef = weakref(temporary_texture)
	(boot.get("_startup_textures") as Array).append(temporary_texture)
	temporary_texture = null
	root.remove_child(boot)
	_check(
		boot.get("_resource_worker") == null
		and not worker.is_started()
		and not worker.is_alive(),
		"detaching Boot joins and releases its in-flight resource worker"
	)
	_check((boot.get("_startup_textures") as Array).is_empty()
		and temporary_ref.get_ref() == null,
		"worker cancellation drops Boot's temporary texture ownership")
	root.add_child(boot)
	boot.queue_free()
	await process_frame


func _test_stager_rejects_stale_host_generation_after_yield() -> void:
	var host := Node3D.new()
	var child := YieldingStagedChild.new()
	host.add_child(child)
	var tail := Node.new()
	host.add_child(tail)
	var tail_ref: WeakRef = weakref(tail)
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
	_check(tail_ref.get_ref() == tail and tail.get_parent() == null,
		"canceling a yielded run preserves detached children for reuse")
	await stager.run(false)
	_check(host.get_child_count() == 2 and tail.get_parent() == host
		and stale_resolutions.size() == 1 and stale_startups.size() == 1,
		"the same canceled stager resumes attached and detached children exactly once")
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


func _test_gameplay_startup_phases() -> void:
	var pending_host := Node3D.new()
	var pending_calls: Array[String] = []
	var pending_progress: Array[float] = []
	var pending_stager := MainStartupStagerType.new(pending_host,
		func() -> void: pending_calls.append("bindings"),
		func() -> void: pending_calls.append("startup"))
	_check(pending_stager.prepare(false), "legacy startup tail prepares")
	root.add_child(pending_host)
	pending_stager.run(false, func(_label: String, ratio: float) -> void: pending_progress.append(ratio))
	_check(not await pending_stager.run(false), "a concurrent run cannot replace the pre-tail progress sink")
	await process_frame
	await process_frame
	_check(pending_calls == ["bindings", "startup"] and pending_progress == [1.0],
		"legacy startup retains its one callback and progress owner across the first tail yield")
	pending_stager.dispose()
	pending_host.queue_free()
	await process_frame
	for interruption in ["", "phase", "progress", "yield"]:
		var host := Node3D.new()
		var calls: Array[String] = []
		var frames: Array[int] = []
		var progress: Array[float] = []
		var completed := {"initialized": false}
		var first_phase := func() -> void:
			calls.append("first")
			frames.append(Engine.get_process_frames())
			if interruption == "phase": _detach_and_reattach_startup_host(host)
		var second_phase := func() -> void:
			calls.append("second")
			frames.append(Engine.get_process_frames())
		var final_phase := func() -> void:
			calls.append("final")
			frames.append(Engine.get_process_frames())
			completed.initialized = true
		var startup_stages: Array[Dictionary] = [
			{"label": "First phase", "run": first_phase},
			{"label": "Second phase", "run": second_phase},
			{"label": "Final phase", "run": final_phase},
		]
		var stager := MainStartupStagerType.new(host,
			func() -> void: calls.append("bindings"),
			func() -> void: calls.append("legacy startup"), startup_stages)
		_check(stager.prepare(false), "gameplay phases prepare before tree attachment")
		root.add_child(host)
		var result := await stager.run(false, func(label: String, ratio: float) -> void:
			progress.append(ratio)
			_check(ratio < 1.0 or completed.initialized,
				"startup progress cannot finish before gameplay startup completes")
			if label == "First phase":
				_check(not completed.initialized, "intermediate startup phase does not admit gameplay")
				if interruption == "progress": _detach_and_reattach_startup_host(host)
				elif interruption == "yield":
					call_deferred("_detach_and_reattach_startup_host", host)
		)
		if interruption.is_empty():
			_check(result and completed.initialized and not stager.is_prepared()
				and calls == ["bindings", "first", "second", "final"]
				and frames[0] < frames[1] and frames[1] < frames[2]
				and progress.size() == 3 and is_equal_approx(progress[-1], 1.0),
				"gameplay phases run once in order on separate loading frames")
		else:
			_check(not result and not completed.initialized and stager.is_prepared()
				and calls == ["bindings", "first"],
				"interrupted gameplay startup fails closed at " + interruption)
			_check(not await stager.run(false) and calls == ["bindings", "first"],
				"interrupted gameplay services cannot resume or replay after " + interruption)
		stager.dispose()
		host.queue_free()
		await process_frame


func _detach_and_reattach_startup_host(host: Node) -> void:
	root.remove_child(host)
	root.add_child(host)


func _test_world_stages_authored_children_and_rejects_stale_yield() -> void:
	var world := (load("res://scenes/world/shipyard_world.tscn") as PackedScene).instantiate() as ShipyardWorld
	_check(world.visual_quality_level == RuntimeSettings.GraphicsProfile.HIGH,
		"authored world keeps High as the default graphics profile")
	var authored := world.get_children()
	var authored_feedback := world.get_node("CentralBerth/BerthFeedback")
	var feedback_owner := authored_feedback.owner
	_check(feedback_owner == world,
		"authored berth feedback belongs to the world across its instanced berth parent")
	var owners: Dictionary = {}
	for child in authored:
		owners[child] = child.owner
	world.prepare_staged_construction()
	var expected_stage_count := world.get_staged_construction_stage_count()
	_check(world.get_child_count() == 0,
		"prepared world defers authored modules before any of their ready callbacks")
	root.add_child(world)
	_check(world.get_child_count() == 0 and not bool(world.get("_built")),
		"attaching a staged world performs no authored or procedural construction")
	var stages: Array[String] = []
	var sink := func(label: String) -> void:
		stages.append(label)
	world.run_staged_construction(sink)
	_check(world.get_child_count() == 1 and stages.size() == 1,
		"world gives the main loop a frame after one authored subtree")
	root.remove_child(world)
	root.add_child(world)
	var stage_count := stages.size()
	await process_frame
	await process_frame
	_check(world.get_child_count() == 1 and stages.size() == stage_count
		and not bool(world.get("_built")),
		"reentering the world cannot revive its stale awaited construction")
	var interrupted_build: Array[String] = []
	var fleet_stage_frames: Array[int] = []
	var lattice_counts: Array[int] = []
	var retained_lattice_nodes: Dictionary = {}
	var lattice_interruptions := [
		"Preparing the central tow service",
		"Preparing central berth ambience",
		"Fitting the central berth fascia",
	]
	var interrupting_sink := func(label: String) -> void:
		sink.call(label)
		var stage_index := int(world.get("_staged_build_index")) - 1
		if stage_index >= 0 and String(ShipyardWorld.BUILD_STAGES[stage_index][0]).begins_with("_build_lattice_"):
			var component_count := 0
			for container: String in ["Activities", "Ambience", "StructuralDressing"]:
				component_count += world.get_node("OperationalLattice/" + container).get_child_count()
			lattice_counts.append(component_count)
		if label.begins_with("Preparing Cinder"):
			fleet_stage_frames.append(Engine.get_process_frames())
		if label == "Parking the provisional fleet":
			var fleet := world.get_node("FleetExpansionProductionBinding") as FleetExpansionProductionBinding
			_check(fleet.is_composition_ready(),
				"world reports its fleet stage only after all Cinder craft settle and attach")
		if lattice_interruptions.has(label) and not interrupted_build.has(label):
			interrupted_build.append(label)
			for container: String in ["Activities", "Ambience", "StructuralDressing"]:
				for child in world.get_node("OperationalLattice/" + container).get_children():
					retained_lattice_nodes[world.get_path_to(child)] = child
			# Cancel at this exact component boundary, independent of machine speed.
			_detach_and_reattach_staged_world(world)
		elif label in ["Preparing Cinder Cargo Hauler", "Setting the signage"] \
				and not interrupted_build.has(label):
			interrupted_build.append(label)
			call_deferred("_detach_and_reattach_staged_world", world)
	for interruption: String in lattice_interruptions:
		await world.run_staged_construction(interrupting_sink)
		stage_count = stages.size()
		await process_frame
		_check(not bool(world.get("_built")) and stages.size() == stage_count
			and stages.back() == interruption and stages.count("Mixing station materials") == 0,
			"world cancels at partial lattice component boundary: %s" % interruption)
		var retained := true
		for path: NodePath in retained_lattice_nodes:
			retained = retained and world.get_node_or_null(path) == retained_lattice_nodes[path]
		_check(retained, "partial lattice resume retains earlier component identities: %s" % interruption)
	await world.run_staged_construction(interrupting_sink)
	var partial_fleet := world.get_node("FleetExpansionProductionBinding") as FleetExpansionProductionBinding
	var partial_cargo := partial_fleet.get_node("cinder_cargo_hauler")
	_check(not bool(world.get("_built")) and not partial_fleet.is_composition_ready()
		and stages.count("Parking the provisional fleet") == 0
		and stages.count("Dressing the industrial deck") == 0,
		"world retains its pending fleet build index when partial Cinder construction detaches")
	await world.run_staged_construction(interrupting_sink)
	_check(world.get_node("FleetExpansionProductionBinding") == partial_fleet
		and partial_fleet.get_node("cinder_cargo_hauler") == partial_cargo
		and world.find_children("ProvisionalParkedFleet", "Node3D", false, false).size() == 1,
		"world resumes its exact provisional fleet owner and craft without duplicates")
	_check(not bool(world.get("_built"))
		and not bool(world.get_station_solar_readability_report().active),
		"late construction cancellation retires existing presentation bindings")
	await world.run_staged_construction(sink)
	await process_frame
	var separated_fleet_frames := fleet_stage_frames.size() == 4
	for index in range(1, fleet_stage_frames.size()):
		separated_fleet_frames = separated_fleet_frames and fleet_stage_frames[index] > fleet_stage_frames[index - 1]
	_check(separated_fleet_frames and stages.size() == expected_stage_count,
		"world counts each actual fleet unit once and constructs it on a separate frame")
	_check(lattice_counts == range(1, 19),
		"lattice progress reports exactly one newly completed component for all 18 units")
	var lattice_retained := true
	for path: NodePath in retained_lattice_nodes:
		lattice_retained = lattice_retained and world.get_node_or_null(path) == retained_lattice_nodes[path]
	_check(lattice_retained and bool(world.get_operational_lattice_audit_report().valid),
		"resumed lattice preserves its exact components and completes the live geometry, audio, and authority contract")
	_check(bool(world.get_station_solar_readability_report().active),
		"finishing a resumed world restores bindings retired after their builders completed")
	var authored_restored := true
	for index in authored.size():
		var child := authored[index]
		authored_restored = authored_restored and world.get_child(index) == child \
			and child.owner == owners[child]
	_check(authored_restored,
		"resumed world restores every authored child in order with its original owner")
	_check(authored_feedback.owner == feedback_owner,
		"resumed world restores descendant ownership across an instanced subtree boundary")
	_check(bool(world.get("_built")) and world.get_target_count() > 0
		and world.player_spawn == world.get_node("PlayerSpawn")
		and world.habitat_spine == world.get_node("HabitatSpine"),
		"resumed world resolves authored bindings before completing procedural construction")
	_check(stages.count("Surveying berths") == 1 and stages.count("Setting the signage") == 1,
		"resumed construction completes the procedural sequence exactly once")
	var completed_children := world.get_children()
	var completed_stages := stages.duplicate()
	var still_complete: bool = await world.run_staged_construction(sink)
	_check(still_complete and world.get_children() == completed_children and stages == completed_stages,
		"completed world accepts a resumed parent stager without rebuilding or repeating progress")
	world.queue_free()
	await process_frame


func _detach_and_reattach_staged_world(world: ShipyardWorld) -> void:
	root.remove_child(world)
	root.add_child(world)


func _test_atomic_graphics_profile_precedes_world_construction() -> void:
	var path := RuntimeSettingsStoreAdapter.DEFAULT_STORE_PATH
	var original_files: Dictionary = {}
	for suffix in ["", ".bak", ".tmp", ".recovery"]:
		if FileAccess.file_exists(path + suffix):
			original_files[suffix] = FileAccess.get_file_as_bytes(path + suffix)
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path + suffix))
	var retained_process_settings := GameFlow._production_runtime_settings_state
	GameFlow._production_runtime_settings_state = {}
	var settings := RuntimeSettings.new()
	settings.graphics_profile = RuntimeSettings.GraphicsProfile.LOW
	var store := UserDataStore.new(path)
	store.load()
	var committed := store.commit({
		RuntimeSettingsStoreAdapter.SETTINGS_PAYLOAD_KEY: settings.to_user_data_payload(),
	}, 0, "startup-low-fixture")
	_check(bool(committed.accepted), "startup fixture stores validated atomic Low settings")
	var stored_bytes := FileAccess.get_file_as_bytes(path)
	var stored_payload: Dictionary = (JSON.parse_string(stored_bytes.get_string_from_utf8()) as Dictionary).payload.runtime_settings
	var boot := BOOT_SCENE.instantiate() as StartupLoader
	boot.auto_start = false
	root.add_child(boot)
	_check(FileAccess.get_file_as_bytes(path) == stored_bytes,
		"Boot's settings preview preserves atomic bytes before normal gameplay startup")
	boot.run_startup()
	var staged := await _wait_for_staged_main(boot)
	var flow := boot.get_main() as GameFlow
	var world := flow.get_node_or_null("ShipyardWorld") as ShipyardWorld if flow != null else null
	_check(staged and world != null and world.visual_quality_level == RuntimeSettings.GraphicsProfile.LOW
		and world.get_node_or_null("ShipyardEnvironment") == null,
		"stored atomic Low reaches the staged world before environment construction")
	if staged:
		await boot.startup_completed
	_check(flow != null and flow.runtime_settings.graphics_profile == RuntimeSettings.GraphicsProfile.LOW,
		"normal GameFlow authority retains the stored Low graphics profile")
	_check(flow != null and int(flow.get("_runtime_settings_load_attempt_count")) == 1,
		"boot preserves the normal single GameFlow authority load")
	var after_store := UserDataStore.new(path)
	after_store.load_read_only()
	_check(after_store.get_snapshot().get(RuntimeSettingsStoreAdapter.SETTINGS_PAYLOAD_KEY) == stored_payload,
		"full startup preserves the runtime settings payload while normal diagnostics may save")
	boot.queue_free()
	await process_frame
	await process_frame
	GameFlow._production_runtime_settings_state = retained_process_settings
	for suffix in ["", ".bak", ".tmp", ".recovery"]:
		if FileAccess.file_exists(path + suffix):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path + suffix))
		if original_files.has(suffix):
			var file := FileAccess.open(path + suffix, FileAccess.WRITE)
			file.store_buffer(original_files[suffix])
			file.close()


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
	_check((boot.get("_startup_textures") as Array).size() == 3,
		"staged Boot retains the worker's three hull textures until ship construction")
	var canceled_stager := boot.get_main().get("_startup_stager") as MainStartupStager
	var canceled_child_refs: Array[WeakRef] = []
	for pending_child in canceled_stager.get("_staged_children") as Array:
		canceled_child_refs.append(weakref(pending_child))
	root.remove_child(boot)
	_check(
		boot.get_main() == null
			and completions.is_empty()
			and boot.find_children("*", "GameFlow", false, false).is_empty(),
		"detaching staged boot retires its incomplete Main before a completion exists"
	)
	await process_frame
	await process_frame
	_check((boot.get("_startup_textures") as Array).is_empty()
		and boot.get("_resource_worker") == null,
		"canceled construction releases warmed textures and stale continuation cannot adopt them")
	var canceled_children_freed := not canceled_child_refs.is_empty()
	for child_ref in canceled_child_refs:
		canceled_children_freed = canceled_children_freed and child_ref.get_ref() == null
	_check(canceled_children_freed,
		"canceling Boot frees all staged Main children even while its stager is retained")
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
	var warmed_texture_refs: Array[WeakRef] = []
	var stages := {}
	var watcher := func() -> void:
		if warmed_texture_refs.is_empty():
			for texture: Texture2D in boot.get("_startup_textures") as Array:
				warmed_texture_refs.append(weakref(texture))
		var live := boot.get_loading_screen()
		if is_instance_valid(live):
			samples.append(live.get_progress())
			stages[live.get_stage_text()] = true
		var live_main := boot.get_main() as GameFlow
		if live_main != null:
			var stager := live_main.get("_startup_stager") as MainStartupStager
			if stager != null and stager.is_prepared() \
					and bool(stager.get("_gameplay_startup_started")):
				_check(not bool(live_main.get("_initialized")),
					"real gameplay remains uninitialized between loading phases")
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
	_check(warmed_texture_refs.size() == 3 and (boot.get("_startup_textures") as Array).is_empty(),
		"real Boot retains exactly three warmed textures then releases its owner after construction")
	if warmed_texture_refs.size() == 3:
		var materials := (main as GameFlow).ship.get_variant_materials()
		var slots := ["albedo_texture", "normal_texture", "roughness_texture"]
		var paths := ["res://assets/materials/torrent-hull-albedo-v1.png",
			"res://assets/materials/torrent-hull-normal-v1.png",
			"res://assets/materials/torrent-hull-roughness-v1.png"]
		for index in range(3):
			var texture := warmed_texture_refs[index].get_ref() as Texture2D
			_check(texture != null and texture.resource_path == paths[index]
				and materials.ivory.get(slots[index]) == texture
				and materials.light.get(slots[index]) == texture,
				"Torrent materials retain the exact worker-loaded resource after handoff: " + slots[index])

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
	var expected_tail := ["Restoring pilot settings", "Registering the fleet",
		"Connecting yard activities", "Applying pilot settings", "Bringing systems online"]
	var actual_tail: Array[String] = []
	for row: Dictionary in report.get("stages", []):
		if expected_tail.has(row.get("label", "")):
			actual_tail.append(String(row.label))
	_check(actual_tail == expected_tail, "real GameFlow completes each startup phase in its original order")
	var settings_report := (main as GameFlow).get_runtime_settings_persistence_report()
	_check(int(settings_report.load_attempt_count) == 1 and bool(settings_report.load_before_first_apply),
		"staged gameplay loads settings once before their first application")
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


func _test_live_boot_rejects_incomplete_fleet() -> void:
	for queue_fleet in [false, true]:
		var boot := InterruptedFleetLoader.new()
		boot.auto_start = false
		boot.queue_fleet = queue_fleet
		root.add_child(boot)
		var completions: Array[Node] = []
		boot.startup_completed.connect(func(main: Node) -> void: completions.append(main))
		var main := await boot.run_startup()
		var report := boot.get_startup_report()
		var screen := boot.get_loading_screen()
		var ready_published := false
		for row: Dictionary in report.stages:
			ready_published = ready_published or row.get("label", "") == "Shipyard ready"
		_check(main == null and boot.get_main() == null and completions.is_empty()
			and not bool(boot.get("_running")) and not ready_published
			and float(report.time_to_interactive_ms) == 0.0
			and screen.get_stage_text() == "Startup failed"
			and not bool(screen.get_report().dismissed),
			"%s fleet under a live Main leaves a failed loading screen without admitting gameplay" % ("queued" if queue_fleet else "detached"))
		await process_frame
		await process_frame
		var freed := not boot.owned_main_children.is_empty()
		for reference in boot.owned_main_children:
			freed = freed and reference.get_ref() == null
		_check(freed, "incomplete startup frees attached and still-staged Main children")
		if queue_fleet:
			_check(not is_instance_valid(boot.interrupted_fleet),
				"failed startup releases its queued partial fleet")
		else:
			_check(is_instance_valid(boot.interrupted_fleet)
				and boot.interrupted_fleet.get_child_count() == 2
				and not boot.interrupted_fleet.is_composition_ready(),
				"detached partial fleet remains with its caller and cannot continue construction")
			boot.interrupted_fleet.free()
		boot.queue_free()
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
		main.world != null and main.player != null and main.hud != null
			and bool(main.get("_initialized")),
		"a directly instantiated coordinator completes gameplay startup synchronously in _ready()"
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
