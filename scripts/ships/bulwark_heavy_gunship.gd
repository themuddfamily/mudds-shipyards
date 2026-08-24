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
const RepairAuthorityType := preload("res://scripts/combat/repair_authority.gd")
const LiveCombatAuthorityType := preload("res://scripts/combat/live_combat_authority.gd")
const WeaponDefinitionType := preload("res://scripts/combat/weapon_definition.gd")
const WeaponDefinitionResolverProfileType := preload("res://scripts/combat/weapon_definition_resolver_profile.gd")
const SiegeLanceDefinition := preload("res://assets/weapons/picket_siege_lance.tres")
const SiegeLanceAudioBindingType := preload("res://scripts/audio/siege_lance_audio_binding.gd")
const ShipComponentDamageType := preload("res://scripts/combat/ship_component_damage.gd")

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
const IDENTITY_AMBER_EMISSION_ENERGY := 0.7
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
const ENGINEER_REPAIR_DURATION_SECONDS := 0.4
const ENGINEER_REPAIR_COOLDOWN_SECONDS := 0.75
const ENGINEER_REPAIR_RESOURCE_ID: StringName = &"bulwark_repair_tool"
const GUNNER_FEEDBACK_NO_TARGET: StringName = &"no_target"
const GUNNER_FEEDBACK_READY: StringName = &"ready"
const GUNNER_FEEDBACK_CHARGING: StringName = &"charging"
const GUNNER_FEEDBACK_COOLDOWN: StringName = &"cooldown"
const GUNNER_FEEDBACK_DENIED: StringName = &"denied"

const HULL_COLLISION_SIZE := Vector3(6.9, 3.1, 10.8)
const SHOULDER_COLLISION_SIZE := Vector3(11.6, 2.1, 5.8)
const CHIN_COLLISION_SIZE := Vector3(4.8, 1.1, 4.0)
const GUNNER_STATION_LOCAL_POSITION := Vector3(2.35, 1.55, 0.55)
const ARMORED_SHOULDER_SIZE := Vector3(3.4, 1.9, 5.3)
const ARMORED_SHOULDER_COPY_COUNT := 2
const IDENTITY_BAND_SIZE := Vector3(0.16, 1.25, 3.2)
const IDENTITY_BAND_COPY_COUNT := 2
## Raised paired bastions turn the broad shoulder slab into a stepped armored
## outline in the normal chase view. They stay inside the existing shoulder
## footprint in X/Z and carry no collision, weapon, light, or component seam.
const DORSAL_BASTION_SIZE := Vector3(1.45, 1.5, 3.4)
const DORSAL_BASTION_COPY_COUNT := 2
const DORSAL_BASTION_CROWN_SIZE := Vector3(1.08, 0.12, 2.55)
const DORSAL_BASTION_CROWN_COPY_COUNT := 2
const COCKPIT_CONSOLE_KEY_COPY_COUNT := 6
const NAVIGATION_LAMP_RADIUS := 0.11
const NAVIGATION_LAMP_COPY_COUNT := 2
const ENGINE_HOUSING_RADIUS := 0.72
const ENGINE_HOUSING_HEIGHT := 2.8
const ENGINE_HOUSING_COPY_COUNT := 2
const GUN_POD_HOUSING_RADIUS := 0.42
const GUN_POD_HOUSING_HEIGHT := 2.15
const GUN_POD_HOUSING_COPY_COUNT := 2
## A retained, static consequence of the existing starboard-wing component
## ledger. The breach sits on the upper aft weapon shoulder: it breaks the
## outboard silhouette in the normal chase view without entering either forward
## muzzle lane, the central cockpit/gunner sightline, or the port boarding lane.
const DAMAGE_CUE_COMPONENT_ID: StringName = &"starboard_wing"
const DAMAGE_CUE_POSITION := Vector3(4.15, 2.0, 2.75)
const DAMAGE_SCORCH_SIZE := Vector3(1.85, 0.06, 1.55)
const DAMAGE_SCORCH_POSITION := Vector3(0.0, 0.03, 0.0)
const DAMAGE_VANE_SIZE := Vector3(0.24, 1.1, 1.25)
const DAMAGE_VANE_POSITION := Vector3(0.0, 0.55, 0.05)
const DAMAGE_VANE_ROTATION := Vector3(0.0, deg_to_rad(-8.0), deg_to_rad(-12.0))
const DAMAGE_SCORCH_COLOR := Color("15191f")
const DAMAGE_VANE_COLOR := Color("ff6945")

static var _shared_damage_scorch_mesh: BoxMesh
static var _shared_damage_scorch_material: StandardMaterial3D
static var _shared_damage_vane_mesh: BoxMesh
static var _shared_damage_vane_material: StandardMaterial3D

var _bulwark_built := false
var _bulwark_visual: Node3D
var _gunner_station: Node3D
var _gunner_station_anchor: Marker3D
var _gunner_status_readout: Label3D
var _gunner_station_feedback: Dictionary = {}
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
var _engineer_repair_authority: RepairAuthority
var _engineer_repair_actor_id: StringName = &""
var _engineer_repair_elapsed := 0.0
var _engineer_repair_state: Dictionary = {
	"status": &"idle",
	"reason": &"",
	"component_id": &"",
	"component_generation": 0,
	"progress": 0.0,
}
var _engineer_status_readout: Label3D
var _siege_lance_audio_sequence := 0
var _siege_lance_audio_binding: RefCounted
var _component_damage_cue: Node3D

signal gunner_target_selected(target_id: StringName, target_generation: int, receipt: Dictionary)
signal gunner_target_cleared(target_id: StringName, target_generation: int, reason: StringName)
signal gunner_charge_changed(actor_key: StringName, target_generation: int, progress: float, reason: StringName)
signal siege_lance_audio_record(record: Dictionary)
signal engineer_repair_state_changed(snapshot: Dictionary)


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
	if _bulwark_built:
		_bulwark_built = _reconfigure_component_damage_from_final_root_collision()
	if not component_damage_changed.is_connected(_on_bulwark_component_damage_changed):
		component_damage_changed.connect(_on_bulwark_component_damage_changed)
	_sync_component_damage_cue()
	_apply_bulwark_metadata()
	_bind_siege_lance_audio()

func _exit_tree() -> void:
	_interrupt_engineer_repair(&"ship_detached")
	_unbind_siege_lance_audio()
	super._exit_tree()


func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	if _reset_for_reuse_mutation_blocked():
		return
	_advance_gunner_role_cooldowns(maxf(delta, 0.0))
	_advance_gunner_role_charges(maxf(delta, 0.0))
	_advance_engineer_repair(maxf(delta, 0.0))
	_cleanup_detached_gunner_state()
	_cleanup_detached_engineer_state()
	_update_gunner_station_feedback()


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
	_reset_engineer_repair_state()
	_sync_component_damage_cue()
	_update_gunner_station_feedback()

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
	_update_gunner_station_feedback()


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
	_share_cockpit_console_key_meshes(cockpit)

	var armor_dark := _material(ARMOR_DARK, 0.78, 0.32)
	var armor_blue := _material(ARMOR_BLUE, 0.72, 0.28)
	var armor_highlight := _material(ARMOR_HIGHLIGHT, 0.66, 0.25)
	# Keep the existing amber bands and starboard navigation marker legible in
	# shadow without adding lights or changing any physical/authority node.
	var amber := _material(
		IDENTITY_AMBER,
		0.52,
		0.31,
		IDENTITY_AMBER,
		IDENTITY_AMBER_EMISSION_ENERGY
	)
	var cyan := _material(GUNNER_CYAN, 0.25, 0.2, GUNNER_CYAN, 1.8)
	var boarding := _material(BOARDING_LIGHT, 0.18, 0.22, BOARDING_LIGHT, 1.2)

	# Armored slab, raised shoulders, chin keel, and rear engine housings form a
	# broad, compact silhouette with a visible centerline armor spine.
	_box(_bulwark_visual, "ArmoredCentralSlab", Vector3(0.0, 1.35, 0.25), Vector3(6.4, 2.7, 8.5), armor_blue)
	_wedge(_bulwark_visual, "ArmoredNose", Vector3(0.0, 1.5, -4.65), Vector3(5.8, 2.8, 3.9), armor_highlight, 0.0)
	_box(_bulwark_visual, "CenterlineArmorSpine", Vector3(0.0, 2.95, 0.45), Vector3(1.35, 0.38, 8.4), armor_highlight)
	_box(_bulwark_visual, "ChinArmor", Vector3(0.0, 0.02, -2.2), CHIN_COLLISION_SIZE, armor_dark)
	var armored_shoulder_transforms: Array[Transform3D] = []
	var armored_shoulder_names := PackedStringArray()
	var identity_band_transforms: Array[Transform3D] = []
	var identity_band_names := PackedStringArray()
	var dorsal_bastion_transforms: Array[Transform3D] = []
	var dorsal_bastion_names := PackedStringArray()
	var dorsal_bastion_crown_transforms: Array[Transform3D] = []
	var dorsal_bastion_crown_names := PackedStringArray()
	var engine_housing_transforms: Array[Transform3D] = []
	var engine_housing_names := PackedStringArray()
	var gun_pod_housing_transforms: Array[Transform3D] = []
	var gun_pod_housing_names := PackedStringArray()
	for side in [-1.0, 1.0]:
		var side_name := "Port" if side < 0.0 else "Starboard"
		armored_shoulder_transforms.append(
			Transform3D(Basis.IDENTITY, Vector3(side * 4.15, 1.05, 0.55))
		)
		armored_shoulder_names.append(side_name + "ArmoredShoulder")
		identity_band_transforms.append(
			Transform3D(Basis.IDENTITY, Vector3(side * 4.18, 1.55, -0.2))
		)
		identity_band_names.append(side_name + "IdentityBand")
		# The slight mirrored roll creates an inward-braced stepped outline while
		# preserving the shoulder's existing lateral and longitudinal envelope.
		dorsal_bastion_transforms.append(Transform3D(
			Basis.from_euler(Vector3(0.0, 0.0, side * deg_to_rad(-7.0))),
			Vector3(side * 4.05, 2.72, 0.72)
		))
		dorsal_bastion_names.append(side_name + "DorsalBastion")
		dorsal_bastion_crown_transforms.append(Transform3D(
			Basis.from_euler(Vector3(0.0, 0.0, side * deg_to_rad(-7.0))),
			Vector3(side * 3.96, 3.48, 0.72)
		))
		dorsal_bastion_crown_names.append(side_name + "DorsalBastionCrown")
		gun_pod_housing_transforms.append(Transform3D(
			Basis.from_euler(Vector3(0.0, deg_to_rad(90.0), 0.0)),
			Vector3(side * 3.25, 1.0, -3.1)
		))
		gun_pod_housing_names.append(side_name + "GunPodHousing")
		engine_housing_transforms.append(Transform3D(
			Basis.from_euler(Vector3(deg_to_rad(90.0), 0.0, 0.0)),
			Vector3(side * 2.65, 1.15, 4.25)
		))
		engine_housing_names.append(side_name + "EngineHousing")
	_add_navigation_lamps(_bulwark_visual, boarding, amber)
	_add_armored_shoulder_batch(
		_bulwark_visual,
		armored_shoulder_transforms,
		armored_shoulder_names,
		armor_dark
	)
	_add_identity_band_batch(
		_bulwark_visual,
		identity_band_transforms,
		identity_band_names,
		amber
	)
	_add_dorsal_silhouette_batch(
		_bulwark_visual,
		"DorsalBastionBatch",
		dorsal_bastion_transforms,
		dorsal_bastion_names,
		DORSAL_BASTION_SIZE,
		DORSAL_BASTION_COPY_COUNT,
		armor_blue,
		&"heavy_gunship_dorsal_bastions"
	)
	_add_dorsal_silhouette_batch(
		_bulwark_visual,
		"DorsalBastionCrownBatch",
		dorsal_bastion_crown_transforms,
		dorsal_bastion_crown_names,
		DORSAL_BASTION_CROWN_SIZE,
		DORSAL_BASTION_CROWN_COPY_COUNT,
		amber,
		&"heavy_gunship_orientation_crowns"
	)
	_add_engine_housing_batch(
		_bulwark_visual,
		engine_housing_transforms,
		engine_housing_names,
		armor_dark
	)
	_add_gun_pod_housing_batch(
		_bulwark_visual,
		gun_pod_housing_transforms,
		gun_pod_housing_names,
		armor_highlight
	)
	_build_component_damage_cue(_bulwark_visual)

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
	_engineer_status_readout = Label3D.new()
	_engineer_status_readout.name = "EngineerRepairReadout"
	_engineer_status_readout.position = Vector3(0.0, 0.76, -1.06)
	_engineer_status_readout.rotation = Vector3(deg_to_rad(-14.0), PI, 0.0)
	_engineer_status_readout.font_size = 24
	_engineer_status_readout.pixel_size = 0.0008
	_engineer_status_readout.modulate = Color("d7ffff")
	_engineer_status_readout.outline_modulate = Color("07111d")
	_engineer_status_readout.outline_size = 6
	_engineer_status_readout.no_depth_test = true
	_engineer_status_readout.set_meta("presentation_only", true)
	_gunner_station.add_child(_engineer_status_readout)
	_refresh_engineer_status_readout()
	_gunner_status_readout = Label3D.new()
	_gunner_status_readout.name = "GunnerStatusReadout"
	_gunner_status_readout.position = Vector3(0.0, 0.76, -0.985)
	_gunner_status_readout.rotation = Vector3(deg_to_rad(-14.0), 0.0, 0.0)
	_gunner_status_readout.font_size = 28
	_gunner_status_readout.pixel_size = 0.0018
	_gunner_status_readout.outline_size = 5
	_gunner_status_readout.outline_modulate = Color("08121c")
	_gunner_status_readout.text = "— NO TARGET —"
	_gunner_station.add_child(_gunner_status_readout)
	_gunner_station_anchor = Marker3D.new()
	_gunner_station_anchor.name = "GunnerStationAnchor"
	_gunner_station_anchor.position = Vector3(0.0, 0.4, 0.0)
	_gunner_station_anchor.set_meta("crew_role", &"gunner")
	_gunner_station_anchor.set_meta("seat_type", &"physical")
	_gunner_station.add_child(_gunner_station_anchor)
	_update_gunner_station_feedback()

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


## Builds exactly two steady renderer surfaces. They have no process callback,
## timer, light, particles, collision, interaction, health, damage, or repair
## seam; visibility only mirrors the already-authoritative component stage.
func _build_component_damage_cue(visual: Node3D) -> void:
	_component_damage_cue = Node3D.new()
	_component_damage_cue.name = "StarboardWeaponShoulderDamageCue"
	_component_damage_cue.position = DAMAGE_CUE_POSITION
	_component_damage_cue.process_mode = Node.PROCESS_MODE_DISABLED
	_component_damage_cue.set_meta(&"presentation_only", true)
	_component_damage_cue.set_meta(&"component_id", DAMAGE_CUE_COMPONENT_ID)
	_component_damage_cue.set_meta(&"damage_authority", false)
	_component_damage_cue.set_meta(&"repair_authority", false)
	_component_damage_cue.set_meta(&"animated", false)
	visual.add_child(_component_damage_cue)

	if _shared_damage_scorch_mesh == null:
		_shared_damage_scorch_mesh = BoxMesh.new()
		_shared_damage_scorch_mesh.size = DAMAGE_SCORCH_SIZE
		_shared_damage_scorch_mesh.resource_local_to_scene = false
	if _shared_damage_scorch_material == null:
		_shared_damage_scorch_material = _material(DAMAGE_SCORCH_COLOR, 0.08, 0.94)
		_shared_damage_scorch_material.resource_local_to_scene = false
	var scorch := MeshInstance3D.new()
	scorch.name = "ShoulderBreachScorch"
	scorch.mesh = _shared_damage_scorch_mesh
	scorch.material_override = _shared_damage_scorch_material
	scorch.position = DAMAGE_SCORCH_POSITION
	_component_damage_cue.add_child(scorch)

	if _shared_damage_vane_mesh == null:
		_shared_damage_vane_mesh = BoxMesh.new()
		_shared_damage_vane_mesh.size = DAMAGE_VANE_SIZE
		_shared_damage_vane_mesh.resource_local_to_scene = false
	if _shared_damage_vane_material == null:
		_shared_damage_vane_material = _material(
			DAMAGE_VANE_COLOR, 0.14, 0.4, DAMAGE_VANE_COLOR, 1.45
		)
		_shared_damage_vane_material.resource_local_to_scene = false
	var vane := MeshInstance3D.new()
	vane.name = "RaisedBreachVane"
	vane.mesh = _shared_damage_vane_mesh
	vane.material_override = _shared_damage_vane_material
	vane.position = DAMAGE_VANE_POSITION
	vane.rotation = DAMAGE_VANE_ROTATION
	_component_damage_cue.add_child(vane)
	_component_damage_cue.visible = false


func _on_bulwark_component_damage_changed(
		component_id: StringName,
		_state: int,
		_integrity: float
	) -> void:
	if component_id == DAMAGE_CUE_COMPONENT_ID:
		_sync_component_damage_cue()


func _sync_component_damage_cue() -> void:
	if not is_instance_valid(_component_damage_cue):
		return
	var model := get_component_damage()
	_component_damage_cue.visible = model != null \
		and model.is_configured() \
		and model.get_component_state(DAMAGE_CUE_COMPONENT_ID) \
			!= ShipComponentDamageType.ComponentState.NOMINAL


## Detached presentation snapshot for focused tests and diagnostics. This is
## deliberately read-only and cannot mutate either the component ledger or the
## inherited whole-craft recovery transaction.
func get_component_damage_cue_snapshot() -> Dictionary:
	var cue := _component_damage_cue
	var scorch := cue.get_node_or_null(^"ShoulderBreachScorch") as MeshInstance3D \
		if is_instance_valid(cue) else null
	var vane := cue.get_node_or_null(^"RaisedBreachVane") as MeshInstance3D \
		if is_instance_valid(cue) else null
	var bounds := AABB()
	var has_bounds := false
	for renderer in [scorch, vane]:
		if renderer == null or renderer.mesh == null or cue == null:
			continue
		var renderer_bounds: AABB = cue.transform * renderer.transform * renderer.mesh.get_aabb()
		bounds = renderer_bounds if not has_bounds else bounds.merge(renderer_bounds)
		has_bounds = true
	var model := get_component_damage()
	return {
		"component_id": DAMAGE_CUE_COMPONENT_ID,
		"stage": ShipComponentDamageType.state_id_for(
			model.get_component_state(DAMAGE_CUE_COMPONENT_ID)
		) if model != null and model.is_configured() else &"unavailable",
		"visible": cue.visible if is_instance_valid(cue) else false,
		"local_bounds": bounds,
		"renderer_nodes": int(scorch != null) + int(vane != null),
		"processes": false,
		"flashes": false,
		"damage_authority": false,
		"repair_authority": false,
	}.duplicate(true)


## The six console keys are immutable cockpit dressing with identical rounded-box
## geometry. Retain their individual named MeshInstance3D nodes, exact transforms,
## two authored finishes, and six submissions while sharing one geometry resource.
func _share_cockpit_console_key_meshes(cockpit: Node3D) -> void:
	if cockpit == null:
		return
	var key_names := PackedStringArray([
		"PortConsoleKey00",
		"PortConsoleKey01",
		"PortConsoleKey02",
		"StarboardConsoleKey00",
		"StarboardConsoleKey01",
		"StarboardConsoleKey02",
	])
	var keys: Array[MeshInstance3D] = []
	var authored_materials: Array[Material] = []
	for key_name in key_names:
		var key := cockpit.get_node_or_null(NodePath(key_name)) as MeshInstance3D
		if key == null or key.mesh == null or key.mesh.get_surface_count() != 1:
			return
		keys.append(key)
		authored_materials.append(key.mesh.surface_get_material(0))
	if keys.size() != COCKPIT_CONSOLE_KEY_COPY_COUNT:
		return
	var shared_mesh := keys[0].mesh
	shared_mesh.surface_set_material(0, null)
	for index in keys.size():
		keys[index].mesh = shared_mesh
		keys[index].material_override = authored_materials[index]


## The port and starboard navigation lamps are immutable visual markers with
## identical sphere geometry and distinct authored finishes. Keep both named
## renderer nodes and submissions while allocating one material-free mesh.
func _add_navigation_lamps(
		parent: Node3D,
		port_material: Material,
		starboard_material: Material
) -> void:
	var shared_mesh := SphereMesh.new()
	shared_mesh.radius = NAVIGATION_LAMP_RADIUS
	shared_mesh.height = NAVIGATION_LAMP_RADIUS * 2.0
	shared_mesh.radial_segments = 24
	shared_mesh.rings = 12
	var materials: Array[Material] = [port_material, starboard_material]
	for index in NAVIGATION_LAMP_COPY_COUNT:
		var side := -1.0 if index == 0 else 1.0
		var lamp := MeshInstance3D.new()
		lamp.name = "PortNavigationLamp" if side < 0.0 else "StarboardNavigationLamp"
		lamp.position = Vector3(side * 4.35, 1.8, -2.5)
		lamp.mesh = shared_mesh
		lamp.material_override = materials[index]
		parent.add_child(lamp)


## The mirrored shoulder shells are childless silhouette presentation with no
## collision or gameplay identity. Their authored inspection names remain on
## the batch while both exact transforms render through one bounded submission.
func _add_armored_shoulder_batch(
		parent: Node3D,
		transforms: Array[Transform3D],
		authored_names: PackedStringArray,
		material: Material
) -> MultiMeshInstance3D:
	var mesh := _rounded_box_mesh(ARMORED_SHOULDER_SIZE, material)
	var multi := MultiMesh.new()
	multi.transform_format = MultiMesh.TRANSFORM_3D
	multi.mesh = mesh
	multi.instance_count = ARMORED_SHOULDER_COPY_COUNT
	multi.visible_instance_count = -1
	var bounds := AABB()
	for index in ARMORED_SHOULDER_COPY_COUNT:
		multi.set_instance_transform(index, transforms[index])
		var instance_bounds := (transforms[index] * mesh.get_aabb()).abs()
		bounds = instance_bounds if index == 0 else bounds.merge(instance_bounds)
	multi.custom_aabb = bounds
	var batch := MultiMeshInstance3D.new()
	batch.name = "ArmoredShoulderBatch"
	batch.multimesh = multi
	batch.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	batch.set_meta(&"presentation_only", true)
	batch.set_meta(&"authored_visual_names", authored_names.duplicate())
	batch.set_meta(&"authored_instance_transforms", transforms.duplicate())
	parent.add_child(batch)
	return batch


## The mirrored amber bands are childless silhouette paint, with no collision,
## damage, weapon, or interaction identity. Preserve their exact rounded mesh,
## material, local transforms, shadow mode, and visible copies in one submission.
func _add_identity_band_batch(
		parent: Node3D,
		transforms: Array[Transform3D],
		authored_names: PackedStringArray,
		material: Material
) -> MultiMeshInstance3D:
	var mesh := _rounded_box_mesh(IDENTITY_BAND_SIZE, material)
	var multi := MultiMesh.new()
	multi.transform_format = MultiMesh.TRANSFORM_3D
	multi.mesh = mesh
	multi.instance_count = IDENTITY_BAND_COPY_COUNT
	multi.visible_instance_count = -1
	var bounds := AABB()
	for index in IDENTITY_BAND_COPY_COUNT:
		multi.set_instance_transform(index, transforms[index])
		var instance_bounds := (transforms[index] * mesh.get_aabb()).abs()
		bounds = instance_bounds if index == 0 else bounds.merge(instance_bounds)
	multi.custom_aabb = bounds
	var batch := MultiMeshInstance3D.new()
	batch.name = "IdentityBandBatch"
	batch.multimesh = multi
	batch.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	batch.set_meta(&"presentation_only", true)
	batch.set_meta(&"authored_visual_names", authored_names.duplicate())
	batch.set_meta(&"authored_instance_transforms", transforms.duplicate())
	parent.add_child(batch)
	return batch


## Two immutable renderer batches supply the Bulwark's stepped upper outline and
## its restrained amber crown read. They are deliberately childless and inert:
## heavy-gunship readability changes, but every gameplay envelope and authority
## remains owned by the pre-existing HeroShip/Bulwark nodes.
func _add_dorsal_silhouette_batch(
		parent: Node3D,
		batch_name: String,
		transforms: Array[Transform3D],
		authored_names: PackedStringArray,
		size: Vector3,
		copy_count: int,
		material: Material,
		silhouette_role: StringName
) -> MultiMeshInstance3D:
	var mesh := _rounded_box_mesh(size, material)
	var multi := MultiMesh.new()
	multi.transform_format = MultiMesh.TRANSFORM_3D
	multi.mesh = mesh
	multi.instance_count = copy_count
	multi.visible_instance_count = -1
	var bounds := AABB()
	for index in copy_count:
		multi.set_instance_transform(index, transforms[index])
		var instance_bounds := (transforms[index] * mesh.get_aabb()).abs()
		bounds = instance_bounds if index == 0 else bounds.merge(instance_bounds)
	multi.custom_aabb = bounds
	var batch := MultiMeshInstance3D.new()
	batch.name = batch_name
	batch.multimesh = multi
	batch.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	batch.set_meta(&"presentation_only", true)
	batch.set_meta(&"gameplay_distance_cue", true)
	batch.set_meta(&"gameplay_authority", false)
	batch.set_meta(&"silhouette_role", silhouette_role)
	batch.set_meta(&"authored_visual_names", authored_names.duplicate())
	batch.set_meta(&"authored_instance_transforms", transforms.duplicate())
	parent.add_child(batch)
	return batch


## The mirrored rear engine housings are immutable exterior dressing: engine
## state remains owned by HeroShip and no component, light, particle, collision,
## or interaction node is attached to either renderer. Preserve their exact
## chamfered cylinders and transforms in one bounded renderer submission.
func _add_engine_housing_batch(
		parent: Node3D,
		transforms: Array[Transform3D],
		authored_names: PackedStringArray,
		material: Material
) -> MultiMeshInstance3D:
	var mesh := StationSurfaceKit.chamfered_cylinder_mesh_cached(
		ENGINE_HOUSING_RADIUS,
		ENGINE_HOUSING_RADIUS,
		ENGINE_HOUSING_HEIGHT,
		32,
		_chamfered_cylinder_cache,
		ShipSurfaceDetail.CYLINDER_WALL_RINGS,
		true,
		true,
		material
	)
	var multi := MultiMesh.new()
	multi.transform_format = MultiMesh.TRANSFORM_3D
	multi.mesh = mesh
	multi.instance_count = ENGINE_HOUSING_COPY_COUNT
	multi.visible_instance_count = -1
	var bounds := AABB()
	for index in ENGINE_HOUSING_COPY_COUNT:
		multi.set_instance_transform(index, transforms[index])
		var instance_bounds := (transforms[index] * mesh.get_aabb()).abs()
		bounds = instance_bounds if index == 0 else bounds.merge(instance_bounds)
	multi.custom_aabb = bounds
	var batch := MultiMeshInstance3D.new()
	batch.name = "EngineHousingBatch"
	batch.multimesh = multi
	batch.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	batch.set_meta(&"presentation_only", true)
	batch.set_meta(&"authored_visual_names", authored_names.duplicate())
	batch.set_meta(&"authored_instance_transforms", transforms.duplicate())
	parent.add_child(batch)
	return batch


## The mirrored gun-pod housings are childless exterior armor with no collision,
## weapon, damage, or interaction ownership. Keep both authored poses and the
## inherited chamfered-cylinder surface in one renderer submission.
func _add_gun_pod_housing_batch(
		parent: Node3D,
		transforms: Array[Transform3D],
		authored_names: PackedStringArray,
		material: Material
) -> MultiMeshInstance3D:
	var mesh := StationSurfaceKit.chamfered_cylinder_mesh_cached(
		GUN_POD_HOUSING_RADIUS,
		GUN_POD_HOUSING_RADIUS,
		GUN_POD_HOUSING_HEIGHT,
		32,
		_chamfered_cylinder_cache,
		ShipSurfaceDetail.CYLINDER_WALL_RINGS,
		true,
		true,
		material
	)
	var multi := MultiMesh.new()
	multi.transform_format = MultiMesh.TRANSFORM_3D
	multi.mesh = mesh
	multi.instance_count = GUN_POD_HOUSING_COPY_COUNT
	multi.visible_instance_count = -1
	var bounds := AABB()
	for index in GUN_POD_HOUSING_COPY_COUNT:
		multi.set_instance_transform(index, transforms[index])
		var instance_bounds := (transforms[index] * mesh.get_aabb()).abs()
		bounds = instance_bounds if index == 0 else bounds.merge(instance_bounds)
	multi.custom_aabb = bounds
	var batch := MultiMeshInstance3D.new()
	batch.name = "GunPodHousingBatch"
	batch.multimesh = multi
	batch.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	batch.set_meta(&"presentation_only", true)
	batch.set_meta(&"authored_visual_names", authored_names.duplicate())
	batch.set_meta(&"authored_instance_transforms", transforms.duplicate())
	parent.add_child(batch)
	return batch


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
	var engineer_repair := get_engineer_repair_state()
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
		"engineer_repair": engineer_repair,
		"engineer_repair_ready": not is_destroyed()
			and bool(get_telemetry().get("landed", false))
			and not bool(get_telemetry().get("landing_active", false))
			and not _engineer_component_selection.is_empty()
			and bool(engineer_repair.get("cooldown_ready", false))
			and not bool(engineer_repair.get("active", false)),
		"gunner_component": _get_gunner_component_operational_state(),
	}.duplicate(true)


## Player-facing projection of the already-authoritative gunner state. This is
## deliberately presentation-only: it never admits an intent or resolves fire.
func get_gunner_station_feedback_snapshot() -> Dictionary:
	_update_gunner_station_feedback()
	return _gunner_station_feedback.duplicate(true)


func _update_gunner_station_feedback() -> void:
	_gunner_station_feedback = _build_gunner_station_feedback()
	if _gunner_status_readout == null or not is_instance_valid(_gunner_status_readout):
		return
	_gunner_status_readout.text = str(_gunner_station_feedback.get("text", "— NO TARGET —"))
	_gunner_status_readout.modulate = _gunner_station_feedback.get("color", GUNNER_CYAN) as Color
	_gunner_status_readout.set_meta(
		"feedback_state", StringName(_gunner_station_feedback.get("state", GUNNER_FEEDBACK_NO_TARGET))
	)
	if _gunner_station != null:
		_gunner_station.set_meta(
			"gunner_feedback_state",
			StringName(_gunner_station_feedback.get("state", GUNNER_FEEDBACK_NO_TARGET))
		)


func _build_gunner_station_feedback() -> Dictionary:
	var feedback := {
		"state": GUNNER_FEEDBACK_NO_TARGET,
		"text": "— NO TARGET —",
		"color": Color("8aa7af"),
		"target_id": StringName(&""),
		"charge_progress": 0.0,
		"cooldown_remaining": 0.0,
		"denial_reason": StringName(&""),
	}
	if is_destroyed():
		feedback.merge({
			"state": GUNNER_FEEDBACK_DENIED,
			"text": "! SHIP DISABLED",
			"color": Color("ff6b5f"),
			"denial_reason": StringName(&"ship_destroyed"),
		}, true)
		return feedback
	if _gunner_target_selection.is_empty():
		return feedback

	var target_id := StringName(_gunner_target_selection.get("target_id", &""))
	var actor_key := _gunner_role_actor_key_from_values(
		int(_gunner_target_selection.get("occupant_peer_id", 0)),
		StringName(_gunner_target_selection.get("avatar_id", &""))
	)
	feedback["target_id"] = target_id
	var component_state := _get_gunner_component_operational_state()
	if not bool(component_state.get("available", false)):
		feedback.merge({
			"state": GUNNER_FEEDBACK_DENIED,
			"text": "! WEAPON OFFLINE",
			"color": Color("ff6b5f"),
			"denial_reason": StringName(
				component_state.get("reason", &"component_damage_unavailable")
			),
		}, true)
		return feedback

	var charge := _gunner_role_charges.get(actor_key, {}) as Dictionary
	if not charge.is_empty():
		var progress := clampf(
			float(charge.get("elapsed", 0.0))
				/ maxf(float(charge.get("charge_time", GUNNER_SIEGE_CHARGE_TIME)), 0.001),
			0.0,
			1.0
		)
		feedback.merge({
			"state": GUNNER_FEEDBACK_CHARGING,
			"text": "△ CHARGING %d%%" % int(roundf(progress * 100.0)),
			"color": Color("ffd166"),
			"charge_progress": progress,
		}, true)
		return feedback

	var cooldown := maxf(float(_gunner_role_cooldowns.get(actor_key, 0.0)), 0.0)
	if cooldown > 0.0:
		feedback.merge({
			"state": GUNNER_FEEDBACK_COOLDOWN,
			"text": "■ COOLDOWN %.1fs" % cooldown,
			"color": Color("ffb44b"),
			"cooldown_remaining": cooldown,
		}, true)
		return feedback

	if int(_gunner_role_ammunition.get(actor_key, 2)) <= 0:
		feedback.merge({
			"state": GUNNER_FEEDBACK_DENIED,
			"text": "! AMMUNITION EMPTY",
			"color": Color("ff6b5f"),
			"denial_reason": StringName(&"ammunition_depleted"),
		}, true)
		return feedback
	if _gunner_combat_authority == null or not is_instance_valid(_gunner_combat_authority):
		feedback.merge({
			"state": GUNNER_FEEDBACK_DENIED,
			"text": "! COMBAT LINK OFFLINE",
			"color": Color("ff6b5f"),
			"denial_reason": StringName(&"combat_authority_unavailable"),
		}, true)
		return feedback

	feedback.merge({
		"state": GUNNER_FEEDBACK_READY,
		"text": "◇ LOCKED // READY",
		"color": GUNNER_CYAN,
	}, true)
	return feedback


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
	if requested_repair <= 0.0:
		return _select_engineer_component(intent, component_id, component_generation)
	var prepared := _prepare_engineer_repair_authority(intent, model)
	if not bool(prepared.get("accepted", false)):
		return prepared
	var repair_request := _engineer_repair_authority.request_repair({
		"actor_id": _engineer_repair_actor_id,
		"target_id": get_ship_id(),
		"component_id": component_id,
		"generation": model.get_ledger_generation(),
		"distance_meters": 0.0,
		"seated": true,
		"resource_id": ENGINEER_REPAIR_RESOURCE_ID,
		"interrupted": false,
		"repair": requested_repair,
	})
	if not bool(repair_request.get("accepted", false)):
		var rejected := _crew_role_result(
			false,
			StringName(repair_request.get("reason", &"repair_not_started"))
		)
		rejected["repair"] = repair_request
		return rejected
	var selection := _select_engineer_component(intent, component_id, component_generation)
	if not bool(selection.get("accepted", false)):
		_engineer_repair_authority.interrupt(&"selection_rejected")
		return selection
	_engineer_repair_elapsed = 0.0
	_set_engineer_repair_state({
		"status": &"repairing",
		"reason": &"",
		"component_id": component_id,
		"component_generation": component_generation,
		"progress": 0.0,
		"token": int(repair_request.get("token", -1)),
		"receipt": repair_request.duplicate(true),
	})
	var result := _crew_role_result(true, &"repair_started")
	result["component_id"] = component_id
	result["integrity_before"] = before
	result["repair"] = repair_request
	result["selection"] = selection
	result["repair_state"] = get_engineer_repair_state()
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


func _prepare_engineer_repair_authority(
	intent: Dictionary,
	model: ShipComponentDamage
) -> Dictionary:
	var actor_id := StringName("peer_%d" % int(intent.get("occupant_peer_id", 0)))
	var ledger_generation := model.get_ledger_generation()
	if _engineer_repair_authority != null \
			and _engineer_repair_actor_id == actor_id \
			and _engineer_repair_authority.get_generation() == ledger_generation:
		return _crew_role_result(true, &"repair_authority_ready")
	if _engineer_repair_authority != null \
			and _engineer_repair_authority.has_active_repair():
		_interrupt_engineer_repair(&"repair_actor_changed")
	_engineer_repair_authority = RepairAuthorityType.new(
		actor_id,
		get_ship_id(),
		ENGINEER_REPAIR_RESOURCE_ID,
		1.0,
		ENGINEER_REPAIR_COOLDOWN_SECONDS,
		1.0,
		RepairAuthority.MAX_RESOURCE_UNITS
	) as RepairAuthority
	_engineer_repair_actor_id = actor_id
	if _engineer_repair_authority == null \
			or not _engineer_repair_authority.is_configuration_valid():
		_reset_engineer_repair_state()
		return _crew_role_result(false, &"repair_authority_unavailable")
	var begun := _engineer_repair_authority.begin_generation(ledger_generation)
	if not bool(begun.get("accepted", false)):
		_reset_engineer_repair_state()
		return _crew_role_result(
			false,
			StringName(begun.get("reason", &"repair_generation_rejected"))
		)
	return _crew_role_result(true, &"repair_authority_ready")


func _advance_engineer_repair(delta: float) -> void:
	if _engineer_repair_authority == null:
		return
	var had_cooldown := _engineer_repair_authority.get_cooldown_remaining() > 0.0
	_engineer_repair_authority.advance(delta)
	if not _engineer_repair_authority.has_active_repair():
		if had_cooldown:
			_refresh_engineer_status_readout()
		return
	var interruption := _engineer_repair_interruption_reason()
	if not interruption.is_empty():
		_interrupt_engineer_repair(interruption)
		return
	_engineer_repair_elapsed = minf(
		_engineer_repair_elapsed + delta,
		ENGINEER_REPAIR_DURATION_SECONDS
	)
	var progress := clampf(
		_engineer_repair_elapsed / ENGINEER_REPAIR_DURATION_SECONDS,
		0.0,
		1.0
	)
	_engineer_repair_state["progress"] = progress
	if progress < 1.0:
		engineer_repair_state_changed.emit(get_engineer_repair_state())
		_refresh_engineer_status_readout()
		return
	var model := get_component_damage()
	var token := int(_engineer_repair_state.get("token", -1))
	var committed := _engineer_repair_authority.commit_component_repair(model, token)
	if not bool(committed.get("accepted", false)):
		var commit_reason := StringName(
			committed.get("reason", &"repair_commit_rejected")
		)
		if commit_reason == &"component_not_damaged":
			_set_engineer_repair_state({
				"status": &"completed",
				"reason": &"berth_repair_completed",
				"component_id": StringName(
					_engineer_repair_state.get("component_id", &"")
				),
				"component_generation": int(
					_engineer_repair_state.get("component_generation", 0)
				),
				"progress": 1.0,
			})
			return
		_set_engineer_repair_state({
			"status": &"interrupted",
			"reason": commit_reason,
			"component_id": StringName(_engineer_repair_state.get("component_id", &"")),
			"component_generation": int(
				_engineer_repair_state.get("component_generation", 0)
			),
			"progress": progress,
		})
		return
	_set_engineer_repair_state({
		"status": &"completed",
		"reason": &"repair_committed",
		"component_id": StringName(_engineer_repair_state.get("component_id", &"")),
		"component_generation": int(_engineer_repair_state.get("component_generation", 0)),
		"progress": 1.0,
		"receipt": committed.duplicate(true),
	})


func _engineer_repair_interruption_reason() -> StringName:
	var telemetry := get_telemetry()
	if bool(telemetry.get("destroyed", false)):
		return &"ship_destroyed"
	if not bool(telemetry.get("landed", false)) \
			or bool(telemetry.get("landing_active", false)):
		return &"left_berth"
	if _engineer_component_selection.is_empty():
		return &"selection_lost"
	if StringName(_engineer_component_selection.get("component_id", &"")) \
			!= StringName(_engineer_repair_state.get("component_id", &"")) \
			or int(_engineer_component_selection.get("component_generation", 0)) \
			!= int(_engineer_repair_state.get("component_generation", 0)):
		return &"selection_changed"
	if _crew_role_authority == null:
		return &"authority_detached"
	var assignment := _crew_role_authority.get_assignment(
		int(_engineer_component_selection.get("occupant_peer_id", 0)),
		StringName(_engineer_component_selection.get("avatar_id", &""))
	)
	if StringName(assignment.get("role", &"")) != CrewRoleGameplayProfileType.ROLE_ENGINEER \
			or StringName(assignment.get("seat_id", &"")) != ENGINEER_SEAT_ID:
		return &"engineer_seat_lost"
	var model := get_component_damage()
	if model == null \
			or model.get_ledger_generation() != _engineer_repair_authority.get_generation():
		return &"component_generation_changed"
	return &""


func _interrupt_engineer_repair(reason: StringName) -> void:
	if _engineer_repair_authority == null \
			or not _engineer_repair_authority.has_active_repair():
		return
	var interruption_receipt := _engineer_repair_authority.interrupt(reason)
	_set_engineer_repair_state({
		"status": &"interrupted",
		"reason": reason,
		"component_id": StringName(_engineer_repair_state.get("component_id", &"")),
		"component_generation": int(_engineer_repair_state.get("component_generation", 0)),
		"progress": float(_engineer_repair_state.get("progress", 0.0)),
		"token": int(_engineer_repair_state.get("token", -1)),
		"receipt": interruption_receipt.duplicate(true),
	})


func _set_engineer_repair_state(state: Dictionary) -> void:
	_engineer_repair_state = state.duplicate(true)
	engineer_repair_state_changed.emit(get_engineer_repair_state())
	_refresh_engineer_status_readout()


func _reset_engineer_repair_state() -> void:
	_engineer_repair_authority = null
	_engineer_repair_actor_id = &""
	_engineer_repair_elapsed = 0.0
	_engineer_repair_state = {
		"status": &"idle",
		"reason": &"",
		"component_id": &"",
		"component_generation": 0,
		"progress": 0.0,
	}
	_refresh_engineer_status_readout()


func get_engineer_repair_state() -> Dictionary:
	var snapshot := _engineer_repair_state.duplicate(true)
	var cooldown := (
		_engineer_repair_authority.get_cooldown_remaining()
		if _engineer_repair_authority != null else 0.0
	)
	snapshot["duration_seconds"] = ENGINEER_REPAIR_DURATION_SECONDS
	snapshot["cooldown_seconds"] = ENGINEER_REPAIR_COOLDOWN_SECONDS
	snapshot["cooldown_remaining"] = cooldown
	snapshot["cooldown_ready"] = cooldown <= 0.0
	snapshot["active"] = _engineer_repair_authority != null \
		and _engineer_repair_authority.has_active_repair()
	return snapshot.duplicate(true)


## Shared, read-only repair-network contract. It projects the current authority
## receipt and selected engineer identity without exposing a repair mutation.
func get_engineer_repair_network_snapshot() -> Dictionary:
	var repair := get_engineer_repair_state()
	var owner: Dictionary = {}
	if not _engineer_component_selection.is_empty() \
			and StringName(_engineer_component_selection.get("component_id", &"")) \
			== StringName(repair.get("component_id", &"")) \
			and int(_engineer_component_selection.get("component_generation", 0)) \
			== int(repair.get("component_generation", 0)):
		owner = {
			"occupant_peer_id": int(_engineer_component_selection.get("occupant_peer_id", 0)),
			"avatar_id": StringName(_engineer_component_selection.get("avatar_id", &"")),
			"seat_id": ENGINEER_SEAT_ID,
			"seat_generation": int(_engineer_component_selection.get("seat_generation", 0)),
		}
	return {
		"repair": repair,
		"owner": owner,
		"presentation_only": true,
	}.duplicate(true)


func get_engineer_status_text() -> String:
	return _engineer_status_readout.text \
		if _engineer_status_readout != null and is_instance_valid(_engineer_status_readout) \
		else ""


func _refresh_engineer_status_readout() -> void:
	if _engineer_status_readout == null or not is_instance_valid(_engineer_status_readout):
		return
	var repair := get_engineer_repair_state()
	var status := StringName(repair.get("status", &"idle"))
	var token := "[READY]"
	if status == &"repairing":
		token = "[WORK %d%%]" % int(round(
			clampf(float(repair.get("progress", 0.0)), 0.0, 1.0) * 100.0
		))
	elif status == &"interrupted":
		token = "[INTERRUPTED]"
	elif float(repair.get("cooldown_remaining", 0.0)) > 0.0:
		token = "[COOLDOWN %.1fs]" % float(repair.get("cooldown_remaining", 0.0))
	_engineer_status_readout.text = "ENGINEER REPAIR\n%s" % token


func _cleanup_detached_engineer_state() -> void:
	if _engineer_component_selection.is_empty():
		return
	if _crew_role_authority == null:
		_clear_engineer_component_selection(&"authority_detached")
		return
	var assignment := _crew_role_authority.get_assignment(
		int(_engineer_component_selection.get("occupant_peer_id", 0)),
		StringName(_engineer_component_selection.get("avatar_id", &""))
	)
	if assignment.is_empty():
		_clear_engineer_component_state(
			int(_engineer_component_selection.get("occupant_peer_id", 0)),
			StringName(_engineer_component_selection.get("avatar_id", &"")),
			&"role_detached"
		)


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
	_interrupt_engineer_repair(reason)
	_engineer_component_selection.clear()
	if advance_generation:
		_engineer_component_generation = mini(_engineer_component_generation + 1, MAX_GUNNER_TARGET_GENERATION)
		_engineer_repair_authority = null
		_engineer_repair_actor_id = &""
		_engineer_repair_elapsed = 0.0


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
