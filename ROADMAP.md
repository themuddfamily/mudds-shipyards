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

## Last delivery: ACT-HUD[hulk restoration instruction] — DONE

After throwing the breaker, the objective describes the bus powering up and
securing the salvaged cell. The old instruction to “Hold the gallery” incorrectly
implied a proximity requirement. Root changed the objective and corrected the
adjacent comment; timer, reward and persistence logic are unchanged.

| Step | Result |
| --- | --- |
| Correct instruction | DONE; one objective literal changed in `game_flow.gd`. |
| Verify | DONE; exact diff confirms no executable logic changes; whitespace check passes. No engine test needed for this wording edit. |
| Close | DONE; removed a verified inactive/integrated clean retired checkout (244MB logical); unique work/captures retained. |

**Remaining in this delivery: zero.** [Recorded result](docs/history/ROADMAP_DELIVERIES.md#act-hud--hulk-restoration-instruction-done).
Latest playable stays b6af782; this minor wording correction needs no new gameplay
checkpoint. Prior E2 benchmark delivery is complete in the same history document.

## Next selection

Select one named production gap from the backlog and record its outcome,
component, exact acceptance, estimate and stopping point before execution.
Hulk continuous ordinary traversal is still unqualified; its staged integration
suite cannot substitute for that acceptance. Do not rerun it unchanged merely
to increase check counts. Do not add a proximity rule absent a design requirement.
Capacity choice and missing original Settings/Aurora inputs remain waiting;
do not repeat settled questions. Full-project task count remains undefined
until unscheduled parent templates have named instances.

## Working constraints

Follow [AGENTS.md](AGENTS.md): Dummy audio for every automated Godot invocation;
headless/private display, explicit x11 under Xvfb, independent abort and owned
input/process cleanup. Keep GitHub Actions disabled and respect the Windows
execution hold. Meaningful runtime/graphics checkpoints require clean Windows
EXE/ZIP/notes and strict startup exit 0 plus `STARTUP_MENU_READY_OK`; artifacts
belong in repository `builds/`. Scratch belongs under `/srv/mudds-work/`.
Project completion still requires every original promise and final-candidate gate,
or an explicit owner deferral beside that promise. No percentage from tests or commits.
