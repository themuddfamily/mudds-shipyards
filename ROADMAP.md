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

No execution card is selected by this definition. Next scheduling action is to
freeze **one first-play card**, after identifying its supported ordinary route
and a bounded command; avoid launching an unbounded repeat/recovery sequence.
The definition changed only existing backlog/roadmap documentation. One medium
read-only mapper covered the independent board scenarios; root defined the six
other activities and integrated review. No engines, tests, builds or scratch
files were needed. All original broad parents/phase gates remain OPEN.

### Selected — PLAY-MINING ordinary packaged sortie

Parent13; production release capability, not new mining gameplay. The exported
OS-input driver lacks a mining route/read-only observation. Freeze ownership:
run_native_sortie.py + test_native_sortie.py, native_sortie_observer.gd,
startup_loader.gd and existing startup_cli_privacy_test.gd only. One high-effort
implementer in an isolated worktree; independent high-effort review; root alone
runs checks, packages, integrates and cleans scratch. No nested delegation.

Finish: fresh archive ELF/default controls→actual Torrent walk/board/Guided
four-drone+interceptor prelude→physical authored Cinder approach→Escape/Activity
Board/Nearby activities/mining SELECT/START→resume→6s real physics inside30m→
generation1 complete with genuine once-only persisted capacity receipt→physical
home strict landing/offline/supported exit. Preserve actors, authored tuning,
ordinary input, unrelated data; no placement, synthetic objective submission,
activity calls, reset/retry or accelerated physics. Observer stays read-only;
paused UI sequence is separate from physics-time proof. Mining grants capacity,
not invented ore/currency. Common-world target comes from live authored frame.

Estimate45–60min implementation, split before90 cumulative. Root clean import600,
observer/startup relevant compile300 and full privacy300; focused Python suite300.
Independent exact clean-pin GO before engines. Clean paired exports900 each,
three strict startup checks330/330/300,1521-style actual payload/archive audit,
then ONE actual archive route at unchanged whole CAP300 (outer360). Stop first
unexpected failure; preserve logs and source before any explicitly reviewed
repair. Never raise cap or narrow route. No unchanged parked route/recovery
replay or ten-run chain. Private Xvfb/x11/Dummy, owned PID/window/input helper,
independent abort and release/reap required. Publish EXE/ZIP/notes only after all
required checks pass; update roadmap, commit/push and clean owned scratch.
Independent alternative is the unresolved cargo replenishment definition, gated
on an actual source/destination policy; no policy inferred. Native/device/audio/
human/installed/final-source acceptance remains factually unperformed where
recorded; existing owner exclusions unchanged. CI remains disabled.

### Mining first-play — privacy parse stop and bounded repair

Initial clean sourced3ccec5e6 passes import20.710s, observer compile15.733s and
startup compile1.174s. Full privacy check stops0.641s: new native-observer test
local mining_args collides with the existing in-world-mining local in the same
function. No Python/export/startup/ordinary-route stages ran. Retain failed raw
stage/STOP/source and every original assertion/deadline.

Root freezes one exact repair, independently causally reviewed: rename only the
new native-observer block's declaration and three references to
mining_first_play_args. No production behavior/test assertion change. Clean pin
and independent delta review precede repair_privacy300 then the original unrun
checks/packages/one archive route. Accepted unchanged import/production compiles
are retained. Another unexpected failure requires cumulative priority review;
no automatic second patch, timeout extension, route narrowing or renamed retry.
Original45–60min/split-before90 budget remains cumulative (selected18:39UTC;
privacy stop18:54UTC).

### Mining first-play — cumulative fixture review

Repaired privacy passes1.162s. Full Python suite runs63 tests and stops7.840s
on one new negative fixture: it rewinds primary generationN while the observed
sample remainsN+1. The existing generation guard correctly fires before the
intended missing-receipt assertion. No export/startup/gameplay stage ran.

Independent cumulative review explicitly GOes one unit-fixture-only correction:
copy the paid after document, remove only payload.cinder_mining_capacity, write
that same-generation missing-receipt fixture. Preserve the original assertion,
all63 tests, every production guard and frozen route/cap. Root freezes before
editing; exact clean-pin review, full repair_python300, then original unrun
package/startup/audit/oneCAP300 route only. Retain both failures (total8.481s).
Original task elapsed~17min at review;45–60min/split-before90 remains cumulative.
Any next unexpected failure STOPs for cumulative priority review before more
work; no automatic patch or renamed/reset budget.

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
