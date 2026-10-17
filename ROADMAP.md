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

## Last delivery: HULK[continuous interior traversal] — DONE

Accepted source `9cffc99a2` walks the actual Player capsule from Torrent's
production exit through the hulk aperture, vestibule, corridor and gallery to
within the breaker's real interaction query. One initial placement; ordinary
held movement thereafter. All five original interior targets and authored
static doorway probes remain; no geometry/physics/deadline changes.

| Step | Result |
| --- | --- |
| Implement | DONE; continuous movement plus production exit staging/world-yaw aiming. Onset trace proved old staging was inside parked landing gear; temporary trace reverted. |
| Verify | DONE; full original300s-cap suite passes83 checks, exit0, zero diagnostics in observed107.0s. All6 waypoints,75.93m actual supported walk and existing reward/recovery/revisit cases pass. |
| Close | DONE; source/index/cache/engine guards and owned cleanup independently verified. Temporary checkout removed; failures/raw runs retained. |

**Remaining in this delivery: zero.** [Recorded result](docs/history/ROADMAP_DELIVERIES.md#hulk--continuous-interior-traversal-done-on9cffc99a2).
Player runtime is unchanged, so latest playable remains b6af782. This accepts
interior traversal only: flight/docking and later fringe/rebase interactions
are still staged. Physical Interact input, full canonical packaged expedition,
real-file cross-process interruption and final-candidate gates remain separate.

## Last attempt: WORLD-SOLO[Ember completed source journey] — INCOMPLETE

On `fe7575fef`, the existing completed-return mode reaches real Ember streaming
and final-approach activation, then the chosen900s wall cap expires (exit124).
Last report:214,983m remaining,754 origin shifts, live locationgeneration1/frame755.
No gameplay assertion failed before timeout; the success marker is absent.
Landing/survey/reward/return remain unqualified. Private save generation14 has
no beacon reward or completed survey. [Recorded result](docs/history/ROADMAP_DELIVERIES.md#world-solo--completed-ember-source-journey-incomplete-at-attempt-cap).

Guards and all3 recorded owned process/socket/lane closure verify. Temporary
checkout removed; raw/private save retained under
`/srv/mudds-work/ember-completed-journey-results-20261017/`.
No runtime change/checkpoint; latest playable remains b6af782. Startup remains
parked after a bounded five-file review found no justified construction candidate.

## Next bounded task: WORLD-CONTRACT[Ember completed-return long soak]

**Problem:** the selected900s attempt cap was a working bound, not the explicit
transit/ABANDON budgets documented as1800/7200s. Completed-return mode must have
an exact long-run contract before full qualification; this timeout alone neither
proves a game defect nor fails those longer contracts. Do not raise a required
acceptance deadline to obtain a pass or repeat the same900s attempt.

**Owner/files:** root; existing `docs/EMBER_LOOP_SOAK.md`, test invocation and
original scope references. Existing runtime script/tick limits stay unchanged.
**Deliverable:** one exact completed-return command with justified wall budget,
physics/input/profile requirements, actual source/build, success/failure/cleanup
conditions, and a clear distinction from outbound-only and ABANDON modes.
**Estimate:** 10–20 min definition; full required execution time separately.

1. Resolve the applicable original long-soak contract and completed mode's
   coverage, including fixture animation timings and initial placement limits.
2. Update existing usage documentation and this task card with that one concrete
   invocation/estimate. Record a named missing criterion if unresolved.
3. Stop at an executable contract; schedule the full original-duration run or a
   demonstrated production repair separately. No new validator or parallel harness.

**Next single action:** reconcile completed mode with the existing long-soak
usage/specification. No engine or other run is active. Full world/phase gates
stay open; this attempt does not count as a delivered gameplay improvement.

## Working constraints

Follow [AGENTS.md](AGENTS.md): Dummy audio for every automated Godot invocation;
headless/private display, explicit x11 under Xvfb, independent abort and owned
input/process cleanup. Keep GitHub Actions disabled and respect the Windows
execution hold. Meaningful runtime/graphics checkpoints require clean Windows
EXE/ZIP/notes and strict startup exit 0 plus `STARTUP_MENU_READY_OK`; artifacts
belong in repository `builds/`. Scratch belongs under `/srv/mudds-work/`.
Project completion still requires every original promise and final-candidate gate,
or an explicit owner deferral beside that promise. No percentage from tests or commits.
