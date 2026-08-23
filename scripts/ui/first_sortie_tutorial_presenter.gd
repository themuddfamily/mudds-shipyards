class_name FirstSortieTutorialPresenter
extends RefCounted

## Snapshot-only first-sortie onboarding. Progress persistence and gameplay
## checkpoints remain caller-owned; this object only formats prompts/intents.

const COMPONENT_ID: StringName = &"first-sortie-tutorial-presenter"
const STEP_ORDER := [
	&"walk_interact", &"board", &"take_seat", &"launch", &"fire", &"return_land", &"exit"
]
const STEP_COPY := {
	&"walk_interact": {"title": "Reach the craft", "controller": "Walk to the craft, then press {interact} to interact.", "keyboard": "Walk to the craft, then press [ E ] to interact.", "accessible": "Walk to the craft and use the interact control."},
	&"board": {"title": "Board", "controller": "Press {interact} to board the craft.", "keyboard": "Press [ E ] to board the craft.", "accessible": "Use the interact control to board the craft."},
	&"take_seat": {"title": "Take the pilot seat", "controller": "Press {interact} to take the pilot seat.", "keyboard": "Press [ E ] to take the pilot seat.", "accessible": "Use the interact control to take the pilot seat."},
	&"launch": {"title": "Launch", "controller": "Apply thrust to launch when the bay is clear.", "keyboard": "Apply thrust to launch when the bay is clear.", "accessible": "Apply thrust to launch when the bay is clear."},
	&"fire": {"title": "Fire safely", "controller": "Press {fire} to fire only when the range target is clear.", "keyboard": "Press [ LMB ] to fire only when the range target is clear.", "accessible": "Use the fire control only when the range target is clear."},
	&"return_land": {"title": "Return and land", "controller": "Use landing assist, then follow the return vector.", "keyboard": "Use landing assist, then follow the return vector.", "accessible": "Use landing assist and follow the return vector."},
	&"exit": {"title": "Exit the craft", "controller": "Press {interact} after coming to a complete stop.", "keyboard": "Press [ E ] after coming to a complete stop.", "accessible": "Come to a complete stop, then use the interact control to exit."},
}

var _snapshot: Dictionary = {}


func present_snapshot(source: Dictionary) -> Dictionary:
	var step_id := StringName(str(source.get("step_id", &"walk_interact")))
	if not STEP_ORDER.has(step_id):
		return _reject(&"unknown_step")
	var copy := STEP_COPY[step_id] as Dictionary
	var family := StringName(str(source.get("input_family", &"controller")))
	var accessible := bool(source.get("accessible", false))
	var prompt := str(copy.accessible if accessible else (copy.keyboard if family == &"keyboard" else copy.controller))
	var glyphs := source.get("glyphs", {}) as Dictionary
	for raw_key in glyphs:
		prompt = prompt.replace("{%s}" % str(raw_key), str(glyphs[raw_key]))
	_snapshot = {
		"component_id": COMPONENT_ID,
		"step_id": step_id,
		"step_index": STEP_ORDER.find(step_id),
		"title": copy.title,
		"prompt": prompt,
		"accessible_prompt": copy.accessible,
		"input_family": family,
		"actions": [
			{"id": &"next", "label": "Next tutorial step", "focusable": true},
			{"id": &"repeat", "label": "Repeat instruction", "focusable": true},
			{"id": &"dismiss", "label": "Dismiss tutorial", "focusable": true},
		],
		"completion_intent": {"kind": &"first_sortie_tutorial", "step_id": step_id, "persist": true},
		"presentation_only": true,
	}.duplicate(true)
	return _snapshot.duplicate(true)


func get_snapshot() -> Dictionary:
	return _snapshot.duplicate(true)


func request(action: StringName) -> Dictionary:
	if _snapshot.is_empty() or not [&"next", &"repeat", &"dismiss"].has(action):
		return {"accepted": false, "reason": &"action_unavailable", "presentation_only": true}
	return {"accepted": true, "action": action, "completion_intent": _snapshot.completion_intent.duplicate(true), "presentation_only": true}


func _reject(reason: StringName) -> Dictionary:
	return {"accepted": false, "reason": reason, "component_id": COMPONENT_ID, "presentation_only": true}
