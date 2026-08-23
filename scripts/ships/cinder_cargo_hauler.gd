class_name CinderCargoHauler
extends HeroShip

const WeaponDefinitionType := preload("res://scripts/combat/weapon_definition.gd")

## Original-modern industrial cargo craft component. No historical class,
## silhouette, cargo contract, or ownership claim is authenticated here.

const SCHEMA_VERSION := 1
const COMPONENT_ID: StringName = &"cinder-cargo-hauler"
const EVIDENCE_STATUS: StringName = &"NEW"
const DISPLAY_NAME := "Cinder cargo hauler"
const CARGO_CAPACITY := 8
const HULL_SIZE := Vector3(6.4, 3.2, 12.0)
const WEAPON_ID: StringName = &"cinder_cargo_mass_driver"

const HULL_COLOR := Color("536b73")
const CARGO_COLOR := Color("b2773d")
const ACCENT_COLOR := Color("42c9cf")

var _cargo_cockpit_seat: Marker3D
var _cargo_boarding_marker: Marker3D
var _cargo_hold: Node3D
var _cargo_anchors: Array[Marker3D] = []
var _cargo_built := false
var _weapon_definition: WeaponDefinition


func _uses_torrent_reconstruction_presentation() -> bool:
	return false


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
	if not _cargo_built:
		_cargo_built = rebuild_variant_presentation(_build_cargo_variant)


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
	var lamp := MeshInstance3D.new()
	lamp.name = "CargoBoardingLamp"
	var lamp_mesh := BoxMesh.new()
	lamp_mesh.size = Vector3(0.18, 0.18, 0.8)
	lamp.mesh = lamp_mesh
	lamp.position = _cargo_boarding_marker.position + Vector3(0.2, 0.5, 0.0)
	lamp.material_override = _material(ACCENT_COLOR, 0.2, 0.42, ACCENT_COLOR, 1.8)
	visual.add_child(lamp)
	_build_cargo_hold(visual)
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
	return {
		"schema_version": SCHEMA_VERSION,
		"component_id": COMPONENT_ID,
		"evidence_status": EVIDENCE_STATUS,
		"content_class": EVIDENCE_STATUS,
		"historically_supported": false,
		"valid": errors.is_empty(),
		"errors": errors,
		"cargo_capacity": CARGO_CAPACITY,
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
	_add_box_collision_shape("CargoHullCollision", Vector3(0.0, 0.25, 0.0), HULL_SIZE)


func _build_hull(visual: Node3D) -> void:
	var hull := MeshInstance3D.new()
	hull.name = "IndustrialHull"
	var mesh := BoxMesh.new()
	mesh.size = HULL_SIZE
	hull.mesh = mesh
	hull.material_override = _material(HULL_COLOR, 0.72, 0.42)
	visual.add_child(hull)
	var cargo_pod := MeshInstance3D.new()
	cargo_pod.name = "CargoPod"
	var pod_mesh := BoxMesh.new()
	pod_mesh.size = Vector3(5.2, 2.2, 7.2)
	cargo_pod.mesh = pod_mesh
	cargo_pod.position = Vector3(0.0, 0.15, 1.0)
	cargo_pod.material_override = _material(CARGO_COLOR, 0.45, 0.42)
	visual.add_child(cargo_pod)


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
