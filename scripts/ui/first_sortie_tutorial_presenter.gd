class_name FirstSortieTutorialPresenter
extends RefCounted

## Snapshot-only first-sortie onboarding. Progress persistence and gameplay
## checkpoints remain caller-owned; this object only formats prompts/intents.

const COMPONENT_ID: StringName = &"first-sortie-tutorial-presenter"
const STEP_ORDER := [
	&"walk_interact", &"board", &"take_seat", &"launch", &"fire", &"return_land", &"exit"
]
const STEP_COPY := {
	&"walk_interact": {"title": "Reach the craft", "controller": "Walk to the craft, then press {interact} to interact.", "keyboard": "Walk to the craft, then press {interact} to interact.", "accessible": "Walk to the craft and use the interact control."},
	&"board": {"title": "Board the Torrent", "controller": "Press {interact} to board the Torrent interceptor.", "keyboard": "Press {interact} to board the Torrent interceptor.", "accessible": "Use the interact control to board the Torrent interceptor."},
	&"take_seat": {"title": "Take the pilot seat", "controller": "Press {interact} to take the pilot seat.", "keyboard": "Press {interact} to take the pilot seat.", "accessible": "Use the interact control to take the pilot seat."},
	&"launch": {"title": "Throttle and steer", "controller": "Hold {move_forward} for throttle. Steer with {move_left}/{move_right} and {pitch_up}/{pitch_down}.", "keyboard": "Hold {move_forward} for throttle. Steer with {move_left}/{move_right} and {pitch_up}/{pitch_down}.", "accessible": "Apply forward throttle, then use the yaw and pitch controls to steer clear of the bay."},
	&"fire": {"title": "Fire at range targets", "controller": "Line up a marked RANGE TARGET, then press {fire} to fire.", "keyboard": "Line up a marked RANGE TARGET, then press {fire} to fire.", "accessible": "Line up a marked range target, then use the fire control."},
	&"return_land": {"title": "Return and land", "controller": "Press {landing_assist}, follow the return vector, then hold {brake} on final approach.", "keyboard": "Press {landing_assist}, follow the return vector, then hold {brake} on final approach.", "accessible": "Enable landing assist, follow the return vector, then brake on final approach."},
	&"exit": {"title": "Exit the craft", "controller": "Press {interact} after coming to a complete stop.", "keyboard": "Press {interact} after coming to a complete stop.", "accessible": "Come to a complete stop, then use the interact control to exit."},
}
const STEP_STATUS := {
	&"walk_interact": {"next_action": "REACH CRAFT // INTERACT", "recovery": "PROMPT LOST // RETURN TO THE CRAFT"},
	&"board": {"next_action": "BOARD TORRENT // INTERACT", "recovery": "OUT OF RANGE // STEP BACK TO THE BOARDING POINT"},
	&"take_seat": {"next_action": "TAKE PILOT SEAT // INTERACT", "recovery": "SEAT PROMPT LOST // FACE THE PILOT SEAT"},
	&"launch": {"next_action": "THROTTLE UP // STEER CLEAR OF BAY", "recovery": "LAUNCH HELD // CENTER THE CRAFT AND REAPPLY THROTTLE"},
	&"fire": {"next_action": "ALIGN RANGE TARGET // FIRE", "recovery": "TARGET LOST // REACQUIRE THE MARKED RANGE TARGET"},
	&"return_land": {"next_action": "LANDING ASSIST // FOLLOW RETURN VECTOR", "recovery": "VECTOR LOST // RE-ENABLE LANDING ASSIST"},
	&"exit": {"next_action": "FULL STOP // EXIT CRAFT", "recovery": "EXIT BLOCKED // STOP COMPLETELY AND INTERACT AGAIN"},
}

var _snapshot: Dictionary = {}
var _source_generation := -1
var _source_revision := -1
var _source_step: StringName = &""
var _source_craft_display_name := ""
var _attached := false


func present_snapshot(source: Dictionary) -> Dictionary:
	if not bool(source.get("show_tutorials", true)):
		_clear_state()
		return _reject(&"tutorials_disabled")
	for lifecycle_key: StringName in [&"actor_attached", &"session_active"]:
		if source.has(lifecycle_key) and not source.get(lifecycle_key) is bool:
			return _reject(&"invalid_lifecycle")
	if source.has("actor_attached") and not bool(source.actor_attached):
		_clear_state()
		return _reject(&"actor_unavailable")
	if source.has("session_active") and not bool(source.session_active):
		_clear_state()
		return _reject(&"session_unavailable")
	var generation_value: Variant = source.get("generation", null)
	if not generation_value is int or int(generation_value) < 0:
		return _reject(&"invalid_generation")
	var generation := int(generation_value)
	var step_id := StringName(str(source.get("step_id", &"walk_interact")))
	if not STEP_ORDER.has(step_id):
		return _reject(&"unknown_step")
	var step_index := STEP_ORDER.find(step_id)
	var revision_value: Variant = source.get("revision", step_index)
	if not revision_value is int or int(revision_value) < 0:
		return _reject(&"invalid_revision")
	var revision := int(revision_value)
	var craft_context := _resolve_board_craft_context(source, step_id)
	if not bool(craft_context.get("accepted", false)):
		return _reject(craft_context.get("reason", &"invalid_craft_context") as StringName)
	var craft_display_name := str(craft_context.get("craft_display_name", ""))
	if _attached and generation < _source_generation:
		return _reject(&"stale_generation")
	if _attached and generation == _source_generation and revision < _source_revision:
		return _reject(&"stale_revision")
	if _attached and generation == _source_generation \
			and revision == _source_revision and (
				step_id != _source_step
				or craft_display_name != _source_craft_display_name
			):
		return _reject(&"conflicting_revision")
	var copy := (STEP_COPY[step_id] as Dictionary).duplicate(true)
	var status := (STEP_STATUS[step_id] as Dictionary).duplicate(true)
	if step_id == &"board" and not craft_display_name.is_empty():
		copy["title"] = "Board %s" % craft_display_name
		copy["controller"] = "Press {interact} to board %s." % craft_display_name
		copy["keyboard"] = "Press {interact} to board %s." % craft_display_name
		copy["accessible"] = (
			"Use the interact control to board %s." % craft_display_name
		)
		status["next_action"] = "BOARD SELECTED CRAFT // INTERACT"
	var family := StringName(str(source.get("input_family", &"controller")))
	var accessible := bool(source.get("accessible", false))
	var prompt := str(copy.accessible if accessible else (copy.keyboard if family == &"keyboard" else copy.controller))
	var glyphs := source.get("glyphs", {}) as Dictionary
	for raw_key in glyphs:
		prompt = prompt.replace("{%s}" % str(raw_key), str(glyphs[raw_key]))
	var progress_label := "STEP %d OF %d" % [step_index + 1, STEP_ORDER.size()]
	var next_action := str(status.next_action)
	var recovery := str(status.recovery)
	var status_text := "\nPROGRESS // %s\nNEXT ACTION // %s\nRECOVERY // %s" % [
		progress_label, next_action, recovery,
	]
	prompt += status_text
	var accessible_prompt := str(copy.accessible) + status_text
	_source_generation = generation
	_source_revision = revision
	_source_step = step_id
	_source_craft_display_name = craft_display_name
	_attached = true
	_snapshot = {
		"component_id": COMPONENT_ID,
		"accepted": true,
		"attached": true,
		"step_id": step_id,
		"step_index": step_index,
		"generation": generation,
		"revision": revision,
		"title": copy.title,
		"prompt": prompt,
		"accessible_prompt": accessible_prompt,
		"craft_display_name": craft_display_name,
		"contextual_craft": not craft_display_name.is_empty(),
		"progress_label": progress_label,
		"next_action": next_action,
		"recovery": recovery,
		"input_family": family,
		"actions": [
			{"id": &"next", "label": "Next tutorial step", "focusable": true},
			{"id": &"repeat", "label": "Repeat instruction", "focusable": true},
			{"id": &"dismiss", "label": "Dismiss tutorial", "focusable": true},
		],
		"completion_intent": {"kind": &"first_sortie_tutorial", "step_id": step_id, "generation": generation, "revision": revision, "persist": true},
		"color_independent": true,
		"presentation_only": true,
		"tutorial_progress_authority": false,
		"gameplay_authority": false,
		"input_authority": false,
		"timer_authority": false,
		"process_authority": false,
	}.duplicate(true)
	return _snapshot.duplicate(true)


func get_snapshot() -> Dictionary:
	var result := _snapshot.duplicate(true)
	if not result.is_empty():
		result["attached"] = _attached
	return result


## Caller-owned actor/session lifecycle invokes this when the retained tutorial
## loses its source. Clearing the fence also makes this object safe to reuse.
func detach(reason: StringName = &"detached") -> Dictionary:
	_clear_state()
	return {
		"accepted": true,
		"attached": false,
		"reason": reason,
		"component_id": COMPONENT_ID,
		"presentation_only": true,
		"tutorial_progress_authority": false,
	}.duplicate(true)


func request(action: StringName) -> Dictionary:
	if not _attached or _snapshot.is_empty() or not [&"next", &"repeat", &"dismiss"].has(action):
		return {"accepted": false, "reason": &"action_unavailable", "presentation_only": true}
	return {
		"accepted": true,
		"action": action,
		"generation": _source_generation,
		"revision": _source_revision,
		"completion_intent": _snapshot.completion_intent.duplicate(true),
		"presentation_only": true,
		"tutorial_progress_authority": false,
		"gameplay_authority": false,
		"input_authority": false,
		"timer_authority": false,
		"process_authority": false,
	}


func _clear_state() -> void:
	_snapshot.clear()
	_source_generation = -1
	_source_revision = -1
	_source_step = &""
	_source_craft_display_name = ""
	_attached = false


func _resolve_board_craft_context(
		source: Dictionary, step_id: StringName
	) -> Dictionary:
	if step_id != &"board" or not source.has("craft_display_name"):
		return {"accepted": true, "craft_display_name": ""}
	var value: Variant = source.get("craft_display_name")
	if not value is String:
		return {"accepted": false, "reason": &"invalid_craft_context"}
	var display_name := str(value).strip_edges()
	if display_name.is_empty() or display_name.length() > 80 \
			or display_name.contains("\n") or display_name.contains("\r") \
			or display_name.contains("\t"):
		return {"accepted": false, "reason": &"invalid_craft_context"}
	# Authorship/evidence qualifiers remain available on the ship identity panel,
	# but the immediate action title needs the craft family and role at a glance.
	if display_name.contains(" — "):
		display_name = display_name.get_slice(" — ", 0).strip_edges()
	if display_name.to_lower().ends_with(" candidate"):
		display_name = display_name.left(display_name.length() - 10).strip_edges()
	if display_name.is_empty():
		return {"accepted": false, "reason": &"invalid_craft_context"}
	return {"accepted": true, "craft_display_name": display_name}


func _reject(reason: StringName) -> Dictionary:
	return {
		"accepted": false,
		"reason": reason,
		"component_id": COMPONENT_ID,
		"presentation_only": true,
		"tutorial_progress_authority": false,
		"gameplay_authority": false,
		"input_authority": false,
		"timer_authority": false,
		"process_authority": false,
	}
