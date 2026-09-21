class_name PlanetaryStreamingBootstrap
extends Node3D

## Shared, explicit opt-in orbital placement and streaming composition for one
## planetary body.
##
## This is the world-agnostic half of what `EmberMoonStreamingBootstrap` used to
## be on its own. A host submits absolute focus coordinates and owns every
## rebase decision and node translation. This component only configures the
## immutable datum/frame, registers one body with one private coordinator, and
## requests its fixed load/unload lifecycle. It has no automatic engine
## callback, and it owns no environment presentation of its own: an airless body
## and an atmospheric one bring their own presentation through the hooks below,
## which is exactly the part that must not be shared.
##
## A subclass supplies `_create_profile()` and may override the presentation
## hooks. Everything else — frame configuration, registration, focus
## evaluation, hysteresis, travel observation, rebase re-expression, snapshot
## and audit scaffolding — is identical for every body and lives here.

## The largest residual this root will silently re-express away after a committed
## common-world translation. It is a rounding allowance, not a correction budget.
const ORIGIN_TRANSLATION_ROUNDING_TOLERANCE_M := 0.01

const SCHEMA_VERSION := 1

const PROFILE_KEYS := [
	"location_id",
	"world_id",
	"body_id",
	"display_label",
	"location_resource_path",
	"scene_resource_path",
	"location_definition",
	"location_scene",
	"datum_point_id",
	"navigation_destination_id",
	"body_radius_meters",
	"load_radius_meters",
	"unload_radius_meters",
	"max_active_body_center_distance_meters",
	"origin_shift_threshold_meters",
	"max_observation_speed_meters_per_second",
	"initial_body_center_world_position",
	"expected_sector_id",
	"expected_anchor_source_id",
	"expected_anchor_position",
	"expected_scene_origin_position",
]

const OWNED_CAPABILITY_KEYS := [
	"absolute_orbital_datum",
	"coordinate_frame_configuration",
	"absolute_focus_evaluation",
	"location_registration",
	"streaming_requests",
	"travel_observation_encoding",
]
const ADJACENT_AUTHORITY_KEYS := [
	"automatic_process",
	"rebase_decision",
	"rebase_application",
	"ship_movement",
	"player_movement",
	"game_flow",
	"travel_session_mutation",
	"landing_decision",
	"world_generation",
	"terrain_generation",
	"collision_generation",
	"save",
	"network",
	"space_backdrop",
	"cinder_streaming",
]

var _registry := NearbySectorOrbitalRegistry.new()
var _coordinate_frame := PlanetaryCoordinateFrame.new()
var _coordinator: WorldStreamingCoordinator
var _profile: Dictionary = {}
var _configured := false
var _configuration_error: StringName = &""
var _update_active := false
var _update_count := 0
var _load_attempt_count := 0
var _unload_attempt_count := 0
var _last_update_result: Dictionary = {}
var _last_body_local_focus := Vector3.ZERO
var _last_focus_frame_generation := 0


func _init() -> void:
	set_process(false)
	set_physics_process(false)
	_profile = _create_profile()
	position = _profile.get(
		"initial_body_center_world_position", Vector3.ZERO
	) as Vector3
	_coordinator = WorldStreamingCoordinator.new()
	_coordinator.name = "WorldStreamingCoordinator"
	add_child(_coordinator)
	_coordinator.location_loaded.connect(_on_location_loaded)
	_coordinator.location_load_failed.connect(_on_location_load_failed)
	_coordinator.location_unloaded.connect(_on_location_unloaded)
	_configure_checked_contract()


func _exit_tree() -> void:
	# Main's authored Environment outlives a streamed generation. Restore its
	# exact station baseline before a whole composition detach; re-entry binds it
	# again from the next accepted current-generation sample.
	_retire_environment(&"bootstrap_detached")


# --- subclass seam -----------------------------------------------------------


## Returns this body's immutable identity. Called once, from `_init`.
func _create_profile() -> Dictionary:
	return {}


## Rejects a loaded instance whose script is not this body's authored scene.
func _loaded_instance_is_expected(_instance: Node3D) -> bool:
	return true


## Composes the body's own presentation against the freshly loaded generation.
func _on_generation_loaded(
		_instance: Node3D,
		_frame_generation: int,
		_location_generation: int,
	) -> void:
	pass


func _on_generation_load_failed(_reason: StringName) -> void:
	pass


func _on_generation_unloaded() -> void:
	pass


## Presents one accepted body-local observation through the body's own
## presentation. Returns a detached result dictionary.
func _present_environment(
		_body_local_observer: Vector3,
		_frame_generation: int,
		_location_generation: int,
	) -> Dictionary:
	return {}


## The `update_absolute_focus` result key the presentation result is filed under.
func _environment_result_key() -> String:
	return "environment_presentation"


func _retire_environment(_reason: StringName) -> void:
	pass


## Adds the body's own presentation rows to the shared snapshot.
func _extend_snapshot(_snapshot: Dictionary) -> void:
	pass


## Adds the body's own presentation contract errors.
func _collect_presentation_contract_errors(
		_errors: PackedStringArray,
		_loaded_instance: Node3D,
	) -> void:
	pass


## Returns a configuration error StringName, or `&""` when the body's own
## presentation bindings are intact.
func _validate_presentation_configuration() -> StringName:
	return &""


func _evidence() -> Dictionary:
	return {
		"content_class": &"orbital_streaming_composition",
		"status": &"new",
		"scope": &"modern_interpretation",
		"references": PackedStringArray(),
		"notes": "",
	}


# --- shared API --------------------------------------------------------------


func get_location_id() -> StringName:
	return _profile.get("location_id", &"") as StringName


func get_world_id() -> StringName:
	return _profile.get("world_id", &"") as StringName


func get_body_id() -> StringName:
	return _profile.get("body_id", &"") as StringName


## The authored location definition this body registered. It carries the
## navigation anchor a cruise decodes as its destination, so a cruise binding
## can ask whichever world it is bound to rather than preloading one body's
## `.tres`.
func get_location_definition() -> WorldLocationDefinition:
	return _profile.get("location_definition") as WorldLocationDefinition


## The canonical navigation-anchor identity a cruise destination is decoded
## from: `{source_id, body_local_position}` for this body, empty when the
## bootstrap never configured.
func get_navigation_destination() -> Dictionary:
	var definition := get_location_definition()
	if not _configured or definition == null:
		return {}
	return {
		"location_id": get_location_id(),
		"world_id": get_world_id(),
		"body_id": get_body_id(),
		"destination_id": _profile.get("navigation_destination_id", &"") as StringName,
		"source_id": definition.anchor_source_id,
		"body_local_position_meters": definition.get_anchor_position(),
	}.duplicate(true)


## Returns the exact immutable-config frame instance required by
## PlanetaryTravelSession's identity binding. The caller may use its explicit
## rebase API, but this bootstrap never requests, commits, or applies a rebase.
func get_coordinate_frame_for_session() -> PlanetaryCoordinateFrame:
	return _coordinate_frame if _configured else null


func get_registry_snapshot() -> Dictionary:
	return _registry.get_snapshot()


func get_loaded_instance() -> Node3D:
	return _coordinator.get_loaded_instance(get_location_id()) \
		if _configured and is_instance_valid(_coordinator) else null


## Test/integration seam matching WorldStreamingCoordinator. Replacement is
## allowed only before the first load attempt while this bootstrap owns a live
## scene-tree lifecycle.
func set_scene_loader(loader: Callable) -> bool:
	if not is_inside_tree() or is_queued_for_deletion():
		return false
	if _update_active or not _configured or not is_instance_valid(_coordinator):
		return false
	if int(_coordinator.audit().get("load_request_count", -1)) != 0:
		return false
	return _coordinator.set_loader(loader)


## Evaluates one canonical absolute focus. Distance is radial from the body
## centre. Loading also requires the body centre to be within the bounded local
## streaming envelope, forcing a caller-owned rebase before a distant scene can
## become resident.
func update_absolute_focus(
		orbital_coordinate: Dictionary,
		expected_coordinate_frame_generation: int
	) -> Dictionary:
	if _update_active:
		return _update_result(false, &"update_in_progress")
	# This standalone seam may be called without its production binding. Reject a
	# stale host sample before it can retain a streaming request that would only
	# become visible after this bootstrap re-enters the scene tree.
	if is_queued_for_deletion() or not is_inside_tree():
		return _update_result(false, &"bootstrap_detached")
	_update_active = true
	if not _configured or not is_instance_valid(_coordinator):
		return _finish_update(false, &"bootstrap_not_configured")
	var frame_snapshot := _coordinate_frame.get_snapshot()
	if not (frame_snapshot.get("pending_rebase", {}) as Dictionary).is_empty():
		return _finish_update(false, &"rebase_pending")
	var body_world_result := _body_center_world_position(
		expected_coordinate_frame_generation
	)
	if not bool(body_world_result.get("accepted", false)):
		return _finish_update(
			false, body_world_result.get("reason", &"body_center_out_of_bounds")
		)
	if transform.basis != Basis.IDENTITY or not position.is_equal_approx(
		body_world_result.get("position", Vector3.INF) as Vector3
	):
		return _finish_update(false, &"root_alignment_mismatch")
	var body_result := _coordinate_frame.orbital_to_body_local_position(
		orbital_coordinate, expected_coordinate_frame_generation
	)
	if not bool(body_result.get("accepted", false)):
		return _finish_update(false, body_result.get("reason", &"invalid_focus_coordinate"))
	var body_local := body_result.get("position", Vector3.INF) as Vector3
	var radial_distance := body_local.length()
	if not body_local.is_finite() or not is_finite(radial_distance):
		return _finish_update(false, &"focus_out_of_bounds")
	var body_world := body_world_result.get("position", Vector3.INF) as Vector3
	var body_center_distance := body_world.length()
	if not is_finite(body_center_distance):
		return _finish_update(false, &"body_center_out_of_bounds")
	_last_body_local_focus = body_local
	_last_focus_frame_generation = expected_coordinate_frame_generation

	var location_id := get_location_id()
	var loaded := get_loaded_instance() != null
	var loading := _coordinator.get_loading_ids().has(str(location_id))
	if loaded or loading:
		if radial_distance > float(_profile.get("unload_radius_meters", 0.0)) \
				or body_center_distance > float(_profile.get(
					"max_active_body_center_distance_meters", 0.0
				)):
			_unload_attempt_count += 1
			var unload := _coordinator.request_unload(location_id)
			return _finish_transition(
				unload, &"unload", radial_distance, body_center_distance,
				expected_coordinate_frame_generation
			)
		var presentation := _present_environment(
			body_local,
			expected_coordinate_frame_generation,
			_current_location_generation(),
		)
		return _finish_update(true, &"within_unload_hysteresis", {
			"action": &"none",
			"radial_distance_meters": radial_distance,
			"body_center_world_distance_meters": body_center_distance,
			"coordinate_frame_generation": expected_coordinate_frame_generation,
			"location_generation": _current_location_generation(),
			_environment_result_key(): presentation.duplicate(true),
		})

	if radial_distance <= float(_profile.get("load_radius_meters", 0.0)):
		if body_center_distance > float(_profile.get(
			"max_active_body_center_distance_meters", 0.0
		)):
			return _finish_update(false, &"rebase_required_before_load", {
				"action": &"none",
				"radial_distance_meters": radial_distance,
				"body_center_world_distance_meters": body_center_distance,
				"coordinate_frame_generation": expected_coordinate_frame_generation,
				"location_generation": _current_location_generation(),
			})
		_load_attempt_count += 1
		var load_outcome := _coordinator.request_load(location_id)
		return _finish_transition(
			load_outcome, &"load", radial_distance, body_center_distance,
			expected_coordinate_frame_generation
		)
	return _finish_update(true, &"outside_load_radius", {
		"action": &"none",
		"radial_distance_meters": radial_distance,
		"body_center_world_distance_meters": body_center_distance,
		"coordinate_frame_generation": expected_coordinate_frame_generation,
		"location_generation": _current_location_generation(),
	})


## Produces a detached, exact-current-generation envelope suitable for a caller
## to pass into PlanetaryTravelSession. The session itself is never retained or
## mutated here.
func create_travel_observation(
		world_streaming_position: Vector3,
		speed_meters_per_second: float,
		expected_coordinate_frame_generation: int,
		expected_location_generation: int
	) -> Dictionary:
	if _update_active:
		return _observation_result(false, &"update_in_progress")
	if not _configured or not is_instance_valid(_coordinator):
		return _observation_result(false, &"bootstrap_not_configured")
	if not is_finite(speed_meters_per_second) or speed_meters_per_second < 0.0:
		return _observation_result(false, &"invalid_observation_speed")
	if speed_meters_per_second > float(_profile.get(
		"max_observation_speed_meters_per_second", 0.0
	)):
		return _observation_result(false, &"observation_speed_out_of_bounds")
	var frame_snapshot := _coordinate_frame.get_snapshot()
	if not (frame_snapshot.get("pending_rebase", {}) as Dictionary).is_empty():
		return _observation_result(false, &"rebase_pending")
	var body_world_result := _body_center_world_position(
		expected_coordinate_frame_generation
	)
	if not bool(body_world_result.get("accepted", false)):
		return _observation_result(
			false, body_world_result.get("reason", &"body_center_out_of_bounds")
		)
	if transform.basis != Basis.IDENTITY or not position.is_equal_approx(
		body_world_result.get("position", Vector3.INF) as Vector3
	):
		return _observation_result(false, &"root_alignment_mismatch")
	var instance := get_loaded_instance()
	var current_location_generation := _current_location_generation()
	if not is_instance_valid(instance):
		return _observation_result(false, _not_loaded_reason())
	if expected_location_generation != current_location_generation \
			or int(instance.get_meta(&"world_location_generation", -1)) \
			!= expected_location_generation:
		return _observation_result(false, &"stale_location_generation")
	var decoded := _coordinate_frame.decode_world_streaming_position(
		world_streaming_position, expected_coordinate_frame_generation
	)
	if not bool(decoded.get("accepted", false)):
		return _observation_result(
			false, decoded.get("reason", &"invalid_world_streaming_position")
		)
	var coordinate_record := decoded.get("coordinate", {}) as Dictionary
	return _observation_result(true, &"current_generation_observation", {
		"world_id": get_world_id(),
		"body_id": get_body_id(),
		"location_id": get_location_id(),
		"location_generation": current_location_generation,
		"coordinate_frame_generation": expected_coordinate_frame_generation,
		"orbital_coordinate": (
			coordinate_record.get("orbital_coordinate", {}) as Dictionary
		).duplicate(true),
		"world_streaming_position_meters": coordinate_record.get(
			"world_streaming_position", Vector3.INF
		),
		"body_local_position_meters": coordinate_record.get(
			"planetary_body_local_position", Vector3.INF
		),
		"radial_distance_meters": (
			coordinate_record.get("planetary_body_local_position", Vector3.INF) as Vector3
		).length(),
		"altitude_meters": coordinate_record.get("altitude_meters", INF),
		"speed_meters_per_second": speed_meters_per_second,
	})


func get_snapshot() -> Dictionary:
	var location_id := get_location_id()
	var registered_definition := _coordinator.get_definition(location_id) \
		if is_instance_valid(_coordinator) else null
	var loaded_instance := get_loaded_instance()
	var snapshot := {
		"schema_version": SCHEMA_VERSION,
		"configured": _configured,
		"configuration_error": _configuration_error,
		"location_id": location_id,
		"world_id": get_world_id(),
		"body_id": get_body_id(),
		"location_resource_path": _profile.get("location_resource_path", ""),
		"scene_resource_path": _profile.get("scene_resource_path", ""),
		"load_radius_meters": _profile.get("load_radius_meters", 0.0),
		"unload_radius_meters": _profile.get("unload_radius_meters", 0.0),
		"maximum_active_body_center_distance_meters": _profile.get(
			"max_active_body_center_distance_meters", 0.0
		),
		"navigation_anchor_body_local_meters": registered_definition.get_anchor_position() \
			if registered_definition != null else Vector3.INF,
		"scene_origin_body_local_meters": registered_definition.get_scene_origin_position() \
			if registered_definition != null else Vector3.INF,
		"root_streaming_position_meters": position,
		"coordinate_frame": _coordinate_frame.get_snapshot(),
		"registry": _registry.get_snapshot(),
		"coordinator": _coordinator.audit() if is_instance_valid(_coordinator) else {},
		"loaded_instance_id": loaded_instance.get_instance_id() \
			if is_instance_valid(loaded_instance) else 0,
		"location_generation": _current_location_generation(),
		"update_count": _update_count,
		"load_attempt_count": _load_attempt_count,
		"unload_attempt_count": _unload_attempt_count,
		"last_update_result": _last_update_result.duplicate(true),
	}
	_extend_snapshot(snapshot)
	return snapshot.duplicate(true)


## Caller cadence needs current validity, not a detached diagnostic history.
## Keep mutable frame, registration, topology, transform and presentation checks
## live on every call. Only the stateless registry's configured datum is reused;
## audit() still independently checks it and produces the full report.
func is_runtime_contract_valid() -> bool:
	return _collect_contract_errors(false).is_empty()


func _collect_contract_errors(
		check_immutable_registry: bool = true
	) -> PackedStringArray:
	var errors := PackedStringArray()
	var label := String(_profile.get("display_label", "body"))
	var location_id := get_location_id()
	var frame_valid := _coordinate_frame.is_runtime_contract_valid()
	# Reconcile resident lifetimes before inspecting registration and presentation,
	# as the previous coordinator audit did before returning its report.
	if is_instance_valid(_coordinator):
		_coordinator.get_loaded_ids()
	var registered_ids := _coordinator.get_registered_ids() \
		if is_instance_valid(_coordinator) else PackedStringArray()
	var definition := _coordinator.get_definition(location_id) \
		if is_instance_valid(_coordinator) else null
	if not _configured:
		errors.append("checked %s orbital streaming contract is not configured: %s" % [
			label, _configuration_error,
		])
	# The registry has no mutable state; configuration already validates its datum.
	if check_immutable_registry and not bool(_registry.audit().get("valid", false)):
		errors.append("nearby-sector orbital registry is invalid")
	if not frame_valid:
		errors.append("%s coordinate frame is invalid" % label)
	if not is_instance_valid(_coordinator) or _coordinator.get_parent() != self \
			or get_child_count() != 1:
		errors.append("exactly one private child coordinator is required")
	if registered_ids != PackedStringArray([str(location_id)]):
		errors.append("coordinator must retain exactly the %s registration" % label)
	if definition == null or not definition.is_definition_valid() \
			or definition.location_id != location_id \
			or definition.sector_id != _profile.get("expected_sector_id", &"") \
			or definition.anchor_source_id != _profile.get(
				"expected_anchor_source_id", &""
			) \
			or definition.get_anchor_position() != _profile.get(
				"expected_anchor_position", Vector3.INF
			) \
			or definition.get_scene_origin_position() != _profile.get(
				"expected_scene_origin_position", Vector3.INF
			):
		errors.append("registered %s location definition diverged" % label)
	var generation := _coordinate_frame.get_generation()
	if generation > 0 and not _root_is_aligned(generation):
		errors.append("bootstrap root is not aligned to the current streaming origin")
	var loaded_instance := get_loaded_instance()
	if is_instance_valid(loaded_instance) \
			and loaded_instance.transform != Transform3D.IDENTITY:
		errors.append(
			"loaded %s scene root must remain body-centred and locally identity" % label
		)
	_collect_presentation_contract_errors(errors, loaded_instance)
	return errors


func audit() -> Dictionary:
	var errors := _collect_contract_errors()
	var owned_capabilities := {}
	for key in OWNED_CAPABILITY_KEYS:
		owned_capabilities[key] = true
	var adjacent_authority := {}
	for key in ADJACENT_AUTHORITY_KEYS:
		adjacent_authority[key] = false
	return {
		"schema_version": SCHEMA_VERSION,
		"valid": errors.is_empty(),
		"errors": errors,
		"snapshot": get_snapshot(),
		"evidence": _evidence(),
		"owned_capabilities": owned_capabilities,
		"adjacent_authority": adjacent_authority,
	}.duplicate(true)


func _configure_checked_contract() -> void:
	for key in PROFILE_KEYS:
		if not _profile.has(key):
			_configuration_error = &"incomplete_body_profile"
			return
	var registry_report := _registry.audit()
	if not bool(registry_report.get("valid", false)):
		_configuration_error = &"invalid_orbital_registry"
		return
	var body_coordinate := _registry.get_coordinate(
		_profile.get("datum_point_id", &"") as StringName
	)
	if body_coordinate.is_empty():
		_configuration_error = &"unknown_body_datum"
		return
	var station_coordinate := _registry.get_coordinate(
		NearbySectorOrbitalRegistry.STATION_DATUM_ID
	)
	var configured := _coordinate_frame.configure(
		get_body_id(),
		float(_profile.get("body_radius_meters", 0.0)),
		NearbySectorOrbitalRegistry.FRAME_ID,
		NearbySectorOrbitalRegistry.CELL_SIZE_METERS,
		body_coordinate,
		Vector3.UP,
		Vector3.FORWARD,
		float(_profile.get("origin_shift_threshold_meters", 0.0)),
		station_coordinate
	)
	if not bool(configured.get("accepted", false)):
		_configuration_error = &"coordinate_frame_configuration_failed"
		return
	var definition := _profile.get("location_definition") as WorldLocationDefinition
	var scene := _profile.get("location_scene") as PackedScene
	var presentation_error := _validate_presentation_configuration()
	if not presentation_error.is_empty():
		_configuration_error = presentation_error
		return
	if definition == null or not definition.is_definition_valid() \
			or definition.location_id != get_location_id() \
			or definition.get_anchor_position() != _profile.get(
				"expected_anchor_position", Vector3.INF
			) \
			or definition.get_scene_origin_position() != _profile.get(
				"expected_scene_origin_position", Vector3.INF
			):
		_configuration_error = &"location_contract_mismatch"
		return
	if scene == null or not _coordinator.register_location(definition, scene):
		_configuration_error = &"location_registration_failed"
		return
	_configured = true


func _on_location_loaded(
		location_id: StringName,
		generation: int,
		instance: Node3D,
	) -> void:
	if location_id != get_location_id() or not _loaded_instance_is_expected(instance):
		return
	_on_generation_loaded(instance, _coordinate_frame.get_generation(), generation)


func _on_location_load_failed(
		location_id: StringName,
		_generation: int,
		reason: StringName,
	) -> void:
	if location_id == get_location_id():
		_on_generation_load_failed(reason)


func _on_location_unloaded(
		location_id: StringName,
		_generation: int,
	) -> void:
	if location_id == get_location_id():
		_on_generation_unloaded()


## The observation rejection reason used while the body is not resident.
func _not_loaded_reason() -> StringName:
	return StringName("%s_not_loaded" % String(get_location_id()))


func _body_center_world_position(expected_generation: int) -> Dictionary:
	var body_coordinate := _registry.get_coordinate(
		_profile.get("datum_point_id", &"") as StringName
	)
	return _coordinate_frame.orbital_to_world_streaming_position(
		body_coordinate, expected_generation
	)


## `CommonWorldOriginRebaseOwner` calls this once per committed transaction, only
## on nodes it actually translated, and only after the commit is irreversible.
##
## The owner translates every covered root by one identical delta. Over a
## multi-thousand-kilometre delta that leaves sub-millimetre rounding in the
## near-zero components of this root's position, and both
## `update_absolute_focus()` and the caller's own checks compare it to the exact
## body centre the frame defines — the latter *after* the next transaction's
## frame commit is already irreversible, which is how a second expedition used to
## lose the rebase its descent needs. Re-expressing the root at that exact
## position removes only the rounding the translation just introduced: a
## displacement beyond a centimetre is left alone, because that is a real move
## and not this seam's business.
func notify_common_world_translation(
		delta: Vector3,
		target_coordinate_frame_generation: int = 0,
	) -> void:
	if not delta.is_finite() or not _configured \
			or target_coordinate_frame_generation < 1 \
			or transform.basis != Basis.IDENTITY:
		return
	var expected := _body_center_world_position(target_coordinate_frame_generation)
	if not bool(expected.get("accepted", false)):
		return
	var exact := expected.get("position", Vector3.INF) as Vector3
	if not exact.is_finite() \
			or position.distance_to(exact) > ORIGIN_TRANSLATION_ROUNDING_TOLERANCE_M:
		return
	position = exact


func _root_is_aligned(expected_generation: int) -> bool:
	if transform.basis != Basis.IDENTITY:
		return false
	var expected := _body_center_world_position(expected_generation)
	return bool(expected.get("accepted", false)) \
		and position.is_equal_approx(expected.get("position", Vector3.INF) as Vector3)


func _current_location_generation() -> int:
	if not is_instance_valid(_coordinator):
		return -1
	var generations := _coordinator.audit().get("generation_by_id", {}) as Dictionary
	return int(generations.get(get_location_id(), -1))


func _finish_transition(
		outcome: Dictionary,
		action: StringName,
		radial_distance: float,
		body_center_distance: float,
		frame_generation: int
	) -> Dictionary:
	return _finish_update(bool(outcome.get("accepted", false)), outcome.get(
		"reason", &"streaming_request_rejected"
	), {
		"action": action,
		"radial_distance_meters": radial_distance,
		"body_center_world_distance_meters": body_center_distance,
		"coordinate_frame_generation": frame_generation,
		"location_generation": int(outcome.get(
			"generation", _current_location_generation()
		)),
		"coordinator_outcome": outcome.duplicate(true),
	})


func _finish_update(
		accepted: bool,
		reason: StringName,
		extra: Dictionary = {}
	) -> Dictionary:
	_update_count += 1
	var result := _update_result(accepted, reason, extra)
	_last_update_result = result.duplicate(true)
	_update_active = false
	return result


func _update_result(
		accepted: bool,
		reason: StringName,
		extra: Dictionary = {}
	) -> Dictionary:
	var result := {"accepted": accepted, "reason": reason}
	for key: Variant in extra:
		result[key] = extra[key]
	return result.duplicate(true)


func _observation_result(
		accepted: bool,
		reason: StringName,
		extra: Dictionary = {}
	) -> Dictionary:
	var result := {"accepted": accepted, "reason": reason}
	for key: Variant in extra:
		result[key] = extra[key]
	return result.duplicate(true)


func _presentation_result(
		accepted: bool,
		reason: StringName,
		extra: Dictionary = {},
	) -> Dictionary:
	var result := {"accepted": accepted, "reason": reason}
	for key: Variant in extra:
		result[key] = extra[key]
	return result.duplicate(true)
