# Development roadmap

**Playable alpha; the full game is unfinished.** Nine of the promised 17 craft
exist. All 36 original parent outcomes and ten phase exit gates remain open.
There is no evidence-backed completion percentage or finish date.

**A roadmap heading is not a work assignment.** Select only a bounded child
with a filled [task card](#task-card-required-before-starting). Its result must
be observable, its pass condition fixed before work starts, and its dependencies
actually satisfied. Missing details mean blocked work, not permission to explore
indefinitely. A completed specification does not count as a completed feature.

Latest playable checkpoint: **6474bda** — [Windows ZIP](builds/windows/MuddsShipyards-6474bda-checkpoint.zip)
([notes](builds/windows/MuddsShipyards-6474bda-notes.txt)) and
[Linux archive](builds/linux/MuddsShipyards-6474bda-linux-x86_64.tar.gz)
([notes](builds/linux/MuddsShipyards-6474bda-linux-notes.txt)).
Cancelled Aurora/Rime approaches now keep their resident world on normal
streaming wind-down until the actor leaves its unload envelope. Actual Main
integration passes both worlds' unload/free, fresh admission and current-origin
checks. This is staged component proof; full ordinary/shared cancellation and
native/hardware qualification remain OPEN.
[Delivery and exact proof limits](docs/history/ROADMAP_DELIVERIES.md#retired-world-residency-delivered-20261105).
Earlier Ember passive progress, save/terminal retry, Aurora/Rime settled resume
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
| Pass | Observed endpoint and expected value for every included case |
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

**Roadmap clarification delivered (documentation only).** The front page now
distinguishes product outcomes, bounded deliveries and qualification, and fixes
the readiness/proof/closure rules. All337 canonical rows are unchanged; local
roadmap links resolve and independent review checked the selection rules. No
gameplay result or qualification is claimed by this documentation change.

**Unfinished implementation, preserved while this requested planning work is handled:** Cinder retained-cabin standing readmission. Existing
[Cinder remote-crew capability 1](docs/ROADMAP_BACKLOG.md#cinder-remote-crew-moving-handback),
independent of parked physical egress and remote cargo transfer.

- **Result:** after browser disconnect/rejoin while standing in the Hauler,
  the guest's first crew-station E obtains a fresh standing cabin berth/body;
  a later E claims the chair. The occupied pilot seat remains with A.
- **Start/owner:** clean `583ad250a`; implementation owns only
  `scripts/game/game_flow.gd` and existing
  `tests/network/halyard_network_passenger_route_test.gd`. One independent
  reviewer checks authorization, ownership, support and lifecycle. Reuse existing
  host boarding/body owners and explicit retained-cabin helper; preserve its
  Halyard behavior and generic cockpit/pilot promotion semantics.
- **Dependencies:** current Hauler/chair/body/transport and existing browser UI
  are present. Do not restore parked egress, Halyard landed-admission or Jovian
  readmission candidates. No new world route, remote terminal or role matrix.
- **Action:** new opt-in `--cinder-cabin-readmission` in the existing two-OS
  passenger caller; A is the host Hauler pilot, B its current Navigator guest.
  Both selected peers use actual Intro Begin Shift before pause/browser actions.
  Existing outside approach staging and an initial production home reset may
  establish the fixture's supported starting state; disclose them. Initial
  hatch/chair/FIRE, browser Disconnect, supported solo cabin walk, Manual Join
  and Back/Resume, first E/body, walk, later E/chair/FIRE use real production UI
  and inputs. No placement, old-grant write or fake body supplies readmission.
- **Pass:** old runtime fails the first fresh-standing-grant endpoint after
  successful setup/rejoin. New runtime retains the same B Player and supported
  cabin after disconnect; old host body weakref, claim and effects retire once.
  Rejoin authenticates current session/admission. First E is BOARD_ANY for a
  host-chosen berth only: unseated fresh bound body/source, no pilot/chair grant.
  Walk at least0.6m on real current cabin support, then claim current Navigator
  chair and FIRE with matching host/guest peer/avatar/entity/frame/claim/stream
  and current consumer receipt. A's original body/seat/source/helm and advancing
  commands, unrelated stock and owners stay current. Stale/foreign/no-admission,
  unsupported/out-of-range, occupied/pending/transition guards stay intact;
  current existing helper prerequisites must actually pass, not be removed.
- **Proof:** raw two-peer UI/action/body/claim/support/receipt operands and actual
  OS0 exits with one distinct success marker/zero diagnostics; retain old failure.
  Run existing recovered-Halyard-cabin focused regression because its helper is
  shared. Targeted staged starting state proves this capability only; complete
  moving roles, full home/egress and ordinary fresh travel remain open.
- **Budget:** start2026-11-05 08:00:25 UTC; source-ready deadline08:30:25;
  all-in deadline09:30:25. Existing caller300s/outer360s, host ready60s, client
  completion120s, Manual Join20s, Back/Resume8s, consumed view8s, walk15s and
  input240+3s support limits retained. Source readiness includes direct parsing
  before behavioral source freeze: at most eight cause-bound readiness fixes,
  then at most three behavioral acceptance corrections (eleven total), all
  within this original clock. Each unexpected failure stops dependent checks
  and records cause/cumulative cost; no reset, renamed retry or parked reopening.
- **Endpoint:** accepted behavior gets focused checks, safe clean-commit
  Windows/Linux checkpoint/strict startup/package validation, merge/push and
  owned cleanup. Otherwise archive/park at deadline or exhausted allowance.
  All Godot Dummy, headless/private Xvfb explicit x11; hosted CI stays disabled.

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
