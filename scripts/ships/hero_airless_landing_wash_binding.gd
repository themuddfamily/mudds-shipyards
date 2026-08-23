class_name HeroAirlessLandingWashBinding
extends RefCounted

## One passive Ember final-approach wash binding shared by the non-Arrow hero
## fleet. It derives a presentation anchor from the craft's accepted collision
## envelope and never mutates flight, landing, collision, or damage state.

const COMPONENT_ID: StringName = &"hero-airless-landing-wash-binding"
const WashScript := preload(
	"res://scripts/effects/arrow_landing_dust_wash_presentation.gd"
)
const WASH_NAME := &"AirlessLandingDustWashPresentation"
const ARROW_DUST_LOCAL_Y := -1.28
const ARROW_DUST_LOCAL_Z := 1.25
const REFERENCE_FOOTPRINT_WIDTH_M := 5.0
const REFERENCE_FOOTPRINT_LENGTH_M := 5.0

var _ship_ref: WeakRef
var _hud_ref: WeakRef
var _wash: Node3D
var _attached := false
var _craft_id: StringName = &""
var _anchor_snapshot: Dictionary = {}
var _last_result: Dictionary = {}


func attach(ship: HeroShip, hud: GameHUD) -> Dictionary:
	if _attached:
		return _result(false, &"already_attached")
	if ship == null or not is_instance_valid(ship) or ship is ArrowReconShip:
		return _result(false, &"unsupported_craft")
	if hud == null or not is_instance_valid(hud) \
			or not hud.has_method(&"get_accessibility_report"):
		return _result(false, &"accessibility_contract_missing")
	var visual_root := ship.get_variant_visual_root()
	var craft_id := _craft_id_for(ship, visual_root)
	if visual_root == null or craft_id == &"":
		return _result(false, &"unsupported_craft")
	if visual_root.get_node_or_null(NodePath(String(WASH_NAME))) != null:
		return _result(false, &"duplicate_wash")
	var collision := ship.get_landing_collision_report()
	if not bool(collision.get("valid", false)):
		return _result(false, &"landing_envelope_unavailable")
	var bounds := collision.get("local_bounds", AABB()) as AABB
	if bounds.size == Vector3.ZERO or not bounds.position.is_finite() \
			or not bounds.size.is_finite():
		return _result(false, &"landing_envelope_invalid")
	var lateral_scale := clampf(
		bounds.size.x / REFERENCE_FOOTPRINT_WIDTH_M, 0.75, 2.5
	)
	var longitudinal_scale := clampf(
		bounds.size.z / REFERENCE_FOOTPRINT_LENGTH_M, 0.75, 3.0
	)
	var wash := WashScript.new() as Node3D
	var configured := wash.call(
		&"configure_footprint", lateral_scale, longitudinal_scale
	) as Dictionary
	if not bool(configured.get("accepted", false)):
		return _result(false, &"footprint_configuration_failed")
	wash.name = String(WASH_NAME)
	var center := bounds.get_center()
	wash.position = Vector3(
		center.x,
		bounds.position.y - ARROW_DUST_LOCAL_Y,
		center.z - ARROW_DUST_LOCAL_Z,
	)
	wash.set_meta("fleet_landing_wash", true)
	wash.set_meta("presentation_only", true)
	visual_root.add_child(wash)
	_ship_ref = weakref(ship)
	_hud_ref = weakref(hud)
	_wash = wash
	_attached = true
	_craft_id = craft_id
	_anchor_snapshot = {
		"craft_id": craft_id,
		"visual_root_instance_id": visual_root.get_instance_id(),
		"wash_instance_id": wash.get_instance_id(),
		"landing_bounds": bounds,
		"contact_plane_y": bounds.position.y,
		"anchor_position": wash.position,
		"lateral_scale": lateral_scale,
		"longitudinal_scale": longitudinal_scale,
		"collision_derived": true,
	}.duplicate(true)
	return _result(true, &"attached")


func present_observation(
		altitude_m: float, vertical_speed_mps: float, airless: bool,
		landing_supported: bool
	) -> Dictionary:
	if not _attached or _wash == null or not is_instance_valid(_wash):
		return _result(false, &"detached")
	var ship := _ship()
	var hud := _hud()
	if ship == null or hud == null or _wash.get_parent() \
			!= ship.get_variant_visual_root():
		return _result(false, &"attachment_lost")
	var accessibility := hud.get_accessibility_report()
	var presented := _wash.call(
		&"present_observation", altitude_m, vertical_speed_mps, airless,
		landing_supported, bool(accessibility.get("reduced_flash", false)),
		bool(accessibility.get("reduced_motion", false))
	) as Dictionary
	_last_result = presented.duplicate(true)
	return _result(
		bool(presented.get("accepted", false)),
		StringName(presented.get("reason", &"wash_rejected")),
	)


func detach() -> Dictionary:
	if _wash != null and is_instance_valid(_wash):
		_wash.call(&"clear", &"detached_zero")
		_wash.queue_free()
	_wash = null
	_ship_ref = null
	_hud_ref = null
	_attached = false
	_last_result = {}
	return _result(true, &"detached")


func get_snapshot() -> Dictionary:
	return {
		"component_id": COMPONENT_ID,
		"attached": _attached and _ship() != null and _hud() != null,
		"craft_id": _craft_id,
		"anchor": _anchor_snapshot.duplicate(true),
		"wash": _wash.call(&"get_snapshot") if _wash != null \
			and is_instance_valid(_wash) else {
				"visible": false,
				"intensity": 0.0,
				"last_reason": &"detached_zero",
			},
		"last_result": _last_result.duplicate(true),
		"duplicate_nodes": 0,
		"presentation_only": true,
		"physics_authority": false,
		"movement_authority": false,
		"landing_authority": false,
		"damage_authority": false,
	}.duplicate(true)


func _craft_id_for(ship: HeroShip, visual_root: Node3D) -> StringName:
	if ship is JovianLightFreighter:
		return &"jovian"
	if ship is ZenithInterceptor:
		return &"zenith"
	if ship is HalyardCrewTransport:
		return &"halyard"
	if visual_root != null and visual_root.name == &"TorrentVisual":
		return &"torrent"
	return &""


func _ship() -> HeroShip:
	return _ship_ref.get_ref() as HeroShip if _ship_ref != null else null


func _hud() -> GameHUD:
	return _hud_ref.get_ref() as GameHUD if _hud_ref != null else null


func _result(accepted: bool, reason: StringName) -> Dictionary:
	return {
		"accepted": accepted,
		"reason": reason,
		"snapshot": get_snapshot(),
		"presentation_only": true,
		"physics_authority": false,
		"movement_authority": false,
		"landing_authority": false,
		"damage_authority": false,
	}.duplicate(true)
