class_name TorrentHeroPresentation
extends Node3D

signal lod_changed(lod_index: int)

## Runtime boundary for the production-intent Blender Torrent presentation.
##
## The imported GLB is visual-only. HeroShip continues to own collision, flight,
## boarding, weapons, cameras, damage and lease authority. The older B5-observed
## macroform remains an evidence-bounded far LOD rather than masquerading as the
## close-range final craft.

const SCHEMA_VERSION := 1
const HERO_ASSET_PATH := "res://assets/models/torrent/hero/torrent_hero_art.glb"
const MANIFEST_PATH := "res://assets/models/torrent/hero/torrent_hero_asset_manifest.json"
const CRITICAL_ENGINE_CORE_DROP := Vector3(0.0, -0.22, 0.06)
const CRITICAL_ENGINE_CORE_CANT_DEGREES := 42.0

const REQUIRED_ROOTS := [
	"LOD0",
	"LOD1",
	"CockpitArt",
	"CanopyPivot",
	"SemanticAnchors",
]
const REQUIRED_ANCHORS := {
	&"PilotSeatAnchor": Vector3(0.0, 1.56, -0.02),
	&"BoardingEntry": Vector3(-1.42, 2.32, 0.18),
	&"BoardingPoint": Vector3(-3.2, 0.05, 0.65),
	&"ExitPoint": Vector3(-7.6, -1.0, 0.75),
	&"LeftMuzzle": Vector3(-2.82, 0.42, -3.42),
	&"RightMuzzle": Vector3(2.82, 0.42, -3.42),
	&"CockpitCamera": Vector3(0.0, 3.32, -0.52),
}

@export_range(15.0, 120.0, 0.5) var lod_switch_distance := 42.0
@export_range(0.0, 20.0, 0.5) var lod_hysteresis := 4.0

var _asset_root: Node3D
var _imported_container: Node3D
var _lod0: Node3D
var _lod1: Node3D
var _cockpit_art: Node3D
var _canopy_pivot: Node3D
var _semantic_anchors: Node3D
var _built := false
var _active_lod := 0
var _runtime_materials: Dictionary = {}
var _integrity_nodes: Dictionary = {}
var _integrity_meshes: Dictionary = {}
var _integrity_materials: Dictionary = {}
var _engine_core_nominal_transforms: Dictionary = {}
var _asset_root_parent_id := 0
var _built_lod_switch_distance := 0.0
var _built_lod_hysteresis := 0.0
var _manifest_glb_sha256 := ""
var _manifest_runtime_triangles := 0
var _manifest_runtime_mesh_counts: Dictionary = {}
var _manifest_runtime_mesh_budget := 0


func _ready() -> void:
	_build_once()
	_apply_lod(0)
	set_process(true)


func _process(_delta: float) -> void:
	if not _built or _asset_root == null:
		return
	_sync_engine_damage_silhouette()
	var viewport := get_viewport()
	var camera := viewport.get_camera_3d() if viewport != null else null
	if camera == null:
		return
	update_lod_for_distance(camera.global_position.distance_to(global_position))


func _build_once() -> void:
	if _built:
		return
	_built = true
	var packed := load(HERO_ASSET_PATH) as PackedScene
	if packed == null:
		push_error("Unable to load the Blender-authored Torrent hero asset")
		return
	var imported := packed.instantiate() as Node3D
	if imported == null:
		push_error("Unable to instantiate the Blender-authored Torrent hero asset")
		return
	imported.name = "TorrentHeroImport"
	add_child(imported)
	_imported_container = imported
	_asset_root = imported.get_node_or_null("TorrentHeroArt") as Node3D
	if _asset_root == null:
		_asset_root = imported.find_child("TorrentHeroArt", true, false) as Node3D
	if _asset_root == null:
		for candidate in imported.find_children("*", "Node3D", true, false):
			if (candidate as Node3D).has_node("LOD0") and (candidate as Node3D).has_node("LOD1"):
				_asset_root = candidate as Node3D
				break
	if _asset_root == null and imported.has_node("LOD0"):
		_asset_root = imported
	if _asset_root == null:
		push_error("Blender-authored Torrent hierarchy root is missing")
		return
	_lod0 = _asset_root.get_node_or_null("LOD0") as Node3D
	_lod1 = _asset_root.get_node_or_null("LOD1") as Node3D
	_cockpit_art = _asset_root.get_node_or_null("CockpitArt") as Node3D
	_canopy_pivot = _asset_root.get_node_or_null("CanopyPivot") as Node3D
	_semantic_anchors = _asset_root.get_node_or_null("SemanticAnchors") as Node3D
	_configure_runtime_materials()
	_configure_lod_ranges()
	_capture_integrity_contract()


func _configure_runtime_materials() -> void:
	_runtime_materials = {
		&"WarmIvoryHull": _pbr_material(Color("e8e2cf"), 0.08, 0.48, true),
		&"IvorySecondary": _pbr_material(Color("aeb2a5"), 0.16, 0.42, true),
		# Secondary structure. `docs/TORRENT_2011_RECONSTRUCTION_SPEC.md` puts the
		# finish inside the modern boundary and explicitly welcomes subtle
		# roughness and normal maps while forbidding dense noisy greebling that
		# would erase the large clean planes, so these five roles take relief
		# and a widened material response and the two hull roles are left
		# alone. Before this pass the canopy rails, dorsal spar, gear, aft
		# grille, engine collars, heat panels, seat and livery band ran at
		# roughness 0.28/0.22/0.66/0.43/0.64 with no map at all, and the
		# baseline touchdown frame shows every one of them as a flat slab
		# beside a panelled hull.
		&"GraphiteMachinery": _structural_material(Color("10191c"), 0.36, 0.62, 3.0, 1.10),
		&"ExposedAlloy": _structural_material(Color("434b4d"), 0.84, 0.18, 3.5, 0.90),
		&"CyanStatus": _emissive_material(Color("0aa3b3"), Color("0cc6dc"), 2.2),
		&"AmberPanel": _amber_panel_material(),
		&"CrimsonSeat": _structural_material(Color("8b1622"), 0.04, 0.78, 6.0, 0.90),
		&"CrimsonLivery": _structural_material(Color("8f1723"), 0.06, 0.34, 3.0, 0.70),
		&"ThermalCeramic": _structural_material(Color("171b1a"), 0.12, 0.86, 2.4, 1.20),
		&"NeutralCanopyGlass": _canopy_material(),
	}
	if _asset_root == null:
		return
	for candidate in _asset_root.find_children("*", "MeshInstance3D", true, false):
		var mesh_instance := candidate as MeshInstance3D
		var source := mesh_instance.get_active_material(0)
		var role := StringName(source.resource_name) if source != null else &""
		var replacement := _runtime_materials.get(role) as Material
		if replacement != null:
			mesh_instance.material_override = replacement
			mesh_instance.set_meta("torrent_material_role", role)
			if role in [&"CyanStatus", &"NeutralCanopyGlass"]:
				mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


func _pbr_material(
	color: Color,
	metallic_value: float,
	roughness_value: float,
	use_hull_microdetail := false
) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.metallic = metallic_value
	material.roughness = roughness_value
	material.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL
	material.diffuse_mode = BaseMaterial3D.DIFFUSE_BURLEY
	material.specular_mode = BaseMaterial3D.SPECULAR_SCHLICK_GGX
	if use_hull_microdetail:
		var albedo := load("res://assets/materials/torrent-hull-albedo-v1.png") as Texture2D
		var normal := load("res://assets/materials/torrent-hull-normal-v1.png") as Texture2D
		var roughness := load("res://assets/materials/torrent-hull-roughness-v1.png") as Texture2D
		material.albedo_texture = albedo
		material.normal_enabled = normal != null
		material.normal_texture = normal
		material.normal_scale = 0.18
		material.roughness_texture = roughness
		material.roughness_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_RED
		material.uv1_triplanar = false
		material.uv1_scale = Vector3.ONE
		material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
		material.clearcoat_enabled = true
		material.clearcoat = 0.34
		material.clearcoat_roughness = 0.30
	return material


## A secondary-structure material: flat scalar colour plus the Torrent's own
## registered normal map at a machined-part frequency. The hull roles keep
## their authored UV0 mapping; this reaches the untextured population only. It
## binds no albedo texture, so `EXPECTED_BODY_TONE` and the frozen CIEDE2000
## floors still read the exact colours above, and no roughness map, so each
## role's roughness scalar is the roughness the player sees.
func _structural_material(
	color: Color,
	metallic_value: float,
	roughness_value: float,
	texture_scale: float,
	normal_strength: float
) -> StandardMaterial3D:
	var material := _pbr_material(color, metallic_value, roughness_value)
	ShipSurfaceDetail.bind_structural_detail(
		material,
		load("res://assets/materials/torrent-hull-normal-v1.png") as Texture2D,
		texture_scale,
		normal_strength
	)
	return material


func _emissive_material(color: Color, emission: Color, energy: float) -> StandardMaterial3D:
	var material := _pbr_material(color, 0.12, 0.28)
	material.emission_enabled = true
	material.emission = emission
	material.emission_energy_multiplier = energy
	return material


func _canopy_material() -> StandardMaterial3D:
	var material := _pbr_material(Color(0.09, 0.25, 0.28, 0.20), 0.12, 0.08)
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.render_priority = 1
	return material


func _amber_panel_material() -> StandardMaterial3D:
	# B5 supports a small pale-yellow translucent panel, but does not establish
	# its function. Keep the authored object legible without turning it into a
	# second opaque display or an unsupported shield-like slab.
	var material := _pbr_material(Color(0.88, 0.70, 0.30, 0.28), 0.08, 0.32)
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.emission_enabled = true
	material.emission = Color(0.42, 0.24, 0.04)
	material.emission_energy_multiplier = 0.42
	return material


func _configure_lod_ranges() -> void:
	# Per-instance visibility ranges switch each imported part from its own AABB
	# centre, producing a visibly mixed ship across the handoff. Disable those
	# ranges and switch the two complete authored hierarchies atomically instead.
	if _lod0 != null:
		for visual in _lod0.find_children("*", "GeometryInstance3D", true, false):
			var geometry := visual as GeometryInstance3D
			geometry.visibility_range_begin = 0.0
			geometry.visibility_range_end = 0.0
			geometry.visibility_range_begin_margin = 0.0
			geometry.visibility_range_end_margin = 0.0
			geometry.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_DISABLED
	if _lod1 != null:
		for visual in _lod1.find_children("*", "GeometryInstance3D", true, false):
			var geometry := visual as GeometryInstance3D
			geometry.visibility_range_begin = 0.0
			geometry.visibility_range_end = 0.0
			geometry.visibility_range_begin_margin = 0.0
			geometry.visibility_range_end_margin = 0.0
			geometry.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_DISABLED


func update_lod_for_distance(distance_metres: float) -> void:
	if not is_finite(distance_metres):
		return
	var safe_hysteresis := clampf(lod_hysteresis, 0.0, lod_switch_distance - 0.5)
	if _active_lod == 0 and distance_metres > lod_switch_distance + safe_hysteresis:
		_apply_lod(1)
	elif _active_lod == 1 and distance_metres < lod_switch_distance - safe_hysteresis:
		_apply_lod(0)


func _apply_lod(lod_index: int) -> void:
	var previous_lod := _active_lod
	_active_lod = clampi(lod_index, 0, 1)
	if _lod0 != null:
		_lod0.visible = _active_lod == 0
	if _lod1 != null:
		_lod1.visible = _active_lod == 1
	# The detailed cabin/canopy belong to the close presentation. LOD1 carries
	# the complete unbounded flight silhouette, so no legacy fallback is needed.
	if _cockpit_art != null:
		_cockpit_art.visible = _active_lod == 0
	if _canopy_pivot != null:
		_canopy_pivot.visible = _active_lod == 0
	if _active_lod != previous_lod:
		lod_changed.emit(_active_lod)


func get_active_lod() -> int:
	return _active_lod


func get_canopy_pivot() -> Node3D:
	return _canopy_pivot if _canopy_pivot != null and is_instance_valid(_canopy_pivot) else null


func get_asset_root() -> Node3D:
	return _asset_root if _asset_root != null and is_instance_valid(_asset_root) else null


func get_lod0_root() -> Node3D:
	return _lod0 if _lod0 != null and is_instance_valid(_lod0) else null


func get_lod1_root() -> Node3D:
	return _lod1 if _lod1 != null and is_instance_valid(_lod1) else null


func get_cockpit_art_root() -> Node3D:
	return _cockpit_art if _cockpit_art != null and is_instance_valid(_cockpit_art) else null


func get_semantic_anchor(anchor_name: StringName) -> Node3D:
	if _semantic_anchors == null or not is_instance_valid(_semantic_anchors):
		return null
	return _semantic_anchors.get_node_or_null(NodePath(String(anchor_name))) as Node3D


func get_engine_plumes() -> Array[MeshInstance3D]:
	var result: Array[MeshInstance3D] = []
	if _asset_root == null or not is_instance_valid(_asset_root):
		return result
	for candidate in _asset_root.find_children("*EnginePlume*", "MeshInstance3D", true, false):
		result.append(candidate as MeshInstance3D)
	return result


func get_engine_cores() -> Array[MeshInstance3D]:
	var result: Array[MeshInstance3D] = []
	if _asset_root == null or not is_instance_valid(_asset_root):
		return result
	for candidate in _asset_root.find_children("*EngineCore", "MeshInstance3D", true, false):
		result.append(candidate as MeshInstance3D)
	return result


## The production component presenter already makes critical engine damage
## static and non-flashing by suppressing one exhaust. Repose the retained
## starboard core face in that same state so the failed mount also reads by
## silhouette from the normal aft chase view. This observes presentation nodes
## only; it owns no thresholds, integrity, propulsion, collision, or authority.
func _sync_engine_damage_silhouette() -> void:
	if _lod0 == null or not is_instance_valid(_lod0):
		return
	var lod0_plumes: Array[Node] = _lod0.find_children("*EnginePlume", "MeshInstance3D", true, false)
	var visible_plumes := 0
	for plume_variant in lod0_plumes:
		if (plume_variant as MeshInstance3D).visible:
			visible_plumes += 1
	var cores := get_engine_cores()
	var visible_cores := 0
	for core in cores:
		if core.visible:
			visible_cores += 1
	var critical := lod0_plumes.size() == 2 and visible_plumes == 1 and visible_cores > 0
	for core in cores:
		var nominal: Transform3D = _engine_core_nominal_transforms.get(
			core.get_instance_id(), core.transform
		)
		core.transform = (
			_critical_engine_core_transform(nominal)
			if critical and String(core.name).begins_with("Starboard")
			else nominal
		)


func get_engine_damage_silhouette_snapshot() -> Dictionary:
	_sync_engine_damage_silhouette()
	var cores: Array[Dictionary] = []
	var canted_count := 0
	for core in get_engine_cores():
		var nominal: Transform3D = _engine_core_nominal_transforms.get(
			core.get_instance_id(), core.transform
		)
		var canted := not core.transform.is_equal_approx(nominal)
		if canted:
			canted_count += 1
		cores.append({
			"name": StringName(core.name),
			"visible": core.visible,
			"transform": core.transform,
			"nominal_transform": nominal,
			"canted": canted,
			"mesh_instance_id": core.mesh.get_instance_id() if core.mesh != null else 0,
		})
	return {
		"stage": &"critical" if canted_count == 1 else &"nominal",
		"canted_core_count": canted_count,
		"core_count": cores.size(),
		"cores": cores,
		"cant_degrees": CRITICAL_ENGINE_CORE_CANT_DEGREES,
		"drop_offset": CRITICAL_ENGINE_CORE_DROP,
		"added_nodes": 0,
		"added_meshes": 0,
		"added_lights": 0,
		"gameplay_authority": false,
	}.duplicate(true)


func _critical_engine_core_transform(nominal: Transform3D) -> Transform3D:
	var result := nominal
	result.origin += CRITICAL_ENGINE_CORE_DROP
	result.basis = nominal.basis * Basis(
		Vector3.RIGHT,
		deg_to_rad(CRITICAL_ENGINE_CORE_CANT_DEGREES)
	)
	return result


func set_imported_canopy_visible(visible: bool) -> void:
	if _canopy_pivot != null and is_instance_valid(_canopy_pivot):
		_canopy_pivot.visible = visible


func set_canopy_fraction(open_fraction: float) -> void:
	if _canopy_pivot == null or not is_instance_valid(_canopy_pivot):
		return
	_canopy_pivot.rotation.x = deg_to_rad(63.0) * clampf(open_fraction, 0.0, 1.0)


func get_asset_audit_report() -> Dictionary:
	var errors := PackedStringArray()
	var raw_source_glb_path := _get_raw_source_glb_path()
	var raw_source_glb_sha256 := (
		FileAccess.get_sha256(raw_source_glb_path)
		if not raw_source_glb_path.is_empty() else ""
	)
	if (
		_imported_container == null
		or not is_instance_valid(_imported_container)
		or get_node_or_null(^"TorrentHeroImport") != _imported_container
		or _imported_container.get_parent() != self
		or _imported_container.top_level
		or not _imported_container.visible
		or not _imported_container.transform.is_equal_approx(Transform3D.IDENTITY)
	):
		errors.append("imported container identity or transform drifted")
	if top_level or not transform.is_equal_approx(Transform3D.IDENTITY):
		errors.append("presentation adapter transform authority drifted")
	if (
		_asset_root == null
		or not is_instance_valid(_asset_root)
		or not is_ancestor_of(_asset_root)
	):
		errors.append("Blender-authored hero root is missing")
	var live_asset_root: Node3D = _asset_root if _asset_root != null and is_instance_valid(_asset_root) else null
	var live_lod0: Node3D = _lod0 if _lod0 != null and is_instance_valid(_lod0) else null
	var live_lod1: Node3D = _lod1 if _lod1 != null and is_instance_valid(_lod1) else null
	var live_cockpit: Node3D = _cockpit_art if _cockpit_art != null and is_instance_valid(_cockpit_art) else null
	var live_canopy: Node3D = _canopy_pivot if _canopy_pivot != null and is_instance_valid(_canopy_pivot) else null
	for required_name in REQUIRED_ROOTS:
		var required_node := live_asset_root.get_node_or_null(NodePath(required_name)) if live_asset_root != null else null
		if required_node == null:
			errors.append("required imported root is missing: %s" % required_name)
		elif required_node != _required_cached_root(required_name):
			errors.append("required imported root identity was substituted: %s" % required_name)
	var lod0_meshes: Array[Node] = []
	if live_lod0 != null:
		lod0_meshes = live_lod0.find_children("*", "MeshInstance3D", true, false)
	var lod1_meshes: Array[Node] = []
	if live_lod1 != null:
		lod1_meshes = live_lod1.find_children("*", "MeshInstance3D", true, false)
	var lod0_triangles := _subtree_triangle_count(live_lod0)
	var lod1_triangles := _subtree_triangle_count(live_lod1)
	var total_mesh_count := live_asset_root.find_children("*", "MeshInstance3D", true, false).size() if live_asset_root != null else 0
	var near_surface_count := _subtree_surface_count(live_lod0) + _subtree_surface_count(live_cockpit) + _subtree_surface_count(live_canopy)
	var far_surface_count := _subtree_surface_count(live_lod1)
	if lod0_triangles < 45000:
		errors.append("close-range LOD0 lacks the authored triangle-density contract")
	if lod1_triangles < 6000:
		errors.append("mid-range LOD1 lacks the authored silhouette-density contract")
	if lod0_meshes.size() > 18 or lod1_meshes.size() > 5:
		errors.append("runtime LOD draw-node budget was exceeded")
	if total_mesh_count > 36 or near_surface_count > 32 or far_surface_count > 5:
		errors.append("runtime presentation surface budget was exceeded")
	if live_canopy == null:
		errors.append("articulated canopy pivot is missing")
	if _semantic_anchors == null:
		errors.append("semantic anchor hierarchy is missing")
	if live_asset_root != null and not live_asset_root.transform.is_equal_approx(Transform3D.IDENTITY):
		errors.append("imported hero root transform is not identity")
	if not visible or (live_asset_root != null and not live_asset_root.visible):
		errors.append("hero presentation visibility authority was disabled")
	if live_asset_root != null and (
		live_asset_root.get_parent() == null
		or live_asset_root.get_parent().get_instance_id() != _asset_root_parent_id
	):
		errors.append("imported hero root parent identity drifted")
	var forbidden_count := 0
	for type_name in [
		"CollisionObject3D", "CollisionShape3D", "Area3D", "Camera3D",
		"AudioStreamPlayer3D", "AnimationPlayer", "NavigationRegion3D",
	]:
		forbidden_count += find_children("*", type_name, true, false).size()
	if forbidden_count != 0:
		errors.append("imported visual subtree contains gameplay-authority nodes")
	for anchor_name: StringName in REQUIRED_ANCHORS:
		var anchor := get_semantic_anchor(anchor_name)
		if anchor == null:
			errors.append("semantic anchor is missing: %s" % anchor_name)
		elif anchor.position.distance_to(REQUIRED_ANCHORS[anchor_name]) > 0.002:
			errors.append("semantic anchor transform drift: %s" % anchor_name)
	for engine_part in get_engine_plumes() + get_engine_cores():
		if absf(engine_part.basis.z.normalized().dot(Vector3.BACK)) < 0.999:
			var nominal_core: Transform3D = _engine_core_nominal_transforms.get(
				engine_part.get_instance_id(), Transform3D.IDENTITY
			)
			if (
				String(engine_part.name).begins_with("Starboard")
				and String(engine_part.name).ends_with("EngineCore")
				and _node_transform_matches_contract(engine_part, nominal_core)
			):
				continue
			errors.append("aft engine axis drift: %s" % engine_part.name)
	if (
		not is_finite(lod_switch_distance)
		or not is_finite(lod_hysteresis)
		or not is_equal_approx(lod_switch_distance, _built_lod_switch_distance)
		or not is_equal_approx(lod_hysteresis, _built_lod_hysteresis)
		or lod_switch_distance < 15.0
		or lod_hysteresis < 0.0
		or lod_hysteresis >= lod_switch_distance
	):
		errors.append("whole-ship LOD switch configuration is invalid")
	for root in [live_lod0, live_lod1, live_cockpit, live_canopy]:
		if root == null:
			continue
		for visual in root.find_children("*", "GeometryInstance3D", true, false):
			var geometry := visual as GeometryInstance3D
			if (
				not is_zero_approx(geometry.visibility_range_begin)
				or not is_zero_approx(geometry.visibility_range_end)
			):
				errors.append("per-part LOD visibility range reintroduced: %s" % geometry.name)
				break
			var mesh_instance := geometry as MeshInstance3D
			var array_mesh := mesh_instance.mesh as ArrayMesh if mesh_instance != null else null
			if array_mesh == null:
				continue
			var serialized_surfaces: Array = array_mesh.get("_surfaces")
			for surface_value: Variant in serialized_surfaces:
				var surface: Dictionary = surface_value if surface_value is Dictionary else {}
				var internal_lods: Array = surface.get("lods", [])
				if not internal_lods.is_empty():
					errors.append("imported per-surface LOD reintroduced: %s" % geometry.name)
					break
	if live_lod0 != null and live_lod0.visible != (_active_lod == 0):
		errors.append("LOD0 visibility disagrees with the atomic LOD state")
	if live_lod1 != null and live_lod1.visible != (_active_lod == 1):
		errors.append("LOD1 visibility disagrees with the atomic LOD state")
	if live_cockpit != null and live_cockpit.visible != (_active_lod == 0):
		errors.append("cockpit visibility disagrees with the atomic LOD state")
	if live_canopy != null and live_canopy.visible != (_active_lod == 0):
		errors.append("canopy visibility disagrees with the atomic LOD state")
	_append_integrity_errors(errors, raw_source_glb_path, raw_source_glb_sha256)
	var canopy_glass := (
		live_canopy.get_node_or_null("CanopyGlass") as MeshInstance3D
		if live_canopy != null else null
	)
	var canopy_material := (
		canopy_glass.material_override as StandardMaterial3D
		if canopy_glass != null else null
	)
	if (
		canopy_material == null
		or canopy_material.transparency != BaseMaterial3D.TRANSPARENCY_ALPHA
		or canopy_material.albedo_color.a > 0.22
	):
		errors.append("close canopy material is not a bounded transparent glazing contract")
	for hull_role: StringName in [&"WarmIvoryHull", &"IvorySecondary"]:
		var hull_material := _runtime_materials.get(hull_role) as StandardMaterial3D
		if (
			hull_material == null
			or hull_material.albedo_texture == null
			or hull_material.albedo_texture.resource_path != "res://assets/materials/torrent-hull-albedo-v1.png"
			or hull_material.normal_texture == null
			or hull_material.normal_texture.resource_path != "res://assets/materials/torrent-hull-normal-v1.png"
			or hull_material.roughness_texture == null
			or hull_material.roughness_texture.resource_path != "res://assets/materials/torrent-hull-roughness-v1.png"
			or hull_material.uv1_triplanar
		):
			errors.append("hull material is not using the registered UV0 PBR map set: %s" % hull_role)
	return {
		"schema_version": SCHEMA_VERSION,
		"valid": errors.is_empty(),
		"errors": errors,
		"asset_path": "res://assets/models/torrent/hero/torrent_hero_art.glb",
		"source_path": "res://art_source/torrent/torrent_hero_v1.blend",
		"authorship": &"original_script_assisted_blender",
		"historical_geometry_authenticated": false,
		"gameplay_authority": false,
		"forbidden_authority_node_count": forbidden_count,
		"lod0_mesh_count": lod0_meshes.size(),
		"lod1_mesh_count": lod1_meshes.size(),
		"total_mesh_count": total_mesh_count,
		"lod0_triangle_count": lod0_triangles,
		"lod1_triangle_count": lod1_triangles,
		"near_surface_count": near_surface_count,
		"far_surface_count": far_surface_count,
		"canopy_pivot_path": get_path_to(live_canopy) if live_canopy != null else NodePath(),
		"canopy_pivot_instance_id": live_canopy.get_instance_id() if live_canopy != null else 0,
		"semantic_anchors_path": get_path_to(_semantic_anchors) if _semantic_anchors != null and is_instance_valid(_semantic_anchors) else NodePath(),
		"semantic_anchors_instance_id": _semantic_anchors.get_instance_id() if _semantic_anchors != null and is_instance_valid(_semantic_anchors) else 0,
		"lod_switch_distance_m": lod_switch_distance,
		"lod_hysteresis_m": lod_hysteresis,
		"active_lod": _active_lod,
		"far_lod_unbounded": true,
		"runtime_material_role_count": _runtime_materials.size(),
		"hull_texture_coordinate": &"UV0/TEXCOORD_0",
		"hull_triplanar": false,
		"runtime_triangle_count": _subtree_triangle_count(live_asset_root),
		"manifest_glb_sha256": _manifest_glb_sha256,
		"glb_hash_verification_mode": (
			&"raw_source_file_sha256"
			if not raw_source_glb_path.is_empty()
			else &"packaged_import_runtime_contract"
		),
		"raw_source_glb_hash_checked": not raw_source_glb_path.is_empty(),
		"raw_source_glb_hash_verified": (
			not raw_source_glb_path.is_empty()
			and not _manifest_glb_sha256.is_empty()
			and raw_source_glb_sha256 == _manifest_glb_sha256
		),
	}


func _required_cached_root(required_name: String) -> Node:
	var candidate: Node = null
	match required_name:
		"LOD0":
			candidate = _lod0
		"LOD1":
			candidate = _lod1
		"CockpitArt":
			candidate = _cockpit_art
		"CanopyPivot":
			candidate = _canopy_pivot
		"SemanticAnchors":
			candidate = _semantic_anchors
	return candidate if candidate != null and is_instance_valid(candidate) else null


func _capture_integrity_contract() -> void:
	_integrity_nodes.clear()
	_integrity_meshes.clear()
	_integrity_materials.clear()
	_engine_core_nominal_transforms.clear()
	_built_lod_switch_distance = lod_switch_distance
	_built_lod_hysteresis = lod_hysteresis
	_asset_root_parent_id = (
		_asset_root.get_parent().get_instance_id()
		if _asset_root != null and _asset_root.get_parent() != null else 0
	)
	var manifest := _read_manifest()
	_manifest_glb_sha256 = str(manifest.get("glb_sha256", ""))
	_manifest_runtime_triangles = int(manifest.get("mesh_triangles_exported_runtime", 0))
	var batching: Dictionary = manifest.get("runtime_static_batching", {})
	_manifest_runtime_mesh_counts = (batching.get("runtime_mesh_counts_by_root", {}) as Dictionary).duplicate(true)
	_manifest_runtime_mesh_budget = int(batching.get("runtime_mesh_instance_budget", 0))
	if _asset_root == null:
		return
	var nodes: Array[Node] = [_asset_root]
	nodes.append_array(_asset_root.find_children("*", "Node", true, false))
	for candidate in nodes:
		var relative_path := str(_asset_root.get_path_to(candidate))
		_integrity_nodes[relative_path] = {
			"instance_id": candidate.get_instance_id(),
			"class": candidate.get_class(),
			"parent_id": candidate.get_parent().get_instance_id() if candidate.get_parent() != null else 0,
			"transform": (candidate as Node3D).transform if candidate is Node3D else Transform3D.IDENTITY,
			"top_level": (candidate as Node3D).top_level if candidate is Node3D else false,
		}
		if candidate is MeshInstance3D:
			var mesh_instance := candidate as MeshInstance3D
			if String(mesh_instance.name).ends_with("EngineCore"):
				_engine_core_nominal_transforms[mesh_instance.get_instance_id()] = mesh_instance.transform
			var role := StringName(mesh_instance.get_meta("torrent_material_role", &""))
			_integrity_meshes[relative_path] = {
				"mesh_id": mesh_instance.mesh.get_instance_id() if mesh_instance.mesh != null else 0,
				"surface_count": mesh_instance.mesh.get_surface_count() if mesh_instance.mesh != null else 0,
				"triangle_count": _mesh_triangle_count(mesh_instance.mesh),
				"content_hash": _mesh_content_hash(mesh_instance.mesh),
				"material_role": role,
				"transform": mesh_instance.transform,
				"visible": mesh_instance.visible,
				"layers": mesh_instance.layers,
				"cast_shadow": mesh_instance.cast_shadow,
				"transparency": mesh_instance.transparency,
			}
	for role: StringName in _runtime_materials:
		var material := _runtime_materials[role] as StandardMaterial3D
		_integrity_materials[role] = _material_signature(material)


func _append_integrity_errors(
	errors: PackedStringArray,
	raw_source_glb_path: String,
	raw_source_glb_sha256: String
) -> void:
	if _asset_root == null or not is_instance_valid(_asset_root):
		return
	if _manifest_glb_sha256.is_empty():
		errors.append("runtime GLB manifest hash is missing")
	elif (
		not raw_source_glb_path.is_empty()
		and raw_source_glb_sha256 != _manifest_glb_sha256
	):
		errors.append("runtime GLB hash does not match its checked-in manifest")
	var nodes: Array[Node] = [_asset_root]
	nodes.append_array(_asset_root.find_children("*", "Node", true, false))
	if nodes.size() != _integrity_nodes.size():
		errors.append("imported hero node roster size drifted")
	for candidate in nodes:
		var relative_path := str(_asset_root.get_path_to(candidate))
		var expected_value: Variant = _integrity_nodes.get(relative_path)
		if not expected_value is Dictionary:
			errors.append("unexpected imported hero node: %s" % relative_path)
			continue
		var expected := expected_value as Dictionary
		if (
			candidate.get_instance_id() != int(expected.get("instance_id", 0))
			or candidate.get_class() != str(expected.get("class", ""))
			or candidate.get_parent() == null
			or candidate.get_parent().get_instance_id() != int(expected.get("parent_id", 0))
		):
			errors.append("imported hero node identity or parent drifted: %s" % relative_path)
		if candidate is Node3D:
			var node_3d := candidate as Node3D
			if node_3d.top_level != bool(expected.get("top_level", false)):
				errors.append("imported hero node top-level authority drifted: %s" % relative_path)
			var expected_transform: Transform3D = expected.get("transform", Transform3D.IDENTITY)
			if not _node_transform_matches_contract(node_3d, expected_transform):
				errors.append("imported hero node transform drifted: %s" % relative_path)
		if candidate is MeshInstance3D:
			_append_mesh_integrity_errors(candidate as MeshInstance3D, relative_path, errors)
	if _runtime_triangle_count() != _manifest_runtime_triangles:
		errors.append("live runtime triangle count no longer matches the manifest")
	if (
		_manifest_runtime_mesh_budget != 36
		or str(_read_manifest().get("runtime_static_batching", {}).get("strategy", ""))
			!= "per_semantic_root_per_material_static_join"
		or not bool(_read_manifest().get("runtime_static_batching", {}).get("source_preserved_in_blend", false))
	):
		errors.append("runtime static-batching manifest contract is invalid")
	for root_name: String in ["LOD0", "LOD1", "CockpitArt", "CanopyPivot"]:
		var root_node := _asset_root.get_node_or_null(NodePath(root_name)) if _asset_root != null else null
		var actual_count := root_node.find_children("*", "MeshInstance3D", true, false).size() if root_node != null else 0
		if actual_count != int(_manifest_runtime_mesh_counts.get(root_name, -1)):
			errors.append("runtime mesh count disagrees with manifest: %s" % root_name)
	for role: StringName in _runtime_materials:
		var material := _runtime_materials[role] as StandardMaterial3D
		if _material_signature(material) != _integrity_materials.get(role, {}):
			errors.append("runtime material content drifted: %s" % role)


func _get_raw_source_glb_path() -> String:
	# Imported resources are remapped inside exported PCKs. Hashing
	# `HERO_ASSET_PATH` there hashes the generated PackedScene rather than the
	# authored GLB and falsely rejects an otherwise exact import. A loose source
	# checkout has a physical, globalized GLB, so retain the strict source hash
	# check whenever that file is actually present. Packaged builds continue to
	# enforce the manifest, live hierarchy, mesh-content, triangle-count,
	# material, and authority contracts below.
	var global_path := ProjectSettings.globalize_path(HERO_ASSET_PATH)
	if global_path.is_empty() or global_path.begins_with("res://"):
		return ""
	return global_path if FileAccess.file_exists(global_path) else ""


func _append_mesh_integrity_errors(
	mesh_instance: MeshInstance3D,
	relative_path: String,
	errors: PackedStringArray
) -> void:
	var expected_value: Variant = _integrity_meshes.get(relative_path)
	if not expected_value is Dictionary:
		errors.append("unexpected imported hero mesh: %s" % relative_path)
		return
	var expected := expected_value as Dictionary
	var role := StringName(expected.get("material_role", &""))
	var expected_material := _runtime_materials.get(role) as Material
	if (
		mesh_instance.mesh == null
		or mesh_instance.mesh.get_instance_id() != int(expected.get("mesh_id", 0))
		or mesh_instance.mesh.get_surface_count() != int(expected.get("surface_count", 0))
		or _mesh_triangle_count(mesh_instance.mesh) != int(expected.get("triangle_count", 0))
		or _mesh_content_hash(mesh_instance.mesh) != str(expected.get("content_hash", ""))
	):
		errors.append("imported hero mesh topology drifted: %s" % relative_path)
	if role.is_empty() or mesh_instance.material_override != expected_material:
		errors.append("imported hero mesh material membership drifted: %s" % relative_path)
	var dynamic_engine_part := "EnginePlume" in mesh_instance.name or "EngineCore" in mesh_instance.name
	if not dynamic_engine_part and mesh_instance.visible != bool(expected.get("visible", true)):
		errors.append("imported hero mesh visibility drifted: %s" % relative_path)
	if (
		mesh_instance.layers != int(expected.get("layers", 1))
		or mesh_instance.cast_shadow != int(expected.get("cast_shadow", GeometryInstance3D.SHADOW_CASTING_SETTING_ON))
		or not is_equal_approx(mesh_instance.transparency, float(expected.get("transparency", 0.0)))
	):
		errors.append("imported hero mesh render contract drifted: %s" % relative_path)


func _node_transform_matches_contract(node: Node3D, expected: Transform3D) -> bool:
	if node == _canopy_pivot:
		if not node.position.is_equal_approx(expected.origin) or not node.scale.is_equal_approx(expected.basis.get_scale()):
			return false
		var rotation := node.rotation
		return (
			rotation.is_finite()
			and is_zero_approx(rotation.y)
			and is_zero_approx(rotation.z)
			and rotation.x >= -0.001
			and rotation.x <= deg_to_rad(63.0) + 0.001
		)
	if "EnginePlume" in node.name:
		if not node.position.is_equal_approx(expected.origin):
			return false
		var current_scale := node.scale
		var expected_scale := expected.basis.get_scale()
		if (
			not current_scale.is_finite()
			or not is_equal_approx(current_scale.x, expected_scale.x)
			or not is_equal_approx(current_scale.y, expected_scale.y)
			or current_scale.z <= 0.0
			or current_scale.z > expected_scale.z * 4.0
		):
			return false
		var current_rotation := node.rotation
		var expected_rotation := expected.basis.get_euler()
		return current_rotation.is_equal_approx(expected_rotation)
	if String(node.name).begins_with("Starboard") and String(node.name).ends_with("EngineCore"):
		return (
			node.transform.is_equal_approx(expected)
			or node.transform.is_equal_approx(_critical_engine_core_transform(expected))
		)
	return node.transform.is_equal_approx(expected)


func _runtime_triangle_count() -> int:
	if _asset_root == null or not is_instance_valid(_asset_root):
		return 0
	return _subtree_triangle_count(_asset_root)


func _subtree_triangle_count(node: Node) -> int:
	if node == null:
		return 0
	var total := 0
	for candidate in node.find_children("*", "MeshInstance3D", true, false):
		total += _mesh_triangle_count((candidate as MeshInstance3D).mesh)
	return total


func _subtree_surface_count(node: Node) -> int:
	if node == null:
		return 0
	var total := 0
	for candidate in node.find_children("*", "MeshInstance3D", true, false):
		var mesh := (candidate as MeshInstance3D).mesh
		if mesh != null:
			total += mesh.get_surface_count()
	return total


func _mesh_triangle_count(mesh: Mesh) -> int:
	if mesh == null:
		return 0
	var total := 0
	for surface_index in mesh.get_surface_count():
		var arrays: Array = mesh.surface_get_arrays(surface_index)
		var indices: Variant = arrays[Mesh.ARRAY_INDEX]
		var vertices: Variant = arrays[Mesh.ARRAY_VERTEX]
		var element_count: int = indices.size() if indices != null and indices.size() > 0 else vertices.size()
		total += element_count / 3
	return total


func _mesh_content_hash(mesh: Mesh) -> String:
	if mesh == null:
		return ""
	var context := HashingContext.new()
	context.start(HashingContext.HASH_SHA256)
	for surface_index in mesh.get_surface_count():
		context.update(var_to_bytes(mesh.surface_get_primitive_type(surface_index)))
		context.update(var_to_bytes(mesh.surface_get_arrays(surface_index)))
	return context.finish().hex_encode()


func _material_signature(material: StandardMaterial3D) -> Dictionary:
	if material == null:
		return {}
	return {
		"albedo": material.albedo_color,
		"albedo_path": material.albedo_texture.resource_path if material.albedo_texture != null else "",
		"metallic": material.metallic,
		"roughness": material.roughness,
		"emission_enabled": material.emission_enabled,
		"emission": material.emission,
		"emission_energy": material.emission_energy_multiplier,
		"transparency": material.transparency,
		"cull_mode": material.cull_mode,
		"normal_path": material.normal_texture.resource_path if material.normal_texture != null else "",
		"roughness_path": material.roughness_texture.resource_path if material.roughness_texture != null else "",
		"triplanar": material.uv1_triplanar,
		"clearcoat_enabled": material.clearcoat_enabled,
		"clearcoat": material.clearcoat,
		"clearcoat_roughness": material.clearcoat_roughness,
		"shading_mode": material.shading_mode,
		"diffuse_mode": material.diffuse_mode,
		"specular_mode": material.specular_mode,
		"render_priority": material.render_priority,
		"no_depth_test": material.no_depth_test,
		"billboard_mode": material.billboard_mode,
		"normal_enabled": material.normal_enabled,
		"normal_scale": material.normal_scale,
		"roughness_channel": material.roughness_texture_channel,
		"triplanar_sharpness": material.uv1_triplanar_sharpness,
		"uv1_scale": material.uv1_scale,
		"texture_filter": material.texture_filter,
	}


func _read_manifest() -> Dictionary:
	var file := FileAccess.open(MANIFEST_PATH, FileAccess.READ)
	if file == null:
		return {}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	return parsed as Dictionary if parsed is Dictionary else {}
