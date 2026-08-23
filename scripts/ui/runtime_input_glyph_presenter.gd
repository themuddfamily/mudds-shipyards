class_name RuntimeInputGlyphPresenter
extends RefCounted

## Detached, player-facing glyph rows for the core loop. This presenter only
## reads the caller's binding profile and device-family resolver; it never
## edits InputMap, commits remaps, or owns persistence.

const Resolver := preload("res://scripts/ui/input_glyph_resolver.gd")
const Profile := preload("res://scripts/settings/input_binding_profile.gd")

const SCHEMA_VERSION := 1
const DEVICE_FAMILY_KEYBOARD: StringName = &"keyboard"
const DEVICE_FAMILY_XBOX: StringName = &"gamepad_xbox"
const DEVICE_FAMILY_PLAYSTATION: StringName = &"gamepad_playstation"
const DEVICE_FAMILY_NINTENDO: StringName = &"gamepad_nintendo"
const DEVICE_FAMILY_GENERIC_GAMEPAD: StringName = &"gamepad_generic"
const SUPPORTED_DEVICE_FAMILIES: Array[StringName] = [
	DEVICE_FAMILY_KEYBOARD,
	&"mouse",
	DEVICE_FAMILY_GENERIC_GAMEPAD,
	DEVICE_FAMILY_XBOX,
	DEVICE_FAMILY_PLAYSTATION,
	DEVICE_FAMILY_NINTENDO,
]
const CORE_ACTIONS: Array[StringName] = [
	&"move_forward", &"interact", &"jump", &"sprint_boost", &"fire", &"pause",
]

var _resolver: InputGlyphResolver
var _profile: InputBindingProfile
var _detached := true


func _init(resolver: InputGlyphResolver = null) -> void:
	_resolver = resolver if resolver != null else Resolver.new()


func attach(profile: InputBindingProfile) -> Dictionary:
	if profile == null:
		return _reject(&"invalid_profile")
	_profile = profile.duplicate_profile()
	_detached = false
	return get_snapshot()


func refresh(profile: InputBindingProfile) -> Dictionary:
	return attach(profile)


func set_device_family(family: StringName) -> Dictionary:
	if not _resolver.set_explicit_device_family_override(family):
		return _reject(&"invalid_device_family")
	return get_snapshot()


func supports_device_family(family: StringName) -> bool:
	return SUPPORTED_DEVICE_FAMILIES.has(family)


func clear_device_family_override() -> Dictionary:
	_resolver.clear_explicit_device_family_override()
	return get_snapshot()


func resolve_action(action: StringName) -> Dictionary:
	if _detached or _profile == null:
		return {"action": action, "valid": false, "text": "Unbound Input", "reason": &"detached"}
	var resolved := _resolver.resolve_action(_profile, action)
	resolved["action"] = action
	return resolved.duplicate(true)


func detach() -> Dictionary:
	_profile = null
	_detached = true
	return get_snapshot()


func get_snapshot() -> Dictionary:
	var rows: Array[Dictionary] = []
	if not _detached and _profile != null:
		for action in CORE_ACTIONS:
			var resolved := _resolver.resolve_action(_profile, action)
			rows.append({
				"action": action,
				"label": _action_label(action),
				"text": str(resolved.get("text", "Unbound Input")),
				"glyph_token": resolved.get("glyph_token", &"input.unknown"),
				"device_family": resolved.get("device_family", &"unknown"),
				"valid": bool(resolved.get("valid", false)),
				"fallback_used": bool(resolved.get("fallback_used", true)),
			})
	return {
		"schema_version": SCHEMA_VERSION,
		"attached": not _detached,
		"device_family": _resolver.get_preferred_device_family(),
		"rows": rows,
		"presentation_only": true,
		"input_authority": false,
	}.duplicate(true)


func _action_label(action: StringName) -> String:
	return String(action).replace("_", " ").capitalize()


func _reject(reason: StringName) -> Dictionary:
	return {"accepted": false, "reason": reason, "presentation_only": true, "input_authority": false}
