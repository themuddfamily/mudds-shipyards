# Development roadmap

**Playable development alpha; a completion date is not yet defensible.**
All **36 original parent outcomes** and **ten phase gates** remain open.
Nine of the eventual 17 craft exist; eight still need supported specifications
and implementation. Partial acceptance is retained in the backlog; it is not
whole-feature completion.

Latest playable checkpoint: **0070248**. After ordinarily giving up the Jovian
helm for a walking cabin berth, the HUD shows PASSENGER for the craft aboard.
The full boarding/departure/both-yaw/handback/backward-walk journey passes with
retired helm authority, supported movement and the original co-pilot retained.
All three actual peers exit0 with clean logs. Previous physical postdock exit
and dock-pose holding capabilities remain included.
[Windows ZIP](builds/windows/MuddsShipyards-0070248-checkpoint.zip),
[Windows notes](builds/windows/MuddsShipyards-0070248-notes.txt),
[Linux notes](builds/linux/MuddsShipyards-0070248-linux-notes.txt).

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

**Existing working-branch backlog cleared; unfinished product outcomes remain open.**

Resolve one existing branch at a time. Before selecting another, either merge and
push accepted work and delete the branch, or preserve its unique source/results
and record the exact unmet requirement and blocker. A failed check does not
automatically authorize an adjacent task or retry.

**184 local and 110 live remote branches deleted; main is the sole local and
live remote branch (zero non-main branches).** Counts describe refs,
not completed features. [Branch accounting and closeouts](docs/history/ROADMAP_DELIVERIES.md#branch-accountability-and-race-timeout-diagnosis--2026-10-20)
preserve the underlying roadmap requirements.

Earlier duplicate cleanup removed 15 local branches already integrated in pushed
main: one by ancestry, 14 through 20 exact patch matches. Their 15 clean,
unowned worktrees are removed; original cherry-picked histories are retained in a
verified bundle. The superseded original Jovian exit caller is archived under a
pushed tag and its local/remote branch deleted. Its retained docked-pilot
successor is now accepted and closed below.

The five local-only exceptions are now accounted for and removed. Cargo capture
and the durable suite launcher are already integrated; the original native and
Sandbox route tooling are superseded by main. The withheld settle-facing guard
remains absent and failed. Exact original histories survive in a verified bundle;
three diagnostic histories also have pushed archive tags. Two clean cache-only
worktrees are removed. Full Sandbox/recovery/reuse remains FAILED/open.
[Five-branch closeout](docs/history/ROADMAP_DELIVERIES.md#five-local-only-branches-accounted-and-closed--2026-10-20).

All 20 candidates in the [earlier inventory](docs/history/ROADMAP_DELIVERIES.md#remaining-branch-status-after-duplicate-closeouts--2026-10-20)
are now accounted for: six references closed through accepted/superseded work,
and fourteen unqualified candidates preserved under explicit WITHHELD tags.
This clears the branch queue; it does not close their unfinished gameplay,
qualification or release requirements. No unaccepted source was merged to reduce
a branch count. Eight previously protected detached worktrees remain unchanged.

**Selected HALYARD-MOVING-CABIN /16,24,26 — one complete ordinary case.**
BOARD prerequisite is accepted on4bc0e3b38 and its caller remains unchanged.
Implement the missing moving selector in existing
`tests/network/halyard_network_passenger_route_test.gd`: original non-playing
Main authority, independent client pilot and client_b passenger at crew_port_00.
After existing ordinary approach/boarding and exact consumed seat confirmations,
same pilot departs >5m; same supported passenger walks >0.6m, sits, stands and
reseats while the hull genuinely moves. Preserve actual host/peer current body,
frame, role and legitimate generation transitions. No staged flight/transform,
body/authority injection, walk-only substitute or altered BOARD result.
One implementer owns that caller; root owns review/integration, existing isolated
process supervision, result and cleanup. No new branch or adjacent assignment.
Original45–60min assignment; compile300s, one full internal300s/outer360s route,
walk15s, role/consumed transitions8s and exit grace10s. Exact selected flag:
`--ordinary-two-client-moving`; marker `HALYARD_ORDINARY_TWO_CLIENT_MOVING_OK`.
Compile command: Godot --headless --audio-driver Dummy --path this clean source
--check-only --script res://tests/network/halyard_network_passenger_route_test.gd.
Full command: same headless/Dummy source script, without --check-only, followed
by -- --ordinary-two-client-moving; peers retain private Xvfb/explicit x11/Dummy.
Freeze implemented source and exact command/PIDs/cache before launch; all three
actual peer OS exits0, explicit complete, zero diagnostics and owned cleanup
required. First failure stops; no automatic repair/cap increase. Commit/push,
record actual full outcome and remove owned profiles/helpers before closure.
This is current-source qualification capability, not new gameplay, endurance,
authority-stop, late join, planetary travel or full server-baseline acceptance.

**Ember first-relay cold recovery DONE on package `923d7b3`.**
The full named check passes: save the unpaid first relay, kill and reap the game,
restart through Boot into the safe yard with exact progress retained, board
again, complete the original survey and receive exactly one durable reward.
Actual process exits are -9 and 0, logs are clean, and source/cache stay unchanged.
The original archive and external metadata were verified before staging; no game
or comparison change. Caller `6112944d0` qualifies the immutable `923d7b326`
package with the original 300-second process and 660-second overall limits.
Earlier failures remain recorded. Independent review passed; temporary staging
and profiles are removed, and all five observed process identities are absent.
Cleanup took 7.72 minutes within the selected 15-minute window. Main remains the
sole working branch; latest playable build `0070248` is unchanged.
Canonical outbound, normal controls and native GPU remain NOT_RUN; standing-pose
restoration remains NOT_SUPPORTED. Other world/recovery requirements stay open.
[Full result, timing and retained scope](docs/history/ROADMAP_DELIVERIES.md#ember-first-relay-cold-recovery--exact-package-accepted--2026-10-20).

**Remaining ten working branches accounted for and deleted.**
Browser-cache diagnostic and network-timeout acceptance preparation, Courier,
Defense, Halyard damage, Salvage access, Jovian reload, Fire restart, HULK revisit
and Rime crew arrival have verified source bundles, binary patches and exact
source archives, with pushed `archive/withheld/<original-branch-leaf>` tags.
All 19 unique commits/32 source-file entries are preserved; current live tips,
remote tag objects/peeled tips and registered ownership were checked before
expected-OID branch deletion. Main is the sole local/remote working branch.
Original failures, budgets and concrete missing facts remain in the parked
outcomes/backlog. Accepted fixture, physical E Deploy and other partial scopes
remain distinct. No engines, compile, route retry, new branch, gameplay acceptance
or checkpoint. Closed at 17:31 UTC inside the selected 17:28–17:48 accounting window.
[Exact source identities and ten retained gaps](docs/history/ROADMAP_DELIVERIES.md#remaining-ten-working-branches-accounted--2026-10-20).

**UI, Mining and Beacon-home working branches accounted for and deleted.**
Seven unique commits across the three branches survive in independently verified
Git bundles, binary patches, exact source archives and pushed WITHHELD tags:
`archive/withheld/ui-board-focus-20261018`,
`archive/withheld/mining-first-play-20261018` and
`archive/withheld/beacon-home-20261020`. No unqualified source was merged.
The UI branch contains diagnostic instrumentation; Mining and Beacon-home contain
opt-in qualification tooling whose original journeys failed at the Activity Board.
UI component9.627798881s, Mining61.9252887s failed cumulative and Beacon37.713s
actual route retain their original budgets and full acceptance contracts.
Original Main popup identity/root recipients and the prior connection-removal
cause remain unknown. UI remains PARKED/OPEN; Mining six-second extraction,
persisted capacity receipt and home return, and Beacon home/dock/shutdown/usable
exit remain unaccepted. Accepted Beacon traversal/settlement remains in main.
No engines, gameplay changes or new checkpoint; playable0070248 unchanged.
The group closed at17:26 UTC within its selected17:21–17:41 accounting window.
[Source preservation and remaining gaps](docs/history/ROADMAP_DELIVERIES.md#ui-mining-and-beacon-working-branches-accounted--2026-10-20).

**Tooltip candidate accounted for as WITHHELD; working branch deleted.**
All five unique commits/seven exact source files survive in verified bundle,
binary patch, source archive and pushed tag
`archive/withheld/exit-tooltip-order-20261020`. Its10-line close-time GUI-input
change is unmerged and unqualified. The private Observation route passed, but
never exercised the original visible embedded TooltipPanel; later baseline also
failed to produce it. Original814.146s checks remain preserved. No new engine,
implementation, acceptance or checkpoint; playable0070248 unchanged.
Local/remote/tracking branch removed after archive/tag/live-tip/ownership checks.
WALK-OBSERVATION and the actual tooltip-close regression remain OPEN. Before any
further repair attempt, observe the real visible tooltip/root bindings and
actual hover owner/pointer/window/foreground state; retain original normal-close
and complete travel/view/home acceptance. Historical source must be adapted to
current owners rather than overwriting newer observer/driver/startup work.
[Withheld archive and unmet requirement](docs/history/ROADMAP_DELIVERIES.md#tooltip-candidate-accounted-and-archived--unqualified--2026-10-20).

**Passenger-role fix and full yaw/handback accepted; both related branches closed.**
Source007024839 merged and pushed in main2f75e834b. Confirmed standing passenger
HUD uses the current cabin claim/craft, preserving pilot/crew precedence and
all ownership. Full136.675s ordinary three-peer route PASS clean: both yaw turns,
normal helm Interact, owner0/generation+1, source/capture retirement, same supported
former pilot, honest PASSENGER HUD and original seated co-pilot. Ordinary lateral
chair clearance then the original backward walk satisfy every original>=0.6m
localhost gate plus additional backward projection after clearance. Walk completes
1.617s within the same15s deadline; all three actual OS exits0. Paired exports,
three strict startups and actual1525-entry package audit PASS; checkpoint0070248.
All65 final process identities absent;280 profile entries verified; owned scratch
removed20.68min within original45min. The role branch is deleted local/remote/
tracking. Its older handback precursor is also deleted after exact patch/blob
matches to accepted9d2173e85, with original history/source in a verified bundle
and two-file archive. Failed first controller attempt remains preserved; total
known stages933.225s includes all original423.260s and failed204.498s, no reset.
Other action-specific handback, physical devices, native/endurance/final gates
and postdock reboard/pilot exit/reclaim/redeparture remain open.
[Acceptance and both branch closeouts](docs/history/ROADMAP_DELIVERIES.md#passenger-hud-and-yaw-handback-accepted-both-branches-closed--2026-10-20).

**Jovian passenger exit accepted; existing branch merged and deleted.**
Source861c4d39b is integrated in pushed main2352d18c3. Original ordinary host/two-
client journey138.470s PASS: deliberate exit E, all seven physical route poses,
same supported player/ground walk, passenger claim/body retirement, retained
pilot and all three actual OS exits0; zero diagnostics. Focused station targeting,
pose and support checks pass. Paired exports, strict three-startup checks and
actual1525-entry payload audit pass; checkpoint861c4d3 published in builds/.
All65 final-run process identities absent;267 profile entries verified; owned
worktree/profile/helpers removed23.65min within original45min. Local/remote/
tracking branch deleted after exact-tip/ownership/pushed-main checks.
Failed fixture and receipt-diagnostic attempts remain preserved in history;
combined current stages1860.013s plus original parser failures are accounted.
Postdock reboard, pilot exit/reclaim/redeparture, other craft and second landing
remain open; no broad parent/phase or native/human gate closes.
[Accepted result and closeout](docs/history/ROADMAP_DELIVERIES.md#physical-jovian-passenger-exit-accepted-and-branch-closed--2026-10-20).

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

**Active-tooltip baseline remains unproved.**
The original candidate is now archived WITHHELD, with its working refs removed.
Its historical private Observation route passed without the original visible
TooltipPanel. The later actual-Main fixture opened real pause controls and focused
Exit, but physical hovering produced no required original tooltip within30s.
No original disconnect pair was reproduced or fix applied by that setup.

Missing fact before a future repair: actual GUI hover owner, native pointer/window
coordinates and visible foreground at Destination, plus original visible tooltip/
root bindings. No popup synthesis, acceptance relaxation or unchanged retry is
selected. The actual lifecycle must be exercised before normal HUD/WM close proof.

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
Caller-only qualification needs no identical playable rebuild. Checkpoint0070248
is the latest accepted playable result; full craft combat/damage/recovery,
cross-craft/Main, hardware/native and final release gates remain open.

## Parked failures and dependent work

These are unfinished outcomes, not candidates for an unchanged retry. Exact
contracts and cumulative attempt records remain in the retained history.

| Outcome | Last actual result | Condition before more work |
| --- | --- | --- |
| PLAY-DEFENSE ordinary route /13 | Candidatea480c0fbb archived WITHHELD; working refs deleted, source unmerged: actual E Deploy accepted, but corrective walk_arrow stationary33.15s and whole34s timeout before boarding. | PARK after original35.963s and one corrective84.239s failure; cumulative406.401s including16 passing stages. No player kill/payment/home/reset/UIexit; no second repair/retry selected. Unique candidates/results preserved; owned scratch cleaned28.24min. |
| Jovian postdock reuse /16,20,26 | DONE on861c4d39b, merged2352d18c3; original138.470s clean three-peer journey, all seven physical exit poses, same-player supported ground walk, retired passenger claim/body and retained pilot; all3 actual OS exits0. Fresh paired checkpoint861c4d3. | Branch local/remote/tracking deleted, owned scratch cleaned23.65min/45min. Reboard/pilot exit/reclaim/redeparture/other craft/second landing remain open; no automatic next case. |
| Habitat common-entry view /9,12 | [Source8a6339b91](docs/history/ROADMAP_DELIVERIES.md#habitat-arrival-view--readback-timed-out-before-image): import passes; full-Main player-height readback times out180.842s before PNG or view metadata. Cumulative201.494s; no observed defect/no-finding. | PARKED. Concrete supported capture-boundary change before selection; no renderer/room substitute, cap increase or unchanged retry. Actual eye stage was not proved reached; accepted Habitat runtime scopes remain. |
| Courier clear /11 | [Candidatecb9d76fa5](docs/history/ROADMAP_DELIVERIES.md#courier-ordinary-clear--escaped-without-player-damage), archived WITHHELD, working refs deleted/source unmerged: prechecks pass; ordinary attempt fails70.377s, ESCAPED at1400m, hull78/78, no player hit/kill or home completion. Cumulative165.917s. | PARKED/withheld. Fresh Courier-window emission/ray/resolver facts are missing; generic shot receipt can be stale. No weapon/aim cause established, repair/retry or public checkpoint selected. Preserve original route/caps; other Courier outcomes need separate selection. |
| Matching RPC-cache templates /25,32 | [Linux built; Windows cold/incremental compilation timed out](docs/history/ROADMAP_DELIVERIES.md#matching-rpc-cache-templates--stopped-at-windows-compilation-budget). No accepted matching pair; callback repair is unverified. Browser diagnostic/prepared acceptance source archived WITHHELD; working refs deleted. | PARKED; no further compilation or dependent browser attempt selected. Existing recipe/JSON fixture remain delivered; empty callable metadata and similar Window errors establish no cause. |
| BROWSER-ORDINARY /25 | Candidatee944f52:89Python/privacy/35join/package checks pass, actual routeFAIL40.554s at NetworkSession tree_exited disconnect error; cleanup fixture command rejected. | PARKED/unmerged/withheld; diagnostic and prepared acceptance refs deleted after source archival. Subsequent passive capture identifies retained native RPC-cache callback; it does not qualify the route. Full continuation NOT_RUN. Original raw data/eight builds preserved; scratch cleaned. |
| AFT-CONSOLE-VIEW /9,12 | Standalone actual-module Xvfb/Forward+/llvmpipe capture FAIL120.485s after camera setup; no image or visual finding. | PARKED; source/root cause unproven. No cap increase, alternate backend/view or retry selected. Owned scratch cleaned; raw results retained. |
| WALK-OBSERVATION /7,9 | Original full route fails rootWindow disconnect after Exit. Privatebae551d58 later passes54-goal travel/view/home/Exit, but lacks original visible TooltipPanel; repair INCONCLUSIVE. All five unique commits/seven files archived under pushed archive/withheld/exit-tooltip-order-20261020; working refs deleted, runtime unmerged. | OPEN. Observe actual original visible tooltip/root bindings and hover owner/pointer/window/foreground state before separately selected normal-close repair proof; full integrated travel/view/home acceptance retained. No new run or unchanged retry. |
| PERIMETER-LIVE /11 | Runtime/admission shipped fdae1cb: all selected focused/production checks, paired exports, three strict startups and package audit PASS. Existing branch merged/pushed/deleted and owned scratch cleaned. | Scoped integration DONE; full ordinary weapons/home/recovery/repeats/network/native remains OPEN. Prior 363.897s/three failures retained; total stages 742.767s. |
| PLAY-BEACON-HOME /13 | Candidatea612ea686 FAIL37.713s guarded/37.419s driver at ActivityBoardButton Return/frame1233; same two root Window signal-disconnection diagnostics. Eleven prechecks pass; no settlement/home/L/E reached, no file captures. Unmerged/withheld source archived under `archive/withheld/beacon-home-20261020`; working branch deleted. | PARKED on UI-BOARD-FOCUS. Recurrence supplies no popup/connection-removal cause; no retry/repair/cap change. Preserve original UI two-component9.627s and Mining budgets. |
| HALYARD-GUNNER-DAMAGE /11,16 | Original 51.847s and one caller repair 52.025s both fail co-pilot admission; actual new damage proof NOT_RUN. Source archived WITHHELD; working refs deleted. | Parked after cumulative 103.872s review. No further diagnosis/fix/run without concrete reopening fact/change; candidates unmerged, no weapon defect established. |
| WALK-SALVAGE-ACCESS / 7,9 | Original61.019s plus one repair60.822s both fail outbound20; same supported Player, inspection/return NOT_RUN. Source archived WITHHELD; working refs deleted. | Parked after cumulative review; no further diagnosis/fix/run. INSPECT/REVISIT remain gated; concrete new fact/change required to reopen. |
| KIT-RELOAD / 13,31 | Distinct-process restore30s timeout; one boundary probe records Main ready but no returned first normal frame before deadline. Source archived WITHHELD; working refs deleted. | Different supported production repair must be selected; no unchanged probe, timeout increase or repeated startup profile. |
| FIRE-RESTART /8,29,31 | Original and viewport caller repair fail visible Fire row intersection before capture/save/restart sampler; no persisted remap proof. Source archived WITHHELD; working refs deleted. | OPEN/PARKED; concrete visible-row cause/change needed before separately frozen original writer/reader acceptance; original300s per process retained. No inferred scrolling cause or retry. |
| HULK-REVISIT /13,31 | Original departure check fails; sole repair reaches reload/dock/shutdown/exit then original300s deadline during new interior walk, before breaker event/receipt. Source archived WITHHELD; working refs deleted. | OPEN/PARKED; establish a concrete production cause/change, retain full physical revisit and once-only cell/reward contract. No cap increase or unchanged retry. |
| SHARED-RIME-BASELINE /3,27 | Original parse failure and typed caller repair retained; repair reaches approach but fails original120s physical landing gate. Survey/home not accepted. Source archived WITHHELD; working refs deleted. | OPEN/PARKED; landing cause unestablished. Preserve full two-crew outbound/survey/reward/save/home and original limits; no automatic rerun. |
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
