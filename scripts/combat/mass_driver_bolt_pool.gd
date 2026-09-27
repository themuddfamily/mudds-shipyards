class_name MassDriverBoltPool
extends TravellingBoltProjectile

## The Cinder cargo hauler's mass-driver slugs: the shared travelling-bolt pool
## re-tinted in the player fleet's pale cyan so a friendly slug never reads as
## the picket's magenta lance or the Emberline raider's red pulse.
##
## Everything that matters is still inherited unchanged: every slug is an
## authority-issued flight on the one `CombatResolver`, its speed, lifetime,
## radius and range come back on the flight ticket, and the terminal segment is
## re-swept and committed by `LiveCombatAuthority.resolve_projectile_arrival()`.
## This subclass only chooses colours.
##
## Evidence status: modern_interpretation. No original Keth Shipyards weapon or
## effect is authenticated or claimed here.

const SLUG_CORE_COLOR := Color("d8fbff")
const SLUG_TRAIL_COLOR := Color("3fb6d9")

static var _slug_catalog: Dictionary = {}


func _build_pool() -> void:
	if _built:
		return
	super._build_pool()
	for slot: Dictionary in _slots:
		var light := slot.get("light") as OmniLight3D
		if is_instance_valid(light):
			light.light_color = SLUG_TRAIL_COLOR


func _material_catalog() -> Dictionary:
	if not _slug_catalog.is_empty():
		return _slug_catalog
	var shared := super._material_catalog()
	var tinted := shared.duplicate()
	for key: String in ["core_material", "reduced_core_material"]:
		var core := (shared[key] as StandardMaterial3D).duplicate() as StandardMaterial3D
		core.albedo_color = SLUG_CORE_COLOR
		core.emission = SLUG_CORE_COLOR
		tinted[key] = core
	for key: String in ["trail_material", "reduced_trail_material"]:
		var trail := (shared[key] as StandardMaterial3D).duplicate() as StandardMaterial3D
		trail.albedo_color = SLUG_TRAIL_COLOR
		trail.emission = SLUG_TRAIL_COLOR
		tinted[key] = trail
	_slug_catalog = tinted
	return _slug_catalog
