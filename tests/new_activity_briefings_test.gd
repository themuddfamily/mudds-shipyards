extends SceneTree

## First-start briefings for the activities added after the Cinder Reach set:
## the Heavy Breach and Torpedo Run deck-board sorties, the Aurora coastal
## survey, the Rime ice-core survey (with its suit heater), the Ember relay
## expedition and the Ember caldera errands. Each briefing is published through
## the production GameFlow seams, shows once, and stays seen across a reload of
## the shared user-data document.

const Presenter := preload("res://scripts/ui/activity_tutorial_presenter.gd")
const GameFlowType := preload("res://scripts/game/game_flow.gd")
const SettingsType := preload("res://scripts/settings/runtime_settings.gd")
const StoreType := preload("res://scripts/persistence/user_data_store.gd")
const FilesystemType := preload("res://scripts/persistence/user_data_filesystem.gd")
const HUD_SCENE := preload("res://scenes/ui/hud.tscn")

const STORE_PATH := "memory://new-activity-briefings-user-data.json"
const NEW_BRIEFINGS: Array[StringName] = [
	&"shipyard_heavy_breach",
	&"shipyard_torpedo_run",
	&"aurora_coastal_observation",
	&"rime_ice_core_survey",
	&"ember_beacon_survey",
	&"ember_caldera_errands",
]

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


func _init() -> void:
	call_deferred(&"_run")


func _run() -> void:
	# Authored copy: every new briefing is known, complete and glyph-tokenised
	# only with actions the HUD resolves.
	for briefing_id in NEW_BRIEFINGS:
		var copy := Presenter.ACTIVITY_COPY.get(briefing_id, {}) as Dictionary
		var complete := Presenter.is_known_activity(briefing_id)
		for key: String in ["title", "label", "controller", "keyboard", "accessible", "next_action", "recovery"]:
			complete = complete and not str(copy.get(key, "")).strip_edges().is_empty()
		_check(complete, "%s has a complete authored briefing" % String(briefing_id))
		var accessible := Presenter.new().present_snapshot({
			"activity_id": briefing_id, "generation": 1, "revision": 1, "accessible": true,
		})
		_check(
			bool(accessible.get("accepted", false))
			and not str(accessible.get("prompt", "")).contains("{"),
			"%s has a glyph-free accessible variant" % String(briefing_id),
		)
	var rime := Presenter.ACTIVITY_COPY[&"rime_ice_core_survey"] as Dictionary
	_check(
		str(rime.controller).contains("SUIT HEATER")
		and str(rime.accessible).contains("suit heater")
		and str(rime.accessible).contains("heated hut")
		and str(rime.recovery).contains("HEATER"),
		"the Rime briefing explains the suit heater and where to warm up",
	)
	var torpedo := Presenter.ACTIVITY_COPY[&"shipyard_torpedo_run"] as Dictionary
	_check(
		str(torpedo.controller).contains("break hard across its nose")
		and str(torpedo.controller).contains("shoot it down"),
		"the Torpedo Run briefing names both counters",
	)
	_check(
		Presenter.briefing_id_for(&"ember_lava_tube_sounding") == &"ember_caldera_errands"
		and Presenter.briefing_id_for(&"ember_lander_wreck_survey") == &"ember_caldera_errands"
		and Presenter.briefing_id_for(&"not_an_activity").is_empty(),
		"both caldera errands share one briefing and unknown ids stay unbriefed",
	)

	# Production GameFlow seams publish each briefing once.
	var filesystem := MemoryFilesystem.new()
	var store := StoreType.new(STORE_PATH, filesystem)
	store.load()
	var hud := HUD_SCENE.instantiate()
	root.add_child(hud)
	await process_frame
	var title := hud.get("_runtime_status_title") as Label
	var detail := hud.get("_runtime_status_detail") as Label
	var flow := GameFlowType.new()
	flow.hud = hud
	flow.runtime_settings = SettingsType.new("user://new_activity_briefings_test.cfg")
	flow._runtime_settings_user_data_store = store
	flow._ensure_tutorial_prompt_seen_store()
	_check(
		flow.activity_tutorial_prompt_id(&"ember_lander_wreck_survey") == &"ember_caldera_errands",
		"GameFlow resolves an errand id onto the shared errand briefing",
	)

	# Deck board: Heavy Breach, then Torpedo Run, from the arm seam's helper.
	for case: Array in [
		[false, &"shipyard_heavy_breach"],
		[true, &"shipyard_torpedo_run"],
	]:
		var briefing_id := case[1] as StringName
		hud.clear_activity_tutorial(&"case")
		flow._activity_tutorial_active_id = &""
		_check(
			flow._publish_board_sortie_briefing(case[0] as bool)
			and title.text == str((Presenter.ACTIVITY_COPY[briefing_id] as Dictionary).title)
			and _briefing_card_visible(hud)
			and flow.has_seen_activity_tutorial(briefing_id),
			"arming a %s sortie the first time briefs it" % String(briefing_id),
		)
		hud.clear_activity_tutorial(&"repeat")
		flow._activity_tutorial_active_id = &""
		_check(
			not flow._publish_board_sortie_briefing(case[0] as bool)
			and not _briefing_card_visible(hud),
			"a later %s arm is silent" % String(briefing_id),
		)

	# Ember errands: a rejected start never consumes the briefing, an accepted
	# one shows it, and the other errand is then silent.
	hud.clear_activity_tutorial(&"errand")
	flow._activity_tutorial_active_id = &""
	_check(
		not flow._publish_accepted_start_briefing(
			{"accepted": false}, &"ember_lava_tube_sounding"
		)
		and not flow.has_seen_activity_tutorial(&"ember_caldera_errands"),
		"a rejected errand start does not consume the errand briefing",
	)
	_check(
		flow._publish_accepted_start_briefing({"accepted": true}, &"ember_lava_tube_sounding")
		and title.text == "Run a caldera errand"
		and flow.has_seen_activity_tutorial(&"ember_caldera_errands"),
		"the first accepted caldera errand briefs the pilot",
	)
	hud.clear_activity_tutorial(&"errand_repeat")
	flow._activity_tutorial_active_id = &""
	_check(
		not flow._publish_accepted_start_briefing({"accepted": true}, &"ember_lander_wreck_survey")
		and not _briefing_card_visible(hud),
		"the second caldera errand does not repeat the shared briefing",
	)

	# Ember expedition start already publishes the relay-survey briefing.
	hud.clear_activity_tutorial(&"ember")
	flow._activity_tutorial_active_id = &""
	_check(
		flow.publish_activity_tutorial_briefing(GameFlowType.EMBER_RELAY_SURVEY_ACTIVITY_ID)
		and title.text == "Fly the Ember expedition",
		"the Ember expedition start now shows its relay-survey briefing",
	)

	# Aurora and Rime: observed from each visit reaching its surface state.
	for case: Array in [
		[flow._aurora_expedition, &"aurora_coastal_observation"],
		[flow._rime_expedition, &"rime_ice_core_survey"],
	]:
		var visit := case[0] as RefCounted
		var briefing_id := case[1] as StringName
		hud.clear_activity_tutorial(&"survey")
		flow._activity_tutorial_active_id = &""
		visit.set(&"state", &"landing")
		flow._observe_planetary_survey_briefings()
		_check(
			not flow.has_seen_activity_tutorial(briefing_id),
			"%s is not briefed before the pilot reaches the surface" % String(briefing_id),
		)
		visit.set(&"state", &"surface")
		flow._observe_planetary_survey_briefings()
		_check(
			title.text == str((Presenter.ACTIVITY_COPY[briefing_id] as Dictionary).title)
			and _briefing_card_visible(hud)
			and flow.has_seen_activity_tutorial(briefing_id),
			"reaching the surface briefs %s once" % String(briefing_id),
		)
		if briefing_id == &"rime_ice_core_survey":
			_check(
				detail.text.contains("SUIT HEATER") or detail.text.contains("suit heater"),
				"the rendered Rime card tells the pilot about the suit heater",
			)
		hud.clear_activity_tutorial(&"survey_repeat")
		flow._activity_tutorial_active_id = &""
		flow._observe_planetary_survey_briefings()
		visit.set(&"state", &"idle")
		flow._observe_planetary_survey_briefings()
		visit.set(&"state", &"surface")
		flow._observe_planetary_survey_briefings()
		_check(
			not _briefing_card_visible(hud),
			"staying on or returning to the %s surface never repeats the briefing" % String(briefing_id),
		)
		visit.set(&"state", &"idle")
		flow._observe_planetary_survey_briefings()

	# Re-entry: a reloaded document remembers every new briefing.
	var reloaded_store := StoreType.new(STORE_PATH, filesystem)
	_check(bool(reloaded_store.load().accepted), "the user-data document reloads after the commits")
	var reloaded_flow := GameFlowType.new()
	reloaded_flow.hud = hud
	reloaded_flow.runtime_settings = flow.runtime_settings
	reloaded_flow._runtime_settings_user_data_store = reloaded_store
	reloaded_flow._ensure_tutorial_prompt_seen_store()
	var all_seen := true
	for briefing_id in NEW_BRIEFINGS:
		all_seen = all_seen and reloaded_flow.has_seen_activity_tutorial(briefing_id) \
			and not reloaded_flow.publish_activity_tutorial_briefing(briefing_id)
	_check(all_seen, "every new briefing stays seen across a whole-session re-entry")

	reloaded_flow.free()
	flow.free()
	hud.clear_activity_tutorial(&"done")
	root.remove_child(hud)
	hud.queue_free()
	await process_frame
	if _failures.is_empty():
		print("NEW_ACTIVITY_BRIEFINGS_TEST_OK (%d assertions)" % _assertions)
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)


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
