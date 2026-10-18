# Development roadmap

The game is a playable development alpha. Latest accepted playable checkpoint:
**24430b7**, with authoritative physical remote hull/throttle gauges and the earlier
steering/cargo/control-help/layout fixes. [Windows notes](builds/windows/MuddsShipyards-24430b7-notes.txt)
and [Linux notes](builds/linux/MuddsShipyards-24430b7-linux-notes.txt) state actual validation.

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

NET-HULL-HUD is selected. Physical hull/throttle gauges remain accepted in24430b7.
The [Titan proposal](docs/design/TITAN_IMPLEMENTATION_PROPOSAL.md) awaits the
owner interpretation choice; implementation remains gated.
WALK-SALVAGE-ACCESS is parked after its original attempt and one caller repair. Reverse qualification and the bounded Torrent
definition are closed below. Completed and parked work does not occupy the
executable queue. Root owns review, integration, checks and closure.

| Task / parents | State | Observable finish | Next action |
| --- | --- | --- | --- |
| NET-HULL-HUD / 21 | IN PROGRESS implementation | Gameplay HUD hull bar/frame uses eligible host health/status, with current solo restoration and no simulation telemetry mutation. | Old-runtime actual publisher regression, bounded HUD-only decoration, full pose/real-peer checks and paired checkpoint. |
| SPEC-TITAN / 10,36 | Proposal DONE; WAITING interpretation decision | Concrete one-pilot/two-passenger/four-unit modern candidate and bounded build tasks. | Owner decision on linked proposal before runtime implementation; historical model gate stays open. |
| WALK-SALVAGE-ACCESS / 7,9 | FAILED/PARKED | Same supported Player must walk hub→inspection row→hub without staging. | Both attempts fail at outbound20; no further diagnosis/fix/run selected. |

Completed reverse/Torrent definitions and the full failed Salvage contracts now
live in [retained task closures](docs/history/ROADMAP_DELIVERIES.md#task-closures-after-remote-throttle-checkpoint--2026-10-18).
Hull repair24430b7 and throttle8f17b02 are named player-visible deliveries,
not whole-project completion. [Hull closure](docs/history/ROADMAP_DELIVERIES.md#remote-physical-hull-instruments--accepted24430b7c1) retains proof and limits.
Titan decision remains pending; no further parked-route work is selected.

### NET-HULL-HUD — remote health in the gameplay HUD

- **Player result/parent:**21; gameplay HUD hull bar/frame must reflect accepted
  host health/maximum/status for the eligible active craft. GameFlow's normal
  physics publisher currently passes local `get_telemetry()` directly to HUD.
  Physical cockpit gauges are already fixed; separate simulation telemetry must
  remain local for flight, repairs, saves and ownership decisions.
- **Owner/boundary:** one high-effort implementation agent; root plus independent
  high-risk review. GameFlow HUD publication, minimal HeroShip read-only display
  getter if needed, existing remote-pose/station-frame tests only. Already-validated
  damage projection owns the display fields; local-authority/clear/retirement must
  restore current source HUD. No wire, physics/damage/command, other HUD telemetry,
  component/power, parked-route, or new-framework changes.
- **Proof/next:** test-only existing normal physics→HUD publisher regression first,
  actual GameHUD hull bar/frame for host50/200 versus local full health. Exact new
  failures on old runtime, no new helper dependency. After root-reviewed clean fix,
  compile and full existing pose/independent Main station-frame tests (original300s,
  per-wait60s) with current/late projected damage/destruction/revival/clear HUD,
  local raw telemetry and throttle/pilot behavior preserved. Exit0/exact existing
  marker/fullraw diagnostics0. Controlled fixtures are not a full ordinary voyage.
- **Budget/stop:**30–60min implementation/review, split before90; checks separate.
  First unexpected failure stops at owner/boundary before separate bounded repair;
  original plus one repair needs cumulative priority review. No automatic retry.
- **Package/close:** fresh clean paired exports, three strict silent startup checks
  and actual package/archive audit; repository builds/ with actual notes. Commit/
  push, retain unique raw/source refs, clean owned scratch. Latest24430b7 remains
  until accepted replacement. No broad parent closes.
- **Completed speed comparison:** observer interpolation/settled pose and pilot
  reconciliation already assign replicated/corrected velocity; physical speed
  consumes that velocity. No missing speed transport or new fix was identified;
  no engine run for this bounded comparison. Do not invent another gauge task.

**Initial failure:** test-only920eb4bc0 import PASS20.693s; compile FAIL16.329s
before HUD regression. GDScript cannot infer the new `frame` variable from
GameFlow's dynamically typed HUD call. No runtime change or old-HUD proof yet.
Raw: `/srv/mudds-work/remote-hull-hud-20261018/results/baseline_compile/`.
**Selected ONE test repair:** root adds explicit Dictionary annotation to that
snapshot local only. Compile once then old-runtime regression; preserve all
acceptance and budgets. This failure and repair remain cumulative; any further
unexpected failure requires priority review before diagnosis/fix/run. Estimate
one minute edit/review, checks separate. No extra diagnostic probe selected.

**Repaired baseline:** test-only1fd8d662e compiles16.283s. Actual normal
physics→HUD regression then reproduces exactly two expected host25% bar/frame
failures in31.230s, exit1/no unrelated diagnostics. Runtime HUD-only repair may
proceed. Initial compile failure remains retained and cumulative; another
unexpected failure requires priority review, not an automatic second caller fix.

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
