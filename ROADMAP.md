# Development roadmap

The game is a playable development alpha. **All ten phase exit gates remain
open.** This file contains the next bounded production tasks and their dependencies. The
[backlog and 36-parent crosswalk](docs/ROADMAP_BACKLOG.md),
[original specifications](docs/history/ROADMAP_SCOPE_20261017.md) and
[production roster](docs/COMPLETION_SCOPE.md) retain the full project scope.
[Completed deliveries](docs/history/ROADMAP_DELIVERIES.md) retain their recorded
source, checks, failures and limitations. Moving them does not close requirements.

Latest Windows checkpoint: **ad596e4**, with [notes](builds/windows/MuddsShipyards-ad596e4-notes.txt).
Latest Linux package: **ad596e4**, with [notes](builds/linux/MuddsShipyards-ad596e4-linux-notes.txt).
Remote pilot seating and confirmed helm release now refresh the consumed
network HUD through the existing live-session guard. Focused physical Main/HUD44
and role-publication3 pass; paired exports, three strict menu startups and all1515
identical payload-entry bytes pass. The focused fixture stages admission/host
roles. The latest normal-spawn/two-client run passes pilot/HUD but fails B’s
passenger craft label; full boarding stays unqualified. Flight/return/endurance
and earlier native observer smoke stay open.
Current full matrix: NOT_RUN;
last unfiltered matrix `f85957f` failed 11 of 1,045 suites. Focused passes do not
replace it. Native Windows execution and human review remain owner-excluded
mandatory gates, factually NOT_RUN. Other hardware/release gates remain open.

## Current position and next action

**36 broad parents and all ten phase gates remain open.** The
[concrete child inventory](docs/ROADMAP_BACKLOG.md#concrete-child-outcomes)
separates named outcomes from missing definitions; it is not a remaining-job
count. **The physical Jovian passenger-seat repair is delivered. The ordinary
two-client boarding attempt FAILED. Both lifecycle cards PASS on frozen d7be01487.**
**Pilot HUD ownership is repaired and checkpointad596e4 is published.**
**The next task fixes the confirmed passenger’s wrong craft label.**
The full ordinary two-client boarding route is still unqualified.
VIP remains FAILED/parked after its first attempt and one syntax repair.
The passenger-seat and pilot-HUD outcomes close only their named scope; no
parent or phase gate closes.

- **Latest source delivery:** ad596e474 publishes consumed pilot/craft status
  after physical seating, completed cabin stand and confirmed helm/departure
  handoffs, preserving live-client/retired-session guards. Physical Main/HUD44
  and role-publication3 pass, with staged admission/host roles.
- **Latest checkpoint:** ad596e4 Windows EXE/ZIP/notes and matching Linux
  ELF/archive/notes are published with strict startup and artifact acceptance.
  The physical Jovian passenger-chair delivery6262749 remains included.
- **Latest qualifications:** LIFE-VISIBLE completes four cycles/24 rest-state
  snapshots with zero phantom failures in211.028s. LIFE-REUSE completes twelve
  sorties/all nine physical berth returns/three Main re-entries in205.716s,
  stable resources and teardown1→1 nodes/zero orphans. Both actual exit0 and
  original diagnostics0. Staged headless source behavior, not packaged ordinary play.
- **Latest ordinary route result:** one cbbebd715 run FAILED in134.850s. Both
  clients complete the station approach; A passes pilot seating/current HUD and
  host authority, B is locally seated passenger but status names Torrent.
  All first failures/.done/actual exits1 are retained. The held caller is pushed
  and unmerged; no source runtime change or unchanged export follows this run.
- **Next:** fix the demonstrated crew craft-label owner with a focused regression,
  publish its accepted checkpoint, then attempt the unchanged original boarding
  qualification once. No extra diagnostic or speculative authority repair.
- **Earlier delivered:** browser per-session generations and accurate defense
  briefing on9be5c83 retain their source/UI scopes.
- **Parked:** Fire restart, Rime shared arrival, HULK revisit, Sandbox recovery
  walk, Convoy/Patrol startup and Q4/Q5 retain their failures and repair limits.
- **External waits:** original Settings artifacts, original Aurora arrival bundle
  and final capacity choice. The original server/two-client baseline remains
  authorized independently; do not ask settled questions again.
- **Cleanup:** owned clean Ember, VIP, Jovian, lifecycle and pilot-HUD source
  checkouts are removed; unique raw results/public builds remain. Three older checkouts with
  unique uncommitted work stay protected. Scratch belongs under `/srv/mudds-work/`.

Report the named result, actual proof, next action and estimate. Source checks,
planning or test totals do not establish whole-parent or hardware completion.

## Next slice — correct the confirmed passenger craft label

The original boarding qualification on cbbebd715 is FAILED after one134.850s
run. A now passes ordinary pilot seating/PILOT-Jovian and current host authority.
B is locally seated at Jovian's copilot anchor with current identity and PASSENGER
role, but its consumed craft remains Torrent. The full passenger predicate and
final dual-seat host confirmation have not passed. [Exact result and original
contract](docs/history/ROADMAP_DELIVERIES.md#ordinary-jovian-boarding--passenger-craft-label-failure-oncbbebd715).

| Task | Type / status / owner | Observable finish | Budget |
| --- | --- | --- | --- |
| NET-CREW-HUD-CRAFT | Runtime fix / READY / root | A confirmed Jovian passenger sees Jovian in network status even when the previous pilot craft remains selected. | Implementation/review20–30min; focused checks/import/compile separately. |
| CHECKPOINT-CREW-HUD | Build / GATED on1 / root | Fresh playable Windows/Linux checkpoint contains the accepted label fix, with strict startups and exact artifact checks. | Preparation/checks15–25min; original export/startup caps retained. |
| NET-JOVIAN-BOARD | Qualification / GATED on1–2 / root | Both ordinary clients retain their real Jovian seats, current identity/authority and correct consumed HUD, with actual exits0. | Compose/freeze5–10min; compile and one original300s route separately. |

### NET-CREW-HUD-CRAFT — derive crew presentation from the confirmed seat

- **Parent/result:** parents16/25; fix the demonstrated PASSENGER/Torrent label
  while B is physically seated in Jovian. This is a presentation repair, not a
  new seat or authority. A's accepted pilot HUD behavior must remain intact.
- **Evidence/owner:** `_network_local_role_presentation` derives role from the
  live crew seat but always derives craft name/ID from `active_ship`. A passenger
  need not replace the prior pilot selection. The retained B snapshot proves
  the visible mismatch; `ShipCrewSeat.get_ship()` exposes the actual seat owner.
- **Boundary:** root owns `scripts/game/game_flow.gd` and the existing
  `tests/network/game_flow_hud_network_status_test.gd`. Resolve craft name/ID
  through the confirmed crew presentation owner, preserving pilot/observer and
  invalid/released-seat fallback. Do not mutate `active_ship`, claims, controls,
  seat authority, protocol or physical movement to make a label match.
- **Proof:** extend the existing confirmed-crew regression with distinct prior
  pilot craft and actual crew-seat craft. Its expected pre-fix mismatch must
  reproduce the recorded defect, then confirmed callback status names Jovian
  after the repair, release/fallback stays correct, and pilot/retired-session
  checks remain green. Use the existing HUD network suite and
  `tests/game_flow_network_role_publication_test.gd`, Dummy/headless, original
  limits and clean recorded source. Do not substitute a manual role publication
  or staged selection equal to the occupied craft for the production callback.
- **Budget/stop:**20–30min implementation/review; source import/compile/checks
  separately. Any unexpected failure or failed repair check stops for priority
  review. The planned old-runtime regression is defect reproduction, not another
  ordinary-route probe. No extra diagnostic run is scheduled.
- **Close:** integrate only accepted runtime/tests, commit/push, immediately build
  CHECKPOINT-CREW-HUD; clean owned disposable files and retain unique raw.

### CHECKPOINT-CREW-HUD — playable checkpoint of the accepted label repair

- **Parent/result:** parents6/32; root uses the existing safe export workflow on
  the accepted clean runtime commit. Freeze exact source/engine/templates first.
- **Artifacts/proof:** repository `builds/windows/` EXE/ZIP/notes and matching
  Linux ELF/archive/notes. Relevant focused checks, payload-entry byte parity,
  exact archive/ZIP members/modes/content and source metadata; direct Linux,
  extracted Linux and supported Windows-payload strict silent startups each
  require actual exit0 plus STARTUP_MENU_READY_OK. Native Windows/hardware and
  full-release gates retain their unperformed scope. No Downloads/hosted CI.
- **Budget/stop:**15–25min preparation/checks, original900s export and300s startup
  budgets. One export per platform; first failure stops with its owner/remaining
  action. Do not regenerate unchanged artifacts to erase a failed check.
- **Close:** publish exact local artifacts and honest notes, commit/push indices,
  remove owned clean export checkout/profiles and keep actual raw acceptance.

### NET-JOVIAN-BOARD — original qualification after the supported runtime repair

- **Parent/result:** parents16/26, Phase7 first server/two-client slice; gate on
  the two accepted cards above. Pilot HUD/checkpointad596e4 remain included.
- **Boundary/source:** root composes pushed cbbebd715 caller/harness/UID with the
  accepted runtime in a clean branch. The local claim-avatar correction is
  already implemented and source-reviewed; do not rewrite identity criteria.
  Main still does not contain this held caller/harness. Record exact source.
- **Proof:** explicit compile, then one unchanged original normal-spawn13-goal
  approach per client, menu joins, pilot and actual passenger chairs, current
  peer/entity/Player generations, consumed HUD/producer/host authority and actual
  OS exits0. Use existing private-Xvfb/x11/Dummy input-only runner, original300s
  total/12s pilot/8s passenger waits and original success marker. No pose writes,
  direct claims/private client actions, shortened routes or weakened predicates.
- **Budget/stop:** compose/freeze5–10min, import/compile and one route separately.
  First failure closes FAILED with original snapshots/receipts/logs; priority
  review precedes any more repair, diagnosis or rerun. Other passenger predicate
  fields were not retained in the latest failure snapshot; they remain unknown,
  not assumed passing after this one known craft-label correction.
- **Close:** integrate caller only after full acceptance, commit/push result,
  clean owned checkout/profiles and preserve unique raw. No flight, endurance,
  headless-server, native-hardware or whole-phase completion is implied.

## Held ordinary Jovian boarding qualification — FAILED

Latest held candidatecbbebd715 combines accepted runtimead596e474 with corrected
local identity proof and the previously reviewed failure capture. Import/compile
pass, but the one original-cap route fails at B's passenger confirmation.
The first shared abort names B; A and host retain their cascading waits. All
three actual peers exit1 with .done receipts; none are forced to137. No final
host passenger/dual-seat confirmation is established. This is one observed
wrong craft label, not proof that every other passenger condition passed.

**Priority review:** select NET-CREW-HUD-CRAFT, a demonstrated player-visible
presentation gap, over another diagnostic or parked VIP/Ember work. Task-root
creation through terminal qualification took495s; the route itself134.850s.
The source owner and finite repair boundary are known. The repair/checkpoint
cards above precede one further original qualification; no further run belongs
to this FAILED card. Earlier prerequisite, compile, diagnostic and repair limits
remain counted; new card names do not reset them.

Earlier exact compile and pilot-confirmation failures remain in
[delivery history](docs/history/ROADMAP_DELIVERIES.md#ordinary-jovian-boarding--runtime-failure-held-on27879aa62),
with the later [pilot-state diagnostic](docs/history/ROADMAP_DELIVERIES.md#jovian-pilot-state--diagnostic-complete-boarding-still-failed).
The accepted pilot HUD repair/checkpoint are unaffected by this new mismatch.

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
