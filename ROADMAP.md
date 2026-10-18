# Development roadmap

The game is a playable development alpha. Latest accepted playable checkpoint:
**da1ae60**, with remote observer engine/throttle HUD, authoritative hull HUD
and physical gauges, plus earlier steering/cargo/control-help/layout fixes.
[Windows notes](builds/windows/MuddsShipyards-da1ae60-notes.txt) and
[Linux notes](builds/linux/MuddsShipyards-da1ae60-linux-notes.txt) state actual validation.

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

HALYARD-GUNNER-DAMAGE is selected as a bounded source qualification.
WEAPONS-DEFINE now has a finite actual binding roster and acceptance distinctions.
NET-OPERATION-HUD is accepted in the current checkpoint; its full contract and
actual checks are in [delivery history](docs/history/ROADMAP_DELIVERIES.md#remote-operation-hud--acceptedda1ae60).
Ember, Aurora and Rime definitions found no missing implementation within their
inspected authored-content scopes; full-world acceptance remains open. The [Titan proposal](docs/design/TITAN_IMPLEMENTATION_PROPOSAL.md) remains
unapproved; parked failures remain outside the queue.

| Task / parent | Kind / state | Observable finish | Next action |
| --- | --- | --- | --- |
| HALYARD-GUNNER-DAMAGE /11,16 | FAILED original seat step; damage NOT_RUN | Actual existing ordinary gunner FIRE produces one authority damage result | One static admission-boundary comparison capped at10 minutes; no engine/repair/rerun selected. |

### HALYARD-GUNNER-DAMAGE — one real hit through the existing ordinary role

- **Kind/result:** source qualification, parents 11/16. Existing gunner gameplay
  test proves a request signal and HUD acknowledgement; extend its existing
  ordinary role firing step to prove the actual GameFlow→LiveCombatAuthority→
  resolver→registered damageable chain and exactly one real damage commit.
  This qualifies one focused hit, not full combat or network crew travel.
- **Owner/files:** one medium-effort test implementer; root reviews/runs.
  Only tests/halyard_crew_gunner_gameplay_test.gd initially. Reuse its current
  whole-Main ordinary boarding/cabin/sit/remapped-FIRE/stand/lifecycle route.
  Preserve disclosed exterior staging; a registered damageable target may be
  positioned as a fixture in the existing gunner aim direction. Do not move the
  player/ship to satisfy a route or call the fire handler directly as proof.
- **Acceptance:** actual admitted gunner and remapped FIRE emit the request,
  existing production handler accepts the Halyard weapon/source, resolved authority receipt
  and target health show the authored damage once. Existing raw pilot/role/HUD/
  cooldown/lifecycle assertions all remain. Do not replace signal-only assertions
  or weaken the original route; append the actual consumer proof at that step.
- **Budget/stop:** 30–60 minutes caller work/review, split before 90; compile once,
  full existing test once under original 300s (checks separate). Headless/Dummy,
  private profile and source/cache/process guards. First unexpected failure stops
  before further diagnosis/fix/run selection; original plus one repair requires
  cumulative review. No automatic retry or scene/runtime change.
- **Close:** caller-only acceptance needs no identical rebuild; current checkpoint
  remains da1ae60. If a runtime defect appears, stop and select its bounded repair
  separately, preserving this full check; accepted runtime changes need a fresh
  paired checkpoint. Retain actual result/source, commit/push and clean scratch.
  Parked Halyard server boarding/moving-cabin/handback is not reopened or reset.

**First unexpected failure, retained:** candidate0b157138b imports20.671s and
compiles15.867s; full original test FAIL51.847s, exit1, one diagnostic:
`ordinary Interact seats at existing co-pilot gunner anchor`. Raw supported
Player is local(0,.500176,-10.62889), approach candidate null. No target fixture
or new FIRE/damage assertions were reached. Source/cache guards and terminal
owner hold; no runtime weapon defect established. Raw/source remain at
`/srv/mudds-work/halyard-gunner-damage-20261018/results/` and branch
`test/halyard-gunner-damage-20261018`; no integration/build/acceptance.

**Separate root selection after stop:** one read-only comparison of the existing
approach/interaction seam against that captured boundary, capped at10 minutes.
Owner: one high-effort lifecycle reviewer; root coordinates. Inspect existing test
look/walk target, Halyard physical gunner anchor/interaction candidate consumer
and GameFlow/Player eligibility only. No engine/probe, code edit or unchanged
retry. End with one exact caller/runtime seam and supported repair candidate, or
no cause established. Any repair needs a separate frozen selection preserving
this full original test and new damage proof. The first failure stays cumulative;
original plus one attempted repair requires priority review before more work.

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
