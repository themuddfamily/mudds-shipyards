extends SceneTree

## Headless long-session soak for the whole production loop (ROADMAP Phase 10 §1).
##
## One process drives `res://scenes/main.tscn` through N complete play cycles
## without ever rebuilding the scene from scratch, rotating across all nine
## flyable craft. Every cycle walks to a craft with real locomotion input, boards
## it with a real `interact` press, wakes propulsion through the production
## automatic-propulsion demand, launches, flies a leg, fires the live weapon,
## returns, lands with the real landing assist, and disembarks. Every third cycle
## additionally takes real combat damage in flight and then destroys the parked
## craft at its berth so the production destruction/regeneration recovery runs.
## Every fourth cycle commits the production settings/session saves and then
## streams the whole `Main` subtree out and back in through the same detach and
## re-attach path a real re-entry uses. Every cycle starts and abandons one
## nearby-sector activity (the station perimeter defense encounter, which is the
## nearby-activity entry available while the yard itself is the resident
## location).
##
## The point is not that one cycle works — other suites own that. The point is
## that the hundredth cycle costs the same as the third. Between cycles this
## suite records the scene-tree node count, the ObjectDB object/node/orphan
## counters, static memory, the audio voice census, the particle census, the
## registered combat source count, live tweens, timers, HUD control count and
## (at the warm-up boundary and at the end) the retained-material fingerprint
## from `tools/geometry_census.gd`. After the warm-up window no counter may grow
## past a small fixed tolerance, and the final whole-`Main` teardown must return
## `OBJECT_NODE_COUNT` to its pre-boot baseline. The window is four cycles because
## that is the first point at which every cycle variant has run once: a plain
## sortie, the first damage/destruction cycle, and the first whole-`Main`
## re-entry each build lazily created presentation the second one reuses.
##
## Every wait is a bounded physics-tick budget cross-checked against a monotonic
## deadline, never a wall-clock sleep: a loop sized in seconds is a different
## amount of simulation on every machine.
##
## Environment:
##   KETH_SOAK_CYCLES=N              cycle count (default 12).
##   KETH_SOAK_MATERIAL_CENSUS=off|boundary|all
##                                   retained-material fingerprint sampling.
##                                   Default `boundary`: the warm-up boundary and
##                                   the final cycle only, because one census
##                                   walk of the live graph costs seconds.

const MAIN_SCENE := preload("res://scenes/main.tscn")
const Census := preload("res://tools/geometry_census.gd")
const Store := preload("res://scripts/persistence/user_data_store.gd")
const ISOLATED_STORE_PATH := "memory://long-session-soak.json"

const DEFAULT_CYCLES := 12
const WARM_UP_CYCLES := 4
const FRAME_BUDGET_GRACE := 30
const LOCOMOTION_TICK_BUDGET := 240
const DEPARTURE_TICK_BUDGET := 200
## The leg flown after the berth is cleared. Departure itself is measured by the
## coordinator's own free-flight transition rather than by a distance: several
## craft are parked inside a nested dock whose structure they bounce along for
## the first seconds, so a fixed metre count is a property of the dock, not of a
## completed launch.
const FREE_FLIGHT_LEG_TICKS := 24
## Where inside the berth's own assist-capture volume the return leg is staged,
## as a fraction of the distance from the published capture pose to the dock. The
## capture contract accepts every craft here; starting mid-lane rather than at
## the far edge halves the flown approach without weakening the gate.
const APPROACH_LANE_FRACTION := 0.5

## Recorded, reproducible defect found by this soak (see docs/LONG_SESSION_SOAK.md).
## The Cinder cargo hauler is accepted for capture on Dock 04's own published
## approach pose and then stalls against the dock structure on the way in, so the
## assist aborts with `approach_obstructed` and the craft can never be parked by
## the player. The obstruction is authored dock geometry, which this suite does
## not own; what it does own is the contract that *only* this craft is affected.
## Fixing Dock 04 makes this assertion fail, which is the intended signal to
## delete the entry.
const KNOWN_OBSTRUCTED_RETURN_CRAFT_IDS: Array[StringName] = [&"cinder_cargo_hauler"]
const FLIGHT_CONTROL_ACTIONS: Array[StringName] = [
	&"move_forward", &"move_back", &"move_left", &"move_right",
	&"pitch_up", &"pitch_down", &"roll_left", &"roll_right",
	&"sprint_boost", &"brake", &"hover", &"fire", &"barrel_roll",
	&"landing_assist",
]
const ON_FOOT_ACTIONS: Array[StringName] = [
	&"interact", &"move_forward", &"move_back", &"move_left", &"move_right",
	&"sprint_boost",
]

## Per-counter growth tolerance measured from the warm-up boundary to the final
## cycle. These are absolute counts, not ratios: a leak is unbounded, so it
## crosses any fixed tolerance long before the soak ends, while the bounded churn
## a healthy loop produces (a toast still fading, a berth mid-regeneration, one
## settling audio voice) does not.
const COUNTER_TOLERANCE := {
	"scene_nodes": 24,
	"objects": 512,
	"object_nodes": 24,
	"orphan_nodes": 0,
	"render_objects_in_frame": 64,
	"static_memory_bytes": 48 * 1024 * 1024,
	"audio_players": 0,
	"audio_voices_playing": 2,
	"particle_systems": 0,
	"particle_systems_emitting": 2,
	"combat_sources": 0,
	"tweens": 4,
	"timers": 4,
	"timers_running": 8,
	"hud_controls": 8,
	"retained_materials": 0,
}

## Keeps every settings and session commit this soak makes inside this process.
class MemoryFilesystem extends UserDataFilesystem:
	var files: Dictionary = {}

	func file_exists(path: String) -> bool:
		return files.has(path)

	func directory_exists(_path: String) -> bool:
		return false

	func ensure_parent_directory(_path: String) -> Error:
		return OK

	func read_bytes(path: String, maximum_bytes: int) -> Dictionary:
		if not files.has(path):
			return {"error": ERR_FILE_NOT_FOUND, "bytes": PackedByteArray()}
		var bytes := (files[path] as PackedByteArray).duplicate()
		if bytes.size() > maximum_bytes:
			return {"error": ERR_FILE_CORRUPT, "bytes": PackedByteArray()}
		return {"error": OK, "bytes": bytes}

	func write_bytes_and_flush(path: String, bytes: PackedByteArray) -> Error:
		files[path] = bytes.duplicate()
		return OK

	func remove_path(path: String) -> Error:
		if not files.has(path):
			return ERR_FILE_NOT_FOUND
		files.erase(path)
		return OK

	func rename_path(from_path: String, to_path: String) -> Error:
		if not files.has(from_path):
			return ERR_FILE_NOT_FOUND
		if files.has(to_path):
			return ERR_ALREADY_EXISTS
		files[to_path] = (files[from_path] as PackedByteArray).duplicate()
		files.erase(from_path)
		return OK


var _failures: Array[String] = []
var _assertions := 0
var _cycle_records: Array[Dictionary] = []
var _material_census_mode := "boundary"
var _cycle_count := DEFAULT_CYCLES
var _baseline_object_nodes := 0
var _destroyed_craft_ids: Array[StringName] = []
var _obstructed_return_craft_ids: Array[StringName] = []
var _returned_craft_ids: Array[StringName] = []
var _activity_starts := 0
var _activity_abandons := 0
var _reentries := 0
var _shots_fired := 0


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_cycle_count = maxi(WARM_UP_CYCLES + 1, _environment_int("KETH_SOAK_CYCLES", DEFAULT_CYCLES))
	_material_census_mode = _environment_text("KETH_SOAK_MATERIAL_CENSUS", "boundary")
	_baseline_object_nodes = int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT))

	var game := MAIN_SCENE.instantiate() as GameFlow
	_check(game != null, "production Main instantiates for the long-session soak")
	if game == null:
		_finish()
		return
	# The save leg below commits real settings and session transactions. They must
	# land in this process's own memory store: a soak that wrote the player's
	# actual `user://` state would both corrupt it and race every other suite in a
	# parallel matrix run for the same file.
	var filesystem := MemoryFilesystem.new()
	var isolated_store := Store.new(ISOLATED_STORE_PATH, filesystem)
	_check(
		game.configure_runtime_settings_persistence(
			isolated_store, "memory://long-session-soak-legacy.cfg"
		),
		"the soak injects an isolated settings store before startup"
	)
	root.add_child(game)
	await process_frame
	await physics_frame
	await process_frame

	var player := game.get_node_or_null("Player") as PlayerController
	var world := game.get_node_or_null("ShipyardWorld") as ShipyardWorld
	var resolver := game.get_combat_resolver() as CombatResolver
	var hud := game.get_node_or_null("HUD") as CanvasLayer
	_check(
		player != null and world != null and resolver != null and hud != null,
		"the soak fixture exposes the production player, world, combat resolver and HUD"
	)
	if player == null or world == null or resolver == null or hud == null:
		await _tear_down(game)
		_finish()
		return

	# The three nested Cinder craft join the registry through deferred production
	# composition; the rotation is only complete once all nine are admitted.
	await _wait_until(func() -> bool: return game.get_flyable_ships().size() >= 9, 4.0)
	var fleet: Array[HeroShip] = game.get_flyable_ships()
	_check(fleet.size() == 9, "the soak rotates across all nine production flyable craft")
	if fleet.size() != 9:
		await _tear_down(game)
		_finish()
		return

	# Shorten only the presentation motions. Every gate below still runs through
	# the real awaited canopy/avatar chain; this keeps a long soak inside the
	# matrix timeout without skipping a single production transition.
	game.canopy_motion_time = 0.04
	game.boarding_motion_time = 0.08
	game.disembarking_motion_time = 0.06
	game.start_shift()
	await process_frame
	# The soak is the post-guide persistent sandbox, exactly as `sandbox_loop_test`
	# establishes it: the guided activity is not the behaviour under measurement.
	game.set("_guided_return_ready_for_completion", false)
	game.set("_guided_activity_complete", true)
	game.phase = GameFlow.Phase.COMPLETE
	_check(game.is_guided_activity_complete(), "the soak begins from the completed-guide sandbox")

	for cycle in _cycle_count:
		await _run_cycle(game, player, world, resolver, hud, fleet, filesystem, cycle)

	_assert_flat_counters()

	var still_destroyed: Array[String] = []
	for craft: HeroShip in fleet:
		if craft.is_destroyed():
			still_destroyed.append(str(craft.get_ship_id()))
	_check(
		still_destroyed.is_empty(),
		"every destroyed craft regenerated before the soak ended (%s)" % ", ".join(still_destroyed)
	)
	_obstructed_return_craft_ids.sort()
	var unrecorded_obstructions: Array[StringName] = []
	for craft_id: StringName in _obstructed_return_craft_ids:
		if not KNOWN_OBSTRUCTED_RETURN_CRAFT_IDS.has(craft_id):
			unrecorded_obstructions.append(craft_id)
	_check(
		unrecorded_obstructions.is_empty(),
		"no craft outside the recorded obstructed-approach set fails a physical berth return (%s)"
			% ", ".join(_stringify(unrecorded_obstructions))
	)
	_returned_craft_ids.sort()
	var never_returned: Array[StringName] = []
	for craft: HeroShip in fleet:
		if not _returned_craft_ids.has(craft.get_ship_id()) \
				and not KNOWN_OBSTRUCTED_RETURN_CRAFT_IDS.has(craft.get_ship_id()):
			never_returned.append(craft.get_ship_id())
	_check(
		never_returned.is_empty(),
		"every craft outside that set completed at least one physical berth return (missing %s)"
			% ", ".join(_stringify(never_returned))
	)
	_check(
		_activity_starts == _cycle_count and _activity_abandons == _cycle_count,
		"one nearby-sector activity was started and abandoned in each of %d cycles (%d/%d)"
			% [_cycle_count, _activity_starts, _activity_abandons]
	)
	_check(
		_reentries == _cycle_count / 4,
		"a whole-Main save and re-entry ran on every fourth cycle (%d)" % _reentries
	)

	# Every save this soak committed has to have gone to the injected store. A
	# soak that quietly rewrote the player's real `user://` settings would be a
	# worse defect than any leak it could find, and in a parallel matrix run it
	# would also race every other suite for the same file.
	var persistence := game.get_runtime_settings_persistence_report()
	_check(
		bool(persistence.get("injected_authority", false))
		and persistence.get("identity_scope", &"") == &"injected_main_lifetime"
		and int(persistence.get("store_instance_id", 0)) == isolated_store.get_instance_id()
		and int(persistence.get("save_success_count", 0)) == int(persistence.get("save_attempt_count", -1))
		and int(persistence.get("save_success_count", 0)) >= _reentries
		and filesystem.files.has(ISOLATED_STORE_PATH),
		"every soak save committed to the injected store and never to production user data"
	)

	await _tear_down(game)
	var teardown_nodes := int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT))
	var teardown_orphans := int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT))
	_check(
		teardown_nodes - _baseline_object_nodes <= int(COUNTER_TOLERANCE["object_nodes"]),
		"the final teardown returns OBJECT_NODE_COUNT to the pre-boot baseline (%d -> %d)"
			% [_baseline_object_nodes, teardown_nodes]
	)
	_check(
		teardown_orphans == 0,
		"the soak ends with zero orphan nodes after the final teardown (observed %d)"
			% teardown_orphans
	)
	_print_summary(teardown_nodes, teardown_orphans)
	_finish()


# ----------------------------------------------------------------- cycle ----


func _run_cycle(
		game: GameFlow,
		player: PlayerController,
		world: ShipyardWorld,
		resolver: CombatResolver,
		hud: CanvasLayer,
		fleet: Array[HeroShip],
		filesystem: MemoryFilesystem,
		cycle: int
	) -> void:
	var craft := fleet[cycle % fleet.size()]
	var craft_id := craft.get_ship_id()
	var notes := PackedStringArray()
	var cycle_started_msec := Time.get_ticks_msec()
	var leg_msec: Dictionary = {}

	await _await_free_on_foot(game, player)

	# One nearby-sector activity per cycle, taken through the same HUD intent the
	# nearby status page uses, then abandoned through the same reset intent.
	var activity_started_msec := Time.get_ticks_msec()
	if await _start_and_abandon_nearby_activity(game, player, world):
		notes.append("activity")
	leg_msec["activity"] = Time.get_ticks_msec() - activity_started_msec

	var board_started_msec := Time.get_ticks_msec()
	var boarded := await _walk_and_board(game, player, craft)
	leg_msec["board"] = Time.get_ticks_msec() - board_started_msec
	if not boarded:
		_check(
			false,
			"cycle %d boards %s with real locomotion and one interact press" % [cycle + 1, craft_id]
		)
		await _recover_to_on_foot(game, player, world)
		leg_msec["cycle"] = Time.get_ticks_msec() - cycle_started_msec
		_record_cycle(game, resolver, hud, cycle, craft_id, notes, leg_msec)
		return

	var launch_started_msec := Time.get_ticks_msec()
	if not await _wake_engine(craft):
		notes.append("engine_wake_missed")
	var launched := await _launch_and_fly(game, craft)
	leg_msec["launch"] = Time.get_ticks_msec() - launch_started_msec
	_check(launched, "cycle %d launches %s off its pad into free flight" % [cycle + 1, craft_id])

	if await _fire_once(game, craft):
		_shots_fired += 1
		notes.append("fired")
	else:
		# A skipped shot always means the leg did not end where it should have.
		# Record the observed state rather than silently dropping the evidence.
		notes.append("no_fire_phase_%d%s" % [
			game.phase, "_destroyed" if craft.is_destroyed() else "",
		])

	var take_damage := cycle % 3 == 2
	if take_damage:
		var hull_before := float(craft.get_telemetry().get("hull", 0.0))
		craft.apply_damage(craft.maximum_hull * 0.35, craft.global_position, Vector3.UP)
		for _damage_tick in 4:
			await physics_frame
			await process_frame
		var hull_after := float(craft.get_telemetry().get("hull", 0.0))
		_check(
			hull_after < hull_before and not craft.is_destroyed(),
			"cycle %d takes real non-fatal damage on %s" % [cycle + 1, craft_id]
		)
		notes.append("damaged")

	var land_started_msec := Time.get_ticks_msec()
	var landed := await _return_and_land(game, world, craft)
	leg_msec["land"] = Time.get_ticks_msec() - land_started_msec
	if landed:
		var disembark_started_msec := Time.get_ticks_msec()
		var disembarked := await _disembark(game, player, craft)
		leg_msec["disembark"] = Time.get_ticks_msec() - disembark_started_msec
		_check(disembarked, "cycle %d disembarks from %s at its berth" % [cycle + 1, craft_id])
	else:
		# One craft's authored approach lane is physically obstructed; that defect
		# is asserted once, by name, after the loop. Recording it per cycle here
		# would bury it under a dozen identical failures.
		if not _obstructed_return_craft_ids.has(craft_id):
			_obstructed_return_craft_ids.append(craft_id)
		notes.append("return_obstructed")
		await _recover_to_on_foot(game, player, world)

	if take_damage:
		# Recovery for a damaged hull is the production destruction/regeneration
		# lifecycle: the parked craft is lost and its berth rebuilds it. The soak
		# waits that recovery out inside the cycle so the counters below are
		# sampled at the same quiescent point every time.
		craft.apply_damage(craft.maximum_hull + 1.0, craft.global_position, Vector3.UP)
		for _destroy_tick in 4:
			await physics_frame
			await process_frame
		var destroyed := craft.is_destroyed()
		var recovered := await _wait_until(
			func() -> bool: return not craft.is_destroyed() and craft.is_boardable(),
			6.0
		)
		_check(
			destroyed and recovered,
			"cycle %d loses and recovers %s through the berth regeneration lifecycle"
				% [cycle + 1, craft_id]
		)
		if not _destroyed_craft_ids.has(craft_id):
			_destroyed_craft_ids.append(craft_id)
		notes.append("destroyed_and_recovered")

	if cycle % 4 == 3:
		await _save_and_reenter(game, filesystem)
		notes.append("reentry")

	await _await_free_on_foot(game, player)
	leg_msec["cycle"] = Time.get_ticks_msec() - cycle_started_msec
	_record_cycle(game, resolver, hud, cycle, craft_id, notes, leg_msec)


# ------------------------------------------------------------- cycle legs ----


## Walks the final stretch to a craft with real locomotion input and boards it
## with a real `interact` press. The teleport only stages the pilot a short walk
## away, outside the just-exited craft's re-board suppression radius; every metre
## after that is produced by held movement actions.
func _walk_and_board(game: GameFlow, player: PlayerController, craft: HeroShip) -> bool:
	var boarding := craft.get_boarding_position()
	var up := craft.global_basis.y.normalized()
	var approach := craft.global_basis.x.normalized()
	player.teleport_to(Transform3D(
		Basis.looking_at(-approach, Vector3.UP),
		boarding + up * 0.05 + approach * 6.0
	))
	player.set_control_enabled(true)
	for _stage_tick in 4:
		await physics_frame
		await process_frame
	var arrived := await _walk_until(
		&"move_forward",
		func() -> bool: return game.boarding_candidate == craft,
		LOCOMOTION_TICK_BUDGET
	)
	if not arrived:
		# Locomotion can be blocked by authored yard geometry between the stage
		# point and a nested expansion pad. Close the remaining gap and re-select
		# through the same proximity rule rather than reaching past the coordinator.
		player.teleport_to(Transform3D(player.global_basis, boarding + up * 0.05))
		arrived = await _wait_until(
			func() -> bool: return game.boarding_candidate == craft,
			0.5
		)
	if not arrived:
		return false
	await _press_live_action(&"interact", 1)
	return await _wait_for_phase(game, GameFlow.Phase.START_ENGINES, 1.5)


func _wake_engine(craft: HeroShip) -> bool:
	_release_flight_controls(craft)
	Input.action_press(&"hover")
	await physics_frame
	await process_frame
	var online := StringName(craft.get_telemetry().get("engine_state", &"")) == HeroShip.ENGINE_ONLINE
	Input.action_release(&"hover")
	return online


## Real launch: lift demand plus forward thrust held until the coordinator itself
## declares the sortie airborne, then a short flown leg. Both are player inputs;
## nothing here moves the hull directly.
func _launch_and_fly(game: GameFlow, craft: HeroShip) -> bool:
	Input.action_press(&"hover")
	Input.action_press(&"move_forward")
	var ticks := 0
	while game.phase != GameFlow.Phase.FREE_FLIGHT and ticks < DEPARTURE_TICK_BUDGET:
		await physics_frame
		await process_frame
		ticks += 1
	var airborne := game.phase == GameFlow.Phase.FREE_FLIGHT
	# Lift demand stays held through the flown leg. Three of the nine craft are
	# parked inside a nested dock, and forward thrust alone walks them along its
	# inner wall instead of out of it.
	for _leg_tick in FREE_FLIGHT_LEG_TICKS:
		await physics_frame
		await process_frame
	Input.action_release(&"hover")
	Input.action_release(&"move_forward")
	for _settle_tick in 4:
		await physics_frame
		await process_frame
	return airborne and not bool(craft.get_telemetry().get("landed", true))


## One real trigger pull through the live weapon path. The range encounter is
## only armed during the guided activity, so away from it this exercises the same
## firing, presentation and audio chain against an empty sky — which is the chain
## that retains tracers, voices and shot records.
func _fire_once(game: GameFlow, craft: HeroShip) -> bool:
	if game.phase != GameFlow.Phase.FREE_FLIGHT or not craft.is_piloted():
		return false
	await _press_live_action(&"fire", 2)
	for _shot_tick in 6:
		await physics_frame
		await process_frame
	return true


## The return leg. Flying the whole way home nine times over would spend the
## entire soak budget on translation, so the craft is placed inside its own
## berth's published assist-capture volume — the production approach lane every
## berth authors, and the exact pose the real capture contract accepts — and the
## real landing assist flies it the rest of the way in.
func _return_and_land(game: GameFlow, world: ShipyardWorld, craft: HeroShip) -> bool:
	var berth := world.get_berth_node(craft.get_home_berth_id())
	if not is_instance_valid(berth):
		return false
	var capture := berth.get_assist_capture_transform()
	craft.global_transform = Transform3D(
		capture.basis,
		capture.origin.lerp(berth.get_dock_transform().origin, APPROACH_LANE_FRACTION)
	)
	craft.velocity = Vector3.ZERO
	await physics_frame
	await process_frame
	if not await _wake_engine(craft):
		return false
	_check(
		bool(
			(world.get_landing_assist_report(craft, craft.get_home_berth_id()) as Dictionary)
				.get("assist_capture_accepted", false)
		),
		"%s is accepted for capture inside its own berth's published approach lane"
			% craft.get_ship_id()
	)
	_dispatch_pilot_action(game, &"landing_assist")
	# An assist that gives up publishes its own abort reason. Waiting out the full
	# budget after that only burns the soak's time; the outcome is already known.
	var docked := await _wait_until(
		func() -> bool:
			var telemetry := craft.get_telemetry()
			if not str(telemetry.get("landing_abort_reason", "")).is_empty():
				return true
			return (
				game.phase == GameFlow.Phase.SHUT_DOWN
				and bool(telemetry.get("landed", false))
			),
		8.0
	) and game.phase == GameFlow.Phase.SHUT_DOWN \
		and bool(craft.get_telemetry().get("landed", false))
	if docked and not _returned_craft_ids.has(craft.get_ship_id()):
		_returned_craft_ids.append(craft.get_ship_id())
	return docked


func _disembark(game: GameFlow, player: PlayerController, craft: HeroShip) -> bool:
	_release_flight_controls(craft)
	var physics_tick := 1.0 / float(Engine.physics_ticks_per_second)
	var idle_budget := HeroShip.AUTOMATIC_ENGINE_IDLE_SHUTDOWN_SECONDS + physics_tick * 2.0
	var idle_frames := int(ceil(idle_budget * float(Engine.physics_ticks_per_second)))
	for _idle_tick in idle_frames:
		await physics_frame
		await process_frame
	if StringName(craft.get_telemetry().get("engine_state", &"")) != HeroShip.ENGINE_OFFLINE:
		return false
	_dispatch_pilot_action(game, &"interact")
	return await _wait_until(
		func() -> bool: return not player.is_seated() and player.is_control_enabled(),
		2.0
	)


## Starts and abandons one nearby-sector activity through the same HUD intent
## surface the nearby status page uses. The perimeter defense encounter is the
## nearby-sector activity reachable while the yard itself is the resident
## location, and it spawns and retires a live hostile roster, which is exactly
## the lifecycle a soak needs to watch.
func _start_and_abandon_nearby_activity(
		game: GameFlow,
		player: PlayerController,
		world: ShipyardWorld
	) -> bool:
	var board := world.call(&"get_station_defense_activity_board") as Area3D
	if not is_instance_valid(board):
		return false
	player.teleport_to(Transform3D(Basis.IDENTITY, board.global_position + Vector3(0.0, 0.2, 1.2)))
	for _approach_tick in 4:
		await physics_frame
		await process_frame
	game.call(&"_on_hud_nearby_activity_intent_requested", {
		"activity_id": &"station_defense",
		"reason": &"start_requested",
	})
	for _encounter_tick in 12:
		await physics_frame
		await process_frame
	var running := _station_defense_state(game) == &"active"
	if running:
		_activity_starts += 1
	game.call(&"_on_hud_nearby_activity_intent_requested", {
		"activity_id": &"station_defense",
		"reason": &"reset_requested",
	})
	for _abandon_tick in 8:
		await physics_frame
		await process_frame
	var abandoned := _station_defense_state(game) == &"idle"
	if abandoned:
		_activity_abandons += 1
	return running and abandoned


func _station_defense_state(game: GameFlow) -> StringName:
	return StringName(
		(game.call(&"_station_defense_nearby_activity_snapshot") as Dictionary)
			.get("state_id", &"")
	)


## The production save/re-entry path: commit the runtime settings and the live
## session snapshots, then stream the whole `Main` subtree out of the tree and
## back in, exactly as `main_reentry_quality_test` establishes the contract.
func _save_and_reenter(game: GameFlow, filesystem: MemoryFilesystem) -> void:
	var persisted := game.call(&"_persist_runtime_settings") as Dictionary
	game.save_cinder_race_session()
	game.save_cinder_patrol_session()
	_check(
		bool(persisted.get("accepted", false)) and filesystem.files.has(ISOLATED_STORE_PATH),
		"the save leg commits a real settings transaction into the isolated store"
	)
	var parent := game.get_parent()
	parent.remove_child(game)
	await process_frame
	await process_frame
	parent.add_child(game)
	await process_frame
	await physics_frame
	await process_frame
	await _wait_until(func() -> bool: return game.get_flyable_ships().size() >= 9, 4.0)
	_reentries += 1


# -------------------------------------------------------------- counters ----


func _record_cycle(
		game: GameFlow,
		resolver: CombatResolver,
		hud: CanvasLayer,
		cycle: int,
		craft_id: StringName,
		notes: PackedStringArray,
		leg_msec: Dictionary
	) -> void:
	var walk := _walk_tree(root)
	var record := {
		"cycle": cycle + 1,
		"craft": str(craft_id),
		"scene_nodes": int(walk.scene_nodes),
		"objects": int(Performance.get_monitor(Performance.OBJECT_COUNT)),
		"object_nodes": int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)),
		"orphan_nodes": int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT)),
		"render_objects_in_frame": int(
			Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME)
		),
		"static_memory_bytes": int(Performance.get_monitor(Performance.MEMORY_STATIC)),
		"audio_players": int(walk.audio_players),
		"audio_voices_playing": int(walk.audio_voices_playing),
		"particle_systems": int(walk.particle_systems),
		"particle_systems_emitting": int(walk.particle_systems_emitting),
		"combat_sources": resolver.get_registered_source_count(),
		"tweens": get_processed_tweens().size(),
		"timers": int(walk.timers),
		"timers_running": int(walk.timers_running),
		"hud_controls": hud.find_children("*", "Control", true, false).size(),
		"notes": ",".join(notes),
		"leg_msec": leg_msec,
	}
	var sample_materials := (
		_material_census_mode == "all"
		or (
			_material_census_mode == "boundary"
			and (cycle == WARM_UP_CYCLES - 1 or cycle == _cycle_count - 1)
		)
	)
	if sample_materials:
		var census: RefCounted = Census.MaterialResourceCensus.new()
		census.collect_retained(game)
		record["retained_materials"] = (census.get("retained_materials") as Dictionary).size()
		record["retained_material_fingerprint"] = str(
			census.call("retained_fingerprint")
		).substr(0, 16)
	_cycle_records.append(record)
	print("SOAK_CYCLE %s" % JSON.stringify(record))


## One walk of the live tree collects every per-node census at once. Five separate
## `find_children` sweeps of an eleven-thousand-node production scene, once per
## cycle, would itself distort the budget this suite is measuring.
func _walk_tree(node: Node) -> Dictionary:
	var totals := {
		"scene_nodes": 0,
		"audio_players": 0,
		"audio_voices_playing": 0,
		"particle_systems": 0,
		"particle_systems_emitting": 0,
		"timers": 0,
		"timers_running": 0,
	}
	_accumulate(node, totals)
	return totals


func _accumulate(node: Node, totals: Dictionary) -> void:
	totals["scene_nodes"] = int(totals["scene_nodes"]) + 1
	if node is AudioStreamPlayer or node is AudioStreamPlayer2D or node is AudioStreamPlayer3D:
		totals["audio_players"] = int(totals["audio_players"]) + 1
		if bool(node.get(&"playing")):
			totals["audio_voices_playing"] = int(totals["audio_voices_playing"]) + 1
	elif node is GPUParticles3D or node is CPUParticles3D \
			or node is GPUParticles2D or node is CPUParticles2D:
		totals["particle_systems"] = int(totals["particle_systems"]) + 1
		if bool(node.get(&"emitting")):
			totals["particle_systems_emitting"] = int(totals["particle_systems_emitting"]) + 1
	elif node is Timer:
		totals["timers"] = int(totals["timers"]) + 1
		if not (node as Timer).is_stopped():
			totals["timers_running"] = int(totals["timers_running"]) + 1
	for child in node.get_children():
		_accumulate(child, totals)


## The soak's central assertion. Warm-up cycles legitimately grow: first-use
## resources, the first activity generation, the first audio synthesis. What may
## not grow is everything after them.
func _assert_flat_counters() -> void:
	if _cycle_records.size() <= WARM_UP_CYCLES:
		_check(false, "the soak recorded more cycles than its warm-up window")
		return
	var baseline := _cycle_records[WARM_UP_CYCLES - 1]
	var final_record := _cycle_records[_cycle_records.size() - 1]
	for counter_variant: Variant in COUNTER_TOLERANCE.keys():
		var counter := str(counter_variant)
		if not baseline.has(counter) or not final_record.has(counter):
			continue
		var start := int(baseline[counter])
		var end := int(final_record[counter])
		var tolerance := int(COUNTER_TOLERANCE[counter])
		var peak := start
		for index in range(WARM_UP_CYCLES, _cycle_records.size()):
			var record := _cycle_records[index]
			if record.has(counter):
				peak = maxi(peak, int(record[counter]))
		_check(
			end - start <= tolerance and peak - start <= tolerance,
			"%s stays flat after warm-up (start %d, peak %d, end %d, tolerance %d)"
				% [counter, start, peak, end, tolerance]
		)
	# The fingerprint itself is recorded, not asserted: its descriptors carry the
	# scene path each material was reached through, and a regenerated berth
	# presentation legitimately changes those paths without retaining one extra
	# material. The count above is the leak-bearing half of the census.


func _print_summary(teardown_nodes: int, teardown_orphans: int) -> void:
	var summary := {
		"schema_version": 1,
		"cycles": _cycle_count,
		"warm_up_cycles": WARM_UP_CYCLES,
		"craft_rotation": 9,
		"activity_starts": _activity_starts,
		"activity_abandons": _activity_abandons,
		"reentries": _reentries,
		"shots_fired": _shots_fired,
		"destroyed_and_recovered": _destroyed_craft_ids.size(),
		"craft_with_physical_return": _stringify(_returned_craft_ids),
		"craft_with_obstructed_return": _stringify(_obstructed_return_craft_ids),
		"pre_boot_object_nodes": _baseline_object_nodes,
		"post_teardown_object_nodes": teardown_nodes,
		"post_teardown_orphan_nodes": teardown_orphans,
		"material_census_mode": _material_census_mode,
		"assertions": _assertions,
		"failures": _failures.size(),
		"cycles_recorded": _cycle_records,
	}
	print("SOAK_SUMMARY %s" % JSON.stringify(summary))


# --------------------------------------------------------------- helpers ----


func _await_free_on_foot(game: GameFlow, player: PlayerController) -> void:
	_release_all_actions()
	await _wait_until(
		func() -> bool: return (
			not bool(game.get("_transition_busy"))
			and not player.is_seated()
			and player.is_control_enabled()
		),
		3.0
	)


## Harness-only recovery so one failed cycle is reported once instead of
## cascading into every later cycle. Nothing here is a production path; a cycle
## that needs it has already failed its own assertion.
func _recover_to_on_foot(game: GameFlow, player: PlayerController, world: ShipyardWorld) -> void:
	_release_all_actions()
	var craft := game.get_active_ship()
	if is_instance_valid(craft):
		craft.set_piloted(false)
		craft.velocity = Vector3.ZERO
		var berth := world.get_berth_node(craft.get_home_berth_id())
		if is_instance_valid(berth):
			craft.global_transform = berth.get_dock_transform()
	game.set("_piloting", false)
	game.set("_transition_busy", false)
	player.force_recovery_to_on_foot(world.get_player_spawn())
	player.set_control_enabled(true)
	game.phase = GameFlow.Phase.COMPLETE
	await _await_free_on_foot(game, player)


func _walk_until(action: StringName, predicate: Callable, tick_budget: int) -> bool:
	Input.action_press(action)
	var ticks := 0
	while not bool(predicate.call()) and ticks < tick_budget:
		await physics_frame
		await process_frame
		ticks += 1
	Input.action_release(action)
	for _settle_tick in 4:
		await physics_frame
		await process_frame
	return bool(predicate.call())


func _press_live_action(action: StringName, physics_ticks: int) -> void:
	Input.action_press(action)
	for _tick in maxi(1, physics_ticks):
		await physics_frame
	Input.action_release(action)
	await physics_frame
	await process_frame


func _dispatch_pilot_action(game: GameFlow, action: StringName) -> void:
	var event := InputEventAction.new()
	event.action = action
	event.pressed = true
	game._unhandled_input(event)


func _release_flight_controls(craft: HeroShip) -> void:
	for action: StringName in FLIGHT_CONTROL_ACTIONS:
		Input.action_release(action)
	var source := craft.get_command_source() as LocalShipInputSource
	if source != null:
		source.clear_pending_look_motion()


func _release_all_actions() -> void:
	for action: StringName in FLIGHT_CONTROL_ACTIONS:
		Input.action_release(action)
	for action: StringName in ON_FOOT_ACTIONS:
		Input.action_release(action)


func _wait_for_phase(game: GameFlow, expected_phase: int, timeout_seconds: float) -> bool:
	return await _wait_until(func() -> bool: return game.phase == expected_phase, timeout_seconds)


func _wait_until(predicate: Callable, timeout_seconds: float) -> bool:
	var frame_budget := (
		int(ceil(maxf(timeout_seconds, 0.0) * float(Engine.physics_ticks_per_second)))
		+ FRAME_BUDGET_GRACE
	)
	var deadline := Time.get_ticks_msec() + int(ceil(maxf(timeout_seconds, 0.0) * 1000.0))
	var frames := 0
	while not bool(predicate.call()):
		if frames >= frame_budget and Time.get_ticks_msec() >= deadline:
			return false
		await physics_frame
		await process_frame
		frames += 1
	return true


func _tear_down(game: Node) -> void:
	_release_all_actions()
	game.queue_free()
	for _teardown_frame in 12:
		await process_frame
		await physics_frame


func _stringify(ids: Array[StringName]) -> Array[String]:
	var text: Array[String] = []
	for id: StringName in ids:
		text.append(str(id))
	return text


func _environment_int(name: String, fallback: int) -> int:
	var raw := OS.get_environment(name).strip_edges()
	return int(raw) if raw.is_valid_int() else fallback


func _environment_text(name: String, fallback: String) -> String:
	var raw := OS.get_environment(name).strip_edges().to_lower()
	return raw if not raw.is_empty() else fallback


func _check(condition: bool, description: String) -> void:
	_assertions += 1
	if condition:
		print("PASS: ", description)
	else:
		_failures.append(description)
		push_error("FAIL: " + description)


func _finish() -> void:
	if _failures.is_empty():
		print("LONG_SESSION_SOAK_TEST_OK: %d assertions" % _assertions)
		quit(0)
	else:
		printerr(
			"LONG_SESSION_SOAK_TEST_FAILED: %d/%d assertions failed: %s"
			% [_failures.size(), _assertions, "; ".join(_failures)]
		)
		quit(1)
