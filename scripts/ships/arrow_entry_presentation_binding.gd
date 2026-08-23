class_name ArrowEntryPresentationBinding
extends RefCounted

## Passive bridge from the production owner's already-authoritative Arrow
## altitude/velocity observation to its authored heat target and retained HUD.
## It never samples movement, applies damage, advances physics, or selects a
## landing outcome.

const COMPONENT_ID: StringName = &"arrow-entry-presentation-binding"

var _arrow_ref: WeakRef
var _hud_ref: WeakRef
var _attached := false
var _atmospheric := false
var _generation := 0
var _observation_count := 0
var _last_result: Dictionary = {}


func attach(arrow: ArrowReconShip, hud: GameHUD) -> Dictionary:
	if _attached:
		return _reject(&"already_attached")
	if arrow == null or not is_instance_valid(arrow) \
			or arrow.get_entry_heat_target() == null:
		return _reject(&"arrow_entry_target_unavailable")
	if hud == null or not is_instance_valid(hud) \
			or not hud.has_method(&"update_atmospheric_entry_status") \
			or not hud.has_method(&"get_accessibility_report"):
		return _reject(&"hud_contract_missing")
	var presentation := arrow.get_entry_heat_target().get_presentation()
	if presentation == null:
		return _reject(&"entry_presentation_unavailable")
	var state := presentation.get_state_snapshot()
	if bool(state.get("configured", false)):
		if not bool(presentation.audit().get("valid", false)):
			return _reject(&"configured_entry_target_invalid")
		_atmospheric = true
	_arrow_ref = weakref(arrow)
	_hud_ref = weakref(hud)
	_attached = true
	_generation += 1
	return _result(true, &"attached")


func configure_atmosphere(profile: PlanetaryAtmosphereProfile) -> Dictionary:
	if not _attached:
		return _reject(&"detached")
	if profile == null or not profile.is_definition_valid():
		return _reject(&"invalid_atmosphere_profile")
	var presentation := _presentation()
	var arrow := _arrow()
	if presentation == null or arrow == null:
		return _reject(&"entry_target_unavailable")
	var state := presentation.get_state_snapshot()
	if bool(state.get("configured", false)):
		if state.get("profile_id", &"") != profile.profile_id:
			return _reject(&"atmosphere_profile_mismatch")
		_atmospheric = true
		return _result(true, &"atmosphere_retained")
	var configured := presentation.configure(
		profile, arrow.get_entry_heat_target().get_material()
	)
	if not bool(configured.get("accepted", false)):
		return _reject(&"entry_target_configuration_failed", {
			"presentation_reason": configured.get("reason", &"unknown"),
		})
	_atmospheric = true
	return _result(true, &"atmosphere_configured")


func present_observation(
		altitude_m: float, speed_mps: float, vertical_speed_mps: float,
		landing_supported: bool
	) -> Dictionary:
	if not _attached:
		return _reject(&"detached")
	if not is_finite(altitude_m) or not is_finite(speed_mps) \
			or not is_finite(vertical_speed_mps) \
			or altitude_m < 0.0 or speed_mps < 0.0:
		return _reject(&"invalid_observation")
	var arrow := _arrow()
	var hud := _hud()
	var presentation := _presentation()
	if arrow == null or hud == null or presentation == null:
		return _reject(&"presentation_target_unavailable")
	var intensity := 0.0
	var heat_result: Dictionary = {
		"accepted": true,
		"reason": &"airless_zero_heat",
	}
	if _atmospheric:
		heat_result = presentation.present_observation(
			altitude_m, speed_mps, presentation.get_generation()
		)
		if not bool(heat_result.get("accepted", false)):
			return _reject(&"entry_heat_rejected", {
				"presentation_reason": heat_result.get("reason", &"unknown"),
			})
		var observation := heat_result.get("observation", {}) as Dictionary
		intensity = float(observation.get(
			"entry_effect_intensity_unitless", 0.0
		))
	var accessibility := hud.get_accessibility_report()
	var source := {
		"world_id": &"aurora_temperate" if _atmospheric else &"ember_moon",
		"branch_id": &"atmospheric" if _atmospheric else &"airless",
		"altitude_m": altitude_m,
		"vertical_speed_mps": vertical_speed_mps,
		"entry_intensity": intensity,
		"landing_supported": landing_supported,
		"reduced_flash": bool(accessibility.get("reduced_flash", false)),
		"reduced_motion": bool(accessibility.get("reduced_motion", false)),
	}
	hud.update_atmospheric_entry_status(source)
	_observation_count += 1
	_last_result = _result(true, &"entry_presented", {
		"source": source.duplicate(true),
		"heat": heat_result.duplicate(true),
		"entry_intensity": intensity,
	})
	return _last_result.duplicate(true)


func detach() -> Dictionary:
	var presentation := _presentation()
	if presentation != null and bool(
		presentation.get_state_snapshot().get("configured", false)
	):
		presentation.reset_for_reuse(presentation.get_generation())
	_arrow_ref = null
	_hud_ref = null
	_attached = false
	_atmospheric = false
	_generation += 1
	_last_result = {}
	return _result(true, &"detached")


func get_snapshot() -> Dictionary:
	return {
		"component_id": COMPONENT_ID,
		"attached": _attached and _arrow() != null and _hud() != null,
		"generation": _generation,
		"branch_id": &"atmospheric" if _atmospheric else &"airless",
		"observation_count": _observation_count,
		"last_result": _last_result.duplicate(true),
		"presentation_only": true,
		"physics_authority": false,
		"movement_authority": false,
		"damage_authority": false,
		"landing_authority": false,
	}.duplicate(true)


func _arrow() -> ArrowReconShip:
	return _arrow_ref.get_ref() as ArrowReconShip if _arrow_ref != null else null


func _hud() -> GameHUD:
	return _hud_ref.get_ref() as GameHUD if _hud_ref != null else null


func _presentation() -> PlanetaryEntryHeatPresentation:
	var arrow := _arrow()
	return arrow.get_entry_heat_target().get_presentation() \
		if arrow != null and arrow.get_entry_heat_target() != null else null


func _result(
		accepted: bool, reason: StringName, extra: Dictionary = {}
	) -> Dictionary:
	var result := {
		"accepted": accepted,
		"reason": reason,
		"generation": _generation,
		"presentation_only": true,
		"physics_authority": false,
		"damage_authority": false,
	}
	for key: Variant in extra:
		result[key] = extra[key]
	return result.duplicate(true)


func _reject(reason: StringName, extra: Dictionary = {}) -> Dictionary:
	return _result(false, reason, extra)
