class_name ShipPerspectiveAudioBinding
extends RefCounted

## Audio-only bridge for caller-owned cockpit/chase presentation state.
## Camera and occupancy truth stay with the caller; this binding only forwards
## an accepted perspective to an existing production ShipAudioRig.

const PERSPECTIVE_EXTERIOR: StringName = &"exterior"
const PERSPECTIVE_COCKPIT: StringName = &"cockpit"
const PERSPECTIVES := [PERSPECTIVE_EXTERIOR, PERSPECTIVE_COCKPIT]
const MAX_SAFE_GENERATION := 9_007_199_254_740_991

var _rig: Node
var _attached := false
var _generation := 0
var _perspective: StringName = PERSPECTIVE_EXTERIOR


func bind(rig: Node) -> Dictionary:
	if _attached:
		return _result(false, &"already_bound")
	if rig == null or not is_instance_valid(rig) \
			or not rig.has_method(&"get_component_id") \
			or rig.call(&"get_component_id") != &"ship-audio-rig":
		return _result(false, &"foreign_audio_rig")
	if not rig.has_method(&"set_audio_perspective") \
			or not rig.has_method(&"get_audio_perspective"):
		return _result(false, &"incomplete_audio_rig")
	_rig = rig
	_attached = true
	_perspective = PERSPECTIVE_EXTERIOR
	_rig.call(&"set_audio_perspective", PERSPECTIVE_EXTERIOR)
	return _result(true, &"bound")


func present_perspective(perspective: StringName, expected_generation: int) -> Dictionary:
	if not _attached or not is_instance_valid(_rig):
		return _result(false, &"not_attached")
	if expected_generation != _generation:
		return _result(false, &"stale_generation")
	if not PERSPECTIVES.has(perspective):
		return _result(false, &"invalid_perspective")
	if _perspective == perspective:
		return _result(true, &"unchanged")
	if not bool(_rig.call(&"set_audio_perspective", perspective)):
		return _result(false, &"perspective_rejected")
	_perspective = perspective
	return _result(true, &"perspective_updated")


func detach() -> Dictionary:
	if not _attached:
		return _result(false, &"not_attached")
	if is_instance_valid(_rig):
		_rig.call(&"set_audio_perspective", PERSPECTIVE_EXTERIOR)
	_attached = false
	_rig = null
	_perspective = PERSPECTIVE_EXTERIOR
	if _generation >= MAX_SAFE_GENERATION:
		return _result(false, &"generation_exhausted")
	_generation += 1
	return _result(true, &"detached")


func get_snapshot() -> Dictionary:
	return {
		"attached": _attached,
		"generation": _generation,
		"perspective": _perspective,
		"authority": {"camera": false, "occupancy": false, "audio_presentation": true},
	}.duplicate(true)


func _result(accepted: bool, reason: StringName) -> Dictionary:
	return {"accepted": accepted, "reason": reason, "generation": _generation}.duplicate(true)
