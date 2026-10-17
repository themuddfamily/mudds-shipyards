# Development roadmap

The game is a playable development alpha. **All ten phase exit gates remain
open.** This file contains the active delivery only. The
[backlog and 36-parent crosswalk](docs/ROADMAP_BACKLOG.md),
[original specifications](docs/history/ROADMAP_SCOPE_20261017.md) and
[production roster](docs/COMPLETION_SCOPE.md) retain the full project scope.
[Completed deliveries](docs/history/ROADMAP_DELIVERIES.md) retain their recorded
source, checks, failures and limitations. Moving them does not close requirements.

Latest Windows checkpoint: **b6af782**, with [notes](builds/windows/MuddsShipyards-b6af782-notes.txt).
Latest Linux package: **b41c3cc**, with [notes](builds/linux/MuddsShipyards-b41c3cc-linux-notes.txt),
including first-install and update interruption recovery. The last paired gameplay checkpoint is
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

## Linux first-install interruption recovery — DONE

Fresh ordinary CLI retries now recover the named first-install publication cut
using the existing validated ownership journal. Actual before-fix retry refused;
after-fix source and actual shipped-manager retries succeed while preserving
settings/saves/notes/unrelated files. Source53663cc12; packageb41c3cc. Installer12,
export pipeline23, actual shipped manager36 checks/9 commands pass. Direct and
archive-extracted native startup each exit0 + exactly one STARTUP_MENU_READY_OK,
no diagnostics. Source/index/engine/cache guards pass; all57 recorded identities
absent, lanes free. Clean worktrees and duplicate ELF removed; raw evidence kept.
[Artifacts, proof and limits](docs/history/ROADMAP_DELIVERIES.md#linux-first-install-recovery--shipped-on-b41c3cc7a).
Old unjournaled orphan entries remain refused; other kill cuts/power loss,
desktop gameplay, hardware and full matrix stay unqualified. No Windows build.

## Convoy position probe — DONE; original qualification still FAIL

The one original300s print-only probe timed out124 after70 passing checks.
Seventeen Main lifetimes returned; their synchronous add_child cost192.606s,
existing post-add_child waits40.965s. The17th returned298.534s, before the first
`missed_abort` check. No game assertion error or Convoy-specific repair candidate;
known generic Main cost alone does not justify another profile. This diagnosis
is stopped/parked. [Raw result and limits](docs/history/ROADMAP_DELIVERIES.md#convoy-restore--one-position-probe-qualification-still-fail).
Declared-source/index/engine/cache guards pass, all6 recorded identities absent,
lanes free, trace patch retained and clean temporary checkout removed.

## Next delivery: managed installed Linux ELF Guided route

**One result / qualification:** a real managed installation of b41c3cc can run
the unchanged Guided walk/board/fly/combat/return/land/shutdown/exit route3/3,
then uninstall without touching protected files. Parent:
[INSTALL-LINUX / direct ELF ordinary route](docs/ROADMAP_BACKLOG.md#recovery-packages-captures-and-release).
Existing b41 startup/update checks and earlier archive/direct Guided results do
not qualify this managed installed-path context.

**Boundary:** published b41c3cc archive, its exact shipped manager, new private
prefix/applications directories with spaces, and unchanged
`tools/release/run_native_sortie.py` SHA256
`a63a3dd9c35d91f9985e5cf4d3b731c081a1a2ecd13e9178fc66e2532f61c991`.
No runtime/driver/route/waits/tuning changes. Original OS XTest → private X11 →
Godot Input/default sampler, x11/Dummy/rendering-driver dummy/disabled render
loop, independent abort and owned input/process cleanup. Desktop-entry launch,
rendered/native GPU, physical devices, Sandbox/Settings are separate.

| Task | Exact finish line / stop | State / estimate |
| --- | --- | --- |
| INSTALL-GUIDED-PREPARE | Actual shipped manager CLI installs the actual archive in private managed prefix; exact installed ELF/manifest/digests/modes/desktop and protected sentinels recorded. | READY;1–2 min actual check, helpers prepared syntax-only |
| INSTALL-GUIDED-RUN | Existing original Guided3/3, fresh profiles/processes, each original300s cap with345s outer cleanup cap. Preserve all phases,91 neutral shutdown frames and physical exit criteria; zero diagnostics; release/reap input/game/display. Stop first failure. | GATED on install; normally3–5 min, original caps unchanged |
| INSTALL-GUIDED-CLOSE | Exact installed payload/manager/archive and protected files unchanged through runs; actual manager uninstall/repeated uninstall succeed; guards/lane/owned-process closure, record scope, commit/push and cleanup. | GATED on passes;5–10 min |

**Owner:** root freezes/runs/interprets; `installed_guided_preparation` prepared
only raw helpers (no execution/engines). Raw existing guarded-driver adaptation:
`/srv/mudds-work/linux-installed-guided-results-20261017/`.
**Next single action:** freeze a clean source checkout and launch the guarded
install/Guided3/3/uninstall workflow after helper review. No engine active now.
No new build is needed; use exact published ELF/archive hashes.
All ten phase gates remain open. Q4/Convoy remain parked without a justified
construction candidate. Latest paired gameplay checkpoint remains b6af782;
Linux package isb41c3cc.

## Working constraints

Follow [AGENTS.md](AGENTS.md): Dummy audio for every automated Godot invocation;
headless/private display, explicit x11 under Xvfb, independent abort and owned
input/process cleanup. Keep GitHub Actions disabled and respect the Windows
execution hold. Meaningful runtime/graphics checkpoints require clean Windows
EXE/ZIP/notes and strict startup exit 0 plus `STARTUP_MENU_READY_OK`; artifacts
belong in repository `builds/`. Scratch belongs under `/srv/mudds-work/`.
Project completion still requires every original promise and final-candidate gate,
or an explicit owner deferral beside that promise. No percentage from tests or commits.
