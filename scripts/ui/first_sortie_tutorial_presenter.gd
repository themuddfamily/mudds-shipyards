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
	&"board": {"title": "Board", "controller": "Press {interact} to board the craft.", "keyboard": "Press {interact} to board the craft.", "accessible": "Use the interact control to board the craft."},
	&"take_seat": {"title": "Take the pilot seat", "controller": "Press {interact} to take the pilot seat.", "keyboard": "Press {interact} to take the pilot seat.", "accessible": "Use the interact control to take the pilot seat."},
	&"launch": {"title": "Launch", "controller": "Apply thrust to launch when the bay is clear.", "keyboard": "Apply thrust to launch when the bay is clear.", "accessible": "Apply thrust to launch when the bay is clear."},
	&"fire": {"title": "Fire safely", "controller": "Press {fire} to fire only when the range target is clear.", "keyboard": "Press {fire} to fire only when the range target is clear.", "accessible": "Use the fire control only when the range target is clear."},
	&"return_land": {"title": "Return and land", "controller": "Use landing assist, then follow the return vector.", "keyboard": "Use landing assist, then follow the return vector.", "accessible": "Use landing assist and follow the return vector."},
	&"exit": {"title": "Exit the craft", "controller": "Press {interact} after coming to a complete stop.", "keyboard": "Press {interact} after coming to a complete stop.", "accessible": "Come to a complete stop, then use the interact control to exit."},
}
const STEP_STATUS := {
	&"walk_interact": {"next_action": "REACH CRAFT // INTERACT", "recovery": "PROMPT LOST // RETURN TO THE CRAFT"},
	&"board": {"next_action": "BOARD CRAFT // INTERACT", "recovery": "OUT OF RANGE // STEP BACK TO THE BOARDING POINT"},
	&"take_seat": {"next_action": "TAKE PILOT SEAT // INTERACT", "recovery": "SEAT PROMPT LOST // FACE THE PILOT SEAT"},
	&"launch": {"next_action": "CLEAR BAY // APPLY THRUST", "recovery": "LAUNCH HELD // CENTER THE CRAFT AND REAPPLY THRUST"},
	&"fire": {"next_action": "ALIGN RANGE TARGET // FIRE", "recovery": "TARGET LOST // REACQUIRE THE MARKED RANGE TARGET"},
	&"return_land": {"next_action": "LANDING ASSIST // FOLLOW RETURN VECTOR", "recovery": "VECTOR LOST // RE-ENABLE LANDING ASSIST"},
	&"exit": {"next_action": "FULL STOP // EXIT CRAFT", "recovery": "EXIT BLOCKED // STOP COMPLETELY AND INTERACT AGAIN"},
}

var _snapshot: Dictionary = {}
var _source_generation := -1
var _source_revision := -1
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
	var revision := STEP_ORDER.find(step_id)
	if _attached and generation < _source_generation:
		return _reject(&"stale_generation")
	if _attached and generation == _source_generation and revision < _source_revision:
		return _reject(&"stale_revision")
	var copy := STEP_COPY[step_id] as Dictionary
	var status := STEP_STATUS[step_id] as Dictionary
	var family := StringName(str(source.get("input_family", &"controller")))
	var accessible := bool(source.get("accessible", false))
	var prompt := str(copy.accessible if accessible else (copy.keyboard if family == &"keyboard" else copy.controller))
	var glyphs := source.get("glyphs", {}) as Dictionary
	for raw_key in glyphs:
		prompt = prompt.replace("{%s}" % str(raw_key), str(glyphs[raw_key]))
	var progress_label := "STEP %d OF %d" % [revision + 1, STEP_ORDER.size()]
	var next_action := str(status.next_action)
	var recovery := str(status.recovery)
	var status_text := "\nPROGRESS // %s\nNEXT ACTION // %s\nRECOVERY // %s" % [
		progress_label, next_action, recovery,
	]
	prompt += status_text
	var accessible_prompt := str(copy.accessible) + status_text
	_source_generation = generation
	_source_revision = revision
	_attached = true
	_snapshot = {
		"component_id": COMPONENT_ID,
		"accepted": true,
		"attached": true,
		"step_id": step_id,
		"step_index": revision,
		"generation": generation,
		"revision": revision,
		"title": copy.title,
		"prompt": prompt,
		"accessible_prompt": accessible_prompt,
		"progress_label": progress_label,
		"next_action": next_action,
		"recovery": recovery,
		"input_family": family,
		"actions": [
			{"id": &"next", "label": "Next tutorial step", "focusable": true},
			{"id": &"repeat", "label": "Repeat instruction", "focusable": true},
			{"id": &"dismiss", "label": "Dismiss tutorial", "focusable": true},
		],
		"completion_intent": {"kind": &"first_sortie_tutorial", "step_id": step_id, "generation": generation, "persist": true},
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
	_attached = false


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
