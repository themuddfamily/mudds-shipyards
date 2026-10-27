# Development roadmap

**Playable alpha; full original scope remains unfinished.** Latest Windows build:
[7f23a80 checkpoint](builds/windows/MuddsShipyards-7f23a80-checkpoint.zip)
([changes and validation](builds/windows/MuddsShipyards-7f23a80-notes.txt)).
Matching [Linux checkpoint](builds/linux/MuddsShipyards-7f23a80-linux-x86_64.tar.gz)
([Linux validation](builds/linux/MuddsShipyards-7f23a80-linux-notes.txt)) is available.
The latest checkpoint retries refused recovery crash-log writes once per second;
successful ordinary store saves cannot postpone publication. Retries stop after
success or clean shutdown. Source checks and packaged startup/parity pass; actual
OS-crash recovery remains unqualified.
The recovery card also offers **Use Safe Audio** after repeated unfinished
startups. It saves master50%/music0 through the existing adapter, preserves other
preferences and retains the existing stable Restore/user-edit protections.
Earlier journey results retain their original source/package scopes;
they were not rerun for7f23a80.
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

A coding assignment delivers **one observable game or build result** and has a
written pass/fail check before editing begins. Broad features below are completion
containers; their existing children live in the [canonical backlog](docs/ROADMAP_BACKLOG.md#concrete-child-outcomes).
A missing driver is an implementation task. An unanswered design choice or
unavailable device names the exact input and owner. Neither counts as completion.

Each selected task must state:

1. **Result and scope:** player action → expected outcome; finite included cases.
2. **Starting point:** source/package, profile, location, participants and owned files.
3. **Proof:** exact command or ordered player steps; expected values, preserved
   state and original limits. A repair must reproduce the old failure and pass
   after the change. State whether proof is source, packaged, physical or native.
4. **Dependencies:** existing prerequisite IDs and their exact required result;
   unresolved inputs remain blocked and cannot be chosen after seeing results.
5. **Budget:** estimate ≤90 minutes for implementation, checks, checkpoint,
   integration and cleanup; absolute deadline, independent abort and fixed total
   correction allowance (default one). Preserve full journey/soak durations.
6. **Closure:** PASS with actual proof, or the first failed predicate and observed
   operands. Merge/push accepted work, provide a playable checkpoint for runtime
   changes, then clean owned branches/worktrees/processes/scratch.

Stop at the first unexpected failure. A correction needs a demonstrated cause,
remaining frozen allowance and explicit cumulative-cost decision; a failed final
correction or hard deadline parks the task. New labels/branches never reset costs,
limits or allowance. Preserve failed source/results. Reopening a parked task
requires its recorded causal condition; a wording change does not authorize it.
Dependent checks launch only after prerequisites actually pass.

Completed results stay closed in their stated source/package scope. New unrelated
defects return to their existing owner instead of enlarging the assignment.
Containers close only when every explicitly named member passes. Required human,
physical-device and native-hardware checks stay open until actually performed.

Report **goal → visible result → status → proof → remaining blocker → elapsed
time → next action**. Definitions, validators, tests and commits are not a project
percentage. The inventory has337 records, including definitions and containers;
that is not a remaining implementation count. PLAN-NEXT stays open until every
source-resolvable acceptance field is supplied. Exact current gaps remain in the
[existing contracts](docs/ROADMAP_BACKLOG.md#remaining-contract-gaps--plan-next).

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

**Delivered — COMBAT-COURIER ordinary escorted withdrawal/home member.**
Source7f23a808c adds the existing runner's `courier-escorted-withdrawal` selector
and read-only chronology/retirement observations. First packaged ordinary-input
run passes59.024s under original300/330s limits: real34 damage leaves Courier44/78,
both escorts admit after2.4physics seconds, same-player lethal17 defender hit
causes WITHDRAWN, all three actors remain retired through strict occupied home/
OFFLINE/physicalE exit. One withdrawal count; no payment claim. Both escorts
are observed live/registered before the defender kill, not staged into the test.

303 driver tests,3627 privacy assertions, fresh paired exports, three strict menu
startups and full1529-entry/nine-predicate package audit pass. No product/source
correction or repeated game run. Independent full raw-chronology review GO;
860 terminal-through-end records retain retirement. Original09:33:43UTC clock,
60minute estimate and11:03:43 hard stop stay charged through cleanup/push.
[Exact result and scope](docs/history/ROADMAP_DELIVERIES.md#ordinary-escorted-courier-withdrawal-accepted-20261027).
Normal UI Quit/gameOS0, post-exit walking, rendered/native GPU/physical input and
full encounter/loss/repeat/recovery/final qualification remain open. Existing
accepted recovery/source results remain in delivery history; no unchanged rerun.

**Next candidates name concrete capabilities.** These are existing
owners and dependencies, not simultaneous assignments or parked-run approvals.
Select only one after its required inputs and acceptance values are fixed.

| Existing goal | Concrete deliverable | Decisive proof / remaining prerequisite |
| --- | --- | --- |
| LINUX-LAUNCH-DIRECT / LINUX-LAUNCH-DESKTOP | Add rendered direct and genuine desktop-entry launch modes to the existing Guided runner, with verified installed process identity and owned cleanup. | [Full route, CAP300, normal UI OS0, both clean markers, unchanged installation](docs/ROADMAP_BACKLOG.md#rendered-installed-launch-capability). One complete rendered Guided journey per launch method; original GUIDED-FINAL3/3 remains separate. Source checks cannot close rendered/final qualification. |

**PLAN-NEXT remains OPEN.** The source-resolvable gaps in the existing337 records
are unfinished work. No new inventory, definition count or blocker list can close
it. Complete each missing finite action/endpoint/limit/proof in its existing row;
external dependencies require the exact answer/artifact and owner. All36 parents
and ten phase exits remain binding. This cleanup makes concrete implementation
seams visible; it does not declare every contract ready or any product gate passed.

Recent accepted and parked results, exact costs and cleanup records are retained
in [delivery history](docs/history/ROADMAP_DELIVERIES.md#roadmap-status-notes-retained-from-2026-10-27).
Completed work is not the active queue. Latest playable checkpoint is7f23a80.

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
