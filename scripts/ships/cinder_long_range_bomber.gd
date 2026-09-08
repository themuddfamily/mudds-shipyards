class_name CinderLongRangeBomber
extends HeroShip

## Original-modern long-range bomber component. No historical craft, weapon,
## payload, or mission claim is authenticated here.

const PayloadAuthority := preload("res://scripts/combat/bomber_payload_authority.gd")
const PayloadPresentation := preload("res://scripts/effects/bomber_payload_presentation.gd")
const ShipPerspectiveAudioBindingType := preload("res://scripts/audio/ship_perspective_audio_binding.gd")
const BomberPayloadAudioBindingType := preload("res://scripts/audio/bomber_payload_audio_binding.gd")
const ShipComponentDamageType := preload("res://scripts/combat/ship_component_damage.gd")
const SHIP_DEFINITION_TEMPLATE: ShipDefinition = preload(
	"res://assets/ships/cinder_long_range_bomber_new_design.tres"
)

const SCHEMA_VERSION := 1
const COMPONENT_ID: StringName = &"cinder_long_range_bomber"
const EVIDENCE_STATUS: StringName = &"NEW"
const DISPLAY_NAME := "Cinder long-range bomber"
const PAYLOAD_HARDPOINT_COUNT := 4
const PAYLOAD_AUTHORITY_PEER_ID := 1
const PAYLOAD_AMMUNITION := 4
const PAYLOAD_COOLDOWN_SECONDS := 1.0
const PAYLOAD_ID: StringName = &"cinder_payload_alpha"
const PAYLOAD_WEAPON_ID: StringName = &"bomber_payload_release"
const PAYLOAD_PRESENTATION_ID: StringName = &"payload_release_flash"
const PAYLOAD_AUDIO_ID: StringName = &"payload_release_audio"
const HULL_SIZE := Vector3(7.0, 3.0, 15.5)
## Retain the cockpit support origin while its continuous shoulder ramps into
## the narrower pressure body. The platform seats 20 mm into the fixed floor.
const COCKPIT_SUPPORT_FAIRING_POSITION := Vector3(0.0, 1.685, -0.55)
const ORDNANCE_SPINE_SIZE := Vector3(2.2, 1.25, 8.4)
const ORDNANCE_SPINE_POSITION := Vector3(0.0, -0.15, 1.5)
const STRIKE_WING_SIZE := Vector3(5.0, 0.3, 6.2)
const STRIKE_WING_OFFSET := Vector3(5.15, -0.45, 0.65)
const STRIKE_WING_SWEEP_DEGREES := 12.0
## A compact twin-fin empennage breaks up the otherwise slab-like aft profile
## from the normal chase distance. Every part stays inside the current wing and
## hull footprint, so this presentation cue does not change berth fit.
const AFT_TAILPLANE_SIZE := Vector3(8.6, 0.22, 2.9)
const AFT_TAILPLANE_POSITION := Vector3(0.0, 0.2, 5.3)
const AFT_FIN_SIZE := Vector3(0.34, 2.2, 3.3)
const AFT_FIN_OFFSET := Vector3(2.3, 1.25, 5.35)
const AFT_FIN_CANT_DEGREES := 12.0
const SENSOR_RADIUS := 0.62
const SENSOR_HEIGHT := 1.24
const SENSOR_POSITION := Vector3(0.0, 1.44, -5.2)
const SENSOR_SCALE := Vector3(1.0, 0.60, 1.0)
## The dorsal sensor remains visible to chase/world cameras, but its placement
## intersects the physical pilot's forward framing. A dedicated presentation
## layer lets the cockpit omit only this exterior emitter without moving it or
## changing the bomber silhouette seen by every exterior camera.
const EXTERIOR_SENSOR_VISUAL_LAYER := 1 << 1
const HULL_COLOR := Color("3e4d57")
const ORDNANCE_COLOR := Color("444d50")
const SENSOR_COLOR := Color("17272e")
## Static presentation of an already-authoritative starboard-wing stage. The
## raised vane sits on the bomber's outboard upper surface, where the chase view
## sees both its hot face and its silhouette without crossing the central aim,
## cockpit, boarding, or payload lanes.
const DAMAGE_CUE_COMPONENT_ID: StringName = &"starboard_wing"
const DAMAGE_CUE_POSITION := Vector3(5.15, -0.45, 0.65)
const DAMAGE_CUE_ROTATION_DEGREES := Vector3(0.0, 12.0, 0.0)
const DAMAGE_SCORCH_SIZE := Vector3(2.6, 0.06, 2.4)
const DAMAGE_SCORCH_POSITION := Vector3(0.0, 0.18, 0.0)
const DAMAGE_VANE_SIZE := Vector3(0.22, 0.66, 2.2)
const DAMAGE_VANE_POSITION := Vector3(0.0, 0.51, 0.0)
## A failed wing keeps the same retained vane but drops and cants it outboard.
## The silhouette break is readable without its hot material, while remaining
## clear of the cockpit, payload and boarding corridors.
const DAMAGE_VANE_FAILED_POSITION := Vector3(0.34, 0.36, 0.12)
const DAMAGE_VANE_FAILED_ROTATION_DEGREES := Vector3(0.0, 0.0, -28.0)
const DAMAGE_SCORCH_COLOR := Color("171b1d")
const DAMAGE_VANE_COLOR := Color("ff6a36")

# The primary hull, painted ordnance spine and sensor are immutable presentation stock.
# Production may briefly own more than one bomber during fleet composition or
# replacement, so retain one process-local recipe instead of allocating the
# same meshes and materials for every copy. Renderer nodes, submissions,
# transforms and physical authority remain per craft.
static var _shared_hull_mesh: ArrayMesh
static var _shared_hull_material: StandardMaterial3D
static var _shared_cockpit_support_fairing_mesh: ArrayMesh
static var _shared_ordnance_spine_mesh: ArrayMesh
static var _shared_ordnance_spine_material: StandardMaterial3D
static var _shared_strike_wing_mesh: ArrayMesh
static var _shared_strike_wing_multimesh: MultiMesh
static var _shared_aft_tailplane_mesh: ArrayMesh
static var _shared_aft_fin_mesh: ArrayMesh
static var _shared_sensor_mesh: SphereMesh
static var _shared_sensor_material: StandardMaterial3D
static var _shared_damage_scorch_mesh: BoxMesh
static var _shared_damage_scorch_material: StandardMaterial3D
static var _shared_damage_vane_mesh: BoxMesh
static var _shared_damage_vane_material: StandardMaterial3D

var _bomber_boarding_marker: Marker3D
var _payload_hardpoints: Array[Marker3D] = []
var _bomber_built := false
var _payload_authority: BomberPayloadAuthority
var _payload_presentation
var _ship_perspective_audio_binding: RefCounted
var _payload_audio_binding: Node
var _component_damage_cue: Node3D


func _init() -> void:
	_payload_authority = PayloadAuthority.new(
		PAYLOAD_AUTHORITY_PEER_ID,
		PAYLOAD_AMMUNITION,
		PAYLOAD_COOLDOWN_SECONDS
	)


# This hull has no authored idle cannon lens. A shot-clearance marker is
# gameplay authority, not a mounting surface for a permanent cyan sphere.
func _uses_weapon_component_fallback_emitters() -> bool:
	return false


func _uses_torrent_reconstruction_presentation() -> bool:
	return false


func _uses_inherited_primary_weapon() -> bool:
	return false


## Cinder's primary action is the caller-owned payload admission seam. Keep the
## inherited pulse cannon unreachable even if a legacy/internal caller invokes
## the old method directly instead of entering the normal HeroShip physics gate.
func _fire_weapon() -> void:
	pass


func _enter_tree() -> void:
	super._enter_tree()
	if _ship_perspective_audio_binding != null:
		call_deferred("_rebind_cinder_perspective_audio")
	if _payload_audio_binding != null:
		call_deferred("_rebind_cinder_payload_audio")


func _ready() -> void:
	# FleetExpansionProductionBinding instantiates this script directly, so apply
	# the authored flight/systems profile before HeroShip snapshots hull and
	# handling state. Keep the Resource instance local to this craft lifecycle.
	ship_definition = SHIP_DEFINITION_TEMPLATE.duplicate(true) as ShipDefinition
	ship_id = COMPONENT_ID
	display_name = DISPLAY_NAME
	role_name = "Long-range bomber"
	set_meta(&"component_id", COMPONENT_ID)
	set_meta(&"evidence_status", EVIDENCE_STATUS)
	set_meta(&"historically_supported", false)
	super._ready()
	_ship_perspective_audio_binding = ShipPerspectiveAudioBindingType.new()
	var perspective_result: Dictionary = _ship_perspective_audio_binding.bind(_ship_audio_rig)
	if bool(perspective_result.get("accepted", false)):
		camera_view_changed.connect(_on_cinder_camera_view_changed)
	else:
		_ship_perspective_audio_binding = null
	if not _bomber_built:
		_bomber_built = rebuild_variant_presentation(_build_bomber_variant)
	if not component_damage_changed.is_connected(_on_bomber_component_damage_changed):
		component_damage_changed.connect(_on_bomber_component_damage_changed)
	_sync_component_damage_cue()
	_build_payload_presentation()
	_build_payload_audio_binding()


func _exit_tree() -> void:
	if _ship_perspective_audio_binding != null:
		if camera_view_changed.is_connected(_on_cinder_camera_view_changed):
			camera_view_changed.disconnect(_on_cinder_camera_view_changed)
		_ship_perspective_audio_binding.detach()
	if _payload_audio_binding != null:
		_payload_audio_binding.detach()
	super._exit_tree()

func _rebind_cinder_payload_audio() -> void:
	if not is_inside_tree() or _payload_audio_binding == null:
		return
	var snapshot: Dictionary = _payload_audio_binding.get_snapshot()
	if not bool(snapshot.get("attached", false)):
		_payload_audio_binding.attach(int(snapshot.get("generation", 0)))


func _rebind_cinder_perspective_audio() -> void:
	if not is_inside_tree() or _ship_perspective_audio_binding == null \
			or _ship_audio_rig == null or not is_instance_valid(_ship_audio_rig):
		return
	var snapshot: Dictionary = _ship_perspective_audio_binding.get_snapshot()
	if bool(snapshot.get("attached", false)):
		return
	var result: Dictionary = _ship_perspective_audio_binding.bind(_ship_audio_rig)
	if bool(result.get("accepted", false)) \
			and not camera_view_changed.is_connected(_on_cinder_camera_view_changed):
		camera_view_changed.connect(_on_cinder_camera_view_changed)


func _on_cinder_camera_view_changed(view: StringName) -> void:
	if _ship_perspective_audio_binding == null:
		return
	var perspective: StringName = &"cockpit" if view == CAMERA_VIEW_COCKPIT else &"exterior"
	var generation := int(_ship_perspective_audio_binding.get_snapshot().get("generation", -1))
	_ship_perspective_audio_binding.present_perspective(perspective, generation)


func get_ship_perspective_audio_snapshot() -> Dictionary:
	return _ship_perspective_audio_binding.get_snapshot() \
		if _ship_perspective_audio_binding != null else {"attached": false}


func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	if _reset_for_reuse_mutation_blocked():
		return
	if _payload_authority != null:
		_payload_authority.advance(maxf(delta, 0.0))
	if is_instance_valid(_payload_presentation):
		_payload_presentation.advance_simulation(maxf(delta, 0.0))


func _commit_variant_reset_for_reuse(context: Dictionary) -> void:
	super._commit_variant_reset_for_reuse(context)
	_sync_component_damage_cue()
	if _payload_authority != null and bool(_payload_authority.get_snapshot().get("active", false)):
		_payload_authority.detach(&"ship_reused")
	if is_instance_valid(_payload_presentation):
		_payload_presentation.detach()
	if _payload_audio_binding != null:
		var audio_snapshot: Dictionary = _payload_audio_binding.get_snapshot()
		if bool(audio_snapshot.get("attached", false)):
			_payload_audio_binding.detach()


func _build_bomber_variant(_controller: HeroShip) -> bool:
	var visual := get_variant_visual_root()
	if visual == null:
		return false
	visual.name = "CinderBomberVisual"
	visual.set_meta(&"geometry_status", EVIDENCE_STATUS)
	visual.set_meta(&"historically_supported", false)
	_build_hull(visual)
	_build_cockpit_support_fairing(visual)
	_build_strike_wings(visual)
	_build_aft_empennage(visual)
	_build_cockpit_and_boarding(visual)
	_build_payload_hardpoints(visual)
	_build_component_damage_cue(visual)
	return true


func get_display_name() -> String:
	return DISPLAY_NAME


func get_cockpit_seat_anchor() -> Marker3D:
	return get_pilot_seat_anchor() as Marker3D


func get_boarding_marker() -> Marker3D:
	return _bomber_boarding_marker


func get_payload_hardpoints() -> Array[Marker3D]:
	return _payload_hardpoints.duplicate()


## Starts the caller-owned payload admission lifecycle. Cinder does not infer a
## generation from scene entry; its session/shipyard owner must provide one.
func begin_payload_generation(generation: int) -> Dictionary:
	var result := _payload_authority.begin_generation(generation)
	if bool(result.get("accepted", false)):
		_sync_payload_audio_generation(generation)
	return result


## Re-enters payload admission after explicit detach or HeroShip reuse cleanup.
func reset_payload_for_reuse(generation: int) -> Dictionary:
	var result := _payload_authority.reset_for_reuse(generation)
	if bool(result.get("accepted", false)) and is_instance_valid(_payload_presentation):
		_payload_presentation.reset_for_reuse()
	if bool(result.get("accepted", false)):
		_sync_payload_audio_generation(generation)
	return result


func detach_payload_authority(reason: StringName = &"detached") -> Dictionary:
	var result := _payload_authority.detach(reason)
	if bool(result.get("accepted", false)) and is_instance_valid(_payload_presentation):
		_payload_presentation.detach()
	if bool(result.get("accepted", false)) and _payload_audio_binding != null:
		_payload_audio_binding.detach()
	return result


func advance_payload_cooldown(delta: float) -> Dictionary:
	return _payload_authority.advance(delta)


func get_payload_authority_snapshot() -> Dictionary:
	return _payload_authority.get_snapshot()


## The physical cockpit is a presentation consumer of the existing payload
## snapshot. It neither advances cooldown nor submits a release intent, and it
## deliberately never falls back to HeroShip's inherited cannon heat language.
func _get_cockpit_system_readout() -> Dictionary:
	var payload := get_payload_authority_snapshot()
	var active := bool(payload.get("active", false))
	var ammunition := maxi(0, int(payload.get("ammunition_remaining", 0)))
	var cooldown := maxf(0.0, float(payload.get("cooldown_remaining", 0.0)))
	if not active:
		return {
			"text": "PAYLOAD OFFLINE  //  AMMO %d  //  RELEASE LOCKED" % ammunition,
			"color": Color("ff6b5f"),
		}.duplicate(true)
	if ammunition <= 0:
		return {
			"text": "PAYLOAD EMPTY  //  AMMO 0  //  RELEASE LOCKED",
			"color": Color("ff6b5f"),
		}.duplicate(true)
	if cooldown > 0.0:
		return {
			"text": "PAYLOAD COOLDOWN %.1fs  //  AMMO %d  //  RELEASE WAIT" % [
				cooldown,
				ammunition,
			],
			"color": Color("ffb85c"),
		}.duplicate(true)
	return {
		"text": "PAYLOAD READY  //  AMMO %d  //  RELEASE READY" % ammunition,
		"color": Color("8de8e4"),
	}.duplicate(true)


func get_payload_presentation():
	return _payload_presentation

func get_payload_audio_binding() -> Node:
	return _payload_audio_binding


## Presentation-only caller seam for graphics/accessibility composition. The
## bomber forwards policy but retains no settings, UI, or profile authority.
func set_payload_presentation_profile(
		payload_visual_intensity: StringName,
		reduced_flash: bool
) -> Dictionary:
	if not is_instance_valid(_payload_presentation):
		return {"accepted": false, "reason": &"payload_presentation_unavailable"}
	return _payload_presentation.apply_presentation_profile(payload_visual_intensity, reduced_flash)


## Mirrors one terminal record already emitted by BomberPayloadProjectile (and
## accepted by the caller's combat path) into the visual pool. Cinder neither
## submits collision evidence nor interprets target, damage, or scoring fields.
func present_payload_terminal_record(terminal_record: Dictionary) -> Dictionary:
	if not is_instance_valid(_payload_presentation):
		return {"accepted": false, "reason": &"payload_presentation_unavailable"}
	var result: Dictionary = _payload_presentation.consume_terminal_record(terminal_record)
	if bool(result.get("accepted", false)) and _payload_audio_binding != null:
		result["audio"] = _payload_audio_binding.present_projectile_terminal(terminal_record)
	return result


## Maps one authored hardpoint to a finite release pose and delegates all
## admission/resource/sequence checks to BomberPayloadAuthority. The returned
## record is unresolved; a later CombatResolver owns actual ordnance effects.
func request_payload_release(
		source_peer_id: int,
		actor_id: StringName,
		generation: int,
		request_sequence: int,
		hardpoint_index: int,
		release_velocity: Vector3,
		payload_id: StringName = PAYLOAD_ID,
		weapon_id: StringName = PAYLOAD_WEAPON_ID,
		presentation_id: StringName = PAYLOAD_PRESENTATION_ID,
		audio_id: StringName = PAYLOAD_AUDIO_ID
) -> Dictionary:
	if hardpoint_index < 0 or hardpoint_index >= _payload_hardpoints.size():
		return {"accepted": false, "reason": &"invalid_hardpoint"}
	var hardpoint := _payload_hardpoints[hardpoint_index]
	if not is_instance_valid(hardpoint):
		return {"accepted": false, "reason": &"hardpoint_unavailable"}
	var payload := {
		"generation": generation,
		"payload_id": payload_id,
		"weapon_id": weapon_id,
		"presentation_id": presentation_id,
		"audio_id": audio_id,
		"release_position": hardpoint.global_position,
		"release_velocity": release_velocity,
	}
	var result := _payload_authority.submit_release_intent(
		source_peer_id,
		actor_id,
		payload,
		request_sequence
	)
	if bool(result.get("accepted", false)):
		result["hardpoint_index"] = hardpoint_index
		result["presentation"] = (
			_payload_presentation.consume_release_record(result.get("record", {}) as Dictionary)
			if is_instance_valid(_payload_presentation)
			else {"accepted": false, "reason": &"payload_presentation_unavailable"}
		)
		if _payload_audio_binding != null:
			result["audio"] = _payload_audio_binding.present_release_record(result.get("record", {}) as Dictionary)
	return result.duplicate(true)


func get_audit_report() -> Dictionary:
	var errors := PackedStringArray()
	var hull_sharing := get_hull_resource_sharing_audit()
	var strike_wing_visual := get_strike_wing_visual_audit()
	var aft_empennage_visual := get_aft_empennage_visual_audit()
	var sensor_sharing := get_sensor_resource_sharing_audit()
	if not _bomber_built:
		errors.append("bomber has not built its authored component tree")
	if not is_instance_valid(get_pilot_seat_anchor()) or not is_instance_valid(_bomber_boarding_marker):
		errors.append("cockpit and boarding anchors are required")
	if _payload_hardpoints.size() != PAYLOAD_HARDPOINT_COUNT:
		errors.append("four caller-owned payload hardpoints are required")
	if _payload_authority == null or not _payload_authority.is_configuration_valid():
		errors.append("bomber payload admission authority is unavailable")
	if (
		not is_instance_valid(_payload_presentation)
		or _payload_presentation.get_parent() != self
		or not bool(_payload_presentation.get_audit_report().get("valid", false))
	):
		errors.append("bounded bomber payload presentation is unavailable")
	if not bool(get_landing_collision_report().get("valid", false)):
		errors.append("bomber requires HeroShip root collision")
	if not bool(hull_sharing.get("valid", false)):
		errors.append("bomber immutable primary visual resource sharing drifted")
	if not bool(strike_wing_visual.get("valid", false)):
		errors.append("bomber swept strike-wing silhouette drifted")
	if not bool(aft_empennage_visual.get("valid", false)):
		errors.append("bomber twin-fin aft silhouette drifted")
	if not bool(sensor_sharing.get("valid", false)):
		errors.append("bomber immutable sensor visual resource sharing drifted")
	if ship_definition == null \
			or not ship_definition.is_definition_valid() \
			or ship_definition.get_ship_id() != COMPONENT_ID:
		errors.append("authored bomber flight definition is not applied")
	return {
		"schema_version": SCHEMA_VERSION,
		"component_id": COMPONENT_ID,
		"evidence_status": EVIDENCE_STATUS,
		"historically_supported": false,
		"valid": errors.is_empty(),
		"errors": errors,
		"payload_hardpoint_count": _payload_hardpoints.size(),
		"hero_ship_derived": true,
		"flight_authority": true,
		"landing_authority": true,
		"damage_authority": true,
		"reuse_authority": true,
		"combat_authority": false,
		"ordnance_authority": false,
		"payload_admission_authority": true,
		"payload_records_unresolved": true,
		"payload_presentation_composed": is_instance_valid(_payload_presentation),
		"payload_presentation_authority": false,
		"berth_authority": false,
		"game_flow_authority": false,
		"network_authority": false,
		"hull_resource_sharing": hull_sharing,
		"strike_wing_visual": strike_wing_visual,
		"aft_empennage_visual": aft_empennage_visual,
		"sensor_resource_sharing": sensor_sharing,
	}.duplicate(true)


## Presentation-only silhouette recipe. The mirrored boxes are two immutable
## transforms in one MultiMesh submission; the batch owns no collision or
## gameplay children.
func get_strike_wing_visual_audit() -> Dictionary:
	var errors := PackedStringArray()
	var visual := get_variant_visual_root()
	var batch := visual.get_node_or_null(^"StrikeWingBatch") as MultiMeshInstance3D \
			if visual != null else null
	if batch == null:
		errors.append("strike-wing batch renderer is missing")
	else:
		if not batch.transform.is_equal_approx(Transform3D.IDENTITY):
			errors.append("strike-wing batch root transform drifted")
		if not batch.visible \
				or batch.cast_shadow != GeometryInstance3D.SHADOW_CASTING_SETTING_ON:
			errors.append("strike-wing renderer state drifted")
		if batch.get_child_count() != 0 or batch.get_script() != null:
			errors.append("strike-wing batch gained semantic children or authority")
		if batch.multimesh != _shared_strike_wing_multimesh:
			errors.append("strike-wing immutable batch identity drifted")
		if batch.material_override != _shared_hull_material:
			errors.append("strike-wing shared hull material identity drifted")
	if _shared_strike_wing_multimesh == null:
		errors.append("strike-wing immutable batch recipe is missing")
	else:
		var expected_transforms := _strike_wing_instance_transforms()
		if _shared_strike_wing_multimesh.instance_count != 2 \
				or _shared_strike_wing_multimesh.mesh != _shared_strike_wing_mesh:
			errors.append("strike-wing batch instance recipe drifted")
		if _shared_strike_wing_multimesh.buffer \
				!= _encode_strike_wing_transforms(expected_transforms):
			errors.append("strike-wing mirrored sweep buffer drifted")
		if not _shared_strike_wing_multimesh.custom_aabb.is_equal_approx(
			_strike_wing_bounds(expected_transforms)
		):
			errors.append("strike-wing batch culling bounds drifted")
		if _shared_strike_wing_multimesh.resource_local_to_scene:
			errors.append("strike-wing batch became scene-local")
	if _shared_strike_wing_mesh == null \
			or not _shared_strike_wing_mesh.get_aabb().size.is_equal_approx(STRIKE_WING_SIZE) \
			or _shared_strike_wing_mesh.resource_local_to_scene:
		errors.append("strike-wing mesh recipe drifted")
	return {
		"valid": errors.is_empty(),
		"errors": errors,
		"renderer_nodes_per_copy": 1 if batch != null else 0,
		"geometry_submissions_per_copy": 1 if batch != null else 0,
		"visible_instances_per_copy": _shared_strike_wing_multimesh.instance_count \
				if _shared_strike_wing_multimesh != null else 0,
		"shared_mesh_resource_id": _shared_strike_wing_mesh.get_instance_id() \
				if _shared_strike_wing_mesh != null else 0,
		"shared_multimesh_resource_id": _shared_strike_wing_multimesh.get_instance_id() \
				if _shared_strike_wing_multimesh != null else 0,
		"shared_hull_material_resource_id": _shared_hull_material.get_instance_id() \
				if _shared_hull_material != null else 0,
		"legacy_per_copy": {
			"renderer_nodes": 2,
			"geometry_submissions": 2,
			"visible_instances": 2,
		},
		"current_per_copy": {
			"renderer_nodes": 1 if batch != null else 0,
			"geometry_submissions": 1 if batch != null else 0,
			"visible_instances": _shared_strike_wing_multimesh.instance_count \
					if _shared_strike_wing_multimesh != null else 0,
		},
	}.duplicate(true)


## Presentation-only bomber recognition cue. The three renderers stay inside
## the existing visual footprint and share immutable stock across craft copies;
## they add no lights, collision, hardpoints, scripts, or gameplay authority.
func get_aft_empennage_visual_audit() -> Dictionary:
	var errors := PackedStringArray()
	var visual := get_variant_visual_root()
	var tailplane := visual.get_node_or_null(^"LongRangeTailplane") as MeshInstance3D \
			if visual != null else null
	var port_fin := visual.get_node_or_null(^"PortBomberFin") as MeshInstance3D \
			if visual != null else null
	var starboard_fin := visual.get_node_or_null(^"StarboardBomberFin") as MeshInstance3D \
			if visual != null else null
	if tailplane == null:
		errors.append("aft tailplane renderer is missing")
	else:
		if not tailplane.position.is_equal_approx(AFT_TAILPLANE_POSITION):
			errors.append("aft tailplane placement drifted")
		if tailplane.mesh != _shared_aft_tailplane_mesh \
				or tailplane.material_override != _shared_hull_material:
			errors.append("aft tailplane immutable resource identity drifted")
		if not tailplane.visible \
				or tailplane.cast_shadow != GeometryInstance3D.SHADOW_CASTING_SETTING_ON:
			errors.append("aft tailplane renderer state drifted")
		if tailplane.get_child_count() != 0 or tailplane.get_script() != null:
			errors.append("aft tailplane gained semantic children or authority")
	for entry in [
		[port_fin, -AFT_FIN_OFFSET.x, AFT_FIN_CANT_DEGREES],
		[starboard_fin, AFT_FIN_OFFSET.x, -AFT_FIN_CANT_DEGREES],
	]:
		var fin := entry[0] as MeshInstance3D
		if fin == null:
			errors.append("aft bomber-fin renderer is missing")
			continue
		var expected_position := Vector3(float(entry[1]), AFT_FIN_OFFSET.y, AFT_FIN_OFFSET.z)
		if not fin.position.is_equal_approx(expected_position) \
				or not is_equal_approx(fin.rotation_degrees.z, float(entry[2])):
			errors.append("aft bomber-fin mirrored cant drifted")
		if fin.mesh != _shared_aft_fin_mesh \
				or fin.material_override != _shared_ordnance_spine_material:
			errors.append("aft bomber-fin immutable resource identity drifted")
		if not fin.visible or fin.cast_shadow != GeometryInstance3D.SHADOW_CASTING_SETTING_ON:
			errors.append("aft bomber-fin renderer state drifted")
		if fin.get_child_count() != 0 or fin.get_script() != null:
			errors.append("aft bomber fin gained semantic children or authority")
	if _shared_aft_tailplane_mesh == null \
			or not _shared_aft_tailplane_mesh.get_aabb().size.is_equal_approx(AFT_TAILPLANE_SIZE) \
			or _shared_aft_tailplane_mesh.resource_local_to_scene:
		errors.append("aft tailplane mesh recipe drifted")
	if _shared_aft_fin_mesh == null \
			or not _shared_aft_fin_mesh.get_aabb().size.is_equal_approx(AFT_FIN_SIZE) \
			or _shared_aft_fin_mesh.resource_local_to_scene:
		errors.append("aft bomber-fin mesh recipe drifted")
	return {
		"valid": errors.is_empty(),
		"errors": errors,
		"renderer_nodes_per_copy": int(tailplane != null) + int(port_fin != null) + int(starboard_fin != null),
		"geometry_submissions_per_copy": 3 if tailplane != null and port_fin != null and starboard_fin != null else 0,
		"tailplane_mesh_resource_id": _shared_aft_tailplane_mesh.get_instance_id() \
				if _shared_aft_tailplane_mesh != null else 0,
		"fin_mesh_resource_id": _shared_aft_fin_mesh.get_instance_id() \
				if _shared_aft_fin_mesh != null else 0,
		"hull_material_resource_id": _shared_hull_material.get_instance_id() \
				if _shared_hull_material != null else 0,
		"ordnance_material_resource_id": _shared_ordnance_spine_material.get_instance_id() \
				if _shared_ordnance_spine_material != null else 0,
		"lights": 0,
		"collision_shapes": 0,
		"payload_hardpoints": 0,
		"gameplay_authority": false,
	}.duplicate(true)


## Detached exact-recipe evidence for the cross-copy cached primary visual stock.
## Structural submissions are mesh surfaces, not a driver draw-call claim.
func get_hull_resource_sharing_audit() -> Dictionary:
	var errors := PackedStringArray()
	var visual := get_variant_visual_root()
	var hull := visual.get_node_or_null(^"LongRangeHull") as MeshInstance3D if visual != null else null
	var mesh := hull.mesh as ArrayMesh if hull != null else null
	var material := hull.material_override as StandardMaterial3D if hull != null else null
	var ordnance := visual.get_node_or_null(^"OrdnanceSpine") as MeshInstance3D if visual != null else null
	var ordnance_mesh := ordnance.mesh as ArrayMesh if ordnance != null else null
	var ordnance_material := ordnance.material_override as StandardMaterial3D if ordnance != null else null
	if hull == null:
		errors.append("LongRangeHull renderer is missing")
	else:
		if not hull.transform.is_equal_approx(Transform3D.IDENTITY):
			errors.append("LongRangeHull transform drifted")
		if not hull.visible or hull.cast_shadow != GeometryInstance3D.SHADOW_CASTING_SETTING_ON:
			errors.append("LongRangeHull renderer state drifted")
		if hull.get_child_count() != 0 or hull.get_script() != null:
			errors.append("LongRangeHull gained semantic children or authority")
	if mesh == null or mesh != _shared_hull_mesh:
		errors.append("LongRangeHull shared mesh identity drifted")
	elif not mesh.get_aabb().size.is_equal_approx(Vector3(5.6, 2.65, HULL_SIZE.z)) or mesh.get_surface_count() != 1:
		errors.append("LongRangeHull mesh recipe drifted")
	elif mesh.resource_local_to_scene:
		errors.append("LongRangeHull mesh became scene-local")
	if material == null or material != _shared_hull_material:
		errors.append("LongRangeHull shared material identity drifted")
	elif (
		not material.albedo_color.is_equal_approx(HULL_COLOR)
		or not is_equal_approx(material.metallic, 0.12)
		or not is_equal_approx(material.roughness, 0.62)
		or material.resource_local_to_scene
	):
		errors.append("LongRangeHull material recipe drifted")
	if ordnance == null:
		errors.append("OrdnanceSpine renderer is missing")
	else:
		var expected_transform := Transform3D(Basis.IDENTITY, ORDNANCE_SPINE_POSITION)
		if not ordnance.transform.is_equal_approx(expected_transform):
			errors.append("OrdnanceSpine transform drifted")
		if not ordnance.visible \
				or ordnance.cast_shadow != GeometryInstance3D.SHADOW_CASTING_SETTING_ON:
			errors.append("OrdnanceSpine renderer state drifted")
		if ordnance.get_child_count() != 0 or ordnance.get_script() != null:
			errors.append("OrdnanceSpine gained semantic children or authority")
	if ordnance_mesh == null or ordnance_mesh != _shared_ordnance_spine_mesh:
		errors.append("OrdnanceSpine shared mesh identity drifted")
	elif not ordnance_mesh.get_aabb().size.is_equal_approx(ORDNANCE_SPINE_SIZE) \
			or ordnance_mesh.get_surface_count() != 1:
		errors.append("OrdnanceSpine mesh recipe drifted")
	elif ordnance_mesh.resource_local_to_scene:
		errors.append("OrdnanceSpine mesh became scene-local")
	if ordnance_material == null or ordnance_material != _shared_ordnance_spine_material:
		errors.append("OrdnanceSpine shared material identity drifted")
	elif (
		not ordnance_material.albedo_color.is_equal_approx(ORDNANCE_COLOR)
		or not is_equal_approx(ordnance_material.metallic, 0.12)
		or not is_equal_approx(ordnance_material.roughness, 0.62)
		or ordnance_material.resource_local_to_scene
	):
		errors.append("OrdnanceSpine material recipe drifted")
	return {
		"valid": errors.is_empty(),
		"errors": errors,
		"family": &"LongRangeHull",
		"renderer_nodes_per_copy": 1 if hull != null else 0,
		"geometry_submissions_per_copy": mesh.get_surface_count() if mesh != null else 0,
		"visible_copies_per_bomber": 1 if hull != null and hull.visible else 0,
		"mesh_resource_id": mesh.get_instance_id() if mesh != null else 0,
		"material_resource_id": material.get_instance_id() if material != null else 0,
		"legacy_two_copy": {
			"renderer_nodes": 2,
			"geometry_submissions": 2,
			"unique_mesh_resources": 2,
			"unique_material_resources": 2,
		},
		"current_two_copy": {
			"renderer_nodes": 2,
			"geometry_submissions": 2,
			"unique_mesh_resources": 1,
			"unique_material_resources": 1,
		},
		"ordnance_spine": {
			"renderer_nodes_per_copy": 1 if ordnance != null else 0,
			"geometry_submissions_per_copy": ordnance_mesh.get_surface_count() \
				if ordnance_mesh != null else 0,
			"visible_copies_per_bomber": 1 if ordnance != null and ordnance.visible else 0,
			"mesh_resource_id": ordnance_mesh.get_instance_id() if ordnance_mesh != null else 0,
			"material_resource_id": ordnance_material.get_instance_id() \
				if ordnance_material != null else 0,
			"legacy_two_copy": {
				"renderer_nodes": 2,
				"geometry_submissions": 2,
				"unique_mesh_resources": 2,
				"unique_material_resources": 2,
			},
			"current_two_copy": {
				"renderer_nodes": 2,
				"geometry_submissions": 2,
				"unique_mesh_resources": 1,
				"unique_material_resources": 1,
			},
		},
	}.duplicate(true)


## Detached exact-recipe evidence for the cross-copy cached sensor visual stock.
## Each craft retains its own renderer and structural surface submission.
func get_sensor_resource_sharing_audit() -> Dictionary:
	var errors := PackedStringArray()
	var visual := get_variant_visual_root()
	var sensor := visual.get_node_or_null(^"LongRangeSensor") as MeshInstance3D \
			if visual != null else null
	var mesh := sensor.mesh as SphereMesh if sensor != null else null
	var material := sensor.material_override as StandardMaterial3D if sensor != null else null
	if sensor == null:
		errors.append("LongRangeSensor renderer is missing")
	else:
		var expected_transform := Transform3D(Basis.IDENTITY.scaled(SENSOR_SCALE), SENSOR_POSITION)
		if not sensor.transform.is_equal_approx(expected_transform):
			errors.append("LongRangeSensor transform drifted")
		if not sensor.visible \
				or sensor.cast_shadow != GeometryInstance3D.SHADOW_CASTING_SETTING_ON:
			errors.append("LongRangeSensor renderer state drifted")
		if sensor.layers != EXTERIOR_SENSOR_VISUAL_LAYER:
			errors.append("LongRangeSensor exterior camera layer drifted")
		if sensor.get_child_count() != 0 or sensor.get_script() != null:
			errors.append("LongRangeSensor gained semantic children or authority")
	if mesh == null or mesh != _shared_sensor_mesh:
		errors.append("LongRangeSensor shared mesh identity drifted")
	elif (
		not is_equal_approx(mesh.radius, SENSOR_RADIUS)
		or not is_equal_approx(mesh.height, SENSOR_HEIGHT)
		or mesh.get_surface_count() != 1
	):
		errors.append("LongRangeSensor mesh recipe drifted")
	elif mesh.resource_local_to_scene:
		errors.append("LongRangeSensor mesh became scene-local")
	if material == null or material != _shared_sensor_material:
		errors.append("LongRangeSensor shared material identity drifted")
	elif (
		not material.albedo_color.is_equal_approx(SENSOR_COLOR)
		or not is_equal_approx(material.metallic, 0.35)
		or not is_equal_approx(material.roughness, 0.24)
		or material.emission_enabled
		or material.resource_local_to_scene
	):
		errors.append("LongRangeSensor material recipe drifted")
	var cockpit_camera := find_child("CockpitCamera", true, false) as Camera3D
	var chase_camera := find_child("ShipCamera", true, false) as Camera3D
	var cockpit_omits_sensor := cockpit_camera != null \
		and (cockpit_camera.cull_mask & EXTERIOR_SENSOR_VISUAL_LAYER) == 0
	var chase_retains_sensor := chase_camera != null \
		and (chase_camera.cull_mask & EXTERIOR_SENSOR_VISUAL_LAYER) != 0
	if not cockpit_omits_sensor:
		errors.append("LongRangeSensor remains visible in cockpit camera")
	if not chase_retains_sensor:
		errors.append("LongRangeSensor disappeared from chase camera")
	return {
		"valid": errors.is_empty(),
		"errors": errors,
		"family": &"LongRangeSensor",
		"renderer_nodes_per_copy": 1 if sensor != null else 0,
		"geometry_submissions_per_copy": mesh.get_surface_count() if mesh != null else 0,
		"visible_copies_per_bomber": 1 if sensor != null and sensor.visible else 0,
		"mesh_resource_id": mesh.get_instance_id() if mesh != null else 0,
		"material_resource_id": material.get_instance_id() if material != null else 0,
		"cockpit_omits_sensor": cockpit_omits_sensor,
		"chase_retains_sensor": chase_retains_sensor,
		"legacy_two_copy": {
			"renderer_nodes": 2,
			"geometry_submissions": 2,
			"unique_mesh_resources": 2,
			"unique_material_resources": 2,
		},
		"current_two_copy": {
			"renderer_nodes": 2,
			"geometry_submissions": 2,
			"unique_mesh_resources": 1,
			"unique_material_resources": 1,
		},
	}.duplicate(true)


## Detached presentation snapshot. It reports the retained renderer state but
## offers no mutation seam into the component ledger or HeroShip recovery path.
func get_component_damage_cue_snapshot() -> Dictionary:
	var visual := get_variant_visual_root()
	var cue := visual.get_node_or_null(^"StarboardWingDamageCue") as Node3D \
			if visual != null else null
	var scorch := cue.get_node_or_null(^"DamageScorch") as MeshInstance3D \
			if cue != null else null
	var vane := cue.get_node_or_null(^"ExposedDamageVane") as MeshInstance3D \
			if cue != null else null
	var bounds := AABB()
	var has_bounds := false
	for renderer in [scorch, vane]:
		if renderer == null or renderer.mesh == null or cue == null:
			continue
		var renderer_bounds: AABB = cue.transform * renderer.transform * renderer.mesh.get_aabb()
		bounds = renderer_bounds if not has_bounds else bounds.merge(renderer_bounds)
		has_bounds = true
	var model := get_component_damage()
	return {
		"component_id": DAMAGE_CUE_COMPONENT_ID,
		"stage": ShipComponentDamageType.state_id_for(
			model.get_component_state(DAMAGE_CUE_COMPONENT_ID)
		) if model != null and model.is_configured() else &"unavailable",
		"visible": cue.visible if cue != null else false,
		"silhouette_pose": &"failed_outboard_canted" if vane != null \
			and not vane.rotation.is_zero_approx() else &"nominal_upright",
		"vane_local_transform": vane.transform if vane != null else Transform3D.IDENTITY,
		"local_bounds": bounds,
		"view_lane_clear": has_bounds and bounds.position.x > HULL_SIZE.x * 0.5,
		"renderer_nodes_per_copy": int(scorch != null) + int(vane != null),
		"geometry_submissions_per_copy": 2 if scorch != null and vane != null else 0,
		"mesh_resource_ids": PackedInt64Array([
			_shared_damage_scorch_mesh.get_instance_id() if _shared_damage_scorch_mesh != null else 0,
			_shared_damage_vane_mesh.get_instance_id() if _shared_damage_vane_mesh != null else 0,
		]),
		"material_resource_ids": PackedInt64Array([
			_shared_damage_scorch_material.get_instance_id() if _shared_damage_scorch_material != null else 0,
			_shared_damage_vane_material.get_instance_id() if _shared_damage_vane_material != null else 0,
		]),
		"processes": false,
		"flashes": false,
		"damage_authority": false,
		"repair_authority": false,
	}.duplicate(true)


func _build_payload_presentation() -> void:
	if is_instance_valid(_payload_presentation):
		return
	_payload_presentation = PayloadPresentation.new()
	_payload_presentation.name = "BomberPayloadPresentation"
	add_child(_payload_presentation)

func _build_payload_audio_binding() -> void:
	if is_instance_valid(_payload_audio_binding):
		return
	_payload_audio_binding = BomberPayloadAudioBindingType.new()
	_payload_audio_binding.name = "BomberPayloadAudioBinding"
	add_child(_payload_audio_binding)
	_payload_audio_binding.attach(0)

func _sync_payload_audio_generation(generation: int) -> void:
	if _payload_audio_binding == null:
		return
	var snapshot: Dictionary = _payload_audio_binding.get_snapshot()
	if bool(snapshot.get("attached", false)):
		_payload_audio_binding.detach()
		snapshot = _payload_audio_binding.get_snapshot()
	var current := int(snapshot.get("generation", 0))
	while current < generation:
		_payload_audio_binding.attach(current)
		_payload_audio_binding.detach()
		current = int(_payload_audio_binding.get_snapshot().get("generation", current + 1))
	if current == generation:
		_payload_audio_binding.attach(current)


func _build_collision() -> void:
	_add_box_collision_shape("BomberHullCollision", Vector3(0.0, 0.0, 0.0), HULL_SIZE)


func _build_hull(visual: Node3D) -> void:
	var sill_finish := _material(Color("586569"), 0.48, 0.42)
	for sill_name in ["PortSill", "StarboardSill"]:
		var sill := visual.find_child(sill_name, true, false) as MeshInstance3D
		if sill != null:
			sill.material_override = sill_finish
	var hull := MeshInstance3D.new()
	hull.name = "LongRangeHull"
	if _shared_hull_mesh == null:
		_shared_hull_mesh = _formed_pressure_mesh(Vector3(5.6, 2.65, HULL_SIZE.z), null)
		_shared_hull_mesh.resource_local_to_scene = false
	if _shared_hull_material == null:
		_shared_hull_material = _material(HULL_COLOR, 0.12, 0.62)
		ShipSurfaceDetail.bind_manufactured_paint(_shared_hull_material)
		_shared_hull_material.uv1_triplanar = true
		_shared_hull_material.uv1_scale = Vector3.ONE * 0.33
		_shared_hull_material.resource_local_to_scene = false
	hull.mesh = _shared_hull_mesh
	hull.material_override = _shared_hull_material
	visual.add_child(hull)
	var ordnance := MeshInstance3D.new()
	ordnance.name = "OrdnanceSpine"
	if _shared_ordnance_spine_mesh == null:
		_shared_ordnance_spine_mesh = _loft_mesh(ORDNANCE_SPINE_SIZE, null)
		_shared_ordnance_spine_mesh.resource_local_to_scene = false
	if _shared_ordnance_spine_material == null:
		_shared_ordnance_spine_material = _material(ORDNANCE_COLOR, 0.12, 0.62)
		_shared_ordnance_spine_material.resource_local_to_scene = false
	ordnance.mesh = _shared_ordnance_spine_mesh
	ordnance.position = ORDNANCE_SPINE_POSITION
	ordnance.material_override = _shared_ordnance_spine_material
	visual.add_child(ordnance)
	var sensor := MeshInstance3D.new()
	sensor.name = "LongRangeSensor"
	if _shared_sensor_mesh == null:
		_shared_sensor_mesh = SphereMesh.new()
		_shared_sensor_mesh.radius = SENSOR_RADIUS
		_shared_sensor_mesh.height = SENSOR_HEIGHT
		_shared_sensor_mesh.resource_local_to_scene = false
	if _shared_sensor_material == null:
		_shared_sensor_material = _material(SENSOR_COLOR, 0.35, 0.24)
		_shared_sensor_material.resource_local_to_scene = false
	sensor.mesh = _shared_sensor_mesh
	sensor.position = SENSOR_POSITION
	sensor.scale = SENSOR_SCALE
	sensor.material_override = _shared_sensor_material
	sensor.layers = EXTERIOR_SENSOR_VISUAL_LAYER
	visual.add_child(sensor)
	_build_bomber_propulsion(visual)
	for side in [-1.0, 1.0]:
		# The marking follows the rolled skin instead of its former flat flank.
		ShipSurfaceDetail.mark_surface(visual, "PressureHullRegistration" + str(side), "cinder-bomber", Vector3(side * 1.679, 1.672, -0.42), Vector2(2.2, 0.9), Vector3(side * 0.628, 0.779, 0), Vector3.UP, 0.32)
	ShipSurfaceDetail.mark_surface(visual, "PayloadServiceMark", "service", Vector3(0, 1.27, 5.8), Vector2(1.8, 0.9), Vector3(0, 1, 0.113), Vector3.FORWARD)


## Long paired propulsion trunks leave a centerline service valley and carry
## the swept wings into the pressure body without a rectangular butt joint.
func _build_bomber_propulsion(visual: Node3D) -> void:
	var ceramic := _material(Color("1e2931"), 0.62, 0.43)
	var metal := _material(Color("79848a"), 0.78, 0.30)
	for z in [2.0, 3.25, 4.5]:
		var plate := _pressure_panel(visual, "DorsalOrdnanceArmor" + str(z), Vector3(0, 1.355, z), 2.0, 2.35, 1.12, 0.05, ceramic)
		plate.rotation.x = PI * 0.5
	var sensor_cowl := _armor_shell(visual, "SensorProtectiveCowl", SENSOR_POSITION + Vector3(0, -0.02, 0.10), Vector3(1.75, 0.42, 1.85), ceramic)
	sensor_cowl.layers = EXTERIOR_SENSOR_VISUAL_LAYER
	var hot := _material(Color("799da5"), 0.4, 0.28, Color("70aec0"), 0.65)
	for side in [-1.0, 1.0]:
		var tag := "Port" if side < 0 else "Starboard"
		_service_bay(visual, tag + "ThermalService", Vector3(side * 2.3, 1.212, 2.6), 0.9, 2.1, _shared_hull_material, ceramic, metal)
		_armor_shell(visual, tag + "PressureShoulder", Vector3(side * 2.3, 0.28, 0.4), Vector3(1.85, 1.8, 12.8), _shared_hull_material, 0.0, _formed_pressure_mesh(Vector3(1.85, 1.8, 12.8), _shared_hull_material))
		_armor_shell(visual, tag + "WingRootFairing", Vector3(side * 3.9, -0.25, 1.2), Vector3(2.7, 0.58, 7.7), _shared_hull_material, side * -0.13, _formed_wing_root_mesh(side, _shared_hull_material))
		_armor_shell(visual, tag + "OutboardArmor", Vector3(side * 5.6, -0.22, 1.8), Vector3(1.6, 0.08, 3.2), _shared_ordnance_spine_material, side * -0.16)
		_cylinder(visual, tag + "TurbineCase", Vector3(side * 2.35, 0.1, 6.75), 0.92, 2.1, metal, Vector3(90, 0, 0))
		_frustum(visual, tag + "ExhaustBell", Vector3(side * 2.35, 0.1, 8.10), 1.0, 0.70, 0.70, ceramic, Vector3(90, 0, 0), false, false)
		_cylinder(visual, tag + "RecessedThroat", Vector3(side * 2.35, 0.1, 7.90), 0.62, 0.08, ceramic, Vector3(90, 0, 0))
		_engine_mechanics(visual, tag, Vector3(side * 2.35, 0.1, 8.31), 0.87, metal, ceramic, hot)
		for z in [-1.1, 0.2, 4.85]:
			_deck_plate(visual, tag + "EngineAccess" + str(z), Vector3(side * 2.3, 1.202, z), 1.1, 1.08, _shared_hull_material, ceramic)
		for i in 3:
			var z := -1.2 + float(i) * 1.52
			_deck_plate(visual, tag + "OrdnanceCover" + str(i), Vector3(side * 4.50, 0.058, z + 1.2), 0.82, 1.30, _shared_hull_material, ceramic)
		var intake := Node3D.new()
		intake.name = tag + "RamScoop"
		intake.position = Vector3(side * 2.3, 0.45, -5.55)
		intake.rotation.x = -PI * 0.5
		visual.add_child(intake)
		_service_bay(intake, "Scoop", Vector3.ZERO, 0.75, 0.80, metal, ceramic, ceramic)


func _build_cockpit_support_fairing(visual: Node3D) -> void:
	var fairing := MeshInstance3D.new()
	fairing.name = "CockpitSupportFairing"
	if _shared_cockpit_support_fairing_mesh == null:
		_shared_cockpit_support_fairing_mesh = _cockpit_shoulder_mesh(COCKPIT_SUPPORT_FAIRING_POSITION, 1.32, 3.9, null)
		_shared_cockpit_support_fairing_mesh.resource_local_to_scene = false
	fairing.mesh = _shared_cockpit_support_fairing_mesh
	fairing.position = COCKPIT_SUPPORT_FAIRING_POSITION
	fairing.material_override = _shared_hull_material
	fairing.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	visual.add_child(fairing)


func _build_strike_wings(visual: Node3D) -> void:
	if _shared_strike_wing_mesh == null:
		_shared_strike_wing_mesh = _loft_mesh(STRIKE_WING_SIZE, null)
		_shared_strike_wing_mesh.resource_local_to_scene = false
	if _shared_strike_wing_multimesh == null:
		var transforms := _strike_wing_instance_transforms()
		_shared_strike_wing_multimesh = MultiMesh.new()
		_shared_strike_wing_multimesh.transform_format = MultiMesh.TRANSFORM_3D
		_shared_strike_wing_multimesh.mesh = _shared_strike_wing_mesh
		_shared_strike_wing_multimesh.instance_count = 2
		_shared_strike_wing_multimesh.visible_instance_count = -1
		_shared_strike_wing_multimesh.buffer = _encode_strike_wing_transforms(transforms)
		_shared_strike_wing_multimesh.custom_aabb = _strike_wing_bounds(transforms)
		_shared_strike_wing_multimesh.resource_local_to_scene = false
	var wing_batch := MultiMeshInstance3D.new()
	wing_batch.name = "StrikeWingBatch"
	wing_batch.multimesh = _shared_strike_wing_multimesh
	wing_batch.material_override = _shared_hull_material
	wing_batch.set_meta(&"presentation_only", true)
	wing_batch.set_meta(&"authored_visual_names", PackedStringArray([
		"PortStrikeWing", "StarboardStrikeWing",
	]))
	wing_batch.set_meta(&"authored_instance_transforms", _strike_wing_instance_transforms())
	visual.add_child(wing_batch)


static func _strike_wing_instance_transforms() -> Array[Transform3D]:
	return [
		Transform3D(
			Basis(Vector3.UP, deg_to_rad(-STRIKE_WING_SWEEP_DEGREES)),
			Vector3(-STRIKE_WING_OFFSET.x, STRIKE_WING_OFFSET.y, STRIKE_WING_OFFSET.z)
		),
		Transform3D(
			Basis(Vector3.UP, deg_to_rad(STRIKE_WING_SWEEP_DEGREES)),
			STRIKE_WING_OFFSET
		),
	]


static func _encode_strike_wing_transforms(
		transforms: Array[Transform3D]
	) -> PackedFloat32Array:
	var buffer := PackedFloat32Array()
	buffer.resize(transforms.size() * 12)
	for index in transforms.size():
		var value := transforms[index]
		var offset := index * 12
		buffer[offset + 0] = value.basis.x.x
		buffer[offset + 1] = value.basis.y.x
		buffer[offset + 2] = value.basis.z.x
		buffer[offset + 3] = value.origin.x
		buffer[offset + 4] = value.basis.x.y
		buffer[offset + 5] = value.basis.y.y
		buffer[offset + 6] = value.basis.z.y
		buffer[offset + 7] = value.origin.y
		buffer[offset + 8] = value.basis.x.z
		buffer[offset + 9] = value.basis.y.z
		buffer[offset + 10] = value.basis.z.z
		buffer[offset + 11] = value.origin.z
	return buffer


static func _strike_wing_bounds(transforms: Array[Transform3D]) -> AABB:
	var mesh_bounds := AABB(-STRIKE_WING_SIZE * 0.5, STRIKE_WING_SIZE)
	var bounds := AABB()
	for index in transforms.size():
		var transformed := (transforms[index] * mesh_bounds).abs()
		bounds = transformed if index == 0 else bounds.merge(transformed)
	return bounds


func _build_aft_empennage(visual: Node3D) -> void:
	if _shared_aft_tailplane_mesh == null:
		_shared_aft_tailplane_mesh = _loft_mesh(AFT_TAILPLANE_SIZE, null)
		_shared_aft_tailplane_mesh.resource_local_to_scene = false
	var tailplane := MeshInstance3D.new()
	tailplane.name = "LongRangeTailplane"
	tailplane.mesh = _shared_aft_tailplane_mesh
	tailplane.position = AFT_TAILPLANE_POSITION
	tailplane.material_override = _shared_hull_material
	visual.add_child(tailplane)

	if _shared_aft_fin_mesh == null:
		_shared_aft_fin_mesh = _loft_mesh(AFT_FIN_SIZE, null)
		_shared_aft_fin_mesh.resource_local_to_scene = false
	for entry in [
		["PortBomberFin", -AFT_FIN_OFFSET.x, AFT_FIN_CANT_DEGREES],
		["StarboardBomberFin", AFT_FIN_OFFSET.x, -AFT_FIN_CANT_DEGREES],
	]:
		var fin := MeshInstance3D.new()
		fin.name = entry[0]
		fin.mesh = _shared_aft_fin_mesh
		fin.position = Vector3(float(entry[1]), AFT_FIN_OFFSET.y, AFT_FIN_OFFSET.z)
		fin.rotation_degrees.z = float(entry[2])
		fin.material_override = _shared_ordnance_spine_material
		visual.add_child(fin)


func _build_component_damage_cue(visual: Node3D) -> void:
	_component_damage_cue = Node3D.new()
	_component_damage_cue.name = "StarboardWingDamageCue"
	_component_damage_cue.position = DAMAGE_CUE_POSITION
	_component_damage_cue.rotation_degrees = DAMAGE_CUE_ROTATION_DEGREES
	_component_damage_cue.process_mode = Node.PROCESS_MODE_DISABLED
	_component_damage_cue.set_meta(&"presentation_only", true)
	_component_damage_cue.set_meta(&"component_id", DAMAGE_CUE_COMPONENT_ID)
	_component_damage_cue.set_meta(&"damage_authority", false)
	_component_damage_cue.set_meta(&"repair_authority", false)
	visual.add_child(_component_damage_cue)

	if _shared_damage_scorch_mesh == null:
		_shared_damage_scorch_mesh = BoxMesh.new()
		_shared_damage_scorch_mesh.size = DAMAGE_SCORCH_SIZE
		_shared_damage_scorch_mesh.resource_local_to_scene = false
	if _shared_damage_scorch_material == null:
		_shared_damage_scorch_material = _material(DAMAGE_SCORCH_COLOR, 0.08, 0.92)
		_shared_damage_scorch_material.resource_local_to_scene = false
	var scorch := MeshInstance3D.new()
	scorch.name = "DamageScorch"
	scorch.mesh = _shared_damage_scorch_mesh
	scorch.material_override = _shared_damage_scorch_material
	scorch.position = DAMAGE_SCORCH_POSITION
	_component_damage_cue.add_child(scorch)

	if _shared_damage_vane_mesh == null:
		_shared_damage_vane_mesh = BoxMesh.new()
		_shared_damage_vane_mesh.size = DAMAGE_VANE_SIZE
		_shared_damage_vane_mesh.resource_local_to_scene = false
	if _shared_damage_vane_material == null:
		_shared_damage_vane_material = _material(
			DAMAGE_VANE_COLOR, 0.18, 0.38, DAMAGE_VANE_COLOR, 1.35
		)
		_shared_damage_vane_material.resource_local_to_scene = false
	var vane := MeshInstance3D.new()
	vane.name = "ExposedDamageVane"
	vane.mesh = _shared_damage_vane_mesh
	vane.material_override = _shared_damage_vane_material
	vane.position = DAMAGE_VANE_POSITION
	_component_damage_cue.add_child(vane)
	_component_damage_cue.visible = false


func _on_bomber_component_damage_changed(
		component_id: StringName,
		_state: int,
		_integrity: float
	) -> void:
	if component_id == DAMAGE_CUE_COMPONENT_ID:
		_sync_component_damage_cue()


func _sync_component_damage_cue() -> void:
	if not is_instance_valid(_component_damage_cue):
		return
	var model := get_component_damage()
	var state := model.get_component_state(DAMAGE_CUE_COMPONENT_ID) \
		if model != null and model.is_configured() \
		else ShipComponentDamageType.ComponentState.NOMINAL
	var vane := _component_damage_cue.get_node_or_null(^"ExposedDamageVane") as MeshInstance3D
	if vane != null:
		# Repair and pooling must restore the authored transform rather than merely
		# hiding a previously failed silhouette.
		vane.position = DAMAGE_VANE_POSITION
		vane.rotation = Vector3.ZERO
		if state == ShipComponentDamageType.ComponentState.FAILED:
			vane.position = DAMAGE_VANE_FAILED_POSITION
			vane.rotation_degrees = DAMAGE_VANE_FAILED_ROTATION_DEGREES
	_component_damage_cue.visible = model != null \
		and model.is_configured() \
		and state \
			!= ShipComponentDamageType.ComponentState.NOMINAL


func _build_cockpit_and_boarding(visual: Node3D) -> void:
	var instrument_cluster := visual.get_node_or_null(
		NodePath("CockpitInterior/InstrumentCluster")
	) as Node3D
	_install_variant_cockpit_system_readout(instrument_cluster)
	var cockpit_camera := visual.get_node_or_null(
		NodePath("CockpitInterior/CockpitCamera")
	) as Camera3D
	if cockpit_camera != null:
		cockpit_camera.cull_mask &= ~EXTERIOR_SENSOR_VISUAL_LAYER
	_bomber_boarding_marker = Marker3D.new()
	_bomber_boarding_marker.name = "BoardingMarker"
	_bomber_boarding_marker.position = Vector3(-3.8, -1.0, -0.5)
	_bomber_boarding_marker.set_meta(&"boarding_side", &"port")
	visual.add_child(_bomber_boarding_marker)


func _build_payload_hardpoints(visual: Node3D) -> void:
	for index in PAYLOAD_HARDPOINT_COUNT:
		var hardpoint := Marker3D.new()
		hardpoint.name = "PayloadHardpoint%02d" % (index + 1)
		hardpoint.position = Vector3(-1.55 if index % 2 == 0 else 1.55, -1.0, -2.4 + float(index / 2) * 4.8)
		hardpoint.set_meta(&"payload_slot_index", index)
		hardpoint.set_meta(&"ordnance_owner", COMPONENT_ID)
		visual.add_child(hardpoint)
		_payload_hardpoints.append(hardpoint)



## Chamfered pressure-shell stock reuses the inherited closed loft topology.
## Broad planar stations carry armor panels; corner facets catch a narrow edge
## highlight without inflating the entire silhouette like a superellipse.
func _loft_mesh(size: Vector3, material: Material) -> ArrayMesh:
	# Use the actual profile breaks as stations. The broad pressure faces
	# stay continuous between those breaks instead of introducing redundant
	# almost-coplanar strips along the manufactured edges.
	var section := PackedVector2Array([
		Vector2(0, 1), Vector2(0.94, 1), Vector2(1, 0.94), Vector2(1, 0.36),
		Vector2(1, 0), Vector2(1, -0.36), Vector2(1, -0.94), Vector2(0.94, -1),
		Vector2(0, -1), Vector2(-0.94, -1), Vector2(-1, -0.94), Vector2(-1, -0.36),
		Vector2(-1, 0), Vector2(-1, 0.36), Vector2(-1, 0.94), Vector2(-0.94, 1),
	])
	return _pressure_section_mesh(size, material, section)


## Broad crowns carry the existing access panels; formed shoulders roll down
## into the belly instead of ending in almost-square vertical walls. The nose
## and afterbody retain their existing stations, length and maximum envelope.
func _formed_pressure_mesh(size: Vector3, material: Material) -> ArrayMesh:
	return _pressure_section_mesh(size, material, PackedVector2Array([
		Vector2(0, 1), Vector2(0.60, 1), Vector2(0.82, 0.87), Vector2(0.96, 0.59),
		Vector2(1, 0.24), Vector2(0.97, -0.32), Vector2(0.81, -0.78), Vector2(0.52, -1),
		Vector2(0, -1), Vector2(-0.52, -1), Vector2(-0.81, -0.78), Vector2(-0.97, -0.32),
		Vector2(-1, 0.24), Vector2(-0.96, 0.59), Vector2(-0.82, 0.87), Vector2(-0.60, 1),
	]), true)


## A cambered transition carries the nacelle's lower shoulder to the wing.
## Its outboard shelf still seats the ordnance covers at their authored height.
func _formed_wing_root_mesh(side: float, material: Material) -> ArrayMesh:
	var mesh := _formed_pressure_mesh(Vector3(2.7, 0.58, 7.7), material)
	var arrays := mesh.surface_get_arrays(0)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var uv: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	surface.set_material(material)
	for index in vertices.size():
		var point := vertices[index]
		var span := clampf((point.x * side + 1.35) / 2.7, 0.0, 1.0)
		# Inboard crown rises into the formed pressure trunk, then settles
		# onto the thin outboard structure over the inner third of the span.
		point.y += 0.48 * pow(1.0 - span, 3.0)
		var slope := -0.48 * 3.0 * pow(1.0 - span, 2.0) * side / 2.7
		var normal := normals[index]
		normal.x -= slope * normal.y
		surface.set_normal(normal.normalized())
		surface.set_uv(uv[index])
		surface.add_vertex(point)
	surface.generate_tangents()
	return surface.commit()


func _pressure_section_mesh(size: Vector3, material: Material, section: PackedVector2Array, formed: bool = false) -> ArrayMesh:
	var stations := [0.0, 0.28, 0.43, 0.83, 1.0]
	var extents: Array[Vector2] = []
	for t in stations:
		var width := minf(1.0, lerpf(0.12, 1.0, t / 0.43))
		var height := minf(1.0, lerpf(0.35, 1.0, t / 0.28))
		if t > 0.83:
			width = lerpf(1.0, 0.9, (t - 0.83) / 0.17)
			height = lerpf(1.0, 0.8, (t - 0.83) / 0.17)
		extents.append(Vector2(width * size.x * 0.5, height * size.y * 0.5))
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	surface.set_material(material)
	for bay in stations.size() - 1:
		var extent_delta := extents[bay + 1] - extents[bay]
		var run: float = size.z * (stations[bay + 1] - stations[bay])
		for edge in 16:
			var next := (edge + 1) % 16
			var edge_direction := section[next] - section[edge]
			# Clockwise exterior winding, with analytic bilinear-patch
			# normals on the tapered chamfers rather than triangle fans.
			for corner in [Vector2i(edge, bay), Vector2i(next, bay), Vector2i(next, bay + 1), Vector2i(edge, bay), Vector2i(next, bay + 1), Vector2i(edge, bay + 1)]:
				var extent := extents[corner.y]
				var tangent := edge_direction
				if formed:
					# Smooth only the formed skin around each section; longitudinal
					# changes and the closed end bulkheads remain distinct surfaces.
					tangent = section[(corner.x + 1) % 16] - section[(corner.x + 15) % 16]
					if is_equal_approx(absf(section[corner.x].y), 1.0):
						tangent = Vector2(section[corner.x].y, 0)
				var around := Vector3(tangent.x * extent.x, tangent.y * extent.y, 0)
				var along := Vector3(section[corner.x].x * extent_delta.x, section[corner.x].y * extent_delta.y, run)
				var u := 1.0 if edge == 15 and corner.x == 0 else float(corner.x) / 16.0
				surface.set_normal(along.cross(around).normalized())
				surface.set_uv(Vector2(u, stations[corner.y]))
				surface.add_vertex(Vector3(section[corner.x].x * extent.x, section[corner.x].y * extent.y, (stations[corner.y] - 0.5) * size.z))
	for cap in [0, stations.size() - 1]:
		var z: float = (stations[cap] - 0.5) * size.z
		for edge in 16:
			var next := (edge + 1) % 16
			var order := [-1, next, edge] if cap == 0 else [-1, edge, next]
			for corner in order:
				var point := Vector3(0, 0, z) if corner < 0 else Vector3(section[corner].x * extents[cap].x, section[corner].y * extents[cap].y, z)
				surface.set_normal(Vector3.FORWARD if cap == 0 else Vector3.BACK)
				# XY cap projection retains a usable tangent frame.
				surface.set_uv(Vector2(point.x / size.x, point.y / size.y) + Vector2.ONE * 0.5)
				surface.add_vertex(point)
	surface.generate_tangents()
	return surface.commit()


func _armor_shell(parent: Node3D, node_name: String, at: Vector3, size: Vector3, coating: Material, skew: float = 0.0, formed_mesh: ArrayMesh = null) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.name = node_name
	instance.position = at
	instance.mesh = formed_mesh if formed_mesh != null else _loft_mesh(size, coating)
	# Shear the assembly into the wing root without an intersecting box joint.
	instance.transform.basis.z.x = -skew
	parent.add_child(instance)
	return instance


func _service_bay(parent: Node3D, tag: String, at: Vector3, width: float, length: float, frame: Material, dark: Material, metal: Material) -> void:
	_box(parent, tag + "Recess", at, Vector3(width, 0.035, length), dark)
	for side in [-1.0, 1.0]:
		_box(parent, tag + "Rim" + str(side), at + Vector3(side * (width * 0.5 + 0.045), 0.035, 0), Vector3(0.09, 0.07, length + 0.18), frame)
	for index in 5:
		_box(parent, tag + "Louver" + str(index), at + Vector3(0, 0.032, (float(index) / 4.0 - 0.5) * length * 0.78), Vector3(width * 0.82, 0.05, length * 0.07), metal, Vector3(0.18, 0, 0))


func _pressure_panel(parent: Node3D, label: String, at: Vector3, top: float, bottom: float, height: float, depth: float, material: Material) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.name = label
	instance.position = at
	instance.mesh = _pressure_mesh(top, bottom, height, depth, material)
	parent.add_child(instance)
	return instance


func _pressure_mesh(top: float, bottom: float, height: float, depth: float, material: Material) -> ArrayMesh:
	var source := _trapezoid_prism_mesh(top, bottom, height, depth, material)
	var arrays := source.surface_get_arrays(0)
	var points: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var uv: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
	var indices := PackedInt32Array()
	if arrays[Mesh.ARRAY_INDEX] != null:
		indices = arrays[Mesh.ARRAY_INDEX]
	if indices.is_empty():
		for index in points.size():
			indices.append(index)
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	surface.set_material(material)
	for triangle in range(0, indices.size(), 3):
		var normal := (points[indices[triangle + 2]] - points[indices[triangle]]).cross(points[indices[triangle + 1]] - points[indices[triangle]]).normalized()
		for corner in 3:
			var index := indices[triangle + corner]
			surface.set_normal(normal)
			surface.set_uv(uv[index])
			surface.add_vertex(points[index])
	surface.generate_tangents()
	return surface.commit()


## Annular combustion channel, retained hub and guide vanes give an unlit
## engine physical depth. Repeated vanes share one mesh and renderer.
func _engine_mechanics(parent: Node3D, tag: String, at: Vector3, radius: float, metal: Material, dark: Material, hot: Material) -> void:
	_cylinder(parent, tag + "ChamberBack", at + Vector3(0, 0, -0.22 * radius), radius * 0.86, radius * 0.08, dark, Vector3(90, 0, 0))
	for ring in 2:
		var torus := TorusMesh.new()
		torus.inner_radius = radius * (0.44 if ring == 0 else 0.88)
		torus.outer_radius = radius * (0.57 if ring == 0 else 1.02)
		torus.rings = 40
		torus.ring_segments = 8
		var lip := MeshInstance3D.new()
		lip.name = tag + ("CombustorAnnulus" if ring == 0 else "NozzleLip")
		lip.mesh = torus
		lip.material_override = hot if ring == 0 else metal
		lip.position = at + Vector3(0, 0, (-0.14 if ring == 0 else 0.18) * radius)
		lip.rotation.x = PI * 0.5
		parent.add_child(lip)
	_frustum(parent, tag + "ThrustPlug", at + Vector3(0, 0, -0.04 * radius), radius * 0.20, radius * 0.36, radius * 0.45, metal, Vector3(90, 0, 0))
	var blades := MultiMesh.new()
	blades.transform_format = MultiMesh.TRANSFORM_3D
	blades.mesh = _rounded_box_mesh(Vector3(radius * 0.065, radius * 0.29, radius * 0.18), metal)
	blades.instance_count = 12
	for i in 12:
		var angle := float(i) * TAU / 12.0
		blades.set_instance_transform(i, Transform3D(Basis(Vector3.BACK, angle + 0.22), Vector3(-sin(angle), cos(angle), 0) * radius * 0.71))
	var batch := MultiMeshInstance3D.new()
	batch.name = tag + "GuideVanes"
	batch.multimesh = blades
	batch.position = at
	batch.set_meta(&"presentation_only", true)
	parent.add_child(batch)


## Flush service plates have their own bevel and dark gasket; the narrow edge
## catches light while a readable seam separates adjacent manufactured parts.
func _deck_plate(parent: Node3D, tag: String, at: Vector3, width: float, length: float, paint: Material, gasket: Material) -> void:
	_box(parent, tag + "Gasket", at, Vector3(width, 0.028, length), gasket)
	_box(parent, tag + "Panel", at + Vector3(0, 0.022, 0), Vector3(width - 0.06, 0.032, length - 0.06), paint)


## A continuous shoulder carries the fixed cockpit floor into the pressure
## body. Its forward and aft ramps replace the stacked plinth silhouettes;
## all pilot, canopy hinge and boarding transforms stay on their original rig.
func _cockpit_shoulder_mesh(origin: Vector3, crown: float, width: float, material: Material) -> ArrayMesh:
	return preload("res://scripts/ships/cinder_cockpit_pressure_fairing.gd").build(origin, crown, width, material)
