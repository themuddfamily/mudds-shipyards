# Development roadmap

The game is a playable development alpha. **All ten phase exit gates remain
open.** This file contains the active delivery only. The
[backlog and 36-parent crosswalk](docs/ROADMAP_BACKLOG.md),
[original specifications](docs/history/ROADMAP_SCOPE_20261017.md) and
[production roster](docs/COMPLETION_SCOPE.md) retain the full project scope.
[Completed deliveries](docs/history/ROADMAP_DELIVERIES.md) retain their recorded
source, checks, failures and limitations. Moving them does not close requirements.

Latest playable: **b6af782**, with [Windows build notes](builds/windows/MuddsShipyards-b6af782-notes.txt)
and [Linux build notes](builds/linux/MuddsShipyards-b6af782-linux-notes.txt).
The browser Disconnect improvement is playable there. Later benchmark/test-only
changes do not require a new gameplay checkpoint. Current full matrix: NOT_RUN;
last unfiltered matrix `f85957f` failed 11 of 1,045 suites. Focused passes do not
replace it. Native Windows execution and human review remain owner-excluded
mandatory gates, factually NOT_RUN. Other hardware/release gates remain open.

## Rules that prevent loops

- Select one named delivery with one observable outcome. Split implementation
  expected to exceed 30–120 minutes before starting; estimate check time separately.
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
- Schedule only the next 3–5 concrete deliveries when their contracts are known.
  Uninstantiated backlog templates are not scheduled work or measurable progress.
- Every scheduled task must fit the task card below. A broad parent such as
  “finish planetary travel” stays in the backlog until specific children exist.
- A failed check ends the qualification task with a recorded failure. Diagnosis
  and repair are separate bounded tasks; neither silently extends the original.
  After one inconclusive diagnostic probe, report the missing fact and choose
  the next task explicitly before doing more investigation.
- Report progress as the named result, proof obtained, remaining action and
  revised time estimate. Planning, diagnostics and test infrastructure do not
  count as a delivered gameplay outcome.

## Required card for the next scheduled tasks

Keep cards here, beside the work, rather than creating another tracking system.
Define only the next 3–5 tasks; refine later backlog items when their dependencies
are known. Do not turn every possible test combination into a speculative queue.

| Field | Required content |
| --- | --- |
| Task / parent | Stable short name, linked parent requirement and one concrete instance. |
| Result | One sentence describing what the player can do, what the build delivers, or which existing behavior is being qualified. Label qualification and planning explicitly. |
| Boundary | Affected component/files and explicit exclusions; new findings become separate tasks. |
| Proof | Existing command or ordinary player action, exact expected result, source/build and unchanged limits. A test count alone is insufficient. |
| Budget | Implementation/diagnosis estimate, check runtime separately, and the point at which work stops for reassessment. |
| Execution | Owner, dependency, READY/GATED/IN PROGRESS/DONE/FAILED/WAITING, and one exact next action. |
| Close | Actual result and limitation, commit/build reference, cleanup of owned disposable files. |

Start with tasks expected to take 30–90 minutes of implementation. Split larger
work before execution. Long established checks retain their required duration
and are estimated separately. A parent closes only when its original acceptance
holds; completing a small child does not close the parent.

## Latest accepted result

**Ember completed source journey DONE on bf452ed868:** real outbound/landing,
walked survey and one durable reward, physical return, home docking and supported
walking exit. Exact52 assertions/catalog, exit0, no diagnostics; approximately
49m51s within the original60-minute cap. Source/cache/process guards pass within
recorded scopes; disposable checkout removed. [Result and limits](docs/history/ROADMAP_DELIVERIES.md#ember--canonical-completed-source-journey-done-on-bf452ed868).
Package, ABANDON, repeat/shared, hardware and full phase gates stay open.
Previous [HULK interior walk](docs/history/ROADMAP_DELIVERIES.md#hulk--continuous-interior-traversal-done-on9cffc99a2)
also remains source-specific; flight/docking/fringe-rebase setup there is staged.

## Current delivery: INSTALL-LINUX[interrupted update publication]

**Player result:** an update killed after publishing its desktop entry can be
retried normally, without leaving the installer stuck or damaging saves.
Parent: [installation/update recovery](docs/ROADMAP_BACKLOG.md#recovery-packages-captures-and-release).
Boundary: `tools/release/install_linux_desktop.py`, its existing consolidated
test and Linux build documentation. Initial-install/uninstall interruption,
power loss and graphical launch remain separate. No new game behavior or
Windows gameplay checkpoint is implied by this Linux manager repair.
Source repair integrated on `d3259aa21`, independently reviewed by root.
Filesystem-only source checks completed during Ember's run; Ember is now closed.

| Task | Proof / stopping condition | State / budget |
| --- | --- | --- |
| LINUX-UPDATE-REPRO | Actual child killed/reaped -9 at desktop-published/manifest-pending cut; distinct CLI retry exits1 with exact launcher mismatch. Raw original failure retained. | DONE; no widened diagnosis |
| LINUX-UPDATE-FIX | Production recovery record allows fresh CLI retry, including a newer third archive, with consistent desktop/manifest/hashes and protected files retained. Ten installer tests pass, no skips; existing bundle integration passes; root runs all23 existing Linux export unit tests successfully. Refusal/normal rollback behavior retained. | DONE on d3259aa21; filesystem checks under5s each |
| LINUX-UPDATE-SHIP | Existing updated manager must ship byte-for-byte in fresh clean Linux archive; actual shipped-script update/kill/retry/uninstall preserves protected files; strict startup exit0/`STARTUP_MENU_READY_OK`. Record hashes/limits, commit/push, remove disposable checkout. | IN PROGRESS; root; cold import launched; allow30 min for package/checks, reassess at boundary |

Source/miniature-bundle acceptance does not qualify the shipped archive.
Journal retirement precedes cleanup: a later kill can leave an unused generation.
Package preparation is pinned to `4141d94ddf01317062886e1becd2c67d1048af40`
at `/srv/mudds-work/linux-update-package-20261017`; clean export dry run passes.
Pinned engine/template and private profile are prepared under
`/srv/mudds-work/linux-update-package-results-20261017/`. Driver
PID355194/start107319076 is launched with its prepared private environment;
follow the live stage owner in `active-owner.json`, verifying actual `/proc`
start ticks before waiting. The reviewed sequence uses existing cold import/export/startup
commands and `check_shipped_manager.py`, which reuses the consolidated SIGKILL
helper against the actual shipped script/archives. All prepared scripts pass
static syntax review. Next: inspect the same cold-import result, then subsequent
gated stages; actual export/archive/startup acceptance remains pending. Abort:
`python3 /srv/mudds-work/linux-update-package-results-20261017/abort.py`.
Any failure ends that task with its actual result and a named follow-up. The
Aurora benchmark candidate stays unscheduled while this production gap is open.

All ten phase gates remain open. Q4 startup stays parked after the bounded
five-file source review found no justified construction candidate. Latest
playable remains b6af782; definition/qualification alone needs no new build.

## Working constraints

Follow [AGENTS.md](AGENTS.md): Dummy audio for every automated Godot invocation;
headless/private display, explicit x11 under Xvfb, independent abort and owned
input/process cleanup. Keep GitHub Actions disabled and respect the Windows
execution hold. Meaningful runtime/graphics checkpoints require clean Windows
EXE/ZIP/notes and strict startup exit 0 plus `STARTUP_MENU_READY_OK`; artifacts
belong in repository `builds/`. Scratch belongs under `/srv/mudds-work/`.
Project completion still requires every original promise and final-candidate gate,
or an explicit owner deferral beside that promise. No percentage from tests or commits.
