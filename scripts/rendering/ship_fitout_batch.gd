class_name ShipFitoutBatch
extends RefCounted

## Scene-node consolidation for procedurally built *ship* fitout dressing
## (Phase 10 §2).
##
## `StationDressingBatch` does this for the station's modules. The ships need the
## same arithmetic for a different shape of subtree, so this is its sibling rather
## than a caller of it:
##
## * A ship is a moving body that is built **before** it is in the tree and
##   rebuilt by `reset_for_reuse`. Every placement here is composed from local
##   transforms only, so a batch is identical whether the craft is parked at a
##   station berth, in flight, or still detached in a builder. The station pass
##   reads `global_transform`, which is meaningless in those last two states.
## * Ship fitout is drawn stock with its material on the mesh surface rather than
##   `_box(collidable = true)` triples; ship collision is authored separately as
##   root shapes and interaction areas, and no ship fitout piece owns a body of
##   its own. There is therefore no solid-batch path here: the pass merges
##   renderers and never creates, moves, resizes or removes a collision shape, so
##   the physical craft is bit-for-bit the craft that was authored. If a fitout
##   piece ever does gain its own body it is a node with a child and this pass
##   will not touch it.
##
## A batch carries one surface per distinct source material, in first-appearance
## order, bound through `set_surface_override_material()`. Triangle count, surface
## count, material bindings and local placement are therefore all identical to the
## separate nodes; only the node and renderer counts fall.
##
## What this deliberately never does, because each of those is an indexing
## contract another system reads by node identity:
##
## * It never touches a node that carries a script, a group, an incoming signal
##   connection, a child, or a name in the protected roster its caller passes.
##   Seats, bunks, anchors, boarding routes, cargo interaction markers, damage
##   cues, hull markings, moving-interior frames, LOD bands and every
##   `MultiMeshInstance3D`/shadow batch already carry one of those, and every
##   name any script, test, tool or document resolves is in the roster.
## * Authored **metadata** no longer refuses a piece, but it does constrain the
##   group: `_render_state_key` includes a digest of every key and value, so a
##   batch only ever absorbs pieces whose metadata is identical, it carries that
##   metadata verbatim, and `AUTHORED_PIECE_INDEX_META` records each piece's own
##   copy. A reader that resolves metadata off the renderer reads the same
##   answer it read before; a value that differs between two pieces splits them
##   into separate groups rather than being averaged into one.
## * It never touches a node any live script variable can still reach. That scan
##   is the guard against freeing something the craft, its bindings or the world
##   is going to call back into.
## * It never crosses a parent boundary, so a container a ship hides, moves,
##   folds or re-parents still owns exactly the geometry it owned before.
## * It never folds a renderer that carries a visibility range, a transparency, a
##   non-default render layer, a skin or an overlay. The interior furnishing LOD
##   bands (`_configure_interior_furnishing_ranges`) are expressed as visibility
##   ranges, so this pass must run after them and leaves every banded piece
##   standing on its own.
## * It never folds a renderer whose mesh a live craft variable holds. That is
##   stock the craft may still re-seat, re-tessellate or re-bind after this pass
##   has run, and a merged copy would not follow it.
## * It **does** now fold a renderer whose mesh is merely drawn more than once.
##   That used to be refused on two grounds. Identity, which
##   `AUTHORED_PIECE_INDEX_META` restates by retaining the shared resource so
##   every `*_resource_sharing_test` reads the identity it always read; and
##   vertex storage, which is real, is paid, and is measured and published in
##   `docs/PERFORMANCE_BUDGET_SCENE_GEOMETRY.md`. Scene-tree nodes are the
##   budget this scene is 51% over, and this is the trade the roadmap
##   authorised to buy them.
## * It never folds live `PrimitiveMesh` stock, which the tree-wide geometry
##   budget sweeps and re-tessellates after the craft has built.
## * It never emits a batch whose triangle count differs from its sources'.
##
## The result is fewer scene nodes and fewer renderers for identical triangles at
## identical local transforms.

const DETERMINANT_EPSILON := 1e-6

## Marks a node this pass created.
const BATCH_META := &"ship_fitout_batch"

## What the batch replaced, in the exact currencies a ship's own render
## allocation report counts, so that report can still describe what the craft is
## *built* from.
##
## Each ship freezes a component-local allocation roster — node, renderer,
## drawn-copy, submission and unique-resource counts — and gates its suite on it.
## That roster is a statement about what the ship builds; this pass runs at the
## end of the same build over dressing the ship no longer indexes by name.
## Without this record the ship would have to either abandon the roster or
## restate it as a number that is only true while this pass is enabled. With it
## the ship adds each batch's authored row back and keeps reporting exactly what
## it built, while `get_fitout_consolidation_report()` reports what was folded.
const AUTHORED_CENSUS_META := &"ship_fitout_batch_authored_census"

## The authored names a batch stands in for, in the project's existing batch
## idiom, so an audit can still see what a merged renderer replaced.
const AUTHORED_NAMES_META := &"authored_visual_names"

## The authored pieces a batch stands in for, one record each, in authored order.
##
## `AUTHORED_NAMES_META` names them and `AUTHORED_CENSUS_META` restores their
## counts. This restores their *identity*, and it is what allows the ships'
## shared-stock families to be batched at all.
##
## Those families exist because a craft builds one cached mesh and hangs N
## renderers on it, and each craft's `*_resource_sharing_test` proves the sharing
## by comparing `a.mesh == b.mesh`. Before this record the merge could only
## answer that question by not happening: it frees the source renderers, and
## `a.mesh` afterwards is the merged buffer, so the audit had no way to reach the
## resource it was asking about. The index hands it back the same resource, so
## the identity it compares is the one it always compared, and a batched member
## proves exactly the fact an unbatched node proved.
##
## Each record carries the piece's authored name, its local placement, its own
## metadata verbatim, the untransformed bound and surface count of its mesh, the
## resolved material of every surface, and — when the mesh outlives the merge —
## the source `Mesh` resource itself. A retained reference is a stronger record
## than the instance id beside it, which names a resource that may since have
## been freed.
##
## Retention is conditional and that condition is what keeps this honest. A mesh
## only the replaced piece drew is freed exactly as before, so the unique-mesh
## count still falls by the merge's own arithmetic and nothing is retained that
## was not retained already. A mesh that is *shared* is kept, and that costs no
## memory at all, because the merge never had the right to free it.
const AUTHORED_PIECE_INDEX_META := &"ship_fitout_batch_authored_pieces"

## The meta keys this pass writes. A node carrying any of them was produced by a
## previous pass and is never folded again, because its own index would be
## absorbed into a second batch that no longer records it.
const BATCH_OWNED_META_KEYS: Array[StringName] = [
	BATCH_META,
	AUTHORED_CENSUS_META,
	AUTHORED_NAMES_META,
	AUTHORED_PIECE_INDEX_META,
	&"authored_instance_transforms",
	&"batched_source_count",
]

## A merged bound this broad and this thin, facing up, is the exact shape the
## station's route-surface discovery reads as a walkable plate. A parked craft's
## interior is a walkable surface in that sweep
## (`tools/station_walkability_sweep.gd`,
## `tests/station_surface_playability_test.gd`), and several separate fittings can
## aggregate into that shape while the space between them stays empty, so a batch
## that would produce one is refused and its sources are left alone. The numbers
## are that audit's own published thresholds.
const PLATE_MIN_BREADTH := 0.65
const PLATE_MAX_THICKNESS := 0.82

## No batch may span more than this on any axis.
##
## A merged mesh is one bounding volume, and both the walkability sweep and the
## renderer read bounding volumes: the sweep decides what is a discrete fitting,
## and the Compatibility renderer's per-object light list decides which of a
## cabin's practicals reach an instance. A batch that spanned a whole hull would
## answer both questions about volume it does not occupy. Groups are therefore
## split into locality-bounded runs, walking children in their authored order so
## a run is a contiguous stretch of what the builder emitted.
##
## Sixteen metres is the station pass's measured cap, and it was re-measured
## here rather than inherited. Four metres was captured against the same
## untrimmed build from all five walking-distance interior framings on both
## renderers: under Compatibility the Halyard crew cabin measured 3.006 mean
## |delta| of 255 at 4 m against 3.010 at 16 m -- indistinguishable -- because
## what moves under that renderer is which lights win an instance's per-object
## slots, and that ordering depends on how many instances the compartment has,
## not on how large any one of them is. Forward+, which the desktop build ships,
## is inside its own same-build noise floor at both caps. Tightening the cap buys
## nothing and costs 74 of the nodes this pass saves.
const MAX_BATCH_EXTENT := 16.0

## Components whose own audit indexes the renderers inside them.
##
## Each of these publishes an exact recursive renderer count or a per-child
## identity/recipe roster that its craft's suite gates on, so its contents are a
## contract rather than anonymous dressing. They are named here, and skipped
## whole, for the same reason the station pass leaves `VipReceptionSuite` and
## `OperationalLattice` alone.
##
## * `PilotAccessSteps` -- the Jovian freighter's fixed threshold and two folding
##   flights are audited as exactly five submitted renderers across their four
##   sub-frames (`tests/jovian_light_freighter_test.gd`).
## * `MainFrame` and `ToeFrame` -- the Jovian cargo ramp's two leaves. Their
##   edge-rail audit finds the single amber child of each frame and asserts its
##   face count and surface count exactly, which is a statement about one
##   renderer among that frame's children
##   (`tests/jovian_cargo_ramp_edge_rail_resource_sharing_test.gd`).
const PROTECTED_FITOUT_CONTAINERS: Array[String] = [
	"PilotAccessSteps",
	"MainFrame",
	"ToeFrame",
]


## Every node name any script, test, tool, scene, asset manifest or document in
## this repository can resolve, inside the eight hero/fleet craft subtrees.
##
## It was produced mechanically, not by judgement. Every anonymous-sibling
## renderer candidate in those subtrees was matched against three things, and is
## listed here if any of them hits:
##
## 1. the whole name appearing anywhere in `scripts/ tests/ tools/ docs/ scenes/
##    assets/` other than the single builder line that names it;
## 2. every name in a family a craft assembles at runtime. Ship audits build
##    paths by concatenation and formatting -- `visual.get_node(tag +
##    "WingArmor")`, `tag + "WingService" + str(station).replace(".", "_") +
##    "Gasket"`, `find_children(tag + "NacelleAccess*Gasket", ...)` -- which a
##    whole-name grep structurally cannot see. Every string a composed lookup
##    contributes is therefore taken as a fragment and listed with every
##    candidate name it occurs in;
## 3. any `find_children`/`find_child` glob in the project, expanded against the
##    name, so `*Sidewall`, `Cargo*` and `ControlStick*` protect everything they
##    could ever return.
##
## A name in this roster is never folded, so seats, bunks, anchors, consoles,
## instrument faces, hatches, route inlays, damage cues, hull markings, canopy
## hardware and every resource-sharing audit's subject keep the node identity
## their consumer looks them up by.
const PROTECTED_FITOUT_NAMES: Array[String] = [

		"DockUmbilicalHead02",  # FleetDockComb freezes its renderer/batch/copy/submission roster
	"DockUmbilicalHead03",  # FleetDockComb freezes its renderer/batch/copy/submission roster
# --- Tenth trim (2026-09-20), further pass: 63 more names. ---
	#
	# Lifting the metadata and shared-mesh refusals, and enrolling two more
	# modules, exposed leaf names that
	# earlier passes never had to grep, because some other guard had always kept
	# the pass out of them. Every one of those names was put through this
	# roster's own three criteria again -- the whole name resolved anywhere in
	# `scripts/`, `tests/`, `tools/`, `docs/`, `scenes/` or `assets/` other than
	# its own builder line; a `find_child`/`find_children` glob that matches it;
	# or a ten-character-or-longer literal some call composes a name from -- and
	# these are the ones that hit. The rest fold.
	#
	# The `*MuzzleLens` family is why this re-grep exists rather than being
	# assumed unnecessary: `HeroShip._ensure_weapon_component_emitters()` counts
	# authored lenses by that glob and *builds two fallback spheres* when it
	# finds fewer than two, so folding the Jovian's lenses silently added two
	# nodes and 336 triangles instead of failing anything.
	"ApproachFrameNorthEast",  # resolved at tests/exterior_target_range_readability_test.gd:18
	"ApproachFrameNorthWest",  # resolved at tests/exterior_target_range_readability_test.gd:21
	"ApproachFrameSouthEast",  # resolved at tests/exterior_target_range_readability_test.gd:19
	"ApproachFrameSouthWest",  # resolved at docs/ULTRAWIDE_FIELD_OF_VIEW_POLICY.md:146, tests/exterior_target_range_readability_test.gd:20
	"BlendedPressureHull",  # resolved at tests/modern_fighter_presentation_test.gd:35, tests/station_triplanar_material_test.gd:1054
	"CargoFitoutAmber",  # matches Cargo*
	"CargoFitoutCabin Liner",  # matches Cargo*
	"CargoFitoutCabin Shell",  # matches Cargo*
	"CargoFitoutDark",  # matches Cargo*
	"CargoFitoutFreight Shell",  # matches Cargo*
	"CargoFitoutHull Cool",  # matches Cargo*
	"CargoFitoutLiner",  # matches Cargo*
	"CargoFitoutStructure",  # matches Cargo*
	"CargoFitoutWebbing",  # matches Cargo*
	"CargoPressureCollar",  # resolved at tests/cinder_cargo_approach_readability_test.gd:69; matches Cargo*
	"CargoPressureJoint",  # matches Cargo*
	"CargoPressureRim",  # resolved at tests/cinder_cargo_approach_readability_test.gd:69; matches Cargo*
	"CargoThresholdHeader",  # resolved at tests/cinder_cargo_approach_readability_test.gd:63, tests/cinder_cargo_approach_readability_test.gd:67; matches Cargo*
	"CoolingVanes",  # matches *Vanes
	"DockMastLamp02",  # matches DockMast*
	"DockMastLamp03",  # matches DockMast*
	"EngineRetentionSaddles",  # resolved at tests/cinder_cargo_hauler_freight_frame_visual_test.gd:91, tests/cinder_cargo_hauler_freight_frame_visual_test.gd:94
	"FlightDeckWindscreenCowl",  # resolved at tests/jovian_light_freighter_test.gd:2199
	"ForwardCabinCrown",  # resolved at tests/jovian_light_freighter_test.gd:2076, tests/jovian_light_freighter_test.gd:2199
	"ForwardFlightDeck",  # resolved at tests/jovian_light_freighter_test.gd:1376, tests/jovian_light_freighter_test.gd:2101
	"ModernHeadrest",  # resolved at tests/zenith_interceptor_test.gd:3510
	"ModernSeatBack",  # resolved at tests/zenith_interceptor_test.gd:3510
	"ModernSeatCushion",  # resolved at tests/zenith_interceptor_test.gd:3510
	"NoseSensorRadome",  # resolved at tests/zenith_interceptor_test.gd:3647
	"PortAftGearStrut",  # matches *GearStrut,*Strut
	"PortCabinTransition",  # resolved at tests/jovian_light_freighter_test.gd:2102; composed from Port+CabinTransition
	"PortCargoShoulder",  # resolved at tests/jovian_light_freighter_test.gd:1377, tests/jovian_light_freighter_test.gd:2101
	"PortDefensiveTurretMuzzleCollar",  # matches *MuzzleCollar
	"PortDefensiveTurretMuzzleLens",  # resolved at tests/jovian_light_freighter_test.gd:525; matches *MuzzleLens
	"PortEngineCowling",  # composed from Port+EngineCowling
	"PortEngineServiceDoor",  # composed from Port+EngineServiceDoor
	"PortForwardGearStrut",  # matches *GearStrut,*Strut
	"PortFreightExhaust",  # resolved at tests/cinder_cargo_hauler_test.gd:629
	"PortFreightThermalServiceVanes",  # matches *Vanes
	"PortLowerEngineHousing",  # matches *EngineHousing
	"PortNoseCapCheek",  # composed from Port+NoseCapCheek
	"PortNoseCheek",  # composed from Port+NoseCheek
	"PortOrdnanceServiceCassette",  # composed from Port+OrdnanceServiceCassette
	"PortThermalServiceVanes",  # matches *Vanes
	"PortUpperEngineHousing",  # matches *EngineHousing
	"PortYokeBrace",  # matches *Brace
	"StarboardAftGearStrut",  # matches *GearStrut,*Strut
	"StarboardCabinTransition",  # resolved at tests/jovian_light_freighter_test.gd:2102; composed from Starboard+CabinTransition
	"StarboardDefensiveTurretMuzzleCollar",  # matches *MuzzleCollar
	"StarboardDefensiveTurretMuzzleLens",  # resolved at tests/jovian_light_freighter_test.gd:526; matches *MuzzleLens
	"StarboardEngineCowling",  # composed from Starboard+EngineCowling
	"StarboardEngineServiceDoor",  # composed from Starboard+EngineServiceDoor
	"StarboardForwardGearStrut",  # matches *GearStrut,*Strut
	"StarboardFreightExhaust",  # resolved at tests/cinder_cargo_hauler_test.gd:630
	"StarboardFreightThermalServiceVanes",  # matches *Vanes
	"StarboardLowerEngineHousing",  # matches *EngineHousing
	"StarboardNoseCapCheek",  # composed from Starboard+NoseCapCheek
	"StarboardNoseCheek",  # composed from Starboard+NoseCheek
	"StarboardOrdnanceServiceCassette",  # composed from Starboard+OrdnanceServiceCassette
	"StarboardThermalServiceVanes",  # matches *Vanes
	"StarboardUpperEngineHousing",  # matches *EngineHousing
	"StarboardYokeBrace",  # matches *Brace
	"TailYokeCap",  # resolved at tests/halyard_engine_damage_silhouette_test.gd:13
	# tests/zenith_interceptor_test.gd composes these as prefix + part at runtime,
	# which a whole-name grep cannot see; the wing-shell trio must stay addressable.
	"PortWingOuterSkin", "StarboardWingOuterSkin",
	"PortElevons", "StarboardElevons",
	"PortBlendedDeltaWing", "StarboardBlendedDeltaWing",
	"AftBayCeiling", "AftBayDeck", "AftHull", "AftPressureCap", "AftPressureWall",
	"ArmoredCentralSlab", "ArmoredNose", "ArrayCrossbar", "AttitudeLadder00",
	"AttitudeLadder01", "AttitudeLadder02", "AttitudeLadder03", "AttitudeLadder04",
	"AvionicsCartridge", "BeltAntiSub", "BinnacleAndControls", "BowDockingArchSegment01",
	"BowDockingArchSegment03", "BowDockingArchStrut00", "BowDockingArchStrut01",
	"BowDockingTargetPlate", "CabinCeiling", "CabinDeck", "CabinFoldingTable",
	"CabinLightStrip", "CabinPortalUpright", "CabinSidewall", "CabinStatusPanel",
	"CableRaceway0", "Canopy", "CanopyNosePressureSeal", "CanopyPressureFrame",
	"CanopyRearFrame", "CanopyRearPressureSeal", "CargoApertureUpright",
	"CargoBoardingLamp", "CargoContainerPort00", "CargoContainerPort01",
	"CargoContainerStarboard00", "CargoContainerStarboard01", "CargoCornerTie-1_0-1_0",
	"CargoCornerTie-1_01_0", "CargoCornerTie1_0-1_0", "CargoCornerTie1_01_0", "CargoDeck",
	"CargoEntrySill", "CargoPalletPort00", "CargoPalletPort01", "CargoPalletStarboard00",
	"CargoPalletStarboard01", "CargoPod", "CargoRampActuator", "CargoRampActuatorRod",
	"CargoRampToe", "CargoRestraintPort0000", "CargoRestraintPort0001",
	"CargoRestraintPort0100", "CargoRestraintPort0101", "CargoRestraintStarboard0000",
	"CargoRestraintStarboard0001", "CargoRestraintStarboard0100",
	"CargoRestraintStarboard0101", "CenterlineArmorSpine", "ChinArmor", "CoPilotConsole",
	"CoPilotHarness", "CoPilotHeadrest", "CoPilotSeatBack", "CoPilotSeatBase",
	"CoPilotSystemsDisplay", "CockpitConnectorDeck", "CockpitFloor",
	"CockpitPressureTransition", "CockpitSillFairing", "CockpitSupportFairing",
	"CompactGraphiteShroud", "CompressionBow", "ContainerCornerStarboard00",
	"ContainerCornerStarboard01", "ContainerDataPlateStarboard00",
	"ContainerDataPlateStarboard01", "ContainerRecessStarboard00",
	"ContainerRecessStarboard01", "ContinuousFreightLoadFrame", "ControlStickBoot",
	"ControlStickGimbal", "ControlStickGrip", "ControlStickShaft", "CopilotSeatBase",
	"CurveJoint", "CyanMuzzleLens", "DamageScorch", "DisplayBezelBottom",
	"DisplayBezelTop", "EngineBreachScorch", "EngineCollar", "EngineIsolationBlade",
	"ExposedDamageVane", "ExposedWingSpar", "FlightDeckQuarterlightSeal",
	"FlightDeckWindscreenSeal", "FlushPassiveAperture", "ForwardBulkheadHeader",
	"ForwardBulkheadWing", "ForwardOpticalWindow", "ForwardPressureCap",
	"ForwardPressureWall", "FreighterPressureWindscreen", "FuselagePanelBand",
	"GunnerConsole", "GunnerConsolePedestal", "GunnerDisplay", "GunnerHeadrest",
	"GunnerHeadrestShell", "GunnerLumbarCushion", "GunnerRearSplinterShield", "GunnerSeat",
	"GunnerSeatBack", "GunnerSeatPanShell", "GunnerSeatShell", "Harness", "HarnessBuckle",
	"Headrest", "HeadrestShell", "HighVisibilityHull", "IndustrialHull", "InstrumentHood",
	"LadderStock", "LandingBogieStrut", "LandingDamper", "LapBeltLeft", "LapBeltRight",
	"LightPulseBarrel", "LockerDisplay", "LongRangeHull", "LongRangeSensor",
	"LongRangeTailplane", "MainGearFoot", "MainGearStrut", "MastPedestal", "MastStem",
	"NoseBelly", "NoseCapBelly", "NoseGearDamper", "NoseGearFoot", "NoseGearStrut",
	"OpaqueEnvelopeShadowBatch", "OpticalRecess", "OrdnanceSpine", "Overlay",
	"PassengerDeck", "PassengerRoof", "PilotDoorFrame", "PilotDoorGlass", "PilotDoorJamb",
	"PodSeparationCollar", "PodStatusLight", "PortAftBaySidewall", "PortBlendedDeltaWing",
	"PortBomberFin", "PortCannonMount", "PortCanopyLaminateEdge", "PortCanopyLatchHook",
	"PortCanopyLatchStriker", "PortCanopyLowerPressureSeal", "PortCanopyLowerRail",
	"PortCanopyNoseFrame", "PortCanopyRearUpright", "PortCanopyTopRail", "PortCargoRamp",
	"PortChamberBack", "PortCockpitSill", "PortCombustorAnnulus", "PortConsoleKey00",
	"PortConsoleKey01", "PortConsoleKey02", "PortConsoleRotary", "PortConsoleToggle00",
	"PortConsoleToggle01", "PortConsoleToggle02", "PortConsoleToggle03",
	"PortDisplayBezelSide", "PortEngineBoom", "PortEngineShroud", "PortExhaustBell",
	"PortGearDamper", "PortHatchDoor", "PortHatchDoorSeal", "PortIntakeLip",
	"PortIntakeShoulder", "PortLowerEngineCollar", "PortLowerEngineCollarRecessedThroat",
	"PortLowerEngineCore", "PortMuzzleBore", "PortNacelleAccess4_15Gasket",
	"PortNacelleAccess4_15Panel", "PortNacelleAccess5_15Gasket",
	"PortNacelleAccess5_15Panel", "PortNavigationLamp", "PortNavigationLight",
	"PortNozzleLip", "PortPressureShoulder", "PortRadiator", "PortRecessedThroat",
	"PortRefractoryNozzle", "PortRootServiceGasket", "PortRootServicePanel",
	"PortRudderPedal", "PortSeatBolster", "PortSensorWingSkin0", "PortSensorWingSkin1",
	"PortSensorWingSkin2", "PortShoulderSupport", "PortSideConsole", "PortSidewall",
	"PortSill", "PortStatusRepeater", "PortSurveyRecognitionMark", "PortThrustPlug",
	"PortUpperEngineCollar", "PortUpperEngineCollarRecessedThroat", "PortUpperEngineCore",
	"PortWingArmor", "PortWingInset", "PortWingOuterSkin", "PortWingService-0_2Gasket",
	"PortWingService-0_2Panel", "PortWingService0_6Gasket", "PortWingService0_6Panel",
	"PortWingService1_4Gasket", "PortWingService1_4Panel", "PressureCoverGasket",
	"PrimaryFlightDisplay", "RaisedBreachVane", "RapidResponseWing", "RearPressureWall",
	"RecessedGraphiteMount", "RepairWorkLamp", "RoofService-3_6Gasket",
	"RoofService3_7Gasket", "SeatBack", "SeatBackShell", "SeatBase", "SeatHeadrest",
	"SeatPan", "SeatPanShell", "Segment00", "Segment01", "Segment02", "Segment03",
	"ServicePocketLiner", "ShoulderBeltLeft", "ShoulderBeltRight", "ShoulderBreachScorch",
	"StarboardAftBaySidewall", "StarboardBlendedDeltaWing", "StarboardBomberFin",
	"StarboardCabinSidewall", "StarboardCannonMount", "StarboardCanopyLaminateEdge",
	"StarboardCanopyLatchHook", "StarboardCanopyLatchStriker",
	"StarboardCanopyLowerPressureSeal", "StarboardCanopyLowerRail",
	"StarboardCanopyNoseFrame", "StarboardCanopyRearUpright", "StarboardCanopyTopRail",
	"StarboardChamberBack", "StarboardCockpitSill", "StarboardCombustorAnnulus",
	"StarboardConsoleKey00", "StarboardConsoleKey01", "StarboardConsoleKey02",
	"StarboardConsoleRotary", "StarboardConsoleToggle00", "StarboardConsoleToggle01",
	"StarboardConsoleToggle02", "StarboardConsoleToggle03", "StarboardDisplayBezelSide",
	"StarboardDisplayFoot", "StarboardEngineAccess-1_1Gasket",
	"StarboardEngineAccess-1_1Panel", "StarboardEngineAccess0_2Gasket",
	"StarboardEngineAccess0_2Panel", "StarboardEngineAccess4_85Gasket",
	"StarboardEngineAccess4_85Panel", "StarboardEngineBoom", "StarboardEngineShroud",
	"StarboardExhaustBell", "StarboardGearDamper", "StarboardGunnerControlCheek",
	"StarboardGunnerControlGrip", "StarboardGunnerGripMount",
	"StarboardGunnerHeadrestPost", "StarboardGunnerReclinePivot",
	"StarboardGunnerSeatRail", "StarboardGunnerShoulderSupport",
	"StarboardGunnerThighSupport", "StarboardInnerWall", "StarboardIntakeLip",
	"StarboardIntakeShoulder", "StarboardLowerEngineCollar",
	"StarboardLowerEngineCollarRecessedThroat", "StarboardLowerEngineCore",
	"StarboardMuzzleBore", "StarboardNacelleAccess4_15Gasket",
	"StarboardNacelleAccess4_15Panel", "StarboardNacelleAccess5_15Gasket",
	"StarboardNacelleAccess5_15Panel", "StarboardNavigationLamp",
	"StarboardNavigationLight", "StarboardNozzleLip", "StarboardOutboardArmor",
	"StarboardOutboardSkirt", "StarboardPressureShoulder", "StarboardRadiator",
	"StarboardRecessedThroat", "StarboardRefractoryNozzle", "StarboardRootServiceGasket",
	"StarboardRootServicePanel", "StarboardRudderPedal", "StarboardSeatBolster",
	"StarboardSeatRail", "StarboardSeatReclinePivot", "StarboardSeatShellReturn",
	"StarboardSensorWingSkin0", "StarboardSensorWingSkin1", "StarboardSensorWingSkin2",
	"StarboardShoulderSupport", "StarboardSideConsole", "StarboardSidewall",
	"StarboardSill", "StarboardSkirtClamp-0_3", "StarboardSkirtClamp1_46",
	"StarboardStatusRepeater", "StarboardSurveyRecognitionMark", "StarboardThrustPlug",
	"StarboardTurbineCase", "StarboardUpperEngineCollar",
	"StarboardUpperEngineCollarRecessedThroat", "StarboardUpperEngineCore",
	"StarboardWallLiner00", "StarboardWallLiner01", "StarboardWallLiner02",
	"StarboardWallLiner03", "StarboardWindowSill", "StarboardWingArmor",
	"StarboardWingInset", "StarboardWingOuterSkin", "StarboardWingRootFairing",
	"StarboardWingService-0_2Gasket", "StarboardWingService-0_2Panel",
	"StarboardWingService0_6Gasket", "StarboardWingService0_6Panel",
	"StarboardWingService1_4Gasket", "StarboardWingService1_4Panel", "SurveyFrontAperture",
	"SurveyServiceCovers", "SurveyServiceGasket", "SurveyServiceLatches", "Throttle",
	"ThrottleGate", "ThrottlePalmGrip", "VentralKeel", "VentralSensorGimbal",
	"VentralSensorLens", "WarningStrip",
]


## One consolidation pass over each root in `roots`.
##
## Roots that are null or already freed are skipped, so a caller can hand over
## the compartments it may or may not have built. `protected` names are never
## folded, at any depth. `reference_root` is the widest node whose script
## variables must be scanned before anything is freed; pass the craft itself when
## it is still detached, or the scene root once it is in the tree. Returns a
## report with the exact node arithmetic so a caller or test can assert it.
static func consolidate(
		roots: Array,
		protected: Array,
		reference_root: Node
	) -> Dictionary:
	var report := _empty_report(&"consolidated")
	if reference_root == null or not is_instance_valid(reference_root):
		report["reason"] = &"reference_root_unavailable"
		return report
	var referenced := _collect_script_referenced_objects(reference_root)
	var shared := _collect_shared_mesh_resources(reference_root, referenced)
	var mesh_uses := count_mesh_uses(reference_root)
	var protected_set := {}
	for name_value in protected:
		protected_set[String(name_value)] = true
	var applied := false
	for root_variant in roots:
		var root := root_variant as Node3D
		if not is_instance_valid(root):
			continue
		applied = true
		var parents: Array[Node] = []
		_collect_parents(root, parents)
		for parent in parents:
			_consolidate_parent(
				parent as Node3D, protected_set, referenced, shared, mesh_uses, report
			)
	report["applied"] = applied
	if not applied:
		report["reason"] = &"no_root_available"
	return report


static func _empty_report(reason: StringName) -> Dictionary:
	return {
		"applied": false,
		"reason": reason,
		"removed_nodes": 0,
		"added_nodes": 0,
		"visual_batches": 0,
		"visual_sources": 0,
	}


## Every `Node3D` under `node` that may host a batch.
##
## A protected container and its whole subtree are skipped. Those components
## publish a frozen renderer roster of their own -- an exact recursive count, a
## per-child identity check, or both -- so folding inside one is a change to that
## component's indexing contract rather than to anonymous dressing, and no audit
## is relaxed here to buy nodes.
static func _collect_parents(node: Node, out: Array[Node]) -> void:
	if PROTECTED_FITOUT_CONTAINERS.has(String(node.name)):
		return
	if node is Node3D:
		out.append(node)
	for child in node.get_children():
		_collect_parents(child, out)


static func _consolidate_parent(
		parent: Node3D,
		protected_set: Dictionary,
		referenced: Dictionary,
		shared: Dictionary,
		mesh_uses: Dictionary,
		report: Dictionary
	) -> void:
	if parent == null or not is_instance_valid(parent):
		return
	# Sibling order is the authored order; grouping keeps it so a merged mesh
	# emits its surfaces in the same sequence the separate nodes submitted them.
	var groups := {}
	for child in parent.get_children():
		if child is MultiMeshInstance3D or not (child is MeshInstance3D):
			continue
		var visual := child as MeshInstance3D
		if not _node_is_free_standing(visual, protected_set, referenced):
			continue
		if not _mesh_is_mergeable(visual, shared):
			continue
		var key := _render_state_key(visual)
		if not groups.has(key):
			groups[key] = []
		(groups[key] as Array).append(visual)
	for key in groups:
		for visuals in _local_chunks(groups[key] as Array):
			if visuals.size() < 2:
				continue
			if _build_visual_batch(parent, visuals, mesh_uses):
				report["visual_batches"] = int(report["visual_batches"]) + 1
				report["visual_sources"] = int(report["visual_sources"]) + visuals.size()
				report["removed_nodes"] = int(report["removed_nodes"]) + visuals.size()
				report["added_nodes"] = int(report["added_nodes"]) + 1


## Every mesh resource a live script variable still holds.
##
## This is the half of the old shared-mesh guard that still refuses. A mesh a
## craft variable holds is stock the craft may still re-seat, re-tessellate or
## re-bind after this pass has run, and a merged copy would not follow it. That
## is a live dependency rather than a contract about identity, so no index can
## restate it and a renderer drawing such a mesh is left exactly as it stands.
##
## The other half — a mesh simply drawn by more than one renderer — used to
## refuse for two reasons. The first was identity: merging dissolved the
## shared-resource identity each craft's `*_resource_sharing_test` proves.
## `AUTHORED_PIECE_INDEX_META` now retains that exact resource, so the audits
## read the identity they always read and none of them is weakened; the roadmap
## authorised this restatement as a deliberate contract change. The second was
## storage, and that one is real and is *paid*: N renderers of one mesh become
## one renderer of a buffer holding N copies of that geometry, so vertex storage
## for those families rises by roughly the geometry the sharing avoided. It is
## bought deliberately, for scene-tree nodes, which is the budget this scene is
## 51% over while its triangle count is 5%. The cost is measured and published
## in `docs/PERFORMANCE_BUDGET_SCENE_GEOMETRY.md` rather than absorbed quietly,
## and the mesh itself is never freed, so the sharing the families were built
## for still holds for every copy that kept its own node.
static func _collect_shared_mesh_resources(root: Node, referenced: Dictionary) -> Dictionary:
	var held := {}
	for object_id in referenced:
		held[object_id] = true
	return held


## How many renderers under `root` draw each mesh resource.
##
## The piece index uses this to decide whether a merge may let a source mesh go:
## a mesh drawn once is the merge's to free, a mesh drawn more than once is
## shared stock the merge never owned and the index keeps the resource.
static func count_mesh_uses(root: Node) -> Dictionary:
	var counts := {}
	_count_mesh_uses(root, counts)
	return counts


static func _count_mesh_uses(node: Node, counts: Dictionary) -> void:
	var visual := node as MeshInstance3D
	if visual != null and visual.mesh != null:
		var id := visual.mesh.get_instance_id()
		counts[id] = int(counts.get(id, 0)) + 1
	var multi := node as MultiMeshInstance3D
	if multi != null and multi.multimesh != null and multi.multimesh.mesh != null:
		var multi_id := multi.multimesh.mesh.get_instance_id()
		counts[multi_id] = int(counts.get(multi_id, 0)) + 1
	for child in node.get_children():
		_count_mesh_uses(child, counts)


## The render state a batch must reproduce exactly, as a grouping key.
##
## Shadow casting and GI mode are the station pass's key. The LOD fields are
## belt-and-braces: `_mesh_is_mergeable` already refuses any renderer that
## carries a camera-distance band, so every member of a group reads zero here,
## and the key makes it impossible for a later change to that refusal to put two
## different bands in one batch by accident.
## The metadata digest is part of the key so a batch only ever absorbs pieces
## whose metadata is identical key for key and value for value. That is what
## lets the batch carry the group's metadata verbatim and still answer a
## metadata question the way each piece answered it; a value that differs splits
## the group instead of being averaged into one.
static func _render_state_key(visual: MeshInstance3D) -> String:
	return "%d|%d|%f|%f|%f|%f|%d|%f|%s" % [
		int(visual.cast_shadow),
		int(visual.gi_mode),
		visual.visibility_range_begin,
		visual.visibility_range_begin_margin,
		visual.visibility_range_end,
		visual.visibility_range_end_margin,
		int(visual.visibility_range_fade_mode),
		visual.lod_bias,
		_metadata_digest(visual),
	]


## Whether `node` carries a meta key this pass itself writes.
static func _carries_batch_metadata(node: Node) -> bool:
	for key in BATCH_OWNED_META_KEYS:
		if node.has_meta(key):
			return true
	return false


## A node's metadata as a stable string, so two pieces group together only when
## every key *and* every value matches.
##
## `var_to_str` rather than `hash()`, because a hash collision would let two
## different values share a group, which is the mistake this guard exists to
## prevent. Keys are sorted so authoring order cannot split a group.
static func _metadata_digest(node: Node) -> String:
	var keys := node.get_meta_list()
	if keys.is_empty():
		return ""
	var names := PackedStringArray()
	for key in keys:
		names.append(String(key))
	names.sort()
	var parts := PackedStringArray()
	for name_value in names:
		parts.append("%s=%s" % [
			name_value, var_to_str(node.get_meta(StringName(name_value)))
		])
	return "|".join(parts)


static func _metadata_of(node: Node) -> Dictionary:
	var out := {}
	for key in node.get_meta_list():
		out[String(key)] = node.get_meta(key)
	return out


static func _apply_render_state(batch: MeshInstance3D, source: MeshInstance3D) -> void:
	batch.cast_shadow = source.cast_shadow
	batch.gi_mode = source.gi_mode
	batch.visibility_range_begin = source.visibility_range_begin
	batch.visibility_range_begin_margin = source.visibility_range_begin_margin
	batch.visibility_range_end = source.visibility_range_end
	batch.visibility_range_end_margin = source.visibility_range_end_margin
	batch.visibility_range_fade_mode = source.visibility_range_fade_mode
	batch.lod_bias = source.lod_bias


## Splits one same-render-state group into runs that each stay inside
## `MAX_BATCH_EXTENT` on every axis.
static func _local_chunks(sources: Array) -> Array:
	var chunks: Array = []
	var current: Array = []
	var bounds := AABB()
	for source_variant in sources:
		var box := _source_bounds_in_parent(source_variant as MeshInstance3D)
		if current.is_empty():
			current = [source_variant]
			bounds = box
			continue
		var merged := bounds.merge(box)
		if merged.size.x > MAX_BATCH_EXTENT \
				or merged.size.y > MAX_BATCH_EXTENT \
				or merged.size.z > MAX_BATCH_EXTENT:
			chunks.append(current)
			current = [source_variant]
			bounds = box
			continue
		current.append(source_variant)
		bounds = merged
	if not current.is_empty():
		chunks.append(current)
	return chunks


## Where a source's drawn volume sits in its own parent's space. Local only: a
## craft that is detached, in flight or mid-rebuild has no meaningful global
## transform, and the answer must not depend on which of those it is.
static func _source_bounds_in_parent(visual: MeshInstance3D) -> AABB:
	if visual == null or visual.mesh == null:
		return AABB(visual.position if visual != null else Vector3.ZERO, Vector3.ZERO)
	return visual.transform * visual.mesh.get_aabb()


## A node nothing else can be holding on to: no script, no metadata, no group,
## no incoming signal, no children, not owned by a packed scene, and not
## reachable from any script variable.
static func _node_is_free_standing(
		node: Node,
		protected_set: Dictionary,
		referenced: Dictionary
	) -> bool:
	if node == null or not is_instance_valid(node):
		return false
	if protected_set.has(String(node.name)):
		return false
	if node.get_script() != null:
		return false
	if _carries_batch_metadata(node):
		return false
	if not node.get_groups().is_empty():
		return false
	if node.get_child_count() != 0:
		return false
	if _has_node_driven_connection(node):
		return false
	if node.owner != null:
		return false
	if referenced.has(node.get_instance_id()):
		return false
	return true


## Whether another *node* drives this one through a signal.
##
## Every `MeshInstance3D` that owns a mesh carries engine-internal connections
## from that resource's `changed` signal, so "no incoming connection at all" is
## never true for a renderer. What matters is whether some other node in the
## scene is wired to this one, because that is a live dependency the merge would
## break.
static func _has_node_driven_connection(node: Node) -> bool:
	for connection in node.get_incoming_connections():
		var source_signal := connection.get("signal") as Signal
		if source_signal == null:
			continue
		if source_signal.get_object() is Node:
			return true
	for signal_info in node.get_signal_list():
		for connection in node.get_signal_connection_list(signal_info["name"]):
			var callable_value := connection.get("callable") as Callable
			if callable_value != null and callable_value.get_object() != null:
				return true
	return false


## One ordinary opaque triangle renderer with a resolvable material on every
## surface, drawn on the default layer with no fade, LOD band or skin.
static func _mesh_is_mergeable(visual: MeshInstance3D, shared: Dictionary) -> bool:
	if not is_instance_valid(visual) or visual.get_child_count() != 0:
		return false
	if visual.mesh != null and shared.has(visual.mesh.get_instance_id()):
		return false
	if not visual.visible:
		return false
	if visual.skin != null or visual.material_overlay != null:
		return false
	if visual.layers != 1:
		return false
	if not is_zero_approx(visual.transparency):
		return false
	if not is_zero_approx(visual.visibility_range_begin) \
			or not is_zero_approx(visual.visibility_range_end):
		return false
	if not visual.visibility_parent.is_empty():
		return false
	if not is_zero_approx(visual.extra_cull_margin):
		return false
	if visual.gi_mode != GeometryInstance3D.GI_MODE_DISABLED \
			and visual.gi_mode != GeometryInstance3D.GI_MODE_STATIC:
		return false
	var mesh := visual.mesh
	if mesh == null or mesh.get_surface_count() < 1:
		return false
	# Turned and swept stock stays a live `PrimitiveMesh`. `TorusGeometryBudget`
	# and the sign budget sweep the finished tree and re-tessellate exactly those
	# renderers from their own radius, and only while the recipe is still a
	# primitive: baking one into a merged `ArrayMesh` takes it out of that sweep
	# and freezes it at the segment count it happened to be authored with. The
	# Bulwark's cockpit gimbal measured +112 triangles that way. Primitive stock
	# is therefore never folded.
	var array_mesh := mesh as ArrayMesh
	if array_mesh == null:
		return false
	if array_mesh.get_blend_shape_count() != 0 or array_mesh.shadow_mesh != null:
		return false
	for surface_index in mesh.get_surface_count():
		if array_mesh.surface_get_primitive_type(surface_index) != Mesh.PRIMITIVE_TRIANGLES:
			return false
		if _surface_material(visual, surface_index) == null:
			return false
	if visual.transform.basis.determinant() <= DETERMINANT_EPSILON:
		return false
	return true


## The material this renderer actually draws `surface_index` with, in Godot's own
## precedence: instance override, then per-surface override, then the surface's
## own material.
static func _surface_material(visual: MeshInstance3D, surface_index: int) -> Material:
	if visual.material_override != null:
		return visual.material_override
	var surface_override := visual.get_surface_override_material(surface_index)
	if surface_override != null:
		return surface_override
	if visual.mesh == null:
		return null
	return visual.mesh.surface_get_material(surface_index)


## Copies the group's shared metadata onto the batch that replaces it.
static func _seat_shared_metadata(batch: Node, metadata: Dictionary) -> void:
	for key in metadata:
		batch.set_meta(StringName(String(key)), metadata[key])


## One index record per authored piece a batch is about to replace.
##
## `names`, `offsets` and `metadata` run parallel to `sources`. `mesh_uses`
## decides retention: a mesh another renderer also draws is kept in the record,
## a mesh only this piece drew is recorded by id and left for the merge to free.
static func _build_piece_index(
		names: PackedStringArray,
		sources: Array[MeshInstance3D],
		offsets: Array[Transform3D],
		metadata: Array[Dictionary],
		mesh_uses: Dictionary
	) -> Array:
	var index: Array = []
	for position in sources.size():
		var source := sources[position]
		var mesh := source.mesh
		var materials: Array[Material] = []
		var surfaces := 0
		if mesh != null:
			surfaces = mesh.get_surface_count()
			for surface_index in surfaces:
				materials.append(_surface_material(source, surface_index))
		var record := {
			"name": names[position],
			"transform": offsets[position],
			"local_transform": source.transform,
			"metadata": metadata[position],
			"materials": materials,
			"surfaces": surfaces,
			"visible": source.visible,
			"cast_shadow": int(source.cast_shadow),
			"gi_mode": int(source.gi_mode),
			"mesh_id": mesh.get_instance_id() if mesh != null else 0,
			"aabb": mesh.get_aabb() if mesh != null else AABB(),
			"material_override": source.material_override,
		}
		if mesh != null and int(mesh_uses.get(mesh.get_instance_id(), 0)) > 1:
			record["mesh"] = mesh
			record["mesh_retained"] = true
		else:
			record["mesh_retained"] = false
		index.append(record)
	return index


## The authored pieces `node` stands in for, or an empty array for anything this
## pass did not create.
static func authored_piece_index(node: Node) -> Array:
	if node == null or not is_instance_valid(node) \
			or not node.has_meta(AUTHORED_PIECE_INDEX_META):
		return []
	return node.get_meta(AUTHORED_PIECE_INDEX_META) as Array


## The authored piece named `piece_name` under `search_root`, whether it still
## stands as its own node or has been folded into a batch.
##
## This is the indexing contract in one call: an audit asks one question and
## gets the same answer on a batched and an unbatched build. Empty when nothing
## of that name was built; otherwise `batched`, `node` (the piece, or the batch
## standing in for it), `name`, `transform`, `metadata`, `materials`,
## `material_override`, `surfaces`, `visible`, `cast_shadow`, `gi_mode`, `aabb`,
## `mesh_id`, and `mesh` whenever that resource is still alive — always for a
## live node, and for a batched piece exactly when the mesh was shared.
##
## A live node of that name always wins over an index record: a piece that kept
## its own node is the stronger answer to the same question.
static func find_authored_piece(search_root: Node, piece_name: String) -> Dictionary:
	if search_root == null or not is_instance_valid(search_root):
		return {}
	if search_root is MeshInstance3D and String(search_root.name) == piece_name:
		return _live_piece_record(search_root as MeshInstance3D)
	for candidate in search_root.find_children(piece_name, "MeshInstance3D", true, false):
		return _live_piece_record(candidate as MeshInstance3D)
	var holders := search_root.find_children("*", "", true, false)
	holders.append(search_root)
	for holder in holders:
		for record_variant in authored_piece_index(holder):
			var record := record_variant as Dictionary
			if String(record.get("name", "")) != piece_name:
				continue
			var resolved := record.duplicate()
			resolved["batched"] = true
			resolved["node"] = holder
			return resolved
	return {}


static func _live_piece_record(visual: MeshInstance3D) -> Dictionary:
	var mesh := visual.mesh
	var materials: Array[Material] = []
	var surfaces := 0
	if mesh != null:
		surfaces = mesh.get_surface_count()
		for surface_index in surfaces:
			materials.append(_surface_material(visual, surface_index))
	return {
		"batched": false,
		"node": visual,
		"name": String(visual.name),
		"transform": visual.transform,
		"local_transform": visual.transform,
		"metadata": _metadata_of(visual),
		"materials": materials,
		"material_override": visual.material_override,
		"surfaces": surfaces,
		"visible": visual.visible,
		"cast_shadow": int(visual.cast_shadow),
		"gi_mode": int(visual.gi_mode),
		"mesh": mesh,
		"mesh_id": mesh.get_instance_id() if mesh != null else 0,
		"mesh_retained": true,
		"aabb": mesh.get_aabb() if mesh != null else AABB(),
	}


## The mesh resource authored piece `piece_name` is drawn from, or `null`.
##
## A `*_resource_sharing_test` compares this between two pieces exactly as it
## used to compare `a.mesh == b.mesh`, and gets the identical answer whether
## either piece is still a node or has been folded into a batch. `null` means
## the piece is unknown, or that it was batched and its mesh was private to it —
## never that sharing has quietly stopped being proven, because a mesh that was
## shared is always retained.
static func authored_piece_mesh(search_root: Node, piece_name: String) -> Mesh:
	var record := find_authored_piece(search_root, piece_name)
	if record.is_empty():
		return null
	return record.get("mesh", null) as Mesh


## Replaces N sibling renderers with one merged renderer in the same parent.
static func _build_visual_batch(
		parent: Node3D,
		visuals: Array,
		mesh_uses: Dictionary = {}
	) -> bool:
	var sources: Array[MeshInstance3D] = []
	var offsets: Array[Transform3D] = []
	var authored_names := PackedStringArray()
	var piece_metadata: Array[Dictionary] = []
	for visual_variant in visuals:
		var visual := visual_variant as MeshInstance3D
		sources.append(visual)
		offsets.append(visual.transform)
		authored_names.append(String(visual.name))
		piece_metadata.append(_metadata_of(visual))
	var merged := _merge(sources, offsets)
	if merged.is_empty() or _reads_as_walkable_plate(merged["mesh"] as ArrayMesh):
		return false
	var newly_reachable := false
	for entry in piece_metadata:
		if not entry.is_empty():
			newly_reachable = true
			break
	if not newly_reachable:
		for source in sources:
			if source.mesh != null \
					and int(mesh_uses.get(source.mesh.get_instance_id(), 0)) > 1:
				newly_reachable = true
				break
	if _manufactures_standing_solid(
			merged["mesh"] as ArrayMesh, sources, offsets, newly_reachable
		):
		return false
	# The merge must be triangle-for-triangle, counted the way the production
	# census counts: index triples where a surface is indexed, vertex triples
	# where it is not. A source that does not survive that arithmetic is left
	# standing rather than silently redrawn.
	if _triangle_count(merged["mesh"] as Mesh) != _source_triangle_count(sources):
		return false
	var first := visuals[0] as MeshInstance3D
	var batch := MeshInstance3D.new()
	batch.name = _batch_name(parent)
	batch.mesh = merged["mesh"] as ArrayMesh
	_apply_render_state(batch, first)
	batch.set_meta(&"authored_instance_transforms", offsets.duplicate())
	batch.set_meta(AUTHORED_NAMES_META, authored_names)
	batch.set_meta(BATCH_META, true)
	batch.set_meta(&"batched_source_count", visuals.size())
	# The group's metadata is identical across every member by construction, so
	# the batch carries it verbatim and a reader that resolves metadata off the
	# renderer reads exactly what it read before. Seated before the batch-owned
	# keys, which an authored key must never be able to overwrite.
	_seat_shared_metadata(batch, piece_metadata[0] if not piece_metadata.is_empty() else {})
	batch.set_meta(AUTHORED_CENSUS_META, _authored_census(sources))
	batch.set_meta(
		AUTHORED_PIECE_INDEX_META,
		_build_piece_index(authored_names, sources, offsets, piece_metadata, mesh_uses)
	)
	parent.add_child(batch)
	_apply_surface_materials(batch, merged["materials"] as Array)
	for visual_variant in visuals:
		var visual := visual_variant as MeshInstance3D
		var holder := visual.get_parent()
		if holder != null:
			holder.remove_child(visual)
		visual.queue_free()
	return true


## A merge may be as tall as its tallest piece and no taller.
##
## `_reads_as_walkable_plate` refuses an aggregate that would read as a *floor*
## to the station's route-surface discovery. This refuses the other shape the
## same sweep blames: `tools/station_walkability_sweep.gd` reports
## `walk_through` for any rendered piece at least `SWEEP_PIECE_HEIGHT` tall
## standing on a walkable cell with no collider anywhere in its volume, and a
## parked craft's interior is a walkable surface in that sweep. Ship fitout
## carries no colliders of its own, so a stack of short fittings merged into one
## tall bound is exactly that defect, even though the air between them is still
## air. A merged bound taller than its own tallest source is manufacturing
## occupancy and is refused.
const SWEEP_PIECE_HEIGHT := 0.4
const AGGREGATE_HEIGHT_TOLERANCE := 0.002


static func _manufactures_standing_solid(
		mesh: ArrayMesh,
		sources: Array[MeshInstance3D],
		offsets: Array[Transform3D],
		newly_reachable: bool
	) -> bool:
	# Scoped to the groups this trim newly reaches. Every batch the shipped pass
	# already formed was measured against the sweep by the trim that introduced
	# it, and re-refusing those costs 136 nodes to re-litigate findings that
	# were already clean. The rule exists so that *relaxing* a refusal cannot
	# manufacture a standing solid, not to re-open settled ground.
	if not newly_reachable:
		return false
	if mesh == null:
		return false
	var merged_height := mesh.get_aabb().size.y
	if merged_height < SWEEP_PIECE_HEIGHT:
		return false
	# If any source already stood that tall, the sweep already had a piece of
	# flaggable height here and the merge manufactures nothing. The refusal is
	# only for a run of individually short pieces whose aggregate crosses the
	# threshold for the first time.
	for index in sources.size():
		var source_mesh := sources[index].mesh
		if source_mesh == null:
			continue
		if (offsets[index] * source_mesh.get_aabb()).size.y \
				>= SWEEP_PIECE_HEIGHT - AGGREGATE_HEIGHT_TOLERANCE:
			return false
	return true


## Triangles a mesh draws, counted exactly as `tools/geometry_census.gd` counts
## them so the two can be compared directly.
static func _triangle_count(mesh: Mesh) -> int:
	if mesh == null:
		return 0
	var array_mesh := mesh as ArrayMesh
	var total := 0
	for surface_index in mesh.get_surface_count():
		if array_mesh != null \
				and array_mesh.surface_get_primitive_type(surface_index) != Mesh.PRIMITIVE_TRIANGLES:
			continue
		var arrays := mesh.surface_get_arrays(surface_index)
		if arrays.is_empty():
			continue
		var indices = arrays[Mesh.ARRAY_INDEX]
		if indices != null and indices.size() > 0:
			total += indices.size() / 3
			continue
		var vertices = arrays[Mesh.ARRAY_VERTEX]
		if vertices != null:
			total += vertices.size() / 3
	return total


static func _source_triangle_count(sources: Array[MeshInstance3D]) -> int:
	var total := 0
	for source in sources:
		total += _triangle_count(source.mesh)
	return total


## The render census of the nodes a batch is about to replace.
##
## Resource identities are recorded rather than the resources themselves: a
## ship's report counts *distinct* meshes and materials, and holding the source
## meshes alive here would give back the memory the merge just freed. Godot's
## object ids are monotonic, so a recorded id is never a live resource other than
## the one it names.
static func _authored_census(sources: Array[MeshInstance3D]) -> Dictionary:
	var submissions := 0
	var drawn_copies := 0
	var mesh_ids := PackedInt64Array()
	var material_ids := PackedInt64Array()
	var override_material_ids := PackedInt64Array()
	for source in sources:
		var mesh := source.mesh
		if mesh == null:
			continue
		submissions += mesh.get_surface_count()
		drawn_copies += 1 if source.visible else 0
		if not mesh_ids.has(mesh.get_instance_id()):
			mesh_ids.append(mesh.get_instance_id())
		if source.material_override != null \
				and not override_material_ids.has(source.material_override.get_instance_id()):
			override_material_ids.append(source.material_override.get_instance_id())
		for surface_index in mesh.get_surface_count():
			var material := _surface_material(source, surface_index)
			if material != null and not material_ids.has(material.get_instance_id()):
				material_ids.append(material.get_instance_id())
	return {
		"descendant_nodes": sources.size(),
		"renderer_nodes": sources.size(),
		"drawn_copies": drawn_copies,
		"surface_submissions": submissions,
		"mesh_resource_ids": mesh_ids,
		"material_resource_ids": material_ids,
		"override_material_resource_ids": override_material_ids,
	}


## How many scene nodes `node` stands in for, beyond the one it now occupies.
##
## Zero for everything this pass did not create, so a ship's descendant walk can
## add it unconditionally and read identically on an unbatched build.
static func authored_node_delta(node: Node) -> int:
	if node == null or not is_instance_valid(node) or not node.has_meta(AUTHORED_CENSUS_META):
		return 0
	var census: Dictionary = node.get_meta(AUTHORED_CENSUS_META)
	return maxi(0, int(census.get("descendant_nodes", 0)) - _live_node_count(node))


static func _live_node_count(node: Node) -> int:
	return 1 + node.find_children("*", "", true, false).size()


## The render census a ship must add back to read as it was built, summed over
## every batch this pass left under `search_root`.
##
## `mesh_resource_ids` are the source meshes to union back in and
## `retired_mesh_resource_ids` the merged meshes to drop. The batches bind their
## materials as per-surface overrides rather than a `material_override`, so a
## report that counts `material_override` sees none of them and
## `override_material_resource_ids` carries exactly what the sources contributed
## to such a report. Every counter is zero and every roster empty when nothing
## under `search_root` was batched, so a report can add this unconditionally.
static func authored_render_census_delta(search_root: Node) -> Dictionary:
	var delta := {
		"descendant_nodes": 0,
		"renderer_nodes": 0,
		"drawn_copies": 0,
		"surface_submissions": 0,
		"mesh_resource_ids": PackedInt64Array(),
		"retired_mesh_resource_ids": PackedInt64Array(),
		"material_resource_ids": PackedInt64Array(),
		"override_material_resource_ids": PackedInt64Array(),
	}
	if search_root == null or not is_instance_valid(search_root):
		return delta
	var candidates := search_root.find_children("*", "", true, false)
	candidates.append(search_root)
	for candidate in candidates:
		if not candidate.has_meta(AUTHORED_CENSUS_META):
			continue
		var census: Dictionary = candidate.get_meta(AUTHORED_CENSUS_META)
		var visual := candidate as MeshInstance3D
		var live_submissions := 0
		if visual != null and visual.mesh != null:
			live_submissions = visual.mesh.get_surface_count()
			delta["retired_mesh_resource_ids"] = _appended(
				delta["retired_mesh_resource_ids"], visual.mesh.get_instance_id()
			)
		delta["descendant_nodes"] = int(delta["descendant_nodes"]) \
			+ authored_node_delta(candidate)
		delta["renderer_nodes"] = int(delta["renderer_nodes"]) \
			+ int(census.get("renderer_nodes", 0)) - (1 if visual != null else 0)
		delta["drawn_copies"] = int(delta["drawn_copies"]) \
			+ int(census.get("drawn_copies", 0)) \
			- (1 if visual != null and visual.visible else 0)
		delta["surface_submissions"] = int(delta["surface_submissions"]) \
			+ int(census.get("surface_submissions", 0)) - live_submissions
		for mesh_id in census.get("mesh_resource_ids", PackedInt64Array()) as PackedInt64Array:
			delta["mesh_resource_ids"] = _appended(delta["mesh_resource_ids"], mesh_id)
		for material_id in census.get(
			"material_resource_ids", PackedInt64Array()
		) as PackedInt64Array:
			delta["material_resource_ids"] = _appended(
				delta["material_resource_ids"], material_id
			)
		for override_id in census.get(
			"override_material_resource_ids", PackedInt64Array()
		) as PackedInt64Array:
			delta["override_material_resource_ids"] = _appended(
				delta["override_material_resource_ids"], override_id
			)
	return delta


static func _appended(ids: PackedInt64Array, id: int) -> PackedInt64Array:
	if not ids.has(id):
		ids.append(id)
	return ids


## One surface per source material, bound exactly as the sources bound it.
##
## The sources each carried their material on the mesh surface, which applies to
## that mesh alone. The merged mesh has one surface per distinct material, so the
## same binding is expressed as a per-surface override; nothing about the
## shading, the surface count or the submission order changes.
static func _apply_surface_materials(visual: MeshInstance3D, materials: Array) -> void:
	for index in materials.size():
		visual.set_surface_override_material(index, materials[index] as Material)


## Whether a merged bound would present itself as a floor plate. See the `PLATE_*`
## constants: the aggregate of several fittings can take that shape while the
## volume between them is empty, and a rendered plate with nothing under it is a
## real defect the walkability sweep audits for.
static func _reads_as_walkable_plate(mesh: ArrayMesh) -> bool:
	if mesh == null:
		return false
	var size := mesh.get_aabb().size
	return size.x >= PLATE_MIN_BREADTH \
		and size.z >= PLATE_MIN_BREADTH \
		and size.y <= PLATE_MAX_THICKNESS


static func _batch_name(parent: Node3D) -> String:
	var index := 1
	var candidate := "FitoutRenderBatch%02d" % index
	while parent.has_node(NodePath(candidate)):
		index += 1
		candidate = "FitoutRenderBatch%02d" % index
	return candidate


## Exact triangle-for-triangle merge of `sources` placed at `offsets`, emitted as
## one surface per distinct source material in first-appearance order.
##
## Returns `{}` when any source cannot be merged losslessly, so the caller leaves
## the originals exactly as they were.
static func _merge(sources: Array[MeshInstance3D], offsets: Array[Transform3D]) -> Dictionary:
	if sources.is_empty() or sources.size() != offsets.size():
		return {}
	var materials: Array[Material] = []
	var order: Array[int] = []
	var buckets: Dictionary = {}
	for source_index in sources.size():
		var mesh := sources[source_index].mesh
		if mesh == null:
			return {}
		for surface_index in mesh.get_surface_count():
			var material := _surface_material(sources[source_index], surface_index)
			if material == null:
				return {}
			var material_id := material.get_instance_id()
			if not buckets.has(material_id):
				buckets[material_id] = []
				order.append(material_id)
				materials.append(material)
			(buckets[material_id] as Array).append(
				Vector2i(source_index, surface_index)
			)
	var merged := ArrayMesh.new()
	for material_id in order:
		var surface := _merge_surface(sources, offsets, buckets[material_id] as Array)
		if surface.is_empty():
			return {}
		merged.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, surface)
	if merged.get_surface_count() != materials.size():
		return {}
	return {"mesh": merged, "materials": materials}


static func _merge_surface(
		sources: Array[MeshInstance3D],
		offsets: Array[Transform3D],
		members: Array
	) -> Array:
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var tangents := PackedFloat32Array()
	var uvs := PackedVector2Array()
	var indices := PackedInt32Array()
	var has_tangents := true
	var has_uvs := true
	for member_variant in members:
		var member := member_variant as Vector2i
		var mesh := sources[member.x].mesh
		var arrays := mesh.surface_get_arrays(member.y)
		var source_vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var source_normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
		if source_vertices.is_empty() or source_normals.size() != source_vertices.size():
			return []
		var placement := offsets[member.x]
		var normal_basis := placement.basis.inverse().transposed()
		var offset := vertices.size()
		for index in source_vertices.size():
			vertices.append(placement * source_vertices[index])
			normals.append((normal_basis * source_normals[index]).normalized())
		if has_tangents and arrays[Mesh.ARRAY_TANGENT] is PackedFloat32Array \
				and (arrays[Mesh.ARRAY_TANGENT] as PackedFloat32Array).size() \
					== source_vertices.size() * 4:
			var source_tangents: PackedFloat32Array = arrays[Mesh.ARRAY_TANGENT]
			for index in source_vertices.size():
				var tangent := (placement.basis * Vector3(
					source_tangents[index * 4],
					source_tangents[index * 4 + 1],
					source_tangents[index * 4 + 2]
				)).normalized()
				tangents.append(tangent.x)
				tangents.append(tangent.y)
				tangents.append(tangent.z)
				tangents.append(source_tangents[index * 4 + 3])
		else:
			has_tangents = false
		if has_uvs and arrays[Mesh.ARRAY_TEX_UV] is PackedVector2Array \
				and (arrays[Mesh.ARRAY_TEX_UV] as PackedVector2Array).size() \
					== source_vertices.size():
			uvs.append_array(arrays[Mesh.ARRAY_TEX_UV] as PackedVector2Array)
		else:
			has_uvs = false
		var source_indices := PackedInt32Array()
		if arrays[Mesh.ARRAY_INDEX] is PackedInt32Array:
			source_indices = arrays[Mesh.ARRAY_INDEX]
		if source_indices.is_empty():
			if source_vertices.size() % 3 != 0:
				return []
			for index in source_vertices.size():
				indices.append(offset + index)
		else:
			if source_indices.size() % 3 != 0:
				return []
			for index in source_indices:
				if index < 0 or index >= source_vertices.size():
					return []
				indices.append(offset + index)
	if vertices.is_empty() or indices.is_empty():
		return []
	var surface := []
	surface.resize(Mesh.ARRAY_MAX)
	surface[Mesh.ARRAY_VERTEX] = vertices
	surface[Mesh.ARRAY_NORMAL] = normals
	if has_tangents and tangents.size() == vertices.size() * 4:
		surface[Mesh.ARRAY_TANGENT] = tangents
	if has_uvs and uvs.size() == vertices.size():
		surface[Mesh.ARRAY_TEX_UV] = uvs
	surface[Mesh.ARRAY_INDEX] = indices
	return surface


## Every **node** any live script variable under `root` can still reach.
##
## The merge frees nodes, so anything a craft, binding or world module is still
## holding must be off limits even when its own node looks anonymous. Only node
## identities are recorded: meshes and materials are shared, cached resources
## here, and this pass never frees a resource.
static func _collect_script_referenced_objects(root: Node) -> Dictionary:
	var referenced := {}
	var visited := {}
	_visit_node_tree(root, referenced, visited)
	return referenced


static func _visit_node_tree(node: Node, referenced: Dictionary, visited: Dictionary) -> void:
	if node == null or not is_instance_valid(node):
		return
	_visit_script_variables(node, referenced, visited)
	for child in node.get_children():
		_visit_node_tree(child, referenced, visited)


static func _visit_script_variables(
		value: Object,
		referenced: Dictionary,
		visited: Dictionary
	) -> void:
	if value == null or not is_instance_valid(value) or value.get_script() == null:
		return
	var id := value.get_instance_id()
	if visited.has(id):
		return
	visited[id] = true
	for property in value.get_property_list():
		if int(property.get("usage", 0)) & PROPERTY_USAGE_SCRIPT_VARIABLE == 0:
			continue
		_visit_variant(value.get(property["name"]), referenced, visited)


static func _visit_variant(value: Variant, referenced: Dictionary, visited: Dictionary) -> void:
	match typeof(value):
		TYPE_OBJECT:
			if not is_instance_valid(value):
				return
			var object := value as Object
			if object is WeakRef:
				_visit_variant((object as WeakRef).get_ref(), referenced, visited)
				return
			if object is Node:
				referenced[object.get_instance_id()] = true
				return
			if object is Mesh:
				referenced[object.get_instance_id()] = true
				return
			# A ship's helper object can hold the node references instead.
			_visit_script_variables(object, referenced, visited)
		TYPE_ARRAY:
			for entry in value as Array:
				_visit_variant(entry, referenced, visited)
		TYPE_DICTIONARY:
			for key in value as Dictionary:
				_visit_variant(key, referenced, visited)
				_visit_variant((value as Dictionary)[key], referenced, visited)
