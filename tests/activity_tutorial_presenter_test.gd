extends SceneTree

## First-time nearby-sector activity briefings. Mirrors the first-sortie tutorial
## suites: authored copy per activity kind, real InputGlyphResolver glyphs for
## keyboard and Xbox device profiles, accessibility/reduced-motion behaviour,
## seen-once persistence across a store round trip, and the production GameFlow
## start seam publishing exactly one briefing per kind.

const Presenter := preload("res://scripts/ui/activity_tutorial_presenter.gd")
const ActivityCardPresenter := preload("res://scripts/ui/nearby_sector_activity_presenter.gd")
const GameFlowType := preload("res://scripts/game/game_flow.gd")
const SettingsType := preload("res://scripts/settings/runtime_settings.gd")
const SeenStoreType := preload("res://scripts/settings/tutorial_prompt_seen_store.gd")
const StoreType := preload("res://scripts/persistence/user_data_store.gd")
const FilesystemType := preload("res://scripts/persistence/user_data_filesystem.gd")
const MAIN_SCENE := preload("res://scenes/main.tscn")
const HUD_SCENE := preload("res://scenes/ui/hud.tscn")
const ActivityBindingType := preload("res://scripts/world/nearby_sector_activity_binding.gd")
const ConvoyHostType := preload("res://scripts/activities/cinder_convoy_escort_host.gd")
const MiningType := preload("res://scripts/world/cinder_mining_platform_activity.gd")
const PatrolRoute := preload("res://assets/activities/cinder_reach_checkpoint_route.tres")
const BeaconType := preload("res://scripts/world/cinder_beacon_traversal_activity.gd")
const BeltRoute := preload("res://assets/activities/cinder_asteroid_field_threading_run.tres")
const ScanType := preload("res://scripts/world/cinder_abandoned_structure_scan_activity.gd")

const CargoAccessScene := preload("res://scenes/world/components/cinder_cargo_access.tscn")
const CargoTerminalScene := preload("res://scenes/world/modules/cargo_destination_terminal.tscn")
const JovianDefinition := preload("res://assets/ships/jovian_provisional.tres")

const STORE_PATH := "memory://activity-tutorial-user-data.json"

var _assertions := 0
var _failures: PackedStringArray = []


class MemoryFilesystem extends FilesystemType:
	var files: Dictionary = {}
	var fail_writes := false

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
		if fail_writes:
			return ERR_CANT_CREATE
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


# Only the actor identity is a probe; berth, manifests, phases and terminal
# admission below all use production components.
class JovianIdentityProbe extends Node3D:
	func get_ship_id() -> StringName:
		return &"jovian_provisional"


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
			if activity_id in [&"cinder_reach_checkpoint_route", &"cinder_debris_beacon_traversal", &"cinder_asteroid_field_threading_run"]:
				_check_route_briefing(detail.text, activity_id)
			if activity_id == &"cinder_relay_patrol":
				_check_patrol_briefing(detail.text)
			if activity_id in [&"shipyard_heavy_breach", &"shipyard_torpedo_run"]:
				_check_board_sortie_briefing(detail.text, activity_id)
			if activity_id == &"cinder_reach_emberline_convoy":
				_check_convoy_briefing(detail.text)
			if activity_id in [&"aurora_coastal_observation", &"rime_ice_core_survey"]:
				_check_surface_survey_briefing(detail.text, activity_id)
			if activity_id == &"cinder_platform_supply_run":
				_check_supply_briefing(detail.text)
		_check(
			seen_titles.size() == Presenter.ACTIVITY_ORDER.size(),
			"each %s activity kind yields its own distinct briefing" % String(device_family),
		)
	await _check_briefing_scroll_lifecycle(hud)
	await _check_production_board_sortie_briefings()
	_check_board_sortie_presentation_variants()
	_check_surface_survey_presentation_variants()
	await _check_production_convoy_behaviors()
	_check_convoy_presentation_variants()
	await _check_production_route_behaviors()
	_check_route_presentation_variants()
	await _check_production_patrol_behaviors()
	var patrol_presenter := Presenter.new()
	var remapped_patrol := patrol_presenter.present_snapshot({
		"activity_id": &"cinder_relay_patrol", "generation": 1,
		"glyphs": {&"brake": "CUSTOM BRAKE"}, "input_family": &"keyboard",
	})
	_check(remapped_patrol.accepted and remapped_patrol.prompt.contains("CUSTOM BRAKE if needed")
		and not remapped_patrol.prompt.contains("{brake}"),
		"patrol optional braking follows caller-resolved remapped controls")
	_check_patrol_briefing(remapped_patrol.prompt)
	var accessible_patrol := patrol_presenter.present_snapshot({
		"activity_id": &"cinder_relay_patrol", "generation": 2, "accessible": true,
	})
	_check(accessible_patrol.accepted and accessible_patrol.prompt == accessible_patrol.accessible_prompt
		and not accessible_patrol.prompt.contains("{"), "accessible patrol instruction is glyph-free")
	_check_patrol_briefing(accessible_patrol.prompt)
	await _check_production_hold_behaviors()
	await _check_production_supply_behaviors()
	var supply_presenter := Presenter.new()
	var remapped_supply := supply_presenter.present_snapshot({
		"activity_id": &"cinder_platform_supply_run", "generation": 1,
		"glyphs": {&"interact": "CUSTOM INTERACT"}, "input_family": &"keyboard",
	})
	_check(remapped_supply.accepted and remapped_supply.prompt.contains("CUSTOM INTERACT")
		and not remapped_supply.prompt.contains("{interact}"),
		"supply terminal delivery follows caller-resolved remapped interaction")
	_check_supply_briefing(remapped_supply.prompt)
	var accessible_supply := supply_presenter.present_snapshot({
		"activity_id": &"cinder_platform_supply_run", "generation": 2, "accessible": true,
	})
	_check(accessible_supply.accepted and accessible_supply.prompt == accessible_supply.accessible_prompt
		and not accessible_supply.prompt.contains("{"), "accessible supply instruction is glyph-free")
	_check_supply_briefing(accessible_supply.prompt)
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
		if activity_id == &"cinder_relay_patrol":
			var patrol_detail := production_hud.get("_runtime_status_detail") as Label
			_check_patrol_briefing(patrol_detail.text)
			var start_count := binding.starts.size()
			_check(flow.publish_activity_tutorial_briefing(activity_id, true)
				and binding.starts.size() == start_count,
				"re-showing patrol help never starts another patrol")
			_check_patrol_briefing(patrol_detail.text)
		if activity_id in [&"cinder_reach_checkpoint_route", &"cinder_debris_beacon_traversal"]:
			var route_detail := production_hud.get("_runtime_status_detail") as Label
			_check_route_briefing(route_detail.text, activity_id)
			var start_count := binding.starts.size()
			_check(flow.publish_activity_tutorial_briefing(activity_id, true)
				and binding.starts.size() == start_count,
				"re-showing route help never starts or resets an activity")
			production_hud.clear_activity_tutorial(&"route_retained_case")
			_check(flow._republish_activity_tutorial_presentation()
				and binding.starts.size() == start_count,
				"retained route help republishes without activating the route")
			_check_route_briefing(route_detail.text, activity_id)
		if activity_id == &"cinder_platform_supply_run":
			var supply_detail := production_hud.get("_runtime_status_detail") as Label
			_check_supply_briefing(supply_detail.text)
			var start_count := binding.starts.size()
			_check(flow.publish_activity_tutorial_briefing(activity_id, true)
				and binding.starts.size() == start_count,
				"re-showing the supply instructions never starts another run")
			production_hud.clear_activity_tutorial(&"supply_retained_case")
			_check(flow._republish_activity_tutorial_presentation(),
				"retained supply briefing republishes after HUD re-entry")
			_check_supply_briefing(supply_detail.text)
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
		and production_title.text == "Fly the patrol route",
		"whole-Main re-entry republishes the retained briefing on the same channel",
	)
	_check_patrol_briefing((production_hud.get("_runtime_status_detail") as Label).text)
	var alias_start_count := binding.starts.size()
	_check(flow.publish_activity_tutorial_briefing(GameFlowType.CINDER_PLATFORM_PATROL_ROUTE_ID, true)
		and production_title.text == "Fly the patrol route" and binding.starts.size() == alias_start_count,
		"PlatformPatrol re-shows the shared route briefing without starting an activity")
	_check_patrol_briefing((production_hud.get("_runtime_status_detail") as Label).text)
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


func _check_briefing_scroll_lifecycle(hud: Variant) -> void:
	hud.clear_activity_tutorial(&"scroll_case")
	var applied: bool = hud.apply_activity_tutorial_snapshot({
		"activity_id": &"shipyard_torpedo_run", "generation": 1, "revision": 1,
	})
	await process_frame
	await process_frame
	var scroll := hud.get("_runtime_status_scroll") as ScrollContainer
	scroll.scroll_vertical = 24
	await process_frame
	var reading_position := scroll.scroll_vertical
	_check(applied and reading_position > 0,
		"the authored torpedo briefing can be scrolled to its later guidance")
	var detail := hud.get("_runtime_status_detail") as Label
	var controller_copy := detail.text
	var glyph_presenter: Variant = hud.get("_runtime_input_glyph_presenter")
	glyph_presenter.set_device_family(&"keyboard")
	hud.call(&"_refresh_input_prompts")
	await process_frame
	await process_frame
	_check(detail.text != controller_copy and scroll.scroll_vertical == reading_position,
		"a live keyboard glyph refresh preserves the same briefing's reading position")
	applied = hud.apply_activity_tutorial_snapshot({
		"activity_id": &"shipyard_heavy_breach", "generation": 2, "revision": 1,
	})
	await process_frame
	await process_frame
	_check(applied and scroll.scroll_vertical == 0,
		"a distinct activity briefing opens at its activation instruction instead of the prior recovery text")
	scroll.scroll_vertical = 24
	await process_frame
	_check(scroll.scroll_vertical > 0,
		"the authored heavy-breach briefing also has a later reading position")
	applied = hud.apply_activity_tutorial_snapshot({
		"activity_id": &"shipyard_heavy_breach", "generation": 3, "revision": 1,
	})
	await process_frame
	await process_frame
	_check(applied and scroll.scroll_vertical == 0,
		"re-showing an activity as a fresh briefing generation starts at the top")
	hud.clear_activity_tutorial(&"scroll_done")


func _check_route_briefing(prompt: String, activity_id: StringName) -> void:
	_check(prompt.contains("activity row's Start") and prompt.contains("in order")
		and prompt.contains("NEXT UNFINISHED") and not prompt.contains("LAST MARKER")
		and not prompt.contains("LAST LIT BEACON"),
		"%s help starts explicitly and recovers at the next unfinished target" % activity_id)
	if activity_id == &"cinder_reach_checkpoint_route":
		_check(prompt.contains("countdown") and prompt.contains("After the start signal")
			and prompt.contains("TIME EXPIRED") and prompt.contains("NEW COUNTDOWN"),
			"race help waits for the start signal and restarts after expiry")
	elif activity_id == &"cinder_debris_beacon_traversal":
		_check(prompt.contains("first beacon") and prompt.contains("all four")
			and prompt.contains("CLEARED BEACONS STAY CLEARED WITHOUT START"),
			"beacon help names first-beacon admission and retained progress")
		_check(prompt.contains("REWARD SAVE PENDING // CLEARED ROUTE RETAINED")
			and prompt.contains("CHOOSE START TO RETRY REWARD SAVE"),
			"beacon help names the existing Start retry for an unpaid completed route")
	else:
		_check(prompt.contains("first gate") and prompt.contains("all five")
			and prompt.contains("RESET ABANDONS PROGRESS") and prompt.contains("FAILED OR RESET"),
			"belt help names first-gate admission and deliberate restart recovery")


func _check_route_presentation_variants() -> void:
	for activity_id: StringName in [&"cinder_reach_checkpoint_route",
			&"cinder_debris_beacon_traversal", &"cinder_asteroid_field_threading_run"]:
		var presenter := Presenter.new()
		var presented := presenter.present_snapshot({
			"activity_id": activity_id, "generation": 1, "input_family": &"keyboard",
			"glyphs": {&"move_forward": "CUSTOM THROTTLE", &"sprint_boost": "CUSTOM BOOST",
				&"brake": "CUSTOM BRAKE"},
		})
		_check(presented.accepted and not presented.prompt.contains("{")
			and presented.prompt.contains("CUSTOM "), "route copy uses remapped controls")
		_check_route_briefing(presented.prompt, activity_id)
		var retained := presenter.get_snapshot()
		retained.prompt = "mutated consumer"
		_check_route_briefing(presenter.get_snapshot().prompt, activity_id)
		var repeated := presenter.request(&"repeat")
		_check(repeated.accepted and not presenter.get_snapshot().activity_authority,
			"repeating route help returns a presentation intent without activity authority")
		var accessible := presenter.present_snapshot({
			"activity_id": activity_id, "generation": 2, "accessible": true,
		})
		_check(accessible.accepted and accessible.prompt == accessible.accessible_prompt
			and not accessible.prompt.contains("{"), "accessible route copy is glyph-free")
		_check_route_briefing(accessible.prompt, activity_id)


func _check_production_route_behaviors() -> void:
	var binding := ActivityBindingType.new()
	binding.add_child(ConvoyHostType.new())
	root.add_child(binding)
	await process_frame
	var first_beacon := BeaconType.BEACONS[0]
	var rejected := binding.start_beacon_traversal(BeaconType.BEACONS[1])
	var started := binding.start_beacon_traversal(first_beacon)
	var wrong := binding.submit_beacon_traversal(1, BeaconType.BEACONS[1])
	var cleared := binding.advance_beacon_traversal_from_caller_sample(first_beacon)
	var left := binding.advance_beacon_traversal_from_caller_sample(Vector3.ZERO)
	var old := binding.advance_beacon_traversal_from_caller_sample(first_beacon)
	var returned := binding.advance_beacon_traversal_from_caller_sample(BeaconType.BEACONS[1])
	_check(not rejected.accepted and rejected.reason == &"outside_first_beacon"
		and started.accepted and not wrong.accepted and wrong.reason == &"out_of_order_beacon"
		and cleared.next_beacon_index == 1,
		"production beacon route needs Start at its first beacon and ordered targets")
	_check(not left.accepted and not old.accepted and left.next_beacon_index == 1
		and old.next_beacon_index == 1 and returned.accepted and returned.next_beacon_index == 2
		and returned.generation == started.generation,
		"leaving and returning to a cleared beacon cannot advance or reset the active route")
	var race_start := binding.start_race()
	var early := binding.submit_race_position(PatrolRoute.get_checkpoint_position(0))
	binding.advance_race(ActivityBindingType.CINDER_RACE_COUNTDOWN_SECONDS)
	var gate := binding.submit_race_position(PatrolRoute.get_checkpoint_position(0))
	var later := binding.submit_race_position(PatrolRoute.get_checkpoint_position(2))
	var previous := binding.submit_race_position(PatrolRoute.get_checkpoint_position(0))
	var next := binding.submit_race_position(PatrolRoute.get_checkpoint_position(1))
	_check(race_start.accepted and not early.accepted and early.reason == &"countdown_in_progress"
		and gate.accepted and gate.next_checkpoint_index == 1,
		"production race Start counts down before the first gate can be accepted")
	_check(not later.accepted and not previous.accepted
		and later.next_checkpoint_index == 1 and previous.next_checkpoint_index == 1
		and next.accepted and next.next_checkpoint_index == 2,
		"missed race gates retain progress and require the next unfinished gate")
	var expired := binding.advance_race(120.0)
	var restarted := binding.start_race()
	_check(expired.state_id == &"failed" and restarted.accepted
		and restarted.state_id == &"countdown" and restarted.next_checkpoint_index == 0,
		"an expired production race accepts Start for a fresh countdown and route")
	var belt_rejected := binding.start_asteroid_field_run(Vector3.ZERO)
	var belt_started := binding.start_asteroid_field_run(BeltRoute.get_checkpoint_position(0))
	var belt_first := binding.submit_asteroid_field_run_position(BeltRoute.get_checkpoint_position(0))
	var belt_wrong := binding.submit_asteroid_field_run_position(BeltRoute.get_checkpoint_position(2))
	var belt_old := binding.submit_asteroid_field_run_position(BeltRoute.get_checkpoint_position(0))
	var belt_next := binding.submit_asteroid_field_run_position(BeltRoute.get_checkpoint_position(1))
	_check(not belt_rejected.accepted and belt_rejected.reason == &"outside_first_gate"
		and belt_started.accepted and belt_first.next_checkpoint_index == 1
		and not belt_wrong.accepted and not belt_old.accepted
		and belt_old.next_checkpoint_index == 1 and belt_next.next_checkpoint_index == 2,
		"production belt run starts at its first gate and preserves the next unfinished gate")
	var belt_reset := binding.reset_asteroid_field_run()
	var belt_not_started := binding.submit_asteroid_field_run_position(BeltRoute.get_checkpoint_position(0))
	var belt_restarted := binding.start_asteroid_field_run(BeltRoute.get_checkpoint_position(0))
	_check(belt_reset.accepted and belt_reset.next_checkpoint_index == 0
		and not belt_not_started.accepted and belt_restarted.accepted
		and belt_restarted.next_checkpoint_index == 0,
		"Reset deliberately abandons belt progress; Start at the first gate begins again")
	var belt_director := binding.get("_asteroid_run_director") as ActivityDirector
	var belt_failed := belt_director.fail_activity(
		ActivityBindingType.ASTEROID_RUN_ACTIVITY_ID, &"asteroid_impact", int(belt_restarted.generation))
	var failed_belt := binding.get_activity_snapshot(&"asteroid_field_run")
	var failed_view := ActivityCardPresenter.new().present(binding.get_snapshot())
	var retry_card: Dictionary = {}
	for card: Dictionary in failed_view.cards:
		if card.activity_id == ActivityBindingType.ASTEROID_RUN_ACTIVITY_ID:
			retry_card = card
	_check(belt_failed and failed_belt.state_id == &"failed"
		and str(retry_card.get("text", "")).contains("RETURN TO THE FIRST BELT GATE AND CHOOSE START TO RETRY")
		and not str(retry_card.get("text", "")).contains("RESET BEFORE RETRYING"),
		"the failed belt's ordinary activity card names first-gate Start without an invented Reset prerequisite")
	var impact_retry := binding.start_asteroid_field_run(BeltRoute.get_checkpoint_position(0))
	_check(impact_retry.accepted and impact_retry.state_id == &"active"
		and impact_retry.generation == failed_belt.generation + 1
		and impact_retry.next_checkpoint_index == 0,
		"Start at the first belt gate directly retries an impact failure as a fresh generation")
	binding.queue_free()
	await process_frame


func _check_patrol_briefing(prompt: String) -> void:
	_check(prompt.contains("activity row's Start") and prompt.contains("selected patrol")
		and prompt.contains("marked waypoints in order") and prompt.contains("hold continuously")
		and prompt.contains("two seconds") and prompt.contains("if needed")
		and prompt.contains("LEAVING RESETS THE CURRENT HOLD")
		and prompt.contains("WHILE ACTIVE, RE-ENTER THE SAME UNFINISHED WAYPOINT WITHOUT START")
		and prompt.contains("FAILED OR ABORTED // CHOOSE START TO RETRY")
		and not prompt.contains("CHOOSE RESET THEN START")
		and not prompt.contains("PATROL LAPSED") and not prompt.contains("last relay"),
		"shared patrol help describes selected waypoints, continuous holds and state-specific recovery")


func _check_production_patrol_behaviors() -> void:
	var binding := ActivityBindingType.new()
	binding.add_child(ConvoyHostType.new())
	root.add_child(binding)
	var actor := Node3D.new()
	root.add_child(actor)
	await process_frame
	var started := binding.start_patrol(actor)
	var first_point: Vector3 = PatrolRoute.get_checkpoint_position(0)
	binding.advance_patrol(0.75, actor, first_point)
	var interrupted := binding.advance_patrol(0.25, actor,
		first_point + Vector3.RIGHT * (PatrolRoute.checkpoint_radius + 1.0))
	_check(started.accepted and interrupted.reason == &"dwell_interrupted"
		and interrupted.state_id == &"active" and interrupted.generation == started.generation
		and int(interrupted.next_checkpoint_index) == 0
		and is_zero_approx(float(interrupted.dwell_elapsed_seconds)),
		"leaving resets only the current patrol hold while the same generation stays ACTIVE")
	var returned := binding.advance_patrol(0.75, actor, first_point)
	var secured := binding.advance_patrol(1.25, actor, first_point)
	_check(returned.state_id == &"active" and returned.generation == started.generation
		and int(returned.next_checkpoint_index) == 0
		and is_equal_approx(float(returned.dwell_elapsed_seconds), 0.75)
		and secured.generation == started.generation and int(secured.next_checkpoint_index) == 1
		and int(secured.completed_checkpoint_count) == 1,
		"re-entry restarts the same unfinished waypoint hold without Start, then targets the next waypoint")
	# The shared briefing and retained patrol row must advertise the same
	# terminal recovery: Start already accepts a failed or aborted patrol.
	for terminal_id: StringName in [&"failed", &"aborted"]:
		var terminal := binding.fail_patrol(&"route_obstructed") if terminal_id == &"failed" \
			else binding.abort_patrol(&"player_requested")
		var terminal_generation := int((binding.get_snapshot().patrol as Dictionary).generation)
		var restarted := binding.start_patrol(actor)
		_check(bool(terminal.get("accepted", false)) and bool(restarted.get("accepted", false))
			and restarted.state_id == &"active" and int(restarted.generation) > terminal_generation
			and int(restarted.next_checkpoint_index) == 0
			and int(restarted.completed_checkpoint_count) == 0,
			"%s patrol accepts the briefing's direct Start retry as a fresh route without Reset" % terminal_id)
	actor.queue_free()
	binding.queue_free()
	await process_frame


func _check_supply_briefing(prompt: String) -> void:
	_check(prompt.contains("activity row's Start") and prompt.contains("cargo is supplied automatically")
		and prompt.contains("Depart beyond the berth gate") and prompt.contains("return and dock")
		and prompt.contains("leave the seat") and prompt.contains("platform cargo terminal")
		and not prompt.contains("take on cargo") and prompt.contains("RESET AND START AGAIN"),
		"supply briefing separates automatic loading, the physical route and final on-foot terminal delivery")


func _check_production_supply_behaviors() -> void:
	var stage := Node3D.new()
	root.add_child(stage)
	var binding := ActivityBindingType.new()
	binding.add_child(ConvoyHostType.new())
	stage.add_child(binding)
	var access := CargoAccessScene.instantiate() as CinderCargoAccess
	stage.add_child(access)
	var terminal := CargoTerminalScene.instantiate() as CargoTransferTerminal
	stage.add_child(terminal)
	terminal.transform = CinderCargoAccess.DESTINATION_TERMINAL_ROOT_LOCAL
	var ship := JovianIdentityProbe.new()
	stage.add_child(ship)
	var actor := Node3D.new()
	stage.add_child(actor)
	await process_frame
	var bound := binding.bind_cargo_access(access, terminal, access.get_attachment_generation())
	var not_docked := binding.start_cargo_run()
	var berth := access.get_berth()
	var lease := berth.try_reserve(ship, JovianDefinition)
	var occupied := berth.occupy(ship, lease)
	ship.global_transform = berth.get_dock_transform()
	var authority := binding.get_cargo_transfer_authority()
	var source := binding.get_cargo_source_handle()
	var destination := binding.get_cargo_destination_handle()
	var started := binding.start_cargo_run()
	var loaded := binding.advance_cargo_run_from_caller_sample(0.1, ship.get_instance_id(), ship.global_position)
	_check(bound.accepted and not not_docked.accepted and occupied and started.accepted
		and loaded.get("production_phase_id") == &"load_crate"
		and authority.get_quantity(source, &"cinder_supply_crates") == 2,
		"a docked Jovian starts with real cargo aboard and advances loading without Interact")
	actor.global_position = access.get_route_marker(&"berth_exit").global_position
	var authorized := binding.authorize_cargo_terminal_actor(actor, ship)
	actor.global_position = terminal.get_node(^"PlayerApproach").global_position
	terminal.interact(actor)
	_check(authorized.accepted and binding.get_last_cargo_terminal_request().reason == &"phases_incomplete"
		and authority.get_quantity(destination, &"cinder_supply_crates") == 0,
		"terminal interaction cannot deliver before departure and return")
	var released := berth.release(ship, lease)
	var inside := binding.advance_cargo_run_from_caller_sample(0.1, ship.get_instance_id(), ship.global_position)
	ship.global_position = access.get_supply_phase_target_position(&"clear_gate")
	var cleared := binding.advance_cargo_run_from_caller_sample(0.1, ship.get_instance_id(), ship.global_position)
	ship.global_transform = berth.get_dock_transform()
	lease = berth.try_reserve(ship, JovianDefinition)
	occupied = berth.occupy(ship, lease)
	var docked := binding.advance_cargo_run_from_caller_sample(0.1, ship.get_instance_id(), ship.global_position)
	_check(released and int(inside.next_phase_index) == 1
		and cleared.get("production_phase_id") == &"clear_gate" and occupied
		and docked.get("production_phase_id") == &"dock_platform"
		and docked.state == CargoDeliveryActivity.State.ACTIVE,
		"the real berth gate and return occupancy advance the route but do not deliver the cargo")
	var expired := binding.advance_cargo_run(120.0)
	var rejected_restart := binding.start_cargo_run()
	var reset := binding.reset_cargo_run()
	var restarted := binding.start_cargo_run()
	_check(expired.state == CargoDeliveryActivity.State.EXPIRED
		and not rejected_restart.accepted and rejected_restart.reason == &"reset_required"
		and reset.accepted and restarted.accepted
		and authority.get_quantity(source, &"cinder_supply_crates") == 2,
		"an expired run must Reset then Start again while docked; cargo remains aboard")
	binding.advance_cargo_run_from_caller_sample(0.1, ship.get_instance_id(), ship.global_position)
	berth.release(ship, lease)
	ship.global_position = access.get_supply_phase_target_position(&"clear_gate")
	binding.advance_cargo_run_from_caller_sample(0.1, ship.get_instance_id(), ship.global_position)
	ship.global_transform = berth.get_dock_transform()
	lease = berth.try_reserve(ship, JovianDefinition)
	berth.occupy(ship, lease)
	binding.advance_cargo_run_from_caller_sample(0.1, ship.get_instance_id(), ship.global_position)
	actor.global_position = access.get_route_marker(&"berth_exit").global_position
	authorized = binding.authorize_cargo_terminal_actor(actor, ship)
	actor.global_position = terminal.get_node(^"PlayerApproach").global_position
	var interacted := terminal.interact(actor)
	var delivered := binding.get_last_cargo_terminal_request()
	_check(authorized.accepted and interacted and delivered.accepted
		and binding.get_snapshot().cargo.state == CargoDeliveryActivity.State.COMPLETED
		and authority.get_quantity(source, &"cinder_supply_crates") == 1
		and authority.get_quantity(destination, &"cinder_supply_crates") == 1,
		"only the authorized on-foot terminal interaction after return commits the delivery")
	stage.queue_free()
	await process_frame


func _check_hold_briefing(prompt: String, activity_id: StringName) -> void:
	var mining := activity_id == &"cinder_platform_mining_run"
	_check(prompt.contains("Once active") and prompt.contains("approach marker")
		and prompt.contains("activity row's Start") and prompt.contains("hold at the marker")
		and prompt.contains("100%") and not prompt.contains("{interact}")
		and not prompt.to_lower().contains("pad")
		and not prompt.to_lower().contains("scan point"),
		"%s briefing names the activation row and current hold without invented interactions" % activity_id)
	_check(prompt.contains("LEAVING RESETS PROGRESS")
		and prompt.contains("CHOOSE START AGAIN")
		and prompt.contains("IF CAPACITY SAVE FAILS AFTER COMPLETION")
		and prompt.contains("CHOOSE START TO RETRY THE CAPACITY RECEIPT")
		and prompt.contains("COMPLETED EXTRACTION RETAINED") if mining else (
			prompt.contains("LEAVING PAUSES PROGRESS")
			and prompt.contains("TO CONTINUE") and not prompt.contains("START AGAIN")
			and prompt.contains("IF REWARD NOT FILED AFTER COMPLETION")
			and prompt.contains("CHOOSE START TO RETRY THE MATERIAL SAMPLE REWARD")),
		"%s recovery distinguishes a restarted extraction from a continuing scan" % activity_id)


func _check_production_hold_behaviors() -> void:
	var binding := ActivityBindingType.new()
	binding.add_child(ConvoyHostType.new())
	root.add_child(binding)
	await process_frame
	var mining_filesystem := MemoryFilesystem.new()
	var mining_store := StoreType.new(STORE_PATH, mining_filesystem)
	var mining_loaded := mining_store.load()
	var mining_configured := binding.configure_cinder_mining_capacity_persistence(mining_store)
	_check(mining_loaded.accepted and mining_configured.accepted,
		"the extraction briefing scenario uses the production capacity persistence binding")
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
	# A failed terminal save retains extraction. The ordinary Start consumer
	# retries its capacity receipt without asking the player to repeat the hold.
	mining_filesystem.fail_writes = true
	var unsaved_capacity := binding.request_mining_reward()
	var retained_mining := binding.get_activity_snapshot(&"mining")
	_check(unsaved_capacity.accepted and not unsaved_capacity.capacity_persisted
		and retained_mining.persistence_retry_available
		and retained_mining.state == MiningType.State.COMPLETE
		and retained_mining.generation == mining_complete.generation,
		"a capacity save failure retains the completed extraction and exposes receipt retry")
	mining_filesystem.fail_writes = false
	var mining_retry_flow := GameFlowType.new()
	var saved_capacity := mining_retry_flow._start_nearby_activity(binding, &"cinder_platform_mining_run")
	var saved_mining := binding.get_activity_snapshot(&"mining")
	var duplicate_capacity := binding.retry_mining_capacity_persistence()
	_check(saved_capacity.accepted and saved_capacity.capacity_persisted
		and saved_mining.capacity_persisted and not saved_mining.persistence_retry_available
		and saved_mining.state == MiningType.State.COMPLETE
		and saved_mining.generation == mining_complete.generation
		and is_equal_approx(float(saved_mining.elapsed_seconds), MiningType.EXTRACTION_SECONDS)
		and not duplicate_capacity.accepted,
		"the briefing's Start action saves the retained capacity receipt once without another extraction")
	mining_retry_flow.free()
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
	# A refused reward leaves a completed scan. The real Start consumer retries
	# that handoff rather than starting another hold at the approach marker.
	var reward_attempts := [0]
	var configured := binding.configure_structure_scan_reward_handoff(
		func(_request: Dictionary) -> Dictionary:
			reward_attempts[0] += 1
			return {"accepted": reward_attempts[0] > 1, "granted": reward_attempts[0] > 1}
	)
	var refused_reward := binding.request_structure_scan_reward()
	var retained_scan := binding.get_snapshot().structure_scan as Dictionary
	_check(configured.accepted and not refused_reward.accepted
		and refused_reward.reason == &"structure_scan_reward_handoff_rejected"
		and retained_scan.state == ScanType.State.COMPLETE
		and retained_scan.generation == scan_start.generation
		and not retained_scan.reward_requested,
		"refused sample reward retains the completed scan instead of requiring another hold")
	var retry_flow := GameFlowType.new()
	var retried_reward := retry_flow._start_nearby_activity(binding, &"cinder_derelict_structure_scan")
	var paid_scan := binding.get_snapshot().structure_scan as Dictionary
	_check(retried_reward.accepted and retried_reward.reward_committed
		and reward_attempts[0] == 2 and paid_scan.reward_requested
		and paid_scan.state == ScanType.State.COMPLETE
		and paid_scan.generation == scan_start.generation
		and is_equal_approx(float(paid_scan.elapsed_seconds), ScanType.SCAN_SECONDS),
		"the briefing's Start action retries the retained sample reward without restarting the scan")
	retry_flow.free()
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


func _check_convoy_briefing(prompt: String) -> void:
	_check(prompt.contains("Depart the berth") and prompt.contains("healthy piloted craft")
		and prompt.contains("marked rendezvous") and prompt.contains("activity row's Start")
		and prompt.contains("automatically") and prompt.contains("marked route"),
		"convoy help names berth departure, rendezvous admission and the tender route")
	_check(prompt.contains("SEPARATED WHILE ACTIVE") and prompt.contains("BEFORE THREE SECONDS")
		and prompt.contains("CHOOSE RESET") and prompt.contains("FRESH ESCORT")
		and not prompt.contains("THROTTLE BACK ONTO THE HAULERS"),
		"convoy help distinguishes active separation recovery from terminal fresh restart")


func _check_convoy_presentation_variants() -> void:
	var presenter := Presenter.new()
	var remapped := presenter.present_snapshot({
		"activity_id": &"cinder_reach_emberline_convoy", "generation": 1,
		"input_family": &"keyboard", "glyphs": {&"fire": "CUSTOM FIRE"},
	})
	_check(remapped.accepted and remapped.prompt.contains("CUSTOM FIRE")
		and not remapped.prompt.contains("{"), "convoy help preserves caller-resolved fire controls")
	_check_convoy_briefing(remapped.prompt)
	var accessible := presenter.present_snapshot({
		"activity_id": &"cinder_reach_emberline_convoy", "generation": 2, "accessible": true,
	})
	_check(accessible.accepted and accessible.prompt == accessible.accessible_prompt
		and accessible.prompt.contains("fire control") and not accessible.prompt.contains("{"),
		"accessible convoy help is glyph-free")
	_check_convoy_briefing(accessible.prompt)


func _check_production_convoy_behaviors() -> void:
	var game := MAIN_SCENE.instantiate() as GameFlow
	var store := StoreType.new(STORE_PATH, MemoryFilesystem.new())
	game.configure_runtime_settings_persistence(store, "user://convoy-tutorial-legacy.cfg")
	root.add_child(game)
	await process_frame
	await physics_frame
	await process_frame
	game.set_physics_process(false)
	var host := game.get_node(^"CinderConvoyEscortHost") as CinderConvoyEscortHost
	var bootstrap := game.get_node(^"CinderStreamingBootstrap") as CinderStreamingBootstrap
	var ship := game.get_flyable_ships()[1] as HeroShip
	_check(game.select_activity_kind(GameFlow.ACTIVITY_KIND_CONVOY_ESCORT).accepted,
		"production convoy selection exposes rendezvous admission")
	ship.set_piloted(true)
	game.active_ship = ship
	game.set("_piloting", true)
	game.phase = GameFlow.Phase.FREE_FLIGHT
	ship.global_position = GameFlow.CINDER_CONVOY_ACTIVATION_CENTER
	game.set("_sortie_departed_berth", false)
	var docked := game.request_activity_start(GameFlow.CINDER_CONVOY_ACTIVITY_ID)
	_check(not docked.accepted and docked.reason == &"sortie_not_departed",
		"convoy Start rejects a craft that has not departed its berth")
	game.set("_sortie_departed_berth", true)
	ship.global_position += Vector3.RIGHT * (GameFlow.CINDER_CONVOY_ACTIVATION_RADIUS + 0.01)
	game.call(&"_physics_process", 0.1)
	for _frame in 20:
		if bootstrap.get_loaded_instance() != null:
			break
		await process_frame
	var outside := game.request_activity_start(GameFlow.CINDER_CONVOY_ACTIVITY_ID)
	_check(not outside.accepted and outside.reason == &"outside_convoy_activation_sphere",
		"convoy Start requires the actual marked rendezvous sphere")
	ship.global_position = GameFlow.CINDER_CONVOY_ACTIVATION_CENTER
	var started := game.request_activity_start(GameFlow.CINDER_CONVOY_ACTIVITY_ID)
	_check(started.accepted and host.get_snapshot().activity.state_id == &"active",
		"Start at the rendezvous admits the real production convoy")
	var generation := host.get_generation()
	var far := (host.get_snapshot().entity_position as Vector3) + Vector3.RIGHT * 60.0
	game.call(&"_advance_cinder_convoy", 0.5, far)
	var separated := host.get_snapshot().activity as Dictionary
	game.call(&"_advance_cinder_convoy", 0.1, host.get_snapshot().entity_position)
	var recovered := host.get_snapshot().activity as Dictionary
	_check(separated.state_id == &"active" and float(separated.separation_elapsed_seconds) > 0.0
		and recovered.state_id == &"active" and recovered.generation == generation
		and is_zero_approx(float(recovered.separation_elapsed_seconds)),
		"returning beside the tender clears separation without Start or a new generation")
	far = (host.get_snapshot().entity_position as Vector3) + Vector3.RIGHT * 60.0
	game.call(&"_advance_cinder_convoy", ConvoyHostType.DEFAULT_MAXIMUM_SEPARATION_SECONDS, far)
	var lost := host.get_snapshot().activity as Dictionary
	var refused := game.request_activity_start(GameFlow.CINDER_CONVOY_ACTIVITY_ID,
		GameFlow.CINDER_CONVOY_ACTIVATION_CENTER)
	_check(lost.state_id == &"failed" and lost.terminal_reason == &"escort_separation_exceeded"
		and not refused.accepted and refused.reason == &"reset_required",
		"three seconds of separation loses the convoy and Start alone cannot recover it")
	_check(game.reset_active_activity(), "production Reset admits recovery after convoy loss")
	ship.global_position = GameFlow.CINDER_CONVOY_ACTIVATION_CENTER
	var restarted := game.request_activity_start(GameFlow.CINDER_CONVOY_ACTIVITY_ID)
	var fresh := host.get_snapshot().activity as Dictionary
	_check(restarted.accepted and fresh.state_id == &"active" and fresh.generation > generation
		and fresh.completed_leg_count == 0 and is_zero_approx(float(fresh.elapsed_seconds)),
		"Reset then rendezvous Start creates a fresh escort with cleared route progress")
	paused = false
	game.set("_piloting", false)
	game.queue_free()
	await process_frame
	await process_frame


func _check_board_sortie_briefing(prompt: String, activity_id: StringName) -> void:
	_check(prompt.contains("On foot at the deck board") and prompt.contains("arm the posted")
		and prompt.contains("healthy combat craft") and prompt.contains("berth departure"),
		"%s help explains physical board admission before combat departure" % activity_id)
	_check(prompt.contains("RETRY DEPARTURE") and prompt.contains("AGAIN TO CANCEL")
		and prompt.contains("ARM THE CURRENT OFFER") and prompt.contains("ALTERNATE")
		and prompt.contains("REWARD SAVE PENDING") and not prompt.contains("CHOOSE RESET"),
		"%s help preserves armed retry, board cancellation, rotating offers and pending reward retry" % activity_id)
	_check(prompt.contains("protected station asset") if activity_id == &"shipyard_heavy_breach"
		else prompt.contains("destroy the torpedo boat"),
		"%s help names its actual cleared objective" % activity_id)


func _check_board_sortie_presentation_variants() -> void:
	for activity_id: StringName in [&"shipyard_heavy_breach", &"shipyard_torpedo_run"]:
		var presenter := Presenter.new()
		var remapped := presenter.present_snapshot({
			"activity_id": activity_id, "generation": 1, "input_family": &"keyboard",
			"glyphs": {&"interact": "CUSTOM INTERACT", &"fire": "CUSTOM FIRE",
				&"pitch_up": "CUSTOM PITCH", &"sprint_boost": "CUSTOM BOOST"},
		})
		_check(remapped.accepted and remapped.prompt.contains("CUSTOM INTERACT")
			and remapped.prompt.contains("CUSTOM FIRE") and not remapped.prompt.contains("{"),
			"%s board admission and combat use caller-resolved controls" % activity_id)
		_check_board_sortie_briefing(remapped.prompt, activity_id)
		var accessible := presenter.present_snapshot({
			"activity_id": activity_id, "generation": 2, "accessible": true,
		})
		_check(accessible.accepted and accessible.prompt == accessible.accessible_prompt
			and accessible.prompt.contains("interact control") and not accessible.prompt.contains("{"),
			"%s accessible board admission is glyph-free" % activity_id)
		_check_board_sortie_briefing(accessible.prompt, activity_id)


func _check_production_board_sortie_briefings() -> void:
	var game := MAIN_SCENE.instantiate() as GameFlow
	game.configure_runtime_settings_persistence(
		StoreType.new(STORE_PATH, MemoryFilesystem.new()), "user://board-tutorial-legacy.cfg")
	root.add_child(game)
	await process_frame
	await physics_frame
	game.set_physics_process(false)
	game.start_shift()
	var board := (game.world as ShipyardWorld).get_heavy_breach_activity_board() as HeavyBreachActivityBoard
	var director := game.get_node(^"EncounterScenarios") as EncounterScenarioDirector
	var ship := game.get_node(^"ArrowReconShip") as HeroShip
	var board_position := board.global_position + Vector3.BACK * 2.0
	game.player.teleport_to(Transform3D(Basis.looking_at(Vector3.FORWARD, Vector3.UP), board_position))
	await physics_frame
	await process_frame
	game.station_interaction_candidate = board
	game.call(&"_on_interact_requested")
	var armed := board.get_snapshot()
	var detail := game.hud.get("_runtime_status_detail") as Label
	_check(armed.sortie_armed and armed.armed_actor_instance_id == game.player.get_instance_id()
		and director.get_state() == EncounterScenarioDirector.STATE_IDLE,
		"physical board Interact arms one admitted avatar generation without starting combat")
	_check_board_sortie_briefing(detail.text, &"shipyard_heavy_breach")
	game.call(&"_on_interact_requested")
	_check(not board.is_sortie_armed()
		and board.get_offered_scenario() == EncounterScenarioDirector.SCENARIO_HEAVY_BREACH,
		"a second board Interact cancels the arm without rotating the posted contract")
	game.call(&"_on_interact_requested")
	ship.set_piloted(true)
	game.active_ship = ship
	game.set("_piloting", true)
	game.phase = GameFlow.Phase.FREE_FLIGHT
	game.set("_sortie_departed_berth", false)
	_check(not game.call(&"_try_launch_armed_heavy_breach") and board.is_sortie_armed(),
		"departure not yet admitted retains the same armed sortie for launch retry")
	game.set("_sortie_departed_berth", true)
	_check(game.call(&"_try_launch_armed_heavy_breach") and director.is_running(),
		"admitted combat craft departure converts the arm into the real encounter")
	director.abort(EncounterScenarioDirector.OUTCOME_WITHDRAWN)
	_check(board.get_offered_scenario() == EncounterScenarioDirector.SCENARIO_TORPEDO_RUN,
		"a concluded heavy breach posts Torpedo Run rather than promising the same retry")
	ship.set_piloted(false)
	game.set("_piloting", false)
	game.phase = GameFlow.Phase.APPROACH_SHIP
	game.hud.clear_activity_tutorial(&"next_board_contract")
	game.call(&"_on_interact_requested")
	_check(board.is_sortie_armed() and board.get_offered_scenario() == EncounterScenarioDirector.SCENARIO_TORPEDO_RUN
		and director.is_concluded(), "on-foot board Interact arms the current Torpedo Run offer")
	_check_board_sortie_briefing(detail.text, &"shipyard_torpedo_run")
	paused = false
	game.queue_free()
	await process_frame
	await process_frame


func _check_surface_survey_briefing(prompt: String, activity_id: StringName) -> void:
	var aurora := activity_id == &"aurora_coastal_observation"
	_check(prompt.contains("On foot") and prompt.contains("start this optional survey")
		and prompt.contains("Board your ship whenever ready") and prompt.contains("OBJECTIVE")
		and prompt.contains("DISTANCE") and prompt.contains("WHILE ACTIVE // INTERACT TO ABANDON"),
		"%s help explains on-foot admission, next target and optional departure or abandonment" % activity_id)
	_check(prompt.contains("REWARD SAVE PENDING") and prompt.contains("RETAINED")
		and prompt.contains("INTERACT AT THE STANDING STONES TO RETRY" if aurora
			else "INTERACT AT THE RIDGE GAUGE TO RETRY"),
		"%s help keeps completed readings and names the actual reward retry landmark" % activity_id)
	if not aurora:
		_check(prompt.contains("HEATER LOW // WARM UP") and prompt.contains("THEN CONTINUE;")
			and prompt.contains("HEATER EMPTY // YOU ARE SAFE; RESTART A FRESH SURVEY")
			and prompt.contains("refill") and not prompt.contains("THEN RESTART AT THE BEACON"),
			"low Rime heat preserves survey progress; only exhaustion calls for a fresh survey")


func _check_surface_survey_presentation_variants() -> void:
	for activity_id: StringName in [&"aurora_coastal_observation", &"rime_ice_core_survey"]:
		var presenter := Presenter.new()
		var remapped := presenter.present_snapshot({
			"activity_id": activity_id, "generation": 1, "input_family": &"keyboard",
			"glyphs": {&"interact": "CUSTOM INTERACT"},
		})
		_check(remapped.accepted and remapped.prompt.contains("CUSTOM INTERACT")
			and not remapped.prompt.contains("{"), "%s survey help preserves remapped interaction" % activity_id)
		_check_surface_survey_briefing(remapped.prompt, activity_id)
		var accessible := presenter.present_snapshot({
			"activity_id": activity_id, "generation": 2, "accessible": true,
		})
		_check(accessible.accepted and accessible.prompt == accessible.accessible_prompt
			and accessible.prompt.contains("interact control") and not accessible.prompt.contains("{"),
			"%s accessible survey admission is glyph-free" % activity_id)
		_check_surface_survey_briefing(accessible.prompt, activity_id)
