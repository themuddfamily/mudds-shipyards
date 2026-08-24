class_name ShipCommandSource
extends Node

const ShipCommandType := preload("res://scripts/control/ship_command.gd")

## Authority-aware base for local, AI, replay, and network command producers.
##
## Every request advances this source's independent sequence, including neutral
## requests while suspended. Consumers compare stream ID plus sequence to reject
## replayed or out-of-order commands; they need not assume contiguous delivery.
## GameFlow edges additionally enter a source-owned FIFO so a faster physics
## producer cannot overwrite them before the game-flow consumer runs. Delivery is
## lossless and ordered inside one generation; explicit lifecycle boundaries
## invalidate undelivered input and begin a new generation.

signal command_produced(command: ShipCommand, authority_peer_id: int)

@export var enabled := true:
	set(value):
		if enabled == value:
			return
		enabled = value
		_synchronize_authority_configuration_boundary()
@export_range(1, 2147483647, 1) var authority_peer_id: int = 1:
	set(value):
		var safe_peer_id := maxi(1, value)
		if get_multiplayer_authority() == safe_peer_id:
			return
		set_multiplayer_authority(safe_peer_id, false)
		_observed_authority_peer_id = safe_peer_id
		_synchronize_authority_configuration_boundary()
	get:
		return get_multiplayer_authority()

var _next_sequence := 0
var _last_timestamp_usec := -1
var _stream_id := 0
var _local_peer_id_override := 0
var _consumption_state_observed := false
var _was_consuming := false
var _observed_authority_peer_id := 1
var _pending_commands: Array[ShipCommand] = []
var _delivery_generation := 0
var _delivery_exhausted := false
var _stream_rollover_pending := false
var _stream_exhausted := false


## Returns the next read-only-public snapshot for this producer's stream.
func next_command(timestamp_usec: int = -1) -> ShipCommand:
	_observe_raw_authority_boundary()
	var consuming := is_enabled_owner()
	# A subclass may invalidate on an ownership/enabled transition. Do that before
	# capturing metadata so the returned command belongs to the new epoch.
	_update_consumption_state(consuming)
	if _stream_rollover_pending:
		_advance_stream_epoch(true)
	if _stream_exhausted:
		# There is no representable epoch after MAX_SAFE_SERIALIZED_INTEGER. Never
		# wrap to a formerly accepted pair or sample controls under an aliased ID.
		return ShipCommandType.neutral(
			ShipCommandType.MAX_SAFE_SERIALIZED_INTEGER,
			_resolve_timestamp(timestamp_usec),
			ShipCommandType.MAX_SAFE_SERIALIZED_INTEGER
		)
	var sequence := _next_sequence
	var command_stream_id := _stream_id
	if _next_sequence >= ShipCommandType.MAX_SAFE_SERIALIZED_INTEGER:
		# Advance at the beginning of the *next* request. Until this command returns,
		# get_stream_id() must still identify it as current for a consumer fence.
		_stream_rollover_pending = true
	else:
		_next_sequence += 1
	var safe_timestamp := _resolve_timestamp(timestamp_usec)

	var command := ShipCommandType.neutral(sequence, safe_timestamp, command_stream_id)
	if consuming:
		var production_generation := _delivery_generation
		var values := _sample_controls()
		if values == null:
			values = {}
		else:
			values = values.duplicate(true)
		values["schema_version"] = ShipCommandType.SCHEMA_VERSION
		values["sequence"] = sequence
		values["timestamp_usec"] = safe_timestamp
		values["stream_id"] = command_stream_id
		command = ShipCommandType.from_dictionary(values)
		if (
			command.is_valid()
			and command.has_game_flow_edge()
			and not _delivery_exhausted
		):
			_pending_commands.append(command.detached_copy())
		# Non-owners may request a neutral snapshot for prediction bookkeeping,
		# but only the configured owner may publish. Clone at this signal boundary
		# so a listener cannot mutate the snapshot returned to the caller.
		var published := ShipCommandType.from_dictionary(command.to_dictionary())
		command_produced.emit(published, get_authority_peer_id())
		# Signals are synchronous and may re-enter a focus/tree boundary. Never hand
		# the caller an actionable snapshot from the generation just revoked.
		if (
			production_generation != _delivery_generation
			or command_stream_id < _stream_id
			or _stream_exhausted
		):
			return ShipCommandType.neutral(sequence, safe_timestamp, command_stream_id)
	return command


## Atomically takes every pending GameFlow edge in production order. Supplying
## a generation prevents a stale caller from draining a queue created after a
## focus, pause, tree, pilot, or source boundary. Returned snapshots are detached
## from both the queue and signal payloads.
func drain_pending_commands(expected_generation: int = -1) -> Array[ShipCommand]:
	var drained: Array[ShipCommand] = []
	# Authority may be changed through Node.set_multiplayer_authority(), bypassing
	# the exported convenience setter. Observe it here as well as in next_command()
	# and revoke, rather than deliver, work sampled for the former owner.
	_observe_raw_authority_boundary()
	_update_consumption_state(is_enabled_owner())
	if not is_enabled_owner():
		_pending_commands.clear()
		return drained
	if _delivery_exhausted:
		return drained
	if expected_generation >= 0 and expected_generation != _delivery_generation:
		return drained
	for command: ShipCommand in _pending_commands:
		drained.append(command.detached_copy())
	_pending_commands.clear()
	return drained


func get_delivery_generation() -> int:
	return _delivery_generation


func is_delivery_exhausted() -> bool:
	return _delivery_exhausted


## Revokes every not-yet-dispatched GameFlow edge and advances the stream epoch.
## Advancing lets direct consumers reject a snapshot captured before this boundary
## even when no newer command has been sampled yet. Subclasses use the hook to
## clear device transients and re-prime held buttons. The returned generation can
## be captured by a synchronous drain caller.
func invalidate_pending_commands() -> int:
	_pending_commands.clear()
	_advance_delivery_generation()
	_advance_stream_epoch()
	_on_delivery_invalidated()
	return _delivery_generation


func get_authority_peer_id() -> int:
	return get_multiplayer_authority()


func set_authority_peer_id(peer_id: int) -> void:
	authority_peer_id = peer_id


## A positive override makes ownership deterministic for tests, replay tools,
## split-screen adapters, and future client prediction. Zero restores the live
## MultiplayerAPI peer ID (or the offline peer ID 1 outside a SceneTree).
func set_local_peer_id_override(peer_id: int) -> void:
	var safe_peer_id := maxi(0, peer_id)
	if _local_peer_id_override == safe_peer_id:
		return
	_local_peer_id_override = safe_peer_id
	_synchronize_authority_configuration_boundary()


func get_local_peer_id() -> int:
	if _local_peer_id_override > 0:
		return _local_peer_id_override
	if is_inside_tree() and multiplayer != null:
		return multiplayer.get_unique_id()
	return 1


func is_enabled_owner() -> bool:
	return enabled and get_local_peer_id() == get_authority_peer_id()


func get_next_sequence() -> int:
	return _next_sequence


func get_stream_id() -> int:
	return _stream_id


func is_stream_exhausted() -> bool:
	return _stream_exhausted


## Starts a new stream epoch. The ID is carried by every command, so sequence 0
## in a reset stream cannot be mistaken for an old packet from the prior epoch.
## Passing -1 selects the next epoch. An explicit replay/restoration ID may jump
## forward but can never roll this live source back or reuse its current epoch.
func reset_stream(next_sequence: int = 0, timestamp_usec: int = -1, new_stream_id: int = -1) -> void:
	_pending_commands.clear()
	_advance_delivery_generation()
	_last_timestamp_usec = (
		clampi(timestamp_usec, 0, ShipCommandType.MAX_SAFE_SERIALIZED_INTEGER)
		if timestamp_usec >= 0
		else -1
	)
	if not _stream_exhausted:
		if _stream_id >= ShipCommandType.MAX_SAFE_SERIALIZED_INTEGER:
			_stream_exhausted = true
		else:
			var minimum_epoch := _stream_id + 1
			_stream_id = (
				maxi(
					minimum_epoch,
					clampi(new_stream_id, 0, ShipCommandType.MAX_SAFE_SERIALIZED_INTEGER)
				)
				if new_stream_id >= 0
				else minimum_epoch
			)
			_next_sequence = clampi(
				next_sequence,
				0,
				ShipCommandType.MAX_SAFE_SERIALIZED_INTEGER
			)
			_stream_rollover_pending = false
	_consumption_state_observed = false
	_was_consuming = false
	_on_stream_reset()


## Subclasses return control values only; the base owns sequence and timestamp.
func _sample_controls() -> Dictionary:
	return {}


func _on_consumption_state_changed(_consuming: bool) -> void:
	# The base class owns the delivery queue, so custom AI/replay/network sources
	# receive the same fail-closed authority boundary even when they do not need the
	# local adapter's device-specific edge priming override.
	invalidate_pending_commands()


func _on_stream_reset() -> void:
	pass


func _on_delivery_invalidated() -> void:
	pass


func _advance_delivery_generation() -> bool:
	if _delivery_exhausted:
		return false
	if _delivery_generation >= ShipCommandType.MAX_SAFE_SERIALIZED_INTEGER:
		_delivery_exhausted = true
		_pending_commands.clear()
		return false
	_delivery_generation += 1
	return true


func _advance_stream_epoch(revoke_pending_on_exhaustion: bool = false) -> bool:
	_stream_rollover_pending = false
	if _stream_exhausted:
		return false
	if _stream_id >= ShipCommandType.MAX_SAFE_SERIALIZED_INTEGER:
		_stream_exhausted = true
		# Once no distinct successor pair exists, delayed work from the terminal
		# pair cannot safely remain available through a separate delivery path.
		# A caller that consumed the direct return synchronously has already seen it;
		# all undelivered copies fail closed at this terminal boundary.
		if revoke_pending_on_exhaustion:
			_pending_commands.clear()
			_advance_delivery_generation()
		return false
	_stream_id += 1
	_next_sequence = 0
	return true


func _resolve_timestamp(requested: int) -> int:
	var candidate := (
		clampi(requested, 0, ShipCommandType.MAX_SAFE_SERIALIZED_INTEGER)
		if requested >= 0
		else mini(int(Time.get_ticks_usec()), ShipCommandType.MAX_SAFE_SERIALIZED_INTEGER)
	)
	if _last_timestamp_usec >= 0:
		candidate = maxi(
			candidate,
			mini(_last_timestamp_usec + 1, ShipCommandType.MAX_SAFE_SERIALIZED_INTEGER)
		)
	_last_timestamp_usec = maxi(0, candidate)
	return _last_timestamp_usec


func _update_consumption_state(consuming: bool) -> void:
	if not _consumption_state_observed:
		_consumption_state_observed = true
		_was_consuming = consuming
		if not consuming:
			_on_consumption_state_changed(false)
		return
	if consuming == _was_consuming:
		return
	_was_consuming = consuming
	_on_consumption_state_changed(consuming)


## Property changes are synchronous authority boundaries. Once this producer has
## been observed, changing enabled, authority, or the deterministic local-peer
## identity immediately revokes queued and directly captured work. Updating the
## observed state here prevents the next sample from advancing a second epoch for
## the same configuration change. Before the first sample there is no work to
## revoke, preserving the useful initial-held-edge contract for injected tools.
func _synchronize_authority_configuration_boundary() -> void:
	if not _consumption_state_observed:
		return
	_was_consuming = is_enabled_owner()
	invalidate_pending_commands()


## Node's native multiplayer setter is intentionally non-virtual and can bypass
## this script's exported property. Snapshot the raw value at both consumption
## entry points so an owner-to-owner authority change still advances the epoch;
## checking only the boolean `is_enabled_owner()` would miss that identity change.
func _observe_raw_authority_boundary() -> void:
	var current_authority := get_multiplayer_authority()
	if current_authority == _observed_authority_peer_id:
		return
	_observed_authority_peer_id = current_authority
	_synchronize_authority_configuration_boundary()
