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

## Active repair: HULK[authored disembark staging]

**Proven cause:** full-scene onset `555bf1256` shows the existing centre-shelf
placement overlaps Torrent LowerGearCollision. First `move_and_slide()` pushes
feet24→21.933 while contacting both overhead gear and shelf; later ticks trap
feet21.803. Moving-frame, recovery and containment do not cause the displacement.
Do not widen floor recovery: it correctly refuses this floor/ceiling pinch.

**Fix/component:** root, existing hulk integration test only. Use production
`settle_exit_onto_support(ship.get_exit_transform())` for the single initial
placement. Replace only the invalid centre-under-hull start point with the actual
exit; retain all five aperture/interior targets and normal capsule/input checks.
No ship/geometry/physics/speed/gravity/timeout changes. Temporary motor trace is
reverted and its exact patch/log preserved. Player runtime bytes are unchanged.

| Step | State / finish line | Estimate |
| --- | --- | --- |
| Fix staging | DONE; actual ship exit replaces unsafe berth-centre placement. | ~5 min |
| Verify | READY; full existing hulk suite original300s, headless/Dummy, exit0 plus `ABANDONED_HULK_LOOP_TEST_OK`, no diagnostics and guarded inputs/teardown. Stop at first failure. | 5–10 min |
| Close | GATED; record real path/outcome, remove clean checkout, commit/push. Test-only change needs no new gameplay checkpoint. | 10 min |

**Next single action:** commit/review exact staging diff, sync owned checkout and
run one guarded full hulk check. All five remaining authored targets, capsule
support/control and post-walk reward/persistence cases stay required. Initial
flight/docking are staged, so full packaged expedition remains open regardless.
No engine running. Latest playable remains b6af782.
Raw onset: `/srv/mudds-work/hulk-continuous-walk-results-20261017/landing-onset/`.

## Working constraints

Follow [AGENTS.md](AGENTS.md): Dummy audio for every automated Godot invocation;
headless/private display, explicit x11 under Xvfb, independent abort and owned
input/process cleanup. Keep GitHub Actions disabled and respect the Windows
execution hold. Meaningful runtime/graphics checkpoints require clean Windows
EXE/ZIP/notes and strict startup exit 0 plus `STARTUP_MENU_READY_OK`; artifacts
belong in repository `builds/`. Scratch belongs under `/srv/mudds-work/`.
Project completion still requires every original promise and final-candidate gate,
or an explicit owner deferral beside that promise. No percentage from tests or commits.
