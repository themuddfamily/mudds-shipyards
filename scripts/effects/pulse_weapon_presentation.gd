class_name PulseWeaponPresentation
extends Node3D

## Bounded, presentation-only pulse weapon visuals for externally resolved hitscan.
##
## The caller owns firing cadence, ray queries, damage, hit selection, and audio.
## This component only displays already-resolved world-space shot geometry. Every
## runtime primitive is preallocated, every animation is a function of shot age,
## and saturated pools recycle the oldest visual without allocating scene nodes.

signal shot_presented(
	shot_id: int,
	style_id: StringName,
	source_instance_id: int,
	hit: bool
)
signal impact_started(
	shot_id: int,
	style_id: StringName,
	source_instance_id: int,
	position: Vector3
)
signal impact_receipt_ready(receipt_id: int, position: Vector3)
## A fail-safe completion for a resolved hit whose visual was retired before it
## could reach the endpoint (pool saturation, explicit clear, or tree exit).
## Gameplay authority is already committed; listeners use this only to release
## the corresponding delayed damage presentation instead of stranding it.
signal impact_receipt_aborted(receipt_id: int)
signal shot_finished(shot_id: int)
signal shot_recycled(retired_shot_id: int, replacement_shot_id: int)
signal effects_cleared
signal presentation_enabled_changed(enabled: bool)

const SCHEMA_VERSION := 2
const COMPONENT_ID: StringName = &"pulse-weapon-presentation"
const EVIDENCE_STATUS: StringName = &"modern_interpretation"
const VFX_ATLAS_PATH := "res://assets/effects/mudds-combat-vfx-atlas-v1.png"
const VFX_ATLAS_SHA256 := "e748314a287112a11f809b417fa262b184199715f029b0915b63ca8ccecd3aac"
const VFX_ATLAS: Texture2D = preload(VFX_ATLAS_PATH)

const STYLE_CYAN: StringName = &"cyan"
const STYLE_AMBER: StringName = &"amber"
const STYLE_MAGENTA: StringName = &"magenta"
const DEFAULT_STYLE_ID: StringName = STYLE_CYAN
const STYLE_IDS: Array[StringName] = [STYLE_CYAN, STYLE_AMBER, STYLE_MAGENTA]

## Static geometry profiles are independent from colour style: the courier and
## skirmisher deliberately share amber, but their tail turret and repeater must
## still read differently in silhouette. Profiles only scale retained pool
## nodes; they never alter travel timing, hit state, receipts, or authority.
const PROFILE_STANDARD: StringName = &"standard"
const PROFILE_SIEGE_LANCE: StringName = &"siege_lance"
const PROFILE_TAIL_TURRET: StringName = &"tail_turret"
const PROFILE_REPEATER: StringName = &"repeater"
const DEFAULT_PROFILE_ID: StringName = PROFILE_STANDARD
const PROFILE_IDS: Array[StringName] = [
	PROFILE_STANDARD,
	PROFILE_SIEGE_LANCE,
	PROFILE_TAIL_TURRET,
	PROFILE_REPEATER,
]

const STANDARD_TRAVEL_PULSE_SCALE := Vector3(1.18, 0.62, 1.0)
const SIEGE_LANCE_TRAVEL_PULSE_SCALE := Vector3(0.68, 1.72, 1.0)
const TAIL_TURRET_TRAVEL_PULSE_SCALE := Vector3(1.44, 0.46, 1.0)
const REPEATER_TRAVEL_PULSE_SCALE := Vector3(0.50, 0.78, 1.0)
const STANDARD_IMPACT_PROFILE_SCALE := Vector3.ONE
const SIEGE_LANCE_IMPACT_PROFILE_SCALE := Vector3(0.82, 1.55, 1.0)
const TAIL_TURRET_IMPACT_PROFILE_SCALE := Vector3(1.48, 0.72, 1.0)
const REPEATER_IMPACT_PROFILE_SCALE := Vector3(0.64, 0.64, 1.0)

const DEFAULT_POOL_CAPACITY := 6
const MAX_POOL_CAPACITY := 8
const BEAM_SEGMENTS_PER_SHOT := 3
const IMPACT_SPARKS_PER_HIT := 4
const MESHES_PER_SLOT := 11
const LIGHTS_PER_SLOT := 2
const NODES_PER_SLOT := 14
const MAX_VISIBLE_MESHES_PER_SHOT := 6
const MAX_VISIBLE_LIGHTS_PER_SHOT := 1
const RESOURCE_CATALOG_MESH_COUNT := 2
const RESOURCE_CATALOG_MATERIAL_COUNT := 9
const RESOURCE_CATALOG_RESOURCE_COUNT := (
	RESOURCE_CATALOG_MESH_COUNT + RESOURCE_CATALOG_MATERIAL_COUNT
)

const MIN_SHOT_DISTANCE := 0.05
const MAX_SHOT_DISTANCE := 2500.0
const PULSE_SPEED := 215.0
const MIN_TRAVEL_DURATION := 0.055
const MAX_TRAVEL_DURATION := 0.28
const MUZZLE_DURATION := 0.065
const MISS_TAIL_DURATION := 0.055
const IMPACT_DURATION := 0.24
const SEGMENT_LENGTH := 1.08
const SEGMENT_SPACING := 1.44
const MIN_VISIBLE_SEGMENT_LENGTH := 0.015

const CONTENT_NOTE := (
	"The authored atlas, segmented travelling pulse, muzzle flash, palette, timing, "
	+ "impact flare, directional backwash, spark arrangement, dimensions, and pooling policy are an original modern "
	+ "presentation treatment. They do not claim to reproduce an authenticated "
	+ "historical Keth Shipyards weapon effect or weapon-system behaviour."
)

## Visual resources are immutable after their first build and identical for every
## component instance. Keep only the Resource identities process-wide; all pool
## nodes, slot dictionaries, transforms, visibility, lights, and lifecycle state
## remain owned by each PulseWeaponPresentation instance.
static var _process_resource_catalog: Dictionary = {}
static var _process_resource_catalog_build_count := 0

@export_category("Bounded presentation")
@export_range(1, MAX_POOL_CAPACITY, 1) var pool_capacity := DEFAULT_POOL_CAPACITY
@export var starts_enabled := true
@export var starts_auto_advance := true

@onready var _pool_root: Node3D = get_node(^"PoolRoot") as Node3D

var _built := false
var _built_pool_capacity := DEFAULT_POOL_CAPACITY
var _built_starts_enabled := true
var _built_starts_auto_advance := true
var _presentation_enabled := true
var _auto_advance_enabled := true
var _enabled_overridden := false
var _auto_advance_overridden := false

var _shared_meshes: Dictionary = {}
var _style_materials: Dictionary = {}
var _atlas_materials: Dictionary = {}
var _slots: Array[Dictionary] = []
var _built_node_instance_ids: Dictionary = {}
var _built_material_contracts: Dictionary = {}
var _built_atlas_material_contracts: Dictionary = {}
var _built_mesh_contracts: Dictionary = {}

var _next_shot_id := 1
## Monotonic transaction identity for each accepted pool activation. Unlike the
## public shot ID, this is deliberately never reset by `reset_for_reuse()` so an
## in-flight advance can exclude every activation created by its callbacks.
var _latest_activation_serial := 0
var _active_effect_count := 0
var _presented_count := 0
var _finished_count := 0
var _recycled_count := 0
var _rejected_count := 0
var _lifecycle_transaction_active := false


func _enter_tree() -> void:
	# `_ready()` runs only once. Re-entry must restore desired processing without
	# reviving effects that were synchronously cleared on the previous exit.
	if _built:
		_refresh_lifecycle()


func _ready() -> void:
	if _built:
		_refresh_lifecycle()
		return
	_built = true
	_built_pool_capacity = clampi(pool_capacity, 1, MAX_POOL_CAPACITY)
	_built_starts_enabled = starts_enabled
	_built_starts_auto_advance = starts_auto_advance
	if not _enabled_overridden:
		_presentation_enabled = starts_enabled
	if not _auto_advance_overridden:
		_auto_advance_enabled = starts_auto_advance
	_apply_evidence_metadata()
	_build_shared_resources()
	_build_pool()
	_capture_built_contract()
	_refresh_lifecycle()


func _process(delta: float) -> void:
	advance_simulation(delta)


func _exit_tree() -> void:
	_lifecycle_transaction_active = true
	var aborted_receipts := _clear_effects_internal(false, false)
	set_process(false)
	_emit_aborted_receipts(aborted_receipts)
	_lifecycle_transaction_active = false


func get_component_id() -> StringName:
	return COMPONENT_ID


func is_lifecycle_transaction_active() -> bool:
	return _lifecycle_transaction_active


## Displays an externally resolved hitscan in world space.
##
## Returns `false` without mutating the pool when geometry, style, lifecycle,
## or the optional source reference is invalid. `source_entity` is reduced to
## its instance ID; the component never retains or modifies the source node.
func present_shot(
		origin: Vector3,
		end: Vector3,
		style_id: StringName = DEFAULT_STYLE_ID,
		source_entity: Node = null,
		hit: bool = false,
		presentation_receipt_id: int = -1,
		profile_id: StringName = DEFAULT_PROFILE_ID
	) -> bool:
	if not _can_mutate_current_presentation():
		return false
	if not _can_present(origin, end, style_id, profile_id, source_entity):
		_rejected_count += 1
		return false

	var slot_index := _find_available_slot()
	if slot_index < 0:
		_rejected_count += 1
		return false

	var retired_shot_id := 0
	var aborted_receipt_id := -1
	var slot: Dictionary = _slots[slot_index]
	if bool(slot.get("active", false)):
		retired_shot_id = int(slot.get("shot_id", 0))
		# Retire atomically but emit completion only after the replacement has been
		# fully installed. A synchronous signal handler may present another shot;
		# no outer mutation may overwrite that nested transaction.
		aborted_receipt_id = _deactivate_slot(slot_index, false)
		_recycled_count += 1

	var shot_id := _next_shot_id
	_next_shot_id += 1
	var distance := origin.distance_to(end)
	var travel_duration := clampf(
		distance / PULSE_SPEED,
		MIN_TRAVEL_DURATION,
		MAX_TRAVEL_DURATION
	)
	var source_instance_id := source_entity.get_instance_id() if source_entity != null else 0
	_latest_activation_serial += 1

	slot = _slots[slot_index]
	slot["active"] = true
	slot["activation_serial"] = _latest_activation_serial
	slot["shot_id"] = shot_id
	slot["origin"] = origin
	slot["end"] = end
	slot["direction"] = (end - origin) / distance
	slot["distance"] = distance
	slot["style_id"] = style_id
	slot["profile_id"] = profile_id
	slot["source_instance_id"] = source_instance_id
	slot["hit"] = hit
	slot["impact_started"] = false
	slot["presentation_receipt_id"] = presentation_receipt_id
	slot["age"] = 0.0
	slot["travel_duration"] = travel_duration
	slot["total_lifetime"] = travel_duration + (IMPACT_DURATION if hit else MISS_TAIL_DURATION)
	_slots[slot_index] = slot
	_active_effect_count += 1
	_presented_count += 1
	_apply_slot_style(slot_index)
	_update_slot(slot_index)
	_refresh_lifecycle()

	# All state mutation is complete before the signal tail begins. Presentation
	# must be observable before any re-entrant recycle callback can retire this
	# replacement, preserving presented-before-finished for every accepted shot.
	shot_presented.emit(shot_id, style_id, source_instance_id, hit)
	if retired_shot_id > 0:
		shot_recycled.emit(retired_shot_id, shot_id)
		shot_finished.emit(retired_shot_id)
	if aborted_receipt_id >= 0:
		impact_receipt_aborted.emit(aborted_receipt_id)
	return true


## Deterministically advances all live visuals. This is available even when
## automatic processing is disabled, which keeps captures and tests reproducible.
func advance_simulation(delta: float) -> bool:
	if not _can_mutate_current_presentation():
		return false
	if (
		not _built
		or not _presentation_enabled
		or not is_finite(delta)
		or delta <= 0.0
		or _active_effect_count <= 0
	):
		return false
	# A callback may accept new shots while this method is walking the pool. Only
	# activations that existed at entry receive this delta; a callback-created
	# activation starts at age zero and waits for the next explicit advance.
	var activation_cutoff := _latest_activation_serial
	var advanced := false
	for slot_index in _slots.size():
		var slot: Dictionary = _slots[slot_index]
		if not bool(slot.get("active", false)):
			continue
		if int(slot.get("activation_serial", 0)) > activation_cutoff:
			continue
		slot["age"] = float(slot.get("age", 0.0)) + delta
		_slots[slot_index] = slot
		if float(slot["age"]) >= float(slot["total_lifetime"]):
			# A hitch may cross both arrival and retirement in one frame. Publish the
			# endpoint transition before completion even when no impact frame can be
			# drawn. Re-entrant callbacks may recycle this slot, so retire only the
			# activation that entered this transaction.
			if bool(slot.get("hit", false)) and not bool(slot.get("impact_started", false)):
				_update_slot(slot_index)
			var live_slot: Dictionary = _slots[slot_index]
			if (
				bool(live_slot.get("active", false))
				and int(live_slot.get("activation_serial", 0)) == int(slot.get("activation_serial", 0))
			):
				_deactivate_slot(slot_index, true)
		else:
			_update_slot(slot_index)
		advanced = true
	_refresh_lifecycle()
	return advanced


## Alias with an explicit domain name for callers that avoid generic methods.
func advance_shot_simulation(delta: float) -> bool:
	return advance_simulation(delta)


## Immediately hides every active slot. No nodes or resources are freed, so a
## subsequent shot reuses the same immutable pool without allocation.
func clear_effects() -> void:
	if not _can_mutate_current_presentation():
		return
	_clear_effects_internal(true)


## Retires only transients launched by one source. This is the scenario-craft
## teardown seam: withdrawing a pooled opponent cannot leave its fan crossing
## the world, and no sibling craft's presentation is disturbed.
func clear_source_effects(source_entity: Node) -> int:
	if (
		not _can_mutate_current_presentation()
		or not is_instance_valid(source_entity)
		or _lifecycle_transaction_active
	):
		return 0
	var source_instance_id := source_entity.get_instance_id()
	var retired := 0
	var aborted_receipts: Array[int] = []
	_lifecycle_transaction_active = true
	for slot_index in _slots.size():
		var slot: Dictionary = _slots[slot_index]
		if (
			bool(slot.get("active", false))
			and int(slot.get("source_instance_id", 0)) == source_instance_id
		):
			var aborted_receipt_id := _deactivate_slot(slot_index, false)
			if aborted_receipt_id >= 0:
				aborted_receipts.append(aborted_receipt_id)
			retired += 1
	_refresh_lifecycle()
	_emit_aborted_receipts(aborted_receipts)
	_lifecycle_transaction_active = false
	return retired


## Clears active visuals and statistics while preserving the allocated pool.
## This is the explicit reentry API for recycled combat/world presentations.
func reset_for_reuse() -> void:
	if not _can_mutate_current_presentation():
		return
	_lifecycle_transaction_active = true
	var aborted_receipts := _clear_effects_internal(false, false)
	_next_shot_id = 1
	_presented_count = 0
	_finished_count = 0
	_recycled_count = 0
	_rejected_count = 0
	_presentation_enabled = true
	_enabled_overridden = true
	_refresh_lifecycle()
	_emit_aborted_receipts(aborted_receipts)
	_lifecycle_transaction_active = false
	effects_cleared.emit()


func set_presentation_enabled(enabled: bool) -> void:
	if not _can_mutate_current_presentation():
		return
	_enabled_overridden = true
	if _presentation_enabled == enabled:
		_refresh_lifecycle()
		return
	_presentation_enabled = enabled
	if not enabled:
		_lifecycle_transaction_active = true
		var aborted_receipts := _clear_effects_internal(true, false)
		_emit_aborted_receipts(aborted_receipts)
		_lifecycle_transaction_active = false
	else:
		_refresh_lifecycle()
	presentation_enabled_changed.emit(enabled)


func is_presentation_enabled() -> bool:
	return _presentation_enabled


func set_auto_advance_enabled(enabled: bool) -> void:
	if not _can_mutate_current_presentation():
		return
	_auto_advance_overridden = true
	_auto_advance_enabled = enabled
	_refresh_lifecycle()


func is_auto_advance_enabled() -> bool:
	return _auto_advance_enabled


func get_active_effect_count() -> int:
	return _active_effect_count


func get_pool_capacity() -> int:
	return _built_pool_capacity if _built else clampi(pool_capacity, 1, MAX_POOL_CAPACITY)


func get_supported_style_ids() -> Array[StringName]:
	return STYLE_IDS.duplicate()


func get_supported_profile_ids() -> Array[StringName]:
	return PROFILE_IDS.duplicate()


func get_statistics() -> Dictionary:
	return {
		"presented": _presented_count,
		"finished": _finished_count,
		"recycled": _recycled_count,
		"rejected": _rejected_count,
		"active": _active_effect_count,
		"capacity": get_pool_capacity(),
	}.duplicate(true)


func get_active_shot_snapshots() -> Array[Dictionary]:
	var snapshots: Array[Dictionary] = []
	for slot: Dictionary in _slots:
		if not bool(slot.get("active", false)):
			continue
		var age := float(slot.get("age", 0.0))
		var travel_duration := float(slot.get("travel_duration", MIN_TRAVEL_DURATION))
		var pulse := slot.get("pulse") as MeshInstance3D
		var impact := slot.get("impact") as MeshInstance3D
		var backwash := slot.get("impact_backwash") as MeshInstance3D
		snapshots.append({
			"shot_id": int(slot.get("shot_id", 0)),
			"origin": slot.get("origin", Vector3.ZERO),
			"end": slot.get("end", Vector3.ZERO),
			"direction": slot.get("direction", Vector3.FORWARD),
			"distance": float(slot.get("distance", 0.0)),
			"style_id": StringName(slot.get("style_id", DEFAULT_STYLE_ID)),
			"profile_id": StringName(slot.get("profile_id", DEFAULT_PROFILE_ID)),
			"source_instance_id": int(slot.get("source_instance_id", 0)),
			"hit": bool(slot.get("hit", false)),
			"age": age,
			"travel_duration": travel_duration,
			"total_lifetime": float(slot.get("total_lifetime", 0.0)),
			"travel_progress": clampf(age / travel_duration, 0.0, 1.0),
			"pulse_position": pulse.global_position if is_instance_valid(pulse) else Vector3.ZERO,
			"pulse_visible": pulse.visible if is_instance_valid(pulse) else false,
			"impact_visible": impact.visible if is_instance_valid(impact) else false,
			"impact_backwash_visible": (
				backwash.visible if is_instance_valid(backwash) else false
			),
			"visible_beam_segments": _count_visible_slot_segments(slot),
		})
	snapshots.sort_custom(func(first: Dictionary, second: Dictionary) -> bool:
		return int(first.get("shot_id", 0)) < int(second.get("shot_id", 0))
	)
	return snapshots.duplicate(true)


func get_integration_contract() -> Dictionary:
	return {
		"schema_version": SCHEMA_VERSION,
		"component_id": COMPONENT_ID,
		"api": &"present_shot(origin_world, end_world, style_id, source_entity, hit, presentation_receipt_id=-1, profile_id=standard)",
		"returns": &"bool_accepted",
		"coordinate_space": &"world_space",
		"authority_policy": &"external_hitscan_authority_presentation_only",
		"caller_owns": PackedStringArray([
			"fire authorization and cadence",
			"ray or shape queries",
			"hit selection and authoritative endpoint",
			"damage, health, destruction, and scoring",
			"weapon and impact audio",
		]),
		"source_entity_policy": &"optional_instance_id_only_no_retained_reference",
		"hit_policy": &"caller_supplied_boolean_no_collision_query",
		"pool_policy": &"fixed_preallocated_oldest_visual_recycled_when_saturated",
		"pool_capacity": get_pool_capacity(),
		"maximum_pool_capacity": MAX_POOL_CAPACITY,
		"minimum_shot_distance": MIN_SHOT_DISTANCE,
		"maximum_shot_distance": MAX_SHOT_DISTANCE,
		"supported_style_ids": PackedStringArray(get_supported_style_ids()),
		"supported_profile_ids": PackedStringArray(get_supported_profile_ids()),
		"collision_policy": &"none_presentation_only_nonblocking",
		"audio_policy": &"none_voice_free_caller_owned",
		"particle_policy": &"none_deterministic_mesh_sparks",
		"allocation_policy": &"no_node_or_resource_allocation_during_present_or_advance",
		"world_transform_policy": &"top_level_slots_remain_at_submitted_world_geometry",
		"tree_exit_policy": &"synchronously_clear_all_active_visuals",
	}.duplicate(true)


func get_evidence_metadata() -> Dictionary:
	return {
		"schema_version": SCHEMA_VERSION,
		"component_id": COMPONENT_ID,
		"evidence_status": EVIDENCE_STATUS,
		"source_bounded": true,
		"historically_supported": false,
		"authenticated_original_geometry": false,
		"authenticated_original_weapon_effect": false,
		"modern_interpretations": PackedStringArray([
			"short travelling train of three pulse-beam dashes",
			"cyan, amber, and magenta emissive presentation styles",
			"spherical muzzle flash and tightly bounded practical light",
			"tintable authored pulse, impact, and shock-ring atlas treatment",
			"atlas impact with eight painted streaks, directional backwash, plus four deterministic mesh sparks",
			"timing, scale, brightness, pool size, and oldest-visual recycle policy",
		]),
		"explicit_unknowns": PackedStringArray([
			"historical weapon-effect geometry, colour, scale, timing, and audio",
			"historical muzzle, projectile, or impact presentation",
			"any relationship between visual style and authoritative weapon behaviour",
		]),
		"content_note": CONTENT_NOTE,
	}.duplicate(true)


func get_determinism_fingerprint() -> String:
	return (
		"%s|v%d|pool=%d|segments=%d|sparks=%d|speed=%.3f|travel=%.3f:%.3f|styles=%s"
		% [
			str(COMPONENT_ID),
			SCHEMA_VERSION,
			get_pool_capacity(),
			BEAM_SEGMENTS_PER_SHOT,
			IMPACT_SPARKS_PER_HIT,
			PULSE_SPEED,
			MIN_TRAVEL_DURATION,
			MAX_TRAVEL_DURATION,
			",".join(PackedStringArray(get_supported_style_ids())),
		]
	)


## Detached audit of the process-wide immutable visual catalog. Resource handles
## are deliberately not exposed: callers receive only identity and visible-value
## contracts, so the audit cannot mutate live presentation resources.
func get_resource_catalog_audit() -> Dictionary:
	var identity_contracts := {}
	var content_contracts := {}
	_append_mesh_catalog_audit(
		identity_contracts,
		content_contracts,
		&"mesh:orb",
		_shared_meshes.get(&"orb") as Mesh
	)
	_append_mesh_catalog_audit(
		identity_contracts,
		content_contracts,
		&"mesh:dash",
		_shared_meshes.get(&"dash") as Mesh
	)
	for style_id: StringName in STYLE_IDS:
		_append_material_catalog_audit(
			identity_contracts,
			content_contracts,
			StringName("material:%s:core" % style_id),
			_style_materials.get(style_id) as StandardMaterial3D
		)
		var atlas_roles := _atlas_materials.get(style_id, {}) as Dictionary
		for role: String in ["pulse", "impact"]:
			_append_material_catalog_audit(
				identity_contracts,
				content_contracts,
				StringName("material:%s:%s" % [style_id, role]),
				atlas_roles.get(role) as StandardMaterial3D
			)
	return {
		"scope": &"process_wide_immutable_resource_catalog",
		"mapping_state_scope": &"component_instance",
		"catalog_build_count": _process_resource_catalog_build_count,
		"resource_count": identity_contracts.size(),
		"mesh_resource_count": RESOURCE_CATALOG_MESH_COUNT,
		"material_resource_count": RESOURCE_CATALOG_MATERIAL_COUNT,
		"legacy_resources_per_component": RESOURCE_CATALOG_RESOURCE_COUNT,
		"shared_resources_per_process": RESOURCE_CATALOG_RESOURCE_COUNT,
		"identity_contracts": identity_contracts,
		"content_contracts": content_contracts,
		"mesh_instance_nodes_per_component": get_pool_capacity() * MESHES_PER_SLOT,
		"maximum_visible_mesh_submissions_per_component": (
			get_pool_capacity() * MAX_VISIBLE_MESHES_PER_SHOT
		),
		"light_nodes_per_component": get_pool_capacity() * LIGHTS_PER_SLOT,
	}.duplicate(true)


func get_performance_audit() -> Dictionary:
	var counts := {
		"node_count": 0,
		"mesh_instances": 0,
		"visible_meshes": 0,
		"lights": 0,
		"visible_lights": 0,
		"shadow_casting_lights": 0,
		"collision_nodes": 0,
		"physics_query_nodes": 0,
		"audio_nodes": 0,
		"particle_emitters": 0,
		"animation_players": 0,
	}
	_count_runtime_nodes(self, counts)
	var budgets := {
		"node_count": 2 + get_pool_capacity() * NODES_PER_SLOT,
		"mesh_instances": get_pool_capacity() * MESHES_PER_SLOT,
		"visible_meshes": get_pool_capacity() * MAX_VISIBLE_MESHES_PER_SHOT,
		"lights": get_pool_capacity() * LIGHTS_PER_SLOT,
		"visible_lights": get_pool_capacity() * MAX_VISIBLE_LIGHTS_PER_SHOT,
		"shadow_casting_lights": 0,
		"collision_nodes": 0,
		"physics_query_nodes": 0,
		"audio_nodes": 0,
		"particle_emitters": 0,
		"animation_players": 0,
	}
	var errors := PackedStringArray()
	for key: String in budgets:
		if int(counts.get(key, -1)) > int(budgets[key]):
			errors.append("%s exceeds fixed presentation budget (%d > %d)" % [key, counts.get(key, -1), budgets[key]])
	var expected_node_count := 2 + get_pool_capacity() * NODES_PER_SLOT
	var expected_mesh_count := get_pool_capacity() * MESHES_PER_SLOT
	var expected_light_count := get_pool_capacity() * LIGHTS_PER_SLOT
	if int(counts.node_count) != expected_node_count:
		errors.append("allocated node count diverged from immutable pool (%d != %d)" % [counts.node_count, expected_node_count])
	if int(counts.mesh_instances) != expected_mesh_count:
		errors.append("allocated mesh count diverged from immutable pool (%d != %d)" % [counts.mesh_instances, expected_mesh_count])
	if int(counts.lights) != expected_light_count:
		errors.append("allocated light count diverged from immutable pool (%d != %d)" % [counts.lights, expected_light_count])
	return {
		"schema_version": SCHEMA_VERSION,
		"within_budget": errors.is_empty(),
		"errors": errors,
		"counts": counts.duplicate(true),
		"budgets": budgets.duplicate(true),
		"pool_capacity": get_pool_capacity(),
		"active_effects": _active_effect_count,
		"resident_mesh_resources": _shared_meshes.size(),
		"resident_style_materials": _style_materials.size() + _atlas_materials.size() * 2,
		"resource_catalog": get_resource_catalog_audit(),
		"runtime_node_allocation": false,
		"runtime_resource_allocation": false,
		"per_frame_allocation": false,
		"uses_external_assets": true,
		"external_asset_path": VFX_ATLAS_PATH,
		"external_asset_sha256": VFX_ATLAS_SHA256,
		"dummy_renderer_safe": true,
	}.duplicate(true)


func get_validation_errors() -> PackedStringArray:
	var errors := PackedStringArray()
	if not _built:
		errors.append("component has not completed its immutable pool build")
		return errors
	if pool_capacity != _built_pool_capacity:
		errors.append("exported pool capacity changed after immutable build")
	if starts_enabled != _built_starts_enabled:
		errors.append("starts-enabled export changed after immutable build")
	if starts_auto_advance != _built_starts_auto_advance:
		errors.append("starts-auto-advance export changed after immutable build")
	if (
		not is_instance_valid(_pool_root)
		or get_node_or_null(^"PoolRoot") != _pool_root
		or not is_ancestor_of(_pool_root)
	):
		errors.append("stable PoolRoot is missing or reparented")
	if not _built_hierarchy_is_live():
		errors.append("preallocated pool hierarchy or node identity changed")
	if not _resource_contracts_are_live():
		errors.append("shared mesh or emissive material contract changed")
	if not _slot_state_is_valid():
		errors.append("active/inactive slot state diverged from deterministic lifecycle")
	if _active_effect_count < 0 or _active_effect_count > get_pool_capacity():
		errors.append("active effect count exceeds fixed pool capacity")
	if is_processing() != _should_process():
		errors.append("process state diverged from enabled/auto/active lifecycle")
	if not bool(get_meta("presentation_only", false)):
		errors.append("root lost presentation-only metadata")
	if StringName(get_meta("evidence_status", &"")) != EVIDENCE_STATUS:
		errors.append("root lost modern-interpretation evidence metadata")
	if bool(get_meta("gameplay_authority", true)):
		errors.append("presentation root cannot claim gameplay authority")
	var performance := get_performance_audit()
	if not bool(performance.within_budget):
		errors.append_array(performance.errors as PackedStringArray)
	var counts := performance.counts as Dictionary
	if (
		int(counts.collision_nodes) != 0
		or int(counts.physics_query_nodes) != 0
		or int(counts.audio_nodes) != 0
		or int(counts.particle_emitters) != 0
	):
		errors.append("presentation pool contains gameplay, audio, or nondeterministic particle nodes")
	return errors


func get_audit_report() -> Dictionary:
	var errors := get_validation_errors()
	return {
		"schema_version": SCHEMA_VERSION,
		"component_id": COMPONENT_ID,
		"valid": errors.is_empty(),
		"errors": errors,
		"evidence_status": EVIDENCE_STATUS,
		"evidence": get_evidence_metadata(),
		"integration": get_integration_contract(),
		"performance": get_performance_audit(),
		"lifecycle": {
			"inside_tree": is_inside_tree(),
			"enabled": _presentation_enabled,
			"auto_advance": _auto_advance_enabled,
			"process_enabled": is_processing(),
			"active_effects": _active_effect_count,
		},
		"statistics": get_statistics(),
		"determinism_fingerprint": get_determinism_fingerprint(),
	}.duplicate(true)


func audit() -> Dictionary:
	return get_audit_report().duplicate(true)


func _can_present(
		origin: Vector3,
		end: Vector3,
		style_id: StringName,
		profile_id: StringName,
		source_entity: Node
	) -> bool:
	if (
		not _built
		or not is_inside_tree()
		or not _presentation_enabled
		or _lifecycle_transaction_active
	):
		return false
	if not origin.is_finite() or not end.is_finite():
		return false
	var distance := origin.distance_to(end)
	if not is_finite(distance) or distance < MIN_SHOT_DISTANCE or distance > MAX_SHOT_DISTANCE:
		return false
	if not STYLE_IDS.has(style_id):
		return false
	if not PROFILE_IDS.has(profile_id):
		return false
	if source_entity != null and not is_instance_valid(source_entity):
		return false
	return true


func _can_mutate_current_presentation() -> bool:
	return not is_queued_for_deletion()


func _find_available_slot() -> int:
	var oldest_slot := -1
	var oldest_shot_id := 9223372036854775807
	for slot_index in _slots.size():
		var slot: Dictionary = _slots[slot_index]
		if not bool(slot.get("active", false)):
			return slot_index
		var shot_id := int(slot.get("shot_id", 0))
		if shot_id < oldest_shot_id:
			oldest_shot_id = shot_id
			oldest_slot = slot_index
	return oldest_slot


func _build_shared_resources() -> void:
	if _process_resource_catalog.is_empty():
		_process_resource_catalog = _create_resource_catalog()
		_process_resource_catalog_build_count += 1

	# These small dictionaries remain instance-owned runtime mappings. Only their
	# immutable Resource values are shared with the process catalog.
	var catalog_meshes := _process_resource_catalog.get("meshes", {}) as Dictionary
	_shared_meshes = {
		&"orb": catalog_meshes.get(&"orb") as Mesh,
		&"dash": catalog_meshes.get(&"dash") as Mesh,
	}
	var catalog_style_materials := (
		_process_resource_catalog.get("style_materials", {}) as Dictionary
	)
	var catalog_atlas_materials := (
		_process_resource_catalog.get("atlas_materials", {}) as Dictionary
	)
	for style_id: StringName in STYLE_IDS:
		_style_materials[style_id] = (
			catalog_style_materials.get(style_id) as StandardMaterial3D
		)
		var catalog_roles := catalog_atlas_materials.get(style_id, {}) as Dictionary
		_atlas_materials[style_id] = {
			"pulse": catalog_roles.get("pulse") as StandardMaterial3D,
			"impact": catalog_roles.get("impact") as StandardMaterial3D,
		}


func _create_resource_catalog() -> Dictionary:
	var meshes := {}
	var atlas_quad := QuadMesh.new()
	atlas_quad.resource_name = "PulsePresentationSharedAtlasQuad"
	atlas_quad.size = Vector2.ONE
	meshes[&"orb"] = atlas_quad

	var dash := BoxMesh.new()
	dash.resource_name = "PulsePresentationSharedDash"
	dash.size = Vector3.ONE
	meshes[&"dash"] = dash

	var style_materials := {}
	var atlas_materials := {}
	for style_id: StringName in STYLE_IDS:
		style_materials[style_id] = _make_style_material(style_id)
		atlas_materials[style_id] = {
			"pulse": _make_atlas_material(style_id, Vector3.ZERO, &"Pulse"),
			"impact": _make_atlas_material(style_id, Vector3(0.5, 0.0, 0.0), &"Impact"),
		}
	return {
		"meshes": meshes,
		"style_materials": style_materials,
		"atlas_materials": atlas_materials,
	}


func _build_pool() -> void:
	_slots.clear()
	for slot_index in _built_pool_capacity:
		var slot_root := Node3D.new()
		slot_root.name = "ShotSlot%02d" % (slot_index + 1)
		slot_root.top_level = true
		_pool_root.add_child(slot_root)
		slot_root.global_transform = Transform3D.IDENTITY
		_tag_presentation_node(slot_root, &"pooled_shot_root")

		var muzzle := _make_mesh(slot_root, "MuzzleFlash", _shared_meshes[&"orb"] as Mesh)
		var muzzle_light := _make_light(slot_root, "MuzzleLight", 1.9)
		var segments: Array[MeshInstance3D] = []
		for segment_index in BEAM_SEGMENTS_PER_SHOT:
			segments.append(_make_mesh(
				slot_root,
				"BeamSegment%02d" % (segment_index + 1),
				_shared_meshes[&"dash"] as Mesh
			))
		var pulse := _make_mesh(slot_root, "TravellingPulse", _shared_meshes[&"orb"] as Mesh)
		var impact := _make_mesh(slot_root, "ImpactFlare", _shared_meshes[&"orb"] as Mesh)
		var impact_backwash := _make_mesh(
			slot_root,
			"ImpactBackwash",
			_shared_meshes[&"dash"] as Mesh
		)
		var impact_light := _make_light(slot_root, "ImpactLight", 2.8)
		var sparks: Array[MeshInstance3D] = []
		for spark_index in IMPACT_SPARKS_PER_HIT:
			sparks.append(_make_mesh(
				slot_root,
				"ImpactSpark%02d" % (spark_index + 1),
				_shared_meshes[&"dash"] as Mesh
			))

		var slot := {
			"index": slot_index,
			"root": slot_root,
			"muzzle": muzzle,
			"muzzle_light": muzzle_light,
			"segments": segments,
			"pulse": pulse,
			"impact": impact,
			"impact_backwash": impact_backwash,
			"impact_light": impact_light,
			"sparks": sparks,
			"active": false,
			"activation_serial": 0,
			"shot_id": 0,
			"origin": Vector3.ZERO,
			"end": Vector3.ZERO,
			"direction": Vector3.FORWARD,
			"distance": 0.0,
			"style_id": DEFAULT_STYLE_ID,
			"profile_id": DEFAULT_PROFILE_ID,
			"source_instance_id": 0,
			"hit": false,
			"impact_started": false,
			"presentation_receipt_id": -1,
			"age": 0.0,
			"travel_duration": MIN_TRAVEL_DURATION,
			"total_lifetime": MIN_TRAVEL_DURATION + MISS_TAIL_DURATION,
		}
		_slots.append(slot)
		_apply_slot_style(slot_index)
		_hide_slot(slot)


func _make_mesh(parent: Node3D, node_name: String, mesh: Mesh) -> MeshInstance3D:
	var result := MeshInstance3D.new()
	result.name = node_name
	result.mesh = mesh
	result.material_override = _style_materials[DEFAULT_STYLE_ID] as Material
	result.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	result.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
	result.layers = 1
	parent.add_child(result)
	_tag_presentation_node(result, &"deterministic_weapon_visual")
	return result


func _make_light(parent: Node3D, node_name: String, range_value: float) -> OmniLight3D:
	var result := OmniLight3D.new()
	result.name = node_name
	result.light_energy = 0.0
	result.omni_range = range_value
	result.shadow_enabled = false
	result.distance_fade_enabled = true
	result.distance_fade_begin = 12.0
	result.distance_fade_length = 8.0
	parent.add_child(result)
	_tag_presentation_node(result, &"bounded_weapon_light")
	return result


func _make_style_material(style_id: StringName) -> StandardMaterial3D:
	var color := _style_color(style_id)
	var result := StandardMaterial3D.new()
	result.resource_name = "PulsePresentation_%s" % style_id
	result.albedo_color = color.lightened(0.24)
	result.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	result.emission_enabled = true
	result.emission = color
	result.emission_energy_multiplier = _style_emission(style_id)
	result.metallic = 0.0
	result.roughness = 0.2
	return result


func _make_atlas_material(
		style_id: StringName,
		atlas_offset: Vector3,
		role: StringName
	) -> StandardMaterial3D:
	var color := _style_color(style_id)
	var result := StandardMaterial3D.new()
	result.resource_name = "PulsePresentation_%s%sAtlas" % [style_id, role]
	result.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	result.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	result.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	result.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	result.albedo_texture = VFX_ATLAS
	result.albedo_color = Color(color.r, color.g, color.b, 0.96)
	result.emission_enabled = true
	result.emission_texture = VFX_ATLAS
	result.emission = color
	result.emission_energy_multiplier = _style_emission(style_id) * (1.15 if role == &"Impact" else 1.0)
	result.uv1_scale = Vector3(0.5, 0.5, 1.0)
	result.uv1_offset = atlas_offset
	result.metallic = 0.0
	result.roughness = 0.0
	return result


func _apply_slot_style(slot_index: int) -> void:
	var slot: Dictionary = _slots[slot_index]
	var style_id := StringName(slot.get("style_id", DEFAULT_STYLE_ID))
	var material := _style_materials.get(style_id) as Material
	for mesh_instance in _get_slot_meshes(slot):
		mesh_instance.material_override = material
	var atlas_roles := _atlas_materials.get(style_id, {}) as Dictionary
	(slot.get("muzzle") as MeshInstance3D).material_override = atlas_roles.get("pulse") as Material
	(slot.get("pulse") as MeshInstance3D).material_override = atlas_roles.get("pulse") as Material
	(slot.get("impact") as MeshInstance3D).material_override = atlas_roles.get("impact") as Material
	var color := _style_color(style_id)
	var muzzle_light := slot.get("muzzle_light") as OmniLight3D
	var impact_light := slot.get("impact_light") as OmniLight3D
	muzzle_light.light_color = color.lightened(0.18)
	impact_light.light_color = color.lightened(0.12)


func _update_slot(slot_index: int) -> void:
	var slot: Dictionary = _slots[slot_index]
	if not bool(slot.get("active", false)):
		return
	var origin := slot.get("origin", Vector3.ZERO) as Vector3
	var end := slot.get("end", Vector3.ZERO) as Vector3
	var direction := slot.get("direction", Vector3.FORWARD) as Vector3
	var distance := float(slot.get("distance", 0.0))
	var age := float(slot.get("age", 0.0))
	var travel_duration := float(slot.get("travel_duration", MIN_TRAVEL_DURATION))
	var travel_progress := clampf(age / travel_duration, 0.0, 1.0)
	var style_id := StringName(slot.get("style_id", DEFAULT_STYLE_ID))
	var profile_id := StringName(slot.get("profile_id", DEFAULT_PROFILE_ID))
	var width_scale := _style_width(style_id)

	var root := slot.get("root") as Node3D
	root.visible = true
	root.global_transform = Transform3D.IDENTITY

	var muzzle := slot.get("muzzle") as MeshInstance3D
	var muzzle_light := slot.get("muzzle_light") as OmniLight3D
	var muzzle_visible := age < minf(MUZZLE_DURATION, travel_duration)
	var muzzle_ratio := clampf(1.0 - age / MUZZLE_DURATION, 0.0, 1.0)
	muzzle.visible = muzzle_visible
	muzzle_light.visible = muzzle_visible
	if muzzle_visible:
		_set_world_mesh_transform(
			muzzle,
			origin,
			direction,
			Vector3(1.15, 0.82, 1.0) * (0.48 + muzzle_ratio * 0.52) * width_scale
		)
		muzzle_light.global_position = origin
		muzzle_light.light_energy = (0.55 + muzzle_ratio * 1.85) * _style_light(style_id)
	else:
		muzzle_light.light_energy = 0.0

	var travelling := age < travel_duration
	var emit_impact_started := false
	if (
		bool(slot.get("hit", false))
		and not bool(slot.get("impact_started", false))
		and age >= travel_duration
	):
		slot["impact_started"] = true
		_slots[slot_index] = slot
		emit_impact_started = true
	var pulse := slot.get("pulse") as MeshInstance3D
	pulse.visible = travelling
	if travelling:
		_set_world_mesh_transform(
			pulse,
			origin.lerp(end, travel_progress),
			direction,
			_travel_pulse_scale(profile_id) * width_scale
		)
	_update_beam_segments(
		slot, travelling, origin, direction, distance, travel_progress, width_scale, profile_id
	)
	_update_impact(slot, age - travel_duration, end, direction, width_scale, style_id, profile_id)
	# This is deliberately the final operation. A synchronous callback may recycle
	# this slot; returning immediately prevents stale outer writes from repainting
	# the replacement effect.
	if emit_impact_started:
		impact_started.emit(
			int(slot.get("shot_id", 0)),
			style_id,
			int(slot.get("source_instance_id", 0)),
			end
		)
		var receipt_id := int(slot.get("presentation_receipt_id", -1))
		if receipt_id >= 0:
			impact_receipt_ready.emit(receipt_id, end)


func _update_beam_segments(
		slot: Dictionary,
		travelling: bool,
		origin: Vector3,
		direction: Vector3,
		distance: float,
		travel_progress: float,
		width_scale: float,
		profile_id: StringName
	) -> void:
	var segments := slot.get("segments") as Array[MeshInstance3D]
	var head_distance := travel_progress * distance
	for segment_index in segments.size():
		var segment := segments[segment_index]
		var center_distance := head_distance - float(segment_index) * SEGMENT_SPACING
		var half_length := minf(
			SEGMENT_LENGTH * _segment_length_scale(profile_id) * 0.5,
			distance * 0.5
		)
		var start_distance := clampf(center_distance - half_length, 0.0, distance)
		var end_distance := clampf(center_distance + half_length, 0.0, distance)
		var visible_length := end_distance - start_distance
		segment.visible = travelling and visible_length >= MIN_VISIBLE_SEGMENT_LENGTH
		if not segment.visible:
			continue
		var visible_center := (start_distance + end_distance) * 0.5
		_set_world_mesh_transform(
			segment,
			origin + direction * visible_center,
			direction,
			Vector3(0.14, 0.14, visible_length)
				* width_scale
				* Vector3(
					_profile_width_scale(profile_id),
					_profile_width_scale(profile_id),
					1.0
				)
		)


func _update_impact(
		slot: Dictionary,
		impact_age: float,
		end: Vector3,
		direction: Vector3,
		width_scale: float,
		style_id: StringName,
		profile_id: StringName
	) -> void:
	var impact := slot.get("impact") as MeshInstance3D
	var impact_backwash := slot.get("impact_backwash") as MeshInstance3D
	var impact_light := slot.get("impact_light") as OmniLight3D
	var sparks := slot.get("sparks") as Array[MeshInstance3D]
	var visible := bool(slot.get("hit", false)) and impact_age >= 0.0 and impact_age < IMPACT_DURATION
	impact.visible = visible
	impact_backwash.visible = visible
	impact_light.visible = visible
	for spark in sparks:
		spark.visible = visible
	if not visible:
		impact_light.light_energy = 0.0
		return

	var phase := clampf(impact_age / IMPACT_DURATION, 0.0, 1.0)
	var flare_scale := (1.15 + sin(phase * PI) * 1.05) * width_scale
	var impact_profile_scale := _impact_profile_scale(profile_id)
	_set_world_mesh_transform(
		impact,
		end,
		direction,
		Vector3(1.12, 1.12, 1.0) * flare_scale * impact_profile_scale
	)
	impact_light.global_position = end
	impact_light.light_energy = (1.0 - phase) * 2.7 * _style_light(style_id)

	# The billboarded flare reads from any camera angle but cannot show which way
	# the resolved pulse arrived. This preallocated streak kicks back along the
	# incoming path using only the endpoints already supplied by the resolver.
	var backwash_envelope := sin(phase * PI)
	var backwash_travel := (0.06 + phase * 0.82) * width_scale
	impact_backwash.transparency = smoothstep(0.48, 1.0, phase)
	_set_world_mesh_transform(
		impact_backwash,
		end - direction * backwash_travel,
		-direction,
		Vector3(
			0.1 + backwash_envelope * 0.1,
			0.1 + backwash_envelope * 0.1,
			0.06 + backwash_envelope * 0.76
		) * width_scale * Vector3(
			_profile_width_scale(profile_id),
			_profile_width_scale(profile_id),
			_segment_length_scale(profile_id)
		)
	)

	var radial_a := direction.cross(Vector3.UP)
	if radial_a.length_squared() <= 0.001:
		radial_a = direction.cross(Vector3.RIGHT)
	radial_a = radial_a.normalized()
	var radial_b := direction.cross(radial_a).normalized()
	for spark_index in sparks.size():
		var angle := TAU * float(spark_index) / float(IMPACT_SPARKS_PER_HIT) + 0.31
		var spark_direction := (
			radial_a * cos(angle)
			+ radial_b * sin(angle)
			- direction * (0.18 + float(spark_index % 2) * 0.11)
		).normalized()
		var travel := (0.08 + phase * (0.62 + float(spark_index) * 0.07)) * width_scale
		_set_world_mesh_transform(
			sparks[spark_index],
			end + spark_direction * travel,
			spark_direction,
			Vector3(0.065, 0.065, maxf(0.065, 0.52 * (1.0 - phase)))
				* width_scale
				* Vector3(
					_profile_width_scale(profile_id),
					_profile_width_scale(profile_id),
					_segment_length_scale(profile_id)
				)
		)


func _travel_pulse_scale(profile_id: StringName) -> Vector3:
	match profile_id:
		PROFILE_SIEGE_LANCE:
			return SIEGE_LANCE_TRAVEL_PULSE_SCALE
		PROFILE_TAIL_TURRET:
			return TAIL_TURRET_TRAVEL_PULSE_SCALE
		PROFILE_REPEATER:
			return REPEATER_TRAVEL_PULSE_SCALE
	return STANDARD_TRAVEL_PULSE_SCALE


func _impact_profile_scale(profile_id: StringName) -> Vector3:
	match profile_id:
		PROFILE_SIEGE_LANCE:
			return SIEGE_LANCE_IMPACT_PROFILE_SCALE
		PROFILE_TAIL_TURRET:
			return TAIL_TURRET_IMPACT_PROFILE_SCALE
		PROFILE_REPEATER:
			return REPEATER_IMPACT_PROFILE_SCALE
	return STANDARD_IMPACT_PROFILE_SCALE


func _segment_length_scale(profile_id: StringName) -> float:
	match profile_id:
		PROFILE_SIEGE_LANCE:
			return 1.65
		PROFILE_TAIL_TURRET:
			return 0.62
		PROFILE_REPEATER:
			return 0.44
	return 1.0


func _profile_width_scale(profile_id: StringName) -> float:
	match profile_id:
		PROFILE_SIEGE_LANCE:
			return 0.78
		PROFILE_TAIL_TURRET:
			return 1.34
		PROFILE_REPEATER:
			return 0.64
	return 1.0


func _set_world_mesh_transform(
		mesh_instance: MeshInstance3D,
		world_position: Vector3,
		forward: Vector3,
		world_scale: Vector3
	) -> void:
	mesh_instance.global_transform = Transform3D(
		_basis_for_forward(forward).scaled(world_scale),
		world_position
	)


func _basis_for_forward(forward: Vector3) -> Basis:
	var safe_forward := forward.normalized()
	var up := Vector3.RIGHT if absf(safe_forward.dot(Vector3.UP)) > 0.98 else Vector3.UP
	return Basis.looking_at(safe_forward, up).orthonormalized()


func _deactivate_slot(slot_index: int, emit_completion: bool) -> int:
	var slot: Dictionary = _slots[slot_index]
	if not bool(slot.get("active", false)):
		_hide_slot(slot)
		return -1
	var completed_shot_id := int(slot.get("shot_id", 0))
	var aborted_receipt_id := -1
	if bool(slot.get("hit", false)) and not bool(slot.get("impact_started", false)):
		aborted_receipt_id = int(slot.get("presentation_receipt_id", -1))
	slot["active"] = false
	slot["source_instance_id"] = 0
	slot["presentation_receipt_id"] = -1
	slot["profile_id"] = DEFAULT_PROFILE_ID
	slot["age"] = 0.0
	_slots[slot_index] = slot
	_active_effect_count = maxi(0, _active_effect_count - 1)
	_finished_count += 1
	_hide_slot(slot)
	if emit_completion and completed_shot_id > 0:
		shot_finished.emit(completed_shot_id)
	return aborted_receipt_id


func _clear_effects_internal(emit_signal: bool, publish_aborts: bool = true) -> Array[int]:
	var aborted_receipts: Array[int] = []
	for slot_index in _slots.size():
		var slot: Dictionary = _slots[slot_index]
		if bool(slot.get("active", false)):
			var aborted_receipt_id := _deactivate_slot(slot_index, false)
			if aborted_receipt_id >= 0:
				aborted_receipts.append(aborted_receipt_id)
		else:
			_hide_slot(slot)
	_active_effect_count = 0
	set_process(false)
	# Publish fail-safe receipts only after every pool mutation is complete. A
	# synchronous listener may re-enter presentation without an outer clear or
	# recycle transaction overwriting that nested activation.
	if publish_aborts:
		_emit_aborted_receipts(aborted_receipts)
	_refresh_lifecycle()
	if emit_signal:
		effects_cleared.emit()
	return aborted_receipts


func _emit_aborted_receipts(receipt_ids: Array[int]) -> void:
	for aborted_receipt_id in receipt_ids:
		impact_receipt_aborted.emit(aborted_receipt_id)


func _hide_slot(slot: Dictionary) -> void:
	var root := slot.get("root") as Node3D
	if is_instance_valid(root):
		root.visible = false
	for mesh_instance in _get_slot_meshes(slot):
		mesh_instance.visible = false
	var muzzle_light := slot.get("muzzle_light") as OmniLight3D
	if is_instance_valid(muzzle_light):
		muzzle_light.visible = false
		muzzle_light.light_energy = 0.0
	var impact_light := slot.get("impact_light") as OmniLight3D
	if is_instance_valid(impact_light):
		impact_light.visible = false
		impact_light.light_energy = 0.0


func _get_slot_meshes(slot: Dictionary) -> Array[MeshInstance3D]:
	var result: Array[MeshInstance3D] = []
	for key: String in ["muzzle", "pulse", "impact", "impact_backwash"]:
		var candidate := slot.get(key) as MeshInstance3D
		if is_instance_valid(candidate):
			result.append(candidate)
	for segment in slot.get("segments", []) as Array[MeshInstance3D]:
		if is_instance_valid(segment):
			result.append(segment)
	for spark in slot.get("sparks", []) as Array[MeshInstance3D]:
		if is_instance_valid(spark):
			result.append(spark)
	return result


func _count_visible_slot_segments(slot: Dictionary) -> int:
	var count := 0
	for segment in slot.get("segments", []) as Array[MeshInstance3D]:
		if is_instance_valid(segment) and segment.visible:
			count += 1
	return count


func _refresh_lifecycle() -> void:
	set_process(_should_process())


func _should_process() -> bool:
	return (
		_built
		and is_inside_tree()
		and _presentation_enabled
		and _auto_advance_enabled
		and _active_effect_count > 0
	)


func _apply_evidence_metadata() -> void:
	set_meta("component_id", COMPONENT_ID)
	set_meta("presentation_only", true)
	set_meta("gameplay_authority", false)
	set_meta("collision_authority", false)
	set_meta("audio_authority", false)
	set_meta("evidence_status", EVIDENCE_STATUS)
	set_meta("historically_supported", false)
	set_meta("authenticated_original_geometry", false)
	set_meta("modern_interpretation", &"pulse_weapon_visual_presentation")
	_tag_presentation_node(_pool_root, &"fixed_effect_pool")


func _tag_presentation_node(node: Node, role: StringName) -> void:
	if not is_instance_valid(node):
		return
	node.set_meta("presentation_only", true)
	node.set_meta("gameplay_authority", false)
	node.set_meta("evidence_status", EVIDENCE_STATUS)
	node.set_meta("historically_supported", false)
	node.set_meta("modern_interpretation", role)


func _capture_built_contract() -> void:
	_built_node_instance_ids.clear()
	for candidate in find_children("*", "", true, false):
		_built_node_instance_ids[str(get_path_to(candidate))] = candidate.get_instance_id()
	_built_material_contracts.clear()
	_built_atlas_material_contracts.clear()
	for style_id: StringName in STYLE_IDS:
		var material := _style_materials.get(style_id) as StandardMaterial3D
		_built_material_contracts[style_id] = _material_contract(material)
		var atlas_roles := _atlas_materials.get(style_id, {}) as Dictionary
		_built_atlas_material_contracts[style_id] = {
			"pulse": _material_contract(atlas_roles.get("pulse") as StandardMaterial3D),
			"impact": _material_contract(atlas_roles.get("impact") as StandardMaterial3D),
		}
	_built_mesh_contracts = {
		"orb": _mesh_contract(_shared_meshes.get(&"orb") as Mesh),
		"dash": _mesh_contract(_shared_meshes.get(&"dash") as Mesh),
	}


func _built_hierarchy_is_live() -> bool:
	if _slots.size() != _built_pool_capacity:
		return false
	if _built_node_instance_ids.size() != 1 + _built_pool_capacity * NODES_PER_SLOT:
		return false
	for relative_path: String in _built_node_instance_ids:
		var live := get_node_or_null(NodePath(relative_path))
		if not is_instance_valid(live) or live.get_instance_id() != int(_built_node_instance_ids[relative_path]):
			return false
	for slot: Dictionary in _slots:
		var slot_root := slot.get("root") as Node3D
		if (
			not is_instance_valid(slot_root)
			or slot_root.get_parent() != _pool_root
			or not slot_root.top_level
			or _get_slot_meshes(slot).size() != MESHES_PER_SLOT
		):
			return false
	return true


func _resource_contracts_are_live() -> bool:
	if (
		_shared_meshes.size() != 2
		or _style_materials.size() != STYLE_IDS.size()
		or _atlas_materials.size() != STYLE_IDS.size()
		or not _resource_catalog_bindings_are_live()
		or not _atlas_contract_is_live()
	):
		return false
	if _mesh_contract(_shared_meshes.get(&"orb") as Mesh) != _built_mesh_contracts.get("orb", {}):
		return false
	if _mesh_contract(_shared_meshes.get(&"dash") as Mesh) != _built_mesh_contracts.get("dash", {}):
		return false
	for style_id: StringName in STYLE_IDS:
		var material := _style_materials.get(style_id) as StandardMaterial3D
		if _material_contract(material) != _built_material_contracts.get(style_id, {}):
			return false
		var atlas_roles := _atlas_materials.get(style_id, {}) as Dictionary
		var built_roles := _built_atlas_material_contracts.get(style_id, {}) as Dictionary
		for role: String in ["pulse", "impact"]:
			if _material_contract(atlas_roles.get(role) as StandardMaterial3D) != built_roles.get(role, {}):
				return false
	for slot: Dictionary in _slots:
		var style_id := StringName(slot.get("style_id", DEFAULT_STYLE_ID))
		var core_material := _style_materials.get(style_id) as Material
		var atlas_roles := _atlas_materials.get(style_id, {}) as Dictionary
		for mesh_instance in _get_slot_meshes(slot):
			var expected_material := core_material
			if mesh_instance.name in [&"MuzzleFlash", &"TravellingPulse"]:
				expected_material = atlas_roles.get("pulse") as Material
			elif mesh_instance.name == &"ImpactFlare":
				expected_material = atlas_roles.get("impact") as Material
			var expected_mesh := (
				_shared_meshes[&"orb"] as Mesh
				if mesh_instance.name in [&"MuzzleFlash", &"TravellingPulse", &"ImpactFlare"]
				else _shared_meshes[&"dash"] as Mesh
			)
			if (
				mesh_instance.mesh != expected_mesh
				or mesh_instance.material_override != expected_material
				or mesh_instance.cast_shadow != GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
				or mesh_instance.layers != 1
			):
				return false
	return true


func _resource_catalog_bindings_are_live() -> bool:
	if (
		_process_resource_catalog_build_count != 1
		or _process_resource_catalog.size() != 3
	):
		return false
	var catalog_meshes := _process_resource_catalog.get("meshes", {}) as Dictionary
	var catalog_style_materials := (
		_process_resource_catalog.get("style_materials", {}) as Dictionary
	)
	var catalog_atlas_materials := (
		_process_resource_catalog.get("atlas_materials", {}) as Dictionary
	)
	if (
		catalog_meshes.size() != RESOURCE_CATALOG_MESH_COUNT
		or catalog_style_materials.size() != STYLE_IDS.size()
		or catalog_atlas_materials.size() != STYLE_IDS.size()
		or _shared_meshes.get(&"orb") != catalog_meshes.get(&"orb")
		or _shared_meshes.get(&"dash") != catalog_meshes.get(&"dash")
	):
		return false
	for style_id: StringName in STYLE_IDS:
		if _style_materials.get(style_id) != catalog_style_materials.get(style_id):
			return false
		var instance_roles := _atlas_materials.get(style_id, {}) as Dictionary
		var catalog_roles := catalog_atlas_materials.get(style_id, {}) as Dictionary
		if (
			instance_roles.size() != 2
			or instance_roles.get("pulse") != catalog_roles.get("pulse")
			or instance_roles.get("impact") != catalog_roles.get("impact")
		):
			return false
	return true


func _atlas_contract_is_live() -> bool:
	if VFX_ATLAS == null or VFX_ATLAS.get_size() != Vector2(1254.0, 1254.0):
		return false
	var physical_path := ProjectSettings.globalize_path(VFX_ATLAS_PATH)
	if FileAccess.file_exists(physical_path):
		return FileAccess.get_sha256(physical_path) == VFX_ATLAS_SHA256
	# Exported PCKs expose the imported texture through remap rather than a loose
	# PNG. The immutable texture/material/content audit remains mandatory there.
	return ResourceLoader.exists(VFX_ATLAS_PATH)


func _slot_state_is_valid() -> bool:
	var live_count := 0
	var live_activation_serials: Dictionary = {}
	for slot: Dictionary in _slots:
		var active := bool(slot.get("active", false))
		var root := slot.get("root") as Node3D
		var muzzle_light := slot.get("muzzle_light") as OmniLight3D
		var impact_light := slot.get("impact_light") as OmniLight3D
		if not is_instance_valid(root) or not is_instance_valid(muzzle_light) or not is_instance_valid(impact_light):
			return false
		if muzzle_light.shadow_enabled or impact_light.shadow_enabled:
			return false
		if active:
			live_count += 1
			var activation_serial := int(slot.get("activation_serial", 0))
			var profile_id := StringName(slot.get("profile_id", DEFAULT_PROFILE_ID))
			var origin := slot.get("origin", Vector3.ZERO) as Vector3
			var end := slot.get("end", Vector3.ZERO) as Vector3
			var direction := slot.get("direction", Vector3.ZERO) as Vector3
			var age := float(slot.get("age", -1.0))
			if (
				not root.visible
				or activation_serial <= 0
				or activation_serial > _latest_activation_serial
				or live_activation_serials.has(activation_serial)
				or not PROFILE_IDS.has(profile_id)
				or not origin.is_finite()
				or not end.is_finite()
				or not direction.is_finite()
				or absf(direction.length() - 1.0) > 0.001
				or age < 0.0
				or age >= float(slot.get("total_lifetime", 0.0))
			):
				return false
			live_activation_serials[activation_serial] = true
		elif root.visible:
			return false
	return live_count == _active_effect_count


func _material_contract(material: StandardMaterial3D) -> Dictionary:
	if material == null:
		return {}
	return {
		"instance_id": material.get_instance_id(),
		"albedo_color": material.albedo_color,
		"shading_mode": material.shading_mode,
		"emission_enabled": material.emission_enabled,
		"emission": material.emission,
		"emission_energy_multiplier": material.emission_energy_multiplier,
		"metallic": material.metallic,
		"roughness": material.roughness,
		"transparency": material.transparency,
		"blend_mode": material.blend_mode,
		"billboard_mode": material.billboard_mode,
		"albedo_texture_id": material.albedo_texture.get_instance_id() if material.albedo_texture != null else 0,
		"albedo_texture_path": material.albedo_texture.resource_path if material.albedo_texture != null else "",
		"emission_texture_id": material.emission_texture.get_instance_id() if material.emission_texture != null else 0,
		"emission_texture_path": material.emission_texture.resource_path if material.emission_texture != null else "",
		"uv1_scale": material.uv1_scale,
		"uv1_offset": material.uv1_offset,
	}


func _mesh_contract(mesh: Mesh) -> Dictionary:
	if mesh == null:
		return {}
	var result := {
		"instance_id": mesh.get_instance_id(),
		"class": mesh.get_class(),
		"aabb": mesh.get_aabb(),
	}
	if mesh is SphereMesh:
		var sphere := mesh as SphereMesh
		result["radius"] = sphere.radius
		result["height"] = sphere.height
		result["radial_segments"] = sphere.radial_segments
		result["rings"] = sphere.rings
	elif mesh is BoxMesh:
		result["size"] = (mesh as BoxMesh).size
	elif mesh is QuadMesh:
		result["size"] = (mesh as QuadMesh).size
	return result


func _append_mesh_catalog_audit(
		identity_contracts: Dictionary,
		content_contracts: Dictionary,
		catalog_key: StringName,
		mesh: Mesh
	) -> void:
	var contract := _mesh_contract(mesh)
	identity_contracts[catalog_key] = int(contract.get("instance_id", 0))
	contract.erase("instance_id")
	content_contracts[catalog_key] = contract


func _append_material_catalog_audit(
		identity_contracts: Dictionary,
		content_contracts: Dictionary,
		catalog_key: StringName,
		material: StandardMaterial3D
	) -> void:
	var contract := _material_contract(material)
	identity_contracts[catalog_key] = int(contract.get("instance_id", 0))
	contract.erase("instance_id")
	contract.erase("albedo_texture_id")
	contract.erase("emission_texture_id")
	content_contracts[catalog_key] = contract


func _count_runtime_nodes(node: Node, counts: Dictionary) -> void:
	counts["node_count"] = int(counts.node_count) + 1
	if node is MeshInstance3D:
		counts["mesh_instances"] = int(counts.mesh_instances) + 1
		if (node as MeshInstance3D).is_visible_in_tree():
			counts["visible_meshes"] = int(counts.visible_meshes) + 1
	if node is Light3D:
		var light := node as Light3D
		counts["lights"] = int(counts.lights) + 1
		if light.is_visible_in_tree() and light.light_energy > 0.0:
			counts["visible_lights"] = int(counts.visible_lights) + 1
		if light.shadow_enabled:
			counts["shadow_casting_lights"] = int(counts.shadow_casting_lights) + 1
	if node is CollisionObject3D or node is CollisionShape3D or node is CollisionPolygon3D:
		counts["collision_nodes"] = int(counts.collision_nodes) + 1
	if node is RayCast3D or node is ShapeCast3D:
		counts["physics_query_nodes"] = int(counts.physics_query_nodes) + 1
	if node is AudioStreamPlayer or node is AudioStreamPlayer2D or node is AudioStreamPlayer3D:
		counts["audio_nodes"] = int(counts.audio_nodes) + 1
	if node is GPUParticles3D or node is CPUParticles3D or node is GPUParticles2D or node is CPUParticles2D:
		counts["particle_emitters"] = int(counts.particle_emitters) + 1
	if node is AnimationPlayer:
		counts["animation_players"] = int(counts.animation_players) + 1
	for child in node.get_children():
		_count_runtime_nodes(child, counts)


func _style_color(style_id: StringName) -> Color:
	match style_id:
		STYLE_AMBER:
			return Color("ff9f43")
		STYLE_MAGENTA:
			return Color("ff54d7")
		_:
			return Color("48dbe2")


func _style_width(style_id: StringName) -> float:
	match style_id:
		STYLE_AMBER:
			return 1.08
		STYLE_MAGENTA:
			return 1.22
		_:
			return 1.0


func _style_emission(style_id: StringName) -> float:
	return 3.35 if style_id == STYLE_MAGENTA else (3.05 if style_id == STYLE_AMBER else 3.2)


func _style_light(style_id: StringName) -> float:
	return 1.12 if style_id == STYLE_MAGENTA else (1.04 if style_id == STYLE_AMBER else 1.0)
