# Development roadmap

**Playable alpha; full original scope remains unfinished.** Latest Windows build:
[ca149d6 checkpoint](builds/windows/MuddsShipyards-ca149d6-checkpoint.zip)
([changes and validation](builds/windows/MuddsShipyards-ca149d6-notes.txt)).
Matching [Linux checkpointca149d6](builds/linux/MuddsShipyards-ca149d6-linux-x86_64.tar.gz)
([Linux validation](builds/linux/MuddsShipyards-ca149d6-linux-notes.txt)) is available.
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

**Delivered: LAN listings expire safely while paused.** Checkpointca149d6 retires
rows and endpoints30 seconds after the last valid reply and refuses stale joins
before creating intent or changing roles. The paused ordinary route observes
expiry at30.003631s, accurate expired feedback/Retry focus and zero stale
admissions. Actual Retry finds the same live host; fresh admission, original
Players' connected/solo walks and both normal exits pass. Fresh Windows EXE/ZIP and matching Linux ELF/archive, with notes, are available. [Exact validation and cleanup](docs/history/ROADMAP_DELIVERIES.md#lan-browser-expiry-accepted-20261025).

Earlier ordinary disconnect/rejoin, full-session UI refusal, Halyard reconnect
and projectile native-link results remain accepted in their recorded scopes.
The complete browser cancellation/reuse route is also accepted: two actual
pending attempts are cancelled, then the same guest Main/Player discovers and
joins a live host, walks connected, leaves and walks solo. Both actors exit
normally. This qualifies existing behaviour; game code and checkpoints are
unchanged. [Exact result and first failed assertion](docs/history/ROADMAP_DELIVERIES.md#browser-cancel-reuse-accepted-20261025).

The separate no-answer case also passes: a silent endpoint naturally times out
at 5,005 ms while paused; cleanup, ordinary Retry/Cancel and fresh live-host join
remain usable. The packaged connected-but-nonadmitting case remains parked, so
BROWSER-UNREACHABLE stays open as a whole. [Exact source-case proof](docs/history/ROADMAP_DELIVERIES.md#browser-no-answer-source-accepted-20261025).

The settings 10→11 real-file migration/reload case is also accepted. Explicit
Save produces the exact current settings section and backup; a distinct normal
Main reload preserves the complete profile and paid Race/reward, then permits
normal Begin Shift and supported walking. The original failures remain retained.
[Exact source-case proof](docs/history/ROADMAP_DELIVERIES.md#settings-schema10-migration-accepted-20261025).

This30s duration is an engineering default, not a claimed user approval. Wider
packaged journeys/device/capacity/endurance and final gates remain open.

The canonical inventory remains
[the existing backlog](docs/ROADMAP_BACKLOG.md#concrete-child-outcomes); no parallel
list of promises or new evidence framework is being introduced.

There are **337 tracked records**, including accepted work, definitions and
containers. They are not 337 remaining tasks. All **36 parent outcomes**, **ten
phase gates** and **17 promised craft** remain in scope; nine craft currently
exist. A reliable remaining-task count or finish estimate needs the unresolved
specifications below. We will report accepted player outcomes and exact blockers,
not a project percentage inferred from rows, tests or commits.

### Small execution queue

Only one implementation card may be active. Completed results are linked under
[accepted work](#accepted-work--source-limits-retained), and failed attempts under
[parked work](#parked-failures-and-dependent-work). They are not next tasks.
The table below contains actual missing decisions.
No implementation card is active. The existing shared Main resource/combat
lifecycle check is accepted on79dc473a5: three retained subtree re-entry cycles,
72assertions/70.113s/OS0/zero diagnostics, including Torrent hull/source1101,
stale-shot rejection, retained nodes, queues and audio. [Exact source scope](docs/history/ROADMAP_DELIVERIES.md#shared-main-source-lifecycle-accepted-20261025).
This is staged source qualification; it does not replace ordinary play, component
ledger/seat-specific contracts, packaged/final-candidate gates or destruction.

Physical Torrent→Arrow→Torrent handoff is
accepted: driveraf38de143/package6fe51dca4,131.708s under unchanged CAP300.
The real damage/two-home prerequisite is followed by supported deck walking,
Arrow boarding/90neutral-OFFLINE ticks/current-stream E exit, return walking,
fresh Torrent stream/reclaim/90neutral ticks/E exit/walk and normal UI OS0.
Both hulls remain parked/OFFLINE during handoff; old sources remain neutral and
non-producing. [Exact result, two failed approaches and cleanup](docs/history/ROADMAP_DELIVERIES.md#torrent-arrow-physical-handoff-accepted-20261025).
Arrow flight/weapons, broader damage/destruction and final integrated craft
qualification remain open; do not replay this accepted case unchanged.

Torrent's real incoming core-damage/passive
repair route is accepted ona1de3363f: hull100→89, core integrity.56 and targeting
power.62,617consecutive airborne observations without repair, then43strict landed
passive commits restore core1/all five nominal/modifiers1/zero effects while hull
stays89. Both home returns, fresh boarding/departure/exits/walking and normal UI
OS0 pass in88.168s under CAP300. [Exact scope and cleanup](docs/history/ROADMAP_DELIVERIES.md#torrent-core-damage-passive-repair-accepted-20261025).

Torrent return/reuse is accepted on5d2c58dba:
actual packaged Guided, two strict home returns with90consecutive neutral/OFFLINE
ticks each, fresh boarding/departure/second lease, supported exits/walking and
normal UI OS0 in85.267s under the unchanged300s cap. This is an executable part
of CRAFT-ACCEPT-TORRENT; broader applicable damage/recovery, cross-craft and required
Main coverage remain open. [Exact scope, failures and cleanup](docs/history/ROADMAP_DELIVERIES.md#torrent-return-reuse-capability-accepted-20261025).
The caption overflow choice remains pending; six Settings extreme-scale/scroll
views stay accepted and REPEAT-RACE stays parked. Torrent's source inventory is
already bound; do not repeat it or replay the accepted reuse route unchanged.

**Not every inventory row is ready to execute.** Craft full-journey routes,
comfort episodes, remaining recovery cuts and final installed-package cases still
have explicitly missing case/route bindings in the backlog. Codex owns resolving
those from the existing contracts in one bounded pass; genuinely missing product
choices stay with their named decision owner. A missing binding is not an active
implementation task, and “all applicable cases” cannot close it. The 36 parents
and ten phase gates are completion containers; select a concrete child result.

| Existing goal | Next bounded result | Proof / stop | State and owner |
| --- | --- | --- | --- |
| ACCESS-CAPTIONS[overflow policy] | Choose how the current caption presents oversized valid text | Actual1280×720 HUD/request1.6/effective1.043478:64-source/512-body accepted, intrinsic650px exceeds411.130px safe height; bodyalone512px. Choose pagination, scrolling or wider/recomposedHUD; preserve full text/readable fonts and fix timing/input/reservation behavior before implementation. [Measured boundary](docs/history/ROADMAP_DELIVERIES.md#caption-combined-hud-overflow-measured-20261025) | WAITING ownerpolicy — one headlesscheck failed safe containment, source/geometrystable; no retry/render/repair. Diagnostic source archived; owned process/scratch cleanup complete, Git closure recorded in adjacent closeout; no runtime delivery |
| REPEAT-RACE | Ten genuine same-world Race completions/payments, strict home exits, normal resets/reuse and usable next start | Same Main/world/Player/Torrent; actual five gates/2s countdown/120s race; exact ledger1→10 and run generations1,3,…19; tenth normal reboard idle20; original home/OFFLINE/walk/normal UI OS0. Fixed quiescent node/registry/objective counters: zero positive growth cycle1→2…10, legitimate receipts excluded. Existing per-cycle300s/subcaps retained; derived aggregate abort3000s. First failure stops | PARKED — first735.603s trial: 3completehome/resource cycles, fourthpaid but home CAP300. One reviewed gantry-lane correction then fails312.126s at firsthome CAP300, before either lane receipt. No ten-cycle acceptance, finalidle20/nextstart/UIclose NOT_RUN. Both failures/source/export retained; allowned processes/scratch cleaned, unaccepted branch accounted then removed. Original12:29Z→13:59Z/90min clock/cumulativecost retained. Reopen only after demonstrated cause of the corrected first-lane failure plus independent cumulative-priority review; no unchanged replay, cap increase or budget reset. [Exact stop](docs/history/ROADMAP_DELIVERIES.md#race-repetition-two-attempt-stop-20261025) |
| SETTINGS-INPUT | Recover the original Settings failure inputs before resuming its unchanged return route | Exact writer/reader scripts and9a89b3763 source recovered. Missing FINAL orchestration/launch receipts, isolated durable profile and source/package300s timeout logs; historical cache root absent. [Literal fields and retained originals](docs/ROADMAP_BACKLOG.md#original-settings-artifacts--bounded-recovery) | WAITING execution artifacts — bounded source/archive search completed; no replacement test or run selected. SETTINGS-RETURN remains open |
| NET-ENDURANCE-DEFINE | Fix the missing numeric lab profile and pass/fail limits before implementing the original30-minute100msRTT/2%loss independent two-client route | One [literal proposal](docs/MOVING_INTERIOR_LATENCY.md#endurance-execution-handoff--proposed-limits-2026-10-25), existing limits separated from proposed values; safe namespace/netem availability verified without game/traffic. No old stream shim or command-injection pass substitutes | WAITING — owner adopts/replaces genuinely unspecified limits. Actual whole-link shaping/1800s ordinary driver still unimplemented; no endurance run selected. Bounded source handoff only; startup profiling remains parked with no unaddressed measured hotspot |
| SPEC-TITAN / VORTEX / PARADOX / KATANA / PREDATOR / DYNAMIC / UTOPIA / SALYUT | One explicit approval or field-level revision for each existing craft proposal | All required geometry/handling/functions/roles/save fields fixed in the corresponding proposal; no repeat proposal preparation | WAITING — user chooses interpretation/design; Codex implements approved fields |
| BOMBER-ROLE-DECISION | Record additional physical roles, each action and seat/access arrangement | Exact role count and actions recorded once; pilot-only runtime does not close this promise | WAITING — user |
| SCOPE-LIMIT / SCOPE-DESKTOP | Fix supported guest/host/role capacity and exact desktop targets | Concrete values in the existing decision register; settings maxima/export presets do not establish support | WAITING — user |
| RECOVERY-POLICY-CINDER-SUPPLY / DEFENSE / BREACH / TORPEDO | For each active context, choose retained fields, safe recovery or resume, debt and reset/refusal behavior | Four complete policy answers; implementations/cold restarts remain separate required work | WAITING — user chooses policy; Codex supplies exact restart checks |
| CARGO-REPLENISH-JOVIAN / CINDER | Fix a legitimate stock/refill/turnover policy | Conserved counts, trigger/capacity/refusal and normal ten-delivery route defined; tests cannot mint cargo to pass | WAITING — user |

The [decision register](docs/ROADMAP_BACKLOG.md#blocking-decisions-and-resources)
contains exact answer fields, prepared craft proposals and external release/device
inputs. These are recorded blockers, not permission to keep researching them.
Already accepted freight/stock/rejection/Beacon/Bomber-refill/Defense-arm decisions
remain settled. Do not ask them again.

### Work order after this correction

1. Select one ready capability, qualification or definition from the canonical
   inventory and state its kind. A capability changes production behavior;
   qualification closes a named original acceptance predicate on a fixed
   candidate; definition supplies one finite missing contract. If a ready
   production capability exists, select it unless a named dependency requires
   other work first. If none exists, finish one bounded readiness pass with exact
   blockers and owners; do not generate a chain of handoffs or discovery cards.
2. Split its production implementation into capabilities estimated at no more
   than90 minutes each. Name each capability's files, observable result and focused
   check before editing. A fleet, world, activity family or final matrix is a
   milestone/container, never one implementation assignment.
3. Deliver and close that capability, then run its retained complete journey when
   its prerequisites hold. A short regression can prove the repair; it cannot
   replace the original full journey, repeat count or deadline.
4. Qualify the stable integrated candidate through the existing release gates.
   Reuse accepted results within their recorded scope. Re-run affected checks when
   code changes invalidate them; do not restart every completed journey by default.

## Turning a goal into one assignment

A goal is **READY only when every field below has a literal answer**. Otherwise
mark it BLOCKED and record the missing value/list plus the owner who can supply it.
“Works”, “usable”, “polished”, “all applicable” and “specified” alone are not pass
conditions. A link is sufficient only if its target fixes the actual cases/values.
The backlog already flags unresolved route/case bindings. Those rows are not yet
fully specified tasks; their existence and a Done means column do not make them
ready. Do not report the breakdown as complete while those bindings are missing.

| Field | Required answer before work starts |
| --- | --- |
| Goal | One existing ID, its kind (capability, qualification or definition) and one bounded result. Name the parent work that remains. |
| Starting point | Source/package, normal player/session state, satisfied prerequisites and exact owned files. |
| Player result | For implementation: current failing/missing behavior → one delivered behavior, with a literal player action and observable state/value. For qualification: the exact original acceptance predicate. For definition: the exact finite fields to record. |
| Acceptance | Fixed complete case list, expected endpoints/counts/tolerances and original deadlines. List what this card can close and the parent acceptance that remains. No criteria chosen after observing results. |
| Proof | Existing focused command or ordinary route and expected output/file/state; an implementation check must distinguish old behavior from delivered behavior. Identify physical-device/hardware/external input separately. |
| Owner and estimate | Implementer/reviewer, implementation/check/closure estimates, hard stop and cumulative cost of earlier attempts. |
| Closure | PASS, FAIL, BLOCKED or PARKED; proof or first failed predicate; remaining work; commit/push/build and owned cleanup. |

Before selecting an implementation card, answer: **what will the player be able to do, or what
required executable packaging/release operation will become possible?** A new
test, capture, source audit or document is not an implementation answer. Label
such work qualification or definition, explain the exact original requirement it
serves, and retain its finite stopping point. A passing helper does not close the
runtime outcome it is intended to exercise.

Keep the selected card's original result, case list and cumulative budget visible
when reporting progress. A discovered prerequisite is recorded against that same
goal; it does not silently replace the result or become a fresh chain of tasks.
At the hard stop, report the unmet result and close or park the assignment.

For example, the next **possible** Torpedo repair would be one control-accounting
change: an unready/no-command sample followed by a real consumed-command sample
must record consumption without requesting fire again, including a terminal boat.
A focused existing driver fixture would prove that correction. It would **not**
close PLAY-TORPEDO. That still requires the entire Heavy→Torpedo→usable Paired Wing
journey, actual seeker evasion/interception,70HP boat destruction, separate
payments, strict home/OFFLINE/physical exit and normal UI exit0, with150s per leg,
shared300s and outer360s. The failed47.646347min plus continuation cost remain
charged; a new card/branch/folder cannot restart that budget. No Torpedo continuation is active; any reopening must satisfy the recorded source-review and cumulative-priority conditions.

### Stop rules that prevent another loop

- Freeze acceptance before editing. Add a case only for an identified uncovered
  original requirement; record why, rather than silently moving the finish line.
- Stop the selected check at its first unexpected failure. Preserve the result
  and source. Diagnose the actual owner; do not build another validator or extend
  the deadline to convert failure into success.
- One attempted repair followed by failure requires a cumulative priority review:
  park/switch, or justify one bounded continuation with a demonstrated cause and
  explicit stop. There is no automatic retry chain.
- Close or park the active card before switching tasks. Preserve unfinished unique
  source. Merge accepted work into main, push, remove completed owned branches and
  worktrees, and release owned processes/scratch. Cleanup is part of completion.
- A meaningful working gameplay/graphics result gets a fresh Windows checkpoint
  through the existing clean-commit workflow. Include actual checks and player
  changes. Documentation/private diagnostics alone do not require an identical build.
- In progress reports state: **goal; player result; accepted/failed/blocked;
  first remaining blocker; elapsed cost; next bounded action**. At closure report
  completed named outcomes and the remaining named milestones. Do not substitute
  assertion counts, evidence versions or commit totals for product progress.

## Accepted work — source limits retained

Recent accepted child outcomes include
[shared Main source lifecycle](docs/history/ROADMAP_DELIVERIES.md#shared-main-source-lifecycle-accepted-20261025),
[physical Torrent–Arrow handoff/reclaim](docs/history/ROADMAP_DELIVERIES.md#torrent-arrow-physical-handoff-accepted-20261025),
[Torrent incoming core damage/passive repair](docs/history/ROADMAP_DELIVERIES.md#torrent-core-damage-passive-repair-accepted-20261025),
[Torrent packaged return/reuse](docs/history/ROADMAP_DELIVERIES.md#torrent-return-reuse-capability-accepted-20261025),
[six Settings extreme-scale/scroll component views](docs/history/ROADMAP_DELIVERIES.md#settings-4x3-extreme-views-inspected-20261025),
[corrupt-primary read-only fallback and continuation](docs/history/ROADMAP_DELIVERIES.md#corrupt-backup-read-only-fallback-accepted-20261025),
[Central walking/launch/home](docs/history/ROADMAP_DELIVERIES.md#central-station-accepted-proof-reused-20261025),
[Hauler conserved delivery](docs/history/ROADMAP_DELIVERIES.md#hauler-supply-first-play-accepted-20261025),
[Race and home](docs/history/ROADMAP_DELIVERIES.md#race-first-play-accepted-20261025),
[Patrol relay](docs/history/ROADMAP_DELIVERIES.md#patrol-relay-first-play-accepted-20261025)
and [browser join/solo walking](docs/history/ROADMAP_DELIVERIES.md#browser-join-supported-walking-20261025).
They stay accepted for their recorded source/route. Their cold/repeat/device/final
candidate requirements remain separate; no automatic unchanged rerun is selected.
Full chronological results belong in the existing
[delivery history](docs/history/ROADMAP_DELIVERIES.md), not the execution queue.

## Parked failures and dependent work

| Existing goal | Specific reopening requirement |
| --- | --- |
| WALK-AFT | Bind the actual frozen Player completed-motion receipt in paused observation; last unpaused observation can lag one tick. Preserve full journey/original 60min cumulative clock/300s and360s caps; independent source GO and priority review before any new trial |
| PLAY-TORPEDO | Retain cancelled request debt across unread queued neutral samples after OS release; source GO and cumulative priority review before checks; full Heavy/Torpedo/Wing finish unchanged |
| PLAY-PATROL[platform_sweep] | Localize normal quit failure; five holds/payment/home/exit already observed but UI exit0/save closure missing. Original300s remains |
| PLAY-DEFENSE | Demonstrated control/gameplay correction for the recorded two-of-four clear; no arbitrary longer fight |
| COMBAT-WING | Demonstrated cause/correction for eight shots causing zero damage; no unsupported aim tuning |
| Other parked rows | Their exact recorded cause, original case list/cap and reopening predicate in the canonical backlog; no unchanged retry |

Unaccepted Torpedo source and helpers are consolidated in
`/srv/mudds-work/torpedo-boat-control-20261025/results/case-records.tar.gz`;
adjacent `closeout.json` records the verified archive/hash, preserved original
clock and cleanup. Source review stopped the sole correction before any tests,
engine, export or whole trial. The Torpedo candidate stays unmerged; transport checkpoint4afd529 now supersedes
0d77125 without accepting Torpedo. [Exact blocker and retained full journey](docs/history/ROADMAP_DELIVERIES.md#torpedo-control-continuation-stopped-at-source-review-20261025).

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
