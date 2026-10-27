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

**Current implementation: PACKAGE-FINAL paired-artifact audit.**
One bounded release-tool capability is selected in its [frozen card](docs/ROADMAP_BACKLOG.md#package-final--existing-members-and-counts),
05:20:33–06:50:33UTC. Extend the existing inventory tool, retain its positional
CLI, pass valid/tampered artifact checks and audit unchanged checkpoint7876ebc.
No engine/gameplay/checkpoint change is selected. PLAN-NEXT remains unfinished.
First focused suite passes27 tests; source review stops on missing ZIP regular-file
type enforcement. One minimal correction is selected in the same frozen budget;
no actual checkpoint audit has run.
The breakdown is still OPEN. Reviewing all337 records did not supply every
missing route, member list or expected value. Those gaps remain in the existing
[finite definition list](docs/ROADMAP_BACKLOG.md#remaining-contract-gaps--plan-next).
Do not report that review as a completed executable roadmap.

The current pass defines one [paired-artifact audit capability](docs/ROADMAP_BACKLOG.md#package-final--existing-members-and-counts),
fills literal station/member fields in the existing
[13-subject view contract](docs/ROADMAP_BACKLOG.md#station-presentation--finite-review-boundaries),
and fixes [caption ingress/expiry/Reset acceptance](docs/ROADMAP_BACKLOG.md#caption-episodes--ingress-and-reset-boundary).
The audit and caption callers still need implementation. Station player-eye
camera/image-readback and remaining ordinary episode observers remain Codex work.
These definitions select no runtime retry and close no player journey or phase.
Earlier seat/colour/combat/crew bindings remain in their existing contracts;
PLAN-NEXT stays OPEN until its remaining source-resolvable fields are supplied.

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

**One implementation active.** Choose another existing capability only after
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
