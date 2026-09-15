# Ember loop soak

`tests/ember_loop_soak_test.gd` drives production `res://scenes/main.tscn`
through N Ember expeditions in one process, alternating the two craft the
production binding admits for the trip (`torrent_provisional`,
`arrow_provisional`). It is the Phase 10 §4 measurement for the planetary loop:
precision jitter, terrain tunnelling, floating-origin discontinuity,
presentation pop, stranded actors, moving-interior state, landing support,
unbounded streaming growth and save/re-entry divergence.

```sh
godot --headless --audio-driver Dummy --path . \
  --script res://tests/ember_loop_soak_test.gd            # 6 cycles
KETH_EMBER_SOAK_CYCLES=18 godot --headless --audio-driver Dummy --path . \
  --script res://tests/ember_loop_soak_test.gd            # 18 cycles
```

## What is real and what is staged

Real, per cycle: walking to the craft and boarding it with one `interact` press;
launching with held flight input; opening the expedition through
`GameFlow.begin_ember_surface_journey()`; `EmberMoonStreamingProductionBinding`
loading the authored moon; `CommonWorldOriginRebaseOwner` committing the
common-world rebase; `PlanetaryCruiseProductionBinding` arming, activating and
completing its final approach; the handoff into `EmberSurfaceLoopHost`; the
descent and caldera touchdown through the real `EmberSurfaceBerth` lease and
`HeroShip.request_berth_landing()`; the disembark; the authored pad-egress and
staging route walked with held movement actions on live terrain support; the
walk back to the real `ShipBoardingArea` and a real `interact` at it.

Staged, twice per cycle and counted as `staging_events`: the craft is held at
Ember's canonical navigation anchor until the real cruise binding reports its
final-approach target ACTIVE, then placed once at the authored corridor entry
pose. Production has no owner that physically flies a craft the 8,000 km from
the yard or the last 10 km into the corridor — `EMBER_MOON_ORBITAL_STREAMING.md`
records that gap — so the suite plays exactly that missing owner and nothing
else. Both placements reset the discontinuity tracker by name; every metre after
them is produced by a production movement owner. This is the precedent
`long_session_soak_test.gd` sets for the yard approach lane.

## Where the loop stops

Each cycle ends at the authored relay survey, recorded as
`stopped_at: authored_survey_gate`. `_consume_ember_surface_reboard_interaction()`
answers a real `interact` at the boarding area with "Survey return pending"
until the survey's mandatory route is complete, and that route's two checkpoints
sit at body-local `(180, ·, -44)` and `(540, ·, -210)` — about 170 m and a
further 400 m from the caldera pad. Walking them is minutes of simulated time per
cycle at a headless Ember tick rate of roughly 5–8 physics ticks per second, so
the suite stops at that gate by name instead of teleporting through it. The
refusal is asserted to be exactly that gate: Host `ON_FOOT`, the exact boarding
area in reach, and an active survey still on its first objective. If a later
change closes the gate, that assertion fails and the suite must be extended
through re-board, ascent, orbital return and the yard landing — the legs are
already written and budgeted below the gate.

`cancel_ember_surface_journey()` deliberately refuses a started expedition
(`ember_surface_journey_already_started`), so what the suite can assert about
stranding is the true, weaker property: at the gate the pilot is embodied, in
control and standing on live authored support, and the craft is parked holding
its own pad lease. Nothing is lost — but a started expedition also cannot be
abandoned, which is recorded below as a remaining gap.

A cycle after the first stops earlier still, at `stopped_at:
repeat_visit_handoff`: the retained composition arms, activates and *completes*
its second final approach — the completion count reaches two and is consumed —
but the Host never leaves `IDLE`, so the surface loop does not start. That is a
second-visit defect rather than a broken loop (the first expedition of a session
always gets through), and it is asserted by name: a first-cycle handoff failure
is still a hard failure, and a later one must show a consumed second completion
against an `IDLE` Host. It is listed under remaining gaps.

## Defects found and fixed

### 1. A common-world rebase aborted the landing it was in the middle of

`scripts/ships/hero_ship.gd`, `scripts/world/common_world_origin_rebase_owner.gd`.
The landing contract freezes the berth's dock and staging transforms in world
space. A committed origin rebase translates the ship, the berth and every other
covered root by one identical delta, after which the live berth no longer
matched its snapshot and `_get_landing_authority_failure()` aborted
`berth_changed`. On Ember this fired on **every** descent, because the drop from
the orbital navigation anchor to the caldera pad is exactly the coordinate
frame's 10 km origin-shift threshold: the craft was thrown out of an approach it
was flying correctly, mid-assist, with the pad in sight.

Fix: the origin owner notifies each node it actually translated, after the commit
is irreversible, through an optional `notify_common_world_translation(delta,
generation)` seam; `HeroShip` re-expresses its already-agreed landing targets in
the new common frame. It moves no hull and changes no phase, and a berth that
genuinely re-authors its dock still fails the guard, because nothing outside that
transaction reaches the seam. Covered by two new assertions in
`tests/landing_clearance_test.gd`: the announced translation keeps the landing
alive, and an unannounced berth move still aborts `berth_changed`.

### 2. The approach was discarded on the tick the craft arrived

`scripts/control/planetary_cruise_production_binding.gd`,
`scripts/control/planetary_cruise_physical_controller.gd`. `HeroShip` retires its
own cruise attachment the moment a braking approach reaches the 1 m/s speed
deadband — and for a final approach that is exactly the tick the craft comes to
rest inside the authored entry volume. The binding's next tick then failed on the
retired attachment, `reconcile_retired_ship_binding()` cleared the controller's
target, and the arrival — which had physically happened — was never measured. The
craft sat in the corridor with an admitted expedition and no handoff to the
surface loop; this is why the production loop could not reach the Ember surface
at all.

Fix: when a tick fails because the ship retired its attachment while an approach
is ACTIVE, the binding takes that one arrival measurement first, through the same
`_measure_final_approach()`/`_measure_return_approach()` predicate the ordinary
cadence uses, and completes through the existing
`_complete_final_approach_guarded()` path. A measurement that does not accept
falls through to the ordinary reconciliation and retirement. Covered by a new
assertion in `tests/ember_final_approach_production_handoff_test.gd`.

### 3. An admitted expedition could never re-arm its approach

`scripts/game/planetary_journey_coordinator.gd`. The final-approach target is
armed exactly once, by `begin_ember_surface_journey()`. `HeroShip` can
independently retire its cruise attachment while the Host is still `IDLE` —
braking complete at the destination, a physical collision, a manual flight
command — and that retirement clears the armed target and the engagement with it.
Nothing re-armed, and there is no production request seam to ask again, so the
expedition stayed active with the craft stranded in Ember orbit and no path to
the surface. Observed directly: the journey reported
`ember_surface_journey_admitted` while the cruise binding reported `not_engaged`
with target generation 0, forever.

Fix: while an expedition is active, its handoff is not yet ready, no completion
receipt exists, the station-return leg has not begun and the Host is attached and
`IDLE`, the retained coordinator re-engages and re-arms through the same public
`request_engage()`/`_arm_ember_final_approach()` calls. It is idempotent (an
armed target reports `final_approach_already_armed`) and adds no movement,
landing or origin authority. Covered by a new assertion in
`tests/ember_final_approach_production_handoff_test.gd`.

### 4. The caldera berth was frozen to the first craft that ever landed

`scripts/world/ember_surface_berth.gd`. `Main` retains one `EmberSurfaceBerth`
for the whole session, and `configure_for_ship()` refused outright once
`_configured_ship_id` was set — a field nothing ever cleared. A later expedition
in a different craft, whose hull sits at a different dock height, therefore failed
its Host bind with `berth_configuration_failed` and the surface loop simply never
started. Player-facing: fly the Arrow to Ember once, then take the Torrent there
in the same session, and nothing happens at the pad.

Fix: the lease guard moves first, and an idle berth re-derives its dock transform,
capture centre and collision bounds for the new craft. A reserved or occupied
berth still refuses with `berth_lease_active`, which is what actually protects a
live landing's snapshot. Covered by an extension to
`_test_berth_configuration_requires_empty_lease()` in
`tests/ember_surface_loop_host_test.gd`: an idle berth re-derives for a second
craft and locks again under that craft's lease.

## Remaining gaps (not fixed here)

- **No production entry point.** `begin_ember_surface_journey()` has no caller in
  the shipped game; the expedition is still a caller-driven seam. The pause
  navigation's `EMBER CRUISE` toggle only engages cruise.
- **No owner flies the craft to Ember or into the corridor.** The two staged
  placements above stand in for it.
- **A started expedition cannot be abandoned.**
  `cancel_ember_surface_journey()` returns `ember_surface_journey_already_started`
  once the Host has left `IDLE`, so the only exit from the caldera is completing
  the loop — which currently requires the 570 m relay survey.
- **A repeat visit completes its approach but never starts the Host.** Cycle two
  onward reaches `final_approach_handoff_ready` with `completion_count` 2 and the
  completion consumed, and the Host stays `IDLE`. The three fixes above carried
  the second visit from "never arms" to "completes and is consumed"; what remains
  is the consumption-to-start step on a rebound Host. Recorded as
  `repeat_visit_handoff_stops` in `EMBER_SUMMARY`.
- **`ember_surface_loop_production_binding_test` has one pre-existing failure**
  ("real survey completion persists one GameFlow reward before the coordinator
  admits the authenticated route home"), reproduced on a clean tree at
  `e57a97e61` before any change here. It is not caused by, and not addressed by,
  this work.
- **The 240 s acceptance target is not reachable on this machine.** With the
  authored Ember moon streamed in, production `Main` runs at roughly 5–8 physics
  ticks per second headless (against ~60 at the yard), and one expedition is a
  few thousand physics ticks. Measured wall-clock figures are below.

## Results

<!-- RESULTS -->
