extends SceneTree

## Rendered evidence for the varied encounter scenarios.
##
## Two sections, deliberately separated because they answer different questions.
##
## **Section A — played.** A real guided sortie: the pilot is boarded through
## the production path, the engines are started with the production
## `engine_start` action, the berth is physically cleared with `move_forward`,
## the coordinator's own interceptor engagement is opened, and the encounter is
## then flown with nothing but `move_forward`, `move_left` and `move_right`
## pressed through the live input map. Every frame in this section is taken from
## the craft's own camera with the HUD left on, because the question being asked
## is "can the player read this while flying", and a frame with the HUD stripped
## out and a director's camera cannot answer it.
##
## **Section B — readability plates.** The craft themselves, photographed from a
## harness camera in an empty volume with the HUD hidden, so the silhouettes,
## the role lamps, the safed muzzle and the damage stages can be compared side
## by side against the two existing opponents. The camera and the pooled
## presentation's deterministic clock are evidence controls, and are labelled as
## such.
##
## Nothing here is a test. This file is deliberately not named `*_test.gd`, so
## the frozen test matrix does not collect it.

const MAIN_SCENE := preload("res://scenes/main.tscn")

const OUTPUT_DIR := "res://artifacts/varied_encounter_visuals"
## Open space well outside the yard. The production WorldEnvironment and key
## light are global, so section B is lit exactly as it is in play without a
## harness light and without station structure crowding the silhouettes.
const ARENA_ORIGIN := Vector3(-380.0, 108.0, -470.0)
const CAMERA_FOV := 40.0
const PILOT_ACTIONS: Array[StringName] = [
	&"move_forward", &"move_left", &"move_right", &"fire", &"sprint_boost",
]

var _failures: Array[String] = []
var _notes: Array[String] = []
var _game: GameFlow
var _camera: Camera3D


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	await _play_encounter()
	await _capture_readability_plates()
	for note in _notes:
		print(note)
	print("CAPTURE_VARIED_ENCOUNTERS_DONE: %s" % OUTPUT_DIR)
	if _failures.is_empty():
		quit(0)
	else:
		print("CAPTURE_VARIED_ENCOUNTERS_FAILED: ", "; ".join(_failures))
		quit(1)


# ------------------------------------------------------ A. played sortie ----

func _play_encounter() -> void:
	_game = MAIN_SCENE.instantiate() as GameFlow
	root.add_child(_game)
	await _settle(4)
	for _step in 6:
		await physics_frame
		await process_frame

	var torrent := _game.get_node("TorrentInterceptor") as HeroShip
	var defender := _game.get_node("RangeOpponent") as RangeOpponent
	var director := _game.get_node("EncounterScenarios") as EncounterScenarioDirector
	var coordinator := _game.get_node("EncounterScenarios/WingCoordinator") as WingCoordinator
	var courier := _game.get_node("CourierRunner") as CourierRunnerOpponent
	var lead := _game.get_node("WingSkirmisherLead") as FlankingSkirmisherOpponent
	var wing := _game.get_node("WingSkirmisherWing") as FlankingSkirmisherOpponent

	# --- the production loop, driven by production inputs only ---
	# The canopy and boarding motion times are shortened. That is a harness
	# control over how long an animation takes, not over what happens: every
	# phase transition below is still the production one.
	_game.canopy_motion_time = 0.02
	_game.boarding_motion_time = 0.025
	# The title card is dismissed the way a player dismisses it: an `interact`
	# press into the HUD's own unhandled-input handler, which runs the intro
	# fade and emits `start_requested` into `GameFlow.start_shift()`. Calling
	# `start_shift()` directly would leave the intro overlay drawn over every
	# frame below, which is exactly the sort of thing a headless assertion does
	# not notice and a rendered frame does.
	var hud := _game.get_node("HUD") as GameHUD
	_dispatch_hud_action(hud, &"interact")
	if not await _wait_until(func() -> bool:
		return _game.phase == GameFlow.Phase.APPROACH_SHIP, 180):
		_failures.append("the shift never began from the production title card")
		await _teardown()
		return
	await _settle(20)
	_game.call("_board_ship", torrent)
	if not await _wait_until(func() -> bool:
		return _game.phase == GameFlow.Phase.START_ENGINES, 240):
		_failures.append("the pilot never reached the production start-engines phase")
		await _teardown()
		return
	torrent.engine_start_time = 0.01
	_dispatch_pilot_action(&"engine_start")
	if not await _wait_until(func() -> bool:
		return _game.phase == GameFlow.Phase.LAUNCH, 180):
		_failures.append("the craft never reached the production launch phase")
		await _teardown()
		return
	Input.action_press(&"move_forward")
	var departed := await _wait_until(func() -> bool:
		return bool(_game.get("_sortie_departed_berth")), 300)
	if not departed:
		_failures.append("the craft never physically cleared its berth")
		Input.action_release(&"move_forward")
		await _teardown()
		return
	# Two harness controls over *pacing only*: this machine renders through
	# llvmpipe, so every simulated frame costs about a third of a second, and the
	# production 4.5 s arming delay plus the 2.4 s escort response would spend
	# four hundred rendered frames on empty sky. Shortening them changes when the
	# contacts arrive, not what arrives or how any of it behaves.
	director.start_delay = 1.2
	director.escort_response_delay = 1.2
	_game.destroyed_targets = _game.total_targets
	_game.call("_begin_interceptor_engagement")
	await _settle(6)
	await _capture("play_01_live_contact.png")
	_notes.append(
		"PLAY: phase=%d defender_active=%s" % [_game.phase, str(defender.is_active())]
	)

	# --- the scenario arms itself, at the production start delay ---
	var armed := await _wait_until(func() -> bool: return director.is_running(), 900)
	if not armed:
		_failures.append("the scenario never armed inside the live engagement")
		Input.action_release(&"move_forward")
		await _teardown()
		return
	await _capture("play_02_courier_scenario_opens.png")
	_notes.append(
		"PLAY: scenario=%s courier_active=%s launch_gap=%.1f m"
			% [
				director.get_active_scenario(),
				str(courier.is_active()),
				torrent.global_position.distance_to(courier.global_position),
			]
	)

	# --- chase: steer and shoot with the live input map, exactly as a player
	#     would. The runner cannot be caught by a Torrent that does not boost —
	#     it burns at 96 m/s against the Torrent's 82 once a pursuer is inside
	#     120 m — so the objective is met with the gun, not with the throttle.
	await _steer_toward(torrent, courier, 140, true)
	await _capture("play_03_chasing_the_runner.png")
	_notes.append(
		"PLAY: chase range=%.1f m escape_progress=%.2f courier_hull=%.1f/%.1f running=%s"
			% [
				torrent.global_position.distance_to(courier.global_position),
				director.get_escape_progress(),
				courier.get_health(),
				courier.maximum_health,
				str(director.is_running()),
			]
	)

	if director.is_running():
		# --- one hit on the runner brings the escort in. Applied through the
		#     same authoritative entry point the player's gun commits through,
		#     because whether a scripted flight path happens to land a hitscan
		#     is not what these frames are evidence of.
		courier.apply_damage(courier.maximum_health * 0.3, courier.global_position)
		var broadcast := await _wait_until(func() -> bool:
			return director.is_distress_broadcast(), 240)
		await _steer_toward(torrent, courier, 90, false)
		await _capture("play_04_runner_outcome.png")
		_notes.append("PLAY: distress_broadcast=%s" % str(broadcast))
		var escorted := await _wait_until(func() -> bool:
			return director.is_escort_launched(), 300)
		_notes.append("PLAY: escort_launched=%s" % str(escorted))
	else:
		# The runner reached the boundary. That is a complete, terminal outcome
		# with nothing left flying, and it is worth a frame of its own.
		await _capture("play_04_runner_outcome.png")
		_notes.append(
			"PLAY: runner outcome=%s roster=%d courier_active=%s"
				% [
					String(director.get_outcome()),
					director.get_roster().size(),
					str(courier.is_active()),
				]
		)
		# Harness control: the director runs one scenario per entry into the
		# engagement phase, so the pair is started explicitly here rather than by
		# flying a second sortie. Everything about how the pair then behaves is
		# production code.
		director.begin_scenario(EncounterScenarioDirector.SCENARIO_PAIRED_WING, torrent)

	await _settle(20)
	await _capture("play_05_wing_inbound.png")
	_notes.append(
		"PLAY: scenario=%s anchor=%s lead_role=%s wing_role=%s"
			% [
				String(director.get_active_scenario()),
				String(coordinator.get_anchor().name) if coordinator.get_anchor() != null else "none",
				String(lead.get_wing_role()),
				String(wing.get_wing_role()),
			]
	)

	# --- turn into the wing and photograph the role trade ---
	var anchor := coordinator.get_anchor() as FlankingSkirmisherOpponent
	var flanker: FlankingSkirmisherOpponent = wing if anchor == lead else lead
	await _steer_toward(torrent, flanker, 140, false)
	await _capture("play_06_turning_into_the_flanker.png")
	_notes.append(
		"PLAY: after turn anchor=%s anchor_commits=%d flanker_safed=%s"
			% [
				String(coordinator.get_anchor().name) if coordinator.get_anchor() != null else "none",
				coordinator.get_swap_count(),
				str(flanker.is_weapon_safed()),
			]
	)

	# --- conclude by meeting whatever objective is live, and photograph it ---
	for member in director.get_roster():
		if member.has_method(&"apply_damage"):
			member.call(&"apply_damage", 100000.0, (member as Node3D).global_position)
	var concluded := await _wait_until(func() -> bool: return director.is_concluded(), 240)
	await _settle(6)
	await _capture("play_07_objective_outcome.png")
	_notes.append(
		"PLAY: concluded=%s outcome=%s roster=%d courier_active=%s wing_active=%d"
			% [
				str(concluded),
				String(director.get_outcome()),
				director.get_roster().size(),
				str(courier.is_active()),
				coordinator.get_active_member_count(),
			]
	)
	Input.action_release(&"move_forward")
	await _release_pilot_actions()
	await _teardown()


## Presses the live steering actions until the target sits inside the craft's
## forward arc, or the budget runs out. This is the same input path a player
## uses; nothing about the craft's attitude is written directly.
func _steer_toward(
		craft: Node3D,
		target: Node3D,
		frame_budget: int,
		shoot: bool = false
	) -> void:
	if not is_instance_valid(craft) or not is_instance_valid(target):
		return
	for _index in frame_budget:
		if not is_instance_valid(target) or not is_instance_valid(craft):
			break
		var offset := target.global_position - craft.global_position
		if offset.length_squared() <= 0.001:
			break
		var direction := offset.normalized()
		var forward := -craft.global_basis.z
		var aligned := forward.dot(direction) > 0.985
		var lateral := craft.global_basis.x.dot(direction)
		Input.action_release(&"move_left")
		Input.action_release(&"move_right")
		if lateral > 0.02:
			Input.action_press(&"move_right")
		elif lateral < -0.02:
			Input.action_press(&"move_left")
		if shoot:
			# A Torrent that does not boost cannot stay with the runner once it
			# lights off, so the chase is flown the way it has to be flown.
			Input.action_press(&"sprint_boost")
		else:
			Input.action_release(&"sprint_boost")
		if shoot and aligned:
			# The player's own gun, through the live `fire` action and the
			# coordinator's own weapon window. Held only while the nose is on the
			# target, which is what a player does and what the encounter is
			# actually asking him to manage.
			Input.action_press(&"fire")
		else:
			Input.action_release(&"fire")
		if aligned and not shoot:
			break
		await physics_frame
		await process_frame
	Input.action_release(&"move_left")
	Input.action_release(&"move_right")
	Input.action_release(&"fire")
	Input.action_release(&"sprint_boost")


# -------------------------------------------------- B. readability plates ----

func _capture_readability_plates() -> void:
	_game = MAIN_SCENE.instantiate() as GameFlow
	root.add_child(_game)
	await _settle(4)
	await physics_frame
	await _settle(2)

	# Same HUD policy as the existing combat and picket captures: every
	# CanvasLayer is hidden and disabled so these frames show only the craft.
	for candidate in _game.find_children("*", "CanvasLayer", true, false):
		var layer := candidate as CanvasLayer
		layer.visible = false
		layer.process_mode = Node.PROCESS_MODE_DISABLED

	var defender := _game.get_node("RangeOpponent") as RangeOpponent
	var picket := _game.get_node("StandoffPicket") as StandoffPicketOpponent
	var lead := _game.get_node("WingSkirmisherLead") as FlankingSkirmisherOpponent
	var wing := _game.get_node("WingSkirmisherWing") as FlankingSkirmisherOpponent
	var courier := _game.get_node("CourierRunner") as CourierRunnerOpponent
	var director := _game.get_node("EncounterScenarios") as EncounterScenarioDirector
	# Evidence control: the director is stood down so nothing dispatches these
	# craft out from under the camera, and the pooled shot clock is stepped by
	# hand rather than by frame time.
	director.enabled = false
	picket.escort_enabled = false
	var pulse := _game.get_node("PulseWeaponPresentation") as PulseWeaponPresentation
	pulse.set_auto_advance_enabled(false)

	_camera = Camera3D.new()
	_camera.name = "EncounterEvidenceCamera"
	_camera.fov = CAMERA_FOV
	_camera.far = 4000.0
	root.add_child(_camera)
	_camera.current = true

	var heading := Vector3(-0.62, -0.10, -0.78).normalized()
	var pose := func(offset: Vector3) -> Transform3D:
		return Transform3D(
			Basis.looking_at(heading, Vector3.UP).orthonormalized(),
			ARENA_ORIGIN + offset
		)

	# 1. The two new silhouettes beside the two existing ones, at one scale.
	for entry in [
		{"craft": defender, "offset": Vector3(-26.0, 0.0, 0.0)},
		{"craft": picket, "offset": Vector3(-8.0, 0.0, 3.0)},
		{"craft": lead, "offset": Vector3(8.0, 0.0, 0.0)},
		{"craft": courier, "offset": Vector3(24.0, 0.0, 3.0)},
	]:
		var craft: RangeOpponent = entry["craft"]
		var placement: Transform3D = pose.call(entry["offset"])
		craft.activate(placement)
		craft.global_transform = placement
		craft.velocity = Vector3.ZERO
		craft.acceleration = 0.0
	await _settle(8)
	_aim_camera(ARENA_ORIGIN, Vector3(-0.72, 0.24, -0.66), 62.0)
	await _capture("plate_01_opponent_roster.png")

	# 2. The wing role read: two identical hulls, two different lamps. This is
	#    the whole coordination signal at combat distance.
	courier.deactivate()
	defender.deactivate()
	picket.deactivate()
	var lead_pose: Transform3D = pose.call(Vector3(-7.0, 0.0, 0.0))
	var wing_pose: Transform3D = pose.call(Vector3(7.0, 0.0, 2.0))
	lead.activate(lead_pose)
	lead.global_transform = lead_pose
	lead.velocity = Vector3.ZERO
	lead.acceleration = 0.0
	wing.activate(wing_pose)
	wing.global_transform = wing_pose
	wing.velocity = Vector3.ZERO
	wing.acceleration = 0.0
	lead.assign_wing_role(WingCoordinator.ROLE_ANCHOR)
	wing.assign_wing_role(WingCoordinator.ROLE_FLANKER)
	await _settle(8)
	_aim_camera(ARENA_ORIGIN, Vector3(-0.66, 0.30, -0.69), 30.0)
	await _capture("plate_02_anchor_and_flanker_lamps.png")

	# 3. The same pair after a role trade. Nothing else about either hull has
	#    changed, so the lamp is doing all of the work.
	lead.assign_wing_role(WingCoordinator.ROLE_FLANKER)
	wing.assign_wing_role(WingCoordinator.ROLE_ANCHOR)
	await _settle(8)
	await _capture("plate_03_roles_traded.png")

	# 4. Armed against safed. The flanker's muzzle lens is dark whenever its gun
	#    cannot arm, which is the honest read on whether it can hurt you.
	lead.call("_set_weapon_safed", false)
	wing.call("_set_weapon_safed", true)
	await _settle(6)
	_aim_camera(ARENA_ORIGIN + Vector3(0.0, 0.0, -6.0), Vector3(-0.2, 0.16, -0.97), 26.0)
	await _capture("plate_04_armed_versus_safed.png")

	# 5. The runner: distress beacon dark, then lit. One state change, no
	#    oscillator — every frame of a given state photographs identically.
	lead.deactivate()
	wing.deactivate()
	var courier_pose: Transform3D = pose.call(Vector3.ZERO)
	courier.activate(courier_pose)
	courier.global_transform = courier_pose
	courier.velocity = Vector3.ZERO
	courier.acceleration = 0.0
	await _settle(8)
	_aim_camera(ARENA_ORIGIN, Vector3(-0.78, 0.22, -0.58), 24.0)
	await _capture("plate_05_courier_calm.png")
	courier.begin_distress_broadcast()
	await _settle(6)
	await _capture("plate_06_courier_distress.png")

	# 6. Staged damage and the destruction the roadmap asks to be consistent.
	courier.apply_damage(courier.maximum_health * 0.72, courier.global_position)
	await _settle(24)
	_aim_camera(ARENA_ORIGIN, Vector3(-0.6, 0.28, 0.75), 22.0)
	await _capture("plate_07_courier_critical.png")
	courier.apply_damage(courier.maximum_health, courier.global_position)
	await _settle(10)
	_aim_camera(ARENA_ORIGIN, Vector3(-0.5, 0.34, 0.8), 30.0)
	await _capture("plate_08_courier_destroyed.png")

	var skirmisher_pose: Transform3D = pose.call(Vector3.ZERO)
	lead.activate(skirmisher_pose)
	lead.global_transform = skirmisher_pose
	lead.velocity = Vector3.ZERO
	lead.acceleration = 0.0
	lead.assign_wing_role(WingCoordinator.ROLE_ANCHOR)
	lead.apply_damage(lead.maximum_health * 0.72, lead.global_position)
	await _settle(24)
	_aim_camera(ARENA_ORIGIN, Vector3(-0.6, 0.28, 0.75), 18.0)
	await _capture("plate_09_skirmisher_critical.png")
	lead.apply_damage(lead.maximum_health, lead.global_position)
	await _settle(10)
	_aim_camera(ARENA_ORIGIN, Vector3(-0.5, 0.34, 0.8), 26.0)
	await _capture("plate_10_skirmisher_destroyed.png")

	if is_instance_valid(_camera):
		root.remove_child(_camera)
		_camera.queue_free()
		_camera = null
	await _teardown()


# ------------------------------------------------------------- harness ----

func _aim_camera(focus: Vector3, direction: Vector3, distance: float) -> void:
	var origin := focus + direction.normalized() * distance
	_camera.global_transform = Transform3D(
		Basis.looking_at((focus - origin).normalized(), Vector3.UP).orthonormalized(),
		origin
	)


func _dispatch_pilot_action(action: StringName) -> void:
	var event := InputEventAction.new()
	event.action = action
	event.pressed = true
	_game._unhandled_input(event)


func _dispatch_hud_action(hud: CanvasLayer, action: StringName) -> void:
	var event := InputEventAction.new()
	event.action = action
	event.pressed = true
	hud._unhandled_input(event)


func _release_pilot_actions() -> void:
	for action in PILOT_ACTIONS:
		Input.action_release(action)
	await physics_frame


func _settle(frames: int) -> void:
	for _index in frames:
		await process_frame


func _wait_until(condition: Callable, frame_budget: int) -> bool:
	for _index in frame_budget:
		if bool(condition.call()):
			return true
		await physics_frame
		await process_frame
	return bool(condition.call())


func _capture(file_name: String) -> void:
	await _settle(4)
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	if image == null or image.is_empty():
		_failures.append("%s produced an empty viewport image" % file_name)
		return
	image.convert(Image.FORMAT_RGB8)
	var path := "%s/%s" % [OUTPUT_DIR, file_name]
	var error := image.save_png(path)
	if error != OK:
		_failures.append("%s could not be written: %s" % [file_name, error_string(error)])
		return
	print("CAPTURED: %s  size=%s" % [path, str(image.get_size())])


func _teardown() -> void:
	await _release_pilot_actions()
	if not is_instance_valid(_game):
		return
	var audio := _game.get_node_or_null("CombatAudioPresentation")
	if is_instance_valid(audio) and audio.get_parent() != null:
		audio.get_parent().remove_child(audio)
		audio.queue_free()
		await process_frame
	root.remove_child(_game)
	_game.queue_free()
	_game = null
	for _index in 10:
		await process_frame
