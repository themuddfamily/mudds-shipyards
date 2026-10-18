# Development roadmap

The game is a playable development alpha. Latest accepted playable checkpoint:
**624d2a6**, with remote steering-release convergence and the earlier cargo,
control-help and layout fixes. [Windows notes](builds/windows/MuddsShipyards-624d2a6-notes.txt)
and [Linux notes](builds/linux/MuddsShipyards-624d2a6-linux-notes.txt) state actual validation.

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

SPEC-TITAN interpretation proposal is selected; implementation remains gated.
WALK-SALVAGE-ACCESS is parked after its original attempt and one caller repair. Reverse qualification and the bounded Torrent
definition are closed below. Completed and parked work does not occupy the
executable queue. Root owns review, integration, checks and closure.

| Task / parents | State | Observable finish | Next action |
| --- | --- | --- | --- |
| SPEC-TITAN / 10,36 | Proposal DONE; WAITING interpretation decision | Concrete one-pilot/two-passenger/four-unit modern candidate and bounded build tasks. | Owner decision on linked proposal before runtime implementation; historical model gate stays open. |
| WALK-SALVAGE-ACCESS / 7,9 | FAILED/PARKED | Same supported Player must walk hub→inspection row→hub without staging. | Both attempts fail at outbound20; no further diagnosis/fix/run selected. |
| CRAFT-GAPS-TORRENT / 10,11 | Definition DONE; craft acceptance OPEN | No specifically required missing implementation found within inspected owners. | Do not invent a feature; any successor needs a concrete requirement/finding. |
| HELM-REVERSE-FLIGHT / 18 | DONE, source qualification | Normal reverse moves host1.448m in888ms; fresh neutral, brake and both real replicas pass. | Closed52b228c86; original parent handback remains open. |

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

### WALK-SALVAGE-ACCESS — normal hub to inspection row and back

- **Type/parents:** qualification of existing station gameplay,7/9. First child
  of WALK-SALVAGE; ordinary inspection/publication and durable physical revisit
  remain required later. It cannot close the whole station or Salvage parent.
- **Definition DONE:** inspection/save runtime exists. Current
  `tests/salvage_terrace_test.gd` stages the connector and uses a memory filesystem
  for its Main inspection/reload checks; it does not prove ordinary hub access.
  Extend that caller with selected `--walk-salvage-access`; default/capture unchanged.
- **Owner/boundary:** one implementation agent owns that existing script only,
  root review/execution. Prepared worktree
  `/srv/mudds-work/salvage-ordinary-access-20261018/source`. No runtime/geometry
  changes, active-craft/position/seat fixtures, direct interaction handlers,
  inspection/save mutation, new framework or parked-route reopening.
- **Proof:** fresh Main, retained normal hub spawn(-8.5,11), ordinary intro
  Interact, same controlled unseated supported Player. Use accepted Annex prefix
  through local(0,4.8), then proposed unqualified north-service continuation
  (0,9.5),(0,19),(-12.5,19),(-12.5,12),(-14,12); cross actual connector and Salvage
  local(0,7),(-8,7),(-16,7). Return by reversed goals to retained spawn. Normal
  mouse-event look/held movement only; physical floor decides height. Preserve
  manifest without inspection. Each waypoint retains240 physics frames,0.20m
  arrival radius/four-frame settle/floor support; same Main/Player and phase/control
  remain current throughout. First failed waypoint ends the route.
- **Command/limits:** existing script plus `-- --walk-salvage-access`, one clean
  source pin, compile300s then ONE private Xvfb/x11/Dummy route300s/outer360s.
  `WALK_SALVAGE_ACCESS_TEST_OK` exactly once only on actual exit0/cleanup and
  original fullraw diagnostics0. Release inputs/cursor on every path; independent
  supervisor abort and owned-process cleanup.
- **Budget/close:**30–45min implementation/review, split before90; check duration
  separate. First unexpected failure stops: exact actor/boundary/owner and at most
  one bounded static diagnosis before a separately selected repair. Failed task
  plus one repair requires cumulative priority review. Commit/push result/limits,
  retain unique raw/source refs, clean owned scratch. Caller-only pass needs no
  identical-runtime checkpoint; any accepted runtime repair has a separate card
  and fresh paired playable packages.
- **Remaining ordered children:** WALK-SALVAGE-INSPECT proves ordinary component
  interactions and manifest publication after actual approach; WALK-SALVAGE-REVISIT
  proves durable fresh-process physical revisit without a duplicate transaction.
  Their exact commands/budgets must be frozen when prerequisites pass. Existing
  connector-staged memory-store proof does not silently satisfy either whole route.

**Initial access result:** source46c059cf1 import/compile pass; ONE route
FAIL61.019s at outbound20, target(91,50.50001), actual(91.54988,40.575),
same supported controlled Player. Collision is Annex GuardrailCollider04.
One bounded static comparison identifies rear-edge guardrail clearance during
this caller's corner turn; no runtime access defect is established. All3 owners
terminal and owned PID identities absent; original profile logs retained unchanged.
Raw: `/srv/mudds-work/salvage-ordinary-access-20261018/results/route/`.

**ONE attempted caller repair:** inset only the two rear-cross corner goals from
Annex local z19 to18.5 within its authored z18..20 rear aisle. Preserve original
hub/inspection-row/service-gate destinations, ordinary movement and all240-frame,
0.20m/floor/300s criteria. Root owns these two literals; no runtime changes,
geometry removal or diagnostic engine probe. Compile once and ONE corrected route.
Original plus this repair are cumulative; another failure requires priority review
before further diagnosis/fix/run. Estimated5min edit/review, checks separate.

**Repair result/closure:** unmerged641bbdbb0 compiles; ONE corrected route
FAIL60.822s at outbound20, target(90.5,50.50001), actual(90.79643,40.39536),
still supported and controlled. It does not prove access to Salvage, inspection
or return. No runtime change/checkpoint. All5 owners terminal/all19 PID identities
absent; source/required cache unchanged, both failed profile bundles/logs retained
byte-identically. Owned checkout/profiles/helpers removed; raw and remote source
ref retained. Latest playable624d2a6 is unchanged.

**Cumulative priority review:**61.019+60.822=121.842s route execution, excluding
source work/import/compile. The two-corner inset did not resolve the retained
route boundary. No competing READY production implementation is established.
Park this chain; do not schedule another diagnostic, path edit, geometry change
or unchanged route under a new name. INSPECT and REVISIT stay gated. Next priority
is a finite evidence-bounded missing-original-craft specification proposal, so
full fleet scope can become executable; an interpretation proposal is not approval
or a delivered craft. Existing evidence/owner-decision gates remain intact.

### CRAFT-GAPS-TORRENT — bounded definition complete

- **Owner/boundary:** one read-only agent; root selects any successor. Existing
  Torrent specification, definition and runtime component/role owners only.
- **Proof/finish:** finite actual implementation gaps with specification and owner
  anchors, or none found/missing fact. Separate implemented-but-unqualified behavior
  from missing capability. No speculative art finding or automatic test expansion.
- **Budget/next:**10min source-only, no engine or broad fleet audit. Stop once
  one implementable production alternative is identified, or a concrete blocker
  is recorded. Root reviews before a separate implementation card; no automatic
  diagnosis/probe chain. Record result in the existing inventory, commit/push;
  no gameplay claim or new checkpoint for the definition.
- **Actual result:** existing [Torrent specification](docs/TORRENT_2011_RECONSTRUCTION_SPEC.md)
  defines source-recognition geometry and physical single-pilot access; its modern
  detail zones do not mandate another weapon or cabin capability. HeroShip owns
  flight, fire, component damage, boarding, landing and reuse. FleetRoleRegistry
  explicitly expects no walkable Torrent cabin. No concrete missing implementation
  was identified in the bounded review; this is not full craft acceptance. Visual
  review and ordinary gameplay-continuity qualifications remain open. Reopen this
  implementation definition only with a specific absent required behavior or a
  supported reference/finding, not another unchanged source inventory. No engines,
  runtime changes, temporary checkout or checkpoint were created.

### HELM-REVERSE-FLIGHT

- **Type/result:** qualify existing gameplay. This is reverse flight and release,
  not a new feature or completion of the reverse parent's required handback.
- **Prerequisite:** retain the existing ordinary three-process Jovian flight
  route: real menu/spawn walk/hatch/chairs, original pilot and co-pilot, forward
  departure >=5m, physical berth release and initial brake. No yaw or handback
  replay is added to this independent continuation.
- **Owner/boundary:** one implementation agent prepared only
  `tests/network/jovian_network_two_client_reverse_test.gd` and its UID in
  `/srv/mudds-work/jovian-remote-reverse-20261018/source`. Root reviews/runs it.
  Existing input, network, physics and base caller remain unchanged. No forced
  position/command/seat/ownership, fabricated replica, or new validator/framework.
- **Proof:** normal original-pilot move_back must produce same-source negative
  throttle, advancing local capture/wire and host delivered-command receipts,
  actual negative velocity and >=1m displacement opposite the recorded nose
  within the host-owned 2s clock, including authorization delivery. Release must
  deliver a fresh fully neutral command within1s; silence-timeout neutral is
  insufficient. Ordinary brake must hold speed <=0.5m/s for1s within10s, then
  brake release must deliver fresh neutral within1s. Both actual client hulls
  must consume newer current-owner poses within0.5m of the stopped host within5s.
  Preserve original actors, seats, ownership generations, source/stream identities
  and released berth throughout all waits. Coasting after thrust release is valid.
- **Command/acceptance:** selected script above; coordinator-only
  `JOVIAN_NETWORK_TWO_CLIENT_REVERSE_OK` after all three actual OS exits0,
  exactly one marker and original full-raw diagnostics0. Import600s,
  compile300s, one private Xvfb/x11/Dummy route with unchanged inherited300s
  clock and outer360s supervisor. Independent abort; release inputs on every exit.
- **Budget/stop:** DONE; implementation/review30–45min estimate, split before90; checks separate.
  Accepted clean source52b228c8646b447a8f3044542c645be1db397e5e. First unexpected failure ends qualification:
  retain raw, record actor/boundary/owner, at most one bounded static diagnosis,
  then select a separate repair. No automatic retry or criterion relaxation.
- **Close:** record actual source/result/limits, commit/push, remove only owned
  disposable checkout/profiles/helpers after retaining unique work/raw. Caller-only
  qualification needs no identical-runtime checkpoint. Any accepted runtime repair
  requires its own card, focused regression and fresh paired playable packages.

**Actual reverse result:** ONE unchanged route PASS138.086s after import/compile.
Host reverse1.448m/888ms, release neutral334ms, brake stops and holds<=0.5m/s1s,
brake release neutral315ms. Pilot replica error0.167m, passenger0m; newer consumed
poses and original identities preserved. Three actual exits0, marker1, diagnostics0.
All3 owners terminal/all23 PID identities absent;74 peer files copied identically.
Raw retained in `/srv/mudds-work/jovian-remote-reverse-20261018/results/`;
owned source/profiles/helpers removed. Caller-only: latest playable624d2a6 unchanged;
handback, native devices, endurance and parent18 remain open.

**HELM-REVERSE-DEFINE: DONE, source definition only.** Existing sampled reverse
input reaches signed host thrust through current authority owners. Neutral means
release, not instantaneous stop; ordinary brake supplies the stop. The definition
selected the subclass seam above. No engine run or gameplay acceptance is claimed.

## Parked failures and dependent work

These are unfinished outcomes, not candidates for an unchanged retry. Exact
contracts and cumulative attempt records remain in the retained history.

| Outcome | Last actual result | Condition before more work |
| --- | --- | --- |
| HELM-YAW-HANDBACK / 18,20 | Original146.578s failure; one repair reaches cabin walking then FAIL156.016s at >=0.6m/15s. | Recorded cumulative priority review parked it. Explicit selection required before further diagnosis/fix/run; no movement cause established. |
| CABIN-PASSENGER-ROLE / 18,20 | Candidate38c079086 HUD36 and actual handback PASSENGER pass, full required route fails walking. Unmerged/withheld; no package. | Preserve full route; no acceptance narrowing or automatic second repair. |
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
