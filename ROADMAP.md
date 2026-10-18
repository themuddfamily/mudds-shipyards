# Development roadmap

**Status: playable development alpha; project completion is unproven.** Latest
accepted checkpoint: **f2bf35a**, with ordinary Aft walking/Zenith boarding
and actual service-arm coexistence. [Windows build notes](builds/windows/MuddsShipyards-f2bf35a-notes.txt)
and [Linux build notes](builds/linux/MuddsShipyards-f2bf35a-linux-notes.txt) state
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
| Station | Nine branches; four service-motion outcomes | Habitat ordinary loop/restart and Central/Freight/Aft service coexistence accepted on recorded checkpoints. Habitat patrol, other branch routes and actual presentation findings remain; parked routes retain their limits. |
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

LIFE-ARM is accepted on packaged `f2bf35a`; its ordinary route and actual controller
step proof passed. Source merged, checkpoint published, owned scratch cleaned.
LIFE-PATROL is selected for implementation and bounded validation under the
card below. Root owns integration/checks/packages; source work is isolated in
`/srv/mudds-work/life-patrol-20261018/source`.

| Remaining work | Readiness | Next bounded action / estimate |
| --- | --- | --- |
| LIFE-PATROL | SELECTED; source definition DONE, runtime NOT_RUN | Shared LIFE configuration plus actual Habitat door input,22 walking goals and original Torrent boarding. Five files, exact card below. Estimate30–45min implementation/review plus10–15min checks/package; original route CAP300/outer360. |
| HAULER-CARGO-MANIFEST | Production gap; GATED on HAULER-CARGO-STOCK | Current binding rejects Hauler; generation-floor API already exists. [Stock prerequisite and conserved-source proof](docs/ROADMAP_BACKLOG.md#hauler-supply-integration-boundaries). 60–90 min implementation/focused checks after decision, checkpoint additional; split before 90 min. |

The Hauler stock/custody decision remains the concrete missing prerequisite for
the reviewed independent production alternative. Do not invent stock, a duplicate
generation API or a whole-game absence-of-defects claim. This queue is local,
not a project estimate. No full station/Sandbox/activity/capture chain follows.

### LIFE-PATROL — prepared Habitat runtime card

Parent9. Definition source `a9c9c4244`; one bounded read-only mapper and root
confirmed the existing route/door/shared-driver seam, without engines or edits to
runtime. This is definition only. Executable outcome: ordinary fresh hub→Habitat
local walking→return→original Torrent boarding while actual patrol drones continue.
No new animation, room, locomotion, cargo or bunk/restart capability is needed.

One implementer owns only `tools/release/run_native_sortie.py`,
`tools/release/test_native_sortie.py`,
`scripts/diagnostics/native_sortie_observer.gd`,
`scripts/game/startup_loader.gd`, `tests/startup_cli_privacy_test.gd`.
Root owns integration/checks/packages; one independent reviewer checks actual
input/door/boarding lifecycle. Reuse `LifeTowPilot` configuration and narrow
observer, not another copied pilot/observer or a replay of Habitat sleep/restart.

Exact ordered22 walking goals (world X,Y,Z):

```text
(0,0,12.5) → (6,0,12.5) → (6,0,13.5) → (34.8,0,13.5)
→ (34.8,0,15.5) → (43,0,15.5) → (46,0,15.5) → (48,0,15.5)
  [normal Habitat door aim / Interact / OPEN and portal-clear wait]
→ (50.5,0,15.5) → (59.15,0,15.5) → (67.8,0,15.5)
→ (59.15,0,15.5) → (54.1,0,15.5) → (50.5,0,15.5)
→ (48,0,15.5) → (46,0,15.5) → (43,0,15.5)
→ (34.8,0,15.5) → (34.8,0,13.5) → (6,0,13.5)
→ (6,0,12.5) → (0,0,12.5)
  [existing LIFE-TOW actual Torrent walk_offset approach and ordinary boarding]
```

Use actual `ShipyardWorld/HabitatSpine/MainAccess`, initially CLOSED/blocked,
unlocked; authored motion.55s. Read only current door ID/path/position/state,
`is_open()` and pure `is_portal_blocked()`, plus actual station candidate.
Reuse HabitatLoop's candidate/aim/OS-E/wait mechanics. Keep supported ordinary
walking/continuity checks active during door aim/wait; a door-stage E cannot count
as the later board-stage press. Authenticate the actual
candidate receipt and native press before OPEN/unblocked; no door setter or forced
candidate. Door aim/wait shares the existing door-near goal's15s clock, without
resetting it; next goal starts its normal15s clock after clear. Keep the same door
open/unblocked on return. No automatic close/reopen retry or Garden Bay branch.

Observe `OperationalLattice/Activities/HabitatServicePatrol`, DRONE_PATROL,
seed3301, actual origin(59.15,4.88,15.5). The two actual `_drone_roots` are
`PresentationRoot/AnimatedServiceDrone01` and02, with retained visible drawn
meshes/global poses. Observer config uses no gantry/arm movers and appends these
two roots. Require same current activity/movers, enabled/visible/processing,
finite nondecreasing clock and both poses changing in local and seated intervals.

Local interval is only goal9(50.5,0,15.5)→goal11(67.8,0,15.5), named
`patrol_inner_threshold`→`patrol_common`. Source polyline17.3m/max goal distance
≈9.932m is definition, not runtime proof. Require actual supported local walk>11m
and every local sample within12m of the live origin. Seat is distant: prove
continued patrol coexistence, not nearby seated placement/readability.

Board original `Main/TorrentInterceptor`, definition `torrent_provisional`,
occupied/reserved `central_berth`. Reuse actual LIFE-TOW `walk_offset` approach
and actual ship candidate within3.1m planar before ordinary Interact; do not append
the raised BoardingPoint as a ground walking goal. Authenticate actual OS press→
BOARDING→START_ENGINES/local pilot at retained real pilot anchor, then90 seated
physics frames. Same ship/Player/capsule/shape/default tuning/physical support,
OFFLINE engine and unchanged parked pose/home ownership persist. No seat/lease
creation, actor placement, animation seeking or authority mutation by observer.

Keep full-stream consecutive validation and retained completed-motion/actual
step proof through shared route configuration, as accepted for Aft; no blanket
movement-limit increase or PlayerController change. Keep15s per goal, .30m planar,
vertical error<.8m, speed<.1m/s and15 consecutive settled samples; boarding12s from
final hub goal, route CAP300/outer360. Existing Habitat/Tow passes retain their
scopes and deadlines; these per-goal limits are shared LIFE limits, not a newly
claimed historical Habitat deadline. First unexpected failure STOP.

Before execution: freeze clean source and independent source review; root runs
observer compile, CLI privacy and full existing Python driver suite, then fresh
paired exports/three strict menu-ready startups/actual payload/archive audit and
ONE archived `--route life-patrol` attempt (`NATIVE_LIFE_PATROL_OK`). These selectors
are not implemented yet. Unchanged Player step-up suite remains accepted onf2bf35a;
no replay is needed without a relevant change. Estimate30–45min implementation/
review plus10–15min checks/package; split before90min. No broad station tour or
automatic successor, native hardware/rendered/full-parent closure or CI dispatch.

## Latest delivered result

**Aft service-arm runtime coexistence accepted on `f2bf35a`.** The same supported
Player completes 15 authored walking goals, 18.303 m local walking within 12 m of the
arm, ordinary Zenith boarding and 90 seated physics frames. All three actual
service movers/clock advance in both intervals; home berth/OFFLINE/parked state
persists. One genuine controller step event accounts for the stair approach;
the ordinary displacement limit and actual movement remain unchanged.

Full player-step suite, 74 Python tests, observer/privacy, fresh paired exports,
three strict menu-ready startups and 1,521-entry audit pass. The changed archived
route passes in 52.812 s guarded, zero diagnostics, full input/process cleanup.
[Windows checkpoint ZIP](builds/windows/MuddsShipyards-f2bf35a-checkpoint.zip)
and [notes](builds/windows/MuddsShipyards-f2bf35a-notes.txt) are published.

[Full result and frozen contract](docs/history/ROADMAP_DELIVERIES.md#aft-service-arm--actor-proven-ordinary-route-accepted)
retain the original failed route, both test-only corrections, cumulative budgets
and actual actor proof. Thirteen terminal owners/69 process identities absent;
14 private-profile files/helpers archived, owned source/profile/extraction removed.
Only unique results remain. This is executable release capability/acceptance,
not new service animation or locomotion tuning. Central/Freight retain their
recorded earlier-source acceptance; Habitat patrol, rendered/hardware/full-station
and all 36 parents/ten phase gates remain OPEN. UI/mining and unrelated parked
failures retain their exact reopening conditions in the backlog/history.

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
