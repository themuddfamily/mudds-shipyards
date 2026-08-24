class_name NearbySectorActivityMusicAdapter
extends Node

## Audio-only bridge from detached Nearby Sector activity snapshots to the
## caller-owned StationMusicBed. It never selects activity state or gameplay.

const ACTIVITY_KINDS := [
	&"race", &"patrol", &"convoy", &"cargo", &"defense", &"mining", &"salvage", &"beacon",
]
const ACTIVITY_STATES := [&"active", &"complete", &"reset", &"idle"]
const MAX_SAFE_GENERATION := 9_007_199_254_740_991

var _bed: StationMusicBed
var _attached := false
var _generation := 0
var _last_activity_generation := -1
var _last_snapshot: Dictionary = {}


func configure(bed: StationMusicBed) -> Dictionary:
	if bed == null:
		return _result(false, &"missing_music_bed")
	if _bed != null:
		return _result(false, &"already_configured")
	_bed = bed
	return _result(true, &"configured")


func attach(expected_generation: int = 0) -> Dictionary:
	if _bed == null:
		return _result(false, &"not_configured")
	if expected_generation != _generation:
		return _result(false, &"stale_generation")
	_attached = true
	_last_activity_generation = -1
	_last_snapshot.clear()
	_bed.set_bed_enabled(true)
	return _result(true, &"attached")


func present_activity_snapshot(snapshot: Dictionary) -> Dictionary:
	if not _attached or _bed == null:
		return _result(false, &"not_attached")
	var decoded := _decode_snapshot(snapshot)
	if not bool(decoded.get("accepted", false)):
		return _result(false, StringName(decoded.get("reason", &"invalid_snapshot")))
	var generation := int(decoded.generation)
	if generation <= _last_activity_generation:
		return _result(false, &"stale_activity_generation")
	var accepted := _bed.notify_activity_state(decoded.activity_kind, decoded.activity_state)
	if not accepted:
		return _result(false, &"music_state_rejected")
	_last_activity_generation = generation
	# Retain only the validated routing tuple. Activity snapshots may carry
	# caller-owned payloads (including decoded audio resources); none of those
	# fields participate in music selection, so keeping a deep copy would pin
	# them until the next accepted snapshot or detach.
	_last_snapshot = {
		"generation": generation,
		"activity_kind": decoded.activity_kind,
		"activity_state": decoded.activity_state,
	}
	return _result(true, &"activity_music_presented")


func detach() -> Dictionary:
	if not _attached:
		return _result(false, &"not_attached")
	_attached = false
	_generation += 1
	_last_activity_generation = -1
	_last_snapshot.clear()
	_bed.set_bed_enabled(false)
	return _result(true, &"detached")


func get_snapshot() -> Dictionary:
	return {
		"attached": _attached,
		"generation": _generation,
		"last_activity_generation": _last_activity_generation,
		"last_snapshot": _last_snapshot.duplicate(true),
		"music": _bed.get_state_snapshot() if _bed != null else {},
		"authority": {"activity": false, "gameplay": false, "music_playback": false},
	}.duplicate(true)


func _decode_snapshot(snapshot: Dictionary) -> Dictionary:
	var generation: Variant = snapshot.get("generation", -1)
	var kind: Variant = snapshot.get("activity_kind", &"")
	var state: Variant = snapshot.get("activity_state", &"")
	if not (generation is int) or int(generation) < 0 or int(generation) > MAX_SAFE_GENERATION \
			or kind is not StringName or not ACTIVITY_KINDS.has(kind as StringName) \
			or state is not StringName or not ACTIVITY_STATES.has(state as StringName):
		return _result(false, &"invalid_snapshot")
	return {
		"accepted": true,
		"generation": int(generation),
		"activity_kind": kind,
		"activity_state": state,
	}.duplicate(true)


func _result(accepted: bool, reason: StringName) -> Dictionary:
	return {"accepted": accepted, "reason": reason}.duplicate(true)
