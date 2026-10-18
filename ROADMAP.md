# Development roadmap

**Next task: reproduce the immediate client landing-edge loss on the old runtime.**
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
| Passenger chair and pilot/passenger HUD repairs | Integrated. Latest runtime delivery b6196a19a resolves craft labels through the actual occupied chair. |
| Playable Windows/Linux checkpoint **b6196a1** | [Windows notes](builds/windows/MuddsShipyards-b6196a1-notes.txt), [Linux notes](builds/linux/MuddsShipyards-b6196a1-linux-notes.txt). Safe exports, three strict menu startups and actual payload/archive checks pass. |
| Ordinary two-client Jovian boarding | fff5f7221: normal approaches, both actual seats, current identities/HUD/authority and host confirmation; all three peers exit 0. |
| Ordinary shared departure and braking | 96c96312f: host physically moves 5.004m, frees berth and stops; both clients remain seated/current. |
| Four-cycle phantom cleanup and twelve-cycle all-nine reuse | d7be01487: both source qualifications pass. Staged/headless source scope; packaged ordinary play is separate. |
| Browser generation/cancel handling and defense briefing | Delivered on their recorded sources; broader connection/controller acceptance stays open. |

**Current failed boundary:** the latest return caller 37cbc7a4e fails its original
8s request-acceptance gate: host landing serial 0. Input release/neutrality and
client identities pass; physical docking and arrival are unqualified. Static
reading identifies a supported immediate-command forwarding gap, but pulse-time
admission in that failed run was not captured. The focused reproduction below
must establish the defect; do not assume it already explains every event.

**Unverified:** current full matrix NOT_RUN (last unfiltered f85957f failed 11 of
1,045 suites); native hardware/device/audio, endurance and final release gates
remain open. Native Windows execution and human review retain the owner's
exclusions and factual NOT_RUN records. Focused passes do not replace these gates.

## Next eight tasks

**5 READY, 3 GATED.** These are eight queue cards, not eight tasks left in the
project. READY definition cards can proceed independently; no parked route is
reopened by this list. Root owns integration and each card unless assigned below.
Implementation and check time are separate; caps are safety limits, not estimates.
The held patch is preserved, not yet accepted or included in a playable build.

| Order / task | Type | Status / dependency | Finish | Work estimate; checks separate |
| --- | --- | --- | --- | --- |
| 1. HELM-EDGE-REPRO | Regression qualification | READY | Real immediate landing then neutral physics demonstrates the missing remote serial on the old runtime. | 15–30min freeze/review; import ≤600s, compile ≤300s, one suite ≤300s. |
| 2. HELM-EDGE-REPAIR | Runtime repair | GATED on 1 | The same admitted edge reaches the current remote helm exactly once; invalidation revokes it. | 30–60min review/integrate existing patch; focused pair ≤300s each. |
| 3. CHECKPOINT-HELM-EDGE | Playable build | GATED on 2 | Fresh paired Windows/Linux packages contain the accepted fix. | 15–25min preparation/artifact work; export ≤900s/platform, startup ≤300s each. |
| 4. NET-JOVIAN-RETURN | Ordinary gameplay qualification | GATED on 2+3 | Physical home dock commits and both retained clients consume arrival. | 5–10min compose/freeze; compile ≤300s, one original route ≤300s. |
| 5. HELM-ACTIONS-DEFINE | Scope definition | READY | Finite supported action/binding/consumer/coverage list, with uncovered cases named. | 30min; no engines. |
| 6. RECOVERY-ONFOOT-DEFINE | Scope definition | READY | On-foot durable boundary and usable resume/safe-home outcome are unambiguous. | 30min; no engines. |
| 7. ACCESS-PAUSE-DEFINE | Scope definition | READY | Pause/options views and required scale/aspect cells are named. | 30min; no captures. |
| 8. BOMBER-ROLES-DEFINE | Scope definition | READY | Promised bomber crew/navigation capabilities are matched to actual production owners or explicit gaps. | 30min; no engines. |

**Selection rule:** finish this planning pass, then resume card 1. A check failure
ends that card; it does not expand the queue. After the existing failed return
and attempted repair, the recorded priority review selected this input repair.
Those failures remain counted. If the repaired qualification fails, record the
first boundary and reassess competing READY work before further action.
Definition cards end at their finite answer or exact missing input; they cannot
turn into diagnostics, implementations or additional checks under the same card.

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
- **Execution:** READY/root; inspect the held two-file diff, save the runtime
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
- **Execution:** GATED on HELM-EDGE-REPRO; root. The two-file patch is written
  in `/srv/mudds-work/helm-edge-20261018/source/`, static diff check passes,
  engine checks NOT_RUN. Review that patch; do not start another implementation.
- **Close:** integrate accepted runtime/tests, commit/push, immediately create
  CHECKPOINT-HELM-EDGE. The earlier return failure/repair remain cumulative and
  return stays unqualified until its separately gated unchanged original route.

### CHECKPOINT-HELM-EDGE — playable accepted command-delivery repair

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

### HELM-ACTIONS-DEFINE — close the remote-helm action-list unknown

- **Result/boundary:** list each action actually supported by local input and
  remote helm, with binding, producing source, wire/consumer and existing proof.
  Read `scripts/input/`, `scripts/network/network_remote_pilot_command_source.gd`,
  GameFlow's helm path and `tests/network_remote_pilot_helm_test.gd`; no runtime edits.
- **Finish/proof:** update the existing parent18 backlog with the finite action
  list and only uncovered named cases. Distinguish immediate synthetic events,
  physical-device proof and direct injected commands. Preserve current landing
  repair ownership; no second investigation of that gap.
- **Execution/stop:** READY/root, 30min. First read actual action bindings; stop
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
Scratch belongs under `/srv/mudds-work/`. The current held helm source/profile
remains needed for card1; three older dirty retired checkouts remain protected.

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
