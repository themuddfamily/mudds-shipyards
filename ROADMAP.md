# Development roadmap

**Status: playable development alpha; project completion is unproven.** Latest
accepted checkpoint: **20e90c9**, showing connection progress, timeout guidance
and permitted retry inline in the title/pause server browser.
[Windows notes](builds/windows/MuddsShipyards-20e90c9-notes.txt) and
[Linux notes](builds/linux/MuddsShipyards-20e90c9-linux-notes.txt) state checks and
limits. Paused LAN discovery remains accepted on042c701. Beacon departure/traversal/once-only saved reward qualification on
e06550e is retained in its recorded scope. Beacon home/dock/exit, Perimeter Hold,
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

AUDIO-NAVIGATOR-CLIENT-RECEIPTS and the demonstrated CREW-EPOCH correction are
accepted on **4bbb341**, merged/pushed and packaged. Original two-peer navigator
route passes204 checks: client first/stand/reseat/revocation/replay, migrated fresh
acceptance and exact disconnect retirement. Actual document/command/client epoch2
agree. Client rejection remains separate unfinished behavior. [Full result and
prior failures](docs/history/ROADMAP_DELIVERIES.md#audio-navigator-client-feedback-and-crew-epoch--delivered).
Owned worktree/profiles/helpers cleaned; all raw results preserved.

The activity first-play breakdown now names actual entry, physical activity,
settlement and home-continuation checkpoints for all twelve activities, with
production owners, existing test seams and retained blockers in the
[bounded handoffs](docs/ROADMAP_BACKLOG.md#activity-first-play--bounded-handoffs).
The six combat rows also distinguish ordinary clear/return from separate
failure/recovery cases and the now-defined missing Perimeter Hold integration.
The breakdown itself is planning progress. Beacon traversal/settlement is qualified below;
no complete additional activity or combat journey is accepted.

| Remaining work | Readiness | Next bounded action / estimate |
| --- | --- | --- |
| AUDIO-NAVIGATOR-CLIENT-REJECTION | Definition DONE; implementation WAITING on one behavior choice | Finite refusal map and exact requester correlation/owners/proof defined. Asked once: all fresh current refusals including unavailable consumer, or consumer/bridge only. No answer inferred; no runtime/protocol selected. [Definition and conditional proof](docs/COMPLETION_SCOPE.md#client-navigator-rejection-response--bounded-definition-next). After choice45–60min implementation/review,15–25min checks,10–15min checkpoint. |
| HAULER-CARGO-MANIFEST | Production gap; GATED on HAULER-CARGO-STOCK | Binding still rejects Hauler; generation-floor API already exists. [Stock prerequisite and conserved-source proof](docs/ROADMAP_BACKLOG.md#hauler-supply-integration-boundaries).60–90min implementation/focused checks after decision, checkpoint additional; split before90min. |

BROWSER-JOIN-DEADLINE is delivered on**1c679a4**, merged/pushed and packaged:
automatic paused5s expiry, synchronous cleanup, cancellation/replacement safety,
actual retry admission and admitted-session survival pass the focused checks.
The full ordinary Main/browser requirement remains open.

PERF-DORMANT-MEASURE concludes **do not prioritize this optimization**: actual
six-actor direct-function cost89.824us combined is below the frozen100us threshold.
No runtime change, performance fix, native FPS claim or new checkpoint.
[Fixture/result/limits](docs/history/ROADMAP_DELIVERIES.md#dormant-opponent-presentation--cost-decision).
Owned scratch cleaned; only raw results remain. STATION-AFT-CONSOLE-VIEW is
**PARKED**: import passes, isolated120s Forward+ capture times out after camera
setup with no PNG/finding. Source mapping first corrected the upstairs nomination:
consoles are on the lower floor. No graphics repair, alternate capture or retry.
[Original contract/result](docs/history/ROADMAP_DELIVERIES.md#aft-console-arrival--component-review-failed).
Threading driver readiness is now defined, **execution GATED on UI-BOARD-FOCUS**:
it would cross the retained failed Activity Board transition. Full five-gate,
durable reward and landing-unlocked home/usable exit requirements remain intact.
[Owners/full contract/readiness](docs/ROADMAP_BACKLOG.md#threading-complete-first-play--driver-readiness).
No engine or renamed Threading retry selected. The independent ordinary browser
non-admission attempt is now parked below; no full route acceptance was gained.

BROWSER-INLINE-RECOVERY is delivered on **20e90c9**, merged/pushed and packaged:
accepted progress/timeout feedback and permitted Retry are reachable inline,
with Cancel/Disconnect priority and validation fencing preserved.
[Actual checks and original corrections](docs/history/ROADMAP_DELIVERIES.md#browser-inline-session-recovery--delivered).
The full OS-input browser route remains separate; no Activity Board/Aft retry.
BROWSER-DRIVER/BROWSER-ORDINARY candidate **e944f52a8** is now **PARKED/unaccepted**:
source pushed, unmerged/withheld. Readiness checks and packaging pass; ONE actual
ordinary route fails40.554s at automatic timeout with a NetworkSession tree_exited
nonexistent-disconnect/empty-callable diagnostic. Underlying cause unknown;
fixture cleanup separately rejects its command. Retry/admission/Disconnect/fresh
Cancel/Resume/normal quit NOT_RUN. No further exception/repair/probe/retry selected.
[Full frozen cards, failures and retained builds](docs/history/ROADMAP_DELIVERIES.md#browser-ordinary-timeout-and-retry--failed-and-parked).
Owned scratch cleaned after preserving raw results/eight unique withheld builds.
The single source API-ownership observation is **NOT_REPRODUCED**: default and
custom APIs both cleanly remove the actual bound SceneCacheInterface callback at
5004/5002ms automatic timeout. No app-ownership change or release cause/fix is
supported. [Exact result and retained source lead](docs/ROADMAP_BACKLOG.md#timeout-rpc-cache-ownership--net-timeout-teardown-owner).
Owned scratch cleaned. One passive release callback capture is now explicitly
selected after independent contract review; only the existing observer changes.
[Exact scope, original failure budget and stopping conditions](docs/ROADMAP_BACKLOG.md#release-timeout-callback-capture--bounded-definition-and-selection).
Underlying ordinary-route acceptance stays parked; no runtime fix, extra capture,
repair, cap increase or no-answer case is selected.

Perimeter Hold's implementation candidate **aa88b5a73** is **PARKED/unmerged**.
Its staged live runtime passes52 assertions; existing director/asset/board/HUD
checks pass. The unchanged90s GameFlow route times out during existing
Breach/Torpedo recovery before Hold entry. No export/checkpoint was produced.
Cumulative363.897s across15 engine stages; source pushed, all processes gone.
[Original acceptance, failures and retained source](docs/history/ROADMAP_DELIVERIES.md#perimeter-hold-live-integration--implemented-but-parked).
No further correction, retry, cap increase or automatic successor selected.

Latest home attempt **a612ea686** is unmerged/withheld: the full-Main route
hit the known Activity Board focus-disconnection pair before Beacon SELECT/START
(37.713s guarded). The page actually opened; popup identity/connection-removal
cause remains unknown. No repair/retry selected. [Failure and preserved contract](docs/history/ROADMAP_DELIVERIES.md#beacon-complete-home--failed-and-parked).
Beacon traversal/settlement qualification remains on **e06550e**; latest checkpoint
**20e90c9** adds inline browser recovery after deadline1c679a4 and discovery042c701. Owned worktree/profiles/helpers
cleaned after preserving raw evidence and all8 unique withheld build files.

All28 actual listening cases remain NOT_RUN. Hauler's already-asked stock/custody
choice is unchanged. This queue is not a project estimate; the completed rejection definition
is not a delivered feature.

## Turning the remaining scope into executable work

A broad parent stays open until all its original requirements are accepted; this
can coexist with many completed children. Use the backlog as the scope inventory,
then promote a child only when its result, prerequisites, file owner, proof,
estimate and stop condition are explicit, as above. **READY, WAITING and PARKED
must never appear as interchangeable “tasks left.”**

For each missing craft, SPEC must first settle the evidence/interpretation and
required capabilities. BUILD-SPLIT then names the actual hull/access, handling,
role/weapon and recovery deliveries with individual owners and proofs before
implementation. These are a checklist for decomposition, not an invented fixed
number of tasks per ship. CRAFT-ACCEPT retains the original complete craft journey.
An unresolved SPEC remains WAITING; a template or a source audit does not deliver
that ship. The already-asked Titan decision remains pending.

The2026-10-20 bounded readiness pass found no additional implementation-ready
card among navigator rejection, Hauler cargo integration and Station Defense
active-run recovery: the first two retain their already-asked policy waits;
the third still lacks its intended active-wave continuation contract. Do not
count these as executable jobs or begin another terminal-debt implementation.
The browser driver and full packaged route were then frozen as separate cards;
both remain unaccepted after the actual timeout diagnostic above. Preserve their
whole timeout→retry/admission→disconnect→fresh cancel→resume/quit contract.
The one API-ownership observation did not reproduce the release error. A release-
level capture contract is the next missing definition. No unchanged source probe,
route retry or release estimate follows from the component/readiness passes.


At each delivery, update that child’s result and remaining dependency, give actual
elapsed time against the estimate, and nominate one next action. Keep at most
three executable cards. Broader estimation becomes possible as unknown build
scope and policy choices are resolved; this planning update does not establish
a total job count or release date.

## Latest delivered result

**Inline browser recovery delivered on20e90c9.** The title/pause browser now shows
current connection progress and timeout guidance and offers permitted Retry.
Cancel/Disconnect retain priority; rejected receipts preserve newer validation.

Five focused suites pass182 assertions; clean Windows/Linux exports, three strict
silent startups and actual1521-entry package parity pass. Independent high review
and root final review: GO. All12 final stages pass. Cumulative17 stages/193.759s
retain the original Cancel-priority failure and explicit corrections. All17 owners
FINISHED/all78 observed process identities absent.
[Windows ZIP](builds/windows/MuddsShipyards-20e90c9-checkpoint.zip),
[build notes](builds/windows/MuddsShipyards-20e90c9-notes.txt),
[original contract/results](docs/history/ROADMAP_DELIVERIES.md#browser-inline-session-recovery--delivered).
Owned scratch cleaned; only raw results remain. All11 public hashes/exact ZIP
and8 unique build files verified. Engine-stage timing excludes implementation
and publication; total elapsed against the original estimate was not captured.

This closes one UI defect under parent25. Full ordinary Main/browser OS-input
retry/admission, rendered readability, capacity/endurance/native/human/final
remain OPEN/NOT_RUN. The5s deadline1c679a4, paused LAN042c701 and Beacon reward
e06550e retain their recorded scopes. Beacon home/Perimeter Hold remain parked.

## Parked failures and dependent work

These are unfinished outcomes, not candidates for an unchanged retry. Exact
contracts and cumulative attempt records remain in the retained history.

| Outcome | Last actual result | Condition before more work |
| --- | --- | --- |
| BROWSER-ORDINARY /25 | Candidatee944f52:89Python/privacy/35join/package checks pass, actual routeFAIL40.554s at NetworkSession tree_exited disconnect error; cleanup fixture command rejected. | PARKED/unmerged/withheld. Full continuation NOT_RUN; no further exception/repair/probe/retry. Raw data/eight builds preserved; scratch cleaned. |
| AFT-CONSOLE-VIEW /9,12 | Standalone actual-module Xvfb/Forward+/llvmpipe capture FAIL120.485s after camera setup; no image or visual finding. | PARKED; source/root cause unproven. No cap increase, alternate backend/view or retry selected. Owned scratch cleaned; raw results retained. |
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
   estimate and check duration before starting. Prefer30–60min implementation;
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
