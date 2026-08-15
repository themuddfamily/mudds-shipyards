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

Witness for the confirmed traversal items (MAP-001…MAP-003), now **GREEN** and
collected by `run_test_matrix.sh`:
[`tests/station_traversal_defect_witness_test.gd`](tests/station_traversal_defect_witness_test.gd)
(sentinel `STATION_TRAVERSAL_DEFECT_WITNESS_TEST_OK`).

Witness for the still-open presentation items (MAP-004…MAP-006), intentionally
**RED** and deliberately outside the `*_test.gd` glob:
[`tests/station_presentation_defect_witness.gd`](tests/station_presentation_defect_witness.gd)
(sentinel `STATION_PRESENTATION_DEFECT_WITNESS_FAILED`). Its three assertions
were moved there verbatim when MAP-001…MAP-003 were fixed, so a P2 presentation
defect no longer holds the P1 traversal gate red. Rename it into the glob once
those three are closed.

### Measurement that underpins the traversal items

`MEASURED_NO_JUMP_STEP_HEIGHT` was **`0.14`** at intake — the production
`PlayerController` (`CharacterBody3D`, plain `move_and_slide()`, no step-up
assist) mounted a 0.14 m lip with continuous `move_forward` and failed at 0.15 m,
walking or sprinting. Any authored lip of 0.15 m or more was therefore a wall,
not a step.

It is now **`0.30`**. `PlayerController` gained a bounded step-up assist
(`STEP_UP_MAX_HEIGHT`), chosen from the rig and the architecture rather than
rounded to taste: it equals this station's own authored stair riser
(`AftJunctionStack` raises 4.2 m over 14 risers = 0.300 m), it is 58% of the
avatar's measured 0.516 m knee-joint height on a 1.945 m standing suit, and it
is inside the 0.38 m capsule radius so the body is only ever placed where the
capsule could have rolled unaided. It is deliberately **below** the station's
0.40 m raised-pod slab, so a room a whole slab above its approach still has to
author a real threshold instead of relying on the assist. Bounds and mutations
are frozen by [`tests/player_step_up_assist_test.gd`](tests/player_step_up_assist_test.gd).

### MAP-001 — Aft stair base is fenced off; the whole aft-upper half of the station is unreachable

- Status: `CLOSED` (fixed 2026-08-15). Severity was **P1**.
- Fix: `scripts/world/aft_junction_stack.gd`. Two rail runs were closing the only
  gate onto the stair-base landing and they overlapped by 0.33 m, so no capsule
  column was ever open. `ApproachPortRail` now stops at the landing's southern
  edge (`_stair_base_landing_south_edge()`) instead of running 1.8 m past it — it
  guards the stretch of connection-deck edge that actually overhangs a drop and
  nothing more. The eastern stair rail line, which stood *on* the landing rather
  than over a drop, now starts where the ramp has climbed clear of the landing
  (`_stair_rail_start_progress()`); the outboard western line still runs full
  length. The landing's own newly-exposed south and west edges gained
  `StairBaseSouthRail` / `StairBaseWestRail`, because opening the gate made a
  previously unreachable 4.4 × 3.5 m landing walkable with two unguarded edges.
- Regression: `tests/station_traversal_defect_witness_test.gd`
  `_test_aft_stair_base_is_not_fenced_off` — the recorded four-position
  reproduction, unchanged. From world `(0.0, 0.18, 50.5)` facing `-X` the
  production capsule now reaches `x = -6.290` on the landing (previously
  `-2.900`) and is stopped by the new west guard rail rather than falling. The
  same suite's required-route-surface flood covers the whole blast radius.
- Residual, recorded not fixed: from `z = 51.5` and north the westward walk is
  still stopped at `x ≈ -3.92` by the side of the ramp itself, which is 0.33 m
  proud of the landing there — just above the 0.30 m step limit. That is the
  side of a staircase, not a route; the player walks in at `z ≤ 51` and turns
  north. The route works but it is not equally open along the whole frontage.
- Original record follows.
- Status at intake: `REPRODUCED`. Severity: **P1** (roadmap: "cannot reach a required route
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

- Status: `CLOSED` (fixed 2026-08-15). Severity was **P1**.
- Fix: `scripts/world/shipyard_world.gd`. Both pods keep their authored
  placement — `docs/research/STATION_TOPOLOGY.md` pins `OperationsPodFloor
  (43, 0.18, 27)` and `RegistryPodDeck (-43, 0.18, 27)` as frozen evidence, so
  moving the decks would have been documentation drift, and lowering them would
  have left every mullion, window, back wall, terminal and sign 0.40 m in the
  air, which is the same defect family the reporter complained about. Instead a
  new `_approach_threshold()` helper builds one rendered, colliding threshold
  apron across each pod's full 12 m frontage: `OperationsPodThreshold` and
  `RegistryPodThreshold`, rising from the lattice deck top (`y = -0.02`) at
  `z = 21.85` to the pod deck top (`y = 0.38`) at `z = 23.05` — a 1.20 m run for
  a 0.40 m rise, 18.4°, well inside `floor_max_angle`. The freight branch needed
  no separate work: its connection lattice is flush with the registry pod deck,
  so it opened as soon as the pod did.
- Regression: `tests/station_traversal_defect_witness_test.gd`
  `_test_pod_decks_can_be_walked_into` — the recorded reproduction, run through
  the production controller. Standing on the lattice deck and holding
  `move_forward` for 200 frames now ends at `(43.0, 0.381, 25.87)` inside the
  operations pod, `(-46.5, 0.381, 30.17)` on the registry pod deck, and
  `(-47.0, 0.380, 30.17)` out along the freight connection lattice. No jump.
- Note on the recorded coordinates: the registry approach at `(-43.0, ·, 21.0)`
  stands **inside the parked `ArrowReconShip`'s hull**, so a capsule placed there
  starts overlapping a ship rather than on the deck. The regression uses
  `(-46.5, ·, 21.0)` on the same 12 m frontage; the lip crossed is identical.
- Original record follows.
- Status at intake: `REPRODUCED`. Severity: **P1** (unreachable required route; the fleet
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

- Status: `CLOSED` (fixed 2026-08-15). Severity was **P1**.
- Fix: none of its own. It was a pure consequence of MAP-001 and MAP-002 and
  closed with them.
- Regression: `tests/station_traversal_defect_witness_test.gd`
  `_test_every_flyable_ship_is_boardable_on_foot` — `STRANDED_SHIPS: []`. Every
  one of the four production `get_boarding_position()` points now has a
  capsule-clear walkable node reachable from `%PlayerSpawn` without a jump.
- Re-measured reachability on the same sweep: **91,901 of 106,969** capsule-clear
  walkable graph nodes are reachable from spawn with no jump, against the
  intake baseline of 53,073 of 106,903 — 49.6% → 85.9%. The node total rose by
  66 because the fix added walkable threshold aprons. The 15,068 nodes still
  unreached are dominated by surfaces with no intended route: `OperationsPodRoof`
  and `RegistryPodRoof` (1,617 each), `FreightControlRoom/RoomRoof` (1,000), the
  habitat and Aft operations ceilings, `FreightGantryCrane/GantryHeader`,
  cargo-unit tops, rail tops and the registry terminal top. Ship interiors and
  the exterior target range have not been swept.
- Original record follows.
- Status at intake: `REPRODUCED`. Severity: **P1** (roadmap: "All four ships can be
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
