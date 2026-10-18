# Development roadmap

The game is a playable development alpha. Latest accepted playable checkpoint:
**f8b5f86** preserves earned Cinder platform supply rewards across payment refusal
and reload, pays once and prevents paid replay. Previous asteroid Start Fresh,
Habitat loop/restart/bunks, Settings, Hauler access, controller look, audio, sprint
and HUD work is included.
[Windows notes](builds/windows/MuddsShipyards-f8b5f86-notes.txt) and
[Linux notes](builds/linux/MuddsShipyards-f8b5f86-linux-notes.txt) state actual validation.

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

**Last planning result:** SCOPE-ROSTER is DONE as a
[finite named scope](docs/COMPLETION_SCOPE.md#finite-release-roster--scope-roster).
The original12 plus modern5 yield17 eventual craft:9 implemented/8 absent.
Nine station routes, four service motions, twelve activities, three worlds,
combat/weapon and physical-role inventories now have explicit boundaries.
SCOPE-DESKTOP source investigation is complete; the final supported target list
remains WAITING. Windows Desktop/Linux x86_64 exports exist; Phase9 does not name
a third target. This is scope definition, not new gameplay or full acceptance.

**ACT-REPEAT-DEFINE is now DONE as a definition.** The
[remaining nine activity contracts](docs/ROADMAP_BACKLOG.md#activity-repetition--remaining-nine-definitions)
complete the twelve-activity classification. Ten same-world runs, no resource
growth and no stranded objectives remain required; no repeat journey was run.

| Remaining gate | Concrete next action | Acceptance boundary |
| --- | --- | --- |
| First ordinary activity play | Select one existing PLAY-* card and freeze actual route, current production owners, original deadlines and once-only reward/home return before any execution | Existing source/staged checks do not qualify ordinary play; no ten-run chain automatically follows |
| Cargo repetition policy | Specify legitimate same-world replenishment and destination turnover before selecting ten deliveries | Jovian6 kits fund3 deliveries; Cinder2 crates fund2 per retained source and destination capacity8. Preserve unanswered Hauler stock choice; no fixture restock or implicit exemption |
| Repeat resource/deadline contract | After accepted first play, freeze one activity's actual command/candidate, equivalent-phase resource baseline and ten measured cycle budget | Generation/receipt/inventory changes need exact legitimate accounting; original deadlines, no-growth and failure-stop criteria remain |

Heavy Breach and Torpedo remain separate ten-clear outcomes on the actual
alternating board: twenty successful alternating sorties yield ten of each.
Do not skip offers, count ten mixed sorties as ten each or replay the parked
BREACH-INTERRUPTION probe. The physical-defense contract retains all three waves
and fresh-reset cycles; failed-wave continuation is not another successful run.

### Next work: three bounded steps

These are three different outcomes, not one expanding investigation. Only the
first is ready for selection; each ends before the next is scheduled. Parent
UI-BOARD-FOCUS remains unresolved until the production behavior is repaired and
verified. PLAY-MINING remains parked under its original contract.

| Step | Deliverable | Completion check | Dependency / limit |
| --- | --- | --- | --- |
| 1. Establish a tooltip during the keyboard transition | One changed real-input HUD reproduction, observing the actual popup and its root connections | Establish the existing Destination Board tooltip with real OS mouse motion; identify the same visible PopupPanel in root connection recipients; then Tab→Tab→Enter and record exact errors, popup teardown and visible focus | Source-backed candidate only. One attempt, CAP60/outer90, within the original UI investigation budget; freeze source/driver pins before execution. No popup or no target error ends the attempt without a fix claim |
| 2. Repair the established production cause | A bounded HUD lifecycle change, if step1 establishes the cause | Existing focused navigation coverage plus the reproducer pass with valid visible focus and no engine errors; independent lifecycle review; fresh checkpoint for accepted runtime change | GATED: observing an error alone is insufficient. Freeze exact runtime files and estimate after identifying the faulty owner/event. No speculative focus deferral, signal suppression or engine change |
| 3. Complete the ordinary mining sortie | Full actual packaged route and once-only saved capacity reward, followed by home return | Original walk/board/flight→Cinder→ordinary SELECT/START→six real extraction seconds→receipt→strict home landing/offline/exit walk | GATED on concrete production repair. Re-select the original PLAY-MINING contract; retain failed-stage61.925s/CAP300. No automatic flight retry or ten-run chain |

Step1 extends the existing UI investigation; it is not a fresh budget or a
replacement acceptance contract. If it does not identify a cause, park the UI
investigation with its exact missing fact and select independent product work.
Do not turn an inconclusive attempt into another menu audit or tooltip variant.

### UI-BOARD-FOCUS — source investigation closed, candidate condition identified

The first real-key HUD component completed the transition (69 samples, exit0,
4.673s guarded), but never created hover, a visible popup or root popup-parent
connections. **NOT_REPRODUCED**, not a repair or Main acceptance. The fixture
remains unmerged and production HUD unchanged.

The follow-up source review found a precise omitted event: switching mouse
capture to visible does not itself synthesize mouse motion or start a tooltip.
The existing Destination Board button has authored tooltip text; real motion
onto it can start the engine timer and create an embedded PopupPanel. Opening
Activity Board hides its parent pause page, which can cancel and queue that
popup for deletion. Popup parent cleanup owns the exact reported signal pair.
This justifies step1 as a changed candidate condition; it does **not** establish
that the original mining run had that tooltip or identify a faulty disconnect.
[Source findings and limits](docs/history/ROADMAP_DELIVERIES.md#activity-board-tooltip--source-backed-candidate-condition).

Original missing fact: which popup held the original root connections, and what
removed or mismatched those connections before teardown. No runtime repair is
justified yet. No unchanged key-only component or mining replay is selected.
The original UI investigation budget20–30min from19:07UTC remains cumulative;
first component4.673s. Source review ended19:25UTC, without another engine run.
Cumulative priority review selects ONE changed tooltip attempt within this same
budget: fixturee646fc792 (only three observational geometry lines added to the
previous unmerged fixture). Root owns the external `results/tooltip-driver.py`
and runs it through `helpers/tooltip-runner.py` at the existing task root.
Driver SHA256 is recorded before launch in the task results. Exact commands are
frozen in `helpers/tooltip_{import,compile,repro}.json`: one headless Dummy import
CAP600 and fixture check-only CAP300, then `xvfb-run -a -s '-screen 0 1600x900x24
-nolisten tcp' python3 results/tooltip-driver.py`, whole driver CAP60/outer90.
The driver launches pinned Godot with Dummy/x11/dummy-renderer/disable-render-loop
and the existing optional probe script. Before keys it requires the hovered
Destination Board plus one visible embedded PopupPanel whose identical ID owns
both root signal connections. Target errors and all diagnostics are retained
separately; the strict outer diagnostic check remains unchanged. Stop after the
first outcome or unexpected failure. No production edit or mining run follows
without a separate selection; no budget reset. Independent probe review required
before launch. No additional source research is selected.

PLAY-MINING candidate20bd1ab remains unmerged/checkpoint withheld. Latest accepted
playable remainsf8b5f86. All original broad parents/phase gates remain OPEN;
CI stays disabled. This queue clarification changes no gameplay acceptance.

At most three executable cards belong here. A definition ends with a finite
answer or exact missing fact; it does not automatically launch its qualifications.
A product implementation card must name one actual production gap, files,
acceptance action, dependencies and estimate before work. Split implementation
expected to exceed90min into independently useful capabilities.

## Latest delivered result

**CINDER-SUPPLY-DEBT is packaged on f8b5f86.** Genuine completed delivery now
checkpoints earned reward before payment; refusal survives reload, a current
owner pays once, and paid reload cannot replay. Focused reward62/16.314s and
three-process roundtrip17/71.163s pass; paired exports, three menu-ready startups
and1521-entry artifact comparison pass. Commit/push and owned scratch cleanup
completed. Active manifest recovery and Hauler stock decisions remain separate.

Completed task cards, exact failed attempts, repairs and check/cleanup records
moved intact to [delivery history](docs/history/ROADMAP_DELIVERIES.md#execution-queue-archived-on-2026-10-18).
[The backlog](docs/ROADMAP_BACKLOG.md#concrete-child-outcomes) retains accepted
children and all unfinished scope. A finished card leaves this queue rather than
accumulating a new active qualification chain.

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
