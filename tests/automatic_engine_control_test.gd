extends SceneTree

## Focused production-Main contract for demand-driven player propulsion.
## Logical device state is injected only at LocalShipInputSource's documented
## provider seam; engine, movement, landing, audio, presentation, and exit all
## remain owned by the live HeroShip/GameFlow nodes from scenes/main.tscn.

const MAIN_SCENE := preload("res://scenes/main.tscn")
const FRAME_BUDGET_GRACE := 30

var _failures := PackedStringArray()
var _assertions := 0


class LogicalInputProvider:
	extends RefCounted

	var strengths: Dictionary = {}

	func set_action(action: StringName, strength: float) -> void:
		strengths[action] = clampf(strength, 0.0, 1.0)

	func release_all() -> void:
		strengths.clear()

	func get_action_strength(action: StringName) -> float:
		return float(strengths.get(action, 0.0))

	func is_action_pressed(action: StringName) -> bool:
		return get_action_strength(action) > 0.5


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var game := MAIN_SCENE.instantiate() as GameFlow
	_check(game != null, "production Main instantiates for automatic-engine coverage")
	if game == null:
		_finish()
		return
	root.add_child(game)
	await process_frame
	await physics_frame
	game.canopy_motion_time = 0.0
	game.boarding_motion_time = 0.0
	game.disembarking_motion_time = 0.0
	game.start_shift()
	await process_frame

	var torrent := game.get_node_or_null("TorrentInterceptor") as HeroShip
	var arrow := game.get_node_or_null("ArrowReconShip") as HeroShip
	var jovian := game.get_node_or_null("JovianLightFreighter") as HeroShip
	var halyard := game.get_node_or_null("HalyardCrewTransport") as HeroShip
	var zenith := game.get_node_or_null("ZenithInterceptor") as HeroShip
	var world := game.get_node_or_null("ShipyardWorld") as ShipyardWorld
	_check(
		torrent != null and arrow != null and jovian != null and halyard != null
		and zenith != null and world != null,
		"production Main exposes the complete five-craft roster and authoritative berth world"
	)
	if (
		torrent == null or arrow == null or jovian == null or halyard == null
		or zenith == null or world == null
	):
		await _clean_up(game)
		_finish()
		return

	_check(
		is_equal_approx(HeroShip.AUTOMATIC_ENGINE_IDLE_SHUTDOWN_SECONDS, 1.5),
		"the player-friendly automatic idle interval is frozen at 1.5 physics seconds"
	)
	_check(
		not InputMap.has_action(&"engine_start") and not InputMap.has_action(&"engine_stop"),
		"production startup and persisted binding application do not expose retired engine actions"
	)

	await _test_exact_idle_clock(torrent)
	await _test_derived_roster_immediate_presentation([
		torrent, arrow, jovian, halyard, zenith,
	])
	await _test_production_sortie(game, arrow, world)

	await _clean_up(game)
	_finish()


func _test_exact_idle_clock(ship: HeroShip) -> void:
	var source := ship.get_command_source() as LocalShipInputSource
	var provider := LogicalInputProvider.new()
	ship.request_engine_stop(false)
	ship.set_piloted(true)
	source.set_input_provider(provider)
	var audio_before_wake := ship.get_ship_audio_rig().get_state_snapshot()
	provider.set_action(&"hover", 1.0)
	await physics_frame
	await process_frame
	var woke_audio := ship.get_ship_audio_rig().get_state_snapshot()
	_check(
		_engine_state(ship) == &"ONLINE"
		and bool(woke_audio.engine_running)
		and int(woke_audio.cue_request_count) == int(audio_before_wake.cue_request_count) + 1
		and StringName(woke_audio.last_cue_id) == ShipAudioRig.CUE_STARTUP,
		"automatic ONLINE atomically commits continuous audio and exactly one startup cue"
	)
	provider.release_all()
	ship.set_physics_process(false)
	for _render_frame in 5:
		await process_frame
	_check(
		_engine_state(ship) == &"ONLINE",
		"render-only frames consume none of the physics idle budget"
	)
	paused = true
	for _paused_frame in 5:
		await process_frame
	_check(_engine_state(ship) == &"ONLINE", "paused time consumes none of the physics idle budget")
	paused = false
	var audio_before_stop := ship.get_ship_audio_rig().get_state_snapshot()
	var physics_tick := 1.0 / float(Engine.physics_ticks_per_second)
	ship.call(
		"_update_automatic_engine_control",
		HeroShip.AUTOMATIC_ENGINE_IDLE_SHUTDOWN_SECONDS - physics_tick,
		ShipCommand.neutral()
	)
	_check(
		_engine_state(ship) == &"ONLINE",
		"propulsion remains ONLINE one physics tick before the exact 1.5-second deadline"
	)
	ship.call(
		"_update_automatic_engine_control",
		physics_tick + 0.000001,
		ShipCommand.neutral()
	)
	var stopped_audio := ship.get_ship_audio_rig().get_state_snapshot()
	_check(
		_engine_state(ship) == &"OFFLINE"
		and not bool(stopped_audio.engine_running)
		and int(stopped_audio.cue_request_count) == int(audio_before_stop.cue_request_count) + 1
		and StringName(stopped_audio.last_cue_id) == ShipAudioRig.CUE_STOP
		and (stopped_audio.desired_loop_layers as PackedStringArray).is_empty(),
		"the threshold tick commits OFFLINE, clears loops, and requests exactly one stop cue"
	)
	ship.set_physics_process(true)
	ship.set_piloted(false)


func _test_derived_roster_immediate_presentation(roster: Array) -> void:
	var providers: Dictionary = {}
	var records: Dictionary = {}
	for candidate: Variant in roster:
		var ship := candidate as HeroShip
		var source := ship.get_command_source() as LocalShipInputSource
		var provider := LogicalInputProvider.new()
		var record := {"online_sync": false, "offline_sync": false}
		providers[ship] = provider
		records[ship] = record
		ship.request_engine_stop(false)
		ship.set_piloted(true)
		source.set_input_provider(provider)
		ship.engine_state_changed.connect(_record_roster_transition.bind(ship, record))
		provider.set_action(&"hover", 1.0)

	_check(
		await _wait_until(func() -> bool: return _roster_has_state(roster, &"ONLINE"), 0.4),
		"hover demand automatically wakes every derived production craft"
	)
	for provider_value: Variant in providers.values():
		(provider_value as LogicalInputProvider).release_all()
	await _advance_physics_seconds(0.5)
	_check(
		_roster_has_state(roster, &"ONLINE"),
		"neutral derived craft remain powered before the finite idle deadline"
	)
	_check(
		await _wait_until(func() -> bool: return _roster_has_state(roster, &"OFFLINE"), 0.8),
		"the complete derived roster idles offline after the same finite deadline"
	)
	var same_tick_sync := true
	for candidate: Variant in roster:
		var ship := candidate as HeroShip
		var record := records[ship] as Dictionary
		same_tick_sync = (
			same_tick_sync
			and bool(record.online_sync)
			and bool(record.offline_sync)
		)
		ship.set_piloted(false)
	_check(
		same_tick_sync,
		"Torrent, Arrow, Jovian, Halyard, and Zenith publish wake/off only after audio and roster-specific visuals sync in the same tick"
	)


func _record_roster_transition(
		state: StringName,
		ship: HeroShip,
		record: Dictionary
	) -> void:
	if state == HeroShip.ENGINE_ONLINE:
		record.online_sync = (
			_variant_presentation_matches(ship, true)
			and ship.get_ship_audio_rig().is_engine_running()
		)
	elif state == HeroShip.ENGINE_OFFLINE:
		var audio_state := ship.get_ship_audio_rig().get_state_snapshot()
		record.offline_sync = (
			_variant_presentation_matches(ship, false)
			and not bool(audio_state.engine_running)
			and (audio_state.desired_loop_layers as PackedStringArray).is_empty()
		)


func _variant_presentation_matches(ship: HeroShip, active: bool) -> bool:
	var is_torrent := str(ship.name) == "TorrentInterceptor"
	var plume_value: Variant = ship.get("_engine_glows" if is_torrent else "_engine_plumes")
	if plume_value is not Array or (plume_value as Array).is_empty():
		return false
	for candidate: Variant in plume_value as Array:
		var plume := candidate as MeshInstance3D
		if not is_instance_valid(plume) or plume.visible != active:
			return false
	var light_property := &""
	match str(ship.name):
		"TorrentInterceptor":
			light_property = &"_engine_lights"
		"ArrowReconShip":
			light_property = &"_arrow_engine_lights"
		"JovianLightFreighter":
			light_property = &"_jovian_engine_lights"
		"HalyardCrewTransport":
			light_property = &"_halyard_engine_lights"
	if light_property.is_empty():
		return true
	var light_value: Variant = ship.get(light_property)
	if light_value is not Array or (light_value as Array).is_empty():
		return false
	for candidate: Variant in light_value as Array:
		var light := candidate as OmniLight3D
		if (
			not is_instance_valid(light)
			or (active and light.light_energy <= 0.0)
			or (not active and not is_zero_approx(light.light_energy))
		):
			return false
	return true


func _test_production_sortie(game: GameFlow, arrow: HeroShip, world: ShipyardWorld) -> void:
	game.call("_board_ship", arrow)
	_check(
		await _wait_until(
			func() -> bool: return game.phase == GameFlow.Phase.START_ENGINES and arrow.is_piloted(),
			0.8
		),
		"physical boarding reaches the seated apply-thrust phase with propulsion offline"
	)
	var source := arrow.get_command_source() as LocalShipInputSource
	var provider := LogicalInputProvider.new()
	_check(source != null, "the boarded craft retains the production local input adapter")
	if source == null:
		return
	source.set_input_provider(provider)
	_check(_engine_state(arrow) == &"OFFLINE", "boarding itself does not wake propulsion")

	# Camera, menu, and interact intent may share the immutable command stream but
	# never require propulsion. Transition-busy contains the interact edge so this
	# assertion observes wake policy without beginning a legitimate offline exit.
	await _tap_action(provider, &"toggle_ship_camera_view")
	await _tap_action(provider, &"camera_distance_out")
	provider.set_action(&"pause", 1.0)
	await physics_frame
	provider.set_action(&"pause", 0.0)
	game.set("_transition_busy", true)
	await _tap_action(provider, &"interact")
	game.set("_transition_busy", false)
	_check(
		_engine_state(arrow) == &"OFFLINE",
		"camera toggle/distance, pause, and UI interaction alone never wake propulsion"
	)

	var parked_position := arrow.global_position
	provider.set_action(&"move_forward", 1.0)
	# `physics_frame` is emitted before node integration. The following idle-frame
	# boundary observes that one completed physics tick without sampling a second.
	await physics_frame
	await process_frame
	_check(
		_engine_state(arrow) == &"ONLINE"
		and arrow.velocity.length() > 0.0
		and arrow.global_position.distance_to(parked_position) > 0.0
		and arrow.get_last_ship_command().throttle > 0.0,
		"one accepted thrust tick wakes ONLINE and physically moves the same production craft"
	)
	_check(
		await _wait_until(
			func() -> bool:
				return (
					not bool(arrow.get_telemetry().get("landed", true))
					and game.phase == GameFlow.Phase.FREE_FLIGHT
				),
			0.8
		),
		"physical departure, not engine state alone, begins the sandbox sortie"
	)
	provider.set_action(&"move_forward", 0.0)
	var audio_before_idle := arrow.get_ship_audio_rig().get_state_snapshot()
	await _advance_physics_seconds(1.0)
	_check(_engine_state(arrow) == &"ONLINE", "neutral flight preserves power before 1.5 seconds")
	_check(
		await _wait_until(func() -> bool: return _engine_state(arrow) == &"OFFLINE", 0.8),
		"neutral flight reaches automatic OFFLINE on a finite physics-time budget"
	)
	var audio_state := arrow.get_ship_audio_rig().get_state_snapshot()
	_check(
		not bool(audio_state.engine_running)
		and is_zero_approx(float(audio_state.throttle))
		and (audio_state.desired_loop_layers as PackedStringArray).is_empty()
		and int(audio_state.cue_request_count) == int(audio_before_idle.cue_request_count) + 1
		and StringName(audio_state.last_cue_id) == ShipAudioRig.CUE_STOP,
		"automatic idle clears continuous audio and requests exactly one stop cue"
	)

	var shots := [0]
	arrow.projectile_fired.connect(func(_origin: Vector3, _direction: Vector3) -> void:
		shots[0] += 1
	)
	provider.set_action(&"fire", 1.0)
	await physics_frame
	await process_frame
	_check(
		_engine_state(arrow) == &"ONLINE"
		and shots[0] == 1
		and arrow.get_last_ship_command().fire,
		"fire demand immediately re-wakes power before same-tick weapon dispatch"
	)
	provider.set_action(&"fire", 0.0)
	_check(
		await _wait_until(func() -> bool: return _engine_state(arrow) == &"OFFLINE", 1.8),
		"the re-woken craft returns offline after fire intent becomes neutral"
	)

	var berth_id := arrow.get_home_berth_id()
	var berth := world.get_berth_node(berth_id) as ShipBerth
	var berth_transform := world.get_berth_transform(berth_id)
	arrow.global_transform = berth_transform.translated_local(Vector3(0.0, 3.0, 0.0))
	arrow.reset_physics_interpolation()
	arrow.velocity = Vector3.ZERO
	await physics_frame
	provider.set_action(&"landing_assist", 1.0)
	_check(
		await _wait_until(func() -> bool: return arrow.is_landing_active(), 0.6),
		"landing intent wakes an offline craft and enters the authoritative assist"
	)
	provider.set_action(&"landing_assist", 0.0)
	_check(
		_engine_state(arrow) == &"ONLINE",
		"landing assist retains required propulsion while controls are neutral"
	)
	_check(
		await _wait_until(func() -> bool: return game.phase == GameFlow.Phase.SHUT_DOWN, 4.0),
		"touchdown reaches the landed automatic-idle phase"
	)
	_check(
		berth != null and berth.get_occupant() == arrow and _engine_state(arrow) == &"ONLINE",
		"touchdown secures the physical berth before automatic idle expires"
	)
	_check(
		await _wait_until(func() -> bool: return _engine_state(arrow) == &"OFFLINE", 1.8),
		"landed neutral propulsion idles offline without a GameFlow stop request"
	)

	await _tap_action(provider, &"interact")
	_check(
		await _wait_until(func() -> bool: return not arrow.is_piloted(), 0.8),
		"offline touchdown makes the ordinary interact/exit control available"
	)
	game.call("_board_ship", arrow)
	_check(
		await _wait_until(
			func() -> bool: return game.phase == GameFlow.Phase.START_ENGINES and arrow.is_piloted(),
			0.8
		)
		and _engine_state(arrow) == &"OFFLINE",
		"re-entry returns to an offline apply-thrust seat without a manual start step"
	)

	source = arrow.get_command_source() as LocalShipInputSource
	provider.release_all()
	await physics_frame
	await process_frame
	_check(
		arrow.get_last_ship_command().is_neutral(),
		"exit/re-entry stream invalidation cannot replay a pre-detach lifecycle edge"
	)
	source.set_authority_peer_id(2)
	var non_owner_position := arrow.global_position
	provider.set_action(&"move_forward", 1.0)
	provider.set_action(&"fire", 1.0)
	provider.set_action(&"landing_assist", 1.0)
	var shots_before_non_owner := int(shots[0])
	await physics_frame
	await process_frame
	_check(
		_engine_state(arrow) == &"OFFLINE"
		and arrow.global_position.is_equal_approx(non_owner_position)
		and shots[0] == shots_before_non_owner
		and not arrow.is_landing_active(),
		"non-owner thrust, fire, and landing demand are neutralized before ship effects"
	)
	source.set_authority_peer_id(1)
	await physics_frame
	await process_frame
	_check(
		_engine_state(arrow) == &"ONLINE" and arrow.velocity.length() > 0.0,
		"restored owner demand re-wakes immediately after the authority boundary"
	)
	provider.release_all()


func _roster_has_state(roster: Array, expected: StringName) -> bool:
	for candidate: Variant in roster:
		if _engine_state(candidate as HeroShip) != expected:
			return false
	return true


func _engine_state(ship: HeroShip) -> StringName:
	return StringName(ship.get_telemetry().get("engine_state", &"OFFLINE"))


func _tap_action(provider: LogicalInputProvider, action: StringName) -> void:
	provider.set_action(action, 1.0)
	await physics_frame
	await process_frame
	provider.set_action(action, 0.0)
	await physics_frame
	await process_frame


func _advance_physics_seconds(seconds: float) -> void:
	var frame_count := int(ceil(maxf(seconds, 0.0) * float(Engine.physics_ticks_per_second)))
	for _frame in frame_count:
		await physics_frame
		await process_frame


func _wait_until(predicate: Callable, timeout_seconds: float) -> bool:
	var frame_budget := (
		int(ceil(maxf(timeout_seconds, 0.0) * float(Engine.physics_ticks_per_second)))
		+ FRAME_BUDGET_GRACE
	)
	for _frame in frame_budget:
		if bool(predicate.call()):
			return true
		await physics_frame
		await process_frame
	return bool(predicate.call())


func _clean_up(game: Node) -> void:
	if is_instance_valid(game):
		game.queue_free()
	await process_frame
	await physics_frame
	await process_frame


func _check(condition: bool, description: String) -> void:
	_assertions += 1
	if condition:
		print("PASS: ", description)
	else:
		_failures.append(description)
		push_error("FAIL: " + description)


func _finish() -> void:
	if _failures.is_empty():
		print("AUTOMATIC_ENGINE_CONTROL_TEST_OK: %d assertions" % _assertions)
		quit(0)
	else:
		print("AUTOMATIC_ENGINE_CONTROL_TEST_FAILED: %d/%d failed" % [_failures.size(), _assertions])
		quit(1)
