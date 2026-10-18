# Development roadmap

The game is a playable development alpha. Latest accepted playable checkpoint:
**8f17b02**, with correct signed remote cockpit throttle gauges and the earlier
steering/cargo/control-help/layout fixes. [Windows notes](builds/windows/MuddsShipyards-8f17b02-notes.txt)
and [Linux notes](builds/linux/MuddsShipyards-8f17b02-linux-notes.txt) state actual validation.

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

NET-HULL-INSTRUMENTS is selected. The throttle repair remains accepted in8f17b02.
SPEC-TITAN proposal awaits the owner interpretation choice; implementation remains gated.
WALK-SALVAGE-ACCESS is parked after its original attempt and one caller repair. Reverse qualification and the bounded Torrent
definition are closed below. Completed and parked work does not occupy the
executable queue. Root owns review, integration, checks and closure.

| Task / parents | State | Observable finish | Next action |
| --- | --- | --- | --- |
| NET-HULL-INSTRUMENTS / 21 | IN PROGRESS implementation | Remote physical hull gauge matches authoritative health through damage/destruction/revival and restores current solo health on clear. | Test-only reproduction first, bounded display repair, real-peer checks and paired checkpoint. |
| NET-THROTTLE-INSTRUMENTS / 17 | DONE; checkpoint8f17b02 | Remote physical Jovian gauge shows signed host throttle, shutdown neutral and current solo restore. | Pose91, real-peer fixture203, paired exports/three strict startups/actual1515-entry audit pass; broader parent17 OPEN. |
| SPEC-TITAN / 10,36 | Proposal DONE; WAITING interpretation decision | Concrete one-pilot/two-passenger/four-unit modern candidate and bounded build tasks. | Owner decision on linked proposal before runtime implementation; historical model gate stays open. |
| WALK-SALVAGE-ACCESS / 7,9 | FAILED/PARKED | Same supported Player must walk hub→inspection row→hub without staging. | Both attempts fail at outbound20; no further diagnosis/fix/run selected. |
| CRAFT-GAPS-TORRENT / 10,11 | Definition DONE; craft acceptance OPEN | No specifically required missing implementation found within inspected owners. | Do not invent a feature; any successor needs a concrete requirement/finding. |
| HELM-REVERSE-FLIGHT / 18 | DONE, source qualification | Normal reverse moves host1.448m in888ms; fresh neutral, brake and both real replicas pass. | Closed52b228c86; original parent handback remains open. |

Completed reverse/Torrent definitions and the full failed Salvage contracts now
live in [retained task closures](docs/history/ROADMAP_DELIVERIES.md#task-closures-after-remote-throttle-checkpoint--2026-10-18).
Repair8f17b02 is a named player-visible delivery, not whole-project completion.
Titan decision remains pending; no further parked-route work is selected.

### NET-HULL-INSTRUMENTS — physical remote hull gauge

- **Player result/parents:**21; remote physical cockpit HullReadout reflects
  current authoritative hull health, not the replica's retained solo value.
  Existing damage rig/transport already receives health and maximum health;
  common instrument consumer still uses local `_hull / maximum_hull`.
- **Owner/boundary:** one high-effort implementation agent owns HeroShip and
  existing remote-pose/station-frame tests; root plus independent high-risk review.
  Display-only normalized authoritative health, immediate clear/retirement restore
  from current local health, destruction0/new-life revival. Preserve local health,
  component/physics/command authority and throttle prediction. No wire/schema,
  unrelated speed/HUD/engine/other gauge or parked-route changes.
- **Proof/next:** old-runtime test-only physical Jovian regression with exact new
  expected failures first; then reviewed clean runtime candidate, compile once
  and full existing remote-pose and independent Main station-frame tests. Actual
  current/late HullReadout after local presentation, damage/destruction/new-life
  and clear restoration; local authority and original snapshot budgets retained.
  Headless/Dummy; original300s tests/per-wait60s. Exit0/one exact existing marker/
  fullraw diagnostics0; no native/ordinary full-voyage claim from these fixtures.
- **Budget/stop:**30–60min implementation/review, split before90; checks separate.
  First unexpected failure stops for exact owner and at most one bounded static
  diagnosis before separate repair. Original plus one repair requires cumulative
  priority review; no automatic retry or acceptance relaxation.
- **Package/close:** fresh clean paired Windows/Linux exports, direct/archive/
  actual Windows-payload strict startup exit0/one STARTUP_MENU_READY_OK/diagnostics0,
  existing actual package/archive audit. Publish in repository builds/ with honest
  notes; commit/push, retain unique raw/source refs and clean owned scratch. Current
  playable8f17b02 remains until acceptance. Titan decision is still pending.

### SPEC-TITAN — concrete interpretation proposal before building

- **Owner/boundary:** one medium-effort documentation agent owns only
  `docs/design/TITAN_IMPLEMENTATION_PROPOSAL.md`; root reviews scope and runtime
  seams. Existing Titan evidence row, original fleet promise and production
  craft/definition/access/berth/recovery pipeline only. No runtime changes,
  engine runs, new research framework, invented historical silhouette or media.
- **Finish:** historical name/medium-transport role separated from unknown model,
  scale, interior, access, systems and handling; one concrete modern proposal,
  ordered30–60min capability cards with exact source owners/player checks and
  preserved full fleet acceptance. No automatic feature/capacity expansion.
- **Budget/next:**15min draft/review, then one explicit interpretation decision
  on the completed proposal before implementation. Original SPEC-TITAN evidence
  gate remains WAITING; proposal is not approved scope or a delivered craft.
- **Source:** existing ledger/matrix support only identity/role. Reopening A3
  through the web tool was inaccessible this turn; no new historical evidence
  or name-to-model claim is asserted. Owner-approved modern interpretation may
  unblock production but never authenticate its appearance.
- **Close:** commit/push the reviewable proposal, source links and actual limits;
  no checkpoint for documentation. Keep all other original craft promises open.
- **Actual result:** [Titan proposal](docs/design/TITAN_IMPLEMENTATION_PROPOSAL.md)
  written and root-reviewed against existing source/seams. Proposed one pilot,
  two passengers, four conserved repair-kit cargo units, connected cabin/hatch,
  existing pilot pulse profile and explicit trial handling. All are modern choices;
  only name/medium-transport role is historically supported. Ordered build tasks
  retain full-craft acceptance and immediate meaningful paired checkpoint policy.
  No runtime edits, engines, new evidence status, approved deferral or craft
  completion. Interpretation decision remains pending; no elapsed time implies it.

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
5. Replenish only after reviewing the result and available independent product
   work. Do not append every newly discovered edge case to the current chain.
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
