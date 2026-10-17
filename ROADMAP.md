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

## Current result: HULK[shelf stall] — unresolved

Contact diagnostic `7f2056d22` proves held input is reaching a processing ON_FOOT
Player; actual DockShelf floor contacts report 0.199348m penetration and zero
travel. Full hulk route still passes52/fails1 at its first movement leg.

**Repair candidate withheld:** admitting first-landing/floor-only contacts into
the existing bounded recovery is not causally proven. The standalone actual-size
shelf regression on unchanged controller `395a392ca` passes first landing and
ordinary walking, plus the complete Player suite. It does not reproduce the
full-scene failure. The extra fixture was reverted; both patches/raw runs are
preserved. No runtime fix, changed geometry or new checkpoint is claimed.
Clean temporary checkout removed. Latest playable remains b6af782.

## Next bounded task: HULK-DIAG[full-scene landing onset]

**Missing fact:** which motor stage first penetrates the shelf. Full Main reuses
an already-running Player; the standalone starts fresh. Existing teleport does
not clear native floor flags, moving-frame ownership or cabin containment.
Determine whether staging context or normal collision movement causes this stall.
**Owner/components:** root; existing Player motor and hulk regression only.
**Estimate:** 15–30 min trace instrumentation; one existing-cap run/review 10 min.

1. Arm a read-only trace immediately before the existing shelf placement. Record
   live capsule/shelf shapes/transforms once; each motor tick records delta,
   prior floor state, gravity/up, frame owner/transform, pre-slide pose/velocity,
   post-slide contacts/pose, post-recovery pose and final pose after containment.
2. Run the full hulk test once, original300s/headless/Dummy. Trace ends at first
   penetration plus3 ticks, bounded by the existing60 settling ticks. No extra
   standalone fixture, longer deadline, changed placement or generic rescue.
3. Stop with the first responsible stage/context and one bounded repair or exact
   missing fact. Do not integrate the withheld recovery candidate on suspicion.

**Next single action:** add this opt-in, bounded onset trace to the existing
failure reproduction. No processes are running; raw original, contact and
standalone-baseline runs are under
`/srv/mudds-work/hulk-continuous-walk-results-20261017/`.
Hulk continuous ordinary walking and full packaged expedition remain open.

## Working constraints

Follow [AGENTS.md](AGENTS.md): Dummy audio for every automated Godot invocation;
headless/private display, explicit x11 under Xvfb, independent abort and owned
input/process cleanup. Keep GitHub Actions disabled and respect the Windows
execution hold. Meaningful runtime/graphics checkpoints require clean Windows
EXE/ZIP/notes and strict startup exit 0 plus `STARTUP_MENU_READY_OK`; artifacts
belong in repository `builds/`. Scratch belongs under `/srv/mudds-work/`.
Project completion still requires every original promise and final-candidate gate,
or an explicit owner deferral beside that promise. No percentage from tests or commits.
