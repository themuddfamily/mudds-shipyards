# Review candidates

Previously identified candidates were reproduced and addressed in the current branch:

- `scripts/combat/live_combat_authority.gd`: receipt allocation now uses a monotonic
  64-bit session allocator for deferred presentations, with explicit fail-closed
  saturation behavior.
- `scripts/audio/station_machinery_ambience.gd` and
  `scripts/audio/combat_audio_presentation.gd`: playback acceptance now includes an
  explicit backend-aware seam and atomic detach-on-rejection behavior.
- `scripts/game/game_flow.gd`, `scripts/effects/hero_damage_presentation.gd`,
  and `scripts/world/shipyard_world.gd`: whole-Main teardown now clears owner-side
  deferred presentation queues to prevent stale replay after re-entry.

## Open candidates — 2026-08-15 human playtest intake

Reporter: project owner (`loginpeople123@gmail.com`), 2026-08-15, verbatim report:
*"there's so many places that are difficult to get to, random objects floating in
the air and it ruins the experience."*

Configuration for every reproduction below: Linux (WSL2 6.18.33.2), Godot
4.7.1.stable.official.a13da4feb, `--headless` for physics probes and
`xvfb-run -a -s "-screen 0 2560x1440x24" ... --rendering-driver vulkan` for frames,
audio driver `Dummy`, clean user-data state, source at commit `ef5450c`.
Failure frequency: 10/10 deterministic for every item unless stated.
Failing witness for all confirmed items:
[`tests/station_traversal_defect_witness_test.gd`](tests/station_traversal_defect_witness_test.gd)
(intentionally RED; sentinel `STATION_TRAVERSAL_DEFECT_WITNESS_TEST_FAILED`).

### Measurement that underpins the traversal items

`MEASURED_NO_JUMP_STEP_HEIGHT: 0.14` — the production `PlayerController`
(`CharacterBody3D`, plain `move_and_slide()`, no step-up assist) mounts a 0.14 m
lip with continuous `move_forward` and fails at 0.15 m, walking or sprinting.
Any authored lip of 0.15 m or more is therefore a wall, not a step.

### MAP-001 — Aft stair base is fenced off; the whole aft-upper half of the station is unreachable

- Status: `REPRODUCED`. Severity: **P1** (roadmap: "cannot reach a required route
  without an unintended jump"; the playable-prototype gate names the Aft upper
  level and Fleet Dock as required no-cheat destinations).
- Authority: `scripts/world/aft_junction_stack.gd:494`
  `_add_rail(lower, Vector3(-3.35, 0, 0.25), Vector3(-3.35, 0, 3.3), "ApproachPortRail")`,
  plus the two `Circulation` stair rails at the ramp foot.
- Node paths: `ShipyardWorld/AftJunctionStack/Structure/LowerOpenDeck/ApproachPortRail`
  (world x = -3.35, z = 48.25 … 51.30, collision on) and
  `ShipyardWorld/AftJunctionStack/Structure/Circulation/@StaticBody3D@81`/`@96`
  (world x ≈ -3.75 … -4.25, z ≈ 51.0 … 52.5).
- Steps: begin shift; walk to the Aft connection deck; stand at world
  `(0.0, 0.18, 50.5)`, `(0.0, 0.18, 51.5)`, `(0.0, 0.18, 52.0)` or
  `(0.0, 0.18, 52.6)` facing `-X`; hold `move_forward` for 200 physics frames.
- Expected: reach the stair base landing (x ≤ -4.6) and climb
  `Structure/Circulation/ContinuousStairRamp`.
- Actual: stops at x = -2.900 / -3.566 / -3.606 / -3.919 respectively, stuck for
  153-165 of 200 frames. The rail plus the stair-rail pair seal every column
  between the connection deck and the ramp foot.
- Blast radius (all unreachable on foot as a consequence):
  `AftJunctionStack/Structure/Circulation/ContinuousStairRamp`,
  `AftJunctionStack/Structure/UpperOpenDeck/UpperFloor` (top y = 4.20),
  `ExposedDockLattice/FleetDockCombConnector/FleetDockCombConnectorDeck`
  (centre `(6.0, 3.88, 68.3)`), and every `FleetDockComb/GeneratedComb/WalkableSurfaces/*`
  (`Trunk`, `Rung01/02`, `DockSlab01/02`, `Rung03Vertical`, `DockSlab03Upper`).
  The ramp itself is fine: from `(-5.0, 0.18, 50.0)` facing `+Z` the production
  capsule climbs to `(-5.0, 4.200, 67.53)` unaided.

### MAP-002 — 0.40 m riser seals the operations pod, the fleet registry pod, and the entire freight branch

- Status: `REPRODUCED`. Severity: **P1** (unreachable required route; the fleet
  registry terminal interaction cannot be acquired from its intended approach).
- Authority: `scripts/world/shipyard_world.gd:2786` `OperationsPodFloor`,
  `scripts/world/shipyard_world.gd:2811` `RegistryPodDeck`, and the
  `JovianFreightBerth` connection lattice, all authored with deck top y = 0.38
  against a lattice deck top of y = -0.02 → a 0.400 m vertical lip at z = 23.0.
- Node paths / coordinates: `ShipyardWorld/UpperOperations/OperationsPodFloor`
  `(43.0, 0.18, 27.0)`; `ShipyardWorld/ModernFleetRegistry/RegistryPodDeck`
  `(-43.0, 0.18, 27.0)`; `ShipyardWorld/JovianFreightBerth/ConnectionLattice/ConnectionHandoffDeck`
  `(-49.5, 0.08, 25.6)`.
- Steps: begin shift; stand at `(43.0, 0.18, 21.0)` (or `(-43.0, 0.18, 21.0)`, or
  `(-47.0, 0.18, 21.0)`) facing `+Z`; hold `move_forward` for 200 frames.
- Expected: step up into the glass-fronted pod / onto the freight handoff deck.
- Actual: stops dead at z = 22.620 with y unchanged at -0.020, stuck 178/200
  frames. The pods have open glazed frontages and a diegetic terminal, so they
  read unmistakably as rooms the player is meant to enter.
- Blast radius: every `JovianFreightBerth` surface is unreachable —
  `ConnectionDeckA/B/C`, `ConnectionHandoffDeck`, `ApronDeck01-04`,
  `CargoRackShelf`, `ServiceRoomShelf`, `FreightControlRoom/RoomFloor`.
  The seam itself is solid structure (no void): the void probe at x = -47.5
  returns zero empty samples, so this is purely the lip.

### MAP-003 — Two of the four flyable craft cannot be boarded on foot

- Status: `REPRODUCED`. Severity: **P1** (roadmap: "All four ships can be
  approached from collision-clear routes, boarded through the production
  reservation path"). Consequence of MAP-001 and MAP-002, tracked separately
  because it is what the player actually loses.
- `JovianLightFreighter` boarding position `(-49.60, 1.11, 65.45)` — on the
  freight loading apron, gated by MAP-002.
- `ZenithInterceptor` boarding position `(14.35, 4.73, 53.85)` — on
  `FleetDockComb/GeneratedComb/WalkableSurfaces/DockSlab01`, gated by MAP-001.
- Reachability sweep: 53,073 of 106,903 capsule-clear walkable graph nodes are
  reachable from `%PlayerSpawn` `(-8.5, 0.18, 11.0)` with no jump — just under
  half the authored walkable area of the station.

### MAP-004 — Pod facade and registry terminal legends are mirrored to the approaching player

- Status: `REPRODUCED`. Severity: **P2** (roadmap: "isolated visual mismatch").
  Argued escalation: the roadmap's P1 clause "systematically reverses or destroys
  scene readability" plausibly applies, because six adjacent legends including the
  only diegetic regeneration interface are all reversed. Left at P2 pending review
  because it neither blocks nor misdirects the core loop.
- `TextMesh` renders its readable face toward local `+Z`; these six are authored
  with `Vector3.ZERO` rotation at the `-Z` face of their structure, so the reader
  standing on the lattice deck sees mirror writing.
- Node paths: `ShipyardWorld/UpperOperations/Sign_DOCK_OPERATIONS` `(43.0, 5.15, 22.68)`;
  `ShipyardWorld/ModernFleetRegistry/Sign_FLEET_REGISTRY__--__MODERN_INTERFACE`
  `(-43.0, 5.05, 22.82)`; `.../Sign_SAY_SHIP_NAME` `(-43.0, 2.17, 23.57)`;
  `.../Sign_TORRENT__JOVIAN__TITAN__VORTEX` `(-43.0, 1.70, 23.56)`;
  `.../Sign_KATANA__PARADOX__PREDATOR__DYNAMIC` `(-43.0, 1.43, 23.56)`;
  `.../Sign_UTOPIA__ARROW` `(-43.0, 1.18, 23.56)`.
  The last four sit 0.05 m in front of `RegistryScreen`, whose own panel faces the
  deck — the text faces into its own screen.
- Evidence frames: `b2_registry_sign.png`, `b2_pod_riser_outside.png`,
  `b2_freight_branch_gap.png` (scratchpad, not committed).

### MAP-005 — Eight safety beacons hover 0.19 m above the roofs they stand on

- Status: `REPRODUCED`. Severity: **P2** ("isolated visual mismatch"); it does not
  imply a route, so it does not escalate.
- Node paths: `ShipyardWorld/OperationalLattice/Activities/AftOperationsActivity/PresentationRoot/SafetyBeacon01-04/Base`
  (around `(3.9 … 7.7, 5.26, 60.0 … 62.5)`, resting surface
  `AftJunctionStack/Structure/OperationsRoom/OperationsCeiling` at y = 4.98) and
  `.../HabitatServicePatrol/PresentationRoot/SafetyBeacon01-04/Base`
  (around `(55.9 … 62.4, 5.15, 11.4 … 19.6)`, resting surface
  `HabitatSpine/Structure/PressurizedHabitatCorridor/HabitatCeiling`).
- Measured drop from the base underside to the surface below: 0.190 m for all eight.

### MAP-006 — Orphan freight dock guide lens hangs in open space

- Status: `REPRODUCED`. Severity: **P2** ("isolated visual mismatch").
- Node path: `ShipyardWorld/JovianFreightBerth/FreightPresentation/DockGuideLens18`,
  centre `(-53.0, 0.63, 77.8)`.
- `LoadingApron/ApronDeck04` ends at z = 76.65, so the lens sits 1.15 m beyond the
  apron edge with a 2.04 m drop to `LoadingApron/ApronCrossChord6` below. Every
  other dock guide lens rests on the apron.

### Unconfirmed observations (not yet reproduced, no witness)

- `ShipyardWorld/OperationalLattice/Activities/CentralTowServiceActivity/PresentationRoot/MaintenanceGantry/OverheadRail`
  (world min y = 5.61) floats 0.08 m above the top of its own
  `MaintenanceGantry/Column` (max y = 5.53) at `(9.5, 5.8, 9.5 … 18.5)`. The same
  0.08 m assembly gap appears on `FreightApproachGantry`. Numerically confirmed,
  not yet confirmed as visible to a player — likely P3.
- Floor decals rendered mirrored in overview frames ("BERTH F-01" on the freight
  berth, "ZENITH // RESERVED" on `FleetDockComb`, "AFT JUNCTION // MODERN
  INTERPRETATION"). Same root cause family as MAP-004 but the correct readable
  orientation for a floor decal was not determined, so no witness was written.
- `ShipyardWorld/ArrowReconBerth/BerthFeedback/FeedbackVisual/Boundary_*`
  (four strips around `(-50 … -36, 0.40, 10.5 … 20.5)`) return no downward hit at
  all — the berth-cue rectangle overhangs the structure it marks. Possibly
  intentional projected cue geometry; not classified.
- `ShipyardWorld/ModernFleetRegistry/Sign_ACTIVE_BERTH__--__CENTRE_SPINE`
  `(-38.5, 3.35, 26.9)` has no geometry within 0.62 m in any direction and a
  1.86 m drop. Probably a floating sign, but its intended mount is unclear.

### Explicit false positives — swept and dismissed

Downward-support sweeping every one of the 2,794 live `MeshInstance3D` nodes in
`Main` produced these unsupported-but-intentional groups, deliberately **not**
raised: `SpaceBackdrop/Celestial*` bodies and `ParallaxStars`;
`ExteriorTargetRange` drones, `BeaconMast`, `RangeTruss` and its range sign;
`OpenLaunchSpine` guide lenses and `SignalMast` (markers deliberately suspended in
the launch corridor void); `OperationalLattice/StructuralDressing/*` keel chords
and fascia (exterior dressing hanging outside the deck edge by design);
`AnimatedServiceDrone*` (authored hovering); ceiling cove rails, overhead beams,
docked/parked craft, and the freight crane; `BerthFeedback/FeedbackVisual`
boundary strips that hover 0.22-0.37 m over their pads (projected landing cue).
Closed `StationDoor` portals were excluded from every reachability query so a door
that simply needs an interact press is never miscounted as a blocked route; only
the two `deferred_access` landmark doors stay solid.
