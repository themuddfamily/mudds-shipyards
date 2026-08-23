extends RefCounted

## Build-only presentation composition for StationOperationsActivity.
##
## This object never enters the scene tree. It owns per-activity construction
## caches while returning the exact materials, movers, lenses, and authored
## MultiMesh transform rosters that the activity audits and animates.

const PROFILE_FULL: StringName = &"full"
const PROFILE_GANTRY: StringName = &"gantry"
const PROFILE_SERVICE_ARM: StringName = &"service_arm"
const PROFILE_DRONE_PATROL: StringName = &"drone_patrol"
const PROFILE_CARGO_LINE: StringName = &"cargo_line"
const PROFILE_SIGNAGE_PYLON: StringName = &"signage_pylon"
const PROFILE_OBSERVATORY: StringName = &"observatory"
const PROFILE_CREW_WORKPOST: StringName = &"crew_workpost"
const PROFILE_CARGO_LINE_LONG: StringName = &"cargo_line_long"

## Service drones are deliberately nonblocking presentation. A route-height
## clearance alone cannot keep their geometry out of every player camera: the
## walking camera has user-controlled pitch and an 8 m boom, and can also start
## from elevated decks. Hide each small drone part before its surface can cross
## a camera near plane. Normal views are unaffected because the cutoff is only
## 0.65 m; at that distance the largest part (the 0.38 m-radius drone body)
## still has 0.15 m between its bounding radius and the production 0.08 m near
## plane. The hard cutoff is intentional: a dithered emissive lens can still
## paint a flashing screen-sized slice during the fade interval.
const DRONE_CAMERA_CLEARANCE_DISTANCE := 0.65

## The Aft Operations placement puts this nonblocking articulated arm directly
## behind the third-person camera at the access door. At steep downward pitch
## the boom can enter the arm even though the player's body cannot. Hide every
## animated arm part before it reaches the near plane; 1.40 m leaves at least 0.15 m
## beyond the 1.165 m half-diagonal of UpperArm plus the 0.08 m camera near
## distance. The fixed collision-backed pedestal remains visible; only the
## deliberately nonblocking animated subtree needs this camera guard.
const SERVICE_ARM_CAMERA_CLEARANCE_DISTANCE := 1.4

var _presentation_root: Node3D
var _profile_id: StringName = PROFILE_FULL
var _drone_count := 0
var _beacon_seat_height := 0.0

var _materials: Dictionary = {}
var _gantry_carriage: Node3D
var _gantry_tool: Node3D
var _service_arm_shoulder: Node3D
var _service_arm_elbow: Node3D
var _service_arm_tool: Node3D
var _drone_roots: Array[Node3D] = []
var _drone_beacon_lenses: Array[MeshInstance3D] = []
var _beacon_lenses: Array[MeshInstance3D] = []
var _station_life_movers: Array[Node3D] = []
var _station_life_lenses: Array[MeshInstance3D] = []
var _station_life_lens_specs: Array[Dictionary] = []
var _multimesh_batch_transforms: Dictionary = {}
var _rounded_box_cache: Dictionary = {}
var _chamfered_cylinder_cache: Dictionary = {}


func build(
		presentation_root: Node3D,
		profile_id: StringName,
		drone_count: int,
		beacon_seat_height: float,
		shared_material_catalog: Dictionary = {}
	) -> void:
	_presentation_root = presentation_root
	_profile_id = profile_id
	_drone_count = drone_count
	_beacon_seat_height = beacon_seat_height
	# Materials are immutable presentation recipes. The owning activity injects
	# its process-wide catalog after the first build so later placements bind the
	# same resources instead of allocating seventeen identical copies. Each
	# builder still owns its dictionary, and animated lenses only swap the
	# per-node material reference; no mutable clock or hierarchy state is shared.
	if shared_material_catalog.is_empty():
		_create_materials()
	else:
		_materials = shared_material_catalog.duplicate(false)
	if _profile_id == PROFILE_FULL or _profile_id == PROFILE_GANTRY:
		_build_gantry()
	if _profile_id == PROFILE_FULL or _profile_id == PROFILE_SERVICE_ARM:
		_build_service_arm()
	if _profile_id == PROFILE_FULL or _profile_id == PROFILE_DRONE_PATROL:
		_build_service_drones()
	match _profile_id:
		PROFILE_CARGO_LINE:
			_build_cargo_transfer_line()
		PROFILE_CARGO_LINE_LONG:
			_build_long_cargo_transfer_line()
		PROFILE_SIGNAGE_PYLON:
			_build_wayfinding_pylon()
		PROFILE_OBSERVATORY:
			_build_skywatch_post()
		PROFILE_CREW_WORKPOST:
			_build_crew_work_post()
	_build_safety_beacons()


func get_materials() -> Dictionary:
	return _materials


func get_gantry_carriage() -> Node3D:
	return _gantry_carriage


func get_gantry_tool() -> Node3D:
	return _gantry_tool


func get_service_arm_shoulder() -> Node3D:
	return _service_arm_shoulder


func get_service_arm_elbow() -> Node3D:
	return _service_arm_elbow


func get_service_arm_tool() -> Node3D:
	return _service_arm_tool


func get_drone_roots() -> Array[Node3D]:
	return _drone_roots


func get_drone_beacon_lenses() -> Array[MeshInstance3D]:
	return _drone_beacon_lenses


func get_beacon_lenses() -> Array[MeshInstance3D]:
	return _beacon_lenses


func get_station_life_movers() -> Array[Node3D]:
	return _station_life_movers


func get_station_life_lenses() -> Array[MeshInstance3D]:
	return _station_life_lenses


func get_station_life_lens_specs() -> Array[Dictionary]:
	return _station_life_lens_specs


func get_multimesh_batch_transforms() -> Dictionary:
	return _multimesh_batch_transforms


func _create_materials() -> void:
	_materials["frame"] = _material(Color("253943"), 0.72, 0.32)
	_materials["frame_edge"] = _material(Color("58717a"), 0.68, 0.27)
	_materials["graphite"] = _material(Color("121b20"), 0.48, 0.58)
	_materials["ceramic"] = _material(Color("cbd7d5"), 0.22, 0.38)
	_materials["orange"] = _material(Color("e78e37"), 0.24, 0.37)
	_materials["rubber"] = _material(Color("101619"), 0.02, 0.9)
	_materials["cyan_dim"] = _material(Color("347b80"), 0.28, 0.34, Color("20878e"), 0.35)
	_materials["cyan_lit"] = _material(Color("78f1ec"), 0.12, 0.25, Color("35d8dc"), 1.55)
	_materials["amber_dim"] = _material(Color("7c5427"), 0.18, 0.42, Color("7e421d"), 0.18)
	_materials["amber_lit"] = _material(Color("ffc069"), 0.12, 0.3, Color("ff8a2b"), 1.8)
	_materials["red_dim"] = _material(Color("632d2d"), 0.16, 0.42, Color("67201e"), 0.16)
	_materials["red_lit"] = _material(Color("ff6b60"), 0.1, 0.3, Color("ef342d"), 1.65)
	# Station-life additions. The two crate colours are painted container steel
	# and join the mapped panel family below; the green pair and the sign face are
	# lit cues and deliberately stay flat, exactly as the amber/cyan/red pairs do.
	_materials["crate"] = _material(Color("2f6f63"), 0.44, 0.46)
	_materials["crate_alt"] = _material(Color("a8552f"), 0.4, 0.5)
	_materials["green_dim"] = _material(Color("2c5f3a"), 0.2, 0.42, Color("1f7a3c"), 0.2)
	_materials["green_lit"] = _material(Color("8ef2a8"), 0.1, 0.3, Color("34d566"), 1.5)
	_materials["sign_lit"] = _material(Color("e8f2ef"), 0.08, 0.28, Color("cfe6df"), 1.15)
	_apply_station_panel_family()


## Bind the registered station panel/normal/roughness recipe to this component's
## structural greys.
##
## Before this pass the operations equipment was the only lattice population with
## no mapped surface at all: flat scalar albedo on hard-edged primitives standing
## on decks that are visibly plated. The recipe, its `normal_scale`, its
## red-channel roughness, its world-triplanar mode and its sharpness are copied
## verbatim from `AftJunctionStack`, including that module's 0.30 physical scale,
## so a gantry column is stamped from the same plate stock as the deck under it
## rather than acquiring a look of its own. Painted hazard bands, tyre rubber and
## the emissive lenses stay unmapped, exactly as the sibling modules leave their
## accent and light materials unmapped.
func _apply_station_panel_family() -> void:
	var panel_albedo := load("res://assets/materials/procedural-panel-triplanar-albedo-v2.png") as Texture2D
	var panel_normal := load("res://assets/materials/procedural-panel-triplanar-normal-v2.png") as Texture2D
	var panel_roughness := load("res://assets/materials/procedural-panel-triplanar-roughness-v2.png") as Texture2D
	if panel_albedo == null or panel_normal == null or panel_roughness == null:
		return
	for key in ["frame", "frame_edge", "graphite", "ceramic", "crate", "crate_alt"]:
		var panel_material := _materials[key] as StandardMaterial3D
		panel_material.albedo_texture = panel_albedo
		panel_material.normal_enabled = true
		panel_material.normal_texture = panel_normal
		# Raised from 0.48 by a rendered sweep at 0.48 / 1.0 / 1.4 / 1.9. At 0.48 a
		# plated wall at eye height is nearly featureless: the seams and rivets are
		# present in the map but too shallow to catch light, which is much of why
		# plated geometry still read as untextured. At 1.9 the plate faces dome and
		# read as embossed plastic, worst on the bright pod walls. 1.0 is the highest
		# value at which no frame showed doming while the dark walls resolved into
		# pressed sheet metal. Every module shares the value so a deck and the wall
		# beside it cannot disagree.
		panel_material.normal_scale = 1.0
		panel_material.roughness_texture = panel_roughness
		panel_material.roughness_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_RED
		panel_material.uv1_triplanar = true
		panel_material.uv1_world_triplanar = true
		panel_material.uv1_triplanar_sharpness = 4.0
		panel_material.uv1_scale = Vector3(0.3, 0.3, 0.3)
		panel_material.texture_repeat = true


func _build_gantry() -> void:
	var gantry := Node3D.new()
	gantry.name = "MaintenanceGantry"
	_presentation_root.add_child(gantry)
	var safety_band_transforms: Array[Transform3D] = []
	for x_side in [-1.0, 1.0]:
		for z_side in [-1.0, 1.0]:
			var x: float = float(x_side) * 4.3
			var z: float = float(z_side) * 2.72
			_box(gantry, "FootPad", Vector3(x, 0.11, z), Vector3(0.92, 0.22, 1.05), _materials["graphite"])
			# Recorded in `bugs.md` as an unconfirmed observation and confirmed here:
			# the column stopped at y = 5.53 while `OverheadRail` starts at y = 5.61,
			# so the rail pair and `BridgeBeam` hung as one rigid unit 0.08 m clear of
			# all four columns with nothing joining them. The column is lengthened by
			# exactly that 0.08 m to meet the rail underside. The rail, the carriage
			# travel (`GANTRY_ELEVATION`) and the footprint are unchanged.
			_box(gantry, "Column", Vector3(x, 2.86, z), Vector3(0.42, 5.5, 0.5), _materials["frame"])
			_box(gantry, "ColumnEdge", Vector3(x - x_side * 0.19, 2.82, z), Vector3(0.055, 5.0, 0.34), _materials["frame_edge"])
			safety_band_transforms.append(Transform3D(
				Basis.IDENTITY, Vector3(x, 0.72, z - z_side * 0.27)
			))
	# The band leaves are repeated, childless warning-colour trim. Foot pads keep
	# their support-test paths, columns keep world collision authority, and the
	# individually named column edges remain available to obstruction captures.
	# One fixed batch retains the exact four band transforms and visible copies.
	var safety_bands := _box_batch(
		gantry,
		"SafetyBands",
		Vector3(0.5, 0.28, 0.06),
		safety_band_transforms,
		_materials["orange"]
	)
	safety_bands.multimesh.custom_aabb = _transformed_mesh_bounds(
		safety_bands.multimesh.mesh.get_aabb(), safety_band_transforms
	)
	safety_bands.set_meta("explicit_authored_bounds", true)
	safety_bands.set_meta("authored_visual_names", PackedStringArray([
		"SafetyBand", "SafetyBand2", "SafetyBand3", "SafetyBand4",
	]))
	for z_side in [-1.0, 1.0]:
		_box(gantry, "OverheadRail", Vector3(0.0, 5.82, z_side * 2.72), Vector3(9.08, 0.42, 0.48), _materials["frame"])
		_box(gantry, "RailFace", Vector3(0.0, 5.83, z_side * 2.46), Vector3(8.55, 0.17, 0.055), _materials["frame_edge"])
	var rail_fastener_transforms: Array[Transform3D] = []
	for z_side in [-1.0, 1.0]:
		for x in [-3.15, -1.05, 1.05, 3.15]:
			rail_fastener_transforms.append(Transform3D(
				Basis.IDENTITY, Vector3(x, 5.83, z_side * 2.42)
			))
	# These eight childless decorative fasteners share one exact mesh, material,
	# layer and shadow contract. The stable MaintenanceGantry/OverheadRail anchors
	# remain ordinary nodes; only their unaddressed visual leaves become one draw.
	var rail_fasteners := _box_batch(
		gantry, "RailFasteners", Vector3(0.13, 0.13, 0.07),
		rail_fastener_transforms, _materials["orange"]
	)
	rail_fasteners.multimesh.custom_aabb = _transformed_mesh_bounds(
		rail_fasteners.multimesh.mesh.get_aabb(), rail_fastener_transforms
	)
	rail_fasteners.set_meta("explicit_authored_bounds", true)
	rail_fasteners.set_meta("authored_visual_names", PackedStringArray([
		"RailFastener", "RailFastener2", "RailFastener3", "RailFastener4",
		"RailFastener5", "RailFastener6", "RailFastener7", "RailFastener8",
	]))
	_box(gantry, "BridgeBeam", Vector3(0.0, 5.65, 0.0), Vector3(0.34, 0.32, 5.25), _materials["frame_edge"])

	_gantry_carriage = Node3D.new()
	_gantry_carriage.name = "AnimatedGantryCarriage"
	gantry.add_child(_gantry_carriage)
	_box(_gantry_carriage, "CarriageBody", Vector3.ZERO, Vector3(1.45, 0.48, 1.16), _materials["ceramic"])
	_box(_gantry_carriage, "CarriageCore", Vector3(0.0, -0.28, 0.0), Vector3(0.78, 0.3, 0.72), _materials["graphite"])
	for x_side in [-1.0, 1.0]:
		for z_side in [-1.0, 1.0]:
			_cylinder(_gantry_carriage, "GuideWheel", Vector3(x_side * 0.58, 0.22, z_side * 0.52), 0.16, 0.12, _materials["rubber"], Vector3(90, 0, 0))

	_gantry_tool = Node3D.new()
	_gantry_tool.name = "TelescopingServiceTool"
	_gantry_carriage.add_child(_gantry_tool)
	_cylinder(_gantry_tool, "OuterRam", Vector3(0.0, -0.58, 0.0), 0.18, 1.05, _materials["frame_edge"])
	_cylinder(_gantry_tool, "InnerRam", Vector3(0.0, -1.12, 0.0), 0.1, 0.72, _materials["ceramic"])
	_cylinder(_gantry_tool, "ToolCollar", Vector3(0.0, -1.49, 0.0), 0.28, 0.19, _materials["orange"])
	_box(_gantry_tool, "ScannerHead", Vector3(0.0, -1.68, 0.0), Vector3(0.68, 0.22, 0.46), _materials["graphite"])
	_box(_gantry_tool, "ScannerLens", Vector3(0.0, -1.81, -0.01), Vector3(0.42, 0.045, 0.24), _materials["cyan_lit"])


func _build_service_arm() -> void:
	var base := Node3D.new()
	base.name = "ArticulatedServiceArm"
	base.position = Vector3(3.72, 0.0, -2.05) if _profile_id == PROFILE_FULL else Vector3.ZERO
	_presentation_root.add_child(base)
	_cylinder(base, "BasePlate", Vector3(0.0, 0.16, 0.0), 0.65, 0.32, _materials["graphite"])
	_cylinder(base, "RotaryBase", Vector3(0.0, 0.48, 0.0), 0.43, 0.46, _materials["frame_edge"])

	_service_arm_shoulder = Node3D.new()
	_service_arm_shoulder.name = "AnimatedShoulder"
	_service_arm_shoulder.position = Vector3(0.0, 0.72, 0.0)
	base.add_child(_service_arm_shoulder)
	_cylinder(_service_arm_shoulder, "ShoulderJoint", Vector3.ZERO, 0.42, 0.62, _materials["orange"], Vector3(90, 0, 0))
	_box(_service_arm_shoulder, "UpperArm", Vector3(-0.05, 1.13, 0.0), Vector3(0.46, 2.22, 0.52), _materials["ceramic"])
	_box(_service_arm_shoulder, "UpperArmInset", Vector3(-0.05, 1.13, -0.275), Vector3(0.22, 1.7, 0.035), _materials["frame_edge"])

	_service_arm_elbow = Node3D.new()
	_service_arm_elbow.name = "AnimatedElbow"
	_service_arm_elbow.position = Vector3(-0.05, 2.23, 0.0)
	_service_arm_shoulder.add_child(_service_arm_elbow)
	_cylinder(_service_arm_elbow, "ElbowJoint", Vector3.ZERO, 0.34, 0.62, _materials["graphite"], Vector3(90, 0, 0))
	_box(_service_arm_elbow, "Forearm", Vector3(0.0, 0.83, 0.0), Vector3(0.36, 1.62, 0.44), _materials["frame_edge"])

	_service_arm_tool = Node3D.new()
	_service_arm_tool.name = "AnimatedToolHead"
	_service_arm_tool.position = Vector3(0.0, 1.65, 0.0)
	_service_arm_elbow.add_child(_service_arm_tool)
	_cylinder(_service_arm_tool, "ToolWrist", Vector3.ZERO, 0.24, 0.42, _materials["orange"], Vector3(90, 0, 0))
	_box(_service_arm_tool, "ToolHousing", Vector3(0.0, 0.26, 0.0), Vector3(0.62, 0.34, 0.72), _materials["graphite"])
	for x_side in [-1.0, 1.0]:
		_box(_service_arm_tool, "DiagnosticFork", Vector3(x_side * 0.23, 0.62, 0.0), Vector3(0.12, 0.62, 0.16), _materials["cyan_dim"])
	for candidate in _service_arm_shoulder.find_children("*", "MeshInstance3D", true, false):
		var arm_mesh := candidate as MeshInstance3D
		arm_mesh.visibility_range_begin = SERVICE_ARM_CAMERA_CLEARANCE_DISTANCE
		arm_mesh.visibility_range_begin_margin = 0.0
		arm_mesh.visibility_range_fade_mode = (
			GeometryInstance3D.VISIBILITY_RANGE_FADE_DISABLED
		)


func _build_service_drones() -> void:
	for index in _drone_count:
		var drone := Node3D.new()
		drone.name = "AnimatedServiceDrone%02d" % (index + 1)
		_presentation_root.add_child(drone)
		_drone_roots.append(drone)
		_cylinder(drone, "Body", Vector3.ZERO, 0.38, 0.34, _materials["ceramic"])
		_cylinder(drone, "LowerRing", Vector3(0.0, -0.2, 0.0), 0.31, 0.11, _materials["frame_edge"])
		_box(drone, "CargoPod", Vector3(0.0, -0.42, 0.0), Vector3(0.58, 0.33, 0.48), _materials["graphite"])
		for x_side in [-1.0, 1.0]:
			_box(drone, "ThrusterArm", Vector3(x_side * 0.48, 0.0, 0.0), Vector3(0.5, 0.1, 0.13), _materials["frame_edge"])
			_cylinder(drone, "Thruster", Vector3(x_side * 0.73, 0.0, 0.0), 0.14, 0.18, _materials["graphite"])
			_box(drone, "ThrusterGlow", Vector3(x_side * 0.73, -0.105, 0.0), Vector3(0.13, 0.035, 0.13), _materials["cyan_lit"])
		var lens := _box(drone, "NavigationLens", Vector3(0.0, 0.03, -0.39), Vector3(0.28, 0.12, 0.055), _materials["cyan_lit"])
		_drone_beacon_lenses.append(lens)
		for candidate in drone.find_children("*", "MeshInstance3D", true, false):
			var drone_mesh := candidate as MeshInstance3D
			drone_mesh.visibility_range_begin = DRONE_CAMERA_CLEARANCE_DISTANCE
			drone_mesh.visibility_range_begin_margin = 0.0
			drone_mesh.visibility_range_fade_mode = (
				GeometryInstance3D.VISIBILITY_RANGE_FADE_DISABLED
			)


## Cargo movement: a short fixed transfer rail with a powered container sled, an
## overhead hoist working the same line, two palletised crate stacks and a
## control pedestal. Nothing here routes, reserves or carries anything; the sled
## and the hoist are closed-form functions of the clock like every other mover in
## this component.
func _build_cargo_transfer_line() -> void:
	var line := Node3D.new()
	line.name = "CargoTransferLine"
	_presentation_root.add_child(line)

	for z_side in [-1.0, 1.0]:
		_box(line, "RailBeam", Vector3(0.0, 0.16, z_side * 0.62), Vector3(8.6, 0.14, 0.28), _materials["frame_edge"])
	# Instanced without moving anything. The five ties keep the same mesh, sizes,
	# positions and material they were drawn with; what changes is that they are
	# one draw submission instead of five. Only stock that is never given
	# collision is instanced — see `get_solid_volume_contract()` for why.
	var tie_transforms: Array[Transform3D] = []
	for x in [-3.6, -1.8, 0.0, 1.8, 3.6]:
		tie_transforms.append(Transform3D(Basis.IDENTITY, Vector3(x, 0.07, 0.0)))
	_box_batch(line, "RailTies", Vector3(0.5, 0.14, 1.9), tie_transforms, _materials["graphite"])
	for x_side in [-1.0, 1.0]:
		_box(line, "RailStop", Vector3(x_side * 4.34, 0.26, 0.0), Vector3(0.24, 0.52, 1.7), _materials["orange"])

	_box(line, "PalletDeckPort", Vector3(-2.9, 0.09, 1.85), Vector3(2.3, 0.18, 1.25), _materials["graphite"])
	_box(line, "CrateLower", Vector3(-3.4, 0.55, 1.85), Vector3(1.05, 0.74, 1.0), _materials["crate"])
	_box(line, "CrateLowerAlt", Vector3(-2.35, 0.55, 1.85), Vector3(0.95, 0.74, 1.0), _materials["crate_alt"])
	_box(line, "CrateUpper", Vector3(-2.9, 1.24, 1.85), Vector3(1.5, 0.64, 1.05), _materials["crate"])
	_box(line, "CrateManifest", Vector3(-2.9, 1.3, 1.33), Vector3(0.62, 0.2, 0.04), _materials["sign_lit"])

	_box(line, "PalletDeckStarboard", Vector3(3.0, 0.09, -1.9), Vector3(2.0, 0.18, 1.2), _materials["graphite"])
	_box(line, "CrateOutbound", Vector3(2.65, 0.52, -1.9), Vector3(1.1, 0.68, 0.98), _materials["crate_alt"])
	_box(line, "CrateOutboundSmall", Vector3(3.62, 0.44, -1.9), Vector3(0.7, 0.52, 0.8), _materials["crate"])

	var band_transforms: Array[Transform3D] = []
	for z_side in [-1.0, 1.0]:
		_box(line, "HoistPost", Vector3(0.0, 1.45, z_side * 1.55), Vector3(0.26, 2.9, 0.3), _materials["frame"])
		band_transforms.append(Transform3D(Basis.IDENTITY, Vector3(0.0, 0.6, z_side * 1.55)))
	_box_batch(line, "HoistPostBands", Vector3(0.3, 0.22, 0.34), band_transforms, _materials["orange"])
	_box(line, "HoistBeam", Vector3(0.0, 2.78, 0.0), Vector3(0.3, 0.26, 3.4), _materials["frame_edge"])

	_cylinder(line, "ControlPedestal", Vector3(-4.15, 0.5, -1.7), 0.22, 1.0, _materials["frame_edge"])
	_box(line, "ControlHousing", Vector3(-4.15, 1.08, -1.7), Vector3(0.5, 0.3, 0.36), _materials["graphite"])
	var readout := _box(line, "ControlReadout", Vector3(-4.15, 1.2, -1.89), Vector3(0.36, 0.16, 0.04), _materials["green_dim"])

	var sled := _add_station_life_mover(line, "AnimatedCargoSled")
	_box(sled, "SledDeck", Vector3.ZERO, Vector3(1.9, 0.2, 1.5), _materials["frame_edge"])
	_box(sled, "SledSkirt", Vector3(0.0, -0.13, 0.0), Vector3(1.7, 0.1, 1.3), _materials["graphite"])
	var wheel_transforms: Array[Transform3D] = []
	for x_side in [-1.0, 1.0]:
		for z_side in [-1.0, 1.0]:
			wheel_transforms.append(Transform3D(
				Basis.from_euler(Vector3(deg_to_rad(90.0), 0.0, 0.0)),
				Vector3(x_side * 0.72, -0.14, z_side * 0.62)
			))
	_cylinder_batch(sled, "SledWheels", 0.13, 0.1, wheel_transforms, _materials["rubber"])
	_box(sled, "SledContainer", Vector3(0.0, 0.6, 0.0), Vector3(1.7, 1.0, 1.35), _materials["crate"])
	var rib_transforms: Array[Transform3D] = []
	for x in [-0.5, 0.5]:
		rib_transforms.append(Transform3D(Basis.IDENTITY, Vector3(x, 0.6, 0.0)))
	_box_batch(sled, "ContainerRibs", Vector3(0.08, 0.98, 1.37), rib_transforms, _materials["crate_alt"])
	_box(sled, "ContainerManifest", Vector3(0.0, 0.88, -0.69), Vector3(0.7, 0.22, 0.04), _materials["sign_lit"])
	var strobe := _box(sled, "SledStrobe", Vector3(0.0, 1.15, 0.0), Vector3(0.3, 0.1, 0.3), _materials["amber_dim"])

	var hoist := _add_station_life_mover(line, "AnimatedCargoHoist")
	_box(hoist, "HoistCarriage", Vector3.ZERO, Vector3(0.62, 0.22, 0.7), _materials["ceramic"])
	_cylinder(hoist, "HoistCable", Vector3(0.0, -0.45, 0.0), 0.035, 0.7, _materials["graphite"])
	_box(hoist, "HoistHook", Vector3(0.0, -0.86, 0.0), Vector3(0.3, 0.24, 0.3), _materials["orange"])

	_register_station_life_lens(strobe, "amber_dim", "amber_lit", 1.6, 0.3, 0.0)
	_register_station_life_lens(readout, "green_dim", "green_lit", 2.4, 1.5, 0.7)


## The same beat over a real distance: a 21.6 m transfer run with a container
## sled that travels 19.2 m of it, a full-length overhead hoist gantry with a
## bridge that tracks the whole rail, palletised stacks at both ends and a control
## pedestal.
##
## Everything repeated is instanced. Twelve rail ties, four gantry posts, four
## post bands, five crates, four alternate crates, four sled wheels and two
## container ribs are 35 bodies drawn in 7 `MultiMeshInstance3D` batches, so the
## whole run costs 36 draw submissions rather than 71. That is the difference
## between two of these fitting the whole-scene draw ceiling and neither doing so;
## see `docs/PERFORMANCE_BUDGET_SCENE_GEOMETRY.md`.
##
## Every seat is deliberate and every one of them was checked in a render at four
## points along the sled's travel, because the defects this family produced last
## time — a hoist carriage leaving its own beam, a sled sinking through its rail —
## were invisible at rest:
##   * sled wheel treads meet the rail heads at y = 0.23, so the sled rides at
##     y = 0.50 exactly as the short line's does;
##   * the travelling bridge's top overlaps the hoist rail underside, so it can
##     never separate from the rail it hangs on;
##   * the hook's lowest point clears the sled container's roof by 0.13 m at
##     every phase of both movers, so the two can cross without intersecting;
##   * every crate rests on the pallet deck or on the crate below it.
func _build_long_cargo_transfer_line() -> void:
	var line := Node3D.new()
	line.name = "LongCargoTransferLine"
	_presentation_root.add_child(line)

	for z_side in [-1.0, 1.0]:
		_box(line, "RailBeam", Vector3(0.0, 0.16, z_side * 0.62), Vector3(21.6, 0.14, 0.28), _materials["frame_edge"])
	var tie_transforms: Array[Transform3D] = []
	for index in 12:
		tie_transforms.append(
			Transform3D(Basis.IDENTITY, Vector3(-9.9 + float(index) * 1.8, 0.07, 0.0))
		)
	_box_batch(line, "RailTies", Vector3(0.5, 0.14, 1.9), tie_transforms, _materials["graphite"])
	for x_side in [-1.0, 1.0]:
		_box(line, "RailStop", Vector3(x_side * 11.0, 0.26, 0.0), Vector3(0.24, 0.52, 1.7), _materials["orange"])

	# Overhead gantry. The post heads reach y = 2.90 and the rail undersides sit
	# at y = 2.76, so the rails bear on the posts rather than hanging beside them.
	# The posts are drawn individually and not instanced, because they are solid
	# and every solid volume has to be a `MeshInstance3D` the station's
	# collision-without-geometry sweep can see.
	#
	# They stand at x = +/-10.4, outboard of both crate stacks. At the more
	# natural-looking 9.6 a post ran straight down through the inbound stack; the
	# clearance probe in `tools/cargo_line_travel_probe.gd` is what reports that.
	var band_transforms: Array[Transform3D] = []
	for x_side in [-1.0, 1.0]:
		for z_side in [-1.0, 1.0]:
			_box(
				line,
				"HoistPost",
				Vector3(x_side * 10.4, 1.45, z_side * 1.35),
				Vector3(0.26, 2.9, 0.3),
				_materials["frame"]
			)
			band_transforms.append(
				Transform3D(Basis.IDENTITY, Vector3(x_side * 10.4, 0.6, z_side * 1.35))
			)
	_box_batch(line, "HoistPostBands", Vector3(0.3, 0.22, 0.34), band_transforms, _materials["orange"])
	for z_side in [-1.0, 1.0]:
		_box(line, "HoistRail", Vector3(0.0, 2.86, z_side * 1.35), Vector3(21.2, 0.2, 0.26), _materials["frame_edge"])

	# Inbound stack. Two crates on the pallet deck and one wide crate bridging
	# both of them, so every box rests on the box or the deck below it. The stacks
	# are 0.8 m deep and set at z = +/-1.30, which leaves the sled's 1.5 m body a
	# 0.15 m lane past them; at 0.95 m deep the sled's container clipped the
	# manifest plate by a centimetre on every pass.
	_box(line, "PalletDeckInbound", Vector3(-8.6, 0.09, 1.3), Vector3(3.2, 0.18, 0.8), _materials["graphite"])
	_box(line, "CrateInboundPort", Vector3(-9.5, 0.54, 1.3), Vector3(1.0, 0.72, 0.8), _materials["crate"])
	_box(line, "CrateInboundStarboard", Vector3(-7.9, 0.54, 1.3), Vector3(1.0, 0.72, 0.8), _materials["crate_alt"])
	_box(line, "CrateInboundTop", Vector3(-8.7, 1.19, 1.3), Vector3(1.5, 0.6, 0.8), _materials["crate"])
	_box(line, "CrateManifest", Vector3(-8.7, 1.25, 0.88), Vector3(0.62, 0.2, 0.04), _materials["sign_lit"])

	_box(line, "PalletDeckOutbound", Vector3(8.2, 0.09, -1.3), Vector3(2.8, 0.18, 0.8), _materials["graphite"])
	_box(line, "CrateOutboundPort", Vector3(7.5, 0.54, -1.3), Vector3(0.9, 0.72, 0.8), _materials["crate_alt"])
	_box(line, "CrateOutboundStarboard", Vector3(8.9, 0.54, -1.3), Vector3(1.0, 0.72, 0.8), _materials["crate"])
	_box(line, "CrateOutboundTop", Vector3(8.2, 1.19, -1.3), Vector3(1.3, 0.6, 0.8), _materials["crate_alt"])

	# Mid-run, on the apron side. Every outboard position collided with something
	# that has to be there: at x = -11.0 with the corner beacon, at x = -10.2 with
	# the gantry post.
	_cylinder(line, "ControlPedestal", Vector3(-6.0, 0.5, -1.15), 0.22, 1.0, _materials["frame_edge"])
	_box(line, "ControlHousing", Vector3(-6.0, 1.08, -1.15), Vector3(0.5, 0.3, 0.36), _materials["graphite"])
	var readout := _box(line, "ControlReadout", Vector3(-6.0, 1.2, -1.34), Vector3(0.36, 0.16, 0.04), _materials["green_dim"])

	var sled := _add_station_life_mover(line, "AnimatedLongCargoSled")
	_box(sled, "SledDeck", Vector3.ZERO, Vector3(1.9, 0.2, 1.5), _materials["frame_edge"])
	_box(sled, "SledSkirt", Vector3(0.0, -0.13, 0.0), Vector3(1.7, 0.1, 1.3), _materials["graphite"])
	var wheel_transforms: Array[Transform3D] = []
	for x_side in [-1.0, 1.0]:
		for z_side in [-1.0, 1.0]:
			wheel_transforms.append(Transform3D(
				Basis.from_euler(Vector3(deg_to_rad(90.0), 0.0, 0.0)),
				Vector3(x_side * 0.72, -0.14, z_side * 0.62)
			))
	_cylinder_batch(sled, "SledWheels", 0.13, 0.1, wheel_transforms, _materials["rubber"])
	_box(sled, "SledContainer", Vector3(0.0, 0.6, 0.0), Vector3(1.7, 1.0, 1.35), _materials["crate"])
	var rib_transforms: Array[Transform3D] = []
	for x in [-0.5, 0.5]:
		rib_transforms.append(Transform3D(Basis.IDENTITY, Vector3(x, 0.6, 0.0)))
	_box_batch(sled, "ContainerRibs", Vector3(0.08, 0.98, 1.37), rib_transforms, _materials["crate_alt"])
	_box(sled, "ContainerManifest", Vector3(0.0, 0.88, -0.69), Vector3(0.7, 0.22, 0.04), _materials["sign_lit"])
	var strobe := _box(sled, "SledStrobe", Vector3(0.0, 1.15, 0.0), Vector3(0.3, 0.1, 0.3), _materials["amber_dim"])

	var hoist := _add_station_life_mover(line, "AnimatedLongCargoHoist")
	_box(hoist, "HoistBridge", Vector3.ZERO, Vector3(0.34, 0.28, 3.1), _materials["frame_edge"])
	_box(hoist, "HoistCarriage", Vector3(0.0, -0.2, 0.0), Vector3(0.62, 0.22, 0.7), _materials["ceramic"])
	_cylinder(hoist, "HoistCable", Vector3(0.0, -0.335, 0.0), 0.035, 0.39, _materials["graphite"])
	_box(hoist, "HoistHook", Vector3(0.0, -0.68, 0.0), Vector3(0.3, 0.3, 0.3), _materials["orange"])

	_register_station_life_lens(strobe, "amber_dim", "amber_lit", 1.6, 0.3, 0.0)
	_register_station_life_lens(readout, "green_dim", "green_lit", 2.4, 1.5, 0.7)


## Signage variety: a wayfinding pylon with a lit board, a bay plaque, a printed
## notice rack, a chasing chevron strip and a slowly rotating identifier drum.
func _build_wayfinding_pylon() -> void:
	var pylon := Node3D.new()
	pylon.name = "WayfindingPylon"
	_presentation_root.add_child(pylon)

	_box(pylon, "BasePlinth", Vector3(0.0, 0.13, 0.0), Vector3(1.5, 0.26, 1.2), _materials["graphite"])
	_box(pylon, "BaseHazardBand", Vector3(0.0, 0.31, 0.0), Vector3(1.54, 0.1, 1.24), _materials["orange"])
	_box(pylon, "Mast", Vector3(0.0, 2.08, 0.0), Vector3(0.44, 3.64, 0.44), _materials["frame"])
	for z_side in [-1.0, 1.0]:
		_box(pylon, "MastEdge", Vector3(0.0, 2.1, z_side * 0.21), Vector3(0.34, 3.3, 0.04), _materials["frame_edge"])

	_box(pylon, "SignBoard", Vector3(0.0, 3.0, 0.28), Vector3(1.7, 1.15, 0.12), _materials["graphite"])
	_box(pylon, "SignFace", Vector3(0.0, 3.0, 0.35), Vector3(1.55, 1.0, 0.04), _materials["sign_lit"])
	_box(pylon, "SignRule", Vector3(0.0, 3.02, 0.375), Vector3(1.4, 0.06, 0.02), _materials["graphite"])

	_box(pylon, "ChevronRail", Vector3(0.0, 2.15, 0.26), Vector3(1.9, 0.5, 0.1), _materials["graphite"])
	for index in 5:
		var chevron := _box(
			pylon,
			"Chevron",
			Vector3(-0.72 + float(index) * 0.36, 2.15, 0.305),
			Vector3(0.22, 0.36, 0.05),
			_materials["amber_dim"]
		)
		# A chase, not a blink: each chevron lights 0.16 s after the one behind
		# it, so the strip reads as pointing somewhere.
		_register_station_life_lens(chevron, "amber_dim", "amber_lit", 1.5, 0.34, float(index) * -0.16)

	_box(pylon, "BayPlaque", Vector3(0.0, 1.2, 0.25), Vector3(0.9, 0.42, 0.08), _materials["frame_edge"])
	_box(pylon, "BayGlyph", Vector3(0.0, 1.2, 0.3), Vector3(0.7, 0.28, 0.03), _materials["amber_lit"])

	_box(pylon, "NoticeBoard", Vector3(0.0, 1.5, -0.265), Vector3(1.1, 0.7, 0.09), _materials["graphite"])
	for index in 3:
		_box(pylon, "NoticeSheet", Vector3(-0.32 + float(index) * 0.32, 1.5, -0.325), Vector3(0.26, 0.5, 0.03), _materials["ceramic"])

	var drum := _add_station_life_mover(pylon, "AnimatedIdentifierDrum")
	_cylinder(drum, "DrumBody", Vector3.ZERO, 0.42, 0.5, _materials["ceramic"])
	_cylinder(drum, "DrumBand", Vector3(0.0, -0.16, 0.0), 0.44, 0.12, _materials["frame_edge"])
	for z_side in [-1.0, 1.0]:
		_box(drum, "DrumGlyph", Vector3(0.0, 0.02, z_side * 0.41), Vector3(0.5, 0.3, 0.04), _materials["cyan_lit"])
	_cylinder(drum, "DrumCap", Vector3(0.0, 0.29, 0.0), 0.3, 0.08, _materials["graphite"])


## Observatory beat: a three-legged skywatch post whose yoke pans and whose optic
## tube elevates, with a lit aperture that pulses while it is tracking and a
## instrument cabinet at deck level.
func _build_skywatch_post() -> void:
	var post := Node3D.new()
	post.name = "SkywatchPost"
	_presentation_root.add_child(post)

	for index in 3:
		var angle := float(index) * TAU / 3.0
		var leg_x := cos(angle) * 1.05
		var leg_z := sin(angle) * 1.05
		_box(post, "LegFoot", Vector3(leg_x, 0.09, leg_z), Vector3(0.52, 0.18, 0.52), _materials["graphite"])
		_box(post, "LegColumn", Vector3(leg_x, 0.72, leg_z), Vector3(0.24, 1.28, 0.24), _materials["frame"])
		_box(
			post,
			"MountRib",
			Vector3(cos(angle) * 0.6, 1.44, sin(angle) * 0.6),
			Vector3(0.9, 0.16, 0.18),
			_materials["frame_edge"],
			Vector3(0.0, -rad_to_deg(angle), 0.0)
		)
	_cylinder(post, "MountRing", Vector3(0.0, 1.44, 0.0), 1.15, 0.22, _materials["frame_edge"])
	_cylinder(post, "Pedestal", Vector3(0.0, 1.78, 0.0), 0.5, 0.5, _materials["frame"])

	_box(post, "InstrumentCabinet", Vector3(1.5, 0.525, -1.0), Vector3(0.8, 1.05, 0.6), _materials["ceramic"])
	_box(post, "CabinetScreen", Vector3(1.5, 0.72, -1.31), Vector3(0.55, 0.42, 0.04), _materials["cyan_lit"])
	_box(post, "CabinetVent", Vector3(1.5, 0.35, -1.31), Vector3(0.5, 0.2, 0.03), _materials["graphite"])
	_box(post, "ConduitRun", Vector3(0.75, 0.06, -0.8), Vector3(1.5, 0.12, 0.14), _materials["graphite"], Vector3(0.0, 35.0, 0.0))

	var yoke := _add_station_life_mover(post, "AnimatedSkywatchYoke")
	_cylinder(yoke, "YokeBase", Vector3.ZERO, 0.42, 0.28, _materials["frame_edge"])
	for x_side in [-1.0, 1.0]:
		_box(yoke, "YokeArm", Vector3(x_side * 0.62, 0.55, 0.0), Vector3(0.16, 0.95, 0.34), _materials["ceramic"])
	_box(yoke, "YokeCap", Vector3(0.0, 1.02, 0.0), Vector3(1.4, 0.14, 0.3), _materials["frame_edge"])

	var tube := _add_station_life_mover(yoke, "AnimatedOpticTube")
	_cylinder(tube, "TubeBody", Vector3.ZERO, 0.3, 1.7, _materials["ceramic"], Vector3(90, 0, 0))
	_cylinder(tube, "TubeCollar", Vector3(0.0, 0.0, 0.55), 0.34, 0.16, _materials["orange"], Vector3(90, 0, 0))
	_cylinder(tube, "Aperture", Vector3(0.0, 0.0, -0.88), 0.28, 0.08, _materials["graphite"], Vector3(90, 0, 0))
	var optic := _cylinder(tube, "OpticLens", Vector3(0.0, 0.0, -0.94), 0.22, 0.05, _materials["cyan_dim"], Vector3(90, 0, 0))
	_cylinder(tube, "Counterweight", Vector3(0.0, 0.0, 0.92), 0.24, 0.3, _materials["graphite"], Vector3(90, 0, 0))
	_cylinder(tube, "FinderScope", Vector3(0.0, 0.34, -0.2), 0.08, 0.6, _materials["frame_edge"], Vector3(90, 0, 0))

	_register_station_life_lens(optic, "cyan_dim", "cyan_lit", 3.4, 2.1, 0.0)


## Crew activity: a work post someone plainly uses. Bench, vice, parts bins, a
## tool wall, a task lamp, a cable drum, supply crates, a hard hat left on the
## bench, an indexing tool carousel and a nodding weld jig with a flickering arc.
func _build_crew_work_post() -> void:
	var post := Node3D.new()
	post.name = "CrewWorkPost"
	_presentation_root.add_child(post)

	_box(post, "BenchTop", Vector3(-0.9, 0.92, 0.55), Vector3(2.6, 0.12, 0.9), _materials["ceramic"])
	_box(post, "BenchApron", Vector3(-0.9, 0.8, 0.96), Vector3(2.5, 0.14, 0.06), _materials["frame_edge"])
	for x_side in [-1.0, 1.0]:
		for z_side in [-1.0, 1.0]:
			_box(post, "BenchLeg", Vector3(-0.9 + x_side * 1.15, 0.43, 0.55 + z_side * 0.32), Vector3(0.12, 0.86, 0.12), _materials["frame"])
	_box(post, "BenchShelf", Vector3(-0.9, 0.3, 0.55), Vector3(2.3, 0.06, 0.7), _materials["graphite"])
	for index in 3:
		_box(post, "PartsBin", Vector3(-1.7 + float(index) * 0.8, 0.45, 0.55), Vector3(0.6, 0.24, 0.5), _materials["orange"])
	_box(post, "BenchVice", Vector3(-1.85, 1.08, 0.55), Vector3(0.28, 0.2, 0.3), _materials["graphite"])
	_box(post, "ViceJaw", Vector3(-1.85, 1.2, 0.55), Vector3(0.3, 0.06, 0.32), _materials["frame_edge"])
	_cylinder(post, "HardHat", Vector3(0.15, 1.06, 0.55), 0.17, 0.16, _materials["orange"])

	_box(post, "ToolWall", Vector3(-0.9, 1.72, 1.0), Vector3(2.5, 1.46, 0.08), _materials["frame"])
	_box(post, "ToolWallInset", Vector3(-0.9, 1.75, 0.955), Vector3(2.35, 1.25, 0.02), _materials["frame_edge"])
	var hung_tool_transforms: Array[Transform3D] = []
	for index in 5:
		hung_tool_transforms.append(
			Transform3D(Basis.IDENTITY, Vector3(-1.85 + float(index) * 0.48, 1.72, 0.935))
		)
	_box_batch(
		post,
		"HungTools",
		Vector3(0.09, 0.55, 0.05),
		hung_tool_transforms,
		_materials["graphite"]
	)
	_box(post, "TaskLamp", Vector3(-0.9, 2.42, 0.86), Vector3(0.9, 0.1, 0.22), _materials["ceramic"])
	_box(post, "TaskLampGlow", Vector3(-0.9, 2.355, 0.86), Vector3(0.8, 0.04, 0.16), _materials["sign_lit"])

	# Seated at y = 0.52 rather than at its own body radius: the 0.5 m flanges are
	# wider than the drum, and any lower they would cut through the mount plane.
	_cylinder(post, "CableDrum", Vector3(1.95, 0.52, 0.7), 0.42, 0.5, _materials["graphite"], Vector3(90, 0, 0))
	for z_side in [-1.0, 1.0]:
		_cylinder(post, "DrumFlange", Vector3(1.95, 0.52, 0.7 + z_side * 0.28), 0.5, 0.06, _materials["frame_edge"], Vector3(90, 0, 0))

	_box(post, "SupplyCrate", Vector3(2.15, 0.34, -0.55), Vector3(1.0, 0.68, 0.9), _materials["crate"])
	_box(post, "SupplyCrateTop", Vector3(2.15, 0.92, -0.55), Vector3(0.85, 0.48, 0.8), _materials["crate_alt"])

	# The post sign caps the tool wall rather than standing on nothing: its
	# underside at y = 2.34 overlaps the wall head at y = 2.45.
	_box(post, "PostSignBack", Vector3(-0.9, 2.46, 1.0), Vector3(1.4, 0.24, 0.06), _materials["graphite"])
	_box(post, "PostSignFace", Vector3(-0.9, 2.46, 0.955), Vector3(1.2, 0.16, 0.03), _materials["sign_lit"])
	_cylinder(post, "JigPost", Vector3(-2.0, 0.775, -0.75), 0.16, 1.55, _materials["frame"])

	var carousel := _add_station_life_mover(post, "AnimatedToolCarousel")
	_cylinder(carousel, "CarouselHub", Vector3.ZERO, 0.12, 0.62, _materials["frame_edge"])
	for index in 3:
		var angle := float(index) * TAU / 3.0
		var tray_x := cos(angle) * 0.3
		var tray_z := sin(angle) * 0.3
		_box(
			carousel,
			"CarouselTray",
			Vector3(tray_x, -0.24, tray_z),
			Vector3(0.34, 0.06, 0.22),
			_materials["graphite"],
			Vector3(0.0, -rad_to_deg(angle), 0.0)
		)
		_box(carousel, "CarouselTool", Vector3(tray_x, -0.03, tray_z), Vector3(0.08, 0.42, 0.08), _materials["ceramic"])

	var jig := _add_station_life_mover(post, "AnimatedWeldJig")
	_box(jig, "JigArm", Vector3(0.45, 0.0, 0.0), Vector3(0.95, 0.14, 0.16), _materials["frame_edge"])
	_box(jig, "JigHead", Vector3(0.95, -0.1, 0.0), Vector3(0.26, 0.26, 0.22), _materials["graphite"])
	var arc := _box(jig, "WeldArc", Vector3(0.95, -0.28, 0.0), Vector3(0.14, 0.12, 0.14), _materials["cyan_dim"])

	# A short, uneven duty cycle: the arc strikes for a fifth of a second at a
	# time, which is what makes it read as work rather than as a status lamp.
	_register_station_life_lens(arc, "cyan_dim", "cyan_lit", 0.85, 0.19, 0.0)


func _build_safety_beacons() -> void:
	var positions := _get_beacon_positions()
	for index in positions.size():
		var beacon := Node3D.new()
		beacon.name = "SafetyBeacon%02d" % (index + 1)
		beacon.position = positions[index]
		beacon.set_meta("collision_policy", &"sacrificial_nonblocking_route_marker")
		_presentation_root.add_child(beacon)
		_cylinder(beacon, "Base", Vector3.ZERO, 0.24, 0.18, _materials["graphite"])
		var lens := _cylinder(beacon, "Lens", Vector3(0.0, 0.2, 0.0), 0.15, 0.24, _materials["amber_dim"])
		_beacon_lenses.append(lens)
		if _profile_id == PROFILE_DRONE_PATROL:
			# MAP-005. The anchor foot used to be a plinth 0.13 m *below* the base
			# pedestal, which left the pedestal hanging 0.07 m over its own foot. It
			# is now a bolt-down flange around the foot of the pedestal, sharing the
			# pedestal's underside, so the whole assembly seats on one plane.
			_box(beacon, "AnchorFoot", Vector3(0.0, -0.06, 0.0), Vector3(0.62, 0.06, 0.62), _materials["frame_edge"])


func _get_beacon_positions() -> Array[Vector3]:
	# MAP-005. `_beacon_seat_height` is half the `Base` pedestal's 0.18 m height, so
	# the pedestal's underside lands on the activity's own mounting plane (local
	# y = 0) — the same plane every `FootPad` in this component already sits on.
	# The previous 0.27 m left all sixteen beacons in the roster hovering: 0.19 m
	# over the Aft, Habitat and Freight roofs and 0.21 m over the Central berth
	# deck. Only the mount transform's own offset from the deck below it remains.
	var x_extent := 4.72
	var z_extent := 3.15
	match _profile_id:
		PROFILE_SERVICE_ARM:
			x_extent = 1.9
			z_extent = 1.25
		PROFILE_DRONE_PATROL:
			x_extent = 4.1
			z_extent = 3.25
		PROFILE_GANTRY:
			x_extent = 4.72
			z_extent = 3.05
		PROFILE_CARGO_LINE:
			x_extent = 4.55
			z_extent = 2.3
		PROFILE_CARGO_LINE_LONG:
			x_extent = 11.05
			z_extent = 1.45
		PROFILE_SIGNAGE_PYLON:
			x_extent = 1.5
			z_extent = 1.2
		PROFILE_OBSERVATORY:
			x_extent = 2.0
			z_extent = 2.0
		PROFILE_CREW_WORKPOST:
			x_extent = 2.4
			z_extent = 1.6
	return [
		Vector3(-x_extent, _beacon_seat_height, -z_extent),
		Vector3(x_extent, _beacon_seat_height, -z_extent),
		Vector3(-x_extent, _beacon_seat_height, z_extent),
		Vector3(x_extent, _beacon_seat_height, z_extent),
	]

func _register_station_life_lens(
		lens: MeshInstance3D,
		dim_key: String,
		lit_key: String,
		period: float,
		duty: float,
		offset: float
	) -> void:
	_station_life_lenses.append(lens)
	_station_life_lens_specs.append({
		"dim": dim_key,
		"lit": lit_key,
		"period": period,
		"duty": duty,
		"offset": offset,
	})


func _add_station_life_mover(parent: Node3D, node_name: String) -> Node3D:
	var mover := Node3D.new()
	mover.name = node_name
	parent.add_child(mover)
	_station_life_movers.append(mover)
	return mover

func _material(
		color: Color,
		metallic: float,
		roughness: float,
		emission_color: Color = Color.TRANSPARENT,
		emission_energy: float = 0.0
	) -> StandardMaterial3D:
	var result := StandardMaterial3D.new()
	result.albedo_color = color
	result.metallic = metallic
	result.roughness = roughness
	# Same faint coated-plate specular the Aft, Habitat, Freight and Fleet Dock
	# modules already give their station surfaces. Without it this equipment kept
	# a dry, matte response that read as untextured plastic beside them.
	result.clearcoat_enabled = true
	result.clearcoat = 0.18
	result.clearcoat_roughness = 0.48
	if emission_energy > 0.0:
		result.emission_enabled = true
		result.emission = emission_color
		result.emission_energy_multiplier = emission_energy
	return result


func _box(
		parent: Node3D,
		node_name: String,
		position_value: Vector3,
		size: Vector3,
		material: Material,
		rotation_degrees_value: Vector3 = Vector3.ZERO
	) -> MeshInstance3D:
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = node_name
	mesh_instance.position = position_value
	mesh_instance.rotation_degrees = rotation_degrees_value
	# Chamfered rather than a raw `BoxMesh`: the bounding box, and therefore the
	# published envelope and every declared footprint, is unchanged, but the edges
	# now catch a highlight the way the surrounding plated decks already do.
	mesh_instance.mesh = _rounded_box_mesh(size)
	mesh_instance.material_override = material
	mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	parent.add_child(mesh_instance, true)
	return mesh_instance


## One `MultiMeshInstance3D` drawing many copies of one chamfered box.
##
## Used only where the copies are genuinely identical stock — rail ties, gantry
## posts, crates, wheels. The mesh is the same cached `ArrayMesh` a `_box()` of
## the same size would get, so an instanced tie and a drawn tie are the same
## object; what changes is that the batch is one draw submission instead of
## twelve. `material_override` carries the same registered triplanar recipe the
## drawn geometry uses, and world-space triplanar means every copy still samples
## the plate by its own world position rather than repeating one mapping.
func _box_batch(
		parent: Node3D,
		node_name: String,
		size: Vector3,
		transforms: Array[Transform3D],
		material: Material
	) -> MultiMeshInstance3D:
	return _instanced(parent, node_name, _rounded_box_mesh(size), transforms, material)


func _cylinder_batch(
		parent: Node3D,
		node_name: String,
		radius: float,
		height: float,
		transforms: Array[Transform3D],
		material: Material
	) -> MultiMeshInstance3D:
	return _instanced(
		parent,
		node_name,
		StationSurfaceKit.chamfered_cylinder_mesh_cached(
			radius * 0.88, radius, height, 12, _chamfered_cylinder_cache, 1
		),
		transforms,
		material
	)


func _instanced(
		parent: Node3D,
		node_name: String,
		mesh: Mesh,
		transforms: Array[Transform3D],
		material: Material
	) -> MultiMeshInstance3D:
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.mesh = mesh
	multimesh.instance_count = transforms.size()
	for index in transforms.size():
		multimesh.set_instance_transform(index, transforms[index])
	var batch := MultiMeshInstance3D.new()
	batch.name = node_name
	batch.multimesh = multimesh
	batch.material_override = material
	batch.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	parent.add_child(batch, true)
	# Keep the CPU-authored roster beside the renderer resource. Headless Godot
	# has no MultiMesh buffer to read back, while Forward+ can compare this exact
	# roster against the live rendering-server transforms.
	batch.set_meta("authored_instance_transforms", transforms.duplicate())
	_multimesh_batch_transforms[batch.get_instance_id()] = transforms.duplicate()
	return batch


func _transformed_mesh_bounds(
		mesh_bounds: AABB,
		transforms: Array[Transform3D]
	) -> AABB:
	var result := AABB()
	var first := true
	for value in transforms:
		var transformed := (value * mesh_bounds).abs()
		if first:
			result = transformed
			first = false
		else:
			result = result.merge(transformed)
	return result


## Box with softly chamfered edges, at this module's frozen bevel rule.
##
## The rule stays `clamp(shortest_side * 0.22, 0.003, 0.2)` and is *not* the
## kit's own `bevel_for_size`. Measured over every live chamfered box in this
## module, adopting the kit rule would move 3 of 22 distinct sizes by up
## to 0.0043 m, so the shared code is the builder, not the rule. The outer extent
## along each axis is preserved exactly, so `get_aabb()` still returns the
## requested size and no footprint, collider or published envelope moves.
func _rounded_box_mesh(size: Vector3) -> ArrayMesh:
	return StationSurfaceKit.rounded_box_mesh_with_bevel_cached(
		size,
		StationSurfaceKit.proportional_bevel_for_size(size, 0.2),
		_rounded_box_cache,
		StationSurfaceKit.BevelUV.FACE_GRID
	)


func _cylinder(
		parent: Node3D,
		node_name: String,
		position_value: Vector3,
		radius: float,
		height: float,
		material: Material,
		rotation_degrees_value: Vector3 = Vector3.ZERO
	) -> MeshInstance3D:
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = node_name
	mesh_instance.position = position_value
	mesh_instance.rotation_degrees = rotation_degrees_value
	# Tapered stock: the wide bottom rim carries this mesh's radial extent alone,
	# so the kit chamfers only the narrow top rim and the silhouette does not
	# move. Outer radius and overall height are unchanged.
	mesh_instance.mesh = StationSurfaceKit.chamfered_cylinder_mesh_cached(
		radius * 0.88, radius, height, 12, _chamfered_cylinder_cache, 1
	)
	mesh_instance.material_override = material
	mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	parent.add_child(mesh_instance, true)
	return mesh_instance
