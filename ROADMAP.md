# Development roadmap

**Status: playable development alpha; project completion is unproven.** Latest
accepted checkpoint: **d00ae72**. Shared menu buttons now keep readable text
while hovered/pressed across the existing palettes and contrast modes.
The accepted local Help CLOSE paints are retained.
The existing combat board offers solo
Paired Wing after Heavy Breach/Torpedo, with on-foot arm/cancel and launch only
after boarding and physical departure. Wing explicitly offers no credit reward.
It retains tractor inversion, title readability/overflow, Convoy guidance,
planetary credits and earlier save protection.
[Windows notes](builds/windows/MuddsShipyards-d00ae72-notes.txt) and
[Linux notes](builds/linux/MuddsShipyards-d00ae72-linux-notes.txt) state checks and
limits. Inline browser progress/timeout/retry remains accepted on20e90c9;
paused LAN discovery on042c701. Beacon departure/traversal/once-only saved reward
qualification on e06550e is retained in its recorded scope. Beacon home/dock/exit, Perimeter Hold,
client rejection and real listening remain unfinished. All36 original parents
and ten phase gates remain open.

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

Latest delivered: shared menu-button contrast, recorded below. Accepted Wing
board admission remains onf671da9; its full ordinary route is still parked.
[Admission scope and checks](docs/history/ROADMAP_DELIVERIES.md#paired-wing-board-admission--shipped-on-f671da9)
remain in the existing history and accepted-outcome table.

### Ordinary Wing route — parked after admission-driver failure

Candidate **b40c62eb3** is pushed on `feat/wing-ordinary-route-20261020`,
unmerged and unpublished. Accepted checkpoint at that attempt’s closure was
**f671da9**.
The missing ordinary route was implemented and attempted from an empty private
profile; its first Heavy Breach board arm failed before any flight or combat.
At frame923 the player was2.905307m from the board, beyond its production2.8m
3D radius. The driver used candidate/settled state as its E-arm condition, then
waited without handling the actual `out_of_range` rejection. The board stayed
unarmed, generation0, director idle. No prerequisite withdrawals, Wing kills,
home return or normal UI exit were qualified.

Original observer parse failure100.874s is retained. One selected explicit-bool
correction passed20 observer assertions15.693s; expression/assertions unchanged.
Import, driver safety/privacy, paired exports, three strict startups and actual
1521-entry PCK/PE/archive audit passed in their recorded scopes. Root stopped the
exact owned route supervisor after observing the rejection; route exit143 after
67.690s, driver success=false. Ten passing stages175.734s; all12 stages including
both failures344.298s. Independent cumulative review: **PARK/noGO**. No automatic
second correction, retry, cap increase or admission-only substitute.

Cleanup23.77min inside original07:14–08:14UTC/60min: all65 observed identities
absent, inputs released and game/input helper/Xvfb reaped. Seven unique candidate
payload/metadata files retained privately and hash-verified; ELF verified inside
the retained tarball,25 profile entries archived/verified, helpers preserved.
Owned clean pushed checkout/import cache/profiles/helpers removed. Only results
remain in `/srv/mudds-work/wing-ordinary-route-20261020/results/`.
[Actual result](docs/history/ROADMAP_DELIVERIES.md#ordinary-wing-route--board-admission-driver-fails).

Future reopening has one concrete implementation seam: approach inside the
actual3D board radius with margin and fail promptly on an observed rejection.
Preserve gameplay radius/controls and original full route: real Heavy/Torpedo
withdrawals, both fresh target-specific Wing weapon kills, physical safe home
and normal UI exit. This is not a new execution selection. Other combat/repeat/
recovery/network/native/human gates remain open; parked Courier/Perimeter are
not adopted. Hauler still waits on its already-asked stock choice.

### Help CLOSE contrast — delivered in checkpoint820cc38

ACCESS-HELP / parents12,29: local hover/pressed fills are darker and their text
follows the active palette. Other menu button defaults, Help focus/outline/
geometry/navigation/paging/close remain. Existing accessibility suite252 checks
PASS, including32 actual CLOSE paint pairs across4 palettes×2 contrast modes×
4states, minimum7.767:1 in regular/high-contrast modes against original4.5/7
floors. Existing Help20 assertions PASS. Headless theme-paint scope; rendered,
human, devices, other Help controls and broad UI acceptance remain open.

All9 frozen stages PASS first attempt, zero diagnostics, 159.893s:
import, accessibility, Help, paired exports, three strict startups and actual
1521-entry PCK/PE/archive audit. Windows payload startup uses Linux engine;
native Windows/GPU/listening/human/final gates remain NOT_RUN/open. Cleanup
7.47min inside original07:41–08:21UTC/40min: all53 observed
identities absent,11 public files hash-verified,21 profile entries archived/
verified, helpers preserved; owned checkout/cache/profiles/helpers removed.
[Actual delivery](docs/history/ROADMAP_DELIVERIES.md#help-close-contrast--shipped-on-820cc38).

### Shared menu-button contrast — delivered in checkpointd00ae72

ACCESS-VIEWS / parents12,29: the shared helper now supplies darker role-tinted
hover/pressed fills and palette-aware light text. Resume, Settings, Restart,
Exit, Back and other shared consumers receive the correction; normal/focus,
geometry/actions/navigation and accepted local Help CLOSE paints remain.
Existing accessibility443 checks PASS, including160 real production menu paint
pairs across5roles×4states×4palettes×2contrast, minimum8.359:1 against original
4.5/7 floors. Help/title paints, reset/focus/outline/geometry/navigation/action
wiring and existing Help20/controller navigation pass.

All10 frozen stages PASS first attempt, zero diagnostics, 167.942s: import,
focused checks, paired exports, three strict startups and actual1521-entry
PCK/PE/archive audit. Headless theme measurements; no rendered/human/device or
whole-UI qualification. Windows payload startup uses Linux engine; native
Windows/GPU/listening/human/final gates remain NOT_RUN/open. Cleanup
8.12min inside original07:49–08:29UTC/40min: all56 observed identities
absent,11 public files hash-verified,23 profile entries archived/verified,
helpers preserved; owned checkout/cache/profiles/helpers removed.
[Actual delivery](docs/history/ROADMAP_DELIVERIES.md#shared-menu-contrast--shipped-on-d00ae72).

### Station Defense full-play driver — source-blocked before edits

PLAY-DEFENSE preflight found a concrete missing production interface before any
edits, tests, engines or export: GameFlow excludes station candidates without
`get_interaction_prompt()`, and StationDefenseActivityBoard lacks it. Its existing
`interact()` starts/retries debt, while Reset is separate. Thus the required E
Deploy/Reset route cannot run. Worktree remains clean; no knowingly failing
route or substitute Nearby UI proof selected. Original full3wave/fourkill/payment/
home/reset contract stays open. Source mapping established actual Arrow support
and whole34s semantics; neither clock nor roster needs a speculative change.

### Selected Station Defense physical interaction fix

DEFENSE-PHYSICAL-INTERACTION / parent13. Retain original **07:58–08:58UTC/60min**
including preflight, implementation/review/checks, paired build and cleanup.
Add snapshot-driven physical prompt and dedicated ordinary-interaction dispatch
through existing GameFlow start/reset wrappers. Idle E Deploy; active status-only
(no destructive reset); completed/failed/aborted E Reset through existing reset
owner; pending debt E retries settlement first; refused session stays protected.
Keep direct `interact()`/Nearby UI start and explicit reset/recover APIs compatible.
Preserve3D2.6m range/facing, on-foot/armed-sortie gates,34s immediate-start clock,
1/2/1 roster, combat/health/rewards/persistence/network and role owners.

One high implementer owns scripts/activities/station_defense_activity_board.gd,
scripts/game/game_flow.gd and a focused actual-Main interaction regression/UID;
extend existing production-placement regression only if needed for genuine debt
prompt selection. One high reviewer, root integration/publication/cleanup.
Estimate15–25min implementation/review; no driver/observer/CLI changes now.

Freeze clean source/exact commands before engines: import180s; existing full
station_defense_production_placement_test.gd300s; new actual-Main physical
tests/game_flow_station_defense_interaction_test.gd120s. Disclose staged avatar/terminal setup: actual nearby-area
candidate/facing/ordinary Player E intent must select board, Deploy begins real
encounter, active repress preserves it, terminal Reset exposes next Deploy;
range/facing/competing-board/refusal and debt fences retain existing owners.
This is production entry/reset regression, not full ordinary combat acceptance.
Paired exports180s each; three strict startups120s each; existing PCK/PE/archive
audit90s. Every Godot headless/Dummy. First unexpected failure stops, no automatic
repair/retry/cap increase or renamed adjacent test. Publish only reviewed passing
checkpoint. Archive/hash-verify unique data/public files and remove owned clean
pushed/integrated checkout/cache/profiles/helpers/duplicate exports. Full
PLAY-DEFENSE driver/combat/payment/home remains separately unqualified; parked
Wing/Perimeter/Breach/Tooltip and native/hardware/human/final gates stay open.

### Selected single placement-test declaration correction

Import PASS20.646822s; placement test stopped at parse error16.380624s before
assertions: newly added `before_retry_generation :=` cannot infer the chained
Variant return. Owned supervisor terminal, no survivors; exports/new Main test
NOT_RUN. Retain source4583734e8 and all37.027447s plus raw failure.
Select exactly `var before_retry_generation: int = ...`, expression/assertions/
production code unchanged. One source-only implementation/review, one full
corrective placement300s; retain accepted import on identical production/classes,
then original new Main120s/exports/startups/audit only if it passes. Original
07:58–08:58UTC/60min unchanged. Another unexpected failure triggers cumulative
review/park; no second repair, cap increase or narrowed proof.

### Waiting decisions — not executable tasks

These questions have already been asked. Keep them pending without asking again
or treating elapsed time as a choice.

| Child | Required input | Result after the dependency resolves |
| --- | --- | --- |
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

## Observation walk — normal exit remains blocked

WALK-OBSERVATION remains unaccepted: completing all54 waypoints/view/home does
not pass the required normal UI exit. See its parked row below and the existing
[numeric caller result](docs/history/ROADMAP_DELIVERIES.md#observation-numeric-contract--runtime-exit-failure).

### Selected diagnosis — popup lifetime during normal Exit

The diagnosis is stopped. The [retained capture](docs/history/ROADMAP_DELIVERIES.md#observation-popup-lifetime-capture--failure-boundary-identified)
identifies the TooltipPanel below PlanetaryDestinationOpenButton; both stored
connection pairs remain across the error. Attempted native Callable identity and
cause are unresolved; no shared cause with Board/RPC is established. The later
cleanup-order candidate remains unmerged/inconclusive. Preserve the complete
route, original90min budget and cumulative733.226s across the four retained
failures; no automatic probe, repair, retry or cap increase is selected.

## Latest playable result

**Checkpointd00ae72** keeps shared menu-button text readable while hovered or
pressed across existing palettes and contrast modes. It retains Help CLOSE,
Paired Wing board admission, tractor inversion, title readability/overflow,
Convoy, credits and saves.

[Windows checkpoint ZIP](builds/windows/MuddsShipyards-d00ae72-checkpoint.zip),
[build notes](builds/windows/MuddsShipyards-d00ae72-notes.txt),
[actual validation and limits](docs/history/ROADMAP_DELIVERIES.md#shared-menu-contrast--shipped-on-d00ae72).
Full ordinary Wing kills/home, native Windows/GPU/device/audio/human and final
release remain open. Guided3/3 on3d92b91 is not transferred to this package.

## Parked failures and dependent work

These are unfinished outcomes, not candidates for an unchanged retry. Exact
contracts and cumulative attempt records remain in the retained history.

| Outcome | Last actual result | Condition before more work |
| --- | --- | --- |
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
