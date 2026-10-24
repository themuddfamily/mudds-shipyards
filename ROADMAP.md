# Development roadmap

**Playable alpha; full original scope remains unfinished.** Latest playable build:
[fb396ab Windows checkpoint](builds/windows/MuddsShipyards-fb396ab-checkpoint.zip)
([changes and validation](builds/windows/MuddsShipyards-fb396ab-notes.txt)).
Nine of the promised 17 craft exist. All 36 original parent outcomes and ten phase
exit gates remain open; completed child results are retained, not counted as whole
features. There is no evidence-backed project percentage or completion date.

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

## Execution now

**Selected: finish HELM-PITCH and HELM-ROLL-RATE ordinary handback.**
Starting clean source2e89b37bc. Each goal gets its own small profile subclass and
one complete existing three-process Jovian route, not another turn-only proof:
physical boarding/departure/brake, both signed sampled axis turns, fresh release,
both actual replicas, ordinary Interact handback, owner0/generation+1, retired
source/capture and supported former-pilot walk. Roll retains no-barrel-roll or
weapon/landing request fences. Root adds the actual right-axis snapshot needed
by pitch's existing handback drift calculation; no production behavior changes.

Two implementers own disjoint new pitch/roll test+UID pairs; root owns the shared
snapshot/records/integration; one independent reviewer checks source/raw results.
Each card estimates15min implementation plus15min check/review, shared hard stop
60min including both goals/attempts/cleanup. Original300s profile/360s outer and
all existing deadlines remain. Import/check-only, then ONE full route per goal,
run sequentially to avoid resource interference; stop at first unexpected failure.
No source/pose/provider/authority staging or reduced handback. Success per goal:
all3actual exits0/one marker/no runtime diagnostics plus reviewed host/client/
handback receipts. No physical-device/native/endurance/full-parent claim, and
no identical playable rebuild for test-only qualification.


**Delivered: HELM-HOVER — actual correction, release and full handback.**
Clean source524606903 passes the full ordinary three-process route157.438s,
including physical boarding/departure/brake, both yaw and boost checks, real
pitch/forward climb, measured hover, fresh release, both actual replicas and
ordinary Interact handback/supported walk/source retirement. Over30ticks/.5s,
actual host tilt16.7403→6.1584° and upward speed13.5390→1.0482m/s match authored
uprighting/damping; fresh hover release arrives313ms, client hull errors≤0.5m.
Root/independent source and raw review GO; import/check-only PASS, all3OSexits0,
zero runtime diagnostics. [Exact result and cleanup](docs/history/ROADMAP_DELIVERIES.md#sampled-remote-hover--full-handback-accepted--2026-10-25).

This qualifies existing normal-yard hover on isolated sampled synthetic input;
no runtime change, planetary-hover/device/native/capacity/endurance/final-parent
completion. Checkpointfb396ab remains current; no identical rebuild. Source is
integrated, no task branch/worktree created; owned scratch is archived/cleaned.

**Delivered: HELM-BOOST — actual host acceleration, release and full handback.**
Clean source70c8a65e5 passes the complete ordinary three-process Jovian route in
147.183s: physical boarding/departure/brake, both yaw turns, equal30tick/.5s
baseline/boost windows, fresh release, both real client replicas and ordinary
Interact handback/supported walk/source retirement. Actual host acceleration
14.6500→19.4500m/s² matches authored thrust/boost/drag; release reaches host in
under0.36s and both client hull errors stay≤0.5m. Owner changes to0/generation+1,
old source/capture retire and no boosted demand remains. Root and independent
source/raw review GO; import/check-only PASS, all3 peer OS exits0/no runtime
diagnostics. [Exact scope and cleanup](docs/history/ROADMAP_DELIVERIES.md#sampled-remote-boost--full-handback-accepted--2026-10-25).

This qualifies existing gameplay on isolated synthetic-action/loopback input;
no runtime tuning/feature change, physical device or native-hardware pass.
No identical playable rebuild is needed; checkpointfb396ab remains current.
Full network/endurance/capacity/final gates stay
open. No task branch/worktree was created.

**Prepared: three concrete craft proposals — owner choices pending.**
[Paradox](docs/design/PARADOX_IMPLEMENTATION_PROPOSAL.md): pilot cannon, separate
physical gunner and one passenger; 16 bounded cards.
[Katana](docs/design/KATANA_IMPLEMENTATION_PROPOSAL.md): single-pilot braking
fighter; 13 bounded cards.
[Predator](docs/design/PREDATOR_IMPLEMENTATION_PROPOSAL.md): unarmed pilot/guard/
voluntary-detainee transport with one real controlled cell; 15 bounded cards.
Each fixes a labelled modern candidate's hull/access/berth/tuning/roles/systems/
recovery and exact acceptance routes. Root source/seam review is complete;
no engine, runtime or package work was performed. Shapes and mechanics remain
UNAPPROVED; registered sources support names/roles, not authenticated models.

Preparation is complete; SPEC/build/craft acceptance remains open. Record each
owner interpretation choice against its proposal before runtime work. Titan and
Vortex choices also remain pending. Do not repeat proposal preparation or infer
approval from continuation. Full17craft scope and historical requirements remain.

**Prepared: SPEC-VORTEX decision proposal — owner choice pending.**
[Vortex's unapproved modern proposal](docs/design/VORTEX_IMPLEMENTATION_PROPOSAL.md)
fixes one pilot/four physical passenger chairs,10×20×5m original hull, continuous
stern access, trial handling, one existing pilot cannon, no cargo/specialist roles,
safe on-foot restart and14 bounded implementation/package cards. Source confidence
supports only the registered name/role; geometry/mechanics are proposed, not
historical. Root source/seam/contract review complete; no engines or runtime edits.
Source-table review also found Vortex differs from the existing Bomber on only
13 handling axes against the registry minimum14. Its proposed tuning needs one
explicit revision and actual combined-roster validation before implementation;
proposal preparation is not a passed fleet check.

This completes proposal preparation, NOT SPEC-VORTEX/BUILD-SPLIT approval, a craft,
phase or historical gate. Owner chooses this labelled modern interpretation,
revises exact fields, or keeps reconstruction frozen pending tied model evidence.
Do not repeat this definition or begin runtime work without that choice. Titan's
existing proposal/interpretation choice also remains pending. Full17craft scope,
capacity/desktop/native/device/rights and full-craft acceptance remain unchanged.

**PLAY-TORPEDO remains OPEN; three full trials stopped/unaccepted.**
The latest run genuinely reboarded after sampled view/selection settling, then
proved real pitch/boost evasion and a distinct seeker shoot-down. Three later
boat shots missed; two real incoming seekers destroyed Arrow. No Torpedo boat
kill, distinct payment, home return, next posting or normal UI exit. The two
earlier failures and supported caller corrections remain recorded on one clock.
[Exact outcomes, cause limits and cleanup](docs/history/ROADMAP_DELIVERIES.md#torpedo-second-boarding-readiness--whole-journey-not-accepted--2026-10-25).

Full finish remains same-process genuine Heavy clear/payment/home/physical
Torpedo posting, real evasion AND distinct seeker interception before actual
boat kill/CLEARED, distinct same-generation durable credit (ledger2/one each),
strict home/OFFLINE physical exit, physical usable Paired Wing posting and UI
OS0. Original150s encounters/sharedCAP300/outer360 unchanged. Reopen only after
a source/raw-supported gameplay/control cause for the failed boat engagement
and a bounded correction preserving that entire journey. No unchanged retry,
arbitrary point/aim/physics/timer change or extra qualifier layer is selected.
Failed source/bundles/results archived, accepted main restored, owned processes/
profiles/package replicas cleaned. Current playable checkpoint remainsfb396ab;
no full Torpedo/parent/native/hardware completion is claimed.

**Delivered: PLAY-BREACH first complete ordinary sortie, checkpointfb396ab.**
Fixed the real late-CombatAuthority Picket damage-adapter gap. The unchanged full
ordinary journey passes90.112s: physical Heavy arm/Arrow takeoff, actual lance
charge, real player hits24+22 destroy the46-health picket/CLEARED, exactly one
same-generation Heavy credit in actual primary data through orderly close,
strict home/OFFLINE physical exit, physical usable Torpedo posting and UI OS0.
Independent source/raw review GO; focused lifecycle/encounter/Heavy checks, fresh
paired exports/three strict startups/actual1527-entry package audit pass.
[Exact result, prior failures and limits](docs/history/ROADMAP_DELIVERIES.md#picket-damage-admission-and-full-heavy-breach--accepted--2026-10-25).

Accepted source merged/pushed; EXE/ZIP/notes in builds/windows. Owned processes/
profiles cleaned and records consolidated; no task branch/worktree was created.
Both earlier failures and the caller-only angle correction remain recorded on
the same Heavy clock. Repeat/Torpedo/recovery/broader combat/native/device/final
requirements stay open; no original parent or phase closes.

PLAY-TORPEDO is a dependent activity, **not a ready assignment** while its
reopening condition above is unmet. Use the next ready product outcome in the
work order; do not reopen it merely because its harness exists.

**PLAY-DEFENSE remains OPEN; consumed-fire qualification stopped.**
The one full ordinary trial destroyed Alpha and Beta, then reached the original
34s timeout with two hostiles remaining. Payment/home/Reset/UI exit were not
reached. Input consumption worked; it did not prove encounter completion or an
engine defect. Failed source/results are archived, accepted main restored, owned
processes/profiles/private package duplicates cleaned. No retry is selected.
[Exact result and reopening condition](docs/history/ROADMAP_DELIVERIES.md#defense-consumed-fire-qualification--not-accepted--2026-10-24).

The finish line remains physical Deploy/real Arrow takeoff, all four genuine
player-weapon kills in waves1–2–1 within unchanged34s, once-only actual-file
payment, strict home/OFFLINE physical exit, physical board Reset/usable next
Deploy and normal UI game exit0, originalCAP300/outer360. Reopen only for a
source/raw-supported cause and bounded correction that preserves that whole
journey. No speculative firing-point/aim/timer changes or unchanged rerun.

**Roadmap contract rewrite completed2026-10-24.**
Every existing named goal has an explicit **Done means** column in the
[canonical inventory](docs/ROADMAP_BACKLOG.md#concrete-child-outcomes). It identifies
the observable result or finite decision artifact. The row's existing dependency
and original limits still apply. Completed source/scenario evidence stays accepted;
final-candidate qualification is performed once through the final release goals.

The reconnect investigation is **NOT ACCEPTED**. Its focused setup failed before
the intended JOIN CABIN assertion and emitted nine ENet send errors. No runtime
repair was made. Unique test source and failed results are archived; accepted
`main` is restored and owned scratch/processes are cleaned. It is not an active
engine task or a completed capability. [Exact closeout](docs/history/ROADMAP_DELIVERIES.md#passenger-readmission-investigation--not-accepted--2026-10-24).

<a id="next-three-production-deliveries"></a>
## Work order

One implementation at a time. Select the earliest **ready product outcome** below;
if blocked, name the missing input and use the next ready one. Do not select an
unrelated test just because its harness is convenient.

1. **Close finite scope decisions.** Eight missing craft specifications, Bomber
   extra roles, final guest/host capacity and desktop list; four active-recovery
   policies; legitimate cargo replenishment/turnover. Each has named answer fields
   and a completion artifact in the [decision register](docs/ROADMAP_BACKLOG.md#blocking-decisions-and-resources).
2. **Complete playable outcomes.** Finish the open core/station/craft and first-play
   activity/world goals. A failure selects its demonstrated gameplay/build/driver
   repair; retain the complete original journey as the finish line. Prioritize
   full combat/activity completion and missing craft over extra Halyard edge cases.
3. **Close lifecycle and durability.** Remaining repeats, cargo cold reload/Hulk
   revisit, recovery, shared-world and multiplayer cases follow their real baseline
   dependencies. Reuse accepted results; fix actual defects, not evidence formats.
4. **Qualify and ship the stable integrated candidate.** Device/audio/performance,
   final captures, full matrix, install/rights/sign/distribution use the exact final
   bytes. Relevant runtime changes invalidate only affected results.

This order is not a claim that unknown specifications are already estimated.
[Concrete blocked inputs](docs/ROADMAP_BACKLOG.md#blocking-decisions-and-resources)
are resolved once; they do not authorize an endless research or definition loop.

## Turning a goal into one assignment

Before work starts, copy its existing ID, **Done means**, dependencies and protected
scope into a short execution card. Add exact production files/owner, action or
command, expected visible result, implementation/check estimate and time budget.
No card may say only “finish”, “polish”, “improve” or “support” a family.

Use this compact card for every selected task; fill each field before editing:

| Field | Required content |
| --- | --- |
| Goal and boundary | One existing goal ID plus this bounded capability; list what remains in its parent. |
| Starting state | Exact source/package, normal player/session state and satisfied dependencies. |
| Visible result | What the player can do after this change, or the exact finite answer for a decision task. |
| Pass condition | Actual action → observable result, numeric limits where applicable, and relevant existing check/ordinary route. |
| Ownership and budget | Exact production files, implementer, estimate and hard stop; include prior attempts in the same cumulative clock. |
| Closure | Actual PASS/FAIL/BLOCKED result, remaining work, integrated source/build where required, and process/worktree/branch cleanup. |

Do not silently expand a failed card into a new project. At the hard stop,
record the failed predicate or missing input and leave the parent open. A further
attempt needs a concrete cause, bounded correction and cumulative priority review;
renaming a task or creating a new branch never resets its budget. Before selecting
a different task, close or explicitly park the current card with its unique work
accounted for. Definitions already finished are reused, not recreated.
Each cumulative review must record total elapsed cost and choose either
**park/switch** or **one bounded continuation** with new causal evidence and an
explicit next stop. A review alone never authorizes an indefinite retry loop.

- Codex owns implementation/checks/integration; the user owns product decisions,
  external credentials and access. Each selected risky lifecycle change gets one
  independent reviewer. The exact file owner is set before editing.
- Decision/handoff preparation: normally 15–30 minutes, ending in the named answer
  or exact missing input. Do not repeat a completed definition. Missing original
  craft build estimates wait for their specifications; do not invent finish dates.
- Implementation: name one runtime/content/build result and an estimate before
  editing. Split before 90 minutes if it cannot yield a reviewable capability;
  preserve the original parent result and cumulative clock across attempts.
- Qualification: use the existing full route and original duration. The first
  unexpected failure stops execution. One proposed correction needs causal proof;
  failed work plus one attempted repair requires cumulative priority review.
- Close with actual result, relevant evidence, remaining limits, merged/pushed
  source, required playable checkpoint, owned-process/scratch cleanup and deletion
  of contained task branches. Failed/unaccepted source is preserved, not merged
  merely to delete it.

A parent closes only when **all** its required named instances pass. Definition,
assertion count, validator files and number of commits are not gameplay progress.

## Accepted work — source limits retained

Recent completed cases include occupied-chair requester feedback (`bcd268c75`),
chair contention/transfer (`99c9fc1af`) and airborne late join/normal docking/crew
boarding (`437fe903d`). Their exact scopes and earlier failures are in
[delivery history](docs/history/ROADMAP_DELIVERIES.md). They do not close the full
multiplayer baseline or any original phase.

## Parked failures and dependent work

The inventory retains each failed route, original cap and specific reopening
condition. No unchanged retries, arbitrary longer caps, substituted short routes
or renamed copies. Observation/VIP, Sandbox, KIT-RELOAD, Hulk revisit, shared Rime,
browser timeout and registered capture blockers remain explicit dependencies.
An old failure does not become a new task merely because another definition ended.

## Validation and final release

Automated Godot uses Dummy audio and headless/private Xvfb with explicit x11.
Audible tests need explicit authorization. GitHub Actions stays disabled.
Native Windows execution and mandatory human review are already owner-excluded;
unperformed facts remain NOT_RUN. Applicable native GPU/device/audio and Linux
requirements remain. No simulated or headless pass supplies those measurements.

The final exit is one accepted candidate with zero P0/P1 defects, reviewed P2
outcomes, the required complete ordinary journeys and unfiltered local matrix,
matching installable artifacts, settled rights/signatures and verified downloaded
bytes. The [ten phase exit contracts](docs/ROADMAP_BACKLOG.md#original-phase-gates-and-completion)
remain binding; none is silently reduced to this alpha.
