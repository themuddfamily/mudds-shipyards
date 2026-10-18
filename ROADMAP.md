# Development roadmap

**Next task: correct the client ownership reader, then qualify the original shared return once.**
The game is a playable development alpha. **36 broad requirements and all ten
phase gates remain open.** This file is the execution queue. The
[named backlog](docs/ROADMAP_BACKLOG.md#concrete-child-outcomes) preserves remaining
scope, the [36-parent crosswalk](docs/ROADMAP_BACKLOG.md#coverage-of-the-original-remaining-outcomes)
prevents omissions, and the [original specification](docs/history/ROADMAP_SCOPE_20261017.md)
remains binding. Actual source-specific results belong in the
[existing delivery history](docs/history/ROADMAP_DELIVERIES.md).

## Progress you can assess

| Delivered outcome | Accepted scope / remaining limit |
| --- | --- |
| Passenger chair and pilot/passenger HUD repairs | Integrated. Crew-label source b6196a19a resolves craft labels through the actual occupied chair. |
| Immediate client landing-edge repair | 2c73494a4, integrated on eaac8a432: old-runtime regression reproduced, repaired command delivery40 and ship commands79 pass. Ordinary return remains unqualified. |
| Playable Windows/Linux checkpoint **2c73494** | [Windows notes](builds/windows/MuddsShipyards-2c73494-notes.txt), [Linux notes](builds/linux/MuddsShipyards-2c73494-linux-notes.txt). Safe exports, three strict menu startups and actual payload/archive checks pass. |
| Ordinary two-client Jovian boarding | fff5f7221: normal approaches, both actual seats, current identities/HUD/authority and host confirmation; all three peers exit 0. |
| Ordinary shared departure and braking | 96c96312f: host physically moves 5.004m, frees berth and stops; both clients remain seated/current. |
| Four-cycle phantom cleanup and twelve-cycle all-nine reuse | d7be01487: both source qualifications pass. Staged/headless source scope; packaged ordinary play is separate. |
| Browser generation/cancel handling and defense briefing | Delivered on their recorded sources; broader connection/controller acceptance stays open. |

**Current failed boundary:** original return331a9628b fails client arrival
confirmation after strict physical home docking. Host request serial1, valid
lease, zero dock position/orientation error, speed0 and landed commit generation1
pass. Both clients show matching landed/docked generation1 and zero seat error;
passenger hull error0m, pilot0.473m. The remaining predicate reads the host-only
ownership registry on a client. Failure/raw remain recorded; full return stays
unqualified until the bounded caller repair below passes the original route.

**Unverified:** current full matrix NOT_RUN (last unfiltered f85957f failed 11 of
1,045 suites); native hardware/device/audio, endurance and final release gates
remain open. Native Windows execution and human review retain the owner's
exclusions and factual NOT_RUN records. Focused passes do not replace these gates.

## Current eight-task batch

**4 DONE, 1 FAILED, 3 READY.** The failed return has one explicitly selected
caller-repair follow-up below; it does not reset earlier attempts or repair counts.
These are queue cards, not the remaining whole-project job count. READY definition cards can proceed independently; no parked route is
reopened by this list. Root owns integration and each card unless assigned below.
Implementation and check time are separate; caps are safety limits, not estimates.
Runtime source2c73494a4 is accepted and integrated. Its fresh Windows/Linux
checkpoint2c73494 is published locally with all declared package checks passing.

| Order / task | Type | Status / dependency | Finish | Work estimate; checks separate |
| --- | --- | --- | --- | --- |
| 1. HELM-EDGE-REPRO | Regression qualification | DONE on a3955ee90 | Real immediate landing then neutral physics demonstrates the missing remote serial on the old runtime. | 15–30min freeze/review; import ≤600s, compile ≤300s, one suite ≤300s. |
| 2. HELM-EDGE-REPAIR | Runtime repair | DONE on 2c73494a4 | The same admitted edge reaches the current remote helm exactly once; invalidation revokes it. | 30–60min review/integrate existing patch; focused pair ≤300s each. |
| 3. CHECKPOINT-HELM-EDGE | Playable build | DONE on 2c73494a4 | Fresh paired Windows/Linux packages contain the accepted fix. | 15–25min preparation/artifact work; export ≤900s/platform, startup ≤300s each. |
| 4. NET-JOVIAN-RETURN | Ordinary gameplay qualification | FAILED on 331a9628b; follow-up below | Physical home dock commits and both retained clients consume arrival. | 5–10min compose/freeze; compile ≤300s, one original route ≤300s. |
| 5. HELM-ACTIONS-DEFINE | Scope definition | DONE; source definition only | Finite supported action/binding/consumer/coverage list, with uncovered cases named. | 30min; no engines. |
| 6. RECOVERY-ONFOOT-DEFINE | Scope definition | READY | On-foot durable boundary and usable resume/safe-home outcome are unambiguous. | 30min; no engines. |
| 7. ACCESS-PAUSE-DEFINE | Scope definition | READY | Pause/options views and required scale/aspect cells are named. | 30min; no captures. |
| 8. BOMBER-ROLES-DEFINE | Scope definition | READY | Promised bomber crew/navigation capabilities are matched to actual production owners or explicit gaps. | 30min; no engines. |

**Selected follow-up: NET-JOVIAN-ARRIVAL-CALLER — READY/root.** One test-file
correction reads the client's received ownership section, retaining original
pilot/ship/ownership generations and every arrival condition. Budget10–20min
review/correction; explicit compile300 and one original route300/outer360 separate.
Independent review GO. This is selected over the three independent READY definition
cards because the remaining check demonstrably reads the wrong registry. The
failed run and its two secondary snapshot get_path errors remain retained.
No runtime, input, route, physical tolerance or deadline changes. First further
failure stops for priority review; no extra probe or automatic second correction.

## Card contracts

### HELM-EDGE-REPRO — prove the supported immediate-command loss

- **Parent/result:** parent18, also supporting16/26. In the existing production
  consumer fixture, a real LocalShipInputSource produces an immediate landing
  command through GameFlow's supported InputEventAction path. Later actual
  neutral physics must not erase the required remote serial/wire identity.
- **Boundary:** only the extension to `tests/command_consumer_delivery_test.gd`.
  Preserve the runtime patch separately; clean test-only commit on old runtime.
  The staged confirmed network client is component proof, not ordinary play.
- **Proof:** source publication witnesses the landing-bearing command and later
  distinct neutral physics. The old runtime fails the new exactly-once remote
  serial/`pilot_landing_1` assertion, with no unrelated failures. No manually
  populated physics snapshot, preset counter or injected landing request.
- **Execution:** DONE/root on a3955ee90: compile0, one suite fails only the
  new expected assertion (39 others pass). Initial de787d5 compile failed on two
  bare pause-notification constants; one reviewed Node qualifier repair passed.
  Both attempts/raw and cumulative repair count remain retained. Frozen recipe:
  inspect the held two-file diff, save the runtime
  patch under its owned results, and freeze only the regression on old runtime.
  Cold import ≤600s, compile ≤300s, one existing consumer suite ≤300s using the
  pinned engine/headless/Dummy and original diagnostics. Expected red closes
  this card as reproduced; an unexpected failure stops for review. Do not apply
  a repair simply to hide a fixture failure.
- **Check command:** after the clean import/compile prerequisites, launch the
  existing matrix through the prepared private environment with
  `--mode headless --audio-driver Dummy --jobs 1 --timeout 300 --import-gate never
  --scope tests/command_consumer_delivery_test.gd` and an owned results directory.
  Pin `/tmp/mudds-tools/godot-4.7.1/godot`; retain the 360s outer suite guard.
- **Close:** record exact source/assertion/result in existing history, retain raw
  and runtime patch, commit/push the regression branch. Next action is card 2.

### HELM-EDGE-REPAIR — retain the admitted immediate command exactly once

- **Parent/result:** parents18/16/26; repair GameFlow's supported InputEventAction/
  replay input path so an immediately sampled landing command is retained for the
  confirmed remote helm before later neutral sampling. No native physical-key
  failure is established; do not widen that claim or substitute physical keys to
  hide the supported compatibility-path loss.
- **Evidence/owner:** LocalShipInputSource553 applies then clears explicit edges;
  ShipCommandSource94 retains a detached GameFlow FIFO entry. GameFlow9051–9069
  queues/samples/drains it synchronously. HeroShip660 updates last_ship_command
  only in physics. GameFlow12199–12209 increments remote landing/roll counters
  only from that physics snapshot, and8959 merely shows pending landing feedback.
  On the old runtime no command_produced capture exists in GameFlow. A later neutral snapshot cannot
  recover the already-consumed edge.
- **Boundary/ownership:** root owns `scripts/game/game_flow.gd` and reviews the
  extended existing `tests/command_consumer_delivery_test.gd`. Share one capture/deduplication
  owner between immediate/FIFO delivery and physics polling, or bind a bounded
  equivalent existing delivery seam. Preserve current live confirmed pilot/source/
  authority/stream checks, monotonic sequence and stream initialization, send
  cadence/clock hold/rate limits, session teardown and source invalidation. Do not
  double-count one command observed by both consumers or let an old source edge
  revive after focus/pause/migration/replacement. No wire/schema/authority/input
  timing/pose change and no additional source queue, validator or event framework.
- **Proof:** extend existing production-consumer fixture with distinct immediate
  command and later neutral physics command under a declared staged confirmed
  client session. Exercise actual GameFlow event/FIFO consumer, observe the source's
  produced landing command, and require remote serial/wire identity exactly once
  after later neutral sampling. Preserve claim/source ownership. Repeated polls,
  stale/non-owner snapshots and source/session invalidation must not replay it.
  HELM-EDGE-REPRO must first establish the old-runtime failure; then the same
  regression must pass. Do not pre-set remote counters, inject a network request or replace the immediate path with a
  manually populated physics snapshot. Component staging is not ordinary-route proof.
- **Checks/budget/stop:** review/integration30–60min, clean source before
  engines. Existing command_consumer_delivery_test and ship_command_test on pinned
  engine, Dummy/headless, original300s suite caps; import/compile separate. One
  repaired focused acceptance after the separately recorded expected reproduction; unexpected
  failure stops for priority review. Do not broaden to parked stall/endurance or
  add a third unchanged return route to diagnose this static gap.
- **Check command:** same matrix/environment, with scope
  `tests/command_consumer_delivery_test.gd,tests/ship_command_test.gd`,
  jobs1, original300s per-suite and660s outer guard. Import/compile are separate.
- **Execution:** DONE/root on 2c73494a4, integrated as eaac8a432. Import/compile
  and both suites exit0, original diagnostics0; consumer40 and ship_command79.
  Full source/cache guards hold, owned processes exit, independent review GO.
  [Exact reproduction and repair](docs/history/ROADMAP_DELIVERIES.md#immediate-client-landing-edge--reproduced-and-repaired).
- **Close:** integrate accepted runtime/tests, commit/push, immediately create
  CHECKPOINT-HELM-EDGE. The earlier return failure/repair remain cumulative and
  return stays unqualified until its separately gated unchanged original route.

### CHECKPOINT-HELM-EDGE — playable accepted command-delivery repair

- **Execution:** DONE/root on exact clean2c73494a4. Both exports, three strict
  startups, all1515 actual payload-entry bytes, stock PE .text, exact Linux archive
  and two-member Windows ZIP checks pass. Seven public artifacts/notes are under
  repository builds. Owned checkout/profiles/helpers are removed; raw/source refs
  remain. [Package closure](docs/history/ROADMAP_DELIVERIES.md#immediate-client-landing-edge--checkpoint-published).
- **Parent/result:** parents6/32; exact clean accepted runtime, pinned Godot/templates.
  Existing safe Windows/Linux exports with correct private versioned XDG template
  mapping; verify actual debug/release paths before engines. Preserve HOME/CODEX_HOME.
- **Proof:** relevant focused checks, EXE/ZIP/notes and Linux ELF/archive/notes,
  actual payload-byte parity, exact archive members/modes/content and metadata.
  Direct Linux, archive Linux and Windows payload strict headless/Dummy startup
  each actualexit0+exactly one STARTUP_MENU_READY_OK/no error or leak diagnostics.
  Original matrix diagnostic policy; retain raw root notice without an invented gate.
- **Budget/stop:**15–25min preparation/checks; export900/startup300 caps separate,
  one export/platform; first failure stops with retained raw. No unchanged rerun.
- **Close:** repository builds only, actual player-visible/input-path changes and
  validation limits in notes, commit/push indices, clean owned checkouts/profiles.
  Native Windows/GPU/device/audio/human/full-release gates remain unperformed.

### NET-JOVIAN-RETURN — unchanged qualification after supported input repair

- **Execution:** FAILED/root on331a9628b: one142.125s route, all peers actualexit1,
  first abort client_b5.01264s after physical host docking. Caller ownership reader
  is corrected only in the separately bounded follow-up below; source held, no rerun.
- **Parent/result:** parents16/26; gate on accepted runtime+fresh checkpoint above.
  Compose held37cbc7a4e caller with accepted runtime; retain its complete input
  pulse and original [physical return contract](docs/history/ROADMAP_DELIVERIES.md#ordinary-shared-return--input-release-boundary-failed).
  No replacement input, route or artificial local landing request.
- **Proof:** original normal menus/all13+interior goals, real chairs/current identity/
  authority/HUD,5m departure/brake, free-home capture, one landing_assist pulse,
  host request8s, physical strict docking/lease/commit120s, client consumed arrival/
  body/hull5s. Existing private-Xvfb/x11/Dummy input-only matrix, original300s total/
  360s outer; actual allpeerexits0, original marker1, no diagnostics, source/cache
  guards. Preserve all original10/10/5/12/8s prerequisites and snapshot criteria.
- **Budget/stop:** compose/freeze5–10min; compile and one original route separately.
  First failure ends FAILED; required priority review before any more action.
  Original failed task plus repair remain counted; no new diagnostic run belongs here.
- **Close:** integrate caller only after acceptance, commit/push exact outcome and
  clean owned checkout/profiles, retain unique raw. No stand/exterior/reuse/
  native/package/endurance or whole-parent/phase claim from this source qualification.

### NET-JOVIAN-ARRIVAL-CALLER — read the ownership actually consumed by clients

- **Result/boundary:** only `tests/network/jovian_network_two_client_return_test.gd`.
  Replace client `get_owned_ship()` authority-ledger lookup with the matching
  `get_authoritative_snapshot().sections.ownership` record. Retain owner==original
  pilot and also require original ship/ownership generations; expose that received
  record in the existing receipt. No production code or authority writes.
- **Proof:** independent API/schema review GO; original hull<=0.5m, anchor<=0.05m,
  fresh same-pilot pose, landed/docked/not-landing, landing generation and retained
  identity checks stay intact. Exact caller source4c9c764e9; accepted runtime2c73494
  and its playable checkpoint unchanged. Existing import remains applicable: no
  resource/class/UID change. Compile300, then one original private-Xvfb/x11/Dummy
  route300/outer360 with all three actualexits0/marker1/originaldiagnostics0 and
  source/cache/process closure. Use fresh peer profiles; preserve original failure.
- **Execution/stop:** READY/root; verify clean4c9c764e9, compile then run once.
  Failed task+attempted repair counts remain cumulative. Any further failure stops;
  competing READY work is RECOVERY-ONFOOT-DEFINE/ACCESS-PAUSE-DEFINE/BOMBER-ROLES-DEFINE.
  Integrate the caller only on acceptance; no identical-runtime checkpoint rebuild.

### HELM-ACTIONS-DEFINE — close the remote-helm action-list unknown

- **Execution:** DONE/root, source definition only. Seven held fields and two
  ordered edge requests are mapped in the [existing backlog roster](docs/ROADMAP_BACKLOG.md#supported-remote-helm-action-roster). Six uncovered held-action
  cases are named; accepted forward throttle/brake and input-edge deliveries are
  retained. No engines or device qualification belong to this definition.
- **Result/boundary:** list each action actually supported by local input and
  remote helm, with binding, producing source, wire/consumer and existing proof.
  Read `scripts/control/`, `scripts/network/network_remote_pilot_command_source.gd`,
  GameFlow's helm path and `tests/network_remote_pilot_helm_test.gd`; no runtime edits.
- **Finish/proof:** update the existing parent18 backlog with the finite action
  list and only uncovered named cases. Distinguish immediate synthetic events,
  physical-device proof and direct injected commands. Preserve current landing
  repair ownership; no second investigation of that gap.
- **Execution/stop:** DONE/root within the30min definition boundary. Frozen recipe:
  first read actual action bindings; stop
  at finite roster or exact missing fact. Commit/push the documentation; any
  implementation or engine check needs its own scheduled production card.

### RECOVERY-ONFOOT-DEFINE — settle one recovery state

- **Result/boundary:** for on-foot recovery only, state what is persisted, whether
  restart resumes supported position or returns safely home, and the ordinary
  action proving usable play. Read existing safe-start/session recovery policy,
  persistence consumers and `tests/safe_start_production_recovery_test.gd`.
- **Finish/proof:** update the existing parent2/31 row with the actual contract,
  production owner, real-file/distinct-process check anchor and exact uncovered
  interruption boundary or missing decision. Cabin/pilot/planetary scope stays
  with its own rows; no new airborne-pose promise or invented entitlement.
- **Execution/stop:** READY/root, 30min; first read the production safe-start
  policy. No engines. Finite contract or exact missing input ends the card;
  commit/push. It does not include implementing or exercising SIGKILL recovery.

### ACCESS-PAUSE-DEFINE — name one finite readability set

- **Result/boundary:** identify pause/options views and applicable promised
  minimum/default/maximum scale and aspect coverage from Phase9/10.3, the
  production UI and existing `tests/runtime_accessibility_presentation_test.gd`.
- **Finish/proof:** update parent29's existing backlog row with exact named cells,
  view/setting owner and existing check/capture anchor. Record unresolved coverage
  explicitly. Do not invent the full Cartesian product, change UI or run captures.
- **Execution/stop:** READY/root, 30min; read the pause/options owner and original
  promise once. Stop at finite cells or exact missing fact, commit/push. A concrete
  readability defect gets a separate production repair card.

### BOMBER-ROLES-DEFINE — resolve the promised capability before building it

- **Result/boundary:** compare Phase5 and the production roster's bomber crew/
  navigation promise with `scripts/ships/cinder_long_range_bomber.gd`, its ship
  definition, actual chair/access bindings and existing bomber tests.
- **Finish/proof:** update parents4/10/16's existing row: each promised capability
  has a supported implemented owner, named missing production behavior, or exact
  interpretation decision. Cargo Hauler roles do not establish Bomber roles.
- **Execution/stop:** READY/root, 30min; start with the original promise and actual
  bomber seat/role registration. No engines or implementation. Finite comparison
  or precise missing decision ends the card; commit/push. Schedule only one named
  production gap afterwards, with its own acceptance and checkpoint.

## Parked work and external waits

| Item | Reopen condition / retained fact |
| --- | --- |
| VIP route | First runtime guard failure plus one syntax repair retained; no VIP arrival/seat/return acceptance. Priority review before further work. |
| Ember native close smoke | Observer capability ships in4270d71; native smoke FAILED/parked. Supported changed fixture/environment required; unchanged external-driver override remains unsupported. |
| Rime shared arrival; HULK revisit; Fire restart; Sandbox recovery; Convoy/Patrol/Q4/Q5 | Original failures, attempted repairs, physical criteria and limits remain in backlog/history. No unchanged retries. |
| Central operational-view finding / two software-renderer capture stalls | No supported art defect or material owner established. Source-tied usable image/reproduction or justified changed environment required. |
| Settings originals; Aurora original arrival bundle; release capacity choice | Existing external questions remain pending. Do not ask again or replace original acceptance. Server/two-client baseline remains authorized independently. |

Clean up each card's owned disposable worktree/profile/helpers at closure after
checking for unique work and live processes; preserve raw failures and source refs.
Scratch belongs under `/srv/mudds-work/`. The completed helm checkpoint checkout/profiles/helpers
are removed; the return checkout remains needed for its selected caller repair; three older dirty retired checkouts remain protected.

## Rules that prevent loops

- Select one named delivery with one observable outcome. Split implementation
  expected to exceed 90 minutes before starting; estimate check time separately.
- Write the affected component, exact acceptance, source/build, owner and next
  action before execution. At handoff, resume that action instead of rediscovering it.
- Use at most three steps: implement, verify, package/close. A passing check ends
  its step. Repeat only after a relevant change or a specific unresolved concern.
- Stop at the first concrete failure. Record the defect, unchanged acceptance,
  remaining action and revised estimate before scheduling its bounded repair.
  One diagnostic hypothesis permits one probe, not an unlimited investigation.
- At the estimate boundary, record done/failed/waiting and remaining work. Do not
  silently extend scope, lower physical criteria or shorten required test durations.
- Close by recording the actual result, committing/pushing, and removing owned
  disposable clean worktrees/scratch. Preserve unique work and raw failures.
- Keep the next eight cards visible; run only READY cards and at most one dependent
  chain at a time. Review priorities before replenishing the queue.
  Uninstantiated backlog templates are not scheduled work or measurable progress.
- Every scheduled task must fit the task card below. A broad parent such as
  “finish planetary travel” stays in the backlog until specific children exist.
- A failed check ends the qualification task with a recorded failure. Diagnosis
  and repair are separate bounded tasks; neither silently extends the original.
  After one inconclusive diagnostic probe, report the missing fact and choose
  the next task explicitly before doing more investigation.
- After a failed task and one attempted repair, review priorities before any
  further diagnosis, repair or rerun. Record the unresolved player/build outcome,
  time spent, competing READY task and selected next action. Renaming a card or
  finding a different defect does not reset this limit. This is a scheduling
  decision, not a new permission request.
- Report progress as the named result, proof obtained, remaining action and
  revised time estimate. Planning, diagnostics and test infrastructure do not
  count as a delivered gameplay outcome.

## Required card for the next scheduled tasks

Keep cards here, beside the work, rather than creating another tracking system.
Keep at most eight cards in this queue; refine later backlog items when their
dependencies are known. Do not turn every possible test combination into a speculative queue.

| Field | Required content |
| --- | --- |
| Task / parent | Stable short name, linked parent requirement and one concrete instance. |
| Result | One sentence describing what the player can do, what the build delivers, or which existing behavior is being qualified. Label qualification and planning explicitly. |
| Boundary | Affected component/files and explicit exclusions; new findings become separate tasks. |
| Proof | Existing command or ordinary player action, exact expected result, source/build and unchanged limits. A test count alone is insufficient. |
| Budget | Implementation/diagnosis estimate, check runtime separately, and the point at which work stops for reassessment. |
| Execution | Owner, dependency, READY/GATED/IN PROGRESS/DONE/FAILED/WAITING, one exact next action, and the action after failure. |
| Close | Actual result and limitation, commit/build reference, cleanup of owned disposable files. |

Prefer tasks expected to take 30–60 minutes of implementation; 90 minutes is
the split boundary, not a target. Split larger
work before execution. Long established checks retain their required duration
and are estimated separately. A parent closes only when its original acceptance
holds; completing a small child does not close the parent.

## Working constraints

Follow [AGENTS.md](AGENTS.md): Dummy audio for every automated Godot invocation;
headless/private display, explicit x11 under Xvfb, independent abort and owned
input/process cleanup. Keep GitHub Actions disabled and respect the Windows
execution hold. Meaningful runtime/graphics checkpoints require clean Windows
EXE/ZIP/notes and strict startup exit 0 plus `STARTUP_MENU_READY_OK`; artifacts
belong in repository `builds/`. Scratch belongs under `/srv/mudds-work/`.
Project completion still requires every original promise and final-candidate gate,
or an explicit owner deferral beside that promise. No percentage from tests or commits.
