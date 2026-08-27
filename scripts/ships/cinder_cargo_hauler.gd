class_name CinderCargoHauler
extends HeroShip

const WeaponDefinitionType := preload("res://scripts/combat/weapon_definition.gd")
const ShipPerspectiveAudioBindingType := preload("res://scripts/audio/ship_perspective_audio_binding.gd")
const CrewSeatRoleAuthorityType := preload("res://scripts/ships/crew_seat_role_authority.gd")
const CrewRoleGameplayProfileType := preload("res://scripts/fleet/crew_role_gameplay_profile.gd")

## Original-modern industrial cargo craft component. No historical class,
## silhouette, cargo contract, or ownership claim is authenticated here.

const SCHEMA_VERSION := 1
const COMPONENT_ID: StringName = &"cinder-cargo-hauler"
const EVIDENCE_STATUS: StringName = &"NEW"
const DISPLAY_NAME := "Cinder cargo hauler"
const CARGO_CAPACITY := 8
const HULL_SIZE := Vector3(6.4, 3.2, 12.0)
const WEAPON_ID: StringName = &"cinder_cargo_mass_driver"
const LOADMASTER_STATION_SEAT_ID: StringName = &"cinder_loadmaster_station"
const NAVIGATOR_STATION_SEAT_ID: StringName = &"cinder_navigator_station"
const INTERIOR_BOUNDS := AABB(Vector3(-2.55, -0.95, -2.80), Vector3(5.10, 2.10, 5.60))
const CABIN_ROUTE_ID: StringName = &"cinder_cargo_port_aperture"
const NAVIGATOR_ROUTE_ID: StringName = &"cinder_navigator_console"
const LOADMASTER_MANIFEST_GENERATION_MAX := 1_000_000
const LOADMASTER_INTERACTION_REACH := 1.20

const HULL_COLOR := Color("536b73")
const CARGO_COLOR := Color("b2773d")
const ACCENT_COLOR := Color("42c9cf")
const CARGO_SHOULDER_SIZE := Vector3(0.42, 0.72, 2.90)
## Repeated exterior load-frame ribs make the freight body legible from the
## normal side/rear approach. Their full bounds remain inside the existing
## 6.8 m-wide collision shell and clear the physical port boarding aperture.
const CARGO_FRAME_RIB_SIZE := Vector3(0.14, 2.40, 0.34)
const CARGO_FRAME_RIB_COLOR := Color("d8a258")
const CARGO_FRAME_RIB_X := 3.28
const CARGO_FRAME_RIB_Z := [-4.65, -2.75, 2.75, 4.65]
const ENGINE_DAMAGE_SHOULDER_COLOR := Color("f0a24a")
const ENGINE_FAILED_SHOULDER_COLOR := Color("d95b43")
const ENGINE_DAMAGE_SHOULDER_X := 2.98
const ENGINE_DAMAGE_SHOULDER_Y := 0.95
const ENGINE_DAMAGE_SHOULDER_Y_SCALE := 2.5
## Both failed-state rails retain a root in the aft roof/hull structure. The
## port support stays nearly upright while the starboard rail folds inward,
## creating an asymmetric outline without making either retained part float.
const ENGINE_FAILED_SHOULDER_ROOT_X := 2.45
const ENGINE_FAILED_SHOULDER_ROOT_Y := 1.50
const ENGINE_FAILED_SHOULDER_Y_SCALE := 1.0
const ENGINE_FAILED_PORT_CANT_DEGREES := 0.0
const ENGINE_FAILED_STARBOARD_CANT_DEGREES := 58.0

# The primary hull is immutable, childless presentation stock. Fleet switching
# can briefly retain two haulers, so keep one process-local mesh/material recipe
# while each craft retains its own renderer, transform, collision and authority.
static var _shared_hull_mesh: BoxMesh
static var _shared_hull_material: StandardMaterial3D
# The cargo pod is likewise static exterior presentation. Keep its renderer
# local so a craft can be detached independently, while sharing its immutable
# geometry and paint recipe across simultaneously retained haulers.
static var _shared_cargo_pod_mesh: BoxMesh
static var _shared_cargo_pod_material: StandardMaterial3D


class CinderLoadmasterInteraction:
	extends Area3D

	var _craft: CinderCargoHauler
	var _seat_id: StringName
	var _seat_generation := 1
	var _reach_meters := 1.20
	var _actor: Node
	var _source_peer_id := 0
	var _occupant_peer_id := 0
	var _avatar_id: StringName = &""
	var _claim_request_sequence := -1


	func configure(
			craft: CinderCargoHauler,
			seat_id: StringName,
			seat_generation: int,
			reach_meters: float
	) -> void:
		_craft = craft
		_seat_id = seat_id
		_seat_generation = seat_generation
		_reach_meters = reach_meters
		collision_layer = PhysicsLayers.INTERACTABLE_AREA_LAYER
		collision_mask = 0
		monitoring = false
		monitorable = true
		var shape := CollisionShape3D.new()
		shape.name = "InteractionShape"
		var sphere := SphereShape3D.new()
		sphere.radius = reach_meters
		shape.shape = sphere
		add_child(shape)


	func get_interaction_prompt() -> String:
		return "[ E ]  SIT  // LOADMASTER" if is_available() else ""


	func get_seat_id() -> StringName:
		return _seat_id


	func get_seat_generation() -> int:
		return _seat_generation


	func is_available() -> bool:
		return is_inside_tree() and _actor == null and _craft != null \
			and _craft.is_loadmaster_station_available()


	func try_claim(
			actor: Node,
			source_peer_id: int,
			occupant_peer_id: int,
			avatar_id: StringName,
			request_sequence: int
	) -> Dictionary:
		if not is_instance_valid(actor) or not is_available():
			return {"accepted": false, "status": &"interaction_unavailable"}
		if not actor is Node3D or global_position.distance_to((actor as Node3D).global_position) > _reach_meters:
			return {"accepted": false, "status": &"interaction_out_of_range"}
		var result := _craft.claim_loadmaster_station(
			actor, source_peer_id, occupant_peer_id, avatar_id, request_sequence, _seat_generation
		)
		if bool(result.get("accepted", false)):
			_actor = actor
			_source_peer_id = source_peer_id
			_occupant_peer_id = occupant_peer_id
			_avatar_id = avatar_id
			_claim_request_sequence = request_sequence
			_apply_availability(false)
		return result


	func release(
			actor: Node,
			source_peer_id: int,
			occupant_peer_id: int,
			avatar_id: StringName,
			request_sequence: int
	) -> Dictionary:
		if _actor != actor:
			return {"accepted": false, "status": &"interaction_actor_mismatch"}
		var result := _craft.release_loadmaster_station(
			actor, source_peer_id, occupant_peer_id, avatar_id, request_sequence, _seat_generation
		)
		if bool(result.get("accepted", false)):
			_actor = null
			_clear_assignment_tracking()
			_apply_availability(true)
		return result


	func clear_for_detach() -> void:
		if _actor != null and _craft != null and _craft.get_crew_role_authority() != null:
			_craft.release_loadmaster_station(
				_actor,
				_source_peer_id,
				_occupant_peer_id,
				_avatar_id,
				_claim_request_sequence + 1,
				_seat_generation
			)
		_actor = null
		_clear_assignment_tracking()
		_apply_availability(false)


	func refresh_availability() -> void:
		_apply_availability(true)


	func _apply_availability(enabled: bool) -> void:
		monitorable = enabled and _craft != null and _craft.is_loadmaster_station_available()
		for child in get_children():
			if child is CollisionShape3D:
				(child as CollisionShape3D).set_deferred(&"disabled", not monitorable)


	func _clear_assignment_tracking() -> void:
		_source_peer_id = 0
		_occupant_peer_id = 0
		_avatar_id = &""
		_claim_request_sequence = -1


class CinderNavigatorInteraction:
	extends Area3D

	var _craft: CinderCargoHauler
	var _seat_id: StringName
	var _seat_generation := 1
	var _reach_meters := 1.20
	var _actor: Node
	var _source_peer_id := 0
	var _occupant_peer_id := 0
	var _avatar_id: StringName = &""
	var _claim_request_sequence := -1


	func configure(
			craft: CinderCargoHauler,
			seat_id: StringName,
			seat_generation: int,
			reach_meters: float
	) -> void:
		_craft = craft
		_seat_id = seat_id
		_seat_generation = seat_generation
		_reach_meters = reach_meters
		collision_layer = PhysicsLayers.INTERACTABLE_AREA_LAYER
		collision_mask = 0
		monitoring = false
		monitorable = true
		var shape := CollisionShape3D.new()
		shape.name = "InteractionShape"
		var sphere := SphereShape3D.new()
		sphere.radius = reach_meters
		shape.shape = sphere
		add_child(shape)


	func get_interaction_prompt() -> String:
		return "[ E ]  SIT  // NAVIGATOR" if is_available() else ""


	func get_seat_id() -> StringName:
		return _seat_id


	func get_seat_generation() -> int:
		return _seat_generation


	func is_available() -> bool:
		return is_inside_tree() and _actor == null and _craft != null \
			and _craft.is_navigator_station_available()


	func try_claim(
			actor: Node,
			source_peer_id: int,
			occupant_peer_id: int,
			avatar_id: StringName,
			request_sequence: int
	) -> Dictionary:
		if not is_instance_valid(actor) or not is_available():
			return {"accepted": false, "status": &"interaction_unavailable"}
		if not actor is Node3D or global_position.distance_to((actor as Node3D).global_position) > _reach_meters:
			return {"accepted": false, "status": &"interaction_out_of_range"}
		var result: Dictionary = _craft.claim_navigator_station(
			actor, source_peer_id, occupant_peer_id, avatar_id, request_sequence, _seat_generation
		)
		if bool(result.get("accepted", false)):
			_actor = actor
			_source_peer_id = source_peer_id
			_occupant_peer_id = occupant_peer_id
			_avatar_id = avatar_id
			_claim_request_sequence = request_sequence
			_apply_availability(false)
		return result


	func release(
			actor: Node,
			source_peer_id: int,
			occupant_peer_id: int,
			avatar_id: StringName,
			request_sequence: int
	) -> Dictionary:
		if _actor != actor:
			return {"accepted": false, "status": &"interaction_actor_mismatch"}
		var result: Dictionary = _craft.release_navigator_station(
			actor, source_peer_id, occupant_peer_id, avatar_id, request_sequence, _seat_generation
		)
		if bool(result.get("accepted", false)):
			_actor = null
			_clear_assignment_tracking()
			_apply_availability(true)
		return result


	func clear_for_detach() -> void:
		if _actor != null and _craft != null and _craft.get_crew_role_authority() != null:
			_craft.release_navigator_station(
				_actor,
				_source_peer_id,
				_occupant_peer_id,
				_avatar_id,
				_claim_request_sequence + 1,
				_seat_generation
			)
		_actor = null
		_clear_assignment_tracking()
		_apply_availability(false)


	func refresh_availability() -> void:
		_apply_availability(true)


	func _apply_availability(enabled: bool) -> void:
		monitorable = enabled and _craft != null and _craft.is_navigator_station_available()
		for child in get_children():
			if child is CollisionShape3D:
				(child as CollisionShape3D).set_deferred(&"disabled", not monitorable)


	func record_request_sequence(request_sequence: int) -> void:
		_claim_request_sequence = maxi(_claim_request_sequence, request_sequence)


	func _clear_assignment_tracking() -> void:
		_source_peer_id = 0
		_occupant_peer_id = 0
		_avatar_id = &""
		_claim_request_sequence = -1

var _cargo_cockpit_seat: Marker3D
var _cargo_boarding_marker: Marker3D
var _cargo_shoulders: MultiMeshInstance3D
var _cargo_frame_ribs: MultiMeshInstance3D
var _cargo_shoulder_material: StandardMaterial3D
var _engine_damage_shoulder_material: StandardMaterial3D
var _cargo_access_sign: Label3D
var _cargo_threshold_light: OmniLight3D
var _cargo_hold: Node3D
var _cargo_anchors: Array[Marker3D] = []
var _walkable_interior: Node3D
var _cargo_cabin: Node3D
var _moving_interior_component: MovingInteriorFrame
var _occupant_volume: Area3D
var _loadmaster_station_anchor: Marker3D
var _crew_console_batch: MultiMeshInstance3D
var _loadmaster_interaction: CinderLoadmasterInteraction
var _navigator_station_anchor: Marker3D
var _navigator_interaction: CinderNavigatorInteraction
var _navigator_ping_receipt: Dictionary = {}
var _navigator_ping_generation := 1
var _loadmaster_status_panel: MeshInstance3D
var _loadmaster_status_display: Label3D
var _loadmaster_status_snapshot: Dictionary = {}
var _crew_role_authority: CrewSeatRoleAuthority
var _loadmaster_manifest_receipt: Dictionary = {}
var _loadmaster_manifest_generation := 1
var _interior_occupant_count := 0
var _cargo_built := false
var _weapon_definition: WeaponDefinition
var _ship_perspective_audio_binding: RefCounted

signal loadmaster_manifest_intent_accepted(receipt: Dictionary)
signal loadmaster_manifest_cleared(generation: int, reason: StringName)


func _uses_torrent_reconstruction_presentation() -> bool:
	return false


func _enter_tree() -> void:
	super._enter_tree()
	if _ship_perspective_audio_binding != null:
		call_deferred("_rebind_cargo_perspective_audio")
	if _cargo_shoulders != null:
		call_deferred("_sync_engine_damage_shoulders")


func _ready() -> void:
	_weapon_definition = _build_weapon_definition()
	ship_id = COMPONENT_ID
	display_name = DISPLAY_NAME
	role_name = "Cargo hauler"
	set_meta(&"component_id", COMPONENT_ID)
	set_meta(&"evidence_status", EVIDENCE_STATUS)
	set_meta(&"historically_supported", false)
	set_meta(&"content_class", EVIDENCE_STATUS)
	super._ready()
	_ship_perspective_audio_binding = ShipPerspectiveAudioBindingType.new()
	var perspective_result: Dictionary = _ship_perspective_audio_binding.bind(_ship_audio_rig)
	if bool(perspective_result.get("accepted", false)):
		camera_view_changed.connect(_on_cargo_camera_view_changed)
	else:
		_ship_perspective_audio_binding = null
	if not _cargo_built:
		_cargo_built = rebuild_variant_presentation(_build_cargo_variant)
	if not component_damage_changed.is_connected(_on_cargo_component_damage_changed):
		component_damage_changed.connect(_on_cargo_component_damage_changed)
	_sync_engine_damage_shoulders()


func _exit_tree() -> void:
	_clear_loadmaster_manifest(&"ship_detached")
	if _loadmaster_interaction != null:
		_loadmaster_interaction.clear_for_detach()
	if _navigator_interaction != null:
		_navigator_interaction.clear_for_detach()
	_clear_navigator_ping(&"ship_detached")
	if _moving_interior_component != null and is_instance_valid(_moving_interior_component):
		_moving_interior_component.clear_occupants(false, &"ship_detached")
	if _ship_perspective_audio_binding != null:
		if camera_view_changed.is_connected(_on_cargo_camera_view_changed):
			camera_view_changed.disconnect(_on_cargo_camera_view_changed)
		_ship_perspective_audio_binding.detach()
	super._exit_tree()


func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	if _reset_for_reuse_mutation_blocked():
		return
	_cleanup_detached_loadmaster()


func _rebind_cargo_perspective_audio() -> void:
	if not is_inside_tree() or _ship_perspective_audio_binding == null \
			or _ship_audio_rig == null or not is_instance_valid(_ship_audio_rig):
		return
	var snapshot: Dictionary = _ship_perspective_audio_binding.get_snapshot()
	if bool(snapshot.get("attached", false)):
		return
	var result: Dictionary = _ship_perspective_audio_binding.bind(_ship_audio_rig)
	if bool(result.get("accepted", false)) \
			and not camera_view_changed.is_connected(_on_cargo_camera_view_changed):
		camera_view_changed.connect(_on_cargo_camera_view_changed)


func _on_cargo_camera_view_changed(view: StringName) -> void:
	if _ship_perspective_audio_binding == null:
		return
	var perspective: StringName = &"cockpit" if view == CAMERA_VIEW_COCKPIT else &"exterior"
	var generation := int(_ship_perspective_audio_binding.get_snapshot().get("generation", -1))
	_ship_perspective_audio_binding.present_perspective(perspective, generation)


func apply_damage(
		amount: float,
		world_hit_position: Vector3 = Vector3.INF,
		world_hit_normal: Vector3 = Vector3.ZERO,
		presentation_receipt_id: int = -1,
		defer_presentation: bool = false
	) -> void:
	super.apply_damage(
		amount,
		world_hit_position,
		world_hit_normal,
		presentation_receipt_id,
		defer_presentation
	)
	if is_destroyed():
		_clear_loadmaster_manifest(&"ship_destroyed")
		if _loadmaster_interaction != null:
			_loadmaster_interaction.clear_for_detach()
		if _navigator_interaction != null:
			_navigator_interaction.clear_for_detach()
		_clear_navigator_ping(&"ship_destroyed")
		if _moving_interior_component != null:
			_moving_interior_component.clear_occupants(true, &"ship_destroyed")


func get_ship_perspective_audio_snapshot() -> Dictionary:
	return _ship_perspective_audio_binding.get_snapshot() \
		if _ship_perspective_audio_binding != null else {"attached": false}


func _build_cargo_variant(_controller: HeroShip) -> bool:
	var visual := get_variant_visual_root()
	if visual == null:
		return false
	visual.name = "CinderCargoVisual"
	visual.set_meta(&"geometry_status", EVIDENCE_STATUS)
	visual.set_meta(&"historically_supported", false)
	_build_hull(visual)
	_cargo_boarding_marker = Marker3D.new()
	_cargo_boarding_marker.name = "CargoBoardingMarker"
	_cargo_boarding_marker.position = Vector3(-3.4, -1.1, 0.0)
	_cargo_boarding_marker.set_meta(&"boarding_side", &"port")
	visual.add_child(_cargo_boarding_marker)
	var boarding_area := ShipBoardingArea.new()
	boarding_area.name = "ShipBoardingArea"
	boarding_area.interaction_id = &"board_cinder_cargo_hauler"
	boarding_area.prompt_text = "[ E ]  BOARD CINDER CARGO HAULER"
	boarding_area.position = _cargo_boarding_marker.position
	var boarding_shape := CollisionShape3D.new()
	boarding_shape.name = "BoardingRange"
	var boarding_sphere := SphereShape3D.new()
	boarding_sphere.radius = 4.5
	boarding_shape.shape = boarding_sphere
	boarding_area.add_child(boarding_shape)
	add_child(boarding_area)
	var lamp := MeshInstance3D.new()
	lamp.name = "CargoBoardingLamp"
	var lamp_mesh := BoxMesh.new()
	lamp_mesh.size = Vector3(0.18, 0.18, 0.8)
	lamp.mesh = lamp_mesh
	lamp.position = _cargo_boarding_marker.position + Vector3(0.2, 0.5, 0.0)
	lamp.material_override = _material(ACCENT_COLOR, 0.2, 0.42, ACCENT_COLOR, 1.8)
	visual.add_child(lamp)
	var boarding_step := _add_interior_box(
		visual,
		"CargoBoardingStep",
		_cargo_boarding_marker.position + Vector3(0.0, 0.05, 0.0),
		Vector3(0.72, 0.16, 1.65),
		ACCENT_COLOR
	)
	boarding_step.set_meta(&"route_id", CABIN_ROUTE_ID)
	var threshold_post_transforms: Array[Transform3D] = [
		Transform3D(Basis.IDENTITY, _cargo_boarding_marker.position + Vector3(0.0, 1.02, -0.72)),
		Transform3D(Basis.IDENTITY, _cargo_boarding_marker.position + Vector3(0.0, 1.02, 0.72)),
	]
	var threshold_posts := _add_visual_box_batch(
		visual,
		"CargoThresholdPostBatch",
		Vector3(0.16, 2.05, 0.16),
		threshold_post_transforms,
		ACCENT_COLOR,
		PackedStringArray(["CargoThresholdPostPort", "CargoThresholdPostStarboard"])
	)
	threshold_posts.set_meta(&"route_id", CABIN_ROUTE_ID)
	var threshold_header := _add_interior_box(
		visual,
		"CargoThresholdHeader",
		_cargo_boarding_marker.position + Vector3(0.0, 2.00, 0.0),
		Vector3(0.16, 0.16, 1.60),
		ACCENT_COLOR
	)
	threshold_header.set_meta(&"presentation_only", true)
	threshold_header.set_meta(&"route_id", CABIN_ROUTE_ID)
	_cargo_access_sign = Label3D.new()
	_cargo_access_sign.name = "CargoAccessSign"
	_cargo_access_sign.position = _cargo_boarding_marker.position + Vector3(-0.02, 1.48, 0.0)
	_cargo_access_sign.rotation.y = PI * 0.5
	_cargo_access_sign.font_size = 24
	_cargo_access_sign.pixel_size = 0.0014
	_cargo_access_sign.modulate = Color("f2ffff")
	_cargo_access_sign.outline_modulate = Color("07111d")
	_cargo_access_sign.outline_size = 8
	_cargo_access_sign.no_depth_test = true
	_cargo_access_sign.text = "CARGO ACCESS\nLOADMASTER"
	_cargo_access_sign.set_meta(&"presentation_only", true)
	_cargo_access_sign.set_meta(&"route_id", CABIN_ROUTE_ID)
	_cargo_access_sign.set_meta(&"color_independent", true)
	visual.add_child(_cargo_access_sign)
	_cargo_threshold_light = OmniLight3D.new()
	_cargo_threshold_light.name = "CargoThresholdLight"
	_cargo_threshold_light.position = _cargo_boarding_marker.position + Vector3(0.0, 1.35, 0.0)
	_cargo_threshold_light.light_color = ACCENT_COLOR
	_cargo_threshold_light.light_energy = 0.72
	_cargo_threshold_light.omni_range = 4.2
	_cargo_threshold_light.shadow_enabled = false
	_cargo_threshold_light.set_meta(&"presentation_only", true)
	_cargo_threshold_light.set_meta(&"reduced_flash_safe", true)
	_cargo_threshold_light.set_meta(&"animated", false)
	visual.add_child(_cargo_threshold_light)
	_build_cargo_hold(visual)
	_build_cargo_interior()
	_bind_cargo_interior_frame()
	return true


func get_display_name() -> String:
	return DISPLAY_NAME


func get_cockpit_seat_anchor() -> Marker3D:
	return get_pilot_seat_anchor() as Marker3D


func get_boarding_marker() -> Marker3D:
	return _cargo_boarding_marker


func get_cargo_hold_root() -> Node3D:
	return _cargo_hold


func get_cargo_transfer_anchors() -> Array[Marker3D]:
	return _cargo_anchors.duplicate()


func get_cargo_capacity() -> int:
	return CARGO_CAPACITY


## The bounded cargo cabin is a real ship-local walkable volume. The frame owns
## occupant compensation; this craft only publishes its physical station and
## consumes detached role receipts.
func get_in_flight_cabin_report() -> Dictionary:
	return {
		"supported": _cargo_built and _walkable_interior != null \
			and _moving_interior_component != null,
		"status": &"cinder_cargo_cabin",
		"frame": _moving_interior_component,
		"stand_transform": _loadmaster_station_anchor.global_transform \
			if is_instance_valid(_loadmaster_station_anchor) and _loadmaster_station_anchor.is_inside_tree() \
			else Transform3D.IDENTITY,
		"local_bounds": INTERIOR_BOUNDS,
		"boarding_route_id": CABIN_ROUTE_ID,
		"loadmaster_station": _loadmaster_station_anchor,
	}.duplicate(true)


func get_cargo_cabin_root() -> Node3D:
	return _cargo_cabin


func get_moving_interior_component() -> MovingInteriorFrame:
	return _moving_interior_component


func get_loadmaster_station_anchor() -> Marker3D:
	return _loadmaster_station_anchor


func get_loadmaster_interaction() -> CinderLoadmasterInteraction:
	return _loadmaster_interaction


func get_navigator_station_anchor() -> Marker3D:
	return _navigator_station_anchor


func get_navigator_interaction() -> CinderNavigatorInteraction:
	return _navigator_interaction


func is_navigator_station_available() -> bool:
	if _crew_role_authority == null or not is_instance_valid(_navigator_station_anchor) \
			or not _has_navigator_seat_registration():
		return false
	for assignment_variant in _crew_role_authority.get_snapshot().get("assignments", []) as Array:
		if StringName((assignment_variant as Dictionary).get("seat_id", &"")) == NAVIGATOR_STATION_SEAT_ID:
			return false
	return true


func _has_navigator_seat_registration() -> bool:
	if _crew_role_authority == null:
		return false
	for seat_variant in _crew_role_authority.get_snapshot().get("seats", []) as Array:
		if not seat_variant is Dictionary:
			continue
		var seat := seat_variant as Dictionary
		if StringName(seat.get("vessel_id", &"")) == get_ship_id() \
				and StringName(seat.get("seat_id", &"")) == NAVIGATOR_STATION_SEAT_ID \
				and StringName(seat.get("role", &"")) == CrewRoleGameplayProfileType.ROLE_PASSENGER:
			return true
	return false


func claim_navigator_station(
		actor: Node,
		source_peer_id: int,
		occupant_peer_id: int,
		avatar_id: StringName,
		request_sequence: int,
		seat_generation: int
) -> Dictionary:
	if not is_instance_valid(actor) or not actor is Node3D:
		return {"accepted": false, "status": &"invalid_interaction_actor"}
	if _navigator_interaction == null \
			or _navigator_interaction.global_position.distance_to((actor as Node3D).global_position) > LOADMASTER_INTERACTION_REACH:
		return {"accepted": false, "status": &"interaction_out_of_range"}
	if not is_navigator_station_available():
		return {"accepted": false, "status": &"station_occupied"}
	var expected_generation := int(_navigator_station_anchor.get_meta(&"seat_generation", 1))
	if seat_generation != expected_generation:
		return {"accepted": false, "status": &"stale_seat_generation"}
	return _crew_role_authority.claim(
		source_peer_id,
		occupant_peer_id,
		avatar_id,
		NAVIGATOR_STATION_SEAT_ID,
		CrewRoleGameplayProfileType.ROLE_PASSENGER,
		request_sequence
	)


func release_navigator_station(
		actor: Node,
		source_peer_id: int,
		occupant_peer_id: int,
		avatar_id: StringName,
		request_sequence: int,
		seat_generation: int
) -> Dictionary:
	if _navigator_interaction == null or _crew_role_authority == null or not is_instance_valid(actor):
		return {"accepted": false, "status": &"invalid_interaction_actor"}
	var result := _crew_role_authority.release(
		source_peer_id,
		occupant_peer_id,
		avatar_id,
		NAVIGATOR_STATION_SEAT_ID,
		request_sequence,
		seat_generation
	)
	if bool(result.get("accepted", false)):
		_clear_navigator_ping(&"role_released")
	return result


func get_navigator_ping_snapshot() -> Dictionary:
	return {
		"schema_version": 1,
		"station_id": NAVIGATOR_STATION_SEAT_ID,
		"route_id": NAVIGATOR_ROUTE_ID,
		"ping_generation": _navigator_ping_generation,
		"receipt": _navigator_ping_receipt.duplicate(true),
		"movement_authority": false,
		"cargo_authority": false,
		"combat_authority": false,
	}.duplicate(true)


func _clear_navigator_ping(_reason: StringName, advance_generation: bool = true) -> void:
	_navigator_ping_receipt = {}
	if advance_generation:
		_navigator_ping_generation += 1


func is_loadmaster_station_available() -> bool:
	if _crew_role_authority == null or not is_instance_valid(_loadmaster_station_anchor):
		return false
	for assignment_variant in _crew_role_authority.get_snapshot().get("assignments", []) as Array:
		if StringName((assignment_variant as Dictionary).get("seat_id", &"")) == LOADMASTER_STATION_SEAT_ID:
			return false
	return true


func claim_loadmaster_station(
		actor: Node,
		source_peer_id: int,
		occupant_peer_id: int,
		avatar_id: StringName,
		request_sequence: int,
		seat_generation: int
) -> Dictionary:
	if not is_instance_valid(actor) or not actor is Node3D:
		return {"accepted": false, "status": &"invalid_interaction_actor"}
	if _loadmaster_interaction == null \
			or _loadmaster_interaction.global_position.distance_to((actor as Node3D).global_position) > LOADMASTER_INTERACTION_REACH:
		return {"accepted": false, "status": &"interaction_out_of_range"}
	if not is_loadmaster_station_available():
		return {"accepted": false, "status": &"station_occupied"}
	var expected_generation := int(_loadmaster_station_anchor.get_meta(&"seat_generation", 1))
	if seat_generation != expected_generation:
		return {"accepted": false, "status": &"stale_seat_generation"}
	return _crew_role_authority.claim(
		source_peer_id,
		occupant_peer_id,
		avatar_id,
		LOADMASTER_STATION_SEAT_ID,
		CrewRoleGameplayProfileType.ROLE_PASSENGER,
		request_sequence
	)


func release_loadmaster_station(
		actor: Node,
		source_peer_id: int,
		occupant_peer_id: int,
		avatar_id: StringName,
		request_sequence: int,
		seat_generation: int
) -> Dictionary:
	if _loadmaster_interaction == null or _crew_role_authority == null or not is_instance_valid(actor):
		return {"accepted": false, "status": &"invalid_interaction_actor"}
	var result := _crew_role_authority.release(
		source_peer_id,
		occupant_peer_id,
		avatar_id,
		LOADMASTER_STATION_SEAT_ID,
		request_sequence,
		seat_generation
	)
	if bool(result.get("accepted", false)):
		_clear_loadmaster_manifest(&"role_released")
	return result


func get_loadmaster_manifest_snapshot() -> Dictionary:
	return {
		"schema_version": 1,
		"station_id": LOADMASTER_STATION_SEAT_ID,
		"station_present": is_instance_valid(_loadmaster_station_anchor),
		"manifest_generation": _loadmaster_manifest_generation,
		"receipt": _loadmaster_manifest_receipt.duplicate(true),
		"cargo_transfer_authority": false,
		"inventory_authority": false,
		"reward_authority": false,
	}.duplicate(true)


func get_loadmaster_status_snapshot() -> Dictionary:
	return _loadmaster_status_snapshot.duplicate(true)


## Presentation refresh is an explicit event seam for seat/session presenters;
## it never polls gameplay state from a per-frame callback.
func refresh_loadmaster_status_display() -> Dictionary:
	var state: StringName = &"available"
	var route_id: StringName = &""
	var manifest_id: StringName = &""
	if not _loadmaster_manifest_receipt.is_empty():
		manifest_id = StringName(_loadmaster_manifest_receipt.get("manifest_id", &""))
		route_id = StringName(_loadmaster_manifest_receipt.get("route_id", &""))
		state = &"manifest_ready" if bool(_loadmaster_manifest_receipt.get("ready", false)) else &"occupied"
	elif _crew_role_authority != null:
		for assignment_variant in _crew_role_authority.get_snapshot().get("assignments", []) as Array:
			if StringName((assignment_variant as Dictionary).get("seat_id", &"")) == LOADMASTER_STATION_SEAT_ID:
				state = &"occupied"
				break
	_update_loadmaster_status_display(state, manifest_id, route_id)
	return _loadmaster_status_snapshot.duplicate(true)


func get_crew_role_authority() -> CrewSeatRoleAuthority:
	return _crew_role_authority


## Binds the caller-owned role ledger to the one physical Cinder station.
func attach_crew_role_authority(authority: CrewSeatRoleAuthority) -> Dictionary:
	if authority == null:
		return _crew_role_result(false, &"authority_unavailable")
	if _crew_role_authority != null and _crew_role_authority != authority:
		return _crew_role_result(false, &"authority_already_attached")
	var snapshot := authority.get_snapshot()
	if not bool(snapshot.get("roster_sealed", false)):
		return _crew_role_result(false, &"roster_not_sealed")
	var station_found := false
	for seat_variant in snapshot.get("seats", []) as Array:
		if not seat_variant is Dictionary:
			continue
		var seat := seat_variant as Dictionary
		if StringName(seat.get("vessel_id", &"")) == get_ship_id() \
				and StringName(seat.get("seat_id", &"")) == LOADMASTER_STATION_SEAT_ID \
				and StringName(seat.get("role", &"")) == CrewRoleGameplayProfileType.ROLE_PASSENGER:
			station_found = true
	if not station_found or not is_instance_valid(_loadmaster_station_anchor):
		return _crew_role_result(false, &"cinder_loadmaster_roster_mismatch")
	_crew_role_authority = authority
	if _loadmaster_interaction != null:
		_loadmaster_interaction.refresh_availability()
	if _navigator_interaction != null:
		_navigator_interaction.refresh_availability()
	refresh_loadmaster_status_display()
	return _crew_role_result(true, &"authority_attached")


## Consumes only the normalized loadmaster manifest/readiness proposal. Cargo
## transfer, inventory, rewards and flight remain owned by their existing systems.
func submit_crew_intent(
		source_peer_id: int,
		occupant_peer_id: int,
		avatar_id: StringName,
		action: StringName,
		payload: Dictionary,
		request_sequence: int
) -> Dictionary:
	if _crew_role_authority == null:
		return _crew_role_result(false, &"authority_unavailable")
	var assignment := _crew_role_authority.get_assignment(occupant_peer_id, avatar_id)
	if assignment.is_empty():
		return _crew_role_result(false, &"assignment_not_found")
	if StringName(assignment.get("vessel_id", &"")) != get_ship_id():
		return _crew_role_result(false, &"foreign_vessel")
	var assignment_seat := StringName(assignment.get("seat_id", &""))
	var is_loadmaster := assignment_seat == LOADMASTER_STATION_SEAT_ID \
			and action == CrewRoleGameplayProfileType.ACTION_PASSENGER_CARGO_MANIFEST
	var is_navigator := assignment_seat == NAVIGATOR_STATION_SEAT_ID \
			and action == CrewRoleGameplayProfileType.ACTION_PASSENGER_PING
	if StringName(assignment.get("role", &"")) != CrewRoleGameplayProfileType.ROLE_PASSENGER \
			or (not is_loadmaster and not is_navigator):
		return _crew_role_result(false, &"unsupported_cinder_role_action")
	var admission := _crew_role_authority.submit_intent(
		source_peer_id, occupant_peer_id, avatar_id, action, payload, request_sequence
	)
	if not bool(admission.get("accepted", false)):
		return admission
	var intent := admission.get("intent", {}) as Dictionary
	var normalized := intent.get("payload", {}) as Dictionary
	if normalized.is_empty():
		return _crew_role_result(false, &"invalid_manifest_intent")
	if is_navigator:
		var ping_receipt := {
			"channel": StringName(normalized.get("channel", &"")),
			"marker_id": StringName(normalized.get("marker_id", &"")),
			"occupant_peer_id": occupant_peer_id,
			"avatar_id": avatar_id,
			"seat_generation": int(assignment.get("seat_generation", 0)),
			"request_sequence": request_sequence,
			"ping_generation": _navigator_ping_generation,
		}
		_navigator_ping_receipt = ping_receipt
		if _navigator_interaction != null:
			_navigator_interaction.record_request_sequence(request_sequence)
		var ping_result := admission.duplicate(true)
		ping_result["status"] = &"intent_consumed"
		ping_result["consumed"] = true
		ping_result["effect"] = {
			"accepted": true,
			"reason": &"navigator_ping_recorded",
			"receipt": ping_receipt.duplicate(true),
		}
		return ping_result
	var receipt := {
		"manifest_id": StringName(normalized.get("manifest_id", &"")),
		"route_id": StringName(normalized.get("route_id", &"")),
		"ready": bool(normalized.get("ready", false)),
		"occupant_peer_id": occupant_peer_id,
		"avatar_id": avatar_id,
		"seat_generation": int(assignment.get("seat_generation", 0)),
		"request_sequence": request_sequence,
		"manifest_generation": _loadmaster_manifest_generation,
	}
	_loadmaster_manifest_receipt = receipt
	loadmaster_manifest_intent_accepted.emit(receipt.duplicate(true))
	refresh_loadmaster_status_display()
	var result := admission.duplicate(true)
	result["status"] = &"intent_consumed"
	result["consumed"] = true
	result["effect"] = {"accepted": true, "reason": &"loadmaster_manifest_recorded", "receipt": receipt.duplicate(true)}
	return result


func release_crew_role(
		source_peer_id: int,
		occupant_peer_id: int,
		avatar_id: StringName,
		seat_id: StringName,
		request_sequence: int,
		seat_generation: int = 0
) -> Dictionary:
	if _crew_role_authority == null:
		return _crew_role_result(false, &"authority_unavailable")
	var released := _crew_role_authority.release(
		source_peer_id, occupant_peer_id, avatar_id, seat_id, request_sequence, seat_generation
	)
	if bool(released.get("accepted", false)):
		_clear_loadmaster_manifest(&"role_released")
	return released


## Returns a defensive copy of the cargo hauler's explicit modern combat role.
## Combat resolution remains owned by the shared authority; this component only
## publishes immutable-by-copy authoring identity.
func get_weapon_definition() -> WeaponDefinition:
	return _weapon_definition.duplicate(true) as WeaponDefinition if _weapon_definition != null else null


func get_audit_report() -> Dictionary:
	var errors := PackedStringArray()
	if not _cargo_built:
		errors.append("craft has not built its authored component tree")
	if not is_instance_valid(get_pilot_seat_anchor()) or not is_instance_valid(_cargo_boarding_marker):
		errors.append("cockpit and boarding anchors are required")
	if not is_instance_valid(_cargo_hold) or _cargo_anchors.size() != CARGO_CAPACITY:
		errors.append("cargo hold requires eight stable transfer anchors")
	var collision_report := get_landing_collision_report()
	if not bool(collision_report.get("valid", false)):
		errors.append("craft requires HeroShip root collision")
	if not supports_in_flight_cabin_access():
		errors.append("craft requires its bounded MovingInteriorFrame cabin")
	if not is_instance_valid(_loadmaster_station_anchor):
		errors.append("craft requires a physical loadmaster station anchor")
	return {
		"schema_version": SCHEMA_VERSION,
		"component_id": COMPONENT_ID,
		"evidence_status": EVIDENCE_STATUS,
		"content_class": EVIDENCE_STATUS,
		"historically_supported": false,
		"valid": errors.is_empty(),
		"errors": errors,
		"cargo_capacity": CARGO_CAPACITY,
		"walkable_cabin": supports_in_flight_cabin_access(),
		"cabin_route_id": CABIN_ROUTE_ID,
		"loadmaster_station_id": LOADMASTER_STATION_SEAT_ID,
		"loadmaster_seat_type": _loadmaster_station_anchor.get_meta("seat_type", &"") \
			if is_instance_valid(_loadmaster_station_anchor) else &"",
		"interior_frame_authority": &"MovingInteriorFrame",
		"interior_occupancy_authority": &"MovingInteriorFrame",
		"cargo_transfer_authority": false,
		"hero_ship_derived": true,
		"flight_authority": true,
		"landing_authority": true,
		"damage_authority": true,
		"reuse_authority": true,
		"berth_authority": false,
		"combat_authority": false,
		"weapon_authority": false,
		"weapon_definition_valid": _weapon_definition != null and _weapon_definition.is_definition_valid(),
		"weapon_id": WEAPON_ID,
		"game_flow_authority": false,
		"network_authority": false,
	}.duplicate(true)


func _build_weapon_definition() -> WeaponDefinition:
	var definition := WeaponDefinitionType.new() as WeaponDefinition
	definition.weapon_id = WEAPON_ID
	definition.display_name = "Cinder cargo mass driver"
	definition.resolution_mode = WeaponDefinition.ResolutionMode.PROJECTILE
	definition.evidence_status = WeaponDefinition.EvidenceStatus.NEW
	definition.evidence_notes = "Original-modern cargo defensive tuning; not a recovered historical weapon specification."
	definition.range_meters = 180.0
	definition.damage_per_hit = 26.0
	definition.cadence_shots_per_second = 1.8
	definition.presentation_id = &"cinder_cargo_mass_driver"
	definition.fire_audio_id = &"cinder_cargo_mass_driver_fire"
	definition.impact_audio_id = &"cinder_cargo_mass_driver_impact"
	definition.dry_fire_audio_id = &"cinder_cargo_mass_driver_dry_fire"
	return definition


func _build_collision() -> void:
	# The exterior silhouette remains the same, but the old monolithic box made
	# the cargo hold physically unreachable. These shell pieces retain berth-fit
	# outer bounds while leaving the port aperture and cabin deck walkable.
	_add_box_collision_shape("CargoHullFloor", Vector3(0.0, -1.16, 0.0), Vector3(6.4, 0.38, 12.0))
	_add_box_collision_shape("CargoBoardingDeck", Vector3(-3.35, -1.14, 0.0), Vector3(0.70, 0.30, 1.60))
	_add_box_collision_shape("CargoHullRoof", Vector3(0.0, 1.57, 0.0), Vector3(6.4, 0.56, 12.0))
	_add_box_collision_shape("CargoHullStarboardWall", Vector3(3.02, 0.20, 0.0), Vector3(0.76, 2.35, 12.0))
	_add_box_collision_shape("CargoHullPortWallForward", Vector3(-3.02, 0.20, -4.15), Vector3(0.76, 2.35, 3.70))
	_add_box_collision_shape("CargoHullPortWallAft", Vector3(-3.02, 0.20, 4.15), Vector3(0.76, 2.35, 3.70))
	_add_box_collision_shape("CargoHullNoseWall", Vector3(0.0, 0.20, -5.70), Vector3(6.0, 2.35, 0.60))
	_add_box_collision_shape("CargoHullTailWall", Vector3(0.0, 0.20, 5.70), Vector3(6.0, 2.35, 0.60))


func _build_hull(visual: Node3D) -> void:
	var hull := MeshInstance3D.new()
	hull.name = "IndustrialHull"
	if _shared_hull_mesh == null:
		_shared_hull_mesh = BoxMesh.new()
		_shared_hull_mesh.size = HULL_SIZE
		_shared_hull_mesh.resource_local_to_scene = false
	if _shared_hull_material == null:
		_shared_hull_material = _material(HULL_COLOR, 0.72, 0.42)
		_shared_hull_material.resource_local_to_scene = false
	hull.mesh = _shared_hull_mesh
	hull.material_override = _shared_hull_material
	visual.add_child(hull)
	var cargo_pod := MeshInstance3D.new()
	cargo_pod.name = "CargoPod"
	if _shared_cargo_pod_mesh == null:
		_shared_cargo_pod_mesh = BoxMesh.new()
		_shared_cargo_pod_mesh.size = Vector3(5.2, 2.2, 7.2)
		_shared_cargo_pod_mesh.resource_local_to_scene = false
	if _shared_cargo_pod_material == null:
		_shared_cargo_pod_material = _material(CARGO_COLOR, 0.45, 0.42)
		_shared_cargo_pod_material.resource_local_to_scene = false
	cargo_pod.mesh = _shared_cargo_pod_mesh
	cargo_pod.position = Vector3(0.0, 0.15, 1.0)
	cargo_pod.material_override = _shared_cargo_pod_material
	visual.add_child(cargo_pod)
	# Eight bright, repeated load-frame ribs expose the otherwise nested cargo
	# pod as an industrial freight body at gameplay distance. One MultiMesh keeps
	# the cue to a single renderer/submission; it owns no collision or authority.
	var frame_transforms: Array[Transform3D] = []
	var frame_names := PackedStringArray()
	for side in [-1.0, 1.0]:
		var side_name := "Port" if side < 0.0 else "Starboard"
		for z_position in CARGO_FRAME_RIB_Z:
			frame_transforms.append(Transform3D(
				Basis.IDENTITY,
				Vector3(side * CARGO_FRAME_RIB_X, 0.20, z_position)
			))
			frame_names.append("CargoFrame%s%+03d" % [side_name, int(round(z_position * 10.0))])
	_cargo_frame_ribs = _add_visual_box_batch(
		visual,
		"CargoFrameRibBatch",
		CARGO_FRAME_RIB_SIZE,
		frame_transforms,
		CARGO_FRAME_RIB_COLOR,
		frame_names
	)
	_cargo_frame_ribs.set_meta(&"silhouette_role", &"cargo_load_frame")
	_cargo_frame_ribs.set_meta(&"color_independent", true)
	_cargo_frame_ribs.set_meta(&"animated", false)
	_cargo_frame_ribs.set_meta(&"gameplay_distance_meters", 24.0)
	# Four split shoulders give the otherwise rectangular hull a broad freight
	# profile from either approach direction. Their complete bounds remain inside
	# the existing side-wall collision envelope and clear the port aperture.
	_cargo_shoulders = _add_visual_box_batch(
		visual,
		"CargoShoulderBatch",
		CARGO_SHOULDER_SIZE,
		_cargo_shoulder_transforms(ShipComponentDamage.ComponentState.NOMINAL),
		CARGO_COLOR,
		PackedStringArray([
			"CargoShoulderPortForward",
			"CargoShoulderStarboardForward",
			"CargoShoulderPortAft",
			"CargoShoulderStarboardAft",
		])
	)
	_cargo_shoulder_material = _cargo_shoulders.material_override as StandardMaterial3D
	_engine_damage_shoulder_material = _material(
		ENGINE_DAMAGE_SHOULDER_COLOR, 0.28, 0.38,
		ENGINE_DAMAGE_SHOULDER_COLOR, 1.15
	)
	_cargo_shoulders.set_meta(&"silhouette_role", &"cargo_shoulders")
	_cargo_shoulders.set_meta(&"color_independent", true)
	_cargo_shoulders.set_meta(&"damage_component_id", ShipComponentDamage.COMPONENT_ENGINE_BAY)
	_cargo_shoulders.set_meta(&"damage_authority", false)
	_cargo_shoulders.set_meta(&"animated", false)
	_cargo_shoulders.set_meta(&"damage_state", &"nominal")


## Existing freight shoulders become raised isolation rails when the inherited
## engine-bay ledger is impaired. A failure keeps both aft rails rooted in the
## roof/hull structure, but folds the starboard rail inward while the port rail
## remains nearly upright. The cue is steady and observes authority only, so it
## adds no collision or gameplay contract.
func _cargo_shoulder_transforms(state: int) -> Array[Transform3D]:
	var transforms: Array[Transform3D] = [
		Transform3D(Basis.IDENTITY, Vector3(-3.12, 0.25, -3.75)),
		Transform3D(Basis.IDENTITY, Vector3(3.12, 0.25, -3.75)),
		Transform3D(Basis.IDENTITY, Vector3(-3.12, 0.25, 3.75)),
		Transform3D(Basis.IDENTITY, Vector3(3.12, 0.25, 3.75)),
	]
	if state in [
		ShipComponentDamage.ComponentState.IMPAIRED,
		ShipComponentDamage.ComponentState.FAILED,
	]:
		var raised_basis := Basis.IDENTITY.scaled(
			Vector3(1.0, ENGINE_DAMAGE_SHOULDER_Y_SCALE, 1.0)
		)
		transforms[2] = Transform3D(
			raised_basis, Vector3(-ENGINE_DAMAGE_SHOULDER_X, ENGINE_DAMAGE_SHOULDER_Y, 3.75)
		)
		transforms[3] = Transform3D(
			raised_basis, Vector3(ENGINE_DAMAGE_SHOULDER_X, ENGINE_DAMAGE_SHOULDER_Y, 3.75)
		)
		if state == ShipComponentDamage.ComponentState.FAILED:
			var rail_scale := Basis.IDENTITY.scaled(
				Vector3(1.0, ENGINE_FAILED_SHOULDER_Y_SCALE, 1.0)
			)
			var local_root := Vector3(0.0, -CARGO_SHOULDER_SIZE.y * 0.5, 0.0)
			var port_basis := Basis(
				Vector3.BACK, deg_to_rad(-ENGINE_FAILED_PORT_CANT_DEGREES)
			) * rail_scale
			var port_root := Vector3(
				-ENGINE_FAILED_SHOULDER_ROOT_X, ENGINE_FAILED_SHOULDER_ROOT_Y, 3.75
			)
			transforms[2] = Transform3D(
				port_basis, port_root - port_basis * local_root
			)
			var starboard_basis := Basis(
				Vector3.BACK, deg_to_rad(ENGINE_FAILED_STARBOARD_CANT_DEGREES)
			) * rail_scale
			var starboard_root := Vector3(
				ENGINE_FAILED_SHOULDER_ROOT_X, ENGINE_FAILED_SHOULDER_ROOT_Y, 3.75
			)
			transforms[3] = Transform3D(
				starboard_basis, starboard_root - starboard_basis * local_root
			)
	return transforms


func _on_cargo_component_damage_changed(
		component_id: StringName,
		_state: int,
		_integrity: float
	) -> void:
	if component_id == ShipComponentDamage.COMPONENT_ENGINE_BAY:
		_sync_engine_damage_shoulders()


func _sync_engine_damage_shoulders() -> void:
	if not is_instance_valid(_cargo_shoulders) or _cargo_shoulders.multimesh == null:
		return
	var model := get_component_damage()
	var state := ShipComponentDamage.ComponentState.NOMINAL
	if model != null and model.is_configured():
		state = model.get_component_state(ShipComponentDamage.COMPONENT_ENGINE_BAY)
	var damaged := state in [
		ShipComponentDamage.ComponentState.IMPAIRED,
		ShipComponentDamage.ComponentState.FAILED,
	]
	var transforms := _cargo_shoulder_transforms(state)
	var mesh := _cargo_shoulders.multimesh.mesh
	var bounds := AABB()
	for index in transforms.size():
		_cargo_shoulders.multimesh.set_instance_transform(index, transforms[index])
		var instance_bounds := (transforms[index] * mesh.get_aabb()).abs()
		bounds = instance_bounds if index == 0 else bounds.merge(instance_bounds)
	_cargo_shoulders.multimesh.custom_aabb = bounds
	_cargo_shoulders.set_meta(&"presented_instance_transforms", transforms.duplicate())
	_cargo_shoulders.set_meta(&"presented_local_bounds", bounds)
	_cargo_shoulders.material_override = (
		_engine_damage_shoulder_material if damaged else _cargo_shoulder_material
	)
	if damaged and _engine_damage_shoulder_material != null:
		var colour := ENGINE_FAILED_SHOULDER_COLOR \
			if state == ShipComponentDamage.ComponentState.FAILED \
			else ENGINE_DAMAGE_SHOULDER_COLOR
		_engine_damage_shoulder_material.albedo_color = colour
		_engine_damage_shoulder_material.emission = colour
	_cargo_shoulders.set_meta(
		&"damage_state",
		ShipComponentDamage.state_id_for(state) if damaged else &"nominal"
	)


func _build_cargo_hold(visual: Node3D) -> void:
	_cargo_hold = Node3D.new()
	_cargo_hold.name = "CargoHold"
	_cargo_hold.set_meta(&"transfer_anchor_contract", true)
	visual.add_child(_cargo_hold)
	for index in CARGO_CAPACITY:
		var anchor := Marker3D.new()
		anchor.name = "CargoTransferAnchor%02d" % (index + 1)
		anchor.position = Vector3(-2.0 if index % 2 == 0 else 2.0, 0.95, -2.4 + float(index / 2) * 1.6)
		anchor.set_meta(&"cargo_slot_index", index)
		anchor.set_meta(&"transfer_owner", COMPONENT_ID)
		_cargo_hold.add_child(anchor)
		_cargo_anchors.append(anchor)


func _build_cargo_interior() -> void:
	_walkable_interior = Node3D.new()
	_walkable_interior.name = "WalkableInterior"
	_walkable_interior.set_meta(&"space_id", &"cinder_cargo_cabin")
	_walkable_interior.set_meta(&"geometry_status", EVIDENCE_STATUS)
	add_child(_walkable_interior)
	_cargo_cabin = Node3D.new()
	_cargo_cabin.name = "LoadmasterCabin"
	_cargo_cabin.set_meta(&"space_id", &"loadmaster_cabin")
	_cargo_cabin.set_meta(&"route_id", CABIN_ROUTE_ID)
	_walkable_interior.add_child(_cargo_cabin)
	_add_interior_box(_cargo_cabin, "CabinDeck", Vector3(0.0, -0.92, 0.0), Vector3(4.9, 0.12, 5.3), CARGO_COLOR)
	_add_interior_box(_cargo_cabin, "CabinCeiling", Vector3(0.0, 1.28, 0.0), Vector3(4.9, 0.10, 5.3), HULL_COLOR)
	_add_interior_box(_cargo_cabin, "CabinStarboardWall", Vector3(2.35, 0.18, 0.0), Vector3(0.10, 2.0, 5.3), HULL_COLOR)
	_add_visual_box_batch(
		_cargo_cabin,
		"CabinEndWallBatch",
		Vector3(4.7, 2.0, 0.10),
		[
			Transform3D(Basis.IDENTITY, Vector3(0.0, 0.18, -2.55)),
			Transform3D(Basis.IDENTITY, Vector3(0.0, 0.18, 2.55)),
		],
		HULL_COLOR,
		PackedStringArray(["CabinForwardWall", "CabinAftWall"])
	)
	# The port wall is intentionally open between the split outer shell pieces;
	# this is the physical boarding route, not a teleport marker.
	_add_visual_box_batch(
		_cargo_cabin,
		"CrewSeatBaseBatch",
		Vector3(0.86, 0.18, 0.82),
		[
			Transform3D(Basis.IDENTITY, Vector3(0.95, -0.55, 1.10)),
			Transform3D(Basis.IDENTITY, Vector3(-0.95, -0.55, 1.10)),
		],
		ACCENT_COLOR,
		PackedStringArray(["LoadmasterSeatBase", "NavigatorSeatBase"])
	)
	_add_visual_box_batch(
		_cargo_cabin,
		"CrewSeatBackBatch",
		Vector3(0.86, 1.0, 0.14),
		[
			Transform3D(Basis.IDENTITY, Vector3(0.95, 0.08, 1.42)),
			Transform3D(Basis.IDENTITY, Vector3(-0.95, 0.08, 1.42)),
		],
		ACCENT_COLOR,
		PackedStringArray(["LoadmasterSeatBack", "NavigatorSeatBack"])
	)
	# These two immutable console shells have always shared the same dimensions,
	# paint and lifetime. Keep their authored transforms and station identities,
	# but submit them through one presentation-only renderer.
	_crew_console_batch = _add_visual_box_batch(
		_cargo_cabin,
		"CrewConsoleBatch",
		Vector3(0.92, 0.58, 0.08),
		[
			Transform3D(Basis.IDENTITY, Vector3(0.95, 0.20, 0.42)),
			Transform3D(Basis.IDENTITY, Vector3(-0.95, 0.20, 0.42)),
		],
		ACCENT_COLOR,
		PackedStringArray(["LoadmasterConsole", "NavigatorConsole"])
	)
	_crew_console_batch.set_meta(
		&"authored_station_ids",
		PackedStringArray([LOADMASTER_STATION_SEAT_ID, NAVIGATOR_STATION_SEAT_ID])
	)
	_loadmaster_status_panel = _add_interior_box(
		_cargo_cabin,
		"LoadmasterStatusPanel",
		Vector3(-0.15, 0.42, -2.28),
		Vector3(1.45, 0.72, 0.06),
		ACCENT_COLOR
	)
	_loadmaster_status_panel.set_meta(&"presentation_only", true)
	_loadmaster_status_panel.set_meta(&"color_independent", true)
	_loadmaster_status_display = Label3D.new()
	_loadmaster_status_display.name = "LoadmasterStatusDisplay"
	_loadmaster_status_display.position = Vector3(-0.15, 0.43, -2.33)
	_loadmaster_status_display.font_size = 24
	_loadmaster_status_display.pixel_size = 0.0012
	_loadmaster_status_display.modulate = Color("f2ffff")
	_loadmaster_status_display.outline_modulate = Color("07111d")
	_loadmaster_status_display.outline_size = 8
	_loadmaster_status_display.no_depth_test = true
	_loadmaster_status_display.set_meta(&"presentation_only", true)
	_loadmaster_status_display.set_meta(&"color_independent", true)
	_loadmaster_status_display.set_meta(&"station_id", LOADMASTER_STATION_SEAT_ID)
	_cargo_cabin.add_child(_loadmaster_status_display)
	_update_loadmaster_status_display(&"available", &"", &"")
	_loadmaster_station_anchor = Marker3D.new()
	_loadmaster_station_anchor.name = "LoadmasterStationAnchor"
	_loadmaster_station_anchor.position = Vector3(0.95, -0.30, 1.10)
	_loadmaster_station_anchor.set_meta(&"seat_id", LOADMASTER_STATION_SEAT_ID)
	_loadmaster_station_anchor.set_meta(&"role", CrewRoleGameplayProfileType.ROLE_PASSENGER)
	_loadmaster_station_anchor.set_meta(&"seat_type", &"physical")
	_loadmaster_station_anchor.set_meta(&"route_id", CABIN_ROUTE_ID)
	_loadmaster_station_anchor.set_meta(&"seat_generation", 1)
	_cargo_cabin.add_child(_loadmaster_station_anchor)
	_loadmaster_interaction = CinderLoadmasterInteraction.new()
	_loadmaster_interaction.name = "LoadmasterStationInteraction"
	_loadmaster_interaction.position = _loadmaster_station_anchor.position + Vector3(0.0, 0.0, -0.72)
	_loadmaster_interaction.configure(
		self,
		LOADMASTER_STATION_SEAT_ID,
		1,
		LOADMASTER_INTERACTION_REACH
	)
	_loadmaster_interaction.set_meta(&"station_id", LOADMASTER_STATION_SEAT_ID)
	_loadmaster_interaction.set_meta(&"route_id", CABIN_ROUTE_ID)
	_loadmaster_interaction.set_meta(&"authority_owner", &"CrewSeatRoleAuthority")
	_cargo_cabin.add_child(_loadmaster_interaction)
	_navigator_station_anchor = Marker3D.new()
	_navigator_station_anchor.name = "NavigatorStationAnchor"
	_navigator_station_anchor.position = Vector3(-0.95, -0.30, 1.10)
	_navigator_station_anchor.set_meta(&"seat_id", NAVIGATOR_STATION_SEAT_ID)
	_navigator_station_anchor.set_meta(&"role", CrewRoleGameplayProfileType.ROLE_PASSENGER)
	_navigator_station_anchor.set_meta(&"seat_type", &"physical")
	_navigator_station_anchor.set_meta(&"route_id", NAVIGATOR_ROUTE_ID)
	_navigator_station_anchor.set_meta(&"seat_generation", 1)
	_cargo_cabin.add_child(_navigator_station_anchor)
	_navigator_interaction = CinderNavigatorInteraction.new()
	_navigator_interaction.name = "NavigatorStationInteraction"
	_navigator_interaction.position = _navigator_station_anchor.position + Vector3(0.0, 0.0, -0.72)
	_navigator_interaction.configure(
		self,
		NAVIGATOR_STATION_SEAT_ID,
		1,
		LOADMASTER_INTERACTION_REACH
	)
	_navigator_interaction.set_meta(&"station_id", NAVIGATOR_STATION_SEAT_ID)
	_navigator_interaction.set_meta(&"route_id", NAVIGATOR_ROUTE_ID)
	_navigator_interaction.set_meta(&"authority_owner", &"CrewSeatRoleAuthority")
	_cargo_cabin.add_child(_navigator_interaction)
	var access := Marker3D.new()
	access.name = "CargoCabinAccessMarker"
	access.position = Vector3(-2.20, -0.30, 0.0)
	access.set_meta(&"route_id", CABIN_ROUTE_ID)
	_walkable_interior.add_child(access)
	var exit := Marker3D.new()
	exit.name = "CargoCabinExitMarker"
	exit.position = Vector3(-2.75, -0.82, 0.0)
	exit.set_meta(&"route_id", CABIN_ROUTE_ID)
	_walkable_interior.add_child(exit)
	_occupant_volume = Area3D.new()
	_occupant_volume.name = "InteriorOccupantVolume"
	_occupant_volume.collision_layer = PhysicsLayers.INTERACTABLE_AREA_LAYER
	_occupant_volume.collision_mask = PhysicsLayers.PLAYER_BODY_LAYER
	_occupant_volume.monitoring = true
	_occupant_volume.monitorable = false
	_occupant_volume.set_meta(&"ship_local_bounds", INTERIOR_BOUNDS)
	_walkable_interior.add_child(_occupant_volume)
	var volume_shape := CollisionShape3D.new()
	volume_shape.name = "InteriorBoundsShape"
	volume_shape.position = INTERIOR_BOUNDS.get_center()
	var volume_box := BoxShape3D.new()
	volume_box.size = INTERIOR_BOUNDS.size
	volume_shape.shape = volume_box
	_occupant_volume.add_child(volume_shape)


func _add_interior_box(
		parent: Node3D,
		node_name: String,
		position_value: Vector3,
		size: Vector3,
		colour: Color
) -> MeshInstance3D:
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = node_name
	mesh_instance.position = position_value
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh_instance.mesh = mesh
	mesh_instance.material_override = _material(colour, 0.42, 0.62)
	parent.add_child(mesh_instance)
	return mesh_instance


## Repeated, childless presentation stock shares one submission while retaining
## its authored local transforms and semantic names for inspection.
func _add_visual_box_batch(
		parent: Node3D,
		node_name: String,
		size: Vector3,
		transforms: Array[Transform3D],
		colour: Color,
		authored_names: PackedStringArray
	) -> MultiMeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	var multi := MultiMesh.new()
	multi.transform_format = MultiMesh.TRANSFORM_3D
	multi.mesh = mesh
	multi.instance_count = transforms.size()
	multi.visible_instance_count = -1
	var bounds := AABB()
	for index in transforms.size():
		multi.set_instance_transform(index, transforms[index])
		var instance_bounds := (transforms[index] * mesh.get_aabb()).abs()
		bounds = instance_bounds if index == 0 else bounds.merge(instance_bounds)
	multi.custom_aabb = bounds
	var batch := MultiMeshInstance3D.new()
	batch.name = node_name
	batch.multimesh = multi
	batch.material_override = _material(colour, 0.42, 0.62)
	batch.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	batch.set_meta(&"presentation_only", true)
	batch.set_meta(&"authored_visual_names", authored_names.duplicate())
	batch.set_meta(&"authored_instance_transforms", transforms.duplicate())
	parent.add_child(batch)
	return batch


func _bind_cargo_interior_frame() -> void:
	_moving_interior_component = MovingInteriorFrame.new()
	_moving_interior_component.name = "MovingInteriorFrame"
	_moving_interior_component.set_meta(&"frame_id", &"cinder_cargo_walkable_interior")
	_moving_interior_component.auto_register_from_volume = true
	add_child(_moving_interior_component)
	_moving_interior_component.configure(self, INTERIOR_BOUNDS, _occupant_volume)
	_moving_interior_component.occupant_registered.connect(_on_interior_occupant_registered)
	_moving_interior_component.occupant_unregistered.connect(_on_interior_occupant_unregistered)
	_moving_interior_component.call_deferred("_register_existing_overlaps")


func _on_interior_occupant_registered(_occupant: Node3D) -> void:
	_sync_interior_occupant_collision()


func _on_interior_occupant_unregistered(
		_occupant: Node3D,
		_exit_velocity: Vector3,
		_reason: StringName
) -> void:
	_sync_interior_occupant_collision()


func _sync_interior_occupant_collision() -> void:
	_interior_occupant_count = (
		_moving_interior_component.get_occupant_count()
		if _moving_interior_component != null else 0
	)
	if is_destroyed():
		return
	collision_mask = PhysicsLayers.SHIP_BODY_MASK & ~PhysicsLayers.PLAYER \
		if _interior_occupant_count > 0 else PhysicsLayers.SHIP_BODY_MASK


func _commit_variant_reset_for_reuse(context: Dictionary) -> void:
	super._commit_variant_reset_for_reuse(context)
	_sync_engine_damage_shoulders()
	_clear_loadmaster_manifest(&"ship_reused", false)
	_loadmaster_manifest_generation = 1
	if _moving_interior_component != null and is_instance_valid(_moving_interior_component):
		_moving_interior_component.configure(self, INTERIOR_BOUNDS, _occupant_volume)
		_moving_interior_component.reset_frame_tracking(true)
	if _loadmaster_interaction != null:
		_loadmaster_interaction.clear_for_detach()
		_loadmaster_interaction.refresh_availability()
	if _navigator_interaction != null:
		_navigator_interaction.clear_for_detach()
		_navigator_interaction.refresh_availability()
	_clear_navigator_ping(&"ship_reused")
	_sync_interior_occupant_collision()


func _cleanup_detached_loadmaster() -> void:
	if _loadmaster_manifest_receipt.is_empty():
		return
	if _crew_role_authority == null:
		_clear_loadmaster_manifest(&"authority_detached")
		return
	var assignment := _crew_role_authority.get_assignment(
		int(_loadmaster_manifest_receipt.get("occupant_peer_id", 0)),
		StringName(_loadmaster_manifest_receipt.get("avatar_id", &""))
	)
	if assignment.is_empty() \
			or StringName(assignment.get("seat_id", &"")) != LOADMASTER_STATION_SEAT_ID \
			or int(assignment.get("seat_generation", 0)) != int(_loadmaster_manifest_receipt.get("seat_generation", 0)):
		_clear_loadmaster_manifest(&"role_detached")


func _clear_loadmaster_manifest(reason: StringName, advance_generation: bool = true) -> void:
	_loadmaster_manifest_receipt.clear()
	if advance_generation:
		_loadmaster_manifest_generation = mini(
			_loadmaster_manifest_generation + 1,
			LOADMASTER_MANIFEST_GENERATION_MAX
		)
	loadmaster_manifest_cleared.emit(_loadmaster_manifest_generation, reason)
	var state: StringName = &"released" if reason in [&"role_released", &"role_detached"] else &"available"
	_update_loadmaster_status_display(state, &"", &"")


func _update_loadmaster_status_display(
		state: StringName,
		manifest_id: StringName,
		route_id: StringName
) -> void:
	_loadmaster_status_snapshot = {
		"schema_version": 1,
		"state": state,
		"manifest_id": manifest_id,
		"route_id": route_id,
		"generation": _loadmaster_manifest_generation,
		"presentation_only": true,
		"color_independent": true,
	}
	if not is_instance_valid(_loadmaster_status_display):
		return
	var roster_reading := _loadmaster_roster_reading(state)
	_loadmaster_status_snapshot["roster_shape"] = roster_reading["shape"]
	_loadmaster_status_snapshot["roster_status"] = roster_reading["status"]
	_loadmaster_status_display.text = (
		"LOADMASTER\nROSTER %s %s\nMANIFEST %s\nROUTE %s"
		% [
			roster_reading["shape"],
			roster_reading["status"],
			str(manifest_id) if not manifest_id.is_empty() else "--",
			str(route_id) if not route_id.is_empty() else "--",
		]
	)


func _loadmaster_roster_reading(state: StringName) -> Dictionary:
	if not _loadmaster_manifest_receipt.is_empty():
		return {"shape": "[=]", "status": "SECURED"} \
			if bool(_loadmaster_manifest_receipt.get("ready", false)) \
			else {"shape": "[!]", "status": "BLOCKED"}
	match state:
		&"occupied":
			return {"shape": "[>]", "status": "LOADING"}
		&"available", &"released":
			return {"shape": "[/]", "status": "DETACHED"}
		_:
			return {"shape": "[X]", "status": "FAULT"}


func _crew_role_result(accepted: bool, status: StringName) -> Dictionary:
	return {
		"accepted": accepted,
		"status": status,
		"ship_id": get_ship_id(),
		"station_id": LOADMASTER_STATION_SEAT_ID,
	}.duplicate(true)
