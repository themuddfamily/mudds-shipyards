class_name HeroFleetAudioBinding
extends RefCounted

## Audio-owned component-damage composition for the baseline hero-fleet rigs.
## The caller supplies the hero identity and existing ShipAudioRig; this bridge
## owns neither ship state nor playback resources.

const ComponentDamageBinding := preload("res://scripts/audio/component_damage_audio_binding.gd")

var _rig: Node
var _parent: Node
var _damage_binding: RefCounted
var _ship_id: StringName = &""
var _profile_id: StringName = &""
var _attached := false
var _generation := 0


func bind(ship_id: StringName, rig: Node) -> Dictionary:
	if _attached:
		return _result(false, &"already_bound")
	if ship_id.is_empty():
		return _result(false, &"missing_ship_id")
	if rig == null or not rig.has_method(&"get_component_id") \
			or rig.call(&"get_component_id") != &"ship-audio-rig":
		return _result(false, &"foreign_audio_rig")
	if not rig.has_method(&"get_profile_id") \
			or not rig.has_method(&"get_declared_profile_ids"):
		return _result(false, &"invalid_audio_rig")
	var profile_id: StringName = rig.call(&"get_profile_id")
	var declared: PackedStringArray = rig.call(&"get_declared_profile_ids")
	if not declared.has(String(profile_id)):
		return _result(false, &"unsupported_audio_profile")
	var damage_binding := ComponentDamageBinding.new()
	var damage_result: Dictionary = damage_binding.bind(rig)
	if not bool(damage_result.get("accepted", false)):
		return _result(false, &"damage_binding_failed")
	_rig = rig
	_damage_binding = damage_binding
	_ship_id = ship_id
	_profile_id = profile_id
	_attached = true
	return _result(true, &"bound")


func bind_parent(parent: Node, rig: Node) -> Dictionary:
	if parent == null or not parent.has_signal(&"component_damage_changed") \
			or not parent.has_method(&"get_component_damage_report"):
		return _result(false, &"invalid_hero_parent")
	var ship_id: StringName = StringName(parent.get("ship_id"))
	var result := bind(ship_id, rig)
	if bool(result.get("accepted", false)):
		_parent = parent
	return result


func present_parent_damage(
		_component_id: StringName,
		_state: int,
		_integrity: float
	) -> Dictionary:
	if not _attached or not is_instance_valid(_parent):
		return _result(false, &"not_bound")
	var report: Dictionary = _parent.call(&"get_component_damage_report")
	var failed_count := int(report.get("failed_count", 0))
	var impaired_count := int(report.get("impaired_count", 0))
	var worst_integrity := clampf(float(report.get("worst_integrity", 1.0)), 0.0, 1.0)
	var stage: StringName = &"critical" if failed_count > 0 else (&"degraded" if impaired_count > 0 else &"repaired")
	return present_component_damage({"stage": stage, "health_ratio": worst_integrity})


func present_component_damage(snapshot: Dictionary) -> Dictionary:
	if not _attached or _damage_binding == null:
		return _result(false, &"not_bound")
	return _damage_binding.present_damage_snapshot(snapshot)


func detach() -> Dictionary:
	if not _attached:
		return _result(false, &"not_bound")
	_attached = false
	_generation += 1
	if _damage_binding != null:
		_damage_binding.detach()
	_damage_binding = null
	_parent = null
	_rig = null
	_ship_id = &""
	_profile_id = &""
	return _result(true, &"detached")


func get_snapshot() -> Dictionary:
	return {
		"attached": _attached,
		"generation": _generation,
		"ship_id": _ship_id,
		"profile_id": _profile_id,
		"component_damage": _damage_binding.get_snapshot() if _damage_binding != null else {},
		"authority": {"ship": false, "damage": false, "repair": false, "audio_playback": false},
	}.duplicate(true)


func _result(accepted: bool, reason: StringName) -> Dictionary:
	return {"accepted": accepted, "reason": reason, "generation": _generation}.duplicate(true)
