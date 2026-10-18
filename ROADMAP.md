# Development roadmap

The game is a playable development alpha. Latest accepted playable checkpoint:
**7be348d**, with authoritative remote hull HUD and physical hull/throttle gauges,
plus the earlier steering/cargo/control-help/layout fixes.
[Windows notes](builds/windows/MuddsShipyards-7be348d-notes.txt) and
[Linux notes](builds/linux/MuddsShipyards-7be348d-linux-notes.txt) state actual validation.

**Project finish: unproven. All 36 broad requirements and all ten phase gates
remain open.** This is not zero progress: accepted child outcomes remain accepted
on their recorded sources. A reliable remaining-job count or finish date is not
available while capability definitions and external dependencies are unresolved.

## Where the remaining work lives

| Question | Authoritative location |
| --- | --- |
| What was promised? | [Original scope and ten phase gates](docs/history/ROADMAP_SCOPE_20261017.md) |
| Is every promise still covered? | [36-parent crosswalk](docs/ROADMAP_BACKLOG.md#coverage-of-the-original-remaining-outcomes) |
| What are the smaller named outcomes? | [Concrete child inventory](docs/ROADMAP_BACKLOG.md#concrete-child-outcomes) |
| Which work has actually passed or failed? | [Delivery history](docs/history/ROADMAP_DELIVERIES.md), including [retained task contracts](docs/history/ROADMAP_DELIVERIES.md#working-card-records-retained-on-2026-10-18) |
| What happens next? | The execution table and selected card below. |

The inventory includes finite scenarios, unresolved definitions and external
waits. A DEFINE or BUILD-SPLIT row is not an implemented capability or a countable
remaining implementation job. Resolve those rows into finite capabilities before
estimating them. Do not change the shipped roster or defer promises without an
explicit owner decision.

## Execution now

Only the selected card below is executable. A missing definition, failed route
or full-craft qualification is not an implementation assignment. Do not create
a successor chain just because a nearby check can be added.

NET-OPERATION-HUD is selected from a concrete source finding under parent17:
the existing publisher overlays host hull, but engine/throttle HUD consumers
still read retained local telemetry. Physical throttle instruments are already
accepted; this card changes the gameplay HUD only. Ember's bounded definition
is complete with no missing authored content identified. Titan remains pending.

| Task / parent | Kind / state | Observable finish | Next action |
| --- | --- | --- | --- |
| NET-OPERATION-HUD /17 | Production fix; test-only regression first | Eligible observer HUD follows accepted host engine/throttle; local pilot prediction and raw simulation stay intact | Reproduce actual normal-publisher HUD discrepancy, then reviewed repair and checkpoint. |

### NET-OPERATION-HUD — engine and throttle in the gameplay HUD

- **Player result:** eligible remote observer sees accepted host engine label,
  throttle magnitude and signed direction; STARTING/OFFLINE/destruction show
  neutral thrust. This machine's pilot keeps its local predicted operation HUD.
  Clear/disable/retirement restores current local readings.
- **Source finding:** GameFlow::_publish_active_ship_telemetry_to_hud merges only
  the accepted hull projection into raw get_telemetry. HUD consumes throttle and
  engine_state directly. HeroShip already retains accepted operation facts and
  applies the observer/pilot policy to physical throttle instruments. No missing
  transport or new wire contract is implied. Source finding is not runtime proof.
- **Owner/files:** one high-effort implementer plus independent high-risk review;
  root freezes/tests/integrates. Only scripts/game/game_flow.gd,
  scripts/ships/hero_ship.gd and existing remote-pose/station-frame tests.
  Read-only display getter and HUD publication seam; raw engine/throttle/health,
  components, saves, controls, physics and command authority stay unchanged.
  No component/power/weapon/landing HUD fields, parked routes or new framework.
- **Proof:** test-only host ONLINE/+65% against retained local OFFLINE/zero,
  actual normal physics publisher and actual engine label/throttle bar/direction.
  Exact expected new failures first. Then forward/reverse, STARTING/OFFLINE/dead,
  local pilot prediction, stale/lifecycle/clear and raw authority invariants in
  full existing pose suite; actual current/late received facts in independent
  Main station-frame suite. Explicit fixture publisher calls are disclosed and
  do not claim an ordinary remote-helm journey. Original300s/per-wait60s caps,
  exit0/exact existing markers/fullraw diagnostics0 unchanged.
- **Budget/stop:**30–60 minutes implementation/review, split before90; import,
  compile, focused pose (~41s) and real-peer (~174s) checks separate. First
  unexpected failure stops before diagnosis/fix/run selection; original plus
  one repair requires cumulative priority review. No automatic successor.
- **Close:** reviewed clean source commit, fresh paired Windows/Linux exports,
  three strict silent startups and actual payload/archive audit; publish under
  repository builds/. Commit/push, preserve unique results and clean owned
  checkout/profiles/helpers/duplicate exports. All broad parents/phase gates open.

## Parked failures and dependent work

These are unfinished outcomes, not candidates for an unchanged retry. Exact
contracts and cumulative attempt records remain in the retained history.

| Outcome | Last actual result | Condition before more work |
| --- | --- | --- |
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
   split before90min into capabilities, not arbitrary test/evidence stages.
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
