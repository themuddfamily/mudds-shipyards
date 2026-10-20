# Development roadmap

**Playable development alpha; a completion date is not yet defensible.**
All **36 original parent outcomes** and **ten phase gates** remain open.
Nine of the eventual 17 craft exist; eight still need supported specifications
and implementation. Partial acceptance is retained in the backlog; it is not
whole-feature completion.

Latest playable checkpoint: **c78e0ac**. The release workflow now verifies Heavy
Breach earned debt across an actual killed game, cold Resume/payment and a further
cold paid replay. Source and archive-extracted Linux transactions pass; staged
combat setup is disclosed. Perimeter Hold remains the fourth physical board
contract, with three live attackers and its 90-second core objective, requiring integrity strictly above35%.
[Windows ZIP](builds/windows/MuddsShipyards-c78e0ac-checkpoint.zip),
[Windows notes](builds/windows/MuddsShipyards-c78e0ac-notes.txt),
[Linux notes](builds/linux/MuddsShipyards-c78e0ac-linux-notes.txt).

This page is the working queue. The
[36-parent crosswalk and named children](docs/ROADMAP_BACKLOG.md#coverage-of-the-original-remaining-outcomes)
retain complete remaining scope; the
[original ten phases](docs/history/ROADMAP_SCOPE_20261017.md)
retain the completion promises. Attempt details belong in
[delivery history](docs/history/ROADMAP_DELIVERIES.md), not this queue.

## What finishing requires

These are delivery groups, not equally sized tasks or a percentage. They may
proceed independently where their actual dependencies permit. No release of the
current nine craft silently removes the remaining eight original commitments.

| Delivery group | Completion check | Smallest next boundary |
| --- | --- | --- |
| Fleet, station and combat | Applicable ordinary craft/role/weapon/damage/recovery/home/reuse journeys; remaining original craft built; station branches and actual art findings resolved | Select one named capability or complete journey from the existing inventory. Missing craft require SPEC, then actual build cards; no whole-ship assignment. |
| Activities and worlds | All twelve activities and required repeats; three canonical world returns and 21 shared-world cells, with rewards/save/recovery | One named activity journey or world/case at a time, preserving the complete outbound→result→usable home contract. |
| Multiplayer | Browser, helm, crew, damage/actor and postdock cases; dedicated-server/two-client baseline, original 30-minute endurance and chosen capacity | A named independently runnable case. Parked handback/boarding failures remain dependencies, not automatic retries. |
| Saves and recovery | Expected continuation, actual interruption/restart and usable controls for required contexts; conserved progress/rewards and protected invalid data | One context and durable boundary with its expected resume/safe-home behavior settled first. Four active terminal-owner policies remain unresolved. |
| Presentation, controls, audio and performance | Applicable views/captures, physical devices, authorized listening and representative native measurements; demonstrated defects fixed | One actual defect or one explicitly selected qualification case. Headless/software results retain their limits. |
| Final release | Frozen integrated candidate; full local matrix, packages, installation, rights/signing and authorized distribution with matching bytes | Final-candidate work follows required integration. Desktop targets, rights/signing inputs and applicable external gates remain open. |

The remaining task count is still unknown: missing-craft build splits, actual
presentation findings, unresolved policies and measurement cases have not all
been defined. Do not turn test counts, commits or row counts into project progress.

## Execution now

**Current focus: finish or explicitly account for existing unmerged work.**

Resolve one existing branch at a time. Before selecting another, either merge and
push accepted work and delete the branch, or preserve its unique source/results
and record the exact unmet requirement and blocker. A failed check does not
automatically authorize an adjacent task or retry.

**170 local and 93 live remote branches deleted; 15 local and 18 live remote
branches remain, including main (17 non-main remote).** Counts describe refs,
not completed features. [Branch accounting and closeouts](docs/history/ROADMAP_DELIVERIES.md#branch-accountability-and-race-timeout-diagnosis--2026-10-20)
preserve the underlying roadmap requirements.

Latest cleanup removed 15 local branches whose work is already integrated in
pushed main: one by ancestry, 14 through 20 exact patch matches. Their 15 clean,
unowned worktrees are removed; original cherry-picked histories are retained in a
verified bundle. The superseded original Jovian exit caller is archived under a
pushed tag and its local/remote branch deleted. Full exit still fails cabin walking
in the retained docked-pilot candidate; no failed journey is accepted.

The five local-only exceptions are now accounted for and removed. Cargo capture
and the durable suite launcher are already integrated; the original native and
Sandbox route tooling are superseded by main. The withheld settle-facing guard
remains absent and failed. Exact original histories survive in a verified bundle;
three diagnostic histories also have pushed archive tags. Two clean cache-only
worktrees are removed. Full Sandbox/recovery/reuse remains FAILED/open.
[Five-branch closeout](docs/history/ROADMAP_DELIVERIES.md#five-local-only-branches-accounted-and-closed--2026-10-20).

Of the 17 remaining remote candidates, **three contain ordinary gameplay fixes**
(passenger role display, docked-pilot pose holding, tooltip retirement on close).
Each still lacks its required acceptance. The other 14 contain qualification
or diagnostic automation, including opt-in startup/release wiring. They are not
14 new gameplay implementations. The
[current branch-by-branch status](docs/history/ROADMAP_DELIVERIES.md#remaining-branch-status-after-duplicate-closeouts--2026-10-20)
records the earlier 20 candidates; accepted Breach and Halyard closeouts and the
archived superseded Jovian caller remove three.
This cleanup changes branch ownership, not the number of completed roadmap outcomes.

**Selected physical passenger-exit repair: 15:47–16:32 UTC, 45min.**
Reuse existing docked-pilot branch. Source now proves confirmed nonpilot departure
teleports to generic station spawn; it cannot satisfy the required authored-ground
endpoint. The caller also mistakes post-confirmation exterior animation poses for
pre-Interact walking goals. Correct both ends of this same original journey:
ordinary supported cabin walk and Interact outside the pilot-swap radius, then
confirmed physical exit along the existing authored route while the other pilot
retains helm/ownership/source and landed pose. Preserve the original endpoint,
retirement, identity, ground-walk and actual three-peer exit assertions.

One implementer owns GameFlow/its focused existing seam test; root owns the
original caller. Independent high review before engines. Original300s suite,
360s outer,15s walks,8s boundary/exit and10s peer grace stay fixed. First unexpected
failure stops. Focused lifecycle/pose/seam checks, full original journey once;
paired checkpoint exports and strict silent isolated startup/audit only after
full acceptance. Merge/push/delete and owned cleanup finish the card. Prior
619.927s stages and original parser failures remain; no cost reset.

The first physical-exit candidate 87b313468 stopped before gameplay: import
passed20.654s, then pose-stage loading found two inferred-type errors in new
GameFlow `exit_pose`/`motion_started` declarations. Failed38.440s and all raw
records retained; no journey/export ran. Within the same15:47–16:32 window,
select one exact type-only correction (`Transform3D`, `bool`), independently
review it, then compile before focused suites and the unchanged full journey.
Prior stages now658.367s plus separately retained parser failures. No deadline
extension, criteria change or unchanged rerun. First further failure stops.

**Docked-pilot branch closeout stopped at a later hatch-route boundary.**
Existing branch `fix/docked-pilot-hold-20261020` is pushed on bf7fb636e and remains
unmerged/withheld. Source proved the original diagonal crossed the solid pilot
chair; the reviewed ordinary clearance point now passes, followed by original
route[0]. Full original journey still FAILS in 147.311s at route[1], before hatch
Interact, exterior release or ground walk. No acceptance requirement was removed.

Import, all 322 pose assertions and compile pass. New stages total 227.457s;
prior 392.470s remain, giving 619.927s plus separately retained original parser
failures. No retry or further repair is selected. Source walks route[0..2]
before hatch Interact; the new host stop is consistent with the doorway, but
canopy/hinge/blocker/contact state was not recorded, so causation is unproved.
All 25 observed process identities absent; 188 profile entries archived and
verified. Owned worktree/profile/helpers removed in 6.01min within the selected
45min window. Exports/startups/audit NOT_RUN; playable c78e0ac unchanged.
[Actual result and missing fact](docs/history/ROADMAP_DELIVERIES.md#docked-pilot-closeout--chair-cleared-hatch-route-still-fails--2026-10-20).

**Existing Halyard boarding branch finished and merged on 4bc0e3b38.**
Full original ordinary menus/spawn/continuous walks and real pilot/passenger
boarding pass in 130.472s under unchanged 300s suite/360s outer limits.
Non-playing authority and both original independent clients retain exact peer/
avatar/ownership/body/frame/seat/claim generations, supported controls and honest
PILOT/PASSENGER HUD; all three actual OS processes exit0 and complete the terminal
handshake. Scalar comparison projections now use the same JSON representation;
no runtime/network/placement/deadline/criteria changes. Source and actual-result
review: GO. Moving-cabin/departure/server-stop/native/human remain separate/open.

Existing branch is merged/pushed/deleted. All 21
observed owned identities absent; raw receipts/logs, profiles and helpers preserved;
owned worktree/profile/helpers removed in 8.74min
inside 30min. New stages 166.878s; earlier two failed routes 271.737s remain
recorded separately (old setup time NOT_RECORDED). Current playable checkpoint
c78e0ac and all 11 public artifact hashes remain unchanged; this changes only an
excluded qualification test. No identical rebuild or adjacent case was selected.
[Delivery](docs/history/ROADMAP_DELIVERIES.md#halyard-ordinary-boarding-branch-finished--2026-10-20).

**Existing Breach interruption branch finished and merged.** Full original
BREACH-INTERRUPTION earned-debt release case passes on c78e0ac: genuine unpaid
completion, live owned kill/reap, distinct normal cold Resume/real pilot/exit/
physical board retry, one atomic receipt+acknowledgement, and third cold paid
replay. Both source and exact archive-extracted executable complete all three
processes. Setup/target-damage fixtures remain disclosed; ordinary combat and
active-combat restoration are not qualified by this case.

The old failure sampled shared-store metadata after payment's next tutorial save.
The existing probe captures the actual primary at the board signal, before
tutorial publication, and requires receipt and paid terminal in that same document.
A second proven caller correction serializes only the expected live integer ledger
for comparison with the JSON-decoded ledger; all eight checks remain exact.
All previous assertions and original 1000s/child300s limits remain.
Fresh privacy/compile, paired exports, three strict menu startups and actual
package audit pass. Independent source and final-result review: GO.

Existing `feat/breach-interruption-fixed-boot-20261018` is merged/pushed/deleted;
owned worktree/profile/helpers removed after verified preservation. New stages
352.043s plus retained 249.405s/four failures give 601.447s. Only this
attempt's `results/` remains. Native Windows/GPU/devices/audio/human/final gates
remain NOT_RUN/open and CI disabled.
[Delivery and limits](docs/history/ROADMAP_DELIVERIES.md#breach-interruption-branch-finished--2026-10-20).

**Current UI task stopped: active-tooltip baseline not reproduced.**
Existing candidate `fix/exit-tooltip-order-20261020` remains unmerged/withheld.
Its historical full Observation route passed, but did not create the original
visible TooltipPanel. The new actual-Main fixture opened the real pause controls
and focused Exit; physical hovering did not create the required original embedded
tooltip within 30 seconds. Therefore no original disconnect pair was reproduced,
no production fix was applied, and no second engine attempt is selected.

Missing fact before a further repair attempt: the actual GUI hover owner, native
pointer/window coordinates and visible foreground at the intended Destination
button. Do not infer a cause, synthesize a popup, weaken original acceptance or
replay the full route merely because this setup failed. Require the original
visible tooltip/root bindings before testing normal HUD/WM process close.

Fixture source4b2b301cb is preserved under pushed tag
`archive/diagnostics/tooltip-close-fixture-20261020`. Import passed; baseline stopped
at61.270s with no ACTIVE event or original errors. Original733.226s retained;
new80.920s gives814.146s total stages. Independent review confirms no fix
qualification; all inputs/processes cleaned, ten owned identities absent. Only
`/srv/mudds-work/tooltip-close-20261020/results/` remains for this attempt.

**Existing Perimeter branch finished and merged.** Runtime/admission integration
is shipped in fdae1cb above. The original Breach test remains byte-identical;
its 48 assertions pass in 76.650s and the separate actual-Main Hold case passes 19
assertions under their unchanged 90s limits. Director/asset/board/HUD/staged Hold/
Wing checks, paired exports, three strict menu startups and actual package audit
all pass. Independent source/result review accepted the scoped delivery.

Existing `feat/perimeter-live-20261020` is contained in pushed main; its local,
remote and tracking refs and owned worktree/profile/helpers are removed after
verified preservation. Only this attempt's `results/` remains. New supervised
stages 378.870s plus retained 363.897s give 742.767s; original failed attempts
remain recorded. Full ordinary Hold and parent 11 remain OPEN. Native Windows,
GPU/devices/audio/human/final gates stay NOT_RUN/open; CI stays disabled.
[Delivery and actual limits](docs/history/ROADMAP_DELIVERIES.md#perimeter-live-branch-finished--2026-10-20).

**Ready production cards: 0. Prepared production cards waiting on decisions: 3.**
The decisions below remain pending; they do not prevent finishing independently
supported existing failures. No completed probe schedules an adjacent probe.

### Next three production deliveries

These are existing children, not new task families. Root owns selection and
integration; assign an implementer only when the prerequisite is satisfied.
Freeze exact files, commands/caps and estimates at that point. The checks below
are acceptance intent, not permission to run an unfrozen engine command.

| Existing child / parents | Player result and implementation boundary | Done for this card | Dependency and cost |
| --- | --- | --- | --- |
| [FREIGHT-TERMINAL-INTERFACE /7,9,13](docs/ROADMAP_BACKLOG.md#freight-terminals--physical-interface-and-existing-transfer-owner) | Ordinary E at existing Freight fittings reaches the genuine cargo job/manifests/receipt. Owners: JovianFreightBerth fittings, CargoTransferTerminal and GameFlow cargo composition. | Actual Main interaction, range/re-entry/refusal/current-owner checks; existing conserved stock and once-only settlement preserved; fresh playable checkpoint. This does not close full Freight delivery/reload/walk. | WAITING: physical job/receipt interface with automatic landing transfer, or manual transfer after docking. Estimate after choice; split before 90min. Do not alias a terminal as the ship or mint another stocked manifest. |
| [HAULER-CARGO-MANIFEST /10,13](docs/ROADMAP_BACKLOG.md#hauler-supply-integration-boundaries) | Hauler joins the real supply contract with the correct conserved stock owner. Owner: NearbySectorActivityBinding admission/custody; existing generation-floor API and CargoTransferAuthority retained. | Jovian→Hauler→Jovian current ownership, stale-handle refusal, no recreated stock, exact conserved destination/receipt; fresh playable checkpoint. Full ordinary Hauler delivery stays separate. | WAITING: shared stock, separate stock or loading-terminal custody. Existing estimate 60–90min implementation/checks plus checkpoint; split if the choice adds a separate capability. Access is already delivered. |
| [AUDIO-NAVIGATOR-CLIENT-REJECTION /30](docs/COMPLETION_SCOPE.md#client-navigator-rejection-response--bounded-definition-next) | The actual requesting client gets one accurate refusal cue/caption for its current request. Existing passenger binding, ENet adapter, GameFlow and navigator audio lifetime owners carry the response. | Distinct equal refusals each present once; stale/replayed/foreign responses stay silent; accepted/clear behavior and full existing peer route retained; fresh playable checkpoint. Dummy checks establish dispatch, not listening. | WAITING: all current authenticated refusals including unavailable consumer, or consumer/bridge refusals only. Prior estimate 45–60min implementation/review, 15–25min checks, 10–15min checkpoint. High-risk lifetime/transport review required. |

A card closes on its stated result, then commit/push, record actual time and clean
owned scratch. Its downstream delivery, reload, full branch or final-candidate
qualification becomes a separate selection with the original acceptance retained.
No card expands silently to cover every adjacent defect.

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

## Turning a broad point into one task

Use the existing [child inventory](docs/ROADMAP_BACKLOG.md#concrete-child-outcomes).
Do not create another tracker. A task is executable only when it has:

1. One player/content/build result, its existing child and original parent.
2. Satisfied prerequisites, exact production files and one responsible implementer.
3. A decisive action/check, expected result, exact command and fixed duration.
4. Implementation and check estimates; prefer 30–60min implementation and split
   before 90min into independently useful capabilities.
5. A stop condition and closure: actual result/time, source or package scope,
   commit/push, owned cleanup and one next action.

Label capability, qualification and planning separately. A capability task changes
the game/content/build pipeline; qualification proves an existing result. Do not
close a full craft, world, multiplayer parent or phase using a narrow source check.
No more than three executable cards; prepare dependent work without scheduling it.

A new failure ends the attempt. Any correction needs a separate selection;
failed work plus one attempted repair requires cumulative priority review.
Parked work additionally needs a concrete fact/change addressing its retained
failure. Renaming a card, shrinking acceptance, increasing a cap or selecting an
adjacent probe does not reset that boundary. A pass ends verification unless a
relevant change or unresolved concern justifies another run.

Completing one helm action never schedules the next action, a new fixture or a
handback retry. Before more qualification, choose the larger player journey it
advances and state its remaining blocker. Prefer an independently useful production
capability when one is ready; if none is ready, name its actual missing dependency.
Do not fill the implementation queue with tests or invent unapproved behavior.

## Accepted work — source limits retained

The backlog preserves accepted child scopes and remaining gates. The existing
[delivery history](docs/history/ROADMAP_DELIVERIES.md) preserves sources, actual
results, timings and cleanup. Recent palette, controls, station service, recovery,
Arrow and helm work remains accepted only within those recorded boundaries.
Caller-only qualification needs no identical playable rebuild. Checkpoint c78e0ac
remains the latest accepted playable result; full craft combat/damage/recovery,
cross-craft/Main, hardware/native and final release gates remain open.

## Parked failures and dependent work

These are unfinished outcomes, not candidates for an unchanged retry. Exact
contracts and cumulative attempt records remain in the retained history.

| Outcome | Last actual result | Condition before more work |
| --- | --- | --- |
| PLAY-DEFENSE ordinary route /13 | Candidatea480c0fbb pushed/unmerged: actual E Deploy accepted, but corrective walk_arrow stationary33.15s and whole34s timeout before boarding. | PARK after original35.963s and one corrective84.239s failure; cumulative406.401s including16 passing stages. No player kill/payment/home/reset/UIexit; no second repair/retry selected. Unique candidates/results preserved; owned scratch cleaned28.24min. |
| Ember first-relay cold cut /14,31 | [Archive923d7b3](docs/history/ROADMAP_DELIVERIES.md#ember-first-relay-cold-cut--runtime-completes-parent-comparison-fails) FAIL312.812s at parent exact durable-state comparison; arm-9/resume0, engine diagnostics0, runtime continuation and receipts0→1. Only two compared coordinate scalars differ by one binary64 ULP. | STOPPED; no repair/retry/cap increase or retroactive comparison relaxation. Contract review and exact-runtime caller correction complete; corrected full package run NOT_RUN and requires a separately frozen selection. No full-cut/location/canonical/installed acceptance; all owned scratch cleaned9.50min within20min. |
| Jovian postdock exit /16,20,26 | [Candidate bf7fb636e](docs/history/ROADMAP_DELIVERIES.md#docked-pilot-closeout--chair-cleared-hatch-route-still-fails--2026-10-20): pose322/import/compile PASS; reviewed chair-clearance and original route[0] pass. Full original route147.311s FAIL at route[1] before hatch Interact. Unmerged/withheld; exports NOT_RUN. | STOPPED after one separately selected source-supported caller correction. Combined619.927s current stages plus original parser failures retained. Missing actual canopy/hinge/blocker/contact state at doorway; no second correction, cap/tolerance increase or adjacent probe selected. All25 identities absent;188 profile entries verified; owned scratch cleaned6.01min within45min. |
| Habitat common-entry view /9,12 | [Source8a6339b91](docs/history/ROADMAP_DELIVERIES.md#habitat-arrival-view--readback-timed-out-before-image): import passes; full-Main player-height readback times out180.842s before PNG or view metadata. Cumulative201.494s; no observed defect/no-finding. | PARKED. Concrete supported capture-boundary change before selection; no renderer/room substitute, cap increase or unchanged retry. Actual eye stage was not proved reached; accepted Habitat runtime scopes remain. |
| Courier clear /11 | [Candidatecb9d76fa5](docs/history/ROADMAP_DELIVERIES.md#courier-ordinary-clear--escaped-without-player-damage), pushed/unmerged: prechecks pass; ordinary attempt fails70.377s, ESCAPED at1400m, hull78/78, no player hit/kill or home completion. Cumulative165.917s. | PARKED/withheld. Fresh Courier-window emission/ray/resolver facts are missing; generic shot receipt can be stale. No weapon/aim cause established, repair/retry or public checkpoint selected. Preserve original route/caps; other Courier outcomes need separate selection. |
| Matching RPC-cache templates /25,32 | [Linux built; Windows cold/incremental compilation timed out](docs/history/ROADMAP_DELIVERIES.md#matching-rpc-cache-templates--stopped-at-windows-compilation-budget). No accepted matching pair; callback repair is unverified. | PARKED; no further compilation or dependent browser attempt selected. Existing recipe/JSON fixture remain delivered; empty callable metadata and similar Window errors establish no cause. |
| BROWSER-ORDINARY /25 | Candidatee944f52:89Python/privacy/35join/package checks pass, actual routeFAIL40.554s at NetworkSession tree_exited disconnect error; cleanup fixture command rejected. | PARKED/unmerged/withheld. Subsequent passive capture identifies retained native RPC-cache callback; it does not qualify the route. Full continuation NOT_RUN. Original raw data/eight builds preserved; scratch cleaned. |
| AFT-CONSOLE-VIEW /9,12 | Standalone actual-module Xvfb/Forward+/llvmpipe capture FAIL120.485s after camera setup; no image or visual finding. | PARKED; source/root cause unproven. No cap increase, alternate backend/view or retry selected. Owned scratch cleaned; raw results retained. |
| WALK-OBSERVATION /7,9 | Two caller failures retained; numeric e390/unchanged game4c58 completes54-goal travel/view/home prefix then FAIL89.064s on rootWindow signal disconnections after focused Exit. | PARKED; full task remains unaccepted, no clean exit0. Capture identifies the Tooltip with stored pairs still present across errors. Laterbae551d58 private route PASS, but no visible tooltip/retirement, so repair acceptance INCONCLUSIVE and candidate withheld. No second attempt selected. |
| PERIMETER-LIVE /11 | Runtime/admission shipped fdae1cb: all selected focused/production checks, paired exports, three strict startups and package audit PASS. Existing branch merged/pushed/deleted and owned scratch cleaned. | Scoped integration DONE; full ordinary weapons/home/recovery/repeats/network/native remains OPEN. Prior 363.897s/three failures retained; total stages 742.767s. |
| PLAY-BEACON-HOME /13 | Candidatea612ea686 FAIL37.713s guarded/37.419s driver at ActivityBoardButton Return/frame1233; same two root Window signal-disconnection diagnostics. Eleven prechecks pass; no settlement/home/L/E reached, no file captures. Unmerged/withheld. | PARKED on UI-BOARD-FOCUS. Recurrence supplies no popup/connection-removal cause; no retry/repair/cap change. Preserve original UI two-component9.627s and Mining budgets. |
| HALYARD-GUNNER-DAMAGE /11,16 | Original 51.847s and one caller repair 52.025s both fail co-pilot admission; actual new damage proof NOT_RUN. | Parked after cumulative 103.872s review. No further diagnosis/fix/run without concrete reopening fact/change; candidates unmerged, no weapon defect established. |
| HELM-YAW-HANDBACK / 18,20 | Original146.578s failure; one repair reaches cabin walking then FAIL156.016s at >=0.6m/15s. | Recorded cumulative priority review parked it. Explicit selection required before further diagnosis/fix/run; no movement cause established. |
| CABIN-PASSENGER-ROLE / 18,20 | Candidate38c079086 HUD36 and actual handback PASSENGER pass, full required route fails walking. Unmerged/withheld; no package. | Preserve full route; no acceptance narrowing or automatic second repair. |
| WALK-SALVAGE-ACCESS / 7,9 | Original61.019s plus one repair60.822s both fail outbound20; same supported Player, inspection/return NOT_RUN. | Parked after cumulative review; no further diagnosis/fix/run. INSPECT/REVISIT remain gated; concrete new fact/change required to reopen. |
| KIT-RELOAD / 13,31 | Distinct-process restore30s timeout; one boundary probe records Main ready but no returned first normal frame before deadline. | Different supported production repair must be selected; no unchanged probe, timeout increase or repeated startup profile. |
| HALYARD-MOVING-CABIN / 16,26 | NOT_RUN; exact retained card requires supported walk/sit/stand/reseat during departure. | BOARD prerequisite accepted; separately freeze original moving case before engines. No moving/departure acceptance follows from boarding. |
| HALYARD-AUTHORITY-STOP / 16,26 | NOT_RUN; exact retained card requires usable solo controls after actual server stop. | GATED on accepted moving-cabin route. |

VIP, Ember native close smoke, Rime arrival, HULK revisit, Fire restart, Sandbox,
Convoy/Patrol/Q4/Q5 and software-renderer capture stalls retain their existing
failure budgets and reopen conditions in the backlog/history. Settings originals,
Aurora original arrival bundle, final capacity, hardware/devices and signing retain
specific external waits. Do not repeat already-asked questions or infer approval.
Dedicated server/two-client baseline remains authorized independently of capacity.

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
