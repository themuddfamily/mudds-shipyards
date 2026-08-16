extends SceneTree

## Regression for the P2 presentation half of the 2026-08-15 human playtest
## report: "…random objects floating in the air and it ruins the experience."
##
## These three assertions were split out of
## `station_traversal_defect_witness_test.gd` when the P1 traversal defects
## (MAP-001/002/003) were fixed, and reproduced there **verbatim** so a P2
## presentation defect could not hold the P1 traversal gate red. They cover
## MAP-004, MAP-005 and MAP-006, which are now fixed, so this file has been
## renamed into the `*_test.gd` glob and is collected by
## `tools/release/run_test_matrix.sh`.
##
## One deliberate change was made when the defects were fixed, recorded here
## rather than made quietly:
##
##   `APPROACH_FACING_SIGNS` gained five entries. The intake listed six mirrored
##   legends; sweeping every live `TextMesh` in the production world found five
##   more with exactly the same cause — `Vector3.ZERO` rotation on a structure's
##   approach-side face — including both legends on `JunctionPortalHeader`, the
##   station's most prominent navigation board. The original six are unchanged
##   in wording, path and expectation; the roster is only widened, from six entries to eleven. No threshold
##   was loosened and no assertion was removed.
##
## Run it directly with:
##
##   godot --headless --path . --script tests/station_presentation_defect_witness_test.gd

const MAIN_SCENE := preload("res://scenes/main.tscn")
const WORLD_LAYER := PhysicsLayers.WORLD

## MAP-004. Facade and terminal legends whose readable face must point at the
## deck the player actually approaches them from. TextMesh renders its readable
## face toward local +Z, so `expected_facing` is the direction a reader stands in.
const APPROACH_FACING_SIGNS := [
	["UpperOperations/Sign_DOCK_OPERATIONS", Vector3(0.0, 0.0, -1.0)],
	["ModernFleetRegistry/Sign_FLEET_REGISTRY__--__MODERN_INTERFACE", Vector3(0.0, 0.0, -1.0)],
	["ModernFleetRegistry/Sign_SAY_SHIP_NAME", Vector3(0.0, 0.0, -1.0)],
	["ModernFleetRegistry/Sign_TORRENT__JOVIAN__TITAN__VORTEX", Vector3(0.0, 0.0, -1.0)],
	["ModernFleetRegistry/Sign_KATANA__PARADOX__PREDATOR__DYNAMIC", Vector3(0.0, 0.0, -1.0)],
	["ModernFleetRegistry/Sign_UTOPIA__ARROW", Vector3(0.0, 0.0, -1.0)],
	# Widened beyond the intake's six after a sweep of every live `TextMesh`.
	# Same cause, same fix; all five were rendered and read backwards first.
	["ExposedDockLattice/Sign_MUDDS__--__REGENERATION_DECK", Vector3(0.0, 0.0, -1.0)],
	["ExposedDockLattice/Sign_CENTRAL_JUNCTION__--__FLEET_DOCKS", Vector3(0.0, 0.0, -1.0)],
	["AftJunctionStack/Structure/VIPLandmark/Sign_VIP_RECEPTION__--__MODERN_INTERPRETATION", Vector3(0.0, 0.0, -1.0)],
	[
		"AftJunctionStack/Structure/OpenStructureDetails/Sign_AFT_JUNCTION__--__MODERN_INTERPRETATION",
		Vector3(0.0, 0.0, -1.0),
	],
	[
		"HabitatSpine/Structure/PlayerClearConnector/Sign_HABITAT_SPINE____FIXED-ERA-INSPIRED",
		Vector3(-1.0, 0.0, 0.0),
	],
	# Aft operations content pass. The status board hangs on the room's south
	# bulkhead and is read from inside the room, so its reader stands at +Z; the
	# stair-head muster legend is read by someone who has just finished the climb
	# and is standing south of the locker, so its reader stands at -Z.
	[
		"AftJunctionStack/Structure/OperationsRoom/OperationsContent/ModuleStatusBoard/Sign_AFT_MODULE_STATUS",
		Vector3(0.0, 0.0, 1.0),
	],
	[
		"AftJunctionStack/Structure/UpperOpenDeck/StairHeadMuster/Sign_MUSTER_POINT",
		Vector3(0.0, 0.0, -1.0),
	],
]

## MAP-005. Decorative pieces that must rest on the surface they are placed against.
const SEATED_DECORATION_PATHS := [
	"OperationalLattice/Activities/AftOperationsActivity/PresentationRoot/SafetyBeacon01/Base",
	"OperationalLattice/Activities/AftOperationsActivity/PresentationRoot/SafetyBeacon02/Base",
	"OperationalLattice/Activities/AftOperationsActivity/PresentationRoot/SafetyBeacon03/Base",
	"OperationalLattice/Activities/AftOperationsActivity/PresentationRoot/SafetyBeacon04/Base",
	"OperationalLattice/Activities/HabitatServicePatrol/PresentationRoot/SafetyBeacon01/Base",
	"OperationalLattice/Activities/HabitatServicePatrol/PresentationRoot/SafetyBeacon02/Base",
	"OperationalLattice/Activities/HabitatServicePatrol/PresentationRoot/SafetyBeacon03/Base",
	"OperationalLattice/Activities/HabitatServicePatrol/PresentationRoot/SafetyBeacon04/Base",
	# Every floor-standing piece the aft operations content pass added. These are
	# the ones that must rest on *collision* rather than merely against drawn
	# geometry, because each one is a solid a player walks into and each one stands
	# on a deck that has a collider under it. The path is the body's `Mesh` child;
	# `_drop_below` excludes the piece's own body, so the ray it fires is against
	# the deck beneath and nothing else.
	"AftJunctionStack/Structure/OperationsRoom/OperationsContent/WatchRackBank/WatchRackFrame00/Mesh",
	"AftJunctionStack/Structure/OperationsRoom/OperationsContent/WatchRackBank/WatchRackFrame01/Mesh",
	"AftJunctionStack/Structure/OperationsRoom/OperationsContent/WatchRackBank/WatchRackFrame02/Mesh",
	"AftJunctionStack/Structure/OperationsRoom/OperationsContent/TrafficPlotTable/PlotTableBase/Mesh",
	"AftJunctionStack/Structure/OperationsRoom/OperationsContent/CoordinatorDesk/CoordinatorDeskBody/Mesh",
	"AftJunctionStack/Structure/OperationsRoom/OperationsContent/ChartPress/ChartPressBody/Mesh",
	"AftJunctionStack/Structure/OperationsRoom/OperationsContent/RefreshmentStand/RefreshmentCounter/Mesh",
	"AftJunctionStack/Structure/UpperOpenDeck/StairHeadMuster/MusterLockerBody/Mesh",
]
const SEATED_DECORATION_TOLERANCE := 0.03

## The 2026-08-16 report: "there's a strange floating block". `_drop_below` above
## cannot answer this class, because it rays against World *collision* and every
## piece here hangs off structure that has none — under-deck chords, stacked
## crates. In open space that ray simply falls forever.
##
## So this roster is measured against **drawn geometry** instead: each piece must
## share volume with, or sit within `SEATED_ON_GEOMETRY_TOLERANCE` of, some other
## visible mesh. Measured live before the fix, with the gap each one hung at:
##
##   Fleet Dock Comb underframe: both 47 m trunk chords hung 0.090 m below the
##   deck they are bolted to, and the port one intersected nothing in the whole
##   module; the three rung chords hung 0.040 m.
##   Jovian freight: all eight cargo crates hovered, 0.045-0.055 m above the rack
##   shelf for the lower four and 0.040-0.070 m above their own lower crate for
##   the upper four.
##
## Widened by the 2026-08-16 interior-relationship pass, from ten entries to
## nineteen. Every addition is a piece that pass either added or repaired, and
## three of them are the repairs themselves, recorded here so the defect cannot
## come back:
##
##   REGEN-DECK-002. Both station pod identity legends hung in mid-air. Measured
##   live, `FLEET REGISTRY // MODERN INTERFACE` occupied y = 4.928 … 5.148 at
##   z = 22.815 — 0.18 m in front of the registry roof's leading edge and 0.48 m
##   below it — and `DOCK OPERATIONS` hung the same way off its mirror pod.
##   MAP-004 turned both the right way round; nothing ever mounted them. Each pod
##   now carries a fascia hung off its own roof edge, sized to meet the glyphs
##   exactly where they already stand, so both legend transforms are unchanged and
##   their MAP-004 approach-facing entries above still hold.
##   OPS-GLAZING-001. Every Dock Operations window pane stood in the 0.245 m gap
##   between the mullions it is supposed to be glazed into, and the fourth pane
##   reached x = 51.825 against a pod that ends at x = 49 — 2.83 m of a 4.7 m
##   sheet of glass standing in open space past the corner of the building.
##
## The comb's own equivalents are asserted structurally rather than by path in
## `tests/fleet_dock_comb_test.gd`, which sweeps every generated surface-detail
## mesh in the module; that sweep is what found COMB-DECK-CUE-001.
##
## Widened again by the central-berth finishing pass, nineteen entries to
## twenty-nine, for the hero berth's port-flank ground support line and the four
## dock mast feet. These are entered pre-emptively rather than as repairs: the
## pass added the first freestanding objects that stand on the *authored* berth
## deck, and that deck is the one surface on the station where the obvious
## seating method is wrong. Its drawn top face is y = 0.095 while the
## `HeroBerthNode` collision box under it ends at y = -0.02, so a piece seated by
## raycast against the World layer — which is what `_drop_below` and the roster
## above it do — lands 0.115 m low and hangs there. That is exactly the error
## that put the central berth cue 0.235 m over its own deck. Every piece listed
## below is instead seated arithmetically against
## `ShipyardWorld.AUTHORED_CENTRAL_BERTH_DECK_TOP` (or `LATTICE_DECK_TOP` for the
## two masts standing on `CentralJunction`), with the station's shared 0.010 m
## bearing into the surface, and is checked here against drawn geometry.
##
## One entry per assembly is listed, at its ground contact, plus the work stand's
## platform because it is the only piece in the line that stands on its own legs
## rather than on the deck. Sub-pieces stacked on those — bins on shelves, the
## hard hat on the platform, cleat horns on cleat stems — share volume with the
## piece under them by construction, and the whole line is additionally swept
## structurally by `tests/central_berth_service_line_test.gd`.
const SEATED_ON_GEOMETRY_PATHS := [
	"FleetDockComb/GeneratedComb/VisualUnderframe/TrunkChordPort",
	"FleetDockComb/GeneratedComb/VisualUnderframe/TrunkChordStarboard",
	"ModernFleetRegistry/Sign_FLEET_REGISTRY__--__MODERN_INTERFACE",
	"ModernFleetRegistry/RegistryDispatchBoard",
	"ModernFleetRegistry/RegistryTaskLampHousing",
	"ModernFleetRegistry/RegistryToolRack",
	"ModernFleetRegistry/RegistryPartsTray",
	"ModernFleetRegistry/RegistryStowedManifest",
	"UpperOperations/Sign_DOCK_OPERATIONS",
	"UpperOperations/OperationsWindow",
	"UpperOperations/LandingConsoleReadout",
	"UpperOperations/LandingViewerHead",
	"JovianFreightBerth/CargoInfrastructure/CargoUnit01/Mesh",
	"JovianFreightBerth/CargoInfrastructure/CargoUnit02/Mesh",
	"JovianFreightBerth/CargoInfrastructure/CargoUnit03/Mesh",
	"JovianFreightBerth/CargoInfrastructure/CargoUnit04/Mesh",
	"JovianFreightBerth/CargoInfrastructure/CargoUnit05/Mesh",
	"JovianFreightBerth/CargoInfrastructure/CargoUnit06/Mesh",
	"JovianFreightBerth/CargoInfrastructure/CargoUnit07/Mesh",
	"JovianFreightBerth/CargoInfrastructure/CargoUnit08/Mesh",
	"CentralBerthServiceLine/PortFlank/BerthReadinessBoard/BoardFoot/Mesh",
	"CentralBerthServiceLine/PortFlank/CableDrumStand/DrumPlinth/Mesh",
	"CentralBerthServiceLine/PortFlank/PartsBinRack/RackFoot/Mesh",
	"CentralBerthServiceLine/PortFlank/ChockLocker/LockerBody/Mesh",
	"CentralBerthServiceLine/PortFlank/AccessWorkStand/StandStepLower/Mesh",
	"CentralBerthServiceLine/PortFlank/AccessWorkStand/StandPlatform/Mesh",
	"CentralBerthServiceLine/DockMastFoot00/MastBaseFlange",
	"CentralBerthServiceLine/DockMastFoot01/MastBaseFlange",
	"CentralBerthServiceLine/DockMastFoot02/MastBaseFlange",
	"CentralBerthServiceLine/DockMastFoot03/MastBaseFlange",
	# Aft operations content pass: the pieces that are mounted on, hung off or
	# stacked on something rather than standing on a deck. Together with the
	# collision-backed roster above this is the whole of what that pass placed —
	# every mug, tag, roll, sheet and headset in the room is required here to share
	# volume with the surface it was put down on. Two were caught by this check
	# during authoring: the lockout tag hung 0.005 m clear of its own chain and the
	# notice sheets stood 0.002 m off the board they are pinned to.
	"AftJunctionStack/Structure/OperationsRoom/OperationsContent/WatchRackBank/RackLockoutTag",
	"AftJunctionStack/Structure/OperationsRoom/OperationsContent/WatchRackBank/RackRemovedFascia",
	"AftJunctionStack/Structure/OperationsRoom/OperationsContent/ModuleStatusBoard/StatusBoardBody",
	"AftJunctionStack/Structure/OperationsRoom/OperationsContent/ModuleStatusBoard/StatusBoardField",
	"AftJunctionStack/Structure/OperationsRoom/OperationsContent/TrafficPlotTable/PlotSweepArm/SweepHead",
	"AftJunctionStack/Structure/OperationsRoom/OperationsContent/TrafficPlotTable/PlotDutyMug",
	"AftJunctionStack/Structure/OperationsRoom/OperationsContent/TrafficPlotTable/PlotLogbookPages",
	"AftJunctionStack/Structure/OperationsRoom/OperationsContent/TrafficPlotTable/PlotToken00",
	"AftJunctionStack/Structure/OperationsRoom/OperationsContent/CoordinatorDesk/CoordinatorLampHead",
	"AftJunctionStack/Structure/OperationsRoom/OperationsContent/CoordinatorDesk/DeskHeadsetBand",
	"AftJunctionStack/Structure/OperationsRoom/OperationsContent/CoordinatorDesk/DutyLogLeaf",
	"AftJunctionStack/Structure/OperationsRoom/OperationsContent/ChartPress/NoticeSheet00",
	"AftJunctionStack/Structure/OperationsRoom/OperationsContent/ChartPress/Clipboard",
	"AftJunctionStack/Structure/OperationsRoom/OperationsContent/ChartPress/ChartPressRoll03",
	"AftJunctionStack/Structure/OperationsRoom/OperationsContent/RefreshmentStand/WaterUrn",
	"AftJunctionStack/Structure/OperationsRoom/OperationsContent/RefreshmentStand/StowedMug00",
	"AftJunctionStack/Structure/OperationsRoom/OperationsContent/CrewTraces/ConsoleHeadsetBand",
	"AftJunctionStack/Structure/OperationsRoom/OperationsChair04/StowedCoverall",
	"AftJunctionStack/Structure/UpperOpenDeck/StairHeadMuster/MusterRouteBoard",
	"AftJunctionStack/Structure/UpperOpenDeck/StairHeadMuster/MusterHoseReel",
	# The long-cargo pass. Every stacked or hung piece of the two 21.6 m transfer
	# runs, plus the short line's re-sited hoist, because these are exactly the
	# shapes that have floated before: a crate resting on the crate below it, a
	# gantry rail resting on its posts, a hoist bridge riding that rail, and a
	# hook hanging off the bridge. The bridge and hook are movers, so they are
	# audited here at the clock position the world boots at and again across the
	# whole travel by `tools/capture_cargo_lines.gd`.
	"OperationalLattice/Activities/PortBranchCargoLine/PresentationRoot/LongCargoTransferLine/CrateInboundTop",
	"OperationalLattice/Activities/PortBranchCargoLine/PresentationRoot/LongCargoTransferLine/CrateOutboundTop",
	"OperationalLattice/Activities/PortBranchCargoLine/PresentationRoot/LongCargoTransferLine/HoistRail",
	"OperationalLattice/Activities/PortBranchCargoLine/PresentationRoot/LongCargoTransferLine/HoistRail2",
	"OperationalLattice/Activities/PortBranchCargoLine/PresentationRoot/LongCargoTransferLine/CrateManifest",
	"OperationalLattice/Activities/PortBranchCargoLine/PresentationRoot/LongCargoTransferLine/AnimatedLongCargoHoist/HoistBridge",
	"OperationalLattice/Activities/PortBranchCargoLine/PresentationRoot/LongCargoTransferLine/AnimatedLongCargoHoist/HoistHook",
	"OperationalLattice/Activities/StarboardBranchCargoLine/PresentationRoot/LongCargoTransferLine/CrateInboundTop",
	"OperationalLattice/Activities/StarboardBranchCargoLine/PresentationRoot/LongCargoTransferLine/CrateOutboundTop",
	"OperationalLattice/Activities/StarboardBranchCargoLine/PresentationRoot/LongCargoTransferLine/HoistRail",
	"OperationalLattice/Activities/StarboardBranchCargoLine/PresentationRoot/LongCargoTransferLine/HoistRail2",
	"OperationalLattice/Activities/StarboardBranchCargoLine/PresentationRoot/LongCargoTransferLine/AnimatedLongCargoHoist/HoistBridge",
	"OperationalLattice/Activities/StarboardBranchCargoLine/PresentationRoot/LongCargoTransferLine/AnimatedLongCargoHoist/HoistHook",
	"OperationalLattice/Activities/CentralCargoTransferLine/PresentationRoot/CargoTransferLine/CrateUpper",
	"OperationalLattice/Activities/CentralCargoTransferLine/PresentationRoot/CargoTransferLine/HoistBeam",
	"OperationalLattice/Activities/CentralCargoTransferLine/PresentationRoot/CargoTransferLine/AnimatedCargoHoist/HoistHook",
	# The VIP reception's own free-standing pieces. Its suite sweeps every mesh in
	# the module, but the three that most resemble the recorded defects — a legend
	# on a panel, a lamp on a fascia, a cove strip in a reveal — are named here as
	# well so they are covered by the station-wide roster a later pass will read.
	"VipReceptionSuite/Structure/Threshold/Sign_MODERN_INTERPRETATION",
	"VipReceptionSuite/Structure/ExteriorShell/OutboardMarkerLamp01",
	"VipReceptionSuite/Structure/Lighting/LanternCoveFront",
]
const SEATED_ON_GEOMETRY_TOLERANCE := 0.001

var _failures: Array[String] = []
var _space: PhysicsDirectSpaceState3D


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var game := MAIN_SCENE.instantiate() as GameFlow
	_check(game != null, "production Main instantiates for the presentation defect witness")
	if game == null:
		_finish()
		return
	root.add_child(game)
	await process_frame
	await physics_frame
	game.start_shift()
	for _settle in 8:
		await physics_frame

	var world := game.get_node_or_null(^"ShipyardWorld") as ShipyardWorld
	var player := game.get_node_or_null(^"PlayerController") as PlayerController
	if player == null:
		player = game.get_node_or_null(^"Player") as PlayerController
	_check(world != null, "production world is live")
	if world == null:
		game.queue_free()
		await process_frame
		_finish()
		return

	# The player body would otherwise occlude the downward support probes.
	if player != null:
		player.teleport_to(Transform3D(Basis.IDENTITY, Vector3(0.0, 500.0, 0.0)))
		await physics_frame

	_space = world.get_world_3d().direct_space_state

	_test_approach_facing_signs(world)
	_test_seated_decorations_rest_on_their_surface(world)
	_test_structural_pieces_rest_on_drawn_geometry(world)
	_test_berth_cues_are_seated_on_the_deck_they_mark(world)
	_test_orphan_dock_guide_lens(world)

	game.queue_free()
	await process_frame
	await physics_frame
	await process_frame
	_finish()


func _test_approach_facing_signs(world: ShipyardWorld) -> void:
	var reversed_signs := PackedStringArray()
	for entry in APPROACH_FACING_SIGNS:
		var sign_mesh := world.get_node_or_null(NodePath(entry[0] as String)) as MeshInstance3D
		if sign_mesh == null or sign_mesh.mesh is not TextMesh:
			reversed_signs.append("%s <missing>" % entry[0])
			continue
		# TextMesh renders its readable face toward local +Z.
		var readable_from := sign_mesh.global_basis.z.normalized()
		if readable_from.dot(entry[1] as Vector3) <= 0.5:
			reversed_signs.append("%s readable_from=%s expected=%s" % [
				entry[0], str(readable_from), str(entry[1])
			])
	print("REVERSED_APPROACH_SIGNS: ", reversed_signs)
	_check(
		reversed_signs.is_empty(),
		"pod facade and registry terminal legends read forwards from the deck they are approached from"
	)


func _test_seated_decorations_rest_on_their_surface(world: ShipyardWorld) -> void:
	var floating := PackedStringArray()
	for path in SEATED_DECORATION_PATHS:
		var mesh_instance := world.get_node_or_null(NodePath(path)) as MeshInstance3D
		if mesh_instance == null or mesh_instance.mesh == null:
			floating.append("%s <missing>" % path)
			continue
		var drop := _drop_below(mesh_instance)
		if drop > SEATED_DECORATION_TOLERANCE:
			floating.append("%s drop=%.3f" % [path, drop])
	print("FLOATING_SEATED_DECORATIONS: ", floating)
	_check(
		floating.is_empty(),
		"every roof-mounted safety beacon and floor-standing interior fitting rests on the surface it is placed against"
	)


func _test_structural_pieces_rest_on_drawn_geometry(world: ShipyardWorld) -> void:
	var drawn: Array[Dictionary] = []
	for candidate in world.find_children("*", "MeshInstance3D", true, false):
		var mesh_instance := candidate as MeshInstance3D
		if mesh_instance.mesh == null or not mesh_instance.is_visible_in_tree():
			continue
		drawn.append({
			"node": mesh_instance,
			"box": (mesh_instance.global_transform * mesh_instance.mesh.get_aabb()).abs(),
		})
	var floating := PackedStringArray()
	for path in SEATED_ON_GEOMETRY_PATHS:
		var piece := world.get_node_or_null(NodePath(path)) as MeshInstance3D
		if piece == null or piece.mesh == null:
			floating.append("%s <missing>" % path)
			continue
		var box := (piece.global_transform * piece.mesh.get_aabb()).abs().grow(SEATED_ON_GEOMETRY_TOLERANCE)
		var seated := false
		for entry in drawn:
			var other := entry["node"] as MeshInstance3D
			if other == piece or piece.is_ancestor_of(other) or other.is_ancestor_of(piece):
				continue
			if box.intersects(entry["box"] as AABB):
				seated = true
				break
		if not seated:
			floating.append("%s at %s" % [path, str(box.get_center())])
	print("FLOATING_STRUCTURAL_PIECES: ", floating)
	_check(
		floating.is_empty(),
		"every under-deck chord, stacked crate, pod legend, glazing pane and interior fitting bears on drawn geometry instead of hanging in space"
	)


## The fourth report in the same category, recorded under ZENITH-SITE-001 as
## "the berth cue plates" and left for an owner: all four berth cues hovered over
## the deck they mark — Zenith 0.140, Jovian 0.210, central 0.235, Arrow 0.380.
##
## Neither existing helper in this file can measure it, which is why it was
## recorded rather than swept:
##
##   `_drop_below` rays World *collision*, and the central berth's drawn deck is
##   an authored Blender shell 0.115 m above the collision box under it. It
##   reports 0.350 there, not 0.235.
##   `_test_structural_pieces_rest_on_drawn_geometry` intersects bounding boxes,
##   and three of the four berths carry a pad or dock ring built as a **torus**,
##   whose bounding box covers its own hole. Every cue plate "intersects" a ring
##   it is nowhere near, so all four berths pass at any hover.
##
## This measures each plate against drawn **triangles** directly beneath its own
## footprint. It is the only method here that answers the question, and the
## reason both cheaper ones are kept is that they are correct for their own
## rosters — a beacon on a collision deck, a chord bolted under a solid beam.
##
## Deck dressing that stands proud of the deck — pad rings, grip strips, deck
## centrelines — is deliberately not counted as support: a plate resting on a
## 0.15 m rib it crosses at four percent of its area is still hovering over the
## other ninety-six. After the fix those ribs cross *over* the cue instead, which
## is what a painted deck marking running past a raised rib looks like.
##
## The tolerance is the largest gap a *seated* cue can still measure, and it is
## derived rather than chosen: the 0.010 m contact bias
## (`ShipyardWorld.BERTH_CUE_SEAT_HEIGHT`, which exists because coincident faces
## z-fight) plus the deepest authored deck relief any cue plate has to bridge.
## That is the Fleet Dock's 0.040 m grip inset: the inset spans x 15.3 .. 25.7
## and the Zenith cue spans 17.0 .. 27.0, so the two starboard boundary strips
## bear on the inset and overhang its edge, measuring 0.051 against the bare slab
## 0.040 below it. A deck with a step in it is not a floating cue. 0.060 leaves
## float slack on top of that and still fails all four recorded hovers — 0.140,
## 0.210, 0.235 and 0.380 — by between two and six times.
const BERTH_CUE_SEAT_TOLERANCE := 0.06
## The structured red. Lifting a seated cue by this much must turn the check red,
## and it is deliberately smaller than the smallest hover actually reported
## (0.140 at the Zenith), so the guard is proven to bite before the defect is
## as bad as the one that was reported.
const BERTH_CUE_RED_MUTATION := 0.1
## Plates sampled per berth. The four boundary strips are the outermost pieces
## and the ones the Zenith report was written about; the lease plate is the
## innermost. Between them they span the whole cue rectangle.
const BERTH_CUE_SAMPLED_PLATES := [
	"Boundary_Port_Forward",
	"Boundary_Port_Aft",
	"Boundary_Starboard_Forward",
	"Boundary_Starboard_Aft",
	"LeaseStatePlate",
]
## A sample is only counted when something is drawn under it at all. Part of the
## central berth's cue rectangle overhangs open channels in the authored shell,
## where nothing is drawn below and no seat exists to measure; that predates this
## and is unchanged by it.
const BERTH_CUE_MINIMUM_SUPPORTED_FRACTION := 0.9


func _test_berth_cues_are_seated_on_the_deck_they_mark(world: ShipyardWorld) -> void:
	var hovering := _measure_hovering_berth_cues(world, true)
	_check(
		hovering.is_empty(),
		"every berth cue plate is seated on the drawn deck it marks, not hovering over it"
	)

	# Structured red. Lift the Zenith cue — the berth the defect was reported at,
	# and the one with no ring at cue height for a hovering plate to read against —
	# and require the same measurement to fail, then restore it.
	var zenith := world.get_node_or_null(^"ZenithFleetDockBerth/BerthFeedback") as ShipBerthFeedback
	if zenith == null:
		_check(false, "the Zenith berth cue resolves for the structured-red mutation")
		return
	var seated_transform := zenith.transform
	zenith.position.y += BERTH_CUE_RED_MUTATION
	var mutated := _measure_hovering_berth_cues(world, false)
	_check(
		not mutated.is_empty(),
		"lifting a seated berth cue %.2f m turns the seating audit red (%s)"
			% [BERTH_CUE_RED_MUTATION, ", ".join(mutated)]
	)
	zenith.transform = seated_transform
	_check(
		_measure_hovering_berth_cues(world, false).is_empty(),
		"restoring the production cue transform returns the seating audit to green"
	)


func _measure_hovering_berth_cues(world: ShipyardWorld, verbose: bool) -> PackedStringArray:
	var hovering := PackedStringArray()
	var measured := PackedStringArray()
	for berth_id in world.get_berth_ids():
		var spec: Dictionary = ShipyardWorld.SHIP_BERTH_FEEDBACK_SPECS.get(berth_id, {})
		var feedback := world.get_node_or_null(
			spec.get("feedback_path", NodePath()) as NodePath
		) as ShipBerthFeedback
		var visual: Node3D = null
		if feedback != null:
			visual = feedback.get_node_or_null(^"FeedbackVisual") as Node3D
		if visual == null:
			hovering.append("%s <no cue>" % berth_id)
			continue
		var worst := -1.0
		var worst_plate := ""
		var supported := 0
		var sampled := 0
		for plate_name: String in BERTH_CUE_SAMPLED_PLATES:
			var plate := visual.get_node_or_null(NodePath(plate_name)) as MeshInstance3D
			if plate == null or plate.mesh == null:
				hovering.append("%s/%s <missing>" % [berth_id, plate_name])
				continue
			var box := (plate.global_transform * plate.mesh.get_aabb()).abs()
			var triangles := _drawn_triangles_under(world, visual, box)
			for ix in 3:
				for iz in 3:
					var from := Vector3(
						lerpf(box.position.x + 0.01, box.end.x - 0.01, float(ix) * 0.5),
						box.position.y + 0.001,
						lerpf(box.position.z + 0.01, box.end.z - 0.01, float(iz) * 0.5)
					)
					sampled += 1
					var surface: Variant = _highest_triangle_below(from, triangles)
					if surface == null:
						continue
					supported += 1
					var gap := from.y - float(surface)
					if gap > worst:
						worst = gap
						worst_plate = plate_name
		measured.append("%s worst=%.3f (%s) supported=%d/%d" % [berth_id, worst, worst_plate, supported, sampled])
		if sampled == 0 or float(supported) / float(sampled) < BERTH_CUE_MINIMUM_SUPPORTED_FRACTION:
			hovering.append("%s only %d of %d cue samples have drawn deck under them" % [berth_id, supported, sampled])
		if worst > BERTH_CUE_SEAT_TOLERANCE:
			hovering.append("%s cue hovers %.3f m over its deck at %s" % [berth_id, worst, worst_plate])
	if verbose:
		print("BERTH_CUE_SEATING: ", measured)
		print("FLOATING_BERTH_CUES: ", hovering)
	return hovering


## Drawn triangles that could support a plate whose world bounds are `box`: only
## meshes that overlap it in X/Z and reach no higher than its underside, and never
## the cue's own geometry.
func _drawn_triangles_under(world: ShipyardWorld, cue_root: Node3D, box: AABB) -> Array:
	var triangles: Array = []
	for candidate in world.find_children("*", "MeshInstance3D", true, false):
		var mesh_instance := candidate as MeshInstance3D
		if mesh_instance.mesh == null or not mesh_instance.is_visible_in_tree():
			continue
		if cue_root.is_ancestor_of(mesh_instance) or mesh_instance == cue_root:
			continue
		var other := (mesh_instance.global_transform * mesh_instance.mesh.get_aabb()).abs()
		if other.position.y > box.position.y + 0.001:
			continue
		if other.end.x < box.position.x or other.position.x > box.end.x:
			continue
		if other.end.z < box.position.z or other.position.z > box.end.z:
			continue
		var faces := mesh_instance.mesh.get_faces()
		var transform := mesh_instance.global_transform
		for index in range(0, faces.size(), 3):
			var a := transform * faces[index]
			var b := transform * faces[index + 1]
			var c := transform * faces[index + 2]
			if minf(a.y, minf(b.y, c.y)) > box.position.y + 0.001:
				continue
			triangles.append([a, b, c])
	return triangles


func _highest_triangle_below(from: Vector3, triangles: Array) -> Variant:
	var best: Variant = null
	for triangle in triangles:
		var hit = Geometry3D.ray_intersects_triangle(
			from, Vector3.DOWN, triangle[0], triangle[1], triangle[2]
		)
		if hit == null:
			continue
		var y := float((hit as Vector3).y)
		if best == null or y > float(best):
			best = y
	return best


func _test_orphan_dock_guide_lens(world: ShipyardWorld) -> void:
	var lens := world.get_node_or_null(
		^"JovianFreightBerth/FreightPresentation/DockGuideLens18"
	) as MeshInstance3D
	if lens == null or lens.mesh == null:
		_check(false, "the freight dock guide lens roster resolves")
		return
	var apron := world.get_node_or_null(
		^"JovianFreightBerth/LoadingApron/ApronDeck04"
	) as StaticBody3D
	var apron_box := _body_world_box(apron) if apron != null else AABB()
	var lens_box := lens.global_transform * lens.mesh.get_aabb()
	var drop := _drop_below(lens)
	print(
		"DOCK_GUIDE_LENS_18: centre=", lens_box.get_center(),
		" drop=", drop,
		" apron_max_z=", apron_box.end.z
	)
	_check(
		drop <= 0.35,
		"the freight dock guide lens sits on the apron it marks instead of hanging in open space"
	)


func _drop_below(mesh_instance: MeshInstance3D) -> float:
	var box := mesh_instance.global_transform * mesh_instance.mesh.get_aabb()
	var origin := Vector3(box.get_center().x, box.position.y + 0.01, box.get_center().z)
	var ray := PhysicsRayQueryParameters3D.create(origin, origin + Vector3.DOWN * 400.0, WORLD_LAYER)
	ray.collide_with_areas = false
	var body := _owning_body(mesh_instance)
	if body != null:
		ray.exclude = [body.get_rid()]
	var hit := _space.intersect_ray(ray)
	if hit.is_empty():
		return 400.0
	return origin.y - float((hit.position as Vector3).y)


func _owning_body(node: Node) -> PhysicsBody3D:
	var cursor := node.get_parent()
	while cursor != null:
		if cursor is PhysicsBody3D:
			return cursor as PhysicsBody3D
		cursor = cursor.get_parent()
	return null


func _body_world_box(body: Node3D) -> AABB:
	var box := AABB()
	var first := true
	for candidate in body.find_children("*", "MeshInstance3D", true, false):
		var mesh_instance := candidate as MeshInstance3D
		if mesh_instance.mesh == null:
			continue
		var world_box := mesh_instance.global_transform * mesh_instance.mesh.get_aabb()
		if first:
			box = world_box
			first = false
		else:
			box = box.merge(world_box)
	return box


func _check(condition: bool, description: String) -> void:
	if condition:
		print("PASS: ", description)
	else:
		_failures.append(description)
		push_error("FAIL: " + description)


func _finish() -> void:
	if _failures.is_empty():
		print("STATION_PRESENTATION_DEFECT_WITNESS_TEST_OK")
		quit(0)
	else:
		print("STATION_PRESENTATION_DEFECT_WITNESS_TEST_FAILED: ", "; ".join(_failures))
		quit(1)
