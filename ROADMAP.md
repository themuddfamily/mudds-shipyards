# Development roadmap

**Playable alpha; full original scope remains unfinished.** Latest Windows build:
[2456552 checkpoint](builds/windows/MuddsShipyards-2456552-checkpoint.zip)
([changes and validation](builds/windows/MuddsShipyards-2456552-notes.txt)).
Matching [Linux checkpoint](builds/linux/MuddsShipyards-2456552-linux-x86_64.tar.gz)
([Linux validation](builds/linux/MuddsShipyards-2456552-linux-notes.txt)) is available.
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
| Stop | Estimate including checks/build/cleanup; first-failure stop; cumulative cost of prior attempts. |
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
split larger production changes before starting. Complete journeys/soaks retain
their original durations. A failed estimate is reported as an overrun against
the same goal. A discovered prerequisite stays charged to that goal; a new
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

## Execution now

**Selected SAVE-UNSUPPORTED: ordinary packaged future-envelope refusal.**
This delivers an executable release check, not a new save policy or completion
of all unsupported-format/recovery cases.

| Field | Frozen assignment |
| --- | --- |
| Result | Drive the actual packaged Settings Save and Reset controls against one future outer-envelope case, quit normally, cold-reopen the same data and show usable ordinary continuation without changing protected files. |
| Start | Base9c4684133; owned branch/worktree `roadmap/unsupported-save-ui-20261026`, `/srv/mudds-work/unsupported-save-ui-20261026/worktree`. Implementer owns native-sortie Python runner, its existing tests and passive observer only; root owns docs/export/installation/checks/cleanup. Valid supported fixture is the accepted9296-byte Heavy raw save, SHA256 af2fada0a687b3a2dad6ee5c4550d4e6cd92120f2df94f6681f053e5b23ed409. It is protected file content, not loaded progress when a future envelope blocks load. |
| Steps | Existing source-case placements are primary, temporary or backup, one per invocation. Selected native run is primary only: seed supported primary/backup, replace primary prelaunch with the source case's opaque schema2 envelope; `.tmp` remains absent. Begin Shift with real OS input; pause/open Settings; focus APPLY + SAVE and press Return; then RESET DEFAULTS and actual CONFIRM RESET; close Settings and normal HUD Quit/OS0. Distinct process/same ELF and profile cold-loads again, begins ordinarily, walks the existing retained continuation points (-8.5,.18,6), (8,.18,6), (8,.18,-24) using the unchanged support/motion/arrival/speed/settle checks, then normal HUD Quit/OS0. |
| Pass/fail | Both loads fail closed with newer_schema, source none/generation0/empty live rewards/default live settings. Save fails store_load_failed/store_reason newer_schema, visible `UNSAVED  //  STORE_LOAD_FAILED`; confirmed Reset applies live defaults but fails persistence with visible `DEFAULTS ACTIVE  //  SAVE FAILED`. Primary/backup names, bytes and0600 modes, absent temporary, and unrelated0640 sentinel remain exact at boot, each refused action, both exits and cold load. No fake healthy startup, backup adoption, destructive repair, StartFresh or injected game state. |
| Proof | Existing focused Python suite plus CLI/privacy checks, actual passive Main observer check if required, clean pinned Linux export, actual installed strict `--startup-check` exit0/exactlyone STARTUP_MENU_READY_OK and one full new native command. Two genuine OS processes, actual UI focus/action/results and independent disk reads; all owned game/input/display processes reaped. Native Windows/GPU/physical device facts remain NOT_RUN. |
| Dependencies | Source4b66b3548 already proves the three placements through real-file Store APIs; reuse that fixture contract. Current nested-settings source map stays closed. Independent source review freezes exactly once EACH per OS process: `Startup could not read stored settings: store_load_failed` and `Atomic runtime settings load retained authored defaults: store_load_failed / newer_schema`. Retain both raw warnings, require exact counts after final output drain, reject every other diagnostic; old routes remain unchanged. Save attempt count rises once per Save/Reset, save success and commit serial remain0; the misleading accepted_transaction_count may increment for refused requests. |
| Logging | Pinned engine source enables desktop file logging in `user://logs`; the new route alone redirects each leg to an owned absolute output log. Strict save-directory membership stays unchanged. Actual package source755ad605a is reused with the updated Python driver: only Python/tests/docs differ; the game/observer payload is unchanged. [Engine source](https://raw.githubusercontent.com/godotengine/godot/a13da4feb8d8aefc283c3763d33a2f170a18d541/main/main.cpp#L2312). |
| Stop | Whole case starts20:59:20UTC2026-10-26; estimate70minutes including checks/archive/push/cleanup, hard22:29:20UTC90minutes. Existing native CAP300, independent330 and installed transaction360 retained. Stop on first unexpected failure; no correction/retry without demonstrated cause and independent cumulative-priority decision. |
| Closure | Integrate/push accepted executable capability only on actual review/validation; do not merge failed candidates for cleanup. Archive raw/source/private diagnostic package, remove owned branch/worktree/process/helpers; latest gameplay checkpoint2456552 stays unless an actual runtime change warrants a new paired checkpoint. Record only proven placement/source/package scope; other placements and formats stay open. |


**Completed: five retained detached worktrees cleaned up.**
All five inactive copies are removed after preserving and verifying their local
source changes. Only the main worktree remains registered; sibling diagnostics
and earlier archives are retained. [Exact paths, preservation and checks](docs/history/ROADMAP_DELIVERIES.md#five-retained-worktrees-closed-20261026).
This is repository housekeeping, not gameplay or release qualification.

**Accepted executable recovery caller; full installed qualification PARKED.**
The paused-schema correction now drives actual keyboard Settings repair, normal
first OS0, cold session3 with Heavy credit1/settings/paid posting and all three
walking goals52.593m. The unchanged gate then rejects two root-window signal
errors during second shutdown; final OS0/clean-file acceptance remains unproven.
[Implementation acceptance and exact failed qualification](docs/history/ROADMAP_DELIVERIES.md#corrupt-repair-caller-accepted-shutdown-gate-open-20261026).
The corrected caller/read-only observer are integrated as a release capability;
no runtime error is suppressed and no further trial/fix/probe is selected. Full
INSTALL-LINUX-CORRUPT remains open. Latest accepted playable build stays2456552.
A [bounded source pass](docs/history/ROADMAP_DELIVERIES.md#popup-parent-connection-source-boundary-20261026) identifies the matching native Popup cleanup pair;
the concrete runtime popup and cleanup order remain missing. No engine/application
patch or additional trial is selected from that source pattern alone.
The subsequent passive owner-capture preparation missed its20:51UTC launch
cutoff. No import/export/game run occurred; the unmerged diagnostic source and
inputs are archived and its owned branch/worktree/helpers removed.
[Preparation stop and retained source](docs/history/ROADMAP_DELIVERIES.md#popup-owner-preparation-cutoff-20261026).

**Accepted: backup-repair restart guidance, checkpoint2456552.**
Confirmed backup repair now tells the player to quit and reopen the game when
startup recovery was blocked. The actual Settings label passes at1024×768 and
requested UI1.6;80source assertions,16actual Windows-payload assertions, paired
exports/three strict startups and actual1529-entry payload audit pass. [Result and scope](docs/history/ROADMAP_DELIVERIES.md#backup-repair-reopen-guidance-accepted-20261026).
Ordinary installed corrupt-data repair/restart and wider recovery qualification
remain open; this closes only the named guidance capability. No next run selected.

**PARKED: retained Heavy data through ordinary Jovian crew recovery.**
The sole new candidate reaches the full chair/forced-stop/cold walk/helm/normal
OS0 journey, but its final protected-namespace check fails: a default race and
its tutorial were added without a live transition receipt. Original settings,
Heavy credit1 and paid terminal remain intact. Independent review upholds PARK;
no second run or blanket data exception. [Failure and exact reopening condition](docs/history/ROADMAP_DELIVERIES.md#retained-heavy-crew-recovery-parked-20261026).
Candidate source/raw/private exports are archived, not merged or published as an
accepted checkpoint. Fresh378d99c crew acceptance stays closed.

**Reduced-motion source definition is closed; ordinary-route binding remains blocked.**
The [eight remaining production consumers](docs/ROADMAP_BACKLOG.md#reduced-motion--finite-production-consumers)
now have literal OFF/ON endpoints and existing focused-suite references. No
runtime gap was demonstrated and no gameplay check was run. Reuse this list;
do not repeat consumer discovery or start a test-only repair. A next selection
must bind an uncovered ordinary caller/candidate/profile/deadline. Accepted
damage/toast/settings proof remains closed; wider rendered/device coverage is open.

**Warm-cache continuation stopped at preparation cutoff; no second render.**
The cold run's complete102-file/5400444-byte Mesa shader cache was recovered
and copied byte-exact into a fresh private profile, with an independent conditional
priority decision. Import passed20.944s. Setup missed the reviewed18:30UTC launch
cutoff; the wrapper refused before Godot Popen. A final timing review upheld
PARK rather than shorten18-original inspection/closure. Cache effect is NOT_TESTED;
no new capture, images, art change or accepted build. Six preparation identities
are absent and its inputs/raw are archived. [Exact preparation record](docs/history/ROADMAP_DELIVERIES.md#hero-warm-cache-preparation-cutoff-20261026).
The original18:01:07UTC/45min/hard18:46:07 and prior cost remain charged. No
further launch window, warm-up, probe, retry or quality/cap change is selected.

**PARKED: full18-frame Torrent hero-cell capture.** One unchanged capture on
frozen2f333b0e4 reaches world/berth/Torrent/pilot instantiation, then its original
300s engine cap expires: exit124, zero PNGs and zero success markers. The interval
after pilot instantiation remains unlocalized; no art/pixel/ROI failure or shader
cause is established. No original-resolution inspection was possible.
[Exact failure and reopening condition](docs/history/ROADMAP_DELIVERIES.md#torrent-hero-cell-original-cap-timeout-20261026).

Forward+/X11/2560×1440 were actually reported with guarded editor7b46e60 and
llvmpipe LLVM19.1.7/Vulkan1.4.305. Source/index/tree/cache and engine/Vulkan pins
remain unchanged; all nine recorded owned identities are absent. This proves
no clean capture shutdown/reflection repair, native GPU/performance or human
review. Existing registry source/image/human stages remain pending unchanged.
No retry, probe, patch, larger cap or lower quality is selected.

Raw commands/environment/cache/diagnostics and the stopped state are in one
verified archive; loose owned records and the detached worktree are cleaned at
closure. No task branch, runtime/art edit, canonical image publication or duplicate
playable build. Original18:01:07UTC/45min includes binding/import/one capture/
review/archive/push/cleanup; archive20.727minutes, final closeout retains total.
Reopen only with a supported causal correction/environment change and independent
cumulative-priority review preserving the original outcome/count/quality/300s.
Do not run another heavy capture as a substitute for this unlocalized failure.

Latest accepted playable checkpoint is2456552, including the [backup-repair restart guidance](docs/history/ROADMAP_DELIVERIES.md#backup-repair-reopen-guidance-accepted-20261026).
The earlier [Jovian cockpit/recovery repair](docs/history/ROADMAP_DELIVERIES.md#ordinary-jovian-engineer-recovery-accepted-20261026) remains accepted within its recorded scope.
Task-selection rules and all337 original records remain binding; no next run is selected.

Recent accepted and parked results are references, not active assignments:

- [Installed retained-save continuation](docs/history/ROADMAP_DELIVERIES.md#installed-retained-heavy-load-accepted-20261026)
- [Checkpoint upgrade](docs/history/ROADMAP_DELIVERIES.md#linux-checkpoint-upgrade-499e681-to-b4ff8c0-accepted-20261026)
- [Installed checkpoint Guided route](docs/history/ROADMAP_DELIVERIES.md#linux-installed-checkpoint-guided-qualification-accepted-20261026)
- [Forward projectile attribution](docs/history/ROADMAP_DELIVERIES.md#forward-hull-projectile-attribution-accepted-20261026)
- [Parked Beacon repetition and causal reopening condition](docs/history/ROADMAP_DELIVERIES.md#beacon-repetition-two-attempt-stop-20261026)
- [Parked Zenith startup failure and causal reopening condition](docs/history/ROADMAP_DELIVERIES.md#zenith-core-repair-startup-failure-parked-20261026)
- [Station view definitions and exact blockers](docs/ROADMAP_BACKLOG.md#station-presentation--finite-review-boundaries)

### Blocked definition work — not an execution queue

At most one implementation assignment may be active. The following rows are
blocked preparation work, not a backlog of runnable implementation tasks.
Use the existing backlog row for each result; do not create another tracker.

The following are **finite definition outputs**, not promises to implement whole
features. Codex owns source-resolvable fields. Each selected definition gets one
15–30 minute pass, then stops with the literal answer or an exact missing input
and owner in that same row. Do not repeat completed source surveys or run games
to discover what acceptance should have been.
An exact missing input ends the attempt as BLOCKED; it does not complete the
definition or its product outcome.

| Existing outcome | Output required before implementation or qualification | Terminal output of this definition attempt |
| --- | --- | --- |
| CRAFT-ACCEPT, one named craft | Ordered uncovered physical/function/damage/recovery/home/reuse/switch/Main steps; each mapped to retained proof or an existing route, expected endpoint and original limit | Every required step has a proof reference or a named unavailable route/input. Accepted Torrent/Arrow steps remain closed; parked failures keep their reopening conditions. One craft per assignment. |
| STATION-FINDINGS, one existing branch/view | One supported camera position/height, source, renderer/quality/resolution/scale and the exact text/access/clearance checks | A frozen view can receive either an inspected no-finding result or one reproducible defect. Use the nine-branch/four-service roster; do not reopen parked captures. |
| ART-FINDINGS | Map the existing 13 capture sets/143 images and original fleet/world/character/effect/UI obligations to accepted coverage or literal missing views | Each uncovered view names its original promise, subject/state and comparison conditions; the station subset is referenced once. No new art obligation inferred from an empty area. |
| SHARED-EMBER-BASELINE | One craft, actual peer roles, outward/surface/home route, survey/result/payment/save endpoints and original limits | One complete ordinary baseline command/route with expected durable data, or the exact missing caller/participant/input. This defines one of the existing 21 cases, not a new shared-world matrix. |
| COMFORT-MOTION / FLASH / COLOUR / CAPTIONS, one family | Flash uses its fixed17-family contract: bind only the named remaining normal trigger/caller; reuse the accepted3649b4b shared native save/three-process/Reset proof and do not redefine consumers. Motion now reuses its [eight fixed source consumers and OFF/ON endpoints](docs/ROADMAP_BACKLOG.md#reduced-motion--finite-production-consumers); only still-unproved ordinary route/candidate/profile/deadline bindings remain. Colour/captions retain their own finite missing fields. | Each missing binding ends in a frozen existing episode or a literal unavailable caller/input and owner. Flash producer/policy definition stays closed; accepted cues remain accepted. No new option or consumer matrix is invented. |
| RECOVERY-CUTS-DEFINE | Only uncovered installed cuts in the existing on-foot/pilot/cabin/bunk/crew/docking/activity/world contracts | Each cut has its committed boundary, expected debt/payment/data, owned kill/restart, supported continuation and original cap; accepted cuts are reused. Four unresolved active-run policies stay owner decisions. |
| INSTALL-LINUX, one existing transaction | Exact prior/candidate package where needed, owned prefix, fixture, protected files, expected bytes/modes and installed usability route | Clean, upgrade, rollback, retained-data, corrupt-data and uninstall remain six distinct existing goals; one transaction per assignment. Unknown package versions block execution, not definition of the required operation. |
| PERF-ROUTES-DEFINE / PERF-CELLS-DEFINE | Bind the seven existing selectors and original world-endurance workload to minimum/target machines and existing measurement budgets | Workload membership, commands and numeric ceilings are literal; missing device access or genuinely unspecified ceilings have a named owner. No extra craft×world×device axes. |

A definition is allowed to resolve a blocked contract. A blocked capability or
qualification is **not** allowed to execute before that contract is fixed.
Repeatedly recording the same unresolved fields is not another completed goal.
If a source-resolvable definition ends blocked, retain the exact missing artifact
and search boundary; reopening needs new information, not a renamed task.

The complete [decision and resource register](docs/ROADMAP_BACKLOG.md#blocking-decisions-and-resources)
is the source for user-owned blockers: eight craft specifications, additional
Bomber roles, capacity/desktop scope, four active-recovery policies, two cargo
replenishment policies, caption overflow, physical hardware/audio access and
release rights/signing/distribution. Each ends with its recorded answer or
artifact; approval does not count as implementation. Already accepted automatic
freight/shared stock/rejection feedback/Beacon 60s/Bomber seat-refill/Defense arm
choices remain settled and must not be asked again.

Completed source qualifications and checkpoint changes belong under
[accepted work](#accepted-work--source-limits-retained), with exact limits.
Failed trials belong under [parked work](#parked-failures-and-dependent-work),
with their first failure and causal reopening condition. Neither is a next task.

### Work order after this correction

1. Select one ready capability, qualification or definition from the canonical
   inventory and state its kind. A capability changes production behavior;
   qualification closes a named original acceptance predicate on a fixed
   candidate; definition supplies one finite missing contract. If a ready
   production capability exists, select it unless a named dependency requires
   other work first. If none exists, finish one bounded readiness pass with exact
   blockers and owners; do not generate a chain of handoffs or discovery cards.
2. Split its production implementation into capabilities estimated at no more
   than90 minutes each. Name each capability's files, observable result and focused
   check before editing. A fleet, world, activity family or final matrix is a
   milestone/container, never one implementation assignment.
3. Deliver and close that capability, then run its retained complete journey when
   its prerequisites hold. A short regression can prove the repair; it cannot
   replace the original full journey, repeat count or deadline.
4. Qualify the stable integrated candidate through the existing release gates.
   Reuse accepted results within their recorded scope. Re-run affected checks when
   code changes invalidate them; do not restart every completed journey by default.

## Turning a goal into one assignment

Use the single [assignment contract above](#how-we-will-work-from-this-roadmap).
Keep one selected card in Execution now; retain accepted and parked contracts
below as references. A smaller regression closes only its named repair. Original
full journeys, repeat counts and deadlines remain separate required outcomes.

### Stop rules that prevent another loop

- Freeze acceptance before editing. Add a case only for an identified uncovered
  original requirement; record why, rather than silently moving the finish line.
- Stop the selected check at its first unexpected failure. Preserve the result
  and source. Diagnose the actual owner; do not build another validator or extend
  the deadline to convert failure into success.
- One attempted repair followed by failure requires a cumulative priority review:
  park/switch, or justify one bounded continuation with a demonstrated cause and
  explicit stop. There is no automatic retry chain.
- Close or park the active card before switching tasks. Preserve unfinished unique
  source. Merge accepted work into main, push, remove completed owned branches and
  worktrees, and release owned processes/scratch. Cleanup is part of completion.
- A meaningful working gameplay/graphics result gets a fresh Windows checkpoint
  through the existing clean-commit workflow. Include actual checks and player
  changes. Documentation/private diagnostics alone do not require an identical build.
- In progress reports state: **goal; player result; accepted/failed/blocked;
  first remaining blocker; elapsed cost; next bounded action**. At closure report
  completed named outcomes and the remaining named milestones. Do not substitute
  assertion counts, evidence versions or commit totals for product progress.

<a id="concrete-pending-capability-ember-surface-loop-captions"></a>
## Accepted work — source limits retained

Recent packaged changes and source qualifications are recorded separately:

| Accepted outcome | Proof and retained limit |
| --- | --- |
| Eighteen live Ember surface-loop captions | [Checkpointb810822](docs/history/ROADMAP_DELIVERIES.md#ember-surface-live-captions-delivered-20261026); controlled owner/reward observations through actual visible HUD, ordinary journey/durable reward/full comfort remain open |
| Three live engine-transition captions | [Checkpoint46bae53](docs/history/ROADMAP_DELIVERIES.md#engine-transition-live-captions-delivered-20261025); actual ledger/rig/visible HUD composition, ordinary flight/full comfort remain open |
| Guided installed normal-exit prerequisite | [Checkpoint 39157e8](docs/history/ROADMAP_DELIVERIES.md#guided-installed-normal-exit-accepted-20261025); one actual direct-ELF flight/normal Exit/OS0, rendered desktop/final 3/3 remain open |
| Sprint/boost option cold restart and Reset | [Three-process proof](docs/history/ROADMAP_DELIVERIES.md#sprint-toggle-cold-process-qualified-20261025); source composition, physical devices/boost flight/original Settings return remain open |
| Interact remap, conflict Cancel and cold Reset | [Three-process proof](docs/history/ROADMAP_DELIVERIES.md#interact-remap-restart-qualified-20261025); synthetic raw input, not physical devices or original Gate C |
| Four final-approach captions | [Checkpoint 4aa8b64](docs/history/ROADMAP_DELIVERIES.md#final-approach-live-captions-delivered-20261025); composed visible HUD, ordinary planetary flight and full comfort acceptance remain open |
| Five Loadmaster captions | [Checkpoint 19336f3](docs/history/ROADMAP_DELIVERIES.md#loadmaster-live-captions-delivered-20261025); rejection has component proof only, with [no demonstrated reachable requester refusal](docs/history/ROADMAP_DELIVERIES.md#loadmaster-refusal-readiness-not-selected-20261025) |
| Current damage Reduced flash | [Checkpoint 1a948d9](docs/history/ROADMAP_DELIVERIES.md#current-damage-reduced-flash-accepted-20261025); accepted active-cue episode; shared native save/cold/Reset now DONE3649b4b, remaining family/device/final gates open |
| Current toast and damage Reduced motion | [Toast](docs/history/ROADMAP_DELIVERIES.md#current-toast-reduced-motion-accepted-20261025), [damage](docs/history/ROADMAP_DELIVERIES.md#active-damage-reduced-motion-accepted-20261025); accepted episodes, not all consumers/device/final gates |
| Combat terminal posting durability | [Exact delivered behavior](docs/history/ROADMAP_DELIVERIES.md#combat-terminal-posting-persistence-accepted-20261025); preserves genuine next posting and pending-write refusal, ordinary complete combat journeys remain open |
| LAN expiry and retry | [Checkpoint ca149d6](docs/history/ROADMAP_DELIVERIES.md#lan-browser-expiry-accepted--2026-10-25); paused monotonic 30-second expiry/fresh admission, not full network/endurance acceptance |

Other accepted child outcomes include
[shared Main source lifecycle](docs/history/ROADMAP_DELIVERIES.md#shared-main-source-lifecycle-accepted-20261025),
[physical Torrent–Arrow handoff/reclaim](docs/history/ROADMAP_DELIVERIES.md#torrent-arrow-physical-handoff-accepted-20261025),
[Torrent incoming core damage/passive repair](docs/history/ROADMAP_DELIVERIES.md#torrent-core-damage-passive-repair-accepted-20261025),
[Torrent packaged return/reuse](docs/history/ROADMAP_DELIVERIES.md#torrent-return-reuse-capability-accepted-20261025),
[six Settings extreme-scale/scroll component views](docs/history/ROADMAP_DELIVERIES.md#settings-4x3-extreme-views-inspected-20261025),
[corrupt-primary read-only fallback and continuation](docs/history/ROADMAP_DELIVERIES.md#corrupt-backup-read-only-fallback-accepted-20261025),
[Central walking/launch/home](docs/history/ROADMAP_DELIVERIES.md#central-station-accepted-proof-reused-20261025),
[Hauler conserved delivery](docs/history/ROADMAP_DELIVERIES.md#hauler-supply-first-play-accepted-20261025),
[Race and home](docs/history/ROADMAP_DELIVERIES.md#race-first-play-accepted-20261025),
[Patrol relay](docs/history/ROADMAP_DELIVERIES.md#patrol-relay-first-play-accepted-20261025)
and [browser join/solo walking](docs/history/ROADMAP_DELIVERIES.md#browser-join-supported-walking-20261025).
They stay accepted for their recorded source/route. Their cold/repeat/device/final
candidate requirements remain separate; no automatic unchanged rerun is selected.
Full chronological results belong in the existing
[delivery history](docs/history/ROADMAP_DELIVERIES.md), not the execution queue.

## Parked failures and dependent work

<a id="zenith-torrent-handback-parked"></a>
### Zenith→Torrent→same Zenith handback — accepted continuation; failures retained

**QUALIFIED in the exact accepted scope:** Game`499e6816f53f3e5a2b16bc74c808b447cc248661`,
caller`8ba86d98efbaf8f4312276db803f77824bfd6ec6`; full exported ordinary route162.917s/actualOS0,
42walking goals/280.899735m, actual Guided and same-Zenith fresh reclaim. The first
four failed runs remain failed; the accepted physical repair and caller detour
are recorded in the [delivery](docs/history/ROADMAP_DELIVERIES.md#zenith-torrent-handback-accepted-20261026).
No unchanged rerun or further trial is selected.

| Trial | Actual elapsed | First failed predicate |
| --- | --- | --- |
| 1, original driver | 56.682s | Corner cut after wing-clear: both floor rays false at2307/2308; existing safe-corner steering/settling subsequently reused without changing points or checks. |
| 2, corrected corner | 67.867s | Stair-base sprint: grounded/support true, but ~0.1552m horizontal plus0.1668m descent gives3D~0.2278m above unchanged0.21167m guard. No solver allowance was added. |
| 3, normal authored walk | 68.320s | At2938 Player loses grounded contact while both probes still see StairBaseLanding; actual horizontal gait≈5.8m/s. Support/grounding requirements reject the run. |
| 4, repaired stairs | 91.991s | All reverse0–11 pass; reverse12 hits the real Central cargo crate and stops at the original15s goal limit. No game defect or larger deadline accepted. |
| 5, safe cargo detour | 162.917s | PASS full original handback, every old destination retained plus four safe lane waypoints; real Guided, strict home/OFFLINE/exit, same-Zenith90freshneutral, normalHUDOS0 and clean durable state. |

Each correction received independent causal/cumulative-priority review. Exact
prior failures remain failed. For the first three archived trials,241 Python
regressions pass in that old source scope, including the
failed sprint sample still being rejected. Import/privacy/observer parse, paired
exports, three strict startups and1,529-entry actual payload audit pass in their
recorded scope; only Boot/observer compiled scripts differ from3649b4b. An earlier
observer-helper scope parse failure and its three-line fix are retained too.
Driver-only corrections reused exact f28f923 game bytes and runtime checks; no
identical re-export or accepted gameplay/handback result is inferred.

**Previous reopening condition satisfied.** Accepted1f7dccb proves continuously
grounded/support/current3D/epoch/no-placement traversal at the captured stair.
After independent priority review, trial4 passed it and exposed the caller's
horizontal shortcut into the real cargo crate. Its actual east face plus capsule
radius/margin predicts the recordedx−1.649388 stop with W+Shift held. The Python-
only detour uses the establishedz13.5 Freight lane, preserving every original
goal/guard/cap; independent review and242 Python/reuse checks precede trial5.
Exact499e681 game/export/startup/payload bytes are reused. The complete route is
now qualified; a later source change invalidates only its affected predicates,
not every previously accepted craft outcome. No new retry is queued.

The following archive/cleanup facts describe the first three failed trials:

All21 supervisors/79 observed owned process identities are absent. Inputs and
input helper/game/Xvfb were released/reaped in every failed trial, with zero game
diagnostics. Verified source bundle, all failures/raw observations and8 exact
unaccepted build files are preserved in
`/srv/mudds-work/zenith-torrent-handback-20261026/records.tar.gz` (374057008bytes;
SHA-256 `3b0f4c10bc8c47bd89d2df19abe1ae26c89b23a2138159e24a62b6f2c7e8692c`;
295regular files/21links, complete content/mode/link/membership verification).
Owned branch/worktree and loose scratch are removed after exact ownership/tip
checks and archive verification; the remote task branch was absent. Only `main`
remains locally. Unrelated detached diagnostic/profiler/station worktrees and old
prunable `/tmp` registrations are retained. No code from that archived candidate was merged and no checkpoint was published
at its closeout;3649b4b was current then. The separately accepted Aft checkpoint
1f7dccb is current above. Closure preparation cost
59.632minutes from09:51:00UTC against90minute estimate; final docs/push stay
on that clock. Full Zenith, other craft/world/network/release and external gates
remain open; earlier accepted Zenith results stay accepted.

**Accepted frozen handback contract — original result and limits retained.**

- **Goal:** existing CRAFT-ACCEPT-ZENITH cross-craft handback member, implemented
  as `run_native_sortie.py --route zenith-torrent-handback` and actually proved.
  Existing Zenith flight/hit/two-home/reuse/settled-Main results stay closed.
- **Starting state:** clean integrated candidate descended from `433a9ded7`,
  exact source and embedded native Linux package recorded before execution;
  fresh owned profile, normal Boot/Begin Shift, nine real craft and authored
  tuning/default command samplers. No source/pack/script override or staged poses.
- **Actions:** reuse LIFE-ARM's fifteen goals/physical canopy boarding/90 seated
  observations; Zenith stays home/OFFLINE. Release then ordinary E exits the
  docked Zenith without flying it. Walk live-home-relative port(-7.2,-1.08,3.9)
  and clear(-1.6,-1.08,5.9) points, >7m/cleared reboard block. Reverse the known
  path below; board Torrent through its live current candidate. Complete actual
  Guided launch→four range drones→defender→return→L/strict home, 90 consecutive
  neutral/OFFLINE observations and physical exit, exactly once. Clear Torrent's
  reboard block radially, reverse the central connector, repeat the fifteen
  outward ARM goals and physically reclaim the same original Zenith. Observe
  90 fresh neutral seated ticks, then normal HUD Exit/actual OS0.
- **Walking route:** from Zenith wing-clear use (x,y,z)
  `(22,4.2,68.3)→(13,4.2,68.3)→(6,4.2,68.3)→(-3.5,4.2,68.3)→`
  `(-3.5,4.2,64.2)→(-3.5,4.2,61.5)→(-5.7,4.2,61.2)→(-5.7,0,51)→`
  `(0,0,51)→(0,0,46.3)→(0,0,39)→(0,0,15.5)→(0,0,13.5)→`
  `(-8.5,0,13.5)→(-8.5,0,15.5)→`
  `(-8.5,0,13.5)→(-8.5,0,live Torrent ExitPoint.z)→live Torrent candidate`.
  After Torrent exit reuse existing radial-clear target
  `player + max(4,8-horizontal_distance_to_boarding)*unit(horizontal_player_minus_boarding)`;
  store that live target. Connect via `(-8.5,0,clear_target.z)→(-8.5,0,13.5)→`
  `(-8.5,0,15.5)→(-8.5,0,13.5)→(0,0,13.5)→(0,0,15.5)`, then unchanged outward ARM_GOALS. Existing Zenith
  corner x≥20.30/z≤59.20 stays binding; all reverse/connector destinations pass in the accepted scope.
- **Pass/fail:** same Main/Player/both hulls, registered1104/1101, seats/cameras/
  areas/berths and authored resources/tuning. Only current occupied craft owns
  pilot/input/camera; exited sources retire, remain neutral/pending0, and fresh
  Zenith stream is greater than its retired epoch, with actual E producer and
  lifecycle-consumer receipts. Zenith remains intact/home/OFFLINE throughout;
  Torrent genuinely releases lease, completes required Guided, restores exact
  strict home lease/OFFLINE and physically exits. All walking is supported and
  actor-current; fresh Zenith claim consumes a new current neutral stream.
  Require normal HUD Quit exit0, both durable clean markers, real files and no
  diagnostics, tracked-source mutation, input capture or surviving owned children.
- **Proof:** exact embedded exported ELF on owned Xvfb, explicit x11 and Dummy,
  OS XTest input into default production samplers; existing native runner records
  raw observations/commands/source/package hashes, actual file/identity/claim
  endpoints and `NATIVE_ZENITH_TORRENT_HANDBACK_OK`, after actual OS0/reap. Focused
  existing Python driver/privacy/observer checks, paired exports, three strict
  startups and actual payload audit precede one whole-route trial.
- **Dependencies and limits:** implement exact selector/orchestrator/observer and
  reviewed fixtures. Guided is mandatory; never force phase/complete flags or
  skip targets. Existing Guided Pilot uses the whole CAP300, with no additional
  per-phase deadline; retain it. Walking15s/goal, boarding12s, initial Zenith
  exit10s, Torrent radial clear12s, real Hero landing timeout/independent4s stall,
  whole-game300s/outer360s remain. Admission's90 neutral observations count once;
  add no duplicate stable wait if they already prove the same consumer condition.
  Native GPU/physical devices/rendered/human/full-craft/final gates stay NOT_RUN.
- **Stop and closure:** estimate90minutes from2026-10-26 09:51:00UTC, including
  readiness, implementation, checks, failures, checkpoint, push and exact owned
  cleanup. Stop at first unexpected failure; no automatic retry or cap/clock
  reset. A later trial needs demonstrated cause and independent cumulative-
  priority review. Failed unaccepted source/binaries are archived, not merged to
  delete a branch. Successful caller/actual journey gets a fresh checkpoint,
  accepted card/backlog update, regular push and branch/worktree/scratch cleanup.




| Existing goal | Specific reopening requirement |
| --- | --- |
| PLAY-CONVOY[ordinary packaged driver] | Source7952127 is unvalidated and archived; corrected Python suite never launched. Fresh per-attempt profile namespace plus reuse preflight, then independent cumulative-priority selection with full original route/CAP300/outer360/75min accounting; no third under the closed card. [Two stops](docs/history/ROADMAP_DELIVERIES.md#convoy-ordinary-driver-two-stops-20261026) |
| CRAFT-ACCEPT-JOVIAN[ordinary solo engineer] | Correct the source-contradictory still-attached authority predicate and log each post-stand member; independent source/cumulative review before any future selection. Both actual trials stop; no third under the closed card. Preserve full physical return/UI0 and original300/360/15s limits |
| WALK-AFT | Bind the actual frozen Player completed-motion receipt in paused observation; last unpaused observation can lag one tick. Preserve full journey/original 60min cumulative clock/300s and360s caps; independent source GO and priority review before any new trial |
| PLAY-TORPEDO | Retain cancelled request debt across unread queued neutral samples after OS release; source GO and cumulative priority review before checks; full Heavy/Torpedo/Wing finish unchanged |
| PLAY-PATROL[platform_sweep] | Localize normal quit failure; five holds/payment/home/exit already observed but UI exit0/save closure missing. Original300s remains |
| PLAY-DEFENSE | Demonstrated control/gameplay correction for the recorded two-of-four clear; no arbitrary longer fight |
| COMBAT-WING | Demonstrated cause/correction for eight shots causing zero damage; no unsupported aim tuning |
| Other parked rows | Their exact recorded cause, original case list/cap and reopening predicate in the canonical backlog; no unchanged retry |

Unaccepted Torpedo source and helpers are consolidated in
`/srv/mudds-work/torpedo-boat-control-20261025/results/case-records.tar.gz`;
adjacent `closeout.json` records the verified archive/hash, preserved original
clock and cleanup. Source review stopped the sole correction before any tests,
engine, export or whole trial. The Torpedo candidate stays unmerged; transport checkpoint4afd529 now supersedes
0d77125 without accepting Torpedo. [Exact blocker and retained full journey](docs/history/ROADMAP_DELIVERIES.md#torpedo-control-continuation-stopped-at-source-review-20261025).

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
