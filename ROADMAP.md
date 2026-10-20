# Development roadmap

**Status: playable development alpha; project completion is unproven.** Latest
accepted checkpoint: **2ed93ca**. Settings save/recovery and activity feedback
now use their current role colours once and follow palette/high-contrast changes.
Six gameplay readouts apply their current
role colour once and follow palette/high-contrast switches: mode, engine,
throttle, hull damage, component status and target lock.
Destination Board status refreshes apply
the current palette role once and follow palette/high-contrast changes.
The physical Station Defense board supports
ordinary E Deploy/status/terminal Reset and settlement retry through existing
owners. Shared menu contrast and the local Help CLOSE paints are retained.
The existing combat board offers solo
Paired Wing after Heavy Breach/Torpedo, with on-foot arm/cancel and launch only
after boarding and physical departure. Wing explicitly offers no credit reward.
It retains tractor inversion, title readability/overflow, Convoy guidance,
planetary credits and earlier save protection.
[Windows notes](builds/windows/MuddsShipyards-2ed93ca-notes.txt) and
[Linux notes](builds/linux/MuddsShipyards-2ed93ca-linux-notes.txt) state checks and
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

### Selected — Arrow ordinary return and reuse command

**CRAFT-ACCEPT-ARROW, parents7/10/11; executable release capability.** Deliver
`run_native_sortie.py --route arrow-return-reuse` for one fresh ordinary package
session: Begin Shift, same supported Player walks the clear Freight-side lane to
Arrow, physical E boarding, normal flight demand/lease release and excursion,
strict occupied home dock, neutral automatic OFFLINE and physical exit; walk
more than7m clear to release reboard suppression, then a second real boarding,
flight/home/offline/exit and normal UI quit. No teleport, gameplay calls, tuning,
time-scale override, staged damage or synthetic in-engine input.

Implementation owns only startup loader selector, read-only native-sortie
observer, existing Python OS driver and its existing Python/startup-privacy
checks. Retain all physics observations for identity/default controls/tuning,
supported walking, actual departure and strict berth/lease/exit transitions;
OS input acts on the latest observation. Root reviews source before execution.

**Freeze:**2026-10-20 09:58–10:58UTC,60min including cleanup; estimate25–35min
implementation/review,10–15min checks/export, one originalCAP300 ordinary route.
After clean candidate: full existing native-driver Python suite; headless/Dummy
import and startup privacy; paired clean exports, direct/archive/payload strict
startup and actual PCK/PE/archive audit; exactly one isolated X11/Dummy Arrow
route from its exported ELF, exit0 plus `NATIVE_ARROW_RETURN_REUSE_OK`.
Root freezes exact pin/commands/owners before engine execution. First unexpected
failure stops all later stages; no automatic correction, rerun or cap increase.
Withhold candidate/publication on failure and retain all elapsed work/results.

Success qualifies only this ordinary return/reuse capability on its named bytes.
Weapon hits, damage/repair/destruction recovery, cross-craft/Main re-entry,
rendered/native/device/full craft gates remain open. Original all-nine/54-waypoint
Sandbox and parked Defense board→Arrow route stay unchanged; neither is
accepted by this independent craft route. Independent production alternative:
Freight terminal integration is concrete but awaits its already-asked workflow
choice; no alternative gameplay behavior is invented while it is pending.

Latest delivered: settings and activity feedback colour repair, recorded below.
Six gameplay status palette repairs remain accepted on941ef73.
Destination Board status palette repair remains accepted onc47ca33.
Station Defense physical E interaction remains accepted ona59127c. Accepted Wing
board admission remains onf671da9; its full ordinary route is still parked.
[Admission scope and checks](docs/history/ROADMAP_DELIVERIES.md#paired-wing-board-admission--shipped-on-f671da9)
remain in the existing history and accepted-outcome table.

### Ordinary Wing route — parked after admission-driver failure

Candidateb40c62eb3 remains pushed, unmerged and unpublished. Its board request
was outside the production3D radius; full Wing combat/home remains unaccepted.
Cumulative344.298s and original60min budget are retained. No retry or second
correction selected. [Full result and reopening condition](docs/history/ROADMAP_DELIVERIES.md#ordinary-wing-route--board-admission-driver-fails).

### Help CLOSE contrast — delivered in checkpoint820cc38

Accepted local hover/pressed text repair; rendered/device/human/broad UI gates
remain open. [Actual checks, package and cleanup](docs/history/ROADMAP_DELIVERIES.md#help-close-contrast--shipped-on-820cc38).

### Shared menu-button contrast — delivered in checkpointd00ae72

Accepted shared hover/pressed text repair; layout/actions and local Help paints
retained. [Actual checks and limits](docs/history/ROADMAP_DELIVERIES.md#shared-menu-contrast--shipped-on-d00ae72).

### Station Defense physical interaction — delivered in checkpointa59127c

Ordinary E Deploy/status/Reset/retry accepted through existing owners, with
separate presses, refusal/debt gates and unchanged34s encounter. Full combat/home
remains open. [Checks, retained correction and cleanup](docs/history/ROADMAP_DELIVERIES.md#station-defense-physical-interaction--shipped-on-a59127c).

### Station Defense ordinary route — parked after post-Deploy walk timeout

Candidatea480c0fbb remains pushed/unmerged/unpublished. Deploy worked; the
post-Deploy walk stayed stationary33.15s and the whole34s encounter timed out
before boarding. No player kill/payment/home/reset/UIexit. Cumulative406.401s
retained; no second repair/retry selected. [Full result and reopening condition](docs/history/ROADMAP_DELIVERIES.md#ordinary-station-defense--deploy-accepted-post-deploy-walk-times-out).

### Destination Board status palette — shipped on c47ca33

Retained status role/palette/high-contrast update accepted; full planetary
journeys and rendered/device/human/final gates remain open. [Actual checks and cleanup](docs/history/ROADMAP_DELIVERIES.md#destination-board-status-palette--shipped-on-c47ca33).

### Gameplay status palettes — shipped on 941ef73

Six gameplay readouts use their current role once; unchanged telemetry skips
registry scans. Copy/visibility/thresholds/reticle geometry retained. [Actual checks, package and limits](docs/history/ROADMAP_DELIVERIES.md#gameplay-status-palettes--shipped-on-941ef73).

### Settings and activity feedback palettes — shipped on 2ed93ca

Four remaining feedback Label families now use the unchanged current-role
helper: settings save result, recovery title, nearby action feedback and activity
selection status. Copy/visibility/actions/focus/authority retained. All12 frozen
stages passed first attempt,174.247s; caller suites11/35/26/113 assertions,
HUD layout552, paired exports/three strict startups/1521-entry package audit.
[Checkpoint2ed93ca, actual validation and limits](docs/history/ROADMAP_DELIVERIES.md#settings-and-activity-feedback-palettes--shipped-on-2ed93ca).

Owned checkout/profiles removed9.57min within original45min. Six closed task
record folders compacted from739 to97 loose files; originals preserved in checked
archives. Two more closed accepted records (Paired Wing admission and tractor
inversion) are now compacted from281 to29 loose files, saving about115MiB.
Original archive entries and published build hashes were verified; all recorded
owned processes are absent. Summaries and reusable helpers remain accessible.
No broader UI, recovery/activity journey, native/human or final-release
acceptance claimed.

### Freight terminal integration — bounded handoff, workflow pending

WALK-FREIGHT source preflight found missing production interaction: Freight's
screens/kiosk are decorative; reusable source terminal is not instantiated and
the destination terminal is on Cinder. Existing Jovian cargo binds ship/berth
manifests and transfers automatically on landing. Corrected the completion roster
from implemented to missing physical integration; no knowingly incomplete walk
or new engine probe was run.

[Ordered handoff](docs/ROADMAP_BACKLOG.md#freight-terminals--physical-interface-and-existing-transfer-owner)
now separates physical interface, genuine existing transfer journey, original
parked KIT-RELOAD and full ordinary branch acceptance. Original conservation,
committed receipt/reload and same-ship return remain required; inspect-only cannot
close the row. One workflow question is pending below. No production task or
qualification execution selected; no scratch checkout created.

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

**Checkpoint2ed93ca** corrects settings save/recovery and activity feedback text
colours across state and accessibility palette/high-contrast changes. It retains
the six gameplay readout and Destination Board fixes, physical Station Defense E,
shared menu/Help contrast, Paired Wing admission, tractor inversion, title
readability, Convoy, credits and saves.

[Windows checkpoint ZIP](builds/windows/MuddsShipyards-2ed93ca-checkpoint.zip),
[build notes](builds/windows/MuddsShipyards-2ed93ca-notes.txt),
[actual validation and limits](docs/history/ROADMAP_DELIVERIES.md#settings-and-activity-feedback-palettes--shipped-on-2ed93ca).
Full ordinary Defense combat/payment/home, Wing kills/home, native Windows/GPU/
device/audio/human and final release remain open. Guided3/3 on3d92b91 is not
transferred to this package.

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
