# Development roadmap

**Playable alpha; full original scope remains unfinished.** Latest Windows build:
[1f7dccb checkpoint](builds/windows/MuddsShipyards-1f7dccb-checkpoint.zip)
([changes and validation](builds/windows/MuddsShipyards-1f7dccb-notes.txt)).
Matching [Linux checkpoint](builds/linux/MuddsShipyards-1f7dccb-linux-x86_64.tar.gz)
([Linux validation](builds/linux/MuddsShipyards-1f7dccb-linux-notes.txt)) is available.
The lower Aft stair now has a visible, collision-backed shoulder onto the landing;
the captured lateral walk retains real floor contact. Reduced flash still updates the current/new HUD damage cue through normal Settings.
Actual save/reset/refusal results also control the HUD unsaved state. The native
Linux synthetic-keyboard save/three-process/Reset sequence passes. Prior cargo,
torpedo and ordinary Ember Quit repairs remain accepted. Full cargo/comfort/world
journeys, remaining producer episodes, physical input and native hardware gates
remain open.
Nine of the promised 17 craft exist. All 36 original parent outcomes and ten phase
exit gates remain open; completed child results are retained, not counted as whole
features. There is no evidence-backed project percentage or completion date.

## How we will work from this roadmap

**One active delivery, with acceptance written before work starts.** Broad
milestones below group work; they cannot be assigned as coding tasks. Use the
existing ID in the [canonical backlog](docs/ROADMAP_BACKLOG.md#concrete-child-outcomes).
Every selected goal must have these literal answers in its existing card:

| Field | Required answer |
| --- | --- |
| Result | Capability/qualification: one player action and resulting behavior, or one release operation. Definition/decision/resource: the exact finite answer, choice or artifact; no product completion implied. |
| Start | Source/package, profile/save, location, participants and exact owned files. |
| Steps | Finite ordered actions or an executable command. |
| Pass/fail | Expected state, count/value/tolerance and endpoint; preserved data; original gameplay limits. |
| Proof | Exact focused check or complete ordinary route, with expected output/state. A repair must distinguish the old failure from the corrected behavior. |
| Dependencies | Existing prerequisite IDs; each missing choice, artifact or device has a named owner. |
| Stop | Estimate including checks/build/cleanup; first-failure stop; cumulative cost of prior attempts. |
| Closure | Accepted result or first failed predicate; commit/push; playable checkpoint for runtime changes; owned branch/worktree/process/scratch cleanup. |

“Improve”, “polish”, “finish”, “works”, “usable”, “all applicable” and “as
specified” cannot stand alone as acceptance. Replace them with the actual action,
value or finite member list in the same card. A container closes only when its
complete named membership passes; a missing member list blocks it.

Missing acceptance fields mean **BLOCKED definition — Codex**, listing exactly
which fields are absent. Missing design choices or external access mean
**BLOCKED input — named owner**, listing the exact answer/artifact required.
Neither is an executable task. One definition pass gets 15–30 minutes to fill the
fields or return that exact blocker; it cannot schedule another discovery chain.

An implementation is estimated at **90 minutes or less including closure**;
split larger production changes before starting. Complete journeys/soaks retain
their original durations. A failed estimate is reported as an overrun against
the same goal. A discovered prerequisite stays charged to that goal; a new
branch, card or agent never resets its elapsed cost.

Stop at the first unexpected failure. One failed repair requires a recorded
cumulative-priority decision before continuation: park/switch, or one correction
supported by a demonstrated cause and an explicit next stop. No automatic retry.
Accepted work remains closed within its recorded scope; reopen only the affected
predicate when an identified source change invalidates its proof. Update the
card and backlog together so stale text cannot schedule completed work again.

Report **goal → player result → PASS/FAIL/BLOCKED/PARKED → proof → remaining
blocker → cumulative time → next bounded action**. Definitions, tests, commits
and evidence files are not gameplay progress.

The inventory contains **337 records: 40 capabilities, 176 qualifications,
73 definitions, 12 decisions, five resources and 31 containers**. These are record
kinds, not a remaining-task count or completion percentage. Full craft journeys,
shared-world cases, comfort episodes, recovery cuts, installation transactions
and performance workloads still have missing bindings. Their exact missing
fields stay blocked in the existing rows; this rewrite does not invent answers
or mark those product outcomes complete.

## What finishing means

The full original scope is retained. A smaller release would require an explicit
scope decision; this plan does not make one.

| Delivery | Concrete finish line | Canonical goals |
| --- | --- | --- |
| Complete game loop and station | Final-package Guided 3/3, original all-nine/54-waypoint Sandbox/recovery 1/1 and original Settings/re-entry 1/1; all nine named station branches physically usable, required interactions/revisit complete | [Core and station proof](docs/ROADMAP_BACKLOG.md#proof-core) |
| All 17 craft | All twelve originals plus five modern additions exist; each passes its specified boarding, flight, actual functions, damage/recovery, strict home landing/exit/reuse, cross-craft and Main re-entry checks | [Craft proof and missing specifications](docs/ROADMAP_BACKLOG.md#proof-craft) |
| Combat and twelve activities | Real player weapons achieve the named encounter results; every activity completes its actual objective, durable result and usable home return; all twelve required ten-run repeats and Hulk revisit pass | [Combat](docs/ROADMAP_BACKLOG.md#proof-combat), [activity proof](docs/ROADMAP_BACKLOG.md#proof-activity) |
| Three worlds and shared travel | Complete Ember, Aurora and Rime canonical physical round trips, required survey/reward/save/abandonment outcomes and all 21 explicitly named shared-world cases | [World proof](docs/ROADMAP_BACKLOG.md#proof-world) |
| Supported multiplayer | Complete server/two-client baseline and remaining role/helm/actor/browser/reconnect cases; original 30-minute session with required adverse networking; chosen supported capacity qualified | [Multiplayer proof](docs/ROADMAP_BACKLOG.md#proof-network) |
| Durable recovery | Named real-file interruptions restart in the settled supported state, preserve accepted progress/debt, pay once and permit ordinary continuation; migration/corrupt/unsupported data handled correctly | [Recovery proof](docs/ROADMAP_BACKLOG.md#proof-recovery) |
| Presentation and hardware quality | Existing 13 capture sets/143 PNGs reviewed; required UI/device/comfort/audio cases pass; representative actual hardware meets declared performance budgets | [Quality proof](docs/ROADMAP_BACKLOG.md#proof-quality) |
| Ship the exact candidate | Unfiltered local matrix, required ordinary routes, packages/install transactions, rights, trusted signing and authorized downloadable-byte identity pass on one integrated candidate | [Release proof](docs/ROADMAP_BACKLOG.md#proof-release) |

Parents 3/27 share the same 21 world cases; 6/35 share one final matrix; 11/21
share the damage work. Breach/Torpedo combat and activity journeys are reused,
not counted as duplicate deliveries. [All 36 promises and ten gates](docs/ROADMAP_BACKLOG.md#coverage-of-the-original-remaining-outcomes).

## Execution now

**Selected qualification: one Zenith→Torrent→same Zenith handback.**
Independent cumulative-priority review selects exactly one continuation after the
accepted1f7dccb stair repair satisfies the archived reopening condition. Current
main4e80ef20 is the base; restore only the five final archived caller/observer/
privacy files fromda7d5a954, preserving the accepted Aft and Player source. The
complete frozen route below remains binding, including mandatory actual Guided,
90neutral/current-epoch admission/reclaim, original movement/support/no-placement
checks and300s game/360s outer abort. Exact candidate/package pins precede checks.
Readiness/parse/Python/privacy/export/startup/payload checks precede one route.
Stop at the first unexpected failure; no automatic fifth trial or speculative
repair is selected. Original09:51UTC clock and90minute estimate continue, already
approximately120minutes; archive/cleanup/push remain charged to that goal.

**Roadmap correction applied; PLAN-NEXT remains open.** This documentation pass
preserves all337 IDs, kinds, parent bindings and accepted scopes; tightens nine
existing contracts; and removes duplicate assignment instructions. Inventory,
section-anchor and local-link checks pass. That documentation pass selected no gameplay run, export or parked-route
retry. Remaining missing routes, member lists and owner inputs keep
the executable breakdown open; blocked records cannot enter implementation.

**Accepted capability: supported Aft stair-base lateral crossing.** Checkpoint
`1f7dccb` adds a visible, tapered shoulder to the existing landing; original ramp,
landing box and Player remain unchanged. Actual old capsule sweep hits the ramp's
steep edge. The corrected fixture now retains floor/support for all74 samples,
max3D movement0.111205m against the original0.211667m guard, then stops at zero
velocity. Full Player/Aft/station-surface/interior checks, isolated Forward+
capture, paired exports, three strict startups and actual1529-entry payload audit
pass. Only the compiled Aft module changes from3649b4b.
[Exact result, failures and source limits](docs/history/ROADMAP_DELIVERIES.md#aft-stair-base-supported-contact-accepted-20261026).
Full handback remains PARKED; no fourth whole route ran. Integration is pushed;
owned branch/worktree/process/scratch cleanup is complete with a verified archive.
Archive closure records114.325minutes from the original09:51UTC start against
the90minute estimate; final closure cost remains in closeout.json. Only `main`
remains locally; unrelated detached diagnostics are retained.

**Zenith/Torrent handback is parked and unqualified.** Three bounded native
trials stopped before Torrent boarding, Guided or Zenith reclaim. The final run
lost grounded contact at StairBaseLanding despite support probes below it.
[Exact failures, reopening condition and preserved source](#zenith-torrent-handback-parked).
The three archived trials remain unaccepted. Exactly one continuation is now
selected above after the demonstrated stair repair and independent priority review.


**Accepted qualification: Zenith settled Main detach/re-entry.**

Source `a70f9397a51845c65d068047d95a5667464782a7` passes the existing suite in45.495s,
exit0, one marker and no diagnostics. Same re-resolved identities, healthy ledger,
lease/OFFLINE/source1104 and empty settled claims/effects survive re-entry. The
same controlled Player physically walks3.226154m in the sampled move-left
direction while grounded; Zenith stays still and unpiloted.
[Exact qualification and remaining scope](docs/history/ROADMAP_DELIVERIES.md#zenith-settled-main-reentry-qualified-20261026). Production matches the existing
3649b4b checkpoint byte-for-byte at source; no new gameplay/art or duplicate build.


- **Goal:** close only CRAFT-ACCEPT-ZENITH's settled retained-Main predicate.
  Existing ordinary pilot/hit/two-home/reuse/normal Quit results stay accepted.
- **Starting state:** clean source descended from `d59b13ee7`; exact test commit
  recorded before execution. Existing `zenith_fleet_dock_integration_test.gd`
  completes its unchanged staged sortie and four exit-settle ticks. Require
  APPROACH_SHIP, unseated controlled Player, boardable/unpiloted healthy Zenith,
  OFFLINE, strict occupied/reserved own berth, no transition or reserved boarding
  claim, and neutral inputs. This is source/staged qualification, not ordinary flight.
- **Actions:** snapshot identities, ledger, lease, controls and settled effects;
  remove the same Main, wait one process frame and re-add it. Check restoration
  within at most30 physics/process pairs. Apply real move_left for24 pairs from
  the retained live exit pose; release and observe10 neutral pairs. No new pose,
  velocity, health, cooldown or phase staging is added to the existing fixture.
- **Pass/fail:** same re-resolved Main/world/Player/Zenith/berth/feedback/art,
  ordered fleet/resources/source1104 and valid restored combat roster; same
  component model/ledger, hull, dock transform/lease/OFFLINE and on-foot ownership.
  Settled pulse/damage/audio effects and boarding claim remain empty; no stale
  ownership is resurrected. The Player remains grounded and unseated/controlled,
  moves more than0.05m in the actual move-left direction, while Zenith stays still
  and unpiloted. Missing precondition or changed preserved state is a failure.
- **Proof:** existing `tests/zenith_fleet_dock_integration_test.gd`, headless and
  `--audio-driver Dummy`, actual exit0 and exactly one
  `ZENITH_FLEET_DOCK_INTEGRATION_TEST_OK`; retain source SHA, raw logs and process
  identities. Existing suite maximum300s and existing sortie waits stay unchanged.
  New30/24/10-frame observations and0.05m movement are declared fixture bounds,
  not historical whole-craft deadlines or performance claims.
- **Dependencies/limits:** existing staged Main/Zenith fixture and public ledger,
  claim, command/effect/roster observers plus read-only `_transition_busy` for the
  exact no-transition predicate. Movement follows the actual camera-relative
  Player move-left direction sampled before the walk; no pose staging.
  Empty settled claims/effects prove absence of stale resurrection, not retirement
  of populated in-flight claims. Damage/repair/loss/handback/art/native gates remain open.
- **Stop and closure:** stop at first unexpected failure for causal review; no
  automatic retry or enlarged cap. Original09:40:00UTC clock, estimate45minutes
  includes definition, checks, review, integration/push and owned cleanup. No
  identical checkpoint is needed for tests/docs-only qualification; a demonstrated
  runtime repair requires focused checks and a fresh playable checkpoint.


Integrated/pushed; owned branch/worktree/processes and loose scratch are closed
with a fully verified archive. Only `main` remains locally; unrelated detached
diagnostic worktrees are preserved. Closure preparation records 11.478
cumulative minutes against the original45minute estimate. Production is unchanged.

**Accepted goal: shared Reduced flash save/cold/Reset caller.**

Result: checkpoint `3649b4b` passes the actual embedded native Linux sequence in
79.507s: three distinct processes exit0 and are reaped; live/new cue, disk values,
whole Reset/defaults, saved feedback, dirty state and both clean markers agree.
Production persistence 47, Main effects 70, reset UI 10/feedback UI 11 assertions pass.
All 14 final stages, three strict startups and actual 1,529-entry PE/ELF audit pass.
Only existing GameFlow/Boot/UID-cache entries change; one probe/remap is added.
[Exact proof, retained failures and scope](docs/history/ROADMAP_DELIVERIES.md#shared-reduced-flash-native-restart-accepted-20261026).

The check demonstrated and repaired a missing canonical setting→HUD forwarder:
runtime/disk ON previously left the same live flash at 0.24. The same production
result now reaches the existing HUD dirty-state presenter. Existing feedback
strings, settings authority and 0.42/0.62s cue policy remain unchanged. This is
synthetic-keyboard UI/component proof; physical input/rendered/native Windows/
GPU/human and remaining ordinary producer episodes stay NOT_RUN/open.


- **Starting state:** base `3ebae8bac`, accepted game `3649b4b`, clean native Linux
  export, one new
  owned private profile; normal Boot creates Main and authored settings. Reduced
  motion remains OFF and payload intensity remains authored default2/high.
- **Actions:** raw keyboard input starts normal gameplay, opens Escape→Settings,
  toggles Reduced flash OFF→ON→OFF→ON, presses APPLY + SAVE and normal Quit.
  A distinct process loads ON, uses RESET DEFAULTS and normal Quit; a third loads
  OFF and all authored defaults, then quits. Actual HUD damage cues are staged
  presentation components, not a combat route.
- **Pass/fail:** visible checkbox/runtime/actual cue/durable primary agree;
  live cues retain their existing duration and no-relight policy; Save/Reset
  feedback and dirty state agree. All three distinct processes exit0, are reaped,
  preserve an unrelated production-store namespace and write both orderly markers.
- **Proof:** `tools/release/run_package_probes.sh --settings-restart --native-export`
  against `builds/linux/MuddsShipyards-3649b4b.x86_64` from source
  `3649b4bbb34742a4fd9d076576c6665fc4355a5f`. Exact accepted command/profile/result
  lives in the closure archive's `green/configs/native-preferences.json` and
  `green/native-probe/shared-reduced-flash/`; maximum300s per process unchanged.
- **Dependencies fulfilled:** embedded Boot-owned caller and early private-profile/CLI
  admission; no seeded preference file or replacement persistence authority.
  Physical input, rendered visibility, native Windows/GPU and ordinary producer
  episodes remain NOT_RUN/open and cannot be closed by this probe.
- **Stop and closure:** first unexpected failure stops the attempt for causal
  review; no timeout growth or clock reset. Estimate90minutes from
  2026-10-26 08:47:00UTC includes readiness, failures, checks, paired checkpoint,
  integration/push and exact owned branch/worktree/scratch cleanup. Close only
  this shared executable preference proof; COMFORT-FLASH stays open.


Integrated/pushed; owned branch/worktree/processes and loose scratch are closed
with a fully verified archive. Only the `main` local branch remains; unrelated
detached diagnostic worktrees are retained. Closure preparation records
52.980 cumulative minutes against the original90-minute estimate.

**Delivered production repair: cargo terminals follow Reduced flash.**
Checkpoint d4e2213 forwards the real setting through loaded/new Cinder clusters
and repaints the exact retained terminal record. Existing carrying/terminal/
committed/rejected emission becomes at most 1.15 with ON; OFF restores the current
state. Dim states stay dim. Text, refusal/receipt feedback, material identity,
stock, generation, transfer, reward and interaction ownership are preserved.

Focused production-cluster material/authority checks pass 38 assertions across
all seven states; real Main setting/world/streaming-path checks pass 70, including
ON before load, same-instance live changes and a fresh OFF generation. The Main
terminal is unavailable (0.18); focused fixtures prove higher-energy state caps.
Observer samples are staged through the normal streaming caller with competing
Main physics suspended. This is component integration, not ordinary cargo travel.
Readability 10, terminal 68 and audio 41 assertions pass. All 12 final stages,
paired exports, three strict startups and the 1,527-entry audit pass; only the
two intended nearby-sector scripts differ in the game payload.
[Exact proof, preserved failures and remaining gates](docs/history/ROADMAP_DELIVERIES.md#cargo-terminal-reduced-flash-production-binding-accepted-20261026).

The obsolete focused-test reset of an unpaid completed delivery was corrected
to a genuine ACTIVE reset plus explicit completed-unpaid refusal; the guard is
unchanged. Original-main reproduction and the Main fixture's type-only failure
remain preserved. The shared preference path is now accepted in3649b4b above; full cargo/comfort,
physical input and native Windows/GPU/human gates remain open. All readiness, failures, checks, builds and
closure stay on the 08:10:00 UTC clock against a 60-minute estimate; no cap reset.
Integrated/pushed; owned branch/worktree/scratch closed after verified archive.
Closure documentation records 35.731 cumulative minutes.

**Delivered definition: finite Reduced flash producer/episode contract.**
The existing COMFORT-FLASH row now binds17 actual producer families to authored
OFF/ON/current/new values, real forwarders and existing test anchors. Shared
ordinary Settings→Apply+Save→distinct Boot→Reset→third Boot endpoints are literal.
[The finite contract and exact remaining owners](docs/ROADMAP_BACKLOG.md#reduced-flash-producer-and-episode-contract)
replace an unspecified consumer list; do not repeat an unchanged source survey.

The cargo terminal production flag gap identified by this definition is now
accepted on d4e2213 above. The shared Reduced-flash native cold/reset caller
is now accepted in3649b4b; unbound normal effect triggers/observers remain
Codex-owned gates.
No new visual-policy choice is needed for these existing source behaviors.
Accepted HUD/torpedo results remain closed. This delivers a source definition,
not new gameplay, an ordinary episode pass or hardware/human qualification.
Source review and linked-file/17-family/337-identity checks pass; no engine,
new test, package, implementation branch/worktree or scratch folder was created.
Cumulative definition work from07:55:00UTC is13.885minutes at closure
preparation against30minute estimate, including review and documentation.

**Delivered production repair: live torpedo bursts adopt Reduced flash.**
Checkpoint9105da8 updates the same existing burst's material and current-age
scale immediately. Authored normal/reduced emission4.0/1.2, peak scale4.2/2.6
and0.55s envelope are unchanged. Actual mesh tests cover hit, interception and
both launcher-loss bursts, repeated toggles, exact position/lifetime/slot/
flight/damage/collision preservation and expired effects staying hidden.
Projectile106, opponent35 and production Main combat-effects60 assertions pass;
all10 final checks, paired exports, three strict startups and actual1527-entry
package audit pass. Only the Seeker projectile differs in the game payload.
[Proof, retained failures and scope](docs/history/ROADMAP_DELIVERIES.md#live-torpedo-burst-reduced-flash-accepted-20261026).

This closes the live terminal-burst capability. Ordinary settings UI/Reset/cold
comfort episodes, full combat/family and native GPU/human review remain open.
The companion's obsolete two-contract rotation expectation was corrected to the
shipped Paired Wing next contract after unchanged-main reproduction; no board
behavior changed. The first old-run expected-label mismatch and companion
failure remain preserved. All readiness/checks/build/closure cost runs from
07:32:00UTC against45minute estimate, without a clock reset or enlarged cap.
Integrated/pushed; owned branch/worktree/scratch cleaned after verified archive.
Closure documentation records22.220 cumulative minutes.

**Delivered production repair: Ember checkpoint on ordinary application quit.**
Checkpoint8e74c40 saves through the existing production collector in the existing
quit owner, before actor/lease teardown. The actual Main Quit test passes157
assertions: live actors, current nonorigin coordinate, incomplete route/optional
progress, exactly one Ember commit, retained foreign data and fresh-store read.
The unchanged detached-actor guard prevents the late teardown from overwriting it.
Existing checkpoint resume, safe-start shutdown and session diagnostics pass.
Actual exported disk/restart case passes196.033s: final ordinary Quit writes the
exact new checkpoint0; original passive checkpoint1, whole ledger/settings/cargo
remain exact. Planned arm2076894/-9 and distinct resume2077238/0 are reaped.
All 14 final checks, three strict startups and1527-entry package audit pass.
[Proof, failures and exact remaining scope](docs/history/ROADMAP_DELIVERIES.md#ember-ordinary-quit-checkpoint-capture-accepted-20261026).

This closes automatic capture for the tested incomplete on-foot application-Quit
path. Staged outbound/corridor/boarding setup is disclosed. Arbitrary Main
removal/streaming, full ordinary travel/home/exit/reuse, completed-debt disk
restart and native Windows/GPU/human gates remain open. Test syntax and wire-type
comparison failures are retained; neither reset the task clock. All readiness,
failures, checks, builds and cleanup run from07:01:00UTC against90minute estimate.
Integrated/pushed; owned branch/worktree/scratch closed after verified preservation.
Closure documentation records31.014 cumulative minutes; no task clock reset.

**Delivered release capability: exported pending-abandon cold restart.**
Gameb30a9ea93/driver7337dc543, checkpointb30a9ea: one exact native Linux
ELF run passes195.384s under original300s per game/660s outer. The real first-
relay save is declined through public Abandon while physical return is pending.
Independent .bak/primary reads verify raw bytes, direct CAS ancestry, unchanged
production receipt identity and foreign data. Planned SIGKILL reaps2066564/-9;
a distinct Boot2066836 exits0 after safe-yard control, new boarding and a fresh
admitted survey at index0. No old checkpoint/location adoption or reward occurs.
Actual final ledger, original passive archive and foreign payload remain exact;
no new quit checkpoint was saved in this run. All owned children are reaped.
[Actual proof, limits and closure](docs/history/ROADMAP_DELIVERIES.md#ember-pending-abandon-native-cold-restart-accepted-20261026).

First native trial stays FAILED116.544s before restart: its driver compared two
coordinate wire decimals that Godot re-encodes after parsing, despite unchanged
receipt hashes/route. One reviewed driver-only correction uses the already
validated pre-abandon runtime envelope, retaining raw-file/hash/CAS/foreign-data
fences, with no epsilon or cap change. Captured offline check and four corrupt
controls pass. Game/runtime/test/assets and actual artifact hashes are unchanged;
nine exact-game checks are retained, driver syntax/compile rerun and corrected
native case passes. Three strict startups and1527-entry PE/ELF audit pass; only
probe and Boot compiled scripts differ from34f60da. Original CLI gate rejected
only the two new stage positives before the three-line Boot change.

Scenario uses real files/two OS processes with disclosed boarding timings and
orbital/corridor placement. It is a pending-return cut, not home/exit/reuse,
ordinary OS-input travel or completed-debt disk proof. Standing-pose restoration
is NOT_SUPPORTED. At b30a9ea ordinary Ember quit capture was unresolved;
application-Quit capture is now accepted in8e74c40 above. Arbitrary scene removal
remains open. The protocol requires the new visit's exact fresh-zero receipt. Existing ember/default case is unchanged and not
replayed. All work includes readiness, failure/correction and closure from
06:03:21UTC against60minute estimate; no task clock or original cap was reset.

**Delivered production repair: saved Ember checkpoint abandonment.**
Checkpoint 34f60da uses the existing Ember planner for one atomic decline of the
exact observed receipt before accepted explicit solo abandonment. Read-only current Host/session/
cruise/controller/ship guards reject before storage or live survey flags change.
Completed earned debt survives; ordinary shutdown/resume, no-saved-receipt and
manual return keep their existing paths. Accepted approach cancellation retires
its staged composition so a retained GameFlow can start a fresh visit too.

Old source050094284 fails exactly nine original loss/refusal assertions in17.614s;
repaired lifecycle passes17.614s.
Two added same-instance assertions and one existing missing-ship probe assertion
cover concrete source-review regressions. All seven selected source suites pass
at original300/900s caps, including manual return
130.592s. Clean paired exports, three strict
menu startups and actual PE/ELF/archive audit pass; exactly the seven expected
compiled runtime scripts change from acceptedf51e02a. Independent final review GO.
[Actual proof/limits/closure](docs/history/ROADMAP_DELIVERIES.md#ember-explicit-abandon-checkpoint-accepted-20261026).

Lifecycle proof uses MemoryFilesystem, staged Host admission and fresh GameFlow/
store objects; the manual-return fixture discloses orbital/corridor staging.
Ordinary OS-input packaged world abandonment, actual-disk interruption/restart,
shared/full-world/final gates remain open. No autosave is invented: ordinary save
caller is tree exit; the live-save refusal control explicitly calls the public
save seam. All cost stays cumulative from05:22:30UTC against60minute estimate,
including readiness, old RED, implementation, validation/build and cleanup.
The task branch is deleted; a verified archive/closeout replaces loose scratch,
and16 supervisors/58 observed process identities are absent. Archive closure
was39.943 cumulative minutes, within the60minute estimate; final Git closure
remains on the same clock in closeout.json.

**Delivered production repair: unpaid survey credit at visit end.**
Checkpointf51e02a preserves Aurora/Rime genuinely completed but unpaid observations
through the existing passive owner in one atomic end-visit retirement write.
Primary/receipt/generation/paid validation, publication refusal and conflicting
unpaid archives preserve prior data. Incomplete/paid retirement and universal
interrupted-resume retirement retain their existing paths.
The old runtime fails exactly eight loss assertions in93.101s; repaired lifecycle
suite passes96.617s and existing
quit/resume suite passes250.040s,
both OS0/one success marker/no diagnostics. Real files/fresh Main/staged current
surface arrival prove passive debt and legitimate once-only retry; this is not
ordinary physical return or a distinct OS restart. Clean paired exports, three
strict menu startups and actual PE/ELF/archive audit pass; only compiled shared
surface expedition differs from accepted30534f5. Independent final review GO.
[Actual source/proof/limits](docs/history/ROADMAP_DELIVERIES.md#surface-survey-unpaid-retirement-accepted-20261026).
The initial test-only parse failure remains FAILED. All cost includes the prior
world-definition/source pass from04:50:31UTC against the60minute estimate;
the task branch is deleted and loose scratch consolidated into a verified
archive/closeout;12 supervisors/50 observed owned process identities are absent.
Archive closure was31.115 cumulative minutes, including the preceding definition
pass; [closure details](docs/history/ROADMAP_DELIVERIES.md#surface-survey-unpaid-retirement-accepted-20261026). Full
WORLD-ABANDON/WORLD-SAVE, ordinary package and final gates remain open.

**Delivered: Zenith pilot handling, real hit, two homes and fresh reuse.**
Checkpoint4bf5e88, release driver4870595: one complete ordinary route passes
in133.691s, including physical walking/boarding, boost above94m/s cruise,
measured30.80° roll, brake/hover/both cameras, one real28-point repeater hit,
two strict home landings/90neutral ticks/OFFLINE, physical exits and wing-clear
walks, fresh consumed pilot stream, and normal HUD Exit/OS0 with both durable
clean states. Full Python checks and actual payload audit pass; seven unchanged
runtime/package checks and three strict startups are retained against exact
GameSource4bf5e88 identity. Independent final review GO.

This closes only CRAFT-ACCEPT-ZENITH's pilot/hit/home/reuse qualification and
its executable release-driver capability. Component damage/repair, loss and
regeneration, Torrent handback, retained-Main, art/device and final-candidate
requirements remain OPEN in its [finite binding](docs/ROADMAP_BACKLOG.md#zenith-finite-acceptance-binding).
The four earlier trials remain FAILED, with source/raw retained and cumulative
cost charged from the same original start. The retired exact15tick procedure
was an executor assumption; the physical predicates were fixed before trial3.
[Actual result, failed trials and limits](docs/history/ROADMAP_DELIVERIES.md#zenith-pilot-hit-home-reuse-accepted-20261026).

**Definition recorded: WORLD-ABANDON-DEFINE.**
The [finite abandonment/next-visit binding](docs/ROADMAP_BACKLOG.md#world-abandonment-and-next-visit-binding)
now separates Aurora/Rime survey abort, airborne approach abort, physical return
and lifecycle rescue; it fixes the uncovered Ember next-visit and real-file
abandonment/restart endpoints. The unpaid-debt end-visit loss is now reproduced and repaired above with
real-file/fresh-Main proof; distinct OS restart remains unqualified. One bounded source pass
ended with the missing ordinary/package commands, fixtures and original limits
assigned to Codex. No engine or qualification ran; no product goal closed.
Do not repeat this source survey or use staged Ember interruption as ordinary
packaged ABANDON proof. Existing full-world and durability gates remain open.

**Delivered production repair: carried-cabin floor contact.**
Checkpoint30534f5 integrates the reproduced PlayerController repair and unchanged
captured regression. An on-foot, previously grounded Player in a live moving
cabin now retains actual floor contact across positive approximately-zero upward
tangent residue, through the original gravity/move/snap/recovery path. Genuine
jumps, airborne motion, missing support and original margins remain covered.
The integrated Player suite passes50.208s/OS0/one marker/no diagnostics; existing
Bulwark floor contract passes6.877s. Clean paired exports, three strict menu
startups and exact1527-entry PE/ELF/archive audit pass; only compiled
PlayerController differs from accepted4bf5e88. Independent final review GO.
[Source, actual proof and retained limits](docs/history/ROADMAP_DELIVERIES.md#carried-cabin-floor-contact-accepted-20261026).

This closes only the demonstrated collision repair found under
CRAFT-ACCEPT-BULWARK. All six ordinary gunner trials below remain FAILED and
parked; no route retry or broader craft acceptance is selected. Extraction/check/
build/closure cost remains cumulative from02:37:33UTC, including the recorded
90minute estimate overrun. Actual hardware and final-candidate gates stay open.

**PARKED: CRAFT-ACCEPT-BULWARK ordinary solo gunner journey.**
No implementation or qualification retry is selected. Six ordinary-route trials
remain FAILED. The latest candidate `96197bf` failed the frozen outward-flight
15s bound after101.287s; it never reached gunner acceptance. The supervisor's
final source guard also failed because a separately authorized Zenith roadmap
edit changed the working tree during the frozen run. That provenance failure is
retained alongside the runtime failure, not repaired by relabelling the result.
Inputs were released and game/input helper/Xvfb reaped; all49 recorded stage
supervisors were absent at2026-10-26T04:37:58UTC. No checkpoint was published.
Cumulative elapsed cost was120.42minutes from the same original02:37:33UTC
start, exceeding the90minute estimate; closure time continues against that goal.
Unique source, all six failures, raw results and failed build bytes are preserved
in `/srv/mudds-work/bulwark-gunner-home-20261026/records.tar.gz` with verified
source bundle and adjacent `closeout.json`. Both owned task branches are removed
(the failed gunner branch remotely too), without merging its unaccepted harness.
After full archive verification,32 unaccepted public scratch build files and
owned private loose files were removed;58 supervisors/269 observed process
identities were absent. The task folder now contains only archive and closeout.
Archive closure cost was132.29minutes from02:37:33UTC; final closure is recorded
against the same clock in closeout.json. Unrelated retained worktrees are untouched.

Reopening requires a demonstrated cause and bounded correction for the actual
outward-flight failure, an independent cumulative-priority decision and a clean
frozen candidate. The original complete contract and limits below remain fixed;
the passing carried-floor regression alone does not close this journey.

The [finite acceptance binding](docs/ROADMAP_BACKLOG.md#bulwark-finite-acceptance-binding)
is retained. This selected executable release capability must start at normal
Begin Shift, physically walk/board Dock03, fly the actual Bulwark clear, brake
and neutral-idle to OFFLINE, then Interact into its supported carried cabin.
Walk its real aisle and claim the gunner; native default-HOLD Fire must wake
weapon power without helm and resolve one source1107/picket_siege_lance22-point
hit on actual DRONE-03 (100→78), preserving560m/.45scharge/4.8scooldown and2→1ammo.
Release, physically stand/walk/reseat with fresh claim, then stand/walk/reclaim
pilot; return to strict own home, neutral automatic OFFLINE, exterior exit and
supported clear walking, normal HUD Exit/OS0 and both real durable clean states.

Implementer owns existing observer/native driver/Python fixtures; root owns
startup/privacy, exact-source checks, paired checkpoint, integration/push/cleanup;
one independent lifecycle/source reviewer. Geometry/input and receipts received
preimplementation review GO. The selected coordinates below are engineering
route choices, not new historical performance promises.

| Boundary | Frozen route / observable result |
| --- | --- |
| Dock03 admission | LIFE-ARM prefix through fleet_trunk, then world `[37,4.2,68.3]→[52,4.2,68.3]→[52,6.6,58.9]→[49,6.6,58.9]` and actual boarding marker; stay on the ramp centre before the upper-deck turn |
| Clear flight and genuine carry | Live dock-relative `[0,0,-20]→[0,20,-50]→[0,20,-140]`; upright/outward native+consumed forward input produces actual speed≥12m/s and<30, then all propulsion releases and90neutral/OFFLINE. Actual hull displacement≥.10m **during** the supported aisle walk; all tail samples retained |
| Physical cabin | Live hull-local `[-.62,1.33,.40]→[-.62,1.33,1.80]→[1.25,1.33,1.80]→[1.25,1.33,.65]`; actual capsule/frame support, containment and current physical gunner claim |
| Finish exterior walking | After pilot reclaim and strict home/OFFLINE/exit: world `[49,6.6,58.9]→[52,6.6,58.9]→[52,4.2,68.3]`; actual raised-deck/ramp support before normal HUD Exit |

Native300s/outer360s are executor abort bounds,
not a historical full-craft deadline; walk/cabin15s, boarding/seat12s, hit25s,
exit10s and actual Hero landing timeout/4sstall remain. No staged poses, direct
input injection inside the game, target/damage/timer changes, pilot shots or
extra helm authority. Every observation and actual release tail is retained.

Estimate90minutes from2026-10-26T02:37:33UTC including checks/build/closure;
this is an engineering estimate, not a user budget. Stop the current pipeline
on first unexpected failure and retain source/raw for causal review; any later
continuation retains cumulative cost. Other pilot second-flight/full component
repair/loss/Torrent handback/Main/art/network/final gates remain OPEN. No test,
engine or export runs before completed-source review. Titan remains blocked on
its recorded design choice; no answer is assumed.

<a id="concrete-pending-capability-ember-surface-loop-captions"></a>
### Ember surface-loop captions: accepted capability contract

Existing goal: **COMFORT-CAPTIONS**, one production capability. For each base ID
below, both existing `_interior` and `_exterior` emissions must display the exact
caption through the shared HUD caption service: exactly18 registry entries.

| Existing cue base | Exact caption | Default severity |
| --- | --- | --- |
| `ember_surface_descent` | Ember descent | medium |
| `ember_surface_landed` | Ember landing complete | low |
| `ember_surface_on_foot` | On foot on Ember | medium |
| `ember_surface_reboard` | Ember craft reboarded | medium |
| `ember_surface_takeoff` | Ember takeoff | medium |
| `ember_surface_ascent` | Ember ascent | medium |
| `ember_surface_orbit_return` | Returning to Ember orbit | medium |
| `ember_surface_abort` | Ember surface journey aborted | high |
| `ember_relay_survey_reward_confirmed` | Ember relay survey reward confirmed | low |

Owned files: `scripts/ui/semantic_audio_cue_presenter.gd`,
`tests/semantic_audio_cue_presenter_test.gd` and
`tests/audio/ember_surface_loop_audio_composition_test.gd`.
The existing production binding supplies these IDs; the repair adds captions,
without new emissions or changes to phase/reward authority or replay policy.
Existing intensity1.0 promotion to high remains; registry-default checks must
use an intensity that does not promote severity.

Pass requires all18 literal caption/default assertions, followed by all18 actual
composition→Director→GameFlow→visible-HUD deliveries and expiry through one
shared service. Repeated/unauthorized/refused/replayed/stale/detached observations
stay silent; captions OFF suppresses display and re-enabling does not replay.
The old registry must fail exactly the18 new caption assertions. The repaired
source must pass the focused checks, paired exports, strict package startups
and payload audit, then receive a checkpoint and independent acceptance review.

The integration uses the existing `EmberSnapshotFixture` owner and controlled
reward observations with real production audio/HUD components and a manual
caption clock. It proves this caption capability; it does not prove a physical
surface journey, real durable reward, listening, rendered/device or full comfort
acceptance. Those existing gates remain open. Original assignment window:
2026-10-25 23:44:40→2026-10-26 00:44:40UTC, including review/build/closure;
the original budget includes the roadmap correction and all closure work. No
new task or repeat is selected by this delivery.

Accepted checkpoints and qualifications are listed under [accepted work](#accepted-work--source-limits-retained).
Failed journeys and their exact reopening conditions are under
[parked work](#parked-failures-and-dependent-work). Their retained delivery
history supplies the full proof; neither list automatically schedules a rerun.

### Blocked definition work — not an execution queue

At most one implementation assignment may be active. The following rows are
blocked preparation work, not a backlog of runnable implementation tasks.
Use the existing backlog row for each result; do not create another tracker.

The following are **finite definition outputs**, not promises to implement whole
features. Codex owns source-resolvable fields. Each selected definition gets one
15–30 minute pass, then stops with the literal answer or an exact missing input
and owner in that same row. Do not repeat completed source surveys or run games
to discover what acceptance should have been.

| Existing outcome | Output required before implementation or qualification | Proof that the definition is finished |
| --- | --- | --- |
| CRAFT-ACCEPT, one named craft | Ordered uncovered physical/function/damage/recovery/home/reuse/switch/Main steps; each mapped to retained proof or an existing route, expected endpoint and original limit | Every required step has a proof reference or a named unavailable route/input. Accepted Torrent/Arrow steps remain closed; parked failures keep their reopening conditions. One craft per assignment. |
| STATION-FINDINGS, one existing branch/view | One supported camera position/height, source, renderer/quality/resolution/scale and the exact text/access/clearance checks | A frozen view can receive either an inspected no-finding result or one reproducible defect. Use the nine-branch/four-service roster; do not reopen parked captures. |
| ART-FINDINGS | Map the existing 13 capture sets/143 images and original fleet/world/character/effect/UI obligations to accepted coverage or literal missing views | Each uncovered view names its original promise, subject/state and comparison conditions; the station subset is referenced once. No new art obligation inferred from an empty area. |
| SHARED-EMBER-BASELINE | One craft, actual peer roles, outward/surface/home route, survey/result/payment/save endpoints and original limits | One complete ordinary baseline command/route with expected durable data, or the exact missing caller/participant/input. This defines one of the existing 21 cases, not a new shared-world matrix. |
| COMFORT-MOTION / FLASH / COLOUR / CAPTIONS, one family | Flash uses its fixed17-family contract: bind only the named remaining normal trigger/caller and shared ordinary preference proof; do not redefine consumers. Other families still need their finite original-required consumers and literal ON/OFF/cold/Reset behavior. | Each missing binding ends in a frozen existing episode or a literal unavailable caller/input and owner. Flash producer/policy definition stays closed; accepted cues remain accepted. No new option or consumer matrix is invented. |
| CREW-RECOVERY-ORDINARY | One existing craft/physical seat, ordinary admission, exact durable commit/kill cut, restart and awake-cabin continuation | Exact protected file delta, fresh-claim/control endpoints, kill/restart commands and original cap. The settled safe-home policy is reused; pose restoration is not reconsidered. |
| RECOVERY-CUTS-DEFINE | Only uncovered installed cuts in the existing on-foot/pilot/cabin/bunk/crew/docking/activity/world contracts | Each cut has its committed boundary, expected debt/payment/data, owned kill/restart, supported continuation and original cap; accepted cuts are reused. Four unresolved active-run policies stay owner decisions. |
| INSTALL-LINUX, one existing transaction | Exact prior/candidate package where needed, owned prefix, fixture, protected files, expected bytes/modes and installed usability route | Clean, upgrade, rollback, retained-data, corrupt-data and uninstall remain six distinct existing goals; one transaction per assignment. Unknown package versions block execution, not definition of the required operation. |
| PERF-ROUTES-DEFINE / PERF-CELLS-DEFINE | Bind the seven existing selectors and original world-endurance workload to minimum/target machines and existing measurement budgets | Workload membership, commands and numeric ceilings are literal; missing device access or genuinely unspecified ceilings have a named owner. No extra craft×world×device axes. |

A definition is allowed to resolve a blocked contract. A blocked capability or
qualification is **not** allowed to execute before that contract is fixed.
Repeatedly recording the same unresolved fields is not another completed goal.
If a source-resolvable definition ends blocked, retain the exact missing artifact
and search boundary; reopening needs new information, not a renamed task.

The complete [decision and resource register](docs/ROADMAP_BACKLOG.md#blocking-decisions-and-resources)
is the source for user-owned blockers: eight craft specifications, additional
Bomber roles, capacity/desktop scope, four active-recovery policies, two cargo
replenishment policies, caption overflow, physical hardware/audio access and
release rights/signing/distribution. Each ends with its recorded answer or
artifact; approval does not count as implementation. Already accepted automatic
freight/shared stock/rejection feedback/Beacon 60s/Bomber seat-refill/Defense arm
choices remain settled and must not be asked again.

Completed source qualifications and checkpoint changes belong under
[accepted work](#accepted-work--source-limits-retained), with exact limits.
Failed trials belong under [parked work](#parked-failures-and-dependent-work),
with their first failure and causal reopening condition. Neither is a next task.

### Work order after this correction

1. Select one ready capability, qualification or definition from the canonical
   inventory and state its kind. A capability changes production behavior;
   qualification closes a named original acceptance predicate on a fixed
   candidate; definition supplies one finite missing contract. If a ready
   production capability exists, select it unless a named dependency requires
   other work first. If none exists, finish one bounded readiness pass with exact
   blockers and owners; do not generate a chain of handoffs or discovery cards.
2. Split its production implementation into capabilities estimated at no more
   than90 minutes each. Name each capability's files, observable result and focused
   check before editing. A fleet, world, activity family or final matrix is a
   milestone/container, never one implementation assignment.
3. Deliver and close that capability, then run its retained complete journey when
   its prerequisites hold. A short regression can prove the repair; it cannot
   replace the original full journey, repeat count or deadline.
4. Qualify the stable integrated candidate through the existing release gates.
   Reuse accepted results within their recorded scope. Re-run affected checks when
   code changes invalidate them; do not restart every completed journey by default.

## Turning a goal into one assignment

Use the single [assignment contract above](#how-we-will-work-from-this-roadmap).
Keep one selected card in Execution now; retain accepted and parked contracts
below as references. A smaller regression closes only its named repair. Original
full journeys, repeat counts and deadlines remain separate required outcomes.

### Stop rules that prevent another loop

- Freeze acceptance before editing. Add a case only for an identified uncovered
  original requirement; record why, rather than silently moving the finish line.
- Stop the selected check at its first unexpected failure. Preserve the result
  and source. Diagnose the actual owner; do not build another validator or extend
  the deadline to convert failure into success.
- One attempted repair followed by failure requires a cumulative priority review:
  park/switch, or justify one bounded continuation with a demonstrated cause and
  explicit stop. There is no automatic retry chain.
- Close or park the active card before switching tasks. Preserve unfinished unique
  source. Merge accepted work into main, push, remove completed owned branches and
  worktrees, and release owned processes/scratch. Cleanup is part of completion.
- A meaningful working gameplay/graphics result gets a fresh Windows checkpoint
  through the existing clean-commit workflow. Include actual checks and player
  changes. Documentation/private diagnostics alone do not require an identical build.
- In progress reports state: **goal; player result; accepted/failed/blocked;
  first remaining blocker; elapsed cost; next bounded action**. At closure report
  completed named outcomes and the remaining named milestones. Do not substitute
  assertion counts, evidence versions or commit totals for product progress.

## Accepted work — source limits retained

Recent packaged changes and source qualifications are recorded separately:

| Accepted outcome | Proof and retained limit |
| --- | --- |
| Eighteen live Ember surface-loop captions | [Checkpointb810822](docs/history/ROADMAP_DELIVERIES.md#ember-surface-live-captions-delivered-20261026); controlled owner/reward observations through actual visible HUD, ordinary journey/durable reward/full comfort remain open |
| Three live engine-transition captions | [Checkpoint46bae53](docs/history/ROADMAP_DELIVERIES.md#engine-transition-live-captions-delivered-20261025); actual ledger/rig/visible HUD composition, ordinary flight/full comfort remain open |
| Guided installed normal-exit prerequisite | [Checkpoint 39157e8](docs/history/ROADMAP_DELIVERIES.md#guided-installed-normal-exit-accepted-20261025); one actual direct-ELF flight/normal Exit/OS0, rendered desktop/final 3/3 remain open |
| Sprint/boost option cold restart and Reset | [Three-process proof](docs/history/ROADMAP_DELIVERIES.md#sprint-toggle-cold-process-qualified-20261025); source composition, physical devices/boost flight/original Settings return remain open |
| Interact remap, conflict Cancel and cold Reset | [Three-process proof](docs/history/ROADMAP_DELIVERIES.md#interact-remap-restart-qualified-20261025); synthetic raw input, not physical devices or original Gate C |
| Four final-approach captions | [Checkpoint 4aa8b64](docs/history/ROADMAP_DELIVERIES.md#final-approach-live-captions-delivered-20261025); composed visible HUD, ordinary planetary flight and full comfort acceptance remain open |
| Five Loadmaster captions | [Checkpoint 19336f3](docs/history/ROADMAP_DELIVERIES.md#loadmaster-live-captions-delivered-20261025); rejection has component proof only, with [no demonstrated reachable requester refusal](docs/history/ROADMAP_DELIVERIES.md#loadmaster-refusal-readiness-not-selected-20261025) |
| Current damage Reduced flash | [Checkpoint 1a948d9](docs/history/ROADMAP_DELIVERIES.md#current-damage-reduced-flash-accepted-20261025); accepted active-cue episode; shared native save/cold/Reset now DONE3649b4b, remaining family/device/final gates open |
| Current toast and damage Reduced motion | [Toast](docs/history/ROADMAP_DELIVERIES.md#current-toast-reduced-motion-accepted-20261025), [damage](docs/history/ROADMAP_DELIVERIES.md#active-damage-reduced-motion-accepted-20261025); accepted episodes, not all consumers/device/final gates |
| Combat terminal posting durability | [Exact delivered behavior](docs/history/ROADMAP_DELIVERIES.md#combat-terminal-posting-persistence-accepted-20261025); preserves genuine next posting and pending-write refusal, ordinary complete combat journeys remain open |
| LAN expiry and retry | [Checkpoint ca149d6](docs/history/ROADMAP_DELIVERIES.md#lan-browser-expiry-accepted--2026-10-25); paused monotonic 30-second expiry/fresh admission, not full network/endurance acceptance |

Other accepted child outcomes include
[shared Main source lifecycle](docs/history/ROADMAP_DELIVERIES.md#shared-main-source-lifecycle-accepted-20261025),
[physical Torrent–Arrow handoff/reclaim](docs/history/ROADMAP_DELIVERIES.md#torrent-arrow-physical-handoff-accepted-20261025),
[Torrent incoming core damage/passive repair](docs/history/ROADMAP_DELIVERIES.md#torrent-core-damage-passive-repair-accepted-20261025),
[Torrent packaged return/reuse](docs/history/ROADMAP_DELIVERIES.md#torrent-return-reuse-capability-accepted-20261025),
[six Settings extreme-scale/scroll component views](docs/history/ROADMAP_DELIVERIES.md#settings-4x3-extreme-views-inspected-20261025),
[corrupt-primary read-only fallback and continuation](docs/history/ROADMAP_DELIVERIES.md#corrupt-backup-read-only-fallback-accepted-20261025),
[Central walking/launch/home](docs/history/ROADMAP_DELIVERIES.md#central-station-accepted-proof-reused-20261025),
[Hauler conserved delivery](docs/history/ROADMAP_DELIVERIES.md#hauler-supply-first-play-accepted-20261025),
[Race and home](docs/history/ROADMAP_DELIVERIES.md#race-first-play-accepted-20261025),
[Patrol relay](docs/history/ROADMAP_DELIVERIES.md#patrol-relay-first-play-accepted-20261025)
and [browser join/solo walking](docs/history/ROADMAP_DELIVERIES.md#browser-join-supported-walking-20261025).
They stay accepted for their recorded source/route. Their cold/repeat/device/final
candidate requirements remain separate; no automatic unchanged rerun is selected.
Full chronological results belong in the existing
[delivery history](docs/history/ROADMAP_DELIVERIES.md), not the execution queue.

## Parked failures and dependent work

<a id="zenith-torrent-handback-parked"></a>
### Zenith→Torrent→same Zenith handback — PARKED / NOT QUALIFIED

Three native Linux/Xvfb OS-input trials failed; no fourth is selected. Game
`f28f923d2d67b1f52416c7d2591b6e3bfcbd3d40`, final unaccepted driver
`da7d5a95456d767ae341ac843bc45833c3df3df0`. Normal Zenith admission/90neutral/OFFLINE/physical exit
and the wing-clear prefix were observed. Torrent boarding, mandatory real Guided,
Torrent home/exit and same-Zenith reclaim were **never reached**.

| Trial | Actual elapsed | First failed predicate |
| --- | --- | --- |
| 1, original driver | 56.682s | Corner cut after wing-clear: both floor rays false at2307/2308; existing safe-corner steering/settling subsequently reused without changing points or checks. |
| 2, corrected corner | 67.867s | Stair-base sprint: grounded/support true, but ~0.1552m horizontal plus0.1668m descent gives3D~0.2278m above unchanged0.21167m guard. No solver allowance was added. |
| 3, normal authored walk | 68.320s | At2938 Player loses grounded contact while both probes still see StairBaseLanding; actual horizontal gait≈5.8m/s. Support/grounding requirements reject the run. |

Each correction received independent causal/cumulative-priority review. Exact
prior failures remain failed. Final241 Python regressions pass, including the
failed sprint sample still being rejected. Import/privacy/observer parse, paired
exports, three strict startups and1,529-entry actual payload audit pass in their
recorded scope; only Boot/observer compiled scripts differ from3649b4b. An earlier
observer-helper scope parse failure and its three-line fix are retained too.
Driver-only corrections reused exact f28f923 game bytes and runtime checks; no
identical re-export or accepted gameplay/handback result is inferred.

**Reopening condition (Codex-owned):** reproduce and validate the production
Player/geometry descent at the captured StairBaseLanding transition, with a
concrete continuously grounded, supported traversal satisfying the existing3D
motion/epoch/no-placement checks. Bind the actual locomotion owner and focused
regression before a new independent priority decision and complete-route trial.
Do not relax grounding/displacement or invent a solver receipt. The accepted
1f7dccb prerequisite supplies the demonstrated physical repair; the three old
trials did not. Any continuation retains the original09:51:00UTC clock and
failed cost; no renamed task resets it. The original full handback remains below.
The new route is archived and **not available in main**.

All21 supervisors/79 observed owned process identities are absent. Inputs and
input helper/game/Xvfb were released/reaped in every failed trial, with zero game
diagnostics. Verified source bundle, all failures/raw observations and8 exact
unaccepted build files are preserved in
`/srv/mudds-work/zenith-torrent-handback-20261026/records.tar.gz` (374057008bytes;
SHA-256 `3b0f4c10bc8c47bd89d2df19abe1ae26c89b23a2138159e24a62b6f2c7e8692c`;
295regular files/21links, complete content/mode/link/membership verification).
Owned branch/worktree and loose scratch are removed after exact ownership/tip
checks and archive verification; the remote task branch was absent. Only `main`
remains locally. Unrelated detached diagnostic/profiler/station worktrees and old
prunable `/tmp` registrations are retained. No code from that archived candidate was merged and no checkpoint was published
at its closeout;3649b4b was current then. The separately accepted Aft checkpoint
1f7dccb is current above. Closure preparation cost
59.632minutes from09:51:00UTC against90minute estimate; final docs/push stay
on that clock. Full Zenith, other craft/world/network/release and external gates
remain open; earlier accepted Zenith results stay accepted.

**Frozen handback contract — one continuation selected after the accepted stair repair.**

- **Goal:** existing CRAFT-ACCEPT-ZENITH cross-craft handback member, implemented
  as `run_native_sortie.py --route zenith-torrent-handback` and actually proved.
  Existing Zenith flight/hit/two-home/reuse/settled-Main results stay closed.
- **Starting state:** clean integrated candidate descended from `433a9ded7`,
  exact source and embedded native Linux package recorded before execution;
  fresh owned profile, normal Boot/Begin Shift, nine real craft and authored
  tuning/default command samplers. No source/pack/script override or staged poses.
- **Actions:** reuse LIFE-ARM's fifteen goals/physical canopy boarding/90 seated
  observations; Zenith stays home/OFFLINE. Release then ordinary E exits the
  docked Zenith without flying it. Walk live-home-relative port(-7.2,-1.08,3.9)
  and clear(-1.6,-1.08,5.9) points, >7m/cleared reboard block. Reverse the known
  path below; board Torrent through its live current candidate. Complete actual
  Guided launch→four range drones→defender→return→L/strict home, 90 consecutive
  neutral/OFFLINE observations and physical exit, exactly once. Clear Torrent's
  reboard block radially, reverse the central connector, repeat the fifteen
  outward ARM goals and physically reclaim the same original Zenith. Observe
  90 fresh neutral seated ticks, then normal HUD Exit/actual OS0.
- **Walking route:** from Zenith wing-clear use (x,y,z)
  `(22,4.2,68.3)→(13,4.2,68.3)→(6,4.2,68.3)→(-3.5,4.2,68.3)→`
  `(-3.5,4.2,64.2)→(-3.5,4.2,61.5)→(-5.7,4.2,61.2)→(-5.7,0,51)→`
  `(0,0,51)→(0,0,46.3)→(0,0,39)→(0,0,15.5)→(-8.5,0,15.5)→`
  `(-8.5,0,13.5)→(-8.5,0,live Torrent ExitPoint.z)→live Torrent candidate`.
  After Torrent exit reuse existing radial-clear target
  `player + max(4,8-horizontal_distance_to_boarding)*unit(horizontal_player_minus_boarding)`;
  store that live target. Connect via `(-8.5,0,clear_target.z)→(-8.5,0,13.5)→`
  `(-8.5,0,15.5)→(0,0,15.5)`, then unchanged outward ARM_GOALS. Existing Zenith
  corner x≥20.30/z≤59.20 stays binding; no claim that reverse/connectors passed yet.
- **Pass/fail:** same Main/Player/both hulls, registered1104/1101, seats/cameras/
  areas/berths and authored resources/tuning. Only current occupied craft owns
  pilot/input/camera; exited sources retire, remain neutral/pending0, and fresh
  Zenith stream is greater than its retired epoch, with actual E producer and
  lifecycle-consumer receipts. Zenith remains intact/home/OFFLINE throughout;
  Torrent genuinely releases lease, completes required Guided, restores exact
  strict home lease/OFFLINE and physically exits. All walking is supported and
  actor-current; fresh Zenith claim consumes a new current neutral stream.
  Require normal HUD Quit exit0, both durable clean markers, real files and no
  diagnostics, tracked-source mutation, input capture or surviving owned children.
- **Proof:** exact embedded exported ELF on owned Xvfb, explicit x11 and Dummy,
  OS XTest input into default production samplers; existing native runner records
  raw observations/commands/source/package hashes, actual file/identity/claim
  endpoints and `NATIVE_ZENITH_TORRENT_HANDBACK_OK`, after actual OS0/reap. Focused
  existing Python driver/privacy/observer checks, paired exports, three strict
  startups and actual payload audit precede one whole-route trial.
- **Dependencies and limits:** implement exact selector/orchestrator/observer and
  reviewed fixtures. Guided is mandatory; never force phase/complete flags or
  skip targets. Existing Guided Pilot uses the whole CAP300, with no additional
  per-phase deadline; retain it. Walking15s/goal, boarding12s, initial Zenith
  exit10s, Torrent radial clear12s, real Hero landing timeout/independent4s stall,
  whole-game300s/outer360s remain. Admission's90 neutral observations count once;
  add no duplicate stable wait if they already prove the same consumer condition.
  Native GPU/physical devices/rendered/human/full-craft/final gates stay NOT_RUN.
- **Stop and closure:** estimate90minutes from2026-10-26 09:51:00UTC, including
  readiness, implementation, checks, failures, checkpoint, push and exact owned
  cleanup. Stop at first unexpected failure; no automatic retry or cap/clock
  reset. A later trial needs demonstrated cause and independent cumulative-
  priority review. Failed unaccepted source/binaries are archived, not merged to
  delete a branch. Successful caller/actual journey gets a fresh checkpoint,
  accepted card/backlog update, regular push and branch/worktree/scratch cleanup.




| Existing goal | Specific reopening requirement |
| --- | --- |
| PLAY-CONVOY[ordinary packaged driver] | Source7952127 is unvalidated and archived; corrected Python suite never launched. Fresh per-attempt profile namespace plus reuse preflight, then independent cumulative-priority selection with full original route/CAP300/outer360/75min accounting; no third under the closed card. [Two stops](docs/history/ROADMAP_DELIVERIES.md#convoy-ordinary-driver-two-stops-20261026) |
| CRAFT-ACCEPT-JOVIAN[ordinary solo engineer] | Correct the source-contradictory still-attached authority predicate and log each post-stand member; independent source/cumulative review before any future selection. Both actual trials stop; no third under the closed card. Preserve full physical return/UI0 and original300/360/15s limits |
| WALK-AFT | Bind the actual frozen Player completed-motion receipt in paused observation; last unpaused observation can lag one tick. Preserve full journey/original 60min cumulative clock/300s and360s caps; independent source GO and priority review before any new trial |
| PLAY-TORPEDO | Retain cancelled request debt across unread queued neutral samples after OS release; source GO and cumulative priority review before checks; full Heavy/Torpedo/Wing finish unchanged |
| PLAY-PATROL[platform_sweep] | Localize normal quit failure; five holds/payment/home/exit already observed but UI exit0/save closure missing. Original300s remains |
| PLAY-DEFENSE | Demonstrated control/gameplay correction for the recorded two-of-four clear; no arbitrary longer fight |
| COMBAT-WING | Demonstrated cause/correction for eight shots causing zero damage; no unsupported aim tuning |
| Other parked rows | Their exact recorded cause, original case list/cap and reopening predicate in the canonical backlog; no unchanged retry |

Unaccepted Torpedo source and helpers are consolidated in
`/srv/mudds-work/torpedo-boat-control-20261025/results/case-records.tar.gz`;
adjacent `closeout.json` records the verified archive/hash, preserved original
clock and cleanup. Source review stopped the sole correction before any tests,
engine, export or whole trial. The Torpedo candidate stays unmerged; transport checkpoint4afd529 now supersedes
0d77125 without accepting Torpedo. [Exact blocker and retained full journey](docs/history/ROADMAP_DELIVERIES.md#torpedo-control-continuation-stopped-at-source-review-20261025).

## Validation and final release

Automated Godot always uses Dummy audio, headless or private Xvfb with explicit
x11. Audible output requires authorization. GitHub Actions remains disabled.
Native Windows execution and mandatory human review remain owner-excluded;
unperformed facts stay NOT_RUN. Applicable Linux/native GPU/device/audio gates
remain; simulated checks cannot supply physical measurements.

The final exit is one accepted candidate with zeroP0/P1, explicitP2 dispositions,
required complete ordinary journeys and unfiltered local matrix, matching
installable artifacts, settled rights/signatures and authorized downloaded-byte
identity. All [ten phase exits](docs/ROADMAP_BACKLOG.md#original-phase-gates-and-completion)
remain binding. Missing design decisions or hardware access stay named blockers;
they do not become indefinite implementation tasks.
