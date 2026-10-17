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

## Latest accepted result

HULK interior walk is DONE on9cffc99a2:75.93m supported ordinary movement,
all6 waypoints and full83-check regression pass. [Scope/result](docs/history/ROADMAP_DELIVERIES.md#hulk--continuous-interior-traversal-done-on9cffc99a2).
Flight/docking/fringe-rebase setup remains staged; full hulk package loop is open.

## Current task: WORLD-SOLO[Ember completed source journey] — READY

**Contract definition DONE:** recovered the original completed-mode job at
`dee132c65776396f0b360f16ec8b21c8e42765b8`: separate cold import600s, route3600s,
no fixed-FPS override, exact52-assertion success. Current harness bytes match that
historical script. [Exact invocation and gates](docs/EMBER_LOOP_SOAK.md#completed-survey-and-physical-return).
The prior900s/fixed60 attempt onfe7575fef remains incomplete at streamed final
approach (754rebases,215km remaining). Its cap is not the original contract;
this is execution of the recovered original, not a changed gameplay deadline.
Raw prior run/private save preserved; temporary checkout removed.

**One outcome:** Arrow physically completes yard launch→Ember landing→walked
relay survey/one durable reward→reboard/ascent→home berth/usable exit. One initial
on-foot yard placement, fixture animations0.04/0.08/0.06s and production API calls
remain disclosed. Current source alone; package, native/rendered/device/menu,
interruption, repeat/shared and full release requirements remain separate.
**Owner:** root, sequential supervised execution. No new implementation needed.

| Step | State / exact finish line | Estimate |
| --- | --- | --- |
| Freeze and cold import | READY; clean pinned source/engine, no `.godot`, fresh private import profile; import exit0/no diagnostics within600s, tracked source/index unchanged. Freeze generated cache. | Up to10 min plus5 min setup |
| Full completed journey | GATED; fresh separate route profile, original3600s command, exit0, zero diagnostics, exact52 marker and catalog result; inspect actual paid store and physical continuity/home result. Stop at first failure. | Up to60 min; no deadline extension |
| Close | GATED; verify inputs/actual process/socket/lane closure, remove disposable clean checkout, record accepted or precise failure, commit/push. | 10 min |

**Next single action:** create a clean owned checkout of the selected full
commit and launch the cold-import stage using the existing supervisor. Record
actual owner PID/start ticks before waiting; retain them at handoff and never
restart solely because an observation expires. No engine is active now.
Do not run default/outbound-only, ABANDON or staged-loop mode as a substitute.

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
