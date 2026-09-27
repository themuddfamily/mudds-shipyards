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
## throttle. Only held flight axes and the boost/brake/hover holds travel.
## GameFlow edges (interact, landing, fire) never do -- they stay the host's own
## decisions, so a remote helm cannot exit, land or fire on the host's behalf.
##
## Wire mapping (encode on the pilot's client, decode here; both halves live in
## this file so they cannot drift apart):
##   move_axis  = (yaw, throttle), scaled into the unit disc the intent allows
##   look_yaw   = roll  (radians field, value in [-1, 1])
##   look_pitch = pitch (radians field, value in [-1, 1])
##   run / crouch / jump = boost / brake / hover

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


func bind_pilot(pilot_peer_id: int, ship_id: StringName) -> void:
	_pilot_peer_id = pilot_peer_id
	_ship_id = ship_id
	_controls = {}
	_age_ticks = HOLD_TICKS + 1


func get_pilot_peer_id() -> int:
	return _pilot_peer_id


func get_ship_id() -> StringName:
	return _ship_id


## One delivered, already-validated movement intent for this craft.
func apply_intent(intent: Dictionary) -> void:
	_controls = decode_intent(intent)
	_age_ticks = 0
	_delivered += 1


## Once per authority physics tick, delivered or not.
func advance_tick() -> void:
	_age_ticks = mini(_age_ticks + 1, HOLD_TICKS + 1)


func is_holding_command() -> bool:
	return _age_ticks <= HOLD_TICKS and not _controls.is_empty()


func get_audit() -> Dictionary:
	return {
		"pilot_peer_id": _pilot_peer_id,
		"ship_id": _ship_id,
		"delivered": _delivered,
		"holding": is_holding_command(),
		"controls": _controls.duplicate(true),
	}


func _sample_controls() -> Dictionary:
	if not is_holding_command():
		return {}
	return _controls.duplicate(true)


## Pilot-side half: the movement intent that carries `command`'s held helm to
## the host for `ship_id`.
static func build_helm_intent(
	peer_id: int, ship_id: StringName, entity_generation: int, sequence: int,
	client_tick: int, command: ShipCommand
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
	return MovementIntent.create(
		peer_id, ship_id, entity_generation, 0, sequence, client_tick, axis,
		false, &"", false, clampf(roll, -1.0, 1.0), clampf(pitch, -1.0, 1.0),
		boost, brake, hover, 0
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
