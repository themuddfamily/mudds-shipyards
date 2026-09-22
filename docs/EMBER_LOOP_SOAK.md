# Ember loop soak

`tests/ember_loop_soak_evidence.gd` drives production `res://scenes/main.tscn`

> **Why this is not a `*_test.gd` matrix suite.** Cycle one is one full real
> expedition and costs ~110 s on an idle machine; under matrix load it would
> exceed the per-suite budget. The defects it found each carry a focused
> assertion in an ordinary suite (`landing_clearance_test`,
> `ember_final_approach_production_handoff_test`,
> `ember_surface_loop_host_test`, `ember_surface_loop_repeat_cycle_test`,
> `ember_repeat_visit_landing_test`), so the matrix guards the fixes while this
> harness is run explicitly for §4 evidence, like the capture harnesses.

through N Ember expeditions in one process, alternating the two craft the
production binding admits for the trip (`torrent_provisional`,
`arrow_provisional`). It is the Phase 10 §4 measurement for the planetary loop:
precision jitter, terrain tunnelling, floating-origin discontinuity,
presentation pop, stranded actors, moving-interior state, landing support,
unbounded streaming growth and save/re-entry divergence.

```sh
godot --headless --audio-driver Dummy --path . \
  --script res://tests/ember_loop_soak_evidence.gd            # 6 cycles
KETH_EMBER_SOAK_CYCLES=18 godot --headless --audio-driver Dummy --path . \
  --script res://tests/ember_loop_soak_evidence.gd            # 18 cycles
```

## What is real and what is staged

The separate `tests/ember_transit_movement_soak.gd` checks the outbound leg
without placing the craft in flight. Run it explicitly from a checkout that
contains the transit implementation:

```sh
timeout 1800 godot --headless --audio-driver Dummy --fixed-fps 60 --path . \
  --script res://tests/ember_transit_movement_soak.gd
```

It places the on-foot pilot near the yard craft, then uses walking, boarding
and held launch input. Acceptance requires over 7,800 km of physical flight,
over 700 committed origin shifts, continuous craft and seated-pilot movement,
and an occupied surface berth after landing. It also checks manual control,
explicit cancellation, whole-Main re-entry and rejected origin-receipt replays.
Exit zero and `EMBER_TRANSIT_MOVEMENT_TEST_OK` are required; a staged arrival
diagnostic does not satisfy this check. The eight-million-metre leg already
takes about 400 seconds at the authored maximum speed, before acceleration and
landing, so this is an explicit long soak rather than a default 300-second
matrix suite. The fixed frame interval preserves the normal 60 Hz movement
step; it does not raise the craft's speed. This check does not establish the
return leg, repeated visits, or native rendered performance.

The same explicit movement soak can exercise the physical ABANDON return:

```sh
KETH_EMBER_PHYSICAL_RETURN=1 timeout 7200 godot --headless --audio-driver Dummy \
  --fixed-fps 60 --path . --script res://tests/ember_transit_movement_soak.gd
```

This adds surface disembarkation, the ordinary ABANDON request, walking back
and reboarding, physical takeoff, ordinary forward thrust until 1,200 m above
the surface berth, queued return cruise across origin shifts, Ember unload,
and the typed home corridor handoff. A test pilot then uses ordinary held
flight and landing inputs to reach the home berth, verifies its actual lease,
disembarks and walks. It does not place the craft or write its velocity during
these legs. The final ordinary-flight leg can take several minutes at the
craft's authored speed, in addition to both interplanetary legs; the long wall
budget also accommodates slower headless hosts. A local launch/landing
probe (`KETH_RETURN_ARRIVAL_DIAGNOSTIC=1`) is only a diagnostic and does not
qualify the round trip. The full round-trip result remains pending until an
unchanged-source run exits zero with all enabled assertions passing.

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
pose. These placements bound the cost of repeated surface cycles; this harness
does not establish continuous outbound travel. The separate movement soak
above checks the production cruise owner, terrain-clearing lead-in and corridor
entry from a yard launch. Both placements reset the discontinuity tracker by
name; every metre after them is produced by a production movement owner. This is the precedent
`long_session_soak_test.gd` sets for the yard approach lane.

## Where the loop stops

Cycle order per expedition: board, launch, open, orbital approach, corridor
handoff, caldera landing, disembark, authored surface route, re-board attempt
(the gate), — on cycles 1, 3, 5 … — the surface save and whole-`Main` re-entry,
then the production abandon, the re-board it opens, the commit off the pad, and
the cycle reset.

Each cycle walks up to the authored relay survey and then takes the production
exit a player takes when they give up on it, recorded as `stopped_at:
abandoned_expedition`.

A separate diagnostic on `1255b5426` completed both mandatory checkpoints by
held production Player input, walked back and reboarded the Arrow through the
live interaction without ABANDON (exit 0, 19 assertions). Arrival was staged
before walking, so this proves the surface route and reboarding, not a complete
physical visit or station reward delivery. No runtime change was needed.

The survey gate itself is still asserted by name first.
`_consume_ember_surface_reboard_interaction()` answers a real `interact` at the
boarding area with "Survey return pending" until the survey's mandatory route is
complete, and that route's two checkpoints sit at body-local `(180, ·, -44)` and
`(540, ·, -210)` — about 170 m and a further 400 m from the caldera pad. Walking
them is minutes of simulated time per cycle at a headless Ember tick rate of
roughly 5–8 physics ticks per second, so the suite proves the refusal is exactly
that gate — Host `ON_FOOT`, the exact boarding area in reach, an active survey
still on its first objective — instead of teleporting through it.

From there the cycle runs the abandon:
`GameFlow.abandon_ember_surface_journey()`, the same call the pause navigation's
`EMBER CRUISE` row makes. The suite asserts the whole rule. The abandon is
admitted and *pending*, never refused; the authored route and its re-board gate
lift at once; the relay survey's activity generation is terminalized with no
reward; and nobody is stranded — the pilot keeps control on live authored
support and the craft keeps its own caldera lease until they have boarded it.
One real `interact` at the boarding area then boards, the Host runs its own
takeoff, and the abandon commits itself once the craft is physically off the pad:
Host back at `IDLE`, still attached, no terminal reason, caldera lease released,
pilot flying, zero reward receipts.

The repeated-cycle suite still stages the 8,000 km flight home, just as it
stages the outbound transit. `_reset_for_next_cycle()` releases the abandoned
visit's live return approach and places the craft and pilot back at the yard.
Production cruise now owns both long legs; the explicit movement soak above
checks them separately from these bounded repeated surface cycles. A reset
placement never counts as a successful physical return.
Everything else in the reset is production: the expedition is ended by the
production abandon, which leaves the retained Host attached and `IDLE` and
retires the visit-scoped surface composition by itself. There is no longer a
hand-forged `COMPLETED` handback in the harness.

Because the abandon releases the Host in place, every later cycle is a real
second, third and sixth expedition by the same retained `Main`, with a fresh
session generation, a rebound caldera berth and a fresh activity generation. A
cycle that fails to arm, activate or hand off its approach, or to land, is a
hard failure at any cycle index, not an excused repeat-visit boundary.

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

### 5. A whole-`Main` re-entry on the surface killed the expedition

`scripts/world/ember_surface_loop_host.gd`. A save/re-entry streams the entire
composition out and back in, so every dependency the Host observes leaves with
it. The Host treated that exactly like losing a dependency: each `tree_exiting`
reached `_queue_terminal()` and the visit committed `FAILED` before `_exit_tree`
even ran. Both actor positions survived the re-entry exactly (measured 0.000 m
drift for craft and pilot in the landing region's own frame) and the streamed
world was intact — but a player who saved and reloaded while walking the caldera
came back to a dead expedition.

Godot reports both removals identically while they are happening: exits are
bottom-up, so a still-live composition root is indistinguishable from a retained
one. The fix takes the decision one deferred step later, once `remove_child` has
returned and the composition root's own tree membership is finally readable. A
composition root still inside the tree means a dependency (or the Host itself)
genuinely left a live composition and the visit terminalizes exactly as before; a
composition root that left with everything else is the re-entry, and the visit is
suspended intact — same phase, same berth lease, same travel session, same
runtime ownership. Resuming re-asserts only what the streamed-out nodes dropped
on their own account: `HeroShip` retires its planetary-surface gravity binding
(the fresh binding restarts its submission sequence, so the visit's sample
counter restarts with it) and `ShipBoardingArea` clears every seat claim, re-taken
only into a genuinely free seat in the phases that require one.

Covered by `_test_composition_reentry_preserves_the_live_visit()` in
`tests/ember_surface_loop_host_test.gd`, and by this suite's re-entry assertion,
which now requires the live Host, its caldera lease, its survey progress and the
active expedition to all survive.

### 6. A started expedition could not be abandoned

`scripts/world/ember_surface_loop_host.gd`,
`scripts/world/ember_surface_loop_production_binding.gd`,
`scripts/game/planetary_journey_coordinator.gd`, `scripts/game/game_flow.gd`.
`cancel_ember_surface_journey()` returned `ember_surface_journey_already_started`
once the Host left `IDLE`, so the only exit from the caldera was completing the
~570 m relay survey. The pause navigation's `EMBER CRUISE` row offered exactly
that refusal.

`EmberSurfaceLoopHost.abandon()` is the production exit, and the rule it
implements is in `EMBER_SURFACE_LOOP_HOST.md` and on
`PlanetaryJourneyCoordinator.abandon_ember_surface_journey()`. It never separates
a pilot from their craft: it commits only while the craft is airborne under its
own pilot, and asked from the pad it is pending — the authored route and its
re-board gate lift so the walk home is immediate, and the Host's own takeoff
carries it until the craft is off the pad. Committing terminalizes the survey's
activity generation with no reward, retires the visit-scoped surface composition,
releases the caldera lease and all runtime ownership, and resets the retained
Host in place to `IDLE`. The craft then flies home on the same Mudds return
approach the completed loop uses, armed directly because an abandoned visit
earned no station-return contract; its completion hands the last leg to the
ordinary registered-berth landing lifecycle. Losing the craft mid-expedition
takes the same exit, so the retained `Main` is no longer left refusing every
later visit.

### 7. A repeat visit was never re-admitted

`scripts/world/ember_surface_loop_host.gd`,
`scripts/game/planetary_journey_coordinator.gd`. A repeat bind is only offered to
a Host that reached `COMPLETED` and handed runtime ownership back, so any other
ending — the survey gate, a terminal failure, a re-entry that could not be
carried — left the retained `Main` refusing every later expedition of the
session. That is why cycle two of the previous soak reached
`final_approach_handoff_ready` and then sat with an `IDLE` Host.

Three things closed it. Releasing a visit through the abandon resets the same
Host node and the same travel session in place — fresh session generation, fresh
command source, no visit-scoped evidence — so the next
`begin_ember_surface_journey()` is admitted with no rebind at all. A Host left
attached to the previous visit's streamed world (Ember unloads behind a departing
craft and the frozen loaded-root identity goes stale, which the Host's own audit
reports and the surface binding refuses to configure against) is now released and
rebound by the retained coordinator, but never under a live expedition.

And the actual reason cycle two used to consume its completion and then sit at
`IDLE`: the surface binding's caller-serial fence belongs to the visit-scoped
composition and resets with it, while the retained coordinator kept counting from
the previous expedition. Every cadence tick of the second visit was refused as a
skipped serial, so nothing ever called `Host.start()`. The coordinator now adopts
the fence the binding is actually holding when a journey is admitted.

Covered by cycle three of `tests/ember_surface_loop_repeat_cycle_test.gd` (a
terminal Host is released and the retained `Main` admits the next expedition) and
by this suite, where every cycle after the first is a real second expedition that
admits, arms, activates, hands off, starts its Host and flies the caldera
descent.

### 8. A repeat visit could not finish its caldera descent

`scripts/ships/hero_ship.gd`. With defect 1 fixed, cycle two onward admitted,
armed, activated, handed off, started its Host and flew the descent — and then
stopped at `stopped_at: repeat_visit_origin_rebase`: `HeroShip` aborted the
landing it was flying with `berth_changed` from inside that descent's own
committed common-world rebase, the Host observed the released lease as
`berth_lease_lost` on its next tick, and the retained coordinator turned the
terminal Host into the safe abandon. The earlier soak recorded it as a
repeat-visit boundary; it never was one. Cycles 3 and 5 are repeat visits too
and they landed. What the even cycles had in common was the Torrent.

The descent's rebase moves the world by ~10 km so the craft sits at the origin.
Defect 1's fix adds that delta to the frozen dock snapshot; the live berth
instead re-derives its dock transform through its own parent chain (moon root,
berth, dock offset), and at 10 km magnitudes float32 rounds that chain
differently from the single addition. Measured on the caldera pad with the
production tree: 0.078 mm for the Arrow's 1.17 m dock height, 0.391 mm for the
Torrent's 0.775 m — either side of the guard's absolute
`LANDING_TRANSFORM_EPSILON` of 0.1 mm. The first visit of a session was the
Arrow, so it landed; the Torrent never did, on any visit.

Fix: on the announced translation, `notify_common_world_translation()` still
moves the snapshot by the delta, then re-expresses the dock and staging targets
from the live berth wherever the berth agrees with the translated snapshot
within the transaction's rounding budget (`LANDING_REBASE_ROUNDING_RELATIVE`,
2^-20 of the largest magnitude handled — under a centimetre on Ember's drop).
The exact guard stays exact afterwards, because the target is now the berth's
own value; a berth that moved by more than that budget under the same commit,
or by anything at all afterwards, is still a `berth_changed` abort. Covered by
`_test_landing_survives_caldera_scale_rebase()` in
`tests/landing_clearance_test.gd`, which models the exact geometry for both
craft and fails on the unfixed ship with the Torrent's `berth_changed`, and by
`tests/ember_repeat_visit_landing_test.gd`, where one retained production `Main`
admits the Arrow and then the Torrent and each lands through its own committed
rebase, holds the caldera lease and disembarks.

One layer of this was removed on the way here and is worth recording, because
it hid the rest. `CommonWorldOriginRebaseOwner` translates every covered root
by one identical delta, which over an 8,000 km translation leaves
sub-millimetre rounding in the near-zero components of
`EmberMoonStreamingBootstrap`'s root. Both `update_absolute_focus()` and
`accept_committed_origin_rebase()` compare that root to the exact body centre
the frame defines, the latter *after* the next transaction's frame commit is
already irreversible — so the second visit's rebase was refused with
`bootstrap_alignment_invalid`, surfaced to the owner as the opaque
`binding_commit_desynchronized`, and starved the surface cadence entirely. The
bootstrap now implements the existing `notify_common_world_translation()` seam
and re-expresses its root at that exact position, allowing at most a centimetre
of rounding, and the binding retains the refusal the owner otherwise reports
opaquely (`last_external_rebase_rejection`).

## Remaining gaps (not fixed here)

- **No owner flies the craft to Ember, into the corridor, or the 8,000 km home.**
  The staged placements above and the staged return in `_reset_for_next_cycle()`
  stand in for it.
- **`ember_surface_loop_production_binding_test`'s recorded failure** ("real
  survey completion persists one GameFlow reward before the coordinator admits
  the authenticated route home"), reproduced on a clean tree at `e57a97e61`, no
  longer reproduces: the suite passes its 79 assertions on `234876ac3` both with
  and without defect 8's ship change, so it was closed on main independently of
  this work. Two other suites fail on that same clean `main` regardless of the
  ship script — `common_world_origin_rebase_production_journey_test` (a detached
  Ember binding's snapshot changes when it refuses a direct rebase acceptance)
  and `tests/world/ember_surface_loop_relay_survey_api_test` (the surface
  binding's caller snapshot carries more than that suite's expected shape) —
  neither of which lands a craft or reaches `notify_common_world_translation()`.
- **The 6-cycle run takes 790 s of cycle legs, not 240 s.** With the authored
  Ember moon streamed in, production `Main` runs at roughly 5–8 physics ticks per
  second headless against ~60 at the yard, and a full expedition is about 1,200
  of those ticks. Now that every cycle runs the whole loop, six of them are
  ~13 min wall. Figures below.

## Results

`EMBER_LOOP_SOAK_TEST_OK: 167 assertions` at the 6-cycle default, 0 failures,
790 s of measured cycle legs (~13 min wall; the machine also ran
`ember_repeat_visit_landing_test` for two of those minutes). Cycles alternate
`arrow_provisional` and `torrent_provisional`, and every cycle now runs the
whole loop: lands, disembarks, walks the authored route, is refused at the
survey gate, and leaves through the production abandon. The odd cycles also run
the surface save and whole-`Main` re-entry.

| Cycle | Craft | Stop | Furthest phase | Ticks | Rebases | Wall |
| --- | --- | --- | --- | --- | --- | --- |
| 1 | arrow | `abandoned_expedition` | `ASCENT` | 576 | 1 | 136.4 s |
| 2 | torrent | `abandoned_expedition` | `ASCENT` | 522 | 1 | 122.6 s |
| 3 | arrow | `abandoned_expedition` | `ASCENT` | 576 | 1 | 153.2 s |
| 4 | torrent | `abandoned_expedition` | `ASCENT` | 522 | 1 | 120.5 s |
| 5 | arrow | `abandoned_expedition` | `ASCENT` | 576 | 1 | 139.7 s |
| 6 | torrent | `abandoned_expedition` | `ASCENT` | 522 | 1 | 117.6 s |

Cycle 2's legs — the first Torrent expedition ever to land — in milliseconds:
board 381, launch 527, orbital approach 402, caldera landing 41,110, disembark
3,469, authored surface route 24,657, survey-gated re-board attempt 44,337,
abandon (pending, re-board, takeoff, commit) 6,304. Cycle 1 (Arrow, with the
re-entry): board 311, launch 534, orbital approach 428, caldera landing 48,592,
disembark 3,570, authored surface route 28,784, survey-gated re-board attempt
43,555, surface save and whole-`Main` re-entry 3,790, abandon 5,595.

Per-cycle measurements, every cycle: 1 floating-origin rebase with a
10,000.063 m committed translation; largest single-tick craft and pilot step
12.533 m (Arrow) / 10.933 m (Torrent) against a 334.333 m bound; zero
unsupported on-foot ticks; minimum tangent altitude above the caldera +0.001 m
(Arrow) / −0.002 m (Torrent); zero seat/piloted/reservation disagreements;
presentation moved without a pop; strict dock acceptance with the exact berth
occupant and token at touchdown.

Counters across all six cycles, recorded after each cycle's reset with Ember
streamed out:

| Counter | Cycles 1–6 | Tolerance |
| --- | --- | --- |
| `scene_nodes` | 10,613 every cycle | 32 |
| `object_nodes` | 11,350 every cycle | 32 |
| `objects` | 24,293 / 24,294 (Arrow cycles), 24,335 (Torrent cycles) | 512 |
| `orphan_nodes` | 6 every cycle | 0 |
| `static_memory_bytes` | 517,560,260 → 517,928,985 | 48 MiB |
| `audio_players` / `particle_systems` / `timers` / `tweens` | 81 / 54 / 21 / 1 every cycle | 0 / 0 / 4 / 4 |
| `streamed_nodes` | 0 every cycle | 0 |

The final teardown returns `OBJECT_NODE_COUNT` to its pre-boot baseline (1 → 1)
with zero orphan nodes. Summary counters: 12 staging events, 6 survey-gated
cycles, 6 abandoned expeditions, 3 surface save/re-entries with **0** terminal
Hosts, 0 repeat-visit handoff stops, 0 reward receipts, 0 assertion failures.

### Before this work

| Boundary | Before | Now |
| --- | --- | --- |
| starting an expedition | pause `EMBER CRUISE` already opened it (since `87400dc`); no objective, no briefing | same press, plus the standing `EMBER EXPEDITION` objective and the first-time activity briefing card |
| abandoning one | `ember_surface_journey_already_started`; the only exit was the 570 m relay survey | pending from the caldera, committed off the pad, craft home on the Mudds return approach |
| repeat visit | second visit consumed its completion and sat at `IDLE` forever; once it flew, every Torrent descent aborted `berth_changed` inside its own rebase | admits, arms, activates, hands off, lands, disembarks and walks the survey route like the first |
| surface save/re-entry | Host `ON_FOOT` → `FAILED`; a dead expedition on reload | Host, caldera lease, survey progress and active expedition all survive |

### Known flake

Under a shortened re-board budget (90 ticks instead of 600) an earlier shape of
this suite intermittently failed to select its craft at the yard on later
cycles. The committed budget is the longer one, which has not reproduced it. A
related cause has since been removed: a craft abandoned in flight kept its
engines online, and `is_boardable()` requires them offline, so the cycle reset
now idles every unpiloted flyable before the next cycle walks up to one.
