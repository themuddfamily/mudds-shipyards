# Development roadmap

The game is a playable development alpha. **All ten phase exit gates remain
open.** This file contains the next bounded production tasks and their dependencies. The
[backlog and 36-parent crosswalk](docs/ROADMAP_BACKLOG.md),
[original specifications](docs/history/ROADMAP_SCOPE_20261017.md) and
[production roster](docs/COMPLETION_SCOPE.md) retain the full project scope.
[Completed deliveries](docs/history/ROADMAP_DELIVERIES.md) retain their recorded
source, checks, failures and limitations. Moving them does not close requirements.

Latest Windows checkpoint: **b6196a1**, with [notes](builds/windows/MuddsShipyards-b6196a1-notes.txt).
Latest Linux package: **b6196a1**, with [notes](builds/linux/MuddsShipyards-b6196a1-linux-notes.txt).
Latest runtime source: **b6196a19a** (pushed). Confirmed crew status now takes
craft name/ID from the occupied chair's ship while retaining the pilot selection.
The old runtime reproduces the passenger mismatch; focused HUD51 and role3 pass
with no diagnostics. The repaired private export profile now produces checkpoint
b6196a1: both safe exports, three strict menu startups and exact artifact checks
pass. Original failed export logs remain retained. Ordinary two-client boarding
now PASS on fff5f7221 in127.937s: both real seats, current identities/authority/
consumed HUD, host confirmation and all three actual exits0. Flight/return and
endurance remain unqualified.
Current full matrix: NOT_RUN;
last unfiltered matrix `f85957f` failed 11 of 1,045 suites. Focused passes do not
replace it. Native Windows execution and human review remain owner-excluded
mandatory gates, factually NOT_RUN. Other hardware/release gates remain open.

## Current position and next action

**36 broad parents and all ten phase gates remain open.** The
[concrete child inventory](docs/ROADMAP_BACKLOG.md#concrete-child-outcomes)
separates named outcomes from missing definitions; it is not a remaining-job
count. **Physical Jovian passenger seating, passenger/pilot HUD repairs and
ordinary two-client boarding are delivered in their recorded scopes. Both
lifecycle cards PASS on frozen d7be01487.**
**Pilot HUD ownership is repaired and checkpointad596e4 is published.**
**The passenger craft-label source repair and checkpoint b6196a1 are delivered.**
The original ordinary two-client boarding route PASS on fff5f7221; this closes
boarding only, not flight, return, dedicated headless server or endurance.
VIP remains FAILED/parked after its first attempt and one syntax repair.
The passenger-seat and pilot-HUD outcomes close only their named scope; no
parent or phase gate closes.

- **Latest source delivery:** b6196a19a resolves confirmed crew craft name/ID
  through the actual chair owner without changing selection or authority.
  The expected old-runtime mismatch is reproduced; focused HUD51 and role3 pass,
  source/cache guards pass, independent review GO.
- **Latest checkpoint:** b6196a1 Windows EXE/ZIP/notes and matching Linux
  ELF/archive/notes pass both exports, three strict startups, all1515 actual
  payload-entry byte comparisons and exact archive/ZIP checks.
  The physical Jovian passenger-chair delivery6262749 remains included.
- **Latest qualifications:** LIFE-VISIBLE completes four cycles/24 rest-state
  snapshots with zero phantom failures in211.028s. LIFE-REUSE completes twelve
  sorties/all nine physical berth returns/three Main re-entries in205.716s,
  stable resources and teardown1→1 nodes/zero orphans. Both actual exit0 and
  original diagnostics0. Staged headless source behavior, not packaged ordinary play.
- **Latest ordinary route result:** fff5f7221 PASS in127.937s with152 checks,
  one original success marker and diagnostics0. Both clients walk all13 approach
  goals plus their interior goal, use their real chairs and pass current identity,
  consumed HUD, producer/host authority and final host dual-seat confirmation.
  All three actual peer exits0/.done failures0; source/cache guards unchanged.
  The unchanged held caller is now integrated; independent contract/result review GO.
- **Latest departure attempt:** cad7f3aac FAIL before throttle on an incorrect
  caller field; both seat confirmations pass. Physical departure/braking remain
  NOT_RUN. The failed flight capability stays pushed and unmerged.
- **Next:** one bounded caller-only field correction and unchanged original
  qualification. No speculative runtime/authority repair or extra diagnostic.
- **Earlier delivered:** browser per-session generations and accurate defense
  briefing on9be5c83 retain their source/UI scopes.
- **Parked:** Fire restart, Rime shared arrival, HULK revisit, Sandbox recovery
  walk, Convoy/Patrol startup and Q4/Q5 retain their failures and repair limits.
- **External waits:** original Settings artifacts, original Aurora arrival bundle
  and final capacity choice. The original server/two-client baseline remains
  authorized independently; do not ask settled questions again.
- **Cleanup:** owned clean Ember, VIP, Jovian, lifecycle and pilot-HUD source
  checkouts are removed; the crew-HUD checkout/profile are also removed after its
  failed export; the separate successful checkpoint checkout/profiles are also
  removed after publication. The accepted boarding checkout/profile/helpers are
  also removed after integration; the failed departure checkout/profile/helpers
  are removed with raw/source refs retained. Three older checkouts with
  unique uncommitted work stay protected. Scratch belongs under `/srv/mudds-work/`.

Report the named result, actual proof, next action and estimate. Source checks,
planning or test totals do not establish whole-parent or hardware completion.

## Next slice — repair the departure caller's consumed-pose field

NET-JOVIAN-DEPART is FAILED on held cad7f3aac after one135.794s route.
The original join/walk/seat stages and host dual-seat confirmation complete.
The new flight hook fails before throttle because it checks the wire field
owner_peer_id on a consumed sample that exposes pilot_peer_id. This is an agent
caller error; no departure or game defect is established. [Actual first failure
and frozen contract](docs/history/ROADMAP_DELIVERIES.md#ordinary-jovian-departure--caller-field-failure-before-throttle).
Main does not include the held flight caller; accepted boarding/checkpoint stay valid.

| Task | Type / status / owner | Observable finish | Budget |
| --- | --- | --- | --- |
| NET-JOVIAN-DEPART-CALLER | Caller repair / READY / root | The original departure/brake scenario checks the actual consumed pilot identity, then passes one unchanged original route or stops on its first failure. | Correction/review10–20min; original import/compile/route caps separately. |

### NET-JOVIAN-DEPART-CALLER — use the existing consumed pose contract

- **Parent/result:** parents16/26; correct only the held flight caller on pushed
  cad7f3aac87d9335b74c2a741f8fec1995e9fee7, composed with current main docs.
  Source/runtime and accepted ordinary boarding behavior remain unchanged.
- **Known owner:** NetworkRemoteCraftPoseStream.latest_sample returns normalized
  history (331); normalization676 maps wire owner_peer_id to pilot_peer_id.
  Change initial readiness, continuous-owner and convergence reads to the actual
  pilot_peer_id field; retain it in existing allowlisted receipts/failure snapshots.
  Compare the same exact host pilot ID. No aliases, runtime field/schema changes,
  weakened identity criteria or additional evidence framework.
- **Proof:** static review of the consumed contract, explicit compile then one
  unchanged NET-JOVIAN-DEPART flight route. The full original5m departure/brake,
  berth release, exact seat/entity generations, physical anchor alignment and
  client pose convergence criteria remain binding in the frozen card linked above.
  Same real joins/all13+interior goals, input-only Xvfb/x11/Dummy, original300s
  route/360s outer,10/10/5s flight phases and8s initial readiness. No extra probe.
- **Budget/stop:**10–20min caller correction/review, source import/compile costs
  separate. Exactly one repair attempt; any failure ends FAILED and requires
  priority review before more diagnosis/repair/rerun. Earlier failed attempt and
  pre-engine review corrections remain counted; this name does not reset limits.
- **Close:** integrate only after full acceptance; otherwise keep candidate held.
  Commit/push exact outcome, clean owned checkout/profile/helpers, preserve raw.
  No unchanged runtime export; latest playable checkpoint remains b6196a1.

## Earlier ordinary Jovian boarding attempt — FAILED (retained history)

Earlier candidatecbbebd715 combines accepted runtimead596e474 with corrected
local identity proof and the previously reviewed failure capture. Import/compile
pass, but the one original-cap route fails at B's passenger confirmation.
The first shared abort names B; A and host retain their cascading waits. All
three actual peers exit1 with .done receipts; none are forced to137. No final
host passenger/dual-seat confirmation is established. This is one observed
wrong craft label, not proof that every other passenger condition passed.

**Priority review:** select NET-CREW-HUD-CRAFT, a demonstrated player-visible
presentation gap, over another diagnostic or parked VIP/Ember work. Task-root
creation through terminal qualification took495s; the route itself134.850s.
The source owner and finite repair boundary were known. Completed source/build
repairs preceded accepted qualification fff5f7221; no further run belongs
to this FAILED card. Earlier prerequisite, compile, diagnostic and repair limits
remain counted; new card names do not reset them.

Earlier exact compile and pilot-confirmation failures remain in
[delivery history](docs/history/ROADMAP_DELIVERIES.md#ordinary-jovian-boarding--runtime-failure-held-on27879aa62),
with the later [pilot-state diagnostic](docs/history/ROADMAP_DELIVERIES.md#jovian-pilot-state--diagnostic-complete-boarding-still-failed).
The later label repair/checkpoint and accepted boarding qualification are recorded above.

## Parked VIP round trip — first runtime guard failure

Caller57fc1122a first failed to parse. The one syntax repair64c74dd46 compiles,
boots through the real menu and reaches four supported outward checkpoints:
Central X0, Aft spine, Aft connector and Aft lower junction. At `out/stair-base`,
the continuous movement guard rejected a0.400m horizontal/0.299m vertical step
near ContinuousStairRamp (horizontal limit0.177m); actual floor support remained
on StairBaseLanding. This does not yet distinguish normal production step
assistance from a defect. No VIP door/seat/return acceptance is established.

**Priority review:** the failed attempt plus one repair has reached its limit.
Park further VIP diagnosis, threshold changes and reruns this batch; select the
independent baseline definition, now complete above, and its Jovian boarding
child. Do not relabel a monitor change as a
new task to reset the limit. A future reopening requires one source-supported
movement contract and explicit scheduling before another probe, with unchanged
full route and900s cap. The exact route/caller/check contract and both failures
remain in [delivery history](docs/history/ROADMAP_DELIVERIES.md#vip-round-trip-contract--parked-after-one-repair).

## Parked Ember qualification — source shipped, native smoke still open

Checkpoint4270d71 contains the source-checked native observer. The exact native
normal-window-close smoke remains FAILED: first dummy-renderer close timeout,
then no visible protocol-capable window, then software-GL V-Sync warning. Required
priority review parks all further native-window work this batch; do not rerun or
filter diagnostics. The published development build has actual strict startup/
artifact acceptance, not completed native observer/journey qualification.

The unchanged external SceneTree driver remains unsupported on frozen9be5c83;
no full packaged abandonment journey ran or inherited source acceptance. Exact
contracts, all failed raw, source232/20 passes, package results and limitations
remain in [delivery history](docs/history/ROADMAP_DELIVERIES.md#ember-native-observer-checkpoint--published-with-native-smoke-open).
Native-window and full physical/durable/shared/release gates remain open.

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

## Working constraints

Follow [AGENTS.md](AGENTS.md): Dummy audio for every automated Godot invocation;
headless/private display, explicit x11 under Xvfb, independent abort and owned
input/process cleanup. Keep GitHub Actions disabled and respect the Windows
execution hold. Meaningful runtime/graphics checkpoints require clean Windows
EXE/ZIP/notes and strict startup exit 0 plus `STARTUP_MENU_READY_OK`; artifacts
belong in repository `builds/`. Scratch belongs under `/srv/mudds-work/`.
Project completion still requires every original promise and final-candidate gate,
or an explicit owner deferral beside that promise. No percentage from tests or commits.
