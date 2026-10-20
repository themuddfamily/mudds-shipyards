# Development roadmap

**Status: playable development alpha; project completion is unproven.** Latest
accepted checkpoint: **49047eb**, explaining blocked save repair and retaining
damaged-save preservation.
[Windows notes](builds/windows/MuddsShipyards-49047eb-notes.txt) and
[Linux notes](builds/linux/MuddsShipyards-49047eb-linux-notes.txt) state checks and
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

**Build capability delivered: RPC-CACHE-BUILD-RECIPE (parents 25/32), source
f45c9094f.** The existing isolated builder now supports the narrow RPC-cache
patch on Windows or Linux release templates. The candidate reuses the exact callback originally connected,
instead of reconstructing it during cache cleanup. Independent source/lifecycle
review supports this candidate; it is not a verified fix.
[Exact ownership, checks and stop boundary](docs/ROADMAP_BACKLOG.md#release-rpc-cache-correction--implementation-cards).

| Child | State | Deliverable and completion check |
| --- | --- | --- |
| RPC-CACHE-BUILD-RECIPE | DONE; integrated, feature branch pushed | Isolated RPC mode, two-platform planning/staging and pinned two-file native patch. All24 existing/extended inert tool tests pass under60s cap. Actual engine compilation/runtime NOT_RUN; no new playable checkpoint. |
| RPC-CACHE-TEMPLATES | STOP after cold + one incremental timeout; Linux PASS | Linux SHA4fe7e2cf,2934.911s. Windows cold3600s cap/3611.847s stage, incremental480s cap/492.111s stage; both exit1/no diagnostics, no accepted PE. All15,090 observed identities absent. Closed/cleaned at86.5min within original90min; no further retry. Pair/collection/runtime remain unavailable. |
| BROWSER-FIXTURE-JSON | DONE; source fixture integrated | Actual JSON numbers normalize safely;62 assertions and real raw0→admitting1→raw2→stop3 handoff pass with original3s limits. No packaged-client acceptance. |
| NET-TIMEOUT-RELEASE-ACCEPT | GATED on matching templates | Relevant focused checks, clean paired exports/strict startups/package checks, then original full ordinary route with unchanged criteria/limits. The fixture handoff prerequisite now passes; native runtime effectiveness remains unverified. No execution selected yet. |

**Current action:** template attempt stopped after the cold build and one
explicitly reviewed incremental finish both reached their compiler caps. No
further retry, collection, game export or runtime route is selected. Cleaned
both duplicate worktrees and disposable helpers/profiles; exact Linux template,
reusable source/SDK/object cache and raw results remain. Original cumulative90min
budget was not reset; closure at86.5min. [Original commands and result](docs/ROADMAP_BACKLOG.md#release-rpc-cache-correction--implementation-cards).
Preparation took6.8min versus15–30min estimate; required SDK files/source pins
verified and preparation actors gone. No game capture or public checkpoint selected.
BROWSER-FIXTURE-JSON is complete: actual JSON sequence numbers normalize safely,
62 assertions pass and the unchanged driver completed raw→admitting→raw→stop.
Three stages took51.654s; all ten observed process identities are absent. Only the
tested fixture file is integrated; no ordinary-route retry or gameplay checkpoint.
All build owners are terminal; matching-template completion remains parked.
The independent save-protection case below is DONE in its named source/Linux
real-file scope. No executable card is currently selected.
The later acceptance candidatee5b9dd25f is prepared and branch-pushed: original
browser-support files plus accepted fixture, with passive capture excluded. It is
unmerged/unqualified; no check/export/route was run during assembly. Its clean
worktree is removed; pushed source and reviewed helper drafts remain retained.
Recipe commit→owned cleanup:4.8min against45–60min implementation/review estimate;
unit stage0.514s. [Result and usage](docs/history/ROADMAP_DELIVERIES.md#rpc-cache-release-template-recipe--implemented).

The passive capture is complete: same valid native SceneCacheInterface callback
remains attached after5,006ms release timeout. Original route still exits1/
success:false. Diagnostic branch783c8c872 remains unmerged/withheld; package/logs
preserved and owned scratch cleaned. [Actual result](docs/history/ROADMAP_DELIVERIES.md#release-timeout-callback-capture--known-failure-captured).

Source review rules out the earlier bind-omission hypothesis: signal comparison
intentionally ignores bind wrappers. Empty release method metadata is expected.
The exact reconstructed native-identity mismatch remains unknown; do not call the
candidate a confirmed fix or alter general callable comparison.

### Waiting decisions — not executable tasks

These questions have already been asked. Keep them pending without asking again
or treating elapsed time as a choice.

| Child | Required input | Result after the dependency resolves |
| --- | --- | --- |
| [AUDIO-NAVIGATOR-CLIENT-REJECTION](docs/COMPLETION_SCOPE.md#client-navigator-rejection-response--bounded-definition-next) | All fresh current refusals including unavailable consumer, or consumer/bridge refusals only. | Correct requester-correlated refusal feedback. Freeze implementation/proof after the choice; prior estimate 45–60min implementation/review, 15–25min checks, 10–15min checkpoint. |
| [HAULER-CARGO-MANIFEST](docs/ROADMAP_BACKLOG.md#hauler-supply-integration-boundaries) | Shared existing stock, separate Hauler stock, or loading-terminal custody. | Actual Hauler cargo admission and conserved source ownership; ordinary delivery remains separately gated. Generation-floor API already exists; freeze files/proof after the choice. Prior estimate 60–90min implementation/checks, checkpoint additional; split before 90min. |

Other scope, evidence, hardware and authorization dependencies remain in the
[backlog](docs/ROADMAP_BACKLOG.md#external-dependencies-outside-the-ready-queue).
[Parked failures](#parked-failures-and-dependent-work) require their recorded
reopening conditions; they are not the next executable queue.

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
The release capture is complete; no repeated observation is selected. The build recipe is delivered; actual patched templates are the next dependency.

## Selected independent save-protection check

**SAVE-UNSUPPORTED[future outer envelope / real files]** (parents31/32),
qualification of existing refusal behavior. Root freezes this bounded case before
edits: extend only `tests/user_data_store_crash_points_test.gd`, one medium
implementer, one independent high lifecycle/data-preservation review. Use one clean
owned worktree; existing production save owners unchanged unless a separately
selected reproduced defect requires a repair.

Create synthetic current primary/backup via actual UserDataStore commits, then
publish a schema_version=SCHEMA_VERSION+1 envelope at primary, .tmp or .bak in
three owned fixture directories. Keep opaque synthetic marker content, another
unrelated file, exact bytes/names and Unix modes. A retained legitimately loaded
store must refuse commit as newer_schema after publication. Two fresh headless/
Dummy child processes then attempt load/read-only-load/commit/recovery/restore/
discard and independently verify refusal plus unchanged files. Fresh commit may
correctly refuse not_loaded after failed load; never fabricate loaded authority.
Require distinct actual parent/child PIDs, unmodified bytes/names/modes, no marker
content in captured diagnostics and no owned survivors. Preserve existing crash
cases. No fake filesystem, field assignment, actual user files or new validator.

Proof once after review/clean candidate: guarded fresh import180s; existing crash-
point suite60s exit0/exactly one USER_DATA_STORE_CRASH_POINTS_TEST_OK. Every engine,
including child invocations, headless/--audio-driver Dummy, private XDG/TMPDIR,
HOME unchanged, source/index/cache/engine/process guards. Estimate30–45min edit/
review plus2–5min checks/cleanup; split before60min. First unexpected failure STOP,
no automatic repair/retry/cap increase. Commit/push and clean owned scratch.
This closes only the named source/Linux real-file case if it passes; nested
settings/legacy formats, installed/package/native/UI recovery and broad parents
stay open. No new gameplay checkpoint is needed for a test-only qualification.
Windows template compilation remains parked with both timeouts retained.

Initial candidatebcc699839: importPASS20.823s, suiteFAIL2.545s at child1's
unsupported parent-liveness query, child2 not launched; all8 observed identities
absent. This is a caller failure, no save defect established. Actual pinned Unix
source confirms is_process_running uses waitpid/ECHILD and captured OS.execute
already waits/reaps via pclose. After independent review, select exactly one
caller correction: remove both invalid is_process_running predicates (child on
invoker, parent on already-reaped child), with accurate identity descriptions.
Keep nonce/ownerfile, actual distinct PIDs, external supervisor, every data/mode/
diagnostic assertion and60s suite cap. No production edits or suppressed errors.
Retain accepted import/cache (only non-global test code changes); one separately
frozen suite run, then STOP on any unexpected failure with no further repair.
Original failure/time and30–45min plus2–5min/cumulative60min budget stay binding.

Accepted result2026-10-20: corrected candidate4b66b3548, suitePASS3.507s,
118 parent assertions and23 in each of two actual fresh children. Invoking
PID1639834, childPIDs1639855/1639878 observed by the independent supervisor;
all15 observed identities across original and corrected stages absent. Retained
loaded commits and all six fresh API calls refuse as specified; three fixtures
retain exact names/bytes/Unix modes and unrelated sentinel. No diagnostics or
opaque marker leak in corrected run. Original failed caller remains recorded.
Cumulative check time26.874s includes import and initial failure; exact tested
file integrated. No production save change or new playable checkpoint; other
SAVE-UNSUPPORTED formats/native/installed and wider recovery gates remain open.

## Save-preservation repair delivered

**RECOVERY-FIX[corrupt primary preservation] / SAVE-CORRUPT**, parents31/32:
accepted on source/checkpoint **9326614**. Repair now verifies a retained copy of
the current damaged primary before replacement across commit, interrupted-save
promotion and explicit backup restoration. A different occupied recovery copy
blocks replacement; identical recovery bytes permit repair.

Store124, binding11 and real-file crash129 assertions pass, including a fresh
process preserving the conflicting fixture and repairing the matching fixture.
Paired exports, three strict menu-ready startup checks and package parity pass.
[Changes, original failed test declaration, actual checks and limits](docs/history/ROADMAP_DELIVERIES.md#corrupt-save-preservation--shipped-on-9326614).
Other corrupt/unsupported formats, installed recovery cuts, active-run policy
choices and all broad parent/phase gates remain open.

## Blocked recovery feedback delivered

**RECOVERY-FIX[corrupt primary preservation] / SAVE-CORRUPT**, parents31/32:
checkpoint **49047eb** explains the known preservation refusal as blocked, with
the damaged save and verified backup retained. It retires confirmation and keeps
the internal reason code out of the banner; real publication ambiguity retains
its existing message. Persistence/retry policy is unchanged.

HUD29, confirmation integration12 and GameFlow18 assertions pass; all10 frozen
source/package stages pass without retries. [Actual outcome and limits](docs/history/ROADMAP_DELIVERIES.md#blocked-save-repair-feedback--shipped-on-49047eb).
This finishes the named feedback follow-up, not a broad recovery parent.

## Observation walk — normal exit remains blocked

**WALK-OBSERVATION**, parents7/9, remains OPEN. Caller e390b97ba with unchanged
private game4c58efa27 exercised all54 waypoints/346.068m: actual ObservationPad,
60 viewing frames with lens-directed camera, then supported return to original
hub with the same Player. Actual focused Exit activation then emits two root
Window nonexistent-connection errors (`focus_entered` / `tree_exited`); normal
exit0 is not established. Full task is FAIL, not a shortened travel acceptance.

Root self-descendant and native-float caller failures are retained; reviewed
numeric correction uses existing finite1e-6 nominal bounds PLUS exact initial
raw-geometry stability. Only two Python files changed,82 tests pass; actual game
ELF hash/startup/artifact results reused without another export. Caller branch
`qual/observation-walk-20261020` pushed/unmerged; no gameplay repair yet.
[Actual result and retained failures](docs/history/ROADMAP_DELIVERIES.md#observation-numeric-contract--runtime-exit-failure).

Next requires a separately selected cause/owner for the Window lifetime/signal
failure during normal UI exit. Similar prior diagnostics do not establish a
shared cause. No further probe/fix/retry/cap increase selected. Original full
hub→Observation/look→hub/UI-exit criteria remain. Cumulative333.882s checks and
24.8min original freeze→cleanup stay inside90min split; no budget reset.
Latest public49047eb unchanged; unique raw/private archives retained, duplicate
checkouts/ELFs/helpers/profiles cleaned. No executable card selected.

### Selected diagnosis — popup lifetime during normal Exit

WALK-OBSERVATION/CONTROL-FIX, parents7/8/9/29/32, diagnosis only. New source fact:
pinned Popup.cpp52–75 owns the exact root focus_entered/tree_exited pair;
Object.cpp1644 means source signal_map entry missing, not a callable-comparator
slot mismatch. Normal Exit script only marks orderly state then SceneTree.quit;
no script Popup/root-signal lifetime mutation found. Missing actual Popup identity
and event ordering prevent a production repair; do not infer shared Board cause.

One high implementer owns only `scripts/diagnostics/native_sortie_observer.gd`
on private `diag/observation-exit-popup-20261020`, basecaller e390/game4c58; high
independent lifecycle reviewer, root validation/cleanup. No recursive agents.
Selected-only passive capture starts before Main: existing Popup census plus
node_added watches, ID/string-only popup visibility/tree-exiting/tree-exited
callbacks, root connection-list snapshots for the two native signals and only
changed fingerprints. Record actual receiver ID/class/path/theme/visibility/
embedded/in-tree/queued state and scalar Callable metadata; no retained Node or
Callable registry. Existing observer payload, physics cadence, route and controls
unchanged. Never connect root focus_entered/tree_exited: a new listener could mask
the missing-map error. No hide/free/reparent/disconnect/state/input mutation,
deferred wait, diagnostics suppression or invented native event ordering.

Capture goal: identify the actual Popup registered on root and its observed
lifetime/slot disappearance at the retained failure, or name the precise missing
fact. Trace prefix OBSERVATION_POPUP_LIFETIME, no new validator/schema family.
Estimate15–20min implementation/review plus5–10min checks/one full route. Original
three attempts/90min cumulative budget retained (24.8min before this mapping).
Before engines finalsourceGO+cleanpin+exactcommands: import180s, privacy60s,
private Linux export180s, strict binary startup120s, existing artifact audit90s,
original fullrouteCAP300/outer330 on isolated authenticatedX11/Dummy/dummy-renderer.
Python82 unchanged/retained. Ordinary result stays FAIL on the known two errors;
diagnosis capture cannot turn it green or close WALK. Any unexpected failure
stops, no repair/retry/cap increase. No public checkpoint for passive diagnosis.
Retain source/rawtrace/unique package, commit/push actual finding, clean owned
scratch; native/device/rendered/human and broad gates stay open.

## Latest playable result

**Blocked save-repair feedback delivered and packaged on49047eb.** When a
recovery copy cannot safely be preserved, the player sees that replacement was
blocked and save files were retained. The known refusal clears confirmation;
true publication ambiguity keeps its existing message. Damaged-save preservation
from9326614 and browser inline progress/timeout/Retry remain included.

[Windows ZIP](builds/windows/MuddsShipyards-49047eb-checkpoint.zip),
[build notes](builds/windows/MuddsShipyards-49047eb-notes.txt),
[actual validation and scope](docs/history/ROADMAP_DELIVERIES.md#blocked-save-repair-feedback--shipped-on-49047eb).
The browser's full ordinary journey and native callback route remain unfinished.
Earlier accepted gameplay outcomes retain their recorded scopes in the
[delivery history](docs/history/ROADMAP_DELIVERIES.md). No whole activity, craft,
roadmap parent or phase closes from this feedback change.

## Parked failures and dependent work

These are unfinished outcomes, not candidates for an unchanged retry. Exact
contracts and cumulative attempt records remain in the retained history.

| Outcome | Last actual result | Condition before more work |
| --- | --- | --- |
| BROWSER-ORDINARY /25 | Candidatee944f52:89Python/privacy/35join/package checks pass, actual routeFAIL40.554s at NetworkSession tree_exited disconnect error; cleanup fixture command rejected. | PARKED/unmerged/withheld. Subsequent passive capture identifies retained native RPC-cache callback; it does not qualify the route. Full continuation NOT_RUN. Original raw data/eight builds preserved; scratch cleaned. |
| AFT-CONSOLE-VIEW /9,12 | Standalone actual-module Xvfb/Forward+/llvmpipe capture FAIL120.485s after camera setup; no image or visual finding. | PARKED; source/root cause unproven. No cap increase, alternate backend/view or retry selected. Owned scratch cleaned; raw results retained. |
| WALK-OBSERVATION /7,9 | Two caller failures retained; numeric e390/unchanged game4c58 completes54-goal travel/view/home prefix then FAIL89.064s on rootWindow signal disconnections after focused Exit. | PARKED; full task remains unaccepted, no clean exit0. Separate Window cause/owner required; no probe/repair/retry selected. |
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
