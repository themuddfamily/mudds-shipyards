class_name TutorialProgressionContract
extends RefCounted

## Detached onboarding progression for presentation/UI callers.
##
## Steps are caller-authored and checkpointed explicitly. This object never
## reads InputMap, emits gameplay actions, mutates a Player/ship, or owns save
## authority; a UI layer decides when a checkpoint has been observed.

const MAX_STEPS := 32
const INPUT_CONTROLLER: StringName = &"controller"
const INPUT_KEYBOARD: StringName = &"keyboard"

var _steps: Array[Dictionary] = []
var _completed: Array[StringName] = []
var _current_index := -1
var _generation := 0
var _started := false
var _preferred_input_family: StringName = INPUT_CONTROLLER


func configure(step_definitions: Array) -> Dictionary:
	if step_definitions.is_empty() or step_definitions.size() > MAX_STEPS:
		return _reject(&"invalid_step_count")
	var next: Array[Dictionary] = []
	var seen := {}
	for raw in step_definitions:
		if not raw is Dictionary:
			return _reject(&"invalid_step")
		var definition: Dictionary = raw
		var id := StringName(definition.get("id", &""))
		var checkpoint_id := StringName(definition.get("checkpoint_id", &""))
		if id == &"" or checkpoint_id == &"" or seen.has(id):
			return _reject(&"invalid_step_identity")
		var controller_prompt := str(definition.get("controller_prompt", "")).strip_edges()
		var keyboard_prompt := str(definition.get("keyboard_prompt", "")).strip_edges()
		var accessible_prompt := str(definition.get("accessible_prompt", "")).strip_edges()
		if controller_prompt.is_empty() or keyboard_prompt.is_empty() or accessible_prompt.is_empty():
			return _reject(&"missing_prompt_variant")
		seen[id] = true
		next.append({
			"id": id,
			"checkpoint_id": checkpoint_id,
			"controller_prompt": controller_prompt,
			"keyboard_prompt": keyboard_prompt,
			"accessible_prompt": accessible_prompt,
			"title": str(definition.get("title", "")).strip_edges(),
		})
	_steps = next
	_completed.clear()
	_current_index = -1
	_started = false
	_generation += 1
	return {"accepted": true, "reason": &"configured", "generation": _generation, "step_count": _steps.size()}


func start() -> Dictionary:
	if _steps.is_empty():
		return _reject(&"not_configured")
	_started = true
	_current_index = 0
	_completed.clear()
	return _state_result(&"started")


func set_preferred_input_family(input_family: StringName) -> Dictionary:
	if input_family != INPUT_CONTROLLER and input_family != INPUT_KEYBOARD:
		return _reject(&"invalid_input_family")
	_preferred_input_family = input_family
	return {"accepted": true, "reason": &"input_family_updated", "input_family": input_family, "generation": _generation}


func current_step() -> Dictionary:
	if not _started or _current_index < 0 or _current_index >= _steps.size():
		return {}
	return _steps[_current_index].duplicate(true)


func current_prompt(accessible: bool = false, input_family: StringName = &"") -> String:
	var step := current_step()
	if step.is_empty():
		return ""
	if accessible:
		return str(step["accessible_prompt"])
	var family := _preferred_input_family if input_family == &"" else input_family
	return str(step["controller_prompt"] if family == INPUT_CONTROLLER else step["keyboard_prompt"])


func checkpoint(step_id: StringName) -> Dictionary:
	if not _started:
		return _reject(&"not_started")
	if _current_index >= _steps.size():
		return _reject(&"already_complete")
	var expected: StringName = _steps[_current_index]["id"]
	if step_id != expected:
		return _reject(&"checkpoint_out_of_order")
	_completed.append(step_id)
	_current_index += 1
	return _state_result(&"checkpointed")


func get_snapshot() -> Dictionary:
	return {
		"generation": _generation,
		"started": _started,
		"current_index": _current_index,
		"completed": _completed.duplicate(),
		"preferred_input_family": _preferred_input_family,
		"step_ids": _step_ids(),
		"presentation_only": true,
	}


func restore(snapshot: Dictionary) -> Dictionary:
	if _steps.is_empty() or not snapshot.get("presentation_only", false):
		return _reject(&"invalid_snapshot")
	if int(snapshot.get("generation", -1)) != _generation or snapshot.get("step_ids", []) != _step_ids():
		return _reject(&"stale_snapshot")
	var index := int(snapshot.get("current_index", -1))
	var completed: Array = snapshot.get("completed", [])
	if index < -1 or index > _steps.size() or not snapshot.get("started", false) or completed.size() != maxi(index, 0):
		return _reject(&"invalid_snapshot_state")
	for i in completed.size():
		if StringName(completed[i]) != StringName(_steps[i]["id"]):
			return _reject(&"invalid_snapshot_state")
	var family := StringName(snapshot.get("preferred_input_family", INPUT_CONTROLLER))
	if family != INPUT_CONTROLLER and family != INPUT_KEYBOARD:
		return _reject(&"invalid_snapshot_state")
	_started = true
	_current_index = index
	_completed.clear()
	for value in completed:
		_completed.append(StringName(value))
	_preferred_input_family = family
	return _state_result(&"restored")


func audit() -> Dictionary:
	return {
		"valid": _steps.size() <= MAX_STEPS,
		"max_steps": MAX_STEPS,
		"controller_first_default": _preferred_input_family == INPUT_CONTROLLER,
		"checkpointed": true,
		"accessibility_prompt_variant": true,
		"reads_input_map": false,
		"gameplay_authority": false,
		"player_authority": false,
		"ship_authority": false,
		"save_authority": false,
	}


func _step_ids() -> Array[StringName]:
	var ids: Array[StringName] = []
	for step in _steps:
		ids.append(step["id"])
	return ids


func _state_result(reason: StringName) -> Dictionary:
	var result := get_snapshot()
	result["accepted"] = true
	result["reason"] = reason
	result["current_step"] = current_step()
	result["current_prompt"] = current_prompt()
	return result


func _reject(reason: StringName) -> Dictionary:
	return {"accepted": false, "reason": reason, "generation": _generation}
