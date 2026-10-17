# Development roadmap

The game is a playable development alpha. **All ten phase exit gates remain
open.** This file contains the next four concrete journey tasks. The
[backlog and 36-parent crosswalk](docs/ROADMAP_BACKLOG.md),
[original specifications](docs/history/ROADMAP_SCOPE_20261017.md) and
[production roster](docs/COMPLETION_SCOPE.md) retain the full project scope.
[Completed deliveries](docs/history/ROADMAP_DELIVERIES.md) retain their recorded
source, checks, failures and limitations. Moving them does not close requirements.

Latest Windows checkpoint: **a8f563e**, with [notes](builds/windows/MuddsShipyards-a8f563e-notes.txt).
Latest Linux package: **a8f563e**, with [notes](builds/linux/MuddsShipyards-a8f563e-linux-notes.txt).
Paired development checkpoint for the new source Rime benchmark selection.
Clean exports, three strict startups and privacy207 pass; all1,515 payload entries
match byte-for-byte. The benchmark requires a source checkout; exported games
exclude tools. Earlier HULK/home, Ember journey and installed recovery proofs
retain their exact source/binary scopes; no full-route proof transfers to these bytes.
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

**Latest accepted task: RIME-BENCH-ROUTE and checkpoint — DONE.**
Source `a8f563e39` adds select-only walking through every authored Rime survey/
return waypoint, supported by Main's real streaming/gravity owners. Focused
Rime33/default152/Ember24/Aurora27 pass. This delivers benchmark coverage,
not new planetary gameplay or native performance qualification. Paired
checkpoint `a8f563e` is published; details and limits are in delivery history.
Ember ABANDON source `e85157b4d` remains DONE (physical home dock/walk, exact31),
with packaged/durable-save/shared/hardware gates open. HULK revisit stays parked.
Sandbox, Convoy and Q4 remain parked at their recorded failures; no automatic retries.

## Previous batch closed — 1 accepted, 1 failed, 1 gated

EMBER-ABANDON-SOURCE is DONE on `e85157b4d` (exact 31, physical home dock/walk).
HULK revisit failed its original 300 s deadline on `2298e4889`; that candidate
remains withheld, and its checkpoint is GATED. Both results and the priority
review are retained in [delivery history](docs/history/ROADMAP_DELIVERIES.md).
No unchanged Ember rerun or further HULK diagnosis/repair is selected.
Retired-directory cleanup removed 16 clean checkouts; three containing uncommitted
work remain intact, with source refs and unique raw results preserved.

## Next batch — Rime journey with two independent crew clients

**ROADMAP-SLICE planning DONE. Four child tasks remain in this batch: one READY,
three GATED. No runtime check ran during planning.** These children implement
and qualify an executable integration route through existing gameplay; they
are not four new gameplay features. All four belong to
[WORLD-SHARED: Rime baseline](docs/ROADMAP_BACKLOG.md#multiplayer).

| Order / task | Status | Observable finish | Work estimate; separate checks |
| --- | --- | --- | --- |
| 1. RIME-CREW-ARRIVAL | READY | Host lands Halyard after canonical outbound travel; both independent crew clients walk onto Rime and physically reboard. | 60–90 min driver integration; existing arrival allowance below. |
| 2. RIME-CREW-SURVEY | GATED on 1 | One actual remote participant walks both readings, manages warmth and earns exactly one disk-backed survey record; second crew retains usable controls. | 60–90 min driver integration; one extended arrival/survey run. |
| 3. RIME-CREW-HOME | GATED on 2 | The same crew/craft continues from Mudds through survey, ascent and physical home dock, then exits to usable play. | 60–90 min driver integration; one continuous source journey. |
| 4. RIME-CREW-PACKAGE | GATED on 3 | Matching published development packages, with the complete journey demonstrated on the exact Linux package. | 30–45 min packaging setup/closure; exports, startup/privacy and one package journey separately. |

### Shared contract — fixed before implementation

- **Profile:** one independent host process, local host as Halyard pilot, and
  two independent authenticated client processes (`client`, `client_b`). Client
  is the survey participant; client_b is a companion who must also walk, exit
  and reboard. No late observer, reconnect, pilot loss or interruption in this
  baseline. The already authorized server/two-client baseline does not settle
  the separate final-release capacity decision.
- **Initial state:** same clean frozen source in all processes, fresh private
  user-data profiles, real Mudds Halyard berth and ordinary hatch/helm departure.
  Disclose existing pre-route hatch approach staging; no placement, clock skip,
  synthetic completion or cruise-distance shortcut after departure. Preserve
  exact crew-body/source identities, real origin rebases, collision and leases.
- **Existing implementation:** authenticated Rime surface exit, authored-trail
  support, heat/survey/reward and all-crew return admission already exist.
  Owners are `scripts/game/game_flow.gd`,
  `scripts/activities/rime_ice_core_survey.gd` and
  `scripts/network/network_planetary_journey_bridge.gd`. No speculative runtime
  rewrite is assigned. An actual failing production boundary becomes a separate
  bounded repair; the failed qualification stays recorded.
- **Known driver gap:** `tests/network/halyard_network_shared_planetary_cruise_test.gd`
  still expects the removed `shared_rime_surface_unavailable` refusal and
  unsupported return. Its surface orchestration currently starts only one client.
  It also places the departed craft into a 9,995 m admission envelope; that
  staging cannot qualify the promised continuous ordinary-input route.
  Existing `--rime-pad-only` / `--rime-shared-survey` modes of
  `tests/network/game_flow_landing_network_integration_test.gd` provide staged,
  in-process coverage. They cannot prove this independent continuous journey.
- **Limits:** preserve this specific shared fixture's inherited
  `EMBER_SURFACE_TOTAL_SECONDS = 2400` and its 120 s physical landing limit,
  plus all existing startup/admission/walk/cleanup limits. The 900 s catalog
  annotation in the separate `rime_visit_loop_test.gd` does not replace this
  fixture's explicit 2400 s contract. Do not increase 2400 s for the added
  crew/survey/home work; failure at that limit is retained. Where existing
  physical leg samplers are reused, retain their 48,000 outbound / 72,000
  return tick limits. Setup/check/cleanup time is separate from implementation.
- **Safety/ownership:** root integrates and runs checks; one implementation agent
  owns the existing shared fixture. Change the passenger base only if its
  orchestration seam requires it, preserving all other modes. These tasks are
  sequential because they share files and route state. Every process uses Dummy
  audio; each input peer has a private Xvfb with explicit x11. Retain an external
  abort path, input release and owned PID/start/socket/display cleanup.
- **Commands:** use pinned Godot with `--headless --audio-driver Dummy --path`
  on the clean source and `--script
  res://tests/network/halyard_network_shared_planetary_cruise_test.gd --` followed
  by the selected flag below. The orchestrator creates private input displays.
  `--rime-shared-arrival` exists but is stale; the survey/home flags below are
  proposed driver additions, not currently runnable commands. Freeze the exact
  source, command, stage assertions and outer abort deadline before each launch.

### 1. RIME-CREW-ARRIVAL — READY, implementation and qualification

- **Next action:** extend the existing shared fixture's Rime arrival path to
  start and coordinate client/client_b; replace obsolete refusal assertions
  with current ordinary hatch exit and physical reboard behavior. Replace the
  Rime branch's post-departure 9,995 m placement/attitude assignment with ordinary
  controlled flight into the same admission envelope; no direct phase/velocity
  rewrite. Stop on a demonstrated obstruction rather than introducing rescue.
  Reuse existing
  Aurora input-driven walking helpers with Rime world assertions. Keep the
  default Ember and Aurora route contracts unchanged.
- **Proof:** run `--rime-shared-arrival` once after source review. Host physically
  crosses more than 9,800,000 m and 900 rebases with zero travel staging events,
  full hull and an occupied Rime berth. Each client independently acknowledges
  the correct world, retains its original authoritative body/intent source,
  walks supported outside the cabin and reboards through the hatch. Host helm
  stays authoritative. Return is refused while either crew member is outside;
  both confirmed reboards clear that gate without starting a home journey.
  Require orchestrator and all three peer exits 0, zero route failures and the existing
  `HALYARD_NETWORK_SHARED_RIME_ARRIVAL_OK` marker, plus owned-resource cleanup.
- **Budget/close:** stop after 90 min implementation or first failed check;
  record source, actual boundary and retained raw. Commit/push accepted driver
  capability. On failure, the next task is one bounded repair specification,
  not task 2 or an unchanged rerun. No new gameplay claim follows.

### 2. RIME-CREW-SURVEY — GATED on task 1

- **Next action once ungated:** add select-only `--rime-shared-survey-route`
  to the same fixture, continuing its real arrival through the existing authored
  beacon, survey/return trails, hut warmth and ridge gauge. The host keeps the
  helm; only client is the survey participant. client_b demonstrates its own
  supported movement and may not steal the participant or award.
- **Proof:** one continuous arrival/survey run under the shared limits. Real
  elapsed cold drains the participant, ordinary hut warmth restores heat, both
  readings advance only at their actual interactions, and the existing host
  reward authority saves exactly one `rime_ice_core_record` to the host's real
  private file. Repeated interaction leaves the count at one. After route
  shutdown, a distinct fresh process reloads that same host file and observes
  the same once-only record through the existing store/authority. Preserve both
  clients' identities and supported physical reboard. Require all process exits
  0, zero failures and an unambiguous survey completion marker fixed before run.
  MemoryFilesystem, direct reward insertion and same-process reload do not pass.
- **Boundary/budget/close:** 60–90 min; no forced write failure, survey abandonment,
  cold-exhaustion recovery or restored-session cases in this baseline. Existing
  staged coverage remains separately scoped. Stop first failure, retain raw and
  name the one failed production/driver boundary; commit/push on acceptance.

### 3. RIME-CREW-HOME — GATED on task 2

- **Next action once ungated:** add `--rime-shared-home-return` to the same
  fixture, retaining task 2's full departure/arrival/survey and continuing through
  both physical reboards, host return action, actual ascent, cruise and home dock.
  Reuse Rime's existing return owner and the Aurora driver's home-route seam.
- **Proof:** run this complete source route once, without restarting or staging
  between stages. Both crew bodies stay confirmed and supported through return;
  surface lease/streaming retire correctly, the same craft occupies the real
  home berth, host shuts down and exits, and both clients regain usable supported
  walking. The survey record remains exactly one after the separate fresh-file
  reload. Require every process exit 0, zero failures, a distinct full-Rime-home
  success marker and owned-resource closure. Partial-stage passes cannot close
  this card. This is the source baseline, not late-join/endurance acceptance.
- **Budget/close:** 60–90 min integration, one unchanged-limit full route. Stop
  first concrete failure; no extra probe or rerun is bundled. Commit/push the
  exact accepted source; freeze it for task 4.

### 4. RIME-CREW-PACKAGE — GATED on task 3

- **Next action once ungated:** use the existing clean-commit export workflow
  to make matching Windows EXE/ZIP/notes and Linux ELF/archive/notes. Run direct/
  archive Linux and silent Windows-payload strict startup, existing privacy and
  exact archive/payload checks. Require startup exit 0 plus
  `STARTUP_MENU_READY_OK`. Then run task 3's unchanged full journey against the
  exact Linux package via the existing external test-wrapper/package-loading
  seam (`--package-under-test`); prove every peer uses package production resources.
- **Proof/close:** package journey meets every task 3 criterion on those exact
  published Linux bytes; artifact identity, notes and owned cleanup pass. Publish
  only to repository `builds/windows/` and `builds/linux/`, commit/push source/docs
  and remove the clean owned disposable checkout. Do not force-add binaries.
  If a required check fails, retain the last accepted checkpoint and failed raw;
  no automatic package rerun or source repair.
- **Budget/limits:** 30–45 min setup/closure; existing export caps up to 930 s
  each, three startups up to 330 s each, privacy up to 300 s, and one package
  journey with the same 2400 s route contract. Windows-payload startup through
  Linux Godot does not qualify native Windows gameplay. Hardware, rendered HUD,
  real audio, full matrix, interruption/endurance and final release remain open.

## Decomposing later work

The backlog is not yet fully decomposed. After this batch,
select at most the next 3–5 known instances. Each needs the required card above;
unknown acceptance gets one bounded definition task. Archive closed cards and
failures in existing delivery history. A planning pass has a 30–45 min budget,
no engine runs, and ends with reviewed cards and a commit/push. Planning and
benchmark diagnostics do not count as delivered gameplay or native performance.

## Working constraints

Follow [AGENTS.md](AGENTS.md): Dummy audio for every automated Godot invocation;
headless/private display, explicit x11 under Xvfb, independent abort and owned
input/process cleanup. Keep GitHub Actions disabled and respect the Windows
execution hold. Meaningful runtime/graphics checkpoints require clean Windows
EXE/ZIP/notes and strict startup exit 0 plus `STARTUP_MENU_READY_OK`; artifacts
belong in repository `builds/`. Scratch belongs under `/srv/mudds-work/`.
Project completion still requires every original promise and final-candidate gate,
or an explicit owner deferral beside that promise. No percentage from tests or commits.
