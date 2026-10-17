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

## Active repair: HULK-FIX[first-landing shelf penetration]

**Observed defect:** on `7f2056d22`, held raw/sampled forward input is nonzero,
Player is unpaused ON_FOOT and processing normally, but actual hulk DockShelf
slide contacts report upward normals, 0.199348m penetration and zero travel.
The first movement leg fails after52 passing checks. The contact diagnostic is
complete; no input/menu fix or geometry change is justified.

**Owner/files:** `hulk_shelf_floor_repair`, Player controller and existing
`player_step_up_assist_test.gd`; root independent review/integration/checks.
**Hypothesis/candidate:** prevent descending first-landing penetration through
the existing bounded vertical overlap recovery. Its current admission excludes
first landings and all slide contacts. Preserve pre-descent lift cap, tangent
position, headroom/wall/slope rejection and authored snap; no generic rescue.
A focused actual-shelf regression must demonstrate the causal path before
acceptance. Do not treat this candidate as a proven fix.

| Step | State / finish line | Estimate |
| --- | --- | --- |
| Implement/review | IN PROGRESS; smallest safe recovery extension plus actual first-landing/normal-walk regression in existing test. | 30–60 min |
| Verify | GATED; focused Player regression then unchanged full hulk route, each original300s, headless/Dummy. Exit0, original success markers, zero diagnostics, stable guards/teardown. Stop at first failure. | 10–20 min |
| Package/close | GATED on actual runtime fix; fresh clean Windows checkpoint EXE/ZIP/notes, focused and strict silent startup checks, remove clean checkout, commit/push. | 20–40 min |

**Next single action:** review candidate commit. No engine is running.
Checkout `/srv/mudds-work/hulk-continuous-walk-20261017` is retained for this
active repair; remove it on closure. Original and traced failures remain at
`/srv/mudds-work/hulk-continuous-walk-results-20261017/` and `contact-trace/`.
Root independently verified traced source/index/cache645/engine, actual isolated
engine environment and all4 owned process/socket/lane closure. Full hulk
ordinary walking and canonical packaged expedition remain unaccepted.
Latest playable remains b6af782 until a new checkpoint is actually validated.

## Working constraints

Follow [AGENTS.md](AGENTS.md): Dummy audio for every automated Godot invocation;
headless/private display, explicit x11 under Xvfb, independent abort and owned
input/process cleanup. Keep GitHub Actions disabled and respect the Windows
execution hold. Meaningful runtime/graphics checkpoints require clean Windows
EXE/ZIP/notes and strict startup exit 0 plus `STARTUP_MENU_READY_OK`; artifacts
belong in repository `builds/`. Scratch belongs under `/srv/mudds-work/`.
Project completion still requires every original promise and final-candidate gate,
or an explicit owner deferral beside that promise. No percentage from tests or commits.
