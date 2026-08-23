class_name BulwarkHeavyGunship
extends HeroShip

## Original-modern heavy gunship component.
##
## This is a new design, not a reconstruction: it has no historical evidence
## references and makes no claim about a recovered silhouette. The common
## HeroShip controller remains the sole owner of flight, pilot weapon requests,
## damage, boarding lifecycle, and reuse; optional gunner fire is admitted by
## the seat authority and resolved by the shared combat authority.

const ModernRoleProfile := preload("res://scripts/fleet/modern_role_profile.gd")
const CrewSeatRoleAuthorityType := preload("res://scripts/ships/crew_seat_role_authority.gd")
const CrewRoleGameplayProfileType := preload("res://scripts/fleet/crew_role_gameplay_profile.gd")
const LiveCombatAuthorityType := preload("res://scripts/combat/live_combat_authority.gd")
const WeaponDefinitionType := preload("res://scripts/combat/weapon_definition.gd")
const WeaponDefinitionResolverProfileType := preload("res://scripts/combat/weapon_definition_resolver_profile.gd")
const SiegeLanceDefinition := preload("res://assets/weapons/picket_siege_lance.tres")
const SiegeLanceAudioBindingType := preload("res://scripts/audio/siege_lance_audio_binding.gd")

const SCHEMA_VERSION := 1
const COMBAT_SOURCE_ID := 1106
const EVIDENCE_STATUS: StringName = &"new"
const EVIDENCE_STATUS_ENUM: int = ShipDefinition.EvidenceStatus.NEW
const EVIDENCE_SCOPE: StringName = &"original_modern_design"
const DESIGN_NOTE := (
	"Bulwark is an original modern heavy gunship component. It has no historical "
	+ "evidence references and makes no claim about an authenticated silhouette, "
	+ "name, role, systems, or continuity."
)

# A dark blue-black armored body with a high-visibility amber identity band is
# intentionally unlike the fleet's recon slate, freighter clay, and interceptor
# purple.  The broad shoulder plates and chin armor make the silhouette read as
# a durable gunship rather than a stretched fighter.
const ARMOR_DARK := Color("101b2a")
const ARMOR_BLUE := Color("243f5b")
const ARMOR_HIGHLIGHT := Color("416b88")
const IDENTITY_AMBER := Color("e2a63c")
const GUNNER_CYAN := Color("58d8df")
const BOARDING_LIGHT := Color("8ae8bd")
const BULWARK_CREW_WEAPON_ID: StringName = &"picket_siege_lance"
const BULWARK_CREW_FACTION_ID: StringName = &"shipyard_flight_test"
const MAX_GUNNER_TARGET_GENERATION := 1_000_000
const MAX_GUNNER_AMMUNITION := 8
const GUNNER_SIEGE_CHARGE_TIME := 0.45
const GUNNER_SEAT_ID: StringName = &"gunner_station"
const PILOT_SEAT_ID: StringName = &"pilot_station"
const ENGINEER_SEAT_ID: StringName = &"engineer_slot"

const HULL_COLLISION_SIZE := Vector3(6.9, 3.1, 10.8)
const SHOULDER_COLLISION_SIZE := Vector3(11.6, 2.1, 5.8)
const CHIN_COLLISION_SIZE := Vector3(4.8, 1.1, 4.0)
const GUNNER_STATION_LOCAL_POSITION := Vector3(2.35, 1.55, 0.55)

var _bulwark_built := false
var _bulwark_visual: Node3D
var _gunner_station: Node3D
var _gunner_station_anchor: Marker3D
var _boarding_area: Area3D
var _crew_role_authority: CrewSeatRoleAuthority
var _gunner_combat_authority: LiveCombatAuthority
var _gunner_weapon_definition: WeaponDefinition
var _gunner_role_cooldowns: Dictionary = {}
var _gunner_role_ammunition: Dictionary = {}
var _gunner_role_charges: Dictionary = {}
var _gunner_target_selection: Dictionary = {}
var _gunner_target_generation := 1
var _engineer_component_selection: Dictionary = {}
var _engineer_component_generation := 1
var _siege_lance_audio_sequence := 0
var _siege_lance_audio_binding: RefCounted

signal gunner_target_selected(target_id: StringName, target_generation: int, receipt: Dictionary)
signal gunner_target_cleared(target_id: StringName, target_generation: int, reason: StringName)
signal gunner_charge_changed(actor_key: StringName, target_generation: int, progress: float, reason: StringName)
signal siege_lance_audio_record(record: Dictionary)


func _init() -> void:
	# Standalone construction is useful to tools and focused tests, so provide
	# the same definition a scene would normally serialize without registering
	# this component in any berth or world catalogue.
	var profile: Dictionary = ModernRoleProfile.get_profile()
	var definition := ShipDefinition.new()
	definition.ship_id = &"bulwark_heavy_gunship"
	definition.display_name = "Bulwark Heavy Gunship"
	definition.role_name = "Heavy gunship"
	definition.evidence_status = EVIDENCE_STATUS_ENUM
	definition.evidence_references = PackedStringArray()
	definition.evidence_notes = DESIGN_NOTE
	definition.compatibility_tags = PackedStringArray([
		"medium_craft", "gunship", "bulwark_gunship", "single_pilot",
	])
	var flight: Dictionary = profile.get("flight_profile", {})
	definition.maximum_speed = float(flight.get("maximum_speed", 98.0))
	definition.thrust_acceleration = float(flight.get("thrust_acceleration", 22.0))
	definition.brake_acceleration = float(flight.get("brake_acceleration", 30.0))
	definition.passive_drag = float(flight.get("passive_drag", 2.35))
	definition.throttle_response = float(flight.get("throttle_response", 6.4))
	# The pre-art profile intentionally compares a lower boost-speed budget;
	# ShipDefinition requires the executable profile to boost at least as fast as
	# its cruise speed, so the component supplies that bounded runtime correction.
	definition.boost_speed = 120.0
	definition.boost_multiplier = float(flight.get("boost_multiplier", 1.22))
	definition.yaw_speed_degrees = float(flight.get("yaw_speed_degrees", 46.0))
	definition.roll_speed_degrees = float(flight.get("roll_speed_degrees", 68.0))
	var systems: Dictionary = profile.get("systems_profile", {})
	definition.engine_start_time = float(systems.get("engine_start_time", 2.75))
	# The runtime fit owns the fleet's highest hull budget while retaining a
	# deliberately slower cadence than the interceptor specialists.
	definition.weapon_cooldown = 0.30
	definition.maximum_hull = 300.0
	definition.landing_maximum_speed = float(systems.get("landing_maximum_speed", 13.0))
	definition.entry_noun = "armored canopy"
	definition.entry_open_verb = "unlock"
	definition.entry_close_verb = "seal"
	definition.boarding_verb = "board"
	definition.audio_profile_id = &"bulwark_heavy_gunship"
	ship_definition = definition
	ship_id = definition.ship_id
	display_name = definition.display_name
	role_name = definition.role_name
	home_berth_id = &"bulwark_fleet_dock_berth"
	identification_accent = IDENTITY_AMBER
	minimum_chase_camera_distance = 14.0
	maximum_chase_camera_distance = 32.0
	cockpit_camera_position = Vector3(0.0, 3.32, -0.68)
	impact_damage_threshold = 58.0
	impact_damage_scale = 1.15


func _uses_torrent_reconstruction_presentation() -> bool:
	return false


func _enter_tree() -> void:
	super._enter_tree()
	if _bulwark_built:
		_bind_siege_lance_audio()
	var rig := get_node_or_null("ShipAudioRig") as ShipAudioRig
	if rig != null:
		rig.profile_id = ShipAudioRig.PROFILE_HEAVY_QUAD_FREIGHTER


func _ready() -> void:
	super._ready()
	_gunner_weapon_definition = SiegeLanceDefinition.duplicate(true) as WeaponDefinition
	if not _bulwark_built:
		_bulwark_built = rebuild_variant_presentation(_build_bulwark_variant)
	_apply_bulwark_metadata()
	_bind_siege_lance_audio()

func _exit_tree() -> void:
	_unbind_siege_lance_audio()
	super._exit_tree()


func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	if _reset_for_reuse_mutation_blocked():
		return
	_advance_gunner_role_cooldowns(maxf(delta, 0.0))
	_advance_gunner_role_charges(maxf(delta, 0.0))
	_cleanup_detached_gunner_state()


func _commit_variant_reset_for_reuse(context: Dictionary) -> void:
	super._commit_variant_reset_for_reuse(context)
	if _siege_lance_audio_binding != null:
		_siege_lance_audio_binding.reset_for_reuse()
	_gunner_role_cooldowns.clear()
	_gunner_role_ammunition.clear()
	_clear_all_gunner_charges(&"ship_reused")
	_clear_gunner_target_selection(&"ship_reused", false)
	_gunner_target_generation = 1
	_clear_engineer_component_selection(&"ship_reused", false)
	_engineer_component_generation = 1

func get_siege_lance_audio_binding() -> RefCounted:
	return _siege_lance_audio_binding

func _bind_siege_lance_audio() -> void:
	if _siege_lance_audio_binding == null:
		_siege_lance_audio_binding = SiegeLanceAudioBindingType.new()
	else:
		var snapshot: Dictionary = _siege_lance_audio_binding.get_snapshot()
		if bool(snapshot.get("attached", false)):
			return
	_siege_lance_audio_binding.attach(self, int(_siege_lance_audio_binding.get_snapshot().get("generation", 0)))

func _unbind_siege_lance_audio() -> void:
	if _siege_lance_audio_binding != null:
		_siege_lance_audio_binding.detach()


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
		_gunner_role_cooldowns.clear()
		_gunner_role_ammunition.clear()
		_clear_all_gunner_charges(&"ship_destroyed")
		_clear_gunner_target_selection(&"ship_destroyed")
		_clear_engineer_component_selection(&"ship_destroyed")


func _build_bulwark_variant(_controller: HeroShip) -> bool:
	var inherited_visual := get_variant_visual_root()
	if inherited_visual == null:
		return false
	# Preserve the inherited functional cockpit and canopy.  Their private HeroShip
	# references remain valid while all source-specific exterior geometry goes.
	var cockpit := inherited_visual.get_node_or_null("CockpitInterior") as Node3D
	var canopy := inherited_visual.get_node_or_null("CanopyHinge") as Node3D
	var hinge_bar := inherited_visual.get_node_or_null("CanopyHingeBar") as Node3D
	var hinge_mounts := inherited_visual.find_children("*CanopyHingeMount", "Node3D", false, false)
	for preserved in [cockpit, canopy, hinge_bar]:
		if preserved != null:
			preserved.reparent(self, true)
	for mount in hinge_mounts:
		(mount as Node3D).reparent(self, true)
	if inherited_visual.get_parent() != null:
		inherited_visual.get_parent().remove_child(inherited_visual)
	inherited_visual.free()

	_bulwark_visual = Node3D.new()
	_bulwark_visual.name = "BulwarkHeavyGunshipVisual"
	_bulwark_visual.set_meta("geometry_status", EVIDENCE_STATUS)
	_bulwark_visual.set_meta("authenticated_historical_silhouette", false)
	_bulwark_visual.set_meta("content_note", DESIGN_NOTE)
	add_child(_bulwark_visual)
	if cockpit != null:
		cockpit.reparent(_bulwark_visual, true)
	if canopy != null:
		canopy.reparent(_bulwark_visual, true)
	if hinge_bar != null:
		hinge_bar.reparent(_bulwark_visual, true)
	for mount in hinge_mounts:
		(mount as Node3D).reparent(_bulwark_visual, true)

	var armor_dark := _material(ARMOR_DARK, 0.78, 0.32)
	var armor_blue := _material(ARMOR_BLUE, 0.72, 0.28)
	var armor_highlight := _material(ARMOR_HIGHLIGHT, 0.66, 0.25)
	var amber := _material(IDENTITY_AMBER, 0.52, 0.31)
	var cyan := _material(GUNNER_CYAN, 0.25, 0.2, GUNNER_CYAN, 1.8)
	var boarding := _material(BOARDING_LIGHT, 0.18, 0.22, BOARDING_LIGHT, 1.2)

	# Armored slab, raised shoulders, chin keel, and rear engine housings form a
	# broad, compact silhouette with a visible centerline armor spine.
	_box(_bulwark_visual, "ArmoredCentralSlab", Vector3(0.0, 1.35, 0.25), Vector3(6.4, 2.7, 8.5), armor_blue)
	_wedge(_bulwark_visual, "ArmoredNose", Vector3(0.0, 1.5, -4.65), Vector3(5.8, 2.8, 3.9), armor_highlight, 0.0)
	_box(_bulwark_visual, "CenterlineArmorSpine", Vector3(0.0, 2.95, 0.45), Vector3(1.35, 0.38, 8.4), armor_highlight)
	_box(_bulwark_visual, "ChinArmor", Vector3(0.0, 0.02, -2.2), CHIN_COLLISION_SIZE, armor_dark)
	for side in [-1.0, 1.0]:
		var side_name := "Port" if side < 0.0 else "Starboard"
		_box(_bulwark_visual, side_name + "ArmoredShoulder", Vector3(side * 4.15, 1.05, 0.55), Vector3(3.4, 1.9, 5.3), armor_dark)
		_box(_bulwark_visual, side_name + "IdentityBand", Vector3(side * 4.18, 1.55, -0.2), Vector3(0.16, 1.25, 3.2), amber)
		_cylinder(_bulwark_visual, side_name + "GunPodHousing", Vector3(side * 3.25, 1.0, -3.1), 0.42, 2.15, armor_highlight, Vector3(0.0, 90.0, 0.0))
		_cylinder(_bulwark_visual, side_name + "EngineHousing", Vector3(side * 2.65, 1.15, 4.25), 0.72, 2.8, armor_dark, Vector3(90.0, 0.0, 0.0))
		_sphere(_bulwark_visual, side_name + "NavigationLamp", Vector3(side * 4.35, 1.8, -2.5), 0.11, boarding if side < 0.0 else amber)

	# Gunner station is physical ship-local presentation and interaction data;
	# its optional siege-lance action is resolved by the shared combat authority.
	_gunner_station = Node3D.new()
	_gunner_station.name = "GunnerStation"
	_gunner_station.position = GUNNER_STATION_LOCAL_POSITION
	_gunner_station.set_meta("crew_role", &"gunner")
	_gunner_station.set_meta("authority_owner", &"LiveCombatAuthority.resolve_hitscan")
	_gunner_station.set_meta("visual_only_weapon_fit", false)
	_gunner_station.set_meta("authenticated_historical_role", false)
	_bulwark_visual.add_child(_gunner_station)
	_box(_gunner_station, "GunnerSeat", Vector3.ZERO, Vector3(0.95, 0.32, 0.95), armor_dark)
	_box(_gunner_station, "GunnerSeatBack", Vector3(0.0, 0.62, 0.28), Vector3(1.0, 1.1, 0.2), armor_dark, Vector3(deg_to_rad(10.0), 0.0, 0.0))
	_box(_gunner_station, "GunnerConsole", Vector3(0.0, 0.62, -0.65), Vector3(1.7, 0.16, 0.75), armor_highlight, Vector3(deg_to_rad(-14.0), 0.0, 0.0))
	_box(_gunner_station, "GunnerDisplay", Vector3(0.0, 0.76, -1.02), Vector3(0.82, 0.34, 0.06), cyan, Vector3(deg_to_rad(-14.0), 0.0, 0.0))
	_gunner_station_anchor = Marker3D.new()
	_gunner_station_anchor.name = "GunnerStationAnchor"
	_gunner_station_anchor.position = Vector3(0.0, 0.4, 0.0)
	_gunner_station_anchor.set_meta("crew_role", &"gunner")
	_gunner_station_anchor.set_meta("seat_type", &"physical")
	_gunner_station.add_child(_gunner_station_anchor)

	# The inherited markers are the common combat/entry seams. Move only their
	# ship-local placement; no replacement weapon or pilot authority is created.
	var left_muzzle := get_node_or_null("LeftMuzzle") as Marker3D
	var right_muzzle := get_node_or_null("RightMuzzle") as Marker3D
	if left_muzzle != null:
		left_muzzle.position = Vector3(-3.2, 1.08, -5.0)
	if right_muzzle != null:
		right_muzzle.position = Vector3(3.2, 1.08, -5.0)
	var boarding_marker := get_node_or_null("BoardingPoint") as Marker3D
	if boarding_marker != null:
		boarding_marker.position = Vector3(-5.9, 0.1, 1.0)
		boarding_marker.set_meta("interaction_role", &"boarding")
	var pilot := get_pilot_seat_anchor()
	if pilot != null:
		pilot.set_meta("crew_role", &"pilot")
		pilot.set_meta("seat_type", &"physical")

	# Replace the temporary Torrent collision envelope with a compact armored
	# envelope.  These are gameplay collision shapes, not a second damage model.
	for collision_node in find_children("*", "CollisionShape3D", true, false):
		var collision := collision_node as CollisionShape3D
		if collision != null:
			collision.get_parent().remove_child(collision)
			collision.free()
	_add_box_collision_shape("BulwarkHullCollision", Vector3(0.0, 1.35, 0.25), HULL_COLLISION_SIZE)
	_add_box_collision_shape("BulwarkShoulderCollision", Vector3(0.0, 1.0, 0.55), SHOULDER_COLLISION_SIZE)
	_add_box_collision_shape("BulwarkChinCollision", Vector3(0.0, 0.02, -2.2), CHIN_COLLISION_SIZE)
	
	_boarding_area = Area3D.new()
	_boarding_area.name = "BulwarkBoardingArea"
	_boarding_area.collision_layer = 0
	_boarding_area.collision_mask = 0
	_boarding_area.set_meta("interaction_role", &"boarding")
	_boarding_area.set_meta("authority_owner", &"HeroShip.boarding")
	var boarding_shape := CollisionShape3D.new()
	var boarding_box := BoxShape3D.new()
	boarding_box.size = Vector3(2.1, 2.0, 2.0)
	boarding_shape.shape = boarding_box
	boarding_shape.position = Vector3(-5.9, 1.0, 1.0)
	_boarding_area.add_child(boarding_shape)
	add_child(_boarding_area)

	return replace_variant_visual_root(_bulwark_visual)


func get_gunner_station_anchor() -> Marker3D:
	return _gunner_station_anchor


## Stable local combat registry identity for this craft. The shared combat
## authority remains the owner of actual source registration and damage.
func get_combat_source_id() -> int:
	return COMBAT_SOURCE_ID


## Binds the injected server-owned role ledger. Bulwark consumes only the
## physical pilot and gunner entries; the authority may carry other role slots
## for a shared vessel policy, but this ship never creates a second ledger.
func attach_crew_role_authority(authority: CrewSeatRoleAuthority) -> Dictionary:
	if authority == null:
		return _crew_role_result(false, &"authority_unavailable")
	if _crew_role_authority != null and _crew_role_authority != authority:
		return _crew_role_result(false, &"authority_already_attached")
	var snapshot := authority.get_snapshot()
	if not bool(snapshot.get("roster_sealed", false)):
		return _crew_role_result(false, &"roster_not_sealed")
	var has_pilot := false
	var has_gunner := false
	for seat_variant in snapshot.get("seats", []) as Array:
		if not seat_variant is Dictionary:
			continue
		var seat := seat_variant as Dictionary
		if StringName(seat.get("vessel_id", &"")) != get_ship_id():
			continue
		if StringName(seat.get("seat_id", &"")) == PILOT_SEAT_ID \
				and StringName(seat.get("role", &"")) == CrewRoleGameplayProfileType.ROLE_PILOT:
			has_pilot = true
		if StringName(seat.get("seat_id", &"")) == GUNNER_SEAT_ID \
				and StringName(seat.get("role", &"")) == CrewRoleGameplayProfileType.ROLE_GUNNER:
			has_gunner = true
	if not has_pilot or not has_gunner:
		return _crew_role_result(false, &"bulwark_roster_mismatch")
	_crew_role_authority = authority
	var result := _crew_role_result(true, &"authority_attached")
	result["role_count"] = (snapshot.get("seats", []) as Array).size()
	return result


func get_crew_role_authority() -> CrewSeatRoleAuthority:
	return _crew_role_authority


## Binds the shared server combat authority used by the optional gunner. This
## does not create a second resolver or damage path; the caller owns the
## authority lifecycle and may already have registered Bulwark for pilot fire.
func attach_gunner_combat_authority(authority: LiveCombatAuthority) -> Dictionary:
	if authority == null or not is_instance_valid(authority):
		return _crew_role_result(false, &"combat_authority_unavailable")
	if _gunner_combat_authority != null and _gunner_combat_authority != authority:
		return _crew_role_result(false, &"combat_authority_already_attached")
	if _gunner_weapon_definition == null:
		_gunner_weapon_definition = SiegeLanceDefinition.duplicate(true) as WeaponDefinition
	var profiles := WeaponDefinitionResolverProfileType.to_resolver_profiles(
		_gunner_weapon_definition,
		BULWARK_CREW_FACTION_ID,
		12.0
	)
	if profiles.is_empty():
		return _crew_role_result(false, &"siege_lance_definition_invalid")
	_gunner_combat_authority = authority
	var registered_profile := authority.get_weapon_profile(self, BULWARK_CREW_WEAPON_ID)
	if registered_profile.is_empty():
		if not authority.register_source(self, COMBAT_SOURCE_ID, BULWARK_CREW_FACTION_ID, profiles):
			_gunner_combat_authority = null
			return _crew_role_result(false, &"combat_source_registration_failed")
	return {
		"accepted": true,
		"status": &"combat_authority_attached",
		"source_id": COMBAT_SOURCE_ID,
		"weapon_id": BULWARK_CREW_WEAPON_ID,
		"weapon_profile": authority.get_weapon_profile(self, BULWARK_CREW_WEAPON_ID),
	}.duplicate(true)


func get_gunner_weapon_definition() -> WeaponDefinition:
	if _gunner_weapon_definition == null:
		_gunner_weapon_definition = SiegeLanceDefinition.duplicate(true) as WeaponDefinition
	return _gunner_weapon_definition.duplicate(true) as WeaponDefinition


func _get_gunner_component_operational_state() -> Dictionary:
	var modifiers := get_operational_modifiers()
	if modifiers.is_empty():
		return {"available": false, "reason": &"component_damage_unavailable"}
	var fire_multiplier := clampf(float(modifiers.get("fire_multiplier", 0.0)), 0.0, 1.0)
	if fire_multiplier <= 0.0 or bool(modifiers.get("fire_disabled", true)):
		return {
			"available": false,
			"reason": &"gunner_weapon_component_failed",
			"fire_multiplier": fire_multiplier,
			"modifiers": modifiers.duplicate(true),
		}.duplicate(true)
	var base_cooldown := 1.0 / maxf(float(_gunner_weapon_definition.cadence_shots_per_second), 0.001)
	return {
		"available": true,
		"reason": &"component_operational",
		"fire_multiplier": fire_multiplier,
		"charge_time": GUNNER_SIEGE_CHARGE_TIME / fire_multiplier,
		"cooldown": base_cooldown / fire_multiplier,
		"modifiers": modifiers.duplicate(true),
	}.duplicate(true)


## Admits one authority receipt and immediately routes the bounded gunner edge
## into the shared CombatResolver hitscan seam. Pilot control remains the
## normal HeroShip path and is never gated by this optional station.
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
	if StringName(assignment.get("role", &"")) == CrewRoleGameplayProfileType.ROLE_ENGINEER \
			and StringName(assignment.get("seat_id", &"")) == ENGINEER_SEAT_ID \
			and action == CrewRoleGameplayProfileType.ACTION_ENGINEER_REPAIR:
		var repair_admission := _crew_role_authority.submit_intent(
			source_peer_id,
			occupant_peer_id,
			avatar_id,
			action,
			payload,
			request_sequence
		)
		if not bool(repair_admission.get("accepted", false)):
			return repair_admission
		var repair_effect := _consume_engineer_repair_intent(
			repair_admission.get("intent", {}) as Dictionary
		)
		var repair_result := repair_admission.duplicate(true)
		repair_result["status"] = (
			&"intent_consumed" if bool(repair_effect.get("accepted", false))
			else &"intent_effect_rejected"
		)
		repair_result["consumed"] = bool(repair_effect.get("accepted", false))
		repair_result["effect"] = repair_effect
		return repair_result
	if StringName(assignment.get("role", &"")) != CrewRoleGameplayProfileType.ROLE_GUNNER \
			or StringName(assignment.get("seat_id", &"")) != GUNNER_SEAT_ID \
			or action != CrewRoleGameplayProfileType.ACTION_GUNNER_FIRE:
		return _crew_role_result(false, &"unsupported_bulwark_role_action")
	var admission := _crew_role_authority.submit_intent(
		source_peer_id,
		occupant_peer_id,
		avatar_id,
		action,
		payload,
		request_sequence
	)
	if not bool(admission.get("accepted", false)):
		return admission
	var effect := _consume_gunner_fire_intent(admission.get("intent", {}) as Dictionary)
	var result := admission.duplicate(true)
	result["status"] = &"intent_consumed" if bool(effect.get("accepted", false)) else &"intent_effect_rejected"
	result["consumed"] = bool(effect.get("accepted", false))
	result["effect"] = effect
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
	var result := _crew_role_authority.release(
		source_peer_id,
		occupant_peer_id,
		avatar_id,
		seat_id,
		request_sequence,
		seat_generation
	)
	if bool(result.get("accepted", false)):
		_clear_gunner_role_state(occupant_peer_id, avatar_id, &"role_released")
		_clear_engineer_component_state(occupant_peer_id, avatar_id, &"role_released")
	return result


func handoff_crew_role(
		source_peer_id: int,
		previous_occupant_peer_id: int,
		previous_avatar_id: StringName,
		seat_id: StringName,
		release_request_sequence: int,
		new_occupant_peer_id: int,
		new_avatar_id: StringName,
		requested_role: StringName,
		claim_request_sequence: int,
		seat_generation: int = 0
) -> Dictionary:
	if _crew_role_authority == null:
		return _crew_role_result(false, &"authority_unavailable")
	var result := _crew_role_authority.handoff(
		source_peer_id,
		previous_occupant_peer_id,
		previous_avatar_id,
		seat_id,
		release_request_sequence,
		new_occupant_peer_id,
		new_avatar_id,
		requested_role,
		claim_request_sequence,
		seat_generation
	)
	if bool(result.get("accepted", false)):
		_clear_gunner_role_state(previous_occupant_peer_id, previous_avatar_id, &"role_handoff")
		_clear_engineer_component_state(previous_occupant_peer_id, previous_avatar_id, &"role_handoff")
	return result


func get_gunner_gameplay_state() -> Dictionary:
	var ready := _weapon_timer <= 0.0 and not is_destroyed()
	return {
		"schema_version": 1,
		"authority_attached": _crew_role_authority != null,
		"target_generation": _gunner_target_generation,
		"target_selection": _gunner_target_selection.duplicate(true),
		"weapon_ready": ready,
		"role_cooldowns": _gunner_role_cooldowns.duplicate(true),
		"role_ammunition": _gunner_role_ammunition.duplicate(true),
		"role_charges": _gunner_role_charges.duplicate(true),
		"engineer_component_generation": _engineer_component_generation,
		"engineer_component_selection": _engineer_component_selection.duplicate(true),
		"gunner_component": _get_gunner_component_operational_state(),
	}.duplicate(true)


func _consume_gunner_fire_intent(intent: Dictionary) -> Dictionary:
	var payload := intent.get("payload", {}) as Dictionary
	var weapon_id := StringName(payload.get("weapon_id", &""))
	var target_id := StringName(payload.get("target_id", &""))
	var target_generation := int(payload.get("target_generation", 0))
	if weapon_id != BULWARK_CREW_WEAPON_ID:
		return _crew_role_result(false, &"weapon_not_authorized")
	if target_generation != _gunner_target_generation:
		return _crew_role_result(false, &"stale_target_generation")
	if target_id.is_empty() or str(target_id).length() > 64:
		return _crew_role_result(false, &"invalid_target_identity")
	var selection := _select_gunner_target(intent, target_id, target_generation)
	if not bool(selection.get("accepted", false)):
		return selection
	var telemetry := get_telemetry()
	if bool(telemetry.get("destroyed", false)):
		return _crew_role_result(false, &"ship_destroyed")
	if StringName(telemetry.get("engine_state", &"")) != ENGINE_ONLINE:
		return _crew_role_result(false, &"engine_not_online")
	var actor_key := _gunner_role_actor_key(intent)
	if not bool(payload.get("trigger", false)):
		return selection
	if float(_gunner_role_cooldowns.get(actor_key, 0.0)) > 0.0:
		return _crew_role_result(false, &"role_cooldown")
	if not _gunner_role_charges.has(actor_key):
		var component_state := _get_gunner_component_operational_state()
		if not bool(component_state.get("available", false)):
			var blocked := _crew_role_result(
				false,
				StringName(component_state.get("reason", &"component_damage_unavailable"))
			)
			blocked["component"] = component_state.duplicate(true)
			return blocked
		_start_gunner_charge(
			intent,
			target_id,
			target_generation,
			float(component_state.get("charge_time", GUNNER_SIEGE_CHARGE_TIME))
		)
		var started := _gunner_charge_result(actor_key, &"charge_started", selection)
		started["component"] = component_state.duplicate(true)
		return started
	var charge := _gunner_role_charges.get(actor_key, {}) as Dictionary
	if not _is_gunner_charge_authorized(intent, charge):
		_cancel_gunner_charge(actor_key, &"charge_revalidated_failed")
		return _crew_role_result(false, &"stale_charge_authorization")
	var charge_progress := float(charge.get("elapsed", 0.0)) / maxf(
		float(charge.get("charge_time", GUNNER_SIEGE_CHARGE_TIME)),
		0.001
	)
	if charge_progress < 1.0:
		return _gunner_charge_result(actor_key, &"charge_progress", selection)
	var ammunition := mini(int(_gunner_role_ammunition.get(actor_key, 2)), MAX_GUNNER_AMMUNITION)
	if ammunition <= 0:
		return _crew_role_result(false, &"ammunition_depleted")
	var authority := _gunner_combat_authority
	if authority == null or not is_instance_valid(authority):
		return _crew_role_result(false, &"combat_authority_unavailable")
	if authority.get_weapon_profile(self, weapon_id).is_empty():
		return _crew_role_result(false, &"weapon_not_registered")
	var component_state := _get_gunner_component_operational_state()
	if not bool(component_state.get("available", false)):
		_cancel_gunner_charge(actor_key, StringName(component_state.get("reason", &"component_damage_unavailable")))
		var blocked := _crew_role_result(false, StringName(component_state.get("reason", &"component_damage_unavailable")))
		blocked["component"] = component_state.duplicate(true)
		return blocked
	var origin: Vector3 = payload.get("origin", global_position)
	var direction: Vector3 = payload.get("direction", -global_basis.z)
	if not origin.is_finite() or not direction.is_finite() or direction.length_squared() <= 0.000001:
		return _crew_role_result(false, &"invalid_fire_vector")
	var result := authority.submit_hitscan_with_deferred_presentation(
		self, weapon_id, origin, direction
	)
	if not bool(result.get("accepted", false)):
		return _crew_role_result(false, StringName(result.get("status", &"shot_rejected")))
	_emit_siege_lance_audio(&"dispatch")
	_emit_siege_lance_audio(&"impact")
	var effect := _crew_role_result(true, &"siege_lance_resolved")
	effect["resolution"] = result.duplicate(true)
	effect["source_id"] = get_combat_source_id()
	effect["faction_id"] = BULWARK_CREW_FACTION_ID
	effect["weapon_id"] = weapon_id
	effect["target_id"] = target_id
	effect["target_generation"] = target_generation
	effect["selection"] = selection
	effect["request_sequence"] = int(intent.get("request_sequence", -1))
	effect["seat_generation"] = int(intent.get("seat_generation", 0))
	var cooldown := float(component_state.get("cooldown", 1.0))
	effect["cooldown_remaining"] = cooldown
	effect["ammunition_remaining"] = ammunition - 1
	effect["component"] = component_state.duplicate(true)
	_gunner_role_cooldowns[actor_key] = cooldown
	_gunner_role_ammunition[actor_key] = ammunition - 1
	_cancel_gunner_charge(actor_key, &"dispatched")
	return effect


func _emit_siege_lance_audio(event_id: StringName) -> void:
	_siege_lance_audio_sequence += 1
	siege_lance_audio_record.emit({
		"generation": 0,
		"sequence": _siege_lance_audio_sequence,
		"transaction_id": StringName("bulwark_siege_lance_%d" % _siege_lance_audio_sequence),
		"weapon_id": BULWARK_CREW_WEAPON_ID,
		"event_id": event_id,
		"accepted": true,
	}.duplicate(true))


func _consume_engineer_repair_intent(intent: Dictionary) -> Dictionary:
	var payload := intent.get("payload", {}) as Dictionary
	var component_id := StringName(payload.get("system_id", &""))
	var requested_repair := float(payload.get("repair", 0.0))
	var component_generation := int(payload.get("system_generation", 0))
	var model := get_component_damage()
	if model == null or not model.is_configured():
		return _crew_role_result(false, &"component_damage_unavailable")
	var telemetry := get_telemetry()
	if bool(telemetry.get("destroyed", false)):
		return _crew_role_result(false, &"ship_destroyed")
	if not bool(telemetry.get("landed", false)) or bool(telemetry.get("landing_active", false)):
		return _crew_role_result(false, &"repair_requires_berthed_ship")
	var report := model.get_component_report()
	if not (report.get("component_order", []) as Array).has(component_id):
		return _crew_role_result(false, &"foreign_component")
	if component_generation != _engineer_component_generation:
		return _crew_role_result(false, &"stale_component_generation")
	var before := model.get_component_integrity(component_id)
	if before < 0.0:
		return _crew_role_result(false, &"foreign_component")
	if before >= 1.0:
		return _crew_role_result(false, &"healthy_component")
	var selection := _select_engineer_component(intent, component_id, component_generation)
	if requested_repair <= 0.0:
		return selection
	var rate := maxf(float(report.get("repair_rate_per_second", 0.0)), 0.05)
	var repair_result := model.tick_repair(requested_repair / rate, true)
	var after := model.get_component_integrity(component_id)
	if not bool(repair_result.get("accepted", false)) or after <= before:
		var rejected := _crew_role_result(
			false,
			StringName(repair_result.get("reason", &"system_not_repaired"))
		)
		rejected["repair"] = repair_result
		rejected["selection"] = selection
		return rejected
	var result := _crew_role_result(true, &"repair_applied")
	result["component_id"] = component_id
	result["integrity_before"] = before
	result["integrity_after"] = after
	result["repair"] = repair_result
	result["selection"] = selection
	return result


func _select_engineer_component(
		intent: Dictionary,
		component_id: StringName,
		component_generation: int
) -> Dictionary:
	_engineer_component_selection = {
		"component_id": component_id,
		"component_generation": component_generation,
		"occupant_peer_id": int(intent.get("occupant_peer_id", 0)),
		"avatar_id": StringName(intent.get("avatar_id", &"")),
		"seat_generation": int(intent.get("seat_generation", 0)),
		"request_sequence": int(intent.get("request_sequence", -1)),
	}.duplicate(true)
	var result := _crew_role_result(true, &"component_selected")
	result["selection"] = _engineer_component_selection.duplicate(true)
	return result


func _clear_engineer_component_state(
		occupant_peer_id: int,
		avatar_id: StringName,
		reason: StringName
) -> void:
	if _engineer_component_selection.is_empty():
		return
	if int(_engineer_component_selection.get("occupant_peer_id", 0)) != occupant_peer_id \
			or StringName(_engineer_component_selection.get("avatar_id", &"")) != avatar_id:
		return
	_clear_engineer_component_selection(reason)


func _clear_engineer_component_selection(reason: StringName, advance_generation: bool = true) -> void:
	_engineer_component_selection.clear()
	if advance_generation:
		_engineer_component_generation = mini(_engineer_component_generation + 1, MAX_GUNNER_TARGET_GENERATION)


func _select_gunner_target(
		intent: Dictionary,
		target_id: StringName,
		target_generation: int
) -> Dictionary:
	var actor_key := _gunner_role_actor_key(intent)
	var prior := _gunner_target_selection
	if not prior.is_empty() and (
		StringName(prior.get("target_id", &"")) != target_id
		or int(prior.get("target_generation", 0)) != target_generation
	):
		_cancel_gunner_charge(actor_key, &"target_changed")
	var selection := {
		"target_id": target_id,
		"target_generation": target_generation,
		"occupant_peer_id": int(intent.get("occupant_peer_id", 0)),
		"avatar_id": StringName(intent.get("avatar_id", &"")),
		"seat_generation": int(intent.get("seat_generation", 0)),
		"request_sequence": int(intent.get("request_sequence", -1)),
	}
	_gunner_target_selection = selection
	gunner_target_selected.emit(target_id, target_generation, selection.duplicate(true))
	var result := _crew_role_result(true, &"target_selected")
	result["selection"] = selection.duplicate(true)
	return result


func _cleanup_detached_gunner_state() -> void:
	if _gunner_target_selection.is_empty() and _gunner_role_charges.is_empty():
		return
	if _crew_role_authority == null:
		_clear_all_gunner_charges(&"authority_detached")
		_clear_gunner_target_selection(&"authority_detached")
		_gunner_role_cooldowns.clear()
		return
	var assignment := _crew_role_authority.get_assignment(
		int(_gunner_target_selection.get("occupant_peer_id", 0)),
		StringName(_gunner_target_selection.get("avatar_id", &""))
	)
	if assignment.is_empty():
		_clear_gunner_role_state(
			int(_gunner_target_selection.get("occupant_peer_id", 0)),
			StringName(_gunner_target_selection.get("avatar_id", &"")),
			&"role_detached"
		)


func _clear_gunner_role_state(
		occupant_peer_id: int,
		avatar_id: StringName,
		reason: StringName
) -> void:
	_gunner_role_cooldowns.erase(_gunner_role_actor_key_from_values(occupant_peer_id, avatar_id))
	_gunner_role_ammunition.erase(_gunner_role_actor_key_from_values(occupant_peer_id, avatar_id))
	_cancel_gunner_charge(
		_gunner_role_actor_key_from_values(occupant_peer_id, avatar_id), reason
	)
	if not _gunner_target_selection.is_empty() \
			and int(_gunner_target_selection.get("occupant_peer_id", 0)) == occupant_peer_id \
			and StringName(_gunner_target_selection.get("avatar_id", &"")) == avatar_id:
		_clear_gunner_target_selection(reason)


func _clear_gunner_target_selection(reason: StringName, advance_generation: bool = true) -> void:
	if _gunner_target_selection.is_empty():
		if advance_generation:
			_gunner_target_generation = mini(
				_gunner_target_generation + 1,
				MAX_GUNNER_TARGET_GENERATION
			)
		return
	var target_id := StringName(_gunner_target_selection.get("target_id", &""))
	var target_generation := int(_gunner_target_selection.get("target_generation", 0))
	_gunner_target_selection.clear()
	gunner_target_cleared.emit(target_id, target_generation, reason)
	if advance_generation:
		_gunner_target_generation = mini(
			_gunner_target_generation + 1,
			MAX_GUNNER_TARGET_GENERATION
		)


func _advance_gunner_role_cooldowns(delta: float) -> void:
	var expired: Array[StringName] = []
	for key_variant in _gunner_role_cooldowns.keys():
		var key := StringName(key_variant)
		var remaining := maxf(0.0, float(_gunner_role_cooldowns[key]) - delta)
		if remaining <= 0.0:
			expired.append(key)
		else:
			_gunner_role_cooldowns[key] = remaining
	for key in expired:
		_gunner_role_cooldowns.erase(key)


func _start_gunner_charge(
		intent: Dictionary,
		target_id: StringName,
		target_generation: int,
		charge_time: float
) -> void:
	var actor_key := _gunner_role_actor_key(intent)
	_gunner_role_charges[actor_key] = {
		"elapsed": 0.0,
		"charge_time": maxf(charge_time, GUNNER_SIEGE_CHARGE_TIME),
		"target_id": target_id,
		"target_generation": target_generation,
		"seat_generation": int(intent.get("seat_generation", 0)),
		"occupant_peer_id": int(intent.get("occupant_peer_id", 0)),
		"avatar_id": StringName(intent.get("avatar_id", &"")),
		"request_sequence": int(intent.get("request_sequence", -1)),
	}.duplicate(true)
	gunner_charge_changed.emit(actor_key, target_generation, 0.0, &"charge_started")


func _gunner_charge_result(
		actor_key: StringName,
		status: StringName,
		selection: Dictionary
) -> Dictionary:
	var charge := _gunner_role_charges.get(actor_key, {}) as Dictionary
	var progress := clampf(
		float(charge.get("elapsed", 0.0)) / maxf(float(charge.get("charge_time", GUNNER_SIEGE_CHARGE_TIME)), 0.001),
		0.0,
		1.0
	)
	var result := _crew_role_result(true, status)
	result["selection"] = selection.get("selection", selection).duplicate(true)
	result["charge_progress"] = progress
	result["charge_remaining"] = maxf(
		float(charge.get("charge_time", GUNNER_SIEGE_CHARGE_TIME)) - float(charge.get("elapsed", 0.0)),
		0.0
	)
	return result


func _is_gunner_charge_authorized(intent: Dictionary, charge: Dictionary) -> bool:
	if charge.is_empty() or _crew_role_authority == null:
		return false
	if int(charge.get("target_generation", 0)) != _gunner_target_generation:
		return false
	if StringName(charge.get("target_id", &"")) != StringName(
			_gunner_target_selection.get("target_id", &"")
	):
		return false
	var assignment := _crew_role_authority.get_assignment(
		int(intent.get("occupant_peer_id", 0)),
		StringName(intent.get("avatar_id", &""))
	)
	return (
		not assignment.is_empty()
		and int(assignment.get("seat_generation", 0)) == int(charge.get("seat_generation", 0))
		and StringName(assignment.get("seat_id", &"")) == GUNNER_SEAT_ID
		and StringName(assignment.get("role", &"")) == CrewRoleGameplayProfileType.ROLE_GUNNER
	)


func _advance_gunner_role_charges(delta: float) -> void:
	for key_variant in _gunner_role_charges.keys().duplicate():
		var key := StringName(key_variant)
		var charge := _gunner_role_charges.get(key, {}) as Dictionary
		var intent := {
			"occupant_peer_id": int(charge.get("occupant_peer_id", 0)),
			"avatar_id": StringName(charge.get("avatar_id", &"")),
		}
		if not _is_gunner_charge_authorized(intent, charge):
			_cancel_gunner_charge(key, &"charge_authorization_lost")
			continue
		var component_state := _get_gunner_component_operational_state()
		if not bool(component_state.get("available", false)):
			_cancel_gunner_charge(
				key,
				StringName(component_state.get("reason", &"component_damage_unavailable"))
			)
			continue
		charge["charge_time"] = maxf(
			float(component_state.get("charge_time", GUNNER_SIEGE_CHARGE_TIME)),
			GUNNER_SIEGE_CHARGE_TIME
		)
		charge["elapsed"] = minf(
			float(charge.get("charge_time", GUNNER_SIEGE_CHARGE_TIME)),
			float(charge.get("elapsed", 0.0)) + delta
		)
		_gunner_role_charges[key] = charge
		gunner_charge_changed.emit(
			key,
			int(charge.get("target_generation", 0)),
		clampf(
			float(charge.get("elapsed", 0.0))
				/ maxf(float(charge.get("charge_time", GUNNER_SIEGE_CHARGE_TIME)), 0.001),
			0.0,
			1.0
		),
			&"charge_progress"
		)


func _cancel_gunner_charge(actor_key: StringName, reason: StringName) -> void:
	if not _gunner_role_charges.has(actor_key):
		return
	var charge := _gunner_role_charges.get(actor_key, {}) as Dictionary
	_gunner_role_charges.erase(actor_key)
	gunner_charge_changed.emit(
		actor_key,
		int(charge.get("target_generation", 0)),
		0.0,
		reason
	)


func _clear_all_gunner_charges(reason: StringName) -> void:
	for key_variant in _gunner_role_charges.keys().duplicate():
		_cancel_gunner_charge(StringName(key_variant), reason)


func _gunner_role_actor_key(intent: Dictionary) -> StringName:
	return _gunner_role_actor_key_from_values(
		int(intent.get("occupant_peer_id", 0)),
		StringName(intent.get("avatar_id", &""))
	)


static func _gunner_role_actor_key_from_values(
		occupant_peer_id: int,
		avatar_id: StringName
) -> StringName:
	return StringName("%d:%s" % [occupant_peer_id, avatar_id])


static func _crew_role_result(accepted: bool, status: StringName) -> Dictionary:
	return {"accepted": accepted, "status": status}


func get_berth_clearance_report() -> Dictionary:
	return {
		"schema_version": 1,
		"home_berth_id": get_home_berth_id(),
		"parked_render_bounds": AABB(Vector3(-5.8, -0.9, -6.0), Vector3(11.6, 5.0, 12.0)),
		"flight_collision_bounds": AABB(Vector3(-5.8, -0.2, -5.3), Vector3(11.6, 3.1, 10.8)),
		"landing_contact_y": -1.21,
		"dock_role": &"fleet_dock_03",
		"provisional": false,
		"historical_class_to_berth_mapping": false,
		"physical_boarding_contract": true,
		"recovery_contract": &"HeroShip.request_berth_landing",
	}


func get_gunner_station_role_contract() -> Dictionary:
	return {
		"schema_version": SCHEMA_VERSION,
		"role": &"gunner",
		"seat": _gunner_station_anchor,
		"seat_type": &"physical",
		"authority_owner": &"LiveCombatAuthority.resolve_hitscan",
		"visual_only_weapon_fit": false,
		"historical_claim": false,
	}


func get_bulwark_evidence_report() -> Dictionary:
	var definition := get_ship_definition()
	return {
		"schema_version": SCHEMA_VERSION,
		"evidence_status": EVIDENCE_STATUS,
		"evidence_status_enum": EVIDENCE_STATUS_ENUM,
		"evidence_scope": EVIDENCE_SCOPE,
		"authenticated_geometry": false,
		"historical_claim": false,
		"creator_supported": PackedStringArray(),
		"modern_original": PackedStringArray([
			"armored slab, broad shoulder plates, chin armor, and all dimensions",
			"Bulwark name, heavy-gunship role, gunner station, materials, and colours",
			"boarding volume, cockpit placement, collision envelope, and handling",
		]),
		"content_note": DESIGN_NOTE,
		"ship_definition": definition.get_audit_report() if definition != null else {},
	}


func get_bulwark_audit_report() -> Dictionary:
	var errors := PackedStringArray()
	var definition := get_ship_definition()
	if definition == null or not definition.is_definition_valid():
		errors.append("valid new ShipDefinition is missing")
	elif definition.get_evidence_status_id() != &"new":
		errors.append("Bulwark definition must remain new")
	if not is_instance_valid(_bulwark_visual):
		errors.append("Bulwark visual root is missing")
	if get_pilot_seat_anchor() == null:
		errors.append("physical pilot seat anchor is missing")
	var boarding_marker := get_node_or_null("BoardingPoint") as Marker3D
	if boarding_marker == null or not boarding_marker.position.is_finite():
		errors.append("physical boarding marker is missing")
	if not is_instance_valid(_boarding_area):
		errors.append("physical boarding interaction area is missing")
	if not is_instance_valid(_gunner_station_anchor):
		errors.append("physical gunner station anchor is missing")
	var collision_count := 0
	for collision_node in find_children("*", "CollisionShape3D", true, false):
		if collision_node is CollisionShape3D and (collision_node as CollisionShape3D).shape != null:
			collision_count += 1
	if collision_count < 3:
		errors.append("armored hull collision envelope is incomplete")
	return {
		"schema_version": SCHEMA_VERSION,
		"valid": errors.is_empty(),
		"errors": errors,
		"ship_id": get_ship_id(),
		"role": get_role(),
		"evidence": get_bulwark_evidence_report(),
		"silhouette_role": &"armored_broad_shoulders",
		"color_role": &"slate_blue_amber",
		"pilot_seat_present": get_pilot_seat_anchor() != null,
		"boarding_marker_present": boarding_marker != null,
		"boarding_area_present": is_instance_valid(_boarding_area),
		"gunner_station_present": is_instance_valid(_gunner_station_anchor),
		"collision_shape_count": collision_count,
		"combat_authority": &"HeroShip",
		"lifecycle_authority": &"HeroShip",
		"uses_base_reuse_lifecycle": true,
		"world_or_berth_registered": false,
	}


func _apply_bulwark_metadata() -> void:
	set_meta("bulwark_heavy_gunship", true)
	set_meta("evidence_status", EVIDENCE_STATUS)
	set_meta("evidence_scope", EVIDENCE_SCOPE)
	set_meta("authenticated_historical_silhouette", false)
	set_meta("historical_claim", false)
	set_meta("role_contract", &"gunner_station")
	set_meta("combat_authority", &"HeroShip")
	set_meta("lifecycle_authority", &"HeroShip")
	set_meta("content_note", DESIGN_NOTE)
