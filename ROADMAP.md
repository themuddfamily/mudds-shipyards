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
consumed HUD, host confirmation and all three actual exits0. Shared departure/
braking now PASS on96c96312f in132.562s: host5.004m physical departure, freed
berth and zero-speed stop with both clients retained. Broader flight/return and
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
boarding only. The added departure/brake qualification passes on96c96312f;
return, dedicated headless server and endurance stay open.
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
- **Latest departure qualification:**96c96312f PASS in132.562s after the one
  caller-field repair. Host moves5.004238m forward, physically releases berth,
  consumes throttle/brake and stops at0m/s. Pilot/passenger hull errors are
  0.489777m/0m against the stopped host; both seat-anchor errors0m. Exact
  identities/authority/HUD remain current; all peers actualexit0, marker1, diag0.
  Capability integrated; no game runtime change or unchanged checkpoint rebuild.
- **Latest return repair:**37cbc7a4e FAIL in142.090s at the8s request-acceptance
  boundary. Release/neutrality and client identities pass; host request serial0,
  result/handoff absent. Physical landing/arrival stay unqualified; source held.
- **Static finding:** the immediate InputEventAction command is drained locally
  but remote forwarding reads only later physics snapshots. The mapping itself
  is intact; failed-run admission at pulse time remains unobserved.
- **Next:** focused old-runtime reproduction and bounded command-delivery repair,
  accepted checkpoint, then one unchanged original return qualification. No extra probe.
- **Earlier delivered:** browser per-session generations and accurate defense
  briefing on9be5c83 retain their source/UI scopes.
- **Parked:** Fire restart, Rime shared arrival, HULK revisit, Sandbox recovery
  walk, Convoy/Patrol startup and Q4/Q5 retain their failures and repair limits.
- **External waits:** original Settings artifacts, original Aurora arrival bundle
  and final capacity choice. The original server/two-client baseline remains
  authorized independently; do not ask settled questions again.
- **Cleanup:** owned clean checkouts/profiles/helpers for the recorded slices,
  including both failed return attempts, are removed. Unique raw/source refs and
  public builds remain. Three older checkouts with unique uncommitted work stay
  protected. Scratch belongs under `/srv/mudds-work/`.

Report the named result, actual proof, next action and estimate. Source checks,
planning or test totals do not establish whole-parent or hardware completion.

## Next slice — retain immediately sampled client landing edges

NET-JOVIAN-LANDING-INPUT-DIAG is DONE as static diagnosis. InputEventAction's
supported compatibility path samples/drains a landing-bearing command immediately
in GameFlow, while remote forwarding reads only HeroShip's later physics snapshot.
The immediate command has no route to the helm counter. Source mapping is intact.
[Code finding and retained uncertainty](docs/history/ROADMAP_DELIVERIES.md#landing-input-diagnosis--immediate-command-misses-remote-forwarding).
The failed run did not capture pulse-time producer output, so this is a supported
code gap, not proof of every event in that run. A focused old-runtime regression
must demonstrate the loss before accepting any repair; no unchanged probe runs.

| Task | Type / status / owner | Observable finish | Budget |
| --- | --- | --- | --- |
| NET-HELM-EDGE-FIX | Runtime fix / READY / root | One valid immediately sampled landing edge reaches the current client's remote helm exactly once and is revoked by source/session boundaries. | Implementation/review45–75min; focused import/compile/checks separate. |
| CHECKPOINT-HELM-EDGE | Build / GATED on fix / root | Fresh playable Windows/Linux checkpoint contains the accepted command-delivery repair. | Preparation/checks15–25min; original export/startup caps separate. |
| NET-JOVIAN-RETURN | Qualification / GATED on fix+checkpoint / root | Original ordinary shared return docks physically and both retained clients consume committed arrival. | Compose/freeze5–10min; compile and one original300s route separate. |

### NET-HELM-EDGE-FIX — capture the actual sampled command for remote forwarding

- **Parent/result:** parents16/26; repair GameFlow's supported InputEventAction/
  replay input path so an immediately sampled landing command is retained for the
  confirmed remote helm before later neutral sampling. No native physical-key
  failure is established; do not widen that claim or substitute physical keys to
  hide the supported compatibility-path loss.
- **Evidence/owner:** LocalShipInputSource553 applies then clears explicit edges;
  ShipCommandSource94 retains a detached GameFlow FIFO entry. GameFlow9051–9069
  queues/samples/drains it synchronously. HeroShip660 updates last_ship_command
  only in physics. GameFlow12199–12209 increments remote landing/roll counters
  only from that physics snapshot, and8959 merely shows pending landing feedback.
  No command_produced capture exists in GameFlow. A later neutral snapshot cannot
  recover the already-consumed edge.
- **Boundary/ownership:** root owns `scripts/game/game_flow.gd` and extends the
  existing `tests/command_consumer_delivery_test.gd`. Share one capture/deduplication
  owner between immediate/FIFO delivery and physics polling, or bind a bounded
  equivalent existing delivery seam. Preserve current live confirmed pilot/source/
  authority/stream checks, monotonic sequence and stream initialization, send
  cadence/clock hold/rate limits, session teardown and source invalidation. Do not
  double-count one command observed by both consumers or let an old source edge
  revive after focus/pause/migration/replacement. No wire/schema/authority/input
  timing/pose change and no additional source queue, validator or event framework.
- **Proof:** extend existing production-consumer fixture with distinct immediate
  command and later neutral physics command under a declared staged confirmed
  client session. Exercise actual GameFlow event/FIFO consumer, observe the source's
  produced landing command, and require remote serial/wire identity exactly once
  after later neutral sampling. Preserve claim/source ownership. Repeated polls,
  stale/non-owner snapshots and source/session invalidation must not replay it.
  Expected old-runtime failure first, then same regression green; do not pre-set
  remote counters, inject a network request or replace the immediate path with a
  manually populated physics snapshot. Component staging is not ordinary-route proof.
- **Checks/budget/stop:** implementation/review45–75min, clean source before
  engines. Existing command_consumer_delivery_test and ship_command_test on pinned
  engine, Dummy/headless, original300s suite caps; import/compile separate. One
  planned old-runtime reproduction and one repaired focused acceptance; unexpected
  failure stops for priority review. Do not broaden to parked stall/endurance or
  add a third unchanged return route to diagnose this static gap.
- **Close:** integrate accepted runtime/tests, commit/push, immediately create
  CHECKPOINT-HELM-EDGE. The earlier return failure/repair remain cumulative and
  return stays unqualified until its separately gated unchanged original route.

### CHECKPOINT-HELM-EDGE — playable accepted command-delivery repair

- **Parent/result:** parents6/32; exact clean accepted runtime, pinned Godot/templates.
  Existing safe Windows/Linux exports with correct private versioned XDG template
  mapping; verify actual debug/release paths before engines. Preserve HOME/CODEX_HOME.
- **Proof:** relevant focused checks, EXE/ZIP/notes and Linux ELF/archive/notes,
  actual payload-byte parity, exact archive members/modes/content and metadata.
  Direct Linux, archive Linux and Windows payload strict headless/Dummy startup
  each actualexit0+exactly one STARTUP_MENU_READY_OK/no error or leak diagnostics.
  Original matrix diagnostic policy; retain raw root notice without an invented gate.
- **Budget/stop:**15–25min preparation/checks; export900/startup300 caps separate,
  one export/platform; first failure stops with retained raw. No unchanged rerun.
- **Close:** repository builds only, actual player-visible/input-path changes and
  validation limits in notes, commit/push indices, clean owned checkouts/profiles.
  Native Windows/GPU/device/audio/human/full-release gates remain unperformed.

### NET-JOVIAN-RETURN — unchanged qualification after supported input repair

- **Parent/result:** parents16/26; gate on accepted runtime+fresh checkpoint above.
  Compose held37cbc7a4e caller with accepted runtime; retain its complete input
  pulse and original [physical return contract](docs/history/ROADMAP_DELIVERIES.md#ordinary-shared-return--input-release-boundary-failed).
  No replacement input, route or artificial local landing request.
- **Proof:** original normal menus/all13+interior goals, real chairs/current identity/
  authority/HUD,5m departure/brake, free-home capture, one landing_assist pulse,
  host request8s, physical strict docking/lease/commit120s, client consumed arrival/
  body/hull5s. Existing private-Xvfb/x11/Dummy input-only matrix, original300s total/
  360s outer; actual allpeerexits0, original marker1, no diagnostics, source/cache
  guards. Preserve all original10/10/5/12/8s prerequisites and snapshot criteria.
- **Budget/stop:** compose/freeze5–10min; compile and one original route separately.
  First failure ends FAILED; required priority review before any more action.
  Original failed task plus repair remain counted; no new diagnostic run belongs here.
- **Close:** integrate caller only after acceptance, commit/push exact outcome and
  clean owned checkout/profiles, retain unique raw. No stand/exterior/reuse/
  native/package/endurance or whole-parent/phase claim from this source qualification.

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
