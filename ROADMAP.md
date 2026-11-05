# Development roadmap

**Playable alpha; the full game is unfinished.** Nine of the promised 17 craft
exist. All 36 original parent outcomes and ten phase exit gates remain open.
There is no evidence-backed completion percentage or finish date.

**A roadmap heading is not a work assignment.** Select only a bounded child
with a filled [task card](#task-card-required-before-starting). Its result must
be observable, its pass condition fixed before work starts, and its dependencies
actually satisfied. Missing details mean blocked work, not permission to explore
indefinitely. A completed specification does not count as a completed feature.

Latest playable checkpoint: **5bc9a17** — [Windows ZIP](builds/windows/MuddsShipyards-5bc9a17-checkpoint.zip)
([notes](builds/windows/MuddsShipyards-5bc9a17-notes.txt)) and
[Linux archive](builds/linux/MuddsShipyards-5bc9a17-linux-x86_64.tar.gz)
([notes](builds/linux/MuddsShipyards-5bc9a17-linux-notes.txt)).
Shared Rime arrival guidance now correctly invites crew to follow the ice-core
survey and reboard for the host’s return. Actual staged Main/HUD checks pass26
assertions; the existing authenticated shared-survey regression passes77. Full
canonical three-peer arrival/home and native qualification remain OPEN.
[Delivery and exact proof limits](docs/history/ROADMAP_DELIVERIES.md#rime-arrival-guidance-delivered-20261105).
Earlier cancelled-world residency, Ember progress/save/retry, settled resume
retirement, Arrow guidance and dedicated startup remain included in their
recorded scopes.

## Read this as a delivery plan

The [canonical backlog](docs/ROADMAP_BACKLOG.md#concrete-child-outcomes)
retains the original requirements and their detailed acceptance contracts.
Its 337 records include containers, definitions and decisions; **337 is not the
number of coding tasks left**. The [36 original outcomes and ten phase gates](docs/ROADMAP_BACKLOG.md#coverage-of-the-original-remaining-outcomes)
remain open. Accepted and failed attempts belong in the
[delivery history](docs/history/ROADMAP_DELIVERIES.md), not in the next-work queue.

Use these three levels:

| Level | What it means | When it closes |
| --- | --- | --- |
| Product outcome | A complete craft, activity, world journey or release requirement | Every named child and its complete integration gate passes |
| Delivery goal | One independently usable game behavior or executable build capability | The fixed player/build action passes, accepted code is merged/pushed, required checkpoint is available and owned cleanup is complete |
| Qualification goal | One named journey, package, hardware or device check | Its original complete cases pass on the declared candidate and environment |

A source map, specification, test fixture or passing component check does not
close a delivery goal for a behavior it has not demonstrated. A completed child
does not close its parent. An unavailable owner decision or device is a named
blocked dependency, not an indefinite coding assignment.

<a id="current-planning-goal-finish-the-executable-breakdown"></a>

## Breakdown defined; readiness checked per task

**PLAN-NEXT is DONE as a definition task.** Reuse the existing
[contracts and dependencies](docs/ROADMAP_BACKLOG.md#remaining-contract-gaps--plan-next);
do not start another inventory or rewrite every contract before shipping work.
Before selecting a child, resolve its contract into the short card below. If a
field is missing, supply that field or name its blocker. Do not treat a broad
heading or a linked document as an executable assignment.

A ready delivery goal must answer all five questions:

1. **What changes for the player?** One observable behavior, or one executable
   build/release result. No standalone research or validator milestone.
2. **What exactly do we do to prove it?** Fixed initial state, participants and
   ordered actions or command; name every included case.
3. **What observations pass or fail it?** Expected values, preserved behavior,
   existing limits and the environment in which they are measured.
4. **What must already work?** Exact dependencies with actual accepted results;
   name any missing decision, artifact, caller or device and its owner.
5. **Where does this assignment end?** Owned files, total estimate, deadline,
   correction limit, deliverables and cleanup. No automatic successor task.

If several behaviors can ship independently, give each its own card before
implementation. Keep their complete journey as a separate required integration
gate. Do not invent easier thresholds or replace ordinary player access with
staged setup merely to make a small task pass.

## How we will work from this roadmap

Each coding assignment delivers **one observable game or build result** and has a
written pass/fail check before editing begins. Broad features below are completion
containers; their existing children live in the [canonical backlog](docs/ROADMAP_BACKLOG.md#concrete-child-outcomes).
A missing driver is an implementation task. An unanswered design choice or
unavailable device names the exact input and owner. Neither counts as completion.

Every executable goal uses this short contract in its existing backlog row or
linked section. Broad parents retain their finite child lists and close only
when those children pass; they are never selected as one coding task.

### Task card required before starting

Fill this card in the current-work section before selecting an implementation.
Link the existing contract rather than copying its full specification. Do not
create a new planning file, validator or evidence format for the card.

```text
Goal: existing child ID / exact bounded member, with contract link
Result: one sentence describing what the player or build can do afterward
Start and owner: source/package, initial state, participants, owned files
Dependencies: exact IDs/results already passed; missing input + owner if blocked
Action: literal command or numbered ordinary player steps
Pass: expected observations/values for each included case; preserved behavior
Proof: output location and environment; what this check does and does not establish
Budget: estimate through cleanup, start/deadline, existing test/correction limits
Endpoint: deliver and close, or retain failure and park at the declared stop
```

No placeholder or unresolved adjective is an acceptance criterion. For example,
“improve crew joining” is too broad; “a fresh client joins the landed host through
the normal browser, takes a free berth, and can walk in that cabin” is an
observable result. Its card must still bind the host/client setup, permitted
identities, exact action sequence, deadlines and expected observations from the
existing contract. This example selects no trial and reopens no parked task.

Freeze the action and pass conditions before implementation. Record the actual
observation beside each expected result at closure. A failed result cannot be
made successful by weakening its threshold, dropping a case or substituting a
component check. Changing an intended requirement is an explicit scope decision;
retain the original failure and explain the change before selecting work under
the revised requirement.

If a result needs several independently deliverable behaviors, split those
behaviors before starting and give each its own pass check. Keep the complete
journey as a required integration gate. Do not split by research, validator,
test-writing or commit count and call those pieces delivered features.

Completion means the declared result actually passes its check. A component
test proves only its component scope; a staged setup does not prove ordinary
player access, and a silent Linux package probe does not prove native Windows
behavior. Record missing integration, hardware and human checks explicitly.

| Field | Required content |
| --- | --- |
| Goal | Existing ID and one observable player or build result |
| Start | Exact source/package, saved state, location and participants |
| Action | Literal command or ordered ordinary player steps |
| Pass | Expected endpoint/value for every included case, fixed before work; actual observations at closure |
| Proof | Actual log, screenshot, artifact or physical observation; identify its environment |
| Prerequisites | Existing IDs and required results, or the exact missing answer/artifact and owner |
| Budget and stop | Estimate, absolute deadline, original test limits, correction allowance and independent abort |
| Close | PASS/FAIL/BLOCKED/PARKED; merge/push accepted work, checkpoint when required, owned cleanup |

An undefined action, endpoint or expected value makes the goal **BLOCKED
definition**. An unavailable decision/device makes it **BLOCKED input**. Supply
only that exact missing field in the same contract; do not expand into another
roadmap audit. A missing implementation or test caller is different: building it
can be a delivery goal once its intended behavior and acceptance are fixed.
Qualification waits until that implementation and its caller actually work.
“Improve”, “polish”, “finish” or “usable” without a linked literal check is not a
ready assignment. Existing full-journey and hardware gates keep their limits.

Include owned files in the starting point and preserved state in the pass
criteria. A repair must reproduce the old failure and pass after the change.
Estimate implementation, checks, required checkpoint, integration and cleanup
together at no more than90minutes; split larger production capabilities before
starting. Default correction allowance is one. Full journeys and soaks retain
their original durations even when implementation is split.

Stop at the first unexpected failure. A correction needs a demonstrated cause,
remaining frozen allowance and explicit cumulative-cost decision; a failed final
correction or hard deadline parks the task. New labels/branches never reset costs,
limits or allowance. Preserve failed source/results. Reopening a parked task
requires its recorded causal condition. An exhausted allowance or deadline also
requires later explicit user reprioritization, retaining prior cost; neither a
wording change nor automatic continuation authorizes a retry.
Dependent checks launch only after prerequisites actually pass.

Completed results stay closed in their stated source/package scope. New unrelated
defects return to their existing owner instead of enlarging the assignment.
Containers close only when every explicitly named member passes. Required human,
physical-device and native-hardware checks stay open until actually performed.

Report **goal → visible result → status → proof → remaining blocker → elapsed
time → next action**. Definitions, validators, tests and commits are not a project
percentage. The inventory has337 records, including definitions and containers;
that is not a remaining implementation count. PLAN-NEXT's definition is accepted;
actual implementation, qualification and exact owner dependencies remain in the
[existing contracts](docs/ROADMAP_BACKLOG.md#remaining-contract-gaps--plan-next).

## What finishing means

The full original scope is retained. A smaller release would require an explicit
scope decision; this plan does not make one.

| Delivery | Concrete finish line | Canonical goals |
| --- | --- | --- |
| Complete game loop and station | Final-package Guided 3/3, original all-nine/54-waypoint Sandbox/recovery 1/1 and original Settings/re-entry 1/1; all nine named station branches physically usable, required interactions/revisit complete | [Core and station proof](docs/ROADMAP_BACKLOG.md#proof-core) |
| All 17 craft | All twelve originals plus five modern additions exist; each passes its specified boarding, flight, actual functions, damage/recovery, strict home landing/exit/reuse, cross-craft and Main re-entry checks | [Craft proof and missing specifications](docs/ROADMAP_BACKLOG.md#proof-craft) |
| Combat and twelve activities | Real player weapons achieve the named encounter results; every activity completes its actual objective, durable result and usable home return; all twelve required ten-run repeats and Hulk revisit pass | [Combat](docs/ROADMAP_BACKLOG.md#proof-combat), [activity proof](docs/ROADMAP_BACKLOG.md#proof-activity) |
| Three worlds and shared travel | Complete Ember, Aurora and Rime canonical physical round trips, required survey/reward/save/abandonment outcomes and all 21 explicitly named shared-world cases | [World proof](docs/ROADMAP_BACKLOG.md#proof-world) |
| Supported multiplayer | Complete server/two-client baseline and remaining role/helm/actor/browser/reconnect cases; original 30-minute session with required adverse networking; chosen supported capacity qualified | [Multiplayer proof](docs/ROADMAP_BACKLOG.md#proof-network) |
| Durable recovery | Named real-file interruptions restart in the settled supported state, preserve accepted progress/debt, pay once and permit ordinary continuation; migration/corrupt/unsupported data handled correctly | [Recovery proof](docs/ROADMAP_BACKLOG.md#proof-recovery) |
| Presentation and hardware quality | Existing 13 capture sets/143 PNGs reviewed; required UI/device/comfort/audio cases pass; representative actual hardware meets declared performance budgets | [Quality proof](docs/ROADMAP_BACKLOG.md#proof-quality) |
| Ship the exact candidate | Unfiltered local matrix, required ordinary routes, packages/install transactions, rights, trusted signing and authorized downloadable-byte identity pass on one integrated candidate | [Release proof](docs/ROADMAP_BACKLOG.md#proof-release) |

Parents 3/27 share the same 21 world cases; 6/35 share one final matrix; 11/21
share the damage work. Breach/Torpedo combat and activity journeys are reused,
not counted as duplicate deliveries. [All 36 promises and ten gates](docs/ROADMAP_BACKLOG.md#coverage-of-the-original-remaining-outcomes).

[Final defect reconciliation](docs/ROADMAP_BACKLOG.md#final-candidate-defect-inventory)
now specifies the existing ledger/result inputs, candidate build-note inventory
and exact blocking verdict. Actual candidate review and implementation/qualification
remain open; zero known bugs alone cannot pass unfinished release journeys.

[Torrent remaining damage](docs/ROADMAP_BACKLOG.md#torrent-remaining-contact-repair-contract)
now fixes hit budgets and actual component consumers. It also identifies the
missing legitimate return path after wing/engine failure: the defender phase
blocks landing, so those cases cannot yet be selected for execution.

Existing [docking recovery](docs/ROADMAP_BACKLOG.md#installed-recovery-exact-cuts),
[Halyard engineer](docs/ROADMAP_BACKLOG.md#halyard-engineer-moving-return),
[Zenith contact/repair](docs/ROADMAP_BACKLOG.md#zenith-remaining-contact-repair-contract)
and [caption episode](docs/ROADMAP_BACKLOG.md#caption-ordinary-episode-contract)
contracts already define their acceptance fields. Their remaining work is the
named implementation and qualification, with parked prerequisites preserved;
do not restart those definition surveys from stale status wording.

[Packaged Ember abandonment](docs/ROADMAP_BACKLOG.md#ember-packaged-physical-abandon-contract)
now names the real pause-menu action, incomplete checkpoint/data checks and
physical home/reuse endpoint. Its normal Save integration and complete input
caller remain missing; the parked outbound gate remains a prerequisite.

[Exported dedicated authority](docs/ROADMAP_BACKLOG.md#packaged-dedicated-authority-contract)
now has a concrete Boot/CLI, listening, orderly one-session exit and packaged
two-client acceptance contract. The accepted source harness remains narrower;
normal Boot launch and optional orderly session exit are delivered on24ed6bc86;
packaged gameplay participation and full qualification remain open.

## Current work and next selection

**Selected: Halyard whole-craft LOD runtime implementation.**
[Existing full LOD contract](docs/ROADMAP_BACKLOG.md#current-craft-lod-contract).
This selects the independently deliverable production capability,not the full
ordinary journey/transition-image qualification. That complete LOD member and
CRAFT-ACCEPT-HALYARD remain OPEN until their original ordinary views pass.

- **Result:** actual current-camera separation switches the complete static
  Halyard exterior to one retained far representation beyond120m and back below
  100m;close geometry/cabin/cockpit/dynamic presentation remains authored and
  functional. Far static triangles≤25%close and submissions≤close. No collision,
  seat,berth,weapon,component,network or interaction authority moves into LOD roots.
- **Start/ownership:** clean main94d800eb5;freeze exact clean candidate before
  checks/exports. One implementer owns scripts/ships/halyard_crew_transport.gd,
  tests/halyard_crew_transport_test.gd and tests/capture_halyard_camera_views.gd;
  one independent high-risk reviewer. Root owns docs/execution/inspection/clean
  exports/checkpoint/merge/push/owned cleanup. No other parked LOD/native trial.
- **Dependencies:** existing Halyard model/finish/route/furniture contract and
  all-nine retained-Main component/empty-claim/home source qualification00f801b1e
  accepted/merged54b11c70c. No new lifecycle definition or actor/role prerequisite.
  Preserve original named close geometry paths and existing furniture100±10m.
- **Action/pass:** build far static pressure-body/nose/shoulders/roof/belly,
  arch/yoke/engine housings/gear/flank-window macroforms once with existing
  materials/builders. Classify EVERY actual exterior renderer close/far/shared;
  preserve shared canopy/interior/hatches/damage vane/engine cores/plumes/lights
  and their state/identity. Keep exact100/120/dead-band retention;negative/nonfinite
  distances cannot mutate. Forceclose only for actual own current CockpitCamera,
  aboard interior Player camera and actual own boarding/disembark transition;
  unrelated camera/name/cached flag is insufficient. Generic Mesh/MultiMesh
  census must cover actual geometry/copies/submissions;no ArrayMesh-only shortcut.
  Exactly one complete static exterior per observation,no resource/node rebuild,
  duplicate listener,authority/query/registration mutation. Keep quiet actual
  source/stream/body/shapes/anchors/claims/home/component snapshots identical
  within each lifecycle epoch,then repeat after the existing retained-Main cut.
- **Focused proof:** extend existing Halyard suite,original300s/sentinel
  HALYARD_CREW_TRANSPORT_TEST_OK/OS0/diag0;actual current-camera,threshold/boundary/
  invalid inputs,own-camera/transition overrides,exhaustive membership,budget,
  authority/resource retention and re-entry cases. Preserve old close allocation
  census honestly;full new LOD/global cost includes far allocations. Run existing
  all-nine Main suite300s after source PASS. Sequential admission,raw/source/cache
  guards and fresh private headless/Dummy profiles;first failure stops.
- **Staged image sanity:** existing four-panel production-camera harness keeps
  default20/44/impaired44/cockpit behavior. An explicit --lod-review mode may
  set ONLY its fixture far-panel maximum chase distance160m and request150m,
  because production Halyard clamps at44m. Record actual current camera/distance/
  selected representation;production camera limits never change. Same own
  ShipCamera,no new beauty camera or registered image count. Save the strip+
  four original-size panels to owned output;inspect all for hull holes/double
  hull,material/clipping and retained canopy/engine/damage/cockpit cues. This is
  staged/fixture-camera source sanity,not ordinary distance/pilot/native proof.
  Add phase logs/270s internal watchdog and original300s independent outer;
  isolated Xvfb,explicitx11/Dummy,Forward+software renderer/actual environment
  recorded. All source/camera/capture staging and tighter limits remain disclosed.
- **Deliver/close:** meaningful graphics change requires clean-commit paired
  Windows/Linux checkpoint in repository builds/,relevant source checks,actual
  archive strict startup OS0/exactly1STARTUP_MENU_READY_OK/diag0,existing package
  identity/payload audit and concise player-visible/actual-validation notes.
  No native Windows/GPU/device/human/release claim. Raw under
  /srv/mudds-work/halyard-whole-lod-20261105/;verified archive before owned
  branch/worktree/profile/cache/helper cleanup. Accepted runtime integrated/pushed;
  no green subset if any declared source/image/package condition fails.
- **Budget/stop:** original preparation2026-11-05 14:17UTC,estimate80–85min,
  hard15:47UTC90min all-in. Source readiness14:52,checks14:58,capture by15:02,
  checkpoint by15:22,closure reserve through15:47. Preserve source300/capture300
  and ordinary900/960/other parked caps;no ordinary run selected. One total
  demonstrated-cause correction after independent cumulative-cost GO. First
  unexpected failure stops dependent checks;failed final correction/deadline
  parks with unique source/raw preserved. No new label/budget or automatic retry.

**Closed: shared retained-Main all-nine component/empty-claim/home source
qualification — PASS.** Qualified00f801b1e,merged54b11c70c. All nine craft retain
actual component/hull/model/shape/home identities and empty claims through the
original three paused detach/re-entry cycles,then show normal eligible passive
repair. Full existing suite exits0 in69.166s with one marker,176assertions,
zero diagnostics and stable source/cache guards.
[Exact scoped proof, first failure/correction and cleanup](docs/history/ROADMAP_DELIVERIES.md#main-nine-component-claims-home-qualified-20261105).
The fixture explicitly records the two unavailable Cinder legacy discovery-area
retirement bits;it makes no active-role restoration claim. Ordinary input,
OS restart,network,LOD and hardware/full-craft acceptance remain OPEN.
**This source qualification stays closed;the new Halyard runtime task is selected above.** Latest playable remains5bc9a17.

**Rime solo access/outbound caller: PARKED/unaccepted.** Candidates
e8635e474→6bd8712e5 are preserved unmerged. Actual package trial stops54.215s
at alignment after four neutral ticks: dot.99894 at entry falls to.92396 while
residual look is consumed; fixed minimum.995. Destination request remains0;
no canonical cruise,landing,exterior/surface or normal UI OS0 was reached.
Zero diagnostics and full owned input/process cleanup; no game handling defect
is established. The sole correction was spent preserving CLI choice order.
[Exact proof, retained source and cleanup](docs/history/ROADMAP_DELIVERIES.md#rime-solo-outbound-alignment-stop-20261105).
Reopening needs measured native-look cause/bounded correction and later explicit
user reprioritization retaining prior cost/exhausted allowance and original limits.
**The Rime attempt remains unselected.**

**Earlier closed member: Bulwark editable-source handoff — PASS.** Frozen source
155cea002 supplies a complete editable archive and reproduction notes. A fresh
empty-cache import and both named source suites pass (158 and31 checks,
zero failures/diagnostics), with all12,011 archived files unchanged afterward.
[Artifact, exact results and proof limits](docs/history/ROADMAP_DELIVERIES.md#bulwark-editable-source-handoff-accepted-20261105).
Owned reconstruction/profile/process cleanup is complete. This closes only the
source handoff; full Bulwark gameplay, art, LOD and native acceptance stay open.
Latest playable remains **5bc9a17**, linked above.

These are selection constraints, **not a list of tasks running in parallel**:

| Existing goal/member | Current result or blocker | Condition before further work |
| --- | --- | --- |
| [Rime solo access/outbound caller](docs/history/ROADMAP_DELIVERIES.md#rime-solo-outbound-alignment-stop-20261105) | PARKED: consumed look continues after alignment stage changes; four-tick tolerance fails | Measured input cause/correction and explicit reprioritization; no tuning or tolerance change inferred |
| [Titan specification](docs/design/TITAN_IMPLEMENTATION_PROPOSAL.md) | BLOCKED input: prepared proposal awaits the user's design decision | Record adoption or exact revisions; no construction before approval |
| [Halyard fresh-Main re-entry](docs/history/ROADMAP_DELIVERIES.md#halyard-fresh-main-offtree-stop-20261105) | PARKED: off-tree cabin-transform errors during actual HUD Restart Shift; no complete re-entry pass | Focused repair/retry request unanswered; original12:47:51UTC deadline expired. Requires explicit reprioritization, retaining cost and exhausted allowance |
| [Jovian first kit-delivery caller](docs/history/ROADMAP_DELIVERIES.md#jovian-native-caller-pause-epoch-stop-20261105) | PARKED: observer motion epoch jumps across Resume before walking; no movement defect established | Concrete pause/freshness correction and explicit reprioritization; original limits/cost remain |
| [Guided flight-observation caller](docs/history/ROADMAP_DELIVERIES.md#guided-flight-observation-stimulus-stop-20261105) | PARKED: requested120px input observed as about150px; exact cause unmeasured | Demonstrated input-unit cause and explicit reprioritization; no renamed retry |
| [Cinder Light whole-craft LOD](docs/history/ROADMAP_DELIVERIES.md#cinder-light-whole-lod-render-stop-20261105) | PARKED: capture timed out without an image; declared internal watchdog missing | Retry request unanswered and11:12:11UTC deadline expired; explicit reprioritization required |
| [Arrow whole-craft LOD](docs/history/ROADMAP_DELIVERIES.md#arrow-whole-lod-typed-membership-stop-20261105) | PARKED: typed mesh-array membership fails on Node3D | Type-safe correction and explicit reprioritization retaining exhausted allowance |
| [Zenith whole-craft LOD](docs/history/ROADMAP_DELIVERIES.md#zenith-modern-lod-census-stop-20261105) | PARKED: ArrayMesh-only method called on BoxMesh | Concrete mesh-type correction and explicit reprioritization retaining exhausted allowance |
| [Cinder retained-cabin readmission](docs/history/ROADMAP_DELIVERIES.md#cinder-standing-readmission-initial-chair-stop-20261105) | PARKED: initial Navigator chair Interact fails before rejoin | Diagnose that rejection, preserve landing guard, explicitly reprioritize |
| [Cinder guest egress](docs/history/ROADMAP_DELIVERIES.md#cinder-guest-egress-home-gate-stop-20261105) | PARKED: host home-ramp eligibility fails before guest launch | Satisfy the recorded causal reopening and cumulative-cost conditions |
| [Landed-crew browser entry](docs/history/ROADMAP_DELIVERIES.md#landed-crew-admission-ui-entry-stop-20261105) | PARKED: failed before admission; no joining feature accepted | Satisfy its recorded reopening conditions; no subset pass |

Every parked source/result remains recoverable from its linked delivery record.
Owned branches/worktrees/scratch for the closed attempts are cleaned up. Their
complete routes, failures, original budgets and correction limits stay binding;
a new label or automatic continuation cannot reset them.

Previously accepted [Rime arrival guidance](docs/history/ROADMAP_DELIVERIES.md#rime-arrival-guidance-delivered-20261105),
[retired-world residency](docs/history/ROADMAP_DELIVERIES.md#retired-world-residency-delivered-20261105)
and [Ember passive progress](docs/history/ROADMAP_DELIVERIES.md#ember-passive-progress-delivered-20261105)
remain closed in their recorded scopes. Aurora/Rime settled resume retirement,
Ember Save Progress, Arrow guidance and exported dedicated startup also retain
their accepted scopes. Halyard physical egress and Ember outbound remain parked
at their previously recorded station-spawn and planetary-gravity caller failures.
Do not reselect accepted components or use them to pass an unperformed full journey.

## Selecting work after the breakdown

Select one ready delivery or qualification goal from an existing row; fill its
card before editing or running checks. A broad craft/activity/world container is never one assignment. Follow
literal prerequisite IDs; independent ready capabilities may run in parallel
with disjoint ownership. A parked task needs its recorded causal reopening
condition and cumulative-cost decision before selection; exhausted limits also
require the explicit user reprioritization described above.

Close each assignment before moving on: actual result and proof, merge/push
accepted changes, required playable checkpoint, and owned branch/worktree/process
cleanup. Preserve unique rejected source without merging it. Report retained
exceptions explicitly. A new failure belongs to its existing goal; it does not
automatically enlarge the current task.

## Validation and final release

Automated Godot always uses Dummy audio, headless or private Xvfb with explicit
x11. Audible output requires authorization. GitHub Actions remains disabled.
Native Windows execution and mandatory human review remain owner-excluded;
unperformed facts stay NOT_RUN. Applicable Linux/native GPU/device/audio gates
remain; simulated checks cannot supply physical measurements.

The final exit is one accepted candidate with zeroP0/P1, explicitP2 dispositions,
required complete ordinary journeys and unfiltered local matrix, matching
installable artifacts, settled rights/signatures and authorized downloaded-byte
identity. All [ten phase exits](docs/ROADMAP_BACKLOG.md#original-phase-gates-and-completion)
remain binding. Missing design decisions or hardware access stay named blockers;
they do not become indefinite implementation tasks.
