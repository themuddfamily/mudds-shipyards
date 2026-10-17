# Development roadmap

The game is a playable development alpha. **All ten phase exit gates remain
open.** This file contains the active delivery only. The
[backlog and 36-parent crosswalk](docs/ROADMAP_BACKLOG.md),
[original specifications](docs/history/ROADMAP_SCOPE_20261017.md) and
[production roster](docs/COMPLETION_SCOPE.md) retain the full project scope.
[Completed deliveries](docs/history/ROADMAP_DELIVERIES.md) retain their recorded
source, checks, failures and limitations. Moving them does not close requirements.

Latest Windows checkpoint: **b6af782**, with [notes](builds/windows/MuddsShipyards-b6af782-notes.txt).
Latest Linux package: **4141d94**, with [notes](builds/linux/MuddsShipyards-4141d94-linux-notes.txt),
including interrupted-update recovery. The last paired gameplay checkpoint is
b6af782, including the browser Disconnect improvement. Current full matrix: NOT_RUN;
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

**Linux interrupted-update recovery shipped on4141d94:** actual shipped-script
SIGKILL/fresh retry and protected-file checks pass20; direct/archive strict
startup both pass. [Result and limits](docs/history/ROADMAP_DELIVERIES.md#linux-interrupted-update-recovery--shipped-on-4141d94dd).
Clean export checkout and duplicate extracted ELF removed. No new Windows build.

## Latest bounded delivery: Aurora coastal walking — DONE

The runner now selects `aurora_surface_walk_route` using the actual Main Player,
streamed terrain and authored lookout. Frozen source c47b5cd55 passes Aurora27,
default152, combat19 and Ember24 focused assertions with no diagnostics. Aurora
sampled258.008m through held-input walking, both endpoints, real terrain/lookout
support and paused Escape cleanup. Source/index/engine/cache guards passed;
38 recorded identities absent, lanes free. Author and acceptance checkouts
removed; raw failures/results retained. [Result and limitations](docs/history/ROADMAP_DELIVERIES.md#aurora-coastal-walking-benchmark--done-on-c47b5cd55).
Initial placement, streaming observation and gravity adapters are disclosed;
full timed/native performance and canonical planetary journeys remain NOT_RUN.

## Next delivery: Linux first-install interruption recovery

**One result:** after an OS kill between desktop publication and ownership
manifest publication during first install, an ordinary fresh CLI retry safely
installs the chosen package while preserving user/unrelated files. Parent:
[INSTALL-LINUX / RECOVERY-FIX](docs/ROADMAP_BACKLOG.md#recovery-packages-captures-and-release).
Existing update recovery covers `previous` installations only; source currently
creates its recovery journal only when `previous` is present. A first install
can publish its desktop entry without a manifest. Reproduce before fixing.

**Boundary:** `tools/release/install_linux_desktop.py` and its consolidated test.
Reuse the real SIGKILL helper and existing journal/ownership checks; no new
validator/schema family or unconditional adoption of unowned desktop entries.
Existing update journal compatibility and refusal behavior must remain. No
production gameplay changes, uninstall-kill or power-loss qualification.

| Task | Exact finish line / stop | State / budget |
| --- | --- | --- |
| LINUX-FIRST-INSTALL-REPRO | Existing real child-process cut, first install only; kill after desktop publication/before manifest, reap, then fresh ordinary CLI retry. Record actual failure or supported success; no assumed bug. | DONE; actual SIGKILL/fresh retry exits1, refusal of desktop without manifest |
| LINUX-FIRST-INSTALL-FIX | If reproduced, repair the existing ownership transaction, pass focused tests including prior update recovery, tampered inputs and protected saves/untracked files. No permissive ownership fallback. | IN PROGRESS;45–60 min implementation, focused checks separately |
| LINUX-FIRST-INSTALL-SHIP | Clean-source Linux archive includes exact repaired manager; actual shipped-manager first-install kill/fresh retry and update checks, exact artifact/member bytes, direct/extracted strict startup exit0 + STARTUP_MENU_READY_OK; notes and cleanup. | GATED on fix; export/smoke5–15 min plus original caps |

**Owner:** `linux_first_install_recovery`, isolated worktree
`/srv/mudds-work/linux-first-install-recovery-20261017`, base09bf654c3;
root owns integration, roadmap and actual package checks.
**Reproduction:** existing helper killed/reaped the real production child at
publication; no previous install, manifest or journal. Fresh ordinary retry
exits1 refusing the desktop entry. Raw `before-fix.json` and cut filesystem retained.
**Next single action:** review the implementer's transaction repair and focused
checks, then freeze clean integrated source for the existing Linux export flow.
`linux_first_install_package_check` prepares the actual shipped-manager check
independently; no engines launched. Raw before/after: `/srv/mudds-work/linux-first-install-recovery-results-20261017/`.
No engines or package export is assigned. Stop at first unexpected boundary and
record it before any separately bounded follow-up.

All ten phase gates remain open. Q4 startup stays parked without a justified
construction candidate. Latest paired gameplay checkpoint remains b6af782;
Linux package is4141d94. No Windows build is needed for benchmark/Linux-only work.

## Working constraints

Follow [AGENTS.md](AGENTS.md): Dummy audio for every automated Godot invocation;
headless/private display, explicit x11 under Xvfb, independent abort and owned
input/process cleanup. Keep GitHub Actions disabled and respect the Windows
execution hold. Meaningful runtime/graphics checkpoints require clean Windows
EXE/ZIP/notes and strict startup exit 0 plus `STARTUP_MENU_READY_OK`; artifacts
belong in repository `builds/`. Scratch belongs under `/srv/mudds-work/`.
Project completion still requires every original promise and final-candidate gate,
or an explicit owner deferral beside that promise. No percentage from tests or commits.
