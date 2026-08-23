class_name EmberSurfaceLoopCommandSource
extends ShipCommandSource

## Bounded production ShipCommand producer for the standalone Ember loop.
## It owns no physics tick: HeroShip samples it through the existing transport.

enum Mode { NEUTRAL, APPROACH, BRAKE, TAKEOFF_ROTATE, ASCENT }

const SCHEMA_VERSION := 1

var _mode := Mode.NEUTRAL
var _generation := 0
var _attached := false
var _sample_count := 0


func attach(expected_generation: int = 0) -> Dictionary:
	if expected_generation != _generation:
		return _result(false, &"stale_generation")
	if not _is_current():
		return _result(false, &"command_source_detached")
	if _attached:
		return _result(false, &"already_attached")
	_generation += 1
	_attached = true
	_mode = Mode.NEUTRAL
	reset_stream()
	return _result(true, &"attached")


func set_mode(mode: int, expected_generation: int) -> Dictionary:
	if expected_generation != _generation:
		return _result(false, &"stale_generation")
	if not _is_current():
		return _result(false, &"command_source_detached")
	if not _attached:
		return _result(false, &"not_attached")
	if mode < Mode.NEUTRAL or mode > Mode.ASCENT:
		return _result(false, &"invalid_mode")
	_mode = mode
	return _result(true, &"mode_changed")


func detach(expected_generation: int) -> Dictionary:
	if expected_generation != _generation:
		return _result(false, &"stale_generation")
	if not _is_current():
		return _result(false, &"command_source_detached")
	if not _attached:
		return _result(false, &"not_attached")
	_mode = Mode.NEUTRAL
	_attached = false
	_generation += 1
	reset_stream()
	return _result(true, &"detached")


func get_generation() -> int:
	return _generation


func get_snapshot() -> Dictionary:
	return {
		"schema_version": SCHEMA_VERSION,
		"attached": _attached,
		"generation": _generation,
		"mode": _mode,
		"mode_id": _mode_id(_mode),
		"sample_count": _sample_count,
		"physics_authority": false,
		"input_map_authority": false,
		"ship_command_transport_authority": true,
	}.duplicate(true)


func _sample_controls() -> Dictionary:
	if not _is_current() or not _attached:
		return {}
	_sample_count += 1
	match _mode:
		Mode.APPROACH:
			return {"throttle": 1.0}
		Mode.BRAKE:
			return {"brake": true}
		Mode.TAKEOFF_ROTATE:
			return {"throttle": 1.0, "pitch": 1.0}
		Mode.ASCENT:
			return {"throttle": 1.0, "boost": true}
		_:
			return {}


func _result(accepted: bool, reason: StringName) -> Dictionary:
	var result := get_snapshot()
	result["accepted"] = accepted
	result["reason"] = reason
	return result.duplicate(true)


func _is_current() -> bool:
	return is_inside_tree() and not is_queued_for_deletion()


static func _mode_id(mode: int) -> StringName:
	match mode:
		Mode.NEUTRAL: return &"neutral"
		Mode.APPROACH: return &"approach"
		Mode.BRAKE: return &"brake"
		Mode.TAKEOFF_ROTATE: return &"takeoff_rotate"
		Mode.ASCENT: return &"ascent"
		_: return &"unknown"
