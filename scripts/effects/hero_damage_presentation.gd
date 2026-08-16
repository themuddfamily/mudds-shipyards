class_name HeroDamagePresentation
extends Node3D

## Reusable, ship-local damage presentation for the hero craft.
##
## The owning ship remains authoritative for health, handling and visibility.
## Feed this component a normalized health value, a lightweight operating state,
## and world-space velocity through [method update_state]. Persistent effects are
## attached at local anchors; impacts and destruction are detached into world
## space so a moving, scaled or subsequently hidden ship cannot drag them along.

signal stage_changed(stage: int, health_ratio: float)
signal status_changed(status: StringName, health_ratio: float)
signal alarm_changed(active: bool, urgency: float)
signal engine_failure_changed(active: bool, power_multiplier: float)
signal destruction_started(world_position: Vector3, inherited_velocity: Vector3)
signal effects_cleared
## Emitted whenever the localized component channel gains, loses, or re-grades a
## section rig. `modern_interpretation` -- no source authenticates the roster.
signal component_effects_changed(active_component_count: int)

enum DamageStage {
	HEALTHY,
	DAMAGED,
	CRITICAL,
	DESTROYED,
}

const STATE_ACTIVE: StringName = &"active"
const STATE_POWERED_DOWN: StringName = &"powered_down"
const STATE_HIDDEN: StringName = &"hidden"
const STATE_DESTROYED: StringName = &"destroyed"

const STATUS_HEALTHY: StringName = &"healthy"
const STATUS_DAMAGED: StringName = &"damaged"
const STATUS_CRITICAL: StringName = &"critical"
const STATUS_DESTROYED: StringName = &"destroyed"

const WORLD_COLLISION_LAYER := 1
const DAMAGE_AMBER := Color("ffb14e")
const DAMAGE_ORANGE := Color("ff6d2e")
const DAMAGE_RED := Color("ff3b35")
const ENGINE_CYAN := Color("62efff")
const SMOKE_COLOR := Color(0.045, 0.065, 0.075, 0.72)
const DEBRIS_DARK := Color("12242b")
const DEBRIS_IVORY := Color("dedbd0")

@export_category("Damage thresholds")
@export_range(0.05, 0.95, 0.01) var damaged_threshold := 0.68
@export_range(0.01, 0.90, 0.01) var critical_threshold := 0.32

@export_category("Local effect anchors")
@export var spark_anchor := Vector3(-3.65, 1.05, 0.9)
@export var smoke_anchor := Vector3(-1.75, 1.0, 4.85)
@export var warning_anchor := Vector3(0.0, 2.62, -0.55)

@export_category("Effect lifetime")
@export_range(0.05, 10.0, 0.05) var impact_effect_lifetime := 0.85
@export_range(0.1, 20.0, 0.1) var destruction_effect_lifetime := 5.0
@export_range(1, 24, 1) var destruction_debris_count := 10

var _built := false
var _health_ratio := 1.0
var _ship_state: StringName = STATE_POWERED_DOWN
var _stage := DamageStage.HEALTHY
var _elapsed := 0.0
var _last_world_velocity := Vector3.ZERO
var _alarm_active := false
var _alarm_urgency := 0.0
var _engine_failure_active := false
var _engine_power_multiplier := 1.0
var _pending_destruction := false
var _pending_destruction_pose := Transform3D.IDENTITY
var _pending_destruction_pose_valid := false
var _destruction_remaining := 0.0
var _tearing_down := false
const MAX_PENDING_DAMAGE_PRESENTATIONS := 16
var _pending_damage_presentations: Dictionary = {}
var _pending_damage_presentation_order: Array[int] = []
## Bounded localized channel. One rig per damaged component id, all of them
## ship-local children of this node so a moving, detached, or re-entered craft
## carries them rather than stranding them in world space.
const MAX_COMPONENT_EFFECTS := 8
const COMPONENT_STATE_NOMINAL := 0
const COMPONENT_STATE_IMPAIRED := 1
const COMPONENT_STATE_FAILED := 2
const COMPONENT_SPARK_AMOUNT := 28
const COMPONENT_SMOKE_COLOR := Color(0.24, 0.22, 0.21, 0.46)
var _component_effects: Dictionary = {}

var _damage_sparks: CPUParticles3D
var _engine_failure_sparks: CPUParticles3D
var _engine_smoke: CPUParticles3D
var _warning_light: OmniLight3D
var _engine_failure_light: OmniLight3D
var _destruction_root: Node3D
var _destruction_flash: OmniLight3D
var _explosion_core: MeshInstance3D
var _shockwave: MeshInstance3D
var _transient_effects: Array[Dictionary] = []
var _materials: Dictionary = {}


func _enter_tree() -> void:
	_tearing_down = false
	# Localized component rigs are ship-local children and therefore re-enter with
	# this node. Re-state their emitters so a detached-then-re-added craft resumes
	# exactly the roster it left with, and never a stale one.
	_apply_component_effect_visibility()
	if _built and _pending_destruction:
		call_deferred("_resume_pending_destruction_after_reentry")


func _ready() -> void:
	_ensure_built()
	_apply_stage_visuals()
	if _pending_destruction:
		_pending_destruction = false
		_spawn_destruction_effects(_pending_destruction_pose, _pending_destruction_pose_valid)


func _process(delta: float) -> void:
	_elapsed += delta
	_update_local_cues()
	_update_component_cues()
	_update_transient_effects(delta)
	_update_destruction_effects(delta)


func _exit_tree() -> void:
	_tearing_down = true
	_clear_all_world_effects(false)


## Applies the authoritative ship state to the presentation.
##
## [param health_ratio] is clamped to 0..1. [param ship_state] should normally
## be one of STATE_ACTIVE, STATE_POWERED_DOWN, STATE_HIDDEN or STATE_DESTROYED.
## Unknown non-destroyed values are treated as active, which keeps the component
## forward-compatible with a ship controller's own state labels.
func update_state(
		health_ratio: float,
		ship_state: StringName = STATE_ACTIVE,
		world_velocity: Vector3 = Vector3.ZERO
	) -> void:
	_ensure_built()
	_last_world_velocity = world_velocity if world_velocity.is_finite() else Vector3.ZERO
	if _stage == DamageStage.DESTROYED:
		return
	_health_ratio = clampf(health_ratio, 0.0, 1.0)
	_ship_state = ship_state
	if _health_ratio <= 0.0 or ship_state == STATE_DESTROYED:
		present_destruction(_last_world_velocity)
		return
	_set_stage(_stage_for_ratio(_health_ratio))
	_apply_stage_visuals()


## Convenience wrapper when only health and current velocity changed.
func set_health_ratio(health_ratio: float, world_velocity: Vector3 = Vector3.ZERO) -> void:
	update_state(health_ratio, _ship_state, world_velocity)


## Convenience wrapper when only the owning ship's operating state changed.
func set_ship_state(ship_state: StringName, world_velocity: Vector3 = Vector3.ZERO) -> void:
	update_state(_health_ratio, ship_state, world_velocity)


## Creates a short world-space impact spark at an exact collision location.
func present_impact(
		world_position: Vector3,
		world_normal: Vector3 = Vector3.UP,
		intensity: float = 1.0
	) -> void:
	_ensure_built()
	if not is_inside_tree() or _stage == DamageStage.DESTROYED or _ship_state == STATE_HIDDEN:
		return
	var effect_root := Node3D.new()
	effect_root.name = "HeroDamageImpact"
	_get_world_effect_host().add_child(effect_root)
	effect_root.global_position = world_position if world_position.is_finite() else global_position
	var safe_normal := world_normal.normalized()
	if safe_normal.length_squared() <= 0.001 or not safe_normal.is_finite():
		safe_normal = Vector3.UP
	var sparks := _make_sparks(
		clampi(roundi(16.0 * clampf(intensity, 0.25, 2.5)), 6, 40),
		0.42,
		8.0 * clampf(intensity, 0.35, 2.0),
		true
	)
	sparks.name = "ImpactSparks"
	sparks.direction = safe_normal
	effect_root.add_child(sparks)
	sparks.emitting = true
	_transient_effects.append({
		"node": effect_root,
		"remaining": impact_effect_lifetime,
	})


## Expresses an already-resolved component-integrity roster as localized, ship-local
## damage rigs. The caller (`ShipComponentDamage` via the owning ship) stays the
## only owner of component state; nothing here decides integrity, and no rig
## affects hull, handling, collision, or scoring.
##
## Each entry needs `id` (StringName), `state` (0 nominal / 1 impaired / 2 failed)
## and `local_position` (Vector3, ship-local). Entries that are nominal, malformed,
## or non-finite retire any rig they own instead of creating one. Returns the
## number of live rigs after the update.
func set_component_damage_states(states: Array) -> int:
	_ensure_built()
	# Pass one accepts only well-formed, damaged entries. Retirement is decided
	# against that accepted roster before anything is created, so the bound below
	# always applies to the roster the craft is about to show rather than to a
	# transient union with the previous one.
	var requested: Dictionary = {}
	var order: Array[StringName] = []
	for untyped_state: Variant in states:
		if not untyped_state is Dictionary:
			continue
		var entry := untyped_state as Dictionary
		var component_id := StringName(entry.get("id", &""))
		if component_id.is_empty() or requested.has(component_id):
			continue
		var local_position: Variant = entry.get("local_position", null)
		if not local_position is Vector3 or not (local_position as Vector3).is_finite():
			continue
		var state := int(entry.get("state", COMPONENT_STATE_NOMINAL))
		if state < COMPONENT_STATE_IMPAIRED:
			continue
		requested[component_id] = {
			"state": mini(state, COMPONENT_STATE_FAILED),
			"local_position": local_position as Vector3,
		}
		order.append(component_id)

	var changed := false
	for existing_id: StringName in _component_effects.keys():
		if not requested.has(existing_id):
			changed = _retire_component_effect(existing_id) or changed
	for component_id: StringName in order:
		var record: Dictionary = requested[component_id]
		var state := int(record.state)
		var local_position: Vector3 = record.local_position
		if _component_effects.has(component_id):
			changed = _update_component_effect(component_id, state, local_position) or changed
			continue
		if _component_effects.size() >= MAX_COMPONENT_EFFECTS:
			continue
		_create_component_effect(component_id, state, local_position)
		changed = true
	if changed:
		_apply_component_effect_visibility()
		component_effects_changed.emit(_component_effects.size())
	return _component_effects.size()


## Retires every localized rig. Used by reuse, disposal and owner handoff so a
## recycled craft can never inherit another life's failed sections.
func clear_component_damage_effects() -> void:
	if _component_effects.is_empty():
		return
	for component_id: StringName in _component_effects.keys():
		_retire_component_effect(component_id)
	component_effects_changed.emit(0)


func get_active_component_effect_count() -> int:
	return _component_effects.size()


func get_component_effect_state(component_id: StringName) -> int:
	var effect: Dictionary = _component_effects.get(component_id, {})
	if effect.is_empty():
		return COMPONENT_STATE_NOMINAL
	return int(effect.get("state", COMPONENT_STATE_NOMINAL))


## Live rig ids in a stable lexicographic order. StringName comparison is
## address-ordered in Godot, so the sort is deliberately done on String values to
## give callers and tests a reproducible roster.
func get_component_effect_ids() -> Array[StringName]:
	var names: Array[String] = []
	for component_id: StringName in _component_effects.keys():
		names.append(String(component_id))
	names.sort()
	var ids: Array[StringName] = []
	for component_name: String in names:
		ids.append(StringName(component_name))
	return ids


func _create_component_effect(
		component_id: StringName,
		state: int,
		local_position: Vector3
	) -> void:
	var rig := Node3D.new()
	rig.name = "ComponentDamage_%s" % String(component_id)
	rig.position = local_position
	add_child(rig)
	# Reuse the same emitter builders as the staged hull channel: one spark/smoke
	# grammar for the whole craft, no second particle vocabulary. Only the sizes
	# are raised, because a section rig has to read at dogfight range against an
	# unlit starfield rather than at cockpit distance.
	var sparks := _make_sparks(COMPONENT_SPARK_AMOUNT, 0.72, 3.4, false)
	sparks.name = "ComponentSparks"
	sparks.direction = Vector3(0.0, 0.75, 0.25)
	sparks.spread = 62.0
	# A section vent is a continuous failure, not the staged hull channel's
	# periodic burst, so it emits steadily and reads on every frame.
	sparks.explosiveness = 0.08
	sparks.scale_amount_min = 0.7
	sparks.scale_amount_max = 1.7
	sparks.emitting = false
	rig.add_child(sparks)
	var smoke := _make_smoke(false)
	smoke.name = "ComponentSmoke"
	smoke.amount = 12
	smoke.lifetime = 1.15
	smoke.initial_velocity_min = 0.28
	smoke.initial_velocity_max = 1.05
	smoke.scale_amount_min = 0.35
	smoke.scale_amount_max = 1.15
	smoke.direction = Vector3(0.0, 0.7, 0.35)
	# Venting smoke has to separate from empty space, not from a lit station wall,
	# so the section channel uses its own lifted-value variant of the same material.
	var smoke_mesh := smoke.mesh as QuadMesh
	if smoke_mesh != null:
		smoke_mesh.material = _materials.component_smoke
	smoke.emitting = false
	rig.add_child(smoke)
	# The same practical-light grammar the alarm and engine-failure cues already
	# use, so a failing section is legible without a new visual vocabulary.
	var glow := OmniLight3D.new()
	glow.name = "ComponentGlow"
	glow.light_color = DAMAGE_ORANGE
	glow.light_energy = 0.0
	glow.omni_range = 4.6
	glow.shadow_enabled = false
	rig.add_child(glow)
	_component_effects[component_id] = {
		"root": rig,
		"sparks": sparks,
		"smoke": smoke,
		"glow": glow,
		"state": state,
	}


func _update_component_effect(
		component_id: StringName,
		state: int,
		local_position: Vector3
	) -> bool:
	var effect: Dictionary = _component_effects[component_id]
	var rig := effect.get("root") as Node3D
	if not is_instance_valid(rig):
		_component_effects.erase(component_id)
		_create_component_effect(component_id, state, local_position)
		return true
	var moved := not rig.position.is_equal_approx(local_position)
	rig.position = local_position
	if int(effect.get("state", COMPONENT_STATE_NOMINAL)) == state:
		return moved
	effect["state"] = state
	_component_effects[component_id] = effect
	return true


func _retire_component_effect(component_id: StringName) -> bool:
	var effect: Dictionary = _component_effects.get(component_id, {})
	if effect.is_empty():
		return false
	_component_effects.erase(component_id)
	var rig := effect.get("root") as Node3D
	if is_instance_valid(rig):
		# Synchronous detachment keeps `get_active_component_effect_count()` and the
		# child roster consistent for reset callers and tests in the same frame.
		if not _tearing_down and rig.get_parent() != null:
			rig.get_parent().remove_child(rig)
		rig.queue_free()
	return true


## Localized rigs follow the same suppression rule as the staged hull channel: a
## hidden or destroyed craft emits nothing, and no rig ever survives destruction.
func _apply_component_effect_visibility() -> void:
	if _component_effects.is_empty():
		return
	var allowed := _ship_state != STATE_HIDDEN and _stage != DamageStage.DESTROYED
	for component_id: StringName in _component_effects.keys():
		var effect: Dictionary = _component_effects[component_id]
		var sparks := effect.get("sparks") as CPUParticles3D
		var smoke := effect.get("smoke") as CPUParticles3D
		var glow := effect.get("glow") as OmniLight3D
		var state := int(effect.get("state", COMPONENT_STATE_NOMINAL))
		if is_instance_valid(sparks):
			sparks.emitting = allowed and state >= COMPONENT_STATE_IMPAIRED
		if is_instance_valid(smoke):
			smoke.emitting = allowed and state >= COMPONENT_STATE_FAILED
		if is_instance_valid(glow):
			glow.light_color = (
				DAMAGE_RED if state >= COMPONENT_STATE_FAILED else DAMAGE_AMBER
			)
			if not allowed or state < COMPONENT_STATE_IMPAIRED:
				glow.light_energy = 0.0


## Section glows flicker on the presentation's own accumulated simulation time,
## offset per section so several failures never pulse in lockstep. No wall clock
## is read here; `_elapsed` is advanced by the frame delta like every other cue.
func _update_component_cues() -> void:
	if _component_effects.is_empty():
		return
	var index := 0
	for component_id: StringName in _component_effects.keys():
		var effect: Dictionary = _component_effects[component_id]
		var glow := effect.get("glow") as OmniLight3D
		index += 1
		if not is_instance_valid(glow):
			continue
		var state := int(effect.get("state", COMPONENT_STATE_NOMINAL))
		if (
			state < COMPONENT_STATE_IMPAIRED
			or _ship_state == STATE_HIDDEN
			or _stage == DamageStage.DESTROYED
		):
			glow.light_energy = 0.0
			continue
		var phase := _elapsed * (17.0 if state >= COMPONENT_STATE_FAILED else 9.0)
		phase += float(index) * 1.37
		var flicker := clampf(0.5 + 0.5 * sin(phase) + 0.18 * sin(phase * 2.7), 0.08, 1.0)
		var peak := 4.6 if state >= COMPONENT_STATE_FAILED else 2.4
		glow.light_energy = peak * flicker


## Queues only transient/terminal art. Health stage, alarm and engine-power state
## remain immediate through [method update_state], preserving gameplay authority.
func defer_damage_presentation(
		receipt_id: int,
		world_position: Vector3,
		world_normal: Vector3,
		intensity: float,
		terminal: bool,
		world_velocity: Vector3,
		world_pose: Variant = null
	) -> bool:
	if receipt_id < 0 or not world_position.is_finite():
		return false
	if _pending_damage_presentations.has(receipt_id):
		_pending_damage_presentation_order.erase(receipt_id)
	_pending_damage_presentations[receipt_id] = {
		"position": world_position,
		"normal": world_normal,
		"intensity": clampf(intensity, 0.25, 2.5),
		"terminal": terminal,
		"velocity": world_velocity if world_velocity.is_finite() else Vector3.ZERO,
		"world_pose": world_pose if world_pose is Transform3D else global_transform,
	}
	_pending_damage_presentation_order.append(receipt_id)
	while _pending_damage_presentation_order.size() > MAX_PENDING_DAMAGE_PRESENTATIONS:
		var evicted: int = _pending_damage_presentation_order.pop_front()
		_pending_damage_presentations.erase(evicted)
	return true


func commit_deferred_damage_presentation(receipt_id: int) -> bool:
	if not _pending_damage_presentations.has(receipt_id):
		return false
	var record := _pending_damage_presentations[receipt_id] as Dictionary
	_pending_damage_presentations.erase(receipt_id)
	_pending_damage_presentation_order.erase(receipt_id)
	present_impact(record.position, record.normal, float(record.intensity))
	if bool(record.terminal):
		present_destruction(record.velocity, record.world_pose)
		_pending_damage_presentations.clear()
		_pending_damage_presentation_order.clear()
	return true


func get_pending_damage_presentation_count() -> int:
	return _pending_damage_presentations.size()


## Clears every pending deferred receipt record without affecting active world effects.
##
## Deferred visual queues are replayed through receipt identities. This is intended
## for owner re-entry and ownership handoff where stale queued sequences must
## never commit after teardown.
func discard_deferred_damage_presentations() -> void:
	_pending_damage_presentations.clear()
	_pending_damage_presentation_order.clear()


## Enters the terminal stage once and detaches the lethal effects into world
## space. The owner can hide or recycle its hull without moving the explosion.
func present_destruction(
		world_velocity: Vector3 = Vector3.ZERO,
		world_pose: Variant = null
	) -> void:
	_ensure_built()
	if _stage == DamageStage.DESTROYED:
		return
	_last_world_velocity = world_velocity if world_velocity.is_finite() else Vector3.ZERO
	_health_ratio = 0.0
	_ship_state = STATE_DESTROYED
	_set_stage(DamageStage.DESTROYED)
	_apply_stage_visuals()
	_pending_destruction_pose = world_pose as Transform3D if world_pose is Transform3D else global_transform
	_pending_destruction_pose.basis = _pending_destruction_pose.basis.orthonormalized()
	_pending_destruction_pose_valid = true
	if is_inside_tree():
		_spawn_destruction_effects(_pending_destruction_pose, true)
	else:
		_pending_destruction = true


## Clears every local/world effect and explicitly prepares this instance for a
## recycled or respawned ship. Destruction cannot be reversed through
## [method update_state]; this explicit reset is required.
func reset_for_reuse(
		health_ratio: float = 1.0,
		ship_state: StringName = STATE_POWERED_DOWN
	) -> void:
	_ensure_built()
	_clear_all_world_effects(false)
	clear_component_damage_effects()
	_pending_damage_presentations.clear()
	_pending_damage_presentation_order.clear()
	_pending_destruction = false
	_pending_destruction_pose_valid = false
	_elapsed = 0.0
	_last_world_velocity = Vector3.ZERO
	_health_ratio = clampf(health_ratio, 0.001, 1.0)
	_ship_state = STATE_POWERED_DOWN if ship_state == STATE_DESTROYED else ship_state
	_stage = _stage_for_ratio(_health_ratio)
	_restart_particles_cleared(_damage_sparks)
	_restart_particles_cleared(_engine_failure_sparks)
	_restart_particles_cleared(_engine_smoke)
	_apply_stage_visuals()
	stage_changed.emit(_stage, _health_ratio)
	status_changed.emit(get_status(), _health_ratio)
	effects_cleared.emit()


## Immediately removes all detached effects and suppresses local emitters.
## This is safe to call before freeing the component or its owning ship.
func dispose_effects() -> void:
	_clear_all_world_effects(false)
	clear_component_damage_effects()
	_pending_damage_presentations.clear()
	_pending_damage_presentation_order.clear()
	_pending_destruction = false
	_pending_destruction_pose_valid = false
	_ship_state = STATE_HIDDEN
	_apply_stage_visuals()
	effects_cleared.emit()


func get_damage_stage() -> int:
	return _stage


func get_health_ratio() -> float:
	return _health_ratio


func get_ship_state() -> StringName:
	return _ship_state


func get_status() -> StringName:
	match _stage:
		DamageStage.DAMAGED:
			return STATUS_DAMAGED
		DamageStage.CRITICAL:
			return STATUS_CRITICAL
		DamageStage.DESTROYED:
			return STATUS_DESTROYED
	return STATUS_HEALTHY


func is_alarm_active() -> bool:
	return _alarm_active


func is_engine_failure_active() -> bool:
	return _engine_failure_active


func get_engine_power_multiplier() -> float:
	return _engine_power_multiplier


func get_last_world_velocity() -> Vector3:
	return _last_world_velocity


func get_destruction_effect_root() -> Node3D:
	return _destruction_root if is_instance_valid(_destruction_root) else null


func get_live_world_effect_count() -> int:
	var count := 1 if is_instance_valid(_destruction_root) else 0
	for effect in _transient_effects:
		if is_instance_valid(effect.get("node")):
			count += 1
	return count


func _stage_for_ratio(ratio: float) -> int:
	var safe_damaged := clampf(damaged_threshold, 0.05, 0.95)
	var safe_critical := clampf(critical_threshold, 0.01, safe_damaged)
	if ratio <= safe_critical:
		return DamageStage.CRITICAL
	if ratio <= safe_damaged:
		return DamageStage.DAMAGED
	return DamageStage.HEALTHY


func _set_stage(next_stage: int) -> void:
	if _stage == next_stage:
		return
	_stage = next_stage
	stage_changed.emit(_stage, _health_ratio)
	status_changed.emit(get_status(), _health_ratio)


func _apply_stage_visuals() -> void:
	if not _built:
		return
	var visible_damage := _ship_state != STATE_HIDDEN and _stage != DamageStage.DESTROYED
	_apply_component_effect_visibility()
	_damage_sparks.emitting = visible_damage and _stage >= DamageStage.DAMAGED
	_engine_failure_sparks.emitting = visible_damage and _stage >= DamageStage.CRITICAL
	_engine_smoke.emitting = visible_damage and _stage >= DamageStage.CRITICAL

	var next_alarm_active := (
		_is_powered_active()
		and _stage >= DamageStage.DAMAGED
		and _stage < DamageStage.DESTROYED
	)
	var next_alarm_urgency := 1.0 if _stage == DamageStage.CRITICAL else 0.45
	if not next_alarm_active:
		next_alarm_urgency = 0.0
	if next_alarm_active != _alarm_active or not is_equal_approx(next_alarm_urgency, _alarm_urgency):
		_alarm_active = next_alarm_active
		_alarm_urgency = next_alarm_urgency
		alarm_changed.emit(_alarm_active, _alarm_urgency)

	var next_engine_failure := _is_powered_active() and _stage == DamageStage.CRITICAL
	if next_engine_failure and not _engine_failure_active:
		_engine_failure_active = true
		_engine_power_multiplier = 0.44
		engine_failure_changed.emit(true, _engine_power_multiplier)
	elif not next_engine_failure:
		var restored_multiplier := 0.0 if _stage == DamageStage.DESTROYED else 1.0
		if _engine_failure_active or not is_equal_approx(restored_multiplier, _engine_power_multiplier):
			_engine_failure_active = false
			_engine_power_multiplier = restored_multiplier
			engine_failure_changed.emit(false, _engine_power_multiplier)

	if not _alarm_active:
		_warning_light.light_energy = 0.0
	if not _engine_failure_active:
		_engine_failure_light.light_energy = 0.0
	if not visible_damage:
		_warning_light.light_energy = 0.0
		_engine_failure_light.light_energy = 0.0


func _is_powered_active() -> bool:
	return _ship_state not in [STATE_POWERED_DOWN, STATE_HIDDEN, STATE_DESTROYED]


func _update_local_cues() -> void:
	if not _built:
		return
	if _alarm_active:
		var warning_pulse := 0.5 + 0.5 * sin(_elapsed * (13.0 if _stage == DamageStage.CRITICAL else 7.0))
		_warning_light.light_color = DAMAGE_RED if _stage == DamageStage.CRITICAL else DAMAGE_AMBER
		_warning_light.light_energy = (1.4 + warning_pulse * 3.4) * _alarm_urgency
	else:
		_warning_light.light_energy = 0.0

	if _engine_failure_active:
		var stutter := 0.48 + 0.28 * sin(_elapsed * 29.0) + 0.18 * sin(_elapsed * 61.0 + 0.7)
		stutter = clampf(stutter, 0.12, 0.88)
		_engine_power_multiplier = stutter
		_engine_failure_light.light_energy = 2.8 * stutter
	else:
		_engine_failure_light.light_energy = 0.0


func _spawn_destruction_effects(
		effect_pose: Transform3D = Transform3D.IDENTITY,
		has_effect_pose: bool = false
	) -> void:
	if not is_inside_tree() or is_instance_valid(_destruction_root):
		return
	if not has_effect_pose:
		effect_pose = global_transform
	effect_pose.basis = effect_pose.basis.orthonormalized()
	_destruction_root = Node3D.new()
	_destruction_root.name = "HeroDamageDestructionEffects"
	_get_world_effect_host().add_child(_destruction_root)
	_destruction_root.global_transform = effect_pose

	var burst := _make_sparks(92, 1.25, 16.0, true)
	burst.name = "ExplosionSparks"
	_destruction_root.add_child(burst)
	burst.emitting = true

	var smoke := _make_smoke(true)
	smoke.name = "ExplosionSmoke"
	smoke.amount = 36
	smoke.lifetime = 2.25
	smoke.explosiveness = 0.94
	smoke.initial_velocity_min = 1.4
	smoke.initial_velocity_max = 5.8
	_destruction_root.add_child(smoke)
	smoke.emitting = true

	_destruction_flash = OmniLight3D.new()
	_destruction_flash.name = "ExplosionFlash"
	_destruction_flash.light_color = DAMAGE_ORANGE
	_destruction_flash.light_energy = 13.0
	_destruction_flash.omni_range = 9.0
	_destruction_flash.shadow_enabled = false
	_destruction_root.add_child(_destruction_flash)

	_explosion_core = MeshInstance3D.new()
	_explosion_core.name = "ExplosionCore"
	var core_mesh := SphereMesh.new()
	core_mesh.radius = 0.72
	core_mesh.height = 1.44
	core_mesh.radial_segments = 20
	core_mesh.rings = 10
	core_mesh.material = _materials.explosion
	_explosion_core.mesh = core_mesh
	_destruction_root.add_child(_explosion_core)

	_shockwave = MeshInstance3D.new()
	_shockwave.name = "ExplosionShockwave"
	var shockwave_mesh := TorusMesh.new()
	shockwave_mesh.inner_radius = 0.84
	shockwave_mesh.outer_radius = 1.0
	shockwave_mesh.rings = 28
	shockwave_mesh.ring_segments = 10
	shockwave_mesh.material = _materials.shockwave
	_shockwave.mesh = shockwave_mesh
	_shockwave.rotation_degrees.x = 90.0
	_destruction_root.add_child(_shockwave)

	for index in destruction_debris_count:
		_spawn_debris_piece(index)

	_destruction_remaining = destruction_effect_lifetime
	destruction_started.emit(_destruction_root.global_position, _last_world_velocity)


func _resume_pending_destruction_after_reentry() -> void:
	if not is_inside_tree() or not _pending_destruction:
		return
	_pending_destruction = false
	_spawn_destruction_effects(_pending_destruction_pose, _pending_destruction_pose_valid)


func _spawn_debris_piece(index: int) -> void:
	var debris := RigidBody3D.new()
	debris.name = "HeroHullDebris%02d" % index
	debris.collision_layer = 0
	debris.collision_mask = WORLD_COLLISION_LAYER
	debris.gravity_scale = 0.0
	debris.mass = 0.32 + float(index % 4) * 0.13
	debris.linear_damp = 0.16
	debris.angular_damp = 0.2
	var count := maxi(destruction_debris_count, 1)
	var angle := TAU * float(index) / float(count)
	debris.position = Vector3(
		cos(angle) * (0.55 + float(index % 3) * 0.28),
		sin(angle * 1.7) * 0.58,
		sin(angle) * (0.8 + float(index % 2) * 0.42)
	)

	var mesh_instance := MeshInstance3D.new()
	var debris_mesh := BoxMesh.new()
	debris_mesh.size = Vector3(
		0.18 + float(index % 3) * 0.13,
		0.12 + float(index % 2) * 0.1,
		0.5 + float(index % 4) * 0.19
	)
	debris_mesh.material = _materials.debris_ivory if index % 3 != 0 else _materials.debris_dark
	mesh_instance.mesh = debris_mesh
	debris.add_child(mesh_instance)
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = debris_mesh.size
	collision.shape = shape
	debris.add_child(collision)
	_destruction_root.add_child(debris)

	var outward := Vector3(cos(angle), 0.2 + float(index % 5) * 0.08, sin(angle)).normalized()
	debris.linear_velocity = _last_world_velocity * 0.32 + outward * (6.0 + float(index % 5) * 1.15)
	debris.angular_velocity = Vector3(
		1.3 + float(index) * 0.72,
		2.2 + float(index % 5) * 0.65,
		-1.5 - float(index) * 0.41
	)


func _update_destruction_effects(delta: float) -> void:
	if not is_instance_valid(_destruction_root):
		return
	_destruction_remaining = maxf(0.0, _destruction_remaining - delta)
	var age := destruction_effect_lifetime - _destruction_remaining
	if is_instance_valid(_destruction_flash):
		var flash_ratio := clampf(1.0 - age / 0.72, 0.0, 1.0)
		_destruction_flash.light_energy = 13.0 * flash_ratio * flash_ratio
		_destruction_flash.omni_range = 9.0 + age * 4.0
	if is_instance_valid(_explosion_core):
		var core_ratio := clampf(1.0 - age / 0.82, 0.0, 1.0)
		_explosion_core.scale = Vector3.ONE * (0.8 + age * 5.2)
		_explosion_core.visible = core_ratio > 0.0
	if is_instance_valid(_shockwave):
		_shockwave.scale = Vector3.ONE * (0.7 + age * 7.2)
		_shockwave.visible = age <= 1.05
	if _destruction_remaining <= 0.0:
		_clear_destruction_effect()
		effects_cleared.emit()


func _update_transient_effects(delta: float) -> void:
	var index := _transient_effects.size() - 1
	while index >= 0:
		var effect := _transient_effects[index]
		var effect_node: Variant = effect.get("node")
		var remaining := float(effect.get("remaining", 0.0)) - delta
		if remaining <= 0.0 or not is_instance_valid(effect_node):
			_remove_world_node(effect_node)
			_transient_effects.remove_at(index)
		else:
			effect["remaining"] = remaining
			_transient_effects[index] = effect
		index -= 1


func _clear_all_world_effects(emit_completion: bool) -> void:
	_clear_destruction_effect()
	for effect in _transient_effects:
		_remove_world_node(effect.get("node"))
	_transient_effects.clear()
	if emit_completion:
		effects_cleared.emit()


func _clear_destruction_effect() -> void:
	_destruction_remaining = 0.0
	_remove_world_node(_destruction_root)
	_destruction_root = null
	_destruction_flash = null
	_explosion_core = null
	_shockwave = null


func _remove_world_node(node: Variant) -> void:
	if not is_instance_valid(node):
		return
	# Tests and reset callers need synchronous detachment; scene teardown instead
	# uses queue_free only because the current-scene parent is already busy
	# removing the hierarchy at that point.
	if not _tearing_down and node.get_parent() != null:
		node.get_parent().remove_child(node)
	node.queue_free()


func _get_world_effect_host() -> Node:
	var current_scene := get_tree().current_scene
	if is_instance_valid(current_scene) and current_scene != self and not is_ancestor_of(current_scene):
		return current_scene
	return get_tree().root


func _ensure_built() -> void:
	if _built:
		return
	_built = true
	_create_materials()
	_damage_sparks = _make_sparks(18, 0.72, 4.6, false)
	_damage_sparks.name = "DamageSparks"
	_damage_sparks.position = spark_anchor
	_damage_sparks.emitting = false
	add_child(_damage_sparks)

	_engine_failure_sparks = _make_sparks(11, 0.46, 3.6, false)
	_engine_failure_sparks.name = "EngineFailureSparks"
	_engine_failure_sparks.position = smoke_anchor
	_engine_failure_sparks.direction = Vector3(0.0, 0.15, 1.0)
	_engine_failure_sparks.emitting = false
	add_child(_engine_failure_sparks)

	_engine_smoke = _make_smoke(false)
	_engine_smoke.name = "EngineSmoke"
	_engine_smoke.position = smoke_anchor
	_engine_smoke.emitting = false
	add_child(_engine_smoke)

	_warning_light = OmniLight3D.new()
	_warning_light.name = "DamageWarningLight"
	_warning_light.position = warning_anchor
	_warning_light.light_color = DAMAGE_AMBER
	_warning_light.light_energy = 0.0
	_warning_light.omni_range = 4.2
	_warning_light.shadow_enabled = false
	add_child(_warning_light)

	_engine_failure_light = OmniLight3D.new()
	_engine_failure_light.name = "EngineFailureLight"
	_engine_failure_light.position = smoke_anchor
	_engine_failure_light.light_color = ENGINE_CYAN
	_engine_failure_light.light_energy = 0.0
	_engine_failure_light.omni_range = 3.8
	_engine_failure_light.shadow_enabled = false
	add_child(_engine_failure_light)


func _make_sparks(amount: int, lifetime_value: float, speed: float, one_shot_value: bool) -> CPUParticles3D:
	var particles := CPUParticles3D.new()
	particles.amount = amount
	particles.lifetime = lifetime_value
	particles.one_shot = one_shot_value
	particles.explosiveness = 0.94 if one_shot_value else 0.58
	particles.randomness = 0.58
	particles.local_coords = false
	particles.direction = Vector3(0.0, 0.2, 1.0)
	particles.spread = 165.0
	particles.gravity = Vector3.ZERO
	particles.initial_velocity_min = speed * 0.48
	particles.initial_velocity_max = speed
	particles.scale_amount_min = 0.35
	particles.scale_amount_max = 1.0
	particles.visibility_aabb = AABB(Vector3(-12.0, -12.0, -12.0), Vector3.ONE * 24.0)
	var spark_mesh := BoxMesh.new()
	spark_mesh.size = Vector3(0.035, 0.035, 0.38)
	spark_mesh.material = _materials.spark
	particles.mesh = spark_mesh
	return particles


func _make_smoke(one_shot_value: bool) -> CPUParticles3D:
	var particles := CPUParticles3D.new()
	particles.amount = 18
	particles.lifetime = 1.65
	particles.one_shot = one_shot_value
	particles.explosiveness = 0.9 if one_shot_value else 0.15
	particles.randomness = 0.72
	particles.local_coords = false
	particles.direction = Vector3(0.0, 0.28, 1.0)
	particles.spread = 48.0
	particles.gravity = Vector3(0.0, 0.22, 0.0)
	particles.initial_velocity_min = 0.35
	particles.initial_velocity_max = 1.9
	particles.scale_amount_min = 0.35
	particles.scale_amount_max = 1.45
	particles.visibility_aabb = AABB(Vector3(-14.0, -14.0, -14.0), Vector3.ONE * 28.0)
	var smoke_quad := QuadMesh.new()
	smoke_quad.size = Vector2(0.92, 0.92)
	smoke_quad.material = _materials.smoke
	particles.mesh = smoke_quad
	return particles


func _restart_particles_cleared(particles: CPUParticles3D) -> void:
	if particles == null:
		return
	particles.emitting = false
	if particles.is_inside_tree():
		particles.restart(true)
		particles.emitting = false


func _create_materials() -> void:
	_materials.spark = _emissive_material(DAMAGE_ORANGE, 4.6)
	_materials.explosion = _emissive_material(Color("fff0b0"), 6.2)
	_materials.debris_ivory = _solid_material(DEBRIS_IVORY, 0.24, 0.42)
	_materials.debris_dark = _solid_material(DEBRIS_DARK, 0.52, 0.3)

	var smoke := StandardMaterial3D.new()
	smoke.albedo_color = SMOKE_COLOR
	smoke.roughness = 1.0
	smoke.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	smoke.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	smoke.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	_materials.smoke = smoke

	# Section venting reads against empty space rather than a lit station surface,
	# so it uses a lifted, slightly warm variant of the same unshaded billboard.
	var component_smoke := StandardMaterial3D.new()
	component_smoke.albedo_color = COMPONENT_SMOKE_COLOR
	component_smoke.roughness = 1.0
	component_smoke.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	component_smoke.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	component_smoke.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	_materials.component_smoke = component_smoke

	var shockwave := StandardMaterial3D.new()
	shockwave.albedo_color = Color(1.0, 0.32, 0.08, 0.54)
	shockwave.roughness = 0.18
	shockwave.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	shockwave.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	shockwave.emission_enabled = true
	shockwave.emission = DAMAGE_ORANGE
	shockwave.emission_energy_multiplier = 3.5
	shockwave.cull_mode = BaseMaterial3D.CULL_DISABLED
	_materials.shockwave = shockwave


func _emissive_material(color: Color, energy: float) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.metallic = 0.1
	material.roughness = 0.18
	material.emission_enabled = true
	material.emission = color
	material.emission_energy_multiplier = energy
	return material


func _solid_material(color: Color, metallic: float, roughness: float) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.metallic = metallic
	material.roughness = roughness
	return material
