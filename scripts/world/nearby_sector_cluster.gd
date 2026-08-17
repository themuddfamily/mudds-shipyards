class_name NearbySectorCluster
extends Node3D

## The one hand-authored destination cluster outside the shipyard envelope.
##
## Flying out of the launch corridor used to give the player the target range and
## then nothing: an empty volume with a decorative backdrop painted 900 m away on
## a shell nobody can reach. This component is the answer to "where do I go", and
## it is deliberately *small*. Four route beacons, one ringed moonlet, one debris
## field, one open dock gate and one derelict extraction platform, every one of
## them placed by hand at a written coordinate. There is no generator here and
## there is no galaxy: the
## roadmap's second Phase 8 item is a constraint on this file, and the way it is
## honoured is that every destination in the cluster is a named constant you can
## read in one screen.
##
## **Distance is a design number, not an accident.** The Torrent cruises at
## 82 m/s and boosts to 118 m/s, and it accelerates at 34 m/s². The platform sits
## 706 m from the station origin, which is about nine seconds outbound at cruise
## and six on boost — long enough that leaving is a decision, short enough that
## coming back is not a chore. The four beacons are spaced 100-130 m apart along
## the way so the trip has a rhythm and the pilot is never between landmarks for
## more than two seconds. Nothing in the cluster reaches past 900 m; the
## presentation-only backdrop star shell still begins at 1450 m, unreachable,
## doing the job it already did.
##
## **This component owns no gameplay authority.** It grants nothing, scores
## nothing, leases nothing and damages nothing. Its structural bodies sit on the
## World collision layer exactly as the station's own geometry does, so the
## existing hull-impact path in `HeroShip` treats a boulder like a bulkhead and no
## second damage route exists. It deliberately adds no range targets either: the
## guided mission counts `ShipyardWorld.get_target_count()`, so a decorative drone
## out here would silently rewrite the objective.
##
## Everything here is `modern_interpretation`. No source authenticates Cinder
## Reach, the platform, the moonlet or the route; the research ledger constrains
## the station and the fleet and says nothing about this sector.

enum DetailQuality {
	LOW,
	MEDIUM,
	HIGH,
}

const SCHEMA_VERSION := 1
const COMPONENT_ID: StringName = &"nearby-sector-cluster"
const EVIDENCE_STATUS: StringName = &"modern_interpretation"
const WORLD_LAYER := PhysicsLayers.WORLD

const CONTENT_NOTE := (
	"Cinder Reach, its extraction platform, the route beacon chain and the ringed "
	+ "moonlet are original modern remake design. No surviving source names, depicts "
	+ "or authenticates any destination outside the shipyard, and nothing here should "
	+ "be read as recovered historical content."
)

## Travel envelope, published so a test can hold the cluster to the bounds this
## file argues for rather than trusting the prose.
const CRUISE_SPEED := 82.0
const BOOST_SPEED := 118.0
const MINIMUM_ANCHOR_DISTANCE := 200.0
const MAXIMUM_ANCHOR_DISTANCE := 760.0
## Outermost reach of anything this component builds, including the debris field
## around the platform. The backdrop star shell starts at 1450 m, so the cluster
## and the painted sky never share a depth.
const MAXIMUM_CONTENT_DISTANCE := 940.0
## Everything must start beyond the target range's last drone (z = -165) so the
## cluster cannot crowd the range or the approach behind it.
const TARGET_RANGE_CLEARANCE_Z := -200.0

## Station-relative placement. The component root is mounted at the shipyard
## origin with an identity transform, so every constant below is also a world
## coordinate and can be read straight off against the station, the launch gate at
## (0, 8, -64) and the target range that ends near z = -165.
const PLATFORM_ANCHOR := Vector3(60.0, -70.0, -700.0)
const MOONLET_ANCHOR := Vector3(-260.0, 40.0, -560.0)
const MOONLET_RADIUS := 90.0

## Four beacons, bowed starboard and down and then back to port so the chain is
## read in perspective rather than as one point, and so the last leg leaves the
## platform's approach lane empty. Each carries an amber outbound lamp and a cyan
## homebound lamp on opposite faces: flying out you see amber, turning for home
## you see cyan. That is the whole return-route cue and it needs no HUD.
const ROUTE_BEACON_SPECS: Array[Dictionary] = [
	{"name": "RouteBeaconAlpha", "position": Vector3(16.0, -9.0, -240.0), "index": 1},
	{"name": "RouteBeaconBravo", "position": Vector3(32.0, -26.0, -372.0), "index": 2},
	{"name": "RouteBeaconCharlie", "position": Vector3(46.0, -44.0, -498.0), "index": 3},
	{"name": "RouteBeaconDelta", "position": Vector3(30.0, -46.0, -600.0), "index": 4},
]

## Debris field: an ellipsoid flattened in Y so it reads as a drift rather than a
## ball, centred on the platform.
const FIELD_RADII := Vector3(180.0, 58.0, 180.0)
const FIELD_SEED := 8140719
const BOULDER_COUNT := 16
const BOULDER_MINIMUM_EXTENT := 20.0
const BOULDER_MAXIMUM_EXTENT := 46.0
const BOULDER_MINIMUM_SEPARATION := 56.0
const DEBRIS_CHIP_COUNT := 520
const DEBRIS_CHIP_SEED := 5512803
## Kept clear so the platform is approachable and the dock gate is not blocked by
## a rock the pilot cannot see until it fills the canopy. It applies to the fine
## debris shell as well as the boulders — the first rendered pass filtered only
## the boulders, and 720 unfiltered chips packed the gate aperture solid and hid
## the platform completely from 170 m out.
const PLATFORM_KEEP_CLEAR_RADIUS := 105.0
const APPROACH_CORRIDOR_RADIUS := 30.0
const APPROACH_CORRIDOR_LENGTH := 200.0
const BEACON_KEEP_CLEAR_RADIUS := 70.0

## Rocks take a much heavier chamfer than station stock. The kit's box rule caps
## at 0.18 m, which on a 30 m boulder is invisible, so the chamfer is proportional
## here instead. 0.13 is where the rendered evidence put it: at 0.30 the inset
## shell rounds so far that a boulder reads as a pale pillow with no facets at
## all, and a field of them looked like spilled packing foam. At 0.13 the block
## keeps its faces and the chamfer is a lit edge between them. Well under the
## builder's own 0.45 safety limit either way, so the shell cannot invert.
const ROCK_BEVEL_PROPORTION := 0.13
const ROCK_LOBES_PER_BOULDER := 3

## Platform envelope, local to `PLATFORM_ANCHOR`. The dock gate is the reason to
## actually arrive: two open frames 18 m apart with a 28 x 23 m clear aperture,
## standing free on the approach lane 77-95 m off the platform and squared to it,
## so the run ends by threading a structure instead of stopping beside one.
##
## It is deliberately *detached* from the platform rather than bolted to the end
## of the processing spine. A tunnel that dead-ends into a hull is not a
## flythrough, it is a wall with a frame around it, and the pilot only finds that
## out at 82 m/s. Standing the gate off on the lane leaves 60 m of clear space on
## the far side to pull up, bank, or run straight past.
const GANTRY_CLEAR_WIDTH := 28.0
const GANTRY_CLEAR_HEIGHT := 23.0
const GANTRY_BEAM := 3.0
const GANTRY_NEAR_Z := 95.0
const GANTRY_FAR_Z := 77.0
const GANTRY_CENTER_Y := 4.0
const SPINE_SIZE := Vector3(9.0, 7.0, 44.0)
const SPINE_CENTER_Z := -6.0
const PROCESSING_SPINE_RIB_SIZE := Vector3(13.0, 9.5, 1.6)
const PROCESSING_SPINE_RIB_Z_POSITIONS: Array[float] = [-24.0, -14.0, 0.0, 12.0]
const PROCESSING_SPINE_RIB_FAMILY_ID: StringName = &"nearby-processing-spine-ribs"

const PERFORMANCE_BUDGET := {
	"static_bodies": 44,
	"mesh_instances": 200,
	# 1 -> 2: the second batch replaces four visual-only processing-spine rib
	# submissions with one while retaining the original debris-shell batch.
	"multimesh_instances": 2,
	"omni_lights": 26,
	"spot_lights": 1,
	"shadow_casting_lights": 0,
	"audio_nodes": 0,
	"particle_emitters": 0,
	"animation_players": 0,
}

const ROCK_BASALT := Color("3c4249")
const ROCK_RUST := Color("55402f")
const ROCK_PALE := Color("5a636a")
const HULL_OCHRE := Color("7d5c34")
const HULL_SHADOW := Color("2a2f36")
const HULL_CHAR := Color("14171b")
const STEEL_BLUE := Color("1c566e")
const KETH_CYAN := Color("48dbe2")
const KETH_ORANGE := Color("ff9f43")
const MOONLET_TEAL := Color("3f8f7a")
const MOONLET_RING := Color("8b7f63")
const MOONLET_CRATER_COUNT := 6

@export_category("Presentation")
@export var starts_enabled := true
@export_enum("Low", "Medium", "High") var initial_quality: int = DetailQuality.HIGH

@onready var _route_root: Node3D = get_node(^"RouteBeacons") as Node3D
@onready var _field_root: Node3D = get_node(^"DebrisField") as Node3D
@onready var _platform_root: Node3D = get_node(^"ExtractionPlatform") as Node3D
@onready var _landmark_root: Node3D = get_node(^"Landmarks") as Node3D

var _materials: Dictionary = {}
var _lens_materials: Dictionary = {}
var _box_cache: Dictionary = {}
var _rock_mesh_cache: Dictionary = {}
var _cylinder_cache: Dictionary = {}
var _spin_bodies: Array[Node3D] = []
var _pulse_lamps: Array[OmniLight3D] = []
var _boulder_offsets: Array[Vector3] = []
var _hazard_head: Node3D
var _moonlet: Node3D
var _built := false
var _cluster_enabled := true
var _quality_level: int = DetailQuality.HIGH
var _elapsed := 0.0
var _audit_report: Dictionary = {}
var _streaming_transition: CinderStreamingTransitionPresentation


func _enter_tree() -> void:
	# A whole-`Main` detach and re-add must restore the animation lifecycle. The
	# geometry survives the round trip untouched; only processing has to come
	# back, and it comes back through the same setter the inspector uses so there
	# is one path rather than two.
	if _built:
		call_deferred("set_cluster_enabled", _cluster_enabled)


func _ready() -> void:
	if _built:
		set_cluster_enabled(_cluster_enabled)
		return
	_built = true
	_quality_level = clampi(initial_quality, DetailQuality.LOW, DetailQuality.HIGH)
	_create_materials()
	_build_route_beacons()
	_build_landmarks()
	_build_debris_field()
	_build_extraction_platform()
	_audit_report = _compose_audit_report()
	set_cluster_enabled(starts_enabled)
	_arm_streaming_transition()


func _process(delta: float) -> void:
	# Accumulated frame delta only. Nothing here reads a wall clock, so two runs
	# stepped with the same deltas produce the same transforms.
	_elapsed += delta
	for body in _spin_bodies:
		if not is_instance_valid(body):
			continue
		var axis := body.get_meta(&"spin_axis", Vector3.UP) as Vector3
		var rate := float(body.get_meta(&"spin_rate", 0.0))
		var rest := body.get_meta(&"rest_basis", Basis.IDENTITY) as Basis
		body.basis = Basis(axis, deg_to_rad(rate) * _elapsed) * rest
	for lamp in _pulse_lamps:
		if not is_instance_valid(lamp):
			continue
		var phase := float(lamp.get_meta(&"pulse_phase", 0.0))
		var base := float(lamp.get_meta(&"base_energy", 1.0))
		var raw_energy := base * (
			0.62 + 0.38 * (0.5 + 0.5 * sin(_elapsed * 1.9 + phase))
		)
		lamp.light_energy = (
			_streaming_transition.scale_dynamic_light_energy(raw_energy)
			if _streaming_transition != null
			else raw_energy
		)
	if is_instance_valid(_hazard_head):
		_hazard_head.rotation.y = _elapsed * 0.9
	if is_instance_valid(_moonlet):
		_moonlet.rotation.y = _elapsed * 0.012


## Suspends every animated element and hides the cluster without destroying it,
## so a paused or low-profile world pays nothing per frame and the exact same
## geometry comes back on re-enable.
func set_cluster_enabled(enabled: bool) -> void:
	_cluster_enabled = enabled
	var presentation_opacity := float(
		get_streaming_transition_snapshot().get("opacity", 1.0)
	)
	visible = enabled and presentation_opacity > 0.0
	set_process(enabled and _built)
	set_physics_process(false)


func is_cluster_enabled() -> bool:
	return _cluster_enabled


## Drops the fine debris shell on the lowest profile. The structures, the
## boulders and every collision shape are identical at all three settings: the
## flyable shape of the sector must not depend on a graphics option.
func set_detail_quality(quality: int) -> void:
	_quality_level = clampi(quality, DetailQuality.LOW, DetailQuality.HIGH)
	if _field_root == null:
		return
	var chips := _field_root.get_node_or_null(^"DebrisChips") as MultiMeshInstance3D
	if chips != null:
		chips.visible = _quality_level >= DetailQuality.MEDIUM


func get_detail_quality() -> int:
	return _quality_level


## Production streaming facade. Direct component fixtures have no coordinator
## metadata, remain fully authored, and reject advancement.
func advance_streaming_transition(
	delta: Variant, distance_meters: Variant, expected_generation: Variant
	) -> Dictionary:
	if _streaming_transition == null:
		return {
			"accepted": false,
			"reason": &"not_streamed",
			"generation": -1,
			"opacity": 1.0,
			"phase": &"standalone",
			"retire_ready": false,
		}
	return _streaming_transition.advance_physics(
		delta, distance_meters, expected_generation
	)


func get_streaming_transition_snapshot() -> Dictionary:
	if _streaming_transition == null:
		return {
			"schema_version": CinderStreamingTransitionPresentation.SCHEMA_VERSION,
			"bound": false,
			"generation": -1,
			"opacity": 1.0,
			"phase": &"standalone",
			"retire_ready": false,
			"root_visible": visible,
		}.duplicate(true)
	return _streaming_transition.get_snapshot()


func get_streaming_transition_audit() -> Dictionary:
	if _streaming_transition == null:
		return {
			"valid": true,
			"standalone": true,
			"automatic_processing": false,
			"streaming_authority": false,
			"gameplay_authority": false,
		}.duplicate(true)
	return _streaming_transition.audit()


func _arm_streaming_transition() -> void:
	var location_id := get_meta(&"world_location_id", &"") as StringName
	var generation := int(get_meta(&"world_location_generation", -1))
	if location_id != CinderStreamingTransitionPresentation.LOCATION_ID \
		or generation <= 0:
		return
	_streaming_transition = CinderStreamingTransitionPresentation.new()
	var bound := _streaming_transition.bind_streamed_content(self, generation)
	if not bool(bound.get("accepted", false)):
		# A streamed generation whose renderer roster cannot be safely controlled
		# fails visually closed. Collision and coordinator ownership remain intact.
		visible = false


## Straight-line distance from the station origin to the platform, in metres.
func get_platform_distance() -> float:
	return PLATFORM_ANCHOR.length()


## Seconds at the Torrent's steady cruise speed, ignoring spin-up. Reported so
## the travel envelope is a measured number in the audit, not a comment.
func get_cruise_travel_seconds() -> float:
	return get_platform_distance() / CRUISE_SPEED


## World-space point on the platform's approach lane, `distance` metres out from
## the platform along +Z. The boulder scatter is forbidden anywhere inside this
## lane, so any point this returns within `APPROACH_CORRIDOR_LENGTH` is flyable.
func get_approach_lane_point(distance: float) -> Vector3:
	return PLATFORM_ANCHOR + Vector3(0.0, GANTRY_CENTER_Y, distance)


## Centre of the dock gate's outer aperture — the point the pilot lines up on.
func get_dock_gate_center() -> Vector3:
	return get_approach_lane_point(GANTRY_NEAR_Z)


func get_route_beacon_positions() -> Array[Vector3]:
	var positions: Array[Vector3] = []
	for spec in ROUTE_BEACON_SPECS:
		positions.append(spec["position"] as Vector3)
	return positions


## Station-relative offsets of the boulders this instance actually placed.
## Returned as a copy; the field is deterministic, so two builds from the same
## seed produce the same list.
func get_boulder_offsets() -> Array[Vector3]:
	return _boulder_offsets.duplicate()


## Deep copy, so a caller inspecting the cluster cannot edit the component's own
## record of what it built.
func get_cluster_audit_report() -> Dictionary:
	return _audit_report.duplicate(true)


func _compose_audit_report() -> Dictionary:
	var beacon_distances: Array[float] = []
	for spec in ROUTE_BEACON_SPECS:
		beacon_distances.append((spec["position"] as Vector3).length())
	var counts := _count_live_nodes()
	var errors: Array[String] = []
	var platform_distance := get_platform_distance()
	if platform_distance > MAXIMUM_ANCHOR_DISTANCE or platform_distance < MINIMUM_ANCHOR_DISTANCE:
		errors.append(
			"platform anchor %.1f m is outside the published travel envelope" % platform_distance
		)
	for spec in ROUTE_BEACON_SPECS:
		var beacon_position := spec["position"] as Vector3
		if beacon_position.z > TARGET_RANGE_CLEARANCE_Z:
			errors.append("beacon %s crowds the target range" % spec["name"])
	if MOONLET_ANCHOR.length() + MOONLET_RADIUS > MAXIMUM_CONTENT_DISTANCE:
		errors.append("moonlet landmark reaches past the published content envelope")
	var field_outer := _get_field_outer_distance()
	if field_outer > MAXIMUM_CONTENT_DISTANCE:
		errors.append("debris field reaches %.1f m, past the published content envelope" % field_outer)
	if _boulder_offsets.size() != BOULDER_COUNT:
		errors.append(
			"placed %d boulders, expected %d" % [_boulder_offsets.size(), BOULDER_COUNT]
		)
	for offset in _boulder_offsets:
		if offset.length() < PLATFORM_KEEP_CLEAR_RADIUS:
			errors.append("a boulder landed inside the platform keep-clear sphere")
			break
	for key: String in PERFORMANCE_BUDGET:
		if int(counts.get(key, 0)) > int(PERFORMANCE_BUDGET[key]):
			errors.append(
				"%s count %d exceeds budget %d" % [key, int(counts[key]), int(PERFORMANCE_BUDGET[key])]
			)
	return {
		"schema_version": SCHEMA_VERSION,
		"component_id": COMPONENT_ID,
		"evidence_status": EVIDENCE_STATUS,
		"content_note": CONTENT_NOTE,
		"gameplay_authority": false,
		"grants_rewards": false,
		"range_targets_added": 0,
		"platform_anchor": PLATFORM_ANCHOR,
		"platform_distance": platform_distance,
		"cruise_travel_seconds": get_cruise_travel_seconds(),
		"boost_travel_seconds": platform_distance / BOOST_SPEED,
		"moonlet_anchor": MOONLET_ANCHOR,
		"moonlet_distance": MOONLET_ANCHOR.length(),
		"field_outer_distance": field_outer,
		"content_envelope": MAXIMUM_CONTENT_DISTANCE,
		"beacon_count": ROUTE_BEACON_SPECS.size(),
		"beacon_distances": beacon_distances,
		"boulder_count": _boulder_offsets.size(),
		"debris_chip_count": DEBRIS_CHIP_COUNT,
		"field_seed": FIELD_SEED,
		"debris_chip_seed": DEBRIS_CHIP_SEED,
		"gantry_clear_width": GANTRY_CLEAR_WIDTH,
		"gantry_clear_height": GANTRY_CLEAR_HEIGHT,
		"counts": counts,
		"budget": PERFORMANCE_BUDGET.duplicate(true),
		"errors": errors,
		"valid": errors.is_empty(),
	}


## Furthest any placed boulder actually reaches from the station origin, lobes
## included. Measured from the built field rather than assumed from the radii.
func _get_field_outer_distance() -> float:
	var furthest := PLATFORM_ANCHOR.length()
	for offset in _boulder_offsets:
		furthest = maxf(furthest, (PLATFORM_ANCHOR + offset).length() + BOULDER_MAXIMUM_EXTENT)
	return furthest


func _count_live_nodes() -> Dictionary:
	var shadow_casting := 0
	for candidate in find_children("*", "Light3D", true, false):
		if (candidate as Light3D).shadow_enabled:
			shadow_casting += 1
	return {
		"static_bodies": find_children("*", "StaticBody3D", true, false).size(),
		"mesh_instances": find_children("*", "MeshInstance3D", true, false).size(),
		"multimesh_instances": find_children("*", "MultiMeshInstance3D", true, false).size(),
		"omni_lights": find_children("*", "OmniLight3D", true, false).size(),
		"spot_lights": find_children("*", "SpotLight3D", true, false).size(),
		"shadow_casting_lights": shadow_casting,
		"audio_nodes": find_children("*", "AudioStreamPlayer3D", true, false).size(),
		"particle_emitters": find_children("*", "GPUParticles3D", true, false).size(),
		"animation_players": find_children("*", "AnimationPlayer", true, false).size(),
		"collision_shapes": find_children("*", "CollisionShape3D", true, false).size(),
	}


# --- Route -------------------------------------------------------------------


func _build_route_beacons() -> void:
	# The chain starts at the launch gate, so beacon one is oriented to the exact
	# heading the pilot leaves the corridor on.
	var previous := Vector3(0.0, 8.0, -64.0)
	for spec in ROUTE_BEACON_SPECS:
		var beacon_position := spec["position"] as Vector3
		var index := int(spec["index"])
		var beacon := Node3D.new()
		beacon.name = String(spec["name"])
		beacon.position = beacon_position
		# Local +Z points back down the leg the pilot just flew. Built from the
		# leg vector rather than `look_at`, which needs a global transform and a
		# node already in the tree; this is exact whatever the world is parented to.
		beacon.basis = _basis_facing(previous - beacon_position)
		beacon.set_meta(&"presentation_only", true)
		_route_root.add_child(beacon)
		previous = beacon_position

		# Presentation only, and deliberately so: a 1.2 m mast standing in the
		# middle of the corridor the pilot is being told to follow would be a
		# cheap collision at 82 m/s. The beacons guide; the boulders and the
		# platform are the things that are solid.
		_cylinder(beacon, "Mast", Vector3.ZERO, 1.2, 1.2, 30.0, _materials["steel"], false)
		_torus(beacon, "SignalRing", Vector3(0.0, 12.0, 0.0), 5.0, 5.6, _materials["cyan_glow"], Vector3(90.0, 0.0, 0.0))
		_torus(beacon, "TrimRing", Vector3(0.0, 12.0, 0.0), 6.4, 6.7, _materials["orange"], Vector3(90.0, 0.0, 0.0))
		_box(beacon, "CounterVane", Vector3(0.0, -11.0, 0.0), Vector3(9.0, 5.0, 0.5), _materials["hull"], false)
		_box(beacon, "VaneSpar", Vector3(0.0, -11.0, 0.0), Vector3(0.5, 5.6, 3.2), _materials["steel"], false)

		# Homebound face (+Z, toward the station) cyan; outbound face amber.
		_lamp(beacon, "HomeLamp", Vector3(0.0, 12.0, 3.4), KETH_CYAN, 3.4, 26.0, true)
		_lamp(beacon, "OutboundLamp", Vector3(0.0, 12.0, -3.4), KETH_ORANGE, 3.0, 24.0, true)
		_lamp(beacon, "MastFootLamp", Vector3(0.0, -15.2, 0.0), KETH_CYAN, 1.6, 14.0, false)

		# `TextMesh` glyphs are thin and the two faces sit either side of the same
		# mast, so without something opaque between them the far sign reads
		# straight through the near one and both legends arrive scrambled. The
		# board is that something, and it also gives each legend a surface to sit
		# on instead of floating in vacuum.
		# The board has to be wider than the longest legend on it, not merely
		# present: at 2.6 scale a 26-character line spans about 20 m, so on the
		# first 15 m board both legends hung over the edges and the reversed far
		# face read straight through beside the near one. Two shorter lines at 2.2
		# span about 14 m inside a 20 m board.
		_box(beacon, "SignBoard", Vector3(0.0, 5.4, 0.0), Vector3(20.0, 3.4, 0.4), _materials["hull_shadow"], false)
		_sign(
			beacon,
			"CINDER REACH  %d m" % int(round((PLATFORM_ANCHOR - beacon_position).length())),
			Vector3(0.0, 5.4, -0.32),
			Vector3(0.0, 180.0, 0.0),
			2.2,
			_materials["orange_glow"]
		)
		_sign(
			beacon,
			"SHIPYARDS  MARKER %d" % index,
			Vector3(0.0, 5.4, 0.32),
			Vector3.ZERO,
			2.2,
			_materials["cyan_glow"]
		)


## Orthonormal basis whose local +Z points along `forward`.
func _basis_facing(forward: Vector3) -> Basis:
	if forward.length_squared() < 0.000001:
		return Basis.IDENTITY
	var z_axis := forward.normalized()
	var up_hint := Vector3.UP if absf(z_axis.dot(Vector3.UP)) < 0.98 else Vector3.RIGHT
	var x_axis := up_hint.cross(z_axis).normalized()
	var y_axis := z_axis.cross(x_axis).normalized()
	return Basis(x_axis, y_axis, z_axis)


# --- Landmarks ---------------------------------------------------------------


func _build_landmarks() -> void:
	# The one large colour body inside the flyable envelope. The backdrop's four
	# bodies are on a 900-1250 m shell and can never be reached; this one can be
	# circled in well under a minute, which is what makes it a landmark and not a
	# painting. It is solid for the same reason: a body you fly through is a
	# poster.
	var moonlet := StaticBody3D.new()
	moonlet.name = "ReachMoonlet"
	moonlet.position = MOONLET_ANCHOR
	moonlet.collision_layer = WORLD_LAYER
	moonlet.collision_mask = 0
	_landmark_root.add_child(moonlet)
	var moonlet_mesh := SphereMesh.new()
	moonlet_mesh.radius = MOONLET_RADIUS
	moonlet_mesh.height = MOONLET_RADIUS * 2.0
	moonlet_mesh.radial_segments = 48
	moonlet_mesh.rings = 24
	var moonlet_view := MeshInstance3D.new()
	moonlet_view.name = "Mesh"
	moonlet_view.mesh = moonlet_mesh
	moonlet_view.material_override = _materials["moonlet"]
	moonlet_view.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	moonlet.add_child(moonlet_view)
	var moonlet_shape := CollisionShape3D.new()
	moonlet_shape.name = "Collision"
	var moonlet_sphere := SphereShape3D.new()
	moonlet_sphere.radius = MOONLET_RADIUS
	moonlet_shape.shape = moonlet_sphere
	moonlet.add_child(moonlet_shape)

	# Two dust bands rather than one, tilted off the body axis so the moonlet has
	# an orientation to read against while the ship moves.
	var ring_holder := Node3D.new()
	ring_holder.name = "MoonletRings"
	ring_holder.position = MOONLET_ANCHOR
	ring_holder.rotation_degrees = Vector3(18.0, 0.0, -11.0)
	_landmark_root.add_child(ring_holder)
	_torus(ring_holder, "InnerRing", Vector3.ZERO, 116.0, 132.0, _materials["ring"], Vector3.ZERO)
	_torus(ring_holder, "OuterRing", Vector3.ZERO, 140.0, 148.0, _materials["ring_pale"], Vector3.ZERO)

	# Crater rims. A 90 m sphere with one albedo has no scale cue at all: it could
	# be a marble ten metres away or a moon a kilometre off, and the pilot has no
	# way to tell which until they hit it. Six rims of known size fix that, and
	# they are deterministic rather than scattered.
	var crater_random := RandomNumberGenerator.new()
	crater_random.seed = FIELD_SEED + 4111
	for crater_index in MOONLET_CRATER_COUNT:
		var latitude := crater_random.randf_range(-0.75, 0.75)
		var longitude := crater_random.randf_range(-PI, PI)
		var planar := sqrt(maxf(0.0, 1.0 - latitude * latitude))
		var normal := Vector3(planar * cos(longitude), latitude, planar * sin(longitude))
		var rim_radius := crater_random.randf_range(9.0, 21.0)
		var rim := _torus(
			moonlet,
			"CraterRim%d" % (crater_index + 1),
			normal * (MOONLET_RADIUS - rim_radius * 0.22),
			rim_radius,
			rim_radius * 1.28,
			_materials["moonlet_crater"],
			Vector3.ZERO
		)
		# A torus lies in its own XZ plane, so aligning local +Y with the surface
		# normal lays the rim flat on the body instead of standing it on edge.
		rim.basis = _basis_facing(normal) * Basis(Vector3.RIGHT, PI * 0.5)
	_moonlet = moonlet


# --- Debris field ------------------------------------------------------------


func _build_debris_field() -> void:
	var random := RandomNumberGenerator.new()
	random.seed = FIELD_SEED
	var rock_materials: Array = [
		_materials["rock_basalt"],
		_materials["rock_rust"],
		_materials["rock_pale"],
	]
	var attempts := 0
	while _boulder_offsets.size() < BOULDER_COUNT and attempts < BOULDER_COUNT * 80:
		attempts += 1
		var offset := _sample_field_offset(random)
		if not _is_placeable_boulder_offset(offset):
			continue
		var extent := random.randf_range(BOULDER_MINIMUM_EXTENT, BOULDER_MAXIMUM_EXTENT)
		_boulder_offsets.append(offset)
		_build_rock_chunk(
			_field_root,
			"Boulder%02d" % _boulder_offsets.size(),
			PLATFORM_ANCHOR + offset,
			extent,
			random,
			rock_materials[_boulder_offsets.size() % rock_materials.size()] as Material,
			true,
			true
		)
	if _boulder_offsets.size() < BOULDER_COUNT:
		push_error(
			"NearbySectorCluster placed only %d of %d boulders before exhausting attempts"
			% [_boulder_offsets.size(), BOULDER_COUNT]
		)

	_build_debris_chips()


## Fine debris as one instanced shell. 720 chips with no nodes, no processing, no
## collision and no lights: the field needs density to read as a drift, and 720
## `MeshInstance3D` children would have been an unaffordable way to get it.
func _build_debris_chips() -> void:
	var chip_material := _material(ROCK_BASALT, 0.04, 0.95)
	chip_material.vertex_color_use_as_albedo = true
	var chip_mesh := StationSurfaceKit.rounded_box_mesh_with_bevel(
		Vector3(1.0, 0.72, 1.34), 0.72 * ROCK_BEVEL_PROPORTION
	)
	chip_mesh.surface_set_material(0, chip_material)

	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.use_colors = true
	multimesh.mesh = chip_mesh
	multimesh.instance_count = DEBRIS_CHIP_COUNT
	var random := RandomNumberGenerator.new()
	random.seed = DEBRIS_CHIP_SEED
	var placed_chips := 0
	var chip_attempts := 0
	while placed_chips < DEBRIS_CHIP_COUNT and chip_attempts < DEBRIS_CHIP_COUNT * 20:
		chip_attempts += 1
		var offset := _sample_field_offset(random)
		if not _is_clear_of_platform_and_lane(offset):
			continue
		var index := placed_chips
		placed_chips += 1
		var scale_value := random.randf_range(0.7, 2.4)
		var chip_basis := Basis.from_euler(
			Vector3(
				random.randf_range(-PI, PI),
				random.randf_range(-PI, PI),
				random.randf_range(-PI, PI)
			)
		).scaled(
			Vector3(
				scale_value,
				scale_value * random.randf_range(0.55, 1.0),
				scale_value * random.randf_range(0.7, 1.25)
			)
		)
		multimesh.set_instance_transform(index, Transform3D(chip_basis, PLATFORM_ANCHOR + offset))
		multimesh.set_instance_color(
			index,
			ROCK_BASALT.lerp(ROCK_RUST if index % 3 == 0 else ROCK_PALE, random.randf_range(0.1, 0.85))
		)
	multimesh.visible_instance_count = placed_chips

	var chips := MultiMeshInstance3D.new()
	chips.name = "DebrisChips"
	chips.multimesh = multimesh
	chips.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	chips.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
	chips.custom_aabb = AABB(PLATFORM_ANCHOR - FIELD_RADII, FIELD_RADII * 2.0)
	chips.visible = _quality_level >= DetailQuality.MEDIUM
	_field_root.add_child(chips)


## Uniform-by-volume sample of the flattened field ellipsoid.
func _sample_field_offset(random: RandomNumberGenerator) -> Vector3:
	var y := random.randf_range(-1.0, 1.0)
	var longitude := random.randf_range(-PI, PI)
	var planar := sqrt(maxf(0.0, 1.0 - y * y))
	var direction := Vector3(planar * cos(longitude), y, planar * sin(longitude))
	var radial := pow(random.randf(), 1.0 / 3.0)
	return direction * radial * FIELD_RADII


## Whether this platform-relative offset is outside both the keep-clear sphere
## around the structure and the lane the pilot flies down to reach it. Shared by
## the boulders and the fine debris shell, because a chip in the gate aperture
## blocks the view exactly as effectively as a rock does.
func _is_clear_of_platform_and_lane(offset: Vector3) -> bool:
	if offset.length() < PLATFORM_KEEP_CLEAR_RADIUS:
		return false
	if offset.z > 0.0 and offset.z < APPROACH_CORRIDOR_LENGTH:
		if Vector2(offset.x, offset.y - GANTRY_CENTER_Y).length() < APPROACH_CORRIDOR_RADIUS:
			return false
	return true


## A boulder may stand here only if it clears the platform, the lane the pilot
## flies down to reach it, every route beacon, and the boulders already placed.
func _is_placeable_boulder_offset(offset: Vector3) -> bool:
	if not _is_clear_of_platform_and_lane(offset):
		return false
	var world_position := PLATFORM_ANCHOR + offset
	for spec in ROUTE_BEACON_SPECS:
		if world_position.distance_to(spec["position"] as Vector3) < BEACON_KEEP_CLEAR_RADIUS:
			return false
	for placed in _boulder_offsets:
		if offset.distance_to(placed) < BOULDER_MINIMUM_SEPARATION:
			return false
	return true


## One asteroid: three overlapping heavily chamfered boxes under a single sphere
## collider. The visual lobes reach further than the collider on purpose — the
## forgiving side of a hazard the pilot meets at cruise speed.
func _build_rock_chunk(
		parent: Node3D,
		node_name: String,
		chunk_position: Vector3,
		mean_extent: float,
		random: RandomNumberGenerator,
		material: Material,
		collidable: bool,
		tumbling: bool
	) -> Node3D:
	var container: Node3D
	if collidable:
		var body := StaticBody3D.new()
		body.collision_layer = WORLD_LAYER
		body.collision_mask = 0
		container = body
	else:
		container = Node3D.new()
	container.name = node_name
	container.position = chunk_position
	parent.add_child(container)

	var lobes := Node3D.new()
	lobes.name = "Lobes"
	container.add_child(lobes)
	for lobe_index in ROCK_LOBES_PER_BOULDER:
		var size := Vector3(
			snappedf(mean_extent * random.randf_range(0.62, 1.12), 0.05),
			snappedf(mean_extent * random.randf_range(0.50, 0.95), 0.05),
			snappedf(mean_extent * random.randf_range(0.62, 1.12), 0.05)
		)
		var lobe := MeshInstance3D.new()
		lobe.name = "Lobe%d" % (lobe_index + 1)
		lobe.mesh = _rock_mesh(size)
		lobe.material_override = material
		lobe.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		lobe.position = Vector3(
			random.randf_range(-0.22, 0.22),
			random.randf_range(-0.18, 0.18),
			random.randf_range(-0.22, 0.22)
		) * mean_extent
		lobe.rotation = Vector3(
			random.randf_range(-PI, PI),
			random.randf_range(-PI, PI),
			random.randf_range(-PI, PI)
		)
		lobes.add_child(lobe)

	if collidable:
		var shape := CollisionShape3D.new()
		shape.name = "Collision"
		var sphere := SphereShape3D.new()
		sphere.radius = mean_extent * 0.40
		shape.shape = sphere
		container.add_child(shape)

	# Slow tumble, set once and driven from accumulated delta, so the field is
	# alive without a physics body or an animation player anywhere in the
	# cluster. The platform's host rock never tumbles: a structure is bolted to it.
	var axis := Vector3(
		random.randf_range(-1.0, 1.0),
		random.randf_range(-1.0, 1.0),
		random.randf_range(-1.0, 1.0)
	)
	var rate := random.randf_range(0.8, 3.5)
	if tumbling:
		if axis.length_squared() < 0.0001:
			axis = Vector3.UP
		lobes.set_meta(&"spin_axis", axis.normalized())
		lobes.set_meta(&"spin_rate", rate)
		lobes.set_meta(&"rest_basis", lobes.basis)
		_spin_bodies.append(lobes)
	return container


func _rock_mesh(size: Vector3) -> ArrayMesh:
	var key := "rock:%0.2f:%0.2f:%0.2f" % [size.x, size.y, size.z]
	if _rock_mesh_cache.has(key):
		return _rock_mesh_cache[key] as ArrayMesh
	var shortest := minf(size.x, minf(size.y, size.z))
	var mesh := StationSurfaceKit.rounded_box_mesh_with_bevel(size, shortest * ROCK_BEVEL_PROPORTION)
	_rock_mesh_cache[key] = mesh
	return mesh


# --- Extraction platform -----------------------------------------------------


func _build_extraction_platform() -> void:
	var platform := Node3D.new()
	platform.name = "CinderReachPlatform"
	platform.position = PLATFORM_ANCHOR
	_platform_root.add_child(platform)

	# Host body. The platform was built onto a rock, so the rock is part of the
	# silhouette rather than a prop standing beside it.
	var host_random := RandomNumberGenerator.new()
	host_random.seed = FIELD_SEED + 977
	_build_rock_chunk(
		platform,
		"HostAsteroid",
		Vector3(0.0, -46.0, -8.0),
		64.0,
		host_random,
		_materials["rock_rust"],
		true,
		false
	)

	# Core drum and its collars.
	_cylinder(platform, "CoreDrum", Vector3.ZERO, 11.0, 11.0, 26.0, _materials["hull"], true)
	_torus(platform, "DrumCollarUpper", Vector3(0.0, 9.0, 0.0), 11.6, 13.2, _materials["steel"], Vector3(90.0, 0.0, 0.0))
	_torus(platform, "DrumCollarLower", Vector3(0.0, -9.0, 0.0), 11.6, 13.2, _materials["steel"], Vector3(90.0, 0.0, 0.0))
	_cylinder(platform, "DrumCap", Vector3(0.0, 15.0, 0.0), 7.4, 9.2, 5.0, _materials["hull_shadow"], true)

	# Processing spine, running out toward the station so the structure points at
	# the pilot's approach instead of presenting a blank flank.
	_box(platform, "ProcessingSpine", Vector3(0.0, 0.0, SPINE_CENTER_Z), SPINE_SIZE, _materials["hull"], true)
	_build_processing_spine_ribs(platform)
	# Burned-through bays: the abandonment read, done with material rather than a
	# hole, so the collision envelope stays one simple solid spine.
	for z_position in [-18.0, 6.0]:
		for side in [-1.0, 1.0]:
			_box(
				platform,
				"ScorchedBay",
				Vector3(side * 4.62, 0.0, z_position),
				Vector3(0.4, 5.4, 8.0),
				_materials["char"],
				false
			)

	_build_gantry(platform)
	_build_extraction_arms(platform)
	_build_derelict_hardware(platform)
	_build_platform_mast(platform)


## Four identical visual-only ribs use the exact cached bevel mesh, steel
## material and authored local transforms they had as separate MeshInstances.
## They own no collision, interaction, animation, evidence or gameplay path, so
## one MultiMesh submission preserves the visible copies and triangles while
## removing three renderer nodes/submissions from this bounded component.
func _build_processing_spine_ribs(platform: Node3D) -> void:
	var transforms: Array[Transform3D] = []
	for z_position in PROCESSING_SPINE_RIB_Z_POSITIONS:
		transforms.append(Transform3D(Basis.IDENTITY, Vector3(0.0, 0.0, z_position)))
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.mesh = StationSurfaceKit.rounded_box_mesh_cached(
		PROCESSING_SPINE_RIB_SIZE, _box_cache
	)
	multimesh.instance_count = transforms.size()
	multimesh.visible_instance_count = -1
	# Bulk-author the renderer payload so the exact 12-float transform record is
	# auditable even when the headless backend exposes identity transform reads.
	multimesh.buffer = _encode_multimesh_transforms(transforms)
	# Raw-buffer MultiMeshes do not derive a CPU AABB under headless. Publish the
	# transformed union explicitly so renderer culling matches the four old nodes.
	multimesh.custom_aabb = _transformed_mesh_bounds(multimesh.mesh.get_aabb(), transforms)
	var batch := MultiMeshInstance3D.new()
	batch.name = "ProcessingSpineRibs"
	batch.multimesh = multimesh
	batch.material_override = _materials["steel"]
	batch.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	batch.set_meta(&"visual_detail_only", true)
	batch.set_meta(&"visual_batch_family_id", PROCESSING_SPINE_RIB_FAMILY_ID)
	batch.set_meta(&"authored_instance_transforms", transforms.duplicate())
	platform.add_child(batch)


func _encode_multimesh_transforms(transforms: Array[Transform3D]) -> PackedFloat32Array:
	var buffer := PackedFloat32Array()
	buffer.resize(transforms.size() * 12)
	for index in transforms.size():
		var transform_value := transforms[index]
		var offset := index * 12
		buffer[offset + 0] = transform_value.basis.x.x
		buffer[offset + 1] = transform_value.basis.y.x
		buffer[offset + 2] = transform_value.basis.z.x
		buffer[offset + 3] = transform_value.origin.x
		buffer[offset + 4] = transform_value.basis.x.y
		buffer[offset + 5] = transform_value.basis.y.y
		buffer[offset + 6] = transform_value.basis.z.y
		buffer[offset + 7] = transform_value.origin.y
		buffer[offset + 8] = transform_value.basis.x.z
		buffer[offset + 9] = transform_value.basis.y.z
		buffer[offset + 10] = transform_value.basis.z.z
		buffer[offset + 11] = transform_value.origin.z
	return buffer


func _transformed_mesh_bounds(mesh_bounds: AABB, transforms: Array[Transform3D]) -> AABB:
	var result := AABB()
	var first := true
	for transform_value in transforms:
		var piece := (transform_value * mesh_bounds).abs()
		if first:
			result = piece
			first = false
		else:
			result = result.merge(piece)
	return result


## The reason to come out here: two open frames the ship fits through with room
## to spare, lit around the aperture so the opening is legible on approach. Both
## frames stand on the approach lane the boulder scatter is forbidden to enter,
## so the run in is clear whatever the field seed produces.
func _build_gantry(platform: Node3D) -> void:
	var half_width := GANTRY_CLEAR_WIDTH * 0.5
	var half_height := GANTRY_CLEAR_HEIGHT * 0.5
	for frame_index in 2:
		var z_position := GANTRY_NEAR_Z if frame_index == 0 else GANTRY_FAR_Z
		var frame := Node3D.new()
		frame.name = "GantryFrame%d" % (frame_index + 1)
		frame.position = Vector3(0.0, GANTRY_CENTER_Y, z_position)
		platform.add_child(frame)
		var span := GANTRY_CLEAR_WIDTH + GANTRY_BEAM * 2.0
		_box(
			frame,
			"Header",
			Vector3(0.0, half_height + GANTRY_BEAM * 0.5, 0.0),
			Vector3(span, GANTRY_BEAM, 4.0),
			_materials["hull"],
			true
		)
		_box(
			frame,
			"Sill",
			Vector3(0.0, -half_height - GANTRY_BEAM * 0.5, 0.0),
			Vector3(span, GANTRY_BEAM, 4.0),
			_materials["hull"],
			true
		)
		for side in [-1.0, 1.0]:
			_box(
				frame,
				"Post",
				Vector3(side * (half_width + GANTRY_BEAM * 0.5), 0.0, 0.0),
				Vector3(GANTRY_BEAM, GANTRY_CLEAR_HEIGHT, 4.0),
				_materials["hull"],
				true
			)
			_box(
				frame,
				"CornerBrace",
				Vector3(side * (half_width - 2.0), half_height - 2.0, 0.0),
				Vector3(7.0, 0.8, 2.4),
				_materials["steel"],
				false,
				Vector3(0.0, 0.0, side * 38.0)
			)
		# Aperture lamps: low energy, short range. They mark the opening from
		# outside without washing out the structure the ship is about to pass.
		for corner_x in [-1.0, 1.0]:
			for corner_y in [-1.0, 1.0]:
				_lamp(
					frame,
					"ApertureLamp",
					Vector3(corner_x * (half_width - 1.0), corner_y * (half_height - 1.0), 2.2),
					KETH_CYAN,
					1.9,
					16.0,
					frame_index == 0
				)

	# Rails linking the two frames into a short tunnel rather than two loose rings.
	for side in [-1.0, 1.0]:
		for rail_y in [-1.0, 1.0]:
			_box(
				platform,
				"GantryRail",
				Vector3(
					side * (half_width + 1.5),
					GANTRY_CENTER_Y + rail_y * (half_height + 1.5),
					(GANTRY_NEAR_Z + GANTRY_FAR_Z) * 0.5
				),
				Vector3(1.2, 1.2, GANTRY_NEAR_Z - GANTRY_FAR_Z),
				_materials["steel"],
				false
			)

	_sign(
		platform,
		"CINDER REACH DOCK GATE",
		Vector3(0.0, GANTRY_CENTER_Y + half_height + GANTRY_BEAM + 3.5, GANTRY_NEAR_Z),
		Vector3.ZERO,
		2.4,
		_materials["cyan_glow"]
	)
	# Platform signage sits above the spine's front face, so it is read once the
	# pilot is through the gate and still has 60 m to slow down.
	_sign(platform, "CINDER REACH", Vector3(0.0, 26.0, 20.0), Vector3.ZERO, 5.0, _materials["orange_glow"])
	_sign(
		platform,
		"EXTRACTION PLATFORM - DERELICT",
		Vector3(0.0, 21.0, 20.0),
		Vector3.ZERO,
		2.2,
		_materials["cyan_glow"]
	)


func _build_extraction_arms(platform: Node3D) -> void:
	for side in [-1.0, 1.0]:
		var arm := Node3D.new()
		arm.name = "ExtractionArm%s" % ("Port" if side < 0.0 else "Starboard")
		arm.position = Vector3(side * 12.0, -8.0, -6.0)
		arm.rotation_degrees = Vector3(-36.0, 0.0, side * 14.0)
		platform.add_child(arm)
		_box(arm, "ArmSpar", Vector3(0.0, -17.0, 0.0), Vector3(4.4, 38.0, 4.4), _materials["hull_shadow"], true)
		for segment in 3:
			_box(
				arm,
				"ArmCollar",
				Vector3(0.0, -6.0 - float(segment) * 11.0, 0.0),
				Vector3(6.0, 1.4, 6.0),
				_materials["steel"],
				false
			)
		_cylinder(arm, "DrillHead", Vector3(0.0, -37.5, 0.0), 1.2, 3.6, 6.0, _materials["orange"], true)
		_lamp(arm, "ArmLamp", Vector3(0.0, -33.0, 3.6), KETH_ORANGE, 1.5, 12.0, false)


func _build_derelict_hardware(platform: Node3D) -> void:
	# A habitat can torn open at one end. Leaving the cap off is not a texture
	# trick: the builder is asked for an uncapped cylinder, so the interior wall
	# is real geometry the pilot can look down.
	var can := Node3D.new()
	can.name = "DerelictHabitatCan"
	can.position = Vector3(25.0, 9.0, -12.0)
	can.rotation_degrees = Vector3(0.0, 12.0, 90.0)
	platform.add_child(can)
	_cylinder(can, "CanShell", Vector3.ZERO, 6.0, 6.0, 18.0, _materials["hull_shadow"], true, Vector3.ZERO, false, true)
	_torus(can, "CanTornRim", Vector3(0.0, 9.0, 0.0), 5.6, 6.3, _materials["char"], Vector3(90.0, 0.0, 0.0))
	_box(can, "CanSpine", Vector3(0.0, -10.4, 0.0), Vector3(2.0, 3.0, 2.0), _materials["steel"], false)

	# Two solar wings, one still oriented and one collapsed off its hinge. The
	# broken one is the fastest read that this place stopped working.
	var wing_intact := Node3D.new()
	wing_intact.name = "SolarWingIntact"
	wing_intact.position = Vector3(-32.0, 11.0, -2.0)
	wing_intact.rotation_degrees = Vector3(0.0, 0.0, 6.0)
	platform.add_child(wing_intact)
	_box(wing_intact, "Panel", Vector3.ZERO, Vector3(42.0, 0.7, 15.0), _materials["solar"], false)
	_box(wing_intact, "Boom", Vector3(20.0, 0.0, 0.0), Vector3(10.0, 1.2, 1.2), _materials["steel"], true)

	var wing_broken := Node3D.new()
	wing_broken.name = "SolarWingCollapsed"
	wing_broken.position = Vector3(31.0, -6.0, -22.0)
	wing_broken.rotation_degrees = Vector3(12.0, 8.0, 58.0)
	platform.add_child(wing_broken)
	_box(wing_broken, "Panel", Vector3.ZERO, Vector3(34.0, 0.7, 15.0), _materials["solar_dead"], false)
	_box(wing_broken, "Boom", Vector3(-17.0, 0.0, 0.0), Vector3(10.0, 1.2, 1.2), _materials["char"], false)

	# Ore chutes hanging under the drum toward the host rock.
	for side in [-1.0, 1.0]:
		_cylinder(
			platform,
			"OreChute",
			Vector3(side * 6.0, -16.0, 2.0),
			2.4,
			2.0,
			22.0,
			_materials["steel"],
			true,
			Vector3(side * 9.0, 0.0, side * 7.0)
		)


func _build_platform_mast(platform: Node3D) -> void:
	_cylinder(platform, "SignalMast", Vector3(0.0, 25.0, 0.0), 1.1, 1.5, 16.0, _materials["steel"], true)
	var head := Node3D.new()
	head.name = "HazardBeaconHead"
	head.position = Vector3(0.0, 34.0, 0.0)
	platform.add_child(head)
	_box(head, "HeadShell", Vector3.ZERO, Vector3(2.6, 1.8, 2.6), _materials["hull_shadow"], false)
	_box(head, "HeadLens", Vector3(0.0, 0.0, 1.5), Vector3(1.6, 1.2, 0.5), _materials["orange_glow"], false)
	var hazard := SpotLight3D.new()
	hazard.name = "HazardBeacon"
	hazard.position = Vector3(0.0, 0.0, 1.4)
	hazard.rotation_degrees = Vector3(0.0, 180.0, 0.0)
	hazard.light_color = KETH_ORANGE
	hazard.light_energy = 6.0
	hazard.spot_range = 90.0
	hazard.spot_angle = 21.0
	hazard.shadow_enabled = false
	head.add_child(hazard)
	_hazard_head = head


# --- Shared builders ---------------------------------------------------------


func _create_materials() -> void:
	_materials["steel"] = _panel_material(STEEL_BLUE, 0.5, 0.36, 0.12)
	_materials["hull"] = _panel_material(HULL_OCHRE, 0.2, 0.66, 0.075)
	_materials["hull_shadow"] = _panel_material(HULL_SHADOW, 0.3, 0.7, 0.1)
	_materials["char"] = _material(HULL_CHAR, 0.1, 0.94)
	_materials["orange"] = _material(KETH_ORANGE, 0.1, 0.56)
	_materials["rock_basalt"] = _material(ROCK_BASALT, 0.04, 0.93)
	_materials["rock_rust"] = _material(ROCK_RUST, 0.06, 0.9)
	_materials["rock_pale"] = _material(ROCK_PALE, 0.05, 0.88)
	_materials["moonlet"] = _material(MOONLET_TEAL, 0.0, 0.94)
	_materials["ring"] = _material(MOONLET_RING, 0.0, 1.0)
	_materials["ring_pale"] = _material(MOONLET_RING.darkened(0.18), 0.0, 1.0)
	_materials["moonlet_crater"] = _material(MOONLET_TEAL.darkened(0.42), 0.0, 0.96)
	_materials["solar"] = _material(Color("15384a"), 0.55, 0.24, Color("1d6f7f"), 0.35)
	_materials["solar_dead"] = _material(Color("101820"), 0.4, 0.72)
	_materials["cyan_glow"] = _material(KETH_CYAN, 0.0, 0.28, KETH_CYAN, 1.5)
	_materials["orange_glow"] = _material(KETH_ORANGE, 0.0, 0.3, KETH_ORANGE, 1.4)


func _material(
		color: Color,
		metallic: float = 0.0,
		roughness: float = 0.65,
		emission_color: Color = Color.TRANSPARENT,
		emission_energy: float = 0.0
	) -> StandardMaterial3D:
	# The same per-pixel/Burley/Schlick-GGX trio the station hub and the modules
	# already answer light with, so the cluster does not shade differently from
	# the place the pilot just left.
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


## Manufactured surfaces in the cluster take the registered station panel recipe,
## because the platform is built stock, not rock. `apply_panel_triplanar` returns
## false when the maps are unavailable; the untextured PBR values are then left
## exactly as set rather than half a recipe being bound.
func _panel_material(
		color: Color,
		metallic: float,
		roughness: float,
		uv_scale: float
	) -> StandardMaterial3D:
	var result := _material(color, metallic, roughness)
	StationSurfaceKit.apply_panel_triplanar(result, uv_scale)
	return result


func _lens_material(color: Color) -> StandardMaterial3D:
	var key := color.to_html(false)
	if not _lens_materials.has(key):
		_lens_materials[key] = _material(color, 0.0, 0.25, color, 1.6)
	return _lens_materials[key] as StandardMaterial3D


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
		cylinder_rotation_degrees: Vector3 = Vector3.ZERO,
		cap_top: bool = true,
		cap_bottom: bool = true
	) -> Node3D:
	var mesh := StationSurfaceKit.chamfered_cylinder_mesh_cached(
		top_radius, bottom_radius, height, 24, _cylinder_cache, 4, cap_top, cap_bottom
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


## A torus is smooth everywhere and has no rim, so it is outside the surface
## kit's scope and stays on the engine primitive.
func _torus(
		parent: Node3D,
		node_name: String,
		torus_position: Vector3,
		inner_radius: float,
		outer_radius: float,
		material: Material,
		torus_rotation_degrees: Vector3
	) -> MeshInstance3D:
	var mesh := TorusMesh.new()
	mesh.inner_radius = inner_radius
	mesh.outer_radius = outer_radius
	mesh.rings = 40
	mesh.ring_segments = 14
	var instance := MeshInstance3D.new()
	instance.name = node_name
	instance.position = torus_position
	instance.rotation_degrees = torus_rotation_degrees
	instance.mesh = mesh
	instance.material_override = material
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(instance)
	return instance


func _lamp(
		parent: Node3D,
		node_name: String,
		lamp_position: Vector3,
		color: Color,
		energy: float,
		range_value: float,
		pulsing: bool
	) -> OmniLight3D:
	var lens := MeshInstance3D.new()
	lens.name = node_name + "Lens"
	lens.position = lamp_position
	var lens_mesh := SphereMesh.new()
	lens_mesh.radius = 0.45
	lens_mesh.height = 0.9
	lens_mesh.radial_segments = 12
	lens_mesh.rings = 6
	lens.mesh = lens_mesh
	lens.material_override = _lens_material(color)
	lens.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(lens)

	var light := OmniLight3D.new()
	light.name = node_name
	light.position = lamp_position
	light.light_color = color
	light.light_energy = energy
	light.omni_range = range_value
	light.shadow_enabled = false
	parent.add_child(light)
	if pulsing:
		light.set_meta(&"pulse_phase", float(_pulse_lamps.size()) * 0.71)
		light.set_meta(&"base_energy", energy)
		_pulse_lamps.append(light)
	return light


func _sign(
		parent: Node3D,
		text: String,
		text_position: Vector3,
		text_rotation_degrees: Vector3,
		scale_value: float,
		material: Material
	) -> MeshInstance3D:
	# Same shared budget as the station: sector legends are read from a moving
	# craft at tens of metres, where a 0.03 m extrusion on a sign scaled 2.2x is
	# geometry nobody is ever placed to see. See `SignGeometryBudget`.
	var text_mesh := SignGeometryBudget.build(text)
	var instance := MeshInstance3D.new()
	instance.name = "Sign_" + text.replace(" ", "_").replace("/", "-")
	instance.position = text_position
	instance.rotation_degrees = text_rotation_degrees
	instance.scale = Vector3.ONE * scale_value
	instance.mesh = text_mesh
	instance.material_override = material
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(instance)
	return instance
