class_name HeroAtmosphericEntryEnvelopeBinding
extends RefCounted

## One passive atmospheric compression-envelope binding shared by the non-Arrow
## hero fleet. It samples a frozen accepted atmosphere profile from the
## production caller's altitude/speed observation and anchors the retained
## renderer to the craft's accepted collision silhouette. It never mutates
## flight, heat, atmosphere, collision, or damage state.

const COMPONENT_ID: StringName = &"hero-atmospheric-entry-envelope-binding"
const EnvelopeScript := preload(
	"res://scripts/effects/arrow_entry_exterior_envelope_presentation.gd"
)
const SamplerScript := preload(
	"res://scripts/world/planetary_atmosphere_sampler.gd"
)
const ENVELOPE_NAME := &"AtmosphericEntryExteriorEnvelope"
const ARROW_ENVELOPE_CENTER := Vector3(0.0, 4.25, 4.75)
const REFERENCE_SILHOUETTE_WIDTH_M := 5.0
const REFERENCE_SILHOUETTE_HEIGHT_M := 5.0

var _ship_ref: WeakRef
var _hud_ref: WeakRef
var _envelope: Node3D
var _sampler: RefCounted
var _attached := false
var _craft_id: StringName = &""
var _profile_id: StringName = &""
var _generation := 0
var _observation_serial := 0
var _previous_level := 0
var _anchor_snapshot: Dictionary = {}
var _last_sample: Dictionary = {}
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
	if visual_root.get_node_or_null(NodePath(String(ENVELOPE_NAME))) != null:
		return _result(false, &"duplicate_envelope")
	var collision := ship.get_landing_collision_report()
	if not bool(collision.get("valid", false)):
		return _result(false, &"collision_silhouette_unavailable")
	var bounds := collision.get("local_bounds", AABB()) as AABB
	if bounds.size == Vector3.ZERO or not bounds.position.is_finite() \
			or not bounds.size.is_finite():
		return _result(false, &"collision_silhouette_invalid")
	var lateral_scale := clampf(
		bounds.size.x / REFERENCE_SILHOUETTE_WIDTH_M, 0.75, 2.5
	)
	var vertical_scale := clampf(
		bounds.size.y / REFERENCE_SILHOUETTE_HEIGHT_M, 0.75, 2.0
	)
	var silhouette_scale := Vector3(lateral_scale, vertical_scale, 1.0)
	# Keep the compression arc on the upper/aft silhouette where a chase camera
	# can read it, while the renderer's intensity scale remains independent.
	var desired_center := Vector3(
		bounds.get_center().x,
		bounds.position.y + bounds.size.y * 0.82,
		bounds.position.z + bounds.size.z * 0.78,
	)
	var envelope := EnvelopeScript.new() as Node3D
	envelope.name = String(ENVELOPE_NAME)
	envelope.scale = silhouette_scale
	envelope.position = desired_center - Vector3(
		ARROW_ENVELOPE_CENTER.x * silhouette_scale.x,
		ARROW_ENVELOPE_CENTER.y * silhouette_scale.y,
		ARROW_ENVELOPE_CENTER.z,
	)
	envelope.set_meta("fleet_atmospheric_entry_envelope", true)
	envelope.set_meta("presentation_only", true)
	visual_root.add_child(envelope)
	_ship_ref = weakref(ship)
	_hud_ref = weakref(hud)
	_envelope = envelope
	_attached = true
	_craft_id = craft_id
	_generation = int(envelope.call(&"get_generation"))
	_anchor_snapshot = {
		"craft_id": craft_id,
		"visual_root_instance_id": visual_root.get_instance_id(),
		"envelope_instance_id": envelope.get_instance_id(),
		"collision_bounds": bounds,
		"anchor_position": envelope.position,
		"silhouette_center": desired_center,
		"silhouette_scale": silhouette_scale,
		"collision_derived": true,
	}.duplicate(true)
	return _result(true, &"attached")


func configure_atmosphere(profile: PlanetaryAtmosphereProfile) -> Dictionary:
	if not _attached:
		return _result(false, &"detached")
	if profile == null or not profile.is_definition_valid():
		return _result(false, &"invalid_atmosphere_profile")
	if _sampler != null:
		return _result(
			_profile_id == profile.profile_id,
			&"atmosphere_retained" if _profile_id == profile.profile_id \
				else &"atmosphere_profile_mismatch",
		)
	var sampler := SamplerScript.new() as RefCounted
	var configured := sampler.call(&"configure", profile) as Dictionary
	if not bool(configured.get("accepted", false)):
		return _result(false, &"atmosphere_sampler_configuration_failed")
	_sampler = sampler
	_profile_id = profile.profile_id
	return _result(true, &"atmosphere_configured")


func present_observation(
		altitude_m: float, speed_mps: float, atmospheric: bool
	) -> Dictionary:
	if not _attached or _envelope == null or not is_instance_valid(_envelope):
		return _result(false, &"detached")
	if not is_finite(altitude_m) or altitude_m < 0.0 \
			or not is_finite(speed_mps) or speed_mps < 0.0:
		return _result(false, &"invalid_observation")
	var ship := _ship()
	var hud := _hud()
	if ship == null or hud == null or _envelope.get_parent() \
			!= ship.get_variant_visual_root():
		return _result(false, &"attachment_lost")
	var intensity := 0.0
	var sample: Dictionary = {
		"accepted": true,
		"reason": &"airless_exact_zero",
		"entry_effect_intensity": 0.0,
	}
	if atmospheric:
		if _sampler == null:
			return _result(false, &"atmosphere_not_configured")
		sample = _sampler.call(
			&"sample", altitude_m, 0.0, speed_mps, 0.0, 0.0
		) as Dictionary
		if not bool(sample.get("accepted", false)):
			return _result(false, &"atmosphere_sample_rejected")
		intensity = clampf(
			float(sample.get("entry_effect_intensity", 0.0)), 0.0, 1.0
		)
	var level := clampi(roundi(intensity * 5.0), 0, 5)
	var cockpit_snapshot := {
		"envelope_gauge": {
			"segment_count": 5,
			"filled_segments": level,
			"recovery": atmospheric and _previous_level >= 3 and level < 3,
		},
	}
	var accessibility := hud.get_accessibility_report()
	var presented := _envelope.call(
		&"present_envelope", cockpit_snapshot,
		&"atmospheric" if atmospheric else &"airless", intensity,
		bool(accessibility.get("reduced_flash", false)),
		bool(accessibility.get("reduced_motion", false)),
		_observation_serial + 1, _generation
	) as Dictionary
	if not bool(presented.get("accepted", false)):
		return _result(false, StringName(presented.get("reason", &"rejected")))
	_observation_serial += 1
	_previous_level = level if atmospheric else 0
	_last_sample = sample.duplicate(true)
	_last_result = presented.duplicate(true)
	return _result(true, &"entry_envelope_presented")


func detach() -> Dictionary:
	if _envelope != null and is_instance_valid(_envelope):
		_envelope.call(&"clear", &"detached", _generation)
		_envelope.queue_free()
	_envelope = null
	_ship_ref = null
	_hud_ref = null
	_sampler = null
	_attached = false
	_profile_id = &""
	_observation_serial = 0
	_previous_level = 0
	_last_sample = {}
	_last_result = {}
	_generation += 1
	return _result(true, &"detached")


func get_snapshot() -> Dictionary:
	return {
		"component_id": COMPONENT_ID,
		"attached": _attached and _ship() != null and _hud() != null,
		"craft_id": _craft_id,
		"profile_id": _profile_id,
		"generation": _generation,
		"observation_serial": _observation_serial,
		"anchor": _anchor_snapshot.duplicate(true),
		"accepted_atmosphere_sample": _last_sample.duplicate(true),
		"envelope": _envelope.call(&"get_snapshot") if _envelope != null \
			and is_instance_valid(_envelope) else {
				"visible": false,
				"effect_opacity": 0.0,
				"state": &"detached",
			},
		"last_result": _last_result.duplicate(true),
		"duplicate_nodes": 0,
		"presentation_only": true,
		"physics_authority": false,
		"movement_authority": false,
		"heat_authority": false,
		"atmosphere_authority": false,
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
		"heat_authority": false,
		"atmosphere_authority": false,
		"damage_authority": false,
	}.duplicate(true)
