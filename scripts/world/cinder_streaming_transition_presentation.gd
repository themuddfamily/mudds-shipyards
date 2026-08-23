class_name CinderStreamingTransitionPresentation
extends RefCounted

## Renderer-only, caller-physics presentation envelope for one streamed Cinder
## generation. It never mutates materials or collision and never requests a
## streaming transition. The production binding remains the sole caller.

const SCHEMA_VERSION := 1
const LOCATION_ID: StringName = &"cinder_reach"
const LOAD_BOUNDARY_METERS := 500.0
const UNLOAD_BOUNDARY_METERS := 650.0
const FADE_IN_SECONDS := 0.5
const FADE_OUT_SECONDS := 0.5
const MAX_RETAINED_DISTANCE_METERS := 725.0
const EXPECTED_AUTHORED_RENDERER_COUNT := 223
const EXPECTED_BOUND_RENDERER_COUNT := 224
const EXPECTED_LIGHT_COUNT := 27
const EPSILON := 0.000001
const APERTURE_LENS_BATCH_NAME: StringName = &"StreamingApertureLensBatch"
const APERTURE_LENS_FAMILY_ID: StringName = &"cinder-streaming-aperture-lenses"
const APERTURE_FRAME_PATHS: Array[NodePath] = [
	^"ExtractionPlatform/CinderReachPlatform/GantryFrame1",
	^"ExtractionPlatform/CinderReachPlatform/GantryFrame2",
]

var _content_root: Node3D
var _generation := -1
var _bound := false
var _opacity := 1.0
var _phase: StringName = &"unbound"
var _phase_elapsed_seconds := 0.0
var _phase_start_opacity := 1.0
var _advance_count := 0
var _last_distance_meters := 0.0
var _retire_ready := false
var _mutation_active := false
var _renderers: Array[Dictionary] = []
var _lights: Array[Dictionary] = []


func bind_streamed_content(content_root: Node3D, generation: int) -> Dictionary:
	if _mutation_active:
		return _result(false, &"reentrant_call")
	if _bound:
		return _result(false, &"already_bound")
	if not is_instance_valid(content_root):
		return _result(false, &"invalid_content_root")
	if content_root.is_queued_for_deletion() or not content_root.is_inside_tree():
		return _result(false, &"content_root_detached")
	if generation <= 0 \
		or int(content_root.get_meta(&"world_location_generation", -1)) != generation \
		or content_root.get_meta(&"world_location_id", &"") != LOCATION_ID:
		return _result(false, &"invalid_streaming_identity")
	var renderers := content_root.find_children(
		"*", "GeometryInstance3D", true, false
	)
	var lights := content_root.find_children("*", "Light3D", true, false)
	if renderers.size() != EXPECTED_AUTHORED_RENDERER_COUNT:
		content_root.visible = false
		return _result(false, &"renderer_roster_mismatch")
	if lights.size() != EXPECTED_LIGHT_COUNT:
		content_root.visible = false
		return _result(false, &"light_roster_mismatch")
	var aperture_lens_family := _validate_aperture_lens_family(content_root)
	if aperture_lens_family.is_empty():
		content_root.visible = false
		return _result(false, &"aperture_lens_family_mismatch")

	_mutation_active = true
	var aperture_lens_batch := _build_aperture_lens_batch(
		content_root, aperture_lens_family
	)
	renderers.append(aperture_lens_batch)
	_content_root = content_root
	_generation = generation
	_renderers.clear()
	_lights.clear()
	for candidate in renderers:
		var renderer := candidate as GeometryInstance3D
		_renderers.append({
			"node": renderer,
			"authored_transparency": renderer.transparency,
			"authored_cast_shadow": renderer.cast_shadow,
		})
	for candidate in lights:
		var light := candidate as Light3D
		_lights.append({
			"node": light,
			"authored_energy": light.light_energy,
		})
	_bound = true
	_opacity = 0.0
	_phase = &"fading_in"
	_phase_elapsed_seconds = 0.0
	_phase_start_opacity = 0.0
	_advance_count = 0
	_last_distance_meters = LOAD_BOUNDARY_METERS
	_retire_ready = false
	_apply_opacity()
	_mutation_active = false
	return _result(true, &"bound_hidden")


## Advances only from a validated caller physics sample. At and inside 650 m a
## partial fade reverses toward the authored state. Outside 650 m it fades to
## zero before reporting retire_ready on one subsequent still-outside tick.
func advance_physics(
	delta: Variant,
	distance_to_anchor_meters: Variant,
	expected_generation: Variant
	) -> Dictionary:
	if _mutation_active:
		return _result(false, &"reentrant_call")
	if not _bound or not is_instance_valid(_content_root):
		return _result(false, &"not_bound")
	if _content_root.is_queued_for_deletion() or not _content_root.is_inside_tree():
		return _result(false, &"content_root_detached")
	if typeof(expected_generation) != TYPE_INT \
		or int(expected_generation) != _generation:
		return _result(false, &"stale_generation")
	if not _is_finite_number(delta) or float(delta) < 0.0:
		return _result(false, &"invalid_delta")
	if not _is_finite_number(distance_to_anchor_meters) \
		or float(distance_to_anchor_meters) < 0.0:
		return _result(false, &"invalid_distance")

	_mutation_active = true
	var step := float(delta)
	var distance := float(distance_to_anchor_meters)
	_last_distance_meters = distance
	_advance_count += 1
	_retire_ready = false
	if distance <= UNLOAD_BOUNDARY_METERS:
		if _phase == &"fading_out" or _phase == &"fade_out_complete":
			_begin_phase(&"fading_in", _opacity)
		if _phase == &"fading_in":
			_phase_elapsed_seconds = minf(
				_phase_elapsed_seconds + step, FADE_IN_SECONDS
			)
			var t := _smooth_unit(_phase_elapsed_seconds / FADE_IN_SECONDS)
			_opacity = lerpf(_phase_start_opacity, 1.0, t)
			if _phase_elapsed_seconds >= FADE_IN_SECONDS - EPSILON:
				_opacity = 1.0
				_phase = &"authored"
		else:
			_opacity = 1.0
			_phase = &"authored"
	else:
		if _phase == &"fade_out_complete":
			_retire_ready = true
		elif distance >= MAX_RETAINED_DISTANCE_METERS:
			_opacity = 0.0
			_phase = &"fade_out_complete"
			_phase_elapsed_seconds = FADE_OUT_SECONDS
		elif _phase != &"fading_out":
			_begin_phase(&"fading_out", _opacity)
		if _phase == &"fading_out":
			_phase_elapsed_seconds = minf(
				_phase_elapsed_seconds + step, FADE_OUT_SECONDS
			)
			var t := _smooth_unit(_phase_elapsed_seconds / FADE_OUT_SECONDS)
			_opacity = lerpf(_phase_start_opacity, 0.0, t)
			if _phase_elapsed_seconds >= FADE_OUT_SECONDS - EPSILON:
				_opacity = 0.0
				_phase = &"fade_out_complete"
	_apply_opacity()
	_mutation_active = false
	return _result(true, &"advanced")


func scale_dynamic_light_energy(authored_energy: float) -> float:
	if not is_finite(authored_energy) or authored_energy < 0.0:
		return 0.0
	return authored_energy * _opacity if _bound else authored_energy


func get_snapshot() -> Dictionary:
	return {
		"schema_version": SCHEMA_VERSION,
		"bound": _bound and is_instance_valid(_content_root),
		"location_id": LOCATION_ID,
		"generation": _generation,
		"opacity": _opacity,
		"phase": _phase,
		"phase_elapsed_seconds": _phase_elapsed_seconds,
		"phase_start_opacity": _phase_start_opacity,
		"advance_count": _advance_count,
		"last_distance_meters": _last_distance_meters,
		"retire_ready": _retire_ready,
		"root_visible": _content_root.visible \
			if is_instance_valid(_content_root) else false,
		"renderer_count": _renderers.size(),
		"light_count": _lights.size(),
		"load_boundary_meters": LOAD_BOUNDARY_METERS,
		"unload_boundary_meters": UNLOAD_BOUNDARY_METERS,
		"fade_in_seconds": FADE_IN_SECONDS,
		"fade_out_seconds": FADE_OUT_SECONDS,
		"maximum_retained_distance_meters": MAX_RETAINED_DISTANCE_METERS,
		"equation": &"smoothstep_time_phases_authored_through_unload_boundary",
	}.duplicate(true)


func audit() -> Dictionary:
	var errors := PackedStringArray()
	if not _bound or not is_instance_valid(_content_root):
		errors.append("one live streamed content root is required")
	if _renderers.size() != EXPECTED_BOUND_RENDERER_COUNT:
		errors.append("renderer roster drifted")
	if _lights.size() != EXPECTED_LIGHT_COUNT:
		errors.append("light roster drifted")
	if not is_finite(_opacity) or _opacity < 0.0 or _opacity > 1.0:
		errors.append("opacity is outside the unit interval")
	for record in _renderers:
		var renderer := record.get("node") as GeometryInstance3D
		if not is_instance_valid(renderer):
			errors.append("renderer baseline target was freed")
			break
		var authored := float(record.get("authored_transparency", -1.0))
		var expected := 1.0 - (1.0 - authored) * _opacity
		if not is_equal_approx(renderer.transparency, expected):
			errors.append("renderer transparency drifted")
			break
		var authored_shadow := int(record.get("authored_cast_shadow", -1))
		var expected_shadow := authored_shadow if _opacity >= 1.0 else (
			GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		)
		if renderer.cast_shadow != expected_shadow:
			errors.append("renderer shadow state drifted")
			break
	for record in _lights:
		var light := record.get("node") as Light3D
		if not is_instance_valid(light):
			errors.append("light baseline target was freed")
			break
		var expected_energy := float(record.get("authored_energy", -1.0)) * _opacity
		# Pulsing authored lights are refreshed from raw energy in the cluster's
		# process callback, so only static lights have a fixed audit expectation.
		if not light.has_meta(&"pulse_phase") \
			and not is_equal_approx(light.light_energy, expected_energy):
			errors.append("static light energy drifted")
			break
	var expected_visible := (
		bool(_content_root.call(&"is_cluster_enabled")) and _opacity > 0.0
		if is_instance_valid(_content_root)
		and _content_root.has_method(&"is_cluster_enabled")
		else _opacity > 0.0
	)
	if is_instance_valid(_content_root) and _content_root.visible != expected_visible:
		errors.append("root visibility drifted")
	return {
		"schema_version": SCHEMA_VERSION,
		"valid": errors.is_empty(),
		"errors": errors,
		"snapshot": get_snapshot(),
		"material_mutation": false,
		"material_duplication": false,
		"collision_mutation": false,
		"automatic_processing": false,
		"streaming_authority": false,
		"gameplay_authority": false,
		"save_authority": false,
		"network_authority": false,
	}.duplicate(true)


func _begin_phase(next_phase: StringName, start_opacity: float) -> void:
	_phase = next_phase
	_phase_elapsed_seconds = 0.0
	_phase_start_opacity = start_opacity
	_retire_ready = false


func _apply_opacity() -> void:
	if not is_instance_valid(_content_root):
		return
	var cluster_enabled := true
	if _content_root.has_method(&"is_cluster_enabled"):
		cluster_enabled = bool(_content_root.call(&"is_cluster_enabled"))
	_content_root.visible = cluster_enabled and _opacity > 0.0
	for record in _renderers:
		var renderer := record.get("node") as GeometryInstance3D
		if not is_instance_valid(renderer):
			continue
		var authored := float(record.get("authored_transparency", 0.0))
		renderer.transparency = 1.0 - (1.0 - authored) * _opacity
		renderer.cast_shadow = (
			int(record.get("authored_cast_shadow", 0))
			if _opacity >= 1.0
			else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		)
	for record in _lights:
		var light := record.get("node") as Light3D
		if is_instance_valid(light):
			light.light_energy = float(record.get("authored_energy", 0.0)) * _opacity


## The eight dock-aperture lenses are one immutable mesh/material recipe and
## carry no collision, navigation, activity state, or animation. Their authored
## MeshInstance paths stay present as hidden semantic identities; this streamed
## generation draws their exact transforms through one bounded submission.
func _validate_aperture_lens_family(content_root: Node3D) -> Array[MeshInstance3D]:
	var family: Array[MeshInstance3D] = []
	var exemplar: MeshInstance3D
	for frame_path in APERTURE_FRAME_PATHS:
		var frame := content_root.get_node_or_null(frame_path) as Node3D
		if frame == null:
			return []
		var frame_lens_count := 0
		for child in frame.get_children():
			var lens := child as MeshInstance3D
			if lens == null or not lens.mesh is SphereMesh:
				continue
			frame_lens_count += 1
			if not lens.get_children().is_empty():
				return []
			if exemplar == null:
				exemplar = lens
			elif lens.mesh != exemplar.mesh \
				or lens.material_override != exemplar.material_override \
				or lens.material_overlay != exemplar.material_overlay \
				or lens.cast_shadow != exemplar.cast_shadow \
				or lens.layers != exemplar.layers \
				or lens.transparency != exemplar.transparency \
				or lens.visibility_range_begin != exemplar.visibility_range_begin \
				or lens.visibility_range_end != exemplar.visibility_range_end \
				or lens.visibility_range_begin_margin != exemplar.visibility_range_begin_margin \
				or lens.visibility_range_end_margin != exemplar.visibility_range_end_margin \
				or lens.visibility_range_fade_mode != exemplar.visibility_range_fade_mode \
				or lens.extra_cull_margin != exemplar.extra_cull_margin \
				or lens.ignore_occlusion_culling != exemplar.ignore_occlusion_culling \
				or lens.gi_mode != exemplar.gi_mode \
				or lens.lod_bias != exemplar.lod_bias:
				return []
			family.append(lens)
		if frame_lens_count != 4:
			return []
	return family


func _build_aperture_lens_batch(
		content_root: Node3D, family: Array[MeshInstance3D]
	) -> MultiMeshInstance3D:
	var platform := content_root.get_node(
		^"ExtractionPlatform/CinderReachPlatform"
	) as Node3D
	var exemplar := family[0]
	var transforms: Array[Transform3D] = []
	var bounds := AABB()
	var has_bounds := false
	var platform_inverse := platform.global_transform.affine_inverse()
	for lens in family:
		var instance_transform := platform_inverse * lens.global_transform
		transforms.append(instance_transform)
		var instance_bounds := instance_transform * exemplar.mesh.get_aabb()
		bounds = bounds.merge(instance_bounds) if has_bounds else instance_bounds
		has_bounds = true

	var multi := MultiMesh.new()
	multi.transform_format = MultiMesh.TRANSFORM_3D
	multi.mesh = exemplar.mesh
	multi.instance_count = transforms.size()
	for index in transforms.size():
		multi.set_instance_transform(index, transforms[index])
	multi.custom_aabb = bounds

	var batch := MultiMeshInstance3D.new()
	batch.name = APERTURE_LENS_BATCH_NAME
	batch.multimesh = multi
	batch.material_override = exemplar.material_override
	batch.material_overlay = exemplar.material_overlay
	batch.cast_shadow = exemplar.cast_shadow
	batch.layers = exemplar.layers
	batch.transparency = exemplar.transparency
	batch.visibility_range_begin = exemplar.visibility_range_begin
	batch.visibility_range_end = exemplar.visibility_range_end
	batch.visibility_range_begin_margin = exemplar.visibility_range_begin_margin
	batch.visibility_range_end_margin = exemplar.visibility_range_end_margin
	batch.visibility_range_fade_mode = exemplar.visibility_range_fade_mode
	batch.extra_cull_margin = exemplar.extra_cull_margin
	batch.ignore_occlusion_culling = exemplar.ignore_occlusion_culling
	batch.gi_mode = exemplar.gi_mode
	batch.lod_bias = exemplar.lod_bias
	batch.set_meta(&"visual_batch_family_id", APERTURE_LENS_FAMILY_ID)
	batch.set_meta(&"authored_instance_transforms", transforms.duplicate())
	var source_paths: Array[NodePath] = []
	for lens in family:
		source_paths.append(content_root.get_path_to(lens))
	batch.set_meta(&"semantic_source_paths", source_paths)
	platform.add_child(batch)
	for lens in family:
		lens.visible = false
	return batch


func _result(accepted: bool, reason: StringName) -> Dictionary:
	return {
		"accepted": accepted,
		"reason": reason,
		"generation": _generation,
		"opacity": _opacity,
		"phase": _phase,
		"retire_ready": _retire_ready,
	}.duplicate(true)


func _smooth_unit(value: float) -> float:
	var t := clampf(value, 0.0, 1.0)
	return t * t * (3.0 - 2.0 * t)


func _is_finite_number(value: Variant) -> bool:
	return (typeof(value) == TYPE_FLOAT or typeof(value) == TYPE_INT) \
		and is_finite(float(value))
