class_name RimeGlacialAuthoredScene
extends Node3D

## Rime: the third visitable world, a cold thin-air glacial body.
##
## The body, terrain clipmap and atmosphere composition follow the same shared
## contracts Aurora uses (one body-centred sphere, one bounded +Y landing patch,
## one caller-driven spherical terrain clipmap, and a
## [PlanetaryAtmosphereComposition] that is the sole `WorldEnvironment` owner).
## What is Rime's own is the place itself: a pale ice shelf under a low
## ice-crystal overcast and drifting ground haze, a survey beacon trailhead, an
## ice-core drill rig with a heated hut, a serac field of leaning ice spires and a
## pressure ridge with a strain gauge, linked by an orange-lit survey trail and a
## cyan-lit return path.
##
## Every placed node is a descendant of `LandingRegion`, a `Node3D` in the
## authored body frame, so every position below is a region-local reading and a
## common-world origin rebase carries all of it with the region. Nothing is
## parented under a plain `Node` (which is in neither authored frame).
##
## The scene owns no streaming, player, camera, gameplay, landing decision,
## origin shifting, save, network or production binding; `RimeExpedition` stands
## it up as a visit.

const SurfaceAudioBindingType := preload("res://scripts/audio/aurora_surface_audio_binding.gd")

const WORLD_PATH := "res://assets/world/planets/rime_glacial_world.tres"
const ATMOSPHERE_PATH := "res://assets/world/planets/rime_glacial_atmosphere.tres"
const TERRAIN_PATH := "res://assets/world/planets/rime_glacial_terrain.tres"
const LANDING_PATH := "res://assets/world/planets/rime_icefall_landing.tres"
const COMPOSITION_PATH := ^"RimeAtmosphereComposition"
const BODY_RADIUS_M := 120000.0
const TERRAIN_RENDER_RESOLUTION := 65
const TERRAIN_SEED := 20_260_927
## The complete 600 m approach box sits inside the flat envelope, exactly as on
## Aurora, so the final-approach flight never meets relief.
const TERRAIN_FLATTEN_RADIUS_M := 750.0
const TERRAIN_VISUAL_CLEARANCE_RADIUS_M := 94.0
const TERRAIN_COLLISION_CLEARANCE_RADIUS_M := 48.0
## Rime's ice sheet reads as one continuous pale surface: the shared clipmap
## material is tinted glacial blue-white and its temperate vertex palette is
## switched off after the build (see `_glaze_terrain_material`).
const TERRAIN_MATERIAL_TINT := Color("cfdde6")
const ORBITAL_FRAME_ID := &"rime_icefall_system"
const ORBITAL_CELL_SIZE_M := 1000000.0
const ORIGIN_SHIFT_THRESHOLD_M := 10000.0

const EXPLORATION_ROOT_NAME := "GlacierExploration"
const SURFACE_ROUTE_ID := &"rime_icefall_survey_route"
const SURFACE_LANDMARK_MARKER_PATHS := {
	&"rime_pad": ^"LandingRegion/Markers/RimePad",
	&"rime_egress": ^"LandingRegion/Markers/RimeEgress",
	&"rime_survey_beacon": ^"LandingRegion/Markers/RimeSurveyBeacon",
	&"rime_drill_rig": ^"LandingRegion/Markers/RimeDrillRig",
	&"rime_serac_field": ^"LandingRegion/Markers/RimeSeracField",
	&"rime_strain_gauge": ^"LandingRegion/Markers/RimeStrainGauge",
}
## The survey's three interaction anchors: start/abandon, first and second
## checkpoint. Each sits at its landmark's route anchor.
const SURVEY_ANCHOR_NAMES := ["SurveyBeacon", "SurveyDrillRig", "SurveyStrainGauge"]
const SURVEY_ANCHOR_POSITIONS := [
	Vector3(-24.0, 0.0, -16.0), Vector3(-54.0, 0.0, -46.0), Vector3(30.0, 0.0, -62.0),
]
## The heated hut's warmth. Standing within `HEAT_SHELTER_RADIUS_M` of it
## refills an explorer's suit heater during the ice-core survey.
const HEAT_SHELTER_ANCHOR_NAME := "RimeHeatedHutWarmth"
const HEAT_SHELTER_POSITION := Vector3(-59.0, 0.0, -43.0)
const HEAT_SHELTER_RADIUS_M := 7.0

## The orange-lit survey trail and the cyan-lit return path, region-local.
const SURVEY_TRAIL := [
	Vector3(-12, 0, -12), Vector3(-24, 0, -16), Vector3(-40, 0, -28),
	Vector3(-52, 0, -42), Vector3(-50, 0, -54), Vector3(-30, 0, -66),
	Vector3(-8, 0, -68), Vector3(14, 0, -70), Vector3(28, 0, -63),
]
const RETURN_TRAIL := [Vector3(30, 0, -60), Vector3(20, 0, -40), Vector3(10, 0, -24)]
const SURVEY_BEACON_COLOR := Color("ff8a2a")
const RETURN_BEACON_COLOR := Color("5fe3ff")

const SERAC_POSITIONS := [
	Vector3(-22, 0, -84), Vector3(-16, 0, -93), Vector3(-9, 0, -80),
	Vector3(-3, 0, -97), Vector3(4, 0, -86), Vector3(10, 0, -95),
	Vector3(-12, 0, -106), Vector3(2, 0, -107), Vector3(15, 0, -81),
]
const RIDGE_SLABS := [
	Vector3(38, 0, -60), Vector3(42, 0, -63), Vector3(46, 0, -61),
	Vector3(50, 0, -65), Vector3(54, 0, -62), Vector3(58, 0, -66), Vector3(62, 0, -63),
]

## Streamed-cost ceilings, comparable to Aurora's generation.
const NODE_BUDGET := 210
const LIGHT_BUDGET := 3
## Anything farther than this from the pad, or higher than this above the ice,
## is a placement that escaped the region frame.
const REGION_PLACEMENT_RADIUS_M := 140.0
const REGION_PLACEMENT_HEIGHT_M := 30.0

var _surface_audio_binding: RefCounted
var _exterior_voice: AudioStreamPlayer
var _interior_voice: AudioStreamPlayer
var _terrain_clipmap: PlanetaryTerrainClipmapRenderer
var _terrain_glazed := false


func _ready() -> void:
	set_process(false)
	set_physics_process(false)
	_build_glacier_exploration()
	_terrain_clipmap = get_node_or_null(^"TerrainClipmap") \
		as PlanetaryTerrainClipmapRenderer
	var terrain := load(TERRAIN_PATH) as PlanetaryTerrainProfile
	if _terrain_clipmap == null or terrain == null:
		push_error("Rime terrain clipmap contract is unavailable")
	else:
		var configured := _terrain_clipmap.configure(
			terrain,
			TERRAIN_RENDER_RESOLUTION,
			TERRAIN_SEED,
			Vector3.UP * BODY_RADIUS_M,
			TERRAIN_FLATTEN_RADIUS_M,
			TERRAIN_VISUAL_CLEARANCE_RADIUS_M,
			TERRAIN_COLLISION_CLEARANCE_RADIUS_M,
			TERRAIN_MATERIAL_TINT,
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
				"Rime terrain clipmap failed: %s"
				% String(rebuilt.get("reason", &"unknown"))
			)
		else:
			_glaze_terrain_material()
	_surface_audio_binding = SurfaceAudioBindingType.new()
	_surface_audio_binding.attach(0)
	_exterior_voice = get_node_or_null(^"SurfaceAmbience/ExteriorVoice") as AudioStreamPlayer
	_interior_voice = get_node_or_null(^"SurfaceAmbience/InteriorVoice") as AudioStreamPlayer
	if _exterior_voice == null or _interior_voice == null:
		push_error("Rime surface ambience voice contract is unavailable")


func _exit_tree() -> void:
	_stop_surface_audio()
	if _surface_audio_binding != null:
		_surface_audio_binding.detach()
		_surface_audio_binding = null


# --- surface audio (shared temperate voices, Rime's own mix inputs) ----------


func present_surface_audio_snapshot(snapshot: Dictionary) -> Dictionary:
	if _surface_audio_binding == null:
		return {"accepted": false, "reason": &"audio_binding_unavailable"}
	var result: Dictionary = _surface_audio_binding.present_snapshot(snapshot)
	if bool(result.get("accepted", false)):
		_apply_surface_audio_mix()
	return result


func set_surface_audio_reduced_dynamic_range(enabled: bool) -> Dictionary:
	if _surface_audio_binding == null:
		return {"accepted": false, "reason": &"audio_binding_unavailable"}
	var result: Dictionary = _surface_audio_binding.set_reduced_dynamic_range(enabled)
	if bool(result.get("accepted", false)):
		_apply_surface_audio_mix()
	return result


func get_surface_audio_snapshot() -> Dictionary:
	var snapshot: Dictionary = _surface_audio_binding.get_snapshot() \
		if _surface_audio_binding != null else {"attached": false}
	snapshot["playback"] = {
		"exterior_playing": _exterior_voice.playing if is_instance_valid(_exterior_voice) else false,
		"interior_playing": _interior_voice.playing if is_instance_valid(_interior_voice) else false,
		"exterior_volume_db": _exterior_voice.volume_db if is_instance_valid(_exterior_voice) else -80.0,
		"interior_volume_db": _interior_voice.volume_db if is_instance_valid(_interior_voice) else -80.0,
	}
	return snapshot.duplicate(true)


func _apply_surface_audio_mix() -> void:
	if not is_instance_valid(_exterior_voice) or not is_instance_valid(_interior_voice):
		return
	var state := _surface_audio_binding.get_snapshot() as Dictionary
	var mix := state.get("mix", {}) as Dictionary
	var perspective := StringName(state.get("ship_perspective", &"exterior"))
	# Rime has no surf: the whole exterior bed is the thin, hard wind.
	var exterior_level := clampf(float(mix.get("wind", 0.0)) * 0.85, 0.0, 1.0)
	var interior_level := clampf(float(mix.get("wind", 0.0)) * 0.4, 0.0, 1.0)
	_set_surface_voice(_exterior_voice, exterior_level if perspective == &"exterior" else exterior_level * 0.12)
	_set_surface_voice(_interior_voice, interior_level if perspective == &"cockpit" else 0.0)
	# Thin cold air carries a slightly higher, thinner wind than Aurora's coast.
	_exterior_voice.pitch_scale = float(mix.get("pitch_scale", 1.0)) * 1.08


func _set_surface_voice(voice: AudioStreamPlayer, level: float) -> void:
	if level <= 0.001:
		voice.stop()
		voice.volume_db = -80.0
		return
	voice.volume_db = clampf(linear_to_db(level) - 16.0, -60.0, -12.0)
	if not voice.playing:
		voice.play()


func _stop_surface_audio() -> void:
	for voice in [_exterior_voice, _interior_voice]:
		if is_instance_valid(voice):
			voice.stop()
			voice.volume_db = -80.0
			voice.pitch_scale = 1.0


# --- detached reads ------------------------------------------------------------


func get_atmosphere_composition() -> PlanetaryAtmosphereComposition:
	return get_node_or_null(COMPOSITION_PATH) as PlanetaryAtmosphereComposition


func get_terrain_clipmap_snapshot() -> Dictionary:
	return (
		_terrain_clipmap.get_snapshot()
		if _terrain_clipmap != null
		else {"configured": false, "ring_count": 0}
	)


func get_landing_region() -> Node3D:
	return get_node_or_null(^"LandingRegion") as Node3D


## Live global position of the heated hut's warmth, or `Vector3.INF`.
func get_heat_shelter_global_position() -> Vector3:
	var anchor := find_child(HEAT_SHELTER_ANCHOR_NAME, true, false) as Node3D
	return anchor.global_position if is_instance_valid(anchor) and anchor.is_inside_tree() \
		else Vector3.INF


## Region-local readings of every node placed in the exploration content. Each
## is taken through the live region transform, so a node that escaped the
## region frame reports where it really stands.
func get_region_local_placements() -> Dictionary:
	var region := get_landing_region()
	var content := region.get_node_or_null(EXPLORATION_ROOT_NAME) as Node3D \
		if region != null else null
	var placements := {}
	if region == null or content == null:
		return placements
	for candidate in content.find_children("*", "Node3D", true, false):
		var node := candidate as Node3D
		placements[String(content.get_path_to(node))] = \
			region.global_transform.affine_inverse() * node.global_position
	return placements


func get_streamed_cost() -> Dictionary:
	var lights := find_children("*", "Light3D", true, false)
	var shadowed := 0
	# The atmosphere rig's own sun is the composition's and is counted apart.
	var authored_lights := 0
	var region := get_landing_region()
	for candidate in lights:
		var light := candidate as Light3D
		if region != null and region.is_ancestor_of(light):
			authored_lights += 1
			if light.shadow_enabled:
				shadowed += 1
	var authored_triangles := 0
	if region != null:
		for candidate in region.find_children("*", "MeshInstance3D", true, false):
			authored_triangles += _mesh_triangles((candidate as MeshInstance3D).mesh)
		for candidate in region.find_children("*", "MultiMeshInstance3D", true, false):
			var multimesh := (candidate as MultiMeshInstance3D).multimesh
			if multimesh != null:
				authored_triangles += _mesh_triangles(multimesh.mesh) * multimesh.instance_count
	var terrain := get_terrain_clipmap_snapshot()
	return {
		"node_count": _count_nodes(self),
		"authored_light_count": authored_lights,
		"authored_shadowed_light_count": shadowed,
		"authored_triangle_count": authored_triangles,
		"terrain_render_triangle_count": int(terrain.get("render_triangle_count", 0)),
	}


func audit() -> Dictionary:
	var errors := PackedStringArray()
	var world := load(WORLD_PATH) as PlanetaryWorldDefinition
	var atmosphere := load(ATMOSPHERE_PATH) as PlanetaryAtmosphereProfile
	var terrain := load(TERRAIN_PATH) as PlanetaryTerrainProfile
	var landing := load(LANDING_PATH) as PlanetaryLandingRegionDefinition
	if world == null or atmosphere == null or terrain == null or landing == null \
			or not world.is_definition_valid() or not atmosphere.is_definition_valid() \
			or not terrain.is_profile_valid() or not landing.is_definition_valid():
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
	if not bool(frame_configuration.get("accepted", false)) \
			or not bool(landing_composition.get("valid", false)):
		errors.append("landing_composition_invalid")
	if get_node_or_null("BodyVisual") == null \
			or get_node_or_null("LandingRegion/WalkablePatch/CollisionShape3D") == null \
			or get_atmosphere_composition() == null or _terrain_clipmap == null:
		errors.append("required_node_missing")
	var terrain_audit := (
		_terrain_clipmap.audit() if _terrain_clipmap != null else {"valid": false}
	) as Dictionary
	var terrain_snapshot := terrain_audit.get("snapshot", {}) as Dictionary
	if not bool(terrain_audit.get("valid", false)) \
			or terrain_snapshot.get("profile_id", &"") != &"rime_glacial_terrain" \
			or int(terrain_snapshot.get("ring_count", 0)) != 5 \
			or int(terrain_snapshot.get("collision_ring_count", 0)) != 1:
		errors.append("terrain_clipmap_invalid")
	var region := get_landing_region()
	if region == null or region.position != Vector3.UP * BODY_RADIUS_M \
			or region.basis != Basis.IDENTITY:
		errors.append("landing_transform_drift")
	_validate_surface_route(errors, landing)
	_validate_region_placements(errors)
	var environments := find_children("*", "WorldEnvironment", true, false)
	if environments.size() != 1 \
			or environments[0] != get_node_or_null("RimeAtmosphereComposition/WorldEnvironment"):
		errors.append("world_environment_census_drift")
	var cost := get_streamed_cost()
	if int(cost.node_count) > NODE_BUDGET:
		errors.append("streamed_node_budget_exceeded")
	if int(cost.authored_light_count) > LIGHT_BUDGET \
			or int(cost.authored_shadowed_light_count) != 0:
		errors.append("authored_light_budget_exceeded")
	if is_processing() or is_physics_processing():
		errors.append("process_authority_added")
	return {
		"valid": errors.is_empty(),
		"errors": errors,
		"world_composition": world_composition,
		"landing_composition": landing_composition,
		"terrain_clipmap": terrain_audit,
		"surface_content": get_surface_content_snapshot(),
		"streamed_cost": cost,
		"authority": {
			"renderer": true, "gameplay": false, "streaming": false, "physics": true,
			"world_generation": false, "terrain_generation": true,
			"collision_generation": true, "origin_shift": false, "save": false,
			"network": false, "audio": true, "camera": false, "surface_route": false,
		},
	}.duplicate(true)


func get_surface_content_snapshot() -> Dictionary:
	var landing := load(LANDING_PATH) as PlanetaryLandingRegionDefinition
	var landmark_positions := {}
	if landing != null:
		for anchor in landing.get_surface_route_anchor_snapshot():
			var record := anchor as Dictionary
			landmark_positions[StringName(record.get("anchor_id", &""))] = \
				record.get("position_region_local_m", Vector3.INF)
	return {
		"content_class": &"NEW",
		"status": &"modern_interpretation",
		"route_id": SURFACE_ROUTE_ID,
		"survey_trail_region_local_m": PackedVector3Array(SURVEY_TRAIL),
		"return_trail_region_local_m": PackedVector3Array(RETURN_TRAIL),
		"landmark_marker_paths": SURFACE_LANDMARK_MARKER_PATHS.duplicate(true),
		"landmark_positions_region_local_m": landmark_positions,
		"survey_anchor_names": PackedStringArray(SURVEY_ANCHOR_NAMES),
		"traversable": false,
		"route_authority": false,
	}.duplicate(true)


func _validate_surface_route(
		errors: PackedStringArray, landing: PlanetaryLandingRegionDefinition
	) -> void:
	if landing == null:
		errors.append("surface_route_resource_missing")
		return
	var declared := {}
	for anchor in landing.get_surface_route_anchor_snapshot():
		var record := anchor as Dictionary
		declared[StringName(record.get("anchor_id", &""))] = \
			record.get("position_region_local_m", Vector3.INF)
	var pads := landing.get_touchdown_pad_snapshot()
	if pads.size() != 1 or StringName((pads[0] as Dictionary).get("pad_id", &"")) != &"rime_pad":
		errors.append("surface_route_resource_drift")
		return
	declared[&"rime_pad"] = ((pads[0] as Dictionary).get(
		"transform_region_local_m", Transform3D.IDENTITY
	) as Transform3D).origin
	for landmark_id: StringName in SURFACE_LANDMARK_MARKER_PATHS:
		var marker := get_node_or_null(SURFACE_LANDMARK_MARKER_PATHS[landmark_id]) as Marker3D
		if marker == null or not declared.has(landmark_id) \
				or marker.position != declared[landmark_id]:
			errors.append("surface_route_marker_drift")
			return
	for index in SURVEY_ANCHOR_NAMES.size():
		var anchor := find_child(SURVEY_ANCHOR_NAMES[index], true, false) as Node3D
		if anchor == null or get_landing_region() == null \
				or (get_landing_region().global_transform.affine_inverse()
					* anchor.global_position).distance_to(SURVEY_ANCHOR_POSITIONS[index]) > 0.01:
			errors.append("survey_anchor_drift")
			return


func _validate_region_placements(errors: PackedStringArray) -> void:
	var placements := get_region_local_placements()
	if placements.is_empty():
		errors.append("glacier_exploration_missing")
		return
	for key: String in placements:
		var local := placements[key] as Vector3
		if not local.is_finite() or Vector2(local.x, local.z).length() > REGION_PLACEMENT_RADIUS_M \
				or local.y < -3.0 or local.y > REGION_PLACEMENT_HEIGHT_M:
			errors.append("region_placement_escaped:%s" % key)
			return


func _orbital_origin() -> Dictionary:
	return {
		"schema_version": PlanetaryCoordinateFrame.COORDINATE_SCHEMA_VERSION,
		"frame_id": ORBITAL_FRAME_ID,
		"cell_x": 0,
		"cell_y": 0,
		"cell_z": 0,
		"offset_meters": Vector3.ZERO,
	}


## The shared clipmap material carries a temperate vertex palette (shore green
## through snow). Rime is one ice sheet, so its tinted albedo is used alone. The
## material's albedo tint - the value the renderer audits - is left untouched.
func _glaze_terrain_material() -> void:
	if _terrain_glazed or _terrain_clipmap == null:
		return
	for candidate in _terrain_clipmap.find_children("*", "MeshInstance3D", true, false):
		var material := (candidate as MeshInstance3D).material_override as StandardMaterial3D
		if material == null:
			continue
		material.vertex_color_use_as_albedo = false
		material.roughness = 0.58
		material.rim_enabled = true
		material.rim = 0.35
		material.rim_tint = 0.6
		_terrain_glazed = true


# --- authored content ------------------------------------------------------


func _build_glacier_exploration() -> void:
	var landing := get_node("LandingRegion") as Node3D
	var content := Node3D.new()
	content.name = EXPLORATION_ROOT_NAME
	landing.add_child(content)
	var slate := _material(Color("2f3a44"))
	var packed_snow := _material(Color("aebdc6"), 0.9)
	var ice := _ice_material(Color("9fd3e8"))
	var deep_ice := _ice_material(Color("6fb3d4"))
	var hut_paint := _material(Color("c2522d"), 0.6)
	var hazard := _material(Color("e98a2c"), 0.6)
	var metal := _material(Color("46525c"), 0.5)
	var survey_lamp := _lamp_material(SURVEY_BEACON_COLOR)
	var return_lamp := _lamp_material(RETURN_BEACON_COLOR)
	(get_node("LandingRegion/PadVisual") as MeshInstance3D).material_override = slate

	# High-visibility orange pad edges read against pale ice from the corridor.
	for side in [-1.0, 1.0]:
		_box(content, "PadEdge%s" % side, Vector3(side * 12.5, 0.055, 0), Vector3(0.25, 0.025, 26), hazard)
		for z in [-12.0, 12.0]:
			_box(content, "PadCorner%s_%s" % [side, z], Vector3(side * 10.0, 0.055, z), Vector3(5, 0.025, 0.25), hazard)

	_build_trail(content, "SurveyTrail", SURVEY_TRAIL, packed_snow)
	_build_trail(content, "ReturnTrail", RETURN_TRAIL, packed_snow)
	_build_route_beacons(content, metal)

	# Survey beacon trailhead: a mast with an orange lamp and a signboard.
	var trailhead := Node3D.new()
	trailhead.name = "SurveyBeaconTrailhead"
	content.add_child(trailhead)
	trailhead.position = Vector3(-26.0, 0.0, -19.0)
	_box(trailhead, "BeaconMast", Vector3(0, 3.0, 0), Vector3(0.2, 6.0, 0.2), metal)
	_prop(trailhead, "BeaconLamp", Vector3(0, 6.2, 0), _sphere(0.32, 8, 4), survey_lamp)
	_light(trailhead, "BeaconLight", Vector3(0, 6.0, 0), SURVEY_BEACON_COLOR, 1.1, 16.0)
	var sign := MeshInstance3D.new()
	sign.name = "IceCoreSurveySign"
	var lettering := TextMesh.new()
	lettering.text = "ICE-CORE SURVEY  >\nDRILL RIG  /  SERACS  /  RIDGE GAUGE\nSUIT HEATER DRAINS - WARM UP AT THE HUT"
	lettering.font_size = 44
	lettering.pixel_size = 0.0055
	sign.mesh = lettering
	sign.position = Vector3(-1.2, 1.9, 4.2)
	sign.rotation.y = PI * 0.5
	var ink := _material(Color("ffe2b8"))
	ink.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	sign.material_override = ink
	trailhead.add_child(sign)
	_box(sign, "SignBackboard", Vector3(0, 0, -0.12), Vector3(4.8, 1.4, 0.18), metal)
	for side in [-1.0, 1.0]:
		_box(sign, "Signpost%s" % side, Vector3(side * 1.8, -0.95, -0.13), Vector3(0.16, 2.0, 0.16), metal)
	_anchor(content, SURVEY_ANCHOR_NAMES[0], SURVEY_ANCHOR_POSITIONS[0])

	_build_drill_rig(content, hut_paint, metal, slate, ice, hazard)
	_build_serac_field(content, ice, deep_ice)
	_build_pressure_ridge(content, deep_ice, metal, return_lamp)
	_build_ice_scatter(content, ice)
	_build_ground_haze(content)


func _build_trail(parent: Node3D, trail_name: String, points: Array, material: Material) -> void:
	for i in range(points.size() - 1):
		var start: Vector3 = points[i]
		var finish: Vector3 = points[i + 1]
		var direction := finish - start
		var strip := _box(parent, "%s%d" % [trail_name, i], (start + finish) * 0.5 + Vector3.UP * 0.03,
			Vector3(2.4, 0.03, direction.length() + 0.6), material)
		strip.rotation.y = atan2(direction.x, direction.z)


## One MultiMesh of posts and one of lamp heads light both trails: orange on the
## survey route, cyan on the way home. Two nodes, no lights.
func _build_route_beacons(parent: Node3D, post_material: Material) -> void:
	var placements: Array[Transform3D] = []
	var colors: Array[Color] = []
	for trail in [SURVEY_TRAIL, RETURN_TRAIL]:
		var color := SURVEY_BEACON_COLOR if trail == SURVEY_TRAIL else RETURN_BEACON_COLOR
		var side := 1.0
		for i in range(trail.size() - 1):
			var start: Vector3 = trail[i]
			var finish: Vector3 = trail[i + 1]
			var direction := finish - start
			var edge := Vector3(direction.z, 0, -direction.x).normalized() * 1.7
			var count := maxi(1, int(direction.length() / 7.0))
			for j in count:
				var point := start.lerp(finish, (float(j) + 0.5) / float(count)) + edge * side
				side = -side
				placements.append(Transform3D(Basis.IDENTITY, point))
				colors.append(color)
	var posts := MultiMesh.new()
	posts.transform_format = MultiMesh.TRANSFORM_3D
	var post_mesh := BoxMesh.new()
	post_mesh.size = Vector3(0.14, 1.1, 0.14)
	posts.mesh = post_mesh
	posts.instance_count = placements.size()
	var heads := MultiMesh.new()
	heads.transform_format = MultiMesh.TRANSFORM_3D
	heads.use_colors = true
	var head_mesh := BoxMesh.new()
	head_mesh.size = Vector3(0.24, 0.16, 0.24)
	heads.mesh = head_mesh
	heads.instance_count = placements.size()
	for index in placements.size():
		posts.set_instance_transform(index, placements[index].translated(Vector3.UP * 0.55))
		heads.set_instance_transform(index, placements[index].translated(Vector3.UP * 1.18))
		heads.set_instance_color(index, colors[index])
	var post_instance := MultiMeshInstance3D.new()
	post_instance.name = "RouteBeaconPosts"
	post_instance.multimesh = posts
	post_instance.material_override = post_material
	post_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(post_instance)
	var head_material := StandardMaterial3D.new()
	head_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	head_material.vertex_color_use_as_albedo = true
	var head_instance := MultiMeshInstance3D.new()
	head_instance.name = "RouteBeaconLamps"
	head_instance.multimesh = heads
	head_instance.material_override = head_material
	head_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(head_instance)


## The ice-core drill rig: a tripod derrick over a core hole, a rack of cut
## cores, and a heated orange hut whose warmth refills a suit heater.
func _build_drill_rig(parent: Node3D, hut_paint: Material, metal: Material,
		slate: Material, ice: Material, hazard: Material) -> void:
	var rig := Node3D.new()
	rig.name = "IceCoreDrillRig"
	parent.add_child(rig)
	var apex := Vector3(-56.0, 7.2, -52.0)
	for leg_index in 3:
		var angle := float(leg_index) * TAU / 3.0 + 0.4
		var foot := Vector3(-56.0 + cos(angle) * 2.4, 0.0, -52.0 + sin(angle) * 2.4)
		var leg := _box(rig, "DerrickLeg%d" % leg_index, (foot + apex) * 0.5,
			Vector3(0.16, foot.distance_to(apex), 0.16), metal)
		# The box's long axis is local +Y; lean it from the foot to the apex.
		leg.basis = Basis(Quaternion(Vector3.UP, (apex - foot).normalized()))
	_box(rig, "DerrickHead", apex, Vector3(0.7, 0.5, 0.7), hazard)
	var string_mesh := CylinderMesh.new()
	string_mesh.top_radius = 0.08
	string_mesh.bottom_radius = 0.08
	string_mesh.height = 7.0
	string_mesh.radial_segments = 8
	_prop(rig, "DrillString", Vector3(-56.0, 3.6, -52.0), string_mesh, metal)
	_box(rig, "CoreHoleCollar", Vector3(-56.0, 0.1, -52.0), Vector3(1.2, 0.2, 1.2), slate)
	var crate := _box(rig, "CoreCrate", Vector3(-52.6, 0.35, -49.2), Vector3(1.8, 0.7, 0.9), slate, true)
	for core_index in 3:
		var core_mesh := CylinderMesh.new()
		core_mesh.top_radius = 0.09
		core_mesh.bottom_radius = 0.09
		core_mesh.height = 1.5
		core_mesh.radial_segments = 8
		var core := _prop(crate, "IceCore%d" % core_index, Vector3(0.0, 0.42, -0.28 + float(core_index) * 0.28), core_mesh, ice)
		core.rotation.z = PI * 0.5
	var hut := _box(rig, "HeatedHut", Vector3(-62.0, 1.4, -42.0), Vector3(5.0, 2.8, 4.0), hut_paint, true)
	_box(hut, "HutRoof", Vector3(0, 1.55, 0), Vector3(5.6, 0.3, 4.6), slate)
	_box(hut, "HutDoor", Vector3(2.51, -0.35, -0.6), Vector3(0.04, 2.0, 1.1), metal)
	var window := _box(hut, "HutWindowGlow", Vector3(2.52, 0.3, 0.95), Vector3(0.03, 0.7, 0.9),
		_lamp_material(Color("ffb46a")))
	window.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_light(rig, "HutWarmthLight", HEAT_SHELTER_POSITION + Vector3(0.8, 2.2, 0.0), Color("ffb070"), 1.4, 9.0)
	_anchor(parent, HEAT_SHELTER_ANCHOR_NAME, HEAT_SHELTER_POSITION)
	_anchor(parent, SURVEY_ANCHOR_NAMES[1], SURVEY_ANCHOR_POSITIONS[1])


## Leaning, faceted ice spires north of the route. Five carry collision so the
## field reads as solid from up close; the rest are silhouette only.
func _build_serac_field(parent: Node3D, ice: Material, deep_ice: Material) -> void:
	var field := Node3D.new()
	field.name = "SeracField"
	parent.add_child(field)
	for index in SERAC_POSITIONS.size():
		var point: Vector3 = SERAC_POSITIONS[index]
		var spire := CylinderMesh.new()
		spire.top_radius = 0.25 + float(index % 3) * 0.2
		spire.bottom_radius = 1.6 + float(index % 4) * 0.35
		spire.height = 4.5 + float((index * 7) % 5) * 1.6
		spire.radial_segments = 5
		spire.rings = 1
		var solid := index % 2 == 0
		var visual := _prop(field, "Serac%d" % index, point + Vector3.UP * spire.height * 0.45, spire,
			ice if index % 3 else deep_ice,
			Vector3(spire.bottom_radius * 1.4, spire.height, spire.bottom_radius * 1.4) if solid else Vector3.ZERO)
		visual.rotation = Vector3(0.12 * sin(float(index) * 1.9), float(index) * 1.3, 0.14 * cos(float(index) * 2.3))
	# A stone cairn marks the serac viewpoint on the trail.
	for stone_index in 3:
		var stone := _sphere(0.55 - float(stone_index) * 0.14, 6, 3)
		_prop(field, "ViewpointCairn%d" % stone_index,
			Vector3(-6.0, 0.35 + float(stone_index) * 0.62, -71.5), stone, _material(Color("59636b")))


## A pressure ridge of tilted ice slabs and the strain gauge the survey reads.
func _build_pressure_ridge(parent: Node3D, deep_ice: Material, metal: Material,
		lamp: Material) -> void:
	var ridge := Node3D.new()
	ridge.name = "PressureRidge"
	parent.add_child(ridge)
	for index in RIDGE_SLABS.size():
		var point: Vector3 = RIDGE_SLABS[index]
		var height := 1.6 + float((index * 5) % 4) * 0.5
		var slab := _box(ridge, "RidgeSlab%d" % index, point + Vector3.UP * height * 0.35,
			Vector3(4.6, height, 2.2), deep_ice, true)
		slab.rotation = Vector3(0.35 * (1.0 if index % 2 else -1.0), 0.3 + float(index) * 0.17, 0.12)
	var gauge := Node3D.new()
	gauge.name = "StrainGauge"
	ridge.add_child(gauge)
	gauge.position = Vector3(32.5, 0.0, -59.5)
	_box(gauge, "GaugeMast", Vector3(0, 2.0, 0), Vector3(0.18, 4.0, 0.18), metal)
	_box(gauge, "GaugeCrossbar", Vector3(0, 3.6, 0), Vector3(2.4, 0.12, 0.12), metal)
	_prop(gauge, "GaugeLamp", Vector3(0, 4.2, 0), _sphere(0.26, 8, 4), lamp)
	_box(gauge, "GaugeHousing", Vector3(-0.9, 1.1, -0.9), Vector3(0.6, 0.5, 0.35), metal)
	_box(gauge, "GaugeDial", Vector3(-0.9, 1.1, -0.71), Vector3(0.4, 0.3, 0.02), lamp)
	_anchor(parent, SURVEY_ANCHOR_NAMES[2], SURVEY_ANCHOR_POSITIONS[2])


## Wind-cut sastrugi, glossy glaze patches and dark boulders breaking through
## the ice, each one MultiMesh, scattered off the pad, the approach corridor and
## both trails with a fixed seed.
func _build_ice_scatter(parent: Node3D, ice: Material) -> void:
	var random := RandomNumberGenerator.new()
	random.seed = TERRAIN_SEED
	var wind := Vector3(-21.0, 0.0, 8.0).normalized()
	var wind_yaw := atan2(wind.x, wind.z)
	var sastrugi: Array[Transform3D] = []
	var glaze: Array[Transform3D] = []
	var boulders: Array[Transform3D] = []
	var attempts := 0
	while (sastrugi.size() < 56 or glaze.size() < 14 or boulders.size() < 14) and attempts < 2000:
		attempts += 1
		var angle := random.randf_range(-PI, PI)
		var radius := random.randf_range(18.0, 92.0)
		var point := Vector3(cos(angle) * radius, 0.0, sin(angle) * radius)
		if not _scatter_point_clear(point):
			continue
		if sastrugi.size() < 56:
			var scale := random.randf_range(0.7, 1.5)
			sastrugi.append(Transform3D(
				Basis(Vector3.UP, wind_yaw + random.randf_range(-0.15, 0.15)).scaled(Vector3(scale, scale, scale)),
				point + Vector3.UP * 0.05))
		elif glaze.size() < 14:
			var spread := random.randf_range(2.0, 5.5)
			glaze.append(Transform3D(Basis.IDENTITY.scaled(Vector3(spread, 1.0, spread * 0.7)),
				point + Vector3.UP * 0.02))
		elif boulders.size() < 14:
			var size := random.randf_range(0.6, 1.6)
			boulders.append(Transform3D(Basis(Vector3.UP, angle).scaled(Vector3(size, size * 0.7, size)),
				point + Vector3.UP * size * 0.2))
	var ridge_mesh := BoxMesh.new()
	ridge_mesh.size = Vector3(0.5, 0.14, 2.8)
	_multimesh(parent, "WindSastrugi", ridge_mesh, sastrugi, _material(Color("dfe9ef"), 0.7))
	var glaze_mesh := CylinderMesh.new()
	glaze_mesh.top_radius = 1.0
	glaze_mesh.bottom_radius = 1.0
	glaze_mesh.height = 0.02
	glaze_mesh.radial_segments = 16
	var glaze_material := _ice_material(Color("bfe6f2"))
	glaze_material.roughness = 0.06
	_multimesh(parent, "IceGlazePatches", glaze_mesh, glaze, glaze_material)
	_multimesh(parent, "FrozenBoulders", _sphere(1.0, 6, 3), boulders, _material(Color("4a5560")))


func _scatter_point_clear(point: Vector3) -> bool:
	# Pad, approach corridor and the parked craft.
	if absf(point.x) < 20.0 and point.z > -22.0:
		return false
	if absf(point.x) < 50.0 and point.z > 0.0:
		return false
	for trail in [SURVEY_TRAIL, RETURN_TRAIL]:
		for i in range(trail.size() - 1):
			if _distance_to_segment(point, trail[i], trail[i + 1]) < 4.0:
				return false
	for serac: Vector3 in SERAC_POSITIONS:
		if point.distance_to(serac) < 4.0:
			return false
	if point.distance_to(Vector3(-60.0, 0.0, -46.0)) < 9.0 \
			or point.distance_to(Vector3(-26.0, 0.0, -19.0)) < 6.0 \
			or (point.x > 30.0 and point.x < 68.0 and point.z < -54.0 and point.z > -72.0):
		return false
	return true


## Drifting ice haze: one wide translucent sheet a little above the ice whose
## noise scrolls with Rime's authored wind. UV-space animation, so origin
## rebases need no update; view-distance fade hides the sheet's edge.
func _build_ground_haze(parent: Node3D) -> void:
	var plane := PlaneMesh.new()
	plane.size = Vector2(260.0, 260.0)
	var haze := MeshInstance3D.new()
	haze.name = "DriftingIceHaze"
	haze.mesh = plane
	haze.position = Vector3(0.0, 0.7, -20.0)
	haze.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	haze.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
	var shader := Shader.new()
	shader.code = """
shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled;

uniform vec2 wind_uv = vec2(-0.0081, 0.0031);
uniform vec3 haze_color : source_color = vec3(0.86, 0.92, 0.96);

float rime_hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float rime_noise(vec2 p) {
	vec2 cell = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(rime_hash(cell), rime_hash(cell + vec2(1.0, 0.0)), f.x),
		mix(rime_hash(cell + vec2(0.0, 1.0)), rime_hash(cell + vec2(1.0, 1.0)), f.x), f.y);
}

void fragment() {
	vec2 p = UV * 26.0 + wind_uv * TIME * 26.0;
	float drift = rime_noise(p) * 0.6 + rime_noise(p * 2.7 + vec2(3.1, 7.4)) * 0.4;
	float streak = smoothstep(0.42, 0.85, drift);
	vec2 edge = min(UV, vec2(1.0) - UV);
	float edge_fade = smoothstep(0.0, 0.18, min(edge.x, edge.y));
	float near_fade = smoothstep(1.5, 6.0, length(VERTEX));
	ALBEDO = haze_color;
	ALPHA = streak * 0.28 * edge_fade * near_fade;
}
"""
	var material := ShaderMaterial.new()
	material.shader = shader
	haze.material_override = material
	parent.add_child(haze)


# --- helpers -------------------------------------------------------------------


func _material(color: Color, roughness: float = 0.88) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = roughness
	return material


func _ice_material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.16
	material.metallic_specular = 0.8
	material.rim_enabled = true
	material.rim = 0.5
	material.rim_tint = 0.7
	return material


func _lamp_material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = color
	return material


func _sphere(radius: float, segments: int, rings: int) -> SphereMesh:
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	mesh.radial_segments = segments
	mesh.rings = rings
	return mesh


func _box(parent: Node3D, prop_name: String, point: Vector3, size: Vector3,
		material: Material, solid: bool = false) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	return _prop(parent, prop_name, point, mesh, material, size if solid else Vector3.ZERO)


func _prop(parent: Node3D, prop_name: String, point: Vector3, mesh: Mesh,
		material: Material, collision_size: Vector3 = Vector3.ZERO) -> MeshInstance3D:
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


func _multimesh(parent: Node3D, node_name: String, mesh: Mesh,
		transforms: Array[Transform3D], material: Material) -> MultiMeshInstance3D:
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.mesh = mesh
	multimesh.instance_count = transforms.size()
	for index in transforms.size():
		multimesh.set_instance_transform(index, transforms[index])
	var instance := MultiMeshInstance3D.new()
	instance.name = node_name
	instance.multimesh = multimesh
	instance.material_override = material
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(instance)
	return instance


## Shadowless, short-range practical light. The scene carries at most
## `LIGHT_BUDGET` of these.
func _light(parent: Node3D, light_name: String, point: Vector3, color: Color,
		energy: float, range_m: float) -> OmniLight3D:
	var light := OmniLight3D.new()
	light.name = light_name
	light.position = point
	light.light_color = color
	light.light_energy = energy
	light.omni_range = range_m
	light.shadow_enabled = false
	parent.add_child(light)
	return light


## Interaction and heat anchors inherit the region frame and every rebase.
func _anchor(parent: Node3D, anchor_name: String, point: Vector3) -> Marker3D:
	var anchor := Marker3D.new()
	anchor.name = anchor_name
	anchor.position = point
	parent.add_child(anchor)
	return anchor


static func _distance_to_segment(point: Vector3, a: Vector3, b: Vector3) -> float:
	var ab := b - a
	var t := clampf((point - a).dot(ab) / maxf(ab.length_squared(), 0.0001), 0.0, 1.0)
	return point.distance_to(a + ab * t)


static func _mesh_triangles(mesh: Mesh) -> int:
	if mesh == null:
		return 0
	var triangles := 0
	for surface in mesh.get_surface_count():
		var arrays := mesh.surface_get_arrays(surface)
		var indices := arrays[Mesh.ARRAY_INDEX] as PackedInt32Array \
			if arrays[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
		if not indices.is_empty():
			triangles += indices.size() / 3
		else:
			triangles += (arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array).size() / 3
	return triangles


static func _count_nodes(node: Node) -> int:
	var count := 1
	for child in node.get_children():
		count += _count_nodes(child)
	return count
