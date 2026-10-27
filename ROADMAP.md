# Development roadmap

**Playable alpha; full original scope remains unfinished.** Latest Windows build:
[7876ebc checkpoint](builds/windows/MuddsShipyards-7876ebc-checkpoint.zip)
([changes and validation](builds/windows/MuddsShipyards-7876ebc-notes.txt)).
Matching [Linux checkpoint](builds/linux/MuddsShipyards-7876ebc-linux-x86_64.tar.gz)
([Linux validation](builds/linux/MuddsShipyards-7876ebc-linux-notes.txt)) is available.
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
PASS only if: [all expected values/counts/tolerances and preserved state]
Proof: [check/route and expected output; source/package/device scope]
Dependencies: [existing IDs and exact required result; or none]
Missing inputs: [field -> owner -> artifact/answer; or none]
Budget: [estimate including checks/build/integration/cleanup]
Stop: [absolute deadline, original run limits, independent abort]
Prior attempts: [total time, first failure, retained source/results; or none]
Close: [PASS/FAIL/BLOCKED/PARKED, proof, commit/push, checkpoint if needed,
        owned branch/worktree/process/scratch cleanup]
```

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

Stop at the first unexpected failure. One failed repair requires a recorded
cumulative-priority decision before continuation: park/switch, or one correction
supported by a demonstrated cause and an explicit next stop. No automatic retry.
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

**Selected — one reviewed varied-capture preparation correction.**
Independent cumulative review permits synchronous supervisor logging, then one
import and one unchanged18-frame capture. Original02:40→03:40UTC clock and
03:00/03:05 preparation/launch cutoffs remain; next failure ends the continuation.
[Exact limited authorization](docs/ROADMAP_BACKLOG.md#varied-encounter-complete-image-set--frozen-2026-10-27).

**PARKED — varied encounter capture preparation; no engine launched.**
The external wrapper passed log/status options without the supervisor's required
`--detach`; argument parsing refused before import. Its subsequent missing-log
read also failed. No capture, image, runtime change or qualification is delivered.
First-failure stop retained; no patch/retry selected. Owned checkout/profile/
scratch removed; six record files verified archived,9.093minutes through cleanup
on the original02:40UTC clock, plus final documentation/push cost.
[Exact failure and next reopening requirement](docs/history/ROADMAP_DELIVERIES.md#varied-encounter-preparation-refused-before-engine-20261027).

**PARKED — Cinder codec continuation stops at a component regression.**
One independently approved correction retains the raw acknowledgement and uses
the exact production JSON canonical form for full-state comparison.314Python,
import and privacy pass; the new Godot exact-float combined assertion fails.
Other new raw-preservation/canonical-equality/wrong-field checks pass, but actual
fixture float values were not logged, so the precise false comparison remains
unproved. No production codec/engine defect is inferred.
No export or second gameplay attempt ran. The first attempt's walking/boarding/
90seat/12mlift observations remain; firing, full flight/home/reuse and normal UI
OS0 are unqualified. [Both stops, source and cleanup](docs/history/ROADMAP_DELIVERIES.md#cinder-codec-continuation-parked-at-component-regression-20261027).
Six candidate files stay unmerged in a verified archive. Owned branch/worktree/
process/scratch cleanup completes60.395minutes from original01:33:55UTC, retaining
original03:03:55 hard stop and both failures. No further correction/test/run is
selected under this closed continuation; no fresh budget or third attempt.

**Accepted — INSTALL-WIN-FINAL compiler-generated uninstaller export.**
Builder17a11183a exports the finalized standalone uninstaller and records its
actual size/hash in the existing result.33 tests pass/one PowerShell check is
skipped. One unsigned [checkpoint setup](builds/windows/MuddsShipyards-7876ebc-installer-17a1118-setup.exe)
([actual validation](builds/windows/MuddsShipyards-7876ebc-installer-17a1118-notes.txt))
compiles81.969s under600s; exported117,593-byte PE/version/hash and extracted game
match their recorded identities. All six earlier artifacts stay unchanged.
This resolves standalone artifact identity for newly compiled setups; earlier
setups keep their limits. Native Windows, trusted signing and final-candidate
qualification stay unperformed/open. The previous source-version repair remains
accepted. [Finite delivery and original clock](docs/history/ROADMAP_DELIVERIES.md#compiler-generated-windows-uninstaller-export-accepted-20261027).
Accepted work is pushed and its owned branch/worktree/process/scratch are cleaned.
The next implementation remains unselected until its literal acceptance is ready.

**Completed this pass: inventory-wide acceptance review.** This is planning
work, with no gameplay completion implied. All 337 rows were reviewed; 12 existing
rows now have literal proof or exact missing-field/owner bindings. Independent
review and the ID/order/parent/kind preservation check pass. Preserve all 337 IDs, their kinds,
36 parent outcomes and ten phase exits. Each canonical row must retain either
its finite result and proof in the
row/linked contract, or its exact missing fields and responsible owner. The
remaining source-resolvable definitions below are still open. Do not add another
planning inventory or restart completed source surveys.
The remaining definition gaps stay visible under
[PLAN-NEXT](docs/ROADMAP_BACKLOG.md#remaining-contract-gaps--plan-next).
A named blocker makes the situation explicit; it does not finish the blocked goal.

For the next implementation, select **one** existing capability with a complete
acceptance card. A broad parent, container, whole craft or “remaining tests” is
not an assignment. Keep implementation goals within 90 minutes including checks,
checkpoint, integration and cleanup; split production changes that exceed that
estimate before starting. Preserve full-route and soak durations separately.
Do not start a new gameplay attempt from this documentation edit.

| Existing goal | Current terminal result | Proven boundary / exact next requirement |
| --- | --- | --- |
| WEAPON-JOVIAN / selected CRAFT-ACCEPT-JOVIAN member | PARKED after the one authorized departure correction | Physical Gantry admission,90 seated ticks and actual first departure pass. At frame2210 the root moves1.753796m against the unchanged1.603333m per-tick bound. No clearance waypoint, Fire, home, reuse or normal UI OS0 passes. The motion owner/cause is unknown; no correction or retry is selected. Failed source remains unmerged and is archived with raw results; owned worktree/branch/process/scratch cleanup completes01:01:30UTC. |
| Linux archive executable mode | ACCEPTED,6b667235b | Private-umask exports retain ELF0755;23 exporter checks and actual corrected archive startup pass. This two-file packaging fix stays integrated. |
| PLAN-NEXT | OPEN definition | Each missing route, member list, expected value, proof command or external input must be named in its existing row. Accepted child results stay closed in their recorded source/package scope. |

The latest playable checkpoint remains7876ebc. The failed Jovian candidate does
not change that build or qualify its cannon. Its original90minute budget starts
2026-10-26 23:40UTC and ends2026-10-27 01:10UTC; the correction has no fresh budget.
The corrected driver is c1488e70b, while its reused exact game package is from
7afcedcb3; these are different source pins.

[Prior execution notes and frozen contracts](docs/history/ROADMAP_DELIVERIES.md#roadmap-execution-notes-superseded-by-the-concrete-goal-review--2026-10-27)
are retained as history. Use the canonical rows for current state and each
historical result only within its recorded scope. Old “selected” statements in
history never authorize a new run.

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
