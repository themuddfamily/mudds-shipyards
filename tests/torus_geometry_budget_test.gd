extends SceneTree

## Holds the station's rings and collars to the geometry budget they were
## measured into, and — more importantly — holds the budget to its floor.
##
## There are two failures worth guarding here and they pull in opposite
## directions. One is the cost regression: someone adds another collar at
## `rings = 64`, it costs two thousand triangles, nobody notices, and the scene
## is a sixth rings again. The other, and the one that actually matters, is the
## *quality* regression: someone decides the floor in `TorusGeometryBudget` is
## conservative and lowers it, and every small ring in the game quietly turns
## into a visible polygon. `MIN_RINGS` and `MIN_RING_SEGMENTS` were chosen by
## rendering a sweep and looking at it, not by arithmetic, so this suite asserts
## them as a floor that cannot be crossed by accident.

const WORLD_SCENE := preload("res://scenes/world/shipyard_world.tscn")

## Rings whose world-space outer radius reaches this are read *as circles* — the
## landing pad rings, the berth rings, the Cinder Reach beacon rings, the moonlet
## rings. They are the class the whole pass was warned about.
const LARGE_RING_RADIUS_METRES := 2.0

## ...and no ring in that class may fall below this. It is the tessellation
## `nearby_sector_cluster.gd` already uses on the biggest circles in the game,
## and `TorusGeometryBudget.TOLERANCE_RADIANS` is calibrated so the budget's own
## answer for a large ring lands exactly here.
const LARGE_RING_MINIMUM_RINGS := 40

## Ceiling on the world subtree's ring geometry.
##
## Before the budget the station's tori cost about 164,500 triangles; after, on
## the per-ring figures measured by `tools/torus_census.gd`, about 102,000. This
## ceiling sits between the two with headroom, so legitimate new collars do not
## trip it while a wholesale return to unbudgeted `TorusMesh` does immediately.
const WORLD_TORUS_TRIANGLE_CEILING := 150_000

## The census counted 108 tori in the world subtree. Held as a floor, not an
## equality: rings may legitimately be added, and this suite bounds their cost,
## not their number.
const MINIMUM_WORLD_TORUS_COUNT := 90

var _assertions := 0
var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_check_plan_contract()
	await _check_world_rings()
	_check_sweep_is_idempotent()
	_check_authored_values_round_trip()
	_finish()


## The rule itself, on synthetic radii, so a change to it is caught without
## depending on any particular object still existing in the world.
func _check_plan_contract() -> void:
	# A large ring keeps the tessellation the biggest circles in the game already
	# use. This is the calibration that makes the pass safe, and it is the first
	# thing to break if the tolerance is retuned.
	for radius in [2.0, 5.6, 9.0, 148.0]:
		var large := TorusGeometryBudget.plan(radius, radius * 0.95)
		_check(
			int(large["rings"]) >= LARGE_RING_MINIMUM_RINGS,
			"a %.1f m ring is planned at %d rings, at or above the %d used on the game's biggest circles" % [
				radius, int(large["rings"]), LARGE_RING_MINIMUM_RINGS,
			]
		)

	# A small collar drops, but never below the floor that was rendered and
	# judged clean. 18x9 is what the distance rule alone produced for the 10 cm
	# exterior pipe clamp, and it is visibly polygonal.
	var collar := TorusGeometryBudget.plan(0.10, 0.065)
	_check(
		int(collar["rings"]) >= TorusGeometryBudget.MIN_RINGS
		and int(collar["ring_segments"]) >= TorusGeometryBudget.MIN_RING_SEGMENTS,
		"a 10 cm collar is planned at %dx%d, at or above the rendered floor %dx%d" % [
			int(collar["rings"]), int(collar["ring_segments"]),
			TorusGeometryBudget.MIN_RINGS, TorusGeometryBudget.MIN_RING_SEGMENTS,
		]
	)
	_check(
		TorusGeometryBudget.MIN_RINGS >= 32 and TorusGeometryBudget.MIN_RING_SEGMENTS >= 12,
		"the tessellation floor is still the one that was rendered and looked at (32x12)"
	)

	# Degenerate input returns the floor rather than something enormous or zero.
	var degenerate := TorusGeometryBudget.plan(0.0, 0.0)
	_check(
		int(degenerate["rings"]) == TorusGeometryBudget.MIN_RINGS
		and int(degenerate["ring_segments"]) == TorusGeometryBudget.MIN_RING_SEGMENTS,
		"a degenerate torus falls back to the floor instead of dividing by zero"
	)


func _check_world_rings() -> void:
	var world := WORLD_SCENE.instantiate() as ShipyardWorld
	_check(world != null, "production shipyard world instantiates")
	if world == null:
		return
	root.add_child(world)
	await process_frame

	# The world does not budget itself — `game_flow.gd` sweeps the whole scene
	# once, because the tori are spread across the station and the ship scenes
	# that are siblings of it. So the sweep is applied here explicitly.
	var report := TorusGeometryBudget.normalise_tree(world)

	var rings: Array[MeshInstance3D] = []
	_collect_rings(world, rings)
	_check(
		rings.size() >= MINIMUM_WORLD_TORUS_COUNT,
		"world still carries its rings and collars (%d tori, floor %d)" % [rings.size(), MINIMUM_WORLD_TORUS_COUNT]
	)

	var total := 0
	var below_floor: Array[String] = []
	var increased: Array[String] = []
	var faceted_large: Array[String] = []
	var chair_bearing_profiles := 0
	var aft_interface_profiles := 0
	var freight_lashing_profiles := 0
	for instance in rings:
		var mesh := instance.mesh as TorusMesh
		total += TorusGeometryBudget.triangles_of(mesh)
		var profile := StringName(instance.get_meta(TorusGeometryBudget.PROFILE_META, &""))

		var authored := Vector2i(mesh.rings, mesh.ring_segments)
		if mesh.has_meta(TorusGeometryBudget.AUTHORED_META):
			authored = mesh.get_meta(TorusGeometryBudget.AUTHORED_META)

		# The budget is a ceiling, not a target: it may never make a ring finer
		# than its builder asked for.
		if mesh.rings > authored.x or mesh.ring_segments > authored.y:
			increased.append("%s (%dx%d over authored %dx%d)" % [
				instance.name, mesh.rings, mesh.ring_segments, authored.x, authored.y,
			])

		# ...and never coarser than the rendered floor, unless the builder itself
		# authored below it, in which case the budget simply left it alone.
		if profile == TorusGeometryBudget.PROFILE_OCCLUDED_CHAIR_BEARING:
			chair_bearing_profiles += 1
			if (
				mesh.rings < mini(TorusGeometryBudget.MIN_RINGS, authored.x)
				or mesh.ring_segments != TorusGeometryBudget.OCCLUDED_CHAIR_BEARING_RING_SEGMENTS
			):
				below_floor.append("%s profile drifted to %dx%d" % [instance.name, mesh.rings, mesh.ring_segments])
		elif profile == TorusGeometryBudget.PROFILE_AFT_INTERFACE_COLLAR:
			aft_interface_profiles += 1
			if (
				mesh.rings < mini(TorusGeometryBudget.MIN_RINGS, authored.x)
				or mesh.ring_segments != TorusGeometryBudget.AFT_INTERFACE_COLLAR_RING_SEGMENTS
			):
				below_floor.append("%s aft profile drifted to %dx%d" % [instance.name, mesh.rings, mesh.ring_segments])
		elif profile == TorusGeometryBudget.PROFILE_FREIGHT_RECESSED_LASHING_RING:
			freight_lashing_profiles += 1
			if (
				mesh.rings < mini(TorusGeometryBudget.MIN_RINGS, authored.x)
				or mesh.ring_segments
					!= TorusGeometryBudget.FREIGHT_RECESSED_LASHING_RING_SEGMENTS
			):
				below_floor.append("%s freight profile drifted to %dx%d" % [
					instance.name, mesh.rings, mesh.ring_segments,
				])
		elif (
			mesh.rings < mini(TorusGeometryBudget.MIN_RINGS, authored.x)
			or mesh.ring_segments < mini(TorusGeometryBudget.MIN_RING_SEGMENTS, authored.y)
		):
			below_floor.append("%s (%dx%d)" % [instance.name, mesh.rings, mesh.ring_segments])

		var scale_factor := instance.global_basis.get_scale().abs()
		var uniform := maxf(maxf(scale_factor.x, scale_factor.y), scale_factor.z)
		if mesh.outer_radius * uniform >= LARGE_RING_RADIUS_METRES:
			if mesh.rings < mini(LARGE_RING_MINIMUM_RINGS, authored.x):
				faceted_large.append("%s (%.2f m at %d rings)" % [
					instance.name, mesh.outer_radius * uniform, mesh.rings,
				])

	_check(
		increased.is_empty(),
		"the budget never increases authored tessellation%s" % ("" if increased.is_empty() else ": " + "; ".join(increased))
	)
	_check(
		below_floor.is_empty(),
		"no live ring is below the rendered tessellation floor%s" % ("" if below_floor.is_empty() else ": " + "; ".join(below_floor))
	)
	_check(
		faceted_large.is_empty(),
		"every ring a player reads as a circle keeps at least %d segments%s" % [
			LARGE_RING_MINIMUM_RINGS,
			"" if faceted_large.is_empty() else ": " + "; ".join(faceted_large),
		]
	)
	_check(
		total <= WORLD_TORUS_TRIANGLE_CEILING,
		"world ring geometry stays inside its budget (%d triangles, ceiling %d)" % [
			total, WORLD_TORUS_TRIANGLE_CEILING,
		]
	)
	_check(
		int(report["triangles_after"]) <= int(report["triangles_before"]),
		"the sweep reports a reduction rather than a growth (%d -> %d)" % [
			int(report["triangles_before"]), int(report["triangles_after"]),
		]
	)
	var profiles := report.get("profiles", {}) as Dictionary
	var chair_report := profiles.get(
		TorusGeometryBudget.PROFILE_OCCLUDED_CHAIR_BEARING, {}
	) as Dictionary
	_check(
		chair_bearing_profiles == 8
		and int(chair_report.get("resources", 0)) == 8
		and int(chair_report.get("instances", 0)) == 8,
		"the bounded observation-chair family remains eight independent visual rings/resources"
	)
	_check(
		int(chair_report.get("triangles_baseline", 0)) == 6656
		and int(chair_report.get("triangles_after", 0)) == 4096
		and int(chair_report.get("surfaces", 0)) == 8,
		"chair bearings freeze at 6656 -> 4096 triangles while eight instances/surfaces stay exact"
	)
	var aft_report := profiles.get(
		TorusGeometryBudget.PROFILE_AFT_INTERFACE_COLLAR, {}
	) as Dictionary
	_check(
		aft_interface_profiles == 26
		and int(aft_report.get("resources", 0)) == 26
		and int(aft_report.get("instances", 0)) == 26,
		"the bounded Aft interface family remains 26 independent visual collars/resources"
	)
	_check(
		int(aft_report.get("triangles_baseline", 0)) == 19968
		and int(aft_report.get("triangles_after", 0)) == 13312
		and int(aft_report.get("surfaces", 0)) == 26,
		"Aft interface collars freeze at 19968 -> 13312 triangles with 26 surfaces unchanged"
	)
	var freight_report := profiles.get(
		TorusGeometryBudget.PROFILE_FREIGHT_RECESSED_LASHING_RING, {}
	) as Dictionary
	_check(
		freight_lashing_profiles == 8
		and int(freight_report.get("resources", 0)) == 8
		and int(freight_report.get("instances", 0)) == 8,
		"the bounded freight lashing family remains eight independent visual rings/resources"
	)
	_check(
		int(freight_report.get("triangles_baseline", 0)) == 6144
		and int(freight_report.get("triangles_after", 0)) == 4096
		and int(freight_report.get("surfaces", 0)) == 8,
		"freight lashing rings freeze at 6144 -> 4096 triangles while eight instances/surfaces stay exact"
	)
	_check(
		total == 135840 and rings.size() == 154,
		"the production world-subtree torus census freezes 137888 -> 135840 triangles across 154 unchanged visible copies"
	)

	world.queue_free()


func _check_sweep_is_idempotent() -> void:
	var holder := Node3D.new()
	root.add_child(holder)
	var instance := MeshInstance3D.new()
	var mesh := TorusMesh.new()
	mesh.outer_radius = 0.25
	mesh.inner_radius = 0.16
	mesh.rings = 64
	mesh.ring_segments = 16
	instance.mesh = mesh
	holder.add_child(instance)

	var first := TorusGeometryBudget.normalise_tree(holder)
	var after_first := Vector2i(mesh.rings, mesh.ring_segments)
	var second := TorusGeometryBudget.normalise_tree(holder)

	_check(
		Vector2i(mesh.rings, mesh.ring_segments) == after_first,
		"a second sweep is a no-op rather than a further reduction"
	)
	_check(
		int(second["triangles_before"]) == int(second["triangles_after"]),
		"a second sweep reports no further saving"
	)
	_check(
		int(first["triangles_after"]) < int(first["triangles_before"]),
		"the first sweep does reduce a 64x16 quarter-metre collar"
	)
	holder.free()


func _check_authored_values_round_trip() -> void:
	var holder := Node3D.new()
	root.add_child(holder)
	var instance := MeshInstance3D.new()
	var mesh := TorusMesh.new()
	mesh.outer_radius = 0.25
	mesh.inner_radius = 0.16
	mesh.rings = 64
	mesh.ring_segments = 16
	instance.mesh = mesh
	holder.add_child(instance)

	TorusGeometryBudget.normalise_tree(holder)
	var restored := TorusGeometryBudget.restore_authored(holder)
	_check(
		restored == 1 and mesh.rings == 64 and mesh.ring_segments == 16,
		"restore_authored puts a budgeted ring back exactly as its builder made it"
	)
	holder.free()


func _collect_rings(node: Node, into: Array[MeshInstance3D]) -> void:
	var instance := node as MeshInstance3D
	if instance != null and instance.mesh is TorusMesh:
		into.append(instance)
	for child in node.get_children():
		_collect_rings(child, into)


func _check(condition: bool, description: String) -> void:
	_assertions += 1
	if condition:
		print("PASS: ", description)
	else:
		_failures.append(description)
		push_error("FAIL: " + description)


func _finish() -> void:
	if _failures.is_empty():
		print("TORUS_GEOMETRY_BUDGET_TEST_OK: %d assertions" % _assertions)
		quit(0)
	else:
		print("TORUS_GEOMETRY_BUDGET_TEST_FAILED: ", "; ".join(_failures))
		quit(1)
