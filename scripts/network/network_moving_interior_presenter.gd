class_name NetworkMovingInteriorPresenter
extends Node3D

## Draws the crew members a non-authority peer receives over the moving-interior
## relationship stream.
##
## This is the production consumer of `NetworkMovingInteriorReplica`. Every
## rendered frame it samples each tracked relationship at its own render time,
## lets `NetworkMovingInteriorReplicaBinding` compose that frame-local pose with
## the live `MovingInteriorFrame` transform, and moves one remote avatar node
## per occupant. A crew member walking the aisle of a Halyard in flight is
## therefore drawn moving *with* the cabin, inside the cabin, on every other
## client.
##
## ## What this node does not own
##
## Nothing authoritative. It never publishes, never accepts a relationship,
## never registers occupancy, never touches a physics body, and never moves the
## local player. The avatars it spawns are plain `Node3D` visuals; the server
## remains the only source of a pose and `NetworkEnetSessionAdapter` remains the
## only thing that decides which relationships exist.
##
## ## Timeline
##
## `NetworkMovingInteriorReplica` interpolates on a real-seconds axis (see its
## own Timeline section). Relationships arrive stamped with a `server_tick`, so
## this presenter anchors on the newest tick the adapter has released,
## converts it once through `NetworkEnetSessionAdapter.moving_interior_tick_to_seconds()`,
## and adds the real time elapsed since that tick was first observed. That sum
## is the render time handed to the replica, which is what lets a pose advance
## smoothly between two arrivals instead of stepping from packet to packet.
##
## ## Allocation
##
## Steady state — every tracked entity already drawn, no arrivals or departures
## — allocates nothing in this node: no scene-tree churn, no rebinding, and no
## container growth. The per-frame path polls one int
## (`get_moving_interior_presentation_entity_count()`), iterates its own
## dictionary in place, and calls `apply_moving_interior_replica()`. The
## allocating reconcile runs only when that count changes, when a frame is
## registered or retired, or when the migration generation moves.
## `get_presentation_audit()["reconcile_count"]` is the witness.

const PilotVisualScene := preload("res://scenes/player/pilot_skinned_presentation.tscn")
const PilotFallbackBuilder := preload("res://scripts/player/pilot_fallback_presentation_builder.gd")
const Relationship := preload("res://scripts/network/moving_interior_relationship.gd")

const MAX_TRACKED_AVATARS := 64

## The imported suit faces +Z in its own space while the canonical avatar
## forward is -Z, so its mount carries the same PI yaw offset `PlayerController`
## applies to the local body. The generated recovery suit is authored on the
## canonical axis and takes no offset.
const IMPORTED_VISUAL_FACING_YAW_OFFSET := PI

## Fallback-suit limb pivots, matching `scenes/player/player.tscn` so a remote
## crew member falling back to the recovery suit has the same proportions as the
## local one.
const FALLBACK_LIMB_PIVOTS := [
	{"name": &"LeftArm", "position": Vector3(-0.46, 1.43, 0.0), "rotation": Vector3(0.0, 0.0, -0.08)},
	{"name": &"RightArm", "position": Vector3(0.46, 1.43, 0.0), "rotation": Vector3(0.0, 0.0, 0.08)},
	{"name": &"LeftLeg", "position": Vector3(-0.17, 0.73, 0.0), "rotation": Vector3.ZERO},
	{"name": &"RightLeg", "position": Vector3(0.17, 0.73, 0.0), "rotation": Vector3.ZERO},
]

## How far the render clock may run past the newest accepted arrival before it
## stops accumulating. The replica clamps its own extrapolation well inside
## this; the cap only keeps the sample time finite and bounded across a long
## delivery stall.
const MAX_CLOCK_RUNOUT_SECONDS := 2.0

## Frame-local speed, in metres per second, above which a drawn crew member is
## animated as walking rather than standing. Presentation only: the clip choice
## is read off the poses the server already published.
const WALK_ANIMATION_SPEED := 0.35
const RUN_ANIMATION_SPEED := 4.2
## Reciprocal time constant of the speed the clip is chosen from. The pose only
## moves when a packet arrives or while the replica extrapolates between two, so
## the raw per-frame step is spiky by construction; smoothing it over about an
## eighth of a second is what keeps a steadily walking crew member on the walk
## clip instead of flickering between walk and run at every arrival boundary.
const ANIMATION_SPEED_SMOOTHING := 8.0

## Clip preference per published occupancy state, best first. The authority says
## what an occupant is *doing*; speed alone cannot, because a crewmate asleep in
## a bunk and one standing still beside it publish the same zero-velocity pose.
## Each list falls back down to a clip the imported suit definitely has, so a
## visual without a dedicated sleep or sit clip still draws a settled body
## rather than nothing.
const SECURED_OCCUPANCY_CLIPS := {
	Relationship.STATE_SEATED: [&"sit", &"seated", &"idle"],
	Relationship.STATE_SLEEPING: [&"sleep", &"rest", &"idle"],
}

var _session: Node = null
var _attached := false
var _reduced_motion := false
var _frames: Dictionary = {}
var _avatars: Dictionary = {}
var _local_entity_ids: Dictionary = {}
var _observed_entity_count := -1
var _generation := 0
var _dirty := true
var _anchor_server_tick := -1
var _anchor_seconds := 0.0
var _elapsed_since_anchor := 0.0
var _reconcile_count := 0
var _spawn_count := 0
var _release_count := 0
var _applied_count := 0
var _last_release_reason: StringName = &""


func _ready() -> void:
	set_process(true)


## A whole-Main detach takes this node and every avatar under it out of the
## tree, and `MovingInteriorFrame` deliberately drops its own occupants on the
## way out. Releasing here rather than trusting the subtree to come back intact
## is what guarantees no orphan avatar survives a re-entry: the next reconcile
## rebuilds from the relationships the adapter is actually still tracking.
func _exit_tree() -> void:
	_release_all_avatars(&"presenter_detached")
	_dirty = true


func _enter_tree() -> void:
	_dirty = true
	_observed_entity_count = -1


## Binds this presenter to the session adapter whose replica it draws. Passing a
## different adapter, or `null`, releases everything drawn for the previous one.
func attach(session: Node) -> Dictionary:
	if session != null and not session.has_method(&"apply_moving_interior_replica"):
		return _result(false, &"invalid_session")
	# Re-attaching the same live adapter is a no-op. GameFlow calls this again on
	# every peer admission, and resetting the cursors there would drop and
	# respawn every crew member already on screen each time somebody joins.
	if _attached and _session == session and is_instance_valid(session):
		return _result(true, &"already_attached")
	if _session != session:
		_release_all_avatars(&"session_replaced")
		_disconnect_session()
	_session = session
	_attached = session != null and is_instance_valid(session)
	_observed_entity_count = -1
	_generation = 0
	_dirty = true
	_reset_clock()
	if _attached:
		_connect_session()
	return _result(_attached, &"attached" if _attached else &"detached")


func detach(reason: StringName = &"detached") -> Dictionary:
	_release_all_avatars(reason)
	_disconnect_session()
	_session = null
	_attached = false
	_observed_entity_count = -1
	_dirty = true
	_reset_clock()
	return _result(true, &"detached", {"reason": reason})


## Registers the live node a published `parent_frame_id` resolves to — for the
## Halyard and the Jovian that is the craft itself, the same node their
## `MovingInteriorFrame` names as its moving frame, and therefore the very
## `CharacterBody3D` the poses on the wire are expressed against. Its transform
## is only read. A relationship whose frame is not registered, or whose frame
## generation does not match, is not drawn: a crew member with no cabin to
## stand in has no correct place on screen.
func register_frame(frame_id: StringName, frame_generation: int, frame_node: Node3D) -> Dictionary:
	if frame_id.is_empty() or frame_generation < 0:
		return _result(false, &"invalid_frame_identity")
	if not is_instance_valid(frame_node):
		return _result(false, &"invalid_frame_node")
	var known: Dictionary = _frames.get(frame_id, {}) as Dictionary
	if int(known.get("generation", -1)) == frame_generation and known.get("node") == frame_node:
		return _result(true, &"frame_unchanged", {"frame_id": frame_id})
	_frames[frame_id] = {"generation": frame_generation, "node": frame_node}
	_dirty = true
	return _result(true, &"frame_registered", {"frame_id": frame_id})


func unregister_frame(frame_id: StringName) -> Dictionary:
	if not _frames.has(frame_id):
		return _result(true, &"frame_unknown", {"frame_id": frame_id})
	_frames.erase(frame_id)
	_dirty = true
	return _result(true, &"frame_unregistered", {"frame_id": frame_id})


## Entity ids this peer draws itself. The local crew member is simulated by the
## local `PlayerController`; drawing the server's echo of them as well would put
## a second body in the cabin.
func set_local_entity_ids(entity_ids: Array) -> Dictionary:
	_local_entity_ids.clear()
	for entity_variant in entity_ids:
		var entity_id := StringName(entity_variant)
		if not entity_id.is_empty():
			_local_entity_ids[entity_id] = true
	_dirty = true
	return _result(true, &"local_entities_set", {"count": _local_entity_ids.size()})


## Accessibility seam, matching the other presenters: the value is owned by
## `RuntimeSettings` and only read here. With reduced motion on, the presenter
## samples at the newest accepted arrival instead of running its render clock
## ahead of it, so a remote body never speculates forward and then corrects —
## it simply follows the poses the server actually sent, a little behind.
func set_reduced_motion(enabled: bool) -> Dictionary:
	_reduced_motion = enabled
	return _result(true, &"reduced_motion_applied", {"reduced_motion": _reduced_motion})


func apply_accessibility_descriptor(descriptor: Dictionary) -> Dictionary:
	return set_reduced_motion(bool(descriptor.get("reduced_motion", false)))


func get_avatar_node(entity_id: StringName) -> Node3D:
	var record: Dictionary = _avatars.get(entity_id, {}) as Dictionary
	var node_variant: Variant = record.get("root")
	return node_variant as Node3D if is_instance_valid(node_variant) else null


func get_drawn_entity_ids() -> Array:
	return _avatars.keys()


## The motion clip the drawn crew member is currently playing, or `&""`. Chosen
## from the smoothed frame-local speed of the poses the server published.
func get_avatar_animation_clip(entity_id: StringName) -> StringName:
	return StringName((_avatars.get(entity_id, {}) as Dictionary).get("clip", &""))


## The occupancy state the drawn body is currently being posed for, as the
## authority published it. Presentation read-through, not a second record.
func get_avatar_occupancy_state(entity_id: StringName) -> int:
	if not _avatars.has(entity_id) or not is_instance_valid(_session):
		return Relationship.STATE_WALKING
	return int(_session.get_moving_interior_occupancy_state(entity_id))


func get_presentation_audit() -> Dictionary:
	return {
		"attached": _attached,
		"drawn_entities": _avatars.size(),
		"registered_frames": _frames.size(),
		"local_entities": _local_entity_ids.size(),
		"reduced_motion": _reduced_motion,
		"migration_generation": _generation,
		"anchor_server_tick": _anchor_server_tick,
		"reconcile_count": _reconcile_count,
		"spawn_count": _spawn_count,
		"release_count": _release_count,
		"applied_count": _applied_count,
		"last_release_reason": _last_release_reason,
		"owns_physics_authority": false,
		"owns_seat_authority": false,
		"owns_movement_authority": false,
	}


func _process(delta: float) -> void:
	if not _attached:
		return
	if not is_instance_valid(_session):
		_release_all_avatars(&"session_lost")
		_attached = false
		return
	if _session.is_server():
		# The authority simulates these bodies directly; it has no replica to
		# draw and must never be handed one.
		if not _avatars.is_empty():
			_release_all_avatars(&"authority_peer")
		return
	var count := int(_session.get_moving_interior_presentation_entity_count())
	if _dirty or count != _observed_entity_count:
		_reconcile(count)
	_advance_clock(delta)
	var sample_time := _sample_time()
	for entity_variant in _avatars:
		var record: Dictionary = _avatars[entity_variant] as Dictionary
		var applied: Dictionary = _session.apply_moving_interior_replica(
			StringName(entity_variant), sample_time
		)
		if bool(applied.get("accepted", false)):
			_applied_count += 1
			_advance_avatar_animation(
				record,
				applied,
				delta,
				int(_session.get_moving_interior_occupancy_state(StringName(entity_variant)))
			)


## Discovery and lifecycle. Deliberately the only allocating path: it runs when
## the tracked set changes, a frame is registered or retired, or the migration
## generation moves — never on a steady frame.
func _reconcile(count: int) -> void:
	_dirty = false
	_reconcile_count += 1
	var generation := int(_session.get_moving_interior_presentation_generation())
	if generation != _generation:
		_release_all_avatars(&"migration")
		_generation = generation
		_reset_clock()
	var entities: Array = _session.get_moving_interior_presentation_entities()
	var seen: Dictionary = {}
	for entity_variant in entities:
		var entity := entity_variant as Dictionary
		var entity_id := StringName(entity.get("entity_id", &""))
		if entity_id.is_empty() or _local_entity_ids.has(entity_id):
			continue
		var frame_id := StringName(entity.get("parent_frame_id", &""))
		var frame_generation := int(entity.get("parent_frame_generation", 0))
		var frame := _resolve_frame(frame_id, frame_generation)
		if frame == null:
			_release_avatar(entity_id, &"frame_unregistered")
			continue
		var entity_generation := maxi(1, int(entity.get("entity_generation", 1)))
		if not _avatars.has(entity_id) and _avatars.size() >= MAX_TRACKED_AVATARS:
			continue
		seen[entity_id] = true
		_bind_avatar(entity_id, entity_generation, frame, frame_generation)
	for entity_variant in _avatars.keys():
		var entity_id := StringName(entity_variant)
		if not seen.has(entity_id):
			# The adapter already dropped this entity: a release tombstone, a
			# peer disconnect, a resync that retired it, or a migration. The
			# crew member stops being drawn in the same frame.
			_release_avatar(entity_id, &"released")
	_observed_entity_count = count


func _resolve_frame(frame_id: StringName, frame_generation: int) -> Node3D:
	if frame_id.is_empty() or not _frames.has(frame_id):
		return null
	var record: Dictionary = _frames[frame_id] as Dictionary
	if int(record.get("generation", -1)) != frame_generation:
		return null
	var node_variant: Variant = record.get("node")
	if not is_instance_valid(node_variant):
		_frames.erase(frame_id)
		return null
	return node_variant as Node3D


func _bind_avatar(
	entity_id: StringName,
	entity_generation: int,
	frame: Node3D,
	frame_generation: int
) -> void:
	var record: Dictionary = _avatars.get(entity_id, {}) as Dictionary
	if record.is_empty():
		record = _spawn_avatar(entity_id)
		if record.is_empty():
			return
		_avatars[entity_id] = record
	elif not is_instance_valid(record.get("root")):
		_release_avatar(entity_id, &"avatar_lost")
		return
	elif int(record.get("entity_generation", 0)) == entity_generation \
			and int(record.get("frame_generation", -1)) == frame_generation \
			and record.get("frame_node") == frame:
		return
	var bound: Dictionary = _session.bind_moving_interior_replica(
		entity_id, entity_generation, record.get("root") as Node3D, frame, frame_generation
	)
	if not bool(bound.get("accepted", false)):
		_release_avatar(entity_id, StringName(bound.get("status", &"bind_rejected")))
		return
	record["entity_generation"] = entity_generation
	record["frame_generation"] = frame_generation
	record["frame_node"] = frame
	_avatars[entity_id] = record


## One remote crew member, built from the production pilot visual. The imported
## Blender suit is the same scene the local player wears; if it cannot build,
## the same generated recovery suit `PlayerController` falls back to is used
## instead, so a crew member is never invisible in the cabin.
func _spawn_avatar(entity_id: StringName) -> Dictionary:
	var root := Node3D.new()
	root.name = "RemoteCrew_%s" % String(entity_id)
	var pivot := Node3D.new()
	pivot.name = "BodyPivot"
	root.add_child(pivot)
	add_child(root)
	_spawn_count += 1
	var visual := PilotVisualScene.instantiate() as Node3D
	var imported := false
	var animation_player: AnimationPlayer = null
	if visual != null:
		pivot.add_child(visual)
		if visual.has_method(&"get_visual_root") and visual.get_visual_root() != null:
			imported = true
			pivot.rotation = Vector3(0.0, IMPORTED_VISUAL_FACING_YAW_OFFSET, 0.0)
			if visual.has_method(&"get_animation_player"):
				animation_player = visual.get_animation_player()
		else:
			pivot.remove_child(visual)
			visual.queue_free()
			visual = null
	if not imported:
		_build_fallback_suit(pivot)
	return {
		"root": root,
		"pivot": pivot,
		"visual": visual,
		"imported": imported,
		"animation_player": animation_player,
		"entity_generation": 0,
		"frame_generation": -1,
		"frame_node": null,
		"last_origin": Vector3.ZERO,
		"has_last_origin": false,
		"speed": 0.0,
		"clip": &"",
	}


func _build_fallback_suit(pivot: Node3D) -> void:
	var limbs: Array[Node3D] = []
	for descriptor_variant in FALLBACK_LIMB_PIVOTS:
		var descriptor := descriptor_variant as Dictionary
		var limb := Node3D.new()
		limb.name = String(descriptor.get("name", &"Limb"))
		limb.position = descriptor.get("position", Vector3.ZERO)
		limb.rotation = descriptor.get("rotation", Vector3.ZERO)
		pivot.add_child(limb)
		limbs.append(limb)
	var builder := PilotFallbackBuilder.new()
	builder.create_materials()
	builder.build(pivot, limbs[0], limbs[1], limbs[2], limbs[3])


## Presentation-only clip selection, read off the poses the server published.
## The clip is only changed when it actually changes, so a steadily walking
## crew member costs no call at all.
##
## The speed is measured in the *cabin's* coordinates, never the world's: a crew
## member standing still in a Halyard under way is crossing the sky at flight
## speed, and a world-space reading would animate every passenger on board as
## sprinting for the whole leg.
func _advance_avatar_animation(
	record: Dictionary, applied: Dictionary, delta: float, occupancy_state: int
) -> void:
	if not bool(record.get("imported", false)):
		return
	var player_variant: Variant = record.get("animation_player")
	if not is_instance_valid(player_variant):
		return
	var local_variant: Variant = applied.get("local_transform")
	if not local_variant is Transform3D:
		return
	var origin := (local_variant as Transform3D).origin
	var speed := float(record.get("speed", 0.0))
	if bool(record.get("has_last_origin", false)) and delta > 0.0:
		var previous: Vector3 = record.get("last_origin", origin)
		var instant := previous.distance_to(origin) / delta
		speed = lerpf(speed, instant, clampf(delta * ANIMATION_SPEED_SMOOTHING, 0.0, 1.0))
	record["speed"] = speed
	record["last_origin"] = origin
	record["has_last_origin"] = true
	var clip: StringName = &"idle"
	if SECURED_OCCUPANCY_CLIPS.has(occupancy_state):
		# A secured occupant is where the authority put them. Their remaining
		# frame-local motion is the seat or bunk being carried, not a stride, so
		# the speed reading is deliberately ignored here: a pilot in a seat during
		# a hard turn must not be animated as sprinting on the spot.
		clip = _first_available_clip(
			player_variant as AnimationPlayer, SECURED_OCCUPANCY_CLIPS[occupancy_state] as Array
		)
	elif speed >= RUN_ANIMATION_SPEED:
		clip = &"run"
	elif speed >= WALK_ANIMATION_SPEED:
		clip = &"walk"
	if StringName(record.get("clip", &"")) == clip:
		return
	record["clip"] = clip
	var animation_player := player_variant as AnimationPlayer
	if animation_player.has_animation(String(clip)):
		animation_player.play(String(clip))


## First clip in `candidates` the suit actually has, or the last one as the
## honest name of what was asked for even when nothing can play it.
func _first_available_clip(
	animation_player: AnimationPlayer, candidates: Array
) -> StringName:
	for candidate_variant in candidates:
		var candidate := StringName(candidate_variant)
		if animation_player.has_animation(String(candidate)):
			return candidate
	return StringName(candidates[candidates.size() - 1]) if not candidates.is_empty() else &"idle"


func _release_avatar(entity_id: StringName, reason: StringName) -> void:
	if not _avatars.has(entity_id):
		return
	var record: Dictionary = _avatars[entity_id] as Dictionary
	_avatars.erase(entity_id)
	_release_count += 1
	_last_release_reason = reason
	# Only the presentation binding is cleared. Which relationships exist stays
	# the adapter's business: detaching the replica sample here would drop a
	# crew member the server is still publishing, and the next arrival would
	# spawn the avatar again — a spawn/free cycle every tick.
	if is_instance_valid(_session):
		_session.unbind_moving_interior_replica(entity_id)
	var root_variant: Variant = record.get("root")
	if is_instance_valid(root_variant):
		var root := root_variant as Node3D
		if root.get_parent() != null:
			root.get_parent().remove_child(root)
		root.queue_free()


func _release_all_avatars(reason: StringName) -> void:
	for entity_variant in _avatars.keys():
		_release_avatar(StringName(entity_variant), reason)
	_avatars.clear()
	_observed_entity_count = -1


func _advance_clock(delta: float) -> void:
	var latest := int(_session.get_moving_interior_latest_server_tick())
	if latest != _anchor_server_tick:
		# Re-anchoring on any change, not only an advance, is deliberate. A
		# reconnect to the same host resumes on the same migration generation
		# with a server tick that may restart lower; an anchor that only ever
		# moved forward would then sit permanently ahead of every arrival and
		# pin the replica at its extrapolation horizon for the rest of the
		# session.
		if latest < 0:
			_reset_clock()
			return
		_anchor_server_tick = latest
		_anchor_seconds = float(_session.moving_interior_tick_to_seconds(latest))
		_elapsed_since_anchor = 0.0
		return
	_elapsed_since_anchor = minf(_elapsed_since_anchor + maxf(0.0, delta), MAX_CLOCK_RUNOUT_SECONDS)


func _sample_time() -> float:
	if _reduced_motion:
		return _anchor_seconds
	return _anchor_seconds + _elapsed_since_anchor


func _reset_clock() -> void:
	_anchor_server_tick = -1
	_anchor_seconds = 0.0
	_elapsed_since_anchor = 0.0


func _connect_session() -> void:
	if not is_instance_valid(_session):
		return
	if _session.has_signal(&"session_stopped") \
			and not _session.session_stopped.is_connected(_on_session_stopped):
		_session.session_stopped.connect(_on_session_stopped)


func _disconnect_session() -> void:
	if not is_instance_valid(_session):
		return
	if _session.has_signal(&"session_stopped") \
			and _session.session_stopped.is_connected(_on_session_stopped):
		_session.session_stopped.disconnect(_on_session_stopped)


## A disconnect is not silence: everything this peer was drawing stops being
## drawn in the same frame the session ends, rather than leaving motionless
## bodies standing in a cabin nobody is flying any more.
func _on_session_stopped(reason: StringName) -> void:
	_release_all_avatars(reason)
	_generation = 0
	_dirty = true
	_reset_clock()


func _result(accepted: bool, status: StringName, extra: Dictionary = {}) -> Dictionary:
	var result := {"accepted": accepted, "status": status}
	result.merge(extra)
	return result
