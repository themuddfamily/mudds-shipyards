class_name ArrowReconShip
extends HeroShip

## Evidence-bounded Arrow-class Recon Ship candidate.
##
## Creator-authored material (A3, page archived 2009-11-12) supports only the
## Arrow-class name, reconnaissance role, and a written description of two
## escape pods. No registered source shows a craft identified as Arrow: B3
## records the label string alone, with no ledger frame anchor and no tied
## craft, so the Arrow name-to-model mapping is `unknown`. This slender
## procedural airframe, all proportions, pod appearance/placement/release
## treatment, cockpit, entry, sensors, engines, weapons, materials, and handling
## are a modern provisional interpretation. The common HeroShip controller
## supplies already-tested flight, cameras, boarding, landing, damage,
## destruction, and reuse behavior.

const SCHEMA_VERSION := 1
const EVIDENCE_STATUS: StringName = &"provisional"
const EVIDENCE_SCOPE: StringName = &"name_role_pod_count_only"
const NAME_TO_MODEL_STATUS: StringName = &"unknown"
const SUPPORTED_ESCAPE_POD_COUNT := 2
const PROVISIONAL_NOTE := (
	"Creator-supported facts (A3 page text): Arrow-class Recon Ship; "
	+ "reconnaissance role; two escape pods. No registered source ties any "
	+ "visible craft to the Arrow name, so the name-to-model mapping is "
	+ "unknown. The displayed geometry, materials, entry, pod appearance and "
	+ "locations, release concept, systems, handling, and weapons are a modern "
	+ "provisional interpretation with no authenticated historical silhouette "
	+ "mapping."
)

# Fleet readability palette. The Arrow's name-to-model mapping is unknown and
# its palette is listed among its unknowns in docs/research/ship_evidence_matrix.json,
# so these are freely chosen modern hull tints picked to separate the recon craft
# from the rest of the fleet under normal and dichromatic vision. See
# tests/fleet_role_differentiation_test.gd for the frozen separation floors.
const HULL_SLATE := Color("7891ab")
const HULL_SLATE_SHADE := Color("66798d")
const TITANIUM := Color("59686c")
const GRAPHITE := Color("15282e")
const SENSOR_CYAN := Color("65e4e8")
const POD_ORANGE := Color("e59a43")
const ENGINE_CYAN := Color("7cf5ef")
const ARROW_NAV_RED := Color("ff6460")
const ARROW_NAV_GREEN := Color("7cf0a3")

# Phase 9 allocation freeze. These two mirrored ribs were the first repeated
# Arrow family with identical mesh/material state and no gameplay, evidence,
# collision, lifecycle, or stable-node identity. The five later panel bands keep
# every ordinary renderer, including the checked-in `FuselagePanelBand` capture
# path, while sharing only their identical TorusMesh resource. The other audited
# families are narrower still: only the identical, childless CurveJoint sphere
# resources under the paired lateral arrays, sensor-wing leading edges and
# three-point dorsal data conduit are shared within their exact family. All
# retained nodes, paths, transforms, materials, shadows, copies and submissions
# remain ordinary independent renderers.
const WING_ROOT_RIB_SIZE := Vector3(1.25, 0.34, 4.8)
const WING_ROOT_RIB_VISIBLE_COPIES := 2
const LATERAL_ARRAY_CURVE_JOINT_RADIUS := 0.07
const LATERAL_ARRAY_CURVE_JOINT_RADIAL_SEGMENTS := 28
const LATERAL_ARRAY_CURVE_JOINT_RINGS := 14
const LATERAL_ARRAY_CURVE_JOINT_VISIBLE_COPIES := 6
const LATERAL_ARRAY_CURVE_JOINT_PATHS := [
	"PortLateralArray/CurveJoint",
	"PortLateralArray/@MeshInstance3D@15",
	"PortLateralArray/@MeshInstance3D@16",
	"StarboardLateralArray/CurveJoint",
	"StarboardLateralArray/@MeshInstance3D@17",
	"StarboardLateralArray/@MeshInstance3D@18",
]
const SENSOR_LEADING_EDGE_CURVE_JOINT_RADIUS := 0.105
const SENSOR_LEADING_EDGE_CURVE_JOINT_RADIAL_SEGMENTS := 28
const SENSOR_LEADING_EDGE_CURVE_JOINT_RINGS := 14
const SENSOR_LEADING_EDGE_CURVE_JOINT_VISIBLE_COPIES := 6
const SENSOR_LEADING_EDGE_CURVE_JOINT_PATHS := [
	"SensorLeadingEdge/CurveJoint",
	"SensorLeadingEdge/@MeshInstance3D@2",
	"SensorLeadingEdge/@MeshInstance3D@3",
	"@Node3D@4/CurveJoint",
	"@Node3D@4/@MeshInstance3D@5",
	"@Node3D@4/@MeshInstance3D@6",
]
const DORSAL_DATA_CONDUIT_CURVE_JOINT_RADIUS := 0.075
const DORSAL_DATA_CONDUIT_CURVE_JOINT_RADIAL_SEGMENTS := 28
const DORSAL_DATA_CONDUIT_CURVE_JOINT_RINGS := 14
const DORSAL_DATA_CONDUIT_CURVE_JOINT_VISIBLE_COPIES := 3
const DORSAL_DATA_CONDUIT_CURVE_JOINT_PATHS := [
	"DorsalDataConduit/CurveJoint",
	"DorsalDataConduit/@MeshInstance3D@8",
	"DorsalDataConduit/@MeshInstance3D@9",
]
const FUSELAGE_PANEL_BAND_INNER_RADIUS := 1.31
const FUSELAGE_PANEL_BAND_OUTER_RADIUS := 1.35
const FUSELAGE_PANEL_BAND_AUTHORED_RINGS := 64
const FUSELAGE_PANEL_BAND_AUTHORED_RING_SEGMENTS := 18
const FUSELAGE_PANEL_BAND_BUDGETED_RINGS := 41
const FUSELAGE_PANEL_BAND_BUDGETED_RING_SEGMENTS := 12
const FUSELAGE_PANEL_BAND_VISIBLE_COPIES := 5
const FUSELAGE_PANEL_BAND_STABLE_PATH := "FuselagePanelBand"
const LEGACY_ARROW_VISUAL_CENSUS := {
	"nodes": 177,
	"mesh_instance_nodes": 159,
	"multi_mesh_instance_nodes": 0,
	"geometry_submissions": 159,
	"visible_geometry_copies": 159,
	"unique_mesh_resource_allocations": 142,
	"auto_fallback_names": 24,
}
const EXPECTED_ARROW_VISUAL_CENSUS := {
	"nodes": 176,
	"mesh_instance_nodes": 157,
	"multi_mesh_instance_nodes": 1,
	"geometry_submissions": 158,
	"visible_geometry_copies": 159,
	"unique_mesh_resource_allocations": 125,
	"auto_fallback_names": 23,
}

var _arrow_built := false
var _arrow_visual: Node3D
var _arrow_materials: Dictionary = {}
var _escape_pods: Array[Node3D] = []
var _engine_plumes: Array[MeshInstance3D] = []
var _arrow_engine_lights: Array[OmniLight3D] = []
var _sensor_sweep: Node3D
var _elapsed_arrow := 0.0
var _wing_root_rib_authored_transforms: Array[Transform3D] = []
var _lateral_array_curve_joint_mesh: SphereMesh
var _sensor_leading_edge_curve_joint_mesh: SphereMesh
var _dorsal_data_conduit_curve_joint_mesh: SphereMesh
var _fuselage_panel_band_mesh: TorusMesh


func _uses_torrent_reconstruction_presentation() -> bool:
	return false


func _ready() -> void:
	super._ready()
	if not _arrow_built:
		_arrow_built = rebuild_variant_presentation(_build_arrow_variant)
	_apply_arrow_metadata()
	_sync_arrow_engine_presentation_immediately()


func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	_elapsed_arrow += delta
	_update_arrow_presentation(delta)


func get_escape_pod_count() -> int:
	return _escape_pods.size()


func get_escape_pods() -> Array[Node3D]:
	return _escape_pods.duplicate()


func get_escape_pod(side_id: StringName) -> Node3D:
	for pod in _escape_pods:
		if StringName(pod.get_meta("pod_side", &"")) == side_id:
			return pod
	return null


func get_sensor_mast() -> Node3D:
	return _sensor_sweep


func get_arrow_visual_root() -> Node3D:
	return _arrow_visual


func get_arrow_evidence_report() -> Dictionary:
	var definition := get_ship_definition()
	return {
		"schema_version": SCHEMA_VERSION,
		"evidence_status": EVIDENCE_STATUS,
		"evidence_scope": EVIDENCE_SCOPE,
		"name_to_model_status": NAME_TO_MODEL_STATUS,
		"authenticated_geometry": false,
		"creator_supported": PackedStringArray([
			"Arrow-class Recon Ship name (A3 page text)",
			"reconnaissance role (A3 page text)",
			"two escape pods described in A3 page text, never observed",
		]),
		"modern_provisional": PackedStringArray([
			"slender silhouette and every dimension",
			"cockpit, canopy, seat, entry side, and cameras",
			"escape-pod shape, position, markings, and release concept",
			"sensor mast and lateral arrays",
			"twin engines, light weapons, materials, and handling values",
		]),
		"content_note": PROVISIONAL_NOTE,
		"ship_definition": definition.get_audit_report() if definition != null else {},
	}


func get_arrow_audit_report() -> Dictionary:
	var errors := PackedStringArray()
	var definition := get_ship_definition()
	if definition == null or not definition.is_definition_valid():
		errors.append("valid provisional ShipDefinition is missing")
	elif definition.get_evidence_status_id() != &"provisional":
		errors.append("Arrow definition must remain provisional")
	if get_escape_pod_count() != SUPPORTED_ESCAPE_POD_COUNT:
		errors.append("Arrow must visibly expose exactly two escape pods")
	if _arrow_visual == null:
		errors.append("Arrow variant visual root is missing")
	if _sensor_sweep == null:
		errors.append("provisional recon sensor mast is missing")
	var left_muzzle := get_node_or_null("LeftMuzzle") as Marker3D
	var right_muzzle := get_node_or_null("RightMuzzle") as Marker3D
	if left_muzzle == null or right_muzzle == null:
		errors.append("light weapon muzzle markers are missing")
	var performance := get_arrow_visual_performance_report()
	if not bool(performance.valid):
		errors.append("Arrow visual allocation/submission census is invalid")
	return {
		"schema_version": SCHEMA_VERSION,
		"valid": errors.is_empty(),
		"errors": errors,
		"ship_id": get_ship_id(),
		"display_name": get_display_name(),
		"role": get_role(),
		"escape_pod_count": get_escape_pod_count(),
		"sensor_mast_present": _sensor_sweep != null,
		"weapon_class": &"light_recon_pulse",
		"engine_count": _engine_plumes.size(),
		"evidence": get_arrow_evidence_report(),
		"performance": performance,
	}


## Detached whole-visual and local-batch evidence. Geometry submissions sum
## mesh surfaces once per ordinary instance or batch; visible copies count every
## ordinary mesh plus every authored MultiMesh transform.
func get_arrow_visual_performance_report() -> Dictionary:
	var errors := PackedStringArray()
	if not is_instance_valid(_arrow_visual):
		return {
			"valid": false,
			"errors": PackedStringArray(["Arrow visual root is missing"]),
			"legacy": LEGACY_ARROW_VISUAL_CENSUS.duplicate(true),
			"current": {},
			"wing_root_rib_batch": {},
			"lateral_array_curve_joint_sharing": {},
			"sensor_leading_edge_curve_joint_sharing": {},
			"dorsal_data_conduit_curve_joint_sharing": {},
			"fuselage_panel_band_mesh_sharing": {},
		}.duplicate(true)

	var current := _collect_arrow_visual_census()
	for key: String in EXPECTED_ARROW_VISUAL_CENSUS:
		if int(current.get(key, -1)) != int(EXPECTED_ARROW_VISUAL_CENSUS[key]):
			errors.append("whole visual census drift: %s" % key)
	var batch := _inspect_wing_root_rib_batch()
	if not bool(batch.valid):
		errors.append_array(batch.errors as PackedStringArray)
	var lateral_joints := _inspect_lateral_array_curve_joint_sharing()
	if not bool(lateral_joints.valid):
		errors.append_array(lateral_joints.errors as PackedStringArray)
	var leading_edge_joints := _inspect_sensor_leading_edge_curve_joint_sharing()
	if not bool(leading_edge_joints.valid):
		errors.append_array(leading_edge_joints.errors as PackedStringArray)
	var dorsal_conduit_joints := _inspect_dorsal_data_conduit_curve_joint_sharing()
	if not bool(dorsal_conduit_joints.valid):
		errors.append_array(dorsal_conduit_joints.errors as PackedStringArray)
	var panel_bands := _inspect_fuselage_panel_band_mesh_sharing()
	if not bool(panel_bands.valid):
		errors.append_array(panel_bands.errors as PackedStringArray)
	return {
		"valid": errors.is_empty(),
		"errors": errors,
		"legacy": LEGACY_ARROW_VISUAL_CENSUS.duplicate(true),
		"expected": EXPECTED_ARROW_VISUAL_CENSUS.duplicate(true),
		"current": current,
		"reductions": {
			"nodes": 1,
			"geometry_submissions": 1,
			"unique_mesh_resource_allocations": 17,
			"auto_fallback_names": 1,
			"visible_geometry_copies": 0,
		},
		"wing_root_rib_batch": batch,
		"lateral_array_curve_joint_sharing": lateral_joints,
		"sensor_leading_edge_curve_joint_sharing": leading_edge_joints,
		"dorsal_data_conduit_curve_joint_sharing": dorsal_conduit_joints,
		"fuselage_panel_band_mesh_sharing": panel_bands,
	}.duplicate(true)


func _build_arrow_variant(_controller: HeroShip) -> bool:
	var inherited_visual := get_variant_visual_root()
	if inherited_visual == null:
		return false
	# Preserve the inherited cockpit/canopy nodes because the common controller
	# owns their private animation and camera references. Every Torrent exterior
	# node is removed; only those functional cockpit nodes are reparented.
	var cockpit := inherited_visual.get_node_or_null("CockpitInterior") as Node3D
	var canopy := inherited_visual.get_node_or_null("CanopyHinge") as Node3D
	var hinge_bar := inherited_visual.get_node_or_null("CanopyHingeBar") as Node3D
	var hinge_mounts := inherited_visual.find_children("*CanopyHingeMount", "Node3D", false, false)
	for preserved in [cockpit, canopy, hinge_bar]:
		if preserved != null:
			preserved.reparent(self, true)
	for mount in hinge_mounts:
		(mount as Node3D).reparent(self, true)
	if inherited_visual.get_parent() != null:
		inherited_visual.get_parent().remove_child(inherited_visual)
	inherited_visual.queue_free()

	_arrow_visual = Node3D.new()
	_arrow_visual.name = "ArrowReconVisual"
	_arrow_visual.set_meta("geometry_status", EVIDENCE_STATUS)
	_arrow_visual.set_meta("authenticated_historical_silhouette", false)
	_arrow_visual.set_meta("content_note", PROVISIONAL_NOTE)
	add_child(_arrow_visual)
	if cockpit != null:
		cockpit.reparent(_arrow_visual, true)
	if canopy != null:
		canopy.reparent(_arrow_visual, true)
	if hinge_bar != null:
		hinge_bar.reparent(_arrow_visual, true)
	for mount in hinge_mounts:
		(mount as Node3D).reparent(_arrow_visual, true)

	_create_arrow_materials()
	_build_slender_airframe()
	_build_recon_systems()
	_build_escape_pods()
	_build_engines_and_landing_gear()
	_restyle_inherited_cockpit(cockpit, canopy)
	_replace_collision_and_markers()
	if not replace_variant_visual_root(_arrow_visual):
		return false
	return true


func _create_arrow_materials() -> void:
	# The `pearl`/`ceramic` material-family keys are the craft's stable public
	# material API and are left alone; only the tints they carry changed.
	_arrow_materials.pearl = _material(HULL_SLATE, 0.18, 0.28)
	_arrow_materials.ceramic = _material(HULL_SLATE_SHADE, 0.12, 0.36)
	# Secondary structure carries a deliberately wide material response. Before
	# this pass titanium/graphite/pod sat at roughness 0.34/0.30/0.42 and
	# metallic 0.58/0.64/0.20 — three surfaces a player could only tell apart by
	# hue. They are now bare machined alloy, matte painted composite, and a
	# painted survival-orange shell, which is three different behaviours under
	# the same light. Colours are untouched; see the palette note above.
	_arrow_materials.titanium = _material(TITANIUM, 0.72, 0.24)
	_arrow_materials.graphite = _material(GRAPHITE, 0.30, 0.68)
	_arrow_materials.sensor = _material(SENSOR_CYAN, 0.18, 0.22, SENSOR_CYAN, 1.7)
	_arrow_materials.pod = _material(POD_ORANGE, 0.10, 0.58)
	_arrow_materials.engine = _material(ENGINE_CYAN, 0.1, 0.16, ENGINE_CYAN, 3.0)
	_arrow_materials.nav_red = _material(ARROW_NAV_RED, 0.1, 0.2, ARROW_NAV_RED, 2.2)
	_arrow_materials.nav_green = _material(ARROW_NAV_GREEN, 0.1, 0.2, ARROW_NAV_GREEN, 2.2)
	_arrow_materials.glass = _transparent_material(Color(0.3, 0.68, 0.7, 0.09), 0.04, 0.08)
	var hull_albedo := load("res://assets/materials/arrow-hull-albedo-v1.png") as Texture2D
	var hull_normal := load("res://assets/materials/arrow-hull-normal-v1.png") as Texture2D
	var hull_roughness := load("res://assets/materials/arrow-hull-roughness-v1.png") as Texture2D
	for hull_material: StandardMaterial3D in [_arrow_materials.pearl, _arrow_materials.ceramic]:
		if hull_albedo != null:
			hull_material.albedo_texture = hull_albedo
		if hull_normal != null:
			hull_material.normal_enabled = true
			hull_material.normal_texture = hull_normal
			hull_material.normal_scale = 0.62
		if hull_roughness != null:
			hull_material.roughness_texture = hull_roughness
			hull_material.roughness_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_RED
		# Triplanar projection keeps the generated aerospace panel treatment stable
		# across the procedural loft and avoids stretched seams at its ring caps.
		hull_material.uv1_triplanar = true
		hull_material.uv1_triplanar_sharpness = 4.0
		hull_material.uv1_scale = Vector3(0.34, 0.34, 0.34)
		hull_material.clearcoat_enabled = true
		hull_material.clearcoat = 0.48
		hull_material.clearcoat_roughness = 0.2
	# Nacelles, wing-root ribs, wingtip pods, the sensor gimbal, the fuselage
	# panel bands, gear feet and the mast pedestal all shared one flat slab of
	# `TITANIUM` with no map of any kind: the aft crop of the baseline capture
	# shows the engine housing as a single uniform grey cylinder. The registered
	# Arrow normal map that already dresses the hull is reused here through
	# triplanar projection at 5-10x the hull's frequency: the hull tiles about
	# once every three metres, and a 0.3 m strut or a 0.4 m collar at that rate
	# receives a fraction of one feature and cannot show relief at all.
	# Measured honestly, this relief is a small contribution under the current
	# station lighting — a rendered A/B at an absurd normal_scale of 12.0 moved
	# under 1% of a berth frame — so the widened metallic/roughness response
	# above is what carries this pass. The relief is kept because it costs
	# nothing and will pay off if the lighting gains contrast. No albedo texture
	# is bound, so the fleet colour floors see exactly the tints above.
	ShipSurfaceDetail.bind_structural_detail(_arrow_materials.titanium, hull_normal, 3.5, 1.20)
	# Struts, keel, mast stem and pod collars are painted composite, not bare
	# metal, so they take the matte end of the craft's roughness range while
	# titanium takes the glossy end.
	ShipSurfaceDetail.bind_structural_detail(_arrow_materials.graphite, hull_normal, 3.0, 1.10)
	# The escape pods were the single most primitive-looking object on the
	# craft: a saturated flat orange blob beside a textured fuselage. A coarser
	# projection than the hardware gives them shell seams at pod scale.
	ShipSurfaceDetail.bind_structural_detail(_arrow_materials.pod, hull_normal, 1.6, 1.30)


func get_variant_materials() -> Dictionary:
	return _arrow_materials


func _build_slender_airframe() -> void:
	_sensor_leading_edge_curve_joint_mesh = SphereMesh.new()
	_sensor_leading_edge_curve_joint_mesh.radius = SENSOR_LEADING_EDGE_CURVE_JOINT_RADIUS
	_sensor_leading_edge_curve_joint_mesh.height = SENSOR_LEADING_EDGE_CURVE_JOINT_RADIUS * 2.0
	_sensor_leading_edge_curve_joint_mesh.radial_segments = SENSOR_LEADING_EDGE_CURVE_JOINT_RADIAL_SEGMENTS
	_sensor_leading_edge_curve_joint_mesh.rings = SENSOR_LEADING_EDGE_CURVE_JOINT_RINGS
	_sensor_leading_edge_curve_joint_mesh.material = _arrow_materials.sensor
	_dorsal_data_conduit_curve_joint_mesh = SphereMesh.new()
	_dorsal_data_conduit_curve_joint_mesh.radius = DORSAL_DATA_CONDUIT_CURVE_JOINT_RADIUS
	_dorsal_data_conduit_curve_joint_mesh.height = DORSAL_DATA_CONDUIT_CURVE_JOINT_RADIUS * 2.0
	_dorsal_data_conduit_curve_joint_mesh.radial_segments = DORSAL_DATA_CONDUIT_CURVE_JOINT_RADIAL_SEGMENTS
	_dorsal_data_conduit_curve_joint_mesh.rings = DORSAL_DATA_CONDUIT_CURVE_JOINT_RINGS
	_dorsal_data_conduit_curve_joint_mesh.material = _arrow_materials.sensor
	_fuselage_panel_band_mesh = TorusMesh.new()
	_fuselage_panel_band_mesh.inner_radius = FUSELAGE_PANEL_BAND_INNER_RADIUS
	_fuselage_panel_band_mesh.outer_radius = FUSELAGE_PANEL_BAND_OUTER_RADIUS
	_fuselage_panel_band_mesh.rings = FUSELAGE_PANEL_BAND_AUTHORED_RINGS
	_fuselage_panel_band_mesh.ring_segments = FUSELAGE_PANEL_BAND_AUTHORED_RING_SEGMENTS
	_fuselage_panel_band_mesh.material = _arrow_materials.titanium
	# A narrow 32-section elliptical fuselage, not the Torrent's broad delta.
	_loft_hull(
		_arrow_visual,
		"ReconFuselage",
		Vector3(0, 1.22, -0.45),
		PackedVector3Array([
			Vector3(0.18, 0.12, -7.2),
			Vector3(0.72, 0.46, -6.15),
			Vector3(1.28, 0.72, -3.7),
			Vector3(1.5, 0.86, -0.7),
			Vector3(1.62, 0.82, 2.6),
			Vector3(1.25, 0.7, 5.2),
			Vector3(0.84, 0.55, 6.3),
		]),
		_arrow_materials.pearl
	)
	_loft_hull(
		_arrow_visual,
		"GraphiteKeel",
		Vector3(0, 0.5, -0.1),
		PackedVector3Array([
			Vector3(0.12, 0.08, -5.6),
			Vector3(0.82, 0.34, -3.8),
			Vector3(1.05, 0.38, 1.8),
			Vector3(0.68, 0.3, 5.3),
		]),
		_arrow_materials.graphite
	)

	# Long swept sensor wings use curved planform lofts and inset titanium roots.
	var wing_root_rib_transforms: Array[Transform3D] = []
	for side_index in 2:
		var side := -1.0 if side_index == 0 else 1.0
		var wing := _build_planform_surface(
			"PortSensorWing" if side_index == 0 else "StarboardSensorWing",
			PackedVector3Array([
				Vector3(side * 0.9, 1.05, -1.6),
				Vector3(side * 5.35, 0.92, 0.75),
				Vector3(side * 5.75, 0.86, 3.65),
				Vector3(side * 1.15, 0.98, 2.8),
			]),
			0.18,
			_arrow_materials.ceramic
		)
		_arrow_visual.add_child(wing)
		wing_root_rib_transforms.append(Transform3D(
			Basis.from_euler(Vector3(0, side * -0.08, 0)),
			Vector3(side * 1.45, 1.03, 1.0)
		))
		_curve_tube(
			_arrow_visual,
			"SensorLeadingEdge",
			PackedVector3Array([
				Vector3(side * 1.0, 1.19, -1.65),
				Vector3(side * 3.4, 1.1, -0.55),
				Vector3(side * 5.35, 1.02, 0.75),
			]),
			SENSOR_LEADING_EDGE_CURVE_JOINT_RADIUS,
			_arrow_materials.sensor,
			_sensor_leading_edge_curve_joint_mesh
		)
		_loft_hull(
			_arrow_visual,
			"WingtipSensorPod",
			Vector3(side * 5.55, 1.0, 2.45),
			PackedVector3Array([
				Vector3(0.08, 0.06, -1.85),
				Vector3(0.33, 0.24, -1.25),
				Vector3(0.42, 0.28, 0.65),
				Vector3(0.18, 0.14, 1.75),
			]),
			_arrow_materials.titanium
		)
		_sphere(_arrow_visual, "PortNavigationLight" if side_index == 0 else "StarboardNavigationLight", Vector3(side * 5.64, 1.04, 3.35), 0.115, _arrow_materials.nav_red if side < 0 else _arrow_materials.nav_green)
	_multi_mesh_box(
		_arrow_visual,
		"WingRootRibBatch",
		WING_ROOT_RIB_SIZE,
		_arrow_materials.titanium,
		wing_root_rib_transforms
	)
	_wing_root_rib_authored_transforms = wing_root_rib_transforms.duplicate()

	# Layered dorsal shell follows the long recon fuselage rather than adding a
	# blocky superstructure. Panel seams are slim and restrained.
	_loft_hull(
		_arrow_visual,
		"DorsalSurveySpine",
		Vector3(0, 2.08, 1.55),
		PackedVector3Array([
			Vector3(0.22, 0.1, -2.4),
			Vector3(0.67, 0.38, -1.35),
			Vector3(0.76, 0.42, 1.65),
			Vector3(0.44, 0.22, 3.0),
		]),
		_arrow_materials.ceramic
	)
	_curve_tube(
		_arrow_visual,
		"DorsalDataConduit",
		PackedVector3Array([
			Vector3(0, 2.52, -0.6),
			Vector3(0, 2.65, 1.45),
			Vector3(0, 2.42, 3.8),
		]),
		DORSAL_DATA_CONDUIT_CURVE_JOINT_RADIUS,
		_arrow_materials.sensor,
		_dorsal_data_conduit_curve_joint_mesh
	)
	for seam_z in [-4.4, -2.6, 0.4, 2.2, 4.3]:
		_torus(
			_arrow_visual,
			"FuselagePanelBand",
			Vector3(0, 1.22, seam_z),
			FUSELAGE_PANEL_BAND_INNER_RADIUS,
			FUSELAGE_PANEL_BAND_OUTER_RADIUS,
			_arrow_materials.titanium,
			Vector3(90, 0, 0),
			Vector3(1.0, 0.58, 1.0),
			_fuselage_panel_band_mesh
		)


func _build_recon_systems() -> void:
	var mast := Node3D.new()
	mast.name = "ReconSensorMast"
	mast.position = Vector3(0, 2.5, 3.55)
	mast.set_meta("provisional_sensor_system", true)
	_arrow_visual.add_child(mast)
	_cylinder(mast, "MastPedestal", Vector3(0, 0.45, 0), 0.16, 0.9, _arrow_materials.titanium)
	_cylinder(mast, "MastStem", Vector3(0, 1.15, 0), 0.08, 0.72, _arrow_materials.graphite)
	_sensor_sweep = Node3D.new()
	_sensor_sweep.name = "SensorSweep"
	_sensor_sweep.position = Vector3(0, 1.48, 0)
	mast.add_child(_sensor_sweep)
	_torus(_sensor_sweep, "PassiveArrayRing", Vector3.ZERO, 0.45, 0.54, _arrow_materials.sensor, Vector3(90, 0, 0))
	_cylinder(_sensor_sweep, "ArrayCrossbar", Vector3.ZERO, 0.055, 1.45, _arrow_materials.titanium, Vector3(0, 0, 90))
	for side in [-1.0, 1.0]:
		_sphere(_sensor_sweep, "ArrayReceiver", Vector3(side * 0.67, 0, 0), 0.15, _arrow_materials.sensor)

	# Ventral camera/spectral turret is a smooth gimbal, not a weapon hardpoint.
	_sphere(_arrow_visual, "VentralSensorGimbal", Vector3(0, -0.06, -1.8), 0.42, _arrow_materials.titanium)
	_sphere(_arrow_visual, "VentralSensorLens", Vector3(0, -0.33, -2.08), 0.2, _arrow_materials.sensor)
	_lateral_array_curve_joint_mesh = SphereMesh.new()
	_lateral_array_curve_joint_mesh.radius = LATERAL_ARRAY_CURVE_JOINT_RADIUS
	_lateral_array_curve_joint_mesh.height = LATERAL_ARRAY_CURVE_JOINT_RADIUS * 2.0
	_lateral_array_curve_joint_mesh.radial_segments = LATERAL_ARRAY_CURVE_JOINT_RADIAL_SEGMENTS
	_lateral_array_curve_joint_mesh.rings = LATERAL_ARRAY_CURVE_JOINT_RINGS
	_lateral_array_curve_joint_mesh.material = _arrow_materials.sensor
	for side_index in 2:
		var side := -1.0 if side_index == 0 else 1.0
		_curve_tube(
			_arrow_visual,
			"PortLateralArray" if side_index == 0 else "StarboardLateralArray",
			PackedVector3Array([
				Vector3(side * 1.35, 1.36, -2.0),
				Vector3(side * 2.25, 1.38, -1.2),
				Vector3(side * 3.45, 1.25, -0.25),
			]),
			LATERAL_ARRAY_CURVE_JOINT_RADIUS,
			_arrow_materials.sensor,
			_lateral_array_curve_joint_mesh
		)


func _build_escape_pods() -> void:
	_escape_pods.clear()
	for side_index in 2:
		var side := -1.0 if side_index == 0 else 1.0
		var pod := Node3D.new()
		pod.name = "PortEscapePod" if side_index == 0 else "StarboardEscapePod"
		pod.position = Vector3(side * 1.62, 1.18, 3.25)
		pod.set_meta("escape_pod", true)
		pod.set_meta("pod_side", &"port" if side < 0 else &"starboard")
		pod.set_meta("pod_index", 0 if side < 0 else 1)
		pod.set_meta("creator_roster_claim", &"two_escape_pods_total")
		pod.set_meta("creator_roster_source", &"A3")
		pod.set_meta("geometry_status", EVIDENCE_STATUS)
		pod.set_meta("separable_visual_module", true)
		pod.set_meta("release_mechanism_implemented", false)
		_arrow_visual.add_child(pod)
		_escape_pods.append(pod)
		_loft_hull(
			pod,
			"PodPressureShell",
			Vector3.ZERO,
			PackedVector3Array([
				Vector3(0.08, 0.06, -1.45),
				Vector3(0.52, 0.42, -0.82),
				Vector3(0.58, 0.47, 0.72),
				Vector3(0.24, 0.18, 1.32),
			]),
			_arrow_materials.pod
		)
		_torus(pod, "PodSeparationCollar", Vector3.ZERO, 0.57, 0.65, _arrow_materials.graphite, Vector3(90, 0, 0), Vector3(1.0, 0.82, 1.0))
		_box(pod, "PodIdentityStripe", Vector3(side * 0.48, 0.02, -0.05), Vector3(0.06, 0.22, 1.55), _arrow_materials.sensor)
		_sphere(pod, "PodStatusLight", Vector3(side * 0.53, 0.14, -0.72), 0.085, _arrow_materials.sensor)


func _build_engines_and_landing_gear() -> void:
	_engine_plumes.clear()
	_arrow_engine_lights.clear()
	for side_index in 2:
		var side := -1.0 if side_index == 0 else 1.0
		_loft_hull(
			_arrow_visual,
			"EfficientEngineHousing",
			Vector3(side * 0.92, 0.94, 5.0),
			PackedVector3Array([
				Vector3(0.32, 0.28, -1.5),
				Vector3(0.64, 0.55, -0.85),
				Vector3(0.68, 0.58, 1.1),
				Vector3(0.54, 0.44, 1.6),
			]),
			_arrow_materials.titanium
		)
		_torus(_arrow_visual, "EngineCollar", Vector3(side * 0.92, 0.94, 6.48), 0.55, 0.7, _arrow_materials.ceramic, Vector3(90, 0, 0))
		var plume := _cylinder(_arrow_visual, "PortEnginePlume" if side_index == 0 else "StarboardEnginePlume", Vector3(side * 0.92, 0.94, 6.92), 0.37, 0.78, _arrow_materials.engine, Vector3(90, 0, 0))
		_engine_plumes.append(plume)
		var light := OmniLight3D.new()
		light.name = "PortEngineLight" if side_index == 0 else "StarboardEngineLight"
		light.position = Vector3(side * 0.92, 0.94, 6.7)
		light.light_color = ENGINE_CYAN
		light.light_energy = 0.0
		light.omni_range = 6.2
		light.shadow_enabled = false
		_arrow_visual.add_child(light)
		_arrow_engine_lights.append(light)

	# Narrow tricycle gear suits the slender hull and keeps a stable parked pose.
	for side in [-1.0, 1.0]:
		_cylinder(_arrow_visual, "MainGearStrut", Vector3(side * 1.55, -0.05, 2.25), 0.07, 1.25, _arrow_materials.graphite, Vector3(0, 0, side * -8.0))
		_torus(_arrow_visual, "MainGearFoot", Vector3(side * 1.7, -0.64, 2.25), 0.22, 0.34, _arrow_materials.titanium, Vector3(90, 0, 0), Vector3(1.4, 0.55, 1.0))
	_cylinder(_arrow_visual, "NoseGearStrut", Vector3(0, -0.02, -4.2), 0.065, 1.12, _arrow_materials.graphite)
	_torus(_arrow_visual, "NoseGearFoot", Vector3(0, -0.56, -4.2), 0.18, 0.29, _arrow_materials.titanium, Vector3(90, 0, 0), Vector3(1.4, 0.55, 1.0))
	for step_index in 3:
		_box(_arrow_visual, "BoardingStep", Vector3(-1.65 - float(step_index) * 0.32, -0.12 + float(step_index) * 0.28, 0.05), Vector3(0.58, 0.1, 0.62), _arrow_materials.pod)


func _restyle_inherited_cockpit(cockpit: Node3D, canopy: Node3D) -> void:
	if cockpit != null:
		# Darker interior preserves high contrast behind the unusually clear canopy.
		for node in cockpit.find_children("*", "MeshInstance3D", true, false):
			var mesh_instance := node as MeshInstance3D
			if "Display" in mesh_instance.name or "ConsoleKey" in mesh_instance.name:
				mesh_instance.material_override = _arrow_materials.sensor
	if canopy != null:
		var glass := canopy.get_node_or_null("CanopyGlass") as MeshInstance3D
		if glass != null:
			glass.material_override = _arrow_materials.glass
			# Retain the inherited physical canopy envelope. Enlarging the shell
			# independently of its private camera/hinge geometry creates a cyan first-
			# person wash and overstates the high-visibility canopy from outside.
			glass.scale = Vector3.ONE
		for frame in canopy.find_children("*Canopy*Frame", "MeshInstance3D", true, false):
			(frame as MeshInstance3D).material_override = _arrow_materials.graphite
		for rail in canopy.find_children("*Canopy*Rail", "MeshInstance3D", true, false):
			(rail as MeshInstance3D).material_override = _arrow_materials.ceramic


func _replace_collision_and_markers() -> void:
	for child in get_children():
		if child is CollisionShape3D:
			remove_child(child)
			child.queue_free()
	_add_box_collision("ArrowHullCollision", Vector3(0, 0.85, -0.35), Vector3(3.1, 1.65, 12.2))
	_add_box_collision("ArrowWingCollision", Vector3(0, 0.88, 1.25), Vector3(11.1, 0.48, 4.9))

	var boarding := get_node_or_null("BoardingPoint") as Marker3D
	var exit := get_node_or_null("ExitPoint") as Marker3D
	var left_muzzle := get_node_or_null("LeftMuzzle") as Marker3D
	var right_muzzle := get_node_or_null("RightMuzzle") as Marker3D
	if boarding != null:
		boarding.position = Vector3(-2.45, -0.02, 0.15)
	if exit != null:
		exit.position = Vector3(-6.6, -0.9, 0.25)
		exit.rotation.y = -PI * 0.5
	if left_muzzle != null:
		left_muzzle.position = Vector3(-1.05, 0.72, -5.7)
	if right_muzzle != null:
		right_muzzle.position = Vector3(1.05, 0.72, -5.7)
	var boarding_area := get_node_or_null("ShipBoardingArea") as Area3D
	if boarding_area != null:
		boarding_area.position = Vector3(-2.45, 0.48, 0.15)
		_add_flank_approach_range(boarding_area)


## PORT-BOARDING-001. The fleet-wide boarding volume is a single 4.5 m sphere on
## the ship's own boarding marker. On this craft that marker sits at local
## (-2.45, -0.02, 0.15) — *underneath the sensor wing*, whose collision spans
## local x = -5.55 … 5.55 by z = -1.2 … 3.7 at y = 0.64 … 1.12. A standing capsule
## cannot occupy the sphere's centre at all, so the prompt only appeared where the
## sphere happened to poke out past the wing: measured on the live berth deck, of
## the 0.5 m grid cells a player can actually stand on, the whole starboard flank
## from z = 7.0 to z = 10.5 offered no prompt, and the nearest cell that did was
## inside the port engine housing. That is the reported "only when you are
## standing inside of the engine".
##
## The sphere is deliberately left exactly as inherited — it is a published
## fleet-wide contract — and a craft-shaped approach volume is added beside it.
## It is sized to the craft plus a walk-up margin, not to the deck: half extents
## 6.9 m laterally and 7.6 m along the hull against a hull of 5.55 / 6.10. With
## the production player's own 2.35 m interaction sphere that reaches 9.25 / 9.95,
## which covers every standable metre of the 16.8 x 17.0 m berth deck (half
## extents 8.4 / 8.5) on both flanks and around nose and tail. It stops 2.55 m
## short of a point 7.0 m off the boarding marker along the lateral axis, so the
## bare-sphere 7.0 m fallback boundary that
## `tests/boarding_accessibility_test.gd` pins is still exercised, not widened.
func _add_flank_approach_range(boarding_area: Area3D) -> void:
	var existing := boarding_area.get_node_or_null("ArrowApproachRange")
	if existing != null:
		boarding_area.remove_child(existing)
		existing.queue_free()
	var approach := CollisionShape3D.new()
	approach.name = "ArrowApproachRange"
	var shape := BoxShape3D.new()
	shape.size = Vector3(13.8, 2.8, 15.2)
	approach.shape = shape
	# Centred on the hull rather than on the boarding marker, expressed relative to
	# the area's own offset so the marker keeps publishing the same world position.
	approach.position = -boarding_area.position
	boarding_area.add_child(approach)


func _add_box_collision(node_name: String, collision_position: Vector3, size: Vector3) -> void:
	var collision := CollisionShape3D.new()
	collision.name = node_name
	collision.position = collision_position
	var shape := BoxShape3D.new()
	shape.size = size
	collision.shape = shape
	add_child(collision)


func _update_arrow_presentation(delta: float) -> void:
	if _sensor_sweep != null:
		_sensor_sweep.rotation.y = fmod(_sensor_sweep.rotation.y + delta * 0.42, TAU)
	var telemetry := get_telemetry()
	var engine_state := StringName(telemetry.get("engine_state", &"OFFLINE"))
	var engine_level := 0.0
	if engine_state == ENGINE_STARTING:
		engine_level = 0.25 + 0.1 * sin(_elapsed_arrow * 16.0)
	elif engine_state == ENGINE_ONLINE:
		engine_level = 0.48 + clampf(velocity.length() / maxf(maximum_speed, 1.0), 0.0, 1.0) * 0.52
	var damage_presentation := get_damage_presentation()
	if is_instance_valid(damage_presentation):
		engine_level *= clampf(damage_presentation.get_engine_power_multiplier(), 0.0, 1.0)
	for plume in _engine_plumes:
		plume.visible = engine_level > 0.01
		plume.scale.z = lerpf(plume.scale.z, 0.42 + engine_level * 1.3, 1.0 - exp(-8.0 * delta))
	for light in _arrow_engine_lights:
		light.light_energy = engine_level * 2.2


func _sync_arrow_engine_presentation_immediately() -> void:
	var telemetry := get_telemetry()
	var state := StringName(telemetry.get("engine_state", ENGINE_OFFLINE))
	var active := not is_destroyed() and state in [ENGINE_STARTING, ENGINE_ONLINE]
	for plume in _engine_plumes:
		if is_instance_valid(plume):
			plume.visible = active
			if not active:
				plume.scale.z = 0.42
	for light in _arrow_engine_lights:
		if is_instance_valid(light):
			light.light_energy = 0.55 if active and state == ENGINE_STARTING else (1.1 if active else 0.0)


func _sync_variant_engine_presentation_immediately() -> void:
	_sync_arrow_engine_presentation_immediately()


func reset_for_reuse(spawn_transform: Transform3D) -> void:
	super.reset_for_reuse(spawn_transform)


func _apply_arrow_metadata() -> void:
	set_meta("arrow_recon_candidate", true)
	set_meta("evidence_status", EVIDENCE_STATUS)
	set_meta("evidence_scope", EVIDENCE_SCOPE)
	set_meta("name_to_model_status", NAME_TO_MODEL_STATUS)
	set_meta("authenticated_historical_silhouette", false)
	set_meta("creator_supported_escape_pod_count", SUPPORTED_ESCAPE_POD_COUNT)
	set_meta("content_note", PROVISIONAL_NOTE)
	set_meta("weapon_class", &"light_recon_pulse")
	set_meta("engine_profile", &"efficient_twin_recon")


func _collect_arrow_visual_census() -> Dictionary:
	var mesh_instances := _arrow_visual.find_children(
		"*", "MeshInstance3D", true, false
	)
	var multi_mesh_instances := _arrow_visual.find_children(
		"*", "MultiMeshInstance3D", true, false
	)
	var unique_mesh_resources := {}
	for candidate in mesh_instances:
		var instance := candidate as MeshInstance3D
		if instance.mesh != null:
			unique_mesh_resources[instance.mesh.get_instance_id()] = true
	var visible_geometry_copies := mesh_instances.size()
	var geometry_submissions := 0
	for candidate in mesh_instances:
		var instance := candidate as MeshInstance3D
		if instance.mesh != null:
			geometry_submissions += instance.mesh.get_surface_count()
	for candidate in multi_mesh_instances:
		var instance := candidate as MultiMeshInstance3D
		if instance.multimesh == null:
			continue
		visible_geometry_copies += instance.multimesh.visible_instance_count
		if instance.multimesh.mesh != null:
			unique_mesh_resources[instance.multimesh.mesh.get_instance_id()] = true
			geometry_submissions += instance.multimesh.mesh.get_surface_count()
	var auto_fallback_names := 0
	for candidate in _arrow_visual.find_children("*", "Node", true, false):
		if str((candidate as Node).name).begins_with("@"):
			auto_fallback_names += 1
	return {
		"nodes": _count_visual_nodes(_arrow_visual),
		"mesh_instance_nodes": mesh_instances.size(),
		"multi_mesh_instance_nodes": multi_mesh_instances.size(),
		"geometry_submissions": geometry_submissions,
		"visible_geometry_copies": visible_geometry_copies,
		"unique_mesh_resource_allocations": unique_mesh_resources.size(),
		"auto_fallback_names": auto_fallback_names,
	}


func _inspect_wing_root_rib_batch() -> Dictionary:
	var errors := PackedStringArray()
	var batch := _arrow_visual.get_node_or_null(
		"WingRootRibBatch"
	) as MultiMeshInstance3D
	if batch == null or batch.multimesh == null:
		return {
			"valid": false,
			"errors": PackedStringArray(["wing-root rib batch is missing"]),
		}.duplicate(true)
	var multimesh := batch.multimesh
	var mesh := multimesh.mesh as BoxMesh
	if _arrow_visual.get_node_or_null("WingRootRib") != null:
		errors.append("retired ordinary wing-root rib renderer remains")
	if multimesh.transform_format != MultiMesh.TRANSFORM_3D:
		errors.append("wing-root rib transform format drift")
	if multimesh.use_colors or multimesh.use_custom_data:
		errors.append("wing-root rib batch gained per-copy payload")
	if multimesh.instance_count != WING_ROOT_RIB_VISIBLE_COPIES \
		or multimesh.visible_instance_count != WING_ROOT_RIB_VISIBLE_COPIES:
		errors.append("wing-root rib visible-copy roster drift")
	if mesh == null or not mesh.size.is_equal_approx(WING_ROOT_RIB_SIZE):
		errors.append("wing-root rib primitive allocation drift")
	elif mesh.material != _arrow_materials.titanium:
		errors.append("wing-root rib material identity drift")
	var expected_transforms := _wing_root_rib_transforms()
	if not _transform_arrays_match(
		_wing_root_rib_authored_transforms, expected_transforms
	):
		errors.append("wing-root rib authored transform snapshot drift")
	var metadata_transforms := batch.get_meta(
		"authored_instance_transforms", []
	) as Array
	if not _transform_arrays_match(metadata_transforms, expected_transforms):
		errors.append("wing-root rib authored transform metadata drift")
	var expected_buffer := _multi_mesh_transform_buffer(expected_transforms)
	# The dummy/headless renderer discards MultiMesh buffers and reads every
	# transform as identity. A live renderer retains the deterministic payload,
	# so validate it whenever it is available while always auditing the CPU copy.
	if not multimesh.buffer.is_empty() and multimesh.buffer != expected_buffer:
		errors.append("wing-root rib renderer transform buffer drift")
	if mesh != null:
		var expected_bounds := _transformed_mesh_bounds(
			mesh.get_aabb(), expected_transforms
		)
		if not multimesh.custom_aabb.is_equal_approx(expected_bounds):
			errors.append("wing-root rib culling bounds drift")
	if not batch.transform.is_equal_approx(Transform3D.IDENTITY) or not batch.visible:
		errors.append("wing-root rib batch-root presentation drift")
	if batch.cast_shadow != GeometryInstance3D.SHADOW_CASTING_SETTING_ON \
		or batch.material_override != null:
		errors.append("wing-root rib render-state drift")
	var metadata_keys := batch.get_meta_list()
	if batch.get_child_count() != 0 or batch.get_script() != null \
		or not batch.get_groups().is_empty() \
		or metadata_keys.size() != 2 \
		or not metadata_keys.has(&"visual_detail_only") \
		or not metadata_keys.has(&"authored_instance_transforms") \
		or not bool(batch.get_meta("visual_detail_only", false)):
		errors.append("wing-root rib batch gained semantic authority")
	return {
		"valid": errors.is_empty(),
		"errors": errors,
		"node_name": str(batch.name),
		"geometry_nodes": 1,
		"geometry_submissions": 1,
		"visible_geometry_copies": multimesh.visible_instance_count,
		"primitive_mesh_allocations": 1 if mesh != null else 0,
		"multimesh_allocations": 1,
		"renderer_buffer_auditable": not multimesh.buffer.is_empty(),
		"culling_bounds": multimesh.custom_aabb,
		"authored_transforms": _wing_root_rib_authored_transforms.duplicate(),
		"legacy": {
			"geometry_nodes": 2,
			"geometry_submissions": 2,
			"visible_geometry_copies": 2,
			"primitive_mesh_allocations": 2,
			"multimesh_allocations": 0,
		},
	}.duplicate(true)


func _inspect_lateral_array_curve_joint_sharing() -> Dictionary:
	var errors := PackedStringArray()
	var joints: Array[MeshInstance3D] = []
	var actual_paths := PackedStringArray()
	var mesh_identities := {}
	var expected_transforms := _lateral_array_curve_joint_transforms()
	for index in LATERAL_ARRAY_CURVE_JOINT_PATHS.size():
		var path := NodePath(LATERAL_ARRAY_CURVE_JOINT_PATHS[index])
		var joint := _arrow_visual.get_node_or_null(path) as MeshInstance3D
		if joint == null or joint.mesh is not SphereMesh:
			errors.append(
				"lateral-array CurveJoint node/path roster drift: %s" % path
			)
			continue
		joints.append(joint)
		actual_paths.append(str(_arrow_visual.get_path_to(joint)))
		mesh_identities[joint.mesh.get_instance_id()] = true
		if not joint.transform.is_equal_approx(expected_transforms[index]):
			errors.append("lateral-array CurveJoint transform drift: %s" % path)
		if not joint.visible \
			or joint.cast_shadow != GeometryInstance3D.SHADOW_CASTING_SETTING_ON \
			or joint.material_override != null \
			or joint.material_overlay != null \
			or joint.layers != 1 \
			or not is_zero_approx(joint.transparency):
			errors.append("lateral-array CurveJoint render-state drift: %s" % path)
		if joint.get_child_count() != 0 \
			or joint.get_script() != null \
			or not joint.get_groups().is_empty() \
			or not joint.get_meta_list().is_empty():
			errors.append("lateral-array CurveJoint gained semantic authority: %s" % path)

	var family_child_count := 0
	for parent_name in [&"PortLateralArray", &"StarboardLateralArray"]:
		var parent := _arrow_visual.get_node_or_null(NodePath(parent_name))
		if parent == null:
			errors.append("lateral-array parent missing: %s" % parent_name)
			continue
		for child in parent.get_children():
			if child is MeshInstance3D and (child as MeshInstance3D).mesh is SphereMesh:
				family_child_count += 1
	if joints.size() != LATERAL_ARRAY_CURVE_JOINT_VISIBLE_COPIES \
		or family_child_count != LATERAL_ARRAY_CURVE_JOINT_VISIBLE_COPIES \
		or actual_paths != PackedStringArray(LATERAL_ARRAY_CURVE_JOINT_PATHS):
		errors.append("lateral-array CurveJoint visible/path roster drift")
	if mesh_identities.size() != 1:
		errors.append("lateral-array CurveJoint shared-mesh identity drift")

	var mesh := _lateral_array_curve_joint_mesh
	if mesh == null \
		or not is_equal_approx(mesh.radius, LATERAL_ARRAY_CURVE_JOINT_RADIUS) \
		or not is_equal_approx(mesh.height, LATERAL_ARRAY_CURVE_JOINT_RADIUS * 2.0) \
		or mesh.radial_segments != LATERAL_ARRAY_CURVE_JOINT_RADIAL_SEGMENTS \
		or mesh.rings != LATERAL_ARRAY_CURVE_JOINT_RINGS \
		or mesh.get_surface_count() != 1:
		errors.append("lateral-array CurveJoint primitive recipe drift")
	elif mesh.material != _arrow_materials.sensor:
		errors.append("lateral-array CurveJoint material identity drift")
	if mesh != null and mesh.resource_local_to_scene:
		errors.append("lateral-array CurveJoint mesh became scene-local")
	for joint in joints:
		if joint.mesh != mesh:
			errors.append("lateral-array CurveJoint retained a private mesh")
			break

	return {
		"valid": errors.is_empty(),
		"errors": errors,
		"node_paths": actual_paths,
		"authored_transforms": expected_transforms.duplicate(),
		"geometry_nodes": joints.size(),
		"geometry_submissions": joints.size(),
		"visible_geometry_copies": joints.size(),
		"primitive_mesh_allocations": mesh_identities.size(),
		"resource_allocation_reduction": 5,
		"component_retained_mesh_present": mesh != null,
		"resource_local_to_scene": mesh.resource_local_to_scene if mesh != null else true,
		"legacy": {
			"geometry_nodes": 6,
			"geometry_submissions": 6,
			"visible_geometry_copies": 6,
			"primitive_mesh_allocations": 6,
		},
	}.duplicate(true)


func _inspect_sensor_leading_edge_curve_joint_sharing() -> Dictionary:
	var errors := PackedStringArray()
	var joints: Array[MeshInstance3D] = []
	var actual_paths := PackedStringArray()
	var mesh_identities := {}
	var expected_transforms := _sensor_leading_edge_curve_joint_transforms()
	for index in SENSOR_LEADING_EDGE_CURVE_JOINT_PATHS.size():
		var path := NodePath(SENSOR_LEADING_EDGE_CURVE_JOINT_PATHS[index])
		var joint := _arrow_visual.get_node_or_null(path) as MeshInstance3D
		if joint == null or joint.mesh is not SphereMesh:
			errors.append(
				"sensor-leading-edge CurveJoint node/path roster drift: %s" % path
			)
			continue
		joints.append(joint)
		actual_paths.append(str(_arrow_visual.get_path_to(joint)))
		mesh_identities[joint.mesh.get_instance_id()] = true
		if not joint.transform.is_equal_approx(expected_transforms[index]):
			errors.append("sensor-leading-edge CurveJoint transform drift: %s" % path)
		if not joint.visible \
			or joint.cast_shadow != GeometryInstance3D.SHADOW_CASTING_SETTING_ON \
			or joint.material_override != null \
			or joint.material_overlay != null \
			or joint.layers != 1 \
			or not is_zero_approx(joint.transparency):
			errors.append("sensor-leading-edge CurveJoint render-state drift: %s" % path)
		if joint.get_child_count() != 0 \
			or joint.get_script() != null \
			or not joint.get_groups().is_empty() \
			or not joint.get_meta_list().is_empty():
			errors.append("sensor-leading-edge CurveJoint gained semantic authority: %s" % path)

	var family_child_count := 0
	for parent_path in [NodePath("SensorLeadingEdge"), NodePath("@Node3D@4")]:
		var parent := _arrow_visual.get_node_or_null(parent_path)
		if parent == null:
			errors.append("sensor-leading-edge parent missing: %s" % parent_path)
			continue
		for child in parent.get_children():
			if child is MeshInstance3D and (child as MeshInstance3D).mesh is SphereMesh:
				family_child_count += 1
	if joints.size() != SENSOR_LEADING_EDGE_CURVE_JOINT_VISIBLE_COPIES \
		or family_child_count != SENSOR_LEADING_EDGE_CURVE_JOINT_VISIBLE_COPIES \
		or actual_paths != PackedStringArray(SENSOR_LEADING_EDGE_CURVE_JOINT_PATHS):
		errors.append("sensor-leading-edge CurveJoint visible/path roster drift")
	if mesh_identities.size() != 1:
		errors.append("sensor-leading-edge CurveJoint shared-mesh identity drift")

	var mesh := _sensor_leading_edge_curve_joint_mesh
	if mesh == null \
		or not is_equal_approx(mesh.radius, SENSOR_LEADING_EDGE_CURVE_JOINT_RADIUS) \
		or not is_equal_approx(mesh.height, SENSOR_LEADING_EDGE_CURVE_JOINT_RADIUS * 2.0) \
		or mesh.radial_segments != SENSOR_LEADING_EDGE_CURVE_JOINT_RADIAL_SEGMENTS \
		or mesh.rings != SENSOR_LEADING_EDGE_CURVE_JOINT_RINGS \
		or mesh.get_surface_count() != 1:
		errors.append("sensor-leading-edge CurveJoint primitive recipe drift")
	elif mesh.material != _arrow_materials.sensor:
		errors.append("sensor-leading-edge CurveJoint material identity drift")
	if mesh != null and mesh.resource_local_to_scene:
		errors.append("sensor-leading-edge CurveJoint mesh became scene-local")
	for joint in joints:
		if joint.mesh != mesh:
			errors.append("sensor-leading-edge CurveJoint retained a private mesh")
			break

	return {
		"valid": errors.is_empty(),
		"errors": errors,
		"node_paths": actual_paths,
		"authored_transforms": expected_transforms.duplicate(),
		"geometry_nodes": joints.size(),
		"geometry_submissions": joints.size(),
		"visible_geometry_copies": joints.size(),
		"primitive_mesh_allocations": mesh_identities.size(),
		"resource_allocation_reduction": 5,
		"component_retained_mesh_present": mesh != null,
		"resource_local_to_scene": mesh.resource_local_to_scene if mesh != null else true,
		"legacy": {
			"geometry_nodes": 6,
			"geometry_submissions": 6,
			"visible_geometry_copies": 6,
			"primitive_mesh_allocations": 6,
		},
	}.duplicate(true)


func _inspect_dorsal_data_conduit_curve_joint_sharing() -> Dictionary:
	var errors := PackedStringArray()
	var joints: Array[MeshInstance3D] = []
	var actual_paths := PackedStringArray()
	var mesh_identities := {}
	var expected_transforms := _dorsal_data_conduit_curve_joint_transforms()
	for index in DORSAL_DATA_CONDUIT_CURVE_JOINT_PATHS.size():
		var path := NodePath(DORSAL_DATA_CONDUIT_CURVE_JOINT_PATHS[index])
		var joint := _arrow_visual.get_node_or_null(path) as MeshInstance3D
		if joint == null or joint.mesh is not SphereMesh:
			errors.append(
				"dorsal-data-conduit CurveJoint node/path roster drift: %s" % path
			)
			continue
		joints.append(joint)
		actual_paths.append(str(_arrow_visual.get_path_to(joint)))
		mesh_identities[joint.mesh.get_instance_id()] = true
		if not joint.transform.is_equal_approx(expected_transforms[index]):
			errors.append("dorsal-data-conduit CurveJoint transform drift: %s" % path)
		if not joint.visible \
			or joint.cast_shadow != GeometryInstance3D.SHADOW_CASTING_SETTING_ON \
			or joint.material_override != null \
			or joint.material_overlay != null \
			or joint.layers != 1 \
			or not is_zero_approx(joint.transparency):
			errors.append("dorsal-data-conduit CurveJoint render-state drift: %s" % path)
		if joint.get_child_count() != 0 \
			or joint.get_script() != null \
			or not joint.get_groups().is_empty() \
			or not joint.get_meta_list().is_empty():
			errors.append(
				"dorsal-data-conduit CurveJoint gained semantic authority: %s" % path
			)

	var conduit := _arrow_visual.get_node_or_null(^"DorsalDataConduit") as Node3D
	var family_child_count := 0
	if conduit == null:
		errors.append("dorsal-data-conduit parent missing")
	else:
		for child in conduit.get_children():
			if child is MeshInstance3D and (child as MeshInstance3D).mesh is SphereMesh:
				family_child_count += 1
	if joints.size() != DORSAL_DATA_CONDUIT_CURVE_JOINT_VISIBLE_COPIES \
		or family_child_count != DORSAL_DATA_CONDUIT_CURVE_JOINT_VISIBLE_COPIES \
		or actual_paths != PackedStringArray(DORSAL_DATA_CONDUIT_CURVE_JOINT_PATHS):
		errors.append("dorsal-data-conduit CurveJoint visible/path roster drift")
	if mesh_identities.size() != 1:
		errors.append("dorsal-data-conduit CurveJoint shared-mesh identity drift")

	var mesh := _dorsal_data_conduit_curve_joint_mesh
	if mesh == null \
		or not is_equal_approx(mesh.radius, DORSAL_DATA_CONDUIT_CURVE_JOINT_RADIUS) \
		or not is_equal_approx(mesh.height, DORSAL_DATA_CONDUIT_CURVE_JOINT_RADIUS * 2.0) \
		or mesh.radial_segments != DORSAL_DATA_CONDUIT_CURVE_JOINT_RADIAL_SEGMENTS \
		or mesh.rings != DORSAL_DATA_CONDUIT_CURVE_JOINT_RINGS \
		or mesh.get_surface_count() != 1:
		errors.append("dorsal-data-conduit CurveJoint primitive recipe drift")
	elif mesh.material != _arrow_materials.sensor:
		errors.append("dorsal-data-conduit CurveJoint material identity drift")
	if mesh != null and mesh.resource_local_to_scene:
		errors.append("dorsal-data-conduit CurveJoint mesh became scene-local")
	for joint in joints:
		if joint.mesh != mesh:
			errors.append("dorsal-data-conduit CurveJoint retained a private mesh")
			break

	return {
		"valid": errors.is_empty(),
		"errors": errors,
		"node_paths": actual_paths,
		"authored_transforms": expected_transforms.duplicate(),
		"geometry_nodes": joints.size(),
		"geometry_submissions": joints.size(),
		"visible_geometry_copies": joints.size(),
		"primitive_mesh_allocations": mesh_identities.size(),
		"resource_allocation_reduction": 2,
		"component_retained_mesh_present": mesh != null,
		"resource_local_to_scene": mesh.resource_local_to_scene if mesh != null else true,
		"legacy": {
			"geometry_nodes": 3,
			"geometry_submissions": 3,
			"visible_geometry_copies": 3,
			"primitive_mesh_allocations": 3,
		},
	}.duplicate(true)


func _inspect_fuselage_panel_band_mesh_sharing() -> Dictionary:
	var errors := PackedStringArray()
	var bands: Array[MeshInstance3D] = []
	var actual_paths := PackedStringArray()
	var mesh_identities := {}
	var expected_transforms := _fuselage_panel_band_transforms()
	for child in _arrow_visual.get_children():
		var band := child as MeshInstance3D
		if band == null or band.mesh is not TorusMesh:
			continue
		var band_mesh := band.mesh as TorusMesh
		if not is_equal_approx(
			band_mesh.inner_radius, FUSELAGE_PANEL_BAND_INNER_RADIUS
		) or not is_equal_approx(
			band_mesh.outer_radius, FUSELAGE_PANEL_BAND_OUTER_RADIUS
		):
			continue
		var index := bands.size()
		bands.append(band)
		var path := str(_arrow_visual.get_path_to(band))
		actual_paths.append(path)
		mesh_identities[band.mesh.get_instance_id()] = true
		if index >= expected_transforms.size() \
			or not band.transform.is_equal_approx(expected_transforms[index]):
			errors.append("fuselage panel-band transform drift: %s" % path)
		if not band.visible \
			or band.cast_shadow != GeometryInstance3D.SHADOW_CASTING_SETTING_ON \
			or band.material_override != null \
			or band.material_overlay != null \
			or band.layers != 1 \
			or not is_zero_approx(band.transparency):
			errors.append("fuselage panel-band render-state drift: %s" % path)
		if not StringName(
			band.get_meta(TorusGeometryBudget.PROFILE_META, &"")
		).is_empty():
			errors.append("fuselage panel-band torus-budget profile drift: %s" % path)
		if band.get_child_count() != 0 \
			or band.get_script() != null \
			or not band.get_groups().is_empty() \
			or not band.get_meta_list().is_empty():
			errors.append("fuselage panel-band gained semantic authority: %s" % path)

	if bands.size() != FUSELAGE_PANEL_BAND_VISIBLE_COPIES \
		or actual_paths.is_empty() \
		or actual_paths[0] != FUSELAGE_PANEL_BAND_STABLE_PATH:
		errors.append("fuselage panel-band visible/path roster drift")
	for index in range(1, actual_paths.size()):
		if not actual_paths[index].begins_with("@MeshInstance3D@"):
			errors.append("fuselage panel-band generated sibling path drift")
			break
	if mesh_identities.size() != 1:
		errors.append("fuselage panel-band shared-mesh identity drift")

	var mesh := _fuselage_panel_band_mesh
	var normalised := mesh != null \
		and mesh.has_meta(TorusGeometryBudget.AUTHORED_META)
	var authored_tessellation := Vector2i(
		FUSELAGE_PANEL_BAND_AUTHORED_RINGS,
		FUSELAGE_PANEL_BAND_AUTHORED_RING_SEGMENTS
	)
	var retained_authored_tessellation := Vector2i.ZERO
	if normalised:
		var authored_value: Variant = mesh.get_meta(
			TorusGeometryBudget.AUTHORED_META, Vector2i.ZERO
		)
		if authored_value is Vector2i:
			retained_authored_tessellation = authored_value
		if retained_authored_tessellation != authored_tessellation:
			errors.append("fuselage panel-band authored budget metadata drift")
	var expected_tessellation := Vector2i(
		FUSELAGE_PANEL_BAND_BUDGETED_RINGS,
		FUSELAGE_PANEL_BAND_BUDGETED_RING_SEGMENTS
	) if normalised else authored_tessellation
	if mesh == null \
		or not is_equal_approx(mesh.inner_radius, FUSELAGE_PANEL_BAND_INNER_RADIUS) \
		or not is_equal_approx(mesh.outer_radius, FUSELAGE_PANEL_BAND_OUTER_RADIUS) \
		or mesh.rings != expected_tessellation.x \
		or mesh.ring_segments != expected_tessellation.y \
		or mesh.get_surface_count() != 1:
		errors.append("fuselage panel-band primitive recipe drift")
	elif mesh.material != _arrow_materials.titanium:
		errors.append("fuselage panel-band material identity drift")
	if mesh != null:
		var expected_mesh_metadata := PackedStringArray([
			TorusGeometryBudget.AUTHORED_META
		]) if normalised else PackedStringArray()
		var actual_mesh_metadata := PackedStringArray()
		for key in mesh.get_meta_list():
			actual_mesh_metadata.append(str(key))
		actual_mesh_metadata.sort()
		expected_mesh_metadata.sort()
		if actual_mesh_metadata != expected_mesh_metadata:
			errors.append("fuselage panel-band mesh budget metadata roster drift")
		if mesh.resource_local_to_scene:
			errors.append("fuselage panel-band mesh became scene-local")
	for band in bands:
		if band.mesh != mesh:
			errors.append("fuselage panel-band retained a private mesh")
			break

	return {
		"valid": errors.is_empty(),
		"errors": errors,
		"node_paths": actual_paths,
		"authored_transforms": expected_transforms.duplicate(),
		"geometry_nodes": bands.size(),
		"geometry_submissions": bands.size(),
		"visible_geometry_copies": bands.size(),
		"primitive_mesh_allocations": mesh_identities.size(),
		"resource_allocation_reduction": 4,
		"component_retained_mesh_present": mesh != null,
		"resource_local_to_scene": mesh.resource_local_to_scene if mesh != null else true,
		"normalised_by_torus_budget": normalised,
		"authored_tessellation": authored_tessellation,
		"current_tessellation": Vector2i(
			mesh.rings, mesh.ring_segments
		) if mesh != null else Vector2i.ZERO,
		"budget_profile": &"",
		"legacy": {
			"geometry_nodes": 5,
			"geometry_submissions": 5,
			"visible_geometry_copies": 5,
			"primitive_mesh_allocations": 5,
		},
	}.duplicate(true)


func _count_visual_nodes(search_root: Node) -> int:
	var count := 1
	for child in search_root.get_children():
		count += _count_visual_nodes(child)
	return count


static func _wing_root_rib_transforms() -> Array[Transform3D]:
	var transforms: Array[Transform3D] = []
	for side in [-1.0, 1.0]:
		transforms.append(Transform3D(
			Basis.from_euler(Vector3(0, side * -0.08, 0)),
			Vector3(side * 1.45, 1.03, 1.0)
		))
	return transforms


static func _lateral_array_curve_joint_transforms() -> Array[Transform3D]:
	return [
		Transform3D(Basis.IDENTITY, Vector3(-1.35, 1.36, -2.0)),
		Transform3D(Basis.IDENTITY, Vector3(-2.25, 1.38, -1.2)),
		Transform3D(Basis.IDENTITY, Vector3(-3.45, 1.25, -0.25)),
		Transform3D(Basis.IDENTITY, Vector3(1.35, 1.36, -2.0)),
		Transform3D(Basis.IDENTITY, Vector3(2.25, 1.38, -1.2)),
		Transform3D(Basis.IDENTITY, Vector3(3.45, 1.25, -0.25)),
	]


static func _sensor_leading_edge_curve_joint_transforms() -> Array[Transform3D]:
	return [
		Transform3D(Basis.IDENTITY, Vector3(-1.0, 1.19, -1.65)),
		Transform3D(Basis.IDENTITY, Vector3(-3.4, 1.1, -0.55)),
		Transform3D(Basis.IDENTITY, Vector3(-5.35, 1.02, 0.75)),
		Transform3D(Basis.IDENTITY, Vector3(1.0, 1.19, -1.65)),
		Transform3D(Basis.IDENTITY, Vector3(3.4, 1.1, -0.55)),
		Transform3D(Basis.IDENTITY, Vector3(5.35, 1.02, 0.75)),
	]


static func _dorsal_data_conduit_curve_joint_transforms() -> Array[Transform3D]:
	return [
		Transform3D(Basis.IDENTITY, Vector3(0.0, 2.52, -0.6)),
		Transform3D(Basis.IDENTITY, Vector3(0.0, 2.65, 1.45)),
		Transform3D(Basis.IDENTITY, Vector3(0.0, 2.42, 3.8)),
	]


static func _fuselage_panel_band_transforms() -> Array[Transform3D]:
	var basis := Basis.from_euler(Vector3(deg_to_rad(90.0), 0.0, 0.0))
	basis.x *= 1.0
	basis.y *= 0.58
	basis.z *= 1.0
	var transforms: Array[Transform3D] = []
	for seam_z in [-4.4, -2.6, 0.4, 2.2, 4.3]:
		transforms.append(Transform3D(basis, Vector3(0, 1.22, seam_z)))
	return transforms


static func _transform_arrays_match(
	actual: Array,
	expected: Array[Transform3D]
	) -> bool:
	if actual.size() != expected.size():
		return false
	for index in expected.size():
		if not (actual[index] as Transform3D).is_equal_approx(expected[index]):
			return false
	return true


func _material(color: Color, metallic: float, roughness: float, emission := Color.BLACK, energy := 0.0) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.metallic = metallic
	material.roughness = roughness
	material.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL
	material.diffuse_mode = BaseMaterial3D.DIFFUSE_BURLEY
	material.specular_mode = BaseMaterial3D.SPECULAR_SCHLICK_GGX
	if energy > 0.0:
		material.emission_enabled = true
		material.emission = emission
		material.emission_energy_multiplier = energy
	return material


func _transparent_material(color: Color, metallic: float, roughness: float) -> StandardMaterial3D:
	var material := _material(color, metallic, roughness)
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.cull_mode = BaseMaterial3D.CULL_BACK
	material.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	material.render_priority = 1
	return material


func _multi_mesh_box(
	parent: Node3D,
	node_name: String,
	size: Vector3,
	material: Material,
	transforms: Array[Transform3D]
	) -> MultiMeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh.material = material
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.mesh = mesh
	multimesh.instance_count = transforms.size()
	multimesh.visible_instance_count = transforms.size()
	multimesh.buffer = _multi_mesh_transform_buffer(transforms)
	multimesh.custom_aabb = _transformed_mesh_bounds(mesh.get_aabb(), transforms)
	var instance := MultiMeshInstance3D.new()
	instance.name = node_name
	instance.multimesh = multimesh
	instance.set_meta("visual_detail_only", true)
	instance.set_meta("authored_instance_transforms", transforms.duplicate())
	parent.add_child(instance)
	return instance


static func _multi_mesh_transform_buffer(
	transforms: Array[Transform3D]
	) -> PackedFloat32Array:
	var buffer := PackedFloat32Array()
	buffer.resize(transforms.size() * 12)
	for index in transforms.size():
		var value := transforms[index]
		var offset := index * 12
		buffer[offset + 0] = value.basis.x.x
		buffer[offset + 1] = value.basis.y.x
		buffer[offset + 2] = value.basis.z.x
		buffer[offset + 3] = value.origin.x
		buffer[offset + 4] = value.basis.x.y
		buffer[offset + 5] = value.basis.y.y
		buffer[offset + 6] = value.basis.z.y
		buffer[offset + 7] = value.origin.y
		buffer[offset + 8] = value.basis.x.z
		buffer[offset + 9] = value.basis.y.z
		buffer[offset + 10] = value.basis.z.z
		buffer[offset + 11] = value.origin.z
	return buffer


static func _transformed_mesh_bounds(
	mesh_bounds: AABB,
	transforms: Array[Transform3D]
	) -> AABB:
	var result := AABB()
	var first := true
	for value in transforms:
		var piece := (value * mesh_bounds).abs()
		if first:
			result = piece
			first = false
		else:
			result = result.merge(piece)
	return result


func _loft_hull(parent: Node3D, node_name: String, origin: Vector3, sections: PackedVector3Array, material: Material) -> MeshInstance3D:
	const RING_COUNT := 20
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	tool.set_material(material)
	for section_index in sections.size():
		var section := sections[section_index]
		for ring_index in RING_COUNT:
			var angle := TAU * float(ring_index) / float(RING_COUNT)
			var cosine := cos(angle)
			var sine := sin(angle)
			var rounded_x := signf(cosine) * pow(absf(cosine), 0.72)
			var rounded_y := signf(sine) * pow(absf(sine), 0.72)
			tool.set_uv(Vector2(float(ring_index) / float(RING_COUNT), float(section_index) / float(maxi(1, sections.size() - 1))))
			tool.add_vertex(Vector3(section.x * rounded_x, section.y * rounded_y, section.z))
	for section_index in sections.size() - 1:
		for ring_index in RING_COUNT:
			var next_ring := (ring_index + 1) % RING_COUNT
			var current := section_index * RING_COUNT + ring_index
			var current_next := section_index * RING_COUNT + next_ring
			var following := (section_index + 1) * RING_COUNT + ring_index
			var following_next := (section_index + 1) * RING_COUNT + next_ring
			tool.add_index(current)
			tool.add_index(following)
			tool.add_index(following_next)
			tool.add_index(current)
			tool.add_index(following_next)
			tool.add_index(current_next)
	var front_center := sections.size() * RING_COUNT
	tool.add_vertex(Vector3(0, 0, sections[0].z))
	var rear_center := front_center + 1
	tool.add_vertex(Vector3(0, 0, sections[sections.size() - 1].z))
	for ring_index in RING_COUNT:
		var next_ring := (ring_index + 1) % RING_COUNT
		tool.add_index(front_center)
		tool.add_index(next_ring)
		tool.add_index(ring_index)
		var rear_base := (sections.size() - 1) * RING_COUNT
		tool.add_index(rear_center)
		tool.add_index(rear_base + ring_index)
		tool.add_index(rear_base + next_ring)
	tool.generate_normals()
	var instance := MeshInstance3D.new()
	instance.name = node_name
	instance.position = origin
	instance.mesh = tool.commit()
	parent.add_child(instance)
	return instance


func _build_planform_surface(node_name: String, outline: PackedVector3Array, thickness: float, material: Material) -> MeshInstance3D:
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	tool.set_material(material)
	var half_thickness := thickness * 0.5
	for point in outline:
		tool.add_vertex(point + Vector3.UP * half_thickness)
	for point in outline:
		tool.add_vertex(point - Vector3.UP * half_thickness)
	for triangle in [[0, 1, 2], [0, 2, 3]]:
		tool.add_index(triangle[0])
		tool.add_index(triangle[1])
		tool.add_index(triangle[2])
		tool.add_index(outline.size() + triangle[0])
		tool.add_index(outline.size() + triangle[2])
		tool.add_index(outline.size() + triangle[1])
	for index in outline.size():
		var next := (index + 1) % outline.size()
		var top_a := index
		var top_b := next
		var bottom_a := outline.size() + index
		var bottom_b := outline.size() + next
		tool.add_index(top_a)
		tool.add_index(bottom_a)
		tool.add_index(bottom_b)
		tool.add_index(top_a)
		tool.add_index(bottom_b)
		tool.add_index(top_b)
	tool.generate_normals()
	var instance := MeshInstance3D.new()
	instance.name = node_name
	instance.mesh = tool.commit()
	return instance


func _curve_tube(
	parent: Node3D,
	node_name: String,
	points: PackedVector3Array,
	radius: float,
	material: Material,
	joint_mesh: SphereMesh = null,
	) -> Node3D:
	var root := Node3D.new()
	root.name = node_name
	parent.add_child(root)
	for index in points.size() - 1:
		var direction := points[index + 1] - points[index]
		var segment := _cylinder(root, "Segment%02d" % index, (points[index] + points[index + 1]) * 0.5, radius, direction.length(), material)
		segment.quaternion = Quaternion(Vector3.UP, direction.normalized())
	for point in points:
		_sphere(root, "CurveJoint", point, radius, material, joint_mesh)
	return root


func _box(parent: Node3D, node_name: String, position: Vector3, size: Vector3, material: Material, rotation := Vector3.ZERO) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.name = node_name
	instance.position = position
	instance.rotation = rotation
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh.material = material
	instance.mesh = mesh
	parent.add_child(instance)
	return instance


func _cylinder(parent: Node3D, node_name: String, position: Vector3, radius: float, height: float, material: Material, rotation_degrees_value := Vector3.ZERO) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.name = node_name
	instance.position = position
	instance.rotation_degrees = rotation_degrees_value
	# Chamfered rims at the Arrow's frozen 36 radial segments. Note what this does
	# and does not reach: the Arrow's engine housings are `_loft_hull` surfaces
	# that close on a centre point with averaged normals, and its engine collars
	# are tori, so neither ever had a 90° rim. What passes through here is the
	# mast pedestal and stem, the array crossbar, the gear struts, the conduit
	# tube segments and the emissive plume. Wall subdivision: see
	# `ShipSurfaceDetail.CYLINDER_WALL_RINGS`.
	instance.mesh = StationSurfaceKit.chamfered_cylinder_mesh_cached(
		radius, radius, height, 36, _chamfered_cylinder_cache,
		ShipSurfaceDetail.CYLINDER_WALL_RINGS, true, true, material
	)
	parent.add_child(instance)
	return instance


func _sphere(
	parent: Node3D,
	node_name: String,
	position: Vector3,
	radius: float,
	material: Material,
	shared_mesh: SphereMesh = null,
	) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.name = node_name
	instance.position = position
	var mesh := shared_mesh
	if mesh == null:
		mesh = SphereMesh.new()
		mesh.radius = radius
		mesh.height = radius * 2.0
		mesh.radial_segments = 28
		mesh.rings = 14
		mesh.material = material
	instance.mesh = mesh
	parent.add_child(instance)
	return instance


func _torus(
	parent: Node3D,
	node_name: String,
	position: Vector3,
	inner_radius: float,
	outer_radius: float,
	material: Material,
	rotation_degrees_value := Vector3.ZERO,
	scale_value := Vector3.ONE,
	shared_mesh: TorusMesh = null
	) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.name = node_name
	instance.position = position
	instance.rotation_degrees = rotation_degrees_value
	instance.scale = scale_value
	var mesh := shared_mesh
	if mesh == null:
		mesh = TorusMesh.new()
		mesh.inner_radius = inner_radius
		mesh.outer_radius = outer_radius
		mesh.rings = 64
		mesh.ring_segments = 18
		mesh.material = material
	instance.mesh = mesh
	parent.add_child(instance)
	return instance
