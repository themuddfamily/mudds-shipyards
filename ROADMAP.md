# Development roadmap

**Playable alpha; the full game is unfinished.** Nine of the promised 17 craft
exist. All 36 original parent outcomes and ten phase exit gates remain open.
There is no evidence-backed completion percentage or finish date.

**A roadmap heading is not a work assignment.** Select only a bounded child
with a filled [task card](#task-card-required-before-starting). Its result must
be observable, its pass condition fixed before work starts, and its dependencies
actually satisfied. Missing details mean blocked work, not permission to explore
indefinitely. A completed specification does not count as a completed feature.

Latest playable checkpoint: **27e2955** — [Windows ZIP](builds/windows/MuddsShipyards-27e2955-checkpoint.zip)
([notes](builds/windows/MuddsShipyards-27e2955-notes.txt)) and
[Linux archive](builds/linux/MuddsShipyards-27e2955-linux-x86_64.tar.gz)
([notes](builds/linux/MuddsShipyards-27e2955-linux-notes.txt)).
The Jovian now switches to a complete simplified exterior beyond 120m and
restores close detail below 100m. Original close geometry, native roof LOD,
furniture, access motion, engine/damage effects and crew state are preserved.
All twelve source suites, original production-camera images, three strict startup
checks and the complete paired package audit pass. Ordinary full-craft journeys,
full art and native/GPU/device gates remain open.
[Exact delivery and proof limits](docs/history/ROADMAP_DELIVERIES.md#jovian-whole-lod-delivered-20261105).
Earlier accepted changes, including Hauler/Bomber distant exteriors, remain
included in their recorded scopes.

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

## One goal, one result, one stopping point

The existing [337-record backlog](docs/ROADMAP_BACKLOG.md#concrete-child-outcomes)
retains the requirements and their acceptance contracts. The backlog inventory
and goal classification are closed; do not repeat them. Missing acceptance
fields and owner inputs remain blocked as recorded in their contracts. The
records include completed work, broad containers, implementation, qualification
and owner decisions. They are not 337 unfinished coding tasks. The eight delivery groups below organize that scope;
none is an executable assignment.

Select a bounded child or an explicitly named member of its existing contract.
Give independently deliverable behaviors separate cards. Keep the complete
ordinary journey as a required integration goal; smaller checks never replace
it. No implementation may start from “finish the ship”, “improve multiplayer”
or another broad heading.

## How we will work from this roadmap

### Task card required before starting

Keep the selected card in [Current work](#current-work-and-next-selection),
using the existing goal ID and contract. Fill every field before editing code:

```text
Goal / contract: existing ID and exact member; link to its acceptance contract
Result: one observable player behavior or executable build/release result
Candidate / start: source or package, initial state, location and participants
Owner / files: implementer and exact files; reviewer when needed
Dependencies: prerequisite IDs and accepted results; missing input + owner
Cases: complete finite list, with ordered ordinary actions or literal commands
Expected: observable endpoint/value for EACH case, including preserved behavior
Proof: output location, environment and which scope it can establish
Budget: all-in estimate, absolute start/deadline, original test limits
Stop: correction allowance, independent abort, first-failure endpoint
Close: actual versus expected, status, elapsed cost, merge/push/build/cleanup
```

**A link alone does not fill a field.** Resolve the linked contract to its actual
cases and expected observations on the card. Reuse its values and limits; do not
invent numerical thresholds. A case should read “given this state, perform these
actions, observe this result”. Words such as “polished”, “robust”, “usable” or
“all applicable” need the literal observation that makes them pass or fail.

Use this small table for the cases, then fill the last column at closure:

| Case | Initial state and action | Expected result | Actual result and proof |
| --- | --- | --- | --- |
| Each named case | Exact setup and steps/command | Observable endpoint/value and preserved state | NOT_RUN until performed; then measured result and artifact |

### Missing information has an endpoint

| Situation | Required next action | When that action ends |
| --- | --- | --- |
| Contract field missing | Codex supplies that exact field in its existing contract, using a 15–30 minute bounded definition pass | Finite answer recorded, or exact absent value/artifact, completed search boundary and owner recorded; no rolling research |
| Product choice or external resource missing | State the exact question/artifact and its owner using the [existing input contracts](docs/ROADMAP_BACKLOG.md#blocking-decisions-and-resources) | Answer/resource recorded; no inferred approval and no blocked implementation |
| Runtime or ordinary caller missing, but behavior defined | Select its bounded implementation with a fixed check | Implemented result passes that check, or failure is parked; a caller/component check alone cannot qualify the ordinary journey |
| Prerequisite unfinished | Name its existing ID and required result | Dependency actually passes before dependent work launches |
| Earlier attempt parked | Retain its failure, source, cumulative cost and causal reopening condition | Reopen only under that condition; exhausted allowance/deadline also requires later explicit user reprioritization |

An undefined goal is **BLOCKED definition**; an unavailable choice/resource is
**BLOCKED input**; an unfinished prerequisite is **GATED**. OPEN and UNSCHEDULED
never mean READY. No missing field authorizes an open-ended assignment.

### Fixed budget and failure boundary

Estimate implementation, checks, required checkpoint, integration and cleanup
**together**, at no more than 90 minutes per implementation assignment. Split
larger production capabilities before starting. Full journeys and soaks retain
their original durations; do not shorten them to fit an implementation card.
Default correction allowance is one; freeze it and the absolute deadline first.

Stop at the first unexpected failure and retain the actual operands/output.
A correction needs a demonstrated cause, remaining frozen allowance and an
explicit cumulative-cost decision. A failed final correction or hard deadline
parks the task. New names, branches or smaller subsets never reset costs or
allowance. Exhaustion also requires later explicit user reprioritization;
automatic continuation cannot authorize a retry. No dependent check starts
before its prerequisites pass. Unrelated defects return to their existing owner.

### What counts as finished

A goal is PASS only when **every frozen case passes in the declared scope**,
accepted changes are merged and pushed, any required playable checkpoint is in
`builds/windows/`, and owned branches/worktrees/processes/scratch are cleaned.
Preserve unique rejected source and results before deleting their task refs.
Report retained exceptions. An unfinished task closes as FAIL, BLOCKED or PARKED
with the exact next input/reopening condition; do not quietly move to another
branch. No automatic successor is scheduled by closing a card.

Source tests establish their source scope; staged setup does not establish
ordinary access, and Linux/software rendering does not establish native Windows
or target-GPU performance. Required physical-device and human checks stay open
until performed, subject to the recorded owner exclusions. A completed definition
or child never closes an unperformed gameplay journey or its parent container.

Progress reports use **goal → player/build result → status → proof → blocker →
elapsed cost → next action**. Definitions, validators, test counts and commits
are not a project percentage. Do not invent a finish date from the row count.

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

### Selected: remove archived checkpoint binary duplicates

**Goal:** the owner's requested file cleanup, supporting PACKAGE-FINAL build
storage. This is housekeeping, not gameplay progress or release qualification.
Start: clean pushed `4157ba2e7`; builds/windows46GB + builds/linux39GB, filesystem
free1.9GB. Root owns this mechanical cleanup; one independent read-only reviewer
has checked pairing/reference conventions. No task branch/worktree or engine run.

**Exact scope:** frozen `/srv/mudds-work/checkpoint-storage-cleanup-20261105/plan.json`
contains306 obsolete canonical loose EXE/ELF candidates totaling51,541,891,296
bytes and their unique retained ZIP/TAR. Preserve latest three complete sets
27e2955/84bd54a/c60face, all archives/notes/export results, four installers,
28 older binaries with active tracked references, and any ambiguous/unique file.

| Case/action | Fixed expected result | Actual/proof |
| --- | --- | --- |
| For each frozen regular single-link candidate, inspect its unique archive member | Exact safe member name/type/mode and size; no alias, encryption or duplicate-member ambiguity; archive retained | NOT_RUN |
| Stream-compare every byte and verify archive CRC/integrity, hash both binary/archive, check unchanged expected inode/size/time/mode identities and no running executable owner | Only exact archived duplicates may be unlinked, immediately after identity recheck; no engine execution | NOT_RUN |
| Mismatch/unreadable/ambiguous/archive or identity problem | Preserve original and archive, record literal exception; never delete unique/unverified bytes or retry around a different file | NOT_RUN |
| Finish/restore contract | Latest complete sets, installers, referenced binaries and every archive remain; per-file proof records original hash/member/archive hash; documented restoration; report actual freed bytes and retained exceptions | NOT_RUN |

**Proof/stop:** command/per-file outcomes under the owned folder above. Start
19:08:00UTC2026-11-05 includes readiness; hard19:28:00UTC20min all-in, verification
cutoff19:24 reserves closure. One correction maximum for a demonstrated driver
error; no unchecked deletion. Expected exceptional files stay retained. A driver
failure/deadline stops work and records remaining candidates; no hidden scope or
budget reset. Close with actual accounting, documentation/commit/push and owned
process/scratch cleanup. No new checkpoint because game/source packages do not
change; all ordinary/native/full-release gates remain open.

### Delivered: Jovian distant exterior and playable checkpoint

**CRAFT-ACCEPT-JOVIAN / whole-craft LOD runtime member: PASS.**
Source `27e2955c33b58b5883ee04f9db64c82734435ac7`, integrated in pushed main
`7d76b8ebe`. The complete ordinary craft/LOD/art journey remains open.

| Frozen case | Expected result | Actual result and proof |
| --- | --- | --- |
| Current camera, boundaries and ownership | Initial close; far only >120m, close only <100m; boundaries/dead band retain; invalid inputs ignored; only own cockpit/aboard/real transition forces close | PASS in full 794-assertion Jovian suite, including foreign and real seat/frame cases |
| Exhaustive final membership and static census | Complete exterior with all 26 source macros; far triangles ≤25%close and submissions ≤close; actual visible MultiMesh copies counted | PASS: 17,907/83,538 triangles (21.44%), 36/124 submissions; 26 nonempty macros, no unknown renderer |
| Original close geometry/native roof LOD/furniture and dynamic/authority state | Preserve original arrays/LOD indices/resources/batching, split aperture, access/engine/damage/crew state and within-epoch identities through switches/Main cuts | PASS: actual source hashes/resource IDs, non-default motion/engine cases and original cabin/crew/batching checks; full Main251 retains Hauler/Bomber coverage and all three cycles |
| Twelve complete source suites | Each exit0, one original marker, no raw diagnostics, stable source/import guards | PASS: twelve headless suites, 1,299 assertions; independent actual log/hash/manifest review |
| Actual production-camera images | Three native640×720 panels and1920×720 unscaled strip; complete exterior envelope, matching hull/four engines and readable centre cockpit | PASS: actual77.467/157.458/8.982m cameras select close/far/close, exterior8/8 corners; four originals independently reviewed; original default four-image gate unchanged/unperformed |
| Clean paired checkpoint and full audit | Three strict menu-ready startups, exact complete inventories/all nine predicates, seven repository checkpoint files | PASS: each exit0/one readiness marker/no diagnostics; all1,531 entries audited; files copied with hash/mode equality |

[Commands, measured results, correction and retained records](docs/history/ROADMAP_DELIVERIES.md#jovian-whole-lod-delivered-20261105).
One of three frozen corrections was used: five new test calls used a Bomber-only
seat accessor, aborting fixture cleanup. The inherited Jovian pilot-seat API
restored that path; the full rerun clears all subsequent failures. No runtime,
original assertion, threshold, scope or deadline changed for the correction.

Started18:22:34UTC; owned cleanup19:03:32UTC (40.98min), within the original
19:52:34UTC/90min all-in deadline. Source is merged/pushed; owned branch, worktree,
processes and generated scratch are removed. Only the verified161-member records
archive and closeout remain in the task folder. Final documentation/push time is
recorded in closeout. No next task is selected by closure; all parked attempts
and owner decisions retain their existing gates.

**Cinder Light live role-choice card: PARKED/unaccepted.** Candidates
6eef191c6→38b51455f→50134b4c2 are archived unmerged. Registry59,nine-craft
separation311 and Main boarding59 checks pass. The first actual full HUD suite
fails all six Light viewport/UI-scale cases:body73px versus63px available,
under the unchanged no-scroll criterion. No screenshot,export,checkpoint or
runtime merge. The sole correction fixed three read-only negative-fixture arrays.
[Exact operands,source and invocation history,archive and cleanup](docs/history/ROADMAP_DELIVERIES.md#cinder-light-choice-card-fit-stop-20261105).
Reopening needs explicit reprioritization with prior cost/exhausted allowance and
a concrete text-packing proposal preserving normal fonts,complete instructions/
role/speed/hull/state,the exact trade-off and all original cases. This member
belongs to CRAFT-ACCEPT-CINDER-LIGHT's production-choice contract;the initial
card's CRAFT-GAPS definition ID was a mistaken ownership reference,not a reopened
completed definition or a fresh task/budget. **No further work on this member is selected.**

**Retained player-motion binding: GATED; bounded check closed2026-11-05.**
All nine original2560×1440 PNGs match their existing manifest's byte counts and
SHA256. However,the recorded Player controller hash differs from documented
sourceed359040c;the capture-script hash alone cannot bind that source. The
original complete run log/source-import guard record and exact inspected-image
binding were not found in the declared retained locations. No recapture,registry
upgrade,pixel reinspection,engine run or gameplay change.
[Exact mismatch and search boundary](docs/history/ROADMAP_DELIVERIES.md#player-motion-retained-binding-stop-20261105).
Reopen this binding only with the actual source/run/inspection artifacts;do not
repeat this search unchanged. This closes the16:03:04UTC selection within its
20-minute/16:23:04UTC bound. **No further work on this member is selected.**

**Bulwark whole-craft LOD runtime/checkpoint: PARKED/unaccepted.**
Candidates28c54b642→a2ad76cfd are archived unmerged. Corrected source gates pass
276focused/31production/176Main checks;static far3134/close35829 (35605 in Main)
triangles and74/74submissions satisfy the fixed budget. Required Forward+ capture
exits1 on two unchanged cockpit-clearance assertions. Actual three640×720 panels
and1920×720strip/current-camera selections pass;far is153.1m. Correct images and
source passes cannot accept a smaller delivery. No export,checkpoint or runtime
merge. The sole correction was spent on empty portal-stock geometry and actual
owned weapon-resource snapshots.
[Exact failure, images, archived source and cleanup](docs/history/ROADMAP_DELIVERIES.md#bulwark-lod-cockpit-clearance-stop-20261105).
Reopening requires literal failed clearance operands and reconciliation with the
original geometry/camera contract,plus explicit user reprioritization retaining
prior cost/exhausted allowance and all remaining gates. No further work on this member selected.

**Closed: concrete-goal working plan — documentation PASS, 2026-11-05.**
Independent review: GO. All337 canonical identities/order/kinds and the original
36-parent/ten-phase tables are preserved. Only Scan's selection state and two
stale definition instructions changed in canonical rows; all17 added local links
and whitespace checks pass. Scan now names its missing original failure record;
the blocker register exposes seventeen unresolved travel maxima; final
reconciliation uses its already-defined contract. Gameplay requirements remain
unchanged. This closes the15:16UTC documentation selection within its20-minute
budget/15:36UTC deadline; no gameplay, checkpoint or parked retry is selected.
No task branch/worktree/process/scratch was created. That documentation task
selected no implementation; subsequent runtime deliveries are linked below.

**Halyard whole-craft LOD runtime: PARKED/unaccepted.** Candidates
8fc3d5d64→663649230 are preserved unmerged. Corrected Halyard541/Main176 source
checks pass;static exterior is12928/51768triangles and70/83submissions. Actual
Forward+/llvmpipe capture exits0/diag0 and selects far at154.1m,but the four
standalone images are1280×900 and composite1280×720,cropping the four-view layout.
The required panels1280×720/strip5120×720 were not produced. Root inspected all
five originals;no source success accepts that visual assembly failure.
No exports,checkpoint or runtime merge. The single correction was spent on
classifying three exact late-created Loadmaster cabin cues.
[Exact results,original cropped image and retained source](docs/history/ROADMAP_DELIVERIES.md#halyard-lod-capture-viewport-stop-20261105).
Reopening requires explicit user reprioritization for a harness-only viewport/
content-scale correction,retaining prior cost/exhausted allowance and unchanged
geometry,cameras,thresholds,300s capture and full checkpoint gates. Actual new
images must meet the same dimensions;existing PNG resizing is not proof.
**No further implementation or qualification is selected.**

Accepted recent results stay closed in their stated scopes:

| Goal/member | Accepted result and proof | Still outside that result |
| --- | --- | --- |
| Shared retained-Main all-nine source qualification | [Actual identity/empty-claim/home retention and normal passive repair](docs/history/ROADMAP_DELIVERIES.md#main-nine-component-claims-home-qualified-20261105) | Ordinary input, OS restart, networking and whole-craft acceptance |
| Bulwark editable-source handoff | [Complete editable archive and clean reproduction](docs/history/ROADMAP_DELIVERIES.md#bulwark-editable-source-handoff-accepted-20261105) | Gameplay, art, LOD and native acceptance |
| Hauler distant exterior runtime/checkpoint | [Complete frozen source/image/package delivery](docs/history/ROADMAP_DELIVERIES.md#hauler-whole-lod-delivered-20261105) | Ordinary LOD transitions, full craft/art and native hardware qualification |
| Bomber distant exterior runtime/checkpoint | [Complete frozen source/image/package delivery](docs/history/ROADMAP_DELIVERIES.md#bomber-whole-lod-delivered-20261105) | Ordinary LOD transitions, full craft/art and native hardware qualification |

These are selection constraints, **not a list of tasks running in parallel**:

| Existing goal/member | Current result or blocker | Condition before further work |
| --- | --- | --- |
| [Cinder Light role-choice card](docs/history/ROADMAP_DELIVERIES.md#cinder-light-choice-card-fit-stop-20261105) | PARKED: added line needs73px inside63px body in all six existing fit cases | Explicit reprioritization and bounded text packing that preserves exact trade-off/full instructions/facts/state,normal fonts and original case/tolerance limits;retain cost/exhausted allowance |
| [Bulwark whole-craft LOD runtime](docs/history/ROADMAP_DELIVERIES.md#bulwark-lod-cockpit-clearance-stop-20261105) | PARKED: required capture fails two unchanged cockpit-clearance assertions despite source and dimension passes | Log exact failed operands, reconcile original clearance contract, explicitly reprioritize with prior cost/exhausted allowance; no subset acceptance |
| [Halyard whole-craft LOD runtime](docs/history/ROADMAP_DELIVERIES.md#halyard-lod-capture-viewport-stop-20261105) | PARKED: source passes,but captured strip/panel dimensions crop the staged review layout | Explicitly reprioritize exact harness viewport/content scaling;unchanged image/geometry/camera/package gates and prior cost remain |
| [Rime solo access/outbound caller](docs/history/ROADMAP_DELIVERIES.md#rime-solo-outbound-alignment-stop-20261105) | PARKED: consumed look continues after alignment stage changes; four-tick tolerance fails | Measured input cause/correction and explicit reprioritization; no tuning or tolerance change inferred |
| [Cinder remote terminal handoff](docs/ROADMAP_BACKLOG.md#cinder-remote-crew-moving-handback) | GATED implementation: remote pilot disembark retires helm without supplying the host an exterior A actor | Codex first implements that existing member’s authoritative disembark/body handoff; terminal RPC alone cannot prove physical eligibility; parked B egress remains separate |
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
