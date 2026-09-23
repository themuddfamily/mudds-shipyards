class_name AuroraTemperateAuthoredScene
extends Node3D

const AuroraSurfaceAudioBindingType := preload("res://scripts/audio/aurora_surface_audio_binding.gd")
const WaterContactAudioBindingType := preload("res://scripts/audio/water_contact_audio_binding.gd")
const SettlementInteractionAudioBindingType := preload("res://scripts/audio/settlement_interaction_audio_binding.gd")

const WORLD_PATH := "res://assets/world/planets/aurora_temperate_world.tres"
const ATMOSPHERE_PATH := "res://assets/world/planets/aurora_temperate_atmosphere.tres"
const TERRAIN_PATH := "res://assets/world/planets/aurora_temperate_terrain.tres"
const LANDING_PATH := "res://assets/world/planets/aurora_foundation_landing.tres"
const BODY_RADIUS_M := 120000.0
const TERRAIN_RENDER_RESOLUTION := 65
const TERRAIN_SEED := 20_260_830
# The authored approach box runs from the pad to 600 m along local +Z. Keep
# that complete flight volume at sea-level height; relief blends back in beyond
# it instead of putting the final-approach camera or ship underneath a hill.
const TERRAIN_FLATTEN_RADIUS_M := 750.0
const TERRAIN_VISUAL_CLEARANCE_RADIUS_M := 94.0
const TERRAIN_COLLISION_CLEARANCE_RADIUS_M := 48.0
const ORBITAL_FRAME_ID := &"aurora_foundation_system"
const ORBITAL_CELL_SIZE_M := 1000000.0
const ORIGIN_SHIFT_THRESHOLD_M := 10000.0
const SURFACE_ROUTE_ID := &"aurora_pad_to_staging"
const SURFACE_ROUTE_EGRESS_ID := &"aurora_egress"
const SURFACE_ROUTE_STAGING_ID := &"aurora_staging"
const SURFACE_LANDMARK_MARKER_PATHS := {
	&"aurora_pad": ^"LandingRegion/Markers/AuroraPad",
	&"aurora_egress": ^"LandingRegion/Markers/AuroraEgress",
	&"aurora_staging": ^"LandingRegion/Markers/AuroraStaging",
}

var _surface_audio_binding: RefCounted
var _water_contact_audio_binding: RefCounted
var _settlement_audio_binding: RefCounted
var _terrain_clipmap: PlanetaryTerrainClipmapRenderer

func _ready() -> void:
	_build_exploration_landmarks()
	set_process(false)
	set_physics_process(false)
	_terrain_clipmap = get_node_or_null(^"TerrainClipmap") \
		as PlanetaryTerrainClipmapRenderer
	var terrain := load(TERRAIN_PATH) as PlanetaryTerrainProfile
	if _terrain_clipmap == null or terrain == null:
		push_error("Aurora terrain clipmap contract is unavailable")
	else:
		var configured := _terrain_clipmap.configure(
			terrain,
			TERRAIN_RENDER_RESOLUTION,
			TERRAIN_SEED,
			Vector3.UP * BODY_RADIUS_M,
			TERRAIN_FLATTEN_RADIUS_M,
			TERRAIN_VISUAL_CLEARANCE_RADIUS_M,
			TERRAIN_COLLISION_CLEARANCE_RADIUS_M,
		)
		var rebuilt := (
			_terrain_clipmap.rebuild(
				Vector3.UP * BODY_RADIUS_M,
				_terrain_clipmap.get_generation(),
			)
			if bool(configured.get("accepted", false))
			else {"accepted": false, "reason": configured.get("reason", &"configure_failed")}
		)
		if not bool(rebuilt.get("accepted", false)):
			push_error(
				"Aurora terrain clipmap failed: %s"
				% String(rebuilt.get("reason", &"unknown"))
			)
	_surface_audio_binding = AuroraSurfaceAudioBindingType.new()
	_surface_audio_binding.attach(0)
	_water_contact_audio_binding = WaterContactAudioBindingType.new()
	_water_contact_audio_binding.attach(0)
	_settlement_audio_binding = SettlementInteractionAudioBindingType.new()
	_settlement_audio_binding.attach(0)

func _exit_tree() -> void:
	if _surface_audio_binding != null:
		_surface_audio_binding.detach()
		_surface_audio_binding = null
	if _water_contact_audio_binding != null:
		_water_contact_audio_binding.detach()
		_water_contact_audio_binding = null
	if _settlement_audio_binding != null:
		_settlement_audio_binding.detach()
		_settlement_audio_binding = null

func present_surface_audio_snapshot(snapshot: Dictionary) -> Dictionary:
	if _surface_audio_binding == null:
		return {"accepted": false, "reason": &"audio_binding_unavailable"}
	return _surface_audio_binding.present_snapshot(snapshot)

func set_surface_audio_reduced_dynamic_range(enabled: bool) -> Dictionary:
	if _surface_audio_binding == null:
		return {"accepted": false, "reason": &"audio_binding_unavailable"}
	return _surface_audio_binding.set_reduced_dynamic_range(enabled)

func get_surface_audio_snapshot() -> Dictionary:
	return _surface_audio_binding.get_snapshot() if _surface_audio_binding != null else {"attached": false}

func present_water_contact_audio_receipt(receipt: Dictionary) -> Dictionary:
	if _water_contact_audio_binding == null:
		return {"accepted": false, "reason": &"water_audio_binding_unavailable"}
	return _water_contact_audio_binding.present_receipt(receipt)

func set_water_contact_audio_perspective(perspective: StringName) -> Dictionary:
	if _water_contact_audio_binding == null:
		return {"accepted": false, "reason": &"water_audio_binding_unavailable"}
	return _water_contact_audio_binding.set_perspective(perspective)

func get_water_contact_audio_snapshot() -> Dictionary:
	return _water_contact_audio_binding.get_snapshot() if _water_contact_audio_binding != null else {"attached": false}

func present_settlement_interaction_audio_receipt(receipt: Dictionary) -> Dictionary:
	if _settlement_audio_binding == null:
		return {"accepted": false, "reason": &"settlement_audio_binding_unavailable"}
	return _settlement_audio_binding.present_receipt(receipt)

func set_settlement_audio_perspective(perspective: StringName) -> Dictionary:
	if _settlement_audio_binding == null:
		return {"accepted": false, "reason": &"settlement_audio_binding_unavailable"}
	return _settlement_audio_binding.set_perspective(perspective)

func get_settlement_audio_snapshot() -> Dictionary:
	return _settlement_audio_binding.get_snapshot() if _settlement_audio_binding != null else {"attached": false}


func get_terrain_clipmap_snapshot() -> Dictionary:
	return (
		_terrain_clipmap.get_snapshot()
		if _terrain_clipmap != null
		else {"configured": false, "ring_count": 0}
	)

func audit() -> Dictionary:
	var errors := PackedStringArray()
	var world := load(WORLD_PATH) as PlanetaryWorldDefinition
	var atmosphere := load(ATMOSPHERE_PATH) as PlanetaryAtmosphereProfile
	var terrain := load(TERRAIN_PATH) as PlanetaryTerrainProfile
	var landing := load(LANDING_PATH) as PlanetaryLandingRegionDefinition
	if world == null or atmosphere == null or terrain == null or landing == null or not world.is_definition_valid() or not atmosphere.is_definition_valid() or not terrain.is_profile_valid() or not landing.is_definition_valid():
		errors.append("resource_contract_invalid")
	if world != null and world.scene_path != scene_file_path:
		errors.append("world_scene_path_drift")
	var world_composition := PlanetaryWorldCompositionValidator.new().validate_composition(
		world, atmosphere, terrain,
	)
	if not bool(world_composition.get("valid", false)):
		errors.append("world_composition_invalid")

	var coordinate_frame := PlanetaryCoordinateFrame.new()
	var frame_configuration := {"accepted": false}
	if world != null and landing != null:
		var origin := _orbital_origin()
		frame_configuration = coordinate_frame.configure(
			landing.body_id, world.body_radius_metres, ORBITAL_FRAME_ID,
			ORBITAL_CELL_SIZE_M, origin, Vector3.UP, Vector3.FORWARD,
			ORIGIN_SHIFT_THRESHOLD_M, origin,
		)
	var landing_composition := PlanetaryLandingCompositionValidator.new().validate_composition(
		world, terrain, coordinate_frame.get_snapshot(), landing,
	)
	if not bool(frame_configuration.get("accepted", false)) or not bool(landing_composition.get("valid", false)):
		errors.append("landing_composition_invalid")

	if get_node_or_null("BodyVisual") == null or get_node_or_null("LandingRegion/WalkablePatch/CollisionShape3D") == null or get_node_or_null("AuroraAtmosphereComposition") == null or _terrain_clipmap == null:
		errors.append("required_node_missing")
	var terrain_clipmap_audit := (
		_terrain_clipmap.audit() if _terrain_clipmap != null else {"valid": false}
	) as Dictionary
	var terrain_clipmap_snapshot := terrain_clipmap_audit.get("snapshot", {}) \
		as Dictionary
	if (
		not bool(terrain_clipmap_audit.get("valid", false))
		or terrain_clipmap_snapshot.get("profile_id", &"")
			!= &"aurora_temperate_terrain"
		or int(terrain_clipmap_snapshot.get("ring_count", 0)) != 5
		or int(terrain_clipmap_snapshot.get("collision_ring_count", 0)) != 1
		or int(terrain_clipmap_snapshot.get("render_vertex_count", 0)) > 300000
		or int(terrain_clipmap_snapshot.get("render_triangle_count", 0)) > 600000
	):
		errors.append("terrain_clipmap_invalid")
	var region := get_node_or_null("LandingRegion") as Node3D
	if region == null or region.position != Vector3.UP * BODY_RADIUS_M or region.basis != Basis.IDENTITY:
		errors.append("landing_transform_drift")
	_validate_surface_route(errors, landing)
	var environments := find_children("*", "WorldEnvironment", true, false)
	if environments.size() != 1 or environments[0] != get_node_or_null("AuroraAtmosphereComposition/WorldEnvironment"):
		errors.append("world_environment_census_drift")
	if is_processing() or is_physics_processing():
		errors.append("process_authority_added")
	return {"valid": errors.is_empty(), "errors": errors, "world_composition": world_composition, "landing_composition": landing_composition, "terrain_clipmap": terrain_clipmap_audit, "surface_content": _surface_content_snapshot(landing), "authority": {"renderer": true, "gameplay": false, "streaming": false, "physics": true, "world_generation": false, "terrain_generation": true, "collision_generation": true, "origin_shift": false, "save": false, "network": false, "audio": false, "camera": false, "surface_route": false}}.duplicate(true)


func _validate_surface_route(errors: PackedStringArray, landing: PlanetaryLandingRegionDefinition) -> void:
	if landing == null:
		errors.append("surface_route_resource_missing")
		return
	var anchors := landing.get_surface_route_anchor_snapshot()
	var pads := landing.get_touchdown_pad_snapshot()
	if anchors.size() != 2 or pads.size() != 1 \
			or StringName((pads[0] as Dictionary).get("pad_id", &"")) != &"aurora_pad" \
			or StringName((pads[0] as Dictionary).get("egress_anchor_id", &"")) != SURFACE_ROUTE_EGRESS_ID:
		errors.append("surface_route_resource_drift")
		return
	var expected_positions := {
		&"aurora_pad": (pads[0] as Dictionary).get("transform_region_local_m", Transform3D.IDENTITY).origin,
		SURFACE_ROUTE_EGRESS_ID: Vector3(18.0, 0.0, 0.0),
		SURFACE_ROUTE_STAGING_ID: Vector3(42.0, 0.0, 0.0),
	}
	for index in anchors.size():
		var anchor := anchors[index] as Dictionary
		var anchor_id := StringName(anchor.get("anchor_id", &""))
		var expected_id := SURFACE_ROUTE_EGRESS_ID if index == 0 else SURFACE_ROUTE_STAGING_ID
		if anchor_id != expected_id \
				or anchor.get("position_region_local_m", Vector3.INF) != expected_positions.get(anchor_id, Vector3.INF):
			errors.append("surface_route_resource_drift")
			return
	for landmark_id: StringName in SURFACE_LANDMARK_MARKER_PATHS:
		var marker := get_node_or_null(SURFACE_LANDMARK_MARKER_PATHS[landmark_id]) as Marker3D
		if marker == null or marker.position != expected_positions[landmark_id]:
			errors.append("surface_route_marker_drift")
			return


func _surface_content_snapshot(landing: PlanetaryLandingRegionDefinition) -> Dictionary:
	var route_points := PackedVector3Array()
	var landmark_positions := {}
	if landing != null:
		var pads := landing.get_touchdown_pad_snapshot()
		if pads.size() == 1:
			route_points.append(((pads[0] as Dictionary).get("transform_region_local_m", Transform3D.IDENTITY) as Transform3D).origin)
		for anchor in landing.get_surface_route_anchor_snapshot():
			var record := anchor as Dictionary
			var anchor_id := StringName(record.get("anchor_id", &""))
			var position := record.get("position_region_local_m", Vector3.INF) as Vector3
			if anchor_id == SURFACE_ROUTE_EGRESS_ID or anchor_id == SURFACE_ROUTE_STAGING_ID:
				route_points.append(position)
				landmark_positions[anchor_id] = position
		if not route_points.is_empty():
			landmark_positions[&"aurora_pad"] = route_points[0]
	return {
		"content_class": &"NEW",
		"status": &"modern_interpretation",
		"route_id": SURFACE_ROUTE_ID,
		"route_points_region_local_m": route_points,
		"landmark_marker_paths": SURFACE_LANDMARK_MARKER_PATHS.duplicate(true),
		"landmark_positions_region_local_m": landmark_positions,
		"traversable": false,
		"route_authority": false,
	}.duplicate(true)


func _orbital_origin() -> Dictionary:
	return {
		"schema_version": PlanetaryCoordinateFrame.COORDINATE_SCHEMA_VERSION,
		"frame_id": ORBITAL_FRAME_ID,
		"cell_x": 0,
		"cell_y": 0,
		"cell_z": 0,
		"offset_meters": Vector3.ZERO,
	}


## A short coastal walk starts at the working pad and ends at a real lookout.
## The authored touchdown/approach volumes remain clear; dressing lives east
## and north of the pad and the existing terrain owns the walking ground.
func _build_exploration_landmarks() -> void:
	var landing := get_node("LandingRegion") as Node3D
	var content := Node3D.new()
	content.name = "CoastalExploration"
	landing.add_child(content)
	var stone := _exploration_material(Color("65777b"))
	var dark_stone := _exploration_material(Color("435659"))
	var foliage := _exploration_material(Color("427567"))
	var light_foliage := _exploration_material(Color("739581"))
	var bark := _exploration_material(Color("665744"))
	var deck := _exploration_material(Color("687974"))
	var metal := _exploration_material(Color("354a51"))
	var amber := _exploration_material(Color("d4ad68"))
	var ground := _exploration_material(Color("4d6655"))
	(get_node("LandingRegion/LandingFloor") as MeshInstance3D).material_override = ground
	(get_node("LandingRegion/PadVisual") as MeshInstance3D).material_override = metal

	# Quiet edge markings keep the existing landing footprint readable.
	for side in [-1.0, 1.0]:
		_exploration_box(content, "PadEdge%s" % side, Vector3(side * 12.5, 0.055, 0), Vector3(0.2, 0.025, 26), amber)
		for z in [-12.0, 12.0]:
			_exploration_box(content, "PadCorner%s_%s" % [side, z], Vector3(side * 10.0, 0.055, z), Vector3(5, 0.025, 0.2), amber)

	# Amber gravel and small posts guide the player from the pad past the
	# existing staging marker to the overlook; every segment lies on solid ground.
	var trail := [Vector3(14, 0, 2), Vector3(33, 0, 2), Vector3(43, 0, -8), Vector3(57, 0, -20)]
	for i in range(trail.size() - 1):
		var start: Vector3 = trail[i]
		var finish: Vector3 = trail[i + 1]
		var direction := finish - start
		var strip := _exploration_box(content, "CoastalTrail%d" % i, (start + finish) * 0.5 + Vector3.UP * 0.035, Vector3(2.8, 0.035, direction.length() + 0.6), deck)
		strip.rotation.y = atan2(direction.x, direction.z)
		var edge := Vector3(direction.z, 0, -direction.x).normalized() * 1.6
		for j in range(3):
			var point := start.lerp(finish, (float(j) + 0.4) / 3.0) + edge
			_exploration_box(content, "TrailPost%d_%d" % [i, j], point + Vector3.UP * 0.3, Vector3(0.13, 0.6, 0.13), metal)
			_exploration_box(content, "TrailCap%d_%d" % [i, j], point + Vector3.UP * 0.62, Vector3(0.19, 0.06, 0.19), amber)

	# Grounded wayfinding: the sign is attached to a backboard and two posts.
	var sign := MeshInstance3D.new()
	sign.name = "CoastalLookoutSign"
	var lettering := TextMesh.new()
	lettering.text = "COASTAL LOOKOUT  >\nFOLLOW THE AMBER TRAIL"
	lettering.font_size = 48
	lettering.pixel_size = 0.006
	sign.mesh = lettering
	sign.position = Vector3(30.0, 1.9, -1.4)
	sign.rotation.y = -PI * 0.5
	var ink := _exploration_material(Color("f2d79b"))
	ink.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	sign.material_override = ink
	content.add_child(sign)
	_survey_anchor(sign, "SurveyTrailSign", Vector3(0, -1.9, 1.4))
	_exploration_box(sign, "SignBackboard", Vector3(0, 0, -0.12), Vector3(4.6, 1.1, 0.18), metal)
	for side in [-1.0, 1.0]:
		_exploration_box(sign, "Signpost%s" % side, Vector3(side * 1.7, -0.9, -0.13), Vector3(0.16, 2.0, 0.16), metal)

	# Low accessible platform with a landward entrance and a protected sea edge.
	_exploration_box(content, "CoastalLookoutDeck", Vector3(64, 0.12, -20), Vector3(14, 0.24, 12), deck, true)
	_exploration_box(content, "LookoutStep", Vector3(56.5, 0.06, -20), Vector3(1.3, 0.12, 3.2), deck, true)
	for z in [-26.0, -14.0]:
		_exploration_box(content, "LookoutSideRail%s" % z, Vector3(64, 1.2, z), Vector3(14, 0.12, 0.12), metal, true)
		for x in [58.0, 64.0, 70.0]:
			_exploration_box(content, "LookoutRailPost%s_%s" % [x, z], Vector3(x, 0.72, z), Vector3(0.14, 1.2, 0.14), metal, true)
	_exploration_box(content, "LookoutSeaRail", Vector3(71, 1.2, -20), Vector3(0.12, 0.12, 12), amber, true)
	for z in [-23.0, -17.0]:
		_exploration_box(content, "LookoutInstrumentPedestal%s" % z, Vector3(68, 0.85, z), Vector3(0.3, 1.2, 0.3), metal, true)
		var scope := CylinderMesh.new()
		scope.top_radius = 0.16
		scope.bottom_radius = 0.25
		scope.height = 1.15
		var telescope := _exploration_prop(content, "LookoutScope%s" % z, Vector3(68, 1.55, z), scope, amber)
		telescope.rotation.z = PI * 0.5
		if z == -17.0:
			_survey_anchor(telescope, "SurveyLookout", Vector3.ZERO)

	# Weathered standing stones form a sheltered stopping point beside the trail.
	for i in range(7):
		var angle := float(i) * 2.39996
		var point := Vector3(51.0 + cos(angle) * (4.0 + float(i % 3)), 0.0, -33.0 + sin(angle) * 4.0)
		var rock := CylinderMesh.new()
		rock.top_radius = 0.35 + float(i % 2) * 0.2
		rock.bottom_radius = 0.9 + float(i % 3) * 0.25
		rock.height = 1.4 + float(i % 4) * 0.7
		rock.radial_segments = 5
		var visual := _exploration_prop(content, "StandingStone%d" % i, point + Vector3.UP * rock.height * 0.5, rock, stone if i % 2 else dark_stone, Vector3(1.3, rock.height, 1.3))
		visual.rotation.y = angle
		if i == 0:
			_survey_anchor(visual, "SurveyStones", Vector3(-2, -0.7, 0))
		visual.scale = Vector3(1.0, 1.0, 0.65 + float(i % 3) * 0.17)

	# Coast-facing clusters replace the evenly spaced cone trees. Their broken
	# silhouettes leave the approach from +Z and the player trail unobstructed.
	var groves := [Vector3(-30, 0, -29), Vector3(24, 0, -34), Vector3(45, 0, 20)]
	for i in range(12):
		var cluster: Vector3 = groves[i / 4]
		var angle := float(i) * 2.39996
		var point := cluster + Vector3(cos(angle) * 5, 0, sin(angle) * 5)
		var height := 2.2 + float(i % 3) * 0.65
		var trunk := CylinderMesh.new()
		trunk.top_radius = 0.16
		trunk.bottom_radius = 0.28
		trunk.height = height
		_exploration_prop(content, "TreeTrunk%d" % i, point + Vector3.UP * height * 0.5, trunk, bark, Vector3(0.5, height, 0.5))
		for branch in range(2):
			var crown := SphereMesh.new()
			crown.radius = 1.3 + float((i + branch) % 3) * 0.25
			crown.height = crown.radius * 1.5
			crown.radial_segments = 7
			crown.rings = 4
			var crown_point := point + Vector3(float(branch) * 0.8 - 0.4, height + float(branch) * 0.4, 0)
			_exploration_prop(content, "TreeCrown%d_%d" % [i, branch], crown_point, crown, foliage if i % 2 else light_foliage)
	for i in range(18):
		var point := Vector3(73 + sin(float(i) * 1.7) * 2.5, 0.0, -68 + float(i) * 7)
		var rock := SphereMesh.new()
		rock.radius = 1.2 + float(i % 3) * 0.45
		rock.height = rock.radius * 1.4
		rock.radial_segments = 6
		rock.rings = 3
		_exploration_prop(content, "ShoreRock%d" % i, point + Vector3.UP * 0.5, rock, dark_stone if i % 2 else stone)
	_build_coastal_water(content)


func _build_coastal_water(parent: Node3D) -> void:
	# The local waterline is a shallow shore on the existing collision shelf.
	# Nothing in this presentation removes terrain or expands the landing pad.
	var water := SurfaceTool.new()
	water.begin(Mesh.PRIMITIVE_TRIANGLES)
	var foam := SurfaceTool.new()
	foam.begin(Mesh.PRIMITIVE_TRIANGLES)
	var beach := SurfaceTool.new()
	beach.begin(Mesh.PRIMITIVE_TRIANGLES)
	var coastline := [-10000.0]
	for step in range(-20, 21):
		coastline.append(float(step) * 20.0)
	coastline.append(10000.0)
	for i in range(coastline.size() - 1):
		var z0: float = coastline[i]
		var z1: float = coastline[i + 1]
		var x0 := 78.0 + sin(float(i) * 1.7) * 3.0
		var x1 := 78.0 + sin(float(i + 1) * 1.7) * 3.0
		var near0 := Vector3(x0, 0.09, z0)
		var near1 := Vector3(x1, 0.09, z1)
		_water_quad(water, near0, near1, Vector3(30000, 0.09, z1), Vector3(30000, 0.09, z0))
		_water_quad(foam, near0 + Vector3.UP * 0.015, near1 + Vector3.UP * 0.015, near1 + Vector3(1.2, 0.015, 0), near0 + Vector3(1.2, 0.015, 0))
		_water_quad(beach, near0 - Vector3(4.0, 0.02, 0), near1 - Vector3(4.0, 0.02, 0), near1 - Vector3(0.0, 0.02, 0), near0 - Vector3(0.0, 0.02, 0))
	var surface := MeshInstance3D.new()
	surface.name = "AuroraCoastalWater"
	surface.mesh = water.commit()
	var shader := Shader.new()
	# This is a local coastal water patch, not a planet-wide ocean. Fade it at
	# distance so its rectangular far edge cannot cut across Aurora's orbital
	# silhouette. VERTEX is view-space in fragment(), so rebases need no update.
	shader.code = "shader_type spatial; render_mode unshaded, cull_disabled; void fragment(){ float ripple = sin(UV.x * 21.0 + TIME * 0.7) * sin(UV.y * 17.0 + TIME * 0.35); ALBEDO = mix(vec3(0.035, 0.19, 0.26), vec3(0.09, 0.36, 0.39), ripple * 0.22 + 0.55); ALPHA = 1.0 - smoothstep(2500.0, 10000.0, length(VERTEX)); }"
	var material := ShaderMaterial.new()
	material.shader = shader
	surface.material_override = material
	surface.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(surface)
	var shore := MeshInstance3D.new()
	shore.name = "AuroraShoreline"
	shore.mesh = foam.commit()
	var foam_material := _exploration_material(Color("91bcb0"))
	foam_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	foam_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	shore.material_override = foam_material
	shore.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(shore)
	var strand := MeshInstance3D.new()
	strand.name = "AuroraShingleBeach"
	strand.mesh = beach.commit()
	var sand := _exploration_material(Color("8c997c"))
	sand.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	sand.cull_mode = BaseMaterial3D.CULL_DISABLED
	strand.material_override = sand
	strand.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(strand)


func _water_quad(builder: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3) -> void:
	for point: Vector3 in [a, b, c, a, c, d]:
		builder.set_normal(Vector3.UP)
		builder.set_uv(Vector2(point.x, point.z) * 0.025)
		builder.add_vertex(point)


func _exploration_material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.88
	return material


func _exploration_box(parent: Node3D, prop_name: String, point: Vector3, size: Vector3, material: Material, solid: bool = false) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	return _exploration_prop(parent, prop_name, point, mesh, material, size if solid else Vector3.ZERO)


func _exploration_prop(parent: Node3D, prop_name: String, point: Vector3, mesh: Mesh, material: Material, collision_size: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var visual := MeshInstance3D.new()
	visual.name = prop_name
	visual.mesh = mesh
	visual.material_override = material
	visual.position = point
	parent.add_child(visual)
	if collision_size != Vector3.ZERO:
		var body := StaticBody3D.new()
		body.collision_layer = 1
		body.collision_mask = 0
		var collision := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = collision_size
		collision.shape = shape
		body.add_child(collision)
		visual.add_child(body)
	return visual


## Anchors inherit authored landmark transforms and common-world rebases.
func _survey_anchor(parent: Node3D, anchor_name: String, offset: Vector3) -> void:
	var anchor := Marker3D.new()
	anchor.name = anchor_name
	parent.add_child(anchor)
	anchor.position = offset
