class_name StationOperationsActivity
extends Node3D

## Reusable, presentation-only station operations vignette.
##
## This component supplies visible maintenance motion without owning gameplay,
## navigation, docking, or collision. Its deterministic clock can be advanced
## manually for captures, tests, replays, and future network presentation.

const SCHEMA_VERSION := 1
const COMPONENT_ID: StringName = &"station-operations-activity"
const EVIDENCE_STATUS: StringName = &"modern_interpretation"
const DEFAULT_VARIATION_SEED := 29173

enum ActivityProfile {
	FULL,
	GANTRY,
	SERVICE_ARM,
	DRONE_PATROL,
}

const PROFILE_IDS := {
	ActivityProfile.FULL: &"full",
	ActivityProfile.GANTRY: &"gantry",
	ActivityProfile.SERVICE_ARM: &"service_arm",
	ActivityProfile.DRONE_PATROL: &"drone_patrol",
}

const FOOTPRINT_MIN := Vector3(-5.4, 0.0, -4.5)
const FOOTPRINT_MAX := Vector3(5.9, 7.25, 4.5)
const SERVICE_ZONE_CENTER := Vector3(0.0, 2.9, 0.0)
const SERVICE_ZONE_HALF_EXTENTS := Vector3(5.9, 3.8, 5.0)

const GANTRY_TRAVEL := 3.15
const GANTRY_ELEVATION := 5.78
const DRONE_COUNT := 2
const BEACON_COUNT := 4
## Half the safety beacon `Base` pedestal height (0.18 m), so the pedestal's
## underside rests on this component's mounting plane instead of hovering. See
## `_get_beacon_positions()` and MAP-005 in `bugs.md`.
const BEACON_SEAT_HEIGHT := 0.09
const RECOMMENDED_MAX_INSTANCES := 6

const PROFILE_PERFORMANCE_BUDGETS := {
	ActivityProfile.FULL: {
		"node_count": 96,
		"mesh_instances": 79,
		"unique_materials": 12,
		"lights": 0,
		"particle_emitters": 0,
		"collision_nodes": 0,
		"animated_assemblies": 5,
	},
	ActivityProfile.GANTRY: {
		"node_count": 59,
		"mesh_instances": 48,
		"unique_materials": 12,
		"lights": 0,
		"particle_emitters": 0,
		"collision_nodes": 0,
		"animated_assemblies": 1,
	},
	ActivityProfile.SERVICE_ARM: {
		"node_count": 31,
		"mesh_instances": 19,
		"unique_materials": 12,
		"lights": 0,
		"particle_emitters": 0,
		"collision_nodes": 0,
		"animated_assemblies": 2,
	},
	ActivityProfile.DRONE_PATROL: {
		"node_count": 42,
		"mesh_instances": 32,
		"unique_materials": 12,
		"lights": 0,
		"particle_emitters": 0,
		"collision_nodes": 0,
		"animated_assemblies": 2,
	},
}

const RECOMMENDED_PRODUCTION_ROSTER_BUDGET := {
	"instance_count": 4,
	"node_count": 228,
	"mesh_instances": 180,
	"unique_materials": 64,
	"lights": 0,
	"particle_emitters": 0,
	"collision_nodes": 0,
	"animated_assemblies": 10,
}

const CONTENT_NOTE := (
	"The remake brief supports richer station machinery, docking equipment, cargo, "
	+ "animated equipment, landing lights, and ambient station activity. It does not "
	+ "authenticate this gantry, articulated service arm, drones, beacon arrangement, "
	+ "dimensions, motion, colours, or placement. Every visible detail in this reusable "
	+ "component is an original modern interpretation and not recovered station geometry."
)

@export_category("Activity")
@export_enum("Full:0", "Gantry:1", "Service Arm:2", "Drone Patrol:3") var activity_profile: int = ActivityProfile.FULL
@export var starts_enabled := true
@export var starts_paused := false
@export_range(0.1, 3.0, 0.05) var playback_speed := 1.0
@export_range(0, 999999, 1) var variation_seed := DEFAULT_VARIATION_SEED

@onready var _mount_anchor: Marker3D = get_node(^"MountAnchor") as Marker3D
@onready var _service_zone_anchor: Marker3D = get_node(^"ServiceZoneAnchor") as Marker3D
@onready var _presentation_root: Node3D = get_node(^"PresentationRoot") as Node3D

var _materials: Dictionary = {}
var _gantry_carriage: Node3D
var _gantry_tool: Node3D
var _service_arm_shoulder: Node3D
var _service_arm_elbow: Node3D
var _service_arm_tool: Node3D
var _drone_roots: Array[Node3D] = []
var _drone_beacon_lenses: Array[MeshInstance3D] = []
var _beacon_lenses: Array[MeshInstance3D] = []
var _elapsed := 0.0
var _activity_enabled := true
var _activity_paused := false
var _enabled_overridden := false
var _paused_overridden := false
var _built_profile := ActivityProfile.FULL
var _built_starts_enabled := true
var _built_starts_paused := false
var _built_playback_speed := 1.0
var _built_variation_seed := DEFAULT_VARIATION_SEED
var _built := false
var _built_node_instance_ids: Dictionary = {}
var _built_static_node_transforms: Dictionary = {}
var _built_node_visibility: Dictionary = {}
var _built_mesh_contracts: Dictionary = {}
var _built_material_contracts: Dictionary = {}
## Size-keyed chamfered box meshes. Equal-sized boxes deliberately share one
## `ArrayMesh`, so the extra edge geometry costs vertices once per distinct size
## rather than once per placement.
var _rounded_box_cache: Dictionary = {}


func _enter_tree() -> void:
	# `_ready()` only runs on the first tree entry. Restore the component's
	# desired process state when an owning world removes and re-adds this child.
	if _built:
		_refresh_lifecycle()


func _ready() -> void:
	add_to_group(&"station_operations_activity", false)
	if _built:
		return
	_built = true
	_built_profile = activity_profile
	_built_starts_enabled = starts_enabled
	_built_starts_paused = starts_paused
	_built_playback_speed = playback_speed
	_built_variation_seed = variation_seed
	_create_materials()
	if _profile_has_gantry():
		_build_gantry()
	if _profile_has_service_arm():
		_build_service_arm()
	if _profile_has_drones():
		_build_service_drones()
	_build_safety_beacons()
	_service_zone_anchor.position = _get_profile_service_zone_center()
	_apply_evidence_metadata()
	if not _enabled_overridden:
		_activity_enabled = starts_enabled
	if not _paused_overridden:
		_activity_paused = starts_paused
	_update_activity_transforms()
	_refresh_lifecycle()
	_capture_built_presentation_contract()


func _process(delta: float) -> void:
	advance_activity_simulation(delta * _get_effective_playback_speed())


func _exit_tree() -> void:
	set_process(false)


func get_component_id() -> StringName:
	return COMPONENT_ID


func get_activity_profile() -> int:
	return _built_profile if _built else activity_profile


func get_activity_profile_id() -> StringName:
	return PROFILE_IDS.get(get_activity_profile(), &"invalid") as StringName


func get_activity_profile_ids() -> PackedStringArray:
	return PackedStringArray([
		PROFILE_IDS[ActivityProfile.FULL],
		PROFILE_IDS[ActivityProfile.GANTRY],
		PROFILE_IDS[ActivityProfile.SERVICE_ARM],
		PROFILE_IDS[ActivityProfile.DRONE_PATROL],
	])


func get_mount_anchor() -> Marker3D:
	return _mount_anchor if is_instance_valid(_mount_anchor) else null


func get_mount_transform() -> Transform3D:
	return (
		_mount_anchor.global_transform
		if (
			is_instance_valid(_mount_anchor)
			and get_node_or_null(^"MountAnchor") == _mount_anchor
			and is_ancestor_of(_mount_anchor)
		)
		else global_transform
	)


func get_service_zone_anchor() -> Marker3D:
	return _service_zone_anchor if is_instance_valid(_service_zone_anchor) else null


func get_mount_footprint_count() -> int:
	match get_activity_profile():
		ActivityProfile.FULL, ActivityProfile.GANTRY:
			return 4
		ActivityProfile.SERVICE_ARM:
			return 1
		ActivityProfile.DRONE_PATROL:
			return 4
		_:
			return 0


## The origin is the centre of a level deck mount. Local +Y is up and local
## -Z faces the serviced berth or traffic lane. No space in this envelope is
## physically blocked because every generated child is presentation-only.
func get_integration_contract() -> Dictionary:
	var local_min := _get_profile_local_min()
	var local_max := _get_profile_local_max()
	var service_zone_center := _get_profile_service_zone_center()
	var mount_type := _get_profile_mount_type()
	return {
		"schema_version": SCHEMA_VERSION,
		"component_id": COMPONENT_ID,
		"activity_profile": get_activity_profile(),
		"activity_profile_id": get_activity_profile_id(),
		"mount_type": mount_type,
		"mount_description": _get_profile_mount_description(),
		"visible_mount_footprint_count": get_mount_footprint_count(),
		"mount_transform": get_mount_transform(),
		"local_min": local_min,
		"local_max": local_max,
		"local_size": local_max - local_min,
		"service_zone_transform": global_transform * Transform3D(Basis.IDENTITY, service_zone_center),
		"service_zone_half_extents": _get_profile_service_zone_half_extents(),
		"up_axis_local": Vector3.UP,
		"service_facing_axis_local": Vector3.FORWARD,
		"collision_policy": &"presentation_only_nonblocking",
		"requires_level_floor": mount_type == &"level_deck" or mount_type == &"deck_edge",
		"required_floor_contact_depth": 0.0,
		"recommended_instance_spacing": 12.0,
		"recommended_max_instances": RECOMMENDED_MAX_INSTANCES,
		"recommended_production_roster": get_activity_profile_ids(),
		"drone_motion_envelope": _get_drone_motion_envelope(),
	}


func get_evidence_metadata() -> Dictionary:
	return {
		"schema_version": SCHEMA_VERSION,
		"component_id": COMPONENT_ID,
		"activity_profile_id": get_activity_profile_id(),
		"evidence_status": EVIDENCE_STATUS,
		"source_bounded": true,
		"authenticated_original_geometry": false,
		"authenticated_original_placement": false,
		"references": PackedStringArray([
			"Goal brief: Shipyard / machinery, docking equipment, cargo, animated equipment, and ambient station activity",
			"Goal brief: Visual Direction / polished stylised science-fiction with readable colour",
			"Goal brief: Creative Freedom / additions must feel like a natural evolution of Keth Shipyards",
		]),
		"supported_invariants": PackedStringArray([
			"the modern station should feel operational rather than visually empty",
			"animated equipment and docking or maintenance infrastructure are appropriate modern additions",
			"clean colourful readability should remain visible within richer modern detail",
		]),
		"modern_interpretations": PackedStringArray([
			"freestanding gantry frame, carriage, telescoping service tool, and motion envelope",
			"articulated maintenance arm, tool head, materials, dimensions, and motion sequence",
			"two autonomous service drones, their routes, lights, cargo pods, and timing",
			"four warning beacons, visual cadence, colour, component footprint, and placement",
		]),
		"explicit_unknowns": PackedStringArray([
			"historical station machinery layout, dimensions, appearance, and animation",
			"whether autonomous service drones existed in any original or fixed-era build",
			"authoritative maintenance workflows and traffic-control light patterns",
		]),
		"content_note": CONTENT_NOTE,
	}


func set_activity_enabled(enabled: bool) -> void:
	_enabled_overridden = true
	if _activity_enabled == enabled:
		_refresh_lifecycle()
		return
	_activity_enabled = enabled
	_refresh_lifecycle()


func is_activity_enabled() -> bool:
	return _activity_enabled


func set_activity_paused(paused: bool) -> void:
	_paused_overridden = true
	if _activity_paused == paused:
		_refresh_lifecycle()
		return
	_activity_paused = paused
	_refresh_lifecycle()


func is_activity_paused() -> bool:
	return _activity_paused


func is_activity_advancing() -> bool:
	return _activity_enabled and not _activity_paused


## Advances the component only while enabled and unpaused. The transforms are
## functions of total elapsed time, so frame subdivision does not change state.
func advance_activity_simulation(delta: float) -> bool:
	if not is_activity_advancing() or not is_finite(delta) or delta <= 0.0:
		return false
	_elapsed += delta
	_update_activity_transforms()
	return true


## Deterministic seek used by capture tooling. This intentionally works while
## paused or disabled, but it never changes either lifecycle flag.
func set_activity_time(seconds: float) -> bool:
	if not is_finite(seconds) or seconds < 0.0:
		return false
	_elapsed = seconds
	_update_activity_transforms()
	return true


func reset_activity_time() -> void:
	_elapsed = 0.0
	_update_activity_transforms()


func get_activity_time() -> float:
	return _elapsed


func get_activity_state() -> Dictionary:
	var drones: Array[Dictionary] = []
	for drone in _drone_roots:
		drones.append({
			"position": drone.position,
			"rotation": drone.rotation,
		})
	return {
		"activity_profile": get_activity_profile(),
		"activity_profile_id": get_activity_profile_id(),
		"elapsed": _elapsed,
		"enabled": _activity_enabled,
		"paused": _activity_paused,
		"advancing": is_activity_advancing(),
		"visible": _presentation_root != null and _presentation_root.visible,
		"gantry_carriage_position": _gantry_carriage.position if _gantry_carriage != null else Vector3.ZERO,
		"gantry_tool_position": _gantry_tool.position if _gantry_tool != null else Vector3.ZERO,
		"service_arm_shoulder_rotation": _service_arm_shoulder.rotation if _service_arm_shoulder != null else Vector3.ZERO,
		"service_arm_elbow_rotation": _service_arm_elbow.rotation if _service_arm_elbow != null else Vector3.ZERO,
		"drones": drones,
		"beacon_pattern": _get_beacon_pattern(),
	}


func get_determinism_fingerprint() -> String:
	var equipment := get_equipment_counts()
	var local_min := _get_profile_local_min()
	var local_max := _get_profile_local_max()
	return "%s|v%d|profile=%s|seed=%d|gantry=%d|arm=%d|drones=%d|beacons=%d|envelope=%s:%s" % [
		str(COMPONENT_ID),
		SCHEMA_VERSION,
		str(get_activity_profile_id()),
		_get_effective_variation_seed(),
		equipment.gantry_count,
		equipment.service_arm_count,
		equipment.service_drone_count,
		equipment.safety_beacon_count,
		str(local_min),
		str(local_max),
	]


func get_equipment_counts() -> Dictionary:
	var gantry_count := 1 if _gantry_carriage != null and _gantry_tool != null else 0
	var service_arm_count := 1 if _service_arm_shoulder != null and _service_arm_elbow != null and _service_arm_tool != null else 0
	var animated_assembly_count := gantry_count + service_arm_count * 2 + _drone_roots.size()
	return {
		"gantry_count": gantry_count,
		"service_arm_count": service_arm_count,
		"service_drone_count": _drone_roots.size(),
		"safety_beacon_count": _beacon_lenses.size(),
		"animated_assembly_count": animated_assembly_count,
	}


func get_recommended_production_roster_budget() -> Dictionary:
	return {
		"schema_version": SCHEMA_VERSION,
		"profiles": get_activity_profile_ids(),
		"budgets": RECOMMENDED_PRODUCTION_ROSTER_BUDGET.duplicate(true),
		"mesh_budget_rationale": (
			"One distinct FULL, GANTRY, SERVICE_ARM, and DRONE_PATROL placement; "
			+ "specialized roles omit unrelated assemblies instead of hiding them."
		),
	}


static func audit_production_roster(activities: Array[Node]) -> Dictionary:
	var counts := {
		"instance_count": 0,
		"node_count": 0,
		"mesh_instances": 0,
		"unique_materials": 0,
		"lights": 0,
		"particle_emitters": 0,
		"collision_nodes": 0,
		"animated_assemblies": 0,
	}
	var profile_counts := {
		&"full": 0,
		&"gantry": 0,
		&"service_arm": 0,
		&"drone_patrol": 0,
	}
	var errors := PackedStringArray()
	for candidate in activities:
		if not candidate is StationOperationsActivity:
			errors.append("production roster contains a node that is not StationOperationsActivity")
			continue
		var activity := candidate as StationOperationsActivity
		var activity_audit := activity.get_audit_report()
		var profile_id := activity.get_activity_profile_id()
		if not bool(activity_audit.valid):
			errors.append(
				"production roster '%s' component fails its own audit: %s" % [
					profile_id,
					"; ".join(activity_audit.errors as PackedStringArray),
				]
			)
		if not profile_counts.has(profile_id):
			errors.append("production roster contains invalid profile '%s'" % profile_id)
			continue
		profile_counts[profile_id] = int(profile_counts[profile_id]) + 1
		var report := activity_audit.performance as Dictionary
		var activity_counts := report.counts as Dictionary
		counts.instance_count = int(counts.instance_count) + 1
		for key: String in activity_counts.keys():
			counts[key] = int(counts.get(key, 0)) + int(activity_counts[key])
	for profile_id: StringName in profile_counts.keys():
		if int(profile_counts[profile_id]) != 1:
			errors.append("recommended production roster requires exactly one '%s' profile" % profile_id)
	for key: String in RECOMMENDED_PRODUCTION_ROSTER_BUDGET.keys():
		if int(counts.get(key, 0)) > int(RECOMMENDED_PRODUCTION_ROSTER_BUDGET[key]):
			errors.append("production roster %s exceeds budget (%d > %d)" % [key, counts.get(key, 0), RECOMMENDED_PRODUCTION_ROSTER_BUDGET[key]])
	return {
		"schema_version": SCHEMA_VERSION,
		"valid": errors.is_empty(),
		"within_budget": errors.is_empty(),
		"errors": errors,
		"profile_counts": profile_counts.duplicate(true),
		"counts": counts.duplicate(true),
		"budgets": RECOMMENDED_PRODUCTION_ROSTER_BUDGET.duplicate(true),
	}


func get_performance_audit(instance_count: int = 1) -> Dictionary:
	var equipment := get_equipment_counts()
	var counts := {
		"node_count": 0,
		"mesh_instances": 0,
		"unique_materials": 0,
		"lights": 0,
		"particle_emitters": 0,
		"collision_nodes": 0,
		"animated_assemblies": int(equipment.animated_assembly_count),
	}
	var material_ids := {}
	_count_runtime_resources(self, counts, material_ids)
	# Retained but momentarily unassigned beacon variants still consume memory.
	# Count every component-owned material instead of reporting only the current
	# flash phase, keeping the audit stable across deterministic animation time.
	for material: Material in _materials.values():
		if material != null:
			material_ids[material.get_instance_id()] = true
	counts["unique_materials"] = material_ids.size()
	var performance_budget := _get_profile_performance_budget()
	var errors := PackedStringArray()
	for key: String in performance_budget.keys():
		if int(counts.get(key, 0)) > int(performance_budget[key]):
			errors.append("%s exceeds %s profile budget (%d > %d)" % [key, get_activity_profile_id(), counts.get(key, 0), performance_budget[key]])
	var audited_instance_count := clampi(instance_count, 1, RECOMMENDED_MAX_INSTANCES)
	var aggregate_counts := {}
	var aggregate_budgets := {}
	for key: String in counts.keys():
		aggregate_counts[key] = int(counts[key]) * audited_instance_count
		aggregate_budgets[key] = int(performance_budget.get(key, 0)) * audited_instance_count
	var aggregate_errors := PackedStringArray()
	for key: String in aggregate_budgets.keys():
		if int(aggregate_counts.get(key, 0)) > int(aggregate_budgets[key]):
			aggregate_errors.append("%s exceeds aggregate profile budget (%d > %d)" % [key, aggregate_counts.get(key, 0), aggregate_budgets[key]])
	return {
		"schema_version": SCHEMA_VERSION,
		"activity_profile": get_activity_profile(),
		"activity_profile_id": get_activity_profile_id(),
		"valid": errors.is_empty(),
		"within_budget": errors.is_empty(),
		"errors": errors,
		"counts": counts.duplicate(true),
		"budgets": performance_budget.duplicate(true),
		"audited_instance_count": audited_instance_count,
		"recommended_max_instances": RECOMMENDED_MAX_INSTANCES,
		"aggregate_counts": aggregate_counts.duplicate(true),
		"aggregate_budgets": aggregate_budgets.duplicate(true),
		"aggregate_within_budget": aggregate_errors.is_empty(),
		"aggregate_errors": aggregate_errors,
		"process_enabled": is_processing(),
		"headless_safe": true,
		"uses_external_assets": false,
		"uses_particles": false,
		"uses_dynamic_lights": false,
		"uses_collision": false,
		"determinism_fingerprint": get_determinism_fingerprint(),
	}


func get_validation_errors() -> PackedStringArray:
	var errors := PackedStringArray()
	if _mount_anchor == null or _service_zone_anchor == null or _presentation_root == null:
		errors.append("required integration anchors or presentation root are missing")
	if (
		get_node_or_null(^"MountAnchor") != _mount_anchor
		or get_node_or_null(^"ServiceZoneAnchor") != _service_zone_anchor
		or get_node_or_null(^"PresentationRoot") != _presentation_root
		or not is_instance_valid(_mount_anchor)
		or not is_instance_valid(_service_zone_anchor)
		or not is_instance_valid(_presentation_root)
		or not is_ancestor_of(_mount_anchor)
		or not is_ancestor_of(_service_zone_anchor)
		or not is_ancestor_of(_presentation_root)
	):
		errors.append("required live anchor and presentation identities changed")
	elif (
		not _mount_anchor.transform.is_equal_approx(Transform3D.IDENTITY)
		or not _presentation_root.transform.is_equal_approx(Transform3D.IDENTITY)
		or not _service_zone_anchor.basis.is_equal_approx(Basis.IDENTITY)
		or not _service_zone_anchor.position.is_equal_approx(_get_profile_service_zone_center())
	):
		errors.append("required anchor or presentation transforms diverged from the built contract")
	if not _cached_presentation_references_are_live():
		errors.append("cached activity equipment no longer belongs to the live presentation hierarchy")
	if not _is_valid_profile(_built_profile):
		errors.append("activity_profile must select FULL, GANTRY, SERVICE_ARM, or DRONE_PATROL")
	if _built:
		if activity_profile != _built_profile:
			errors.append("activity_profile cannot be changed after the component has built")
		if starts_enabled != _built_starts_enabled:
			errors.append("starts_enabled cannot be changed after the component has built")
		if starts_paused != _built_starts_paused:
			errors.append("starts_paused cannot be changed after the component has built")
		if playback_speed != _built_playback_speed:
			errors.append("playback_speed cannot be changed after the component has built")
		if variation_seed != _built_variation_seed:
			errors.append("variation_seed cannot be changed after the component has built")
	var expected := _get_expected_equipment_counts()
	var equipment := get_equipment_counts()
	for key: String in expected.keys():
		if int(equipment.get(key, -1)) != int(expected[key]):
			errors.append("%s profile requires %s=%d, found %d" % [get_activity_profile_id(), key, expected[key], equipment.get(key, -1)])
	if _beacon_lenses.size() != BEACON_COUNT:
		errors.append("safety beacon count does not match the stable contract")
	if _get_effective_variation_seed() < 0:
		errors.append("variation seed must not be negative")
	var effective_playback_speed := _get_effective_playback_speed()
	if not is_finite(effective_playback_speed) or effective_playback_speed <= 0.0:
		errors.append("playback speed must be finite and greater than zero")
	if is_processing() != is_activity_advancing():
		errors.append("process state must match the enabled and paused lifecycle state")
	if is_instance_valid(_presentation_root) and is_ancestor_of(_presentation_root) and _presentation_root.visible != _activity_enabled:
		errors.append("presentation visibility must match the enabled lifecycle state")
	var performance := get_performance_audit()
	if not bool(performance.within_budget):
		errors.append_array(performance.errors as PackedStringArray)
	if int((performance.counts as Dictionary).collision_nodes) != 0:
		errors.append("presentation component must never create collision nodes")
	var performance_counts := performance.counts as Dictionary
	var expected_counts := _get_profile_performance_budget()
	for key: String in expected_counts:
		if int(performance_counts.get(key, -1)) != int(expected_counts[key]):
			errors.append("live %s count diverged from the immutable %s profile build" % [key, get_activity_profile_id()])
	if not _all_live_meshes_fit_published_envelope():
		errors.append("live activity mesh geometry exceeds the published profile envelope")
	return errors


func get_audit_report() -> Dictionary:
	var errors := get_validation_errors()
	return {
		"schema_version": SCHEMA_VERSION,
		"component_id": COMPONENT_ID,
		"activity_profile": get_activity_profile(),
		"activity_profile_id": get_activity_profile_id(),
		"valid": errors.is_empty(),
		"errors": errors,
		"evidence_status": EVIDENCE_STATUS,
		"evidence": get_evidence_metadata(),
		"integration": get_integration_contract(),
		"performance": get_performance_audit(),
		"lifecycle": {
			"enabled": _activity_enabled,
			"paused": _activity_paused,
			"advancing": is_activity_advancing(),
			"process_enabled": is_processing(),
		},
		"equipment": get_equipment_counts(),
		"determinism_fingerprint": get_determinism_fingerprint(),
	}


func audit() -> Dictionary:
	return get_audit_report().duplicate(true)


func _is_valid_profile(profile: int) -> bool:
	return PROFILE_IDS.has(profile)


func _get_effective_playback_speed() -> float:
	return _built_playback_speed if _built else playback_speed


func _get_effective_variation_seed() -> int:
	return _built_variation_seed if _built else variation_seed


func _profile_has_gantry() -> bool:
	return _built_profile == ActivityProfile.FULL or _built_profile == ActivityProfile.GANTRY


func _profile_has_service_arm() -> bool:
	return _built_profile == ActivityProfile.FULL or _built_profile == ActivityProfile.SERVICE_ARM


func _profile_has_drones() -> bool:
	return _built_profile == ActivityProfile.FULL or _built_profile == ActivityProfile.DRONE_PATROL


func _get_expected_equipment_counts() -> Dictionary:
	return {
		"gantry_count": 1 if _profile_has_gantry() else 0,
		"service_arm_count": 1 if _profile_has_service_arm() else 0,
		"service_drone_count": DRONE_COUNT if _profile_has_drones() else 0,
		"safety_beacon_count": BEACON_COUNT,
		"animated_assembly_count": (
			(1 if _profile_has_gantry() else 0)
			+ (2 if _profile_has_service_arm() else 0)
			+ (DRONE_COUNT if _profile_has_drones() else 0)
		),
	}


func _get_profile_performance_budget() -> Dictionary:
	var budget: Variant = PROFILE_PERFORMANCE_BUDGETS.get(_built_profile)
	return (budget as Dictionary).duplicate(true) if budget is Dictionary else {}


func _cached_presentation_references_are_live() -> bool:
	if not is_instance_valid(_presentation_root) or not is_ancestor_of(_presentation_root):
		return false
	var required_nodes: Array[Node] = []
	if _profile_has_gantry():
		if not is_instance_valid(_gantry_carriage) or not is_instance_valid(_gantry_tool):
			return false
		required_nodes.append_array([_gantry_carriage, _gantry_tool])
	elif is_instance_valid(_gantry_carriage) or is_instance_valid(_gantry_tool):
		return false
	if _profile_has_service_arm():
		if (
			not is_instance_valid(_service_arm_shoulder)
			or not is_instance_valid(_service_arm_elbow)
			or not is_instance_valid(_service_arm_tool)
		):
			return false
		required_nodes.append_array([
			_service_arm_shoulder,
			_service_arm_elbow,
			_service_arm_tool,
		])
	elif (
		is_instance_valid(_service_arm_shoulder)
		or is_instance_valid(_service_arm_elbow)
		or is_instance_valid(_service_arm_tool)
	):
		return false
	if _drone_roots.size() != (DRONE_COUNT if _profile_has_drones() else 0):
		return false
	if _drone_beacon_lenses.size() != (DRONE_COUNT if _profile_has_drones() else 0):
		return false
	if _beacon_lenses.size() != BEACON_COUNT:
		return false
	for drone in _drone_roots:
		if not is_instance_valid(drone):
			return false
		required_nodes.append(drone)
	for lens in _drone_beacon_lenses:
		if not is_instance_valid(lens):
			return false
		required_nodes.append(lens)
	for lens in _beacon_lenses:
		if not is_instance_valid(lens):
			return false
		required_nodes.append(lens)
	for candidate in required_nodes:
		if not _presentation_root.is_ancestor_of(candidate):
			return false
	return true


func _capture_built_presentation_contract() -> void:
	_built_node_instance_ids.clear()
	_built_static_node_transforms.clear()
	_built_node_visibility.clear()
	_built_mesh_contracts.clear()
	_built_material_contracts.clear()
	var dynamic_node_ids := _dynamic_node_instance_ids()
	for candidate in find_children("*", "", true, false):
		var relative_path := str(get_path_to(candidate))
		_built_node_instance_ids[relative_path] = candidate.get_instance_id()
		if candidate is Node3D and not dynamic_node_ids.has(candidate.get_instance_id()):
			_built_static_node_transforms[relative_path] = (candidate as Node3D).transform
		if candidate is Node3D and candidate != _presentation_root:
			_built_node_visibility[relative_path] = (candidate as Node3D).visible
		if candidate is MeshInstance3D:
			var mesh_instance := candidate as MeshInstance3D
			_built_mesh_contracts[relative_path] = {
				"instance_id": mesh_instance.get_instance_id(),
				"transform": mesh_instance.transform,
				"mesh_instance_id": (
					mesh_instance.mesh.get_instance_id() if mesh_instance.mesh != null else 0
				),
				"mesh_class": mesh_instance.mesh.get_class() if mesh_instance.mesh != null else "",
				"mesh_aabb": mesh_instance.mesh.get_aabb() if mesh_instance.mesh != null else AABB(),
				"mesh_storage": _resource_storage_fingerprint(mesh_instance.mesh),
				"material_instance_id": (
					mesh_instance.material_override.get_instance_id()
					if mesh_instance.material_override != null else 0
				),
				"dynamic_material": (
					_beacon_lenses.has(mesh_instance)
					or _drone_beacon_lenses.has(mesh_instance)
				),
				"cast_shadow": mesh_instance.cast_shadow,
				"layers": mesh_instance.layers,
				"visibility_range_begin": mesh_instance.visibility_range_begin,
				"visibility_range_end": mesh_instance.visibility_range_end,
				"visibility_range_begin_margin": mesh_instance.visibility_range_begin_margin,
				"visibility_range_end_margin": mesh_instance.visibility_range_end_margin,
				"visibility_range_fade_mode": mesh_instance.visibility_range_fade_mode,
				"transparency": mesh_instance.transparency,
				"flip_faces": (
					(mesh_instance.mesh as PrimitiveMesh).flip_faces
					if mesh_instance.mesh is PrimitiveMesh else false
				),
			}
	for material_key in _materials:
		var material := _materials[material_key] as StandardMaterial3D
		if material != null:
			_built_material_contracts[material_key] = _standard_material_contract(material)


func _built_presentation_hierarchy_is_live() -> bool:
	if not _built or _built_node_instance_ids.is_empty():
		return false
	var live_nodes := find_children("*", "", true, false)
	if live_nodes.size() != _built_node_instance_ids.size():
		return false
	for relative_path_value in _built_node_instance_ids:
		var relative_path := NodePath(str(relative_path_value))
		var candidate := get_node_or_null(relative_path)
		if (
			not is_instance_valid(candidate)
			or candidate.get_instance_id() != int(_built_node_instance_ids[relative_path_value])
			or not is_ancestor_of(candidate)
		):
			return false
	for relative_path_value in _built_static_node_transforms:
		var candidate := get_node_or_null(NodePath(str(relative_path_value))) as Node3D
		if (
			not is_instance_valid(candidate)
			or not candidate.transform.is_equal_approx(
				_built_static_node_transforms[relative_path_value] as Transform3D
			)
		):
			return false
	for relative_path_value in _built_node_visibility:
		var candidate := get_node_or_null(NodePath(str(relative_path_value))) as Node3D
		if (
			not is_instance_valid(candidate)
			or candidate.visible != bool(_built_node_visibility[relative_path_value])
		):
			return false
	return true


func _owned_material_instance_ids() -> Dictionary:
	var result := {}
	for material_value in _materials.values():
		var material := material_value as Material
		if material != null:
			result[material.get_instance_id()] = true
	return result


func _built_mesh_contracts_are_live() -> bool:
	if _built_mesh_contracts.is_empty():
		return false
	var owned_material_ids := _owned_material_instance_ids()
	for relative_path_value in _built_mesh_contracts:
		var contract := _built_mesh_contracts[relative_path_value] as Dictionary
		var candidate := get_node_or_null(NodePath(str(relative_path_value)))
		if not candidate is MeshInstance3D:
			return false
		var mesh_instance := candidate as MeshInstance3D
		if (
			mesh_instance.get_instance_id() != int(contract.get("instance_id", 0))
			or not mesh_instance.visible
			or mesh_instance.mesh == null
			or mesh_instance.mesh.get_instance_id() != int(contract.get("mesh_instance_id", 0))
			or mesh_instance.mesh.get_class() != str(contract.get("mesh_class", ""))
			or not mesh_instance.mesh.get_aabb().is_equal_approx(contract.get("mesh_aabb", AABB()) as AABB)
			or _resource_storage_fingerprint(mesh_instance.mesh)
				!= (contract.get("mesh_storage", PackedStringArray()) as PackedStringArray)
			or not mesh_instance.transform.is_equal_approx(contract.get("transform", Transform3D.IDENTITY) as Transform3D)
			or mesh_instance.cast_shadow != int(contract.get("cast_shadow", -1))
			or mesh_instance.layers != int(contract.get("layers", 0))
			or not is_equal_approx(mesh_instance.visibility_range_begin, float(contract.get("visibility_range_begin", 0.0)))
			or not is_equal_approx(mesh_instance.visibility_range_end, float(contract.get("visibility_range_end", 0.0)))
			or not is_equal_approx(mesh_instance.visibility_range_begin_margin, float(contract.get("visibility_range_begin_margin", 0.0)))
			or not is_equal_approx(mesh_instance.visibility_range_end_margin, float(contract.get("visibility_range_end_margin", 0.0)))
			or mesh_instance.visibility_range_fade_mode != int(contract.get("visibility_range_fade_mode", -1))
			or not is_equal_approx(mesh_instance.transparency, float(contract.get("transparency", 0.0)))
			or (
				mesh_instance.mesh is PrimitiveMesh
				and (mesh_instance.mesh as PrimitiveMesh).flip_faces
					!= bool(contract.get("flip_faces", false))
			)
			or mesh_instance.material_override == null
			or not owned_material_ids.has(mesh_instance.material_override.get_instance_id())
		):
			return false
		if (
			not bool(contract.get("dynamic_material", false))
			and mesh_instance.material_override.get_instance_id()
				!= int(contract.get("material_instance_id", 0))
		):
			return false
	return _materials_match_build_contract() and _activity_pose_matches_clock()


func _dynamic_node_instance_ids() -> Dictionary:
	var result := {}
	for candidate in [
		_gantry_carriage,
		_gantry_tool,
		_service_arm_shoulder,
		_service_arm_elbow,
		_service_arm_tool,
	]:
		if is_instance_valid(candidate):
			result[candidate.get_instance_id()] = true
	for drone in _drone_roots:
		if is_instance_valid(drone):
			result[drone.get_instance_id()] = true
	return result


func _standard_material_contract(material: StandardMaterial3D) -> Dictionary:
	return {
		"instance_id": material.get_instance_id(),
		"albedo_color": material.albedo_color,
		"metallic": material.metallic,
		"roughness": material.roughness,
		"transparency": material.transparency,
		"emission_enabled": material.emission_enabled,
		"emission": material.emission,
		"emission_energy": material.emission_energy_multiplier,
		"cull_mode": material.cull_mode,
		"shading_mode": material.shading_mode,
		"vertex_color_use_as_albedo": material.vertex_color_use_as_albedo,
		"vertex_color_is_srgb": material.vertex_color_is_srgb,
		"distance_fade_mode": material.distance_fade_mode,
		"storage": _resource_storage_fingerprint(material),
	}


func _materials_match_build_contract() -> bool:
	if _built_material_contracts.size() != _materials.size():
		return false
	for material_key in _built_material_contracts:
		var material := _materials.get(material_key) as StandardMaterial3D
		var contract := _built_material_contracts[material_key] as Dictionary
		if (
			material == null
			or material.get_instance_id() != int(contract.get("instance_id", 0))
			or not material.albedo_color.is_equal_approx(contract.get("albedo_color", Color.TRANSPARENT) as Color)
			or not is_equal_approx(material.metallic, float(contract.get("metallic", 0.0)))
			or not is_equal_approx(material.roughness, float(contract.get("roughness", 0.0)))
			or material.transparency != int(contract.get("transparency", -1))
			or material.cull_mode != int(contract.get("cull_mode", -1))
			or material.shading_mode != int(contract.get("shading_mode", -1))
			or material.vertex_color_use_as_albedo != bool(contract.get("vertex_color_use_as_albedo", false))
			or material.vertex_color_is_srgb != bool(contract.get("vertex_color_is_srgb", false))
			or material.distance_fade_mode != int(contract.get("distance_fade_mode", -1))
			or material.emission_enabled != bool(contract.get("emission_enabled", false))
			or not material.emission.is_equal_approx(contract.get("emission", Color.TRANSPARENT) as Color)
			or not is_equal_approx(
				material.emission_energy_multiplier,
				float(contract.get("emission_energy", 0.0))
			)
			or _resource_storage_fingerprint(material)
				!= (contract.get("storage", PackedStringArray()) as PackedStringArray)
		):
			return false
	return true


## Content fingerprint of every stored property on an owned resource.
##
## Values are recorded as a recursive content hash rather than as `var_to_str`
## text. The hash covers the same stored bytes, so the fingerprint keeps the same
## sensitivity; what it gives up is human-readable diagnostics, and nothing prints
## this fingerprint. The reason is cost: once this component's boxes became
## chamfered `ArrayMesh` resources, the text form had to serialise a full
## vertex/normal/tangent/UV/index buffer per mesh on every audit call. Measured on
## the FULL profile's 79 meshes that was 48-88 ms per pass, and it took
## `station_operations_activity_test` from 0.5 s to over 175 s, past its 180 s
## matrix timeout. With the hash the same suite runs in 0.6 s.
##
## `station_operations_activity_test` still drives this red by mutating a live
## generated mesh in place; see the drift witness there.
func _resource_storage_fingerprint(resource: Resource) -> PackedStringArray:
	var result := PackedStringArray()
	if resource == null:
		return result
	for property_value in resource.get_property_list():
		var property := property_value as Dictionary
		if int(property.get("usage", 0)) & PROPERTY_USAGE_STORAGE == 0:
			continue
		var property_name := StringName(property.get("name", &""))
		result.append("%s=%d" % [property_name, hash(resource.get(property_name))])
	result.sort()
	return result


func _node_matches_expected_pose(
	node: Node3D,
	expected_position: Vector3,
	expected_rotation: Vector3
) -> bool:
	return (
		is_instance_valid(node)
		and node.position.is_equal_approx(expected_position)
		and node.scale.is_equal_approx(Vector3.ONE)
		and node.basis.is_equal_approx(Basis.from_euler(expected_rotation, node.rotation_order))
	)


func _activity_pose_matches_clock() -> bool:
	var seed_phase := fmod(float(_get_effective_variation_seed()), 997.0) / 997.0 * TAU
	if _profile_has_gantry():
		var carriage_phase := _elapsed * 0.37 + seed_phase * 0.17
		if not _node_matches_expected_pose(
			_gantry_carriage,
			Vector3(sin(carriage_phase) * GANTRY_TRAVEL, GANTRY_ELEVATION, 0.0),
			Vector3.ZERO
		):
			return false
		if not _node_matches_expected_pose(
			_gantry_tool,
			Vector3(0.0, -0.12 - (0.18 + 0.16 * sin(_elapsed * 0.53 + seed_phase)), 0.0),
			Vector3(0.0, sin(_elapsed * 0.29 + seed_phase) * 0.12, 0.0)
		):
			return false
	if _profile_has_service_arm():
		if not _node_matches_expected_pose(
			_service_arm_shoulder,
			Vector3(0.0, 0.72, 0.0),
			Vector3(0.0, sin(_elapsed * 0.21 + seed_phase) * 0.18, -0.54 + sin(_elapsed * 0.31 + seed_phase) * 0.22)
		):
			return false
		if not _node_matches_expected_pose(
			_service_arm_elbow,
			Vector3(-0.05, 2.23, 0.0),
			Vector3(0.0, 0.0, 0.82 + sin(_elapsed * 0.43 + seed_phase + 0.7) * 0.28)
		):
			return false
		if not _node_matches_expected_pose(
			_service_arm_tool,
			Vector3(0.0, 1.65, 0.0),
			Vector3(0.0, _elapsed * 0.28 + seed_phase, sin(_elapsed * 0.51) * 0.09)
		):
			return false
	if _profile_has_drones():
		for index in _drone_roots.size():
			var phase := _elapsed * (0.24 + index * 0.035) + seed_phase + float(index) * PI
			if not _node_matches_expected_pose(
				_drone_roots[index],
				Vector3(cos(phase) * (3.55 - index * 0.28), 1.48 + float(index) * 0.44 + sin(phase * 2.0) * 0.18, sin(phase) * (2.85 - index * 0.22)),
				Vector3(0.04 * sin(phase * 1.7), -phase + PI * 0.5, 0.08 * cos(phase))
			):
				return false
	var beacon_pattern := _get_beacon_pattern()
	for index in _beacon_lenses.size():
		var expected_beacon_material: Material = _materials["amber_lit"] if beacon_pattern[index] else _materials["amber_dim"]
		if _beacon_lenses[index].material_override != expected_beacon_material:
			return false
	for index in _drone_beacon_lenses.size():
		var drone_pulse := fmod(_elapsed + float(index) * 0.42 + seed_phase, 1.35) < 0.24
		var expected_drone_material: Material = _materials["red_lit"] if drone_pulse else _materials["cyan_dim"]
		if _drone_beacon_lenses[index].material_override != expected_drone_material:
			return false
	return true


func _all_live_meshes_fit_published_envelope() -> bool:
	if (
		not is_instance_valid(_presentation_root)
		or not is_ancestor_of(_presentation_root)
		or not _built_presentation_hierarchy_is_live()
		or not _built_mesh_contracts_are_live()
	):
		return false
	var local_min := _get_profile_local_min() - Vector3.ONE * 0.03
	var local_max := _get_profile_local_max() + Vector3.ONE * 0.03
	var mesh_count := 0
	for candidate in find_children("*", "MeshInstance3D", true, false):
		var mesh_instance := candidate as MeshInstance3D
		if mesh_instance.mesh == null:
			return false
		var relative_transform_value: Variant = _node_transform_relative_to_component(mesh_instance)
		if not relative_transform_value is Transform3D:
			return false
		var relative_transform := relative_transform_value as Transform3D
		var bounds := mesh_instance.get_aabb()
		for corner_index in 8:
			var corner := bounds.position + Vector3(
				bounds.size.x if corner_index & 1 else 0.0,
				bounds.size.y if corner_index & 2 else 0.0,
				bounds.size.z if corner_index & 4 else 0.0
			)
			var point: Vector3 = relative_transform * corner
			if (
				point.x < local_min.x or point.x > local_max.x
				or point.y < local_min.y or point.y > local_max.y
				or point.z < local_min.z or point.z > local_max.z
			):
				return false
		mesh_count += 1
	return mesh_count == int(_get_profile_performance_budget().get("mesh_instances", -1))


func _node_transform_relative_to_component(node: Node3D) -> Variant:
	if not is_ancestor_of(node):
		return null
	var relative_transform := Transform3D.IDENTITY
	var current: Node = node
	while current != self:
		if not current is Node3D:
			return null
		relative_transform = (current as Node3D).transform * relative_transform
		current = current.get_parent()
		if current == null:
			return null
	return relative_transform


func _get_profile_local_min() -> Vector3:
	match _built_profile:
		ActivityProfile.GANTRY:
			return Vector3(-5.4, 0.0, -3.6)
		ActivityProfile.SERVICE_ARM:
			return Vector3(-2.4, 0.0, -1.75)
		ActivityProfile.DRONE_PATROL:
			return Vector3(-4.55, 0.0, -3.55)
		_:
			return FOOTPRINT_MIN


func _get_profile_local_max() -> Vector3:
	match _built_profile:
		ActivityProfile.GANTRY:
			return Vector3(5.4, 7.25, 3.6)
		ActivityProfile.SERVICE_ARM:
			return Vector3(2.4, 5.45, 1.75)
		ActivityProfile.DRONE_PATROL:
			return Vector3(4.55, 2.4, 3.55)
		_:
			return FOOTPRINT_MAX


func _get_profile_service_zone_center() -> Vector3:
	match _built_profile:
		ActivityProfile.SERVICE_ARM:
			return Vector3(0.15, 2.3, 0.0)
		ActivityProfile.DRONE_PATROL:
			return Vector3(0.0, 1.35, 0.0)
		_:
			return SERVICE_ZONE_CENTER


func _get_profile_service_zone_half_extents() -> Vector3:
	match _built_profile:
		ActivityProfile.GANTRY:
			return Vector3(5.9, 3.8, 4.1)
		ActivityProfile.SERVICE_ARM:
			return Vector3(2.6, 2.6, 1.9)
		ActivityProfile.DRONE_PATROL:
			return Vector3(5.0, 1.6, 4.2)
		_:
			return SERVICE_ZONE_HALF_EXTENTS


func _get_profile_mount_type() -> StringName:
	match _built_profile:
		ActivityProfile.SERVICE_ARM:
			return &"deck_edge"
		ActivityProfile.DRONE_PATROL:
			return &"deck_or_inverted_ceiling_anchor"
		_:
			return &"level_deck"


func _get_profile_mount_description() -> String:
	match _built_profile:
		ActivityProfile.SERVICE_ARM:
			return "Origin is the service-arm rotary base at a level deck edge; local -Z faces the service lane."
		ActivityProfile.DRONE_PATROL:
			return "Origin is the patrol-zone mount plane; use upright on deck or rotate 180 degrees around local X for an inverted ceiling anchor."
		_:
			return "Origin is the centre of the level deck footprint; local -Z faces the serviced berth or traffic lane."


func _get_drone_motion_envelope() -> Dictionary:
	if not _profile_has_drones():
		return {
			"present": false,
			"local_center": Vector3.ZERO,
			"half_extents": Vector3.ZERO,
		}
	return {
		"present": true,
		"local_center": Vector3(0.0, 1.7, 0.0),
		"half_extents": Vector3(4.45, 0.72, 3.35),
		"route_type": &"deterministic_elliptical_patrol",
		"collision_policy": &"presentation_only_nonblocking",
	}


func _refresh_lifecycle() -> void:
	if _presentation_root != null:
		_presentation_root.visible = _activity_enabled
	set_process(_activity_enabled and not _activity_paused)


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
	for key in ["frame", "frame_edge", "graphite", "ceramic"]:
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
			_box(gantry, "SafetyBand", Vector3(x, 0.72, z - z_side * 0.27), Vector3(0.5, 0.28, 0.06), _materials["orange"])
	for z_side in [-1.0, 1.0]:
		_box(gantry, "OverheadRail", Vector3(0.0, 5.82, z_side * 2.72), Vector3(9.08, 0.42, 0.48), _materials["frame"])
		_box(gantry, "RailFace", Vector3(0.0, 5.83, z_side * 2.46), Vector3(8.55, 0.17, 0.055), _materials["frame_edge"])
		for x in [-3.15, -1.05, 1.05, 3.15]:
			_box(gantry, "RailFastener", Vector3(x, 5.83, z_side * 2.42), Vector3(0.13, 0.13, 0.07), _materials["orange"])
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
	base.position = Vector3(3.72, 0.0, -2.05) if _built_profile == ActivityProfile.FULL else Vector3.ZERO
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


func _build_service_drones() -> void:
	for index in DRONE_COUNT:
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


func _build_safety_beacons() -> void:
	var positions := _get_beacon_positions()
	for index in positions.size():
		var beacon := Node3D.new()
		beacon.name = "SafetyBeacon%02d" % (index + 1)
		beacon.position = positions[index]
		_presentation_root.add_child(beacon)
		_cylinder(beacon, "Base", Vector3.ZERO, 0.24, 0.18, _materials["graphite"])
		var lens := _cylinder(beacon, "Lens", Vector3(0.0, 0.2, 0.0), 0.15, 0.24, _materials["amber_dim"])
		_beacon_lenses.append(lens)
		if _built_profile == ActivityProfile.DRONE_PATROL:
			# MAP-005. The anchor foot used to be a plinth 0.13 m *below* the base
			# pedestal, which left the pedestal hanging 0.07 m over its own foot. It
			# is now a bolt-down flange around the foot of the pedestal, sharing the
			# pedestal's underside, so the whole assembly seats on one plane.
			_box(beacon, "AnchorFoot", Vector3(0.0, -0.06, 0.0), Vector3(0.62, 0.06, 0.62), _materials["frame_edge"])


func _get_beacon_positions() -> Array[Vector3]:
	# MAP-005. `BEACON_SEAT_HEIGHT` is half the `Base` pedestal's 0.18 m height, so
	# the pedestal's underside lands on the activity's own mounting plane (local
	# y = 0) — the same plane every `FootPad` in this component already sits on.
	# The previous 0.27 m left all sixteen beacons in the roster hovering: 0.19 m
	# over the Aft, Habitat and Freight roofs and 0.21 m over the Central berth
	# deck. Only the mount transform's own offset from the deck below it remains.
	var x_extent := 4.72
	var z_extent := 3.15
	match _built_profile:
		ActivityProfile.SERVICE_ARM:
			x_extent = 1.9
			z_extent = 1.25
		ActivityProfile.DRONE_PATROL:
			x_extent = 4.1
			z_extent = 3.25
		ActivityProfile.GANTRY:
			x_extent = 4.72
			z_extent = 3.05
	return [
		Vector3(-x_extent, BEACON_SEAT_HEIGHT, -z_extent),
		Vector3(x_extent, BEACON_SEAT_HEIGHT, -z_extent),
		Vector3(-x_extent, BEACON_SEAT_HEIGHT, z_extent),
		Vector3(x_extent, BEACON_SEAT_HEIGHT, z_extent),
	]


func _update_activity_transforms() -> void:
	if not _built:
		return
	var seed_phase := fmod(float(_get_effective_variation_seed()), 997.0) / 997.0 * TAU
	if _gantry_carriage != null and _gantry_tool != null:
		var carriage_phase := _elapsed * 0.37 + seed_phase * 0.17
		_gantry_carriage.position = Vector3(sin(carriage_phase) * GANTRY_TRAVEL, GANTRY_ELEVATION, 0.0)
		_gantry_tool.position.y = -0.12 - (0.18 + 0.16 * sin(_elapsed * 0.53 + seed_phase))
		_gantry_tool.rotation.y = sin(_elapsed * 0.29 + seed_phase) * 0.12

	if _service_arm_shoulder != null and _service_arm_elbow != null and _service_arm_tool != null:
		_service_arm_shoulder.rotation = Vector3(0.0, sin(_elapsed * 0.21 + seed_phase) * 0.18, -0.54 + sin(_elapsed * 0.31 + seed_phase) * 0.22)
		_service_arm_elbow.rotation = Vector3(0.0, 0.0, 0.82 + sin(_elapsed * 0.43 + seed_phase + 0.7) * 0.28)
		_service_arm_tool.rotation = Vector3(0.0, _elapsed * 0.28 + seed_phase, sin(_elapsed * 0.51) * 0.09)

	for index in _drone_roots.size():
		var drone := _drone_roots[index]
		var phase := _elapsed * (0.24 + index * 0.035) + seed_phase + float(index) * PI
		var radius_x := 3.55 - index * 0.28
		var radius_z := 2.85 - index * 0.22
		drone.position = Vector3(
			cos(phase) * radius_x,
			1.48 + float(index) * 0.44 + sin(phase * 2.0) * 0.18,
			sin(phase) * radius_z
		)
		drone.rotation = Vector3(0.04 * sin(phase * 1.7), -phase + PI * 0.5, 0.08 * cos(phase))

	var pattern := _get_beacon_pattern()
	for index in _beacon_lenses.size():
		_beacon_lenses[index].material_override = _materials["amber_lit"] if pattern[index] else _materials["amber_dim"]
	for index in _drone_beacon_lenses.size():
		var drone_pulse := fmod(_elapsed + float(index) * 0.42 + seed_phase, 1.35) < 0.24
		_drone_beacon_lenses[index].material_override = _materials["red_lit"] if drone_pulse else _materials["cyan_dim"]


func _get_beacon_pattern() -> Array[bool]:
	var result: Array[bool] = []
	var seed_phase_seconds := fmod(float(_get_effective_variation_seed()), 31.0) * 0.013
	for index in BEACON_COUNT:
		var pulse_time := fmod(_elapsed + seed_phase_seconds + float(index % 2) * 0.55, 1.1)
		result.append(pulse_time < 0.22)
	return result


func _apply_evidence_metadata() -> void:
	set_meta("component_id", COMPONENT_ID)
	set_meta("evidence_status", EVIDENCE_STATUS)
	set_meta("presentation_only", true)
	set_meta("nonblocking_collision", true)
	set_meta("content_note", CONTENT_NOTE)
	_presentation_root.set_meta("evidence_status", EVIDENCE_STATUS)
	_presentation_root.set_meta("modern_interpretation", true)
	add_to_group(&"station_operations_activity")


func _count_runtime_resources(node: Node, counts: Dictionary, material_ids: Dictionary) -> void:
	counts["node_count"] = int(counts.node_count) + 1
	if node is MeshInstance3D:
		counts["mesh_instances"] = int(counts.mesh_instances) + 1
		var material := (node as MeshInstance3D).material_override
		if material != null:
			material_ids[material.get_instance_id()] = true
	if node is Light3D:
		counts["lights"] = int(counts.lights) + 1
	if node is GPUParticles3D or node is CPUParticles3D:
		counts["particle_emitters"] = int(counts.particle_emitters) + 1
	if node is CollisionObject3D or node is CollisionShape3D or node is CollisionPolygon3D:
		counts["collision_nodes"] = int(counts.collision_nodes) + 1
	for child in node.get_children():
		_count_runtime_resources(child, counts, material_ids)


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
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius * 0.88
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = 12
	mesh.rings = 1
	mesh_instance.mesh = mesh
	mesh_instance.material_override = material
	mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	parent.add_child(mesh_instance, true)
	return mesh_instance
