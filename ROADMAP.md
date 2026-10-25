# Development roadmap

**Playable alpha; full original scope remains unfinished.** Latest playable build:
[8cda303 Windows checkpoint](builds/windows/MuddsShipyards-8cda303-checkpoint.zip)
([changes and validation](builds/windows/MuddsShipyards-8cda303-notes.txt)). Matching [Linux checkpoint](builds/linux/MuddsShipyards-8cda303-linux-x86_64.tar.gz) is now available
([Linux validation](builds/linux/MuddsShipyards-8cda303-linux-notes.txt)).
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

**Verified: complete ordinary browser disconnect and fresh rejoin.** The guest
joins the live host, walks, disconnects normally and retires its old transport and
authority, walks solo, then Refreshes and rejoins the same available host with a
fresh matching admission. Both original Players walk under the second admission;
second Disconnect, host stop and solo returns pass. Host counts0→1→0→1→0;
both actual processes exit0 with zero diagnostics. Earlier caller failures are
retained; no gameplay or deadline change. [Accepted route and cleanup](docs/history/ROADMAP_DELIVERIES.md#browser-disconnect-rejoin-accepted-20261025).

Earlier full-session UI refusal, complete ordinary Halyard reconnect and projectile
native-link repair remain accepted in their recorded scopes. Production files
still match the Windows and Linux8cda303 checkpoints; no identical-game export.
Wider package/device/capacity/endurance and final gates remain open.

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

Only one implementation card may be active. Each row below is a bounded step
within the existing goal, not a replacement for its full acceptance. The disconnect/rejoin qualification is accepted below. No implementation card is active. The complete named reconnect case is
accepted for its recorded Linux-source ordinary-input scope. Torpedo remains
parked; broader multiplayer and final-candidate requirements remain separate.

| Existing goal | Next bounded result | Proof / stop | State and owner |
| --- | --- | --- | --- |
| PACKAGE-LINUX[8cda303] | Deliver the missing Linux checkpoint for the already accepted Windows8c gameplay: executable, installable launcher archive and player notes | Exact clean8cda303 safe export; original900s export/300s each strict direct+archive menu startup; embedded payload parity, exact tar bytes/modes/metadata; no diagnostics and owned cleanup; first unexpected failure stops | DONE — exact8cda303 Linux ELF/archive/notes delivered; direct22.353s/archive22.470s menu startups each exit0/sentinel1/zero diagnostics; all1527 actual payload entries match Windows; archive bytes/modes/metadata and independent review pass. Owned checkout/process/profile cleanup complete; full install/ordinary/native/final gates remain open |
| BROWSER-DISCONNECT | Normal LAN join/connected walking → guest ordinary Disconnect/complete old authority retirement/solo walk while original host stays available → actual Refresh/fresh join/new matching admission tuple → same-Player connected walk → second normal Disconnect/host stop/usable return | Existing independent two-Main caller opt-in only; original300s outer/230s work/Main60s/UI5s/discovery10s/admission20s/handoffs20s/guest100s/host30s/cleanup10s,≥1m/5s walking+settle/12neutral ticks; immutable first and second receipts, both actual OS exits0/clean logs | DONE035fa2f in source InputEvent/LAN ordinary-route scope — whole88.888s/510checks, actual2OS exits0/zero diagnostics, both original Players and fresh matched admission tuple, all7supported walks/bothretirements/currentHUDfences/hostcounts0→1→0→1→0. Independent review GO; earlier failures retained, original75min clock includes all elapsed time from08:15:10Z. No runtime/cap change; package/device/endurance/capacity/final gates remain open |
| BROWSER-STALE | Real elapsed-time LAN freshness owner and stale selection preflight are missing | User must choose lifetime; abstract30ticks has no duration. No unchanged stopped-host/unreachable retry or invented clock mapping | WAITING — user lifetime answer; monotonic expiry continues through paused menus, runtime implementation/complete ordinary proof still required |
| BROWSER-FULL | Genuine full host/occupant, disabled-row pointer refusal, real Refresh and same-Player usable solo return completed | 209 coordinator checks/125.781s; actual GUI press+release, zero activation/join/admission, fresh full directory1→2,1.002774m supported walk, host counts0→1→0, three actual OS exits0/zero diagnostics; original caps retained | DONE e39653cf in source InputEvent/LAN UI-refusal scope — independent review GO;18.696min through cleanup plus final push; package/device/native/endurance/capacity/final gates separate |
| ACCESS-PAUSE-4X3[normal Settings top, scale1.0] | Existing top Settings image inspected at1024×768/requested+effective1.0 | Rendered original PNG: heading/visible two-column rows/scrollbar/fixed footer fit and read clearly; zero diagnostics, capture exit0; no visual finding | INSPECTED — component top view only on59117f3/lavapipe; other scroll positions/states/scales/focus navigation/full-cell qualification remain open; no unchanged recapture selected |
| WALK-AFT | Furniture-clear Operations path exercised; complete original journey remains unaccepted | Both ordinary trials stop after actual Board UI at resumed-motion receipt comparison; no stairs/Zenith/home/UI-exit completion. Actual frozen Player receipt is newer than the last unpaused observer sample | PARKED — candidate 06ce015 unmerged/archived; original 60min, 50.915min through cleanup. Reopen only after actual paused `_life_completed_motion()` receipt binding, independent source GO and cumulative review; no unchanged retry or freshness relaxation |
| NET-ACTOR[projectile/native disconnect] | Closed native recipients skipped before budget work; connected deferred/flying/terminal updates retained | Existing real ENet close-window regression (66), projectile replication (49), canonical (17), consumer (8); all exit0/zero diagnostics, caps unchanged; verified Windows EXE/ZIP/notes | DONE 8cda303 in focused production transport scope — independent review GO; 10.733 minutes through cleanup including conservative mapping cost; full actor/Picket/Torpedo journeys remain open |
| SERVER-BASELINE-PASSENGER-RECONNECT | Complete original ordinary reconnect journey delivered on109aca0 | 397 checks/171.747s, all three peers exit0, zero diagnostics; original seven moving stages/loss/UI rejoin/home/fresh berth+later chair/renewed flight verified, original caps retained; fresh verified Windows EXE+ZIP+notes | DONE in Linux-source ordinary-input scope; package/device/endurance/capacity/final gates remain separate |
| PLAN-ASSIGN | Replace the chronological working page with this queue; audit every canonical goal for a finite result or explicit blocking input | Preserve all337 IDs/order,36 parents/ten gates; review changed acceptance and local links. Finish after this pass; no automatic new definition task | PASS — Codex; documentation only |
| PLAY-TORPEDO | Cancelled request accounting must survive unread queued neutral samples across actual OS release | Source review BLOCK: output dispatch does not establish which engine samples postdate release. Candidate archived; no tests/export/trial, no gameplay completion | PARKED — Codex;67.453min cumulative at stop, no automatic retry |
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

1. Select one ready **player-visible capability** from the canonical inventory.
   Prefer missing gameplay/content and observed defects over extending a test
   harness. If a specification is blocked, use the next genuinely ready outcome.
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

| Field | Required answer before work starts |
| --- | --- |
| Goal | One existing ID and one bounded production result. Name the parent work that remains. |
| Starting point | Source/package, normal player/session state, satisfied prerequisites and exact owned files. |
| Player result | Literal action → observable state/value; for a decision, the exact finite fields to record. |
| Acceptance | Fixed complete case list, expected endpoints/counts/tolerances and original deadlines. No criteria chosen after observing results. |
| Proof | Existing focused command or ordinary route and expected output/file/state. Identify physical-device/hardware/external input separately. |
| Owner and estimate | Implementer/reviewer, implementation/check/closure estimates, hard stop and cumulative cost of earlier attempts. |
| Closure | PASS, FAIL, BLOCKED or PARKED; proof or first failed predicate; remaining work; commit/push/build and owned cleanup. |

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
