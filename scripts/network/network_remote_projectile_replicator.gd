class_name NetworkRemoteProjectileReplicator
extends Node3D

## Replicates the travelling projectiles the host resolves -- the Cinder
## hauler's mass-driver slugs and the torpedo boat's seeker torpedoes -- to the
## clients, as presentation only.
##
## Both weapons are real authority flights on the host (`CombatResolver` opens
## the flight, `LiveCombatAuthority` commits the arrival). Before this a client
## saw neither: the pulse, bomber-payload and opponent-pulse records crossed the
## wire, but a slug or a torpedo simply never appeared on any other machine.
##
## ## Host half
##
## `observe_pool()` listens to a pool's own launch / resolve / abandon /
## intercept signals and turns each into one record on the existing projectile
## snapshot path (`NetworkEnetSessionAdapter.publish_projectile_snapshot()`),
## through a publisher callable GameFlow supplies so every projectile publisher
## on the host shares one monotonic tick. A slug flies straight, so its launch
## record is enough until it ends; a torpedo steers, so every
## `TORPEDO_UPDATE_INTERVAL_TICKS` its live position and heading are published
## again. Nothing here reads a collision, applies damage or decides a hit.
##
## ## Client half
##
## `present_packet()` takes the packet GameFlow's projectile replica handler
## routes here and draws it: a small emissive slug or torpedo body with a
## trail, flown forward at the published speed between records and eased onto
## each newer record, and a short burst at the terminal position. A visual
## whose record stops arriving is retired after its published lifetime, so a
## lost terminal never leaves a slug hanging in the sky.

const RECORD_KEY := "remote_projectile_record"
const KIND_SLUG: StringName = &"mass_driver_slug"
const KIND_TORPEDO: StringName = &"seeker_torpedo"
const TORPEDO_UPDATE_INTERVAL_TICKS := 6
const MAX_VISUALS := 24
const MAX_SPEED := 2000.0
const MAX_LIFETIME := 30.0
const LIFETIME_GRACE_SECONDS := 1.0
const CORRECTION_RATE := 10.0
const BURST_SECONDS := 0.45

const SLUG_CORE_COLOR := Color("d8fbff")
const SLUG_TRAIL_COLOR := Color("3fb6d9")
const TORPEDO_HULL_COLOR := Color("2d3530")
const TORPEDO_SEEKER_COLOR := Color("d4ff3a")
const TORPEDO_TRAIL_COLOR := Color("ff9a3c")

var _publisher := Callable()
var _pools: Dictionary = {}
var _active: Dictionary = {}
var _serial := 0
var _host_ticks := 0
var _published_count := 0
var _publish_failures := 0

var _visuals: Dictionary = {}
var _free_visuals: Array = []
var _reduced_flash := false
var _presented_count := 0
var _terminal_count := 0
var _expired_count := 0
var _burst_count := 0


func _ready() -> void:
	set_process(false)


func _exit_tree() -> void:
	clear_presentation()


# --- host half ---------------------------------------------------------------


## `publisher` is called as `publisher.call(projectile: Dictionary, terminal:
## bool, recipients: Array) -> Dictionary` and owns the tick stamp.
func set_publisher(publisher: Callable) -> void:
	_publisher = publisher


## Starts replicating one pool. `kind` is `KIND_SLUG` for a
## `TravellingBoltProjectile` pool or `KIND_TORPEDO` for a
## `SeekerTorpedoProjectile` pool; `source_entity_id` names the shooter on the
## wire. Observing the same pool again is a no-op.
func observe_pool(pool: Node, kind: StringName, source_entity_id: StringName) -> Dictionary:
	if not is_instance_valid(pool) or kind not in [KIND_SLUG, KIND_TORPEDO] \
			or String(source_entity_id).is_empty():
		return {"accepted": false, "status": &"invalid_pool"}
	var key := pool.get_instance_id()
	if _pools.has(key):
		return {"accepted": true, "status": &"already_observed"}
	var bindings: Array = []
	if kind == KIND_SLUG:
		bindings = [
			[&"bolt_launched", Callable(self, "_on_launched").bind(key)],
			[&"bolt_resolved", Callable(self, "_on_resolved").bind(key)],
			[&"bolt_abandoned", Callable(self, "_on_abandoned").bind(key)],
		]
	else:
		bindings = [
			[&"torpedo_launched", Callable(self, "_on_launched").bind(key)],
			[&"torpedo_resolved", Callable(self, "_on_resolved").bind(key)],
			[&"torpedo_abandoned", Callable(self, "_on_abandoned").bind(key)],
			[&"torpedo_intercepted", Callable(self, "_on_intercepted").bind(key)],
		]
	for binding: Array in bindings:
		if not pool.has_signal(StringName(binding[0])):
			return {"accepted": false, "status": &"pool_signals_missing"}
	for binding: Array in bindings:
		pool.connect(StringName(binding[0]), binding[1] as Callable)
	_pools[key] = {
		"pool": weakref(pool), "kind": kind, "source": source_entity_id, "bindings": bindings,
	}
	return {"accepted": true, "status": &"pool_observed", "kind": kind}


func is_observing(pool: Node) -> bool:
	return is_instance_valid(pool) and _pools.has(pool.get_instance_id())


## One authority physics tick: drops pools that went away (aborting their
## flights on the wire) and restates every live torpedo's pose on its cadence.
func advance_host() -> void:
	_host_ticks += 1
	for key_variant in _pools.keys():
		var entry := _pools[key_variant] as Dictionary
		var pool := (entry.pool as WeakRef).get_ref() as Node
		if not is_instance_valid(pool) or pool.is_queued_for_deletion():
			_forget_pool(int(key_variant), &"pool_retired")
	if _host_ticks % TORPEDO_UPDATE_INTERVAL_TICKS != 0:
		return
	for key_variant in _pools.keys():
		var entry := _pools[key_variant] as Dictionary
		if StringName(entry.kind) != KIND_TORPEDO:
			continue
		var pool := (entry.pool as WeakRef).get_ref() as Node
		if not pool.has_method(&"get_active_torpedo_records"):
			continue
		for record_variant in pool.call(&"get_active_torpedo_records"):
			var record := record_variant as Dictionary
			var active_key := _active_key(int(key_variant), int(record.get("flight_id", 0)))
			if not _active.has(active_key):
				continue
			var active := _active[active_key] as Dictionary
			# The newest steered pose is what a late peer is shown and what an
			# abort names, not the launch record.
			active["record"] = record.duplicate(true)
			var projectile := _projectile_from_record(active, record, &"flying", {})
			if not projectile.is_empty():
				_publish(projectile, false)


## Re-sends every live flight to a peer that just joined.
func republish_for_peer(peer_id: int) -> int:
	var sent := 0
	for active_variant in _active.values():
		var active := active_variant as Dictionary
		var record := (active.record as Dictionary).duplicate(true)
		if StringName(active.kind) == KIND_SLUG:
			# A slug's only record is its launch; a late peer is shown it where
			# it has flown to since, not back at the muzzle.
			var elapsed := float(Time.get_ticks_msec() - int(active.get("launched_msec", 0))) / 1000.0
			var origin: Variant = record.get("origin", record.get("position"))
			var direction: Variant = record.get("direction", Vector3.FORWARD)
			if origin is Vector3 and direction is Vector3 and (origin as Vector3).is_finite():
				record["position"] = (origin as Vector3) \
					+ (direction as Vector3).normalized() * float(record.get("speed", 0.0)) * elapsed
				record["elapsed"] = float(record.get("elapsed", 0.0)) + elapsed
		var projectile := _projectile_from_record(active, record, &"flying", {})
		if not projectile.is_empty() and bool(_publish(projectile, false, [peer_id]).get("accepted", false)):
			sent += 1
	return sent


## Stops observing every pool. `abort` publishes an abort for each live flight
## first (a pool retired mid-session); a stopped session passes false because
## there is nobody left to tell.
func clear_host(abort: bool = false) -> void:
	for key_variant in _pools.keys():
		_forget_pool(int(key_variant), &"host_cleared", abort)
	_pools.clear()
	_active.clear()


func get_active_flight_count() -> int:
	return _active.size()


func _forget_pool(key: int, reason: StringName, abort: bool = true) -> void:
	var entry := _pools.get(key, {}) as Dictionary
	_pools.erase(key)
	if entry.is_empty():
		return
	var pool := (entry.pool as WeakRef).get_ref() as Node
	if is_instance_valid(pool):
		for binding: Array in entry.get("bindings", []):
			if pool.is_connected(StringName(binding[0]), binding[1] as Callable):
				pool.disconnect(StringName(binding[0]), binding[1] as Callable)
	for active_key in _active.keys():
		var active := _active[active_key] as Dictionary
		if int(active.pool_key) != key:
			continue
		_active.erase(active_key)
		if abort:
			var projectile := _projectile_from_record(active, active.record as Dictionary, &"aborted", {})
			if not projectile.is_empty():
				projectile["terminal_reason"] = reason
				_publish(projectile, true)


func _on_launched(record: Dictionary, pool_key: int) -> void:
	var entry := _pools.get(pool_key, {}) as Dictionary
	if entry.is_empty():
		return
	var flight_id := int(record.get("flight_id", 0))
	if flight_id <= 0:
		return
	_serial += 1
	var prefix := "slug" if StringName(entry.kind) == KIND_SLUG else "torpedo"
	var active := {
		"projectile_id": StringName("%s-%d" % [prefix, _serial]),
		"kind": entry.kind,
		"source": entry.source,
		"pool_key": pool_key,
		"record": record.duplicate(true),
		"launched_msec": Time.get_ticks_msec(),
	}
	_active[_active_key(pool_key, flight_id)] = active
	var projectile := _projectile_from_record(active, record, &"flying", {}, true)
	if not projectile.is_empty():
		_publish(projectile, false)


func _on_resolved(record: Dictionary, result: Dictionary, pool_key: int) -> void:
	# The host presents a detonation only for an arrival that did damage (a
	# no-damage proximity fuse is a near miss), so only that is an impact here.
	var damaged := bool(result.get("damaged", false))
	_end_flight(record, pool_key, &"resolved", {
		"kind": &"impact" if damaged else &"expiry",
		"reason": StringName(record.get("terminal_reason", &"")),
	})


func _on_abandoned(record: Dictionary, reason: StringName, pool_key: int) -> void:
	_end_flight(record, pool_key, &"aborted", {"reason": reason})


func _on_intercepted(record: Dictionary, pool_key: int) -> void:
	_end_flight(record, pool_key, &"resolved", {"kind": &"impact", "reason": &"intercepted"})


func _end_flight(record: Dictionary, pool_key: int, state: StringName, terminal_intent: Dictionary) -> void:
	var active_key := _active_key(pool_key, int(record.get("flight_id", 0)))
	if not _active.has(active_key):
		return
	var active := _active[active_key] as Dictionary
	_active.erase(active_key)
	var terminal_record := record.duplicate(true)
	var terminal_position: Variant = record.get("terminal_position", record.get("position"))
	if terminal_position is Vector3 and (terminal_position as Vector3).is_finite():
		terminal_record["position"] = terminal_position
	var projectile := _projectile_from_record(
		active, terminal_record, state, {} if state == &"aborted" else terminal_intent
	)
	if projectile.is_empty():
		return
	projectile["terminal_reason"] = StringName(terminal_intent.get("reason", &""))
	_publish(projectile, true)


func _projectile_from_record(
	active: Dictionary, record: Dictionary, state: StringName, terminal_intent: Dictionary,
	launch: bool = false
) -> Dictionary:
	var position: Variant = record.get("position", record.get("origin"))
	var direction: Variant = record.get("direction", Vector3.FORWARD)
	if not position is Vector3 or not (position as Vector3).is_finite():
		return {}
	if not direction is Vector3 or not (direction as Vector3).is_finite() \
			or (direction as Vector3).length_squared() < 0.000001:
		direction = Vector3.FORWARD
	var projectile := {
		"projectile_id": StringName(active.projectile_id),
		"projectile_generation": 1,
		"source_entity_id": StringName(active.source),
		"source_generation": 1,
		"owner_peer_id": 1,
		"position": position,
		"direction": (direction as Vector3).normalized(),
		"last_update_tick": 0,
		"state": state,
		RECORD_KEY: {
			"kind": StringName(active.kind),
			# Only the live launch carries this transient cue. Late-join and
			# steering records describe a flight already underway.
			"launch": launch,
			"speed": clampf(float(record.get("speed", 0.0)), 0.0, MAX_SPEED),
			"lifetime": clampf(float(record.get("lifetime", 0.0)), 0.0, MAX_LIFETIME),
			"elapsed": maxf(0.0, float(record.get("elapsed", 0.0))),
			"radius": maxf(0.0, float(record.get("radius", 0.0))),
		},
	}
	if not terminal_intent.is_empty():
		projectile["terminal_intent"] = {
			"kind": StringName(terminal_intent.get("kind", &"impact")),
			"projectile_id": StringName(active.projectile_id),
			"projectile_generation": 1,
			"source_generation": 1,
		}
	return projectile


func _publish(projectile: Dictionary, terminal: bool, recipients: Array = []) -> Dictionary:
	if not _publisher.is_valid():
		_publish_failures += 1
		return {"accepted": false, "status": &"publisher_unavailable"}
	var result: Variant = _publisher.call(projectile, terminal, recipients)
	if result is Dictionary and bool((result as Dictionary).get("accepted", false)):
		_published_count += 1
		return result as Dictionary
	_publish_failures += 1
	return result as Dictionary if result is Dictionary else {"accepted": false, "status": &"publish_failed"}


static func _active_key(pool_key: int, flight_id: int) -> String:
	return "%d:%d" % [pool_key, flight_id]


# --- client half -------------------------------------------------------------


func set_reduced_flash_enabled(enabled: bool) -> void:
	_reduced_flash = enabled


## Draws one replicated record. `status` is the adapter's own verdict on the
## packet (`projectile_presented`, `projectile_waiting_for_gap` or
## `projectile_terminal_applied`); anything else is not drawn.
func present_packet(packet: Dictionary, status: StringName) -> Dictionary:
	var projectile := packet.get("projectile", {}) as Dictionary
	var descriptor := projectile.get(RECORD_KEY, {}) as Dictionary
	var projectile_id := StringName(projectile.get("projectile_id", &""))
	var kind := StringName(descriptor.get("kind", &""))
	var position: Variant = projectile.get("position")
	var direction: Variant = projectile.get("direction", Vector3.FORWARD)
	if String(projectile_id).is_empty() or kind not in [KIND_SLUG, KIND_TORPEDO] \
			or not position is Vector3 or not (position as Vector3).is_finite() \
			or not direction is Vector3 or not (direction as Vector3).is_finite():
		return {"accepted": false, "status": &"invalid_remote_projectile_record"}
	var speed := float(descriptor.get("speed", 0.0))
	var lifetime := float(descriptor.get("lifetime", 0.0))
	if not is_finite(speed) or speed < 0.0 or speed > MAX_SPEED \
			or not is_finite(lifetime) or lifetime < 0.0 or lifetime > MAX_LIFETIME:
		return {"accepted": false, "status": &"invalid_remote_projectile_record"}
	var forward := (direction as Vector3).normalized() if (direction as Vector3).length_squared() > 0.000001 \
		else Vector3.FORWARD
	if status == &"projectile_terminal_applied":
		_terminal_count += 1
		# Only a contact bursts. A flight that ran out of lifetime or range ends
		# quietly on the host, so it must not detonate in empty sky here.
		var intent := projectile.get("terminal_intent", {}) as Dictionary
		_retire_visual(projectile_id, position as Vector3,
			not intent.is_empty() and StringName(intent.get("kind", &"")) == &"impact")
		return {"accepted": true, "status": &"remote_projectile_terminal_presented"}
	if status not in [&"projectile_presented", &"projectile_waiting_for_gap"]:
		return {"accepted": false, "status": &"remote_projectile_not_presentable"}
	var visual := _visuals.get(projectile_id, {}) as Dictionary
	if visual.is_empty():
		visual = _acquire_visual(kind)
		if visual.is_empty():
			return {"accepted": false, "status": &"remote_projectile_capacity"}
		visual["position"] = position
		_visuals[projectile_id] = visual
		_presented_count += 1
	visual["kind"] = kind
	visual["target"] = position
	visual["direction"] = forward
	visual["speed"] = speed
	visual["remaining"] = maxf(0.0, lifetime - float(descriptor.get("elapsed", 0.0))) + LIFETIME_GRACE_SECONDS
	visual["bursting"] = false
	_apply_kind(visual, kind)
	_place(visual)
	set_process(true)
	return {"accepted": true, "status": &"remote_projectile_presented", "projectile_id": projectile_id}


func get_drawn_projectile_ids() -> Array:
	var ids: Array = []
	for projectile_id in _visuals.keys():
		if not bool((_visuals[projectile_id] as Dictionary).get("bursting", false)):
			ids.append(projectile_id)
	return ids


func get_visual_position(projectile_id: StringName) -> Vector3:
	var visual := _visuals.get(projectile_id, {}) as Dictionary
	return visual.get("position", Vector3.INF) as Vector3


func clear_presentation() -> void:
	for projectile_id in _visuals.keys():
		var visual := _visuals[projectile_id] as Dictionary
		_hide(visual)
		_free_visuals.append(visual)
	_visuals.clear()
	set_process(false)


func get_audit() -> Dictionary:
	return {
		"observed_pools": _pools.size(),
		"active_flights": _active.size(),
		"published": _published_count,
		"publish_failures": _publish_failures,
		"drawn": get_drawn_projectile_ids().size(),
		"presented": _presented_count,
		"terminals": _terminal_count,
		"expired": _expired_count,
		"bursts": _burst_count,
		"owns_combat_authority": false,
	}


func _process(delta: float) -> void:
	if _visuals.is_empty():
		set_process(false)
		return
	var step := maxf(0.0, delta)
	var alpha := 1.0 - exp(-CORRECTION_RATE * step)
	for projectile_id in _visuals.keys():
		var visual := _visuals[projectile_id] as Dictionary
		visual["remaining"] = float(visual.get("remaining", 0.0)) - step
		if bool(visual.get("bursting", false)):
			_advance_burst(visual, step)
			if float(visual.remaining) <= 0.0:
				_hide(visual)
				_visuals.erase(projectile_id)
				_free_visuals.append(visual)
			continue
		if float(visual.remaining) <= 0.0:
			_expired_count += 1
			_hide(visual)
			_visuals.erase(projectile_id)
			_free_visuals.append(visual)
			continue
		var travel := (visual.direction as Vector3) * float(visual.speed) * step
		visual["target"] = (visual.target as Vector3) + travel
		var drawn := (visual.position as Vector3) + travel
		visual["position"] = drawn.lerp(visual.target as Vector3, alpha)
		_place(visual)


func _retire_visual(projectile_id: StringName, position: Vector3, burst: bool) -> void:
	var visual := _visuals.get(projectile_id, {}) as Dictionary
	if visual.is_empty():
		if not burst:
			return
		visual = _acquire_visual(KIND_SLUG)
		if visual.is_empty():
			return
		_visuals[projectile_id] = visual
	if not burst:
		_hide(visual)
		_visuals.erase(projectile_id)
		_free_visuals.append(visual)
		return
	_burst_count += 1
	visual["position"] = position
	visual["bursting"] = true
	visual["remaining"] = BURST_SECONDS
	var root := visual.root as Node3D
	root.global_position = position
	(visual.body as Node3D).visible = false
	(visual.trail as Node3D).visible = false
	var burst_node := visual.burst as MeshInstance3D
	burst_node.visible = true
	burst_node.scale = Vector3.ONE * 0.4
	set_process(true)


func _advance_burst(visual: Dictionary, _step: float) -> void:
	var progress := 1.0 - clampf(float(visual.remaining) / BURST_SECONDS, 0.0, 1.0)
	var maximum := 2.2 if _reduced_flash else 3.6
	(visual.burst as Node3D).scale = Vector3.ONE * lerpf(0.4, maximum, progress)


func _acquire_visual(kind: StringName) -> Dictionary:
	if not _free_visuals.is_empty():
		var reused := _free_visuals.pop_back() as Dictionary
		(reused.root as Node3D).visible = true
		return reused
	if _visuals.size() >= MAX_VISUALS or not is_inside_tree():
		return {}
	var root := Node3D.new()
	root.name = "RemoteProjectile_%d" % (_visuals.size() + _free_visuals.size())
	add_child(root)
	root.top_level = true
	var body := MeshInstance3D.new()
	body.name = "Body"
	var body_mesh := CapsuleMesh.new()
	body_mesh.radius = 0.2
	body_mesh.height = 0.9
	body.mesh = body_mesh
	body.rotation = Vector3(-PI * 0.5, 0.0, 0.0)
	body.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(body)
	var trail := MeshInstance3D.new()
	trail.name = "Trail"
	var trail_mesh := CylinderMesh.new()
	trail_mesh.top_radius = 0.02
	trail_mesh.bottom_radius = 0.16
	trail_mesh.height = 5.0
	trail.mesh = trail_mesh
	trail.rotation = Vector3(-PI * 0.5, 0.0, 0.0)
	trail.position = Vector3(0.0, 0.0, 2.9)
	trail.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(trail)
	var burst := MeshInstance3D.new()
	burst.name = "Burst"
	var burst_mesh := SphereMesh.new()
	burst_mesh.radius = 0.6
	burst_mesh.height = 1.2
	burst.mesh = burst_mesh
	burst.visible = false
	burst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(burst)
	var visual := {
		"root": root, "body": body, "trail": trail, "burst": burst, "kind": &"",
		"position": Vector3.ZERO, "target": Vector3.ZERO, "direction": Vector3.FORWARD,
		"speed": 0.0, "remaining": 0.0, "bursting": false,
	}
	_apply_kind(visual, kind)
	return visual


func _apply_kind(visual: Dictionary, kind: StringName) -> void:
	if StringName(visual.get("applied_kind", &"")) == kind and StringName(visual.get("applied_flash", &"")) \
			== (&"reduced" if _reduced_flash else &"full"):
		(visual.body as Node3D).visible = true
		(visual.trail as Node3D).visible = true
		(visual.burst as Node3D).visible = false
		return
	var torpedo := kind == KIND_TORPEDO
	var body := visual.body as MeshInstance3D
	var trail := visual.trail as MeshInstance3D
	var burst := visual.burst as MeshInstance3D
	var body_mesh := body.mesh as CapsuleMesh
	body_mesh.radius = 0.34 if torpedo else 0.16
	body_mesh.height = 2.6 if torpedo else 0.8
	(trail.mesh as CylinderMesh).height = (3.0 if _reduced_flash else 7.0) if torpedo else 5.0
	trail.position = Vector3(0.0, 0.0, (trail.mesh as CylinderMesh).height * 0.5 + body_mesh.height * 0.5)
	var energy_scale := 0.35 if _reduced_flash else 1.0
	body.material_override = _material(
		TORPEDO_HULL_COLOR if torpedo else SLUG_CORE_COLOR,
		(1.2 if torpedo else 5.0) * energy_scale, false
	)
	trail.material_override = _material(
		TORPEDO_TRAIL_COLOR if torpedo else SLUG_TRAIL_COLOR, 2.2 * energy_scale, true
	)
	burst.material_override = _material(
		TORPEDO_SEEKER_COLOR if torpedo else SLUG_CORE_COLOR, 4.0 * energy_scale, true
	)
	body.visible = true
	trail.visible = true
	burst.visible = false
	visual["applied_kind"] = kind
	visual["applied_flash"] = &"reduced" if _reduced_flash else &"full"


func _place(visual: Dictionary) -> void:
	var root := visual.root as Node3D
	if not is_instance_valid(root) or not root.is_inside_tree():
		return
	var forward := visual.direction as Vector3
	var origin := visual.position as Vector3
	var up := Vector3.UP if absf(forward.dot(Vector3.UP)) < 0.98 else Vector3.RIGHT
	root.global_transform = Transform3D(Basis.looking_at(forward, up), origin)


func _hide(visual: Dictionary) -> void:
	var root := visual.get("root") as Node3D
	if is_instance_valid(root):
		root.visible = false
	visual["bursting"] = false


static func _material(color: Color, energy: float, translucent: bool) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = Color(color, 0.7) if translucent else color
	material.emission_enabled = true
	material.emission = color
	material.emission_energy_multiplier = energy
	if translucent:
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	return material
