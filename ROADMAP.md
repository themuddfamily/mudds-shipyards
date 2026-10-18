# Development roadmap

The game is a playable development alpha. Latest accepted playable checkpoint:
**e3d1ada**, with the Heavy Breach board bound before play, Aurora/Rime and
activity music,
saved walking sprint toggle, authoritative remote HUD and earlier gameplay fixes.
[Windows notes](builds/windows/MuddsShipyards-e3d1ada-notes.txt) and
[Linux notes](builds/linux/MuddsShipyards-e3d1ada-linux-notes.txt) state actual validation.

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
| AUDIO-SURFACE-MUSIC /30 | DONE; packaged4ff7a08 | Aurora/Rime music follows transit/landing/surface visit state | Closed after full phase/activity/bed checks, independent review and paired checkpoint; ordinary journey/listening gates remain open. |
| BOOT-BREACH-OWNERS /9,11,13 | DONE; packagede3d1ada | Physical Heavy Breach board has its actual director/combat/objective owners before play | Full startup and production route pass; paired checkpoint. Crash-recovery transaction stays parked. |

REMAP-DEFINE and [the sprint repair](docs/history/ROADMAP_DELIVERIES.md#on-foot-sprint-toggle--acceptedbd4e15d)
are closed. AUDIO-CONTENT-DEFINE and AUDIO-ACTIVITY-LIFECYCLE are complete. No adjacent
HUD power or movement/tow chain is selected. Original Settings/hardware gates
remain open, and Titan approval remains pending.

Both selected audio repairs are closed. No successor is selected. Dormant Ember
feed/acoustics and audible mix retain separate definitions/gates. The next planning
step is to resolve remaining DEFINE/BUILD-SPLIT rows into finite player/build
capabilities with unchanged parent acceptance, rather than infer another audio
repair. [Surface-music result and retained card](docs/history/ROADMAP_DELIVERIES.md#surface-visit-music--accepted4ff7a08).

### Latest planning result

NET-PROFILES-DEFINE and RECOVERY-PILOT-DEFINE are DONE as definitions only.
[Network profile contract](docs/MOVING_INTERIOR_LATENCY.md#finite-profile-contract--net-profiles-define-2026-10-18)
separates the five existing stream profiles, three-process consumer injection,
actual host stalls and still-missing impaired independent/endurance journeys.
[Pilot recovery contract](docs/ROADMAP_BACKLOG.md#settled-pilot-recovery-contract)
names the existing home-berth preference, fresh claims and preserved activity/debt;
its prior packaged pass remains accepted, final-candidate/ordinary-controls gates
stay open. No runtime gap was established by either definition; no tests or new
build were needed. No qualification successor is selected. Remaining definitions
must identify an actual finite contract or production gap before implementation.

### Activity-write planning result

ACT-WRITES-DEFINE is DONE as a definition: the
[finite roster](docs/ROADMAP_BACKLOG.md#activity-write-boundary-roster--act-writes-define)
maps12 activities to their actual session/summary/reward owners and existing
checks. Terminal-only behavior is recorded without waiving broader original
recovery promises. Existing coverage and parked failures remain intact.
A concrete build/release gap is identified: the exported interruption driver
cannot select Heavy Breach/Torpedo terminal debt, although source memory-backed
checks already cover the gameplay owner. The candidate below was implemented and
checked, then withheld after its original and one repaired transaction failed.

BREACH-INTERRUPTION is now FAILED/PARKED after its original source attempt and
one caller repair. Both stop at physical board arming; no earned terminal,
recovery/payment/replay or checkpoint is accepted. The retained snapshot shows
missing configured board owners. The separate startup repair below addresses
that binding seam without accepting this transaction. No successor
or third attempt is selected. [Full result and frozen contract](docs/history/ROADMAP_DELIVERIES.md#breach-interruption--failed-and-parked).

BOOT-BREACH-OWNERS is DONE in checkpoint **e3d1ada**. Startup now retries the
existing Heavy Breach owner binding after the actual shared combat/director
siblings exist, on both staged Boot and synchronous Main paths. Exact-owner
regression and existing full startup/production route pass; fresh paired builds
and strict package checks pass. [Result and retained card](docs/history/ROADMAP_DELIVERIES.md#boot-heavy-breach-owners--acceptede3d1ada).
No successor is selected; full combat and parked interruption acceptance remain
open. This repair does not accept or rerun the failed release probe.

### Selected reopening — BREACH-INTERRUPTION after the production fix

Root explicitly reopens the same13/31/32 outcome on the changed production
baseline342705a1e, retaining both original failures and cumulative71.004s. The
qualifying new fact/change is accepted BOOT-BREACH-OWNERS e3d1ada: the missing
deferred binding and exact production owners are now directly proven/fixed in
the full startup suite. This is not an unchanged third probe or a reset budget.

- One medium-effort integration agent ports only the retained e9c6111b4 and
  3c10a071b four-file release capability onto this clean fixed baseline, without
  further caller/gameplay edits. One high-effort reviewer checks exact source
  composition, independent processes and preserved finish criteria. Root owns
  execution, integration, builds and cleanup. No nested agents or new validators.
- Finish remains the original genuine Heavy Breach earned terminal/unpaid debt,
  target-only delegated filesystem refusal, owned live readiness kill/reap with
  byte-identical interrupted document, distinct same-profile normal Resume/real
  pilot/production exit/physical board retry, exactly one atomic receipt/ack,
  then a further distinct cold paid replay without a second receipt. Settings,
  actual unrelated cargo payload and all authority/admission/diagnostic guards
  remain. Torpedo and active-combat restore are separate/unqualified.
-30–60min integration/qualification. Import, compile changed probe, existing
  startup CLI privacy, then exactly one full source transaction at original300s
  per-process caps. Unchanged startup96.328s/production route48 on e3 and board52
  on e9 retain their recorded sources; they are not rerun merely for a new pin.
  If source passes, clean paired exports/three strict silent startups/actual
  package audit, then one exact archive-extracted ELF transaction, same caps.
- First unexpected failure ends this reopening, with cumulative priority review
  including the retained71.004s and this run. No further caller repair, fourth
  automatic attempt, rename, timeout change or different recovery choice.
  Preserve raw failure and candidate; no failed candidate publication.
- All engine runs private/headless/Dummy; no native Windows, audible output or
  CI. Fixtures and acceptance limits remain disclosed. Commit/push regularly;
  clean owned scratch after terminal closure. Independent Cinder supply terminal
  qualification remains an unselected alternative; no adjacent recovery chain.

## Parked failures and dependent work

These are unfinished outcomes, not candidates for an unchanged retry. Exact
contracts and cumulative attempt records remain in the retained history.

| Outcome | Last actual result | Condition before more work |
| --- | --- | --- |
| BREACH-INTERRUPTION /13,31,32 | Originale9c6111b4 fails35.365s; one caller repair3c10a071b fails35.638s at same board-arm step. Board snapshot: attached, configured=false, director/combat IDs0, external_owners_unavailable. No saved terminal or recovery proof. | Cumulative71.004s review PARKED; candidate unmerged/withheld, no exports. Separate production binding repair e3d1ada addresses the observed owner seam; recovery transaction remains unqualified and no further probe/repair is selected. No automatic third attempt or renamed retry. |
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
