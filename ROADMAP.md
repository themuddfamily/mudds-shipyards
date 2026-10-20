# Development roadmap

**Status: playable development alpha; project completion is unproven.** Latest
accepted checkpoint: **3d92b91**, explaining paused saved Convoy objectives and
crediting the existing planetary ambience loops; earlier save protection remains.
[Windows notes](builds/windows/MuddsShipyards-3d92b91-notes.txt) and
[Linux notes](builds/linux/MuddsShipyards-3d92b91-linux-notes.txt) state checks and
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

**Latest completed planning task: LIFE-PACKAGE-DEFINE (parent 7).** The
[finite lifecycle breakdown](docs/ROADMAP_BACKLOG.md#packaged-ordinary-lifecycle--life-package-define)
now separates five existing outcome groups, their actual dependencies and the
missing packaged ordinary-route seam. This was a source/contract review with
one bounded backlog edit, no engine run and no gameplay completion claim.

| Work | Actual state | Completion / next boundary |
| --- | --- | --- |
| LIFE-PACKAGE-DEFINE /7 | DONE as definition only | Five existing outcome groups now have explicit uncovered behavior and runnable/dependency boundaries. Four/twelve-cycle source passes remain accepted; no package journey was rerun or newly accepted. |
| WALK-OBSERVATION exit diagnosis /7,8,9,29,32 | STOPPED after one capture; Tooltip identified, cause unresolved | PlanetaryDestinationOpenButton Tooltip retains both native root connections across the errors. Attempted native comparator identity remains unknown; full walk FAIL. [Result and stopping boundary](#selected-diagnosis--popup-lifetime-during-normal-exit); no repeat or repair selected. |
| Process-exit tooltip cleanup /7,8,9,29,32 | WITHHELD; private route PASS, repair INCONCLUSIVE | Sourcebae551d58 preserves marker/restart input semantics;39 focused assertions and full route pass. Active-tooltip regression precondition absent, so no integration, checkpoint or second attempt. |
| GUIDED[current checkpoint3d92b91] /7; initial Guided interceptor /11 | DONE in recorded Linux ordinary-input scope | Original3/3 complete, default controls,91 neutral frames and actual craft exit. Final-package/other craft/encounter/native gates remain separate; no unchanged repeat scheduled. |
| Matching RPC-cache templates /25,32 | PARKED; Linux built, Windows cold and incremental attempts timed out | No accepted matching pair; no further compilation or dependent browser route selected. [Retained result](docs/history/ROADMAP_DELIVERIES.md#matching-rpc-cache-templates--stopped-at-windows-compilation-budget). |

The RPC build recipe and browser JSON fixture are delivered in their recorded
source scopes; they are no longer current tasks. The cache callback repair is
still an unverified candidate. Empty release callable metadata does not prove a
cause, and no shared cause with the Window failure is established.

**Delivered on checkpoint3d92b91: saved Convoy objective and planetary ambience credits.**
Cold-restored/wrong-craft Convoy objectives now explain the paused save and name
the craft to board; accepted rebind restores live progress. Credits now include
the three actual procedural surface ambience loops. Source3d92b9181 is integrated
and pushed. Existing Convoy20/Credits25 assertions, actual Windows-payload credits,
paired exports, three strict startups and artifact audit all PASS first attempt:
10 stages203.594s, all45 process identities absent, owned cleanup at9.0min from
selection against45min cap. [Player changes, actual checks and limits](docs/history/ROADMAP_DELIVERIES.md#saved-convoy-objective-and-planetary-credits--shipped-on-3d92b91).

RIGHTS-DEFINE is complete as a [finite source-backed family map](docs/ROADMAP_BACKLOG.md#rights-families-and-missing-documents--rights-define),
not legal clearance or a release gate. Missing project release terms and separate
historical-media redistribution records remain explicit; the settled creator-
permission account is preserved. **GUIDED[current checkpoint3d92b91] accepted3/3.** Three fresh ordinary-input
runs complete the full training/combat/home/neutral-shutdown/physical-disembark
route in49.212/47.913/50.147s, zero diagnostics; each retains91 neutral frames
and0.17m physical exit error. This also supplies the named initial Guided
interceptor encounter proof in the same Torrent scope, without a second delivery.
[Exact scope, unchanged contract and actual results](docs/history/ROADMAP_DELIVERIES.md#guided-checkpoint3d92b91--original-ordinary-route-accepted3of3).
All18 process identities absent; owned cleanup5.43min, no new build/source change.
GUIDED-FINAL, other encounters, Sandbox/Settings and broader gates remain open.
**Selected implementation: COMBAT-COURIER ordinary packaged route, parent11.**
Normal entry already exists: Guided range clear → keep initial defender alive
for4.5 physics seconds → automatic first courier dispatch. No encounter selector
or production combat integration is missing. Root owns existing
`run_native_sortie.py`/`test_native_sortie.py`; one medium implementer owns only
`native_sortie_observer.gd`, `startup_loader.gd` and existing startup privacy test.
One high reviewer checks read-only observation, scalar retained hit/kill receipts
and full-route acceptance before engines. No recursive agents.

Add explicit silent-private `courier-intercept` route/mode. Reuse unchanged
Guided prefix/defender/home/neutral-shutdown/physical exit; wait without firing
at defender, pursue actual runner using authored controls/weapons. Read-only
Courier/director snapshot includes actor identity/pose/velocity/health, scenario/
generation/outcome/escape progress and retained scalar accepted/resolved player
hit+kill receipts tied to source ship/target/sequence/positive damage. Require
actual courier destruction before1400m escape AND CLEARED; generic fire, escape,
withdrawal, disappearance or roster deactivation cannot pass. Then clear initial
defender and finish home. Preserve4.5s dispatch,82% distress,2.4s escort,700m/7s
disengagement and150s backstop; no fixture placement, direct damage, tuning,
authority, event-order or timing changes. Escape/withdrawal/recovery remain
separate cases; prior Guided3/3 is reused, not repeated as a separate assignment.

Estimate25–35min implementation/review,10min focused/export/one full ordinary
route,10min checkpoint if accepted; stop/split at60min from selection. Freeze
clean source/commands before engines: existing Python driver tests60s, fresh
Dummy import180s, privacy60s, private Linux export180s/strict startup120s, original
full normal route CAP300/outer330 once, then Windows export180s, archive/payload
strict startups120s each and actual package audit90s. First unexpected failure
STOP; no automatic repair/retry, cap increase, shortened journey or expected-error
suppression. Only complete route/zero diagnostics permits integration and paired
checkpoint; otherwise retain withheld source/raw artifacts and clean owned
scratch. Native Windows/GPU/device/audio/human and broader combat/release stay open.
Tooltip cleanup-order candidate remains unmerged/unproved; no retry is scheduled.

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
The earlier RPC-cache capture is complete. Matching patched templates remain
unavailable and Windows compilation is parked; neither is an automatic next task.

## Unsupported-save protection — completed scoped check

**SAVE-UNSUPPORTED[future outer envelope / real files]**, parents31/32, is DONE
in source/Linux real-file scope on4b66b3548. A legitimately loaded store and two
fresh child processes refuse destructive operations after a future envelope is
published at primary/tmp/backup; exact names, bytes, Unix modes and unrelated
files remain. The corrected suite passes118 parent assertions and23 per child,
with no diagnostics or opaque-marker leak. All15 observed process identities
are absent. No production change or new gameplay checkpoint was needed.

[Original failed caller, corrected check and retained scope](docs/history/ROADMAP_DELIVERIES.md#future-save-outer-envelopes--sourcelinux-real-file-case-accepted)
remain authoritative. Cumulative checks26.874s include the original failure;
other formats, installed/native/UI recovery and broad parents stay open. This
accepted check is history, not an executable task.

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
shared cause. The passive diagnosis below has now stopped; no gameplay repair,
acceptance retry or cap increase is selected. Original full
hub→Observation/look→hub/UI-exit criteria remain. Cumulative333.882s checks and
24.8min original freeze→cleanup stay inside90min split; no budget reset.
Latest public49047eb unchanged; unique raw/private archives retained, duplicate
checkouts/ELFs/helpers/profiles cleaned. The later diagnostic capture below
retains its own package/result and stops without a gameplay repair.

### Selected diagnosis — popup lifetime during normal Exit

**STOPPED after one capture; Popup identified, native cause unresolved.** Source
9743b650f is committed/pushed on its diagnostic branch and remains unmerged.
Five import/privacy/export/strict-startup/artifact checks pass. The full ordinary
route still FAILS90.724s on the two original root signal errors after all54
waypoints, actual60-frame view and supported home return. No normal exit0 or
WALK acceptance; that diagnosis published no checkpoint.

The receiver is a visible embedded **TooltipPanel beneath
PlanetaryDestinationOpenButton**. Both root outgoing and Popup incoming
connections retain the same stored hashes immediately before and after the
errors. No connection-removal event was observed. The exact missing fact is the
attempted native Callable comparator/hash/data versus the stored Callable;
neither its cause nor a production repair is established. Similar Board/RPC
errors do not establish shared ownership.

[Original frozen selection, actual event bracket, validation and limits](docs/history/ROADMAP_DELIVERIES.md#observation-popup-lifetime-capture--failure-boundary-identified)
retain the full contract and failed result. Six stages181.145s; cumulative
checks515.027s with all original failures retained. All31 new process identities
absent, inputs/helper/game/Xvfb released; unique package/raw logs/profile archive
retained. Owned checkout/cache/helpers/profiles cleaned at47.37min from original
freeze, inside the unchanged90min budget. The one later cleanup-order candidate is recorded above; it does not establish
a repair. No further probe/repair/retry selected.

## Latest playable result

**Checkpoint3d92b91** fixes misleading live progress on a paused saved Convoy
escort and adds the missing planetary ambience attribution. It retains earlier
save-preservation/blocked-feedback, browser and accepted gameplay improvements.

[Windows checkpoint ZIP](builds/windows/MuddsShipyards-3d92b91-checkpoint.zip),
[build notes](builds/windows/MuddsShipyards-3d92b91-notes.txt),
[actual validation and scope](docs/history/ROADMAP_DELIVERIES.md#saved-convoy-objective-and-planetary-credits--shipped-on-3d92b91).
Full Convoy play/endurance, native Windows/GPU/device/audio/human review and final
release remain open. Native-tooltip shutdown failure and its unproved cleanup
candidate are not resolved by this independent delivery. No broad parent or
phase closes from these two content/UI changes.

## Parked failures and dependent work

These are unfinished outcomes, not candidates for an unchanged retry. Exact
contracts and cumulative attempt records remain in the retained history.

| Outcome | Last actual result | Condition before more work |
| --- | --- | --- |
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
