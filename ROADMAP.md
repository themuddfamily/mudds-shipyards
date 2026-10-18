# Development roadmap

**Status: playable development alpha; project completion is unproven.** Latest
accepted checkpoint: **2df8c31**, with ordinary Freight walking/Jovian boarding
and active gantry coexistence. [Windows build notes](builds/windows/MuddsShipyards-2df8c31-notes.txt)
and [Linux build notes](builds/linux/MuddsShipyards-2df8c31-linux-notes.txt) state
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
| Station | Nine branches; four service-motion outcomes | Habitat ordinary loop/restart and Central/Freight service coexistence accepted on recorded checkpoints. Aft/Habitat service acceptance, other branch routes and actual presentation findings remain; parked routes retain their limits. |
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

The current planning task is to remove stale assignments and leave a bounded
next card, rather than start another station-wide chain. Aft route definition
is now complete from existing source; no engine or route run was needed.

| Work | Kind / readiness | Owner and bounded next result | Estimate |
| --- | --- | --- | --- |
| LIFE-ARM | Acceptance/release capability; prepared below, not yet executed | One implementer owns the five named driver/observer/privacy files; root integrates, checks and packages. One independent reviewer checks lifecycle/input boundaries. Stop after one complete route or first failure. | 30–45min implementation/review; 10–15min focused checks/export/startup; native cap300s, outer360s |
| HAULER-CARGO-MANIFEST | Production behavior; GATED on HAULER-CARGO-STOCK | Binding admission/conserved source custody. Current source rejects Hauler; generation-floor API already exists. [Exact stock prerequisite and proof](docs/ROADMAP_BACKLOG.md#hauler-supply-integration-boundaries). No duplicate generation API or implicit stock grant. | 60–90min implementation/focused checks after decision, checkpoint additional; split before90min |

This is a local queue, not the remaining project. No Habitat-patrol, full Sandbox,
mining, ten-run activity or capture successor starts automatically after LIFE-ARM.
Review the result against its original parent and available production work first.
The bounded production-seam review found the Hauler gap above; other inspected
Hauler/Bomber/terminal-recovery policies need their recorded decisions. That is
not a claim that the entire game has no other implementation gaps.

### LIFE-ARM — prepared acceptance card

**Result:** the release driver can prove ordinary hub→Aft stairs→Zenith pilot
boarding while the existing service arm continues operating. This delivers an
executable release check; it adds no new animation or gameplay. Parent9 remains
open until its other applicable outcomes hold. Definition source:668b5b6dc.

**Owned files:** `tools/release/run_native_sortie.py`,
`tools/release/test_native_sortie.py`,
`scripts/diagnostics/native_sortie_observer.gd`,
`scripts/game/startup_loader.gd`, `tests/startup_cli_privacy_test.gd`.
Extend the shared LIFE pilot/observer with bounded route configuration; do not
copy another pilot or change world geometry, controls, cargo or ship behavior.

Use fresh ordinary Start Shift and OS input only. Existing authored goals, in order:

```text
(0,0,15.5) → (0,0,39) → (0,0,46.3) → (0,0,51)
→ (-5.7,0,51) → (-5.7,4.2,61.2) → (-3.5,4.2,61.5)
→ (-3.5,4.2,64.2) → (-3.5,4.2,68.3) → (6,4.2,68.3)
→ (13,4.2,68.3) → (22,4.2,68.3)
→ (20.2,4.2,59.2) → (18.6,4.2,58.6) → (18.2,4.2,58.2)
```

These reuse the existing Sandbox walking/Zenith approach coordinates, without
Sandbox triggers or sorties. Observe actual production Zenith candidate and
settled walking before ordinary Interact. Do not append Jovian's dynamic-marker
walk or impose its extra3.1m proximity rule: production boarding selects the
available actual candidate under its existing7m fallback reach. Never force a
candidate, active ship, boarding call, actor pose or rescue.

Observe `ShipyardWorld/OperationalLattice/Activities/AftOperationsActivity`,
SERVICE_ARM profile, and its actual shoulder/elbow/tool transform owners.
Local walking interval: stair-top(-5.7,4.2,61.2) through fleet-bridge(6,4.2,68.3).
Require actual local distance>11m and every local sample within12m of actual
arm origin(5.8,4.99,61.2). Source polyline≈18.52m/max goal distance≈11.527m
is a route definition, not measured runtime acceptance.

Require the same supported Player/capsule/shape, default tuning, enabled/visible/
processing service, nondecreasing finite clock and all three actual mover poses
changing in both local walking and seated intervals. Zenith must be the original
`Main/ZenithInterceptor`, ID `zenith_b7_observed`, home berth
`zenith_fleet_dock_berth`. Authenticate actual input→BOARDING→local pilot, then
90 seated physics frames with correct current ownership/home reservation,
OFFLINE engine and unchanged parked pose. Seat coexistence is separate from
nearby walking/readability. Read-only observation must not create seats, clean
leases, advance/seek service animation or alter authority.

Retain shared LIFE limits:15s per goal, .30m planar arrival, vertical error<.8m,
speed<.1m/s and15 consecutive settled physics samples; boarding12s; whole
route300s/outer360s. These are shared LIFE limits, not a claimed previous Zenith
per-goal deadline. Validate every emitted consecutive sample. First unexpected
failure stops execution; no automatic repair/retry or budget reset.

Checks: existing full Python driver tests, observer compile and CLI privacy;
clean paired exports, three strict startup checks and actual payload/archive
audit; ONE exact archive-extracted ordinary route using the planned
`--route life-arm` selector and `NATIVE_LIFE_ARM_OK` marker. The selector is not
implemented yet. Root owns silent/headless or isolated x11 checks and independent
abort/input/process cleanup. Review before launch; record source, actual duration
and failures. Native GPU/rendered readability/final integration remain separate.

## Latest delivered result

Freight LIFE-GANTRY is accepted on packaged2df8c31: ordinary approach, nearby
walking, Jovian boarding and90 seated frames. Central LIFE-TOW remains accepted
on9162fac with caller11c2332. Both are existing-service runtime coexistence,
not new service animations. Builds are in repository `builds/`; owned scratch
was cleaned after preserving unique results.

Full frozen cards, failures, checks and publication records live in
[delivery history](docs/history/ROADMAP_DELIVERIES.md). No completed Central or
Freight selection is reissued here. UI-BOARD-FOCUS and ordinary mining retain
their parked conditions in the [backlog](docs/ROADMAP_BACKLOG.md#baseline-scope-and-planning-children);
the successful component reproduction did not establish a production repair.

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
