class_name StationServiceAgent
extends Node3D

## Reusable, presentation-only station service courier.
##
## Where `StationOperationsActivity` is a fixed rail bolted to one mount, this
## component travels a **route resolved from the declared station graph**. The
## world hands it an ordered list of local waypoints that came out of
## `StationNavigationGraph.find_route()`, which in turn came out of the
## `StationRouteRegistry` report. The agent therefore consumes the one station
## topology the project already declares instead of authoring a second one.
##
## The agent owns no gameplay authority whatsoever. It cannot reserve a berth,
## hold a lease, land or launch a craft, regenerate anything, resolve damage, be
## interacted with, or block the player: the whole subtree is mesh, marker, and
## `Node3D` only, and the audit turns red if a collider, area, light, particle
## emitter, or audio voice ever appears inside it.
##
## Motion is a pure function of the component clock, so 30/60/120 Hz stepping and
## an absolute seek all produce the same pose. The service envelope is finite,
## published, and re-checked across a complete traversal cycle; the agent can
## never leave it.
##
## Every route, cadence, dimension, colour, and silhouette here is
## `modern_interpretation` and authenticates no original station logistics.

const SCHEMA_VERSION := 1
const COMPONENT_ID: StringName = &"station-service-agent"
const EVIDENCE_STATUS: StringName = &"modern_interpretation"
const DEFAULT_VARIATION_SEED := 6607

## Bounded route contract. A courier route is one or a few declared connector
## hops, never a free flight across the station interior.
const MINIMUM_WAYPOINTS := 2
const MAXIMUM_WAYPOINTS := 8
const MINIMUM_SEGMENT_LENGTH := 0.25
const MINIMUM_ROUTE_LENGTH := 1.0
const MAXIMUM_ROUTE_LENGTH := 48.0

## Bounded flight contract. The floor on hover lift keeps the courier clear above
## the production player capsule (`1.94 m`) so a presentation body never appears
## to occupy walking space it does not physically own.
const MINIMUM_TRAVERSAL_SPEED := 0.25
const MAXIMUM_TRAVERSAL_SPEED := 4.0
const MINIMUM_HOVER_LIFT := 2.6
# The freight branch crosses a real maintenance gantry. At 9.10 m its lowest
# swept body point preserves player headroom above that structure, so the
# bounded service band must admit that one overhead route.
const MAXIMUM_HOVER_LIFT := 9.1
const MAXIMUM_LATERAL_SWAY := 0.5
const MAXIMUM_VERTICAL_SWAY := 0.45

## Circumscribed half extents of the courier body under any yaw, plus the
## vertical half extent. The published envelope always contains this box.
const BODY_HALF_EXTENTS := Vector3(1.15, 0.55, 1.15)

## Poses sampled across one complete out-and-back cycle when validating that the
## agent can never leave its published envelope.
const ENVELOPE_SAMPLE_COUNT := 64

## Radians of the traversal cycle, either side of an endpoint, over which the
## courier turns around. The turn happens while the cosine-eased travel has
## slowed the courier almost to a stop.
const TURN_BAND := 0.35

const PERFORMANCE_BUDGET := {
	"node_count": 11,
	"mesh_instances": 7,
	"unique_materials": 6,
	"lights": 0,
	"particle_emitters": 0,
	"collision_nodes": 0,
	"audio_nodes": 0,
	"area_nodes": 0,
	"animated_assemblies": 1,
}

const RECOMMENDED_MAX_INSTANCES := 6

## Every courier uses the same immutable six-recipe surface catalog. The
## dictionary itself is copied per instance; only Material values are shared.
## Route clocks, poses, and the status-lens override remain instance-owned.
static var _shared_material_catalog: Dictionary = {}

const CONTENT_NOTE := (
	"The remake brief supports ambient station activity, cargo movement, and "
	+ "animated equipment. It does not authenticate this courier silhouette, its "
	+ "route, cadence, hover height, colours, cargo pod, or the idea that autonomous "
	+ "service craft existed in any original or fixed-era build. Every visible and "
	+ "behavioural detail here is an original modern interpretation."
)

@export_category("Agent")
@export var agent_id: StringName = &""
@export var starts_enabled := true
@export var starts_paused := false
@export_range(0.1, 3.0, 0.05) var playback_speed := 1.0
@export_range(0, 999999, 1) var variation_seed := DEFAULT_VARIATION_SEED

@export_category("Service envelope")
@export_range(MINIMUM_TRAVERSAL_SPEED, MAXIMUM_TRAVERSAL_SPEED, 0.05) var traversal_speed := 1.25
@export_range(MINIMUM_HOVER_LIFT, MAXIMUM_HOVER_LIFT, 0.05) var hover_lift := 2.85
@export_range(0.0, MAXIMUM_LATERAL_SWAY, 0.01) var lateral_sway := 0.22
@export_range(0.0, MAXIMUM_VERTICAL_SWAY, 0.01) var vertical_sway := 0.16

@onready var _route_anchor: Marker3D = get_node(^"RouteAnchor") as Marker3D
@onready var _service_envelope_anchor: Marker3D = get_node(^"ServiceEnvelopeAnchor") as Marker3D
@onready var _presentation_root: Node3D = get_node(^"PresentationRoot") as Node3D

var _materials: Dictionary = {}
## Size-keyed chamfered box meshes, shared between equal-sized courier parts.
var _rounded_box_cache: Dictionary = {}
var _carriage: Node3D
var _status_lens: MeshInstance3D
var _route_id: StringName = &""
var _route_node_ids := PackedStringArray()
var _route_points := PackedVector3Array()
var _segment_lengths := PackedFloat64Array()
var _route_length := 0.0
var _route_configured := false
var _elapsed := 0.0
var _agent_enabled := true
var _agent_paused := false
var _enabled_overridden := false
var _paused_overridden := false
var _built := false
var _built_agent_id: StringName = &""
var _built_starts_enabled := true
var _built_starts_paused := false
var _built_playback_speed := 1.0
var _built_variation_seed := DEFAULT_VARIATION_SEED
var _built_traversal_speed := 1.25
var _built_hover_lift := 2.85
var _built_lateral_sway := 0.22
var _built_vertical_sway := 0.16
var _built_route_fingerprint := ""
var _built_node_instance_ids: Dictionary = {}
var _built_material_contracts: Dictionary = {}
var _envelope_min := Vector3.ZERO
var _envelope_max := Vector3.ZERO


func _enter_tree() -> void:
	# `_ready()` only runs on the first tree entry. Restore the component's desired
	# process state when an owning world removes and re-adds this child.
	if _built:
		_refresh_lifecycle()


func _ready() -> void:
	add_to_group(&"station_service_agent", false)
	if _built:
		return
	_built = true
	_built_agent_id = agent_id
	_built_starts_enabled = starts_enabled
	_built_starts_paused = starts_paused
	_built_playback_speed = playback_speed
	_built_variation_seed = variation_seed
	_built_traversal_speed = traversal_speed
	_built_hover_lift = hover_lift
	_built_lateral_sway = lateral_sway
	_built_vertical_sway = vertical_sway
	_built_route_fingerprint = _route_fingerprint()
	_create_materials()
	_build_courier()
	_capture_built_material_contracts()
	_recompute_service_envelope()
	_route_anchor.transform = Transform3D.IDENTITY
	_service_envelope_anchor.transform = Transform3D(Basis.IDENTITY, get_service_envelope_center())
	_apply_evidence_metadata()
	if not _enabled_overridden:
		_agent_enabled = starts_enabled
	if not _paused_overridden:
		_agent_paused = starts_paused
	_update_agent_transforms()
	_refresh_lifecycle()
	_capture_built_hierarchy()


func _process(delta: float) -> void:
	advance_agent_simulation(delta * _get_effective_playback_speed())


func _exit_tree() -> void:
	set_process(false)


func get_component_id() -> StringName:
	return COMPONENT_ID


func get_agent_id() -> StringName:
	return _built_agent_id if _built else agent_id


## Installs the route the world resolved from `StationNavigationGraph`.
##
## Waypoints are component-local. The route is immutable once the component has
## built, so a caller can never re-aim a live courier out of its audited envelope.
func configure_service_route(
		route_id: StringName,
		node_ids: PackedStringArray,
		local_waypoints: PackedVector3Array
	) -> bool:
	if _built:
		return false
	if route_id.is_empty():
		return false
	if local_waypoints.size() < MINIMUM_WAYPOINTS or local_waypoints.size() > MAXIMUM_WAYPOINTS:
		return false
	if node_ids.size() != local_waypoints.size():
		return false
	for node_id in node_ids:
		if node_id.is_empty():
			return false
	for point in local_waypoints:
		if not _is_finite_vector(point):
			return false
	# The mount is the route origin by contract: the world places the component at
	# the first waypoint. Accepting an offset start would let the published
	# envelope and the visible mount disagree.
	if not local_waypoints[0].is_equal_approx(Vector3.ZERO):
		return false
	var segment_lengths := PackedFloat64Array()
	var total := 0.0
	for index in range(local_waypoints.size() - 1):
		var segment := local_waypoints[index].distance_to(local_waypoints[index + 1])
		if segment < MINIMUM_SEGMENT_LENGTH:
			return false
		segment_lengths.append(segment)
		total += segment
	if total < MINIMUM_ROUTE_LENGTH or total > MAXIMUM_ROUTE_LENGTH:
		return false
	_route_id = route_id
	_route_node_ids = node_ids.duplicate()
	_route_points = local_waypoints.duplicate()
	_segment_lengths = segment_lengths
	_route_length = total
	_route_configured = true
	return true


func has_service_route() -> bool:
	return _route_configured


func get_route_id() -> StringName:
	return _route_id


func get_route_node_ids() -> PackedStringArray:
	return _route_node_ids.duplicate()


func get_route_points() -> PackedVector3Array:
	return _route_points.duplicate()


func get_route_length() -> float:
	return _route_length


## Exact world-space waypoints the courier serves, for integration audits that
## compare the installed route against the live navigation graph.
func get_world_route_points() -> PackedVector3Array:
	var points := PackedVector3Array()
	var basis_transform := global_transform
	for point in _route_points:
		points.append(basis_transform * point)
	return points


func get_service_envelope_center() -> Vector3:
	return (_envelope_min + _envelope_max) * 0.5


func get_service_envelope_half_extents() -> Vector3:
	return (_envelope_max - _envelope_min) * 0.5


func get_service_envelope() -> Dictionary:
	return {
		"local_min": _envelope_min,
		"local_max": _envelope_max,
		"local_size": _envelope_max - _envelope_min,
		"local_center": get_service_envelope_center(),
		"half_extents": get_service_envelope_half_extents(),
		"world_transform": global_transform * Transform3D(Basis.IDENTITY, get_service_envelope_center()),
		"body_half_extents": BODY_HALF_EXTENTS,
		"collision_policy": &"presentation_only_nonblocking",
	}


## The origin is the first route waypoint. Local +Y is up and the courier hovers
## `hover_lift` above the declared route line. No space in the envelope is
## physically blocked because every generated child is presentation-only.
func get_integration_contract() -> Dictionary:
	var envelope := get_service_envelope()
	return {
		"schema_version": SCHEMA_VERSION,
		"component_id": COMPONENT_ID,
		"agent_id": get_agent_id(),
		"route_id": _route_id,
		"route_node_ids": _route_node_ids.duplicate(),
		"route_waypoint_count": _route_points.size(),
		"route_length": _route_length,
		"route_source": &"station_navigation_graph",
		"mount_transform": global_transform,
		"local_min": _envelope_min,
		"local_max": _envelope_max,
		"service_envelope": envelope,
		"traversal_speed": _get_effective_traversal_speed(),
		"hover_lift": _get_effective_hover_lift(),
		"lateral_sway": _get_effective_lateral_sway(),
		"vertical_sway": _get_effective_vertical_sway(),
		"up_axis_local": Vector3.UP,
		"collision_policy": &"presentation_only_nonblocking",
		"recommended_max_instances": RECOMMENDED_MAX_INSTANCES,
		"minimum_ground_clearance": _get_effective_hover_lift() - _get_effective_vertical_sway() - BODY_HALF_EXTENTS.y,
	}


## Explicit, deliberately negative authority declaration. A service courier is
## presentation: it observes the station graph and never owns station state.
func get_authority_contract() -> Dictionary:
	var counts := _count_subtree()
	return {
		"schema_version": SCHEMA_VERSION,
		"authority_ids": PackedStringArray(),
		"owns_berth_authority": false,
		"owns_lease_authority": false,
		"owns_landing_authority": false,
		"owns_spawn_or_regeneration_authority": false,
		"owns_combat_or_damage_authority": false,
		"owns_interaction_authority": false,
		"owns_door_authority": false,
		"owns_navigation_authority": false,
		"ship_berth_count": int(counts.ship_berth_count),
		"area_nodes": int(counts.area_nodes),
		"collision_nodes": int(counts.collision_nodes),
		"audio_nodes": int(counts.audio_nodes),
		"network_authority_role": &"none",
	}


func get_evidence_metadata() -> Dictionary:
	return {
		"schema_version": SCHEMA_VERSION,
		"component_id": COMPONENT_ID,
		"agent_id": get_agent_id(),
		"evidence_status": EVIDENCE_STATUS,
		"source_bounded": true,
		"authenticated_original_geometry": false,
		"authenticated_original_placement": false,
		"authenticated_original_routes": false,
		"authenticated_original_logistics": false,
		"references": PackedStringArray([
			"Goal brief: Shipyard / machinery, docking equipment, cargo, animated equipment, and ambient station activity",
			"Goal brief: Creative Freedom / additions must feel like a natural evolution of Keth Shipyards",
		]),
		"modern_interpretations": PackedStringArray([
			"autonomous courier silhouette, cargo pod, status lens, and materials",
			"hover height, traversal cadence, sway, and out-and-back service pattern",
			"the decision that connector slots carry visible service traffic at all",
		]),
		"explicit_unknowns": PackedStringArray([
			"whether any original or fixed-era build moved cargo between station modules",
			"historical station logistics workflows, schedules, and traffic rules",
		]),
		"content_note": CONTENT_NOTE,
	}


func set_agent_enabled(enabled: bool) -> void:
	_enabled_overridden = true
	_agent_enabled = enabled
	_refresh_lifecycle()


func is_agent_enabled() -> bool:
	return _agent_enabled


func set_agent_paused(paused: bool) -> void:
	_paused_overridden = true
	_agent_paused = paused
	_refresh_lifecycle()


func is_agent_paused() -> bool:
	return _agent_paused


func is_agent_advancing() -> bool:
	return _agent_enabled and not _agent_paused


## Advances the courier only while enabled and unpaused. The pose is a function of
## total elapsed time, so frame subdivision does not change state.
func advance_agent_simulation(delta: float) -> bool:
	if not is_agent_advancing() or not is_finite(delta) or delta <= 0.0:
		return false
	_elapsed += delta
	_update_agent_transforms()
	return true


## Deterministic seek used by capture tooling. This intentionally works while
## paused or disabled, but it never changes either lifecycle flag.
func set_agent_time(seconds: float) -> bool:
	if not is_finite(seconds) or seconds < 0.0:
		return false
	_elapsed = seconds
	_update_agent_transforms()
	return true


func reset_agent_time() -> void:
	_elapsed = 0.0
	_update_agent_transforms()


func get_agent_time() -> float:
	return _elapsed


func get_agent_state() -> Dictionary:
	var pose := _pose_at(_elapsed)
	return {
		"agent_id": get_agent_id(),
		"route_id": _route_id,
		"elapsed": _elapsed,
		"enabled": _agent_enabled,
		"paused": _agent_paused,
		"advancing": is_agent_advancing(),
		"visible": _presentation_root != null and _presentation_root.visible,
		"carriage_position": _carriage.position if _carriage != null else Vector3.ZERO,
		"carriage_yaw": _carriage.rotation.y if _carriage != null else 0.0,
		"route_distance": float(pose.distance),
		"outbound": bool(pose.outbound),
		"status_lens_lit": _status_lens_should_be_lit(_elapsed),
	}


func get_determinism_fingerprint() -> String:
	return "%s|v%d|agent=%s|route=%s|seed=%d|speed=%.4f|lift=%.4f|sway=%.4f:%.4f|length=%.4f|points=%d" % [
		str(COMPONENT_ID),
		SCHEMA_VERSION,
		str(get_agent_id()),
		str(_route_id),
		_get_effective_variation_seed(),
		_get_effective_traversal_speed(),
		_get_effective_hover_lift(),
		_get_effective_lateral_sway(),
		_get_effective_vertical_sway(),
		_route_length,
		_route_points.size(),
	]


func get_performance_audit() -> Dictionary:
	var counts := _count_subtree()
	var reported := {
		"node_count": int(counts.node_count),
		"mesh_instances": int(counts.mesh_instances),
		"unique_materials": _materials.size(),
		"lights": int(counts.lights),
		"particle_emitters": int(counts.particle_emitters),
		"collision_nodes": int(counts.collision_nodes),
		"audio_nodes": int(counts.audio_nodes),
		"area_nodes": int(counts.area_nodes),
		"animated_assemblies": 1 if _carriage != null else 0,
	}
	var errors := PackedStringArray()
	for key: String in PERFORMANCE_BUDGET.keys():
		if int(reported.get(key, 0)) > int(PERFORMANCE_BUDGET[key]):
			errors.append("%s exceeds the service agent budget (%d > %d)" % [key, reported.get(key, 0), PERFORMANCE_BUDGET[key]])
	return {
		"schema_version": SCHEMA_VERSION,
		"valid": errors.is_empty(),
		"within_budget": errors.is_empty(),
		"errors": errors,
		"counts": reported.duplicate(true),
		"budgets": PERFORMANCE_BUDGET.duplicate(true),
		"process_enabled": is_processing(),
		"physics_process_enabled": is_physics_processing(),
		"headless_safe": true,
		"uses_external_assets": false,
		"uses_particles": false,
		"uses_dynamic_lights": false,
		"uses_collision": false,
		"determinism_fingerprint": get_determinism_fingerprint(),
	}


## Detached resource evidence for focused audits. It proves that the visible
## parameter contracts are unchanged, that every courier retains the process
## catalog identities, and that the dynamic lens still points at the correct
## dim/lit entry for this instance's clock.
func get_material_catalog_audit() -> Dictionary:
	var identities := {}
	var shared_identity := true
	var keys := PackedStringArray()
	for key in _materials:
		var material := _materials[key] as Material
		var shared_material := _shared_material_catalog.get(key) as Material
		keys.append(str(key))
		identities[key] = material.get_instance_id() if material != null else 0
		shared_identity = (
			shared_identity
			and material != null
			and shared_material != null
			and material == shared_material
		)
	keys.sort()
	var bound_references := 0
	for candidate in find_children("*", "MeshInstance3D", true, false):
		if (candidate as MeshInstance3D).material_override != null:
			bound_references += 1
	return {
		"valid": (
			_materials.size() == 6
			and shared_identity
			and _materials_match_build_contract()
			and _agent_lens_material_matches_clock()
		),
		"catalog_shared": shared_identity,
		"catalog_keys": keys,
		"catalog_entry_count": _materials.size(),
		"retained_unique_materials": identities.size(),
		"bound_material_references": bound_references,
		"dynamic_lens_bindings_valid": _agent_lens_material_matches_clock(),
		"identity_by_key": identities.duplicate(true),
		"visible_parameters_by_key": _built_material_contracts.duplicate(true),
	}


static func audit_material_catalog_roster(candidates: Array[Node]) -> Dictionary:
	var errors := PackedStringArray()
	var reference_identity_by_key := {}
	var retained_material_ids := {}
	var bound_material_references := 0
	var instance_count := 0
	var catalogs_share_identity := true
	for candidate in candidates:
		if not candidate is StationServiceAgent:
			errors.append("material roster contains a node that is not StationServiceAgent")
			continue
		var agent := candidate as StationServiceAgent
		var audit := agent.get_material_catalog_audit()
		instance_count += 1
		if not bool(audit.valid):
			errors.append("courier '%s' material catalog fails its own audit" % agent.get_agent_id())
		var identities := audit.identity_by_key as Dictionary
		if reference_identity_by_key.is_empty():
			reference_identity_by_key = identities.duplicate(true)
		else:
			catalogs_share_identity = catalogs_share_identity and identities == reference_identity_by_key
		for material_id in identities.values():
			retained_material_ids[int(material_id)] = true
		bound_material_references += int(audit.bound_material_references)
	if not catalogs_share_identity:
		errors.append("couriers do not share one material catalog identity")
	if instance_count > 0 and retained_material_ids.size() != 6:
		errors.append("courier roster retains %d materials instead of the shared six-entry catalog" % retained_material_ids.size())
	return {
		"schema_version": SCHEMA_VERSION,
		"valid": errors.is_empty(),
		"errors": errors,
		"catalog_shared": catalogs_share_identity,
		"identity_by_key": reference_identity_by_key.duplicate(true),
		"counts": {
			"instance_count": instance_count,
			"catalog_entries": reference_identity_by_key.size(),
			"retained_unique_materials": retained_material_ids.size(),
			"bound_material_references": bound_material_references,
		},
	}


func get_validation_errors() -> PackedStringArray:
	var errors := PackedStringArray()
	if _route_anchor == null or _service_envelope_anchor == null or _presentation_root == null:
		errors.append("required route anchor, envelope anchor, or presentation root is missing")
		return errors
	if (
		get_node_or_null(^"RouteAnchor") != _route_anchor
		or get_node_or_null(^"ServiceEnvelopeAnchor") != _service_envelope_anchor
		or get_node_or_null(^"PresentationRoot") != _presentation_root
		or not is_instance_valid(_route_anchor)
		or not is_instance_valid(_service_envelope_anchor)
		or not is_instance_valid(_presentation_root)
		or not is_ancestor_of(_route_anchor)
		or not is_ancestor_of(_service_envelope_anchor)
		or not is_ancestor_of(_presentation_root)
	):
		errors.append("required live anchor and presentation identities changed")
	elif (
		not _route_anchor.transform.is_equal_approx(Transform3D.IDENTITY)
		or not _presentation_root.transform.is_equal_approx(Transform3D.IDENTITY)
		or not _service_envelope_anchor.basis.is_equal_approx(Basis.IDENTITY)
		or not _service_envelope_anchor.position.is_equal_approx(get_service_envelope_center())
	):
		errors.append("required anchor or presentation transforms diverged from the built contract")
	if get_agent_id().is_empty():
		errors.append("service agent requires a stable non-empty agent id")
	if not _route_configured:
		errors.append("service agent has no configured navigation route")
	if not _built_hierarchy_is_live():
		errors.append("built courier hierarchy identities changed after construction")
	if not is_instance_valid(_carriage) or not _presentation_root.is_ancestor_of(_carriage):
		errors.append("service carriage no longer belongs to the live presentation hierarchy")
	if not basis.is_equal_approx(Basis.IDENTITY):
		errors.append("service agent mount must stay unrotated and unscaled so hover lift remains world-up")
	if _built:
		if agent_id != _built_agent_id:
			errors.append("agent_id cannot be changed after the component has built")
		if starts_enabled != _built_starts_enabled:
			errors.append("starts_enabled cannot be changed after the component has built")
		if starts_paused != _built_starts_paused:
			errors.append("starts_paused cannot be changed after the component has built")
		if not is_equal_approx(playback_speed, _built_playback_speed):
			errors.append("playback_speed cannot be changed after the component has built")
		if variation_seed != _built_variation_seed:
			errors.append("variation_seed cannot be changed after the component has built")
		if not is_equal_approx(traversal_speed, _built_traversal_speed):
			errors.append("traversal_speed cannot be changed after the component has built")
		if not is_equal_approx(hover_lift, _built_hover_lift):
			errors.append("hover_lift cannot be changed after the component has built")
		if not is_equal_approx(lateral_sway, _built_lateral_sway):
			errors.append("lateral_sway cannot be changed after the component has built")
		if not is_equal_approx(vertical_sway, _built_vertical_sway):
			errors.append("vertical_sway cannot be changed after the component has built")
		if _route_fingerprint() != _built_route_fingerprint:
			errors.append("navigation route cannot be changed after the component has built")
	var speed := _get_effective_traversal_speed()
	if not is_finite(speed) or speed < MINIMUM_TRAVERSAL_SPEED or speed > MAXIMUM_TRAVERSAL_SPEED:
		errors.append("traversal speed must stay inside the bounded service band")
	var lift := _get_effective_hover_lift()
	if not is_finite(lift) or lift < MINIMUM_HOVER_LIFT or lift > MAXIMUM_HOVER_LIFT:
		errors.append("hover lift must stay inside the bounded service band")
	if _get_effective_lateral_sway() < 0.0 or _get_effective_lateral_sway() > MAXIMUM_LATERAL_SWAY:
		errors.append("lateral sway must stay inside the bounded service band")
	if _get_effective_vertical_sway() < 0.0 or _get_effective_vertical_sway() > MAXIMUM_VERTICAL_SWAY:
		errors.append("vertical sway must stay inside the bounded service band")
	if _get_effective_variation_seed() < 0:
		errors.append("variation seed must not be negative")
	var effective_playback := _get_effective_playback_speed()
	if not is_finite(effective_playback) or effective_playback <= 0.0:
		errors.append("playback speed must be finite and greater than zero")
	if _route_configured:
		if _route_points.size() < MINIMUM_WAYPOINTS or _route_points.size() > MAXIMUM_WAYPOINTS:
			errors.append("configured route waypoint count left the bounded contract")
		if _route_length < MINIMUM_ROUTE_LENGTH or _route_length > MAXIMUM_ROUTE_LENGTH:
			errors.append("configured route length left the bounded contract")
		if _route_node_ids.size() != _route_points.size():
			errors.append("configured route node ids and waypoints disagree")
	if is_processing() != is_agent_advancing():
		errors.append("process state must match the enabled and paused lifecycle state")
	if _presentation_root.visible != _agent_enabled:
		errors.append("presentation visibility must match the enabled lifecycle state")
	var performance := get_performance_audit()
	if not bool(performance.within_budget):
		errors.append_array(performance.errors as PackedStringArray)
	var counts := performance.counts as Dictionary
	for key: String in PERFORMANCE_BUDGET.keys():
		if int(counts.get(key, -1)) != int(PERFORMANCE_BUDGET[key]):
			errors.append("live %s count diverged from the immutable service agent build" % key)
	if int(counts.get("collision_nodes", -1)) != 0 or int(counts.get("area_nodes", -1)) != 0:
		errors.append("presentation courier must never create collision or interaction volumes")
	var authority := get_authority_contract()
	if int(authority.ship_berth_count) != 0:
		errors.append("service courier must never contain berth authority")
	if not _agent_pose_matches_clock():
		errors.append("live courier pose diverged from its deterministic clock")
	if not _materials_match_build_contract():
		errors.append("shared courier material catalog diverged from its built visible parameters")
	if not _envelope_contains_complete_cycle():
		errors.append("courier traversal leaves the published service envelope")
	if not _live_meshes_fit_envelope():
		errors.append("live courier geometry exceeds the published service envelope")
	return errors


func get_audit_report() -> Dictionary:
	var errors := get_validation_errors()
	return {
		"schema_version": SCHEMA_VERSION,
		"component_id": COMPONENT_ID,
		"agent_id": get_agent_id(),
		"valid": errors.is_empty(),
		"errors": errors,
		"evidence_status": EVIDENCE_STATUS,
		"evidence": get_evidence_metadata(),
		"integration": get_integration_contract(),
		"authority": get_authority_contract(),
		"performance": get_performance_audit(),
		"material_catalog": get_material_catalog_audit(),
		"lifecycle": {
			"enabled": _agent_enabled,
			"paused": _agent_paused,
			"advancing": is_agent_advancing(),
			"process_enabled": is_processing(),
			"reversible": true,
			"mode": &"identity_preserving_enable_disable",
		},
		"state": get_agent_state(),
		"determinism_fingerprint": get_determinism_fingerprint(),
	}


func audit() -> Dictionary:
	return get_audit_report().duplicate(true)


# --- deterministic motion -----------------------------------------------------


func _seed_phase() -> float:
	return fmod(float(_get_effective_variation_seed()), 997.0) / 997.0 * TAU


## Pure pose function. Everything visible about the courier at time `seconds` is
## derived here, which is what makes 30/60/120 Hz stepping, absolute seeking, and
## the audit's envelope sweep agree.
##
## Travel is a cosine-eased out-and-back along the resolved route, so the courier
## decelerates to a stop at each declared endpoint instead of snapping direction
## at speed. `traversal_speed` is the mean speed over the cycle. The heading turns
## through `PI` inside a narrow band around each endpoint, while the courier is
## nearly stationary. A multi-segment route still changes heading abruptly at an
## interior corner; production routes are single connector hops.
func _pose_at(seconds: float) -> Dictionary:
	if not _route_configured or _route_length <= 0.0:
		return {
			"position": Vector3.UP * _get_effective_hover_lift(),
			"yaw": 0.0,
			"distance": 0.0,
			"outbound": true,
		}
	var theta := fposmod(seconds * PI * _get_effective_traversal_speed() / _route_length, TAU)
	var distance := _route_length * 0.5 * (1.0 - cos(theta))
	var sample := _sample_route(distance)
	var direction := sample.direction as Vector3
	var lateral_axis := Vector3(-direction.z, 0.0, direction.x)
	if lateral_axis.length_squared() < 0.000001:
		lateral_axis = Vector3.RIGHT
	else:
		lateral_axis = lateral_axis.normalized()
	var phase := _seed_phase()
	var sway := lateral_axis * sin(seconds * 0.61 + phase) * _get_effective_lateral_sway()
	var bob := Vector3.UP * (
		_get_effective_hover_lift() + sin(seconds * 0.83 + phase * 1.3) * _get_effective_vertical_sway()
	)
	var turn := (
		smoothstep(PI - TURN_BAND, PI, theta)
		if theta < PI
		else 1.0 - smoothstep(TAU - TURN_BAND, TAU, theta)
	)
	return {
		"position": (sample.position as Vector3) + sway + bob,
		"yaw": atan2(direction.x, direction.z) + PI * turn,
		"distance": distance,
		"outbound": theta < PI,
	}


func _sample_route(distance: float) -> Dictionary:
	var remaining := clampf(distance, 0.0, _route_length)
	for index in _segment_lengths.size():
		var segment_length := float(_segment_lengths[index])
		var start := _route_points[index]
		var end := _route_points[index + 1]
		if remaining <= segment_length or index == _segment_lengths.size() - 1:
			var ratio: float = clampf(remaining / segment_length, 0.0, 1.0) if segment_length > 0.0 else 0.0
			return {
				"position": start.lerp(end, ratio),
				"direction": (end - start).normalized(),
			}
		remaining -= segment_length
	return {"position": _route_points[0], "direction": Vector3.FORWARD}


func _status_lens_should_be_lit(seconds: float) -> bool:
	return fmod(seconds + _seed_phase(), 1.6) < 0.42


func _update_agent_transforms() -> void:
	if _carriage == null or not is_instance_valid(_carriage):
		return
	var pose := _pose_at(_elapsed)
	_carriage.position = pose.position as Vector3
	_carriage.rotation = Vector3(0.0, float(pose.yaw), 0.0)
	if is_instance_valid(_status_lens):
		_status_lens.material_override = (
			_materials["cyan_lit"] if _status_lens_should_be_lit(_elapsed) else _materials["cyan_dim"]
		) as Material


func _agent_pose_matches_clock() -> bool:
	if not is_instance_valid(_carriage):
		return false
	var pose := _pose_at(_elapsed)
	if not _carriage.position.is_equal_approx(pose.position as Vector3):
		return false
	if not _carriage.scale.is_equal_approx(Vector3.ONE):
		return false
	if not _carriage.basis.is_equal_approx(
		Basis.from_euler(Vector3(0.0, float(pose.yaw), 0.0), _carriage.rotation_order)
	):
		return false
	return _agent_lens_material_matches_clock()


func _agent_lens_material_matches_clock() -> bool:
	if not is_instance_valid(_status_lens):
		return false
	var expected_lens: Material = (
		_materials["cyan_lit"] if _status_lens_should_be_lit(_elapsed) else _materials["cyan_dim"]
	)
	return _status_lens.material_override == expected_lens


# --- envelope -----------------------------------------------------------------


func _recompute_service_envelope() -> void:
	var lift := _get_effective_hover_lift()
	var vertical := _get_effective_vertical_sway()
	var lateral := _get_effective_lateral_sway()
	if not _route_configured or _route_points.is_empty():
		_envelope_min = Vector3(-BODY_HALF_EXTENTS.x, lift - vertical - BODY_HALF_EXTENTS.y, -BODY_HALF_EXTENTS.z)
		_envelope_max = Vector3(BODY_HALF_EXTENTS.x, lift + vertical + BODY_HALF_EXTENTS.y, BODY_HALF_EXTENTS.z)
		return
	var minimum := _route_points[0]
	var maximum := _route_points[0]
	for point in _route_points:
		minimum = Vector3(minf(minimum.x, point.x), minf(minimum.y, point.y), minf(minimum.z, point.z))
		maximum = Vector3(maxf(maximum.x, point.x), maxf(maximum.y, point.y), maxf(maximum.z, point.z))
	# Sway is applied along a horizontal axis perpendicular to travel, so
	# expanding both horizontal axes is deliberately conservative.
	var horizontal := lateral + BODY_HALF_EXTENTS.x
	_envelope_min = Vector3(
		minimum.x - horizontal,
		minimum.y + lift - vertical - BODY_HALF_EXTENTS.y,
		minimum.z - horizontal
	)
	_envelope_max = Vector3(
		maximum.x + horizontal,
		maximum.y + lift + vertical + BODY_HALF_EXTENTS.y,
		maximum.z + horizontal
	)


func _envelope_contains_complete_cycle() -> bool:
	if not _route_configured or _route_length <= 0.0:
		return true
	var speed := _get_effective_traversal_speed()
	if speed <= 0.0:
		return false
	var cycle_seconds := (_route_length * 2.0) / speed
	for index in ENVELOPE_SAMPLE_COUNT:
		var seconds := cycle_seconds * float(index) / float(ENVELOPE_SAMPLE_COUNT)
		var pose := _pose_at(seconds)
		if not _point_inside_envelope((pose.position as Vector3), BODY_HALF_EXTENTS, 0.001):
			return false
	return true


func _point_inside_envelope(point: Vector3, half_extents: Vector3, tolerance: float) -> bool:
	var minimum := point - half_extents
	var maximum := point + half_extents
	return (
		minimum.x >= _envelope_min.x - tolerance
		and minimum.y >= _envelope_min.y - tolerance
		and minimum.z >= _envelope_min.z - tolerance
		and maximum.x <= _envelope_max.x + tolerance
		and maximum.y <= _envelope_max.y + tolerance
		and maximum.z <= _envelope_max.z + tolerance
	)


func _live_meshes_fit_envelope() -> bool:
	var mesh_count := 0
	for candidate in find_children("*", "MeshInstance3D", true, false):
		var mesh_instance := candidate as MeshInstance3D
		if mesh_instance.mesh == null:
			return false
		var relative: Variant = _transform_relative_to_component(mesh_instance)
		if not (relative is Transform3D):
			return false
		var bounds := mesh_instance.mesh.get_aabb()
		for corner_index in 8:
			var corner := bounds.position + Vector3(
				bounds.size.x if corner_index & 1 else 0.0,
				bounds.size.y if corner_index & 2 else 0.0,
				bounds.size.z if corner_index & 4 else 0.0
			)
			var point: Vector3 = (relative as Transform3D) * corner
			if not _point_inside_envelope(point, Vector3.ZERO, 0.02):
				return false
		mesh_count += 1
	return mesh_count == int(PERFORMANCE_BUDGET.mesh_instances)


func _transform_relative_to_component(node: Node3D) -> Variant:
	if not is_ancestor_of(node):
		return null
	var relative := Transform3D.IDENTITY
	var current: Node = node
	while current != self:
		if not current is Node3D:
			return null
		relative = (current as Node3D).transform * relative
		current = current.get_parent()
		if current == null:
			return null
	return relative


# --- lifecycle and construction ----------------------------------------------


func _refresh_lifecycle() -> void:
	if _presentation_root != null and is_instance_valid(_presentation_root):
		_presentation_root.visible = _agent_enabled
	set_process(_agent_enabled and not _agent_paused)


func _get_effective_playback_speed() -> float:
	return _built_playback_speed if _built else playback_speed


func _get_effective_variation_seed() -> int:
	return _built_variation_seed if _built else variation_seed


func _get_effective_traversal_speed() -> float:
	return _built_traversal_speed if _built else traversal_speed


func _get_effective_hover_lift() -> float:
	return _built_hover_lift if _built else hover_lift


func _get_effective_lateral_sway() -> float:
	return _built_lateral_sway if _built else lateral_sway


func _get_effective_vertical_sway() -> float:
	return _built_vertical_sway if _built else vertical_sway


func _route_fingerprint() -> String:
	var parts := PackedStringArray([str(_route_id)])
	for node_id in _route_node_ids:
		parts.append(node_id)
	for point in _route_points:
		parts.append("%.5f,%.5f,%.5f" % [point.x, point.y, point.z])
	return "|".join(parts)


func _apply_evidence_metadata() -> void:
	set_meta("component_id", COMPONENT_ID)
	set_meta("agent_id", get_agent_id())
	set_meta("evidence_status", EVIDENCE_STATUS)
	set_meta("presentation_only", true)
	set_meta("nonblocking_collision", true)
	set_meta("owns_berth_authority", false)
	set_meta("content_note", CONTENT_NOTE)
	_presentation_root.set_meta("evidence_status", EVIDENCE_STATUS)
	_presentation_root.set_meta("modern_interpretation", true)


func _create_materials() -> void:
	if not _shared_material_catalog.is_empty():
		_materials = _shared_material_catalog.duplicate(false)
		return
	_materials["hull"] = _material(Color("2b4753"), 0.66, 0.34)
	_materials["hull_edge"] = _material(Color("6d868f"), 0.62, 0.28)
	_materials["graphite"] = _material(Color("141d22"), 0.44, 0.6)
	_materials["orange"] = _material(Color("e78e37"), 0.24, 0.37)
	_materials["cyan_dim"] = _material(Color("347b80"), 0.28, 0.34, Color("20878e"), 0.32)
	_materials["cyan_lit"] = _material(Color("78f1ec"), 0.12, 0.25, Color("35d8dc"), 1.5)
	_apply_station_panel_family()
	_shared_material_catalog = _materials.duplicate(false)


func _capture_built_material_contracts() -> void:
	_built_material_contracts.clear()
	for key in _materials:
		var material := _materials[key] as StandardMaterial3D
		if material != null:
			_built_material_contracts[key] = _standard_material_contract(material)


func _standard_material_contract(material: StandardMaterial3D) -> Dictionary:
	return {
		"instance_id": material.get_instance_id(),
		"albedo_color": material.albedo_color,
		"metallic": material.metallic,
		"roughness": material.roughness,
		"emission_enabled": material.emission_enabled,
		"emission": material.emission,
		"emission_energy": material.emission_energy_multiplier,
		"clearcoat_enabled": material.clearcoat_enabled,
		"clearcoat": material.clearcoat,
		"clearcoat_roughness": material.clearcoat_roughness,
		"storage": _resource_storage_fingerprint(material),
	}


func _materials_match_build_contract() -> bool:
	if _built_material_contracts.size() != _materials.size():
		return false
	for key in _built_material_contracts:
		var material := _materials.get(key) as StandardMaterial3D
		var contract := _built_material_contracts[key] as Dictionary
		if (
			material == null
			or material.get_instance_id() != int(contract.get("instance_id", 0))
			or not material.albedo_color.is_equal_approx(
				contract.get("albedo_color", Color.TRANSPARENT) as Color
			)
			or not is_equal_approx(material.metallic, float(contract.get("metallic", 0.0)))
			or not is_equal_approx(material.roughness, float(contract.get("roughness", 0.0)))
			or material.emission_enabled != bool(contract.get("emission_enabled", false))
			or not material.emission.is_equal_approx(
				contract.get("emission", Color.TRANSPARENT) as Color
			)
			or not is_equal_approx(
				material.emission_energy_multiplier,
				float(contract.get("emission_energy", 0.0))
			)
			or material.clearcoat_enabled != bool(contract.get("clearcoat_enabled", false))
			or not is_equal_approx(material.clearcoat, float(contract.get("clearcoat", 0.0)))
			or not is_equal_approx(
				material.clearcoat_roughness,
				float(contract.get("clearcoat_roughness", 0.0))
			)
			or _resource_storage_fingerprint(material)
				!= (contract.get("storage", PackedStringArray()) as PackedStringArray)
		):
			return false
	return true


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


## Bind the registered station panel/normal/roughness recipe to the courier's
## structural greys, at the same 0.30 physical scale every other station
## population uses.
##
## A rendered review of the integrated couriers found the one thing wrong with
## this component: it was the only visible station body still built from raw
## `BoxMesh` with flat scalar colour, so at player eye height it read as an
## untextured primitive hanging over the deck rather than as a service craft —
## exactly the four properties (flat scalar colour, sharp unbevelled edges,
## uniform roughness, no contact shading) the project's own art-direction notes
## name as what makes blocky geometry read as a toy. The painted `orange` cargo
## pod and the cyan status lens stay outside the family, exactly as every sibling
## module leaves its painted hazard and lit-cue materials unmapped.
func _apply_station_panel_family() -> void:
	for key in ["hull", "hull_edge", "graphite"]:
		StationSurfaceKit.apply_panel_triplanar(_materials[key] as StandardMaterial3D, 0.3)


func _material(
		albedo: Color,
		metallic: float,
		roughness: float,
		emission := Color.BLACK,
		emission_energy := 0.0
	) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = albedo
	material.metallic = metallic
	material.roughness = roughness
	# Same faint coated-plate specular the Aft, Habitat, Freight, Fleet Dock and
	# operations-activity surfaces already carry. Without it the courier kept a
	# dry matte response that read as plastic beside the plated deck under it.
	material.clearcoat_enabled = true
	material.clearcoat = 0.18
	material.clearcoat_roughness = 0.48
	if emission_energy > 0.0:
		material.emission_enabled = true
		material.emission = emission
		material.emission_energy_multiplier = emission_energy
	return material


func _build_courier() -> void:
	_carriage = Node3D.new()
	_carriage.name = "ServiceCarriage"
	_presentation_root.add_child(_carriage)
	_box(_carriage, "Hull", Vector3(0.0, 0.0, 0.0), Vector3(0.86, 0.34, 1.18), _materials["hull"])
	_box(_carriage, "ForwardCowl", Vector3(0.0, 0.02, -0.72), Vector3(0.5, 0.26, 0.34), _materials["hull_edge"])
	_box(_carriage, "PortPod", Vector3(-0.56, -0.02, 0.06), Vector3(0.2, 0.22, 0.6), _materials["graphite"])
	_box(_carriage, "StarboardPod", Vector3(0.56, -0.02, 0.06), Vector3(0.2, 0.22, 0.6), _materials["graphite"])
	_box(_carriage, "CargoPod", Vector3(0.0, -0.3, 0.12), Vector3(0.54, 0.3, 0.62), _materials["orange"])
	_status_lens = _box(_carriage, "StatusLens", Vector3(0.0, 0.2, -0.5), Vector3(0.22, 0.1, 0.06), _materials["cyan_dim"])
	_box(_carriage, "TailFin", Vector3(0.0, 0.28, 0.5), Vector3(0.08, 0.42, 0.36), _materials["hull_edge"])


func _box(
		parent: Node3D,
		node_name: String,
		local_position: Vector3,
		size: Vector3,
		material: Material
	) -> MeshInstance3D:
	# Chamfered rather than a raw `BoxMesh`: the bounding box, and therefore the
	# published service envelope and `BODY_HALF_EXTENTS`, are unchanged, but the
	# edges now catch a highlight the way the plated deck below already does. The
	# builder and the bevel rule are the shared kit's, not a local copy.
	var instance := MeshInstance3D.new()
	instance.name = node_name
	instance.mesh = StationSurfaceKit.rounded_box_mesh_with_bevel_cached(
		size,
		StationSurfaceKit.proportional_bevel_for_size(size, 0.2),
		_rounded_box_cache,
		StationSurfaceKit.BevelUV.FACE_GRID
	)
	instance.material_override = material
	instance.position = local_position
	parent.add_child(instance)
	return instance


func _capture_built_hierarchy() -> void:
	_built_node_instance_ids.clear()
	for candidate in find_children("*", "", true, false):
		_built_node_instance_ids[str(get_path_to(candidate))] = candidate.get_instance_id()


func _built_hierarchy_is_live() -> bool:
	if not _built or _built_node_instance_ids.is_empty():
		return false
	var live := find_children("*", "", true, false)
	if live.size() != _built_node_instance_ids.size():
		return false
	for relative_path_value in _built_node_instance_ids:
		var candidate := get_node_or_null(NodePath(str(relative_path_value)))
		if (
			not is_instance_valid(candidate)
			or candidate.get_instance_id() != int(_built_node_instance_ids[relative_path_value])
			or not is_ancestor_of(candidate)
		):
			return false
	return true


func _count_subtree() -> Dictionary:
	var counts := {
		"node_count": 0,
		"mesh_instances": 0,
		"lights": 0,
		"particle_emitters": 0,
		"collision_nodes": 0,
		"audio_nodes": 0,
		"area_nodes": 0,
		"ship_berth_count": 0,
	}
	for node in find_children("*", "", true, false):
		counts.node_count = int(counts.node_count) + 1
		if node is MeshInstance3D:
			counts.mesh_instances = int(counts.mesh_instances) + 1
		if node is Light3D:
			counts.lights = int(counts.lights) + 1
		if node is GPUParticles3D or node is CPUParticles3D:
			counts.particle_emitters = int(counts.particle_emitters) + 1
		if node is CollisionObject3D or node is CollisionShape3D:
			counts.collision_nodes = int(counts.collision_nodes) + 1
		if node is Area3D:
			counts.area_nodes = int(counts.area_nodes) + 1
		if node is AudioStreamPlayer or node is AudioStreamPlayer2D or node is AudioStreamPlayer3D:
			counts.audio_nodes = int(counts.audio_nodes) + 1
		var script := node.get_script() as Script
		if script != null and script.resource_path.ends_with("/ship_berth.gd"):
			counts.ship_berth_count = int(counts.ship_berth_count) + 1
	return counts


func _is_finite_vector(value: Vector3) -> bool:
	return is_finite(value.x) and is_finite(value.y) and is_finite(value.z)
