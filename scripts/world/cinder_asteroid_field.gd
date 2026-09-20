class_name CinderAsteroidField
extends Node3D

## The nearby sector's first *navigable* rock: a belt with mass, standing off
## the outbound route on the starboard side, that the pilot flies through rather
## than past.
##
## The existing debris field is small fragments scattered around Cinder Reach and
## the eight presentation clusters flanking the beacon chain. Nothing in it has
## to be avoided; you fly through it and it decorates the window. This component
## is the opposite: thirty solid bodies at 22-50 m, spaced so the gaps between
## their colliders are a ship's width rather than a squadron's, on the layer the
## hull actually collides with.
##
## Three rules make a field of that mass safe to ship:
##
## 1. **It is a tube, not a ball.** A straight bore of `LANE_RADIUS` runs the
##    whole length of the belt, and no asteroid's *visual* reach enters it, not
##    merely no asteroid's collider. A player who does not want the threading run
##    can fly the bore at cruise with the field on both sides and touch nothing.
##    The bore mouths and waist are ringed in cyan chevrons so the opening is
##    readable from outside the belt, from the same palette the route beacons use
##    for "this way home".
## 2. **It stands entirely off every published lane.** Placement re-tests each
##    candidate against the route beacon chain, the frozen beacon-traversal
##    corridor, the platform keep-clear sphere and its approach lane, *and* the
##    two outbound legs the clearance suite sweeps that the cluster's own
##    predicate does not cover (launch gate to Alpha, and Delta back up to the
##    platform clearance point). The belt is far enough starboard that those
##    tests pass with room; they run anyway, because a later nudge to the anchor
##    must fail loudly rather than quietly block the route.
## 3. **Nothing here simulates.** Every asteroid carries one authored orientation
##    baked into its batch transform. The belt is thirty bodies and eight
##    renderers with no `_process`, no tween and no animation player, so the
##    streamed sector pays for it once at build.
##
## The component grants nothing and owns no activity state. It publishes the
## threading route's authored geometry so the activity definition and this
## geometry cannot drift, and it renders that route's presentation from a
## snapshot the activity authority hands it.

const SCHEMA_VERSION := 1
const COMPONENT_ID: StringName = &"cinder-asteroid-field"
const EVIDENCE_STATUS: StringName = &"modern_interpretation"
const CONTENT_CLASS: StringName = &"NEW"
const ACTIVITY_ID: StringName = &"cinder_asteroid_field_threading_run"
const REWARD_ID: StringName = &"return_asteroid_survey_to_shipyard"
const WORLD_LAYER := PhysicsLayers.WORLD
## The activity authority's own copy of this route. Held here so the audit can
## prove the shipped definition and the built geometry are the same five gates:
## a belt nudged sideways without regenerating the resource would otherwise send
## the pilot to five points inside the rock.
const THREADING_ROUTE := preload(
	"res://assets/activities/cinder_asteroid_field_threading_run.tres"
)

## Belt axis, in the same station-origin world frame the rest of the cluster is
## authored in. It runs starboard of and parallel to the outbound beacon chain,
## descending with it, so the belt is a landmark beside the route the whole way
## out rather than a detour bolted to one end of it.
const LANE_ENTRY := Vector3(246.0, -6.0, -274.0)
const LANE_EXIT := Vector3(298.0, -64.0, -558.0)
## Clear bore. 44 m is a little over three times the widest production hull, so
## the lane reads as an opening rather than a slot even at boost.
const LANE_RADIUS := 44.0
## Outer skin of the belt, measured perpendicular to the axis.
const OUTER_RADIUS := 140.0

const FIELD_SEED := 4471903
const ASTEROID_COUNT := 30
const MINIMUM_EXTENT := 22.0
const MAXIMUM_EXTENT := 50.0
## The collider is a sphere at this proportion of the sampled extent. Higher than
## the 0.40 the decorative boulders use: those exist to be flown past and are
## deliberately forgiving, these exist to be flown between and a collider that
## sits far inside its own silhouette teaches the pilot the wrong gap.
const COLLISION_PROPORTION := 0.44
## Furthest a lobe can reach from its asteroid's centre: the largest lobe half
## size (0.56) plus the largest lobe offset (0.22), with room for the authored
## rotation swinging a corner outward. Placement reserves this, not the collider,
## against the bore, so the safe lane is visually clear and not merely passable.
const VISUAL_REACH_PROPORTION := 0.92
## Centre-to-centre floor. With the extent range above, two worst-case
## neighbours still leave 22 m of daylight between their colliders and a typical
## pair leaves nearer 35 m.
const MINIMUM_SEPARATION := 72.0
const LOBES_PER_ASTEROID := 3
## Matches `NearbySectorCluster.ROCK_BEVEL_PROPORTION`, so a belt asteroid and a
## Cinder Reach boulder are cut from the same stone.
const BEVEL_PROPORTION := 0.13

## Shared silhouette stock. Six authored proportions, each drawn through one
## batch, with per-instance rotation and scale on top. The bevel is proportional
## to the mesh, so six stock recipes read as six genuinely different rocks where
## six scales of one recipe would read as one rock at six sizes.
const STOCK_SIZES: Array[Vector3] = [
	Vector3(1.00, 0.74, 0.92),
	Vector3(0.86, 0.62, 1.12),
	Vector3(1.14, 0.90, 0.70),
	Vector3(0.78, 0.96, 0.84),
	Vector3(1.06, 0.58, 1.04),
	Vector3(0.92, 0.82, 1.20),
]

## The threading run, authored as offsets from the bore: `t` along the axis, then
## `u` (starboard of the axis) and `v` (above it) in metres. Every gate sits
## outside the bore and inside the belt, so running the route means leaving the
## safe lane and crossing the rock four times. The gates alternate sides for
## exactly that reason: a route that stayed on one flank could be flown around
## the outside of the belt.
const THREADING_GATE_SPECS: Array[Dictionary] = [
	{"name": "ThreadingGate1", "t": 0.12, "u": 78.0, "v": 14.0},
	{"name": "ThreadingGate2", "t": 0.31, "u": -74.0, "v": 26.0},
	{"name": "ThreadingGate3", "t": 0.50, "u": 82.0, "v": -22.0},
	{"name": "ThreadingGate4", "t": 0.69, "u": -80.0, "v": -18.0},
	{"name": "ThreadingGate5", "t": 0.88, "u": 70.0, "v": 24.0},
]
## Arrival volume, matched by `assets/activities/cinder_asteroid_field_threading_run.tres`.
const CHECKPOINT_RADIUS := 30.0
## Clear pocket reserved around each gate. Larger than the arrival volume so the
## pilot can see the gate before being inside it and can pull out of it after.
const GATE_POCKET_RADIUS := 46.0

## Outbound legs the clearance suite sweeps that `NearbySectorCluster`'s own
## beacon-corridor predicate does not measure. Held here as published geometry so
## a placement regression names the leg it blocked.
const OUTBOUND_GUARD_SEGMENTS: Array[Dictionary] = [
	{"name": &"launch_gate_to_alpha", "start": Vector3(0.0, 8.0, -64.0), "finish": Vector3(16.0, -9.0, -240.0)},
	{"name": &"delta_to_platform_clearance", "start": Vector3(30.0, -46.0, -600.0), "finish": Vector3(60.0, -66.0, -530.0)},
]
const OUTBOUND_GUARD_RADIUS := 48.0

## Bore markers: six cyan chevrons on the rim at each mouth and at the waist.
const LANE_MARKER_RING_PARAMETERS: Array[float] = [0.0, 0.5, 1.0]
const LANE_MARKER_RING_COPIES := 6
const LANE_MARKER_SIZE := Vector3(9.0, 1.1, 1.1)
const LANE_MARKER_FAMILY_ID: StringName = &"cinder-asteroid-lane-chevrons"
## Gate markers: four chevrons boxing each threading gate.
const GATE_MARKER_COPIES := 4
const GATE_MARKER_SIZE := Vector3(7.0, 1.2, 1.2)
const GATE_MARKER_RADIUS := 17.0
const GATE_MARKER_FAMILY_ID: StringName = &"cinder-asteroid-threading-gates"
const ASTEROID_BATCH_FAMILY_ID: StringName = &"cinder-asteroid-belt-stock"

## Authored gate marker states. Presentation only: the batch, its renderer, its
## copy count and its submission count are identical in every state, so a
## threading run cannot change the streamed sector's roster mid-flight.
const GATE_CLEARED_SCALE := Vector3(0.52, 0.52, 0.52)
const GATE_PENDING_SCALE := Vector3(0.78, 0.78, 0.78)
const GATE_NEXT_SCALE := Vector3(1.34, 1.34, 1.34)
const GATE_COMPLETE_SCALE := Vector3(1.16, 1.16, 1.16)
const GATE_FAILED_SCALE := Vector3(1.42, 0.34, 0.34)
const GATE_NEXT_RADIUS := 22.0
const GATE_FAILED_RADIUS := 12.0
const PRESENTATION_NODE_DELTA := 0
const PRESENTATION_LIGHT_DELTA := 0
const PRESENTATION_SUBMISSION_DELTA := 0

const ROCK_TINTS: Array[Color] = [
	Color("4a5057"), Color("634a38"), Color("6a737a"),
]

var _built := false
var _asteroids: Array[Dictionary] = []
var _stock_batches: Array[MultiMeshInstance3D] = []
var _lane_markers: MultiMeshInstance3D
var _gate_markers: MultiMeshInstance3D
var _rock_material: StandardMaterial3D
var _presentation_snapshot: Dictionary = {}
var _bodies_root: Node3D
var _visuals_root: Node3D


## Builds the belt. `materials` is the cluster's own material dictionary so the
## bore and gate chevrons use the sector's published glow roles; `rock_mesh_cache`
## is the cluster's rock mesh cache, so a stock recipe already cut for a Cinder
## Reach boulder is reused rather than duplicated.
func build(materials: Dictionary, rock_mesh_cache: Dictionary) -> void:
	if _built:
		return
	_built = true

	_bodies_root = Node3D.new()
	_bodies_root.name = "Asteroids"
	add_child(_bodies_root)
	_visuals_root = Node3D.new()
	_visuals_root.name = "BeltVisuals"
	add_child(_visuals_root)

	# One neutral vertex-colour material for the whole belt. Three rock tints
	# arrive per instance, so six shared-stock batches cover eighteen
	# rock-and-shape combinations without eighteen renderers or eighteen
	# materials.
	_rock_material = StandardMaterial3D.new()
	_rock_material.albedo_color = Color.WHITE
	_rock_material.metallic = 0.03
	_rock_material.roughness = 0.93
	_rock_material.vertex_color_use_as_albedo = true

	_place_asteroids()
	_build_stock_batches(rock_mesh_cache)
	_build_lane_markers(materials)
	_build_gate_markers(materials)
	_presentation_snapshot = {}
	_apply_gate_marker_state({})


# --- Published geometry -------------------------------------------------------


func get_lane_entry() -> Vector3:
	return LANE_ENTRY


func get_lane_exit() -> Vector3:
	return LANE_EXIT


func get_lane_axis_direction() -> Vector3:
	return (LANE_EXIT - LANE_ENTRY).normalized()


func get_lane_length() -> float:
	return LANE_ENTRY.distance_to(LANE_EXIT)


## Point on the bore centreline at `parameter` in [0, 1].
func get_lane_point(parameter: float) -> Vector3:
	return LANE_ENTRY.lerp(LANE_EXIT, clampf(parameter, 0.0, 1.0))


## Perpendicular distance from the bore centreline, measured against the capped
## segment so a sample past either mouth is measured from that mouth.
func distance_to_lane_axis(world_position: Vector3) -> float:
	if not world_position.is_finite():
		return INF
	var segment := LANE_EXIT - LANE_ENTRY
	var along := clampf(
		(world_position - LANE_ENTRY).dot(segment) / segment.length_squared(), 0.0, 1.0
	)
	return world_position.distance_to(LANE_ENTRY + segment * along)


## Starboard-of-axis unit vector. Built from the axis rather than a stored basis
## so the published gates and the built geometry cannot disagree.
func get_lane_starboard_axis() -> Vector3:
	var forward := get_lane_axis_direction()
	var hint := Vector3.UP if absf(forward.dot(Vector3.UP)) < 0.98 else Vector3.RIGHT
	return forward.cross(hint).normalized()


func get_lane_up_axis() -> Vector3:
	return get_lane_starboard_axis().cross(get_lane_axis_direction()).normalized()


## The authored threading route, in order. This is the single source the
## activity definition is checked against.
func get_threading_checkpoints() -> PackedVector3Array:
	var points := PackedVector3Array()
	var starboard := get_lane_starboard_axis()
	var up := get_lane_up_axis()
	for spec in THREADING_GATE_SPECS:
		points.append(
			get_lane_point(float(spec["t"]))
			+ starboard * float(spec["u"])
			+ up * float(spec["v"])
		)
	return points


func get_asteroid_records() -> Array[Dictionary]:
	return _asteroids.duplicate(true)


func get_asteroid_count() -> int:
	return _asteroids.size()


## Furthest the belt reaches from the station origin, lobes included.
func get_outer_content_distance() -> float:
	var furthest := 0.0
	for record in _asteroids:
		furthest = maxf(
			furthest,
			(record["position"] as Vector3).length()
				+ float(record["extent"]) * VISUAL_REACH_PROPORTION,
		)
	return furthest


## What the pilot at `world_position` is currently inside. The struck index is
## the authored collider the sample is within, which is the same sphere the
## physics body carries; the activity authority uses it to end a run that hit
## rock, and the physics engine independently stops the hull.
func classify_position(world_position: Vector3) -> Dictionary:
	var lane_distance := distance_to_lane_axis(world_position)
	var struck_index := -1
	var nearest_surface := INF
	for index in _asteroids.size():
		var record := _asteroids[index]
		var surface := (
			world_position.distance_to(record["position"] as Vector3)
			- float(record["collision_radius"])
		)
		if surface < nearest_surface:
			nearest_surface = surface
		if surface <= 0.0 and struck_index < 0:
			struck_index = index
	return {
		"schema_version": SCHEMA_VERSION,
		"lane_distance": lane_distance,
		"inside_belt": lane_distance <= OUTER_RADIUS,
		"inside_safe_lane": lane_distance <= LANE_RADIUS,
		"struck_asteroid_index": struck_index,
		"struck": struck_index >= 0,
		"nearest_asteroid_surface_distance": nearest_surface,
		"gameplay_authority": false,
		"reward_authority": false,
	}


# --- Placement ----------------------------------------------------------------


## Whether a candidate centre with the supplied physical margin stands clear of
## the bore and of every published lane outside this component.
func is_placeable(world_position: Vector3, visual_reach: float, collision_radius: float) -> bool:
	var lane_distance := distance_to_lane_axis(world_position)
	# The bore is reserved against the *visual* reach: a lobe hanging into the
	# lane makes the opening unreadable even though the hull would pass.
	if lane_distance < LANE_RADIUS + visual_reach:
		return false
	if lane_distance > OUTER_RADIUS - collision_radius:
		return false
	for checkpoint in get_threading_checkpoints():
		if world_position.distance_to(checkpoint) < GATE_POCKET_RADIUS + collision_radius:
			return false
	for segment_spec in OUTBOUND_GUARD_SEGMENTS:
		if _distance_to_segment(
				world_position,
				segment_spec["start"] as Vector3,
				segment_spec["finish"] as Vector3,
			) < OUTBOUND_GUARD_RADIUS + collision_radius:
			return false
	return true


func _place_asteroids() -> void:
	var random := RandomNumberGenerator.new()
	random.seed = FIELD_SEED
	var attempts := 0
	while _asteroids.size() < ASTEROID_COUNT and attempts < ASTEROID_COUNT * 800:
		attempts += 1
		var extent := random.randf_range(MINIMUM_EXTENT, MAXIMUM_EXTENT)
		var candidate := _sample_belt_position(random)
		var visual_reach := extent * VISUAL_REACH_PROPORTION
		var collision_radius := extent * COLLISION_PROPORTION
		if not is_placeable(candidate, visual_reach, collision_radius):
			continue
		if not _is_clear_of_sector_content(candidate, collision_radius):
			continue
		var crowded := false
		for placed in _asteroids:
			if candidate.distance_to(placed["position"] as Vector3) < MINIMUM_SEPARATION:
				crowded = true
				break
		if crowded:
			continue
		_asteroids.append(_author_asteroid(random, candidate, extent))
	if _asteroids.size() < ASTEROID_COUNT:
		push_error(
			"CinderAsteroidField placed only %d of %d asteroids before exhausting attempts"
			% [_asteroids.size(), ASTEROID_COUNT]
		)


## Clearance against everything the rest of the sector publishes. Re-measured
## here rather than assumed from the anchor, so moving the belt cannot silently
## park it on a beacon or in the platform approach.
func _is_clear_of_sector_content(world_position: Vector3, collision_radius: float) -> bool:
	for spec in NearbySectorCluster.ROUTE_BEACON_SPECS:
		if world_position.distance_to(spec["position"] as Vector3) \
				< NearbySectorCluster.BEACON_KEEP_CLEAR_RADIUS + collision_radius:
			return false
	for index in NearbySectorCluster.ROUTE_BEACON_SPECS.size() - 1:
		if _distance_to_segment(
				world_position,
				NearbySectorCluster.ROUTE_BEACON_SPECS[index]["position"] as Vector3,
				NearbySectorCluster.ROUTE_BEACON_SPECS[index + 1]["position"] as Vector3,
			) < NearbySectorCluster.BEACON_TRAVERSAL_CORRIDOR_RADIUS + collision_radius:
			return false
	var platform_offset := world_position - NearbySectorCluster.PLATFORM_ANCHOR
	if platform_offset.length() \
			< NearbySectorCluster.PLATFORM_KEEP_CLEAR_RADIUS + collision_radius:
		return false
	var lane_point := NearbySectorCluster.PLATFORM_ANCHOR + Vector3(
		0.0,
		NearbySectorCluster.GANTRY_CENTER_Y,
		clampf(platform_offset.z, 0.0, NearbySectorCluster.APPROACH_CORRIDOR_LENGTH),
	)
	if world_position.distance_to(lane_point) \
			< NearbySectorCluster.APPROACH_CORRIDOR_RADIUS + collision_radius:
		return false
	if world_position.distance_to(NearbySectorCluster.MOONLET_ANCHOR) \
			< NearbySectorCluster.MOONLET_RADIUS + collision_radius:
		return false
	if world_position.z > NearbySectorCluster.TARGET_RANGE_CLEARANCE_Z:
		return false
	return true


## Uniform-by-volume sample of the belt tube: a length along the axis and a
## radius biased so area, not radius, is uniform across the annulus.
func _sample_belt_position(random: RandomNumberGenerator) -> Vector3:
	var along := random.randf()
	var angle := random.randf_range(-PI, PI)
	var radius := sqrt(
		lerpf(LANE_RADIUS * LANE_RADIUS, OUTER_RADIUS * OUTER_RADIUS, random.randf())
	)
	return (
		get_lane_point(along)
		+ get_lane_starboard_axis() * (radius * cos(angle))
		+ get_lane_up_axis() * (radius * sin(angle))
	)


func _author_asteroid(
		random: RandomNumberGenerator, world_position: Vector3, extent: float
	) -> Dictionary:
	var lobes: Array[Dictionary] = []
	for lobe_index in LOBES_PER_ASTEROID:
		lobes.append({
			"stock_index": random.randi_range(0, STOCK_SIZES.size() - 1),
			"offset": Vector3(
				random.randf_range(-0.22, 0.22),
				random.randf_range(-0.18, 0.18),
				random.randf_range(-0.22, 0.22),
			) * extent,
			# One authored orientation, baked once into the batch transform.
			# The belt never spins: thirty tumbling bodies would be thirty
			# per-frame transform writes for a silhouette the pilot reads in
			# two seconds at 82 m/s.
			"rotation": Vector3(
				random.randf_range(-PI, PI),
				random.randf_range(-PI, PI),
				random.randf_range(-PI, PI),
			),
			"scale": Vector3(
				extent * random.randf_range(0.50, 0.56),
				extent * random.randf_range(0.40, 0.50),
				extent * random.randf_range(0.50, 0.56),
			),
		})
	return {
		"index": _asteroids.size(),
		"name": "Asteroid%02d" % (_asteroids.size() + 1),
		"position": world_position,
		"extent": extent,
		"collision_radius": extent * COLLISION_PROPORTION,
		"visual_reach": extent * VISUAL_REACH_PROPORTION,
		"tint": ROCK_TINTS[_asteroids.size() % ROCK_TINTS.size()],
		"lobes": lobes,
	}


# --- Construction -------------------------------------------------------------


func _build_stock_batches(rock_mesh_cache: Dictionary) -> void:
	var grouped: Array[Array] = []
	for _stock_index in STOCK_SIZES.size():
		grouped.append([])
	for record in _asteroids:
		var body := StaticBody3D.new()
		body.name = String(record["name"])
		body.position = record["position"] as Vector3
		body.collision_layer = WORLD_LAYER
		body.collision_mask = 0
		body.set_meta(&"asteroid_extent", float(record["extent"]))
		body.set_meta(&"asteroid_collision_radius", float(record["collision_radius"]))
		_bodies_root.add_child(body)
		var shape := CollisionShape3D.new()
		shape.name = "Collision"
		var sphere := SphereShape3D.new()
		sphere.radius = float(record["collision_radius"])
		shape.shape = sphere
		body.add_child(shape)
		for lobe: Dictionary in record["lobes"]:
			var basis_value := Basis.from_euler(lobe["rotation"] as Vector3).scaled(
				lobe["scale"] as Vector3
			)
			(grouped[int(lobe["stock_index"])] as Array).append({
				"transform": Transform3D(
					basis_value,
					(record["position"] as Vector3) + (lobe["offset"] as Vector3),
				),
				"color": record["tint"] as Color,
			})

	for stock_index in STOCK_SIZES.size():
		var entries := grouped[stock_index] as Array
		var multimesh := MultiMesh.new()
		multimesh.transform_format = MultiMesh.TRANSFORM_3D
		multimesh.use_colors = true
		multimesh.mesh = _stock_mesh(stock_index, rock_mesh_cache)
		multimesh.instance_count = entries.size()
		# The authored transforms and colours are also published as metadata.
		# `MultiMesh.get_instance_transform` reads back identity under the dummy
		# rendering driver every headless check runs on, so a suite that read
		# the buffer would be measuring the driver rather than the belt.
		var authored_transforms: Array[Transform3D] = []
		var authored_colors := PackedColorArray()
		for entry_index in entries.size():
			var entry := entries[entry_index] as Dictionary
			var entry_transform := entry["transform"] as Transform3D
			var entry_color := entry["color"] as Color
			multimesh.set_instance_transform(entry_index, entry_transform)
			multimesh.set_instance_color(entry_index, entry_color)
			authored_transforms.append(entry_transform)
			authored_colors.append(entry_color)
		multimesh.visible_instance_count = entries.size()
		var batch := MultiMeshInstance3D.new()
		batch.name = "AsteroidStock%d" % (stock_index + 1)
		batch.multimesh = multimesh
		batch.material_override = _rock_material
		batch.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		batch.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
		batch.set_meta(&"visual_batch_family_id", ASTEROID_BATCH_FAMILY_ID)
		batch.set_meta(&"authored_stock_size", STOCK_SIZES[stock_index])
		batch.set_meta(&"authored_visible_copy_count", entries.size())
		batch.set_meta(&"authored_instance_transforms", authored_transforms)
		batch.set_meta(&"authored_instance_colors", authored_colors)
		_visuals_root.add_child(batch)
		_stock_batches.append(batch)


## Stock mesh, keyed and cached exactly the way `NearbySectorCluster._rock_mesh`
## keys its boulder recipes, so the two share one entry when they ask for the
## same size rather than cutting the same rock twice.
func _stock_mesh(stock_index: int, rock_mesh_cache: Dictionary) -> ArrayMesh:
	var size := STOCK_SIZES[stock_index]
	var key := "rock:%0.2f:%0.2f:%0.2f" % [size.x, size.y, size.z]
	if rock_mesh_cache.has(key):
		return rock_mesh_cache[key] as ArrayMesh
	var shortest := minf(size.x, minf(size.y, size.z))
	var mesh := StationSurfaceKit.rounded_box_mesh_with_bevel(
		size, shortest * BEVEL_PROPORTION
	)
	rock_mesh_cache[key] = mesh
	return mesh


func _build_lane_markers(materials: Dictionary) -> void:
	var transforms: Array[Transform3D] = []
	var starboard := get_lane_starboard_axis()
	var up := get_lane_up_axis()
	for parameter in LANE_MARKER_RING_PARAMETERS:
		var centre := get_lane_point(parameter)
		for copy_index in LANE_MARKER_RING_COPIES:
			var angle := TAU * float(copy_index) / float(LANE_MARKER_RING_COPIES)
			var radial := starboard * cos(angle) + up * sin(angle)
			transforms.append(Transform3D(
				Basis(radial, up.cross(radial).normalized(), get_lane_axis_direction()),
				centre + radial * LANE_RADIUS,
			))
	_lane_markers = _build_marker_batch(
		"SafeLaneChevrons",
		LANE_MARKER_SIZE,
		transforms,
		materials.get("cyan_glow") as Material,
		LANE_MARKER_FAMILY_ID,
	)


func _build_gate_markers(materials: Dictionary) -> void:
	_gate_markers = _build_marker_batch(
		"ThreadingGateChevrons",
		GATE_MARKER_SIZE,
		_gate_marker_transforms({}),
		materials.get("orange_glow") as Material,
		GATE_MARKER_FAMILY_ID,
	)


func _build_marker_batch(
		node_name: String,
		size: Vector3,
		transforms: Array[Transform3D],
		material: Material,
		family_id: StringName,
	) -> MultiMeshInstance3D:
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.mesh = StationSurfaceKit.rounded_box_mesh_with_bevel(
		size, minf(size.y, size.z) * BEVEL_PROPORTION
	)
	multimesh.instance_count = transforms.size()
	for index in transforms.size():
		multimesh.set_instance_transform(index, transforms[index])
	multimesh.visible_instance_count = transforms.size()
	var batch := MultiMeshInstance3D.new()
	batch.name = node_name
	batch.multimesh = multimesh
	batch.material_override = material
	batch.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	batch.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
	batch.set_meta(&"presentation_only", true)
	batch.set_meta(&"visual_batch_family_id", family_id)
	batch.set_meta(&"authored_visible_copy_count", transforms.size())
	batch.set_meta(&"authored_instance_transforms", transforms.duplicate())
	_visuals_root.add_child(batch)
	return batch


# --- Threading run presentation ----------------------------------------------


## Redraws the gate chevrons from an activity snapshot. Consumes the snapshot
## and owns nothing: no state here can start, advance, fail or reward a run.
func apply_threading_presentation(snapshot: Dictionary) -> Dictionary:
	_presentation_snapshot = snapshot.duplicate(true)
	_apply_gate_marker_state(_presentation_snapshot)
	return get_presentation_state()


func get_presentation_state() -> Dictionary:
	return {
		"schema_version": SCHEMA_VERSION,
		"activity_id": ACTIVITY_ID,
		"state_id": StringName(_presentation_snapshot.get("state_id", &"idle")),
		"next_checkpoint_index": int(_presentation_snapshot.get("next_checkpoint_index", 0)),
		"checkpoint_count": THREADING_GATE_SPECS.size(),
		"marker_copy_count": (
			_gate_markers.multimesh.visible_instance_count
			if is_instance_valid(_gate_markers) and _gate_markers.multimesh != null
			else 0
		),
		"gameplay_authority": false,
		"reward_authority": false,
	}


func _apply_gate_marker_state(snapshot: Dictionary) -> void:
	if not is_instance_valid(_gate_markers) or _gate_markers.multimesh == null:
		return
	var transforms := _gate_marker_transforms(snapshot)
	for index in transforms.size():
		_gate_markers.multimesh.set_instance_transform(index, transforms[index])
	_gate_markers.multimesh.visible_instance_count = transforms.size()
	_gate_markers.set_meta(&"authored_instance_transforms", transforms.duplicate())
	_gate_markers.set_meta(&"authored_visible_copy_count", transforms.size())


func _gate_marker_transforms(snapshot: Dictionary) -> Array[Transform3D]:
	var state_id := StringName(snapshot.get("state_id", &"idle"))
	var next_index := int(snapshot.get("next_checkpoint_index", -1))
	var starboard := get_lane_starboard_axis()
	var up := get_lane_up_axis()
	var forward := get_lane_axis_direction()
	var transforms: Array[Transform3D] = []
	var checkpoints := get_threading_checkpoints()
	for gate_index in checkpoints.size():
		var scale_value := GATE_PENDING_SCALE
		var radius := GATE_MARKER_RADIUS
		match state_id:
			&"active":
				if gate_index < next_index:
					scale_value = GATE_CLEARED_SCALE
				elif gate_index == next_index:
					scale_value = GATE_NEXT_SCALE
					radius = GATE_NEXT_RADIUS
			&"completed":
				scale_value = GATE_COMPLETE_SCALE
			&"failed":
				scale_value = GATE_FAILED_SCALE
				radius = GATE_FAILED_RADIUS
		for copy_index in GATE_MARKER_COPIES:
			var angle := TAU * float(copy_index) / float(GATE_MARKER_COPIES)
			var radial := starboard * cos(angle) + up * sin(angle)
			transforms.append(Transform3D(
				Basis(radial, up.cross(radial).normalized(), forward).scaled(scale_value),
				checkpoints[gate_index] + radial * radius,
			))
	return transforms


# --- Audit --------------------------------------------------------------------


func audit() -> Dictionary:
	var errors := PackedStringArray()
	if _asteroids.size() != ASTEROID_COUNT:
		errors.append(
			"placed %d asteroids, expected %d" % [_asteroids.size(), ASTEROID_COUNT]
		)
	for record in _asteroids:
		var position := record["position"] as Vector3
		if not is_placeable(
				position, float(record["visual_reach"]), float(record["collision_radius"])
			):
			errors.append("an asteroid stands inside the safe lane, a gate pocket or an outbound leg")
			break
	for record in _asteroids:
		if not _is_clear_of_sector_content(
				record["position"] as Vector3, float(record["collision_radius"])
			):
			errors.append("an asteroid crowds a published beacon, the platform or its approach")
			break
	var outer := get_outer_content_distance()
	if outer > NearbySectorCluster.MAXIMUM_CONTENT_DISTANCE:
		errors.append(
			"the belt reaches %.1f m, past the published content envelope" % outer
		)
	var anchor_distance := get_lane_point(0.5).length()
	if anchor_distance < NearbySectorCluster.MINIMUM_ANCHOR_DISTANCE \
			or anchor_distance > NearbySectorCluster.MAXIMUM_ANCHOR_DISTANCE:
		errors.append(
			"the belt anchor %.1f m is outside the published travel envelope" % anchor_distance
		)
	for checkpoint in get_threading_checkpoints():
		var lane_distance := distance_to_lane_axis(checkpoint)
		if lane_distance <= LANE_RADIUS or lane_distance >= OUTER_RADIUS:
			errors.append("a threading gate is outside the belt or inside the safe lane")
			break
	if not find_children("*", "Light3D", true, false).is_empty():
		errors.append("the belt owns a light")
	errors.append_array(_threading_route_errors())
	return {
		"schema_version": SCHEMA_VERSION,
		"component_id": COMPONENT_ID,
		"content_class": CONTENT_CLASS,
		"evidence_status": EVIDENCE_STATUS,
		"activity_id": ACTIVITY_ID,
		"reward_id": REWARD_ID,
		"asteroid_count": _asteroids.size(),
		"stock_batch_count": _stock_batches.size(),
		"lane_entry": LANE_ENTRY,
		"lane_exit": LANE_EXIT,
		"lane_radius": LANE_RADIUS,
		"outer_radius": OUTER_RADIUS,
		"outer_content_distance": outer,
		"threading_checkpoints": get_threading_checkpoints(),
		"checkpoint_radius": CHECKPOINT_RADIUS,
		"gameplay_authority": false,
		"grants_rewards": false,
		"errors": errors,
		"valid": errors.is_empty(),
	}


## Whether the shipped activity definition still describes this belt's gates.
func _threading_route_errors() -> PackedStringArray:
	var errors := PackedStringArray()
	if THREADING_ROUTE == null or not THREADING_ROUTE.is_definition_valid():
		errors.append("the threading run definition is missing or invalid")
		return errors
	if THREADING_ROUTE.activity_id != ACTIVITY_ID:
		errors.append("the threading run definition carries another activity id")
	if not is_equal_approx(THREADING_ROUTE.checkpoint_radius, CHECKPOINT_RADIUS):
		errors.append("the threading run definition uses another arrival radius")
	var authored := get_threading_checkpoints()
	if THREADING_ROUTE.checkpoint_positions.size() != authored.size():
		errors.append("the threading run definition has a different gate count")
		return errors
	for index in authored.size():
		if not THREADING_ROUTE.checkpoint_positions[index].is_equal_approx(authored[index]):
			errors.append("threading gate %d drifted from the shipped definition" % (index + 1))
			break
	return errors


func _distance_to_segment(point: Vector3, start: Vector3, finish: Vector3) -> float:
	var segment := finish - start
	if segment.length_squared() < 0.000001:
		return point.distance_to(start)
	var along := clampf((point - start).dot(segment) / segment.length_squared(), 0.0, 1.0)
	return point.distance_to(start + segment * along)
