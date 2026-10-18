# Development roadmap

**Next: finish 16:10 qualification and the archive-placed on-foot recovery cut.**
The game is a playable development alpha. **All 36 broad requirements and all ten
phase gates remain open.** This file holds the executable queue; the
[named backlog](docs/ROADMAP_BACKLOG.md#concrete-child-outcomes),
[36-parent crosswalk](docs/ROADMAP_BACKLOG.md#coverage-of-the-original-remaining-outcomes),
[original specification](docs/history/ROADMAP_SCOPE_20261017.md) and
[delivery history](docs/history/ROADMAP_DELIVERIES.md) retain full scope/results.

## Current delivered position

| Outcome | Actual proof / limit |
| --- | --- |
| Immediate client landing edge retained exactly once | Runtime `2c73494a4`; old-runtime failure reproduced, consumer40/ship_command79 pass. Source/ownership/session boundaries revoke pending input. |
| Fresh playable checkpoint **f90547c** | [Windows notes](builds/windows/MuddsShipyards-f90547c-notes.txt), [Linux notes](builds/linux/MuddsShipyards-f90547c-linux-notes.txt). Adds on-foot release-driver support; both exports, three strict startups,1515 matching payload entries and exact archives pass. |
| Ordinary two-client Jovian short sortie and physical home return | Source `4c9c764e9` PASS in138.915s: normal boarding/real seats,5m departure/brake, accepted landing, strict home dock/lease/landed commit and both retained clients consume original pilot/ownership generations and arrival. All three peers exit 0; marker 1; diagnostics 0. |
| Earlier passenger chair/HUD, lifecycle, browser/briefing deliveries | Retain their recorded scopes; no whole craft, parent or phase closes. |

The eight-card batch is closed: reproduction, runtime repair, checkpoint, shared
return and four bounded definitions. Definitions are planning, not extra game
features. The return's first`331a9628b` attempt FAILED at a client ownership predicate;
one reviewed caller-only correction reads the received authoritative snapshot.
Failed raw, original criteria and cumulative repair counts remain retained.
The accepted caller changes no game runtime; checkpoint `f90547c` now adds the accepted on-foot release-driver capability.
No identical rebuild or unchanged route rerun is scheduled.

**Still unqualified:** dedicated server, postdock exit/reuse, canonical shared
world journeys,30-minute endurance, devices/native GPU/audio and final release.
Current full matrix NOT_RUN; last unfiltered f85957f failed 11 of 1,045 suites.
Native Windows/human-review owner exclusions remain factual NOT_RUN.

## Next four cards

**2 DONE, 2 IN PROGRESS.** These are the current bounded deliveries, not the remaining
whole-project job count. Root owns integration. Do not reopen parked failures.

| Task | Type / state | Observable finish | Work estimate; checks separate |
| --- | --- | --- | --- |
| RECOVERY-ONFOOT-PROBE | Release capability / DONE (source scope) | Existing exported recovery driver admits and observes a genuine settled exterior on-foot save/resume context. |45–60 min implementation/review; explicit compile and focused source checks≤300s each. |
| CHECKPOINT-ONFOOT-PROBE | Build / DONE | Fresh paired package contains the accepted on-foot driver capability. |15–25 min preparation/artifact work; export≤900s/platform and startup≤300s each. |
| RECOVERY-ONFOOT-CUT | Recovery qualification / IN PROGRESS | Real-file on-foot commit survives owned SIGKILL/distinct restart into supported walking and real boarding beside the saved craft. |10–20 min freeze/driver preparation; existing package-probe limits separate and unchanged. |
| ACCESS-PAUSE-16X10 | UI qualification / FAILED at binding-conflict visibility | Actual Main pause/options views remain readable, reachable and focused at1920x1200 and the three authored scale choices. |30–45 min existing-fixture coverage/review; one original300s source check. |

The three recovery cards are sequential. UI work can proceed independently in
an isolated checkout with disjoint ownership. A failed card ends at its first
concrete boundary; one attempted repair requires priority review before more work.

### RECOVERY-ONFOOT-PROBE — support the missing release-driver context

- **Parents/result:**2/31/32. The existing runtime already saves a four-field
  home-berth preference for settled on-foot play; it stores no player pose. The
  release driver's allowed contexts currently reject on_foot. Deliver this
  executable package/release capability, not another evidence format.
- **Ownership:** `scripts/game/startup_loader.gd`,
  `scripts/diagnostics/in_world_interruption_probe.gd`,
  `tools/release/run_package_probes.sh` and the smallest relevant existing checks
  such as `tests/startup_cli_privacy_test.gd`. Use existing GameFlow capture/apply
  and UserDataStore owners; change runtime recovery only for a reproduced defect.
- **Boundary:** add on_foot to the existing isolated silent driver path. Preserve
  pilot/cabin/rest/crew/engineer behavior, unsafe CLI rejection, private profile/
  Dummy requirements and normal startup isolation. Arm a named nondefault craft's
  genuine settled exterior preference through the production capture/commit seam;
  do not fabricate saved payload, player position, berth/seat authority or rewards.
  The selected convoy case discloses its existing craft-motion fixture and a
  craft-only home-approach placement; production landing/lease, pilot exit and
  supported exterior capture must establish the saved context. This does not
  qualify an ordinary full flight home.
- **Proof:** the old boot contract rejects this context; new focused admission/
  source-probe checks require the supported four fields, correct actual supported
  player state and explicit arm/resume observation. Compile and relevant existing
  checks on a clean pinned source. Do not rerun parked whole session recovery/Q5.
  Source-driver proof does not close real OS interruption or packaged acceptance.
- **Execution:** DONE/root at `f90547c37`, after recorded failure/one type repair.
  Source driver PASS: actual arm SIGKILL/reap, distinct resume0, supported walk
  0.525555m, ordinary Interact boarding, receipts1→2 exactly once; source/cache
  stable and processes closed. This does not close exported-game acceptance.
  Original candidate `b5e2b00a5` passed static review and
  import but explicit compile exits1: forward/right types cannot be inferred
  at probe lines1232/1233. CLI not run. One bounded repair adds only explicit
  Vector3 annotations at `f90547c37`: compile PASS and CLI249 PASS, source/cache
  stable. Priority review selects one existing source-driver on_foot+convoy
  arm/resume check next, before paying for packages; competing full UI sweep
  stays queued. Exact `--source --in-world-interruption --activity=convoy`,
  context on_foot, Dummy/headless,300s per stage/660s outer, first failure STOP.
  Source invocation passed; original failure/repair counts remain. Inspect existing arm/resume branches and freeze the
  on-foot case contract from the [completed definition](docs/ROADMAP_BACKLOG.md#settled-exterior-on-foot-recovery-contract).
  Budget45–60 min; split before 90 min. First unexpected result stops for review.
  Commit/push accepted production capability; immediately build the next card.

### CHECKPOINT-ONFOOT-PROBE — ship the accepted release capability

- **Parents/result:**6/32; gate on clean accepted probe source. Pin Godot/templates,
  correct private versioned XDG template mapping, preserve HOME/CODEX_HOME.
- **Proof:** existing safe sequential Windows/Linux exports; EXE/ZIP/notes and
  matching ELF/archive/notes; actual PCK byte parity, exact members/modes/metadata,
  stock PE .text. Direct/archive Linux and actual Windows payload each strict
  headless/Dummy startup actualexit0+exactlyone STARTUP_MENU_READY_OK/no original
  error/leak diagnostics. Native Windows execution is not implied.
- **Execution:** DONE/root on accepted clean source `f90547c37`; both safe exports,
  three strict startups, actual payload parity/archive/stock PE checks pass.
  EXE/ZIP/notes and matching Linux artifacts are in repository builds/.
- **Budget/stop/close:**15–25 min preparation/checks, original900s exports/300s
  startups separately. One export/platform, first failure stops with raw retained.
  Publish only repository builds; commit/push notes/index, then qualify the cut.

### RECOVERY-ONFOOT-CUT — actual installed/archive interruption and usable return

- **Parents/result:**2/31; gate on exact package supporting on_foot and existing
  release-driver contract. Choose one existing supported activity/debt boundary
  and named nondefault craft/home berth; retain its existing limits and criteria.
- **Proof:** actual real-file settled exterior preference committed before the
  armed signal; own/reap real SIGKILL, then a distinct same-profile process accepts
  ordinary Resume/Begin Shift. Fresh craft/home-berth support is valid, player is
  awake/unseated/controls enabled with no stale seat/hatch claim. Walk through
  normal input and Interact to board that craft; activity/debt/earned-reward state
  remains conserved/once-only. No airborne position or arbitrary power-loss claim.
- **Execution:** IN PROGRESS/root. Freeze accepted `f90547c` Linux ELF, SHA256
  `5c0cfb46f1aa0a42bb9bdc087dfe9aec6fba6a5038425f197e282c0bb5dc17d9`,
  existing runner `--native-export --in-world-interruption --activity=convoy`,
  on_foot/private headless/Dummy, original300s/stage and660s outer. One run;
  no automatic repair. The direct repository ELF invocation PASSES, including
  real SIGKILL/distinct restart, supported walk/Interact and receipts1→2.
  The card title also requires installed/archive placement: keep that part OPEN.
  After the independent UI run closes, extract the audited exact archive to an
  owned install directory, verify ELF bytes and copy its immutable export metadata,
  then run the existing native-export driver once at that actual extracted path.
  This retains300s/stage/660s outer; desktop-menu installation stays separate.
  Preparation10–20 min; stage checks retain
  existing release-driver bounds. First failure closes FAILED; no extra probe or
  automatic correction. Preserve raw/process/input closure; commit/push actual
  scope and clean owned scratch. Native hardware/device/audio remain separate.

### ACCESS-PAUSE-16X10 — one missing production-window layout case

- **Parents/result:**12/29. Existing Main ultrawide layout coverage omits16:10;
  a gameplay-only SubViewport check does not cover pause/options Controls.
- **Ownership/boundary:** extend existing `tests/ultrawide_layout_test.gd` for the
  selected1920x1200 case and required authored scales0.75/1.0/1.6 and pause/options
  states from the [finite view roster](docs/ROADMAP_BACKLOG.md#pauseoptions-view-and-cell-roster).
  Reuse existing HUD layout/focus/rebind/display/repair owners and checks. No new
  harness/validator, speculative UI redesign or full settings/device matrix.
- **Proof:** actual Main Window/viewport, visible Control safe bounds/font floor,
  options scrolling and focus/confirmation return remain usable. Record requested
  and effective pause scale; its authored fit ceiling is valid behavior. This
  source-layout result does not qualify physical controllers or all rendered views.
- **Execution:** FAILED/root. Original `dd4ff0353` same-frame options re-entry
  failed; one fixture correction `4128526c9` uses separated ordinary buttons,
  whose diagnostic passes159 assertions. One corrected full300s invocation
  then fails at requested0.75/binding_conflict: focused Replace button rectangle
  (681.75,1815.75,252.75,24) is outside visible bounds; scroll450. Eighteen
  observations run; later states/scales NOT_RUN. Actualexit1, source/cache stable,
  owner closed. Coverage is integrated; no production HUD fix is bundled.
- **Priority review:** after the initial failure and one fixture correction,
  stop UI diagnosis/repair here. Finish the archive recovery placement first.
  The next production task must fix this exact visible conflict/focus outcome,
  with original full selected300s acceptance; no repeated general UI audit.

## Parked work and external waits

VIP, Ember native close smoke, Rime arrival, HULK revisit, Fire restart, Sandbox
recovery, Convoy/Patrol/Q4/Q5 and the two software-renderer capture stalls retain
their original failures/reopen conditions. No unchanged retry is selected.
Settings originals, Aurora original arrival bundle and release capacity choice
remain existing external waits; do not ask settled questions again. The dedicated
server/two-client baseline remains authorized independently of larger capacity.
Bomber comparison now identifies one further precise interpretation: additional
role/count, concrete navigation action and physical access are unspecified. It
is not an approved pilot-only deferral; no invented crew feature is scheduled.

Owned helm/return checkouts, profiles/helpers and duplicate builds are removed;
unique raw/source refs and public builds remain. Three older dirty retired
checkouts remain protected. Scratch belongs under `/srv/mudds-work/`.

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
- Keep at most eight bounded cards visible; run only READY cards and at most one dependent
  chain at a time. Review priorities before replenishing the queue.
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
Keep at most eight cards in this queue; refine later backlog items when their
dependencies are known. Do not turn every possible test combination into a speculative queue.

| Field | Required content |
| --- | --- |
| Task / parent | Stable short name, linked parent requirement and one concrete instance. |
| Result | One sentence describing what the player can do, what the build delivers, or which existing behavior is being qualified. Label qualification and planning explicitly. |
| Boundary | Affected component/files and explicit exclusions; new findings become separate tasks. |
| Proof | Existing command or ordinary player action, exact expected result, source/build and unchanged limits. A test count alone is insufficient. |
| Budget | Implementation/diagnosis estimate, check runtime separately, and the point at which work stops for reassessment. |
| Execution | Owner, dependency, READY/GATED/IN PROGRESS/DONE/FAILED/WAITING, one exact next action, and the action after failure. |
| Close | Actual result and limitation, commit/build reference, cleanup of owned disposable files. |

Prefer tasks expected to take 30–60 minutes of implementation; 90 minutes is
the split boundary, not a target. Split larger
work before execution. Long established checks retain their required duration
and are estimated separately. A parent closes only when its original acceptance
holds; completing a small child does not close the parent.

## Working constraints

Follow [AGENTS.md](AGENTS.md): Dummy audio for every automated Godot invocation;
headless/private display, explicit x11 under Xvfb, independent abort and owned
input/process cleanup. Keep GitHub Actions disabled and respect the Windows
execution hold. Meaningful runtime/graphics checkpoints require clean Windows
EXE/ZIP/notes and strict startup exit 0 plus `STARTUP_MENU_READY_OK`; artifacts
belong in repository `builds/`. Scratch belongs under `/srv/mudds-work/`.
Project completion still requires every original promise and final-candidate gate,
or an explicit owner deferral beside that promise. No percentage from tests or commits.
