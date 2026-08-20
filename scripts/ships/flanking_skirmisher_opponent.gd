class_name FlankingSkirmisherOpponent
extends ResolverBackedOpponent

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
const SKIRMISHER_WEAPON_ID: StringName = &"skirmisher_repeater"
## Reuses the defender's amber. The project's pooled pulse grammar is cyan for
## the player fleet, magenta for the picket's heavy charged lance, and amber for
## ordinary opponent guns; a fourth style would have to be cut into the frozen
## fixed pool, and this craft's gun is an ordinary opponent gun.
const SKIRMISHER_PULSE_STYLE: StringName = &"amber"

## A compact dark delta. Neither the defender's broad ivory dart nor the
## picket's long graphite spine: this reads small and close-in at a glance.
const HULL_BASALT := Color("2f3a3f")
const HULL_MOSS := Color("55665c")
const HULL_CHALK := Color("cfd6cc")
const ROLE_ANCHOR_LAMP := Color("ffb347")
const ROLE_FLANKER_LAMP := Color("58ff9b")
const SKIRMISHER_ENGINE := Color("b6ffe3")

# Component-local static presentation budget. The old build retained one
# BoxMesh per chalk-band node. The mirrored pair has one exact immutable recipe,
# so only its Mesh Resource is shared: nodes, visible copies, materials,
# transforms, lights, collision, and structural submissions remain unchanged.
const WING_CHALK_BAND_SIZE := Vector3(2.4, 0.05, 0.3)
const WING_CHALK_BAND_POSITIONS := [
	Vector3(-2.5, 0.06, 0.4),
	Vector3(2.5, 0.06, 0.4),
]
const PRESENTATION_DESCENDANT_NODE_COUNT := 29
const PRESENTATION_VISUAL_NODE_COUNT := 21
const PRESENTATION_MESH_INSTANCE_COUNT := 18
const PRESENTATION_LIGHT_NODE_COUNT := 4
const PRESENTATION_COLLISION_SHAPE_COUNT := 3
const PRESENTATION_PARTICLE_NODE_COUNT := 2
const PRESENTATION_SURFACE_SUBMISSION_COUNT := 18
const PRESENTATION_MATERIAL_RESOURCE_COUNT := 8
const BASELINE_PRESENTATION_MESH_RESOURCE_COUNT := 16
const PRESENTATION_MESH_RESOURCE_COUNT := 15
const BASELINE_PRESENTATION_BOX_MESH_RESOURCE_COUNT := 6
const PRESENTATION_BOX_MESH_RESOURCE_COUNT := 5
const WING_CHALK_BAND_INSTANCE_COUNT := 2
const BASELINE_WING_CHALK_BAND_MESH_RESOURCE_COUNT := 2
const WING_CHALK_BAND_MESH_RESOURCE_COUNT := 1

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

var _wing_role: StringName = WingCoordinator.ROLE_UNASSIGNED
var _weapon_safed := true
var _role_lamp: MeshInstance3D
var _role_light: OmniLight3D
var _muzzle_lens: MeshInstance3D
var _shots_arc_denied := 0
var _wing_chalk_band_mesh: BoxMesh


# ------------------------------------------------------------- lifecycle ----

func _ready() -> void:
	super()
	set_meta("component_id", COMPONENT_ID)
	set_meta("evidence_status", EVIDENCE_STATUS)
	set_meta("historically_supported", false)
	set_meta("modern_interpretation", &"flanking_skirmisher_opponent")
	if source_id <= 0:
		source_id = DEFAULT_SOURCE_ID
	_apply_role_presentation()


func activate(spawn_transform: Transform3D) -> Dictionary:
	var activation := super(spawn_transform) as Dictionary
	if not bool(activation.get("accepted", false)):
		return activation
	_shots_arc_denied = 0
	_set_weapon_safed(true)
	_apply_role_presentation()
	return activation


func deactivate() -> void:
	super()
	_assign_wing_role_internal(WingCoordinator.ROLE_UNASSIGNED)
	_set_weapon_safed(true)


func _destroy_interceptor(death_position: Vector3) -> void:
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


## Called by `WingCoordinator`. The craft stores and presents the role; it never
## chooses it, so two skirmishers can never both believe they are the anchor.
func assign_wing_role(role: StringName) -> void:
	if not _can_assign_wing_role():
		return
	_assign_wing_role_internal(role)


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


## Renderer-independent, component-local allocation evidence for the first
## exact mirrored visual family. Structural submissions are mesh-surface counts,
## not driver draw calls; no frame-time, draw-call, or VRAM claim is made.
func get_wing_chalk_band_resource_audit() -> Dictionary:
	var errors := PackedStringArray()
	var mesh_resource_ids := {}
	var box_mesh_resource_ids := {}
	var material_resource_ids := {}
	var band_mesh_resource_ids := {}
	var band_material_resource_ids := {}
	var behavior_rows: Array[Dictionary] = []
	var visual_node_count := 0
	var mesh_instance_count := 0
	var surface_submission_count := 0
	var light_node_count := 0
	var collision_shape_count := 0
	var particle_node_count := 0
	var descendant_node_count := 0
	var band_instance_count := 0
	var band_submission_count := 0
	var authority_node_count := 0
	var scripted_node_count := 0
	var child_node_count := 0
	var metadata_entry_count := 0
	var processing_node_count := 0
	var visual := _visual_root
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
			if mesh is BoxMesh:
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
			var band_mesh := band.mesh as BoxMesh
			if band_mesh == null:
				errors.append("wing_chalk_band_mesh_type_drift:%d" % slot_index)
			else:
				band_mesh_resource_ids[band_mesh.get_instance_id()] = true
				band_submission_count += band_mesh.get_surface_count()
				if band_mesh.material != null:
					band_material_resource_ids[band_mesh.material.get_instance_id()] = true
				if (
					not band_mesh.size.is_equal_approx(WING_CHALK_BAND_SIZE)
					or band_mesh.material != _materials.skirmisher_chalk
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
			child_node_count += band.get_child_count()
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

		var descendants := find_children("*", "Node", true, false)
		descendant_node_count = descendants.size()
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
	if descendant_node_count != PRESENTATION_DESCENDANT_NODE_COUNT:
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
		"scope": &"wing_skirmisher_mirrored_childless_chalk_bands",
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
		"light_nodes_old": PRESENTATION_LIGHT_NODE_COUNT,
		"light_nodes_new": light_node_count,
		"collision_shapes_old": PRESENTATION_COLLISION_SHAPE_COUNT,
		"collision_shapes_new": collision_shape_count,
		"particle_nodes_old": PRESENTATION_PARTICLE_NODE_COUNT,
		"particle_nodes_new": particle_node_count,
		"behavior_rows": behavior_rows,
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


func get_validation_errors() -> PackedStringArray:
	var errors := get_resolver_backed_errors()
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


func _is_fire_authorized() -> bool:
	# The encounter's authorization first, then this craft's own arc. Both are
	# re-asked on the dispatch frame; neither is cached from the charge frame.
	return super() and _is_firing_arc_open()


# ----------------------------------------------------------- presentation ----

func _assign_wing_role_internal(role: StringName) -> void:
	var next := role if WingCoordinator.ROLES.has(role) else WingCoordinator.ROLE_UNASSIGNED
	if _wing_role == next:
		return
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
	if is_instance_valid(_muzzle_lens):
		_muzzle_lens.visible = _active and not _weapon_safed
	if is_instance_valid(_warning_light) and _weapon_safed:
		_warning_light.light_energy = 0.0


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
	_wedge(_visual_root, "DeltaNose", Vector3(0.0, 0.0, -1.9), Vector3(2.6, 0.72, 4.2), _materials.skirmisher_hull)
	_wedge(_visual_root, "DeltaBody", Vector3(0.0, -0.02, 0.9), Vector3(3.4, 0.86, 3.6), _materials.skirmisher_hull)
	_box(_visual_root, "Keelplate", Vector3(0.0, -0.44, 0.6), Vector3(2.2, 0.24, 4.4), _materials.skirmisher_deep)
	_wedge(_visual_root, "Canopy", Vector3(0.0, 0.44, -1.0), Vector3(1.05, 0.5, 1.9), _materials.glass)
	_box(_visual_root, "SpineFairing", Vector3(0.0, 0.42, 1.1), Vector3(0.62, 0.36, 2.6), _materials.skirmisher_moss)

	_wing_chalk_band_mesh = _make_box_mesh(WING_CHALK_BAND_SIZE, _materials.skirmisher_chalk)
	for side in [-1.0, 1.0]:
		_wedge(_visual_root, "Wing", Vector3(side * 2.4, -0.06, 1.0), Vector3(3.0, 0.22, 3.8), _materials.skirmisher_moss, side * 0.06)
		_box_from_mesh(_visual_root, "WingChalkBand", Vector3(side * 2.5, 0.06, 0.4), _wing_chalk_band_mesh)
		_box(_visual_root, "WingletFin", Vector3(side * 3.7, 0.36, 1.9), Vector3(0.16, 0.9, 1.3), _materials.skirmisher_chalk, Vector3(0.0, side * 0.16, side * -0.22))
		_cylinder(_visual_root, "EnginePod", Vector3(side * 1.0, -0.02, 2.5), 0.36, 1.3, _materials.skirmisher_deep, Vector3(90.0, 0.0, 0.0))
		var plume := _cylinder(_visual_root, "EnginePlume", Vector3(side * 1.0, -0.02, 3.42), 0.2, 0.8, _materials.skirmisher_engine, Vector3(90.0, 0.0, 0.0))
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

	_build_collision()
	_build_damage_effects()


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
	add_child(_damage_sparks)
	_damage_smoke = _make_smoke_particles(false)
	_damage_smoke.name = "EngineSmoke"
	_damage_smoke.position = Vector3(-1.0, 0.06, 2.9)
	_damage_smoke.emitting = false
	add_child(_damage_smoke)


func _create_skirmisher_materials() -> void:
	_materials.skirmisher_hull = _material(HULL_BASALT, 0.36, 0.44)
	_materials.skirmisher_moss = _material(HULL_MOSS, 0.34, 0.48)
	_materials.skirmisher_chalk = _material(HULL_CHALK, 0.22, 0.5)
	_materials.skirmisher_deep = _material(Color("161d20"), 0.6, 0.3)
	_materials.skirmisher_engine = _material(SKIRMISHER_ENGINE, 0.08, 0.2, SKIRMISHER_ENGINE, 2.6)
	_materials.skirmisher_muzzle = _material(ROLE_ANCHOR_LAMP, 0.12, 0.22, ROLE_ANCHOR_LAMP, 2.6)
	# A per-instance lamp material: the two craft in a wing show different roles
	# at the same moment, so this must not be shared between them.
	# Authored with emission already enabled: `_apply_role_presentation()` only
	# retints and re-energises it, and a material whose emission was never
	# enabled would silently ignore both.
	_materials.skirmisher_role_lamp = _material(ROLE_ANCHOR_LAMP, 0.1, 0.2, ROLE_ANCHOR_LAMP, 3.4)
