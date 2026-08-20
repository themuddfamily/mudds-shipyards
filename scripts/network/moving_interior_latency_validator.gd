class_name NetworkMovingInteriorLatencyValidator
extends RefCounted

## Bounded, renderer-independent evidence gate for moving-interior snapshots.
##
## A caller supplies the packets that arrived during one network trace. This
## validator measures transport latency/loss/jitter and checks that accepted
## occupant motion remains bounded in frame-local coordinates. The frame may
## travel any distance; that motion is deliberately excluded from the local
## stability budget. It owns no RPC, clock, interpolation, movement, seat,
## damage, landing, or replica-authority state.

const Relationship := preload("res://scripts/network/moving_interior_relationship.gd")
const RelationshipValidator := preload(
	"res://scripts/network/moving_interior_relationship_validator.gd"
)

const SCHEMA_VERSION := 1
const POLICY_VERSION: StringName = &"moving_interior_latency_validator_v2"
const DEFAULT_TICK_INTERVAL_SECONDS := 1.0 / 60.0
const DEFAULT_MAX_LATENCY_SECONDS := 0.100
const DEFAULT_MAX_JITTER_SECONDS := 0.020
const DEFAULT_MAX_LOSS_RATIO := 0.02
const DEFAULT_MAX_LOCAL_SPEED_MPS := 20.0
const DEFAULT_LOCAL_CORRECTION_METERS := 0.50
const DEFAULT_MAX_HOLD_SECONDS := 0.250
const DEFAULT_MIN_OCCUPANCY_COVERAGE_RATIO := 1.0
const COMPARISON_EPSILON := 0.000001

var _last_report: Dictionary = {}


## Validates a detached trace of delivered packets. Each trace item contains:
## `snapshot` (the relationship wire dictionary), `arrival_time_seconds`, and
## optionally `frame_world_transform` (a Transform3D, identity by default).
## `sent_packet_count` includes packets lost before delivery. Packet arrival
## order is preserved exactly as supplied, so a reordered packet is observed
## and rejected by the existing relationship authority gate.
func validate_trace(
	trace: Array,
	sent_packet_count: int,
	options: Dictionary = {}
) -> Dictionary:
	_last_report = {}
	if sent_packet_count <= 0:
		return _finish(false, &"invalid_sent_packet_count", {})
	if trace.is_empty():
		return _finish(false, &"empty_trace", {})
	if trace.size() > sent_packet_count:
		return _finish(false, &"delivered_packets_exceed_sent", {})
	var tick_interval := float(options.get(
		"tick_interval_seconds", DEFAULT_TICK_INTERVAL_SECONDS
	))
	var max_latency := float(options.get(
		"max_latency_seconds", DEFAULT_MAX_LATENCY_SECONDS
	))
	var max_jitter := float(options.get(
		"max_jitter_seconds", DEFAULT_MAX_JITTER_SECONDS
	))
	var max_loss_ratio := float(options.get(
		"max_loss_ratio", DEFAULT_MAX_LOSS_RATIO
	))
	var max_local_speed := float(options.get(
		"max_local_speed_mps", DEFAULT_MAX_LOCAL_SPEED_MPS
	))
	var local_correction := float(options.get(
		"local_correction_meters", DEFAULT_LOCAL_CORRECTION_METERS
	))
	var max_hold := float(options.get(
		"max_hold_seconds", DEFAULT_MAX_HOLD_SECONDS
	))
	var max_occupancy_gap := float(options.get(
		"max_occupancy_gap_seconds", max_hold
	))
	var min_occupancy_coverage := float(options.get(
		"min_occupancy_coverage_ratio", DEFAULT_MIN_OCCUPANCY_COVERAGE_RATIO
	))
	var authority_peer_id := int(options.get("authority_peer_id", 1))
	var expected_frame_id := StringName(options.get(
		"expected_parent_frame_id", &""
	))
	var expected_frame_generation := int(options.get(
		"expected_parent_frame_generation", 0
	))
	if not _valid_positive_finite(tick_interval) \
			or not _valid_positive_finite(max_latency) \
			or not _valid_nonnegative_finite(max_jitter) \
			or not _valid_ratio(max_loss_ratio) \
			or not _valid_positive_finite(max_local_speed) \
			or not _valid_nonnegative_finite(local_correction) \
			or not _valid_positive_finite(max_hold) \
			or not _valid_positive_finite(max_occupancy_gap) \
			or not _valid_ratio(min_occupancy_coverage) \
			or authority_peer_id <= 0:
		return _finish(false, &"invalid_trace_policy", {})
	if (expected_frame_id != &"") != (expected_frame_generation > 0):
		return _finish(false, &"invalid_expected_frame_policy", {})

	var first_tick := -1
	var origin_tick := int(options.get("origin_server_tick", -1))
	var origin_send_time := float(options.get(
		"origin_send_time_seconds", 0.0
	))
	if not is_finite(origin_send_time):
		return _finish(false, &"invalid_origin_send_time", {})
	var authority = RelationshipValidator.new(authority_peer_id)
	var accepted_count := 0
	var rejected_count := 0
	var max_latency_seen := 0.0
	var max_jitter_seen := 0.0
	var max_local_step := 0.0
	var max_frame_motion := 0.0
	var max_hold_seen := 0.0
	var max_gap_ticks := 0
	var previous_latency := NAN
	var occupancy_samples := 0
	var occupancy_missing_frame_count := 0
	var occupancy_frame_switch_count := 0
	var max_occupancy_gap_seen := 0.0
	var occupancy_last_arrival: Dictionary = {}
	var occupancy_last_frame: Dictionary = {}
	var previous_local_origin: Dictionary = {}
	var previous_frame_origin: Dictionary = {}
	var previous_world_origin: Dictionary = {}
	var previous_tick_by_entity: Dictionary = {}
	var packet_errors := PackedStringArray()
	var stale_or_reordered_count := 0

	for item_index in trace.size():
		var item_variant: Variant = trace[item_index]
		if not item_variant is Dictionary:
			packet_errors.append("trace item %d is not a dictionary" % item_index)
			rejected_count += 1
			continue
		var item := item_variant as Dictionary
		if not item.has("snapshot") or not item.has("arrival_time_seconds"):
			packet_errors.append("trace item %d is missing packet fields" % item_index)
			rejected_count += 1
			continue
		var arrival := float(item.get("arrival_time_seconds", NAN))
		if not is_finite(arrival) or arrival < 0.0:
			packet_errors.append("trace item %d has invalid arrival time" % item_index)
			rejected_count += 1
			continue
		var raw_snapshot: Variant = item.get("snapshot")
		if not raw_snapshot is Dictionary:
			packet_errors.append("trace item %d has a non-dictionary snapshot" % item_index)
			rejected_count += 1
			continue
		var relationship = Relationship.from_dictionary(raw_snapshot as Dictionary)
		if not relationship.is_valid():
			packet_errors.append("trace item %d has an invalid relationship" % item_index)
			rejected_count += 1
			continue
		var tick := relationship.get_server_tick()
		if first_tick < 0:
			first_tick = tick
		if origin_tick < 0:
			origin_tick = first_tick
		var expected_send := origin_send_time + float(tick - origin_tick) * tick_interval
		var latency := arrival - expected_send
		if latency < -COMPARISON_EPSILON \
				or latency > max_latency + COMPARISON_EPSILON:
			packet_errors.append("trace item %d exceeds latency budget" % item_index)
		if not is_nan(previous_latency):
			max_jitter_seen = max(max_jitter_seen, abs(latency - previous_latency))
		previous_latency = latency
		max_latency_seen = max(max_latency_seen, latency)
		var authority_result := authority.accept(authority_peer_id, raw_snapshot as Dictionary)
		if not bool(authority_result.get("accepted", false)):
			rejected_count += 1
			var status := StringName(authority_result.get("status", &"rejected"))
			if status == &"stale_or_duplicate_tick":
				stale_or_reordered_count += 1
			else:
				packet_errors.append("trace item %d rejected as %s" % [item_index, status])
			continue
		accepted_count += 1
		var entity_id := relationship.get_entity_id()
		var parent_frame_id := relationship.get_parent_frame_id()
		var parent_frame_generation := relationship.get_parent_frame_generation()
		if parent_frame_id == &"" or parent_frame_generation <= 0:
			occupancy_missing_frame_count += 1
			packet_errors.append("trace item %d has no moving-interior occupancy frame" % item_index)
		else:
			occupancy_samples += 1
			if expected_frame_id != &"" \
					and (parent_frame_id != expected_frame_id \
					or parent_frame_generation != expected_frame_generation):
				packet_errors.append("trace item %d changes the expected occupancy frame" % item_index)
			var previous_arrival := float(occupancy_last_arrival.get(entity_id, NAN))
			if not is_nan(previous_arrival):
				var occupancy_gap := arrival - previous_arrival
				if occupancy_gap < -COMPARISON_EPSILON:
					packet_errors.append("trace item %d reorders occupancy arrival" % item_index)
				else:
					max_occupancy_gap_seen = max(max_occupancy_gap_seen, occupancy_gap)
					if occupancy_gap > max_occupancy_gap + COMPARISON_EPSILON:
						packet_errors.append("trace item %d exceeds occupancy hold budget" % item_index)
			var prior_frame: Dictionary = occupancy_last_frame.get(entity_id, {})
			if not prior_frame.is_empty() \
					and (StringName(prior_frame.get("id", &"")) != parent_frame_id \
					or int(prior_frame.get("generation", 0)) != parent_frame_generation):
				occupancy_frame_switch_count += 1
				packet_errors.append("trace item %d switches moving-interior occupancy frame" % item_index)
			occupancy_last_arrival[entity_id] = arrival
			occupancy_last_frame[entity_id] = {
				"id": parent_frame_id,
				"generation": parent_frame_generation,
			}
		var prior_tick := int(previous_tick_by_entity.get(entity_id, -1))
		if bool(authority_result.get("gap_detected", false)) and prior_tick >= 0:
			var gap_ticks := tick - prior_tick
			max_gap_ticks = max(max_gap_ticks, gap_ticks)
			max_hold_seen = max(max_hold_seen, float(gap_ticks) * tick_interval)
		previous_tick_by_entity[entity_id] = tick
		var local_transform := relationship.get_frame_local_transform()
		var frame_transform := Transform3D.IDENTITY
		if item.has("frame_world_transform"):
			if not item.get("frame_world_transform") is Transform3D:
				packet_errors.append("trace item %d has an invalid frame transform" % item_index)
				continue
			frame_transform = item.get("frame_world_transform") as Transform3D
		if not _finite_transform(frame_transform):
			packet_errors.append("trace item %d has a non-finite frame transform" % item_index)
			continue
		var local_origin := local_transform.origin
		var world_origin := (frame_transform * local_transform).origin
		var has_previous_pose := previous_local_origin.has(entity_id)
		if has_previous_pose:
			var server_ticks: int = maxi(1, tick - prior_tick)
			var local_step := local_origin.distance_to(previous_local_origin[entity_id])
			var allowed_step := max_local_speed * float(server_ticks) * tick_interval \
				+ local_correction
			max_local_step = max(max_local_step, local_step)
			if local_step > allowed_step:
				packet_errors.append("trace item %d exceeds frame-local motion budget" % item_index)
			var frame_step := frame_transform.origin.distance_to(previous_frame_origin[entity_id])
			max_frame_motion = max(max_frame_motion, frame_step)
			# The world delta is informative only. Stability is judged against the
			# local delta, so a translating frame cannot look like occupant drift.
			var world_step := world_origin.distance_to(previous_world_origin[entity_id])
			if world_step < 0.0: # Defensive; distance_to is always non-negative.
				packet_errors.append("trace item %d has invalid world displacement" % item_index)
		previous_local_origin[entity_id] = local_origin
		previous_frame_origin[entity_id] = frame_transform.origin
		previous_world_origin[entity_id] = world_origin

	var loss_ratio := float(sent_packet_count - trace.size()) / float(sent_packet_count)
	var occupancy_coverage_ratio := 0.0
	if accepted_count > 0:
		occupancy_coverage_ratio = float(occupancy_samples) / float(accepted_count)
	var accepted := packet_errors.is_empty() \
		and max_latency_seen <= max_latency + COMPARISON_EPSILON \
		and max_jitter_seen <= max_jitter + COMPARISON_EPSILON \
		and loss_ratio <= max_loss_ratio + COMPARISON_EPSILON \
		and max_hold_seen <= max_hold + COMPARISON_EPSILON \
		and occupancy_coverage_ratio + COMPARISON_EPSILON >= min_occupancy_coverage \
		and max_occupancy_gap_seen <= max_occupancy_gap + COMPARISON_EPSILON \
		and occupancy_frame_switch_count == 0 \
		and accepted_count > 0
	return _finish(accepted, &"stable" if accepted else &"unstable", {
		"metrics": {
			"sent_packet_count": sent_packet_count,
			"delivered_packet_count": trace.size(),
			"accepted_packet_count": accepted_count,
			"rejected_packet_count": rejected_count,
			"stale_or_reordered_count": stale_or_reordered_count,
			"packet_loss_ratio": loss_ratio,
			"max_latency_seconds": max_latency_seen,
			"max_jitter_seconds": max_jitter_seen,
			"max_gap_ticks": max_gap_ticks,
			"max_hold_seconds": max_hold_seen,
			"max_local_step_meters": max_local_step,
			"max_frame_motion_meters": max_frame_motion,
			"occupancy_sample_count": occupancy_samples,
			"occupancy_entity_count": occupancy_last_frame.size(),
			"occupancy_coverage_ratio": occupancy_coverage_ratio,
			"occupancy_missing_frame_count": occupancy_missing_frame_count,
			"occupancy_frame_switch_count": occupancy_frame_switch_count,
			"max_occupancy_gap_seconds": max_occupancy_gap_seen,
		},
		"policy": {
			"max_latency_seconds": max_latency,
			"max_jitter_seconds": max_jitter,
			"max_loss_ratio": max_loss_ratio,
			"max_local_speed_mps": max_local_speed,
			"local_correction_meters": local_correction,
			"max_hold_seconds": max_hold,
			"max_occupancy_gap_seconds": max_occupancy_gap,
			"min_occupancy_coverage_ratio": min_occupancy_coverage,
			"expected_parent_frame_id": expected_frame_id,
			"expected_parent_frame_generation": expected_frame_generation,
		},
		"packet_errors": packet_errors,
	})


func get_last_report() -> Dictionary:
	return _last_report.duplicate(true)


func audit() -> Dictionary:
	return {
		"schema_version": SCHEMA_VERSION,
		"policy_version": POLICY_VERSION,
		"valid": true,
		"trace_observation_only": true,
		"network_authority": false,
		"owns_interpolation": false,
		"owns_movement": false,
		"owns_seat_or_boarding": false,
		"frame_local_stability_gate": true,
		"latency_loss_jitter_gate": true,
		"occupancy_continuity_gate": true,
		"requires_moving_frame": true,
	}.duplicate(true)


func _finish(accepted: bool, reason: StringName, payload: Dictionary) -> Dictionary:
	_last_report = {
		"schema_version": SCHEMA_VERSION,
		"policy_version": POLICY_VERSION,
		"accepted": accepted,
		"stable": accepted,
		"reason": reason,
		"metrics": payload.get("metrics", {}).duplicate(true),
		"policy": payload.get("policy", {}).duplicate(true),
		"packet_errors": payload.get("packet_errors", PackedStringArray()).duplicate(),
	}.duplicate(true)
	return _last_report.duplicate(true)


func _valid_positive_finite(value: float) -> bool:
	return is_finite(value) and value > 0.0


func _valid_nonnegative_finite(value: float) -> bool:
	return is_finite(value) and value >= 0.0


func _valid_ratio(value: float) -> bool:
	return is_finite(value) and value >= 0.0 and value <= 1.0


func _finite_transform(value: Transform3D) -> bool:
	for component in [
		value.basis.x.x, value.basis.x.y, value.basis.x.z,
		value.basis.y.x, value.basis.y.y, value.basis.y.z,
		value.basis.z.x, value.basis.z.y, value.basis.z.z,
		value.origin.x, value.origin.y, value.origin.z,
	]:
		if not is_finite(float(component)):
			return false
	return true
