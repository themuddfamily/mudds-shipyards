class_name FlankingSkirmisherOpponent
extends ResolverBackedOpponent

const WeaponDefinitionResolverProfileType := preload(
	"res://scripts/combat/weapon_definition_resolver_profile.gd"
)
const SCATTER_DEFINITION: WeaponDefinition = preload(
	"res://assets/weapons/skirmisher_flank_scatter.tres"
)

## Wing skirmisher — an opponent that is only dangerous as half of a pair.
##
## The defender is a lone dogfighter that leans on cadence. The picket is a lone
## marksman that leans on reach. This craft leans on **the other one of itself**,
## and its whole design is that a single skirmisher is close to harmless.
##
## Two roles, assigned by `WingCoordinator`, never by this craft:
##
##   * **Anchor.** Flies to the point in front of the player's nose and stays
##     there, trading fast weak shots head-on. Its job is not to win; its job is
##     to be the thing worth looking at.
##   * **Flanker.** Refuses the frontal fight outright. It flies to the player's
##     rear hemisphere, and its gun is **hard-safed** anywhere outside a rear
##     arc — not merely inaccurate, but incapable of arming. It cannot be traded
##     with, only turned on.
##
## So the fight is a rotation problem rather than an aim problem. You cannot
## face both. Turning to face the flanker does not solve it either: the
## coordinator sees your nose swing, holds for `role_swap_hold`, and then the
## two craft trade jobs — which means a player who keeps turning keeps both guns
## out of their arcs and takes almost nothing, and a player who fixates on the
## anchor is shot in the back the whole time. The counter to the pair is
## movement; the counter to a single survivor is nothing at all, because a lone
## skirmisher is always the anchor and always in front of you.
##
## The role is on the hull, not only in the coordinator: the dorsal role lamp is
## amber while anchoring and green while flanking, and the flanker's muzzle lens
## goes fully dark whenever its gun is safed. Those are step changes driven by
## state, never by a sampled phase of an oscillator, so a screenshot of one
## frame means the same thing as the frame beside it.
##
## Trade-offs. It owns the highest turn rate, the highest acceleration and the
## fastest weapon cadence in the opponent roster, and pays with the lowest hull,
## the lowest per-shot damage and a very short engagement range. It cannot reach
## anything, cannot survive a sustained pass, and cannot fight alone.
##
## Evidence status: modern_interpretation. No original Keth Shipyards craft,
## weapon, tactic, formation, or class name is authenticated or claimed here.

signal wing_role_changed(role: StringName)
signal weapon_safed_changed(safed: bool)

const SCHEMA_VERSION := 1
const COMPONENT_ID: StringName = &"flanking-skirmisher-opponent"
const EVIDENCE_STATUS: StringName = &"modern_interpretation"
const DISPLAY_NAME := "Mudds wing skirmisher"

const DEFAULT_SOURCE_ID := 2103
const SKIRMISHER_WEAPON_ID: StringName = &"skirmisher_flank_scatter"
## Reuses the defender's amber. The project's pooled pulse grammar is cyan for
## the player fleet, magenta for the picket's heavy charged lance, and amber for
## ordinary opponent guns; a fourth style would have to be cut into the frozen
## fixed pool, and this craft's gun is an ordinary opponent gun.
const SKIRMISHER_PULSE_STYLE: StringName = &"amber"
const SKIRMISHER_PULSE_PROFILE: StringName = PulseWeaponPresentation.PROFILE_REPEATER
const SKIRMISHER_AUDIO_PROFILE: StringName = CombatAudioPresentation.WEAPON_PROFILE_REPEATER

## A compact dark delta. Neither the defender's broad ivory dart nor the
## picket's long graphite spine: this reads small and close-in at a glance.
const HULL_BASALT := Color("2f3a3f")
const HULL_MOSS := Color("55665c")
const HULL_CHALK := Color("9ba79d")
const ROLE_ANCHOR_LAMP := Color("ffb347")
const ROLE_FLANKER_LAMP := Color("58ff9b")
const SKIRMISHER_ENGINE := Color("b6ffe3")
const REPEATER_CHARGE_SCALE := Vector3(0.62, 1.6, 0.62)
## One broad, steady dorsal arrow for the already-committed rear cross. Its
## 4.8 m long axis spans most of the delta silhouette so the destination side
## remains readable at the craft's short combat range without a light or flash.
const REAR_CROSS_CUE_COLOR := Color("baffd0")
const REAR_CROSS_CUE_SIZE := Vector3(1.5, 0.12, 4.8)
const REAR_CROSS_CUE_POSITION := Vector3(0.0, 0.2, -0.95)

# Component-local static presentation budget. The old build retained one
# Mesh per wing, chalk-band and winglet-fin node. Each mirrored pair has one
# exact immutable recipe; the asymmetric wing is authored once on port and the
# starboard node mirrors that same ArrayMesh. Only Mesh Resources are shared:
# nodes, visible copies, materials, transforms, lights, collision, and
# structural submissions remain unchanged.
const WING_SIZE := Vector3(3.0, 0.22, 3.8)
const WING_POSITIONS := [
	Vector3(-2.4, -0.06, 1.0),
	Vector3(2.4, -0.06, 1.0),
]
const WING_SCALES := [
	Vector3.ONE,
	Vector3(-1.0, 1.0, 1.0),
]
const WING_PORT_SKEW := -0.06
const WING_CHALK_BAND_SIZE := Vector3(2.4, 0.05, 0.3)
const WING_CHALK_BAND_POSITIONS := [
	Vector3(-2.5, 0.06, 0.4),
	Vector3(2.5, 0.06, 0.4),
]
const WINGLET_FIN_SIZE := Vector3(0.16, 0.9, 1.3)
const WINGLET_FIN_POSITIONS := [
	Vector3(-3.7, 0.36, 1.9),
	Vector3(3.7, 0.36, 1.9),
]
const WINGLET_FIN_ROTATIONS := [
	Vector3(0.0, -0.16, 0.22),
	Vector3(0.0, 0.16, -0.22),
]
const PRESENTATION_DESCENDANT_NODE_COUNT := 37
const PRESENTATION_VISUAL_NODE_COUNT := 26
const PRESENTATION_MESH_INSTANCE_COUNT := 19
const PRESENTATION_LIGHT_NODE_COUNT := 5
const PRESENTATION_COLLISION_SHAPE_COUNT := 3
const PRESENTATION_PARTICLE_NODE_COUNT := 3
const PRESENTATION_SURFACE_SUBMISSION_COUNT := 21
const PRESENTATION_MATERIAL_RESOURCE_COUNT := 8
const BASELINE_PRESENTATION_MESH_RESOURCE_COUNT := 16
const PRESENTATION_MESH_RESOURCE_COUNT := 14
const BASELINE_PRESENTATION_BOX_MESH_RESOURCE_COUNT := 6
const PRESENTATION_BOX_MESH_RESOURCE_COUNT := 1
const WING_INSTANCE_COUNT := 2
const BASELINE_WING_MESH_RESOURCE_COUNT := 2
const WING_MESH_RESOURCE_COUNT := 1
const WING_CHALK_BAND_INSTANCE_COUNT := 2
const BASELINE_WING_CHALK_BAND_MESH_RESOURCE_COUNT := 2
const WING_CHALK_BAND_MESH_RESOURCE_COUNT := 1
const WINGLET_FIN_INSTANCE_COUNT := 2
const BASELINE_WINGLET_FIN_MESH_RESOURCE_COUNT := 2
const WINGLET_FIN_MESH_RESOURCE_COUNT := 1

const CONTENT_NOTE := (
	"The skirmisher silhouette, palette, role lamp, anchor/flanker split, rear "
	+ "firing arc, and every balance value are an original modern "
	+ "interpretation. They do not reproduce or claim any authenticated "
	+ "historical Keth Shipyards craft, weapon, tactic, formation, or class name."
)

@export_category("Wing tactics")
## Cosine gate on the flanker's rear arc, measured against the player's own
## forward vector. Below this the gun is safed outright.
@export_range(-1.0, 0.5, 0.01) var rear_arc_cosine := -0.15
## How far in front of the player's nose the anchor tries to sit.
@export_range(10.0, 200.0, 1.0) var anchor_station_range := 40.0
## How far behind the player the flanker tries to sit.
@export_range(10.0, 200.0, 1.0) var flank_station_range := 34.0
## Cosine gate on the firing cone, for both roles.
@export_range(0.5, 0.9999, 0.0001) var aim_tolerance := 0.9
## Cooldown forced when a committed charge is broken by arc, cone or occlusion.
@export_range(0.0, 8.0, 0.05) var abort_recovery := 0.35
## How far to the opposite side of the player's wake a flanker cuts after a
## resolved rear shot. This changes only its requested movement direction; the
## inherited physics loop still owns acceleration, speed and collision.
@export_range(8.0, 80.0, 1.0) var rear_cross_lateral_offset := 28.0
## A rear cross expires instead of becoming a permanent alternate station if
## damage or geometry prevents the craft from reaching the opposite shoulder.
@export_range(0.25, 4.0, 0.05) var rear_cross_duration := 1.15

var _wing_role: StringName = WingCoordinator.ROLE_UNASSIGNED
var _weapon_safed := true
var _role_lamp: MeshInstance3D
var _role_light: OmniLight3D
var _muzzle_lens: MeshInstance3D
var _shots_arc_denied := 0
var _wing_mesh: ArrayMesh
var _wing_recipe_vertices := PackedVector3Array()
var _wing_chalk_band_mesh: ArrayMesh
var _winglet_fin_mesh: ArrayMesh
var _rear_cross_state: StringName = &"idle"
var _rear_cross_started_at := 0.0
var _rear_cross_destination_side := 1.0
var _rear_cross_completed_count := 0
var _rear_cross_activation_generation := 0
var _rear_cross_cue: MeshInstance3D
var _rear_cross_cue_mesh: ArrayMesh
var _weapon_definition: WeaponDefinition


# ------------------------------------------------------------- lifecycle ----

func _ready() -> void:
	_weapon_definition = SCATTER_DEFINITION.duplicate(true) as WeaponDefinition
	if _weapon_definition != null:
		weapon_range = _weapon_definition.range_meters
		weapon_damage = (
			_weapon_definition.damage_per_hit
			/ float(WeaponDefinitionResolverProfileType.SCATTER_PELLET_COUNT)
		)
		weapon_cooldown = 1.0 / _weapon_definition.cadence_shots_per_second
	super()
	set_meta("component_id", COMPONENT_ID)
	set_meta("evidence_status", EVIDENCE_STATUS)
	set_meta("historically_supported", false)
	set_meta("modern_interpretation", &"flanking_skirmisher_opponent")
	if source_id <= 0:
		source_id = DEFAULT_SOURCE_ID
	_apply_role_presentation()
	_apply_rear_cross_presentation()


func _exit_tree() -> void:
	# Streaming re-entry restores combat registration in the resolver-backed
	# base. The short tactical pass is deliberately not replayed after absence.
	_reset_rear_cross_tactic()
	super()


func activate(spawn_transform: Transform3D) -> Dictionary:
	var activation := super(spawn_transform) as Dictionary
	if not bool(activation.get("accepted", false)):
		return activation
	_reset_rear_cross_tactic()
	_shots_arc_denied = 0
	_set_weapon_safed(true)
	_apply_role_presentation()
	return activation


func deactivate() -> void:
	super()
	_reset_rear_cross_tactic()
	_assign_wing_role_internal(WingCoordinator.ROLE_UNASSIGNED)
	_set_weapon_safed(true)


func _destroy_interceptor(death_position: Vector3) -> void:
	_reset_rear_cross_tactic()
	_assign_wing_role_internal(WingCoordinator.ROLE_UNASSIGNED)
	_set_weapon_safed(true)
	super(death_position)


# -------------------------------------------------------- public contract ----

func get_display_name() -> String:
	return DISPLAY_NAME


func get_component_id() -> StringName:
	return COMPONENT_ID


func get_weapon_id() -> StringName:
	return SKIRMISHER_WEAPON_ID


func get_pulse_style_id() -> StringName:
	return SKIRMISHER_PULSE_STYLE


func get_pulse_profile_id() -> StringName:
	return SKIRMISHER_PULSE_PROFILE


func get_combat_audio_profile_id() -> StringName:
	return SKIRMISHER_AUDIO_PROFILE


func get_weapon_definition() -> WeaponDefinition:
	return _weapon_definition.duplicate(true) as WeaponDefinition \
		if _weapon_definition != null else null


func get_weapon_profiles() -> Dictionary:
	var definition := get_weapon_definition()
	if definition == null or definition.weapon_id != SKIRMISHER_WEAPON_ID:
		return {}
	return WeaponDefinitionResolverProfileType.to_resolver_profiles(
		definition,
		faction_id,
		weapon_origin_tolerance,
	)


func get_sustained_damage_per_second() -> float:
	var trigger_damage := (
		_weapon_definition.damage_per_hit if _weapon_definition != null else weapon_damage
	)
	var cycle := maxf(0.001, telegraph_time + weapon_cooldown)
	return trigger_damage / cycle


## Called by `WingCoordinator`. The craft stores and presents the role; it never
## chooses it, so two skirmishers can never both believe they are the anchor.
func assign_wing_role(role: StringName) -> void:
	if not _can_assign_wing_role():
		return
	_assign_wing_role_internal(role)


## Preserve the inherited coordinator-owned target assignment and only observe
## its loss so no stale committed intent remains visible between frames.
func set_target(target: Node3D) -> void:
	super(target)
	if not _has_current_target():
		_reset_rear_cross_tactic()


func _can_assign_wing_role() -> bool:
	return is_inside_tree() and not is_queued_for_deletion()


func get_wing_role() -> StringName:
	return _wing_role


func is_anchor() -> bool:
	return _wing_role == WingCoordinator.ROLE_ANCHOR


## True while the gun cannot arm. Always true for a flanker outside its rear
## arc, and the hull says so: the muzzle lens is dark whenever this is true.
func is_weapon_safed() -> bool:
	return _weapon_safed


func get_arc_denied_count() -> int:
	return _shots_arc_denied


## Runtime-readable state for the post-shot flank pass. It is intentionally a
## movement contract only: combat resolution, damage and physics stay on the
## resolver-backed base and the inherited CharacterBody3D loop.
func get_rear_cross_snapshot() -> Dictionary:
	_refresh_rear_cross_state()
	var elapsed := maxf(0.0, _elapsed - _rear_cross_started_at)
	return {
		"tactic_id": &"rear_cross",
		"state_id": _rear_cross_state,
		"destination_side": _rear_cross_destination_side,
		"elapsed_seconds": elapsed if _rear_cross_state == &"active" else 0.0,
		"duration_seconds": rear_cross_duration,
		"remaining_seconds": (
			maxf(0.0, rear_cross_duration - elapsed)
			if _rear_cross_state == &"active" else 0.0
		),
		"lateral_offset": rear_cross_lateral_offset,
		"completed_crosses": _rear_cross_completed_count,
		"uses_existing_movement_authority": true,
		"uses_existing_resolver_authority": true,
		"combat_authority": false,
		"damage_authority": false,
		"physics_authority": false,
	}.duplicate(true)


## A renderer-readable view of the one retained intent vane. The vane only
## observes the authoritative rear-cross state above: it cannot select a side,
## move the craft, retain a target, dispatch a weapon, resolve damage, or grant
## a reward. Its mesh and material are built once with the hull and never
## replaced or mutated as the cue changes sides.
func get_rear_cross_intent_cue_snapshot() -> Dictionary:
	_refresh_rear_cross_state()
	var cue_valid := is_instance_valid(_rear_cross_cue)
	var mesh: ArrayMesh = (
		_rear_cross_cue_mesh
		if cue_valid and _rear_cross_cue.mesh == _rear_cross_cue_mesh else null
	)
	var material := (
		mesh.surface_get_material(0) as StandardMaterial3D
		if mesh != null and mesh.get_surface_count() == 1 else null
	)
	var local_bounds := AABB()
	if cue_valid and mesh != null:
		local_bounds = (_rear_cross_cue.transform * mesh.get_aabb()).abs()
	return {
		"cue_id": &"rear_cross_destination_vane",
		"derived_from_tactic_id": &"rear_cross",
		"state_id": _rear_cross_state,
		"visible": cue_valid and _rear_cross_cue.visible,
		"destination_side": (
			_rear_cross_destination_side if _rear_cross_state == &"active" else 0.0
		),
		"activation_generation": _activation_generation,
		"intent_activation_generation": _rear_cross_activation_generation,
		"renderer_nodes": 1 if cue_valid else 0,
		"mesh_resources": 1 if mesh != null else 0,
		"material_resources": 1 if material != null else 0,
		"mesh_resource_id": mesh.get_instance_id() if mesh != null else 0,
		"material_resource_id": material.get_instance_id() if material != null else 0,
		"local_transform": _rear_cross_cue.transform if cue_valid else Transform3D.IDENTITY,
		"local_bounds": local_bounds,
		"long_axis_meters": REAR_CROSS_CUE_SIZE.z,
		"steady_state_only": true,
		"flashes": false,
		"processes": false,
		"uses_timer": false,
		"presentation_only": true,
		"movement_authority": false,
		"target_authority": false,
		"fire_authority": false,
		"combat_authority": false,
		"damage_authority": false,
		"reward_authority": false,
	}.duplicate(true)


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
			"compact basalt skirmisher delta with a dorsal role lamp",
			"anchor and flanker station keeping around the player's facing",
			"hard-safed rear firing arc for the flanking role",
			"every balance, cadence, range, and damage value",
		]),
		"explicit_unknowns": PackedStringArray([
			"any historical opposing craft, weapon, loadout, tactic, or class name",
		]),
		"content_note": CONTENT_NOTE,
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
		"presentation_resources": get_wing_chalk_band_resource_audit(),
		"weapon_profiles": get_weapon_profiles(),
		"tactics": get_tactics_profile(),
		"authority": {
			"source_id": source_id,
			"faction_id": faction_id,
			"registered": is_combat_source_registered(),
			"weapon_id": SKIRMISHER_WEAPON_ID,
			"pulse_style_id": SKIRMISHER_PULSE_STYLE,
			"pulse_profile_id": SKIRMISHER_PULSE_PROFILE,
			"combat_audio_profile_id": SKIRMISHER_AUDIO_PROFILE,
		},
		"lifecycle": {
			"inside_tree": is_inside_tree(),
			"active": is_active(),
			"wing_role": _wing_role,
			"weapon_safed": _weapon_safed,
			"shots_fired": get_shots_fired(),
			"shots_withheld": get_shots_withheld(),
			"arc_denied": _shots_arc_denied,
			"pending_shot_receipts": get_pending_shot_receipt_count(),
		},
	}.duplicate(true)


## Renderer-independent, component-local allocation evidence for the exact
## mirrored trim families. Structural submissions are mesh-surface counts, not
## driver draw calls; no frame-time, draw-call, or VRAM claim is made.
func get_wing_chalk_band_resource_audit() -> Dictionary:
	var errors := PackedStringArray()
	var mesh_resource_ids := {}
	var box_mesh_resource_ids := {}
	var material_resource_ids := {}
	var band_mesh_resource_ids := {}
	var band_material_resource_ids := {}
	var wing_mesh_resource_ids := {}
	var wing_material_resource_ids := {}
	var fin_mesh_resource_ids := {}
	var fin_material_resource_ids := {}
	var behavior_rows: Array[Dictionary] = []
	var wing_behavior_rows: Array[Dictionary] = []
	var fin_behavior_rows: Array[Dictionary] = []
	var visual_node_count := 0
	var mesh_instance_count := 0
	var surface_submission_count := 0
	var light_node_count := 0
	var collision_shape_count := 0
	var particle_node_count := 0
	var descendant_node_count := 0
	var band_instance_count := 0
	var band_submission_count := 0
	var wing_instance_count := 0
	var wing_submission_count := 0
	var fin_instance_count := 0
	var fin_submission_count := 0
	var authority_node_count := 0
	var scripted_node_count := 0
	var child_node_count := 0
	var metadata_entry_count := 0
	var processing_node_count := 0
	var visual := _visual_root
	var marking_costs := ShipSurfaceDetail.get_surface_marking_costs(visual)
	if visual == null or not is_instance_valid(visual) or visual.name != &"WingSkirmisherVisual":
		errors.append("wing_skirmisher_visual_root_unavailable")
	else:
		visual_node_count = visual.get_child_count()
		for raw_node in visual.get_children():
			if raw_node is Light3D:
				light_node_count += 1
			if raw_node is not MeshInstance3D:
				continue
			var instance := raw_node as MeshInstance3D
			var mesh := instance.mesh
			if mesh == null:
				continue
			mesh_instance_count += 1
			mesh_resource_ids[mesh.get_instance_id()] = true
			if mesh.has_meta(&"stock_size"):
				box_mesh_resource_ids[mesh.get_instance_id()] = true
			for surface_index in mesh.get_surface_count():
				surface_submission_count += 1
				var material := mesh.surface_get_material(surface_index)
				if material != null:
					material_resource_ids[material.get_instance_id()] = true

		for slot_index in WING_CHALK_BAND_POSITIONS.size():
			var expected_position: Vector3 = WING_CHALK_BAND_POSITIONS[slot_index]
			var matching_nodes: Array[MeshInstance3D] = []
			for raw_node in visual.get_children():
				var candidate := raw_node as MeshInstance3D
				if candidate != null and candidate.position.is_equal_approx(expected_position):
					matching_nodes.append(candidate)
			if matching_nodes.size() != 1:
				errors.append("wing_chalk_band_transform_slot_count_drift:%d" % slot_index)
				continue
			var band := matching_nodes[0]
			band_instance_count += 1
			var band_mesh := band.mesh as ArrayMesh
			if band_mesh == null:
				errors.append("wing_chalk_band_mesh_type_drift:%d" % slot_index)
			else:
				band_mesh_resource_ids[band_mesh.get_instance_id()] = true
				band_submission_count += band_mesh.get_surface_count()
				if band_mesh.surface_get_material(0) != null:
					band_material_resource_ids[band_mesh.surface_get_material(0).get_instance_id()] = true
				if (
					not band_mesh.get_aabb().size.is_equal_approx(WING_CHALK_BAND_SIZE)
					or band_mesh.surface_get_material(0) != _materials.skirmisher_chalk
					or band_mesh.get_surface_count() != 1
				):
					errors.append("wing_chalk_band_mesh_recipe_drift:%d" % slot_index)
			if (
				band.get_parent() != visual
				or not band.rotation.is_equal_approx(Vector3.ZERO)
				or not band.scale.is_equal_approx(Vector3.ONE)
				or not band.visible
				or band.layers != 1
				or band.cast_shadow != GeometryInstance3D.SHADOW_CASTING_SETTING_ON
				or band.material_override != null
				or band.material_overlay != null
			):
				errors.append("wing_chalk_band_node_recipe_drift:%d" % slot_index)
			if band.get_script() != null:
				scripted_node_count += 1
			metadata_entry_count += band.get_meta_list().size()
			if band.is_processing() or band.is_physics_processing():
				processing_node_count += 1
			for direct_child in band.get_children():
				if not ShipSurfaceDetail.is_surface_marking_patch(direct_child):
					child_node_count += 1
			for child in band.find_children("*", "Node", true, false):
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
				"side": "port" if slot_index == 0 else "starboard",
				"position": [band.position.x, band.position.y, band.position.z],
				"rotation": [band.rotation.x, band.rotation.y, band.rotation.z],
				"scale": [band.scale.x, band.scale.y, band.scale.z],
				"size": [WING_CHALK_BAND_SIZE.x, WING_CHALK_BAND_SIZE.y, WING_CHALK_BAND_SIZE.z],
				"material": "skirmisher_chalk",
			})

		for slot_index in WING_POSITIONS.size():
			var expected_position: Vector3 = WING_POSITIONS[slot_index]
			var matching_nodes: Array[MeshInstance3D] = []
			for raw_node in visual.get_children():
				var candidate := raw_node as MeshInstance3D
				if candidate != null and candidate.position.is_equal_approx(expected_position):
					matching_nodes.append(candidate)
			if matching_nodes.size() != 1:
				errors.append("wing_transform_slot_count_drift:%d" % slot_index)
				continue
			var wing := matching_nodes[0]
			wing_instance_count += 1
			var wing_array_mesh := wing.mesh as ArrayMesh
			if wing_array_mesh == null:
				errors.append("wing_mesh_type_drift:%d" % slot_index)
			else:
				wing_mesh_resource_ids[wing_array_mesh.get_instance_id()] = true
				wing_submission_count += wing_array_mesh.get_surface_count()
				if wing_array_mesh.get_surface_count() == 1:
					var material := wing_array_mesh.surface_get_material(0)
					if material != null:
						wing_material_resource_ids[material.get_instance_id()] = true
				if not _wing_mesh_matches_recipe(wing_array_mesh):
					errors.append("wing_mesh_recipe_drift:%d" % slot_index)
			if (
				wing.get_parent() != visual
				or not wing.rotation.is_equal_approx(Vector3.ZERO)
				or not wing.scale.is_equal_approx(WING_SCALES[slot_index])
				or not wing.visible
				or wing.layers != 1
				or wing.cast_shadow != GeometryInstance3D.SHADOW_CASTING_SETTING_ON
				or wing.material_override != null
				or wing.material_overlay != null
			):
				errors.append("wing_node_recipe_drift:%d" % slot_index)
			if wing.get_script() != null:
				scripted_node_count += 1
			metadata_entry_count += wing.get_meta_list().size()
			if wing.is_processing() or wing.is_physics_processing():
				processing_node_count += 1
			for direct_child in wing.get_children():
				if not ShipSurfaceDetail.is_surface_marking_patch(direct_child):
					child_node_count += 1
			for child in wing.find_children("*", "Node", true, false):
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
			wing_behavior_rows.append({
				"side": "port" if slot_index == 0 else "starboard",
				"position": [wing.position.x, wing.position.y, wing.position.z],
				"rotation": [wing.rotation.x, wing.rotation.y, wing.rotation.z],
				"scale": [wing.scale.x, wing.scale.y, wing.scale.z],
				"size": [WING_SIZE.x, WING_SIZE.y, WING_SIZE.z],
				"effective_skew": WING_PORT_SKEW if slot_index == 0 else -WING_PORT_SKEW,
				"material": "skirmisher_moss",
			})

		for slot_index in WINGLET_FIN_POSITIONS.size():
			var expected_position: Vector3 = WINGLET_FIN_POSITIONS[slot_index]
			var matching_nodes: Array[MeshInstance3D] = []
			for raw_node in visual.get_children():
				var candidate := raw_node as MeshInstance3D
				if candidate != null and candidate.position.is_equal_approx(expected_position):
					matching_nodes.append(candidate)
			if matching_nodes.size() != 1:
				errors.append("winglet_fin_transform_slot_count_drift:%d" % slot_index)
				continue
			var fin := matching_nodes[0]
			fin_instance_count += 1
			var fin_mesh := fin.mesh as ArrayMesh
			if fin_mesh == null:
				errors.append("winglet_fin_mesh_type_drift:%d" % slot_index)
			else:
				fin_mesh_resource_ids[fin_mesh.get_instance_id()] = true
				fin_submission_count += fin_mesh.get_surface_count()
				if fin_mesh.surface_get_material(0) != null:
					fin_material_resource_ids[fin_mesh.surface_get_material(0).get_instance_id()] = true
				if (
					not fin_mesh.get_aabb().size.is_equal_approx(WINGLET_FIN_SIZE)
					or fin_mesh.surface_get_material(0) != _materials.skirmisher_chalk
					or fin_mesh.get_surface_count() != 1
				):
					errors.append("winglet_fin_mesh_recipe_drift:%d" % slot_index)
			if (
				fin.get_parent() != visual
				or not fin.rotation.is_equal_approx(WINGLET_FIN_ROTATIONS[slot_index])
				or not fin.scale.is_equal_approx(Vector3.ONE)
				or not fin.visible
				or fin.layers != 1
				or fin.cast_shadow != GeometryInstance3D.SHADOW_CASTING_SETTING_ON
				or fin.material_override != null
				or fin.material_overlay != null
			):
				errors.append("winglet_fin_node_recipe_drift:%d" % slot_index)
			if fin.get_script() != null:
				scripted_node_count += 1
			metadata_entry_count += fin.get_meta_list().size()
			if fin.is_processing() or fin.is_physics_processing():
				processing_node_count += 1
			for direct_child in fin.get_children():
				if not ShipSurfaceDetail.is_surface_marking_patch(direct_child):
					child_node_count += 1
			for child in fin.find_children("*", "Node", true, false):
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
			fin_behavior_rows.append({
				"side": "port" if slot_index == 0 else "starboard",
				"position": [fin.position.x, fin.position.y, fin.position.z],
				"rotation": [fin.rotation.x, fin.rotation.y, fin.rotation.z],
				"scale": [fin.scale.x, fin.scale.y, fin.scale.z],
				"size": [WINGLET_FIN_SIZE.x, WINGLET_FIN_SIZE.y, WINGLET_FIN_SIZE.z],
				"material": "skirmisher_chalk",
			})

		var descendants := find_children("*", "Node", true, false)
		descendant_node_count = descendants.size()
		# CombatAuthority attaches this exact lifecycle adapter in production.
		# It owns damage admission, not mirrored-trim presentation geometry.
		var damage_adapter := get_node_or_null("AuthoritativeDamageable") as LifecycleDamageableAdapter
		if damage_adapter != null and damage_adapter.get_parent() == self \
				and damage_adapter.target_entity_path == NodePath("..") \
				and damage_adapter.lifecycle_kind == LifecycleDamageableAdapter.LifecycleKind.RANGE_OPPONENT:
			descendant_node_count -= 1
		for node in descendants:
			if node is CollisionShape3D:
				collision_shape_count += 1
			if node is CPUParticles3D:
				particle_node_count += 1
			if node is Light3D and node.get_parent() != visual:
				# The visual-root lights were already counted above; this adds the
				# direct repeater charge light without depending on render buffers.
				light_node_count += 1

	if band_mesh_resource_ids.size() != WING_CHALK_BAND_MESH_RESOURCE_COUNT:
		errors.append("wing_chalk_band_mesh_identity_not_shared")
	if band_material_resource_ids.size() != 1:
		errors.append("wing_chalk_band_material_identity_count_drift")
	if _wing_chalk_band_mesh == null or not band_mesh_resource_ids.has(_wing_chalk_band_mesh.get_instance_id()):
		errors.append("wing_chalk_band_component_mesh_identity_drift")
	if band_instance_count != WING_CHALK_BAND_INSTANCE_COUNT:
		errors.append("wing_chalk_band_instance_count_drift")
	if band_submission_count != WING_CHALK_BAND_INSTANCE_COUNT:
		errors.append("wing_chalk_band_submission_count_drift")
	if wing_mesh_resource_ids.size() != WING_MESH_RESOURCE_COUNT:
		errors.append("wing_mesh_identity_not_shared")
	if wing_material_resource_ids.size() != 1:
		errors.append("wing_material_identity_count_drift")
	if _wing_mesh == null or not wing_mesh_resource_ids.has(_wing_mesh.get_instance_id()):
		errors.append("wing_component_mesh_identity_drift")
	if wing_instance_count != WING_INSTANCE_COUNT:
		errors.append("wing_instance_count_drift")
	if wing_submission_count != WING_INSTANCE_COUNT:
		errors.append("wing_submission_count_drift")
	if fin_mesh_resource_ids.size() != WINGLET_FIN_MESH_RESOURCE_COUNT:
		errors.append("winglet_fin_mesh_identity_not_shared")
	if fin_material_resource_ids.size() != 1:
		errors.append("winglet_fin_material_identity_count_drift")
	if _winglet_fin_mesh == null or not fin_mesh_resource_ids.has(_winglet_fin_mesh.get_instance_id()):
		errors.append("winglet_fin_component_mesh_identity_drift")
	if fin_instance_count != WINGLET_FIN_INSTANCE_COUNT:
		errors.append("winglet_fin_instance_count_drift")
	if fin_submission_count != WINGLET_FIN_INSTANCE_COUNT:
		errors.append("winglet_fin_submission_count_drift")
	if visual_node_count != PRESENTATION_VISUAL_NODE_COUNT:
		errors.append("wing_skirmisher_visual_node_count_drift")
	if mesh_instance_count != PRESENTATION_MESH_INSTANCE_COUNT:
		errors.append("wing_skirmisher_mesh_instance_count_drift")
	if surface_submission_count != PRESENTATION_SURFACE_SUBMISSION_COUNT:
		errors.append("wing_skirmisher_submission_count_drift")
	if mesh_resource_ids.size() != PRESENTATION_MESH_RESOURCE_COUNT:
		errors.append("wing_skirmisher_mesh_resource_count_drift")
	if box_mesh_resource_ids.size() != PRESENTATION_BOX_MESH_RESOURCE_COUNT:
		errors.append("wing_skirmisher_box_mesh_resource_count_drift")
	if material_resource_ids.size() != PRESENTATION_MATERIAL_RESOURCE_COUNT:
		errors.append("wing_skirmisher_material_resource_count_drift")
	if descendant_node_count != PRESENTATION_DESCENDANT_NODE_COUNT + int(marking_costs.nodes):
		errors.append("wing_skirmisher_descendant_node_count_drift")
	if light_node_count != PRESENTATION_LIGHT_NODE_COUNT:
		errors.append("wing_skirmisher_light_node_count_drift")
	if collision_shape_count != PRESENTATION_COLLISION_SHAPE_COUNT:
		errors.append("wing_skirmisher_collision_shape_count_drift")
	if particle_node_count != PRESENTATION_PARTICLE_NODE_COUNT:
		errors.append("wing_skirmisher_particle_node_count_drift")
	if (
		authority_node_count != 0
		or scripted_node_count != 0
		or child_node_count != 0
		or metadata_entry_count != 0
		or processing_node_count != 0
	):
		errors.append("wing_chalk_band_stock_gained_authority_or_lifecycle")

	return {
		"valid": errors.is_empty(),
		"errors": errors,
		"scope": &"wing_skirmisher_mirrored_childless_trim",
		"surface_marking_costs": marking_costs,
		"total_presentation_allocations": {
			"nodes": visual_node_count + int(marking_costs.nodes),
			"mesh_instances": mesh_instance_count + int(marking_costs.mesh_instances),
			"geometry_submissions": surface_submission_count + int(marking_costs.geometry_submissions),
			"unique_mesh_resources": mesh_resource_ids.size() + int(marking_costs.unique_mesh_resources),
			"unique_material_resources": material_resource_ids.size() + int(marking_costs.unique_material_resources),
		},
		"descendant_nodes_old": PRESENTATION_DESCENDANT_NODE_COUNT,
		"descendant_nodes_new": descendant_node_count,
		"visual_nodes_old": PRESENTATION_VISUAL_NODE_COUNT,
		"visual_nodes_new": visual_node_count,
		"mesh_instance_nodes_old": PRESENTATION_MESH_INSTANCE_COUNT,
		"mesh_instance_nodes_new": mesh_instance_count,
		"drawn_copies_old": PRESENTATION_MESH_INSTANCE_COUNT,
		"drawn_copies_new": mesh_instance_count,
		"structural_submissions_old": PRESENTATION_SURFACE_SUBMISSION_COUNT,
		"structural_submissions_new": surface_submission_count,
		"material_resources_old": PRESENTATION_MATERIAL_RESOURCE_COUNT,
		"material_resources_new": material_resource_ids.size(),
		"mesh_resources_old": BASELINE_PRESENTATION_MESH_RESOURCE_COUNT,
		"mesh_resources_new": mesh_resource_ids.size(),
		"box_mesh_resources_old": BASELINE_PRESENTATION_BOX_MESH_RESOURCE_COUNT,
		"box_mesh_resources_new": box_mesh_resource_ids.size(),
		"wing_chalk_band_instances": band_instance_count,
		"wing_chalk_band_mesh_resources_old": BASELINE_WING_CHALK_BAND_MESH_RESOURCE_COUNT,
		"wing_chalk_band_mesh_resources_new": band_mesh_resource_ids.size(),
		"wing_chalk_band_submissions_old": WING_CHALK_BAND_INSTANCE_COUNT,
		"wing_chalk_band_submissions_new": band_submission_count,
		"wing_instances": wing_instance_count,
		"wing_mesh_resources_old": BASELINE_WING_MESH_RESOURCE_COUNT,
		"wing_mesh_resources_new": wing_mesh_resource_ids.size(),
		"wing_submissions_old": WING_INSTANCE_COUNT,
		"wing_submissions_new": wing_submission_count,
		"winglet_fin_instances": fin_instance_count,
		"winglet_fin_mesh_resources_old": BASELINE_WINGLET_FIN_MESH_RESOURCE_COUNT,
		"winglet_fin_mesh_resources_new": fin_mesh_resource_ids.size(),
		"winglet_fin_submissions_old": WINGLET_FIN_INSTANCE_COUNT,
		"winglet_fin_submissions_new": fin_submission_count,
		"light_nodes_old": PRESENTATION_LIGHT_NODE_COUNT,
		"light_nodes_new": light_node_count,
		"collision_shapes_old": PRESENTATION_COLLISION_SHAPE_COUNT,
		"collision_shapes_new": collision_shape_count,
		"particle_nodes_old": PRESENTATION_PARTICLE_NODE_COUNT,
		"particle_nodes_new": particle_node_count,
		"behavior_rows": behavior_rows,
		"wing_behavior_rows": wing_behavior_rows,
		"fin_behavior_rows": fin_behavior_rows,
		"authority_node_count": authority_node_count,
		"scripted_node_count": scripted_node_count,
		"child_node_count": child_node_count,
		"metadata_entry_count": metadata_entry_count,
		"processing_node_count": processing_node_count,
		"batched": false,
		"renderer_consumed_values_changed": false,
		"frame_time_claimed": false,
		"gpu_draw_call_claimed": false,
		"vram_claimed": false,
		"whole_scene_budget_claimed": false,
	}.duplicate(true)


func _wing_mesh_matches_recipe(mesh: ArrayMesh) -> bool:
	if (
		mesh.get_surface_count() != 1
		or mesh.surface_get_primitive_type(0) != Mesh.PRIMITIVE_TRIANGLES
		or mesh.surface_get_material(0) != _materials.skirmisher_moss
	):
		return false
	# The beveled four-station airframe replaced the original six-point prism.
	# Keep an independent canonical vertex recipe for drift checks without
	# rebuilding reference mesh resources on every encounter audit.
	if _wing_recipe_vertices.is_empty():
		var recipe := _armour_mesh(WING_SIZE, _materials.skirmisher_moss, 0.08, WING_PORT_SKEW)
		_wing_recipe_vertices = recipe.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	var actual_vertices: PackedVector3Array = mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	if actual_vertices.size() != _wing_recipe_vertices.size():
		return false
	for vertex_index in actual_vertices.size():
		if not actual_vertices[vertex_index].is_equal_approx(_wing_recipe_vertices[vertex_index]):
			return false
	return true


func get_validation_errors() -> PackedStringArray:
	var errors := get_resolver_backed_errors()
	if _weapon_definition == null:
		errors.append("scatter weapon definition is required")
	else:
		for definition_error in _weapon_definition.get_validation_errors():
			errors.append("scatter weapon definition invalid: %s" % definition_error)
		if _weapon_definition.weapon_id != SKIRMISHER_WEAPON_ID:
			errors.append("scatter weapon identity drifted")
		if (
			not _weapon_definition.spread_enabled
			or not is_equal_approx(_weapon_definition.spread_degrees, 5.0)
		):
			errors.append("scatter weapon must retain its deterministic five-degree envelope")
		var profile := get_weapon_profiles().get(SKIRMISHER_WEAPON_ID, {}) as Dictionary
		if (
			int(profile.get("pellet_count", 0))
				!= WeaponDefinitionResolverProfileType.SCATTER_PELLET_COUNT
			or not is_equal_approx(float(profile.get("trigger_damage", 0.0)), 14.0)
		):
			errors.append("scatter resolver profile must retain three pellets and a 14-point trigger cap")
	if not _built:
		errors.append("wing skirmisher presentation has not been built")
	elif not bool(get_wing_chalk_band_resource_audit().valid):
		errors.append("wing skirmisher presentation resource-sharing contract drifted")
	if not WingCoordinator.ROLES.has(_wing_role):
		errors.append("wing role must be one of the coordinator's declared roles")
	if _wing_role == WingCoordinator.ROLE_UNASSIGNED and _active and not _weapon_safed:
		errors.append("an unassigned skirmisher must keep its weapon safed")
	if not _active and not _weapon_safed:
		errors.append("a dormant skirmisher must keep its weapon safed")
	if flank_station_range >= engagement_range:
		errors.append("the flank station must sit inside the engagement range")
	if anchor_station_range >= engagement_range:
		errors.append("the anchor station must sit inside the engagement range")
	if rear_arc_cosine >= 1.0:
		errors.append("the rear arc must admit some part of the player's rear hemisphere")
	if rear_cross_lateral_offset <= 0.0:
		errors.append("the rear cross must name a visible lateral offset")
	if rear_cross_duration <= 0.0:
		errors.append("the rear cross must have a finite positive duration")
	return errors


# ---------------------------------------------------------------- tactics ----

## Station keeping relative to the *player's facing*, not to the player's
## position. That single change is what makes the pair read as coordinated: the
## anchor is always the craft in your windscreen and the flanker is always the
## one that is not.
func _choose_motion_direction(target_direction: Vector3, distance: float) -> Vector3:
	var target_forward := _get_target_forward()
	var lateral := Vector3.UP.cross(target_direction)
	if lateral.length_squared() <= 0.001:
		lateral = Vector3.RIGHT
	lateral = lateral.normalized() * _orbit_sign
	var weave := Vector3.UP * sin(_elapsed * 0.97 + 0.4) * 0.16

	if _wing_role == WingCoordinator.ROLE_FLANKER:
		_refresh_rear_cross_state()
		if _rear_cross_state == &"active":
			var cross_station := _get_rear_cross_station()
			# Presentation samples the exact station used by this authoritative
			# movement update. It gains no callback or target ownership of its own.
			_apply_rear_cross_presentation()
			var to_cross_station := cross_station - global_position
			if to_cross_station.length_squared() > 1.0:
				# The player's rear point remains in the blend, so the pass reads as
				# a wake crossing rather than an unrelated sideways retreat.
				return (to_cross_station.normalized() * 0.88 + weave * 0.35).normalized()
			_complete_rear_cross()
		var station := _get_target_aim_position() - target_forward * flank_station_range
		var to_station := station - global_position
		if to_station.length_squared() <= 0.001:
			return target_direction
		var desired := to_station.normalized()
		if _frontal_exposure() > rear_arc_cosine:
			# Still in the player's front hemisphere: swinging wide beats flying
			# through his guns, and it is what makes the manoeuvre readable.
			desired = (desired * 0.55 + lateral * 0.95 + weave).normalized()
		return desired

	# Anchor (and any unassigned craft): take the station directly in front of
	# the player's nose, then hold it with a shallow crossing orbit.
	var anchor_station := _get_target_aim_position() + target_forward * anchor_station_range
	var to_anchor := anchor_station - global_position
	var anchor_distance := to_anchor.length()
	if anchor_distance <= 0.001:
		return (lateral * 0.9 + weave).normalized()
	var approach := to_anchor / anchor_distance
	if anchor_distance < anchor_station_range * 0.5:
		approach = (approach * 0.35 + lateral * 0.92 + weave).normalized()
	if distance < retreat_range:
		approach = (-target_direction * 0.7 + lateral * 0.72 + weave).normalized()
	return approach


## Fast, cheap shots — and, for a flanker, only from behind. The arc test is
## against the *player's* forward vector, so it is the player's facing that
## opens and closes this weapon, not the skirmisher's own aim.
func _update_weapon(
		target_position: Vector3,
		target_direction: Vector3,
		distance: float,
		delta: float
	) -> void:
	var arc_open := _is_firing_arc_open()
	_set_weapon_safed(not arc_open)
	var forward := -global_basis.z
	if _telegraph_remaining > 0.0:
		var aim_held := forward.dot(target_direction) >= aim_tolerance - 0.06
		if (
			not arc_open
			or distance > engagement_range
			or not aim_held
			or not _has_line_of_sight(target_position)
		):
			_telegraph_remaining = 0.0
			_cooldown_remaining = maxf(_cooldown_remaining, abort_recovery)
			if not arc_open:
				_shots_arc_denied += 1
			return
		_telegraph_remaining = maxf(0.0, _telegraph_remaining - delta)
		if _telegraph_remaining <= 0.0:
			_fire_at_target(_get_target_aim_position())
		return
	if not arc_open:
		return
	if _cooldown_remaining > 0.0 or distance > engagement_range:
		return
	if forward.dot(target_direction) < aim_tolerance:
		return
	if not _has_line_of_sight(target_position):
		return
	_telegraph_remaining = telegraph_time


## Observe the inherited resolver call after it has made the authoritative
## decision. A miss is still a resolved discharge and therefore a readable cue;
## rejected or withheld requests never start movement.
func _fire_at_target(target_position: Vector3) -> void:
	var shots_before := get_shots_fired()
	super(target_position)
	if get_shots_fired() <= shots_before or _wing_role != WingCoordinator.ROLE_FLANKER:
		return
	var result := get_last_shot_result()
	if bool(result.get("accepted", false)) and bool(result.get("resolved", false)):
		_begin_rear_cross()


## The anchor may always shoot. The flanker may shoot only from the player's
## rear hemisphere. An unassigned craft may not shoot at all — that state only
## exists before the coordinator's first assignment and while standing down.
func _is_firing_arc_open() -> bool:
	if not _active or not is_instance_valid(_target):
		return false
	if _wing_role == WingCoordinator.ROLE_ANCHOR:
		return true
	if _wing_role == WingCoordinator.ROLE_FLANKER:
		return _frontal_exposure() <= rear_arc_cosine
	return false


## How far inside the player's forward arc this craft is sitting: +1 dead ahead
## of him, -1 dead astern.
func _frontal_exposure() -> float:
	if not is_instance_valid(_target):
		return 1.0
	var offset := global_position - _target.global_position
	if offset.length_squared() <= 0.000001:
		return 1.0
	return _get_target_forward().dot(offset.normalized())


func _get_target_forward() -> Vector3:
	if not is_instance_valid(_target):
		return Vector3.FORWARD
	var forward := -_target.global_basis.z
	if forward.length_squared() <= 0.001:
		return Vector3.FORWARD
	return forward.normalized()


func _get_target_right() -> Vector3:
	if not is_instance_valid(_target):
		return Vector3.RIGHT
	var right := _target.global_basis.x
	if right.length_squared() <= 0.001:
		return Vector3.RIGHT
	return right.normalized()


## One source of truth for both the inherited movement request and its retained
## direction vane. Every term already belongs to the active rear-cross tactic.
func _get_rear_cross_station() -> Vector3:
	return (
		_get_target_aim_position()
			- _get_target_forward() * flank_station_range
			+ _get_target_right()
				* rear_cross_lateral_offset * _rear_cross_destination_side
	)


func _begin_rear_cross() -> void:
	_refresh_rear_cross_state()
	if _rear_cross_state == &"active" or not is_instance_valid(_target):
		return
	var target_right := _get_target_right()
	var side_offset := (global_position - _target.global_position).dot(target_right)
	if absf(side_offset) > 0.5:
		_rear_cross_destination_side = -signf(side_offset)
	else:
		# A dead-centre stern shot still has a deterministic opposite shoulder,
		# keyed to the inherited orbit selected from the spawn side.
		_rear_cross_destination_side = -1.0 if _orbit_sign >= 0.0 else 1.0
	_rear_cross_started_at = _elapsed
	_rear_cross_state = &"active"
	_rear_cross_activation_generation = _activation_generation
	_apply_rear_cross_presentation()


func _refresh_rear_cross_state() -> void:
	if (
		_rear_cross_state == &"active"
		and (
			not _active
			or _wing_role != WingCoordinator.ROLE_FLANKER
			or not _has_current_target()
			or _rear_cross_activation_generation != _activation_generation
		)
	):
		_reset_rear_cross_tactic()
		return
	if (
		_rear_cross_state == &"active"
		and _elapsed - _rear_cross_started_at >= rear_cross_duration
	):
		_complete_rear_cross()


func _complete_rear_cross() -> void:
	if _rear_cross_state != &"active":
		return
	_rear_cross_state = &"completed"
	_rear_cross_completed_count += 1
	_rear_cross_activation_generation = 0
	_apply_rear_cross_presentation()


func _reset_rear_cross_tactic() -> void:
	_rear_cross_state = &"idle"
	_rear_cross_started_at = 0.0
	_rear_cross_destination_side = 1.0
	_rear_cross_completed_count = 0
	_rear_cross_activation_generation = 0
	_apply_rear_cross_presentation()


func _is_fire_authorized() -> bool:
	# The encounter's authorization first, then this craft's own arc. Both are
	# re-asked on the dispatch frame; neither is cached from the charge frame.
	return super() and _is_firing_arc_open()


# ----------------------------------------------------------- presentation ----

func _assign_wing_role_internal(role: StringName) -> void:
	var next := role if WingCoordinator.ROLES.has(role) else WingCoordinator.ROLE_UNASSIGNED
	if _wing_role == next:
		return
	if next != WingCoordinator.ROLE_FLANKER:
		_reset_rear_cross_tactic()
	_wing_role = next
	_apply_role_presentation()
	wing_role_changed.emit(_wing_role)


func _set_weapon_safed(safed: bool) -> void:
	if _weapon_safed == safed:
		return
	_weapon_safed = safed
	_apply_role_presentation()
	weapon_safed_changed.emit(_weapon_safed)


## A step function of role and safing state. Deliberately not driven from a
## phase of accumulated presentation time: `HeroDamagePresentation`'s warning
## and engine-failure lights derive their energy from `sin(elapsed * 13)` and
## `sin(elapsed * 29) + sin(elapsed * 61)`, which makes any single-frame capture
## of them phase-dependent and was the root cause of a long-standing flaky gate.
## Nothing on this hull repeats that: every value below is a function of state
## only, so any frame of a given state photographs identically.
func _apply_role_presentation() -> void:
	if not _built:
		return
	var lamp_colour := ROLE_ANCHOR_LAMP
	var lamp_energy := 0.0
	if _wing_role == WingCoordinator.ROLE_ANCHOR:
		lamp_colour = ROLE_ANCHOR_LAMP
		lamp_energy = 3.4
	elif _wing_role == WingCoordinator.ROLE_FLANKER:
		lamp_colour = ROLE_FLANKER_LAMP
		lamp_energy = 3.4
	if is_instance_valid(_role_lamp):
		var lamp_material := _role_lamp.get_active_material(0) as StandardMaterial3D
		if lamp_material != null:
			lamp_material.albedo_color = lamp_colour
			lamp_material.emission = lamp_colour
			lamp_material.emission_energy_multiplier = lamp_energy
		_role_lamp.visible = _active and lamp_energy > 0.0
	if is_instance_valid(_role_light):
		_role_light.light_color = lamp_colour
		_role_light.light_energy = lamp_energy * 0.6 if _active else 0.0
	if is_instance_valid(_muzzle_lens):
		# The gun's own lens is the honest read on whether it can hurt you.
		_muzzle_lens.visible = _active and not _weapon_safed
	if is_instance_valid(_warning_light) and _weapon_safed:
		_warning_light.light_energy = 0.0


## The inherited presentation loop rewrites every registered warning lens's
## visibility from `_active` alone each frame. The muzzle lens is registered
## there on purpose — it should still swell with the charge — so the safing read
## is re-applied on top of the inherited pass rather than instead of it.
func _update_presentation(delta: float) -> void:
	super(delta)
	if not _built:
		return
	# Target removal can happen without another coordinator assignment. Observe
	# that loss through the inherited presentation pass so a committed vane can
	# never remain on a craft that no longer has a live rear-cross target.
	_refresh_rear_cross_state()
	# Physics has already applied `_update_attitude()` for this frame. Re-sample
	# the same tactic station now so the non-top-level vane remains world-true
	# after its hull and every transformed ancestor have moved or rotated.
	_apply_rear_cross_presentation()
	if (
		_active
		and not _weapon_safed
		and _telegraph_remaining > 0.0
		and is_instance_valid(_muzzle_lens)
	):
		# The fast repeater reads as a narrow vertical tick. Its static scale
		# signature adds no pulse frequency and remains subordinate to safing.
		_muzzle_lens.scale *= REPEATER_CHARGE_SCALE
	if is_instance_valid(_muzzle_lens):
		_muzzle_lens.visible = _active and not _weapon_safed
	if is_instance_valid(_warning_light) and _weapon_safed:
		_warning_light.light_energy = 0.0


## A direct observation, never a phase or animation. The retained wedge samples
## the exact cross station at the existing tactic update and again in the
## existing post-attitude presentation pass, so transformed parents and a
## moving/turning hull or target cannot make it lie about the committed route.
func _apply_rear_cross_presentation() -> void:
	if not is_instance_valid(_rear_cross_cue):
		return
	var presented := (
		_active
		and _wing_role == WingCoordinator.ROLE_FLANKER
		and _rear_cross_state == &"active"
		and _rear_cross_activation_generation == _activation_generation
		and _has_current_target()
	)
	_rear_cross_cue.position = REAR_CROSS_CUE_POSITION
	if not presented:
		_rear_cross_cue.visible = false
		_rear_cross_cue.rotation = Vector3.ZERO
		return
	var direction := _get_rear_cross_station() - global_position
	if direction.length_squared() <= 0.000001:
		_rear_cross_cue.visible = false
		return
	var normalized_direction := direction.normalized()
	var presentation_up := Vector3.UP
	if absf(normalized_direction.dot(presentation_up)) >= 0.98:
		presentation_up = Vector3.RIGHT
	_rear_cross_cue.global_basis = Basis.looking_at(
		normalized_direction,
		presentation_up
	)
	_rear_cross_cue.visible = true


# ---------------------------------------------------------------- geometry ----

## Builds the skirmisher hull. Every primitive, material and particle helper,
## and the whole inherited damage/destruction/debris presentation, are reused
## from `RangeOpponent`; only the silhouette, palette and mounts differ.
func _build_interceptor() -> void:
	if _built:
		return
	_built = true
	motion_mode = CharacterBody3D.MOTION_MODE_FLOATING
	floor_stop_on_slope = false
	# The station ranges are the single source of truth for this craft's
	# tactics. The inherited orbit fields are kept in step so the shared movement
	# loop bands speed against the distances it actually manoeuvres to.
	preferred_range = anchor_station_range
	retreat_range = minf(retreat_range, anchor_station_range * 0.5)
	_create_materials()
	_create_skirmisher_materials()
	_visual_root = Node3D.new()
	_visual_root.name = "WingSkirmisherVisual"
	add_child(_visual_root)

	# A short, wide, low delta. Half the defender's length and none of the
	# picket's reach: it has to read as something that lives inside your turn.
	# A crowned foredeck grows into the cockpit shoulders; the broad delta
	# remains a separate sharp wing skin with its existing mounting stations.
	_box_from_mesh(_visual_root, "DeltaNose", Vector3(0, 0, -1.9), _skirmisher_forward_shell([
		Vector4(-2.1, 0.12, 0.16, -0.04), Vector4(-1.88, 0.25, 0.205, -0.03),
		Vector4(-1.55, 0.44, 0.26, -0.02), Vector4(-1.1, 0.68, 0.32, -0.005),
		Vector4(-0.55, 0.91, 0.37, 0.005), Vector4(0.0, 1.08, 0.4, 0),
		Vector4(0.55, 1.19, 0.4, -0.005), Vector4(1.05, 1.27, 0.395, -0.01),
		Vector4(1.35, 1.3, 0.39, -0.01),
	], _materials.skirmisher_hull))
	_box_from_mesh(_visual_root, "DeltaBody", Vector3(0, -0.02, 0.9), _skirmisher_forward_shell([
		Vector4(-1.45, 1.3, 0.39, 0.01), Vector4(-0.45, 1.7, 0.43, 0),
		Vector4(0.85, 1.66, 0.43, 0), Vector4(1.8, 1.25, 0.31, -0.03),
	], _materials.skirmisher_hull))
	_box(_visual_root, "Keelplate", Vector3(0.0, -0.44, 0.6), Vector3(2.2, 0.24, 4.4), _materials.skirmisher_deep)
	# Glazing sits in a tapered saddle instead of on a rectangular plinth. The
	# raised aft shoulder gives the cockpit a pressure volume with a clear sill.
	_box_from_mesh(_visual_root, "Canopy", Vector3(0.0, 0.43, -1.0), _skirmisher_forward_shell([
		Vector4(-1.03, 0.1, 0.055, 0.0), Vector4(-0.84, 0.235, 0.12, 0.025),
		Vector4(-0.62, 0.37, 0.18, 0.05), Vector4(-0.25, 0.48, 0.235, 0.075),
		Vector4(0.05, 0.52, 0.255, 0.08), Vector4(0.35, 0.51, 0.25, 0.075),
		Vector4(0.58, 0.47, 0.24, 0.06), Vector4(0.76, 0.43, 0.22, 0.045),
		Vector4(0.97, 0.33, 0.09, -0.025),
	], _materials.glass))
	_pressure_body(_visual_root, "SpineFairing", Vector3(0.0, 0.42, 1.1), [
		Vector4(-1.3, 0.39, 0.13, 0.0), Vector4(-0.72, 0.32, 0.18, 0.0),
		Vector4(0.42, 0.31, 0.18, 0.0), Vector4(1.3, 0.19, 0.075, -0.1),
	], _materials.skirmisher_moss)

	_wing_chalk_band_mesh = _make_box_mesh(WING_CHALK_BAND_SIZE, _materials.skirmisher_chalk)
	_winglet_fin_mesh = _skirmisher_fin_shell(FIN_SECTIONS, _materials.skirmisher_chalk)
	var engine_pod_mesh := _skirmisher_engine_pod_mesh()
	for side in [-1.0, 1.0]:
		if side < 0.0:
			var port_wing := _wedge(
				_visual_root, "Wing", WING_POSITIONS[0], WING_SIZE,
				_materials.skirmisher_moss, WING_PORT_SKEW
			)
			_wing_mesh = port_wing.mesh as ArrayMesh
		else:
			var starboard_wing := MeshInstance3D.new()
			starboard_wing.name = "Wing"
			starboard_wing.position = WING_POSITIONS[1]
			starboard_wing.scale = WING_SCALES[1]
			starboard_wing.mesh = _wing_mesh
			_visual_root.add_child(starboard_wing)
		_box_from_mesh(_visual_root, "WingChalkBand", Vector3(side * 2.5, 0.06, 0.4), _wing_chalk_band_mesh)
		_box_from_mesh(_visual_root, "WingletFin", Vector3(side * 3.7, 0.36, 1.9), _winglet_fin_mesh, Vector3(0.0, side * 0.16, side * -0.22))
		var engine_pod := MeshInstance3D.new()
		engine_pod.name = "EnginePod"
		engine_pod.position = Vector3(side * 1.0, -0.02, 2.5)
		engine_pod.mesh = engine_pod_mesh
		_visual_root.add_child(engine_pod)
		var plume := _exhaust_plume(_visual_root, "EnginePlume", Vector3(side * 1.0, -0.02, 3.42), 0.2, 0.8, _materials.skirmisher_engine, Vector3(90.0, 0.0, 0.0))
		_engine_glows.append(plume)
		var engine_light := OmniLight3D.new()
		engine_light.name = "EngineLight"
		engine_light.position = Vector3(side * 1.0, -0.02, 3.1)
		engine_light.light_color = SKIRMISHER_ENGINE
		engine_light.light_energy = 0.0
		engine_light.omni_range = 4.2
		engine_light.shadow_enabled = false
		_visual_root.add_child(engine_light)
		_engine_lights.append(engine_light)

	# Chin repeater. One gun, mounted low and central, with a lens that goes
	# dark the instant the weapon is safed.
	_cylinder(_visual_root, "RepeaterHousing", Vector3(0.0, -0.3, -2.9), 0.24, 1.7, _materials.skirmisher_deep, Vector3(90.0, 0.0, 0.0))
	_muzzle_lens = _sphere(_visual_root, "RepeaterLens", Vector3(0.0, -0.3, -3.86), 0.15, _materials.skirmisher_muzzle)
	_warning_lenses.append(_muzzle_lens)

	# Dorsal role lamp. This is the whole coordination read at combat distance:
	# amber means "this one is in your face", green means "this one is going for
	# your back". Its own material instance, so the two craft in a wing can
	# display different roles at the same time.
	_role_lamp = _sphere(_visual_root, "RoleLamp", Vector3(0.0, 0.66, 1.2), 0.2, _materials.skirmisher_role_lamp)
	_role_light = OmniLight3D.new()
	_role_light.name = "RoleLampLight"
	_role_light.position = Vector3(0.0, 0.82, 1.2)
	_role_light.light_color = ROLE_ANCHOR_LAMP
	_role_light.light_energy = 0.0
	_role_light.omni_range = 6.5
	_role_light.shadow_enabled = false
	_visual_root.add_child(_role_light)

	# A single retained triangular prism points across the dorsal silhouette
	# toward the committed rear-cross shoulder. Nesting it under the existing
	# role lamp keeps it banked with the hull without expanding the visual root's
	# frozen direct-renderer and mirrored-trim resource budgets.
	_rear_cross_cue = _wedge(
		_role_lamp,
		"RearCrossDirectionVane",
		REAR_CROSS_CUE_POSITION,
		REAR_CROSS_CUE_SIZE,
		_materials.skirmisher_rear_cross_cue
	)
	_rear_cross_cue.process_mode = Node.PROCESS_MODE_DISABLED
	_rear_cross_cue.visible = false
	_rear_cross_cue_mesh = _rear_cross_cue.mesh as ArrayMesh

	_muzzle_port = Marker3D.new()
	_muzzle_port.name = "RepeaterMuzzle"
	_muzzle_port.position = Vector3(0.0, -0.3, -3.98)
	add_child(_muzzle_port)
	# One gun. The inherited alternating-muzzle field is pinned to the same
	# marker so no inherited path can fire from a phantom port.
	_muzzle_starboard = _muzzle_port

	_warning_light = OmniLight3D.new()
	_warning_light.name = "RepeaterChargeLight"
	_warning_light.position = Vector3(0.0, -0.3, -3.6)
	_warning_light.light_color = ROLE_ANCHOR_LAMP
	_warning_light.light_energy = 0.0
	_warning_light.omni_range = 6.0
	_warning_light.shadow_enabled = false
	add_child(_warning_light)

	_build_skirmisher_fittings()
	# Wing registration follows the broad rear skin; heat labels sit on engine lids.
	for side in [-1.0, 1.0]:
		ShipSurfaceDetail.mark_surface(_visual_root, "WingRegistry", "skirmisher",
			Vector3(side * 2.55, 0.05, 2.4), Vector2(1.8, 0.9), Vector3.UP, Vector3.FORWARD)
		ShipSurfaceDetail.mark_surface(_visual_root, "EngineHeat", "exhaust",
			Vector3(side * 1.0, 0.37, 2.38), Vector2(0.8, 0.4), Vector3.UP, Vector3(side, 0, 0))
	_build_collision()
	_build_damage_effects()


## Formed forward pressure volume; retains the authored bounds and shared finishes.
func _skirmisher_forward_shell(sections: Array, material: Material, open_front := false, segments := 64) -> ArrayMesh:
	var key := "skirmisher_crown:" + str(sections) + ":" + str(material.get_instance_id()) + ":" + str(open_front) + ":" + str(segments)
	if _pressure_shell_meshes.has(key):
		return _pressure_shell_meshes[key] as ArrayMesh
	var rings: Array[PackedVector3Array] = []
	var normals: Array[PackedVector3Array] = []
	var profile := PackedVector2Array()
	var tangents := PackedVector2Array()
	# A continuously crowned deck and glazing replace the broad mounting flat.
	# Superellipse shoulders keep the low, chined delta rather than a round tube.
	for j in segments:
		var angle := PI * 0.5 - float(j) * TAU / float(segments)
		var c := cos(angle)
		var v := sin(angle)
		profile.append(Vector2(signf(c) * pow(absf(c), 0.65), signf(v) * pow(absf(v), 0.65)))
	for j in profile.size():
		tangents.append((profile[(j + 1) % profile.size()] - profile[(j + profile.size() - 1) % profile.size()]).normalized())
	# Keep coating coordinates in metres. Use one reference perimeter throughout
	# the shell so tapering stations cannot make the finish drift along its axis.
	var reference_size := Vector2.ZERO
	for section: Vector4 in sections:
		reference_size = reference_size.max(Vector2(section.y, section.z))
	var arc_distances := PackedFloat32Array([0.0])
	for j in profile.size():
		var span := (profile[(j + 1) % profile.size()] - profile[j]) * reference_size
		arc_distances.append(arc_distances[-1] + span.length())
	for r in sections.size():
		var section: Vector4 = sections[r]
		var previous: Vector4 = sections[maxi(0, r - 1)]
		var next: Vector4 = sections[mini(sections.size() - 1, r + 1)]
		var slope := (next - previous) / (next.x - previous.x)
		var ring := PackedVector3Array()
		var ring_normals := PackedVector3Array()
		for j in profile.size():
			var point := profile[j]
			ring.append(Vector3(point.x * section.y, point.y * section.z + section.w, section.x))
			var around := Vector3(tangents[j].x * section.y, tangents[j].y * section.z, 0)
			var along := Vector3(point.x * slope.y, point.y * slope.z + slope.w, 1)
			# Shared analytic side normals remove triangle diagonals and continue
			# through authored stations. End caps still have crisp planar normals.
			ring_normals.append(along.cross(around).normalized())
		rings.append(ring)
		normals.append(ring_normals)
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	surface.set_material(material)
	for r in rings.size() - 1:
		for j in profile.size():
			var k := (j + 1) % profile.size()
			# Clockwise fronts, matching the armour emitter; the pressure skin
			# alone interpolates vertex normals across each formed shoulder.
			for address: Vector2i in [Vector2i(r, j), Vector2i(r + 1, k), Vector2i(r + 1, j), Vector2i(r, j), Vector2i(r, k), Vector2i(r + 1, k)]:
				var point := rings[address.x][address.y]
				var normal := normals[address.x][address.y]
				surface.set_normal(normal)
				# A continuous wrap avoids projection switches across the shoulder.
				var around_index := profile.size() if address.y == 0 and j == profile.size() - 1 else address.y
				surface.set_uv(Vector2(arc_distances[around_index], point.z))
				surface.add_vertex(point)
	for j in range(1, profile.size() - 1):
		if not open_front:
			_emit_armour_triangle(surface, rings[0][0], rings[0][j], rings[0][j + 1])
		_emit_armour_triangle(surface, rings[-1][0], rings[-1][j + 1], rings[-1][j])
	surface.generate_tangents()
	var mesh := surface.commit()
	_pressure_shell_meshes[key] = mesh
	return mesh


func _build_collision() -> void:
	var body := CollisionShape3D.new()
	body.name = "DeltaCollision"
	body.position = Vector3(0.0, 0.0, 0.2)
	var body_shape := BoxShape3D.new()
	body_shape.size = Vector3(3.4, 1.1, 7.4)
	body.shape = body_shape
	add_child(body)
	for side in [-1.0, 1.0]:
		var wing := CollisionShape3D.new()
		wing.name = "PortWingCollision" if side < 0.0 else "StarboardWingCollision"
		wing.position = Vector3(side * 2.4, -0.06, 1.0)
		var wing_shape := BoxShape3D.new()
		wing_shape.size = Vector3(3.0, 0.5, 3.8)
		wing.shape = wing_shape
		add_child(wing)


func _build_damage_effects() -> void:
	_damage_sparks = _make_spark_particles(14, 0.6, 4.0)
	_damage_sparks.name = "DamageSparks"
	_damage_sparks.position = Vector3(0.7, 0.2, 0.6)
	_damage_sparks.one_shot = false
	_damage_sparks.emitting = false
	_damage_sparks.visible = false
	add_child(_damage_sparks)
	_damage_smoke = _make_smoke_particles(false)
	_damage_smoke.name = "EngineSmoke"
	_damage_smoke.position = Vector3(-1.0, 0.06, 2.9)
	_damage_smoke.emitting = false
	_damage_smoke.visible = false
	add_child(_damage_smoke)


func _create_skirmisher_materials() -> void:
	_materials.skirmisher_hull = _material(HULL_BASALT, 0.1, 0.61)
	_materials.skirmisher_moss = _material(HULL_MOSS, 0.1, 0.61)
	_materials.skirmisher_chalk = _material(HULL_CHALK, 0.1, 0.61)
	_materials.skirmisher_chalk.vertex_color_use_as_albedo = true
	_materials.skirmisher_deep = _material(Color("161d20"), 0.6, 0.3)
	_materials.skirmisher_engine = _material(SKIRMISHER_ENGINE, 0.08, 0.2, SKIRMISHER_ENGINE, 2.6)
	_materials.skirmisher_muzzle = _material(ROLE_ANCHOR_LAMP, 0.12, 0.22, ROLE_ANCHOR_LAMP, 2.6)
	_materials.skirmisher_rear_cross_cue = _material(
		REAR_CROSS_CUE_COLOR,
		0.08,
		0.24,
		REAR_CROSS_CUE_COLOR,
		2.8
	)
	_materials.skirmisher_rear_cross_cue.cull_mode = BaseMaterial3D.CULL_DISABLED
	# A per-instance lamp material: the two craft in a wing show different roles
	# at the same moment, so this must not be shared between them.
	# Authored with emission already enabled: `_apply_role_presentation()` only
	# retints and re-energises it, and a material whose emission was never
	# enabled would silently ignore both.
	_materials.skirmisher_role_lamp = _material(ROLE_ANCHOR_LAMP, 0.1, 0.2, ROLE_ANCHOR_LAMP, 3.4)


func _build_skirmisher_fittings() -> void:
	var parts: Array = []
	# The sill follows the glazing, sinking its lower edge into the pressure hull.
	parts.append([Vector3(0, 0.32, -1.0), Vector3.ZERO, 0, Vector3.ZERO, [
		Vector4(-1.12, 0.17, 0.09, -0.01), Vector4(-0.62, 0.46, 0.14, 0),
		Vector4(0.22, 0.61, 0.15, 0), Vector4(0.82, 0.52, 0.14, 0),
		Vector4(1.08, 0.35, 0.09, -0.025),
	]])
	# A transverse pressure hoop terminates the canopy at the dorsal spine.
	parts.append([Vector3(0, 0.43, -0.22), Vector3.ZERO, 1, Vector3.ZERO, [
		Vector4(-0.04, 0.44, 0.23, 0.045), Vector4(0.04, 0.43, 0.22, 0.045),
	]])
	# The crowned ducts are joined into this same three-finish batch below.
	for side in [-1.0, 1.0]:
		_add_skirmisher_wing_fittings(parts, side)
		parts.append([Vector3(side*1.0,0.32,2.38),Vector3(0.48,0.1,0.96),0])
	# Forward service bays and winglet inset faces.
	for side in [-1.0,1.0]:
		parts.append([Vector3(side*0.66,0.30,-1.53),Vector3(0.42,0.10,1.39),2,Vector3(0,side*-0.25,0)])
		parts.append([Vector3(side*0.7,0.37,-1.35),Vector3(0.3,0.04,0.72),0,Vector3(0,side*-0.25,0)])
		# The lower saddle meets the outside of the nacelle, below its bore.
		parts.append([Vector3(side * 1.0, -0.43, 2.6), Vector3.ZERO, 0, Vector3.ZERO, [
			Vector4(-0.40, 0.16, 0.055, 0.035),
			Vector4(-0.24, 0.31, 0.075, 0.025),
			Vector4(0.20, 0.32, 0.065, 0.0),
			Vector4(0.34, 0.20, 0.030, 0.035),
		]])
		for rib in 3:
			parts.append([Vector3(side*0.45,0.62,0.5+rib*0.39),Vector3(0.12,0.1,0.22),2])
	parts.append([Vector3(0,-0.02,2.72),Vector3(1.09,0.5,0.09),2])
	for rib in 4:
		parts.append([Vector3(-0.36+rib*0.24,-0.02,2.78),Vector3(0.11,0.36,0.06),0])
	_fit_armour(parts,[_materials.skirmisher_moss,_materials.skirmisher_chalk,_materials.skirmisher_deep])
	var fittings := _visual_root.get_node("FittedArmourAndServices") as MeshInstance3D
	var combined := ArrayMesh.new()
	for finish in 3:
		var surface := SurfaceTool.new()
		surface.begin(Mesh.PRIMITIVE_TRIANGLES)
		surface.set_material(fittings.mesh.surface_get_material(finish))
		surface.append_from(fittings.mesh, finish, Transform3D.IDENTITY)
		var duct := _skirmisher_intake_mesh(finish)
		var fin_fittings := _skirmisher_fin_fittings(finish)
		for side in [-1.0, 1.0]:
			surface.append_from(duct, 0, Transform3D(Basis.IDENTITY, Vector3(side * 1.08, 0, 0)))
			if fin_fittings != null:
				var slot := 0 if side < 0 else 1
				surface.append_from(fin_fittings, 0, Transform3D(
					Basis.from_euler(WINGLET_FIN_ROTATIONS[slot]), WINGLET_FIN_POSITIONS[slot]))
		surface.commit(combined)
	fittings.mesh = combined


## Height, half thickness, half chord and chord centre. The leading edge sweeps
## aft into a narrow rolled tip; the full root chord still meets the wing skin.
const FIN_SECTIONS := [
	Vector4(-0.45, 0.08, 0.65, 0.0),
	Vector4(-0.30, 0.075, 0.60, 0.035),
	Vector4(0.0, 0.058, 0.43, 0.205),
	Vector4(0.30, 0.035, 0.255, 0.375),
	Vector4(0.43, 0.026, 0.16, 0.47),
	Vector4(0.45, 0.012, 0.10, 0.47),
]


## Continuous rolled cross-sections, authored once for both positively rotated
## fin nodes. Analytic normals follow the thickness taper and longitudinal sweep.
func _skirmisher_fin_shell(sections: Array, material: Material) -> ArrayMesh:
	const SEGMENTS := 24
	var rings: Array[PackedVector3Array] = []
	var normals: Array[PackedVector3Array] = []
	var profile := PackedVector2Array()
	for j in SEGMENTS:
		var angle := TAU * float(j) / float(SEGMENTS)
		profile.append(Vector2(cos(angle), sin(angle)))
	for row in sections.size():
		var section: Vector4 = sections[row]
		var previous: Vector4 = sections[maxi(0, row - 1)]
		var next: Vector4 = sections[mini(sections.size() - 1, row + 1)]
		var slope := (next - previous) / (next.x - previous.x)
		var ring := PackedVector3Array()
		var ring_normals := PackedVector3Array()
		for j in SEGMENTS:
			var p := profile[j]
			ring.append(Vector3(p.x * section.y, section.x, p.y * section.z + section.w))
			var around := Vector3(-p.y * section.y, 0, p.x * section.z)
			var along := Vector3(p.x * slope.y, 1, p.y * slope.z + slope.w)
			ring_normals.append(along.cross(around).normalized())
		rings.append(ring)
		normals.append(ring_normals)
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	surface.set_material(material)
	for row in rings.size() - 1:
		for j in SEGMENTS:
			var k := (j + 1) % SEGMENTS
			for address: Vector2i in [Vector2i(row, j), Vector2i(row + 1, k), Vector2i(row + 1, j), Vector2i(row, j), Vector2i(row, k), Vector2i(row + 1, k)]:
				var p := rings[address.x][address.y]
				surface.set_normal(normals[address.x][address.y])
				var wrap := SEGMENTS if address.y == 0 and j == SEGMENTS - 1 else address.y
				surface.set_uv(Vector2(float(wrap) / float(SEGMENTS) * 2.6, p.y))
				surface.add_vertex(p)
	for j in range(1, SEGMENTS - 1):
		_emit_armour_triangle(surface, rings[0][0], rings[0][j], rings[0][j + 1])
		_emit_armour_triangle(surface, rings[-1][0], rings[-1][j + 1], rings[-1][j])
	surface.generate_tangents()
	return surface.commit()


## Root boot and captive covers join the existing three-finish services batch.
## The covers are swept skins with embedded folded returns on both faces, so neither mirror
## needs negative scale or a dark rectangular plate protruding beyond the tip.
func _skirmisher_fin_fittings(finish: int) -> ArrayMesh:
	if finish == 1:
		return null
	var material: Material = _materials.skirmisher_moss if finish == 0 else _materials.skirmisher_deep
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	surface.set_material(material)
	if finish == 0:
		var boot := _skirmisher_fin_shell([
			Vector4(-0.47, 0.16, 0.67, 0.0),
			Vector4(-0.41, 0.15, 0.66, 0.01),
			Vector4(-0.32, 0.095, 0.60, 0.035),
			Vector4(-0.25, 0.073, 0.555, 0.085),
		], material)
		surface.append_from(boot, 0, Transform3D.IDENTITY)
	var cover_sections := [
		Vector4(-0.22, 0.011, 0.32, 0.10),
		Vector4(-0.16, 0.013, 0.34, 0.14),
		Vector4(0.12, 0.011, 0.22, 0.30),
		Vector4(0.22, 0.007, 0.13, 0.37),
	]
	if finish == 0:
		for i in cover_sections.size():
			var section: Vector4 = cover_sections[i]
			section.x = section.x * 0.86 - 0.005
			section.z *= 0.89
			cover_sections[i] = section
	for face in [-1.0, 1.0]:
		_skirmisher_fin_cover(surface, cover_sections, face, 0.011 if finish == 0 else 0.004)
	surface.generate_tangents()
	return surface.commit()


func _skirmisher_fin_face_x(y: float, z: float) -> float:
	for row in FIN_SECTIONS.size() - 1:
		var a: Vector4 = FIN_SECTIONS[row]
		var b: Vector4 = FIN_SECTIONS[row + 1]
		if y <= b.x:
			var section := a.lerp(b, clampf((y - a.x) / (b.x - a.x), 0, 1))
			return section.y * sqrt(maxf(0, 1.0 - pow((z - section.w) / section.z, 2)))
	return 0.0


## The inset follows the fin skin instead of hovering as a planar plate. Fold
## its boundary below the supporting skin to keep grazing side views sealed.
func _skirmisher_fin_cover(surface: SurfaceTool, sections: Array, face: float, lift: float) -> void:
	var rows: Array[PackedVector3Array] = []
	for section: Vector4 in sections:
		var row := PackedVector3Array()
		for step in 13:
			var z := section.w + section.z * (float(step) / 6.0 - 1.0)
			row.append(Vector3(face * (_skirmisher_fin_face_x(section.x, z) + lift), section.x, z))
		rows.append(row)
	for row in rows.size() - 1:
		for step in 12:
			var points := [rows[row][step], rows[row + 1][step], rows[row + 1][step + 1], rows[row][step + 1]]
			if face < 0:
				points.reverse()
			_emit_armour_triangle(surface, points[0], points[1], points[2])
			_emit_armour_triangle(surface, points[0], points[2], points[3])
	var perimeter := PackedVector3Array()
	for p in rows[0]:
		perimeter.append(p)
	for row in range(1, rows.size()):
		perimeter.append(rows[row][-1])
	for step in range(11, -1, -1):
		perimeter.append(rows[-1][step])
	for row in range(rows.size() - 2, 0, -1):
		perimeter.append(rows[row][0])
	if face < 0:
		perimeter.reverse()
	var inward := Vector3(-face * (lift + 0.007), 0, 0)
	for i in perimeter.size():
		var a := perimeter[i]
		var b := perimeter[(i + 1) % perimeter.size()]
		_emit_armour_triangle(surface, a, b, b + inward)
		_emit_armour_triangle(surface, a, b + inward, a + inward)


## The intake rolls into a broad shoulder, then narrows and falls onto the
## existing turned exhaust. Stations are in the craft's longitudinal frame;
## the shared superellipse gives this duct a crown instead of a mounting flat.
const INTAKE_SECTIONS := [
	Vector4(-0.48, 0.34, 0.125, 0.47),
	Vector4(-0.32, 0.375, 0.16, 0.445),
	Vector4(-0.08, 0.43, 0.23, 0.39),
	Vector4(0.20, 0.46, 0.285, 0.36),
	Vector4(0.65, 0.455, 0.28, 0.35),
	Vector4(1.10, 0.42, 0.26, 0.33),
	Vector4(1.48, 0.37, 0.225, 0.30),
	Vector4(1.88, 0.32, 0.19, 0.265),
	Vector4(2.24, 0.285, 0.15, 0.225),
	Vector4(2.63, 0.25, 0.12, 0.17),
]


func _skirmisher_intake_mesh(finish: int) -> ArrayMesh:
	var materials := [_materials.skirmisher_moss, _materials.skirmisher_chalk, _materials.skirmisher_deep]
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	surface.set_material(materials[finish])
	if finish == 0:
		surface.append_from(_skirmisher_forward_shell(INTAKE_SECTIONS, materials[0], true, 32), 0, Transform3D.IDENTITY)
		# Five pressed louvers follow the housing crown over a fitted dark bed.
		for slat in 5:
			_skirmisher_grille_patch(surface, 0.05 + slat * 0.21, 0.115 + slat * 0.21, 0.215, 0.018)
	elif finish == 1:
		# A single continuous rolled lip replaces the separate top and cheeks.
		_skirmisher_intake_band(surface, Vector4(-0.48, 0.34, 0.125, 0.47), Vector4(-0.505, 0.30, 0.065, 0.47))
	else:
		# The mouth is open: an inward-facing liner reaches a recessed bulkhead.
		_skirmisher_intake_band(surface, Vector4(-0.505, 0.30, 0.065, 0.47), Vector4(-0.24, 0.27, 0.05, 0.485))
		var ring := _skirmisher_intake_ring(Vector4(-0.24, 0.27, 0.05, 0.485))
		for j in range(1, ring.size() - 1):
			_emit_armour_triangle(surface, ring[0], ring[j], ring[j + 1])
		_skirmisher_grille_patch(surface, -0.035, 1.04, 0.255, 0.009)
	surface.generate_tangents()
	return surface.commit()


func _skirmisher_intake_ring(section: Vector4) -> PackedVector3Array:
	var ring := PackedVector3Array()
	for j in 32:
		var angle := PI * 0.5 - float(j) * TAU / 32.0
		var c := cos(angle)
		var v := sin(angle)
		ring.append(Vector3(signf(c) * pow(absf(c), 0.65) * section.y,
			signf(v) * pow(absf(v), 0.65) * section.z + section.w, section.x))
	return ring


func _skirmisher_intake_band(surface: SurfaceTool, start: Vector4, end: Vector4) -> void:
	var a := _skirmisher_intake_ring(start)
	var b := _skirmisher_intake_ring(end)
	for j in a.size():
		var k := (j + 1) % a.size()
		_emit_armour_triangle(surface, a[j], b[k], b[j])
		_emit_armour_triangle(surface, a[j], a[k], b[k])


func _skirmisher_intake_crown(x: float, z: float) -> float:
	for i in INTAKE_SECTIONS.size() - 1:
		var a: Vector4 = INTAKE_SECTIONS[i]
		var b: Vector4 = INTAKE_SECTIONS[i + 1]
		if z <= b.x:
			var section := a.lerp(b, clampf((z - a.x) / (b.x - a.x), 0.0, 1.0))
			return section.w + section.z * pow(maxf(0.0, 1.0 - pow(absf(x) / section.y, 2.0 / 0.65)), 0.65 / 2.0)
	return 0.29


## The grille has real transverse curvature and clipped ends. Its sampled
## stations include every underlying shell seam so no face crosses the crown.
func _skirmisher_grille_patch(surface: SurfaceTool, start: float, end: float, half_width: float, lift: float) -> void:
	var stations := PackedFloat32Array([start, start + 0.025])
	for section: Vector4 in INTAKE_SECTIONS:
		if section.x > start + 0.025 and section.x < end - 0.025:
			stations.append(section.x)
	stations.append(end - 0.025)
	stations.append(end)
	for row in stations.size() - 1:
		for step in 16:
			var points := PackedVector3Array()
			for address in [Vector2i(row, step), Vector2i(row + 1, step), Vector2i(row + 1, step + 1), Vector2i(row, step + 1)]:
				var z := stations[address.x]
				var width := half_width * (0.86 if address.x in [0, stations.size() - 1] else 1.0)
				var x := width * (float(address.y) / 8.0 - 1.0)
				points.append(Vector3(x, _skirmisher_intake_crown(x, z) + lift, z))
			_emit_armour_triangle(surface, points[0], points[1], points[2])
			_emit_armour_triangle(surface, points[0], points[2], points[3])

	# Fold the perimeter down into its supporting skin. Both the bed and the
	# raised louvers are closed at grazing angles, with no hovering open edges.
	var perimeter := PackedVector3Array()
	for step in 17:
		var x := half_width * 0.86 * (float(step) / 8.0 - 1.0)
		perimeter.append(Vector3(x, _skirmisher_intake_crown(x, start) + lift, start))
	for row in range(1, stations.size()):
		var x := half_width * (0.86 if row == stations.size() - 1 else 1.0)
		perimeter.append(Vector3(x, _skirmisher_intake_crown(x, stations[row]) + lift, stations[row]))
	for step in range(15, -1, -1):
		var x := half_width * 0.86 * (float(step) / 8.0 - 1.0)
		perimeter.append(Vector3(x, _skirmisher_intake_crown(x, end) + lift, end))
	for row in range(stations.size() - 2, 0, -1):
		var x := -half_width
		perimeter.append(Vector3(x, _skirmisher_intake_crown(x, stations[row]) + lift, stations[row]))
	var depth := lift - (0.006 if lift > 0.01 else -0.003)
	for i in perimeter.size():
		var a := perimeter[i]
		var b := perimeter[(i + 1) % perimeter.size()]
		_emit_armour_triangle(surface, a, b, b - Vector3.UP * depth)
		_emit_armour_triangle(surface, a, b - Vector3.UP * depth, a - Vector3.UP * depth)


## A continuous nacelle and recessed throat replace the closed cylinder and
## detached block petals. Both engines share one stock and one existing finish;
## vertex tint separates the dark liner, shell and narrow retaining lands.
func _skirmisher_engine_pod_mesh() -> ArrayMesh:
	var profile := PackedVector2Array([
		Vector2(0.0, -0.65), Vector2(0.27, -0.65),
		Vector2(0.34, -0.58), Vector2(0.36, -0.48),
		Vector2(0.36, 0.38), Vector2(0.38, 0.43),
		Vector2(0.38, 0.49), Vector2(0.34, 0.58),
		Vector2(0.32, 0.84), Vector2(0.30, 0.88),
		Vector2(0.265, 0.88), Vector2(0.245, 0.81),
		Vector2(0.22, 0.48), Vector2(0.17, 0.32),
		Vector2(0.0, 0.32),
	])
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	surface.set_material(_materials.skirmisher_chalk)
	var distance := 0.0
	const SEGMENTS := 64
	for section in profile.size() - 1:
		var start := profile[section]
		var end := profile[section + 1]
		var slope := end - start
		var tint := Color(0.12, 0.16, 0.18)
		if section in [4, 5, 6, 8, 9]:
			tint = Color(0.65, 0.68, 0.70)
		elif section == 7:
			tint = Color(0.34, 0.39, 0.42)
		elif section >= 10:
			tint = Color(0.025, 0.035, 0.04)
		for segment in SEGMENTS:
			var a := TAU * float(segment) / float(SEGMENTS)
			var b := TAU * float(segment + 1) / float(SEGMENTS)
			var points := PackedVector3Array([
				Vector3(cos(a) * start.x, sin(a) * start.x, start.y),
				Vector3(cos(b) * start.x, sin(b) * start.x, start.y),
				Vector3(cos(b) * end.x, sin(b) * end.x, end.y),
				Vector3(cos(a) * end.x, sin(a) * end.x, end.y),
			])
			for triangle in [[0, 2, 1], [0, 3, 2]]:
				if (points[triangle[2]] - points[triangle[0]]).cross(points[triangle[1]] - points[triangle[0]]).length_squared() < 1e-12:
					continue
				for index in triangle:
					var point := points[index]
					var radial := Vector2(point.x, point.y).normalized()
					surface.set_normal(Vector3(slope.y * radial.x, slope.y * radial.y, -slope.x).normalized())
					surface.set_color(tint)
					if section in [0, 13]:
						surface.set_uv(Vector2(point.x, point.y))
					else:
						surface.set_uv(Vector2(float(segment + (1 if index in [1, 2] else 0)) / float(SEGMENTS), distance + (slope.length() if index in [2, 3] else 0.0)))
					surface.add_vertex(point)
		distance += slope.length()
	surface.generate_tangents()
	var mesh := surface.commit()
	mesh.resource_local_to_scene = false
	return mesh


## Formed load paths, sealed access lids and trailing elevons all join the
## existing three-material fittings batch. The retained mirrored wing skins,
## markings, fin anchors and combat cue geometry keep their original contracts.
func _add_skirmisher_wing_fittings(parts: Array, side: float) -> void:
	# Spanwise shoulder falls from the pressure pod onto the thin wing skin.
	# The chord narrows outboard, so this reads as a fitted root rather than a
	# second longitudinal engine pod resting on a flat plate.
	parts.append([Vector3(side * 1.38, 0.0, 1.13), Vector3.ZERO, 0,
		Vector3(0, side * PI * 0.5, 0), [
			Vector4(0.0, 1.43, 0.29, 0.015),
			Vector4(0.42, 1.34, 0.255, 0.01),
			Vector4(0.9, 1.03, 0.12, 0.015),
			Vector4(1.5, 0.74, 0.025, 0.033),
		]])
	# A single flush, swept maintenance lid sits in a dark gasket on the
	# shoulder. Two short captive latches replace the isolated square bumps.
	var lid_rotation := Vector3(0, side * -0.16, side * -0.14)
	parts.append([Vector3(side * 2.46, 0.126, 1.19),
		Vector3(0.65, 0.016, 1.19), 2, lid_rotation])
	parts.append([Vector3(side * 2.46, 0.139, 1.19),
		Vector3(0.59, 0.016, 1.11), 0, lid_rotation])
	for latch_z in [0.78, 1.59]:
		parts.append([Vector3(side * 2.48, 0.159, latch_z),
			Vector3(0.18, 0.018, 0.048), 1, lid_rotation])
	# Trailing elevons have a continuous hinge recess and two fitted leaves.
	# Slightly raised skins reveal their perimeter without changing silhouette.
	parts.append([Vector3(side * 2.79, 0.064, 2.36),
		Vector3(1.66, 0.025, 0.067), 2])
	for leaf in 2:
		var leaf_x := side * (2.38 + leaf * 0.79)
		parts.append([Vector3(leaf_x, 0.063, 2.61),
			Vector3(0.76, 0.018, 0.45), 2])
		parts.append([Vector3(leaf_x, 0.083, 2.625),
			Vector3(0.705, 0.027, 0.395), 0])
		# Short metal hinge straps tie the leaves into the fixed rear spar.
		parts.append([Vector3(leaf_x, 0.09, 2.35),
			Vector3(0.12, 0.045, 0.145), 1])
	# A tapered actuator shroud meets the hinge, and the fin grows from a
	# spreader shoe. Both are low formed parts with no exposed floating blocks.
	parts.append([Vector3(side * 2.06, 0.057, 2.14), Vector3.ZERO, 0,
		Vector3.ZERO, [
			Vector4(-0.46, 0.045, 0.025, 0),
			Vector4(-0.18, 0.11, 0.065, 0.015),
			Vector4(0.23, 0.105, 0.055, 0.01),
			Vector4(0.34, 0.055, 0.025, 0),
		]])
	parts.append([Vector3(side * 3.64, 0.025, 1.94), Vector3.ZERO, 0,
		Vector3(0, side * 0.16, 0), [
			Vector4(-0.75, 0.07, 0.025, 0),
			Vector4(-0.39, 0.2, 0.09, 0.015),
			Vector4(0.49, 0.2, 0.09, 0.015),
			Vector4(0.71, 0.09, 0.025, 0),
		]])
