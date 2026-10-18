# Development roadmap

The game is a playable development alpha. Latest accepted playable checkpoint:
**59c55cb** fixes Start Fresh for interrupted Asteroid Threading: the abandoned
active run cannot return after later streaming/reload, while earned rewards and
failed-save retry remain protected. Previous Habitat loop/restart, six bunks,
Settings, Hauler access, controller look, audio, sprint and HUD work is included.
[Windows notes](builds/windows/MuddsShipyards-59c55cb-notes.txt) and
[Linux notes](builds/linux/MuddsShipyards-59c55cb-linux-notes.txt) state actual validation.

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
| HAULER-SUPPLY-ACCESS /10,13 | DONE; packageda43ae4b | Actual Hauler lands at Cinder supply platform; current pilot walks to authorized terminal | Full focused access/berth/switching checks, independent review and paired checkpoint pass; cargo stock/manifest/delivery remain separate. |
| SETTINGS-SCALED-FOCUS-SCROLL /12,29 | DONE; packaged4d7ac43 | Large-scale Settings focus fully reveals its current row; pending requests respect focus/page ownership | Focus59 and full16:9/21:9/32:9 source checks, independent review and paired checkpoint pass; rendered/device/transaction gates remain open. |
| HABITAT-BUNK-REST /7,9 | DONE; packaged221f523 | All six Habitat bunks offer actual Interact sleep/wake, supported walking/reuse and owner-loss cleanup | Full focused rest, spine, Habitat and ship sleep checks; independent review and paired checkpoint pass. Ordinary loop/restart accepted separately on3707bc9/29abe94. |
| DOCK-RECOVERY-PROBE /2,31,32 | DONE; packaged311df73 | Existing release driver interrupts one real Bulwark assist and proves distinct-process usable home recovery with conserved failed Convoy/reward boundary | Full privacy/landing suites, source and archive-extracted ELF cuts, paired checkpoint pass. Installed/final/ordinary/busy-exit gates remain open. |
| WALK-HABITAT-LOOP /7,9 | DONE; packaged3707bc9 | Fresh normal hub→door→actual bunk sleep/wake→common room→same hub, no placement/rescue | Actual archive ELF OS-input loop54.259s/163.231m passes; independent review and paired checkpoint. Normal restart is separately accepted on29abe94. |
| WALK-HABITAT-RESTART /7,9 | DONE; packaged29abe94 | Real sleep→normal UI quit→distinct process/same data→fresh supported look/walk/tractor interaction→normal UI quit | Actual archive ELF68.756s under oneCAP300; both exit0/clean markers, independent review and paired checkpoint. Normal Habitat aggregate closes on recorded sources; dressing/native/final gates remain separate. |
| ASTEROID-START-FRESH /13,31 | DONE; packaged59c55cb | Start Fresh retires saved active asteroid progress before streaming; stale writers cannot restore it, earnings/refused writes remain protected | Full production asteroid179/253.847s<CAP300, independent review, paired checkpoint/three strict startups. Broader interruption/ordinary/final gates remain separate. |

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

### Completed craft definitions — Zenith, Bulwark and Halyard

CRAFT-GAPS-ZENITH/BULWARK/HALYARD (parents10/11) are DONE as source definitions
in the existing [fleet capability maps](docs/COMPLETION_SCOPE.md#zenith-authored-capability-map--craft-gaps-zenith).
Zenith's bounded B7 art and modern single-pilot systems, Bulwark's supported
pilot-to-gunner cabin/lance and unanchored auxiliary policy, and Halyard's eight
chairs/shared Loadmaster/repair/gunner consumers now have finite owners and
coverage distinctions. No concrete new required missing runtime component/role
was established in inspected owners. No engine/test/capture/export ran; no new
gameplay or full craft acceptance is claimed. Original art/combat/ordinary crew/
recovery, historical and external gates remain OPEN; parked routes were not
reopened. No repair or qualification successor is selected by this definition.

### Completed craft definitions — three Cinder variants

CRAFT-GAPS-CINDER-LIGHT/HAULER/BOMBER (parents10/11) are DONE as bounded source
maps in the existing [fleet roster](docs/COMPLETION_SCOPE.md#cinder-light-interceptor-capability-map--craft-gaps-cinder-light).
Light has no concrete new required runtime/physical-role gap identified. Hauler's
actual supply consumer is Jovian-only, so its anchors/forwarding bridge cannot
accept promised Hauler cargo play; HAULER-CARGO-DEFINE names the missing contract.
Bomber's additional crew/navigation decision remains WAITING, and its known
source re-entry/refill path leaves BOMBER-REARM-POLICY unresolved. No new mission,
stock entitlement, role or rearm mechanic is invented. All nine current CRAFT-GAPS
rows now have bounded definitions (including exact remaining interpretation gaps);
this does not close any full craft/art/combat/crew/world/recovery requirement.
No engine/test/capture/export ran; no new build was needed for this definition.
No runtime repair or qualification successor is automatically selected.

### Hauler supply access — delivered

HAULER-SUPPLY-ACCESS is DONE in checkpoint **a43ae4b**: the actual Hauler can
land at the existing Cinder supply platform and its pilot can walk to the terminal
with current actor/ship/lease authorization. Original Jovian access is preserved.
Full access76, existing berth83 and physical-switching35 checks pass, plus paired
exports, three strict silent startups and actual1519-entry package audit.
The focused route stages initial craft/exit placement; full Main outbound/home
and E-key dispatch remain separate. No cargo stock, transfer or reward is granted.
[Result and retained card](docs/history/ROADMAP_DELIVERIES.md#hauler-supply-access--accepteda43ae4b).

The [ordered remaining cargo tasks](docs/ROADMAP_BACKLOG.md#hauler-supply-integration-boundaries)
are stock policy (one already-asked question), conserved manifest integration,
then actual delivery. Stock is WAITING; manifest/delivery are GATED. Neither a
whitelist edit nor bridge readiness completes cargo gameplay. No successor is
selected by this closure; all original parent/phase requirements remain open.

### Smaller remaining activity tasks

ACT-REPEAT-DEFINE now has three finite children:
[REPEAT-RACE, REPEAT-BEACON and REPEAT-SCAN](docs/ROADMAP_BACKLOG.md#activity-repetition--first-bounded-definition-slice).
Each covers one activity's ten same-world runs with actual route, existing
reward/reset rules, resource stability and usable next start. Each is GATED on
its named first canonical PLAY-* journey and a frozen measurement/deadline card.
This is a definition slice, not a gameplay delivery or newly executable queue;
Scan's parked failure remains parked. Other repeatability classifications remain
open. No new runtime/test/build was needed for this breakdown.

### Minimum-size pause/options — qualified

ACCESS-PAUSE-4X3 is DONE on source **ece9a0253**: actual Main at1024x768 passes
all96 observations/32 states per requested scale0.75/1/1.6, with safe bounds,
font floor, complete scroll reachability and correct live focus. The existing
fixture gained only a resolution selector; no production change was needed.
Cold import20.807s, compile16.457s and full selected33.402s pass at original caps.
[Result and retained card](docs/history/ROADMAP_DELIVERIES.md#minimum-size-pauseoptions--qualifiedece9a0253).
Rendered/human/device gates remain separate. This qualification needed no new
build; the later Settings repair below has its own checkpoint.

### Torpedo authority definition — finite cases

TORPEDO-AUTH-DEFINE is DONE as a source definition: the existing authority and
retained solo-restoration consumers are implemented. No new runtime defect was
found. The [finite remaining cases](docs/ROADMAP_BACKLOG.md#torpedo-authority-and-restoration--finite-remaining-cases)
separate one peer-flight lifecycle, five session-restoration actions, pilot loss,
target destruction/removal and phase withdrawal. Each needs its own bounded card
and genuine baseline; none is selected automatically. Prior API/in-process/source
passes retain their scope; independent packaged/ordinary Torpedo play stays open.
No engine/test/export ran for this definition.

### Settings focus scrolling — delivered; remaining pause aspects qualified

SETTINGS-SCALED-FOCUS-SCROLL is DONE in paired checkpoint **4d7ac43**. Settings
keyboard/controller focus fully reveals the selected row at large scale;
obsolete/duplicate deferred requests cannot move the wrong page or overscroll.
Existing focus59 checks and unchanged full16:9/21:9/32:9 checks each pass96
observations at requested0.75/1/1.6. Independent review, paired exports/three
strict silent startups and actual1519-entry package audit pass.

The original21:9 graphics-row failure33.080s and pre-run duplicate-request review
are retained in [delivery history](docs/history/ROADMAP_DELIVERIES.md#scaled-settings-focus--accepted4d7ac43).
The three named aspect children are DONE on4d7ac43; earlier4:3/16:10 source
results retain their recorded scope. This is actual Main geometry/focus proof,
not physical-device, rendered/human or real Settings transaction qualification.
No successor is selected by this closure; original UI/device/release gates remain.

### Cabin recovery definition and Habitat finding

RECOVERY-CABIN-DEFINE is DONE as a source contract: ship cabin/bunk recovery
retains a four-field home preference and returns a fresh awake Player to a
supported home cabin with fresh hatch ownership. Prior package passes remain
accepted; no new feature/test/probe is claimed. [Exact contract and two installed
cases](docs/ROADMAP_BACKLOG.md#settled-cabin-and-ship-bunk-recovery-contract).

The independent WALK-HABITAT map found six visual bunks without rest interaction;
station bunk support was selected separately and delivered below. Full ordinary
loop/restart qualification followed on3707bc9/29abe94. Parked Sandbox retains its
original failure; staged placement does not replace the accepted ordinary routes.

### Habitat bunk rest — delivered

HABITAT-BUNK-REST is DONE in paired checkpoint221f523: six authored Habitat bunks
use normal local Interact sleep/wake, safe supported exits and reuse. Pause
preserves sleep; Main detach, retained-owner removal/reuse and owner destruction
recover awake controls. Existing ship-specific guards and recovery authority remain intact.

Focused rest134, complete spine, full Habitat and existing ship sleep gameplay/
lifecycle suites pass on the exact clean source; independent cumulative review,
paired exports, three strict silent startups and actual1521-entry payload audit pass.
The initial reuse33.678s and full audit41.239s failures remain recorded; one
fixture correction and explicit exact266+6 collision-cost integration resolved
the frozen checks. [Actual results and retained cards](docs/history/ROADMAP_DELIVERIES.md#habitat-bunk-rest--accepted221f523).
Owned temporary checkout/profiles/helpers removed; raw results retained.

This delivery starts with one staged placement at a real wake point. Separate
full ordinary WALK-HABITAT loop/restart results on3707bc9/29abe94 follow below;
the staged rest check alone does not establish them.

### Crew recovery — definition complete

RECOVERY-CREW-DEFINE is DONE as a source definition. A settled solo crew seat
saves a four-field home-cabin preference; explicit Resume returns awake/unseated
with fresh cabin/hatch ownership, without restoring old role/seat authority.
The [settled contract](docs/ROADMAP_BACKLOG.md#settled-seated-crew-recovery-contract)
names actual owners, prior ca0 crew acceptance and two finite remaining outcomes:
CREW-RECOVERY-INSTALLED and CREW-RECOVERY-ORDINARY. Their candidate/route gates
remain; the parked full resume-suite failure is unchanged. No new runtime gap,
engine qualification or playable build is claimed by this definition.

### Docking and planetary recovery — definitions complete

RECOVERY-DOCK-DEFINE and RECOVERY-PLANET-DEFINE are DONE as source definitions.
The [docking contract](docs/ROADMAP_BACKLOG.md#settled-docking-recovery-contract)
distinguishes active-assist pilot preference from attempted unavailable publication
during busy exit. The source map identified the missing executable docking cut; its driver is
delivered below. Installed assist and exit cuts remain separate finite outcomes.

The [per-world recovery boundaries](docs/ROADMAP_BACKLOG.md#planetary-recovery-boundaries)
distinguish Aurora/Rime visit restoration from Ember safe-home/later-survey
continuity. Existing WORLD-SAVE, RECOVERY-KILL and shared interruption rows retain
remaining work. Ember surface-location restoration is not proven or waived;
Aurora original-artifact waits/Rime parked arrival are unchanged. No engines,
new runtime acceptance or checkpoint were needed for these definitions.

The selected one-cut driver capability is delivered below. Its separate installed,
busy-exit and ordinary-route requirements remain open; no automatic successor
chain is implied. All36 parents and ten phase gates remain open.

### Docking interruption driver — delivered

DOCK-RECOVERY-PROBE is DONE in paired checkpoint311df73. Normal landing acquires
an actual lease; observed assist progress precedes owned SIGKILL and a distinct
cold Resume with fresh home pilot/seat/hatch, no old assist and working throttle.
The actual failed landing_requested Convoy and first receipt stay exact through
recovery; public reset/start then completes a distinct generation once.

Source and actual archive-extracted native ELF cuts pass at original300s leg
caps, plus complete startup privacy/landing suites, independent review, paired
exports/three strict silent startups and actual1521-entry package audit.
[Actual result and frozen card](docs/history/ROADMAP_DELIVERIES.md#docking-interruption-driver--accepted311df73).
No unexpected failed attempt. Escort/approach placement remains disclosed;
ordinary docking, busy exit and installed/final-candidate qualification stay open.
Owned source checkout/profiles/helpers removed; raw results retained.

### Ordinary Habitat journey — definition complete

WALK-HABITAT now has two bounded acceptance outcomes in the
[complete route contract](docs/ROADMAP_BACKLOG.md#ordinary-habitat-journey--finite-acceptance-contract):
WALK-HABITAT-LOOP (fresh hub→door→actual sleep/wake→common room→same hub) and
WALK-HABITAT-RESTART (normal quit while resting, distinct process, supported awake
controls). Source mapping found no further gameplay gap. Existing staged tests
do not prove this journey, and the parked whole-Sandbox route is unchanged.

The route uses actual authored circulation and obstacle-aware waypoints;
restart preserves the current safe-start contract without inventing a saved
station sleeping pose. Each outcome has one300s whole-operation cap, actual
input/state observations and explicit abort/cleanup. No engines or new build
were needed for the definition; LOOP and RESTART are now accepted below on their recorded sources.

The full LOOP and separate RESTART results follow. Neither staged fixtures nor
LOOP alone establish the restart result.
All36 broad parents and ten phase gates remain open.

### Ordinary Habitat loop — delivered

WALK-HABITAT-LOOP is DONE in paired checkpoint3707bc9. Actual archive-extracted
Linux ELF, OS XTest/private Xvfb/x11/Dummy: normal Start Shift, one Player walks
from fresh hub to the closed door, opens it, sleeps/wakes at actual Bunk01,
occupies the common room and reverses the full physical route to the same hub.
54.259s<CAP300,163.231m/26 waypoints/seven floor colliders; exact sleep reservation,
released/repressed E, supported wake and hub return verify with unchanged actors.

Initial five unit-fixture failures7.123s and compile failure1.304s remain recorded
(cumulative8.427s). Reviewed copy/spawn clarification passes48 Python tests;
exact bool annotation repairs compilation. Final privacy304, required clean paired
exports/three strict startups/1521-entry audit and full loop pass; independent
cumulative review and owned process/source/profile/helper cleanup pass.
[Actual results and retained card](docs/history/ROADMAP_DELIVERIES.md#ordinary-habitat-loop--accepted3707bc9).
This qualifies input/physics in the isolated environment, not GPU/device/human
or final-source release acceptance. Original Sandbox failure is untouched.

### Ordinary Habitat restart — delivered

WALK-HABITAT-RESTART is DONE in paired checkpoint29abe94. Actual archive-extracted
ELF completes in68.756s under the original singleCAP300: ordinary hub/door/Bunk01
sleep, real menu EXIT TO DESKTOP and clean exit0; distinct process on the same
profile, normal Begin Shift with no old claims, actual look and10.749m supported
walk, current tractor driver admission/released-repressed E exit, then a second
normal menu quit/exit0. Six actual-file copies preserve unrelated payload and
prove unavailable sleeping context, session1→2 and both clean shutdown markers.
Independent review of1388 raw observations GO; diagnostics0/all owned cleanup.

Initial route36.419s stopped before UI quit because a new driver predicate rejected
a stable negative Godot shape Resource ID. One explicitly frozen nonzero-ID repair
retains exact identity matching; Python54/7.399s and unchanged GDScript privacy327
scope pass. New paired exports, three strict startups and1521-entry package audit
pass. [Actual result and retained cards](docs/history/ROADMAP_DELIVERIES.md#ordinary-habitat-restart--accepted29abe94).
WALK-HABITAT's normal loop/restart aggregate closes on3707bc9/29abe94; final dressing,
Sandbox, installed/final regression and native/device/audio/rendered/human gates
remain separate/open. All36 broad parents/ten phase gates remain OPEN.

### Activity recovery — definition complete, two runtime gaps identified

RECOVERY-ACTIVITY-DEFINE is DONE as a source map, not new gameplay acceptance.
The [finite contract](docs/ROADMAP_BACKLOG.md#activity-recovery--progress-player-state-and-uncovered-capabilities)
separates last-committed activity progress from fresh safe-home player/craft
recovery, normal Resume/Begin Shift and durable Start Fresh. The existing twelve
activity owners/tests remain authoritative; no duplicated roster/probe family.
Four terminal-only active-resume policies remain explicitly unresolved, and the
original recovery promises remain binding.

Two production gaps received bounded observable finishes; the asteroid fix is now delivered below:

- **ASTEROID-START-FRESH (DONE59c55cb):** Start Fresh previously omitted saved Asteroid Threading progress
  from both title-time durable decline and live reset. Finish: abandon the active
  run before its world streams, no old run on later stream/cold load; retain
  earnings/unrelated data and refuse failed publication without hiding the choice.
- **CINDER-SUPPLY-DEBT:** supply persistence only triggers after accepted reward,
  leaving earned-but-refused completion live-only. Finish: genuine earned debt
  survives cold load, pays once, then remains paid after another load; preserve
  transfer identity/quantity and extend existing authority's atomic acknowledgement.

Independent source review GO. No code/tests/engines/packages changed or ran for
this definition. That definition produced no new checkpoint; current runtime delivery follows below; parked Breach and
other failures, Hauler stock decisions, four active recovery policy gates and
native/device/human/final acceptance remain unchanged. ASTEROID-START-FRESH is delivered below through existing decline/reset owners.
Cinder debt remains a separate next capability. No additional interruption
probe or broad recovery rerun is selected by this planning closure.

### Asteroid Start Fresh — delivered

ASTEROID-START-FRESH is DONE in paired checkpoint59c55cb. Ordinary public Start
Fresh now commits a same-generation IDLE asteroid record even with no streamed
world, then synchronizes a present live owner only after authoritative publication.
Retained/callback writers cannot resurrect abandoned progress; completed unpaid/
paid history, unrelated data, invalid records and refused-write retry are protected.
Resume retains the saved active run through the existing continuation contract.

Complete existing production asteroid suite:179 assertions/253.847s under original
300s cap, exit0/oneOK/no diagnostics. Independent review inspected actual save
files, public choice, absent/live/later-stream/cold Main, refusal/published-sync
refusal/retry, retained director/binding, genuine unpaid/paid/replay and unsupported
cases. Initial GameFlow inference failure2.989s is retained; one explicitly frozen
bool annotation correction passes, all test criteria remain unchanged. Clean
import/compiles, paired exports/three strict startups/1521-entry artifact audit pass.
[Actual result and frozen card](docs/history/ROADMAP_DELIVERIES.md#asteroid-start-fresh--accepted59c55cb).

This establishes headless Linux save/reset behavior, not an ordinary OS-input
asteroid sortie, actual OS-interruption or final installed/full regression gate.
Native Windows/GPU/device/audio/rendered/human gates retain their factual open/
NOT_RUN status. All36 broad parents/ten phase gates remain OPEN, CI disabled.
Next bounded production capability is CINDER-SUPPLY-DEBT: freeze genuine transfer
identity/quantity proof, existing handoff/persistence/authority ownership and its
one-payment cold-load acceptance before implementing; no adjacent probe selected.

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
