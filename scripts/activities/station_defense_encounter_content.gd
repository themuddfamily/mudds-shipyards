class_name StationDefenseEncounterContent
extends Node3D

## Checked-in production composition for one bounded station-defense encounter.
##
## This node discovers only its authored children, validates their stable handle
## metadata and physical staging volumes, then registers the pre-created
## RangeOpponent roster with StationDefenseEncounterHost. A caller must inject
## its existing LiveCombatAuthority; this content never owns a resolver.

signal snapshot_changed(snapshot: Dictionary)

const SCHEMA_VERSION := 1
const COMPONENT_ID: StringName = &"shipyard_perimeter_defense_content"
const EVIDENCE_STATUS: StringName = &"modern_interpretation"
const MAX_AUTHORED_NODE_COUNT := 24
const MIN_KEEP_CLEAR_RADIUS := 8.0
const MIN_KEEP_CLEAR_GAP := 4.0
const HOSTILE_WEAPON_ID: StringName = &"perimeter_defense_pulse"
const LATER_WAVE_TACTIC_ID: StringName = &"dockside_crossfire_pincer"
const LATER_WAVE_ID: StringName = &"dockside_relief"
const PINCER_CLOSE_HOSTILE_ID: StringName = &"perimeter_raider_beta"
const PINCER_OUTER_HOSTILE_ID: StringName = &"perimeter_raider_gamma"
const PINCER_CLOSE_PREFERRED_RANGE := 22.0
const PINCER_OUTER_PREFERRED_RANGE := 74.0
const PINCER_CLOSE_ORBIT_SIGN := -1.0
const PINCER_OUTER_ORBIT_SIGN := 1.0
const PINCER_CLOSE_TELEGRAPH_RADIUS := 0.24
const PINCER_OUTER_TELEGRAPH_RADIUS := 0.16
const PINCER_CLOSE_TELEGRAPH_POSITIONS := [
	Vector3(-0.62, 0.58, -4.98),
	Vector3(0.62, 0.58, -4.98),
]
const PINCER_OUTER_TELEGRAPH_POSITIONS := [
	Vector3(-3.55, 0.58, -4.30),
	Vector3(3.55, 0.58, -4.30),
]
const INTEGRITY_STATE_STABLE: StringName = &"stable"
const INTEGRITY_STATE_UNDER_FIRE: StringName = &"under_fire"
const INTEGRITY_STATE_CRITICAL: StringName = &"critical"
const INTEGRITY_STATE_FAILED: StringName = &"failed"
const HOSTILE_WEAPON_PROFILES := {
	HOSTILE_WEAPON_ID: {
		"range": 170.0,
		"damage": 11.0,
		"origin_tolerance": 18.0,
	},
}
const HOSTILE_SOURCE_ID_BY_ID := {
	&"perimeter_raider_alpha": 2121,
	&"perimeter_raider_beta": 2122,
	&"perimeter_raider_gamma": 2123,
}

## Local-space origins audited at world pose (90, 0, -10). The player envelope
## is advisory integration data; the hostile leash is enforced whenever the
## caller advances objective physics.
const PLAYER_SHIP_ORIGIN_ENVELOPE := AABB(
	Vector3(-20.0, 4.0, -90.0),
	Vector3(40.0, 12.0, 40.0)
)
const HOSTILE_ORIGIN_LEASH := AABB(
	Vector3(-34.0, -1.0, -96.0),
	Vector3(68.0, 22.0, 72.0)
)
const AUDITED_WORLD_TRANSFORM := Transform3D(
	Basis.IDENTITY,
	Vector3(90.0, 0.0, -10.0)
)

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

@export var contract_definition: StationDefenseEncounterDefinition

var _initialized := false
var _initialization_errors := PackedStringArray()
var _host: StationDefenseEncounterHost
var _combat_authority: LiveCombatAuthority
var _spawn_staging: Node3D
var _opponent_roster: Node3D
var _protected_asset: StationDefensePerimeterAsset
var _entity_by_key: Dictionary = {}
var _staging_by_key: Dictionary = {}
var _registered_source_keys: Dictionary = {}
var _content_mutation_active := false
var _publish_pending := false
var _last_hostile_shot: Dictionary = {}
var _last_leash_exit: Dictionary = {}
var _configuration_state: StringName = &"awaiting_external_authority"
var _last_live_world_transform := AUDITED_WORLD_TRANSFORM
var _later_wave_tactic_state: StringName = &"idle"
var _later_wave_tactic_generation := 0
var _later_wave_tactic_applied := false
var _nominal_tactic_configuration_by_key: Dictionary = {}


func _enter_tree() -> void:
	_last_live_world_transform = global_transform
	if _initialized:
		call_deferred("_restore_after_reentry")
	elif (
		_configuration_state == &"configured_pending_tree"
		and is_instance_valid(_combat_authority)
	):
		# A retained content subtree may receive its caller-owned authority while
		# streamed out. `_ready()` does not run again when that subtree returns,
		# so only this tree-current callback may finish the accepted configuration.
		call_deferred("_initialize_pending_configuration_after_reentry")


func _exit_tree() -> void:
	_last_live_world_transform = global_transform
	if _initialized:
		_restore_later_wave_tactic_configuration()
		_retire_hostile_sources()


func _ready() -> void:
	_last_live_world_transform = global_transform
	_resolve_authored_nodes()
	if is_instance_valid(_combat_authority):
		_initialize_checked_in_content()
	else:
		_publish_snapshot()


func _initialize_pending_configuration_after_reentry() -> void:
	if (
		is_queued_for_deletion()
		or not is_inside_tree()
		or _initialized
		or _configuration_state != &"configured_pending_tree"
		or not is_instance_valid(_combat_authority)
	):
		return
	_initialize_checked_in_content()


## Injects the exact caller-owned session authority. The encounter scene has no
## internal LiveCombatAuthority or CombatResolver node and cannot replace this
## identity after configuration.
func configure_external_combat_authority(
	combat_authority: LiveCombatAuthority
	) -> Dictionary:
	if _content_mutation_active:
		return _content_result(false, &"reentrant_call")
	if _initialized or _configuration_state == &"configured_pending_tree":
		return _content_result(false, &"already_configured")
	if not _initialization_errors.is_empty():
		return _content_result(false, &"configuration_failed_terminal")
	if not is_instance_valid(combat_authority):
		return _content_result(false, &"combat_authority_required")
	if is_ancestor_of(combat_authority):
		return _content_result(false, &"combat_authority_must_be_external")
	var resolver := combat_authority.get_resolver()
	if not is_instance_valid(resolver):
		return _content_result(false, &"combat_resolver_required")

	_content_mutation_active = true
	_combat_authority = combat_authority
	_configuration_state = &"configured_pending_tree"
	if is_inside_tree():
		_initialize_checked_in_content()
	_content_mutation_active = false
	_flush_publish()
	if _initialized or not is_inside_tree():
		return _content_result(true, &"configured")
	return _content_result(false, &"configuration_failed_terminal")


func is_content_ready() -> bool:
	return _initialized


func get_host() -> StationDefenseEncounterHost:
	return _host if is_instance_valid(_host) else null


func get_combat_authority() -> LiveCombatAuthority:
	return _combat_authority if is_instance_valid(_combat_authority) else null


## Detached exact roster proof for the three production-composed hostile combat
## sources. The content owns their authored identity mapping but not the shared
## authority; callers can include this bounded roster in a wider authority census
## without reaching into private nodes or accepting count-only substitutions.
func get_live_source_registration_contract() -> Dictionary:
	var errors := PackedStringArray()
	var rows: Array[Dictionary] = []
	var expected_keys: Dictionary = {}
	var exact_registration_count := 0
	if not _initialized:
		errors.append("station-defense content is not initialized")
	if not is_instance_valid(_combat_authority):
		errors.append("station-defense external combat authority is unavailable")
	elif is_ancestor_of(_combat_authority):
		errors.append("station-defense combat authority must remain external")
	elif not is_instance_valid(_combat_authority.get_resolver()):
		errors.append("station-defense external combat resolver is unavailable")
	if contract_definition == null:
		errors.append("station-defense contract definition is unavailable")
	else:
		for handle in contract_definition.get_ordered_hostile_handles():
			var hostile_id := StringName(handle.get("hostile_id", &""))
			var key := StationDefenseContract.handle_key(handle, "hostile_id")
			var entity := _entity_by_key.get(key) as RangeOpponent
			var source_id := int(HOSTILE_SOURCE_ID_BY_ID.get(hostile_id, 0))
			var retained_source_id := int(_registered_source_keys.get(key, 0))
			var exact := (
				is_instance_valid(entity)
				and entity.is_inside_tree()
				and not entity.is_queued_for_deletion()
				and source_id > 0
				and retained_source_id == source_id
				and _hostile_source_registration_is_exact(entity, source_id)
			)
			expected_keys[key] = true
			if exact:
				exact_registration_count += 1
			else:
				errors.append("station-defense hostile source registration is not exact: %s" % key)
			rows.append({
				"hostile_id": hostile_id,
				"handle_generation": int(handle.get("generation", -1)),
				"source_id": source_id,
				"retained_source_id": retained_source_id,
				"entity_instance_id": entity.get_instance_id() if is_instance_valid(entity) else 0,
				"faction_id": (
					_combat_authority.get_source_faction(entity)
					if is_instance_valid(_combat_authority) and is_instance_valid(entity)
					else &""
				),
				"weapon_profile": (
					_combat_authority.get_weapon_profile(entity, HOSTILE_WEAPON_ID)
					if is_instance_valid(_combat_authority) and is_instance_valid(entity)
					else {}
				),
				"exact": exact,
			})
	for retained_key in _registered_source_keys:
		if not expected_keys.has(retained_key):
			errors.append("station-defense retained an unauthored hostile source key: %s" % retained_key)
	if _registered_source_keys.size() != HOSTILE_SOURCE_ID_BY_ID.size():
		errors.append("station-defense hostile source key count is not exact")
	if rows.size() != HOSTILE_SOURCE_ID_BY_ID.size():
		errors.append("station-defense hostile source row count is not exact")
	errors.sort()
	return {
		"schema_version": SCHEMA_VERSION,
		"component_id": COMPONENT_ID,
		"valid": errors.is_empty(),
		"errors": errors,
		"authority_instance_id": (
			_combat_authority.get_instance_id()
			if is_instance_valid(_combat_authority) else 0
		),
		"resolver_instance_id": (
			_combat_authority.get_resolver().get_instance_id()
			if is_instance_valid(_combat_authority)
			and is_instance_valid(_combat_authority.get_resolver()) else 0
		),
		"expected_source_count": HOSTILE_SOURCE_ID_BY_ID.size(),
		"registered_source_key_count": _registered_source_keys.size(),
		"exact_registration_count": exact_registration_count,
		"faction_id": (
			contract_definition.hostile_faction_id
			if contract_definition != null else &""
		),
		"weapon_id": HOSTILE_WEAPON_ID,
		"expected_weapon_profile": (
			HOSTILE_WEAPON_PROFILES[HOSTILE_WEAPON_ID] as Dictionary
		).duplicate(true),
		"sources": rows,
	}.duplicate(true)


func get_generation() -> int:
	return _host.get_generation() if is_instance_valid(_host) else 0


func get_protected_asset() -> StationDefensePerimeterAsset:
	return _protected_asset if is_instance_valid(_protected_asset) else null


func start(expected_generation: int) -> Dictionary:
	if _content_mutation_active:
		return _content_result(false, &"reentrant_call")
	if not _initialized:
		return _content_result(false, &"content_not_ready")
	if not _live_pose_matches_audited_site():
		return _content_result(false, &"audited_world_pose_required")
	if not is_instance_valid(_protected_asset) \
		or bool(_protected_asset.get_snapshot().get("destroyed", true)):
		return _content_result(false, &"protected_asset_unavailable")
	_content_mutation_active = true
	var source_errors := PackedStringArray()
	_wire_hostile_combat(source_errors)
	if not source_errors.is_empty():
		_content_mutation_active = false
		_flush_publish()
		return _content_result(false, &"hostile_combat_wiring_failed")
	_last_leash_exit.clear()
	var result := _host.start(expected_generation)
	_content_mutation_active = false
	_flush_publish()
	return result


## Delegates caller-owned physics time; this content has no process callback or
## wall-clock gameplay authority.
func advance_physics(delta: float, expected_generation: int) -> Dictionary:
	if _content_mutation_active:
		return _content_result(false, &"reentrant_call")
	if not _initialized:
		return _content_result(false, &"content_not_ready")
	if not _live_pose_matches_audited_site():
		_content_mutation_active = true
		var placement_abort := _host.abort(expected_generation)
		_content_mutation_active = false
		_flush_publish()
		if bool(placement_abort.get("accepted", false)):
			return _content_result(false, &"audited_world_pose_changed")
		return placement_abort
	var leash_exit := _find_leash_exit()
	if not leash_exit.is_empty():
		_content_mutation_active = true
		_last_leash_exit = leash_exit.duplicate(true)
		var aborted := _host.abort(expected_generation)
		_content_mutation_active = false
		_flush_publish()
		if bool(aborted.get("accepted", false)):
			return _content_result(false, &"engagement_leash_exited")
		return aborted
	return _host.advance_physics(delta, expected_generation)


func protected_asset_damaged(
	asset_handle: Dictionary,
	event_handle: Dictionary,
	expected_generation: int
	) -> Dictionary:
	if not _initialized:
		return _content_result(false, &"content_not_ready")
	return _host.protected_asset_damaged(asset_handle, event_handle, expected_generation)


func protected_asset_destroyed(
	asset_handle: Dictionary,
	event_handle: Dictionary,
	expected_generation: int
	) -> Dictionary:
	if not _initialized:
		return _content_result(false, &"content_not_ready")
	return _host.protected_asset_destroyed(asset_handle, event_handle, expected_generation)


func fail(reason: StringName, expected_generation: int) -> Dictionary:
	if not _initialized:
		return _content_result(false, &"content_not_ready")
	return _host.fail(reason, expected_generation)


func abort(expected_generation: int) -> Dictionary:
	if not _initialized:
		return _content_result(false, &"content_not_ready")
	return _host.abort(expected_generation)


func reset(expected_generation: int) -> Dictionary:
	if _content_mutation_active:
		return _content_result(false, &"reentrant_call")
	if not _initialized:
		return _content_result(false, &"content_not_ready")
	var old_handle := _protected_asset.get_asset_handle()
	var next_handle := _protected_asset.get_next_asset_handle()
	if next_handle.is_empty():
		return _content_result(false, &"protected_asset_generation_exhausted")
	var physical_preflight := _protected_asset.preflight_renew(
		int(old_handle.get("generation", -1))
	)
	if not bool(physical_preflight.get("accepted", false)):
		var rejected := _content_result(
			false, &"protected_asset_renewal_preflight_failed"
		)
		rejected["preflight_reason"] = physical_preflight.get("reason", &"unknown")
		return rejected.duplicate(true)
	_content_mutation_active = true
	var reset_result := _host.reset(expected_generation)
	if not bool(reset_result.get("accepted", false)):
		_content_mutation_active = false
		_flush_publish()
		return reset_result
	var reset_activity := reset_result.get("activity", {}) as Dictionary
	var renewed_handle := _host.renew_protected_asset_handle(
		old_handle,
		next_handle,
		int(reset_activity.get("generation", -1))
	)
	if not bool(renewed_handle.get("accepted", false)):
		_content_mutation_active = false
		_flush_publish()
		return _content_result(false, &"protected_asset_handle_renewal_failed")
	var renewed_asset := _protected_asset.renew(int(old_handle.generation))
	if bool(renewed_asset.get("accepted", false)):
		_apply_protected_asset_presentation()
	_content_mutation_active = false
	_flush_publish()
	if not bool(renewed_asset.get("accepted", false)):
		return _content_result(false, &"protected_asset_renewal_failed")
	var result := _host.get_snapshot()
	result["accepted"] = true
	result["reason"] = &"reset"
	return result.duplicate(true)


## Restores only a terminal history generation into fresh IDLE production
## content. The loaded activity itself is never resumed: no enemy activates,
## no damage/health record is applied, and no reward or combat source is created.
func restore_terminal_session_history(history: Dictionary) -> Dictionary:
	if _content_mutation_active or not _initialized:
		return _content_result(false, &"content_unavailable")
	var state_id := StringName(history.get("state_id", &""))
	var history_generation := int(history.get("generation", -1))
	var activity := _host.get_snapshot().get("activity", {}) as Dictionary
	if (
		state_id not in [&"idle", &"completed", &"failed"]
		or history_generation < 0
		or StringName(activity.get("state_id", &"")) != &"idle"
		or int(activity.get("generation", -1)) != 0
	):
		return _content_result(false, &"pristine_idle_restore_required")
	var target_generation := history_generation + 1
	if target_generation > StationDefenseContract.MAX_SAFE_INTEGER:
		return _content_result(false, &"generation_exhausted")
	var target_handle := {
		"asset_id": StationDefensePerimeterAsset.ASSET_ID,
		"generation": target_generation,
	}
	var asset_preflight := _protected_asset.preflight_pristine_generation_restore(
		target_generation
	)
	if not bool(asset_preflight.get("accepted", false)):
		return _content_result(false, &"pristine_asset_restore_required")
	_content_mutation_active = true
	var host_restore := _host.restore_idle_session_generation(
		target_generation, target_handle
	)
	if not bool(host_restore.get("accepted", false)):
		_content_mutation_active = false
		_flush_publish()
		return host_restore
	var asset_restore := _protected_asset.restore_pristine_generation(target_generation)
	_content_mutation_active = false
	_apply_protected_asset_presentation()
	_flush_publish()
	if not bool(asset_restore.get("accepted", false)):
		return _content_result(false, &"asset_generation_restore_failed")
	return _content_result(true, &"terminal_history_restored_as_idle")


func get_evidence_metadata() -> Dictionary:
	return {
		"schema_version": SCHEMA_VERSION,
		"component_id": COMPONENT_ID,
		"evidence_status": EVIDENCE_STATUS,
		"historically_supported": false,
		"authenticated_original_encounter": false,
		"authenticated_spawn_geometry": false,
		"claims_historical_wave_plan": false,
		"modern_interpretations": PackedStringArray([
			"the station-defense encounter itself",
			"all hostile spawn transforms and keep-clear volumes",
			"the wave grouping, ordering, delay, and timeout",
			"the dedicated renewable protected perimeter asset",
			"the bounded engagement and hostile source wiring",
		]),
		"explicit_unknowns": PackedStringArray([
			"any historical Keth Shipyards defense encounter or spawn arrangement",
		]),
		"content_note": (
			contract_definition.content_note
			if contract_definition != null
			else "Encounter definition unavailable."
		),
	}.duplicate(true)


## HUD-safe primitive snapshot. Node and Resource references never escape.
func get_snapshot() -> Dictionary:
	var host_snapshot := (
		_host.get_snapshot()
		if is_instance_valid(_host)
		else {
			"configured": false,
			"activity": {"state_id": "idle", "generation": 0},
			"spawn_roster": [],
		}
	)
	var activity := (host_snapshot.get("activity", {}) as Dictionary).duplicate(true)
	var tactic_feedback := _get_later_wave_tactic_feedback(activity)
	var integrity_feedback := _get_protected_asset_integrity_feedback(activity)
	var objective := str(tactic_feedback.get("objective", "DEFEND PERIMETER BEACON"))
	if (
		StringName(integrity_feedback.get("state_id", INTEGRITY_STATE_STABLE))
		!= INTEGRITY_STATE_STABLE
		and (
			StringName(activity.get("state_id", &"idle")) == &"active"
			or StringName(integrity_feedback.get("state_id", &""))
			== INTEGRITY_STATE_FAILED
		)
	):
		objective = "%s // %s" % [
			objective,
			str(integrity_feedback.get("retained_status", "PERIMETER STATUS UNKNOWN")),
		]
	activity["tactic_id"] = tactic_feedback.get("tactic_id", &"")
	activity["tactic_state_id"] = tactic_feedback.get("state_id", &"idle")
	activity["protected_asset_integrity"] = integrity_feedback.duplicate(true)
	activity["protected_asset_integrity_state"] = integrity_feedback.get(
		"state_id", INTEGRITY_STATE_STABLE
	)
	activity["protected_asset_integrity_percent"] = int(
		integrity_feedback.get("health_percent", 0)
	)
	activity["protected_asset_integrity_text"] = str(
		integrity_feedback.get("retained_status", "")
	)
	activity["next_step"] = objective
	activity["objective_text"] = objective
	host_snapshot["activity"] = activity
	var contract_snapshot: Dictionary = (
		contract_definition.instantiate_contract().get_snapshot()
		if contract_definition != null
		else {}
	)
	if is_instance_valid(_protected_asset):
		contract_snapshot["protected_asset_handles"] = [
			_protected_asset.get_asset_handle(),
		]
	return {
		"schema_version": SCHEMA_VERSION,
		"component_id": COMPONENT_ID,
		"content_ready": _initialized,
		"configuration_state": _configuration_state,
		"initialization_errors": _initialization_errors.duplicate(),
		"contract": contract_snapshot,
		"host": host_snapshot,
		"staging": _get_staging_snapshot(),
		"protected_asset": (
			_protected_asset.get_snapshot()
			if is_instance_valid(_protected_asset)
			else {}
		),
		"opponent_count": _entity_by_key.size(),
		"authored_node_count": _count_authored_nodes(self),
		"precreated_roster_wired": (
			_initialized
			and int(host_snapshot.get("spawn_roster_count", 0)) == _entity_by_key.size()
		),
		"external_combat_authority_injected": is_instance_valid(_combat_authority),
		"owns_combat_authority": false,
		"registered_hostile_source_count": _registered_source_keys.size(),
		"hostile_weapon_id": HOSTILE_WEAPON_ID,
		"last_hostile_shot": _last_hostile_shot.duplicate(true),
		"last_leash_exit": _last_leash_exit.duplicate(true),
		"later_wave_tactic": tactic_feedback,
		"protected_asset_integrity": integrity_feedback,
		"engagement": {
			"required_world_transform": AUDITED_WORLD_TRANSFORM,
			"live_world_transform": _get_live_world_transform(),
			"live_pose_matches_required": _live_pose_matches_audited_site(),
			"player_ship_origin_envelope": PLAYER_SHIP_ORIGIN_ENVELOPE,
			"hostile_origin_leash": HOSTILE_ORIGIN_LEASH,
			"leash_exit_policy": &"public_host_abort_then_source_retirement",
		},
		"uses_caller_physics_delta": true,
		"evidence": get_evidence_metadata(),
		"authority_exclusions": _AUTHORITY_EXCLUSIONS.duplicate(true),
	}.duplicate(true)


func audit() -> Dictionary:
	var errors := _collect_composition_errors(false)
	for initialization_error in _initialization_errors:
		_append_unique(errors, initialization_error)
	if not _initialized:
		_append_unique(errors, "checked-in encounter content is not initialized")
	if is_instance_valid(_host):
		var host_audit := _host.audit()
		if not bool(host_audit.get("valid", false)):
			for host_error in host_audit.get("errors", PackedStringArray()):
				_append_unique(errors, "host: %s" % host_error)
	if is_instance_valid(_protected_asset):
		var asset_audit := _protected_asset.audit()
		if not bool(asset_audit.get("valid", false)):
			for asset_error in asset_audit.get("errors", PackedStringArray()):
				_append_unique(errors, "protected asset: %s" % asset_error)
	errors.sort()
	return {
		"schema_version": SCHEMA_VERSION,
		"component_id": COMPONENT_ID,
		"valid": errors.is_empty(),
		"errors": errors,
		"snapshot": get_snapshot(),
		"limits": {
			"maximum_authored_node_count": MAX_AUTHORED_NODE_COUNT,
			"maximum_content_hostiles": StationDefenseEncounterDefinition.MAX_CONTENT_HOSTILES,
			"minimum_keep_clear_radius": MIN_KEEP_CLEAR_RADIUS,
			"minimum_keep_clear_gap": MIN_KEEP_CLEAR_GAP,
			"hostile_source_count": HOSTILE_SOURCE_ID_BY_ID.size(),
			"hostile_leash_local": HOSTILE_ORIGIN_LEASH,
			"player_ship_origin_envelope_local": PLAYER_SHIP_ORIGIN_ENVELOPE,
		},
		"evidence": get_evidence_metadata(),
		"authority_exclusions": _AUTHORITY_EXCLUSIONS.duplicate(true),
	}.duplicate(true)


func _initialize_checked_in_content() -> void:
	if _initialized or not _initialization_errors.is_empty():
		return
	_resolve_authored_nodes()
	_initialization_errors = _collect_composition_errors(true)
	if not _initialization_errors.is_empty():
		_configuration_state = &"configuration_failed_terminal"
		_publish_snapshot()
		return

	var contract := contract_definition.instantiate_contract()
	var source_errors := PackedStringArray()
	_acquire_hostile_sources_atomically(source_errors)
	if not source_errors.is_empty():
		for source_error in source_errors:
			_initialization_errors.append(source_error)
		_initialization_errors.sort()
		_configuration_state = &"configuration_failed_terminal"
		_publish_snapshot()
		return
	var configured := _host.configure(contract, _combat_authority)
	if not bool(configured.get("accepted", false)):
		_forget_hostile_sources()
		_initialization_errors.append(
			"host configuration failed: %s" % String(configured.get("reason", &"unknown"))
		)
		_configuration_state = &"configuration_failed_terminal"
		_publish_snapshot()
		return
	for handle in contract_definition.get_ordered_hostile_handles():
		var key := StationDefenseContract.handle_key(handle, "hostile_id")
		var entity := _entity_by_key.get(key) as RangeOpponent
		var staging := _staging_by_key.get(key, {}) as Dictionary
		var marker := staging.get("marker") as Marker3D
		var registered := _host.register_hostile(
			handle,
			entity,
			marker.global_transform,
			contract_definition.hostile_faction_id
		)
		if not bool(registered.get("accepted", false)):
			_initialization_errors.append(
				"hostile %s registration failed: %s" % [
					key, String(registered.get("reason", &"unknown")),
				]
				)
	_capture_nominal_tactic_configuration()
	_wire_protected_asset()
	var combat_errors := PackedStringArray()
	_wire_hostile_combat(combat_errors)
	for combat_error in combat_errors:
		_initialization_errors.append(combat_error)
	if not _initialization_errors.is_empty():
		_forget_hostile_sources()
		_initialization_errors.sort()
		_configuration_state = &"configuration_failed_terminal"
		_publish_snapshot()
		return
	if not _host.snapshot_changed.is_connected(_on_host_snapshot_changed):
		_host.snapshot_changed.connect(_on_host_snapshot_changed)
	_initialized = true
	_configuration_state = &"ready"
	_publish_snapshot()


func _resolve_authored_nodes() -> void:
	_host = get_node_or_null(^"Host") as StationDefenseEncounterHost
	_spawn_staging = get_node_or_null(^"SpawnStaging") as Node3D
	_opponent_roster = get_node_or_null(^"OpponentRoster") as Node3D
	_protected_asset = get_node_or_null(^"ProtectedPerimeterAsset") as StationDefensePerimeterAsset


func _collect_composition_errors(rebuild_lookups: bool) -> PackedStringArray:
	var errors := PackedStringArray()
	if contract_definition == null:
		errors.append("contract definition is required")
	else:
		for definition_error in contract_definition.get_validation_errors():
			_append_unique(errors, "definition: %s" % definition_error)
	if not is_instance_valid(_host):
		errors.append("Host must be a StationDefenseEncounterHost")
	if not is_instance_valid(_combat_authority):
		errors.append("an external LiveCombatAuthority must be injected")
	elif is_ancestor_of(_combat_authority):
		errors.append("the injected LiveCombatAuthority must not be content-owned")
	elif not is_instance_valid(_combat_authority.get_resolver()):
		errors.append("the injected authority must expose its existing CombatResolver")
	if get_node_or_null(^"CombatAuthority") != null \
		or not find_children("*", "CombatResolver", true, false).is_empty():
		errors.append("encounter content may not own a combat authority or resolver")
	if not _live_pose_matches_audited_site():
		errors.append("encounter live transform differs from the audited world site")
	if not is_instance_valid(_spawn_staging):
		errors.append("SpawnStaging must be a Node3D")
	if not is_instance_valid(_opponent_roster):
		errors.append("OpponentRoster must be a Node3D")
	if not is_instance_valid(_protected_asset):
		errors.append("ProtectedPerimeterAsset must be the dedicated renewable asset")
	elif StringName(_protected_asset.get_asset_handle().asset_id) \
		!= StationDefensePerimeterAsset.ASSET_ID:
		errors.append("protected perimeter asset ID differs from the contract")
	var authored_count := _count_authored_nodes(self)
	if authored_count > MAX_AUTHORED_NODE_COUNT:
		errors.append("authored node count exceeds the checked-in content bound")
	if contract_definition == null \
		or not is_instance_valid(_spawn_staging) \
		or not is_instance_valid(_opponent_roster) \
		or not is_instance_valid(_protected_asset):
		errors.sort()
		return errors
	if rebuild_lookups:
		_entity_by_key.clear()
		_staging_by_key.clear()
		_collect_entities(errors)
		_collect_staging(errors)
	_validate_lookup_coverage(errors)
	_validate_keep_clear_separation(errors)
	_validate_runtime_wiring(errors)
	errors.sort()
	return errors


func _collect_entities(errors: PackedStringArray) -> void:
	for child in _opponent_roster.get_children():
		var entity := child as RangeOpponent
		if entity == null:
			errors.append("OpponentRoster may contain only RangeOpponent instances")
			continue
		var handle := _metadata_handle(entity)
		var key := StationDefenseContract.handle_key(handle, "hostile_id")
		if not _handle_metadata_valid(handle):
			errors.append("opponent %s has invalid stable handle metadata" % entity.name)
		elif _entity_by_key.has(key):
			errors.append("duplicate opponent handle metadata: %s" % key)
		else:
			_entity_by_key[key] = entity
		if entity.is_active():
			errors.append("opponent %s must be dormant before host registration" % entity.name)


func _collect_staging(errors: PackedStringArray) -> void:
	for child in _spawn_staging.get_children():
		var marker := child as Marker3D
		if marker == null:
			errors.append("SpawnStaging may contain only Marker3D children")
			continue
		var handle := _metadata_handle(marker)
		var key := StationDefenseContract.handle_key(handle, "hostile_id")
		if not _handle_metadata_valid(handle):
			errors.append("spawn marker %s has invalid stable handle metadata" % marker.name)
			continue
		if _staging_by_key.has(key):
			errors.append("duplicate spawn marker handle metadata: %s" % key)
			continue
		var area := marker.get_node_or_null(^"KeepClearVolume") as Area3D
		var collision := (
			area.get_node_or_null(^"CollisionShape3D") as CollisionShape3D
			if area != null
			else null
		)
		var sphere := collision.shape as SphereShape3D if collision != null else null
		if area == null or collision == null or sphere == null:
			errors.append("spawn marker %s requires one spherical keep-clear volume" % marker.name)
			continue
		if area.position != Vector3.ZERO or collision.position != Vector3.ZERO:
			errors.append("spawn marker %s keep-clear volume must be marker-centered" % marker.name)
		if area.collision_layer != 0 or area.collision_mask != 0 \
			or area.monitoring or area.monitorable:
			errors.append("spawn marker %s keep-clear volume must be query-inert" % marker.name)
		var radius := _world_sphere_radius(collision, sphere)
		if not is_finite(radius) or radius < MIN_KEEP_CLEAR_RADIUS:
			errors.append("spawn marker %s keep-clear radius is below its bound" % marker.name)
		if not _transform_is_finite_and_nondegenerate(marker.global_transform):
			errors.append("spawn marker %s transform is invalid" % marker.name)
		_staging_by_key[key] = {
			"marker": marker,
			"area": area,
			"collision": collision,
			"radius": radius,
			"world_position": collision.global_position,
		}


func _validate_lookup_coverage(errors: PackedStringArray) -> void:
	var expected_keys: Dictionary = {}
	for handle in contract_definition.get_ordered_hostile_handles():
		var key := StationDefenseContract.handle_key(handle, "hostile_id")
		expected_keys[key] = true
		if not _entity_by_key.has(key):
			errors.append("contract hostile lacks a pre-created opponent: %s" % key)
		if not _staging_by_key.has(key):
			errors.append("contract hostile lacks a physical spawn marker: %s" % key)
	for key in _entity_by_key:
		if not expected_keys.has(key):
			errors.append("pre-created opponent is outside the contract: %s" % key)
	for key in _staging_by_key:
		if not expected_keys.has(key):
			errors.append("spawn marker is outside the contract: %s" % key)
	if _entity_by_key.size() > StationDefenseEncounterDefinition.MAX_CONTENT_HOSTILES:
		errors.append("pre-created opponent roster exceeds the content bound")


func _validate_keep_clear_separation(errors: PackedStringArray) -> void:
	var ordered := contract_definition.get_ordered_hostile_handles()
	for left_index in ordered.size():
		var left_key := StationDefenseContract.handle_key(ordered[left_index], "hostile_id")
		var left := _staging_by_key.get(left_key, {}) as Dictionary
		if left.is_empty():
			continue
		var left_position := _staging_world_position(left)
		for right_index in range(left_index + 1, ordered.size()):
			var right_key := StationDefenseContract.handle_key(ordered[right_index], "hostile_id")
			var right := _staging_by_key.get(right_key, {}) as Dictionary
			if right.is_empty():
				continue
			var right_position := _staging_world_position(right)
			var required := float(left.radius) + float(right.radius) + MIN_KEEP_CLEAR_GAP
			if left_position.distance_to(right_position) < required:
				errors.append("spawn keep-clear volumes overlap: %s / %s" % [left_key, right_key])


func _get_staging_snapshot() -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	if contract_definition == null:
		return rows
	for handle in contract_definition.get_ordered_hostile_handles():
		var key := StationDefenseContract.handle_key(handle, "hostile_id")
		var staging := _staging_by_key.get(key, {}) as Dictionary
		var marker := staging.get("marker") as Marker3D
		var world_position := _staging_world_position(staging)
		if is_instance_valid(marker) and marker.is_inside_tree():
			staging["world_position"] = world_position
		rows.append({
			"hostile_id": handle.hostile_id,
			"generation": int(handle.generation),
			"marker_name": String(marker.name) if is_instance_valid(marker) else "",
			"local_position": marker.position if is_instance_valid(marker) else Vector3.INF,
			"world_position": world_position,
			"keep_clear_radius": float(staging.get("radius", 0.0)),
			"query_inert": (
				is_instance_valid(staging.get("area"))
				and int((staging.area as Area3D).collision_layer) == 0
				and int((staging.area as Area3D).collision_mask) == 0
			),
		})
	return rows


func _wire_protected_asset() -> void:
	if not is_instance_valid(_protected_asset):
		return
	if not _protected_asset.asset_damaged.is_connected(_on_protected_asset_damaged):
		_protected_asset.asset_damaged.connect(_on_protected_asset_damaged)
	if not _protected_asset.asset_destroyed.is_connected(_on_protected_asset_destroyed):
		_protected_asset.asset_destroyed.connect(_on_protected_asset_destroyed)
	_apply_protected_asset_presentation()


func _apply_protected_asset_presentation() -> Dictionary:
	if not is_instance_valid(_protected_asset):
		return _content_result(false, &"protected_asset_unavailable")
	var asset_result := _protected_asset.apply_authority_presentation_snapshot(
		_protected_asset.get_snapshot()
	)
	if is_instance_valid(_host):
		var activity := _host.get_snapshot().get("activity", {}) as Dictionary
		_protected_asset.apply_activity_presentation_snapshot(activity)
		_apply_active_hostile_bearing(activity)
	return asset_result


func _apply_active_hostile_bearing(activity: Dictionary) -> Dictionary:
	if not is_instance_valid(_protected_asset):
		return _content_result(false, &"protected_asset_unavailable")
	var activity_generation := int(activity.get("generation", 0))
	var bearing_sum := Vector3.ZERO
	var bearing_count := 0
	for handle: Dictionary in activity.get("active_hostile_handles", []) as Array:
		var key := StationDefenseContract.handle_key(handle, "hostile_id")
		var entity := _entity_by_key.get(key) as RangeOpponent
		if not is_instance_valid(entity):
			continue
		var direction := entity.global_position - _protected_asset.global_position
		direction.y = 0.0
		if direction.is_finite() and direction.length_squared() > 0.000001:
			bearing_sum += direction.normalized()
			bearing_count += 1
	var active := (
		StringName(activity.get("state_id", &"")) == &"active"
		and bool(activity.get("wave_active", false))
		and bearing_count > 0
		and bearing_sum.length_squared() > 0.000001
	)
	return _protected_asset.apply_hostile_bearing_presentation_snapshot({
		"asset_handle": _protected_asset.get_asset_handle(),
		"activity_generation": activity_generation,
		"active": active,
		"bearing_world": bearing_sum.normalized() if active else Vector3.ZERO,
	})


func _capture_nominal_tactic_configuration() -> void:
	if not _nominal_tactic_configuration_by_key.is_empty():
		return
	for key_variant in _entity_by_key:
		var key := str(key_variant)
		var entity := _entity_by_key.get(key) as RangeOpponent
		if not is_instance_valid(entity) or StringName(
			entity.get_meta("hostile_id", &"")
		) not in [PINCER_CLOSE_HOSTILE_ID, PINCER_OUTER_HOSTILE_ID]:
			continue
		_nominal_tactic_configuration_by_key[key] = {
			"preferred_range": entity.preferred_range,
			"orbit_sign": float(entity.get("_orbit_sign")),
			"telegraph_node_paths": (
				entity.get_weapon_telegraph_mesh_allocation_audit().get(
					"node_paths", PackedStringArray()
				) as PackedStringArray
			).duplicate(),
			"telegraph_positions": _get_tactic_telegraph_positions(entity),
			"telegraph_radius": _get_tactic_telegraph_radius(entity),
		}.duplicate(true)


func _sync_later_wave_tactic(activity: Dictionary) -> void:
	var state_id := StringName(activity.get("state_id", &"idle"))
	var generation := int(activity.get("generation", 0))
	var wave_id := StringName(activity.get("wave_id", &""))
	var wave_active := bool(activity.get("wave_active", false))
	if state_id == &"idle":
		_restore_later_wave_tactic_configuration()
		_later_wave_tactic_state = &"idle"
		_later_wave_tactic_generation = 0
		return
	if state_id in [&"completed", &"failed", &"aborted", &"timed_out"]:
		_restore_later_wave_tactic_configuration()
		_later_wave_tactic_state = state_id
		return
	if state_id != &"active" or wave_id != LATER_WAVE_ID:
		_restore_later_wave_tactic_configuration()
		_later_wave_tactic_state = &"standby"
		return

	_later_wave_tactic_generation = generation
	if not wave_active:
		_restore_later_wave_tactic_configuration()
		_later_wave_tactic_state = &"forming"
		return
	var active_ids: Array[StringName] = []
	for handle: Dictionary in activity.get("active_hostile_handles", []) as Array:
		active_ids.append(StringName(handle.get("hostile_id", &"")))
	if PINCER_CLOSE_HOSTILE_ID in active_ids and PINCER_OUTER_HOSTILE_ID in active_ids:
		_apply_later_wave_tactic_configuration()
		_later_wave_tactic_state = &"active"
		return
	_restore_later_wave_tactic_configuration()
	_later_wave_tactic_state = &"broken"


func _apply_later_wave_tactic_configuration() -> void:
	var close_entity := _get_tactic_entity(PINCER_CLOSE_HOSTILE_ID)
	var outer_entity := _get_tactic_entity(PINCER_OUTER_HOSTILE_ID)
	if not is_instance_valid(close_entity) or not is_instance_valid(outer_entity):
		_restore_later_wave_tactic_configuration()
		return
	_later_wave_tactic_applied = true
	close_entity.preferred_range = PINCER_CLOSE_PREFERRED_RANGE
	close_entity.set("_orbit_sign", PINCER_CLOSE_ORBIT_SIGN)
	outer_entity.preferred_range = PINCER_OUTER_PREFERRED_RANGE
	outer_entity.set("_orbit_sign", PINCER_OUTER_ORBIT_SIGN)
	if (
		not _apply_tactic_telegraph_identity(
			close_entity,
			PINCER_CLOSE_TELEGRAPH_POSITIONS,
			PINCER_CLOSE_TELEGRAPH_RADIUS
		)
		or not _apply_tactic_telegraph_identity(
			outer_entity,
			PINCER_OUTER_TELEGRAPH_POSITIONS,
			PINCER_OUTER_TELEGRAPH_RADIUS
		)
	):
		_restore_later_wave_tactic_configuration()


func _restore_later_wave_tactic_configuration() -> void:
	if not _later_wave_tactic_applied:
		return
	for key_variant in _nominal_tactic_configuration_by_key:
		var key := str(key_variant)
		var entity := _entity_by_key.get(key) as RangeOpponent
		var nominal := _nominal_tactic_configuration_by_key.get(key, {}) as Dictionary
		if not is_instance_valid(entity) or nominal.is_empty():
			continue
		entity.preferred_range = float(nominal.get("preferred_range", entity.preferred_range))
		entity.set("_orbit_sign", float(nominal.get("orbit_sign", 1.0)))
		var telegraphs := _get_tactic_telegraph_nodes(
			entity,
			nominal.get("telegraph_node_paths", PackedStringArray()) as PackedStringArray
		)
		var nominal_positions := nominal.get("telegraph_positions", []) as Array
		for index in mini(telegraphs.size(), nominal_positions.size()):
			telegraphs[index].position = nominal_positions[index] as Vector3
		var nominal_radius := float(nominal.get("telegraph_radius", 0.0))
		if nominal_radius > 0.0:
			for telegraph in telegraphs:
				var sphere := telegraph.mesh as SphereMesh
				if sphere != null:
					sphere.radius = nominal_radius
					sphere.height = nominal_radius * 2.0
	_later_wave_tactic_applied = false


func _get_tactic_telegraph_nodes(
	entity: RangeOpponent,
	node_paths: PackedStringArray = PackedStringArray()
	) -> Array[MeshInstance3D]:
	var nodes: Array[MeshInstance3D] = []
	if not is_instance_valid(entity):
		return nodes
	var visual := entity.get_node_or_null(^"RangeInterceptorVisual") as Node3D
	if not is_instance_valid(visual):
		return nodes
	var paths := node_paths
	if paths.is_empty():
		paths = entity.get_weapon_telegraph_mesh_allocation_audit().get(
			"node_paths", PackedStringArray()
		) as PackedStringArray
	for path_text in paths:
		var telegraph := visual.get_node_or_null(NodePath(path_text)) as MeshInstance3D
		if is_instance_valid(telegraph) and telegraph.mesh is SphereMesh:
			nodes.append(telegraph)
	return nodes


func _get_tactic_telegraph_positions(entity: RangeOpponent) -> Array[Vector3]:
	var positions: Array[Vector3] = []
	for telegraph in _get_tactic_telegraph_nodes(entity):
		positions.append(telegraph.position)
	return positions


func _get_tactic_telegraph_radius(entity: RangeOpponent) -> float:
	var telegraphs := _get_tactic_telegraph_nodes(entity)
	if telegraphs.is_empty():
		return 0.0
	var sphere := telegraphs[0].mesh as SphereMesh
	return sphere.radius if sphere != null else 0.0


func _apply_tactic_telegraph_identity(
	entity: RangeOpponent,
	positions: Array,
	radius: float
	) -> bool:
	var nominal := _nominal_tactic_configuration_by_key.get(
		_find_tactic_entity_key(entity), {}
	) as Dictionary
	var telegraphs := _get_tactic_telegraph_nodes(
		entity,
		nominal.get("telegraph_node_paths", PackedStringArray()) as PackedStringArray
	)
	if telegraphs.size() != positions.size() or radius <= 0.0:
		return false
	for telegraph in telegraphs:
		if not (telegraph.mesh is SphereMesh):
			return false
	for index in telegraphs.size():
		telegraphs[index].position = positions[index] as Vector3
		var sphere := telegraphs[index].mesh as SphereMesh
		sphere.radius = radius
		sphere.height = radius * 2.0
	return true


func _find_tactic_entity_key(entity: RangeOpponent) -> String:
	for key_variant in _entity_by_key:
		var key := str(key_variant)
		if _entity_by_key.get(key) == entity:
			return key
	return ""


func _get_tactic_entity(hostile_id: StringName) -> RangeOpponent:
	for entity_variant in _entity_by_key.values():
		var entity := entity_variant as RangeOpponent
		if is_instance_valid(entity) and StringName(
			entity.get_meta("hostile_id", &"")
		) == hostile_id:
			return entity
	return null


func _get_later_wave_tactic_feedback(activity: Dictionary) -> Dictionary:
	var state := _later_wave_tactic_state
	var objective := "CLEAR APPROACH RAIDER // DEFEND PERIMETER BEACON"
	var status := "CROSSFIRE PINCER // STANDBY"
	match state:
		&"idle":
			objective = "START PERIMETER DEFENSE"
			status = "CROSSFIRE PINCER // IDLE"
		&"forming":
			objective = "PINCER INBOUND // HOLD PERIMETER BEACON"
			status = "WAVE 2 // CROSSFIRE FORMING"
		&"active":
			objective = "BREAK CROSSFIRE PINCER // PROTECT BEACON"
			status = "BETA CLOSE // GAMMA OUTER"
		&"broken":
			objective = "PINCER BROKEN // FINISH REMAINING RAIDER"
			status = "CROSSFIRE BROKEN // NOMINAL PURSUIT"
		&"completed":
			objective = "PERIMETER SECURE // RECOVER AT DEFENSE BOARD"
			status = "CROSSFIRE DEFEATED"
		&"failed", &"aborted", &"timed_out":
			objective = "DEFENSE ENDED // RECOVER AT DEFENSE BOARD"
			status = "CROSSFIRE RETIRED"
	return {
		"tactic_id": LATER_WAVE_TACTIC_ID,
		"wave_id": LATER_WAVE_ID,
		"state_id": state,
		"generation": _later_wave_tactic_generation,
		"active": state == &"active",
		"applied": _later_wave_tactic_applied,
		"status": status,
		"objective": objective,
		"formation": [
			{
				"hostile_id": PINCER_CLOSE_HOSTILE_ID,
				"role": &"close_pressure",
				"preferred_range": PINCER_CLOSE_PREFERRED_RANGE,
				"orbit_sign": PINCER_CLOSE_ORBIT_SIGN,
				"telegraph_identity": &"compact_pair",
				"identity_pattern": "><",
				"presentation_active": state == &"active" and _later_wave_tactic_applied,
				"telegraph_positions": PINCER_CLOSE_TELEGRAPH_POSITIONS.duplicate(),
			},
			{
				"hostile_id": PINCER_OUTER_HOSTILE_ID,
				"role": &"outer_crossfire",
				"preferred_range": PINCER_OUTER_PREFERRED_RANGE,
				"orbit_sign": PINCER_OUTER_ORBIT_SIGN,
				"telegraph_identity": &"wide_guard",
				"identity_pattern": "|    |",
				"presentation_active": state == &"active" and _later_wave_tactic_applied,
				"telegraph_positions": PINCER_OUTER_TELEGRAPH_POSITIONS.duplicate(),
			},
		],
		"terminal_or_break_restores_nominal": true,
		"combat_authority": false,
		"damage_authority": false,
	}.duplicate(true)


## Retained, HUD-safe accessibility projection of the physical asset's one
## authoritative health store. Four text/pattern states complement the fixed
## beacon silhouette and align with the existing station-defense audio cues;
## this content never emits damage, owns health, or retains a second state.
func _get_protected_asset_integrity_feedback(activity: Dictionary) -> Dictionary:
	var asset_snapshot := (
		_protected_asset.get_snapshot()
		if is_instance_valid(_protected_asset)
		else {}
	)
	var maximum_health := maxf(float(asset_snapshot.get("maximum_health", 0.0)), 0.0)
	var health := clampf(
		float(asset_snapshot.get("health", 0.0)),
		0.0,
		maximum_health
	)
	var health_ratio := health / maximum_health if maximum_health > 0.0 else 0.0
	var health_percent := clampi(roundi(health_ratio * 100.0), 0, 100)
	var damage_event_count := int(asset_snapshot.get("damage_event_count", 0))
	var state_id := INTEGRITY_STATE_STABLE
	if bool(asset_snapshot.get("destroyed", true)) or health <= 0.0:
		state_id = INTEGRITY_STATE_FAILED
	elif health_ratio <= StationDefensePerimeterAsset.PRESENTATION_CRITICAL_THRESHOLD:
		state_id = INTEGRITY_STATE_CRITICAL
	elif (
		damage_event_count > 0
		or health_ratio <= StationDefensePerimeterAsset.PRESENTATION_SAFE_THRESHOLD
	):
		state_id = INTEGRITY_STATE_UNDER_FIRE

	var label := "PERIMETER CORE STABLE"
	var pattern := "[||||]"
	var semantic_cue_id: StringName = &"station_defense_asset_safe"
	match state_id:
		INTEGRITY_STATE_UNDER_FIRE:
			label = "PERIMETER CORE UNDER FIRE"
			pattern = "[|||!]"
			semantic_cue_id = &"station_defense_asset_danger"
		INTEGRITY_STATE_CRITICAL:
			label = "PERIMETER CORE CRITICAL"
			pattern = "[|!!!]"
			semantic_cue_id = &"station_defense_asset_critical"
		INTEGRITY_STATE_FAILED:
			label = "PERIMETER CORE FAILED"
			pattern = "[XXXX]"
			semantic_cue_id = &"station_defense_asset_destroyed"
	var retained_status := "%s %d%% %s" % [label, health_percent, pattern]
	return {
		"state_id": state_id,
		"label": label,
		"health_percent": health_percent,
		"pattern": pattern,
		"retained_status": retained_status,
		"semantic_cue_id": semantic_cue_id,
		"source_health": health,
		"source_maximum_health": maximum_health,
		"source_damage_event_count": damage_event_count,
		"source_asset_handle": (
			asset_snapshot.get("asset_handle", {}) as Dictionary
		).duplicate(true),
		"source_activity_state_id": StringName(activity.get("state_id", &"idle")),
		"state_count": 4,
		"uses_color_only": false,
		"health_authority": false,
		"damage_authority": false,
	}.duplicate(true)


func _acquire_hostile_sources_atomically(errors: PackedStringArray) -> void:
	if not is_instance_valid(_combat_authority):
		_append_unique(errors, "external combat authority is required")
		return
	var newly_acquired: Array[Dictionary] = []
	for handle in contract_definition.get_ordered_hostile_handles():
		var key := StationDefenseContract.handle_key(handle, "hostile_id")
		var entity := _entity_by_key.get(key) as RangeOpponent
		var hostile_id := StringName(handle.hostile_id)
		var source_id := int(HOSTILE_SOURCE_ID_BY_ID.get(hostile_id, 0))
		if not is_instance_valid(entity) or source_id <= 0:
			_append_unique(errors, "hostile source identity unavailable: %s" % key)
			break
		var exact_before := _hostile_source_registration_is_exact(entity, source_id)
		if not exact_before and not _combat_authority.register_source(
			entity,
			source_id,
			contract_definition.hostile_faction_id,
			HOSTILE_WEAPON_PROFILES
		):
			_append_unique(errors, "hostile source registration failed: %s" % key)
			break
		if not _hostile_source_registration_is_exact(entity, source_id):
			_append_unique(errors, "hostile source registration is not exact: %s" % key)
			break
		_registered_source_keys[key] = source_id
		if not exact_before:
			newly_acquired.append({"entity": entity, "source_id": source_id})
	if errors.is_empty():
		return
	for acquired in newly_acquired:
		var entity := acquired.get("entity") as RangeOpponent
		if is_instance_valid(entity):
			_combat_authority.forget_source(
				entity, int(acquired.get("source_id", 0))
			)
	_registered_source_keys.clear()


func _wire_hostile_combat(errors: PackedStringArray) -> void:
	if not is_instance_valid(_combat_authority) or not is_instance_valid(_protected_asset):
		_append_unique(errors, "external combat authority and protected asset are required")
		return
	for handle in contract_definition.get_ordered_hostile_handles():
		var key := StationDefenseContract.handle_key(handle, "hostile_id")
		var entity := _entity_by_key.get(key) as RangeOpponent
		var hostile_id := StringName(handle.hostile_id)
		var source_id := int(HOSTILE_SOURCE_ID_BY_ID.get(hostile_id, 0))
		if not is_instance_valid(entity) or source_id <= 0:
			_append_unique(errors, "hostile source identity unavailable: %s" % key)
			continue
		entity.set_target(_protected_asset)
		var projectile_callback := Callable(
			self,
			"_on_hostile_projectile_fired"
		).bind(entity)
		if not entity.projectile_fired.is_connected(projectile_callback):
			entity.projectile_fired.connect(projectile_callback)
		var registered := _combat_authority.register_source(
			entity,
			source_id,
			contract_definition.hostile_faction_id,
			HOSTILE_WEAPON_PROFILES
		)
		var exact_existing := _hostile_source_registration_is_exact(entity, source_id)
		if not registered and not exact_existing:
			_append_unique(errors, "hostile source registration failed: %s" % key)
			continue
		_registered_source_keys[key] = source_id


func _hostile_source_registration_is_exact(
	entity: RangeOpponent,
	source_id: int
	) -> bool:
	return is_instance_valid(entity) \
		and is_instance_valid(_combat_authority) \
		and _combat_authority.get_source_id(entity) == source_id \
		and _combat_authority.get_source_faction(entity) \
			== contract_definition.hostile_faction_id \
		and _combat_authority.get_weapon_profile(entity, HOSTILE_WEAPON_ID) \
			== (HOSTILE_WEAPON_PROFILES[HOSTILE_WEAPON_ID] as Dictionary)


func _retire_hostile_sources() -> void:
	if not is_instance_valid(_combat_authority):
		_registered_source_keys.clear()
		return
	for handle in contract_definition.get_ordered_hostile_handles():
		var key := StationDefenseContract.handle_key(handle, "hostile_id")
		var entity := _entity_by_key.get(key) as RangeOpponent
		var source_id := int(HOSTILE_SOURCE_ID_BY_ID.get(StringName(handle.hostile_id), 0))
		if is_instance_valid(entity) and _combat_authority.get_source_id(entity) == source_id:
			_combat_authority.retire_source_registration(entity, source_id)
	_registered_source_keys.clear()


func _forget_hostile_sources() -> void:
	if not is_instance_valid(_combat_authority):
		_registered_source_keys.clear()
		return
	for handle in contract_definition.get_ordered_hostile_handles():
		var key := StationDefenseContract.handle_key(handle, "hostile_id")
		var entity := _entity_by_key.get(key) as RangeOpponent
		var source_id := int(HOSTILE_SOURCE_ID_BY_ID.get(StringName(handle.hostile_id), 0))
		if is_instance_valid(entity) and _combat_authority.get_source_id(entity) == source_id:
			_combat_authority.forget_source(entity, source_id)
	_registered_source_keys.clear()


func _validate_runtime_wiring(errors: PackedStringArray) -> void:
	if contract_definition == null:
		return
	var seen_source_ids: Dictionary = {}
	for handle in contract_definition.get_ordered_hostile_handles():
		var key := StationDefenseContract.handle_key(handle, "hostile_id")
		var entity := _entity_by_key.get(key) as RangeOpponent
		var source_id := int(HOSTILE_SOURCE_ID_BY_ID.get(StringName(handle.hostile_id), 0))
		if source_id <= 0 or seen_source_ids.has(source_id):
			errors.append("hostile source IDs must be unique and positive")
		else:
			seen_source_ids[source_id] = true
		if _initialized and is_instance_valid(entity):
			var callback := Callable(self, "_on_hostile_projectile_fired").bind(entity)
			if not entity.projectile_fired.is_connected(callback):
				errors.append("hostile projectile bridge is disconnected: %s" % key)
	if _initialized and is_instance_valid(_protected_asset):
		var host_snapshot := _host.get_snapshot()
		var activity := host_snapshot.get("activity", {}) as Dictionary
		var protected_states := activity.get("protected_assets", []) as Array
		if protected_states.size() != 1 \
			or StationDefenseContract.handle_key(
				(protected_states[0] as Dictionary).handle,
				"asset_id"
			) != StationDefenseContract.handle_key(
				_protected_asset.get_asset_handle(),
				"asset_id"
			):
			errors.append("host and physical protected-asset generations differ")


func _find_leash_exit() -> Dictionary:
	for handle in contract_definition.get_ordered_hostile_handles():
		var key := StationDefenseContract.handle_key(handle, "hostile_id")
		var entity := _entity_by_key.get(key) as RangeOpponent
		if not is_instance_valid(entity) or not entity.is_active():
			continue
		var local_origin := to_local(entity.global_position)
		if not local_origin.is_finite() or not HOSTILE_ORIGIN_LEASH.has_point(local_origin):
			return {
				"hostile_id": handle.hostile_id,
				"handle_generation": int(handle.generation),
				"local_origin": local_origin,
				"activity_generation": get_generation(),
				"policy": &"abort_then_retire",
			}.duplicate(true)
	return {}


func _on_hostile_projectile_fired(
	origin: Vector3,
	direction: Vector3,
	entity: RangeOpponent
	) -> void:
	if _content_mutation_active \
		or not _initialized \
		or not is_instance_valid(entity) \
		or not entity.is_active() \
		or not is_instance_valid(_combat_authority):
		return
	var activity := _host.get_snapshot().get("activity", {}) as Dictionary
	if StringName(activity.get("state_id", &"")) != &"active":
		return
	var result := _combat_authority.submit_hitscan(
		entity,
		HOSTILE_WEAPON_ID,
		origin,
		direction
	)
	_last_hostile_shot = _detached_shot_result(result)
	_publish_snapshot()


func _on_protected_asset_damaged(
	asset_handle: Dictionary,
	event_handle: Dictionary
	) -> void:
	if _content_mutation_active or not _initialized:
		return
	_content_mutation_active = true
	_host.protected_asset_damaged(asset_handle, event_handle, get_generation())
	_apply_protected_asset_presentation()
	_content_mutation_active = false
	_flush_publish()


func _on_protected_asset_destroyed(
	asset_handle: Dictionary,
	event_handle: Dictionary
	) -> void:
	if _content_mutation_active or not _initialized:
		return
	_content_mutation_active = true
	_host.protected_asset_destroyed(asset_handle, event_handle, get_generation())
	_apply_protected_asset_presentation()
	_content_mutation_active = false
	_flush_publish()


func _restore_after_reentry() -> void:
	if not _initialized or is_queued_for_deletion() or not is_inside_tree():
		return
	var errors := PackedStringArray()
	_wire_protected_asset()
	_wire_hostile_combat(errors)
	if not errors.is_empty():
		for error in errors:
			_append_unique(_initialization_errors, error)
	if is_instance_valid(_host):
		_sync_later_wave_tactic(
			_host.get_snapshot().get("activity", {}) as Dictionary
		)
	_publish_snapshot()


func _detached_shot_result(result: Dictionary) -> Dictionary:
	return {
		"accepted": bool(result.get("accepted", false)),
		"resolved": bool(result.get("resolved", false)),
		"status": StringName(result.get("status", &"")),
		"source_id": int(result.get("source_id", 0)),
		"sequence": int(result.get("last_sequence", -1)),
		"hit": bool(result.get("hit", false)),
		"damaged": bool(result.get("damaged", false)),
		"destroyed": bool(result.get("destroyed", false)),
		"applied_damage": float(result.get("applied_damage", 0.0)),
		"remaining_health": float(result.get("remaining_health", 0.0)),
		"position": result.get("position", Vector3.INF) as Vector3,
	}.duplicate(true)


func _on_host_snapshot_changed(host_snapshot: Dictionary) -> void:
	var activity := host_snapshot.get("activity", {}) as Dictionary
	_sync_later_wave_tactic(activity)
	if is_instance_valid(_protected_asset):
		_protected_asset.apply_activity_presentation_snapshot(activity)
		_apply_active_hostile_bearing(activity)
	if StringName(activity.get("state_id", &"")) in [
		&"completed", &"failed", &"aborted", &"timed_out",
	]:
		_retire_hostile_sources()
	if _content_mutation_active:
		_publish_pending = true
		return
	_publish_snapshot()


func _publish_snapshot() -> void:
	snapshot_changed.emit(get_snapshot())


func _flush_publish() -> void:
	_publish_pending = false
	_publish_snapshot()


func _content_result(accepted: bool, reason: StringName) -> Dictionary:
	var result := get_snapshot()
	result["accepted"] = accepted
	result["reason"] = reason
	return result.duplicate(true)


func _count_authored_nodes(node: Node) -> int:
	var count := 1
	for child in node.get_children():
		count += 1
		if child is RangeOpponent:
			continue
		count += _count_authored_descendants(child)
	return count


func _count_authored_descendants(node: Node) -> int:
	var count := 0
	for child in node.get_children():
		count += 1
		if child is RangeOpponent:
			continue
		count += _count_authored_descendants(child)
	return count


func _live_pose_matches_audited_site() -> bool:
	return _get_live_world_transform().is_equal_approx(AUDITED_WORLD_TRANSFORM)


func _get_live_world_transform() -> Transform3D:
	if is_inside_tree():
		_last_live_world_transform = global_transform
	return _last_live_world_transform


static func _metadata_handle(node: Node) -> Dictionary:
	return {
		"hostile_id": StringName(node.get_meta("hostile_id", &"")),
		"generation": int(node.get_meta("handle_generation", 0)),
	}


static func _handle_metadata_valid(handle: Dictionary) -> bool:
	return StationDefenseContract.is_stable_id(handle.get("hostile_id", &"")) \
		and int(handle.get("generation", 0)) > 0 \
		and int(handle.get("generation", 0)) <= StationDefenseContract.MAX_SAFE_INTEGER


static func _world_sphere_radius(
	collision: CollisionShape3D,
	sphere: SphereShape3D
	) -> float:
	var scale := collision.global_basis.get_scale().abs()
	return sphere.radius * maxf(scale.x, maxf(scale.y, scale.z))


static func _staging_world_position(staging: Dictionary) -> Vector3:
	var collision := staging.get("collision") as CollisionShape3D
	if is_instance_valid(collision) and collision.is_inside_tree():
		return collision.global_position
	return staging.get("world_position", Vector3.INF) as Vector3


static func _transform_is_finite_and_nondegenerate(value: Transform3D) -> bool:
	return value.origin.is_finite() \
		and value.basis.x.is_finite() \
		and value.basis.y.is_finite() \
		and value.basis.z.is_finite() \
		and is_finite(value.basis.determinant()) \
		and absf(value.basis.determinant()) > 0.000001


static func _append_unique(errors: PackedStringArray, message: String) -> void:
	if message not in errors:
		errors.append(message)
