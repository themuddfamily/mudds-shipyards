# Development roadmap

**Status: playable development alpha; project completion is unproven.**
Latest accepted checkpoint: **51257b3**. The ordinary Arrow route now proves one
real pilot precision-emitter hit and preserves two flights, strict home/offline
exits, clear-walk/reboarding and normal UI quit. This qualifies existing gameplay;
it does not add a weapon or finish Arrow. [Windows notes](builds/windows/MuddsShipyards-51257b3-notes.txt)
and [Linux notes](builds/linux/MuddsShipyards-51257b3-linux-notes.txt) retain actual
validation and limits. All36 original parents and ten phase gates remain open.

Read this page for **what to do next**, the [backlog](docs/ROADMAP_BACKLOG.md)
for complete remaining scope, and [delivery history](docs/history/ROADMAP_DELIVERIES.md)
for attempt records. No finished or parked item is an active assignment.

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

**Active: HELM-ROLL-RATE turn/release caller, selected11:41UTC2026-10-20.**
Continuous Q/R roll-rate is separate from the G barrel-roll edge. Production
already maps left−1/right+1 and rotates about local FORWARD; use the actual up
vector's signed change about the retained nose to measure roll. One implementer
extends the shared steering caller with an optional measured-vector hook and a
small roll specialization; no copied route or runtime change.

| Field | Fixed result and limit |
| --- | --- |
| Result | Original three-process crew boarding/≥5m departure/brake, both sampled roll-rate signs cause≥3° host roll within host-owned2s, fresh neutral≤1s, measured roll drift≤0.5° for1s and both actual client quaternion attitudes≤2° within2s. |
| Ownership/input | Shared yaw caller plus tiny roll-rate caller/UID only. Synthetic Godot actions→production LocalShipInputSource→ENet→actual host, not OS/hardware/provider injection. Preserve source/wire streams, authenticated actors/seat/entity/ownership, released berth and neutral other actions; no fire/landing/barrel-roll command. |
| Checks | After clean pin/two reviews: headless Dummy import180s, roll direct check-only120s, ONE roll and ONE each affected pitch/yaw regression, original coordinator300s/10s exit grace/outer360s each. Child private Xvfb/x11/Dummy stays inherited; all3 actual OS exits0, one coordinator marker/zero raw diagnostics, source/cache stable. |
| Budget/stop | ≤20min implementation plus review/checks/cleanup inside original11:41–12:41UTC/60min. First unexpected failure STOP; no automatic repair/retry or relaxed limits. Release actions/reap owned processes on every path. |
| Closure | Commit/push actual source result, preserve checked logs/profiles and remove owned scratch. Handback remains required/PARKED; no hardware/native/endurance/full-parent claim or identical playable rebuild for caller-only changes. |

Accepted pitch/yaw turn-release scopes remain source-specific; their changed
shared measurement/neutral guard justifies one affected regression each. Latest
accepted playable remains51257b3. No other helm action or parked route selected.

### Next production alternative: Freight physical terminal interface

**FREIGHT-TERMINAL-INTERFACE is WAITING, not READY.** It is a known missing
player interaction: existing Freight screens/kiosk are decorative. The
[existing handoff](docs/ROADMAP_BACKLOG.md#freight-terminals--physical-interface-and-existing-transfer-owner)
names runtime owners, conserved manifests and ordered completion checks.
The already-asked workflow choice below must resolve before implementation.
Once resolved, select only the physical interface capability, then separately
qualify delivery/cold reload/full branch. Do not count this planning pass or the
Arrow route as delivering the terminal, and do not bypass parked KIT-RELOAD.

### After these cards

Do not pre-assign an entire CRAFT-ACCEPT, ART-FINDINGS or PLAY-* family. Select
one existing child whose dependency is actually satisfied and whose visible
result can be stated in one sentence. If none is ready, record the specific
missing input in that existing child; do not manufacture a validator, another
scope inventory, or a renamed parked probe to fill the queue.

### Waiting decisions — not executable tasks

These questions have already been asked. Keep them pending without asking again
or treating elapsed time as a choice.

| Child | Required input | Result after the dependency resolves |
| --- | --- | --- |
| FREIGHT-TERMINAL-WORKFLOW | Newly asked: physical terminals select the existing Jovian job/show manifests and receipt while keeping automatic landing transfer (recommended), or manual terminal transfer after docking. No answer recorded. | Freeze exact physical endpoint/manifest ownership and one production-interface assignment; preserve existing stock/once-only transfer and full walk/reload/same-ship requirement. Separate from Hauler policy. |
| [AUDIO-NAVIGATOR-CLIENT-REJECTION](docs/COMPLETION_SCOPE.md#client-navigator-rejection-response--bounded-definition-next) | All fresh current refusals including unavailable consumer, or consumer/bridge refusals only. | Correct requester-correlated refusal feedback. Freeze implementation/proof after the choice; prior estimate 45–60min implementation/review, 15–25min checks, 10–15min checkpoint. |
| [HAULER-CARGO-MANIFEST](docs/ROADMAP_BACKLOG.md#hauler-supply-integration-boundaries) | Shared existing stock, separate Hauler stock, or loading-terminal custody. | Actual Hauler cargo admission and conserved source ownership; ordinary delivery remains separately gated. Generation-floor API already exists; freeze files/proof after the choice. Prior estimate 60–90min implementation/checks, checkpoint additional; split before 90min. |
| [TRAVEL-LIMIT Beacon outbound](docs/ROADMAP_BACKLOG.md#beacon-outbound-travel-envelope--proposal-awaiting-decision) | Newly asked:30s or60s unpaused elapsed from engine-start input at the occupied Torrent berth to controlled first Beacon. No answer recorded. | Agree one numeric leg target before adding/qualifying its existing-driver timing; no simulation-only proof, return/roster reduction or parked retry. |
| BOMBER-REARM-POLICY | Newly asked: keep spent rounds across seat changes until explicit rearm/recovery, or refill all four whenever pilot retakes the seat. No answer recorded. | Define the permitted entitlement before any same-hull payload correction; current seat-session reset is not an accepted design choice. |

Other scope, evidence, hardware and authorization dependencies remain in the
[backlog](docs/ROADMAP_BACKLOG.md#external-dependencies-outside-the-ready-queue).
[Parked failures](#parked-failures-and-dependent-work) require their recorded
reopening conditions; they are not the next executable queue.

## Accepted work — source limits retained

Detailed timings, assertions, process inventories and cleanup records belong in
the existing history. These are accepted slices, not closed broad parents.

| Outcome | Accepted scope / remaining boundary |
| --- | --- |
| Remote pitch turn/release | [Sourcef9682a38c](docs/history/ROADMAP_DELIVERIES.md#sampled-remote-pitch--turn-and-release-accepted): both synthetic sampled directions reach actual host, fresh neutral/drift and both client attitudes pass; changed yaw regression passes too. Handback remains PARKED; no OS/device/native/endurance/full-parent acceptance. |
| Aboard help, one cell | [Source e5dfe1117](docs/history/ROADMAP_DELIVERIES.md#aboard-help--one-minimum-scale-1610-cell-accepted): all20 ordinary aboard rows/four pages at1920×1200/.75,124 assertions; source headless layout/wrapping/focus/Close only. Other cells, rendered/device/crew gameplay and final candidate remain open. |
| Arrow pilot precision hit and return/reuse | [Checkpoint51257b3](docs/history/ROADMAP_DELIVERIES.md#arrow-precision-hit-and-return--shipped-on-51257b3): one native timed F press, fresh source/target/sequence/receipt and actual24damage100→76, full two-flight home/offline exits/reboard/UIquit120.991s; source changes extend acceptance automation. Broader craft/combat/damage/recovery/art/native/final remain open. |
| Arrow ordinary return/reuse | [Checkpoint ed1167b](docs/history/ROADMAP_DELIVERIES.md#arrow-ordinary-return-and-reuse--shipped-on-ed1167b): actual archive OS-input two flights/home/offline exits, >7m clear/reboard and normal UI quit PASS106.765s/CAP300; prior two failures retained. Broad craft/native/final gates open. |
| Settings/activity feedback palettes | [Checkpoint2ed93ca](docs/history/ROADMAP_DELIVERIES.md#settings-and-activity-feedback-palettes--shipped-on-2ed93ca): save/recovery/nearby/selection text uses current role once; caller suites and retained layout/package checks PASS. Existing copy/actions/focus/authority and helper retained; headless theme scope, broader journeys/native/human/final open. |
| Gameplay status palettes | [Checkpoint941ef73](docs/history/ROADMAP_DELIVERIES.md#gameplay-status-palettes--shipped-on-941ef73): six gameplay status label families use their current role once and follow palette/high contrast.256 finite state cases/768 actual paints, full accessibility/target-lock/sensor/layout and paired package checks PASS. Text/visibility/thresholds/geometry/authority retained; headless theme scope, broader rendered/device/human/full journeys/final open. |
| Destination Board status palette | [Checkpointc47ca33](docs/history/ROADMAP_DELIVERIES.md#destination-board-status-palette--shipped-on-c47ca33): retained status role updates once and follows current accessibility palette/high contrast;32 actual palette/contrast pairs, full HUD layout/accessibility/Main console and paired package checks PASS. Headless theme scope; rendered/device/human/full journeys/final remain open. |
| Station Defense physical interaction | [Checkpointa59127c](docs/history/ROADMAP_DELIVERIES.md#station-defense-physical-interaction--shipped-on-a59127c): ordinary E discovery/Deploy/status/Reset/retry through existing owners; actual Main15/full placement62 and paired package checks PASS. Full ordinary combat/payment/home remains unqualified. |
| Shared menu contrast | [Checkpointd00ae72](docs/history/ROADMAP_DELIVERIES.md#shared-menu-contrast--shipped-on-d00ae72): role-tinted hover/pressed fills and palette-aware text corrected in shared helper;160 actual menu paints plus existing Help/title/navigation pass. Paired exports/startups/audit accepted; broad UI/rendered/device/human/final gates open. |
| Help CLOSE contrast | [Checkpoint820cc38](docs/history/ROADMAP_DELIVERIES.md#help-close-contrast--shipped-on-820cc38): readable hover/pressed paints,32 actual paint pairs and existing Help navigation PASS; paired exports/startups/audit. Other UI/rendered/device/human/final gates remain open. |
| Paired Wing board admission | [Checkpointf671da9](docs/history/ROADMAP_DELIVERIES.md#paired-wing-board-admission--shipped-on-f671da9): third solo board contract, departure/authority gates, actual Wing roster/objective/no-credit lifecycle pass. Full ordinary two-kill/home and other encounter gates remain open. |
| On-foot help, one cell | [Source5ac9d3ef0](docs/history/ROADMAP_DELIVERIES.md#on-foot-help--one-minimum-scale-1610-cell-accepted): all four pages at1920×1200/.75 pass geometry/wrapping/focus. Other help modes/cells, rendered/human/device and final candidate remain open. |
| Tractor look inversion | [Checkpoint34d4b9e](docs/history/ROADMAP_DELIVERIES.md#tractor-look-inversion--shipped-on-34d4b9e): saved/live existing on-foot inversion reaches tractor mouse/pad pitch; full tractor/settings/package checks pass. Physical devices, ordinary/full controls and final candidate remain open. |
| Begin Shift focus / press | [Checkpoint923d7b3](docs/history/ROADMAP_DELIVERIES.md#begin-shift-focus-contrast--shipped-on-923d7b3): dark text clears measured4.5/7 contrast floors across existing palettes. Other readability, saved profiles, devices and final accessibility remain open. |
| Title overflow | [Checkpoint19e7990](docs/history/ROADMAP_DELIVERIES.md#title-menu-overflow--startup-actions-kept-on-screen): all title actions fit the measured viewports. Focus contrast is separately delivered on923d7b3; other title states and full accessibility remain open. |
| Guided / initial interceptor | [Checkpoint3d92b91 ordinary3/3](docs/history/ROADMAP_DELIVERIES.md#guided-checkpoint3d92b91--original-ordinary-route-accepted3of3), including home/shutdown/physical exit. Acceptance stays on those bytes; later checkpoints and final candidate are not covered. |
| Saved Convoy / credits | [Checkpoint3d92b91](docs/history/ROADMAP_DELIVERIES.md#saved-convoy-objective-and-planetary-credits--shipped-on-3d92b91): paused-save guidance and planetary ambience attribution. Full Convoy play/endurance remains open. |
| Host-stall recovery | [Source3d6b1b513](docs/history/ROADMAP_DELIVERIES.md#original-host-stall-route--current-source-accepted): original full independent suite, both600-step stalls and original2s actions. No unchanged rerun; ordinary handback, full matrix, final package/native/endurance remain separate. |
| Future save envelope | [Source4b66b3548](docs/history/ROADMAP_DELIVERIES.md#future-save-outer-envelopes--sourcelinux-real-file-case-accepted): real-file Linux refusal/preservation. Other formats, installed/native/UI recovery remain open. |
| Corrupt-primary preservation | [Checkpoint9326614](docs/history/ROADMAP_DELIVERIES.md#corrupt-save-preservation--shipped-on-9326614): retain damaged bytes before replacement and block conflicting retained copies. Broader recovery remains open. |
| Blocked repair feedback | [Checkpoint49047eb](docs/history/ROADMAP_DELIVERIES.md#blocked-save-repair-feedback--shipped-on-49047eb): known preservation refusal is explained without changing persistence policy. |
| Planning definitions | [36-parent crosswalk](docs/ROADMAP_BACKLOG.md#coverage-of-the-original-remaining-outcomes) names each next child and dependency; [packaged lifecycle definition](docs/ROADMAP_BACKLOG.md#packaged-ordinary-lifecycle--life-package-define) names uncovered cases. Neither is gameplay acceptance or a whole-project estimate. |

## Turning the remaining scope into executable work

Use the existing [named child inventory](docs/ROADMAP_BACKLOG.md#concrete-child-outcomes)
and [family contracts](docs/ROADMAP_BACKLOG.md#family-contracts), rather than
creating another tracker. Each selected card must answer these questions before
implementation or engine execution:

| Required field | A usable answer |
| --- | --- |
| Result | One thing the player can do, content they can encounter, or executable build/release capability; name its original parent and existing child ID. Label planning and qualification separately. |
| Prerequisites | Specific accepted dependencies or missing input. WAITING, GATED and PARKED are not READY. |
| Ownership | Exact production files/component and implementer; disjoint ownership for parallel work. |
| Proof | Exact focused command or ordinary action, expected result and fixed duration. Keep broader parent journey requirements visible and unchanged. |
| Budget and stop | Implementation estimate, check duration and stopping condition. Prefer 30–60min implementation; split before 90min into useful capabilities. A new failure ends the attempt. |
| Closure | Actual outcome/time, source versus packaged status, remaining requirement, commit/push, owned cleanup and one next action. |

A broad parent closes only when all its original requirements are accepted.
For missing craft, settle SPEC first, then replace BUILD-SPLIT placeholders with
actual hull/access, handling, role/weapon and recovery capabilities. Do not invent
a fixed task count per ship. Retain complete CRAFT-ACCEPT journeys.

Keep at most three executable cards. Before starting another qualification chain,
identify an independent production alternative or record its concrete missing
definition. Do not expand an investigation into a succession of adjacent probes.
The earlier RPC-cache capture is complete. Matching patched templates remain
unavailable and Windows compilation is parked; neither is an automatic next task.

## Latest playable result

**Checkpoint51257b3** adds the ordinary pilot precision-hit phase to the existing
Arrow return/reuse command: one real24damage hit, attitude restoration and two
complete flights/home docks/offline exits/reboard/normal UIquit. Actual archive
executable PASS120.991s, zero diagnostics and full process/input cleanup.
Existing palette/Defense board/Wing admission/inversion/title/credits/save work
is retained. No new ship, weapon or combat encounter is claimed.

[Windows checkpoint ZIP](builds/windows/MuddsShipyards-51257b3-checkpoint.zip),
[build notes](builds/windows/MuddsShipyards-51257b3-notes.txt),
[actual validation and limits](docs/history/ROADMAP_DELIVERIES.md#arrow-precision-hit-and-return--shipped-on-51257b3).
Defense/Wing full combat/home, craft damage/recovery, native Windows/GPU/device/
audio/human/final release remain open. Old Guided3/3 is not transferred here.

## Parked failures and dependent work

These are unfinished outcomes, not candidates for an unchanged retry. Exact
contracts and cumulative attempt records remain in the retained history.

| Outcome | Last actual result | Condition before more work |
| --- | --- | --- |
| PLAY-DEFENSE ordinary route /13 | Candidatea480c0fbb pushed/unmerged: actual E Deploy accepted, but corrective walk_arrow stationary33.15s and whole34s timeout before boarding. | PARK after original35.963s and one corrective84.239s failure; cumulative406.401s including16 passing stages. No player kill/payment/home/reset/UIexit; no second repair/retry selected. Unique candidates/results preserved; owned scratch cleaned28.24min. |
| Ember first-relay cold cut /14,31 | [Archive923d7b3](docs/history/ROADMAP_DELIVERIES.md#ember-first-relay-cold-cut--runtime-completes-parent-comparison-fails) FAIL312.812s at parent exact durable-state comparison; arm-9/resume0, engine diagnostics0, runtime continuation and receipts0→1. Only two compared coordinate scalars differ by one binary64 ULP. | STOPPED; no repair/retry/cap increase or retroactive comparison relaxation. Contract review and exact-runtime caller correction complete; corrected full package run NOT_RUN and requires a separately frozen selection. No full-cut/location/canonical/installed acceptance; all owned scratch cleaned9.50min within20min. |
| Jovian postdock exit /16,20,26 | [Corrective candidate0d225bee8](docs/history/ROADMAP_DELIVERIES.md#docked-pilot-hold--focused-pass-full-exit-stops-at-cabin-walk): pose322/import/compile PASS; full route145.995s FAIL at15s cabin walk after actual standing, retained pilot at exact dock. Unmerged/withheld; exports NOT_RUN. | PARKED after failed runtime plus one corrective attempt: combined392.470s current stages plus retained8054/e147 parser failures. No second repair, retry, tolerance/cap increase or renamed adjacent probe. Walking cause unproved; later node-path errors are inherited failure capture. All owned scratch cleaned17.09min inside original45min. |
| Habitat common-entry view /9,12 | [Source8a6339b91](docs/history/ROADMAP_DELIVERIES.md#habitat-arrival-view--readback-timed-out-before-image): import passes; full-Main player-height readback times out180.842s before PNG or view metadata. Cumulative201.494s; no observed defect/no-finding. | PARKED. Concrete supported capture-boundary change before selection; no renderer/room substitute, cap increase or unchanged retry. Actual eye stage was not proved reached; accepted Habitat runtime scopes remain. |
| Courier clear /11 | [Candidatecb9d76fa5](docs/history/ROADMAP_DELIVERIES.md#courier-ordinary-clear--escaped-without-player-damage), pushed/unmerged: prechecks pass; ordinary attempt fails70.377s, ESCAPED at1400m, hull78/78, no player hit/kill or home completion. Cumulative165.917s. | PARKED/withheld. Fresh Courier-window emission/ray/resolver facts are missing; generic shot receipt can be stale. No weapon/aim cause established, repair/retry or public checkpoint selected. Preserve original route/caps; other Courier outcomes need separate selection. |
| Matching RPC-cache templates /25,32 | [Linux built; Windows cold/incremental compilation timed out](docs/history/ROADMAP_DELIVERIES.md#matching-rpc-cache-templates--stopped-at-windows-compilation-budget). No accepted matching pair; callback repair is unverified. | PARKED; no further compilation or dependent browser attempt selected. Existing recipe/JSON fixture remain delivered; empty callable metadata and similar Window errors establish no cause. |
| BROWSER-ORDINARY /25 | Candidatee944f52:89Python/privacy/35join/package checks pass, actual routeFAIL40.554s at NetworkSession tree_exited disconnect error; cleanup fixture command rejected. | PARKED/unmerged/withheld. Subsequent passive capture identifies retained native RPC-cache callback; it does not qualify the route. Full continuation NOT_RUN. Original raw data/eight builds preserved; scratch cleaned. |
| AFT-CONSOLE-VIEW /9,12 | Standalone actual-module Xvfb/Forward+/llvmpipe capture FAIL120.485s after camera setup; no image or visual finding. | PARKED; source/root cause unproven. No cap increase, alternate backend/view or retry selected. Owned scratch cleaned; raw results retained. |
| WALK-OBSERVATION /7,9 | Two caller failures retained; numeric e390/unchanged game4c58 completes54-goal travel/view/home prefix then FAIL89.064s on rootWindow signal disconnections after focused Exit. | PARKED; full task remains unaccepted, no clean exit0. Capture identifies the Tooltip with stored pairs still present across errors. Laterbae551d58 private route PASS, but no visible tooltip/retirement, so repair acceptance INCONCLUSIVE and candidate withheld. No second attempt selected. |
| PERIMETER-LIVE /11 | Candidateaa88b5a73 unmerged; staged Hold52/director149/asset12/board58/HUD9 pass. GameFlow FAIL90.178s before Hold entry; exports NOT_RUN. | PARKED after cumulative363.897s/three failures and independent review. Concrete change addressing retained full GameFlow route boundary plus separate selection required; no additional correction/retry/cap increase/narrowed acceptance. |
| PLAY-BEACON-HOME /13 | Candidatea612ea686 FAIL37.713s guarded/37.419s driver at ActivityBoardButton Return/frame1233; same two root Window signal-disconnection diagnostics. Eleven prechecks pass; no settlement/home/L/E reached, no file captures. Unmerged/withheld. | PARKED on UI-BOARD-FOCUS. Recurrence supplies no popup/connection-removal cause; no retry/repair/cap change. Preserve original UI two-component9.627s and Mining budgets. |
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

### Performance workload definition — implementation boundary clarified

Seven benchmark selectors already cover station walking, Torrent flight,
Halyard cabin repetition, Torrent combat reuse and three surface loops.
Whole orbit-to-surface expedition repetition is uncovered; its representative
craft/world/cycle and relationship to existing world endurance remain undefined.
[Coverage and next definition](docs/ROADMAP_BACKLOG.md#benchmark-workload-definition--retained-coverage-and-missing-decision).
PERF-ROUTES-DEFINE stays open. This source handoff adds no gameplay or native
performance result and selects no new route or parked startup retry.

### Fleet route selection — full reuse scope retained

Source review confirms three assigned Fleet Dock berths, including Bulwark;
the completion roster's deferred-Dock03 sentence was stale. Original all-shipped
reach/reuse covers nine craft and shares existing CRAFT-ACCEPT journeys.
[Exact scope and missing runnable boundary](docs/ROADMAP_BACKLOG.md#fleet-access-and-reuse--shared-acceptance-boundary).
No three-berth threshold substitute, renamed Sandbox retry or new engine run
selected. Fleet access/reuse and presentation acceptance remain open.

### Fleet snapshot budget — existing accepted result reconciled

NET-FULL-SNAPSHOT was incorrectly listed as unscheduled. Retained raw results
on accepted330a39ce3 show the complete Main/ENet suite PASS382 in172.837s:
nine-craft forced-full/live envelopes4656/4656 bytes, exact snapshot decoding
and transport fragmentation within the unchanged12000-byte ceiling.
[Existing delivery and retained failure/repair](docs/history/ROADMAP_DELIVERIES.md#net-component-powers--host-output-and-bounded-live-updates-accepted).
The aggregate child is DONE on that source. No new engine run, CPU benchmark or
gameplay delivery is claimed; ordinary multiplayer, native, endurance and final
candidate qualification remain open. All36 parents/ten phase gates remain open.

## Finish rules for every next task

1. Select one named player/build outcome from the inventory. State parent, exact
   files/owner, prerequisites, proof command/action, unchanged criteria, implementation
   estimate and check duration before starting. Prefer 30–60min implementation;
   split before 90min into capabilities, not arbitrary test/evidence stages.
   Before starting a further qualification chain, identify one independently
   executable production alternative or record the concrete missing definition.
   For future cards, distinguish checks protecting the changed behavior from
   larger parent journey gates before implementation; do not retroactively narrow
   a failed card's frozen acceptance.
2. Keep the selected result fixed. A new defect ends that attempt; it does not
   silently enlarge it. Record the failed outcome and remaining work. There is no
   automatic repair allowance: any repair must first be separately selected.
   Failed task plus one attempted repair requires cumulative priority review before more work;
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
