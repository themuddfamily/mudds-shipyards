class_name CinderNavigatorPingHudComposition
extends RefCounted

## Caller-injected presentation composition for Cinder navigator bridge output.
## It owns one presenter and adapter only; callers retain bridge, HUD lifecycle,
## ordinary crew snapshots, Cinder, network, sensor, and audio authority.

const PresenterType := preload("res://scripts/ui/cinder_navigator_ping_presenter.gd")
const AdapterType := preload("res://scripts/ui/cinder_navigator_ping_hud_adapter.gd")

var _presenter: Object
var _adapter: Object
var _hud: Object
var _attached := false
var _generation := 0
var _last_result: Dictionary = {}
var _last_migration_generation := 0
var _last_server_tick := 0


func attach(hud: Object) -> Dictionary:
	if _attached:
		detach()
	_presenter = PresenterType.new()
	_adapter = AdapterType.new()
	var bound: Dictionary = _adapter.attach(hud, _presenter)
	if not bool(bound.get("accepted", false)):
		_presenter = null
		_adapter = null
		return _reject(StringName(bound.get("reason", &"adapter_attach_failed")))
	_hud = hud
	_attached = true
	_generation += 1
	_last_result.clear()
	_last_migration_generation = 0
	_last_server_tick = 0
	return _result(true, &"bound")


func detach() -> Dictionary:
	if _adapter != null:
		_adapter.detach()
	_presenter = null
	_adapter = null
	_hud = null
	_attached = false
	_generation += 1
	_last_result.clear()
	_last_migration_generation = 0
	_last_server_tick = 0
	return _result(true, &"detached")


func apply_bridge_result(result: Dictionary, base_crew_snapshot: Dictionary = {}) -> Dictionary:
	if not _ready():
		return _reject(&"detached")
	var applied: Dictionary = _adapter.apply_bridge_result(result, base_crew_snapshot)
	return _record(applied)


func apply_tombstones(
		tombstones: Array,
		base_crew_snapshot: Dictionary = {},
		status: StringName = &"peer_released"
	) -> Dictionary:
	return apply_bridge_result({
		"accepted": true,
		"status": status,
		"tombstones": tombstones.duplicate(true),
	}, base_crew_snapshot)


func get_snapshot() -> Dictionary:
	return {
		"attached": _ready(),
		"generation": _generation,
		"migration_generation": _last_migration_generation,
		"server_tick": _last_server_tick,
		"presenter": _presenter.get_snapshot() if _presenter != null else {},
		"adapter": _adapter.get_snapshot() if _adapter != null else {},
		"last_result": _last_result.duplicate(true),
		"presentation_only": true,
		"hud_lifecycle_authority": false,
		"crew_role_authority": false,
		"cinder_authority": false,
		"network_authority": false,
		"sensor_authority": false,
		"audio_authority": false,
	}.duplicate(true)


func _record(applied: Dictionary) -> Dictionary:
	var recorded := applied.duplicate(true)
	recorded["composition_generation"] = _generation
	if bool(applied.get("accepted", false)) and applied.get("reason") != &"duplicate":
		_last_result = recorded.duplicate(true)
		var view := (applied.get("composed", {}) as Dictionary).get("cinder_navigator_ping", {}) as Dictionary
		if view.has("migration_generation"):
			_last_migration_generation = int(view.get("migration_generation", 0))
		if view.has("server_tick"):
			_last_server_tick = int(view.get("server_tick", 0))
	return recorded


func _ready() -> bool:
	return _attached and _presenter != null and _adapter != null \
			and _hud != null and is_instance_valid(_hud)


func _result(accepted: bool, reason: StringName) -> Dictionary:
	return {
		"accepted": accepted,
		"reason": reason,
		"generation": _generation,
		"presentation_only": true,
	}.duplicate(true)


func _reject(reason: StringName) -> Dictionary:
	return _result(false, reason)
