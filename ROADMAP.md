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

## Last delivery: E2 · Ember surface walking benchmark — DONE

Accepted on `00ffaa045`: selectable normal walking on Main's streamed Ember
surface, with real origin rebase and production-policy gravity adapter.

| Step | Result |
| --- | --- |
| E2.1 · Preserve existing routes | Default 152 and combat 19 checks PASS; Python record tests 15 PASS. |
| E2.2 · Accept the new walk | Surface 24 checks PASS: 135.65m sampled walk, outbound/return visits, support/gravity, report and active-walk abort. |
| E2.3 · Close delivery | Independent input/process cleanup review passes; temporary checkout removed; raw results retained. |

**Remaining in E2: zero.** See [recorded result](docs/history/ROADMAP_DELIVERIES.md#e2--ember-surface-walking-benchmark-done)
and [runner usage](docs/PERFORMANCE_BENCHMARK_RUNNER.md). Full-duration/native
performance, Host journey binding and canonical planetary journeys remain open.
This tools/test-only delivery leaves the latest playable at b6af782.

## Selecting the next delivery

After E2 closes, select a named production gap from the backlog and write its
outcome, component, dependencies, acceptance, estimate and stop point here.
Do not automatically launch another diagnostic or expand benchmark coverage.
A newly found E2 defect gets one bounded repair card before an unrelated task.
Unresolved capacity choice, missing original Settings artifacts and missing
Aurora reproduction inputs remain in the backlog; do not ask again without new information.

## Working constraints

Follow [AGENTS.md](AGENTS.md): Dummy audio for every automated Godot invocation;
headless/private display, explicit x11 under Xvfb, independent abort and owned
input/process cleanup. Keep GitHub Actions disabled and respect the Windows
execution hold. Meaningful runtime/graphics checkpoints require clean Windows
EXE/ZIP/notes and strict startup exit 0 plus `STARTUP_MENU_READY_OK`; artifacts
belong in repository `builds/`. Scratch belongs under `/srv/mudds-work/`.
Project completion still requires every original promise and final-candidate gate,
or an explicit owner deferral beside that promise. No percentage from tests or commits.
