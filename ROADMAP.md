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

## Current delivery: PERF-ROUTE[Aurora coastal walking]

**One result:** the existing production benchmark runner can select a physical
Aurora coastal walk. Parent: original performance surface-route coverage in the
[backlog](docs/ROADMAP_BACKLOG.md#performance-controls-accessibility-and-audio).
This is an executable benchmark capability, not native performance acceptance.
**Boundary:** existing `tools/performance/benchmark_runner.gd`,
`run_native_windows_benchmark.ps1` selection allowlist, consolidated runner/record
checks and `docs/PERFORMANCE_BENCHMARK_RUNNER.md`. Reuse the authored coastal
points/frame handling in `tests/aurora_visit_loop_test.gd`; use actual Main-owned
Aurora terrain and held movement. Disclose initial benchmark staging; no actor
placement during sampled walking. No production gameplay/gravity/physics changes, canonical
flight/reward/save qualification, new schemas or validator families.
**Owner:** `aurora_coastal_benchmark` implements in its own worktree; root
reviews/integrates. Base d09dfabf68575583469373fa3a1d4e027b2825d6;
Implementation integrated as `44c92bc65e22b91c39d10b4ff3acd792c08ec9e4`;
first focused engine attempt is recorded below. No engine is active now.

| Task | Exact finish line / stopping condition | State / estimate |
| --- | --- | --- |
| AURORA-WALK-IMPLEMENT | Add select-only `aurora_surface_walk_route` through existing runner, reset fresh local route targets across origin changes, preserve original two-route default. Own only the named runner/allowlist/test/docs seams. | REPAIR IN PROGRESS; explicit bool type at terrain metadata seam,15 min maximum |
| AURORA-WALK-VERIFY | Existing `tests/performance_benchmark_runner_test.gd`, headless/Dummy, original300s cap: original default, combat and Ember selections retain acceptance; new selected smoke proves positive sampled physical path, real terrain support, endpoint completion, JSON round-trip and abort/input cleanup. Existing Python record checks pass; no timing/quality/schema relaxation. | FAILED on44c92bc65 before route startup; rerun only after repair |
| AURORA-WALK-CLOSE | Record actual source/result/limits, commit/push and remove clean disposable checkout. Keep full3600-frame/60s warmup and18000-frame/600s sample floors, selected smoke performance acceptance false/null; native hardware remains NOT_RUN. | GATED; 10 min |

**First qualification FAILED:** cold import exit0, no diagnostics. Selected
Aurora failed compilation at `benchmark_runner.gd:403`: `on_terrain` inferred
from Variant metadata has no set type. Supervisor stopped/reaped the check143;
default/combat/Ember were not launched. Source/index/engine and post-import cache
unchanged; seven recorded process identities absent, lanes free, closure reports
no owned socket/display remnants. Raw failure retained:
`/srv/mudds-work/aurora-coastal-acceptance-results-20261017/`.

**Next single action:** review the implementer's15-minute explicit-bool repair,
freeze a new clean commit and run the unchanged acceptance. Expected Aurora27,
default152, combat19, Ember24 assertions. Original import600s/mode300s caps remain;
no unchanged retry and no scope expansion into planetary behavior.

All ten phase gates remain open. Q4 startup stays parked after the bounded
five-file source review found no justified construction candidate. Latest
paired gameplay checkpoint remains b6af782; Linux manager package is4141d94.

## Working constraints

Follow [AGENTS.md](AGENTS.md): Dummy audio for every automated Godot invocation;
headless/private display, explicit x11 under Xvfb, independent abort and owned
input/process cleanup. Keep GitHub Actions disabled and respect the Windows
execution hold. Meaningful runtime/graphics checkpoints require clean Windows
EXE/ZIP/notes and strict startup exit 0 plus `STARTUP_MENU_READY_OK`; artifacts
belong in repository `builds/`. Scratch belongs under `/srv/mudds-work/`.
Project completion still requires every original promise and final-candidate gate,
or an explicit owner deferral beside that promise. No percentage from tests or commits.
