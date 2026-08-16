class_name StationDefenseContract
extends RefCounted

## Immutable, data-only definition for one station-defense objective.
##
## Hostiles and protected station assets are generation-bearing handles supplied
## by callers. This contract snapshots primitives only; it resolves no nodes and
## owns no spawning, combat, damage, world, or protected-object lifecycle.

enum WaveMode {
	ORDERED,
	SIMULTANEOUS,
}

const MAX_SAFE_INTEGER := 9_007_199_254_740_991
const MAX_ID_LENGTH := 64
const MAX_WAVES := 16
const MAX_HOSTILES_PER_WAVE := 64
const MAX_TOTAL_HOSTILES := 256
const MAX_PROTECTED_ASSETS := 64
const MAX_WAVE_DELAY_SECONDS := 600.0
const MAX_TIMEOUT_SECONDS := 86_400.0

const _WAVE_KEYS := ["wave_id", "mode", "delay_seconds", "hostile_handles"]
const _HOSTILE_HANDLE_KEYS := ["hostile_id", "generation"]
const _ASSET_HANDLE_KEYS := ["asset_id", "generation"]

var _activity_id: StringName
var _waves: Array[Dictionary] = []
var _protected_asset_handles: Array[Dictionary] = []
var _timeout_seconds: float
var _configuration_errors := PackedStringArray()


func _init(
	p_activity_id: StringName,
	p_waves: Array[Dictionary],
	p_protected_asset_handles: Array[Dictionary],
	p_timeout_seconds: float
	) -> void:
	_activity_id = p_activity_id
	_timeout_seconds = p_timeout_seconds
	_capture_waves(p_waves)
	_capture_protected_assets(p_protected_asset_handles)
	_validate_configuration()


func is_configuration_valid() -> bool:
	return _configuration_errors.is_empty()


func get_configuration_errors() -> PackedStringArray:
	return _configuration_errors.duplicate()


func get_activity_id() -> StringName:
	return _activity_id


func get_wave_count() -> int:
	return _waves.size()


func get_wave(index: int) -> Dictionary:
	if index < 0 or index >= _waves.size():
		return {}
	return _waves[index].duplicate(true)


func get_waves() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for wave in _waves:
		result.append(wave.duplicate(true))
	return result


func get_protected_asset_handles() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for handle in _protected_asset_handles:
		result.append(handle.duplicate(true))
	return result


func get_timeout_seconds() -> float:
	return _timeout_seconds


func get_snapshot() -> Dictionary:
	return {
		"activity_id": _activity_id,
		"waves": get_waves(),
		"protected_asset_handles": get_protected_asset_handles(),
		"timeout_seconds": _timeout_seconds,
	}


func audit() -> Dictionary:
	return {
		"valid": is_configuration_valid(),
		"errors": get_configuration_errors(),
		"limits": {
			"maximum_waves": MAX_WAVES,
			"maximum_hostiles_per_wave": MAX_HOSTILES_PER_WAVE,
			"maximum_total_hostiles": MAX_TOTAL_HOSTILES,
			"maximum_protected_assets": MAX_PROTECTED_ASSETS,
			"maximum_wave_delay_seconds": MAX_WAVE_DELAY_SECONDS,
			"maximum_timeout_seconds": MAX_TIMEOUT_SECONDS,
		},
		"authority": _authority_exclusions(),
		"contract": get_snapshot(),
	}.duplicate(true)


func _capture_waves(input_waves: Array[Dictionary]) -> void:
	for input_wave in input_waves:
		if not _has_exact_keys(input_wave, _WAVE_KEYS):
			_configuration_errors.append("wave entries must contain exactly wave_id, mode, delay_seconds, and hostile_handles")
		var raw_wave_id: Variant = _field(input_wave, "wave_id", null)
		if not raw_wave_id is String and not raw_wave_id is StringName:
			_configuration_errors.append("wave_id must be a String or StringName")
		var raw_mode: Variant = _field(input_wave, "mode", null)
		if not raw_mode is int:
			_configuration_errors.append("wave mode must be an integer enum")
		var raw_delay: Variant = _field(input_wave, "delay_seconds", null)
		if not raw_delay is int and not raw_delay is float:
			_configuration_errors.append("wave delay must be numeric")
		var captured_handles: Array[Dictionary] = []
		var raw_handles: Variant = _field(input_wave, "hostile_handles", [])
		if raw_handles is Array:
			for raw_handle: Variant in raw_handles as Array:
				if raw_handle is Dictionary:
					var handle := raw_handle as Dictionary
					if not _has_exact_keys(handle, _HOSTILE_HANDLE_KEYS):
						_configuration_errors.append("hostile handles must contain exactly hostile_id and generation")
					captured_handles.append(_canonical_handle(handle, "hostile_id"))
				else:
					_configuration_errors.append("hostile handles must be dictionaries")
		else:
			_configuration_errors.append("hostile_handles must be an Array")
		_waves.append({
			"wave_id": _canonical_id(raw_wave_id),
			"mode": int(raw_mode) if raw_mode is int else -1,
			"delay_seconds": float(raw_delay) if raw_delay is int or raw_delay is float else NAN,
			"hostile_handles": captured_handles,
		})


func _capture_protected_assets(input_handles: Array[Dictionary]) -> void:
	for input_handle in input_handles:
		if not _has_exact_keys(input_handle, _ASSET_HANDLE_KEYS):
			_configuration_errors.append("protected asset handles must contain exactly asset_id and generation")
		_protected_asset_handles.append(_canonical_handle(input_handle, "asset_id"))


func _validate_configuration() -> void:
	if not is_stable_id(_activity_id):
		_configuration_errors.append("activity_id must be a stable identifier")
	if _waves.is_empty() or _waves.size() > MAX_WAVES:
		_configuration_errors.append("wave count must be within 1..%d" % MAX_WAVES)
	if not is_finite(_timeout_seconds) \
		or _timeout_seconds <= 0.0 \
		or _timeout_seconds > MAX_TIMEOUT_SECONDS:
		_configuration_errors.append("timeout_seconds is outside its finite bound")
	if _protected_asset_handles.is_empty() \
		or _protected_asset_handles.size() > MAX_PROTECTED_ASSETS:
		_configuration_errors.append("protected asset count must be within 1..%d" % MAX_PROTECTED_ASSETS)

	var wave_ids := {}
	var hostile_ids := {}
	var total_hostiles := 0
	for wave in _waves:
		var wave_id := StringName(wave.wave_id)
		if not is_stable_id(wave_id):
			_configuration_errors.append("wave IDs must be stable identifiers")
		elif wave_ids.has(wave_id):
			_configuration_errors.append("wave IDs must be unique")
		else:
			wave_ids[wave_id] = true
		if int(wave.mode) < WaveMode.ORDERED or int(wave.mode) > WaveMode.SIMULTANEOUS:
			_configuration_errors.append("wave mode must be ORDERED or SIMULTANEOUS")
		var delay := float(wave.delay_seconds)
		if not is_finite(delay) or delay < 0.0 or delay > MAX_WAVE_DELAY_SECONDS:
			_configuration_errors.append("wave delay is outside its finite bound")
		var handles := wave.hostile_handles as Array
		if handles.is_empty() or handles.size() > MAX_HOSTILES_PER_WAVE:
			_configuration_errors.append("hostiles per wave must be within 1..%d" % MAX_HOSTILES_PER_WAVE)
		total_hostiles += handles.size()
		for handle: Dictionary in handles:
			_validate_handle(handle, "hostile_id", "hostile", _configuration_errors)
			var hostile_id := StringName(handle.get("hostile_id", &""))
			if hostile_ids.has(hostile_id):
				_configuration_errors.append("hostile IDs must be unique across every wave")
			else:
				hostile_ids[hostile_id] = true
	if total_hostiles > MAX_TOTAL_HOSTILES:
		_configuration_errors.append("total hostile count exceeds %d" % MAX_TOTAL_HOSTILES)

	var asset_ids := {}
	for handle in _protected_asset_handles:
		_validate_handle(handle, "asset_id", "protected asset", _configuration_errors)
		var asset_id := StringName(handle.get("asset_id", &""))
		if asset_ids.has(asset_id):
			_configuration_errors.append("protected asset IDs must be unique")
		else:
			asset_ids[asset_id] = true
	_configuration_errors.sort()


static func is_stable_id(value: Variant) -> bool:
	if not value is String and not value is StringName:
		return false
	var text := str(value)
	if text.is_empty() or text.length() > MAX_ID_LENGTH:
		return false
	for character in text:
		var code := character.unicode_at(0)
		var allowed := code >= 97 and code <= 122 \
			or code >= 48 and code <= 57 \
			or character in ["_", "-", "."]
		if not allowed:
			return false
	return true


static func validate_event_handle(handle: Dictionary) -> bool:
	if not _has_exact_keys(handle, ["event_id", "generation"]):
		return false
	return is_stable_id(_field(handle, "event_id", &"")) \
		and _valid_generation(_field(handle, "generation", 0))


static func canonical_event_handle(handle: Dictionary) -> Dictionary:
	return {
		"event_id": StringName(_field(handle, "event_id", &"")),
		"generation": int(_field(handle, "generation", 0)),
	}


static func canonical_hostile_handle(handle: Dictionary) -> Dictionary:
	return _canonical_handle(handle, "hostile_id")


static func canonical_asset_handle(handle: Dictionary) -> Dictionary:
	return _canonical_handle(handle, "asset_id")


static func handle_key(handle: Dictionary, id_field: String) -> String:
	return "%s@%d" % [str(_field(handle, id_field, &"")), int(_field(handle, "generation", 0))]


static func _canonical_handle(handle: Dictionary, id_field: String) -> Dictionary:
	var generation: Variant = _field(handle, "generation", 0)
	return {
		id_field: _canonical_id(_field(handle, id_field, null)),
		"generation": int(generation) if generation is int else 0,
	}


static func _canonical_id(value: Variant) -> StringName:
	return StringName(value) if value is String or value is StringName else &""


static func _validate_handle(
	handle: Dictionary,
	id_field: String,
	label: String,
	errors: PackedStringArray
	) -> void:
	if not is_stable_id(handle.get(id_field, &"")):
		errors.append("%s handle has an invalid stable identity" % label)
	if not _valid_generation(handle.get("generation", 0)):
		errors.append("%s handle has an invalid generation" % label)


static func _valid_generation(value: Variant) -> bool:
	return value is int and int(value) > 0 and int(value) <= MAX_SAFE_INTEGER


static func _has_exact_keys(dictionary: Dictionary, expected: Array) -> bool:
	if dictionary.size() != expected.size():
		return false
	var normalized := PackedStringArray()
	for key: Variant in dictionary:
		if not key is String and not key is StringName:
			return false
		normalized.append(str(key))
	for expected_key: String in expected:
		if not normalized.has(expected_key):
			return false
	return true


static func _field(dictionary: Dictionary, key: String, default_value: Variant) -> Variant:
	if dictionary.has(key):
		return dictionary[key]
	var named := StringName(key)
	return dictionary[named] if dictionary.has(named) else default_value


static func _authority_exclusions() -> Dictionary:
	return {
		"combat_resolution": false,
		"spawning": false,
		"damage": false,
		"rewards": false,
		"ships": false,
		"berths": false,
		"world_geometry": false,
		"hud": false,
		"game_flow": false,
		"main": false,
		"save": false,
		"network": false,
	}
