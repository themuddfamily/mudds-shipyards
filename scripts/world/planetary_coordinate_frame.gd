class_name PlanetaryCoordinateFrame
extends RefCounted

## Deterministic, authority-free planetary coordinate and floating-origin policy.
##
## One Godot world unit is one metre. Planetary-body local and world-streaming
## positions are bounded relative Vector3 values. Orbital positions use a
## canonical integer-cell plus metre-offset record so nearby sub-metre offsets
## survive even when the system-wide cell identity is very large. Absolute
## orbital coordinates do not carry an origin generation; local mappings do.
##
## The configured surface tangent frame is affine at one surface reference:
## +X east, +Y radial up, +Z south (-Z north). Radial altitude is reported
## separately and is not silently equated with tangent Y away from the reference.
##
## Rebasing is two-step. [method request_rebase] freezes a generation-stamped
## proposal; [method commit_rebase] advances the local mapping and returns a
## translation delta that a caller may choose to apply. This class never moves a
## node or invokes rendering, physics, streaming, gameplay, save, or networking.

const SCHEMA_VERSION := 1
const COORDINATE_SCHEMA_VERSION := 1
const METERS_PER_WORLD_UNIT := 1.0
const MIN_BODY_RADIUS_METERS := 1.0
const MAX_BODY_RADIUS_METERS := 100_000_000.0
const MIN_ORBITAL_CELL_SIZE_METERS := 1.0
const MAX_ORBITAL_CELL_SIZE_METERS := 1_000_000_000.0
const MIN_ORIGIN_SHIFT_THRESHOLD_METERS := 1.0
const MAX_ORIGIN_SHIFT_THRESHOLD_METERS := 10_000_000.0
const MAX_LOCAL_COMPONENT_METERS := 1_000_000_000.0
const MAX_SAFE_INTEGER := 9_007_199_254_740_991
const MAX_GENERATION := MAX_SAFE_INTEGER
const MIN_TANGENT_AXIS_LENGTH := 0.000001

const FRAME_BODY_LOCAL: StringName = &"planetary_body_local"
const FRAME_SURFACE_TANGENT: StringName = &"surface_tangent"
const FRAME_ORBITAL: StringName = &"orbital"
const FRAME_WORLD_STREAMING: StringName = &"world_streaming"

const _COORDINATE_KEYS := [
	"schema_version",
	"frame_id",
	"cell_x",
	"cell_y",
	"cell_z",
	"offset_meters",
]

var _configured := false
var _body_id: StringName = &""
var _orbital_frame_id: StringName = &""
var _body_radius_meters := 0.0
var _orbital_cell_size_meters := 0.0
var _body_center_orbital_coordinate: Dictionary = {}
var _surface_reference_direction := Vector3.ZERO
var _surface_reference_body_local := Vector3.ZERO
var _surface_north_direction := Vector3.ZERO
var _surface_tangent_basis := Basis.IDENTITY
var _origin_shift_threshold_meters := 0.0
var _world_streaming_origin_orbital_coordinate: Dictionary = {}
var _generation := 0
var _next_rebase_request_id := 1
var _pending_rebase: Dictionary = {}
var _last_rebase_result: Dictionary = {}
var _rebase_request_count := 0
var _rebase_commit_count := 0
var _rebase_cancel_count := 0


## Configures one immutable body/tangent/orbital frame and initial streaming
## origin. Orbital coordinate dictionaries are strict: exact keys, an exact
## StringName frame ID, safe integer cells, and canonical half-open offsets.
func configure(
		body_id: StringName,
		body_radius_meters: float,
		orbital_frame_id: StringName,
		orbital_cell_size_meters: float,
		body_center_orbital_coordinate: Dictionary,
		surface_reference_direction: Vector3,
		surface_north_hint: Vector3,
		origin_shift_threshold_meters: float,
		world_streaming_origin_orbital_coordinate: Dictionary
	) -> Dictionary:
	if _configured:
		return _result(false, &"already_configured")
	if not _is_stable_id(str(body_id)):
		return _result(false, &"invalid_body_id")
	if not _is_stable_id(str(orbital_frame_id)):
		return _result(false, &"invalid_orbital_frame_id")
	if not is_finite(body_radius_meters) \
		or body_radius_meters < MIN_BODY_RADIUS_METERS \
		or body_radius_meters > MAX_BODY_RADIUS_METERS:
		return _result(false, &"invalid_body_radius")
	if not is_finite(orbital_cell_size_meters) \
		or orbital_cell_size_meters < MIN_ORBITAL_CELL_SIZE_METERS \
		or orbital_cell_size_meters > MAX_ORBITAL_CELL_SIZE_METERS:
		return _result(false, &"invalid_orbital_cell_size")
	if not is_finite(origin_shift_threshold_meters) \
		or origin_shift_threshold_meters < MIN_ORIGIN_SHIFT_THRESHOLD_METERS \
		or origin_shift_threshold_meters > MAX_ORIGIN_SHIFT_THRESHOLD_METERS \
		or origin_shift_threshold_meters > MAX_LOCAL_COMPONENT_METERS:
		return _result(false, &"invalid_origin_shift_threshold")
	var body_coordinate_validation := _validate_coordinate_contract(
		body_center_orbital_coordinate,
		orbital_frame_id,
		orbital_cell_size_meters
	)
	if not bool(body_coordinate_validation.get("accepted", false)):
		return _result(false, &"invalid_body_center_coordinate", {
			"coordinate_reason": body_coordinate_validation.get(
				"reason", &"invalid_coordinate"
			),
		})
	var origin_validation := _validate_coordinate_contract(
		world_streaming_origin_orbital_coordinate,
		orbital_frame_id,
		orbital_cell_size_meters
	)
	if not bool(origin_validation.get("accepted", false)):
		return _result(false, &"invalid_streaming_origin_coordinate", {
			"coordinate_reason": origin_validation.get(
				"reason", &"invalid_coordinate"
			),
		})
	if not _is_finite_nonzero_vector(surface_reference_direction):
		return _result(false, &"invalid_surface_reference")
	if not _is_finite_nonzero_vector(surface_north_hint):
		return _result(false, &"invalid_surface_north_hint")

	var surface_up := surface_reference_direction.normalized()
	var north_projection := surface_north_hint \
		- surface_up * surface_north_hint.dot(surface_up)
	if north_projection.length() < MIN_TANGENT_AXIS_LENGTH:
		return _result(false, &"degenerate_surface_north_hint")
	var surface_north := north_projection.normalized()
	var surface_east := surface_north.cross(surface_up).normalized()
	var surface_south := -surface_north
	var tangent_basis := Basis(surface_east, surface_up, surface_south)
	var surface_reference := surface_up * body_radius_meters
	if not _is_bounded_local_vector(surface_reference) \
		or not _is_valid_tangent_basis(tangent_basis):
		return _result(false, &"invalid_surface_tangent_basis")

	_configured = true
	_body_id = body_id
	_orbital_frame_id = orbital_frame_id
	_body_radius_meters = body_radius_meters
	_orbital_cell_size_meters = orbital_cell_size_meters
	_body_center_orbital_coordinate = (
		body_coordinate_validation.get("coordinate", {}) as Dictionary
	).duplicate(true)
	_surface_reference_direction = surface_up
	_surface_reference_body_local = surface_reference
	_surface_north_direction = surface_north
	_surface_tangent_basis = tangent_basis
	_origin_shift_threshold_meters = origin_shift_threshold_meters
	_world_streaming_origin_orbital_coordinate = (
		origin_validation.get("coordinate", {}) as Dictionary
	).duplicate(true)
	_generation = 1
	return _result(true, &"configured", {"snapshot": get_snapshot()})


func is_configured() -> bool:
	return _configured


func get_generation() -> int:
	return _generation


## Strictly validates and detaches an absolute orbital coordinate. Unlike local
## conversion results, a valid absolute coordinate survives origin rebases.
func validate_orbital_coordinate(candidate: Variant) -> Dictionary:
	if not _configured:
		return _result(false, &"not_configured")
	var validation := _validate_coordinate_contract(
		candidate, _orbital_frame_id, _orbital_cell_size_meters
	)
	if not bool(validation.get("accepted", false)):
		return _result(false, validation.get("reason", &"invalid_coordinate"))
	return _result(true, &"valid_coordinate", {
		"coordinate": (
			validation.get("coordinate", {}) as Dictionary
		).duplicate(true),
	})


func body_local_to_surface_tangent(
		body_local_position: Vector3,
		expected_generation: int
	) -> Dictionary:
	var preflight := _local_conversion_preflight(
		body_local_position, expected_generation
	)
	if not bool(preflight.get("accepted", false)):
		return preflight
	var tangent := _surface_tangent_basis.transposed() \
		* (body_local_position - _surface_reference_body_local)
	if not _is_bounded_local_vector(tangent):
		return _result(false, &"coordinate_out_of_bounds")
	return _position_result(
		FRAME_BODY_LOCAL, FRAME_SURFACE_TANGENT, tangent
	)


func surface_tangent_to_body_local(
		surface_tangent_position: Vector3,
		expected_generation: int
	) -> Dictionary:
	var preflight := _local_conversion_preflight(
		surface_tangent_position, expected_generation
	)
	if not bool(preflight.get("accepted", false)):
		return preflight
	var body_local := _surface_reference_body_local \
		+ _surface_tangent_basis * surface_tangent_position
	if not _is_bounded_local_vector(body_local):
		return _result(false, &"coordinate_out_of_bounds")
	return _position_result(
		FRAME_SURFACE_TANGENT, FRAME_BODY_LOCAL, body_local
	)


func body_local_to_orbital_position(
		body_local_position: Vector3,
		expected_generation: int
	) -> Dictionary:
	var preflight := _local_conversion_preflight(
		body_local_position, expected_generation
	)
	if not bool(preflight.get("accepted", false)):
		return preflight
	var added := _add_local_to_coordinate(
		_body_center_orbital_coordinate, body_local_position
	)
	if not bool(added.get("accepted", false)):
		return _result(false, added.get("reason", &"coordinate_out_of_bounds"))
	return _result(true, &"converted", {
		"source_frame": FRAME_BODY_LOCAL,
		"target_frame": FRAME_ORBITAL,
		"coordinate": (
			added.get("coordinate", {}) as Dictionary
		).duplicate(true),
	})


func orbital_to_body_local_position(
		orbital_coordinate: Variant,
		expected_generation: int
	) -> Dictionary:
	var generation_preflight := _generation_preflight(expected_generation)
	if not bool(generation_preflight.get("accepted", false)):
		return generation_preflight
	var validation := _validate_coordinate_contract(
		orbital_coordinate, _orbital_frame_id, _orbital_cell_size_meters
	)
	if not bool(validation.get("accepted", false)):
		return _result(false, validation.get("reason", &"invalid_coordinate"))
	var relative := _subtract_coordinates(
		validation.get("coordinate", {}) as Dictionary,
		_body_center_orbital_coordinate
	)
	if not bool(relative.get("accepted", false)):
		return _result(false, relative.get("reason", &"coordinate_out_of_bounds"))
	return _position_result(
		FRAME_ORBITAL,
		FRAME_BODY_LOCAL,
		relative.get("position", Vector3.ZERO) as Vector3
	)


func orbital_to_world_streaming_position(
		orbital_coordinate: Variant,
		expected_generation: int
	) -> Dictionary:
	var generation_preflight := _generation_preflight(expected_generation)
	if not bool(generation_preflight.get("accepted", false)):
		return generation_preflight
	var validation := _validate_coordinate_contract(
		orbital_coordinate, _orbital_frame_id, _orbital_cell_size_meters
	)
	if not bool(validation.get("accepted", false)):
		return _result(false, validation.get("reason", &"invalid_coordinate"))
	var relative := _subtract_coordinates(
		validation.get("coordinate", {}) as Dictionary,
		_world_streaming_origin_orbital_coordinate
	)
	if not bool(relative.get("accepted", false)):
		return _result(false, relative.get("reason", &"coordinate_out_of_bounds"))
	return _position_result(
		FRAME_ORBITAL,
		FRAME_WORLD_STREAMING,
		relative.get("position", Vector3.ZERO) as Vector3
	)


func world_streaming_to_orbital_position(
		world_streaming_position: Vector3,
		expected_generation: int
	) -> Dictionary:
	var preflight := _local_conversion_preflight(
		world_streaming_position, expected_generation
	)
	if not bool(preflight.get("accepted", false)):
		return preflight
	var added := _add_local_to_coordinate(
		_world_streaming_origin_orbital_coordinate,
		world_streaming_position
	)
	if not bool(added.get("accepted", false)):
		return _result(false, added.get("reason", &"coordinate_out_of_bounds"))
	return _result(true, &"converted", {
		"source_frame": FRAME_WORLD_STREAMING,
		"target_frame": FRAME_ORBITAL,
		"coordinate": (
			added.get("coordinate", {}) as Dictionary
		).duplicate(true),
	})


## Radial altitude is distance from body centre minus the configured mean radius.
func body_local_altitude_meters(
		body_local_position: Vector3,
		expected_generation: int
	) -> Dictionary:
	var preflight := _local_conversion_preflight(
		body_local_position, expected_generation
	)
	if not bool(preflight.get("accepted", false)):
		return preflight
	var altitude := body_local_position.length() - _body_radius_meters
	if not is_finite(altitude):
		return _result(false, &"coordinate_out_of_bounds")
	return _result(true, &"converted", {
		"source_frame": FRAME_BODY_LOCAL,
		"target_frame": &"radial_altitude",
		"altitude_meters": altitude,
	})


## Encodes one body-local point into a canonical detached multi-frame record.
func encode_body_local_position(
		body_local_position: Vector3,
		expected_generation: int
	) -> Dictionary:
	var preflight := _local_conversion_preflight(
		body_local_position, expected_generation
	)
	if not bool(preflight.get("accepted", false)):
		return preflight
	var encoded := _encode_body_local_unchecked(body_local_position)
	if encoded.is_empty():
		return _result(false, &"coordinate_out_of_bounds")
	return _result(true, &"encoded", {"coordinate": encoded})


## Decodes a current-generation world-streaming point to the same canonical
## record. Integer-cell subtraction occurs before any float multiplication.
func decode_world_streaming_position(
		world_streaming_position: Vector3,
		expected_generation: int
	) -> Dictionary:
	var preflight := _local_conversion_preflight(
		world_streaming_position, expected_generation
	)
	if not bool(preflight.get("accepted", false)):
		return preflight
	var orbital := _add_local_to_coordinate(
		_world_streaming_origin_orbital_coordinate,
		world_streaming_position
	)
	if not bool(orbital.get("accepted", false)):
		return _result(false, orbital.get("reason", &"coordinate_out_of_bounds"))
	var body_relative := _subtract_coordinates(
		orbital.get("coordinate", {}) as Dictionary,
		_body_center_orbital_coordinate
	)
	if not bool(body_relative.get("accepted", false)):
		return _result(
			false, body_relative.get("reason", &"coordinate_out_of_bounds")
		)
	var decoded := _encode_body_local_unchecked(
		body_relative.get("position", Vector3.ZERO) as Vector3
	)
	if decoded.is_empty():
		return _result(false, &"coordinate_out_of_bounds")
	return _result(true, &"decoded", {"coordinate": decoded})


## Evaluates the inclusive floating-origin threshold without mutating state.
func evaluate_origin_shift(
		focus_world_streaming_position: Vector3,
		expected_generation: int
	) -> Dictionary:
	var preflight := _local_conversion_preflight(
		focus_world_streaming_position, expected_generation
	)
	if not bool(preflight.get("accepted", false)):
		return preflight
	var distance := focus_world_streaming_position.length()
	return _result(true, &"evaluated", {
		"distance_from_origin_meters": distance,
		"threshold_meters": _origin_shift_threshold_meters,
		"rebase_required": distance >= _origin_shift_threshold_meters,
	})


## Freezes one proposal that would move the supplied focus to streaming zero.
func request_rebase(
		focus_world_streaming_position: Vector3,
		expected_generation: int
	) -> Dictionary:
	var preflight := _local_conversion_preflight(
		focus_world_streaming_position, expected_generation
	)
	if not bool(preflight.get("accepted", false)):
		return preflight
	if not _pending_rebase.is_empty():
		return _result(false, &"rebase_already_pending")
	if focus_world_streaming_position.length() < _origin_shift_threshold_meters:
		return _result(false, &"origin_shift_below_threshold")
	if _generation >= MAX_GENERATION:
		return _result(false, &"generation_exhausted")
	if _next_rebase_request_id > MAX_SAFE_INTEGER:
		return _result(false, &"request_id_exhausted")
	var target := _add_local_to_coordinate(
		_world_streaming_origin_orbital_coordinate,
		focus_world_streaming_position
	)
	if not bool(target.get("accepted", false)):
		return _result(false, target.get("reason", &"target_origin_out_of_bounds"))
	var request_id := _next_rebase_request_id
	_next_rebase_request_id += 1
	_pending_rebase = {
		"request_id": request_id,
		"source_generation": _generation,
		"target_generation": _generation + 1,
		"source_origin_orbital_coordinate": (
			_world_streaming_origin_orbital_coordinate.duplicate(true)
		),
		"target_origin_orbital_coordinate": (
			(target.get("coordinate", {}) as Dictionary).duplicate(true)
		),
		"focus_world_streaming_position": focus_world_streaming_position,
		"world_translation_delta": -focus_world_streaming_position,
	}
	_rebase_request_count += 1
	return _result(true, &"rebase_requested", {
		"request": _pending_rebase.duplicate(true),
	})


## Commits exactly the pending request from the expected source generation.
func commit_rebase(request_id: int, expected_generation: int) -> Dictionary:
	var generation_preflight := _generation_preflight(expected_generation)
	if not bool(generation_preflight.get("accepted", false)):
		return generation_preflight
	if request_id < 1 or request_id > MAX_SAFE_INTEGER:
		return _result(false, &"invalid_rebase_request_id")
	if _pending_rebase.is_empty():
		return _result(false, &"no_pending_rebase")
	if request_id != int(_pending_rebase.get("request_id", 0)):
		return _result(false, &"stale_rebase_request")
	if int(_pending_rebase.get("source_generation", 0)) != _generation \
		or int(_pending_rebase.get("target_generation", 0)) != _generation + 1:
		return _result(false, &"stale_rebase_generation")
	var committed := _pending_rebase.duplicate(true)
	_world_streaming_origin_orbital_coordinate = (
		committed.get("target_origin_orbital_coordinate", {}) as Dictionary
	).duplicate(true)
	_generation = int(committed.get("target_generation", 0))
	_pending_rebase.clear()
	_rebase_commit_count += 1
	_last_rebase_result = committed.duplicate(true)
	_last_rebase_result["reason"] = &"rebased"
	_last_rebase_result["committed_generation"] = _generation
	return _result(true, &"rebased", {
		"rebase": _last_rebase_result.duplicate(true),
		"snapshot": get_snapshot(),
	})


## Cancels only the matching pending request without advancing generation.
func cancel_rebase(request_id: int, expected_generation: int) -> Dictionary:
	var generation_preflight := _generation_preflight(expected_generation)
	if not bool(generation_preflight.get("accepted", false)):
		return generation_preflight
	if request_id < 1 or request_id > MAX_SAFE_INTEGER:
		return _result(false, &"invalid_rebase_request_id")
	if _pending_rebase.is_empty():
		return _result(false, &"no_pending_rebase")
	if request_id != int(_pending_rebase.get("request_id", 0)):
		return _result(false, &"stale_rebase_request")
	_pending_rebase.clear()
	_rebase_cancel_count += 1
	return _result(true, &"rebase_cancelled", {"snapshot": get_snapshot()})


func get_snapshot() -> Dictionary:
	return {
		"schema_version": SCHEMA_VERSION,
		"configured": _configured,
		"body_id": _body_id,
		"orbital_frame_id": _orbital_frame_id,
		"meters_per_world_unit": METERS_PER_WORLD_UNIT,
		"body_radius_meters": _body_radius_meters,
		"orbital_cell_size_meters": _orbital_cell_size_meters,
		"body_center_orbital_coordinate": (
			_body_center_orbital_coordinate.duplicate(true)
		),
		"surface_reference_direction": _surface_reference_direction,
		"surface_reference_body_local": _surface_reference_body_local,
		"surface_north_direction": _surface_north_direction,
		"surface_tangent_basis": _surface_tangent_basis,
		"origin_shift_threshold_meters": _origin_shift_threshold_meters,
		"world_streaming_origin_orbital_coordinate": (
			_world_streaming_origin_orbital_coordinate.duplicate(true)
		),
		"generation": _generation,
		"pending_rebase": _pending_rebase.duplicate(true),
		"last_rebase_result": _last_rebase_result.duplicate(true),
		"rebase_request_count": _rebase_request_count,
		"rebase_commit_count": _rebase_commit_count,
		"rebase_cancel_count": _rebase_cancel_count,
	}.duplicate(true)


func audit() -> Dictionary:
	var errors := PackedStringArray()
	if not _configured:
		errors.append("coordinate frame is not configured")
	else:
		if not _is_stable_id(str(_body_id)) or not _is_stable_id(
			str(_orbital_frame_id)
		):
			errors.append("frame identity is invalid")
		if not is_finite(_body_radius_meters) \
			or _body_radius_meters < MIN_BODY_RADIUS_METERS \
			or _body_radius_meters > MAX_BODY_RADIUS_METERS:
			errors.append("body radius is outside the supported finite range")
		if not is_finite(_orbital_cell_size_meters) \
			or _orbital_cell_size_meters < MIN_ORBITAL_CELL_SIZE_METERS \
			or _orbital_cell_size_meters > MAX_ORBITAL_CELL_SIZE_METERS:
			errors.append("orbital cell size is outside the supported finite range")
		if not is_finite(_origin_shift_threshold_meters) \
			or _origin_shift_threshold_meters < MIN_ORIGIN_SHIFT_THRESHOLD_METERS \
			or _origin_shift_threshold_meters > MAX_ORIGIN_SHIFT_THRESHOLD_METERS:
			errors.append("origin-shift threshold is outside the supported finite range")
		if not bool(_validate_coordinate_contract(
			_body_center_orbital_coordinate,
			_orbital_frame_id,
			_orbital_cell_size_meters
		).get("accepted", false)):
			errors.append("body-centre orbital coordinate is invalid")
		if not bool(_validate_coordinate_contract(
			_world_streaming_origin_orbital_coordinate,
			_orbital_frame_id,
			_orbital_cell_size_meters
		).get("accepted", false)):
			errors.append("streaming-origin orbital coordinate is invalid")
		if not _is_bounded_local_vector(_surface_reference_body_local) \
			or not _is_valid_tangent_basis(_surface_tangent_basis):
			errors.append("surface tangent contract is invalid")
		if _generation < 1 or _generation > MAX_GENERATION:
			errors.append("coordinate generation is invalid")
	if not _pending_rebase.is_empty():
		if int(_pending_rebase.get("source_generation", 0)) != _generation \
			or int(_pending_rebase.get("target_generation", 0)) != _generation + 1:
			errors.append("pending rebase generation is inconsistent")
		var source := _pending_rebase.get(
			"source_origin_orbital_coordinate", {}
		) as Dictionary
		var target := _pending_rebase.get(
			"target_origin_orbital_coordinate", {}
		) as Dictionary
		var focus := _pending_rebase.get(
			"focus_world_streaming_position", Vector3.INF
		) as Vector3
		var translation := _pending_rebase.get(
			"world_translation_delta", Vector3.INF
		) as Vector3
		var expected_target := _add_local_to_coordinate(source, focus)
		if not bool(expected_target.get("accepted", false)) \
			or expected_target.get("coordinate", {}) != target \
			or not _is_bounded_local_vector(translation) \
			or not translation.is_equal_approx(-focus):
			errors.append("pending rebase coordinate delta is inconsistent")
	if _rebase_commit_count > _rebase_request_count \
		or _rebase_cancel_count > _rebase_request_count \
		or _rebase_commit_count + _rebase_cancel_count > _rebase_request_count:
		errors.append("rebase counters are inconsistent")
	return {
		"schema_version": SCHEMA_VERSION,
		"valid": errors.is_empty(),
		"errors": errors,
		"snapshot": get_snapshot(),
		"coordinate_policy": {
			"units": &"metres",
			"orbital_encoding": &"safe_integer_cells_plus_half_open_offsets",
			"surface_axes": &"x_east_y_up_z_south",
			"altitude": &"radial_distance_minus_mean_radius",
			"world_streaming": &"orbital_relative_to_current_origin",
			"origin_threshold": &"inclusive",
		},
		"authority": {
			"automatic_process": false,
			"actor_movement": false,
			"renderer": false,
			"physics": false,
			"streaming_coordinator": false,
			"gameplay": false,
			"save": false,
			"network": false,
		},
	}.duplicate(true)


func _encode_body_local_unchecked(body_local_position: Vector3) -> Dictionary:
	var orbital := _add_local_to_coordinate(
		_body_center_orbital_coordinate, body_local_position
	)
	if not bool(orbital.get("accepted", false)):
		return {}
	var orbital_coordinate := orbital.get("coordinate", {}) as Dictionary
	var world := _subtract_coordinates(
		orbital_coordinate, _world_streaming_origin_orbital_coordinate
	)
	var surface_tangent := _surface_tangent_basis.transposed() \
		* (body_local_position - _surface_reference_body_local)
	var altitude := body_local_position.length() - _body_radius_meters
	if not bool(world.get("accepted", false)) \
		or not _is_bounded_local_vector(surface_tangent) \
		or not is_finite(altitude):
		return {}
	return {
		"schema_version": SCHEMA_VERSION,
		"body_id": _body_id,
		"frame_generation": _generation,
		"planetary_body_local_position": body_local_position,
		"surface_tangent_position": surface_tangent,
		"altitude_meters": altitude,
		"orbital_coordinate": orbital_coordinate.duplicate(true),
		"world_streaming_position": world.get(
			"position", Vector3.ZERO
		) as Vector3,
	}.duplicate(true)


func _add_local_to_coordinate(
		base_coordinate: Dictionary,
		local_delta: Vector3
	) -> Dictionary:
	if not _is_bounded_local_vector(local_delta):
		return {"accepted": false, "reason": &"coordinate_out_of_bounds"}
	var base_validation := _validate_coordinate_contract(
		base_coordinate, _orbital_frame_id, _orbital_cell_size_meters
	)
	if not bool(base_validation.get("accepted", false)):
		return {
			"accepted": false,
			"reason": base_validation.get("reason", &"invalid_coordinate"),
		}
	var base := base_validation.get("coordinate", {}) as Dictionary
	var offset := base.get("offset_meters", Vector3.ZERO) as Vector3
	var cells := [int(base.cell_x), int(base.cell_y), int(base.cell_z)]
	var totals := [
		offset.x + local_delta.x,
		offset.y + local_delta.y,
		offset.z + local_delta.z,
	]
	var canonical_offsets := [0.0, 0.0, 0.0]
	var half_cell := _orbital_cell_size_meters * 0.5
	for axis in 3:
		var total := float(totals[axis])
		if not is_finite(total):
			return {"accepted": false, "reason": &"coordinate_out_of_bounds"}
		var carry_float: float = floor(
			(total + half_cell) / _orbital_cell_size_meters
		)
		if not is_finite(carry_float) or absf(carry_float) > MAX_SAFE_INTEGER:
			return {"accepted": false, "reason": &"coordinate_out_of_bounds"}
		var carry := int(carry_float)
		var next_cell := int(cells[axis]) + carry
		if not _is_safe_integer(next_cell):
			return {"accepted": false, "reason": &"orbital_cell_exhausted"}
		var canonical_offset := total \
			- float(carry) * _orbital_cell_size_meters
		# Floating arithmetic exactly at a boundary can land one ULP outside.
		if canonical_offset >= half_cell:
			next_cell += 1
			canonical_offset -= _orbital_cell_size_meters
		elif canonical_offset < -half_cell:
			next_cell -= 1
			canonical_offset += _orbital_cell_size_meters
		if not _is_safe_integer(next_cell) \
			or not is_finite(canonical_offset) \
			or canonical_offset < -half_cell \
			or canonical_offset >= half_cell:
			return {"accepted": false, "reason": &"orbital_cell_exhausted"}
		cells[axis] = next_cell
		canonical_offsets[axis] = 0.0 if canonical_offset == 0.0 \
			else canonical_offset
	return {
		"accepted": true,
		"coordinate": _coordinate(
			int(cells[0]),
			int(cells[1]),
			int(cells[2]),
			Vector3(
				float(canonical_offsets[0]),
				float(canonical_offsets[1]),
				float(canonical_offsets[2])
			)
		),
	}


func _subtract_coordinates(target: Dictionary, origin: Dictionary) -> Dictionary:
	var target_validation := _validate_coordinate_contract(
		target, _orbital_frame_id, _orbital_cell_size_meters
	)
	var origin_validation := _validate_coordinate_contract(
		origin, _orbital_frame_id, _orbital_cell_size_meters
	)
	if not bool(target_validation.get("accepted", false)) \
		or not bool(origin_validation.get("accepted", false)):
		return {"accepted": false, "reason": &"invalid_coordinate"}
	var target_coordinate := target_validation.get("coordinate", {}) as Dictionary
	var origin_coordinate := origin_validation.get("coordinate", {}) as Dictionary
	var target_offset := target_coordinate.offset_meters as Vector3
	var origin_offset := origin_coordinate.offset_meters as Vector3
	var cell_deltas := [
		int(target_coordinate.cell_x) - int(origin_coordinate.cell_x),
		int(target_coordinate.cell_y) - int(origin_coordinate.cell_y),
		int(target_coordinate.cell_z) - int(origin_coordinate.cell_z),
	]
	var maximum_cell_delta := int(ceil(
		MAX_LOCAL_COMPONENT_METERS / _orbital_cell_size_meters
	)) + 2
	for cell_delta: int in cell_deltas:
		if absi(cell_delta) > maximum_cell_delta:
			return {"accepted": false, "reason": &"coordinate_out_of_bounds"}
	var position := Vector3(
		float(cell_deltas[0]) * _orbital_cell_size_meters \
			+ target_offset.x - origin_offset.x,
		float(cell_deltas[1]) * _orbital_cell_size_meters \
			+ target_offset.y - origin_offset.y,
		float(cell_deltas[2]) * _orbital_cell_size_meters \
			+ target_offset.z - origin_offset.z
	)
	if not _is_bounded_local_vector(position):
		return {"accepted": false, "reason": &"coordinate_out_of_bounds"}
	return {"accepted": true, "position": position}


func _local_conversion_preflight(
		position: Vector3,
		expected_generation: int
	) -> Dictionary:
	var generation_preflight := _generation_preflight(expected_generation)
	if not bool(generation_preflight.get("accepted", false)):
		return generation_preflight
	if not _is_bounded_local_vector(position):
		return _result(false, &"invalid_coordinate")
	return {"accepted": true}


func _generation_preflight(expected_generation: int) -> Dictionary:
	if not _configured:
		return _result(false, &"not_configured")
	if expected_generation < 1 or expected_generation > MAX_GENERATION:
		return _result(false, &"invalid_generation")
	if expected_generation != _generation:
		return _result(false, &"stale_generation")
	return {"accepted": true}


func _position_result(
		source_frame: StringName,
		target_frame: StringName,
		position: Vector3
	) -> Dictionary:
	return _result(true, &"converted", {
		"source_frame": source_frame,
		"target_frame": target_frame,
		"position": position,
	})


func _result(
		accepted: bool,
		reason: StringName,
		details: Dictionary = {}
	) -> Dictionary:
	var result := {
		"accepted": accepted,
		"reason": reason,
		"configured": _configured,
		"generation": _generation,
	}
	result.merge(details, true)
	return result.duplicate(true)


func _coordinate(
		cell_x: int,
		cell_y: int,
		cell_z: int,
		offset_meters: Vector3
	) -> Dictionary:
	return {
		"schema_version": COORDINATE_SCHEMA_VERSION,
		"frame_id": _orbital_frame_id,
		"cell_x": cell_x,
		"cell_y": cell_y,
		"cell_z": cell_z,
		"offset_meters": offset_meters,
	}


static func _validate_coordinate_contract(
		candidate: Variant,
		expected_frame_id: StringName,
		cell_size_meters: float
	) -> Dictionary:
	if not candidate is Dictionary:
		return {"accepted": false, "reason": &"coordinate_not_dictionary"}
	var coordinate := candidate as Dictionary
	if not _has_exact_string_keys(coordinate, _COORDINATE_KEYS):
		return {"accepted": false, "reason": &"coordinate_fields_invalid"}
	if not coordinate.schema_version is int \
		or int(coordinate.schema_version) != COORDINATE_SCHEMA_VERSION:
		return {"accepted": false, "reason": &"coordinate_schema_invalid"}
	if not coordinate.frame_id is StringName \
		or coordinate.frame_id != expected_frame_id:
		return {"accepted": false, "reason": &"coordinate_frame_mismatch"}
	if not coordinate.cell_x is int or not coordinate.cell_y is int \
		or not coordinate.cell_z is int:
		return {"accepted": false, "reason": &"coordinate_cells_invalid"}
	if not _is_safe_integer(int(coordinate.cell_x)) \
		or not _is_safe_integer(int(coordinate.cell_y)) \
		or not _is_safe_integer(int(coordinate.cell_z)):
		return {"accepted": false, "reason": &"coordinate_cells_out_of_bounds"}
	if not coordinate.offset_meters is Vector3:
		return {"accepted": false, "reason": &"coordinate_offset_invalid"}
	var offset := coordinate.offset_meters as Vector3
	var half_cell := cell_size_meters * 0.5
	if not offset.is_finite() \
		or offset.x < -half_cell or offset.x >= half_cell \
		or offset.y < -half_cell or offset.y >= half_cell \
		or offset.z < -half_cell or offset.z >= half_cell:
		return {"accepted": false, "reason": &"coordinate_offset_not_canonical"}
	return {"accepted": true, "coordinate": coordinate.duplicate(true)}


static func _has_exact_string_keys(candidate: Dictionary, expected: Array) -> bool:
	if candidate.size() != expected.size():
		return false
	for key: Variant in candidate:
		if not key is String or not expected.has(key):
			return false
	for key: String in expected:
		if not candidate.has(key):
			return false
	return true


static func _is_valid_tangent_basis(basis: Basis) -> bool:
	return _is_finite_nonzero_vector(basis.x) \
		and _is_finite_nonzero_vector(basis.y) \
		and _is_finite_nonzero_vector(basis.z) \
		and basis.is_orthonormal() \
		and basis.determinant() > 0.0


static func _is_finite_nonzero_vector(value: Vector3) -> bool:
	return value.is_finite() and value.length() >= MIN_TANGENT_AXIS_LENGTH


static func _is_bounded_local_vector(value: Vector3) -> bool:
	return value.is_finite() \
		and absf(value.x) <= MAX_LOCAL_COMPONENT_METERS \
		and absf(value.y) <= MAX_LOCAL_COMPONENT_METERS \
		and absf(value.z) <= MAX_LOCAL_COMPONENT_METERS


static func _is_safe_integer(value: int) -> bool:
	return value >= -MAX_SAFE_INTEGER and value <= MAX_SAFE_INTEGER


static func _is_stable_id(value: String) -> bool:
	if value.is_empty() or value.length() > 64 or value.begins_with("_") \
		or value.ends_with("_") or value.contains("__"):
		return false
	for index in value.length():
		var code := value.unicode_at(index)
		var is_lower_letter := code >= 97 and code <= 122
		var is_digit := code >= 48 and code <= 57
		if not is_lower_letter and not is_digit and code != 95:
			return false
	return true
