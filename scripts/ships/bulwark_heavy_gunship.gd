class_name BulwarkHeavyGunship
extends HeroShip

## Original-modern heavy gunship component.
##
## This is a new design, not a reconstruction: it has no historical evidence
## references and makes no claim about a recovered silhouette. The common
## HeroShip controller remains the sole owner of flight, pilot weapon requests,
## damage, boarding lifecycle, and reuse; optional gunner fire is admitted by
## the seat authority and resolved by the shared combat authority.

const ShipServiceCassette := preload("res://scripts/ships/ship_service_cassette.gd")
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
const COMBAT_SOURCE_ID := 1107
const EVIDENCE_STATUS: StringName = &"new"
const EVIDENCE_STATUS_ENUM: int = ShipDefinition.EvidenceStatus.NEW
const EVIDENCE_SCOPE: StringName = &"original_modern_design"
const DESIGN_NOTE := (
	"Bulwark is an original modern heavy gunship component. It has no historical "
	+ "evidence references and makes no claim about an authenticated silhouette, "
	+ "name, role, systems, or continuity."
)

# Desaturated gunmetal armor and small amber identification stripes support
# the broad, low gunship silhouette without reading as blue plastic or gold trim.
const ARMOR_DARK := Color("252b30")
const ARMOR_BLUE := Color("414b52")
const ARMOR_HIGHLIGHT := Color("687277")
const IDENTITY_AMBER := Color("957c4f")
const IDENTITY_AMBER_EMISSION_ENERGY := 0.15
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
const ENGINEER_REPAIR_RESOURCE_CAPACITY := 6
const GUNNER_FEEDBACK_NO_TARGET: StringName = &"no_target"
const GUNNER_FEEDBACK_READY: StringName = &"ready"
const GUNNER_FEEDBACK_CHARGING: StringName = &"charging"
const GUNNER_FEEDBACK_COOLDOWN: StringName = &"cooldown"
const GUNNER_FEEDBACK_DENIED: StringName = &"denied"

const HULL_COLLISION_SIZE := Vector3(6.9, 3.1, 10.8)
const SHOULDER_COLLISION_SIZE := Vector3(11.6, 2.1, 5.8)
const CHIN_COLLISION_SIZE := Vector3(4.8, 1.1, 4.0)
## Dock 03's raised slab leaves a narrow but capsule-clear aft-port corner.
## HeroShip's generic (-7.6, -1.0, 0.75) exit projects into the comb's genuine
## negative-space gap. This point sits directly on the y = 6.6 deck when parked,
## with 0.12 m lateral and 0.17 m aft clearance beyond the player's 0.38 m
## capsule; the shared boarding/disembark authority continues to consume it.
const FLEET_DOCK_EXIT_LOCAL_POSITION := Vector3(-5.5, -1.08, 5.7)
const GUNNER_STATION_LOCAL_POSITION := Vector3(2.35, 1.55, 0.55)
const ARMORED_SHOULDER_SIZE := Vector3(3.4, 1.25, 5.3)
const ARMORED_SHOULDER_COPY_COUNT := 2
const IDENTITY_BAND_SIZE := Vector3(0.22, 0.035, 1.8)
const IDENTITY_BAND_COPY_COUNT := 2
## Low paired weapon shoulders reinforce the armored outline without tall
## stacks above the cockpit. They stay inside the existing shoulder
## footprint in X/Z and carry no collision, weapon, light, or component seam.
const DORSAL_BASTION_SIZE := Vector3(1.8, 0.82, 4.15)
const DORSAL_BASTION_COPY_COUNT := 2
const DORSAL_BASTION_CROWN_SIZE := Vector3(0.14, 0.026, 1.9)
const DORSAL_BASTION_CROWN_COPY_COUNT := 2
const COCKPIT_CONSOLE_KEY_COPY_COUNT := 6
const COCKPIT_DISPLAY_BEZEL_PAIR_COUNT := 2
const NAVIGATION_LAMP_RADIUS := 0.11
const NAVIGATION_LAMP_COPY_COUNT := 2
const ENGINE_HOUSING_COPY_COUNT := 2
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
## Failure reuses the retained breach vane in an outboard-canted pose.  The
## shoulder remains untouched: only this presentation-only child moves, making
## the failed weapon shoulder legible by shape even with its emission removed.
const DAMAGE_VANE_FAILED_POSITION := Vector3(1.22, 0.47, 0.34)
const DAMAGE_VANE_FAILED_ROTATION := Vector3(0.0, deg_to_rad(-8.0), deg_to_rad(-50.0))
const DAMAGE_SCORCH_COLOR := Color("15191f")
const DAMAGE_VANE_COLOR := Color("ff6945")

static var _shared_damage_scorch_mesh: BoxMesh
static var _shared_damage_scorch_material: StandardMaterial3D
static var _shared_damage_vane_mesh: BoxMesh
static var _shared_damage_vane_material: StandardMaterial3D
static var _shared_cockpit_console_key_mesh: Mesh

static var _shared_engine_exhaust_mesh: WeakRef

var _bulwark_built := false
var _bulwark_visual: Node3D
var _gunner_station: Node3D
var _gunner_station_anchor: Marker3D
var _gunner_status_readout: Label3D
var _gunner_station_feedback: Dictionary = {}
var _gunner_roster_presentation_state: StringName = &"detached"
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
		rig.profile_id = ShipAudioRig.PROFILE_BULWARK_HEAVY_GUNSHIP


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
	_share_cockpit_display_bezel_meshes(cockpit)

	var armor_dark := _material(ARMOR_DARK, 0.12, 0.62)
	var armor_blue := _material(ARMOR_BLUE, 0.12, 0.62)
	var armor_highlight := _material(ARMOR_HIGHLIGHT, 0.16, 0.58)
	# Structural canopy sills use the hull finish; amber remains on controls.
	if cockpit != null:
		for sill_name in ["PortSill", "StarboardSill"]:
			var sill := cockpit.get_node_or_null(sill_name) as MeshInstance3D
			if sill != null:
				sill.material_override = armor_dark
	for coating in [armor_dark, armor_blue, armor_highlight]:
		ShipSurfaceDetail.bind_manufactured_paint(coating)
		# Metric local projection prevents long armor UVs stretching the wear.
		coating.uv1_triplanar = true
		coating.uv1_world_triplanar = false
		coating.uv1_scale = Vector3.ONE * 0.5
	# Keep the existing amber bands and starboard navigation marker legible in
	# shadow without adding lights or changing any physical/authority node.
	var amber := _material(
		IDENTITY_AMBER,
		0.52,
		0.31,
		IDENTITY_AMBER,
		IDENTITY_AMBER_EMISSION_ENERGY
	)
	var boarding := _material(BOARDING_LIGHT, 0.18, 0.22, BOARDING_LIGHT, 1.2)

	# Continuous load-bearing keel and a descending forebody replace the blunt
	# slab nose. Every upper section remains below the inherited cabin floor.
	_profile_shell(_bulwark_visual, "ArmoredCentralSlab", Vector3(0, 0.82, 0.25), [
		Vector4(-4.25, 2.22, 0.40, -0.10), Vector4(-2.25, 2.75, 0.76, 0),
		Vector4(1.45, 2.75, 0.76, 0), Vector4(2.8, 2.16, 0.61, -0.10),
		Vector4(4.25, 1.50, 0.33, -0.25),
	], armor_blue)
	_profile_shell(_bulwark_visual, "ArmoredNose", Vector3.ZERO, [
		Vector4(-6.25, 1.05, 0.19, 0.48), Vector4(-5.4, 1.95, 0.33, 0.62),
		Vector4(-3.25, 2.82, 0.62, 0.88), Vector4(-2.65, 2.82, 0.65, 0.9),
	], armor_highlight, true)
	_profile_shell(_bulwark_visual, "CenterlineArmorSpine", Vector3.ZERO, [
		Vector4(1.55, 0.47, 0.09, 1.68), Vector4(2.40, 0.60, 0.12, 1.56),
		Vector4(3.70, 0.48, 0.09, 1.19), Vector4(4.45, 0.31, 0.08, 0.94),
	], armor_blue)
	_armor_shell(_bulwark_visual, "ChinArmor", Vector3(0, 0.02, -2.2), Vector3(4.3, 0.86, 4.0), armor_dark)
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
			Transform3D(Basis.IDENTITY, Vector3(side * 4.62, 1.685, 0.6))
		)
		identity_band_names.append(side_name + "IdentityBand")
		# Low continuous caps follow the armored shoulder envelope.
		dorsal_bastion_transforms.append(Transform3D(
			Basis.IDENTITY,
			Vector3(side * 4.05, 1.94, 0.60)
		))
		dorsal_bastion_names.append(side_name + "DorsalBastion")
		dorsal_bastion_crown_transforms.append(Transform3D(
			Basis.IDENTITY,
			Vector3(side * 4.05, 2.368, 0.60)
		))
		dorsal_bastion_crown_names.append(side_name + "DorsalBastionCrown")
		gun_pod_housing_transforms.append(Transform3D(
			Basis.from_euler(Vector3(deg_to_rad(90.0), 0.0, 0.0)),
			Vector3(side * 3.25, 1.0, -3.1)
		))
		gun_pod_housing_names.append(side_name + "GunPodHousing")
		engine_housing_transforms.append(Transform3D(
			Basis.IDENTITY,
			Vector3(side * 2.65, 1.15, 4.05)
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
	_build_bulwark_manufactured_details(_bulwark_visual, armor_blue, armor_dark)
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
	_build_gunner_station_furniture(armor_dark, armor_highlight)
	_engineer_status_readout = Label3D.new()
	_engineer_status_readout.name = "EngineerRepairReadout"
	_engineer_status_readout.position = Vector3(0.0, 0.76, -1.06)
	_engineer_status_readout.rotation = Vector3(deg_to_rad(14.0), PI, 0.0)
	_engineer_status_readout.font_size = 28
	_engineer_status_readout.pixel_size = 0.0011
	_engineer_status_readout.modulate = Color("d7ffff")
	_engineer_status_readout.outline_modulate = Color("07111d")
	_engineer_status_readout.outline_size = 6
	_engineer_status_readout.no_depth_test = false
	_engineer_status_readout.double_sided = false
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
	_gunner_status_readout.double_sided = false
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
	var exit_marker := get_node_or_null("ExitPoint") as Marker3D
	if exit_marker != null:
		exit_marker.position = FLEET_DOCK_EXIT_LOCAL_POSITION
		exit_marker.rotation = Vector3(0.0, -PI * 0.5, 0.0)
	var pilot := get_pilot_seat_anchor()
	if pilot != null:
		pilot.set_meta("crew_role", &"pilot")
		pilot.set_meta("seat_type", &"physical")

	# Replace the temporary Torrent collision envelope with a compact armored
	# envelope.  These are gameplay collision shapes, not a second damage model.
	# Only the ship's direct shapes belong to that hull envelope. Nested areas
	# retain their own shapes, including the shared boarding discovery sphere.
	for collision_node in find_children("*", "CollisionShape3D", false, false):
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

	if not replace_variant_visual_root(_bulwark_visual):
		return false
	_build_engine_exhaust(_bulwark_visual)
	return true


## A supported bucket and a formed console replace the exposed chair/desk
## primitives. Both retained readouts remain on opposite physical screen faces.
func _build_gunner_station_furniture(armor: Material, frame: Material) -> void:
	_gunner_fitting("GunnerSeat", Vector3.ZERO, [
		Vector4(0.78, -0.12, 0.08, -0.47), Vector4(0.93, -0.15, 0.14, -0.32),
		Vector4(0.89, -0.15, 0.12, 0.30), Vector4(0.78, -0.10, 0.10, 0.43),
	], _materials.upholstery)
	var back_rotation := Vector3(deg_to_rad(-78.0), 0, 0)
	_gunner_fitting("GunnerSeatBack", Vector3(0, 0.63, 0.30), [
		Vector4(0.62, -0.09, 0.09, -0.50), Vector4(0.68, -0.11, 0.14, -0.33),
		Vector4(0.61, -0.09, 0.07, 0.17), Vector4(0.52, -0.07, 0.07, 0.50),
	], _materials.upholstery, back_rotation)
	_gunner_fitting("GunnerSeatShell", Vector3(0, 0.63, 0.30), [
		Vector4(0.84, -0.18, -0.10, -0.51), Vector4(0.95, -0.19, -0.11, -0.32),
		Vector4(0.86, -0.17, -0.09, 0.28), Vector4(0.70, -0.14, -0.06, 0.53),
	], armor, back_rotation)
	# The insert sits inside a continuous shell; raised side cushions cradle the
	# torso instead of reading as one flat upholstered plate from the approach.
	_gunner_fitting("GunnerLumbarCushion", Vector3(0, 0.63, 0.30), [
		Vector4(0.50, 0.13, 0.15, -0.38), Vector4(0.59, 0.14, 0.20, -0.28),
		Vector4(0.57, 0.12, 0.17, -0.15), Vector4(0.49, 0.10, 0.12, -0.09),
	], _materials.upholstery_light, back_rotation)
	_gunner_fitting("GunnerSeatPanShell", Vector3.ZERO, [
		Vector4(0.85, -0.20, -0.10, -0.48), Vector4(1.02, -0.24, -0.10, -0.27),
		Vector4(0.99, -0.23, -0.09, 0.30), Vector4(0.81, -0.18, -0.07, 0.44),
	], armor)
	_gunner_fitting("GunnerHeadrestShell", Vector3(0, 1.21, 0.45), [
		Vector4(0.48, -0.13, -0.04, -0.14), Vector4(0.64, -0.14, -0.03, -0.05),
		Vector4(0.59, -0.12, -0.04, 0.15), Vector4(0.47, -0.10, -0.03, 0.19),
	], armor, back_rotation)
	_gunner_fitting("GunnerHeadrest", Vector3(0, 1.21, 0.45), [
		Vector4(0.42, -0.04, 0.06, -0.13), Vector4(0.56, -0.05, 0.12, -0.05),
		Vector4(0.53, -0.04, 0.10, 0.12), Vector4(0.43, -0.03, 0.06, 0.17),
	], _materials.upholstery_light, back_rotation)
	for side in [-1.0, 1.0]:
		var tag := "Port" if side < 0 else "Starboard"
		_gunner_fitting(tag + "GunnerThighSupport", Vector3(side * 0.42, 0.04, -0.02), [
			Vector4(0.10, -0.10, 0.12, -0.36), Vector4(0.18, -0.12, 0.17, -0.23),
			Vector4(0.18, -0.12, 0.17, 0.24), Vector4(0.11, -0.08, 0.11, 0.34),
		], _materials.upholstery_light)
		_gunner_fitting(tag + "GunnerShoulderSupport", Vector3(side * 0.35, 0.63, 0.30), [
			Vector4(0.10, -0.06, 0.13, -0.40), Vector4(0.17, -0.08, 0.22, -0.24),
			Vector4(0.19, -0.05, 0.22, 0.19), Vector4(0.10, -0.03, 0.10, 0.40),
		], _materials.upholstery_light, back_rotation)
		_gunner_fitting(tag + "GunnerSeatRail", Vector3(side * 0.30, -0.20, 0), [
			Vector4(0.11, -0.08, 0.01, -0.46), Vector4(0.14, -0.08, 0.08, -0.32),
			Vector4(0.14, -0.08, 0.08, 0.32), Vector4(0.11, -0.08, 0.01, 0.46),
		], frame)
		_cylinder_between(_gunner_station, tag + "GunnerHeadrestPost", Vector3(side * 0.17, 1.03, 0.45), Vector3(side * 0.17, 1.24, 0.50), 0.025, frame)
		_cylinder(_gunner_station, tag + "GunnerReclinePivot", Vector3(side * 0.48, 0.14, 0.31), 0.075, 0.035, frame, Vector3(0, 0, 90))
	# The console's crown falls toward the gunner, leaving the entire display
	# above it. Its pedestal meets the existing hull deck beneath the station.
	_gunner_fitting("GunnerConsole", Vector3.ZERO, [
		Vector4(1.34, 0.12, 0.50, -1.17), Vector4(1.55, 0.12, 0.53, -0.95),
		Vector4(1.50, 0.12, 0.40, -0.40), Vector4(1.30, 0.10, 0.32, -0.22),
	], _materials.cockpit_anti_glare, Vector3.ZERO, armor)
	_gunner_fitting("GunnerConsolePedestal", Vector3.ZERO, [
		Vector4(0.86, -0.27, 0.15, -1.02), Vector4(1.08, -0.26, 0.15, -0.60),
		Vector4(0.87, -0.24, 0.12, -0.31),
	], armor)
	var display_mount := Node3D.new()
	display_mount.name = "GunnerDisplayMount"
	display_mount.position = Vector3(0, 0.76, -1.02)
	display_mount.rotation.x = deg_to_rad(-14.0)
	_gunner_station.add_child(display_mount)
	_build_gunner_display_housing(display_mount, armor)
	for side in [-1.0, 1.0]:
		var tag := "Port" if side < 0 else "Starboard"
		# Formed cheeks follow the control deck slope and carry both hand grips.
		_gunner_fitting(tag + "GunnerControlCheek", Vector3(side * 0.56, 0, 0), [
			Vector4(0.16, 0.34, 0.53, -0.78), Vector4(0.24, 0.30, 0.52, -0.54),
			Vector4(0.24, 0.24, 0.45, -0.32), Vector4(0.16, 0.21, 0.33, -0.21),
		], _materials.cockpit_anti_glare, Vector3.ZERO, armor)
		_gunner_fitting(tag + "DisplayFoot", Vector3(side * 0.43, 0, 0), [
			Vector4(0.10, 0.41, 0.52, -1.12), Vector4(0.10, 0.40, 0.64, -1.02),
			Vector4(0.08, 0.41, 0.55, -0.91),
		], frame)
		_cylinder(_gunner_station, tag + "GunnerGripMount", Vector3(side * 0.56, 0.49, -0.43), 0.08, 0.08, armor)
		_cylinder_between(_gunner_station, tag + "GunnerControlGrip", Vector3(side * 0.56, 0.52, -0.43), Vector3(side * 0.55, 0.70, -0.46), 0.043, _materials.cockpit_anti_glare)
	_box(_gunner_station, "GunnerDisplay", Vector3(0, 0.76, -1.02), Vector3(1.05, 0.40, 0.06), _materials.display_substrate, Vector3(deg_to_rad(-14.0), 0, 0))


func _gunner_fitting(label: String, at: Vector3, sections: Array[Vector4], finish: Material, angles: Vector3 = Vector3.ZERO, casing: Material = null) -> MeshInstance3D:
	var fitting := MeshInstance3D.new()
	fitting.name = label
	fitting.position = at
	fitting.rotation = angles
	fitting.mesh = _cockpit_formed_enclosure_mesh(sections, finish, casing)
	_gunner_station.add_child(fitting)
	return fitting


## An extruded, chamfered perimeter leaves the retained two-sided screen open.
## Its edge returns are one casing, avoiding intersecting box-rail corner seams.
func _build_gunner_display_housing(mount: Node3D, finish: Material) -> void:
	var rings: Array[PackedVector3Array] = []
	for section in [
		Vector4(0.606, 0.260, -0.070, 0.042), Vector4(0.616, 0.270, -0.035, 0.045),
		Vector4(0.606, 0.260, 0.060, 0.042), Vector4(0.520, 0.195, 0.060, 0.008),
		Vector4(0.520, 0.195, -0.070, 0.008),
	]:
		var x: float = section.x
		var y: float = section.y
		var z: float = section.z
		var bevel: float = section.w
		rings.append(PackedVector3Array([
			Vector3(-x + bevel, -y, z), Vector3(x - bevel, -y, z),
			Vector3(x, -y + bevel, z), Vector3(x, y - bevel, z),
			Vector3(x - bevel, y, z), Vector3(-x + bevel, y, z),
			Vector3(-x, y - bevel, z), Vector3(-x, -y + bevel, z),
		]))
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	surface.set_material(finish)
	for ring_index in rings.size():
		var current := rings[ring_index]
		var next := rings[(ring_index + 1) % rings.size()]
		for edge in 8:
			var next_edge := (edge + 1) % 8
			var face := [current[edge], next[edge], next[next_edge], current[next_edge]]
			var normal: Vector3 = (face[2] - face[0]).cross(face[1] - face[0]).normalized()
			for vertex_index in [0, 1, 2, 0, 2, 3]:
				var vertex: Vector3 = face[vertex_index]
				surface.set_normal(normal)
				surface.set_uv(Vector2(vertex.x, vertex.y + vertex.z))
				surface.add_vertex(vertex)
	surface.generate_tangents()
	var housing := MeshInstance3D.new()
	housing.name = "GunnerDisplayHousing"
	housing.mesh = surface.commit()
	mount.add_child(housing)


## One swept armor casting joins the rear shield to the outboard shoulder.
## Its flared foot penetrates the existing slab/shoulder; the crown falls below
## the display at the forward end. The entire inboard seat approach stays open.
## Furniture, physical anchors and the coarse gameplay hull remain independent.
func _build_gunner_crew_surround(visual: Node3D, armor: Material) -> void:
	# Ship-local X/Z, crown height and foot height. The rear ring follows the
	# former shield footprint, then turns into the former outboard coaming.
	var sections := [
		Vector4(1.88, 1.37, 2.28, 1.35),
		Vector4(2.08, 1.37, 2.60, 1.35),
		Vector4(2.70, 1.37, 2.60, 1.35),
		Vector4(3.00, 1.09, 2.56, 1.35),
		Vector4(3.08, 0.66, 2.52, 1.42),
		Vector4(3.08, -0.48, 2.40, 1.42),
		Vector4(3.02, -0.96, 1.98, 1.40),
	]
	var outward := [Vector3.BACK, Vector3.BACK, Vector3.BACK,
		Vector3(0.707107, 0, 0.707107), Vector3.RIGHT, Vector3.RIGHT, Vector3.RIGHT]
	var rings: Array[PackedVector3Array] = []
	for index in sections.size():
		var section: Vector4 = sections[index]
		var center := Vector3(section.x, 0, section.y)
		var crown := section.z
		var foot := section.w
		var ring := PackedVector3Array()
		# A broad armor root, chamfered crown and recessed inner face give the
		# crew pocket a supported sill instead of a thin freestanding plate.
		for corner in [Vector2(-0.25, foot), Vector2(0.30, foot),
			Vector2(0.34, foot + 0.08), Vector2(0.16, crown - 0.06),
			Vector2(0.10, crown), Vector2(-0.10, crown),
			Vector2(-0.16, crown - 0.06), Vector2(-0.25, foot + 0.08)]:
			ring.append(center + outward[index] * corner.x + Vector3.UP * corner.y)
		rings.append(ring)
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	surface.set_material(armor)
	for index in range(rings.size() - 1):
		for edge in 8:
			var next := (edge + 1) % 8
			_profile_quad(surface, rings[index][edge], rings[index + 1][edge],
				rings[index + 1][next], rings[index][next])
	# Quad fans close both exposed ends with the same metric projection.
	for index in [0, rings.size() - 1]:
		var ring := rings[index]
		for edge in [1, 3, 5]:
			if index == 0:
				_profile_quad(surface, ring[0], ring[edge], ring[edge + 1], ring[edge + 2])
			else:
				_profile_quad(surface, ring[0], ring[edge + 2], ring[edge + 1], ring[edge])
	surface.generate_tangents()
	var surround := MeshInstance3D.new()
	surround.name = "GunnerRearSplinterShield"
	surround.mesh = surface.commit()
	visual.add_child(surround)


## Functional assemblies use broad continuous armor around recessed mechanics.
## The weapon lanes and aft-port boarding gap keep their established clearance.
func _build_bulwark_manufactured_details(visual: Node3D, armor: Material, dark: Material) -> void:
	var metal := _material(Color("626a6d"), 0.78, 0.4)
	var hot := _material(Color("739eab"), 0.2, 0.35, Color("78afc2"), 0.6)
	_build_propulsion_cradles(visual, metal, dark)
	_pressure_panel(visual, "CockpitPressureTransition", Vector3(0, 1.6, -0.55), 2.1, 3.7, 0.56, 3.4, armor)
	_build_nose_avionics(visual, armor, dark, metal)
	_build_gunner_crew_surround(visual, armor)
	for side in [-1.0, 1.0]:
		var tag := "Port" if side < 0 else "Starboard"
		# Mount cooling cartridges on the actual falling aft deck, so their
		# perimeter and louver bank follow its slope instead of hovering above it.
		var cooling_mount := Node3D.new()
		cooling_mount.name = tag + "ReactorCoolingMount"
		cooling_mount.position = Vector3(side * 1.12, 1.472, 2.34)
		cooling_mount.rotation.x = atan(0.25 / 1.35)
		visual.add_child(cooling_mount)
		ShipServiceCassette.install(cooling_mount, tag + "ReactorCooling", Vector3.ZERO, 0.62, 0.96, armor, dark, metal)
		# One low armored shoulder cap follows the hull instead of a turret stack.
		ShipServiceCassette.install(visual, tag + "BastionThermalFace", Vector3(side * 4.05, 2.37, 1.03), 1.06, 1.05, armor, dark, metal)
		var skirt := _pressure_panel(visual, tag + "OutboardSkirt", Vector3(side * 5.80, 1.08, 0.58), 0.48, 0.64, 0.055, 2.1, armor)
		skirt.rotation.z = PI * 0.5
		for z in [-0.30, 1.46]:
			_box(visual, tag + "SkirtClamp" + str(z), Vector3(side * 5.835, 1.08, z), Vector3(0.07, 0.46, 0.08), metal)
		# Nacelle armor terminates before the separate dark nozzle throat and lip.
		_frustum(visual, tag + "ExhaustBell", Vector3(side * 2.65, 1.15, 5.54), 0.63, 0.52, 0.46, metal, Vector3(90, 0, 0), false, false)
		_cylinder(visual, tag + "RecessedThroat", Vector3(side * 2.65, 1.15, 5.45), 0.48, 0.08, dark, Vector3(90, 0, 0))
		_engine_mechanics(visual, tag, Vector3(side * 2.65, 1.15, 5.72), 0.55, metal, dark, hot)
		# Keep the vent wholly on the flat forward nacelle pad, clear of its step.
		ShipServiceCassette.install(visual, tag + "NacelleDorsalVent", Vector3(side * 2.65, 1.95, 3.50), 0.74, 0.74, armor, dark, metal)
		# The cannon cassette follows the receiver roof before its removable cover.
		var cannon_mount := Node3D.new()
		cannon_mount.name = tag + "CannonCoolingMount"
		cannon_mount.position = Vector3(side * 3.25, 1.45665, -2.95)
		cannon_mount.rotation.x = -atan(0.01 / 0.91)
		visual.add_child(cannon_mount)
		ShipServiceCassette.install(cannon_mount, tag + "CannonCooling", Vector3.ZERO, 0.58, 0.80, armor, dark, metal)
	_build_cannon_construction(visual, armor, dark, metal)

	# Stencilled identification belongs on the continuous armored flank, clear
	# of shoulder joints, boarding hardware, vents and gunner controls.
	for side in [-1.0, 1.0]:
		var registration := ShipSurfaceDetail.mark_surface(visual, ("Port" if side < 0 else "Starboard") + "HullRegistration", "bulwark",
			Vector3(side * 5.85, 1.05, 0.58), Vector2(1.65, 0.84), Vector3(side, 0, 0), Vector3.UP)
		# This dark armor needs lighter stencil ink than the upper hull paint.
		registration.modulate = Color(3.0, 3.0, 3.0, 1.0)
	ShipSurfaceDetail.mark_surface(visual, "AftExhaustWarning", "exhaust",
		Vector3(0, 0.59, 4.50), Vector2(1.75, 0.62), Vector3.BACK, Vector3.UP)


## A removable avionics cassette seats below the glacis, inside an opening in
## ArmoredNose itself. The single sloped mount keeps all fittings on that plane.
func _build_nose_avionics(visual: Node3D, armor: Material, dark: Material, metal: Material) -> void:
	var bay := Node3D.new()
	bay.name = "NoseAvionicsBay"
	bay.position = Vector3(0, 1.065, -4.325)
	bay.rotation.x = -atan(0.55 / 2.15)
	visual.add_child(bay)
	var liner_surface := SurfaceTool.new()
	liner_surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	liner_surface.set_material(dark)
	_profile_quad(liner_surface, Vector3(-0.77, 0.008, -1.095), Vector3(0.77, 0.008, -1.095),
		Vector3(1.23, 0.008, 1.095), Vector3(-1.23, 0.008, 1.095))
	liner_surface.generate_tangents()
	var liner := MeshInstance3D.new()
	liner.name = "ServicePocketLiner"
	liner.mesh = liner_surface.commit()
	bay.add_child(liner)
	var cover_mesh := _profile_mesh([
		Vector4(-0.90, 0.16, 0.065, 0.085),
		Vector4(-0.68, 0.22, 0.09, 0.095),
		Vector4(0.73, 0.33, 0.09, 0.095),
		Vector4(0.91, 0.26, 0.065, 0.085),
	], armor)
	var covers: Array[Transform3D] = []
	var retainers: Array[Transform3D] = []
	for side in [-1.0, 1.0]:
		covers.append(Transform3D(Basis.IDENTITY, Vector3(side * 0.60, 0, 0)))
		for z in [-0.64, 0.66]:
			retainers.append(Transform3D(Basis.IDENTITY, Vector3(side * 0.60, 0.189, z)))
	_add_propulsion_part_batch(bay, "ArmoredServiceCoverBatch", cover_mesh, covers)
	_add_propulsion_part_batch(bay, "CaptiveRetainerBatch", _rounded_box_mesh(Vector3(0.17, 0.035, 0.07), metal), retainers)
	_profile_shell(bay, "AvionicsCartridge", Vector3.ZERO, [
		Vector4(-0.98, 0.21, 0.12, 0.12),
		Vector4(-0.70, 0.30, 0.16, 0.16),
		Vector4(0.60, 0.30, 0.16, 0.16),
		Vector4(0.85, 0.23, 0.10, 0.10),
	], dark)
	# The forward-facing optical window sits behind a protective lower lip.
	var lens := _material(Color("294c58"), 0.56, 0.2)
	_box(bay, "RecessedOpticalWindow", Vector3(0, 0.145, -0.988), Vector3(0.29, 0.105, 0.025), lens)
	_box(bay, "OpticalWindowGuard", Vector3(0, 0.04, -1.015), Vector3(0.48, 0.075, 0.11), armor)
	var ribs: Array[Transform3D] = []
	for index in 6:
		ribs.append(Transform3D(Basis.IDENTITY, Vector3(0, 0.325, -0.41 + float(index) * 0.16)))
	_add_propulsion_part_batch(bay, "AvionicsCoolingRibBatch", _rounded_box_mesh(Vector3(0.37, 0.035, 0.055), metal), ribs)


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
	var state := model.get_component_state(DAMAGE_CUE_COMPONENT_ID) \
		if model != null and model.is_configured() else ShipComponentDamageType.ComponentState.NOMINAL
	_apply_component_damage_cue_pose(state)
	_component_damage_cue.visible = model != null \
		and model.is_configured() \
		and state \
			!= ShipComponentDamageType.ComponentState.NOMINAL


## Keeps the complete retained cue at its authored pose outside the failed
## ledger stage. Reset and repair therefore restore the exact same nominal
## transform, while no gameplay, collision, or component state is mutated here.
func _apply_component_damage_cue_pose(state: int) -> void:
	var vane := _component_damage_cue.get_node_or_null(^"RaisedBreachVane") as MeshInstance3D
	if vane == null:
		return
	if state == ShipComponentDamageType.ComponentState.FAILED:
		vane.position = DAMAGE_VANE_FAILED_POSITION
		vane.rotation = DAMAGE_VANE_FAILED_ROTATION
		return
	vane.position = DAMAGE_VANE_POSITION
	vane.rotation = DAMAGE_VANE_ROTATION


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
	var state := model.get_component_state(DAMAGE_CUE_COMPONENT_ID) \
		if model != null and model.is_configured() else -1
	return {
		"component_id": DAMAGE_CUE_COMPONENT_ID,
		"stage": ShipComponentDamageType.state_id_for(state) if state >= 0 else &"unavailable",
		"silhouette_pose": (
			&"failed_outboard_canted" if state == ShipComponentDamageType.ComponentState.FAILED
			else &"nominal_upright"
		),
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
## two authored finishes, and six submissions while sharing one material-free mesh
## across every Bulwark instance. No renderer consumes or mutates the mesh surface
## material after the per-node authored finish has moved to material_override.
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
	if _shared_cockpit_console_key_mesh == null:
		_shared_cockpit_console_key_mesh = keys[0].mesh
		_shared_cockpit_console_key_mesh.surface_set_material(0, null)
		_shared_cockpit_console_key_mesh.resource_local_to_scene = false
	for index in keys.size():
		keys[index].mesh = _shared_cockpit_console_key_mesh
		keys[index].material_override = authored_materials[index]


## The inherited instrument panel's four bezel leaves are static, childless
## cockpit dressing. Top/bottom and port/starboard were authored as two exact
## geometry/material pairs but allocated four separate meshes. Preserve every
## renderer node, transform, surface material, shadow, layer, and submission;
## only share the immutable mesh inside each pair for this Bulwark instance.
func _share_cockpit_display_bezel_meshes(cockpit: Node3D) -> void:
	if cockpit == null:
		return
	var instrument_cluster := cockpit.get_node_or_null(^"InstrumentCluster") as Node3D
	if instrument_cluster == null:
		return
	var bezel_pairs := [
		PackedStringArray(["DisplayBezelTop", "DisplayBezelBottom"]),
		PackedStringArray(["PortDisplayBezelSide", "StarboardDisplayBezelSide"]),
	]
	for pair_names: PackedStringArray in bezel_pairs:
		var pair: Array[MeshInstance3D] = []
		for bezel_name in pair_names:
			var bezel := instrument_cluster.get_node_or_null(NodePath(bezel_name)) \
					as MeshInstance3D
			if bezel == null or bezel.mesh == null or bezel.get_child_count() != 0:
				return
			pair.append(bezel)
		if pair.size() != COCKPIT_DISPLAY_BEZEL_PAIR_COUNT:
			return
		var shared_mesh := pair[0].mesh
		if shared_mesh.get_surface_count() != 1 \
				or pair[1].mesh.get_surface_count() != 1 \
				or shared_mesh.get_aabb() != pair[1].mesh.get_aabb() \
				or shared_mesh.surface_get_material(0) \
					!= pair[1].mesh.surface_get_material(0):
			return
		shared_mesh.resource_local_to_scene = false
		pair[1].mesh = shared_mesh


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
		lamp.position = Vector3(side * 4.05, 2.11, -1.15)
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
	# A broad load-bearing middle narrows at both ends. The aft bevel closes
	# toward the engine cradle instead of leaving a slab across the stern.
	var mesh := _profile_mesh([
		Vector4(-2.65, 0.38, 0.24, -0.04),
		Vector4(-1.22, 1.70, 0.625, 0),
		# Recessed assembly joints divide the heavy shoulder armor into fitted
		# sections. The middle plate retains the registration and damage mount.
		Vector4(-0.96, 1.70, 0.625, 0), Vector4(-0.92, 1.655, 0.580, 0),
		Vector4(-0.88, 1.70, 0.625, 0),
		Vector4(0.91, 1.70, 0.625, 0), Vector4(0.95, 1.655, 0.580, 0),
		Vector4(0.99, 1.70, 0.625, 0),
		Vector4(1.35, 1.70, 0.625, 0),
		Vector4(2.15, 1.25, 0.47, -0.12),
		Vector4(2.65, 0.72, 0.29, -0.23),
	], material)
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


## Two immutable renderer batches supply the Bulwark's low armored outline and
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
	var mesh := _profile_mesh([
		Vector4(-2.075, 0.24, 0.15, -0.16),
		Vector4(-0.92, 0.90, 0.41, 0),
		Vector4(1.08, 0.90, 0.41, 0),
		Vector4(1.47, 0.71, 0.29, -0.12),
		Vector4(2.075, 0.37, 0.13, -0.28),
	], material) if silhouette_role == &"heavy_gunship_dorsal_bastions" else _loft_mesh(size, material)
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
## or interaction node is attached to either renderer. Forward armor and aft
## protective saddles share one bounded renderer at the retained nacelle mounts.
func _add_engine_housing_batch(
		parent: Node3D,
		transforms: Array[Transform3D],
		authored_names: PackedStringArray,
		material: Material
) -> MultiMeshInstance3D:
	# Forward armor carries the existing vent. Its aft face steps down to a
	# separate upper saddle, exposing the thrust barrel and retention collars
	# below it instead of burying the whole powerplant inside a solid pod.
	var front := _profile_mesh([
		Vector4(-1.75, 0.48, 0.48, -0.03), Vector4(-1.0, 0.85, 0.80, 0),
		Vector4(-0.10, 0.85, 0.80, 0), Vector4(0.10, 0.76, 0.72, 0),
	], material)
	var saddle := _profile_mesh([
		Vector4(0.12, 0.76, 0.19, 0.53), Vector4(0.30, 0.73, 0.19, 0.55),
		Vector4(0.94, 0.64, 0.16, 0.58), Vector4(1.28, 0.49, 0.11, 0.58),
	], material)
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	surface.set_material(material)
	surface.append_from(front, 0, Transform3D.IDENTITY)
	surface.append_from(saddle, 0, Transform3D.IDENTITY)
	var mesh := surface.commit()
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


## Paired receiver castings and removable aft covers share one renderer. Their
## narrow transverse joint is a real break in the shell, backed by a dark seal.
## All weapon, damage and muzzle authority stays on the inherited ship nodes.
func _add_gun_pod_housing_batch(
		parent: Node3D,
		transforms: Array[Transform3D],
		authored_names: PackedStringArray,
		material: Material
) -> MultiMeshInstance3D:
	var receiver := _profile_mesh([
		Vector4(-0.76, 0.38, 0.31, 0.04),
		Vector4(-0.37, 0.56, 0.43, 0.02),
		Vector4(0.54, 0.63, 0.46, 0),
		Vector4(0.73, 0.63, 0.46, 0),
	], material)
	var rear_cover := _profile_mesh([
		Vector4(0.77, 0.63, 0.46, 0),
		Vector4(1.24, 0.57, 0.38, -0.04),
		Vector4(1.55, 0.43, 0.26, -0.08),
	], material)
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	surface.set_material(material)
	# Keep the retained batch poses, authoring the new castings along ship Z.
	var into_mount := Transform3D(Basis(Vector3.RIGHT, -PI * 0.5), Vector3.ZERO)
	surface.append_from(receiver, 0, into_mount)
	surface.append_from(rear_cover, 0, into_mount)
	var mesh := surface.commit()
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


## The barrel has a recessed bore, front retention flange and a tapered muzzle
## lip. Annular surfaces leave visible air around the barrel at its socket;
## the former closed muzzle disk and overlapping narrow pod solid are gone.
func _build_cannon_construction(parent: Node3D, armor: Material, dark: Material, metal: Material) -> void:
	var poses: Array[Transform3D] = []
	var barrel_poses: Array[Transform3D] = []
	for side in [-1.0, 1.0]:
		poses.append(Transform3D(Basis.IDENTITY, Vector3(side * 3.25, 1.0, -3.1)))
		# Fit the bore to the unchanged functional muzzle and its damage cue.
		barrel_poses.append(Transform3D(Basis.IDENTITY, Vector3(side * 3.2, 1.08, -3.1)))
	var gasket := _profile_mesh([
		Vector4(0.71, 0.605, 0.435, 0), Vector4(0.79, 0.605, 0.435, 0),
	], dark)
	_add_propulsion_part_batch(parent, "CannonReceiverSealBatch", gasket, poses)
	var socket := _cannon_annulus_mesh([
		Vector3(-1.19, 0.33, 0.245), Vector3(-1.15, 0.36, 0.245),
		Vector3(-0.83, 0.43, 0.245), Vector3(-0.73, 0.43, 0.245),
	], metal)
	_add_propulsion_part_batch(parent, "CannonRetentionSocketBatch", socket, barrel_poses)
	var barrel := _cannon_annulus_mesh([
		Vector3(-1.81, 0.19, 0.135), Vector3(-1.37, 0.19, 0.135),
		Vector3(-1.34, 0.21, 0.135), Vector3(-0.77, 0.21, 0.135),
	], dark)
	_add_propulsion_part_batch(parent, "CannonRecessedBarrelBatch", barrel, barrel_poses)
	var muzzle := _cannon_annulus_mesh([
		Vector3(-1.88, 0.25, 0.175), Vector3(-1.84, 0.275, 0.155),
		Vector3(-1.69, 0.275, 0.155), Vector3(-1.63, 0.21, 0.155),
	], metal)
	_add_propulsion_part_batch(parent, "CannonOpenMuzzleBatch", muzzle, barrel_poses)
	# Paired longitudinal guides belong to the casting's lower load path,
	# terminating at the socket instead of stacking another slab on its crown.
	var guides: Array[Transform3D] = []
	var guide := _profile_mesh([
		Vector4(-1.05, 0.055, 0.055, 0), Vector4(-0.55, 0.075, 0.07, 0),
		Vector4(0.62, 0.075, 0.07, 0), Vector4(0.69, 0.055, 0.045, 0),
	], armor)
	for pose in poses:
		for flank in [-1.0, 1.0]:
			guides.append(pose * Transform3D(Basis.IDENTITY, Vector3(flank * 0.30, -0.29, 0)))
	_add_propulsion_part_batch(parent, "CannonLowerGuideBatch", guide, guides)


## Closed-wall lathe along Z: outer wall, inward-facing bore and annular ends.
## No center fan closes the opening, and no double-sided material hides winding.
func _cannon_annulus_mesh(stations: Array[Vector3], coating: Material) -> ArrayMesh:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	surface.set_material(coating)
	for ring in range(stations.size() - 1):
		var a := stations[ring]
		var b := stations[ring + 1]
		for segment in 32:
			var angle := TAU * float(segment) / 32.0
			var next_angle := TAU * float(segment + 1) / 32.0
			var p := Vector3(cos(angle), sin(angle), 0)
			var q := Vector3(cos(next_angle), sin(next_angle), 0)
			var front := Vector3(0, 0, a.x)
			var rear := Vector3(0, 0, b.x)

			var outer_slope := (b.y - a.y) / (b.x - a.x)
			var inner_slope := (b.z - a.z) / (b.x - a.x)
			var outer_p := (p + Vector3(0, 0, -outer_slope)).normalized()
			var outer_q := (q + Vector3(0, 0, -outer_slope)).normalized()
			var inner_p := -(p + Vector3(0, 0, -inner_slope)).normalized()
			var inner_q := -(q + Vector3(0, 0, -inner_slope)).normalized()
			# Circumferential normals remain smooth; each authored axial span
			# keeps its own slope so machined shoulders retain a deliberate break.
			_cannon_surface_quad(surface,
				[p * a.y + front, p * b.y + rear, q * b.y + rear, q * a.y + front],
				[outer_p, outer_p, outer_q, outer_q],
				[Vector2(angle, a.x), Vector2(angle, b.x), Vector2(next_angle, b.x), Vector2(next_angle, a.x)])
			_cannon_surface_quad(surface,
				[q * a.z + front, q * b.z + rear, p * b.z + rear, p * a.z + front],
				[inner_q, inner_q, inner_p, inner_p],
				[Vector2(next_angle, a.x), Vector2(next_angle, b.x), Vector2(angle, b.x), Vector2(angle, a.x)])
			if ring == 0:
				_cannon_surface_quad(surface,
					[p * a.z + front, p * a.y + front, q * a.y + front, q * a.z + front],
					[Vector3.FORWARD, Vector3.FORWARD, Vector3.FORWARD, Vector3.FORWARD],
					[Vector2(p.x, p.y) * a.z, Vector2(p.x, p.y) * a.y, Vector2(q.x, q.y) * a.y, Vector2(q.x, q.y) * a.z])
			if ring == stations.size() - 2:
				_cannon_surface_quad(surface,
					[q * b.z + rear, q * b.y + rear, p * b.y + rear, p * b.z + rear],
					[Vector3.BACK, Vector3.BACK, Vector3.BACK, Vector3.BACK],
					[Vector2(q.x, q.y) * b.z, Vector2(q.x, q.y) * b.y, Vector2(p.x, p.y) * b.y, Vector2(p.x, p.y) * b.z])
	surface.generate_tangents()
	return surface.commit()


func _cannon_surface_quad(surface: SurfaceTool, points: Array[Vector3], normals: Array[Vector3], uvs: Array[Vector2]) -> void:
	for corner in [0, 1, 2, 0, 2, 3]:
		surface.set_normal(normals[corner])
		surface.set_uv(uvs[corner])
		surface.add_vertex(points[corner])


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
	var registered_source_id := authority.get_source_id(self)
	if registered_source_id > 0:
		if registered_source_id != COMBAT_SOURCE_ID \
				or authority.get_source_faction(self) != BULWARK_CREW_FACTION_ID:
			return _crew_role_result(false, &"combat_source_identity_mismatch")
		if authority.get_weapon_profile(self, BULWARK_CREW_WEAPON_ID).is_empty():
			# Registration replaces the source's entire weapon dictionary. Never
			# repair a production pilot-only source here by erasing its pilot profile.
			return _crew_role_result(false, &"siege_lance_profile_missing")
	else:
		if not authority.register_source(self, COMBAT_SOURCE_ID, BULWARK_CREW_FACTION_ID, profiles):
			return _crew_role_result(false, &"combat_source_registration_failed")
	_gunner_combat_authority = authority
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
			and bool(engineer_repair.get("resource_ready", false))
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
	_gunner_status_readout.text = "%s\n%s" % [
		str(_gunner_station_feedback.get("roster_text", "× GUNNER [DETACHED]")),
		str(_gunner_station_feedback.get("text", "— NO TARGET —")),
	]
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
		"roster_state": &"detached",
		"roster_text": "× GUNNER [DETACHED]",
		"target_id": StringName(&""),
		"charge_progress": 0.0,
		"cooldown_remaining": 0.0,
		"denial_reason": StringName(&""),
	}
	var roster_feedback := _get_gunner_roster_feedback()
	feedback["roster_state"] = roster_feedback.get("state", &"detached")
	feedback["roster_text"] = roster_feedback.get("text", "× GUNNER [DETACHED]")
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


## Formats only the sealed authority's detached public roster. It never claims,
## releases, or otherwise mutates the crew ledger. A retained RELEASED token is
## shown only after this station was actually occupied and the public roster
## subsequently no longer contains that assignment.
func _get_gunner_roster_feedback() -> Dictionary:
	if _crew_role_authority == null:
		_gunner_roster_presentation_state = &"detached"
		return {"state": &"detached", "text": "× GUNNER [DETACHED]"}
	var snapshot := _crew_role_authority.get_snapshot()
	if not bool(snapshot.get("roster_sealed", false)):
		_gunner_roster_presentation_state = &"detached"
		return {"state": &"detached", "text": "× GUNNER [DETACHED]"}

	var gunner_assignment := {}
	for assignment_variant in snapshot.get("assignments", []) as Array:
		if not assignment_variant is Dictionary:
			continue
		var assignment := assignment_variant as Dictionary
		if StringName(assignment.get("seat_id", &"")) == GUNNER_SEAT_ID \
				and StringName(assignment.get("role", &"")) == CrewRoleGameplayProfileType.ROLE_GUNNER:
			gunner_assignment = assignment
			break
	if gunner_assignment.is_empty():
		if _gunner_roster_presentation_state in [&"claimed", &"armed", &"active"]:
			_gunner_roster_presentation_state = &"released"
		if _gunner_roster_presentation_state == &"released":
			return {"state": &"released", "text": "↗ GUNNER [RELEASED]"}
		_gunner_roster_presentation_state = &"available"
		return {"state": &"available", "text": "□ GUNNER [AVAILABLE]"}

	var actor_key := _gunner_role_actor_key_from_values(
		int(gunner_assignment.get("occupant_peer_id", 0)),
		StringName(gunner_assignment.get("avatar_id", &""))
	)
	var state: StringName = &"claimed"
	if not (_gunner_role_charges.get(actor_key, {}) as Dictionary).is_empty():
		state = &"active"
	elif not _gunner_target_selection.is_empty() \
			and int(_gunner_target_selection.get("occupant_peer_id", 0)) == int(gunner_assignment.get("occupant_peer_id", 0)) \
			and StringName(_gunner_target_selection.get("avatar_id", &"")) == StringName(gunner_assignment.get("avatar_id", &"")):
		state = &"armed"
	_gunner_roster_presentation_state = state
	match state:
		&"active":
			return {"state": state, "text": "▲ GUNNER [ACTIVE]"}
		&"armed":
			return {"state": state, "text": "◆ GUNNER [ARMED]"}
	return {"state": &"claimed", "text": "■ GUNNER [CLAIMED]"}


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
			and _engineer_repair_authority.get_generation() == ledger_generation:
		if _engineer_repair_actor_id == actor_id:
			return _crew_role_result(true, &"repair_authority_ready")
		if _engineer_repair_authority.has_active_repair():
			_interrupt_engineer_repair(&"repair_actor_changed")
		var rebound := _engineer_repair_authority.rebind_actor(
			actor_id, ledger_generation
		)
		if not bool(rebound.get("accepted", false)):
			var rejected := _crew_role_result(
				false,
				StringName(rebound.get("reason", &"repair_actor_rebind_rejected"))
			)
			rejected["repair"] = rebound.duplicate(true)
			return rejected
		_engineer_repair_actor_id = actor_id
		return _crew_role_result(true, &"repair_authority_rebound")
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
		ENGINEER_REPAIR_RESOURCE_CAPACITY
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
	var resource_units := (
		_engineer_repair_authority.get_resource_units()
		if _engineer_repair_authority != null else ENGINEER_REPAIR_RESOURCE_CAPACITY
	)
	snapshot["resource_id"] = ENGINEER_REPAIR_RESOURCE_ID
	snapshot["resource_capacity"] = ENGINEER_REPAIR_RESOURCE_CAPACITY
	snapshot["resource_units"] = resource_units
	snapshot["resource_ready"] = resource_units > 0
	snapshot["active"] = _engineer_repair_authority != null \
		and _engineer_repair_authority.has_active_repair()
	return snapshot.duplicate(true)


## Restocks this landed craft's existing finite engineer locker without
## resetting component damage, cooldown, role assignment, or ship lifecycle.
func restock_engineer_repair_kits() -> Dictionary:
	var telemetry := get_telemetry()
	if is_destroyed():
		return {"accepted": false, "reason": &"ship_destroyed"}
	if is_piloted():
		return {"accepted": false, "reason": &"pilot_seated"}
	if not bool(telemetry.get("landed", false)) \
			or bool(telemetry.get("landing_active", false)):
		return {"accepted": false, "reason": &"ship_not_landed"}
	if _engineer_repair_authority == null:
		return {
			"accepted": true,
			"reason": &"resource_already_full",
			"ship_id": get_ship_id(),
			"display_name": get_display_name(),
			"resource_id": ENGINEER_REPAIR_RESOURCE_ID,
			"resource_capacity": ENGINEER_REPAIR_RESOURCE_CAPACITY,
			"resource_units": ENGINEER_REPAIR_RESOURCE_CAPACITY,
			"previous_resource_units": ENGINEER_REPAIR_RESOURCE_CAPACITY,
			"units_added": 0,
		}
	var model := get_component_damage()
	if model == null:
		return {"accepted": false, "reason": &"component_authority_unavailable"}
	var result := _engineer_repair_authority.restock_resource(
		ENGINEER_REPAIR_RESOURCE_ID, model.get_ledger_generation()
	)
	result["ship_id"] = get_ship_id()
	result["display_name"] = get_display_name()
	if bool(result.get("accepted", false)) \
			and int(result.get("units_added", 0)) > 0:
		engineer_repair_state_changed.emit(get_engineer_repair_state())
		_refresh_engineer_status_readout()
	return result.duplicate(true)


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
	var resource_units := int(repair.get("resource_units", 0))
	var resource_capacity := int(repair.get("resource_capacity", 0))
	var token := "[READY]" if resource_units > 0 else "[DEPLETED]"
	if status == &"repairing":
		token = "[WORK %d%%]" % int(round(
			clampf(float(repair.get("progress", 0.0)), 0.0, 1.0) * 100.0
		))
	elif status == &"interrupted":
		token = "[INTERRUPTED]"
	elif float(repair.get("cooldown_remaining", 0.0)) > 0.0:
		token = "[COOLDOWN %.1fs]" % float(repair.get("cooldown_remaining", 0.0))
	_engineer_status_readout.text = "ENGINEER REPAIR\n%s // KITS %d/%d" % [
		token, resource_units, resource_capacity
	]


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
	_engineer_repair_state = {
		"status": &"idle",
		"reason": &"",
		"component_id": &"",
		"component_generation": 0,
		"progress": 0.0,
	}
	_engineer_component_selection.clear()
	if advance_generation:
		_engineer_component_generation = mini(_engineer_component_generation + 1, MAX_GUNNER_TARGET_GENERATION)
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
	# Publish the same live root-shape union that landing assist consumes. The
	# former literal omitted the chin collision's lower 0.33 m and shifted the
	# longitudinal bounds, allowing berth-route audits to reason about a smaller
	# hull than the player could actually hit.
	var collision_bounds := get_landing_collision_report().get(
		"local_bounds", AABB()
	) as AABB
	return {
		"schema_version": 1,
		"home_berth_id": get_home_berth_id(),
		"parked_render_bounds": AABB(Vector3(-5.8, -0.9, -6.0), Vector3(11.6, 5.0, 12.0)),
		"flight_collision_bounds": collision_bounds,
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
		"color_role": &"gunmetal_amber",
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



## Chamfered pressure-shell stock reuses the inherited closed loft topology.
## Broad planar stations carry armor panels; corner facets catch a narrow edge
## highlight without inflating the entire silhouette like a superellipse.
func _loft_mesh(size: Vector3, material: Material) -> ArrayMesh:
	var scratch := Node3D.new()
	var instance := _wedge(scratch, "LoftStock", Vector3.ZERO, size, material)
	var source := instance.mesh as ArrayMesh
	var arrays := source.surface_get_arrays(0)
	var points: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var section := PackedVector2Array([
		Vector2(0, 1), Vector2(0.72, 1), Vector2(1, 0.72), Vector2(1, 0.36),
		Vector2(1, 0), Vector2(1, -0.36), Vector2(1, -0.72), Vector2(0.72, -1),
		Vector2(0, -1), Vector2(-0.72, -1), Vector2(-1, -0.72), Vector2(-1, -0.36),
		Vector2(-1, 0), Vector2(-1, 0.36), Vector2(-1, 0.72), Vector2(-0.72, 1),
	])
	# SurfaceTool reindexes vertices when it generates normals. UV station
	# coordinates remain stable through that optimization; array order does not.
	var uv: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
	for index in points.size():
		if Vector2(points[index].x, points[index].y).length_squared() < 0.0000001:
			continue
		var progress := uv[index].y
		var corner := roundi(uv[index].x * 16.0) % 16
		var breadth := minf(1.0, lerpf(0.12, 1.0, progress / 0.43))
		var depth := minf(1.0, lerpf(0.35, 1.0, progress / 0.28))
		if progress > 0.83:
			breadth = lerpf(1.0, 0.9, (progress - 0.83) / 0.17)
			depth = lerpf(1.0, 0.8, (progress - 0.83) / 0.17)
		points[index] = Vector3(
			section[corner].x * size.x * 0.5 * breadth,
			section[corner].y * size.y * 0.5 * depth,
			lerpf(-size.z * 0.5, size.z * 0.5, progress)
		)
	# The tapered chamfers are bilinear patches: width and height change at
	# different rates, so each quad is twisted. Analytic patch normals avoid
	# diagonal-weighted light fans while retaining the actual profile folds.
	var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	surface.set_material(material)
	for triangle in range(0, indices.size(), 3):
		var a := points[indices[triangle]]
		var b := points[indices[triangle + 1]]
		var c := points[indices[triangle + 2]]
		var face_normal := (c - a).cross(b - a).normalized()
		var is_cap := absf(face_normal.z) > 0.999
		var rings: Array[int] = []
		var first_t := 1.0
		var last_t := 0.0
		for corner in 3:
			var coordinate := uv[indices[triangle + corner]]
			rings.append(roundi(coordinate.x * 16.0) % 16)
			first_t = minf(first_t, coordinate.y)
			last_t = maxf(last_t, coordinate.y)
		rings.sort()
		var edge := 15 if rings[2] - rings[0] > 8 else rings[0]
		var edge_direction := section[(edge + 1) % 16] - section[edge]
		var extents: Array[Vector2] = []
		for t in [first_t, last_t]:
			var width := minf(1.0, lerpf(0.12, 1.0, t / 0.43))
			var height := minf(1.0, lerpf(0.35, 1.0, t / 0.28))
			if t > 0.83:
				width = lerpf(1.0, 0.9, (t - 0.83) / 0.17)
				height = lerpf(1.0, 0.8, (t - 0.83) / 0.17)
			extents.append(Vector2(width * size.x * 0.5, height * size.y * 0.5))
		var extent_delta := extents[1] - extents[0]
		for corner in 3:
			var vertex_index := indices[triangle + corner]
			var texture_uv := uv[vertex_index]
			var normal := face_normal
			if is_cap:
				# Station UVs collapse each end cap to a line. Project the cap
				# on XY so its tangent and normal-map sampling remain defined.
				texture_uv = Vector2(points[vertex_index].x / size.x, points[vertex_index].y / size.y) + Vector2.ONE * 0.5
			else:
				var ring := roundi(texture_uv.x * 16.0) % 16
				var extent := extents[0] if is_equal_approx(texture_uv.y, first_t) else extents[1]
				var around := Vector3(edge_direction.x * extent.x, edge_direction.y * extent.y, 0)
				var along := Vector3(section[ring].x * extent_delta.x, section[ring].y * extent_delta.y, size.z * (last_t - first_t))
				normal = along.cross(around).normalized()
				# Duplicate U=0 as U=1 on the final wrapped sidewall strip.
				if edge == 15 and ring == 0:
					texture_uv.x = 1.0
			surface.set_normal(normal)
			surface.set_uv(texture_uv)
			surface.add_vertex(points[vertex_index])
	surface.generate_tangents()
	var result := surface.commit()
	scratch.free()
	return result


func _armor_shell(parent: Node3D, node_name: String, at: Vector3, size: Vector3, coating: Material, skew: float = 0.0) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.name = node_name
	instance.position = at
	instance.mesh = _loft_mesh(size, coating)
	# Shear the assembly into the wing root without an intersecting box joint.
	instance.transform.basis.z.x = -skew
	parent.add_child(instance)
	return instance


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


## The exposed aft thrust cartridges sit inside the existing nacelle envelope.
## Each immutable part family is shared across both engines; neither the nozzle
## mouths nor their independently driven exhaust meshes move with this dressing.
func _build_propulsion_cradles(parent: Node3D, metal: Material, dark: Material) -> void:
	var barrel := StationSurfaceKit.chamfered_cylinder_mesh_cached(
		0.60, 0.60, 1.22, 32, _chamfered_cylinder_cache,
		ShipSurfaceDetail.CYLINDER_WALL_RINGS, true, true, metal
	)
	var collar := TorusMesh.new()
	collar.inner_radius = 0.575
	collar.outer_radius = 0.685
	collar.rings = 40
	collar.ring_segments = 8
	collar.material = metal
	var rail := _profile_mesh([
		Vector4(-0.41, 0.038, 0.030, 0), Vector4(-0.35, 0.0525, 0.045, 0),
		Vector4(0.35, 0.0525, 0.045, 0), Vector4(0.41, 0.038, 0.030, 0),
	], dark)
	var barrels: Array[Transform3D] = []
	var collars: Array[Transform3D] = []
	var rails: Array[Transform3D] = []
	for side in [-1.0, 1.0]:
		var center := Vector3(side * 2.65, 1.15, 4.66)
		barrels.append(Transform3D(Basis(Vector3.RIGHT, PI * 0.5), center))
		for z in [4.27, 5.17]:
			collars.append(Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3(center.x, center.y, z)))
		# Broad axial cooling rails tie the collars together on the exposed
		# flanks. The upper saddle covers the top of the cartridge.
		for degrees in [-125.0, -55.0, 55.0, 125.0]:
			var angle := deg_to_rad(degrees)
			rails.append(Transform3D(Basis(Vector3.BACK, -angle), center + Vector3(sin(angle), cos(angle), 0) * 0.61))
	_add_propulsion_part_batch(parent, "ThrustCartridgeBatch", barrel, barrels)
	_add_propulsion_part_batch(parent, "ThrustRetentionCollarBatch", collar, collars)
	_add_propulsion_part_batch(parent, "ThrustCoolingRailBatch", rail, rails)


func _add_propulsion_part_batch(parent: Node3D, label: String, mesh: Mesh, poses: Array[Transform3D]) -> void:
	var multi := MultiMesh.new()
	multi.transform_format = MultiMesh.TRANSFORM_3D
	multi.mesh = mesh
	multi.instance_count = poses.size()
	var bounds := AABB()
	for index in poses.size():
		multi.set_instance_transform(index, poses[index])
		var part_bounds := poses[index] * mesh.get_aabb()
		bounds = part_bounds if index == 0 else bounds.merge(part_bounds)
	multi.custom_aabb = bounds
	var batch := MultiMeshInstance3D.new()
	batch.name = label
	batch.multimesh = multi
	batch.set_meta(&"presentation_only", true)
	parent.add_child(batch)


## Annular combustion channel, retained hub and guide vanes give an unlit
## engine physical depth. Repeated vanes share one mesh and renderer.
func _engine_mechanics(parent: Node3D, tag: String, at: Vector3, radius: float, metal: Material, dark: Material, hot: Material) -> void:
	_cylinder(parent, tag + "ChamberBack", at + Vector3(0, 0, -0.22 * radius), radius * 0.86, radius * 0.08, dark, Vector3(90, 0, 0))
	for ring in 2:
		var torus := TorusMesh.new()
		torus.inner_radius = radius * (0.44 if ring == 0 else 0.88)
		torus.outer_radius = radius * (0.57 if ring == 0 else 1.02)
		torus.rings = 40
		torus.ring_segments = 8
		var lip := MeshInstance3D.new()
		lip.name = tag + ("CombustorAnnulus" if ring == 0 else "NozzleLip")
		lip.mesh = torus
		lip.material_override = hot if ring == 0 else metal
		lip.position = at + Vector3(0, 0, (-0.14 if ring == 0 else 0.18) * radius)
		lip.rotation.x = PI * 0.5
		parent.add_child(lip)
	_frustum(parent, tag + "ThrustPlug", at + Vector3(0, 0, -0.04 * radius), radius * 0.20, radius * 0.36, radius * 0.45, metal, Vector3(90, 0, 0))
	var blades := MultiMesh.new()
	blades.transform_format = MultiMesh.TRANSFORM_3D
	blades.mesh = _rounded_box_mesh(Vector3(radius * 0.065, radius * 0.29, radius * 0.18), metal)
	blades.instance_count = 12
	for i in 12:
		var angle := float(i) * TAU / 12.0
		blades.set_instance_transform(i, Transform3D(Basis(Vector3.BACK, angle + 0.22), Vector3(-sin(angle), cos(angle), 0) * radius * 0.71))
	var batch := MultiMeshInstance3D.new()
	batch.name = tag + "GuideVanes"
	batch.multimesh = blades
	batch.position = at
	batch.set_meta(&"presentation_only", true)
	parent.add_child(batch)


## Each station stores longitudinal position, half width, half height and rise.
## Planar chines retain deliberate creases; bilinear side normals avoid diagonal
## shading seams where successive sections change width and height together.
func _profile_mesh(stations: Array, coating: Material, nose_service_pocket: bool = false) -> ArrayMesh:
	var corners := [Vector2(-0.72, 1), Vector2(0.72, 1), Vector2(1, 0.5), Vector2(1, -0.5), Vector2(0.72, -1), Vector2(-0.72, -1), Vector2(-1, -0.5), Vector2(-1, 0.5)]
	var section: Array[Vector2] = []
	var tangents: Array[Vector2] = []
	# Small quadratic corner breaks leave the broad armor planes intact.
	# Their tangents join those planes continuously, avoiding a soft inflatable
	# hull or sharp polygon edges with no manufactured highlight.
	for index in corners.size():
		var corner: Vector2 = corners[index]
		var before := corner.lerp(corners[(index + 7) % 8], 0.14)
		var after := corner.lerp(corners[(index + 1) % 8], 0.14)
		for sample in 5:
			var t := float(sample) / 4.0
			section.append(before.lerp(corner, t).lerp(corner.lerp(after, t), t))
			tangents.append((corner - before).lerp(after - corner, t).normalized())
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	surface.set_material(coating)
	var total_length: float = stations[-1].x - stations[0].x
	for i in range(stations.size() - 1):
		var a: Vector4 = stations[i]
		var b: Vector4 = stations[i + 1]
		for j in section.size():
			var p: Vector2 = section[j]
			var q: Vector2 = section[(j + 1) % section.size()]
			var points := [Vector3(p.x * a.y, p.y * a.z + a.w, a.x), Vector3(q.x * a.y, q.y * a.z + a.w, a.x), Vector3(q.x * b.y, q.y * b.z + b.w, b.x), Vector3(p.x * b.y, p.y * b.z + b.w, b.x)]
			# Only the broad top face of the nose's middle span is opened. Its
			# perimeter stays continuous with the original load-bearing shell.
			if nose_service_pocket and i == 1 and j == 4:
				var front_left := Vector3(-0.78, a.z + a.w, a.x)
				var front_right := Vector3(0.78, a.z + a.w, a.x)
				var rear_left := Vector3(-1.24, b.z + b.w, b.x)
				var rear_right := Vector3(1.24, b.z + b.w, b.x)
				var drop := Vector3(0, -0.16, 0)
				_profile_quad(surface, points[0], front_left, rear_left, points[3])
				_profile_quad(surface, front_right, points[1], points[2], rear_right)
				_profile_quad(surface, front_left, front_left + drop, rear_left + drop, rear_left)
				_profile_quad(surface, front_right + drop, front_right, rear_right, rear_right + drop)
				_profile_quad(surface, front_left + drop, front_right + drop, rear_right + drop, rear_left + drop)
				_profile_quad(surface, front_left, front_right, front_right + drop, front_left + drop)
				_profile_quad(surface, rear_left + drop, rear_right + drop, rear_right, rear_left)
				continue
			for corner in [0, 1, 2, 0, 2, 3]:
				var station := a if corner < 2 else b
				var ring := p if corner == 0 or corner == 3 else q
				var tangent := tangents[j if corner == 0 or corner == 3 else (j + 1) % section.size()]
				var around := Vector3(tangent.x * station.y, tangent.y * station.z, 0)
				var along := Vector3(ring.x * (b.y - a.y), ring.y * (b.z - a.z) + b.w - a.w, b.x - a.x)
				surface.set_normal(along.cross(around).normalized())
				surface.set_uv(Vector2(float(j + (1 if corner == 1 or corner == 2 else 0)) / float(section.size()), (station.x - stations[0].x) / total_length))
				surface.add_vertex(points[corner])
	for cap in [0, stations.size() - 1]:
		var station: Vector4 = stations[cap]
		for j in section.size():
			var p: Vector2 = section[j]
			var q: Vector2 = section[(j + 1) % section.size()]
			var ring_order := [Vector2.ZERO, q, p] if cap == 0 else [Vector2.ZERO, p, q]
			for ring: Vector2 in ring_order:
				surface.set_normal(Vector3.FORWARD if cap == 0 else Vector3.BACK)
				surface.set_uv(ring * 0.5 + Vector2.ONE * 0.5)
				surface.add_vertex(Vector3(ring.x * station.y, ring.y * station.z + station.w, station.x))
	surface.generate_tangents()
	return surface.commit()


## Clockwise flat quads with metric planar UVs, also valid on pocket walls.
func _profile_quad(surface: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3) -> void:
	var normal := (c - a).cross(b - a).normalized()
	var u := (b - a).normalized()
	var v := u.cross(normal).normalized()
	for point: Vector3 in [a, b, c, a, c, d]:
		surface.set_normal(normal)
		surface.set_uv(Vector2((point - a).dot(u), (point - a).dot(v)))
		surface.add_vertex(point)


func _profile_shell(parent: Node3D, label: String, at: Vector3, stations: Array, coating: Material, nose_service_pocket: bool = false) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.name = label
	instance.position = at
	instance.mesh = _profile_mesh(stations, coating, nose_service_pocket)
	parent.add_child(instance)
	return instance


## Add the missing propulsion presentation at this hull's nozzle mouths. The
## envelope is baked along local +Z with its base at zero, so HeroShip's axial
## throttle/damage scaling cannot widen the plume or pull it out of its mount.
func _build_engine_exhaust(visual: Node3D) -> void:
	var radius := 0.55
	var nozzle := Vector3(2.65, 1.15, 5.72)
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
