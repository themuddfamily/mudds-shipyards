class_name StationOperationsActivity
extends Node3D

## Reusable station-operations presentation vignette.
##
## This component supplies visible maintenance motion without owning gameplay,
## navigation, docking, or collision. Profiles may declare solid-looking static
## volumes for an owning world to realise beside the component, but the activity
## subtree itself remains collision-free. Its deterministic clock can be advanced
## manually for captures, tests, replays, and future network presentation.

## Emitted whenever the component's enabled/tree state or local transform changes.
## An owning world uses this to keep its sibling collision body visible in physics
## exactly when the presentation it represents exists, without moving collision
## authority into this component.
signal solid_volume_state_changed(active: bool, activity_global_transform: Transform3D)

const SCHEMA_VERSION := 1
const COMPONENT_ID: StringName = &"station-operations-activity"
const EVIDENCE_STATUS: StringName = &"modern_interpretation"
const DEFAULT_VARIATION_SEED := 29173
const PresentationBuilder := preload(
	"res://scripts/world/station_operations_activity_presentation_builder.gd"
)

enum ActivityProfile {
	FULL,
	GANTRY,
	SERVICE_ARM,
	DRONE_PATROL,
	CARGO_LINE,
	SIGNAGE_PYLON,
	OBSERVATORY,
	CREW_WORKPOST,
	CARGO_LINE_LONG,
}

const PROFILE_IDS := {
	ActivityProfile.FULL: &"full",
	ActivityProfile.GANTRY: &"gantry",
	ActivityProfile.SERVICE_ARM: &"service_arm",
	ActivityProfile.DRONE_PATROL: &"drone_patrol",
	ActivityProfile.CARGO_LINE: &"cargo_line",
	ActivityProfile.SIGNAGE_PYLON: &"signage_pylon",
	ActivityProfile.OBSERVATORY: &"observatory",
	ActivityProfile.CREW_WORKPOST: &"crew_workpost",
	ActivityProfile.CARGO_LINE_LONG: &"cargo_line_long",
}

## Movers and material-swapped lenses each station-life profile is required to
## build. The four original profiles predate this table and keep their bespoke
## gantry/arm/drone accessors; everything added afterwards is described here so a
## new beat is one data row plus one builder rather than five parallel edits.
const PROFILE_STATION_LIFE_COUNTS := {
	ActivityProfile.CARGO_LINE: {"movers": 2, "lenses": 2},
	ActivityProfile.SIGNAGE_PYLON: {"movers": 1, "lenses": 5},
	ActivityProfile.OBSERVATORY: {"movers": 2, "lenses": 1},
	ActivityProfile.CREW_WORKPOST: {"movers": 2, "lenses": 1},
	ActivityProfile.CARGO_LINE_LONG: {"movers": 2, "lenses": 2},
}

const FOOTPRINT_MIN := Vector3(-5.4, 0.0, -4.5)
const FOOTPRINT_MAX := Vector3(5.9, 7.25, 4.5)
const SERVICE_ZONE_CENTER := Vector3(0.0, 2.9, 0.0)
const SERVICE_ZONE_HALF_EXTENTS := Vector3(5.9, 3.8, 5.0)

const GANTRY_TRAVEL := 3.15
const GANTRY_ELEVATION := 5.78
const DRONE_COUNT := 2
## FULL is mounted in Central's walkable service court. Its original 1.48 m
## orbit put the cargo pod and pulsing navigation lens through the authored
## walking-camera sweep, so a lens could fill the near plane as a red slice.
## Re-frozen 1.48 -> 3.75 m: the lowest point of the whole drone now clears the
## production camera's 2.843 m default boom/sphere/margin/near sweep. The
## dedicated roof-patrol profile deliberately retains its authored 1.48 m
## mount-relative route; its world mount already supplies the roof elevation.
const FULL_DRONE_BASE_ELEVATION := 3.75
const ROOF_PATROL_DRONE_BASE_ELEVATION := 1.48
const BEACON_COUNT := 4
## Half the safety beacon `Base` pedestal height (0.18 m), so the pedestal's
## underside rests on this component's mounting plane instead of hovering. See
## `_get_beacon_positions()` and MAP-005 in `bugs.md`.
const BEACON_SEAT_HEIGHT := 0.09
const RECOMMENDED_MAX_INSTANCES := 6

## The catalog is process-wide because every entry is an immutable visible
## recipe. Instances receive a shallow dictionary copy, so their key roster
## cannot affect a peer, while every value is the same retained Material. Runtime
## animation remains per instance and swaps only MeshInstance3D overrides.
static var _shared_material_catalog: Dictionary = {}

## Exact, not merely bounding: `get_validation_errors()` rejects a live count that
## differs from its profile row in either direction.
##
## Re-frozen by the station-life pass. `unique_materials` went 12 -> 17 on all
## four original profiles because the component's material set is built whole
## regardless of profile, and the pass added `crate`, `crate_alt`, `green_dim`,
## `green_lit` and `sign_lit`. That is a real cost the audit is designed to
## report rather than hide — it already counts momentarily unassigned beacon
## variants for the same reason — and no original profile's node, mesh or
## animated-assembly count moved. The four new rows were measured against the
## live builds: 58/47, 43/33, 44/33 and 59/48 nodes/meshes.
##
## Re-frozen again by the long-cargo pass, which added two keys to every row
## rather than to one. `multimesh_batches` is the number of `MultiMeshInstance3D`
## nodes a profile builds and `multimesh_instances` the number of copies those
## batches draw. They are 0 on the seven profiles whose geometry is untouched, and
## the audit is stricter for carrying them: a batch is one draw submission but
## many bodies, and only the pair says which.
##
## `CARGO_LINE` moved, and nothing about it is drawn differently. Its five rail
## ties, four sled wheels, two container ribs and two hoist post bands were
## already thirteen copies of four meshes at four sizes; they are now four
## instanced batches of the same meshes at the same sizes, positions and
## materials. `node_count` 58 -> 49, `mesh_instances` 47 -> 34,
## `multimesh_batches` 0 -> 4, `multimesh_instances` 0 -> 13. That is nine fewer
## draw submissions for a pixel-identical result, and it is what paid for most of
## the second long line. Solid volumes were deliberately left un-instanced; see
## `get_solid_volume_contract()`.
##
## The `CARGO_LINE_LONG` row was measured against its live build: 54/39, four
## batches drawing 22 copies.
##
## The crew-workpost trim pass changes only the five identical graphite tools
## hung on its fixed tool wall. Their five authored meshes are now one batch of
## the same cached mesh at the same five transforms and material. The family is
## decorative stock: it is absent from `get_solid_volume_contract()`, and is not
## a mover, lens, collider, or lifecycle/authority node. `node_count` 59 -> 55,
## `mesh_instances` 48 -> 43, `multimesh_batches` 0 -> 1, and
## `multimesh_instances` 0 -> 5: four fewer renderer submissions with the same
## five visible copies.
##
## The gantry safety-band pass changes only the four childless orange bands at
## the column feet. Foot pads retain their support-test paths, columns retain the
## owning world's solid-volume contract, and column-edge names remain available
## to obstruction captures. FULL/GANTRY each move by the same exact delta:
## `node_count` -3, `mesh_instances` -4, `multimesh_batches` +1 and
## `multimesh_instances` +4. Four visible copies and their shared cached mesh
## remain; submissions fall by three.
const PROFILE_PERFORMANCE_BUDGETS := {
	ActivityProfile.FULL: {
		"node_count": 93,
		"mesh_instances": 75,
		"unique_materials": 17,
		"lights": 0,
		"particle_emitters": 0,
		"collision_nodes": 0,
		"multimesh_batches": 1,
		"multimesh_instances": 4,
		"geometry_submissions": 76,
		"drawn_copies": 79,
		"animated_assemblies": 5,
	},
	ActivityProfile.GANTRY: {
		"node_count": 56,
		"mesh_instances": 44,
		"unique_materials": 17,
		"lights": 0,
		"particle_emitters": 0,
		"collision_nodes": 0,
		"multimesh_batches": 1,
		"multimesh_instances": 4,
		"geometry_submissions": 45,
		"drawn_copies": 48,
		"animated_assemblies": 1,
	},
	ActivityProfile.SERVICE_ARM: {
		"node_count": 31,
		"mesh_instances": 19,
		"unique_materials": 17,
		"lights": 0,
		"particle_emitters": 0,
		"collision_nodes": 0,
		"multimesh_batches": 0,
		"multimesh_instances": 0,
		"geometry_submissions": 19,
		"drawn_copies": 19,
		"animated_assemblies": 2,
	},
	ActivityProfile.DRONE_PATROL: {
		"node_count": 42,
		"mesh_instances": 32,
		"unique_materials": 17,
		"lights": 0,
		"particle_emitters": 0,
		"collision_nodes": 0,
		"multimesh_batches": 0,
		"multimesh_instances": 0,
		"geometry_submissions": 32,
		"drawn_copies": 32,
		"animated_assemblies": 2,
	},
	ActivityProfile.CARGO_LINE: {
		"node_count": 49,
		"mesh_instances": 34,
		"unique_materials": 17,
		"lights": 0,
		"particle_emitters": 0,
		"collision_nodes": 0,
		"multimesh_batches": 4,
		"multimesh_instances": 13,
		"geometry_submissions": 38,
		"drawn_copies": 47,
		"animated_assemblies": 2,
	},
	ActivityProfile.SIGNAGE_PYLON: {
		"node_count": 43,
		"mesh_instances": 33,
		"unique_materials": 17,
		"lights": 0,
		"particle_emitters": 0,
		"collision_nodes": 0,
		"multimesh_batches": 0,
		"multimesh_instances": 0,
		"geometry_submissions": 33,
		"drawn_copies": 33,
		"animated_assemblies": 1,
	},
	ActivityProfile.OBSERVATORY: {
		"node_count": 44,
		"mesh_instances": 33,
		"unique_materials": 17,
		"lights": 0,
		"particle_emitters": 0,
		"collision_nodes": 0,
		"multimesh_batches": 0,
		"multimesh_instances": 0,
		"geometry_submissions": 33,
		"drawn_copies": 33,
		"animated_assemblies": 2,
	},
	ActivityProfile.CREW_WORKPOST: {
		"node_count": 55,
		"mesh_instances": 43,
		"unique_materials": 17,
		"lights": 0,
		"particle_emitters": 0,
		"collision_nodes": 0,
		"multimesh_batches": 1,
		"multimesh_instances": 5,
		"geometry_submissions": 44,
		"drawn_copies": 48,
		"animated_assemblies": 2,
	},
	ActivityProfile.CARGO_LINE_LONG: {
		"node_count": 54,
		"mesh_instances": 39,
		"unique_materials": 17,
		"lights": 0,
		"particle_emitters": 0,
		"collision_nodes": 0,
		"multimesh_batches": 4,
		"multimesh_instances": 22,
		"geometry_submissions": 43,
		"drawn_copies": 61,
		"animated_assemblies": 2,
	},
}

## Re-frozen by the long-cargo pass, 8 -> 10 placements. Both additions are
## `cargo_line_long`, because the request was for more of the same beat over a
## longer run rather than for a new role.
##
##   `instance_count` 8 -> 10.
##   `node_count` 432 -> 531: -9 as `cargo_line` instanced its repeats, +2 x 54.
##   `mesh_instances` 339 -> 404: -13 from the same instancing, +2 x 39.
##   `unique_materials` was historically 136 -> 170 because the same 17-entry
##     catalog was rebuilt per placement. Catalog sharing later reduced the
##     retained production-roster total 170 -> 17 without changing any binding.
##   `animated_assemblies` 17 -> 21: +2 x 2, a sled and a hoist each.
##   `multimesh_batches` 0 -> 12 and `multimesh_instances` 0 -> 57.
##
## In draw submissions that is 339 -> 416 for the whole roster: 38 for the short
## line where it used to be 47, and 43 for each 21.6 m run where the same
## geometry drawn one mesh at a time would have cost 61.
##
## The crew-workpost trim pass then moved the recommended roster exactly once:
## `node_count` 531 -> 527, `mesh_instances` 404 -> 399,
## `multimesh_batches` 12 -> 13, and `multimesh_instances` 57 -> 62. Counting
## one renderer submission per drawn mesh or batch, the roster is 416 -> 412.
##
## The two production placements that carry a gantry then apply the safety-band
## delta twice: nodes 527 -> 521, MeshInstances 399 -> 391, batches 13 -> 15,
## batched copies 62 -> 70, and submissions 412 -> 406. Total drawn copies stay
## 461; collision declarations, movers, lenses and materials do not change.
const RECOMMENDED_PRODUCTION_ROSTER_BUDGET := {
	"instance_count": 10,
	"node_count": 521,
	"mesh_instances": 391,
	"unique_materials": 17,
	"lights": 0,
	"particle_emitters": 0,
	"collision_nodes": 0,
	"multimesh_batches": 15,
	"multimesh_instances": 70,
	"geometry_submissions": 406,
	"drawn_copies": 461,
	"animated_assemblies": 21,
}

## Exactly how many placements of each profile the recommended roster carries.
##
## This replaces a flat "exactly one of every profile" rule. That rule was a
## proxy for role differentiation, and it stopped being the right proxy the
## moment the roster deliberately carried the same beat twice: it would have read
## a second cargo run as a defect rather than as the point. The equality is not
## loosened into a range, only moved — each profile still has an exact required
## count, and a live count that differs in either direction is still an error.
const RECOMMENDED_PRODUCTION_ROSTER_PROFILE_COUNTS := {
	&"full": 1,
	&"gantry": 1,
	&"service_arm": 1,
	&"drone_patrol": 1,
	&"cargo_line": 1,
	&"signage_pylon": 1,
	&"observatory": 1,
	&"crew_workpost": 1,
	&"cargo_line_long": 2,
}

const CONTENT_NOTE := (
	"The remake brief supports richer station machinery, docking equipment, cargo, "
	+ "animated equipment, landing lights, and ambient station activity. It does not "
	+ "authenticate this gantry, articulated service arm, drones, beacon arrangement, "
	+ "cargo transfer lines of either length, wayfinding pylon, skywatch post, crew work post, "
	+ "dimensions, motion, colours, or placement. Every visible detail in this reusable "
	+ "component is an original modern interpretation and not recovered station geometry."
)

@export_category("Activity")
@export_enum(
	"Full:0",
	"Gantry:1",
	"Service Arm:2",
	"Drone Patrol:3",
	"Cargo Line:4",
	"Signage Pylon:5",
	"Observatory:6",
	"Crew Workpost:7",
	"Cargo Line Long:8"
) var activity_profile: int = ActivityProfile.FULL
@export var starts_enabled := true
@export var starts_paused := false
@export_range(0.1, 3.0, 0.05) var playback_speed := 1.0
@export_range(0, 999999, 1) var variation_seed := DEFAULT_VARIATION_SEED

@onready var _mount_anchor: Marker3D = get_node(^"MountAnchor") as Marker3D
@onready var _service_zone_anchor: Marker3D = get_node(^"ServiceZoneAnchor") as Marker3D
@onready var _presentation_root: Node3D = get_node(^"PresentationRoot") as Node3D

var _materials: Dictionary = {}
var _gantry_carriage: Node3D
var _gantry_tool: Node3D
var _service_arm_shoulder: Node3D
var _service_arm_elbow: Node3D
var _service_arm_tool: Node3D
var _drone_roots: Array[Node3D] = []
var _drone_beacon_lenses: Array[MeshInstance3D] = []
var _beacon_lenses: Array[MeshInstance3D] = []
## Station-life movers in the fixed build order each `_build_*` function emits.
## `_station_life_mover_pose()` is the single source of every one of their poses;
## both the clock update and the audit's pose check read it, so a mover cannot
## drift from the state the audit believes it is in.
var _station_life_movers: Array[Node3D] = []
var _station_life_lenses: Array[MeshInstance3D] = []
## One `{dim, lit, period, duty, offset}` row per entry in `_station_life_lenses`.
var _station_life_lens_specs: Array[Dictionary] = []
var _presentation_builder: PresentationBuilder
var _elapsed := 0.0
var _activity_enabled := true
var _activity_paused := false
var _enabled_overridden := false
var _paused_overridden := false
var _built_profile := ActivityProfile.FULL
var _built_starts_enabled := true
var _built_starts_paused := false
var _built_playback_speed := 1.0
var _built_variation_seed := DEFAULT_VARIATION_SEED
var _built := false
var _built_node_instance_ids: Dictionary = {}
var _built_static_node_transforms: Dictionary = {}
var _built_node_visibility: Dictionary = {}
var _built_mesh_contracts: Dictionary = {}
## Instanced structure gets its own contract rather than riding on the mesh one.
## A `MultiMeshInstance3D` is not a `MeshInstance3D`, so without this every batch
## would silently escape the drift check, the envelope check and the mesh-count
## equality that the drawn geometry has to satisfy.
var _built_multimesh_contracts: Dictionary = {}
## The authored copy of every batch's instance transforms, keyed by the
## `MultiMeshInstance3D`'s instance id.
##
## The audit reads this rather than `MultiMesh.get_instance_transform()` because
## the buffer lives on the rendering server: under `--headless`, where the whole
## test matrix runs, `buffer` comes back empty and every instance reads as
## identity. Auditing that would be worse than not auditing it — it would pass
## vacuously in CI and disagree with what the player's build actually draws. What
## is held here is the geometry this component authored, and the envelope check,
## the drift check and the rendered captures all agree on it.
var _multimesh_batch_transforms: Dictionary = {}
var _built_material_contracts: Dictionary = {}


func _enter_tree() -> void:
	# `_ready()` only runs on the first tree entry. Restore the component's
	# desired process state when an owning world removes and re-adds this child.
	if _built:
		set_notify_transform(true)
		_refresh_lifecycle()


func _ready() -> void:
	add_to_group(&"station_operations_activity", false)
	if _built:
		return
	_built = true
	set_notify_transform(true)
	_built_profile = activity_profile
	_built_starts_enabled = starts_enabled
	_built_starts_paused = starts_paused
	_built_playback_speed = playback_speed
	_built_variation_seed = variation_seed
	_presentation_builder = PresentationBuilder.new()
	_presentation_builder.build(
		_presentation_root,
		PROFILE_IDS.get(_built_profile, &"invalid") as StringName,
		DRONE_COUNT,
		BEACON_SEAT_HEIGHT,
		_shared_material_catalog
	)
	_adopt_presentation_builder_state()
	if _shared_material_catalog.is_empty():
		_shared_material_catalog = _materials.duplicate(false)
	_service_zone_anchor.position = _get_profile_service_zone_center()
	_apply_evidence_metadata()
	if not _enabled_overridden:
		_activity_enabled = starts_enabled
	if not _paused_overridden:
		_activity_paused = starts_paused
	_update_activity_transforms()
	_refresh_lifecycle()
	_capture_built_presentation_contract()


func _adopt_presentation_builder_state() -> void:
	_materials = _presentation_builder.get_materials()
	_gantry_carriage = _presentation_builder.get_gantry_carriage()
	_gantry_tool = _presentation_builder.get_gantry_tool()
	_service_arm_shoulder = _presentation_builder.get_service_arm_shoulder()
	_service_arm_elbow = _presentation_builder.get_service_arm_elbow()
	_service_arm_tool = _presentation_builder.get_service_arm_tool()
	_drone_roots = _presentation_builder.get_drone_roots()
	_drone_beacon_lenses = _presentation_builder.get_drone_beacon_lenses()
	_beacon_lenses = _presentation_builder.get_beacon_lenses()
	_station_life_movers = _presentation_builder.get_station_life_movers()
	_station_life_lenses = _presentation_builder.get_station_life_lenses()
	_station_life_lens_specs = _presentation_builder.get_station_life_lens_specs()
	_multimesh_batch_transforms = _presentation_builder.get_multimesh_batch_transforms()


func _process(delta: float) -> void:
	advance_activity_simulation(delta * _get_effective_playback_speed())


func _exit_tree() -> void:
	# The owning world's solid body is a sibling, so it does not leave the tree
	# when this component alone is detached. Publish the absence before exit to
	# prevent an invisible obstacle until the component is re-added.
	solid_volume_state_changed.emit(false, global_transform)
	set_process(false)


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSFORM_CHANGED and _built and is_inside_tree():
		# Production mounts are static, but editor/test relocation must not leave a
		# world-owned body behind at the old pose.
		solid_volume_state_changed.emit(
			_activity_enabled and is_inside_tree(), global_transform
		)


func get_component_id() -> StringName:
	return COMPONENT_ID


func get_activity_profile() -> int:
	return _built_profile if _built else activity_profile


func get_activity_profile_id() -> StringName:
	return PROFILE_IDS.get(get_activity_profile(), &"invalid") as StringName


func get_activity_profile_ids() -> PackedStringArray:
	return PackedStringArray([
		PROFILE_IDS[ActivityProfile.FULL],
		PROFILE_IDS[ActivityProfile.GANTRY],
		PROFILE_IDS[ActivityProfile.SERVICE_ARM],
		PROFILE_IDS[ActivityProfile.DRONE_PATROL],
		PROFILE_IDS[ActivityProfile.CARGO_LINE],
		PROFILE_IDS[ActivityProfile.SIGNAGE_PYLON],
		PROFILE_IDS[ActivityProfile.OBSERVATORY],
		PROFILE_IDS[ActivityProfile.CREW_WORKPOST],
	])


func get_mount_anchor() -> Marker3D:
	return _mount_anchor if is_instance_valid(_mount_anchor) else null


func get_mount_transform() -> Transform3D:
	return (
		_mount_anchor.global_transform
		if (
			is_instance_valid(_mount_anchor)
			and get_node_or_null(^"MountAnchor") == _mount_anchor
			and is_ancestor_of(_mount_anchor)
		)
		else global_transform
	)


func get_service_zone_anchor() -> Marker3D:
	return _service_zone_anchor if is_instance_valid(_service_zone_anchor) else null


func get_mount_footprint_count() -> int:
	match get_activity_profile():
		ActivityProfile.FULL, ActivityProfile.GANTRY:
			return 4
		ActivityProfile.SERVICE_ARM:
			return 1
		ActivityProfile.DRONE_PATROL:
			return 4
		ActivityProfile.CARGO_LINE, ActivityProfile.CARGO_LINE_LONG:
			return 4
		ActivityProfile.SIGNAGE_PYLON:
			return 1
		ActivityProfile.OBSERVATORY:
			return 3
		ActivityProfile.CREW_WORKPOST:
			return 4
		_:
			return 0


## The origin is the centre of a level deck mount. Local +Y is up and local
## -Z faces the serviced berth or traffic lane. The generated subtree owns no
## physics; an owning world may realise the exact static volumes declared by
## [method get_solid_volume_contract] as sibling collision.
func get_integration_contract() -> Dictionary:
	var local_min := _get_profile_local_min()
	var local_max := _get_profile_local_max()
	var service_zone_center := _get_profile_service_zone_center()
	var mount_type := _get_profile_mount_type()
	var declared_solid_volume_count := get_solid_volume_contract().size()
	return {
		"schema_version": SCHEMA_VERSION,
		"component_id": COMPONENT_ID,
		"activity_profile": get_activity_profile(),
		"activity_profile_id": get_activity_profile_id(),
		"mount_type": mount_type,
		"mount_description": _get_profile_mount_description(),
		"visible_mount_footprint_count": get_mount_footprint_count(),
		"mount_transform": get_mount_transform(),
		"local_min": local_min,
		"local_max": local_max,
		"local_size": local_max - local_min,
		"service_zone_transform": global_transform * Transform3D(Basis.IDENTITY, service_zone_center),
		"service_zone_half_extents": _get_profile_service_zone_half_extents(),
		"up_axis_local": Vector3.UP,
		"service_facing_axis_local": Vector3.FORWARD,
		"collision_policy": (
			&"world_owned_declared_solids_presentation_nonblocking"
			if declared_solid_volume_count > 0
			else &"presentation_only_nonblocking"
		),
		"declared_solid_volume_count": declared_solid_volume_count,
		"owns_collision": false,
		"intentionally_nonblocking_static_families": PackedStringArray([
			"safety_beacon_sacrificial_route_marker",
		]),
		"requires_level_floor": mount_type == &"level_deck" or mount_type == &"deck_edge",
		"required_floor_contact_depth": 0.0,
		"recommended_instance_spacing": 12.0,
		"recommended_max_instances": RECOMMENDED_MAX_INSTANCES,
		"recommended_production_roster": get_activity_profile_ids(),
		"drone_motion_envelope": _get_drone_motion_envelope(),
	}


## The static parts of this component an owning world makes solid.
##
## This component never builds collision itself and that has not changed: its
## audit still requires `collision_nodes == 0`, because a presentation rail that
## owned bodies could quietly acquire gameplay authority. What it can honestly do
## is *declare* which of its drawn volumes are solid-looking, so the world that
## places it can build matching World-layer collision beside it. Every entry
## carries `{name, position, size, basis}` in this component's local space;
## `basis` defaults to identity.
## Box stock defaults to `shape_kind=box`; cylindrical fixed plant declares
## `shape_kind=cylinder`, `radius`, and `height`. Position and dimensions are
## copied from the drawn primitive. Boxes therefore match the drawn box exactly;
## cylinders preserve the visual's axis, radius, height and round footprint while
## deliberately omitting only its cosmetic rim chamfer.
##
## Deliberately excluded, and why:
##   * all 0.42 m-high safety beacons. They are intentionally nonphysical,
##     sacrificial route-marker trim — a gameplay abstraction that avoids forty
##     wheel-height snags; no walking step-up or simulated yielding is claimed;
##   * the rail beams and ties, at 0.23 m and 0.14 m — a player steps over a rail,
##     and a knee-high invisible wall along a walkway would be the worse defect;
##   * the pallet decks, at 0.18 m — the same, a kerb rather than an obstacle;
##   * the gantry foot pads, at 0.22 m. Those were tried as solid volumes by the
##     tow-tractor pass and reverted: the lattice's mount-support probes, which
##     drop a ray from 0.25 m to prove each gantry foot is seated on a *named*
##     deck, began reporting the pad instead of `CentralJunction` and
##     `ConnectionDeckA`, and the freight berth's exact seam roster gained four
##     contacts. Both audits were right — a solid 0.22 m plate lying on a deck is a
##     new surface bolted onto that deck. The column stands in the middle of the
##     same footprint and stops a vehicle 0.25 m earlier than the pad edge would,
##     which is the whole of what that costs;
##   * every mover. The sled and the hoist are closed-form functions of a clock
##     with no physics behind them; giving them colliders would make a body that
##     teleports through the player each frame. They stay nonblocking exactly as
##     the patrol drones and the service couriers do.
##
## Every volume named here is drawn by an individual `MeshInstance3D` and never
## by a `MultiMesh` batch, and that is a hard rule rather than a coincidence. The
## station's collision-without-visible-geometry sweep builds its "is anything
## drawn here" index by walking `MeshInstance3D` nodes, and a `MultiMesh` buffer
## is not even readable under `--headless`, where that sweep runs. Instancing a
## crate and then colliding it would therefore register as a solid surface with
## nothing drawn at it — the exact defect the sweep exists to catch.
func get_solid_volume_contract() -> Array[Dictionary]:
	var volumes: Array[Dictionary] = []
	# The maintenance gantry's four columns. Added by the tow-tractor obstruction
	# pass, from a playtest report: "if I drive into a spaceship I just clip
	# through it... the same with certain poles". These are the poles.
	# `CentralTowServiceActivity` is a `FULL` vignette mounted four metres from the
	# tractor's parking spot, and each column is 0.42 x 5.5 x 0.5 of drawn steel
	# standing on the deck with nothing at all behind it.
	if _profile_has_gantry():
		for x_side in [-1.0, 1.0]:
			for z_side in [-1.0, 1.0]:
				volumes.append({
					"name": "Column",
					"position": Vector3(float(x_side) * 4.3, 2.86, float(z_side) * 2.72),
					"size": Vector3(0.42, 5.5, 0.5),
				})
	# The service arm's fixed pedestal: 0.71 m of plant the whole arm turns on, and
	# the only part of that assembly that does not move. The sizes are the drawn
	# cylinders' own bounding boxes — the kit's chamfer shrinks the cap radius and
	# the lateral height but never the outer radius or the overall height, so
	# `get_aabb()` is exactly 2r x h x 2r. The offset is the arm base's own, which
	# the `FULL` profile shifts and the standalone profile does not.
	if _profile_has_service_arm():
		var arm_base := (
			Vector3(3.72, 0.0, -2.05)
			if get_activity_profile() == ActivityProfile.FULL
			else Vector3.ZERO
		)
		volumes.append_array([
			{
				"name": "BasePlate",
				"position": arm_base + Vector3(0.0, 0.16, 0.0),
				"size": Vector3(1.3, 0.32, 1.3),
				"shape_kind": &"cylinder",
				"radius": 0.65,
				"height": 0.32,
			},
			{
				"name": "RotaryBase",
				"position": arm_base + Vector3(0.0, 0.48, 0.0),
				"size": Vector3(0.86, 0.46, 0.86),
				"shape_kind": &"cylinder",
				"radius": 0.43,
				"height": 0.46,
			},
		])
	match get_activity_profile():
		ActivityProfile.CREW_WORKPOST:
			# The Aft stair delivers the 2.3 m-wide production tractor directly
			# into this fixed work post. Preserve the exact static gross shapes and
			# rotations; dependent trim inherits its parent's obstruction, while the
			# animated carousel and weld jig remain deliberately nonblocking.
			var drum_basis := Basis.from_euler(Vector3(PI * 0.5, 0.0, 0.0))
			volumes.append_array([
				{"name": "BenchTop", "position": Vector3(-0.9, 0.92, 0.55), "size": Vector3(2.6, 0.12, 0.9)},
				{"name": "BenchLeg", "position": Vector3(-2.05, 0.43, 0.23), "size": Vector3(0.12, 0.86, 0.12)},
				{"name": "BenchLeg", "position": Vector3(-2.05, 0.43, 0.87), "size": Vector3(0.12, 0.86, 0.12)},
				{"name": "BenchLeg", "position": Vector3(0.25, 0.43, 0.23), "size": Vector3(0.12, 0.86, 0.12)},
				{"name": "BenchLeg", "position": Vector3(0.25, 0.43, 0.87), "size": Vector3(0.12, 0.86, 0.12)},
				{"name": "ToolWall", "position": Vector3(-0.9, 1.72, 1.0), "size": Vector3(2.5, 1.46, 0.08)},
				{"name": "CableDrum", "position": Vector3(1.95, 0.52, 0.7), "size": Vector3(0.84, 0.5, 0.84), "shape_kind": &"cylinder", "radius": 0.42, "height": 0.5, "basis": drum_basis},
				{"name": "DrumFlange", "position": Vector3(1.95, 0.52, 0.42), "size": Vector3(1.0, 0.06, 1.0), "shape_kind": &"cylinder", "radius": 0.5, "height": 0.06, "basis": drum_basis},
				{"name": "DrumFlange", "position": Vector3(1.95, 0.52, 0.98), "size": Vector3(1.0, 0.06, 1.0), "shape_kind": &"cylinder", "radius": 0.5, "height": 0.06, "basis": drum_basis},
				{"name": "SupplyCrate", "position": Vector3(2.15, 0.34, -0.55), "size": Vector3(1.0, 0.68, 0.9)},
				{"name": "SupplyCrateTop", "position": Vector3(2.15, 0.92, -0.55), "size": Vector3(0.85, 0.48, 0.8)},
				{"name": "JigPost", "position": Vector3(-2.0, 0.775, -0.75), "size": Vector3(0.32, 1.55, 0.32), "shape_kind": &"cylinder", "radius": 0.16, "height": 1.55},
			])
		ActivityProfile.CARGO_LINE:
			volumes.append_array([
				{"name": "CrateLower", "position": Vector3(-3.4, 0.55, 1.85), "size": Vector3(1.05, 0.74, 1.0)},
				{"name": "CrateLowerAlt", "position": Vector3(-2.35, 0.55, 1.85), "size": Vector3(0.95, 0.74, 1.0)},
				{"name": "CrateUpper", "position": Vector3(-2.9, 1.24, 1.85), "size": Vector3(1.5, 0.64, 1.05)},
				{"name": "CrateOutbound", "position": Vector3(2.65, 0.52, -1.9), "size": Vector3(1.1, 0.68, 0.98)},
				{"name": "CrateOutboundSmall", "position": Vector3(3.62, 0.44, -1.9), "size": Vector3(0.7, 0.52, 0.8)},
				{"name": "HoistPostPort", "position": Vector3(0.0, 1.45, -1.55), "size": Vector3(0.26, 2.9, 0.3)},
				{"name": "HoistPostStarboard", "position": Vector3(0.0, 1.45, 1.55), "size": Vector3(0.26, 2.9, 0.3)},
				{"name": "RailStopPort", "position": Vector3(-4.34, 0.26, 0.0), "size": Vector3(0.24, 0.52, 1.7)},
				{"name": "RailStopStarboard", "position": Vector3(4.34, 0.26, 0.0), "size": Vector3(0.24, 0.52, 1.7)},
				{"name": "ControlPedestal", "position": Vector3(-4.15, 0.5, -1.7), "size": Vector3(0.44, 1.0, 0.44)},
				{"name": "ControlHousing", "position": Vector3(-4.15, 1.08, -1.7), "size": Vector3(0.5, 0.3, 0.36)},
			])
		ActivityProfile.CARGO_LINE_LONG:
			volumes.append_array([
				{"name": "CrateInboundPort", "position": Vector3(-9.5, 0.54, 1.3), "size": Vector3(1.0, 0.72, 0.8)},
				{"name": "CrateInboundStarboard", "position": Vector3(-7.9, 0.54, 1.3), "size": Vector3(1.0, 0.72, 0.8)},
				{"name": "CrateInboundTop", "position": Vector3(-8.7, 1.19, 1.3), "size": Vector3(1.5, 0.6, 0.8)},
				{"name": "CrateOutboundPort", "position": Vector3(7.5, 0.54, -1.3), "size": Vector3(0.9, 0.72, 0.8)},
				{"name": "CrateOutboundStarboard", "position": Vector3(8.9, 0.54, -1.3), "size": Vector3(1.0, 0.72, 0.8)},
				{"name": "CrateOutboundTop", "position": Vector3(8.2, 1.19, -1.3), "size": Vector3(1.3, 0.6, 0.8)},
			])
			for x_side in [-1.0, 1.0]:
				for z_side in [-1.0, 1.0]:
					volumes.append({
						"name": "HoistPost",
						"position": Vector3(x_side * 10.4, 1.45, z_side * 1.35),
						"size": Vector3(0.26, 2.9, 0.3),
					})
				volumes.append({
					"name": "RailStop",
					"position": Vector3(x_side * 11.0, 0.26, 0.0),
					"size": Vector3(0.24, 0.52, 1.7),
				})
			volumes.append_array([
				{"name": "ControlPedestal", "position": Vector3(-6.0, 0.5, -1.15), "size": Vector3(0.44, 1.0, 0.44)},
				{"name": "ControlHousing", "position": Vector3(-6.0, 1.08, -1.15), "size": Vector3(0.5, 0.3, 0.36)},
			])
	return volumes


func get_evidence_metadata() -> Dictionary:
	return {
		"schema_version": SCHEMA_VERSION,
		"component_id": COMPONENT_ID,
		"activity_profile_id": get_activity_profile_id(),
		"evidence_status": EVIDENCE_STATUS,
		"source_bounded": true,
		"authenticated_original_geometry": false,
		"authenticated_original_placement": false,
		"references": PackedStringArray([
			"Goal brief: Shipyard / machinery, docking equipment, cargo, animated equipment, and ambient station activity",
			"Goal brief: Visual Direction / polished stylised science-fiction with readable colour",
			"Goal brief: Creative Freedom / additions must feel like a natural evolution of Keth Shipyards",
		]),
		"supported_invariants": PackedStringArray([
			"the modern station should feel operational rather than visually empty",
			"animated equipment and docking or maintenance infrastructure are appropriate modern additions",
			"clean colourful readability should remain visible within richer modern detail",
		]),
		"modern_interpretations": PackedStringArray([
			"freestanding gantry frame, carriage, telescoping service tool, and motion envelope",
			"articulated maintenance arm, tool head, materials, dimensions, and motion sequence",
			"two autonomous service drones, their routes, lights, cargo pods, and timing",
			"four warning beacons, visual cadence, colour, component footprint, and placement",
			"cargo transfer rail, container sled, overhead hoist, crate stacks, and their timing",
			"long transfer run, its full-length hoist gantry, travelling bridge, and instanced rail and crate stock",
			"wayfinding pylon, sign board, bay plaque, notice rack, chevron chase, and identifier drum",
			"skywatch post, optic tube, pan and elevation arcs, and instrument cabinet",
			"crew work post, bench, tool wall, parts bins, hard hat, tool carousel, and weld jig",
		]),
		"explicit_unknowns": PackedStringArray([
			"historical station machinery layout, dimensions, appearance, and animation",
			"whether autonomous service drones existed in any original or fixed-era build",
			"authoritative maintenance workflows and traffic-control light patterns",
			"any original station signage, wayfinding language, cargo handling method, or crew practice",
			"whether the station ever carried an observation or sensor instrument of any kind",
		]),
		"content_note": CONTENT_NOTE,
	}


func set_activity_enabled(enabled: bool) -> void:
	if not _can_mutate_activity():
		return
	_enabled_overridden = true
	if _activity_enabled == enabled:
		_refresh_lifecycle()
		return
	_activity_enabled = enabled
	_refresh_lifecycle()


func is_activity_enabled() -> bool:
	return _activity_enabled


func set_activity_paused(paused: bool) -> void:
	if not _can_mutate_activity():
		return
	_paused_overridden = true
	if _activity_paused == paused:
		_refresh_lifecycle()
		return
	_activity_paused = paused
	_refresh_lifecycle()


func is_activity_paused() -> bool:
	return _activity_paused


func is_activity_advancing() -> bool:
	return _activity_enabled and not _activity_paused


func _can_mutate_activity() -> bool:
	return is_inside_tree() and not is_queued_for_deletion()


## Advances the component only while enabled and unpaused. The transforms are
## functions of total elapsed time, so frame subdivision does not change state.
func advance_activity_simulation(delta: float) -> bool:
	if not _can_mutate_activity():
		return false
	if not is_activity_advancing() or not is_finite(delta) or delta <= 0.0:
		return false
	_elapsed += delta
	_update_activity_transforms()
	return true


## Deterministic seek used by capture tooling. This intentionally works while
## paused or disabled, but it never changes either lifecycle flag.
func set_activity_time(seconds: float) -> bool:
	if not _can_mutate_activity():
		return false
	if not is_finite(seconds) or seconds < 0.0:
		return false
	_elapsed = seconds
	_update_activity_transforms()
	return true


func reset_activity_time() -> void:
	if not _can_mutate_activity():
		return
	_elapsed = 0.0
	_update_activity_transforms()


func get_activity_time() -> float:
	return _elapsed


func get_activity_state() -> Dictionary:
	var drones: Array[Dictionary] = []
	for drone in _drone_roots:
		drones.append({
			"position": drone.position,
			"rotation": drone.rotation,
		})
	var station_life: Array[Dictionary] = []
	for mover in _station_life_movers:
		station_life.append({
			"position": mover.position,
			"rotation": mover.rotation,
		})
	var station_life_lit: Array[bool] = []
	for index in _station_life_lenses.size():
		station_life_lit.append(
			_station_life_lenses[index].material_override
			== _materials[_station_life_lens_specs[index].lit]
		)
	return {
		"activity_profile": get_activity_profile(),
		"activity_profile_id": get_activity_profile_id(),
		"elapsed": _elapsed,
		"enabled": _activity_enabled,
		"paused": _activity_paused,
		"advancing": is_activity_advancing(),
		"visible": _presentation_root != null and _presentation_root.visible,
		"gantry_carriage_position": _gantry_carriage.position if _gantry_carriage != null else Vector3.ZERO,
		"gantry_tool_position": _gantry_tool.position if _gantry_tool != null else Vector3.ZERO,
		"service_arm_shoulder_rotation": _service_arm_shoulder.rotation if _service_arm_shoulder != null else Vector3.ZERO,
		"service_arm_elbow_rotation": _service_arm_elbow.rotation if _service_arm_elbow != null else Vector3.ZERO,
		"drones": drones,
		"station_life_movers": station_life,
		"station_life_lit": station_life_lit,
		"beacon_pattern": _get_beacon_pattern(),
	}


func get_determinism_fingerprint() -> String:
	var equipment := get_equipment_counts()
	var local_min := _get_profile_local_min()
	var local_max := _get_profile_local_max()
	return "%s|v%d|profile=%s|seed=%d|gantry=%d|arm=%d|drones=%d|beacons=%d|movers=%d|lenses=%d|envelope=%s:%s" % [
		str(COMPONENT_ID),
		SCHEMA_VERSION,
		str(get_activity_profile_id()),
		_get_effective_variation_seed(),
		equipment.gantry_count,
		equipment.service_arm_count,
		equipment.service_drone_count,
		equipment.safety_beacon_count,
		equipment.station_life_mover_count,
		equipment.station_life_lens_count,
		str(local_min),
		str(local_max),
	]


func get_equipment_counts() -> Dictionary:
	var gantry_count := 1 if _gantry_carriage != null and _gantry_tool != null else 0
	var service_arm_count := 1 if _service_arm_shoulder != null and _service_arm_elbow != null and _service_arm_tool != null else 0
	var animated_assembly_count := (
		gantry_count
		+ service_arm_count * 2
		+ _drone_roots.size()
		+ _station_life_movers.size()
	)
	return {
		"gantry_count": gantry_count,
		"service_arm_count": service_arm_count,
		"service_drone_count": _drone_roots.size(),
		"safety_beacon_count": _beacon_lenses.size(),
		"station_life_mover_count": _station_life_movers.size(),
		"station_life_lens_count": _station_life_lenses.size(),
		"animated_assembly_count": animated_assembly_count,
	}


func get_recommended_production_roster_budget() -> Dictionary:
	return {
		"schema_version": SCHEMA_VERSION,
		"profiles": get_activity_profile_ids(),
		"budgets": RECOMMENDED_PRODUCTION_ROSTER_BUDGET.duplicate(true),
		"mesh_budget_rationale": (
			"One distinct FULL, GANTRY, SERVICE_ARM, DRONE_PATROL, CARGO_LINE, "
			+ "SIGNAGE_PYLON, OBSERVATORY, and CREW_WORKPOST placement; "
			+ "specialized roles omit unrelated assemblies instead of hiding them."
		),
	}


## Observable proof for resource/performance audits. Contracts include every
## stored material property captured after construction, while identities prove
## that all placements retain the same resources. The returned dictionaries are
## detached; callers cannot alter the live catalog through this API.
func get_material_catalog_audit() -> Dictionary:
	var identities := {}
	var keys := PackedStringArray()
	var shared_identity := true
	for key in _materials:
		var material := _materials[key] as Material
		var shared_material := _shared_material_catalog.get(key) as Material
		keys.append(str(key))
		identities[key] = material.get_instance_id() if material != null else 0
		shared_identity = (
			shared_identity
			and material != null
			and shared_material != null
			and material == shared_material
		)
	keys.sort()
	var bound_references := 0
	for candidate in find_children("*", "", true, false):
		if (
			(candidate is MeshInstance3D or candidate is MultiMeshInstance3D)
			and (candidate as GeometryInstance3D).material_override != null
		):
			bound_references += 1
	return {
		"valid": (
			_materials.size() == 17
			and shared_identity
			and _materials_match_build_contract()
			and _dynamic_lens_materials_match_clock()
		),
		"catalog_shared": shared_identity,
		"catalog_keys": keys,
		"catalog_entry_count": _materials.size(),
		"retained_unique_materials": identities.size(),
		"bound_material_references": bound_references,
		"dynamic_lens_count": (
			_beacon_lenses.size()
			+ _drone_beacon_lenses.size()
			+ _station_life_lenses.size()
		),
		"dynamic_lens_bindings_valid": _dynamic_lens_materials_match_clock(),
		"identity_by_key": identities.duplicate(true),
		"visible_parameters_by_key": _built_material_contracts.duplicate(true),
	}


static func audit_production_roster(activities: Array[Node]) -> Dictionary:
	var counts := {
		"instance_count": 0,
		"node_count": 0,
		"mesh_instances": 0,
		"unique_materials": 0,
		"lights": 0,
		"particle_emitters": 0,
		"collision_nodes": 0,
		"multimesh_batches": 0,
		"multimesh_instances": 0,
		"geometry_submissions": 0,
		"drawn_copies": 0,
		"animated_assemblies": 0,
	}
	var profile_counts := {}
	for profile_id: StringName in RECOMMENDED_PRODUCTION_ROSTER_PROFILE_COUNTS:
		profile_counts[profile_id] = 0
	var errors := PackedStringArray()
	var retained_material_ids := {}
	var reference_identity_by_key := {}
	var bound_material_references := 0
	var dynamic_lens_count := 0
	var dynamic_lens_bindings_valid := true
	var catalogs_share_identity := true
	for candidate in activities:
		if not candidate is StationOperationsActivity:
			errors.append("production roster contains a node that is not StationOperationsActivity")
			continue
		var activity := candidate as StationOperationsActivity
		var activity_audit := activity.get_audit_report()
		var profile_id := activity.get_activity_profile_id()
		if not bool(activity_audit.valid):
			errors.append(
				"production roster '%s' component fails its own audit: %s" % [
					profile_id,
					"; ".join(activity_audit.errors as PackedStringArray),
				]
			)
		if not profile_counts.has(profile_id):
			errors.append("production roster contains invalid profile '%s'" % profile_id)
			continue
		profile_counts[profile_id] = int(profile_counts[profile_id]) + 1
		var report := activity_audit.performance as Dictionary
		var activity_counts := report.counts as Dictionary
		counts.instance_count = int(counts.instance_count) + 1
		for key: String in activity_counts.keys():
			if key == "unique_materials":
				continue
			counts[key] = int(counts.get(key, 0)) + int(activity_counts[key])
		var catalog_audit := activity.get_material_catalog_audit()
		if not bool(catalog_audit.valid):
			errors.append("production roster '%s' material catalog fails its own audit" % profile_id)
		var identities := catalog_audit.identity_by_key as Dictionary
		if reference_identity_by_key.is_empty():
			reference_identity_by_key = identities.duplicate(true)
		else:
			catalogs_share_identity = catalogs_share_identity and identities == reference_identity_by_key
		for material_id in identities.values():
			retained_material_ids[int(material_id)] = true
		bound_material_references += int(catalog_audit.bound_material_references)
		dynamic_lens_count += int(catalog_audit.dynamic_lens_count)
		dynamic_lens_bindings_valid = (
			dynamic_lens_bindings_valid
			and bool(catalog_audit.dynamic_lens_bindings_valid)
		)
	counts.unique_materials = retained_material_ids.size()
	if not catalogs_share_identity:
		errors.append("production roster placements do not share one material catalog identity")
	for profile_id: StringName in profile_counts.keys():
		var required := int(RECOMMENDED_PRODUCTION_ROSTER_PROFILE_COUNTS[profile_id])
		if int(profile_counts[profile_id]) != required:
			errors.append(
				"recommended production roster requires exactly %d '%s' placement(s), found %d" % [
					required, profile_id, profile_counts[profile_id],
				]
			)
	for key: String in RECOMMENDED_PRODUCTION_ROSTER_BUDGET.keys():
		if int(counts.get(key, 0)) > int(RECOMMENDED_PRODUCTION_ROSTER_BUDGET[key]):
			errors.append("production roster %s exceeds budget (%d > %d)" % [key, counts.get(key, 0), RECOMMENDED_PRODUCTION_ROSTER_BUDGET[key]])
	return {
		"schema_version": SCHEMA_VERSION,
		"valid": errors.is_empty(),
		"within_budget": errors.is_empty(),
		"errors": errors,
		"profile_counts": profile_counts.duplicate(true),
		"counts": counts.duplicate(true),
		"budgets": RECOMMENDED_PRODUCTION_ROSTER_BUDGET.duplicate(true),
		"material_catalog": {
			"valid": (
				catalogs_share_identity
				and retained_material_ids.size() == 17
				and dynamic_lens_bindings_valid
			),
			"catalog_shared": catalogs_share_identity,
			"catalog_entries": reference_identity_by_key.size(),
			"retained_unique_materials": retained_material_ids.size(),
			"bound_material_references": bound_material_references,
			"dynamic_lens_count": dynamic_lens_count,
			"dynamic_lens_bindings_valid": dynamic_lens_bindings_valid,
			"identity_by_key": reference_identity_by_key.duplicate(true),
		},
	}


func get_performance_audit(instance_count: int = 1) -> Dictionary:
	var equipment := get_equipment_counts()
	var counts := {
		"node_count": 0,
		"mesh_instances": 0,
		"unique_materials": 0,
		"lights": 0,
		"particle_emitters": 0,
		"collision_nodes": 0,
		# Instanced structure is counted twice on purpose: `multimesh_batches` is
		# what the renderer submits, `multimesh_instances` is what the player sees.
		# Reporting only the first would let a batch grow without limit; reporting
		# only the second would hide that it costs one draw.
		"multimesh_batches": 0,
		"multimesh_instances": 0,
		"geometry_submissions": 0,
		"drawn_copies": 0,
		"animated_assemblies": int(equipment.animated_assembly_count),
	}
	var material_ids := {}
	_count_runtime_resources(self, counts, material_ids)
	counts["geometry_submissions"] = (
		int(counts.mesh_instances) + int(counts.multimesh_batches)
	)
	counts["drawn_copies"] = (
		int(counts.mesh_instances) + int(counts.multimesh_instances)
	)
	# Retained but momentarily unassigned beacon variants still consume memory.
	# Count every component-owned material instead of reporting only the current
	# flash phase, keeping the audit stable across deterministic animation time.
	for material: Material in _materials.values():
		if material != null:
			material_ids[material.get_instance_id()] = true
	counts["unique_materials"] = material_ids.size()
	var performance_budget := _get_profile_performance_budget()
	var errors := PackedStringArray()
	for key: String in performance_budget.keys():
		if int(counts.get(key, 0)) > int(performance_budget[key]):
			errors.append("%s exceeds %s profile budget (%d > %d)" % [key, get_activity_profile_id(), counts.get(key, 0), performance_budget[key]])
	var audited_instance_count := clampi(instance_count, 1, RECOMMENDED_MAX_INSTANCES)
	var aggregate_counts := {}
	var aggregate_budgets := {}
	for key: String in counts.keys():
		# Geometry and nodes scale per placement. The immutable material catalog
		# does not: all placements retain the same seventeen resources.
		var multiplier := 1 if key == "unique_materials" else audited_instance_count
		aggregate_counts[key] = int(counts[key]) * multiplier
		aggregate_budgets[key] = int(performance_budget.get(key, 0)) * multiplier
	var aggregate_errors := PackedStringArray()
	for key: String in aggregate_budgets.keys():
		if int(aggregate_counts.get(key, 0)) > int(aggregate_budgets[key]):
			aggregate_errors.append("%s exceeds aggregate profile budget (%d > %d)" % [key, aggregate_counts.get(key, 0), aggregate_budgets[key]])
	return {
		"schema_version": SCHEMA_VERSION,
		"activity_profile": get_activity_profile(),
		"activity_profile_id": get_activity_profile_id(),
		"valid": errors.is_empty(),
		"within_budget": errors.is_empty(),
		"errors": errors,
		"counts": counts.duplicate(true),
		"budgets": performance_budget.duplicate(true),
		"audited_instance_count": audited_instance_count,
		"recommended_max_instances": RECOMMENDED_MAX_INSTANCES,
		"aggregate_counts": aggregate_counts.duplicate(true),
		"aggregate_budgets": aggregate_budgets.duplicate(true),
		"aggregate_within_budget": aggregate_errors.is_empty(),
		"aggregate_errors": aggregate_errors,
		"process_enabled": is_processing(),
		"headless_safe": true,
		"uses_external_assets": false,
		"uses_particles": false,
		"uses_dynamic_lights": false,
		"uses_collision": false,
		"determinism_fingerprint": get_determinism_fingerprint(),
	}


func get_validation_errors() -> PackedStringArray:
	var errors := PackedStringArray()
	if _mount_anchor == null or _service_zone_anchor == null or _presentation_root == null:
		errors.append("required integration anchors or presentation root are missing")
	if (
		get_node_or_null(^"MountAnchor") != _mount_anchor
		or get_node_or_null(^"ServiceZoneAnchor") != _service_zone_anchor
		or get_node_or_null(^"PresentationRoot") != _presentation_root
		or not is_instance_valid(_mount_anchor)
		or not is_instance_valid(_service_zone_anchor)
		or not is_instance_valid(_presentation_root)
		or not is_ancestor_of(_mount_anchor)
		or not is_ancestor_of(_service_zone_anchor)
		or not is_ancestor_of(_presentation_root)
	):
		errors.append("required live anchor and presentation identities changed")
	elif (
		not _mount_anchor.transform.is_equal_approx(Transform3D.IDENTITY)
		or not _presentation_root.transform.is_equal_approx(Transform3D.IDENTITY)
		or not _service_zone_anchor.basis.is_equal_approx(Basis.IDENTITY)
		or not _service_zone_anchor.position.is_equal_approx(_get_profile_service_zone_center())
	):
		errors.append("required anchor or presentation transforms diverged from the built contract")
	if not _cached_presentation_references_are_live():
		errors.append("cached activity equipment no longer belongs to the live presentation hierarchy")
	if not _is_valid_profile(_built_profile):
		errors.append("activity_profile must select FULL, GANTRY, SERVICE_ARM, or DRONE_PATROL")
	if _built:
		if activity_profile != _built_profile:
			errors.append("activity_profile cannot be changed after the component has built")
		if starts_enabled != _built_starts_enabled:
			errors.append("starts_enabled cannot be changed after the component has built")
		if starts_paused != _built_starts_paused:
			errors.append("starts_paused cannot be changed after the component has built")
		if playback_speed != _built_playback_speed:
			errors.append("playback_speed cannot be changed after the component has built")
		if variation_seed != _built_variation_seed:
			errors.append("variation_seed cannot be changed after the component has built")
	var expected := _get_expected_equipment_counts()
	var equipment := get_equipment_counts()
	for key: String in expected.keys():
		if int(equipment.get(key, -1)) != int(expected[key]):
			errors.append("%s profile requires %s=%d, found %d" % [get_activity_profile_id(), key, expected[key], equipment.get(key, -1)])
	if _beacon_lenses.size() != BEACON_COUNT:
		errors.append("safety beacon count does not match the stable contract")
	if _get_effective_variation_seed() < 0:
		errors.append("variation seed must not be negative")
	var effective_playback_speed := _get_effective_playback_speed()
	if not is_finite(effective_playback_speed) or effective_playback_speed <= 0.0:
		errors.append("playback speed must be finite and greater than zero")
	if is_processing() != is_activity_advancing():
		errors.append("process state must match the enabled and paused lifecycle state")
	if is_instance_valid(_presentation_root) and is_ancestor_of(_presentation_root) and _presentation_root.visible != _activity_enabled:
		errors.append("presentation visibility must match the enabled lifecycle state")
	var performance := get_performance_audit()
	if not bool(performance.within_budget):
		errors.append_array(performance.errors as PackedStringArray)
	if int((performance.counts as Dictionary).collision_nodes) != 0:
		errors.append("presentation component must never create collision nodes")
	var performance_counts := performance.counts as Dictionary
	var expected_counts := _get_profile_performance_budget()
	for key: String in expected_counts:
		if int(performance_counts.get(key, -1)) != int(expected_counts[key]):
			errors.append("live %s count diverged from the immutable %s profile build" % [key, get_activity_profile_id()])
	if not _all_live_meshes_fit_published_envelope():
		errors.append("live activity mesh geometry exceeds the published profile envelope")
	return errors


func get_audit_report() -> Dictionary:
	var errors := get_validation_errors()
	return {
		"schema_version": SCHEMA_VERSION,
		"component_id": COMPONENT_ID,
		"activity_profile": get_activity_profile(),
		"activity_profile_id": get_activity_profile_id(),
		"valid": errors.is_empty(),
		"errors": errors,
		"evidence_status": EVIDENCE_STATUS,
		"evidence": get_evidence_metadata(),
		"integration": get_integration_contract(),
		"performance": get_performance_audit(),
		"material_catalog": get_material_catalog_audit(),
		"lifecycle": {
			"enabled": _activity_enabled,
			"paused": _activity_paused,
			"advancing": is_activity_advancing(),
			"process_enabled": is_processing(),
		},
		"equipment": get_equipment_counts(),
		"determinism_fingerprint": get_determinism_fingerprint(),
	}


func audit() -> Dictionary:
	return get_audit_report().duplicate(true)


func _is_valid_profile(profile: int) -> bool:
	return PROFILE_IDS.has(profile)


func _get_effective_playback_speed() -> float:
	return _built_playback_speed if _built else playback_speed


func _get_effective_variation_seed() -> int:
	return _built_variation_seed if _built else variation_seed


func _profile_has_gantry() -> bool:
	return _built_profile == ActivityProfile.FULL or _built_profile == ActivityProfile.GANTRY


func _profile_has_service_arm() -> bool:
	return _built_profile == ActivityProfile.FULL or _built_profile == ActivityProfile.SERVICE_ARM


func _profile_has_drones() -> bool:
	return _built_profile == ActivityProfile.FULL or _built_profile == ActivityProfile.DRONE_PATROL


func _get_expected_station_life_counts() -> Dictionary:
	var counts: Variant = PROFILE_STATION_LIFE_COUNTS.get(_built_profile)
	return counts as Dictionary if counts is Dictionary else {"movers": 0, "lenses": 0}


func _get_expected_equipment_counts() -> Dictionary:
	var station_life := _get_expected_station_life_counts()
	return {
		"gantry_count": 1 if _profile_has_gantry() else 0,
		"service_arm_count": 1 if _profile_has_service_arm() else 0,
		"service_drone_count": DRONE_COUNT if _profile_has_drones() else 0,
		"safety_beacon_count": BEACON_COUNT,
		"station_life_mover_count": int(station_life.movers),
		"station_life_lens_count": int(station_life.lenses),
		"animated_assembly_count": (
			(1 if _profile_has_gantry() else 0)
			+ (2 if _profile_has_service_arm() else 0)
			+ (DRONE_COUNT if _profile_has_drones() else 0)
			+ int(station_life.movers)
		),
	}


func _get_profile_performance_budget() -> Dictionary:
	var budget: Variant = PROFILE_PERFORMANCE_BUDGETS.get(_built_profile)
	return (budget as Dictionary).duplicate(true) if budget is Dictionary else {}


func _cached_presentation_references_are_live() -> bool:
	if not is_instance_valid(_presentation_root) or not is_ancestor_of(_presentation_root):
		return false
	var required_nodes: Array[Node] = []
	if _profile_has_gantry():
		if not is_instance_valid(_gantry_carriage) or not is_instance_valid(_gantry_tool):
			return false
		required_nodes.append_array([_gantry_carriage, _gantry_tool])
	elif is_instance_valid(_gantry_carriage) or is_instance_valid(_gantry_tool):
		return false
	if _profile_has_service_arm():
		if (
			not is_instance_valid(_service_arm_shoulder)
			or not is_instance_valid(_service_arm_elbow)
			or not is_instance_valid(_service_arm_tool)
		):
			return false
		required_nodes.append_array([
			_service_arm_shoulder,
			_service_arm_elbow,
			_service_arm_tool,
		])
	elif (
		is_instance_valid(_service_arm_shoulder)
		or is_instance_valid(_service_arm_elbow)
		or is_instance_valid(_service_arm_tool)
	):
		return false
	if _drone_roots.size() != (DRONE_COUNT if _profile_has_drones() else 0):
		return false
	if _drone_beacon_lenses.size() != (DRONE_COUNT if _profile_has_drones() else 0):
		return false
	if _beacon_lenses.size() != BEACON_COUNT:
		return false
	var station_life := _get_expected_station_life_counts()
	if (
		_station_life_movers.size() != int(station_life.movers)
		or _station_life_lenses.size() != int(station_life.lenses)
		or _station_life_lens_specs.size() != _station_life_lenses.size()
	):
		return false
	for mover in _station_life_movers:
		if not is_instance_valid(mover):
			return false
		required_nodes.append(mover)
	for lens in _station_life_lenses:
		if not is_instance_valid(lens):
			return false
		required_nodes.append(lens)
	for drone in _drone_roots:
		if not is_instance_valid(drone):
			return false
		required_nodes.append(drone)
	for lens in _drone_beacon_lenses:
		if not is_instance_valid(lens):
			return false
		required_nodes.append(lens)
	for lens in _beacon_lenses:
		if not is_instance_valid(lens):
			return false
		required_nodes.append(lens)
	for candidate in required_nodes:
		if not _presentation_root.is_ancestor_of(candidate):
			return false
	return true


func _capture_built_presentation_contract() -> void:
	_built_node_instance_ids.clear()
	_built_static_node_transforms.clear()
	_built_node_visibility.clear()
	_built_mesh_contracts.clear()
	_built_multimesh_contracts.clear()
	_built_material_contracts.clear()
	var dynamic_node_ids := _dynamic_node_instance_ids()
	for candidate in find_children("*", "", true, false):
		var relative_path := str(get_path_to(candidate))
		_built_node_instance_ids[relative_path] = candidate.get_instance_id()
		if candidate is Node3D and not dynamic_node_ids.has(candidate.get_instance_id()):
			_built_static_node_transforms[relative_path] = (candidate as Node3D).transform
		if candidate is Node3D and candidate != _presentation_root:
			_built_node_visibility[relative_path] = (candidate as Node3D).visible
		if candidate is MultiMeshInstance3D:
			var batch := candidate as MultiMeshInstance3D
			var instance_transforms := _batch_transforms(batch)
			_built_multimesh_contracts[relative_path] = {
				"instance_id": batch.get_instance_id(),
				"transform": batch.transform,
				"multimesh_instance_id": (
					batch.multimesh.get_instance_id() if batch.multimesh != null else 0
				),
				"mesh_instance_id": (
					batch.multimesh.mesh.get_instance_id()
					if batch.multimesh != null and batch.multimesh.mesh != null else 0
				),
				"mesh_aabb": (
					batch.multimesh.mesh.get_aabb()
					if batch.multimesh != null and batch.multimesh.mesh != null else AABB()
				),
				"mesh_storage": _resource_storage_fingerprint(
					batch.multimesh.mesh if batch.multimesh != null else null
				),
				"custom_aabb": (
					batch.multimesh.custom_aabb if batch.multimesh != null else AABB()
				),
				"explicit_authored_bounds": bool(
					batch.get_meta("explicit_authored_bounds", false)
				),
				"instance_transforms": instance_transforms,
				"material_instance_id": (
					batch.material_override.get_instance_id()
					if batch.material_override != null else 0
				),
				"cast_shadow": batch.cast_shadow,
				"layers": batch.layers,
			}
		elif candidate is MeshInstance3D:
			var mesh_instance := candidate as MeshInstance3D
			_built_mesh_contracts[relative_path] = {
				"instance_id": mesh_instance.get_instance_id(),
				"transform": mesh_instance.transform,
				"mesh_instance_id": (
					mesh_instance.mesh.get_instance_id() if mesh_instance.mesh != null else 0
				),
				"mesh_class": mesh_instance.mesh.get_class() if mesh_instance.mesh != null else "",
				"mesh_aabb": mesh_instance.mesh.get_aabb() if mesh_instance.mesh != null else AABB(),
				"mesh_storage": _resource_storage_fingerprint(mesh_instance.mesh),
				"material_instance_id": (
					mesh_instance.material_override.get_instance_id()
					if mesh_instance.material_override != null else 0
				),
				"dynamic_material": (
					_beacon_lenses.has(mesh_instance)
					or _drone_beacon_lenses.has(mesh_instance)
					or _station_life_lenses.has(mesh_instance)
				),
				"cast_shadow": mesh_instance.cast_shadow,
				"layers": mesh_instance.layers,
				"visibility_range_begin": mesh_instance.visibility_range_begin,
				"visibility_range_end": mesh_instance.visibility_range_end,
				"visibility_range_begin_margin": mesh_instance.visibility_range_begin_margin,
				"visibility_range_end_margin": mesh_instance.visibility_range_end_margin,
				"visibility_range_fade_mode": mesh_instance.visibility_range_fade_mode,
				"transparency": mesh_instance.transparency,
				"flip_faces": (
					(mesh_instance.mesh as PrimitiveMesh).flip_faces
					if mesh_instance.mesh is PrimitiveMesh else false
				),
			}
	for material_key in _materials:
		var material := _materials[material_key] as StandardMaterial3D
		if material != null:
			_built_material_contracts[material_key] = _standard_material_contract(material)


func _built_presentation_hierarchy_is_live() -> bool:
	if not _built or _built_node_instance_ids.is_empty():
		return false
	var live_nodes := find_children("*", "", true, false)
	if live_nodes.size() != _built_node_instance_ids.size():
		return false
	for relative_path_value in _built_node_instance_ids:
		var relative_path := NodePath(str(relative_path_value))
		var candidate := get_node_or_null(relative_path)
		if (
			not is_instance_valid(candidate)
			or candidate.get_instance_id() != int(_built_node_instance_ids[relative_path_value])
			or not is_ancestor_of(candidate)
		):
			return false
	for relative_path_value in _built_static_node_transforms:
		var candidate := get_node_or_null(NodePath(str(relative_path_value))) as Node3D
		if (
			not is_instance_valid(candidate)
			or not candidate.transform.is_equal_approx(
				_built_static_node_transforms[relative_path_value] as Transform3D
			)
		):
			return false
	for relative_path_value in _built_node_visibility:
		var candidate := get_node_or_null(NodePath(str(relative_path_value))) as Node3D
		if (
			not is_instance_valid(candidate)
			or candidate.visible != bool(_built_node_visibility[relative_path_value])
		):
			return false
	return true


func _owned_material_instance_ids() -> Dictionary:
	var result := {}
	for material_value in _materials.values():
		var material := material_value as Material
		if material != null:
			result[material.get_instance_id()] = true
	return result


func _built_mesh_contracts_are_live() -> bool:
	if _built_mesh_contracts.is_empty():
		return false
	var owned_material_ids := _owned_material_instance_ids()
	for relative_path_value in _built_mesh_contracts:
		var contract := _built_mesh_contracts[relative_path_value] as Dictionary
		var candidate := get_node_or_null(NodePath(str(relative_path_value)))
		if not candidate is MeshInstance3D:
			return false
		var mesh_instance := candidate as MeshInstance3D
		if (
			mesh_instance.get_instance_id() != int(contract.get("instance_id", 0))
			or not mesh_instance.visible
			or mesh_instance.mesh == null
			or mesh_instance.mesh.get_instance_id() != int(contract.get("mesh_instance_id", 0))
			or mesh_instance.mesh.get_class() != str(contract.get("mesh_class", ""))
			or not mesh_instance.mesh.get_aabb().is_equal_approx(contract.get("mesh_aabb", AABB()) as AABB)
			or _resource_storage_fingerprint(mesh_instance.mesh)
				!= (contract.get("mesh_storage", PackedStringArray()) as PackedStringArray)
			or not mesh_instance.transform.is_equal_approx(contract.get("transform", Transform3D.IDENTITY) as Transform3D)
			or mesh_instance.cast_shadow != int(contract.get("cast_shadow", -1))
			or mesh_instance.layers != int(contract.get("layers", 0))
			or not is_equal_approx(mesh_instance.visibility_range_begin, float(contract.get("visibility_range_begin", 0.0)))
			or not is_equal_approx(mesh_instance.visibility_range_end, float(contract.get("visibility_range_end", 0.0)))
			or not is_equal_approx(mesh_instance.visibility_range_begin_margin, float(contract.get("visibility_range_begin_margin", 0.0)))
			or not is_equal_approx(mesh_instance.visibility_range_end_margin, float(contract.get("visibility_range_end_margin", 0.0)))
			or mesh_instance.visibility_range_fade_mode != int(contract.get("visibility_range_fade_mode", -1))
			or not is_equal_approx(mesh_instance.transparency, float(contract.get("transparency", 0.0)))
			or (
				mesh_instance.mesh is PrimitiveMesh
				and (mesh_instance.mesh as PrimitiveMesh).flip_faces
					!= bool(contract.get("flip_faces", false))
			)
			or mesh_instance.material_override == null
			or not owned_material_ids.has(mesh_instance.material_override.get_instance_id())
		):
			return false
		if (
			not bool(contract.get("dynamic_material", false))
			and mesh_instance.material_override.get_instance_id()
				!= int(contract.get("material_instance_id", 0))
		):
			return false
	return (
		_built_multimesh_contracts_are_live()
		and _materials_match_build_contract()
		and _activity_pose_matches_clock()
	)


func _batch_transforms(batch: MultiMeshInstance3D) -> Array[Transform3D]:
	var recorded: Variant = _multimesh_batch_transforms.get(batch.get_instance_id())
	var result: Array[Transform3D] = []
	if recorded is Array:
		for value in recorded as Array:
			result.append(value as Transform3D)
	return result


func _built_multimesh_contracts_are_live() -> bool:
	var expected := int(_get_profile_performance_budget().get("multimesh_batches", 0))
	if _built_multimesh_contracts.size() != expected:
		return false
	var owned_material_ids := _owned_material_instance_ids()
	for relative_path_value in _built_multimesh_contracts:
		var contract := _built_multimesh_contracts[relative_path_value] as Dictionary
		var candidate := get_node_or_null(NodePath(str(relative_path_value)))
		if not candidate is MultiMeshInstance3D:
			return false
		var batch := candidate as MultiMeshInstance3D
		var recorded := contract.get("instance_transforms", []) as Array
		if (
			batch.get_instance_id() != int(contract.get("instance_id", 0))
			or not batch.visible
			or batch.multimesh == null
			or batch.multimesh.get_instance_id() != int(contract.get("multimesh_instance_id", 0))
			or batch.multimesh.mesh == null
			or batch.multimesh.mesh.get_instance_id() != int(contract.get("mesh_instance_id", 0))
			or not batch.multimesh.mesh.get_aabb().is_equal_approx(
				contract.get("mesh_aabb", AABB()) as AABB
			)
			or _resource_storage_fingerprint(batch.multimesh.mesh)
				!= (contract.get("mesh_storage", PackedStringArray()) as PackedStringArray)
			or not batch.multimesh.custom_aabb.is_equal_approx(
				contract.get("custom_aabb", AABB()) as AABB
			)
			or bool(batch.get_meta("explicit_authored_bounds", false))
				!= bool(contract.get("explicit_authored_bounds", false))
			or not batch.transform.is_equal_approx(
				contract.get("transform", Transform3D.IDENTITY) as Transform3D
			)
			or batch.cast_shadow != int(contract.get("cast_shadow", -1))
			or batch.layers != int(contract.get("layers", 0))
			or batch.multimesh.instance_count != recorded.size()
			or batch.material_override == null
			or batch.material_override.get_instance_id()
				!= int(contract.get("material_instance_id", 0))
			or not owned_material_ids.has(batch.material_override.get_instance_id())
		):
			return false
		var live := _batch_transforms(batch)
		if live.size() != recorded.size():
			return false
		for index in recorded.size():
			if not live[index].is_equal_approx(recorded[index] as Transform3D):
				return false
		if bool(contract.get("explicit_authored_bounds", false)):
			var expected_bounds := _transformed_mesh_bounds(
				batch.multimesh.mesh.get_aabb(), recorded
			)
			if not batch.multimesh.custom_aabb.is_equal_approx(expected_bounds):
				return false
		# Headless has no rendering buffer, so its structural audit stops at the
		# authored roster above. With a renderer, also prove the rendering server
		# received every transform rather than trusting only the CPU-side record.
		if not RenderingServer.get_video_adapter_name().is_empty():
			for index in recorded.size():
				if not batch.multimesh.get_instance_transform(index).is_equal_approx(
					recorded[index] as Transform3D
				):
					return false
	return true


func _transformed_mesh_bounds(mesh_bounds: AABB, transforms: Array) -> AABB:
	var result := AABB()
	var first := true
	for value in transforms:
		var transformed := ((value as Transform3D) * mesh_bounds).abs()
		if first:
			result = transformed
			first = false
		else:
			result = result.merge(transformed)
	return result


func _dynamic_node_instance_ids() -> Dictionary:
	var result := {}
	for candidate in [
		_gantry_carriage,
		_gantry_tool,
		_service_arm_shoulder,
		_service_arm_elbow,
		_service_arm_tool,
	]:
		if is_instance_valid(candidate):
			result[candidate.get_instance_id()] = true
	for drone in _drone_roots:
		if is_instance_valid(drone):
			result[drone.get_instance_id()] = true
	for mover in _station_life_movers:
		if is_instance_valid(mover):
			result[mover.get_instance_id()] = true
	return result


func _standard_material_contract(material: StandardMaterial3D) -> Dictionary:
	return {
		"instance_id": material.get_instance_id(),
		"albedo_color": material.albedo_color,
		"metallic": material.metallic,
		"roughness": material.roughness,
		"transparency": material.transparency,
		"emission_enabled": material.emission_enabled,
		"emission": material.emission,
		"emission_energy": material.emission_energy_multiplier,
		"cull_mode": material.cull_mode,
		"shading_mode": material.shading_mode,
		"vertex_color_use_as_albedo": material.vertex_color_use_as_albedo,
		"vertex_color_is_srgb": material.vertex_color_is_srgb,
		"distance_fade_mode": material.distance_fade_mode,
		"storage": _resource_storage_fingerprint(material),
	}


func _materials_match_build_contract() -> bool:
	if _built_material_contracts.size() != _materials.size():
		return false
	for material_key in _built_material_contracts:
		var material := _materials.get(material_key) as StandardMaterial3D
		var contract := _built_material_contracts[material_key] as Dictionary
		if (
			material == null
			or material.get_instance_id() != int(contract.get("instance_id", 0))
			or not material.albedo_color.is_equal_approx(contract.get("albedo_color", Color.TRANSPARENT) as Color)
			or not is_equal_approx(material.metallic, float(contract.get("metallic", 0.0)))
			or not is_equal_approx(material.roughness, float(contract.get("roughness", 0.0)))
			or material.transparency != int(contract.get("transparency", -1))
			or material.cull_mode != int(contract.get("cull_mode", -1))
			or material.shading_mode != int(contract.get("shading_mode", -1))
			or material.vertex_color_use_as_albedo != bool(contract.get("vertex_color_use_as_albedo", false))
			or material.vertex_color_is_srgb != bool(contract.get("vertex_color_is_srgb", false))
			or material.distance_fade_mode != int(contract.get("distance_fade_mode", -1))
			or material.emission_enabled != bool(contract.get("emission_enabled", false))
			or not material.emission.is_equal_approx(contract.get("emission", Color.TRANSPARENT) as Color)
			or not is_equal_approx(
				material.emission_energy_multiplier,
				float(contract.get("emission_energy", 0.0))
			)
			or _resource_storage_fingerprint(material)
				!= (contract.get("storage", PackedStringArray()) as PackedStringArray)
		):
			return false
	return true


func _dynamic_lens_materials_match_clock() -> bool:
	for index in _station_life_lenses.size():
		if (
			not is_instance_valid(_station_life_lenses[index])
			or _station_life_lenses[index].material_override
				!= _station_life_lens_material(index)
		):
			return false
	var beacon_pattern := _get_beacon_pattern()
	for index in _beacon_lenses.size():
		var expected_beacon: Material = (
			_materials["amber_lit"] if beacon_pattern[index] else _materials["amber_dim"]
		)
		if (
			not is_instance_valid(_beacon_lenses[index])
			or _beacon_lenses[index].material_override != expected_beacon
		):
			return false
	var seed_phase := fmod(float(_get_effective_variation_seed()), 997.0) / 997.0 * TAU
	for index in _drone_beacon_lenses.size():
		var lit := fmod(_elapsed + float(index) * 0.42 + seed_phase, 1.35) < 0.24
		var expected_drone: Material = (
			_materials["red_lit"] if lit else _materials["cyan_dim"]
		)
		if (
			not is_instance_valid(_drone_beacon_lenses[index])
			or _drone_beacon_lenses[index].material_override != expected_drone
		):
			return false
	return true


## Content fingerprint of every stored property on an owned resource.
##
## Values are recorded as a recursive content hash rather than as `var_to_str`
## text. The hash covers the same stored bytes, so the fingerprint keeps the same
## sensitivity; what it gives up is human-readable diagnostics, and nothing prints
## this fingerprint. The reason is cost: once this component's boxes became
## chamfered `ArrayMesh` resources, the text form had to serialise a full
## vertex/normal/tangent/UV/index buffer per mesh on every audit call. Measured on
## the FULL profile's 79 meshes that was 48-88 ms per pass, and it took
## `station_operations_activity_test` from 0.5 s to over 175 s, past its 180 s
## matrix timeout. With the hash the same suite runs in 0.6 s.
##
## `station_operations_activity_test` still drives this red by mutating a live
## generated mesh in place; see the drift witness there.
func _resource_storage_fingerprint(resource: Resource) -> PackedStringArray:
	var result := PackedStringArray()
	if resource == null:
		return result
	for property_value in resource.get_property_list():
		var property := property_value as Dictionary
		if int(property.get("usage", 0)) & PROPERTY_USAGE_STORAGE == 0:
			continue
		var property_name := StringName(property.get("name", &""))
		result.append("%s=%d" % [property_name, hash(resource.get(property_name))])
	result.sort()
	return result


func _node_matches_expected_pose(
	node: Node3D,
	expected_position: Vector3,
	expected_rotation: Vector3
) -> bool:
	return (
		is_instance_valid(node)
		and node.position.is_equal_approx(expected_position)
		and node.scale.is_equal_approx(Vector3.ONE)
		and node.basis.is_equal_approx(Basis.from_euler(expected_rotation, node.rotation_order))
	)


func _activity_pose_matches_clock() -> bool:
	var seed_phase := fmod(float(_get_effective_variation_seed()), 997.0) / 997.0 * TAU
	if _profile_has_gantry():
		var carriage_phase := _elapsed * 0.37 + seed_phase * 0.17
		if not _node_matches_expected_pose(
			_gantry_carriage,
			Vector3(sin(carriage_phase) * GANTRY_TRAVEL, GANTRY_ELEVATION, 0.0),
			Vector3.ZERO
		):
			return false
		if not _node_matches_expected_pose(
			_gantry_tool,
			Vector3(0.0, -0.12 - (0.18 + 0.16 * sin(_elapsed * 0.53 + seed_phase)), 0.0),
			Vector3(0.0, sin(_elapsed * 0.29 + seed_phase) * 0.12, 0.0)
		):
			return false
	if _profile_has_service_arm():
		if not _node_matches_expected_pose(
			_service_arm_shoulder,
			Vector3(0.0, 0.72, 0.0),
			Vector3(0.0, sin(_elapsed * 0.21 + seed_phase) * 0.18, -0.54 + sin(_elapsed * 0.31 + seed_phase) * 0.22)
		):
			return false
		if not _node_matches_expected_pose(
			_service_arm_elbow,
			Vector3(-0.05, 2.23, 0.0),
			Vector3(0.0, 0.0, 0.82 + sin(_elapsed * 0.43 + seed_phase + 0.7) * 0.28)
		):
			return false
		if not _node_matches_expected_pose(
			_service_arm_tool,
			Vector3(0.0, 1.65, 0.0),
			Vector3(0.0, _elapsed * 0.28 + seed_phase, sin(_elapsed * 0.51) * 0.09)
		):
			return false
	if _profile_has_drones():
		for index in _drone_roots.size():
			var phase := _elapsed * (0.24 + index * 0.035) + seed_phase + float(index) * PI
			if not _node_matches_expected_pose(
				_drone_roots[index],
				Vector3(cos(phase) * (3.55 - index * 0.28), _get_drone_base_elevation() + float(index) * 0.44 + sin(phase * 2.0) * 0.18, sin(phase) * (2.85 - index * 0.22)),
				Vector3(0.04 * sin(phase * 1.7), -phase + PI * 0.5, 0.08 * cos(phase))
			):
				return false
	for index in _station_life_movers.size():
		var pose := _station_life_mover_pose(index, seed_phase)
		if not _node_matches_expected_pose(_station_life_movers[index], pose[0], pose[1]):
			return false
	for index in _station_life_lenses.size():
		if _station_life_lenses[index].material_override != _station_life_lens_material(index):
			return false
	var beacon_pattern := _get_beacon_pattern()
	for index in _beacon_lenses.size():
		var expected_beacon_material: Material = _materials["amber_lit"] if beacon_pattern[index] else _materials["amber_dim"]
		if _beacon_lenses[index].material_override != expected_beacon_material:
			return false
	for index in _drone_beacon_lenses.size():
		var drone_pulse := fmod(_elapsed + float(index) * 0.42 + seed_phase, 1.35) < 0.24
		var expected_drone_material: Material = _materials["red_lit"] if drone_pulse else _materials["cyan_dim"]
		if _drone_beacon_lenses[index].material_override != expected_drone_material:
			return false
	return true


func _all_live_meshes_fit_published_envelope() -> bool:
	if (
		not is_instance_valid(_presentation_root)
		or not is_ancestor_of(_presentation_root)
		or not _built_presentation_hierarchy_is_live()
		or not _built_mesh_contracts_are_live()
	):
		return false
	var local_min := _get_profile_local_min() - Vector3.ONE * 0.03
	var local_max := _get_profile_local_max() + Vector3.ONE * 0.03
	var mesh_count := 0
	for candidate in find_children("*", "MeshInstance3D", true, false):
		var mesh_instance := candidate as MeshInstance3D
		if mesh_instance.mesh == null:
			return false
		var relative_transform_value: Variant = _node_transform_relative_to_component(mesh_instance)
		if not relative_transform_value is Transform3D:
			return false
		if not _bounds_fit(
			relative_transform_value as Transform3D, mesh_instance.get_aabb(), local_min, local_max
		):
			return false
		mesh_count += 1
	# Instanced structure is held to the same envelope, per copy rather than per
	# batch. A `MultiMeshInstance3D` node can sit inside the envelope while an
	# instance transform puts a rail tie outside it, and only the per-copy check
	# sees that.
	var batch_count := 0
	for candidate in find_children("*", "MultiMeshInstance3D", true, false):
		var batch := candidate as MultiMeshInstance3D
		if batch.multimesh == null or batch.multimesh.mesh == null:
			return false
		var batch_transform_value: Variant = _node_transform_relative_to_component(batch)
		if not batch_transform_value is Transform3D:
			return false
		var batch_transform := batch_transform_value as Transform3D
		var bounds := batch.multimesh.mesh.get_aabb()
		var instance_transforms := _batch_transforms(batch)
		if instance_transforms.size() != batch.multimesh.instance_count:
			return false
		for instance_transform in instance_transforms:
			if not _bounds_fit(batch_transform * instance_transform, bounds, local_min, local_max):
				return false
		batch_count += 1
	var budget := _get_profile_performance_budget()
	return (
		mesh_count == int(budget.get("mesh_instances", -1))
		and batch_count == int(budget.get("multimesh_batches", -1))
	)


func _bounds_fit(
		relative_transform: Transform3D,
		bounds: AABB,
		local_min: Vector3,
		local_max: Vector3
	) -> bool:
	for corner_index in 8:
		var corner := bounds.position + Vector3(
			bounds.size.x if corner_index & 1 else 0.0,
			bounds.size.y if corner_index & 2 else 0.0,
			bounds.size.z if corner_index & 4 else 0.0
		)
		var point: Vector3 = relative_transform * corner
		if (
			point.x < local_min.x or point.x > local_max.x
			or point.y < local_min.y or point.y > local_max.y
			or point.z < local_min.z or point.z > local_max.z
		):
			return false
	return true


func _node_transform_relative_to_component(node: Node3D) -> Variant:
	if not is_ancestor_of(node):
		return null
	var relative_transform := Transform3D.IDENTITY
	var current: Node = node
	while current != self:
		if not current is Node3D:
			return null
		relative_transform = (current as Node3D).transform * relative_transform
		current = current.get_parent()
		if current == null:
			return null
	return relative_transform


func _get_profile_local_min() -> Vector3:
	match _built_profile:
		ActivityProfile.GANTRY:
			return Vector3(-5.4, 0.0, -3.6)
		ActivityProfile.SERVICE_ARM:
			return Vector3(-2.4, 0.0, -1.75)
		ActivityProfile.DRONE_PATROL:
			return Vector3(-4.55, 0.0, -3.55)
		ActivityProfile.CARGO_LINE:
			return Vector3(-4.85, 0.0, -2.65)
		ActivityProfile.CARGO_LINE_LONG:
			return Vector3(-11.4, 0.0, -1.8)
		ActivityProfile.SIGNAGE_PYLON:
			return Vector3(-1.8, 0.0, -1.5)
		ActivityProfile.OBSERVATORY:
			return Vector3(-2.35, 0.0, -2.35)
		ActivityProfile.CREW_WORKPOST:
			return Vector3(-2.85, 0.0, -1.95)
		_:
			return FOOTPRINT_MIN


func _get_profile_local_max() -> Vector3:
	match _built_profile:
		ActivityProfile.GANTRY:
			return Vector3(5.4, 7.25, 3.6)
		ActivityProfile.SERVICE_ARM:
			return Vector3(2.4, 5.45, 1.75)
		ActivityProfile.DRONE_PATROL:
			return Vector3(4.55, 2.4, 3.55)
		ActivityProfile.CARGO_LINE:
			return Vector3(4.85, 2.98, 2.65)
		ActivityProfile.CARGO_LINE_LONG:
			return Vector3(11.4, 3.0, 1.8)
		ActivityProfile.SIGNAGE_PYLON:
			return Vector3(1.8, 4.5, 1.5)
		ActivityProfile.OBSERVATORY:
			return Vector3(2.35, 3.75, 2.35)
		ActivityProfile.CREW_WORKPOST:
			return Vector3(2.85, 2.6, 1.95)
		_:
			return FOOTPRINT_MAX


func _get_profile_service_zone_center() -> Vector3:
	match _built_profile:
		ActivityProfile.SERVICE_ARM:
			return Vector3(0.15, 2.3, 0.0)
		ActivityProfile.DRONE_PATROL:
			return Vector3(0.0, 1.35, 0.0)
		ActivityProfile.CARGO_LINE, ActivityProfile.CARGO_LINE_LONG:
			return Vector3(0.0, 1.5, 0.0)
		ActivityProfile.SIGNAGE_PYLON:
			return Vector3(0.0, 2.2, 0.0)
		ActivityProfile.OBSERVATORY:
			return Vector3(0.0, 2.3, 0.0)
		ActivityProfile.CREW_WORKPOST:
			return Vector3(0.0, 1.3, 0.0)
		_:
			return SERVICE_ZONE_CENTER


func _get_profile_service_zone_half_extents() -> Vector3:
	match _built_profile:
		ActivityProfile.GANTRY:
			return Vector3(5.9, 3.8, 4.1)
		ActivityProfile.SERVICE_ARM:
			return Vector3(2.6, 2.6, 1.9)
		ActivityProfile.DRONE_PATROL:
			return Vector3(5.0, 1.6, 4.2)
		ActivityProfile.CARGO_LINE:
			return Vector3(5.1, 1.8, 3.0)
		# Deliberately narrower in Z relative to its length than the short line's:
		# both live runs stand between the branch guard rails, and a wider service
		# claim would overlap a rail the rendered geometry clears by 0.36 m.
		ActivityProfile.CARGO_LINE_LONG:
			return Vector3(11.7, 1.8, 1.95)
		ActivityProfile.SIGNAGE_PYLON:
			return Vector3(2.0, 2.5, 1.8)
		ActivityProfile.OBSERVATORY:
			return Vector3(2.5, 2.4, 2.5)
		ActivityProfile.CREW_WORKPOST:
			return Vector3(3.0, 1.5, 2.2)
		_:
			return SERVICE_ZONE_HALF_EXTENTS


func _get_profile_mount_type() -> StringName:
	match _built_profile:
		ActivityProfile.SERVICE_ARM, ActivityProfile.CREW_WORKPOST:
			return &"deck_edge"
		ActivityProfile.DRONE_PATROL:
			return &"deck_or_inverted_ceiling_anchor"
		_:
			return &"level_deck"


func _get_profile_mount_description() -> String:
	match _built_profile:
		ActivityProfile.SERVICE_ARM:
			return "Origin is the service-arm rotary base at a level deck edge; local -Z faces the service lane."
		ActivityProfile.DRONE_PATROL:
			return "Origin is the patrol-zone mount plane; use upright on deck or rotate 180 degrees around local X for an inverted ceiling anchor."
		ActivityProfile.CARGO_LINE:
			return "Origin is the centre of the transfer rail on a level deck; the rail runs along local X and local -Z faces the handling apron."
		ActivityProfile.CARGO_LINE_LONG:
			return "Origin is the centre of a 21.6 m transfer run on a level deck; the rail runs along local X under a full-length overhead hoist gantry, the inbound stack stands on local +Z and the outbound stack on local -Z, and the run needs 22.8 m of continuous level floor."
		ActivityProfile.SIGNAGE_PYLON:
			return "Origin is the pylon base plinth on a level deck; the lit board, plaque and chevron strip all face local +Z, so the pylon is mounted facing the approach."
		ActivityProfile.OBSERVATORY:
			return "Origin is the centre of the three-legged skywatch plinth on a level deck; the instrument needs open sky above and pans a full arc."
		ActivityProfile.CREW_WORKPOST:
			return "Origin is the deck-edge work post; the bench and tool wall back onto local +Z and the crew stands on the local -Z side."
		_:
			return "Origin is the centre of the level deck footprint; local -Z faces the serviced berth or traffic lane."


func _get_drone_motion_envelope() -> Dictionary:
	if not _profile_has_drones():
		return {
			"present": false,
			"local_center": Vector3.ZERO,
			"half_extents": Vector3.ZERO,
		}
	return {
		"present": true,
		"local_center": Vector3(0.0, _get_drone_base_elevation() + 0.22, 0.0),
		"half_extents": Vector3(4.45, 0.72, 3.35),
		"route_type": &"deterministic_elliptical_patrol",
		"collision_policy": &"presentation_only_nonblocking",
	}


func _get_drone_base_elevation() -> float:
	return (
		FULL_DRONE_BASE_ELEVATION
		if _built_profile == ActivityProfile.FULL
		else ROOF_PATROL_DRONE_BASE_ELEVATION
	)


func _refresh_lifecycle() -> void:
	if _presentation_root != null:
		_presentation_root.visible = _activity_enabled
	set_process(_activity_enabled and not _activity_paused)
	# Pre-tree setters are valid configuration and have no world-owned sibling to
	# notify yet. Reading `global_transform` there emits an engine diagnostic; the
	# explicit builder sync and `_enter_tree()` publish once a world frame exists.
	if is_inside_tree():
		solid_volume_state_changed.emit(_activity_enabled, global_transform)


func _update_activity_transforms() -> void:
	if not _built:
		return
	var seed_phase := fmod(float(_get_effective_variation_seed()), 997.0) / 997.0 * TAU
	if _gantry_carriage != null and _gantry_tool != null:
		var carriage_phase := _elapsed * 0.37 + seed_phase * 0.17
		_gantry_carriage.position = Vector3(sin(carriage_phase) * GANTRY_TRAVEL, GANTRY_ELEVATION, 0.0)
		_gantry_tool.position.y = -0.12 - (0.18 + 0.16 * sin(_elapsed * 0.53 + seed_phase))
		_gantry_tool.rotation.y = sin(_elapsed * 0.29 + seed_phase) * 0.12

	if _service_arm_shoulder != null and _service_arm_elbow != null and _service_arm_tool != null:
		_service_arm_shoulder.rotation = Vector3(0.0, sin(_elapsed * 0.21 + seed_phase) * 0.18, -0.54 + sin(_elapsed * 0.31 + seed_phase) * 0.22)
		_service_arm_elbow.rotation = Vector3(0.0, 0.0, 0.82 + sin(_elapsed * 0.43 + seed_phase + 0.7) * 0.28)
		_service_arm_tool.rotation = Vector3(0.0, _elapsed * 0.28 + seed_phase, sin(_elapsed * 0.51) * 0.09)

	for index in _drone_roots.size():
		var drone := _drone_roots[index]
		var phase := _elapsed * (0.24 + index * 0.035) + seed_phase + float(index) * PI
		var radius_x := 3.55 - index * 0.28
		var radius_z := 2.85 - index * 0.22
		drone.position = Vector3(
			cos(phase) * radius_x,
			_get_drone_base_elevation() + float(index) * 0.44 + sin(phase * 2.0) * 0.18,
			sin(phase) * radius_z
		)
		drone.rotation = Vector3(0.04 * sin(phase * 1.7), -phase + PI * 0.5, 0.08 * cos(phase))

	for index in _station_life_movers.size():
		var pose := _station_life_mover_pose(index, seed_phase)
		_station_life_movers[index].position = pose[0]
		_station_life_movers[index].rotation = pose[1]
	for index in _station_life_lenses.size():
		_station_life_lenses[index].material_override = _station_life_lens_material(index)

	var pattern := _get_beacon_pattern()
	for index in _beacon_lenses.size():
		_beacon_lenses[index].material_override = _materials["amber_lit"] if pattern[index] else _materials["amber_dim"]
	for index in _drone_beacon_lenses.size():
		var drone_pulse := fmod(_elapsed + float(index) * 0.42 + seed_phase, 1.35) < 0.24
		_drone_beacon_lenses[index].material_override = _materials["red_lit"] if drone_pulse else _materials["cyan_dim"]


func _get_beacon_pattern() -> Array[bool]:
	var result: Array[bool] = []
	var seed_phase_seconds := fmod(float(_get_effective_variation_seed()), 31.0) * 0.013
	for index in BEACON_COUNT:
		var pulse_time := fmod(_elapsed + seed_phase_seconds + float(index % 2) * 0.55, 1.1)
		result.append(pulse_time < 0.22)
	return result


## The complete pose of one station-life mover as a pure function of the clock.
##
## Returns `[position, rotation]`. Every branch is a closed-form function of
## `_elapsed` and the build seed only, so a 120 Hz process and a single 30 Hz
## step land on the same transform, and `set_activity_time()` reproduces any
## earlier frame exactly.
func _station_life_mover_pose(index: int, seed_phase: float) -> Array:
	match _built_profile:
		ActivityProfile.CARGO_LINE:
			if index == 0:
				# Container sled shuttling the fixed rail, easing at both stops.
				# Travel re-frozen 3.3 -> 3.24 by the clearance probe: at 3.3 the
				# 1.9 m sled deck reached x = 4.25 while the rail stop's inner face
				# is at 4.22, so at each end of every pass the sled corner sat 0.03 m
				# inside the stop that is meant to stop it. 3.24 leaves 0.03 m of
				# daylight instead. Six centimetres of an 6.6 m stroke.
				var travel := sin(_elapsed * 0.23 + seed_phase * 0.31)
				# y = 0.50 puts the wheel treads exactly on the rail heads at
				# y = 0.23; anything lower sinks the sled into its own track.
				return [
					Vector3(travel * 3.24, 0.5, 0.0),
					Vector3(0.0, 0.0, 0.0),
				]
			# Overhead hoist tracking across the line and dipping to the deck.
			# Traverse only. The carriage stays at y = 2.62 so it always meets the
			# underside of `HoistBeam` at y = 2.65; a vertical beat would need a
			# stretching cable, and a scaled mover is exactly what the audit's
			# pose check forbids, so the carriage would visibly detach from its
			# own rail instead. It is confined to the +Z apron lane because at
			# z >= 1.05 the hook clears the sled container it would otherwise
			# pass straight through.
			var hoist_phase := _elapsed * 0.31 + seed_phase
			return [
				Vector3(0.0, 2.62, 1.35 + sin(hoist_phase) * 0.3),
				Vector3(0.0, sin(hoist_phase * 0.5) * 0.15, 0.0),
			]
		ActivityProfile.CARGO_LINE_LONG:
			if index == 0:
				# Container sled working the full run: 19.2 m of travel, easing at
				# both stops. The rail stops' inner faces are at x = +/-10.88 and
				# the sled deck's half length is 0.95, so the sled comes to rest
				# 0.33 m short of the stop rather than through it. y = 0.50 puts
				# the wheel treads on the rail heads at y = 0.23, the same seat the
				# short line uses.
				return [
					Vector3(sin(_elapsed * 0.135 + seed_phase * 0.31) * 9.6, 0.5, 0.0),
					Vector3.ZERO,
				]
			# Travelling hoist bridge. It tracks the whole rail at a different rate
			# from the sled, so the two pass each other rather than shadowing one
			# another. Traverse only, and at a fixed height: y = 2.66 puts the
			# bridge's top at 2.80, overlapping the hoist rail underside at 2.76,
			# so the bridge cannot separate from the rail it rides. A vertical beat
			# would need a stretching cable, and a scaled mover is exactly what the
			# pose audit forbids. The hook's lowest point is y = 1.73, clearing the
			# sled container roof at y = 1.60 by 0.13 m at every phase of both.
			return [
				Vector3(sin(_elapsed * 0.191 + seed_phase) * 8.4, 2.66, 0.0),
				Vector3(0.0, 0.0, 0.0),
			]
		ActivityProfile.SIGNAGE_PYLON:
			# Slow continuous drum rotation; the chevrons below do the chasing.
			return [
				Vector3(0.0, 4.05, 0.0),
				Vector3(0.0, _elapsed * 0.19 + seed_phase, 0.0),
			]
		ActivityProfile.OBSERVATORY:
			if index == 0:
				# Yoke pans across a bounded arc rather than spinning freely.
				return [
					Vector3(0.0, 2.05, 0.0),
					Vector3(0.0, sin(_elapsed * 0.11 + seed_phase) * 1.05, 0.0),
				]
			# Optic tube elevation. The sign is positive so the -Z aperture end
			# rises: the instrument always reads as looking out of the station
			# rather than down at the deck it stands on.
			return [
				Vector3(0.0, 0.85, 0.0),
				Vector3(0.34 + sin(_elapsed * 0.17 + seed_phase + 0.9) * 0.26, 0.0, 0.0),
			]
		ActivityProfile.CREW_WORKPOST:
			if index == 0:
				# Tool carousel indexing round the bench.
				return [
					Vector3(0.55, 1.28, 0.55),
					Vector3(0.0, _elapsed * 0.27 + seed_phase, 0.0),
				]
			# Weld jig nodding over the work.
			return [
				Vector3(-2.0, 1.55, -0.75),
				Vector3(0.0, sin(_elapsed * 0.37 + seed_phase) * 0.21, -0.24 + sin(_elapsed * 0.83 + seed_phase) * 0.22),
			]
	return [Vector3.ZERO, Vector3.ZERO]


func _station_life_lens_material(index: int) -> Material:
	var spec := _station_life_lens_specs[index]
	var seed_phase_seconds := fmod(float(_get_effective_variation_seed()), 31.0) * 0.013
	var pulse := fmod(_elapsed + seed_phase_seconds + float(spec.offset), float(spec.period))
	return _materials[spec.lit] if pulse < float(spec.duty) else _materials[spec.dim]


func _apply_evidence_metadata() -> void:
	set_meta("component_id", COMPONENT_ID)
	set_meta("evidence_status", EVIDENCE_STATUS)
	set_meta("presentation_only", true)
	set_meta("nonblocking_collision", true)
	set_meta("content_note", CONTENT_NOTE)
	_presentation_root.set_meta("evidence_status", EVIDENCE_STATUS)
	_presentation_root.set_meta("modern_interpretation", true)
	add_to_group(&"station_operations_activity")


func _count_runtime_resources(node: Node, counts: Dictionary, material_ids: Dictionary) -> void:
	counts["node_count"] = int(counts.node_count) + 1
	if node is MultiMeshInstance3D:
		var batch := node as MultiMeshInstance3D
		counts["multimesh_batches"] = int(counts.multimesh_batches) + 1
		if batch.multimesh != null:
			counts["multimesh_instances"] = (
				int(counts.multimesh_instances) + batch.multimesh.instance_count
			)
		if batch.material_override != null:
			material_ids[batch.material_override.get_instance_id()] = true
	elif node is MeshInstance3D:
		counts["mesh_instances"] = int(counts.mesh_instances) + 1
		var material := (node as MeshInstance3D).material_override
		if material != null:
			material_ids[material.get_instance_id()] = true
	if node is Light3D:
		counts["lights"] = int(counts.lights) + 1
	if node is GPUParticles3D or node is CPUParticles3D:
		counts["particle_emitters"] = int(counts.particle_emitters) + 1
	if node is CollisionObject3D or node is CollisionShape3D or node is CollisionPolygon3D:
		counts["collision_nodes"] = int(counts.collision_nodes) + 1
	for child in node.get_children():
		_count_runtime_resources(child, counts, material_ids)
