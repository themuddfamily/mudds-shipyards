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
const MAX_ROUTE_LENGTH_M := 100_000.0
const DEFAULT_MAX_SEGMENT_LENGTH_M := 5_000.0
const AUDIO_PROFILE_IDS := [
	PlanetarySurfaceAudioCatalog.EXTERIOR_PROFILE_ID,
	PlanetarySurfaceAudioCatalog.INTERIOR_PROFILE_ID,
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
@export_range(0.25, MAX_ROUTE_LENGTH_M, 0.25)
var maximum_segment_length_m := DEFAULT_MAX_SEGMENT_LENGTH_M
## Opaque IDs parallel to node_ids. Surface nodes normally select exterior;
## an interior value is permitted for a sheltered/structure landmark.
@export var node_audio_profile_ids := PackedStringArray([
	"temperate_exterior", "temperate_exterior", "temperate_exterior",
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
	if edge_from_ids.size() > MAX_EDGES:
		errors.append("edge count exceeds bounded maximum")
	var edges := {}
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
		var from_index := node_ids.find(String(from_id))
		var to_index := node_ids.find(String(to_id))
		if from_index >= 0 and to_index >= 0 \
				and _finite_vector(node_positions_body_local_m[from_index]) \
				and _finite_vector(node_positions_body_local_m[to_index]) \
				and node_positions_body_local_m[from_index].distance_to(
					node_positions_body_local_m[to_index]
				) > maximum_segment_length_m:
			errors.append("edge %d exceeds maximum segment length" % index)
	if not node_ids.is_empty() and errors.is_empty() and not _all_nodes_reachable():
		errors.append("authored surface route contains unreachable nodes")
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
		"maximum_segment_length_m": maximum_segment_length_m,
		"audio_catalog_id": PlanetarySurfaceAudioCatalog.CATALOG_ID,
		"evidence": {"content_class": CONTENT_CLASS, "status": EVIDENCE_STATUS,
			"historical_claim": false},
	}.duplicate(true)


func get_audit_report() -> Dictionary:
	var errors := get_validation_errors()
	return {
		"schema_version": SCHEMA_VERSION, "valid": errors.is_empty(),
		"errors": errors, "snapshot": get_snapshot(),
		"authority": {"surface_route": false, "navigation": false,
			"movement": false, "terrain": false, "streaming": false,
			"audio": false, "gameplay": false, "save": false, "network": false},
	}.duplicate(true)


func _node_snapshot() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for index in node_ids.size():
		result.append({"node_id": StringName(node_ids[index]),
			"position_body_local_m": node_positions_body_local_m[index] \
				if index < node_positions_body_local_m.size() else Vector3.ZERO,
			"audio_profile_id": StringName(node_audio_profile_ids[index]) \
				if index < node_audio_profile_ids.size() else &""})
	return result.duplicate(true)


func _edge_snapshot() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for index in mini(edge_from_ids.size(), edge_to_ids.size()):
		result.append({"from": StringName(edge_from_ids[index]),
			"to": StringName(edge_to_ids[index])})
	return result.duplicate(true)


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
