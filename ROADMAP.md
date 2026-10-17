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

## Current task: HULK[continuous interior traversal] — acceptance FAILED

**Result:** implementation `a97723864` replaces waypoint teleports with ordinary
held movement on the existing 73.713m six-point interior route. The first full
300s-cap check stops at waypoint1: the Player stays at (-96,21.80265,-450).
Shelf support, waypoint0 and the static doorway ray pass. **52 checks pass,
one fails**; continuous walking remains unaccepted. No runtime fix is claimed.

| Step | Result |
| --- | --- |
| Implement | DONE; existing test uses Begin Shift, one shelf placement, normal input and live capsule/hulk support checks. |
| Verify | FAILED; first attempted movement leg stalls. Original caps, route and collision retained. |
| Close this attempt | DONE; raw failure retained, guards/owned teardown verified, clean checkout removed. |

[Actual result and scope](docs/history/ROADMAP_DELIVERIES.md#hulk--continuous-interior-traversal-acceptance-failed).
Original flight/dock setup is staged; this check cannot qualify the full packaged
expedition. Latest playable remains b6af782.

## Next bounded task: HULK-DIAG[shelf stall contact]

**Hypothesis:** physical capsule contact blocks movement; source review found
no camera/menu gating in enabled on-foot Player input. Contact is not proven.
**Owner/files:** root, same existing `tests/abandoned_hulk_loop_test.gd`.
**Deliverable:** identify the actual rejecting owner from one stalled leg.
**Estimate:** 10–20 min instrumentation; one original-cap run plus review 10 min.

1. Add a first-stall log: raw/sampled input, active physics/embodiment, velocity,
   slide collider path/normal/depth/travel. No new framework or changed gameplay.
2. Run the same full suite once at its original 300s cap, headless/Dummy, guarded
   clean source/private profiles and existing process supervisor.
3. Stop after the trace identifies collision, suppression or one missing fact;
   record a concrete repair before any changed route, geometry or further run.

**Next single action:** review and run the instrumented failure branch once.
Read-only contact capture is implemented; acceptance has not been rerun. No unchanged
retry, teleport rescue, wider doorway, altered gravity or longer deadline.
The broader hulk salvage/revisit requirement remains open.

## Working constraints

Follow [AGENTS.md](AGENTS.md): Dummy audio for every automated Godot invocation;
headless/private display, explicit x11 under Xvfb, independent abort and owned
input/process cleanup. Keep GitHub Actions disabled and respect the Windows
execution hold. Meaningful runtime/graphics checkpoints require clean Windows
EXE/ZIP/notes and strict startup exit 0 plus `STARTUP_MENU_READY_OK`; artifacts
belong in repository `builds/`. Scratch belongs under `/srv/mudds-work/`.
Project completion still requires every original promise and final-candidate gate,
or an explicit owner deferral beside that promise. No percentage from tests or commits.
