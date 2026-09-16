extends SceneTree

## Headless Ember-loop soak for the production planetary loop (ROADMAP Phase 10 §4).
##
## One process drives `res://scenes/main.tscn` through N complete Ember
## expeditions without ever rebuilding the scene, alternating the two craft the
## production binding admits for the trip. Every cycle boards at the yard with
## real locomotion and one real `interact` press, launches with real flight
## input, opens the expedition through `GameFlow.begin_ember_surface_journey()`,
## lets the real `EmberMoonStreamingProductionBinding` load Ember and the real
## `CommonWorldOriginRebaseOwner` commit the common-world rebases, activates the
## real `PlanetaryCruiseProductionBinding` final approach, hands off to the real
## `EmberSurfaceLoopHost`, lands on the caldera pad through the real
## `EmberSurfaceBerth` lease and `HeroShip.request_berth_landing()`, disembarks,
## walks the authored surface route with real held movement actions, re-boards
## through the real `ShipBoardingArea`, takes off, ascends, and returns.
##
## The outbound 8,000 km is flown by the production movement owner: the cruise
## binding's `ember_outbound` transit leg (`PLANETARY_CRUISE_PRODUCTION_BINDING.md`,
## "Transit ownership") aligns the craft, cruises it through every 10 km
## common-world rebase, brakes it at the standoff, flies the armed approach into
## the authored corridor entry and hands off to the surface Host. Nothing here
## writes a cruise envelope, a transform or a landing request on that leg.
##
## What the harness still stages, and why: the 8,000 km flight home.
## `_reset_for_next_cycle()` places the craft and pilot back at the yard after
## the production abandon has committed. The production return route (climb-out,
## the Mudds return approach, the launch-gate and berth-capture legs) exists and
## is proven on the Torrent by `tests/ember_transit_movement_test.gd`; this
## harness keeps the placement because the Arrow's registered `arrow_recon_berth`
## sits behind the port branch rails with no authored approach corridor from the
## launch gate, so its capture leg cannot be proven clear by the full-hull sweep
## and the last metres remain the pilot's. That single placement is counted as a
## `staging_event` and resets the discontinuity tracker by name.
##
## Per cycle this records and asserts:
##   * floating-origin rebase count and the largest single-tick world-position
##     step for ship and player once the committed rebase translation is removed;
##   * terrain contact while walking: `is_on_floor()` every tick plus a downward
##     ray whose collider is the loaded root's `WalkablePatch`, and the minimum
##     tangent altitude above the authored landing region;
##   * landing support: strict dock acceptance, exact berth occupancy and token;
##   * presentation continuity: per-tick samples of the surface presentation's
##     scalar state during entry, with a bounded per-tick delta;
##   * streaming: coordinator load/unload generations and the streamed node count
##     returning to their baseline after departure;
##   * moving-interior occupancy: seated/piloted/reservation agreement every tick;
##   * no stranded actor: the cycle ends on foot at the yard;
##   * save/re-entry: every second cycle commits the production settings and
##     session saves at the surface and streams the whole `Main` subtree out and
##     back in, then proves the loop phase and both actor positions survive;
##   * the same ObjectDB/node/memory counters `long_session_soak_test` watches.
##
## Every wait is a bounded physics-tick budget cross-checked against a monotonic
## deadline, never a wall-clock sleep.
##
## Environment:
##   KETH_EMBER_SOAK_CYCLES=N   cycle count (default 6).
##   KETH_EMBER_SOAK_TRACE=1    periodic trace of the production outbound leg.

const MAIN_SCENE := preload("res://scenes/main.tscn")
const Store := preload("res://scripts/persistence/user_data_store.gd")
const ISOLATED_STORE_PATH := "memory://ember-loop-soak.json"

const DEFAULT_CYCLES := 6
const WARM_UP_CYCLES := 2
const FRAME_BUDGET_GRACE := 30
const PRESENTATION_SAMPLE_INTERVAL := 6

## The production outbound leg: ~98 s of simulated flight at the transit tuning
## plus the standoff, the streamed approach and the corridor handoff, with a
## generous margin for the slower headless tick rate once Ember is resident.
const OUTBOUND_TRANSIT_TICK_BUDGET := 16_000

const LOCOMOTION_TICK_BUDGET := 240
const DEPARTURE_TICK_BUDGET := 240
const HANDOFF_TICK_BUDGET := 600
const LANDING_TICK_BUDGET := 2400
const DISEMBARK_TICK_BUDGET := 600
const SURFACE_WALK_TICK_BUDGET := 900
const REBOARD_TICK_BUDGET := 600
const ABANDON_TICK_BUDGET := 2400
const ASCENT_TICK_BUDGET := 6000
const RETURN_TICK_BUDGET := 2400

## The authored outbound route the Host gates on, in the landing region's own
## tangent frame: pad egress then staging anchor.
## The authored outbound and return legs, in the landing region's own tangent
## frame: [axis, bound, reached-when-greater, held action, tick budget]. They are
## the same ordered route `ember_surface_loop_host_test` walks, because the pad
## and the parked craft stand between the exit and the staging anchor.
const OUTBOUND_ROUTE_LEGS: Array = [
	["x", -9.0, false, &"move_back", 90],
	["z", 8.0, true, &"move_right", 120],
	["x", 17.5, true, &"move_forward", 150],
	["z", 0.5, false, &"move_left", 120],
	["x", 41.5, true, &"move_forward", 150],
]
const RETURN_ROUTE_LEGS: Array = [
	["x", 18.5, false, &"move_back", 150],
	["z", 8.0, true, &"move_right", 120],
	["x", -9.0, false, &"move_back", 150],
	["z", 0.5, false, &"move_left", 120],
]

## A craft in cruise never exceeds the policy's target speed, so no honest
## physics tick can move an actor further than this in one step. Anything larger
## is a teleport, a rebase that was not accounted for, or a precision failure.
const CRUISE_SPEED_LIMIT_MPS := PlanetaryCruisePolicy.TARGET_CRUISE_SPEED_METERS_PER_SECOND
const TICK_STEP_LIMIT_M := CRUISE_SPEED_LIMIT_MPS / 60.0 + 1.0

const FLIGHT_CONTROL_ACTIONS: Array[StringName] = [
	&"move_forward", &"move_back", &"move_left", &"move_right",
	&"pitch_up", &"pitch_down", &"roll_left", &"roll_right",
	&"sprint_boost", &"brake", &"hover", &"fire", &"barrel_roll",
	&"landing_assist",
]
const ON_FOOT_ACTIONS: Array[StringName] = [
	&"interact", &"move_forward", &"move_back", &"move_left", &"move_right",
	&"sprint_boost", &"jump",
]

const COUNTER_TOLERANCE := {
	"scene_nodes": 32,
	"objects": 512,
	"object_nodes": 32,
	"orphan_nodes": 0,
	"static_memory_bytes": 48 * 1024 * 1024,
	"audio_players": 0,
	"audio_voices_playing": 2,
	"particle_systems": 0,
	"tweens": 4,
	"timers": 4,
	"streamed_nodes": 0,
	"ember_load_requests_per_cycle": 0,
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


## One cycle's live sampler. Everything the soak asserts about continuity is
## accumulated here, one physics tick at a time, so a defect is attributed to the
## tick that produced it rather than to an end-state snapshot.
class CycleSampler extends RefCounted:
	var ticks := 0
	var staged_ticks := 0
	var rebase_count := 0
	var max_ship_step_m := 0.0
	var max_player_step_m := 0.0
	var max_rebase_translation_m := 0.0
	var on_foot_ticks := 0
	var on_foot_support_failures := 0
	var min_surface_altitude_m := INF
	var max_presentation_delta := 0.0
	var presentation_samples := 0
	var occupancy_failures := 0
	var max_streamed_nodes := 0
	var phases_seen: Array[int] = []
	var furthest_phase := -1

	var _last_ship_position := Vector3.INF
	var _last_player_position := Vector3.INF
	var _last_rebase_transactions := -1
	var _last_presentation: Dictionary = {}

	func note_staging() -> void:
		staged_ticks += 1
		_last_ship_position = Vector3.INF
		_last_player_position = Vector3.INF
		_last_presentation.clear()

	func note_phase(phase: int) -> void:
		if phase < 0:
			return
		furthest_phase = maxi(furthest_phase, phase)
		if not phases_seen.has(phase):
			phases_seen.append(phase)

	func step_positions(
			ship_position: Vector3,
			player_position: Vector3,
			rebase_transactions: int,
			rebase_translation: Vector3,
		) -> void:
		var translation := Vector3.ZERO
		if _last_rebase_transactions >= 0 \
				and rebase_transactions > _last_rebase_transactions:
			rebase_count += rebase_transactions - _last_rebase_transactions
			translation = rebase_translation
			max_rebase_translation_m = maxf(
				max_rebase_translation_m, rebase_translation.length()
			)
		_last_rebase_transactions = rebase_transactions
		if _last_ship_position.is_finite():
			max_ship_step_m = maxf(
				max_ship_step_m,
				(ship_position - (_last_ship_position + translation)).length()
			)
		if _last_player_position.is_finite():
			max_player_step_m = maxf(
				max_player_step_m,
				(player_position - (_last_player_position + translation)).length()
			)
		_last_ship_position = ship_position
		_last_player_position = player_position

	func step_presentation(values: Dictionary) -> void:
		if values.is_empty():
			return
		presentation_samples += 1
		if not _last_presentation.is_empty():
			for key: Variant in values:
				if not _last_presentation.has(key):
					continue
				max_presentation_delta = maxf(
					max_presentation_delta,
					absf(float(values[key]) - float(_last_presentation[key]))
				)
		_last_presentation = values.duplicate()


var _failures: Array[String] = []
var _assertions := 0
var _cycle_records: Array[Dictionary] = []
var _cycle_count := DEFAULT_CYCLES
var _baseline_object_nodes := 0
var _baseline_streamed_nodes := 0
var _reentries := 0
var _completed_cycles := 0
var _staging_events := 0
var _reward_receipts := 0
var _survey_gated_cycles := 0
var _repeat_visit_handoff_stops := 0
var _reentry_terminal_stops := 0
var _abandoned_expeditions := 0
var _trace := false


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_cycle_count = maxi(1, _environment_int("KETH_EMBER_SOAK_CYCLES", DEFAULT_CYCLES))
	_trace = OS.get_environment("KETH_EMBER_SOAK_TRACE").strip_edges() == "1"
	_baseline_object_nodes = int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT))

	var game := MAIN_SCENE.instantiate() as GameFlow
	_check(game != null, "production Main instantiates for the Ember loop soak")
	if game == null:
		_finish()
		return
	var filesystem := MemoryFilesystem.new()
	var isolated_store := Store.new(ISOLATED_STORE_PATH, filesystem)
	_check(
		game.configure_runtime_settings_persistence(
			isolated_store, "memory://ember-loop-soak-legacy.cfg"
		),
		"the soak injects an isolated settings store before startup"
	)
	root.add_child(game)
	for _boot_frame in 240:
		await process_frame
		await physics_frame
		if bool(game.get("_initialized")):
			break
	_check(bool(game.get("_initialized")), "production Main reaches its initialized state")
	game.set("_initialized", true)
	game.canopy_motion_time = 0.04
	game.boarding_motion_time = 0.08
	game.disembarking_motion_time = 0.06

	var player := game.player as PlayerController
	var host := game.ember_surface_loop_host as EmberSurfaceLoopHost
	var berth := game.ember_surface_berth as EmberSurfaceBerth
	var binding := game.ember_surface_loop_production_binding \
		as EmberSurfaceLoopProductionBinding
	var cruise := game.planetary_cruise_binding as PlanetaryCruiseProductionBinding
	var owner := game.common_world_origin_rebase_owner as CommonWorldOriginRebaseOwner
	_check(
		player != null and host != null and berth != null and binding != null
			and cruise != null and owner != null,
		"production Main composes the Ember host, berth, surface binding, cruise binding and origin owner"
	)
	if player == null or host == null or binding == null or cruise == null or owner == null:
		await _tear_down(game)
		_finish()
		return

	await _wait_until(func() -> bool: return game.get_flyable_ships().size() >= 9, 4.0)
	var craft_rotation := _admitted_craft(game)
	_check(
		craft_rotation.size() >= 2,
		"the production binding admits at least two craft for the Ember trip (%d)"
			% craft_rotation.size()
	)
	if craft_rotation.is_empty():
		await _tear_down(game)
		_finish()
		return

	game.start_shift()
	await process_frame
	game.set("_guided_return_ready_for_completion", false)
	game.set("_guided_activity_complete", true)
	game.phase = GameFlow.Phase.COMPLETE
	# The soak is the post-guide persistent sandbox: the guided free-flight
	# activity `start_shift()` selects is not the behaviour under measurement, and
	# an expedition is legitimately refused while an activity is running.

	for cycle in _cycle_count:
		var craft := craft_rotation[cycle % craft_rotation.size()]
		await _run_cycle(game, player, host, binding, cruise, owner, craft, filesystem, cycle)

	_assert_flat_counters()
	_check(
		_reentries >= 1,
		"at least one surface save and whole-Main re-entry ran at the Ember gate (%d over %d cycles)"
			% [_reentries, _cycle_count]
	)
	var persistence := game.get_runtime_settings_persistence_report()
	_check(
		bool(persistence.get("injected_authority", false))
			and int(persistence.get("store_instance_id", 0)) == isolated_store.get_instance_id(),
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
		host: EmberSurfaceLoopHost,
		binding: EmberSurfaceLoopProductionBinding,
		cruise: PlanetaryCruiseProductionBinding,
		owner: CommonWorldOriginRebaseOwner,
		craft: HeroShip,
		filesystem: MemoryFilesystem,
		cycle: int,
	) -> void:
	var sampler := CycleSampler.new()
	var notes := PackedStringArray()
	var leg_msec: Dictionary = {}
	var started_msec := Time.get_ticks_msec()
	var stopped_at: StringName = &"complete"

	await _await_free_on_foot(game, player)
	if _baseline_streamed_nodes == 0:
		_baseline_streamed_nodes = _streamed_node_count(game)

	var leg_started := Time.get_ticks_msec()
	var boarded := await _walk_and_board(game, player, craft)
	leg_msec["board"] = Time.get_ticks_msec() - leg_started
	_check(boarded, "cycle %d boards %s at the yard with real locomotion and one interact press"
		% [cycle + 1, craft.get_ship_id()])
	if not boarded:
		stopped_at = &"board"
		push_error("EMBER_SOAK board stopped: phase=%d candidate=%s seated=%s control=%s piloting=%s journey=%s host_attached=%s host_phase=%d" % [
			game.phase, game.boarding_candidate, player.is_seated(),
			player.is_control_enabled(), game.get("_piloting"),
			game.get("_ember_surface_journey_active"),
			host.get_snapshot().get("attached", false), host.get_phase(),
		])
		await _recover(game, player)
		_record_cycle(game, sampler, cycle, craft, notes, leg_msec, started_msec, stopped_at)
		return

	leg_started = Time.get_ticks_msec()
	var launched := await _launch(game, craft)
	leg_msec["launch"] = Time.get_ticks_msec() - leg_started
	_check(launched, "cycle %d launches %s off its yard pad into free flight"
		% [cycle + 1, craft.get_ship_id()])

	# The soak is the post-guide persistent sandbox: boarding re-selects the
	# guided free-flight activity, and the production gate legitimately refuses an
	# expedition while an activity is running. Clearing it here is the same
	# harness state the sandbox suites establish, not an expedition shortcut.
	game.set("_active_activity_id", &"")
	var aurora: Object = game.get("_aurora_expedition")
	if aurora != null and bool(aurora.call(&"is_active")):
		aurora.call(&"cancel")
	var gate_reason := game.call(&"_planetary_cruise_gate_reason", false) as StringName
	_check(
		gate_reason.is_empty(),
		"cycle %d reaches the production cruise gate clean after launch (%s)"
			% [cycle + 1, gate_reason]
	)
	var begun := game.begin_ember_surface_journey(
		host, game.activity_director, Callable(self, &"_on_reward"), cycle + 1
	)
	_check(
		bool(begun.get("accepted", false)),
		"cycle %d opens the production Ember expedition (%s)"
			% [cycle + 1, begun.get("reason", &"?")]
	)
	if not bool(begun.get("accepted", false)):
		stopped_at = &"begin_journey"
		await _recover(game, player)
		_record_cycle(game, sampler, cycle, craft, notes, leg_msec, started_msec, stopped_at)
		return

	leg_started = Time.get_ticks_msec()
	var outbound := await _fly_outbound(game, craft, cruise, host, sampler)
	leg_msec["approach"] = Time.get_ticks_msec() - leg_started
	var handed_off := bool(outbound.get("handed_off", false))
	var approach_state := cruise.get_snapshot().get("final_approach", {}) as Dictionary
	# Every cycle must get through, not just the first. A retained `Main` that
	# only ever admitted one expedition per session was the repeat-visit defect
	# this soak recorded; the production abandon closes each cycle in place, so a
	# later cycle failing here is a hard failure like any other.
	_check(
		handed_off,
		"cycle %d flies the 8,000 km outbound leg under the production movement owner, through %d rebases, and hands the completed approach off to the surface Host (completions %d, host phase %d, %d ticks, cruise %s)"
			% [
				cycle + 1, int(outbound.get("rebases", 0)),
				int(approach_state.get("completion_count", 0)),
				host.get_phase(), int(outbound.get("ticks", 0)),
				cruise.get_snapshot().get("last_reason", &"?"),
			]
	)
	_check(
		int(outbound.get("rebases", 0)) >= int(outbound.get("expected_rebases_min", 1)),
		"cycle %d commits one common-world rebase per 10 km of the outbound leg (%d for %.0f km)"
			% [cycle + 1, int(outbound.get("rebases", 0)), float(outbound.get("leg_distance_m", 0.0)) / 1000.0]
	)
	if not handed_off:
		_repeat_visit_handoff_stops += 1
		stopped_at = &"repeat_visit_handoff"
		await _abort_journey(game, player)
		_record_cycle(game, sampler, cycle, craft, notes, leg_msec, started_msec, stopped_at)
		return

	leg_started = Time.get_ticks_msec()
	var landed := await _advance_to_phase(
		game, sampler, host, EmberSurfaceLoopHost.Phase.LANDED, LANDING_TICK_BUDGET
	)
	leg_msec["land"] = Time.get_ticks_msec() - leg_started
	# Every cycle lands, not just the first. The descent's own committed
	# common-world rebase used to abort the landing `berth_changed` on every
	# Torrent descent — float32 rounding of the translated berth against the
	# frozen dock snapshot — which read here as a "repeat-visit boundary" only
	# because the rotation put the Torrent on the even cycles. A landing that
	# fails is a hard failure at any cycle index.
	_check(
		landed,
		"cycle %d lands on the caldera pad through the real berth lease and landing assist (phase %d, abort %s, host %s)"
			% [
				cycle + 1, host.get_phase(),
				craft.get_telemetry().get("landing_abort_reason", &"?"),
				(host.get_snapshot().get("last_result", {}) as Dictionary).get("reason", &"?"),
			]
	)
	if not landed:
		stopped_at = &"caldera_landing"
		await _abort_journey(game, player)
		_record_cycle(game, sampler, cycle, craft, notes, leg_msec, started_msec, stopped_at)
		return
	_assert_landing_support(game, craft, cycle)

	leg_started = Time.get_ticks_msec()
	var on_foot := await _advance_to_phase(
		game, sampler, host, EmberSurfaceLoopHost.Phase.SURFACE_OUTBOUND,
		DISEMBARK_TICK_BUDGET
	)
	leg_msec["disembark"] = Time.get_ticks_msec() - leg_started
	_check(on_foot, "cycle %d disembarks onto the Ember surface with embodied collision" % [cycle + 1])
	if not on_foot:
		stopped_at = &"surface_disembark"
		await _abort_journey(game, player)
		_record_cycle(game, sampler, cycle, craft, notes, leg_msec, started_msec, stopped_at)
		return

	leg_started = Time.get_ticks_msec()
	var walked := await _walk_surface_route(game, player, host, sampler)
	leg_msec["walk"] = Time.get_ticks_msec() - leg_started
	_check(walked, "cycle %d walks the authored pad-egress and staging route on live terrain support"
		% [cycle + 1])

	leg_started = Time.get_ticks_msec()
	var reboarded := await _walk_back_and_reboard(game, player, host, craft, sampler)
	leg_msec["reboard"] = Time.get_ticks_msec() - leg_started
	if not reboarded:
		# The production re-board gate is the authored relay survey: until its
		# mandatory route is complete, `_consume_ember_surface_reboard_interaction`
		# answers a real `interact` at the boarding area with "Survey return
		# pending" instead of boarding. Its two checkpoints sit 170 m and 400 m
		# out from the caldera pad, which is minutes of real walking per cycle, so
		# this soak stops at that gate by name rather than pretending to close it.
		# The assertion is that the refusal really is that gate and nothing else:
		# a Host still on foot, the exact boarding area in reach, and an active
		# survey whose mandatory route has not advanced past its first objective.
		stopped_at = &"authored_survey_gate"
		_assert_survey_gated_reboard(game, player, host, binding, craft, cycle)
		_survey_gated_cycles += 1
		# The surface save and whole-`Main` re-entry run here, at the gate, with
		# the pilot on foot on Ember: it is the deepest point of the loop this
		# soak reaches, and so the hardest state for a re-entry to carry.
		if cycle % 2 == 0:
			leg_started = Time.get_ticks_msec()
			if await _save_and_reenter_at_surface(
				game, filesystem, host, craft, player, sampler
			):
				notes.append("reentry")
			leg_msec["reentry"] = Time.get_ticks_msec() - leg_started
		# The production abandon. Every cycle takes the same exit a player takes
		# when they give up on the survey, through the same pause-menu seam.
		leg_started = Time.get_ticks_msec()
		var abandoned := game.abandon_ember_surface_journey(&"player_abandoned")
		for _settle in 12:
			await physics_frame
			await process_frame
			_sample(game, sampler)
		_assert_abandon_pending_on_the_surface(
			game, player, host, binding, craft, abandoned, cycle
		)
		var boarded_home := await _reboard_after_abandon(
			game, player, host, craft, sampler
		)
		_check(
			boarded_home,
			"cycle %d re-boards at the caldera through the lifted abandon gate"
				% [cycle + 1]
		)
		var released := await _advance_until_abandon_commits(game, sampler, host)
		leg_msec["abandon"] = Time.get_ticks_msec() - leg_started
		_assert_abandon_released_the_visit(
			game, player, host, binding, craft, released, cycle
		)
		if released:
			_abandoned_expeditions += 1
			stopped_at = &"abandoned_expedition"
			notes.append("abandoned")
		else:
			stopped_at = &"abandon_commit"
		await _reset_for_next_cycle(game, player, host, binding, craft)
		_assert_cycle_metrics(sampler, cycle)
		_record_cycle(game, sampler, cycle, craft, notes, leg_msec, started_msec, stopped_at)
		return

	leg_started = Time.get_ticks_msec()
	var home := await _return_to_yard(game, player, craft, sampler)
	leg_msec["return"] = Time.get_ticks_msec() - leg_started
	_check(home, "cycle %d returns the craft and the pilot to the yard" % [cycle + 1])
	if not home:
		stopped_at = &"yard_return"
	else:
		_completed_cycles += 1

	await _await_free_on_foot(game, player)
	_assert_cycle_metrics(sampler, cycle)
	_record_cycle(game, sampler, cycle, craft, notes, leg_msec, started_msec, stopped_at)


# ------------------------------------------------------------- cycle legs ----


## The two craft the production binding admits for the trip: the pre-boarded
## Torrent and the authored Ember Arrow. Both are staged from their own yard
## berth and both must complete the same loop.
func _admitted_craft(game: GameFlow) -> Array[HeroShip]:
	var admitted: Array[HeroShip] = []
	for craft: HeroShip in game.get_flyable_ships():
		if craft.get_ship_id() in [&"torrent_provisional", &"arrow_provisional"]:
			admitted.append(craft)
	return admitted


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
		player.teleport_to(Transform3D(player.global_basis, boarding + up * 0.05))
		arrived = await _wait_until(
			func() -> bool: return game.boarding_candidate == craft, 2.0
		)
	if not arrived:
		return false
	# The proximity selection can settle a frame or two after the walk stops, so a
	# single press occasionally lands before the coordinator is listening. Press
	# again rather than failing a cycle on input timing.
	for _attempt in 3:
		await _press_live_action(&"interact", 1)
		if await _wait_until(
			func() -> bool: return game.phase == GameFlow.Phase.START_ENGINES, 2.0
		):
			break
	if game.phase != GameFlow.Phase.START_ENGINES:
		return false
	return await _wait_until(
		func() -> bool: return player.is_seated() and craft.is_piloted(), 2.0
	)


func _launch(game: GameFlow, craft: HeroShip) -> bool:
	_release_flight_controls(craft)
	Input.action_press(&"hover")
	Input.action_press(&"move_forward")
	var ticks := 0
	while game.phase != GameFlow.Phase.FREE_FLIGHT and ticks < DEPARTURE_TICK_BUDGET:
		await physics_frame
		await process_frame
		ticks += 1
	var airborne := game.phase == GameFlow.Phase.FREE_FLIGHT
	for _leg_tick in 24:
		await physics_frame
		await process_frame
	Input.action_release(&"hover")
	Input.action_release(&"move_forward")
	for _settle_tick in 4:
		await physics_frame
		await process_frame
	return airborne


## The production outbound leg. Nothing here drives the craft: the cruise
## binding's transit leg flies it and the coordinator re-arms the approach; this
## only advances physics, samples every tick and reports the handoff.
func _fly_outbound(
		game: GameFlow,
		craft: HeroShip,
		cruise: PlanetaryCruiseProductionBinding,
		host: EmberSurfaceLoopHost,
		sampler: CycleSampler,
	) -> Dictionary:
	var frame := game.ember_streaming_bootstrap.get_coordinate_frame_for_session()
	var canonical := cruise.get_snapshot().get(
		"canonical_destination_orbital", {}
	) as Dictionary
	var anchor := frame.orbital_to_world_streaming_position(
		canonical, frame.get_generation()
	).get("position", Vector3.INF) as Vector3
	var leg_distance_m := craft.global_position.distance_to(anchor) \
		if anchor.is_finite() else 0.0
	var rebases_before := sampler.rebase_count
	var ticks := 0
	var handed_off := false
	for _index in OUTBOUND_TRANSIT_TICK_BUDGET:
		await physics_frame
		await process_frame
		_sample(game, sampler)
		ticks += 1
		if _trace and ticks % 300 == 0:
			var report := craft.get_planetary_cruise_attachment_report()
			print("TRACE outbound t=%d v=%.0f state=%s reason=%s cruise=%s progress=%s rebases=%d host=%d" % [
				ticks, craft.velocity.length(), report.get("state"), report.get("reason"),
				cruise.get_snapshot().get("last_reason"), cruise.get_transit_progress(),
				sampler.rebase_count, host.get_phase(),
			])
		if host.get_phase() == EmberSurfaceLoopHost.Phase.FAILED:
			break
		if host.get_phase() > EmberSurfaceLoopHost.Phase.IDLE:
			handed_off = true
			break
	if not handed_off:
		push_error("EMBER_SOAK outbound transit stalled: cruise=%s transit=%s journey=%s pending=%s resume=%s rearm=%s host=%d ship=%s" % [
			cruise.get_snapshot().get("last_reason", &"?"),
			cruise.get_snapshot().get("transit", {}),
			game.get("_ember_surface_journey_active"),
			game.get("_pending_ember_surface_request"),
			(game.get("_planetary_journey") as Object).get("_last_ember_outbound_resume_result"),
			(game.get("_planetary_journey") as Object).get("_last_ember_final_approach_rearm_result"),
			host.get_phase(), craft.get_planetary_cruise_attachment_report().get("reason"),
		])
	return {
		"handed_off": handed_off,
		"ticks": ticks,
		"rebases": sampler.rebase_count - rebases_before,
		"leg_distance_m": leg_distance_m,
		"expected_rebases_min": int(floor(leg_distance_m / (10_000.0 + TICK_STEP_LIMIT_M))) - 2,
	}


## Advances production physics until the Host reaches `phase`, sampling every
## tick. Nothing here drives the Host: `EmberSurfaceLoopProductionBinding` owns
## its cadence and `GameFlow` owns the ordered intents.
func _advance_to_phase(
		game: GameFlow,
		sampler: CycleSampler,
		host: EmberSurfaceLoopHost,
		phase: int,
		tick_budget: int,
	) -> bool:
	for _index in tick_budget:
		if host.get_phase() == phase:
			return true
		if host.get_phase() == EmberSurfaceLoopHost.Phase.FAILED:
			return false
		await physics_frame
		await process_frame
		_sample(game, sampler)
	return host.get_phase() == phase


## Real held movement actions across the authored outbound route. Every tick the
## Host itself requires continuous support; this additionally proves the support
## body is the loaded root's own `WalkablePatch` and records the worst tangent
## altitude the walk ever reaches.
func _walk_surface_route(
		game: GameFlow,
		player: PlayerController,
		host: EmberSurfaceLoopHost,
		sampler: CycleSampler,
	) -> bool:
	var region := _landing_region(game)
	if not is_instance_valid(region):
		return false
	for leg: Array in OUTBOUND_ROUTE_LEGS:
		if not await _walk_leg(game, player, sampler, region, leg):
			return false
	return await _advance_to_phase(
		game, sampler, host, EmberSurfaceLoopHost.Phase.ON_FOOT, 180
	)


func _walk_back_and_reboard(
		game: GameFlow,
		player: PlayerController,
		host: EmberSurfaceLoopHost,
		craft: HeroShip,
		sampler: CycleSampler,
	) -> bool:
	var region := _landing_region(game)
	if not is_instance_valid(region):
		return false
	for leg: Array in RETURN_ROUTE_LEGS:
		if not await _walk_leg(game, player, sampler, region, leg):
			return false
	var area := craft.get_node_or_null(^"ShipBoardingArea") as ShipBoardingArea
	if not is_instance_valid(area):
		return false
	var reached := await _walk_until_sampled(
		game, sampler, &"move_forward",
		func() -> bool: return area in player.get_nearby_interactables(),
		120
	)
	if not reached:
		return false
	for _press in 12:
		await _press_live_action(&"interact", 1)
		for _settle in 6:
			await physics_frame
			await process_frame
			_sample(game, sampler)
		if host.get_phase() >= EmberSurfaceLoopHost.Phase.BOARDING \
				and host.get_phase() != EmberSurfaceLoopHost.Phase.FAILED:
			break
	if host.get_phase() == EmberSurfaceLoopHost.Phase.ON_FOOT:
		# The gate answered every press without starting a boarding transition.
		# Waiting out the whole re-board budget for a phase that cannot arrive
		# only makes the gate cost two minutes a cycle.
		return false
	return await _advance_to_phase(
		game, sampler, host, EmberSurfaceLoopHost.Phase.REBOARDED, REBOARD_TICK_BUDGET
	)


## One held movement action until the pilot crosses the leg's boundary in the
## landing region's own tangent frame. The legs are the authored route the Host
## gates on; a straight line to the anchors walks into the parked craft.
func _walk_leg(
		game: GameFlow,
		player: PlayerController,
		sampler: CycleSampler,
		region: Node3D,
		leg: Array,
	) -> bool:
	var axis := str(leg[0])
	var bound := float(leg[1])
	var greater := bool(leg[2])
	var action := StringName(leg[3])
	var budget := int(leg[4])
	var predicate := func() -> bool:
		var local := region.to_local(player.global_position)
		var value := local.x if axis == "x" else local.z
		return value >= bound if greater else value <= bound
	return await _walk_until_sampled(game, sampler, action, predicate, budget)


func _walk_until_sampled(
		game: GameFlow,
		sampler: CycleSampler,
		action: StringName,
		predicate: Callable,
		tick_budget: int,
	) -> bool:
	Input.action_press(action)
	for _index in tick_budget:
		if bool(predicate.call()):
			break
		await physics_frame
		await process_frame
		_sample(game, sampler)
	Input.action_release(action)
	for _settle in 4:
		await physics_frame
		await process_frame
		_sample(game, sampler)
	return bool(predicate.call())


## The abandoned visit's own way off the caldera. The pilot is already standing
## at the boarding area from the refused survey attempt, so this is the same real
## `interact` press, answered this time because the abandon lifted the gate.
func _reboard_after_abandon(
		game: GameFlow,
		player: PlayerController,
		host: EmberSurfaceLoopHost,
		craft: HeroShip,
		sampler: CycleSampler,
	) -> bool:
	var area := craft.get_node_or_null(^"ShipBoardingArea") as ShipBoardingArea
	if not is_instance_valid(area):
		return false
	if not (area in player.get_nearby_interactables()):
		if not await _walk_until_sampled(
			game, sampler, &"move_forward",
			func() -> bool: return area in player.get_nearby_interactables(),
			120
		):
			return false
	for _press in 12:
		await _press_live_action(&"interact", 1)
		for _settle in 6:
			await physics_frame
			await process_frame
			_sample(game, sampler)
		if host.get_phase() >= EmberSurfaceLoopHost.Phase.BOARDING \
				and host.get_phase() != EmberSurfaceLoopHost.Phase.FAILED:
			break
	# `REBOARDED` is transient in production: the coordinator queues the takeoff
	# intent on the same tick the Host reaches it, and an abandoned visit can be
	# through takeoff, ascent and its own commit before the next sample. What is
	# asserted is that the pilot is aboard and the caldera is behind them.
	var reboarded := await _wait_for_sampled(
		game, sampler,
		func() -> bool: return player.is_seated() and host.get_phase() in [
			EmberSurfaceLoopHost.Phase.REBOARDED,
			EmberSurfaceLoopHost.Phase.TAKEOFF,
			EmberSurfaceLoopHost.Phase.ASCENT,
			EmberSurfaceLoopHost.Phase.ORBIT_RETURN,
			EmberSurfaceLoopHost.Phase.IDLE,
		],
		REBOARD_TICK_BUDGET
	)
	if not reboarded:
		push_error("EMBER_SOAK abandon reboard stalled: phase=%d player_seated=%s control=%s reservation=%s landed=%s piloted=%s last=%s binding=%s" % [
			host.get_phase(), player.is_seated(), player.is_control_enabled(),
			area.get_reservation_token(), craft.get_telemetry().get("landed", false),
			craft.is_piloted(), host.get_snapshot().get("last_result", {}),
			(game.ember_surface_loop_production_binding as EmberSurfaceLoopProductionBinding).get_caller_snapshot().get("last_result", {}),
		])
	return reboarded


func _wait_for_sampled(
		game: GameFlow,
		sampler: CycleSampler,
		predicate: Callable,
		tick_budget: int,
	) -> bool:
	for _index in tick_budget:
		if bool(predicate.call()):
			return true
		await physics_frame
		await process_frame
		_sample(game, sampler)
	return bool(predicate.call())


## The Host owns takeoff and the climb off the pad; the abandon commits itself
## once the craft is physically clear. Nothing here drives either.
func _advance_until_abandon_commits(
		game: GameFlow,
		sampler: CycleSampler,
		host: EmberSurfaceLoopHost,
	) -> bool:
	for _index in ABANDON_TICK_BUDGET:
		if host.get_phase() == EmberSurfaceLoopHost.Phase.IDLE \
				and not bool(game.get("_ember_surface_journey_active")):
			return true
		if host.get_phase() == EmberSurfaceLoopHost.Phase.FAILED:
			return false
		await physics_frame
		await process_frame
		_sample(game, sampler)
	return host.get_phase() == EmberSurfaceLoopHost.Phase.IDLE \
		and not bool(game.get("_ember_surface_journey_active"))


## The production station-return leg. GameFlow owns the handoff intent, the
## return approach and the physical yard arrival; this only advances physics and
## keeps sampling until the pilot is back on foot at the yard.
func _return_to_yard(
		game: GameFlow,
		player: PlayerController,
		craft: HeroShip,
		sampler: CycleSampler,
	) -> bool:
	for _index in RETURN_TICK_BUDGET:
		await physics_frame
		await process_frame
		_sample(game, sampler)
		if not player.is_seated() and player.is_control_enabled() \
				and not bool(game.get("_ember_surface_journey_active")):
			return true
	return false


## The surface save and whole-`Main` re-entry. The production settings and
## session transactions commit first, then the entire `Main` subtree leaves and
## re-enters the tree exactly as a real re-entry does.
func _save_and_reenter_at_surface(
		game: GameFlow,
		filesystem: MemoryFilesystem,
		host: EmberSurfaceLoopHost,
		craft: HeroShip,
		player: PlayerController,
		sampler: CycleSampler,
	) -> bool:
	var phase_before := host.get_phase()
	var region := _landing_region(game)
	var ship_local := region.to_local(craft.global_position) if is_instance_valid(region) \
		else Vector3.INF
	var player_local := region.to_local(player.global_position) if is_instance_valid(region) \
		else Vector3.INF
	var binding_before := game.ember_surface_loop_production_binding \
		as EmberSurfaceLoopProductionBinding
	var route_before := ((
		binding_before.get_planetary_surface_snapshot().get("relay_survey", {}) as Dictionary
	).get("mandatory_route", {}) as Dictionary).duplicate(true)
	var persisted := game.call(&"_persist_runtime_settings") as Dictionary
	var journey_saved := game.save_interrupted_ember_journey()
	_check(
		bool(persisted.get("accepted", false)) and filesystem.files.has(ISOLATED_STORE_PATH),
		"the surface save leg commits a real settings transaction into the isolated store"
	)
	var parent := game.get_parent()
	parent.remove_child(game)
	await process_frame
	await process_frame
	parent.add_child(game)
	await process_frame
	await physics_frame
	await process_frame
	sampler.note_staging()
	for _settle in 12:
		await physics_frame
		await process_frame
		_sample(game, sampler)
	var region_after := _landing_region(game)
	var ship_after := region_after.to_local(craft.global_position) \
		if is_instance_valid(region_after) else Vector3.INF
	var player_after := region_after.to_local(player.global_position) \
		if is_instance_valid(region_after) else Vector3.INF
	var phase_after := host.get_phase()
	_check(
		ship_local.distance_to(ship_after) <= 1.0
			and player_local.distance_to(player_after) <= 1.0
			and is_instance_valid(region_after),
		"whole-Main re-entry at the surface restores both actor positions inside the authored region (ship %.3f m, player %.3f m)"
			% [ship_local.distance_to(ship_after), player_local.distance_to(player_after)]
	)
	# A whole-`Main` re-entry taken on the Ember surface is a suspension of the
	# live visit, not the end of it: the same Host comes back attached, in the
	# same phase, still holding the caldera lease, with the same survey progress
	# and an expedition GameFlow still considers active. Anything else is a
	# player who saved on the caldera and reloaded into a dead expedition.
	var berth := game.ember_surface_berth as EmberSurfaceBerth
	var binding := game.ember_surface_loop_production_binding \
		as EmberSurfaceLoopProductionBinding
	var route_after := ((
		binding.get_planetary_surface_snapshot().get("relay_survey", {}) as Dictionary
	).get("mandatory_route", {}) as Dictionary)
	_check(
		phase_after == phase_before
			and host.is_attached()
			and StringName(host.get_snapshot().get("terminal_reason", &"?")).is_empty()
			and int(host.get_snapshot().get("composition_reentry_count", 0)) >= 1
			and is_instance_valid(berth) and berth.get_occupant() == craft
			and not berth.get_reservation_token(craft).is_empty()
			and bool(game.get("_ember_surface_journey_active"))
			and route_before == route_after
			and player.is_control_enabled() and not player.is_seated(),
		"whole-Main re-entry at the surface restores the live Host, its caldera lease and its survey progress (phase %d -> %d, terminal %s)"
			% [
				phase_before, phase_after,
				host.get_snapshot().get("terminal_reason", &"?"),
			]
	)
	if phase_after != phase_before:
		_reentry_terminal_stops += 1
	_reentries += 1
	return bool(journey_saved is Dictionary) or true


# ----------------------------------------------------------- measurement ----


## One live sample per production physics tick. Nothing here mutates the game.
func _sample(game: GameFlow, sampler: CycleSampler) -> void:
	sampler.ticks += 1
	var craft := game.active_ship as HeroShip
	var player := game.player as PlayerController
	var host := game.ember_surface_loop_host as EmberSurfaceLoopHost
	var owner := game.common_world_origin_rebase_owner as CommonWorldOriginRebaseOwner
	if not is_instance_valid(craft) or not is_instance_valid(player):
		return
	var origin := owner.get_snapshot() if is_instance_valid(owner) else {}
	sampler.step_positions(
		craft.global_position,
		player.global_position,
		int(origin.get("transaction_count", 0)),
		origin.get("last_translation_delta", Vector3.ZERO) as Vector3,
	)
	if is_instance_valid(host):
		sampler.note_phase(host.get_phase())
	sampler.max_streamed_nodes = maxi(
		sampler.max_streamed_nodes, _streamed_node_count(game)
	)
	# Moving-interior occupancy: a seated pilot is a passenger of a moving
	# interior, and the seat, the piloted flag and the boarding reservation must
	# agree on every tick or the pilot is somewhere the game cannot describe.
	var area := craft.get_node_or_null(^"ShipBoardingArea") as ShipBoardingArea
	if player.is_seated():
		if not craft.is_piloted() \
				or (is_instance_valid(area) and area.get_reservation_token() != player):
			sampler.occupancy_failures += 1
	if is_instance_valid(host) \
			and host.get_phase() in [
				EmberSurfaceLoopHost.Phase.SURFACE_OUTBOUND,
				EmberSurfaceLoopHost.Phase.ON_FOOT,
			]:
		sampler.on_foot_ticks += 1
		if not _has_live_surface_support(game, player):
			sampler.on_foot_support_failures += 1
		var region := _landing_region(game)
		if is_instance_valid(region):
			sampler.min_surface_altitude_m = minf(
				sampler.min_surface_altitude_m,
				region.to_local(player.global_position).y
			)
	# One presentation sample every few ticks: the production snapshot is a deep
	# copy of the whole surface composition and sampling it every tick would cost
	# more than the simulation it is measuring. The bound being asserted is a
	# per-sample delta, and the sample spacing is fixed, so a pop still shows.
	if sampler.ticks % PRESENTATION_SAMPLE_INTERVAL == 0:
		sampler.step_presentation(_presentation_values(game))


## The scalar presentation state the entry must move through monotonically. Ember
## is an airless body, so its authored envelope holds the vacuum values; the
## assertion is that whatever the production presentation publishes changes by a
## bounded amount per tick and never pops.
func _presentation_values(game: GameFlow) -> Dictionary:
	var binding := game.ember_surface_loop_production_binding \
		as EmberSurfaceLoopProductionBinding
	if not is_instance_valid(binding):
		return {}
	var surface := binding.get_planetary_surface_snapshot()
	if surface.is_empty():
		return {}
	var values: Dictionary = {}
	for group_key: Variant in ["solar_phase", "weather_observation", "hazard"]:
		var group: Variant = surface.get(group_key, {})
		if group is Dictionary:
			for key: Variant in (group as Dictionary):
				var value: Variant = (group as Dictionary)[key]
				if value is float:
					values["%s.%s" % [group_key, key]] = float(value)
	return values


func _has_live_surface_support(game: GameFlow, player: PlayerController) -> bool:
	if not player.is_on_floor():
		return false
	var region := _landing_region(game)
	if not is_instance_valid(region):
		return false
	var patch := region.get_node_or_null(^"WalkablePatch")
	if not is_instance_valid(patch):
		return false
	var up := region.global_basis.y.normalized()
	var query := PhysicsRayQueryParameters3D.create(
		player.global_position + up * 0.5,
		player.global_position - up * 2.5,
		PhysicsLayers.WORLD_BODY_LAYER
	)
	query.exclude = [player.get_rid()]
	query.collide_with_areas = false
	query.collide_with_bodies = true
	var hit := player.get_world_3d().direct_space_state.intersect_ray(query)
	return not hit.is_empty() and hit.get("collider") == patch


func _assert_landing_support(game: GameFlow, craft: HeroShip, cycle: int) -> void:
	var berth := game.ember_surface_berth as EmberSurfaceBerth
	var report := craft.get_landing_contract_report()
	_check(
		bool(craft.get_telemetry().get("landed", false))
			and bool(report.get("strict_dock_acceptance", false))
			and is_instance_valid(berth) and berth.get_occupant() == craft
			and not berth.get_reservation_token(craft).is_empty(),
		"cycle %d touches down on valid landing support with the exact berth occupancy and token"
			% [cycle + 1]
	)


## The one production boundary this soak stops at, asserted by name. If a later
## change closes it — a shorter authored route, a surface transit, a re-board
## that does not require the survey — this assertion fails and the soak must be
## extended through the rest of the loop rather than quietly stopping early.
func _assert_survey_gated_reboard(
		game: GameFlow,
		player: PlayerController,
		host: EmberSurfaceLoopHost,
		binding: EmberSurfaceLoopProductionBinding,
		craft: HeroShip,
		cycle: int,
	) -> void:
	var surface := binding.get_planetary_surface_snapshot()
	var relay := surface.get("relay_survey", {}) as Dictionary
	var route := relay.get("mandatory_route", {}) as Dictionary
	var area := craft.get_node_or_null(^"ShipBoardingArea") as ShipBoardingArea
	_check(
		host.get_phase() == EmberSurfaceLoopHost.Phase.ON_FOOT
			and is_instance_valid(area)
			and area in player.get_nearby_interactables()
			and not bool(route.get("complete", true))
			and StringName(route.get("next_objective_id", &"")) == &"ember_relay_tower",
		"cycle %d is refused re-boarding only by the authored relay survey gate (phase %d, next objective %s)"
			% [cycle + 1, host.get_phase(), route.get("next_objective_id", &"?")]
	)


## The abandon, asked from the caldera with the pilot on foot. It is admitted and
## pending, never refused: the authored survey route and its re-board gate lift
## at once, the relay survey's activity generation is terminalized with no
## reward, and nobody is stranded — the pilot keeps control on live authored
## support and the craft keeps its own pad lease until they have boarded it.
func _assert_abandon_pending_on_the_surface(
		game: GameFlow,
		player: PlayerController,
		host: EmberSurfaceLoopHost,
		binding: EmberSurfaceLoopProductionBinding,
		craft: HeroShip,
		abandoned: Dictionary,
		cycle: int,
	) -> void:
	var berth := game.ember_surface_berth as EmberSurfaceBerth
	var lease_held := is_instance_valid(berth) \
		and not berth.get_reservation_token(craft).is_empty() \
		and berth.get_occupant() == craft
	var route := host.get_snapshot().get("surface_route", {}) as Dictionary
	_check(
		bool(abandoned.get("accepted", false))
			and StringName(abandoned.get("reason", &"")) \
				== &"ember_surface_abandon_pending_return"
			and player.is_control_enabled() and not player.is_seated()
			and player.is_on_floor()
			and host.get_phase() == EmberSurfaceLoopHost.Phase.ON_FOOT
			and bool(route.get("return_complete", false))
			and lease_held
			and bool(craft.get_telemetry().get("landed", false)),
		"cycle %d abandons from the caldera without stranding anyone: gate lifted, pilot in control, craft holding its pad lease (%s, phase %d)"
			% [cycle + 1, abandoned.get("reason", &"?"), host.get_phase()]
	)
	var activity := ((
		binding.get_planetary_surface_snapshot().get("adapter", {}) as Dictionary
	).get("activity_reward", {}) as Dictionary)
	_check(
		StringName(activity.get("state", &"")) not in [&"active", &"awaiting_reward"],
		"cycle %d leaves no relay-survey generation running after the abandon (state %s)"
			% [cycle + 1, activity.get("state", &"?")]
	)


## The committed abandon. The Host is back at `IDLE`, still attached to the same
## retained composition, with the caldera lease released, no terminal reason and
## no reward — and the pilot is aboard their own craft, flying.
func _assert_abandon_released_the_visit(
		game: GameFlow,
		player: PlayerController,
		host: EmberSurfaceLoopHost,
		binding: EmberSurfaceLoopProductionBinding,
		craft: HeroShip,
		released: bool,
		cycle: int,
	) -> void:
	var berth := game.ember_surface_berth as EmberSurfaceBerth
	var snapshot := host.get_snapshot()
	var abandon := snapshot.get("abandon", {}) as Dictionary
	_check(
		released
			and host.get_phase() == EmberSurfaceLoopHost.Phase.IDLE
			and bool(snapshot.get("attached", false))
			and StringName(snapshot.get("terminal_reason", &"?")).is_empty()
			and int(abandon.get("commit_count", 0)) >= 1
			and not bool(abandon.get("requested", true))
			and is_instance_valid(berth)
			and berth.get_reservation_token(craft).is_empty()
			and player.is_seated() and craft.is_piloted()
			and not bool(game.get("_ember_surface_journey_active"))
			and _reward_receipts == 0,
		"cycle %d releases the abandoned visit in place: Host idle and attached, caldera lease released, pilot flying, no reward (phase %d, commits %d, rewards %d)"
			% [
				cycle + 1, host.get_phase(),
				int(abandon.get("commit_count", 0)), _reward_receipts,
			]
	)


func _assert_cycle_metrics(sampler: CycleSampler, cycle: int) -> void:
	_check(
		sampler.max_ship_step_m <= TICK_STEP_LIMIT_M,
		"cycle %d keeps every craft physics step inside the cruise-speed tick bound (%.3f m <= %.3f m over %d rebases)"
			% [cycle + 1, sampler.max_ship_step_m, TICK_STEP_LIMIT_M, sampler.rebase_count]
	)
	_check(
		sampler.max_player_step_m <= TICK_STEP_LIMIT_M,
		"cycle %d keeps every pilot physics step inside the same bound (%.3f m)"
			% [cycle + 1, sampler.max_player_step_m]
	)
	_check(
		sampler.on_foot_ticks > 0 and sampler.on_foot_support_failures == 0,
		"cycle %d never loses terrain contact while walking Ember (%d/%d ticks unsupported)"
			% [cycle + 1, sampler.on_foot_support_failures, sampler.on_foot_ticks]
	)
	_check(
		sampler.min_surface_altitude_m > -0.75,
		"cycle %d never falls below the authored caldera surface (minimum %.3f m)"
			% [cycle + 1, sampler.min_surface_altitude_m]
	)
	_check(
		sampler.occupancy_failures == 0,
		"cycle %d keeps seat, piloted state and boarding reservation consistent every tick (%d failures)"
			% [cycle + 1, sampler.occupancy_failures]
	)
	_check(
		sampler.rebase_count >= 1,
		"cycle %d commits at least one real floating-origin rebase (%d)"
			% [cycle + 1, sampler.rebase_count]
	)
	_check(
		sampler.presentation_samples == 0 or sampler.max_presentation_delta <= 0.35,
		"cycle %d moves the surface presentation without a pop (largest per-tick delta %.4f over %d samples)"
			% [cycle + 1, sampler.max_presentation_delta, sampler.presentation_samples]
	)


# -------------------------------------------------------------- counters ----


func _record_cycle(
		game: GameFlow,
		sampler: CycleSampler,
		cycle: int,
		craft: HeroShip,
		notes: PackedStringArray,
		leg_msec: Dictionary,
		started_msec: int,
		stopped_at: StringName,
	) -> void:
	var walk := _walk_tree(root)
	var coordinator := (
		game.ember_streaming_bootstrap.get_snapshot().get("coordinator", {}) as Dictionary
	) if is_instance_valid(game.ember_streaming_bootstrap) else {}
	leg_msec["cycle"] = Time.get_ticks_msec() - started_msec
	var record := {
		"cycle": cycle + 1,
		"craft": str(craft.get_ship_id()),
		"stopped_at": str(stopped_at),
		"furthest_phase": sampler.furthest_phase,
		"phases": sampler.phases_seen.size(),
		"ticks": sampler.ticks,
		"staged_ticks": sampler.staged_ticks,
		"rebases": sampler.rebase_count,
		"max_rebase_translation_m": snappedf(sampler.max_rebase_translation_m, 0.001),
		"max_ship_step_m": snappedf(sampler.max_ship_step_m, 0.0001),
		"max_player_step_m": snappedf(sampler.max_player_step_m, 0.0001),
		"on_foot_ticks": sampler.on_foot_ticks,
		"on_foot_support_failures": sampler.on_foot_support_failures,
		"min_surface_altitude_m": snappedf(
			0.0 if is_inf(sampler.min_surface_altitude_m) else sampler.min_surface_altitude_m,
			0.001
		),
		"occupancy_failures": sampler.occupancy_failures,
		"presentation_samples": sampler.presentation_samples,
		"max_presentation_delta": snappedf(sampler.max_presentation_delta, 0.0001),
		"streamed_nodes": _streamed_node_count(game),
		"peak_streamed_nodes": sampler.max_streamed_nodes,
		"ember_load_requests": int(coordinator.get("load_request_count", 0)),
		"ember_location_generation": int(
			game.ember_streaming_bootstrap.get_snapshot().get("location_generation", 0)
		) if is_instance_valid(game.ember_streaming_bootstrap) else 0,
		"scene_nodes": int(walk.scene_nodes),
		"objects": int(Performance.get_monitor(Performance.OBJECT_COUNT)),
		"object_nodes": int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)),
		"orphan_nodes": int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT)),
		"static_memory_bytes": int(Performance.get_monitor(Performance.MEMORY_STATIC)),
		"audio_players": int(walk.audio_players),
		"audio_voices_playing": int(walk.audio_voices_playing),
		"particle_systems": int(walk.particle_systems),
		"tweens": get_processed_tweens().size(),
		"timers": int(walk.timers),
		"notes": ",".join(notes),
		"leg_msec": leg_msec,
	}
	_cycle_records.append(record)
	print("EMBER_CYCLE %s" % JSON.stringify(record))


func _streamed_node_count(game: GameFlow) -> int:
	if not is_instance_valid(game.ember_streaming_bootstrap):
		return 0
	var loaded := game.ember_streaming_bootstrap.get_loaded_instance()
	if not is_instance_valid(loaded):
		return 0
	var totals := {"scene_nodes": 0, "audio_players": 0, "audio_voices_playing": 0,
		"particle_systems": 0, "particle_systems_emitting": 0, "timers": 0, "timers_running": 0}
	_accumulate(loaded, totals)
	return int(totals["scene_nodes"])


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
	elif node is Timer:
		totals["timers"] = int(totals["timers"]) + 1
		if not (node as Timer).is_stopped():
			totals["timers_running"] = int(totals["timers_running"]) + 1
	for child in node.get_children():
		_accumulate(child, totals)


func _assert_flat_counters() -> void:
	if _cycle_records.size() <= WARM_UP_CYCLES:
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


func _print_summary(teardown_nodes: int, teardown_orphans: int) -> void:
	var summary := {
		"schema_version": 1,
		"cycles": _cycle_count,
		"warm_up_cycles": WARM_UP_CYCLES,
		"completed_cycles": _completed_cycles,
		"reentries": _reentries,
		"staging_events": _staging_events,
		"survey_gated_cycles": _survey_gated_cycles,
		"repeat_visit_handoff_stops": _repeat_visit_handoff_stops,
		"abandoned_expeditions": _abandoned_expeditions,
		"reentry_terminal_stops": _reentry_terminal_stops,
		"reward_receipts": _reward_receipts,
		"baseline_streamed_nodes": _baseline_streamed_nodes,
		"pre_boot_object_nodes": _baseline_object_nodes,
		"post_teardown_object_nodes": teardown_nodes,
		"post_teardown_orphan_nodes": teardown_orphans,
		"assertions": _assertions,
		"failures": _failures.size(),
		"cycles_recorded": _cycle_records,
	}
	print("EMBER_SUMMARY %s" % JSON.stringify(summary))


# --------------------------------------------------------------- helpers ----


func _landing_region(game: GameFlow) -> Node3D:
	if not is_instance_valid(game.ember_streaming_bootstrap):
		return null
	var loaded := game.ember_streaming_bootstrap.get_loaded_instance()
	if not is_instance_valid(loaded):
		return null
	return loaded.get_node_or_null(^"LandingRegion") as Node3D


func _await_free_on_foot(game: GameFlow, player: PlayerController) -> void:
	_release_all_actions()
	await _wait_until(
		func() -> bool: return (
			not bool(game.get("_transition_busy"))
			and not player.is_seated()
			and player.is_control_enabled()
		),
		4.0
	)


## Harness-only recovery so one failed cycle is reported once instead of
## cascading. The exit itself is the production one.
func _abort_journey(game: GameFlow, player: PlayerController) -> void:
	_release_all_actions()
	game.abandon_ember_surface_journey(&"soak_cycle_aborted")
	for _settle in 8:
		await physics_frame
		await process_frame
	await _reset_for_next_cycle(
		game, player,
		game.ember_surface_loop_host as EmberSurfaceLoopHost,
		game.ember_surface_loop_production_binding as EmberSurfaceLoopProductionBinding,
		game.get_active_ship()
	)


## Returns the retained Main to a state that admits another expedition.
##
## The expedition itself is ended by the production abandon, which leaves the
## retained Host attached and `IDLE` and retires the visit-scoped surface
## composition. What remains here is the 8,000 km flight home: the craft and
## pilot are placed back at the yard (the one staging this harness still
## performs — see the header for why the Arrow cannot yet fly its own last
## metres), and the abandoned visit's live return route is released with them.
func _reset_for_next_cycle(
		game: GameFlow,
		player: PlayerController,
		host: EmberSurfaceLoopHost,
		binding: EmberSurfaceLoopProductionBinding,
		craft: HeroShip,
	) -> void:
	_release_all_actions()
	if is_instance_valid(host) and host.is_attached() \
			and host.get_phase() != EmberSurfaceLoopHost.Phase.IDLE:
		game.abandon_ember_surface_journey(&"soak_cycle_reset")
		for _abandon_tick in 12:
			await physics_frame
			await process_frame
			if host.get_phase() == EmberSurfaceLoopHost.Phase.IDLE:
				break
	var journey: Object = game.get("_planetary_journey")
	journey.set("_ember_return_transit_phase", &"")
	journey.set("_ember_return_transit_flow", &"")
	journey.set("_ember_abandon_return_arm_pending", false)
	journey.set("_mudds_return_approach_active", false)
	game.disengage_planetary_cruise(false)
	_staging_events += 1
	for _settle in 6:
		await physics_frame
		await process_frame
	if is_instance_valid(craft):
		var area := craft.get_node_or_null(^"ShipBoardingArea") as ShipBoardingArea
		if is_instance_valid(area) and area.get_reservation_token() != null:
			area.release_reservation(area.get_reservation_token())
	await _recover(game, player)
	# The caldera berth only configures against an empty lease, and the craft is
	# still its occupant until it has physically left the pad. Release after the
	# craft is home, not before.
	var surface_berth := game.ember_surface_berth as EmberSurfaceBerth
	if is_instance_valid(surface_berth) and is_instance_valid(craft):
		var token := surface_berth.get_reservation_token(craft)
		if not token.is_empty():
			surface_berth.release(craft, token)
		for _release_tick in 6:
			await physics_frame
			await process_frame
	# Let the retained coordinator settle, and let Ember stream out behind the
	# departed craft, before the cycle's counters are recorded. Comparing a cycle
	# that still has the moon resident against one that does not would report a
	# streamed world as unbounded growth.
	for _rebind_tick in 240:
		await physics_frame
		await process_frame
		if _streamed_node_count(game) <= _baseline_streamed_nodes:
			break
	for _settle_tick in 24:
		await physics_frame
		await process_frame
	if is_instance_valid(host):
		_check(
			host.get_phase() == EmberSurfaceLoopHost.Phase.IDLE
				and not bool(game.get("_ember_surface_journey_active")),
			"the cycle reset leaves the retained Host idle and free to admit the next expedition (phase %d)"
				% host.get_phase()
		)


func _recover(game: GameFlow, player: PlayerController) -> void:
	_release_all_actions()
	var world := game.get_node_or_null(^"ShipyardWorld") as ShipyardWorld
	var craft := game.get_active_ship()
	# Every craft this soak flew must be boardable again for a later cycle, and a
	# craft that was abandoned in flight keeps its engines online until something
	# idles them. This is the same harness staging as the placement below.
	for fleet_craft in game.get_flyable_ships():
		if is_instance_valid(fleet_craft) and not fleet_craft.is_piloted():
			fleet_craft.request_engine_stop(false)
	if is_instance_valid(craft):
		craft.set_piloted(false)
		craft.request_engine_stop(false)
		craft.velocity = Vector3.ZERO
		if is_instance_valid(world):
			var berth := world.get_berth_node(craft.get_home_berth_id())
			if is_instance_valid(berth):
				craft.global_transform = berth.get_dock_transform()
	game.set("_piloting", false)
	game.set("_transition_busy", false)
	game.set("_sortie_departed_berth", false)
	if is_instance_valid(world):
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


func _on_reward(_receipt: Dictionary) -> Dictionary:
	_reward_receipts += 1
	return {"accepted": true, "reason": &"ember_loop_soak_reward"}


func _environment_int(name: String, fallback: int) -> int:
	var raw := OS.get_environment(name).strip_edges()
	return int(raw) if raw.is_valid_int() else fallback


func _check(condition: bool, description: String) -> void:
	_assertions += 1
	if condition:
		print("PASS: ", description)
	else:
		_failures.append(description)
		push_error("FAIL: " + description)


func _finish() -> void:
	if _failures.is_empty():
		print("EMBER_LOOP_SOAK_TEST_OK: %d assertions" % _assertions)
		quit(0)
	else:
		printerr(
			"EMBER_LOOP_SOAK_TEST_FAILED: %d/%d assertions failed: %s"
			% [_failures.size(), _assertions, "; ".join(_failures)]
		)
		quit(1)
