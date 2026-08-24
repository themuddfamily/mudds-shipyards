class_name StationDefenseEncounterDefinition
extends Resource

## Checked-in, data-only content for one StationDefenseContract.
##
## Runtime activity state is created by StationDefenseEncounterHost. This
## resource owns no clock, scene instance, combat state, protected asset, or
## reward. Flat packed arrays keep the authored roster deterministic and make
## every content bound inspectable without introducing mutable wave objects.

const SCHEMA_VERSION := 1
const MAX_CONTENT_HOSTILES := 8
const EVIDENCE_STATUS: StringName = &"modern_interpretation"

const _AUTHORITY_EXCLUSIONS := {
	"activity_progression": false,
	"combat_resolution": false,
	"health": false,
	"damage": false,
	"rewards": false,
	"runtime_scene_instantiation": false,
	"protected_asset_lifecycle": false,
	"ships": false,
	"berths": false,
	"world_geometry": false,
	"hud": false,
	"game_flow": false,
	"main": false,
	"save": false,
	"network": false,
}

@export_category("Identity")
@export var activity_id: StringName = &"station_defense_encounter"
@export var display_name := "Station defense encounter"
@export_multiline var content_note := "Original station-defense content; no historical encounter is authenticated."
@export var hostile_faction_id: StringName = &"station_defense_hostiles"

@export_category("Waves")
@export var wave_ids := PackedStringArray()
@export var wave_modes := PackedInt32Array()
@export var wave_delays_seconds := PackedFloat32Array()
@export var wave_hostile_counts := PackedInt32Array()
@export var hostile_ids := PackedStringArray()
@export var hostile_generations := PackedInt32Array()

@export_category("Protected assets")
@export var protected_asset_ids := PackedStringArray()
@export var protected_asset_generations := PackedInt32Array()

@export_category("Timing")
@export_range(0.1, 86400.0, 0.1) var timeout_seconds := 60.0
@export_range(0.25, 3.0, 0.05) var later_wave_opening_duration_seconds := 1.25


func instantiate_contract() -> StationDefenseContract:
	return StationDefenseContract.new(
		activity_id,
		_build_waves(),
		_build_protected_assets(),
		timeout_seconds
	) as StationDefenseContract


func get_ordered_hostile_handles() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for index in hostile_ids.size():
		result.append({
			"hostile_id": StringName(hostile_ids[index]),
			"generation": (
				int(hostile_generations[index])
				if index < hostile_generations.size()
				else 0
			),
		})
	return result


func get_validation_errors() -> PackedStringArray:
	var errors := PackedStringArray()
	if not StationDefenseContract.is_stable_id(activity_id):
		errors.append("activity_id must be a stable identifier")
	if display_name.is_empty() or display_name != display_name.strip_edges() \
		or display_name.contains("\n") or display_name.contains("\r"):
		errors.append("display_name must be non-empty, trimmed, and single-line")
	if content_note.is_empty() or content_note != content_note.strip_edges():
		errors.append("content_note must be non-empty and trimmed")
	if not StationDefenseContract.is_stable_id(hostile_faction_id):
		errors.append("hostile_faction_id must be a stable identifier")
	if wave_ids.is_empty() or wave_ids.size() > StationDefenseContract.MAX_WAVES:
		errors.append("wave count is outside the StationDefenseContract bound")
	if wave_modes.size() != wave_ids.size() \
		or wave_delays_seconds.size() != wave_ids.size() \
		or wave_hostile_counts.size() != wave_ids.size():
		errors.append("wave arrays must have identical lengths")
	if hostile_ids.is_empty() or hostile_ids.size() > MAX_CONTENT_HOSTILES:
		errors.append("hostile count is outside the encounter-content bound")
	if hostile_generations.size() != hostile_ids.size():
		errors.append("hostile ID and generation arrays must have identical lengths")
	if protected_asset_ids.is_empty() \
		or protected_asset_ids.size() > StationDefenseContract.MAX_PROTECTED_ASSETS:
		errors.append("protected asset count is outside the StationDefenseContract bound")
	if protected_asset_generations.size() != protected_asset_ids.size():
		errors.append("protected asset ID and generation arrays must have identical lengths")
	var partition_total := 0
	for count in wave_hostile_counts:
		if count <= 0 or count > StationDefenseContract.MAX_HOSTILES_PER_WAVE:
			errors.append("each wave hostile count must be within the contract bound")
		partition_total += maxi(0, count)
	if partition_total != hostile_ids.size():
		errors.append("wave hostile counts must partition the exact hostile roster")
	if (
		not is_finite(later_wave_opening_duration_seconds)
		or later_wave_opening_duration_seconds < 0.25
		or later_wave_opening_duration_seconds > 3.0
	):
		errors.append("later-wave opening duration must remain within 0.25 and 3 seconds")

	# Reuse the production contract's exact ID, generation, mode, delay, duplicate,
	# and timeout validation rather than maintaining a second interpretation.
	var contract := instantiate_contract()
	for contract_error in contract.get_configuration_errors():
		if contract_error not in errors:
			errors.append(contract_error)
	errors.sort()
	return errors


func is_definition_valid() -> bool:
	return get_validation_errors().is_empty()


func get_evidence_metadata() -> Dictionary:
	return {
		"schema_version": SCHEMA_VERSION,
		"component_id": activity_id,
		"evidence_status": EVIDENCE_STATUS,
		"historically_supported": false,
		"authenticated_original_encounter": false,
		"claims_historical_wave_plan": false,
		"modern_interpretations": PackedStringArray([
			"station perimeter defense objective",
			"ordered probe followed by a breaker-and-feint relief opening",
			"bounded heavy-picket reinforcement and counterplay window",
			"spawn positions, keep-clear radii, delay, and timeout",
		]),
		"explicit_unknowns": PackedStringArray([
			"any historical Keth Shipyards defense encounter or hostile wave plan",
		]),
		"content_note": content_note,
	}.duplicate(true)


func audit() -> Dictionary:
	var errors := get_validation_errors()
	var contract := instantiate_contract()
	return {
		"schema_version": SCHEMA_VERSION,
		"valid": errors.is_empty(),
		"errors": errors,
		"display_name": display_name,
		"contract": contract.get_snapshot(),
		"hostile_faction_id": hostile_faction_id,
		"wave_count": wave_ids.size(),
		"hostile_count": hostile_ids.size(),
		"protected_asset_count": protected_asset_ids.size(),
		"limits": {
			"maximum_content_hostiles": MAX_CONTENT_HOSTILES,
			"maximum_waves": StationDefenseContract.MAX_WAVES,
			"maximum_hostiles_per_wave": StationDefenseContract.MAX_HOSTILES_PER_WAVE,
			"later_wave_opening_duration_seconds": later_wave_opening_duration_seconds,
		},
		"evidence": get_evidence_metadata(),
		"authority_exclusions": _AUTHORITY_EXCLUSIONS.duplicate(true),
	}.duplicate(true)


func _build_waves() -> Array[Dictionary]:
	var waves: Array[Dictionary] = []
	var hostile_offset := 0
	for wave_index in wave_ids.size():
		var handles: Array[Dictionary] = []
		var count := (
			maxi(0, int(wave_hostile_counts[wave_index]))
			if wave_index < wave_hostile_counts.size()
			else 0
		)
		for local_index in count:
			var hostile_index := hostile_offset + local_index
			handles.append({
				"hostile_id": (
					StringName(hostile_ids[hostile_index])
					if hostile_index < hostile_ids.size()
					else &""
				),
				"generation": (
					int(hostile_generations[hostile_index])
					if hostile_index < hostile_generations.size()
					else 0
				),
			})
		hostile_offset += count
		waves.append({
			"wave_id": StringName(wave_ids[wave_index]),
			"mode": int(wave_modes[wave_index]) if wave_index < wave_modes.size() else -1,
			"delay_seconds": (
				float(wave_delays_seconds[wave_index])
				if wave_index < wave_delays_seconds.size()
				else NAN
			),
			"hostile_handles": handles,
		})
	return waves


func _build_protected_assets() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for index in protected_asset_ids.size():
		result.append({
			"asset_id": StringName(protected_asset_ids[index]),
			"generation": (
				int(protected_asset_generations[index])
				if index < protected_asset_generations.size()
				else 0
			),
		})
	return result
