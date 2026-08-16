extends SceneTree

## Source-current rendered-evidence walkthrough for the playable vertical slice.
##
## The 27 named frames retain one live production Main instance and exercise its
## boarding/seating, engine, camera, combat-damage, landing, and disembarkation
## states. This is deliberately staged evidence, not a controller-only or
## uninterrupted playthrough: the harness invokes some production handlers
## directly, teleports/repositions production bodies, freezes the range opponent,
## and adds one evidence camera for legible compositions. Those interventions are
## enumerated in the evidence manifest; they are never evidence that the omitted
## walking, flight, aiming, or UI-input segments were completed by a player.
##
## Set KETH_CAPTURE_SCENES_PARSE_ONLY=1 to validate this script without opening a
## renderer, instantiating Main, or touching the existing artifacts. A production
## capture is intentionally deferred until the enclosing source freeze is stable.

const MAIN_SCENE_PATH := "res://scenes/main.tscn"
const HUD_SCENE_PATH := "res://scenes/ui/hud.tscn"
const HUD_SCRIPT_PATH := "res://scripts/ui/hud.gd"
const PARSE_ONLY_ENVIRONMENT_VARIABLE := "KETH_CAPTURE_SCENES_PARSE_ONLY"
const OUTPUT_DIR := "res://artifacts"
const STAGING_DIR := "user://keth_phase2_gameplay_capture_staging"
const EVIDENCE_MANIFEST_PATH := OUTPUT_DIR + "/gameplay_evidence_manifest.json"
const SOURCE_MANIFEST_PATH := OUTPUT_DIR + "/gameplay_source_manifest.sha256"
const CAPTURE_LOG_PATH := OUTPUT_DIR + "/capture_scenes_forward_plus_2560x1440.log"
const CAPTURE_RESOLUTION := Vector2i(2560, 1440)
const CAPTURE_FILES: Array[String] = [
	"title.png",
	"station.png",
	"fleet_overview.png",
	"aft_junction.png",
	"operations_room.png",
	"habitat_exterior.png",
	"habitat_common_room.png",
	"freight_dock_approach.png",
	"jovian_walkup.png",
	"jovian_profile.png",
	"jovian_cargo_ramp.png",
	"jovian_cargo_bay.png",
	"jovian_passenger_cabin.png",
	"jovian_cockpit.png",
	"jovian_launch.png",
	"jovian_return.png",
	"arrow_walkup.png",
	"arrow_profile.png",
	"boarding.png",
	"seated_cockpit.png",
	"engine_startup.png",
	"flight.png",
	"cockpit_flight.png",
	"dogfight.png",
	"touchdown.png",
	"disembark.png",
	"return_on_foot.png",
]

const SOURCE_ROOTS: Array[String] = [
	"res://project.godot",
	"res://export_presets.cfg",
	"res://default_bus_layout.tres",
	"res://tests/capture_scenes.gd",
	"res://tests/capture_scenes.gd.uid",
	"res://scripts",
	"res://scenes",
	"res://assets",
	"res://art_source",
	"res://tools",
]

const HUD_SEMANTIC_CAPTURES: Array[String] = [
	"title.png",
	"jovian_cockpit.png",
	"jovian_launch.png",
	"jovian_return.png",
	"boarding.png",
	"seated_cockpit.png",
	"engine_startup.png",
	"flight.png",
	"cockpit_flight.png",
	"dogfight.png",
	"touchdown.png",
	"disembark.png",
	"return_on_foot.png",
]

const STAGING_INTERVENTIONS: Array[Dictionary] = [
	{
		"id": "direct_title_handler",
		"frames": ["station.png", "fleet_overview.png"],
		"action": "Calls the production HUD _begin handler directly.",
		"limit": "Proves the handler-to-GameFlow transition, not mouse, keyboard, or controller activation of the title control.",
	},
	{
		"id": "evidence_camera",
		"frames": [
			"station.png", "fleet_overview.png", "aft_junction.png",
			"operations_room.png", "habitat_exterior.png",
			"habitat_common_room.png", "freight_dock_approach.png",
			"jovian_walkup.png", "jovian_profile.png",
			"jovian_cargo_ramp.png", "jovian_cargo_bay.png",
			"jovian_passenger_cabin.png", "jovian_return.png",
			"arrow_walkup.png", "arrow_profile.png", "boarding.png",
			"seated_cockpit.png", "engine_startup.png", "touchdown.png",
			"disembark.png", "return_on_foot.png",
		],
		"action": "Adds and positions one capture-only Camera3D.",
		"limit": "These compositions do not prove a production player or ship camera traversed the same route.",
	},
	{
		"id": "direct_door_interaction",
		"frames": ["operations_room.png", "habitat_common_room.png"],
		"action": "Calls the live StationDoor interact method with the production player.",
		"limit": "Proves the real door state and clear portal, not player-input approach or traversal through the doorway.",
	},
	{
		"id": "on_foot_teleports",
		"frames": [
			"habitat_common_room.png", "freight_dock_approach.png",
			"jovian_walkup.png", "jovian_cargo_ramp.png",
			"jovian_cargo_bay.png", "jovian_passenger_cabin.png",
			"arrow_walkup.png", "arrow_profile.png", "boarding.png",
		],
		"action": "Teleports the same production PlayerController to safe production transforms.",
		"limit": "These frames are spatial/state evidence, not proof that the connecting station route was walked under player input.",
	},
	{
		"id": "moving_interior_component_step",
		"frames": ["jovian_passenger_cabin.png"],
		"action": "Temporarily pauses the production coordinator, offsets the live Jovian, and calls its public frame-step API out and back.",
		"limit": "Proves the bounded moving-frame invariant used in the frame; it is not a continuous piloted interior voyage.",
	},
	{
		"id": "jovian_staged_return_approach",
		"frames": ["jovian_return.png"],
		"action": "Places the live Jovian three metres above its home transform at zero velocity, then invokes the production landing request.",
		"limit": "The final reservation, assist, latch, berth occupation, and phase transition are production behavior; the preceding return flight is not evidenced.",
	},
	{
		"id": "torrent_staged_launch_clearance",
		"frames": ["flight.png", "cockpit_flight.png", "dogfight.png"],
		"action": "Moves the live Torrent clear of dock geometry before applying the production throttle action.",
		"limit": "Velocity and cameras are live, but these frames do not prove a continuous piloted departure from the berth.",
	},
	{
		"id": "direct_lifecycle_commands",
		"frames": [
			"jovian_cockpit.png", "jovian_launch.png", "jovian_return.png",
			"engine_startup.png", "flight.png", "cockpit_flight.png",
			"dogfight.png", "touchdown.png", "disembark.png",
			"return_on_foot.png",
		],
		"action": "Calls public ship engine/camera methods and private GameFlow landing, engagement, projectile, or exit handlers where the harness names those transitions.",
		"limit": "The resulting production lifecycle and telemetry states are evidenced, but the direct calls do not prove equivalent keyboard, mouse, gamepad, or HUD-control activation.",
	},
	{
		"id": "staged_range_encounter",
		"frames": ["dogfight.png"],
		"action": "Starts the production encounter directly, freezes/repositions the live opponent, applies damage through its API, and invokes the production incoming-projectile handler.",
		"limit": "Proves the composed live damage, smoke, pulse, hull, and HUD states; it is not evidence of player aim, firing input, adversary navigation, or a naturally completed dogfight.",
	},
	{
		"id": "torrent_staged_landing_approach",
		"frames": ["touchdown.png", "disembark.png", "return_on_foot.png"],
		"action": "Places the live Torrent three metres above its registered berth at zero velocity, then invokes the production landing request.",
		"limit": "The final assist, latch, shutdown, disembarkation, and restored control are production behavior; the preceding return flight is not evidenced.",
	},
]

const PNG_SIGNATURE_BYTES: Array[int] = [137, 80, 78, 71, 13, 10, 26, 10]
const MINIMUM_CAPTURE_BYTES := 100_000
const MINIMUM_LUMINANCE_RANGE := 0.035
const MINIMUM_LUMINANCE_VARIANCE := 0.00010
const NEAR_DUPLICATE_MEAN_DIFFERENCE := 0.0075
const NEAR_DUPLICATE_CHANGED_FRACTION := 0.065
const PIXEL_CHANGE_THRESHOLD := 0.045

## Simulated frames granted on top of a nominal duration, so a condition that
## settles right on the edge of its budget is not lost to rounding.
const FRAME_BUDGET_GRACE := 30

var _capture_failures: Array[String] = []
var _captured_images: Dictionary = {}
var _capture_order: Array[String] = []
var _capture_records: Array[Dictionary] = []
var _capture_hashes: Dictionary = {}
var _variation_metrics: Dictionary = {}
var _source_paths := PackedStringArray()
var _source_snapshot: Dictionary = {}
var _source_aggregate_sha256 := ""
var _source_frozen_validated := false
var _evidence_camera: Camera3D
var _game: Node3D
var _hud: CanvasLayer
var _hud_identity: Dictionary = {}


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	if OS.get_environment(PARSE_ONLY_ENVIRONMENT_VARIABLE) == "1":
		print("CAPTURE_SCENES_PARSE_OK: 27-state source-current evidence inventory")
		quit(0)
		return

	_configure_native_capture()
	_source_paths = _collect_source_paths()
	_source_snapshot = _snapshot_source_files()
	_source_aggregate_sha256 = _source_snapshot_hash(_source_snapshot)
	_check(CAPTURE_FILES.size() == 27, "capture inventory retains exactly 27 named states")
	_check(
		_source_paths.size() > SOURCE_ROOTS.size()
		and _source_snapshot.size() == _source_paths.size()
		and not _source_aggregate_sha256.is_empty(),
		"production source scope has one complete deterministic start snapshot"
	)
	_prepare_staging_directory()
	if not _capture_failures.is_empty():
		_finish()
		return

	var packed := load(MAIN_SCENE_PATH) as PackedScene
	if packed == null:
		_fail("main scene did not load")
		_finish()
		return

	_game = packed.instantiate() as Node3D
	var game := _game
	if game == null:
		_fail("main scene did not instantiate as its production Node3D root")
		_finish()
		return
	root.add_child(game)
	_hud = game.get_node_or_null("HUD") as CanvasLayer
	_capture_hud_identity()
	await _frames(12)
	await _capture("title.png")

	var world := game.get_node_or_null("ShipyardWorld") as Node3D
	var player := game.get_node_or_null("Player") as CharacterBody3D
	var ship := game.get_node_or_null("TorrentInterceptor") as CharacterBody3D
	var arrow := game.get_node_or_null("ArrowReconShip") as ArrowReconShip
	var jovian := game.get_node_or_null("JovianLightFreighter") as JovianLightFreighter
	var zenith := game.get_node_or_null("ZenithInterceptor") as HeroShip
	var opponent := game.get_node_or_null("RangeOpponent") as CharacterBody3D
	var hud := _hud
	if world == null or player == null or ship == null or arrow == null or jovian == null or zenith == null or opponent == null or hud == null:
		_fail("main scene is missing a required vertical-slice node")
		await _dispose(game)
		_finish()
		return
	_validate_production_hud("initial production HUD")
	var habitat := world.call("get_habitat_spine") as HabitatSpine
	if habitat == null:
		_fail("shared world is missing its integrated Habitat Spine")
		await _dispose(game)
		_finish()
		return
	var freight_berth := world.call("get_jovian_freight_berth") as JovianFreightBerth
	if freight_berth == null:
		_fail("shared world is missing its integrated Jovian freight berth")
		await _dispose(game)
		_finish()
		return
	_check(game.get_node_or_null("ReserveInterceptor") == null, "retired duplicate ReserveInterceptor is absent from capture world")
	var fleet: Array[HeroShip] = game.call("get_flyable_ships")
	_check(
		fleet.size() == 4 and fleet.has(ship) and fleet.has(arrow) and fleet.has(jovian) and fleet.has(zenith),
		"capture world contains exactly the distinct Torrent, Arrow, Jovian, and Zenith production fleet"
	)

	# Long enough to photograph each physical transition, short enough for this
	# evidence run to remain useful in automated verification.
	game.set("canopy_motion_time", 0.8)
	game.set("boarding_motion_time", 1.55)
	game.set("disembarking_motion_time", 1.2)

	# Capture shortcut, disclosed in STAGING_INTERVENTIONS: invoke the production
	# title handler directly. This exercises its real GameFlow path, but is not UI
	# device-input evidence and must not be described as a clicked title control.
	hud.call("_begin")
	if not await _wait_for_phase(game, GameFlow.Phase.APPROACH_SHIP, 2.0):
		_fail("title-screen begin action did not enter the on-foot approach phase")
		await _dispose(game)
		_finish()
		return
	await _frames(5)

	_evidence_camera = Camera3D.new()
	_evidence_camera.name = "CaptureEvidenceCamera"
	_evidence_camera.near = 0.08
	_evidence_camera.far = 2200.0
	game.add_child(_evidence_camera)

	# A high three-quarter view reveals the source-informed exposed central
	# crossing, orthogonal berth arms, launch spine, and deliberate voids.
	_frame_camera(
		Vector3(64.0, 47.0, 59.0),
		Vector3(0.0, 0.4, -7.0),
		57.0
	)
	await _frames(7)
	await _capture("station.png")

	# The expanded sandbox now has the distinct Torrent, provisional Arrow recon
	# craft, and Jovian freighter on separate registered berths. Centre this high
	# three-quarter view on their full berth triangle: the added stand-off keeps the
	# long freight craft inside frame without shrinking the two smaller hulls into
	# an indistinct station-only overview.
	_frame_camera(
		Vector3(-18.0, 68.0, 82.0),
		Vector3(-25.0, 1.0, 22.0),
		64.0
	)
	await _frames(6)
	await _capture("fleet_overview.png")

	var aft_module := world.get_node_or_null("AftJunctionStack") as AftJunctionStack
	_check(aft_module != null, "capture world contains the integrated aft junction module")
	if aft_module != null:
		_frame_camera(
			aft_module.to_global(Vector3(28.0, 19.0, 25.0)),
			aft_module.to_global(Vector3(0.0, 2.4, 11.0)),
			57.0
		)
		await _frames(6)
		await _capture("aft_junction.png")

		# Open the real production door before moving the evidence camera into the
		# compact room. The component/integration suites separately prove that the
		# player discovers and walks through this same portal with E/W input.
		var operations_door := aft_module.get_operations_entrance()
		operations_door.interact(player)
		# The panel travels on the physics clock; wait for it to actually be open.
		await _wait_until(func() -> bool: return operations_door.is_open(), 0.7)
		_check(operations_door.is_open(), "operations-room evidence uses the physically open production door")
		_frame_camera(
			aft_module.to_global(Vector3(5.6, 2.35, 10.15)),
			aft_module.to_global(Vector3(5.6, 1.35, 15.4)),
			60.0
		)
		await _frames(6)
		await _capture("operations_room.png")

	# The starboard habitat is photographed as an attached part of the live
	# station, retaining its connecting lattice, neighbouring Dock Operations pod,
	# and broad glazed observation volume instead of presenting a detached prop.
	_check(world.call("get_habitat_spine") == habitat, "habitat exterior frame uses the production shared-world instance")
	_check(habitat.get_bunk_count() == 6 and habitat.get_chair_count() == 8, "habitat exterior belongs to the fully furnished production module")
	_frame_camera(
		Vector3(96.0, 31.0, -22.0),
		Vector3(37.0, 1.5, 15.5),
		56.0
	)
	await _frames(8)
	await _capture("habitat_exterior.png")

	# Open the real pressure door and put the same production player inside the
	# published observation/common volume. The evidence camera is the only
	# capture-only object; room, furniture, glazing, avatar, and door state are live.
	var habitat_door := habitat.get_main_access()
	_check(habitat_door != null and habitat_door.interact(player), "habitat common-room evidence opens the real StationDoor")
	# The panel travels on the physics clock; wait for the portal to actually clear.
	await _wait_until(
		func() -> bool: return habitat_door.is_open() and not habitat_door.is_portal_blocked(),
		0.7
	)
	_check(habitat_door.is_open() and not habitat_door.is_portal_blocked(), "habitat pressure portal is physically clear for the interior frame")
	var habitat_player_position := habitat.to_global(Vector3(-2.0, 0.18, 24.5))
	player.call(
		"teleport_to",
		Transform3D(Basis(Vector3.UP, -PI * 0.5), habitat_player_position)
	)
	await physics_frame
	await process_frame
	_check(habitat.contains_room(&"observation-common", player.global_position), "physical player stands inside the registered observation/common room")
	_frame_camera(
		habitat.to_global(Vector3(0.0, 2.55, 18.8)),
		habitat.to_global(Vector3(0.0, 1.75, 27.2)),
		56.0
	)
	await _frames(7)
	await _capture("habitat_common_room.png")

	# The port freight branch and its ship are one production-world composition.
	# Validate identity, evidence boundary, direct berth registration, and physical
	# placement before using capture cameras or moving the player near the vessel.
	var jovian_audit := jovian.get_jovian_audit_report()
	var jovian_evidence := jovian.get_jovian_evidence_report()
	var jovian_interior := jovian.get_walkable_interior_report()
	var jovian_home_transform := world.call(
		"get_berth_transform",
		&"jovian_freight_berth"
	) as Transform3D
	_check(bool(jovian_audit.get("valid", false)), "production Jovian passes its complete runtime audit")
	_check(
		jovian.get_ship_id() == &"jovian_provisional"
		and jovian.get_display_name() == "Jovian-class Light Freighter candidate"
		and jovian.get_role() == "Light freighter",
		"Jovian captures preserve the creator-supported class identity and light-freighter role"
	)
	_check(
		str(jovian_evidence.get("evidence_status", "")) == "provisional"
		and not bool(jovian_evidence.get("authenticated_geometry", true)),
		"Jovian captures retain explicit provisional-geometry evidence status"
	)
	_check(
		jovian.get_home_berth_id() == &"jovian_freight_berth"
		and freight_berth.get_berth_id() == &"jovian_freight_berth"
		and freight_berth.get_berth_transform().is_equal_approx(jovian_home_transform),
		"Jovian and the port freight module resolve the same direct production berth"
	)
	_check(
		jovian.global_transform.is_equal_approx(jovian_home_transform),
		"parked Jovian occupies its registered freight dock transform"
	)
	_check(
		jovian_interior.get("frame") == jovian
		and jovian_interior.get("root") == jovian.get_interior_root()
		and not bool(jovian_interior.get("detached_interior", true)),
		"Jovian cargo, passenger, and cockpit spaces share the live spacecraft frame"
	)

	# Start at the semantic freight approach marker, with the same embodied player
	# used everywhere else in the walkthrough. The low diagonal view keeps the
	# connection deck, gantry, apron, parked freighter, and walking scale legible.
	var freight_approach := freight_berth.get_route_transform(&"approach")
	player.call("teleport_to", freight_approach)
	await physics_frame
	await process_frame
	_check(
		player.global_position.distance_to(freight_approach.origin) < 0.4,
		"freight approach frame places the physical player on the production route"
	)
	_frame_camera(
		freight_berth.to_global(Vector3(31.0, 15.5, -15.0)),
		freight_berth.to_global(Vector3(0.0, 2.0, 25.0)),
		58.0
	)
	await _frames(8)
	await _capture("freight_dock_approach.png")

	# The cargo-ramp exit is a collision-safe world transform owned by the ship,
	# not a freestanding set marker. It gives the walk-up frame an honest human
	# scale while retaining the freight module behind the landed vessel.
	var jovian_ramp_exit := jovian.get_interior_exit_transform()
	player.call("teleport_to", jovian_ramp_exit)
	await physics_frame
	await process_frame
	_check(
		player.global_position.distance_to(jovian_ramp_exit.origin) < 0.4,
		"Jovian walk-up uses the ship-owned safe transform beyond the deployed ramp"
	)
	_check(
		not jovian.is_piloted()
		and str(jovian.get_telemetry().get("engine_state", "")) == "OFFLINE"
		and bool(jovian.get_telemetry().get("landed", false)),
		"Jovian walk-up records the genuinely parked, offline, unpiloted freighter"
	)
	_frame_camera(
		_ship_point(jovian, Vector3(-19.0, 6.3, -7.0)),
		_ship_point(jovian, Vector3(-1.5, 1.25, -0.5)),
		51.0
	)
	await _frames(7)
	await _capture("jovian_walkup.png")

	# A distant opposite-side three-quarter angle records the complete utility
	# silhouette and quad-engine arrangement independently of the port walk-up.
	_check(int(jovian_audit.get("engine_count", 0)) == 4, "Jovian profile belongs to the audited quad-engine production craft")
	_frame_camera(
		_ship_point(jovian, Vector3(25.0, 11.0, 16.5)),
		_ship_point(jovian, Vector3(0.0, 1.45, 0.0)),
		48.0
	)
	await _frames(7)
	await _capture("jovian_profile.png")

	# Move to the stable access marker at the foot of the ship-owned ramp. This
	# close view shows that the aperture and ramp connect directly to the lit bay.
	var interior_access := jovian.get_interior_access_marker()
	_check(interior_access != null, "Jovian exposes its production cargo-ramp access marker")
	if interior_access != null:
		player.call("teleport_to", interior_access.global_transform)
	await physics_frame
	await process_frame
	_check(
		interior_access != null
		and player.global_position.distance_to(interior_access.global_position) < 0.4,
		"cargo-ramp frame places the physical player at the ship-local access threshold"
	)
	_frame_camera(
		_ship_point(jovian, Vector3(-16.8, 3.8, 7.4)),
		_ship_point(jovian, Vector3(-5.25, 1.55, 3.2)),
		54.0
	)
	await _frames(7)
	await _capture("jovian_cargo_ramp.png")

	# Put the real world player on the physical cargo deck and register that body
	# with the production moving-interior coordinator. The camera is the only
	# capture object; bay meshes, colliders, cargo, lights, and avatar remain live.
	player.call("set_control_enabled", false)
	var cargo_player_transform := jovian.global_transform * Transform3D(
		Basis.IDENTITY,
		Vector3(0.0, 0.64, 3.15)
	)
	player.call("teleport_to", cargo_player_transform)
	await physics_frame
	await process_frame
	var moving_interior := jovian.get_moving_interior_component()
	_check(moving_interior != null, "Jovian exposes its typed production moving-interior coordinator")
	var interior_registration := moving_interior.register_occupant(player) if moving_interior != null else {}
	_check(
		moving_interior != null
		and bool(interior_registration.get("registered", false))
		and moving_interior.is_occupant_registered(player),
		"visible cargo-bay player is registered to the Jovian moving frame"
	)
	_check(
		moving_interior != null
		and moving_interior.contains_world_position(player.global_position)
		and jovian.get_interior_bounds().has_point(jovian.to_local(player.global_position)),
		"visible cargo-bay player physically occupies the published ship-local cabin envelope"
	)
	_check(
		jovian.get_cargo_bay_root() != null
		and jovian.get_cargo_hardpoints().size() >= 4,
		"cargo-bay frame uses the furnished production room and stable freight hardpoints"
	)
	_frame_camera(
		_ship_point(jovian, Vector3(0.0, 2.65, 8.05)),
		_ship_point(jovian, Vector3(0.0, 1.45, -2.65)),
		67.0
	)
	await _frames(7)
	await _capture("jovian_cargo_bay.png")

	# The connected passenger room is reached without changing scenes or frames.
	# Exercise one real rigid-frame translation and return while the avatar is
	# visible there, proving that its ship-local deck position is preserved.
	var passenger_player_transform := jovian.global_transform * Transform3D(
		Basis.IDENTITY,
		Vector3(0.72, 0.64, -5.25)
	)
	player.call("teleport_to", passenger_player_transform)
	await physics_frame
	await process_frame
	_check(
		moving_interior != null and moving_interior.is_occupant_registered(player),
		"passenger-cabin avatar remains owned by the same moving-interior coordinator"
	)
	_check(
		jovian.get_passenger_cabin_root() != null
		and jovian.get_passenger_seat_anchors().size() >= 6
		and jovian.get_interior_bounds().has_point(jovian.to_local(player.global_position)),
		"passenger-cabin avatar stands inside the connected furnished production interior"
	)
	if moving_interior != null:
		moving_interior.set_physics_process(false)
		var passenger_local_before := jovian.to_local(player.global_position)
		var docked_jovian_transform := jovian.global_transform
		moving_interior.reset_frame_tracking(true)
		jovian.global_transform = Transform3D(
			docked_jovian_transform.basis,
			docked_jovian_transform.origin + Vector3(0.42, 0.12, -0.28)
		)
		var carry_out := moving_interior.step_frame(1.0 / 60.0, 1)
		_check(
			bool(carry_out.get("applied", false))
			and int(carry_out.get("occupants_applied", 0)) >= 1
			and jovian.to_local(player.global_position).distance_to(passenger_local_before) < 0.015,
			"moving-interior step carries the visible passenger with invariant ship-local position"
		)
		jovian.global_transform = docked_jovian_transform
		var carry_home := moving_interior.step_frame(1.0 / 60.0, 2)
		_check(
			bool(carry_home.get("applied", false))
			and jovian.to_local(player.global_position).distance_to(passenger_local_before) < 0.015
			and jovian.global_transform.is_equal_approx(jovian_home_transform),
			"moving-interior return restores the ship to its registered physical freight berth"
		)
		moving_interior.reset_frame_tracking(true)
		moving_interior.set_physics_process(true)
	_frame_camera(
		_ship_point(jovian, Vector3(-0.65, 2.05, -7.25)),
		_ship_point(jovian, Vector3(0.4, 1.45, -4.25)),
		68.0
	)
	await _frames(7)
	await _capture("jovian_passenger_cabin.png")

	# Transfer from the walking interior to the independent pilot-hatch lifecycle.
	# Registration is explicitly released first so no frame component can double-
	# apply the seated anchor motion owned by PlayerController.
	if moving_interior != null:
		var interior_release := moving_interior.unregister_occupant(
			player,
			false,
			&"capture_pilot_transfer"
		)
		_check(bool(interior_release.get("released", false)), "pilot transfer releases moving-interior occupant ownership exactly once")
	var jovian_boarding_point := jovian.get_boarding_position()
	var freight_deck_height := freight_berth.get_route_transform(&"boarding-staging").origin.y
	var jovian_boarding_start := Vector3(
		jovian_boarding_point.x,
		freight_deck_height,
		jovian_boarding_point.z
	)
	player.call(
		"teleport_to",
		Transform3D(jovian.global_basis.orthonormalized(), jovian_boarding_start)
	)
	player.call("set_control_enabled", true)
	await _frames(5)
	Input.action_press("interact")
	await physics_frame
	await physics_frame
	Input.action_release("interact")
	if not await _wait_for_phase(game, GameFlow.Phase.BOARDING, 1.0):
		_fail("real interact input did not begin Jovian pilot-hatch boarding")
		await _dispose(game)
		_finish()
		return
	if not await _wait_for_phase(game, GameFlow.Phase.START_ENGINES, 4.5):
		_fail("Jovian boarding did not complete at its physical pilot seat")
		await _dispose(game)
		_finish()
		return
	_check(
		game.call("get_active_ship") == jovian
		and jovian.is_piloted()
		and bool(player.call("is_seated")),
		"Jovian cockpit frame uses the active production ship and physically seated pilot"
	)
	_check(
		player.global_position.distance_to(jovian.get_pilot_seat_anchor().global_position) < 0.08,
		"Jovian pilot occupies its live ship-local seat anchor"
	)
	jovian.set_cockpit_view(true)
	_evidence_camera.current = false
	var jovian_cockpit_camera := jovian.get_camera()
	jovian_cockpit_camera.current = true
	await _frames(7)
	_check(
		jovian.get_camera_view() == &"COCKPIT" and jovian_cockpit_camera.current,
		"Jovian cockpit evidence uses the production pilot-eye camera"
	)
	await _capture("jovian_cockpit.png")

	# Start and launch the freighter through the normal engine and throttle paths.
	# Its own chase rig and live HUD record a real heavy-craft sortie rather than a
	# static exterior repositioned against an unrelated background.
	jovian.request_engine_start()
	if not await _wait_for_phase(game, GameFlow.Phase.FREE_FLIGHT, 5.0):
		_fail("Jovian engine startup did not enter the sandbox free-flight phase")
		await _dispose(game)
		_finish()
		return
	jovian.set_cockpit_view(false)
	await _frames(4)
	Input.action_press("move_forward")
	# Throttle motion is integrated in `_physics_process`; wait for the departure
	# the frame below asserts on rather than for 1.45 s of smoothed engine delta.
	await _wait_until(
		func() -> bool:
			var telemetry := jovian.get_telemetry()
			return (
				jovian.velocity.length() > 5.0
				and not bool(telemetry.get("landed", true))
				and jovian.global_position.distance_to(jovian_home_transform.origin) > 2.0
			),
		1.45
	)
	var jovian_launch_telemetry := jovian.get_telemetry()
	_check(
		jovian.velocity.length() > 5.0
		and not bool(jovian_launch_telemetry.get("landed", true))
		and jovian.global_position.distance_to(jovian_home_transform.origin) > 2.0,
		"Jovian launch frame is backed by real throttle motion clear of its freight berth"
	)
	_check(
		game.call("get_active_ship") == jovian
		and int(game.get("phase")) == GameFlow.Phase.FREE_FLIGHT
		and jovian.get_camera().current
		and world.call("get_berth_node", &"jovian_freight_berth").get_occupant() == null,
		"Jovian launch retains production free-flight authority, HUD, and chase camera"
	)
	await _frames(4)
	await _capture("jovian_launch.png")
	Input.action_release("move_forward")

	# Capture-only approach positioning mirrors the later guided Torrent landing:
	# the actual landing assist still performs the final movement, basis alignment,
	# latch, berth re-occupation, phase change, and engine-running return state.
	jovian.global_transform = Transform3D(
		jovian_home_transform.basis,
		jovian_home_transform.origin + Vector3.UP * 3.0
	)
	jovian.reset_physics_interpolation()
	jovian.velocity = Vector3.ZERO
	game.call("_try_request_landing")
	var jovian_landing_accepted := bool(game.get("_landing_request_active"))
	_check(jovian_landing_accepted, "GameFlow landing assist accepts and reserves the slow staged Jovian home approach")
	if not await _wait_for_phase(game, GameFlow.Phase.SHUT_DOWN, 12.0):
		var failed_return_telemetry := jovian.get_telemetry()
		_fail(
			"Jovian landing did not return to the registered freight berth "
			+ "(phase=%d landed=%s speed=%.3f distance=%.3f)"
			% [
				int(game.get("phase")),
				str(failed_return_telemetry.get("landed", false)),
				jovian.velocity.length(),
				jovian.global_position.distance_to(jovian_home_transform.origin),
			]
		)
		await _dispose(game)
		_finish()
		return
	var jovian_return_telemetry := jovian.get_telemetry()
	_check(
		bool(jovian_return_telemetry.get("landed", false))
		and str(jovian_return_telemetry.get("engine_state", "")) == "ONLINE"
		and jovian.global_transform.is_equal_approx(jovian_home_transform),
		"Jovian return frame records a running craft physically latched at its exact home berth"
	)
	_frame_camera(
		freight_berth.to_global(Vector3(29.0, 12.0, 7.0)),
		freight_berth.to_global(Vector3(0.0, 2.2, 29.0)),
		50.0
	)
	await _frames(6)
	await _capture("jovian_return.png")

	# Leave the freight sortie cleanly so the original Arrow evidence and guided
	# Torrent walkthrough continue in the same production scene instance.
	jovian.request_engine_stop()
	await _frames(3)
	var jovian_pilot_exit := jovian.get_exit_transform()
	game.call("_try_exit_ship")
	if not await _wait_for_phase(game, GameFlow.Phase.DISEMBARKING, 1.0):
		_fail("landed offline Jovian did not begin physical pilot-hatch disembarkation")
		await _dispose(game)
		_finish()
		return
	if not await _wait_for_phase(game, GameFlow.Phase.APPROACH_SHIP, 4.5):
		_fail("Jovian disembarkation did not restore the pending guided on-foot phase")
		await _dispose(game)
		_finish()
		return
	_check(
		not jovian.is_piloted()
		and not bool(player.call("is_seated"))
		and bool(player.call("is_control_enabled"))
		and player.global_position.distance_to(jovian_pilot_exit.origin) < 0.2,
		"Jovian return restores the same physical pilot to its collision-safe on-foot exit"
	)
	_check(
		jovian.global_transform.is_equal_approx(jovian_home_transform)
		and str(jovian.get_telemetry().get("engine_state", "")) == "OFFLINE",
		"completed Jovian evidence leaves the production freighter safely offline at home"
	)

	# Walk the same player to the Arrow's collision-safe port-side egress point for
	# an embodied scale frame. The craft remains parked, offline, and unpiloted so
	# this does not consume or bypass the later guided Torrent boarding sequence.
	var arrow_walkup_transform := arrow.get_exit_transform()
	player.call(
		"teleport_to",
		arrow_walkup_transform
	)
	await physics_frame
	await process_frame
	_check(player.global_position.distance_to(arrow.global_position) > 5.8, "Arrow walk-up uses the production collision-safe on-foot position beyond its sensor wing")
	_check(not arrow.is_piloted() and str(arrow.get_telemetry().engine_state) == "OFFLINE", "Arrow walk-up records an honestly parked and inactive craft")
	# Stay in the clear half-space between the pilot exit and Arrow. In Arrow-local
	# coordinates the registry pod ends at x=-7.5 while the physical player exit is
	# x=-6.6, so this complete sightline remains outside the pod rather than merely
	# placing its camera origin beyond one of the pod's corners.
	_frame_camera(
		_ship_point(arrow, Vector3(-6.2, 4.8, -13.0)),
		_ship_point(arrow, Vector3(-2.5, 0.75, 0.0)),
		52.0
	)
	await _frames(7)
	await _capture("arrow_walkup.png")

	# A separate broadside/three-quarter profile makes the slender recon fuselage,
	# swept sensor planform, and supported two-pod count independently readable.
	var arrow_evidence := arrow.get_arrow_evidence_report()
	_check(str(arrow_evidence.evidence_status) == "provisional" and not bool(arrow_evidence.authenticated_geometry), "Arrow profile retains explicit provisional geometry status")
	_check(arrow.get_escape_pod_count() == 2, "Arrow profile exposes the creator-supported two-pod count")
	_check(arrow.global_transform.is_equal_approx(world.call("get_berth_transform", &"arrow_recon_berth")), "Arrow profile uses its registered rotated recon berth")
	# Photograph the opposite broadside from west of the registry footprint. The
	# pod remains spatially connected to the berth, but this angle sees its front
	# face at a separated oblique instead of presenting mirrored backside text.
	_frame_camera(
		_ship_point(arrow, Vector3(-12.2, 8.4, -13.0)),
		_ship_point(arrow, Vector3(0.0, 1.2, 0.0)),
		46.0
	)
	await _frames(7)
	await _capture("arrow_profile.png")

	# Capture-only shortcut: place the real on-foot character beside the port
	# boarding point. Interaction and every subsequent state transition still use
	# the normal input/signal/gameplay path.
	var boarding_point: Vector3 = ship.call("get_boarding_position")
	var deck_height: float = float((world.call("get_player_spawn") as Transform3D).origin.y)
	var boarding_start := Vector3(boarding_point.x - 0.65, deck_height, boarding_point.z + 0.25)
	player.call("teleport_to", Transform3D(Basis(Vector3.UP, -PI * 0.5), boarding_start))
	await _frames(5)
	Input.action_press("interact")
	await physics_frame
	await physics_frame
	Input.action_release("interact")
	if not await _wait_for_phase(game, GameFlow.Phase.BOARDING, 1.0):
		_fail("real interact input did not begin boarding")
		await _dispose(game)
		_finish()
		return

	_frame_camera(
		_ship_point(ship, Vector3(-8.6, 5.9, -0.25)),
		_ship_point(ship, Vector3(-0.15, 3.25, -0.35)),
		50.0
	)
	# Canopy opens for 0.8 s, then the pilot climbs for 1.55 s. Wait for the
	# canopy to be fully open and the pilot visibly crossing the sill — the exact
	# state the frame below asserts on — instead of for 1.48 s of smoothed engine
	# delta. `is_seated()` ends the wait too, so an overshoot fails loudly on the
	# assertions rather than silently burning the budget.
	await _wait_until(
		func() -> bool:
			return (
				bool(player.call("is_seated"))
				or (
					bool(ship.call("is_canopy_open"))
					and player.global_position.distance_to(boarding_start) > 0.75
				)
			),
		1.48
	)
	_frame_camera(
		_ship_point(ship, Vector3(-8.6, 5.9, -0.25)),
		_ship_point(ship, Vector3(-0.15, 3.25, -0.35)),
		50.0
	)
	_check(int(game.get("phase")) == GameFlow.Phase.BOARDING, "boarding remains in progress for the transition frame")
	_check(bool(ship.call("is_canopy_open")), "boarding frame has the canopy fully open")
	_check(not bool(player.call("is_seated")), "boarding frame precedes the seated state")
	_check(player.global_position.distance_to(boarding_start) > 0.75, "boarding frame contains visible pilot movement")
	await _capture("boarding.png")

	if not await _wait_for_phase(game, GameFlow.Phase.START_ENGINES, 4.0):
		_fail("boarding did not complete in the physical pilot seat")
		await _dispose(game)
		_finish()
		return
	var seat_anchor := ship.call("get_pilot_seat_anchor") as Node3D
	_check(bool(player.call("is_seated")), "pilot is physically seated after boarding")
	_check(not bool(ship.call("is_canopy_open")), "canopy seals around the seated pilot")
	_check(
		seat_anchor != null and player.global_position.distance_to(seat_anchor.global_position) < 0.08,
		"seated pilot occupies the ship's live seat anchor"
	)
	_frame_camera(
		_ship_point(ship, Vector3(-5.15, 4.65, -3.35)),
		_ship_point(ship, Vector3(0.0, 3.05, -0.35)),
		42.0
	)
	await _frames(6)
	await _capture("seated_cockpit.png")

	# The rear evidence angle is intentionally different from the cockpit frame;
	# it records the real STARTING state and both animated engine exhausts.
	ship.call("request_engine_start")
	# This frame wants the craft *mid* spin-up, so there is no settling condition
	# to wait on — the 0.82 s is the intent. Spend it on the clock the exhaust
	# animation and the engine timer actually advance on. The STARTING assertion
	# below is what proves the window was not overshot.
	await _advance_simulated(0.82)
	_check(
		str((ship.call("get_telemetry") as Dictionary).get("engine_state", "")).to_upper() == "STARTING",
		"engine-start capture occurs during the deliberate startup state"
	)
	_frame_camera(
		_ship_point(ship, Vector3(0.0, 3.7, 12.6)),
		_ship_point(ship, Vector3(0.0, 1.45, 3.75)),
		54.0
	)
	await _frames(5)
	await _capture("engine_startup.png")
	if not await _wait_for_phase(game, GameFlow.Phase.LAUNCH, 3.0):
		_fail("engine startup did not advance to launch")
		await _dispose(game)
		_finish()
		return

	# Capture-only positioning puts the craft clear of foreground dock geometry.
	# Forward motion below is nevertheless generated by the real throttle action.
	ship.global_position = Vector3(0.0, 18.0, -96.0)
	ship.global_basis = Basis.IDENTITY
	ship.velocity = Vector3.ZERO
	ship.call("set_cockpit_view", false)
	_evidence_camera.current = false
	var ship_camera := ship.call("get_camera") as Camera3D
	ship_camera.current = true
	Input.action_press("move_forward")
	# Throttle acceleration is integrated in `_physics_process`; wait for the
	# speed the frame asserts on rather than for 0.95 s of smoothed engine delta.
	await _wait_until(func() -> bool: return ship.velocity.length() > 8.0, 0.95)
	_check(ship.velocity.length() > 8.0, "chase-flight frame is backed by real throttle-driven motion")
	var telemetry_panel := hud.get("_telemetry_panel") as Control
	var reticle := hud.get("_reticle") as Control
	_check(telemetry_panel != null and telemetry_panel.visible, "chase-flight frame exposes live HUD telemetry")
	_check(reticle != null and reticle.visible, "chase-flight frame exposes the weapon reticle")
	_check(ship_camera.current, "chase-flight frame uses the production chase camera")
	_check(
		ship_camera.project_ray_normal(ship_camera.get_viewport().get_visible_rect().size * 0.5).normalized().dot(-ship.global_basis.z.normalized()) > 0.995,
		"chase reticle ray aligns with the craft's physical nose"
	)
	await _frames(4)
	await _capture("flight.png")

	ship.call("set_cockpit_view", true)
	await _frames(7)
	_check(str(ship.call("get_camera_view")) == "COCKPIT", "cockpit-flight frame uses the physical pilot-eye camera")
	var cockpit_camera := ship.call("get_camera") as Camera3D
	_check(cockpit_camera.current, "cockpit-flight frame uses the production cockpit camera")
	_check(
		cockpit_camera.project_ray_normal(cockpit_camera.get_viewport().get_visible_rect().size * 0.5).normalized().dot(-ship.global_basis.z.normalized()) > 0.995,
		"cockpit reticle ray aligns with the same physical nose as chase view"
	)
	await _capture("cockpit_flight.png")
	Input.action_release("move_forward")

	# Enter the live encounter through the production coordinator, then freeze only
	# the opponent's navigation for a stable evidence composition. Damage, smoke,
	# HUD health, incoming raycast damage, and the pooled pulse remain real systems.
	game.call("_begin_interceptor_engagement")
	await _frames(4)
	ship.call("set_cockpit_view", false)
	await _frames(4)
	ship_camera = ship.call("get_camera") as Camera3D
	var screen_center := ship_camera.get_viewport().get_visible_rect().size * 0.5
	var view_direction := ship_camera.project_ray_normal(screen_center).normalized()
	opponent.set_physics_process(false)
	# Keep the damaged interceptor large enough to read without letting its broad
	# prongs occlude the chase craft, reticle, or directional-damage HUD.
	opponent.global_position = ship_camera.global_position + view_direction * 50.0 + ship_camera.global_basis.x * 3.8
	opponent.look_at(ship.global_position, Vector3.UP, true)
	opponent.velocity = Vector3.ZERO
	opponent.call("apply_damage", 58.0, opponent.global_position + Vector3.UP * 0.6)
	# The damage stage is applied synchronously; this short wait only lets the
	# persistent smoke emitter put particles in the world, which it does on the
	# simulation clock. There is nothing to poll, so spend the same nominal
	# duration in physics steps rather than in smoothed engine delta.
	await _advance_simulated(0.18)
	var hull_before := float((ship.call("get_telemetry") as Dictionary).get("hull", 0.0))
	var hull_shape := ship.find_child("HullCollision", true, false) as CollisionShape3D
	var hull_target := hull_shape.global_position if hull_shape != null else ship.global_position + Vector3.UP
	game.call(
		"_on_opponent_projectile_fired",
		opponent.global_position,
		(hull_target - opponent.global_position).normalized()
	)
	var pulse_presentation := game.get_node_or_null("PulseWeaponPresentation") as PulseWeaponPresentation
	await physics_frame
	await process_frame
	_check(float((ship.call("get_telemetry") as Dictionary).get("hull", 0.0)) < hull_before, "enemy raycast produces real hero-ship damage")
	_check(float(opponent.call("get_health")) <= float(opponent.get("maximum_health")) * 0.34, "dogfight frame shows the opponent's critical damage stage")
	var smoke := opponent.find_child("EngineSmoke", true, false) as CPUParticles3D
	_check(smoke != null and smoke.emitting, "dogfight frame includes persistent damaged-engine smoke")
	var enemy_panel := hud.get("_enemy_panel") as Control
	var damage_direction := hud.get("_damage_direction") as Control
	_check(enemy_panel != null and enemy_panel.visible, "dogfight frame exposes live enemy health and damage status")
	_check(damage_direction != null and damage_direction.visible, "dogfight frame exposes directional incoming-damage feedback")
	_check(
		pulse_presentation != null
		and int(pulse_presentation.get_statistics().get("presented", 0)) > 0,
		"dogfight frame is backed by the bounded authoritative pulse presentation"
	)
	await _capture("dogfight.png")

	# Resolve the same live opponent through its damage API to obtain the real
	# return-to-yard mission state before testing landing assist.
	opponent.call("apply_damage", 999.0, opponent.global_position)
	if not await _wait_for_phase(game, GameFlow.Phase.RETURN_TO_YARD, 2.0):
		_fail("opponent destruction did not assign the return-to-yard phase")
		await _dispose(game)
		_finish()
		return

	var landing_transform := world.call("get_ship_spawn") as Transform3D
	ship.global_transform = landing_transform.translated(Vector3(0.0, 3.0, 0.0))
	ship.velocity = Vector3.ZERO
	_frame_camera(
		Vector3(-20.0, 10.2, 7.5),
		landing_transform.origin + Vector3(0.0, 1.15, 0.0),
		55.0
	)
	game.call("_try_request_landing")
	_check(bool(ship.call("is_landing_active")), "landing assist accepts a slow craft above the physical berth")
	if not await _wait_for_phase(game, GameFlow.Phase.SHUT_DOWN, 4.0):
		_fail("landing assist did not complete on the physical pad")
		await _dispose(game)
		_finish()
		return
	_frame_camera(
		Vector3(-20.0, 10.2, 7.5),
		landing_transform.origin + Vector3(0.0, 1.15, 0.0),
		55.0
	)
	var landed_telemetry := ship.call("get_telemetry") as Dictionary
	_check(bool(landed_telemetry.get("landed", false)), "touchdown frame records the craft latched to the landing pad")
	_check(ship.global_position.distance_to(landing_transform.origin) < 0.2, "touchdown completes at the real shipyard berth transform")
	await _frames(4)
	await _capture("touchdown.png")

	ship.call("request_engine_stop")
	await _frames(3)
	game.call("_try_exit_ship")
	if not await _wait_for_phase(game, GameFlow.Phase.DISEMBARKING, 1.0):
		_fail("landed offline craft did not begin disembarkation")
		await _dispose(game)
		_finish()
		return
	var disembark_seat_position := player.global_position
	# Wait for the exit transition the frame below asserts on, rather than for
	# 1.27 s of smoothed engine delta. Leaving DISEMBARKING ends the wait too, so
	# an overshoot fails loudly on the assertions instead of burning the budget.
	await _wait_until(
		func() -> bool:
			return (
				int(game.get("phase")) != GameFlow.Phase.DISEMBARKING
				or (
					bool(ship.call("is_canopy_open"))
					and player.global_position.distance_to(disembark_seat_position) > 0.6
				)
			),
		1.27
	)
	_frame_camera(
		_ship_point(ship, Vector3(-13.2, 6.2, 6.6)),
		_ship_point(ship, Vector3(-3.5, 2.1, 0.35)),
		53.0
	)
	var exit_transform := ship.call("get_exit_transform") as Transform3D
	_check(int(game.get("phase")) == GameFlow.Phase.DISEMBARKING, "disembark frame remains inside the physical exit transition")
	_check(bool(ship.call("is_canopy_open")), "disembark frame has the canopy fully open")
	_check(player.global_position.distance_to(disembark_seat_position) > 0.6, "disembark frame contains visible pilot movement out of the seat")
	_check(player.global_position.distance_to(exit_transform.origin) > 0.4, "disembark frame precedes the final on-foot placement")
	await _capture("disembark.png")

	if not await _wait_for_phase(game, GameFlow.Phase.COMPLETE, 4.0):
		_fail("disembarkation did not return control to the on-foot player")
		await _dispose(game)
		_finish()
		return
	_check(not bool(player.call("is_seated")), "final frame has the real pilot back on foot")
	_check(bool(player.call("is_control_enabled")), "final frame restores on-foot control")
	_check(player.global_position.distance_to(exit_transform.origin) < 0.2, "final player stands beside the same landed spacecraft")
	_frame_camera(
		_ship_point(ship, Vector3(-14.2, 5.4, -5.6)),
		_ship_point(ship, Vector3(-3.7, 1.75, 0.1)),
		54.0
	)
	await _frames(7)
	await _capture("return_on_foot.png")

	_validate_capture_set()
	_validate_source_frozen()
	if _capture_failures.is_empty():
		_write_source_manifest(STAGING_DIR.path_join(SOURCE_MANIFEST_PATH.get_file()))
		_write_evidence_manifest(STAGING_DIR.path_join(EVIDENCE_MANIFEST_PATH.get_file()))
	if _capture_failures.is_empty():
		_publish_evidence_set()
	await _dispose(game)
	_finish()


func _configure_native_capture() -> void:
	DisplayServer.window_set_size(CAPTURE_RESOLUTION)
	root.size = CAPTURE_RESOLUTION
	root.content_scale_size = Vector2i.ZERO
	root.use_taa = true
	root.msaa_3d = Viewport.MSAA_2X
	var renderer := StringName(RenderingServer.get_current_rendering_method())
	var display_name := DisplayServer.get_name()
	var native_window_size := DisplayServer.window_get_size()
	_check(renderer == &"forward_plus", "capture uses the Forward+ renderer")
	_check(display_name == "X11", "capture uses a native X11 display")
	_check(root.size == CAPTURE_RESOLUTION, "root viewport is exactly 2560x1440")
	_check(
		native_window_size == CAPTURE_RESOLUTION,
		"native X11 window content is exactly 2560x1440"
	)
	print(
		"CAPTURE_SCENES_RENDERER: method=%s adapter=%s display=%s window=%dx%d viewport=%dx%d"
		% [
			renderer,
			RenderingServer.get_video_adapter_name(),
			display_name,
			native_window_size.x,
			native_window_size.y,
			root.size.x,
			root.size.y,
		]
	)


func _prepare_staging_directory() -> void:
	var staging_absolute := ProjectSettings.globalize_path(STAGING_DIR)
	var directory_error := DirAccess.make_dir_recursive_absolute(staging_absolute)
	_check(
		directory_error == OK or directory_error == ERR_ALREADY_EXISTS,
		"private gameplay-capture staging directory is available"
	)
	if directory_error != OK and directory_error != ERR_ALREADY_EXISTS:
		return
	var staged_names: Array[String] = CAPTURE_FILES.duplicate()
	staged_names.append(SOURCE_MANIFEST_PATH.get_file())
	staged_names.append(EVIDENCE_MANIFEST_PATH.get_file())
	for file_name in staged_names:
		var path := STAGING_DIR.path_join(file_name)
		if FileAccess.file_exists(path):
			var remove_error := DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
			_check(remove_error == OK, "stale private staging file clears: %s" % file_name)


func _capture_hud_identity() -> void:
	if _hud == null:
		_hud_identity = {}
		return
	var hud_script := _hud.get_script() as Script
	_hud_identity = {
		"instance_id": _hud.get_instance_id(),
		"parent": _hud.get_parent(),
		"scene_file_path": _hud.scene_file_path,
		"script_path": hud_script.resource_path if hud_script != null else "",
		"layer": _hud.layer,
	}


func _validate_production_hud(context: String) -> void:
	var hud_script := _hud.get_script() as Script if _hud != null else null
	_check(
		_hud != null
		and is_instance_valid(_hud)
		and _hud.get_instance_id() == int(_hud_identity.get("instance_id", 0))
		and _hud.get_parent() == _game
		and _hud.get_parent() == _hud_identity.get("parent")
		and _hud.scene_file_path == HUD_SCENE_PATH
		and _hud.scene_file_path == str(_hud_identity.get("scene_file_path", ""))
		and hud_script != null
		and hud_script.resource_path == HUD_SCRIPT_PATH
		and hud_script.resource_path == str(_hud_identity.get("script_path", ""))
		and _hud.layer == int(_hud_identity.get("layer", -1))
		and bool(_hud.get("visible")),
		"%s retains the same visible production HUD CanvasLayer" % context
	)


func _frame_camera(world_position: Vector3, focus: Vector3, field_of_view: float) -> void:
	if _evidence_camera == null:
		return
	_evidence_camera.global_position = world_position
	_evidence_camera.fov = field_of_view
	_evidence_camera.look_at(focus, Vector3.UP)
	_evidence_camera.current = true


func _ship_point(ship: Node3D, local_point: Vector3) -> Vector3:
	return ship.global_transform * local_point


func _wait_for_phase(game: Node, expected_phase: int, timeout_seconds: float) -> bool:
	return await _wait_until(
		func() -> bool: return int(game.get("phase")) == expected_phase,
		timeout_seconds
	)


## Waits for `predicate` on both the simulation clock and the monotonic clock,
## giving up only once both budgets are spent.
##
## Software-rendered 2560x1440 Forward+ evidence takes substantially longer than
## real time to advance one simulated second, which the previous form tried to
## absorb with a `SceneTreeTimer`. That is the worst of both clocks: the timer
## counts Godot's smoothed engine delta, the loop advances the physics clock, and
## the engine drops physics steps rather than letting the simulation spiral, so
## the timer expired with the transition only part-stepped. `GameFlow` also
## releases some work against a monotonic deadline (`Time.get_ticks_msec()`),
## which neither of those clocks measures.
##
## `timeout_seconds` is kept as the *nominal* duration and becomes both a budget
## of simulated frames and a wall-clock deadline. The frame budget is added
## alongside the original deadline rather than replacing it, so a monotonic
## release stays bounded on the clock that owns it and a frame budget cannot
## stretch the window over an unbounded run of wall clock on its own. Both bounds
## stay finite, so a genuinely stuck condition still fails the capture.
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


## Advances `seconds` worth of simulated time as a count of physics steps.
##
## For the handful of waits that are genuinely "let the presentation play for a
## while" with no condition to settle on, the nominal duration is still the
## intent — but it has to be spent on the clock the presentation advances on. A
## `SceneTreeTimer` spends it on the smoothed engine delta instead, and on a
## starved box that expires having stepped the simulation only part of the way.
func _advance_simulated(seconds: float) -> void:
	var steps := maxi(
		int(ceil(maxf(seconds, 0.0) * float(Engine.physics_ticks_per_second))),
		1
	)
	for _step in steps:
		await physics_frame
	await process_frame


func _frames(count: int) -> void:
	for _index in count:
		await process_frame


func _capture(file_name: String) -> void:
	var expected_index := _capture_order.size()
	_check(
		expected_index < CAPTURE_FILES.size()
		and CAPTURE_FILES[expected_index] == file_name,
		"capture follows the exact declared state order at %s" % file_name
	)
	_validate_production_hud("frame %s" % file_name)

	# Waiting for post-draw prevents sampling the prior camera's frame after a
	# same-tick view switch.
	await process_frame
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	if image == null or image.is_empty():
		_fail("empty viewport image for " + file_name)
		return
	var actual_size := Vector2i(image.get_width(), image.get_height())
	_check(actual_size == CAPTURE_RESOLUTION, "%s is exactly 2560x1440" % file_name)
	if actual_size != CAPTURE_RESOLUTION:
		return

	# Normalise to one declared PNG type rather than accepting whichever viewport
	# surface format happened to be returned by the host.
	if image.get_format() != Image.FORMAT_RGB8:
		image.convert(Image.FORMAT_RGB8)
	_check(image.get_format() == Image.FORMAT_RGB8, "%s readback is canonical RGB8" % file_name)
	if image.get_format() != Image.FORMAT_RGB8:
		return

	var luminance := _sample_luminance_statistics(image)
	var luminance_range := float(luminance.get("range", 0.0))
	var luminance_variance := float(luminance.get("variance", 0.0))
	_check(
		luminance_range >= MINIMUM_LUMINANCE_RANGE,
		"%s is nonblank (sampled luminance range %.5f)" % [file_name, luminance_range]
	)
	_check(
		luminance_variance >= MINIMUM_LUMINANCE_VARIANCE,
		"%s contains tonal detail (sampled variance %.6f)"
		% [file_name, luminance_variance]
	)
	if (
		luminance_range < MINIMUM_LUMINANCE_RANGE
		or luminance_variance < MINIMUM_LUMINANCE_VARIANCE
	):
		return

	var path := STAGING_DIR.path_join(file_name)
	var error := image.save_png(path)
	if error != OK:
		_fail("%s could not be saved: %s" % [file_name, error_string(error)])
		return
	if not FileAccess.file_exists(path):
		_fail("%s is missing after save" % file_name)
		return
	var file := FileAccess.open(path, FileAccess.READ)
	var byte_count := file.get_length() if file != null else 0
	if byte_count < MINIMUM_CAPTURE_BYTES:
		_fail("%s is unexpectedly small on disk (%d bytes)" % [file_name, byte_count])
		return
	var png_report := _inspect_png(path)
	_check(bool(png_report.get("valid", false)), "%s is exact 8-bit RGB non-interlaced PNG" % file_name)
	_check(
		Vector2i(
			int(png_report.get("width", 0)),
			int(png_report.get("height", 0))
		) == CAPTURE_RESOLUTION,
		"%s saved PNG decodes at exactly 2560x1440" % file_name
	)
	if (
		not bool(png_report.get("valid", false))
		or int(png_report.get("width", 0)) != CAPTURE_RESOLUTION.x
		or int(png_report.get("height", 0)) != CAPTURE_RESOLUTION.y
	):
		return
	var digest := FileAccess.get_sha256(path)
	_check(digest.length() == 64, "%s has a full SHA-256 digest" % file_name)
	_check(not _capture_hashes.has(digest), "%s has a unique full-file SHA-256" % file_name)
	if digest.length() != 64 or _capture_hashes.has(digest):
		return
	_capture_hashes[digest] = file_name
	_captured_images[file_name] = image
	_capture_order.append(file_name)
	_capture_records.append({
		"file": file_name,
		"published_path": OUTPUT_DIR.path_join(file_name),
		"sha256": digest,
		"png_bytes": byte_count,
		"png_type": "PNG 8-bit RGB non-interlaced",
		"resolution": [actual_size.x, actual_size.y],
		"luminance_range": snappedf(luminance_range, 0.000001),
		"luminance_variance": snappedf(luminance_variance, 0.000001),
		"game_phase": int(_game.get("phase")) if _game != null else -1,
		"active_camera": _active_camera_record(),
		"production_hud_semantically_required": HUD_SEMANTIC_CAPTURES.has(file_name),
		"production_hud_visible": _hud != null and bool(_hud.get("visible")),
		"staging_intervention_ids": _staging_ids_for_frame(file_name),
	})
	print(
		"CAPTURED_STAGED: %s  %dx%d  %d bytes  sha256=%s"
		% [
			ProjectSettings.globalize_path(path),
			image.get_width(), image.get_height(), byte_count, digest,
		]
	)


func _sample_luminance_statistics(image: Image) -> Dictionary:
	var darkest := 1.0
	var brightest := 0.0
	var luminance_sum := 0.0
	var luminance_squared_sum := 0.0
	var sample_count := 0
	for sample_y in 36:
		var y := mini(image.get_height() - 1, roundi(float(sample_y) / 35.0 * float(image.get_height() - 1)))
		for sample_x in 64:
			var x := mini(image.get_width() - 1, roundi(float(sample_x) / 63.0 * float(image.get_width() - 1)))
			var luminance := image.get_pixel(x, y).get_luminance()
			darkest = minf(darkest, luminance)
			brightest = maxf(brightest, luminance)
			luminance_sum += luminance
			luminance_squared_sum += luminance * luminance
			sample_count += 1
	var mean := luminance_sum / maxf(float(sample_count), 1.0)
	return {
		"range": brightest - darkest,
		"variance": maxf(
			0.0,
			luminance_squared_sum / maxf(float(sample_count), 1.0) - mean * mean
		),
	}


func _validate_capture_set() -> void:
	_check(_capture_order == CAPTURE_FILES, "capture order exactly matches the 27-state inventory")
	_check(_captured_images.size() == CAPTURE_FILES.size(), "capture memory set contains exactly 27 frames")
	_check(_capture_records.size() == CAPTURE_FILES.size(), "evidence record set contains exactly 27 frames")
	_check(_capture_hashes.size() == CAPTURE_FILES.size(), "all 27 full-file SHA-256 digests are unique")
	for file_name in CAPTURE_FILES:
		if not _captured_images.has(file_name):
			_fail("required capture was not produced: " + file_name)
		elif not FileAccess.file_exists(STAGING_DIR.path_join(file_name)):
			_fail("required staged capture is missing on disk: " + file_name)

	var closest_pair := ""
	var closest_mean := INF
	var closest_changed_fraction := 1.0
	for first_index in _capture_order.size():
		for second_index in range(first_index + 1, _capture_order.size()):
			var first_name := _capture_order[first_index]
			var second_name := _capture_order[second_index]
			var comparison := _compare_images(
				_captured_images[first_name] as Image,
				_captured_images[second_name] as Image
			)
			var mean_difference := float(comparison.get("mean_difference", 0.0))
			var changed_fraction := float(comparison.get("changed_fraction", 0.0))
			if mean_difference < closest_mean:
				closest_mean = mean_difference
				closest_changed_fraction = changed_fraction
				closest_pair = "%s / %s" % [first_name, second_name]
			if (
				mean_difference < NEAR_DUPLICATE_MEAN_DIFFERENCE
				and changed_fraction < NEAR_DUPLICATE_CHANGED_FRACTION
			):
				_fail(
					"near-duplicate captures %s and %s (mean %.5f, changed %.3f)"
					% [first_name, second_name, mean_difference, changed_fraction]
				)
	print(
		"CAPTURE_VARIATION: closest=%s mean=%.5f changed=%.3f"
		% [closest_pair, closest_mean, closest_changed_fraction]
	)
	_variation_metrics = {
		"closest_pair": closest_pair,
		"mean_difference": snappedf(closest_mean, 0.000001),
		"changed_fraction": snappedf(closest_changed_fraction, 0.000001),
		"near_duplicate_mean_threshold": NEAR_DUPLICATE_MEAN_DIFFERENCE,
		"near_duplicate_changed_fraction_threshold": NEAR_DUPLICATE_CHANGED_FRACTION,
	}


func _compare_images(first: Image, second: Image) -> Dictionary:
	var total_difference := 0.0
	var changed_pixels := 0
	var sample_count := 0
	for sample_y in 27:
		var normalized_y := float(sample_y) / 26.0
		var first_y := mini(first.get_height() - 1, roundi(normalized_y * float(first.get_height() - 1)))
		var second_y := mini(second.get_height() - 1, roundi(normalized_y * float(second.get_height() - 1)))
		for sample_x in 48:
			var normalized_x := float(sample_x) / 47.0
			var first_x := mini(first.get_width() - 1, roundi(normalized_x * float(first.get_width() - 1)))
			var second_x := mini(second.get_width() - 1, roundi(normalized_x * float(second.get_width() - 1)))
			var first_color := first.get_pixel(first_x, first_y)
			var second_color := second.get_pixel(second_x, second_y)
			var difference := (
				absf(first_color.r - second_color.r)
				+ absf(first_color.g - second_color.g)
				+ absf(first_color.b - second_color.b)
			) / 3.0
			total_difference += difference
			if difference >= PIXEL_CHANGE_THRESHOLD:
				changed_pixels += 1
			sample_count += 1
	return {
		"mean_difference": total_difference / maxf(float(sample_count), 1.0),
		"changed_fraction": float(changed_pixels) / maxf(float(sample_count), 1.0),
	}


func _inspect_png(path: String) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {"valid": false, "reason": "file_open_failed"}
	var header := file.get_buffer(29)
	file.close()
	if header.size() != 29:
		return {"valid": false, "reason": "short_header"}
	var signature_valid := true
	for byte_index in PNG_SIGNATURE_BYTES.size():
		if int(header[byte_index]) != PNG_SIGNATURE_BYTES[byte_index]:
			signature_valid = false
			break
	var ihdr_valid := (
		_read_big_endian_u32(header, 8) == 13
		and int(header[12]) == 73
		and int(header[13]) == 72
		and int(header[14]) == 68
		and int(header[15]) == 82
	)
	var width := _read_big_endian_u32(header, 16)
	var height := _read_big_endian_u32(header, 20)
	var bit_depth := int(header[24])
	var color_type := int(header[25])
	var compression_method := int(header[26])
	var filter_method := int(header[27])
	var interlace_method := int(header[28])
	var decoded := Image.new()
	var decode_error := decoded.load(ProjectSettings.globalize_path(path))
	var decoded_rgb8 := decode_error == OK and decoded.get_format() == Image.FORMAT_RGB8
	var dimensions_match_decode := (
		decode_error == OK
		and decoded.get_width() == width
		and decoded.get_height() == height
	)
	return {
		"valid": (
			signature_valid
			and ihdr_valid
			and bit_depth == 8
			and color_type == 2
			and compression_method == 0
			and filter_method == 0
			and interlace_method == 0
			and decoded_rgb8
			and dimensions_match_decode
		),
		"signature_valid": signature_valid,
		"ihdr_valid": ihdr_valid,
		"width": width,
		"height": height,
		"bit_depth": bit_depth,
		"color_type": color_type,
		"compression_method": compression_method,
		"filter_method": filter_method,
		"interlace_method": interlace_method,
		"decode_error": decode_error,
		"decoded_format": int(decoded.get_format()) if decode_error == OK else -1,
	}


func _read_big_endian_u32(bytes: PackedByteArray, offset: int) -> int:
	return (
		(int(bytes[offset]) << 24)
		| (int(bytes[offset + 1]) << 16)
		| (int(bytes[offset + 2]) << 8)
		| int(bytes[offset + 3])
	)


func _active_camera_record() -> Dictionary:
	var active_camera := root.get_camera_3d()
	if active_camera == null:
		return {"present": false}
	return {
		"present": true,
		"name": String(active_camera.name),
		"path": String(active_camera.get_path()),
		"production_camera": active_camera != _evidence_camera,
		"transform": _transform_record(active_camera.global_transform),
		"fov": snappedf(active_camera.fov, 0.0001),
		"near": snappedf(active_camera.near, 0.0001),
		"far": snappedf(active_camera.far, 0.0001),
	}


func _transform_record(value: Transform3D) -> Dictionary:
	return {
		"basis_x": _vector3_record(value.basis.x),
		"basis_y": _vector3_record(value.basis.y),
		"basis_z": _vector3_record(value.basis.z),
		"origin": _vector3_record(value.origin),
	}


func _vector3_record(value: Vector3) -> Array[float]:
	return [
		snappedf(value.x, 0.0001),
		snappedf(value.y, 0.0001),
		snappedf(value.z, 0.0001),
	]


func _staging_ids_for_frame(file_name: String) -> Array[String]:
	var result: Array[String] = []
	for intervention in STAGING_INTERVENTIONS:
		var frames := intervention.get("frames", []) as Array
		if frames.has(file_name):
			result.append(str(intervention.get("id", "")))
	return result


func _snapshot_source_files() -> Dictionary:
	var snapshot := {}
	for path in _source_paths:
		var digest := FileAccess.get_sha256(path) if FileAccess.file_exists(path) else ""
		if digest.is_empty():
			_fail("source freeze path is missing or cannot be hashed: %s" % path)
		else:
			snapshot[path] = digest
	return snapshot


func _collect_source_paths() -> PackedStringArray:
	var collected := PackedStringArray()
	for root_path in SOURCE_ROOTS:
		if FileAccess.file_exists(root_path):
			collected.append(root_path)
			continue
		if not DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(root_path)):
			_fail("source freeze root is missing: %s" % root_path)
			continue
		_collect_source_directory(root_path, collected)
	collected.sort()
	var deduplicated := PackedStringArray()
	for path in collected:
		if not deduplicated.has(path):
			deduplicated.append(path)
	return deduplicated


func _collect_source_directory(directory_path: String, output: PackedStringArray) -> void:
	var directory := DirAccess.open(directory_path)
	if directory == null:
		_fail("source freeze directory cannot be opened: %s" % directory_path)
		return
	directory.list_dir_begin()
	var entry := directory.get_next()
	while not entry.is_empty():
		if entry != "." and entry != ".." and entry != "__pycache__":
			var path := directory_path.path_join(entry)
			if directory.current_is_dir():
				_collect_source_directory(path, output)
			elif (
				not entry.ends_with("~")
				and not entry.ends_with(".pyc")
				and entry != ".DS_Store"
			):
				output.append(path)
		entry = directory.get_next()
	directory.list_dir_end()


func _source_snapshot_hash(snapshot: Dictionary) -> String:
	var context := HashingContext.new()
	if context.start(HashingContext.HASH_SHA256) != OK:
		return ""
	for path in _source_paths:
		context.update(("%s  %s\n" % [snapshot.get(path, ""), path]).to_utf8_buffer())
	return context.finish().hex_encode()


func _validate_source_frozen() -> void:
	var final_snapshot := _snapshot_source_files()
	var final_aggregate := _source_snapshot_hash(final_snapshot)
	_source_frozen_validated = (
		final_snapshot == _source_snapshot
		and final_aggregate == _source_aggregate_sha256
	)
	_check(
		_source_frozen_validated,
		"project/default bus/harness/scripts/scenes/assets/art_source/tools remain byte-identical through capture"
	)


func _source_file_records() -> Array[Dictionary]:
	var records: Array[Dictionary] = []
	for path in _source_paths:
		records.append({"path": path, "sha256": str(_source_snapshot.get(path, ""))})
	return records


func _write_source_manifest(path: String) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	_check(file != null, "staged source SHA-256 manifest opens for writing")
	if file == null:
		return
	for source_path in _source_paths:
		file.store_line("%s  %s" % [_source_snapshot.get(source_path, ""), source_path])
	file.close()
	_check(FileAccess.file_exists(path), "staged source SHA-256 manifest is present")


func _write_evidence_manifest(path: String) -> void:
	var staged_source_manifest := STAGING_DIR.path_join(SOURCE_MANIFEST_PATH.get_file())
	var manifest := {
		"schema": "phase2_gameplay_rendered_evidence_v1",
		"frame_count": CAPTURE_FILES.size(),
		"frame_inventory": CAPTURE_FILES,
		"capture_resolution": [CAPTURE_RESOLUTION.x, CAPTURE_RESOLUTION.y],
		"png_contract": "PNG 8-bit RGB non-interlaced; exact 2560x1440",
		"renderer": String(RenderingServer.get_current_rendering_method()),
		"adapter": RenderingServer.get_video_adapter_name(),
		"display": DisplayServer.get_name(),
		"native_window_size": [
			DisplayServer.window_get_size().x,
			DisplayServer.window_get_size().y,
		],
		"production_main_scene": MAIN_SCENE_PATH,
		"production_hud": {
			"scene": HUD_SCENE_PATH,
			"script": HUD_SCRIPT_PATH,
			"instance_id_unchanged": (
				_hud != null
				and _hud.get_instance_id() == int(_hud_identity.get("instance_id", 0))
			),
			"canvas_never_replaced_or_hidden_by_harness": true,
			"semantically_required_frames": HUD_SEMANTIC_CAPTURES,
		},
		"source_manifest": SOURCE_MANIFEST_PATH,
		"source_manifest_sha256": FileAccess.get_sha256(staged_source_manifest),
		"source_aggregate_sha256": _source_aggregate_sha256,
		"source_file_count": _source_paths.size(),
		"source_files": _source_file_records(),
		"source_unchanged_during_capture": _source_frozen_validated,
		"frames": _capture_records,
		"full_file_sha256_unique_count": _capture_hashes.size(),
		"variation_metrics": _variation_metrics,
		"staging_interventions": STAGING_INTERVENTIONS,
		"controller_only_physical_loop_evidence": false,
		"uninterrupted_playthrough": false,
		"capture_log_path": CAPTURE_LOG_PATH,
		"capture_log_policy": "External launcher must redirect/tee raw stdout and stderr to this path; the harness does not synthesize a process log.",
		"evidence_limits": [
			"The 27 images are deterministic staged production-state evidence, not an uninterrupted human playthrough.",
			"Direct handlers, teleports, body transforms, a frozen opponent, and an evidence camera are enumerated above and do not prove the omitted input-controlled travel or combat segments.",
			"Production HUD presence proves the live CanvasLayer was retained; it does not make capture-camera establishing shots equivalent to a player camera view.",
			"Native X11 Forward+ output does not prove native-Windows rendering, representative native-GPU performance, controller ergonomics, flight feel, audibility, or camera comfort.",
			"Exact PNG, luminance, variance, and uniqueness checks reject corrupt, blank, low-resolution, and duplicate files but do not replace original-resolution human visual review.",
		],
	}
	var file := FileAccess.open(path, FileAccess.WRITE)
	_check(file != null, "staged gameplay evidence manifest opens for writing")
	if file == null:
		return
	file.store_string(JSON.stringify(manifest, "  ", false) + "\n")
	file.close()
	_check(FileAccess.file_exists(path), "staged gameplay evidence manifest is present")


func _publish_evidence_set() -> void:
	var output_absolute := ProjectSettings.globalize_path(OUTPUT_DIR)
	var directory_error := DirAccess.make_dir_recursive_absolute(output_absolute)
	_check(
		directory_error == OK or directory_error == ERR_ALREADY_EXISTS,
		"published gameplay evidence directory is available"
	)
	if directory_error != OK and directory_error != ERR_ALREADY_EXISTS:
		return

	# Remove only the two old claim files before publishing any new PNG. If a
	# later copy fails, no stale manifest can authenticate a mixed image set.
	for manifest_path in [SOURCE_MANIFEST_PATH, EVIDENCE_MANIFEST_PATH]:
		if FileAccess.file_exists(manifest_path):
			var remove_error := DirAccess.remove_absolute(
				ProjectSettings.globalize_path(manifest_path)
			)
			_check(remove_error == OK, "stale published claim clears: %s" % manifest_path)
	if not _capture_failures.is_empty():
		return

	for file_name in CAPTURE_FILES:
		var source_path := STAGING_DIR.path_join(file_name)
		var destination_path := OUTPUT_DIR.path_join(file_name)
		if not _replace_exact_file(source_path, destination_path):
			return
		var record := _capture_record_for(file_name)
		var report := _inspect_png(destination_path)
		_check(bool(report.get("valid", false)), "published %s retains its exact PNG type" % file_name)
		_check(
			int(report.get("width", 0)) == CAPTURE_RESOLUTION.x
			and int(report.get("height", 0)) == CAPTURE_RESOLUTION.y,
			"published %s remains exactly 2560x1440" % file_name
		)
		_check(
			FileAccess.get_sha256(destination_path) == str(record.get("sha256", "")),
			"published %s is byte-identical to its validated staged frame" % file_name
		)
		if not _capture_failures.is_empty():
			return

	# Recheck after PNG publication and publish manifests last. This preserves an
	# explicit no-manifest failure state if production sources drift during I/O.
	_validate_source_frozen()
	if not _source_frozen_validated or not _capture_failures.is_empty():
		return
	if not _replace_exact_file(
		STAGING_DIR.path_join(SOURCE_MANIFEST_PATH.get_file()),
		SOURCE_MANIFEST_PATH
	):
		return
	if not _replace_exact_file(
		STAGING_DIR.path_join(EVIDENCE_MANIFEST_PATH.get_file()),
		EVIDENCE_MANIFEST_PATH
	):
		return
	_check(
		FileAccess.get_sha256(SOURCE_MANIFEST_PATH)
		== FileAccess.get_sha256(STAGING_DIR.path_join(SOURCE_MANIFEST_PATH.get_file())),
		"published source manifest is byte-identical to its staged file"
	)
	_check(
		FileAccess.get_sha256(EVIDENCE_MANIFEST_PATH)
		== FileAccess.get_sha256(STAGING_DIR.path_join(EVIDENCE_MANIFEST_PATH.get_file())),
		"published evidence manifest is byte-identical to its staged file"
	)
	print(
		"CAPTURE_SCENES_SOURCE_MANIFEST: aggregate=%s path=%s"
		% [_source_aggregate_sha256, ProjectSettings.globalize_path(SOURCE_MANIFEST_PATH)]
	)
	print(
		"CAPTURE_SCENES_EVIDENCE_MANIFEST: %s"
		% ProjectSettings.globalize_path(EVIDENCE_MANIFEST_PATH)
	)
	print(
		"CAPTURE_SCENES_LOG_TARGET: %s (external stdout/stderr tee)"
		% ProjectSettings.globalize_path(CAPTURE_LOG_PATH)
	)


func _replace_exact_file(source_path: String, destination_path: String) -> bool:
	if not FileAccess.file_exists(source_path):
		_fail("publish source is missing: %s" % source_path)
		return false
	if FileAccess.file_exists(destination_path):
		var remove_error := DirAccess.remove_absolute(
			ProjectSettings.globalize_path(destination_path)
		)
		if remove_error != OK:
			_fail("published destination could not be replaced: %s" % destination_path)
			return false
	var copy_error := DirAccess.copy_absolute(
		ProjectSettings.globalize_path(source_path),
		ProjectSettings.globalize_path(destination_path)
	)
	if copy_error != OK:
		_fail("staged evidence could not publish to %s: %s" % [destination_path, error_string(copy_error)])
		return false
	return true


func _capture_record_for(file_name: String) -> Dictionary:
	for record in _capture_records:
		if str(record.get("file", "")) == file_name:
			return record
	return {}


func _check(condition: bool, description: String) -> void:
	if condition:
		print("CAPTURE_PASS: ", description)
	else:
		_fail(description)


func _fail(description: String) -> void:
	_capture_failures.append(description)
	push_error("CAPTURE_FAIL: " + description)


func _release_actions() -> void:
	for action in ["interact", "move_forward", "fire", "sprint_boost", "brake"]:
		Input.action_release(action)


func _dispose(game: Node) -> void:
	_release_actions()
	if is_instance_valid(game):
		game.queue_free()
	await process_frame
	await process_frame
	await process_frame


func _finish() -> void:
	if _capture_failures.is_empty():
		print(
			"CAPTURE_SCENES_OK: %d source-frozen native X11 Forward+ production states at %dx%d"
			% [_capture_order.size(), CAPTURE_RESOLUTION.x, CAPTURE_RESOLUTION.y]
		)
		quit(0)
	else:
		push_error("CAPTURE_SCENES_FAILED: " + "; ".join(_capture_failures))
		quit(1)
