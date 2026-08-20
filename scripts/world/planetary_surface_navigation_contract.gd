class_name PlanetarySurfaceNavigationContract
extends Resource

## Bounded authored surface route graph for one landing region.
##
## This contract is deliberately data-only: it does not raycast, generate
## terrain, move a craft/player, stream a scene, or resolve/play audio. Node
## positions are body-local metres and are authored alongside the landing
## region. Audio IDs are opaque route hints consumed by a later presentation
## owner; the existing catalog remains the only resolver.

const SCHEMA_VERSION := 1
const CONTENT_CLASS: StringName = &"NEW"
const EVIDENCE_STATUS: StringName = &"modern_interpretation"
const MAX_NODES := 128
const MAX_EDGES := 256
const MAX_LANDING_SITES := 16
const MAX_LANDMARKS := 64
const MAX_HAZARDS := 64
const MAX_ROUTE_LENGTH_M := 100_000.0
const DEFAULT_MAX_SEGMENT_LENGTH_M := 5_000.0
const AUDIO_PROFILE_IDS := [
	PlanetarySurfaceAudioCatalog.EXTERIOR_PROFILE_ID,
	PlanetarySurfaceAudioCatalog.INTERIOR_PROFILE_ID,
]
const HAZARD_KIND_IDS := [
	&"unstable_terrain", &"exposed_reactor", &"dust_surge", &"collapsed_structure",
]

@export var world_id: StringName = &"ember_moon"
@export var region_id: StringName = &"ember_caldera"
@export var node_ids := PackedStringArray([
	"pad_alpha_egress", "surface_staging_gate", "caldera_overlook",
])
@export var node_positions_body_local_m := PackedVector3Array([
	Vector3(18.0, 120000.0, 0.0),
	Vector3(42.0, 120000.0, 0.0),
	Vector3(420.0, 120025.0, -180.0),
])
@export var edge_from_ids := PackedStringArray([
	"pad_alpha_egress", "surface_staging_gate",
])
@export var edge_to_ids := PackedStringArray([
	"surface_staging_gate", "caldera_overlook",
])
## Stable authored route IDs parallel to the directed edge arrays. They are
## references for content and UI only; this resource never resolves movement.
@export var edge_route_ids := PackedStringArray([
	"pad_to_surface_staging", "surface_staging_to_overlook",
])
@export_range(0.25, MAX_ROUTE_LENGTH_M, 0.25)
var maximum_segment_length_m := DEFAULT_MAX_SEGMENT_LENGTH_M
## Opaque IDs parallel to node_ids. Surface nodes normally select exterior;
## an interior value is permitted for a sheltered/structure landmark.
@export var node_audio_profile_ids := PackedStringArray([
	"temperate_exterior", "temperate_exterior", "temperate_exterior",
])

## Authored landing sites, landmarks, and recoverable hazards refer to the
## route graph by stable marker/route IDs. Positions are body-local metres.
## These declarations intentionally do not instantiate terrain, collision,
## navigation, hazard, landing, or teleport authority.
@export_category("Authored landing sites")
@export var landing_site_ids := PackedStringArray(["ember_caldera_pad"])
@export var landing_site_display_names := PackedStringArray(["Caldera Landing Pad"])
@export var landing_site_marker_ids := PackedStringArray(["pad_alpha_egress"])
@export var landing_site_route_ids := PackedStringArray(["pad_to_surface_staging"])
@export var landing_site_positions_body_local_m := PackedVector3Array([
	Vector3(18.0, 120000.0, 0.0),
])

@export_category("Authored landmarks")
@export var landmark_ids := PackedStringArray([
	"surface_staging_gate", "caldera_overlook",
])
@export var landmark_display_names := PackedStringArray([
	"Surface Staging Gate", "Caldera Overlook",
])
@export var landmark_marker_ids := PackedStringArray([
	"surface_staging_gate", "caldera_overlook",
])
@export var landmark_route_ids := PackedStringArray([
	"pad_to_surface_staging", "surface_staging_to_overlook",
])
@export var landmark_positions_body_local_m := PackedVector3Array([
	Vector3(42.0, 120000.0, 0.0), Vector3(420.0, 120025.0, -180.0),
])

@export_category("Recoverable hazards")
@export var hazard_ids := PackedStringArray([
	"caldera_thermal_vent", "caldera_unstable_slope",
])
@export var hazard_display_names := PackedStringArray([
	"Caldera Thermal Vent", "Caldera Unstable Slope",
])
@export var hazard_kind_ids := PackedStringArray([
	"exposed_reactor", "unstable_terrain",
])
@export var hazard_marker_ids := PackedStringArray([
	"surface_staging_gate", "caldera_overlook",
])
@export var hazard_route_ids := PackedStringArray([
	"pad_to_surface_staging", "surface_staging_to_overlook",
])
@export var hazard_recovery_ids := PackedStringArray([
	"return_to_landed_ship", "abort_to_orbit_return",
])
@export var hazard_positions_body_local_m := PackedVector3Array([
	Vector3(58.0, 120000.0, -4.0), Vector3(398.0, 120024.0, -170.0),
])


func get_validation_errors() -> PackedStringArray:
	var errors := PackedStringArray()
	_validate_id(errors, "world_id", world_id)
	_validate_id(errors, "region_id", region_id)
	if node_ids.is_empty() or node_ids.size() > MAX_NODES:
		errors.append("node_ids must contain 1 to %d nodes" % MAX_NODES)
	if node_positions_body_local_m.size() != node_ids.size():
		errors.append("node positions must be parallel to node IDs")
	if node_audio_profile_ids.size() != node_ids.size():
		errors.append("node audio profiles must be parallel to node IDs")
	var seen := {}
	for index in node_ids.size():
		var node_id := StringName(node_ids[index])
		_validate_id(errors, "node_ids[%d]" % index, node_id)
		if seen.has(node_id):
			errors.append("node IDs must be unique: %s" % node_id)
		seen[node_id] = true
		if index < node_positions_body_local_m.size() \
				and not _finite_vector(node_positions_body_local_m[index]):
			errors.append("node position %d must be finite" % index)
		if index < node_audio_profile_ids.size():
			var audio_id := StringName(node_audio_profile_ids[index])
			if not AUDIO_PROFILE_IDS.has(audio_id):
				errors.append("node audio profile %d is not in the strict surface catalog" % index)
	if not is_finite(maximum_segment_length_m) \
			or maximum_segment_length_m <= 0.0 \
			or maximum_segment_length_m > MAX_ROUTE_LENGTH_M:
		errors.append("maximum_segment_length_m must be finite and bounded")
	if edge_from_ids.size() != edge_to_ids.size():
		errors.append("edge endpoint arrays must be parallel")
	if edge_route_ids.size() != edge_from_ids.size():
		errors.append("edge route IDs must be parallel to edge endpoints")
	if edge_from_ids.size() > MAX_EDGES:
		errors.append("edge count exceeds bounded maximum")
	var edges := {}
	var routes := {}
	for index in mini(edge_from_ids.size(), edge_to_ids.size()):
		var from_id := StringName(edge_from_ids[index])
		var to_id := StringName(edge_to_ids[index])
		if not seen.has(from_id) or not seen.has(to_id):
			errors.append("edge %d references an unknown node" % index)
			continue
		if from_id == to_id:
			errors.append("edge %d must not be a self-loop" % index)
			continue
		var edge_key := "%s>%s" % [from_id, to_id]
		if edges.has(edge_key):
			errors.append("duplicate directed edge: %s" % edge_key)
		else:
			edges[edge_key] = true
		if index < edge_route_ids.size():
			var route_id := StringName(edge_route_ids[index])
			_validate_id(errors, "edge route %d" % index, route_id)
			if routes.has(route_id):
				errors.append("edge route IDs must be unique: %s" % route_id)
			routes[route_id] = {"from": from_id, "to": to_id}
		var from_index := node_ids.find(String(from_id))
		var to_index := node_ids.find(String(to_id))
		if from_index >= 0 and to_index >= 0 \
				and _finite_vector(node_positions_body_local_m[from_index]) \
				and _finite_vector(node_positions_body_local_m[to_index]) \
				and node_positions_body_local_m[from_index].distance_to(
					node_positions_body_local_m[to_index]
				) > maximum_segment_length_m:
			errors.append("edge %d exceeds maximum segment length" % index)
	if not node_ids.is_empty() and edge_from_ids.size() == edge_to_ids.size() \
			and not _all_nodes_reachable():
		errors.append("authored surface route contains unreachable nodes")
	_validate_landing_sites(errors, routes, seen)
	_validate_landmarks(errors, routes, seen)
	_validate_hazards(errors, routes, seen)
	return errors


func is_definition_valid() -> bool:
	return get_validation_errors().is_empty()


func get_snapshot() -> Dictionary:
	return {
		"schema_version": SCHEMA_VERSION,
		"unit_system": &"game_scale_si_body_local",
		"identity": {"world_id": world_id, "region_id": region_id},
		"nodes": _node_snapshot(),
		"edges": _edge_snapshot(),
		"route_markers": _node_snapshot(),
		"landing_sites": _landing_site_snapshot(),
		"landmarks": _landmark_snapshot(),
		"hazards": _hazard_snapshot(),
		"maximum_segment_length_m": maximum_segment_length_m,
		"audio_catalog_id": PlanetarySurfaceAudioCatalog.CATALOG_ID,
		"evidence": {"content_class": CONTENT_CLASS, "status": EVIDENCE_STATUS,
			"historical_claim": false, "procedural_generation": false},
	}.duplicate(true)


func get_audit_report() -> Dictionary:
	var errors := get_validation_errors()
	return {
		"schema_version": SCHEMA_VERSION, "valid": errors.is_empty(),
		"errors": errors, "snapshot": get_snapshot(),
		"authority": {"surface_route": false, "navigation": false,
			"movement": false, "terrain": false, "streaming": false,
			"audio": false, "gameplay": false, "save": false, "network": false,
			"landing": false, "hazard": false, "teleport": false,
			"procedural_generation": false},
	}.duplicate(true)


func _node_snapshot() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for index in node_ids.size():
		result.append({"node_id": StringName(node_ids[index]),
			"marker_id": StringName(node_ids[index]),
			"position_body_local_m": node_positions_body_local_m[index] \
				if index < node_positions_body_local_m.size() else Vector3.ZERO,
			"audio_profile_id": StringName(node_audio_profile_ids[index]) \
				if index < node_audio_profile_ids.size() else &""})
	return result.duplicate(true)


func _edge_snapshot() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for index in mini(edge_from_ids.size(), edge_to_ids.size()):
		result.append({"from": StringName(edge_from_ids[index]),
			"to": StringName(edge_to_ids[index]),
			"route_id": StringName(edge_route_ids[index]) \
				if index < edge_route_ids.size() else &""})
	return result.duplicate(true)


func get_route_marker_ids() -> PackedStringArray:
	return node_ids.duplicate()


func _landing_site_snapshot() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for index in landing_site_ids.size():
		result.append({
			"id": StringName(landing_site_ids[index]),
			"display_name": String(landing_site_display_names[index]) if index < landing_site_display_names.size() else "",
			"marker_id": StringName(landing_site_marker_ids[index]) if index < landing_site_marker_ids.size() else &"",
			"route_id": StringName(landing_site_route_ids[index]) if index < landing_site_route_ids.size() else &"",
			"position_body_local_m": landing_site_positions_body_local_m[index] if index < landing_site_positions_body_local_m.size() else Vector3.INF,
		})
	return result.duplicate(true)


func _landmark_snapshot() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for index in landmark_ids.size():
		result.append({
			"id": StringName(landmark_ids[index]),
			"display_name": String(landmark_display_names[index]) if index < landmark_display_names.size() else "",
			"marker_id": StringName(landmark_marker_ids[index]) if index < landmark_marker_ids.size() else &"",
			"route_id": StringName(landmark_route_ids[index]) if index < landmark_route_ids.size() else &"",
			"position_body_local_m": landmark_positions_body_local_m[index] if index < landmark_positions_body_local_m.size() else Vector3.INF,
		})
	return result.duplicate(true)


func _hazard_snapshot() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for index in hazard_ids.size():
		result.append({
			"id": StringName(hazard_ids[index]),
			"display_name": String(hazard_display_names[index]) if index < hazard_display_names.size() else "",
			"kind": StringName(hazard_kind_ids[index]) if index < hazard_kind_ids.size() else &"",
			"marker_id": StringName(hazard_marker_ids[index]) if index < hazard_marker_ids.size() else &"",
			"route_id": StringName(hazard_route_ids[index]) if index < hazard_route_ids.size() else &"",
			"recovery_id": StringName(hazard_recovery_ids[index]) if index < hazard_recovery_ids.size() else &"",
			"position_body_local_m": hazard_positions_body_local_m[index] if index < hazard_positions_body_local_m.size() else Vector3.INF,
		})
	return result.duplicate(true)


func _validate_landing_sites(errors: PackedStringArray, routes: Dictionary, markers: Dictionary) -> void:
	_validate_parallel_content(errors, "landing site", landing_site_ids,
		landing_site_display_names, landing_site_marker_ids, landing_site_route_ids,
		landing_site_positions_body_local_m, MAX_LANDING_SITES, routes, markers)


func _validate_landmarks(errors: PackedStringArray, routes: Dictionary, markers: Dictionary) -> void:
	_validate_parallel_content(errors, "landmark", landmark_ids,
		landmark_display_names, landmark_marker_ids, landmark_route_ids,
		landmark_positions_body_local_m, MAX_LANDMARKS, routes, markers)


func _validate_hazards(errors: PackedStringArray, routes: Dictionary, markers: Dictionary) -> void:
	_validate_parallel_content(errors, "hazard", hazard_ids,
		hazard_display_names, hazard_marker_ids, hazard_route_ids,
		hazard_positions_body_local_m, MAX_HAZARDS, routes, markers)
	if hazard_kind_ids.size() != hazard_ids.size():
		errors.append("hazard kinds must be parallel to IDs")
	if hazard_recovery_ids.size() != hazard_ids.size():
		errors.append("hazard recovery IDs must be parallel to IDs")
	for index in hazard_ids.size():
		if index < hazard_kind_ids.size():
			var kind := StringName(hazard_kind_ids[index])
			if not HAZARD_KIND_IDS.has(kind):
				errors.append("hazard kind %d is not in the authored hazard catalog" % index)
		if index < hazard_recovery_ids.size():
			_validate_id(errors, "hazard recovery %d" % index, StringName(hazard_recovery_ids[index]))


func _validate_parallel_content(errors: PackedStringArray, label: String,
		ids: PackedStringArray, display_names: PackedStringArray,
		marker_ids: PackedStringArray, route_ids: PackedStringArray,
		positions: PackedVector3Array, maximum: int, routes: Dictionary,
		markers: Dictionary) -> void:
	if ids.is_empty():
		errors.append("%s must contain at least one authored entry" % label)
	if ids.size() > maximum:
		errors.append("%s count exceeds bounded maximum" % label)
	if display_names.size() != ids.size():
		errors.append("%s display names must be parallel to IDs" % label)
	if marker_ids.size() != ids.size():
		errors.append("%s marker IDs must be parallel to IDs" % label)
	if route_ids.size() != ids.size():
		errors.append("%s route IDs must be parallel to IDs" % label)
	if positions.size() != ids.size():
		errors.append("%s positions must be parallel to IDs" % label)
	var seen := {}
	for index in ids.size():
		var item_id := StringName(ids[index])
		_validate_id(errors, "%s ID %d" % [label, index], item_id)
		if seen.has(item_id):
			errors.append("%s IDs must be unique: %s" % [label, item_id])
		seen[item_id] = true
		if index < display_names.size() and (display_names[index].is_empty() or display_names[index].contains("\n")):
			errors.append("%s display name %d must be bounded single-line copy" % [label, index])
		var marker_id := StringName(marker_ids[index]) if index < marker_ids.size() else &""
		var route_id := StringName(route_ids[index]) if index < route_ids.size() else &""
		if index < marker_ids.size() and not markers.has(marker_id):
			errors.append("%s %d references an unknown route marker" % [label, index])
		if index < route_ids.size() and not routes.has(route_id):
			errors.append("%s %d references an unknown route" % [label, index])
		if routes.has(route_id) and markers.has(marker_id):
			var route: Dictionary = routes[route_id]
			if route["from"] != marker_id and route["to"] != marker_id:
				errors.append("%s %d marker is not an endpoint of its authored route" % [label, index])
		if index < positions.size() and not _finite_vector(positions[index]):
			errors.append("%s position %d must be finite" % [label, index])


func _all_nodes_reachable() -> bool:
	if node_ids.is_empty():
		return false
	var reached := {StringName(node_ids[0]): true}
	var changed := true
	while changed:
		changed = false
		for index in mini(edge_from_ids.size(), edge_to_ids.size()):
			var from_id := StringName(edge_from_ids[index])
			var to_id := StringName(edge_to_ids[index])
			if reached.has(from_id) and not reached.has(to_id):
				reached[to_id] = true
				changed = true
	return reached.size() == node_ids.size()


static func _validate_id(errors: PackedStringArray, field_name: String, value: StringName) -> void:
	var text := String(value)
	if text.is_empty() or text.length() > 64 or text.begins_with("_") \
			or text.ends_with("_") or text.contains("__"):
		errors.append("%s must be a lowercase snake_case identifier" % field_name)
		return
	for code in text.to_ascii_buffer():
		if not ((code >= 97 and code <= 122) or (code >= 48 and code <= 57) or code == 95):
			errors.append("%s must be a lowercase snake_case identifier" % field_name)
			return


static func _finite_vector(value: Vector3) -> bool:
	return is_finite(value.x) and is_finite(value.y) and is_finite(value.z)
