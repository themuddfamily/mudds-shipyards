# Development roadmap

The game is a playable development alpha. **All ten phase exit gates remain
open.** This file contains the next three concrete installer tasks. The
[backlog and 36-parent crosswalk](docs/ROADMAP_BACKLOG.md),
[original specifications](docs/history/ROADMAP_SCOPE_20261017.md) and
[production roster](docs/COMPLETION_SCOPE.md) retain the full project scope.
[Completed deliveries](docs/history/ROADMAP_DELIVERIES.md) retain their recorded
source, checks, failures and limitations. Moving them does not close requirements.

Latest Windows checkpoint: **a8f563e**, with [notes](builds/windows/MuddsShipyards-a8f563e-notes.txt).
Latest Linux package: **a8f563e**, with [notes](builds/linux/MuddsShipyards-a8f563e-linux-notes.txt).
Paired development checkpoint for the new source Rime benchmark selection.
Clean exports, three strict startups and privacy207 pass; all1,515 payload entries
match byte-for-byte. The benchmark requires a source checkout; exported games
exclude tools. Earlier HULK/home, Ember journey and installed recovery proofs
retain their exact source/binary scopes; no full-route proof transfers to these bytes.
Current full matrix: NOT_RUN;
last unfiltered matrix `f85957f` failed 11 of 1,045 suites. Focused passes do not
replace it. Native Windows execution and human review remain owner-excluded
mandatory gates, factually NOT_RUN. Other hardware/release gates remain open.

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
- Schedule at most the next 3–5 concrete deliveries when their contracts are known.
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
Define at most the next 3–5 tasks; refine later backlog items when their dependencies
are known. Do not turn every possible test combination into a speculative queue.

| Field | Required content |
| --- | --- |
| Task / parent | Stable short name, linked parent requirement and one concrete instance. |
| Result | One sentence describing what the player can do, what the build delivers, or which existing behavior is being qualified. Label qualification and planning explicitly. |
| Boundary | Affected component/files and explicit exclusions; new findings become separate tasks. |
| Proof | Existing command or ordinary player action, exact expected result, source/build and unchanged limits. A test count alone is insufficient. |
| Budget | Implementation/diagnosis estimate, check runtime separately, and the point at which work stops for reassessment. |
| Execution | Owner, dependency, READY/GATED/IN PROGRESS/DONE/FAILED/WAITING, one exact next action, and the action after failure. |
| Close | Actual result and limitation, commit/build reference, cleanup of owned disposable files. |

Start with tasks expected to take 30–90 minutes of implementation. Split larger
work before execution. Long established checks retain their required duration
and are estimated separately. A parent closes only when its original acceptance
holds; completing a small child does not close the parent.

## Current position

**36 broad parent outcomes remain open; the remaining executable-job count is
not yet known.** Parent scope lives in the backlog. Only named cards below are
scheduled tasks; their steps are not separate delivered outcomes. Planning and
diagnosis are reported separately from playable changes.

Recent accepted results: Ember completed physical source journey on bf452ed868,
Aurora coastal benchmark route on c47b5cd55, Linux first-install recovery/package
b41c3cc, and managed installed Guided3/3. See
[completed deliveries](docs/history/ROADMAP_DELIVERIES.md) for exact proof/limits.
These do not close their broad parents or the ten phase gates.

**Latest accepted task: RIME-BENCH-ROUTE and checkpoint — DONE.**
Source `a8f563e39` adds select-only walking through every authored Rime survey/
return waypoint, supported by Main's real streaming/gravity owners. Focused
Rime33/default152/Ember24/Aurora27 pass. This delivers benchmark coverage,
not new planetary gameplay or native performance qualification. Paired
checkpoint `a8f563e` is published; details and limits are in delivery history.
Ember ABANDON source `e85157b4d` remains DONE (physical home dock/walk, exact31),
with packaged/durable-save/shared/hardware gates open. HULK revisit stays parked.
Sandbox, Convoy and Q4 remain parked at their recorded failures; no automatic retries.

## Earlier accepted/parked work

EMBER-ABANDON-SOURCE is DONE on `e85157b4d` (exact 31, physical home dock/walk).
HULK revisit failed its original 300 s deadline on `2298e4889`; that candidate
remains withheld, and its checkpoint is GATED. Both results and the priority
review are retained in [delivery history](docs/history/ROADMAP_DELIVERIES.md).
No unchanged Ember rerun or further HULK diagnosis/repair is selected.
Retired-directory cleanup removed 16 clean checkouts; three containing uncommitted
work remain intact, with source refs and unique raw results preserved.

## Next batch — retry an interrupted Linux uninstall

**Three bounded tasks: reproduction DONE, repair IN PROGRESS, shipping GATED.** This delivers one installation
recovery behavior. The failed Rime driver and its type repair are closed and
withheld; survey/home/package children are parked with their parent, not silently
dropped. [Failure, original contracts and priority review](docs/history/ROADMAP_DELIVERIES.md#rime-arrival-closed--landing-gate-failure-and-priority-review).
No further Rime probe, repair or unchanged run is selected.

| Task | Status | Observable finish | Work estimate; separate checks |
| --- | --- | --- | --- |
| LINUX-UNINSTALL-CUT | DONE on published a8f563e | Actual SIGKILL after menu-entry removal produces a distinct-process retry result on the published manager, with protected data intact. | 20–30 min setup/closure; bounded child waits up to 10 s each, overall 120 s. |
| LINUX-UNINSTALL-RETRY | IN PROGRESS | Rerunning uninstall completes that interrupted removal safely, once and without deleting saves/unrelated files. | 60–90 min implementation; existing 12 installer tests plus focused cut/refusal checks, overall 120 s. |
| LINUX-UNINSTALL-SHIP | GATED on accepted repair | A fresh downloadable Linux archive contains the fixed manager and passes the same real cut/retry; paired checkpoint has actual startup/artifact results. | 30–45 min setup/closure; export/startup/privacy allowances separately below. |

### LINUX-UNINSTALL-CUT — DONE, bounded reproduction

Actual shipped manager SHA `ebd03b09e7f901bd469c2bb7d175404e8263e51e1b0e6345f2c096a6876c1057`
matches source. Install exits 0; exact paused uninstall PID/start is verified,
SIGKILL exits -9, and distinct CLI retry exits 1 with the predicted missing
desktop refusal. Only the menu entry disappeared; payload/manifest/protected
bytes remain exact, and retry makes no additional mutation. Children are reaped.
Raw `/srv/mudds-work/linux-uninstall-recovery-20261018/results/reproduction/`
is retained. This closes reproduction, not recovery acceptance.

- **Parent/owner:** [INSTALL-LINUX](docs/ROADMAP_BACKLOG.md#recovery-packages-captures-and-release);
  root assigns one implementation agent, root owns integration and checks.
  Work belongs under one `/srv/mudds-work/linux-uninstall-recovery-20261018/`
  directory; remove its disposable clean checkout at close and retain raw.
- **Exact case:** use published `builds/linux/MuddsShipyards-a8f563e-linux-x86_64.tar.gz`
  (SHA256 `964784cf05a1b38c96c5a358cf402592623fd952af37fa4387a9386894653eb9`).
  Verify/extract its shipped manager; install that archive into explicit private
  install/applications paths. Seed unrelated files in the runtime generation
  and install root, plus private Godot user-data sentinels. Never use real user
  installation/profile paths or launch the game in this reproduction.
- **Existing seam:** `tools/release/install_linux_desktop.py::uninstall` removes
  the desktop entry before payload/manifest cleanup. `read_install` requires
  that entry on retry. This is a source-level predicted gap, not yet an observed
  SIGKILL result. Reuse the real child-process pause/kill/retry pattern already
  in `tools/release/test_install_linux_desktop.py`; no validator/framework.
- **Proof/next action:** run the actual shipped uninstall, pause immediately
  after its desktop unlink and before the first payload unlink, then send owned
  SIGKILL and require actual exit -9. Start a distinct ordinary CLI uninstall
  process with the same paths. Record its exit/stdout/stderr and exact owned/
  protected-file state. Predicted old result is refusal mentioning changed or
  missing owned desktop entry, retaining payload/manifest and all protected bytes.
  This expected defect reproduction is not accepted uninstall recovery.
- **Budget/stop:** 20–30 min setup, child waits up to 10 s, single 120 s outer
  cap. No production edits, other interruption cuts, power-loss claims or engine
  calls. If the predicted failure is not reproduced, stop and reassess rather
  than implementing a speculative fix. Commit/push actual result; leave task 2
  gated until its defect and unchanged acceptance are explicit.

### LINUX-UNINSTALL-RETRY — IN PROGRESS, reproduced cut confirmed

Dependency is now met by the actual shipped-script SIGKILL reproduction above.
Next action: one agent implements the existing manager/test repair in the
owned checkout; root reviews it independently before the single focused run.
Conflicting install/update must not overwrite a pending removal operation.

- **Result/boundary:** repair the existing manager so an ordinary uninstall
  retry safely finishes the named interrupted operation. Own only
  `tools/release/install_linux_desktop.py` and its existing test file. The game,
  launcher format and unrelated install/update behavior stay outside this fix.
- **Next action once ungated:** preserve verified removal intent before the
  destructive boundary and resume only that authenticated owned operation.
  Use the existing lock/atomic-write/ownership machinery. This is a production
  transaction consumed by the manager, not an evidence schema or validator.
  Do not broadly accept missing/modified desktop entries without valid intent.
- **Proof:** the same actual SIGKILL cut followed by a distinct CLI retry exits
  0; only originally owned menu entry, payload, manifest and removal intent are
  gone. A repeated uninstall succeeds. Every seeded save/unrelated byte remains.
  Modified surviving owned files or a foreign/edited desktop entry must refuse
  before further mutation; retain existing unsafe-path and install/update guards.
  Run all 12 existing installer tests plus the smallest regression protecting
  this cut/refusal behavior, using Python bytecode disabled and private paths.
- **Budget/stop:** 60–90 min implementation; focused Python checks have one
  120 s outer cap with original child limits. Stop first unexpected failure and
  retain its exact source; schedule any repair separately. Do not bundle another
  cut, a crash matrix or a new installer architecture. Commit/push accepted code.

### LINUX-UNINSTALL-SHIP — GATED on task 2

- **Result/next action:** export from the clean accepted commit using existing
  safe scripts; publish EXE/ZIP/notes in `builds/windows/` and matching Linux
  ELF/archive/notes in `builds/linux/`. Notes describe the installer retry change;
  no new gameplay or native Windows execution is implied.
- **Proof:** exact source manager bytes occur inside the new Linux archive.
  Repeat task 2's real cut/retry once using that extracted shipped script and
  archive, with protected data intact. Run the existing focused installer checks,
  strict direct/archive Linux and silent Windows-payload startup (exit 0 plus
  `STARTUP_MENU_READY_OK`), privacy and archive/payload identity checks. Game
  startup uses headless/Dummy; no active desktop, audible output or hosted CI.
- **Budget/close:** 30–45 min setup/closure; exports up to 930 s each, three
  startups up to 330 s each, privacy up to 300 s, installer consumer up to 120 s.
  Stop first required failure, retain the previous accepted packages and raw;
  no automatic rerun. On acceptance commit/push notes/source, remove owned clean
  checkout and preserve exact published artifacts. Broader install cuts, power
  loss, native platform/device/audio/performance and full-release gates stay open.

## Decomposing later work

The backlog is not yet fully decomposed. After this batch,
select at most the next 3–5 known instances. Each needs the required card above;
unknown acceptance gets one bounded definition task. Archive closed cards and
failures in existing delivery history. A planning pass has a 30–45 min budget,
no engine runs, and ends with reviewed cards and a commit/push. Planning and
benchmark diagnostics do not count as delivered gameplay or native performance.

## Working constraints

Follow [AGENTS.md](AGENTS.md): Dummy audio for every automated Godot invocation;
headless/private display, explicit x11 under Xvfb, independent abort and owned
input/process cleanup. Keep GitHub Actions disabled and respect the Windows
execution hold. Meaningful runtime/graphics checkpoints require clean Windows
EXE/ZIP/notes and strict startup exit 0 plus `STARTUP_MENU_READY_OK`; artifacts
belong in repository `builds/`. Scratch belongs under `/srv/mudds-work/`.
Project completion still requires every original promise and final-candidate gate,
or an explicit owner deferral beside that promise. No percentage from tests or commits.
