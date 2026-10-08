class_name NetworkRemoteCraftPoseStream
extends RefCounted

## Host-authoritative craft pose replication for piloted craft.
##
## Before this, a peer the ledger seated in a pilot seat flew its own local copy
## of the craft while the host simulated the authoritative copy from the same
## helm, and nothing ever carried the host's answer back: over a long flight the
## two drifted apart, and every *other* client saw the craft parked at its berth
## the whole time. This is the missing half.
##
## ## Host half (publisher)
##
## Every `PUBLISH_INTERVAL_TICKS` authority ticks (20 Hz) the host builds one
## movement entry per piloted craft -- each remote pilot's craft, and the host's
## own craft while the host flies it -- and GameFlow hands them to the existing
## authoritative snapshot (`NetworkEnetSessionAdapter.publish_snapshot()`, via
## the ship-telemetry bridge), so they ride the delta codec, the fragmenter and
## the client's `NetworkSnapshotJitterBuffer` like every other movement record.
## A craft whose pilot lets go keeps being published for `COAST_TICKS` so the
## other clients watch it settle where the host's copy settles, and a craft that
## is destroyed while tracked is published once more per interval with
## `destroyed = true` so its pilot's client can present the loss.
##
## ## Client half (replica)
##
## `consume_movement_section()` keeps a short history of samples per craft.
## Once per physics tick `advance_replica()` then does one of two things with
## each craft it has samples for:
##
## * the craft this peer is **piloting** is its own prediction: the host's pose
##   is extrapolated forward by the round trip (that is how far the local copy
##   leads the host's) and the local copy is pulled toward it -- nothing inside
##   `CORRECTION_DEADBAND_METERS`, an exponential blend beyond it, and a hard
##   snap past `SNAP_DISTANCE_METERS` / `SNAP_ANGLE_RADIANS`;
## * every **other** craft is interpolated between the two samples that bracket
##   a render clock running `INTERPOLATION_DELAY_TICKS` behind the newest
##   arrival, and briefly extrapolated when the stream stalls.
##
## Nothing here grants authority. A client never publishes a pose, and the only
## node this class moves is a craft the caller hands it on a client.

const MODE: StringName = &"remote_pilot_craft"
const ENTITY_SUFFIX := "-pose"
const PUBLISH_INTERVAL_TICKS := 3
const COAST_TICKS := 600
const TICK_SECONDS := 1.0 / 60.0
const MAX_DISPLAY_BYTES := 8192
const MAX_DISPLAY_INFLATED_BYTES := 65536

const SAMPLE_HISTORY := 8
const STALE_SAMPLE_TICKS := 120
const MAX_LEAD_TICKS := 30
## The helm is sampled every four physics ticks and held; on average a command
## is two ticks old before it leaves the pilot's machine.
const HELM_QUANTIZATION_TICKS := 2

const CORRECTION_DEADBAND_METERS := 0.5
const SNAP_DISTANCE_METERS := 15.0
const POSITION_CORRECTION_RATE := 4.0
const ROTATION_DEADBAND_RADIANS := 0.05
const SNAP_ANGLE_RADIANS := 1.05
const ROTATION_CORRECTION_RATE := 3.0
const VELOCITY_CORRECTION_RATE := 2.0

const INTERPOLATION_DELAY_TICKS := 6
const MAX_OBSERVER_EXTRAPOLATION_TICKS := 15
const CLOCK_SNAP_TICKS := 30.0
const CLOCK_SLEW := 0.1

# Host state.
var _published: Dictionary = {}
var _observed_damage: Dictionary = {}
var _settled: Dictionary = {}
var _observed_operation: Dictionary = {}

# Client state.
var _samples: Dictionary = {}
var _settled_applied: Dictionary = {}
var _presentation_shapes: Dictionary = {}
var _presentation_source_keys: Dictionary = {}
var _epoch := 0
var _clock := -1.0
var _heard_tick := -1
var _heard_frame := -1
var _corrections := 0
var _snaps := 0
var _interpolated := 0
var _rejected := 0


static func pose_entity_id(ship_id: StringName) -> StringName:
	return StringName("%s%s" % [String(ship_id), ENTITY_SUFFIX])


## One movement entry for one piloted craft. `pose_tick` is the authority's
## boarding-ledger tick, the one clock both halves already share.
static func build_pose_entry(
	craft: Node3D, ship_id: StringName, pilot_peer_id: int, pose_tick: int, destroyed: bool = false
) -> Dictionary:
	if not is_instance_valid(craft) or not craft.is_inside_tree() or String(ship_id).is_empty():
		return {}
	var velocity := Vector3.ZERO
	if craft is CharacterBody3D:
		velocity = (craft as CharacterBody3D).velocity
	var transform := craft.global_transform
	if not transform.origin.is_finite() or not velocity.is_finite():
		return {}
	var hull: Dictionary = (craft as HeroShip).get_network_damage_presentation_snapshot() if craft is HeroShip else {}
	return {
		"entity_id": pose_entity_id(ship_id),
		"entity_generation": maxi(1, int(hull.get("component_generation", 1))),
		"hull_presentation": hull,
		"operation_presentation": (craft as HeroShip).get_network_operation_presentation_snapshot() if craft is HeroShip else {},
		"operation_tick": maxi(0, pose_tick), "pose_active": true,
		"owner_peer_id": maxi(1, pilot_peer_id),
		"mode": MODE,
		"ship_id": ship_id,
		"pose_tick": maxi(0, pose_tick),
		"position": transform.origin,
		"rotation": transform.basis.orthonormalized().get_rotation_quaternion(),
		"velocity_world": velocity,
		"destroyed": destroyed,
	}


# --- host half ---------------------------------------------------------------


static func should_publish(server_tick: int) -> bool:
	return server_tick >= 0 and server_tick % PUBLISH_INTERVAL_TICKS == 0


## `pilots` maps ship_id -> {"craft": Node3D, "peer_id": int} for every craft
## that is piloted right now. Returns the movement entries to publish this tick
## (empty on a tick that is not a publish tick).
func build_host_entries(pilots: Dictionary, server_tick: int, observed_craft: Array = [], epoch: int = 1, station_origin: Vector3 = Vector3.ZERO) -> Array:
	var entries: Array = []
	for ship_id_variant in pilots.keys():
		var ship_id := StringName(ship_id_variant)
		var pilot := pilots[ship_id_variant] as Dictionary
		var craft = pilot.get("craft")
		if not is_instance_valid(craft):
			continue
		_published[ship_id] = {
			"craft": craft, "peer_id": int(pilot.get("peer_id", 1)), "last_piloted_tick": server_tick,
		}
	if not should_publish(server_tick):
		return entries
	# Read committed owners after their transactions. Changes reopen the same
	# coast window, so regeneration at a berth is published even after the pilot
	# and old pose stream have gone. Hits never manufacture a new generation.
	for craft: HeroShip in observed_craft:
		if not is_instance_valid(craft) or not craft.is_inside_tree():
			continue
		var ship_id := craft.get_ship_id()
		var hull := craft.get_network_damage_presentation_snapshot()
		if hull.is_empty():
			continue
		var prior := _observed_damage.get(ship_id, {}) as Dictionary
		var changed := not prior.is_empty() and prior != hull
		var already_damaged := float(hull.health) < float(hull.maximum_health) or int(hull.component_generation) > 1
		for component: Dictionary in hull.components:
			already_damaged = already_damaged or int(component.state) != 0
		if changed or (prior.is_empty() and already_damaged):
			_published[ship_id] = {"craft": craft, "peer_id": int((_published.get(ship_id, {}) as Dictionary).get("peer_id", 1)), "last_piloted_tick": server_tick}
		_observed_damage[ship_id] = hull
		var operation := craft.get_network_operation_presentation_snapshot()
		var facts := [operation.engine, operation.landed, operation.docked, operation.landing, operation.canopy_open]
		var operating: bool = operation.engine != HeroShip.ENGINE_OFFLINE or bool(operation.docked) or bool(operation.landing) or not bool(operation.landed) or bool(operation.canopy_open)
		if (_observed_operation.has(ship_id) and _observed_operation[ship_id] != facts) or (not _observed_operation.has(ship_id) and operating):
			_published[ship_id] = {"craft": craft, "peer_id": int((_published.get(ship_id, {}) as Dictionary).get("peer_id", 1)), "last_piloted_tick": server_tick}
		_observed_operation[ship_id] = facts
		if not _settled.has(ship_id) and _published.has(ship_id):
			_settled[ship_id] = {"craft": craft, "pose_tick": server_tick, "position": craft.global_position - station_origin,
				"rotation": craft.global_basis.orthonormalized().get_rotation_quaternion(), "velocity_world": craft.velocity}

	for ship_id_variant in _published.keys():
		var ship_id := StringName(ship_id_variant)
		var record := _published[ship_id_variant] as Dictionary
		var craft = record.get("craft")
		if not is_instance_valid(craft) or not (craft as Node).is_inside_tree():
			_published.erase(ship_id_variant)
			continue
		if server_tick - int(record.get("last_piloted_tick", server_tick)) > COAST_TICKS \
				and not (craft.has_method(&"is_destroyed") and bool(craft.call(&"is_destroyed"))):
			_published.erase(ship_id_variant)
			continue
		var destroyed: bool = craft.has_method(&"is_destroyed") and bool(craft.call(&"is_destroyed"))
		var entry := build_pose_entry(
			craft as Node3D, ship_id, int(record.get("peer_id", 1)), server_tick, destroyed
		)
		if not entry.is_empty():
			entry["craft_epoch"] = maxi(1, epoch)
			entries.append(entry)
			_settled[ship_id] = {"craft": craft, "pose_tick": server_tick, "position": entry.position - station_origin,
				"rotation": entry.rotation, "velocity_world": entry.velocity_world}
	# Motion coasts independently of committed parked operation facts. Idle
	# rows retain their last pose tick: they never manufacture fresh movement.
	for ship_id: StringName in _settled.keys():
		if _published.has(ship_id):
			continue
		var record: Dictionary = _settled[ship_id]
		var craft: Node3D = record.craft if is_instance_valid(record.craft) else null
		if craft == null or not craft.is_inside_tree():
			_settled.erase(ship_id)
			_observed_operation.erase(ship_id)
			continue
		var entry := build_pose_entry(craft, ship_id, 1, int(record.pose_tick), bool(craft.call(&"is_destroyed")))
		if not entry.is_empty():
			entry["craft_epoch"] = maxi(1, epoch)
			for field: String in ["position", "rotation", "velocity_world"]:
				entry[field] = record[field]
			entry["position"] += station_origin
			entry["pose_active"] = false
			entry["operation_tick"] = server_tick
			entries.append(entry)
	return entries


func is_host_tracking(ship_id: StringName) -> bool:
	return _published.has(ship_id)


func clear_host() -> void:
	_published.clear()
	_observed_damage.clear()
	_observed_operation.clear()
	_settled.clear()


# --- client half -------------------------------------------------------------


## Takes the movement section of one applied authoritative snapshot. Only this
## stream's entries are read; everything else in the section is ignored. A
## sample no newer than the newest one already held for that craft (the
## canonical republish of an older movement section, say) changes nothing.
func consume_movement_section(movement: Array, physics_frame: int = -1, station_origin: Vector3 = Vector3.ZERO) -> int:
	var accepted := 0
	var display_batch := _display_batch_from_movement(movement)
	for entry_variant in movement:
		if not entry_variant is Dictionary:
			continue
		var entry := entry_variant as Dictionary
		if StringName(entry.get("mode", &"")) != MODE:
			continue
		var sample := _sample_from_entry(entry, display_batch, station_origin)
		if sample.is_empty():
			_rejected += 1
			continue
		var ship_id := StringName(sample.get("ship_id", &""))
		if _epoch > 0 and int(sample.craft_epoch) != _epoch:
			_rejected += 1
			continue
		_epoch = int(sample.craft_epoch)
		var history: Array = _samples.get(ship_id, [])
		if not history.is_empty():
			var previous := history.back() as Dictionary
			if int(sample.entity_generation) < int(previous.entity_generation) \
					or (int(sample.entity_generation) == int(previous.entity_generation) and bool(previous.destroyed) and not bool(sample.destroyed)):
				_rejected += 1
				continue
			if int(sample.entity_generation) > int(previous.entity_generation):
				history = []
		if not history.is_empty() and int(sample.pose_tick) <= int((history.back() as Dictionary).pose_tick):
			if int(sample.pose_tick) == int((history.back() as Dictionary).pose_tick) \
					and int(sample.operation_tick) > int((history.back() as Dictionary).get("operation_tick", -1)):
				history[history.size() - 1] = sample
				_samples[ship_id] = history
				accepted += 1
			continue
		history.append(sample)
		while history.size() > SAMPLE_HISTORY:
			history.pop_front()
		_samples[ship_id] = history
		accepted += 1
		if int(sample.pose_tick) > _heard_tick:
			_heard_tick = int(sample.pose_tick)
			_heard_frame = physics_frame if physics_frame >= 0 else Engine.get_physics_frames()
	return accepted



## Immutable local authored shapes only. Retained solo damage and operational
## state cannot affect these fingerprints. Rebind after production variants
## build at each session; clear retires all source references with that session.
func bind_replica_craft_presentations(ships: Array) -> void:
	_presentation_shapes.clear()
	_presentation_source_keys.clear()
	for craft: HeroShip in ships:
		if not is_instance_valid(craft) or not craft.is_inside_tree():
			continue
		var hull := craft.get_network_damage_presentation_snapshot()
		var operation := craft.get_network_operation_presentation_snapshot()
		if hull.is_empty() or operation.is_empty():
			continue
		var placements: Array = []
		for component: Dictionary in hull.components:
			placements.append([component.local_position, component.local_radius])
		var paths: Array = []
		for renderer: Array in operation.renderers:
			paths.append(renderer[0])
		_presentation_shapes[craft.get_ship_id()] = {"placements": placements, "paths": paths,
			"layout_hash": hash(placements), "roster_hash": hash([paths, operation.renderer_kinds])}
		_presentation_source_keys[craft.get_ship_id()] = _craft_presentation_source_key(craft)

func _craft_presentation_source_key(craft: HeroShip) -> Array:
	var visual := craft.get_variant_visual_root()
	return [craft.get_instance_id(), craft.ship_definition.get_instance_id() if craft.ship_definition != null else 0,
		visual.get_instance_id() if is_instance_valid(visual) else 0]


func ensure_replica_craft_presentations(ships: Array) -> void:
	var changed := false
	for craft: HeroShip in ships:
		if is_instance_valid(craft) and craft.is_inside_tree() \
				and _presentation_source_keys.get(craft.get_ship_id(), []) != _craft_presentation_source_key(craft):
			forget(craft.get_ship_id())
			craft.clear_network_operation_presentation()
			craft.clear_network_damage_presentation()
			changed = true
	if changed:
		bind_replica_craft_presentations(ships)


func has_samples(ship_id: StringName) -> bool:
	return not (_samples.get(ship_id, []) as Array).is_empty()


func latest_sample(ship_id: StringName) -> Dictionary:
	var history: Array = _samples.get(ship_id, [])
	return (history.back() as Dictionary).duplicate(true) if not history.is_empty() else {}


func get_tracked_ship_ids() -> Array:
	return _samples.keys()


func forget(ship_id: StringName) -> void:
	_samples.erase(ship_id)
	_settled_applied.erase(ship_id)


func clear_replica() -> void:
	_samples.clear()
	_settled_applied.clear()
	_presentation_shapes.clear()
	_presentation_source_keys.clear()
	_epoch = 0
	_clock = -1.0
	_heard_tick = -1
	_heard_frame = -1


## The replica's estimate of the authority tick, advanced once per physics
## tick and slewed toward "newest pose heard + physics frames since", so the
## render clock moves smoothly between arrivals instead of in 3-tick steps.
func advance_clock(physics_frame: int = -1) -> float:
	if _heard_tick < 0:
		return -1.0
	var frame := physics_frame if physics_frame >= 0 else Engine.get_physics_frames()
	var target := float(_heard_tick + maxi(0, frame - _heard_frame))
	if _clock < 0.0 or absf(target - (_clock + 1.0)) > CLOCK_SNAP_TICKS:
		_clock = target
	else:
		_clock += 1.0
		_clock += (target - _clock) * CLOCK_SLEW
	return _clock


func get_clock() -> float:
	return _clock


## One physics tick of the replica. `ships` is every craft this peer knows,
## `piloted` the one it is flying as a remote pilot (or null), `locally_flown`
## any craft this peer is flying on its own authority (never touched), and
## `round_trip_ms` the transport's current RTT to the host.
func advance_replica(
	ships: Array, piloted: Node3D, locally_flown: Node3D, round_trip_ms: float, delta: float
) -> Dictionary:
	var clock := advance_clock()
	var report := {"corrected": 0, "snapped": 0, "interpolated": 0, "clock": clock}
	if clock < 0.0:
		return report
	for craft_variant in ships:
		if not is_instance_valid(craft_variant) or not craft_variant is Node3D:
			continue
		var craft := craft_variant as Node3D
		if not craft.has_method(&"get_ship_id"):
			continue
		var ship_id := StringName(craft.call(&"get_ship_id"))
		if not has_samples(ship_id):
			continue
		var latest := latest_sample(ship_id)
		if craft == locally_flown:
			continue
		if not bool(latest.get("pose_active", true)):
			var settled_key := Vector2i(int(latest.entity_generation), int(latest.pose_tick))
			if _settled_applied.get(ship_id) != settled_key:
				craft.global_transform = Transform3D(Basis(latest.rotation), latest.position)
				if craft is CharacterBody3D:
					craft.velocity = latest.velocity_world
				_settled_applied[ship_id] = settled_key
			continue
		_settled_applied.erase(ship_id)
		if clock - float(latest.pose_tick) > STALE_SAMPLE_TICKS:
			continue
		if craft == piloted:
			var verdict := reconcile_pilot(craft, ship_id, round_trip_ms, delta)
			if StringName(verdict.get("status", &"")) == &"snapped":
				report.snapped = int(report.snapped) + 1
			elif StringName(verdict.get("status", &"")) == &"corrected":
				report.corrected = int(report.corrected) + 1
			continue
		if craft == locally_flown:
			continue
		if bool(interpolate_observer(craft, ship_id).get("applied", false)):
			report.interpolated = int(report.interpolated) + 1
	return report


## Pulls this peer's own predicted copy toward the host's authoritative pose.
## The host's sample is extrapolated by how far the local copy leads it: the
## time since the sample was taken plus one round trip (the local copy already
## contains the helm input the host has not simulated yet) plus the helm's own
## send quantisation.
func reconcile_pilot(craft: Node3D, ship_id: StringName, round_trip_ms: float, delta: float) -> Dictionary:
	var latest := latest_sample(ship_id)
	if latest.is_empty() or not is_instance_valid(craft):
		return {"status": &"no_sample"}
	if bool(latest.get("destroyed", false)):
		return {"status": &"destroyed"}
	if craft.has_method(&"is_landing_active") and bool(craft.call(&"is_landing_active")):
		return {"status": &"landing"}
	var lead_ticks := clampf(
		maxf(0.0, _clock - float(latest.pose_tick))
			+ maxf(0.0, round_trip_ms) / 1000.0 / TICK_SECONDS
			+ HELM_QUANTIZATION_TICKS,
		0.0, MAX_LEAD_TICKS
	)
	var host_velocity: Vector3 = latest.velocity_world
	var target_position: Vector3 = (latest.position as Vector3) + host_velocity * lead_ticks * TICK_SECONDS
	var target_rotation: Quaternion = latest.rotation
	var current := craft.global_transform
	var current_rotation := current.basis.orthonormalized().get_rotation_quaternion()
	var position_error := target_position - current.origin
	var angle_error := current_rotation.angle_to(target_rotation)
	if position_error.length() > SNAP_DISTANCE_METERS or angle_error > SNAP_ANGLE_RADIANS:
		craft.global_transform = Transform3D(Basis(target_rotation), target_position)
		if craft is CharacterBody3D:
			(craft as CharacterBody3D).velocity = host_velocity
		if craft.has_method(&"reset_physics_interpolation"):
			craft.reset_physics_interpolation()
		_snaps += 1
		return {"status": &"snapped", "error": position_error.length(), "angle": angle_error}
	var corrected := false
	var step := maxf(0.0, delta)
	if position_error.length() > CORRECTION_DEADBAND_METERS:
		var alpha := 1.0 - exp(-POSITION_CORRECTION_RATE * step)
		craft.global_position = current.origin + position_error * alpha
		if craft is CharacterBody3D:
			var body := craft as CharacterBody3D
			body.velocity = body.velocity.lerp(
				host_velocity, 1.0 - exp(-VELOCITY_CORRECTION_RATE * step)
			)
		corrected = true
	if angle_error > ROTATION_DEADBAND_RADIANS:
		var beta := 1.0 - exp(-ROTATION_CORRECTION_RATE * step)
		var origin := craft.global_position
		craft.global_transform = Transform3D(Basis(current_rotation.slerp(target_rotation, beta)), origin)
		corrected = true
	if corrected:
		_corrections += 1
		return {"status": &"corrected", "error": position_error.length(), "angle": angle_error}
	return {"status": &"within_deadband", "error": position_error.length(), "angle": angle_error}


## Moves a craft somebody else is flying to where the host had it
## `INTERPOLATION_DELAY_TICKS` ago, between the two samples that bracket that
## time; past the newest sample it extrapolates for at most
## `MAX_OBSERVER_EXTRAPOLATION_TICKS` and then holds.
func interpolate_observer(craft: Node3D, ship_id: StringName) -> Dictionary:
	var history: Array = _samples.get(ship_id, [])
	if history.is_empty() or not is_instance_valid(craft) or _clock < 0.0:
		return {"applied": false, "status": &"no_sample"}
	var render_tick := _clock - INTERPOLATION_DELAY_TICKS
	var older: Dictionary = {}
	var newer: Dictionary = {}
	for sample_variant in history:
		var sample := sample_variant as Dictionary
		if float(sample.pose_tick) <= render_tick:
			older = sample
		else:
			newer = sample
			break
	var position: Vector3
	var rotation: Quaternion
	var velocity: Vector3
	if older.is_empty():
		# Everything held is still ahead of the render clock (the stream just
		# started): hold the oldest sample.
		var first := history.front() as Dictionary
		position = first.position
		rotation = first.rotation
		velocity = first.velocity_world
	elif newer.is_empty():
		var ahead := clampf(render_tick - float(older.pose_tick), 0.0, MAX_OBSERVER_EXTRAPOLATION_TICKS)
		velocity = older.velocity_world
		position = (older.position as Vector3) + velocity * ahead * TICK_SECONDS
		rotation = older.rotation
	else:
		var span := maxf(1.0, float(newer.pose_tick) - float(older.pose_tick))
		var t := clampf((render_tick - float(older.pose_tick)) / span, 0.0, 1.0)
		position = (older.position as Vector3).lerp(newer.position as Vector3, t)
		rotation = (older.rotation as Quaternion).slerp(newer.rotation as Quaternion, t)
		velocity = (older.velocity_world as Vector3).lerp(newer.velocity_world as Vector3, t)
	craft.global_transform = Transform3D(Basis(rotation), position)
	if craft is CharacterBody3D:
		(craft as CharacterBody3D).velocity = velocity
	_interpolated += 1
	return {"applied": true, "status": &"interpolated", "render_tick": render_tick}


func get_audit() -> Dictionary:
	return {
		"host_tracked": _published.keys(),
		"replica_tracked": _samples.keys(),
		"clock": _clock,
		"heard_tick": _heard_tick,
		"corrections": _corrections,
		"snaps": _snaps,
		"interpolated": _interpolated,
		"rejected": _rejected,
	}


func _display_batch_from_movement(movement: Array) -> Dictionary:
	for row: Variant in movement:
		if not row is Dictionary or StringName(row.get("mode", &"")) != MODE or not row.has("display_facts"):
			continue
		var packed: Variant = row.display_facts
		var inflated_size: Variant = row.get("display_size")
		if not packed is PackedByteArray or packed.size() < 8 or packed.size() > MAX_DISPLAY_BYTES \
				or packed[0] != 0x28 or packed[1] != 0xb5 or packed[2] != 0x2f or packed[3] != 0xfd \
				or not inflated_size is int or int(inflated_size) < 8 or int(inflated_size) > MAX_DISPLAY_INFLATED_BYTES:
			return {}
		var inflated: PackedByteArray = packed.decompress(int(inflated_size), FileAccess.COMPRESSION_ZSTD)
		if inflated.is_empty():
			return {}
		var decoded: Variant = bytes_to_var(inflated)
		if not decoded is Array or decoded.size() > 9:
			return {}
		var facts: Dictionary = {}
		for item: Variant in decoded:
			if not item is Array or item.size() != 11 or not (item[0] is StringName or item[0] is String):
				return {}
			var identity := pose_entity_id(StringName(item[0]))
			if facts.has(identity):
				return {}
			facts[identity] = item
		return facts
	return {}


func _sample_from_entry(entry: Dictionary, display_batch: Dictionary = {}, station_origin: Vector3 = Vector3.ZERO) -> Dictionary:
	var display: Dictionary = entry
	if not entry.has("ship_id"):
		var identity := StringName(entry.get("entity_id", &""))
		if not display_batch.has(identity):
			return {}
		var decoded: Variant = display_batch[identity]
		if not decoded is Array or decoded.size() != 11 or not decoded[9] is Array or decoded[9].size() != 10:
			return {}
		entry = entry.duplicate()
		var fields := ["ship_id", "pose_tick", "operation_tick", "pose_active", "craft_epoch", "rotation", "velocity_world", "destroyed", "hull_presentation"]
		for index in fields.size():
			entry[fields[index]] = decoded[index]
		var shape: Dictionary = _presentation_shapes.get(StringName(decoded[0]), {})
		if shape.is_empty() or not decoded[9][9] is int or int(decoded[9][9]) != int(shape.roster_hash):
			return {}
		var operation: Dictionary = {}
		var operation_fields := ["engine", "landed", "docked", "landing", "canopy", "canopy_open", "readout", "readout_color", "renderers"]
		for index in operation_fields.size():
			operation[operation_fields[index]] = decoded[9][index]
		if not operation.renderers is Array or operation.renderers.size() != shape.paths.size():
			return {}
		var renderers: Array = []
		var indices: Dictionary = {}
		for row: Variant in operation.renderers:
			if not row is Array or row.size() != 12 or not row[0] is int or int(row[0]) < 0 \
					or int(row[0]) >= shape.paths.size() or indices.has(int(row[0])):
				return {}
			indices[int(row[0])] = true
			var renderer: Array = row.duplicate()
			renderer[0] = shape.paths[int(row[0])]
			renderers.append(renderer)
		operation["renderers"] = renderers
		entry["operation_presentation"] = operation
		if not decoded[10] is Vector3 or not (decoded[10] as Vector3).is_finite():
			return {}
		entry["position"] = (decoded[10] as Vector3) + station_origin
		display = entry
		var packed_hull: Variant = display.get("hull_presentation")
		if not packed_hull is Array or packed_hull.size() != 5 or not packed_hull[3] is Array \
				or packed_hull[3].size() != ShipComponentDamage.COMPONENT_ORDER.size() \
				or not packed_hull[4] is int or int(packed_hull[4]) != int(shape.layout_hash):
			return {}
		var components: Array = []
		for index in ShipComponentDamage.COMPONENT_ORDER.size():
			var row: Variant = packed_hull[3][index]
			if not _bounded_number(row, 0.0, 1.0):
				return {}
			var state := ShipComponentDamage.state_for_integrity(float(row))
			components.append({"id": ShipComponentDamage.COMPONENT_ORDER[index], "integrity": row,
				"state": state, "state_id": ShipComponentDamage.state_id_for(state),
				"local_position": shape.placements[index][0], "local_radius": shape.placements[index][1]})
		display["hull_presentation"] = {"health": packed_hull[0], "maximum_health": packed_hull[1],
			"component_generation": packed_hull[2], "components": components}

	var ship_id := StringName(entry.get("ship_id", &""))
	var position: Variant = entry.get("position")
	var rotation: Variant = entry.get("rotation")
	var velocity: Variant = entry.get("velocity_world")
	var pose_tick: Variant = entry.get("pose_tick")
	if String(ship_id).is_empty() or StringName(entry.get("entity_id", &"")) != pose_entity_id(ship_id):
		return {}
	if not position is Vector3 or not (position as Vector3).is_finite():
		return {}
	if not velocity is Vector3 or not (velocity as Vector3).is_finite():
		return {}
	if not rotation is Quaternion or not (rotation as Quaternion).is_finite() \
			or absf((rotation as Quaternion).length() - 1.0) > 0.01:
		return {}
	if not pose_tick is int or int(pose_tick) < 0:
		return {}
	var generation: Variant = entry.get("entity_generation", 1)
	var epoch: Variant = entry.get("craft_epoch", 1)
	if not generation is int or int(generation) < 1 or not epoch is int or int(epoch) < 1:
		return {}
	var hull: Variant = display.get("hull_presentation", {})
	if not hull is Dictionary or (not (hull as Dictionary).is_empty() and not _valid_hull_presentation(hull, generation, bool(entry.get("destroyed", false)))):
		return {}
	var operation: Variant = display.get("operation_presentation", {})
	var operation_tick: Variant = entry.get("operation_tick", pose_tick)
	if not operation is Dictionary or (not operation.is_empty() and not _valid_operation_presentation(operation)) \
			or not operation_tick is int or int(operation_tick) < int(pose_tick) \
			or not entry.get("pose_active", true) is bool:
		return {}
	return {
		"operation_presentation": (operation as Dictionary).duplicate(true),
		"operation_tick": int(operation_tick), "pose_active": bool(entry.get("pose_active", true)),
		"entity_generation": int(generation), "craft_epoch": int(epoch), "hull_presentation": (hull as Dictionary).duplicate(true),
		"ship_id": ship_id,
		"pose_tick": int(pose_tick),
		"pilot_peer_id": int(entry.get("owner_peer_id", 1)),
		"position": position,
		"rotation": (rotation as Quaternion).normalized(),
		"velocity_world": velocity,
		"destroyed": bool(entry.get("destroyed", false)),
	}


func _valid_hull_presentation(hull: Dictionary, generation: int, destroyed: bool) -> bool:
	for field in ["health", "maximum_health"]:
		if not (hull.get(field) is float or hull.get(field) is int) or not is_finite(float(hull[field])):
			return false
	if float(hull.maximum_health) <= 0.0 or float(hull.health) < 0.0 or float(hull.health) > float(hull.maximum_health) \
			or destroyed != is_zero_approx(float(hull.health)) \
			or not hull.get("component_generation") is int or int(hull.component_generation) != generation \
			or not hull.get("components") is Array or (hull.components as Array).size() != ShipComponentDamage.COMPONENT_ORDER.size():
		return false
	var ids: Dictionary = {}
	for row: Variant in hull.components:
		if not row is Dictionary:
			return false
		var id := StringName(row.get("id", &""))
		if id not in ShipComponentDamage.COMPONENT_ORDER or ids.has(id) \
				or not (row.get("integrity") is float or row.get("integrity") is int) or not is_finite(float(row.integrity)) \
				or float(row.integrity) < 0.0 or float(row.integrity) > 1.0 \
				or not row.get("state") is int or int(row.state) != ShipComponentDamage.state_for_integrity(float(row.integrity)) \
				or not row.get("local_position") is Vector3 or not (row.local_position as Vector3).is_finite() \
				or not (row.get("local_radius") is float or row.get("local_radius") is int) \
				or not is_finite(float(row.local_radius)) or float(row.local_radius) <= 0.0:
			return false
		ids[id] = true
	return true


func _finite_color(value: Variant) -> bool:
	return value is Color and is_finite(value.r) and is_finite(value.g) and is_finite(value.b) and is_finite(value.a)


func _finite_transform(value: Variant) -> bool:
	return value is Transform3D and value.origin.is_finite() and value.basis.x.is_finite() \
		and value.basis.y.is_finite() and value.basis.z.is_finite() \
		and value.origin.length() < 10000.0 and value.basis.get_scale().length() < 100.0


func _bounded_number(value: Variant, lower: float, upper: float) -> bool:
	return (value is float or value is int) and is_finite(float(value)) and float(value) >= lower and float(value) <= upper


func _valid_operation_presentation(operation: Dictionary) -> bool:
	if StringName(operation.get("engine", &"")) not in [HeroShip.ENGINE_OFFLINE, HeroShip.ENGINE_STARTING, HeroShip.ENGINE_ONLINE]:
		return false
	for field: String in ["landed", "docked", "landing", "canopy_open"]:
		if not operation.get(field) is bool:
			return false
	if not _bounded_number(operation.get("canopy"), 0.0, 1.0) or not operation.get("readout") is String \
			or operation.readout.length() > 256 or not _finite_color(operation.get("readout_color")) \
			or not operation.get("renderers") is Array or operation.renderers.size() > 64:
		return false
	var paths: Dictionary = {}
	for packed: Variant in operation.renderers:
		if not packed is Array or packed.size() != 12 or not packed[0] is String:
			return false
		var row := HeroShip.unpack_network_engine_renderer(packed)
		var path: String = row.path
		if path.is_empty() or path.length() > 256 or path.begins_with("/") or ".." in path or ":" in path or paths.has(path) \
				or not _finite_transform(row.get("transform")) or not row.get("visible") is bool:
			return false
		paths[path] = true
		for uniform: String in ["plume_damage_mix", "plume_boost"]:
			if row.has(uniform) and not _bounded_number(row[uniform], 0.0, 1.0):
				return false
		if row.has("overlay") and not row.overlay is bool:
			return false
		if bool(row.get("overlay", false)) and (not _finite_color(row.get("overlay_color")) or not _bounded_number(row.get("overlay_intensity"), 0.0, 20.0)):
			return false
		if row.has("light_energy") and (not _finite_color(row.get("light_color")) or not _bounded_number(row.light_energy, 0.0, 100.0)):
			return false
		if row.has("core_material"):
			if not row.core_material is Array or row.core_material.size() != 4 or not _finite_color(row.core_material[0]) \
					or not row.core_material[1] is bool or not _finite_color(row.core_material[2]) or not _bounded_number(row.core_material[3], 0.0, 100.0):
				return false
		if row.has("slots"):
			if not row.slots is Array or row.slots.size() > 8 or not row.get("slot_count") is int or int(row.slot_count) < -1 or int(row.slot_count) > row.slots.size():
				return false
			for transform: Variant in row.slots:
				if not _finite_transform(transform):
					return false
	return true


## Only the fixed, primitive display facts are packed; no node/resource can
## enter this metadata. Compression keeps parked fleet baselines within the
## existing fragment envelope. The receiver bounds inflation and then uses
## exactly the same hull/operation validators as unpacked owning fixtures.
static func pack_display_facts(entries: Array) -> Array:
	var packed_entries: Array = []
	var batch: Array = []
	for entry: Dictionary in entries:
		var wire: Dictionary = {}
		for field: String in ["entity_id", "entity_generation", "owner_peer_id", "mode"]:
			wire[field] = entry[field]
		var hull: Dictionary = entry.hull_presentation
		var components: Array = []
		var placements: Array = []
		for component: Dictionary in hull.components:
			components.append(component.integrity)
			placements.append([component.local_position, component.local_radius])
		var operation: Dictionary = entry.operation_presentation
		var paths: Array = []
		var renderers: Array = []
		for row: Array in operation.renderers:
			var renderer := row.duplicate()
			renderer[0] = paths.size()
			paths.append(row[0])
			renderers.append(renderer)
		var operation_fields: Array = [operation.engine, operation.landed, operation.docked, operation.landing,
			operation.canopy, operation.canopy_open, operation.readout, operation.readout_color, renderers, hash([paths, operation.renderer_kinds])]
		var facts: Array = [entry.ship_id, entry.pose_tick, entry.operation_tick, entry.pose_active,
			entry.craft_epoch, entry.rotation, entry.velocity_world, entry.destroyed,
			[hull.health, hull.maximum_health, hull.component_generation, components, hash(placements)], operation_fields, entry.position]
		batch.append(facts)
		packed_entries.append(wire)
	if not packed_entries.is_empty():
		var bytes := var_to_bytes(batch)
		packed_entries[0]["display_size"] = bytes.size()
		packed_entries[0]["display_facts"] = bytes.compress(FileAccess.COMPRESSION_ZSTD)
	return packed_entries
