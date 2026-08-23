class_name NearbySectorActivityBinding
extends Node3D

## Production owner for the one authored activity that belongs in Cinder Reach.
##
## The convoy host already owns its route, movement, and escort lifecycle. This
## binding gives the streamed cluster one stable composition seam without
## handing the cluster any GameFlow, HUD, combat, reward, save, or network
## authority. The route is checked against the cluster's authored envelope; no
## points are generated or extended here.

const SCHEMA_VERSION := 1
const ACTIVITY_ID: StringName = &"cinder_reach_emberline_convoy"
const HOST_PATH := NodePath("EmberlineSupplyTenderHost")

var _host: CinderConvoyEscortHost


func _ready() -> void:
	set_process(false)
	set_physics_process(false)
	# The host normalises its display name while building, so resolve the
	# authored child by type after child-ready rather than relying on that name.
	_host = get_child(0) as CinderConvoyEscortHost


func start_convoy() -> Dictionary:
	if not is_inside_tree() or _host == null:
		return _result(false, &"not_ready")
	return _host.start(_host.get_generation())


func advance_convoy(delta: float, escort_position: Vector3) -> Dictionary:
	if not is_inside_tree() or _host == null:
		return _result(false, &"not_ready")
	return _host.advance_physics(delta, escort_position, _host.get_generation())


func reset_convoy() -> Dictionary:
	if not is_inside_tree() or _host == null:
		return _result(false, &"not_ready")
	return _host.reset(_host.get_generation())


func get_snapshot() -> Dictionary:
	return {
		"schema_version": SCHEMA_VERSION,
		"activity_id": ACTIVITY_ID,
		"host_instance_id": _host.get_instance_id() if is_instance_valid(_host) else 0,
		"host": _host.get_snapshot() if is_instance_valid(_host) else {},
		"production_owner": true,
		"gameplay_authority": false,
		"game_flow_authority": false,
		"hud_authority": false,
		"network_authority": false,
	}.duplicate(true)


func audit() -> Dictionary:
	var errors := PackedStringArray()
	if not is_instance_valid(_host) or _host.get_parent() != self:
		errors.append("one authored convoy host is required")
	else:
		for point in _host.get_snapshot().get("route_positions", PackedVector3Array()):
			var position := point as Vector3
			if not position.is_finite() or position.length() > NearbySectorCluster.MAXIMUM_CONTENT_DISTANCE:
				errors.append("convoy route leaves the authored cluster envelope")
				break
		if not bool(_host.audit().get("valid", false)):
			errors.append("convoy host audit failed")
	return {
		"schema_version": SCHEMA_VERSION,
		"activity_id": ACTIVITY_ID,
		"valid": errors.is_empty(),
		"errors": errors,
		"snapshot": get_snapshot(),
		"route_policy": &"existing_authored_convoy_route_only",
		"production_owner": true,
		"gameplay_authority": false,
		"game_flow_authority": false,
		"hud_authority": false,
		"network_authority": false,
	}.duplicate(true)


func _result(accepted: bool, reason: StringName) -> Dictionary:
	return {"accepted": accepted, "reason": reason, "snapshot": get_snapshot()}
