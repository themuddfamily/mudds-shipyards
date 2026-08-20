class_name PlanetaryObjectiveRewardRecoveryContract
extends Resource

## Explicit objective/reward/recovery handoff for the authored Ember visit.
##
## The contract is intentionally a data-only join.  It names the existing
## activity and return authorities, but never resolves an objective, writes a
## reward, moves a player or ship, or creates a second reward inventory.  A
## production director may consume the detached snapshot at its own authority
## boundary.

const SCHEMA_VERSION := 1
const CONTENT_CLASS: StringName = &"NEW"
const EVIDENCE_STATUS: StringName = &"modern_interpretation"
const MAX_ID_LENGTH := 64
const MAX_NAME_LENGTH := 96
const MAX_NOTE_LENGTH := 512
const MAX_ITEMS := 32
const MIN_ACTIVITIES := 5

const REQUIRED_WORLD_ID: StringName = &"ember_moon"
const REQUIRED_RETURN_TARGET_ID: StringName = &"mudds_shipyards"
const REQUIRED_REWARD_AUTHORITY_ID: StringName = &"game_flow_reward_authority"
const REQUIRED_REWARD_STORE_ID: StringName = &"game_flow_reward_store"
const REQUIRED_RETURN_AUTHORITY_ID: StringName = &"planetary_landing_return_contract"

const EXISTING_ACTIVITY_AUTHORITY_IDS := {
	&"activity_director": true,
	&"cargo_delivery_activity": true,
	&"timed_checkpoint_race": true,
	&"convoy_escort_activity": true,
}

const EXISTING_RECOVERY_IDS := {
	&"return_to_landed_ship": true,
	&"abort_to_orbit_return": true,
	&"reset_at_start_beacon": true,
	&"recover_convoy_at_return_beacon": true,
}

@export_category("Identity")
@export var world_id: StringName = REQUIRED_WORLD_ID
@export var return_target_id: StringName = REQUIRED_RETURN_TARGET_ID
@export var display_name := "Ember Objective and Recovery Handoffs"

@export_category("Typed objective handoffs")
@export var activity_ids := PackedStringArray([
	"ember_beacon_survey",
	"ember_caldera_patrol",
	"ember_kit_cargo_run",
	"ember_checkpoint_race",
	"ember_convoy_escort",
])
@export var objective_ids := PackedStringArray([
	"survey_beacon_network",
	"complete_caldera_inspection",
	"deliver_fabrication_kits",
	"set_checkpoint_record",
	"escort_emberline_convoy",
])
@export var activity_authority_ids := PackedStringArray([
	"activity_director",
	"activity_director",
	"cargo_delivery_activity",
	"timed_checkpoint_race",
	"convoy_escort_activity",
])

@export_category("Single existing reward store")
## All activities point to this one existing store.  A second store ID is
## rejected even if it has a different name, preventing parallel inventories.
@export var reward_store_id: StringName = REQUIRED_REWARD_STORE_ID
@export var activity_reward_store_ids := PackedStringArray([
	"game_flow_reward_store",
	"game_flow_reward_store",
	"game_flow_reward_store",
	"game_flow_reward_store",
	"game_flow_reward_store",
])
@export var reward_ids := PackedStringArray([
	"ember_beacon_data",
	"ember_patrol_log",
	"ember_fabrication_kits",
	"ember_race_record",
	"ember_convoy_credit",
])
@export var reward_authority_id: StringName = REQUIRED_REWARD_AUTHORITY_ID

@export_category("Return incentives and recovery")
@export var return_incentive_ids := PackedStringArray([
	"return_beacon_data_to_shipyard",
	"return_patrol_log_to_shipyard",
	"return_kits_to_shipyard_berth",
	"return_race_record_to_shipyard",
	"return_convoy_credit_to_shipyard",
])
@export var activity_recovery_ids := PackedStringArray([
	"return_to_landed_ship",
	"abort_to_orbit_return",
	"return_to_landed_ship",
	"reset_at_start_beacon",
	"recover_convoy_at_return_beacon",
])
@export var return_authority_id: StringName = REQUIRED_RETURN_AUTHORITY_ID

@export_category("Evidence")
@export var evidence_references := PackedStringArray([
	"res://docs/PLANETARY_DESTINATION_CONTENT_CONTRACT.md",
])
@export_multiline var evidence_notes := (
	"Fixed authored Ember objective outcomes. Rewards resolve through the one "
	+ "existing reward store and return incentives resolve through the landing "
	+ "return authority; no duplicate inventory is declared."
)


func get_validation_errors() -> PackedStringArray:
	var errors := PackedStringArray()
	_validate_id(errors, "world_id", world_id)
	_validate_id(errors, "return_target_id", return_target_id)
	_validate_id(errors, "reward_store_id", reward_store_id)
	_validate_id(errors, "reward_authority_id", reward_authority_id)
	_validate_id(errors, "return_authority_id", return_authority_id)
	if world_id != REQUIRED_WORLD_ID:
		errors.append("world_id must hand off the authored Ember world")
	if return_target_id != REQUIRED_RETURN_TARGET_ID:
		errors.append("return_target_id must be mudds_shipyards")
	if reward_store_id != REQUIRED_REWARD_STORE_ID:
		errors.append("reward_store_id must use the existing reward store")
	if reward_authority_id != REQUIRED_REWARD_AUTHORITY_ID:
		errors.append("reward authority must use the existing GameFlow authority")
	if return_authority_id != REQUIRED_RETURN_AUTHORITY_ID:
		errors.append("return authority must use the existing planetary return contract")
	if display_name.is_empty() or display_name.length() > MAX_NAME_LENGTH or display_name.contains("\n"):
		errors.append("display_name must be bounded single-line copy")
	_validate_activity_lists(errors)
	_validate_evidence(errors)
	return errors


func is_definition_valid() -> bool:
	return get_validation_errors().is_empty()


## Validates an external detached handoff without retaining or mutating it.
## This accepts the same shape emitted by get_snapshot(), making the seam
## usable by a future ActivityDirector/Network server owner.
func validate_handoff(candidate: Dictionary) -> Dictionary:
	var errors := PackedStringArray()
	if candidate.is_empty():
		errors.append("objective handoff snapshot is required")
	else:
		var identity: Variant = candidate.get("identity", {})
		if not identity is Dictionary:
			errors.append("handoff identity must be a dictionary")
		else:
			if StringName((identity as Dictionary).get("world_id", &"")) != world_id:
				errors.append("handoff world ID does not match")
			if StringName((identity as Dictionary).get("return_target_id", &"")) != return_target_id:
				errors.append("handoff return target does not match")
		var records: Variant = candidate.get("activities", [])
		if not records is Array:
			errors.append("handoff activities must be an array")
		else:
			_validate_activity_records(errors, records as Array)
		var authority: Variant = candidate.get("authorities", {})
		if not authority is Dictionary:
			errors.append("handoff authorities must be a dictionary")
		else:
			var authority_map := authority as Dictionary
			if StringName(authority_map.get("reward_store_id", &"")) != reward_store_id:
				errors.append("handoff must use the one existing reward store")
			if StringName(authority_map.get("reward_authority_id", &"")) != reward_authority_id:
				errors.append("handoff reward authority does not match")
			if StringName(authority_map.get("return_authority_id", &"")) != return_authority_id:
				errors.append("handoff return authority does not match")
	return {
		"accepted": errors.is_empty() and is_definition_valid(),
		"reason": &"objective_handoff_valid" if errors.is_empty() else &"objective_handoff_rejected",
		"errors": errors,
		"snapshot": get_snapshot(),
	}.duplicate(true)


func get_snapshot() -> Dictionary:
	var activities: Array[Dictionary] = []
	for index in activity_ids.size():
		activities.append({
			"activity_id": StringName(activity_ids[index]),
			"objective_id": StringName(objective_ids[index]) if index < objective_ids.size() else &"",
			"activity_authority_id": StringName(activity_authority_ids[index]) if index < activity_authority_ids.size() else &"",
			"reward_id": StringName(reward_ids[index]) if index < reward_ids.size() else &"",
			"reward_store_id": StringName(activity_reward_store_ids[index]) if index < activity_reward_store_ids.size() else &"",
			"return_incentive_id": StringName(return_incentive_ids[index]) if index < return_incentive_ids.size() else &"",
			"return_target_id": return_target_id,
			"recovery_id": StringName(activity_recovery_ids[index]) if index < activity_recovery_ids.size() else &"",
			"recovery_authority_id": return_authority_id,
		})
	return {
		"schema_version": SCHEMA_VERSION,
		"identity": {
			"world_id": world_id,
			"display_name": display_name,
			"return_target_id": return_target_id,
		},
		"activities": activities,
		"authorities": {
			"reward_store_id": reward_store_id,
			"reward_authority_id": reward_authority_id,
			"return_authority_id": return_authority_id,
		},
		"evidence": {
			"content_class": CONTENT_CLASS,
			"status": EVIDENCE_STATUS,
			"historical_claim": false,
			"procedural_generation": false,
			"references": evidence_references.duplicate(),
		},
		"authority": {
			"objective": false,
			"activity": false,
			"reward": false,
			"reward_store": false,
			"return": false,
			"recovery": false,
			"save": false,
			"network": false,
		},
	}.duplicate(true)


func get_audit_report() -> Dictionary:
	var errors := get_validation_errors()
	return {
		"schema_version": SCHEMA_VERSION,
		"valid": errors.is_empty(),
		"errors": errors,
		"snapshot": get_snapshot(),
		"production_wiring": false,
		"owns_reward_store": false,
	}.duplicate(true)


func _validate_activity_lists(errors: PackedStringArray) -> void:
	if activity_ids.size() < MIN_ACTIVITIES or activity_ids.size() > MAX_ITEMS:
		errors.append("activity_ids must contain %d to %d IDs" % [MIN_ACTIVITIES, MAX_ITEMS])
	var fields: Array = [objective_ids, activity_authority_ids, reward_ids,
		activity_reward_store_ids, return_incentive_ids, activity_recovery_ids]
	var labels := ["objectives", "activity authorities", "rewards", "reward stores", "return incentives", "recoveries"]
	for index in fields.size():
		if fields[index].size() != activity_ids.size():
			errors.append("activity %s must be parallel to activity_ids" % labels[index])
	_validate_unique_ids(errors, "activity_ids", activity_ids)
	_validate_unique_ids(errors, "objective_ids", objective_ids)
	_validate_unique_ids(errors, "reward_ids", reward_ids)
	_validate_unique_ids(errors, "return_incentive_ids", return_incentive_ids)
	for index in activity_ids.size():
		_validate_id(errors, "activity %d" % index, StringName(activity_ids[index]))
		if index < objective_ids.size():
			_validate_id(errors, "objective %d" % index, StringName(objective_ids[index]))
		if index < activity_authority_ids.size():
			var activity_authority := StringName(activity_authority_ids[index])
			_validate_id(errors, "activity authority %d" % index, activity_authority)
			if not EXISTING_ACTIVITY_AUTHORITY_IDS.has(activity_authority):
				errors.append("activity %d is not tied to an existing activity authority" % index)
		if index < reward_ids.size():
			_validate_id(errors, "reward %d" % index, StringName(reward_ids[index]))
		if index < activity_reward_store_ids.size():
			var store := StringName(activity_reward_store_ids[index])
			_validate_id(errors, "reward store %d" % index, store)
			if store != reward_store_id:
				errors.append("duplicate reward store authority at activity %d" % index)
		if index < return_incentive_ids.size():
			var incentive := StringName(return_incentive_ids[index])
			_validate_id(errors, "return incentive %d" % index, incentive)
			if not String(incentive).begins_with("return_"):
				errors.append("return incentive %d must begin with return_" % index)
		if index < activity_recovery_ids.size():
			var recovery := StringName(activity_recovery_ids[index])
			_validate_id(errors, "recovery %d" % index, recovery)
			if not EXISTING_RECOVERY_IDS.has(recovery):
				errors.append("activity %d is not tied to an existing recovery state" % index)
	if _unique_values(activity_reward_store_ids).size() > 1:
		errors.append("handoff must declare one reward store, not duplicate stores")


func _validate_activity_records(errors: PackedStringArray, records: Array) -> void:
	if records.size() < MIN_ACTIVITIES or records.size() > MAX_ITEMS:
		errors.append("handoff activities must contain the authored activity roster")
	var seen := {}
	for index in records.size():
		var record: Variant = records[index]
		if not record is Dictionary:
			errors.append("activity handoff %d must be a dictionary" % index)
			continue
		var item := record as Dictionary
		var activity_id := StringName(item.get("activity_id", &""))
		if seen.has(activity_id):
			errors.append("duplicate activity handoff ID: %s" % activity_id)
		seen[activity_id] = true
		if not EXISTING_ACTIVITY_AUTHORITY_IDS.has(StringName(item.get("activity_authority_id", &""))):
			errors.append("activity handoff %d references an unknown activity authority" % index)
		if StringName(item.get("reward_store_id", &"")) != reward_store_id:
			errors.append("activity handoff %d references a duplicate reward store" % index)
		if StringName(item.get("return_target_id", &"")) != return_target_id:
			errors.append("activity handoff %d has the wrong return target" % index)


func _validate_unique_ids(errors: PackedStringArray, field_name: String, values: PackedStringArray) -> void:
	var seen := {}
	for value in values:
		var id := StringName(value)
		if seen.has(id):
			errors.append("%s must not contain duplicate IDs" % field_name)
		seen[id] = true


func _unique_values(values: PackedStringArray) -> Array[StringName]:
	var result: Array[StringName] = []
	for value in values:
		var id := StringName(value)
		if not result.has(id):
			result.append(id)
	return result


func _validate_evidence(errors: PackedStringArray) -> void:
	if evidence_references.is_empty():
		errors.append("evidence_references must contain an authored record")
	for reference in evidence_references:
		if String(reference).length() > 256 or not String(reference).begins_with("res://"):
			errors.append("evidence references must be bounded res:// paths")
	if evidence_notes.length() > MAX_NOTE_LENGTH:
		errors.append("evidence_notes exceeds the bounded note length")


func _validate_id(errors: PackedStringArray, field_name: String, value: StringName) -> void:
	var text := String(value)
	if text.is_empty() or text.length() > MAX_ID_LENGTH or text.begins_with("_") or text.ends_with("_") or text.contains("__"):
		errors.append("%s must be lowercase snake_case" % field_name)
		return
	for code in text.to_ascii_buffer():
		if not ((code >= 97 and code <= 122) or (code >= 48 and code <= 57) or code == 95):
			errors.append("%s must be lowercase snake_case" % field_name)
			return
