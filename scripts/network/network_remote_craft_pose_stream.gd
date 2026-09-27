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

# Client state.
var _samples: Dictionary = {}
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
	return {
		"entity_id": pose_entity_id(ship_id),
		"entity_generation": 1,
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
func build_host_entries(pilots: Dictionary, server_tick: int) -> Array:
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
	for ship_id_variant in _published.keys():
		var ship_id := StringName(ship_id_variant)
		var record := _published[ship_id_variant] as Dictionary
		var craft = record.get("craft")
		if not is_instance_valid(craft) or not (craft as Node).is_inside_tree():
			_published.erase(ship_id_variant)
			continue
		if server_tick - int(record.get("last_piloted_tick", server_tick)) > COAST_TICKS:
			_published.erase(ship_id_variant)
			continue
		var destroyed: bool = craft.has_method(&"is_destroyed") and bool(craft.call(&"is_destroyed"))
		var entry := build_pose_entry(
			craft as Node3D, ship_id, int(record.get("peer_id", 1)), server_tick, destroyed
		)
		if not entry.is_empty():
			entries.append(entry)
	return entries


func is_host_tracking(ship_id: StringName) -> bool:
	return _published.has(ship_id)


func clear_host() -> void:
	_published.clear()


# --- client half -------------------------------------------------------------


## Takes the movement section of one applied authoritative snapshot. Only this
## stream's entries are read; everything else in the section is ignored. A
## sample no newer than the newest one already held for that craft (the
## canonical republish of an older movement section, say) changes nothing.
func consume_movement_section(movement: Array, physics_frame: int = -1) -> int:
	var accepted := 0
	for entry_variant in movement:
		if not entry_variant is Dictionary:
			continue
		var entry := entry_variant as Dictionary
		if StringName(entry.get("mode", &"")) != MODE:
			continue
		var sample := _sample_from_entry(entry)
		if sample.is_empty():
			_rejected += 1
			continue
		var ship_id := StringName(sample.get("ship_id", &""))
		var history: Array = _samples.get(ship_id, [])
		if not history.is_empty() and int(sample.pose_tick) <= int((history.back() as Dictionary).pose_tick):
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


func has_samples(ship_id: StringName) -> bool:
	return not (_samples.get(ship_id, []) as Array).is_empty()


func latest_sample(ship_id: StringName) -> Dictionary:
	var history: Array = _samples.get(ship_id, [])
	return (history.back() as Dictionary).duplicate(true) if not history.is_empty() else {}


func get_tracked_ship_ids() -> Array:
	return _samples.keys()


func forget(ship_id: StringName) -> void:
	_samples.erase(ship_id)


func clear_replica() -> void:
	_samples.clear()
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


func _sample_from_entry(entry: Dictionary) -> Dictionary:
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
	return {
		"ship_id": ship_id,
		"pose_tick": int(pose_tick),
		"pilot_peer_id": int(entry.get("owner_peer_id", 1)),
		"position": position,
		"rotation": (rotation as Quaternion).normalized(),
		"velocity_world": velocity,
		"destroyed": bool(entry.get("destroyed", false)),
	}
