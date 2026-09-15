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
	_check_declared_view_contract()
	await _check_world_rings()
	_check_sweep_is_idempotent()
	_check_authored_values_round_trip()
	_finish()


## The declared-view rule (ninth trim): a builder may state how close a camera
## gets to a ring, and the plan is solved there with floors that scale with the
## declaration. What this guards: walk-up rings are bit-for-bit unchanged, a
## declaration never raises tessellation, the far floors hold, declared answers
## stay cardinal-aligned so AABB contracts hold, and a shared mesh can only ever
## be declared closer.
func _check_declared_view_contract() -> void:
	# At or under walk-up range the rule is exactly the photographed one.
	for radii in [[0.25, 0.16], [0.19, 0.12], [0.74, 0.55], [9.0, 8.7]]:
		var walk_up := TorusGeometryBudget.plan(radii[0], radii[1])
		var declared_near := TorusGeometryBudget.plan(radii[0], radii[1], 0.3)
		var declared_eye := TorusGeometryBudget.plan(
			radii[0], radii[1], TorusGeometryBudget.NEAR_EYE_METRES
		)
		_check(
			walk_up == declared_near and walk_up == declared_eye,
			"a %.2f m ring declared at or under walk-up range keeps the walk-up plan" % radii[0]
		)
	_check(
		TorusGeometryBudget.floor_rings_for(TorusGeometryBudget.NEAR_EYE_METRES)
			== TorusGeometryBudget.MIN_RINGS
		and TorusGeometryBudget.floor_ring_segments_for(TorusGeometryBudget.NEAR_EYE_METRES)
			== TorusGeometryBudget.MIN_RING_SEGMENTS,
		"the walk-up floors are the photographed 32x12"
	)

	# The floors scale with distance and never pass the far floors.
	_check(
		TorusGeometryBudget.floor_rings_for(1.0) == 20
		and TorusGeometryBudget.floor_rings_for(1.6) == 12
		and TorusGeometryBudget.floor_rings_for(3.4) == TorusGeometryBudget.FAR_MIN_RINGS
		and TorusGeometryBudget.floor_rings_for(100.0) == TorusGeometryBudget.FAR_MIN_RINGS
		and TorusGeometryBudget.floor_ring_segments_for(1.0) == 8
		and TorusGeometryBudget.floor_ring_segments_for(3.4) == TorusGeometryBudget.FAR_MIN_RING_SEGMENTS
		and TorusGeometryBudget.FAR_MIN_RINGS >= 12
		and TorusGeometryBudget.FAR_MIN_RING_SEGMENTS >= 8,
		"declared floors scale from the photographed pair and stop at 12x8"
	)

	# A declared answer is never finer than the walk-up answer, never coarser
	# than the far floor, and always a multiple of four on both circles.
	for distance in [1.0, 1.6, 2.5, 3.4, 8.0]:
		for radii in [[0.25, 0.16], [0.19, 0.12], [0.46, 0.34], [2.55, 2.25]]:
			var walk_up := TorusGeometryBudget.plan(radii[0], radii[1])
			var declared := TorusGeometryBudget.plan(radii[0], radii[1], distance)
			_check(
				int(declared["rings"]) <= int(walk_up["rings"])
				and int(declared["ring_segments"]) <= int(walk_up["ring_segments"])
				and int(declared["rings"]) >= TorusGeometryBudget.FAR_MIN_RINGS
				and int(declared["ring_segments"]) >= TorusGeometryBudget.FAR_MIN_RING_SEGMENTS
				and int(declared["rings"]) % TorusGeometryBudget.RADIAL_ALIGNMENT == 0
				and int(declared["ring_segments"]) % TorusGeometryBudget.RADIAL_ALIGNMENT == 0,
				"a %.2f m ring declared at %.1f m plans %dx%d: under the walk-up %dx%d, over the far floor, cardinal-aligned" % [
					radii[0], distance, int(declared["rings"]), int(declared["ring_segments"]),
					int(walk_up["rings"]), int(walk_up["ring_segments"]),
				]
			)

	# The large-ring calibration survives a declaration: the sweep of a ring a
	# player reads as a circle is still 40 at the exterior range's approach.
	var drone_ring := TorusGeometryBudget.plan(2.55, 2.25, 3.0)
	_check(
		int(drone_ring["rings"]) >= LARGE_RING_MINIMUM_RINGS,
		"a 2.55 m ring declared at 3 m keeps %d rings (got %d)" % [
			LARGE_RING_MINIMUM_RINGS, int(drone_ring["rings"]),
		]
	)

	# A declaration is applied through the sweep without touching metadata, a
	# shared mesh is budgeted at the closest of its declarations, and the
	# baseline column still reports the walk-up rule.
	var holder := Node3D.new()
	root.add_child(holder)
	var mesh := TorusMesh.new()
	mesh.outer_radius = 0.25
	mesh.inner_radius = 0.16
	mesh.rings = 64
	mesh.ring_segments = 16
	for _copy in 2:
		var instance := MeshInstance3D.new()
		instance.mesh = mesh
		holder.add_child(instance)
	TorusGeometryBudget.declare_nearest_view(mesh, 8.0)
	TorusGeometryBudget.declare_nearest_view(mesh, 1.6)
	TorusGeometryBudget.declare_nearest_view(mesh, 3.0)
	_check(
		is_equal_approx(TorusGeometryBudget.nearest_view_for(mesh), 1.6)
		and mesh.get_meta_list().is_empty(),
		"a shared mesh keeps the closest declaration and no metadata is written by declaring"
	)
	var report := TorusGeometryBudget.normalise_tree(holder)
	var expected := TorusGeometryBudget.plan(0.25, 0.16, 1.6)
	var walk_up_plan := TorusGeometryBudget.plan(0.25, 0.16)
	_check(
		mesh.rings == int(expected["rings"])
		and mesh.ring_segments == int(expected["ring_segments"])
		and mesh.get_meta(TorusGeometryBudget.AUTHORED_META, Vector2i.ZERO) == Vector2i(64, 16)
		and mesh.get_meta_list().size() == 1
		and int(report["triangles_baseline"])
			== int(walk_up_plan["rings"]) * int(walk_up_plan["ring_segments"]) * 2 * 2
		and int(report["triangles_after"]) == mesh.rings * mesh.ring_segments * 2 * 2,
		"the sweep solves a declared ring at its declaration (%dx%d) and reports the walk-up %dx%d as its baseline" % [
			mesh.rings, mesh.ring_segments, int(walk_up_plan["rings"]), int(walk_up_plan["ring_segments"]),
		]
	)
	var restored := TorusGeometryBudget.restore_authored(holder)
	_check(
		restored == 2 and mesh.rings == 64 and mesh.ring_segments == 16,
		"restore_authored puts a declared ring back exactly as its builder made it"
	)
	holder.free()

	# The sphere rule is the ship plan carried out to a declaration in the same
	# way: identical at walk-up, floored at the freight berth's 12x6 far out.
	var walk_up_sphere := ShipGeometryBudget.sphere_plan(0.16, 24, 12)
	var kit_walk_up := StationSurfaceKit.sphere_tessellation_for(
		0.16, TorusGeometryBudget.NEAR_EYE_METRES, 24, 12
	)
	_check(
		kit_walk_up == Vector2i(int(walk_up_sphere["radial_segments"]), int(walk_up_sphere["rings"]))
		and StationSurfaceKit.sphere_tessellation_for(0.16, 1.0, 24, 12) == Vector2i(20, 11)
		and StationSurfaceKit.sphere_tessellation_for(0.16, 3.0, 24, 12) == Vector2i(12, 7)
		and StationSurfaceKit.sphere_tessellation_for(0.095, 2.9, 24, 12) == Vector2i(12, 7)
		and StationSurfaceKit.sphere_tessellation_for(0.26, 3.0, 24, 12) == Vector2i(16, 9)
		and StationSurfaceKit.sphere_tessellation_for(1.4, 3.0, 24, 12) == Vector2i(24, 12)
		and StationSurfaceKit.sphere_tessellation_for(0.5, 0.6, 12, 6) == Vector2i(12, 6)
		and StationSurfaceKit.sphere_tessellation_for(0.02, 100.0, 12, 6) == Vector2i(12, 6),
		"the declared sphere rule matches the ship plan at walk-up, scales with distance, keeps an equatorial vertex ring, floors at twelve meridians and never rises"
	)
	# The odd ring count is what keeps a declared sphere's width exact: Godot
	# cuts the meridian into `rings + 1` bands, so 12x7 has a vertex ring on the
	# equator and 12x6 does not.
	var declared_lens := SphereMesh.new()
	declared_lens.radius = 0.075
	declared_lens.height = 0.15
	var declared_recipe := StationSurfaceKit.sphere_tessellation_for(0.075, 2.5, 24, 12)
	declared_lens.radial_segments = declared_recipe.x
	declared_lens.rings = declared_recipe.y
	_check(
		declared_recipe == Vector2i(12, 7)
		and declared_lens.get_aabb().size.is_equal_approx(Vector3(0.15, 0.15, 0.15)),
		"a declared 7.5 cm lens keeps its exact 0.15 m extent on every axis (got %s at %s)" % [
			str(declared_lens.get_aabb().size), str(declared_recipe),
		]
	)


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

		# ...and never coarser than the rendered floor at the ring's declared
		# nearest view — the photographed 32x12 for anything a player can walk
		# up to, scaled out only where a builder has measured the distance —
		# unless the builder itself authored below it, in which case the budget
		# simply left it alone.
		var declared_view := TorusGeometryBudget.nearest_view_for(mesh)
		var rings_floor := TorusGeometryBudget.floor_rings_for(declared_view)
		var segments_floor := TorusGeometryBudget.floor_ring_segments_for(declared_view)
		if profile == TorusGeometryBudget.PROFILE_OCCLUDED_CHAIR_BEARING:
			chair_bearing_profiles += 1
			if (
				mesh.rings < mini(rings_floor, authored.x)
				or mesh.ring_segments != TorusGeometryBudget.OCCLUDED_CHAIR_BEARING_RING_SEGMENTS
			):
				below_floor.append("%s profile drifted to %dx%d" % [instance.name, mesh.rings, mesh.ring_segments])
		elif profile == TorusGeometryBudget.PROFILE_AFT_INTERFACE_COLLAR:
			aft_interface_profiles += 1
			if (
				mesh.rings < mini(rings_floor, authored.x)
				or mesh.ring_segments != TorusGeometryBudget.AFT_INTERFACE_COLLAR_RING_SEGMENTS
			):
				below_floor.append("%s aft profile drifted to %dx%d" % [instance.name, mesh.rings, mesh.ring_segments])
		elif profile == TorusGeometryBudget.PROFILE_FREIGHT_RECESSED_LASHING_RING:
			freight_lashing_profiles += 1
			if (
				mesh.rings < mini(rings_floor, authored.x)
				or mesh.ring_segments
					!= TorusGeometryBudget.FREIGHT_RECESSED_LASHING_RING_SEGMENTS
			):
				below_floor.append("%s freight profile drifted to %dx%d" % [
					instance.name, mesh.rings, mesh.ring_segments,
				])
		elif (
			mesh.rings < mini(rings_floor, authored.x)
			or mesh.ring_segments < mini(segments_floor, authored.y)
		):
			below_floor.append("%s (%dx%d)" % [instance.name, mesh.rings, mesh.ring_segments])
		# A declared ring is never coarser than the absolute far floor, and a
		# walk-up ring is exactly held to the photographed one: the declared
		# floor can only be below the walk-up floor when a builder declared.
		if declared_view > TorusGeometryBudget.NEAR_EYE_METRES and (
			mesh.rings < mini(TorusGeometryBudget.FAR_MIN_RINGS, authored.x)
			or mesh.ring_segments < mini(TorusGeometryBudget.FAR_MIN_RING_SEGMENTS, authored.y)
		):
			below_floor.append("%s declared at %.2f m fell under the far floor (%dx%d)" % [
				instance.name, declared_view, mesh.rings, mesh.ring_segments,
			])

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
	# The sweep covers ordinary renderers; batched tori are budgeted by their
	# builders. Their full authored copy cost still belongs under the world cap.
	var batched_triangles := 0
	for candidate in world.find_children("*", "MultiMeshInstance3D", true, false):
		var batch := candidate as MultiMeshInstance3D
		if batch.multimesh != null and batch.multimesh.mesh is TorusMesh:
			batched_triangles += TorusGeometryBudget.triangles_of(batch.multimesh.mesh as TorusMesh) * batch.multimesh.instance_count
	_check(
		total + batched_triangles <= WORLD_TORUS_TRIANGLE_CEILING,
		"world ring geometry stays inside its budget (%d triangles, ceiling %d)" % [
			total + batched_triangles, WORLD_TORUS_TRIANGLE_CEILING,
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
	# Eight bearings at 24x8: the occluded eight-edge tube as before, with the
	# major sweep now solved at the family's declared metre.
	_check(
		int(chair_report.get("triangles_baseline", 0)) == 6656
		and int(chair_report.get("triangles_after", 0)) == 3072
		and int(chair_report.get("surfaces", 0)) == 8,
		"chair bearings freeze at 6656 -> 3072 triangles while eight instances/surfaces stay exact"
	)
	var aft_report := profiles.get(
		TorusGeometryBudget.PROFILE_AFT_INTERFACE_COLLAR, {}
	) as Dictionary
	_check(
		aft_interface_profiles == 20
		and int(aft_report.get("resources", 0)) == 5
		and int(aft_report.get("instances", 0)) == 20,
		"the ordinary Aft interface renderers retain 20 copies sharing five immutable recipes"
	)
	# Five roof-spine clamps at 16x8, three service-wall conduit collars at 20x8
	# and four pedestal bearings at 24x8 are solved at their declared ranges;
	# the eight walk-up collars keep 32x8: 1280 + 960 + 1536 + 4096.
	_check(
		int(aft_report.get("triangles_baseline", 0)) == 15360
		and int(aft_report.get("triangles_after", 0)) == 7872
		and int(aft_report.get("surfaces", 0)) == 20,
		"ordinary Aft interface collars retain 15360 -> 7872 triangles across 20 surfaces"
	)
	var freight_report := profiles.get(
		TorusGeometryBudget.PROFILE_FREIGHT_RECESSED_LASHING_RING, {}
	) as Dictionary
	_check(
		freight_lashing_profiles == 8
		and int(freight_report.get("resources", 0)) == 1
		and int(freight_report.get("instances", 0)) == 8,
		"the freight lashing family retains eight independent visuals sharing one immutable ring recipe"
	)
	# Eight recessed rings at 20x8: the profile's eight-edge tube as before,
	# with the major sweep solved at the deck-flush standing-eye range.
	_check(
		int(freight_report.get("triangles_baseline", 0)) == 6144
		and int(freight_report.get("triangles_after", 0)) == 2560
		and int(freight_report.get("surfaces", 0)) == 8,
		"freight lashing rings freeze at 6144 -> 2560 triangles while eight instances/surfaces stay exact"
	)
	# Refrozen 2026-09-15 for the ninth trim: the same 133 copies, 111,584 ->
	# 87,008 triangles, every saving from a ring whose builder declared its
	# nearest view (deck-flush sockets and connectors, the habitat service run,
	# the Aft roof and underfloor families, the recessed lashing rings, the
	# exterior range at its hull approach). No ring was added or removed.
	_check(
		total == 87520 and rings.size() == 133,
		"the ordinary world-subtree TorusMesh renderers retain 87520 triangles across 133 copies (got %d across %d)"
			% [total, rings.size()]
	)

	# Six console collars moved out of the sweep's ordinary MeshInstance roster.
	# Their builder explicitly applies the same profile before batching; retain
	# its exact copies, recipe, buffer and authority checks in this budget suite.
	var aft := world.get_node("AftJunctionStack") as AftJunctionStack
	var shock := aft.get_console_shock_collar_visual_allocation_audit()
	_check(bool(shock.valid), "the six batched console shock collars preserve their exact reviewed profile and authored renderer contract")

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
