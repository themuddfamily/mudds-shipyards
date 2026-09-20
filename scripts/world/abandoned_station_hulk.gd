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
const HULL_BOUNDING_RADIUS := 46.0
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
	"mesh_instances": 39,
	"omni_lights": LIGHT_BUDGET,
	"spot_lights": 0,
	"shadow_casting_lights": 0,
	"audio_nodes": 0,
	"particle_emitters": 0,
	"animation_players": 0,
	"ship_berths": 1,
}

const HULL_STEEL := Color("2f3a44")
const HULL_PALE := Color("55606a")
const HULL_CHAR := Color("14171b")

var _exterior_root: Node3D
var _interior_root: Node3D
var _fitting_root: Node3D
var _berth: ShipBerth
var _breaker: Area3D
var _lights: Array[OmniLight3D] = []
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
	_build_practicals()
	_build_berth()
	_build_breaker()
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
		_box(
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
		light.omni_range = PRACTICAL_RANGE
		light.omni_attenuation = 2.1
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
