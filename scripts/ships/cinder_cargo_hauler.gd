class_name CinderCargoHauler
extends HeroShip

const WeaponDefinitionType := preload("res://scripts/combat/weapon_definition.gd")
const ShipPerspectiveAudioBindingType := preload("res://scripts/audio/ship_perspective_audio_binding.gd")
const CrewSeatRoleAuthorityType := preload("res://scripts/ships/crew_seat_role_authority.gd")
const CrewRoleGameplayProfileType := preload("res://scripts/fleet/crew_role_gameplay_profile.gd")
const SHIP_DEFINITION_TEMPLATE: ShipDefinition = preload(
	"res://assets/ships/cinder_cargo_hauler_new_design.tres"
)

## Original-modern industrial cargo craft component. No historical class,
## silhouette, cargo contract, or ownership claim is authenticated here.

const SCHEMA_VERSION := 1
const COMPONENT_ID: StringName = &"cinder_cargo_hauler"
const EVIDENCE_STATUS: StringName = &"NEW"
const DISPLAY_NAME := "Cinder cargo hauler"
const CARGO_CAPACITY := 8
const HULL_SIZE := Vector3(6.4, 3.2, 12.0)
const CARGO_POD_SIZE := Vector3(5.2, 2.2, 7.2)
const CARGO_POD_POSITION := Vector3(0.0, 0.15, 1.0)
## The live collision and walkable cabin already leave this port-side doorway
## open. These bounds cut the same route through both nested exterior recipes,
## preventing their former full box faces from becoming opaque blockers.
const PORT_APERTURE_Y_MIN := -0.97
const PORT_APERTURE_Y_MAX := 1.29
const PORT_APERTURE_Z_MIN := -2.30
const PORT_APERTURE_Z_MAX := 2.30
const EXTERIOR_SHELL_THICKNESS := 0.30
const WEAPON_ID: StringName = &"cinder_cargo_mass_driver"
const LOADMASTER_STATION_SEAT_ID: StringName = &"cinder_loadmaster_station"
const NAVIGATOR_STATION_SEAT_ID: StringName = &"cinder_navigator_station"
const INTERIOR_BOUNDS := AABB(Vector3(-2.55, -0.95, -2.80), Vector3(5.10, 2.10, 5.60))
const CABIN_ROUTE_ID: StringName = &"cinder_cargo_port_aperture"
const NAVIGATOR_ROUTE_ID: StringName = &"cinder_navigator_console"
const LOADMASTER_MANIFEST_GENERATION_MAX := 1_000_000
const LOADMASTER_INTERACTION_REACH := 1.20

const HULL_COLOR := Color("657373")
const CARGO_COLOR := Color("5c6563")
const ACCENT_COLOR := Color("79a1a5")
const CARGO_SHOULDER_SIZE := Vector3(0.42, 0.72, 2.90)
## Repeated exterior load-frame ribs make the freight body legible from the
## normal side/rear approach. Their full bounds remain inside the existing
## 6.8 m-wide collision shell and clear the physical port boarding aperture.
const CARGO_FRAME_RIB_SIZE := Vector3(0.14, 2.40, 0.34)
const CARGO_FRAME_RIB_COLOR := Color("8b989d")
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
static var _shared_hull_mesh: ArrayMesh
static var _shared_hull_material: StandardMaterial3D
# The cargo pod is likewise static exterior presentation. Keep its renderer
# local so a craft can be detached independently, while sharing its immutable
# geometry and paint recipe across simultaneously retained haulers.
static var _shared_cargo_pod_mesh: ArrayMesh
static var _shared_cargo_pod_material: StandardMaterial3D
static var _shared_freight_load_frame: ArrayMesh
static var _shared_engine_mounts: ArrayMesh


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

static var _shared_engine_exhaust_mesh: WeakRef

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


# This hull has no authored idle cannon lens. A shot-clearance marker is
# gameplay authority, not a mounting surface for a permanent cyan sphere.
func _uses_weapon_component_fallback_emitters() -> bool:
	return false


func _uses_torrent_reconstruction_presentation() -> bool:
	return false


func _enter_tree() -> void:
	super._enter_tree()
	if _ship_perspective_audio_binding != null:
		call_deferred("_rebind_cargo_perspective_audio")
	if _cargo_shoulders != null:
		call_deferred("_sync_engine_damage_shoulders")


func _ready() -> void:
	# The production binding creates this script directly, so install a private
	# copy of the authored profile before HeroShip initializes hull and handling.
	ship_definition = SHIP_DEFINITION_TEMPLATE.duplicate(true) as ShipDefinition
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
	_build_engine_exhaust(visual)
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
	_build_cargo_entry(visual)
	_cargo_access_sign = Label3D.new()
	_cargo_access_sign.name = "CargoAccessSign"
	_cargo_access_sign.position = Vector3(-3.43, 1.31, 0.0)
	_cargo_access_sign.rotation.y = -PI * 0.5
	_cargo_access_sign.font_size = 24
	_cargo_access_sign.pixel_size = 0.0020
	_cargo_access_sign.modulate = Color("f2ffff")
	_cargo_access_sign.outline_modulate = Color("07111d")
	_cargo_access_sign.outline_size = 8
	_cargo_access_sign.no_depth_test = false
	_cargo_access_sign.text = "CARGO ACCESS\nLOADMASTER"
	_cargo_access_sign.set_meta(&"presentation_only", true)
	_cargo_access_sign.set_meta(&"route_id", CABIN_ROUTE_ID)
	_cargo_access_sign.set_meta(&"color_independent", true)
	visual.add_child(_cargo_access_sign)
	_cargo_threshold_light = OmniLight3D.new()
	_cargo_threshold_light.name = "CargoThresholdLight"
	_cargo_threshold_light.position = Vector3(-2.65, 0.85, 0.0)
	_cargo_threshold_light.light_color = Color("d8e8e5")
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
	if ship_definition == null \
			or not ship_definition.is_definition_valid() \
			or ship_definition.get_ship_id() != COMPONENT_ID:
		errors.append("authored cargo-hauler flight definition is not applied")
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
	var sill_finish := _material(Color("586569"), 0.48, 0.42)
	for sill_name in ["PortSill", "StarboardSill"]:
		var sill := visual.find_child(sill_name, true, false) as MeshInstance3D
		if sill != null:
			sill.material_override = sill_finish
	var hull := MeshInstance3D.new()
	hull.name = "IndustrialHull"
	if _shared_hull_mesh == null:
		_shared_hull_mesh = _port_aperture_shell_mesh(
			HULL_SIZE,
			PORT_APERTURE_Y_MIN,
			PORT_APERTURE_Y_MAX,
			PORT_APERTURE_Z_MIN,
			PORT_APERTURE_Z_MAX,
			EXTERIOR_SHELL_THICKNESS
		)
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
	var cargo_pod := MeshInstance3D.new()
	cargo_pod.name = "CargoPod"
	if _shared_cargo_pod_mesh == null:
		_shared_cargo_pod_mesh = _port_aperture_shell_mesh(
			CARGO_POD_SIZE,
			PORT_APERTURE_Y_MIN - CARGO_POD_POSITION.y,
			PORT_APERTURE_Y_MAX - CARGO_POD_POSITION.y,
			PORT_APERTURE_Z_MIN - CARGO_POD_POSITION.z,
			PORT_APERTURE_Z_MAX - CARGO_POD_POSITION.z,
			EXTERIOR_SHELL_THICKNESS
		)
		_shared_cargo_pod_mesh.resource_local_to_scene = false
	if _shared_cargo_pod_material == null:
		_shared_cargo_pod_material = _material(CARGO_COLOR, 0.12, 0.62)
		_shared_cargo_pod_material.resource_local_to_scene = false
	cargo_pod.mesh = _shared_cargo_pod_mesh
	cargo_pod.position = CARGO_POD_POSITION
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
			var end_ratio := clampf((absf(z_position) / 6.0 - 0.66) / 0.34, 0.0, 1.0)
			var rib_x := HULL_SIZE.x * 0.5 * lerpf(1.0, 0.80, end_ratio) + CARGO_FRAME_RIB_X - HULL_SIZE.x * 0.5
			var cant: float = -side * signf(z_position) * atan(0.64 / 2.04) if end_ratio > 0.0 else 0.0
			frame_transforms.append(Transform3D(
				Basis(Vector3.UP, cant),
				Vector3(side * rib_x, 0.20, z_position)
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
	_build_freight_pressure_fairings(visual)
	_build_continuous_load_frame(visual)
	ShipSurfaceDetail.mark_surface(visual, "ForwardFreightRegistration", "cinder-cargo", Vector3(0, 0, -6.135), Vector2(2.25, 1.125), Vector3.FORWARD, Vector3.UP)
	ShipSurfaceDetail.mark_surface(visual, "AftFreightRegistration", "cinder-cargo", Vector3(0, 0, 6.135), Vector2(2.25, 1.125), Vector3.BACK, Vector3.UP)
	ShipSurfaceDetail.mark_surface(visual, "CrewAccessMark", "rescue", Vector3(-3.34, 0.25, -3.75), Vector2(1.35, 0.675), Vector3.LEFT, Vector3.UP)


## The freight pressure vessel keeps its exact doorway and cabin. Shaped end
## caps, segmented roof armor and isolated engine pods turn that necessary
## rectangular interior into a manufactured transport exterior.
func _build_freight_pressure_fairings(visual: Node3D) -> void:
	var dark := _material(Color("1b2931"), 0.5, 0.48)
	var metal := _material(Color("73858c"), 0.82, 0.32)
	_pressure_panel(visual, "CockpitPressureTransition", Vector3(0, 1.715, -0.55), 2.1, 3.1, 0.35, 3.4, _shared_hull_material)
	for z in [2.0, 3.2]:
		var plate := _pressure_panel(visual, "FreightRoofArmor" + str(z), Vector3(0, 1.635, z), 3.1, 3.3, 1.04, 0.05, dark)
		plate.rotation.x = PI * 0.5
	for end in [-1.0, 1.0]:
		var bulkhead := Node3D.new()
		bulkhead.name = "ForwardBulkhead" if end < 0 else "AftBulkhead"
		bulkhead.position = Vector3(0, 0, end * 6.115)
		bulkhead.rotation.x = end * PI * 0.5
		visual.add_child(bulkhead)
		_deck_plate(bulkhead, "PressureCover", Vector3.ZERO, 3.62, 1.51, _shared_hull_material, dark)
		for x in [-1.36, 1.36]:
			_service_bay(bulkhead, "Latch" + str(x), Vector3(x, 0.05, 0), 0.35, 0.92, metal, dark, dark)
		for side in [-1.0, 1.0]:
			_box(visual, "CornerCrashBeam" + str(end) + str(side), Vector3(side * 2.02, -0.08, end * 6.0), Vector3(0.18, 1.90, 0.24), dark)
			_box(visual, "CargoCornerTie" + str(end) + str(side), Vector3(side * 2.02, 0.43, end * 6.11), Vector3(0.32, 0.21, 0.17), metal)
	for z in [-3.6, 3.7]:
		_deck_plate(visual, "RoofService" + str(z), Vector3(0, 1.638, z), 3.45, 0.68, _shared_hull_material, dark)

	var fore := _pressure_panel(visual, "ForwardPressureCap", Vector3(0, 0, -6.03), 4.0, 4.50, 0.16, 2.35, _shared_hull_material)
	fore.rotation.x = -PI * 0.5
	var aft := _pressure_panel(visual, "AftPressureCap", Vector3(0, 0, 6.03), 4.0, 4.50, 0.16, 2.35, _shared_hull_material)
	aft.rotation.x = PI * 0.5
	for side in [-1.0, 1.0]:
		var tag := "Port" if side < 0 else "Starboard"
		var cradle := MeshInstance3D.new()
		cradle.name = tag + "FreightCradle"
		cradle.mesh = _freight_cradle_mesh(side)
		cradle.material_override = dark
		visual.add_child(cradle)
		_service_bay(visual, tag + "FreightThermalService", Vector3(side * 2.3, 1.695, 0.4), 0.66, 1.5, _shared_hull_material, dark, metal)
		# All side pods stop behind the protected boarding aperture (z > 2.30).
		_armor_shell(visual, tag + "EnginePylon", Vector3(side * 3.03, 0.38, 4.12), Vector3(1.55, 1.20, 3.25), _shared_hull_material)
		_armor_shell(visual, tag + "EngineShroud", Vector3(side * 3.75, 0.4, 4.45), Vector3(1.62, 1.62, 3.5), dark)
		preload("res://scripts/ships/cinder_exhaust_machinery.gd").bell(visual, tag + "FreightExhaust", Vector3(side * 3.75, 0.4, 6.40), 0.75, 0.55, 0.65, metal)
		_cylinder(visual, tag + "RecessedThroat", Vector3(side * 3.75, 0.4, 6.20), 0.45, 0.08, dark, Vector3(90, 0, 0))
		_engine_mechanics(visual, tag, Vector3(side * 3.75, 0.4, 6.59), 0.64, metal, dark)
		for z in [4.15, 5.15]:
			_deck_plate(visual, tag + "NacelleAccess" + str(z), Vector3(side * 3.75, 1.218 if z < 5.0 else 1.19, z), 0.85, 0.65, _shared_hull_material, dark)
		var radiator := Node3D.new()
		radiator.name = tag + "NacelleRadiator"
		radiator.position = Vector3(side * 4.565, 0.4, 4.60)
		radiator.rotation.z = side * -PI * 0.5
		visual.add_child(radiator)
		_service_bay(radiator, "Cooling", Vector3.ZERO, 0.46, 1.05, metal, dark, dark)
	_build_engine_mounts(visual)


## Two retained saddles transfer each nacelle into the freight structure. Their
## collars follow the existing tapered shroud; closed shear webs seat on the
## pressure roof, leaving the service panels and the failed shoulder rails free.
## Both sides and simultaneous craft reuse the same immutable mounting stock.
func _build_engine_mounts(visual: Node3D) -> void:
	if _shared_engine_mounts == null:
		var surface := SurfaceTool.new()
		surface.begin(Mesh.PRIMITIVE_TRIANGLES)
		var section := PackedVector2Array([
			Vector2(0.62, 1), Vector2(0.91, 0.80), Vector2(1, 0.40),
			Vector2(1, -0.40), Vector2(0.91, -0.80), Vector2(0.62, -1),
			Vector2(-0.62, -1), Vector2(-0.91, -0.80), Vector2(-1, -0.40),
			Vector2(-1, 0.40), Vector2(-0.91, 0.80), Vector2(-0.62, 1),
		])
		for z in [3.65, 4.65]:
			# Two annular stations produce an open collar, never an opaque
			# plug through the engine. Every face has a metric UV projection.
			var rings: Array[PackedVector3Array] = []
			for station in [z - 0.12, z + 0.12]:
				var t: float = (station - 2.70) / 3.5
				var width := minf(1.0, lerpf(0.12, 1.0, t / 0.43)) * 0.81
				var height := minf(1.0, lerpf(0.35, 1.0, t / 0.28)) * 0.81
				for offset in [-0.015, 0.075]:
					var ring := PackedVector3Array()
					for point in section:
						ring.append(Vector3(3.75 + point.x * (width + offset), 0.4 + point.y * (height + offset), station))
					rings.append(ring)
			for edge in section.size():
				var next := (edge + 1) % section.size()
				_mount_quad(surface, rings[1][edge], rings[1][next], rings[3][next], rings[3][edge])
				_mount_quad(surface, rings[0][next], rings[0][edge], rings[2][edge], rings[2][next])
				_mount_quad(surface, rings[0][edge], rings[0][next], rings[1][next], rings[1][edge])
				_mount_quad(surface, rings[3][edge], rings[3][next], rings[2][next], rings[2][edge])
			var taper := clampf((z / 6.0 - 0.66) / 0.34, 0.0, 1.0)
			var root_x := 2.78
			var shoulder_x := root_x / lerpf(1.0, 0.80, taper)
			var shoulder_arc := (shoulder_x - 2.5) / 0.70
			var root_y := (1.3 + 0.30 * sqrt(1.0 - shoulder_arc * shoulder_arc)) * lerpf(1.0, 0.82, taper)
			# A broad top flange and sloping web span the pylon joint; the
			# root is embedded in the static roof, never the damage shoulders.
			var web := PackedVector2Array([
				Vector2(root_x, root_y - 0.07), Vector2(root_x, root_y + 0.13),
				Vector2(root_x + 0.27, root_y + 0.13), Vector2(3.58, 1.31),
				Vector2(3.93, 1.29), Vector2(3.93, 1.13), Vector2(3.48, 1.13),
			])
			for edge in web.size():
				var next := (edge + 1) % web.size()
				_mount_quad(surface, Vector3(web[edge].x, web[edge].y, z - 0.12),
					Vector3(web[next].x, web[next].y, z - 0.12),
					Vector3(web[next].x, web[next].y, z + 0.12), Vector3(web[edge].x, web[edge].y, z + 0.12))
			var triangles := Geometry2D.triangulate_polygon(web)
			for end in [-1.0, 1.0]:
				for triangle in range(0, triangles.size(), 3):
					var order := [0, 1, 2] if end < 0 else [2, 1, 0]
					for corner in order:
						var point := web[triangles[triangle + corner]]
						surface.set_normal(Vector3(0, 0, end))
						surface.set_uv(point)
						surface.add_vertex(Vector3(point.x, point.y, z + end * 0.12))
		# Bake the mirror with reversed winding and reflected normals. A
		# negative renderer scale produces inverted lighting on this stock.
		var starboard := surface.commit()
		var arrays := starboard.surface_get_arrays(0)
		var points: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
		var uv: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
		for triangle in range(0, points.size(), 3):
			for corner in [0, 2, 1]:
				var i: int = triangle + corner
				surface.set_normal(normals[i] * Vector3(-1, 1, 1))
				surface.set_uv(uv[i])
				surface.add_vertex(points[i] * Vector3(-1, 1, 1))
		surface.generate_tangents()
		_shared_engine_mounts = surface.commit()
		_shared_engine_mounts.resource_local_to_scene = false
	var mounts := MeshInstance3D.new()
	mounts.name = "EngineRetentionSaddles"
	mounts.mesh = _shared_engine_mounts
	mounts.material_override = _shared_hull_material
	mounts.set_meta(&"presentation_only", true)
	visual.add_child(mounts)


static func _mount_quad(surface: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3) -> void:
	var normal := (c - a).cross(b - a).normalized()
	var u_axis := (b - a).normalized()
	var v_axis := normal.cross(u_axis)
	for point in [a, b, c, a, c, d]:
		surface.set_normal(normal)
		surface.set_uv(Vector2((point - a).dot(u_axis), (point - a).dot(v_axis)))
		surface.add_vertex(point)


## Cargo restraints carry around the roof and into the lower side frame instead of
## ending as isolated vertical trim. The same immutable frame stock is retained
## by every hauler; it neither crosses the open port route nor owns collision.
func _build_continuous_load_frame(visual: Node3D) -> void:
	if _shared_freight_load_frame == null:
		var vertices := PackedVector3Array()
		var normals := PackedVector3Array()
		var indices := PackedInt32Array()
		for z in CARGO_FRAME_RIB_Z:
			var end_ratio := clampf((absf(z) / 6.0 - 0.66) / 0.34, 0.0, 1.0)
			var sx := lerpf(1.0, 0.80, end_ratio)
			var sy := lerpf(1.0, 0.82, end_ratio)
			var path := PackedVector2Array([
				Vector2(-3.22 * sx, -1.04 * sy), Vector2(-3.22 * sx, 1.30 * sy),
				Vector2(-3.03 * sx, 1.54 * sy), Vector2(-2.48 * sx, 1.65 * sy),
				Vector2(2.48 * sx, 1.65 * sy), Vector2(3.03 * sx, 1.54 * sy),
				Vector2(3.22 * sx, 1.30 * sy), Vector2(3.22 * sx, -1.04 * sy),
			])
			_append_load_band(vertices, normals, indices, path, z, 0.30)
		var arrays := []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = vertices
		arrays[Mesh.ARRAY_NORMAL] = normals
		arrays[Mesh.ARRAY_INDEX] = indices
		_shared_freight_load_frame = ArrayMesh.new()
		_shared_freight_load_frame.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		_shared_freight_load_frame.resource_local_to_scene = false
	var frame := MeshInstance3D.new()
	frame.name = "ContinuousFreightLoadFrame"
	frame.mesh = _shared_freight_load_frame
	frame.material_override = _shared_hull_material
	visual.add_child(frame)


static func _append_load_band(vertices: PackedVector3Array, normals: PackedVector3Array,
		indices: PackedInt32Array, path: PackedVector2Array, z: float, width: float) -> void:
	var rings: Array[PackedVector3Array] = []
	for i in path.size():
		var tangent := (path[mini(i + 1, path.size() - 1)] - path[maxi(0, i - 1)]).normalized()
		var out := Vector2(-tangent.y, tangent.x)
		var point := path[i]
		var inner := point - out * 0.045
		var outer := point + out * 0.07
		rings.append(PackedVector3Array([
			Vector3(outer.x, outer.y, z - width * 0.5), Vector3(outer.x, outer.y, z + width * 0.5),
			Vector3(inner.x, inner.y, z + width * 0.5), Vector3(inner.x, inner.y, z - width * 0.5),
		]))
	for i in rings.size() - 1:
		var mid := (path[i] + path[i + 1]) * 0.5
		var out := Vector3(mid.x, maxf(mid.y, 0.0), 0).normalized()
		for edge in 4:
			var next := (edge + 1) % 4
			_append_shell_quad(vertices, normals, indices, rings[i][edge], rings[i][next], rings[i + 1][next], rings[i + 1][edge],
				[out, Vector3.BACK, -out, Vector3.FORWARD][edge])
	for cap in [0, rings.size() - 1]:
		_append_shell_quad(vertices, normals, indices, rings[cap][0], rings[cap][1], rings[cap][2], rings[cap][3], Vector3.DOWN)


## Continuous load rails follow the pressure roof's end taper. Their seating
## faces stay on the skin rather than emerging from intersecting wedge stock.
func _freight_cradle_mesh(side: float) -> ArrayMesh:
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var indices := PackedInt32Array()
	var rings: Array[PackedVector3Array] = []
	for z in [-5.72, -5.46, -3.96, 3.96, 5.46, 5.72]:
		var end_ratio := clampf((absf(z) / 6.0 - 0.66) / 0.34, 0.0, 1.0)
		var width_scale := lerpf(1.0, 0.80, end_ratio)
		var y := 1.6 * lerpf(1.0, 0.82, end_ratio)
		var center_x := side * 1.82 * width_scale
		var width := 0.22 if absf(z) < 5.6 else 0.12
		rings.append(PackedVector3Array([
			Vector3(center_x - width * 0.5, y + 0.065, z),
			Vector3(center_x + width * 0.5, y + 0.065, z),
			Vector3(center_x + width * 0.5, y - 0.025, z),
			Vector3(center_x - width * 0.5, y - 0.025, z),
		]))
	for bay in rings.size() - 1:
		for edge in 4:
			var next := (edge + 1) % 4
			_append_shell_quad(vertices, normals, indices,
				rings[bay][edge], rings[bay][next], rings[bay + 1][next], rings[bay + 1][edge],
				[Vector3.UP, Vector3.RIGHT, Vector3.DOWN, Vector3.LEFT][edge])
	for cap in [0, rings.size() - 1]:
		_append_shell_quad(vertices, normals, indices, rings[cap][0], rings[cap][1], rings[cap][2], rings[cap][3], Vector3.FORWARD if cap == 0 else Vector3.BACK)
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh


## One formed exterior surface with a bounded port aperture. The full cabin
## stations retain the existing AABB while the sealed end bays taper; four
## reveal faces prevent a hollow/backface seam around the doorway. Cabin-local
## deck, ceiling, starboard and end walls remain the interior presentation.
static func _port_aperture_shell_mesh(
		size: Vector3,
		aperture_y_min: float,
		aperture_y_max: float,
		aperture_z_min: float,
		aperture_z_max: float,
		thickness: float
	) -> ArrayMesh:
	var half := size * 0.5
	var x0 := -half.x
	var x1 := x0 + thickness
	var y0 := -half.y
	var y1 := half.y
	var z0 := -half.z
	var z1 := half.z
	aperture_y_min = clampf(aperture_y_min, y0, y1)
	aperture_y_max = clampf(aperture_y_max, aperture_y_min, y1)
	aperture_z_min = clampf(aperture_z_min, z0, z1)
	aperture_z_max = clampf(aperture_z_max, aperture_z_min, z1)
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var indices := PackedInt32Array()
	# Full cabin width and the doorway are retained at the middle stations.
	# Broad rolled shoulders and a radiused lower chine replace the box corners;
	# sealed end bays neck down to fitted bulkheads without crossing the route.
	var bevel := minf(0.30, maxf(0.0, y1 - aperture_y_max))
	var lower_bevel := minf(0.50, maxf(0.0, aperture_y_min - y0))
	var section := PackedVector2Array([
		Vector2(x0 + 0.70, y1), Vector2(half.x - 0.70, y1),
		Vector2(half.x - 0.20, y1 - bevel * 0.24), Vector2(half.x, y1 - bevel),
		Vector2(half.x, y0 + lower_bevel), Vector2(half.x - 0.18, y0 + lower_bevel * 0.28),
		Vector2(half.x - 0.65, y0), Vector2(x0 + 0.65, y0),
		Vector2(x0 + 0.18, y0 + lower_bevel * 0.28), Vector2(x0, y0 + lower_bevel),
		Vector2(x0, y1 - bevel), Vector2(x0 + 0.20, y1 - bevel * 0.24),
	])
	var section_normals := PackedVector2Array()
	var starboard_wall := 3
	var port_wall := 9
	if size == HULL_SIZE:
		# Form the outer pressure shell with tangent elliptical bends. Eight
		# segments per bend replace the two broad chamfer facets; the roof,
		# stamped side walls and cabin aperture keep their authored bounds.
		section.clear()
		section.append(Vector2(x0 + 0.70, y1))
		section_normals.append(Vector2(0, 1))
		for corner in 4:
			var upper := corner == 0 or corner == 3
			var radius := Vector2(0.70 if upper else 0.65, bevel if upper else lower_bevel)
			var center := Vector2(
				half.x - radius.x if corner < 2 else x0 + radius.x,
				y1 - radius.y if upper else y0 + radius.y)
			for step in 9:
				# The final top-left endpoint is already the first section point.
				if corner == 3 and step == 8:
					continue
				var angle := PI * 0.5 - float(corner) * PI * 0.5 - float(step) / 8.0 * PI * 0.5
				var radial := Vector2(cos(angle), sin(angle))
				section.append(center + radial * radius)
				section_normals.append(Vector2(radial.x / radius.x, radial.y / radius.y).normalized())
			if corner == 0:
				starboard_wall = section.size() - 1
			elif corner == 2:
				port_wall = section.size() - 1
	var stations: Array[float] = [z0, z0 * 0.91, z0 * 0.66, aperture_z_min, 0.0, aperture_z_max, z1 * 0.66, z1 * 0.91, z1]
	stations.sort()
	var rings: Array[PackedVector3Array] = []
	for z in stations:
		var end_ratio := clampf((absf(z) / half.z - 0.66) / 0.34, 0.0, 1.0)
		# Keep every aperture station at the full, unshifted cabin section.
		if z >= aperture_z_min and z <= aperture_z_max:
			end_ratio = 0.0
		var ring := PackedVector3Array()
		for point in section:
			ring.append(Vector3(point.x * lerpf(1.0, 0.80, end_ratio), point.y * lerpf(1.0, 0.82, end_ratio), z))
		rings.append(ring)
	for bay in stations.size() - 1:
		var in_door := stations[bay] >= aperture_z_min and stations[bay + 1] <= aperture_z_max
		for edge in section.size():
			if edge == port_wall and in_door:
				continue
			var next := (edge + 1) % section.size()
			# Stamp the large freight faces into the pressure skin itself. The
			# perimeter stays at the original shell bounds; recessed pans expose
			# real angled reveals and leave the interior pressure wall intact.
			if size == HULL_SIZE and (edge == starboard_wall or edge == port_wall) and stations[bay + 1] - stations[bay] > 0.6:
				_append_freight_pan(vertices, normals, indices,
					rings[bay][edge], rings[bay][next], rings[bay + 1][next], rings[bay + 1][edge],
					Vector3.RIGHT if edge == starboard_wall else Vector3.LEFT)
				continue
			var vertex_start := vertices.size()
			var midpoint := (section[edge] + section[next]) * 0.5
			_append_shell_quad(vertices, normals, indices,
				rings[bay][edge], rings[bay][next], rings[bay + 1][next], rings[bay + 1][edge],
				Vector3(midpoint.x / half.x, midpoint.y / half.y, 0).normalized())
			if not section_normals.is_empty() and vertices.size() == vertex_start + 4:
				# Preserve clockwise triangles while giving each bend endpoint its
				# analytic normal. Longitudinal taper joints stay deliberate folds.
				for vertex_index in range(vertex_start, vertices.size()):
					var point := vertices[vertex_index]
					var at_start := is_equal_approx(point.z, stations[bay])
					var ring_index := bay if at_start else bay + 1
					var section_index := edge if point.is_equal_approx(rings[ring_index][edge]) else next
					var across := section_normals[section_index]
					var along := rings[bay + 1][section_index] - rings[bay][section_index]
					var scale_x := rings[ring_index][section_index].x / section[section_index].x
					var scale_y := rings[ring_index][section_index].y / section[section_index].y
					var nx := across.x / scale_x
					var ny := across.y / scale_y
					normals[vertex_index] = Vector3(nx, ny, -(nx * along.x + ny * along.y) / along.z).normalized()
		if in_door:
			for band in [Vector2(y0 + lower_bevel, aperture_y_min), Vector2(aperture_y_max, y1 - bevel)]:
				_append_shell_quad(vertices, normals, indices,
					Vector3(x0, band.x, stations[bay]), Vector3(x0, band.y, stations[bay]),
					Vector3(x0, band.y, stations[bay + 1]), Vector3(x0, band.x, stations[bay + 1]), Vector3.LEFT)
	for cap in [0, rings.size() - 1]:
		var ring := rings[cap]
		var center := Vector3(0, 0, stations[cap])
		for edge in section.size():
			var next := (edge + 1) % section.size()
			var triangle := [center, ring[next], ring[edge]] if cap == 0 else [center, ring[edge], ring[next]]
			for point in triangle:
				indices.append(vertices.size())
				vertices.append(point)
				normals.append(Vector3.FORWARD if cap == 0 else Vector3.BACK)
	# Doorway reveals close the shell thickness from exterior to cabin.
	_append_shell_quad(vertices, normals, indices,
		Vector3(x0, aperture_y_min, aperture_z_min), Vector3(x1, aperture_y_min, aperture_z_min),
		Vector3(x1, aperture_y_max, aperture_z_min), Vector3(x0, aperture_y_max, aperture_z_min), Vector3.BACK)
	_append_shell_quad(vertices, normals, indices,
		Vector3(x0, aperture_y_min, aperture_z_max), Vector3(x0, aperture_y_max, aperture_z_max),
		Vector3(x1, aperture_y_max, aperture_z_max), Vector3(x1, aperture_y_min, aperture_z_max), Vector3.FORWARD)
	_append_shell_quad(vertices, normals, indices,
		Vector3(x0, aperture_y_min, aperture_z_min), Vector3(x0, aperture_y_min, aperture_z_max),
		Vector3(x1, aperture_y_min, aperture_z_max), Vector3(x1, aperture_y_min, aperture_z_min), Vector3.UP)
	_append_shell_quad(vertices, normals, indices,
		Vector3(x0, aperture_y_max, aperture_z_min), Vector3(x1, aperture_y_max, aperture_z_min),
		Vector3(x1, aperture_y_max, aperture_z_max), Vector3(x0, aperture_y_max, aperture_z_max), Vector3.DOWN)
	var uv := PackedVector2Array()
	for index in vertices.size():
		var point := vertices[index]
		var normal := normals[index].abs()
		if normal.z > normal.x and normal.z > normal.y:
			uv.append(Vector2(point.x, point.y) * 0.3)
		elif normal.y > normal.x:
			uv.append(Vector2(point.x, point.z) * 0.3)
		else:
			uv.append(Vector2(point.y, point.z) * 0.3)
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TEX_UV] = uv
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	mesh.set_meta(&"port_aperture_local_bounds", AABB(
		Vector3(x0, aperture_y_min, aperture_z_min),
		Vector3(thickness, aperture_y_max - aperture_y_min, aperture_z_max - aperture_z_min)
	))
	mesh.set_meta(&"closed_aperture_reveals", true)
	return mesh


## A deep pressed panel, including its surrounding skin and sloped reveal.
## Sloped perimeter reveals catch light across the large flank surface.
static func _append_freight_pan(vertices: PackedVector3Array, normals: PackedVector3Array,
		indices: PackedInt32Array, a: Vector3, b: Vector3, c: Vector3, d: Vector3, outward: Vector3) -> void:
	var outer := PackedVector2Array([
		Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1),
	])
	var inner := PackedVector2Array([
		Vector2(0.10, 0.13), Vector2(0.90, 0.13), Vector2(0.90, 0.87), Vector2(0.10, 0.87),
	])
	var border := PackedVector3Array()
	var rim := PackedVector3Array()
	var floor_ring := PackedVector3Array()
	for i in 4:
		var q := outer[i]
		border.append(a.lerp(b, q.x).lerp(d.lerp(c, q.x), q.y))
		q = inner[i]
		rim.append(a.lerp(b, q.x).lerp(d.lerp(c, q.x), q.y))
		q = q.lerp(Vector2(0.5, 0.5), 0.085)
		floor_ring.append(a.lerp(b, q.x).lerp(d.lerp(c, q.x), q.y) - outward * 0.15)
	for edge in 4:
		var next := (edge + 1) % 4
		_append_shell_quad(vertices, normals, indices, border[edge], border[next], rim[next], rim[edge], outward)
		_append_shell_quad(vertices, normals, indices, rim[edge], rim[next], floor_ring[next], floor_ring[edge], outward)
	# A shallow diamond pressing stiffens each broad pan. Its crown remains
	# below the original outer skin, giving four deliberate light planes rather
	# than leaving another featureless rectangular sheet inside the recess.
	var crown := (floor_ring[0] + floor_ring[1] + floor_ring[2] + floor_ring[3]) * 0.25 + outward * 0.075
	for edge in 4:
		var next := (edge + 1) % 4
		var first := floor_ring[edge]
		var second := floor_ring[next]
		var normal := (second - first).cross(crown - first).normalized()
		if normal.dot(outward) < 0.0:
			normal = -normal
		var triangle := [first, second, crown] if (second - first).cross(crown - first).dot(normal) < 0.0 else [first, crown, second]
		for point in triangle:
			indices.append(vertices.size())
			vertices.append(point)
			normals.append(normal)


static func _append_shell_quad(
		vertices: PackedVector3Array,
		normals: PackedVector3Array,
		indices: PackedInt32Array,
		a: Vector3,
		b: Vector3,
		c: Vector3,
		d: Vector3,
		normal: Vector3
	) -> void:
	if (b - a).cross(c - a).length_squared() <= 0.000001 \
			or (c - a).cross(d - a).length_squared() <= 0.000001:
		return
	var geometric := (b - a).cross(c - a).normalized()
	if geometric.dot(normal) < 0.0:
		geometric = -geometric
	normal = geometric
	var base := vertices.size()
	var ordered := [a, b, c, d]
	# Godot front faces wind clockwise, opposite the outward shading normal.
	if (b - a).cross(c - a).dot(normal) > 0.0:
		ordered = [a, d, c, b]
	for vertex in ordered:
		vertices.append(vertex)
		normals.append(normal)
	indices.append_array(PackedInt32Array([
		base, base + 1, base + 2,
		base, base + 2, base + 3,
	]))


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


## A full-width pressure collar closes the nested shell reveal without placing
## a decorative doorway in the middle of the physical boarding route. The
## bevelled mouth, recessed seal and cabin-side liner are one open ring.
func _build_cargo_entry(visual: Node3D) -> void:
	var frame_finish := _material(Color("89938f"), 0.55, 0.38)
	ShipSurfaceDetail.bind_manufactured_paint(frame_finish)
	var liner_finish := _material(Color("35413f"), 0.35, 0.54)
	var collar := MeshInstance3D.new()
	collar.name = "CargoPressureCollar"
	collar.mesh = _cargo_portal_mesh(-3.32, -2.40, 2.34, -1.04, 1.38, 2.14, -0.97, 1.23)
	collar.material_override = liner_finish
	collar.set_meta(&"presentation_only", true)
	collar.set_meta(&"route_id", CABIN_ROUTE_ID)
	visual.add_child(collar)
	var rim := MeshInstance3D.new()
	rim.name = "CargoPressureRim"
	rim.mesh = _cargo_portal_mesh(-3.40, -3.28, 2.36, -1.05, 1.40, 2.23, -1.00, 1.24)
	rim.material_override = frame_finish
	rim.set_meta(&"presentation_only", true)
	visual.add_child(rim)
	var posts := _add_visual_box_batch(
		visual, "CargoThresholdPostBatch", Vector3(0.09, 1.83, 0.08),
		[
			Transform3D(Basis.IDENTITY, Vector3(-3.41, 0.15, -2.28)),
			Transform3D(Basis.IDENTITY, Vector3(-3.41, 0.15, 2.28)),
		], Color("89938f"),
		PackedStringArray(["CargoThresholdPostPort", "CargoThresholdPostStarboard"])
	)
	posts.material_override = frame_finish
	posts.set_meta(&"route_id", CABIN_ROUTE_ID)
	var header := _add_interior_box(visual, "CargoThresholdHeader",
		Vector3(-3.33, 1.31, 0.0), Vector3(0.20, 0.17, 3.98), Color("35413f"))
	header.mesh = _rounded_box_mesh(Vector3(0.20, 0.17, 3.98), null)
	header.material_override = liner_finish
	header.set_meta(&"presentation_only", true)
	header.set_meta(&"route_id", CABIN_ROUTE_ID)
	var step := _add_interior_box(visual, "CargoBoardingStep",
		Vector3(-3.4, -1.05, 0.0), Vector3(0.72, 0.16, 1.65), Color("68716a"))
	step.mesh = _rounded_box_mesh(Vector3(0.72, 0.16, 1.65), null)
	step.material_override = frame_finish
	step.set_meta(&"route_id", CABIN_ROUTE_ID)
	var sill := _add_interior_box(visual, "CargoEntrySill",
		Vector3(-2.77, -1.0, 0.0), Vector3(0.66, 0.12, 4.17), Color("68716a"))
	sill.mesh = _rounded_box_mesh(Vector3(0.66, 0.12, 4.17), null)
	sill.material_override = frame_finish
	var tread_transforms: Array[Transform3D] = []
	for x in [-3.65, -3.51, -3.37, -3.23]:
		tread_transforms.append(Transform3D(Basis.IDENTITY, Vector3(x, -0.965, 0.0)))
	_add_visual_box_batch(visual, "CargoBoardingGripBatch", Vector3(0.035, 0.012, 1.43),
		tread_transforms, Color("25322f"), PackedStringArray())
	var lamp := _add_interior_box(visual, "CargoBoardingLamp", Vector3(-3.18, 1.16, 0.0),
		Vector3(0.065, 0.045, 1.32), Color("d8e8e5"))
	lamp.material_override = _material(Color("d8e8e5"), 0.1, 0.42, Color("d8e8e5"), 0.9)


## Closed chamfered rectangular ring extruded along X. All four surfaces are
## authored explicitly so the aperture has inward-facing reveal walls as well
## as an outward-facing rim; it never relies on double-sided material.
func _cargo_portal_mesh(front: float, back: float, outer_z: float,
		outer_bottom: float, outer_top: float, inner_z: float,
		inner_bottom: float, inner_top: float) -> ArrayMesh:
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var indices := PackedInt32Array()
	var outer := _cargo_portal_section(outer_z, outer_bottom, outer_top, 0.24)
	var inner := _cargo_portal_section(inner_z, inner_bottom, inner_top, 0.16)
	for edge in outer.size():
		var next := (edge + 1) % outer.size()
		var a := Vector3(front, outer[edge].y, outer[edge].x)
		var b := Vector3(front, outer[next].y, outer[next].x)
		var c := Vector3(front, inner[next].y, inner[next].x)
		var d := Vector3(front, inner[edge].y, inner[edge].x)
		var depth := Vector3(back - front, 0.0, 0.0)
		_append_shell_quad(vertices, normals, indices, a, b, c, d, Vector3.LEFT)
		_append_shell_quad(vertices, normals, indices, a + depth, d + depth, c + depth, b + depth, Vector3.RIGHT)
		var outward := Vector3(0.0, (a.y + b.y) * 0.5 - 0.15, (a.z + b.z) * 0.5)
		_append_shell_quad(vertices, normals, indices, a, a + depth, b + depth, b, outward)
		_append_shell_quad(vertices, normals, indices, d, c, c + depth, d + depth, -outward)
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh


func _cargo_portal_section(half_width: float, bottom: float, top: float, corner: float) -> PackedVector2Array:
	return PackedVector2Array([
		Vector2(-half_width + corner, bottom), Vector2(half_width - corner, bottom),
		Vector2(half_width, bottom + corner), Vector2(half_width, top - corner),
		Vector2(half_width - corner, top), Vector2(-half_width + corner, top),
		Vector2(-half_width, top - corner), Vector2(-half_width, bottom + corner),
	])


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
	_build_cabin_construction()
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
	_finish_cabin_stations()
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
	_loadmaster_status_display.position = Vector3(-0.15, 0.43, -2.235)
	_loadmaster_status_display.font_size = 24
	_loadmaster_status_display.pixel_size = 0.0032
	_loadmaster_status_display.modulate = Color("f2ffff")
	_loadmaster_status_display.outline_modulate = Color("07111d")
	_loadmaster_status_display.outline_size = 8
	_loadmaster_status_display.no_depth_test = false
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


func _build_cabin_construction() -> void:
	var frame_material := _material(Color("626e69"), 0.48, 0.42)
	var lining_material := _material(Color("87918a"), 0.16, 0.71)
	ShipSurfaceDetail.bind_manufactured_paint(lining_material)
	# Two end bulkhead rings turn ceiling, deck and sidewall into a continuous
	# fabricated cabin. Their centres remain open; no collision is introduced.
	var bulkhead_mesh := _cargo_portal_mesh(-0.07, 0.07, 2.39, -0.88, 1.25, 2.22, -0.86, 1.12)
	var bulkheads := MultiMeshInstance3D.new()
	bulkheads.name = "CabinBulkheadFrames"
	bulkheads.multimesh = MultiMesh.new()
	bulkheads.multimesh.transform_format = MultiMesh.TRANSFORM_3D
	bulkheads.multimesh.mesh = bulkhead_mesh
	bulkheads.multimesh.instance_count = 2
	for index in 2:
		bulkheads.multimesh.set_instance_transform(index,
			Transform3D(Basis(Vector3.UP, PI * 0.5), Vector3(0.0, 0.0, -2.35 if index == 0 else 2.35)))
	bulkheads.material_override = frame_material
	bulkheads.set_meta(&"presentation_only", true)
	_cargo_cabin.add_child(bulkheads)
	var panels: Array[Transform3D] = []
	for z in [-1.76, -0.59, 0.59, 1.76]:
		panels.append(Transform3D(Basis.IDENTITY, Vector3(2.275, 0.20, z)))
	var wall_panels := _add_visual_box_batch(_cargo_cabin, "CabinLiningPanels",
		Vector3(0.06, 1.65, 1.10), panels, Color("87918a"), PackedStringArray())
	wall_panels.multimesh.mesh = _rounded_box_mesh(Vector3(0.06, 1.65, 1.10), null)
	wall_panels.material_override = lining_material
	var deck := _cargo_cabin.get_node("CabinDeck") as MeshInstance3D
	deck.material_override = _material(Color("303b37"), 0.24, 0.78)
	var rail_transforms: Array[Transform3D] = []
	for z in [-2.1, 2.1]:
		rail_transforms.append(Transform3D(Basis.IDENTITY, Vector3(0.0, 1.14, z)))
	var rails := _add_visual_box_batch(_cargo_cabin, "CabinCeilingConduits",
		Vector3(4.38, 0.11, 0.12), rail_transforms, Color("626e69"), PackedStringArray())
	rails.multimesh.mesh = _rounded_box_mesh(Vector3(4.38, 0.11, 0.12), null)
	rails.material_override = frame_material
	var pedestal_transforms: Array[Transform3D] = []
	var console_legs: Array[Transform3D] = []
	for x in [-0.95, 0.95]:
		pedestal_transforms.append(Transform3D(Basis.IDENTITY, Vector3(x, -0.735, 1.1)))
		console_legs.append(Transform3D(Basis.IDENTITY, Vector3(x, -0.435, 0.42)))
	var pedestals := _add_visual_box_batch(_cargo_cabin, "CrewSeatPedestals",
		Vector3(0.46, 0.25, 0.54), pedestal_transforms, Color("303b37"), PackedStringArray())
	pedestals.multimesh.mesh = _rounded_box_mesh(Vector3(0.46, 0.25, 0.54), null)
	var console_supports := _add_visual_box_batch(_cargo_cabin, "CrewConsoleSupports",
		Vector3(0.54, 0.85, 0.16), console_legs, Color("303b37"), PackedStringArray())
	console_supports.multimesh.mesh = _rounded_box_mesh(Vector3(0.54, 0.85, 0.16), null)


func _finish_cabin_stations() -> void:
	# Retain station transforms and batched ownership while forming the shells
	# and giving seats soft inserts and consoles recessed instrument glass.
	for stock in [
		["CrewSeatBaseBatch", Vector3(0.86, 0.18, 0.82)],
		["CrewSeatBackBatch", Vector3(0.86, 1.0, 0.14)],
		["CrewConsoleBatch", Vector3(0.92, 0.58, 0.08)],
	]:
		var batch := _cargo_cabin.get_node(stock[0]) as MultiMeshInstance3D
		batch.multimesh.mesh = _rounded_box_mesh(stock[1], null)
	var seat_pads: Array[Transform3D] = []
	var back_pads: Array[Transform3D] = []
	var screens: Array[Transform3D] = []
	for x in [-0.95, 0.95]:
		seat_pads.append(Transform3D(Basis.IDENTITY, Vector3(x, -0.425, 1.06)))
		back_pads.append(Transform3D(Basis.IDENTITY, Vector3(x, 0.08, 1.325)))
		screens.append(Transform3D(Basis.IDENTITY, Vector3(x, 0.22, 0.37)))
	var pads := _add_visual_box_batch(_cargo_cabin, "CrewSeatCushions",
		Vector3(0.72, 0.10, 0.66), seat_pads, Color("283831"), PackedStringArray())
	pads.multimesh.mesh = _rounded_box_mesh(Vector3(0.72, 0.10, 0.66), null)
	pads.material_override = _material(Color("283831"), 0.0, 0.94)
	var backs := _add_visual_box_batch(_cargo_cabin, "CrewBackCushions",
		Vector3(0.70, 0.82, 0.10), back_pads, Color("283831"), PackedStringArray())
	backs.multimesh.mesh = _rounded_box_mesh(Vector3(0.70, 0.82, 0.10), null)
	backs.material_override = pads.material_override
	var glass := _add_visual_box_batch(_cargo_cabin, "CrewInstrumentGlass",
		Vector3(0.78, 0.40, 0.025), screens, Color("112b2d"), PackedStringArray())
	glass.multimesh.mesh = _rounded_box_mesh(Vector3(0.78, 0.40, 0.025), null)
	glass.material_override = _material(Color("112b2d"), 0.25, 0.24, Color("31565b"), 0.25)


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
	if roster_reading.is_empty():
		_loadmaster_status_display.text = (
			"LOADMASTER\nMANIFEST %s\nROUTE %s"
			% [str(manifest_id) if not manifest_id.is_empty() else "--", str(route_id) if not route_id.is_empty() else "--"]
		)
		return
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
	match state:
		&"occupied":
			return {"shape": "[>]", "status": "LOADING"} \
				if _loadmaster_manifest_receipt.is_empty() \
				else {"shape": "[!]", "status": "BLOCKED"}
		&"manifest_ready":
			if not _loadmaster_manifest_receipt.is_empty() \
					and bool(_loadmaster_manifest_receipt.get("ready", false)):
				return {"shape": "[=]", "status": "SECURED"}
		&"available", &"released":
			return {"shape": "[/]", "status": "DETACHED"}
	return {}


func _crew_role_result(accepted: bool, status: StringName) -> Dictionary:
	return {
		"accepted": accepted,
		"status": status,
		"ship_id": get_ship_id(),
		"station_id": LOADMASTER_STATION_SEAT_ID,
	}.duplicate(true)

## Chamfered pressure-shell stock reuses the inherited closed loft topology.
## Broad planar stations carry armor panels; corner facets catch a narrow edge
## highlight without inflating the entire silhouette like a superellipse.
func _loft_mesh(size: Vector3, material: Material) -> ArrayMesh:
	# Use the actual profile breaks as stations. The broad pressure faces
	# stay continuous between those breaks instead of introducing redundant
	# almost-coplanar strips along the manufactured edges.
	var section := PackedVector2Array([
		Vector2(0, 1), Vector2(0.62, 1), Vector2(0.91, 0.80), Vector2(1, 0.40),
		Vector2(1, 0), Vector2(1, -0.40), Vector2(0.91, -0.80), Vector2(0.62, -1),
		Vector2(0, -1), Vector2(-0.62, -1), Vector2(-0.91, -0.80), Vector2(-1, -0.40),
		Vector2(-1, 0), Vector2(-1, 0.40), Vector2(-0.91, 0.80), Vector2(-0.62, 1),
	])
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
				var around := Vector3(edge_direction.x * extent.x, edge_direction.y * extent.y, 0)
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


func _armor_shell(parent: Node3D, node_name: String, at: Vector3, size: Vector3, coating: Material, skew: float = 0.0) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.name = node_name
	instance.position = at
	instance.mesh = _loft_mesh(size, coating)
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


## Recessed stator and turned hub share the Cinder family machinery meshes.
func _engine_mechanics(parent: Node3D, tag: String, at: Vector3, radius: float, metal: Material, dark: Material) -> void:
	preload("res://scripts/ships/cinder_exhaust_machinery.gd").install(parent, tag, at, radius, metal, dark)


## Flush service plates have their own bevel and dark gasket; the narrow edge
## catches light while a readable seam separates adjacent manufactured parts.
func _deck_plate(parent: Node3D, tag: String, at: Vector3, width: float, length: float, paint: Material, gasket: Material) -> void:
	_box(parent, tag + "Gasket", at, Vector3(width, 0.028, length), gasket)
	_box(parent, tag + "Panel", at + Vector3(0, 0.022, 0), Vector3(width - 0.06, 0.032, length - 0.06), paint)


## Add the missing propulsion presentation at this hull's nozzle mouths. The
## envelope is baked along local +Z with its base at zero, so HeroShip's axial
## throttle/damage scaling cannot widen the plume or pull it out of its mount.
func _build_engine_exhaust(visual: Node3D) -> void:
	var radius := 0.64
	var nozzle := Vector3(3.75, 0.4, 6.59)
	var plume_mesh := (
		_shared_engine_exhaust_mesh.get_ref() as ArrayMesh
		if _shared_engine_exhaust_mesh != null else null
	)
	if plume_mesh == null:
		var envelope := CylinderMesh.new()
		envelope.bottom_radius = radius * 0.78
		envelope.top_radius = radius * 0.18
		envelope.height = radius * 2.8
		envelope.radial_segments = 24
		var surface := SurfaceTool.new()
		surface.append_from(envelope, 0, Transform3D(
			Basis(Vector3.RIGHT, PI * 0.5), Vector3(0.0, 0.0, envelope.height * 0.5)
		))
		plume_mesh = surface.commit()
		_shared_engine_exhaust_mesh = weakref(plume_mesh)
	for index in 2:
		var side := -1.0 if index == 0 else 1.0
		var mouth := Vector3(nozzle.x * side, nozzle.y, nozzle.z + radius * 0.05)
		var plume := MeshInstance3D.new()
		plume.name = ("Port" if index == 0 else "Starboard") + "EnginePlume"
		plume.transform = Transform3D(Basis.IDENTITY, mouth)
		plume.mesh = plume_mesh
		plume.visible = false
		visual.add_child(plume)
		_engine_glows.append(plume)
		EngineExhaustPresentation.install(plume, Vector3.BACK)
	_sync_engine_visuals_immediately()
