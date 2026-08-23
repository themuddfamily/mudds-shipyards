class_name RangeOpponent
extends CharacterBody3D

const RangeOpponentDamageAdapterType := preload(
	"res://scripts/combat/range_opponent_component_damage_adapter.gd"
)
const RangeOpponentDamageAudioBindingType := preload(
	"res://scripts/audio/range_opponent_component_damage_audio_binding.gd"
)

## Reusable range-defense interceptor for the prototype combat encounter.
##
## The craft is assembled entirely from procedural Godot geometry. Local
## forward is negative Z. It begins hidden and non-colliding, and can therefore
## live in the station scene until the range encounter explicitly activates it.

signal projectile_fired(origin: Vector3, direction: Vector3)
signal health_changed(current: float, maximum: float)
signal destroyed(position: Vector3)

const WORLD_LAYER := PhysicsLayers.WORLD
const SHIP_LAYER := PhysicsLayers.SHIP
const TARGET_LAYER := PhysicsLayers.TARGET

const HULL_IVORY := Color("f0eee2")
const HULL_SHADE := Color("aab7b4")
const FRAME_DARK := Color("10242c")
const FRAME_DEEP := Color("06141b")
const KETH_CYAN := Color("48dbe2")
const SIGNAL_AMBER := Color("f4b94f")
const ENGINE_BLUE := Color("63efff")
const DAMAGE_ORANGE := Color("ff8b3d")
const SMOKE_DARK := Color(0.08, 0.12, 0.14, 0.62)
const DESTRUCTION_EFFECT_LIFETIME := 4.5
const MAX_PENDING_DAMAGE_PRESENTATIONS := 16
const SENSOR_DAMAGE_ANCHOR_NAMES := {
	&"RangeInterceptorVisual": &"AmberCanopy",
	&"StandoffPicketVisual": &"SensorBlister",
	&"ContractCourierVisual": &"DistressBeacon",
	&"WingSkirmisherVisual": &"RoleLamp",
}

## Four exact port/starboard box families in the base defender hull. These are
## childless presentation stock: authority lives on the craft root, its seven
## CollisionShape3D children, the muzzle markers and the state-driven lights.
## Each family retains two nodes/submissions and shares only its immutable mesh.
const SYMMETRIC_HULL_BOX_SPECS := [
	{
		"name": &"ProngInset",
		"size": Vector3(0.52, 0.13, 4.4),
		"material_key": &"cyan",
		"positions": [Vector3(-2.65, 0.38, -1.1), Vector3(2.65, 0.38, -1.1)],
		"rotations": [Vector3.ZERO, Vector3.ZERO],
	},
	{
		"name": &"SweptBrace",
		"size": Vector3(3.3, 0.36, 1.0),
		"material_key": &"frame",
		"positions": [Vector3(-1.55, 0.0, 1.05), Vector3(1.55, 0.0, 1.05)],
		"rotations": [Vector3(0.0, 0.48, 0.0), Vector3(0.0, -0.48, 0.0)],
	},
	{
		"name": &"OuterVane",
		"size": Vector3(0.26, 1.5, 2.5),
		"material_key": &"ivory",
		"positions": [Vector3(-3.65, 0.7, 1.95), Vector3(3.65, 0.7, 1.95)],
		"rotations": [Vector3(0.0, 0.1, 0.17), Vector3(0.0, -0.1, -0.17)],
	},
	{
		"name": &"VaneTip",
		"size": Vector3(0.3, 0.22, 1.15),
		"material_key": &"amber",
		"positions": [Vector3(-3.73, 1.4, 1.7), Vector3(3.73, 1.4, 1.7)],
		"rotations": [Vector3.ZERO, Vector3.ZERO],
	},
]
const SYMMETRIC_HULL_BOX_BASELINE_NODES := 8
const SYMMETRIC_HULL_BOX_BASELINE_SUBMISSIONS := 8
const SYMMETRIC_HULL_BOX_BASELINE_MESH_RESOURCES := 8
const SYMMETRIC_HULL_BOX_EXPECTED_MATERIAL_RESOURCES := 4

## Twin gun-charge spheres are state-driven presentation nodes: their scale and
## visibility animate independently, while firing, collision and damage
## authority remain on the opponent root, muzzle markers and collision shapes.
## Keep both ordinary nodes/submissions and share only their immutable recipe.
const WEAPON_TELEGRAPH_RADIUS := 0.16
const WEAPON_TELEGRAPH_RADIAL_SEGMENTS := 24
const WEAPON_TELEGRAPH_RINGS := 12
const WEAPON_TELEGRAPH_COPY_COUNT := 2
const WEAPON_TELEGRAPH_POSITIONS := [
	Vector3(-2.65, -0.08, -4.98),
	Vector3(2.65, -0.08, -4.98),
]

## The paired gun housings are immutable presentation shells. Weapon authority
## remains on the root and its two muzzle markers; charge animation remains on
## the independent lens nodes. One bounded batch therefore preserves both
## visible copies while removing one renderer node and one surface submission.
const GUN_HOUSING_COPY_COUNT := 2
const GUN_HOUSING_POSITIONS := [
	Vector3(-2.65, -0.08, -4.35),
	Vector3(2.65, -0.08, -4.35),
]
const GUN_HOUSING_NAMES := ["PortGunHousing", "StarboardGunHousing"]

## The mirrored engine-pod shells are immutable presentation stock. Their
## animated plume renderers and practical lights remain independent so staged
## damage and reuse can continue to drive each side without touching the batch.
const RANGE_ENGINE_POD_COPY_COUNT := 2
const RANGE_ENGINE_POD_POSITIONS := [
	Vector3(-2.67, 0.05, 3.1),
	Vector3(2.67, 0.05, 3.1),
]
const RANGE_ENGINE_POD_NAMES := ["PortEnginePod", "StarboardEnginePod"]

@export_category("Defense craft")
@export_range(1.0, 1000.0, 1.0) var maximum_health := 85.0
@export_range(10.0, 160.0, 1.0) var cruise_speed := 38.0
@export_range(10.0, 200.0, 1.0) var chase_speed := 58.0
@export_range(1.0, 100.0, 1.0) var acceleration := 29.0
@export_range(10.0, 240.0, 1.0) var turn_speed_degrees := 94.0

@export_category("Tactics")
@export_range(10.0, 200.0, 1.0) var preferred_range := 52.0
@export_range(5.0, 100.0, 1.0) var retreat_range := 24.0
@export_range(20.0, 400.0, 1.0) var engagement_range := 170.0
@export_range(0.1, 3.0, 0.05) var telegraph_time := 0.62
@export_range(0.2, 8.0, 0.05) var weapon_cooldown := 1.55
@export_range(20.0, 400.0, 1.0) var projectile_speed := 135.0

## Instance-owned, so the meshes are freed with the craft and never outlive it.
var _chamfered_cylinder_cache: Dictionary = {}
var _active := false
var _built := false
var _hull_damage: RangeOpponentComponentDamageAdapter
var _damage_audio_binding: RefCounted
var _elapsed := 0.0
var _cooldown_remaining := 0.0
var _telegraph_remaining := 0.0
var _orbit_sign := 1.0
var _target: Node3D
var _alternate_muzzle := false
var _destruction_time := 0.0
var _last_motion_direction := Vector3.FORWARD
var _bank_angle := 0.0
var _pending_spawn_transform := Transform3D.IDENTITY
var _apply_spawn_on_ready := false
var _target_aim_shape: CollisionShape3D

var _visual_root: Node3D
var _muzzle_port: Marker3D
var _muzzle_starboard: Marker3D
var _warning_light: OmniLight3D
var _warning_lenses: Array[MeshInstance3D] = []
var _weapon_telegraph_mesh: SphereMesh
var _engine_glows: Array[MeshInstance3D] = []
var _engine_lights: Array[OmniLight3D] = []
var _materials: Dictionary = {}
var _spark_particle_mesh: BoxMesh
var _smoke_particle_mesh: QuadMesh
var _damage_sparks: CPUParticles3D
var _damage_smoke: CPUParticles3D
var _weapon_damage_sparks: CPUParticles3D
var _sensor_damage_light: OmniLight3D
var _presented_sensor_damage_stage: StringName = &"nominal"
var _destruction_root: Node3D
var _destruction_light: OmniLight3D
var _debris: Dictionary = {}
var _transient_effects: Dictionary = {}
var _destruction_generation := 0
var _tearing_down := false
var _pending_damage_presentations: Dictionary = {}
var _pending_damage_presentation_order: Array[int] = []
var _pending_terminal_presentation_sequence := -1


func _enter_tree() -> void:
	_tearing_down = false


func _ready() -> void:
	_ensure_hull_damage_adapter()
	_bind_damage_audio()
	_build_interceptor()
	_ensure_weapon_component_damage_presentation()
	_ensure_sensor_component_damage_presentation()
	if _active:
		if _apply_spawn_on_ready:
			global_transform = _pending_spawn_transform
			global_basis = global_basis.orthonormalized()
			_apply_spawn_on_ready = false
	else:
		deactivate()


func _exit_tree() -> void:
	_tearing_down = true
	_unbind_damage_audio()
	_clear_destruction_effects()


func _physics_process(delta: float) -> void:
	if not _active:
		return
	var modifiers := get_operational_modifiers()
	var mobility := clampf(float(modifiers.get("mobility_multiplier", 0.0)), 0.0, 1.0)
	_elapsed += delta
	_cooldown_remaining = maxf(0.0, _cooldown_remaining - delta)
	var aware_target := _has_target_awareness(modifiers)
	if not aware_target:
		_telegraph_remaining = 0.0
		velocity = velocity.move_toward(Vector3.ZERO, acceleration * mobility * 0.45 * delta)
		move_and_slide()
		return

	var target_position := _get_target_aim_position()
	var offset := target_position - global_position
	var distance := offset.length()
	if distance <= 0.001:
		return
	var target_direction := offset / distance
	var desired_direction := _choose_motion_direction(target_direction, distance)
	desired_direction = _avoid_world_geometry(desired_direction)
	_last_motion_direction = desired_direction
	var desired_speed := chase_speed if distance > preferred_range * 1.65 else cruise_speed
	desired_speed *= mobility
	velocity = velocity.move_toward(
		desired_direction * desired_speed,
		acceleration * mobility * delta
	)
	_update_attitude(target_direction, delta)
	move_and_slide()
	_resolve_slide_collisions()
	_update_weapon(target_position, target_direction, distance, delta)


func _process(delta: float) -> void:
	_update_presentation(delta)
	if _destruction_time > 0.0:
		_destruction_time = maxf(0.0, _destruction_time - delta)
		if _destruction_light != null:
			var normalized_time := _destruction_time / 0.72
			_destruction_light.light_energy = 10.0 * normalized_time * normalized_time
			_destruction_light.omni_range = 7.0 + 8.0 * (1.0 - normalized_time)
			if _destruction_time <= 0.0:
				_destruction_light.queue_free()
				_destruction_light = null
	if (
		not _active
		and _pending_terminal_presentation_sequence < 0
		and _destruction_time <= 0.0
		and _debris.is_empty()
	):
		visible = false


## Assigns the craft that the range defender should pursue and engage.
func set_target(target: Node3D) -> void:
	_target = target if _is_live_target(target) else null
	_target_aim_shape = null
	if _target == null:
		return
	for candidate in _target.find_children("*", "CollisionShape3D", true, false):
		var collision_shape := candidate as CollisionShape3D
		if collision_shape != null and not collision_shape.disabled and collision_shape.shape != null:
			_target_aim_shape = collision_shape
			break


func _get_target_aim_position() -> Vector3:
	if (
		is_instance_valid(_target_aim_shape)
		and _target_aim_shape.is_inside_tree()
		and not _target_aim_shape.is_queued_for_deletion()
		and not _target_aim_shape.disabled
	):
		return _target_aim_shape.global_position
	return _target.global_position if _has_current_target() else global_position - global_basis.z


func _has_current_target() -> bool:
	return _is_live_target(_target)


## Nominal sensors preserve the established coordinator-owned target assignment.
## Once damaged, awareness becomes a bounded range consequence: the opponent
## retains target identity but cannot pursue or fire until that craft returns to
## its degraded detection envelope. ComponentDamageModel remains data-only.
func _has_target_awareness(modifiers: Dictionary = {}) -> bool:
	if not _has_current_target():
		return false
	var resolved_modifiers := modifiers if not modifiers.is_empty() else get_operational_modifiers()
	var targeting_modifier := clampf(
		float(resolved_modifiers.get("targeting_multiplier", 0.0)),
		0.0,
		1.0
	)
	if targeting_modifier <= 0.0 or bool(resolved_modifiers.get("targeting_disabled", true)):
		return false
	if is_equal_approx(targeting_modifier, 1.0):
		return true
	var awareness_range := engagement_range * lerpf(0.75, 1.75, targeting_modifier)
	return global_position.distance_squared_to(_get_target_aim_position()) <= awareness_range * awareness_range


func _is_live_target(target: Node3D) -> bool:
	return is_instance_valid(target) and target.is_inside_tree() and not target.is_queued_for_deletion()


## Restores the interceptor and places it at a world-space spawn transform.
func activate(spawn_transform: Transform3D) -> Dictionary:
	return activate_with_result(spawn_transform)


## Typed, fail-closed activation seam for lifecycle owners that need acceptance
## evidence. Existing valid callers may continue to ignore the detached result.
func activate_with_result(spawn_transform: Transform3D) -> Dictionary:
	_ensure_hull_damage_adapter()
	if _damage_audio_binding != null:
		_damage_audio_binding.reset_for_reuse()
	var reset_result := _hull_damage.reset_for_reuse(maximum_health)
	if not bool(reset_result.get("accepted", false)):
		return {
			"accepted": false,
			"reason": reset_result.get("reason", &"damage_model_reset_rejected"),
			"damage_model": reset_result.duplicate(true),
		}.duplicate(true)
	_build_interceptor()
	_ensure_weapon_component_damage_presentation()
	_ensure_sensor_component_damage_presentation()
	_clear_destruction_effects()
	var clean_spawn := spawn_transform
	clean_spawn.basis = clean_spawn.basis.orthonormalized()
	if is_inside_tree():
		global_transform = clean_spawn
		_apply_spawn_on_ready = false
	else:
		# Preserve world-space activation semantics if a coordinator prepares the
		# encounter before adding this instance to its transformed parent.
		_pending_spawn_transform = clean_spawn
		_apply_spawn_on_ready = true
	velocity = Vector3.ZERO
	_active = true
	visible = true
	_visual_root.visible = true
	# The interceptor is both a physical ship body and a damageable hitscan target.
	# Keeping both bits makes ship-to-ship collision reciprocal while preserving
	# the dedicated Target query used by the current combat presentation path.
	collision_layer = SHIP_LAYER | TARGET_LAYER
	collision_mask = WORLD_LAYER | SHIP_LAYER
	_elapsed = 0.0
	_cooldown_remaining = 0.85
	_telegraph_remaining = 0.0
	_alternate_muzzle = false
	_orbit_sign = 1.0 if spawn_transform.origin.x >= 0.0 else -1.0
	_bank_angle = 0.0
	_visual_root.rotation = Vector3.ZERO
	_damage_sparks.emitting = false
	_damage_smoke.emitting = false
	_weapon_damage_sparks.emitting = false
	_sensor_damage_light.light_energy = 0.0
	_presented_sensor_damage_stage = &"nominal"
	_restart_particles_cleared(_damage_sparks)
	_restart_particles_cleared(_damage_smoke)
	_restart_particles_cleared(_weapon_damage_sparks)
	_set_damage_stage()
	health_changed.emit(get_health(), get_maximum_health())
	return {
		"accepted": true,
		"reason": &"activated",
		"health": get_health(),
		"maximum_health": get_maximum_health(),
		"damage_model": reset_result.duplicate(true),
	}.duplicate(true)


## Removes the craft from play without producing a destruction effect.
func deactivate() -> void:
	_active = false
	velocity = Vector3.ZERO
	collision_layer = 0
	collision_mask = 0
	_telegraph_remaining = 0.0
	_cooldown_remaining = 0.0
	if _damage_sparks != null:
		_damage_sparks.emitting = false
		_restart_particles_cleared(_damage_sparks)
	if _damage_smoke != null:
		_damage_smoke.emitting = false
		_restart_particles_cleared(_damage_smoke)
	if _weapon_damage_sparks != null:
		_weapon_damage_sparks.emitting = false
		_restart_particles_cleared(_weapon_damage_sparks)
	if _sensor_damage_light != null:
		_sensor_damage_light.light_energy = 0.0
	_presented_sensor_damage_stage = &"nominal"
	if _visual_root != null:
		_visual_root.visible = true
	_clear_destruction_effects()
	visible = false


## Applies hull damage immediately, with optional sequence-keyed presentation delay.
## Authority (health, collision, activity and destruction notification) is never
## deferred. Combat presentation may wait for the matching travelling pulse.
func apply_damage(
	amount: float,
	hit_position: Vector3 = Vector3.ZERO,
	sequence: int = -1,
	defer_visuals: bool = false
	) -> void:
	if not is_inside_tree() or is_queued_for_deletion():
		return
	var before_health := get_health()
	if not _active or before_health <= 0.0:
		return
	var damage_result := _hull_damage.apply_hull_damage(amount, maximum_health)
	if not bool(damage_result.get("accepted", false)):
		return
	var current_health := float(damage_result.get("current_health", before_health))
	var terminal := current_health <= 0.0
	var effect_pose := global_transform
	effect_pose.basis = effect_pose.basis.orthonormalized()
	var presentation := {
		"sequence": sequence,
		"hit_position": hit_position,
		"health": current_health,
		"terminal": terminal,
		"effect_pose": effect_pose,
		"inherited_velocity": velocity,
	}
	if defer_visuals and sequence >= 0:
		_queue_damage_presentation(sequence, presentation)
	else:
		_clear_pending_damage_presentations()
		_present_damage_record(presentation)
	health_changed.emit(current_health, get_maximum_health())
	if terminal:
		_destroy_interceptor(effect_pose.origin)


func get_health() -> float:
	return _hull_damage.get_health() if _hull_damage != null else 0.0

func get_damage_audio_binding() -> RefCounted:
	return _damage_audio_binding

func _bind_damage_audio() -> void:
	_unbind_damage_audio()
	_damage_audio_binding = RangeOpponentDamageAudioBindingType.new()
	_damage_audio_binding.attach(self)

func _unbind_damage_audio() -> void:
	if _damage_audio_binding != null:
		_damage_audio_binding.detach()
	_damage_audio_binding = null


func get_maximum_health() -> float:
	return _hull_damage.get_maximum_health() if _hull_damage != null else maximum_health


func get_component_damage_snapshot() -> Dictionary:
	if _hull_damage == null:
		return {}
	var snapshot := _hull_damage.get_snapshot()
	snapshot["configuration_current"] = _hull_damage.configuration_matches(maximum_health)
	return snapshot.duplicate(true)


## Detached component consequences for this craft's existing movement, weapon,
## and aim authorities to consume. The damage model never performs those acts.
func get_operational_modifiers() -> Dictionary:
	return _hull_damage.get_operational_modifiers() if _hull_damage != null else {}


func is_active() -> bool:
	return _active


## Renderer-independent audit for the base defender's four paired box families.
##
## Structural submissions are mesh-surface counts, not driver draw calls. The
## report proves only a component-local retained-resource reduction and returns
## deep-detached primitive data suitable for a focused regression.
func get_symmetric_hull_box_allocation_audit() -> Dictionary:
	var errors := PackedStringArray()
	var behavior_rows: Array[Dictionary] = []
	var all_mesh_ids: Dictionary = {}
	var all_material_ids: Dictionary = {}
	var node_count := 0
	var structural_submissions := 0
	var authority_node_count := 0
	var scripted_node_count := 0
	var child_node_count := 0
	var metadata_entry_count := 0
	var processing_node_count := 0
	var visual := _visual_root
	if visual == null or not is_instance_valid(visual) or visual.name != &"RangeInterceptorVisual":
		errors.append("range_opponent_visual_root_unavailable")
	else:
		var direct_mesh_nodes: Array[MeshInstance3D] = []
		for raw_node in visual.get_children():
			var direct_mesh := raw_node as MeshInstance3D
			if direct_mesh != null:
				direct_mesh_nodes.append(direct_mesh)
		for spec in SYMMETRIC_HULL_BOX_SPECS:
			var family_name := StringName(spec["name"])
			var expected_size: Vector3 = spec["size"]
			var material_key := StringName(spec["material_key"])
			var expected_material := _materials.get(String(material_key)) as Material
			var expected_positions := spec["positions"] as Array
			var expected_rotations := spec["rotations"] as Array
			var family_mesh_ids: Dictionary = {}
			for side_index in 2:
				var expected_position: Vector3 = expected_positions[side_index]
				var expected_rotation: Vector3 = expected_rotations[side_index]
				var matching_nodes: Array[MeshInstance3D] = []
				for candidate in direct_mesh_nodes:
					if candidate.position.is_equal_approx(expected_position):
						matching_nodes.append(candidate)
				if matching_nodes.size() != 1:
					errors.append(
						"symmetric_hull_box_transform_slot_count_drift:%s:%d"
						% [String(family_name), side_index]
					)
					continue
				var instance := matching_nodes[0]
				node_count += 1
				var mesh := instance.mesh as BoxMesh
				if mesh == null:
					errors.append("symmetric_hull_box_mesh_type_drift:%s" % String(family_name))
				else:
					family_mesh_ids[mesh.get_instance_id()] = true
					all_mesh_ids[mesh.get_instance_id()] = true
					structural_submissions += mesh.get_surface_count()
					if mesh.material != null:
						all_material_ids[mesh.material.get_instance_id()] = true
					if (
						not mesh.size.is_equal_approx(expected_size)
						or mesh.material != expected_material
						or mesh.get_surface_count() != 1
					):
						errors.append(
							"symmetric_hull_box_mesh_recipe_drift:%s" % String(family_name)
						)
				if (
					instance.get_parent() != visual
					or not instance.rotation.is_equal_approx(expected_rotation)
					or not instance.scale.is_equal_approx(Vector3.ONE)
					or not instance.visible
					or instance.layers != 1
					or instance.cast_shadow != GeometryInstance3D.SHADOW_CASTING_SETTING_ON
				):
					errors.append(
						"symmetric_hull_box_node_recipe_drift:%s" % String(family_name)
					)
				if instance.get_script() != null:
					scripted_node_count += 1
				metadata_entry_count += instance.get_meta_list().size()
				if instance.is_processing() or instance.is_physics_processing():
					processing_node_count += 1
				child_node_count += instance.get_child_count()
				for child in instance.find_children("*", "Node", true, false):
					if child.get_script() != null:
						scripted_node_count += 1
					if (
						child is CollisionObject3D
						or child is CollisionShape3D
						or child is NavigationRegion3D
						or child is Light3D
						or child is AudioStreamPlayer
						or child is AudioStreamPlayer3D
						or child is Camera3D
					):
						authority_node_count += 1
				behavior_rows.append({
					"family": String(family_name),
					"side": "port" if side_index == 0 else "starboard",
					"position": [instance.position.x, instance.position.y, instance.position.z],
					"rotation": [instance.rotation.x, instance.rotation.y, instance.rotation.z],
					"scale": [instance.scale.x, instance.scale.y, instance.scale.z],
					"size": [expected_size.x, expected_size.y, expected_size.z],
					"material": String(material_key),
				})
			if family_mesh_ids.size() != 1:
				errors.append(
					"symmetric_hull_box_mesh_identity_not_shared:%s" % String(family_name)
				)

	if node_count != SYMMETRIC_HULL_BOX_BASELINE_NODES:
		errors.append("symmetric_hull_box_total_node_count_drift")
	if all_mesh_ids.size() != SYMMETRIC_HULL_BOX_SPECS.size():
		errors.append("symmetric_hull_box_mesh_identity_count_drift")
	if all_material_ids.size() != SYMMETRIC_HULL_BOX_EXPECTED_MATERIAL_RESOURCES:
		errors.append("symmetric_hull_box_material_identity_count_drift")
	if structural_submissions != SYMMETRIC_HULL_BOX_BASELINE_SUBMISSIONS:
		errors.append("symmetric_hull_box_submission_count_drift")
	if (
		authority_node_count != 0
		or scripted_node_count != 0
		or child_node_count != 0
		or metadata_entry_count != 0
		or processing_node_count != 0
	):
		errors.append("symmetric_hull_box_stock_gained_authority_or_lifecycle")

	var referenced_resource_count := all_mesh_ids.size() + all_material_ids.size()
	var baseline_referenced_resource_count := (
		SYMMETRIC_HULL_BOX_BASELINE_MESH_RESOURCES
		+ SYMMETRIC_HULL_BOX_EXPECTED_MATERIAL_RESOURCES
	)
	return {
		"valid": errors.is_empty(),
		"errors": errors,
		"scope": &"range_opponent_symmetric_childless_hull_boxes",
		"family_count": SYMMETRIC_HULL_BOX_SPECS.size(),
		"node_count": node_count,
		"baseline_node_count": SYMMETRIC_HULL_BOX_BASELINE_NODES,
		"node_delta": node_count - SYMMETRIC_HULL_BOX_BASELINE_NODES,
		"drawn_copy_count": node_count,
		"structural_submission_count": structural_submissions,
		"baseline_structural_submission_count": SYMMETRIC_HULL_BOX_BASELINE_SUBMISSIONS,
		"submission_delta": structural_submissions - SYMMETRIC_HULL_BOX_BASELINE_SUBMISSIONS,
		"mesh_resource_identity_count": all_mesh_ids.size(),
		"baseline_mesh_resource_identity_count": SYMMETRIC_HULL_BOX_BASELINE_MESH_RESOURCES,
		"mesh_resource_identity_delta": all_mesh_ids.size() - SYMMETRIC_HULL_BOX_BASELINE_MESH_RESOURCES,
		"material_resource_identity_count": all_material_ids.size(),
		"baseline_material_resource_identity_count": SYMMETRIC_HULL_BOX_EXPECTED_MATERIAL_RESOURCES,
		"material_resource_identity_delta": all_material_ids.size() - SYMMETRIC_HULL_BOX_EXPECTED_MATERIAL_RESOURCES,
		"referenced_visual_resource_identity_count": referenced_resource_count,
		"baseline_referenced_visual_resource_identity_count": baseline_referenced_resource_count,
		"referenced_visual_resource_identity_delta": referenced_resource_count - baseline_referenced_resource_count,
		"behavior_rows": behavior_rows,
		"authority_node_count": authority_node_count,
		"scripted_node_count": scripted_node_count,
		"child_node_count": child_node_count,
		"metadata_entry_count": metadata_entry_count,
		"processing_node_count": processing_node_count,
		"batched": false,
		"frame_time_claimed": false,
		"gpu_draw_call_claimed": false,
		"vram_claimed": false,
		"whole_scene_budget_claimed": false,
	}.duplicate(true)


## Detached allocation and authority evidence for the two independently
## animated gun-charge spheres. This is deliberately separate from the hull-box
## audit: the nodes are dynamic presentation, but the SphereMesh recipe is not.
func get_weapon_telegraph_mesh_allocation_audit() -> Dictionary:
	var errors := PackedStringArray()
	var paths := PackedStringArray()
	var transforms: Array[Transform3D] = []
	var mesh_ids := {}
	var material_ids := {}
	var submissions := 0
	var authority_nodes := 0
	var collision_shape_nodes := 0
	var visual := _visual_root
	var telegraphs: Array[MeshInstance3D] = []
	if visual == null or not is_instance_valid(visual) or visual.name != &"RangeInterceptorVisual":
		errors.append("weapon_telegraph_visual_root_unavailable")
	else:
		for raw_node in visual.get_children():
			var candidate := raw_node as MeshInstance3D
			var sphere := candidate.mesh as SphereMesh if candidate != null else null
			if sphere != null and is_equal_approx(sphere.radius, WEAPON_TELEGRAPH_RADIUS):
				telegraphs.append(candidate)

	for index in telegraphs.size():
		var telegraph := telegraphs[index]
		var sphere := telegraph.mesh as SphereMesh
		var path := str(visual.get_path_to(telegraph))
		paths.append(path)
		transforms.append(telegraph.transform)
		mesh_ids[sphere.get_instance_id()] = true
		submissions += sphere.get_surface_count()
		if sphere.material != null:
			material_ids[sphere.material.get_instance_id()] = true
		if index >= WEAPON_TELEGRAPH_POSITIONS.size() \
			or not telegraph.position.is_equal_approx(WEAPON_TELEGRAPH_POSITIONS[index]) \
			or not telegraph.rotation.is_zero_approx() \
			or not is_equal_approx(telegraph.scale.x, telegraph.scale.y) \
			or not is_equal_approx(telegraph.scale.y, telegraph.scale.z) \
			or not telegraph.scale.is_finite():
			errors.append("weapon_telegraph_transform_drift:%s" % path)
		if telegraph.get_parent() != visual \
			or telegraph.layers != 1 \
			or telegraph.cast_shadow != GeometryInstance3D.SHADOW_CASTING_SETTING_ON \
			or telegraph.material_override != null \
			or telegraph.material_overlay != null \
			or not is_zero_approx(telegraph.transparency):
			errors.append("weapon_telegraph_renderer_state_drift:%s" % path)
		var gained_authority := telegraph.get_child_count() != 0 \
			or telegraph.get_script() != null \
			or not telegraph.get_groups().is_empty() \
			or not telegraph.get_meta_list().is_empty() \
			or telegraph.is_processing() \
			or telegraph.is_physics_processing()
		for descendant in telegraph.find_children("*", "Node", true, false):
			if descendant is CollisionShape3D:
				collision_shape_nodes += 1
			if descendant is CollisionObject3D \
				or descendant is CollisionShape3D \
				or descendant is NavigationRegion3D \
				or descendant is Light3D \
				or descendant is Camera3D \
				or descendant is AudioStreamPlayer \
				or descendant is AudioStreamPlayer3D:
				gained_authority = true
		if gained_authority:
			authority_nodes += 1
			errors.append("weapon_telegraph_gained_authority_or_lifecycle:%s" % path)

	if telegraphs.size() != WEAPON_TELEGRAPH_COPY_COUNT \
		or paths.is_empty() \
		or paths[0] != "WeaponTelegraph":
		errors.append("weapon_telegraph_node_path_roster_drift")
	if paths.size() == WEAPON_TELEGRAPH_COPY_COUNT \
		and not paths[1].begins_with("@MeshInstance3D@"):
		errors.append("weapon_telegraph_generated_sibling_path_drift")
	if mesh_ids.size() != 1:
		errors.append("weapon_telegraph_mesh_identity_not_shared")
	if material_ids.size() != 1:
		errors.append("weapon_telegraph_material_identity_count_drift")
	var mesh := _weapon_telegraph_mesh
	if mesh == null \
		or not is_equal_approx(mesh.radius, WEAPON_TELEGRAPH_RADIUS) \
		or not is_equal_approx(mesh.height, WEAPON_TELEGRAPH_RADIUS * 2.0) \
		or mesh.radial_segments != WEAPON_TELEGRAPH_RADIAL_SEGMENTS \
		or mesh.rings != WEAPON_TELEGRAPH_RINGS \
		or mesh.get_surface_count() != 1:
		errors.append("weapon_telegraph_sphere_recipe_drift")
	elif mesh.material != _materials.get("amber_emissive"):
		errors.append("weapon_telegraph_material_identity_drift")
	if mesh != null:
		if mesh.resource_local_to_scene or not mesh.get_meta_list().is_empty():
			errors.append("weapon_telegraph_mesh_mutability_or_metadata_drift")
	for telegraph in telegraphs:
		if telegraph.mesh != mesh:
			errors.append("weapon_telegraph_retained_private_mesh")
			break

	return {
		"valid": errors.is_empty(),
		"errors": errors,
		"scope": &"range_opponent_weapon_telegraph_immutable_sphere",
		"node_paths": paths,
		"current_transforms": transforms.duplicate(),
		"geometry_nodes": telegraphs.size(),
		"geometry_submissions": submissions,
		"visible_geometry_copies": telegraphs.size(),
		"primitive_mesh_allocations": mesh_ids.size(),
		"material_resource_identities": material_ids.size(),
		"resource_allocation_reduction": 1,
		"collision_shape_nodes": collision_shape_nodes,
		"authority_nodes": authority_nodes,
		"batched": false,
		"legacy": {
			"geometry_nodes": WEAPON_TELEGRAPH_COPY_COUNT,
			"geometry_submissions": WEAPON_TELEGRAPH_COPY_COUNT,
			"visible_geometry_copies": WEAPON_TELEGRAPH_COPY_COUNT,
			"primitive_mesh_allocations": WEAPON_TELEGRAPH_COPY_COUNT,
			"material_resource_identities": 1,
		},
	}.duplicate(true)


## Returns the detached, world-owned lethal-effect root while it is alive.
func get_destruction_effect_root() -> Node3D:
	return _destruction_root if is_instance_valid(_destruction_root) else null


func get_pending_damage_presentation_count() -> int:
	return _pending_damage_presentations.size()


## Removes all queued deferred damage receipts for re-entry/teardown safety.
func discard_deferred_damage_presentations() -> void:
	_clear_pending_damage_presentations()


## Commits exactly one delayed hit presentation. Missing, evicted and stale
## sequences are harmless so recycled opponents cannot replay prior-life VFX.
func commit_deferred_damage_presentation(sequence: int) -> bool:
	if is_queued_for_deletion() or not is_inside_tree() or not _pending_damage_presentations.has(sequence):
		return false
	var presentation := _pending_damage_presentations[sequence] as Dictionary
	_pending_damage_presentations.erase(sequence)
	_pending_damage_presentation_order.erase(sequence)
	if bool(presentation.get("terminal", false)):
		_clear_pending_damage_presentations()
	_present_damage_record(presentation)
	return true


func _choose_motion_direction(target_direction: Vector3, distance: float) -> Vector3:
	var orbit_direction := Vector3.UP.cross(target_direction).normalized() * _orbit_sign
	var vertical_weave := Vector3.UP * sin(_elapsed * 0.83 + 0.7) * 0.25
	var radial_weight := clampf((distance - preferred_range) / maxf(preferred_range, 1.0), -1.0, 1.0)
	var desired := orbit_direction * 0.78 + target_direction * radial_weight * 0.95 + vertical_weave
	if distance > preferred_range * 1.75:
		desired = target_direction * 0.9 + orbit_direction * 0.24 + vertical_weave
	elif distance < retreat_range:
		desired = -target_direction * 0.86 + orbit_direction * 0.52 + vertical_weave
	if desired.length_squared() <= 0.001:
		return target_direction
	return desired.normalized()


func _avoid_world_geometry(desired_direction: Vector3) -> Vector3:
	if not is_inside_tree():
		return desired_direction
	var look_ahead := 12.0 + velocity.length() * 0.28
	var origin := global_position
	var query := PhysicsRayQueryParameters3D.create(
		origin,
		origin + desired_direction * look_ahead,
		WORLD_LAYER,
		[get_rid()]
	)
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return desired_direction
	var surface_normal: Vector3 = hit.get("normal", Vector3.UP)
	var tangent := desired_direction.slide(surface_normal).normalized()
	if tangent.length_squared() <= 0.001:
		tangent = surface_normal.cross(Vector3.UP).normalized()
	return (tangent * 0.8 + surface_normal * 0.65).normalized()


func _update_attitude(target_direction: Vector3, delta: float) -> void:
	var aim_direction := target_direction
	if aim_direction.length_squared() <= 0.001:
		aim_direction = _last_motion_direction
	var look_up := Vector3.UP
	if absf(aim_direction.dot(look_up)) > 0.965:
		look_up = Vector3.FORWARD
	var desired_basis := Basis.looking_at(aim_direction, look_up).orthonormalized()
	var lateral_speed := global_basis.x.dot(velocity)
	var bank_target := clampf(lateral_speed / maxf(cruise_speed, 1.0), -0.18, 0.18)
	_bank_angle = lerpf(_bank_angle, bank_target, 1.0 - exp(-5.0 * delta))
	desired_basis = (desired_basis * Basis(Vector3.BACK, _bank_angle)).orthonormalized()
	var modifiers := get_operational_modifiers()
	var mobility := clampf(float(modifiers.get("mobility_multiplier", 0.0)), 0.0, 1.0)
	var blend := 1.0 - exp(-deg_to_rad(turn_speed_degrees) * mobility * delta)
	global_basis = Basis(Quaternion(global_basis.orthonormalized()).slerp(
		Quaternion(desired_basis),
		blend
	)).orthonormalized()


func _resolve_slide_collisions() -> void:
	for index in get_slide_collision_count():
		var collision := get_slide_collision(index)
		velocity = velocity.slide(collision.get_normal()) * 0.88


func _update_weapon(target_position: Vector3, target_direction: Vector3, distance: float, delta: float) -> void:
	var modifiers := get_operational_modifiers()
	var fire_modifier := clampf(float(modifiers.get("fire_multiplier", 0.0)), 0.0, 1.0)
	var targeting_modifier := clampf(
		float(modifiers.get("targeting_multiplier", 0.0)),
		0.0,
		1.0
	)
	if fire_modifier <= 0.0 or bool(modifiers.get("fire_disabled", true)):
		_telegraph_remaining = 0.0
		return
	if _telegraph_remaining > 0.0:
		# Charging is a visible commitment, not a guaranteed hit. A player who
		# breaks line of sight, range, or the defender's firing cone cancels it.
		var still_aimed := (-global_basis.z).dot(target_direction) >= _aim_acceptance_dot(
			0.86,
			targeting_modifier
		)
		if distance > engagement_range or not still_aimed or not _has_line_of_sight(target_position):
			_telegraph_remaining = 0.0
			_cooldown_remaining = maxf(_cooldown_remaining, 0.28)
			return
		_telegraph_remaining = maxf(0.0, _telegraph_remaining - delta)
		if _telegraph_remaining <= 0.0:
			_fire_at_target(_get_target_aim_position())
		return
	if _cooldown_remaining > 0.0 or distance > engagement_range:
		return
	var forward := -global_basis.z
	if forward.dot(target_direction) < _aim_acceptance_dot(0.94, targeting_modifier) \
			or not _has_line_of_sight(target_position):
		return
	_telegraph_remaining = telegraph_time


func _aim_acceptance_dot(nominal_dot: float, targeting_modifier: float) -> float:
	return clampf(
		lerpf(0.995, nominal_dot, clampf(targeting_modifier, 0.0, 1.0)),
		nominal_dot,
		0.995
	)


func _has_line_of_sight(target_position: Vector3) -> bool:
	if not is_inside_tree():
		return true
	var query := PhysicsRayQueryParameters3D.create(
		global_position,
		target_position,
		WORLD_LAYER,
		[get_rid()]
	)
	return get_world_3d().direct_space_state.intersect_ray(query).is_empty()


func _fire_at_target(target_position: Vector3) -> void:
	if not _active or not _has_current_target():
		return
	var modifiers := get_operational_modifiers()
	if not _has_target_awareness(modifiers):
		return
	var fire_modifier := clampf(float(modifiers.get("fire_multiplier", 0.0)), 0.0, 1.0)
	if fire_modifier <= 0.0 or bool(modifiers.get("fire_disabled", true)):
		return
	var muzzle := _muzzle_starboard if _alternate_muzzle else _muzzle_port
	_alternate_muzzle = not _alternate_muzzle
	var target_velocity := Vector3.ZERO
	var target_body := _target as CharacterBody3D
	if target_body != null:
		target_velocity = target_body.velocity
	var flight_time := clampf(muzzle.global_position.distance_to(target_position) / projectile_speed, 0.0, 1.15)
	var predicted_position := target_position + target_velocity * flight_time
	var direction := (predicted_position - muzzle.global_position).normalized()
	if direction.length_squared() <= 0.001:
		direction = -global_basis.z
	projectile_fired.emit(muzzle.global_position, direction)
	_spawn_muzzle_flash(muzzle.global_position)
	_cooldown_remaining = weapon_cooldown / fire_modifier


func _set_damage_stage() -> void:
	_set_damage_stage_for_health(get_health(), _active)


func _set_damage_stage_for_health(presented_health: float, presentation_active: bool) -> void:
	if _damage_sparks == null or _damage_smoke == null:
		return
	var ratio := presented_health / maxf(get_maximum_health(), 0.001)
	_damage_sparks.emitting = presentation_active and ratio <= 0.67
	_damage_smoke.emitting = presentation_active and ratio <= 0.34
	_set_weapon_component_damage_presentation(presentation_active)
	_set_sensor_component_damage_presentation(presentation_active)


func _update_presentation(delta: float) -> void:
	if not _built:
		return
	_sync_weapon_damage_anchor()
	_sync_sensor_damage_anchor()
	var ratio := clampf(get_health() / maxf(get_maximum_health(), 0.001), 0.0, 1.0)
	var engine_strength := 0.0
	if _active:
		engine_strength = 0.78 + clampf(velocity.length() / maxf(chase_speed, 1.0), 0.0, 1.0) * 0.4
		if ratio <= 0.34:
			engine_strength *= 0.42 + 0.28 * maxf(0.0, sin(_elapsed * 23.0))
	for index in _engine_glows.size():
		var glow := _engine_glows[index]
		var side_damage := 0.42 if ratio <= 0.34 and index == 0 else 1.0
		# CylinderMesh length is local Y even after the visual node is rotated.
		glow.scale.y = lerpf(glow.scale.y, 0.55 + engine_strength * side_damage, 1.0 - exp(-9.0 * delta))
		glow.visible = _active
		if index < _engine_lights.size():
			_engine_lights[index].light_energy = engine_strength * side_damage * 1.9

	var charge := 0.0
	if _active and _telegraph_remaining > 0.0:
		charge = 1.0 - _telegraph_remaining / maxf(telegraph_time, 0.001)
		charge = clampf(charge, 0.0, 1.0)
		charge = 0.22 + charge * 1.15 + sin(_elapsed * 34.0) * 0.08
	for lens in _warning_lenses:
		lens.scale = Vector3.ONE * (0.8 + charge * 0.55)
		lens.visible = _active
	if _warning_light != null:
		_warning_light.light_energy = charge * 5.0


func _destroy_interceptor(death_position: Vector3) -> void:
	_active = false
	velocity = Vector3.ZERO
	collision_layer = 0
	collision_mask = 0
	_telegraph_remaining = 0.0
	destroyed.emit(death_position)


func _queue_damage_presentation(sequence: int, presentation: Dictionary) -> void:
	if _pending_damage_presentations.has(sequence):
		_pending_damage_presentation_order.erase(sequence)
	_pending_damage_presentations[sequence] = presentation.duplicate(true)
	_pending_damage_presentation_order.append(sequence)
	if bool(presentation.get("terminal", false)):
		_pending_terminal_presentation_sequence = sequence
	while _pending_damage_presentation_order.size() > MAX_PENDING_DAMAGE_PRESENTATIONS:
		var evicted_sequence: int = _pending_damage_presentation_order.pop_front()
		_pending_damage_presentations.erase(evicted_sequence)
		if evicted_sequence == _pending_terminal_presentation_sequence:
			_pending_terminal_presentation_sequence = -1


func _present_damage_record(presentation: Dictionary) -> void:
	var hit_position: Vector3 = presentation.get("hit_position", Vector3.ZERO)
	_spawn_impact_sparks(hit_position)
	if bool(presentation.get("terminal", false)):
		_damage_sparks.emitting = false
		_damage_smoke.emitting = false
		_weapon_damage_sparks.emitting = false
		_restart_particles_cleared(_weapon_damage_sparks)
		_sensor_damage_light.light_energy = 0.0
		_presented_sensor_damage_stage = &"nominal"
		_visual_root.visible = false
		_pending_terminal_presentation_sequence = -1
		var effect_pose: Transform3D = presentation.get("effect_pose", global_transform)
		var inherited_velocity: Vector3 = presentation.get("inherited_velocity", Vector3.ZERO)
		_spawn_destruction_burst(inherited_velocity, effect_pose)
		return
	# Receipts may arrive out of firing order when shot ranges differ. Persistent
	# damage cues must reflect current authority, never an older receipt that
	# would visually heal a craft after a newer critical hit was presented.
	_set_damage_stage_for_health(get_health(), _active)


func _ensure_hull_damage_adapter() -> void:
	if _hull_damage == null:
		_hull_damage = RangeOpponentDamageAdapterType.new(maximum_health) \
			as RangeOpponentComponentDamageAdapter


## Persistent, component-local damage feedback. Every production derivative
## supplies its actual firing muzzle through `_get_firing_muzzle()`, so the one
## inherited emitter follows a nose cannon, tail turret, repeater, or lance
## without duplicating presentation or damage authority in each archetype.
func _set_weapon_component_damage_presentation(presentation_active: bool) -> void:
	if _weapon_damage_sparks == null:
		return
	var weapon_state := _get_component_damage_state(
		RangeOpponentComponentDamageAdapter.WEAPON_COMPONENT_ID
	)
	var stage := weapon_state.get("stage", {}) as Dictionary
	var stage_id := StringName(stage.get("stage_id", &"nominal"))
	var should_emit := presentation_active and stage_id != &"nominal"
	_sync_weapon_damage_anchor()
	if _weapon_damage_sparks.emitting and not should_emit:
		_restart_particles_cleared(_weapon_damage_sparks)
	else:
		_weapon_damage_sparks.emitting = should_emit


func _ensure_weapon_component_damage_presentation() -> void:
	if _weapon_damage_sparks != null and is_instance_valid(_weapon_damage_sparks):
		return
	_ensure_particle_meshes()
	_weapon_damage_sparks = _make_spark_particles(10, 0.55, 2.8)
	_weapon_damage_sparks.name = "WeaponDamageSparks"
	_weapon_damage_sparks.one_shot = false
	_weapon_damage_sparks.emitting = false
	add_child(_weapon_damage_sparks)
	_sync_weapon_damage_anchor()


## Sensor degradation remains behaviorally owned by the existing targeting
## modifier. This inherited light adds only a local read at each authored
## sensor/mast node, and its presented stage advances with damage receipts.
func _set_sensor_component_damage_presentation(presentation_active: bool) -> void:
	if _sensor_damage_light == null:
		return
	var sensor_state := _get_component_damage_state(
		RangeOpponentComponentDamageAdapter.SENSOR_COMPONENT_ID
	)
	var stage := sensor_state.get("stage", {}) as Dictionary
	_presented_sensor_damage_stage = (
		StringName(stage.get("stage_id", &"nominal"))
		if presentation_active else &"nominal"
	)
	_sync_sensor_damage_anchor()
	var energy := 0.0
	if _presented_sensor_damage_stage == &"damaged":
		energy = 2.4
	elif _presented_sensor_damage_stage == &"critical":
		energy = 4.8
	_sensor_damage_light.light_energy = energy


func _ensure_sensor_component_damage_presentation() -> void:
	if _sensor_damage_light != null and is_instance_valid(_sensor_damage_light):
		return
	_sensor_damage_light = OmniLight3D.new()
	_sensor_damage_light.name = "SensorDamageLight"
	_sensor_damage_light.light_color = DAMAGE_ORANGE
	_sensor_damage_light.light_energy = 0.0
	_sensor_damage_light.omni_range = 5.0
	_sensor_damage_light.shadow_enabled = false
	_sensor_damage_light.set_meta(&"presentation_only", true)
	add_child(_sensor_damage_light)
	_sync_sensor_damage_anchor()


func _sync_sensor_damage_anchor() -> void:
	if _sensor_damage_light == null or not is_instance_valid(_sensor_damage_light):
		return
	var anchor := _get_sensor_component_anchor()
	if anchor != null and is_instance_valid(anchor) and anchor.is_inside_tree():
		_sensor_damage_light.global_position = anchor.global_position


func _get_sensor_component_anchor() -> Node3D:
	if _visual_root == null or not is_instance_valid(_visual_root):
		return self
	var anchor_name := StringName(
		SENSOR_DAMAGE_ANCHOR_NAMES.get(StringName(_visual_root.name), &"")
	)
	if not anchor_name.is_empty():
		var anchor := _visual_root.find_child(String(anchor_name), true, false) as Node3D
		if anchor != null:
			return anchor
	return _visual_root


func _sync_weapon_damage_anchor() -> void:
	if _weapon_damage_sparks == null or not is_instance_valid(_weapon_damage_sparks):
		return
	var muzzle := _get_firing_muzzle()
	if muzzle != null and is_instance_valid(muzzle) and muzzle.is_inside_tree():
		_weapon_damage_sparks.global_position = muzzle.global_position


## Shared presentation anchor. Resolver-backed derivatives may override this
## for non-nose mounts; the base defender follows its alternating live muzzle.
func _get_firing_muzzle() -> Node3D:
	return _muzzle_starboard if _alternate_muzzle else _muzzle_port


func _get_component_damage_state(component_id: StringName) -> Dictionary:
	if _hull_damage == null:
		return {}
	var snapshot := _hull_damage.get_snapshot()
	var model := snapshot.get("model", {}) as Dictionary
	for component_variant in model.get("components", []) as Array:
		if not component_variant is Dictionary:
			continue
		var component := component_variant as Dictionary
		if StringName(component.get("component_id", &"")) == component_id:
			return component.duplicate(true)
	return {}


func _clear_pending_damage_presentations() -> void:
	_pending_damage_presentations.clear()
	_pending_damage_presentation_order.clear()
	_pending_terminal_presentation_sequence = -1


func _spawn_impact_sparks(hit_position: Vector3) -> void:
	if not is_inside_tree():
		return
	var sparks := _make_spark_particles(15, 0.42, 7.5)
	sparks.name = "ImpactSparks"
	_get_world_effect_host().add_child(sparks)
	if hit_position != Vector3.ZERO:
		sparks.global_position = hit_position
	else:
		sparks.global_position = global_position - global_basis.z * 1.5
	sparks.emitting = true
	var effect_id := sparks.get_instance_id()
	_transient_effects[effect_id] = sparks
	get_tree().create_timer(0.9).timeout.connect(_remove_transient_effect.bind(effect_id))


func _spawn_muzzle_flash(world_position: Vector3) -> void:
	if not is_inside_tree():
		return
	var flash := _make_spark_particles(9, 0.16, 3.2)
	flash.name = "DefenseMuzzleFlash"
	_get_world_effect_host().add_child(flash)
	flash.global_position = world_position
	flash.emitting = true
	var effect_id := flash.get_instance_id()
	_transient_effects[effect_id] = flash
	get_tree().create_timer(0.45).timeout.connect(_remove_transient_effect.bind(effect_id))


func _spawn_destruction_burst(
	inherited_velocity: Vector3,
	effect_pose: Transform3D
	) -> void:
	if not is_inside_tree():
		return
	_destruction_generation += 1
	var effect_generation := _destruction_generation
	effect_pose.basis = effect_pose.basis.orthonormalized()
	_destruction_root = Node3D.new()
	_destruction_root.name = "RangeOpponentDestructionEffects"
	_get_world_effect_host().add_child(_destruction_root)
	_destruction_root.global_transform = effect_pose

	var burst := _make_spark_particles(72, 1.15, 14.0)
	burst.name = "InterceptorDestructionBurst"
	_destruction_root.add_child(burst)
	burst.position = Vector3.ZERO
	burst.emitting = true
	get_tree().create_timer(2.2).timeout.connect(burst.queue_free)

	var smoke_burst := _make_smoke_particles(true)
	smoke_burst.name = "DestructionSmoke"
	smoke_burst.amount = 28
	smoke_burst.lifetime = 1.75
	smoke_burst.one_shot = true
	smoke_burst.explosiveness = 0.95
	smoke_burst.initial_velocity_min = 1.5
	smoke_burst.initial_velocity_max = 5.0
	_destruction_root.add_child(smoke_burst)
	smoke_burst.emitting = true
	get_tree().create_timer(3.0).timeout.connect(smoke_burst.queue_free)

	_destruction_light = OmniLight3D.new()
	_destruction_light.name = "DestructionFlash"
	_destruction_light.light_color = SIGNAL_AMBER
	_destruction_light.light_energy = 10.0
	_destruction_light.omni_range = 7.0
	_destruction_light.shadow_enabled = false
	_destruction_root.add_child(_destruction_light)
	_destruction_time = 0.72

	for index in 10:
		var debris := RigidBody3D.new()
		debris.name = "HullDebris%02d" % index
		debris.collision_layer = 0
		debris.collision_mask = WORLD_LAYER
		debris.gravity_scale = 0.0
		debris.mass = 0.35 + float(index % 3) * 0.18
		debris.linear_damp = 0.18
		debris.angular_damp = 0.22
		var angle := TAU * float(index) / 10.0
		var offset := Vector3(cos(angle) * (0.8 + float(index % 2)), sin(angle * 1.7) * 0.65, sin(angle) * 1.8)
		debris.position = offset
		var mesh_instance := MeshInstance3D.new()
		var debris_mesh := BoxMesh.new()
		debris_mesh.size = Vector3(0.28 + float(index % 3) * 0.2, 0.14 + float(index % 2) * 0.16, 0.65 + float(index % 4) * 0.22)
		debris_mesh.material = _materials.ivory if index % 3 != 0 else _materials.cyan
		mesh_instance.mesh = debris_mesh
		debris.add_child(mesh_instance)
		var collision_shape := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = debris_mesh.size
		collision_shape.shape = shape
		debris.add_child(collision_shape)
		_destruction_root.add_child(debris)
		var burst_direction := Vector3(cos(angle), 0.18 + float(index % 4) * 0.12, sin(angle)).normalized()
		debris.linear_velocity = inherited_velocity * 0.28 + burst_direction * (5.5 + float(index % 5))
		debris.angular_velocity = Vector3(1.4 + index, 2.1 + index * 0.4, -1.8 - index * 0.25)
		var debris_id := debris.get_instance_id()
		_debris[debris_id] = debris
		get_tree().create_timer(DESTRUCTION_EFFECT_LIFETIME).timeout.connect(
			_remove_debris.bind(debris_id, effect_generation)
		)
	get_tree().create_timer(DESTRUCTION_EFFECT_LIFETIME).timeout.connect(
		_expire_destruction_effect.bind(effect_generation)
	)


func _remove_debris(debris_id: int, effect_generation: int) -> void:
	if effect_generation != _destruction_generation:
		return
	var debris: Variant = _debris.get(debris_id)
	_debris.erase(debris_id)
	if is_instance_valid(debris):
		debris.queue_free()


func _expire_destruction_effect(effect_generation: int) -> void:
	if effect_generation != _destruction_generation:
		return
	_clear_destruction_root()


func _remove_transient_effect(effect_id: int) -> void:
	var effect: Variant = _transient_effects.get(effect_id)
	_transient_effects.erase(effect_id)
	if is_instance_valid(effect):
		effect.queue_free()


func _restart_particles_cleared(particles: CPUParticles3D) -> void:
	if particles == null or not particles.is_inside_tree():
		return
	particles.restart(true)
	particles.emitting = false


func _clear_destruction_effects() -> void:
	_clear_pending_damage_presentations()
	_clear_destruction_root()
	for effect in _transient_effects.values():
		_remove_world_node(effect)
	_transient_effects.clear()


func _clear_destruction_root() -> void:
	_destruction_generation += 1
	_destruction_time = 0.0
	_remove_world_node(_destruction_root)
	_destruction_root = null
	_destruction_light = null
	_debris.clear()


func _remove_world_node(node: Variant) -> void:
	if not is_instance_valid(node):
		return
	# Explicit deactivate/reactivate calls detach immediately. During tree exit,
	# the world host may itself be busy removing children, so defer only deletion.
	if not _tearing_down and node.get_parent() != null:
		node.get_parent().remove_child(node)
	node.queue_free()


func _get_world_effect_host() -> Node:
	var current_scene := get_tree().current_scene
	if is_instance_valid(current_scene) and current_scene != self and not is_ancestor_of(current_scene):
		return current_scene
	return get_tree().root


func _build_interceptor() -> void:
	if _built:
		return
	_built = true
	motion_mode = CharacterBody3D.MOTION_MODE_FLOATING
	floor_stop_on_slope = false
	_create_materials()
	_visual_root = Node3D.new()
	_visual_root.name = "RangeInterceptorVisual"
	add_child(_visual_root)

	# A narrow forked dart distinguishes this range defender from the hero's
	# broad Torrent arrowhead. Twin forward prongs frame a warm amber cockpit.
	_wedge(_visual_root, "CentralKeel", Vector3(0.0, 0.18, 0.1), Vector3(2.25, 1.15, 7.2), _materials.ivory)
	_wedge(_visual_root, "DarkUnderkeel", Vector3(0.0, -0.45, 0.7), Vector3(1.55, 0.48, 5.8), _materials.deep)
	_wedge(_visual_root, "AmberCanopy", Vector3(0.0, 0.93, -0.35), Vector3(1.46, 0.88, 2.8), _materials.glass)
	_box(_visual_root, "DorsalFrame", Vector3(0.0, 1.16, 1.22), Vector3(0.4, 0.24, 2.5), _materials.frame)
	_box(_visual_root, "AftCrossbar", Vector3(0.0, 0.05, 2.55), Vector3(7.3, 0.5, 1.2), _materials.shade)
	_box(_visual_root, "AftCyanBand", Vector3(0.0, 0.36, 2.4), Vector3(6.5, 0.12, 0.34), _materials.cyan)
	var symmetric_box_meshes: Dictionary = {}
	for spec in SYMMETRIC_HULL_BOX_SPECS:
		var material := _materials.get(String(StringName(spec["material_key"]))) as Material
		var family_name := StringName(spec["name"])
		symmetric_box_meshes[family_name] = _make_box_mesh(spec["size"], material)
	_weapon_telegraph_mesh = SphereMesh.new()
	_weapon_telegraph_mesh.radius = WEAPON_TELEGRAPH_RADIUS
	_weapon_telegraph_mesh.height = WEAPON_TELEGRAPH_RADIUS * 2.0
	_weapon_telegraph_mesh.radial_segments = WEAPON_TELEGRAPH_RADIAL_SEGMENTS
	_weapon_telegraph_mesh.rings = WEAPON_TELEGRAPH_RINGS
	_weapon_telegraph_mesh.material = _materials.amber_emissive
	_add_gun_housing_batch(_visual_root)
	_add_range_engine_pod_batch(_visual_root)

	for side_index in 2:
		var side := -1.0 if side_index == 0 else 1.0
		_wedge(_visual_root, "ForwardProng", Vector3(side * 2.65, -0.02, -0.65), Vector3(1.18, 0.72, 8.35), _materials.ivory, side * 0.025)
		for spec in SYMMETRIC_HULL_BOX_SPECS:
			var family_name := StringName(spec["name"])
			_box_from_mesh(
				_visual_root,
				String(family_name),
				(spec["positions"] as Array)[side_index],
				symmetric_box_meshes[family_name] as BoxMesh,
				(spec["rotations"] as Array)[side_index]
			)
		_cylinder(_visual_root, "ChargeLens", Vector3(side * 2.65, -0.08, -4.88), 0.18, 0.12, _materials.amber_emissive, Vector3(90.0, 0.0, 0.0))
		var lens := _sphere(
			_visual_root,
			"WeaponTelegraph",
			Vector3(side * 2.65, -0.08, -4.98),
			WEAPON_TELEGRAPH_RADIUS,
			_materials.amber_emissive,
			_weapon_telegraph_mesh
		)
		_warning_lenses.append(lens)

		_cylinder(_visual_root, "EngineCollar", Vector3(side * 2.67, 0.05, 3.82), 0.68, 0.26, _materials.shade, Vector3(90.0, 0.0, 0.0))
		_cylinder(_visual_root, "EngineCore", Vector3(side * 2.67, 0.05, 3.99), 0.39, 0.15, _materials.engine, Vector3(90.0, 0.0, 0.0))
		var plume := _cylinder(_visual_root, "EnginePlume", Vector3(side * 2.67, 0.05, 4.42), 0.24, 0.78, _materials.engine, Vector3(90.0, 0.0, 0.0))
		_engine_glows.append(plume)
		var engine_light := OmniLight3D.new()
		engine_light.name = "EngineLight"
		engine_light.position = Vector3(side * 2.67, 0.05, 4.08)
		engine_light.light_color = ENGINE_BLUE
		engine_light.light_energy = 0.0
		engine_light.omni_range = 5.5
		engine_light.shadow_enabled = false
		_visual_root.add_child(engine_light)
		_engine_lights.append(engine_light)

	_muzzle_port = Marker3D.new()
	_muzzle_port.name = "PortMuzzle"
	_muzzle_port.position = Vector3(-2.65, -0.08, -5.03)
	add_child(_muzzle_port)
	_muzzle_starboard = Marker3D.new()
	_muzzle_starboard.name = "StarboardMuzzle"
	_muzzle_starboard.position = Vector3(2.65, -0.08, -5.03)
	add_child(_muzzle_starboard)
	_warning_light = OmniLight3D.new()
	_warning_light.name = "WeaponChargeLight"
	_warning_light.position = Vector3(0.0, -0.08, -4.75)
	_warning_light.light_color = SIGNAL_AMBER
	_warning_light.light_energy = 0.0
	_warning_light.omni_range = 7.0
	_warning_light.shadow_enabled = false
	add_child(_warning_light)

	_build_collision()
	_build_damage_effects()


func _add_gun_housing_batch(parent: Node3D) -> MultiMeshInstance3D:
	var mesh := StationSurfaceKit.chamfered_cylinder_mesh_cached(
		0.31, 0.31, 1.0, 28, _chamfered_cylinder_cache,
		ShipSurfaceDetail.CYLINDER_WALL_RINGS, true, true, _materials.frame
	)
	var rotation_basis := Basis.from_euler(Vector3(deg_to_rad(90.0), 0.0, 0.0))
	var transforms: Array[Transform3D] = []
	var bounds := AABB()
	var multi := MultiMesh.new()
	multi.transform_format = MultiMesh.TRANSFORM_3D
	multi.mesh = mesh
	multi.instance_count = GUN_HOUSING_COPY_COUNT
	multi.visible_instance_count = -1
	for index in GUN_HOUSING_COPY_COUNT:
		var authored_transform := Transform3D(rotation_basis, GUN_HOUSING_POSITIONS[index])
		transforms.append(authored_transform)
		multi.set_instance_transform(index, authored_transform)
		var instance_bounds := (authored_transform * mesh.get_aabb()).abs()
		bounds = instance_bounds if index == 0 else bounds.merge(instance_bounds)
	multi.custom_aabb = bounds
	var batch := MultiMeshInstance3D.new()
	batch.name = "GunHousingBatch"
	batch.multimesh = multi
	batch.layers = 1
	batch.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	batch.set_meta(&"presentation_only", true)
	batch.set_meta(&"authored_visual_names", PackedStringArray(GUN_HOUSING_NAMES))
	batch.set_meta(&"authored_instance_transforms", transforms.duplicate())
	parent.add_child(batch)
	return batch


func _add_range_engine_pod_batch(parent: Node3D) -> MultiMeshInstance3D:
	var mesh := StationSurfaceKit.chamfered_cylinder_mesh_cached(
		0.58, 0.58, 1.45, 28, _chamfered_cylinder_cache,
		ShipSurfaceDetail.CYLINDER_WALL_RINGS, true, true, _materials.frame
	)
	var rotation_basis := Basis.from_euler(Vector3(deg_to_rad(90.0), 0.0, 0.0))
	var transforms: Array[Transform3D] = []
	var bounds := AABB()
	var multi := MultiMesh.new()
	multi.transform_format = MultiMesh.TRANSFORM_3D
	multi.mesh = mesh
	multi.instance_count = RANGE_ENGINE_POD_COPY_COUNT
	multi.visible_instance_count = -1
	for index in RANGE_ENGINE_POD_COPY_COUNT:
		var authored_transform := Transform3D(rotation_basis, RANGE_ENGINE_POD_POSITIONS[index])
		transforms.append(authored_transform)
		multi.set_instance_transform(index, authored_transform)
		var instance_bounds := (authored_transform * mesh.get_aabb()).abs()
		bounds = instance_bounds if index == 0 else bounds.merge(instance_bounds)
	multi.custom_aabb = bounds
	var batch := MultiMeshInstance3D.new()
	batch.name = "RangeEnginePodBatch"
	batch.multimesh = multi
	batch.layers = 1
	batch.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	batch.set_meta(&"presentation_only", true)
	batch.set_meta(&"authored_visual_names", PackedStringArray(RANGE_ENGINE_POD_NAMES))
	batch.set_meta(&"authored_instance_transforms", transforms.duplicate())
	parent.add_child(batch)
	return batch


func _build_collision() -> void:
	var keel_collision := CollisionShape3D.new()
	keel_collision.name = "KeelCollision"
	keel_collision.position = Vector3(0.0, 0.05, 0.2)
	var keel_shape := BoxShape3D.new()
	keel_shape.size = Vector3(2.2, 1.4, 7.2)
	keel_collision.shape = keel_shape
	add_child(keel_collision)
	var cockpit_collision := CollisionShape3D.new()
	cockpit_collision.name = "CockpitCollision"
	cockpit_collision.position = Vector3(0.0, 0.58, -0.35)
	var cockpit_shape := BoxShape3D.new()
	cockpit_shape.size = Vector3(1.7, 1.65, 3.0)
	cockpit_collision.shape = cockpit_shape
	add_child(cockpit_collision)
	var crossbar_collision := CollisionShape3D.new()
	crossbar_collision.name = "AftCrossbarCollision"
	crossbar_collision.position = Vector3(0.0, 0.2, 2.55)
	var crossbar_shape := BoxShape3D.new()
	crossbar_shape.size = Vector3(7.35, 0.85, 1.3)
	crossbar_collision.shape = crossbar_shape
	add_child(crossbar_collision)
	for side in [-1.0, 1.0]:
		var prong_collision := CollisionShape3D.new()
		prong_collision.name = "PortProngCollision" if side < 0.0 else "StarboardProngCollision"
		prong_collision.position = Vector3(side * 2.65, -0.02, -0.55)
		var prong_shape := BoxShape3D.new()
		prong_shape.size = Vector3(1.28, 0.92, 9.25)
		prong_collision.shape = prong_shape
		add_child(prong_collision)
		var vane_collision := CollisionShape3D.new()
		vane_collision.name = "PortVaneCollision" if side < 0.0 else "StarboardVaneCollision"
		vane_collision.position = Vector3(side * 3.65, 0.7, 1.95)
		var vane_shape := BoxShape3D.new()
		vane_shape.size = Vector3(0.42, 1.65, 2.55)
		vane_collision.shape = vane_shape
		add_child(vane_collision)


func _build_damage_effects() -> void:
	_ensure_particle_meshes()
	_damage_sparks = _make_spark_particles(18, 0.7, 4.4)
	_damage_sparks.name = "DamageSparks"
	_damage_sparks.position = Vector3(-1.2, 0.45, 1.8)
	_damage_sparks.one_shot = false
	_damage_sparks.emitting = false
	add_child(_damage_sparks)
	_damage_smoke = _make_smoke_particles(false)
	_damage_smoke.name = "EngineSmoke"
	_damage_smoke.position = Vector3(-2.67, 0.15, 3.55)
	_damage_smoke.emitting = false
	add_child(_damage_smoke)
	_ensure_weapon_component_damage_presentation()


func _make_spark_particles(count: int, lifetime_value: float, speed: float) -> CPUParticles3D:
	var particles := CPUParticles3D.new()
	particles.amount = count
	particles.lifetime = lifetime_value
	particles.one_shot = true
	particles.explosiveness = 0.92
	particles.randomness = 0.52
	particles.local_coords = false
	particles.direction = Vector3(0.0, 0.1, 1.0)
	particles.spread = 180.0
	particles.gravity = Vector3.ZERO
	particles.initial_velocity_min = speed * 0.55
	particles.initial_velocity_max = speed
	particles.scale_amount_min = 0.35
	particles.scale_amount_max = 1.0
	particles.mesh = _spark_particle_mesh
	return particles


func _make_smoke_particles(one_shot_value: bool) -> CPUParticles3D:
	var particles := CPUParticles3D.new()
	particles.amount = 16
	particles.lifetime = 1.45
	particles.one_shot = one_shot_value
	particles.explosiveness = 0.18 if not one_shot_value else 0.88
	particles.randomness = 0.7
	particles.local_coords = false
	particles.direction = Vector3(0.0, 0.3, 1.0)
	particles.spread = 42.0
	particles.gravity = Vector3(0.0, 0.28, 0.0)
	particles.initial_velocity_min = 0.4
	particles.initial_velocity_max = 1.8
	particles.scale_amount_min = 0.35
	particles.scale_amount_max = 1.25
	particles.mesh = _smoke_particle_mesh
	return particles


func _ensure_particle_meshes() -> void:
	if _spark_particle_mesh == null:
		_spark_particle_mesh = BoxMesh.new()
		_spark_particle_mesh.size = Vector3(0.035, 0.035, 0.42)
		_spark_particle_mesh.material = _materials.spark
	if _smoke_particle_mesh == null:
		_smoke_particle_mesh = QuadMesh.new()
		_smoke_particle_mesh.size = Vector2(0.85, 0.85)
		_smoke_particle_mesh.material = _materials.smoke


func _create_materials() -> void:
	_materials.ivory = _material(HULL_IVORY, 0.32, 0.5)
	_materials.shade = _material(HULL_SHADE, 0.42, 0.46)
	_materials.frame = _material(FRAME_DARK, 0.58, 0.35)
	_materials.deep = _material(FRAME_DEEP, 0.62, 0.28)
	_materials.cyan = _material(KETH_CYAN, 0.24, 0.3, KETH_CYAN, 1.15)
	_materials.amber = _material(SIGNAL_AMBER, 0.3, 0.36)
	_materials.amber_emissive = _material(SIGNAL_AMBER, 0.14, 0.24, SIGNAL_AMBER, 2.3)
	_materials.engine = _material(ENGINE_BLUE, 0.08, 0.2, ENGINE_BLUE, 2.8)
	_materials.spark = _material(DAMAGE_ORANGE, 0.08, 0.2, DAMAGE_ORANGE, 4.2)
	var glass := StandardMaterial3D.new()
	glass.albedo_color = Color(0.82, 0.45, 0.12, 0.76)
	glass.metallic = 0.4
	glass.roughness = 0.13
	glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glass.cull_mode = BaseMaterial3D.CULL_DISABLED
	glass.emission_enabled = true
	glass.emission = Color("9b4e18")
	glass.emission_energy_multiplier = 0.85
	_materials.glass = glass
	var smoke := StandardMaterial3D.new()
	smoke.albedo_color = SMOKE_DARK
	smoke.roughness = 1.0
	smoke.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	smoke.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	smoke.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	_materials.smoke = smoke


func _material(color: Color, metallic: float, roughness: float, emission := Color.BLACK, energy := 0.0) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.metallic = metallic
	material.roughness = roughness
	if energy > 0.0:
		material.emission_enabled = true
		material.emission = emission
		material.emission_energy_multiplier = energy
	return material


func _make_box_mesh(size: Vector3, material: Material) -> BoxMesh:
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh.material = material
	return mesh


func _box_from_mesh(
	parent: Node3D,
	node_name: String,
	position_value: Vector3,
	mesh: BoxMesh,
	rotation_value := Vector3.ZERO
) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.name = node_name
	instance.position = position_value
	instance.rotation = rotation_value
	instance.mesh = mesh
	parent.add_child(instance)
	return instance


func _box(parent: Node3D, node_name: String, position_value: Vector3, size: Vector3, material: Material, rotation_value := Vector3.ZERO) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.name = node_name
	instance.position = position_value
	instance.rotation = rotation_value
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh.material = material
	instance.mesh = mesh
	parent.add_child(instance)
	return instance


func _cylinder(parent: Node3D, node_name: String, position_value: Vector3, radius: float, height: float, material: Material, rotation_degrees_value := Vector3.ZERO) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.name = node_name
	instance.position = position_value
	instance.rotation_degrees = rotation_degrees_value
	# Chamfered rims at the opponent's frozen 28 radial segments. Inherited by
	# `StandoffPicketOpponent`. Outer radius and overall height are unchanged and
	# the encounter's collision bodies are authored separately. Wall subdivision:
	# see `ShipSurfaceDetail.CYLINDER_WALL_RINGS`.
	instance.mesh = StationSurfaceKit.chamfered_cylinder_mesh_cached(
		radius, radius, height, 28, _chamfered_cylinder_cache,
		ShipSurfaceDetail.CYLINDER_WALL_RINGS, true, true, material
	)
	parent.add_child(instance)
	return instance


func _sphere(
	parent: Node3D,
	node_name: String,
	position_value: Vector3,
	radius: float,
	material: Material,
	shared_mesh: SphereMesh = null
	) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.name = node_name
	instance.position = position_value
	var mesh := shared_mesh
	if mesh == null:
		mesh = SphereMesh.new()
		mesh.radius = radius
		mesh.height = radius * 2.0
		mesh.radial_segments = 24
		mesh.rings = 12
		mesh.material = material
	instance.mesh = mesh
	parent.add_child(instance)
	return instance


## Creates a crisp, tapered prism with its point toward local negative Z.
func _wedge(parent: Node3D, node_name: String, position_value: Vector3, size: Vector3, material: Material, skew := 0.0) -> MeshInstance3D:
	var half_width := size.x * 0.5
	var half_height := size.y * 0.5
	var half_length := size.z * 0.5
	var nose_x := skew * size.z
	var vertices := PackedVector3Array([
		Vector3(nose_x, -half_height, -half_length),
		Vector3(-half_width, -half_height, half_length),
		Vector3(half_width, -half_height, half_length),
		Vector3(nose_x, half_height, -half_length),
		Vector3(-half_width, half_height, half_length),
		Vector3(half_width, half_height, half_length),
	])
	var indices := PackedInt32Array([
		0, 2, 1,
		3, 4, 5,
		0, 3, 5, 0, 5, 2,
		0, 1, 4, 0, 4, 3,
		1, 2, 5, 1, 5, 4,
	])
	var surface_tool := SurfaceTool.new()
	surface_tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	surface_tool.set_material(material)
	for index in indices:
		surface_tool.add_vertex(vertices[index])
	surface_tool.generate_normals()
	var instance := MeshInstance3D.new()
	instance.name = node_name
	instance.position = position_value
	instance.mesh = surface_tool.commit()
	parent.add_child(instance)
	return instance
