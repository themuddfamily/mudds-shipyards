# Development roadmap

**Playable alpha; full original scope remains unfinished.** Latest Windows build:
[1d095ad checkpoint](builds/windows/MuddsShipyards-1d095ad-checkpoint.zip)
([changes and validation](builds/windows/MuddsShipyards-1d095ad-notes.txt)).
Matching [Linux checkpoint](builds/linux/MuddsShipyards-1d095ad-linux-x86_64.tar.gz)
([Linux validation](builds/linux/MuddsShipyards-1d095ad-linux-notes.txt)) is available.
Bulwark now rejects empty siege-lance ammunition before starting a charge and
clears any stale charge; its console shows AMMUNITION EMPTY instead of a stuck
CHARGING100%. The isolated fix passes13 regression checks,303 existing Python
checks,3627 privacy assertions and fresh paired export/startup/archive checks.
The full ordinary pilot/gunner/home driver remains parked and unqualified.
Recovery crash-log writes still retry once per second;
successful ordinary store saves cannot postpone publication. Retries stop after
success or clean shutdown. Source checks and packaged startup/parity pass; actual
OS-crash recovery remains unqualified.
The recovery card also offers **Use Safe Audio** after repeated unfinished
startups. It saves master50%/music0 through the existing adapter, preserves other
preferences and retains the existing stable Restore/user-edit protections.
Earlier journey results retain their original source/package scopes;
they were not rerun for1d095ad.
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

Every executable goal uses this short contract in its existing backlog row or
linked section. Broad parents retain their finite child lists and close only
when those children pass; they are never selected as one coding task.

| Field | Required content |
| --- | --- |
| Goal | Existing ID and one observable player or build result |
| Start | Exact source/package, saved state, location and participants |
| Action | Literal command or ordered ordinary player steps |
| Pass | Observed endpoint and expected value for every included case |
| Proof | Actual log, screenshot, artifact or physical observation; identify its environment |
| Prerequisites | Existing IDs and required results, or the exact missing answer/artifact and owner |
| Budget and stop | Estimate, absolute deadline, original test limits, correction allowance and independent abort |
| Close | PASS/FAIL/BLOCKED/PARKED; merge/push accepted work, checkpoint when required, owned cleanup |

A missing command, endpoint or criterion makes the goal **BLOCKED definition**.
An unavailable decision/device makes it **BLOCKED input**. Neither enters the
implementation queue. A definition task supplies only that exact missing field
in the same contract and stops; it cannot expand into a new roadmap audit.
“Improve”, “polish”, “finish” or “usable” without a linked literal check is not a
ready assignment. Existing full-journey and hardware gates keep their limits.

Include owned files in the starting point and preserved state in the pass
criteria. A repair must reproduce the old failure and pass after the change.
Estimate implementation, checks, required checkpoint, integration and cleanup
together at no more than90minutes; split larger production capabilities before
starting. Default correction allowance is one. Full journeys and soaks retain
their original durations even when implementation is split.

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
Source/notes are pushed; owned branch/worktree/route/profiles/scratch removed
after verified preservation. Closure28.465minutes versus60estimated, with final
notes/push charged to this same clock.

**PARKED — rendered installed direct/desktop launch.**
Candidate121580670 is unmerged. The first candidate failed on the observer's
viewport API call. Its sole correction passed compilation, exports, strict menu
startups and package audit, but actual rendered direct launch then timed out
before any gameplay observation:301.195s under CAP300 (302.562s outer under330).
No post-exit walk, PNG, normal UI shutdown or clean markers were established;
desktop launch is NOT_RUN. Root cause is unknown. All owned process cleanup flags
pass and installation bytes remain unchanged. The latest playable build remains
7f23a80. [Terminal result and preservation](docs/ROADMAP_BACKLOG.md#rendered-installed-launch-capability).

**PARKED — COURIER-RECOVERY cold pilot recovery capability.**
Unmerged candidate229bfa6c9 passes source review,313 Python tests,3880 privacy/
observer-compilation assertions, paired exports, three strict menu startups and
full1529-entry/nine-predicate package audit. The actual once-only route fails
42.371s into leg1: four targets destroyed/first Courier running78, but defender85
and no confirmed wounds instead of required17/two wounds. Acknowledged fire
caused no observed damage; why is unproven. No committed interruption/cold Resume
was reached. Sole correction had already fixed the focused Resume-input failure;
allowance0 means PARK with no further repair/retry. Cleanup flags pass; private
candidate/source/results are verified archived, owned branch/worktree/profiles/
scratch removed. No failed code merged or public checkpoint replaced.
[Exact result and reopening boundary](docs/ROADMAP_BACKLOG.md#courier-intercept--bounded-outcomes).
That attempt is closed; latest playable build7f23a80 remains unchanged.

Reopening the parked launch work requires causal evidence about the startup
stall in its original environment and an explicit cumulative-cost decision;
its exhausted correction allowance cannot be reset by another card or branch.

**Delivered — INSTALL-LINUX-UNINSTALL executable lifecycle command.**
Source62810ebf5 adds the existing full transaction as one repeatable release
command. Its once-only checkpoint7f23a80 run passes101.196s: shipped-manager
install/uninstall/repeat/fresh-generation reinstall, strict startup, full ordinary
Guided55.388s/normal HUD OS0/both clean markers, then final uninstall. All five
protected files remain byte/mode exact, including the real8655byte earned Heavy
save; inputs stay unchanged and owned processes are reaped. Installer work22.249s
under120; original game/child limits retained.25 tests and independent full raw
review pass after the one retained initial correction. No gameplay or graphics
change/new public build; latest playable checkpoint remains7f23a80.
[Command, actual proof and retained limits](docs/ROADMAP_BACKLOG.md#final-linux-uninstallreinstall--install-linux-uninstall).
Final-candidate, graphical desktop launch, retained-save gameplay reload and
native/human gates remain open. Original11:12:09UTC/60minute estimate/12:12:09
hard stop include integration/push/owned cleanup. Source is pushed; branch/
worktree/install/profile/scratch cleaned after verified preservation. Closure
18.007minutes through cleanup; final notes/push remain on that clock. No new
implementation selected.

**Defined — HUD-PATROL durable fields and ordinary callers.**
Frozen source0e3b58a25; original11:35:01UTC/20minute estimate/hard11:55:01UTC.
Bound exact saved state/reward fields, reset→branch choice→start/cold-Main values,
button rules and existing source/fixture commands. One read-only source agent;
root owns review/docs/commit/push. No engine, parked trial, new UI or gameplay
repair selected. Existing physical home reboarding already resets terminal Patrol;
branch selection before departure and normal free-flight Start are production
callers. [Literal contract](docs/ROADMAP_BACKLOG.md#hud-patrol-contract). Ordinary automation/
whole-sequence limit/cold observations remain open. No branch/worktree/process/
scratch created; 7.606minutes through source review/checks, with final
commit/push charged to the same20minute clock.
The separate Titan design question is pending; no missing-craft build is authorized
by elapsed time or this definition work.

**Delivered — Bulwark empty-magazine charge/readout repair.**
Source1d095ad93 contains only the runtime guard, focused test and import UID.
Zero ammo now clears/refuses a charge and displays the authored AMMUNITION EMPTY
warning; positive-ammo timing and authority gates remain unchanged.13 regression
checks,303 existing driver tests,3627 privacy assertions, fresh Windows/Linux
exports, three strict menu startups and full1529-entry/nine-predicate artifact
audit pass. Independent source/raw/artifact review GO. New playable checkpoint
1d095ad is available above; native Windows/GPU/audio/human gates remain open.

The combined ordinary driver1b5649cc2 is PARKED at its CLI-order test failure,
without an export/native run; no failing test was changed or waived. Its five
private driver/observer/startup/privacy files are excluded and verified archived;
owned branch/worktree/scratch removed. Publishing the independently tested runtime
repair does not accept the full ordinary gunner journey or craft. [Proof and
source separation](docs/ROADMAP_BACKLOG.md#bulwark-ordinary-gunner-member).
Both scopes keep the original11:43UTC/90minute clock/hard13:13/execution end13:03
and exhausted correction allowance through integration/push/cleanup. Both task
branches/worktrees/private caches/build duplicates are removed after verified
preservation. Shared cleanup42.885minutes versus90estimate; final notes/push
stay on that original clock.

**Selection rule:** use the latest canonical State and linked terminal result.
Reconcile contradictions before selecting work. An already-fixed source binding
is reused; missing executable caller support becomes a production capability,
not another survey of the same members.

**PLAN-NEXT remains OPEN.** The source-resolvable gaps in the existing337 records
are unfinished work. No new inventory, definition count or blocker list can close
it. Complete each missing finite action/endpoint/limit/proof in its existing row;
external dependencies require the exact answer/artifact and owner. All36 parents
and ten phase exits remain binding. This cleanup makes concrete implementation
seams visible; it does not declare every contract ready or any product gate passed.

Recent accepted and parked results, exact costs and cleanup records are retained
in [delivery history](docs/history/ROADMAP_DELIVERIES.md#roadmap-status-notes-retained-from-2026-10-27).
Completed work is not the active queue. Latest playable checkpoint is1d095ad.

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
