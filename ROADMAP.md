# Development roadmap

**Playable alpha; full original scope remains unfinished.** Latest Windows build:
[7876ebc checkpoint](builds/windows/MuddsShipyards-5010203-checkpoint.zip)
([changes and validation](builds/windows/MuddsShipyards-5010203-notes.txt)).
Matching [Linux checkpoint](builds/linux/MuddsShipyards-5010203-linux-x86_64.tar.gz)
([Linux validation](builds/linux/MuddsShipyards-5010203-linux-notes.txt)) is available.
The recovery card now offers **Use Safe Audio** after repeated unfinished
startups. It saves master50%/music0 through the existing adapter, preserves other
preferences and retains the existing stable Restore/user-edit protections.
Earlier journey results below retain their original source/package scopes;
they were not rerun for5010203.
Legacy CFG recovery, read-only loading and direct legacy saves now preserve a
newer primary, temporary or backup generation instead of selecting older data
or deleting the newer file. All three files and live preferences stay unchanged.
Confirmed settings backup repair now explains when to quit and reopen the game
to finish recovery; the existing startup owners supply that condition.
Jovian cabin Interact now takes the aimed-at helm instead of its co-pilot chair.
The complete ordinary engineer-save/SIGKILL/normal-recovery/cabin-walk/helm/throttle/
normal-Quit journey passes on the exported Linux checkpoint.
Forward projectile hits now reach the actual forward-hull ledger and local cue;
collision routing remains unchanged. The full Zenith→Torrent Guided→same Zenith handback now passes ordinary synthetic
keyboard input, strict home/exit/reclaim and normal HUD Quit. The lower Aft stair has a visible, collision-backed shoulder onto the landing;
the captured lateral walk retains real floor contact. Reduced flash still updates the current/new HUD damage cue through normal Settings.
Actual save/reset/refusal results also control the HUD unsaved state. The native
Linux synthetic-keyboard save/three-process/Reset sequence passes. Prior cargo,
torpedo and ordinary Ember Quit repairs remain accepted. Full cargo/comfort/world
journeys, remaining producer episodes, physical input and native hardware gates
remain open.
Nine of the promised 17 craft exist. All 36 original parent outcomes and ten phase
exit gates remain open; completed child results are retained, not counted as whole
features. There is no evidence-backed project percentage or completion date.

## How we will work from this roadmap

Every remaining item must resolve to one of three things: **a ready task with a
fixed pass/fail check**, **a blocked task naming its exact missing input and
owner**, or **a container listing the tasks needed to finish it**. A blocked
item is unfinished; describing its blocker does not make it complete. The
[remaining contract gaps](docs/ROADMAP_BACKLOG.md#remaining-contract-gaps--plan-next)
are still blocked, not a list of ready implementation assignments.

Use this short card in the existing goal's row or linked contract before
starting. Fill the brackets with literal values; an unfilled bracket blocks work.
Do not create a second task tracker.

```text
Goal: [existing ID and one result]
Player/build result: [action -> observable outcome]
Included: [finite behavior/case list]; excluded: [adjacent work deferred]
Start: [commit/package, profile, location, participants/device, owned files]
Actions: [ordered steps or exact command]
PASS only if: [each predicate -> actual observation -> expected value/tolerance; preserved state]
Proof: [check/route and expected output; source/package/device scope]
Dependencies: [existing IDs and exact required result; or none]
Missing inputs: [field -> owner -> artifact/answer; or none]
Budget: [estimate including checks/build/integration/cleanup]
Stop: [absolute deadline including closure, original run limits, independent abort]
Corrections: [total allowance for this selection; default one, never replenished]
Prior attempts: [total time, first failure, retained source/results; or none]
Close: [PASS/FAIL/BLOCKED/PARKED, proof, commit/push, checkpoint if needed,
        owned branch/worktree/process/scratch cleanup]
```

Every predicate names its actual observation and expected value before execution.
On failure, retain the observed values, including operands of compound assertions.
A prerequisite must actually succeed before a dependent command launches; issuing
commands in sequence alone is insufficient. Missing observations cannot establish
a runtime cause or qualify a result.

All listed PASS predicates must hold. On PASS, close this goal within that scope;
leave broader release/device gates with their existing owners. A newly found
unrelated defect goes to its existing goal and does not enlarge this card.
On failure, record the first unmet predicate and stop; do not weaken acceptance
or silently add a repair. Reopening must name the affected predicate, the new
causal evidence or missing input received, and the cumulative-priority decision.
A new label, branch or clearer wording is not new evidence.

**One active delivery, with acceptance written before work starts.** Broad
milestones below group work; they cannot be assigned as coding tasks. Use the
existing ID in the [canonical backlog](docs/ROADMAP_BACKLOG.md#concrete-child-outcomes).
Every selected goal must have these literal answers in its existing card:

| Field | Required answer |
| --- | --- |
| Result | Capability/qualification: one player action and resulting behavior, or one release operation. Definition/decision/resource: the exact finite answer, choice or artifact; no product completion implied. |
| Start | Source/package, profile/save, location, participants and exact owned files. |
| Steps | Finite ordered actions or an executable command. |
| Pass/fail | Expected state, count/value/tolerance and endpoint; preserved data; original gameplay limits. |
| Proof | Exact focused check or complete ordinary route, with expected output/state. A repair must distinguish the old failure from the corrected behavior. |
| Dependencies | Existing prerequisite IDs; each missing choice, artifact or device has a named owner. |
| Stop | Estimate including checks/build/cleanup, absolute hard deadline and independent abort; first-failure stop; cumulative cost of prior attempts. |
| Closure | Accepted result or first failed predicate; commit/push; playable checkpoint for runtime changes; owned branch/worktree/process/scratch cleanup. |

“Improve”, “polish”, “finish”, “works”, “usable”, “all applicable” and “as
specified” cannot stand alone as acceptance. Replace them with the actual action,
value or finite member list in the same card. A container closes only when its
complete named membership passes; a missing member list blocks it.

**Reviewable completion is mandatory.** Each ready capability or qualification
must name the exact command or player steps, expected output/state and proof
location. Another person must be able to decide the result without asking the
implementer what “done” meant. If those details cannot yet be supplied, record
BLOCKED definition with the literal missing fields; do not start implementation.
For a container, enumerate its existing child IDs and close only when each is
accepted. A link to a broad family, a passing helper test or a new document is
not proof of the promised running-game result.

The next selection resolves one existing missing acceptance field or delivers one
ready production result. It must not repeat a whole-roadmap inventory or create
another planning/evidence layer. Keep completed scopes closed. Report remaining
work as named unfinished outcomes and blockers, never as document/test/commit counts.

A task must say **what the player can do afterward**, or the exact build/release
operation that succeeds. For example: “Roll back499→b4→499, load the b4-earned
save in499 as session3, retain credit1/settings, walk the three named points and
Quit with OS0.” “Improve save compatibility” is not an assignment. A definition
instead names the exact unanswered fields it will supply; a decision names the
exact choice and who makes it. A family label never supplies either result.

The selected card must be self-contained enough for another person to judge its
outcome without reconstructing chat history. Link the exact command, fixture,
expected state and original limits; do not link only a broad feature document.
Record one terminal result and the first unmet predicate. Failure never silently
adds another objective or turns a completed child back into an endless task.

A goal is ready only if a reviewer can follow those steps and decide PASS or FAIL
from the frozen expected results without choosing another value or reconstructing
chat history. List unresolved fields literally under BLOCKED; do not schedule the
run. Proof must name its scope: source check, packaged automated route, physical
device or native-hardware measurement. One scope cannot silently satisfy another.
A dependency names an existing outcome and the exact result needed from it; a
family name alone is insufficient. These rules apply to every existing backlog row,
including final release and owner-dependent goals.

Missing acceptance fields mean **BLOCKED definition — Codex**, listing exactly
which fields are absent. Missing design choices or external access mean
**BLOCKED input — named owner**, listing the exact answer/artifact required.
Neither is an executable task. One definition pass gets 15–30 minutes to fill the
fields or return that exact blocker; it cannot schedule another discovery chain.

An implementation is estimated at **90 minutes or less including closure**;
split larger production changes before starting. Reserve explicit time for
integration/build/cleanup inside that budget. At the recorded hard deadline,
stop implementation and record the unfinished result; do not silently extend it.
Complete journeys/soaks retain their original durations. A failed estimate is
reported as an overrun against the same goal. A discovered prerequisite stays charged to that goal; a new
branch, card or agent never resets its elapsed cost.

Freeze the total correction allowance before implementation (default one) and
an absolute deadline including closure. A correction consumes that allowance;
a new cause, branch, card or review never replenishes it. Validate the final
allowed correction; any further failed predicate then means FAIL/PARKED and
cleanup. Reaching the absolute deadline is also terminal. No additional correction,
same-run reopening or deadline extension is allowed. A later explicit user
reprioritization must name the terminal boundary being superseded and retain all
prior costs/results; it does not retroactively make the failed attempt pass.

Stop at the first unexpected failure. Before spending any remaining correction
allowance, record a cumulative-priority decision: park/switch, or one correction
supported by a demonstrated cause and an explicit next stop. A failed correction
ends the selection when its allowance is exhausted. No automatic retry.
Accepted work remains closed within its recorded scope; reopen only the affected
predicate when an identified source change invalidates its proof. Update the
card and backlog together so stale text cannot schedule completed work again.

Report **goal → player result → PASS/FAIL/BLOCKED/PARKED → proof → remaining
blocker → cumulative time → next bounded action**. Definitions, tests, commits
and evidence files are not gameplay progress.

The inventory contains **337 records: 38 capabilities, 177 qualifications,
74 definitions, 12 decisions, five resources and 31 containers**. These are record
kinds, not a remaining-task count or completion percentage. Full craft journeys,
shared-world cases, comfort episodes, recovery cuts, installation transactions
and performance workloads still have missing bindings. Their exact missing
fields stay blocked in the existing rows; this rewrite does not invent answers
or mark those product outcomes complete.

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

## Current work and next selection

**Accepted — PACKAGE-FINAL paired-artifact audit capability.**
The existing inventory tool now checks complete Windows/Linux payload parity,
hash-pinned PE code, compiled-source bundle files, tar/ZIP contents and unchanged
inputs. Corrected28-test suite and one real7876ebc audit pass; all1529 entries and
nine predicates agree. Source d70231901 is integrated/pushed27d1e70e8.
[Exact command, first review stop, actual proof and cleanup](docs/ROADMAP_BACKLOG.md#package-final--existing-members-and-counts).
Original13-test baseline and first27-test PASS are retained; review caught ZIP
special-file metadata, and its one source-proven correction is accepted. Cleanup
finishes14.696minutes from05:20:33UTC, plus final notes/push on the same clock.
Owned branch/worktree/scratch are removed; one small verified archive remains.
No game/engine/public checkpoint change; final release/player/native gates stay open.

**PARKED — caption Save/Reset/cold caller; no implementation active.**
The three-local typing correction99658edda passes301 Python tests, import,
probe parse, privacy, private Linux export and strict actual-archive startup.
The packaged writer then exits1 at its initial caption-service/presenter assertion,
before Begin Shift or settings changes. Its operand values were not logged;
no missing runtime owner or gameplay defect is established. Writer reaped;
reader, reset-reader and default-flash regression NOT_RUN. No further correction
or reopening is selected. Candidate code remains unmerged.
[Exact failure, archive and limits](docs/ROADMAP_BACKLOG.md#caption-episodes--ingress-and-reset-boundary).
The original05:38:34 start and45.076 prior minutes stay charged; the explicit
90→105minute budget amendment is retained. Verified archive/branch/worktree/
scratch cleanup completes at70.748 cumulative wall minutes; final notes/push
remain charged to the same clock. The public playable checkpoint is unchanged.

**PARKED — COMFORT-COLOUR ordinary Guided caller; no implementation active.**
Candidate87a51f41f first failed observer parsing; the one allowed correction
7caea1fbb explicitly typed two Dictionary locals. Corrected304 Python checks,
import/parse/privacy, private Linux export and strict archive startup pass.
Actual Tritanopia flight completes combat/home/physical exit/normal HUD Quit
with game OS0, zero diagnostics and all owned processes/input cleaned up.
Its caller nevertheless fails the frozen coverage assertion:11/12 endpoints,
required HUD STARTING never observed. All1763 samples show OFFLINE or ONLINE;
no production cause is established. Default regression NOT_RUN. No further
correction/reopening is selected and candidate code stays unmerged.
[Exact terminal result and preserved source](docs/ROADMAP_BACKLOG.md#colour-cues--remaining-proof-ownership).
Original06:51:29 clock, sole correction and fixed07:51:29 deadline are retained;
archive/branch/worktree/scratch cleanup completes at14.907 cumulative minutes.
Final notes/push remain charged. Current public checkpoint and accepted colour
component/storage scopes stay unchanged; full comfort/device/rendered gates open.

**Definition complete — INSTALL-LINUX-UNINSTALL execution contract.**
The [existing final uninstall/reinstall goal](docs/ROADMAP_BACKLOG.md#final-linux-uninstallreinstall--install-linux-uninstall)
now fixes shipped-manager commands, private prefix/XDG, exact managed files/modes,
four then five protected fixtures, repeat-uninstall/fresh-generation reinstall,
full installed Guided usability and original separate limits. Actual earned-save
fixture bytes/hash verified; no engine/installation was run or final gate closed.
Final candidate identity, graphical desktop launch and retained-save gameplay
reload remain with their existing owners. Root owns only these two docs; no
branch/worktree/scratch created. Start07:08:13UTC,20minute definition estimate/
07:28:13 deadline include checks/commit/push. Source review, fixture verification,
all337 canonical identities/order and new anchors pass; roughly7minutes through
review/checks, with final commit/push charged to the same clock. No implementation
is active. The eight prepared craft SPEC proposals await the explicit owner
interpretation/design answer requested this turn; no approval has been inferred.

**Definitions complete — final Linux clean install and upgrade.**
The [existing two transaction contracts](docs/ROADMAP_BACKLOG.md#final-linux-clean-install-and-upgrade--transaction-contracts)
now fix empty-prefix clean install and actual499e681→final upgrade paths/commands,
managed/protected bytes/modes, new-generation/old-file retirement, installed full
Guided and separate original30/300/310/330s limits. Actual prior archive/payload
hashes and original wrapper limits were read/verified. Final archive identity and
all actual final execution, graphical desktop and retained-save reload remain
open; no engine/installer/export/CI run or accepted checkpoint rerun occurred.
Root owns only these two docs; no branch/worktree/scratch created. Original
07:14:58UTC start,15minute estimate/07:34:58 hard deadline include review/checks/
commit/push. Independent source review, all337 identities/order and new anchors
pass; roughly6minutes through checks, with final push charged to the same clock.
Craft design approval remains pending; no implementation active.

**Definition field complete — FINAL-RECONCILE direct parent membership.**
The [36-parent crosswalk](docs/ROADMAP_BACKLOG.md#coverage-of-the-original-remaining-outcomes)
now names each existing direct child ID instead of broad family labels. Independent
mechanical review verifies exact source-order membership, unchanged original
outcome/proof columns, all337 canonical identities/order and ten phase criteria.
Self/output/publication ordering is explicit; no pre-publication gate requires
future downloaded-byte proof. All original completion conditions remain binding.
This does not close FINAL-RECONCILE: exact phase-predicate/source/candidate bindings,
candidate defect inventory and actual qualification remain open. Root owns only
these two docs; no branch/worktree/scratch/runtime/CI/checkpoint created. Original
07:21:06 start/15minute estimate/07:41:06 hard deadline include commit/push/closure.
Craft design approval remains pending; no implementation active.

**Definition disposition complete — all ten phase predicates.**
The [existing phase table](docs/ROADMAP_BACKLOG.md#original-phase-gates-and-completion)
now links every phase to exact existing proof-owner IDs and literal missing fields.
Three disjoint source reviews pass for phases1–5/6–8/9–10; original phase names/
exit criteria, all337 canonical identities/order and declared13capture/21shared
memberships are preserved. Full journeys remain explicit in phases4/5; shared
predicate owners do not impose unrelated whole-container dependencies.
This is not executable acceptance or phase completion. Exact ordinary/candidate/
view/device/measurement bindings stay blocked where listed. Original production
crash-log redaction, complete safe graphics/audio fallback and whole orbit↔surface
repetition now have explicit missing fields under existing owners; no new task ID,
tracker/validator or proof result was invented. FINAL-RECONCILE still needs the
candidate defect inventory and actual required results, followed by authorized
distribution. Original07:21:06 definition clock/direct-membership result/cost are
retained; this phase interval starts07:26:53 and closes within the earlier07:41:06
bound, including review/checks/commit/push. Only these two docs changed; no branch/
worktree/scratch/engine/CI/checkpoint created. Craft approval remains pending;
no production implementation is active.

**Delivered — production Safe Audio recovery action; technical PASS, process deviation.**
Source50102032a integrates the missing normal HUD→GameFlow→adapter audio apply
caller. It is explicit, master0.5/music0, current-startup/revision fenced, available
after STABLE only while this startup's unconsumed graphics fallback remains active.
Automatic graphics recovery preserves audio; ordinary Restore, later user edits,
Keep Safe and refused/corrupt/newer-write protections remain. Four source suites
pass121 assertions, including actual Main/HUD/buses, typed/wire persistence,
rollback, one-shot Restore and three visible/focusable/in-bounds controls.
Fresh paired5010203 exports/three strict startups/all1529 payloads/nine artifact
audit predicates pass. EXE/checkpointZIP/notes are in builds/windows; matching
Linux files are in builds/linux. Native Windows/audible/devices/full release remain
NOT_RUN/open; source integration uses an injected filesystem, not an OS-crash run.

The first test's mixed typed/JSON number comparisons failed and are retained;
one test-only correction passed. **The frozen process card was not followed
exactly:** root later used the same filename for Linux inventory and runner status,
overwriting a passed inventory, then hit KeyError during private package preparation.
Root regenerated that read-only map with distinct names and added an orchestrator
alias guard; source, binaries, expectations/caps stayed unchanged. First actual
paired audit then passed. Independent review gives technical GO but explicitly
retains this procedural concern; root accepts the verified delivery under the
existing task authorization, not as process-contract compliance or a blanket
future retry exception. Original07:37:14 clock/45minute estimate/09:07:14 hard
stop and all failed records stay charged. No further production repair occurred.
[Exact source/proof boundary](docs/ROADMAP_BACKLOG.md#safe-start-graphicsaudio--production-action-and-proof-scope).
Owned closure is complete: source50102032a is contained in pushed main;
fresh remote/worktree ownership checked before exact-tip branch deletion (remote
branch absent), worktree/scratch removed and only archive/closeout retained.
Verified archive12814902bytes/271members, SHA256
`aef2f81b6f21320ab3af61f79920be2d081d804577a8dc5eeea24dfb2c375c4a`.
Cleanup08:25:14UTC is48.011 cumulative minutes, exceeding the45minute estimate
by3.011; final notes/push remain charged within the unchanged09:07:14 deadline.

**Active — Phase9/FINAL-RECONCILE crash-log publication retry.**
Original binding start2026-10-27 08:28:35UTC atbc0faf415 stays charged. Source
proves Main already composes private crash diagnostics, but a failed recovery
snapshot publication leaves the bridge pending and Main never calls its retry API.
Deliver normal Main physics retry at the existing1.0s cadence while the diagnostic
session is active, no per-frame hammering; success clears pending and stops retries,
retaining the exact captured recovery snapshot and one CRASH_DETECTED event.
Repeated failures retain data and retry only once per interval. Clean/teardown
must not gain dirty-marker writes or independent timers; preserve record/store
persistence, foreign data, redaction and original clean-shutdown semantics.
One agent owns GameFlow, existing lifecycle bridge only if a cheap readiness
query is needed, and existing Main diagnostics integration test. Root owns docs,
validation, paired export/checkpoint/integration/cleanup. Do not wire optional
network/threshold APIs or invent uploader/stack-capture requirements.
Proof: commit a test-only RED on old production first: injected sink-stage failures
leave publication pending/file absent across normal physics. Only the named new
retry assertions may fail; source parser/other existing predicates must pass.
Then implement consumer and run existing Main/record/lifecycle/sink suites at
unchanged300s per-suite caps, verifying1s boundaries, repeated refusal, one event/
one publication, no post-success or post-clean retry and preserved payload.
RED is expected failure, not acceptance. One correction allowance applies only to
unexpected production/test/build failures; any failed corrective validation parks.
Read-only bookkeeping regeneration may fix lost preparation output with identical
frozen inputs before an acceptance comparison; record it, never claim a failed
predicate passed, never alter source/expectations/caps to hide a failure.
Fresh paired checkpoint/three strict menu startups/full payload/archive audit
required before accepted integration. All Godot Dummy/headless or isolated x11.
Estimate30minutes including RED/GREEN/build/cleanup; absolute hard stop09:28:35UTC
(60minutes from binding), final10minutes for closure. Before launch full current
cap plus closure must fit; source/review/failed costs remain charged. Native/
real-OS crash/device/audio/full release remain open. Push accepted work and remove
owned branch/worktree/process/scratch after verified preservation. No parked retry.

**PLAN-NEXT remains OPEN.** A remaining row with an unresolved Codex-owned
acceptance field is unfinished planning, not an executable task. No runtime trial
is selected by this documentation update.

For each listed gap, supply the finite answer in its existing row/contract:
the named members, action/trigger, expected endpoint, preserved state, proof
and original limits. Reuse accepted results. If an answer needs a design decision
or unavailable artifact, name the exact field, owner and required answer/artifact.
Codex-owned source bindings remain unfinished until supplied; writing “Codex
will define this” does not pass. Each definition pass ends after15–30minutes with
the answer or the precise blocker; it cannot start a gameplay trial or a new
research chain.

**PASS for PLAN-NEXT:** every existing record has a finite result and proof or
an exact external dependency, every container names its complete membership,
and no unresolved Codex-owned action/endpoint/limit/proof field remains.
Preserve all337 IDs, their kinds/order,36 parent outcomes and ten phase exits.
This is planning completion only. Runtime completion still needs the named
player journeys and release gates.

**Select one implementation at a time.** Choose another existing capability only after
its literal acceptance card is complete. Freeze the result before editing;
include checks, checkpoint, integration and cleanup in its estimate of at most
90minutes. Full journeys and soaks retain their original durations. A failed
attempt keeps its cumulative cost and reopening condition. No runtime retry is
authorized by this wording change.

Recent terminal results are retained in their existing contracts and
[delivery history](docs/history/ROADMAP_DELIVERIES.md). They are not an active queue:

| Existing outcome | Terminal result and remaining boundary |
| --- | --- |
| SOLO-EMBER outbound driver | PARKED8219:8,010,865m/776rebases; unconditional default-source assertion rejects the production approach handoff. Landing/surface exit/normal OS0 unproven. Candidate archived unmerged; no further run selected. [Exact stop](docs/history/ROADMAP_DELIVERIES.md#ember-corrected-native-flight-parked-at-approach-command-handoff-20261027). |
| Busy exterior-exit interruption support | Accepted24774c04 source and embedded Linux accepted/refused-save pairs; installed/full ordinary/native/final qualification stays open. [Proof](docs/history/ROADMAP_DELIVERIES.md#busy-exterior-exit-release-interruption-support-accepted-20261027). |
| Varied encounter capture | PARKED at original300s,0/18images; no demonstrated render/art cause and no retry selected. [Exact stop](docs/history/ROADMAP_DELIVERIES.md#varied-encounter-preparation-refused-before-engine-20261027). |
| Cinder Light weapon/reuse driver | PARKED at component regression; firing/home/reuse/normal OS0 remain unqualified. Source archived unmerged. [Exact stop](docs/history/ROADMAP_DELIVERIES.md#cinder-codec-continuation-parked-at-component-regression-20261027). |
| INSTALL-WIN-FINAL export capability | Accepted17a11183a finalized standalone uninstaller export; trusted signing/native execution/final-candidate qualification remain open. [Proof](docs/history/ROADMAP_DELIVERIES.md#compiler-generated-windows-uninstaller-export-accepted-20261027). |
| WEAPON-JOVIAN | PARKED at per-tick displacement bound; motion cause unknown. No Fire/home/reuse acceptance or retry selected. [Exact stop](docs/history/ROADMAP_DELIVERIES.md#jovian-cannon-departure-parked-and-linux-archive-modes-fixed-20261027). |
| Linux archive executable mode | Accepted6b667235b private-umask ELF0755 export repair; final package qualification stays open. |

Latest playable checkpoint remains7876ebc. Owned temporary branches/worktrees
for these closed attempts were cleaned after preservation. Retained failures,
original clocks, source/package pins and proof limits live in their linked
contracts; none receives a fresh budget through a new label. Historical
“selected” statements do not schedule work; this section controls selection.

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
