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

## Managed installed Linux Guided route — DONE3/3

The actual shipped b41c3cc manager installed its archive in a private managed
prefix with spaces. Unchanged original Guided driver passes3/3 in50.839s,
50.035s,50.518s; all phases,91 neutral shutdown frames,0.17m exit error, zero
diagnostics. Actual uninstall/repeated uninstall preserve protected files.
Source/index/public artifacts stable, all39 recorded identities absent, three
private displays/authority paths closed, lanes free; clean checkout removed.
[Result and capture limit](docs/history/ROADMAP_DELIVERIES.md#managed-installed-linux-b41c3cc--guided33-done).
The extra observer missed native environment snapshots because of spaces in its
command parser; actual process/argument/display/route/closure records remain.
No rerun merely for paperwork. Direct installed ELF only: desktop-entry launch,
rendered/native GPU, devices, Sandbox/Settings and full phase gates stay open.

## Sandbox recovery boundary — DONE diagnosis, original route still FAIL

Retained ca0afc4 original observations show only12 frames/0.20 physics seconds
between completed regeneration/recovery_walk entry and deadline. The first
recovery waypoint40 is9.65m away; responsive turning reaches forward-input
threshold only at the final observation. No blocking geometry/control failure
is evidenced. [Recorded boundary](docs/history/ROADMAP_DELIVERIES.md#sandbox-recovery-walking--retained-observation-boundary).
No new engine run or gameplay repair claimed.

## Next bounded task: SANDBOX-PACING-CANDIDATE

**Diagnosis/planning only.** Parent: original full Sandbox normal-input/crash/
recall/reuse acceptance. Owner `sandbox_recovery_boundary`, IN PROGRESS.

| Field | Contract |
| --- | --- |
| Result | Identify one demonstrably avoidable earlier controller/input delay from original stage frames and actual observations, or report NONE. |
| Boundary | Same exact original driver and `/srv/mudds-work/ca0-sandbox-acceptance-20261017/` receipts. Read-only; inspect only longest plausible avoidable branch, no engines/edits/new profiles/validators or broad startup audit. |
| Proof | Actual frame/state/position interval plus exact driver branch supporting unnecessary waiting; total duration alone is insufficient. Preserve all54 ordered waypoints, eight sorties, real crash/recall/regeneration/recovery/reuse, default physical sampler, original waits/criteria and300s cap. |
| Budget |15 min artifact review, stop at candidate or NONE. |
| Close | Root schedules one supported correction separately, with full original acceptance; do not relabel a modified driver as unchanged. If NONE, park with no repeated run/profile. |

**Next single action:** review the assigned bounded pacing finding. No engines
active. Do not rerun accepted Guided/package/benchmark checks. All ten phase
gates remain open. Q4/Convoy remain parked without a justified construction
candidate. Latest paired gameplay checkpoint remains b6af782; Linux isb41c3cc.

## Working constraints

Follow [AGENTS.md](AGENTS.md): Dummy audio for every automated Godot invocation;
headless/private display, explicit x11 under Xvfb, independent abort and owned
input/process cleanup. Keep GitHub Actions disabled and respect the Windows
execution hold. Meaningful runtime/graphics checkpoints require clean Windows
EXE/ZIP/notes and strict startup exit 0 plus `STARTUP_MENU_READY_OK`; artifacts
belong in repository `builds/`. Scratch belongs under `/srv/mudds-work/`.
Project completion still requires every original promise and final-candidate gate,
or an explicit owner deferral beside that promise. No percentage from tests or commits.
