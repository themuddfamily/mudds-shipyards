class_name HalyardCrewTransport
extends HeroShip

## Halyard Crew Transport — an original modern craft.
##
## `modern_interpretation`, and specifically **not** a remake. The Halyard has no
## entry in the source ledger, is named after nothing in it, and is registered as
## `ShipDefinition.EvidenceStatus.NEW` with no evidence references. Every metre,
## colour, fitting and handling value below is this project's own design. Nothing
## here is a claim about the original game, and nothing here may be cited as one.
##
## **The role it fills.** The implemented fleet had three fighters and one
## freighter. It had nothing that carries people. The Halyard is a pressurised
## crew carrier: a long, narrow, faceted pressure hull with a two-station flight
## deck, six forward-facing crew seats, an aft systems bay with two bunks, and a
## port-side airstair. It is the second craft in the fleet whose pilot may leave
## the seat and walk the hull while it is under way (see
## [method get_in_flight_cabin_report]), and the first one built for that from
## the outset rather than around a cargo hold.
##
## **The lateral trade it makes.** The Halyard alone owns the fleet's highest
## sustained top speed (108 m/s). It pays for that everywhere else: it owns the
## fleet's *lowest* thrust acceleration, brake acceleration, throttle response,
## boost multiplier, turn rates and landing gate, and the fleet's *longest*
## engine spool and weapon cadence. Its boost is the weakest in the fleet, so
## every fighter still out-sprints it — it is fast only once it is already fast,
## and it commits to a vector long before it arrives on one. Its hull (190) sits
## second in the fleet, below the freighter and above every fighter. See
## `docs/design/FLEET_VISUAL_GRAMMAR.md` §8 and
## `tests/fleet_role_differentiation_test.gd` for the rule this satisfies, and
## `tests/halyard_crew_transport_test.gd` for the regression that holds it.
##
## **The silhouette.** A long faceted octagonal pressure tube — the only craft in
## the fleet whose dominant mass is a tube rather than a plate, wedge, delta or
## slab — carrying a proud open bow docking arch on two struts, a lit
## band of ten cabin windows down each flank, a dorsal service spine, and a
## transverse tail yoke with four engines in a single row. Span-to-length is
## 0.34, well clear of Torrent 0.80, Arrow 0.91, Jovian 0.71 and Zenith 1.38. It
## borrows neither Zenith's wide-delta/strake/pod language nor Torrent's aft
## rails and paired round housings; both are evidence-bounded reads and are not
## available to a modern design.

const SCHEMA_VERSION := 1
const EVIDENCE_STATUS: StringName = &"modern_interpretation"
const EVIDENCE_SCOPE: StringName = &"original_design"
const NAME_TO_MODEL_STATUS: StringName = &"not_applicable"
const COMBAT_SOURCE_ID := 1105
const INTERIOR_SCHEMA_VERSION := 1
const CrewSeatRoleAuthorityType := preload("res://scripts/ships/crew_seat_role_authority.gd")
const CrewRoleGameplayProfileType := preload("res://scripts/fleet/crew_role_gameplay_profile.gd")
const HalyardCrewStatusDisplayType := preload("res://scripts/ships/halyard_crew_status_display.gd")
const ShipPerspectiveAudioBindingType := preload("res://scripts/audio/ship_perspective_audio_binding.gd")
const HalyardLoadmasterAudioBindingType := preload("res://scripts/audio/halyard_loadmaster_audio_binding.gd")
const HALYARD_CREW_WEAPON_ID: StringName = &"halyard_long_range_defensive_lance"
const HALYARD_CREW_FACTION_ID: StringName = &"shipyard_flight_test"
const PASSENGER_PING_COOLDOWN_SECONDS := 1.0
const MAX_PASSENGER_PING_MARKERS := 8
const MAX_GUNNER_TARGET_GENERATION := 1_000_000
const LOADMASTER_STATION_SEAT_ID: StringName = &"crew_port_00"
const LOADMASTER_MANIFEST_GENERATION_MAX := 1_000_000
const ENGINEER_POWER_ROUTE_BONUS := 0.15
const CREW_ROLE_GAMEPLAY_SNAPSHOT_SCHEMA_VERSION := 1
const HALYARD_CREW_ROLE_OCCUPANT_META: StringName = &"_halyard_crew_role_occupant"


class HalyardPilotCommandSource:
	extends ShipCommandSource

	var _held_controls: Dictionary = {}


	func set_held_controls(controls: Dictionary) -> void:
		_held_controls = controls.duplicate(true)


	func clear_held_controls() -> void:
		_held_controls.clear()


	func _sample_controls() -> Dictionary:
		return _held_controls.duplicate(true)

signal passenger_cabin_ping_emitted(
	marker_id: StringName,
	channel: StringName,
	world_position: Vector3,
	receipt: Dictionary
)
signal passenger_cabin_ping_cleared(
	marker_id: StringName,
	reason: StringName,
	occupant_peer_id: int,
	avatar_id: StringName
)
signal gunner_target_selected(
	target_id: StringName,
	target_generation: int,
	receipt: Dictionary
)
signal gunner_target_cleared(
	target_id: StringName,
	target_generation: int,
	reason: StringName
)
signal engineer_component_selected(
	component_id: StringName,
	component_generation: int,
	receipt: Dictionary
)
signal engineer_component_cleared(
	component_id: StringName,
	component_generation: int,
	reason: StringName
)
signal engineer_power_route_changed(
	component_id: StringName,
	route: StringName,
	bonus: float,
	receipt: Dictionary
)
signal loadmaster_manifest_intent_accepted(receipt: Dictionary)
signal loadmaster_manifest_cleared(generation: int, reason: StringName)

const DESIGN_NOTE := (
	"The Halyard is an original modern design created for this remake. It is not "
	+ "a reconstruction, candidate, or interpretation of any historical Keth ship; "
	+ "its name appears in no registered source and is deliberately not one of the "
	+ "reserved ledger names. Its silhouette, dimensions, colours, cabin, crew "
	+ "stations, systems, materials, handling and berth are all modern design and "
	+ "authenticate nothing."
)

## Ship-local envelope of the connected walkable interior. Drives the occupancy
## Area3D that registers a crew member with the moving-interior coordinator.
const INTERIOR_BOUNDS := AABB(Vector3(-2.60, 0.0, -13.40), Vector3(5.20, 3.60, 22.70))

## Ship-local envelope a crew member may occupy while the transport is under way.
##
## This is the anti-stranding box, not the room plan — real walls do the
## room-by-room work. It is the bounding box of the craft's three walkable deck
## collision footprints (`CockpitDeckCollision`, `CabinDeckCollision`,
## `AftBayDeckCollision`), grown upward to head height and outward to the hull
## walls, so nothing outside the pressure hull is inside it. `PlayerController`
## confines the occupant to this box, so the only way out of a flying Halyard is
## back into the pilot seat.
const CABIN_MOVEMENT_BOUNDS := AABB(Vector3(-2.62, 0.30, -13.40), Vector3(5.24, 3.30, 22.70))

## Standing pose the pilot arrives at when leaving the seat under way: on the
## cabin deck immediately aft of the flight-deck portal, facing aft down the
## aisle into the cabin they have just been given.
const CABIN_STAND_LOCAL_ORIGIN := Vector3(0.0, 0.52, -8.90)
const CABIN_STAND_LOCAL_YAW := PI

const PARKED_RENDER_BOUNDS := AABB(Vector3(-4.95, -1.13, -13.90), Vector3(9.90, 5.70, 28.50))
const FLIGHT_COLLISION_BOUNDS := AABB(Vector3(-4.85, -1.10, -13.85), Vector3(9.70, 5.65, 28.40))

# --------------------------------------------------------------- palette ----
#
# Both identity colours were chosen by measurement, not by eye, using the same
# implementation the fleet audit measures with (`tests/fleet_colour_metrics.gd`:
# sRGB -> linear -> Vienot 1999 dichromat simulation -> CIE L*a*b* -> CIEDE2000),
# swept over the sRGB cube against all four existing craft under all four vision
# models. The rule applied was the strict one from
# `docs/design/FLEET_VISUAL_GRAMMAR.md` §7.2 — do not spend the fleet's measured
# headroom — so each value had to beat the *current fleet minimum*, not merely
# the frozen floor.
#
# HULL_OLIVE #6e7a3e: worst separation 19.06 (vs Jovian under protanopia), above
# both the 12.0 floor and today's 16.62 fleet body-tone minimum, so adding it
# leaves that minimum exactly where it was. Green is the one hue region no craft
# in the fleet occupies, and at L* 49.0 it still reads against near-black space,
# which a darker high-separation tone would not.
#
# HALYARD_ACCENT #341024: worst separation 31.60 (vs Jovian under protanopia),
# above the 25.0 accent floor, above the 30.0 Torrent floor, and above today's
# 31.38 fleet accent minimum — again spending nothing.
#
# **Recorded finding, because it constrains whoever adds the sixth craft.** The
# chromatic accent space is now exhausted. A full sweep of the sRGB cube found
# that *every* colour clearing both accent floors is either near-neutral grey at
# ~25.1 (barely over the floor, and a grey is not an identification colour) or
# dark violet/plum below L* 27. The lightest value that spends no headroom at
# all is this one, at L* 10.8. That is why the Halyard's accent is a deep
# aubergine used as exterior banding rather than a bright trim colour, and why
# the craft carries its identity in its body tone and its silhouette instead.
# `tests/halyard_crew_transport_test.gd` re-measures both numbers so the finding
# cannot rot.
const HULL_OLIVE := Color("6e7a3e")
const HULL_SHADE := Color("566030")
const HALYARD_ACCENT := Color("341024")
const HALYARD_STRUCTURE := Color("2f3a33")
const HALYARD_STRUCTURE_DARK := Color("17201c")
const DECK_PLATE := Color("3d443c")
const CABIN_TRIM := Color("4a5348")
const SEAT_CLOTH := Color("24312c")
const LOCKER_FACE := Color("46503f")
const CABIN_LIGHT := Color("a9bda4")
const WINDOW_INTERIOR := Color("33403a")
# Shared fleet layer, unchanged and deliberately not differentiating: cyan
# engine emission, red to port, green to starboard.
# (`docs/design/FLEET_VISUAL_GRAMMAR.md` §2, layer 1.)
const ENGINE_CYAN := Color("68f0ef")
const HALYARD_NAV_RED := Color("ff5f58")
const HALYARD_NAV_GREEN := Color("74ec97")

# ------------------------------------------------------------- surfacing ----
#
# Every surface on this craft is built by `StationSurfaceKit`'s chamfered
# builders and finished with the registered object-local triplanar panel recipe
# (`StationSurfaceKit.apply_panel_triplanar`), which binds the registered
# `procedural-panel-triplanar-*-v2` albedo/normal/roughness trio at
# `normal_scale = 1.0`, triplanar projection, sharpness 4.0. The helper's
# station-world projection is disabled after binding because this craft moves.
#
# One deliberate departure, with both rules named. `apply_panel_triplanar` sets
# `normal_scale = 1.0`; that is the *station* family's relief, and
# `docs/design/FLEET_VISUAL_GRAMMAR.md` §7.7 forbids a ship hull from using it
# ("a ship hull at 1.0 reads as station plating"). The walked and structural
# surfaces here — decks, bulkheads, the airstair, the bow collar, the yoke —
# keep the registered 1.0, which is exactly where the station family belongs and
# what `scripts/world/jovian_freight_berth.gd` already does for surfaces the
# player stands on. The two *hull skin* materials keep the same registered maps,
# projection and UV recipe but drop `normal_scale` to HULL_NORMAL_SCALE, inside
# the fleet's 0.10-0.68 band, so the outside of the vessel does not read as a
# bulkhead. Nothing else about the recipe changes.
#
# The hull UV scale is the finest in the fleet (Torrent 0.17, Jovian 0.24, Arrow
# 0.34) because the Halyard's dominant mass is one very large uninterrupted
# pressure tube: at station frequency a 19 m flank carries about four panel
# features, which reads as a painted box rather than a plated hull.
const HULL_PANEL_UV_SCALE := 0.26
const STRUCTURE_PANEL_UV_SCALE := 0.30
const WALKED_PANEL_UV_SCALE := 0.22
const HULL_NORMAL_SCALE := 0.46
const HULL_CLEARCOAT := 0.30

# ---------------------------------------------------------------- layout ----
#
# One place to read the craft's dimensions. Ship-local, -Z forward, y = 0 is the
# ship root plane; the walkable deck surface is at y = 0.50 and the parked
# landing contact plane is at y = -1.30.
const DECK_SURFACE_Y := 0.50
## Parked contact plane. Set from the dock rather than from taste: Fleet Dock
## 02's slab surface is 1.08 m below the berth origin the world publishes, so
## this is the craft-local y at which its four feet actually meet the deck.
const LANDING_CONTACT_Y := -1.08
const HULL_HALF_WIDTH := 2.62
const TUBE_FORWARD_Z := -10.60
const TUBE_AFT_Z := 8.20
const BOW_RING_Z := -13.55
const BOW_RING_RADIUS := 2.45
const BOW_RING_CENTRE_Y := 1.85
## Shift applied to the whole inherited `CockpitInterior` / canopy hierarchy so
## the common cockpit lands on the Halyard's forward flight deck. The internal
## seat-anchor and camera offsets are never touched, which is what preserves the
## frozen fleet-wide 1.76 m feet-frame-to-eye-point rise
## (`SEAT_TO_COCKPIT_CAMERA_RISE` in `tests/fleet_role_differentiation_test.gd`).
const COCKPIT_SHIFT := Vector3(-0.70, -1.47, -11.55)
## Port hatch and airstair station, in craft-local z. See the note in
## `_build_flank_detail` for why this is a deck-driven number rather than a
## styling one.
const AIRSTAIR_Z := -4.80
## Transverse engine yoke station, clear aft of the pressure hull.
const TAIL_YOKE_Z := 11.20
const CREW_SEAT_ROWS: Array[float] = [-8.00, -5.40, -2.80]
const CREW_SEAT_HALF_SPACING := 1.30
const CABIN_WINDOW_COUNT := 10
const CABIN_WINDOW_FIRST_Z := -8.30
const CABIN_WINDOW_PITCH := 1.55

## Compact dorsal self-defence hardware. These dimensions remain below the
## Jovian freighter's 0.68 m base, 0.19 m barrel radius and 1.55 m barrel length:
## the Halyard owns the fleet's slowest cadence, so its weapon silhouette must
## read as the lightest defensive fit rather than as freight-scale armament.
const DEFENSIVE_MOUNT_BASE_RADIUS := 0.36
const DEFENSIVE_BARREL_RADIUS := 0.11
const DEFENSIVE_BARREL_LENGTH := 1.10
const DEFENSIVE_SHROUD_SIZE := Vector3(0.34, 0.28, 0.56)
const DEFENSIVE_COLLAR_RADIUS := 0.16
const DEFENSIVE_COLLAR_LENGTH := 0.14
const DEFENSIVE_LENS_RADIUS := 0.075
const DEFENSIVE_MUZZLE_POSITIONS := [
	Vector3(-1.75, 4.24, -7.65),
	Vector3(1.75, 4.24, -7.65),
]
const DEFENSIVE_VISUAL_PARTS_PER_MOUNT := 5

## Component-local render allocation freeze. The seven dorsal ribs are repeated,
## childless exterior trim: no collider, route, seat, boarding, propulsion,
## damage, weapon, audio, lifecycle or evidence contract names one of them. They
## retain one authored copy at each original transform, but share one renderer
## submission through a ship-local MultiMesh.
const SPINE_RIB_SIZE := Vector3(1.90, 0.22, 0.28)
const SPINE_RIB_COPY_COUNT := 7
const GEAR_DAMPER_RADIUS := 0.12
const GEAR_DAMPER_HEIGHT := 0.83
const GEAR_DAMPER_COPY_COUNT := 4
const RENDER_DESCENDANT_COUNT := 121
const RENDER_MESH_INSTANCE_COUNT := 112
const RENDER_MULTIMESH_BATCH_COUNT := 4
const RENDER_DRAWN_COPY_COUNT := 163
const RENDER_GEOMETRY_SUBMISSION_COUNT := 116
const RENDER_UNIQUE_MESH_RESOURCE_COUNT := 65
const RENDER_UNIQUE_MATERIAL_RESOURCE_COUNT := 14

var _halyard_built := false
var _halyard_visual: Node3D
var _halyard_materials: Dictionary = {}
var _box_mesh_cache: Dictionary = {}
var _walkable_interior: Node3D
var _crew_cabin: Node3D
var _aft_systems_bay: Node3D
var _moving_interior_component: MovingInteriorFrame
var _occupant_volume: Area3D
var _interior_access_marker: Marker3D
var _interior_deck_marker: Marker3D
var _interior_exit_marker: Marker3D
var _cabin_stand_marker: Marker3D
var _co_pilot_station_anchor: Marker3D
var _crew_seat_anchors: Array[Marker3D] = []
var _interior_occupant_count := 0
var _engine_plumes: Array[MeshInstance3D] = []
var _engine_cores: Array[MeshInstance3D] = []
var _halyard_engine_lights: Array[OmniLight3D] = []
var _elapsed_halyard := 0.0
var _spine_rib_mesh: Mesh
var _spine_rib_batch: MultiMeshInstance3D
var _spine_rib_transforms: Array[Transform3D] = []
var _crew_role_authority: CrewSeatRoleAuthority
var _crew_status_display: HalyardCrewStatusDisplay
var _loadmaster_station_sign: Label3D
var _loadmaster_station_sign_snapshot: Dictionary = {}
var _passenger_ping_cooldowns: Dictionary = {}
var _gunner_role_cooldowns: Dictionary = {}
var _passenger_ping_markers: Dictionary = {}
var _loadmaster_manifest_receipt: Dictionary = {}
var _loadmaster_manifest_generation := 1
var _gunner_target_selection: Dictionary = {}
var _gunner_target_generation := 1
var _engineer_component_selection: Dictionary = {}
var _engineer_component_generation := 1
var _pilot_command_source: HalyardPilotCommandSource
var _pilot_command_state: Dictionary = {}
var _pilot_last_request_sequence := -1
var _pilot_command_seat_generation := 0
var _emergency_pilot_handoff_state: Dictionary = {}
var _ship_perspective_audio_binding: RefCounted
var _loadmaster_audio_binding: RefCounted


func _uses_torrent_reconstruction_presentation() -> bool:
	return false


func _enter_tree() -> void:
	super._enter_tree()
	_clear_loadmaster_station_display(&"ship_attached")
	if _ship_perspective_audio_binding != null:
		call_deferred("_rebind_halyard_perspective_audio")
	if _loadmaster_audio_binding != null:
		call_deferred("_rebind_loadmaster_audio")


func _ready() -> void:
	super._ready()
	_ship_perspective_audio_binding = ShipPerspectiveAudioBindingType.new()
	_loadmaster_audio_binding = HalyardLoadmasterAudioBindingType.new()
	_loadmaster_audio_binding.attach()
	var perspective_result: Dictionary = _ship_perspective_audio_binding.bind(_ship_audio_rig)
	if bool(perspective_result.get("accepted", false)):
		camera_view_changed.connect(_on_halyard_camera_view_changed)
	else:
		_ship_perspective_audio_binding = null
	loadmaster_manifest_cleared.connect(_on_loadmaster_audio_cleared)
	if not _halyard_built:
		_halyard_built = rebuild_variant_presentation(_build_halyard_variant)
	if _halyard_built:
		_halyard_built = _reconfigure_component_damage_from_final_root_collision()
	_apply_halyard_metadata()
	_sync_halyard_engine_presentation_immediately()
	_build_loadmaster_station_display()


func _exit_tree() -> void:
	_clear_loadmaster_manifest(&"ship_detached")
	_clear_loadmaster_station_display(&"ship_detached")
	if _ship_perspective_audio_binding != null:
		if camera_view_changed.is_connected(_on_halyard_camera_view_changed):
			camera_view_changed.disconnect(_on_halyard_camera_view_changed)
		_ship_perspective_audio_binding.detach()
	if _loadmaster_audio_binding != null:
		if loadmaster_manifest_cleared.is_connected(_on_loadmaster_audio_cleared):
			loadmaster_manifest_cleared.disconnect(_on_loadmaster_audio_cleared)
		_loadmaster_audio_binding.detach()
	super._exit_tree()


func _rebind_halyard_perspective_audio() -> void:
	if not is_inside_tree() or _ship_perspective_audio_binding == null \
			or _ship_audio_rig == null or not is_instance_valid(_ship_audio_rig):
		return
	var snapshot: Dictionary = _ship_perspective_audio_binding.get_snapshot()
	if bool(snapshot.get("attached", false)):
		return
	var result: Dictionary = _ship_perspective_audio_binding.bind(_ship_audio_rig)
	if bool(result.get("accepted", false)) \
			and not camera_view_changed.is_connected(_on_halyard_camera_view_changed):
		camera_view_changed.connect(_on_halyard_camera_view_changed)


func _on_halyard_camera_view_changed(view: StringName) -> void:
	if _ship_perspective_audio_binding == null:
		return
	var perspective: StringName = (
		&"cockpit" if view == CAMERA_VIEW_COCKPIT else &"exterior"
	)
	var generation := int(_ship_perspective_audio_binding.get_snapshot().get("generation", -1))
	_ship_perspective_audio_binding.present_perspective(perspective, generation)
	if _loadmaster_audio_binding != null:
		_loadmaster_audio_binding.present_perspective(&"cockpit" if perspective == &"cockpit" else &"cabin")


func _rebind_loadmaster_audio() -> void:
	if not is_inside_tree() or _loadmaster_audio_binding == null:
		return
	var snapshot: Dictionary = _loadmaster_audio_binding.get_snapshot()
	if not bool(snapshot.get("attached", false)):
		_loadmaster_audio_binding.attach(int(snapshot.get("generation", 0)))
	_on_halyard_camera_view_changed(get_camera_view())


func _on_loadmaster_audio_cleared(generation: int, reason: StringName) -> void:
	if _loadmaster_audio_binding != null:
		_loadmaster_audio_binding.present_cleared(generation, reason)


func get_loadmaster_audio_snapshot() -> Dictionary:
	return _loadmaster_audio_binding.get_snapshot() \
		if _loadmaster_audio_binding != null else {"attached": false}


func _present_loadmaster_result(result: Dictionary) -> void:
	if _loadmaster_audio_binding == null:
		return
	if bool(result.get("accepted", false)):
		var effect := result.get("effect", {}) as Dictionary
		var receipt := effect.get("receipt", {}) as Dictionary
		if not receipt.is_empty():
			_loadmaster_audio_binding.present_accepted_receipt(receipt)
	else:
		_loadmaster_audio_binding.present_rejected_result(result)


func get_ship_perspective_audio_snapshot() -> Dictionary:
	return _ship_perspective_audio_binding.get_snapshot() \
		if _ship_perspective_audio_binding != null else {"attached": false}


func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	if _reset_for_reuse_mutation_blocked():
		return
	_advance_crew_role_cooldowns(maxf(delta, 0.0))
	_cleanup_detached_passenger_pings()
	_elapsed_halyard += delta
	_update_halyard_presentation(delta)


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
		_set_interior_operational(false)


func _preflight_variant_reset_for_reuse(spawn_transform: Transform3D) -> Dictionary:
	return super._preflight_variant_reset_for_reuse(spawn_transform)


func _commit_variant_reset_for_reuse(context: Dictionary) -> void:
	super._commit_variant_reset_for_reuse(context)
	if _crew_status_display != null and is_instance_valid(_crew_status_display):
		_crew_status_display.clear_for_detach()
	_clear_passenger_ping_markers(&"ship_reused")
	_clear_loadmaster_manifest(&"ship_reused", false)
	_clear_loadmaster_station_display(&"ship_reused")
	_loadmaster_manifest_generation = 1
	_passenger_ping_cooldowns.clear()
	_gunner_role_cooldowns.clear()
	_clear_gunner_target_selection(&"ship_reused", false)
	_gunner_target_generation = 1
	_clear_engineer_component_selection(&"ship_reused", false)
	_engineer_component_generation = 1
	_clear_pilot_command(&"ship_reused")
	_pilot_last_request_sequence = -1
	_pilot_command_seat_generation = 0
	_set_interior_operational(true)
	if _moving_interior_component != null:
		_moving_interior_component.configure(self, INTERIOR_BOUNDS, _occupant_volume)
		_moving_interior_component.reset_frame_tracking(true)
	refresh_crew_status_display()


# ------------------------------------------------------------- contracts ----


func get_halyard_visual_root() -> Node3D:
	return _halyard_visual


## Stable local combat registry identity for this craft. The shared combat
## authority remains the owner of actual registration.
func get_combat_source_id() -> int:
	return COMBAT_SOURCE_ID


## Binds the session-owned seat/role authority to this physical Halyard. The
## Halyard never creates a second seat ledger: claims, generations, and intent
## sequencing remain in the injected authority, while this ship only consumes
## receipts that its own component owner can apply.
func attach_crew_role_authority(authority: CrewSeatRoleAuthority) -> Dictionary:
	if authority == null:
		return _crew_role_result(false, &"authority_unavailable")
	if _crew_role_authority != null and _crew_role_authority != authority:
		return _crew_role_result(false, &"authority_already_attached")
	var snapshot := authority.get_snapshot()
	if not bool(snapshot.get("roster_sealed", false)):
		return _crew_role_result(false, &"roster_not_sealed")
	var seats: Array = snapshot.get("seats", []) as Array
	if seats.size() != CrewSeatRoleAuthorityType.get_halyard_roster().size():
		return _crew_role_result(false, &"halyard_roster_mismatch")
	for seat_variant in seats:
		if not seat_variant is Dictionary:
			return _crew_role_result(false, &"halyard_roster_mismatch")
		var seat := seat_variant as Dictionary
		if StringName(seat.get("vessel_id", &"")) != &"halyard_new_design" \
				or StringName(seat.get("frame_id", &"")) != &"halyard_walkable_interior":
			return _crew_role_result(false, &"halyard_roster_mismatch")
	_crew_role_authority = authority
	refresh_crew_status_display()
	var result := _crew_role_result(true, &"authority_attached")
	result["role_count"] = seats.size()
	return result


func get_crew_role_authority() -> CrewSeatRoleAuthority:
	return _crew_role_authority


## Explicit presentation refresh from one detached gameplay snapshot. This is
## caller-driven and never polls authority or gameplay state.
func refresh_crew_status_display() -> Dictionary:
	if _crew_status_display == null or not is_instance_valid(_crew_status_display):
		return {}
	var snapshot := get_crew_role_gameplay_snapshot()
	var display_snapshot := _crew_status_display.present_crew_snapshot(snapshot)
	_present_loadmaster_station_snapshot(snapshot.get("loadmaster_manifest", {}))
	return display_snapshot


func get_crew_status_display() -> HalyardCrewStatusDisplay:
	return _crew_status_display


func get_loadmaster_station_display_snapshot() -> Dictionary:
	return _loadmaster_station_sign_snapshot.duplicate(true)


func get_loadmaster_station_display_readout() -> String:
	return _loadmaster_station_sign.text if is_instance_valid(_loadmaster_station_sign) else ""


## Builds one presentation-only sign outside the authored visual root. Keeping
## it on the ship root preserves the frozen Halyard mesh/collision budgets while
## the sign still follows the physical cabin seat through the moving hull.
func _build_loadmaster_station_display() -> void:
	if is_instance_valid(_loadmaster_station_sign):
		_position_loadmaster_station_display()
		return
	_loadmaster_station_sign = Label3D.new()
	_loadmaster_station_sign.name = "LoadmasterStationSign"
	_loadmaster_station_sign.font_size = 24
	_loadmaster_station_sign.pixel_size = 0.0012
	_loadmaster_station_sign.modulate = Color("b9f1d0")
	_loadmaster_station_sign.outline_modulate = Color("07111d")
	_loadmaster_station_sign.outline_size = 8
	_loadmaster_station_sign.no_depth_test = true
	_loadmaster_station_sign.set_meta("presentation_only", true)
	_loadmaster_station_sign.set_meta("seat_id", LOADMASTER_STATION_SEAT_ID)
	_loadmaster_station_sign.set_meta("route_id", &"crew_cabin_port_row_00")
	add_child(_loadmaster_station_sign)
	_position_loadmaster_station_display()
	_clear_loadmaster_station_display(&"display_ready")


func _position_loadmaster_station_display() -> void:
	if not is_instance_valid(_loadmaster_station_sign):
		return
	var anchor := get_loadmaster_station_anchor()
	if not is_instance_valid(anchor):
		_loadmaster_station_sign.visible = false
		return
	_loadmaster_station_sign.global_position = anchor.global_position \
			+ anchor.global_basis * Vector3(0.0, 0.86, -0.42)
	_loadmaster_station_sign.global_rotation = anchor.global_rotation
	_loadmaster_station_sign.visible = true


func _present_loadmaster_station_snapshot(source: Variant) -> void:
	if not source is Dictionary:
		_clear_loadmaster_station_display(&"invalid_snapshot")
		return
	var detached := source as Dictionary
	var receipt := detached.get("receipt", {}) as Dictionary
	var state := &"standby"
	var manifest_id := &""
	var route_id := &""
	var ready := false
	var generation := int(detached.get("manifest_generation", 0))
	if not receipt.is_empty():
		manifest_id = StringName(receipt.get("manifest_id", &""))
		route_id = StringName(receipt.get("route_id", &""))
		ready = bool(receipt.get("ready", false))
		state = &"ready" if ready else &"blocked"
	_loadmaster_station_sign_snapshot = {
		"schema_version": 1,
		"seat_id": LOADMASTER_STATION_SEAT_ID,
		"route_id": route_id,
		"manifest_id": manifest_id,
		"manifest_generation": generation,
		"state": state,
		"ready": ready,
		"presentation_only": true,
		"cargo_transfer_authority": false,
		"inventory_mutation_authority": false,
		"reward_authority": false,
		"helm_authority": false,
	}.duplicate(true)
	if is_instance_valid(_loadmaster_station_sign):
		_loadmaster_station_sign.text = (
			"LOADMASTER\n[%s]\nMANIFEST %s\nROUTE %s"
			% [str(state).to_upper(), str(manifest_id) if not manifest_id.is_empty() else "--", str(route_id) if not route_id.is_empty() else "--"]
		)
		_position_loadmaster_station_display()


func _clear_loadmaster_station_display(reason: StringName) -> void:
	_loadmaster_station_sign_snapshot = {
		"schema_version": 1,
		"seat_id": LOADMASTER_STATION_SEAT_ID,
		"route_id": &"",
		"manifest_id": &"",
		"manifest_generation": _loadmaster_manifest_generation,
		"state": &"standby",
		"ready": false,
		"reason": reason,
		"presentation_only": true,
		"cargo_transfer_authority": false,
		"inventory_mutation_authority": false,
		"reward_authority": false,
		"helm_authority": false,
	}.duplicate(true)
	if is_instance_valid(_loadmaster_station_sign):
		_loadmaster_station_sign.text = "LOADMASTER\n[STANDBY]\nMANIFEST --\nROUTE --"
		_loadmaster_station_sign.visible = is_inside_tree()


## Server-only bridge for the network session's already-admitted role receipt.
## The Halyard authority remains the final physical roster gate.
func admit_network_crew_role(
	occupant_peer_id: int,
	peer_generation: int,
	avatar_id: StringName,
	seat_id: StringName,
	role: StringName,
	seat_generation: int,
	request_sequence: int
) -> Dictionary:
	if peer_generation <= 0 or seat_generation <= 0 or request_sequence <= 0:
		return _crew_role_result(false, &"invalid_network_generation")
	if _crew_role_authority == null:
		return _crew_role_result(false, &"authority_unavailable")
	var assignment := _crew_role_authority.get_assignment(occupant_peer_id, avatar_id)
	if not assignment.is_empty():
		if StringName(assignment.get("seat_id", &"")) != seat_id \
				or StringName(assignment.get("role", &"")) != role:
			return _crew_role_result(false, &"network_seat_mismatch")
		var already := _crew_role_result(true, &"network_role_already_admitted")
		already["assignment"] = assignment.duplicate(true)
		return already
	var authority_snapshot := _crew_role_authority.get_snapshot()
	var authority_peer_id := int(authority_snapshot.get("authority_peer_id", 1))
	var result := _crew_role_authority.claim(
		authority_peer_id, occupant_peer_id, avatar_id, seat_id, role, request_sequence
	)
	if bool(result.get("accepted", false)):
		refresh_crew_status_display()
	return result


func release_network_crew_role(
	occupant_peer_id: int,
	peer_generation: int,
	avatar_id: StringName,
	seat_id: StringName,
	seat_generation: int,
	request_sequence: int
) -> Dictionary:
	if _crew_role_authority == null:
		return _crew_role_result(false, &"authority_unavailable")
	var assignment := _crew_role_authority.get_assignment(occupant_peer_id, avatar_id)
	if assignment.is_empty():
		return _crew_role_result(true, &"network_role_already_released")
	if peer_generation <= 0 or StringName(assignment.get("seat_id", &"")) != seat_id \
			or int(assignment.get("seat_generation", 0)) != seat_generation:
		return _crew_role_result(false, &"network_seat_mismatch")
	var authority_peer_id := int(_crew_role_authority.get_snapshot().get("authority_peer_id", 1))
	var result := _crew_role_authority.release(
		authority_peer_id, occupant_peer_id, avatar_id, seat_id, request_sequence, seat_generation
	)
	if bool(result.get("accepted", false)):
		refresh_crew_status_display()
	return result


## Returns the detached pilot receipt currently held by the Halyard command
## source. The command source itself remains private to HeroShip's seam.
func get_crew_pilot_command_state() -> Dictionary:
	return _pilot_command_state.duplicate(true)


## Admits and immediately consumes the currently implemented Halyard role
## actions: pilot flight, engineer repair, gunner weapon, and passenger ping. Admission is
## server-owned by
## CrewSeatRoleAuthority; mutation is still owner-owned by ShipComponentDamage.
## Other role actions are intentionally left to their downstream authorities.
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
	var role := StringName(assignment.get("role", &""))
	var is_loadmaster_manifest := role == CrewRoleGameplayProfileType.ROLE_PASSENGER \
			and StringName(assignment.get("seat_id", &"")) == LOADMASTER_STATION_SEAT_ID \
			and action == CrewRoleGameplayProfileType.ACTION_PASSENGER_CARGO_MANIFEST
	var supported := (
		role == CrewRoleGameplayProfileType.ROLE_PILOT
			and action == CrewRoleGameplayProfileType.ACTION_FLIGHT_COMMAND
	) or (
		role == CrewRoleGameplayProfileType.ROLE_ENGINEER
			and action == CrewRoleGameplayProfileType.ACTION_ENGINEER_REPAIR
	) or (
		role == CrewRoleGameplayProfileType.ROLE_GUNNER
			and action == CrewRoleGameplayProfileType.ACTION_GUNNER_FIRE
	) or (
		role == CrewRoleGameplayProfileType.ROLE_PASSENGER
			and action == CrewRoleGameplayProfileType.ACTION_PASSENGER_PING
	) or is_loadmaster_manifest
	if not supported:
		if is_loadmaster_manifest:
			_present_loadmaster_result(_crew_role_result(false, &"unsupported_halyard_role_action"))
		return _crew_role_result(false, &"unsupported_halyard_role_action")
	var admission := _crew_role_authority.submit_intent(
		source_peer_id,
		occupant_peer_id,
		avatar_id,
		action,
		payload,
		request_sequence
	)
	if not bool(admission.get("accepted", false)):
		if is_loadmaster_manifest:
			_present_loadmaster_result(admission)
		return admission
	var intent := admission.get("intent", {}) as Dictionary
	var effect := (
		_consume_pilot_flight_intent(intent)
		if role == CrewRoleGameplayProfileType.ROLE_PILOT
		else (
			_consume_engineer_repair_intent(intent)
			if role == CrewRoleGameplayProfileType.ROLE_ENGINEER
			else (
				_consume_gunner_fire_intent(intent)
				if role == CrewRoleGameplayProfileType.ROLE_GUNNER
				else (
					_consume_loadmaster_manifest_intent(intent)
					if is_loadmaster_manifest
					else _consume_passenger_ping_intent(intent)
				)
			)
		)
	)
	var result := admission.duplicate(true)
	result["status"] = &"intent_consumed" if bool(effect.get("accepted", false)) else &"intent_effect_rejected"
	result["consumed"] = bool(effect.get("accepted", false))
	result["effect"] = effect
	if is_loadmaster_manifest:
		_present_loadmaster_result(result)
	refresh_crew_status_display()
	return result


func _consume_pilot_flight_intent(intent: Dictionary) -> Dictionary:
	var payload := intent.get("payload", {}) as Dictionary
	var request_sequence := int(intent.get("request_sequence", -1))
	var seat_generation := int(intent.get("seat_generation", 0))
	var occupant_peer_id := int(intent.get("occupant_peer_id", 0))
	var avatar_id := StringName(intent.get("avatar_id", &""))
	if seat_generation <= 0:
		return _crew_role_result(false, &"invalid_pilot_generation")
	if not _pilot_command_state.is_empty():
		var current_peer_id := int(_pilot_command_state.get("occupant_peer_id", 0))
		var current_avatar_id := StringName(_pilot_command_state.get("avatar_id", &""))
		if current_peer_id != occupant_peer_id or current_avatar_id != avatar_id:
			return _crew_role_result(false, &"pilot_authority_busy")
		if seat_generation != _pilot_command_seat_generation:
			return _crew_role_result(false, &"stale_pilot_generation")
		if request_sequence <= _pilot_last_request_sequence:
			return _crew_role_result(false, &"stale_pilot_sequence")
	var telemetry := get_telemetry()
	if bool(telemetry.get("destroyed", false)):
		return _crew_role_result(false, &"ship_destroyed")
	if bool(telemetry.get("landing_active", false)):
		return _crew_role_result(false, &"pilot_blocked_during_landing")
	if _pilot_command_source == null or not is_instance_valid(_pilot_command_source):
		_pilot_command_source = HalyardPilotCommandSource.new()
		add_child(_pilot_command_source)
		var authority_snapshot := _crew_role_authority.get_snapshot()
		var authority_peer_id := int(authority_snapshot.get("authority_peer_id", 1))
		_pilot_command_source.set_authority_peer_id(authority_peer_id)
		_pilot_command_source.set_local_peer_id_override(authority_peer_id)
	if not _piloted:
		set_piloted(true)
	if get_command_source() != _pilot_command_source:
		set_command_source(_pilot_command_source)
	_pilot_command_source.set_held_controls(payload)
	_pilot_command_state = {
		"occupant_peer_id": occupant_peer_id,
		"avatar_id": avatar_id,
		"seat_generation": seat_generation,
		"request_sequence": request_sequence,
		"command": payload.duplicate(true),
	}
	_pilot_command_seat_generation = seat_generation
	_pilot_last_request_sequence = request_sequence
	var result := _crew_role_result(true, &"pilot_command_applied")
	result["command"] = payload.duplicate(true)
	result["seat_generation"] = seat_generation
	result["request_sequence"] = request_sequence
	return result


## Binds one already-authorized non-pilot role to the existing moving-interior
## coordinator. The role authority owns the claim; MovingInteriorFrame owns the
## physical registration, so this method creates no second occupancy ledger.
func attach_crew_role_occupant(
	occupant_peer_id: int,
	avatar_id: StringName,
	seat_id: StringName,
	occupant: Node3D,
	options: Dictionary = {}
) -> Dictionary:
	if _crew_role_authority == null:
		return _crew_role_result(false, &"authority_unavailable")
	var assignment := _crew_role_authority.get_assignment(occupant_peer_id, avatar_id)
	if assignment.is_empty():
		return _crew_role_result(false, &"assignment_not_found")
	if StringName(assignment.get("seat_id", &"")) != seat_id:
		return _crew_role_result(false, &"seat_mismatch")
	if StringName(assignment.get("role", &"")) == CrewRoleGameplayProfileType.ROLE_PILOT:
		return _crew_role_result(false, &"pilot_occupancy_reserved")
	if not is_instance_valid(occupant) or not occupant.is_inside_tree():
		return _crew_role_result(false, &"invalid_occupant")
	if _moving_interior_component == null or not is_instance_valid(_moving_interior_component):
		return _crew_role_result(false, &"moving_interior_unavailable")
	if _moving_interior_component.is_occupant_registered(occupant):
		if not occupant.has_meta(HALYARD_CREW_ROLE_OCCUPANT_META):
			return _crew_role_result(false, &"occupancy_already_owned")
		var existing_metadata := occupant.get_meta(HALYARD_CREW_ROLE_OCCUPANT_META, {}) as Dictionary
		if int(existing_metadata.get("occupant_peer_id", 0)) != occupant_peer_id \
				or StringName(existing_metadata.get("avatar_id", &"")) != avatar_id \
				or StringName(existing_metadata.get("seat_id", &"")) != seat_id:
			return _crew_role_result(false, &"occupancy_identity_mismatch")
		var already := _crew_role_result(true, &"already_registered")
		already["assignment"] = assignment.duplicate(true)
		return already
	var registration_options := options.duplicate(true)
	registration_options["registration_source"] = &"crew_role_seat"
	var registration := _moving_interior_component.register_occupant(occupant, registration_options)
	if not bool(registration.get("registered", false)):
		return registration
	occupant.set_meta(HALYARD_CREW_ROLE_OCCUPANT_META, {
		"occupant_peer_id": occupant_peer_id,
		"avatar_id": avatar_id,
		"seat_id": seat_id,
		"seat_generation": int(assignment.get("seat_generation", 0)),
		"role": StringName(assignment.get("role", &"")),
	})
	var result := _crew_role_result(true, StringName(registration.get("status", &"registered")))
	result["assignment"] = assignment.duplicate(true)
	result["registration"] = registration.duplicate(true)
	refresh_crew_status_display()
	return result


## Releases the physical registration and then the matching server-owned seat.
## A caller that already released the authority claim cannot accidentally clear
## another occupant: the metadata and exact seat/assignment checks fail closed.
func release_crew_role_occupant(
	source_peer_id: int,
	occupant_peer_id: int,
	avatar_id: StringName,
	seat_id: StringName,
	occupant: Node3D,
	request_sequence: int,
	seat_generation: int = 0,
	inherit_velocity: bool = false
) -> Dictionary:
	if _crew_role_authority == null:
		return _crew_role_result(false, &"authority_unavailable")
	if not is_instance_valid(occupant):
		return _crew_role_result(false, &"invalid_occupant")
	if _moving_interior_component == null \
			or not _moving_interior_component.is_occupant_registered(occupant):
		return _crew_role_result(false, &"occupancy_not_registered")
	var metadata := occupant.get_meta(HALYARD_CREW_ROLE_OCCUPANT_META, {}) as Dictionary
	if int(metadata.get("occupant_peer_id", 0)) != occupant_peer_id \
			or StringName(metadata.get("avatar_id", &"")) != avatar_id \
			or StringName(metadata.get("seat_id", &"")) != seat_id:
		return _crew_role_result(false, &"occupancy_identity_mismatch")
	var assignment := _crew_role_authority.get_assignment(occupant_peer_id, avatar_id)
	if assignment.is_empty() or StringName(assignment.get("seat_id", &"")) != seat_id:
		return _crew_role_result(false, &"assignment_not_found")
	var release := _crew_role_authority.release(
		source_peer_id,
		occupant_peer_id,
		avatar_id,
		seat_id,
		request_sequence,
		seat_generation
	)
	if not bool(release.get("accepted", false)):
		return release
	var unregistration := _moving_interior_component.unregister_occupant(
		occupant,
		inherit_velocity,
		&"crew_role_released"
	)
	occupant.remove_meta(HALYARD_CREW_ROLE_OCCUPANT_META)
	_clear_crew_role_state(occupant_peer_id, avatar_id, &"role_released")
	var result := release.duplicate(true)
	result["occupancy"] = unregistration.duplicate(true)
	refresh_crew_status_display()
	return result


func _release_tagged_crew_role_occupants(
	occupant_peer_id: int,
	avatar_id: StringName,
	reason: StringName
) -> void:
	if _moving_interior_component == null or not is_instance_valid(_moving_interior_component):
		return
	for occupant in _moving_interior_component.get_registered_occupants():
		if not occupant.has_meta(HALYARD_CREW_ROLE_OCCUPANT_META):
			continue
		var metadata := occupant.get_meta(HALYARD_CREW_ROLE_OCCUPANT_META, {}) as Dictionary
		if int(metadata.get("occupant_peer_id", 0)) != occupant_peer_id \
				or StringName(metadata.get("avatar_id", &"")) != avatar_id:
			continue
		_moving_interior_component.unregister_occupant(occupant, false, reason)
		occupant.remove_meta(HALYARD_CREW_ROLE_OCCUPANT_META)


## Releases a session assignment through the same authority that owns the claim,
## then lets the ship clear any passenger markers owned by that avatar. Calling
## the authority directly remains safe: the physics cleanup pass observes the
## missing assignment and performs the same detach cleanup.
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
		_clear_crew_role_state(occupant_peer_id, avatar_id, &"role_released")
		_release_tagged_crew_role_occupants(occupant_peer_id, avatar_id, &"role_released")
		refresh_crew_status_display()
	return result


## Swaps one physical seat through the session authority's atomic handoff
## receipt, then clears only the outgoing avatar's ship-local role state.
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
		_clear_emergency_pilot_handoff_state()
		_clear_crew_role_state(
			previous_occupant_peer_id,
			previous_avatar_id,
			&"role_handoff"
		)
		_release_tagged_crew_role_occupants(
			previous_occupant_peer_id,
			previous_avatar_id,
			&"role_handoff"
		)
		refresh_crew_status_display()
	return result


## Explicit emergency command transfer for a disconnected pilot. This is a
## caller-invoked release/claim transaction over the existing authority; it
## never watches for a disconnect or promotes a crew member automatically.
## The admitted non-pilot keeps its MovingInteriorFrame registration while its
## seat assignment changes, so the physical occupant does not blink out of the
## cabin during the authority transition.
func request_emergency_pilot_handoff(
		source_peer_id: int,
		new_occupant_peer_id: int,
		new_avatar_id: StringName,
		new_seat_id: StringName,
		release_request_sequence: int,
		claim_request_sequence: int,
		occupant: Node3D,
		seat_generation: int = 0
) -> Dictionary:
	if _crew_role_authority == null:
		return _crew_role_result(false, &"authority_unavailable")
	if not is_instance_valid(occupant) or not occupant.is_inside_tree():
		return _crew_role_result(false, &"invalid_occupant")
	var assignment := _crew_role_authority.get_assignment(new_occupant_peer_id, new_avatar_id)
	if assignment.is_empty():
		return _crew_role_result(false, &"assignment_not_found")
	if StringName(assignment.get("seat_id", &"")) != new_seat_id:
		return _crew_role_result(false, &"seat_mismatch")
	if StringName(assignment.get("role", &"")) == CrewRoleGameplayProfileType.ROLE_PILOT:
		return _crew_role_result(false, &"pilot_assignment_already_present")
	if release_request_sequence < 0 or claim_request_sequence <= release_request_sequence:
		return _crew_role_result(false, &"invalid_handoff_sequence")
	var last_intent := _crew_role_authority.get_last_intent(new_occupant_peer_id, new_avatar_id)
	if not last_intent.is_empty() \
			and claim_request_sequence <= int(last_intent.get("request_sequence", -1)):
		return _crew_role_result(false, &"stale_request_sequence")
	if _moving_interior_component == null \
			or not _moving_interior_component.is_occupant_registered(occupant):
		return _crew_role_result(false, &"occupancy_not_registered")
	var metadata := occupant.get_meta(HALYARD_CREW_ROLE_OCCUPANT_META, {}) as Dictionary
	if int(metadata.get("occupant_peer_id", 0)) != new_occupant_peer_id \
			or StringName(metadata.get("avatar_id", &"")) != new_avatar_id \
			or StringName(metadata.get("seat_id", &"")) != new_seat_id:
		return _crew_role_result(false, &"occupancy_identity_mismatch")
	var authority_snapshot := _crew_role_authority.get_snapshot()
	for assignment_variant in authority_snapshot.get("assignments", []) as Array:
		var live_assignment := assignment_variant as Dictionary
		if StringName(live_assignment.get("role", &"")) == CrewRoleGameplayProfileType.ROLE_PILOT:
			return _crew_role_result(false, &"pilot_assignment_still_present")
	var pilot_seat_found := false
	var pilot_seat_occupied := false
	for seat_variant in authority_snapshot.get("seats", []) as Array:
		var seat := seat_variant as Dictionary
		if StringName(seat.get("seat_id", &"")) != &"pilot_station":
			continue
		pilot_seat_found = true
		if int(seat.get("seat_generation", 0)) != int(assignment.get("seat_generation", 0)) \
				and seat_generation > 0:
			return _crew_role_result(false, &"stale_seat_generation")
		break
	if not pilot_seat_found:
		return _crew_role_result(false, &"pilot_seat_unavailable")
	for assignment_variant in authority_snapshot.get("assignments", []) as Array:
		var live_assignment := assignment_variant as Dictionary
		if StringName(live_assignment.get("seat_id", &"")) == &"pilot_station":
			pilot_seat_occupied = true
			break
	if pilot_seat_occupied:
		return _crew_role_result(false, &"pilot_seat_occupied")
	# A released pilot may still have one physics tick of held state. Neutralize
	# it before the explicit replacement can submit a fresh command sequence.
	_clear_pilot_command(&"emergency_handoff")
	var release := _crew_role_authority.release(
		source_peer_id,
		new_occupant_peer_id,
		new_avatar_id,
		new_seat_id,
		release_request_sequence,
		seat_generation
	)
	if not bool(release.get("accepted", false)):
		return release
	var claim := _crew_role_authority.claim(
		source_peer_id,
		new_occupant_peer_id,
		new_avatar_id,
		&"pilot_station",
		CrewRoleGameplayProfileType.ROLE_PILOT,
		claim_request_sequence
	)
	if not bool(claim.get("accepted", false)):
		return claim
	var pilot_assignment := claim.get("assignment", {}) as Dictionary
	_clear_crew_role_state(new_occupant_peer_id, new_avatar_id, &"emergency_handoff")
	_emergency_pilot_handoff_state = {
		"status": &"completed",
		"previous_role": StringName(assignment.get("role", &"")),
		"new_role": CrewRoleGameplayProfileType.ROLE_PILOT,
		"previous_seat_generation": int(assignment.get("seat_generation", 0)),
		"new_seat_generation": int(pilot_assignment.get("seat_generation", 0)),
		"release_request_sequence": release_request_sequence,
		"claim_request_sequence": claim_request_sequence,
		"occupant_peer_id": new_occupant_peer_id,
		"avatar_id": new_avatar_id,
		"neutral_command_confirmed": _pilot_command_state.is_empty() and not _piloted,
	}
	occupant.set_meta(HALYARD_CREW_ROLE_OCCUPANT_META, {
		"occupant_peer_id": new_occupant_peer_id,
		"avatar_id": new_avatar_id,
		"seat_id": &"pilot_station",
		"seat_generation": int(pilot_assignment.get("seat_generation", 0)),
		"role": CrewRoleGameplayProfileType.ROLE_PILOT,
	})
	var result := claim.duplicate(true)
	result["status"] = &"emergency_pilot_handoff"
	result["released_assignment"] = release.get("assignment", {}).duplicate(true)
	result["occupancy_preserved"] = true
	result["pilot_assignment"] = pilot_assignment.duplicate(true)
	refresh_crew_status_display()
	return result


func get_passenger_ping_markers() -> Array[Dictionary]:
	var markers: Array[Dictionary] = []
	for marker_variant in _passenger_ping_markers.values():
		markers.append((marker_variant as Dictionary).duplicate(true))
	markers.sort_custom(func(left: Dictionary, right: Dictionary) -> bool:
		return str(left.get("marker_id", "")) < str(right.get("marker_id", ""))
	)
	return markers


## The fallback loadmaster station is a real passenger seat in the Halyard's
## authored cabin. It is intentionally not a second seat ledger or a cargo
## transfer terminal.
func get_loadmaster_station_anchor() -> Marker3D:
	for anchor in _crew_seat_anchors:
		if StringName(anchor.get_meta("seat_id", &"")) == LOADMASTER_STATION_SEAT_ID:
			return anchor
	return null


## Returns only caller-owned manifest/readiness evidence. Inventory, reward,
## cargo movement, and berth authority remain outside this role.
func get_loadmaster_manifest_snapshot() -> Dictionary:
	return {
		"schema_version": 1,
		"station_seat_id": LOADMASTER_STATION_SEAT_ID,
		"station_present": is_instance_valid(get_loadmaster_station_anchor()),
		"manifest_generation": _loadmaster_manifest_generation,
		"receipt": _loadmaster_manifest_receipt.duplicate(true),
		"cargo_transfer_authority": false,
		"inventory_mutation_authority": false,
		"reward_authority": false,
		"helm_authority": false,
	}.duplicate(true)


## Detached occupancy/gameplay view for downstream network and HUD consumers.
## The authority remains the owner of claims and generations; this method only
## copies its current assignments and Halyard-local role receipts. It returns
## no Nodes, authority objects, or mutable ship-owned dictionaries.
func get_crew_role_gameplay_snapshot() -> Dictionary:
	var role_occupancy := {}
	for role in CrewRoleGameplayProfileType.ROLES:
		role_occupancy[role] = []
	var snapshot := {
		"schema_version": CREW_ROLE_GAMEPLAY_SNAPSHOT_SCHEMA_VERSION,
		"authority_attached": _crew_role_authority != null,
		"authority_event_sequence": -1,
		"occupants": [],
		"role_occupancy": role_occupancy,
		"selected_targets": {"gunner": {}, "engineer": {}},
		"active_markers": [],
		"loadmaster_manifest": get_loadmaster_manifest_snapshot(),
		"power_routing": {
			"engineer": {},
			"effective_outputs": {
				"mobility_multiplier": 1.0,
				"fire_multiplier": 1.0,
				"targeting_multiplier": 1.0,
			},
		},
		"departure_readiness": {
			"pilot_required": true,
			"pilot_present": false,
			"pilot_seat_generation": 0,
			"ready": false,
			"optional_crew_count": 0,
			"optional_roles": {
				CrewRoleGameplayProfileType.ROLE_GUNNER: {"occupied": false, "seat_generation": 0},
				CrewRoleGameplayProfileType.ROLE_ENGINEER: {"occupied": false, "seat_generation": 0},
				CrewRoleGameplayProfileType.ROLE_PASSENGER: {"occupied": false, "seat_generation": 0},
			},
			"authority_event_sequence": -1,
		},
		"emergency_pilot_handoff": {},
	}
	if _crew_role_authority == null:
		return snapshot
	var authority_snapshot := _crew_role_authority.get_snapshot()
	snapshot["authority_event_sequence"] = int(authority_snapshot.get("event_sequence", -1))
	(snapshot["departure_readiness"] as Dictionary)["authority_event_sequence"] = int(
		authority_snapshot.get("event_sequence", -1)
	)
	var live_assignments: Array = authority_snapshot.get("assignments", []) as Array
	var live_actors := {}
	var departure_readiness := snapshot["departure_readiness"] as Dictionary
	var optional_roles := departure_readiness["optional_roles"] as Dictionary
	for assignment_variant in live_assignments:
		if not assignment_variant is Dictionary:
			continue
		var assignment := assignment_variant as Dictionary
		var role := StringName(assignment.get("role", &""))
		if not role_occupancy.has(role):
			continue
		var occupant_peer_id := int(assignment.get("occupant_peer_id", 0))
		var avatar_id := StringName(assignment.get("avatar_id", &""))
		var actor_key := _crew_role_actor_key_from_values(occupant_peer_id, avatar_id)
		live_actors[actor_key] = {"role": role, "assignment": assignment}
		var seat_generation := int(assignment.get("seat_generation", 0))
		if role == CrewRoleGameplayProfileType.ROLE_PILOT:
			departure_readiness["pilot_present"] = true
			departure_readiness["pilot_seat_generation"] = seat_generation
		elif optional_roles.has(role):
			var optional_role := optional_roles[role] as Dictionary
			optional_role["occupied"] = true
			optional_role["seat_generation"] = seat_generation
			optional_role["occupant_peer_id"] = occupant_peer_id
			optional_role["avatar_id"] = avatar_id
		var cooldown_remaining := 0.0
		if role == CrewRoleGameplayProfileType.ROLE_GUNNER:
			cooldown_remaining = maxf(0.0, float(_gunner_role_cooldowns.get(actor_key, 0.0)))
		elif role == CrewRoleGameplayProfileType.ROLE_PASSENGER:
			cooldown_remaining = maxf(0.0, float(_passenger_ping_cooldowns.get(actor_key, 0.0)))
		var occupant := {
			"occupant_peer_id": occupant_peer_id,
			"avatar_id": avatar_id,
			"seat_id": StringName(assignment.get("seat_id", &"")),
			"role": role,
			"seat_generation": int(assignment.get("seat_generation", 0)),
			"capabilities": (assignment.get("capabilities", []) as Array).duplicate(true),
			"cooldown_remaining": cooldown_remaining,
			"cooldown_ready": cooldown_remaining <= 0.0,
			"selected_target": {},
			"active_marker": {},
		}
		if role == CrewRoleGameplayProfileType.ROLE_GUNNER \
				and _crew_role_state_matches_actor(_gunner_target_selection, occupant_peer_id, avatar_id):
			occupant["selected_target"] = _gunner_target_selection.duplicate(true)
			(snapshot["selected_targets"] as Dictionary)["gunner"] = _gunner_target_selection.duplicate(true)
		elif role == CrewRoleGameplayProfileType.ROLE_ENGINEER \
				and _crew_role_state_matches_actor(_engineer_component_selection, occupant_peer_id, avatar_id):
			occupant["selected_target"] = _engineer_component_selection.duplicate(true)
			(snapshot["selected_targets"] as Dictionary)["engineer"] = _engineer_component_selection.duplicate(true)
		elif role == CrewRoleGameplayProfileType.ROLE_PASSENGER \
				and _crew_role_state_matches_actor(_passenger_ping_markers.get(actor_key, {}), occupant_peer_id, avatar_id):
			occupant["active_marker"] = (_passenger_ping_markers[actor_key] as Dictionary).duplicate(true)
			(snapshot["active_markers"] as Array).append(occupant["active_marker"])
		if _crew_role_state_matches_actor(_loadmaster_manifest_receipt, occupant_peer_id, avatar_id):
			occupant["loadmaster_manifest"] = _loadmaster_manifest_receipt.duplicate(true)
		var detached_occupant := occupant.duplicate(true)
		(snapshot["occupants"] as Array).append(detached_occupant)
		(role_occupancy[role] as Array).append(occupant.duplicate(true))
	var selected_targets := snapshot["selected_targets"] as Dictionary
	for target_role in [&"gunner", &"engineer"]:
		var selection := selected_targets[target_role] as Dictionary
		if selection.is_empty():
			continue
		var selection_key := _crew_role_actor_key_from_values(
			int(selection.get("occupant_peer_id", 0)),
			StringName(selection.get("avatar_id", &""))
		)
		var live_actor := live_actors.get(selection_key, {}) as Dictionary
		var expected_role := CrewRoleGameplayProfileType.ROLE_GUNNER if target_role == &"gunner" else CrewRoleGameplayProfileType.ROLE_ENGINEER
		if live_actor.is_empty() or StringName(live_actor.get("role", &"")) != expected_role:
			selected_targets[target_role] = {}
	var route_view := {}
	var route_modifiers := get_operational_modifiers()
	var engineer_selection := selected_targets.get("engineer", {}) as Dictionary
	if not engineer_selection.is_empty():
		route_view = {
			"component_id": StringName(engineer_selection.get("component_id", &"")),
			"component_generation": int(engineer_selection.get("component_generation", 0)),
			"channel": StringName(engineer_selection.get("power_route", &"none")),
			"bonus": float(engineer_selection.get("power_route_bonus", 0.0)),
		}.duplicate(true)
	else:
		# A detached or handed-off selection must never leave routed output in the
		# detached consumer view, even if authority cleanup is mid-frame.
		route_modifiers = super.get_operational_modifiers()
	var effective_outputs := {
		"mobility_multiplier": clampf(float(route_modifiers.get("mobility_multiplier", 1.0)), 0.0, 1.0),
		"fire_multiplier": clampf(float(route_modifiers.get("fire_multiplier", 1.0)), 0.0, 1.0),
		"targeting_multiplier": clampf(float(route_modifiers.get("targeting_multiplier", 1.0)), 0.0, 1.0),
	}
	(snapshot["power_routing"] as Dictionary)["engineer"] = route_view
	(snapshot["power_routing"] as Dictionary)["effective_outputs"] = effective_outputs
	var optional_crew_count := 0
	for optional_role_variant in optional_roles.values():
		if bool((optional_role_variant as Dictionary).get("occupied", false)):
			optional_crew_count += 1
	departure_readiness["optional_crew_count"] = optional_crew_count
	departure_readiness["ready"] = bool(departure_readiness.get("pilot_present", false))
	var handoff_snapshot := {}
	if not _emergency_pilot_handoff_state.is_empty():
		var handoff_assignment := _crew_role_authority.get_assignment(
			int(_emergency_pilot_handoff_state.get("occupant_peer_id", 0)),
			StringName(_emergency_pilot_handoff_state.get("avatar_id", &""))
		)
		if StringName(handoff_assignment.get("role", &"")) == CrewRoleGameplayProfileType.ROLE_PILOT:
			handoff_snapshot = {
				"status": _emergency_pilot_handoff_state.get("status", &"completed"),
				"previous_role": _emergency_pilot_handoff_state.get("previous_role", &""),
				"new_role": _emergency_pilot_handoff_state.get("new_role", &"pilot"),
				"previous_seat_generation": int(_emergency_pilot_handoff_state.get("previous_seat_generation", 0)),
				"new_seat_generation": int(_emergency_pilot_handoff_state.get("new_seat_generation", 0)),
				"release_request_sequence": int(_emergency_pilot_handoff_state.get("release_request_sequence", -1)),
				"claim_request_sequence": int(_emergency_pilot_handoff_state.get("claim_request_sequence", -1)),
				"authority_event_sequence": int(authority_snapshot.get("event_sequence", -1)),
				"ready": bool(departure_readiness.get("ready", false)),
				"neutral_command_confirmed": bool(_emergency_pilot_handoff_state.get("neutral_command_confirmed", false))
					and _pilot_command_state.is_empty()
					and not _piloted,
			}.duplicate(true)
	snapshot["emergency_pilot_handoff"] = handoff_snapshot
	(snapshot["occupants"] as Array).sort_custom(func(left: Dictionary, right: Dictionary) -> bool:
		return str(left.get("seat_id", "")) < str(right.get("seat_id", ""))
	)
	(snapshot["active_markers"] as Array).sort_custom(func(left: Dictionary, right: Dictionary) -> bool:
		return str(left.get("marker_id", "")) < str(right.get("marker_id", ""))
	)
	return snapshot.duplicate(true)


## Halyard-local power routing derived from the authoritative engineer
## selection. The component-damage owner still decides the base modifier; this
## route only gives an admitted engineer receipt a bounded priority on the
## matching live ship channel; a nominal channel naturally caps at 1.0.
func get_operational_modifiers() -> Dictionary:
	var modifiers := super.get_operational_modifiers()
	if modifiers.is_empty() or _engineer_component_selection.is_empty():
		return modifiers
	var route := StringName(_engineer_component_selection.get("power_route", &""))
	if route.is_empty() or route == &"none":
		return modifiers
	var base_value := clampf(float(modifiers.get(route, 1.0)), 0.0, 1.0)
	if base_value <= 0.0:
		return modifiers
	modifiers[route] = minf(base_value + ENGINEER_POWER_ROUTE_BONUS, 1.0)
	modifiers["engineer_power_route"] = {
		"component_id": StringName(_engineer_component_selection.get("component_id", &"")),
		"component_generation": int(_engineer_component_selection.get("component_generation", 0)),
		"channel": route,
		"bonus": ENGINEER_POWER_ROUTE_BONUS,
	}.duplicate(true)
	return modifiers


## Hands one admitted gunner receipt to HeroShip's existing weapon request
## seam. `_fire_weapon()` only emits `projectile_fired`; GameFlow's registered
## live combat authority remains responsible for source faction, weapon profile,
## target resolution, and damage. This method never mutates damage state.
func _consume_gunner_fire_intent(intent: Dictionary) -> Dictionary:
	var payload := intent.get("payload", {}) as Dictionary
	var weapon_id := StringName(payload.get("weapon_id", &""))
	var target_id := StringName(payload.get("target_id", &""))
	var actor_key := _crew_role_actor_key(intent)
	var target_generation := int(payload.get("target_generation", 0))
	if weapon_id != HALYARD_CREW_WEAPON_ID:
		return _crew_role_result(false, &"weapon_not_authorized")
	if target_generation != _gunner_target_generation:
		return _crew_role_result(false, &"stale_target_generation")
	var selection := _select_gunner_target(intent, target_id, target_generation)
	if not bool(selection.get("accepted", false)):
		return selection
	if not bool(payload.get("trigger", false)):
		return selection
	var telemetry := get_telemetry()
	if bool(telemetry.get("destroyed", false)):
		return _crew_role_result(false, &"ship_destroyed")
	if StringName(telemetry.get("engine_state", &"")) != ENGINE_ONLINE:
		return _crew_role_result(false, &"engine_not_online")
	if bool(telemetry.get("landing_active", false)):
		return _crew_role_result(false, &"weapon_blocked_during_landing")
	if _weapon_timer > 0.0:
		return _crew_role_result(false, &"weapon_cooldown")
	if float(_gunner_role_cooldowns.get(actor_key, 0.0)) > 0.0:
		return _crew_role_result(false, &"role_cooldown")
	var previous_timer := _weapon_timer
	_fire_weapon()
	if _weapon_timer <= previous_timer:
		return _crew_role_result(false, &"weapon_request_rejected")
	var result := _crew_role_result(true, &"weapon_request_emitted")
	result["source_id"] = COMBAT_SOURCE_ID
	result["faction_id"] = HALYARD_CREW_FACTION_ID
	result["weapon_id"] = weapon_id
	result["target_id"] = target_id
	result["target_generation"] = target_generation
	result["selection"] = selection
	result["request_sequence"] = int(intent.get("request_sequence", -1))
	result["cooldown_remaining"] = _weapon_timer
	_gunner_role_cooldowns[actor_key] = weapon_cooldown
	return result


func _select_gunner_target(
	intent: Dictionary,
	target_id: StringName,
	target_generation: int
) -> Dictionary:
	if target_id.is_empty() or str(target_id).length() > 64:
		return _crew_role_result(false, &"invalid_target_identity")
	var actor_key := _crew_role_actor_key(intent)
	var selection := {
		"target_id": target_id,
		"target_generation": target_generation,
		"occupant_peer_id": int(intent.get("occupant_peer_id", 0)),
		"avatar_id": StringName(intent.get("avatar_id", &"")),
		"request_sequence": int(intent.get("request_sequence", -1)),
	}
	_gunner_target_selection = selection
	gunner_target_selected.emit(target_id, target_generation, selection.duplicate(true))
	var result := _crew_role_result(true, &"target_selected")
	result["selection"] = selection.duplicate(true)
	result["actor_key"] = actor_key
	return result


## Passenger pings are ship-local navigation markers, not UI state. The marker
## position comes from the real moving cabin deck marker, while the caller only
## supplies the bounded channel/marker identifiers admitted by the role profile.
func _consume_passenger_ping_intent(intent: Dictionary) -> Dictionary:
	var payload := intent.get("payload", {}) as Dictionary
	var marker_id := StringName(payload.get("marker_id", &""))
	var channel := StringName(payload.get("channel", &""))
	var actor_key := _crew_role_actor_key(intent)
	if float(_passenger_ping_cooldowns.get(actor_key, 0.0)) > 0.0:
		return _crew_role_result(false, &"passenger_ping_cooldown")
	var cabin := get_in_flight_cabin_report()
	var deck_frame: MovingInteriorFrame = cabin.get("frame", null) as MovingInteriorFrame
	if not bool(cabin.get("supported", false)) \
			or not is_instance_valid(_interior_deck_marker) \
			or not is_instance_valid(deck_frame):
		return _crew_role_result(false, &"cabin_unavailable")
	var world_position := _interior_deck_marker.global_position
	if not world_position.is_finite():
		return _crew_role_result(false, &"marker_position_unavailable")
	var occupant_peer_id := int(intent.get("occupant_peer_id", 0))
	var avatar_id := StringName(intent.get("avatar_id", &""))
	if not _passenger_ping_markers.has(actor_key) \
			and _passenger_ping_markers.size() >= MAX_PASSENGER_PING_MARKERS:
		return _crew_role_result(false, &"passenger_ping_limit")
	var marker := {
		"marker_id": marker_id,
		"channel": channel,
		"world_position": world_position,
		"occupant_peer_id": occupant_peer_id,
		"avatar_id": avatar_id,
		"request_sequence": int(intent.get("request_sequence", -1)),
	}
	_passenger_ping_markers[actor_key] = marker
	_passenger_ping_cooldowns[actor_key] = PASSENGER_PING_COOLDOWN_SECONDS
	passenger_cabin_ping_emitted.emit(
		marker_id,
		channel,
		world_position,
		marker.duplicate(true)
	)
	var result := _crew_role_result(true, &"passenger_ping_emitted")
	result["marker"] = marker.duplicate(true)
	result["cooldown_remaining"] = PASSENGER_PING_COOLDOWN_SECONDS
	return result


## Loadmaster support is a receipt-only cabin action. The caller supplies a
## manifest/route/readiness proposal; this ship records it for downstream
## consumers but never transfers inventory, grants reward, or claims helm.
func _consume_loadmaster_manifest_intent(intent: Dictionary) -> Dictionary:
	var assignment_seat_id := StringName(intent.get("seat_id", &""))
	if assignment_seat_id != LOADMASTER_STATION_SEAT_ID:
		return _crew_role_result(false, &"loadmaster_station_required")
	if not is_instance_valid(get_loadmaster_station_anchor()):
		return _crew_role_result(false, &"loadmaster_station_unavailable")
	if is_destroyed():
		return _crew_role_result(false, &"ship_destroyed")
	var payload := intent.get("payload", {}) as Dictionary
	var receipt := {
		"role": CrewRoleGameplayProfileType.ROLE_PASSENGER,
		"seat_id": assignment_seat_id,
		"occupant_peer_id": int(intent.get("occupant_peer_id", 0)),
		"avatar_id": StringName(intent.get("avatar_id", &"")),
		"seat_generation": int(intent.get("seat_generation", 0)),
		"request_sequence": int(intent.get("request_sequence", -1)),
		"manifest_generation": _loadmaster_manifest_generation,
		"manifest_id": StringName(payload.get("manifest_id", &"")),
		"route_id": StringName(payload.get("route_id", &"")),
		"ready": bool(payload.get("ready", false)),
		"cargo_transfer_authority": false,
		"inventory_mutation_authority": false,
		"reward_authority": false,
		"helm_authority": false,
	}.duplicate(true)
	_loadmaster_manifest_receipt = receipt
	loadmaster_manifest_intent_accepted.emit(receipt.duplicate(true))
	var result := _crew_role_result(true, &"loadmaster_manifest_recorded")
	result["receipt"] = receipt.duplicate(true)
	return result


func _consume_engineer_repair_intent(intent: Dictionary) -> Dictionary:
	var payload := intent.get("payload", {}) as Dictionary
	var system_id := StringName(payload.get("system_id", &""))
	var requested_repair := float(payload.get("repair", 0.0))
	var system_generation := int(payload.get("system_generation", 0))
	var model := get_component_damage()
	if model == null or not model.is_configured():
		return _crew_role_result(false, &"component_damage_unavailable")
	var telemetry := get_telemetry()
	if bool(telemetry.get("destroyed", false)):
		return _crew_role_result(false, &"ship_destroyed")
	if not bool(telemetry.get("landed", false)) or bool(telemetry.get("landing_active", false)):
		return _crew_role_result(false, &"repair_requires_berthed_ship")
	var report := model.get_component_report()
	var order: Array = report.get("component_order", []) as Array
	if not order.has(system_id):
		return _crew_role_result(false, &"foreign_component")
	if system_generation != _engineer_component_generation:
		return _crew_role_result(false, &"stale_component_generation")
	var before := model.get_component_integrity(system_id)
	if before < 0.0:
		return _crew_role_result(false, &"foreign_component")
	if before >= 1.0:
		return _crew_role_result(false, &"healthy_component")
	var selection := _select_engineer_component(intent, system_id, system_generation)
	if not bool(selection.get("accepted", false)):
		return selection
	if requested_repair <= 0.0:
		return selection
	var rate := maxf(float(report.get("repair_rate_per_second", 0.0)), 0.05)
	var repair_result := model.tick_repair(requested_repair / rate, true)
	var after := model.get_component_integrity(system_id)
	if not bool(repair_result.get("accepted", false)) or after <= before:
		var rejected := _crew_role_result(false, StringName(repair_result.get("reason", &"system_not_repaired")))
		rejected["repair"] = repair_result
		rejected["selection"] = selection
		return rejected
	var result := _crew_role_result(true, &"repair_applied")
	result["system_id"] = system_id
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
	var power_route := _engineer_power_route_for_component(component_id)
	var selection := {
		"component_id": component_id,
		"component_generation": component_generation,
		"power_route": power_route,
		"power_route_bonus": ENGINEER_POWER_ROUTE_BONUS if power_route != &"none" else 0.0,
		"occupant_peer_id": int(intent.get("occupant_peer_id", 0)),
		"avatar_id": StringName(intent.get("avatar_id", &"")),
		"request_sequence": int(intent.get("request_sequence", -1)),
	}
	_engineer_component_selection = selection
	engineer_component_selected.emit(
		component_id,
		component_generation,
		selection.duplicate(true)
	)
	engineer_power_route_changed.emit(
		component_id,
		power_route,
		float(selection.get("power_route_bonus", 0.0)),
		selection.duplicate(true)
	)
	var result := _crew_role_result(true, &"component_selected")
	result["selection"] = selection.duplicate(true)
	return result


func _engineer_power_route_for_component(component_id: StringName) -> StringName:
	match component_id:
		ShipComponentDamage.COMPONENT_ENGINE_BAY:
			return &"mobility_multiplier"
		ShipComponentDamage.COMPONENT_PORT_WING, ShipComponentDamage.COMPONENT_STARBOARD_WING:
			return &"fire_multiplier"
		ShipComponentDamage.COMPONENT_CORE_SYSTEMS:
			return &"targeting_multiplier"
		_:
			return &"none"


static func _crew_role_result(accepted: bool, status: StringName) -> Dictionary:
	return {"accepted": accepted, "status": status}


func get_interior_root() -> Node3D:
	return _walkable_interior


## Registration frame for moving-interior occupant stabilisation.
func get_interior_frame() -> Node3D:
	return self


func get_moving_interior_component() -> MovingInteriorFrame:
	return _moving_interior_component


func get_crew_cabin_root() -> Node3D:
	return _crew_cabin


func get_aft_systems_bay_root() -> Node3D:
	return _aft_systems_bay


func get_interior_access_marker() -> Marker3D:
	return _interior_access_marker


func get_interior_deck_marker() -> Marker3D:
	return _interior_deck_marker


## World-space safe transform beyond the deployed airstair. Deliberately distinct
## from `HeroShip.get_exit_transform()`, which serves the pilot seat.
func get_interior_exit_transform() -> Transform3D:
	if _interior_exit_marker == null:
		return Transform3D(global_basis.orthonormalized(), global_position)
	return _interior_exit_marker.global_transform


func get_interior_bounds() -> AABB:
	return INTERIOR_BOUNDS


## World-space standing pose a pilot arrives at when leaving the seat under way.
func get_cabin_stand_transform() -> Transform3D:
	if _cabin_stand_marker == null:
		return global_transform.translated_local(CABIN_STAND_LOCAL_ORIGIN)
	return Transform3D(
		_cabin_stand_marker.global_basis.orthonormalized(),
		_cabin_stand_marker.global_position
	)


## The second station on the flight deck. It is a real marker on the real deck
## rather than a claim in a report: the multi-crew work that comes later seats a
## second occupant here, and until it does this is where the co-pilot's console,
## seat and harness physically are.
func get_co_pilot_station_anchor() -> Marker3D:
	return _co_pilot_station_anchor


func get_crew_seat_anchors() -> Array[Marker3D]:
	return _crew_seat_anchors.duplicate()


## `modern_interpretation`. The Halyard is a crew carrier, so its pilot may stand
## up and walk it away from a berth — that is the whole point of the class. A
## destroyed or un-instantiated interior withdraws the offer rather than opening
## a hatch onto nothing.
func get_in_flight_cabin_report() -> Dictionary:
	var ready := (
		not is_destroyed()
		and is_instance_valid(_walkable_interior)
		and is_instance_valid(_moving_interior_component)
		and _moving_interior_component.get_moving_frame() == self
	)
	return {
		"supported": ready,
		"status": &"walkable_cabin" if ready else &"interior_unavailable",
		"frame": _moving_interior_component,
		"stand_transform": get_cabin_stand_transform(),
		"local_bounds": CABIN_MOVEMENT_BOUNDS,
	}


func get_interior_occupant_count() -> int:
	return _interior_occupant_count


func get_walkable_interior_report() -> Dictionary:
	return {
		"schema_version": INTERIOR_SCHEMA_VERSION,
		"frame": self,
		"moving_interior_component": _moving_interior_component,
		"root": _walkable_interior,
		"ship_local_bounds": INTERIOR_BOUNDS,
		"access_marker": _interior_access_marker,
		"deck_marker": _interior_deck_marker,
		"exit_transform": get_interior_exit_transform(),
		"crew_cabin": _crew_cabin,
		"aft_systems_bay": _aft_systems_bay,
		"pilot_cockpit": get_pilot_seat_anchor().get_parent() if get_pilot_seat_anchor() != null else null,
		# The three spaces the deck genuinely joins. The port airstair is the
		# boarding station, not a fourth connected space: its pressure door is
		# shut while the craft is parked, and the hull wall behind it is solid
		# collision — which is also what confines a crew member walking the cabin
		# under way to the inside of the hull.
		"connected_spaces": PackedStringArray([
			"flight_deck", "crew_cabin", "aft_systems_bay",
		]),
		"exterior_access": &"port_airstair_hatch",
		"exterior_access_is_walkable": false,
		"passenger_seat_count": _crew_seat_anchors.size(),
		"flight_deck_station_count": 2,
		"detached_interior": false,
		"physical_deck_collision": true,
		"moving_occupant_compensation": _moving_interior_component != null,
		"historically_authenticated_layout": false,
		"content_note": DESIGN_NOTE,
	}


## Typed clearance contract for a berth or landing planner.
func get_berth_clearance_report() -> Dictionary:
	return {
		"schema_version": 1,
		"home_berth_id": get_home_berth_id(),
		"parked_render_bounds": PARKED_RENDER_BOUNDS,
		"flight_collision_bounds": FLIGHT_COLLISION_BOUNDS,
		"airstair_side": &"port",
		"airstair_local_direction": Vector3.LEFT,
		"landing_contact_y": LANDING_CONTACT_Y,
		"deployed_airstair_may_overlap_apron": true,
		"provisional": false,
	}


func get_halyard_evidence_report() -> Dictionary:
	var definition := get_ship_definition()
	return {
		"schema_version": SCHEMA_VERSION,
		"evidence_status": EVIDENCE_STATUS,
		"evidence_scope": EVIDENCE_SCOPE,
		"name_to_model_status": NAME_TO_MODEL_STATUS,
		"authenticated_geometry": false,
		"historical_claim": false,
		"creator_supported": PackedStringArray(),
		"modern_original": PackedStringArray([
			"the Halyard name, which appears in no registered source",
			"silhouette, dimensions, proportions, and colours",
			"crew cabin, flight deck, aft systems bay, airstair and every fixture",
			"two-station flight deck, seat and camera placement, and access side",
			"quad tail-yoke engines, defensive mounts, landing gear",
			"materials, handling, durability, audio profile, and all mechanics",
		]),
		"content_note": DESIGN_NOTE,
		"ship_definition": definition.get_audit_report() if definition != null else {},
	}


## Authored visual roster for the Halyard's two light defensive mounts. Combat
## authority remains entirely with HeroShip and the unchanged muzzle markers;
## this report describes presentation only.
func get_halyard_weapon_visual_report() -> Dictionary:
	var expected_names := PackedStringArray()
	var present_names := PackedStringArray()
	var modern_metadata_matches := true
	for side_name in ["Port", "Starboard"]:
		for suffix in [
			"DefensiveMountBase", "DefensivePulseBarrel", "DefensiveBarrelShroud",
			"DefensiveMuzzleCollar", "DefensiveMuzzleLens",
		]:
			var node_name: String = side_name + suffix
			expected_names.append(node_name)
			var part := _halyard_visual.get_node_or_null(node_name) as MeshInstance3D if _halyard_visual != null else null
			if part == null:
				modern_metadata_matches = false
				continue
			present_names.append(node_name)
			modern_metadata_matches = (
				modern_metadata_matches
				and part.get_meta("evidence_status", &"") == EVIDENCE_STATUS
				and part.get_meta("weapon_role", &"") == &"light_self_defence"
				and bool(part.get_meta("modern_original", false))
			)
	var left_muzzle := get_node_or_null("LeftMuzzle") as Marker3D
	var right_muzzle := get_node_or_null("RightMuzzle") as Marker3D
	return {
		"schema_version": 1,
		"design_status": EVIDENCE_STATUS,
		"historically_authenticated": false,
		"weapon_role": &"light_self_defence",
		"mount_count": 2,
		"visual_parts_per_mount": DEFENSIVE_VISUAL_PARTS_PER_MOUNT,
		"expected_node_names": expected_names,
		"present_node_names": present_names,
		"exact_roster": present_names == expected_names,
		"modern_metadata_matches": modern_metadata_matches,
		"muzzle_markers": [left_muzzle, right_muzzle],
		"authored_muzzle_positions": DEFENSIVE_MUZZLE_POSITIONS.duplicate(),
		"barrel_radius": DEFENSIVE_BARREL_RADIUS,
		"barrel_length": DEFENSIVE_BARREL_LENGTH,
		"shroud_size": DEFENSIVE_SHROUD_SIZE,
		"collar_radius": DEFENSIVE_COLLAR_RADIUS,
		"collar_length": DEFENSIVE_COLLAR_LENGTH,
		"lens_radius": DEFENSIVE_LENS_RADIUS,
	}


func get_halyard_render_allocation_report() -> Dictionary:
	var mesh_nodes := _halyard_visual.find_children("*", "MeshInstance3D", true, false) if _halyard_visual != null else []
	var batch_nodes := _halyard_visual.find_children("*", "MultiMeshInstance3D", true, false) if _halyard_visual != null else []
	var descendant_count := _halyard_visual.find_children("*", "Node", true, false).size() if _halyard_visual != null else 0
	var drawn_copies := 0
	var submissions := 0
	var mesh_resource_ids := {}
	var material_resource_ids := {}
	var multimesh_resource_ids := {}
	for raw_node in mesh_nodes:
		var instance := raw_node as MeshInstance3D
		if instance.mesh == null:
			continue
		drawn_copies += 1
		submissions += instance.mesh.get_surface_count()
		mesh_resource_ids[instance.mesh.get_instance_id()] = true
		if instance.material_override != null:
			material_resource_ids[instance.material_override.get_instance_id()] = true
	for raw_node in batch_nodes:
		var batch := raw_node as MultiMeshInstance3D
		if batch.multimesh == null or batch.multimesh.mesh == null:
			continue
		var visible_copies := batch.multimesh.visible_instance_count
		if visible_copies < 0:
			visible_copies = batch.multimesh.instance_count
		drawn_copies += visible_copies
		submissions += batch.multimesh.mesh.get_surface_count()
		mesh_resource_ids[batch.multimesh.mesh.get_instance_id()] = true
		multimesh_resource_ids[batch.multimesh.get_instance_id()] = true
		if batch.material_override != null:
			material_resource_ids[batch.material_override.get_instance_id()] = true

	var expected_buffer := _encode_multimesh_transforms(_spine_rib_transforms)
	var buffer_matches := (
		is_instance_valid(_spine_rib_batch)
		and _spine_rib_batch.multimesh != null
		and _spine_rib_batch.multimesh.buffer == expected_buffer
	)
	var bounds_match := false
	var material_matches := false
	var mesh_matches := false
	if is_instance_valid(_spine_rib_batch) and _spine_rib_batch.multimesh != null:
		var multi := _spine_rib_batch.multimesh
		if multi.mesh != null:
			bounds_match = multi.custom_aabb.is_equal_approx(
				_transformed_mesh_bounds(multi.mesh.get_aabb(), _spine_rib_transforms)
			)
		mesh_matches = multi.mesh == _spine_rib_mesh
		material_matches = _spine_rib_batch.material_override == _halyard_materials.get("hull_shade")
	var exact_counts := (
		descendant_count == RENDER_DESCENDANT_COUNT
		and mesh_nodes.size() == RENDER_MESH_INSTANCE_COUNT
		and batch_nodes.size() == RENDER_MULTIMESH_BATCH_COUNT
		and drawn_copies == RENDER_DRAWN_COPY_COUNT
		and submissions == RENDER_GEOMETRY_SUBMISSION_COUNT
		and mesh_resource_ids.size() == RENDER_UNIQUE_MESH_RESOURCE_COUNT
		and material_resource_ids.size() == RENDER_UNIQUE_MATERIAL_RESOURCE_COUNT
		and multimesh_resource_ids.size() == RENDER_MULTIMESH_BATCH_COUNT
		and _spine_rib_transforms.size() == SPINE_RIB_COPY_COUNT
	)
	return {
		"schema_version": 1,
		"descendant_nodes": descendant_count,
		"mesh_instances": mesh_nodes.size(),
		"multimesh_batches": batch_nodes.size(),
		"multimesh_resources": multimesh_resource_ids.size(),
		"drawn_copies": drawn_copies,
		"geometry_submissions": submissions,
		"unique_mesh_resources": mesh_resource_ids.size(),
		"unique_material_resources": material_resource_ids.size(),
		"spine_rib_copies": _spine_rib_transforms.size(),
		"renderer_buffer_floats": expected_buffer.size(),
		"renderer_buffer_matches_authored": buffer_matches,
		"bounds_match_authored": bounds_match,
		"mesh_resource_matches_authored": mesh_matches,
		"material_resource_matches_authored": material_matches,
		"exact_counts": exact_counts,
		"authored_spine_rib_transforms": _spine_rib_transforms.duplicate(),
	}


func get_halyard_audit_report() -> Dictionary:
	var errors := PackedStringArray()
	var definition := get_ship_definition()
	if definition == null or not definition.is_definition_valid():
		errors.append("valid ShipDefinition is missing")
	elif definition.get_evidence_status_id() != &"new":
		errors.append("Halyard definition must remain a new original design, never a historical claim")
	elif not definition.get_audit_report().get("evidence_references", PackedStringArray()).is_empty():
		errors.append("an original design must carry no evidence references")
	if _halyard_visual == null:
		errors.append("dedicated Halyard visual root is missing")
	if _walkable_interior == null or _crew_cabin == null or _aft_systems_bay == null:
		errors.append("connected crew interior hierarchy is incomplete")
	if _interior_access_marker == null or _interior_deck_marker == null or _interior_exit_marker == null:
		errors.append("interior route markers are incomplete")
	if _cabin_stand_marker == null:
		errors.append("in-flight cabin standing marker is missing")
	elif not CABIN_MOVEMENT_BOUNDS.has_point(CABIN_STAND_LOCAL_ORIGIN):
		errors.append("in-flight cabin standing pose falls outside the confined cabin envelope")
	if _co_pilot_station_anchor == null:
		errors.append("second flight-deck crew station is missing")
	if _moving_interior_component == null or _moving_interior_component.get_moving_frame() != self:
		errors.append("typed moving-interior component is not configured against the ship frame")
	if _crew_seat_anchors.size() < 6:
		errors.append("crew cabin requires at least six seat anchors")
	if _engine_plumes.size() != 4:
		errors.append("tail yoke requires exactly four engine plumes")
	var weapons := get_halyard_weapon_visual_report()
	if not bool(weapons.exact_roster):
		errors.append("Halyard defensive weapon visual roster drifted")
	if not bool(weapons.modern_metadata_matches):
		errors.append("Halyard defensive mounts lost their modern light-self-defence metadata")
	var render := get_halyard_render_allocation_report()
	if not bool(render.exact_counts):
		errors.append("Halyard render allocations drifted from the frozen component-local roster")
	if not bool(render.renderer_buffer_matches_authored):
		errors.append("Halyard dorsal spine renderer buffer drifted from its authored transforms")
	if not bool(render.bounds_match_authored):
		errors.append("Halyard dorsal spine culling bounds drifted from its authored copies")
	if not bool(render.mesh_resource_matches_authored) or not bool(render.material_resource_matches_authored):
		errors.append("Halyard dorsal spine mesh or material identity drifted")
	return {
		"schema_version": SCHEMA_VERSION,
		"valid": errors.is_empty(),
		"errors": errors,
		"evidence_status": EVIDENCE_STATUS,
		"combat_source_id": COMBAT_SOURCE_ID,
		"crew_seat_count": _crew_seat_anchors.size(),
		"flight_deck_station_count": 2,
		"engine_count": _engine_plumes.size(),
		"content_note": DESIGN_NOTE,
	}


# ----------------------------------------------------------------- build ----


func _build_halyard_variant(_controller: HeroShip) -> bool:
	var inherited_visual := get_variant_visual_root()
	if inherited_visual == null:
		return false
	# Keep the common cockpit objects and the controller's private references to
	# them intact, but move the whole cabin onto the transport's flight deck.
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
	inherited_visual.queue_free()

	_halyard_visual = Node3D.new()
	_halyard_visual.name = "HalyardTransportVisual"
	_halyard_visual.set_meta("geometry_status", EVIDENCE_STATUS)
	_halyard_visual.set_meta("authenticated_historical_silhouette", false)
	_halyard_visual.set_meta("content_note", DESIGN_NOTE)
	add_child(_halyard_visual)
	for preserved in [cockpit, canopy, hinge_bar]:
		if preserved != null:
			preserved.reparent(_halyard_visual, true)
	for mount in hinge_mounts:
		(mount as Node3D).reparent(_halyard_visual, true)

	_create_halyard_materials()
	_relocate_and_restyle_cockpit(cockpit, canopy, hinge_bar, hinge_mounts)
	_build_pressure_hull()
	_build_bow_docking_arch()
	_build_flank_detail()
	_build_connected_interior()
	_build_propulsion_and_gear()
	_replace_collision_and_markers()
	_bind_optional_interior_frame()
	if not replace_variant_visual_root(_halyard_visual):
		return false
	return true


func _create_halyard_materials() -> void:
	_halyard_materials.hull_olive = _halyard_material(HULL_OLIVE, 0.18, 0.42)
	_halyard_materials.hull_shade = _halyard_material(HULL_SHADE, 0.24, 0.50)
	# Interior metalness is deliberately low. The first rendered cabin pass ran
	# structure/trim/locker at 0.26-0.32 metallic against the panel roughness map
	# and the practical lights turned every bulkhead into wet polished tile, which
	# is not what a working crew compartment looks like.
	_halyard_materials.structure = _halyard_material(HALYARD_STRUCTURE, 0.10, 0.78)
	_halyard_materials.dark = _halyard_material(HALYARD_STRUCTURE_DARK, 0.62, 0.34)
	_halyard_materials.accent = _halyard_material(HALYARD_ACCENT, 0.14, 0.58)
	_halyard_materials.deck = _halyard_material(DECK_PLATE, 0.14, 0.86)
	_halyard_materials.trim = _halyard_material(CABIN_TRIM, 0.08, 0.74)
	_halyard_materials.cloth = _halyard_material(SEAT_CLOTH, 0.04, 0.88)
	_halyard_materials.locker = _halyard_material(LOCKER_FACE, 0.12, 0.70)
	# Rendered at eye height in the aft bay, the first pass's 2.4 energy blew the
	# side strips out into solid white bars that ate the bulkheads behind them.
	_halyard_materials.interior_light = _halyard_material(CABIN_LIGHT, 0.0, 0.34, CABIN_LIGHT, 0.95)
	# Cabin instruments do not use the identification accent. On this craft the
	# accent is a deep aubergine chosen for at-a-glance hull separation, and a
	# self-lit panel in it would be a black display. The Jovian makes the same
	# split for the same reason.
	_halyard_materials.display = _halyard_material(Color("14302c"), 0.16, 0.24, Color("57d6c0"), 2.6)
	# Caution instruments. Amber, because that is what a caution instrument is,
	# and deliberately not the identification accent — see the note in
	# `_relocate_and_restyle_cockpit`.
	_halyard_materials.instrument = _halyard_material(Color("3a2a10"), 0.16, 0.28, Color("e0a445"), 2.4)
	_halyard_materials.instrument_low = _halyard_material(Color("241a0b"), 0.10, 0.42, Color("6f5222"), 0.42)
	_halyard_materials.window_glow = _halyard_material(
		WINDOW_INTERIOR, 0.05, 0.42, Color("cfe0cc"), 2.1
	)
	_halyard_materials.engine = _halyard_material(ENGINE_CYAN, 0.10, 0.18, ENGINE_CYAN, 3.0)
	_halyard_materials.nav_red = _halyard_material(HALYARD_NAV_RED, 0.10, 0.22, HALYARD_NAV_RED, 2.3)
	_halyard_materials.nav_green = _halyard_material(HALYARD_NAV_GREEN, 0.10, 0.22, HALYARD_NAV_GREEN, 2.3)
	_halyard_materials.glass = _halyard_glass(Color(0.16, 0.28, 0.24, 0.22))

	# The registered station panel maps and triplanar recipe, applied through the
	# shared kit. See the surfacing note at the top of this file for why the two
	# hull skins step `normal_scale` back into the fleet band afterwards and the
	# walked/structural surfaces keep the registered 1.0.
	for hull_material: StandardMaterial3D in [
		_halyard_materials.hull_olive, _halyard_materials.hull_shade
	]:
		if _apply_vehicle_panel_triplanar(hull_material, HULL_PANEL_UV_SCALE):
			hull_material.normal_scale = HULL_NORMAL_SCALE
			hull_material.clearcoat_enabled = true
			hull_material.clearcoat = HULL_CLEARCOAT
			hull_material.clearcoat_roughness = 0.28
			# The panel albedo is a greyscale plate pattern and multiplies the
			# authored tint; the tint itself is untouched, so the body tone the
			# fleet colour audit measures is exactly the authored HULL_OLIVE.
			hull_material.albedo_color = HULL_OLIVE if hull_material == _halyard_materials.hull_olive else HULL_SHADE
	for structural_material: StandardMaterial3D in [
		_halyard_materials.structure, _halyard_materials.dark,
		_halyard_materials.accent, _halyard_materials.trim,
		_halyard_materials.locker,
	]:
		_apply_vehicle_panel_triplanar(structural_material, STRUCTURE_PANEL_UV_SCALE)
	# Surfaces the crew physically stands on take the walked panel scale, exactly
	# as the freight berth's decks do.
	_apply_vehicle_panel_triplanar(_halyard_materials.deck, WALKED_PANEL_UV_SCALE)


func _apply_vehicle_panel_triplanar(material: StandardMaterial3D, uv_scale: float) -> bool:
	if not StationSurfaceKit.apply_panel_triplanar(material, uv_scale):
		return false
	# Static station pieces need world-continuous projection. This moving craft
	# must carry its projection with it so the panel pattern cannot swim in flight.
	material.uv1_world_triplanar = false
	return true


func get_variant_materials() -> Dictionary:
	return _halyard_materials


func _relocate_and_restyle_cockpit(
		cockpit: Node3D,
		canopy: Node3D,
		hinge_bar: Node3D,
		hinge_mounts: Array[Node]
	) -> void:
	# The inherited cockpit is built from the common controller's material set,
	# and several of those materials are derived from `identification_accent`:
	# `gold` (sills, harness, buckle), `display_gold` and `display_gold_low` (the
	# warning strip, the centre attitude bar, the console keys). On every other
	# craft that accent is a bright colour and those objects read. On this craft
	# it is a deep aubergine chosen for hull separation, and an emissive panel in
	# it is a black panel — an unlit warning strip is worse than no warning
	# strip. Cockpit instrument emission is therefore taken off the accent and
	# put on the transport's own readable amber, exactly as the freighter puts
	# its displays on teal rather than on its crimson accent.
	var swaps := {
		_materials.get("gold"): _halyard_materials.trim,
		_materials.get("display_gold"): _halyard_materials.instrument,
		_materials.get("display_gold_low"): _halyard_materials.instrument_low,
		_materials.get("display_cyan"): _halyard_materials.display,
		_materials.get("upholstery"): _halyard_materials.cloth,
		_materials.get("upholstery_light"): _halyard_materials.trim,
		_materials.get("restraint"): _halyard_materials.accent,
	}
	for root_node: Node3D in [cockpit, canopy, hinge_bar]:
		if root_node == null:
			continue
		for node in root_node.find_children("*", "MeshInstance3D", true, false):
			var mesh_instance := node as MeshInstance3D
			var current := mesh_instance.material_override
			if current != null and swaps.has(current) and swaps[current] != null:
				mesh_instance.material_override = swaps[current]

	if cockpit != null:
		cockpit.position += COCKPIT_SHIFT
		cockpit.set_meta("space_id", &"flight_deck")
		# The transport connects this former fighter rear bulkhead to the crew
		# cabin, so the solid panel is replaced by a real open pressure frame.
		var rear_wall := cockpit.get_node_or_null("RearPressureWall") as MeshInstance3D
		if rear_wall != null:
			rear_wall.visible = false
		for surface in cockpit.find_children("*Sidewall", "MeshInstance3D", true, false):
			(surface as MeshInstance3D).material_override = _halyard_materials.structure
		for surface in cockpit.find_children("*Sill", "MeshInstance3D", true, false):
			(surface as MeshInstance3D).material_override = _halyard_materials.accent
		for display in cockpit.find_children("*Display", "MeshInstance3D", true, false):
			(display as MeshInstance3D).material_override = _halyard_materials.display
		for floor_plate in cockpit.find_children("CockpitFloor", "MeshInstance3D", true, false):
			(floor_plate as MeshInstance3D).material_override = _halyard_materials.deck
	if canopy != null:
		canopy.position += COCKPIT_SHIFT
		# The common controller supplies a fighter's lift-up bubble canopy. A
		# pressurised crew deck is not entered that way — the Halyard is boarded
		# through the port hatch — and rendered at this craft's scale the bubble
		# sat directly across the seated pilot's forward view. Its nodes and the
		# canopy state machine are left intact so boarding, the open/close
		# lifecycle and every canopy assertion still run; only its meshes are
		# hidden. Making the port hatch itself the animated entry surface is
		# recorded as follow-up work rather than faked here.
		for canopy_mesh in canopy.find_children("*", "MeshInstance3D", true, false):
			(canopy_mesh as MeshInstance3D).visible = false
		for glass in canopy.find_children("CanopyGlass", "MeshInstance3D", true, false):
			(glass as MeshInstance3D).material_override = _halyard_materials.glass
		for frame in canopy.find_children("*Canopy*Frame", "MeshInstance3D", true, false):
			(frame as MeshInstance3D).material_override = _halyard_materials.structure
		for rail in canopy.find_children("*Canopy*Rail", "MeshInstance3D", true, false):
			(rail as MeshInstance3D).material_override = _halyard_materials.accent
	if hinge_bar != null:
		hinge_bar.position += COCKPIT_SHIFT
		(hinge_bar as MeshInstance3D).material_override = _halyard_materials.structure
		(hinge_bar as MeshInstance3D).visible = false
	for mount in hinge_mounts:
		var mount_3d := mount as Node3D
		mount_3d.position += COCKPIT_SHIFT
		if mount_3d is MeshInstance3D:
			(mount_3d as MeshInstance3D).material_override = _halyard_materials.accent
			(mount_3d as MeshInstance3D).visible = false


## The dominant mass: a faceted octagonal pressure tube assembled from long
## chamfered boxes, stepped in at the crown and the belly. Deliberately not a
## smooth loft — `docs/design/FLEET_VISUAL_GRAMMAR.md` §7.9 requires planar,
## faceted, stepped construction, and a smoothly blended tube would be the one
## organic hull in the fleet.
func _build_pressure_hull() -> void:
	var length := TUBE_AFT_Z - TUBE_FORWARD_Z
	var centre_z := (TUBE_AFT_Z + TUBE_FORWARD_Z) * 0.5
	_box(_halyard_visual, "HullCore", Vector3(0.0, 1.85, centre_z), Vector3(HULL_HALF_WIDTH * 2.0, 2.90, length), _halyard_materials.hull_olive)
	_box(_halyard_visual, "HullCrown", Vector3(0.0, 3.35, centre_z), Vector3(4.20, 1.00, length - 0.60), _halyard_materials.hull_olive)
	_box(_halyard_visual, "HullCrownCap", Vector3(0.0, 3.90, centre_z), Vector3(2.60, 0.30, length - 1.40), _halyard_materials.hull_shade)
	_box(_halyard_visual, "HullBelly", Vector3(0.0, 0.12, centre_z), Vector3(4.30, 0.80, length - 0.20), _halyard_materials.hull_shade)
	_box(_halyard_visual, "HullKeel", Vector3(0.0, -0.45, centre_z + 0.20), Vector3(2.50, 0.55, length - 2.80), _halyard_materials.structure)

	# Stepped nose, built as a *shell* around the flight deck rather than as two
	# solid blocks. The first rendered pass authored it solid, and the production
	# cockpit camera then looked straight into the inside of the hull: the pilot's
	# own view was a wall of unlit panel. Roof, belly and cheeks now enclose the
	# deck and the forward face is glazing, so the seated eye point has an
	# uninterrupted forward view. Stepped construction is preserved by the second,
	# narrower nose-cap ring rather than by filling the volume.
	for side in [-1.0, 1.0]:
		var side_name := "Port" if side < 0.0 else "Starboard"
		_box(_halyard_visual, side_name + "NoseCheek", Vector3(side * 2.03, 1.80, -11.75), Vector3(0.34, 2.60, 2.40), _halyard_materials.hull_olive)
		_box(_halyard_visual, side_name + "NoseCapCheek", Vector3(side * 1.48, 1.72, -12.85), Vector3(0.30, 2.10, 0.90), _halyard_materials.hull_shade)
		_box(_halyard_visual, side_name + "FlightDeckQuarterlight", Vector3(side * 1.66, 2.05, -12.55), Vector3(0.14, 1.05, 1.50), _halyard_materials.glass)
		_box(_halyard_visual, side_name + "NoseChine", Vector3(side * 2.05, 0.72, -11.75), Vector3(0.44, 0.34, 2.30), _halyard_materials.accent)
	_box(_halyard_visual, "NoseRoof", Vector3(0.0, 2.98, -11.75), Vector3(4.30, 0.36, 2.40), _halyard_materials.hull_olive)
	_box(_halyard_visual, "NoseBelly", Vector3(0.0, 0.28, -11.75), Vector3(4.30, 0.56, 2.40), _halyard_materials.hull_shade)
	_box(_halyard_visual, "NoseCapRoof", Vector3(0.0, 2.70, -12.85), Vector3(3.20, 0.34, 0.90), _halyard_materials.hull_shade)
	_box(_halyard_visual, "NoseCapBelly", Vector3(0.0, 0.34, -12.85), Vector3(3.20, 0.48, 0.90), _halyard_materials.hull_shade)
	# Flight-deck glazing wraps the forward face. Transparent, so it is excluded
	# from the body-tone measurement by construction rather than by luck.
	_box(_halyard_visual, "FlightDeckGlazing", Vector3(0.0, 1.85, -13.28), Vector3(3.00, 1.90, 0.14), _halyard_materials.glass)
	_box(_halyard_visual, "GlazingCentrePost", Vector3(0.0, 1.85, -13.32), Vector3(0.12, 1.90, 0.10), _halyard_materials.structure)
	for post_x in [-1.05, 1.05]:
		_box(_halyard_visual, "GlazingPost", Vector3(post_x, 1.85, -13.32), Vector3(0.10, 1.90, 0.10), _halyard_materials.structure)

	# Aft pressure end and the transverse yoke root.
	_box(_halyard_visual, "AftHull", Vector3(0.0, 1.85, 8.90), Vector3(4.30, 2.80, 1.60), _halyard_materials.hull_olive)
	_box(_halyard_visual, "AftPressureCap", Vector3(0.0, 1.85, 9.72), Vector3(3.40, 2.20, 0.28), _halyard_materials.structure)

	# Dorsal service spine with periodic ribs: a long low conduit that gives the
	# crown a readable direction from above and from the chase camera.
	_box(_halyard_visual, "DorsalServiceSpine", Vector3(0.0, 4.20, centre_z), Vector3(0.55, 0.34, length - 2.40), _halyard_materials.structure)
	_spine_rib_transforms.clear()
	for rib_index in SPINE_RIB_COPY_COUNT:
		var rib_z := TUBE_FORWARD_Z + 1.80 + float(rib_index) * 2.55
		_spine_rib_transforms.append(Transform3D(Basis.IDENTITY, Vector3(0.0, 4.10, rib_z)))
	_spine_rib_mesh = StationSurfaceKit.rounded_box_mesh_cached(SPINE_RIB_SIZE, _box_mesh_cache)
	_spine_rib_batch = _multimesh_visual_stock(
		_halyard_visual,
		"SpineRibs",
		_spine_rib_mesh,
		_halyard_materials.hull_shade,
		_spine_rib_transforms,
		PackedStringArray([
			"SpineRib00", "SpineRib01", "SpineRib02", "SpineRib03",
			"SpineRib04", "SpineRib05", "SpineRib06",
		])
	)


## The at-distance signature: an open bow docking arch standing proud of the
## nose on two struts. Its five chamfered box segments retain a readable docking
## aperture and target plate without completing the wheel-like hollow loop that
## the original eight-segment collar formed.
func _build_bow_docking_arch() -> void:
	var segment_length := 2.0 * BOW_RING_RADIUS * tan(PI / 8.0)
	for segment_index in 5:
		var angle := PI * float(segment_index) / 4.0
		var segment := _box(
			_halyard_visual,
			"BowDockingArchSegment%02d" % segment_index,
			Vector3(
				BOW_RING_RADIUS * cos(angle),
				BOW_RING_CENTRE_Y + BOW_RING_RADIUS * sin(angle),
				BOW_RING_Z
			),
			Vector3(segment_length, 0.34, 0.55),
			_halyard_materials.hull_shade if segment_index % 2 == 0 else _halyard_materials.accent
		)
		segment.rotation.z = angle + PI * 0.5
	for strut_index in 2:
		var strut_angle := PI * (2.0 * float(strut_index) + 1.0) / 4.0
		_box(
			_halyard_visual,
			"BowDockingArchStrut%02d" % strut_index,
			Vector3(
				(BOW_RING_RADIUS - 0.42) * cos(strut_angle) * 0.92,
				BOW_RING_CENTRE_Y + (BOW_RING_RADIUS - 0.42) * sin(strut_angle) * 0.92,
				-12.94
			),
			Vector3(0.24, 0.24, 1.05),
			_halyard_materials.structure
		)
	_box(_halyard_visual, "BowDockingTargetPlate", Vector3(0.0, BOW_RING_CENTRE_Y - 2.05, BOW_RING_Z), Vector3(1.30, 0.22, 0.70), _halyard_materials.dark)


## Ten lit cabin windows down each flank, in a recessed frame. No other craft in
## the fleet carries passenger glazing, and a row of small lit rectangles is the
## most legible thing on a hull at range.
func _build_flank_detail() -> void:
	var band_centre_z := CABIN_WINDOW_FIRST_Z + CABIN_WINDOW_PITCH * float(CABIN_WINDOW_COUNT - 1) * 0.5
	var band_length := CABIN_WINDOW_PITCH * float(CABIN_WINDOW_COUNT - 1) + 1.30
	var cabin_window_glow_transforms: Array[Transform3D] = []
	var cabin_window_glow_names := PackedStringArray()
	var cabin_window_pane_transforms: Array[Transform3D] = []
	var cabin_window_pane_names := PackedStringArray()
	for side in [-1.0, 1.0]:
		var side_name := "Port" if side < 0.0 else "Starboard"
		_box(_halyard_visual, side_name + "WindowFrame", Vector3(side * (HULL_HALF_WIDTH + 0.04), 2.35, band_centre_z), Vector3(0.12, 0.78, band_length), _halyard_materials.structure)
		_box(_halyard_visual, side_name + "WindowSill", Vector3(side * (HULL_HALF_WIDTH + 0.06), 1.92, band_centre_z), Vector3(0.16, 0.14, band_length), _halyard_materials.accent)
		for window_index in CABIN_WINDOW_COUNT:
			var window_z := CABIN_WINDOW_FIRST_Z + float(window_index) * CABIN_WINDOW_PITCH
			# The lit pane sits proud of the recessed frame. Authored inboard of it
			# on the first pass, every window was hidden inside the hull skin and
			# the band rendered as an unbroken dark stripe.
			cabin_window_glow_transforms.append(Transform3D(
				Basis.IDENTITY,
				Vector3(side * (HULL_HALF_WIDTH + 0.09), 2.35, window_z)
			))
			cabin_window_glow_names.append(side_name + "WindowGlow%02d" % window_index)
			cabin_window_pane_transforms.append(Transform3D(
				Basis.IDENTITY,
				Vector3(side * (HULL_HALF_WIDTH + 0.13), 2.35, window_z)
			))
			cabin_window_pane_names.append(side_name + "WindowPane%02d" % window_index)
		# A single continuous banding stripe in the identification accent, low on
		# the flank where it is unbroken by windows or hardware.
		_box(_halyard_visual, side_name + "IdentificationBand", Vector3(side * (HULL_HALF_WIDTH + 0.05), 0.92, -1.20), Vector3(0.14, 0.36, 17.60), _halyard_materials.accent)
		# Defensive pulse mount. The Halyard's cadence is the slowest in the
		# fleet; this is self-defence hardware, not an armament.
		var weapon_parts: Array[MeshInstance3D] = []
		weapon_parts.append(_cylinder(
			_halyard_visual, side_name + "DefensiveMountBase",
			Vector3(side * 1.75, 4.12, -6.30), DEFENSIVE_MOUNT_BASE_RADIUS, 0.28,
			_halyard_materials.structure
		))
		weapon_parts.append(_cylinder(
			_halyard_visual, side_name + "DefensivePulseBarrel",
			Vector3(side * 1.75, 4.24, -7.05), DEFENSIVE_BARREL_RADIUS,
			DEFENSIVE_BARREL_LENGTH, _halyard_materials.dark, Vector3(90.0, 0.0, 0.0)
		))
		# A short faceted fairing carries the barrel out of the low-profile base;
		# it is a shroud, not a second heavy turret body.
		weapon_parts.append(_box(
			_halyard_visual, side_name + "DefensiveBarrelShroud",
			Vector3(side * 1.75, 4.24, -6.62), DEFENSIVE_SHROUD_SIZE,
			_halyard_materials.hull_shade
		))
		weapon_parts.append(_cylinder(
			_halyard_visual, side_name + "DefensiveMuzzleCollar",
			Vector3(side * 1.75, 4.24, -7.49), DEFENSIVE_COLLAR_RADIUS,
			DEFENSIVE_COLLAR_LENGTH, _halyard_materials.structure,
			Vector3(90.0, 0.0, 0.0)
		))
		# The dim amber lens is centred exactly on the unchanged combat marker.
		# It communicates a low-output pulse emitter without increasing authority.
		weapon_parts.append(_sphere(
			_halyard_visual, side_name + "DefensiveMuzzleLens",
			DEFENSIVE_MUZZLE_POSITIONS[0 if side < 0.0 else 1],
			DEFENSIVE_LENS_RADIUS, _halyard_materials.instrument_low
		))
		for part in weapon_parts:
			part.set_meta("evidence_status", EVIDENCE_STATUS)
			part.set_meta("modern_original", true)
			part.set_meta("weapon_role", &"light_self_defence")
			part.set_meta("visual_only", true)
		# Port-side airstair into the crew cabin. Its z is not a styling choice:
		# parked on Fleet Dock 02 the craft's bow and tail overhang a 12 m slab,
		# so the only deck a crew member can actually stand on runs alongside the
		# midships hull. The hatch is placed where the deck is.
		if side < 0.0:
			for tread_index in 4:
				_box(
					_halyard_visual,
					"AirstairTread%02d" % tread_index,
					Vector3(-2.86 - float(tread_index) * 0.42, 0.24 - float(tread_index) * 0.44, AIRSTAIR_Z),
					Vector3(0.46, 0.14, 1.55),
					_halyard_materials.deck
				)
			_box(_halyard_visual, "AirstairStringer", Vector3(-3.60, -0.36, AIRSTAIR_Z), Vector3(2.00, 0.16, 0.14), _halyard_materials.structure, Vector3(0.0, 0.0, deg_to_rad(-46.0)))
			_box(_halyard_visual, "AirstairHatchSurround", Vector3(-2.70, 1.55, AIRSTAIR_Z), Vector3(0.16, 2.10, 1.90), _halyard_materials.accent)
	var window_pane_mesh := StationSurfaceKit.rounded_box_mesh_cached(
		Vector3(0.05, 0.54, 1.08),
		_box_mesh_cache
	)
	_multimesh_visual_stock(
		_halyard_visual,
		"CabinWindowPaneBatch",
		window_pane_mesh,
		_halyard_materials.glass,
		cabin_window_pane_transforms,
		cabin_window_pane_names
	)
	var window_glow_mesh := StationSurfaceKit.rounded_box_mesh_cached(
		Vector3(0.05, 0.48, 1.00),
		_box_mesh_cache
	)
	_multimesh_visual_stock(
		_halyard_visual,
		"CabinWindowGlowBatch",
		window_glow_mesh,
		_halyard_materials.window_glow,
		cabin_window_glow_transforms,
		cabin_window_glow_names
	)


func _build_connected_interior() -> void:
	_walkable_interior = Node3D.new()
	_walkable_interior.name = "WalkableInterior"
	_walkable_interior.set_meta("space_id", &"halyard_connected_interior")
	_walkable_interior.set_meta("geometry_status", EVIDENCE_STATUS)
	_walkable_interior.set_meta("detached_interior", false)
	_walkable_interior.set_meta("historically_authenticated_layout", false)
	# A direct child of the physical ship, not of the banked exterior visual
	# root: deck meshes, hull colliders, the occupancy volume and the
	# MovingInteriorFrame all have to share one authoritative rigid transform.
	add_child(_walkable_interior)
	var cockpit := _halyard_visual.get_node_or_null("CockpitInterior") as Node3D
	if cockpit != null:
		cockpit.reparent(_walkable_interior, true)

	_build_flight_deck_second_station()
	_build_crew_cabin()
	_build_aft_systems_bay()
	_build_interior_route_and_markers()


## The multi-crew half of the flight deck. The inherited common cockpit supplies
## the pilot station; this adds the real second seat, console and anchor to
## starboard of it, on the same deck plate.
func _build_flight_deck_second_station() -> void:
	var station := Node3D.new()
	station.name = "CoPilotStation"
	station.set_meta("space_id", &"flight_deck")
	station.position = Vector3(0.70, 0.0, -11.57)
	_walkable_interior.add_child(station)
	_box(station, "CoPilotSeatBase", Vector3(0.0, 0.94, 0.0), Vector3(0.70, 0.20, 0.80), _halyard_materials.cloth)
	_box(station, "CoPilotSeatBack", Vector3(0.0, 1.50, 0.40), Vector3(0.70, 0.96, 0.16), _halyard_materials.cloth, Vector3(deg_to_rad(9.0), 0.0, 0.0))
	_box(station, "CoPilotHeadrest", Vector3(0.0, 2.06, 0.44), Vector3(0.50, 0.28, 0.20), _halyard_materials.trim)
	_box(station, "CoPilotHarness", Vector3(0.0, 1.50, 0.28), Vector3(0.12, 0.68, 0.05), _halyard_materials.accent)
	_box(station, "CoPilotConsole", Vector3(0.34, 1.18, -0.92), Vector3(0.92, 0.44, 0.60), _halyard_materials.structure, Vector3(deg_to_rad(-16.0), 0.0, 0.0))
	_box(station, "CoPilotSystemsDisplay", Vector3(0.34, 1.36, -1.10), Vector3(0.62, 0.26, 0.04), _halyard_materials.display, Vector3(deg_to_rad(-16.0), 0.0, 0.0))
	_co_pilot_station_anchor = Marker3D.new()
	_co_pilot_station_anchor.name = "CoPilotStationAnchor"
	# Same feet-frame convention as `PilotSeatAnchor`: the controller carries its
	# hips 0.72 m above its own root, so an occupant placed here sits on the
	# 0.94 m cushion.
	_co_pilot_station_anchor.position = Vector3(0.0, 0.22, -0.02)
	_co_pilot_station_anchor.set_meta("station_id", &"co_pilot")
	station.add_child(_co_pilot_station_anchor)
	# The common controller's practical cockpit light is Torrent-only presentation
	# and is deliberately released for fleet variants, so the flight deck needs
	# its own. Rendered without one, both crew stations sat in the dark while the
	# cabin behind them was lit.
	var deck_light := OmniLight3D.new()
	deck_light.name = "FlightDeckPracticalLight"
	deck_light.position = Vector3(-0.70, 2.70, -0.90)
	deck_light.light_color = Color("dfeef0")
	deck_light.light_energy = 0.85
	deck_light.omni_range = 4.4
	deck_light.shadow_enabled = true
	station.add_child(deck_light)
	_box(station, "FlightDeckLightStrip", Vector3(-0.70, 2.96, -0.90), Vector3(1.70, 0.06, 0.16), _halyard_materials.interior_light)


func _build_crew_cabin() -> void:
	_crew_cabin = Node3D.new()
	_crew_cabin.name = "CrewCabin"
	_crew_cabin.set_meta("space_id", &"crew_cabin")
	_crew_cabin.set_meta("capacity_status", &"modern_design")
	_walkable_interior.add_child(_crew_cabin)
	_box(_crew_cabin, "CabinDeck", Vector3(0.0, 0.41, -3.65), Vector3(4.86, 0.18, 12.50), _halyard_materials.deck)
	_box(_crew_cabin, "CabinAisleInlay", Vector3(0.0, 0.51, -3.65), Vector3(1.00, 0.03, 12.20), _halyard_materials.accent)
	_box(_crew_cabin, "CabinCeiling", Vector3(0.0, 3.34, -3.65), Vector3(4.86, 0.16, 12.50), _halyard_materials.trim)
	var cabin_window_pane_transforms: Array[Transform3D] = []
	var cabin_window_pane_names := PackedStringArray()
	var crew_seat_leg_transforms: Array[Transform3D] = []
	var crew_seat_leg_names := PackedStringArray()
	for side in [-1.0, 1.0]:
		var side_name := "Port" if side < 0.0 else "Starboard"
		_box(_crew_cabin, side_name + "CabinSidewall", Vector3(side * 2.46, 1.92, -3.65), Vector3(0.18, 2.86, 12.50), _halyard_materials.structure)
		_box(_crew_cabin, side_name + "CabinLightStrip", Vector3(side * 2.30, 3.22, -3.65), Vector3(0.05, 0.12, 11.60), _halyard_materials.interior_light)
		# Inboard faces of the same ten windows. Without these the cabin sidewall
		# is a blank bulkhead: the exterior band is outboard of it, so the first
		# rendered pass produced a passenger cabin with no windows in it.
		for window_index in CABIN_WINDOW_COUNT:
			var window_z := CABIN_WINDOW_FIRST_Z + float(window_index) * CABIN_WINDOW_PITCH
			if window_z < -9.30 or window_z > 2.10:
				continue
			_box(_crew_cabin, side_name + "CabinWindowSurround%02d" % window_index, Vector3(side * 2.40, 2.35, window_z), Vector3(0.09, 0.68, 1.20), _halyard_materials.trim)
			cabin_window_pane_transforms.append(Transform3D(
				Basis.IDENTITY,
				Vector3(side * 2.34, 2.35, window_z)
			))
			cabin_window_pane_names.append(side_name + "CabinWindowPane%02d" % window_index)
		_box(_crew_cabin, side_name + "CabinHandrail", Vector3(side * 2.28, 2.72, -3.65), Vector3(0.09, 0.09, 11.20), _halyard_materials.trim)
		# Six forward-facing crew seats, three a side, either side of a 1.0 m
		# aisle. Anchors are explicit contracts for the multi-crew work.
		for row_index in CREW_SEAT_ROWS.size():
			var seat_root := Node3D.new()
			seat_root.name = side_name + "CrewSeat%02d" % row_index
			seat_root.position = Vector3(side * CREW_SEAT_HALF_SPACING, 0.0, CREW_SEAT_ROWS[row_index])
			_crew_cabin.add_child(seat_root)
			_box(seat_root, "SeatBase", Vector3(0.0, 0.92, 0.0), Vector3(0.68, 0.18, 0.76), _halyard_materials.cloth)
			_box(seat_root, "SeatBack", Vector3(0.0, 1.46, 0.40), Vector3(0.68, 0.92, 0.15), _halyard_materials.cloth, Vector3(deg_to_rad(8.0), 0.0, 0.0))
			_box(seat_root, "SeatHeadrest", Vector3(0.0, 1.98, 0.44), Vector3(0.48, 0.26, 0.18), _halyard_materials.trim)
			_box(seat_root, "SeatHarness", Vector3(0.0, 1.44, 0.28), Vector3(0.11, 0.66, 0.05), _halyard_materials.accent)
			crew_seat_leg_transforms.append(Transform3D(
				Basis.IDENTITY,
				seat_root.position + Vector3(0.0, 0.70, 0.10)
			))
			crew_seat_leg_names.append(seat_root.name + "/SeatLeg")
			var anchor := Marker3D.new()
			anchor.name = "CrewSeatAnchor"
			anchor.position = Vector3(0.0, 0.20, -0.04)
			anchor.set_meta("seat_id", StringName("crew_%s_%02d" % [side_name.to_lower(), row_index]))
			seat_root.add_child(anchor)
			_crew_seat_anchors.append(anchor)
		# Overhead stowage above the seat rows.
		_box(_crew_cabin, side_name + "OverheadStowage", Vector3(side * 1.86, 2.98, -5.40), Vector3(1.10, 0.52, 7.20), _halyard_materials.locker)
	# These inboard panes are repeated cabin illumination only. Keeping their
	# batch beneath CrewCabin preserves the moving-interior transform while
	# removing thirteen renderer submissions; the surrounding frames and every
	# physical/semantic cabin node remain independent.
	var cabin_window_pane_mesh := StationSurfaceKit.rounded_box_mesh_cached(
		Vector3(0.05, 0.48, 1.00),
		_box_mesh_cache
	)
	_multimesh_visual_stock(
		_crew_cabin,
		"CabinInteriorWindowPaneBatch",
		cabin_window_pane_mesh,
		_halyard_materials.window_glow,
		cabin_window_pane_transforms,
		cabin_window_pane_names
	)
	var seat_leg_mesh := StationSurfaceKit.rounded_box_mesh_cached(
		Vector3(0.20, 0.28, 0.20),
		_box_mesh_cache
	)
	_multimesh_visual_stock(
		_crew_cabin,
		"CrewSeatLegBatch",
		seat_leg_mesh,
		_halyard_materials.structure,
		crew_seat_leg_transforms,
		crew_seat_leg_names
	)
	# Open pressure frames make the forward and aft connections explicit rather
	# than leaving two blank bulkheads.
	for portal_z in [-9.70, 2.50]:
		for side in [-1.0, 1.0]:
			_box(_crew_cabin, "CabinPortalUpright", Vector3(side * 1.28, 1.90, portal_z), Vector3(0.18, 2.80, 0.22), _halyard_materials.accent)
		_box(_crew_cabin, "CabinPortalHeader", Vector3(0.0, 3.16, portal_z), Vector3(2.74, 0.22, 0.22), _halyard_materials.accent)
	_box(_crew_cabin, "CabinFoldingTable", Vector3(0.0, 1.06, -5.40), Vector3(0.90, 0.09, 1.50), _halyard_materials.trim)
	var status_panel := _box(
		_crew_cabin,
		"CabinStatusPanel",
		Vector3(0.0, 2.35, 2.62),
		Vector3(1.00, 0.54, 0.05),
		_halyard_materials.display
	)
	_crew_status_display = HalyardCrewStatusDisplayType.new()
	_crew_status_display.name = "HalyardCrewStatusDisplay"
	status_panel.add_child(_crew_status_display)
	# Threshold plate inside the port hatch. Kept clear of the port seat row.
	_box(_crew_cabin, "AirstairInnerLanding", Vector3(-1.98, 0.52, AIRSTAIR_Z), Vector3(0.86, 0.06, 1.70), _halyard_materials.accent)
	_box(_crew_cabin, "PortHatchDoor", Vector3(-2.36, 1.55, AIRSTAIR_Z), Vector3(0.10, 2.00, 1.80), _halyard_materials.dark)
	_box(_crew_cabin, "PortHatchDoorSeal", Vector3(-2.30, 1.55, AIRSTAIR_Z), Vector3(0.05, 2.10, 1.90), _halyard_materials.accent)
	for light_z in [-8.00, -3.65, 0.70]:
		var cabin_light := OmniLight3D.new()
		cabin_light.name = "CabinPracticalLight"
		cabin_light.position = Vector3(0.0, 3.06, light_z)
		cabin_light.light_color = Color("e2f0e0")
		cabin_light.light_energy = 0.95
		cabin_light.omni_range = 5.4
		cabin_light.shadow_enabled = true
		_crew_cabin.add_child(cabin_light)


func _build_aft_systems_bay() -> void:
	_aft_systems_bay = Node3D.new()
	_aft_systems_bay.name = "AftSystemsBay"
	_aft_systems_bay.set_meta("space_id", &"aft_systems_bay")
	_walkable_interior.add_child(_aft_systems_bay)
	_box(_aft_systems_bay, "AftBayDeck", Vector3(0.0, 0.41, 5.85), Vector3(4.46, 0.18, 6.50), _halyard_materials.deck)
	_box(_aft_systems_bay, "AftBayCeiling", Vector3(0.0, 3.34, 5.85), Vector3(4.46, 0.16, 6.50), _halyard_materials.trim)
	for side in [-1.0, 1.0]:
		var side_name := "Port" if side < 0.0 else "Starboard"
		_box(_aft_systems_bay, side_name + "AftBaySidewall", Vector3(side * 2.26, 1.92, 5.85), Vector3(0.18, 2.86, 6.50), _halyard_materials.structure)
		# A fold-down bunk each side: this is a crew carrier, and the aft bay is
		# where the off-watch crew are.
		_box(_aft_systems_bay, side_name + "CrewBunk", Vector3(side * 1.62, 1.24, 6.60), Vector3(1.16, 0.16, 2.10), _halyard_materials.cloth)
		_box(_aft_systems_bay, side_name + "BunkFrame", Vector3(side * 1.62, 1.14, 6.60), Vector3(1.24, 0.10, 2.20), _halyard_materials.structure)
		_box(_aft_systems_bay, side_name + "BunkCurtainRail", Vector3(side * 1.02, 2.16, 6.60), Vector3(0.07, 0.07, 2.20), _halyard_materials.trim)
		_box(_aft_systems_bay, side_name + "SystemsRack", Vector3(side * 1.80, 2.26, 3.85), Vector3(0.72, 1.80, 1.30), _halyard_materials.locker)
		for panel_index in 3:
			_box(
				_aft_systems_bay,
				side_name + "RackPanel%02d" % panel_index,
				Vector3(side * 1.42, 1.68 + float(panel_index) * 0.56, 3.85),
				Vector3(0.05, 0.32, 1.00),
				_halyard_materials.display
			)
		_box(_aft_systems_bay, side_name + "AftBayLightStrip", Vector3(side * 2.12, 3.22, 5.85), Vector3(0.05, 0.12, 5.80), _halyard_materials.interior_light)
	var bay_light := OmniLight3D.new()
	bay_light.name = "AftBayPracticalLight"
	bay_light.position = Vector3(0.0, 3.06, 5.85)
	bay_light.light_color = Color("dcecdc")
	bay_light.light_energy = 0.9
	bay_light.omni_range = 5.0
	bay_light.shadow_enabled = true
	_aft_systems_bay.add_child(bay_light)


func _build_interior_route_and_markers() -> void:
	# A short same-level bridge joins the crew cabin to the flight deck, so the
	# walk from the airstair to the pilot seat is one continuous deck.
	_box(_walkable_interior, "FlightDeckConnector", Vector3(0.0, 0.41, -10.15), Vector3(2.60, 0.18, 1.30), _halyard_materials.deck)
	for side in [-1.0, 1.0]:
		_box(_walkable_interior, "FlightDeckConnectorRail", Vector3(side * 1.34, 1.55, -10.15), Vector3(0.11, 2.10, 1.26), _halyard_materials.structure)

	_interior_access_marker = Marker3D.new()
	_interior_access_marker.name = "InteriorAccessMarker"
	_interior_access_marker.position = Vector3(-4.55, -1.12, AIRSTAIR_Z)
	_interior_access_marker.rotation.y = PI * 0.5
	_interior_access_marker.set_meta("route_id", &"port_airstair")
	_walkable_interior.add_child(_interior_access_marker)
	_interior_deck_marker = Marker3D.new()
	_interior_deck_marker.name = "InteriorDeckMarker"
	_interior_deck_marker.position = Vector3(-1.75, 0.64, AIRSTAIR_Z)
	_interior_deck_marker.rotation.y = PI * 0.5
	_interior_deck_marker.set_meta("space_id", &"crew_cabin")
	_walkable_interior.add_child(_interior_deck_marker)
	_interior_exit_marker = Marker3D.new()
	_interior_exit_marker.name = "InteriorExitMarker"
	_interior_exit_marker.position = Vector3(-5.20, -1.12, AIRSTAIR_Z)
	_interior_exit_marker.rotation.y = PI * 0.5
	_walkable_interior.add_child(_interior_exit_marker)
	# The standing pose used when the pilot leaves the seat away from a berth. A
	# real ship-local marker rather than a computed offset, so the cabin route,
	# the containment recall and the re-boarding prompt all name one place.
	_cabin_stand_marker = Marker3D.new()
	_cabin_stand_marker.name = "CabinStandMarker"
	_cabin_stand_marker.position = CABIN_STAND_LOCAL_ORIGIN
	_cabin_stand_marker.rotation.y = CABIN_STAND_LOCAL_YAW
	_cabin_stand_marker.set_meta("space_id", &"cabin_stand")
	_walkable_interior.add_child(_cabin_stand_marker)

	# Direct CharacterBody collision shapes make the interior physically
	# walkable; this volume drives production MovingInteriorFrame occupancy while
	# keeping every occupant in the same world-space scene.
	_occupant_volume = Area3D.new()
	_occupant_volume.name = "InteriorOccupantVolume"
	_occupant_volume.collision_layer = PhysicsLayers.INTERACTABLE_AREA_LAYER
	_occupant_volume.collision_mask = PhysicsLayers.PLAYER_BODY_LAYER
	_occupant_volume.monitoring = true
	_occupant_volume.monitorable = false
	_occupant_volume.set_meta("ship_local_bounds", INTERIOR_BOUNDS)
	_walkable_interior.add_child(_occupant_volume)
	var volume_shape := CollisionShape3D.new()
	volume_shape.name = "InteriorBoundsShape"
	volume_shape.position = INTERIOR_BOUNDS.get_center()
	var box := BoxShape3D.new()
	box.size = INTERIOR_BOUNDS.size
	volume_shape.shape = box
	_occupant_volume.add_child(volume_shape)


func _build_propulsion_and_gear() -> void:
	# Transverse tail yoke carrying four engines in one row. No other craft in
	# the fleet puts its propulsion on a single lateral bar; the Jovian's quad is
	# a stacked 2x2 box and the fighters are paired on the hull.
	# The yoke stands clear aft of the pressure hull. On the first rendered pass
	# it sat at z 9.90, half buried behind the aft hull, and from abeam the craft
	# read as one engine on a stick instead of four engines on a bar.
	_box(_halyard_visual, "TailYoke", Vector3(0.0, 1.55, TAIL_YOKE_Z), Vector3(9.60, 1.15, 1.40), _halyard_materials.structure)
	_box(_halyard_visual, "TailYokeCap", Vector3(0.0, 2.24, TAIL_YOKE_Z), Vector3(8.80, 0.24, 1.20), _halyard_materials.hull_shade)
	_box(_halyard_visual, "TailYokeBand", Vector3(0.0, 1.55, TAIL_YOKE_Z - 0.76), Vector3(9.00, 0.34, 0.14), _halyard_materials.accent)
	for side in [-1.0, 1.0]:
		var side_name := "Port" if side < 0.0 else "Starboard"
		_box(_halyard_visual, side_name + "YokePylon", Vector3(side * 1.35, 1.55, 10.20), Vector3(0.55, 0.85, 2.60), _halyard_materials.structure)
		_box(_halyard_visual, side_name + "YokeBrace", Vector3(side * 3.10, 1.20, 10.30), Vector3(3.60, 0.42, 0.60), _halyard_materials.structure, Vector3(0.0, side * deg_to_rad(-26.0), 0.0))
		_box(_halyard_visual, side_name + "YokeTipFairing", Vector3(side * 4.72, 1.55, TAIL_YOKE_Z), Vector3(0.40, 1.25, 1.60), _halyard_materials.hull_olive)
	for engine_index in 4:
		var offsets := [-3.75, -1.45, 1.45, 3.75]
		var engine_x: float = offsets[engine_index]
		var prefix := "Engine%02d" % engine_index
		_cylinder(_halyard_visual, prefix + "Housing", Vector3(engine_x, 1.55, 12.20), 0.72, 2.10, _halyard_materials.structure, Vector3(90.0, 0.0, 0.0))
		_cylinder(_halyard_visual, prefix + "Collar", Vector3(engine_x, 1.55, 13.36), 0.86, 0.36, _halyard_materials.hull_shade, Vector3(90.0, 0.0, 0.0))
		var core := _cylinder(_halyard_visual, prefix + "Core", Vector3(engine_x, 1.55, 13.56), 0.48, 0.18, _halyard_materials.engine, Vector3(90.0, 0.0, 0.0))
		_engine_cores.append(core)
		var plume := _cylinder(_halyard_visual, prefix + "Plume", Vector3(engine_x, 1.55, 14.02), 0.32, 0.94, _halyard_materials.engine, Vector3(90.0, 0.0, 0.0))
		_engine_plumes.append(plume)
		var light := OmniLight3D.new()
		light.name = prefix + "Light"
		light.position = Vector3(engine_x, 1.55, 13.75)
		light.light_color = ENGINE_CYAN
		light.light_energy = 0.0
		light.omni_range = 7.0
		light.shadow_enabled = false
		_halyard_visual.add_child(light)
		_halyard_engine_lights.append(light)

	# Shared fleet navigation convention: red to port, green to starboard.
	_box(_halyard_visual, "PortNavLight", Vector3(-4.96, 1.55, TAIL_YOKE_Z), Vector3(0.16, 0.34, 0.60), _halyard_materials.nav_red)
	_box(_halyard_visual, "StarboardNavLight", Vector3(4.96, 1.55, TAIL_YOKE_Z), Vector3(0.16, 0.34, 0.60), _halyard_materials.nav_green)
	_box(_halyard_visual, "PortForwardNavLight", Vector3(-2.30, 1.85, -13.62), Vector3(0.24, 0.24, 0.16), _halyard_materials.nav_red)
	_box(_halyard_visual, "StarboardForwardNavLight", Vector3(2.30, 1.85, -13.62), Vector3(0.24, 0.24, 0.16), _halyard_materials.nav_green)

	# Four landing legs on a 10 m wheelbase, deliberately short enough that all
	# four feet sit inside the 12 m Fleet Dock 02 slab (0.8 m and 1.2 m of slab
	# to spare fore and aft) while the bow collar and the tail yoke overhang it,
	# the way a long aircraft overhangs its stand.
	var gear_damper_transforms: Array[Transform3D] = []
	var gear_damper_names := PackedStringArray()
	for side in [-1.0, 1.0]:
		for leg_z in [-5.20, 4.80]:
			var leg_name := ("Port" if side < 0.0 else "Starboard") + ("Forward" if leg_z < 0.0 else "Aft")
			_box(_halyard_visual, leg_name + "GearStrut", Vector3(side * 1.95, -0.37, leg_z), Vector3(0.30, 0.88, 0.30), _halyard_materials.dark, Vector3(0.0, 0.0, side * deg_to_rad(-6.0)))
			_box(_halyard_visual, leg_name + "GearFoot", Vector3(side * 2.08, -0.98, leg_z), Vector3(1.20, 0.20, 1.65), _halyard_materials.structure)
			gear_damper_transforms.append(Transform3D(Basis.IDENTITY, Vector3(side * 1.78, -0.19, leg_z)))
			gear_damper_names.append(leg_name + "GearDamper")
	# The four dampers are immutable visual trim. Landing contact and collision
	# remain owned by LandingGearCollision, so this retains every physical gear
	# contract while replacing four identical renderer submissions with one.
	var gear_damper_mesh := StationSurfaceKit.chamfered_cylinder_mesh_cached(
		GEAR_DAMPER_RADIUS, GEAR_DAMPER_RADIUS, GEAR_DAMPER_HEIGHT, 32,
		_chamfered_cylinder_cache, ShipSurfaceDetail.CYLINDER_WALL_RINGS,
		true, true, _halyard_materials.accent
	)
	_multimesh_visual_stock(
		_halyard_visual,
		"LandingGearDamperBatch",
		gear_damper_mesh,
		_halyard_materials.accent,
		gear_damper_transforms,
		gear_damper_names
	)


func _replace_collision_and_markers() -> void:
	for child in get_children():
		if child is CollisionShape3D:
			remove_child(child)
			child.queue_free()
	# Three walkable deck plates. Their footprints join without a gap, so the
	# walk from the airstair to the pilot seat never crosses a hole.
	_add_box_collision("CockpitDeckCollision", Vector3(0.0, 0.38, -11.60), Vector3(3.90, 0.24, 3.40))
	_add_box_collision("CabinDeckCollision", Vector3(0.0, 0.38, -3.65), Vector3(4.90, 0.24, 12.50))
	_add_box_collision("AftBayDeckCollision", Vector3(0.0, 0.38, 5.85), Vector3(4.50, 0.24, 6.50))
	# The pressure hull itself. The interior is enclosed by real geometry, not by
	# the containment guard alone.
	_add_box_collision("HullCrownCollision", Vector3(0.0, 3.62, -1.20), Vector3(5.30, 0.90, 18.80))
	_add_box_collision("PortHullWallCollision", Vector3(-2.58, 1.95, -1.20), Vector3(0.28, 2.90, 18.80))
	_add_box_collision("StarboardHullWallCollision", Vector3(2.58, 1.95, -1.20), Vector3(0.28, 2.90, 18.80))
	_add_box_collision("VentralHullCollision", Vector3(0.0, 0.04, -1.20), Vector3(5.20, 0.78, 18.80))
	# The nose is a shell around the flight deck, so its collision is roof and
	# belly rather than one solid block; the port and starboard flight-deck walls
	# below close the remaining two sides.
	_add_box_collision("NoseRoofCollision", Vector3(0.0, 3.02, -11.95), Vector3(4.35, 0.44, 3.10))
	_add_box_collision("NoseBellyCollision", Vector3(0.0, -0.06, -11.95), Vector3(4.35, 0.62, 3.10))
	_add_box_collision("CockpitForwardWallCollision", Vector3(0.0, 1.85, -13.40), Vector3(3.60, 2.60, 0.24))
	for side in [-1.0, 1.0]:
		# The flight deck has a floor; it needs sides too, because a crew member
		# can now walk on to it and an unenclosed deck edge is a way out of a
		# pressurised hull.
		_add_box_collision(
			("Port" if side < 0.0 else "Starboard") + "CockpitSidewallCollision",
			Vector3(side * 2.10, 1.75, -11.60),
			Vector3(0.24, 2.60, 3.40)
		)
	_add_box_collision("AftHullCollision", Vector3(0.0, 1.85, 8.90), Vector3(4.35, 2.85, 1.65))
	_add_box_collision("AftPressureWallCollision", Vector3(0.0, 1.85, 9.72), Vector3(4.60, 2.60, 0.28))
	_add_box_collision("BowCollarCollision", Vector3(0.0, 1.85, -13.55), Vector3(5.30, 5.30, 0.60))
	_add_box_collision("TailYokeCollision", Vector3(0.0, 1.55, TAIL_YOKE_Z), Vector3(9.60, 1.15, 1.40))
	for side in [-1.0, 1.0]:
		_add_box_collision(
			("Port" if side < 0.0 else "Starboard") + "EngineCollision",
			Vector3(side * 2.60, 1.55, 12.70),
			Vector3(3.40, 1.60, 3.60)
		)
	_add_box_collision("LandingGearCollision", Vector3(0.0, -0.73, -0.60), Vector3(5.00, 0.70, 12.00))
	# The airstair is a real sloped ship-owned collider aligned with its visual.
	_add_airstair_wedge_collision("PortAirstairCollision", -4.35, -2.62, -1.08, -1.08, 0.52, AIRSTAIR_Z, 0.85)

	var boarding := get_node_or_null("BoardingPoint") as Marker3D
	var exit := get_node_or_null("ExitPoint") as Marker3D
	var left_muzzle := get_node_or_null("LeftMuzzle") as Marker3D
	var right_muzzle := get_node_or_null("RightMuzzle") as Marker3D
	# Boarding is from the port side, on the flat deck outboard of the airstair
	# rather than on the ramp itself, at the craft-local y of the parked contact
	# plane so the marker sits on the apron the crew member is standing on.
	if boarding != null:
		boarding.position = Vector3(-4.90, LANDING_CONTACT_Y, AIRSTAIR_Z)
	if exit != null:
		exit.position = Vector3(-5.60, LANDING_CONTACT_Y, AIRSTAIR_Z)
		exit.rotation.y = -PI * 0.5
	if left_muzzle != null:
		left_muzzle.position = DEFENSIVE_MUZZLE_POSITIONS[0]
	if right_muzzle != null:
		right_muzzle.position = DEFENSIVE_MUZZLE_POSITIONS[1]
	var boarding_area := get_node_or_null("ShipBoardingArea") as Area3D
	if boarding_area != null:
		boarding_area.position = Vector3(-4.90, LANDING_CONTACT_Y + 0.50, AIRSTAIR_Z)
		_add_deck_approach_range(boarding_area)
	var camera_rig := get_node_or_null("CameraRig") as Node3D
	if camera_rig != null:
		camera_rig.position = Vector3(0.0, 3.60, 8.20)


## HALYARD-BOARDING-001. The fleet-wide boarding volume is one 4.5 m sphere on
## the craft's own boarding marker, and on a 28.35 m transport that is not a
## marker in the wrong place — it is a marker of the wrong *size*.
##
## This craft's marker is correctly sited: local (-4.90, -0.58, -4.80), out on the
## port lane 2.18 m clear of the port hull wall, at the foot of the airstair the
## crew actually board by. Nothing is wrong with it. But a 4.5 m sphere there
## covers world z = 44.0 … 53.0 of a craft that runs z = 39.45 … 67.8. The whole
## aft two thirds of the hull and the entire starboard flank fall outside it, and
## the ring sample over the live berth measured the result exactly: 5 of 14
## standable points around the parked craft offered the prompt, and every silent
## one was aft of the wing or on the wrong side.
##
## Proportion is the whole of it. The same 4.5 m sphere on the 12.2 m Arrow
## reaches nose to tail; here it reaches 32% of the length. So the sphere is left
## exactly as inherited — it is a published fleet-wide contract that
## `boarding_accessibility_test` pins by name at `BoardingRange` — and a
## craft-shaped approach volume is added beside it, as the Arrow's pass did.
##
## Sized to the craft plus a walk-up margin, not to the deck — the same rule the
## Arrow's `ArrowApproachRange` was cut to, and it matters here because the deck
## is now 34.4 m long and a volume sized to *that* would prompt from the far side
## of the comb trunk, twenty metres from the hatch.
##
## Half extents 4.6 laterally and 12.0 along the hull, against a hull of 4.8 and
## 14.5. With the production player's own 2.35 m interaction sphere that reaches
## 6.95 and 14.35, which covers the full 12 m width of the pad (half extent 6.0)
## on both flanks, the whole tail apron, and the deck ahead of the bow collar,
## whose forward face stands at local z = -14.15. It is centred on the hull, not
## on the marker, expressed relative to the area's offset so the marker keeps
## publishing the same world position and `get_boarding_position()` is untouched.
##
## What it deliberately does not reach is the outer 2.65 m of the nose apron and
## the outer 3.05 m of the comb trunk. Those are the walk-up: a player coming
## down the trunk to dock 02 crosses into the prompt 2.37 m after they start,
## which is what `fleet_role_differentiation_test` now stages and measures.
##
## Laterally it stops short of both neighbours: it reaches x = 43.95 against dock
## 03's slab at 46.0 and x = 30.05 against dock 01's at 28.0, so it cannot put
## this craft's prompt on the Zenith's pad.
func _add_deck_approach_range(boarding_area: Area3D) -> void:
	var existing := boarding_area.get_node_or_null("HalyardApproachRange")
	if existing != null:
		boarding_area.remove_child(existing)
		existing.queue_free()
	var approach := CollisionShape3D.new()
	approach.name = "HalyardApproachRange"
	var shape := BoxShape3D.new()
	shape.size = Vector3(9.2, 3.6, 24.0)
	approach.shape = shape
	approach.position = -boarding_area.position
	boarding_area.add_child(approach)


func _add_box_collision(
		node_name: String,
		collision_position: Vector3,
		size: Vector3,
		rotation_value := Vector3.ZERO
	) -> CollisionShape3D:
	var collision := CollisionShape3D.new()
	collision.name = node_name
	collision.position = collision_position
	collision.rotation = rotation_value
	var shape := BoxShape3D.new()
	shape.size = size
	collision.shape = shape
	add_child(collision)
	return collision


func _add_airstair_wedge_collision(
		node_name: String,
		outer_x: float,
		inner_x: float,
		bottom_y: float,
		outer_top_y: float,
		inner_top_y: float,
		center_z: float,
		half_width_z: float
	) -> CollisionShape3D:
	var collision := CollisionShape3D.new()
	collision.name = node_name
	var shape := ConvexPolygonShape3D.new()
	shape.points = PackedVector3Array([
		Vector3(outer_x, bottom_y, center_z - half_width_z),
		Vector3(outer_x, outer_top_y, center_z - half_width_z),
		Vector3(inner_x, bottom_y, center_z - half_width_z),
		Vector3(inner_x, inner_top_y, center_z - half_width_z),
		Vector3(outer_x, bottom_y, center_z + half_width_z),
		Vector3(outer_x, outer_top_y, center_z + half_width_z),
		Vector3(inner_x, bottom_y, center_z + half_width_z),
		Vector3(inner_x, inner_top_y, center_z + half_width_z),
	])
	collision.shape = shape
	add_child(collision)
	return collision


func _bind_optional_interior_frame() -> void:
	_moving_interior_component = get_node_or_null("MovingInteriorFrame") as MovingInteriorFrame
	if _moving_interior_component == null:
		_moving_interior_component = MovingInteriorFrame.new()
		_moving_interior_component.name = "MovingInteriorFrame"
		add_child(_moving_interior_component)
	_moving_interior_component.set_meta("frame_id", &"halyard_walkable_interior")
	# The volume is built after the pre-authored coordinator has run `_ready`, so
	# enable automatic monitoring before configure and let both signal wiring and
	# existing-overlap registration be active immediately.
	_moving_interior_component.auto_register_from_volume = true
	_moving_interior_component.configure(self, INTERIOR_BOUNDS, _occupant_volume)
	if not _moving_interior_component.occupant_registered.is_connected(_on_interior_occupant_registered):
		_moving_interior_component.occupant_registered.connect(_on_interior_occupant_registered)
	if not _moving_interior_component.occupant_unregistered.is_connected(_on_interior_occupant_unregistered):
		_moving_interior_component.occupant_unregistered.connect(_on_interior_occupant_unregistered)
	_sync_interior_occupant_collision()
	_moving_interior_component.call_deferred("_register_existing_overlaps")


func _on_interior_occupant_registered(_occupant: Node3D) -> void:
	_sync_interior_occupant_collision()


func _on_interior_occupant_unregistered(
		_occupant: Node3D,
		_exit_velocity: Vector3,
		_reason: StringName
	) -> void:
	_sync_interior_occupant_collision()


func _sync_interior_occupant_collision() -> void:
	_interior_occupant_count = (
		_moving_interior_component.get_occupant_count()
		if _moving_interior_component != null
		else 0
	)
	if is_destroyed():
		# A destroyed hull owns layer 0 / mask 0. Never re-arm it from here.
		return
	# A crew member standing on this ship's own deck must stop being an obstacle
	# to this ship's own `move_and_slide()` while it is under way. Counting
	# rather than latching keeps that correct for more than one occupant, which
	# is the point of a crew transport.
	collision_mask = (
		PhysicsLayers.SHIP_BODY_MASK & ~PhysicsLayers.PLAYER
		if _interior_occupant_count > 0
		else PhysicsLayers.SHIP_BODY_MASK
	)


func _set_interior_operational(enabled: bool) -> void:
	if not enabled:
		_clear_passenger_ping_markers(&"interior_unavailable")
		_clear_loadmaster_manifest(&"interior_unavailable")
		_passenger_ping_cooldowns.clear()
		_gunner_role_cooldowns.clear()
		_clear_gunner_target_selection(&"interior_unavailable")
		_clear_engineer_component_selection(&"interior_unavailable")
		_clear_pilot_command(&"interior_unavailable")
		if _crew_status_display != null and is_instance_valid(_crew_status_display):
			_crew_status_display.clear_for_detach()
	if _walkable_interior != null:
		_walkable_interior.visible = enabled
	if _occupant_volume != null:
		_occupant_volume.set_deferred(&"monitoring", enabled)
		for child in _occupant_volume.get_children():
			if child is CollisionShape3D:
				(child as CollisionShape3D).set_deferred(&"disabled", not enabled)
	if not enabled and _moving_interior_component != null:
		_moving_interior_component.clear_occupants(true, &"ship_destroyed")
	_sync_interior_occupant_collision()
	if enabled:
		refresh_crew_status_display()


func _cleanup_detached_passenger_pings() -> void:
	var tagged_occupancy_present := _cleanup_detached_crew_role_occupants()
	if _passenger_ping_markers.is_empty() \
			and _loadmaster_manifest_receipt.is_empty() \
			and _gunner_target_selection.is_empty() \
			and _engineer_component_selection.is_empty() \
			and _pilot_command_state.is_empty() \
			and not tagged_occupancy_present:
		return
	if _crew_role_authority == null:
		_clear_passenger_ping_markers(&"authority_detached")
		_clear_loadmaster_manifest(&"authority_detached")
		_clear_gunner_target_selection(&"authority_detached")
		_clear_engineer_component_selection(&"authority_detached")
		_clear_pilot_command(&"authority_detached")
		return
	var detached: Array[Dictionary] = []
	for marker_variant in _passenger_ping_markers.values():
		var marker := marker_variant as Dictionary
		var assignment := _crew_role_authority.get_assignment(
			int(marker.get("occupant_peer_id", 0)),
			StringName(marker.get("avatar_id", &""))
		)
		if assignment.is_empty():
			detached.append(marker)
	for marker in detached:
		_clear_crew_role_state(
			int(marker.get("occupant_peer_id", 0)),
			StringName(marker.get("avatar_id", &"")),
			&"role_detached"
		)
	if not _loadmaster_manifest_receipt.is_empty():
		var loadmaster_assignment := _crew_role_authority.get_assignment(
			int(_loadmaster_manifest_receipt.get("occupant_peer_id", 0)),
			StringName(_loadmaster_manifest_receipt.get("avatar_id", &""))
		)
		if loadmaster_assignment.is_empty() \
				or StringName(loadmaster_assignment.get("seat_id", &"")) != LOADMASTER_STATION_SEAT_ID:
			_clear_loadmaster_manifest(&"role_detached")
	if not _gunner_target_selection.is_empty():
		var target_assignment := _crew_role_authority.get_assignment(
			int(_gunner_target_selection.get("occupant_peer_id", 0)),
			StringName(_gunner_target_selection.get("avatar_id", &""))
		)
		if target_assignment.is_empty():
			_clear_crew_role_state(
				int(_gunner_target_selection.get("occupant_peer_id", 0)),
				StringName(_gunner_target_selection.get("avatar_id", &"")),
				&"role_detached"
			)
	if not _engineer_component_selection.is_empty():
		var component_assignment := _crew_role_authority.get_assignment(
			int(_engineer_component_selection.get("occupant_peer_id", 0)),
			StringName(_engineer_component_selection.get("avatar_id", &""))
		)
		if component_assignment.is_empty():
			_clear_crew_role_state(
				int(_engineer_component_selection.get("occupant_peer_id", 0)),
				StringName(_engineer_component_selection.get("avatar_id", &"")),
				&"role_detached"
			)
	if not _pilot_command_state.is_empty():
		var pilot_assignment := _crew_role_authority.get_assignment(
			int(_pilot_command_state.get("occupant_peer_id", 0)),
			StringName(_pilot_command_state.get("avatar_id", &""))
		)
		if pilot_assignment.is_empty():
			_clear_crew_role_state(
				int(_pilot_command_state.get("occupant_peer_id", 0)),
				StringName(_pilot_command_state.get("avatar_id", &"")),
				&"role_detached"
			)


func _cleanup_detached_crew_role_occupants() -> bool:
	if _moving_interior_component == null or not is_instance_valid(_moving_interior_component):
		return false
	var tagged_occupancy_present := false
	for occupant in _moving_interior_component.get_registered_occupants():
		if not occupant.has_meta(HALYARD_CREW_ROLE_OCCUPANT_META):
			continue
		tagged_occupancy_present = true
		var metadata := occupant.get_meta(HALYARD_CREW_ROLE_OCCUPANT_META, {}) as Dictionary
		var assignment := _crew_role_authority.get_assignment(
			int(metadata.get("occupant_peer_id", 0)),
			StringName(metadata.get("avatar_id", &""))
		) if _crew_role_authority != null else {}
		if assignment.is_empty() \
				or StringName(assignment.get("seat_id", &"")) != StringName(metadata.get("seat_id", &"")):
			_moving_interior_component.unregister_occupant(occupant, false, &"role_detached")
			occupant.remove_meta(HALYARD_CREW_ROLE_OCCUPANT_META)
	return tagged_occupancy_present


func _clear_passenger_ping_for_actor(
		occupant_peer_id: int,
		avatar_id: StringName,
		reason: StringName
) -> void:
	var key := _passenger_ping_actor_key(occupant_peer_id, avatar_id)
	if not _passenger_ping_markers.has(key):
		return
	var marker := _passenger_ping_markers[key] as Dictionary
	_passenger_ping_markers.erase(key)
	passenger_cabin_ping_cleared.emit(
		StringName(marker.get("marker_id", &"")),
		reason,
		occupant_peer_id,
		avatar_id
	)


func _clear_crew_role_state(
	occupant_peer_id: int,
	avatar_id: StringName,
	reason: StringName
) -> void:
	var actor_key := _crew_role_actor_key_from_values(occupant_peer_id, avatar_id)
	_passenger_ping_cooldowns.erase(actor_key)
	_gunner_role_cooldowns.erase(actor_key)
	_clear_passenger_ping_for_actor(occupant_peer_id, avatar_id, reason)
	if _crew_role_state_matches_actor(_loadmaster_manifest_receipt, occupant_peer_id, avatar_id):
		_clear_loadmaster_manifest(reason)
	if not _gunner_target_selection.is_empty() \
			and int(_gunner_target_selection.get("occupant_peer_id", 0)) == occupant_peer_id \
			and StringName(_gunner_target_selection.get("avatar_id", &"")) == avatar_id:
		_clear_gunner_target_selection(reason)
	if not _engineer_component_selection.is_empty() \
			and int(_engineer_component_selection.get("occupant_peer_id", 0)) == occupant_peer_id \
			and StringName(_engineer_component_selection.get("avatar_id", &"")) == avatar_id:
		_clear_engineer_component_selection(reason)
	if not _pilot_command_state.is_empty() \
			and int(_pilot_command_state.get("occupant_peer_id", 0)) == occupant_peer_id \
			and StringName(_pilot_command_state.get("avatar_id", &"")) == avatar_id:
		_clear_pilot_command(reason)
	if not _emergency_pilot_handoff_state.is_empty() \
			and int(_emergency_pilot_handoff_state.get("occupant_peer_id", 0)) == occupant_peer_id \
			and StringName(_emergency_pilot_handoff_state.get("avatar_id", &"")) == avatar_id:
		_clear_emergency_pilot_handoff_state()
	refresh_crew_status_display()


func _advance_crew_role_cooldowns(delta: float) -> void:
	for cooldowns in [_passenger_ping_cooldowns, _gunner_role_cooldowns]:
		var expired: Array[StringName] = []
		for key_variant in cooldowns.keys():
			var key := StringName(key_variant)
			var remaining := maxf(0.0, float(cooldowns[key]) - delta)
			if remaining <= 0.0:
				expired.append(key)
			else:
				cooldowns[key] = remaining
		for key in expired:
			cooldowns.erase(key)


func _clear_passenger_ping_markers(reason: StringName) -> void:
	var actors: Array[Dictionary] = []
	for marker_variant in _passenger_ping_markers.values():
		actors.append(marker_variant as Dictionary)
	for marker in actors:
		_clear_passenger_ping_for_actor(
			int(marker.get("occupant_peer_id", 0)),
			StringName(marker.get("avatar_id", &"")),
			reason
		)


func _clear_loadmaster_manifest(reason: StringName, advance_generation: bool = true) -> void:
	_loadmaster_manifest_receipt.clear()
	if advance_generation:
		_loadmaster_manifest_generation = mini(
			_loadmaster_manifest_generation + 1,
			LOADMASTER_MANIFEST_GENERATION_MAX
		)
	_clear_loadmaster_station_display(reason)
	loadmaster_manifest_cleared.emit(_loadmaster_manifest_generation, reason)


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


func _clear_engineer_component_selection(
	reason: StringName,
	advance_generation: bool = true
) -> void:
	if _engineer_component_selection.is_empty():
		if advance_generation:
			_engineer_component_generation = mini(
				_engineer_component_generation + 1,
				MAX_GUNNER_TARGET_GENERATION
			)
		return
	var component_id := StringName(_engineer_component_selection.get("component_id", &""))
	var component_generation := int(
		_engineer_component_selection.get("component_generation", 0)
	)
	var route := StringName(_engineer_component_selection.get("power_route", &"none"))
	_engineer_component_selection.clear()
	engineer_component_cleared.emit(component_id, component_generation, reason)
	engineer_power_route_changed.emit(
		component_id,
		&"none",
		0.0,
		{
			"component_id": component_id,
			"component_generation": component_generation,
			"previous_route": route,
			"reason": reason,
		}.duplicate(true)
	)
	if advance_generation:
		_engineer_component_generation = mini(
			_engineer_component_generation + 1,
			MAX_GUNNER_TARGET_GENERATION
		)


func _clear_pilot_command(_reason: StringName) -> void:
	if _pilot_command_source != null and is_instance_valid(_pilot_command_source):
		_pilot_command_source.clear_held_controls()
	_pilot_command_state.clear()
	_pilot_last_request_sequence = -1
	_pilot_command_seat_generation = 0
	if _piloted:
		set_piloted(false)


func _clear_emergency_pilot_handoff_state() -> void:
	_emergency_pilot_handoff_state.clear()


static func _passenger_ping_actor_key(occupant_peer_id: int, avatar_id: StringName) -> StringName:
	return StringName("%d:%s" % [occupant_peer_id, str(avatar_id)])


static func _crew_role_actor_key(intent: Dictionary) -> StringName:
	return _crew_role_actor_key_from_values(
		int(intent.get("occupant_peer_id", 0)),
		StringName(intent.get("avatar_id", &""))
	)


static func _crew_role_actor_key_from_values(
	occupant_peer_id: int,
	avatar_id: StringName
) -> StringName:
	return StringName("%d:%s" % [occupant_peer_id, str(avatar_id)])


static func _crew_role_state_matches_actor(
	state: Variant,
	occupant_peer_id: int,
	avatar_id: StringName
) -> bool:
	if not state is Dictionary or (state as Dictionary).is_empty():
		return false
	var record := state as Dictionary
	return int(record.get("occupant_peer_id", 0)) == occupant_peer_id \
		and StringName(record.get("avatar_id", &"")) == avatar_id


# ---------------------------------------------------------- presentation ----


func _update_halyard_presentation(_delta: float) -> void:
	var telemetry := get_telemetry()
	var engine_state := StringName(telemetry.get("engine_state", &"OFFLINE"))
	var engine_level := 0.0
	if engine_state == ENGINE_STARTING:
		# The longest spool in the fleet, so the run-up is worth showing.
		engine_level = 0.16 + 0.10 * sin(_elapsed_halyard * 7.0)
	elif engine_state == ENGINE_ONLINE:
		engine_level = 0.42 + clampf(velocity.length() / maxf(maximum_speed, 1.0), 0.0, 1.0) * 0.58
	if is_destroyed():
		engine_level = 0.0
	_apply_engine_level(engine_level)


func _sync_halyard_engine_presentation_immediately() -> void:
	var engine_state := StringName(get_telemetry().get("engine_state", &"OFFLINE"))
	var engine_level := 0.0
	if engine_state == ENGINE_STARTING:
		engine_level = 0.2
	elif engine_state == ENGINE_ONLINE:
		engine_level = 0.42
	if is_destroyed():
		engine_level = 0.0
	_apply_engine_level(engine_level)


func _apply_engine_level(engine_level: float) -> void:
	for plume in _engine_plumes:
		if not is_instance_valid(plume):
			continue
		plume.visible = engine_level > 0.02
		plume.scale = Vector3(1.0, 0.35 + engine_level * 1.55, 1.0)
	for core in _engine_cores:
		if is_instance_valid(core):
			core.visible = engine_level > 0.01
	for light in _halyard_engine_lights:
		if is_instance_valid(light):
			light.light_energy = engine_level * 2.4


func _sync_variant_engine_presentation_immediately() -> void:
	_sync_halyard_engine_presentation_immediately()


func _apply_halyard_metadata() -> void:
	set_meta("evidence_status", EVIDENCE_STATUS)
	set_meta("evidence_scope", EVIDENCE_SCOPE)
	set_meta("name_to_model_status", NAME_TO_MODEL_STATUS)
	set_meta("authenticated_historical_silhouette", false)
	set_meta("historical_claim", false)
	set_meta("content_note", DESIGN_NOTE)


# --------------------------------------------------------------- helpers ----


func _halyard_material(
		color: Color,
		metallic: float,
		roughness: float,
		emission := Color.BLACK,
		energy := 0.0
	) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.metallic = clampf(metallic, 0.0, 1.0)
	material.roughness = clampf(roughness, 0.04, 1.0)
	material.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL
	material.diffuse_mode = BaseMaterial3D.DIFFUSE_BURLEY
	material.specular_mode = BaseMaterial3D.SPECULAR_SCHLICK_GGX
	if energy > 0.0:
		material.emission_enabled = true
		material.emission = emission
		material.emission_energy_multiplier = energy
	return material


func _halyard_glass(color: Color) -> StandardMaterial3D:
	var material := _halyard_material(color, 0.10, 0.09, Color("1d4740"), 0.18)
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.cull_mode = BaseMaterial3D.CULL_BACK
	material.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	material.render_priority = 1
	return material


## Chamfered box built by the shared `StationSurfaceKit`.
##
## This deliberately shadows `HeroShip._box`, which routes through the
## controller's own private `_rounded_box_mesh`. That copy emits its two
## triangles in `0-1-2 / 0-2-3` order, which is precisely the order the kit
## documents as the reversed case it had to fix — with the same vertex normals,
## that winding disagrees with the outward normal on all six faces. Every box on
## this craft therefore goes through `StationSurfaceKit.rounded_box_mesh_cached`,
## whose emission order (`0-2-1 / 0-3-2`) is the one
## `tests/station_surface_winding_test.gd` calibrates against the engine's own
## primitives. `tests/halyard_crew_transport_test.gd` re-measures every mesh this
## craft builds against that same calibration, so the craft cannot regress into
## the reversed builder.
func _box(
		parent: Node3D,
		node_name: String,
		box_position: Vector3,
		size: Vector3,
		material: Material,
		rotation_value := Vector3.ZERO
	) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.name = node_name
	instance.position = box_position
	instance.rotation = rotation_value
	var mesh := StationSurfaceKit.rounded_box_mesh_cached(size, _box_mesh_cache)
	instance.mesh = mesh
	instance.material_override = material
	parent.add_child(instance)
	return instance


## One renderer allocation for repeated, childless, non-colliding visual stock.
## The authored transforms remain in parent space and the explicit union keeps
## Forward+ culling equivalent even when raw buffer assignment does not rebuild
## the CPU-side bounds under headless.
func _multimesh_visual_stock(
		parent: Node3D,
		node_name: String,
		mesh: Mesh,
		material: Material,
		transforms: Array[Transform3D],
		authored_names: PackedStringArray
	) -> MultiMeshInstance3D:
	var multi := MultiMesh.new()
	multi.transform_format = MultiMesh.TRANSFORM_3D
	multi.mesh = mesh
	multi.instance_count = transforms.size()
	multi.visible_instance_count = -1
	multi.buffer = _encode_multimesh_transforms(transforms)
	multi.custom_aabb = _transformed_mesh_bounds(mesh.get_aabb(), transforms)
	var batch := MultiMeshInstance3D.new()
	batch.name = node_name
	batch.multimesh = multi
	batch.material_override = material
	batch.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	batch.layers = 1
	batch.set_meta("visual_detail_only", true)
	batch.set_meta("authored_visual_names", authored_names.duplicate())
	batch.set_meta("authored_instance_transforms", transforms.duplicate())
	parent.add_child(batch)
	return batch


func _encode_multimesh_transforms(transforms: Array[Transform3D]) -> PackedFloat32Array:
	var buffer := PackedFloat32Array()
	buffer.resize(transforms.size() * 12)
	for index in transforms.size():
		var value := transforms[index]
		var offset := index * 12
		buffer[offset + 0] = value.basis.x.x
		buffer[offset + 1] = value.basis.y.x
		buffer[offset + 2] = value.basis.z.x
		buffer[offset + 3] = value.origin.x
		buffer[offset + 4] = value.basis.x.y
		buffer[offset + 5] = value.basis.y.y
		buffer[offset + 6] = value.basis.z.y
		buffer[offset + 7] = value.origin.y
		buffer[offset + 8] = value.basis.x.z
		buffer[offset + 9] = value.basis.y.z
		buffer[offset + 10] = value.basis.z.z
		buffer[offset + 11] = value.origin.z
	return buffer


func _transformed_mesh_bounds(mesh_bounds: AABB, transforms: Array[Transform3D]) -> AABB:
	var result := AABB()
	var first := true
	for value in transforms:
		var transformed := (value * mesh_bounds).abs()
		if first:
			result = transformed
			first = false
		else:
			result = result.merge(transformed)
	return result
