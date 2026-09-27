class_name AbandonedStationHulk
extends Node3D

## The one destination in the nearby sector you can go *inside*.
##
## Everything else out here is flown past or scanned: the beacons, the moonlet,
## the debris drift, the open dock gate and the extraction platform are all
## exterior silhouettes. This is the exception. The hulk is a dead orbital
## service station that the pilot flies to, parks against, climbs out of and
## walks through, and it is deliberately built from the same stock the shipyard
## is built from so it costs what a station module costs.
##
## **It is not a second docking system.** The docking face carries one ordinary
## [ShipBerth]: the same lease/occupancy contract `ShipyardWorld` registers for
## Central, Arrow, Dock 04-06 and the fleet docks, and the same one
## `EmberSurfaceBerth` adapts for the caldera pad. `GameFlow` reserves, occupies
## and releases it through its existing berth path, and the pilot leaves the seat
## through the existing `ShipBoardingArea`/disembark seam. Nothing here reserves,
## occupies, lands, boards or moves a craft on its own.
##
## **It owns no reward authority.** The single bounded activity inside — throwing
## the auxiliary breaker in the reactor gallery — is a detached
## [DerelictPowerRestorationActivity] snapshot. `GameFlow` alone crosses it into
## the existing `GameFlowRewardAuthority`, so the hulk cannot grant anything.
##
## **Silhouette.** The extraction platform is a vertical drum on a rock with a
## horizontal processing spine and a gantry. This reads as its own thing at
## approach distance because it is the opposite shape: one long flat-sided hull
## lying *across* the approach, 80 m of it, broken open at the bow, with two
## collar rings, a snapped mast raked off the spine and a lit dock shelf on the
## station-facing flank. Nothing on it spins and nothing on it is ochre.
##
## Everything here is `modern_interpretation`. No source names or depicts this
## station, this sector or anything in it.

const SCHEMA_VERSION := 1
const COMPONENT_ID: StringName = &"abandoned-station-hulk"
const EVIDENCE_STATUS: StringName = &"modern_interpretation"
const CONTENT_CLASS: StringName = &"NEW"
const WORLD_LAYER := PhysicsLayers.WORLD

const CONTENT_NOTE := (
	"The abandoned station hulk, its dock shelf and its three interior spaces "
	+ "are original modern remake design. No surviving source names, depicts or "
	+ "authenticates a derelict station in this sector."
)

## Station-relative anchor. The cluster root is mounted at the shipyard origin
## with an identity transform, so this is also a world coordinate. 486 m out,
## port and high: off the starboard-low beacon chain, off the platform approach
## lane, and 167 m clear of the ringed moonlet's 90 m body.
const HULK_ANCHOR := Vector3(-120.0, 26.0, -470.0)
## The hull lies along local X. Local +Z faces the station, so the dock shelf and
## the walk-in aperture are both on the side the pilot arrives from.
const HULL_LENGTH := 78.0
## Everything the hulk physically occupies fits inside this radius of the
## anchor: half the hull, plus the dock shelf, plus the raked mast.
## The broken bow truss is the furthest-reaching piece; it is presentation only
## and carries no collision, but the envelope still reserves it.
const HULL_BOUNDING_RADIUS := 54.0
const HULL_HEIGHT := 12.0
const HULL_DEPTH := 22.0
const HULL_PLATE := 2.0
## Interior deck and overhead, measured off the hull shell above.
const DECK_Y := -4.0
const OVERHEAD_Y := 4.0
## Walk-in aperture in the starboard flank, level with the deck.
const APERTURE_MIN_X := 21.0
const APERTURE_MAX_X := 27.0
const APERTURE_CENTER_X := 24.0
const APERTURE_WIDTH := APERTURE_MAX_X - APERTURE_MIN_X

## The three connected spaces, as [min_x, max_x] on the interior deck. They are
## a straight run so the walk reads without a map: come in at the dock, cross
## the vestibule, take the spine corridor forward, end in the reactor gallery.
const VESTIBULE_RANGE := Vector2(14.0, 39.0)
const CORRIDOR_RANGE := Vector2(-10.0, 14.0)
const GALLERY_RANGE := Vector2(-39.0, -10.0)
const SPACE_IDS: Array[StringName] = [
	&"dock_vestibule",
	&"spine_corridor",
	&"reactor_gallery",
]
## Both internal bulkheads carry the same 4 m x 6 m doorway on the centreline.
const DOORWAY_HALF_WIDTH := 2.0
const DOORWAY_HEAD_Y := 2.0
const BULKHEAD_DOCK_X := 14.0
const BULKHEAD_GALLERY_X := -10.0

## Dock shelf and berth. The shelf deck is flush with the interior deck, so the
## walk from the parked hull to the aperture has no step in it.
const DOCK_SHELF_CENTER := Vector3(APERTURE_CENTER_X, DECK_Y - 1.0, 20.0)
const DOCK_SHELF_SIZE := Vector3(26.0, 2.0, 20.0)
const BERTH_ID: StringName = &"cinder_hulk_dock"
const BERTH_LOCAL_POSITION := Vector3(APERTURE_CENTER_X, DECK_Y, 20.0)
## Every production hull the player can fly carries `small_craft` or
## `medium_craft`; the shelf is sized for both and tagged for both rather than
## inventing a hulk-only class of ship.
const BERTH_COMPATIBILITY_TAGS: Array[String] = ["small_craft", "medium_craft"]
const BERTH_DOCK_HEIGHT := 2.4
const BERTH_LANDING_HALF_EXTENTS := Vector3(9.0, 5.0, 9.0)
const BERTH_ASSIST_CAPTURE_CENTER := Vector3(0.0, 8.0, -18.0)
const BERTH_ASSIST_CAPTURE_HALF_EXTENTS := Vector3(20.0, 14.0, 30.0)
const BERTH_ASSIST_MAXIMUM_SPEED := 32.0
const BERTH_ASSIST_MAXIMUM_TILT_DEGREES := 75.0

## The breaker stands on the gallery deck beside the dead reactor drum. The
## drum and its plinth are pushed to the port side of the gallery precisely so
## this panel, and the walk to it, stay on clear deck.
const BREAKER_LOCAL_POSITION := Vector3(-26.0, DECK_Y + 1.8, 3.0)
const REACTOR_LOCAL_Z := -6.0
const BREAKER_INTERACTION_EXTENTS := Vector3(1.6, 1.8, 1.6)

## Powered-down means practicals, not station lighting. Eight shadowless omnis:
## three in the gallery, two in the corridor, two in the vestibule and one over
## the dock shelf, every one of them dim and short-range, so the interior reads
## as emergency power rather than as a lit room.
const LIGHT_BUDGET := 8
const PRACTICAL_ENERGY := 0.85
const PRACTICAL_RANGE := 11.0
const RESTORED_PRACTICAL_ENERGY := 2.1
const RESTORED_PRACTICAL_RANGE := 18.0
const RESTORED_PRACTICAL_ATTENUATION := 0.8
const EMERGENCY_PRACTICAL_ATTENUATION := 2.1
const RESTORED_BUS_COLOR := Color("b9e9ff")
const PRACTICAL_FADE_BEGIN := 60.0
const PRACTICAL_FADE_LENGTH := 25.0
const EMERGENCY_AMBER := Color("ff9f43")
const EMERGENCY_RED := Color("e0503a")
const DOCK_CYAN := Color("48dbe2")

## Component-local census contract, held by the suite rather than trusted. The
## hulk is streamed content: it is never in the resident scene, so these are the
## exact nodes one loaded Cinder generation gains.
const PERFORMANCE_BUDGET := {
	"static_bodies": 18,
	# 39 structural/fitting meshes plus the one merged silhouette-detail renderer.
	"mesh_instances": 40,
	"omni_lights": LIGHT_BUDGET,
	"spot_lights": 0,
	"shadow_casting_lights": 0,
	"audio_nodes": 0,
	"particle_emitters": 0,
	"animation_players": 0,
	"ship_berths": 1,
}

## Approach-silhouette pass. Everything that makes the hulk read as a derelict
## *station* from 400+ m (broken bow truss, antenna stubs, proud hull plates in two
## tones, dark port rows and breaches, and a warm light pool on the dock shelf)
## is merged into one presentation-only renderer with one surface per finish, so
## the pass costs one node, five submissions and no light at all. Emergency
## practicals fade out at 85 m; from the lane only emissive and silhouette read.
const SILHOUETTE_DETAIL_NAME := "SilhouetteDetail"
const SILHOUETTE_TRIANGLE_BUDGET := 2500
const SILHOUETTE_SURFACE_ROLES: Array[StringName] = [
	&"pale_structure", &"dark_plate", &"aperture", &"warm_lamp", &"warm_pool",
]
const WARM_POOL_COLOR := Color("ffb46a")
const WARM_POOL_ENERGY := 1.6
## Interior partitions, fittings and the breaker are only visible through the
## walk-in aperture and the bow break; past this range they are not drawn at all.
const INTERIOR_VISIBILITY_END := 160.0
const INTERIOR_VISIBILITY_MARGIN := 40.0
## Small exterior trim (guide fins, ribs) stops drawing where it is sub-pixel.
const SMALL_TRIM_VISIBILITY_END := 520.0
const SMALL_TRIM_VISIBILITY_MARGIN := 80.0
const WARM_POOL_SHADER_CODE := """
shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, shadows_disabled;
uniform vec4 pool_color : source_color = vec4(1.0, 0.7, 0.42, 1.0);
uniform float pool_energy = 1.6;
void fragment() {
	float d = length(UV - vec2(0.5)) * 2.0;
	float falloff = 1.0 - smoothstep(0.0, 1.0, d);
	falloff *= falloff;
	ALBEDO = pool_color.rgb * pool_energy * falloff * COLOR.a;
}
"""

const HULL_STEEL := Color("2f3a44")
const HULL_PALE := Color("55606a")
const HULL_CHAR := Color("14171b")

var _exterior_root: Node3D
var _interior_root: Node3D
var _fitting_root: Node3D
var _berth: ShipBerth
var _breaker: Area3D
var _lights: Array[OmniLight3D] = []
var _auxiliary_power_restored := false
var _materials: Dictionary = {}
var _box_cache: Dictionary = {}
var _cylinder_cache: Dictionary = {}
var _built := false
var _quality_level := 2
var _audit_report: Dictionary = {}


## Built by the owning cluster after its materials exist, so the hulk shares the
## cluster's mesh caches and its manufactured panel recipes instead of
## duplicating a second copy of every box and cylinder in the sector.
func build(
		shared_materials: Dictionary,
		box_cache: Dictionary,
		cylinder_cache: Dictionary
	) -> bool:
	if _built:
		return false
	_built = true
	_materials = shared_materials
	_box_cache = box_cache
	_cylinder_cache = cylinder_cache
	position = HULK_ANCHOR
	_create_local_materials()
	_exterior_root = _child_root("Exterior")
	_interior_root = _child_root("Interior")
	_fitting_root = _child_root("Fittings")
	_build_hull_shell()
	_build_dock_face()
	_build_interior_partitions()
	_build_interior_fittings()
	_build_exterior_detail()
	_build_silhouette_detail()
	_build_practicals()
	_build_berth()
	_build_breaker()
	_apply_visibility_ranges()
	_audit_report = _compose_audit_report()
	return true


func is_built() -> bool:
	return _built


## The physical lease the pilot's craft parks against. `GameFlow` owns every
## reservation, occupancy and release on it; the hulk never touches the lease.
func get_dock_berth() -> ShipBerth:
	return _berth


func get_dock_berth_id() -> StringName:
	return BERTH_ID


func get_breaker() -> Area3D:
	return _breaker


func get_anchor() -> Vector3:
	return HULK_ANCHOR


func get_station_distance() -> float:
	return HULK_ANCHOR.length()


## World-space centre of each connected interior space, published so the suite
## can walk the real route rather than trusting authored prose.
func get_interior_route_points() -> Array[Vector3]:
	var points: Array[Vector3] = []
	for local: Vector3 in [
		# The parked craft's shelf, outside the hull.
		Vector3(DOCK_SHELF_CENTER.x, DECK_Y + 1.0, DOCK_SHELF_CENTER.z),
		# Through the walk-in aperture.
		Vector3(APERTURE_CENTER_X, DECK_Y + 1.0, 4.0),
		# The three connected spaces, in the order they are walked. Only the
		# gallery point is off the centreline, because the reactor plinth holds
		# the port half of that room.
		Vector3((VESTIBULE_RANGE.x + VESTIBULE_RANGE.y) * 0.5, DECK_Y + 1.0, 0.0),
		Vector3((CORRIDOR_RANGE.x + CORRIDOR_RANGE.y) * 0.5, DECK_Y + 1.0, 0.0),
		Vector3((GALLERY_RANGE.x + GALLERY_RANGE.y) * 0.5, DECK_Y + 1.0, 2.0),
		# Standing at the breaker.
		Vector3(BREAKER_LOCAL_POSITION.x, DECK_Y + 1.0, BREAKER_LOCAL_POSITION.z - 2.2),
	]:
		points.append(to_global(local))
	return points


func get_breaker_world_position() -> Vector3:
	return to_global(BREAKER_LOCAL_POSITION)


func get_dock_world_transform() -> Transform3D:
	return _berth.get_dock_transform() if is_instance_valid(_berth) else Transform3D.IDENTITY


## Only presentation scales with the graphics option. Every collision shape, the
## deck, the doorways and the dock shelf are identical at all three settings,
## because the walkable shape of a destination must not depend on a slider.
func set_detail_quality(quality: int) -> void:
	_quality_level = clampi(quality, 0, 2)
	if not _built:
		return
	var trim := _exterior_root.get_node_or_null(^"HullRibTrim") as Node3D
	if trim != null:
		trim.visible = _quality_level >= 1


func get_detail_quality() -> int:
	return _quality_level


func get_audit_report() -> Dictionary:
	return _audit_report.duplicate(true)


func get_light_nodes() -> Array[OmniLight3D]:
	var result: Array[OmniLight3D] = []
	for light in _lights:
		if is_instance_valid(light):
			result.append(light)
	return result


## Presentation only. The reward authority supplies the claimed state; this
## component never decides whether the breaker earned a cell.
func set_auxiliary_power_restored(restored: bool) -> void:
	_auxiliary_power_restored = restored
	for light in get_light_nodes():
		if light.name == "DockShelfPractical":
			continue
		light.light_color = (
			RESTORED_BUS_COLOR if restored else light.get_meta("emergency_color") as Color
		)
		light.omni_range = RESTORED_PRACTICAL_RANGE if restored else PRACTICAL_RANGE
		light.omni_attenuation = (
			RESTORED_PRACTICAL_ATTENUATION
			if restored else EMERGENCY_PRACTICAL_ATTENUATION
		)
		var authored_energy := (
			RESTORED_PRACTICAL_ENERGY
			if restored else float(light.get_meta("emergency_energy"))
		)
		var cluster := get_parent()
		if cluster != null and cluster.has_method(&"refresh_station_hulk_light_energy"):
			cluster.call(&"refresh_station_hulk_light_energy", light, authored_energy)
		else:
			light.light_energy = authored_energy


func is_auxiliary_power_restored() -> bool:
	return _auxiliary_power_restored


func count_live_nodes() -> Dictionary:
	var shadow_casting := 0
	for candidate in find_children("*", "Light3D", true, false):
		if (candidate as Light3D).shadow_enabled:
			shadow_casting += 1
	return {
		"static_bodies": find_children("*", "StaticBody3D", true, false).size(),
		"mesh_instances": find_children("*", "MeshInstance3D", true, false).size(),
		"omni_lights": find_children("*", "OmniLight3D", true, false).size(),
		"spot_lights": find_children("*", "SpotLight3D", true, false).size(),
		"shadow_casting_lights": shadow_casting,
		"audio_nodes": find_children("*", "AudioStreamPlayer3D", true, false).size(),
		"particle_emitters": find_children("*", "GPUParticles3D", true, false).size(),
		"animation_players": find_children("*", "AnimationPlayer", true, false).size(),
		"ship_berths": find_children("*", "ShipBerth", true, false).size(),
		"collision_shapes": find_children("*", "CollisionShape3D", true, false).size(),
	}


# --- Build -------------------------------------------------------------------


func _child_root(node_name: String) -> Node3D:
	var node := Node3D.new()
	node.name = node_name
	add_child(node)
	return node


## The hull is a *shell*, not a solid. A solid drum would look identical from
## outside and be unwalkable inside, so the six plates below are the exterior
## silhouette and the interior ceiling/deck at the same time, and every one of
## them is a real collision body: a craft cannot fly through the hull and the
## pilot cannot fall out of it.
func _build_hull_shell() -> void:
	var half_length := HULL_LENGTH * 0.5
	var half_depth := HULL_DEPTH * 0.5
	_box(
		_exterior_root,
		"HullDeck",
		Vector3(0.0, DECK_Y - HULL_PLATE * 0.5, 0.0),
		Vector3(HULL_LENGTH, HULL_PLATE, HULL_DEPTH),
		_materials["hulk_deck"]
	)
	_box(
		_exterior_root,
		"HullOverhead",
		Vector3(0.0, OVERHEAD_Y + HULL_PLATE * 0.5, 0.0),
		Vector3(HULL_LENGTH, HULL_PLATE, HULL_DEPTH),
		_materials["hulk_hull"]
	)
	_box(
		_exterior_root,
		"HullFlankPort",
		Vector3(0.0, 0.0, -half_depth + HULL_PLATE * 0.5),
		Vector3(HULL_LENGTH, HULL_HEIGHT, HULL_PLATE),
		_materials["hulk_hull"]
	)
	# The starboard flank is split around the walk-in aperture rather than
	# modelled as a hole, so the opening is exactly the gap between two plates
	# and the collision envelope stays two simple boxes.
	var fore_length := APERTURE_MIN_X + half_length
	_box(
		_exterior_root,
		"HullFlankStarboardFore",
		Vector3(APERTURE_MIN_X - fore_length * 0.5, 0.0, half_depth - HULL_PLATE * 0.5),
		Vector3(fore_length, HULL_HEIGHT, HULL_PLATE),
		_materials["hulk_hull"]
	)
	var aft_length := half_length - APERTURE_MAX_X
	_box(
		_exterior_root,
		"HullFlankStarboardAft",
		Vector3(APERTURE_MAX_X + aft_length * 0.5, 0.0, half_depth - HULL_PLATE * 0.5),
		Vector3(aft_length, HULL_HEIGHT, HULL_PLATE),
		_materials["hulk_hull"]
	)
	_box(
		_exterior_root,
		"HullCapAft",
		Vector3(half_length + HULL_PLATE * 0.5, 0.0, 0.0),
		Vector3(HULL_PLATE, HULL_HEIGHT, HULL_DEPTH),
		_materials["hulk_hull"]
	)
	# The bow cap is the broken end: it is charred and it stops short of the
	# overhead, so the derelict reads as opened up rather than merely parked.
	_box(
		_exterior_root,
		"HullCapBowBreak",
		Vector3(-half_length - HULL_PLATE * 0.5, -1.4, 0.0),
		Vector3(HULL_PLATE, HULL_HEIGHT - 2.8, HULL_DEPTH),
		_materials["hulk_char"]
	)


func _build_dock_face() -> void:
	_box(
		_exterior_root,
		"DockShelf",
		DOCK_SHELF_CENTER,
		DOCK_SHELF_SIZE,
		_materials["hulk_deck"]
	)
	# Two low guide fins frame the shelf. They are presentation only: a fin that
	# could catch a descending hull would be a second landing contract.
	for side: float in [-1.0, 1.0]:
		var fin := _box(
			_exterior_root,
			"DockGuideFin",
			Vector3(
				APERTURE_CENTER_X + side * 12.0,
				DECK_Y + 0.6,
				DOCK_SHELF_CENTER.z + 4.0
			),
			Vector3(1.2, 1.2, 12.0),
			_materials["hulk_trim"],
			false
		)
		fin.set_meta(&"small_trim", true)
	# One lit approach stripe down the shelf centreline, and the aperture
	# surround, so the docking face is findable from the lane without a HUD.
	_box(
		_exterior_root,
		"DockApproachStripe",
		Vector3(APERTURE_CENTER_X, DECK_Y + 0.06, DOCK_SHELF_CENTER.z + 2.0),
		Vector3(1.0, 0.12, 16.0),
		_materials["hulk_dock_glow"],
		false
	)
	for side: float in [-1.0, 1.0]:
		_box(
			_exterior_root,
			"DockApertureSurround",
			Vector3(
				APERTURE_CENTER_X + side * (APERTURE_WIDTH * 0.5 + 0.35),
				0.0,
				HULL_DEPTH * 0.5 - HULL_PLATE - 0.2
			),
			Vector3(0.7, HULL_HEIGHT - 1.0, 0.4),
			_materials["hulk_dock_glow"],
			false
		)


## Two bulkheads with one doorway each turn the hull into three spaces. Each is
## a port panel, a starboard panel and a head above the opening, so the doorway
## is a real 4 m x 6 m gap in solid collision rather than a scripted trigger.
func _build_interior_partitions() -> void:
	for bulkhead: Dictionary in [
		{"name": "BulkheadDock", "x": BULKHEAD_DOCK_X},
		{"name": "BulkheadGallery", "x": BULKHEAD_GALLERY_X},
	]:
		var bulkhead_x := float(bulkhead["x"])
		var panel_depth := (HULL_DEPTH * 0.5 - HULL_PLATE) - DOORWAY_HALF_WIDTH
		var panel_center := DOORWAY_HALF_WIDTH + panel_depth * 0.5
		for side: float in [-1.0, 1.0]:
			_box(
				_interior_root,
				"%sPanel" % bulkhead["name"],
				Vector3(bulkhead_x, 0.0, side * panel_center),
				Vector3(1.6, HULL_HEIGHT - 4.0, panel_depth),
				_materials["hulk_bulkhead"]
			)
		var head_height := OVERHEAD_Y - DOORWAY_HEAD_Y
		_box(
			_interior_root,
			"%sHead" % bulkhead["name"],
			Vector3(bulkhead_x, DOORWAY_HEAD_Y + head_height * 0.5, 0.0),
			Vector3(1.6, head_height, DOORWAY_HALF_WIDTH * 2.0),
			_materials["hulk_bulkhead"]
		)


func _build_interior_fittings() -> void:
	# Reactor gallery: the dead drum the activity is about, on its plinth.
	_box(
		_fitting_root,
		"ReactorPlinth",
		Vector3(-26.0, DECK_Y + 0.6, REACTOR_LOCAL_Z),
		Vector3(10.0, 1.2, 8.0),
		_materials["hulk_deck"]
	)
	_cylinder(
		_fitting_root,
		"ReactorDrum",
		Vector3(-26.0, DECK_Y + 4.2, REACTOR_LOCAL_Z),
		3.6,
		4.0,
		6.0,
		_materials["hulk_machinery"]
	)
	# Spine corridor: one toppled crate, so the corridor is something you walk
	# around rather than a clear tube.
	_box(
		_fitting_root,
		"CorridorSpillCrate",
		Vector3(2.0, DECK_Y + 0.8, 4.2),
		Vector3(2.4, 1.6, 2.4),
		_materials["hulk_machinery"]
	)
	# Dock vestibule: a suit locker bank against the aft cap.
	_box(
		_fitting_root,
		"VestibuleLockerBank",
		Vector3(33.0, DECK_Y + 1.6, -6.0),
		Vector3(4.0, 3.2, 2.4),
		_materials["hulk_machinery"]
	)


## Exterior detail is presentation only and adds one node each. It is what makes
## the hulk legible against the extraction platform at approach distance: two
## collar rings, a raked snapped mast, a rib run down the port flank, and the
## charred break at the bow.
func _build_exterior_detail() -> void:
	# Collar bands, built from the same chamfered cylinder stock as everything
	# else rather than from a torus: the cluster's torus family is an audited,
	# shared-recipe allocation and a decorative ring has no business joining it.
	for collar: Dictionary in [
		{"name": "HullCollarFore", "x": -22.0},
		{"name": "HullCollarAft", "x": 18.0},
	]:
		_cylinder(
			_exterior_root,
			String(collar["name"]),
			Vector3(float(collar["x"]), 0.0, 0.0),
			13.6,
			13.6,
			2.4,
			_materials["hulk_trim"],
			false,
			Vector3(0.0, 0.0, 90.0)
		)
	_cylinder(
		_exterior_root,
		"SnappedMast",
		Vector3(-28.0, 11.0, 0.0),
		0.9,
		1.4,
		14.0,
		_materials["hulk_hull"],
		false,
		Vector3(0.0, 0.0, 34.0)
	)
	_cylinder(
		_exterior_root,
		"SnappedMastStub",
		Vector3(-36.0, 16.0, 3.0),
		0.7,
		0.9,
		5.0,
		_materials["hulk_char"],
		false,
		Vector3(18.0, 0.0, 62.0)
	)
	var trim := Node3D.new()
	trim.name = "HullRibTrim"
	_exterior_root.add_child(trim)
	for index in 6:
		_box(
			trim,
			"HullRib",
			Vector3(-32.0 + float(index) * 13.0, 0.0, -HULL_DEPTH * 0.5 - 0.5),
			Vector3(1.4, HULL_HEIGHT + 1.6, 1.0),
			_materials["hulk_trim"],
			false
		)
	for scorch: Vector3 in [
		Vector3(-33.0, 3.2, HULL_DEPTH * 0.5 - 0.7),
		Vector3(-24.0, -3.0, HULL_DEPTH * 0.5 - 0.7),
		Vector3(-14.0, 2.4, -HULL_DEPTH * 0.5 + 0.7),
	]:
		_box(
			_exterior_root,
			"HullScorch",
			scorch,
			Vector3(9.0, 5.0, 0.7),
			_materials["hulk_char"],
			false
		)
	# The dead solar wing stub. It is the one element that breaks the hull's
	# rectangle from every angle, and it is deliberately unlit and unpowered.
	_box(
		_exterior_root,
		"DeadSolarWing",
		Vector3(6.0, 12.0, -13.0),
		Vector3(22.0, 0.6, 9.0),
		_materials["hulk_dead_panel"],
		false,
		Vector3(24.0, 0.0, 9.0)
	)


## The approach silhouette. One presentation-only renderer, no collision and no
## light: everything here is read from the lane, so none of it may change what a
## hull can hit or what the walk-in route looks like from the deck.
func _build_silhouette_detail() -> void:
	var tools: Array[SurfaceTool] = []
	for _role in SILHOUETTE_SURFACE_ROLES:
		var tool := SurfaceTool.new()
		tool.begin(Mesh.PRIMITIVE_TRIANGLES)
		tools.append(tool)
	var pale := tools[0]
	var dark := tools[1]
	var aperture := tools[2]
	var lamp := tools[3]
	var pool := tools[4]
	var half_length := HULL_LENGTH * 0.5
	var half_depth := HULL_DEPTH * 0.5
	var top_y := OVERHEAD_Y + HULL_PLATE

	# Broken bow truss: the station's service boom, torn off at the break. Four
	# longerons of uneven length, square frames where both sides survive, one
	# diagonal per bay, and one longeron snapped and hanging.
	var truss_y := 1.6
	var truss_half := 1.6
	var longeron_lengths: Array[float] = [14.0, 10.0, 12.5, 6.0]
	var corners: Array[Vector2] = [
		Vector2(truss_half, truss_half), Vector2(truss_half, -truss_half),
		Vector2(-truss_half, -truss_half), Vector2(-truss_half, truss_half),
	]
	var root_x := -half_length + 1.0
	for index in corners.size():
		var corner := corners[index]
		var start := Vector3(root_x, truss_y + corner.x, corner.y)
		_emit_beam(pale, start, start + Vector3(-longeron_lengths[index], 0.0, 0.0), 0.45)
	# The short longeron broke and swung down.
	var snapped_root := Vector3(root_x - longeron_lengths[3], truss_y - truss_half, truss_half)
	_emit_beam(pale, snapped_root, snapped_root + Vector3(-3.6, -2.4, 0.8), 0.4)
	var frame_x := root_x - 3.0
	var bay := 0
	while frame_x > root_x - 12.6:
		var reach := root_x - frame_x
		var alive: Array[bool] = []
		for length in longeron_lengths:
			alive.append(length >= reach)
		for index in corners.size():
			var next := (index + 1) % corners.size()
			if alive[index] and alive[next]:
				_emit_beam(
					pale,
					Vector3(frame_x, truss_y + corners[index].x, corners[index].y),
					Vector3(frame_x, truss_y + corners[next].x, corners[next].y),
					0.3
				)
		if alive[0] and alive[1]:
			var z_from := corners[0].y if bay % 2 == 0 else corners[1].y
			var z_to := corners[1].y if bay % 2 == 0 else corners[0].y
			_emit_beam(
				pale,
				Vector3(frame_x + 3.0, truss_y + truss_half, z_from),
				Vector3(frame_x, truss_y + truss_half, z_to),
				0.25
			)
		frame_x -= 3.0
		bay += 1
	# Torn overhead frame and keel stubs peeling away from the break.
	_emit_beam(pale, Vector3(-half_length + 3.0, top_y + 0.4, 7.0), Vector3(-45.0, 9.5, 9.0), 0.6)
	_emit_beam(pale, Vector3(-half_length + 3.0, top_y + 0.4, -6.0), Vector3(-43.0, 7.8, -7.5), 0.5)
	_emit_beam(pale, Vector3(-30.0, -6.5, 5.0), Vector3(-44.0, -9.0, 6.0), 0.55)
	_emit_beam(pale, Vector3(-30.0, -6.5, -5.0), Vector3(-41.0, -8.0, -6.0), 0.5)

	# Antenna stubs on the dorsal face: one standing mast with its yards, one
	# raked, one snapped short, and a dead dish on its pedestal at the aft end.
	_emit_beam(pale, Vector3(6.0, top_y, 4.0), Vector3(6.0, top_y + 9.0, 4.0), 0.35)
	_emit_beam(pale, Vector3(6.0, top_y + 7.6, 1.0), Vector3(6.0, top_y + 7.6, 7.0), 0.25)
	_emit_beam(pale, Vector3(6.0, top_y + 5.2, 2.4), Vector3(6.0, top_y + 5.2, 5.6), 0.2)
	_emit_beam(pale, Vector3(10.0, top_y, -4.0), Vector3(12.5, top_y + 5.5, -5.0), 0.3)
	_emit_beam(pale, Vector3(31.0, top_y, 2.0), Vector3(31.0, top_y + 3.5, 2.0), 0.4)
	_emit_beam(pale, Vector3(31.0, top_y + 3.5, 2.0), Vector3(32.4, top_y + 4.4, 2.8), 0.3)
	_emit_beam(pale, Vector3(34.0, top_y, -5.0), Vector3(34.0, top_y + 1.6, -5.0), 0.6)
	_emit_box(
		pale,
		Transform3D(
			Basis.from_euler(Vector3(deg_to_rad(8.0), 0.0, deg_to_rad(30.0))),
			Vector3(34.0, top_y + 2.0, -5.0)
		),
		Vector3(3.2, 0.25, 3.2)
	)
	# Dorsal girder between the collars, and the aft docking-probe stubs.
	_emit_beam(pale, Vector3(-18.0, top_y + 0.7, -7.0), Vector3(12.0, top_y + 0.7, -7.0), 0.7)
	for post_x: float in [-12.0, 0.0, 9.0]:
		_emit_beam(pale, Vector3(post_x, top_y, -7.0), Vector3(post_x, top_y + 0.7, -7.0), 0.4)
	_emit_beam(pale, Vector3(half_length + 1.5, 3.0, 4.0), Vector3(47.0, 3.5, 4.0), 0.5)
	_emit_beam(pale, Vector3(half_length + 1.5, -3.0, -4.0), Vector3(45.0, -3.2, -4.5), 0.45)

	# Hull-plate breakup: plates stand proud of the flanks and the dorsal face in
	# two tones, and some cells are missing so the base hull shows between them.
	# Exclusions keep the walk-in aperture, its surround and the scorch marks
	# clear; the collar bands are skipped on every face.
	var exclusions_starboard: Array[Rect2] = [
		Rect2(APERTURE_MIN_X - 2.5, -6.0, APERTURE_WIDTH + 5.0, 12.0),
		Rect2(-37.5, 0.7, 9.0, 5.0),
		Rect2(-28.5, -5.5, 9.0, 5.0),
	]
	var exclusions_port: Array[Rect2] = [
		Rect2(-18.5, -0.1, 9.0, 5.0),
		Rect2(-33.0, -3.5, 6.0, 5.0),
	]
	var collar_bands: Array[Vector2] = [Vector2(-23.6, -20.4), Vector2(16.4, 19.6)]
	var random := RandomNumberGenerator.new()
	random.seed = 4470012
	var cell_width := 6.4
	var cell_x := -half_length + 0.6
	while cell_x + cell_width <= half_length - 0.4:
		for row in 2:
			var y0 := -5.2 + float(row) * 5.4
			for face in 3:
				if random.randf() < 0.3:
					continue
				var tone := dark if random.randf() < 0.45 else pale
				var trim_x := absf(random.randf_range(-0.6, 0.6))
				var plate := Rect2(cell_x + 0.3, y0 + 0.2, cell_width - 0.6 - trim_x, 4.4)
				if _rect_hits_bands(plate, collar_bands):
					continue
				var center := plate.get_center()
				match face:
					0:
						if _rect_hits_any(plate, exclusions_starboard):
							continue
						_emit_box(tone, Transform3D(Basis.IDENTITY,
							Vector3(center.x, center.y, half_depth + 0.14)),
							Vector3(plate.size.x, plate.size.y, 0.28))
					1:
						if _rect_hits_any(plate, exclusions_port):
							continue
						_emit_box(tone, Transform3D(Basis.IDENTITY,
							Vector3(center.x, center.y, -half_depth - 0.14)),
							Vector3(plate.size.x, plate.size.y, 0.28))
					2:
						# The dorsal face uses the row as a lateral band instead.
						_emit_box(tone, Transform3D(Basis.IDENTITY,
							Vector3(center.x, top_y + 0.14, -5.4 + float(row) * 10.8)),
							Vector3(plate.size.x, 0.28, 9.4))
		cell_x += cell_width

	# Dark apertures: a port row on both flanks and three breaches. Unlit black
	# reads as open hull against sunlit plate at any range.
	var window_x := -34.0
	while window_x <= 36.0:
		var window := Rect2(window_x - 0.5, 2.15, 1.0, 0.9)
		if not _rect_hits_bands(window, collar_bands):
			if not _rect_hits_any(window, exclusions_starboard):
				_emit_box(aperture, Transform3D(Basis.IDENTITY,
					Vector3(window_x, 2.6, half_depth + 0.18)), Vector3(1.0, 0.9, 0.36))
			if not _rect_hits_any(window, exclusions_port):
				_emit_box(aperture, Transform3D(Basis.IDENTITY,
					Vector3(window_x, 2.6, -half_depth - 0.18)), Vector3(1.0, 0.9, 0.36))
		window_x += 3.5
	_emit_box(aperture, Transform3D(Basis.IDENTITY,
		Vector3(-33.0, top_y + 0.2, -3.0)), Vector3(7.0, 0.4, 6.0))
	_emit_box(aperture, Transform3D(Basis.IDENTITY,
		Vector3(-30.0, -1.0, -half_depth - 0.2)), Vector3(6.0, 5.0, 0.4))
	_emit_box(aperture, Transform3D(Basis.IDENTITY,
		Vector3(8.0, -3.2, half_depth + 0.2)), Vector3(4.0, 2.5, 0.4))

	# Warm dock-shelf lamps: two heads over the walk-in aperture, two at the
	# shelf's outer corners and a lip strip the pilot sees from below the shelf.
	var shelf_top := DOCK_SHELF_CENTER.y + DOCK_SHELF_SIZE.y * 0.5
	var shelf_front_z := DOCK_SHELF_CENTER.z + DOCK_SHELF_SIZE.z * 0.5
	var shelf_min_x := DOCK_SHELF_CENTER.x - DOCK_SHELF_SIZE.x * 0.5
	var shelf_max_x := DOCK_SHELF_CENTER.x + DOCK_SHELF_SIZE.x * 0.5
	for lamp_x: float in [APERTURE_MIN_X - 0.8, APERTURE_MAX_X + 0.8]:
		_emit_box(lamp, Transform3D(Basis.IDENTITY,
			Vector3(lamp_x, 4.6, half_depth + 0.5)), Vector3(1.4, 0.5, 0.8))
	for lamp_x: float in [shelf_min_x + 1.0, shelf_max_x - 1.0]:
		_emit_box(lamp, Transform3D(Basis.IDENTITY,
			Vector3(lamp_x, shelf_top + 0.3, shelf_front_z - 0.6)), Vector3(0.8, 0.6, 0.8))
	_emit_box(lamp, Transform3D(Basis.IDENTITY,
		Vector3(DOCK_SHELF_CENTER.x, DOCK_SHELF_CENTER.y, shelf_front_z + 0.12)),
		Vector3(DOCK_SHELF_SIZE.x - 6.0, 0.35, 0.24))

	# The light pool itself: an additive radial pool on the shelf deck and a wash
	# on the flank above it, falling off from the shelf upward.
	var inset := 1.0
	var pool_y := shelf_top + 0.07
	_emit_pool_quad(pool, [
		Vector3(shelf_min_x + inset, pool_y, shelf_front_z - inset),
		Vector3(shelf_max_x - inset, pool_y, shelf_front_z - inset),
		Vector3(shelf_max_x - inset, pool_y, half_depth + inset),
		Vector3(shelf_min_x + inset, pool_y, half_depth + inset),
	], [Vector2(0, 1), Vector2(1, 1), Vector2(1, 0), Vector2(0, 0)], 1.0)
	_emit_pool_quad(pool, [
		Vector3(shelf_min_x + 3.0, shelf_top, half_depth + 0.42),
		Vector3(shelf_max_x - 3.0, shelf_top, half_depth + 0.42),
		Vector3(shelf_max_x - 3.0, OVERHEAD_Y + 1.0, half_depth + 0.42),
		Vector3(shelf_min_x + 3.0, OVERHEAD_Y + 1.0, half_depth + 0.42),
	], [Vector2(0, 0.5), Vector2(1, 0.5), Vector2(1, 0.0), Vector2(0, 0.0)], 0.75)

	var mesh := ArrayMesh.new()
	var materials: Array[Material] = [
		_materials["hulk_trim"],
		_materials["hulk_plate_dark"],
		_materials["hulk_aperture"],
		_materials["hulk_warm_lamp"],
		_materials["hulk_warm_pool"],
	]
	for index in tools.size():
		tools[index].commit(mesh)
		mesh.surface_set_material(index, materials[index])
	var detail := MeshInstance3D.new()
	detail.name = SILHOUETTE_DETAIL_NAME
	detail.mesh = mesh
	detail.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	detail.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
	detail.set_meta(&"presentation_only", true)
	detail.set_meta(&"silhouette_surface_roles", SILHOUETTE_SURFACE_ROLES.duplicate())
	_exterior_root.add_child(detail)


func get_silhouette_detail() -> MeshInstance3D:
	if not is_instance_valid(_exterior_root):
		return null
	return _exterior_root.get_node_or_null(SILHOUETTE_DETAIL_NAME) as MeshInstance3D


func get_silhouette_triangle_count() -> int:
	var detail := get_silhouette_detail()
	if detail == null or detail.mesh == null:
		return 0
	var triangles := 0
	for surface in detail.mesh.get_surface_count():
		var arrays := detail.mesh.surface_get_arrays(surface)
		var indices: Variant = arrays[Mesh.ARRAY_INDEX]
		if indices is PackedInt32Array and not (indices as PackedInt32Array).is_empty():
			triangles += (indices as PackedInt32Array).size() / 3
		else:
			triangles += (arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array).size() / 3
	return triangles


func _rect_hits_any(rect: Rect2, exclusions: Array[Rect2]) -> bool:
	for exclusion in exclusions:
		if rect.intersects(exclusion):
			return true
	return false


func _rect_hits_bands(rect: Rect2, bands: Array[Vector2]) -> bool:
	for band in bands:
		if rect.position.x < band.y and rect.end.x > band.x:
			return true
	return false


## A beam between two points with a square cross-section.
func _emit_beam(tool: SurfaceTool, from: Vector3, to: Vector3, thickness: float) -> void:
	var axis := to - from
	var length := axis.length()
	if length < 0.001:
		return
	var x_axis := axis / length
	var hint := Vector3.UP if absf(x_axis.dot(Vector3.UP)) < 0.95 else Vector3.FORWARD
	var z_axis := x_axis.cross(hint).normalized()
	var y_axis := z_axis.cross(x_axis).normalized()
	_emit_box(
		tool,
		Transform3D(Basis(x_axis, y_axis, z_axis), (from + to) * 0.5),
		Vector3(length, thickness, thickness)
	)


## Twelve sharp triangles, clockwise-front like every Godot surface, with the
## normals and positions carried through the supplied rigid transform.
func _emit_box(tool: SurfaceTool, xform: Transform3D, size: Vector3) -> void:
	var half := size * 0.5
	for axis in 3:
		for sign_value: float in [1.0, -1.0]:
			var normal := Vector3.ZERO
			normal[axis] = sign_value
			var u_axis := (axis + 1) % 3
			var v_axis := (axis + 2) % 3
			var u := Vector3.ZERO
			u[u_axis] = 1.0
			var v := normal.cross(u)
			var center := normal * half[axis]
			var u_half := u * half[u_axis]
			var v_half := v * half[v_axis]
			var quad: Array[Vector3] = [
				center - u_half - v_half,
				center + u_half - v_half,
				center + u_half + v_half,
				center - u_half + v_half,
			]
			var world_normal := (xform.basis * normal).normalized()
			for corner_index: int in [0, 2, 1, 0, 3, 2]:
				tool.set_normal(world_normal)
				tool.set_uv(Vector2(
					1.0 if corner_index == 1 or corner_index == 2 else 0.0,
					1.0 if corner_index >= 2 else 0.0
				))
				tool.set_color(Color.WHITE)
				tool.add_vertex(xform * quad[corner_index])


## Additive pool quad; the pool shader disables culling so both faces draw and
## the winding does not matter. Vertex alpha scales the pool's strength.
func _emit_pool_quad(
		tool: SurfaceTool,
		corners: Array[Vector3],
		uvs: Array[Vector2],
		strength: float
	) -> void:
	var normal := (corners[1] - corners[0]).cross(corners[3] - corners[0]).normalized()
	for corner_index: int in [0, 2, 1, 0, 3, 2]:
		tool.set_normal(normal)
		tool.set_uv(uvs[corner_index])
		tool.set_color(Color(1.0, 1.0, 1.0, strength))
		tool.add_vertex(corners[corner_index])


## Interior spaces and fittings are only visible through the aperture and the
## bow break; they stop drawing well before the hulk is small in the canopy.
## Collision is untouched: only renderers take a range.
func _apply_visibility_ranges() -> void:
	for holder: Node in [_interior_root, _fitting_root, _breaker]:
		if not is_instance_valid(holder):
			continue
		for candidate in holder.find_children("*", "GeometryInstance3D", true, false):
			_set_visibility_range(
				candidate as GeometryInstance3D,
				INTERIOR_VISIBILITY_END,
				INTERIOR_VISIBILITY_MARGIN
			)
	for candidate in _exterior_root.find_children("*", "GeometryInstance3D", true, false):
		var renderer := candidate as GeometryInstance3D
		var parent := renderer.get_parent()
		if renderer.has_meta(&"small_trim") \
				or (parent != null and parent.name == &"HullRibTrim"):
			_set_visibility_range(
				renderer, SMALL_TRIM_VISIBILITY_END, SMALL_TRIM_VISIBILITY_MARGIN
			)


func _set_visibility_range(renderer: GeometryInstance3D, end: float, margin: float) -> void:
	renderer.visibility_range_begin = 0.0
	renderer.visibility_range_end = end
	renderer.visibility_range_end_margin = margin
	renderer.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF


## Emergency practicals. Shadowless, short-range, distance-faded and dim, in the
## same recipe the station's own modules use for fitting lights, so the hulk
## shades the way the place the pilot just left does. There is no room light.
func _build_practicals() -> void:
	var lights_root := Node3D.new()
	lights_root.name = "Practicals"
	add_child(lights_root)
	for spec: Dictionary in [
		{"name": "GalleryPractical", "position": Vector3(-33.0, 2.4, -5.0), "color": EMERGENCY_RED, "energy": 0.62},
		{"name": "GalleryPractical", "position": Vector3(-26.0, 2.4, 7.0), "color": EMERGENCY_AMBER, "energy": 0.9},
		{"name": "GalleryPractical", "position": Vector3(-16.0, 2.4, 3.0), "color": EMERGENCY_RED, "energy": 0.55},
		{"name": "CorridorPractical", "position": Vector3(-4.0, 2.6, 0.0), "color": EMERGENCY_AMBER, "energy": 0.7},
		{"name": "CorridorPractical", "position": Vector3(8.0, 2.6, 0.0), "color": EMERGENCY_AMBER, "energy": 0.7},
		{"name": "VestibulePractical", "position": Vector3(19.0, 2.6, -4.0), "color": EMERGENCY_AMBER, "energy": 0.8},
		{"name": "VestibulePractical", "position": Vector3(33.0, 2.6, 4.0), "color": EMERGENCY_RED, "energy": 0.5},
		{"name": "DockShelfPractical", "position": Vector3(APERTURE_CENTER_X, DECK_Y + 4.0, 22.0), "color": DOCK_CYAN, "energy": 1.1},
	]:
		var light := OmniLight3D.new()
		light.name = String(spec["name"])
		light.position = spec["position"] as Vector3
		light.light_color = spec["color"] as Color
		light.light_energy = float(spec["energy"]) * PRACTICAL_ENERGY
		light.set_meta("emergency_color", light.light_color)
		light.set_meta("emergency_energy", light.light_energy)
		light.omni_range = PRACTICAL_RANGE
		light.omni_attenuation = EMERGENCY_PRACTICAL_ATTENUATION
		light.shadow_enabled = false
		light.distance_fade_enabled = true
		light.distance_fade_begin = PRACTICAL_FADE_BEGIN
		light.distance_fade_length = PRACTICAL_FADE_LENGTH
		light.set_meta("localized_practical_light", true)
		lights_root.add_child(light)
		_lights.append(light)


## One ordinary ShipBerth. Everything about docking here — reservation, lease
## token, occupancy, landing assist capture, release on departure — is the
## contract `ShipyardWorld` already registers for its own nine berths.
func _build_berth() -> void:
	_berth = ShipBerth.new()
	_berth.name = "HulkDockBerth"
	_berth.position = BERTH_LOCAL_POSITION
	_berth.berth_id = BERTH_ID
	_berth.compatibility_tags = PackedStringArray(BERTH_COMPATIBILITY_TAGS)
	# Local +Z faces the station, and a parked craft faces the way it leaves, so
	# the dock basis turns the hull about to point back down the return route.
	_berth.dock_transform = Transform3D(
		Basis(Vector3.UP, PI),
		Vector3(0.0, BERTH_DOCK_HEIGHT, 0.0)
	)
	_berth.landing_half_extents = BERTH_LANDING_HALF_EXTENTS
	_berth.assist_capture_center = BERTH_ASSIST_CAPTURE_CENTER
	_berth.assist_capture_half_extents = BERTH_ASSIST_CAPTURE_HALF_EXTENTS
	_berth.assist_capture_maximum_speed = BERTH_ASSIST_MAXIMUM_SPEED
	_berth.assist_maximum_tilt_degrees = BERTH_ASSIST_MAXIMUM_TILT_DEGREES
	add_child(_berth)


func _build_breaker() -> void:
	_breaker = HulkPowerBreaker.new()
	_breaker.name = "AuxiliaryPowerBreaker"
	_breaker.position = BREAKER_LOCAL_POSITION
	add_child(_breaker)
	var housing := MeshInstance3D.new()
	housing.name = "Housing"
	housing.mesh = StationSurfaceKit.rounded_box_mesh_cached(
		Vector3(1.1, 2.2, 0.5), _box_cache
	)
	housing.material_override = _materials["hulk_machinery"]
	housing.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_breaker.add_child(housing)
	var lens := MeshInstance3D.new()
	lens.name = "Lens"
	lens.position = Vector3(0.0, 0.55, -0.32)
	lens.mesh = StationSurfaceKit.rounded_box_mesh_cached(
		Vector3(0.6, 0.16, 0.12), _box_cache
	)
	lens.material_override = _materials["hulk_breaker_lens"]
	lens.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_breaker.add_child(lens)
	var shape := CollisionShape3D.new()
	shape.name = "Interaction"
	var box_shape := BoxShape3D.new()
	box_shape.size = BREAKER_INTERACTION_EXTENTS * 2.0
	shape.shape = box_shape
	_breaker.add_child(shape)


# --- Materials and primitives ------------------------------------------------


## The hulk's own finish family. The scalar recipes are the station's registered
## manufactured-panel values; only the colour and the physical finish differ, so
## the derelict is the same construction as the shipyard, just dead and cold.
func _create_local_materials() -> void:
	_materials["hulk_hull"] = _panel_material(
		HULL_STEEL, 0.35, 0.62, 0.1, StationSurfaceKit.PanelFinish.STRUCTURAL_ALLOY
	)
	_materials["hulk_deck"] = _panel_material(
		HULL_PALE.darkened(0.35), 0.25, 0.78, 0.12, StationSurfaceKit.PanelFinish.WALKED_DECK
	)
	_materials["hulk_bulkhead"] = _panel_material(
		HULL_STEEL.lightened(0.08), 0.3, 0.7, 0.1, StationSurfaceKit.PanelFinish.PAINTED_METAL
	)
	_materials["hulk_machinery"] = _panel_material(
		HULL_PALE.darkened(0.5), 0.45, 0.55, 0.1, StationSurfaceKit.PanelFinish.PAINTED_METAL
	)
	_materials["hulk_trim"] = _panel_material(
		HULL_PALE, 0.4, 0.5, 0.1, StationSurfaceKit.PanelFinish.METAL_TRIM
	)
	_materials["hulk_char"] = _flat_material(HULL_CHAR, 0.1, 0.94)
	_materials["hulk_dead_panel"] = _flat_material(Color("101820"), 0.4, 0.72)
	_materials["hulk_dock_glow"] = _flat_material(DOCK_CYAN, 0.0, 0.3, DOCK_CYAN, 1.3)
	# Second plate tone for the silhouette breakup: darker, rougher steel than
	# the hull so replaced and missing plates read against it at range.
	_materials["hulk_plate_dark"] = _panel_material(
		HULL_STEEL.darkened(0.35), 0.3, 0.74, 0.1, StationSurfaceKit.PanelFinish.STRUCTURAL_ALLOY
	)
	var aperture := StandardMaterial3D.new()
	aperture.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	aperture.albedo_color = Color(0.012, 0.014, 0.018)
	_materials["hulk_aperture"] = aperture
	_materials["hulk_warm_lamp"] = _flat_material(
		WARM_POOL_COLOR, 0.0, 0.4, WARM_POOL_COLOR, 2.2
	)
	var pool_shader := Shader.new()
	pool_shader.code = WARM_POOL_SHADER_CODE
	var pool := ShaderMaterial.new()
	pool.shader = pool_shader
	pool.set_shader_parameter(&"pool_color", WARM_POOL_COLOR)
	pool.set_shader_parameter(&"pool_energy", WARM_POOL_ENERGY)
	_materials["hulk_warm_pool"] = pool
	_materials["hulk_breaker_lens"] = _flat_material(
		EMERGENCY_RED, 0.0, 0.3, EMERGENCY_RED, 1.5
	)


func _flat_material(
		color: Color,
		metallic: float = 0.0,
		roughness: float = 0.65,
		emission_color: Color = Color.TRANSPARENT,
		emission_energy: float = 0.0
	) -> StandardMaterial3D:
	var result := StandardMaterial3D.new()
	result.albedo_color = color
	result.metallic = metallic
	result.roughness = roughness
	result.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL
	result.diffuse_mode = BaseMaterial3D.DIFFUSE_BURLEY
	result.specular_mode = BaseMaterial3D.SPECULAR_SCHLICK_GGX
	if emission_energy > 0.0:
		result.emission_enabled = true
		result.emission = emission_color
		result.emission_energy_multiplier = emission_energy
	return result


func _panel_material(
		color: Color,
		metallic: float,
		roughness: float,
		uv_scale: float,
		finish: int
	) -> StandardMaterial3D:
	var result := _flat_material(color, metallic, roughness)
	StationSurfaceKit.apply_panel_triplanar(result, uv_scale, finish)
	return result


func _box(
		parent: Node3D,
		node_name: String,
		box_position: Vector3,
		size: Vector3,
		material: Material,
		collidable: bool = true,
		box_rotation_degrees: Vector3 = Vector3.ZERO
	) -> Node3D:
	var mesh := StationSurfaceKit.rounded_box_mesh_cached(size, _box_cache)
	if collidable:
		var body := StaticBody3D.new()
		body.name = node_name
		body.position = box_position
		body.rotation_degrees = box_rotation_degrees
		body.collision_layer = WORLD_LAYER
		body.collision_mask = 0
		parent.add_child(body)
		var view := MeshInstance3D.new()
		view.name = "Mesh"
		view.mesh = mesh
		view.material_override = material
		view.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		body.add_child(view)
		var shape := CollisionShape3D.new()
		shape.name = "Collision"
		var box_shape := BoxShape3D.new()
		box_shape.size = size
		shape.shape = box_shape
		body.add_child(shape)
		return body
	var instance := MeshInstance3D.new()
	instance.name = node_name
	instance.position = box_position
	instance.rotation_degrees = box_rotation_degrees
	instance.mesh = mesh
	instance.material_override = material
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(instance)
	return instance


func _cylinder(
		parent: Node3D,
		node_name: String,
		cylinder_position: Vector3,
		top_radius: float,
		bottom_radius: float,
		height: float,
		material: Material,
		collidable: bool = true,
		cylinder_rotation_degrees: Vector3 = Vector3.ZERO
	) -> Node3D:
	var mesh := StationSurfaceKit.chamfered_cylinder_mesh_cached(
		top_radius, bottom_radius, height, 24, _cylinder_cache, 4, true, true
	)
	if collidable:
		var body := StaticBody3D.new()
		body.name = node_name
		body.position = cylinder_position
		body.rotation_degrees = cylinder_rotation_degrees
		body.collision_layer = WORLD_LAYER
		body.collision_mask = 0
		parent.add_child(body)
		var view := MeshInstance3D.new()
		view.name = "Mesh"
		view.mesh = mesh
		view.material_override = material
		view.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		body.add_child(view)
		var shape := CollisionShape3D.new()
		shape.name = "Collision"
		var cylinder_shape := CylinderShape3D.new()
		cylinder_shape.radius = maxf(top_radius, bottom_radius)
		cylinder_shape.height = height
		shape.shape = cylinder_shape
		body.add_child(shape)
		return body
	var instance := MeshInstance3D.new()
	instance.name = node_name
	instance.position = cylinder_position
	instance.rotation_degrees = cylinder_rotation_degrees
	instance.mesh = mesh
	instance.material_override = material
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(instance)
	return instance


# --- Audit -------------------------------------------------------------------


func _compose_audit_report() -> Dictionary:
	var counts := count_live_nodes()
	var errors := PackedStringArray()
	var distance := get_station_distance()
	if distance < NearbySectorCluster.MINIMUM_ANCHOR_DISTANCE \
			or distance > NearbySectorCluster.MAXIMUM_ANCHOR_DISTANCE:
		errors.append(
			"hulk anchor %.1f m is outside the published travel envelope" % distance
		)
	if distance + HULL_BOUNDING_RADIUS > NearbySectorCluster.MAXIMUM_CONTENT_DISTANCE:
		errors.append("hulk reaches past the published content envelope")
	if HULK_ANCHOR.distance_to(NearbySectorCluster.PLATFORM_ANCHOR) \
			< NearbySectorCluster.PLATFORM_KEEP_CLEAR_RADIUS + HULL_BOUNDING_RADIUS:
		errors.append("hulk crowds the extraction platform keep-clear sphere")
	if HULK_ANCHOR.distance_to(NearbySectorCluster.MOONLET_ANCHOR) \
			< NearbySectorCluster.MOONLET_RADIUS + HULL_BOUNDING_RADIUS:
		errors.append("hulk crowds the ringed moonlet")
	if not is_instance_valid(_berth) or _berth.get_berth_id() != BERTH_ID:
		errors.append("hulk dock berth missing")
	elif not _berth.get_validation_errors().is_empty():
		errors.append("hulk dock berth is not a valid landing contract")
	if not is_instance_valid(_breaker):
		errors.append("hulk auxiliary breaker missing")
	var silhouette := get_silhouette_detail()
	var silhouette_triangles := get_silhouette_triangle_count()
	if silhouette == null or silhouette.mesh == null \
			or silhouette.mesh.get_surface_count() != SILHOUETTE_SURFACE_ROLES.size():
		errors.append("hulk approach silhouette detail missing")
	elif silhouette_triangles > SILHOUETTE_TRIANGLE_BUDGET:
		errors.append(
			"hulk silhouette detail %d triangles exceeds budget %d"
			% [silhouette_triangles, SILHOUETTE_TRIANGLE_BUDGET]
		)
	for key: String in PERFORMANCE_BUDGET:
		if int(counts.get(key, 0)) > int(PERFORMANCE_BUDGET[key]):
			errors.append(
				"%s count %d exceeds budget %d"
				% [key, int(counts[key]), int(PERFORMANCE_BUDGET[key])]
			)
	return {
		"schema_version": SCHEMA_VERSION,
		"component_id": COMPONENT_ID,
		"content_class": CONTENT_CLASS,
		"evidence_status": EVIDENCE_STATUS,
		"content_note": CONTENT_NOTE,
		"anchor": HULK_ANCHOR,
		"station_distance": distance,
		"berth_id": BERTH_ID,
		"interior_space_ids": SPACE_IDS.duplicate(),
		"interior_space_count": SPACE_IDS.size(),
		"light_budget": LIGHT_BUDGET,
		"silhouette_triangle_count": silhouette_triangles,
		"silhouette_triangle_budget": SILHOUETTE_TRIANGLE_BUDGET,
		"counts": counts,
		"budget": PERFORMANCE_BUDGET.duplicate(true),
		"grants_rewards": false,
		"berth_lease_authority": false,
		"landing_authority": false,
		"gameplay_authority": false,
		"network_authority": false,
		"errors": errors,
		"valid": errors.is_empty(),
	}.duplicate(true)


## The physical control the on-foot pilot uses. It owns its prompt and one
## detached signal; the activity state and the reward live entirely outside it.
class HulkPowerBreaker:
	extends Area3D

	signal breaker_engaged(actor: Node)

	var _engaged := false

	func _ready() -> void:
		monitoring = false
		monitorable = true
		collision_layer = PhysicsLayers.INTERACTABLE_AREA_LAYER
		collision_mask = PhysicsLayers.INTERACTABLE_AREA_MASK

	func get_interaction_id() -> StringName:
		return &"restore_hulk_auxiliary_power"

	func get_interaction_prompt() -> String:
		if _engaged:
			return "[ E ]  AUXILIARY BUS ENGAGED"
		return "[ E ]  ENGAGE AUXILIARY POWER BREAKER"

	func interact(actor: Node = null) -> bool:
		if not is_inside_tree():
			return false
		_engaged = true
		breaker_engaged.emit(actor)
		return true

	func set_engaged(engaged: bool) -> void:
		_engaged = engaged

	func is_engaged() -> bool:
		return _engaged
