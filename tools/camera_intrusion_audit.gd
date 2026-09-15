class_name CameraIntrusionAudit
extends SceneTree

## Ship-perspective camera intrusion audit for the production scene (Phase 10 §1).
##
## The walking half of "audit world geometry from the embodied player and ship
## perspectives" is covered by `tools/station_walkability_sweep.gd` and
## `tools/coplanar_seam_audit.gd`. This is the flying half: it asks where the
## *player's actual camera* ends up inside something while a craft sits at its
## berth, descends its landing-assist lane, climbs back out of it, flies the
## published outbound route, or is left behind when the pilot steps out of the
## cabin.
##
## Three independent defects are measured, because they have three different
## owners and three different fixes:
##
##   (a) **camera sphere overlap** -- the chase rig's own `SpringArm3D` sweep
##       shape (radius `chase_camera_collision_radius`) ends up overlapping
##       solid collision. The arm excludes the owning craft by RID, so its own
##       hull is checked separately against the craft's landing collision
##       envelope; everything else is a live `intersect_shape` on the real
##       `CAMERA_OBSTRUCTION_QUERY_MASK`.
##   (b) **near-plane intrusion** -- a near-plane corner of the resolved chase
##       camera, the cockpit camera at its seat pose, or the on-foot camera at
##       the cabin exit lies *inside* a visible opaque renderer. Collision is
##       not the authority here: station dressing, greebles and most ship hull
##       plating carry no collision at all, so this walks real triangles
##       (`Mesh.surface_get_arrays`, including decoded `MultiMesh` copies) and
##       runs a three-ray parity test in each renderer's own local space.
##       Requiring all three rays to agree is what keeps open shells and single
##       quads -- which a one-ray parity test always calls "inside" -- out of
##       the report.
##   (c) **spring-arm collapse** -- the arm resolves so short at rest that the
##       player cannot read their own craft. A camera that is technically clear
##       of geometry but sitting on the tailplane is still a defect.
##
## Poses are composed rather than flown. The chase rig is rigidly parented to
## the hull (`_update_presentation` forces `_camera.global_basis` back to the
## ship basis every frame), so the whole envelope a player can reach at one hull
## attitude is: the zoom they chose, `maximum_chase_camera_rotation_lag_degrees`
## of boom orbit lag in pitch or yaw, and the velocity bank. The rig's live
## parameters -- pivot offset, arm inclination, radius, margin, near, FOV,
## `keep_aspect` -- are read off the real nodes at boot and the arm sweep is
## replayed with the same `cast_motion` the engine uses, so the simulation is
## checked against the live rig at each craft's berth and the disagreement is
## reported.
##
## Aspect ratio is sampled twice. The project ships
## `display/window/stretch/aspect = keep`, which pillarboxes a 32:9 display back
## to a 16:9 render, so 16:9 is the shipping case; the second pass exists only
## to say honestly whether the `KEEP_HEIGHT` vertical-FOV policy would make
## intrusions worse at 137.7 degrees horizontal if that stretch mode ever
## changed. No FOV policy is invented here.
##
## The audit is triage, not a gate: it always exits 0 once the scene boots,
## prints a per-craft summary, and writes the full grouped list to
## `user://camera_intrusion_audit.json`.

const SCHEMA_VERSION := 1
const PROFILE_ID := &"camera_intrusion_audit_v1"
const MAIN_SCENE := preload("res://scenes/main.tscn")
const OUTBOUND_ROUTE := preload(
	"res://assets/activities/cinder_reach_checkpoint_route.tres"
)
const JSON_PATH := "user://camera_intrusion_audit.json"

const SETTLE_FRAMES := 8

## Spatial index cell for the renderer grid, in metres.
const GRID := 4.0
const GRID_SPAN_BUDGET := 4096
const MULTIMESH_INSTANCE_BUDGET := 2048
const MAX_TRIANGLES_PER_SURFACE := 20000
## How many world renderers the containment self-check probes at their own
## bounding-box centre before any camera pose is evaluated.
const SELF_CHECK_SAMPLES := 400

## Lane resolution. The assist lane is short and worth walking finely; the
## outbound route is mostly open space, so it is stepped coarsely and capped --
## past this distance from the launch gate there is nothing left to intrude on.
const ASSIST_LANE_SAMPLES := 9
const OUTBOUND_STEP_M := 10.0
const OUTBOUND_RANGE_M := 400.0

## Aspect ratios sampled for the near plane. 16:9 is what the shipping
## `keep` stretch mode actually renders; 32:9 is the reported-only ultrawide
## case (137.7 degrees horizontal at the shipped 72 degree vertical FOV).
const SHIPPING_ASPECT := 16.0 / 9.0
const ULTRAWIDE_ASPECT := 32.0 / 9.0

## A resolved rest arm shorter than this is unreadable: the craft fills the
## frame and the player loses the situational view the chase rig exists for.
## Free flight along the published route carries no attitude contract, so the
## whole tilt range is reachable there. Berth lanes use the berth's own
## published `assist_maximum_tilt_degrees` instead of this.
const FREE_FLIGHT_TILT_DEGREES := 90.0

const READABLE_REST_ARM_FLOOR_M := 4.0
const READABLE_REST_ARM_FRACTION := 0.5

## Sphere overlap shallower than this is contact, not intrusion, and is inside
## the `SpringArm3D` margin the rig already keeps.
const SPHERE_INTRUSION_EPSILON := 0.001

## Ray directions for the parity test, deliberately off-axis so an axis-aligned
## box face, edge or vertex cannot swallow or double-count a crossing.
const PARITY_RAYS: Array[Vector3] = [
	Vector3(0.98255, 0.11103, 0.04649),
	Vector3(0.09011, 0.98239, 0.16294),
	Vector3(0.15434, 0.06081, 0.98615),
]
const RAY_EPSILON := 1.0e-7

var _instances: Array[Dictionary] = []
## One spatial index per audit space: index 0 is world space, index n > 0 is
## craft n - 1's own root-local space. A craft's own renderers have to be
## indexed locally because lane poses are composed, not flown -- the hull stays
## parked while its camera is evaluated 300 m down the outbound route.
var _grids: Array[Dictionary] = []
var _oversize: Array[PackedInt32Array] = []
var _space_instances: Array[PackedInt32Array] = []

var _mesh_surface_faces: Dictionary = {}
var _crafts: Array[Dictionary] = []
var _findings: Dictionary = {}
var _notes := PackedStringArray()
var _skipped_batches := 0
var _skipped_surfaces := 0
var _shadow_only_skips := 0
var _chase_samples := 0
var _point_tests := 0
var _candidate_tests := 0
var _improper_poses := 0
var _parity_evaluations := 0
var _self_check: Dictionary = {}
var _phase_ms: Dictionary = {}

var _state: PhysicsDirectSpaceState3D
var _sphere := SphereShape3D.new()
var _sphere_query := PhysicsShapeQueryParameters3D.new()


func _init() -> void:
	call_deferred("_run_cli")


func _run_cli() -> void:
	var started := Time.get_ticks_msec()
	var game := MAIN_SCENE.instantiate()
	if game == null:
		push_error("CAMERA_INTRUSION_AUDIT_FAILED: production Main did not instantiate")
		quit(1)
		return
	root.add_child(game)
	await process_frame
	await physics_frame
	if game.has_method("start_shift"):
		game.call("start_shift")
	for _settle in SETTLE_FRAMES:
		await physics_frame
	await process_frame

	var world := game.get_node_or_null(^"ShipyardWorld") as Node3D
	if world == null:
		push_error("CAMERA_INTRUSION_AUDIT_FAILED: production ShipyardWorld missing")
		quit(1)
		return
	_state = (game as Node3D).get_viewport().world_3d.direct_space_state
	_sphere_query.shape = _sphere
	_sphere_query.collision_mask = PhysicsLayers.CAMERA_OBSTRUCTION_QUERY_MASK
	_sphere_query.collide_with_areas = false
	_sphere_query.collide_with_bodies = true

	var booted := Time.get_ticks_msec()
	_collect_crafts(game, world)
	if _crafts.is_empty():
		push_error("CAMERA_INTRUSION_AUDIT_FAILED: production Main exposed no flyable craft")
		quit(1)
		return
	_collect_renderers(game as Node3D)
	var walked := Time.get_ticks_msec()
	_index_instances()
	var indexed := Time.get_ticks_msec()

	_run_self_check()

	var player := game.get_node_or_null(^"Player") as Node3D
	var exit_rig := _describe_exit_rig(player)
	for craft_index in _crafts.size():
		_audit_craft(craft_index, exit_rig)
	_phase_ms = {
		"boot": booted - started,
		"walk": walked - booted,
		"index": indexed - walked,
		"sample": Time.get_ticks_msec() - indexed,
	}

	var report := _build_report(world, exit_rig, Time.get_ticks_msec() - started)
	for line in summary_lines(report):
		print(line)
	var file := FileAccess.open(JSON_PATH, FileAccess.WRITE)
	if file == null:
		push_error("CAMERA_INTRUSION_AUDIT_FAILED: cannot write %s" % JSON_PATH)
		quit(1)
		return
	file.store_string(JSON.stringify(report, "\t", true, false))
	file.close()
	print("CAMERA_INTRUSION_AUDIT_JSON=", ProjectSettings.globalize_path(JSON_PATH))
	print("CAMERA_INTRUSION_AUDIT_OK")
	game.queue_free()
	await process_frame
	quit(0)


# ------------------------------------------------------------------- craft --


## Reads the live rig instead of re-deriving it. Every number used to compose a
## pose below -- the pivot offset, the arm's inclination and direction, the
## sweep radius and margin, the near plane, the FOV and the aspect policy --
## comes off the production nodes, so a later change to `_build_markers_and_camera`
## moves this audit with it rather than leaving it measuring a stale rig.
func _collect_crafts(game: Node, world: Node3D) -> void:
	var berth_ids: Array = world.call("get_berth_ids")
	var station_berths: Dictionary = {}
	for berth_id: StringName in berth_ids:
		var berth := world.call("get_berth_node", berth_id) as ShipBerth
		if berth != null:
			station_berths[berth_id] = berth
	var extra_berths: Array[ShipBerth] = []
	for candidate in (game as Node).find_children("*", "ShipBerth", true, false):
		var berth := candidate as ShipBerth
		if berth != null and not station_berths.has(berth.get_berth_id()):
			extra_berths.append(berth)
	if extra_berths.is_empty():
		_notes.append(
			"no off-station ShipBerth (Ember/Aurora surface host) is resident at boot; "
			+ "surface-host lanes are not audited here"
		)
	# An off-station pad has no craft homed on it, so its lanes are flown by
	# whichever craft the session currently has authority over.
	var host_pilot: HeroShip = game.call("get_active_ship") as HeroShip
	var ships: Array = game.call("get_flyable_ships")
	if host_pilot == null and not ships.is_empty():
		host_pilot = ships[0] as HeroShip
	var outbound := _outbound_polyline(world)
	for ship: HeroShip in ships:
		if ship == null or not is_instance_valid(ship):
			continue
		var pivot := ship.get_node_or_null(^"CameraRig") as Node3D
		var arm := ship.get("_camera_spring_arm") as SpringArm3D
		var mount := ship.get("_camera_boundary_mount") as Node3D
		var chase := ship.get("_camera") as Camera3D
		var cockpit := ship.get("_cockpit_camera") as Camera3D
		if pivot == null or arm == null or chase == null or mount == null:
			_notes.append("%s exposes no chase rig to audit" % ship.get_ship_id())
			continue
		var collision := ship.get_landing_collision_report()
		# The rig's own authority for "inside my hull", so the audit and the
		# shipped boundary correction cannot disagree about where the hull ends.
		var envelope := ship.get_chase_camera_self_hull_envelope()
		var berth := station_berths.get(ship.get_home_berth_id()) as ShipBerth
		if berth == null:
			_notes.append("%s has no resident home berth (%s)" % [
				ship.get_ship_id(), ship.get_home_berth_id(),
			])
		# The arm places its direct children along its own +Z. Reading the live
		# mount back out of the rig keeps that convention measured, not assumed.
		var arm_direction := (arm.global_basis * Vector3(0.0, 0.0, 1.0)).normalized()
		var live_length := (mount.global_position - arm.global_position).dot(arm_direction)
		_crafts.append({
			"index": _crafts.size(),
			"ship": ship,
			"ship_id": ship.get_ship_id(),
			"node": String(ship.name),
			"rid": ship.get_rid(),
			"berth": berth,
			"berth_id": ship.get_home_berth_id(),
			"pivot_local": ship.to_local(pivot.global_position),
			"arm_local_direction": ship.global_basis.orthonormalized().inverse() * arm_direction,
			"arm_radius": ship.chase_camera_collision_radius,
			"arm_margin": ship.chase_camera_collision_margin,
			"arm_rest": arm.spring_length,
			"arm_minimum": ship.minimum_chase_camera_distance,
			"arm_maximum": ship.maximum_chase_camera_distance,
			"arm_live_length": live_length,
			"lag_degrees": ship.maximum_chase_camera_rotation_lag_degrees,
			"chase_near": chase.near,
			"chase_fov": chase.fov,
			"chase_keep_height": chase.keep_aspect == Camera3D.KEEP_HEIGHT,
			"chase_cull_mask": chase.cull_mask,
			"cockpit": cockpit,
			"cockpit_near": cockpit.near if cockpit != null else 0.0,
			"cockpit_fov": cockpit.fov if cockpit != null else 0.0,
			"cockpit_keep_height": cockpit == null \
				or cockpit.keep_aspect == Camera3D.KEEP_HEIGHT,
			"cockpit_local": ship.to_local(cockpit.global_position) \
				if cockpit != null else Vector3.ZERO,
			"cockpit_cull_mask": cockpit.cull_mask if cockpit != null else 0,
			"hull_bounds": envelope.get("bounds", AABB()) as AABB,
			"hull_valid": bool(envelope.get("valid", false)),
			"collision_bounds": collision.get("local_bounds", AABB()) as AABB,
			"hull_visual_lift_m": float(envelope.get("visual_lift_m", 0.0)),
			"hull_renderers": int(envelope.get("renderer_count", 0)),
			"exit_local": ship.to_local(ship.get_exit_transform().origin),
			"outbound": outbound,
			"surface_hosts": extra_berths if ship == host_pilot else ([] as Array[ShipBerth]),
			"space": 0,
		})
		if ship == host_pilot:
			for berth_node in extra_berths:
				_notes.append("off-station berth %s audited with %s" % [
					berth_node.get_berth_id(), ship.get_ship_id(),
				])
		if cockpit == null:
			_notes.append("%s exposes no cockpit camera" % ship.get_ship_id())


## The published outbound line: the station's own `LaunchGate` aim followed by
## the Cinder Reach checkpoint beacons, the same polyline
## `tests/outbound_route_clearance_test.gd` proves the largest hull can fly.
func _outbound_polyline(world: Node3D) -> Array[Vector3]:
	var points: Array[Vector3] = []
	var gate := world.call("get_launch_gate_transform") as Transform3D
	points.append(gate.origin)
	var beacons: Variant = (OUTBOUND_ROUTE as Resource).get("checkpoint_positions")
	if typeof(beacons) == TYPE_PACKED_VECTOR3_ARRAY:
		for beacon: Vector3 in (beacons as PackedVector3Array):
			points.append(beacon)
	if points.size() < 2:
		_notes.append(
			"outbound route resource exposed no readable beacons; "
			+ "sampling the launch-gate axis instead"
		)
		points.append(gate.origin + gate.basis * Vector3(0.0, 0.0, -OUTBOUND_RANGE_M))
	return points


func _describe_exit_rig(player: Node3D) -> Dictionary:
	if player == null:
		_notes.append("production Player missing; cabin-exit camera not audited")
		return {}
	var rig := player.get_node_or_null(^"CameraRig") as Node3D
	var arm := player.get_node_or_null(
		^"CameraRig/CameraYaw/CameraPitch/SpringArm3D"
	) as SpringArm3D
	var camera := player.get_node_or_null(
		^"CameraRig/CameraYaw/CameraPitch/SpringArm3D/PlayerCamera"
	) as Camera3D
	if rig == null or arm == null or camera == null:
		_notes.append("production Player exposes no camera rig; cabin exit not audited")
		return {}
	var eye_height := rig.position.y
	var report: Variant = null
	if player.has_method("get_camera_view_report"):
		report = player.call("get_camera_view_report")
	if report is Dictionary and (report as Dictionary).has("eye_pivot"):
		var eye: Variant = (report as Dictionary)["eye_pivot"]
		if eye is Vector3:
			eye_height = (eye as Vector3).y
	return {
		"eye_height": eye_height,
		"pitch_degrees": rad_to_deg(
			(player.get_node(^"CameraRig/CameraYaw/CameraPitch") as Node3D).rotation.x
		),
		"arm_length": arm.spring_length,
		"arm_margin": arm.margin,
		"arm_radius": (arm.shape as SphereShape3D).radius \
			if arm.shape is SphereShape3D else 0.2,
		"near": camera.near,
		"fov": camera.fov,
		"keep_height": camera.keep_aspect == Camera3D.KEEP_HEIGHT,
		"cull_mask": camera.cull_mask,
	}


# --------------------------------------------------------------- renderers --


func _collect_renderers(render_root: Node3D) -> void:
	var craft_by_id: Dictionary = {}
	for craft in _crafts:
		craft_by_id[(craft["ship"] as Node).get_instance_id()] = craft
	for candidate in render_root.find_children("*", "VisualInstance3D", true, false):
		var visual := candidate as VisualInstance3D
		if visual == null or not visual.is_visible_in_tree():
			continue
		if visual is Light3D or visual is GPUParticles3D or visual is CPUParticles3D:
			continue
		# `SHADOWS_ONLY` proxies never reach the colour pass, so a camera inside
		# one sees nothing and it is not an intrusion.
		if visual is GeometryInstance3D and (visual as GeometryInstance3D).cast_shadow \
				== GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY:
			_shadow_only_skips += 1
			continue
		var owner_craft := _owning_craft(visual, craft_by_id)
		var space := 0
		var reference := Transform3D.IDENTITY
		if not owner_craft.is_empty():
			space = int(owner_craft["index"]) + 1
			reference = (owner_craft["ship"] as Node3D).global_transform.affine_inverse()
		var path := String(render_root.get_path_to(visual))
		if visual is MultiMeshInstance3D:
			_collect_multimesh(visual as MultiMeshInstance3D, path, space, reference)
		elif visual is MeshInstance3D:
			var instance := visual as MeshInstance3D
			if instance.mesh == null:
				continue
			_add_instance(
				instance, path, -1, space, reference * instance.global_transform,
				instance.mesh,
				func(surface: int) -> Material:
					return instance.get_active_material(surface)
			)


func _owning_craft(node: Node, craft_by_id: Dictionary) -> Dictionary:
	var walker: Node = node
	while walker != null:
		var found: Variant = craft_by_id.get(walker.get_instance_id())
		if found != null:
			return found as Dictionary
		walker = walker.get_parent()
	return {}


func _collect_multimesh(
		batch: MultiMeshInstance3D,
		path: String,
		space: int,
		reference: Transform3D
	) -> void:
	var multimesh := batch.multimesh
	if multimesh == null or multimesh.mesh == null:
		return
	if multimesh.transform_format != MultiMesh.TRANSFORM_3D:
		return
	var count := multimesh.instance_count
	if multimesh.visible_instance_count >= 0:
		count = mini(count, multimesh.visible_instance_count)
	if count <= 0:
		return
	var placements := _multimesh_placements(batch, multimesh, count)
	if placements.is_empty() or placements.size() > MULTIMESH_INSTANCE_BUDGET:
		_skipped_batches += 1
		return
	var mesh := multimesh.mesh
	var override := batch.material_override
	var resolve := func(surface: int) -> Material:
		if override != null:
			return override
		return mesh.surface_get_material(surface)
	var batch_transform := reference * batch.global_transform
	for copy in placements.size():
		_add_instance(
			batch, path, copy, space, batch_transform * placements[copy], mesh, resolve
		)


## `MultiMesh.get_instance_transform()` answers identity in a headless probe.
## The packed `buffer` survives that round trip, and the station's batch builders
## also publish `authored_instance_transforms`; either recovers the placements.
func _multimesh_placements(
		batch: MultiMeshInstance3D,
		multimesh: MultiMesh,
		count: int
	) -> Array[Transform3D]:
	var placements: Array[Transform3D] = []
	var buffer := multimesh.buffer
	var stride := 12
	if multimesh.use_colors:
		stride += 4
	if multimesh.use_custom_data:
		stride += 4
	if buffer.size() >= count * stride:
		for instance in count:
			var base := instance * stride
			placements.append(Transform3D(
				Basis(
					Vector3(buffer[base + 0], buffer[base + 4], buffer[base + 8]),
					Vector3(buffer[base + 1], buffer[base + 5], buffer[base + 9]),
					Vector3(buffer[base + 2], buffer[base + 6], buffer[base + 10])
				),
				Vector3(buffer[base + 3], buffer[base + 7], buffer[base + 11])
			))
		return placements
	var authored := batch.get_meta("authored_instance_transforms", []) as Array
	for instance in mini(count, authored.size()):
		placements.append(authored[instance] as Transform3D)
	return placements


func _add_instance(
		node: VisualInstance3D,
		path: String,
		copy: int,
		space: int,
		placement: Transform3D,
		mesh: Mesh,
		resolve_material: Callable
	) -> void:
	var opaque := PackedInt32Array()
	for surface in mesh.get_surface_count():
		if _is_opaque(resolve_material.call(surface) as Material):
			opaque.append(surface)
	if opaque.is_empty():
		return
	var faces := _mesh_faces(mesh)
	var usable := PackedInt32Array()
	for surface in opaque:
		if surface < faces.size() and not (faces[surface] as PackedVector3Array).is_empty():
			usable.append(surface)
	if usable.is_empty():
		return
	var bounds := placement * mesh.get_aabb()
	if not bounds.has_volume() and bounds.size.length() <= 0.0:
		return
	_instances.append({
		"path": path,
		"copy": copy,
		"space": space,
		"layers": node.layers,
		"owner": _owner_script(node),
		"module": _module_for(path),
		"mesh": mesh,
		"surfaces": usable,
		"inverse": placement.affine_inverse(),
		"bounds": bounds,
	})


## Triangles per surface, in the mesh's own local space, cached per mesh
## resource so a thousand-copy batch decodes its geometry once.
func _mesh_faces(mesh: Mesh) -> Array:
	var key := mesh.get_rid()
	var cached: Variant = _mesh_surface_faces.get(key)
	if cached != null:
		return cached as Array
	var built: Array = []
	for surface in mesh.get_surface_count():
		built.append(_surface_triangles(mesh, surface))
	_mesh_surface_faces[key] = built
	return built


func _surface_triangles(mesh: Mesh, surface: int) -> PackedVector3Array:
	var empty := PackedVector3Array()
	if mesh is ArrayMesh \
			and (mesh as ArrayMesh).surface_get_primitive_type(surface) \
			!= Mesh.PRIMITIVE_TRIANGLES:
		_skipped_surfaces += 1
		return empty
	var arrays := mesh.surface_get_arrays(surface)
	if arrays.size() <= Mesh.ARRAY_VERTEX:
		return empty
	if typeof(arrays[Mesh.ARRAY_VERTEX]) != TYPE_PACKED_VECTOR3_ARRAY:
		return empty
	var vertices := arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array
	if vertices.is_empty():
		return empty
	var indices := PackedInt32Array()
	if arrays.size() > Mesh.ARRAY_INDEX \
			and typeof(arrays[Mesh.ARRAY_INDEX]) == TYPE_PACKED_INT32_ARRAY:
		indices = arrays[Mesh.ARRAY_INDEX] as PackedInt32Array
	var triangle_count := (
		indices.size() / 3 if not indices.is_empty() else vertices.size() / 3
	)
	if triangle_count <= 0:
		return empty
	if triangle_count > MAX_TRIANGLES_PER_SURFACE:
		_skipped_surfaces += 1
		return empty
	if indices.is_empty():
		return vertices
	var out := PackedVector3Array()
	out.resize(indices.size())
	for slot in indices.size():
		out[slot] = vertices[indices[slot]]
	return out


func _index_instances() -> void:
	var space_count := _crafts.size() + 1
	for space in space_count:
		_grids.append({})
		_oversize.append(PackedInt32Array())
		_space_instances.append(PackedInt32Array())
	for index in _instances.size():
		var instance := _instances[index]
		var space := int(instance["space"])
		if space >= space_count:
			continue
		_space_instances[space].append(index)
		var bounds := instance["bounds"] as AABB
		var low := _cell(bounds.position)
		var high := _cell(bounds.end)
		var span := (high.x - low.x + 1) * (high.y - low.y + 1) * (high.z - low.z + 1)
		if span <= 0 or span > GRID_SPAN_BUDGET:
			_oversize[space].append(index)
			continue
		var grid := _grids[space]
		for x in range(low.x, high.x + 1):
			for y in range(low.y, high.y + 1):
				for z in range(low.z, high.z + 1):
					var key := Vector3i(x, y, z)
					var bucket: PackedInt32Array = grid.get(key, PackedInt32Array())
					bucket.append(index)
					grid[key] = bucket


## Proves the containment detector can detect. Every solid renderer contains its
## own bounding-box centre, so a spread of world instances is probed at theirs
## before any camera is: a near-zero pass rate here means an empty report is a
## broken probe, not a clean scene. Shells, frames and plates legitimately do
## not contain their own centre, so the rate is a floor, never 100 per cent.
func _run_self_check() -> void:
	var pool := _space_instances[0]
	if pool.is_empty():
		return
	var stride := maxi(1, pool.size() / SELF_CHECK_SAMPLES)
	var probed := 0
	var contained := 0
	for slot in range(0, pool.size(), stride):
		var index := pool[slot]
		probed += 1
		if _point_in_instance(index, (_instances[index]["bounds"] as AABB).get_center()):
			contained += 1
	_self_check = {
		"probed": probed,
		"contained": contained,
		"fraction": snappedf(float(contained) / float(maxi(1, probed)), 0.001),
	}
	if contained == 0:
		_notes.append(
			"containment self-check found no solid renderer containing its own centre; "
			+ "treat every empty near-plane result below as unproven"
		)


static func _cell(point: Vector3) -> Vector3i:
	return Vector3i(floori(point.x / GRID), floori(point.y / GRID), floori(point.z / GRID))


# ------------------------------------------------------------------ lanes --


## The lanes one craft can put its camera on, as (label, ship transform) pairs.
##
## Only published geometry is used. The assist lane is the berth's own
## `get_assist_staging_transform()` to `get_dock_transform()` descent, its
## reverse is the launch climb, and the outbound polyline is the station's
## published `LaunchGate` aim followed by the Cinder Reach beacons. No route is
## invented between a fleet-dock berth and the launch gate, because the station
## publishes none and a straight line between them runs through the habitat.
func _craft_lanes(craft: Dictionary) -> Array[Dictionary]:
	var lanes: Array[Dictionary] = []
	var ship := craft["ship"] as HeroShip
	var berth := craft["berth"] as ShipBerth
	var parked := ship.global_transform
	lanes.append({
		"lane": &"berth_rest",
		"tilt_degrees": 0.0,
		"poses": [{"pose": parked, "freedom": 0.0}] as Array[Dictionary],
	})
	if berth != null:
		_append_berth_lanes(lanes, berth, &"assist_descent", &"launch_climb")
	for host: ShipBerth in (craft["surface_hosts"] as Array[ShipBerth]):
		_append_berth_lanes(
			lanes, host,
			StringName("surface_host_descent:%s" % host.get_berth_id()),
			StringName("surface_host_climb:%s" % host.get_berth_id())
		)
	var outbound := craft["outbound"] as Array[Vector3]
	var route := _walk_polyline(outbound)
	if not route.is_empty():
		lanes.append({
			"lane": &"outbound_route",
			"tilt_degrees": FREE_FLIGHT_TILT_DEGREES,
			"poses": route,
		})
		# The same line flown the other way is a different camera lane: the boom
		# trails behind the nose, so an inbound craft drags it through geometry
		# the outbound pass never touched.
		var reversed: Array[Vector3] = []
		for index in range(outbound.size() - 1, -1, -1):
			reversed.append(outbound[index])
		var inbound := _walk_polyline(reversed)
		if not inbound.is_empty():
			lanes.append({
				"lane": &"inbound_route",
				"tilt_degrees": FREE_FLIGHT_TILT_DEGREES,
				"poses": inbound,
			})
	return lanes


func _append_berth_lanes(
		lanes: Array[Dictionary],
		berth: ShipBerth,
		descent_id: StringName,
		climb_id: StringName
	) -> void:
	var dock := berth.get_dock_transform()
	var staging := berth.get_assist_staging_transform()
	var descent: Array[Dictionary] = []
	for step in ASSIST_LANE_SAMPLES:
		var ratio := float(step) / float(ASSIST_LANE_SAMPLES - 1)
		descent.append({
			"pose": Transform3D(
				Basis(Quaternion(staging.basis.orthonormalized()).slerp(
					Quaternion(dock.basis.orthonormalized()), ratio
				)),
				staging.origin.lerp(dock.origin, ratio)
			),
			# The berth's capture contract permits any yaw and up to its own
			# tilt limit where the craft is acquired, and the assist has rotated
			# the craft onto the dock attitude by the time it is parked. The
			# attitude envelope is scaled the same way rather than applying the
			# full capture freedom to a craft already sitting on the pad.
			"freedom": 1.0 - ratio,
		})
	lanes.append({
		"lane": descent_id,
		"tilt_degrees": berth.get_assist_maximum_tilt_degrees(),
		"poses": descent,
	})
	var climb: Array[Dictionary] = []
	for step in range(descent.size() - 1, -1, -1):
		climb.append(descent[step])
	lanes.append({
		"lane": climb_id,
		"tilt_degrees": berth.get_assist_maximum_tilt_degrees(),
		"poses": climb,
	})


## Walks a published polyline at `OUTBOUND_STEP_M`, stopping at
## `OUTBOUND_RANGE_M`: past that the route is open space with nothing left to
## intrude on, and the samples buy nothing but wall clock.
func _walk_polyline(points: Array[Vector3]) -> Array[Dictionary]:
	var poses: Array[Dictionary] = []
	var travelled := 0.0
	for leg in points.size() - 1:
		var from := points[leg]
		var to := points[leg + 1]
		var leg_length := from.distance_to(to)
		if leg_length <= 0.001:
			continue
		var heading := _travel_basis((to - from) / leg_length)
		var steps := maxi(1, int(ceil(leg_length / OUTBOUND_STEP_M)))
		for step in steps:
			if travelled > OUTBOUND_RANGE_M:
				return poses
			poses.append({
				"pose": Transform3D(heading, from.lerp(to, float(step) / float(steps))),
				"freedom": 1.0,
			})
			travelled += leg_length / float(steps)
	return poses


## Local forward is negative Z for every craft in the fleet, so a travel basis
## looks *back* along the direction of motion for its Z column.
##
## `Basis.looking_at` is used rather than a hand-built cross-product frame
## because the obvious hand-built one is a reflection, not a rotation: composing
## `Basis(reference.cross(forward), forward.cross(right), -forward)` yields
## determinant -1, `Quaternion()` of it is meaningless, and the chase rig's own
## `_chase_follow_rotation` slerp then resolves the boom onto an attitude no
## player can reach. Every pose this audit reports has to be one a craft can
## actually hold, which `_sample_chase` re-checks per sample.
static func _travel_basis(direction: Vector3) -> Basis:
	var forward := direction.normalized()
	var reference := Vector3.UP
	if absf(forward.dot(reference)) > 0.99:
		reference = Vector3.BACK
	return Basis.looking_at(forward, reference).orthonormalized()


## The boom orbit offsets a player can actually reach at one hull attitude:
## nothing, the rotation-lag limit in pitch or yaw, and the velocity bank. The
## optical basis is forced back to the hull every frame, so only the boom moves.
## The hull attitudes a player can hold on one lane point. Nothing here is
## invented: the berth's own `assist_maximum_tilt_degrees` is the tilt a landing
## approach may legally carry and any yaw is explicitly permitted, while free
## flight along the published route has no attitude contract at all. `freedom`
## collapses the whole set back onto the authored attitude at a parked berth.
static func _attitude_variants(tilt_degrees: float, freedom: float) -> Array[Dictionary]:
	var level: Array[Dictionary] = [{"id": &"level", "basis": Basis.IDENTITY}]
	if freedom <= 0.001 or tilt_degrees <= 0.0:
		return level
	var tilt := deg_to_rad(tilt_degrees * clampf(freedom, 0.0, 1.0))
	var yaw := PI * clampf(freedom, 0.0, 1.0)
	level.append({"id": &"pitch_up", "basis": Basis(Vector3.RIGHT, tilt)})
	level.append({"id": &"pitch_down", "basis": Basis(Vector3.RIGHT, -tilt)})
	level.append({"id": &"roll_left", "basis": Basis(Vector3.BACK, tilt)})
	level.append({"id": &"roll_right", "basis": Basis(Vector3.BACK, -tilt)})
	level.append({"id": &"yaw_left", "basis": Basis(Vector3.UP, yaw * 0.5)})
	level.append({"id": &"yaw_right", "basis": Basis(Vector3.UP, -yaw * 0.5)})
	level.append({"id": &"yaw_reversed", "basis": Basis(Vector3.UP, yaw)})
	return level


func _boom_variants(craft: Dictionary) -> Array[Dictionary]:
	var lag := deg_to_rad(float(craft["lag_degrees"]))
	var variants: Array[Dictionary] = [
		{"id": &"centred", "boom": Basis.IDENTITY, "bank": 0.0},
	]
	if lag > 0.0:
		variants.append({"id": &"lag_pitch_up", "boom": Basis(Vector3.RIGHT, lag), "bank": 0.0})
		variants.append({"id": &"lag_pitch_down", "boom": Basis(Vector3.RIGHT, -lag), "bank": 0.0})
		variants.append({"id": &"lag_yaw_left", "boom": Basis(Vector3.UP, lag), "bank": 0.0})
		variants.append({"id": &"lag_yaw_right", "boom": Basis(Vector3.UP, -lag), "bank": 0.0})
	# `_update_presentation` clamps the velocity bank to +-0.08 rad about the
	# craft's forward axis, and applies it to both the boom and the optics.
	variants.append({"id": &"bank_left", "boom": Basis.IDENTITY, "bank": 0.08})
	variants.append({"id": &"bank_right", "boom": Basis.IDENTITY, "bank": -0.08})
	return variants


# ---------------------------------------------------------------- sampling --


func _audit_craft(craft_index: int, exit_rig: Dictionary) -> void:
	var craft := _crafts[craft_index]
	var ship := craft["ship"] as HeroShip
	var zooms: Array[float] = [
		float(craft["arm_minimum"]), float(craft["arm_rest"]), float(craft["arm_maximum"]),
	]
	var booms := _boom_variants(craft)
	for lane in _craft_lanes(craft):
		var lane_id := lane["lane"] as StringName
		var tilt := float(lane["tilt_degrees"])
		for entry: Dictionary in (lane["poses"] as Array[Dictionary]):
			var base := entry["pose"] as Transform3D
			for attitude in _attitude_variants(tilt, float(entry["freedom"])):
				var pose := Transform3D(
					base.basis.orthonormalized() * (attitude["basis"] as Basis),
					base.origin
				)
				for zoom in zooms:
					for boom in booms:
						_sample_chase(craft, lane_id, pose, zoom, boom, attitude["id"])
				_sample_cockpit(craft, lane_id, pose, attitude["id"])
	_sample_rest_arm(craft)
	if not exit_rig.is_empty():
		_sample_cabin_exit(craft, ship.global_transform, exit_rig)


## Replays the engine's own sweep: `SpringArm3D` casts its shape along the arm's
## global +Z for `spring_length`, keeps the safe fraction, and holds `margin`
## clear of the first hit. The owning craft is excluded by RID exactly as
## `_build_markers_and_camera` excludes it, so its own hull is checked against
## the landing collision envelope instead.
func _sample_chase(
		craft: Dictionary,
		lane: StringName,
		pose: Transform3D,
		zoom: float,
		boom: Dictionary,
		attitude: StringName
	) -> void:
	_chase_samples += 1
	var hull_basis := pose.basis.orthonormalized()
	# A reflected frame is not an attitude; refusing to sample one keeps the
	# report to poses a craft can hold and a capture can reproduce.
	if hull_basis.determinant() <= 0.0:
		_improper_poses += 1
		return
	var bank := Basis(Vector3.FORWARD, float(boom["bank"]))
	var boom_basis := hull_basis * (boom["boom"] as Basis) * bank
	var pivot := pose * (craft["pivot_local"] as Vector3)
	var direction := (boom_basis * (craft["arm_local_direction"] as Vector3)).normalized()
	var radius := float(craft["arm_radius"])
	var resolved := _resolve_arm(craft, pivot, direction, zoom, radius)
	craft["retraction_samples"] = int(craft.get("retraction_samples", 0)) + 1
	if resolved < zoom - 0.001:
		craft["retracted_samples"] = int(craft.get("retracted_samples", 0)) + 1
		craft["shortest_arm_m"] = minf(float(craft.get("shortest_arm_m", INF)), resolved)
	var mount_point := pivot + direction * resolved
	var optical := hull_basis * bank
	# `ChaseCameraBoundaryMount` runs after the arm's own sweep and lifts the one
	# camera clear of the owning hull. Skipping it would report intrusions the
	# shipped rig already corrects -- and would miss the ones the lift creates.
	var correction := _boundary_correction(craft, mount_point, optical, pose)
	var camera_point := mount_point + hull_basis.y.normalized() * correction
	var sample := {
		"lane": lane, "zoom": zoom, "boom": boom["id"], "attitude": attitude,
		"ship_pose": pose,
		"arm_requested_m": zoom, "arm_resolved_m": resolved,
		"boundary_lift_m": correction,
		"ship_origin": pose.origin, "camera": camera_point,
	}
	_test_sphere(craft, camera_point, radius, pose, &"chase", sample)
	_test_near_plane(
		craft, camera_point, optical, float(craft["chase_near"]),
		float(craft["chase_fov"]), bool(craft["chase_keep_height"]),
		int(craft["chase_cull_mask"]), pose, &"chase", sample
	)


## Replays `HeroShip._enforce_chase_camera_self_hull_boundary`: if the mounted
## near plane is inside the craft's own landing collision envelope, the mount
## lifts the camera along the hull's up axis until the lowest near-plane sample
## clears the envelope's top face. The production code measures that against the
## live viewport, so the shipping 16:9 near plane is what drives the lift here.
func _boundary_correction(
		craft: Dictionary,
		mount: Vector3,
		optical: Basis,
		pose: Transform3D
	) -> float:
	if not bool(craft["hull_valid"]):
		return 0.0
	var bounds := craft["hull_bounds"] as AABB
	if not bounds.has_volume():
		return 0.0
	var inverse := pose.affine_inverse()
	var lowest := INF
	var clearance := INF
	for sample in _near_plane_points(
		mount, optical, float(craft["chase_near"]), float(craft["chase_fov"]),
		bool(craft["chase_keep_height"]), SHIPPING_ASPECT
	):
		var local := inverse * sample
		lowest = minf(lowest, local.y)
		clearance = minf(clearance, _signed_point_aabb_clearance(local, bounds))
	if clearance >= HeroShip.CHASE_CAMERA_SELF_HULL_CLEARANCE:
		return 0.0
	return maxf(bounds.end.y + HeroShip.CHASE_CAMERA_SELF_HULL_CLEARANCE - lowest, 0.0)


## The camera point plus its four near-plane corners, which is exactly the
## sample set `HeroShip._chase_camera_boundary_samples` uses.
static func _near_plane_points(
		point: Vector3,
		optical: Basis,
		near: float,
		fov: float,
		keep_height: bool,
		aspect: float
	) -> Array[Vector3]:
	var tangent := tan(deg_to_rad(fov * 0.5))
	var half_height := near * tangent
	var half_width := half_height * aspect
	if not keep_height:
		half_width = near * tangent
		half_height = half_width / aspect
	var forward := -optical.z.normalized()
	var right := optical.x.normalized()
	var up := optical.y.normalized()
	var centre := point + forward * near
	return [
		point,
		centre - right * half_width + up * half_height,
		centre + right * half_width + up * half_height,
		centre - right * half_width - up * half_height,
		centre + right * half_width - up * half_height,
	] as Array[Vector3]


func _sample_cockpit(
		craft: Dictionary,
		lane: StringName,
		pose: Transform3D,
		attitude: StringName
	) -> void:
	if craft["cockpit"] == null:
		return
	var seat := pose * (craft["cockpit_local"] as Vector3)
	_test_near_plane(
		craft, seat, pose.basis.orthonormalized(), float(craft["cockpit_near"]),
		float(craft["cockpit_fov"]), bool(craft["cockpit_keep_height"]),
		int(craft["cockpit_cull_mask"]), pose,
		&"cockpit", {
			"lane": lane, "attitude": attitude, "ship_pose": pose,
			"ship_origin": pose.origin, "camera": seat,
		}
	)


## The on-foot rig where the pilot is put down when they leave the cabin: the
## first-person eye, and the third-person boom at its authored rest length.
func _sample_cabin_exit(
		craft: Dictionary,
		pose: Transform3D,
		exit_rig: Dictionary
	) -> void:
	var ship := craft["ship"] as HeroShip
	var exit := ship.get_exit_transform()
	var eye := exit.origin + Vector3.UP * float(exit_rig["eye_height"])
	var facing := exit.basis.orthonormalized()
	var pitch := Basis(Vector3.RIGHT, deg_to_rad(float(exit_rig["pitch_degrees"])))
	var view := facing * pitch
	_test_near_plane(
		craft, eye, view, float(exit_rig["near"]), float(exit_rig["fov"]),
		bool(exit_rig["keep_height"]), int(exit_rig["cull_mask"]), pose,
		&"cabin_exit_first_person",
		{"lane": &"cabin_exit", "ship_pose": pose, "ship_origin": pose.origin, "camera": eye}
	)
	var direction := (view * Vector3(0.0, 0.0, 1.0)).normalized()
	var radius := float(exit_rig["arm_radius"])
	var boom := _resolve_arm(craft, eye, direction, float(exit_rig["arm_length"]), radius)
	var third := eye + direction * boom
	_test_sphere(craft, third, radius, pose, &"cabin_exit_third_person",
		{"lane": &"cabin_exit", "ship_pose": pose, "ship_origin": pose.origin,
		"camera": third, "arm_requested_m": float(exit_rig["arm_length"]),
		"arm_resolved_m": boom})
	_test_near_plane(
		craft, third, view, float(exit_rig["near"]), float(exit_rig["fov"]),
		bool(exit_rig["keep_height"]), int(exit_rig["cull_mask"]), pose,
		&"cabin_exit_third_person",
		{"lane": &"cabin_exit", "ship_pose": pose, "ship_origin": pose.origin, "camera": third}
	)


func _resolve_arm(
		craft: Dictionary,
		origin: Vector3,
		direction: Vector3,
		length: float,
		radius: float
	) -> float:
	if length <= 0.0:
		return 0.0
	_sphere.radius = radius
	_sphere_query.transform = Transform3D(Basis.IDENTITY, origin)
	_sphere_query.exclude = [craft["rid"]] as Array[RID]
	_sphere_query.motion = direction * length
	var sweep := _state.cast_motion(_sphere_query)
	_sphere_query.motion = Vector3.ZERO
	var safe := 1.0 if sweep.size() < 1 else float(sweep[0])
	var resolved := length * safe
	if safe < 1.0:
		resolved = maxf(0.0, resolved - float(craft["arm_margin"]))
	return resolved


## Deepest solid overlap of the sweep sphere, split by owner: the craft's own
## landing collision envelope (which the arm excludes by RID and therefore
## cannot retract for) and everything else on the camera obstruction mask.
func _test_sphere(
		craft: Dictionary,
		point: Vector3,
		radius: float,
		pose: Transform3D,
		rig: StringName,
		sample: Dictionary
	) -> void:
	if bool(craft["hull_valid"]):
		var local := pose.affine_inverse() * point
		var depth := radius - _point_aabb_distance(local, craft["hull_bounds"] as AABB)
		if depth > SPHERE_INTRUSION_EPSILON:
			_record(craft, &"camera_sphere_in_own_hull", rig, sample, {
				"target": "%s (self-hull envelope)" % craft["node"],
				"owner": "res://scripts/ships/hero_ship.gd",
				"depth_m": depth,
			})
	_sphere.radius = radius
	_sphere_query.transform = Transform3D(Basis.IDENTITY, point)
	_sphere_query.exclude = [craft["rid"]] as Array[RID]
	var hits := _state.intersect_shape(_sphere_query, 4)
	for hit in hits:
		var collider := hit.get("collider") as Node
		if collider == null:
			continue
		_record(craft, &"camera_sphere_in_world_collision", rig, sample, {
			"target": String(collider.name),
			"owner": _owner_script(collider),
			"depth_m": radius,
		})


## Near-plane corners inside a visible opaque renderer. Collision is not the
## authority: the plating, dressing and greebles that a near plane actually
## clips through mostly carry none.
func _test_near_plane(
		craft: Dictionary,
		point: Vector3,
		optical: Basis,
		near: float,
		fov: float,
		keep_height: bool,
		cull_mask: int,
		pose: Transform3D,
		rig: StringName,
		sample: Dictionary
	) -> void:
	for aspect_index in 2:
		var aspect := SHIPPING_ASPECT if aspect_index == 0 else ULTRAWIDE_ASPECT
		var band: StringName = &"16:9" if aspect_index == 0 else &"32:9"
		var points := _near_plane_points(point, optical, near, fov, keep_height, aspect)
		# The camera point itself is aspect independent, so the ultrawide pass
		# only has to re-probe the four widened corners.
		for index in range(0 if aspect_index == 0 else 1, points.size()):
			_probe_point(craft, points[index], cull_mask, pose, rig, band, sample)


func _probe_point(
		craft: Dictionary,
		point: Vector3,
		cull_mask: int,
		pose: Transform3D,
		rig: StringName,
		band: StringName,
		sample: Dictionary
	) -> void:
	var world_hit := _containing_instance(0, point, cull_mask)
	if world_hit >= 0:
		_record(craft, &"near_plane_in_world_mesh", rig, sample, {
			"target": String(_instances[world_hit]["path"]),
			"owner": String(_instances[world_hit]["owner"]),
			"module": String(_instances[world_hit]["module"]),
			"aspect": band,
			"depth_m": _point_aabb_depth(point, _instances[world_hit]["bounds"] as AABB),
		})
	var local := pose.affine_inverse() * point
	var own_hit := _containing_instance(int(craft["index"]) + 1, local, cull_mask)
	if own_hit >= 0:
		_record(craft, &"near_plane_in_own_hull_mesh", rig, sample, {
			"target": String(_instances[own_hit]["path"]),
			"owner": String(_instances[own_hit]["owner"]),
			"module": String(_instances[own_hit]["module"]),
			"aspect": band,
			"depth_m": _point_aabb_depth(local, _instances[own_hit]["bounds"] as AABB),
		})


## A renderer this camera's `cull_mask` excludes cannot be on screen, so it
## cannot be a near-plane intrusion. The Zenith and the Torrent both hide their
## exterior canopy shell from the cockpit rig in exactly this way.
func _containing_instance(space: int, point: Vector3, cull_mask: int) -> int:
	if space >= _grids.size():
		return -1
	_point_tests += 1
	var bucket: PackedInt32Array = (_grids[space] as Dictionary).get(
		_cell(point), PackedInt32Array()
	)
	_candidate_tests += bucket.size() + _oversize[space].size()
	for index in bucket:
		if int(_instances[index]["layers"]) & cull_mask == 0:
			continue
		if _point_in_instance(index, point):
			return index
	for index in _oversize[space]:
		if int(_instances[index]["layers"]) & cull_mask == 0:
			continue
		if _point_in_instance(index, point):
			return index
	return -1


func _point_in_instance(index: int, point: Vector3) -> bool:
	var instance := _instances[index]
	if not (instance["bounds"] as AABB).has_point(point):
		return false
	_parity_evaluations += 1
	var local := (instance["inverse"] as Transform3D) * point
	var faces := _mesh_faces(instance["mesh"] as Mesh)
	# Three rays, all of which must agree. One ray calls every open shell and
	# every single quad "inside"; three off-axis rays only agree for geometry
	# that actually closes around the point.
	for ray in PARITY_RAYS:
		var crossings := 0
		for surface in (instance["surfaces"] as PackedInt32Array):
			crossings += _ray_crossings(faces[surface] as PackedVector3Array, local, ray)
		if crossings % 2 == 0:
			return false
	return true


func _ray_crossings(
		triangles: PackedVector3Array,
		origin: Vector3,
		direction: Vector3
	) -> int:
	var crossings := 0
	var count := triangles.size() / 3
	for triangle in count:
		var base := triangle * 3
		var a := triangles[base]
		var edge1 := triangles[base + 1] - a
		var edge2 := triangles[base + 2] - a
		var pvec := direction.cross(edge2)
		var determinant := edge1.dot(pvec)
		if absf(determinant) < RAY_EPSILON:
			continue
		var inverse := 1.0 / determinant
		var tvec := origin - a
		var u := tvec.dot(pvec) * inverse
		if u < 0.0 or u > 1.0:
			continue
		var qvec := tvec.cross(edge1)
		var v := direction.dot(qvec) * inverse
		if v < 0.0 or u + v > 1.0:
			continue
		if edge2.dot(qvec) * inverse > RAY_EPSILON:
			crossings += 1
	return crossings


## Whether the chase rig still stands far enough back at rest to read the craft.
func _sample_rest_arm(craft: Dictionary) -> void:
	var ship := craft["ship"] as HeroShip
	var pose := ship.global_transform
	var pivot := pose * (craft["pivot_local"] as Vector3)
	var direction := (
		pose.basis.orthonormalized() * (craft["arm_local_direction"] as Vector3)
	).normalized()
	var rest := float(craft["arm_rest"])
	var resolved := _resolve_arm(craft, pivot, direction, rest, float(craft["arm_radius"]))
	var required := maxf(
		READABLE_REST_ARM_FLOOR_M,
		float(craft["arm_minimum"]) * READABLE_REST_ARM_FRACTION
	)
	craft["rest_arm_resolved_m"] = resolved
	craft["rest_arm_required_m"] = required
	# The simulated sweep is checked against the live rig it is standing in for.
	craft["simulation_disagreement_m"] = absf(resolved - float(craft["arm_live_length"]))
	if resolved < required:
		_record(craft, &"spring_arm_collapse_at_rest", &"chase", {
			"lane": &"berth_rest", "ship_pose": pose, "ship_origin": pose.origin,
			"camera": pivot + direction * resolved,
			"arm_requested_m": rest, "arm_resolved_m": resolved,
		}, {
			"target": "%s chase spring arm" % craft["node"],
			"owner": "res://scripts/ships/hero_ship.gd",
			"depth_m": required - resolved,
		})


# ----------------------------------------------------------------- report --


## Findings are grouped by craft, class, rig, lane and the node they hit. A lane
## walked at three zooms and seven boom offsets reports the same wall a hundred
## times; the group keeps the worst sample and counts the rest.
func _record(
		craft: Dictionary,
		finding: StringName,
		rig: StringName,
		sample: Dictionary,
		detail: Dictionary
	) -> void:
	var key := "%s|%s|%s|%s|%s" % [
		craft["ship_id"], finding, rig, sample.get("lane", &""), detail.get("target", ""),
	]
	var depth := float(detail.get("depth_m", 0.0))
	var group: Variant = _findings.get(key)
	if group == null:
		_findings[key] = {
			"craft": String(craft["ship_id"]),
			"berth": String(craft["berth_id"]),
			"finding": String(finding),
			"rig": String(rig),
			"lane": String(sample.get("lane", &"")),
			"target": String(detail.get("target", "")),
			"owner": String(detail.get("owner", "")),
			"module": String(detail.get("module", "")),
			"sample_count": 1,
			"aspect_bands": [String(detail.get("aspect", "16:9"))],
			"worst_depth_m": depth,
			"worst": _sample_row(sample, detail),
		}
		return
	var row := group as Dictionary
	row["sample_count"] = int(row["sample_count"]) + 1
	var band := String(detail.get("aspect", "16:9"))
	if not (row["aspect_bands"] as Array).has(band):
		(row["aspect_bands"] as Array).append(band)
	if depth > float(row["worst_depth_m"]):
		row["worst_depth_m"] = depth
		row["worst"] = _sample_row(sample, detail)


static func _sample_row(sample: Dictionary, detail: Dictionary) -> Dictionary:
	return {
		"boom": String(sample.get("boom", &"centred")),
		"attitude": String(sample.get("attitude", &"level")),
		"zoom_m": snappedf(float(sample.get("zoom", 0.0)), 0.01),
		"arm_requested_m": snappedf(float(sample.get("arm_requested_m", 0.0)), 0.01),
		"arm_resolved_m": snappedf(float(sample.get("arm_resolved_m", 0.0)), 0.01),
		"boundary_lift_m": snappedf(float(sample.get("boundary_lift_m", 0.0)), 0.001),
		"ship_origin": _vector_row(sample.get("ship_origin", Vector3.ZERO)),
		"ship_pose": _transform_row(sample.get("ship_pose", Transform3D.IDENTITY)),
		"camera": _vector_row(sample.get("camera", Vector3.ZERO)),
		"aspect": String(detail.get("aspect", "16:9")),
		"depth_m": snappedf(float(detail.get("depth_m", 0.0)), 0.001),
	}


## A finding is only actionable if a capture can stand the craft back up in
## exactly the attitude that produced it, so the whole basis travels with it as
## twelve numbers: the three basis columns then the origin.
static func _transform_row(value: Variant) -> Array:
	var pose := value as Transform3D
	var row: Array = []
	for column: Vector3 in [pose.basis.x, pose.basis.y, pose.basis.z, pose.origin]:
		row.append_array([
			snappedf(column.x, 0.00001),
			snappedf(column.y, 0.00001),
			snappedf(column.z, 0.00001),
		])
	return row


static func _aabb_row(bounds: AABB) -> Dictionary:
	return {
		"position": _vector_row(bounds.position),
		"size": _vector_row(bounds.size),
	}


static func _vector_row(value: Variant) -> Array:
	var vector := value as Vector3
	return [
		snappedf(vector.x, 0.01), snappedf(vector.y, 0.01), snappedf(vector.z, 0.01),
	]


func _build_report(world: Node3D, exit_rig: Dictionary, elapsed_ms: int) -> Dictionary:
	var rows: Array[Dictionary] = []
	for key: String in _findings:
		rows.append(_findings[key] as Dictionary)
	rows.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if not is_equal_approx(float(a["worst_depth_m"]), float(b["worst_depth_m"])):
			return float(a["worst_depth_m"]) > float(b["worst_depth_m"])
		return int(a["sample_count"]) > int(b["sample_count"])
	)
	var craft_rows: Array[Dictionary] = []
	for craft in _crafts:
		var counts: Dictionary = {}
		for row in rows:
			if row["craft"] != String(craft["ship_id"]):
				continue
			counts[row["finding"]] = int(counts.get(row["finding"], 0)) + 1
		craft_rows.append({
			"craft": String(craft["ship_id"]),
			"node": String(craft["node"]),
			"berth": String(craft["berth_id"]),
			"chase": {
				"collision_radius_m": float(craft["arm_radius"]),
				"collision_margin_m": float(craft["arm_margin"]),
				"rest_length_m": snappedf(float(craft["arm_rest"]), 0.01),
				"zoom_range_m": [float(craft["arm_minimum"]), float(craft["arm_maximum"])],
				"rotation_lag_degrees": float(craft["lag_degrees"]),
				"near_m": float(craft["chase_near"]),
				"fov_degrees": float(craft["chase_fov"]),
				"keep_height": bool(craft["chase_keep_height"]),
				"cull_mask": int(craft["chase_cull_mask"]),
				"rest_resolved_m": snappedf(float(craft.get("rest_arm_resolved_m", 0.0)), 0.01),
				"rest_required_m": snappedf(float(craft.get("rest_arm_required_m", 0.0)), 0.01),
				"live_rig_length_m": snappedf(float(craft["arm_live_length"]), 0.01),
				"simulation_disagreement_m": snappedf(
					float(craft.get("simulation_disagreement_m", 0.0)), 0.001
				),
				"samples": int(craft.get("retraction_samples", 0)),
				"retracted_samples": int(craft.get("retracted_samples", 0)),
				"shortest_resolved_m": snappedf(
					float(craft.get("shortest_arm_m", INF)), 0.01
				) if craft.has("shortest_arm_m") else -1.0,
			},
			"cockpit": {
				"present": craft["cockpit"] != null,
				"seat_local": _vector_row(craft["cockpit_local"]),
				"near_m": float(craft["cockpit_near"]),
				"fov_degrees": float(craft["cockpit_fov"]),
				"keep_height": bool(craft["cockpit_keep_height"]),
				"cull_mask": int(craft["cockpit_cull_mask"]),
			},
			"self_hull_envelope": {
				"collision_bounds": _aabb_row(craft["collision_bounds"] as AABB),
				"bounds": _aabb_row(craft["hull_bounds"] as AABB),
				"visual_lift_m": snappedf(float(craft["hull_visual_lift_m"]), 0.001),
				"renderer_count": int(craft["hull_renderers"]),
			},
			"findings": counts,
			"finding_total": _total_for(rows, String(craft["ship_id"])),
		})
	var classes: Dictionary = {}
	for row in rows:
		classes[row["finding"]] = int(classes.get(row["finding"], 0)) + 1
	return {
		"schema_version": SCHEMA_VERSION,
		"profile_id": String(PROFILE_ID),
		"generated_unix": int(Time.get_unix_time_from_system()),
		"elapsed_ms": elapsed_ms,
		"phase_ms": _phase_ms,
		"scene": "res://scenes/main.tscn",
		"world": String(world.name),
		"aspect_policy": {
			"stretch_aspect": String(ProjectSettings.get_setting(
				"display/window/stretch/aspect", "keep"
			)),
			"shipping_aspect": snappedf(SHIPPING_ASPECT, 0.001),
			"reported_ultrawide_aspect": snappedf(ULTRAWIDE_ASPECT, 0.001),
			"note": "keep pillarboxes ultrawide back to 16:9, so 32:9 rows are "
				+ "reported for the KEEP_HEIGHT policy only and are not shipping state",
		},
		"exit_rig": exit_rig,
		"coverage": {
			"crafts": _crafts.size(),
			"renderers": _instances.size(),
			"chase_samples": _chase_samples,
			"point_tests": _point_tests,
			"renderer_candidate_tests": _candidate_tests,
			"parity_evaluations": _parity_evaluations,
			"rejected_improper_poses": _improper_poses,
			"parity_self_check": _self_check,
			"assist_lane_samples": ASSIST_LANE_SAMPLES,
			"outbound_step_m": OUTBOUND_STEP_M,
			"outbound_range_m": OUTBOUND_RANGE_M,
			"skipped_batches": _skipped_batches,
			"skipped_surfaces": _skipped_surfaces,
			"shadow_only_skips": _shadow_only_skips,
		},
		"finding_classes": classes,
		"crafts": craft_rows,
		"findings": rows,
		"notes": _notes,
	}


static func _total_for(rows: Array[Dictionary], craft: String) -> int:
	var total := 0
	for row in rows:
		if row["craft"] == craft:
			total += 1
	return total


static func summary_lines(report: Dictionary) -> PackedStringArray:
	var lines := PackedStringArray()
	var coverage := report["coverage"] as Dictionary
	lines.append(
		"CAMERA_INTRUSION_AUDIT %s schema=%d craft=%d renderers=%d chase_samples=%d point_tests=%d elapsed=%dms"
		% [
			report["profile_id"], int(report["schema_version"]), int(coverage["crafts"]),
			int(coverage["renderers"]), int(coverage["chase_samples"]),
			int(coverage["point_tests"]), int(report["elapsed_ms"]),
		]
	)
	var classes := report["finding_classes"] as Dictionary
	var class_parts := PackedStringArray()
	for name: String in classes:
		class_parts.append("%s=%d" % [name, int(classes[name])])
	lines.append("CAMERA_INTRUSION_AUDIT_CLASSES %s" % (
		" ".join(class_parts) if class_parts.size() > 0 else "(none)"
	))
	for craft: Dictionary in (report["crafts"] as Array):
		var chase := craft["chase"] as Dictionary
		lines.append(
			"CAMERA_INTRUSION_CRAFT %s berth=%s findings=%d rest=%.2f/%.2fm live_delta=%.3fm radius=%.2f near=%.3f cockpit_near=%.3f samples=%d retracted=%d shortest=%.2fm hull_lift=%.3fm"
			% [
				craft["craft"], craft["berth"], int(craft["finding_total"]),
				float(chase["rest_resolved_m"]), float(chase["rest_required_m"]),
				float(chase["simulation_disagreement_m"]),
				float(chase["collision_radius_m"]), float(chase["near_m"]),
				float((craft["cockpit"] as Dictionary)["near_m"]),
				int(chase["samples"]), int(chase["retracted_samples"]),
				float(chase["shortest_resolved_m"]),
				float((craft["self_hull_envelope"] as Dictionary)["visual_lift_m"]),
			]
		)
	var shown := 0
	for row: Dictionary in (report["findings"] as Array):
		if shown >= 20:
			break
		shown += 1
		var worst := row["worst"] as Dictionary
		lines.append(
			"CAMERA_INTRUSION_FINDING %s %s rig=%s lane=%s target=%s depth=%.3fm samples=%d aspects=%s attitude=%s boom=%s zoom=%.1f at=%s owner=%s"
			% [
				row["craft"], row["finding"], row["rig"], row["lane"], row["target"],
				float(row["worst_depth_m"]), int(row["sample_count"]),
				",".join(PackedStringArray(row["aspect_bands"] as Array)),
				worst["attitude"], worst["boom"], float(worst["zoom_m"]),
				str(worst["camera"]), row["owner"],
			]
		)
	if (report["findings"] as Array).size() > shown:
		lines.append("CAMERA_INTRUSION_FINDING ... %d more in the JSON" % (
			(report["findings"] as Array).size() - shown
		))
	for note: String in (report["notes"] as PackedStringArray):
		lines.append("CAMERA_INTRUSION_NOTE %s" % note)
	return lines


# ---------------------------------------------------------------- geometry --


static func _point_aabb_distance(point: Vector3, bounds: AABB) -> float:
	var outside := Vector3(
		maxf(maxf(bounds.position.x - point.x, point.x - bounds.end.x), 0.0),
		maxf(maxf(bounds.position.y - point.y, point.y - bounds.end.y), 0.0),
		maxf(maxf(bounds.position.z - point.z, point.z - bounds.end.z), 0.0)
	)
	return outside.length()


## Negative inside the box, positive outside: the same sign convention
## `HeroShip._signed_point_aabb_clearance` uses for its boundary correction.
static func _signed_point_aabb_clearance(point: Vector3, bounds: AABB) -> float:
	var outside := _point_aabb_distance(point, bounds)
	if outside > 0.0:
		return outside
	return -_point_aabb_depth(point, bounds)


## How far inside a box the point is, used only to rank mesh findings.
static func _point_aabb_depth(point: Vector3, bounds: AABB) -> float:
	if not bounds.has_point(point):
		return 0.0
	return minf(
		minf(
			minf(point.x - bounds.position.x, bounds.end.x - point.x),
			minf(point.y - bounds.position.y, bounds.end.y - point.y)
		),
		minf(point.z - bounds.position.z, bounds.end.z - point.z)
	)


static func _is_opaque(material: Material) -> bool:
	if material == null:
		return true
	if material is BaseMaterial3D:
		var base := material as BaseMaterial3D
		if base.transparency != BaseMaterial3D.TRANSPARENCY_DISABLED:
			return false
		if base.no_depth_test:
			return false
		return base.blend_mode == BaseMaterial3D.BLEND_MODE_MIX
	if material is ShaderMaterial:
		var shader := (material as ShaderMaterial).shader
		if shader == null:
			return false
		var code := shader.code
		for marker in [
			"blend_add", "blend_sub", "blend_mul", "blend_premul_alpha",
			"depth_draw_never", "depth_test_disabled",
		]:
			if code.contains(marker):
				return false
		return true
	return false


static func _owner_script(node: Node) -> String:
	var walker: Node = node
	while walker != null:
		var script := walker.get_script() as Script
		if script != null and script.resource_path != "":
			return script.resource_path
		walker = walker.get_parent()
	return "(no script owner)"


static func _module_for(path: String) -> String:
	if path == "":
		return "(scene root)"
	var parts := path.split("/")
	if parts.size() >= 2 and parts[0] == "ShipyardWorld":
		return "%s/%s" % [parts[0], parts[1]]
	return parts[0]
