extends SceneTree

## Renders the station's rings and collars with and without the tessellation
## budget, so a triangle saving can be checked against the only thing that
## actually matters about a ring: whether it still reads as a circle.
##
## This runner is deliberately not a `_test.gd` suite. It produces pictures for
## a human (or an agent with eyes) to look at; it asserts nothing about them,
## because "still looks round" is not a number.
##
## Both passes come out of **one** build of the world, using
## `TorusGeometryBudget.restore_authored`, so the before and after shots share a
## scene, a light rig and a camera transform to the float. The only difference
## between a matched pair is `rings` and `ring_segments`.
##
## Every shot is written twice: the full 1920x1080 frame, and a 4x magnification
## of the ring's silhouette, which is where major-sweep faceting actually shows.
##
## Usage (needs a display; xvfb is fine, --headless is not — headless has no
## rasteriser and writes blank frames):
##   xvfb-run -a -s '-screen 0 1920x1080x24' godot --path . \
##     --resolution 1920x1080 --rendering-method forward_plus \
##     --audio-driver Dummy --script res://tests/capture_torus_smoothness.gd
##
## Optional environment variables:
##   KETH_TORUS_CAPTURE_DIR=res://path    output directory (default below).
##   KETH_TORUS_CAPTURE_ONLY=key,key      restrict to named subjects.
##   KETH_TORUS_CAPTURE_SWEEP=48x16,24x12 photograph the selected subjects at
##                                        these explicit `rings`x`ring_segments`
##                                        instead of the authored/budgeted pair.
##                                        This is how a floor gets chosen by
##                                        looking rather than by arithmetic.
##   KETH_TORUS_CAPTURE_VIEW=whole|near   restrict each pass to one matched
##                                        camera framing (default: both).

const MAIN_SCENE := preload("res://scenes/main.tscn")
const LOCATION := preload("res://assets/world/locations/cinder_reach.tres")

const DEFAULT_OUTPUT_DIR := "res://artifacts/torus_smoothness"
const CAPTURE_RESOLUTION := Vector2i(1920, 1080)
const CAMERA_FOV := 70.0

## Magnified crop: a 480x270 window blown up 4x to the full frame size.
const CROP_SIZE := Vector2i(480, 270)
const CROP_ZOOM := 4

## Distance for the "whole" shot as a multiple of the ring's major radius. 1.6 is
## about the closest a 70 degree camera can stand and still hold the entire ring
## in frame, which is the worst case for major-sweep faceting: the ring is as
## large on screen as it can be while still reading as a circle.
const WHOLE_FRAMING_RATIO := 1.6

## Distance in metres from the tube's surface for the "near" shot. This is the
## walk-up case the budget's `NEAR_EYE_METRES` claims to protect, photographed
## rather than asserted.
const NEAR_SURFACE_METRES := 0.6

## Every subject is a live ring in the production scene, chosen to cover the
## range the budget has to span and, specifically, every place it takes its
## largest reductions.
const SUBJECTS: Array = [
	{
		"key": "beacon_signal_ring",
		"node": "CinderStreamingBootstrap/WorldStreamingCoordinator/WorldLocation_CinderReach/RouteBeacons/RouteBeaconAlpha/SignalRing",
		"note": "THE NAMED RISK: Cinder Reach beacon signal ring, read as a circle",
	},
	{
		"key": "beacon_trim_ring",
		"node": "CinderStreamingBootstrap/WorldStreamingCoordinator/WorldLocation_CinderReach/RouteBeacons/RouteBeaconAlpha/TrimRing",
		"note": "the larger ring of the same beacon",
	},
	{
		"key": "pad_outer_ring",
		"node": "ShipyardWorld/LandingPad/OuterPadRing",
		"note": "9 m ring the player walks across: largest cut on a walk-up ring",
	},
	{
		"key": "pad_inner_ring",
		"node": "ShipyardWorld/LandingPad/InnerPadRing",
		"note": "inner landing pad ring, also walked past",
	},
	{
		"key": "arrow_berth_ring",
		"node": "ShipyardWorld/LandingPad/ArrowReconBerthOuterRing",
		"note": "berth ring",
	},
	{
		"key": "freight_dock_ring",
		"node": "ShipyardWorld/JovianFreightBerth/LoadingApron/OuterDockRing",
		"note": "the largest berth ring in the station",
	},
	{
		"key": "freight_lashing_ring",
		"node": "ShipyardWorld/JovianFreightBerth/HandlingZones/LashingRingPort01",
		"note": "explicitly tagged recessed deck fitting; 32-edge sweep remains exact",
	},
	{
		"key": "range_beacon_ring",
		"node": "ShipyardWorld/ExteriorTargetRange/BeaconRing",
		"note": "range beacon ring, flown through",
	},
	{
		"key": "drone_outer_ring",
		"node": "ShipyardWorld/ExteriorTargetRange/TargetDrone01/DroneVisual/OuterRing",
		"note": "target drone ring, seen in flight and up close",
	},
	{
		"key": "dock_mast_collar",
		"node": "ShipyardWorld/ExposedDockLattice/DockMastCollar",
		"note": "the half-metre mast collar the budget was written for",
	},
	{
		"key": "deck_tiedown_socket",
		"node": "ShipyardWorld/LandingPad/IntegratedDeckServices/TieDownSocket",
		"note": "deck fitting the player walks over: hardest cut on a floor object",
	},
	{
		"key": "chair_bearing",
		"node": "ShipyardWorld/HabitatSpine/Structure/ObservationCommon/CommonChair01/Bearing",
		"note": "interior furniture bearing, walk-up range",
	},
	{
		"key": "exterior_pipe_clamp",
		"node": "ShipyardWorld/AftJunctionStack/Structure/OperationsRoom/VisualPressureEnvelope/ExteriorPipeClamp",
		"note": "bounded interface collar: 32-edge major sweep, cardinal 8-edge tube section",
	},
	{
		"key": "arrow_panel_band",
		"node": "ArrowReconShip/ArrowReconVisual/FuselagePanelBand",
		"note": "1.35 m band on a 2 cm tube: thinnest ring, tube segments halved",
	},
	{
		"key": "moonlet_outer_ring",
		"node": "CinderStreamingBootstrap/WorldStreamingCoordinator/WorldLocation_CinderReach/Landmarks/MoonletRings/OuterRing",
		"note": "148 m landmark ring, the largest circle in the game",
	},
]

var _failures: Array[String] = []
var _output_dir := DEFAULT_OUTPUT_DIR


func _initialize() -> void:
	_run()


func _run() -> void:
	var configured := OS.get_environment("KETH_TORUS_CAPTURE_DIR")
	if configured != "":
		_output_dir = configured
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_output_dir))

	var only := OS.get_environment("KETH_TORUS_CAPTURE_ONLY").split(",", false)

	var window := root
	window.size = CAPTURE_RESOLUTION
	window.content_scale_size = CAPTURE_RESOLUTION

	var game := MAIN_SCENE.instantiate()
	root.add_child(game)
	for _frame in 16:
		await process_frame
	await physics_frame
	if not await _load_cinder_through_production_binding(game):
		_failures.append("production binding did not stream Cinder for its torus subjects")

	# The production main scene opens on its title layer. These are pictures of
	# geometry, so every CanvasLayer is switched off rather than dismissed.
	for candidate in game.find_children("*", "CanvasLayer", true, false):
		var layer := candidate as CanvasLayer
		layer.visible = false
		layer.process_mode = Node.PROCESS_MODE_DISABLED

	# Freeze the world. The station animates — the freight crane travels, the
	# warning lights pulse, the target drones drift on their station-keeping
	# path — and the two passes are taken seconds apart. Without this, a matched
	# pair differs because the scene moved, and the difference gets blamed on the
	# tessellation. Frozen, the only thing that changes between a pair is
	# `rings` and `ring_segments`.
	paused = true

	var camera := Camera3D.new()
	camera.name = "TorusSmoothnessCamera"
	camera.fov = CAMERA_FOV
	camera.near = 0.05
	camera.far = 6000.0
	camera.current = true
	root.add_child(camera)

	var subjects: Array = []
	for subject in SUBJECTS:
		if only.size() > 0 and not only.has(String(subject["key"])):
			continue
		var node := game.get_node_or_null(NodePath(String(subject["node"]))) as MeshInstance3D
		if node == null:
			_failures.append("missing torus: %s" % String(subject["node"]))
			continue
		var mesh := node.mesh as TorusMesh
		if mesh == null:
			_failures.append("not a TorusMesh: %s" % String(subject["node"]))
			continue
		subjects.append({"spec": subject, "node": node, "mesh": mesh})

	var passes: Array = ["budgeted", "authored"]
	var sweep := OS.get_environment("KETH_TORUS_CAPTURE_SWEEP").split(",", false)
	if sweep.size() > 0:
		passes = sweep

	# Pass order matters: the world has already budgeted itself by now, so the
	# authored pass is the one that has to be restored, and the budgeted pass is
	# re-applied afterwards from the same authored values.
	for pass_name in passes:
		if pass_name == "authored":
			TorusGeometryBudget.restore_authored(game)
		elif pass_name != "budgeted":
			var parts := String(pass_name).split("x")
			for entry in subjects:
				var swept: TorusMesh = entry["mesh"]
				swept.rings = int(parts[0])
				swept.ring_segments = int(parts[1])
		print("")
		print("--- %s ---" % pass_name)
		print("%-22s %6s %5s %8s  %s" % ["subject", "rings", "seg", "tris", "note"])
		for entry in subjects:
			var mesh: TorusMesh = entry["mesh"]
			var spec: Dictionary = entry["spec"]
			print("%-22s %6d %5d %8d  %s" % [
				String(spec["key"]), mesh.rings, mesh.ring_segments,
				mesh.rings * mesh.ring_segments * 2, String(spec["note"]),
			])
		for entry in subjects:
			await _shoot(camera, entry, pass_name)

	camera.queue_free()
	game.queue_free()
	await process_frame

	if _failures.is_empty():
		print("")
		print("torus smoothness captures written to %s" % _output_dir)
		quit(0)
		return
	for failure in _failures:
		printerr(failure)
	quit(1)


func _load_cinder_through_production_binding(game: Node) -> bool:
	var flow := game as GameFlow
	var bootstrap := game.get_node_or_null(
		^"CinderStreamingBootstrap"
	) as CinderStreamingBootstrap
	var ship := flow.get_guided_ship() if flow != null else null
	if flow == null or ship == null or bootstrap == null:
		return false
	# Player recall would race this helper at y=-70. Use the real piloted ship as
	# the binding's tracked actor in the authored clear approach lane, outside the
	# platform's collidable CoreDrum; the harness then pauses the complete scene.
	flow.active_ship = ship
	ship.set_piloted(true)
	ship.velocity = Vector3.ZERO
	ship.global_position = LOCATION.get_anchor_position() + Vector3(
		0.0,
		NearbySectorCluster.GANTRY_CENTER_Y,
		170.0
	)
	for _frame in 60:
		await physics_frame
		await process_frame
		if bootstrap.get_loaded_instance() != null:
			return true
	return false


## Two framings per ring.
##
## "whole" is the ring seen down its own axis at the closest distance that still
## contains it — the shot that decides whether the major sweep still reads as a
## circle. "near" puts the camera a walk-up distance from one point of the tube,
## looking along the ring, which is where cross-section faceting and the local
## straightness of a large ring show up.
func _shoot(camera: Camera3D, entry: Dictionary, pass_name: String) -> void:
	var node: MeshInstance3D = entry["node"]
	var mesh: TorusMesh = entry["mesh"]
	var key := String(entry["spec"]["key"])

	var world_scale := node.global_basis.get_scale().abs()
	var uniform_scale := maxf(maxf(world_scale.x, world_scale.y), world_scale.z)
	var major_radius := (mesh.outer_radius + mesh.inner_radius) * 0.5 * uniform_scale
	var tube_radius := (mesh.outer_radius - mesh.inner_radius) * 0.5 * uniform_scale

	var centre := node.global_position
	# `TorusMesh` sweeps in the node's local XZ plane, so local +Y is its axis.
	var axis := node.global_basis.y.normalized()
	var radial := node.global_basis.x.normalized()
	# A point on the ring itself: the focus for the magnified crop.
	var rim := centre + radial * major_radius

	var requested_view := OS.get_environment("KETH_TORUS_CAPTURE_VIEW")
	if requested_view.is_empty() or requested_view == "whole":
		var whole_distance := maxf(1.0, WHOLE_FRAMING_RATIO * major_radius)
		# Slightly off-axis rather than dead-on, so the ring reads as a ring against
		# whatever is behind it instead of as a flat annulus on the module it sits on.
		var whole_direction := (axis * 0.88 + radial * 0.47).normalized()
		_aim(camera, centre + whole_direction * whole_distance, centre)
		await _write(camera, "%s_whole_%s" % [key, pass_name], rim)

	# Walk-up: stand off the outer face of the tube, looking along the sweep so
	# the ring curves away across the frame.
	if requested_view.is_empty() or requested_view == "near":
		var near_direction := (axis * 0.45 + radial * 0.89).normalized()
		var near_eye := rim + near_direction * (tube_radius + NEAR_SURFACE_METRES)
		var tangent := axis.cross(radial).normalized()
		var look_at_point := rim + tangent * maxf(major_radius * 0.35, tube_radius * 3.0)
		_aim(camera, near_eye, look_at_point)
		await _write(camera, "%s_near_%s" % [key, pass_name], rim)


func _aim(camera: Camera3D, eye: Vector3, target: Vector3) -> void:
	camera.global_position = eye
	var up := Vector3.UP
	if absf((target - eye).normalized().dot(up)) > 0.99:
		up = Vector3.FORWARD
	camera.look_at(target, up)
	# The production scene owns player and cockpit cameras that claim the
	# viewport as the game flow advances; reclaim it for every shot.
	camera.make_current()


## Writes the full frame and a 4x magnification centred on `focus`.
func _write(camera: Camera3D, name: String, focus: Vector3) -> void:
	# The environment auto-exposes, and every shot follows a large camera jump.
	# Too few frames here and a matched pair differs in brightness rather than in
	# geometry, which is exactly the confusion this harness exists to avoid.
	for _frame in 24:
		await process_frame
	await RenderingServer.frame_post_draw
	var image := get_root().get_texture().get_image()
	var full_path := "%s/%s.png" % [_output_dir, name]
	if image.save_png(full_path) != OK:
		_failures.append("could not write %s" % full_path)
		return

	var screen := camera.unproject_position(focus)
	if camera.is_position_behind(focus):
		screen = Vector2(CAPTURE_RESOLUTION) * 0.5
	var origin := Vector2i(screen) - CROP_SIZE / 2
	origin.x = clampi(origin.x, 0, CAPTURE_RESOLUTION.x - CROP_SIZE.x)
	origin.y = clampi(origin.y, 0, CAPTURE_RESOLUTION.y - CROP_SIZE.y)
	var crop := image.get_region(Rect2i(origin, CROP_SIZE))
	# Nearest-neighbour: the question is where the geometry's edge is, and any
	# smoothing filter would answer it by inventing intermediate pixels.
	crop.resize(CROP_SIZE.x * CROP_ZOOM, CROP_SIZE.y * CROP_ZOOM, Image.INTERPOLATE_NEAREST)
	var crop_path := "%s/%s_crop.png" % [_output_dir, name]
	if crop.save_png(crop_path) != OK:
		_failures.append("could not write %s" % crop_path)
