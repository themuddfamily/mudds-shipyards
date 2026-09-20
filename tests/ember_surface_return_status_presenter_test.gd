extends SceneTree

const PresenterType := preload("res://scripts/ui/ember_surface_return_status_presenter.gd")

var _assertions := 0
var _failures: PackedStringArray = []


func _init() -> void:
	call_deferred(&"_run")


func _run() -> void:
	var presenter := PresenterType.new()
	var roster := [
		[&"orbit_approach", true, {}, "[O>>]", "ORBIT APPROACH // ALIGN ENTRY", "ORBIT: ALIGN ENTRY", &"travel"],
		[&"descent", true, {}, "[>>>]", "DESCENT // ENTERING", "DESCENT: ENTERING", &"travel"],
		[&"surface_approach", true, {}, "[>=>]", "ENTRY CORRIDOR // HOLD LINE", "ENTRY: CORRIDOR", &"travel"],
		[&"landing_approach", true, {}, "[v=v]", "LANDING COMMIT // HOLD STEADY", "LANDING: COMMIT", &"travel"],
		[&"landed", true, {}, "[===]", "LANDED // HOLD POSITION", "LANDED: HOLD", &"ready"],
		[&"on_foot", true, {}, "[***]", "ON FOOT // SURFACE TASK", "ON FOOT: SURFACE", &"travel"],
		[&"on_foot", true, {"accepted": true, "reason": &"return_manifest_ready"}, "[###]", "RETURN MANIFEST // READY", "MANIFEST: READY", &"ready"],
		[&"reboard", true, {}, "[<->]", "REBOARD // ENTER CRAFT", "REBOARD: ENTER", &"ready"],
		[&"reboarded", true, {}, "[=^=]", "REBOARDED // READY FOR TAKEOFF", "REBOARDED: TAKEOFF READY", &"ready"],
		[&"takeoff", true, {}, "[^>>]", "TAKEOFF // CLIMB", "TAKEOFF: CLIMB", &"travel"],
		[&"ascent", true, {}, "[^^^]", "ASCENT // CLIMB TO ORBIT", "ASCENT: TO ORBIT", &"travel"],
		[&"orbit_return", true, {}, "[|||]", "ORBIT RETURN // HANDOFF", "ORBIT RETURN: HANDOFF", &"travel"],
		[&"on_foot", false, {}, "[---]", "DETACHED // WAIT FOR CURRENT SESSION", "DETACHED: WAIT SESSION", &"detached"],
	]
	var visible_titles := {}
	var markers := {}
	var detached: Dictionary = {}
	for index in roster.size():
		var expected := roster[index] as Array
		var view := presenter.present(_snapshot(
			index + 1, expected[0], expected[1], expected[2]
		))
		_check_semantics(
			view, expected[3], expected[4], expected[5], expected[6],
			"%s production status retains its complete meaning in the visible title" % expected[5],
		)
		var title := str(view.get("visible_title", ""))
		var marker := str((view.get("status_semantics", {}) as Dictionary).get("marker", ""))
		_check(not visible_titles.has(title), "%s visible title is semantically unique" % expected[5])
		_check(not markers.has(marker), "%s ASCII marker shape is unique" % expected[5])
		visible_titles[title] = true
		markers[marker] = true
		if index == roster.size() - 1:
			detached = view
	_check(visible_titles.size() == 13 and markers.size() == 13,
		"the complete reachable-state roster has unique title text and marker shapes")
	var failed := PresenterType.new().present(_snapshot(1, &"failed", true))
	_check(
		not bool(failed.get("accepted", false))
			and failed.get("reason", &"") == &"unsupported_phase",
		"generic Host failure cannot be relabelled as an abort",
	)
	var negative_receipt := PresenterType.new().present(_snapshot(
		1, &"on_foot", true,
		{"accepted": false, "reason": &"return_manifest_denied"},
	))
	_check_semantics(
		negative_receipt, "[XXX]", "REJECTED // STATUS UNAVAILABLE",
		"REJECTED: UNAVAILABLE", &"rejected",
		"a synthetic negative receipt cannot invent a BLOCKED state",
	)
	var exact_rejected := PresenterType.new().present(_snapshot(1, &"rejected", true))
	_check_semantics(
		exact_rejected, "[XXX]", "REJECTED // STATUS UNAVAILABLE", "REJECTED: UNAVAILABLE",
		&"rejected", "only the exact rejected state visibly says REJECTED",
	)
	_check(
		not bool(detached.get("travel_authority", true))
			and not bool((detached.get("status_semantics", {}) as Dictionary).get("input_authority", true)),
		"status semantics remain presentation-only",
	)
	_test_optional_surface_objectives()
	_test_caldera_expedition_objective()
	if _failures.is_empty():
		print("EMBER_SURFACE_RETURN_STATUS_PRESENTER_TEST_OK (%d assertions)" % _assertions)
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)


func _test_optional_surface_objectives() -> void:
	var presenter := PresenterType.new()
	var snapshot := _snapshot(1, &"on_foot", true)
	snapshot.host["actor_state"] = {
		"player_position": Vector3(0.0, 120000.0, 0.0),
	}
	snapshot.binding = {
		"attached": true,
		"planetary_surface": {
			"relay_survey": {
				"activity_id": &"ember_beacon_survey",
				"optional_checkpoints": {
					&"ember_sample_rack_analysis_log": {
						"checkpoint_id": &"ember_sample_rack_analysis_log",
						"interaction_id": &"ember_sample_rack_analysis",
						"status": &"available", "completed": false,
					},
					&"ember_bunker_gantry_log": {
						"checkpoint_id": &"ember_bunker_gantry_log",
						"interaction_id": &"ember_bunker_gantry_survey",
						"status": &"available", "completed": false,
					},
				},
			},
			"sample_rack_interaction": {
				"interaction_id": &"ember_sample_rack_analysis",
				"position_body_local_m": Vector3(6.0, 120000.0, 0.0),
			},
			"survey_interaction": {
				"interaction_id": &"ember_bunker_gantry_survey",
				"position_body_local_m": Vector3(12.0, 120000.0, 5.0),
			},
		},
	}
	var available := presenter.present(snapshot)
	var optional := available.get("optional_objectives", {}) as Dictionary
	var nearest := optional.get("nearest_incomplete", {}) as Dictionary
	_check(
		bool(available.get("accepted", false))
			and bool(optional.get("available", false))
			and int(optional.get("completed_count", -1)) == 0
			and int(optional.get("objective_count", -1)) == 2
			and nearest.get("checkpoint_id", &"") \
				== &"ember_sample_rack_analysis_log"
			and is_equal_approx(float(nearest.get("distance_m", -1.0)), 6.0)
			and str(available.get("text", "")).contains(
				"OPTIONAL SURVEY  //  0 OF 2"
			)
			and str(available.get("text", "")).contains(
				"OPTIONAL  [ ]  SAMPLE RACK  //  6.0 m"
			)
			and not bool(optional.get("navigation_authority", true))
			and not bool(optional.get("activity_authority", true))
			and not bool(optional.get("reward_authority", true)),
		"on-foot status exposes both real optional interactions and the nearest unfinished distance without authority",
	)
	snapshot.generation = 2
	var checkpoints := snapshot.binding.planetary_surface.relay_survey.optional_checkpoints as Dictionary
	checkpoints[&"ember_sample_rack_analysis_log"] = {
		"checkpoint_id": &"ember_sample_rack_analysis_log",
		"interaction_id": &"ember_sample_rack_analysis",
		"status": &"completed", "completed": true,
	}
	var after_sample := presenter.present(snapshot)
	optional = after_sample.get("optional_objectives", {}) as Dictionary
	nearest = optional.get("nearest_incomplete", {}) as Dictionary
	_check(
		int(optional.get("completed_count", -1)) == 1
			and nearest.get("checkpoint_id", &"") == &"ember_bunker_gantry_log"
			and is_equal_approx(
				float(nearest.get("distance_m", -1.0)), 13.0
			)
			and str(after_sample.get("text", "")).contains(
				"OPTIONAL  [X]  SAMPLE RACK"
			),
		"completing the nearer rack immediately promotes the unfinished bunker log",
	)
	snapshot.generation = 3
	checkpoints[&"ember_bunker_gantry_log"] = {
		"checkpoint_id": &"ember_bunker_gantry_log",
		"interaction_id": &"ember_bunker_gantry_survey",
		"status": &"completed", "completed": true,
	}
	var completed := presenter.present(snapshot)
	optional = completed.get("optional_objectives", {}) as Dictionary
	_check(
		int(optional.get("completed_count", -1)) == 2
			and (optional.get("nearest_incomplete", {}) as Dictionary).is_empty()
			and str(completed.get("text", "")).contains(
				"OPTIONAL SURVEY  //  2 OF 2"
			),
		"both side-task completions remain visible without inventing another target",
	)
	snapshot.generation = 4
	snapshot.binding.planetary_surface.relay_survey.activity_id = &"foreign_activity"
	var foreign := presenter.present(snapshot)
	_check(
		not bool((foreign.get("optional_objectives", {}) as Dictionary).get(
			"available", true
		)),
		"foreign activity snapshots cannot be relabelled as Ember side tasks",
	)
	snapshot.generation = 5
	snapshot.binding.planetary_surface.relay_survey.activity_id = &"ember_beacon_survey"
	snapshot.binding.planetary_surface.sample_rack_interaction.interaction_id \
		= &"foreign_sample_rack"
	var mismatched := presenter.present(snapshot)
	var mismatched_optional := mismatched.get("optional_objectives", {}) as Dictionary
	_check(
		int(mismatched_optional.get("objective_count", -1)) == 1
			and (
				mismatched_optional.get("objectives", []) as Array
			)[0].checkpoint_id == &"ember_bunker_gantry_log",
		"a mismatched interaction identity cannot borrow an Ember checkpoint label",
	)


## The two authored caldera errands must be legible from the same standing
## surface card the relay survey already owns: offered while the pilot stands
## at a trailhead, tracked checkpoint by checkpoint once one is in hand, and
## gone the moment the pilot is no longer on foot.
func _test_caldera_expedition_objective() -> void:
	var presenter := PresenterType.new()
	var snapshot := _snapshot(1, &"on_foot", true)
	snapshot.host["actor_state"] = {
		"player_position": Vector3(16.0, 120000.0, -3.0),
	}
	snapshot.binding = {
		"attached": true,
		"planetary_surface": {
			"caldera_expeditions": {
				"world_id": &"ember_moon",
				"active_activity_id": &"",
				"activities": {
					&"ember_lava_tube_sounding": _expedition_record(
						&"ember_lava_tube_sounding", "Lava Tube Sounding",
						&"available", Vector3(18.0, 120000.0, -3.0), 0
					),
					&"ember_lander_wreck_survey": _expedition_record(
						&"ember_lander_wreck_survey", "Lander Wreck Survey",
						&"available", Vector3(40.0, 120000.0, -4.0), 0
					),
				},
			},
			"caldera_expedition_interactions": {
				"offers": {
					&"ember_lava_tube_sounding": {
						"active": true, "pressable": true,
						"prompt": "[ E ]  BEGIN LAVA TUBE SOUNDING",
					},
					&"ember_lander_wreck_survey": {
						"active": true, "pressable": false,
						"prompt": "[ E ]  BEGIN LANDER WRECK SURVEY",
					},
				},
			},
		},
	}
	var offered := presenter.present(snapshot)
	var expeditions := offered.get("caldera_expeditions", {}) as Dictionary
	var nearest := expeditions.get("nearest_offer", {}) as Dictionary
	_check(
		bool(offered.get("accepted", false))
			and bool(expeditions.get("available", false))
			and int(expeditions.get("logged_count", -1)) == 0
			and int(expeditions.get("expedition_count", -1)) == 2
			and (expeditions.get("active", {}) as Dictionary).is_empty()
			and StringName(nearest.get("activity_id", &"")) \
				== &"ember_lava_tube_sounding"
			and is_equal_approx(float(nearest.get("distance_m", -1.0)), 2.0)
			and bool(nearest.get("in_range", false))
			and str(offered.get("text", "")).contains(
				"EXPEDITIONS  //  0 OF 2 LOGGED"
			)
			and str(offered.get("text", "")).contains(
				"EXPEDITION  [ ]  LAVA TUBE SOUNDING  //  2.0 m"
			)
			and str(offered.get("text", "")).contains(
				"[ E ]  BEGIN LAVA TUBE SOUNDING"
			)
			and not bool(expeditions.get("activity_authority", true))
			and not bool(expeditions.get("reward_authority", true))
			and not bool(expeditions.get("navigation_authority", true)),
		"a pilot standing at a trailhead is offered the nearer errand by name, distance and press",
	)

	snapshot.generation = 2
	var records := snapshot.binding.planetary_surface.caldera_expeditions.activities as Dictionary
	snapshot.binding.planetary_surface.caldera_expeditions.active_activity_id \
		= &"ember_lava_tube_sounding"
	records[&"ember_lava_tube_sounding"] = _expedition_record(
		&"ember_lava_tube_sounding", "Lava Tube Sounding", &"active",
		Vector3(18.0, 120000.0, -3.0), 1
	)
	records[&"ember_lander_wreck_survey"] = _expedition_record(
		&"ember_lander_wreck_survey", "Lander Wreck Survey", &"busy",
		Vector3(40.0, 120000.0, -4.0), 0
	)
	var offers := snapshot.binding.planetary_surface.caldera_expedition_interactions.offers as Dictionary
	offers[&"ember_lava_tube_sounding"] = {
		"active": true, "pressable": true,
		"prompt": "[ E ]  ABANDON LAVA TUBE SOUNDING",
	}
	var in_hand_view := presenter.present(snapshot)
	expeditions = in_hand_view.get("caldera_expeditions", {}) as Dictionary
	var in_hand := expeditions.get("active", {}) as Dictionary
	_check(
		StringName(in_hand.get("activity_id", &"")) == &"ember_lava_tube_sounding"
			and int(in_hand.get("checkpoints_reached", -1)) == 1
			and int(in_hand.get("checkpoint_count", -1)) == 2
			and is_equal_approx(
				float(in_hand.get("distance_m", -1.0)),
				Vector3(-74.0, 120000.0, 16.0).distance_to(
					Vector3(16.0, 120000.0, -3.0)
				)
			)
			and (expeditions.get("nearest_offer", {}) as Dictionary).is_empty()
			and str(in_hand_view.get("text", "")).contains(
				"EXPEDITION  [>]  LAVA TUBE SOUNDING  //  CHECKPOINT 2 OF 2"
			)
			and str(in_hand_view.get("text", "")).contains(
				"[ E ]  ABANDON LAVA TUBE SOUNDING"
			),
		"the errand in hand replaces the offer with a live checkpoint counter and a way out",
	)

	snapshot.generation = 3
	snapshot.binding.planetary_surface.caldera_expeditions.active_activity_id = &""
	records[&"ember_lava_tube_sounding"] = _expedition_record(
		&"ember_lava_tube_sounding", "Lava Tube Sounding", &"completed",
		Vector3(18.0, 120000.0, -3.0), 2
	)
	records[&"ember_lander_wreck_survey"] = _expedition_record(
		&"ember_lander_wreck_survey", "Lander Wreck Survey", &"completed",
		Vector3(40.0, 120000.0, -4.0), 2
	)
	var logged := presenter.present(snapshot)
	expeditions = logged.get("caldera_expeditions", {}) as Dictionary
	_check(
		int(expeditions.get("logged_count", -1)) == 2
			and (expeditions.get("active", {}) as Dictionary).is_empty()
			and (expeditions.get("nearest_offer", {}) as Dictionary).is_empty()
			and str(logged.get("text", "")).contains(
				"EXPEDITIONS  //  2 OF 2 LOGGED"
			)
			and not str(logged.get("text", "")).contains("CHECKPOINT"),
		"both errands logged leaves a tally and no standing objective to chase",
	)

	snapshot.generation = 4
	records[&"ember_lava_tube_sounding"] = _expedition_record(
		&"ember_lava_tube_sounding", "Lava Tube Sounding", &"available",
		Vector3(18.0, 120000.0, -3.0), 0
	)
	for aboard_phase: StringName in [&"reboard", &"reboarded", &"ascent", &"landed"]:
		snapshot.generation += 1
		snapshot.host.phase_id = aboard_phase
		var aboard := presenter.present(snapshot)
		_check(
			not bool((aboard.get("caldera_expeditions", {}) as Dictionary).get(
				"available", true
			))
			and not str(aboard.get("text", "")).contains("EXPEDITION"),
			"no caldera errand is offered or tracked while the pilot is %s" % aboard_phase,
		)

	snapshot.generation += 1
	snapshot.host.phase_id = &"on_foot"
	snapshot.binding.planetary_surface.caldera_expeditions.world_id = &"foreign_world"
	var foreign := presenter.present(snapshot)
	_check(
		not bool((foreign.get("caldera_expeditions", {}) as Dictionary).get(
			"available", true
		)),
		"a foreign world's errand record cannot be relabelled as an Ember caldera errand",
	)

	snapshot.generation += 1
	snapshot.binding.planetary_surface.erase("caldera_expeditions")
	snapshot.binding.planetary_surface.erase("caldera_expedition_interactions")
	var off_world := presenter.present(snapshot)
	_check(
		not bool((off_world.get("caldera_expeditions", {}) as Dictionary).get(
			"available", true
		))
		and not str(off_world.get("text", "")).contains("EXPEDITION"),
		"a surface report without an Ember errand record shows no errand at all",
	)


func _expedition_record(
		activity_id: StringName, display_name: String, offer_state: StringName,
		trailhead: Vector3, reached: int
	) -> Dictionary:
	var checkpoints := PackedVector3Array([
		Vector3(-32.0, 120000.0, -38.0), Vector3(-74.0, 120000.0, 16.0),
	]) if activity_id == &"ember_lava_tube_sounding" else PackedVector3Array([
		Vector3(56.0, 120000.0, 18.0), Vector3(52.0, 120000.0, 46.0),
	])
	return {
		"activity_id": activity_id,
		"display_name": display_name,
		"offer_state": offer_state,
		"trailhead_body_local_m": trailhead,
		"checkpoints_body_local_m": checkpoints,
		"checkpoints_reached": reached,
		"checkpoint_count": checkpoints.size(),
		"next_checkpoint_body_local_m": (
			checkpoints[reached] if reached < checkpoints.size() else Vector3.INF
		),
		"reward_committed": offer_state == &"completed",
	}.duplicate(true)


func _snapshot(
		generation: int, phase: StringName, attached: bool, receipt: Dictionary = {}
	) -> Dictionary:
	return {
		"generation": generation,
		"host": {"phase_id": phase, "attached": attached},
		"binding": {"attached": attached},
		"last_result": receipt.duplicate(true),
	}.duplicate(true)


func _check_semantics(
		view: Dictionary, marker: String, label: String, short_label: String,
		kind: StringName, message: String
	) -> void:
	var semantics := view.get("status_semantics", {}) as Dictionary
	var visible_title := str(view.get("visible_title", ""))
	_check(
		bool(view.get("accepted", false))
			and semantics.get("marker", "") == marker
			and semantics.get("label", "") == label
			and semantics.get("short_label", "") == short_label
			and semantics.get("kind", &"") == kind
			and visible_title == "EMBER %s %s" % [marker, short_label]
			and visible_title.length() <= 40
			and _is_ascii(visible_title)
			and str(view.get("text", "")).begins_with(visible_title + "\n")
			and str(view.get("text", "")).contains("STATUS MARKER  //  %s  //  %s" % [marker, label])
			and bool(semantics.get("text_independent", false))
			and bool(semantics.get("shape_independent", false))
			and bool(semantics.get("color_independent", false)),
		message,
	)


func _is_ascii(value: String) -> bool:
	for index in value.length():
		if value.unicode_at(index) > 127:
			return false
	return true


func _check(condition: bool, message: String) -> void:
	_assertions += 1
	if not condition:
		_failures.append("FAIL: " + message)
