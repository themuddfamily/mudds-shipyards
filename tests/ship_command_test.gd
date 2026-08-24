extends SceneTree

const ShipCommandType := preload("res://scripts/control/ship_command.gd")
const ShipCommandSourceType := preload("res://scripts/control/ship_command_source.gd")
const LocalShipInputSourceType := preload("res://scripts/control/local_ship_input_source.gd")

var _failures: Array[String] = []


class FakeInputProvider:
	extends RefCounted

	var strengths: Dictionary = {}
	var pressed: Dictionary = {}
	var read_count := 0

	func get_action_strength(action: StringName) -> float:
		read_count += 1
		return float(strengths.get(action, 0.0))

	func is_action_pressed(action: StringName) -> bool:
		read_count += 1
		return bool(pressed.get(action, false))

	func set_pressed(action: StringName, value: bool) -> void:
		pressed[action] = value
		strengths[action] = 1.0 if value else 0.0


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_test_command_snapshot()
	_test_source_stream_and_authority()
	_test_lossless_lifecycle_delivery()
	_test_real_input_map_adapter()
	await process_frame
	_finish()


func _test_command_snapshot() -> void:
	var neutral := ShipCommandType.neutral(3, 99)
	_check(neutral.sequence == 3 and neutral.timestamp_usec == 99, "neutral command preserves stream metadata")
	_check(neutral.is_neutral() and neutral.is_valid(), "neutral command has no controls and validates")

	var command := ShipCommandType.from_dictionary({
		"schema_version": ShipCommandType.SCHEMA_VERSION,
		"sequence": 7,
		"timestamp_usec": 123456,
		"stream_id": 9,
		"throttle": 4.0,
		"yaw": -3.0,
		"pitch": NAN,
		"roll": INF,
		"look_yaw_delta": 4.0,
		"look_pitch_delta": -INF,
		"boost": true,
		"brake": true,
		"hover": true,
		"fire": true,
		"fire_pressed": true,
		"barrel_roll": true,
		"engine_start": true,
		"engine_stop": true,
		"landing": true,
		"interact": true,
		"camera_toggle": true,
	})
	_check(command.throttle == 1.0 and command.yaw == -1.0, "analogue controls clamp to their signed unit range")
	_check(command.pitch == 0.0 and command.roll == 0.0, "NaN and infinity sanitize to neutral axes")
	_check(command.look_yaw_delta == 1.0 and command.look_pitch_delta == 0.0, "look deltas sanitize independently from attitude-rate axes")
	_check(command.boost and command.brake and command.hover and command.fire, "held action snapshot preserves booleans")
	_check(command.fire_pressed, "schema v4 appends the fire rising edge independently of held fire")
	_check(command.barrel_roll, "barrel-roll edge has an explicit transport field")
	_check(command.engine_start and command.engine_stop and command.landing, "system edge snapshot preserves booleans")
	_check(command.interact and command.camera_toggle, "interaction edge snapshot preserves booleans")
	_check(command.is_valid(), "sanitized command validates at the trust boundary")
	_check(command.has_game_flow_edge() and command.has_lifecycle_edge(), "GameFlow-edge classification includes the appended ordered fire edge")
	var legacy_engine_only := ShipCommandType.from_dictionary({
		"schema_version": ShipCommandType.SCHEMA_VERSION,
		"sequence": 8,
		"timestamp_usec": 123457,
		"stream_id": 9,
		"engine_start": true,
		"engine_stop": true,
	})
	_check(
		legacy_engine_only.engine_start
		and legacy_engine_only.engine_stop
		and not legacy_engine_only.has_lifecycle_edge(),
		"deprecated engine fields deserialize for transport compatibility but are not live lifecycle actions"
	)
	_check(
		command.is_strictly_newer_than(8, ShipCommandType.MAX_SAFE_SERIALIZED_INTEGER)
		and command.is_strictly_newer_than(9, 6)
		and not command.is_strictly_newer_than(9, 7)
		and not command.is_strictly_newer_than(10, 0),
		"command freshness compares stream epoch before sequence without rollback"
	)
	var detached := command.detached_copy()
	detached._engine_start = false
	_check(command.engine_start, "detached command copies cannot mutate their source snapshot")

	var serialized := command.to_dictionary()
	var restored := ShipCommandType.from_dictionary(serialized)
	_check(restored.to_dictionary() == serialized, "command serialization round-trips every field exactly")
	var json_decoded: Variant = JSON.parse_string(JSON.stringify(serialized))
	var json_restored := ShipCommandType.from_dictionary(json_decoded as Dictionary)
	_check(
		json_restored.sequence == command.sequence
		and json_restored.timestamp_usec == command.timestamp_usec
		and json_restored.stream_id == command.stream_id,
		"JSON round-trip preserves integral stream metadata"
	)
	serialized["throttle"] = -0.25
	_check(command.throttle == 1.0, "serialized dictionaries are detached from read-only snapshot state")

	var malformed := ShipCommandType.from_dictionary({
		"sequence": -8,
		"timestamp_usec": -9,
		"throttle": "full",
		"fire": "false",
	})
	_check(malformed.sequence == 0 and malformed.timestamp_usec == 0, "negative stream metadata sanitizes safely")
	_check(malformed.is_neutral(), "wrongly typed wire fields cannot synthesize input")
	_check(not malformed.is_valid() and "schema_version is required" in malformed.get_validation_errors(), "missing schema is explicitly rejected")
	var future_schema := ShipCommandType.from_dictionary({
		"schema_version": ShipCommandType.SCHEMA_VERSION + 1,
		"sequence": 12,
		"timestamp_usec": 34,
		"fire": true,
	})
	_check(future_schema.is_neutral() and not future_schema.is_valid(), "unsupported future schema cannot trigger an action")
	var stale_schema := command.to_dictionary()
	stale_schema["schema_version"] = 1
	var stale_command := ShipCommandType.from_dictionary(stale_schema)
	_check(stale_command.is_neutral() and not stale_command.is_valid(), "pre-look-delta schema is rejected instead of changing attitude semantics")
	var missing_stream := ShipCommandType.from_dictionary({
		"schema_version": ShipCommandType.SCHEMA_VERSION,
		"sequence": 1,
		"timestamp_usec": 2,
		"fire": true,
	})
	_check(missing_stream.is_neutral() and not missing_stream.is_valid(), "missing stream epoch cannot trigger an action")


func _test_source_stream_and_authority() -> void:
	var provider := FakeInputProvider.new()
	provider.strengths[&"move_forward"] = 0.85
	provider.strengths[&"move_back"] = 0.10
	provider.strengths[&"move_right"] = 0.55
	provider.strengths[&"pitch_up"] = 0.25
	provider.strengths[&"roll_right"] = 0.4
	provider.set_pressed(&"sprint_boost", true)
	provider.set_pressed(&"fire", true)
	provider.set_pressed(&"landing_assist", true)
	provider.set_pressed(&"barrel_roll", true)

	var source_a := LocalShipInputSourceType.new()
	var source_b := LocalShipInputSourceType.new()
	root.add_child(source_a)
	root.add_child(source_b)
	source_a.set_input_provider(provider)
	source_b.set_input_provider(provider)
	source_a.set_authority_peer_id(11)
	source_b.set_authority_peer_id(22)
	source_a.set_local_peer_id_override(11)
	source_b.set_local_peer_id_override(11)
	var published_a: Array[ShipCommand] = []
	var published_b: Array[ShipCommand] = []
	source_a.command_produced.connect(func(command: ShipCommand, _peer_id: int) -> void:
		published_a.append(command)
	)
	source_b.command_produced.connect(func(command: ShipCommand, _peer_id: int) -> void:
		published_b.append(command)
	)

	var first_a := source_a.next_command(1000)
	_check(first_a.sequence == 0 and first_a.timestamp_usec == 1000, "first local command begins a deterministic stream")
	_check(is_equal_approx(first_a.throttle, 0.75), "local source samples signed throttle from the InputMap contract")
	_check(is_equal_approx(first_a.yaw, 0.55) and is_equal_approx(first_a.pitch, 0.25), "local source samples keyboard yaw and pitch rate axes")
	_check(is_zero_approx(first_a.look_yaw_delta) and is_zero_approx(first_a.look_pitch_delta), "rate axes do not synthesize mouse look deltas")
	_check(is_equal_approx(first_a.roll, 0.4) and first_a.barrel_roll, "analogue roll and classic barrel-roll edge remain distinct")
	_check(first_a.boost and first_a.fire and first_a.fire_pressed and first_a.landing, "held and initial edge actions share one snapshot")

	source_a.look_motion_for_full_axis = 100.0
	source_a.queue_look_motion(Vector2(35.0, -20.0))
	var second_a := source_a.next_command(1000)
	_check(second_a.sequence == 1 and second_a.timestamp_usec == 1001, "sequence and timestamp remain strictly monotonic")
	_check(second_a.fire and not second_a.fire_pressed and not second_a.landing, "held fire repeats while fire and landing edges do not")
	_check(is_equal_approx(second_a.yaw, 0.55) and is_equal_approx(second_a.pitch, 0.25), "mouse motion cannot alter keyboard attitude-rate axes")
	_check(is_equal_approx(second_a.look_yaw_delta, 0.35) and is_equal_approx(second_a.look_pitch_delta, 0.2), "queued mouse motion occupies independent per-tick look fields")
	_check(is_equal_approx(second_a.roll, 0.4) and not second_a.barrel_roll, "held classic barrel-roll action cannot repeat its edge")

	var reads_before_non_owner := provider.read_count
	var neutral_b := source_b.next_command(500)
	_check(neutral_b.is_neutral(), "non-owner source returns a neutral command")
	_check(provider.read_count == reads_before_non_owner, "non-owner source never polls or consumes local input")
	_check(published_a.size() == 2 and published_b.is_empty(), "only an enabled owner publishes commands")
	_check(source_a.get_authority_peer_id() == 11 and source_b.get_authority_peer_id() == 22, "sources expose independent authority peer IDs")

	provider.set_pressed(&"landing_assist", false)
	var released := source_a.next_command(1002)
	provider.set_pressed(&"landing_assist", true)
	var repressed := source_a.next_command(1003)
	_check(not released.landing and repressed.landing, "release and repress creates exactly one new edge")
	var held_again := source_a.next_command(1004)
	_check(not held_again.landing, "an edge action cannot repeat while held")
	provider.set_pressed(&"fire", false)
	var fire_released := source_a.next_command(1010)
	provider.set_pressed(&"fire", true)
	var fire_repressed := source_a.next_command(1011)
	var fire_held_again := source_a.next_command(1012)
	_check(
		not fire_released.fire and not fire_released.fire_pressed
		and fire_repressed.fire and fire_repressed.fire_pressed
		and fire_held_again.fire and not fire_held_again.fire_pressed,
		"fire rising edges are one-shot while ordinary held fire remains continuous"
	)

	source_a.enabled = false
	provider.set_pressed(&"toggle_ship_camera_view", true)
	var reads_before_disabled := provider.read_count
	var disabled := source_a.next_command(1005)
	_check(
		disabled.is_neutral()
		and disabled.stream_id > held_again.stream_id
		and disabled.sequence == 0,
		"disabled source advances to a new neutral authority epoch"
	)
	_check(provider.read_count == reads_before_disabled, "disabled source never polls or consumes local input")
	source_a.enabled = true
	var resumed := source_a.next_command(1006)
	_check(not resumed.camera_toggle, "resuming primes held edges instead of inventing a camera toggle")
	var resumed_held := source_a.next_command(1007)
	_check(not resumed_held.camera_toggle, "primed held edge remains suppressed")
	provider.set_pressed(&"toggle_ship_camera_view", false)
	source_a.next_command(1008)
	provider.set_pressed(&"toggle_ship_camera_view", true)
	var resumed_repress := source_a.next_command(1009)
	_check(resumed_repress.camera_toggle, "a post-resume release and repress produces one camera edge")

	# Source B observed a non-owner frame. Transferring its local peer while the
	# start key is held must not replay A's prior edge into B's command stream.
	source_b.set_local_peer_id_override(22)
	var transferred := source_b.next_command(501)
	_check(not transferred.landing, "ownership transfer suppresses already-held edge actions")
	provider.set_pressed(&"landing_assist", false)
	source_b.next_command(502)
	provider.set_pressed(&"landing_assist", true)
	var b_repress := source_b.next_command(503)
	_check(b_repress.landing, "new owner receives a fresh edge after release and repress")
	_check(
		source_a.get_stream_id() == 2
		and source_a.get_next_sequence() == 4
		and source_b.get_stream_id() == 2
		and source_b.get_next_sequence() == 3,
		"simultaneous producers keep isolated epoch and sequence ledgers"
	)

	var replacement_provider := FakeInputProvider.new()
	replacement_provider.set_pressed(&"landing_assist", true)
	var swap_source := LocalShipInputSourceType.new()
	root.add_child(swap_source)
	swap_source.set_input_provider(provider)
	swap_source.next_command(700)
	swap_source.set_input_provider(replacement_provider)
	var swapped_held := swap_source.next_command(701)
	_check(not swapped_held.landing, "provider swap primes held edge actions")
	replacement_provider.set_pressed(&"landing_assist", false)
	swap_source.next_command(702)
	replacement_provider.set_pressed(&"landing_assist", true)
	_check(swap_source.next_command(703).landing, "replacement provider edges after release and repress")

	var isolation_provider := FakeInputProvider.new()
	isolation_provider.set_pressed(&"fire", true)
	var isolation_source := LocalShipInputSourceType.new()
	root.add_child(isolation_source)
	isolation_source.set_input_provider(isolation_provider)
	isolation_source.command_produced.connect(func(published: ShipCommand, _peer_id: int) -> void:
		# Underscore fields are only private by GDScript convention. The source
		# therefore clones its signal payload to protect the returned snapshot.
		published._fire = false
		published._sequence = 999
	)
	var isolated_return := isolation_source.next_command(900)
	_check(isolated_return.fire and isolated_return.sequence == 0, "signal listener mutation cannot alter the caller's snapshot")

	var reset_provider := FakeInputProvider.new()
	reset_provider.set_pressed(&"landing_assist", true)
	var reset_source := LocalShipInputSourceType.new()
	root.add_child(reset_source)
	reset_source.set_input_provider(reset_provider)
	_check(reset_source.next_command(950).landing, "initial held action produces its first edge")
	reset_source.reset_stream()
	var held_across_reset := reset_source.next_command(951)
	_check(not held_across_reset.landing and held_across_reset.stream_id == 1, "stream reset primes held edges without control side effects")

	var base_source := ShipCommandSourceType.new()
	base_source.set_authority_peer_id(77)
	base_source.set_local_peer_id_override(77)
	var base_command := base_source.next_command(42)
	_check(base_command.is_neutral(), "base source is a valid neutral producer for future adapters")
	base_source.reset_stream()
	var reset_command := base_source.next_command(43)
	_check(reset_command.sequence == 0 and reset_command.stream_id == 1, "stream reset emits sequence zero under a distinct epoch")
	base_source.free()
	source_a.queue_free()
	source_b.queue_free()
	swap_source.queue_free()
	isolation_source.queue_free()
	reset_source.queue_free()
	provider = null


func _test_lossless_lifecycle_delivery() -> void:
	var provider := FakeInputProvider.new()
	var source := LocalShipInputSourceType.new()
	source.set_input_provider(provider)
	var published: Array[ShipCommand] = []
	source.command_produced.connect(func(command: ShipCommand, _peer_id: int) -> void:
		published.append(command)
		# Attempt to corrupt both metadata and the edge after the source has queued
		# its detached delivery copy.
		command._sequence = 999
		command._landing = false
		command._fire_pressed = false
	)

	source.next_command(3000)
	provider.set_pressed(&"landing_assist", true)
	var start := source.next_command(3001)
	provider.set_pressed(&"landing_assist", false)
	var between := source.next_command(3002)
	provider.set_pressed(&"fire", true)
	var fire_edge := source.next_command(3003)
	provider.set_pressed(&"fire", false)
	provider.set_pressed(&"interact", true)
	var stop := source.next_command(3004)
	var generation := source.get_delivery_generation()
	var batch := source.drain_pending_commands(generation)
	_check(
		start.landing
		and between.is_neutral()
		and fire_edge.fire_pressed
		and stop.interact
		and batch.size() == 3
		and batch[0].sequence == start.sequence
		and batch[0].landing
		and batch[1].sequence == fire_edge.sequence
		and batch[1].fire_pressed
		and batch[2].sequence == stop.sequence
		and batch[2].interact,
		"GameFlow FIFO preserves landing, fire, and interact edges in production order across a newer neutral sample"
	)
	_check(
		source.drain_pending_commands(generation).is_empty(),
		"lifecycle FIFO transfers each queued snapshot exactly once"
	)
	batch[0]._sequence = 777
	batch[0]._landing = false
	_check(
		start.sequence == 1 and start.landing,
		"drained and signal snapshots are isolated from the direct physics snapshot"
	)

	# A boundary revokes previously sampled input and advances a delivery-only
	# generation without rewinding the command sequence.
	provider.set_pressed(&"interact", false)
	source.next_command(3004)
	provider.set_pressed(&"interact", true)
	var stale := source.next_command(3005)
	var stale_generation := source.get_delivery_generation()
	var stale_stream := source.get_stream_id()
	var fresh_generation := source.invalidate_pending_commands()
	_check(
		stale.interact
		and fresh_generation > stale_generation
		and source.get_stream_id() > stale_stream
		and source.get_next_sequence() == 0
		and source.drain_pending_commands(fresh_generation).is_empty(),
		"delivery invalidation revokes sampled edges under a strictly newer stream epoch"
	)
	provider.set_pressed(&"interact", false)
	source.next_command(3006)
	provider.set_pressed(&"landing_assist", true)
	var fresh := source.next_command(3007)
	_check(
		source.drain_pending_commands(stale_generation).is_empty(),
		"a stale generation cannot drain a newer boundary generation"
	)
	var fresh_batch := source.drain_pending_commands(fresh_generation)
	_check(
		fresh.landing
		and fresh_batch.size() == 1
		and fresh_batch[0].sequence == fresh.sequence,
		"a rejected stale-generation drain leaves the current ordered queue intact"
	)

	provider.set_pressed(&"landing_assist", false)
	source.next_command(3008)
	provider.set_pressed(&"landing_assist", true)
	source.next_command(3009)
	var generation_before_reset := source.get_delivery_generation()
	source.reset_stream()
	_check(
		source.get_delivery_generation() > generation_before_reset
		and source.drain_pending_commands().is_empty(),
		"stream reset invalidates undelivered lifecycle edges as a new delivery generation"
	)

	var non_owner := LocalShipInputSourceType.new()
	non_owner.set_input_provider(provider)
	non_owner.set_authority_peer_id(44)
	non_owner.set_local_peer_id_override(45)
	_check(
		non_owner.next_command(4000).is_neutral()
		and non_owner.drain_pending_commands().is_empty(),
		"non-owner samples never enter the authoritative lifecycle FIFO"
	)
	non_owner.set_authority_peer_id(45)
	non_owner.enabled = false
	_check(
		non_owner.next_command(4001).is_neutral()
		and non_owner.drain_pending_commands().is_empty(),
		"disabled samples never enter the authoritative lifecycle FIFO"
	)

	# Authority configuration changes are boundaries at assignment time, not only
	# when a later physics sample happens to observe them. Each probe deliberately
	# queues an actionable edge and drains immediately after revocation.
	var disabled_boundary_provider := FakeInputProvider.new()
	disabled_boundary_provider.set_pressed(&"landing_assist", true)
	var disabled_boundary := LocalShipInputSourceType.new()
	disabled_boundary.set_input_provider(disabled_boundary_provider)
	var disabled_captured := disabled_boundary.next_command(4100)
	var disabled_generation := disabled_boundary.get_delivery_generation()
	var disabled_stream := disabled_boundary.get_stream_id()
	disabled_boundary.enabled = false
	_check(
		disabled_captured.landing
		and disabled_boundary.get_delivery_generation() > disabled_generation
		and disabled_boundary.get_stream_id() > disabled_stream
		and disabled_boundary.drain_pending_commands(disabled_generation).is_empty()
		and disabled_boundary.drain_pending_commands().is_empty(),
		"disabling after sampling synchronously revokes the queued authoritative edge"
	)

	var authority_boundary_provider := FakeInputProvider.new()
	authority_boundary_provider.set_pressed(&"landing_assist", true)
	var authority_boundary := LocalShipInputSourceType.new()
	authority_boundary.set_input_provider(authority_boundary_provider)
	var authority_captured := authority_boundary.next_command(4200)
	var authority_generation := authority_boundary.get_delivery_generation()
	authority_boundary.set_authority_peer_id(77)
	_check(
		authority_captured.landing
		and not authority_boundary.is_enabled_owner()
		and authority_boundary.get_delivery_generation() > authority_generation
		and authority_boundary.drain_pending_commands(authority_generation).is_empty()
		and authority_boundary.drain_pending_commands().is_empty(),
		"authority reassignment synchronously revokes work sampled for the former owner"
	)

	var local_peer_boundary_provider := FakeInputProvider.new()
	local_peer_boundary_provider.set_pressed(&"landing_assist", true)
	var local_peer_boundary := LocalShipInputSourceType.new()
	local_peer_boundary.set_input_provider(local_peer_boundary_provider)
	var local_peer_captured := local_peer_boundary.next_command(4300)
	var local_peer_generation := local_peer_boundary.get_delivery_generation()
	local_peer_boundary.set_local_peer_id_override(2)
	_check(
		local_peer_captured.landing
		and not local_peer_boundary.is_enabled_owner()
		and local_peer_boundary.get_delivery_generation() > local_peer_generation
		and local_peer_boundary.drain_pending_commands(local_peer_generation).is_empty()
		and local_peer_boundary.drain_pending_commands().is_empty(),
		"local-peer reassignment synchronously revokes work sampled for its old identity"
	)

	var direct_authority_provider := FakeInputProvider.new()
	direct_authority_provider.set_pressed(&"landing_assist", true)
	var direct_authority_boundary := LocalShipInputSourceType.new()
	direct_authority_boundary.set_input_provider(direct_authority_provider)
	direct_authority_boundary.next_command(4400)
	var direct_authority_generation := direct_authority_boundary.get_delivery_generation()
	var direct_authority_stream := direct_authority_boundary.get_stream_id()
	direct_authority_boundary.set_multiplayer_authority(88, false)
	_check(
		direct_authority_boundary.drain_pending_commands(
			direct_authority_generation
		).is_empty()
		and direct_authority_boundary.drain_pending_commands().is_empty()
		and direct_authority_boundary.get_delivery_generation() > direct_authority_generation
		and direct_authority_boundary.get_stream_id() > direct_authority_stream,
		"FIFO drain fails closed when raw Node authority changes outside the convenience setter"
	)

	var owner_to_owner_provider := FakeInputProvider.new()
	owner_to_owner_provider.set_pressed(&"landing_assist", true)
	var owner_to_owner_boundary := LocalShipInputSourceType.new()
	owner_to_owner_boundary.set_input_provider(owner_to_owner_provider)
	owner_to_owner_boundary.set_local_peer_id_override(2)
	owner_to_owner_boundary.set_authority_peer_id(2)
	owner_to_owner_boundary.next_command(4500)
	var owner_to_owner_generation := owner_to_owner_boundary.get_delivery_generation()
	var owner_to_owner_stream := owner_to_owner_boundary.get_stream_id()
	owner_to_owner_boundary.set_multiplayer_authority(1, false)
	owner_to_owner_boundary.set_local_peer_id_override(1)
	_check(
		owner_to_owner_boundary.is_enabled_owner()
		and owner_to_owner_boundary.drain_pending_commands(
			owner_to_owner_generation
		).is_empty()
		and owner_to_owner_boundary.get_delivery_generation() > owner_to_owner_generation
		and owner_to_owner_boundary.get_stream_id() > owner_to_owner_stream,
		"raw owner-to-owner authority identity change revokes the old owner's queue even when ownership remains true"
	)

	# Explicit reset IDs may jump forward for replay restoration, but may never
	# roll a live source back. Sequence rollover likewise advances only after the
	# terminal pair has been delivered under its still-current epoch.
	var boundary_source := ShipCommandSourceType.new()
	var first_pair := boundary_source.next_command(5000)
	boundary_source.reset_stream(0, -1, first_pair.stream_id)
	var after_lower_reset := boundary_source.next_command(5001)
	boundary_source.reset_stream(
		ShipCommandType.MAX_SAFE_SERIALIZED_INTEGER,
		-1,
		5
	)
	var terminal_sequence := boundary_source.next_command(5002)
	var rolled_sequence := boundary_source.next_command(5003)
	_check(
		after_lower_reset.stream_id > first_pair.stream_id
		and terminal_sequence.stream_id == 5
		and terminal_sequence.sequence == ShipCommandType.MAX_SAFE_SERIALIZED_INTEGER
		and rolled_sequence.stream_id == 6
		and rolled_sequence.sequence == 0,
		"explicit lower resets and automatic sequence rollover never reuse an accepted pair"
	)

	var exhaustion_provider := FakeInputProvider.new()
	var exhaustion_source := LocalShipInputSourceType.new()
	exhaustion_source.set_input_provider(exhaustion_provider)
	exhaustion_source.reset_stream(
		ShipCommandType.MAX_SAFE_SERIALIZED_INTEGER,
		-1,
		ShipCommandType.MAX_SAFE_SERIALIZED_INTEGER
	)
	exhaustion_provider.set_pressed(&"landing_assist", true)
	var final_actionable := exhaustion_source.next_command(6000)
	var generation_before_exhaustion := exhaustion_source.get_delivery_generation()
	var exhausted := exhaustion_source.next_command(6001)
	var terminal_batch := exhaustion_source.drain_pending_commands()
	_check(
		final_actionable.landing
		and final_actionable.stream_id == ShipCommandType.MAX_SAFE_SERIALIZED_INTEGER
		and final_actionable.sequence == ShipCommandType.MAX_SAFE_SERIALIZED_INTEGER
		and exhaustion_source.is_stream_exhausted()
		and exhaustion_source.get_delivery_generation() > generation_before_exhaustion
		and exhausted.is_neutral()
		and terminal_batch.is_empty(),
		"stream saturation permits one synchronous terminal return then revokes undelivered copies and fails closed"
	)
	var delivery_exhaustion_provider := FakeInputProvider.new()
	var delivery_exhaustion_source := LocalShipInputSourceType.new()
	delivery_exhaustion_source.set_input_provider(delivery_exhaustion_provider)
	delivery_exhaustion_source.next_command(6500)
	delivery_exhaustion_source.set(
		"_delivery_generation",
		ShipCommandType.MAX_SAFE_SERIALIZED_INTEGER
	)
	delivery_exhaustion_source.invalidate_pending_commands()
	delivery_exhaustion_source.next_command(6501)
	delivery_exhaustion_provider.set_pressed(&"landing_assist", true)
	var undeliverable_edge := delivery_exhaustion_source.next_command(6502)
	_check(
		delivery_exhaustion_source.is_delivery_exhausted()
		and undeliverable_edge.landing
		and delivery_exhaustion_source.drain_pending_commands().is_empty(),
		"delivery-generation saturation fails closed instead of wrapping onto a stale drain token"
	)

	# A synchronous signal listener can cause a focus/tree-style invalidation while
	# next_command() is still on the stack. The caller must receive neutral rather
	# than the just-revoked action.
	var reentrant_provider := FakeInputProvider.new()
	var reentrant_source := LocalShipInputSourceType.new()
	reentrant_source.set_input_provider(reentrant_provider)
	reentrant_provider.set_pressed(&"landing_assist", true)
	reentrant_source.command_produced.connect(func(_command: ShipCommand, _peer_id: int) -> void:
		reentrant_source.invalidate_pending_commands()
	, CONNECT_ONE_SHOT)
	var reentrantly_invalidated := reentrant_source.next_command(7000)
	_check(
		reentrantly_invalidated.is_neutral()
		and reentrant_source.drain_pending_commands().is_empty(),
		"reentrant boundary invalidation neutralizes the direct return and its queued copy"
	)
	source.free()
	non_owner.free()
	boundary_source.free()
	exhaustion_source.free()
	delivery_exhaustion_source.free()
	reentrant_source.free()
	disabled_boundary.free()
	authority_boundary.free()
	local_peer_boundary.free()
	direct_authority_boundary.free()
	owner_to_owner_boundary.free()


func _test_real_input_map_adapter() -> void:
	# This complements the deterministic fake-provider coverage by proving the
	# default adapter reaches the project's actual InputMap actions.
	Input.action_release(&"move_forward")
	Input.action_release(&"landing_assist")
	Input.action_release(&"fire")
	var source := LocalShipInputSourceType.new()
	root.add_child(source)
	Input.action_press(&"move_forward", 0.65)
	Input.action_press(&"landing_assist")
	Input.action_press(&"fire")
	var first := source.next_command(2000)
	var second := source.next_command(2001)
	_check(is_equal_approx(first.throttle, 0.65), "default local source reads analogue strength from the real InputMap")
	_check(first.landing and not second.landing, "real InputMap edge is emitted once while held")
	_check(first.fire and first.fire_pressed and second.fire and not second.fire_pressed, "real InputMap exposes one fire edge alongside preserved held fire")
	Input.action_release(&"move_forward")
	Input.action_release(&"landing_assist")
	Input.action_release(&"fire")
	source.queue_free()

	var retired_provider := FakeInputProvider.new()
	retired_provider.set_pressed(&"engine_start", true)
	retired_provider.set_pressed(&"engine_stop", true)
	var retired_source := LocalShipInputSourceType.new()
	retired_source.set_input_provider(retired_provider)
	retired_source.queue_action_edge(&"engine_start")
	retired_source.queue_action_edge(&"engine_stop")
	var retired_sample := retired_source.next_command(2002)
	_check(
		not retired_sample.engine_start
		and not retired_sample.engine_stop
		and retired_source.drain_pending_commands().is_empty(),
		"LocalShipInputSource neither samples nor explicitly queues retired engine actions"
	)
	retired_source.free()


func _check(condition: bool, description: String) -> void:
	if condition:
		print("PASS: ", description)
	else:
		_failures.append(description)
		push_error("FAIL: " + description)


func _finish() -> void:
	if _failures.is_empty():
		print("SHIP_COMMAND_TEST_OK")
		quit(0)
	else:
		print("SHIP_COMMAND_TEST_FAILED: ", ", ".join(_failures))
		quit(1)
