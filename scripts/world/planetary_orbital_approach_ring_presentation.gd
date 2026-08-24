class_name PlanetaryOrbitalApproachRingPresentation
extends Node3D

## Presentation-only orbital approach ring at a caller-authored boundary anchor.

## Every live visitable-world presentation uses this exact immutable torus
## recipe. Retaining the geometry once for the class removes one mesh resource
## allocation for each additional ring while leaving each node, transform, and
## solar-responsive material independently owned.
static var _shared_ring_mesh: TorusMesh

# The ring is created as part of the surface composition, before the first
# caller-owned solar sample arrives.  Daylight is the least intrusive safe
# baseline, and makes the authored approach datum present on that first frame
# instead of appearing a frame later when the sample is applied.
const INITIAL_SUN_ELEVATION_SINE := 1.0

var _configured := false
var _anchor := Vector3.ZERO
var _profile: StringName = &"high"
var _ring: MeshInstance3D
var _material: StandardMaterial3D
var _last_solar: Dictionary = {}

func _ready() -> void:
	set_process(false)
	set_physics_process(false)
	_ring = MeshInstance3D.new()
	_ring.name = "OwnedOrbitalApproachRing"
	if _shared_ring_mesh == null:
		_shared_ring_mesh = TorusMesh.new()
		_shared_ring_mesh.inner_radius = 18.0
		_shared_ring_mesh.outer_radius = 20.0
	_ring.mesh = _shared_ring_mesh
	_material = StandardMaterial3D.new()
	_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_material.emission_enabled = true
	_material.emission = Color(0.2, 0.55, 1.0, 1.0)
	_ring.material_override = _material
	_ring.visible = false
	add_child(_ring)

func configure(anchor: Vector3) -> Dictionary:
	if _configured or not anchor.is_finite():
		return {"accepted": false, "reason": &"invalid_orbital_ring_configuration"}
	_anchor = anchor
	position = anchor
	_configured = true
	apply_solar_phase({"sun_elevation_sine": INITIAL_SUN_ELEVATION_SINE})
	return {"accepted": true, "reason": &"configured"}

func apply_solar_phase(solar: Variant) -> Dictionary:
	if not _configured or _material == null or not solar is Dictionary:
		return {"accepted": false, "reason": &"invalid_orbital_ring_solar"}
	var elevation: Variant = (solar as Dictionary).get("sun_elevation_sine", NAN)
	if not (elevation is float or elevation is int):
		return {"accepted": false, "reason": &"invalid_orbital_ring_solar"}
	var night := clampf(-float(elevation), 0.0, 1.0)
	var energy := clampf(0.15 + night * 0.95, 0.1, 1.1)
	if _profile == &"low":
		_ring.visible = false
	else:
		_ring.visible = true
	_material.emission_energy_multiplier = energy if _profile == &"high" else minf(energy, 0.65)
	_last_solar = (solar as Dictionary).duplicate(true)
	return {"accepted": true, "reason": &"orbital_ring_solar_applied"}

func apply_graphics_profile(profile: StringName) -> Dictionary:
	if profile not in [&"low", &"medium", &"high"]:
		return {"accepted": false, "reason": &"invalid_graphics_profile"}
	_profile = profile
	if not _last_solar.is_empty():
		apply_solar_phase(_last_solar)
	return {"accepted": true, "reason": &"graphics_profile_applied"}

func detach() -> Dictionary:
	if _ring == null:
		return {"accepted": false, "reason": &"orbital_ring_unavailable"}
	_ring.visible = false
	return {"accepted": true, "reason": &"orbital_ring_detached"}

func reenter() -> Dictionary:
	if _last_solar.is_empty():
		return {"accepted": false, "reason": &"orbital_ring_reentry_unavailable"}
	return apply_solar_phase(_last_solar)

func get_snapshot() -> Dictionary:
	return {"configured": _configured, "anchor_body_local_m": _anchor, "visible": _ring.visible if _ring != null else false, "graphics_profile": _profile, "authority": {"navigation": false, "entry": false, "flight": false, "clock": false}}.duplicate(true)
