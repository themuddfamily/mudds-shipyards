class_name NetworkRemotePilotCommandSource
extends ShipCommandSource

## The host-side helm of a craft a remote peer is flying.
##
## A peer the boarding ledger has seated in a craft's pilot seat streams its
## helm to the host as ordinary movement intents on the one existing movement
## RPC, addressed to the craft's ship id. `NetworkRemoteShipCommandSource`
## validates them (owner, generation, stream order, tick window, axis bound,
## rate) and hands the host one accepted intent per physics tick; this source
## turns the latest one into the `ShipCommand` the host's own `HeroShip` flies
## from, through the ship's existing `set_command_source()` producer seam. The
## host therefore simulates the craft its crew is standing in, instead of the
## pilot flying a private copy that nobody aboard can feel move.
##
## Commands are sample-and-hold between deliveries (the client streams at
## `SEND_INTERVAL_TICKS`), and a helm that goes silent for `HOLD_TICKS` falls
## to neutral: a dropped pilot leaves a coasting craft, never one stuck at full
## throttle. Held flight axes/boost/brake/hover and ordered barrel-roll presses
## travel. Landing presses request the host's existing per-craft berth assist;
## the host still decides capture, reservation and completion. Exit and fire
## remain separate GameFlow decisions.
##
## Wire mapping (encode on the pilot's client, decode here; both halves live in
## this file so they cannot drift apart):
##   move_axis  = (yaw, throttle), scaled into the unit disc the intent allows
##   look_yaw   = roll  (radians field, value in [-1, 1])
##   look_pitch = pitch (radians field, value in [-1, 1])
##   run / crouch / jump = boost / brake / hover
##   interaction_request_id = monotonic barrel-roll request in pilot mode only
##   board_request / boarding_target_id = landing request / "pilot_landing_<id>"
## These last fields are consumed only by the registered pilot helm route.
## They neither name a berth nor request an on-foot boarding transaction.

const MovementIntent := preload("res://scripts/network/network_movement_intent.gd")

## Client send cadence, in physics ticks (15 Hz at 60 Hz physics).
const SEND_INTERVAL_TICKS := 4
## Physics ticks a delivered command is held before the helm falls to neutral.
const HOLD_TICKS := 30

var _controls: Dictionary = {}
var _age_ticks := HOLD_TICKS + 1
var _pilot_peer_id := 0
var _ship_id: StringName = &""
var _delivered := 0
var _roll_retired_stream := -1
var _roll_wire_stream := -1
var _roll_wire_sequence := -1
var _roll_request_id := 0
var _roll_pending := false
var _roll_delivered := 0
var _landing_request_id := 0
var _landing_pending := false


func bind_pilot(pilot_peer_id: int, ship_id: StringName, previous_roll_receipt: Dictionary = {}) -> void:
	_pilot_peer_id = pilot_peer_id
	_ship_id = ship_id
	_controls = {}
	_age_ticks = HOLD_TICKS + 1
	_roll_retired_stream = int(previous_roll_receipt.get("stream", -1))
	_roll_wire_stream = _roll_retired_stream
	_roll_wire_sequence = int(previous_roll_receipt.get("sequence", -1))
	_roll_request_id = int(previous_roll_receipt.get("request", 0))
	_roll_pending = false
	_landing_request_id = int(previous_roll_receipt.get("landing_request", 0))
	_landing_pending = false


func get_roll_receipt() -> Dictionary:
	return {
		"stream": _roll_wire_stream, "sequence": _roll_wire_sequence,
		"request": _roll_request_id, "landing_request": _landing_request_id,
	}


func get_pilot_peer_id() -> int:
	return _pilot_peer_id


func get_ship_id() -> StringName:
	return _ship_id


## One delivered, already-validated movement intent for this craft.
func apply_intent(intent: Dictionary) -> void:
	_controls = decode_intent(intent)
	_age_ticks = 0
	_delivered += 1
	var stream := int(intent.get("stream_id", 0))
	var sequence := int(intent.get("sequence", 0))
	# A prior seat lease retires its entire stream, including queued presses.
	if stream <= _roll_retired_stream or stream < _roll_wire_stream \
			or (stream == _roll_wire_stream and sequence <= _roll_wire_sequence):
		return
	if stream > _roll_wire_stream:
		_roll_pending = false
		_roll_request_id = 0
		_landing_request_id = 0
		_landing_pending = false
	_roll_wire_stream = stream
	_roll_wire_sequence = sequence
	var request := int(intent.get("interaction_request_id", 0))
	if request > _roll_request_id:
		_roll_request_id = request
		_roll_pending = true

	var target := String(intent.get("boarding_target_id", ""))
	if intent.get("board_request", false) == true and target.begins_with("pilot_landing_"):
		var serial := target.trim_prefix("pilot_landing_")
		if serial.is_valid_int():
			var landing_request := int(serial)
			if serial == str(landing_request) and landing_request > _landing_request_id \
					and landing_request <= ShipCommand.MAX_SAFE_SERIALIZED_INTEGER:
				_landing_request_id = landing_request
				_landing_pending = true


## GameFlow consumes this validated pilot edge once, without setting an edge
## on the host player's active ship or running any on-foot boarding consumer.
func take_landing_request() -> bool:
	var pending := _landing_pending
	_landing_pending = false
	return pending


## Once per authority physics tick, delivered or not.
func advance_tick() -> void:
	_age_ticks = mini(_age_ticks + 1, HOLD_TICKS + 1)
	if _age_ticks > HOLD_TICKS:
		_roll_pending = false
		_landing_pending = false


func is_holding_command() -> bool:
	return _age_ticks <= HOLD_TICKS and not _controls.is_empty()


func get_audit() -> Dictionary:
	return {
		"pilot_peer_id": _pilot_peer_id,
		"ship_id": _ship_id,
		"delivered": _delivered,
		"holding": is_holding_command(),
		"controls": _controls.duplicate(true),
		"roll_delivered": _roll_delivered,
	}


func _sample_controls() -> Dictionary:
	if not is_holding_command():
		return {}
	var controls := _controls.duplicate(true)
	controls["barrel_roll"] = _roll_pending
	if _roll_pending:
		_roll_delivered += 1
	_roll_pending = false
	return controls


func _on_delivery_invalidated() -> void:
	_controls.clear()
	_age_ticks = HOLD_TICKS + 1
	_roll_pending = false
	_landing_pending = false


## Pilot-side half: the movement intent that carries `command`'s held helm to
## the host for `ship_id`. `stream_id` is the pilot's helm stream epoch: a
## restarted stream (sequence back at zero) must carry a higher one, because
## the host's record for the seat still remembers the old stream's sequence.
static func build_helm_intent(
	peer_id: int, ship_id: StringName, entity_generation: int, sequence: int,
	client_tick: int, command: ShipCommand, stream_id: int = 0, roll_request_id: int = 0, landing_request_id: int = 0
) -> Dictionary:
	var throttle := 0.0
	var yaw := 0.0
	var pitch := 0.0
	var roll := 0.0
	var boost := false
	var brake := false
	var hover := false
	if command != null and command.is_valid():
		throttle = command.throttle
		yaw = command.yaw
		pitch = command.pitch
		roll = command.roll
		boost = command.boost
		brake = command.brake
		hover = command.hover
	var axis := Vector2(clampf(yaw, -1.0, 1.0), clampf(throttle, -1.0, 1.0))
	if axis.length() > 1.0:
		axis = axis.normalized()
	var landing_target := StringName("pilot_landing_%d" % landing_request_id) if landing_request_id > 0 else &""
	return MovementIntent.create(
		peer_id, ship_id, entity_generation, maxi(stream_id, 0), sequence, client_tick, axis,
		landing_request_id > 0, landing_target, false, clampf(roll, -1.0, 1.0), clampf(pitch, -1.0, 1.0),
		boost, brake, hover, maxi(0, roll_request_id)
	).to_dictionary()


## Host-side half: the held flight controls one delivered intent stands for.
static func decode_intent(intent: Dictionary) -> Dictionary:
	var axis: Variant = intent.get("move_axis", [0.0, 0.0])
	var yaw := 0.0
	var throttle := 0.0
	if axis is Array and (axis as Array).size() == 2:
		yaw = clampf(float((axis as Array)[0]), -1.0, 1.0)
		throttle = clampf(float((axis as Array)[1]), -1.0, 1.0)
	return {
		"throttle": throttle,
		"yaw": yaw,
		"pitch": clampf(float(intent.get("look_pitch", 0.0)), -1.0, 1.0),
		"roll": clampf(float(intent.get("look_yaw", 0.0)), -1.0, 1.0),
		"boost": intent.get("run", false) == true,
		"brake": intent.get("crouch", false) == true,
		"hover": intent.get("jump", false) == true,
	}
