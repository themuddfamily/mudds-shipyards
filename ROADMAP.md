# Development roadmap

**Status: playable development alpha; project completion is unproven.** Latest
accepted checkpoint: **330a39c**, with actual host craft power percentages in the
observer HUD and bounded live network updates. [Windows build notes](builds/windows/MuddsShipyards-330a39c-notes.txt)
and [Linux build notes](builds/linux/MuddsShipyards-330a39c-linux-notes.txt) state
actual checks and limits. All 36 original parents and ten phase gates remain open.

## What separates this alpha from completion

These are scope groups, not equally sized tasks or a percentage. The
[36-parent crosswalk](docs/ROADMAP_BACKLOG.md#coverage-of-the-original-remaining-outcomes)
and [original ten phase gates](docs/history/ROADMAP_SCOPE_20261017.md) retain every
promise. Each named child and its dependencies live in the existing
[backlog](docs/ROADMAP_BACKLOG.md#concrete-child-outcomes).

| Remaining scope | Known boundary | What must be settled or delivered next |
| --- | --- | --- |
| Fleet and historical content | 17 eventual craft: 9 implemented, 8 absent | Eight SPEC→BUILD-SPLIT→CRAFT-ACCEPT chains; missing evidence/interpretation decisions precede builds. Existing nine still require their applicable full craft/art/role journeys. |
| Station | Nine branches; four service-motion outcomes | Habitat ordinary loop/restart and all four service runtime outcomes accepted on recorded checkpoints. Other branch routes and actual presentation findings remain; parked routes retain their limits. |
| Activities and combat | Twelve activities, six named combat encounters | Complete uncovered ordinary outbound/activity/reward/home journeys, then each legitimate ten-run contract. Cargo replenishment/turnover policy is unresolved; Hauler source integration is a known stock-policy-gated production gap. |
| Worlds | Ember, Aurora, Rime; 21 named shared-world cells | Canonical solo/shared returns, saves, abandonment, crew and repeat visits; source/staged passes cover only their recorded cases. Aurora originals remain waiting and Rime arrival remains parked. |
| Multiplayer | Named browser, helm, role, damage, actor and postdock cases | Dedicated server/two-client baseline, applicable role/reuse cases, original 30-minute endurance and chosen capacity. Release guest count/playing-host decision remains waiting. |
| Recovery and saves | Seven context definitions; accepted cuts retained | Four terminal-only active-run policies remain unresolved; remaining installed/ordinary cuts and migration/corrupt/unsupported data cases need their exact expected behavior and candidate. |
| Presentation, controls, audio and performance | Finite view/device/capture families | Actual defects and native measurements, real devices/audio, accessibility and applicable capture gates. Hardware/authorization dependencies cannot be replaced by headless passes. |
| Release | Existing Windows/Linux checkpoint workflows | Target-list decision, exact final integrated regression/packages/install transactions, licensing/signing and authorized distribution. Native Windows execution/human-review owner exclusions stay in force. |

**Remaining job count and finish date: unknown.** BUILD-SPLIT placeholders,
policy choices and actual visual/performance findings still have unresolved
multiplicities. Do not call a definition, qualification or checkpoint a finished
feature. Do not invent a project percentage from rows, tests or commits.

## Execution now

NET-COMPONENT-POWERS is accepted on `330a39c`, merged and packaged. The original
pose fixture failure, one sequence repair, integration budget failure and selected
codec repair remain in the [complete result](docs/history/ROADMAP_DELIVERIES.md#net-component-powers--host-output-and-bounded-live-updates-accepted).
Owned scratch is cleaned; unique results remain. No further power/network task
is selected. All four station service runtime passes retain their recorded scope.

| Remaining work | Readiness | Next bounded action / estimate |
| --- | --- | --- |
| AUDIO-CREW-REPAIR-PLAYBACK | IN PROGRESS; concrete running-game gap | Actual repair start/interruption/completion must cross correct source fields and independent repair ordering to distinct resident sounds. Complete card below; 45–75 min implementation/review, 10–20 min focused checks and 10–15 min checkpoint work, estimated rather than guaranteed. |
| HAULER-CARGO-MANIFEST | Production gap; GATED on HAULER-CARGO-STOCK | Binding still rejects Hauler; generation-floor API already exists. [Stock prerequisite and conserved-source proof](docs/ROADMAP_BACKLOG.md#hauler-supply-integration-boundaries). 60–90 min implementation/focused checks after decision, checkpoint additional; split before 90 min. |

AUDIO-MIX-DEFINE is complete as a source definition. The [finite real-output roster](docs/COMPLETION_SCOPE.md#real-output-mix-roster--audio-mix-define)
names current craft/activity/shared episodes and actual source-check limits.
Every listening case remains NOT_RUN, gated on a selected package/ordinary route,
actual output device/backend/configuration and explicit audible authorization.
No mandatory headphone/speaker matrix is invented. Ember’s airless boundary and
unspecified dormant-feed intent remain recorded. Hauler’s pending stock/custody
choice remains unchanged; do not repeat that question or invent stock.

## Next executable card: AUDIO-CREW-REPAIR-PLAYBACK

**IN PROGRESS on e383975f6.** Pre-execution source review additionally found the
router omits the four already-defined engineer repair IDs, so it drops those
captions/events before the Director. Narrow router ownership/check is included
below before edits. Existing bounded cue retirement may be used to prevent old
terminal slots suppressing the next genuine repair; no new voice/timer/authority
is introduced. The same complete player result and original stop/budget apply.

**Player result, parent30:** actual accepted Halyard engineer repair start,
interruption and completion generate distinct short sound requests and the
existing correct captions. Progress does not beep each frame. Repair truth,
resource debit and role authority remain with the existing owners.

- **Prerequisite/cause:** source definition on9ef81a348 identifies raw repair
  `status/token/progress` versus binding `sequence/repair_state`, the role-event
  gate that misses elapsed completion, and the Director’s semantic-only relay.
  Fix all three together; fabricated correctly shaped inputs cannot prove this.
- **Owner/files:** one implementation agent owns `scripts/game/game_flow.gd`,
  `scripts/audio/audio_director.gd`, `scripts/audio/semantic_audio_cue_router.gd`
  (only missing engineer repair labels), and, where required at its input boundary,
  `scripts/audio/halyard_crew_semantic_audio_binding.gd`. Extend existing
  `tests/audio/game_flow_halyard_crew_audio_integration_test.gd` and
  `tests/audio_director_test.gd`; existing engineer/role tests may provide the real
  source fixture. Independent lifecycle review; root owns actual runs/integration/
  checkpoint. No repair/role/network/save authority or protocol change.
- **Implementation contract:** observe real repair status/token/progress under
  the existing source/binding lifetime; normalize to its presentation vocabulary
  with separate monotonic repair ordering. Role-authority sequence must retain
  its meaning. Elapsed completion/interruption still forwards when it is unchanged.
  Retire ordering/dedup state on source replacement, detach/re-entry and session
  cleanup. Preserve direct normalized-input compatibility in the binding.
- **Playback:** reuse three distinct existing resident templates:
  `STREAM_UI_CONFIRM` for start, `STREAM_TARGET_DESTROYED_PRIMARY` for completion,
  `STREAM_COMBAT_ALERT_PRIMARY` for interruption, on the UI bus at existing
  authored cue levels. Dispatch
  directly through the bounded resident effect pool, with current reduced-range
  attenuation. Add no stream, voice, timer or generic caption echo; do not invoke
  public generic cue methods that would emit a second event. Match only accepted
  crew repair IDs/source; progress/unknown/invalid/stale/unbound input is silent.
- **Focused proof:** real Halyard + actual role authority + production GameFlow
  bridge + real Director dispatch. Verify real repair start, progress and elapsed
  completion, plus departure interruption, while role sequence stays unchanged;
  distinct resident request/stream/bus, once-only terminal cues, unchanged caption
  identity, progress silence, duplicate/stale rejection, ship/source switch and
  detach/re-entry. Preserve kit debit/repair results. A request spy can expose
  actual dispatch under Dummy; it is not audibility or physical-seat proof.
- **Commands/checks:** pin the clean source and use pinned Godot headless/Dummy.
  Run the changed existing Director and GameFlow crew suites plus existing
  `audio/halyard_engineer_audio_integration_test.gd`,
  `halyard_crew_role_gameplay_test.gd`,
  `audio/reduced_dynamic_range_audio_integration_test.gd` and
  `audio/semantic_audio_source_unbind_test.gd`, plus the existing
  `audio/halyard_crew_semantic_audio_router_test.gd` for repaired routing labels,
  requiring exit0 and their existing
  success markers. Freeze exact commands/budgets before execution. No real output,
  desktop run, parked physical crew route or full matrix is selected.
- **Delivery/stop:** fresh clean paired checkpoint, three strict silent package
  startups (exit0 + STARTUP_MENU_READY_OK), existing package audit and repository
  EXE/ZIP/actual notes. First unexpected failure stops for a separately selected
  causal repair; failure plus one repair requires cumulative priority review.
  Split remaining capability before90min implementation. Do not broaden into all
  semantic cue playback, new audio architecture or listening qualification.

## Turning the remaining scope into executable work

A broad parent stays open until all its original requirements are accepted; this
can coexist with many completed children. Use the backlog as the scope inventory,
then promote a child only when its result, prerequisites, file owner, proof,
estimate and stop condition are explicit, as above. **READY, WAITING and PARKED
must never appear as interchangeable “tasks left.”**

For each missing craft, SPEC must first settle the evidence/interpretation and
required capabilities. BUILD-SPLIT then names the actual hull/access, handling,
role/weapon and recovery deliveries with individual owners and proofs before
implementation. These are a checklist for decomposition, not an invented fixed
number of tasks per ship. CRAFT-ACCEPT retains the original complete craft journey.
An unresolved SPEC remains WAITING; a template or a source audit does not deliver
that ship. The already-asked Titan decision remains pending.

At each delivery, update that child’s result and remaining dependency, give actual
elapsed time against the estimate, and nominate one next action. Keep at most
three executable cards. Broader estimation becomes possible as unknown build
scope and policy choices are resolved; this planning update does not establish
a total job count or release date.

## Latest delivered result

**Host craft powers and bounded live updates accepted on `330a39c`.** An eligible
observer’s retained ENGINE OUTPUT / WEAPONS / TARGETING percentages match the
actual observed craft’s host telemetry, including critical-hull stutter and
admitted Halyard routing. Missing legacy fields clear old host powers; local
pilot/simulation/repair/motion authority stays unchanged. When a live delta is too
large, the existing full-snapshot form carries the complete update under the
unchanged 12000-byte ceiling, then normal deltas resume from that baseline.

Codec, full pose 302, independent Main/ENet 382, Halyard 70 and local HUD 104 checks
PASS. The previously failing nine-craft full/live envelopes both measure 4,656 bytes.
Fresh paired exports, all three strict menu-ready checks and 1,521-entry package
audit PASS. [Windows checkpoint ZIP](builds/windows/MuddsShipyards-330a39c-checkpoint.zip)
and [notes](builds/windows/MuddsShipyards-330a39c-notes.txt) are available.

[Full result and retained original contract](docs/history/ROADMAP_DELIVERIES.md#net-component-powers--host-output-and-bounded-live-updates-accepted)
include both failures, repairs, actual source/artifact hashes and cumulative 753.824 s
of guarded execution. All 22 terminal owners/121 observed process identities are
absent; original 96/current 102 profile files and helpers are retained, owned
worktree/profile/helpers removed. Eleven published files and exact ZIP bytes
reverified. These source/headless/fixture/package checks do not qualify ordinary
physical crew admission, full multiplayer endurance, native Windows/GPU/device/
audio, human or final-release gates. All 36 parents/ten phase gates remain OPEN.

## Parked failures and dependent work

These are unfinished outcomes, not candidates for an unchanged retry. Exact
contracts and cumulative attempt records remain in the retained history.

| Outcome | Last actual result | Condition before more work |
| --- | --- | --- |
| BREACH-INTERRUPTION /13,31,32 | Originale9/repair3c fail board arming35.365/35.638s. After accepted owner fix e3, unchanged probe c159 fails69.957s at atomic-payment commit assertion after cold Resume/one matching receipt; third cold replay NOT_RUN. | Cumulative140.961s STOP/PARK; candidates unmerged/withheld, no recovery checkpoint. No further diagnosis/repair/run, fourth automatic attempt or renamed retry selected; concrete causal fact/change required. |
| HALYARD-GUNNER-DAMAGE /11,16 | Original 51.847s and one caller repair 52.025s both fail co-pilot admission; actual new damage proof NOT_RUN. | Parked after cumulative 103.872s review. No further diagnosis/fix/run without concrete reopening fact/change; candidates unmerged, no weapon defect established. |
| HELM-YAW-HANDBACK / 18,20 | Original146.578s failure; one repair reaches cabin walking then FAIL156.016s at >=0.6m/15s. | Recorded cumulative priority review parked it. Explicit selection required before further diagnosis/fix/run; no movement cause established. |
| CABIN-PASSENGER-ROLE / 18,20 | Candidate38c079086 HUD36 and actual handback PASSENGER pass, full required route fails walking. Unmerged/withheld; no package. | Preserve full route; no acceptance narrowing or automatic second repair. |
| WALK-SALVAGE-ACCESS / 7,9 | Original61.019s plus one repair60.822s both fail outbound20; same supported Player, inspection/return NOT_RUN. | Parked after cumulative review; no further diagnosis/fix/run. INSPECT/REVISIT remain gated; concrete new fact/change required to reopen. |
| KIT-RELOAD / 13,31 | Distinct-process restore30s timeout; one boundary probe records Main ready but no returned first normal frame before deadline. | Different supported production repair must be selected; no unchanged probe, timeout increase or repeated startup profile. |
| HALYARD-BOARD / 16,26 | Two attempts fail the same seat comparison after both real seats. No runtime defect established. | Priority review parked it; no third automatic diagnosis/repair/run. |
| HALYARD-MOVING-CABIN / 16,26 | NOT_RUN; exact retained card requires supported walk/sit/stand/reseat during departure. | GATED on accepted HALYARD-BOARD. |
| HALYARD-AUTHORITY-STOP / 16,26 | NOT_RUN; exact retained card requires usable solo controls after actual server stop. | GATED on accepted moving-cabin route. |

VIP, Ember native close smoke, Rime arrival, HULK revisit, Fire restart, Sandbox,
Convoy/Patrol/Q4/Q5 and software-renderer capture stalls retain their existing
failure budgets and reopen conditions in the backlog/history. Settings originals,
Aurora original arrival bundle, final capacity, hardware/devices and signing retain
specific external waits. Do not repeat already-asked questions or infer approval.
Dedicated server/two-client baseline remains authorized independently of capacity.

## Finish rules for every next task

1. Select one named player/build outcome from the inventory. State parent, exact
   files/owner, prerequisites, proof command/action, unchanged criteria, implementation
   estimate and check duration before starting. Prefer30–60min implementation;
   split before 90min into capabilities, not arbitrary test/evidence stages.
   Before starting a further qualification chain, identify one independently
   executable production alternative or record the concrete missing definition.
   For future cards, distinguish checks protecting the changed behavior from
   larger parent journey gates before implementation; do not retroactively narrow
   a failed card's frozen acceptance.
2. Keep the selected result fixed. A new defect ends that attempt; it does not
   silently enlarge it. Record the failed outcome and remaining work. Failed task
   plus one attempted repair requires cumulative priority review before more work;
   renaming a card does not reset the budget. Reopening parked work also needs
   a named production change, changed environment, resolved dependency or new fact
   addressing its retained failure. Priority review alone is not a reason to rerun.
3. A pass ends verification. Do not repeat accepted checks without a relevant
   change or concrete unresolved concern. Qualification and planning remain labelled
   as such; prefer an identified production gap for the next implementation task.
4. At closure report: what the player can now do, whether it is source-qualified
   or packaged, what failed/remains, and the next single action. Commit/push and
   clean owned scratch. No progress percentage from tests, commits or task rows.
5. Replenish only after reviewing the result against its original parent and
   available independent product work. Report elapsed work against the selected
   card before selecting a successor; never let one session become an unbounded
   sequence of adjacent repairs. Do not append every newly discovered edge case
   to the current chain.
   Keep at most three executable cards; dependent and parked scope stays above or
   in the backlog. Preserve the original parent acceptance until fully proven.

## Validation and final release

Follow [AGENTS.md](AGENTS.md): every automated Godot invocation uses Dummy audio;
headless/private display and explicit x11 under Xvfb; independent abort and owned
input/process cleanup. Never enable or dispatch GitHub Actions. Respect the
existing native Windows execution hold. Scratch belongs in `/srv/mudds-work/`;
protect unrelated and unique work when cleaning.

Meaningful accepted runtime/graphics changes require clean paired Windows/Linux
checkpoints in repository `builds/`, focused checks and strict silent startup
exit0 plus `STARTUP_MENU_READY_OK`. Caller-only qualification does not require
an identical rebuild. Package notes state actual validation and limits.

Current full matrix NOT_RUN; last unfiltered f85957f failed11/1,045 suites.
Native GPU/device/audio/human gates remain unperformed where recorded; VM,
software-renderer or source checks cannot replace them. Project completion requires
every original promise accepted or explicitly owner-deferred beside that promise,
all applicable final-candidate gates passed, and distributed bytes matching the
qualified candidate. No broad parent or phase closes in this reorganization.
