class_name StandoffPicketOpponent
extends RangeOpponent

const WeaponDefinitionResolverProfileType := preload(
	"res://scripts/combat/weapon_definition_resolver_profile.gd"
)
const SIEGE_LANCE_DEFINITION := preload("res://assets/weapons/picket_siege_lance.tres")
const SiegeLanceAudioBindingType := preload("res://scripts/audio/siege_lance_audio_binding.gd")

## Standoff picket lance — a second, laterally differentiated range-defence
## archetype for the Phase 6 encounter.
##
## Where `RangeOpponent` is a close orbiting dogfighter that leans on cadence,
## this craft is a fragile long-reach marksman. It holds a wide standoff band,
## charges a long, loud lance telegraph, lands one heavy shot, then relocates
## laterally to the opposite firing bearing. Closing the distance is the whole
## counterplay: inside `minimum_arming_range` its lance cannot arm, an in-progress
## charge is aborted with a recovery penalty, and its slow hull and slow turn
## rate cannot re-open the gap against a hero craft.
##
## Authority reuse (nothing here owns a second damage path):
##   * identity, faction and weapon envelope    -> LiveCombatAuthority.register_source
##   * damage proxy                             -> LiveCombatAuthority.attach_lifecycle_damageable
##   * every shot                               -> the one live CombatResolver
##   * presentation receipts                    -> LiveCombatAuthority's 64-bit allocator
##   * hull/damage/destruction/debris lifecycle -> inherited from RangeOpponent
##   * shot visuals                             -> the shared fixed PulseWeaponPresentation pool
##   * fire/impact/explosion cues               -> the shared ten-voice CombatAudioPresentation
##
## The production coordinator (`GameFlow`) hard-binds its pulse style and fire
## cue to exactly two identities (the player fleet and `$RangeOpponent`), so a
## third combatant that routed through `LiveCombatAuthority.submit_hitscan*`
## would be presented in the player's cyan with the player's fire cue. This
## craft therefore submits to the same resolver under its own registered
## identity and consumes the same pooled presentation seams itself. It adds no
## ray query, no health store, and no second damage application.
##
## Evidence status: modern_interpretation. No original Keth Shipyards craft,
## weapon, tactic, or class name is authenticated or claimed by this archetype.

signal lance_fired(origin: Vector3, direction: Vector3, result: Dictionary)
signal siege_lance_audio_record(record: Dictionary)
signal engagement_state_changed(state: StringName)

const SCHEMA_VERSION := 1
const COMPONENT_ID: StringName = &"standoff-picket-opponent"
const EVIDENCE_STATUS: StringName = &"modern_interpretation"
const DISPLAY_NAME := "Mudds range standoff picket"

const DEFAULT_SOURCE_ID := 2102
const DEFAULT_FACTION: StringName = &"range_defence"
const LANCE_WEAPON_ID: StringName = &"picket_siege_lance"
const LANCE_PULSE_STYLE: StringName = &"magenta"
const LANCE_PULSE_PROFILE: StringName = PulseWeaponPresentation.PROFILE_SIEGE_LANCE
const LANCE_AUDIO_PROFILE: StringName = CombatAudioPresentation.WEAPON_PROFILE_SIEGE_LANCE

const STATE_DORMANT: StringName = &"dormant"
const STATE_CLOSING: StringName = &"closing"
const STATE_HOLDING: StringName = &"holding"
const STATE_BREAKING: StringName = &"breaking"
const STATE_RELOCATING: StringName = &"relocating"

## Deliberately darker and cooler than the defender's ivory dart so the two
## opponent archetypes separate at a glance, but light enough to hold a readable
## silhouette against the black backdrop at standoff distance.
const HULL_GRAPHITE := Color("5a6472")
const HULL_SLATE := Color("7d879a")
const HULL_BONE := Color("d5dae2")
const LANCE_MAGENTA := Color("ff54d7")
const LANCE_VIOLET := Color("8a5bff")
const PICKET_ENGINE := Color("9ce8ff")
const LANCE_EMITTER_CHARGE_SCALE := Vector3(0.72, 1.8, 0.72)
const LANCE_LENS_CHARGE_SCALE := Vector3.ONE * 1.35
const LANCE_SPINE_CHARGE_SCALE := Vector3.ONE * 0.78

const MAX_PENDING_LANCE_RECEIPTS := 8

# Component-local static presentation budget. The old build allocated one
# BoxMesh for each of fourteen box nodes. Five mirrored recipes are immutable
# exact duplicates, so the cache retains one mesh per recipe; the broad static
# radiator pair also shares one renderer submission without changing its copies.
const BASELINE_PRESENTATION_VISUAL_NODE_COUNT := 33
const PRESENTATION_VISUAL_NODE_COUNT := 29
const BASELINE_PRESENTATION_MESH_INSTANCE_COUNT := 31
const PRESENTATION_MESH_INSTANCE_COUNT := 23
const PRESENTATION_RENDERER_NODE_COUNT := 27
const PRESENTATION_VISIBLE_GEOMETRY_COPY_COUNT := 31
const BASELINE_PRESENTATION_SURFACE_SUBMISSION_COUNT := 31
const PRESENTATION_SURFACE_SUBMISSION_COUNT := 27
const PRESENTATION_MATERIAL_RESOURCE_COUNT := 8
const BASELINE_PRESENTATION_MESH_RESOURCE_COUNT := 27
const PRESENTATION_MESH_RESOURCE_COUNT := 22
const BASELINE_PRESENTATION_BOX_MESH_RESOURCE_COUNT := 14
const PRESENTATION_BOX_MESH_RESOURCE_COUNT := 9
const PRESENTATION_BOX_INSTANCE_COUNT := 14
const PRESENTATION_SHARED_BOX_FAMILY_COUNT := 5
const PRESENTATION_MULTIMESH_BATCH_COUNT := 4
const ENGINE_POD_COPY_COUNT := 2
const ENGINE_CORE_COPY_COUNT := 2
const LANCE_RAIL_COPY_COUNT := 2
const RADIATOR_VANE_COPY_COUNT := 2

const CONTENT_NOTE := (
	"The picket silhouette, palette, lance telegraph, standoff band, minimum arming "
	+ "range, alternating relocation, and every balance value are an original modern "
	+ "interpretation. They do "
	+ "not reproduce or claim any authenticated historical Keth Shipyards craft, "
	+ "weapon, tactic, or class name."
)

@export_category("Combat authority")
## Stable session identity. Must not collide with the fleet or the defender.
@export var source_id := DEFAULT_SOURCE_ID
@export var faction_id: StringName = DEFAULT_FACTION
@export var lance_range := 560.0
@export var lance_damage := 22.0
@export var lance_origin_tolerance := 22.0

@export_category("Picket tactics")
## Distance the picket tries to hold. Far outside the defender's orbit band.
@export_range(20.0, 400.0, 1.0) var standoff_range := 132.0
## Inside this radius the lance cannot arm and an active charge is aborted.
@export_range(5.0, 200.0, 1.0) var minimum_arming_range := 58.0
## Cosine gate on the firing cone. Much narrower than the defender's.
@export_range(0.5, 0.9999, 0.0001) var lance_aim_tolerance := 0.985
## Cosine gate that keeps an in-progress charge alive.
@export_range(0.5, 0.9999, 0.0001) var lance_hold_tolerance := 0.965
## Cooldown forced when a charge is broken by range, cone, or occlusion.
@export_range(0.0, 8.0, 0.05) var lance_abort_recovery := 0.9
## Cooldown applied on dispatch so the picket never opens instantly.
@export_range(0.0, 12.0, 0.05) var initial_arming_delay := 1.6
## After an accepted lance dispatch, break laterally before settling for the
## next charge. Successive shots alternate sides so the marksman cannot remain
## parked on one firing bearing.
@export_range(0.1, 5.0, 0.05) var post_shot_relocation_duration := 1.15

@export_category("Escort dispatch")
## The picket is dispatched as the defender's second wave and withdraws with it.
@export var escort_enabled := true
@export_range(0.0, 30.0, 0.1) var escort_launch_delay := 3.0
@export var defender_path := NodePath("../RangeOpponent")
@export var combat_authority_path := NodePath("../CombatAuthority")
@export var pulse_presentation_path := NodePath("../PulseWeaponPresentation")
@export var combat_audio_path := NodePath("../CombatAudioPresentation")
@export var encounter_host_path := NodePath("..")
@export var hud_path := NodePath("../HUD")

var _registered := false
var _escort_dispatched := false
var _escort_fire_authorized := false
var _dispatch_generation := 0
var _dispatch_owner_generation := 0
var _dispatch_owner_instance_id := 0
var _dispatch_authority_owner: Node
var _dispatch_defender: RangeOpponent
var _escort_elapsed := 0.0
var _engagement_state: StringName = STATE_DORMANT
var _last_shot_result: Dictionary = {}
var _lance_receipts: Dictionary = {}
var _lance_receipt_order: Array[int] = []
var _pulse_signals_connected := false
var _lance_lens: MeshInstance3D
var _lance_emitter: MeshInstance3D
var _picket_box_mesh_cache: Dictionary = {}
var _shots_fired := 0
var _shots_aborted := 0
var _weapon_definition: WeaponDefinition
var _lance_charge_generation := 0
var _lance_charge_target_instance_id := 0
var _lance_charge_dispatch_generation := 0
var _lance_charge_armed := false
var _lance_charge_cancel_reason: StringName = &""
var _audio_sequence := 0
var _siege_lance_audio_binding: RefCounted
var _bound_escort_defender: RangeOpponent
var _post_shot_relocation_remaining := 0.0
var _post_shot_relocation_sign := 1.0


# ------------------------------------------------------------- lifecycle ----

func _enter_tree() -> void:
	super()
	# A whole-`Main` detach/re-entry re-adds this node without calling `_ready()`
	# again. Restoring the registration is deferred so the coordinator's own
	# deferred combat restore observes the same source roster it built at boot.
	if _built:
		_bind_siege_lance_audio()
		call_deferred("_restore_after_reentry")


func _ready() -> void:
	super()
	_weapon_definition = SIEGE_LANCE_DEFINITION.duplicate(true) as WeaponDefinition
	set_meta("component_id", COMPONENT_ID)
	set_meta("evidence_status", EVIDENCE_STATUS)
	set_meta("historically_supported", false)
	set_meta("modern_interpretation", &"standoff_picket_opponent")
	_attach_damage_proxy()
	_connect_pulse_signals()
	_bind_siege_lance_audio()


func _exit_tree() -> void:
	_unbind_siege_lance_audio()
	_revoke_dispatch_authorization(&"detached")
	_disconnect_pulse_signals()
	# Damage authority is already final; only queued presentation is dropped so a
	# streamed teardown can never resurrect a transient on re-entry.
	_discard_lance_receipts()
	# The resolver drops the live registration through its own `tree_exiting`
	# hook while deliberately retaining this identity's replay high-water mark.
	# Mirror that here so the claim cannot outlive the registration it describes.
	_registered = false
	super()


func _physics_process(delta: float) -> void:
	_update_escort_dispatch(delta)
	if _active and is_finite(delta) and delta >= 0.0:
		_post_shot_relocation_remaining = maxf(
			0.0,
			_post_shot_relocation_remaining - delta
		)
	super(delta)
	if _lance_charge_armed and not _has_current_target():
		_cancel_lance_charge(&"target_lost", false)
	_update_engagement_state()


# -------------------------------------------------------- public contract ----

func get_display_name() -> String:
	return DISPLAY_NAME


func get_component_id() -> StringName:
	return COMPONENT_ID


func get_engagement_state() -> StringName:
	return _engagement_state


func is_escort_dispatched() -> bool:
	return _escort_dispatched


func is_combat_source_registered() -> bool:
	return _registered


func get_pending_lance_receipt_count() -> int:
	return _lance_receipts.size()


func get_last_shot_result() -> Dictionary:
	return _last_shot_result.duplicate(true)


## Detached tactical state for HUD, encounter and regression consumers. The
## sign selects one of the two lateral directions around the current target;
## no mutable target reference escapes the snapshot.
func get_post_shot_relocation_snapshot() -> Dictionary:
	return {
		"active": _post_shot_relocation_remaining > 0.0,
		"remaining": maxf(_post_shot_relocation_remaining, 0.0),
		"direction_sign": _post_shot_relocation_sign,
	}.duplicate(true)


func set_target(target: Node3D) -> void:
	var next_id := target.get_instance_id() if is_instance_valid(target) else 0
	var previous_id := _target.get_instance_id() if is_instance_valid(_target) else 0
	if next_id != previous_id:
		if _telegraph_remaining > 0.0:
			_cancel_lance_charge(&"target_changed", false)
		_lance_charge_generation += 1
	_lance_charge_target_instance_id = next_id
	super.set_target(target)


## Detached caller-physics charge state for HUD/counterplay consumers. The
## target object is represented only by its instance identity and generation;
## no mutable target reference escapes this snapshot.
func get_lance_charge_snapshot() -> Dictionary:
	var progress := 0.0
	if _telegraph_remaining > 0.0:
		progress = clampf(1.0 - _telegraph_remaining / maxf(telegraph_time, 0.001), 0.0, 1.0)
	return {
		"active": _telegraph_remaining > 0.0,
		"progress": progress,
		"remaining": maxf(_telegraph_remaining, 0.0),
		"target_generation": _lance_charge_generation,
		"target_instance_id": _lance_charge_target_instance_id,
		"dispatch_generation": _lance_charge_dispatch_generation,
		"armed": _lance_charge_armed,
		"cancel_reason": _lance_charge_cancel_reason,
	}.duplicate(true)


## Explicit lifecycle cancel used by an owner transferring or withdrawing the
## picket. It never changes resolver state because no shot has been dispatched.
func cancel_lance_charge(reason: StringName = &"cancelled") -> void:
	_cancel_lance_charge(reason, false)


## Defensive copy of the checked-in heavy/standoff weapon authoring profile.
func get_weapon_definition() -> WeaponDefinition:
	return _weapon_definition.duplicate(true) as WeaponDefinition \
		if _weapon_definition != null else null


## Immutable authority envelope submitted to `LiveCombatAuthority`.
func get_weapon_profiles() -> Dictionary:
	var definition := get_weapon_definition()
	if definition == null or definition.weapon_id != LANCE_WEAPON_ID:
		return {}
	return WeaponDefinitionResolverProfileType.to_resolver_profiles(
		definition,
		faction_id,
		lance_origin_tolerance,
	)


## Ordered trade-off axes used by the opponent role-differentiation audit. Every
## value has an unambiguous "better for this opponent" reading so no-strict-
## dominance can be measured the same way the fleet audit measures the player
## craft.
func get_tactics_profile() -> Dictionary:
	return {
		"maximum_health": maximum_health,
		"cruise_speed": cruise_speed,
		"chase_speed": chase_speed,
		"acceleration": acceleration,
		"turn_speed_degrees": turn_speed_degrees,
		"engagement_range": engagement_range,
		"weapon_range": lance_range,
		"weapon_damage": lance_damage,
		"sustained_damage_per_second": get_sustained_damage_per_second(),
		"telegraph_time": telegraph_time,
		"weapon_cooldown": weapon_cooldown,
		"minimum_arming_range": minimum_arming_range,
		"preferred_engagement_distance": standoff_range,
	}.duplicate(true)


func get_sustained_damage_per_second() -> float:
	var cycle := maxf(0.001, telegraph_time + weapon_cooldown)
	return lance_damage / cycle


func get_evidence_metadata() -> Dictionary:
	return {
		"schema_version": SCHEMA_VERSION,
		"component_id": COMPONENT_ID,
		"evidence_status": EVIDENCE_STATUS,
		"historically_supported": false,
		"authenticated_original_geometry": false,
		"authenticated_original_weapon": false,
		"authenticated_original_tactic": false,
		"claims_historical_class_name": false,
		"modern_interpretations": PackedStringArray([
			"graphite standoff picket silhouette with a forward lance barrel",
			"magenta lance telegraph, charge lens, and pooled magenta pulse style",
			"standoff band, minimum arming range, and alternating post-shot relocation",
			"every balance, cadence, range, and damage value",
		]),
		"explicit_unknowns": PackedStringArray([
			"any historical opposing craft, weapon, loadout, tactic, or class name",
		]),
		"content_note": CONTENT_NOTE,
	}.duplicate(true)


## Exact, component-local static presentation census. It inspects Resource
## identity and mesh surfaces only, so it remains deterministic under headless
## where renderer buffers are unavailable. Particles, collision and authority
## nodes sit outside StandoffPicketVisual and are deliberately out of this trim.
func get_presentation_performance_contract() -> Dictionary:
	var mesh_instances := 0
	var box_instances := 0
	var submissions := 0
	var mesh_resources := {}
	var box_mesh_resources := {}
	var material_resources := {}
	var visual_nodes := 0
	var multimesh_batches := 0
	var visible_geometry_copies := 0
	if is_instance_valid(_visual_root):
		visual_nodes = _visual_root.get_child_count()
		for candidate: Node in _visual_root.get_children():
			if candidate is MultiMeshInstance3D:
				var batch := candidate as MultiMeshInstance3D
				var multi := batch.multimesh
				if multi == null or multi.mesh == null:
					continue
				multimesh_batches += 1
				var visible_count := multi.visible_instance_count
				visible_geometry_copies += multi.instance_count if visible_count < 0 else visible_count
				mesh_resources[multi.mesh.get_instance_id()] = true
				if multi.mesh is BoxMesh:
					box_instances += multi.instance_count if visible_count < 0 else visible_count
					box_mesh_resources[multi.mesh.get_instance_id()] = true
				submissions += multi.mesh.get_surface_count()
				for surface_index in multi.mesh.get_surface_count():
					var batch_material := multi.mesh.surface_get_material(surface_index)
					if batch_material != null:
						material_resources[batch_material.get_instance_id()] = true
				continue
			if candidate is not MeshInstance3D:
				continue
			var instance := candidate as MeshInstance3D
			var mesh := instance.mesh
			if mesh == null:
				continue
			mesh_instances += 1
			visible_geometry_copies += 1
			mesh_resources[mesh.get_instance_id()] = true
			if mesh is BoxMesh:
				box_instances += 1
				box_mesh_resources[mesh.get_instance_id()] = true
			submissions += mesh.get_surface_count()
			for surface_index in mesh.get_surface_count():
				var material := mesh.surface_get_material(surface_index)
				if material != null:
					material_resources[material.get_instance_id()] = true
	var valid := (
		visual_nodes == PRESENTATION_VISUAL_NODE_COUNT
		and mesh_instances == PRESENTATION_MESH_INSTANCE_COUNT
		and mesh_instances + multimesh_batches == PRESENTATION_RENDERER_NODE_COUNT
		and visible_geometry_copies == PRESENTATION_VISIBLE_GEOMETRY_COPY_COUNT
		and submissions == PRESENTATION_SURFACE_SUBMISSION_COUNT
		and mesh_resources.size() == PRESENTATION_MESH_RESOURCE_COUNT
		and box_instances == PRESENTATION_BOX_INSTANCE_COUNT
		and box_mesh_resources.size() == PRESENTATION_BOX_MESH_RESOURCE_COUNT
		and _picket_box_mesh_cache.size() == PRESENTATION_BOX_MESH_RESOURCE_COUNT
		and material_resources.size() == PRESENTATION_MATERIAL_RESOURCE_COUNT
		and multimesh_batches == PRESENTATION_MULTIMESH_BATCH_COUNT
	)
	return {
		"valid": valid,
		"headless_safe": true,
		"scope": &"StandoffPicketVisual_static_geometry",
		"baseline_visual_nodes": BASELINE_PRESENTATION_VISUAL_NODE_COUNT,
		"visual_nodes": visual_nodes,
		"baseline_mesh_instances": BASELINE_PRESENTATION_MESH_INSTANCE_COUNT,
		"mesh_instances": mesh_instances,
		"renderer_nodes": mesh_instances + multimesh_batches,
		"visible_geometry_copies": visible_geometry_copies,
		"baseline_surface_submissions": BASELINE_PRESENTATION_SURFACE_SUBMISSION_COUNT,
		"surface_submissions": submissions,
		"baseline_mesh_resources": BASELINE_PRESENTATION_MESH_RESOURCE_COUNT,
		"mesh_resources": mesh_resources.size(),
		"mesh_resource_delta": mesh_resources.size() - BASELINE_PRESENTATION_MESH_RESOURCE_COUNT,
		"baseline_box_mesh_resources": BASELINE_PRESENTATION_BOX_MESH_RESOURCE_COUNT,
		"box_mesh_resources": box_mesh_resources.size(),
		"box_instances": box_instances,
		"shared_box_families": PRESENTATION_SHARED_BOX_FAMILY_COUNT,
		"material_resources": material_resources.size(),
		"multimesh_batches": multimesh_batches,
	}.duplicate(true)


func get_audit_report() -> Dictionary:
	var errors := get_validation_errors()
	return {
		"schema_version": SCHEMA_VERSION,
		"component_id": COMPONENT_ID,
		"display_name": DISPLAY_NAME,
		"valid": errors.is_empty(),
		"errors": errors,
		"evidence": get_evidence_metadata(),
		"presentation_performance": get_presentation_performance_contract(),
		"weapon_profiles": get_weapon_profiles(),
		"tactics": get_tactics_profile(),
		"authority": {
			"source_id": source_id,
			"faction_id": faction_id,
			"registered": _registered,
			"weapon_id": LANCE_WEAPON_ID,
			"pulse_style_id": LANCE_PULSE_STYLE,
			"pulse_profile_id": LANCE_PULSE_PROFILE,
			"combat_audio_profile_id": LANCE_AUDIO_PROFILE,
		},
		"weapon_definition": (
			_weapon_definition.get_definition_snapshot()
			if _weapon_definition != null else {}
		),
		"lifecycle": {
			"inside_tree": is_inside_tree(),
			"active": is_active(),
			"escort_enabled": escort_enabled,
			"escort_dispatched": _escort_dispatched,
			"escort_fire_authorized": _escort_fire_authorized,
			"dispatch_generation": _dispatch_generation,
			"dispatch_owner_generation": _dispatch_owner_generation,
			"dispatch_owner_instance_id": _dispatch_owner_instance_id,
			"engagement_state": _engagement_state,
			"pending_lance_receipts": _lance_receipts.size(),
			"shots_fired": _shots_fired,
			"shots_aborted": _shots_aborted,
			"post_shot_relocation": get_post_shot_relocation_snapshot(),
		},
	}.duplicate(true)


func get_validation_errors() -> PackedStringArray:
	var errors := PackedStringArray()
	if not _built:
		errors.append("picket presentation has not been built")
	if not bool(get_presentation_performance_contract().valid):
		errors.append("picket presentation resource-sharing contract drifted")
	if source_id <= 0:
		errors.append("source_id must be a positive stable identity")
	if faction_id.is_empty():
		errors.append("faction_id is required")
	if not is_finite(lance_range) or lance_range <= 0.0:
		errors.append("lance range must be finite and positive")
	if not is_finite(lance_damage) or lance_damage <= 0.0:
		errors.append("lance damage must be finite and positive")
	if not is_finite(lance_origin_tolerance) or lance_origin_tolerance <= 0.0:
		errors.append("lance origin tolerance must be finite and positive")
	if _weapon_definition == null:
		errors.append("picket siege lance weapon definition is required")
	else:
		for definition_error in _weapon_definition.get_validation_errors():
			errors.append("picket siege lance definition: %s" % definition_error)
		if _weapon_definition.weapon_id != LANCE_WEAPON_ID:
			errors.append("picket siege lance definition ID must match the resolver weapon ID")
		if not is_equal_approx(_weapon_definition.range_meters, lance_range):
			errors.append("picket siege lance range must match the authored runtime envelope")
		if not is_equal_approx(_weapon_definition.damage_per_hit, lance_damage):
			errors.append("picket siege lance damage must match the authored runtime envelope")
	if minimum_arming_range >= standoff_range:
		errors.append("minimum arming range must sit inside the standoff band")
	if standoff_range >= engagement_range:
		errors.append("standoff band must sit inside the engagement range")
	if lance_hold_tolerance > lance_aim_tolerance:
		errors.append("charge hold cone must not be narrower than the arming cone")
	if not is_finite(post_shot_relocation_duration) or post_shot_relocation_duration <= 0.0:
		errors.append("post-shot relocation duration must be finite and positive")
	if _registered and not is_instance_valid(_get_combat_authority()):
		errors.append("registration is claimed without a live combat authority")
	if _lance_receipts.size() > MAX_PENDING_LANCE_RECEIPTS:
		errors.append("pending lance receipts exceed the fixed bound")
	if _active and is_inside_tree() and not _registered:
		errors.append("an active picket must own a live combat registration")
	if not _active and _registered:
		errors.append("a dormant picket must not retain a live combat registration")
	return errors


# ------------------------------------------------------------- activation ----

func activate(spawn_transform: Transform3D) -> Dictionary:
	# A queued picket is still attached until the frame drain, but it can no
	# longer safely reclaim collision, damage, or combat-authority ownership.
	# Deliberately retain the inherited detached/pre-tree staging path.
	if is_queued_for_deletion():
		return {
			"accepted": false,
			"reason": &"queued_for_deletion",
		}.duplicate(true)
	# In escort mode activation alone is movement/lifecycle authority, never fire
	# authority. Only `activate_authorized_dispatch()` below may publish a grant.
	if escort_enabled:
		_revoke_dispatch_authorization(&"activation_reset")
	var activation := super(spawn_transform) as Dictionary
	if not bool(activation.get("accepted", false)):
		return activation
	_cooldown_remaining = maxf(_cooldown_remaining, initial_arming_delay)
	_shots_fired = 0
	_shots_aborted = 0
	_post_shot_relocation_remaining = 0.0
	_post_shot_relocation_sign = 1.0
	_cancel_lance_charge(&"activation_reset", false)
	_lance_charge_generation = 0
	_lance_charge_target_instance_id = 0
	_lance_charge_dispatch_generation = 0
	_discard_lance_receipts()
	if _siege_lance_audio_binding != null:
		_siege_lance_audio_binding.reset_for_reuse()
	_register_combat_source()
	_set_engagement_state(STATE_CLOSING)
	return activation


## Activates one explicitly owned dispatch and returns its detached authority
## receipt. Escort dispatches name their defender as both owner and synchronous
## cancellation source. Scenario dispatches name the director and its scenario
## generation; that owner is re-asked at the irreversible fire seam.
func activate_authorized_dispatch(
		spawn_transform: Transform3D,
		target: Node3D,
		authority_owner: Node,
		owner_generation: int,
		escort_defender: RangeOpponent = null
	) -> Dictionary:
	if not escort_enabled:
		return {"accepted": false, "reason": &"escort_mode_disabled"}.duplicate(true)
	if (
		not is_instance_valid(target)
		or target.is_queued_for_deletion()
		or not target.is_inside_tree()
		or not is_instance_valid(authority_owner)
		or authority_owner.is_queued_for_deletion()
		or not authority_owner.is_inside_tree()
		or owner_generation <= 0
	):
		return {"accepted": false, "reason": &"invalid_dispatch_authority"}.duplicate(true)
	if is_instance_valid(escort_defender):
		if authority_owner != escort_defender or not escort_defender.is_active():
			return {"accepted": false, "reason": &"invalid_escort_owner"}.duplicate(true)
	elif not authority_owner.has_method(&"is_picket_dispatch_authorized"):
		return {"accepted": false, "reason": &"unsupported_dispatch_owner"}.duplicate(true)

	var activation := activate(spawn_transform)
	if not bool(activation.get("accepted", false)):
		return activation
	set_target(target)
	_dispatch_generation += 1
	_dispatch_owner_generation = owner_generation
	_dispatch_authority_owner = authority_owner
	_dispatch_owner_instance_id = authority_owner.get_instance_id()
	_dispatch_defender = escort_defender
	_escort_dispatched = true
	_escort_fire_authorized = true
	if is_instance_valid(_dispatch_defender):
		_bind_escort_defender_signal(_dispatch_defender)
	var receipt := activation.duplicate(true)
	receipt["dispatch_generation"] = _dispatch_generation
	receipt["owner_generation"] = _dispatch_owner_generation
	receipt["owner_instance_id"] = _dispatch_owner_instance_id
	return receipt


func deactivate() -> void:
	_revoke_dispatch_authorization(&"deactivated")
	_post_shot_relocation_remaining = 0.0
	_cancel_lance_charge(&"deactivated", false)
	_lance_charge_target_instance_id = 0
	_release_combat_registration()
	_discard_lance_receipts()
	super()
	_set_engagement_state(STATE_DORMANT)

func get_siege_lance_audio_binding() -> RefCounted:
	return _siege_lance_audio_binding

func _bind_siege_lance_audio() -> void:
	if _siege_lance_audio_binding == null:
		_siege_lance_audio_binding = SiegeLanceAudioBindingType.new()
	else:
		var snapshot: Dictionary = _siege_lance_audio_binding.get_snapshot()
		if bool(snapshot.get("attached", false)):
			return
	_siege_lance_audio_binding.attach(self, int(_siege_lance_audio_binding.get_snapshot().get("generation", 0)))

func _unbind_siege_lance_audio() -> void:
	if _siege_lance_audio_binding != null:
		_siege_lance_audio_binding.detach()


func _destroy_interceptor(death_position: Vector3) -> void:
	_revoke_dispatch_authorization(&"destroyed")
	_post_shot_relocation_remaining = 0.0
	_cancel_lance_charge(&"destroyed", false)
	_lance_charge_target_instance_id = 0
	_release_combat_registration()
	# The engagement latch stays claimed so a destroyed picket is not re-dispatched
	# while the same defender wave is still live.
	_escort_dispatched = true
	super(death_position)
	_set_engagement_state(STATE_DORMANT)


func _restore_after_reentry() -> void:
	if is_queued_for_deletion() or not is_inside_tree():
		return
	_connect_pulse_signals()
	_attach_damage_proxy()
	if _active:
		_register_combat_source()


# --------------------------------------------------------------- dispatch ----

## Dispatches and withdraws the picket with the defender wave it escorts. The
## delay is accumulated from fixed physics deltas, never from a wall clock.
func _update_escort_dispatch(delta: float) -> void:
	if not is_inside_tree():
		return
	if not escort_enabled:
		# A runtime switch to direct/manual use severs the old escort signal before
		# it can cancel a manual charge.
		if is_instance_valid(_dispatch_authority_owner) or is_instance_valid(_bound_escort_defender):
			_revoke_dispatch_authorization(&"manual_mode")
		return
	var defender := get_node_or_null(defender_path) as RangeOpponent
	if is_instance_valid(_dispatch_authority_owner):
		# A scenario-owned grant is deliberately independent of the ambient defender.
		if not is_instance_valid(_dispatch_defender):
			return
		if defender == _dispatch_defender and defender.is_active():
			return
		_stand_down_escort_dispatch(&"escort_owner_changed")
		return
	var defender_active := (
		is_instance_valid(defender)
		and defender.has_method(&"is_active")
		and bool(defender.call(&"is_active"))
	)
	if not defender_active:
		_escort_elapsed = 0.0
		if _escort_dispatched:
			_stand_down_escort_dispatch(&"escort_stood_down")
		return
	if _escort_dispatched or not _encounter_authorizes_dispatch():
		return
	if not is_finite(delta) or delta < 0.0:
		return
	_escort_elapsed += delta
	if _escort_elapsed < escort_launch_delay:
		return
	var target := _resolve_encounter_target()
	if not is_instance_valid(target):
		return
	var next_owner_generation := _dispatch_generation + 1
	var activation := activate_authorized_dispatch(
		_compute_dispatch_transform(defender, target),
		target,
		defender,
		next_owner_generation,
		defender,
	)
	if not bool(activation.get("accepted", false)):
		return


## Dispatch is authorized only while the coordinator is actually running its
## interceptor engagement. Withdrawal stays keyed to the defender wave, so a
## craft already in play is never stranded by a phase change. A non-coordinator
## host (isolated fixtures, evidence harnesses, tools) delegates the decision
## entirely to the defender it escorts.
func _encounter_authorizes_dispatch() -> bool:
	var host := get_node_or_null(encounter_host_path)
	if host is GameFlow:
		return (host as GameFlow).phase == GameFlow.Phase.INTERCEPTOR_ENGAGEMENT
	return true


## Fire rights belong to this escort dispatch, not to GameFlow. The explicit
## latch is granted only after a successful dispatch, synchronously revoked by
## the defender's terminal signal, and re-checked against the defender's public
## lifecycle state at the irreversible shot seam. Isolated/manual fixtures that
## disable escort dispatch retain the component's established direct-fire use.
func _is_fire_authorized() -> bool:
	if not _active or not is_inside_tree():
		return false
	if not escort_enabled:
		return true
	if not _escort_dispatched or not _escort_fire_authorized:
		return false
	if (
		not is_instance_valid(_dispatch_authority_owner)
		or _dispatch_authority_owner.get_instance_id() != _dispatch_owner_instance_id
		or not _dispatch_authority_owner.is_inside_tree()
		or _dispatch_owner_generation <= 0
	):
		return false
	if is_instance_valid(_dispatch_defender):
		return (
			_dispatch_authority_owner == _dispatch_defender
			and get_node_or_null(defender_path) == _dispatch_defender
			and _dispatch_defender.is_active()
		)
	return (
		_dispatch_authority_owner.has_method(&"is_picket_dispatch_authorized")
		and bool(_dispatch_authority_owner.call(
			&"is_picket_dispatch_authorized", self, _dispatch_owner_generation
		))
	)


func _bind_escort_defender_signal(defender: RangeOpponent) -> void:
	if not escort_enabled:
		return
	if defender == _bound_escort_defender:
		return
	_unbind_escort_defender_signal()
	_bound_escort_defender = defender
	if (
		is_instance_valid(_bound_escort_defender)
		and not _bound_escort_defender.destroyed.is_connected(_on_escort_defender_destroyed)
	):
		_bound_escort_defender.destroyed.connect(_on_escort_defender_destroyed)


func _unbind_escort_defender_signal() -> void:
	if (
		is_instance_valid(_bound_escort_defender)
		and _bound_escort_defender.destroyed.is_connected(_on_escort_defender_destroyed)
	):
		_bound_escort_defender.destroyed.disconnect(_on_escort_defender_destroyed)
	_bound_escort_defender = null


func _on_escort_defender_destroyed(_death_position: Vector3) -> void:
	if not escort_enabled or _bound_escort_defender != _dispatch_defender:
		return
	_stand_down_escort_dispatch(&"escort_stood_down")


func _stand_down_escort_dispatch(reason: StringName) -> void:
	var should_withdraw := _escort_dispatched and _active
	_revoke_dispatch_authorization(reason)
	if should_withdraw:
		deactivate()
		# `deactivate()` uses its general lifecycle reason. Retain the dispatch
		# owner's terminal reason for callers inspecting the cancelled charge.
		_cancel_lance_charge(reason, false)


func _revoke_dispatch_authorization(reason: StringName) -> void:
	_escort_fire_authorized = false
	_escort_dispatched = false
	_dispatch_owner_generation = 0
	_dispatch_owner_instance_id = 0
	_dispatch_authority_owner = null
	_dispatch_defender = null
	_unbind_escort_defender_signal()
	if _lance_charge_armed or _telegraph_remaining > 0.0:
		_cancel_lance_charge(reason, false)


func _resolve_encounter_target() -> Node3D:
	if is_instance_valid(_target) and _target.is_inside_tree():
		return _target
	var host := get_node_or_null(encounter_host_path)
	if is_instance_valid(host) and host.has_method(&"get_active_ship"):
		var active_ship := host.call(&"get_active_ship") as Node3D
		if is_instance_valid(active_ship) and active_ship.is_inside_tree():
			return active_ship
	return null


## Places the picket well behind and beside the defender, already looking at the
## target, so it reads on screen as a second wave holding back rather than as a
## duplicate of the craft the player is already fighting.
func _compute_dispatch_transform(defender: Node3D, target: Node3D) -> Transform3D:
	var anchor := defender.global_position if is_instance_valid(defender) else global_position
	var to_target := target.global_position - anchor
	if to_target.length_squared() <= 0.001:
		to_target = Vector3.FORWARD
	to_target = to_target.normalized()
	var lateral := Vector3.UP.cross(to_target)
	if lateral.length_squared() <= 0.001:
		lateral = Vector3.RIGHT
	lateral = lateral.normalized()
	var origin := anchor - to_target * 62.0 + lateral * 74.0 + Vector3.UP * 24.0
	var facing := target.global_position - origin
	if facing.length_squared() <= 0.001:
		facing = to_target
	var up := Vector3.UP
	if absf(facing.normalized().dot(up)) > 0.965:
		up = Vector3.FORWARD
	return Transform3D(Basis.looking_at(facing.normalized(), up).orthonormalized(), origin)


# ---------------------------------------------------------------- tactics ----

## Standoff kiting instead of the defender's tight orbit. Three bands: close to
## the standoff ring, hold it with a slow wide drift, and break directly away
## when the player gets inside the arming radius.
func _choose_motion_direction(target_direction: Vector3, distance: float) -> Vector3:
	var lateral := Vector3.UP.cross(target_direction)
	if lateral.length_squared() <= 0.001:
		lateral = Vector3.RIGHT
	lateral = lateral.normalized()
	if _post_shot_relocation_remaining > 0.0:
		# Preserve a shallow outward component so this is a firing-position break,
		# not a tight orbit. Geometry avoidance remains inherited and authoritative
		# movement still resolves through CharacterBody3D.move_and_slide().
		return (
			lateral * _post_shot_relocation_sign * 0.94
			- target_direction * 0.24
		).normalized()
	lateral *= _orbit_sign
	var weave := Vector3.UP * sin(_elapsed * 0.41 + 1.3) * 0.12
	var desired := Vector3.ZERO
	if distance < minimum_arming_range:
		# Break: face-on retreat, only a shallow lateral component so the escape
		# reads as a deliberate withdrawal instead of another orbit.
		desired = -target_direction * 0.94 + lateral * 0.26
	elif distance > standoff_range * 1.25:
		desired = target_direction * 0.92 + lateral * 0.18 + weave
	else:
		var band_error := clampf(
			(distance - standoff_range) / maxf(standoff_range, 1.0),
			-1.0,
			1.0
		)
		desired = lateral * 0.34 + target_direction * band_error * 0.72 + weave
	if desired.length_squared() <= 0.001:
		return target_direction
	return desired.normalized()


## Long, cancellable lance charge with a hard minimum arming radius.
func _update_weapon(
		target_position: Vector3,
		target_direction: Vector3,
		distance: float,
		delta: float
	) -> void:
	var forward := -global_basis.z
	if _telegraph_remaining > 0.0:
		var aim_held := forward.dot(target_direction) >= lance_hold_tolerance
		var in_band := distance <= engagement_range and distance >= minimum_arming_range
		if not in_band or not aim_held or not _has_line_of_sight(target_position):
			# Closing the gap, breaking the cone, or breaking line of sight all
			# cancel a committed charge and cost the picket real time.
			_cancel_lance_charge(&"counterplay", true)
			_cooldown_remaining = maxf(_cooldown_remaining, lance_abort_recovery)
			_shots_aborted += 1
			_emit_siege_lance_audio(&"aborted", true)
			return
		_telegraph_remaining = maxf(0.0, _telegraph_remaining - delta)
		if _telegraph_remaining <= 0.0:
			_fire_at_target(_get_target_aim_position())
		return
	if _cooldown_remaining > 0.0:
		return
	if distance > engagement_range or distance < minimum_arming_range:
		return
	if forward.dot(target_direction) < lance_aim_tolerance:
		return
	if not _has_line_of_sight(target_position):
		return
	_lance_charge_target_instance_id = _target.get_instance_id()
	_lance_charge_generation = maxi(_lance_charge_generation, 1)
	_lance_charge_dispatch_generation = _dispatch_generation if escort_enabled else 0
	_lance_charge_armed = true
	_lance_charge_cancel_reason = &""
	_telegraph_remaining = telegraph_time
	_emit_siege_lance_audio(&"charge_started", true)


func _update_engagement_state() -> void:
	if not _active:
		_set_engagement_state(STATE_DORMANT)
		return
	if not is_instance_valid(_target):
		_set_engagement_state(STATE_CLOSING)
		return
	if _post_shot_relocation_remaining > 0.0:
		_set_engagement_state(STATE_RELOCATING)
		return
	var distance := global_position.distance_to(_get_target_aim_position())
	if distance < minimum_arming_range:
		_set_engagement_state(STATE_BREAKING)
	elif distance > standoff_range * 1.25:
		_set_engagement_state(STATE_CLOSING)
	else:
		_set_engagement_state(STATE_HOLDING)


func _cancel_lance_charge(reason: StringName, count_abort: bool) -> void:
	if _telegraph_remaining > 0.0 and count_abort:
		_shots_aborted += 1
	if _telegraph_remaining > 0.0:
		_telegraph_remaining = 0.0
	_lance_charge_armed = false
	_lance_charge_dispatch_generation = 0
	_lance_charge_cancel_reason = reason


func _is_lance_charge_authorized() -> bool:
	return (
		_lance_charge_armed
		and _has_current_target()
		and _target.get_instance_id() == _lance_charge_target_instance_id
		and _lance_charge_generation > 0
		and (not escort_enabled or _lance_charge_dispatch_generation == _dispatch_generation)
	)


func _set_engagement_state(state: StringName) -> void:
	if _engagement_state == state:
		return
	_engagement_state = state
	engagement_state_changed.emit(state)


# ----------------------------------------------------------------- firing ----

## Resolves one lance shot on the single live `CombatResolver` under this craft's
## registered identity, then consumes the shared pooled presentation seams. No
## ray query, health store, or damage application lives here.
func _fire_at_target(target_position: Vector3) -> void:
	if not _active or not is_inside_tree():
		return
	# A charge can finish before the next escort physics pass after its defender
	# stands down. Re-ask this dispatch's own authorization here, as the shared
	# resolver-backed opponents do, before allocating a receipt or sequence.
	if not _is_fire_authorized():
		if _lance_charge_armed or _telegraph_remaining > 0.0:
			_cancel_lance_charge(&"authorization_lost", false)
		_cooldown_remaining = maxf(_cooldown_remaining, weapon_cooldown)
		_last_shot_result = {"accepted": false, "status": &"fire_unauthorized"}
		return
	if _lance_charge_armed and not _is_lance_charge_authorized():
		_cancel_lance_charge(&"charge_revalidated_failed", false)
		return
	var authority := _get_combat_authority()
	var resolver: CombatResolver = (
		authority.get_resolver() as CombatResolver if is_instance_valid(authority) else null
	)
	if not is_instance_valid(resolver) or not _registered:
		_cancel_lance_charge(&"authority_unavailable", false)
		_cooldown_remaining = weapon_cooldown
		return
	var definition := _weapon_definition
	if definition == null or not definition.is_definition_valid():
		_cancel_lance_charge(&"weapon_definition_invalid", false)
		_cooldown_remaining = weapon_cooldown
		_last_shot_result = {"accepted": false, "status": &"weapon_definition_invalid"}
		return
	var muzzle := _muzzle_port if is_instance_valid(_muzzle_port) else self as Node3D
	var origin: Vector3 = muzzle.global_position
	var direction := target_position - origin
	if direction.length_squared() <= 0.000001:
		direction = -global_basis.z
	direction = direction.normalized()

	# One receipt from the shared session-monotonic allocator. Saturation fails
	# closed here exactly as it does inside the authority's own submit path.
	var receipt_id := authority.allocate_presentation_receipt_id()
	if receipt_id < 0:
		_cooldown_remaining = weapon_cooldown
		_last_shot_result = {"accepted": false, "status": &"receipt_exhausted"}
		return
	var sequence := resolver.get_last_sequence(self, source_id) + 1
	var request := ShotRequest.new(
		self,
		source_id,
		faction_id,
		LANCE_WEAPON_ID,
		sequence,
		origin,
		direction,
		definition.range_meters,
		definition.damage_per_hit,
		receipt_id
	)
	var result := resolver.resolve_hitscan(request)
	_lance_charge_armed = false
	_lance_charge_cancel_reason = &""
	_emit_siege_lance_audio(&"dispatch", bool(result.get("accepted", false)))
	_cooldown_remaining = weapon_cooldown
	_last_shot_result = result.duplicate(true)
	_shots_fired += 1
	if bool(result.get("accepted", false)) and bool(result.get("resolved", false)):
		_begin_post_shot_relocation()
	# `projectile_fired` is deliberately NOT raised. On the defender that signal is
	# a request for the coordinator to submit a shot; this craft has already
	# resolved its own, so re-raising it could produce a second submission.
	lance_fired.emit(origin, direction, result.duplicate(true))
	if not bool(result.get("accepted", false)) or not bool(result.get("resolved", false)):
		return
	_emit_siege_lance_audio(&"impact", true)
	_spawn_muzzle_flash(origin)
	_present_lance_shot(origin, direction, receipt_id, result)


func _begin_post_shot_relocation() -> void:
	_post_shot_relocation_sign *= -1.0
	_post_shot_relocation_remaining = post_shot_relocation_duration


func _present_lance_shot(
		origin: Vector3,
		direction: Vector3,
		receipt_id: int,
		result: Dictionary
	) -> void:
	var endpoint_range := _weapon_definition.range_meters if _weapon_definition != null else lance_range
	var endpoint := origin + direction * endpoint_range
	if bool(result.get("hit", false)):
		var resolved_position: Variant = result.get("position", endpoint)
		if resolved_position is Vector3 and (resolved_position as Vector3).is_finite():
			endpoint = resolved_position as Vector3
	var audio := _get_combat_audio()
	if is_instance_valid(audio):
		audio.play_opponent_weapon_fire(
			origin, get_instance_id(), LANCE_AUDIO_PROFILE
		)
	var damaged := bool(result.get("damaged", false))
	if damaged:
		_record_lance_receipt(receipt_id, result, endpoint)
		_flash_target_damage(origin, result)
	# A receipt only travels with a shot that actually queued target presentation.
	# A miss or a blocked shot carries none, so no listener can be handed an ID
	# with nothing behind it.
	var presented := false
	var pulse := _get_pulse_presentation()
	if is_instance_valid(pulse):
		presented = pulse.present_shot(
			origin,
			endpoint,
			LANCE_PULSE_STYLE,
			self,
			bool(result.get("hit", false)),
			receipt_id if damaged else -1,
			LANCE_PULSE_PROFILE
		)
	if damaged and not presented:
		# The pool refused or is unavailable. Authority is already final, so the
		# queued target presentation is released immediately rather than stranded.
		_finalize_lance_receipt(receipt_id, endpoint, true)


func _record_lance_receipt(receipt_id: int, result: Dictionary, endpoint: Vector3) -> void:
	var target_entity: Variant = result.get("target_entity")
	var terminal := bool(result.get("destroyed", false))
	var terminal_position := endpoint
	var target_instance_id := 0
	if is_instance_valid(target_entity):
		target_instance_id = (target_entity as Object).get_instance_id()
		if terminal and target_entity is Node3D:
			terminal_position = (target_entity as Node3D).global_position
	_lance_receipts[receipt_id] = {
		"target": weakref(target_entity) if is_instance_valid(target_entity) else null,
		"target_instance_id": target_instance_id,
		"endpoint": endpoint,
		"terminal_position": terminal_position,
		"terminal": terminal,
	}
	_lance_receipt_order.append(receipt_id)
	while _lance_receipt_order.size() > MAX_PENDING_LANCE_RECEIPTS:
		var evicted: int = _lance_receipt_order.pop_front()
		_lance_receipts.erase(evicted)


func _emit_siege_lance_audio(event_id: StringName, accepted: bool) -> void:
	_audio_sequence += 1
	siege_lance_audio_record.emit({
		"generation": 0,
		"sequence": _audio_sequence,
		"transaction_id": StringName("picket_siege_lance_%d" % _audio_sequence),
		"weapon_id": LANCE_WEAPON_ID,
		"event_id": event_id,
		"accepted": accepted,
	}.duplicate(true))
	if accepted and event_id == &"charge_started":
		_present_siege_lance_charge_caption()


## Mirrors the already-armed charge event into the retained accessible caption
## ingress. This is presentation-only: it performs no target query, changes no
## charge state, and never submits a shot or damage request.
func _present_siege_lance_charge_caption() -> void:
	var hud := get_node_or_null(hud_path)
	if not is_instance_valid(hud) or not hud.has_method(&"present_semantic_audio_cue"):
		return
	hud.call(
		&"present_semantic_audio_cue",
		&"siege_lance_charge",
		&"threat_warning",
		1.0,
		global_position,
	)


## Directional hit feedback. The coordinator owns this cue for the defender it
## knows about; the picket raises the same presentation-only cue for its own
## shots without touching hull, score, or phase state.
func _flash_target_damage(origin: Vector3, result: Dictionary) -> void:
	var hud := get_node_or_null(hud_path)
	var target_entity: Variant = result.get("target_entity")
	if (
		not is_instance_valid(hud)
		or not hud.has_method(&"flash_damage")
		or not is_instance_valid(target_entity)
		or target_entity is not Node3D
	):
		return
	var target_node := target_entity as Node3D
	var local_source := target_node.global_basis.inverse() * (origin - target_node.global_position)
	hud.call(
		&"flash_damage",
		float(result.get("applied_damage", _weapon_definition.damage_per_hit if _weapon_definition != null else lance_damage)) / 20.0,
		Vector2(local_source.x, local_source.z)
	)


# ------------------------------------------------------ receipt lifecycle ----

func _on_lance_receipt_ready(receipt_id: int, position: Vector3) -> void:
	if not _lance_receipts.has(receipt_id):
		return
	_finalize_lance_receipt(receipt_id, position, false)


func _on_lance_receipt_aborted(receipt_id: int) -> void:
	if not _lance_receipts.has(receipt_id):
		return
	# The visual was recycled or torn down before arrival. Damage authority is
	# already committed, so release the queued target presentation now instead of
	# leaving a damaged hull visually pending forever.
	_finalize_lance_receipt(receipt_id, Vector3.INF, true)


func _finalize_lance_receipt(
		receipt_id: int,
		arrival_position: Vector3,
		play_impact_cue: bool
	) -> void:
	var record := _lance_receipts.get(receipt_id, {}) as Dictionary
	_lance_receipts.erase(receipt_id)
	_lance_receipt_order.erase(receipt_id)
	if record.is_empty():
		return
	var endpoint := record.get("endpoint", Vector3.INF) as Vector3
	if arrival_position.is_finite():
		endpoint = arrival_position
	var audio := _get_combat_audio()
	if play_impact_cue and is_instance_valid(audio) and endpoint.is_finite() and is_inside_tree():
		audio.play_impact(endpoint, 0.9, get_instance_id())
	var target_reference := record.get("target") as WeakRef
	var target := target_reference.get_ref() as Node if target_reference != null else null
	# The target's own commit is one-shot and idempotent, so it does not matter
	# whether the coordinator's pooled-impact listener reached it first; the queued
	# presentation is released exactly once either way. The lethal cue is still
	# ours to raise, because the coordinator holds no record of a shot it did not
	# submit and would otherwise leave a destroyed hull silent.
	if is_instance_valid(target) and target.has_method(&"commit_deferred_damage_presentation"):
		target.call(&"commit_deferred_damage_presentation", receipt_id)
	if bool(record.get("terminal", false)) and is_instance_valid(audio) and is_inside_tree():
		var effect_position := record.get("terminal_position", endpoint) as Vector3
		if not effect_position.is_finite():
			effect_position = endpoint
		if effect_position.is_finite():
			audio.play_explosion(
				effect_position,
				maxi(int(record.get("target_instance_id", 0)), 0)
			)


func _discard_lance_receipts() -> void:
	_lance_receipts.clear()
	_lance_receipt_order.clear()


# ------------------------------------------------------------- authority ----

func _register_combat_source() -> void:
	var authority := _get_combat_authority()
	if not is_instance_valid(authority):
		return
	if _registered and authority.get_source_id(self) == source_id:
		return
	_registered = authority.register_source(self, source_id, faction_id, get_weapon_profiles())


func _release_combat_registration() -> void:
	if not _registered:
		return
	_registered = false
	var authority := _get_combat_authority()
	if is_instance_valid(authority):
		# Retire only the live registration: the stable identity keeps its replay
		# high-water mark so a captured pre-withdrawal request stays stale.
		authority.retire_source_registration(self, source_id)


func _attach_damage_proxy() -> void:
	var authority := _get_combat_authority()
	if not is_instance_valid(authority):
		return
	authority.attach_lifecycle_damageable(
		self,
		LifecycleDamageableAdapter.LifecycleKind.RANGE_OPPONENT,
		faction_id
	)


func _get_combat_authority() -> LiveCombatAuthority:
	return get_node_or_null(combat_authority_path) as LiveCombatAuthority


func _get_pulse_presentation() -> PulseWeaponPresentation:
	return get_node_or_null(pulse_presentation_path) as PulseWeaponPresentation


func _get_combat_audio() -> CombatAudioPresentation:
	return get_node_or_null(combat_audio_path) as CombatAudioPresentation


func _connect_pulse_signals() -> void:
	if _pulse_signals_connected:
		return
	var pulse := _get_pulse_presentation()
	if not is_instance_valid(pulse):
		return
	if not pulse.impact_receipt_ready.is_connected(_on_lance_receipt_ready):
		pulse.impact_receipt_ready.connect(_on_lance_receipt_ready)
	if not pulse.impact_receipt_aborted.is_connected(_on_lance_receipt_aborted):
		pulse.impact_receipt_aborted.connect(_on_lance_receipt_aborted)
	_pulse_signals_connected = true


func _disconnect_pulse_signals() -> void:
	_pulse_signals_connected = false
	var pulse := _get_pulse_presentation()
	if not is_instance_valid(pulse):
		return
	if pulse.impact_receipt_ready.is_connected(_on_lance_receipt_ready):
		pulse.impact_receipt_ready.disconnect(_on_lance_receipt_ready)
	if pulse.impact_receipt_aborted.is_connected(_on_lance_receipt_aborted):
		pulse.impact_receipt_aborted.disconnect(_on_lance_receipt_aborted)


# ---------------------------------------------------------- presentation ----

## The long-cadence lance focuses through three retained nodes: a lengthened
## emitter, a large muzzle lens, and a smaller spine witness. These are static,
## non-color multipliers on the inherited charge size, not another animation or
## weapon state.
func _update_presentation(delta: float) -> void:
	super(delta)
	if not _active or _telegraph_remaining <= 0.0:
		return
	if is_instance_valid(_lance_emitter):
		_lance_emitter.scale *= LANCE_EMITTER_CHARGE_SCALE
	if is_instance_valid(_lance_lens):
		_lance_lens.scale *= LANCE_LENS_CHARGE_SCALE
	if _warning_lenses.size() >= 3 and is_instance_valid(_warning_lenses[2]):
		_warning_lenses[2].scale *= LANCE_SPINE_CHARGE_SCALE

## Builds the picket hull. Every primitive helper, material helper, particle
## helper, and the inherited charge/engine animation are reused from
## `RangeOpponent`; only the silhouette, palette, and mounts differ.
func _build_interceptor() -> void:
	if _built:
		return
	_built = true
	motion_mode = CharacterBody3D.MOTION_MODE_FLOATING
	floor_stop_on_slope = false
	# The picket band is the single source of truth for its tactics. The inherited
	# orbit fields are kept in step so the shared movement loop bands speed against
	# the same distances this craft actually manoeuvres to.
	preferred_range = standoff_range
	retreat_range = minimum_arming_range
	_create_materials()
	_create_picket_materials()
	_visual_root = Node3D.new()
	_visual_root.name = "StandoffPicketVisual"
	add_child(_visual_root)

	# A long dark spine with a single forward lance barrel. Deliberately the
	# opposite read from the defender's broad ivory forked dart.
	_wedge(_visual_root, "SpineNose", Vector3(0.0, 0.0, -2.6), Vector3(1.15, 0.9, 5.4), _materials.picket_hull)
	_picket_box(_visual_root, "SpineBody", Vector3(0.0, 0.0, 1.4), Vector3(1.25, 1.0, 6.2), _materials.picket_hull)
	_picket_box(_visual_root, "SpineKeel", Vector3(0.0, -0.62, 1.6), Vector3(0.8, 0.34, 5.4), _materials.picket_deep)
	_picket_box(_visual_root, "DorsalRail", Vector3(0.0, 0.66, 1.9), Vector3(0.42, 0.3, 4.6), _materials.picket_slate)
	# A continuous dorsal identification stripe. This is the identity read that
	# survives at standoff distance where hull tone alone does not.
	_picket_box(_visual_root, "DorsalStripe", Vector3(0.0, 0.83, 1.2), Vector3(0.2, 0.06, 7.4), _materials.picket_magenta)
	_picket_box(_visual_root, "FlankStripePort", Vector3(-0.64, 0.2, 1.2), Vector3(0.06, 0.16, 6.6), _materials.picket_magenta)
	_picket_box(_visual_root, "FlankStripeStarboard", Vector3(0.64, 0.2, 1.2), Vector3(0.06, 0.16, 6.6), _materials.picket_magenta)
	_wedge(_visual_root, "SensorCowl", Vector3(0.0, 0.68, -1.1), Vector3(0.9, 0.5, 2.4), _materials.picket_slate)
	_sphere(_visual_root, "SensorBlister", Vector3(0.0, 0.78, -1.9), 0.26, _materials.picket_magenta)

	# Forward lance barrel. The charge lens is the long-range read.
	_cylinder(_visual_root, "LanceBarrel", Vector3(0.0, -0.06, -5.6), 0.3, 5.6, _materials.picket_slate, Vector3(90.0, 0.0, 0.0))
	_cylinder(_visual_root, "LanceCollar", Vector3(0.0, -0.06, -3.2), 0.46, 0.5, _materials.picket_deep, Vector3(90.0, 0.0, 0.0))
	_add_lance_rail_batch(_visual_root)
	_cylinder(_visual_root, "LanceMuzzleRing", Vector3(0.0, -0.06, -8.15), 0.38, 0.32, _materials.picket_deep, Vector3(90.0, 0.0, 0.0))
	_lance_emitter = _cylinder(
		_visual_root, "LanceEmitter", Vector3(0.0, -0.06, -8.4), 0.17, 0.4,
		_materials.picket_violet_emissive, Vector3(90.0, 0.0, 0.0)
	)
	_warning_lenses.append(_lance_emitter)
	_lance_lens = _sphere(_visual_root, "LanceChargeLens", Vector3(0.0, -0.06, -8.62), 0.22, _materials.picket_magenta_emissive)
	_warning_lenses.append(_lance_lens)
	var spine_lens := _sphere(_visual_root, "LanceSpineLens", Vector3(0.0, 0.34, -3.4), 0.15, _materials.picket_magenta_emissive)
	_warning_lenses.append(spine_lens)
	_add_engine_pod_batch(_visual_root)
	_add_engine_core_batch(_visual_root)
	_add_radiator_vane_batch(_visual_root)

	for side in [-1.0, 1.0]:
		# Swept radiator vanes replace the defender's forward prongs entirely.
		_picket_box(_visual_root, "VaneSpar", Vector3(side * 1.15, 0.05, 2.3), Vector3(1.9, 0.28, 0.6), _materials.picket_slate, Vector3(0.0, side * 0.46, 0.0))
		_picket_box(_visual_root, "VaneStripe", Vector3(side * 2.9, 0.22, 3.5), Vector3(2.1, 0.06, 0.24), _materials.picket_magenta, Vector3(0.0, side * 0.46, 0.0))
		_picket_box(_visual_root, "VaneTipFin", Vector3(side * 3.85, 0.5, 4.0), Vector3(0.18, 1.0, 1.5), _materials.picket_bone, Vector3(0.0, side * 0.24, side * -0.2))

		var plume := _cylinder(_visual_root, "EnginePlume", Vector3(side * 0.86, -0.02, 5.42), 0.17, 0.7, _materials.picket_engine, Vector3(90.0, 0.0, 0.0))
		_engine_glows.append(plume)
		var engine_light := OmniLight3D.new()
		engine_light.name = "EngineLight"
		engine_light.position = Vector3(side * 0.86, -0.02, 5.1)
		engine_light.light_color = PICKET_ENGINE
		engine_light.light_energy = 0.0
		engine_light.omni_range = 4.6
		engine_light.shadow_enabled = false
		_visual_root.add_child(engine_light)
		_engine_lights.append(engine_light)

	_muzzle_port = Marker3D.new()
	_muzzle_port.name = "LanceMuzzle"
	_muzzle_port.position = Vector3(0.0, -0.06, -8.75)
	add_child(_muzzle_port)
	# The picket mounts a single lance. The inherited alternating-muzzle field is
	# pinned to the same marker so no inherited path can fire from a phantom port.
	_muzzle_starboard = _muzzle_port

	_warning_light = OmniLight3D.new()
	_warning_light.name = "LanceChargeLight"
	_warning_light.position = Vector3(0.0, -0.06, -8.2)
	_warning_light.light_color = LANCE_MAGENTA
	_warning_light.light_energy = 0.0
	_warning_light.omni_range = 11.0
	_warning_light.shadow_enabled = false
	add_child(_warning_light)

	_build_collision()
	_build_damage_effects()


## The mirrored pod shells are immutable presentation only. Their animated core
## and plume peers remain independent MeshInstance3Ds in the engine-glow arrays.
func _add_engine_pod_batch(parent: Node3D) -> MultiMeshInstance3D:
	var mesh := StationSurfaceKit.chamfered_cylinder_mesh_cached(
		0.4, 0.4, 1.5, 28, _chamfered_cylinder_cache,
		ShipSurfaceDetail.CYLINDER_WALL_RINGS, true, true, _materials.picket_deep
	)
	var transforms: Array[Transform3D] = [
		Transform3D(Basis.from_euler(Vector3(deg_to_rad(90.0), 0.0, 0.0)), Vector3(-0.86, -0.02, 4.3)),
		Transform3D(Basis.from_euler(Vector3(deg_to_rad(90.0), 0.0, 0.0)), Vector3(0.86, -0.02, 4.3)),
	]
	var multi := MultiMesh.new()
	multi.transform_format = MultiMesh.TRANSFORM_3D
	multi.mesh = mesh
	multi.instance_count = ENGINE_POD_COPY_COUNT
	multi.visible_instance_count = -1
	var bounds := AABB()
	for index in ENGINE_POD_COPY_COUNT:
		multi.set_instance_transform(index, transforms[index])
		var instance_bounds := (transforms[index] * mesh.get_aabb()).abs()
		bounds = instance_bounds if index == 0 else bounds.merge(instance_bounds)
	multi.custom_aabb = bounds
	var batch := MultiMeshInstance3D.new()
	batch.name = "EnginePodBatch"
	batch.multimesh = multi
	batch.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	batch.set_meta(&"presentation_only", true)
	batch.set_meta(&"authored_visual_names", PackedStringArray(["PortEnginePod", "StarboardEnginePod"]))
	batch.set_meta(&"authored_instance_transforms", transforms.duplicate())
	parent.add_child(batch)
	return batch


## The mirrored engine cores are static visual caps. The independently retained
## plumes remain in `_engine_glows`, so thrust animation and reuse reset keep
## their existing per-side lifecycle while this immutable pair submits once.
func _add_engine_core_batch(parent: Node3D) -> MultiMeshInstance3D:
	var mesh := StationSurfaceKit.chamfered_cylinder_mesh_cached(
		0.27, 0.27, 0.16, 28, _chamfered_cylinder_cache,
		ShipSurfaceDetail.CYLINDER_WALL_RINGS, true, true, _materials.picket_engine
	)
	var core_basis := Basis.from_euler(Vector3(deg_to_rad(90.0), 0.0, 0.0))
	var transforms: Array[Transform3D] = [
		Transform3D(core_basis, Vector3(-0.86, -0.02, 5.02)),
		Transform3D(core_basis, Vector3(0.86, -0.02, 5.02)),
	]
	var multi := MultiMesh.new()
	multi.transform_format = MultiMesh.TRANSFORM_3D
	multi.mesh = mesh
	multi.instance_count = ENGINE_CORE_COPY_COUNT
	multi.visible_instance_count = -1
	var bounds := AABB()
	for index in ENGINE_CORE_COPY_COUNT:
		multi.set_instance_transform(index, transforms[index])
		var instance_bounds := (transforms[index] * mesh.get_aabb()).abs()
		bounds = instance_bounds if index == 0 else bounds.merge(instance_bounds)
	multi.custom_aabb = bounds
	var batch := MultiMeshInstance3D.new()
	batch.name = "EngineCoreBatch"
	batch.multimesh = multi
	batch.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	batch.set_meta(&"presentation_only", true)
	batch.set_meta(&"authored_visual_names", PackedStringArray(["PortEngineCore", "StarboardEngineCore"]))
	batch.set_meta(&"authored_instance_transforms", transforms.duplicate())
	parent.add_child(batch)
	return batch


## The mirrored lance rails are an immutable identification detail. Neither
## rail participates in lance aiming, charge animation, collision or damage;
## the independently named emitter, lens and muzzle retain those live roles.
func _add_lance_rail_batch(parent: Node3D) -> MultiMeshInstance3D:
	var mesh := StationSurfaceKit.chamfered_cylinder_mesh_cached(
		0.07, 0.07, 4.6, 28, _chamfered_cylinder_cache,
		ShipSurfaceDetail.CYLINDER_WALL_RINGS, true, true, _materials.picket_magenta
	)
	var rail_basis := Basis.from_euler(Vector3(deg_to_rad(90.0), 0.0, 0.0))
	var transforms: Array[Transform3D] = [
		Transform3D(rail_basis, Vector3(-0.34, 0.16, -5.4)),
		Transform3D(rail_basis, Vector3(0.34, 0.16, -5.4)),
	]
	var multi := MultiMesh.new()
	multi.transform_format = MultiMesh.TRANSFORM_3D
	multi.mesh = mesh
	multi.instance_count = LANCE_RAIL_COPY_COUNT
	multi.visible_instance_count = -1
	var bounds := AABB()
	for index in LANCE_RAIL_COPY_COUNT:
		multi.set_instance_transform(index, transforms[index])
		var instance_bounds := (transforms[index] * mesh.get_aabb()).abs()
		bounds = instance_bounds if index == 0 else bounds.merge(instance_bounds)
	multi.custom_aabb = bounds
	var batch := MultiMeshInstance3D.new()
	batch.name = "LanceRailBatch"
	batch.multimesh = multi
	batch.layers = 1
	batch.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	batch.set_meta(&"presentation_only", true)
	batch.set_meta(&"authored_visual_names", PackedStringArray(["LanceRailPort", "LanceRailStarboard"]))
	batch.set_meta(&"authored_instance_transforms", transforms.duplicate())
	parent.add_child(batch)
	return batch


## The broad mirrored radiator shells are immutable silhouette geometry. Their
## collision remains in the independently authored vane CollisionShape3Ds, so
## batching only the visible pair cannot affect movement or hit resolution.
func _add_radiator_vane_batch(parent: Node3D) -> MultiMeshInstance3D:
	var mesh := _picket_box_mesh(Vector3(3.7, 0.16, 3.1), _materials.picket_bone)
	var transforms: Array[Transform3D] = [
		Transform3D(Basis.from_euler(Vector3(0.0, -0.46, 0.12)), Vector3(-2.3, 0.12, 2.9)),
		Transform3D(Basis.from_euler(Vector3(0.0, 0.46, -0.12)), Vector3(2.3, 0.12, 2.9)),
	]
	var multi := MultiMesh.new()
	multi.transform_format = MultiMesh.TRANSFORM_3D
	multi.mesh = mesh
	multi.instance_count = RADIATOR_VANE_COPY_COUNT
	multi.visible_instance_count = -1
	var bounds := AABB()
	for index in RADIATOR_VANE_COPY_COUNT:
		multi.set_instance_transform(index, transforms[index])
		var instance_bounds := (transforms[index] * mesh.get_aabb()).abs()
		bounds = instance_bounds if index == 0 else bounds.merge(instance_bounds)
	multi.custom_aabb = bounds
	var batch := MultiMeshInstance3D.new()
	batch.name = "RadiatorVaneBatch"
	batch.multimesh = multi
	batch.layers = 1
	batch.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	batch.set_meta(&"presentation_only", true)
	batch.set_meta(&"authored_visual_names", PackedStringArray(["PortRadiatorVane", "StarboardRadiatorVane"]))
	batch.set_meta(&"authored_instance_transforms", transforms.duplicate())
	parent.add_child(batch)
	return batch


## Component-owned immutable primitive cache. Size and bound surface material
## form the complete BoxMesh recipe; transforms and names remain per-node.
func _picket_box(
		parent: Node3D,
		node_name: String,
		position_value: Vector3,
		size: Vector3,
		material: Material,
		rotation_value := Vector3.ZERO,
	) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.name = node_name
	instance.position = position_value
	instance.rotation = rotation_value
	instance.mesh = _picket_box_mesh(size, material)
	parent.add_child(instance)
	return instance


func _picket_box_mesh(size: Vector3, material: Material) -> BoxMesh:
	var cache_key := "box:%0.4f:%0.4f:%0.4f:%d" % [
		size.x,
		size.y,
		size.z,
		0 if material == null else material.get_instance_id(),
	]
	var mesh := _picket_box_mesh_cache.get(cache_key) as BoxMesh
	if mesh == null:
		mesh = BoxMesh.new()
		mesh.size = size
		mesh.material = material
		_picket_box_mesh_cache[cache_key] = mesh
	return mesh


func _build_collision() -> void:
	var spine := CollisionShape3D.new()
	spine.name = "SpineCollision"
	spine.position = Vector3(0.0, 0.0, 0.4)
	var spine_shape := BoxShape3D.new()
	spine_shape.size = Vector3(1.4, 1.5, 10.2)
	spine.shape = spine_shape
	add_child(spine)

	var barrel := CollisionShape3D.new()
	barrel.name = "LanceBarrelCollision"
	barrel.position = Vector3(0.0, -0.06, -6.2)
	var barrel_shape := BoxShape3D.new()
	barrel_shape.size = Vector3(0.75, 0.75, 5.4)
	barrel.shape = barrel_shape
	add_child(barrel)

	for side in [-1.0, 1.0]:
		var vane := CollisionShape3D.new()
		vane.name = "PortVaneCollision" if side < 0.0 else "StarboardVaneCollision"
		vane.position = Vector3(side * 2.3, 0.12, 3.0)
		var vane_shape := BoxShape3D.new()
		vane_shape.size = Vector3(3.6, 0.6, 3.2)
		vane.shape = vane_shape
		vane.rotation = Vector3(0.0, side * 0.46, 0.0)
		add_child(vane)


func _build_damage_effects() -> void:
	_damage_sparks = _make_spark_particles(16, 0.68, 4.0)
	_damage_sparks.name = "DamageSparks"
	_damage_sparks.position = Vector3(0.5, 0.35, 1.6)
	_damage_sparks.one_shot = false
	_damage_sparks.emitting = false
	add_child(_damage_sparks)
	_damage_smoke = _make_smoke_particles(false)
	_damage_smoke.name = "LanceSmoke"
	_damage_smoke.position = Vector3(-0.86, 0.1, 4.6)
	_damage_smoke.emitting = false
	add_child(_damage_smoke)


func _create_picket_materials() -> void:
	_materials.picket_hull = _material(HULL_GRAPHITE, 0.34, 0.46)
	_materials.picket_slate = _material(HULL_SLATE, 0.42, 0.4)
	_materials.picket_deep = _material(Color("2a3038"), 0.55, 0.32)
	_materials.picket_bone = _material(HULL_BONE, 0.24, 0.5)
	_materials.picket_magenta = _material(LANCE_MAGENTA, 0.2, 0.28, LANCE_MAGENTA, 2.4)
	_materials.picket_magenta_emissive = _material(LANCE_MAGENTA, 0.1, 0.2, LANCE_MAGENTA, 3.1)
	_materials.picket_violet_emissive = _material(LANCE_VIOLET, 0.12, 0.22, LANCE_VIOLET, 2.4)
	_materials.picket_engine = _material(PICKET_ENGINE, 0.08, 0.2, PICKET_ENGINE, 2.6)
