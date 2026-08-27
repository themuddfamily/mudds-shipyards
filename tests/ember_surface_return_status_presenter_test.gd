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
	if _failures.is_empty():
		print("EMBER_SURFACE_RETURN_STATUS_PRESENTER_TEST_OK (%d assertions)" % _assertions)
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)


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
