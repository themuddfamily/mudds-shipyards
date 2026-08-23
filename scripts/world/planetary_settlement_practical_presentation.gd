class_name PlanetarySettlementPracticalPresentation
extends Node3D

## Presentation-only exterior practical for one authored settlement. It owns
## one light target and consumes caller-owned solar phase; it owns no clock,
## settlement access, interaction, or gameplay state.

var _structure_id: StringName = &""
var _configured := false
var _generation := 0
var _light: OmniLight3D
var _last_solar: Dictionary = {}
var _graphics_profile: StringName = &"high"


func _ready() -> void:
	set_process(false)
	set_physics_process(false)
	_light = OmniLight3D.new()
	_light.name = "OwnedSettlementPractical"
	_light.omni_range = 18.0
	_light.light_energy = 0.0
	_light.visible = false
	add_child(_light)


func configure(structure_id: StringName) -> Dictionary:
	if _configured or structure_id.is_empty():
		return {"accepted": false, "reason": &"invalid_practical_configuration"}
	_structure_id = structure_id
	_configured = true
	_generation += 1
	return {"accepted": true, "reason": &"configured", "generation": _generation}


func apply_solar_phase(snapshot: Variant) -> Dictionary:
	if not _configured or _light == null or not snapshot is Dictionary:
		return {"accepted": false, "reason": &"invalid_solar_phase"}
	var solar := snapshot as Dictionary
	var state := StringName(solar.get("state", &""))
	var elevation: Variant = solar.get("sun_elevation_sine", NAN)
	if state not in [&"daylight", &"twilight", &"night"] \
			or not (elevation is float or elevation is int):
		return {"accepted": false, "reason": &"invalid_solar_phase"}
	var night_factor := clampf(-float(elevation), 0.0, 1.0) if state != &"daylight" else 0.0
	_light.visible = night_factor > 0.01
	var energy_cap := 0.45 if _graphics_profile == &"low" else 1.1
	_light.light_energy = clampf(night_factor * energy_cap, 0.0, energy_cap)
	_light.light_color = Color(1.0, 0.55 + night_factor * 0.2, 0.3 + night_factor * 0.25, 1.0)
	_last_solar = solar.duplicate(true)
	return {"accepted": true, "reason": &"practical_solar_applied", "night_factor_unitless": night_factor}


func apply_graphics_profile(profile: StringName) -> Dictionary:
	if profile not in [&"low", &"high"]:
		return {"accepted": false, "reason": &"invalid_graphics_profile"}
	_graphics_profile = profile
	if not _last_solar.is_empty():
		apply_solar_phase(_last_solar)
	return {"accepted": true, "reason": &"graphics_profile_applied", "profile": _graphics_profile}


func detach() -> Dictionary:
	if _light == null:
		return {"accepted": false, "reason": &"practical_unavailable"}
	_light.visible = false
	return {"accepted": true, "reason": &"practical_detached"}


func reenter() -> Dictionary:
	if _last_solar.is_empty():
		return {"accepted": false, "reason": &"practical_reentry_unavailable"}
	return apply_solar_phase(_last_solar)


func get_snapshot() -> Dictionary:
	return {"configured": _configured, "structure_id": _structure_id, "generation": _generation, "light_instance_id": _light.get_instance_id() if _light != null else 0, "visible": _light.visible if _light != null else false, "energy": _light.light_energy if _light != null else 0.0, "last_solar": _last_solar.duplicate(true), "graphics_profile": _graphics_profile, "authority": {"clock": false, "settlement_interaction": false, "gameplay": false, "movement": false}}.duplicate(true)
