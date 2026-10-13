extends SceneTree

## First-time nearby-sector activity briefings. Mirrors the first-sortie tutorial
## suites: authored copy per activity kind, real InputGlyphResolver glyphs for
## keyboard and Xbox device profiles, accessibility/reduced-motion behaviour,
## seen-once persistence across a store round trip, and the production GameFlow
## start seam publishing exactly one briefing per kind.

const Presenter := preload("res://scripts/ui/activity_tutorial_presenter.gd")
const GameFlowType := preload("res://scripts/game/game_flow.gd")
const SettingsType := preload("res://scripts/settings/runtime_settings.gd")
const SeenStoreType := preload("res://scripts/settings/tutorial_prompt_seen_store.gd")
const StoreType := preload("res://scripts/persistence/user_data_store.gd")
const FilesystemType := preload("res://scripts/persistence/user_data_filesystem.gd")
const HUD_SCENE := preload("res://scenes/ui/hud.tscn")
const ActivityBindingType := preload("res://scripts/world/nearby_sector_activity_binding.gd")
const ConvoyHostType := preload("res://scripts/activities/cinder_convoy_escort_host.gd")
const MiningType := preload("res://scripts/world/cinder_mining_platform_activity.gd")
const ScanType := preload("res://scripts/world/cinder_abandoned_structure_scan_activity.gd")

const STORE_PATH := "memory://activity-tutorial-user-data.json"

var _assertions := 0
var _failures: PackedStringArray = []


class MemoryFilesystem extends FilesystemType:
	var files: Dictionary = {}

	func file_exists(path: String) -> bool:
		return files.has(path)

	func directory_exists(_path: String) -> bool:
		return false

	func ensure_parent_directory(_path: String) -> Error:
		return OK

	func read_bytes(path: String, maximum_bytes: int) -> Dictionary:
		if not files.has(path):
			return {"error": ERR_FILE_NOT_FOUND, "bytes": PackedByteArray()}
		var bytes := (files[path] as PackedByteArray).duplicate()
		if bytes.size() > maximum_bytes:
			return {"error": ERR_FILE_CORRUPT, "bytes": PackedByteArray()}
		return {"error": OK, "bytes": bytes}

	func write_bytes_and_flush(path: String, bytes: PackedByteArray) -> Error:
		files[path] = bytes.duplicate()
		return OK

	func remove_path(path: String) -> Error:
		if not files.has(path):
			return ERR_FILE_NOT_FOUND
		files.erase(path)
		return OK

	func rename_path(from_path: String, to_path: String) -> Error:
		if not files.has(from_path):
			return ERR_FILE_NOT_FOUND
		files[to_path] = (files[from_path] as PackedByteArray).duplicate()
		files.erase(from_path)
		return OK


class BindingProbe extends Node3D:
	var starts: Array[StringName] = []

	func get_snapshot() -> Dictionary:
		return {
			"schema_version": 1,
			"activity_id": &"nearby",
			"generation": 0,
			"mining": {},
			"structure_scan": {},
			"beacon_traversal": {},
			"cargo": {},
		}

	func start_race() -> Dictionary:
		return _accept(&"cinder_reach_checkpoint_route")

	func start_patrol(_actor: Variant) -> Dictionary:
		return _accept(&"cinder_relay_patrol")

	func start_mining_activity(_position: Vector3) -> Dictionary:
		return _accept(&"cinder_platform_mining_run")

	func start_structure_scan(_position: Vector3) -> Dictionary:
		return _accept(&"cinder_derelict_structure_scan")

	func start_beacon_traversal(_position: Vector3) -> Dictionary:
		return _accept(&"cinder_debris_beacon_traversal")

	func start_cargo_run() -> Dictionary:
		return _accept(&"cinder_platform_supply_run")

	func _accept(activity_id: StringName) -> Dictionary:
		starts.append(activity_id)
		return {"accepted": true, "activity_id": activity_id}


class ClusterProbe extends Node3D:
	func _init() -> void:
		var binding := BindingProbe.new()
		binding.name = "ActivityBinding"
		add_child(binding)


class WorldProbe extends Node3D:
	var cluster := ClusterProbe.new()

	func _init() -> void:
		add_child(cluster)

	func get_nearby_sector_cluster() -> Node3D:
		return cluster


func _init() -> void:
	call_deferred(&"_run")


func _run() -> void:
	_check(
		Presenter.ACTIVITY_ORDER.size() == Presenter.ACTIVITY_COPY.size()
		and Presenter.ACTIVITY_ORDER.size() == 16,
		"the activity briefing family is frozen at one prompt per offered activity",
	)
	var hud := HUD_SCENE.instantiate()
	root.add_child(hud)
	await process_frame
	var title := hud.get("_runtime_status_title") as Label
	var detail := hud.get("_runtime_status_detail") as Label
	var glyph_presenter: Variant = hud.get("_runtime_input_glyph_presenter")

	# Every activity kind, on both a keyboard and an Xbox controller profile,
	# must produce one complete prompt with no unresolved glyph token left in it.
	for device_family: StringName in [&"keyboard", &"gamepad_xbox"]:
		glyph_presenter.set_device_family(device_family)
		hud.call(&"_refresh_input_prompts")
		var seen_titles := {}
		for index in Presenter.ACTIVITY_ORDER.size():
			var activity_id: StringName = Presenter.ACTIVITY_ORDER[index]
			hud.clear_activity_tutorial(&"next_case")
			var applied: bool = hud.apply_activity_tutorial_snapshot({
				"activity_id": activity_id,
				"generation": index + 1,
				"revision": 1,
			})
			var copy := Presenter.ACTIVITY_COPY[activity_id] as Dictionary
			var glyph_ok := true
			for action: StringName in Presenter.GLYPH_ACTIONS:
				if not str(copy.controller).contains("{%s}" % String(action)):
					continue
				var resolved := str(
					glyph_presenter.resolve_action(action).get("text", "")
				)
				glyph_ok = glyph_ok and not resolved.is_empty() \
					and detail.text.contains(resolved)
			seen_titles[str(copy.title)] = true
			_check(
				applied
				and not str(copy.title).is_empty()
				and title.text == str(copy.title)
				and detail.text.length() > str(copy.title).length()
				and not detail.text.contains("{")
				and detail.text.contains("NEXT ACTION // ")
				and detail.text.contains("RECOVERY // ")
				and glyph_ok,
				"%s briefing renders resolved %s copy on the tutorial channel" % [
					String(activity_id), String(device_family),
				],
			)
			if activity_id in [&"cinder_platform_mining_run", &"cinder_derelict_structure_scan"]:
				_check_hold_briefing(detail.text, activity_id)
		_check(
			seen_titles.size() == Presenter.ACTIVITY_ORDER.size(),
			"each %s activity kind yields its own distinct briefing" % String(device_family),
		)
	await _check_production_hold_behaviors()
	for activity_id: StringName in [&"cinder_platform_mining_run", &"cinder_derelict_structure_scan"]:
		var hold_presenter := Presenter.new()
		var remapped := hold_presenter.present_snapshot({
			"activity_id": activity_id, "generation": 1,
			"glyphs": {&"brake": "CUSTOM BRAKE"}, "input_family": &"keyboard",
		})
		_check(remapped.accepted and remapped.prompt.contains("CUSTOM BRAKE")
			and not remapped.prompt.contains("{brake}"),
			"%s optional braking follows caller-resolved remapped controls" % activity_id)
		var accessible_hold := hold_presenter.present_snapshot({
			"activity_id": activity_id, "generation": 2, "accessible": true,
		})
		_check(accessible_hold.accepted and accessible_hold.prompt == accessible_hold.accessible_prompt
			and not accessible_hold.prompt.contains("{"),
			"%s accessible hold instruction is glyph-free" % activity_id)
		_check_hold_briefing(accessible_hold.prompt, activity_id)

	# Accessibility and reduced-motion presets reach the same retained card.
	var settings := SettingsType.new("user://activity_tutorial_presenter_test.cfg")
	settings.reduced_motion = true
	settings.reduced_flash = true
	hud.set_accessibility(settings.get_accessibility_descriptor())
	hud.clear_activity_tutorial(&"accessibility_case")
	_check(
		hud.apply_activity_tutorial_snapshot({
			"activity_id": &"station_defense", "generation": 90, "revision": 1,
		})
		and hud.get("_reduced_motion")
		and (hud.get("_runtime_status_panel") as PanelContainer).visible
		and detail.text.contains("NEXT ACTION // HOLD THE PERIMETER"),
		"a reduced-motion, reduced-flash preset still renders the briefing text",
	)
	var accessible_presenter := Presenter.new()
	var accessible := accessible_presenter.present_snapshot({
		"activity_id": &"station_defense", "generation": 1, "revision": 1,
		"accessible": true,
	})
	_check(
		accessible.accepted
		and accessible.prompt == accessible.accessible_prompt
		and not accessible.prompt.contains("{")
		and accessible.color_independent
		and accessible.prompt.contains("RECOVERY // PERIMETER BREACHED"),
		"the accessible variant is glyph-free, colour-independent and keeps recovery guidance",
	)
	var disabled := accessible_presenter.present_snapshot({
		"activity_id": &"cinder_relay_patrol", "generation": 2, "revision": 1,
		"show_tutorials": false,
	})
	_check(
		not disabled.accepted
		and disabled.reason == &"tutorials_disabled"
		and not disabled.has("completion_intent"),
		"the show-tutorials accessibility setting suppresses briefings without completion",
	)
	var unknown := accessible_presenter.present_snapshot({
		"activity_id": &"heavy_breach", "generation": 3, "revision": 1,
	})
	_check(
		not unknown.accepted and unknown.reason == &"unknown_activity",
		"an unlisted activity kind fails closed instead of inventing copy",
	)
	settings.reduced_motion = false
	settings.reduced_flash = false
	hud.set_accessibility(settings.get_accessibility_descriptor())
	hud.clear_activity_tutorial(&"case_complete")
	root.remove_child(hud)
	hud.queue_free()
	await process_frame

	# Seen-once persistence: the same user-data document, beside runtime settings.
	var filesystem := MemoryFilesystem.new()
	var store := StoreType.new(STORE_PATH, filesystem)
	_check(bool(store.load().accepted), "seen-set store opens the shared user-data document")
	var seed_payload := store.get_snapshot()
	seed_payload["runtime_settings"] = {"schema_version": 1}
	_check(
		bool(store.commit(seed_payload, store.get_generation(), "seed-settings").accepted),
		"an unrelated settings namespace already occupies the document",
	)
	var seen_store := SeenStoreType.new(store)
	_check(bool(seen_store.restore().accepted) and not seen_store.has_seen(&"cinder_relay_patrol"), "a first run has seen no briefing")
	var marked := seen_store.mark_seen(&"cinder_relay_patrol", "activity-tutorial-0000000001")
	_check(
		bool(marked.accepted) and marked.reason == &"persisted"
		and seen_store.has_seen(&"cinder_relay_patrol"),
		"showing a briefing records it in the existing user-data document",
	)
	_check(
		store.get_snapshot().has("runtime_settings")
		and store.get_snapshot().has(SeenStoreType.PAYLOAD_NAMESPACE),
		"the seen-set is a sibling namespace and never replaces settings",
	)
	var reloaded_store := StoreType.new(STORE_PATH, filesystem)
	_check(bool(reloaded_store.load().accepted), "the document reloads from disk after the commit")
	var reloaded_seen := SeenStoreType.new(reloaded_store)
	_check(
		bool(reloaded_seen.restore().accepted)
		and reloaded_seen.has_seen(&"cinder_relay_patrol")
		and not reloaded_seen.has_seen(&"station_defense"),
		"a persistence round trip restores exactly the briefings already shown",
	)
	var corrupt_payload := reloaded_store.get_snapshot()
	corrupt_payload[SeenStoreType.PAYLOAD_NAMESPACE] = {
		"schema_version": SeenStoreType.SCHEMA_VERSION + 1, "seen_ids": [],
	}
	_check(
		bool(reloaded_store.commit(
			corrupt_payload, reloaded_store.get_generation(), "seed-newer-schema"
		).accepted)
		and not bool(SeenStoreType.new(reloaded_store).restore().accepted),
		"a newer seen-set schema is rejected instead of silently reset",
	)

	# Production GameFlow: the real start seam publishes one briefing per kind.
	var production_filesystem := MemoryFilesystem.new()
	var production_store := StoreType.new(STORE_PATH, production_filesystem)
	production_store.load()
	var production_hud := HUD_SCENE.instantiate()
	root.add_child(production_hud)
	var flow := GameFlowType.new()
	var world := WorldProbe.new()
	root.add_child(world)
	await process_frame
	flow.hud = production_hud
	flow.world = world
	flow.runtime_settings = SettingsType.new(
		"user://activity_tutorial_presenter_production_test.cfg"
	)
	flow._runtime_settings_user_data_store = production_store
	flow._ensure_tutorial_prompt_seen_store()
	var production_title := production_hud.get("_runtime_status_title") as Label
	var binding := world.cluster.get_node(^"ActivityBinding") as BindingProbe
	var board_started: Array[StringName] = [
		&"cinder_reach_checkpoint_route",
		&"cinder_relay_patrol",
		&"cinder_platform_mining_run",
		&"cinder_derelict_structure_scan",
		&"cinder_debris_beacon_traversal",
		&"cinder_platform_supply_run",
	]
	for activity_id in board_started:
		production_hud.clear_activity_tutorial(&"production_case")
		flow._on_hud_nearby_activity_intent_requested({
			"reason": &"start_requested", "activity_id": activity_id,
		})
		var expected := str((Presenter.ACTIVITY_COPY[activity_id] as Dictionary).title)
		_check(
			production_title.text == expected
			and _briefing_card_visible(production_hud)
			and flow._activity_tutorial_active_id == activity_id
			and flow.has_seen_activity_tutorial(activity_id),
			"the production start seam briefs %s the first time it runs" % String(activity_id),
		)
		if activity_id in [&"cinder_platform_mining_run", &"cinder_derelict_structure_scan"]:
			var production_detail := production_hud.get("_runtime_status_detail") as Label
			_check(binding.starts.back() == activity_id
				and production_detail.text.contains("Once active")
				and production_detail.text.contains("hold at the marker"),
				"%s briefing describes the accepted start's current hold, not a second start" % activity_id)
			_check_hold_briefing(production_detail.text, activity_id)
			var start_count := binding.starts.size()
			_check(flow.publish_activity_tutorial_briefing(activity_id, true)
				and binding.starts.size() == start_count
				and production_detail.text.contains("Once active")
				and not production_detail.text.contains("started at"),
				"re-showing %s explains the hold without claiming or starting a live activity" % activity_id)
		production_hud.clear_activity_tutorial(&"production_repeat")
		flow._activity_tutorial_active_id = &""
		flow._on_hud_nearby_activity_intent_requested({
			"reason": &"start_requested", "activity_id": activity_id,
		})
		_check(
			not _briefing_card_visible(production_hud)
			and flow._activity_tutorial_active_id.is_empty(),
			"a second %s start is silent once the briefing has been seen" % String(activity_id),
		)
	_check(
		binding.starts.size() == board_started.size() * 2,
		"briefing publication never replaces or duplicates the real activity start",
	)
	flow._on_hud_nearby_activity_intent_requested({
		"reason": &"start_requested", "activity_id": &"station_defense",
	})
	_check(
		not flow.has_seen_activity_tutorial(&"station_defense"),
		"a rejected activity start never consumes its one-time briefing",
	)
	_check(
		flow.activity_tutorial_prompt_id(GameFlowType.ACTIVITY_KIND_CONVOY_ESCORT)
			== GameFlowType.CINDER_CONVOY_ACTIVITY_ID
		and flow.activity_tutorial_prompt_id(GameFlowType.CINDER_PLATFORM_PATROL_ROUTE_ID)
			== &"cinder_relay_patrol"
		and flow.activity_tutorial_prompt_id(GameFlowType.CARGO_DELIVERY_ACTIVITY_ID)
			== &"cinder_platform_supply_run"
		and flow.activity_tutorial_prompt_id(&"heavy_breach").is_empty(),
		"free-flight sortie kinds and route ids resolve onto the same Cinder Reach briefings",
	)

	# The two places in the sector that have an inside get the same one-shot
	# treatment as the board activities, but their trigger is proximity rather
	# than a pressed start, so they are published directly here.
	for place_id: StringName in [
		&"cinder_hulk_power_restoration",
		&"cinder_asteroid_field_threading_run",
	]:
		production_hud.clear_activity_tutorial(&"place_case")
		flow._activity_tutorial_active_id = &""
		var place_copy := Presenter.ACTIVITY_COPY[place_id] as Dictionary
		_check(
			flow.publish_activity_tutorial_briefing(place_id)
			and production_title.text == str(place_copy.title)
			and _briefing_card_visible(production_hud)
			and flow.has_seen_activity_tutorial(place_id),
			"the first approach to %s briefs the pilot once" % String(place_id),
		)
		production_hud.clear_activity_tutorial(&"place_repeat")
		flow._activity_tutorial_active_id = &""
		_check(
			not flow.publish_activity_tutorial_briefing(place_id)
			and not _briefing_card_visible(production_hud),
			"a later approach to %s is silent" % String(place_id),
		)
		# The Destination Board's deliberate "show me again" is the one path
		# allowed past the seen-set, and it still starts nothing.
		_check(
			flow.publish_activity_tutorial_briefing(place_id, true)
			and production_title.text == str(place_copy.title)
			and _briefing_card_visible(production_hud),
			"the board can re-show the %s briefing on request" % String(place_id),
		)
	_check(
		binding.starts.size() == board_started.size() * 2,
		"a place briefing never starts an activity",
	)
	production_hud.clear_activity_tutorial(&"place_done")
	flow._activity_tutorial_active_id = &""

	# Retained-HUD re-entry redraws the live briefing without re-arming it.
	production_hud.clear_activity_tutorial(&"reentry_case")
	flow._activity_tutorial_active_id = &"cinder_relay_patrol"
	_check(
		flow._republish_activity_tutorial_presentation()
		and production_title.text == "Fly the relay patrol",
		"whole-Main re-entry republishes the retained briefing on the same channel",
	)
	production_hud.presentation_intent_requested.connect(
		flow._on_hud_presentation_intent_requested
	)
	var acknowledged: Dictionary = production_hud.request_activity_tutorial_action(&"next")
	_check(
		bool(acknowledged.accepted)
		and flow._activity_tutorial_active_id.is_empty()
		and not _briefing_card_visible(production_hud),
		"acknowledging the briefing retires it through the shared intent seam",
	)

	# Whole-Main re-entry and a reload both keep the seen-set.
	flow._record_activity_tutorial_seen(GameFlowType.ACTIVITY_BOARD_PROXIMITY_PROMPT_ID)
	flow._sync_production_runtime_settings_state()
	var reentered_flow := GameFlowType.new()
	reentered_flow._adopt_production_runtime_settings_state()
	_check(
			reentered_flow._tutorial_prompt_seen_store == flow._tutorial_prompt_seen_store
		and reentered_flow.has_seen_activity_tutorial(&"cinder_relay_patrol")
		and reentered_flow.has_seen_activity_tutorial(GameFlowType.ACTIVITY_BOARD_PROXIMITY_PROMPT_ID),
		"a re-entered Main adopts the same process-lifetime seen-set",
	)
	GameFlowType._production_runtime_settings_state = {}
	var reloaded_flow := GameFlowType.new()
	var reloaded_production_store := StoreType.new(STORE_PATH, production_filesystem)
	reloaded_production_store.load()
	reloaded_flow._runtime_settings_user_data_store = reloaded_production_store
	reloaded_flow._ensure_tutorial_prompt_seen_store()
	_check(
		reloaded_flow.has_seen_activity_tutorial(&"cinder_relay_patrol")
		and reloaded_flow.has_seen_activity_tutorial(&"cinder_platform_supply_run")
		and reloaded_flow.has_seen_activity_tutorial(GameFlowType.ACTIVITY_BOARD_PROXIMITY_PROMPT_ID)
		and not reloaded_flow.has_seen_activity_tutorial(&"station_defense"),
		"a fresh session reloads the persisted seen-set from the same document",
	)
	_check(
		reloaded_flow.has_seen_activity_tutorial(&"cinder_hulk_power_restoration")
		and reloaded_flow.has_seen_activity_tutorial(
			&"cinder_asteroid_field_threading_run"
		)
		and not reloaded_flow.publish_activity_tutorial_briefing(
			&"cinder_hulk_power_restoration"
		),
		"a re-entered session remembers both sector places and never re-briefs them",
	)
	_check(
		not reloaded_flow.publish_activity_tutorial_briefing(&"cinder_relay_patrol"),
		"a reloaded session never repeats a briefing the player has already read",
	)
	var early_flow := GameFlowType.new()
	early_flow._ensure_tutorial_prompt_seen_store()
	early_flow._record_activity_tutorial_seen(&"cinder_debris_beacon_traversal")
	_check(
		not early_flow._tutorial_prompt_seen_store.has_store()
		and early_flow.has_seen_activity_tutorial(&"cinder_debris_beacon_traversal"),
		"a briefing shown before the document opens is still remembered in memory",
	)
	var late_store := StoreType.new(STORE_PATH, production_filesystem)
	late_store.load()
	early_flow._runtime_settings_user_data_store = late_store
	early_flow._ensure_tutorial_prompt_seen_store()
	_check(
		early_flow._tutorial_prompt_seen_store.has_store()
		and early_flow.has_seen_activity_tutorial(&"cinder_debris_beacon_traversal")
		and early_flow.has_seen_activity_tutorial(&"cinder_relay_patrol"),
		"adopting the document later merges the persisted set with this session's",
	)
	early_flow.free()

	reentered_flow.free()
	reloaded_flow.free()
	flow.free()
	root.remove_child(world)
	world.free()
	root.remove_child(production_hud)
	production_hud.queue_free()
	await process_frame
	if _failures.is_empty():
		print("ACTIVITY_TUTORIAL_PRESENTER_TEST_OK (%d assertions)" % _assertions)
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)


func _check_hold_briefing(prompt: String, activity_id: StringName) -> void:
	var mining := activity_id == &"cinder_platform_mining_run"
	_check(prompt.contains("Once active") and prompt.contains("approach marker")
		and prompt.contains("activity row's Start") and prompt.contains("hold at the marker")
		and prompt.contains("100%") and not prompt.contains("{interact}")
		and not prompt.to_lower().contains("pad")
		and not prompt.to_lower().contains("scan point"),
		"%s briefing names the activation row and current hold without invented interactions" % activity_id)
	_check(prompt.contains("LEAVING RESETS PROGRESS")
		and prompt.contains("CHOOSE START AGAIN") if mining else (
			prompt.contains("LEAVING PAUSES PROGRESS")
			and prompt.contains("TO CONTINUE") and not prompt.contains("START AGAIN")),
		"%s recovery distinguishes a restarted extraction from a continuing scan" % activity_id)


func _check_production_hold_behaviors() -> void:
	var binding := ActivityBindingType.new()
	binding.add_child(ConvoyHostType.new())
	root.add_child(binding)
	await process_frame
	var pad_rejection := binding.start_mining_activity(MiningType.PLATFORM_ANCHOR)
	_check(not pad_rejection.accepted and pad_rejection.reason == &"outside_approach_anchor",
		"landing at the mining platform is outside its real extraction admission sphere")
	var mining_start := binding.start_mining_activity(MiningType.APPROACH_ANCHOR)
	var half_extraction := MiningType.EXTRACTION_SECONDS / 2.0
	var partial_mining := binding.advance_mining_activity_from_caller_sample(
		half_extraction, MiningType.APPROACH_ANCHOR)
	_check(mining_start.accepted and partial_mining.accepted
		and partial_mining.state == MiningType.State.ACTIVE
		and is_equal_approx(float(partial_mining.elapsed_seconds), half_extraction),
		"Start at the extraction approach marker admits the real six-second hold")
	var mining_left := binding.advance_mining_activity_from_caller_sample(
		1.0, MiningType.PLATFORM_ANCHOR)
	var mining_return := binding.advance_mining_activity_from_caller_sample(
		MiningType.EXTRACTION_SECONDS, MiningType.APPROACH_ANCHOR)
	_check(mining_left.reason == &"extraction_interrupted"
		and mining_left.state == MiningType.State.RESET
		and float(mining_left.elapsed_seconds) == 0.0 and not mining_return.accepted,
		"leaving extraction resets progress; returning alone cannot restart the hold")
	var mining_restart := binding.start_mining_activity(MiningType.APPROACH_ANCHOR)
	var mining_complete := binding.advance_mining_activity_from_caller_sample(
		MiningType.EXTRACTION_SECONDS, MiningType.APPROACH_ANCHOR)
	_check(mining_restart.accepted and mining_complete.accepted
		and mining_complete.state == MiningType.State.COMPLETE
		and mining_complete.generation == mining_start.generation + 1
		and float(mining_complete.elapsed_seconds) == MiningType.EXTRACTION_SECONDS,
		"choosing Start again admits a new extraction that completes after the full hold")
	var scan_start := binding.start_structure_scan(ScanType.APPROACH_ANCHOR)
	var half_scan := ScanType.SCAN_SECONDS / 2.0
	var partial_scan := binding.advance_structure_scan_from_caller_sample(
		half_scan, ScanType.APPROACH_ANCHOR)
	_check(scan_start.accepted and partial_scan.accepted
		and partial_scan.state == ScanType.State.SCANNING
		and is_equal_approx(float(partial_scan.elapsed_seconds), half_scan),
		"Start at the scan approach marker admits the real four-second hold")
	var scan_left := binding.advance_structure_scan_from_caller_sample(
		ScanType.SCAN_SECONDS, ScanType.APPROACH_ANCHOR + Vector3.RIGHT * (ScanType.INTERACTION_RADIUS + 1.0))
	_check(not scan_left.accepted and scan_left.reason == &"outside_scan_approach"
		and scan_left.generation == scan_start.generation
		and is_equal_approx(float(scan_left.elapsed_seconds), half_scan),
		"leaving the scan sphere pauses without erasing progress or changing generation")
	var scan_return := binding.advance_structure_scan_from_caller_sample(
		half_scan, ScanType.APPROACH_ANCHOR)
	_check(scan_return.accepted and scan_return.state == ScanType.State.COMPLETE
		and scan_return.generation == scan_start.generation
		and float(scan_return.elapsed_seconds) == ScanType.SCAN_SECONDS,
		"returning continues and completes the same scan without another Start or Interact")
	binding.queue_free()
	await process_frame


func _briefing_card_visible(hud: Variant) -> bool:
	var panel := hud.get("_runtime_status_panel") as PanelContainer
	return (
		(hud.get("_runtime_status_cards") as Dictionary).has(&"activity_tutorial")
		and StringName(str(hud.get("_runtime_status_kind"))) == &"activity_tutorial"
		and is_instance_valid(panel)
		and panel.visible
	)


func _check(condition: bool, message: String) -> void:
	_assertions += 1
	if condition:
		print("PASS: %s" % message)
	else:
		_failures.append("FAIL: " + message)
