class_name CrashRecoveryRegressionManifest
extends RefCounted

## A small, caller-owned evidence contract for the crash/recovery seam.
##
## This is deliberately a regression manifest rather than a recovery
## controller.  Production authorities (damage, ship lifecycle, and save/re-
## entry) publish detached observations to the caller; this contract checks
## that one bounded trace contains the complete failure -> cleanup -> respawn
## -> re-entry hand-off.  It owns no scene, clock, persistence, damage, or
## respawn authority.

const SCHEMA_VERSION := 1
const MAX_TRACE_EVENTS := 16
const MAX_GENERATION := 9_007_199_254_740_991
const MAX_SEQUENCE := 9_007_199_254_740_991

const STEP_COMPONENT_FAILURE: StringName = &"component_failure"
const STEP_CLEANUP: StringName = &"cleanup"
const STEP_RESPAWN: StringName = &"respawn"
const STEP_GENERATION_SAFE_REENTRY: StringName = &"generation_safe_reentry"

const REQUIRED_STEPS := [
	STEP_COMPONENT_FAILURE,
	STEP_CLEANUP,
	STEP_RESPAWN,
	STEP_GENERATION_SAFE_REENTRY,
]

const _STEP_OWNERS := {
	STEP_COMPONENT_FAILURE: &"ComponentDamageModel",
	STEP_CLEANUP: &"RecoveryLifecycle",
	STEP_RESPAWN: &"HeroShip",
	STEP_GENERATION_SAFE_REENTRY: &"SaveReentryLifecycle",
}


## Returns the frozen acceptance surface.  The result is detached so a caller
## cannot alter the manifest by mutating a returned nested array/dictionary.
func get_manifest() -> Dictionary:
	return {
		"schema_version": SCHEMA_VERSION,
		"manifest_id": "crash_recovery_failure_respawn_reentry_v1",
		"maximum_trace_events": MAX_TRACE_EVENTS,
		"required_steps": REQUIRED_STEPS.duplicate(),
		"ordered_steps": true,
		"step_authorities": _STEP_OWNERS.duplicate(true),
		"evidence": {
			STEP_COMPONENT_FAILURE: [
				"generation",
				"component_id",
				"damage_sequence",
				"health_before",
				"health_after",
				"state",
				"authoritative",
			],
			STEP_CLEANUP: [
				"source_generation",
				"pending_receipts_after",
				"transient_nodes_after",
				"stale_callbacks_cancelled",
				"old_authority_released",
			],
			STEP_RESPAWN: [
				"source_generation",
				"generation",
				"restored",
				"health_restored",
				"spawn_transform_restored",
				"active",
			],
			STEP_GENERATION_SAFE_REENTRY: [
				"source_generation",
				"generation",
				"stale_request_rejected",
				"stale_reason",
				"duplicate_reentry_rejected",
				"state_restored",
				"accepted",
				"current_generation",
			],
		},
	}.duplicate(true)


## Validates one bounded ordered trace.  Unknown or duplicate required steps
## fail closed: silently dropping an untrusted event would make a partial
## crash path look like a complete recovery.
func validate_trace(trace: Array) -> Dictionary:
	var errors := PackedStringArray()
	var validated_steps: Array[StringName] = []
	var seen := {}
	var previous_step_index := -1
	var failure_generation := 0
	var respawn_generation := 0

	if trace.size() == 0:
		errors.append("trace_empty")
	elif trace.size() > MAX_TRACE_EVENTS:
		errors.append("trace_too_large")

	for raw_event in trace:
		if not raw_event is Dictionary:
			errors.append("event_not_dictionary")
			continue
		var event := raw_event as Dictionary
		var step := StringName(str(event.get("step", "")))
		var step_index := REQUIRED_STEPS.find(step)
		if step_index < 0:
			errors.append("unknown_step")
			continue
		if seen.has(step):
			errors.append("duplicate_step:%s" % step)
			continue
		if step_index <= previous_step_index:
			errors.append("step_order_invalid:%s" % step)
			continue
		seen[step] = true
		previous_step_index = step_index
		var step_result := _validate_step(step, event, failure_generation, respawn_generation)
		if not bool(step_result.get("accepted", false)):
			errors.append(str(step_result.get("reason", "step_invalid")))
			continue
		validated_steps.append(step)
		if step == STEP_COMPONENT_FAILURE:
			failure_generation = int(event.get("generation", 0))
		elif step == STEP_RESPAWN:
			respawn_generation = int(event.get("generation", 0))

	for required_step in REQUIRED_STEPS:
		if not seen.has(required_step):
			errors.append("missing_step:%s" % required_step)

	return {
		"accepted": errors.is_empty(),
		"reason": &"accepted" if errors.is_empty() else StringName(errors[0]),
		"errors": errors,
		"validated_steps": validated_steps,
		"trace_count": trace.size(),
		"failure_generation": failure_generation,
		"respawn_generation": respawn_generation,
		"manifest_id": "crash_recovery_failure_respawn_reentry_v1",
	}.duplicate(true)


func audit() -> Dictionary:
	return {
		"valid": true,
		"manifest": get_manifest(),
		"authority": {
			"damage": false,
			"respawn": false,
			"cleanup": false,
			"reentry": false,
			"clock": false,
			"scene": false,
			"persistence": false,
		},
	}.duplicate(true)


func _validate_step(
		step: StringName,
		event: Dictionary,
		failure_generation: int,
		respawn_generation: int
		) -> Dictionary:
	if StringName(event.get("authority_owner", &"")) != _STEP_OWNERS[step]:
		return _reject("authority_owner_invalid:%s" % step)
	if not bool(event.get("authoritative", true)):
		return _reject("event_not_authoritative:%s" % step)
	match step:
		STEP_COMPONENT_FAILURE:
			return _validate_component_failure(event)
		STEP_CLEANUP:
			return _validate_cleanup(event, failure_generation)
		STEP_RESPAWN:
			return _validate_respawn(event, failure_generation)
		STEP_GENERATION_SAFE_REENTRY:
			return _validate_reentry(event, respawn_generation)
	return _reject("step_not_implemented")


func _validate_component_failure(event: Dictionary) -> Dictionary:
	var generation := int(event.get("generation", 0))
	var sequence := int(event.get("damage_sequence", 0))
	var component_id := str(event.get("component_id", ""))
	var health_before := float(event.get("health_before", NAN))
	var health_after := float(event.get("health_after", NAN))
	if not _valid_generation(generation) or not _valid_sequence(sequence):
		return _reject("component_failure_identity_invalid")
	if component_id.is_empty():
		return _reject("component_id_missing")
	if not is_finite(health_before) or not is_finite(health_after):
		return _reject("component_health_nonfinite")
	if health_before <= 0.0 or health_after > 0.0 or health_after >= health_before:
		return _reject("component_failure_health_transition_invalid")
	if StringName(event.get("state", &"")) != &"failed":
		return _reject("component_failure_state_invalid")
	return _accept()


func _validate_cleanup(event: Dictionary, failure_generation: int) -> Dictionary:
	var source_generation := int(event.get("source_generation", 0))
	if not _valid_generation(source_generation) or source_generation != failure_generation:
		return _reject("cleanup_generation_invalid")
	if int(event.get("pending_receipts_after", -1)) != 0:
		return _reject("cleanup_pending_receipts")
	if int(event.get("transient_nodes_after", -1)) != 0:
		return _reject("cleanup_transient_nodes")
	if not bool(event.get("stale_callbacks_cancelled", false)):
		return _reject("cleanup_stale_callbacks")
	if not bool(event.get("old_authority_released", false)):
		return _reject("cleanup_authority_retained")
	return _accept()


func _validate_respawn(event: Dictionary, failure_generation: int) -> Dictionary:
	var source_generation := int(event.get("source_generation", 0))
	var generation := int(event.get("generation", 0))
	if not _valid_generation(source_generation) or source_generation != failure_generation:
		return _reject("respawn_source_generation_invalid")
	if not _valid_generation(generation) or generation != source_generation + 1:
		return _reject("respawn_generation_invalid")
	for key in ["restored", "health_restored", "spawn_transform_restored", "active"]:
		if not bool(event.get(key, false)):
			return _reject("respawn_%s_missing" % key)
	return _accept()


func _validate_reentry(event: Dictionary, respawn_generation: int) -> Dictionary:
	var source_generation := int(event.get("source_generation", 0))
	var generation := int(event.get("generation", 0))
	if not _valid_generation(source_generation) or source_generation != respawn_generation:
		return _reject("reentry_source_generation_invalid")
	if not _valid_generation(generation) or generation != source_generation + 1:
		return _reject("reentry_generation_invalid")
	if not bool(event.get("stale_request_rejected", false)):
		return _reject("reentry_stale_request_accepted")
	var stale_reason := StringName(event.get("stale_reason", &""))
	if stale_reason != &"stale_generation" and stale_reason != &"stale_attachment_generation":
		return _reject("reentry_stale_reason_invalid")
	if not bool(event.get("duplicate_reentry_rejected", false)):
		return _reject("reentry_duplicate_accepted")
	if not bool(event.get("state_restored", false)) or not bool(event.get("accepted", false)):
		return _reject("reentry_restore_invalid")
	if int(event.get("current_generation", 0)) != generation:
		return _reject("reentry_current_generation_invalid")
	return _accept()


func _valid_generation(value: int) -> bool:
	return value > 0 and value <= MAX_GENERATION


func _valid_sequence(value: int) -> bool:
	return value > 0 and value <= MAX_SEQUENCE


func _accept() -> Dictionary:
	return {"accepted": true, "reason": &"accepted"}


func _reject(reason: String) -> Dictionary:
	return {"accepted": false, "reason": StringName(reason)}
