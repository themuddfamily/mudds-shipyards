class_name NetworkRemoteBodySimulation
extends Node

## Server-owned on-foot bodies for remote occupants of moving interiors.
##
## Before this node existed the authority published every identified occupant
## of a `MovingInteriorFrame` but simulated only its own player: a remote
## client's walking crewmate was a name with no body behind it. This node gives
## each admitted remote occupant a real body on the server — the production
## `PlayerController` scene, the same capsule, floor snap, step-up assist,
## cabin containment, seat and bunk transitions the host's own player has —
## registered with the craft's `MovingInteriorFrame` so the deck carries it,
## and driven only by the intents `NetworkMovementAuthority` has already
## accepted from that body's owner. The publication seam then reads this
## body's pose off the frame like any other occupant, so what every client is
## told is where the *simulation* put the crewmate, never where the crewmate
## claimed to be.
##
## ## Rules this node enforces
##
## * **One owner per body, one body per entity id.** An intent reaches a body
##   only through `consume_movement_intent()`, after the authority has checked
##   the sender is the registered owner, the generation is current and the
##   stream is ordered. A forged, stale or reordered packet never gets here.
## * **Hold, then freeze.** Owners stream below the physics rate, so the last
##   accepted intent keeps driving the body between sends. When no ordered
##   intent has arrived for `INTENT_HOLD_TICKS`, the body is frozen — its axes
##   cleared, so it decelerates to a stop where it stands — until one does.
##   This is the same gap rule the relationship stream applies going the other
##   way; a peer that has gone quiet stops moving rather than walking on.
## * **A seat is claimed by the body at it.** An interaction request is
##   resolved against the seats and bunks the *server* body's interaction area
##   overlaps, inside the same reach the host's own player has, through the
##   same `StationSeat` reservation, boarding and disembark transitions. The
##   request id is monotonic per stream and honoured once.
## * **A seat changes the ledger's mode, not just the body's posture.** The
##   moment a body claims a seat or bunk its movement avatar is put into
##   `NetworkMovementAuthority.MODE_SEATED`, and back `on_foot` when it stands.
##   A walking intent from the owner while seated is therefore refused *by the
##   ledger*, with a named reason that is counted in its audit, rather than
##   accepted and then ignored here.
## * **Bodies exist only while their occupant does.** Admission creates one,
##   release frees it; a peer disconnect, a session stop, a craft lost or a
##   whole-Main detach all release. Nothing here survives the session, so the
##   resident scene census is unchanged when nobody is aboard.
##
## The node owns no authority ledger: ownership, ordering and the tick window
## are `NetworkMovementAuthority`'s, seat reservation is `StationSeat`'s,
## occupancy is `MovingInteriorFrame`'s and publication is `GameFlow`'s.

const PlayerScene := preload("res://scenes/player/player.tscn")
const Intent := preload("res://scripts/network/network_movement_intent.gd")
const MovementAuthority := preload("res://scripts/network/network_movement_authority.gd")
const Relationship := preload("res://scripts/network/moving_interior_relationship.gd")

## Meta a remote body carries so the publisher can recognise a server-simulated
## occupant without holding a second roster.
const REMOTE_BODY_META: StringName = &"_network_remote_body"

## Server ticks a held intent survives without a newer ordered one. Three
## missed 15 Hz sends at 60 Hz; 200 ms of silence stops the body.
const INTENT_HOLD_TICKS := 12
## The host's own reach for a station seat, mirrored from `GameFlow`.
const SEAT_MAX_REACH := 3.25
const SEAT_TRANSITION_SECONDS := 0.45
const MAX_BODIES := 16

var _session: Node = null
var _bodies: Dictionary = {}
var _audit := {
	"admitted": 0,
	"released": 0,
	"intents_applied": 0,
	"gap_freezes": 0,
	"interactions": 0,
	"interactions_refused": 0,
	"seat_claims": 0,
	"seat_releases": 0,
	"occupancy_lost": 0,
	"mode_switches": 0,
	"mode_switches_refused": 0,
	"last_release_reason": &"",
}


func _exit_tree() -> void:
	# The subtree is leaving. Every frame under it clears its own occupants on
	# the way out and the session that admitted these bodies is being retired
	# in the same breath, so nothing is unregistered here — the records are
	# simply dropped and the bodies freed with the subtree.
	for entity_variant in _bodies.keys():
		var record := _bodies[entity_variant] as Dictionary
		var body_variant: Variant = record.get("body")
		if is_instance_valid(body_variant):
			(body_variant as Node).queue_free()
	_bodies.clear()


## Binds this simulation to the session adapter whose movement authority feeds
## it. A different adapter, or `null`, releases every body first.
func attach(session: Node) -> Dictionary:
	if session != null and not session.has_method(&"consume_movement_intent"):
		return _result(false, &"invalid_session")
	if _session == session:
		return _result(true, &"already_attached")
	if not _bodies.is_empty():
		release_all(&"session_replaced")
	_session = session
	return _result(session != null, &"attached" if session != null else &"detached")


func detach(reason: StringName = &"detached") -> Dictionary:
	release_all(reason)
	_session = null
	return _result(true, &"detached", {"reason": reason})


## Stands a server-owned body for `owner_peer_id` in the cabin of `craft`, at
## the craft's own stand pose, registered with `frame`. The caller has already
## established that the peer is admitted and aboard; this only builds and
## binds the body, and registers its movement avatar with the authority.
func admit(
	owner_peer_id: int,
	entity_id: StringName,
	craft: Node3D,
	frame: Node,
	frame_id: StringName,
	entity_generation: int = 1
) -> Dictionary:
	if not is_inside_tree():
		return _result(false, &"simulation_not_in_tree")
	if not is_instance_valid(_session) or not _session.is_server():
		return _result(false, &"authority_required")
	if owner_peer_id <= 1 or String(entity_id).is_empty() or entity_generation <= 0:
		return _result(false, &"invalid_body_identity")
	if _bodies.has(entity_id):
		return _result(false, &"duplicate_body", {"entity_id": entity_id})
	if _bodies.size() >= MAX_BODIES:
		return _result(false, &"body_capacity")
	if not is_instance_valid(craft) or not craft.is_inside_tree() \
			or not craft.has_method(&"get_in_flight_cabin_report"):
		return _result(false, &"invalid_craft")
	if not is_instance_valid(frame) or not frame.has_method(&"register_occupant"):
		return _result(false, &"invalid_frame")
	var report: Dictionary = craft.get_in_flight_cabin_report()
	if not bool(report.get("supported", false)):
		return _result(false, &"cabin_unavailable")
	var stand := report.get("stand_transform", craft.global_transform) as Transform3D
	stand = Transform3D(stand.basis.orthonormalized(), stand.origin)
	var body := PlayerScene.instantiate() as CharacterBody3D
	if body == null or not body.has_method(&"set_remote_drive_enabled"):
		if body != null:
			body.free()
		return _result(false, &"body_scene_unavailable")
	body.name = "RemoteBody_%s" % String(entity_id)
	add_child(body)
	body.set_remote_drive_enabled(true)
	body.global_transform = stand
	body.velocity = Vector3.ZERO
	body.reset_physics_interpolation()
	var registration: Dictionary = frame.register_occupant(body, {
		"require_inside_bounds": false,
		"registration_source": &"network_remote_body",
	})
	if not bool(registration.get("registered", false)):
		remove_child(body)
		body.free()
		return _result(false, StringName(registration.get("status", &"frame_rejected_body")))
	body.set_cabin_containment(craft, report.get("local_bounds", AABB()) as AABB, stand)
	var avatar: Dictionary = _session.register_avatar(
		owner_peer_id, entity_id, entity_generation, &"on_foot"
	)
	if not bool(avatar.get("accepted", false)):
		frame.unregister_occupant(body, false, &"avatar_rejected")
		remove_child(body)
		body.free()
		return _result(false, StringName(avatar.get("status", &"avatar_rejected")))
	body.set_meta(REMOTE_BODY_META, {
		"owner_peer_id": owner_peer_id,
		"entity_id": entity_id,
		"entity_generation": entity_generation,
	})
	body.boarding_completed.connect(_on_body_boarded.bind(entity_id))
	body.disembarking_completed.connect(_on_body_stood.bind(entity_id))
	_bodies[entity_id] = {
		"owner_peer_id": owner_peer_id,
		"entity_id": entity_id,
		"entity_generation": entity_generation,
		"body": body,
		"craft": craft,
		"frame": frame,
		"frame_id": frame_id,
		"last_intent_tick": -1,
		"frozen": false,
		"seat": null,
		"seat_state": &"standing",
		"avatar_mode": MovementAuthority.MODE_ON_FOOT,
		"last_interaction_id": 0,
		"intents_applied": 0,
	}
	_audit["admitted"] = int(_audit["admitted"]) + 1
	return _result(true, &"body_admitted", {
		"entity_id": entity_id,
		"entity_generation": entity_generation,
		"owner_peer_id": owner_peer_id,
		"body": body,
	})


func release(entity_id: StringName, reason: StringName = &"released") -> Dictionary:
	if not _bodies.has(entity_id):
		return _result(false, &"unknown_body", {"entity_id": entity_id})
	var record := _bodies[entity_id] as Dictionary
	_bodies.erase(entity_id)
	var body_variant: Variant = record.get("body")
	var frame_variant: Variant = record.get("frame")
	var seat_variant: Variant = record.get("seat")
	if is_instance_valid(body_variant):
		var body := body_variant as CharacterBody3D
		if is_instance_valid(seat_variant):
			(seat_variant as StationSeat).cancel_reservation(body)
		if is_instance_valid(frame_variant) and frame_variant.has_method(&"is_occupant_registered") \
				and frame_variant.is_occupant_registered(body):
			frame_variant.unregister_occupant(body, false, reason)
		if body.has_method(&"clear_cabin_containment"):
			body.clear_cabin_containment()
		if body.get_parent() != null:
			body.get_parent().remove_child(body)
		body.queue_free()
	if is_instance_valid(_session) and _session.is_server() and _session.is_inside_tree():
		_session.retire_avatar(entity_id, int(record.get("entity_generation", 1)))
	_audit["released"] = int(_audit["released"]) + 1
	_audit["last_release_reason"] = reason
	return _result(true, &"body_released", {"entity_id": entity_id, "reason": reason})


func release_peer(peer_id: int, reason: StringName = &"peer_released") -> Dictionary:
	var released: Array = []
	for entity_variant in _bodies.keys():
		if int((_bodies[entity_variant] as Dictionary).get("owner_peer_id", 0)) == peer_id:
			released.append(entity_variant)
	for entity_variant in released:
		release(StringName(entity_variant), reason)
	return _result(true, &"peer_bodies_released", {"released": released.size()})


func release_all(reason: StringName = &"released") -> Dictionary:
	var count := 0
	for entity_variant in _bodies.keys():
		release(StringName(entity_variant), reason)
		count += 1
	return _result(true, &"all_bodies_released", {"released": count})


## One authoritative tick. Consumes at most one accepted intent per body,
## applies it, resolves interaction requests and enforces the hold window.
## Called by the publisher before it reads poses, so the pose it publishes for
## this tick is the one the intent for this tick produced.
func advance(server_tick: int) -> Dictionary:
	if not is_instance_valid(_session) or not _session.is_server():
		return _result(false, &"authority_required")
	var applied := 0
	var frozen := 0
	var lost: Array = []
	for entity_variant in _bodies:
		var record := _bodies[entity_variant] as Dictionary
		if not _record_is_live(record):
			lost.append(entity_variant)
			continue
		var body := record.get("body") as CharacterBody3D
		var delivered: Dictionary = _session.consume_movement_intent(
			StringName(entity_variant), int(record.get("entity_generation", 1)), server_tick
		)
		if bool(delivered.get("accepted", false)):
			var intent = Intent.from_dictionary(delivered.get("intent", {}) as Dictionary)
			if StringName(record.get("seat_state", &"standing")) == &"standing":
				body.apply_remote_intent(
					intent.get_move_axis(), intent.get_look_yaw(),
					intent.is_running(), intent.has_jump_request()
				)
			record["last_intent_tick"] = server_tick
			record["frozen"] = false
			record["intents_applied"] = int(record.get("intents_applied", 0)) + 1
			applied += 1
			if intent.get_interaction_request_id() > int(record.get("last_interaction_id", 0)):
				record["last_interaction_id"] = intent.get_interaction_request_id()
				_handle_interaction(record)
		elif StringName(record.get("seat_state", &"standing")) == &"standing" \
				and not bool(record.get("frozen", false)) and int(record.get("last_intent_tick", -1)) >= 0 \
				and server_tick - int(record.get("last_intent_tick", -1)) > INTENT_HOLD_TICKS:
			# The hold window is an on-foot rule. A seated body's owner may be
			# streaming intents the ledger refuses by mode, and that silence is
			# the ledger's refusal count, not a delivery gap.
			body.clear_remote_intent()
			record["frozen"] = true
			frozen += 1
			_audit["gap_freezes"] = int(_audit["gap_freezes"]) + 1
	for entity_variant in lost:
		_audit["occupancy_lost"] = int(_audit["occupancy_lost"]) + 1
		release(StringName(entity_variant), &"occupancy_lost")
	_audit["intents_applied"] = int(_audit["intents_applied"]) + applied
	return _result(true, &"advanced", {
		"server_tick": server_tick, "applied": applied, "frozen": frozen, "lost": lost.size(),
	})


func has_body(entity_id: StringName) -> bool:
	return _bodies.has(entity_id)


func get_body(entity_id: StringName) -> CharacterBody3D:
	var body_variant: Variant = (_bodies.get(entity_id, {}) as Dictionary).get("body")
	return body_variant as CharacterBody3D if is_instance_valid(body_variant) else null


func get_body_entity_ids() -> Array:
	return _bodies.keys()


func get_body_count() -> int:
	return _bodies.size()


## What the body is doing, on `NetworkMovingInteriorRelationship`'s scale.
func get_occupancy_state(entity_id: StringName) -> int:
	var body := get_body(entity_id)
	if body == null:
		return Relationship.STATE_WALKING
	if body.is_sleeping():
		return Relationship.STATE_SLEEPING
	if body.is_seated():
		return Relationship.STATE_SEATED
	return Relationship.STATE_WALKING


## Read-only view of one body's record: identity, hold state and seat state.
func get_body_record(entity_id: StringName) -> Dictionary:
	var record := _bodies.get(entity_id, {}) as Dictionary
	if record.is_empty():
		return {}
	return {
		"owner_peer_id": int(record.get("owner_peer_id", 0)),
		"entity_id": entity_id,
		"entity_generation": int(record.get("entity_generation", 1)),
		"frame_id": StringName(record.get("frame_id", &"")),
		"last_intent_tick": int(record.get("last_intent_tick", -1)),
		"frozen": bool(record.get("frozen", false)),
		"seat_state": StringName(record.get("seat_state", &"standing")),
		"avatar_mode": StringName(record.get("avatar_mode", MovementAuthority.MODE_ON_FOOT)),
		"seated": is_instance_valid(record.get("seat")),
		"last_interaction_id": int(record.get("last_interaction_id", 0)),
		"intents_applied": int(record.get("intents_applied", 0)),
		"occupancy_state": get_occupancy_state(entity_id),
	}


static func is_remote_body(node: Node) -> bool:
	return is_instance_valid(node) and node.has_meta(REMOTE_BODY_META)


static func get_remote_body_identity(node: Node) -> Dictionary:
	if not is_remote_body(node):
		return {}
	return (node.get_meta(REMOTE_BODY_META, {}) as Dictionary).duplicate(true)


func get_audit() -> Dictionary:
	var audit := _audit.duplicate(true)
	audit["bodies"] = _bodies.size()
	audit["attached"] = is_instance_valid(_session)
	audit["intent_hold_ticks"] = INTENT_HOLD_TICKS
	audit["owns_movement_authority"] = false
	audit["owns_seat_authority"] = false
	audit["owns_occupancy"] = false
	return audit


# --- interaction ------------------------------------------------------------


func _handle_interaction(record: Dictionary) -> void:
	_audit["interactions"] = int(_audit["interactions"]) + 1
	match StringName(record.get("seat_state", &"standing")):
		&"standing":
			_try_sit(record)
		&"seated":
			_stand(record)
		_:
			_audit["interactions_refused"] = int(_audit["interactions_refused"]) + 1


## The same rule the host's own player is held to: the nearest available seat
## or bunk of *this* craft that the body's interaction area actually overlaps,
## within reach of the body's own interaction origin. Nothing is claimed by
## name, and a seat across the cabin is out of reach however the request is
## phrased.
func _try_sit(record: Dictionary) -> void:
	var body := record.get("body") as CharacterBody3D
	var craft := record.get("craft") as Node3D
	var origin: Vector3 = body.get_interaction_origin()
	var best: StationSeat = null
	var best_distance := INF
	for candidate in body.get_nearby_interactables():
		if not candidate is StationSeat:
			continue
		var seat := candidate as StationSeat
		if not seat.is_available() or not _seat_belongs_to_craft(seat, craft):
			continue
		var distance := origin.distance_to(seat.get_entry_transform().origin)
		if distance > SEAT_MAX_REACH or distance >= best_distance:
			continue
		best = seat
		best_distance = distance
	if best == null or not best.try_reserve(body):
		_audit["interactions_refused"] = int(_audit["interactions_refused"]) + 1
		return
	body.clear_remote_intent()
	if not body.begin_boarding(
		best.get_entry_transform(), best.get_seat_anchor(), SEAT_TRANSITION_SECONDS, craft
	):
		best.cancel_reservation(body)
		_audit["interactions_refused"] = int(_audit["interactions_refused"]) + 1
		return
	record["seat"] = best
	record["seat_state"] = &"sitting"
	# The claim is the moment the ledger's mode changes: from here until the
	# body stands again, a walking intent is refused by name at the authority.
	_set_avatar_mode(record, MovementAuthority.MODE_SEATED)


func _stand(record: Dictionary) -> void:
	var body := record.get("body") as CharacterBody3D
	var seat_variant: Variant = record.get("seat")
	if not is_instance_valid(seat_variant):
		record["seat"] = null
		record["seat_state"] = &"standing"
		return
	var seat := seat_variant as StationSeat
	if not seat.begin_release(body):
		_audit["interactions_refused"] = int(_audit["interactions_refused"]) + 1
		return
	var was_bunk := seat is ShipBunk
	if was_bunk:
		body.set_sleeping_context(false)
	else:
		body.set_station_seated_context(false)
	if not body.begin_disembark(
		seat.get_exit_transform(), SEAT_TRANSITION_SECONDS, record.get("craft") as Node3D
	):
		seat.finish_transition(body)
		if was_bunk:
			body.set_sleeping_context(true)
		else:
			body.set_station_seated_context(true)
		_audit["interactions_refused"] = int(_audit["interactions_refused"]) + 1
		return
	record["seat_state"] = &"rising"


func _on_body_boarded(entity_id: StringName) -> void:
	var record := _bodies.get(entity_id, {}) as Dictionary
	if record.is_empty() or StringName(record.get("seat_state", &"")) != &"sitting":
		return
	var body := record.get("body") as CharacterBody3D
	var seat_variant: Variant = record.get("seat")
	if not is_instance_valid(body) or not is_instance_valid(seat_variant):
		record["seat"] = null
		record["seat_state"] = &"standing"
		_set_avatar_mode(record, MovementAuthority.MODE_ON_FOOT)
		return
	var seat := seat_variant as StationSeat
	seat.finish_transition(body)
	if seat is ShipBunk:
		body.set_sleeping_context(true)
	else:
		body.set_station_seated_context(true)
	record["seat_state"] = &"seated"
	_audit["seat_claims"] = int(_audit["seat_claims"]) + 1


func _on_body_stood(entity_id: StringName) -> void:
	var record := _bodies.get(entity_id, {}) as Dictionary
	if record.is_empty() or StringName(record.get("seat_state", &"")) != &"rising":
		return
	var body := record.get("body") as CharacterBody3D
	var seat_variant: Variant = record.get("seat")
	if is_instance_valid(seat_variant) and is_instance_valid(body):
		(seat_variant as StationSeat).release(body)
	record["seat"] = null
	record["seat_state"] = &"standing"
	# Back on foot: the ledger accepts walking again, and the hold window
	# starts from the first intent it delivers rather than from the seat.
	record["last_intent_tick"] = -1
	record["frozen"] = false
	_set_avatar_mode(record, MovementAuthority.MODE_ON_FOOT)
	_audit["seat_releases"] = int(_audit["seat_releases"]) + 1


## Mirrors the body's physical seat result into the movement ledger. The ledger
## is the adapter's; this only reports what the seat authority already did.
func _set_avatar_mode(record: Dictionary, mode: StringName) -> void:
	if StringName(record.get("avatar_mode", &"")) == mode:
		return
	if not is_instance_valid(_session) or not _session.is_server() \
			or not _session.has_method(&"set_avatar_mode"):
		_audit["mode_switches_refused"] = int(_audit["mode_switches_refused"]) + 1
		return
	var result: Dictionary = _session.set_avatar_mode(
		StringName(record.get("entity_id", &"")), int(record.get("entity_generation", 1)), mode
	)
	if bool(result.get("accepted", false)):
		record["avatar_mode"] = mode
		_audit["mode_switches"] = int(_audit["mode_switches"]) + 1
	else:
		_audit["mode_switches_refused"] = int(_audit["mode_switches_refused"]) + 1


func _seat_belongs_to_craft(seat: StationSeat, craft: Node3D) -> bool:
	if not is_instance_valid(craft):
		return false
	if seat is ShipBunk:
		return (seat as ShipBunk).get_ship() == craft
	return craft.is_ancestor_of(seat)


func _record_is_live(record: Dictionary) -> bool:
	var body_variant: Variant = record.get("body")
	var craft_variant: Variant = record.get("craft")
	var frame_variant: Variant = record.get("frame")
	if not is_instance_valid(body_variant) or not (body_variant as Node).is_inside_tree():
		return false
	if not is_instance_valid(craft_variant) or not (craft_variant as Node).is_inside_tree():
		return false
	if craft_variant.has_method(&"is_destroyed") and craft_variant.is_destroyed():
		return false
	if not is_instance_valid(frame_variant) or not frame_variant.is_occupant_registered(body_variant):
		return false
	return true


func _result(accepted: bool, status: StringName, extra: Dictionary = {}) -> Dictionary:
	var result := {"accepted": accepted, "status": status}
	result.merge(extra)
	return result
