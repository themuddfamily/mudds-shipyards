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

**Active delivery: complete Guided flight-observation caller.** Existing
[vertical-slice flight observations](docs/ROADMAP_BACKLOG.md#vertical-slice-flight-observations),
also a prerequisite of the still-open motion startup caller.

- **Result:** an opt-in ordinary Guided run records and checks actual mouse/
  command/backlog, chase/cockpit/zoom/sight and same-frame HUD cue behavior, then
  completes the unchanged combat/home/OFFLINE/physical exit/normal Quit route.
  This supplies an executable release capability, not a new control scheme.
- **Start/owner:** clean0acc2ae0d; implementation owns only existing
  `tools/release/run_native_sortie.py`, `tools/release/test_native_sortie.py` and
  `scripts/diagnostics/native_sortie_observer.gd`. Before check/source freeze,
  review identified that the actual decorated telemetry is temporary. Root also
  owns the passive publication signal in `scripts/ui/hud.gd` so the observer can
  read the real input separately from the cue's transformed output; no inferred
  ingress or duplicate decoration substitutes for this predicate.
  Root owns frozen package/
  artifact preparation, export/checkpoint, integration/docs/cleanup. Independent
  review covers passive readback, default-route preservation and safety gates.
- **Dependencies:** accepted ordinary Guided driver/exit, actual flight/camera/
  cue implementations and exact source contracts exist. No prior exact parked
  flight-observation caller was found in bounded contract/history/ref checks.
  Do not reopen the unrelated colour Guided, rollback or Cinder capture cases.
- **Action:** add `--observe-flight` only for `--route guided`, retaining existing
  private Boot observer admission and default input sampler. Old driver must
  reject this missing option before launching. Build a clean candidate; run one
  extended Guided and two unchanged Guided runs on its exact Linux package,
  each fresh profile. Preserve original300s per process/330s outer throughout.
- **Pass:** at actual TARGET_PRACTICE within5m of(0,8,-78),z<-66,ONLINE/intact/
  airborne/free home lease/no assist or obstruction, hold brake until speed≤.8.
  Deliver one120px OS mouse impulse and record actual event/command/backlog;
  require physical attitude response and initial chase lag>.5°,then45 neutral
  60Hz physics ticks with finite orthonormal poses,nose-locked optics,lag≤8.1°,
  monotone decay within.05° tolerance and final<.25°. No provider/physics/time/
  pose injection. Actual V switches require fresh edges/current camera and
  lag≤.1°. Cockpit sight uses the existing five rays/near/alignment/panel/readout
  requirements. One chase wheel step gives one sampled zoom command and1.5m
  clamped9…24; cockpit wheel leaves stored chase zoom unchanged. Collision
  retraction is not a stored-zoom failure. Same-frame actual velocity/camera/
  decorated telemetry/HUD cue independently obey projection/safe ellipse/
  visibility at departure/turn/stop/views; reticle remains fixed and both hide
  after physical home exit. Then all original Guided combat/home/usable-exit/
  UIOS0 predicates pass. Preserve actual final view/zoom via normal inputs only.
- **Proof:** existing focused safety tests and affected flight source checks pass,
  source/Python syntax clean. Three actual isolated Xvfb/x11/Dummy/dummy-renderer
  ordinary runs exit0 with zero diagnostics, full results and input-release/
  process-reap evidence. Numeric producer/consumer readbacks do not qualify
  rendered pixels, physical mouse polling, native GPU or final-game GUIDED-FINAL.
  Full three-stage motion Save/cold/Reset caller remains OPEN; this complete
  prerequisite does not replace it or reduce original3/3 final requirements.
- **Budget/stop:** original assessment start2026-11-05 10:36:22UTC; all-in deadline
 12:06:22 (90minutes including mapping/code/checks/build/three routes/cleanup).
  One cause-bound correction round total; source/action/checks freeze before
  execution. First unexpected failure stops dependent checks; failed final
  correction or hard stop parks source/results without an accepted subset.
  Original source-suite300s and per-route300s/outer330s remain unchanged.
- **Close:** accepted code gets clean-commit Windows/Linux checkpoint, three
  strict startup checks and paired package audit, merge/push and owned cleanup.
  All Godot Dummy; input automation private Xvfb explicit x11 with independent
  abort/release/reap. No Forward+ capture, CI enablement or distribution is selected.


**Cinder Light whole-craft LOD: PARKED/unaccepted.** Candidate8dc9b6496 is
archived unmerged. Focused256/full317 and canopy6/damage7/silhouette9 source
checks pass; far static geometry measures6022/39142triangles (15.385%) and38/64
submissions. Required Forward+ capture times out at110s with no image or frame
marker; its exact stalled stage is unmeasured. No new checkpoint or smaller
accepted subset. The declared90s internal watchdog was not implemented; only
outer110s enforcement is proved. [Exact stop and archive](docs/history/ROADMAP_DELIVERIES.md#cinder-light-whole-lod-render-stop-20261105).

A single bounded capture retry has been requested from the user, with phase
logs/watchdog, proposed300s internal/330s outer, unchanged LOD code and original
11:12:11UTC all-in deadline/prior cost. **No approval has been received; no retry
is selected or authorized.** The exhausted correction limit and render stop
remain in force. Owned worktrees/branch/scratch are cleaned up; a later explicit
reprioritization can recover the verified source archive.

**Shared Rime arrival guidance: DELIVERED on5bc9a1705.** Both the host objective
and blocked repeat-action toast use the existing contract’s correct shared-survey
message. STAND IN CABIN, Aurora/solo/other-phase guidance and survey/authority/
reward state are preserved. Focused26/shared-survey77 checks, clean exports,
three strict startups and paired package audit pass. The checkpoint is linked
above; full baseline/native gates remain open. Accepted source is pushed and
owned branch/worktree/scratch cleanup is complete.
[Exact scope and closure](docs/history/ROADMAP_DELIVERIES.md#rime-arrival-guidance-delivered-20261105).

**Arrow whole-craft LOD: PARKED/unaccepted.** Candidate75a413ec8 is archived
unmerged. Corrected scripts parse cleanly, but the first focused runtime check
fails during far-exterior construction: an ancestor Node3D is searched in a
typed mesh array. Only API existence passed; geometry budget, switching,
authority/re-entry, captures and packaging remain unproved. The single correction
round is exhausted. No build was made; latest playable remains6474bda.
[Failure, archive and cleanup](docs/history/ROADMAP_DELIVERIES.md#arrow-whole-lod-typed-membership-stop-20261105).
Reopening requires explicit user reprioritization retaining prior cost and the
exhausted limit, plus type-safe membership during ancestor traversal. The full
existing acceptance contract remains binding; no renamed retry is selected.

**Roadmap clarification delivered (documentation only).** The front page now
distinguishes product outcomes, bounded deliveries and qualification, and fixes
the readiness/proof/closure rules. All337 canonical rows are unchanged; local
roadmap links resolve and independent review checked the selection rules. No
gameplay result or qualification is claimed by this documentation change.

**Cinder retained-cabin standing readmission: PARKED/unaccepted.** Candidate
5982bafd0 is archived unmerged. The old-runtime run reached the intended first
rejoined E failure, but the candidate stopped earlier: initial Navigator chair E
did not confirm. Its disconnect/rejoin/readmission result remains unproved.
The shared Halyard regression passes34 assertions; that does not qualify Cinder.
The frozen correction allowance is exhausted. No checkpoint was built; latest
playable remains6474bda. Owned worktrees, branch and scratch are cleaned up.
[Exact results, archive and reopening conditions](docs/history/ROADMAP_DELIVERIES.md#cinder-standing-readmission-initial-chair-stop-20261105).

Do not select a renamed retry. Reopening requires an actionable diagnosis of the
actual initial chair rejection, preservation of the authoritative landing guard,
and explicit user reprioritization retaining the prior cost and exhausted limit.
Other independent ready goals remain selectable under the rules below.

The
[Cinder physical guest exit attempt](docs/history/ROADMAP_DELIVERIES.md#cinder-guest-egress-home-gate-stop-20261105)
is **PARKED/unaccepted** at host home-ramp eligibility, before any guest process
launched. The candidate passes 97 Hauler component and 334 codec assertions,
but physical exit/walk/reboard is unproved. Source is preserved unmerged; no
checkpoint was built. Fresh-session admission and remote cargo transfer remain
separate open capabilities.

The
[retired-world residency capability](docs/history/ROADMAP_DELIVERIES.md#retired-world-residency-delivered-20261105)
is **DELIVERED** on 6474bda with the checkpoint linked above. Actual source/Main
checks prove both worlds' normal coordinator unload and deferred scene/terrain
free after staged cancelled approaches leave the envelope; full shared/ordinary
cancellation journeys and native qualification remain open.

The bounded
[Zenith modern LOD attempt](docs/history/ROADMAP_DELIVERIES.md#zenith-modern-lod-census-stop-20261105)
is **PARKED/unaccepted**: its new census calls an ArrayMesh-only method on
BoxMesh. The sole correction was spent on an earlier null-index assumption.
No complete modern LOD sequence, rendered pair or checkpoint passed; the
candidate is preserved unmerged. Existing full Zenith qualification stays open.

Earlier [Ember passive shared progress](docs/history/ROADMAP_DELIVERIES.md#ember-passive-progress-delivered-20261105)
on **d525554** remains included. A fresh observer receives the
host's real survey progress; the exterior HUD presentation has a separately
staged focused check. Physical late admission and full ordinary journeys remain
unproved. The subsequent [landed-crew browser-entry attempt](docs/history/ROADMAP_DELIVERIES.md#landed-crew-admission-ui-entry-stop-20261105)
is PARKED/unaccepted: it failed before admission, so no new crew-joining feature
or checkpoint is claimed.

Aurora/Rime settled resume retirement, Ember Save Progress, Arrow guidance and
exported dedicated startup retain their accepted source/package scopes. Do not
select them again as missing implementations. Halyard physical egress remains
PARKED at its station-spawn jump; Ember outbound stays PARKED at its planetary-
gravity caller comparison. Their source/raw, failures, costs and reopening gates
are preserved; neither is qualified by this checkpoint.

Select a ready delivery or qualification goal from its existing contract.
Parked work retains the causal reopening and explicit reprioritization rules
above; a changed name or automatic continuation does not clear a terminal stop.
Verified official editor and Windows/Linux release templates remain available in
`/srv/mudds-work/toolchains/godot-4.7.1-official/`.

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
