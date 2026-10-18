# Development roadmap

**Status: playable development alpha; project completion is unproven.** Latest
accepted checkpoint: **ea8fe43**, with ordinary Habitat door walking/Torrent
boarding and actual patrol-drone coexistence. [Windows build notes](builds/windows/MuddsShipyards-ea8fe43-notes.txt)
and [Linux build notes](builds/linux/MuddsShipyards-ea8fe43-linux-notes.txt) state
actual checks and limits. All 36 original parents and ten phase gates remain open.

## What separates this alpha from completion

These are scope groups, not equally sized tasks or a percentage. The
[36-parent crosswalk](docs/ROADMAP_BACKLOG.md#coverage-of-the-original-remaining-outcomes)
and [original ten phase gates](docs/history/ROADMAP_SCOPE_20261017.md) retain every
promise. Each named child and its dependencies live in the existing
[backlog](docs/ROADMAP_BACKLOG.md#concrete-child-outcomes).

| Remaining scope | Known boundary | What must be settled or delivered next |
| --- | --- | --- |
| Fleet and historical content | 17 eventual craft: 9 implemented, 8 absent | Eight SPEC→BUILD-SPLIT→CRAFT-ACCEPT chains; missing evidence/interpretation decisions precede builds. Existing nine still require their applicable full craft/art/role journeys. |
| Station | Nine branches; four service-motion outcomes | Habitat ordinary loop/restart and all four service runtime outcomes accepted on recorded checkpoints. Other branch routes and actual presentation findings remain; parked routes retain their limits. |
| Activities and combat | Twelve activities, six named combat encounters | Complete uncovered ordinary outbound/activity/reward/home journeys, then each legitimate ten-run contract. Cargo replenishment/turnover policy is unresolved; Hauler source integration is a known stock-policy-gated production gap. |
| Worlds | Ember, Aurora, Rime; 21 named shared-world cells | Canonical solo/shared returns, saves, abandonment, crew and repeat visits; source/staged passes cover only their recorded cases. Aurora originals remain waiting and Rime arrival remains parked. |
| Multiplayer | Named browser, helm, role, damage, actor and postdock cases | Dedicated server/two-client baseline, applicable role/reuse cases, original 30-minute endurance and chosen capacity. Release guest count/playing-host decision remains waiting. |
| Recovery and saves | Seven context definitions; accepted cuts retained | Four terminal-only active-run policies remain unresolved; remaining installed/ordinary cuts and migration/corrupt/unsupported data cases need their exact expected behavior and candidate. |
| Presentation, controls, audio and performance | Finite view/device/capture families | Actual defects and native measurements, real devices/audio, accessibility and applicable capture gates. Hardware/authorization dependencies cannot be replaced by headless passes. |
| Release | Existing Windows/Linux checkpoint workflows | Target-list decision, exact final integrated regression/packages/install transactions, licensing/signing and authorized distribution. Native Windows execution/human-review owner exclusions stay in force. |

**Remaining job count and finish date: unknown.** BUILD-SPLIT placeholders,
policy choices and actual visual/performance findings still have unresolved
multiplicities. Do not call a definition, qualification or checkpoint a finished
feature. Do not invent a project percentage from rows, tests or commits.

## Execution now

LIFE-PATROL is accepted on `ea8fe43`. All four station service runtime cards
have passed on their recorded sources. The source is merged, a fresh checkpoint
is published and owned scratch is cleaned. The remote-power source definition is
complete. Its candidate `9a3e16604` passes the full pose regression but fails
Main/ENet’s existing nine-craft live-delta ceiling. The attempt is STOPPED after
one fixture repair; source is pushed, unmerged and no checkpoint is published.

| Remaining work | Readiness | Next bounded action / estimate |
| --- | --- | --- |
| NET-COMPONENT-POWERS | STOPPED after one fixture repair; integration failure | Full pose302 passes, Main/ENet live delta12408 bytes fails unchanged ceiling. [Cumulative result](docs/history/ROADMAP_DELIVERIES.md#net-component-powers--network-envelope-stop-and-priority-review). Next selection must identify a bounded production encoding fix that retains the actual powers and existing size limit before another run. Original card/acceptance retained below. |
| HAULER-CARGO-MANIFEST | Production gap; GATED on HAULER-CARGO-STOCK | Binding still rejects Hauler; generation-floor API already exists. [Stock prerequisite and conserved-source proof](docs/ROADMAP_BACKLOG.md#hauler-supply-integration-boundaries). 60–90 min implementation/focused checks after decision, checkpoint additional; split before 90 min. |

The Hauler stock/custody decision remains the concrete missing prerequisite for
the reviewed independent production alternative. Do not invent stock, a duplicate
generation API or a whole-game absence-of-defects claim. The observed remote-power
network-size failure is the next concrete production boundary to resolve before
implementation; do not extend a service qualification chain. This is a local queue,
not a project estimate.

## Next executable card: NET-COMPONENT-POWERS

**Retained contract, currently STOPPED.** Do not execute unchanged. Initial
42.010s pose failure had one exact fixture sequence repair; repaired pose passed
302 assertions in42.149s, then Main/ENet failed173.347s at live-delta size12408.
Cumulative guarded execution346.467s includes every import/compile/failed run.
Remaining Halyard/local HUD runtime suites and all exports/startups are NOT_RUN.
The estimates below were the original selection, not a renewed budget. Root
priority review stops further diagnosis/repair/runs in this attempt. A separately
frozen production encoding proposal addressing this observed budget failure is
required to reopen; do not remove power channels, raise the ceiling or rename
this card to reset its acceptance/time. No accepted runtime delivery is claimed.

**Player result:** when observing another craft, HUD ENGINE OUTPUT, WEAPONS and
TARGETING percentages agree with that craft’s accepted host telemetry, including
critical-hull stutter and Halyard engineer routing. Parents 11/21 remain open.
This is one production fix; its checks and checkpoint are part of delivery,
not three extra features.

- **Owner/files:** one implementation agent owns
  `scripts/network/network_remote_craft_pose_stream.gd`,
  `scripts/ships/hero_ship.gd`, `scripts/game/game_flow.gd` and the existing
  `tests/network_remote_craft_pose_test.gd`. Extend the existing Halyard role test
  only if needed to prove the routed-value transport. Root integrates, runs checks
  and packages; an independent reviewer checks ordering/authority boundaries.
- **Known cause:** host-active canonical telemetry already carries the three
  powers. Per-craft pose entries omit them, packing drops them, and the HUD only
  overlays host hull/engine/throttle. Use the existing optional primitive power
  fields in that craft’s pose payload; preserve the compressed row layout.
  Settled craft already publish fresh `operation_tick` with their retained pose;
  power updates must use that ordering without manufacturing movement.
- **Implementation:** sample the craft’s actual live powers together; retain a
  finite, bounded complete trio through packing/decoding and accepted ordering;
  expose a detached eligible HUD projection through the existing publisher.
  A newer legacy row without powers clears any older power projection.
- **Completion proof:** extend the existing pose test to deliver packed host
  powers into the actual retained HUD label, including impaired/zero powers,
  critical-hull output and an admitted Halyard route. Check settled updates,
  stale/generation/epoch rejection, destruction, missing-field fallback,
  local-pilot exclusion and clear/re-entry. Raw local telemetry, component report,
  repair ledger and motion stay unchanged. Invalid/partial triples cannot become
  an accepted power projection. Do not claim physical crew admission from a fixture.
- **Commands:** pinned Godot, `--headless --audio-driver Dummy --path <clean-source>
  --script res://tests/network_remote_craft_pose_test.gd`; run the existing
  station-frame pose and Halyard role tests for the affected seams, plus existing
  local `hero_engine_throttle_component_hud_test.gd`. The station-frame test is
  already the independent production Main/ENet integration; no duplicate Main
  suite is added. All four use the same command prefix and existing success
  markers. Each requires exit 0 and its existing success marker. Freeze exact
  commands/source before execution. Terminal samples preserve the actual host
  trio; destruction does not invent different weapon/targeting multiplier semantics.
- **Delivery:** clean-commit checkpoint export, focused checks and silent isolated
  package `--startup-check` with exit 0 and `STARTUP_MENU_READY_OK`; EXE, ZIP and
  actual build notes in `builds/windows/`, using the existing paired workflow.
- **Stop:** first unexpected failure ends the attempt. Record its cause before
  one bounded repair; preserve cumulative time and original acceptance. If the
  implementation will exceed 90 minutes, split the remaining production capability
  before continuing. No new protocol/version/validator family, weapon behavior,
  role authority, full multiplayer endurance or parked-route retry belongs here.

## Turning the remaining scope into executable work

A broad parent stays open until all its original requirements are accepted; this
can coexist with many completed children. Use the backlog as the scope inventory,
then promote a child only when its result, prerequisites, file owner, proof,
estimate and stop condition are explicit, as above. **READY, WAITING and PARKED
must never appear as interchangeable “tasks left.”**

For each missing craft, SPEC must first settle the evidence/interpretation and
required capabilities. BUILD-SPLIT then names the actual hull/access, handling,
role/weapon and recovery deliveries with individual owners and proofs before
implementation. These are a checklist for decomposition, not an invented fixed
number of tasks per ship. CRAFT-ACCEPT retains the original complete craft journey.
An unresolved SPEC remains WAITING; a template or a source audit does not deliver
that ship. The already-asked Titan decision remains pending.

At each delivery, update that child’s result and remaining dependency, give actual
elapsed time against the estimate, and nominate one next action. Keep at most
three executable cards. Broader estimation becomes possible as unknown build
scope and policy choices are resolved; this planning update does not establish
a total job count or release date.

## Latest delivered result

**Habitat patrol runtime coexistence accepted on `ea8fe43`.** The same supported
Player completes all 22 walking goals, opens actual MainAccess through normal
Interact, walks 17.302 m locally within 12 m of the two patrol drones' activity,
returns, boards the original Torrent and remains pilot for 90 seated frames.
Both actual drone poses/clock advance during local and seated intervals; the
same door/home berth/OFFLINE/parked state and default controls persist.

All 77 Python checks, observer/privacy, fresh paired exports, three strict menu-ready
startups and 1,521-entry audit pass. ONE archived route passes in 65.899 s guarded,
zero diagnostics and full input/process cleanup, on the first attempt.
[Windows checkpoint ZIP](builds/windows/MuddsShipyards-ea8fe43-checkpoint.zip)
and [notes](builds/windows/MuddsShipyards-ea8fe43-notes.txt) are published.

[Full result and frozen contract](docs/history/ROADMAP_DELIVERIES.md#habitat-patrol--ordinary-door-walking-and-torrent-boarding-accepted)
retain exact route/door/boarding proof, original caps and actual artifact hashes.
Eleven terminal owners/67 process identities absent; 12 private-profile files/
helpers archived, owned source/profile/extraction removed. Only unique results
remain. No new animation, locomotion, cargo or bunk behavior is claimed. All four
LIFE runtime cards are accepted source-specifically; station art/readability,
other routes, hardware/full-station/final and all 36 parents/ten phase gates stay
OPEN. Unrelated parked failures retain their exact conditions and budgets.

## Parked failures and dependent work

These are unfinished outcomes, not candidates for an unchanged retry. Exact
contracts and cumulative attempt records remain in the retained history.

| Outcome | Last actual result | Condition before more work |
| --- | --- | --- |
| BREACH-INTERRUPTION /13,31,32 | Originale9/repair3c fail board arming35.365/35.638s. After accepted owner fix e3, unchanged probe c159 fails69.957s at atomic-payment commit assertion after cold Resume/one matching receipt; third cold replay NOT_RUN. | Cumulative140.961s STOP/PARK; candidates unmerged/withheld, no recovery checkpoint. No further diagnosis/repair/run, fourth automatic attempt or renamed retry selected; concrete causal fact/change required. |
| HALYARD-GUNNER-DAMAGE /11,16 | Original 51.847s and one caller repair 52.025s both fail co-pilot admission; actual new damage proof NOT_RUN. | Parked after cumulative 103.872s review. No further diagnosis/fix/run without concrete reopening fact/change; candidates unmerged, no weapon defect established. |
| HELM-YAW-HANDBACK / 18,20 | Original146.578s failure; one repair reaches cabin walking then FAIL156.016s at >=0.6m/15s. | Recorded cumulative priority review parked it. Explicit selection required before further diagnosis/fix/run; no movement cause established. |
| CABIN-PASSENGER-ROLE / 18,20 | Candidate38c079086 HUD36 and actual handback PASSENGER pass, full required route fails walking. Unmerged/withheld; no package. | Preserve full route; no acceptance narrowing or automatic second repair. |
| WALK-SALVAGE-ACCESS / 7,9 | Original61.019s plus one repair60.822s both fail outbound20; same supported Player, inspection/return NOT_RUN. | Parked after cumulative review; no further diagnosis/fix/run. INSPECT/REVISIT remain gated; concrete new fact/change required to reopen. |
| KIT-RELOAD / 13,31 | Distinct-process restore30s timeout; one boundary probe records Main ready but no returned first normal frame before deadline. | Different supported production repair must be selected; no unchanged probe, timeout increase or repeated startup profile. |
| HALYARD-BOARD / 16,26 | Two attempts fail the same seat comparison after both real seats. No runtime defect established. | Priority review parked it; no third automatic diagnosis/repair/run. |
| HALYARD-MOVING-CABIN / 16,26 | NOT_RUN; exact retained card requires supported walk/sit/stand/reseat during departure. | GATED on accepted HALYARD-BOARD. |
| HALYARD-AUTHORITY-STOP / 16,26 | NOT_RUN; exact retained card requires usable solo controls after actual server stop. | GATED on accepted moving-cabin route. |

VIP, Ember native close smoke, Rime arrival, HULK revisit, Fire restart, Sandbox,
Convoy/Patrol/Q4/Q5 and software-renderer capture stalls retain their existing
failure budgets and reopen conditions in the backlog/history. Settings originals,
Aurora original arrival bundle, final capacity, hardware/devices and signing retain
specific external waits. Do not repeat already-asked questions or infer approval.
Dedicated server/two-client baseline remains authorized independently of capacity.

## Finish rules for every next task

1. Select one named player/build outcome from the inventory. State parent, exact
   files/owner, prerequisites, proof command/action, unchanged criteria, implementation
   estimate and check duration before starting. Prefer30–60min implementation;
   split before 90min into capabilities, not arbitrary test/evidence stages.
   Before starting a further qualification chain, identify one independently
   executable production alternative or record the concrete missing definition.
   For future cards, distinguish checks protecting the changed behavior from
   larger parent journey gates before implementation; do not retroactively narrow
   a failed card's frozen acceptance.
2. Keep the selected result fixed. A new defect ends that attempt; it does not
   silently enlarge it. Record the failed outcome and remaining work. Failed task
   plus one attempted repair requires cumulative priority review before more work;
   renaming a card does not reset the budget. Reopening parked work also needs
   a named production change, changed environment, resolved dependency or new fact
   addressing its retained failure. Priority review alone is not a reason to rerun.
3. A pass ends verification. Do not repeat accepted checks without a relevant
   change or concrete unresolved concern. Qualification and planning remain labelled
   as such; prefer an identified production gap for the next implementation task.
4. At closure report: what the player can now do, whether it is source-qualified
   or packaged, what failed/remains, and the next single action. Commit/push and
   clean owned scratch. No progress percentage from tests, commits or task rows.
5. Replenish only after reviewing the result against its original parent and
   available independent product work. Report elapsed work against the selected
   card before selecting a successor; never let one session become an unbounded
   sequence of adjacent repairs. Do not append every newly discovered edge case
   to the current chain.
   Keep at most three executable cards; dependent and parked scope stays above or
   in the backlog. Preserve the original parent acceptance until fully proven.

## Validation and final release

Follow [AGENTS.md](AGENTS.md): every automated Godot invocation uses Dummy audio;
headless/private display and explicit x11 under Xvfb; independent abort and owned
input/process cleanup. Never enable or dispatch GitHub Actions. Respect the
existing native Windows execution hold. Scratch belongs in `/srv/mudds-work/`;
protect unrelated and unique work when cleaning.

Meaningful accepted runtime/graphics changes require clean paired Windows/Linux
checkpoints in repository `builds/`, focused checks and strict silent startup
exit0 plus `STARTUP_MENU_READY_OK`. Caller-only qualification does not require
an identical rebuild. Package notes state actual validation and limits.

Current full matrix NOT_RUN; last unfiltered f85957f failed11/1,045 suites.
Native GPU/device/audio/human gates remain unperformed where recorded; VM,
software-renderer or source checks cannot replace them. Project completion requires
every original promise accepted or explicitly owner-deferred beside that promise,
all applicable final-candidate gates passed, and distributed bytes matching the
qualified candidate. No broad parent or phase closes in this reorganization.
