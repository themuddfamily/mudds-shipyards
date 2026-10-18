# Development roadmap

The game is a playable development alpha. Latest accepted playable checkpoint:
**99e79c3**, with continuous right-stick camera look on foot, aboard and in the
tow tractor, plus earlier startup, music, saved sprint and remote HUD fixes.
[Windows notes](builds/windows/MuddsShipyards-99e79c3-notes.txt) and
[Linux notes](builds/linux/MuddsShipyards-99e79c3-linux-notes.txt) state actual validation.

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
| GAMEPAD-LOOK /8,29 | DONE; packaged99e79c3 | Held right stick rotates actual local Player/tractor camera with safe handoffs | Full focused camera/tow/glyph checks, independent review and paired checkpoint pass; real-device/full controller route remains open. |

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

BREACH-INTERRUPTION's original failure/one-repair history remains retained.
The production binding repair below resolved its missing-owner prerequisite;
a separately selected unchanged-probe reopening then failed at a later atomic
payment check. The result below remains unaccepted; this is not a new budget.

BOOT-BREACH-OWNERS is DONE in checkpoint **e3d1ada**. Startup now retries the
existing Heavy Breach owner binding after the actual shared combat/director
siblings exist, on both staged Boot and synchronous Main paths. Exact-owner
regression and existing full startup/production route pass; fresh paired builds
and strict package checks pass. [Result and retained card](docs/history/ROADMAP_DELIVERIES.md#boot-heavy-breach-owners--acceptede3d1ada).
No successor is selected; full combat and parked interruption acceptance remain
open. This repair does not accept or rerun the failed release probe.

### Latest interruption result

BREACH-INTERRUPTION's explicitly selected reopening on the accepted startup fix
is FAILED/PARKED. Candidatec1598ad67 reached earned debt, real readiness kill,
cold normal Resume and one matching paid receipt, then failed its atomic-payment
commit assertion in69.957s. No terminal recovery OK or third paid cold replay;
no export/merge/checkpoint. Prior71.004s is retained: cumulative140.961s. No
further repair/run is selected. [Reopening result and retained scope](docs/history/ROADMAP_DELIVERIES.md#breach-interruption-after-fixed-startup--failed-and-parked).

### Completed definitions — controls/help and remaining UI views

CONTROL-FINDINGS (parent8) is DONE as source review: the concrete missing
right-stick camera input is repaired below. ACCESS-VIEWS-DEFINE (parents12/29)
is DONE as a source definition in the [finite production view roster](docs/ROADMAP_BACKLOG.md#remaining-ui-view-roster--access-views-define).
It identifies actual owners, visible states and existing coverage for gameplay,
help, activity/nearby/destination pages, browser, credits, captions, role status,
recovery and rest. Each future check selects one named state/aspect/scale cell.
No new UI qualification ran. Existing mixed prompts, camera-distance help,
sprint toggle and16:10 pause acceptance retain their recorded scope. No full
UI/device acceptance or unchanged parked rerun is implied.

### Latest controller delivery

GAMEPAD-LOOK is DONE in checkpoint **99e79c3**. The advertised right-stick LOOK
now continuously rotates actual Player/tractor cameras at the authored delta-based
rate, with existing inversion/clamps and local owner/lifecycle clearing. Active
stick look suspends only the tractor's camera recenter; idle recenter remains.
Old exact11/8 failures, final complete player106/tractor148/tow integration92/
glyph HUD40 checks, independent review, paired exports/three strict silent
startups and actual1517-entry payload audit pass. Physical controller feel,
ordinary controller-only journeys and full Settings/hardware acceptance remain
open. [Result and retained card](docs/history/ROADMAP_DELIVERIES.md#gamepad-camera-look--accepted99e79c3).
No successor is selected by this closure; remaining definitions and original
qualification routes retain their named boundaries.

### Completed craft definitions — Arrow and Jovian

CRAFT-GAPS-ARROW and CRAFT-GAPS-JOVIAN (parents10/11) are DONE as bounded
source definitions in the existing [fleet capability maps](docs/COMPLETION_SCOPE.md#arrow-authored-capability-map--craft-gaps-arrow).
Arrow's one-pilot/recon/two-pod presentation and Jovian's connected interior,
freight/engineer/navigation roles are mapped to actual owners and existing
coverage. No concrete new required missing runtime component/role was found in
those bounded owners. No engine/capture/test ran; no new gameplay pass/build is
claimed. Operational escape pods, scanning gameplay or a Jovian gunner station
are not inferred from presentation/policy records. Original full-craft/art/combat/
ordinary packaged routes and historical source dependencies remain OPEN. No
runtime repair or qualification successor is automatically selected.

### Selected craft definitions — Zenith, Bulwark and Halyard

CRAFT-GAPS-ZENITH/BULWARK/HALYARD (parents10/11) are selected as three independent
source-only definitions,30min total. Root maps Zenith; two medium-effort read-only
agents map Bulwark and Halyard separately. Finish each finite authored component/
role map with actual production owners, existing coverage, concrete missing
runtime behavior or exact missing definition. Preserve source-specific passes,
original craft/art/combat/crew acceptance and historical boundaries. No engine,
test/capture/export/CI run, runtime edit, new tracker/validator, parked gunner/
boarding/handback retry or automatic qualification chain. Stop once owners,
seams and acceptance distinctions are known; any real product repair needs a
separate frozen card. Root integrates into the existing completion roster/backlog,
commits/pushes and reports definition progress without claiming gameplay passes.

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
