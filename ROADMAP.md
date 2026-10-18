# Development roadmap

The game is a playable development alpha. Latest accepted playable checkpoint:
**f1f35d1**, with stable activity music through normal updates/completion,
saved walking sprint toggle, authoritative remote HUD and earlier gameplay fixes.
[Windows notes](builds/windows/MuddsShipyards-f1f35d1-notes.txt) and
[Linux notes](builds/linux/MuddsShipyards-f1f35d1-linux-notes.txt) state actual validation.

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

Only an explicitly selected card is executable. A missing definition, failed route
or full-craft qualification is not an implementation assignment. Do not create
a successor chain just because a nearby check can be added.

DAMAGE-DEFINE is complete; its concrete NET-COMPONENT-ROW repair is accepted
in checkpoint39a2ad7. [Actual result and retained contract](docs/history/ROADMAP_DELIVERIES.md#remote-component-hud-row--accepted39a2ad7).
HALYARD-GUNNER-DAMAGE failed its original seat step twice and is parked below.
WEAPONS-DEFINE has a finite actual roster; no new weapon is inferred missing.
NET-OPERATION-HUD is included in the current checkpoint; its full contract and
actual checks are in [delivery history](docs/history/ROADMAP_DELIVERIES.md#remote-operation-hud--acceptedda1ae60).
Ember, Aurora and Rime definitions found no missing implementation within their
inspected authored-content scopes; full-world acceptance remains open. The [Titan proposal](docs/design/TITAN_IMPLEMENTATION_PROPOSAL.md) remains
unapproved; parked failures remain outside the queue.

| Task / parent | Kind / state | Observable finish | Next action |
| --- | --- | --- | --- |
| NET-COMPONENT-ROW /11,21 | DONE; packaged39a2ad7 | Retained row follows accepted host components and restores current local data on clear/pilot change | Closed after focused local/pose/Main ENet checks and paired checkpoint; no automatic adjacent successor. |
| ONFOOT-SPRINT-TOGGLE /8,29 | DONE; packagedbd4e15d | Shared Sprint/boost HOLD/TOGGLE works in local walking sprint with safe handoffs | Closed after focused source checks and paired checkpoint; no automatic adjacent successor. |
| AUDIO-ACTIVITY-LIFECYCLE /30 | DONE; packagedf1f35d1 | Current activity mix survives normal base updates and same-run completion | Closed after five focused suites and paired checkpoint; audible mix review stays open. |
| AUDIO-SURFACE-MUSIC /30 | Production repair; SELECTED | Aurora/Rime music follows transit/landing/surface visit state | Old focused phase reproduction, readonly projection, focused checks and paired checkpoint. |

REMAP-DEFINE and [the sprint repair](docs/history/ROADMAP_DELIVERIES.md#on-foot-sprint-toggle--acceptedbd4e15d)
are closed. AUDIO-CONTENT-DEFINE and AUDIO-ACTIVITY-LIFECYCLE are complete. No adjacent
HUD power or movement/tow chain is selected. Original Settings/hardware gates
remain open, and Titan approval remains pending.

The activity music capability is closed. Root selects AUDIO-SURFACE-MUSIC
separately after its accepted result; dormant Ember feed and audible mix remain
separate definitions/gates.

### AUDIO-SURFACE-MUSIC — existing surface bed follows actual visit state

- **Kind/result:** production music phase repair, parent30. Aurora/Rime use the
  existing surface bed during landed/disembarking/surface/opening_boarding/
  boarding states. Their landing state selects the existing landing profile;
  outbound/corridor/return_cruise retain flight context. Idle/restoring/retiring
  do not imply a surface. Combat retains highest priority.
- **Owner/files:** one high-effort implementer, independent lifecycle reviewer;
  GameFlow._update_music_bed_state and optional readonly shared visit-state
  projection in planetary_surface_visit_expedition.gd; existing
  tests/audio/music_phase_integration_test.gd. Root owns integration/checkpoint.
  No world travel/physics/content/save authority or asset/voice change.
- **Acceptance:** preserve original phase assertions/waits. Test-only old proof
  stages actual retained Aurora/Rime visit state in the existing focused test,
  asserting real StationMusicBed surface state/family. Final finite visit-state
  map, combat/landing precedence, return/idle restoration and current activity
  overlay/base-family composition must pass with unchanged visit/gameplay state.
  This is controlled source presentation proof, not ordinary surface travel or
  listening. Parked Rime arrival/Aurora originals remain untouched.
- **Budget/stop:**30–60min implement/review, split before90. Compile then full
  existing phase, nearby activity integration and music-bed suites once under
  original budgets, headless/Dummy/private profiles. First unexpected failure
  stops before separate repair selection; original plus one repair requires
  cumulative priority review. No audio output or parked route rerun.
- **Alternative/close:** no independent production successor is identified by
  the audio map beyond this repair; Ember feed/acoustics needs its own definition.
  No automatic adjacent audio chain. Accepted runtime requires fresh clean paired
  exports/three strict silent startups/existing package audit, commit/push and
  owned scratch cleanup. Mix/device/full-world gates remain open.

## Parked failures and dependent work

These are unfinished outcomes, not candidates for an unchanged retry. Exact
contracts and cumulative attempt records remain in the retained history.

| Outcome | Last actual result | Condition before more work |
| --- | --- | --- |
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
