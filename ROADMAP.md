# Development roadmap

The game is a playable development alpha. **All ten phase exit gates remain
open.** This file contains the next bounded production tasks and their dependencies. The
[backlog and 36-parent crosswalk](docs/ROADMAP_BACKLOG.md),
[original specifications](docs/history/ROADMAP_SCOPE_20261017.md) and
[production roster](docs/COMPLETION_SCOPE.md) retain the full project scope.
[Completed deliveries](docs/history/ROADMAP_DELIVERIES.md) retain their recorded
source, checks, failures and limitations. Moving them does not close requirements.

Latest Windows checkpoint: **9be5c83**, with [notes](builds/windows/MuddsShipyards-9be5c83-notes.txt).
Latest Linux package: **9be5c83**, with [notes](builds/linux/MuddsShipyards-9be5c83-linux-notes.txt).
Browser sessions stay visible across independent capacity generations; defense
briefing describes the physical-board controls and conditional recovery. Four
focused source suites, paired exports, three strict startups, privacy207 and
all1,515 payload-entry bytes pass. Exported proof covers startup/artifacts, not
real-host migration or the full physical defense route. Earlier journey and
installed transaction proofs retain their exact scopes.
Current full matrix: NOT_RUN;
last unfiltered matrix `f85957f` failed 11 of 1,045 suites. Focused passes do not
replace it. Native Windows execution and human review remain owner-excluded
mandatory gates, factually NOT_RUN. Other hardware/release gates remain open.

## Rules that prevent loops

- Select one named delivery with one observable outcome. Split implementation
  expected to exceed 90 minutes before starting; estimate check time separately.
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
- Schedule at most the next 3–5 concrete deliveries when their contracts are known.
  Uninstantiated backlog templates are not scheduled work or measurable progress.
- Every scheduled task must fit the task card below. A broad parent such as
  “finish planetary travel” stays in the backlog until specific children exist.
- A failed check ends the qualification task with a recorded failure. Diagnosis
  and repair are separate bounded tasks; neither silently extends the original.
  After one inconclusive diagnostic probe, report the missing fact and choose
  the next task explicitly before doing more investigation.
- After a failed task and one attempted repair, review priorities before any
  further diagnosis, repair or rerun. Record the unresolved player/build outcome,
  time spent, competing READY task and selected next action. Renaming a card or
  finding a different defect does not reset this limit. This is a scheduling
  decision, not a new permission request.
- Report progress as the named result, proof obtained, remaining action and
  revised time estimate. Planning, diagnostics and test infrastructure do not
  count as a delivered gameplay outcome.

## Required card for the next scheduled tasks

Keep cards here, beside the work, rather than creating another tracking system.
Define at most the next 3–5 tasks; refine later backlog items when their dependencies
are known. Do not turn every possible test combination into a speculative queue.

| Field | Required content |
| --- | --- |
| Task / parent | Stable short name, linked parent requirement and one concrete instance. |
| Result | One sentence describing what the player can do, what the build delivers, or which existing behavior is being qualified. Label qualification and planning explicitly. |
| Boundary | Affected component/files and explicit exclusions; new findings become separate tasks. |
| Proof | Existing command or ordinary player action, exact expected result, source/build and unchanged limits. A test count alone is insufficient. |
| Budget | Implementation/diagnosis estimate, check runtime separately, and the point at which work stops for reassessment. |
| Execution | Owner, dependency, READY/GATED/IN PROGRESS/DONE/FAILED/WAITING, one exact next action, and the action after failure. |
| Close | Actual result and limitation, commit/build reference, cleanup of owned disposable files. |

Start with tasks expected to take 30–90 minutes of implementation. Split larger
work before execution. Long established checks retain their required duration
and are estimated separately. A parent closes only when its original acceptance
holds; completing a small child does not close the parent.

## Current position

**36 broad parent outcomes remain open; the remaining executable-job count is
not yet known.** Parent scope lives in the backlog. Only named cards below are
scheduled tasks; their steps are not separate delivered outcomes. Planning and
diagnosis are reported separately from playable changes.

Recent accepted results: Ember completed physical source journey on bf452ed868,
Aurora coastal benchmark route on c47b5cd55, Linux first-install recovery/package
b41c3cc, and managed installed Guided3/3. See
[completed deliveries](docs/history/ROADMAP_DELIVERIES.md) for exact proof/limits.
These do not close their broad parents or the ten phase gates.

**Latest accepted deliveries: browser session rows and defense briefing — DONE.**
Clean source9be5c833a passes all four focused suites and paired checkpoint9be5c83.
This delivers two bounded UI outcomes; no broad parent or phase gate closes.
Fire restart qualification stays parked after its recorded failure and one
fixture repair, with both candidates unintegrated.

**Earlier accepted task: RIME-BENCH-ROUTE and checkpoint — DONE.**
Source `a8f563e39` adds select-only walking through every authored Rime survey/
return waypoint, supported by Main's real streaming/gravity owners. Focused
Rime33/default152/Ember24/Aurora27 pass. This delivers benchmark coverage,
not new planetary gameplay or native performance qualification. Paired
checkpoint `a8f563e` is published; details and limits are in delivery history.
Ember ABANDON source `e85157b4d` remains DONE (physical home dock/walk, exact31),
with packaged/durable-save/shared/hardware gates open. HULK revisit stays parked.
Sandbox, Convoy and Q4 remain parked at their recorded failures; no automatic retries.

## Earlier accepted/parked work

EMBER-ABANDON-SOURCE is DONE on `e85157b4d` (exact 31, physical home dock/walk).
HULK revisit failed its original 300 s deadline on `2298e4889`; that candidate
remains withheld, and its checkpoint is GATED. Both results and the priority
review are retained in [delivery history](docs/history/ROADMAP_DELIVERIES.md).
No unchanged Ember rerun or further HULK diagnosis/repair is selected.
Retired-directory cleanup removed 16 clean checkouts; three containing uncommitted
work remain intact, with source refs and unique raw results preserved.

## Earlier browser / Fire batch

BROWSER-CANCEL and paired checkpointa39e93a are DONE. RACE-PAGE-RESET static
diagnosis found an intentional owner separation, with no justified repair.
FIRE-RESTART failed before capture; its one viewport fixture repair failed the
same visible-row requirement. Both fixture candidates are withheld; no restart
or persistence defect/acceptance is claimed. Required priority review chose an
independent planning pass, now closed with the production queue below. No further Fire diagnosis/probe/repair/run is
selected. [Actual outcomes and archived contracts](docs/history/ROADMAP_DELIVERIES.md#fire-viewport-repair--failed-required-priority-review-complete).

Owned browser and Fire clean checkouts are removed; published builds and unique
raw are retained. Fire source38e475960 and its failed parentb5b3c5a76 are preserved
by remote hold `hold/fire-restart-viewport-20261018`. Earlier Rime/HULK/startup
failures remain parked; renaming a card does not reset the one-repair limit.

## Current batch closed — two UI changes, checkpoint9be5c83

Browser session presentation and defense briefing are DONE on clean source
`9be5c833a8608900e7af71b344be948dd5d23722`, integrated in mainb4fbeeba6.
Four focused source suites and all paired startup/artifact checks pass.
Independent final artifact audit is GO; both owned clean source checkouts are
removed. Public artifacts and unique raw remain under repository builds/ and
`/srv/mudds-work/visible-fixes-20261018/results/`. These are two scoped UI
outcomes, not whole networking/tutorial/phase completion.

## Next queue — packaged Ember abandonment acceptance

The remaining WORLD-ABANDON requirement includes a packaged physical journey.
The earlier source run on e85157b4d completed exact31 in about41m15s under the
original7200s cap, using MemoryFilesystem. That does not establish package or
durable-save acceptance. The existing unchanged driver is
`tests/ember_transit_movement_soak.gd`, SHA256
`4728e8875706b1dac77b70e0a4212007a08fda11bb114e83a4299efb80ab9f2d`.

| Task | Status / owner | Observable finish | Budget |
| --- | --- | --- | --- |
| EMBER-PACKAGE-PREFLIGHT | READY / root | Native shipped Linux ELF demonstrably loads the external original driver against packed resources, or records the exact unsupported boundary. | 20–30min setup; one owned120s preflight. |
| EMBER-PACKAGE-ABANDON | GATED on preflight / root | Exact shipped Linux package completes unchanged canonical outbound/abandon/reboard/home/walk. | 30–45min setup; original7200s route cap, prior source run41m15s. |

### EMBER-PACKAGE-PREFLIGHT — establish the actual package consumer

- **Parent/result:** [WORLD-ABANDON / PACKAGE-LINUX](docs/ROADMAP_BACKLOG.md#activities-and-planetary-journeys).
  Establish an executable native package qualification command before starting
  the long journey. This is preflight, not gameplay or route acceptance.
- **Owner/dependency:** root, with one bounded mechanical helper if useful.
  Exact public `builds/linux/MuddsShipyards-9be5c83.x86_64` and matching archive
  must retain the published SHA256. Read the original harness from source9be5c83
  and verify the hash above. No production change or new source worktree needed.
- **Boundary:** one fresh private directory containing only the unchanged raw
  driver and a tiny bootstrap that compiles/loads it without instantiating the
  journey. No loose production scripts/scenes/assets/project/cache may mask a
  missing export. Execute the actual shipped ELF; record actual executable and
  artifact hash, argv and private XDG/user-data resolution. Do not use an editor
  engine with --main-pack as a substitute and call it native-package acceptance.
- **Proof:** bootstrap emits exactly one EMBER_PACKAGE_DRIVER_READY only after
  executing and loading the exact original driver against packed dependencies;
  actual child exits0, no diagnostics, all owned children close and package bytes
  stay unchanged. Include --startup-check so an ignored external --script can
  exit at its ordinary menu: STARTUP_MENU_READY_OK alone is explicitly not a
  preflight pass. Export templates can ignore script overrides; observe rather
  than assume support. No route actors should be instantiated in this preflight.
- **Budget/stop:**20–30min setup; write exact command/expected marker before one
 120s supervised attempt. Every engine invocation headless/Dummy/private XDG,
  independent PID/start-checked abort/reap. Stop on the first unsupported/missing
  boundary and retain raw; no automatic alternate consumer, script injection,
  export modification, cap change or long-run launch. Record a separate decision
  before any repair. A failed task plus one repair requires priority review.
- **Next/close:** inspect native launcher/driver argument compatibility, prepare
  the isolated bootstrap and run once. Commit/push actual result/command in the
  existing docs, clean disposable owned scratch and preserve unique failures.
  No new build for preflight-only work. Ungate the journey only on actual proof.

### EMBER-PACKAGE-ABANDON — one unchanged physical journey

- **Parent/result:** [WORLD-ABANDON](docs/ROADMAP_BACKLOG.md#activities-and-planetary-journeys),
  Ember only. Qualify the actual native Linux package for canonical outbound,
  physical landing/exit, abandon, ordinary walking/reboard/ascent, return,
  occupied home berth, unload/disembark and supported home walking.
- **Owner/dependency:** root; GATED until preflight proves the exact consumer.
  Same frozen public9be5c83 binary/archive and unchanged driver hash. One distinct
  private journey process/profile; no loose production fallback or user saves.
- **Proof:** existing KETH_EMBER_PHYSICAL_RETURN=1, headless/Dummy/fixed-fps60;
  no completed-return or local-arrival diagnostic mode, no --startup-check in the
  journey. Preserve every original tick/landing/walk/continuity limit, fixture
  initial placement and canopy/boarding timings. Require actual exit0 and exactly
  one terminal EMBER_TRANSIT_MOVEMENT_TEST_OK with exact31, zero diagnostics,
  frozen package/driver and full process/socket closure. No extra staging,
  pose/velocity/lease rescue, shortened route or relaxed deadline.
- **Budget/stop:**30–45min setup/closure; the original route cap is7200s and
  previous source result took2474.7s. Record the exact command/environment and
  milestone receipts before launch; report only observed stages while it runs.
  Use existing supervisor/independent abort. First failure ends the task; preserve
  exact source/binary/stage, schedule any repair separately and apply the same
  one-repair priority-review rule. Do not silently extend or restart the route.
- **Close/limits:** record actual native package result and exact scopes, commit/
  push and remove owned disposable checkout/scratch. This driver uses
  MemoryFilesystem: durable disk rewards/recovery, completed survey, reuse,
  shared crew, hardware/GPU/audio/Windows/human/full-release gates remain open.
  A passing preflight alone cannot close this journey or its broad parent.

## Station finding still missing — DEFINE/GATED

STATION-FINDING[Central operational view] is DEFINE/GATED, not a READY repair.
Root needs one source-tied current image or ordinary-action reproduction showing
an actual layout/readability defect before assigning production ownership. The
bounded station/help/role read found implemented paths rather than a supported
missing behavior. Original `capture-station-operations` remains parked at0/7
images and its unchanged300s software-renderer compilation stall; that does not
identify an art defect and is not scheduled for another unchanged run.

Once usable existing source-identified evidence or a separately justified changed
capture environment exists, one30min definition task may compare one Central
view with its ordinary walk/Interact route, preserving collision/berth clearance.
It ends with one concrete finding and a separate30–90min repair card, or the exact
missing artifact. No unsupported topology, new capture workaround or speculative
signage/art task is authorized by this placeholder. Original STATION-ART/
ART-FINDING parent scope remains in the backlog.

## Later decomposition

Keep only the next3–5 executable cards here; archive closed cards in existing
[delivery history](docs/history/ROADMAP_DELIVERIES.md). Other36-parent instances
remain unscheduled in the backlog. Unknown work gets one bounded definition
child. Finishing this queue does not close the whole parent, all settings,
all networking or the ten phase gates. Do not count diagnosis, tests or build
artifacts as extra gameplay features.

## Working constraints

Follow [AGENTS.md](AGENTS.md): Dummy audio for every automated Godot invocation;
headless/private display, explicit x11 under Xvfb, independent abort and owned
input/process cleanup. Keep GitHub Actions disabled and respect the Windows
execution hold. Meaningful runtime/graphics checkpoints require clean Windows
EXE/ZIP/notes and strict startup exit 0 plus `STARTUP_MENU_READY_OK`; artifacts
belong in repository `builds/`. Scratch belongs under `/srv/mudds-work/`.
Project completion still requires every original promise and final-candidate gate,
or an explicit owner deferral beside that promise. No percentage from tests or commits.
